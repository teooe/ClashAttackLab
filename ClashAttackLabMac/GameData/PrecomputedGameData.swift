import Foundation

/// Resolves every definition once so the simulation's hot loops read a
/// dictionary instead of rebuilding definitions on each lookup.
///
/// Engines look definitions up thousands of times per battle; providers such
/// as `ReferenceGameData` assemble each definition from the catalog, which is
/// far too slow to repeat every tick.
nonisolated struct PrecomputedGameData: GameDataProviding {
    let source: any GameDataProviding
    private let definitions: [BattleEntityKind: CombatDefinition]
    private let spellDefinitions: [BattleSpellKind: SpellDefinition]
    let battleDuration: TimeInterval

    init(_ source: any GameDataProviding) {
        self.source = source
        definitions = Dictionary(
            uniqueKeysWithValues: BattleEntityKind.allCases.map {
                ($0, source.definition(for: $0))
            }
        )
        spellDefinitions = Dictionary(
            uniqueKeysWithValues: BattleSpellKind.allCases.map {
                ($0, source.spellDefinition(for: $0))
            }
        )
        battleDuration = source.battleDuration
    }

    /// Avoids wrapping a provider that is already precomputed.
    static func wrapping(_ gameData: any GameDataProviding) -> PrecomputedGameData {
        (gameData as? PrecomputedGameData) ?? PrecomputedGameData(gameData)
    }

    func definition(for kind: BattleEntityKind) -> CombatDefinition {
        definitions[kind] ?? source.definition(for: kind)
    }

    func spellDefinition(for kind: BattleSpellKind) -> SpellDefinition {
        spellDefinitions[kind] ?? source.spellDefinition(for: kind)
    }
}
