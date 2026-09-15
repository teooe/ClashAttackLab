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
        let baselineKinds = baseline.deployments.map(\.kind)
        let baselineEntityIDs = baseline.deployments.map(\.entityID)
        let baselineSpellKinds =
            baseline.spellDeployments.map(\.kind)
        let baselineSpellIDs =
            baseline.spellDeployments.map(\.id)

        #expect(plans.count == 24)
        #expect(baseline.totalDeploymentCount == 15)
        #expect(baseline.totalSpellCount == 3)

        for plan in plans.dropFirst() {
            #expect(plan.deployments.map(\.kind) == baselineKinds)
            #expect(
                plan.deployments.map(\.entityID) ==
                    baselineEntityIDs
            )
            #expect(
                plan.spellDeployments.map(\.kind) ==
                    baselineSpellKinds
            )
            #expect(
                plan.spellDeployments.map(\.id) ==
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
                let troops = plan.deployments.map {
                    "\($0.position.x),\($0.position.y),\($0.deploymentTime)"
                }
                let spells = plan.spellDeployments.map {
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

    #expect(variants.count == 21)
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

                return coordinate.row >= 0 &&
                    coordinate.row < grid.rows &&
                    coordinate.column >= 0 &&
                    coordinate.column <= 2
            }
        }
    )
    #expect(
        variants.allSatisfy { variant in
            variant.spellDeployments.allSatisfy {
                $0.deploymentTime >= 0 && $0.deploymentTime <= 59
            }
        }
    )
    #expect(
        variants.contains { $0.name.contains("magie anticipate") }
    )
    #expect(
        variants.contains { $0.name.contains("deploy avanti") }
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


@Test
func duplicatedBaseCreatesASecondPersistentLibraryEntry() {
    let storageKey = "clashAttackLab.tests.duplicatedBase.(UUID().uuidString)"
    let library = BaseSnapshotLibrary(storageKey: storageKey)
    library.clear()

    let original = BaseSnapshot(
        name: "Originale",
        objects: [
            BaseObjectSnapshot(
                kind: .townHall,
                column: 20,
                row: 8
            ),
            BaseObjectSnapshot(
                kind: .cannon,
                column: 15,
                row: 8
            )
        ]
    )
    let copy = original.duplicated(named: "Originale copia")

    library.save(original)
    library.save(copy)

    #expect(library.bases.count == 2)
    #expect(original.id != copy.id)
    #expect(library.bases.map(\.name).contains("Originale copia"))

    library.clear()
}


@Test
func armyEntryAdvisorDistinguishesGroundAndAirRecommendations() {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let advisor = ArmyEntryAdvisor(
        navigationGrid: grid,
        gameData: PrototypeGameData()
    )
    let army = ArmyConfiguration(
        giants: 1,
        barbarians: 0,
        archers: 0,
        wallBreakers: 0,
        wizards: 0,
        healSpells: 0,
        rageSpells: 0,
        balloons: 1,
        dragons: 1
    )
    let advice = advisor.analyze(
        entities: PrototypeBattleMap.makeBaseEntities(
            navigationGrid: grid,
            layout: .fortress
        ),
        armyConfiguration: army,
        baseName: "Fortezza"
    )

    #expect(advice.recommendations.count == 3)
    #expect(advice.recommendation(for: .giant)?.movementDomain == .ground)
    #expect(advice.recommendation(for: .balloon)?.movementDomain == .air)
    #expect(advice.recommendation(for: .balloon)?.wallCrossings == 0)
    #expect(advice.preferredRecommendation != nil)
    #expect(advice.recommendations.allSatisfy { $0.pathCost > 0 })
}


@Test
func guidedPlanGeneratorAddsBaseAwareFormation() {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let army = ArmyConfiguration.prototypeDefault
    let base = PrototypeBattleMap.makeBaseEntities(
        navigationGrid: grid,
        layout: .fortress
    )
    let guidance = ArmyEntryAdvisor(
        navigationGrid: grid,
        gameData: PrototypeGameData()
    ).analyze(
        entities: base,
        armyConfiguration: army,
        baseName: "Fortezza"
    )
    let plans = AttackPlanGenerator(
        navigationGrid: grid,
        armyConfiguration: army,
        entryAdvice: guidance
    ).generate()

    #expect(plans.count == 30)
    #expect(plans.contains { $0.name.contains("Guidata") })
    #expect(
        plans
            .filter { $0.name.contains("Guidata") }
            .allSatisfy { $0.totalDeploymentCount == army.totalTroops }
    )
}


@Test
func barbarianKingIsASeparateHeroAndUsesIronFist() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let gameData = PrototypeGameData()
    let kingDefinition = gameData.definition(for: .barbarianKing)

    #expect(ArmyConfiguration.prototypeDefault.barbarians == 2)
    #expect(ArmyConfiguration.prototypeDefault.barbarianKings == 1)
    #expect(kingDefinition.heroAbility?.displayName == "Pugno di ferro")
    #expect(kingDefinition.heroAbility?.duration == 6)

    let kingPosition = grid.worldPosition(
        for: GridCoordinate(column: 1, row: 8)
    )
    let cannonColumns = [4, 6, 8, 10]
    let cannons = cannonColumns.map {
        BattleEntity(
            kind: .cannon,
            position: grid.worldPosition(
                for: GridCoordinate(column: $0, row: 8)
            )
        )
    }
    let plan = AttackPlan(
        name: "Re sotto pressione",
        deployments: [
            DeploymentOrder(
                kind: .barbarianKing,
                position: kingPosition,
                deploymentTime: 0
            )
        ]
    )
    let engine = SimulationEngine(
        entities: cannons,
        attackPlan: plan,
        gameData: gameData,
        navigationGrid: grid
    )
    engine.start()

    for _ in 0..<26 {
        engine.advance(by: 0.25)
    }

    let king = try #require(
        engine.entities.first { $0.kind == .barbarianKing }
    )
    #expect(king.heroAbilityUsed)
    #expect(king.heroAbilityRemaining > 0)
}


@Test
func archerQueenActivatesRoyalCloakAndExtendsHerRange() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let gameData = PrototypeGameData()
    let queenDefinition = gameData.definition(for: .archerQueen)

    #expect(ArmyConfiguration.prototypeDefault.archerQueens == 1)
    #expect(queenDefinition.heroAbility?.displayName == "Manto reale")
    #expect(queenDefinition.heroAbility?.attackRangeMultiplier == 1.35)

    let queenPosition = grid.worldPosition(
        for: GridCoordinate(column: 1, row: 8)
    )
    let cannons = [4, 6, 8].map {
        BattleEntity(
            kind: .cannon,
            position: grid.worldPosition(
                for: GridCoordinate(column: $0, row: 8)
            )
        )
    }
    let engine = SimulationEngine(
        entities: cannons,
        attackPlan: AttackPlan(
            name: "Regina sotto pressione",
            deployments: [
                DeploymentOrder(
                    kind: .archerQueen,
                    position: queenPosition,
                    deploymentTime: 0
                )
            ]
        ),
        gameData: gameData,
        navigationGrid: grid
    )
    engine.start()

    for _ in 0..<28 {
        engine.advance(by: 0.25)
    }

    let queen = try #require(
        engine.entities.first { $0.kind == .archerQueen }
    )
    #expect(queen.heroAbilityUsed)
    #expect(queen.heroAbilityRemaining > 0)
}


@Test
func manualHeroAbilityActivationRequiresADeployedHeroAndIsSingleUse() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let gameData = PrototypeGameData()
    let kingPosition = grid.worldPosition(
        for: GridCoordinate(column: 1, row: 8)
    )
    let townHall = BattleEntity(
        kind: .townHall,
        position: grid.worldPosition(
            for: GridCoordinate(column: 22, row: 8)
        )
    )
    let engine = SimulationEngine(
        entities: [townHall],
        attackPlan: AttackPlan(
            name: "Controllo abilità",
            deployments: [
                DeploymentOrder(
                    kind: .barbarianKing,
                    position: kingPosition,
                    deploymentTime: 0
                )
            ]
        ),
        gameData: gameData,
        navigationGrid: grid
    )

    #expect(engine.heroAbilityState(for: .barbarianKing) == .notDeployed)
    #expect(!engine.activateHeroAbility(for: .barbarianKing))

    engine.start()
    engine.advance(by: 0.25)

    #expect(engine.heroAbilityState(for: .barbarianKing) == .ready)
    #expect(engine.activateHeroAbility(for: .barbarianKing))
    #expect(engine.heroAbilityState(for: .barbarianKing) == .active)
    #expect(!engine.activateHeroAbility(for: .barbarianKing))

    let king = try #require(
        engine.entities.first { $0.kind == .barbarianKing }
    )
    #expect(king.heroAbilityUsed)
    #expect(king.heroAbilityRemaining > 0)
}


