import SwiftUI

/// A single tile on the lobby board.
struct NodeTile: View {
    let node: LobbyNode
    let isSpawning: Bool
    let onTap: () -> Void
    var onRename: ((String) -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var showRename = false
    @State private var showDeleteConfirm = false
    @State private var newName = ""

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                header
                Spacer(minLength: 0)
                liveStrip
            }
            .padding(16)
            .frame(minHeight: 132)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tileBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(strokeColor, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isSpawning)
        .contextMenu {
            if onRename != nil {
                Button {
                    newName = node.name
                    showRename = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
            }
            if onDelete != nil {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
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

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            kindBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PW.silver)
            }
            Spacer()
            statusDot
        }
    }

    private var kindBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(node.kind == .location ? PW.guards : PW.info)
                .frame(width: 32, height: 32)
            Image(systemName: node.kind == .location ? "flag.checkered" : "rectangle.3.group")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(PW.silver)
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(node.mc.isRunning ? PW.ok : PW.silverDim)
            .frame(width: 10, height: 10)
            .overlay(
                isSpawning
                ? ProgressView().controlSize(.small).tint(PW.silver)
                : nil
            )
    }

    private var liveStrip: some View {
        HStack(spacing: 8) {
            if let op = node.operator {
                Label(op.display ?? op.deviceId, systemImage: "person.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(PW.panel3)
                    .clipShape(Capsule())
                    .foregroundStyle(PW.silver)
            }
            if node.live.activeSessions > 0 {
                metricChip("\(node.live.activeSessions) active", color: PW.ok)
            }
            if node.live.activePostings > 0 {
                metricChip("\(node.live.activePostings) live", color: PW.guards)
            }
            Spacer()
            if !node.mc.isRunning {
                Text("offline")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PW.silverDim)
            }
        }
    }

    private func metricChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold).monospaced())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var strokeColor: Color {
        node.mc.isRunning ? PW.lineStrong : PW.line
    }

    private var tileBackground: Color {
        node.mc.isRunning ? PW.panel2 : PW.panel
    }
}
