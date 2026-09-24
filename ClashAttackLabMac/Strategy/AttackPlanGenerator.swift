import Foundation

/// Produces deterministic candidate plans from independent strategy axes.
///
/// Every candidate uses the exact ArmyConfiguration selected by the user.
/// Identifiers are reused across plans so headless ranking changes only
/// placement and timing, never the army being compared.
nonisolated struct AttackPlanGenerator {
    private struct Formation {
        let name: String
        let firstRow: Int
        let secondRow: Int
        let usesEntryAdvice: Bool
    }

    private struct Tempo {
        let name: String
        let waveGap: TimeInterval
        let withinWaveDelay: TimeInterval
    }

    private struct BreachStyle {
        let name: String
        let wallBreakerOffset: Int
    }

    private let navigationGrid: NavigationGrid
    private let armyConfiguration: ArmyConfiguration
    private let entryAdvice: ArmyEntryAdvice?
    private let baseEntities: [BattleEntity]
    private let gameData: any GameDataProviding
    private let armyRules: ArmyCapacityRules

    init(
        navigationGrid: NavigationGrid,
        armyConfiguration: ArmyConfiguration = .prototypeDefault,
        entryAdvice: ArmyEntryAdvice? = nil,
        baseEntities: [BattleEntity] = [],
        gameData: any GameDataProviding = PrototypeGameData(),
        armyRules: ArmyCapacityRules = .prototype
    ) {
        self.navigationGrid = navigationGrid
        self.armyConfiguration = armyConfiguration
        self.entryAdvice = entryAdvice
        self.baseEntities = baseEntities
        self.gameData = gameData
        self.armyRules = armyRules
    }

    func generate() -> [AttackPlan] {
        precondition(
            armyConfiguration.isValid(under: armyRules),
            armyConfiguration.validationMessage(under: armyRules) ??
                "Configurazione esercito non valida."
        )

        let troopKinds = armyConfiguration.deploymentSequence
        let spellKinds = armyConfiguration.spellSequence
        let entityIDs = troopKinds.enumerated().map {
            SimulationIdentity.make("troop:\($0.offset):\($0.element)")
        }
        let spellIDs = spellKinds.enumerated().map {
            SimulationIdentity.make("spell:\($0.offset):\($0.element)")
        }

        return formations.flatMap { formation in
            tempos.flatMap { tempo in
                breachStyles.map { breachStyle in
                    makePlan(
                        formation: formation,
                        tempo: tempo,
                        breachStyle: breachStyle,
                        troopKinds: troopKinds,
                        spellKinds: spellKinds,
                        entityIDs: entityIDs,
                        spellIDs: spellIDs
                    )
                }
            }
        }
    }

    private var formations: [Formation] {
        var result = [
            Formation(
                name: "Alta",
                firstRow: navigationGrid.scaledRow(fromPrototype: 4),
                secondRow: navigationGrid.scaledRow(fromPrototype: 5),
                usesEntryAdvice: false
            ),
            Formation(
                name: "Centro",
                firstRow: navigationGrid.scaledRow(fromPrototype: 8),
                secondRow: navigationGrid.scaledRow(fromPrototype: 9),
                usesEntryAdvice: false
            ),
            Formation(
                name: "Bassa",
                firstRow: navigationGrid.scaledRow(fromPrototype: 12),
                secondRow: navigationGrid.scaledRow(fromPrototype: 11),
                usesEntryAdvice: false
            ),
            Formation(
                name: "Divisa",
                firstRow: navigationGrid.scaledRow(fromPrototype: 4),
                secondRow: navigationGrid.scaledRow(fromPrototype: 12),
                usesEntryAdvice: false
            )
        ]

        if entryAdvice?.preferredRecommendation != nil {
            result.append(
                Formation(
                    name: "Guidata",
                    firstRow: navigationGrid.scaledRow(fromPrototype: 8),
                    secondRow: navigationGrid.scaledRow(fromPrototype: 8),
                    usesEntryAdvice: true
                )
            )
        }

        return result
    }

    private var tempos: [Tempo] {
        [
            Tempo(
                name: "Rapida",
                waveGap: 2.4,
                withinWaveDelay: 0.3
            ),
            Tempo(
                name: "Bilanciata",
                waveGap: 3.0,
                withinWaveDelay: 0.4
            ),
            Tempo(
                name: "Paziente",
                waveGap: 4.2,
                withinWaveDelay: 0.6
            )
        ]
    }

    private var breachStyles: [BreachStyle] {
        [
            BreachStyle(
                name: "Breccia stretta",
                wallBreakerOffset: 0
            ),
            BreachStyle(
                name: "Breccia larga",
                wallBreakerOffset: 1
            )
        ]
    }

    private func makePlan(
        formation: Formation,
        tempo: Tempo,
        breachStyle: BreachStyle,
        troopKinds: [BattleEntityKind],
        spellKinds: [BattleSpellKind],
        entityIDs: [UUID],
        spellIDs: [UUID]
    ) -> AttackPlan {
        let waveSize = max(
            1,
            armyConfiguration.distinctTroopKindCount
        )
        let deployments = troopKinds.indices.map { index in
            let kind = troopKinds[index]
            let wave = index / waveSize
            let slot = index % waveSize
            let fallbackRow = wave.isMultiple(of: 2)
                ? formation.firstRow
                : formation.secondRow
            let advisedRow = entryAdvice?.recommendation(
                for: kind
            )?.laneRow
            let baseRow = formation.usesEntryAdvice
                ? advisedRow ?? fallbackRow
                : fallbackRow
            let row = deploymentRow(
                for: kind,
                baseRow: baseRow,
                wave: wave,
                breachStyle: breachStyle
            )

            return DeploymentOrder(
                id: entityIDs[index],
                entityID: entityIDs[index],
                kind: kind,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(
                        column: deploymentColumn(for: kind),
                        row: row
                    )
                ),
                deploymentTime: min(
                    59,
                    Double(wave) * tempo.waveGap +
                        Double(slot) * tempo.withinWaveDelay
                )
            )
        }
        let lastTroopTime =
            deployments.map(\.deploymentTime).max() ?? 0
        let firstSpellTime = max(
            1.5,
            lastTroopTime * 0.65 + 1.5
        )
        let freezePlanner = FreezePlacementPlanner(
            navigationGrid: navigationGrid,
            gameData: gameData
        )
        let lightningPlanner = LightningPlacementPlanner(
            navigationGrid: navigationGrid,
            gameData: gameData
        )
        let earthquakePlanner = EarthquakePlacementPlanner(
            navigationGrid: navigationGrid,
            gameData: gameData
        )
        var previousFreezePositions: [WorldPosition] = []
        var previousLightningPositions: [WorldPosition] = []
        var previousEarthquakePositions: [WorldPosition] = []
        let spellDeployments = spellKinds.indices.map { index in
            let kind = spellKinds[index]
            let supportsFirstLane = index.isMultiple(of: 2)
            let fallbackRow = supportsFirstLane
                ? formation.firstRow
                : formation.secondRow
            let row = formation.usesEntryAdvice
                ? entryAdvice?.preferredRecommendation?.laneRow ?? fallbackRow
                : fallbackRow
            let fallback = navigationGrid.worldPosition(
                for: GridCoordinate(
                    column: min(navigationGrid.columns - 1, spellColumn(for: kind)),
                    row: clampedRow(row)
                )
            )
            let position: WorldPosition
            if kind == .freeze {
                position = freezePlanner.position(
                    entities: baseEntities,
                    troopKinds: troopKinds,
                    laneRow: clampedRow(row),
                    previousPositions: previousFreezePositions
                ) ?? fallback
                previousFreezePositions.append(position)
            } else if kind == .lightning {
                position = lightningPlanner.position(
                    entities: baseEntities,
                    previousPositions: previousLightningPositions
                ) ?? fallback
                previousLightningPositions.append(position)
            } else if kind == .earthquake {
                position = earthquakePlanner.position(
                    entities: baseEntities,
                    previousPositions: previousEarthquakePositions
                ) ?? fallback
                previousEarthquakePositions.append(position)
            } else {
                position = fallback
            }

            return SpellDeploymentOrder(
                id: spellIDs[index],
                kind: kind,
                position: position,
                deploymentTime: min(
                    59,
                    firstSpellTime + Double(index) * 2.2
                )
            )
        }

        return AttackPlan(
            name: "\(formation.name) · \(tempo.name) · \(breachStyle.name)",
            deployments: deployments,
            spellDeployments: spellDeployments
        )
    }

    private func spellColumn(for kind: BattleSpellKind) -> Int {
        navigationGrid.scaledColumn(fromPrototype: prototypeSpellColumn(for: kind))
    }

    private func prototypeSpellColumn(for kind: BattleSpellKind) -> Int {
        switch kind {
        case .heal:
            return 13
        case .rage:
            return 18
        case .freeze:
            return 16
        case .lightning:
            return 17
        case .earthquake:
            return 14
        }
    }

    private func deploymentRow(
        for kind: BattleEntityKind,
        baseRow: Int,
        wave: Int,
        breachStyle: BreachStyle
    ) -> Int {
        let direction = wave.isMultiple(of: 2) ? -1 : 1
        let offset: Int

        switch kind {
        case .wallBreaker:
            offset = direction * breachStyle.wallBreakerOffset
        case .giant:
            offset = 0
        case .barbarian:
            offset = direction
        case .archer:
            offset = -direction
        case .wizard:
            offset = -direction * 2
        case .balloon:
            offset = direction * 2
        case .dragon:
            offset = -direction * 3
        case .barbarianKing:
            offset = 0
        case .archerQueen:
            offset = -direction
        case .wallWrecker:
            offset = 0
        case .stoneSlammer:
            offset = direction * 2
        case .cannon, .archerTower, .mortar, .wizardTower, .infernoTower, .bombTower, .hiddenTesla, .giantBomb, .airBomb, .airSweeper, .airDefense,
             .townHall, .goldStorage, .wall:
            offset = 0
        }

        return clampedRow(baseRow + offset)
    }

    private func deploymentColumn(
        for kind: BattleEntityKind
    ) -> Int {
        switch kind {
        case .giant, .wallBreaker:
            return 2
        case .barbarian, .archer, .wizard:
            return 1
        case .balloon, .dragon:
            return 0
        case .barbarianKing:
            return 2
        case .archerQueen:
            return 1
        case .wallWrecker:
            return 2
        case .stoneSlammer:
            return 0
        case .cannon, .archerTower, .mortar, .wizardTower, .infernoTower, .bombTower, .hiddenTesla, .giantBomb, .airBomb, .airSweeper, .airDefense,
             .townHall, .goldStorage, .wall:
            return 1
        }
    }

    private func clampedRow(_ row: Int) -> Int {
        min(max(row, 0), navigationGrid.rows - 1)
    }
}