@Test
func wallWreckerIsASingleSiegeMachineThatPrioritizesTownHall() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let gameData = PrototypeGameData()
    let definition = gameData.definition(for: .wallWrecker)

    #expect(ArmyConfiguration.prototypeDefault.wallWreckers == 1)
    #expect(definition.targetingProfile?.preference == .townHall)
    #expect(definition.damageMultiplierAgainstWalls == 8)

    let army = ArmyConfiguration(
        giants: 0,
        barbarians: 0,
        archers: 0,
        wallBreakers: 0,
        wizards: 0,
        healSpells: 0,
        rageSpells: 0,
        wallWreckers: 2
    )
    #expect(!army.isValid)

    let wrecker = BattleEntity(
        kind: .wallWrecker,
        position: grid.worldPosition(
            for: GridCoordinate(column: 1, row: 8)
        ),
        hitPoints: definition.maxHitPoints
    )
    let cannon = BattleEntity(
        kind: .cannon,
        position: grid.worldPosition(
            for: GridCoordinate(column: 5, row: 8)
        ),
        hitPoints: gameData.definition(for: .cannon).maxHitPoints
    )
    let townHall = BattleEntity(
        kind: .townHall,
        position: grid.worldPosition(
            for: GridCoordinate(column: 20, row: 8)
        ),
        hitPoints: gameData.definition(for: .townHall).maxHitPoints
    )
    let decision = TargetSelectionSystem().selectTroopObjective(
        for: 0,
        among: [1, 2],
        entities: [wrecker, cannon, townHall],
        gameData: gameData,
        navigationGrid: grid,
        breakableCells: [],
        breakableTraversalCost: 0
    )

    #expect(decision?.targetIndex == 2)
}


@Test
func destroyedWallWreckerReleasesItsPayloadAndCountsItAsDeployed() {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let gameData = PrototypeGameData()
    let wreckerPosition = grid.worldPosition(
        for: GridCoordinate(column: 2, row: 8)
    )
    let cannonCoordinates = (3...6).flatMap { column in
        (5...10).map {
            GridCoordinate(column: column, row: $0)
        }
    }
    var base = cannonCoordinates.map {
        BattleEntity(
            kind: .cannon,
            position: grid.worldPosition(for: $0)
        )
    }
    base.append(
        BattleEntity(
            kind: .townHall,
            position: grid.worldPosition(
                for: GridCoordinate(column: 22, row: 8)
            )
        )
    )
    let engine = SimulationEngine(
        entities: base,
        attackPlan: AttackPlan(
            name: "Carico d’assedio",
            deployments: [
                DeploymentOrder(
                    kind: .wallWrecker,
                    position: wreckerPosition,
                    deploymentTime: 0
                )
            ]
        ),
        gameData: gameData,
        navigationGrid: grid
    )
    engine.start()

    for _ in 0..<20 {
        engine.advance(by: 0.25)
    }

    #expect(engine.releasedPayloadTroopCount == 3)
    #expect(engine.deployedTroopCount == 4)
    #expect(
        engine.entities.filter {
            $0.kind == .giant || $0.kind == .barbarian
        }.count == 3
    )

    let firstIDs = engine.entities.map(\.id)
    let firstPositions = engine.entities.map(\.position)
    let firstHitPoints = engine.entities.map(\.hitPoints)
    engine.reset()
    #expect(engine.releasedPayloadTroopCount == 0)
    #expect(engine.deployedTroopCount == 0)
    #expect(engine.entities.count == base.count)
    engine.start()
    for _ in 0..<20 {
        engine.advance(by: 0.25)
    }
    #expect(engine.entities.map(\.id) == firstIDs)
    #expect(engine.entities.map(\.position) == firstPositions)
    #expect(engine.entities.map(\.hitPoints) == firstHitPoints)
    #expect(engine.releasedPayloadTroopCount == 3)
    #expect(Set(engine.entities.map(\.id)).count == engine.entities.count)
}


@Test
func stoneSlammerFliesToDefensesAndUsesTheSharedPayloadSystem() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let gameData = PrototypeGameData()
    let definition = gameData.definition(for: .stoneSlammer)

    #expect(definition.movementDomain == .air)
    #expect(definition.targetingProfile?.preference == .defenses)
    #expect(definition.splashRadius > 0)
    #expect(definition.siegePayload == [.balloon, .balloon])

    let invalidArmy = ArmyConfiguration(
        giants: 0,
        barbarians: 0,
        archers: 0,
        wallBreakers: 0,
        wizards: 0,
        healSpells: 0,
        rageSpells: 0,
        wallWreckers: 1,
        stoneSlammers: 1
    )
    #expect(!invalidArmy.isValid)

    let slammer = BattleEntity(
        kind: .stoneSlammer,
        position: grid.worldPosition(
            for: GridCoordinate(column: 1, row: 8)
        ),
        hitPoints: definition.maxHitPoints
    )
    let townHall = BattleEntity(
        kind: .townHall,
        position: grid.worldPosition(
            for: GridCoordinate(column: 4, row: 8)
        ),
        hitPoints: gameData.definition(for: .townHall).maxHitPoints
    )
    let cannon = BattleEntity(
        kind: .cannon,
        position: grid.worldPosition(
            for: GridCoordinate(column: 12, row: 8)
        ),
        hitPoints: gameData.definition(for: .cannon).maxHitPoints
    )
    let decision = TargetSelectionSystem().selectTroopObjective(
        for: 0,
        among: [1, 2],
        entities: [slammer, townHall, cannon],
        gameData: gameData,
        navigationGrid: grid,
        breakableCells: [],
        breakableTraversalCost: 0
    )

    #expect(decision?.targetIndex == 2)
}


@Test
func freezeSpellDisablesDefenseOnlyWhileItsZoneIsActive() {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let gameData = PrototypeGameData()
    let cannonPosition = grid.worldPosition(
        for: GridCoordinate(column: 10, row: 8)
    )
    let cannon = BattleEntity(
        kind: .cannon,
        position: cannonPosition
    )
    let giantPosition = grid.worldPosition(
        for: GridCoordinate(column: 1, row: 8)
    )
    let plan = AttackPlan(
        name: "Controllo Gelo",
        deployments: [
            DeploymentOrder(
                kind: .giant,
                position: giantPosition,
                deploymentTime: 0
            )
        ],
        spellDeployments: [
            SpellDeploymentOrder(
                kind: .freeze,
                position: cannonPosition,
                deploymentTime: 0
            )
        ]
    )
    let engine = SimulationEngine(
        entities: [
            cannon,
            BattleEntity(
                kind: .townHall,
                position: grid.worldPosition(
                    for: GridCoordinate(column: 22, row: 8)
                )
            )
        ],
        attackPlan: plan,
        gameData: gameData,
        navigationGrid: grid
    )
    engine.start()
    engine.advance(by: 0.25)

    #expect(engine.isDefenseDisabled(cannon.id))
    #expect(
        engine.spellDefinition(for: .freeze).disablesDefenses
    )

    for _ in 0..<20 {
        engine.advance(by: 0.25)
    }

    #expect(!engine.isDefenseDisabled(cannon.id))
}


@Test
func freezePlacementCoversClustersAndIsIndependentOfEntityOrder() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let data = PrototypeGameData()
    let planner = FreezePlacementPlanner(navigationGrid: grid, gameData: data)
    let positions = [WorldPosition(x: 500, y: 400), WorldPosition(x: 600, y: 400)]
    let defenses = positions.map { BattleEntity(kind: .cannon, position: $0) }
    let selected = try #require(planner.position(
        entities: defenses, troopKinds: [.giant], laneRow: 8
    ))
    let radius = data.spellDefinition(for: .freeze).radius
    for position in positions {
        #expect(hypot(selected.x - position.x, selected.y - position.y) <= radius)
    }
    #expect(planner.position(
        entities: Array(defenses.reversed()), troopKinds: [.giant], laneRow: 8
    ) == selected)
    #expect(grid.coordinate(for: selected) != nil)
}

@Test
func freezePlacementIgnoresDefensesThatCannotAttackTheArmy() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let planner = FreezePlacementPlanner(
        navigationGrid: grid, gameData: PrototypeGameData()
    )
    let cannon = BattleEntity(kind: .cannon, position: WorldPosition(x: 350, y: 400))
    #expect(planner.position(
        entities: [cannon], troopKinds: [.balloon], laneRow: 8
    ) == nil)
    #expect(planner.position(
        entities: [], troopKinds: [.giant], laneRow: 8
    ) == nil)
    let airDefense = BattleEntity(
        kind: .airDefense, position: WorldPosition(x: 850, y: 400)
    )
    let selected = try #require(planner.position(
        entities: [cannon, airDefense], troopKinds: [.balloon], laneRow: 8
    ))
    #expect(hypot(selected.x - airDefense.position.x,
        selected.y - airDefense.position.y) <= 135)
}

