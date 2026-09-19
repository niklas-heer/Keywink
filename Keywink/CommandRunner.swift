import Cocoa

class CommandRunner {
  struct Execution {
    let terminationStatus: Int32
    let standardOutput: Data
    let standardError: Data
  }

  private static let executionQueue = DispatchQueue(
    label: "de.niklas-heer.Keywink.command-runner",
    qos: .userInitiated)

  static func run(_ command: String) {
    execute(command) { result in
      switch result {
      case .success(let execution) where execution.terminationStatus != 0:
        let error = String(data: execution.standardError, encoding: .utf8) ?? ""
        let output = String(data: execution.standardOutput, encoding: .utf8) ?? ""

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Command failed with exit code \(execution.terminationStatus)"
        alert.informativeText = [error, output].joined(separator: "\n").trimmingCharacters(
          in: .whitespacesAndNewlines)
        alert.runModal()
      case .failure(let error):
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Failed to run command"
        alert.informativeText = error.localizedDescription
        alert.runModal()
      default:
        break
      }
    }
  }

  static func execute(
    _ command: String,
    completion: @escaping (Swift.Result<Execution, Error>) -> Void
  ) {
    executionQueue.async {
      let result = Swift.Result { try executeSynchronously(command) }
      DispatchQueue.main.async {
        completion(result)
      }
    }
  }

  private static func executeSynchronously(_ command: String) throws -> Execution {
    let fileManager = FileManager.default
    let temporaryDirectory = fileManager.temporaryDirectory.appendingPathComponent(
      "Keywink-Command-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(
      at: temporaryDirectory, withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700])
    defer { try? fileManager.removeItem(at: temporaryDirectory) }

    let outputURL = temporaryDirectory.appendingPathComponent("stdout")
    let errorURL = temporaryDirectory.appendingPathComponent("stderr")
    try Data().write(to: outputURL)
    try Data().write(to: errorURL)

    let outputHandle = try FileHandle(forWritingTo: outputURL)
    let errorHandle = try FileHandle(forWritingTo: errorURL)
    defer {
      try? outputHandle.close()
      try? errorHandle.close()
    }

    let task = Process()
    task.standardOutput = outputHandle
    task.standardError = errorHandle
    task.executableURL = URL(
      fileURLWithPath: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/sh")
    task.arguments = ["-c", command]

    try task.run()
    task.waitUntilExit()
    try outputHandle.close()
    try errorHandle.close()

    return Execution(
      terminationStatus: task.terminationStatus,
      standardOutput: try Data(contentsOf: outputURL),
      standardError: try Data(contentsOf: errorURL))
  }
}
