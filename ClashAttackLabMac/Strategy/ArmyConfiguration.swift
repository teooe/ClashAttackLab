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

    init(
        giants: Int,
        barbarians: Int,
        archers: Int,
        wallBreakers: Int,
        wizards: Int,
        healSpells: Int,
        rageSpells: Int,
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
    }

    static let prototypeDefault = ArmyConfiguration(
        giants: 2,
        barbarians: 2,
        archers: 2,
        wallBreakers: 2,
        wizards: 1,
        healSpells: 1,
        rageSpells: 1,
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

    var troopCapacityUsed: Int {
        giants * 5 +
            barbarians +
            archers +
            wallBreakers * 2 +
            wizards * 4 +
            balloons * 3 +
            dragons * 2
    }

    var spellCapacityUsed: Int {
        healSpells + rageSpells
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
        totalTroops > 0 &&
            troopCapacityUsed <= Self.maximumTroopCapacity &&
            spellCapacityUsed <= Self.maximumSpellCapacity &&
            barbarianKings <= 1 &&
            archerQueens <= 1 &&
            wallWreckers + stoneSlammers <= 1 &&
            allCountsAreNonnegative
    }

    var validationMessage: String? {
        if !allCountsAreNonnegative {
            return "Le quantità non possono essere negative."
        }

        if totalTroops == 0 {
            return "Aggiungi almeno una truppa."
        }

        if troopCapacityUsed > Self.maximumTroopCapacity {
            return "Capacità truppe superata."
        }

        if barbarianKings > 1 || archerQueens > 1 {
            return "Puoi usare un solo esemplare per ciascun eroe prototipo."
        }

        if wallWreckers + stoneSlammers > 1 {
            return "Puoi usare una sola macchina d’assedio prototipo."
        }

        if spellCapacityUsed > Self.maximumSpellCapacity {
            return "Capacità incantesimi superata."
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
        case .cannon, .archerTower, .mortar, .airDefense,
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
            Array(repeating: .rage, count: rageSpells)
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
            rageSpells
        ].allSatisfy { $0 >= 0 }
    }
}
