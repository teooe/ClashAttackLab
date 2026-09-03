import Foundation
import Testing
@testable import ClashAttackLabMac

struct ClashAttackLabMacTests {
    @Test
    func scoringAwardsStarsAndExcludesWalls() {
        let gameData = PrototypeGameData()
        let scoring = BaseScoringSystem()
        let position = WorldPosition(x: 0, y: 0)

        var entities = [
            BattleEntity(
                kind: .townHall,
                position: position,
                hitPoints: 900
            ),
            BattleEntity(
                kind: .cannon,
                position: position,
                hitPoints: 500
            ),
            BattleEntity(
                kind: .goldStorage,
                position: position,
                hitPoints: 620
            ),
            BattleEntity(
                kind: .goldStorage,
                position: position,
                hitPoints: 620
            ),
            BattleEntity(
                kind: .wall,
                position: position,
                hitPoints: 0
            )
        ]

        var score = scoring.calculate(
            entities: entities,
            gameData: gameData
        )
        #expect(score.totalBuildings == 4)
        #expect(score.stars == 0)
        #expect(score.destructionPercentage == 0)

        entities[1].hitPoints = 0
        entities[2].hitPoints = 0
        score = scoring.calculate(
            entities: entities,
            gameData: gameData
        )
        #expect(score.destructionPercentage == 50)
        #expect(score.stars == 1)

        entities[0].hitPoints = 0
        score = scoring.calculate(
            entities: entities,
            gameData: gameData
        )
        #expect(score.destructionPercentage == 75)
        #expect(score.townHallDestroyed)
        #expect(score.stars == 2)

        entities[3].hitPoints = 0
        score = scoring.calculate(
            entities: entities,
            gameData: gameData
        )
        #expect(score.destructionPercentage == 100)
        #expect(score.stars == 3)
    }

    @Test
    func weightedPathfindingCanBreakOrAvoidAWall() throws {
        let grid = NavigationGrid(
            columns: 5,
            rows: 5,
            cellSize: 1,
            origin: WorldPosition(x: 0, y: 0),
            blockedCells: []
        )
        let pathfinder = AStarPathfinder()
        let start = grid.worldPosition(
            for: GridCoordinate(column: 0, row: 2)
        )
        let goal = grid.worldPosition(
            for: GridCoordinate(column: 4, row: 2)
        )
        let wall = GridCoordinate(column: 2, row: 2)

        let breakingRoute = try #require(
            pathfinder.findPath(
                from: start,
                to: goal,
                in: grid,
                breakableCells: [wall],
                breakableTraversalCost: 0
            )
        )
        let breakingCoordinates = breakingRoute.waypoints.compactMap {
            grid.coordinate(for: $0)
        }
        #expect(breakingCoordinates.contains(wall))

