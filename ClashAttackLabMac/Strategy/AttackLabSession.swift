import Combine
import Foundation
import SpriteKit

final class AttackLabSession: ObservableObject {
    @Published private(set) var evaluations: [AttackPlanEvaluation] = []
    @Published private(set) var selectedPlanID: UUID?
    @Published private(set) var armyConfiguration: ArmyConfiguration
    @Published private(set) var baseLayout: PrototypeBaseLayout
    @Published private(set) var isManualPlanning = false
    @Published private(set) var manualPlan = ManualAttackPlan()
    @Published private(set) var manualSelection:
        ManualPlacementSelection = .troop(.giant)
    @Published private(set) var manualNextDeploymentTime:
        TimeInterval = 0
    @Published private(set) var savedPlans: [AttackPlan] = []
    @Published private(set) var comparisonEvaluations: [AttackPlanEvaluation] = []
    @Published private(set) var lastSimulationResult: SimulationResult?
    @Published private(set) var attackHistory: [AttackHistoryEntry] = []

    let scene: BattleScene

    var candidatePlanCount: Int {
        candidatePlans.count
    }

    var manualTroopChoices: [BattleEntityKind] {
        [
            .giant,
            .barbarian,
            .archer,
            .wallBreaker,
            .wizard,
            .balloon,
            .dragon
        ].filter { armyConfiguration.troopCount(for: $0) > 0 }
    }

    var manualSpellChoices: [BattleSpellKind] {
        [.heal, .rage].filter {
            armyConfiguration.spellCount(for: $0) > 0
        }
    }

    var manualPlacementInstruction: String {
        switch manualSelection {
        case .troop:
            return "clicca nella fascia ciano dell’arena"
        case .spell:
            return "clicca ovunque nell’arena"
        }
    }

    var canPlaceManualSelection: Bool {
        switch manualSelection {
        case .troop(let kind):
            return manualPlan.troopCount(for: kind) <
                armyConfiguration.troopCount(for: kind)

        case .spell(let kind):
            return manualPlan.spellCount(for: kind) <
                armyConfiguration.spellCount(for: kind)
        }
    }

