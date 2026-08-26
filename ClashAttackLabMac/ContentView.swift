import SpriteKit
import SwiftUI

struct ContentView: View {
    private let scene: BattleScene = {
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

        return BattleScene(
            size: CGSize(width: 1_000, height: 700),
            entities: entities
        )
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clash Attack Lab")
                        .font(.title2.bold())

                    Text("Milestone 1 · Arena statica")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label("Simulazione pronta", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .padding()

            Divider()

            SpriteView(scene: scene)
                .frame(minWidth: 720, minHeight: 520)
        }
    }
}

#Preview {
    ContentView()
}