/// Prototype spatial heuristic, not a prediction of combat or the game's AI.
/// Scores every grid cell by covered DPS relevant to the selected army.
/// A lane-distance penalty favors useful nearby clusters; subsequent casts
/// discount already covered defenses without forbidding a repeated freeze.
nonisolated struct FreezePlacementPlanner {
    let navigationGrid: NavigationGrid
    let gameData: any GameDataProviding

    func position(
        entities: [BattleEntity],
        troopKinds: [BattleEntityKind],
        laneRow: Int,
        previousPositions: [WorldPosition] = []
    ) -> WorldPosition? {
        guard !troopKinds.isEmpty else { return nil }
        let defenses = entities.filter {
            gameData.definition(for: $0.kind).role == .defense
        }.sorted { $0.id.uuidString < $1.id.uuidString }
        let radius = gameData.spellDefinition(for: .freeze).radius
        let laneY = navigationGrid.worldPosition(
            for: GridCoordinate(column: 0, row: laneRow)
        ).y
        let weightedDefenses = defenses.map { defense in
            let data = gameData.definition(for: defense.kind)
            let threatenedCount = troopKinds.filter {
                data.attackTargetLayer.accepts(
                    gameData.definition(for: $0).movementDomain
                )
            }.count
            let relevance = Double(threatenedCount) / Double(troopKinds.count)
            let wasCovered = previousPositions.contains {
                distance($0, defense.position) <= radius
            }
            let value = data.attackDamage / max(0.1, data.attackInterval) *
                relevance * (wasCovered ? 0.25 : 1)
            return (position: defense.position, value: value)
        }
        var best: WorldPosition?
        var bestScore = 0.0

        for row in 0..<navigationGrid.rows {
            for column in 0..<navigationGrid.columns {
                let center = navigationGrid.worldPosition(
                    for: GridCoordinate(column: column, row: row)
                )
                var coveredValue = 0.0
                for defense in weightedDefenses {
                    if distance(center, defense.position) <= radius {
                        coveredValue += defense.value
                    }
                }
                let lanePenalty = 1 + abs(center.y - laneY) /
                    max(navigationGrid.cellSize * 6, 1)
                let score = coveredValue / lanePenalty
                // Stable row/column traversal resolves ties, never random UUIDs.
                if score > bestScore {
                    bestScore = score
                    best = center
                }
            }
        }
        return best
    }

    private func distance(_ first: WorldPosition, _ second: WorldPosition) -> Double {
        hypot(first.x - second.x, first.y - second.y)
    }
}


