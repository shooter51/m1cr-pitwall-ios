import Foundation
import Observation

@MainActor
@Observable
final class LobbyViewModel {
    enum State {
        case idle
        case loading
        case ready
        case error(String)
    }

    private(set) var state: State = .idle
    private(set) var nodes: [LobbyNode] = []
    private(set) var spawningNodeIds: Set<String> = []

    private let lobby: LobbyClient
    private let mc: MCClient
    private var eventTask: Task<Void, Never>?

    init(lobby: LobbyClient, mc: MCClient) {
        self.lobby = lobby
        self.mc = mc
    }

    @MainActor
    func load() async {
        state = .loading
        do {
            let nodes = try await lobby.listNodes()
            self.nodes = nodes
            self.state = .ready
        } catch {
            self.state = .error(error.localizedDescription)
        }
    }

    @MainActor
    func attach(to node: LobbyNode) async {
        // If MC isn't running, spawn first.
        if !node.mc.isRunning {
            spawningNodeIds.insert(node.id)
            defer { spawningNodeIds.remove(node.id) }
            do {
                try await lobby.spawn(nodeId: node.id)
                // Brief delay for the container to come up.
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await load()
            } catch {
                state = .error("Spawn failed: \(error.localizedDescription)")
                return
            }
        }

        // Re-fetch nodes to get the authoritative post-spawn state, then attach.
        // Doing this before the attach call avoids a race where the cached nodes
        // array may not yet reflect the spawned container's URL.
        await load()

        do {
            try await lobby.attach(nodeId: node.id)
        } catch {
            state = .error("Attach failed: \(error.localizedDescription)")
            return
        }

        // Use the freshly fetched node, falling back to the original if not found.
        if let refreshed = nodes.first(where: { $0.id == node.id }) {
            mc.attach(to: refreshed)
        } else {
            mc.attach(to: node)
        }
    }

    @MainActor
    func rename(_ node: LobbyNode, to newName: String) async {
        do {
            _ = try await lobby.updateNode(id: node.id, fields: ["name": newName])
            await load()
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    @MainActor
    func delete(_ node: LobbyNode) async {
        do {
            try await lobby.deleteNode(id: node.id)
            await load()
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    @MainActor
    func createNode(name: String, slug: String, kind: LobbyNode.Kind) async throws -> LobbyNode {
        let body = CreateNodeBody(name: name, slug: slug, kind: kind, parentId: nil)
        let node = try await lobby.createNode(body)
        await load()
        return node
    }

    @MainActor
    func startEventStream() {
        eventTask?.cancel()
        let stream = lobby.eventStream()
        eventTask = Task { @MainActor in
            do {
                for try await event in stream {
                    handle(event)
                }
            } catch {
                state = .error("Event stream error: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    func stopEventStream() {
        eventTask?.cancel()
        eventTask = nil
    }

    @MainActor
    private func handle(_ event: LobbyEvent) {
        switch event.type {
        case "node.added", "node.spawned", "node.stopped",
             "operator.attached", "operator.detached":
            Task { await self.load() }
        case "ready":
            break
        default:
            break
        }
    }
}
