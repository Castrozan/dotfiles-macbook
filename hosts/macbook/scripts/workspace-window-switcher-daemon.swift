import AppKit
import Darwin
import Foundation
import UniformTypeIdentifiers

let switcherCommandSocketPath = "/tmp/workspace-switcher.sock"
let switcherActiveFlagFilePath = "/tmp/workspace-switcher.active"
let switcherPerformanceLogFilePath = "/tmp/workspace-switcher-perf.log"

let cardWidth: CGFloat = 140
let cardHeight: CGFloat = 120
let cardIconSize: CGFloat = 64
let cardSpacing: CGFloat = 12
let overlayPadding: CGFloat = 16
let overlayCornerRadius: CGFloat = 14
let cardCornerRadius: CGFloat = 10
let titleFontSize: CGFloat = 11
let selectionBorderWidth: CGFloat = 3
let commitTimeoutSeconds: TimeInterval = 10.0
let socketReadBufferSize = 1024
let socketListenBacklog: Int32 = 32
let aerospaceIpcTimeoutSeconds: Int = 2
let clientReadTimeoutMicroseconds: Int32 = 500_000

final class ActivationPerformanceProfiler {
    private static let phaseOrderForReport: [String] = [
        "worker_started",
        "ipc_workspace_done",
        "ipc_focus_done",
        "main_callback",
        "mru_sort_done",
        "overlay_build_done",
        "overlay_visible",
    ]

    private let logFilePath: String
    private let lock = NSLock()
    private var timestampNanosecondsByPhase: [String: UInt64] = [:]
    private var workspaceWindowCount: Int = 0

    init(logFilePath: String) {
        self.logFilePath = logFilePath
    }

    func beginNewActivation() {
        lock.lock()
        timestampNanosecondsByPhase = [:]
        workspaceWindowCount = 0
        timestampNanosecondsByPhase["begin"] = DispatchTime.now().uptimeNanoseconds
        lock.unlock()
    }

    func markPhase(_ phaseName: String) {
        lock.lock()
        if timestampNanosecondsByPhase["begin"] != nil {
            timestampNanosecondsByPhase[phaseName] = DispatchTime.now().uptimeNanoseconds
        }
        lock.unlock()
    }

    func recordWorkspaceWindowCount(_ count: Int) {
        lock.lock()
        workspaceWindowCount = count
        lock.unlock()
    }

    func emitActivationReport() {
        lock.lock()
        let timestampsSnapshot = timestampNanosecondsByPhase
        let windowCount = workspaceWindowCount
        timestampNanosecondsByPhase = [:]
        workspaceWindowCount = 0
        lock.unlock()

        guard let baselineNanoseconds = timestampsSnapshot["begin"] else { return }
        var lineParts: [String] = ["windows=\(windowCount)"]
        for phaseName in ActivationPerformanceProfiler.phaseOrderForReport {
            if let phaseNanoseconds = timestampsSnapshot[phaseName] {
                let deltaMilliseconds = Double(phaseNanoseconds &- baselineNanoseconds) / 1_000_000.0
                lineParts.append("\(phaseName)=\(String(format: "%.3f", deltaMilliseconds))")
            }
        }
        appendStringToFile(lineParts.joined(separator: " ") + "\n", atPath: logFilePath)
    }

    private func appendStringToFile(_ string: String, atPath path: String) {
        let data = Data(string.utf8)
        if let fileHandle = FileHandle(forWritingAtPath: path) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            try? fileHandle.close()
        } else {
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }
}

let performanceProfiler = ActivationPerformanceProfiler(logFilePath: switcherPerformanceLogFilePath)

final class AeroSpaceWindowProvider {
    private var cachedSocketPath: String?

