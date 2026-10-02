import Foundation
import Testing

@testable import IKCCore

private final class MemoryStore: SecretStore {
  var values: [String: Data] = [:]

  private func key(_ service: String, _ account: String) -> String { "\(service):\(account)" }

  func get(service: String, account: String) throws -> Data {
    guard let value = values[key(service, account)] else { throw IKCError.notFound }
    return value
  }

  func set(_ secret: Data, service: String, account: String) throws {
    if secret.isEmpty { throw IKCError.emptySecret }
    values[key(service, account)] = secret
  }

  func remove(service: String, account: String) throws {
    values.removeValue(forKey: key(service, account))
  }
}

@Test func storeAndReadExactBytes() throws {
  let store = MemoryStore()
  let secret = Data([0, 1, 10, 255])
  let set = try IKCCommand(arguments: ["set", "service", "account"])
  #expect(try set.execute(input: secret, store: store) == Data("stored\n".utf8))
  let get = try IKCCommand(arguments: ["get", "service", "account"])
  #expect(try get.execute(input: Data(), store: store) == secret)
}

@Test func probeCleansUp() throws {
  let store = MemoryStore()
  let probe = try IKCCommand(arguments: ["probe"])
  #expect(try probe.execute(input: Data(), store: store) == Data("ok\n".utf8))
  #expect(store.values.isEmpty)
}

@Test func invalidCommandsAreRejected() {
  #expect(throws: IKCError.invalidArguments) {
    try IKCCommand(arguments: ["set", "", "account"])
  }
  #expect(throws: IKCError.invalidArguments) {
    try IKCCommand(arguments: ["delete", "service", "account"])
  }
}

@Test func emptySecretIsRejected() throws {
  let store = MemoryStore()
  let set = try IKCCommand(arguments: ["set", "service", "account"])
  #expect(throws: IKCError.emptySecret) {
    try set.execute(input: Data(), store: store)
  }
  #expect(store.values.isEmpty)
}
