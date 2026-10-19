import SwiftUI

struct ArmyEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ArmyConfiguration

    private let rules: ArmyCapacityRules
    private let defaultArmy: ArmyConfiguration
    private let presets: [ArmySearchVariant]
    private let onApply: (ArmyConfiguration) -> Void

    init(
        configuration: ArmyConfiguration,
        rules: ArmyCapacityRules = .prototype,
        defaultArmy: ArmyConfiguration = .prototypeDefault,
        presets: [ArmySearchVariant] = [],
        onApply: @escaping (ArmyConfiguration) -> Void
    ) {
        _draft = State(initialValue: configuration)
        self.rules = rules
        self.defaultArmy = defaultArmy
        self.presets = presets
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

            // The advanced troops make the list taller than small screens.
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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

                    if BattleEntityKind.advancedTroops.contains(where: { rules.allows($0) }) {
                        GroupBox("Truppe avanzate") {
                            VStack(spacing: 12) {
                                ForEach(
                                    BattleEntityKind.advancedTroops.filter { rules.allows($0) },
                                    id: \.self
                                ) { kind in
                                    let style = TroopStyle.style(for: kind)
                                    troopRow(
                                        symbol: style.symbol,
                                        color: Color(
                                            red: style.red,
                                            green: style.green,
                                            blue: style.blue
                                        ),
                                        title: style.displayName,
                                        kind: kind,
                                        value: Binding(
                                            get: { draft[troop: kind] },
                                            set: { draft[troop: kind] = $0 }
                                        )
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
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
                        ForEach(BattleEntityKind.advancedHeroes, id: \.self) { kind in
                            let style = TroopStyle.style(for: kind)
                            troopRow(
                                symbol: style.symbol,
                                color: Color(
                                    red: style.red,
                                    green: style.green,
                                    blue: style.blue
                                ),
                                title: style.displayName,
                                kind: kind,
                                value: Binding(
                                    get: { draft[troop: kind] },
                                    set: { draft[troop: kind] = $0 }
                                )
                            )
                        }
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
                        ForEach(
                            BattleEntityKind.advancedSiegeMachines.filter { rules.allows($0) },
                            id: \.self
                        ) { kind in
                            let style = TroopStyle.style(for: kind)
                            troopRow(
                                symbol: style.symbol,
                                color: Color(red: style.red, green: style.green, blue: style.blue),
                                title: style.displayName,
                                kind: kind,
                                value: Binding(
                                    get: { draft[troop: kind] },
                                    set: { draft[troop: kind] = $0 }
                                )
                            )
                        }
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
                            ForEach(ArmyConfiguration.advancedSpellKinds, id: \.self) { kind in
                                let style = SpellStyle.style(for: kind)
                                spellRow(
                                    symbol: style.symbol,
                                    color: Color(
                                        red: style.red,
                                        green: style.green,
                                        blue: style.blue
                                    ),
                                    title: style.displayName,
                                    kind: kind,
                                    value: Binding(
                                        get: { draft[spell: kind] },
                                        set: { draft[spell: kind] = $0 }
                                    )
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxHeight: 520)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(
                        "Capacità truppe",
                        systemImage: "person.3.fill"
                    )
                    Spacer()
                    Text(
                        "\(draft.troopCapacityUsed(under: rules))/\(rules.totalTroopCapacity)" +
                            (rules.clanCastleTroopCapacity > 0
                                ? " · Castello \(rules.clanCastleTroopCapacity)"
                                : "")
                    )
                    .monospacedDigit()
                }

                ProgressView(
                    value: Double(
                        min(draft.troopCapacityUsed(under: rules), rules.totalTroopCapacity)
                    ),
                    total: Double(max(rules.totalTroopCapacity, 1))
                )
                .tint(
                    draft.troopCapacityUsed(under: rules) > rules.totalTroopCapacity
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
                        "\(draft.spellCapacityUsed(under: rules))/\(rules.totalSpellCapacity)" +
                            (rules.clanCastleSpellCapacity > 0
                                ? " · Castello \(rules.clanCastleSpellCapacity)"
                                : "")
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

                if !presets.isEmpty {
                    Menu("Formazioni") {
                        ForEach(presets.indices, id: \.self) { index in
                            Button(presets[index].name) {
                                draft = presets[index].configuration
                            }
                        }
                    }
                    .fixedSize()
                }

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
        let uniqueKinds: [BattleEntityKind] = BattleEntityKind.heroKinds +
            BattleEntityKind.siegeMachineKinds
        let isUnique = uniqueKinds.contains(kind)
        let maximum = isUnique
            ? 1
            : max(12, rules.totalTroopCapacity / max(cost, 1))

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

            Stepper(value: value, in: 0...max(4, rules.totalSpellCapacity)) {
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