/// Chooses the cell that maximizes immediate prototype damage value.
/// Defensive DPS is weighted above passive buildings and repeated casts spread out.
nonisolated struct LightningPlacementPlanner {
    let navigationGrid: NavigationGrid
    let gameData: any GameDataProviding

    func position(
        entities: [BattleEntity],
        previousPositions: [WorldPosition] = []
    ) -> WorldPosition? {
        let radius = gameData.spellDefinition(for: .lightning).radius
        let targets = entities.filter {
            let role = gameData.definition(for: $0.kind).role
            return $0.isAlive && (role == .defense || role == .building)
        }
        guard !targets.isEmpty else { return nil }

        var bestPosition: WorldPosition?
        var bestScore = -Double.infinity
        for row in 0..<navigationGrid.rows {
            for column in 0..<navigationGrid.columns {
                let center = navigationGrid.worldPosition(
                    for: GridCoordinate(column: column, row: row)
                )
                let score = targets.reduce(0.0) { partial, entity in
                    guard hypot(center.x - entity.position.x, center.y - entity.position.y) <= radius else {
                        return partial
                    }
                    let definition = gameData.definition(for: entity.kind)
                    let combatValue = definition.role == .defense
                        ? 2_000 + definition.attackDamage / max(0.1, definition.attackInterval)
                        : 250
                    let remainingValue = max(0.15, entity.hitPoints / definition.maxHitPoints)
                    return partial + combatValue * remainingValue
                }
                let repeatedPenalty = previousPositions.reduce(0.0) { partial, previous in
                    partial + (hypot(center.x - previous.x, center.y - previous.y) <= radius ? 10_000 : 0)
                }
                let adjustedScore = score - repeatedPenalty
                if adjustedScore > bestScore {
                    bestScore = adjustedScore
                    bestPosition = center
                }
            }
        }
        return bestPosition
    }
}