    private func resolveAeroSpaceSocketPath() -> String? {
        let username = ProcessInfo.processInfo.environment["USER"] ?? NSUserName()
        let expectedSocketPath = "/tmp/bobko.aerospace-\(username).sock"
        if FileManager.default.fileExists(atPath: expectedSocketPath) {
            return expectedSocketPath
        }
        guard let directoryEntries = try? FileManager.default.contentsOfDirectory(atPath: "/tmp") else {
            return nil
        }
        let matchingFileName = directoryEntries.first { fileName in
            fileName.hasPrefix("bobko.aerospace-") && fileName.hasSuffix(".sock")
        }
        guard let matchedFileName = matchingFileName else { return nil }
        return "/tmp/\(matchedFileName)"
    }

    private func socketPathWithLazyResolution() -> String? {
        if cachedSocketPath == nil {
            cachedSocketPath = resolveAeroSpaceSocketPath()
        }
        return cachedSocketPath
    }

    private func sendIpcCommand(arguments: [String]) -> String? {
        guard let socketPath = socketPathWithLazyResolution() else { return nil }

        let socketDescriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        if socketDescriptor < 0 { return nil }
        defer { Darwin.close(socketDescriptor) }

        var sendReceiveTimeout = timeval(tv_sec: aerospaceIpcTimeoutSeconds, tv_usec: 0)
        let timevalLength = socklen_t(MemoryLayout<timeval>.size)
        _ = Darwin.setsockopt(socketDescriptor, SOL_SOCKET, SO_RCVTIMEO, &sendReceiveTimeout, timevalLength)
        _ = Darwin.setsockopt(socketDescriptor, SOL_SOCKET, SO_SNDTIMEO, &sendReceiveTimeout, timevalLength)

        if !connectUnixSocket(descriptor: socketDescriptor, toPath: socketPath) {
            cachedSocketPath = nil
            return nil
        }

        let requestObject: [String: Any] = [
            "args": arguments,
            "stdin": "",
            "windowId": NSNull(),
            "workspace": NSNull(),
        ]
        guard let requestData = try? JSONSerialization.data(withJSONObject: requestObject) else {
            return nil
        }

        let bytesWritten = requestData.withUnsafeBytes { rawBufferPointer -> Int in
            return Darwin.send(socketDescriptor, rawBufferPointer.baseAddress, rawBufferPointer.count, 0)
        }
        if bytesWritten != requestData.count {
            cachedSocketPath = nil
            return nil
        }
        _ = Darwin.shutdown(socketDescriptor, SHUT_WR)

        var responseData = Data()
        var readBuffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let bytesRead = readBuffer.withUnsafeMutableBufferPointer { bufferPointer -> Int in
                return Darwin.recv(socketDescriptor, bufferPointer.baseAddress, bufferPointer.count, 0)
            }
            if bytesRead <= 0 { break }
            responseData.append(readBuffer, count: bytesRead)
        }

        guard let firstResponseObject = parseFirstJsonObject(from: responseData) else {
            cachedSocketPath = nil
            return nil
        }
        let exitCode = (firstResponseObject["exitCode"] as? Int) ?? 1
        if exitCode != 0 { return nil }
        return firstResponseObject["stdout"] as? String ?? ""
    }

    private func parseFirstJsonObject(from data: Data) -> [String: Any]? {
        if let singleObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return singleObject
        }
        guard let asString = String(data: data, encoding: .utf8) else { return nil }
        var openBraceDepth = 0
        var insideStringLiteral = false
        var previousCharacter: Character = " "
        var endIndex: String.Index?
        for currentIndex in asString.indices {
            let currentCharacter = asString[currentIndex]
            if insideStringLiteral {
                if currentCharacter == "\"" && previousCharacter != "\\" {
                    insideStringLiteral = false
                }
            } else if currentCharacter == "\"" {
                insideStringLiteral = true
            } else if currentCharacter == "{" {
                openBraceDepth += 1
            } else if currentCharacter == "}" {
                openBraceDepth -= 1
                if openBraceDepth == 0 {
                    endIndex = asString.index(after: currentIndex)
                    break
                }
            }
            previousCharacter = currentCharacter
        }
        guard let foundEndIndex = endIndex else { return nil }
        let firstObjectSlice = asString[asString.startIndex..<foundEndIndex]
        guard let firstObjectData = String(firstObjectSlice).data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: firstObjectData)) as? [String: Any]
    }

    func getFocusedWorkspaceWindows() -> [[String: Any]] {
        guard let stdout = sendIpcCommand(arguments: ["list-windows", "--workspace", "focused", "--json"]) else {
            return []
        }
        return parseWindowsJsonArray(stdout)
    }

    func getFocusedWindowId() -> Int? {
        guard let stdout = sendIpcCommand(arguments: ["list-windows", "--focused", "--json"]) else {
            return nil
        }
        let windows = parseWindowsJsonArray(stdout)
        guard let firstWindow = windows.first else { return nil }
        return firstWindow["window-id"] as? Int
    }

    func focusWindow(windowId: Int) {
        _ = sendIpcCommand(arguments: ["focus", "--window-id", String(windowId)])
    }

    private func parseWindowsJsonArray(_ jsonString: String) -> [[String: Any]] {
        guard let data = jsonString.data(using: .utf8) else { return [] }
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array
    }
}