@Test
func repeatedFreezePlacementCanCoverAnotherCluster() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let planner = FreezePlacementPlanner(
        navigationGrid: grid, gameData: PrototypeGameData()
    )
    let defenses = [350.0, 850.0].map {
        BattleEntity(kind: .cannon, position: WorldPosition(x: $0, y: 400))
    }
    let first = try #require(planner.position(
        entities: defenses, troopKinds: [.giant], laneRow: 8
    ))
    let second = try #require(planner.position(
        entities: defenses, troopKinds: [.giant], laneRow: 8,
        previousPositions: [first]
    ))
    #expect(first != second)
    #expect(hypot(first.x - second.x, first.y - second.y) > 135)
}

@Test
func generatedFreezeUsesBaseAndRefinementPreservesItsAnchor() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let defensePosition = grid.worldPosition(
        for: GridCoordinate(column: 20, row: 8)
    )
    let army = ArmyConfiguration(
        giants: 1, barbarians: 0, archers: 0, wallBreakers: 0,
        wizards: 0, healSpells: 0, rageSpells: 0, freezeSpells: 1
    )
    let plans = AttackPlanGenerator(
        navigationGrid: grid, armyConfiguration: army,
        baseEntities: [BattleEntity(kind: .cannon, position: defensePosition)]
    ).generate()
    #expect(plans.count == 24)
    for plan in plans {
        let spell = try #require(plan.spellDeployments.first)
        #expect(spell.kind == .freeze)
        #expect(hypot(spell.position.x - defensePosition.x,
            spell.position.y - defensePosition.y) <= 135)
        #expect(plan.deployments.count == 1)
    }
    let source = try #require(plans.first)
    let shifted = AttackPlanRefiner(navigationGrid: grid).variant(
        from: source, laneOffset: 2
    )
    #expect(shifted.spellDeployments.first?.position ==
        source.spellDeployments.first?.position)
    #expect(shifted.deployments.first?.position != source.deployments.first?.position)
}

@Test
func freezePreventsShotsAndResetClearsTheZone() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let cannon = BattleEntity(
        kind: .cannon,
        position: grid.worldPosition(for: GridCoordinate(column: 5, row: 8))
    )
    let order = DeploymentOrder(
        kind: .giant,
        position: grid.worldPosition(for: GridCoordinate(column: 2, row: 8)),
        deploymentTime: 0
    )
    let frozen = SimulationEngine(
        entities: [cannon],
        attackPlan: AttackPlan(
            name: "Frozen",
            deployments: [order],
            spellDeployments: [SpellDeploymentOrder(
                kind: .freeze, position: cannon.position, deploymentTime: 0
            )]
        ),
        gameData: PrototypeGameData(), navigationGrid: grid
    )
    let control = SimulationEngine(
        entities: [cannon],
        attackPlan: AttackPlan(name: "Control", deployments: [order]),
        gameData: PrototypeGameData(), navigationGrid: grid
    )
    frozen.start()
    control.start()
    for _ in 0..<4 {
        frozen.advance(by: 0.25)
        control.advance(by: 0.25)
    }
    let frozenTroop = try #require(frozen.entities.first { $0.id == order.entityID })
    let controlTroop = try #require(control.entities.first { $0.id == order.entityID })
    #expect(frozenTroop.hitPoints > controlTroop.hitPoints)
    #expect(!frozen.projectiles.contains { $0.sourceEntityID == cannon.id })
    frozen.reset()
    #expect(frozen.activeSpells.isEmpty)
    #expect(!frozen.isDefenseDisabled(cannon.id))
    #expect(frozen.deployedSpellCount == 0)
    #expect(frozen.pendingSpellCount == 1)
}


@Test
func heroCommandSurvivesJSONAndLegacyPlansStillLoad() throws {
    let troop = DeploymentOrder(
        kind: .barbarianKing, position: WorldPosition(x: 100, y: 300),
        deploymentTime: 0
    )
    let plan = AttackPlan(
        name: "Recorded hero", deployments: [troop],
        heroAbilityOrders: [HeroAbilityOrder(
            entityID: troop.entityID, activationTime: 3
        )]
    )
    let data = try JSONEncoder().encode(plan)
    let restored = try JSONDecoder().decode(AttackPlan.self, from: data)
    #expect(restored.heroAbilityOrders.first?.entityID == troop.entityID)
    #expect(restored.heroAbilityOrders.first?.activationTime == 3)
    #expect(restored.latestDeploymentTime == 3)
    var legacy = try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    legacy.removeValue(forKey: "heroAbilityOrders")
    let legacyData = try JSONSerialization.data(withJSONObject: legacy)
    let oldPlan = try JSONDecoder().decode(AttackPlan.self, from: legacyData)
    #expect(oldPlan.heroAbilityOrders.isEmpty)
    #expect(oldPlan.deployments.first?.entityID == troop.entityID)
}

@Test
func manualHeroCommandReplaysAtExactlyTheRecordedStep() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let order = DeploymentOrder(
        kind: .barbarianKing,
        position: grid.worldPosition(for: GridCoordinate(column: 1, row: 8)),
        deploymentTime: 0
    )
    let base = [BattleEntity(
        kind: .townHall,
        position: grid.worldPosition(for: GridCoordinate(column: 23, row: 8))
    )]
    let engine = SimulationEngine(
        entities: base,
        attackPlan: AttackPlan(name: "Hero replay", deployments: [order]),
        gameData: PrototypeGameData(), navigationGrid: grid
    )
    engine.start()
    for _ in 0..<4 { engine.advance(by: 0.25) }
    let activationTime = engine.elapsedTime
    #expect(engine.activateHeroAbility(for: .barbarianKing))
    #expect(!engine.activateHeroAbility(for: .barbarianKing))
    let recorded = engine.recordedAttackPlan
    #expect(recorded.heroAbilityOrders.count == 1)
    #expect(recorded.heroAbilityOrders.first?.activationTime == activationTime)
    for _ in 0..<8 { engine.advance(by: 0.25) }
    let positions = engine.entities.map(\.position)
    let health = engine.entities.map(\.hitPoints)
    let abilityTimers = engine.entities.map(\.heroAbilityRemaining)

    let decoded = try JSONDecoder().decode(
        AttackPlan.self, from: JSONEncoder().encode(recorded)
    )
    engine.loadAttackPlan(decoded)
    engine.start()
    for _ in 0..<3 { engine.advance(by: 0.25) }
    #expect(engine.heroAbilityState(for: .barbarianKing) == .ready)
    engine.advance(by: 0.25)
    #expect(engine.heroAbilityState(for: .barbarianKing) == .active)
    for _ in 0..<8 { engine.advance(by: 0.25) }
    #expect(engine.entities.map(\.position) == positions)
    #expect(engine.entities.map(\.hitPoints) == health)
    #expect(engine.entities.map(\.heroAbilityRemaining) == abilityTimers)
    #expect(engine.recordedAttackPlan.heroAbilityOrders.count == 1)
}

@Test
func pausedHeroCommandIsRecordedWithoutAdvancingBattleTime() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let order = DeploymentOrder(
        kind: .archerQueen,
        position: grid.worldPosition(for: GridCoordinate(column: 1, row: 8)),
        deploymentTime: 0
    )
    let engine = SimulationEngine(
        entities: [BattleEntity(
            kind: .townHall,
            position: grid.worldPosition(for: GridCoordinate(column: 23, row: 8))
        )],
        attackPlan: AttackPlan(name: "Paused command", deployments: [order]),
        gameData: PrototypeGameData(), navigationGrid: grid
    )
    engine.start()
    engine.advance(by: 0.25)
    engine.togglePause()
    let pausedTime = engine.elapsedTime
    #expect(engine.activateHeroAbility(for: .archerQueen))
    let timer = try #require(engine.entities.first { $0.id == order.entityID })
        .heroAbilityRemaining
    engine.advance(by: 0.25)
    #expect(engine.elapsedTime == pausedTime)
    #expect(engine.entities.first { $0.id == order.entityID }?.heroAbilityRemaining == timer)
    #expect(engine.recordedAttackPlan.heroAbilityOrders.first?.activationTime == pausedTime)
    engine.reset()
    engine.start()
    engine.advance(by: 0.25)
    #expect(engine.heroAbilityState(for: .archerQueen) == .active)
}

