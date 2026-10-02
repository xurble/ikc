import Foundation
import Security

public enum IKCError: Error, Equatable {
  case invalidArguments
  case emptySecret
  case notFound
  case keychain(OSStatus)
  case probeMismatch
}

public protocol SecretStore {
  func get(service: String, account: String) throws -> Data
  func set(_ secret: Data, service: String, account: String) throws
  func remove(service: String, account: String) throws
}

public struct SyncedKeychain: SecretStore {
  public init() {}

  private func query(service: String, account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrSynchronizable as String: true,
    ]
  }

  public func get(service: String, account: String) throws -> Data {
    var request = query(service: service, account: account)
    request[kSecReturnData as String] = true
    request[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(request as CFDictionary, &result)
    if status == errSecItemNotFound { throw IKCError.notFound }
    guard status == errSecSuccess else { throw IKCError.keychain(status) }
    guard let data = result as? Data else { throw IKCError.probeMismatch }
    return data
  }

  public func set(_ secret: Data, service: String, account: String) throws {
    if secret.isEmpty { throw IKCError.emptySecret }
    let request = query(service: service, account: account)
    var addition = request
    addition[kSecValueData as String] = secret
    addition[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
    let status = SecItemAdd(addition as CFDictionary, nil)
    if status == errSecDuplicateItem {
      let update = [kSecValueData as String: secret]
      let updateStatus = SecItemUpdate(request as CFDictionary, update as CFDictionary)
      guard updateStatus == errSecSuccess else { throw IKCError.keychain(updateStatus) }
    } else if status != errSecSuccess {
      throw IKCError.keychain(status)
    }
  }

  public func remove(service: String, account: String) throws {
    let status = SecItemDelete(query(service: service, account: account) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw IKCError.keychain(status)
    }
  }
}

public enum IKCCommand: Equatable {
  case get(String, String)
  case set(String, String)
  case probe

  public init(arguments: [String]) throws {
    if arguments == ["probe"] {
      self = .probe
    } else if arguments.count == 3, arguments[0] == "get" || arguments[0] == "set" {
      let service = arguments[1]
      let account = arguments[2]
      guard !service.isEmpty, !account.isEmpty else { throw IKCError.invalidArguments }
      self = arguments[0] == "get" ? .get(service, account) : .set(service, account)
    } else {
      throw IKCError.invalidArguments
    }
  }

  public func execute(input: Data, store: any SecretStore) throws -> Data {
    switch self {
    case .get(let service, let account):
      return try store.get(service: service, account: account)
    case .set(let service, let account):
      try store.set(input, service: service, account: account)
      return Data("stored\n".utf8)
    case .probe:
      let service = "ikc-probe-\(UUID().uuidString)"
      let account = "probe"
      let sample = Data(UUID().uuidString.utf8)
      try store.set(sample, service: service, account: account)
      let received: Data
      do {
        received = try store.get(service: service, account: account)
      } catch {
        try? store.remove(service: service, account: account)
        throw error
      }
      try store.remove(service: service, account: account)
      guard received == sample else {
        throw IKCError.probeMismatch
      }
      return Data("ok\n".utf8)
    }
  }
}

public func errorMessage(_ error: Error) -> String {
  guard let error = error as? IKCError else { return "Unexpected error." }
  switch error {
  case .invalidArguments:
    return "Usage: ikc get SERVICE ACCOUNT | ikc set SERVICE ACCOUNT < secret | ikc probe"
  case .emptySecret:
    return "Refusing to store an empty secret."
  case .notFound:
    return "No synced Keychain item matches that service and account."
  case .keychain(let status):
    let detail = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error"
    return "Keychain error \(status): \(detail)"
  case .probeMismatch:
    return "Keychain returned unexpected data."
  }
}
