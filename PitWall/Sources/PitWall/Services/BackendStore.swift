import Foundation
import Observation

/// Persists the set of known backends + which one is current.
/// Storage is UserDefaults (small JSON blob); the client key lives alongside
/// because this is a closed-loop family network and the device is already trusted
/// to hold it (matches the shared-key threat model from the PRD).
@Observable
final class BackendStore: @unchecked Sendable {
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
            persist()
        } else {
            self.backends = stored
            if let currentRaw = defaults.string(forKey: currentKey),
               let uuid = UUID(uuidString: currentRaw),
               stored.contains(where: { $0.id == uuid }) {
                self.currentId = uuid
            } else {
                self.currentId = stored.first?.id
            }
        }
    }

    var current: Backend? {
        guard let id = currentId else { return nil }
        return backends.first { $0.id == id }
    }

    func add(_ backend: Backend) {
        backends.append(backend)
        persist()
    }

    func update(_ backend: Backend) {
        guard let idx = backends.firstIndex(where: { $0.id == backend.id }) else { return }
        backends[idx] = backend
        persist()
    }

    func remove(id: UUID) {
        backends.removeAll { $0.id == id }
        if currentId == id { currentId = backends.first?.id }
        persist()
    }

    func setCurrent(_ id: UUID) {
        guard backends.contains(where: { $0.id == id }) else { return }
        currentId = id
        if let idx = backends.firstIndex(where: { $0.id == id }) {
            backends[idx].lastConnectedAt = Date()
        }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(backends) {
            defaults.set(data, forKey: backendsKey)
        }
        if let id = currentId {
            defaults.set(id.uuidString, forKey: currentKey)
        } else {
            defaults.removeObject(forKey: currentKey)
        }
    }
}
