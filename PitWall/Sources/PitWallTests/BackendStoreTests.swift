import Testing
import Foundation
@testable import PitWall

@Suite("BackendStore")
struct BackendStoreTests {

    private func makeDefaults() -> UserDefaults {
        let suite = "com.pitwall.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func makeSeed() -> Backend {
        Backend(
            name: "Test Server",
            lobbyURL: URL(string: "https://pitwall.test.com")!,
            clientKey: "test-key-123"
        )
    }

    @MainActor
    @Test("Init with seed populates store on empty defaults")
    func initWithSeed() {
        let seed = makeSeed()
        let store = BackendStore(defaults: makeDefaults(), defaultSeed: seed)

        #expect(store.backends.count == 1)
        #expect(store.backends.first?.name == "Test Server")
        #expect(store.currentId == seed.id)
        #expect(store.current?.clientKey == "test-key-123")
    }

    @MainActor
    @Test("Init without seed on empty defaults yields empty store")
    func initEmpty() {
        let store = BackendStore(defaults: makeDefaults(), defaultSeed: nil)

        #expect(store.backends.isEmpty)
        #expect(store.currentId == nil)
        #expect(store.current == nil)
    }

    @MainActor
    @Test("Add backend appends to list")
    func addBackend() {
        let store = BackendStore(defaults: makeDefaults(), defaultSeed: nil)
        let backend = makeSeed()
        store.add(backend)

        #expect(store.backends.count == 1)
        #expect(store.backends.first?.id == backend.id)
    }

    @MainActor
    @Test("Remove backend by id")
    func removeBackend() {
        let seed = makeSeed()
        let store = BackendStore(defaults: makeDefaults(), defaultSeed: seed)
        store.remove(id: seed.id)

        #expect(store.backends.isEmpty)
        #expect(store.currentId == nil)
    }

    @MainActor
    @Test("setCurrent changes current id")
    func setCurrent() {
        let store = BackendStore(defaults: makeDefaults(), defaultSeed: nil)
        let b1 = Backend(name: "A", lobbyURL: URL(string: "https://a.com")!, clientKey: "k1")
        let b2 = Backend(name: "B", lobbyURL: URL(string: "https://b.com")!, clientKey: "k2")
        store.add(b1)
        store.add(b2)
        store.setCurrent(b1.id)

        #expect(store.currentId == b1.id)
        #expect(store.current?.name == "A")

        store.setCurrent(b2.id)
        #expect(store.currentId == b2.id)
        #expect(store.current?.name == "B")
    }

    @MainActor
    @Test("setCurrent ignores unknown id")
    func setCurrentUnknown() {
        let seed = makeSeed()
        let store = BackendStore(defaults: makeDefaults(), defaultSeed: seed)
        let unknownId = UUID()
        store.setCurrent(unknownId)

        #expect(store.currentId == seed.id)
    }

    @MainActor
    @Test("Persist and reload round-trip")
    func persistReload() {
        let defaults = makeDefaults()
        let seed = makeSeed()

        let store1 = BackendStore(defaults: defaults, defaultSeed: seed)
        let b2 = Backend(name: "Second", lobbyURL: URL(string: "https://second.com")!, clientKey: "k2")
        store1.add(b2)
        store1.setCurrent(b2.id)

        // Reload from same defaults — should recover state
        let store2 = BackendStore(defaults: defaults, defaultSeed: nil)

        #expect(store2.backends.count == 2)
        #expect(store2.currentId == b2.id)
        #expect(store2.current?.name == "Second")
    }
}
