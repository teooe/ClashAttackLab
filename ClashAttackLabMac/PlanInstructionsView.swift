import AppKit
import SwiftUI

/// The loaded plan as numbered steps to repeat by hand on a phone.
struct PlanInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    let title: String
    let steps: [PlanInstructionStep]
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Istruzioni")
                    .font(.title2.bold())
                Text(title)
                    .font(.headline)
                Text("Lati e angoli sono quelli della mappa come la vedi in quest'app. I tempi sono indicativi: conta l'ordine.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if steps.isEmpty {
                Text("Il piano caricato non ha ordini.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(steps) { step in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(step.id).")
                                    .font(.body.monospacedDigit().bold())
                                    .frame(width: 30, alignment: .trailing)
                                Text(step.timeLabel)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 52, alignment: .leading)
                                Text(step.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .frame(maxHeight: 460)
            }

            HStack {
                Button(copied ? "Copiato" : "Copia testo") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    copied = true
                }
                .disabled(steps.isEmpty)
                Spacer()
                Button("Chiudi") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}