func connectUnixSocket(descriptor: Int32, toPath path: String) -> Bool {
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let pathBytesWithNullTerminator = path.utf8CString
    if pathBytesWithNullTerminator.count > MemoryLayout.size(ofValue: address.sun_path) {
        return false
    }
    withUnsafeMutablePointer(to: &address.sun_path) { sunPathPointer in
        sunPathPointer.withMemoryRebound(to: CChar.self, capacity: pathBytesWithNullTerminator.count) { typedDestinationPointer in
            pathBytesWithNullTerminator.withUnsafeBufferPointer { sourceBufferPointer in
                typedDestinationPointer.update(from: sourceBufferPointer.baseAddress!, count: pathBytesWithNullTerminator.count)
            }
        }
    }
    let addressLength = socklen_t(MemoryLayout<sockaddr_un>.size)
    let connectResult = withUnsafePointer(to: &address) { addressPointer -> Int32 in
        return addressPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
            return Darwin.connect(descriptor, sockaddrPointer, addressLength)
        }
    }
    return connectResult >= 0
}

func bindUnixSocket(descriptor: Int32, toPath path: String) -> Bool {
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let pathBytesWithNullTerminator = path.utf8CString
    if pathBytesWithNullTerminator.count > MemoryLayout.size(ofValue: address.sun_path) {
        return false
    }
    withUnsafeMutablePointer(to: &address.sun_path) { sunPathPointer in
        sunPathPointer.withMemoryRebound(to: CChar.self, capacity: pathBytesWithNullTerminator.count) { typedDestinationPointer in
            pathBytesWithNullTerminator.withUnsafeBufferPointer { sourceBufferPointer in
                typedDestinationPointer.update(from: sourceBufferPointer.baseAddress!, count: pathBytesWithNullTerminator.count)
            }
        }
    }
    let addressLength = socklen_t(MemoryLayout<sockaddr_un>.size)
    let bindResult = withUnsafePointer(to: &address) { addressPointer -> Int32 in
        return addressPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
            return Darwin.bind(descriptor, sockaddrPointer, addressLength)
        }
    }
    return bindResult >= 0
}

final class ApplicationIconProvider {
    private var iconCacheByApplicationName: [String: NSImage] = [:]

    func prewarmCacheFromRunningApplications() {
        let workspace = NSWorkspace.shared
        for runningApplication in workspace.runningApplications {
            guard let applicationName = runningApplication.localizedName else { continue }
            if iconCacheByApplicationName[applicationName] != nil { continue }
            if let icon = runningApplication.icon {
                iconCacheByApplicationName[applicationName] = icon
            }
        }
    }

    func iconForApplicationName(_ applicationName: String) -> NSImage {
        if let cachedIcon = iconCacheByApplicationName[applicationName] {
            return cachedIcon
        }
        let resolvedIcon = resolveIconFromRunningApplications(named: applicationName)
        iconCacheByApplicationName[applicationName] = resolvedIcon
        return resolvedIcon
    }

