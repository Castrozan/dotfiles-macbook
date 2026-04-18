import Cocoa

var inputLines: [String] = []
while let line = readLine() {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
        inputLines.append(trimmed)
    }
}

if inputLines.isEmpty {
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)

class FuzzyPickerController: NSObject, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    let allItems: [String]
    var filteredItems: [String]
    let tableView: NSTableView
    let searchField: NSTextField
    let window: NSPanel
    var selectedResult: String?

    init(items: [String]) {
        self.allItems = items
        self.filteredItems = items

        let windowWidth: CGFloat = 600
        let windowHeight: CGFloat = 400
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowOriginX = screenFrame.midX - windowWidth / 2
        let windowOriginY = screenFrame.midY - windowHeight / 2 + screenFrame.height * 0.15
        let windowFrame = NSRect(x: windowOriginX, y: windowOriginY, width: windowWidth, height: windowHeight)

        window = NSPanel(
            contentRect: windowFrame,
            styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = NSColor(white: 0.13, alpha: 0.95)
        window.hasShadow = true

        searchField = NSTextField(frame: NSRect(x: 16, y: 0, width: Int(windowWidth) - 32, height: 28))
        searchField.placeholderString = "Search applications..."
        searchField.font = NSFont.systemFont(ofSize: 18)
        searchField.focusRingType = .none
        searchField.isBezeled = false
        searchField.drawsBackground = false
        searchField.textColor = .white

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: Int(windowWidth), height: Int(windowHeight) - 50))
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        tableView = NSTableView(frame: .zero)
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.rowHeight = 30
        tableView.intercellSpacing = NSSize(width: 0, height: 1)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        column.isEditable = false
        tableView.addTableColumn(column)
        scrollView.documentView = tableView

        let contentView = window.contentView!
        searchField.frame = NSRect(x: 16, y: Int(windowHeight) - 40, width: Int(windowWidth) - 32, height: 28)
        scrollView.frame = NSRect(x: 0, y: 0, width: Int(windowWidth), height: Int(windowHeight) - 48)
        contentView.addSubview(searchField)
        contentView.addSubview(scrollView)

        super.init()

        searchField.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(searchField)
        NSApp.activate(ignoringOtherApps: true)
        if !filteredItems.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    func fuzzyMatch(item: String, query: String) -> Bool {
        let itemLower = item.lowercased()
        let queryLower = query.lowercased()
        var itemIndex = itemLower.startIndex
        for queryChar in queryLower {
            guard let foundIndex = itemLower[itemIndex...].firstIndex(of: queryChar) else {
                return false
            }
            itemIndex = itemLower.index(after: foundIndex)
        }
        return true
    }

    func controlTextDidChange(_ notification: Notification) {
        let query = searchField.stringValue
        if query.isEmpty {
            filteredItems = allItems
        } else {
            filteredItems = allItems.filter { fuzzyMatch(item: $0, query: query) }
        }
        tableView.reloadData()
        if !filteredItems.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commitSelection()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            NSApp.terminate(nil)
            return true
        }
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            let nextRow = min(tableView.selectedRow + 1, filteredItems.count - 1)
            tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
            tableView.scrollRowToVisible(nextRow)
            return true
        }
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            let prevRow = max(tableView.selectedRow - 1, 0)
            tableView.selectRowIndexes(IndexSet(integer: prevRow), byExtendingSelection: false)
            tableView.scrollRowToVisible(prevRow)
            return true
        }
        return false
    }

    func commitSelection() {
        let row = tableView.selectedRow
        if row >= 0 && row < filteredItems.count {
            selectedResult = filteredItems[row]
        }
        NSApp.terminate(nil)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("ItemCell")
        var cellView = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView

        if cellView == nil {
            cellView = NSTableCellView(frame: .zero)
            let textField = NSTextField(labelWithString: "")
            textField.font = NSFont.systemFont(ofSize: 15)
            textField.textColor = .white
            textField.frame = NSRect(x: 16, y: 0, width: 560, height: 28)
            cellView!.addSubview(textField)
            cellView!.textField = textField
            cellView!.identifier = identifier
        }

        cellView!.textField?.stringValue = filteredItems[row]
        return cellView
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return PickerRowView()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {}
}

class PickerRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            NSColor(white: 0.3, alpha: 1.0).setFill()
            bounds.fill()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: FuzzyPickerController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = FuzzyPickerController(items: inputLines)
        controller.show()
    }

    func applicationDidResignActive(_ notification: Notification) {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let result = controller?.selectedResult {
            FileHandle.standardOutput.write(Data((result + "\n").utf8))
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
