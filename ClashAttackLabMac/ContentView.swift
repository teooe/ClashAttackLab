import SpriteKit
import SwiftUI

struct ContentView: View {
    private let scene: BattleScene = {
        let gameData = PrototypeGameData()
        let navigationGrid = PrototypeBattleMap.makeNavigationGrid()
        let attackPlan = PrototypeBattleMap.makeAttackPlan(
            navigationGrid: navigationGrid
        )
        let baseEntities = PrototypeBattleMap.makeBaseEntities(
            navigationGrid: navigationGrid
        )

        let simulation = SimulationEngine(
            entities: baseEntities,
            attackPlan: attackPlan,
            gameData: gameData,
            navigationGrid: navigationGrid
        )

        return BattleScene(
            size: CGSize(width: 1_100, height: 760),
            simulation: simulation,
            navigationGrid: navigationGrid,
            attackPlan: attackPlan
        )
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clash Attack Lab")
                        .font(.title2.bold())

                    Text("Milestone 7 · Difese specializzate e proiettili")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                Button {
                    scene.startSimulation()
                } label: {
                    Label("Avvia", systemImage: "play.fill")
                }

                Button {
                    scene.togglePause()
                } label: {
                    Label("Pausa / Riprendi", systemImage: "pause.fill")
                }

                Menu("Velocità") {
                    Button("1×") {
                        scene.simulationSpeed = 1
                    }
                    Button("2×") {
                        scene.simulationSpeed = 2
                    }
                    Button("4×") {
                        scene.simulationSpeed = 4
                    }
                }

                Button {
                    scene.restartSimulation()
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

                    Spacer()

                    Text("Preferenze bersaglio: documentate")
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

            Divider()

            SpriteView(scene: scene)
                .frame(minWidth: 840, minHeight: 600)
        }
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
