import Foundation

extension BattleEntityKind {
    /// Troops unlocked between Town Hall 7 and 15 that the real mode adds
    /// on top of the original prototype army.
    nonisolated static let advancedTroops: [BattleEntityKind] = [
        .hogRider, .valkyrie, .golem, .bowler, .miner, .pekka, .yeti,
        .rootRider, .electroDragon, .dragonRider, .lavaHound
    ]

    nonisolated var isAdvancedTroop: Bool {
        Self.advancedTroops.contains(self)
    }

    /// Heroes added for the real mode next to the King and the Queen.
    nonisolated static let advancedHeroes: [BattleEntityKind] = [
        .grandWarden, .royalChampion
    ]

    nonisolated static let heroKinds: [BattleEntityKind] = [
        .barbarianKing, .archerQueen
    ] + advancedHeroes

    nonisolated var isHero: Bool {
        Self.heroKinds.contains(self)
    }

    /// Troops that only appear when another one dies (Lava Hound, Golem);
    /// they cannot be trained and have no catalog entry of their own.
    nonisolated static let spawnedTroops: [BattleEntityKind] = [
        .lavaPup, .golemite
    ]
}

/// Name, map symbol, colour and body size shared by every view that draws
/// one of the advanced troops.
nonisolated struct TroopStyle {
    let displayName: String
    let symbol: String
    let red: Double
    let green: Double
    let blue: Double

    /// Radius of the troop's body in scene points.
    let radius: Double

    static func style(for kind: BattleEntityKind) -> TroopStyle {
        switch kind {
        case .hogRider:
            return TroopStyle(displayName: "Domatore di cinghiali", symbol: "HR", red: 0.62, green: 0.40, blue: 0.24, radius: 25)
        case .valkyrie:
            return TroopStyle(displayName: "Valchiria", symbol: "VA", red: 0.90, green: 0.45, blue: 0.20, radius: 25)
        case .golem:
            return TroopStyle(displayName: "Golem", symbol: "GO", red: 0.45, green: 0.42, blue: 0.38, radius: 38)
        case .bowler:
            return TroopStyle(displayName: "Bowler", symbol: "BW", red: 0.35, green: 0.45, blue: 0.85, radius: 26)
        case .miner:
            return TroopStyle(displayName: "Minatore", symbol: "MI", red: 0.55, green: 0.48, blue: 0.30, radius: 22)
        case .pekka:
            return TroopStyle(displayName: "P.E.K.K.A", symbol: "PK", red: 0.25, green: 0.30, blue: 0.55, radius: 32)
        case .yeti:
            return TroopStyle(displayName: "Yeti", symbol: "YE", red: 0.70, green: 0.85, blue: 0.95, radius: 34)
        case .rootRider:
            return TroopStyle(displayName: "Cavalcaradici", symbol: "RR", red: 0.30, green: 0.55, blue: 0.25, radius: 34)
        case .electroDragon:
            return TroopStyle(displayName: "Elettrodrago", symbol: "ED", red: 0.25, green: 0.55, blue: 0.95, radius: 36)
        case .dragonRider:
            return TroopStyle(displayName: "Cavaliere del drago", symbol: "CD", red: 0.75, green: 0.25, blue: 0.20, radius: 34)
        case .lavaHound:
            return TroopStyle(displayName: "Mastino lavico", symbol: "LH", red: 0.85, green: 0.30, blue: 0.10, radius: 38)
        case .grandWarden:
            return TroopStyle(displayName: "Gran Sorvegliante", symbol: "GW", red: 0.95, green: 0.80, blue: 0.45, radius: 32)
        case .royalChampion:
            return TroopStyle(displayName: "Campionessa reale", symbol: "RC", red: 0.20, green: 0.70, blue: 0.75, radius: 32)
        case .lavaPup:
            return TroopStyle(displayName: "Cucciolo lavico", symbol: "lp", red: 0.95, green: 0.45, blue: 0.15, radius: 14)
        case .golemite:
            return TroopStyle(displayName: "Golemita", symbol: "gm", red: 0.55, green: 0.52, blue: 0.48, radius: 20)
        default:
            return TroopStyle(displayName: "Truppa", symbol: "?", red: 0.5, green: 0.5, blue: 0.5, radius: 22)
        }
    }
}

/// Name, map symbol and colour of the spells added for the real mode.
nonisolated struct SpellStyle {
    let displayName: String
    let symbol: String
    let red: Double
    let green: Double
    let blue: Double

    static func style(for kind: BattleSpellKind) -> SpellStyle {
        switch kind {
        case .jump:
            return SpellStyle(displayName: "Salto", symbol: "J", red: 0.45, green: 0.80, blue: 0.30)
        case .invisibility:
            return SpellStyle(displayName: "Invisibilità", symbol: "I", red: 0.70, green: 0.70, blue: 0.90)
        case .haste:
            return SpellStyle(displayName: "Velocità", symbol: "V", red: 0.95, green: 0.55, blue: 0.75)
        case .poison:
            return SpellStyle(displayName: "Veleno", symbol: "P", red: 0.55, green: 0.25, blue: 0.65)
        case .heal:
            return SpellStyle(displayName: "Cura", symbol: "H", red: 0.2, green: 0.8, blue: 0.3)
        case .rage:
            return SpellStyle(displayName: "Furia", symbol: "R", red: 0.6, green: 0.3, blue: 0.8)
        case .freeze:
            return SpellStyle(displayName: "Gelo", symbol: "F", red: 0.3, green: 0.8, blue: 0.9)
        case .lightning:
            return SpellStyle(displayName: "Fulmine", symbol: "L", red: 0.95, green: 0.85, blue: 0.2)
        case .earthquake:
            return SpellStyle(displayName: "Terremoto", symbol: "E", red: 0.95, green: 0.6, blue: 0.2)
        }
    }
}
