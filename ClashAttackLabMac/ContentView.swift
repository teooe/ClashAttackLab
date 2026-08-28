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

                    Text("Milestone 6 · Esercito misto e targeting per unità")
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
                    detail: "attacco a distanza"
                )

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Preferenze bersaglio: documentate")
                    Text("Statistiche e costo percorso: prototipo")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
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
                .frame(width: 24, height: 24)
                .background(color)
                .clipShape(Circle())

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