    private func resolveIconFromRunningApplications(named applicationName: String) -> NSImage {
        let workspace = NSWorkspace.shared
        for runningApplication in workspace.runningApplications {
            if runningApplication.localizedName == applicationName, let icon = runningApplication.icon {
                return icon
            }
        }
        return workspace.icon(for: UTType.application)
    }
}

final class NonActivatingFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class SwitcherOverlayPanel {
    private let iconProvider: ApplicationIconProvider
    private var floatingPanel: NonActivatingFloatingPanel?
    private var backgroundVisualEffectView: NSVisualEffectView?
    private var cardViewsWithBorderOverlays: [(NSView, NSView)] = []

    init(iconProvider: ApplicationIconProvider) {
        self.iconProvider = iconProvider
    }

    func showWithWindowsAndSelection(_ windows: [[String: Any]], selectedIndex: Int) {
        createFloatingPanel()
        buildOverlayContentsWithCards(windows: windows, selectedIndex: selectedIndex)
        centerPanelOnMainScreen()
        performanceProfiler.markPhase("overlay_build_done")
        floatingPanel?.orderFrontRegardless()
    }

    func updateSelectedIndex(_ selectedIndex: Int) {
        for (cardIndex, (cardView, borderView)) in cardViewsWithBorderOverlays.enumerated() {
            let isSelected = cardIndex == selectedIndex
            applyCardSelectionStyle(cardView: cardView, borderView: borderView, isSelected: isSelected)
        }
    }

    func hide() {
        if let panelToDispose = floatingPanel {
            panelToDispose.orderOut(nil)
            panelToDispose.close()
        }
        floatingPanel = nil
        backgroundVisualEffectView = nil
        cardViewsWithBorderOverlays = []
    }

