import Testing
import Foundation
@testable import PitWall

// KeychainHelper wraps the real SecItem APIs.
// Tests use a unique account key per test to avoid collisions.
//
// NOTE: Keychain write operations require entitlements that are only available
// when running on a device or in Xcode. Tests that depend on writes are skipped
// when the write returns false (indicating missing entitlements in CLI `swift test`).

@Suite("KeychainHelper")
struct KeychainHelperTests {

    // Generate a unique account for each test call to avoid cross-test pollution.
    private func uniqueAccount() -> String {
        "test.\(UUID().uuidString)"
    }

    // Always clean up by deleting the test account.
    private func cleanup(account: String) {
        KeychainHelper.delete(account: account)
    }

    // Returns true when the Keychain is accessible (write succeeds).
    private func keychainAvailable() -> Bool {
        let probe = "test.\(UUID().uuidString)"
        let ok = KeychainHelper.write("probe", account: probe)
        KeychainHelper.delete(account: probe)
        return ok
    }

    // MARK: - Write and Read

    @Test("Write and read back a string value")
    func writeAndRead() throws {
        try #require(keychainAvailable(), "Keychain not accessible in this environment (needs entitlements)")
        let account = uniqueAccount()
        defer { cleanup(account: account) }

        let written = KeychainHelper.write("hello-keychain", account: account)
        #expect(written == true)

        let value = KeychainHelper.read(account: account)
        #expect(value == "hello-keychain")
    }

    @Test("Read returns nil for a missing key")
    func readMissingKey() {
        let account = uniqueAccount()
        // Do not write anything — account should not exist.
        let value = KeychainHelper.read(account: account)
        #expect(value == nil)
    }

    @Test("Delete removes a stored value")
    func deleteRemovesValue() throws {
        try #require(keychainAvailable(), "Keychain not accessible in this environment (needs entitlements)")
        let account = uniqueAccount()

        KeychainHelper.write("to-be-deleted", account: account)
        let deleted = KeychainHelper.delete(account: account)
        #expect(deleted == true)

        let value = KeychainHelper.read(account: account)
        #expect(value == nil)
    }

    @Test("Delete returns true for a non-existent key (idempotent)")
    func deleteNonExistent() {
        let account = uniqueAccount()
        // Nothing was written — delete should still succeed (errSecItemNotFound is treated as success).
        let result = KeychainHelper.delete(account: account)
        #expect(result == true)
    }

    @Test("Overwrite existing value updates stored data")
    func overwriteUpdatesValue() throws {
        try #require(keychainAvailable(), "Keychain not accessible in this environment (needs entitlements)")
        let account = uniqueAccount()
        defer { cleanup(account: account) }

        KeychainHelper.write("initial-value", account: account)
        let updated = KeychainHelper.write("updated-value", account: account)
        #expect(updated == true)

        let value = KeychainHelper.read(account: account)
        #expect(value == "updated-value")
    }

    @Test("Write preserves unicode strings")
    func writeUnicode() throws {
        try #require(keychainAvailable(), "Keychain not accessible in this environment (needs entitlements)")
        let account = uniqueAccount()
        defer { cleanup(account: account) }

        let unicode = "🏎️ Laguna Seca — M1 Circuit"
        KeychainHelper.write(unicode, account: account)

        let value = KeychainHelper.read(account: account)
        #expect(value == unicode)
    }

    @Test("Multiple accounts stored independently")
    func multipleAccountsAreIndependent() throws {
        try #require(keychainAvailable(), "Keychain not accessible in this environment (needs entitlements)")
        let account1 = uniqueAccount()
        let account2 = uniqueAccount()
        defer {
            cleanup(account: account1)
            cleanup(account: account2)
        }

        KeychainHelper.write("value-one", account: account1)
        KeychainHelper.write("value-two", account: account2)

        #expect(KeychainHelper.read(account: account1) == "value-one")
        #expect(KeychainHelper.read(account: account2) == "value-two")
    }

    @Test("Read after delete returns nil")
    func readAfterDelete() throws {
        try #require(keychainAvailable(), "Keychain not accessible in this environment (needs entitlements)")
        let account = uniqueAccount()

        KeychainHelper.write("temporary", account: account)
        KeychainHelper.delete(account: account)

        #expect(KeychainHelper.read(account: account) == nil)
    }
}
