import Foundation
import Observation

@Observable
final class RaceWallViewModel: @unchecked Sendable {
    private(set) var postings: [RacePosting] = []
    private(set) var error: String?

    private let mc: MCClient

    init(mc: MCClient) {
        self.mc = mc
    }

    @MainActor
    func load() async {
        guard let base = mc.attachedMCURL else { return }
        var request = URLRequest(url: base.appendingPathComponent("/api/race-wall"))
        mc.authorize(&request)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                error = "Race wall: \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                return
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            postings = (try decoder.decode(RacePostingList.self, from: data)).postings
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func join(posting: RacePosting, driverName: String) async {
        guard let base = mc.attachedMCURL else { return }
        var request = URLRequest(url: base.appendingPathComponent("/api/race-wall/\(posting.id)/join"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        mc.authorize(&request)
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["driver_name": driverName])
        do {
            _ = try await URLSession.shared.data(for: request)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func pushToDisplay(posting: RacePosting, displayId: String) async {
        guard let base = mc.attachedMCURL else { return }
        var request = URLRequest(url: base.appendingPathComponent("/api/race-wall/\(posting.id)/display"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        mc.authorize(&request)
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["display_id": displayId])
        _ = try? await URLSession.shared.data(for: request)
    }
}