@Test
func heroCommandsArePreservedByRenameDuplicateAndLibraryReload() throws {
    let key = "clashAttackLab.tests.heroCommands.\(UUID().uuidString)"
    defer { UserDefaults.standard.removeObject(forKey: key) }
    let library = AttackPlanLibrary(storageKey: key)
    let troop = DeploymentOrder(
        kind: .barbarianKing, position: WorldPosition(x: 100, y: 300),
        deploymentTime: 0
    )
    let plan = AttackPlan(
        name: "Original", deployments: [troop],
        heroAbilityOrders: [HeroAbilityOrder(entityID: troop.entityID, activationTime: 4)]
    )
    library.save(plan)
    library.rename(plan, to: "Renamed")
    #expect(library.plans.first?.heroAbilityOrders.count == 1)
    let copy = library.duplicate(plan)
    #expect(copy.id != plan.id)
    #expect(copy.heroAbilityOrders.first?.entityID == copy.deployments.first?.entityID)
    let reloaded = AttackPlanLibrary(storageKey: key)
    #expect(reloaded.plans.count == 2)
    #expect(reloaded.plans.allSatisfy { $0.heroAbilityOrders.count == 1 })
}

@Test
func editingAndRefiningKeepHeroCommandsAttachedToTheirDeployment() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let troop = DeploymentOrder(
        kind: .barbarianKing,
        position: grid.worldPosition(for: GridCoordinate(column: 1, row: 8)),
        deploymentTime: 2
    )
    let command = HeroAbilityOrder(entityID: troop.entityID, activationTime: 6)
    var draft = ManualAttackPlan(
        deployments: [troop], heroAbilityOrders: [command]
    )
    draft.updateOrderTime(id: troop.id, to: 4)
    #expect(draft.makeAttackPlan().heroAbilityOrders.first?.activationTime == 8)
    let refined = AttackPlanRefiner(navigationGrid: grid).variant(
        from: draft.makeAttackPlan(), laneOffset: 1, tempoMultiplier: 1.2
    )
    #expect(refined.heroAbilityOrders.first?.entityID == troop.entityID)
    let time = try #require(refined.heroAbilityOrders.first?.activationTime)
    #expect(abs(time - 9.6) < 0.000001)
    draft.removeOrder(id: troop.id)
    #expect(draft.makeAttackPlan().heroAbilityOrders.isEmpty)
}


@Test
func heroScheduleEditorClampsTimeAndKeepsOneCommandPerHero() throws {
    let hero = DeploymentOrder(
        kind: .archerQueen, position: WorldPosition(x: 100, y: 300),
        deploymentTime: 3
    )
    let troop = DeploymentOrder(
        kind: .giant, position: hero.position, deploymentTime: 0
    )
    var draft = ManualAttackPlan(deployments: [hero, troop])
    draft.setHeroAbilityTime(entityID: troop.entityID, to: 5)
    #expect(draft.heroAbilityOrders.isEmpty)
    draft.setHeroAbilityTime(entityID: hero.entityID, to: 0)
    #expect(draft.heroAbilityOrders.first?.activationTime == 3)
    let commandID = try #require(draft.heroAbilityOrders.first?.id)
    draft.setHeroAbilityTime(entityID: hero.entityID, to: 100)
    #expect(draft.heroAbilityOrders.count == 1)
    #expect(draft.heroAbilityOrders.first?.activationTime == 59)
    #expect(draft.heroAbilityOrders.first?.id == commandID)
    draft.setHeroAbilityTime(entityID: hero.entityID, to: .nan)
    #expect(draft.heroAbilityOrders.first?.activationTime == 59)
    #expect(draft.totalOrderCount == 3)
    draft.removeHeroAbility(entityID: hero.entityID)
    #expect(draft.totalOrderCount == 2)
    #expect(draft.deployments.count == 2)
}

@Test
func removingLastOrderRemovesScheduledAbilityBeforeItsHero() {
    let hero = DeploymentOrder(
        kind: .barbarianKing, position: WorldPosition(x: 100, y: 300),
        deploymentTime: 0
    )
    var draft = ManualAttackPlan(deployments: [hero])
    draft.setHeroAbilityTime(entityID: hero.entityID, to: 4)
    draft.removeMostRecentOrder()
    #expect(draft.heroAbilityOrders.isEmpty)
    #expect(draft.deployments.count == 1)
    draft.removeMostRecentOrder()
    #expect(draft.totalOrderCount == 0)
}

@Test
func editedHeroScheduleRunsAtTheSelectedTime() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let hero = DeploymentOrder(
        kind: .barbarianKing,
        position: grid.worldPosition(for: GridCoordinate(column: 1, row: 8)),
        deploymentTime: 0
    )
    var draft = ManualAttackPlan(deployments: [hero])
    draft.setHeroAbilityTime(entityID: hero.entityID, to: 2)
    let engine = SimulationEngine(
        entities: [BattleEntity(
            kind: .townHall,
            position: grid.worldPosition(for: GridCoordinate(column: 23, row: 8))
        )],
        attackPlan: draft.makeAttackPlan(),
        gameData: PrototypeGameData(), navigationGrid: grid
    )
    engine.start()
    for _ in 0..<6 { engine.advance(by: 0.25) }
    #expect(engine.heroAbilityState(for: .barbarianKing) == .ready)
    for _ in 0..<3 { engine.advance(by: 0.25) }
    #expect(engine.heroAbilityState(for: .barbarianKing) == .active)
    draft.removeHeroAbility(entityID: hero.entityID)
    engine.loadAttackPlan(draft.makeAttackPlan())
    engine.start()
    for _ in 0..<9 { engine.advance(by: 0.25) }
    #expect(engine.heroAbilityState(for: .barbarianKing) == .ready)
}


@Test
func heroTimingSearchPreservesArmySpellsAndBaseline() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let position = grid.worldPosition(for: GridCoordinate(column: 1, row: 8))
    let king = DeploymentOrder(kind: .barbarianKing, position: position, deploymentTime: 1)
    let queen = DeploymentOrder(kind: .archerQueen, position: position, deploymentTime: 3)
    let plan = AttackPlan(
        name: "Hero search", deployments: [king, queen],
        spellDeployments: [SpellDeploymentOrder(
            kind: .rage, position: position, deploymentTime: 5
        )]
    )
    let refiner = AttackPlanRefiner(navigationGrid: grid)
    let variants = refiner.heroTimingVariants(for: plan)
    #expect(!variants.isEmpty)
    #expect(variants.count <= 9)
    let fullSearch = refiner.variants(for: plan)
    #expect(fullSearch.contains { $0.id == plan.id })
    #expect(fullSearch.count == 21 + variants.count)
    for variant in variants {
        #expect(variant.deployments.map(\.id) == plan.deployments.map(\.id))
        #expect(variant.deployments.map(\.entityID) == plan.deployments.map(\.entityID))
        #expect(variant.deployments.map(\.position) == plan.deployments.map(\.position))
        #expect(variant.deployments.map(\.deploymentTime) == plan.deployments.map(\.deploymentTime))
        #expect(variant.spellDeployments.map(\.id) == plan.spellDeployments.map(\.id))
        #expect(variant.spellDeployments.map(\.deploymentTime) == plan.spellDeployments.map(\.deploymentTime))
        for command in variant.heroAbilityOrders {
            let hero = try #require(plan.deployments.first { $0.entityID == command.entityID })
            #expect(command.activationTime >= hero.deploymentTime)
            #expect(command.activationTime <= 59)
        }
    }
}

@Test
func heroTimingSearchIncludesAutomaticAndChangesOneHeroAtATime() {
    let position = WorldPosition(x: 100, y: 300)
    let king = DeploymentOrder(kind: .barbarianKing, position: position, deploymentTime: 0)
    let queen = DeploymentOrder(kind: .archerQueen, position: position, deploymentTime: 0)
    let plan = AttackPlan(
        name: "Recorded timings", deployments: [king, queen],
        heroAbilityOrders: [
            HeroAbilityOrder(entityID: king.entityID, activationTime: 6),
            HeroAbilityOrder(entityID: queen.entityID, activationTime: 10)
        ]
    )
    let variants = AttackPlanRefiner(
        navigationGrid: PrototypeBattleMap.makeNavigationGrid()
    ).heroTimingVariants(for: plan)
    #expect(variants.contains { candidate in
        candidate.heroAbilityOrders.count == 1 &&
            candidate.heroAbilityOrders.first?.entityID == queen.entityID
    })
    #expect(variants.contains { candidate in
        candidate.heroAbilityOrders.contains {
            $0.entityID == king.entityID && $0.activationTime == 4
        } && candidate.heroAbilityOrders.contains {
            $0.entityID == queen.entityID && $0.activationTime == 10
        }
    })
}