/// Scores wall clusters first, then nearby objectives, to create useful breaches.
nonisolated struct EarthquakePlacementPlanner {
    let navigationGrid: NavigationGrid
    let gameData: any GameDataProviding

    func position(
        entities: [BattleEntity],
        previousPositions: [WorldPosition] = []
    ) -> WorldPosition? {
        let radius = gameData.spellDefinition(for: .earthquake).radius
        let targets = entities.filter { entity in
            guard entity.isAlive else { return false }
            let role = gameData.definition(for: entity.kind).role
            return role == .wall || role == .defense || role == .building
        }
        guard !targets.isEmpty else { return nil }
        var best: WorldPosition?
        var bestScore = -Double.infinity
        for row in 0..<navigationGrid.rows {
            for column in 0..<navigationGrid.columns {
                let center = navigationGrid.worldPosition(
                    for: GridCoordinate(column: column, row: row)
                )
                var score = 0.0
                for entity in targets where hypot(
                    center.x - entity.position.x,
                    center.y - entity.position.y
                ) <= radius {
                    let role = gameData.definition(for: entity.kind).role
                    score += role == .wall ? 1_000 : (role == .defense ? 250 : 100)
                }
                if previousPositions.contains(where: {
                    hypot(center.x - $0.x, center.y - $0.y) <= radius
                }) {
                    score -= 5_000
                }
                if score > bestScore {
                    bestScore = score
                    best = center
                }
            }
        }
        return best
    }
}