        let detourRoute = try #require(
            pathfinder.findPath(
                from: start,
                to: goal,
                in: grid,
                breakableCells: [wall],
                breakableTraversalCost: 100
            )
        )
        let detourCoordinates = detourRoute.waypoints.compactMap {
            grid.coordinate(for: $0)
        }
        #expect(!detourCoordinates.contains(wall))
        #expect(detourRoute.totalCost < breakingRoute.totalCost + 100)
    }

    @Test
    func attackPlanOrdersDeploymentsByTime() {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let lateID = UUID()
        let earlyID = UUID()
        let middleID = UUID()

        let plan = AttackPlan(
            name: "Ordine di prova",
            deployments: [
                DeploymentOrder(
                    entityID: lateID,
                    kind: .giant,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 2, row: 4)
                    ),
                    deploymentTime: 4
                ),
                DeploymentOrder(
                    entityID: earlyID,
                    kind: .giant,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 2, row: 7)
                    ),
                    deploymentTime: 0
                ),
                DeploymentOrder(
                    entityID: middleID,
                    kind: .giant,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 2, row: 11)
                    ),
                    deploymentTime: 2
                )
            ]
        )

        #expect(
            plan.orderedDeployments.map(\.entityID) ==
                [earlyID, middleID, lateID]
        )
    }

    @Test
    func attackPlanOrdersSpellDeploymentsByTime() {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let lateID = UUID()
        let earlyID = UUID()
        let plan = AttackPlan(
            name: "Spell order",
            deployments: [],
            spellDeployments: [
                SpellDeploymentOrder(
                    id: lateID,
                    kind: .rage,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 10, row: 8)
                    ),
                    deploymentTime: 4
                ),
                SpellDeploymentOrder(
                    id: earlyID,
                    kind: .heal,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 8, row: 8)
                    ),
                    deploymentTime: 1
                )
            ]
        )

        #expect(
            plan.orderedSpellDeployments.map(\.id) ==
                [earlyID, lateID]
        )
    }

    @Test
    func simulationDeploysMixedTroopsAtScheduledTimes() {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let plan = PrototypeBattleMap.makeAttackPlan(
            navigationGrid: grid
        )
        let engine = makeDeploymentTestEngine(
            grid: grid,
            plan: plan
        )

        #expect(
            engine.pendingDeploymentCount ==
                plan.totalDeploymentCount
        )
        #expect(engine.deployedTroopCount == 0)
        #expect(engine.entities.count == 1)

        engine.start()
        engine.advance(by: 1.0 / 60.0)

        #expect(
            engine.pendingDeploymentCount ==
                plan.totalDeploymentCount - 1
        )
        #expect(engine.deployedTroopCount == 1)
        #expect(
            engine.entities.contains {
                $0.id == plan.orderedDeployments[0].entityID
            }
        )

        advance(engine, ticks: 75)

        #expect(engine.deployedTroopCount == 5)
        #expect(
            Set(
                engine.entities
                    .filter {
                        $0.kind == .giant ||
                            $0.kind == .barbarian ||
                            $0.kind == .archer ||
                            $0.kind == .wallBreaker ||
                            $0.kind == .wizard
                    }
                    .map(\.kind)
            ) == Set([
                .giant,
                .barbarian,
                .archer,
                .wallBreaker,
                .wizard
            ])
        )

        advance(engine, ticks: 330)

        #expect(engine.pendingDeploymentCount == 0)
        #expect(
            engine.deployedTroopCount ==
                plan.totalDeploymentCount
        )

        let deployedIDs = Set(engine.entities.map(\.id))
        let plannedIDs = Set(plan.deployments.map(\.entityID))
        #expect(plannedIDs.isSubset(of: deployedIDs))
    }

    @Test
    func scheduledSpellActivatesAndExpires() {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let start = grid.worldPosition(
            for: GridCoordinate(column: 2, row: 8)
        )
        let plan = AttackPlan(
            name: "Spell lifecycle",
            deployments: [
                DeploymentOrder(
                    kind: .barbarian,
                    position: start,
                    deploymentTime: 0
                )
            ],
            spellDeployments: [
                SpellDeploymentOrder(
                    kind: .heal,
                    position: start,
                    deploymentTime: 0.5
                )
            ]
        )
        let engine = makeDeploymentTestEngine(
            grid: grid,
            plan: plan
        )

        engine.start()
        advance(engine, ticks: 20)

        #expect(engine.pendingSpellCount == 1)
        #expect(engine.activeSpells.isEmpty)

        advance(engine, ticks: 20)

        #expect(engine.pendingSpellCount == 0)
        #expect(engine.deployedSpellCount == 1)
        #expect(engine.activeSpells.count == 1)

        advance(engine, ticks: 380)

        #expect(engine.activeSpells.isEmpty)
    }

    @Test
    func healSpellRestoresHitPointsInsideItsZone() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let troopPosition = grid.worldPosition(
            for: GridCoordinate(column: 5, row: 8)
        )
        let cannon = BattleEntity(
            kind: .cannon,
            position: grid.worldPosition(
                for: GridCoordinate(column: 7, row: 8)
            )
        )
        let townHall = BattleEntity(
            kind: .townHall,
            position: grid.worldPosition(
                for: GridCoordinate(column: 20, row: 8)
            )
        )
        let deployment = DeploymentOrder(
            kind: .giant,
            position: troopPosition,
            deploymentTime: 0
        )
        let planWithoutHeal = AttackPlan(
            name: "No heal",
            deployments: [deployment]
        )
        let planWithHeal = AttackPlan(
            name: "Heal",
            deployments: [deployment],
            spellDeployments: [
                SpellDeploymentOrder(
                    kind: .heal,
                    position: troopPosition,
                    deploymentTime: 0
                )
            ]
        )
        let normalEngine = SimulationEngine(
            entities: [cannon, townHall],
            attackPlan: planWithoutHeal,
            gameData: PrototypeGameData(),
            navigationGrid: grid
        )
        let healedEngine = SimulationEngine(
            entities: [cannon, townHall],
            attackPlan: planWithHeal,
            gameData: PrototypeGameData(),
            navigationGrid: grid
        )

        normalEngine.start()
        healedEngine.start()
        advance(normalEngine, ticks: 120)
        advance(healedEngine, ticks: 120)

        let normalGiant = try #require(
            normalEngine.entities.first { $0.kind == .giant }
        )
        let healedGiant = try #require(
            healedEngine.entities.first { $0.kind == .giant }
        )

        #expect(healedGiant.hitPoints > normalGiant.hitPoints)
    }

    @Test
    func rageSpellIncreasesMovementInsideItsZone() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let start = grid.worldPosition(
            for: GridCoordinate(column: 2, row: 8)
        )
        let townHall = BattleEntity(
            kind: .townHall,
            position: grid.worldPosition(
                for: GridCoordinate(column: 22, row: 8)
            )
        )
        let deployment = DeploymentOrder(
            kind: .barbarian,
            position: start,
            deploymentTime: 0
        )
        let normalPlan = AttackPlan(
            name: "Normal",
            deployments: [deployment]
        )
        let ragePlan = AttackPlan(
            name: "Rage",
            deployments: [deployment],
            spellDeployments: [
                SpellDeploymentOrder(
                    kind: .rage,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 5, row: 8)
                    ),
                    deploymentTime: 0
                )
            ]
        )
        let normalEngine = SimulationEngine(
            entities: [townHall],
            attackPlan: normalPlan,
            gameData: PrototypeGameData(),
            navigationGrid: grid
        )
        let ragedEngine = SimulationEngine(
            entities: [townHall],
            attackPlan: ragePlan,
            gameData: PrototypeGameData(),
            navigationGrid: grid
        )

        normalEngine.start()
        ragedEngine.start()
        advance(normalEngine, ticks: 60)
        advance(ragedEngine, ticks: 60)

        let normalBarbarian = try #require(
            normalEngine.entities.first { $0.kind == .barbarian }
        )
        let ragedBarbarian = try #require(
            ragedEngine.entities.first { $0.kind == .barbarian }
        )

        #expect(ragedBarbarian.position.x > normalBarbarian.position.x)
    }

    @Test
    func rageSpellIncreasesDamageAndAttackFrequency() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let start = grid.worldPosition(
            for: GridCoordinate(column: 5, row: 8)
        )
        let townHall = BattleEntity(
            kind: .townHall,
            position: grid.worldPosition(
                for: GridCoordinate(column: 6, row: 8)
            )
        )
        let deployment = DeploymentOrder(
            kind: .barbarian,
            position: start,
            deploymentTime: 0
        )
        let normalEngine = SimulationEngine(
            entities: [townHall],
            attackPlan: AttackPlan(
                name: "Normal damage",
                deployments: [deployment]
            ),
            gameData: PrototypeGameData(),
            navigationGrid: grid
        )
        let ragedEngine = SimulationEngine(
            entities: [townHall],
            attackPlan: AttackPlan(
                name: "Raged damage",
                deployments: [deployment],
                spellDeployments: [
                    SpellDeploymentOrder(
                        kind: .rage,
                        position: start,
                        deploymentTime: 0
                    )
                ]
            ),
            gameData: PrototypeGameData(),
            navigationGrid: grid
        )

        normalEngine.start()
        ragedEngine.start()
        advance(normalEngine, ticks: 60)
        advance(ragedEngine, ticks: 60)

        let normalTownHall = try #require(
            normalEngine.entities.first { $0.kind == .townHall }
        )
        let ragedTownHall = try #require(
            ragedEngine.entities.first { $0.kind == .townHall }
        )

        #expect(ragedTownHall.hitPoints < normalTownHall.hitPoints)
    }

    @Test
    func pauseStopsTimeAndResetRestoresThePlan() {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let plan = PrototypeBattleMap.makeAttackPlan(
            navigationGrid: grid
        )
        let engine = makeDeploymentTestEngine(
            grid: grid,
            plan: plan
        )

        engine.start()
        engine.advance(by: 1.0 / 60.0)
        let timeAtPause = engine.elapsedTime

        engine.togglePause()
        advance(engine, ticks: 120)

        #expect(engine.elapsedTime == timeAtPause)
        #expect(engine.deployedTroopCount == 1)

        engine.togglePause()
        engine.advance(by: 1.0 / 60.0)

        #expect(engine.elapsedTime > timeAtPause)

        engine.reset()

        if case .ready = engine.status {
            // Stato atteso.
        } else {
            Issue.record("Il reset deve riportare la simulazione a ready.")
        }

        #expect(engine.elapsedTime == 0)
        #expect(
            engine.pendingDeploymentCount ==
                plan.totalDeploymentCount
        )
        #expect(engine.deployedTroopCount == 0)
        #expect(engine.pendingSpellCount == plan.totalSpellCount)
        #expect(engine.deployedSpellCount == 0)
        #expect(engine.activeSpells.isEmpty)
        #expect(engine.entities.count == 1)
    }

    @Test
    func targetingProfilesKeepEvidenceSeparateFromPrototypeStats() throws {
        let gameData = PrototypeGameData()

        let giantProfile = try #require(
            gameData.definition(for: .giant).targetingProfile
        )
        let barbarianProfile = try #require(
            gameData.definition(for: .barbarian).targetingProfile
        )
        let archerProfile = try #require(
            gameData.definition(for: .archer).targetingProfile
        )
        let wallBreakerProfile = try #require(
            gameData.definition(for: .wallBreaker).targetingProfile
        )
        let wizardProfile = try #require(
            gameData.definition(for: .wizard).targetingProfile
        )

        #expect(giantProfile.preference == .defenses)
        #expect(barbarianProfile.preference == .anyBuilding)
        #expect(archerProfile.preference == .anyBuilding)
        #expect(wallBreakerProfile.preference == .walls)
        #expect(wizardProfile.preference == .anyBuilding)
        #expect(giantProfile.evidence == .documented)
        #expect(barbarianProfile.evidence == .documented)
        #expect(archerProfile.evidence == .documented)
        #expect(wallBreakerProfile.evidence == .documented)
        #expect(wizardProfile.evidence == .approximation)
    }

    @Test
    func wallBreakerPrioritizesWallOverCloserDefense() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let start = grid.worldPosition(
            for: GridCoordinate(column: 2, row: 8)
        )
        let cannon = BattleEntity(
            kind: .cannon,
            position: grid.worldPosition(
                for: GridCoordinate(column: 4, row: 8)
            )
        )
        let wall = BattleEntity(
            kind: .wall,
            position: grid.worldPosition(
                for: GridCoordinate(column: 8, row: 8)
            )
        )
        let engine = makeSingleTroopEngine(
            troopKind: .wallBreaker,
            troopPosition: start,
            objectives: [cannon, wall],
            grid: grid
        )

        engine.start()
        engine.advance(by: 1.0 / 60.0)

        let wallBreaker = try #require(
            engine.entities.first { $0.kind == .wallBreaker }
        )
        #expect(wallBreaker.currentTargetID == wall.id)
    }

    @Test
    func wallBreakerExplosionDestroysNearbyWallsAndItself() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let start = grid.worldPosition(
            for: GridCoordinate(column: 5, row: 8)
        )
        let wallCoordinates = [
            GridCoordinate(column: 6, row: 7),
            GridCoordinate(column: 6, row: 8),
            GridCoordinate(column: 6, row: 9)
        ]
        let walls = wallCoordinates.map {
            BattleEntity(
                kind: .wall,
                position: grid.worldPosition(for: $0)
            )
        }
        let townHall = BattleEntity(
            kind: .townHall,
            position: grid.worldPosition(
                for: GridCoordinate(column: 12, row: 8)
            )
        )
        let engine = makeSingleTroopEngine(
            troopKind: .wallBreaker,
            troopPosition: start,
            objectives: walls + [townHall],
            grid: grid
        )

        engine.start()
        engine.advance(by: 1.0 / 60.0)

        let remainingWalls = engine.entities.filter {
            $0.kind == .wall && $0.isAlive
        }
        let wallBreaker = try #require(
            engine.entities.first { $0.kind == .wallBreaker }
        )

        #expect(remainingWalls.isEmpty)
        #expect(!wallBreaker.isAlive)
        #expect(engine.livingTroopCount == 0)
    }

    @Test
    func wallBreakerFallsBackToBuildingWhenNoWallsRemain() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let start = grid.worldPosition(
            for: GridCoordinate(column: 5, row: 8)
        )
        let townHall = BattleEntity(
            kind: .townHall,
            position: grid.worldPosition(
                for: GridCoordinate(column: 6, row: 8)
            )
        )
        let engine = makeSingleTroopEngine(
            troopKind: .wallBreaker,
            troopPosition: start,
            objectives: [townHall],
            grid: grid
        )

        engine.start()
        engine.advance(by: 1.0 / 60.0)

        let damagedTownHall = try #require(
            engine.entities.first { $0.id == townHall.id }
        )
        let wallBreaker = try #require(
            engine.entities.first { $0.kind == .wallBreaker }
        )
        let maximumHitPoints = PrototypeGameData()
            .definition(for: .townHall)
            .maxHitPoints

        #expect(damagedTownHall.hitPoints < maximumHitPoints)
        #expect(!wallBreaker.isAlive)
        #expect(engine.livingTroopCount == 0)

        guard case .finished(let result) = engine.status else {
            Issue.record("La battaglia deve terminare senza truppe vive.")
            return
        }

        #expect(result.finishReason == .armyEliminated)
        #expect(result.metrics.troopsLost == 1)
        #expect(result.metrics.damageToBase > 0)
        #expect(result.metrics.spellsCast == 0)
    }

    @Test
    func giantPrioritizesDefenseOverCloserStorage() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let start = grid.worldPosition(
            for: GridCoordinate(column: 2, row: 5)
        )
        let storage = BattleEntity(
            kind: .goldStorage,
            position: grid.worldPosition(
                for: GridCoordinate(column: 4, row: 5)
            )
        )
        let cannon = BattleEntity(
            kind: .cannon,
            position: grid.worldPosition(
                for: GridCoordinate(column: 9, row: 5)
            )
        )
        let engine = makeSingleTroopEngine(
            troopKind: .giant,
            troopPosition: start,
            objectives: [storage, cannon],
            grid: grid
        )

        engine.start()
        engine.advance(by: 1.0 / 60.0)

        let giant = try #require(
            engine.entities.first { $0.kind == .giant }
        )
        #expect(giant.currentTargetID == cannon.id)
    }

    @Test
    func barbarianChoosesCloserBuildingWithoutDefensePreference() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let start = grid.worldPosition(
            for: GridCoordinate(column: 2, row: 5)
        )
        let storage = BattleEntity(
            kind: .goldStorage,
            position: grid.worldPosition(
                for: GridCoordinate(column: 4, row: 5)
            )
        )
        let cannon = BattleEntity(
            kind: .cannon,
            position: grid.worldPosition(
                for: GridCoordinate(column: 9, row: 5)
            )
        )
        let engine = makeSingleTroopEngine(
            troopKind: .barbarian,
            troopPosition: start,
            objectives: [storage, cannon],
            grid: grid
        )

        engine.start()
        engine.advance(by: 1.0 / 60.0)

        let barbarian = try #require(
            engine.entities.first { $0.kind == .barbarian }
        )
        #expect(barbarian.currentTargetID == storage.id)
    }

    @Test
    func archerLaunchesArrowFromRangeWithoutMoving() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let start = grid.worldPosition(
            for: GridCoordinate(column: 2, row: 5)
        )
        let storage = BattleEntity(
            kind: .goldStorage,
            position: grid.worldPosition(
                for: GridCoordinate(column: 6, row: 5)
            )
        )
        let engine = makeSingleTroopEngine(
            troopKind: .archer,
            troopPosition: start,
            objectives: [storage],
            grid: grid
        )

        engine.start()
        engine.advance(by: 1.0 / 60.0)

        let archer = try #require(
            engine.entities.first { $0.kind == .archer }
        )
        let storageBeforeImpact = try #require(
            engine.entities.first { $0.id == storage.id }
        )
        let arrow = try #require(engine.projectiles.first)

        #expect(archer.currentTargetID == storage.id)
        #expect(archer.position == start)
        #expect(arrow.kind == .arrow)
        #expect(arrow.targetEntityID == storage.id)
        #expect(
            storageBeforeImpact.hitPoints ==
                PrototypeGameData()
                    .definition(for: .goldStorage)
                    .maxHitPoints
        )

        advance(engine, ticks: 30)

        let storageAfterImpact = try #require(
            engine.entities.first { $0.id == storage.id }
        )
        #expect(
            storageAfterImpact.hitPoints <
                PrototypeGameData()
                    .definition(for: .goldStorage)
                    .maxHitPoints
        )
    }

    @Test
    func wizardFireballDamagesNearbyBuildings() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let start = grid.worldPosition(
            for: GridCoordinate(column: 2, row: 8)
        )
        let primaryStorage = BattleEntity(
            kind: .goldStorage,
            position: grid.worldPosition(
                for: GridCoordinate(column: 6, row: 8)
            )
        )
        let nearbyStorage = BattleEntity(
            kind: .goldStorage,
            position: grid.worldPosition(
                for: GridCoordinate(column: 6, row: 9)
            )
        )
        let engine = makeSingleTroopEngine(
            troopKind: .wizard,
            troopPosition: start,
            objectives: [primaryStorage, nearbyStorage],
            grid: grid
        )

        engine.start()
        engine.advance(by: 1.0 / 60.0)

        let fireball = try #require(engine.projectiles.first)
        #expect(fireball.kind == .fireball)

        advance(engine, ticks: 30)

        let damagedPrimary = try #require(
            engine.entities.first { $0.id == primaryStorage.id }
        )
        let damagedNearby = try #require(
            engine.entities.first { $0.id == nearbyStorage.id }
        )
        let maximum = PrototypeGameData()
            .definition(for: .goldStorage)
            .maxHitPoints

        #expect(damagedPrimary.hitPoints < maximum)
        #expect(damagedNearby.hitPoints < maximum)
    }

    @Test
    func archerTowerDelaysDamageUntilArrowImpact() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let tower = BattleEntity(
            kind: .archerTower,
            position: grid.worldPosition(
                for: GridCoordinate(column: 10, row: 8)
            )
        )
        let giantID = UUID()
        let plan = AttackPlan(
            name: "Test proiettile torre",
            deployments: [
                DeploymentOrder(
                    entityID: giantID,
                    kind: .giant,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 4, row: 8)
                    ),
                    deploymentTime: 0
                )
            ]
        )
        let engine = SimulationEngine(
            entities: [tower],
            attackPlan: plan,
            gameData: PrototypeGameData(),
            navigationGrid: grid
        )

        engine.start()
        engine.advance(by: 1.0 / 60.0)

        let giantBeforeImpact = try #require(
            engine.entities.first { $0.id == giantID }
        )
        let projectile = try #require(engine.projectiles.first)

        #expect(projectile.kind == .arrow)
        #expect(projectile.targetEntityID == giantID)
        #expect(
            giantBeforeImpact.hitPoints ==
                PrototypeGameData()
                    .definition(for: .giant)
                    .maxHitPoints
        )

        advance(engine, ticks: 30)

        let giantAfterImpact = try #require(
            engine.entities.first { $0.id == giantID }
        )
        #expect(
            giantAfterImpact.hitPoints <
                PrototypeGameData()
                    .definition(for: .giant)
                    .maxHitPoints
        )
    }

    @Test
    func mortarIgnoresTroopsInsideMinimumRange() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let mortar = BattleEntity(
            kind: .mortar,
            position: grid.worldPosition(
                for: GridCoordinate(column: 10, row: 8)
            )
        )
        let closeID = UUID()
        let distantID = UUID()
        let plan = AttackPlan(
            name: "Test raggio minimo",
            deployments: [
                DeploymentOrder(
                    entityID: closeID,
                    kind: .giant,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 12, row: 8)
                    ),
                    deploymentTime: 0
                ),
                DeploymentOrder(
                    entityID: distantID,
                    kind: .giant,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 17, row: 8)
                    ),
                    deploymentTime: 0
                )
            ]
        )
        let engine = SimulationEngine(
            entities: [mortar],
            attackPlan: plan,
            gameData: PrototypeGameData(),
            navigationGrid: grid
        )

        engine.start()
        engine.advance(by: 1.0 / 60.0)

        let shell = try #require(engine.projectiles.first)
        #expect(shell.kind == .mortarShell)
        #expect(shell.targetEntityID == distantID)
        #expect(shell.targetEntityID != closeID)
        #expect(shell.splashRadius > 0)
    }

    @Test
    func mortarSplashDamagesClusteredTroops() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let mortar = BattleEntity(
            kind: .mortar,
            position: grid.worldPosition(
                for: GridCoordinate(column: 10, row: 8)
            )
        )
        let firstID = UUID()
        let secondID = UUID()
        let plan = AttackPlan(
            name: "Test danno ad area",
            deployments: [
                DeploymentOrder(
                    entityID: firstID,
                    kind: .giant,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 17, row: 8)
                    ),
                    deploymentTime: 0
                ),
                DeploymentOrder(
                    entityID: secondID,
                    kind: .giant,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 17, row: 9)
                    ),
                    deploymentTime: 0
                )
            ]
        )
        let gameData = PrototypeGameData()
        let engine = SimulationEngine(
            entities: [mortar],
            attackPlan: plan,
            gameData: gameData,
            navigationGrid: grid
        )

        engine.start()
        engine.advance(by: 1.0 / 60.0)
        advance(engine, ticks: 60)

        let first = try #require(
            engine.entities.first { $0.id == firstID }
        )
        let second = try #require(
            engine.entities.first { $0.id == secondID }
        )
        let maximum = gameData.definition(for: .giant).maxHitPoints

        #expect(first.hitPoints < maximum)
        #expect(second.hitPoints < maximum)
    }

    @Test
    func generatorCreatesFairAndDistinctCandidatePlans() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let plans = PrototypeBattleMap.makeCandidateAttackPlans(
            navigationGrid: grid
        )
        let baseline = try #require(plans.first)
        let baselineKinds = baseline.orderedDeployments.map(\.kind)
        let baselineEntityIDs = baseline.orderedDeployments.map(\.entityID)
        let baselineSpellKinds =
            baseline.orderedSpellDeployments.map(\.kind)
        let baselineSpellIDs =
            baseline.orderedSpellDeployments.map(\.id)

        #expect(plans.count == 24)
        #expect(baseline.totalDeploymentCount == 12)
        #expect(baseline.totalSpellCount == 2)

        for plan in plans.dropFirst() {
            #expect(plan.orderedDeployments.map(\.kind) == baselineKinds)
            #expect(
                plan.orderedDeployments.map(\.entityID) ==
                    baselineEntityIDs
            )
            #expect(
                plan.orderedSpellDeployments.map(\.kind) ==
                    baselineSpellKinds
            )
            #expect(
                plan.orderedSpellDeployments.map(\.id) ==
                    baselineSpellIDs
            )
        }

        let distinctSchedules = Set(
            plans.map {
                $0.orderedDeployments
                    .map { String(format: "%.1f", $0.deploymentTime) }
                    .joined(separator: "|")
            }
        )
        let distinctCandidates = Set(
            plans.map { plan in
                let troops = plan.orderedDeployments.map {
                    "\($0.position.x),\($0.position.y),\($0.deploymentTime)"
                }
                let spells = plan.orderedSpellDeployments.map {
                    "\($0.position.x),\($0.position.y),\($0.deploymentTime)"
                }
                return (troops + spells).joined(separator: "|")
            }
        )

        #expect(distinctSchedules.count == 3)
        #expect(distinctCandidates.count == plans.count)
    }

    @Test
    func armyConfigurationEnforcesPrototypeCapacity() {
        let defaultArmy = ArmyConfiguration.prototypeDefault
        let oversizedArmy = ArmyConfiguration(
            giants: 7,
            barbarians: 3,
            archers: 3,
            wallBreakers: 2,
            wizards: 2,
            healSpells: 1,
            rageSpells: 1
        )
        let emptyArmy = ArmyConfiguration(
            giants: 0,
            barbarians: 0,
            archers: 0,
            wallBreakers: 0,
            wizards: 0,
            healSpells: 0,
            rageSpells: 0
        )

        #expect(defaultArmy.isValid)
        #expect(defaultArmy.troopCapacityUsed == 30)
        #expect(!oversizedArmy.isValid)
        #expect(!emptyArmy.isValid)
        #expect(
            emptyArmy.validationMessage ==
                "Aggiungi almeno una truppa."
        )
    }

    @Test
    func generatorUsesTheChosenArmyComposition() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let customArmy = ArmyConfiguration(
            giants: 1,
            barbarians: 0,
            archers: 0,
            wallBreakers: 0,
            wizards: 2,
            healSpells: 0,
            rageSpells: 1
        )
        let plans = PrototypeBattleMap.makeCandidateAttackPlans(
            navigationGrid: grid,
            armyConfiguration: customArmy
        )
        let baseline = try #require(plans.first)

        #expect(customArmy.isValid)
        #expect(plans.count == 24)
        #expect(
            baseline.orderedDeployments.map(\.kind) ==
                customArmy.deploymentSequence
        )
        #expect(
            baseline.orderedSpellDeployments.map(\.kind) ==
                customArmy.spellSequence
        )
        #expect(baseline.totalDeploymentCount == 3)
        #expect(baseline.totalSpellCount == 1)

        for plan in plans.dropFirst() {
            #expect(
                plan.orderedDeployments.map(\.kind) ==
                    customArmy.deploymentSequence
            )
            #expect(
                plan.orderedSpellDeployments.map(\.kind) ==
                    customArmy.spellSequence
            )
        }
    }

    @Test
    func headlessEvaluatorReturnsRankedResults() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let plans = Array(
            PrototypeBattleMap.makeCandidateAttackPlans(
                navigationGrid: grid
            )
            .prefix(2)
        )
        let evaluator = AttackPlanEvaluator(
            baseEntities: PrototypeBattleMap.makeBaseEntities(
                navigationGrid: grid
            ),
            gameData: PrototypeGameData(),
            navigationGrid: grid
        )

        let results = evaluator.evaluate(plans)
        #expect(results.count == plans.count)

        let first = try #require(results.first)
        let second = try #require(results.dropFirst().first)

        #expect(
            first.stars > second.stars ||
            (
                first.stars == second.stars &&
                first.destructionPercentage >=
                    second.destructionPercentage
            )
        )
        #expect(results.allSatisfy { $0.result.elapsedTime <= 60 })
    }

    @Test
    func loadingAnotherPlanResetsSimulation() {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let plans = PrototypeBattleMap.makeCandidateAttackPlans(
            navigationGrid: grid
        )
        let engine = makeDeploymentTestEngine(
            grid: grid,
            plan: plans[0]
        )

        engine.start()
        engine.advance(by: 1)
        #expect(engine.deployedTroopCount > 0)
        #expect(engine.elapsedTime > 0)

        engine.loadAttackPlan(plans[1])

        if case .ready = engine.status {
            // Stato atteso.
        } else {
            Issue.record("Il nuovo piano deve essere caricato in stato ready.")
        }

        #expect(engine.elapsedTime == 0)
        #expect(engine.deployedTroopCount == 0)
        #expect(engine.deployedSpellCount == 0)
        #expect(
            engine.pendingDeploymentCount ==
                plans[1].totalDeploymentCount
        )
        #expect(
            engine.pendingSpellCount ==
                plans[1].totalSpellCount
        )
        #expect(engine.activeSpells.isEmpty)
        #expect(engine.entities.count == 1)
    }

    @Test
    func curatedBaseLayoutsKeepComparableObjectiveInventory() {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let layouts = PrototypeBaseLayout.allCases
        var wallSignatures: Set<String> = []

        for layout in layouts {
            let entities = PrototypeBattleMap.makeBaseEntities(
                navigationGrid: grid,
                layout: layout
            )

            #expect(
                entities.filter { $0.kind == .cannon }.count == 2
            )
            #expect(
                entities.filter { $0.kind == .archerTower }.count == 2
            )
            #expect(
                entities.filter { $0.kind == .mortar }.count == 1
            )
            #expect(
                entities.filter { $0.kind == .airDefense }.count == 2
            )
            #expect(
                entities.filter { $0.kind == .townHall }.count == 1
            )
            #expect(
                entities.filter { $0.kind == .goldStorage }.count == 2
            )

            let signature = PrototypeBattleMap.wallCoordinates(
                for: layout
            )
            .map { coordinate in
                "\(coordinate.column),\(coordinate.row)"
            }
            .sorted()
            .joined(separator: "|")
            wallSignatures.insert(signature)
        }

        #expect(wallSignatures.count == layouts.count)
    }

    @Test
    func loadingAnotherBaseResetsBattleToTheNewScenario() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let plan = try #require(
            PrototypeBattleMap.makeCandidateAttackPlans(
                navigationGrid: grid
            ).first
        )
        let fortress = PrototypeBattleMap.makeBaseEntities(
            navigationGrid: grid,
            layout: .fortress
        )
        let corridor = PrototypeBattleMap.makeBaseEntities(
            navigationGrid: grid,
            layout: .corridor
        )
        let engine = SimulationEngine(
            entities: fortress,
            attackPlan: plan,
            gameData: PrototypeGameData(),
            navigationGrid: grid
        )

        engine.start()
        engine.advance(by: 1)

        #expect(engine.deployedTroopCount > 0)
        #expect(engine.elapsedTime > 0)

        engine.loadScenario(
            entities: corridor,
            attackPlan: plan
        )

        guard case .ready = engine.status else {
            Issue.record("Il caricamento della base deve tornare ready.")
            return
        }

        #expect(engine.elapsedTime == 0)
        #expect(engine.deployedTroopCount == 0)
        #expect(engine.pendingDeploymentCount == plan.totalDeploymentCount)
        #expect(engine.entities.count == corridor.count)
        #expect(
            engine.entities.filter { $0.kind == .wall }.count ==
                PrototypeBattleMap.wallCoordinates(for: .corridor).count
        )
    }

    @Test
    func balloonFliesAcrossAnIntactWall() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let balloonID = UUID()
        let wall = BattleEntity(
            kind: .wall,
            position: grid.worldPosition(
                for: GridCoordinate(column: 6, row: 8)
            )
        )
        let cannon = BattleEntity(
            kind: .cannon,
            position: grid.worldPosition(
                for: GridCoordinate(column: 10, row: 8)
            )
        )
        let plan = AttackPlan(
            name: "Volo diretto",
            deployments: [
                DeploymentOrder(
                    entityID: balloonID,
                    kind: .balloon,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 2, row: 8)
                    ),
                    deploymentTime: 0
                )
            ]
        )
        let engine = SimulationEngine(
            entities: [wall, cannon],
            attackPlan: plan,
            gameData: PrototypeGameData(),
            navigationGrid: grid
        )

        engine.start()
        advance(engine, ticks: 120)

        let balloon = try #require(
            engine.entities.first { $0.id == balloonID }
        )
        let remainingWall = try #require(
            engine.entities.first { $0.id == wall.id }
        )

        #expect(balloon.currentTargetID == cannon.id)
        #expect(balloon.position.x > wall.position.x)
        #expect(remainingWall.isAlive)
        #expect(balloon.blockingWallID == nil)
    }

    @Test
    func airDefenseTargetsOnlyAirTroops() throws {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let giantID = UUID()
        let balloonID = UUID()
        let airDefense = BattleEntity(
            kind: .airDefense,
            position: grid.worldPosition(
                for: GridCoordinate(column: 10, row: 8)
            )
        )
        let plan = AttackPlan(
            name: "Bersaglio antiaereo",
            deployments: [
                DeploymentOrder(
                    entityID: giantID,
                    kind: .giant,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 5, row: 8)
                    ),
                    deploymentTime: 0
                ),
                DeploymentOrder(
                    entityID: balloonID,
                    kind: .balloon,
                    position: grid.worldPosition(
                        for: GridCoordinate(column: 6, row: 8)
                    ),
                    deploymentTime: 0
                )
            ]
        )
        let engine = SimulationEngine(
            entities: [airDefense],
            attackPlan: plan,
            gameData: PrototypeGameData(),
            navigationGrid: grid
        )

        engine.start()
        engine.advance(by: 1.0 / 60.0)

        let projectile = try #require(engine.projectiles.first)
        let giant = try #require(
            engine.entities.first { $0.id == giantID }
        )

        #expect(projectile.kind == .airBolt)
        #expect(projectile.targetEntityID == balloonID)
        #expect(
            giant.hitPoints ==
                PrototypeGameData()
                    .definition(for: .giant)
                    .maxHitPoints
        )
    }

    @Test
    func manualPlanBuildsAnIndependentOrderedAttack() {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        var draft = ManualAttackPlan(name: "Test manuale")
        let firstPosition = grid.worldPosition(
            for: GridCoordinate(column: 1, row: 4)
        )
        let secondPosition = grid.worldPosition(
            for: GridCoordinate(column: 2, row: 10)
        )

        draft.append(
            .troop(.giant),
            at: firstPosition,
            time: 1.2
        )
        draft.append(
            .spell(.rage),
            at: secondPosition,
            time: 0.6
        )
        draft.append(
            .troop(.archer),
            at: secondPosition,
            time: 0.8
        )

        let plan = draft.makeAttackPlan()

        #expect(plan.id == draft.id)
        #expect(draft.totalOrderCount == 3)
        #expect(draft.troopCount(for: .giant) == 1)
        #expect(draft.troopCount(for: .archer) == 1)
        #expect(draft.spellCount(for: .rage) == 1)
        #expect(plan.totalDeploymentCount == 2)
        #expect(plan.totalSpellCount == 1)
        #expect(plan.orderedDeployments.map(\.kind) == [
            .archer,
            .giant
        ])

        draft.removeMostRecentOrder()

        #expect(draft.totalOrderCount == 2)
        #expect(draft.troopCount(for: .giant) == 0)
        #expect(draft.troopCount(for: .archer) == 1)

        draft.removeAllOrders()

        #expect(draft.totalOrderCount == 0)
    }

    private func makeSingleTroopEngine(
        troopKind: BattleEntityKind,
        troopPosition: WorldPosition,
        objectives: [BattleEntity],
        grid: NavigationGrid
    ) -> SimulationEngine {
        let plan = AttackPlan(
            name: "Targeting test",
            deployments: [
                DeploymentOrder(
                    kind: troopKind,
                    position: troopPosition,
                    deploymentTime: 0
                )
            ]
        )

        return SimulationEngine(
            entities: objectives,
            attackPlan: plan,
            gameData: PrototypeGameData(),
            navigationGrid: grid
        )
    }

    private func makeDeploymentTestEngine(
        grid: NavigationGrid,
        plan: AttackPlan
    ) -> SimulationEngine {
        let townHall = BattleEntity(
            kind: .townHall,
            position: grid.worldPosition(
                for: GridCoordinate(column: 22, row: 8)
            )
        )

        return SimulationEngine(
            entities: [townHall],
            attackPlan: plan,
            gameData: PrototypeGameData(),
            navigationGrid: grid
        )
    }

    private func advance(
        _ engine: SimulationEngine,
        ticks: Int
    ) {
        for _ in 0..<ticks {
            engine.advance(by: 1.0 / 60.0)
        }
    }
}