@Test
func heroTimingSearchDeduplicatesClampedTimesAndSkipsNonHeroes() {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let refiner = AttackPlanRefiner(navigationGrid: grid)
    let position = WorldPosition(x: 100, y: 300)
    let ordinary = AttackPlan(name: "No heroes", deployments: [
        DeploymentOrder(kind: .giant, position: position, deploymentTime: 0)
    ])
    #expect(refiner.heroTimingVariants(for: ordinary).isEmpty)
    let hero = DeploymentOrder(kind: .barbarianKing, position: position, deploymentTime: 59)
    let late = AttackPlan(name: "Late hero", deployments: [hero])
    let variants = refiner.heroTimingVariants(for: late)
    #expect(variants.count == 1)
    #expect(variants.first?.heroAbilityOrders.first?.activationTime == 59)
}


@Test
func cooperativeEvaluationMatchesSynchronousResults() async throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let base = PrototypeBattleMap.makeBaseEntities(navigationGrid: grid)
    let evaluator = AttackPlanEvaluator(
        baseEntities: base, gameData: PrototypeGameData(), navigationGrid: grid
    )
    let plans = Array(AttackPlanGenerator(navigationGrid: grid).generate().prefix(2))
    let expected = evaluator.evaluate(plans)
    var progress: [Int] = []
    let actual = try await evaluator.evaluateAsync(plans) { progress.append($0) }
    #expect(progress == [0, 1, 2])
    #expect(actual.map(\.plan.id) == expected.map(\.plan.id))
    #expect(actual.map(\.stars) == expected.map(\.stars))
    #expect(actual.map(\.destructionPercentage) == expected.map(\.destructionPercentage))
    #expect(actual.map { $0.result.elapsedTime } == expected.map { $0.result.elapsedTime })
    #expect(actual.map { $0.result.survivingTroops } == expected.map { $0.result.survivingTroops })
    #expect(actual.map { $0.result.metrics.damageToBase } == expected.map { $0.result.metrics.damageToBase })
}

@Test
func cooperativeEvaluationHonorsCancellationBeforeStarting() async {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let evaluator = AttackPlanEvaluator(
        baseEntities: PrototypeBattleMap.makeBaseEntities(navigationGrid: grid),
        gameData: PrototypeGameData(), navigationGrid: grid
    )
    let plans = AttackPlanGenerator(navigationGrid: grid).generate()
    let task = Task { @MainActor in
        try await evaluator.evaluateAsync(plans)
    }
    task.cancel()
    do {
        _ = try await task.value
        Issue.record("A cancelled evaluation must not return a ranking.")
    } catch is CancellationError {
        // Expected.
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test
func cooperativeEvaluationYieldsAndCanBeCancelledDuringSearch() async {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let evaluator = AttackPlanEvaluator(
        baseEntities: PrototypeBattleMap.makeBaseEntities(navigationGrid: grid),
        gameData: PrototypeGameData(), navigationGrid: grid
    )
    let plans = AttackPlanGenerator(navigationGrid: grid).generate()
    var started = false
    var completed = 0
    let task = Task { @MainActor in
        try await evaluator.evaluateAsync(plans) {
            started = true
            completed = $0
        }
    }
    while !started { await Task.yield() }
    task.cancel()
    do {
        _ = try await task.value
        Issue.record("Interrupted search must not publish partial results.")
    } catch is CancellationError {
        #expect(completed < plans.count)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test
func replacingAndCancellingSessionSearchDoesNotPublishStaleResults() async {
    let session = AttackLabSession()
    session.findBestAttack()
    #expect(session.isSearching)
    session.rankGeneratedPlansAcrossBases()
    #expect(session.isSearching)
    #expect(session.searchTitle == "Torneo strategie")
    session.cancelSearch()
    #expect(!session.isSearching)
    for _ in 0..<10 { await Task.yield() }
    #expect(session.evaluations.isEmpty)
    #expect(session.generatedPlanRankings.isEmpty)
    #expect(session.searchMessage.contains("annullata"))
}

@Test
func loadingAnotherPlanCancelsAnActiveSearch() async {
    let session = AttackLabSession()
    session.findBestAttack()
    let plan = AttackPlan(name: "Replacement", deployments: [])
    session.loadSavedPlan(plan)
    #expect(!session.isSearching)
    for _ in 0..<10 { await Task.yield() }
    #expect(session.selectedPlanID == plan.id)
    #expect(session.evaluations.isEmpty)
}


@Test
func equalCostPathfindingUsesStableCoordinateTieBreaks() throws {
    let grid = NavigationGrid(
        columns: 5, rows: 5, cellSize: 40,
        origin: WorldPosition(x: 0, y: 0),
        blockedCells: [GridCoordinate(column: 2, row: 2)]
    )
    let start = grid.worldPosition(for: GridCoordinate(column: 0, row: 2))
    let goal = grid.worldPosition(for: GridCoordinate(column: 4, row: 2))
    let pathfinder = AStarPathfinder()
    let expected = try #require(pathfinder.findPath(from: start, to: goal, in: grid))
    #expect(expected.waypoints.contains {
        (grid.coordinate(for: $0)?.row ?? 2) < 2
    })
    for _ in 0..<30 {
        let result = try #require(pathfinder.findPath(from: start, to: goal, in: grid))
        #expect(result.waypoints == expected.waypoints)
        #expect(result.totalCost == expected.totalCost)
    }
}


@Test
func regeneratedPrototypeBasesKeepIdentityAndEntityOrder() {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    for layout in PrototypeBaseLayout.allCases {
        let first = PrototypeBattleMap.makeBaseEntities(navigationGrid: grid, layout: layout)
        let second = PrototypeBattleMap.makeBaseEntities(navigationGrid: grid, layout: layout)
        #expect(first.map(\.id) == second.map(\.id))
        #expect(first.map(\.position) == second.map(\.position))
        #expect(first.map(\.kind) == second.map(\.kind))
        #expect(Set(first.map(\.id)).count == first.count)
    }
}

@Test
func regeneratedCandidatesAndBasesProduceTheSameBattle() async throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let firstPlan = try #require(AttackPlanGenerator(navigationGrid: grid).generate().first)
    let secondPlan = try #require(AttackPlanGenerator(navigationGrid: grid).generate().first)
    #expect(firstPlan.deployments.map(\.id) == secondPlan.deployments.map(\.id))
    #expect(firstPlan.deployments.map(\.entityID) == secondPlan.deployments.map(\.entityID))
    #expect(firstPlan.spellDeployments.map(\.id) == secondPlan.spellDeployments.map(\.id))
    let firstEvaluator = AttackPlanEvaluator(
        baseEntities: PrototypeBattleMap.makeBaseEntities(navigationGrid: grid),
        gameData: PrototypeGameData(), navigationGrid: grid
    )
    let secondEvaluator = AttackPlanEvaluator(
        baseEntities: PrototypeBattleMap.makeBaseEntities(navigationGrid: grid),
        gameData: PrototypeGameData(), navigationGrid: grid
    )
    let firstResults = try await firstEvaluator.evaluateAsync([firstPlan])
    let secondResults = try await secondEvaluator.evaluateAsync([secondPlan])
    let first = try #require(firstResults.first?.result)
    let second = try #require(secondResults.first?.result)
    #expect(first.elapsedTime == second.elapsedTime)
    #expect(first.survivingTroops == second.survivingTroops)
    #expect(first.score.stars == second.score.stars)
    #expect(first.score.destructionPercentage == second.score.destructionPercentage)
    #expect(first.metrics.damageToBase == second.metrics.damageToBase)
}

private func robustnessFixture(
    name: String, outcomes: [(Int, Double)]
) -> AttackPlanRobustnessAnalysis {
    let plan = AttackPlan(name: name, deployments: [])
    let entries = outcomes.enumerated().map { index, outcome in
        BaseAttackEvaluation(
            layout: PrototypeBaseLayout.allCases[index],
            evaluation: AttackPlanEvaluation(
                plan: plan,
                result: SimulationResult(
                    winner: .defenses, elapsedTime: 30,
                    timeExpired: true, finishReason: .timeExpired,
                    deployedTroops: 1, survivingTroops: 1, survivingDefenses: 1,
                    troopAttackCount: 1, defenseAttackCount: 1,
                    score: BaseScoreSnapshot(
                        destructionPercentage: outcome.1, stars: outcome.0,
                        townHallDestroyed: false, destroyedBuildings: 0, totalBuildings: 1
                    ),
                    metrics: BattleSummaryMetrics(
                        damageToBase: outcome.1, hitPointsLostByArmy: 0,
                        troopsLost: 0, destroyedWalls: 0, spellsCast: 0
                    )
                )
            )
        )
    }
    return AttackPlanRobustnessAnalysis(plan: plan, entries: entries)
}

@Test
func weakestBaseRankingCanPreferConsistencyOverAHigherAverage() {
    let uneven = robustnessFixture(name: "Uneven", outcomes: [(3, 100), (3, 100), (1, 50)])
    let consistent = robustnessFixture(name: "Consistent", outcomes: [(2, 70), (2, 70), (2, 70)])
    let candidates = [uneven, consistent]
    #expect(AttackPlanRobustnessRanker.rank(candidates).first?.plan.id == uneven.plan.id)
    #expect(AttackPlanRobustnessRanker.rank(
        candidates, objective: .weakestBase
    ).first?.plan.id == consistent.plan.id)
    #expect(uneven.weakestEntry?.layout == .doubleCore)
    #expect(uneven.weakestEntry?.evaluation.stars == 1)
    #expect(uneven.weakestBaseSummary.contains("Doppio nucleo"))
}

