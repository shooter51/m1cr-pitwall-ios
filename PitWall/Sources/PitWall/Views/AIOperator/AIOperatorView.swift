import SwiftUI

struct AIOperatorView: View {
    @Environment(MCClient.self) private var mc
    @State private var vm: AIOperatorViewModel?
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        NavigationStack {
            ZStack {
                PW.carbon.ignoresSafeArea()

                if let vm {
                    chatLayout(vm: vm)
                } else {
                    ProgressView().tint(PW.guards)
                }
            }
            .navigationTitle("AI Operator")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if let vm {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            vm.clearHistory()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(PW.silverDim)
                        }
                    }
                }
            }
        }
        .onAppear {
            if vm == nil {
                let api = PitWallAPI(mc: mc)
                vm = AIOperatorViewModel(api: api)
            }
        }
        .sheet(item: Binding(
            get: { vm?.pendingApproval },
            set: { vm?.pendingApproval = $0 }
        )) { msg in
            if let vm {
                ApprovalSheet(message: msg, vm: vm)
            }
        }
    }

    // MARK: - Chat layout

    @ViewBuilder
    private func chatLayout(vm: AIOperatorViewModel) -> some View {
        VStack(spacing: 0) {
            // Suggestions (only when no messages)
            if vm.messages.isEmpty {
                suggestionsSection(vm: vm)
            }

            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }

                        if vm.isStreaming {
                            streamingIndicator
                                .id("streaming")
                        }
                    }
                    .padding(.horizontal, PW.cardPadding)
                    .padding(.vertical, PW.cardPadding)
                }
                .onAppear { scrollProxy = proxy }
                .onChange(of: vm.messages.count) {
                    withAnimation {
                        proxy.scrollTo(vm.messages.last?.id, anchor: .bottom)
                    }
                }
                .onChange(of: vm.isStreaming) {
                    if vm.isStreaming {
                        withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
                    }
                }
            }

            // Error bar
            if let error = vm.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(PW.warn)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(PW.silver)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, PW.cardPadding)
                .padding(.vertical, 8)
                .background(PW.warn.opacity(0.15))
            }

            // Input bar
            inputBar(vm: vm)
        }
    }

    // MARK: - Suggestions

    private func suggestionsSection(vm: AIOperatorViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK ACTIONS")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(PW.silverDim)
                .padding(.horizontal, PW.cardPadding)
                .padding(.top, PW.cardPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AIOperatorViewModel.suggestions, id: \.self) { suggestion in
                        Button {
                            Task { await vm.sendSuggestion(suggestion) }
                        } label: {
                            Text(suggestion)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(PW.silver)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(PW.panel2)
                                .overlay(
                                    Rectangle()
                                        .stroke(PW.guards.opacity(0.4), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, PW.cardPadding)
                .padding(.bottom, 12)
            }

            Divider().background(PW.line)
        }
    }

    // MARK: - Input bar

    private func inputBar(vm: AIOperatorViewModel) -> some View {
        HStack(spacing: 10) {
            TextField("Ask the AI operator…", text: Binding(
                get: { vm.inputText },
                set: { vm.inputText = $0 }
            ))
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(PW.silver)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(PW.panel2)
            .overlay(Rectangle().stroke(PW.lineStrong, lineWidth: 1))
            .disabled(vm.isStreaming)
            .onSubmit {
                Task { await vm.send() }
            }

            Button {
                Task { await vm.send() }
            } label: {
                Image(systemName: vm.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(vm.isStreaming ? PW.warn : PW.guards)
            }
            .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isStreaming)
        }
        .padding(.horizontal, PW.cardPadding)
        .padding(.vertical, 10)
        .background(PW.panel)
        .overlay(alignment: .top) {
            Rectangle().fill(PW.line).frame(height: 1)
        }
    }

    // MARK: - Streaming indicator

    private var streamingIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                AnimatedDot(delay: Double(i) * 0.2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 12)
    }
}

// MARK: - Animated dot for streaming indicator

private struct AnimatedDot: View {
    let delay: Double
    @State private var opacity: Double = 0.3

    var body: some View {
        Circle()
            .fill(PW.silverDim)
            .frame(width: 6, height: 6)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    opacity = 1.0
                }
            }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user { Spacer(minLength: 60) }

            if message.role == .assistant {
                // AI avatar
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(PW.guards)
                    .frame(width: 28, height: 28)
                    .background(PW.guards.opacity(0.15))
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Tool chips
                if !message.toolCalls.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(message.toolCalls) { tool in
                                ToolChip(tool: tool)
                            }
                        }
                    }
                }

                // Message text
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.system(size: 14))
                        .foregroundStyle(PW.silver)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(message.role == .user ? PW.guards.opacity(0.15) : PW.panel)
                        .overlay(
                            Rectangle()
                                .stroke(
                                    message.role == .user ? PW.guards.opacity(0.3) : PW.lineStrong,
                                    lineWidth: 1
                                )
                        )
                        .multilineTextAlignment(message.role == .user ? .trailing : .leading)
                }

                // Approval needed badge
                if message.requiresApproval {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(PW.warn)
                        Text("REQUIRES APPROVAL")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(PW.warn)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PW.warn.opacity(0.1))
                }
            }

            if message.role == .assistant { Spacer(minLength: 60) }
            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(PW.silverDim)
            }
        }
    }
}

// MARK: - Tool chip

struct ToolChip: View {
    let tool: ToolCall

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.system(size: 9))
                .foregroundStyle(statusColor)
            Text(tool.name.uppercased().replacingOccurrences(of: "_", with: " "))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.12))
        .overlay(Rectangle().stroke(statusColor.opacity(0.3), lineWidth: 1))
    }

    private var statusColor: Color {
        switch tool.status {
        case "executed", "success": return PW.ok
        case "requires_approval": return PW.warn
        case "error", "rejected": return PW.guards
        default: return PW.info
        }
    }

    private var statusIcon: String {
        switch tool.status {
        case "executed", "success": return "checkmark.circle.fill"
        case "requires_approval": return "exclamationmark.triangle.fill"
        case "error", "rejected": return "xmark.circle.fill"
        default: return "clock.fill"
        }
    }
}

// MARK: - Approval sheet

struct ApprovalSheet: View {
    let message: ChatMessage
    let vm: AIOperatorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PW.carbon.ignoresSafeArea()

                VStack(alignment: .leading, spacing: PW.sectionSpacing) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(PW.warn)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ACTION REQUIRES APPROVAL")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(PW.silver)
                            Text("The AI operator is requesting to perform a destructive action.")
                                .font(.system(size: 12))
                                .foregroundStyle(PW.silverMid)
                        }
                    }
                    .padding()
                    .background(PW.warn.opacity(0.1))
                    .overlay(Rectangle().stroke(PW.warn.opacity(0.3), lineWidth: 1))

                    Text(message.text)
                        .font(.system(size: 14))
                        .foregroundStyle(PW.silver)
                        .padding()
                        .background(PW.panel)

                    Spacer()

                    HStack(spacing: 12) {
                        Button("REJECT") {
                            vm.rejectAction(message)
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(PW.panel2)
                        .foregroundStyle(PW.silverMid)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))

                        Button("APPROVE") {
                            Task {
                                await vm.approveAction(message)
                                dismiss()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(PW.cardPadding)
            }
            .navigationTitle("Approval Required")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
