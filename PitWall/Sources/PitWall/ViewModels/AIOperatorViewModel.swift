import Foundation
import Observation

// MARK: - Chat message model

struct ChatMessage: Identifiable, Sendable {
    let id: UUID
    let role: AIMessage.Role
    var text: String
    var toolCalls: [ToolCall]
    var requiresApproval: Bool
    var approvalAuditId: String?

    init(
        id: UUID = UUID(),
        role: AIMessage.Role,
        text: String = "",
        toolCalls: [ToolCall] = [],
        requiresApproval: Bool = false,
        approvalAuditId: String? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.toolCalls = toolCalls
        self.requiresApproval = requiresApproval
        self.approvalAuditId = approvalAuditId
    }
}

struct ToolCall: Identifiable, Sendable {
    let id: UUID
    let name: String
    var status: String

    init(id: UUID = UUID(), name: String, status: String = "pending") {
        self.id = id
        self.name = name
        self.status = status
    }
}

// MARK: - AIOperatorViewModel

@MainActor
@Observable
final class AIOperatorViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isStreaming: Bool = false
    var error: String?
    var pendingApproval: ChatMessage?

    private let api: PitWallAPI

    static let suggestions = [
        "Who's fastest today?",
        "Start a competition",
        "Show rig status",
        "End session on Rig 3",
        "What's the best lap this week?",
        "How many drivers are active?",
    ]

    init(api: PitWallAPI) {
        self.api = api
        loadHistory()
    }

    // MARK: - Send message

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        inputText = ""
        isStreaming = true
        error = nil

        let userMsg = ChatMessage(role: .user, text: text)
        messages.append(userMsg)

        let assistantMsg = ChatMessage(role: .assistant, text: "")
        messages.append(assistantMsg)
        let assistantIdx = messages.count - 1

        let apiMessages = messages
            .filter { $0.role == .user || ($0.role == .assistant && !$0.text.isEmpty) }
            .dropLast() // exclude the empty assistant placeholder
            .map { AIMessage(role: $0.role, content: $0.text) }

        do {
            let stream = await api.aiChat(messages: Array(apiMessages))
            for try await chunk in stream {
                if Task.isCancelled { break }
                if let text = chunk.text {
                    messages[assistantIdx].text += text
                }
                if let toolName = chunk.toolName {
                    let existing = messages[assistantIdx].toolCalls.first { $0.name == toolName }
                    if existing == nil {
                        messages[assistantIdx].toolCalls.append(
                            ToolCall(name: toolName, status: chunk.toolStatus ?? "pending")
                        )
                    } else if let status = chunk.toolStatus,
                              let idx = messages[assistantIdx].toolCalls.firstIndex(where: { $0.name == toolName }) {
                        messages[assistantIdx].toolCalls[idx].status = status
                    }
                }
                if chunk.done { break }
            }
        } catch {
            messages[assistantIdx].text = "Error: \(error.localizedDescription)"
            self.error = error.localizedDescription
        }

        isStreaming = false
        saveHistory()
    }

    func sendSuggestion(_ text: String) async {
        inputText = text
        await send()
    }

    func approveAction(_ message: ChatMessage) async {
        pendingApproval = nil
        // Re-submit with approval audit ID
        inputText = "Approve action \(message.approvalAuditId ?? "unknown")"
        await send()
    }

    func rejectAction(_ message: ChatMessage) {
        pendingApproval = nil
        let rejection = ChatMessage(role: .user, text: "Action rejected by operator.")
        messages.append(rejection)
    }

    func clearHistory() {
        messages = []
        try? FileManager.default.removeItem(at: Self.historyFileURL)
    }

    // MARK: - History persistence (encrypted file storage)
    //
    // Chat history is written to the app's Documents directory with the
    // `.completeUntilFirstUserAuthentication` Data Protection attribute so the
    // file is encrypted at rest and inaccessible before first unlock.

    private static var historyFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("pitwall_chat_history.json")
    }

    private func saveHistory() {
        let storable = messages.map { msg in
            ["role": msg.role.rawValue, "text": msg.text]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: storable) else { return }
        // Write with Data Protection: file is encrypted until device is unlocked after boot.
        try? data.write(to: Self.historyFileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: Self.historyFileURL),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: String]]
        else { return }

        messages = raw.compactMap { dict in
            guard let roleStr = dict["role"],
                  let role = AIMessage.Role(rawValue: roleStr),
                  let text = dict["text"]
            else { return nil }
            return ChatMessage(role: role, text: text)
        }
    }
}