@Test
func weakestBaseUsesDestructionToBreakEqualStarsAndHandlesEmptyResults() {
    let first = robustnessFixture(name: "First", outcomes: [(2, 80), (2, 60)])
    let second = robustnessFixture(name: "Second", outcomes: [(2, 80), (2, 70)])
    let empty = AttackPlanRobustnessAnalysis(
        plan: AttackPlan(name: "Empty", deployments: []), entries: []
    )
    let ranked = AttackPlanRobustnessRanker.rank(
        [empty, first, second], objective: .weakestBase
    )
    #expect(ranked.map(\.plan.name) == ["Second", "First", "Empty"])
    #expect(first.weakestEntry?.layout == .corridor)
    #expect(empty.weakestEntry == nil)
}


private func testPlanArchiveData(
    _ plans: [AttackPlan], grid: NavigationGrid, version: Int = 1
) throws -> Data {
    try JSONEncoder().encode(AttackPlanArchive(
        format: "clash-attack-lab-plans", version: version,
        profile: "prototype-v1", columns: grid.columns, rows: grid.rows,
        cellSize: grid.cellSize, origin: grid.origin, plans: plans
    ))
}

@Test
func planArchiveRoundTripsArmySpellsAndHeroCommands() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let basePlan = try #require(AttackPlanGenerator(navigationGrid: grid).generate().first)
    let hero = try #require(basePlan.deployments.first { $0.kind == .barbarianKing })
    let plan = basePlan.recordingHeroAbility(HeroAbilityOrder(
        entityID: hero.entityID, activationTime: hero.deploymentTime + 4
    ))
    let data = try AttackPlanArchiveCodec.encode([plan], on: grid)
    let restored = try #require(AttackPlanArchiveCodec.decode(data, on: grid).first)
    #expect(restored.id == plan.id)
    #expect(restored.deployments.map(\.entityID) == plan.deployments.map(\.entityID))
    #expect(restored.spellDeployments.map(\.id) == plan.spellDeployments.map(\.id))
    #expect(restored.heroAbilityOrders.first?.entityID == hero.entityID)
    #expect(restored.heroAbilityOrders.first?.activationTime == hero.deploymentTime + 4)
    #expect(restored.armyConfiguration == plan.armyConfiguration)
}

@Test
func importingPlansAddsCopiesWithoutOverwritingSavedEntries() throws {
    let key = "clashAttackLab.tests.planImport.\(UUID().uuidString)"
    defer { UserDefaults.standard.removeObject(forKey: key) }
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let plan = try #require(AttackPlanGenerator(navigationGrid: grid).generate().first)
    let library = AttackPlanLibrary(storageKey: key)
    library.save(plan)
    let data = try AttackPlanArchiveCodec.encode([plan], on: grid)
    #expect(try library.importArchive(data, on: grid) == 1)
    #expect(try library.importArchive(data, on: grid) == 1)
    #expect(library.plans.count == 3)
    #expect(Set(library.plans.map(\.id)).count == 3)
    #expect(library.plans.last?.id == plan.id)
    #expect(library.plans.first?.deployments.first?.entityID == plan.deployments.first?.entityID)
    #expect(AttackPlanLibrary(storageKey: key).plans.count == 3)
}

@Test
func invalidBatchImportLeavesTheWholeLibraryUnchanged() throws {
    let key = "clashAttackLab.tests.atomicImport.\(UUID().uuidString)"
    defer { UserDefaults.standard.removeObject(forKey: key) }
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let plan = try #require(AttackPlanGenerator(navigationGrid: grid).generate().first)
    let library = AttackPlanLibrary(storageKey: key)
    library.save(plan)
    let invalid = AttackPlan(name: "No troops", deployments: [])
    let data = try testPlanArchiveData([plan, invalid], grid: grid)
    #expect(throws: AttackPlanArchiveError.self) {
        try library.importArchive(data, on: grid)
    }
    #expect(library.plans.map(\.id) == [plan.id])
    #expect(AttackPlanLibrary(storageKey: key).plans.map(\.id) == [plan.id])
}

@Test
func planArchiveRejectsDuplicateIDsAndHeroCommandsBeforeDeployment() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let position = grid.worldPosition(for: GridCoordinate(column: 1, row: 8))
    let hero = DeploymentOrder(kind: .barbarianKing, position: position, deploymentTime: 3)
    let duplicate = AttackPlan(name: "Duplicate", deployments: [hero, hero])
    #expect(throws: AttackPlanArchiveError.self) {
        try AttackPlanArchiveCodec.validate([duplicate], on: grid)
    }
    let early = AttackPlan(name: "Early", deployments: [hero],
        heroAbilityOrders: [HeroAbilityOrder(entityID: hero.entityID, activationTime: 2)])
    #expect(throws: AttackPlanArchiveError.self) {
        try AttackPlanArchiveCodec.validate([early], on: grid)
    }
    let dangling = AttackPlan(name: "Missing hero", deployments: [hero],
        heroAbilityOrders: [HeroAbilityOrder(entityID: UUID(), activationTime: 4)])
    #expect(throws: AttackPlanArchiveError.self) {
        try AttackPlanArchiveCodec.validate([dangling], on: grid)
    }
}

@Test
func planArchiveRejectsInvalidPositionsTimesAndArmyCapacity() {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let legal = grid.worldPosition(for: GridCoordinate(column: 1, row: 8))
    let invalidOrders = [
        DeploymentOrder(kind: .giant, position: WorldPosition(x: .nan, y: 300), deploymentTime: 0),
        DeploymentOrder(kind: .giant, position: legal, deploymentTime: .infinity),
        DeploymentOrder(kind: .giant, position: grid.worldPosition(
            for: GridCoordinate(column: 10, row: 8)), deploymentTime: 0),
        DeploymentOrder(kind: .cannon, position: legal, deploymentTime: 0)
    ]
    for order in invalidOrders {
        #expect(throws: AttackPlanArchiveError.self) {
            try AttackPlanArchiveCodec.validate([
                AttackPlan(name: "Invalid", deployments: [order])
            ], on: grid)
        }
    }
    let oversized = AttackPlan(name: "Too many", deployments: (0..<7).map { _ in
        DeploymentOrder(kind: .giant, position: legal, deploymentTime: 0)
    })
    #expect(throws: AttackPlanArchiveError.self) {
        try AttackPlanArchiveCodec.validate([oversized], on: grid)
    }
}

@Test
func planArchiveRejectsIncompatibleAndOversizedFiles() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let plan = try #require(AttackPlanGenerator(navigationGrid: grid).generate().first)
    let newer = try testPlanArchiveData([plan], grid: grid, version: 99)
    #expect(throws: AttackPlanArchiveError.self) {
        try AttackPlanArchiveCodec.decode(newer, on: grid)
    }
    let otherGrid = NavigationGrid(
        columns: 30, rows: grid.rows, cellSize: grid.cellSize,
        origin: grid.origin, blockedCells: []
    )
    let incompatible = try testPlanArchiveData([plan], grid: otherGrid)
    #expect(throws: AttackPlanArchiveError.self) {
        try AttackPlanArchiveCodec.decode(incompatible, on: grid)
    }
    #expect(throws: AttackPlanArchiveError.self) {
        try AttackPlanArchiveCodec.decode(
            Data(repeating: 32, count: AttackPlanArchiveCodec.maximumBytes + 1),
            on: grid
        )
    }
}

@Test
func openingSavedPlanSynchronizesItsArmyWithTheEditor() {
    let session = AttackLabSession()
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let plan = AttackPlan(name: "Queen only", deployments: [
        DeploymentOrder(kind: .archerQueen, position: grid.worldPosition(
            for: GridCoordinate(column: 1, row: 8)), deploymentTime: 0)
    ])
    session.loadSavedPlan(plan)
    #expect(session.armyConfiguration.archerQueens == 1)
    #expect(session.armyConfiguration.giants == 0)
    #expect(session.selectedPlanID == plan.id)
    session.editSavedPlan(plan)
    #expect(session.isManualPlanning)
    #expect(session.manualPlan.deployments.first?.entityID == plan.deployments.first?.entityID)
    session.cancelManualPlanning()
    #expect(session.selectedPlanID == plan.id)
}


