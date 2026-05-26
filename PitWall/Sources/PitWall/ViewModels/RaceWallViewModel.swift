import Foundation
import Observation

@MainActor
@Observable
final class RaceWallViewModel {
    private(set) var postings: [RacePosting] = []
    private(set) var error: String?

    private let api: PitWallAPI

    init(mc: MCClient) {
        self.api = PitWallAPI(mc: mc)
    }

    func load() async {
        do {
            let result = try await api.raceWallPostings()
            guard !Task.isCancelled else { return }
            postings = result
        } catch {
            self.error = error.localizedDescription
        }
    }

    func join(posting: RacePosting, driverName: String) async {
        do {
            try await api.joinPosting(id: posting.id, driverName: driverName)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func pushToDisplay(posting: RacePosting, displayId: String) async {
        do {
            try await api.pushPostingToDisplay(id: posting.id, displayId: displayId)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
