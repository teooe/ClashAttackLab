import SwiftUI

struct AttackHistoryView: View {
    @ObservedObject var session: AttackLabSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Storico battaglie", systemImage: "clock.arrow.circlepath")
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

            Text("Conserva fino a 50 risultati completati sul Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if session.attackHistory.isEmpty {
                ContentUnavailableView(
                    "Nessuna battaglia conclusa",
                    systemImage: "clock",
                    description: Text("Avvia una simulazione per registrare qui il risultato.")
                )
            } else {
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
                            Text(entry.finishReasonName)
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

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("⭐ \(entry.stars)")
                                .font(.subheadline.bold())
                            Text(entry.completedAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 460)
    }
}
