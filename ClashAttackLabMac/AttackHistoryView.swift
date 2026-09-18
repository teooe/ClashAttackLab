import SwiftUI

struct AttackHistoryView: View {
    @ObservedObject var session: AttackLabSession
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimelineEntry: AttackHistoryEntry?

    var body: some View {
        let summary = session.attackHistorySummary

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Archivio battaglie", systemImage: "clock.arrow.circlepath")
                    .font(.title2.bold())

                Spacer()

                if !session.attackHistory.isEmpty {
                    Button("Svuota", role: .destructive) {
                        session.clearAttackHistory()
                    }
                }

                Button("Fine") {
                    dismiss()
                }
            }

            Text(
                "Conserva fino a 50 risultati. Le nuove registrazioni includono base e piano per il replay."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            if session.attackHistory.isEmpty {
                ContentUnavailableView(
                    "Nessuna battaglia conclusa",
                    systemImage: "clock",
                    description: Text(
                        "Avvia una simulazione per registrare qui il risultato."
                    )
                )
            } else {
                HStack(spacing: 10) {
                    summaryCard(
                        title: "Battaglie",
                        value: "\(summary.battleCount)"
                    )
                    summaryCard(
                        title: "Stelle medie",
                        value: String(format: "%.2f", summary.averageStars)
                    )
                    summaryCard(
                        title: "Distruzione media",
                        value: String(
                            format: "%.1f%%",
                            summary.averageDestruction
                        )
                    )
                    summaryCard(
                        title: "Migliore",
                        value: summary.bestEntry.map {
                            "⭐ \($0.stars) · \(String(format: "%.1f%%", $0.destructionPercentage))"
                        } ?? "—"
                    )
                }

                List(session.attackHistory) { entry in
                    HStack(spacing: 12) {
                        Image(
                            systemName: entry.winnerName == "Attaccanti"
                                ? "checkmark.circle.fill"
                                : "xmark.circle.fill"
                        )
                        .foregroundStyle(
                            entry.winnerName == "Attaccanti" ? .green : .red
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.planName)
                                .font(.headline)
                            Text(
                                entry.baseSnapshot?.name ??
                                    entry.baseLayout?.displayName ??
                                    "Base non registrata"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            Text(
                                String(
                                    format: "%.1f%% · %.1f s · superstiti %d · persi %d",
                                    entry.destructionPercentage,
                                    entry.elapsedTime,
                                    entry.survivingTroops,
                                    entry.troopsLost
                                )
                            )
                            .font(.caption)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 5) {
                            Text("⭐ \(entry.stars)")
                                .font(.subheadline.bold())
                            Text(entry.completedAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if entry.attackPlan != nil,
                               entry.baseSnapshot != nil ||
                               entry.baseLayout != nil {
                                if let timeline = entry.timeline,
                                   !timeline.isEmpty {
                                    Button("Eventi") {
                                        selectedTimelineEntry = entry
                                    }
                                    .buttonStyle(.bordered)
                                }
                                Button("Rigioca") {
                                    session.replayHistoryEntry(entry)
                                    dismiss()
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Text("Solo risultato")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 520)
        .sheet(item: $selectedTimelineEntry) { entry in
            BattleTimelineView(entry: entry)
        }
    }

    private func summaryCard(
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}


/// Compact post-battle explanation backed by engine events, not inferred UI.
struct BattleTimelineView: View {
    let entry: AttackHistoryEntry
    @Environment(\.dismiss) private var dismiss

    private var timeline: [BattleTimelineEvent] {
        entry.timeline ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Timeline battaglia", systemImage: "list.bullet.rectangle")
                    .font(.title2.bold())
                Spacer()
                Button("Fine") { dismiss() }
            }

            Text(entry.planName)
                .font(.headline)
            Text(
                "\(entry.finishReasonName) · ⭐ \(entry.stars) · " +
                String(format: "%.1f%%", entry.destructionPercentage)
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            List(timeline) { event in
                HStack(alignment: .top, spacing: 12) {
                    Text(String(format: "%05.1f s", event.timestamp))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 54, alignment: .trailing)
                    Image(systemName: icon(for: event.kind))
                        .foregroundStyle(color(for: event.kind))
                        .frame(width: 18)
                    Text(event.message)
                        .font(.callout)
                }
                .padding(.vertical, 3)
            }
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 480)
    }

    private func icon(for kind: BattleTimelineEventKind) -> String {
        switch kind {
        case .deployment: return "arrow.right.circle.fill"
        case .spellCast: return "sparkles"
        case .heroAbility: return "bolt.circle.fill"
        case .trapTriggered: return "burst.fill"
        case .structureDestroyed: return "building.2.crop.circle"
        case .troopDefeated: return "xmark.circle.fill"
        case .siegePayloadReleased: return "shippingbox.fill"
        case .battleFinished: return "flag.checkered"
        }
    }

    private func color(for kind: BattleTimelineEventKind) -> Color {
        switch kind {
        case .deployment: return .cyan
        case .spellCast: return .purple
        case .heroAbility: return .yellow
        case .trapTriggered: return .pink
        case .structureDestroyed: return .orange
        case .troopDefeated: return .red
        case .siegePayloadReleased: return .brown
        case .battleFinished: return .green
        }
    }
}
