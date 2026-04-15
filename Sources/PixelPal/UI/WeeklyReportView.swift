import SwiftUI
import PixelPalCore

/// Weekly report card — pixel-art styled, one-click share.
/// Shows work stats for the past 7 days with character identity.
/// Shareable as an image with #PixelPal watermark.
struct WeeklyReportView: View {
    let report: WorkPatternStore.WeekReport
    let characterName: String
    let characterEmoji: String
    let evolutionDays: Int
    let onShare: (NSImage) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text(characterEmoji)
                    .font(.system(size: 32))
                Text("\(characterName) & Me")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("Week in Review")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCell(icon: "⏱", label: "Work", value: String(format: "%.1fh", report.totalWorkHours))
                statCell(icon: "☕", label: "Breaks", value: "\(report.totalBreaks)")
                statCell(icon: "✅", label: "Tasks", value: "\(report.tasksCompleted)")
                statCell(icon: "🌙", label: "Late nights", value: "\(report.lateNightCount)")
                statCell(icon: "🔥", label: "Longest focus", value: "\(report.longestStreak)m")
                statCell(icon: "📅", label: "Days active", value: "\(report.daysActive)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Break compliance bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Break compliance")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(report.avgBreakCompliance * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.2))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(complianceColor)
                            .frame(width: geo.size.width * min(1, report.avgBreakCompliance))
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Evolution days
            if evolutionDays > 0 {
                HStack {
                    Text("🤝")
                    Text("Day \(evolutionDays) together")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
            }

            Divider()

            // Footer with watermark
            HStack {
                Text("#PixelPal")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.5))
                Spacer()
                Button(action: shareReport) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Text("Done")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }

    private func statCell(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(icon)
                .font(.system(size: 16))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }

    private var complianceColor: Color {
        if report.avgBreakCompliance >= 0.7 { return .green }
        if report.avgBreakCompliance >= 0.4 { return .orange }
        return .red
    }

    @MainActor
    private func shareReport() {
        // Render this view as an image for sharing
        let renderer = ImageRenderer(content: self.body)
        renderer.scale = 2.0 // Retina
        if let image = renderer.nsImage {
            onShare(image)
        }
    }
}

/// Trigger sharing via macOS share sheet
func shareImage(_ image: NSImage) {
    let picker = NSSharingServicePicker(items: [image])
    if let button = NSApp.keyWindow?.contentView {
        picker.show(relativeTo: .zero, of: button, preferredEdge: .minY)
    }
}