@Test
func attackPlanRoundTripsThroughLocalStorageFormat() throws {
    let plan = AttackPlan(
        name: "Piano persistente",
        deployments: [
            DeploymentOrder(
                kind: .giant,
                position: WorldPosition(x: 12, y: 24),
                deploymentTime: 1.5
            )
        ],
        spellDeployments: [
            SpellDeploymentOrder(
                kind: .rage,
                position: WorldPosition(x: 36, y: 48),
                deploymentTime: 2.0
            )
        ]
    )

    let data = try JSONEncoder().encode(plan)
    let decoded = try JSONDecoder().decode(AttackPlan.self, from: data)

    #expect(decoded.name == plan.name)
    #expect(decoded.totalDeploymentCount == 1)
    #expect(decoded.totalSpellCount == 1)
    #expect(decoded.deployments.first?.kind == .giant)
    #expect(decoded.spellDeployments.first?.kind == .rage)
    #expect(decoded.deployments.first?.position == WorldPosition(x: 12, y: 24))
}


@Test
func manualPlanSupportsTargetedOrderEditing() {
    var draft = ManualAttackPlan()
    draft.append(
        .troop(.giant),
        at: WorldPosition(x: 10, y: 10),
        time: 2
    )
    let storedID = draft.orderedDeployments[0].id
    draft.updateOrderTime(id: storedID, to: 4.5)
    #expect(draft.orderedDeployments[0].deploymentTime == 4.5)
    draft.removeOrder(id: storedID)
    #expect(draft.totalOrderCount == 0)
}


