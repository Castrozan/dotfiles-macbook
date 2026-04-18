import Cocoa

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
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = NSColor(white: 0.13, alpha: 0.95)
        window.hasShadow = true

        searchField = NSTextField(frame: .zero)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search applications..."
        searchField.font = NSFont.systemFont(ofSize: 18)
        searchField.focusRingType = .none
        searchField.isBezeled = false
        searchField.drawsBackground = false
        searchField.textColor = .white

        let scrollView = NSScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        tableView = NSTableView(frame: .zero)
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.rowHeight = 32
        tableView.intercellSpacing = NSSize(width: 0, height: 2)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        column.isEditable = false
        tableView.addTableColumn(column)

        scrollView.documentView = tableView

        let separator = NSBox(frame: .zero)
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator

        let contentView = window.contentView!
        contentView.addSubview(searchField)
        contentView.addSubview(separator)
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            separator.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

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
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.font = NSFont.systemFont(ofSize: 16)
            textField.textColor = .white
            cellView!.addSubview(textField)
            cellView!.textField = textField
            cellView!.identifier = identifier
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 16),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor),
            ])
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
        var inputLines: [String] = []
        while let line = readLine() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                inputLines.append(trimmed)
            }
        }

        if inputLines.isEmpty {
            NSApp.terminate(nil)
            return
        }

        controller = FuzzyPickerController(items: inputLines)
        controller.show()
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

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
