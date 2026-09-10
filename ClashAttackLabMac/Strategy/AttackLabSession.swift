import Combine
import Foundation
import SpriteKit

final class AttackLabSession: ObservableObject {
    @Published private(set) var evaluations: [AttackPlanEvaluation] = []
    @Published private(set) var selectedPlanID: UUID?
    @Published private(set) var armyConfiguration: ArmyConfiguration
    @Published private(set) var baseLayout: PrototypeBaseLayout
    @Published private(set) var activeBaseSnapshot: BaseSnapshot
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
    @Published private(set) var currentPlanAnalysis: AttackPlanRobustnessAnalysis?
    @Published private(set) var robustnessRankings: [AttackPlanRobustnessAnalysis] = []
    @Published private(set) var refinementReport: AttackPlanRefinementReport?
    @Published private(set) var generatedPlanRankings: [AttackPlanRobustnessAnalysis] = []
    @Published private(set) var baseReconnaissance: BaseReconnaissance?
    @Published private(set) var armyEntryAdvice: ArmyEntryAdvice?
    @Published private(set) var savedBases: [BaseSnapshot] = []
    @Published private(set) var savedBasePlanAnalysis: SavedBasePlanAnalysis?
    @Published private(set) var heroAbilityMessage =
        "Le abilità degli eroi sono pronte dopo il loro schieramento."

    let scene: BattleScene

    var candidatePlanCount: Int {
        candidatePlans.count
    }

    func activateHeroAbility(for kind: BattleEntityKind) {
        let definition = gameData.definition(for: kind)
        let stateBeforeActivation = scene.heroAbilityState(for: kind)

        if scene.activateHeroAbility(for: kind) {
            heroAbilityMessage = "\(definition.heroAbility?.displayName ?? definition.displayName) attivata."
            return
        }

        switch stateBeforeActivation {
        case .notDeployed:
            heroAbilityMessage = "\(definition.displayName) non è ancora stato schierato."
        case .ready:
            heroAbilityMessage = "Avvia o riprendi la battaglia per usare l’abilità."
        case .active:
            heroAbilityMessage = "L’abilità di \(definition.displayName) è già attiva."
        case .used:
            heroAbilityMessage = "L’abilità di \(definition.displayName) è già stata usata."
        case .defeated:
            heroAbilityMessage = "\(definition.displayName) è stato sconfitto."
        }
    }

    func restartSimulation() {
        scene.restartSimulation()
        heroAbilityMessage =
            "Le abilità degli eroi sono pronte dopo il loro schieramento."
    }

    var editorNavigationGrid: NavigationGrid {
        navigationGrid
    }

