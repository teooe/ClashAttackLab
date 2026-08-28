import Foundation

nonisolated struct AttackPlanEvaluation: Identifiable {
    let id: UUID
    let plan: AttackPlan
    let result: SimulationResult

    init(plan: AttackPlan, result: SimulationResult) {
        self.id = plan.id
        self.plan = plan
        self.result = result
    }

    var stars: Int {
        result.score.stars
    }

    var destructionPercentage: Double {
        result.score.destructionPercentage
    }
}

/// Runs complete battles without creating SpriteKit nodes.
///
/// This is the first search layer for "Trova attacco": each candidate uses a
/// fresh deterministic engine, so visual frame rate cannot alter the ranking.
struct AttackPlanEvaluator {
    private let baseEntities: [BattleEntity]
    private let gameData: any GameDataProviding
    private let navigationGrid: NavigationGrid

    init(
        baseEntities: [BattleEntity],
        gameData: any GameDataProviding,
        navigationGrid: NavigationGrid
    ) {
        self.baseEntities = baseEntities
        self.gameData = gameData
        self.navigationGrid = navigationGrid
    }

    func evaluate(
        _ plans: [AttackPlan]
    ) -> [AttackPlanEvaluation] {
        plans.compactMap { evaluate($0) }
            .sorted(by: isBetter)
    }

    private func evaluate(
        _ plan: AttackPlan
    ) -> AttackPlanEvaluation? {
        let engine = SimulationEngine(
            entities: baseEntities,
            attackPlan: plan,
            gameData: gameData,
            navigationGrid: navigationGrid
        )
        engine.start()

        var iterations = 0
        let maximumIterations = 300

        while iterations < maximumIterations {
            if case .finished(let result) = engine.status {
                return AttackPlanEvaluation(
                    plan: plan,
                    result: result
                )
            }

            engine.advance(by: 0.25)
            iterations += 1
        }

        if case .finished(let result) = engine.status {
            return AttackPlanEvaluation(
                plan: plan,
                result: result
            )
        }

        return nil
    }

    private func isBetter(
        _ first: AttackPlanEvaluation,
        _ second: AttackPlanEvaluation
    ) -> Bool {
        if first.stars != second.stars {
            return first.stars > second.stars
        }

        if first.destructionPercentage != second.destructionPercentage {
            return first.destructionPercentage >
                second.destructionPercentage
        }

        if
            first.result.score.townHallDestroyed !=
            second.result.score.townHallDestroyed
        {
            return first.result.score.townHallDestroyed
        }

        if first.result.survivingTroops != second.result.survivingTroops {
            return first.result.survivingTroops >
                second.result.survivingTroops
        }

        if first.result.elapsedTime != second.result.elapsedTime {
            return first.result.elapsedTime < second.result.elapsedTime
        }

        return first.plan.name < second.plan.name
    }
}
