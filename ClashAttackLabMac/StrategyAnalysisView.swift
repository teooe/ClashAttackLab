import SwiftUI

struct StrategyAnalysisView: View {
    @ObservedObject var session: AttackLabSession
    @Environment(\.dismiss) private var dismiss
    @State private var showingRankings = false
    @State private var showingRefinement = false
    @State private var showingTournament = false
    @State private var showingBaseReconnaissance = false
    @State private var showingArmyEntryAdvice = false
    @State private var showingSavedBaseAnalysis = false
    @State private var showingScenarioAnalysis = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SearchProgressView(session: session)
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

                Button("Stress test") {
                    session.analyzeCurrentPlanUnderScenarios()
                    showingScenarioAnalysis = true
                }
                .disabled(session.isManualPlanning)

                Button("Cerca resistente") {
                    session.findMostResilientArmyAndAttack()
                    showingScenarioAnalysis = true
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

                Button("Ingresso") {
                    session.analyzeArmyEntryOptions()
                    showingArmyEntryAdvice = true
                }
                .disabled(session.isManualPlanning)

                Button("Ricognizione") {
                    session.analyzeCurrentBase()
                    showingBaseReconnaissance = true
                }
                .disabled(session.isManualPlanning)
            }

            let spellImpact = session.currentSpellImpactAnalysis
            if !spellImpact.entries.isEmpty {
                SpellImpactSummaryView(analysis: spellImpact)
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
                    summaryCard(
                        title: "Stabilità",
                        value: analysis.stabilityLabel
                    )
                }

                Text("Affidabilità: \(analysis.reliabilitySummary) · \(analysis.weakestBaseSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
        .sheet(isPresented: $showingArmyEntryAdvice) {
            ArmyEntryAdviceView(session: session)
        }
        .sheet(isPresented: $showingSavedBaseAnalysis) {
            SavedBaseAnalysisView(session: session)
        }
        .sheet(isPresented: $showingScenarioAnalysis) {
            ScenarioAnalysisView(session: session)
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


/// Shows the bounded sensitivity analysis without mixing it with the normal
/// multi-base ranking. Each result is still deterministic for its scenario.
struct ScenarioAnalysisView: View {
    @ObservedObject var session: AttackLabSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SearchProgressView(session: session)

            HStack {
                Label(
                    "Stress test del piano",
                    systemImage: "shield.lefthalf.filled"
                )
                .font(.title2.bold())
                Spacer()
                Button("Stress test") {
                    session.analyzeCurrentPlanUnderScenarios()
                }
                .buttonStyle(.bordered)
                .disabled(session.isManualPlanning)
                Button("Cerca resistente") {
                    session.findMostResilientArmyAndAttack()
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.isManualPlanning)
                Button("Fine") { dismiss() }
            }

            Text(
                "Confronto deterministico con valori prototipo neutri, attacco +10% e difese +10%. Non è una probabilità né una statistica ufficiale."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            if !session.resilientPlanRankings.isEmpty {
                resilientResults
            } else if let analysis = session.scenarioAnalysis {
                Text(analysis.plan.name)
                    .font(.headline)

                HStack(spacing: 10) {
                    card(
                        title: "Stelle medie",
                        value: String(format: "%.2f", analysis.averageStars)
                    )
                    card(
                        title: "Distruzione media",
                        value: String(
                            format: "%.1f%%",
                            analysis.averageDestruction
                        )
                    )
                    card(
                        title: "Stabilità",
                        value: analysis.stabilityLabel
                    )
                }

                List(analysis.entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.scenario.displayName)
                                .font(.headline)
                            Text(entry.scenario.explanation)
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
                    "Nessuno stress test",
                    systemImage: "shield",
                    description: Text(
                        "Premi Ricalcola per valutare il piano corrente."
                    )
                )
            }
        }
        .padding(20)
        .frame(minWidth: 700, minHeight: 480)
    }


    private var resilientResults: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Piani più resistenti")
                .font(.headline)
            Text(
                "Classifica per risultato nel caso peggiore; solo dopo contano media e superstiti."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            List(
                Array(session.resilientPlanRankings.prefix(10).enumerated()),
                id: \.element.id
            ) { item in
                let rank = item.offset + 1
                let analysis = item.element
                HStack(spacing: 12) {
                    Text("#\(rank)")
                        .font(.title3.bold())
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(analysis.plan.name)
                            .font(.headline)
                        Text(
                            String(
                                format: "peggiore: ⭐ %d · %.1f%%",
                                analysis.worstEntry?.evaluation.stars ?? 0,
                                analysis.worstEntry?.evaluation.destructionPercentage ?? 0
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Text(
                            String(
                                format: "media: ⭐ %.2f · %.1f%% · %.1f superstiti",
                                analysis.averageStars,
                                analysis.averageDestruction,
                                analysis.averageSurvivors
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(
                        analysis.isThreeStarStable
                            ? "Tripla stabile"
                            : "Variabile"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(
                        analysis.isThreeStarStable ? .green : .orange
                    )
                    Button("Carica") {
                        session.loadResilientPlan(analysis)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func card(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
