import SwiftUI

// MARK: - AIOperatorView

struct AIOperatorView: View {
    @Environment(MCClient.self) private var mc
    @State private var vm: AIOperatorViewModel?
    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if let vm {
                twoColumnLayout(vm: vm)
            } else {
                Spacer()
                ProgressView().tint(PW.guards)
                Spacer()
            }
        }
        .background(PW.carbon)
        .onAppear {
            if vm == nil {
                let api = PitWallAPI(mc: mc)
                vm = AIOperatorViewModel(api: api)
            }
        }
        .alert("Clear conversation?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { vm?.clearHistory() }
        } message: {
            Text("This will remove all messages in this session.")
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        PWTopBar(eyebrow: "AI · OPERATOR", title: "RACE ENGINEER") {
            HStack(spacing: 6) {
                Circle().fill(PW.ok).frame(width: 6, height: 6)
                Text("MODEL · CLAUDE SONNET 4.5")
                    .font(PW.FontStyle.mono(10, weight: .semibold))
                    .foregroundColor(PW.silverMid)
                    .tracking(1.6)
            }
            PWTopBarDivider()
            Text("CONTEXT · 8.4K TOKENS")
                .font(PW.FontStyle.mono(10, weight: .semibold))
                .foregroundColor(PW.silverMid)
                .tracking(1.6)
            PWTopBarDivider()
            Text("SESSION ACTIVE")
                .font(PW.FontStyle.mono(10, weight: .semibold))
                .foregroundColor(PW.silverMid)
                .tracking(1.6)
        } actions: {
            Button("CLEAR") { showClearConfirm = true }
                .buttonStyle(PrimaryButtonStyle(.danger, compact: true))
        }
        .overlay(alignment: .topLeading) {
            // EXPERIMENTAL badge in title area
            HStack(spacing: 0) {
                Spacer().frame(width: 22)
                // Positioned after title — using overlay approach
            }
        }
    }

    // MARK: - Two column layout

    private func twoColumnLayout(vm: AIOperatorViewModel) -> some View {
        HStack(spacing: 0) {
            // Chat column (flex)
            chatColumn(vm: vm)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(PW.line).frame(width: 1)
                }

            // Right panel (260pt fixed)
            rightPanel(vm: vm)
                .frame(width: 260)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Chat column

    private func chatColumn(vm: AIOperatorViewModel) -> some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(vm.messages) { msg in
                            if msg.role == .user {
                                UserBubble(text: msg.text)
                                    .id(msg.id)
                            } else {
                                AIBubble(message: msg)
                                    .id(msg.id)
                            }
                        }

                        if vm.isStreaming {
                            streamingDots
                                .id("streaming")
                        }
                    }
                    .padding(14)
                }
                .background(PW.panel)
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
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(PW.warn)
                        .font(.system(size: 11))
                    Text(error)
                        .font(PW.FontStyle.mono(10))
                        .foregroundStyle(PW.silver)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(PW.warn.opacity(0.12))
                .overlay(alignment: .top) { Rectangle().fill(PW.warn.opacity(0.3)).frame(height: 1) }
            }

            // Input bar
            inputBar(vm: vm)

            // Disclaimer footer
            HStack {
                Spacer()
                Text("AI OPERATOR IS EXPERIMENTAL · DESTRUCTIVE ACTIONS REQUIRE APPROVAL · RESPONSES MAY BE INCORRECT")
                    .font(PW.FontStyle.mono(9))
                    .foregroundColor(PW.silverDim)
                    .tracking(1.6)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(PW.carbon2)
            .overlay(alignment: .top) { Rectangle().fill(PW.line).frame(height: 1) }
        }
    }

    // MARK: - Input bar

    private func inputBar(vm: AIOperatorViewModel) -> some View {
        HStack(spacing: 10) {
            TextField("TYPE A COMMAND…", text: Binding(
                get: { vm.inputText },
                set: { vm.inputText = $0 }
            ))
            .font(PW.FontStyle.mono(12, weight: .semibold))
            .foregroundStyle(vm.inputText.isEmpty ? PW.silverDim : PW.silver)
            .tracking(1.2)
            .textCase(.uppercase)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(PW.panel2)
            .overlay(Rectangle().stroke(PW.lineStrong, lineWidth: 1))
            .disabled(vm.isStreaming)
            .onSubmit { Task { await vm.send() } }

            Button {
                Task { await vm.send() }
            } label: {
                Text(vm.isStreaming ? "STOP" : "SEND →")
            }
            .buttonStyle(PrimaryButtonStyle(.primary, compact: true))
            .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isStreaming)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(PW.panel)
        .overlay(alignment: .top) { Rectangle().fill(PW.line).frame(height: 1) }
    }

    // MARK: - Streaming dots

    private var streamingDots: some View {
        HStack(spacing: 8) {
            // AI avatar placeholder
            Rectangle()
                .fill(PW.guards.opacity(0.15))
                .frame(width: 28, height: 28)
                .overlay(Rectangle().stroke(PW.guards.opacity(0.3), lineWidth: 1))

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    AIAnimatedDot(delay: Double(i) * 0.2)
                }
            }
            .padding(.leading, 4)

            Spacer()
        }
    }

    // MARK: - Right panel

    private func rightPanel(vm: AIOperatorViewModel) -> some View {
        VStack(spacing: 0) {
            // Active tools section
            activeToolsSection(vm: vm)

            // Suggestions section
            suggestionsSection(vm: vm)

            // Approval queue section
            approvalQueueSection(vm: vm)

            Spacer(minLength: 0)
        }
        .background(PW.carbon)
    }

    // MARK: - Active tools section

    private func activeToolsSection(vm: AIOperatorViewModel) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("// ACTIVE TOOLS")
                    .font(PW.FontStyle.mono(9, weight: .bold))
                    .foregroundColor(PW.guardsBright)
                    .tracking(2.2)
                Spacer()
                Text("THIS SESSION")
                    .font(PW.FontStyle.mono(8))
                    .foregroundColor(PW.silverDim)
                    .tracking(1.8)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            let allTools = vm.messages
                .flatMap { $0.toolCalls }
                .suffix(3)
            let toolList = Array(allTools)

            if toolList.isEmpty {
                Text("NO TOOLS CALLED YET")
                    .font(PW.FontStyle.mono(9))
                    .foregroundColor(PW.silverDim)
                    .tracking(1.6)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(toolList.enumerated()), id: \.offset) { idx, tool in
                        let isRunning = tool.status == "pending" || tool.status == "running"
                        let isDone = tool.status == "executed" || tool.status == "success"
                        let opacity: Double = idx == toolList.count - 1 ? 1.0 : (idx == toolList.count - 2 ? 0.6 : 0.4)

                        HStack(spacing: 8) {
                            if isRunning {
                                LiveDot(color: PW.guardsBright, size: 7)
                            } else {
                                Circle()
                                    .fill(isDone ? PW.ok : PW.silverDim)
                                    .frame(width: 7, height: 7)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(tool.name.uppercased())
                                    .font(PW.FontStyle.mono(10, weight: .bold))
                                    .foregroundColor(isRunning ? PW.guardsBright : PW.silver)
                                    .tracking(1.2)
                                    .lineLimit(1)
                                Text(isRunning ? "RUNNING…" : "DONE")
                                    .font(PW.FontStyle.mono(8))
                                    .foregroundColor(PW.silverDim)
                                    .tracking(1.4)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 14)
                        .opacity(opacity)
                        .overlay(alignment: .bottom) {
                            if idx < toolList.count - 1 {
                                Rectangle().fill(PW.lineSoft).frame(height: 1)
                            }
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(PW.line).frame(height: 1)
        }
    }

    // MARK: - Suggestions section

    private func suggestionsSection(vm: AIOperatorViewModel) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("// SUGGESTIONS")
                    .font(PW.FontStyle.mono(9, weight: .bold))
                    .foregroundColor(PW.guardsBright)
                    .tracking(2.2)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            VStack(spacing: 4) {
                ForEach(AIOperatorViewModel.suggestions.prefix(5), id: \.self) { suggestion in
                    Button {
                        Task { await vm.sendSuggestion(suggestion) }
                    } label: {
                        Text(suggestion.uppercased())
                            .font(PW.FontStyle.mono(10, weight: .semibold))
                            .foregroundColor(PW.silverMid)
                            .tracking(1.4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(PW.panel2)
                            .overlay(Rectangle().stroke(PW.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(PW.line).frame(height: 1)
        }
    }

    // MARK: - Approval queue section

    private func approvalQueueSection(vm: AIOperatorViewModel) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("// APPROVAL QUEUE")
                    .font(PW.FontStyle.mono(9, weight: .bold))
                    .foregroundColor(PW.warn)
                    .tracking(2.2)
                Spacer()
                if let _ = vm.pendingApproval {
                    Text("1 PENDING")
                        .font(PW.FontStyle.mono(8, weight: .bold))
                        .foregroundColor(PW.warn)
                        .tracking(1.6)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(PW.warn.opacity(0.12))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)

            if let pending = vm.pendingApproval {
                VStack(alignment: .leading, spacing: 0) {
                    // Card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(PW.warn)
                            Text("DESTRUCTIVE ACTION")
                                .font(PW.FontStyle.mono(8, weight: .bold))
                                .foregroundColor(PW.warn)
                                .tracking(1.8)
                        }

                        Text(pending.text.uppercased())
                            .font(PW.FontStyle.mono(10, weight: .bold))
                            .foregroundColor(PW.silver)
                            .tracking(1.0)
                            .lineLimit(3)

                        if let auditId = pending.approvalAuditId {
                            Text(auditId)
                                .font(PW.FontStyle.mono(9))
                                .foregroundColor(PW.silverDim)
                                .tracking(1.0)
                        }

                        HStack(spacing: 6) {
                            Button("REJECT") {
                                vm.rejectAction(pending)
                            }
                            .buttonStyle(PrimaryButtonStyle(.danger, compact: true))
                            .frame(maxWidth: .infinity)

                            Button("APPROVE") {
                                Task { await vm.approveAction(pending) }
                            }
                            .buttonStyle(PrimaryButtonStyle(.primary, compact: true))
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 2)
                    }
                    .padding(12)
                    .background(PW.panel)
                    .overlay(
                        Rectangle()
                            .stroke(PW.warn.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(alignment: .leading) {
                        Rectangle().fill(PW.warn).frame(width: 3)
                    }

                    Text("DESTRUCTIVE ACTIONS (END SESSION, RESTART SERVER, FORCE DISCONNECT) APPEAR HERE FOR REVIEW BEFORE EXECUTION.")
                        .font(PW.FontStyle.mono(9))
                        .foregroundColor(PW.silverDim)
                        .tracking(1.4)
                        .lineSpacing(3)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            } else {
                Text("NO PENDING APPROVALS")
                    .font(PW.FontStyle.mono(9))
                    .foregroundColor(PW.silverDim)
                    .tracking(1.6)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - User message bubble

private struct UserBubble: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Spacer(minLength: 40)

            Text(text)
                .font(PW.FontStyle.mono(12, weight: .semibold))
                .foregroundColor(PW.silver)
                .tracking(0.4)
                .lineSpacing(3)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PW.guards.opacity(0.12))
                .overlay(Rectangle().stroke(PW.guardsBright.opacity(0.28), lineWidth: 1))

            // User avatar
            ZStack {
                Rectangle().fill(PW.guards).frame(width: 28, height: 28)
                Text("T")
                    .font(PW.FontStyle.title(13))
                    .foregroundColor(.white)
            }
            .frame(width: 28, height: 28)
            .padding(.top, 2)
        }
    }
}

// MARK: - AI message bubble

private struct AIBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // AI avatar
            ZStack {
                Rectangle()
                    .fill(PW.guards.opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay(Rectangle().stroke(PW.guards.opacity(0.3), lineWidth: 1))
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(PW.guardsBright)
            }
            .frame(width: 28, height: 28)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                // Tool indicators
                ForEach(message.toolCalls) { tool in
                    AIToolIndicator(tool: tool)
                }

                // Tool result block (collapsed)
                if !message.toolCalls.isEmpty {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(PW.ok)
                            Text("RESULT · \(message.toolCalls.last?.name.uppercased() ?? "")")
                                .font(PW.FontStyle.mono(9, weight: .bold))
                                .foregroundColor(PW.ok)
                                .tracking(1.8)
                        }
                        Spacer()
                        Text("▸ EXPAND")
                            .font(PW.FontStyle.mono(8))
                            .foregroundColor(PW.silverDim)
                            .tracking(1.4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(PW.panel2)
                    .overlay(Rectangle().stroke(PW.line, lineWidth: 1))
                }

                // Message text
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(PW.FontStyle.mono(12, weight: .semibold))
                        .foregroundColor(PW.silver)
                        .tracking(0.4)
                        .lineSpacing(3)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(PW.carbon)
                        .overlay(Rectangle().stroke(PW.lineStrong, lineWidth: 1))
                }

                // Approval needed banner
                if message.requiresApproval {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(PW.warn)
                        Text("REQUIRES APPROVAL · DESTRUCTIVE ACTION")
                            .font(PW.FontStyle.mono(9, weight: .bold))
                            .foregroundColor(PW.warn)
                            .tracking(1.6)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PW.warn.opacity(0.1))
                    .overlay(Rectangle().stroke(PW.warn.opacity(0.3), lineWidth: 1))
                }
            }
            .frame(maxWidth: .infinity * 0.72, alignment: .leading)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Tool indicator row

private struct AIToolIndicator: View {
    let tool: ToolCall

    private var isDone: Bool {
        tool.status == "executed" || tool.status == "success"
    }

    var body: some View {
        HStack(spacing: 8) {
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PW.ok)
                    .frame(width: 10, height: 10)
            } else {
                LiveDot(color: PW.guardsBright, size: 7)
                    .frame(width: 10, height: 10)
            }

            Text(tool.name.uppercased())
                .font(PW.FontStyle.mono(9, weight: .bold))
                .foregroundColor(isDone ? PW.ok : PW.silverDim)
                .tracking(1.8)
                .lineLimit(1)

            Spacer()

            Text(isDone ? "DONE" : "RUNNING…")
                .font(PW.FontStyle.mono(8))
                .foregroundColor(PW.silverDim)
                .tracking(1.2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isDone ? PW.ok.opacity(0.05) : PW.guards.opacity(0.06))
        .overlay(alignment: .leading) {
            Rectangle().fill(isDone ? PW.ok : PW.guards).frame(width: 2)
        }
    }
}

