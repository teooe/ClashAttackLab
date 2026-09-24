import Foundation

/// User-selected army used by every generated candidate.
///
/// Capacity values are prototype constraints. They exist to keep comparisons
/// fair and are not presented as official housing-space statistics.
nonisolated struct ArmyConfiguration: Equatable {
    static let maximumTroopCapacity = 30
    static let maximumSpellCapacity = 4

    var giants: Int
    var barbarians: Int
    var archers: Int
    var wallBreakers: Int
    var wizards: Int
    var balloons: Int
    var dragons: Int
    var barbarianKings: Int
    var archerQueens: Int
    var wallWreckers: Int
    var stoneSlammers: Int
    var healSpells: Int
    var rageSpells: Int
    var freezeSpells: Int
    var lightningSpells: Int
    var earthquakeSpells: Int

    init(
        giants: Int,
        barbarians: Int,
        archers: Int,
        wallBreakers: Int,
        wizards: Int,
        healSpells: Int,
        rageSpells: Int,
        freezeSpells: Int = 0,
        lightningSpells: Int = 0,
        earthquakeSpells: Int = 0,
        balloons: Int = 0,
        dragons: Int = 0,
        barbarianKings: Int = 0,
        archerQueens: Int = 0,
        wallWreckers: Int = 0,
        stoneSlammers: Int = 0
    ) {
        self.giants = giants
        self.barbarians = barbarians
        self.archers = archers
        self.wallBreakers = wallBreakers
        self.wizards = wizards
        self.balloons = balloons
        self.dragons = dragons
        self.barbarianKings = barbarianKings
        self.archerQueens = archerQueens
        self.wallWreckers = wallWreckers
        self.stoneSlammers = stoneSlammers
        self.healSpells = healSpells
        self.rageSpells = rageSpells
        self.freezeSpells = freezeSpells
        self.lightningSpells = lightningSpells
        self.earthquakeSpells = earthquakeSpells
    }

    static let prototypeDefault = ArmyConfiguration(
        giants: 2,
        barbarians: 2,
        archers: 2,
        wallBreakers: 2,
        wizards: 1,
        healSpells: 1,
        rageSpells: 1,
        freezeSpells: 0,
        lightningSpells: 1,
        earthquakeSpells: 1,
        balloons: 2,
        dragons: 1,
        barbarianKings: 1,
        archerQueens: 1,
        wallWreckers: 1,
        stoneSlammers: 0
    )

    var totalTroops: Int {
        giants + barbarians + archers + wallBreakers + wizards +
            balloons + dragons + barbarianKings + archerQueens +
            wallWreckers + stoneSlammers
    }

    static let troopKinds: [BattleEntityKind] = [
        .giant, .barbarian, .archer, .wallBreaker, .wizard, .balloon,
        .dragon, .barbarianKing, .archerQueen, .wallWrecker, .stoneSlammer
    ]

    static let spellKinds: [BattleSpellKind] = [
        .heal, .rage, .freeze, .lightning, .earthquake
    ]

    var troopCapacityUsed: Int {
        troopCapacityUsed(under: .prototype)
    }

    var spellCapacityUsed: Int {
        spellCapacityUsed(under: .prototype)
    }

    func troopCapacityUsed(under rules: ArmyCapacityRules) -> Int {
        Self.troopKinds.reduce(0) {
            $0 + troopCount(for: $1) * rules.housing(for: $1)
        }
    }

    func spellCapacityUsed(under rules: ArmyCapacityRules) -> Int {
        Self.spellKinds.reduce(0) {
            $0 + spellCount(for: $1) * rules.housing(for: $1)
        }
    }

    var distinctTroopKindCount: Int {
        [
            giants,
            barbarians,
            archers,
            wallBreakers,
            wizards,
            balloons,
            dragons,
            barbarianKings,
            archerQueens,
            wallWreckers,
            stoneSlammers
        ].filter { $0 > 0 }.count
    }

    var isValid: Bool {
        isValid(under: .prototype)
    }

    var validationMessage: String? {
        validationMessage(under: .prototype)
    }

    func isValid(under rules: ArmyCapacityRules) -> Bool {
        validationMessage(under: rules) == nil
    }

    func validationMessage(under rules: ArmyCapacityRules) -> String? {
        if !allCountsAreNonnegative {
            return "Le quantità non possono essere negative."
        }

        if totalTroops == 0 {
            return "Aggiungi almeno una truppa."
        }

        if troopCapacityUsed(under: rules) > rules.troopCapacity {
            return "Capacità truppe superata."
        }

        if barbarianKings > 1 || archerQueens > 1 {
            return "Puoi usare un solo esemplare per ciascun eroe."
        }

        if wallWreckers + stoneSlammers > 1 {
            return "Puoi usare una sola macchina d’assedio."
        }

        if spellCapacityUsed(under: rules) > rules.spellCapacity {
            return "Capacità incantesimi superata."
        }

        if let locked = Self.troopKinds.first(where: {
            troopCount(for: $0) > 0 && !rules.allows($0)
        }) {
            return "\(rules.lockedName(for: locked)) non è ancora sbloccato."
        }

        if let locked = Self.spellKinds.first(where: {
            spellCount(for: $0) > 0 && !rules.allows($0)
        }) {
            return "\(rules.lockedName(for: locked)) non è ancora sbloccato."
        }

        return nil
    }

    func troopCount(for kind: BattleEntityKind) -> Int {
        switch kind {
        case .giant:
            return giants
        case .barbarian:
            return barbarians
        case .archer:
            return archers
        case .wallBreaker:
            return wallBreakers
        case .wizard:
            return wizards
        case .balloon:
            return balloons
        case .dragon:
            return dragons
        case .barbarianKing:
            return barbarianKings
        case .archerQueen:
            return archerQueens
        case .wallWrecker:
            return wallWreckers
        case .stoneSlammer:
            return stoneSlammers
        case .cannon, .archerTower, .mortar, .wizardTower, .infernoTower, .bombTower, .hiddenTesla, .giantBomb, .airBomb, .airSweeper, .airDefense,
             .townHall, .goldStorage, .wall:
            return 0
        }
    }

    func spellCount(for kind: BattleSpellKind) -> Int {
        switch kind {
        case .heal:
            return healSpells
        case .rage:
            return rageSpells
        case .freeze:
            return freezeSpells
        case .lightning:
            return lightningSpells
        case .earthquake:
            return earthquakeSpells
        }
    }

    var deploymentSequence: [BattleEntityKind] {
        var remaining: [BattleEntityKind: Int] = [
            .wallBreaker: wallBreakers,
            .giant: giants,
            .barbarian: barbarians,
            .archer: archers,
            .wizard: wizards,
            .balloon: balloons,
            .dragon: dragons,
            .barbarianKing: barbarianKings,
            .archerQueen: archerQueens,
            .wallWrecker: wallWreckers,
            .stoneSlammer: stoneSlammers
        ]
        let preferredOrder: [BattleEntityKind] = [
            .wallBreaker,
            .giant,
            .barbarian,
            .archer,
            .wizard,
            .balloon,
            .dragon,
            .barbarianKing,
            .archerQueen,
            .wallWrecker,
            .stoneSlammer
        ]
        var result: [BattleEntityKind] = []

        while remaining.values.contains(where: { $0 > 0 }) {
            for kind in preferredOrder
            where remaining[kind, default: 0] > 0 {
                result.append(kind)
                remaining[kind, default: 0] -= 1
            }
        }

        return result
    }

    var spellSequence: [BattleSpellKind] {
        Array(repeating: .heal, count: healSpells) +
            Array(repeating: .rage, count: rageSpells) +
            Array(repeating: .freeze, count: freezeSpells) +
            Array(repeating: .lightning, count: lightningSpells) +
            Array(repeating: .earthquake, count: earthquakeSpells)
    }

    private var allCountsAreNonnegative: Bool {
        [
            giants,
            barbarians,
            archers,
            wallBreakers,
            wizards,
            balloons,
            dragons,
            barbarianKings,
            archerQueens,
            wallWreckers,
            stoneSlammers,
            healSpells,
            rageSpells,
            freezeSpells,
            lightningSpells,
            earthquakeSpells
        ].allSatisfy { $0 >= 0 }
    }
}


