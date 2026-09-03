import SwiftUI

/// Cross-base tournament for every plan produced by the automatic generator.
struct StrategyTournamentView: View {
    @ObservedObject var session: AttackLabSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(
                    "Torneo delle strategie",
                    systemImage: "trophy"
                )
                .font(.title2.bold())

                Spacer()

                Button("Ricalcola") {
                    session.rankGeneratedPlansAcrossBases()
                }

                Button("Fine") {
                    dismiss()
                }
            }

            Text(
                "\(session.candidatePlanCount) piani generati automaticamente, valutati su tutte le basi disponibili."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            if session.generatedPlanRankings.isEmpty {
                ContentUnavailableView(
                    "Nessun piano da confrontare",
                    systemImage: "trophy",
                    description: Text(
                        "Premi Ricalcola per eseguire il torneo strategico."
                    )
                )
            } else {
                List {
                    ForEach(
                        Array(
                            session.generatedPlanRankings.prefix(12).enumerated()
                        ),
                        id: \.element.id
                    ) { item in
                        let rank = item.offset + 1
                        let analysis = item.element

                        HStack(spacing: 12) {
                            Text("\(rank)")
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
                                session.loadGeneratedPlan(analysis.plan)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 820, minHeight: 560)
        .onAppear {
            if session.generatedPlanRankings.isEmpty {
                session.rankGeneratedPlansAcrossBases()
            }
        }
    }
}
