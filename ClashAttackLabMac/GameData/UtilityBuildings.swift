import Foundation

extension BattleEntityKind {
    /// Village buildings that neither attack nor store the main loot:
    /// collectors, army buildings, huts. They count for destruction.
    nonisolated static let utilityBuildings: [BattleEntityKind] = [
        .goldMine, .elixirCollector, .darkElixirDrill, .elixirStorage,
        .darkElixirStorage, .clanCastle, .armyCamp, .barracks, .darkBarracks,
        .laboratory, .spellFactory, .darkSpellFactory, .workshop, .heroHall,
        .petHouse, .blacksmith, .builderHut, .helperHut
    ]

    nonisolated var isUtilityBuilding: Bool {
        Self.utilityBuildings.contains(self)
    }
}

/// Name, map symbol and colour shared by every view that draws a
/// non-defensive building.
nonisolated struct UtilityBuildingStyle {
    let displayName: String
    let symbol: String
    let red: Double
    let green: Double
    let blue: Double

    static func style(for kind: BattleEntityKind) -> UtilityBuildingStyle {
        switch kind {
        case .goldMine:
            return UtilityBuildingStyle(displayName: "Miniera d’oro", symbol: "MO", red: 0.85, green: 0.68, blue: 0.16)
        case .elixirCollector:
            return UtilityBuildingStyle(displayName: "Estrattore di elisir", symbol: "EE", red: 0.72, green: 0.30, blue: 0.78)
        case .darkElixirDrill:
            return UtilityBuildingStyle(displayName: "Trivella elisir nero", symbol: "TN", red: 0.25, green: 0.20, blue: 0.30)
        case .elixirStorage:
            return UtilityBuildingStyle(displayName: "Deposito di elisir", symbol: "DE", red: 0.62, green: 0.22, blue: 0.70)
        case .darkElixirStorage:
            return UtilityBuildingStyle(displayName: "Deposito elisir nero", symbol: "DN", red: 0.18, green: 0.14, blue: 0.24)
        case .clanCastle:
            return UtilityBuildingStyle(displayName: "Castello del clan", symbol: "CC", red: 0.55, green: 0.36, blue: 0.22)
        case .armyCamp:
            return UtilityBuildingStyle(displayName: "Accampamento", symbol: "AC", red: 0.52, green: 0.44, blue: 0.30)
        case .barracks:
            return UtilityBuildingStyle(displayName: "Caserma", symbol: "CS", red: 0.60, green: 0.38, blue: 0.28)
        case .darkBarracks:
            return UtilityBuildingStyle(displayName: "Caserma nera", symbol: "CN", red: 0.30, green: 0.26, blue: 0.34)
        case .laboratory:
            return UtilityBuildingStyle(displayName: "Laboratorio", symbol: "LB", red: 0.36, green: 0.52, blue: 0.62)
        case .spellFactory:
            return UtilityBuildingStyle(displayName: "Fabbrica incantesimi", symbol: "FI", red: 0.48, green: 0.34, blue: 0.66)
        case .darkSpellFactory:
            return UtilityBuildingStyle(displayName: "Fabbrica incantesimi neri", symbol: "FN", red: 0.28, green: 0.22, blue: 0.40)
        case .workshop:
            return UtilityBuildingStyle(displayName: "Officina d’assedio", symbol: "OF", red: 0.46, green: 0.40, blue: 0.36)
        case .heroHall:
            return UtilityBuildingStyle(displayName: "Sala degli eroi", symbol: "SE", red: 0.70, green: 0.56, blue: 0.24)
        case .petHouse:
            return UtilityBuildingStyle(displayName: "Casa dei cuccioli", symbol: "CU", red: 0.64, green: 0.48, blue: 0.40)
        case .blacksmith:
            return UtilityBuildingStyle(displayName: "Fabbro", symbol: "FB", red: 0.40, green: 0.40, blue: 0.44)
        case .builderHut:
            return UtilityBuildingStyle(displayName: "Capanna del costruttore", symbol: "CP", red: 0.58, green: 0.50, blue: 0.36)
        case .helperHut:
            return UtilityBuildingStyle(displayName: "Capanna degli aiutanti", symbol: "AI", red: 0.52, green: 0.56, blue: 0.40)
        default:
            return UtilityBuildingStyle(displayName: "Edificio", symbol: "E", red: 0.45, green: 0.45, blue: 0.45)
        }
    }
}