    private func createFloatingPanel() {
        let initialContentFrame = NSRect(x: 0, y: 0, width: 400, height: 200)
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        let createdPanel = NonActivatingFloatingPanel(
            contentRect: initialContentFrame,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        createdPanel.isReleasedWhenClosed = false
        createdPanel.level = .popUpMenu
        createdPanel.isOpaque = false
        createdPanel.backgroundColor = .clear
        createdPanel.hasShadow = true
        createdPanel.ignoresMouseEvents = true
        createdPanel.hidesOnDeactivate = false
        createdPanel.alphaValue = 1.0
        createdPanel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        floatingPanel = createdPanel
    }

    private func buildOverlayContentsWithCards(windows: [[String: Any]], selectedIndex: Int) {
        guard let panel = floatingPanel else { return }
        let cardCount = CGFloat(windows.count)
        let totalWidth = overlayPadding * 2 + cardCount * cardWidth + max(0, cardCount - 1) * cardSpacing
        let totalHeight = overlayPadding * 2 + cardHeight

        let panelFrame = NSRect(x: 0, y: 0, width: totalWidth, height: totalHeight)
        panel.setFrame(panelFrame, display: false)

        let backgroundFrame = NSRect(x: 0, y: 0, width: totalWidth, height: totalHeight)
        let createdBackgroundView = NSVisualEffectView(frame: backgroundFrame)
        createdBackgroundView.material = .hudWindow
        createdBackgroundView.blendingMode = .behindWindow
        createdBackgroundView.state = .active
        createdBackgroundView.wantsLayer = true
        createdBackgroundView.layer?.cornerRadius = overlayCornerRadius
        createdBackgroundView.layer?.masksToBounds = true
        createdBackgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        panel.contentView?.addSubview(createdBackgroundView)
        backgroundVisualEffectView = createdBackgroundView

        for (windowIndex, windowData) in windows.enumerated() {
            let horizontalOffset = overlayPadding + CGFloat(windowIndex) * (cardWidth + cardSpacing)
            let verticalOffset = overlayPadding
            let isSelected = windowIndex == selectedIndex

            let (cardView, borderView) = createWindowCard(
                windowData: windowData,
                horizontalOffset: horizontalOffset,
                verticalOffset: verticalOffset,
                isSelected: isSelected
            )
            createdBackgroundView.addSubview(cardView)
            cardViewsWithBorderOverlays.append((cardView, borderView))
        }
    }

    private func createWindowCard(
        windowData: [String: Any],
        horizontalOffset: CGFloat,
        verticalOffset: CGFloat,
        isSelected: Bool
    ) -> (NSView, NSView) {
        let cardFrame = NSRect(x: horizontalOffset, y: verticalOffset, width: cardWidth, height: cardHeight)
        let cardView = NSView(frame: cardFrame)
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = cardCornerRadius

        let borderView = NSView(frame: NSRect(x: 0, y: 0, width: cardWidth, height: cardHeight))
        borderView.wantsLayer = true
        borderView.layer?.cornerRadius = cardCornerRadius
        borderView.layer?.borderWidth = selectionBorderWidth
        cardView.addSubview(borderView)

        let applicationName = (windowData["app-name"] as? String) ?? ""
        let applicationIcon = iconProvider.iconForApplicationName(applicationName)
        let iconHorizontalOffset = (cardWidth - cardIconSize) / 2
        let iconVerticalOffset = cardHeight - cardIconSize - 16
        let iconImageView = NSImageView(frame: NSRect(
            x: iconHorizontalOffset,
            y: iconVerticalOffset,
            width: cardIconSize,
            height: cardIconSize
        ))
        iconImageView.image = applicationIcon
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        cardView.addSubview(iconImageView)

        let windowTitle = (windowData["window-title"] as? String) ?? applicationName
        let titleFrame = NSRect(x: 6, y: 4, width: cardWidth - 12, height: 28)
        let titleTextField = NSTextField(frame: titleFrame)
        titleTextField.stringValue = windowTitle
        titleTextField.isBezeled = false
        titleTextField.drawsBackground = false
        titleTextField.isEditable = false
        titleTextField.isSelectable = false
        titleTextField.alignment = .center
        titleTextField.lineBreakMode = .byTruncatingTail
        titleTextField.maximumNumberOfLines = 2
        cardView.addSubview(titleTextField)

        applyCardSelectionStyle(cardView: cardView, borderView: borderView, isSelected: isSelected)
        return (cardView, borderView)
    }

    private func applyCardSelectionStyle(cardView: NSView, borderView: NSView, isSelected: Bool) {
        if isSelected {
            cardView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
            borderView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
        } else {
            cardView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
            borderView.layer?.borderColor = NSColor.clear.cgColor
        }
        let textAlpha: CGFloat = isSelected ? 1.0 : 0.6
        let fontWeight: NSFont.Weight = isSelected ? .medium : .regular
        for subview in cardView.subviews {
            if let textField = subview as? NSTextField {
                textField.textColor = NSColor.white.withAlphaComponent(textAlpha)
                textField.font = NSFont.systemFont(ofSize: titleFontSize, weight: fontWeight)
            }
        }
    }

    private func centerPanelOnMainScreen() {
        guard let panel = floatingPanel, let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let panelFrame = panel.frame
        let centeredX = (screenFrame.size.width - panelFrame.size.width) / 2
        let centeredY = (screenFrame.size.height - panelFrame.size.height) / 2
        panel.setFrameOrigin(NSPoint(x: centeredX, y: centeredY))
    }
}

final class MostRecentlyUsedWindowTracker {
    private var windowIdsOrderedByRecency: [Int] = []

    func recordFocusedWindow(_ windowId: Int) {
        if let existingIndex = windowIdsOrderedByRecency.firstIndex(of: windowId) {
            windowIdsOrderedByRecency.remove(at: existingIndex)
        }
        windowIdsOrderedByRecency.insert(windowId, at: 0)
    }

