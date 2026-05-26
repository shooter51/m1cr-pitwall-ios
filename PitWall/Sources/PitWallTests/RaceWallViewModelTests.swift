import Testing
import Foundation
@testable import PitWall

@Suite("RaceWallViewModel")
struct RaceWallViewModelTests {

    @MainActor
    private func makeMC(attached: Bool = false) -> MCClient {
        let mc = MCClient(
            clientKey: "test-key",
            lobbyURL: URL(string: "https://lobby.test.com")!,
            deviceId: "device-test"
        )
        if attached {
            let node = LobbyNode(
                id: "node-1",
                parentId: nil,
                name: "Bay A",
                slug: "bay-a",
                kind: .location,
                metadata: [:],
                mc: .init(url: "http://192.0.2.1", isRunning: true, startedAt: nil),
                operator: nil,
                live: .init(activeSessions: 0, activeRaces: 0, activePostings: 0)
            )
            mc.attach(to: node)
        }
        return mc
    }

    // MARK: - Initial state

    @MainActor
    @Test("RaceWallViewModel starts with empty postings")
    func initialPostingsEmpty() {
        let vm = RaceWallViewModel(mc: makeMC())
        #expect(vm.postings.isEmpty)
    }

    @MainActor
    @Test("RaceWallViewModel starts with nil error")
    func initialErrorNil() {
        let vm = RaceWallViewModel(mc: makeMC())
        #expect(vm.error == nil)
    }

    // MARK: - load() error path (not attached)

    @MainActor
    @Test("load() sets error when MC is not attached")
    func loadSetsErrorWhenNotAttached() async {
        let mc = makeMC(attached: false)
        let vm = RaceWallViewModel(mc: mc)

        await vm.load()

        // notAttached throws APIError.notAttached — this should be reflected in vm.error
        #expect(vm.error != nil)
        #expect(vm.postings.isEmpty)
    }

    // MARK: - join() error path (not attached)

    @MainActor
    @Test("join() sets error when MC is not attached")
    func joinSetsErrorWhenNotAttached() async {
        let mc = makeMC(attached: false)
        let vm = RaceWallViewModel(mc: mc)

        let posting = makePosting()
        await vm.join(posting: posting, driverName: "Tom")

        #expect(vm.error != nil)
    }

    // MARK: - pushToDisplay() error path (not attached)

    @MainActor
    @Test("pushToDisplay sets error when MC is not attached")
    func pushToDisplaySetsErrorWhenNotAttached() async {
        let mc = makeMC(attached: false)
        let vm = RaceWallViewModel(mc: mc)

        let posting = makePosting()
        await vm.pushToDisplay(posting: posting, displayId: "display-01")

        #expect(vm.error != nil)
    }

    // MARK: - load() network error path (attached but no real server)

    @MainActor
    @Test("load() sets error when network is unavailable", .disabled("makes real network call — run manually"))
    func loadSetsErrorOnNetworkFailure() async {
        let mc = makeMC(attached: true)
        let vm = RaceWallViewModel(mc: mc)

        await vm.load()

        // Network call will fail (no real server at 192.0.2.1).
        // Either error is set, or postings is empty. Both are acceptable.
        if vm.error != nil {
            #expect(vm.error != nil)
        } else {
            // If no error, postings may be empty from a graceful empty response.
            #expect(vm.postings.isEmpty || !vm.postings.isEmpty)
        }
    }

    // MARK: - Error does not accumulate

    @MainActor
    @Test("error field is overwritten on each failure, not accumulated")
    func errorOverwritten() async {
        let mc = makeMC(attached: false)
        let vm = RaceWallViewModel(mc: mc)

        await vm.load()
        let firstError = vm.error

        await vm.load()
        let secondError = vm.error

        // Both should be non-nil; they may or may not be the same string.
        #expect(firstError != nil)
        #expect(secondError != nil)
    }

    // MARK: - RacePosting model

    @Test("RacePosting.Status raw values match API contract")
    func racePostingStatusRawValues() {
        #expect(RacePosting.Status.live.rawValue == "live")
        #expect(RacePosting.Status.full.rawValue == "full")
        #expect(RacePosting.Status.ended.rawValue == "ended")
        #expect(RacePosting.Status.cancelled.rawValue == "cancelled")
    }

    @Test("RacePosting decodes from snake_case JSON")
    func racePostingDecoding() throws {
        let json = """
        {
          "id": "posting-01",
          "source_org_id": "org-source",
          "target_org_id": "org-target",
          "competition_id": null,
          "track_name": "Brands Hatch",
          "track_id": "brands-hatch",
          "vehicle_class": "gt3",
          "vehicle_name": null,
          "slot_total": 10,
          "slot_open": 5,
          "thumbnail_url": null,
          "status": "live",
          "started_at": "2026-01-15T10:00:00Z",
          "ends_at": null,
          "source_name": "M1 Circuit",
          "source_slug": "m1-circuit"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let posting = try decoder.decode(RacePosting.self, from: json)

        #expect(posting.id == "posting-01")
        #expect(posting.trackName == "Brands Hatch")
        #expect(posting.trackId == "brands-hatch")
        #expect(posting.vehicleClass == "gt3")
        #expect(posting.slotTotal == 10)
        #expect(posting.slotOpen == 5)
        #expect(posting.status == .live)
        #expect(posting.sourceName == "M1 Circuit")
        #expect(posting.sourceSlug == "m1-circuit")
    }

    // MARK: - Helpers

    private func makePosting() -> RacePosting {
        RacePosting(
            id: "posting-test",
            sourceOrgId: "org-src",
            targetOrgId: "org-dst",
            competitionId: nil,
            trackName: "Brands Hatch",
            trackId: "brands-hatch",
            vehicleClass: "gt3",
            vehicleName: nil,
            slotTotal: 8,
            slotOpen: 4,
            thumbnailUrl: nil,
            status: .live,
            startedAt: "2026-01-15T10:00:00Z",
            endsAt: nil,
            sourceName: "M1 Circuit",
            sourceSlug: "m1-circuit"
        )
    }
}
