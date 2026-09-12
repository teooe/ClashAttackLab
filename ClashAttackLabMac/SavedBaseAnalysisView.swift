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

                Button("Ricalcola") {
                    session.analyzeCurrentPlanAcrossSavedBases()
                }

                Button("Fine") {
                    dismiss()
                }
            }

            Text(
                "Confronta il piano attuale con la base aperta e con tutte le basi salvate sul Mac."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            if let analysis = session.savedBasePlanAnalysis {
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