    func sortWindowsByRecency(_ windows: [[String: Any]]) -> [[String: Any]] {
        var positionByWindowId: [Int: Int] = [:]
        for (position, windowId) in windowIdsOrderedByRecency.enumerated() {
            positionByWindowId[windowId] = position
        }
        let unknownWindowPosition = windowIdsOrderedByRecency.count
        return windows.sorted { firstWindow, secondWindow in
            let firstWindowId = (firstWindow["window-id"] as? Int) ?? Int.max
            let secondWindowId = (secondWindow["window-id"] as? Int) ?? Int.max
            let firstPosition = positionByWindowId[firstWindowId] ?? unknownWindowPosition
            let secondPosition = positionByWindowId[secondWindowId] ?? unknownWindowPosition
            return firstPosition < secondPosition
        }
    }

    func removeStaleWindowIds(currentWindowIds: Set<Int>) {
        windowIdsOrderedByRecency = windowIdsOrderedByRecency.filter { currentWindowIds.contains($0) }
    }
}

final class WindowSwitcherStateMachine {
    private let aerospaceWindowProvider: AeroSpaceWindowProvider
    private let switcherOverlayPanel: SwitcherOverlayPanel
    private let mostRecentlyUsedWindowTracker: MostRecentlyUsedWindowTracker
    private var orderedWindows: [[String: Any]] = []
    private var selectedWindowIndex: Int = 0
    private var isActivationActive: Bool = false
    private var isFetchingWindowsFromAeroSpace: Bool = false
    private var commitRequestedBeforeFetchCompleted: Bool = false
    private var accumulatedPendingDirectionChanges: Int = 0
    private var commitTimeoutTimer: Timer?

    init(
        aerospaceWindowProvider: AeroSpaceWindowProvider,
        switcherOverlayPanel: SwitcherOverlayPanel,
        mostRecentlyUsedWindowTracker: MostRecentlyUsedWindowTracker
    ) {
        self.aerospaceWindowProvider = aerospaceWindowProvider
        self.switcherOverlayPanel = switcherOverlayPanel
        self.mostRecentlyUsedWindowTracker = mostRecentlyUsedWindowTracker
    }

    var isActive: Bool { isActivationActive }

    func handleNextCommand() {
        if !isActivationActive {
            beginActivation(withInitialDirection: 1)
            return
        }
        if isFetchingWindowsFromAeroSpace {
            accumulatedPendingDirectionChanges += 1
            return
        }
        advanceSelection(by: 1)
        restartCommitTimeoutTimer()
    }

    func handlePrevCommand() {
        if !isActivationActive {
            beginActivation(withInitialDirection: -1)
            return
        }
        if isFetchingWindowsFromAeroSpace {
            accumulatedPendingDirectionChanges -= 1
            return
        }
        advanceSelection(by: -1)
        restartCommitTimeoutTimer()
    }

    func handleCommitCommand() {
        if !isActivationActive { return }
        if isFetchingWindowsFromAeroSpace {
            commitRequestedBeforeFetchCompleted = true
            return
        }
        cancelCommitTimeoutTimer()
        focusSelectedWindowAndDeactivate()
    }

    func handleCancelCommand() {
        if !isActivationActive { return }
        cancelCommitTimeoutTimer()
        deactivate()
    }

    func recordFocusedWindowFromExternalSignal(_ windowId: Int) {
        mostRecentlyUsedWindowTracker.recordFocusedWindow(windowId)
    }

    private func createActiveFlagFile() {
        FileManager.default.createFile(atPath: switcherActiveFlagFilePath, contents: nil)
    }

    private func removeActiveFlagFile() {
        try? FileManager.default.removeItem(atPath: switcherActiveFlagFilePath)
    }

    private func beginActivation(withInitialDirection initialDirection: Int) {
        performanceProfiler.beginNewActivation()
        isActivationActive = true
        createActiveFlagFile()
        isFetchingWindowsFromAeroSpace = true
        commitRequestedBeforeFetchCompleted = false
        accumulatedPendingDirectionChanges = initialDirection
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.fetchWindowsFromAeroSpaceOnBackgroundThread()
        }
    }