@Test
func attackHistoryEntryCapturesCompletedBattleMetrics() {
    let plan = AttackPlan(name: "Storico", deployments: [])
    let score = BaseScoreSnapshot(
        destructionPercentage: 72.5,
        stars: 2,
        townHallDestroyed: true,
        destroyedBuildings: 8,
        totalBuildings: 11
    )
    let metrics = BattleSummaryMetrics(
        damageToBase: 1_250,
        hitPointsLostByArmy: 400,
        troopsLost: 3,
        destroyedWalls: 2,
        spellsCast: 1
    )
    let result = SimulationResult(
        winner: .attackers,
        elapsedTime: 42.5,
        timeExpired: false,
        finishReason: .armyEliminated,
        deployedTroops: 8,
        survivingTroops: 5,
        survivingDefenses: 1,
        troopAttackCount: 20,
        defenseAttackCount: 14,
        score: score,
        metrics: metrics
    )

    let entry = AttackHistoryEntry(
        plan: plan,
        result: result,
        completedAt: Date(timeIntervalSince1970: 0)
    )

    #expect(entry.planName == "Storico")
    #expect(entry.stars == 2)
    #expect(entry.destructionPercentage == 72.5)
    #expect(entry.survivingTroops == 5)
    #expect(entry.troopsLost == 3)
    #expect(entry.spellsCast == 1)
}