// MARK: - Animated dot for streaming

private struct AIAnimatedDot: View {
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

// Keep ToolChip and ApprovalSheet for backward-compat / other callers

// MARK: - Tool chip (legacy)

struct ToolChip: View {
    let tool: ToolCall

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.system(size: 9))
                .foregroundStyle(statusColor)
            Text(tool.name.uppercased())
                .font(PW.FontStyle.mono(9, weight: .bold))
                .foregroundStyle(statusColor)
                .tracking(1.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.12))
        .overlay(Rectangle().stroke(statusColor.opacity(0.3), lineWidth: 1))
    }

    private var statusColor: Color {
        switch tool.status {
        case "executed", "success": return PW.ok
        case "requires_approval":   return PW.warn
        case "error", "rejected":   return PW.guards
        default:                    return PW.info
        }
    }

    private var statusIcon: String {
        switch tool.status {
        case "executed", "success": return "checkmark.circle.fill"
        case "requires_approval":   return "exclamationmark.triangle.fill"
        case "error", "rejected":   return "xmark.circle.fill"
        default:                    return "clock.fill"
        }
    }
}

// MARK: - Approval sheet (legacy modal, kept for compatibility)

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
                                .font(PW.FontStyle.mono(14, weight: .bold))
                                .foregroundStyle(PW.silver)
                                .tracking(1.4)
                            Text("The AI operator is requesting to perform a destructive action.")
                                .font(PW.FontStyle.mono(11))
                                .foregroundStyle(PW.silverMid)
                        }
                    }
                    .padding()
                    .background(PW.warn.opacity(0.1))
                    .overlay(Rectangle().stroke(PW.warn.opacity(0.3), lineWidth: 1))

                    Text(message.text)
                        .font(PW.FontStyle.mono(13))
                        .foregroundStyle(PW.silver)
                        .padding()
                        .background(PW.panel)

                    Spacer()

                    HStack(spacing: 12) {
                        Button("REJECT") {
                            vm.rejectAction(message)
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle(.danger, compact: true))
                        .frame(maxWidth: .infinity)

                        Button("APPROVE") {
                            Task {
                                await vm.approveAction(message)
                                dismiss()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(.primary, compact: true))
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
