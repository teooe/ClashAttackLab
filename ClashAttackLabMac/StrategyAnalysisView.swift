import SwiftUI

struct StrategyAnalysisView: View {
    @ObservedObject var session: AttackLabSession
    @Environment(\.dismiss) private var dismiss
    @State private var showingRankings = false
    @State private var showingRefinement = false
    @State private var showingTournament = false
    @State private var showingBaseReconnaissance = false
    @State private var showingSavedBaseAnalysis = false

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

                Button("Ottimizza piano") {
                    session.refineCurrentPlanAcrossBases()
                    showingRefinement = true
                }
                .disabled(session.isManualPlanning)

                Button("Torneo") {
                    session.rankGeneratedPlansAcrossBases()
                    showingTournament = true
                }
                .disabled(session.isManualPlanning)

                Button("Fine") {
                    dismiss()
                }
            }

            Text("Lo stesso piano viene valutato su tutte le basi disponibili.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Text("Ricognizione: percorrenze A* e pressione difensiva della base aperta.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Basi locali") {
                    session.analyzeCurrentPlanAcrossSavedBases()
                    showingSavedBaseAnalysis = true
                }
                .disabled(session.isManualPlanning)

                Button("Ricognizione") {
                    session.analyzeCurrentBase()
                    showingBaseReconnaissance = true
                }
                .disabled(session.isManualPlanning)
            }

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
        .sheet(isPresented: $showingRefinement) {
            StrategyRefinementView(session: session)
        }
        .sheet(isPresented: $showingTournament) {
            StrategyTournamentView(session: session)
        }
        .sheet(isPresented: $showingBaseReconnaissance) {
            BaseReconnaissanceView(session: session)
        }
        .sheet(isPresented: $showingSavedBaseAnalysis) {
            SavedBaseAnalysisView(session: session)
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