@Test
func robustnessAnalysisCalculatesAveragesAcrossBases() {
    let plan = AttackPlan(name: "Robustezza", deployments: [])

    func evaluation(
        stars: Int,
        destruction: Double,
        survivors: Int,
        duration: TimeInterval
    ) -> AttackPlanEvaluation {
        let score = BaseScoreSnapshot(
            destructionPercentage: destruction,
            stars: stars,
            townHallDestroyed: stars >= 2,
            destroyedBuildings: 0,
            totalBuildings: 0
        )
        let metrics = BattleSummaryMetrics(
            damageToBase: destruction,
            hitPointsLostByArmy: 0,
            troopsLost: 0,
            destroyedWalls: 0,
            spellsCast: 0
        )
        let result = SimulationResult(
            winner: .attackers,
            elapsedTime: duration,
            timeExpired: false,
            finishReason: .totalDestruction,
            deployedTroops: survivors,
            survivingTroops: survivors,
            survivingDefenses: 0,
            troopAttackCount: 0,
            defenseAttackCount: 0,
            score: score,
            metrics: metrics
        )
        return AttackPlanEvaluation(plan: plan, result: result)
    }

    let analysis = AttackPlanRobustnessAnalysis(
        plan: plan,
        entries: [
            BaseAttackEvaluation(
                layout: .fortress,
                evaluation: evaluation(
                    stars: 3,
                    destruction: 100,
                    survivors: 5,
                    duration: 20
                )
            ),
            BaseAttackEvaluation(
                layout: .corridor,
                evaluation: evaluation(
                    stars: 1,
                    destruction: 50,
                    survivors: 3,
                    duration: 40
                )
            )
        ]
    )

    #expect(analysis.averageStars == 2)
    #expect(analysis.averageDestruction == 75)
    #expect(analysis.averageSurvivors == 4)
    #expect(analysis.averageDuration == 30)
    #expect(analysis.threeStarCount == 1)
}


