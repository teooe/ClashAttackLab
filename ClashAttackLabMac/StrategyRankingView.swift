import SwiftUI

struct StrategyRankingView: View {
    @ObservedObject var session: AttackLabSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Classifica robustezza", systemImage: "trophy")
                    .font(.title2.bold())

                Spacer()

                Button("Ricalcola") {
                    session.rankSavedPlansAcrossBases()
                }

                Button("Fine") {
                    dismiss()
                }
            }

            Text("Ordine: stelle medie, distruzione, superstiti e durata.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if session.robustnessRankings.isEmpty {
                ContentUnavailableView(
                    "Nessun piano da classificare",
                    systemImage: "tray",
                    description: Text("Salva almeno un piano oppure carica un piano corrente.")
                )
            } else {
                List {
                    ForEach(
                        Array(session.robustnessRankings.enumerated()),
                        id: \.element.id
                    ) { item in
                        let (index, analysis) = item

                        HStack(spacing: 12) {
                        Text(String(index + 1))
                            .font(.title3.bold())
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(analysis.plan.name)
                                .font(.headline)
                            Text(
                                String(
                                    format: "⭐ %.2f · %.1f%% · %.1f superstiti · %.1f s",
                                    analysis.averageStars,
                                    analysis.averageDestruction,
                                    analysis.averageSurvivors,
                                    analysis.averageDuration
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(
                            String(
                                format: "%d/%d triple",
                                analysis.threeStarCount,
                                analysis.entries.count
                            )
                        )
                        .font(.caption)

                        Button("Carica") {
                            session.loadSavedPlan(analysis.plan)
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 460)
        .onAppear {
            if session.robustnessRankings.isEmpty {
                session.rankSavedPlansAcrossBases()
            }
        }
    }
}
