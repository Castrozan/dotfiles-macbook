import AppKit
import Foundation

final class DaemonCompositionRoot {
    func bootstrapAndRun() {
        DaemonStartupSequence.removeStaleActivationFlagFile(atPath: DaemonConfiguration.activationFlagFilePath)

        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)

        let composedDependencies = buildAllDependencies()
        composedDependencies.applicationIconProvider.prewarmCacheFromRunningApplications()
        composedDependencies.commandSocketServer.startAcceptingConnectionsOnBackgroundThread()

        application.run()
    }

    private func buildAllDependencies() -> ComposedDaemonDependencies {
        let aerospaceSocketPathResolver = AeroSpaceSocketPathResolver()
        let aerospaceIpcClient = AeroSpaceIpcClient(
            socketPathResolver: aerospaceSocketPathResolver,
            connectionTimeoutSeconds: DaemonConfiguration.aerospaceIpcTimeoutSeconds
        )
        let aerospaceWindowProvider = AeroSpaceWindowProvider(ipcClient: aerospaceIpcClient)

        let applicationIconCache = ApplicationIconCache()
        let applicationIconProvider = ApplicationIconProvider(iconCache: applicationIconCache)

        let activationPhaseTimestampStore = ActivationPhaseTimestampStore()
        let performanceLogFileAppender = PerformanceLogFileAppender(
            logFilePath: DaemonConfiguration.performanceLogFilePath
        )
        let activationPerformanceProfiler = ActivationPerformanceProfiler(
            timestampStore: activationPhaseTimestampStore,
            logFileAppender: performanceLogFileAppender
        )
        let overlayLifecycleObserver = PerformanceProfilingOverlayLifecycleAdapter(
            performanceProfiler: activationPerformanceProfiler
        )

        let mostRecentlyUsedWindowTracker = MostRecentlyUsedWindowTracker()
        let activationFlagFileWriter = ActiveFlagFileWriter(
            flagFilePath: DaemonConfiguration.activationFlagFilePath
        )
        let commitTimeoutTimerScheduler = CommitTimeoutTimerScheduler()

        let windowCardViewFactory = WindowCardViewFactory(
            iconProvider: applicationIconProvider,
            cardWidth: DaemonConfiguration.cardWidth,
            cardHeight: DaemonConfiguration.cardHeight,
            cardIconSize: DaemonConfiguration.cardIconSize,
            cardCornerRadius: DaemonConfiguration.cardCornerRadius,
            selectionBorderWidth: DaemonConfiguration.selectionBorderWidth,
            cardIconTopPadding: DaemonConfiguration.cardIconTopPadding,
            cardTitleHorizontalInset: DaemonConfiguration.cardTitleHorizontalInset,
            cardTitleBottomOffset: DaemonConfiguration.cardTitleBottomOffset,
            cardTitleHeight: DaemonConfiguration.cardTitleHeight
        )
        let cardSelectionStyler = CardSelectionStyler(
            titleFontSize: DaemonConfiguration.titleFontSize
        )
        let switcherOverlayPanel = SwitcherOverlayPanel(
            cardViewFactory: windowCardViewFactory,
            selectionStyler: cardSelectionStyler,
            overlayLifecycleObserver: overlayLifecycleObserver,
            cardWidth: DaemonConfiguration.cardWidth,
            cardHeight: DaemonConfiguration.cardHeight,
            cardSpacing: DaemonConfiguration.cardSpacing,
            overlayPadding: DaemonConfiguration.overlayPadding,
            overlayCornerRadius: DaemonConfiguration.overlayCornerRadius
        )

        let windowSwitcherStateMachine = WindowSwitcherStateMachine(
            windowProvider: aerospaceWindowProvider,
            windowFocuser: aerospaceWindowProvider,
            overlayRenderer: switcherOverlayPanel,
            mruTracker: mostRecentlyUsedWindowTracker,
            activationFlagWriter: activationFlagFileWriter,
            performanceProfiler: activationPerformanceProfiler,
            commitTimeoutScheduler: commitTimeoutTimerScheduler,
            commitTimeoutSeconds: DaemonConfiguration.commitTimeoutSeconds
        )

        let socketCommandMainThreadDispatcher = SocketCommandMainThreadDispatcher(
            commandHandler: windowSwitcherStateMachine
        )
        let commandSocketAcceptLoop = CommandSocketAcceptLoop(
            socketPath: DaemonConfiguration.commandSocketPath,
            listenBacklog: DaemonConfiguration.socketListenBacklog,
            socketFileMode: DaemonConfiguration.commandSocketFileMode,
            clientReadBufferSize: DaemonConfiguration.socketReadBufferSize,
            clientReadTimeoutMicroseconds: DaemonConfiguration.clientReadTimeoutMicroseconds,
            onCommandReceived: { trimmedCommandString in
                guard let parsedCommand = SocketCommandParser.parseTrimmedCommand(trimmedCommandString) else {
                    return
                }
                socketCommandMainThreadDispatcher.dispatchOnMainThread(parsedCommand)
            }
        )
        let commandSocketServer = CommandSocketServer(acceptLoop: commandSocketAcceptLoop)

        return ComposedDaemonDependencies(
            applicationIconProvider: applicationIconProvider,
            commandSocketServer: commandSocketServer
        )
    }
}

private struct ComposedDaemonDependencies {
    let applicationIconProvider: IconProviding
    let commandSocketServer: CommandSocketServer
}