    private let gameData: any GameDataProviding
    private let navigationGrid: NavigationGrid
    private var baseEntities: [BattleEntity]
    private var candidatePlans: [AttackPlan]
    private var evaluator: AttackPlanEvaluator
    private var activePlan: AttackPlan
    private let planLibrary = AttackPlanLibrary()
    private let historyStore = AttackHistoryStore()

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
        self.activePlan = initialPlan
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
        self.savedPlans = planLibrary.plans
        self.attackHistory = historyStore.entries
        self.scene.simulationFinishedHandler = { [weak self] result in
            guard let self else { return }
            self.lastSimulationResult = result
            self.historyStore.record(
                AttackHistoryEntry(
                    plan: self.activePlan,
                    result: result
                )
            )
            self.attackHistory = self.historyStore.entries
        }
    }

    func clearAttackHistory() {
        historyStore.clear()
        attackHistory = historyStore.entries
    }

    func compareSavedPlans(_ plans: [AttackPlan]) {
        guard !plans.isEmpty else {
            comparisonEvaluations = []
            return
        }

        comparisonEvaluations = evaluator.evaluate(plans)
    }

    func saveCurrentPlan() {
        planLibrary.save(activePlan)
        savedPlans = planLibrary.plans
    }

    func loadSavedPlan(_ plan: AttackPlan) {
        guard !isManualPlanning else { return }
        activePlan = plan
        selectedPlanID = plan.id
        evaluations = []
        lastSimulationResult = nil
        scene.loadAttackPlan(plan)
    }

    func editSavedPlan(_ plan: AttackPlan) {
        guard !isManualPlanning else { return }

        manualPlan = ManualAttackPlan(
            id: plan.id,
            name: plan.name,
            deployments: plan.deployments,
            spellDeployments: plan.spellDeployments
        )
        manualNextDeploymentTime = min(
            59,
            manualPlan.latestDeploymentTime + 0.6
        )
        manualSelection = defaultManualSelection
        isManualPlanning = true
        scene.setManualPlacementHandler { [weak self] position in
            self?.appendManualPlacement(at: position)
        }
        scene.setManualPlacementUsesWholeArena(
            manualSelectionUsesWholeArena
        )
        scene.loadAttackPlan(manualPlan.makeAttackPlan())
    }

    func renameSavedPlan(_ plan: AttackPlan, to name: String) {
        planLibrary.rename(plan, to: name)
        savedPlans = planLibrary.plans
    }

    func duplicateSavedPlan(_ plan: AttackPlan) {
        _ = planLibrary.duplicate(plan)
        savedPlans = planLibrary.plans
    }

    func deleteSavedPlan(_ plan: AttackPlan) {
        planLibrary.delete(plan)
        savedPlans = planLibrary.plans
    }

    func moveSavedPlans(from offsets: IndexSet, to destination: Int) {
        planLibrary.move(from: offsets, to: destination)
        savedPlans = planLibrary.plans
    }

    func findBestAttack() {
        guard !isManualPlanning else {
            return
        }

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

        finishManualMode(restoreActivePlan: false)
        armyConfiguration = configuration
        candidatePlans = generatedPlans
        evaluations = []
        activePlan = firstPlan
        selectedPlanID = firstPlan.id
        resetManualDraft()
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

        finishManualMode(restoreActivePlan: false)
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

        activePlan = initialPlan
        selectedPlanID = initialPlan.id
        resetManualDraft()
        scene.loadScenario(
            entities: entities,
            attackPlan: initialPlan
        )
    }

    func beginManualPlanning() {
        guard !isManualPlanning else {
            return
        }

        resetManualDraft()
        isManualPlanning = true
        scene.setManualPlacementHandler { [weak self] position in
            self?.appendManualPlacement(at: position)
        }
        scene.setManualPlacementUsesWholeArena(
            manualSelectionUsesWholeArena
        )
        scene.loadAttackPlan(manualPlan.makeAttackPlan())
    }

    func cancelManualPlanning() {
        finishManualMode(restoreActivePlan: true)
    }

    func finishManualPlanning() {
        guard manualPlan.totalOrderCount > 0 else {
            return
        }

        let plan = manualPlan.makeAttackPlan()
        activePlan = plan
        selectedPlanID = plan.id
        evaluations = []
        finishManualMode(restoreActivePlan: false)
        scene.loadAttackPlan(plan)
    }

    func selectManualPlacement(
        _ selection: ManualPlacementSelection
    ) {
        manualSelection = selection
        scene.setManualPlacementUsesWholeArena(
            manualSelectionUsesWholeArena
        )
    }

    func adjustManualDeploymentTime(by delta: TimeInterval) {
        let updated = manualNextDeploymentTime + delta
        manualNextDeploymentTime = min(59, max(0, updated))
    }

    func removeManualOrder(id: UUID) {
        guard isManualPlanning else { return }
        manualPlan.removeOrder(id: id)
        scene.loadAttackPlan(manualPlan.makeAttackPlan())
    }

    func updateManualOrderTime(id: UUID, to time: TimeInterval) {
        guard isManualPlanning else { return }
        manualPlan.updateOrderTime(id: id, to: time)
        scene.loadAttackPlan(manualPlan.makeAttackPlan())
    }

    func removeLastManualOrder() {
        guard manualPlan.totalOrderCount > 0 else {
            return
        }

        manualPlan.removeMostRecentOrder()
        manualNextDeploymentTime = manualPlan.totalOrderCount == 0
            ? 0
            : min(59, manualPlan.latestDeploymentTime + 0.6)
        scene.loadAttackPlan(manualPlan.makeAttackPlan())
    }

    func clearManualOrders() {
        resetManualDraft()
        scene.loadAttackPlan(manualPlan.makeAttackPlan())
    }

    func manualGridLabel(for position: WorldPosition) -> String {
        guard let coordinate = navigationGrid.coordinate(for: position) else {
            return "fuori griglia"
        }

        return "c\(coordinate.column) · r\(coordinate.row)"
    }

    func select(_ evaluation: AttackPlanEvaluation) {
        guard !isManualPlanning else {
            return
        }

        activePlan = evaluation.plan
        selectedPlanID = evaluation.plan.id
        scene.loadAttackPlan(evaluation.plan)
    }

    private func appendManualPlacement(at position: WorldPosition) {
        guard isManualPlanning, canPlaceManualSelection else {
            return
        }

        manualPlan.append(
            manualSelection,
            at: position,
            time: manualNextDeploymentTime
        )
        manualNextDeploymentTime = min(
            59,
            manualNextDeploymentTime + 0.6
        )

        if !canPlaceManualSelection {
            manualSelection = defaultManualSelection
            scene.setManualPlacementUsesWholeArena(
                manualSelectionUsesWholeArena
            )
        }

        scene.loadAttackPlan(manualPlan.makeAttackPlan())
    }

    private var manualSelectionUsesWholeArena: Bool {
        if case .spell = manualSelection {
            return true
        }

        return false
    }

    private func resetManualDraft() {
        manualPlan = ManualAttackPlan()
        manualNextDeploymentTime = 0
        manualSelection = defaultManualSelection
    }

    private var defaultManualSelection: ManualPlacementSelection {
        if let firstTroop = manualTroopChoices.first(where: {
            manualPlan.troopCount(for: $0) <
                armyConfiguration.troopCount(for: $0)
        }) {
            return .troop(firstTroop)
        }

        if let firstSpell = manualSpellChoices.first(where: {
            manualPlan.spellCount(for: $0) <
                armyConfiguration.spellCount(for: $0)
        }) {
            return .spell(firstSpell)
        }

        return .troop(.giant)
    }

    private func finishManualMode(restoreActivePlan: Bool) {
        guard isManualPlanning else {
            return
        }

        isManualPlanning = false
        scene.setManualPlacementUsesWholeArena(false)
        scene.setManualPlacementHandler(nil)

        if restoreActivePlan {
            scene.loadAttackPlan(activePlan)
        }
    }
}
