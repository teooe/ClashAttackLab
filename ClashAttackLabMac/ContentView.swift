import Foundation
import SpriteKit
import SwiftUI

struct ContentView: View {
    @StateObject private var session = AttackLabSession()
    @State private var showingArmyBuilder = false
    @State private var showingBaseLibrary = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clash Attack Lab")
                        .font(.title2.bold())

                    Text(
                        "Milestone 15 · \(session.baseLayout.displayName) · Terra e aria"
                    )
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
                    showingArmyBuilder = true
                } label: {
                    Label("Esercito", systemImage: "person.3.fill")
                }

                Button {
                    showingBaseLibrary = true
                } label: {
                    Label("Base", systemImage: "square.grid.3x3.fill")
                }

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
                        detail: "terra · difese"
                    )

                    legendItem(
                        symbol: "B",
                        color: .red,
                        title: "Barbaro",
                        detail: "terra · edifici"
                    )

                    legendItem(
                        symbol: "A",
                        color: .pink,
                        title: "Arciera",
                        detail: "terra · distanza"
                    )

                    legendItem(
                        symbol: "WB",
                        color: .green,
                        title: "Spaccamuro",
                        detail: "terra · muri"
                    )

                    legendItem(
                        symbol: "W",
                        color: .blue,
                        title: "Mago",
                        detail: "terra · area"
                    )
                }

                HStack(spacing: 18) {
                    legendItem(
                        symbol: "BL",
                        color: .indigo,
                        title: "Mongolfiera",
                        detail: "aria · difese"
                    )

                    legendItem(
                        symbol: "DR",
                        color: .mint,
                        title: "Drago",
                        detail: "aria · edifici"
                    )

                    Spacer()

                    Text("Ciano = traiettoria aerea diretta sui muri")
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

                    Text("Comportamenti e valori: prototipo esplicito")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 18) {
                    legendItem(
                        symbol: "C",
                        color: .gray,
                        title: "Cannone",
                        detail: "solo terra"
                    )

                    legendItem(
                        symbol: "TA",
                        color: .cyan,
                        title: "Torre",
                        detail: "terra + aria"
                    )

                    legendItem(
                        symbol: "MO",
                        color: .brown,
                        title: "Mortaio",
                        detail: "solo terra"
                    )

                    legendItem(
                        symbol: "AD",
                        color: .indigo,
                        title: "Difesa aerea",
                        detail: "solo aria"
                    )
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
        .sheet(isPresented: $showingArmyBuilder) {
            ArmyEditorView(
                configuration: session.armyConfiguration
            ) { configuration in
                session.applyArmyConfiguration(configuration)
            }
        }
        .sheet(isPresented: $showingBaseLibrary) {
            BaseEditorView(layout: session.baseLayout) { layout in
                session.applyBaseLayout(layout)
            }
        }
    }

    private var comparisonBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    "Piani simulati · \(session.baseLayout.displayName)",
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
