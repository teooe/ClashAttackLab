import SwiftUI

struct BaseReconnaissanceView: View {
    @ObservedObject var session: AttackLabSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Ricognizione della base", systemImage: "map")
                    .font(.title2.bold())

                Spacer()

                Button("Ricalcola") {
                    session.analyzeCurrentBase()
                }

                Button("Fine") {
                    dismiss()
                }
            }

            Text(
                "Lettura tecnica della base attuale: percorsi A* reali del simulatore e pressione difensiva stimata."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            if let reconnaissance = session.baseReconnaissance {
                VStack(alignment: .leading, spacing: 5) {
                    Text(reconnaissance.layoutName)
                        .font(.headline)
                    Text(reconnaissance.recommendationText)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                List(reconnaissance.lanes) { lane in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lane.label)
                                .font(.headline)
                            Text("Primo bersaglio: \(lane.firstTargetName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(
                                String(
                                    format: "Percorso %.0f · muri %d · pressione %.1f",
                                    lane.pathCost,
                                    lane.wallCrossings,
                                    lane.pressureScore
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if lane.id == reconnaissance.recommendedLane?.id {
                            Text("Consigliata")
                                .font(.caption.bold())
                                .foregroundStyle(.tint)
                        }

                        Button("Applica") {
                            session.applyReconnaissanceLane(lane)
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                ContentUnavailableView(
                    "Nessuna ricognizione",
                    systemImage: "map",
                    description: Text(
                        "Premi Ricalcola per analizzare le corsie della base."
                    )
                )
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 520)
        .onAppear {
            if session.baseReconnaissance == nil {
                session.analyzeCurrentBase()
            }
        }
    }
}
