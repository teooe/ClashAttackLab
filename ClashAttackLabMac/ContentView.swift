import Foundation
import SpriteKit
import SwiftUI

struct ContentView: View {
    @StateObject private var session = AttackLabSession()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clash Attack Lab")
                        .font(.title2.bold())

                    Text("Milestone 12 · Incantesimi, ricerca e analisi")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                Button {
                    session.findBestAttack()
                } label: {
                    Label(
                        "Trova tra \(session.candidatePlanCount)",
                        systemImage: "wand.and.stars"
                    )
                }
                .buttonStyle(.borderedProminent)

                Button {
                    session.scene.startSimulation()
                } label: {
                    Label("Avvia", systemImage: "play.fill")
                }

                Button {
                    session.scene.togglePause()
                } label: {
                    Label("Pausa / Riprendi", systemImage: "pause.fill")
                }

                Menu("Velocità") {
                    Button("1×") {
                        session.scene.simulationSpeed = 1
                    }
                    Button("2×") {
                        session.scene.simulationSpeed = 2
                    }
                    Button("4×") {
                        session.scene.simulationSpeed = 4
                    }
                }

                Button {
                    session.scene.restartSimulation()
                } label: {
                    Label("Riavvia", systemImage: "arrow.counterclockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
            .padding()

            Divider()

            VStack(spacing: 8) {
                HStack(spacing: 18) {
                    legendItem(
                        symbol: "G",
                        color: .orange,
                        title: "Gigante",
                        detail: "priorità difese"
                    )

                    legendItem(
                        symbol: "B",
                        color: .red,
                        title: "Barbaro",
                        detail: "qualsiasi edificio"
                    )

                    legendItem(
                        symbol: "A",
                        color: .pink,
                        title: "Arciera",
                        detail: "freccia a distanza"
                    )

                    legendItem(
                        symbol: "WB",
                        color: .green,
                        title: "Spaccamuro",
                        detail: "esplosione sui muri"
                    )

                    Spacer()

                    Text("Preferenze bersaglio: documentate")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 18) {
                    legendItem(
                        symbol: "H",
                        color: .green,
                        title: "Cura",
                        detail: "recupero nella zona"
                    )

                    legendItem(
                        symbol: "R",
                        color: .purple,
                        title: "Furia",
                        detail: "danno + velocità"
                    )

                    Spacer()

                    Text("Comportamento documentato · valori numerici prototipo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 18) {
                    legendItem(
                        symbol: "C",
                        color: .gray,
                        title: "Cannone",
                        detail: "colpo singolo"
                    )

                    legendItem(
                        symbol: "TA",
                        color: .cyan,
                        title: "Torre",
                        detail: "alta frequenza"
                    )

                    legendItem(
                        symbol: "MO",
                        color: .brown,
                        title: "Mortaio",
                        detail: "area + raggio minimo"
                    )

                    Spacer()

                    Text("Statistiche, proiettili e danno ad area: prototipo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.thinMaterial)

            if !session.evaluations.isEmpty {
                Divider()
                comparisonBar
            }

            Divider()

            SpriteView(scene: session.scene)
                .frame(minWidth: 840, minHeight: 600)
        }
    }

    private var comparisonBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    "Piani simulati senza rendering",
                    systemImage: "cpu"
                )
                .font(.caption.bold())

                Spacer()

                Text("Il migliore è già caricato: premi Avvia per rivederlo")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(
                        session.evaluations.indices,
                        id: \.self
                    ) { index in
                        planCard(
                            evaluation: session.evaluations[index],
                            rank: index + 1
                        )
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.06))
    }

    private func planCard(
        evaluation: AttackPlanEvaluation,
        rank: Int
    ) -> some View {
        let isSelected = session.selectedPlanID == evaluation.plan.id
        let isBest = rank == 1

        return Button {
            session.select(evaluation)
        } label: {
            HStack(spacing: 10) {
                Text("#\(rank)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(isBest ? .green : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(evaluation.plan.name)
                            .font(.caption.bold())

                        if isBest {
                            Text("MIGLIORE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.green)
                        }
                    }

                    Text(
                        String(
                            format: "%d★ · %.0f%% · %.1f s · %d superstiti",
                            evaluation.stars,
                            evaluation.destructionPercentage,
                            evaluation.result.elapsedTime,
                            evaluation.result.survivingTroops
                        )
                    )
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)

                    Text(
                        String(
                            format: "Danno %.0f · Perse %d · Muri %d · %@",
                            evaluation.result.metrics.damageToBase,
                            evaluation.result.metrics.troopsLost,
                            evaluation.result.metrics.destroyedWalls,
                            evaluation.result.finishReason.displayName
                        )
                    )
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.16)
                    : Color.primary.opacity(0.045)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(
                        isSelected
                            ? Color.accentColor.opacity(0.8)
                            : Color.primary.opacity(0.1),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func legendItem(
        symbol: String,
        color: Color,
        title: String,
        detail: String
    ) -> some View {
        HStack(spacing: 7) {
            Text(symbol)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 28, height: 24)
                .background(color)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.bold())
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
