import SwiftUI

struct AttackHistoryView: View {
    @ObservedObject var session: AttackLabSession
    @Environment(\.dismiss) private var dismiss

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
                               entry.baseLayout != nil {
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
