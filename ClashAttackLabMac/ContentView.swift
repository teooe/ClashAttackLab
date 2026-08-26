import SpriteKit
import SwiftUI

struct ContentView: View {
    private let scene: BattleScene = {
        let gameData = PrototypeGameData()
        let entities = [
            BattleEntity(
                kind: .giant,
                position: WorldPosition(x: 220, y: 350)
            ),
            BattleEntity(
                kind: .cannon,
                position: WorldPosition(x: 780, y: 350)
            )
        ]

        let simulation = SimulationEngine(
            entities: entities,
            gameData: gameData
        )

        return BattleScene(
            size: CGSize(width: 1_000, height: 700),
            simulation: simulation
        )
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clash Attack Lab")
                        .font(.title2.bold())

                    Text("Milestone 1 · Movimento e combattimento")
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
                .frame(minWidth: 760, minHeight: 540)
        }
    }
}

#Preview {
    ContentView()
}
