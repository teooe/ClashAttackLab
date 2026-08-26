import SwiftUI

struct ContentView: View {
    private let simulationStatus: SimulationStatus = .ready

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "scope")
                .font(.system(size: 52))
                .foregroundStyle(.blue)

            Text("Clash Attack Lab")
                .font(.largeTitle.bold())

            Text("Laboratorio di simulazione degli attacchi")
                .font(.title3)
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 320)

            Label(
                "Motore di simulazione: \(simulationStatus.displayName)",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
        }
        .frame(minWidth: 640, minHeight: 420)
        .padding(32)
    }
}

#Preview {
    ContentView()
}