    var manualTroopChoices: [BattleEntityKind] {
        [
            .giant,
            .barbarian,
            .archer,
            .wallBreaker,
            .wizard,
            .balloon,
            .dragon,
            .barbarianKing,
            .archerQueen
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
    private let baseLibrary = BaseSnapshotLibrary()

    init() {
        let gameData = PrototypeGameData()
        let navigationGrid = PrototypeBattleMap.makeNavigationGrid()
        let layout = PrototypeBaseLayout.fortress
        let baseEntities = PrototypeBattleMap.makeBaseEntities(
            navigationGrid: navigationGrid,
            layout: layout
        )
        let configuration = ArmyConfiguration.prototypeDefault
        let initialEntryAdvice = ArmyEntryAdvisor(
            navigationGrid: navigationGrid,
            gameData: gameData
        ).analyze(
            entities: baseEntities,
            armyConfiguration: configuration,
            baseName: layout.displayName
        )
        let candidatePlans = AttackPlanGenerator(
            navigationGrid: navigationGrid,
            armyConfiguration: configuration,
            entryAdvice: initialEntryAdvice
        ).generate()
        let initialPlan = candidatePlans[0]

        self.armyConfiguration = configuration
        self.baseLayout = layout
        self.activeBaseSnapshot = BaseSnapshot.make(
            from: layout,
            navigationGrid: navigationGrid
        )
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
        self.savedBases = baseLibrary.bases
        self.armyEntryAdvice = initialEntryAdvice
        self.scene.simulationFinishedHandler = { [weak self] result in
            guard let self else { return }
            self.lastSimulationResult = result
            self.historyStore.record(
                AttackHistoryEntry(
                    plan: self.activePlan,
                    result: result,
                    baseLayout: self.baseLayout,
                    baseSnapshot: self.activeBaseSnapshot
                )
            )
            self.attackHistory = self.historyStore.entries
        }
    }

    func analyzeCurrentBase() {
        guard !isManualPlanning else {
            return
        }

        baseReconnaissance = BaseReconnaissanceSystem(
            navigationGrid: navigationGrid,
            gameData: gameData
        ).analyze(
            entities: baseEntities,
            layoutName: activeBaseSnapshot.name
        )
    }

    func analyzeArmyEntryOptions() {
        guard !isManualPlanning else {
            return
        }

        armyEntryAdvice = ArmyEntryAdvisor(
            navigationGrid: navigationGrid,
            gameData: gameData
        ).analyze(
            entities: baseEntities,
            armyConfiguration: armyConfiguration,
            baseName: activeBaseSnapshot.name
        )
    }

    /// Shifts the current plan to the lane selected in the reconnaissance.
    func applyReconnaissanceLane(
        _ lane: DeploymentLaneAssessment
    ) {
        guard
            !isManualPlanning,
            !activePlan.deployments.isEmpty
        else {
            return
        }

        let deploymentRows = activePlan.deployments.compactMap {
            navigationGrid.coordinate(for: $0.position)?.row
        }
        guard !deploymentRows.isEmpty else {
            return
        }

        let averageRow =
            deploymentRows.reduce(0, +) / deploymentRows.count
        let shiftedPlan = AttackPlanRefiner(
            navigationGrid: navigationGrid
        ).variant(
            from: activePlan,
            laneOffset: lane.row - averageRow
        )

        loadSavedPlan(shiftedPlan)
        currentPlanAnalysis = nil
    }

    /// Tests the current plan on the active base and every saved custom base.
    func analyzeCurrentPlanAcrossSavedBases() {
        guard !isManualPlanning else {
            return
        }

        var seenBaseIDs = Set<UUID>()
        let bases = ([activeBaseSnapshot] + savedBases).filter {
            seenBaseIDs.insert($0.id).inserted &&
                $0.isValid(on: navigationGrid)
        }

        let entries = bases.compactMap {
            snapshot -> CustomBaseAttackEvaluation? in
            let entities = snapshot.makeEntities(
                navigationGrid: navigationGrid
            )
            let evaluator = AttackPlanEvaluator(
                baseEntities: entities,
                gameData: gameData,
                navigationGrid: navigationGrid
            )

            guard let evaluation = evaluator.evaluate([activePlan]).first else {
                return nil
            }

            return CustomBaseAttackEvaluation(
                base: snapshot,
                evaluation: evaluation
            )
        }

        savedBasePlanAnalysis = SavedBasePlanAnalysis(
            plan: activePlan,
            entries: entries
        )
    }

    func analyzeCurrentPlanAcrossBases() {
        guard !isManualPlanning else { return }
        currentPlanAnalysis = makeRobustnessAnalysis(for: activePlan)
    }

    func rankSavedPlansAcrossBases() {
        guard !isManualPlanning else { return }

        var seenPlanIDs = Set<UUID>()
        let candidates = ([activePlan] + savedPlans).filter {
            seenPlanIDs.insert($0.id).inserted
        }
        let analyses = candidates.map { makeRobustnessAnalysis(for: $0) }
        robustnessRankings = AttackPlanRobustnessRanker.rank(analyses)
    }

    /// Runs the automatically generated plans against every prototype base.
    ///
    /// Unlike the normal finder, this does not optimize only the base currently
    /// on screen. The result is a robustness tournament that exposes strategies
    /// which remain effective when the layout changes.
    func rankGeneratedPlansAcrossBases() {
        guard !isManualPlanning else {
            return
        }

        let analyses = candidatePlans.map { makeRobustnessAnalysis(for: $0) }
        generatedPlanRankings = AttackPlanRobustnessRanker.rank(analyses)
    }

    func loadGeneratedPlan(_ plan: AttackPlan) {
        loadSavedPlan(plan)
        currentPlanAnalysis = makeRobustnessAnalysis(for: plan)
    }

    /// Searches lane and deployment-tempo variants of the active plan.
    ///
    /// Each candidate is tested on every available prototype base before the
    /// deterministic ranking chooses the recommendation.
    func refineCurrentPlanAcrossBases() {
        guard !isManualPlanning else {
            return
        }

        let variants = AttackPlanRefiner(
            navigationGrid: navigationGrid
        ).variants(for: activePlan)
        let analyses = variants.map { makeRobustnessAnalysis(for: $0) }

        refinementReport = AttackPlanRefinementReport(
            sourcePlan: activePlan,
            rankedCandidates: AttackPlanRobustnessRanker.rank(analyses)
        )
    }

    func loadRefinedPlan(_ plan: AttackPlan) {
        loadSavedPlan(plan)
    }


    private func makeGuidedCandidatePlans(
        for configuration: ArmyConfiguration,
        entities: [BattleEntity],
        baseName: String
    ) -> (plans: [AttackPlan], advice: ArmyEntryAdvice) {
        let advice = ArmyEntryAdvisor(
            navigationGrid: navigationGrid,
            gameData: gameData
        ).analyze(
            entities: entities,
            armyConfiguration: configuration,
            baseName: baseName
        )
        let plans = AttackPlanGenerator(
            navigationGrid: navigationGrid,
            armyConfiguration: configuration,
            entryAdvice: advice
        ).generate()

        return (plans, advice)
    }

    private func makeRobustnessAnalysis(
        for plan: AttackPlan
    ) -> AttackPlanRobustnessAnalysis {
        let entries: [BaseAttackEvaluation] =
            PrototypeBaseLayout.allCases.compactMap {
                layout -> BaseAttackEvaluation? in
                let entities = PrototypeBattleMap.makeBaseEntities(
                    navigationGrid: navigationGrid,
                    layout: layout
                )
                let layoutEvaluator = AttackPlanEvaluator(
                    baseEntities: entities,
                    gameData: gameData,
                    navigationGrid: navigationGrid
                )

                guard let evaluation = layoutEvaluator.evaluate([plan]).first else {
                    return nil
                }

                return BaseAttackEvaluation(
                    layout: layout,
                    evaluation: evaluation
                )
            }

        return AttackPlanRobustnessAnalysis(
            plan: plan,
            entries: entries
        )
    }

    func clearAttackHistory() {
        historyStore.clear()
        attackHistory = historyStore.entries
    }

    var attackHistorySummary: AttackHistorySummary {
        AttackHistorySummary(entries: attackHistory)
    }

    /// Recreates a recent recorded battle using its original base and plan.
    ///
    /// Entries made by earlier versions are intentionally left available but
    /// cannot be replayed because they did not persist a plan snapshot.
    func replayHistoryEntry(_ entry: AttackHistoryEntry) {
        guard
            !isManualPlanning,
            let plan = entry.attackPlan
        else {
            return
        }

        if let snapshot = entry.baseSnapshot {
            applyImportedBase(snapshot)
        } else if let layout = entry.baseLayout {
            applyBaseLayout(layout)
        } else {
            return
        }

        loadSavedPlan(plan)
        scene.restartSimulation()
        scene.startSimulation()
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

        let guidance = makeGuidedCandidatePlans(
            for: configuration,
            entities: baseEntities,
            baseName: activeBaseSnapshot.name
        )

        guard let firstPlan = guidance.plans.first else {
            return
        }

        finishManualMode(restoreActivePlan: false)
        armyConfiguration = configuration
        armyEntryAdvice = guidance.advice
        candidatePlans = guidance.plans
        evaluations = []
        activePlan = firstPlan
        selectedPlanID = firstPlan.id
        resetManualDraft()
        scene.loadAttackPlan(firstPlan)
    }

    func applyBaseLayout(_ layout: PrototypeBaseLayout) {
        let entities = PrototypeBattleMap.makeBaseEntities(
            navigationGrid: navigationGrid,
            layout: layout
        )

        let guidance = makeGuidedCandidatePlans(
            for: armyConfiguration,
            entities: entities,
            baseName: layout.displayName
        )
        guard let initialPlan = guidance.plans.first else {
            return
        }

        finishManualMode(restoreActivePlan: false)
        baseLayout = layout
        activeBaseSnapshot = BaseSnapshot.make(
            from: layout,
            navigationGrid: navigationGrid
        )
        baseEntities = entities
        evaluator = AttackPlanEvaluator(
            baseEntities: entities,
            gameData: gameData,
            navigationGrid: navigationGrid
        )
        evaluations = []
        baseReconnaissance = nil
        armyEntryAdvice = guidance.advice
        candidatePlans = guidance.plans

        activePlan = initialPlan
        selectedPlanID = initialPlan.id
        resetManualDraft()
        scene.loadScenario(
            entities: entities,
            attackPlan: initialPlan
        )
    }

    /// Loads a validated JSON base as a live simulation scenario.
    func applyImportedBase(_ snapshot: BaseSnapshot) {
        guard !isManualPlanning, snapshot.isValid(on: navigationGrid) else {
            return
        }

        let entities = snapshot.makeEntities(
            navigationGrid: navigationGrid
        )
        guard !entities.isEmpty else {
            return
        }

        let guidance = makeGuidedCandidatePlans(
            for: armyConfiguration,
            entities: entities,
            baseName: snapshot.name
        )
        guard let initialPlan = guidance.plans.first else {
            return
        }

        finishManualMode(restoreActivePlan: false)
        activeBaseSnapshot = snapshot
        baseEntities = entities
        evaluations = []
        currentPlanAnalysis = nil
        baseReconnaissance = nil
        armyEntryAdvice = guidance.advice
        candidatePlans = guidance.plans

        evaluator = AttackPlanEvaluator(
            baseEntities: entities,
            gameData: gameData,
            navigationGrid: navigationGrid
        )

        activePlan = initialPlan
        selectedPlanID = initialPlan.id
        resetManualDraft()
        scene.loadScenario(
            entities: entities,
            attackPlan: initialPlan
        )
    }

    func saveBaseSnapshot(_ snapshot: BaseSnapshot) {
        guard snapshot.isValid(on: navigationGrid) else {
            return
        }

        baseLibrary.save(snapshot)
        savedBases = baseLibrary.bases
    }

    func loadSavedBase(_ snapshot: BaseSnapshot) {
        applyImportedBase(snapshot)
    }

    func deleteSavedBase(_ snapshot: BaseSnapshot) {
        baseLibrary.delete(snapshot)
        savedBases = baseLibrary.bases
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