@Test
func robustnessRankerUsesPlanNameAsDeterministicFinalTieBreaker() {
    let alpha = AttackPlan(name: "Alpha", deployments: [])
    let beta = AttackPlan(name: "Beta", deployments: [])
    let ranked = AttackPlanRobustnessRanker.rank([
        AttackPlanRobustnessAnalysis(plan: beta, entries: []),
        AttackPlanRobustnessAnalysis(plan: alpha, entries: [])
    ])

    #expect(ranked.map(\.plan.name) == ["Alpha", "Beta"])
}


@Test
func planRefinerKeepsArmyAndClampsShiftedDeploymentRows() {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let topRowPosition = grid.worldPosition(
        for: GridCoordinate(column: 1, row: 0)
    )
    let plan = AttackPlan(
        name: "Da rifinire",
        deployments: [
            DeploymentOrder(
                kind: .giant,
                position: topRowPosition,
                deploymentTime: 4
            )
        ],
        spellDeployments: [
            SpellDeploymentOrder(
                kind: .rage,
                position: topRowPosition,
                deploymentTime: 5
            )
        ]
    )

    let variants = AttackPlanRefiner(
        navigationGrid: grid
    ).variants(for: plan)

    #expect(variants.count == 15)
    #expect(variants.contains { $0.id == plan.id })
    #expect(
        variants.allSatisfy {
            $0.totalDeploymentCount == plan.totalDeploymentCount &&
                $0.totalSpellCount == plan.totalSpellCount
        }
    )
    #expect(
        variants.allSatisfy { variant in
            variant.deployments.allSatisfy { order in
                guard let coordinate = grid.coordinate(for: order.position) else {
                    return false
                }

                return coordinate.row >= 0 && coordinate.row < grid.rows
            }
        }
    )
}


