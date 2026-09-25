import SwiftUI

struct ArmyEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ArmyConfiguration

    private let rules: ArmyCapacityRules
    private let defaultArmy: ArmyConfiguration
    private let onApply: (ArmyConfiguration) -> Void

    init(
        configuration: ArmyConfiguration,
        rules: ArmyCapacityRules = .prototype,
        defaultArmy: ArmyConfiguration = .prototypeDefault,
        onApply: @escaping (ArmyConfiguration) -> Void
    ) {
        _draft = State(initialValue: configuration)
        self.rules = rules
        self.defaultArmy = defaultArmy
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
                        kind: .giant,
                        value: $draft.giants
                    )
                    troopRow(
                        symbol: "B",
                        color: .red,
                        title: "Barbaro",
                        kind: .barbarian,
                        value: $draft.barbarians
                    )
                    troopRow(
                        symbol: "A",
                        color: .pink,
                        title: "Arciera",
                        kind: .archer,
                        value: $draft.archers
                    )
                    troopRow(
                        symbol: "WB",
                        color: .green,
                        title: "Spaccamuro",
                        kind: .wallBreaker,
                        value: $draft.wallBreakers
                    )
                    troopRow(
                        symbol: "W",
                        color: .blue,
                        title: "Mago",
                        kind: .wizard,
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
                        kind: .balloon,
                        value: $draft.balloons
                    )
                    troopRow(
                        symbol: "DR",
                        color: .mint,
                        title: "Drago",
                        kind: .dragon,
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
                    kind: .barbarianKing,
                    value: $draft.barbarianKings
                )
                troopRow(
                    symbol: "AQ",
                    color: .purple,
                    title: "Regina degli arcieri",
                    kind: .archerQueen,
                    value: $draft.archerQueens
                )
            }

            GroupBox("Macchina d’assedio") {
                troopRow(
                    symbol: "AR",
                    color: .brown,
                    title: "Ariete da guerra",
                    kind: .wallWrecker,
                    value: $draft.wallWreckers
                )
                troopRow(
                    symbol: "SP",
                    color: .cyan,
                    title: "Schiantapietre",
                    kind: .stoneSlammer,
                    value: $draft.stoneSlammers
                )
            }

            GroupBox("Incantesimi") {
                VStack(spacing: 12) {
                    spellRow(
                        symbol: "H",
                        color: .green,
                        title: "Cura",
                        kind: .heal,
                        value: $draft.healSpells
                    )
                    spellRow(
                        symbol: "R",
                        color: .purple,
                        title: "Furia",
                        kind: .rage,
                        value: $draft.rageSpells
                    )
                    spellRow(
                        symbol: "F",
                        color: .cyan,
                        title: "Gelo",
                        kind: .freeze,
                        value: $draft.freezeSpells
                    )
                    spellRow(
                        symbol: "L",
                        color: .yellow,
                        title: "Fulmine",
                        kind: .lightning,
                        value: $draft.lightningSpells
                    )
                    spellRow(
                        symbol: "E",
                        color: .orange,
                        title: "Terremoto",
                        kind: .earthquake,
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
                        "\(draft.troopCapacityUsed(under: rules))/\(rules.troopCapacity)"
                    )
                    .monospacedDigit()
                }

                ProgressView(
                    value: Double(
                        min(draft.troopCapacityUsed(under: rules), rules.troopCapacity)
                    ),
                    total: Double(max(rules.troopCapacity, 1))
                )
                .tint(
                    draft.troopCapacityUsed(under: rules) > rules.troopCapacity
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
                        "\(draft.spellCapacityUsed(under: rules))/\(rules.spellCapacity)"
                    )
                    .monospacedDigit()
                }
                .font(.subheadline)

                if let message = draft.validationMessage(under: rules) {
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
                    draft = defaultArmy
                }

                Button("Applica e rigenera") {
                    onApply(draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!draft.isValid(under: rules))
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func troopRow(
        symbol: String,
        color: Color,
        title: String,
        kind: BattleEntityKind,
        value: Binding<Int>
    ) -> some View {
        let cost = rules.housing(for: kind)
        let uniqueKinds: [BattleEntityKind] = [
            .barbarianKing, .archerQueen, .wallWrecker, .stoneSlammer
        ]
        let isUnique = uniqueKinds.contains(kind)
        let maximum = isUnique
            ? 1
            : max(12, rules.troopCapacity / max(cost, 1))

        return HStack(spacing: 12) {
            symbolView(symbol, color: color)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(
                    rules.allows(kind)
                        ? "spazio: \(cost)"
                        : "non sbloccato"
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Stepper(
                value: value,
                in: 0...maximum
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
        kind: BattleSpellKind,
        value: Binding<Int>
    ) -> some View {
        HStack(spacing: 12) {
            symbolView(symbol, color: color)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(
                    rules.allows(kind)
                        ? "spazio: \(rules.housing(for: kind))"
                        : "non sbloccato"
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Stepper(value: value, in: 0...max(4, rules.spellCapacity)) {
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
