import Combine
import Foundation
import SpriteKit

final class AttackLabSession: ObservableObject {
    @Published private(set) var evaluations: [AttackPlanEvaluation] = []
    @Published private(set) var selectedPlanID: UUID?

    let scene: BattleScene

    private let candidatePlans: [AttackPlan]
    private let evaluator: AttackPlanEvaluator

    init() {
        let gameData = PrototypeGameData()
        let navigationGrid = PrototypeBattleMap.makeNavigationGrid()
        let baseEntities = PrototypeBattleMap.makeBaseEntities(
            navigationGrid: navigationGrid
        )
        let candidatePlans = PrototypeBattleMap.makeCandidateAttackPlans(
            navigationGrid: navigationGrid
        )
        let initialPlan = candidatePlans[0]

        self.candidatePlans = candidatePlans
        self.evaluator = AttackPlanEvaluator(
            baseEntities: baseEntities,
            gameData: gameData,
            navigationGrid: navigationGrid
        )

        let simulation = SimulationEngine(
            entities: baseEntities,
            attackPlan: initialPlan,
            gameData: gameData,
            navigationGrid: navigationGrid
        )

        self.scene = BattleScene(
            size: CGSize(width: 1_100, height: 760),
            simulation: simulation,
            navigationGrid: navigationGrid,
            attackPlan: initialPlan
        )
        self.selectedPlanID = initialPlan.id
    }

    func findBestAttack() {
        let rankedEvaluations = evaluator.evaluate(candidatePlans)
        evaluations = rankedEvaluations

        guard let best = rankedEvaluations.first else {
            return
        }

        select(best)
    }

    func select(_ evaluation: AttackPlanEvaluation) {
        selectedPlanID = evaluation.plan.id
        scene.loadAttackPlan(evaluation.plan)
    }
}