/// Housing costs, capacities and unlocked units used to validate an army.
nonisolated struct ArmyCapacityRules: Equatable {
    var troopCapacity: Int
    var spellCapacity: Int
    var troopHousing: [BattleEntityKind: Int]
    var spellHousing: [BattleSpellKind: Int]

    /// Nil allows every troop or spell.
    var unlockedTroops: Set<BattleEntityKind>?
    var unlockedSpells: Set<BattleSpellKind>?

    /// Short description shown next to the capacity bars.
    var label: String

    /// Prototype constraints that keep comparisons fair; not official values.
    static let prototype = ArmyCapacityRules(
        troopCapacity: ArmyConfiguration.maximumTroopCapacity,
        spellCapacity: ArmyConfiguration.maximumSpellCapacity,
        troopHousing: [
            .giant: 5, .barbarian: 1, .archer: 1, .wallBreaker: 2,
            .wizard: 4, .balloon: 3, .dragon: 2
        ],
        spellHousing: [
            .heal: 1, .rage: 1, .freeze: 1, .lightning: 1, .earthquake: 1
        ],
        unlockedTroops: nil,
        unlockedSpells: nil,
        label: "Prototipo"
    )

    func housing(for kind: BattleEntityKind) -> Int {
        troopHousing[kind] ?? 0
    }

    func housing(for kind: BattleSpellKind) -> Int {
        spellHousing[kind] ?? 0
    }

    func allows(_ kind: BattleEntityKind) -> Bool {
        unlockedTroops?.contains(kind) ?? true
    }

    func allows(_ kind: BattleSpellKind) -> Bool {
        unlockedSpells?.contains(kind) ?? true
    }

    fileprivate func lockedName(for kind: BattleEntityKind) -> String {
        PrototypeGameData().definition(for: kind).displayName
    }

    fileprivate func lockedName(for kind: BattleSpellKind) -> String {
        PrototypeGameData().spellDefinition(for: kind).displayName
    }
}

