import Foundation
#if SWIFT_PACKAGE
  import IKCCore
#endif

do {
  let command = try IKCCommand(arguments: Array(CommandLine.arguments.dropFirst()))
  let input: Data
  if case .set = command {
    input = FileHandle.standardInput.readDataToEndOfFile()
  } else {
    input = Data()
  }
  let output = try command.execute(input: input, store: SyncedKeychain())
  FileHandle.standardOutput.write(output)
} catch {
  let message = errorMessage(error) + "\n"
  FileHandle.standardError.write(Data(message.utf8))
  exit(error as? IKCError == .notFound ? 4 : 1)
}