    private func fetchWindowsFromAeroSpaceOnBackgroundThread() {
        performanceProfiler.markPhase("worker_started")
        let workspaceWindows = aerospaceWindowProvider.getFocusedWorkspaceWindows()
        performanceProfiler.markPhase("ipc_workspace_done")
        let focusedWindowId = aerospaceWindowProvider.getFocusedWindowId()
        performanceProfiler.markPhase("ipc_focus_done")
        DispatchQueue.main.async { [weak self] in
            self?.onAeroSpaceWindowsFetched(workspaceWindows: workspaceWindows, focusedWindowId: focusedWindowId)
        }
    }

    private func onAeroSpaceWindowsFetched(workspaceWindows: [[String: Any]], focusedWindowId: Int?) {
        performanceProfiler.markPhase("main_callback")
        performanceProfiler.recordWorkspaceWindowCount(workspaceWindows.count)
        isFetchingWindowsFromAeroSpace = false

        if workspaceWindows.isEmpty {
            deactivate()
            return
        }

        let currentWindowIds = Set(workspaceWindows.compactMap { $0["window-id"] as? Int })
        mostRecentlyUsedWindowTracker.removeStaleWindowIds(currentWindowIds: currentWindowIds)
        if let focusedId = focusedWindowId {
            mostRecentlyUsedWindowTracker.recordFocusedWindow(focusedId)
        }
        orderedWindows = mostRecentlyUsedWindowTracker.sortWindowsByRecency(workspaceWindows)
        performanceProfiler.markPhase("mru_sort_done")

        let totalWindowCount = orderedWindows.count
        let totalAccumulatedDirection = accumulatedPendingDirectionChanges
        if totalAccumulatedDirection == 0 {
            selectedWindowIndex = min(1, totalWindowCount - 1)
        } else {
            let modulo = totalAccumulatedDirection % totalWindowCount
            selectedWindowIndex = (modulo + totalWindowCount) % totalWindowCount
        }

        if commitRequestedBeforeFetchCompleted {
            focusSelectedWindowAndDeactivate()
            return
        }

        switcherOverlayPanel.showWithWindowsAndSelection(orderedWindows, selectedIndex: selectedWindowIndex)
        performanceProfiler.markPhase("overlay_visible")
        performanceProfiler.emitActivationReport()
        restartCommitTimeoutTimer()
    }

    private func advanceSelection(by direction: Int) {
        if orderedWindows.isEmpty { return }
        let totalWindowCount = orderedWindows.count
        let modulo = (selectedWindowIndex + direction) % totalWindowCount
        selectedWindowIndex = (modulo + totalWindowCount) % totalWindowCount
        switcherOverlayPanel.updateSelectedIndex(selectedWindowIndex)
    }

    private func focusSelectedWindowAndDeactivate() {
        if !orderedWindows.isEmpty, selectedWindowIndex >= 0, selectedWindowIndex < orderedWindows.count {
            if let windowId = orderedWindows[selectedWindowIndex]["window-id"] as? Int {
                aerospaceWindowProvider.focusWindow(windowId: windowId)
            }
        }
        deactivate()
    }

    private func deactivate() {
        cancelCommitTimeoutTimer()
        removeActiveFlagFile()
        isActivationActive = false
        isFetchingWindowsFromAeroSpace = false
        commitRequestedBeforeFetchCompleted = false
        accumulatedPendingDirectionChanges = 0
        orderedWindows = []
        selectedWindowIndex = 0
        switcherOverlayPanel.hide()
    }

    private func restartCommitTimeoutTimer() {
        cancelCommitTimeoutTimer()
        commitTimeoutTimer = Timer.scheduledTimer(withTimeInterval: commitTimeoutSeconds, repeats: false) { [weak self] _ in
            self?.handleCommitCommand()
        }
    }

    private func cancelCommitTimeoutTimer() {
        commitTimeoutTimer?.invalidate()
        commitTimeoutTimer = nil
    }
}

final class CommandSocketServer {
    private let windowSwitcherStateMachine: WindowSwitcherStateMachine

