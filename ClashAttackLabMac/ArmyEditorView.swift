import SwiftUI

struct ArmyEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ArmyConfiguration

    private let onApply: (ArmyConfiguration) -> Void

    init(
        configuration: ArmyConfiguration,
        onApply: @escaping (ArmyConfiguration) -> Void
    ) {
        _draft = State(initialValue: configuration)
        self.onApply = onApply
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Componi esercito")
                    .font(.title2.bold())

                Text(
                    "Il laboratorio genererà 24 piani con questa stessa composizione."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            GroupBox("Truppe") {
                VStack(spacing: 12) {
                    troopRow(
                        symbol: "G",
                        color: .orange,
                        title: "Gigante",
                        cost: 5,
                        value: $draft.giants
                    )
                    troopRow(
                        symbol: "B",
                        color: .red,
                        title: "Barbaro",
                        cost: 1,
                        value: $draft.barbarians
                    )
                    troopRow(
                        symbol: "A",
                        color: .pink,
                        title: "Arciera",
                        cost: 1,
                        value: $draft.archers
                    )
                    troopRow(
                        symbol: "WB",
                        color: .green,
                        title: "Spaccamuro",
                        cost: 2,
                        value: $draft.wallBreakers
                    )
                    troopRow(
                        symbol: "W",
                        color: .blue,
                        title: "Mago",
                        cost: 4,
                        value: $draft.wizards
                    )
                }
                .padding(.vertical, 4)
            }

            GroupBox("Aria") {
                VStack(spacing: 12) {
                    troopRow(
                        symbol: "BL",
                        color: .indigo,
                        title: "Mongolfiera",
                        cost: 3,
                        value: $draft.balloons
                    )
                    troopRow(
                        symbol: "DR",
                        color: .mint,
                        title: "Drago",
                        cost: 2,
                        value: $draft.dragons
                    )
                }
                .padding(.vertical, 4)
            }

            GroupBox("Eroe") {
                troopRow(
                    symbol: "BK",
                    color: .yellow,
                    title: "Re barbaro",
                    cost: 0,
                    value: $draft.barbarianKings
                )
                troopRow(
                    symbol: "AQ",
                    color: .purple,
                    title: "Regina degli arcieri",
                    cost: 0,
                    value: $draft.archerQueens
                )
            }

            GroupBox("Macchina d’assedio") {
                troopRow(
                    symbol: "AR",
                    color: .brown,
                    title: "Ariete da guerra",
                    cost: 0,
                    value: $draft.wallWreckers
                )
                troopRow(
                    symbol: "SP",
                    color: .cyan,
                    title: "Schiantapietre",
                    cost: 0,
                    value: $draft.stoneSlammers
                )
            }

            GroupBox("Incantesimi") {
                VStack(spacing: 12) {
                    spellRow(
                        symbol: "H",
                        color: .green,
                        title: "Cura",
                        value: $draft.healSpells
                    )
                    spellRow(
                        symbol: "R",
                        color: .purple,
                        title: "Furia",
                        value: $draft.rageSpells
                    )
                    spellRow(
                        symbol: "F",
                        color: .cyan,
                        title: "Gelo",
                        value: $draft.freezeSpells
                    )
                    spellRow(
                        symbol: "L",
                        color: .yellow,
                        title: "Fulmine",
                        value: $draft.lightningSpells
                    )
                    spellRow(
                        symbol: "E",
                        color: .orange,
                        title: "Terremoto",
                        value: $draft.earthquakeSpells
                    )
                }
                .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(
                        "Capacità truppe",
                        systemImage: "person.3.fill"
                    )
                    Spacer()
                    Text(
                        "\(draft.troopCapacityUsed)/\(ArmyConfiguration.maximumTroopCapacity)"
                    )
                    .monospacedDigit()
                }

                ProgressView(
                    value: Double(draft.troopCapacityUsed),
                    total: Double(ArmyConfiguration.maximumTroopCapacity)
                )
                .tint(
                    draft.troopCapacityUsed >
                        ArmyConfiguration.maximumTroopCapacity
                        ? .red
                        : .accentColor
                )

                HStack {
                    Label(
                        "Capacità incantesimi",
                        systemImage: "sparkles"
                    )
                    Spacer()
                    Text(
                        "\(draft.spellCapacityUsed)/\(ArmyConfiguration.maximumSpellCapacity)"
                    )
                    .monospacedDigit()
                }
                .font(.subheadline)

                if let message = draft.validationMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text(
                        "\(draft.totalTroops) truppe · configurazione valida"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Annulla") {
                    dismiss()
                }

                Spacer()

                Button("Ripristina") {
                    draft = .prototypeDefault
                }

                Button("Applica e rigenera") {
                    onApply(draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!draft.isValid)
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func troopRow(
        symbol: String,
        color: Color,
        title: String,
        cost: Int,
        value: Binding<Int>
    ) -> some View {
        HStack(spacing: 12) {
            symbolView(symbol, color: color)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text("costo prototipo: \(cost)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Stepper(
                value: value,
                in: cost == 0 ? 0...1 : 0...12
            ) {
                Text("\(value.wrappedValue)")
                    .font(.body.monospacedDigit())
                    .frame(width: 24, alignment: .trailing)
            }
        }
    }

    private func spellRow(
        symbol: String,
        color: Color,
        title: String,
        value: Binding<Int>
    ) -> some View {
        HStack(spacing: 12) {
            symbolView(symbol, color: color)

            Text(title)

            Spacer()

            Stepper(value: value, in: 0...4) {
                Text("\(value.wrappedValue)")
                    .font(.body.monospacedDigit())
                    .frame(width: 24, alignment: .trailing)
            }
        }
    }

    private func symbolView(
        _ symbol: String,
        color: Color
    ) -> some View {
        Text(symbol)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(width: 34, height: 26)
            .background(color)
            .clipShape(Capsule())
    }
}
