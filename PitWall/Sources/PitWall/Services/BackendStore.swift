import Foundation
import Observation

/// Persists the set of known backends + which one is current.
/// Metadata (name, URL, etc.) is stored in UserDefaults; client keys are stored
/// in the Keychain under "com.m1circuit.pitwall" with account "<uuid>.clientKey".
@MainActor
@Observable
final class BackendStore {
    private(set) var backends: [Backend]
    private(set) var currentId: UUID?

    private let defaults: UserDefaults
    private let backendsKey = "pitwall.backends.v1"
    private let currentKey  = "pitwall.backends.currentId.v1"

    /// `defaultSeed` is consulted only on a totally empty store — provides the
    /// M1 Circuit default that came from `Secrets.xcconfig` at build time.
    init(defaults: UserDefaults = .standard, defaultSeed: Backend? = nil) {
        self.defaults = defaults

        let stored: [Backend] = (try? defaults.data(forKey: backendsKey)
            .map { try JSONDecoder().decode([Backend].self, from: $0) }) ?? nil ?? []

        if stored.isEmpty, let seed = defaultSeed {
            self.backends = [seed]
            self.currentId = seed.id
            persist([seed])
        } else {
            // Rehydrate clientKeys from Keychain.
            let rehydrated = stored.map { backend -> Backend in
                if let key = KeychainHelper.read(account: "\(backend.id.uuidString).clientKey") {
                    var copy = backend
                    copy.clientKey = key
                    return copy
                }
                return backend
            }
            self.backends = rehydrated
            if let currentRaw = defaults.string(forKey: currentKey),
               let uuid = UUID(uuidString: currentRaw),
               rehydrated.contains(where: { $0.id == uuid }) {
                self.currentId = uuid
            } else {
                self.currentId = rehydrated.first?.id
            }
        }
    }

    var current: Backend? {
        guard let id = currentId else { return nil }
        return backends.first { $0.id == id }
    }

    func add(_ backend: Backend) {
        backends.append(backend)
        persist(backends)
    }

    func update(_ backend: Backend) {
        guard let idx = backends.firstIndex(where: { $0.id == backend.id }) else { return }
        backends[idx] = backend
        persist(backends)
    }

    func remove(id: UUID) {
        backends.removeAll { $0.id == id }
        KeychainHelper.delete(account: "\(id.uuidString).clientKey")
        if currentId == id { currentId = backends.first?.id }
        persist(backends)
    }

    func setCurrent(_ id: UUID) {
        guard backends.contains(where: { $0.id == id }) else { return }
        currentId = id
        if let idx = backends.firstIndex(where: { $0.id == id }) {
            backends[idx].lastConnectedAt = Date()
        }
        persist(backends)
    }

    // MARK: - Private

    private func persist(_ currentBackends: [Backend]) {
        // Store clientKeys in Keychain; strip them from UserDefaults data.
        for backend in currentBackends {
            KeychainHelper.write(backend.clientKey, account: "\(backend.id.uuidString).clientKey")
        }

        // Encode backends with empty clientKey so plaintext key never hits UserDefaults.
        let sanitised = currentBackends.map { b -> Backend in
            var copy = b
            copy.clientKey = ""
            return copy
        }
        if let data = try? JSONEncoder().encode(sanitised) {
            defaults.set(data, forKey: backendsKey)
        }
        if let id = currentId {
            defaults.set(id.uuidString, forKey: currentKey)
        } else {
            defaults.removeObject(forKey: currentKey)
        }
    }
}