@Test
func automaticPlanGeneratorProducesTheExpectedStrategyMatrix() {
    let plans = AttackPlanGenerator(
        navigationGrid: PrototypeBattleMap.makeNavigationGrid(),
        armyConfiguration: .prototypeDefault
    ).generate()

    #expect(plans.count == 24)
    #expect(Set(plans.map(\.name)).count == plans.count)
}


@Test
func archivedBattleRetainsReplayDataAndSummaryChoosesBestResult() throws {
    let plan = AttackPlan(name: "Replay", deployments: [])
    let score = BaseScoreSnapshot(
        destructionPercentage: 80,
        stars: 2,
        townHallDestroyed: true,
        destroyedBuildings: 8,
        totalBuildings: 10
    )
    let metrics = BattleSummaryMetrics(
        damageToBase: 800,
        hitPointsLostByArmy: 100,
        troopsLost: 1,
        destroyedWalls: 1,
        spellsCast: 1
    )
    let result = SimulationResult(
        winner: .attackers,
        elapsedTime: 31,
        timeExpired: false,
        finishReason: .armyEliminated,
        deployedTroops: 4,
        survivingTroops: 3,
        survivingDefenses: 1,
        troopAttackCount: 12,
        defenseAttackCount: 8,
        score: score,
        metrics: metrics
    )

    let entry = AttackHistoryEntry(
        plan: plan,
        result: result,
        baseLayout: .corridor,
        completedAt: Date(timeIntervalSince1970: 0)
    )
    let decoded = try JSONDecoder().decode(
        AttackHistoryEntry.self,
        from: JSONEncoder().encode(entry)
    )
    let summary = AttackHistorySummary(entries: [decoded])

    #expect(decoded.attackPlan?.name == "Replay")
    #expect(decoded.baseLayout == .corridor)
    #expect(summary.replayableCount == 1)
    #expect(summary.bestEntry?.id == decoded.id)
}


