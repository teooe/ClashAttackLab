import SpriteKit
import SwiftUI

struct ContentView: View {
    private let scene: BattleScene = {
        let gameData = PrototypeGameData()
        let navigationGrid = PrototypeBattleMap.makeNavigationGrid()

        let entities = [
            BattleEntity(
                kind: .giant,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 2, row: 4)
                )
            ),
            BattleEntity(
                kind: .giant,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 2, row: 11)
                )
            ),
            BattleEntity(
                kind: .cannon,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 17, row: 3)
                )
            ),
            BattleEntity(
                kind: .cannon,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 21, row: 8)
                )
            ),
            BattleEntity(
                kind: .cannon,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(column: 17, row: 13)
                )
            )
        ]

        let simulation = SimulationEngine(
            entities: entities,
            gameData: gameData,
            navigationGrid: navigationGrid
        )

        return BattleScene(
            size: CGSize(width: 1_100, height: 760),
            simulation: simulation,
            navigationGrid: navigationGrid
        )
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clash Attack Lab")
                        .font(.title2.bold())

                    Text("Milestone 3 · Muri e pathfinding A*")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Muri statici · approssimazione")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
                .frame(minWidth: 820, minHeight: 580)
        }
    }
}

#Preview {
    ContentView()
}
