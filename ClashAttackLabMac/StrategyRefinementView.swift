import SwiftUI

struct StrategyRefinementView: View {
    @ObservedObject var session: AttackLabSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SearchProgressView(session: session)
            HStack {
                Label("Ottimizzazione del piano", systemImage: "wand.and.stars")
                    .font(.title2.bold())

                Spacer()

                Button("Ricalcola") {
                    session.refineCurrentPlanAcrossBases()
                }

                Button("Fine") {
                    dismiss()
                }
            }

            Text(
                "Conserva esercito e incantesimi: prova corsia, ritmo, profondità del deploy, tempi delle magie e abilità degli eroi su tutte le basi. L’attivazione automatica a vita bassa resta attiva."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            if let report = session.refinementReport {
                HStack(spacing: 10) {
                    summaryCard(
                        title: "Piano di partenza",
                        value: report.sourcePlan.name
                    )
                    summaryCard(
                        title: "Varianti testate",
                        value: "\(report.candidateCount)"
                    )
                    summaryCard(
                        title: "Consigliato",
                        value: report.recommendedPlan?.name ?? "—"
                    )
                }

                List {
                    ForEach(Array(report.rankedCandidates.prefix(8))) {
                        analysis in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    analysis.plan.id == report.sourcePlan.id
                                        ? "Baseline"
                                        : "Variante"
                                )
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

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
                                session.loadRefinedPlan(analysis.plan)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Nessuna ottimizzazione",
                    systemImage: "wand.and.stars",
                    description: Text(
                        "Premi Ricalcola per cercare miglioramenti del piano corrente."
                    )
                )
            }
        }
        .padding(20)
        .frame(minWidth: 820, minHeight: 540)
        .onAppear {
            if session.refinementReport == nil {
                session.refineCurrentPlanAcrossBases()
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
                .font(.headline)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
