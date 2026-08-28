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
    var healSpells: Int
    var rageSpells: Int

    static let prototypeDefault = ArmyConfiguration(
        giants: 2,
        barbarians: 3,
        archers: 3,
        wallBreakers: 2,
        wizards: 2,
        healSpells: 1,
        rageSpells: 1
    )

    var totalTroops: Int {
        giants + barbarians + archers + wallBreakers + wizards
    }

    var troopCapacityUsed: Int {
        giants * 5 +
            barbarians +
            archers +
            wallBreakers * 2 +
            wizards * 4
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
            wizards
        ].filter { $0 > 0 }.count
    }

    var isValid: Bool {
        totalTroops > 0 &&
            troopCapacityUsed <= Self.maximumTroopCapacity &&
            spellCapacityUsed <= Self.maximumSpellCapacity &&
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
        case .cannon, .archerTower, .mortar,
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
            .wizard: wizards
        ]
        let preferredOrder: [BattleEntityKind] = [
            .wallBreaker,
            .giant,
            .barbarian,
            .archer,
            .wizard
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
            healSpells,
            rageSpells
        ].allSatisfy { $0 >= 0 }
    }
}