@Test
func baseReconnaissanceProfilesReachableLanesAndProducesRecommendation() {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let data = PrototypeGameData()
    let report = BaseReconnaissanceSystem(
        navigationGrid: grid,
        gameData: data
    ).analyze(
        entities: PrototypeBattleMap.makeBaseEntities(
            navigationGrid: grid,
            layout: .fortress
        ),
        layout: .fortress
    )

    #expect(report.lanes.count == 5)
    #expect(report.recommendedLane != nil)
    #expect(report.lanes.allSatisfy { $0.pathCost > 0 })
    #expect(
        report.lanes.allSatisfy {
            !$0.firstTargetName.isEmpty && $0.pressureScore > 0
        }
    )
}


@Test
func baseSnapshotRoundTripsAndValidatesPortableCoordinates() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let original = BaseSnapshot.make(
        from: .corridor,
        navigationGrid: grid
    )

    #expect(original.isValid)
    #expect(original.wallCount > 0)
    #expect(original.objectiveCount > 0)

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(
        BaseSnapshot.self,
        from: data
    )
    let entities = decoded.makeEntities(navigationGrid: grid)

    #expect(decoded.name == original.name)
    #expect(decoded.objects.count == original.objects.count)
    #expect(entities.count == original.objects.count)
}


@Test
func baseSnapshotEditorPlacesReplacesAndRemovesObjects() {
    var snapshot = BaseSnapshot(
        name: "Editor",
        objects: [
            BaseObjectSnapshot(
                kind: .townHall,
                column: 20,
                row: 8
            )
        ]
    )

    snapshot.place(.wall, atColumn: 20, row: 8)
    #expect(snapshot.object(atColumn: 20, row: 8)?.kind == .wall)
    #expect(snapshot.objectiveCount == 0)

    snapshot.place(.cannon, atColumn: 10, row: 4)
    #expect(snapshot.objectiveCount == 1)
    snapshot.removeObject(atColumn: 10, row: 4)
    #expect(snapshot.objectiveCount == 0)
}


@Test
func baseLibraryPersistsLatestVersionOfASavedSnapshot() {
    let storageKey = "clashAttackLab.tests.baseLibrary.\(UUID().uuidString)"
    let library = BaseSnapshotLibrary(storageKey: storageKey)
    defer {
        library.clear()
    }

    let original = BaseSnapshot(
        name: "Prima",
        objects: [
            BaseObjectSnapshot(
                kind: .townHall,
                column: 20,
                row: 8
            )
        ]
    )
    let renamed = BaseSnapshot(
        id: original.id,
        name: "Aggiornata",
        objects: original.objects
    )

    library.save(original)
    library.save(renamed)

    #expect(library.bases.count == 1)
    #expect(library.bases.first?.name == "Aggiornata")
}


@Test
func savedBasePlanAnalysisCalculatesMetricsAcrossCustomBases() {
    let plan = AttackPlan(name: "Analisi locale", deployments: [])
    let score = BaseScoreSnapshot(
        destructionPercentage: 60,
        stars: 2,
        townHallDestroyed: true,
        destroyedBuildings: 6,
        totalBuildings: 10
    )
    let result = SimulationResult(
        winner: .attackers,
        elapsedTime: 20,
        timeExpired: false,
        finishReason: .armyEliminated,
        deployedTroops: 4,
        survivingTroops: 3,
        survivingDefenses: 1,
        troopAttackCount: 0,
        defenseAttackCount: 0,
        score: score,
        metrics: BattleSummaryMetrics(
            damageToBase: 600,
            hitPointsLostByArmy: 50,
            troopsLost: 1,
            destroyedWalls: 0,
            spellsCast: 0
        )
    )
    let evaluation = AttackPlanEvaluation(plan: plan, result: result)
    let base = BaseSnapshot(
        name: "Locale",
        objects: [
            BaseObjectSnapshot(
                kind: .townHall,
                column: 20,
                row: 8
            )
        ]
    )
    let analysis = SavedBasePlanAnalysis(
        plan: plan,
        entries: [
            CustomBaseAttackEvaluation(
                base: base,
                evaluation: evaluation
            )
        ]
    )

    #expect(analysis.averageStars == 2)
    #expect(analysis.averageDestruction == 60)
    #expect(analysis.averageSurvivors == 3)
    #expect(analysis.threeStarCount == 0)
}


@Test
func baseValidationRejectsMissingTownHallAndDefense() {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let snapshot = BaseSnapshot(
        name: "Incompleta",
        objects: [
            BaseObjectSnapshot(
                kind: .goldStorage,
                column: 10,
                row: 8
            )
        ]
    )

    let report = snapshot.validationReport(on: grid)

    #expect(!report.isBuildable)
    #expect(report.errors.count == 2)
}

@Test
func baseValidationWarnsWhenDeployStripIsOccupied() {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let snapshot = BaseSnapshot(
        name: "Avviso",
        objects: [
            BaseObjectSnapshot(
                kind: .townHall,
                column: 20,
                row: 8
            ),
            BaseObjectSnapshot(
                kind: .cannon,
                column: 1,
                row: 4
            )
        ]
    )

    let report = snapshot.validationReport(on: grid)

    #expect(report.isBuildable)
    #expect(!report.warnings.isEmpty)
}
