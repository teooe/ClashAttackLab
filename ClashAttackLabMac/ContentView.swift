import SpriteKit
import SwiftUI

struct ContentView: View {
    private let scene: BattleScene = {
        let gameData = PrototypeGameData()
        let entities = [
            BattleEntity(
                kind: .giant,
                position: WorldPosition(x: 140, y: 270)
            ),
            BattleEntity(
                kind: .giant,
                position: WorldPosition(x: 140, y: 490)
            ),
            BattleEntity(
                kind: .cannon,
                position: WorldPosition(x: 680, y: 190)
            ),
            BattleEntity(
                kind: .cannon,
                position: WorldPosition(x: 770, y: 380)
            ),
            BattleEntity(
                kind: .cannon,
                position: WorldPosition(x: 680, y: 570)
            )
        ]

        let simulation = SimulationEngine(
            entities: entities,
            gameData: gameData
        )

        return BattleScene(
            size: CGSize(width: 1_100, height: 760),
            simulation: simulation
        )
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clash Attack Lab")
                        .font(.title2.bold())

                    Text("Milestone 2 · Più entità e selezione bersagli")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Dati prototipo · non ufficiali")
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
                .frame(minWidth: 800, minHeight: 570)
        }
    }
}

#Preview {
    ContentView()
}