    init(windowSwitcherStateMachine: WindowSwitcherStateMachine) {
        self.windowSwitcherStateMachine = windowSwitcherStateMachine
    }

    func startAcceptingConnections() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runServerAcceptLoop()
        }
    }

    private func runServerAcceptLoop() {
        try? FileManager.default.removeItem(atPath: switcherCommandSocketPath)

        let serverSocketDescriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        if serverSocketDescriptor < 0 { return }

        if !bindUnixSocket(descriptor: serverSocketDescriptor, toPath: switcherCommandSocketPath) {
            Darwin.close(serverSocketDescriptor)
            return
        }
        switcherCommandSocketPath.withCString { pathCString in
            _ = Darwin.chmod(pathCString, 0o666)
        }

        if Darwin.listen(serverSocketDescriptor, socketListenBacklog) < 0 {
            Darwin.close(serverSocketDescriptor)
            return
        }

        while true {
            let clientDescriptor = Darwin.accept(serverSocketDescriptor, nil, nil)
            if clientDescriptor < 0 { continue }
            var clientReceiveTimeout = timeval(tv_sec: 0, tv_usec: clientReadTimeoutMicroseconds)
            let timevalLength = socklen_t(MemoryLayout<timeval>.size)
            _ = Darwin.setsockopt(clientDescriptor, SOL_SOCKET, SO_RCVTIMEO, &clientReceiveTimeout, timevalLength)

            var readBuffer = [UInt8](repeating: 0, count: socketReadBufferSize)
            let bytesRead = readBuffer.withUnsafeMutableBufferPointer { bufferPointer -> Int in
                return Darwin.recv(clientDescriptor, bufferPointer.baseAddress, bufferPointer.count, 0)
            }
            Darwin.close(clientDescriptor)
            if bytesRead <= 0 { continue }
            let receivedData = Data(readBuffer.prefix(bytesRead))
            guard let receivedString = String(data: receivedData, encoding: .utf8) else { continue }
            let trimmedCommand = receivedString.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedCommand.isEmpty { continue }
            dispatchCommandToMainThread(trimmedCommand)
        }
    }

    private func dispatchCommandToMainThread(_ command: String) {
        if command.hasPrefix("focus:") {
            let windowIdString = String(command.dropFirst("focus:".count))
            guard let windowId = Int(windowIdString) else { return }
            DispatchQueue.main.async { [weak self] in
                self?.windowSwitcherStateMachine.recordFocusedWindowFromExternalSignal(windowId)
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let stateMachine = self?.windowSwitcherStateMachine else { return }
            switch command {
            case "next": stateMachine.handleNextCommand()
            case "prev": stateMachine.handlePrevCommand()
            case "commit": stateMachine.handleCommitCommand()
            case "cancel": stateMachine.handleCancelCommand()
            default: break
            }
        }
    }
}

func removeStaleActiveFlagOnStartup() {
    try? FileManager.default.removeItem(atPath: switcherActiveFlagFilePath)
}

removeStaleActiveFlagOnStartup()

let sharedApplication = NSApplication.shared
sharedApplication.setActivationPolicy(.accessory)

let aerospaceWindowProvider = AeroSpaceWindowProvider()
let applicationIconProvider = ApplicationIconProvider()
applicationIconProvider.prewarmCacheFromRunningApplications()
let switcherOverlayPanel = SwitcherOverlayPanel(iconProvider: applicationIconProvider)
let mostRecentlyUsedWindowTracker = MostRecentlyUsedWindowTracker()
let windowSwitcherStateMachine = WindowSwitcherStateMachine(
    aerospaceWindowProvider: aerospaceWindowProvider,
    switcherOverlayPanel: switcherOverlayPanel,
    mostRecentlyUsedWindowTracker: mostRecentlyUsedWindowTracker
)

let commandSocketServer = CommandSocketServer(windowSwitcherStateMachine: windowSwitcherStateMachine)
commandSocketServer.startAcceptingConnections()

sharedApplication.run()
