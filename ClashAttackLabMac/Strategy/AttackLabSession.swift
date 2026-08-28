import Combine
import Foundation
import SpriteKit

final class AttackLabSession: ObservableObject {
    @Published private(set) var evaluations: [AttackPlanEvaluation] = []
    @Published private(set) var selectedPlanID: UUID?
    @Published private(set) var armyConfiguration: ArmyConfiguration
    @Published private(set) var baseLayout: PrototypeBaseLayout

    let scene: BattleScene

    var candidatePlanCount: Int {
        candidatePlans.count
    }

    private let gameData: any GameDataProviding
    private let navigationGrid: NavigationGrid
    private var baseEntities: [BattleEntity]
    private var candidatePlans: [AttackPlan]
    private var evaluator: AttackPlanEvaluator

    init() {
        let gameData = PrototypeGameData()
        let navigationGrid = PrototypeBattleMap.makeNavigationGrid()
        let layout = PrototypeBaseLayout.fortress
        let baseEntities = PrototypeBattleMap.makeBaseEntities(
            navigationGrid: navigationGrid,
            layout: layout
        )
        let configuration = ArmyConfiguration.prototypeDefault
        let candidatePlans = AttackPlanGenerator(
            navigationGrid: navigationGrid,
            armyConfiguration: configuration
        ).generate()
        let initialPlan = candidatePlans[0]

        self.armyConfiguration = configuration
        self.baseLayout = layout
        self.gameData = gameData
        self.navigationGrid = navigationGrid
        self.baseEntities = baseEntities
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

    func applyArmyConfiguration(
        _ configuration: ArmyConfiguration
    ) {
        guard configuration.isValid else {
            return
        }

        let generatedPlans = AttackPlanGenerator(
            navigationGrid: navigationGrid,
            armyConfiguration: configuration
        ).generate()

        guard let firstPlan = generatedPlans.first else {
            return
        }

        armyConfiguration = configuration
        candidatePlans = generatedPlans
        evaluations = []
        selectedPlanID = firstPlan.id
        scene.loadAttackPlan(firstPlan)
    }

    func applyBaseLayout(_ layout: PrototypeBaseLayout) {
        guard layout != baseLayout else {
            return
        }

        let entities = PrototypeBattleMap.makeBaseEntities(
            navigationGrid: navigationGrid,
            layout: layout
        )

        baseLayout = layout
        baseEntities = entities
        evaluator = AttackPlanEvaluator(
            baseEntities: entities,
            gameData: gameData,
            navigationGrid: navigationGrid
        )
        evaluations = []

        guard let initialPlan = candidatePlans.first else {
            return
        }

        selectedPlanID = initialPlan.id
        scene.loadScenario(
            entities: entities,
            attackPlan: initialPlan
        )
    }

    func select(_ evaluation: AttackPlanEvaluation) {
        selectedPlanID = evaluation.plan.id
        scene.loadAttackPlan(evaluation.plan)
    }
}
