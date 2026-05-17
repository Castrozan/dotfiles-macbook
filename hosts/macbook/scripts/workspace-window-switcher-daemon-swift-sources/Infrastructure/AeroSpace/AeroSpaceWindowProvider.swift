import Foundation

final class AeroSpaceWindowProvider: WindowProviding, WindowFocusing {
    private let ipcClient: AeroSpaceIpcClient

    init(ipcClient: AeroSpaceIpcClient) {
        self.ipcClient = ipcClient
    }

    func getFocusedWorkspaceWindows() -> [WorkspaceWindow] {
        let dictionaries = listWindowDictionaries(arguments: ["list-windows", "--workspace", "focused", "--json"])
        return dictionaries.compactMap(WorkspaceWindow.fromAeroSpaceDictionary)
    }

    func getFocusedWindowIdentifier() -> Int? {
        let dictionaries = listWindowDictionaries(arguments: ["list-windows", "--focused", "--json"])
        guard let firstDictionary = dictionaries.first else { return nil }
        return firstDictionary["window-id"] as? Int
    }

    func focusWindow(withIdentifier identifier: Int) {
        _ = executeCommand(arguments: ["focus", "--window-id", String(identifier)])
    }

    private func listWindowDictionaries(arguments: [String]) -> [[String: Any]] {
        guard let stdoutContent = executeCommand(arguments: arguments) else { return [] }
        guard let data = stdoutContent.data(using: .utf8) else { return [] }
        return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }

    private func executeCommand(arguments: [String]) -> String? {
        guard let requestData = AeroSpaceIpcRequestEncoder.encodeRequest(arguments: arguments) else {
            return nil
        }
        guard let responseData = ipcClient.sendRequestAndReadResponse(requestData) else {
            return nil
        }
        guard let parsedResponse = AeroSpaceIpcResponseParser.parseFirstResponse(from: responseData) else {
            return nil
        }
        if parsedResponse.exitCode != 0 { return nil }
        return parsedResponse.stdoutContent
    }
}
