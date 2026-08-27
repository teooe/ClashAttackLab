import SpriteKit
import SwiftUI

struct ContentView: View {
    private let scene: BattleScene = {
        let gameData = PrototypeGameData()
        let navigationGrid = PrototypeBattleMap.makeNavigationGrid()
        let attackPlan = PrototypeBattleMap.makeAttackPlan(
            navigationGrid: navigationGrid
        )

        var baseEntities = [
            BattleEntity(
                kind: .cannon,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 16, row: 3)
                )
            ),
            BattleEntity(
                kind: .cannon,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 19, row: 8)
                )
            ),
            BattleEntity(
                kind: .cannon,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 16, row: 13)
                )
            ),
            BattleEntity(
                kind: .townHall,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 22, row: 8)
                )
            ),
            BattleEntity(
                kind: .goldStorage,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 17, row: 7)
                )
            ),
            BattleEntity(
                kind: .goldStorage,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 17, row: 12)
                )
            )
        ]

        baseEntities += PrototypeBattleMap.wallCoordinates().map {
            BattleEntity(
                kind: .wall,
                position: navigationGrid.worldPosition(for: $0)
            )
        }

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

                    Text("Milestone 5 · Piano di deploy temporizzato")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Dati e tempo: prototipo")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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

            SpriteView(scene: scene)
                .frame(minWidth: 840, minHeight: 600)
        }
    }
}

#Preview {
    ContentView()
}
