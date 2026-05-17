import Foundation

final class PerformanceLogFileAppender {
    private let logFilePath: String

    init(logFilePath: String) {
        self.logFilePath = logFilePath
    }

    func appendLine(_ line: String) {
        let data = Data(line.utf8)
        if let fileHandle = FileHandle(forWritingAtPath: logFilePath) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            try? fileHandle.close()
        } else {
            FileManager.default.createFile(atPath: logFilePath, contents: data)
        }
    }
}
