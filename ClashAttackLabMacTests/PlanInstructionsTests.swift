import Foundation
import Testing
@testable import ClashAttackLabMac

struct PlanInstructionsTests {
    private func arena() throws -> BattleArena {
        try BattleArena.make(for: .reference(townHall: 15))
    }

    @Test
    func thePlayersStrategyReadsAsSteps() throws {
        let arena = try arena()
        let base = arena.makeBaseEntities(layout: .fortress)
        let army = try #require(ArmyConfiguration.playerArmy(for: arena.armyRules))
        let plan = try #require(PlayerStrategyPlanner(
            navigationGrid: arena.navigationGrid,
            latestOrderTime: BattleTiming.latestOrderTime(forBattleDuration: arena.gameData.battleDuration)
        ).plan(for: army, against: base))
        let writer = PlanInstructions(navigationGrid: arena.navigationGrid, base: base, gameData: arena.gameData)
        let steps = writer.steps(for: plan)

        #expect(steps.first?.text.hasPrefix("Campionessa reale") == true)
        #expect(steps.first?.timeLabel == "subito")
        #expect(steps.contains { $0.text.hasPrefix("12 × Invisibilità, una ogni ~4 s") })
        #expect(steps.contains { $0.text == "Abilità di Campionessa reale" })
        #expect(steps.map(\.id) == Array(1...steps.count))
        for (earlier, later) in zip(steps, steps.dropFirst()) {
            #expect(earlier.time <= later.time)
        }
        // Grouped: far fewer steps than single orders.
        #expect(steps.count < plan.deployments.count + plan.spellDeployments.count)
        #expect(writer.text(for: plan).hasPrefix(PlayerStrategyPlanner.planName + "\n1. [subito] "))
    }

    @Test
    func troopsDroppedTogetherBecomeOneStep() throws {
        let arena = try arena()
        let grid = arena.navigationGrid
        let edge = grid.worldPosition(for: GridCoordinate(column: 1, row: grid.rows / 2))
        let plan = AttackPlan(
            name: "Draghi",
            deployments: (0..<3).map {
                DeploymentOrder(kind: .dragon, position: edge, deploymentTime: Double($0) * 0.3)
            } + [DeploymentOrder(kind: .dragon, position: edge, deploymentTime: 20)]
        )
        let steps = PlanInstructions(navigationGrid: grid, base: [], gameData: arena.gameData).steps(for: plan)

        #expect(steps.count == 2)
        #expect(steps[0].text == "3 × Drago dal lato sinistro")
        #expect(steps[1].text == "Drago dal lato sinistro")
        #expect(steps[1].timeLabel == "~20 s")
    }

    @Test
    func sidesFollowTheMapAsDrawn() throws {
        let arena = try arena()
        let grid = arena.navigationGrid
        let writer = PlanInstructions(navigationGrid: grid, base: [], gameData: arena.gameData)
        let topLeft = grid.worldPosition(for: GridCoordinate(column: 1, row: grid.rows - 2))
        let bottom = grid.worldPosition(for: GridCoordinate(column: grid.columns / 2, row: 1))

        #expect(writer.sideDescription(topLeft) == "dall'angolo in alto a sinistra")
        #expect(writer.sideDescription(bottom) == "dal lato in basso")
        #expect(writer.landmark(near: topLeft, prefix: " su") == "")
    }
}
