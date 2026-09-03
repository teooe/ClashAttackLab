import SwiftUI

struct ArmyEntryAdviceView: View {
    @ObservedObject var session: AttackLabSession

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(
                    "Consiglio di ingresso",
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                )
                .font(.title2.bold())

                Spacer()

                Button("Ricalcola") {
                    session.analyzeArmyEntryOptions()
                }

                Button("Fine") {
                    dismiss()
                }
            }

            Text(
                "Confronta le cinque corsie di schieramento per ogni truppa dell’esercito: bersaglio coerente con il suo profilo, percorso reale del simulatore e fuoco difensivo stimato."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            if let advice = session.armyEntryAdvice {
                VStack(alignment: .leading, spacing: 5) {
                    Text(advice.baseName)
                        .font(.headline)
                    Text(advice.recommendationText)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                List(advice.recommendations) { recommendation in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                "\(recommendation.troopName) × \(recommendation.troopCount)"
                            )
                            .font(.headline)
                            Text(
                                "\(recommendation.laneLabel) · primo bersaglio \(recommendation.firstTargetName)"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            Text(recommendation.routeSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(
                            recommendation.movementDomain == .air
                                ? "Aria"
                                : "Terra"
                        )
                        .font(.caption.bold())
                        .foregroundStyle(.tint)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                ContentUnavailableView(
                    "Nessun consiglio calcolato",
                    systemImage:
                        "point.topleft.down.to.point.bottomright.curvepath",
                    description: Text(
                        "Premi Ricalcola per analizzare l’esercito contro la base aperta."
                    )
                )
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 520)
        .onAppear {
            if session.armyEntryAdvice == nil {
                session.analyzeArmyEntryOptions()
            }
        }
    }
}
