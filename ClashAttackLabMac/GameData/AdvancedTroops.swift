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
        default:
            return TroopStyle(displayName: "Truppa", symbol: "?", red: 0.5, green: 0.5, blue: 0.5, radius: 22)
        }
    }
}
