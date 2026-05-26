import Testing
import Foundation
@testable import PitWall

@Suite("LobbyNode")
struct LobbyNodeTests {

    private func snakeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private func snakeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }

    @Test("Full payload Codable round-trip")
    func fullPayloadRoundTrip() throws {
        let json = """
        {
          "id": "node-42",
          "parent_id": "parent-1",
          "name": "Paddock-A",
          "slug": "paddock-a",
          "kind": "location",
          "metadata": {
            "track": "Laguna Seca",
            "slots": 10,
            "active": true,
            "extra": null,
            "tags": ["sim", "gt3"],
            "config": {"version": 2}
          },
          "mc": {
            "url": "http://mc.local:8080",
            "is_running": true,
            "started_at": "2026-01-15T10:30:00Z"
          },
          "operator": {
            "device_id": "device-abc",
            "display": "Tom's iPad",
            "attached_at": "2026-01-15T10:31:00Z"
          },
          "live": {
            "active_sessions": 5,
            "active_races": 1,
            "active_postings": 2
          }
        }
        """.data(using: .utf8)!

        let decoder = snakeDecoder()
        let node = try decoder.decode(LobbyNode.self, from: json)

        #expect(node.id == "node-42")
        #expect(node.parentId == "parent-1")
        #expect(node.name == "Paddock-A")
        #expect(node.slug == "paddock-a")
        #expect(node.kind == .location)
        #expect(node.mc.url == "http://mc.local:8080")
        #expect(node.mc.isRunning == true)
        #expect(node.mc.startedAt == "2026-01-15T10:30:00Z")
        #expect(node.operator?.deviceId == "device-abc")
        #expect(node.operator?.display == "Tom's iPad")
        #expect(node.live.activeSessions == 5)
        #expect(node.live.activeRaces == 1)
        #expect(node.live.activePostings == 2)

        // Metadata spot checks
        #expect(node.metadata["track"] == .string("Laguna Seca"))
        #expect(node.metadata["slots"] == .number(10))
        #expect(node.metadata["active"] == .bool(true))
        #expect(node.metadata["extra"] == .null)
        #expect(node.metadata["tags"] == .array([.string("sim"), .string("gt3")]))
        #expect(node.metadata["config"] == .object(["version": .number(2)]))

        // Re-encode and decode to verify round-trip
        let encoder = snakeEncoder()
        let reEncoded = try encoder.encode(node)
        let reDecoded = try decoder.decode(LobbyNode.self, from: reEncoded)
        #expect(reDecoded == node)
    }

    @Test("Org kind decodes correctly")
    func orgKind() throws {
        let json = """
        {
          "id": "org-1",
          "parent_id": null,
          "name": "M1 Circuit",
          "slug": "m1-circuit",
          "kind": "org",
          "metadata": {},
          "mc": {"url": null, "is_running": false, "started_at": null},
          "operator": null,
          "live": {"active_sessions": 0, "active_races": 0, "active_postings": 0}
        }
        """.data(using: .utf8)!

        let node = try snakeDecoder().decode(LobbyNode.self, from: json)

        #expect(node.kind == .org)
        #expect(node.parentId == nil)
        #expect(node.operator == nil)
        #expect(node.mc.url == nil)
        #expect(node.mc.isRunning == false)
    }

    @Test("LobbyNodeList decodes array of nodes")
    func nodeListDecoding() throws {
        let json = """
        {
          "nodes": [
            {
              "id": "n1",
              "parent_id": null,
              "name": "Node 1",
              "slug": "node-1",
              "kind": "location",
              "metadata": {},
              "mc": {"url": null, "is_running": false, "started_at": null},
              "operator": null,
              "live": {"active_sessions": 0, "active_races": 0, "active_postings": 0}
            },
            {
              "id": "n2",
              "parent_id": "n1",
              "name": "Node 2",
              "slug": "node-2",
              "kind": "org",
              "metadata": {},
              "mc": {"url": "http://mc2.local", "is_running": true, "started_at": null},
              "operator": null,
              "live": {"active_sessions": 3, "active_races": 1, "active_postings": 0}
            }
          ]
        }
        """.data(using: .utf8)!

        let list = try snakeDecoder().decode(LobbyNodeList.self, from: json)
        #expect(list.nodes.count == 2)
        #expect(list.nodes[0].id == "n1")
        #expect(list.nodes[1].parentId == "n1")
    }

    @Test("CreateNodeBody encodes correctly")
    func createNodeBodyEncoding() throws {
        let body = CreateNodeBody(name: "Bay B", slug: "bay-b", kind: .location, parentId: "parent-1")
        let encoder = snakeEncoder()
        let data = try encoder.encode(body)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["name"] as? String == "Bay B")
        #expect(dict["slug"] as? String == "bay-b")
        #expect(dict["kind"] as? String == "location")
        #expect(dict["parent_id"] as? String == "parent-1")
    }

    @Test("CreateNodeBody encodes nil parentId as absent or null")
    func createNodeBodyNilParent() throws {
        let body = CreateNodeBody(name: "Root", slug: "root", kind: .org, parentId: nil)
        let encoder = snakeEncoder()
        let data = try encoder.encode(body)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // parentId: nil encodes as either absent or NSNull depending on encoder config
        let value = dict["parent_id"]
        #expect(value == nil || value is NSNull)
    }
}
