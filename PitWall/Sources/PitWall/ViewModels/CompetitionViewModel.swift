import Foundation
import Observation

@MainActor
@Observable
final class CompetitionViewModel {
    var competitions: [Competition] = []
    var isLoading = false
    var error: String?

    private let api: PitWallAPI

    init(mc: MCClient) {
        self.api = PitWallAPI(mc: mc)
    }

    func loadCompetitions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await api.competitions()
            guard !Task.isCancelled else { return }
            competitions = result
        } catch {
            self.error = error.localizedDescription
        }
    }

    func create(params: CreateCompetitionParams) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await api.createCompetition(params)
            // Reload full list after creation since the POST only returns partial data.
            await loadCompetitions()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
