import SwiftUI

/// A single node tile on the lobby board.
struct NodeTile: View {
    let node: LobbyNode
    let isSpawning: Bool
    let onTap: () -> Void
    var onRename: ((String) -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var showRename = false
    @State private var showDeleteConfirm = false
    @State private var newName = ""

    private var isOrg: Bool { node.kind == .org }
    private var isOnline: Bool { node.mc.isRunning }
    private var accentColor: Color { isOrg ? PW.info : PW.guards }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 10) {
                    // Top: eyebrow + title + status dot
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isOrg ? "// ORGANIZATION" : "// LOCATION")
                                .font(PW.FontStyle.mono(9, weight: .bold))
                                .foregroundColor(accentColor)
                                .tracking(2.2)

                            Text(node.name.uppercased())
                                .font(PW.FontStyle.card(32))
                                .foregroundColor(PW.silver)
                                .tracking(-0.64)
                                .lineLimit(1)

                            if let sub = nodeSub {
                                Text(sub.uppercased())
                                    .font(PW.FontStyle.mono(9, weight: .semibold))
                                    .foregroundColor(PW.silverDim)
                                    .tracking(1.8)
                            }
                        }

                        Spacer()

                        Circle()
                            .fill(isOnline ? PW.ok : PW.silverDim)
                            .frame(width: 8, height: 8)
                            .overlay(
                                isSpawning
                                ? ProgressView().controlSize(.mini).tint(PW.silver)
                                : nil
                            )
                    }

                    // Body: driver + rigs + live count (online only)
                    if isOnline {
                        HStack(spacing: 12) {
                            if let op = node.operator {
                                HStack(spacing: 6) {
                                    ZStack {
                                        Rectangle()
                                            .fill(PW.guards)
                                            .frame(width: 18, height: 18)
                                        Text(String((op.display ?? op.deviceId).prefix(1)).uppercased())
                                            .font(PW.FontStyle.title(11))
                                            .foregroundColor(.white)
                                            .tracking(-0.22)
                                    }
                                    Text((op.display ?? op.deviceId).uppercased())
                                        .font(PW.FontStyle.mono(9, weight: .semibold))
                                        .foregroundColor(PW.silver)
                                        .tracking(0.4)
                                }
                                Rectangle().fill(PW.line).frame(width: 1, height: 14)
                            }

                            Text("\(rigCount) RIGS")
                                .font(PW.FontStyle.mono(9, weight: .semibold))
                                .foregroundColor(PW.silverMid)
                                .tracking(1.8)

                            if node.live.activeSessions > 0 {
                                Rectangle().fill(PW.line).frame(width: 1, height: 14)
                                HStack(spacing: 4) {
                                    LiveDot(color: PW.guardsBright, size: 6)
                                    Text("\(node.live.activeSessions) LIVE")
                                        .font(PW.FontStyle.mono(9, weight: .bold))
                                        .foregroundColor(PW.guardsBright)
                                        .tracking(2.0)
                                }
                            }
                        }
                    } else {
                        Text("OFFLINE · LAST SEEN RECENTLY")
                            .font(PW.FontStyle.mono(9, weight: .semibold))
                            .foregroundColor(PW.silverDim)
                            .tracking(2.2)
                    }

                    // Footer: track + open button
                    if isOnline {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("TRACK")
                                    .font(PW.FontStyle.mono(9, weight: .semibold))
                                    .foregroundColor(PW.silverDim)
                                    .tracking(2.0)
                                Text("—")
                                    .font(PW.FontStyle.mono(11, weight: .semibold))
                                    .foregroundColor(PW.silver2)
                            }
                            Spacer()
                            Text("OPEN →")
                                .font(PW.FontStyle.mono(10, weight: .bold))
                                .foregroundColor(PW.silver)
                                .tracking(1.6)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 8)
                                .overlay(Rectangle().stroke(PW.lineStrong, lineWidth: 1))
                                .clipShape(CutShape())
                        }
                        .padding(.top, 10)
                        .overlay(alignment: .top) {
                            Rectangle().fill(PW.line).frame(height: 1)
                        }
                    }
                }
                .padding(18)
                .frame(minHeight: 158)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PW.panel)
                .overlay(Rectangle().stroke(PW.line, lineWidth: 1))
                .overlay(alignment: .leading) {
                    Rectangle().fill(accentColor).frame(width: 3)
                }
                .opacity(isOnline ? 1 : 0.62)
            }
        }
        .buttonStyle(.plain)
        .disabled(isSpawning)
        .contextMenu {
            if onRename != nil {
                Button { newName = node.name; showRename = true } label: {
                    Label("Rename", systemImage: "pencil")
                }
            }
            if onDelete != nil {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Rename", isPresented: $showRename) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { onRename?(newName) }
        }
        .alert("Delete \(node.name)?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete?() }
        } message: {
            Text("This will remove the location and all its data. This cannot be undone.")
        }
    }

    private var nodeSub: String? {
        if node.kind == .org { return "\(node.live.activeSessions) LOCATIONS" }
        return nil
    }

    private var rigCount: Int { 0 }
}
