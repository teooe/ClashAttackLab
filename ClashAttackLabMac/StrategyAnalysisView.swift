import SwiftUI

struct StrategyAnalysisView: View {
    @ObservedObject var session: AttackLabSession
    @Environment(\.dismiss) private var dismiss
    @State private var showingRankings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Analisi strategica", systemImage: "chart.bar.xaxis")
                    .font(.title2.bold())

                Spacer()

                Button("Ricalcola") {
                    session.analyzeCurrentPlanAcrossBases()
                }
                .buttonStyle(.borderedProminent)

                Button("Classifica piani") {
                    session.rankSavedPlansAcrossBases()
                    showingRankings = true
                }
                .disabled(session.isManualPlanning)

                Button("Fine") {
                    dismiss()
                }
            }

            Text("Lo stesso piano viene valutato su tutte le basi disponibili.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let analysis = session.currentPlanAnalysis {
                Text(analysis.plan.name)
                    .font(.headline)

                HStack(spacing: 10) {
                    summaryCard(
                        title: "Stelle medie",
                        value: String(format: "%.2f", analysis.averageStars)
                    )
                    summaryCard(
                        title: "Distruzione media",
                        value: String(format: "%.1f%%", analysis.averageDestruction)
                    )
                    summaryCard(
                        title: "Superstiti medi",
                        value: String(format: "%.1f", analysis.averageSurvivors)
                    )
                    summaryCard(
                        title: "Triplette",
                        value: "\(analysis.threeStarCount)/\(analysis.entries.count)"
                    )
                }

                List(analysis.entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.layout.displayName)
                                .font(.headline)
                            Text(entry.layout.summary)
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
                    "Nessuna analisi",
                    systemImage: "chart.bar",
                    description: Text("Premi Ricalcola per testare il piano corrente.")
                )
            }
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 520)
        .onAppear {
            if session.currentPlanAnalysis == nil {
                session.analyzeCurrentPlanAcrossBases()
            }
        }
        .sheet(isPresented: $showingRankings) {
            StrategyRankingView(session: session)
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
