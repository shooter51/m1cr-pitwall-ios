import Testing
import Foundation
@testable import PitWall

// MARK: - AIOperatorViewModel tests
// Tests message management, tool parsing, and chat history.
// The AI endpoint requires auth — network tests accept 401/403 gracefully.

@Suite("AIOperatorViewModel")
struct AIOperatorViewModelTests {
    let baseURL = URL(string: "https://pitwall.m1circuit.com")!

    @MainActor
    private func makeVM() -> AIOperatorViewModel {
        let mc = MCClient(
            clientKey: "test-key",
            lobbyURL: URL(string: "https://pitwall.m1circuit.com")!,
            deviceId: "test-device"
        )
        let api = PitWallAPI(mc: mc)
        return AIOperatorViewModel(api: api)
    }

    // MARK: - ChatMessage

    @Test("ChatMessage initialises with default values")
    func chatMessageDefaults() {
        let msg = ChatMessage(role: .user, text: "Hello")
        #expect(msg.role == .user)
        #expect(msg.text == "Hello")
        #expect(msg.toolCalls.isEmpty)
        #expect(msg.requiresApproval == false)
        #expect(msg.approvalAuditId == nil)
    }

    @Test("ChatMessage with tool calls stores them correctly")
    func chatMessageWithToolCalls() {
        let tool1 = ToolCall(name: "list_rigs", status: "executed")
        let tool2 = ToolCall(name: "start_session", status: "requires_approval")
        let msg = ChatMessage(
            role: .assistant,
            text: "I'll check the rigs.",
            toolCalls: [tool1, tool2],
            requiresApproval: true,
            approvalAuditId: "audit-123"
        )
        #expect(msg.toolCalls.count == 2)
        #expect(msg.toolCalls[0].name == "list_rigs")
        #expect(msg.toolCalls[1].status == "requires_approval")
        #expect(msg.requiresApproval == true)
        #expect(msg.approvalAuditId == "audit-123")
    }

    // MARK: - ToolCall

    @Test("ToolCall initialises with pending status by default")
    func toolCallDefaultStatus() {
        let tool = ToolCall(name: "get_standings")
        #expect(tool.name == "get_standings")
        #expect(tool.status == "pending")
    }

    @Test("ToolCall can be mutated")
    func toolCallMutation() {
        var tool = ToolCall(name: "end_session", status: "pending")
        tool.status = "executed"
        #expect(tool.status == "executed")
    }

    // MARK: - AIMessage.Role

    @Test("AIMessage.Role raw values are correct")
    func aiMessageRoleRawValues() {
        #expect(AIMessage.Role.user.rawValue == "user")
        #expect(AIMessage.Role.assistant.rawValue == "assistant")
    }

    // MARK: - Suggestions

    @Test("AIOperatorViewModel has at least 4 suggestion chips")
    func suggestionsAvailable() {
        #expect(AIOperatorViewModel.suggestions.count >= 4)
        for suggestion in AIOperatorViewModel.suggestions {
            #expect(!suggestion.isEmpty)
        }
    }

    // MARK: - ViewModel state

    @MainActor
    @Test("AIOperatorViewModel starts with empty messages")
    func initialState() {
        let vm = makeVM()
        vm.clearHistory()

        #expect(vm.messages.isEmpty)
        #expect(vm.inputText.isEmpty)
        #expect(vm.isStreaming == false)
        #expect(vm.error == nil)
    }

    @MainActor
    @Test("clearHistory removes all messages")
    func clearHistoryRemovesMessages() {
        let vm = makeVM()

        let msg = ChatMessage(role: .user, text: "test")
        vm.messages.append(msg)
        #expect(vm.messages.count > 0)

        vm.clearHistory()
        #expect(vm.messages.isEmpty)
    }

    @MainActor
    @Test("rejectAction appends a rejection message")
    func rejectActionAppendsMessage() async {
        let vm = makeVM()
        vm.clearHistory()

        let approvalMsg = ChatMessage(role: .assistant, text: "I want to end session", requiresApproval: true)
        vm.rejectAction(approvalMsg)

        #expect(vm.messages.last?.role == .user)
        #expect(vm.messages.last?.text.contains("rejected") == true)
        #expect(vm.pendingApproval == nil)
    }

    @MainActor
    @Test("send with empty input does not append message")
    func sendWithEmptyInputIsNoOp() async {
        let vm = makeVM()
        vm.clearHistory()
        vm.inputText = "   " // whitespace only

        await vm.send()

        #expect(vm.messages.isEmpty)
    }

    // MARK: - AIChunk parsing

    @Test("AIChunk with text creates non-empty text chunk")
    func aiChunkTextParsing() {
        let chunk = AIChunk(text: "Hello world", toolName: nil, toolStatus: nil, done: false)
        #expect(chunk.text == "Hello world")
        #expect(chunk.toolName == nil)
        #expect(chunk.done == false)
    }

    @Test("AIChunk with tool data stores tool info")
    func aiChunkToolParsing() {
        let chunk = AIChunk(text: nil, toolName: "list_rigs", toolStatus: "executed", done: false)
        #expect(chunk.text == nil)
        #expect(chunk.toolName == "list_rigs")
        #expect(chunk.toolStatus == "executed")
    }

    @Test("AIChunk done flag signals completion")
    func aiChunkDoneFlag() {
        let chunk = AIChunk(text: nil, toolName: nil, toolStatus: nil, done: true)
        #expect(chunk.done == true)
    }
}