@Test
func armySearchPreservesPrototypeCapacityAndSpecialUnits() {
    let source = ArmyConfiguration.prototypeDefault
    let variants = ArmyCompositionSearch.variants(from: source)
    #expect(variants.count == 7)
    #expect(variants.first?.configuration == source)
    for variant in variants {
        let army = variant.configuration
        #expect(army.isValid)
        #expect(army.troopCapacityUsed == source.troopCapacityUsed)
        #expect(army.barbarianKings == source.barbarianKings)
        #expect(army.archerQueens == source.archerQueens)
        #expect(army.wallWreckers == source.wallWreckers)
        #expect(army.stoneSlammers == source.stoneSlammers)
        #expect(army.healSpells == source.healSpells)
        #expect(army.rageSpells == source.rageSpells)
        #expect(army.freezeSpells == source.freezeSpells)
    }
    for index in variants.indices {
        #expect(!variants.prefix(index).contains {
            $0.configuration == variants[index].configuration
        })
    }
}

@Test
func armySearchHandlesSparseArmiesAndGeneratesValidPlanArchives() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    var source = ArmyConfiguration(
        giants: 0, barbarians: 1, archers: 0, wallBreakers: 0,
        wizards: 0, healSpells: 0, rageSpells: 0
    )
    let variants = ArmyCompositionSearch.variants(from: source)
    #expect(variants.count == 2)
    #expect(variants.last?.configuration.archers == 1)
    for variant in ArmyCompositionSearch.variants(from: .prototypeDefault) {
        let plans = AttackPlanGenerator(
            navigationGrid: grid, armyConfiguration: variant.configuration
        ).generate()
        try AttackPlanArchiveCodec.validate(plans, on: grid)
        #expect(plans.allSatisfy { $0.armyConfiguration == variant.configuration })
    }
    source.barbarians = 0
    #expect(ArmyCompositionSearch.variants(from: source).isEmpty)
}

@Test
func selectingAnEvaluationSynchronizesTheArmyConfiguration() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let plan = AttackPlan(name: "Archers", deployments: [
        DeploymentOrder(
            kind: .archer,
            position: grid.worldPosition(for: GridCoordinate(column: 1, row: 8)),
            deploymentTime: 0
        )
    ])
    let evaluator = AttackPlanEvaluator(
        baseEntities: PrototypeBattleMap.makeBaseEntities(navigationGrid: grid),
        gameData: PrototypeGameData(), navigationGrid: grid
    )
    let evaluation = try #require(evaluator.evaluate([plan]).first)
    let session = AttackLabSession()
    session.select(evaluation)
    #expect(session.armyConfiguration == plan.armyConfiguration)
    #expect(session.selectedPlanID == plan.id)
    #expect(session.candidatePlanCount > 0)
}

@Test
func armyCompositionSearchCanBeCancelledWithoutChangingTheSelectedArmy() async {
    let session = AttackLabSession()
    let originalArmy = session.armyConfiguration
    let originalID = session.selectedPlanID
    session.findBestArmyAndAttack()
    #expect(session.isSearching)
    session.cancelSearch()
    for _ in 0..<10 { await Task.yield() }
    #expect(!session.isSearching)
    #expect(session.armyConfiguration == originalArmy)
    #expect(session.selectedPlanID == originalID)
    #expect(session.evaluations.isEmpty)
}


private func savedBaseRobustnessFixture(
    name: String,
    outcomes: [(Int, Double)]
) -> SavedBasePlanRobustnessAnalysis {
    let plan = AttackPlan(name: name, deployments: [])
    let entries = outcomes.enumerated().map { index, outcome in
        let base = BaseSnapshot(
            name: "Base \(index + 1)",
            objects: [
                BaseObjectSnapshot(
                    kind: .townHall,
                    column: 20,
                    row: 8
                )
            ]
        )
        let result = SimulationResult(
            winner: .defenses,
            elapsedTime: 30,
            timeExpired: true,
            finishReason: .timeExpired,
            deployedTroops: 4,
            survivingTroops: 2,
            survivingDefenses: 1,
            troopAttackCount: 2,
            defenseAttackCount: 2,
            score: BaseScoreSnapshot(
                destructionPercentage: outcome.1,
                stars: outcome.0,
                townHallDestroyed: outcome.0 >= 2,
                destroyedBuildings: 0,
                totalBuildings: 1
            ),
            metrics: BattleSummaryMetrics(
                damageToBase: outcome.1,
                hitPointsLostByArmy: 0,
                troopsLost: 2,
                destroyedWalls: 0,
                spellsCast: 0
            )
        )
        return CustomBaseAttackEvaluation(
            base: base,
            evaluation: AttackPlanEvaluation(plan: plan, result: result)
        )
    }
    return SavedBasePlanRobustnessAnalysis(plan: plan, entries: entries)
}

@Test
func savedBaseReliabilityRankingCanPreferConsistency() {
    let uneven = savedBaseRobustnessFixture(
        name: "Potente ma instabile",
        outcomes: [(3, 100), (3, 100), (1, 50)]
    )
    let consistent = savedBaseRobustnessFixture(
        name: "Affidabile",
        outcomes: [(2, 70), (2, 70), (2, 70)]
    )

    #expect(
        SavedBasePlanRanker.rank(
            [uneven, consistent],
            objective: .average
        ).first?.plan.id == uneven.plan.id
    )
    #expect(
        SavedBasePlanRanker.rank(
            [uneven, consistent],
            objective: .weakestBase
        ).first?.plan.id == consistent.plan.id
    )
    #expect(uneven.weakestEntry?.base.name == "Base 3")
    #expect(uneven.weakestBaseSummary.contains("1★"))
}

@Test
func savedBaseReliabilityRankingHandlesEmptyAnalyses() {
    let empty = SavedBasePlanRobustnessAnalysis(
        plan: AttackPlan(name: "Vuoto", deployments: []),
        entries: []
    )
    let first = savedBaseRobustnessFixture(
        name: "Primo",
        outcomes: [(2, 60), (2, 55)]
    )
    let second = savedBaseRobustnessFixture(
        name: "Secondo",
        outcomes: [(2, 60), (2, 65)]
    )

    let ranked = SavedBasePlanRanker.rank(
        [empty, first, second],
        objective: .weakestBase
    )
    #expect(ranked.map(\.plan.name) == ["Secondo", "Primo", "Vuoto"])
    #expect(empty.weakestEntry == nil)
}


@Test
func baseStrategyBookSummarizesPerBaseRecommendations() {
    let first = savedBaseRobustnessFixture(
        name: "Prima",
        outcomes: [(3, 100)]
    )
    let second = savedBaseRobustnessFixture(
        name: "Seconda",
        outcomes: [(1, 40)]
    )
    let firstEntry = try! #require(first.entries.first)
    let secondEntry = try! #require(second.entries.first)
    let book = BaseStrategyBook(
        recommendations: [
            BaseStrategyRecommendation(
                base: firstEntry.base,
                evaluation: firstEntry.evaluation,
                candidateCount: 84
            ),
            BaseStrategyRecommendation(
                base: secondEntry.base,
                evaluation: secondEntry.evaluation,
                candidateCount: 84
            )
        ]
    )

    #expect(book.baseCount == 2)
    #expect(book.threeStarCount == 1)
    #expect(book.averageStars == 2)
    #expect(book.averageDestruction == 70)
    #expect(book.recommendations[0].candidateCount == 84)
}


@Test
func baseStrategyLibraryPersistsAndReplacesStrategyForTheSameBase() {
    let key = "clashAttackLab.tests.baseStrategies.\(UUID().uuidString)"
    let library = BaseStrategyLibrary(storageKey: key)
    defer { library.clear() }

    let analysis = savedBaseRobustnessFixture(
        name: "Archivio",
        outcomes: [(2, 72)]
    )
    let entry = try! #require(analysis.entries.first)
    let recommendation = BaseStrategyRecommendation(
        base: entry.base,
        evaluation: entry.evaluation,
        candidateCount: 84
    )
    let first = BaseStrategyRecord(
        savedAt: Date(timeIntervalSince1970: 10),
        recommendation: recommendation
    )
    let replacement = BaseStrategyRecord(
        savedAt: Date(timeIntervalSince1970: 20),
        recommendation: recommendation
    )

    library.save([first])
    library.save([replacement])

    #expect(library.records.count == 1)
    #expect(library.records.first?.id == replacement.id)
    #expect(library.records.first?.candidateCount == 84)

    let restored = BaseStrategyLibrary(storageKey: key)
    #expect(restored.records.count == 1)
    #expect(restored.records.first?.base.id == entry.base.id)

    if let record = library.records.first {
        library.delete(record)
    }
    #expect(library.records.isEmpty)
}