nonisolated struct ArmySearchVariant {
    let name: String
    let configuration: ArmyConfiguration
}

/// Local, bounded exploration of equal-capacity prototype armies.
/// It does not claim to enumerate every possible composition.
nonisolated enum ArmyCompositionSearch {
    static func variants(
        from source: ArmyConfiguration,
        rules: ArmyCapacityRules = .prototype
    ) -> [ArmySearchVariant] {
        guard source.isValid(under: rules) else { return [] }
        var result = [ArmySearchVariant(name: "Esercito attuale", configuration: source)]
        func append(_ name: String, change: (inout ArmyConfiguration) -> Void) {
            var candidate = source
            change(&candidate)
            guard candidate.isValid(under: rules),
                candidate.troopCapacityUsed(under: rules) ==
                    source.troopCapacityUsed(under: rules),
                !result.contains(where: { $0.configuration == candidate }) else { return }
            result.append(ArmySearchVariant(name: name, configuration: candidate))
        }
        if source.barbarians > 0 {
            append("Barbari → Arcieri") { $0.archers += $0.barbarians; $0.barbarians = 0 }
        }
        if source.archers > 0 {
            append("Arcieri → Barbari") { $0.barbarians += $0.archers; $0.archers = 0 }
        }
        if source.giants > 0 {
            append("Gigante → Mago e Barbaro") {
                $0.giants -= 1; $0.wizards += 1; $0.barbarians += 1
            }
            append("Gigante → Mongolfiera e Drago") {
                $0.giants -= 1; $0.balloons += 1; $0.dragons += 1
            }
        }
        if source.wizards > 0 {
            append("Mago → quattro Arcieri") { $0.wizards -= 1; $0.archers += 4 }
        }
        if source.balloons > 0 {
            append("Mongolfiera → tre Barbari") { $0.balloons -= 1; $0.barbarians += 3 }
        }
        return result
    }
}
