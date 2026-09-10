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

    init(
        navigationGrid: NavigationGrid,
        armyConfiguration: ArmyConfiguration = .prototypeDefault,
        entryAdvice: ArmyEntryAdvice? = nil,
        baseEntities: [BattleEntity] = [],
        gameData: any GameDataProviding = PrototypeGameData()
    ) {
        self.navigationGrid = navigationGrid
        self.armyConfiguration = armyConfiguration
        self.entryAdvice = entryAdvice
        self.baseEntities = baseEntities
        self.gameData = gameData
    }

    func generate() -> [AttackPlan] {
        precondition(
            armyConfiguration.isValid,
            armyConfiguration.validationMessage ??
                "Configurazione esercito non valida."
        )

        let troopKinds = armyConfiguration.deploymentSequence
        let spellKinds = armyConfiguration.spellSequence
        let entityIDs = troopKinds.map { _ in UUID() }
        let spellIDs = spellKinds.map { _ in UUID() }

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
                firstRow: 4,
                secondRow: 5,
                usesEntryAdvice: false
            ),
            Formation(
                name: "Centro",
                firstRow: 8,
                secondRow: 9,
                usesEntryAdvice: false
            ),
            Formation(
                name: "Bassa",
                firstRow: 12,
                secondRow: 11,
                usesEntryAdvice: false
            ),
            Formation(
                name: "Divisa",
                firstRow: 4,
                secondRow: 12,
                usesEntryAdvice: false
            )
        ]

        if entryAdvice?.preferredRecommendation != nil {
            result.append(
                Formation(
                    name: "Guidata",
                    firstRow: 8,
                    secondRow: 8,
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
                entityID: entityIDs[index],
                kind: kind,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(
                        column: deploymentColumn(for: kind),
                        row: row
                    )
                ),
                deploymentTime:
                    Double(wave) * tempo.waveGap +
                    Double(slot) * tempo.withinWaveDelay
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
        var previousFreezePositions: [WorldPosition] = []
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
            } else {
                position = fallback
            }

            return SpellDeploymentOrder(
                id: spellIDs[index],
                kind: kind,
                position: position,
                deploymentTime:
                    firstSpellTime + Double(index) * 2.2
            )
        }

        return AttackPlan(
            name: "\(formation.name) · \(tempo.name) · \(breachStyle.name)",
            deployments: deployments,
            spellDeployments: spellDeployments
        )
    }

    private func spellColumn(for kind: BattleSpellKind) -> Int {
        switch kind {
        case .heal:
            return 13
        case .rage:
            return 18
        case .freeze:
            return 16
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
        case .cannon, .archerTower, .mortar, .airDefense,
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
        case .cannon, .archerTower, .mortar, .airDefense,
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
