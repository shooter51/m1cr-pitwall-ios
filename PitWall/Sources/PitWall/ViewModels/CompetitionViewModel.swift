import Foundation
import Observation

@Observable
final class CompetitionViewModel {
    var competitions: [Competition] = []
    var isLoading = false
    var error: String?

    private let mc: MCClient

    init(mc: MCClient) {
        self.mc = mc
    }

    private var api: PitWallAPI {
        PitWallAPI(mc: mc)
    }

    @MainActor
    func loadCompetitions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            competitions = try await api.competitions()
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func create(params: CreateCompetitionParams) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            let newComp = try await api.createCompetition(params)
            competitions.insert(newComp, at: 0)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