@Test
func scenarioAdjustedGameDataScalesOnlyTheRelevantSide() {
    let base = PrototypeGameData()
    let attackerFavored = ScenarioAdjustedGameData(
        base: base,
        scenario: .attackerFavored
    )
    let defenseFavored = ScenarioAdjustedGameData(
        base: base,
        scenario: .defenseFavored
    )

    #expect(
        attackerFavored.definition(for: .giant).maxHitPoints ==
            base.definition(for: .giant).maxHitPoints * 1.1
    )
    #expect(
        attackerFavored.definition(for: .cannon).attackDamage ==
            base.definition(for: .cannon).attackDamage * 0.9
    )
    #expect(
        defenseFavored.definition(for: .giant).attackDamage ==
            base.definition(for: .giant).attackDamage * 0.9
    )
    #expect(
        defenseFavored.definition(for: .wall).maxHitPoints ==
            base.definition(for: .wall).maxHitPoints * 1.1
    )
    #expect(
        defenseFavored.spellDefinition(for: .freeze).duration ==
            base.spellDefinition(for: .freeze).duration
    )
}

@Test
func scenarioAnalysisReportsWorstCaseAndStability() {
    let fixture = savedBaseRobustnessFixture(
        name: "Stress",
        outcomes: [(3, 100), (3, 99), (1, 45)]
    )
    let evaluations = fixture.entries.map(\.evaluation)
    let analysis = AttackPlanScenarioAnalysis(
        plan: fixture.plan,
        entries: [
            ScenarioAttackEvaluation(
                scenario: .neutral,
                evaluation: evaluations[0]
            ),
            ScenarioAttackEvaluation(
                scenario: .attackerFavored,
                evaluation: evaluations[1]
            ),
            ScenarioAttackEvaluation(
                scenario: .defenseFavored,
                evaluation: evaluations[2]
            )
        ]
    )

    #expect(analysis.averageStars == Double(7) / 3)
    #expect(analysis.averageDestruction == Double(244) / 3)
    #expect(analysis.worstCase?.scenario == .defenseFavored)
    #expect(!analysis.isThreeStarStable)
    #expect(analysis.stabilityLabel == "Caso peggiore: 1★")
}


private func scenarioRobustnessFixture(
    name: String,
    outcomes: [(Int, Double)]
) -> ScenarioPlanRobustnessAnalysis {
    let fixture = savedBaseRobustnessFixture(
        name: name,
        outcomes: outcomes
    )
    let scenarios = PrototypeCombatScenario.allCases
    let entries = fixture.entries.enumerated().map { index, entry in
        ScenarioAttackEvaluation(
            scenario: scenarios[index],
            evaluation: entry.evaluation
        )
    }
    return ScenarioPlanRobustnessAnalysis(
        plan: fixture.plan,
        entries: entries
    )
}

@Test
func resilientPlanRankingPrefersTheStrongestWorstScenario() {
    let fragile = scenarioRobustnessFixture(
        name: "Fragile",
        outcomes: [(3, 100), (3, 100), (1, 40)]
    )
    let resilient = scenarioRobustnessFixture(
        name: "Resistente",
        outcomes: [(2, 70), (2, 70), (2, 70)]
    )

    let ranked = ScenarioPlanRobustnessRanker.rank(
        [fragile, resilient]
    )

    #expect(ranked.first?.plan.id == resilient.plan.id)
    #expect(fragile.worstEntry?.scenario == .defenseFavored)
    #expect(!fragile.isThreeStarStable)
}

@Test
func resilientPlanRankingUsesWorstDestructionBeforeAverage() {
    let first = scenarioRobustnessFixture(
        name: "Primo",
        outcomes: [(2, 95), (2, 90), (2, 50)]
    )
    let second = scenarioRobustnessFixture(
        name: "Secondo",
        outcomes: [(2, 90), (2, 85), (2, 60)]
    )
    let empty = ScenarioPlanRobustnessAnalysis(
        plan: AttackPlan(name: "Vuoto", deployments: []),
        entries: []
    )

    let ranked = ScenarioPlanRobustnessRanker.rank([empty, first, second])

    #expect(ranked.map(\.plan.name) == ["Secondo", "Primo", "Vuoto"])
    #expect(second.neutralEvaluation?.stars == 2)
}


@Test
func simulationResultContainsCompactBattleTimeline() throws {
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
    let engine = SimulationEngine(
        entities: [townHall],
        attackPlan: AttackPlan(
            name: "Timeline",
            deployments: [
                DeploymentOrder(
                    kind: .barbarian,
                    position: start,
                    deploymentTime: 0
                )
            ],
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

    engine.start()
    for _ in 0..<1_000 {
        engine.advance(by: 1.0 / 60.0)
    }
    let optionalResult: SimulationResult?
    if case .finished(let finished) = engine.status {
        optionalResult = finished
    } else {
        optionalResult = nil
    }
    let result = try #require(optionalResult)

    #expect(result.timeline.contains { $0.kind == .deployment })
    #expect(result.timeline.contains { $0.kind == .spellCast })
    #expect(result.timeline.contains { $0.kind == .structureDestroyed })
    #expect(result.timeline.last?.kind == .battleFinished)
    #expect(result.timeline.count <= 160)
}

@Test
func historyEntryRetainsTimelineButOlderEntriesCanOmitIt() {
    let plan = AttackPlan(name: "Storico", deployments: [])
    let result = SimulationResult(
        winner: .defenses,
        elapsedTime: 20,
        timeExpired: true,
        finishReason: .timeExpired,
        deployedTroops: 1,
        survivingTroops: 0,
        survivingDefenses: 1,
        troopAttackCount: 1,
        defenseAttackCount: 1,
        score: .zero,
        metrics: BattleSummaryMetrics(
            damageToBase: 0,
            hitPointsLostByArmy: 100,
            troopsLost: 1,
            destroyedWalls: 0,
            spellsCast: 0
        ),
        timeline: [
            BattleTimelineEvent(
                timestamp: 0,
                kind: .deployment,
                message: "Barbaro schierato"
            )
        ]
    )
    let entry = AttackHistoryEntry(plan: plan, result: result)

    #expect(entry.timeline?.count == 1)
    #expect(entry.timeline?.first?.kind == .deployment)
}


@Test
func lightningSpellDealsImmediateAreaDamageWithoutPersistentZone() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let gameData = PrototypeGameData()
    let impact = grid.worldPosition(for: GridCoordinate(column: 10, row: 8))
    let cannon = BattleEntity(kind: .cannon, position: impact)
    let distantTownHall = BattleEntity(
        kind: .townHall,
        position: grid.worldPosition(for: GridCoordinate(column: 22, row: 8))
    )
    let plan = AttackPlan(
        name: "Fulmine istantaneo",
        deployments: [
            DeploymentOrder(
                kind: .barbarian,
                position: grid.worldPosition(for: GridCoordinate(column: 1, row: 1)),
                deploymentTime: 30
            )
        ],
        spellDeployments: [
            SpellDeploymentOrder(kind: .lightning, position: impact, deploymentTime: 0)
        ]
    )
    let engine = SimulationEngine(
        entities: [cannon, distantTownHall],
        attackPlan: plan,
        gameData: gameData,
        navigationGrid: grid
    )
    engine.start()
    engine.advance(by: 0.1)

    let struck = try #require(engine.entities.first { $0.id == cannon.id })
    let untouched = try #require(engine.entities.first { $0.id == distantTownHall.id })
    let lightning = gameData.spellDefinition(for: .lightning)
    #expect(struck.hitPoints == gameData.definition(for: .cannon).maxHitPoints - lightning.instantDamage)
    #expect(untouched.hitPoints == gameData.definition(for: .townHall).maxHitPoints)
    #expect(engine.activeSpells.isEmpty)
    #expect(engine.deployedSpellCount == 1)
}

@Test
func lightningPlannerTargetsDenseDefensiveClusterAndSpreadsRepeatedCasts() throws {
    let grid = PrototypeBattleMap.makeNavigationGrid()
    let gameData = PrototypeGameData()
    let cluster = [
        GridCoordinate(column: 11, row: 7),
        GridCoordinate(column: 12, row: 7),
        GridCoordinate(column: 11, row: 8)
    ].map { BattleEntity(kind: .cannon, position: grid.worldPosition(for: $0)) }
    let isolated = BattleEntity(
        kind: .mortar,
        position: grid.worldPosition(for: GridCoordinate(column: 21, row: 14))
    )
    let planner = LightningPlacementPlanner(navigationGrid: grid, gameData: gameData)
    let first = try #require(planner.position(entities: cluster + [isolated]))
    let radius = gameData.spellDefinition(for: .lightning).radius
    let coveredCluster = cluster.filter {
        hypot(first.x - $0.position.x, first.y - $0.position.y) <= radius
    }
    #expect(coveredCluster.count >= 2)

    let second = try #require(planner.position(
        entities: cluster + [isolated],
        previousPositions: [first]
    ))
    #expect(first != second)
}
