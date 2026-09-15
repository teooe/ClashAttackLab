import SwiftUI

struct SavedBaseAnalysisView: View {
    @ObservedObject var session: AttackLabSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SearchProgressView(session: session)
            HStack {
                Label(
                    "Analisi basi locali",
                    systemImage: "square.stack.3d.up"
                )
                .font(.title2.bold())

                Spacer()

                Menu {
                    Button("Analizza piano attuale") {
                        session.analyzeCurrentPlanAcrossSavedBases()
                    }
                    Button("Trova piano affidabile") {
                        session.findReliableArmyAndAttackAcrossSavedBases()
                    }
                } label: {
                    Label("Ricerca", systemImage: "wand.and.stars")
                }
                .disabled(session.isManualPlanning)

                Button("Fine") {
                    dismiss()
                }
            }

            Text(
                "Analizza il piano attuale oppure cerca composizione e deploy più affidabili sulla base aperta e sulle basi salvate localmente."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            RobustnessObjectivePicker(session: session)

            if !session.savedBasePlanRankings.isEmpty {
                reliablePlanResults
            } else if let analysis = session.savedBasePlanAnalysis {
                HStack(spacing: 10) {
                    summaryCard(
                        title: "Basi",
                        value: "\(analysis.entries.count)"
                    )
                    summaryCard(
                        title: "Stelle medie",
                        value: String(format: "%.2f", analysis.averageStars)
                    )
                    summaryCard(
                        title: "Distruzione media",
                        value: String(
                            format: "%.1f%%",
                            analysis.averageDestruction
                        )
                    )
                    summaryCard(
                        title: "Triplette",
                        value: "\(analysis.threeStarCount)/\(analysis.entries.count)"
                    )
                }

                List(analysis.entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.base.name)
                                .font(.headline)
                            Text(
                                "\(entry.base.objectiveCount) strutture · \(entry.base.wallCount) muri"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text("⭐ \(entry.evaluation.stars)")
                                .font(.headline)
                            Text(
                                String(
                                    format: "%.1f%% · %d superstiti · %.1f s",
                                    entry.evaluation.destructionPercentage,
                                    entry.evaluation.result.survivingTroops,
                                    entry.evaluation.result.elapsedTime
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                ContentUnavailableView(
                    "Nessuna base da analizzare",
                    systemImage: "square.stack.3d.up",
                    description: Text(
                        "Salva o importa una base, poi premi Ricalcola."
                    )
                )
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 520)
        .onAppear {
            if session.savedBasePlanAnalysis == nil {
                session.analyzeCurrentPlanAcrossSavedBases()
            }
        }
    }


    private var reliablePlanResults: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Piani affidabili sulle basi locali")
                .font(.headline)
            Text(session.robustnessObjective.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)

            List(
                Array(session.savedBasePlanRankings.prefix(10).enumerated()),
                id: \.element.id
            ) { item in
                let rank = item.offset + 1
                let analysis = item.element
                HStack(spacing: 12) {
                    Text("#\(rank)")
                        .font(.title3.bold())
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(analysis.plan.name)
                            .font(.headline)
                        Text(
                            String(
                                format: "⭐ %.2f · %.1f%% · %.1f superstiti · %d/%d triple",
                                analysis.averageStars,
                                analysis.averageDestruction,
                                analysis.averageSurvivors,
                                analysis.threeStarCount,
                                analysis.entries.count
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Text("Base peggiore: \(analysis.weakestBaseSummary)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Carica") {
                        session.loadReliableSavedBasePlan(analysis)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 4)
            }
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
                .font(.title3.bold())
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
