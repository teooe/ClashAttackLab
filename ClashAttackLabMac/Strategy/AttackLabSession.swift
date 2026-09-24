import Combine
import Foundation
import SpriteKit

final class AttackLabSession: ObservableObject {
    @Published private(set) var robustnessObjective: RobustnessObjective = .average

    func setRobustnessObjective(_ objective: RobustnessObjective) {
        robustnessObjective = objective
        robustnessRankings = AttackPlanRobustnessRanker.rank(
            robustnessRankings, objective: objective
        )
        generatedPlanRankings = AttackPlanRobustnessRanker.rank(
            generatedPlanRankings, objective: objective
        )
        savedBasePlanRankings = SavedBasePlanRanker.rank(
            savedBasePlanRankings, objective: objective
        )
        if let report = refinementReport {
            refinementReport = AttackPlanRefinementReport(
                sourcePlan: report.sourcePlan,
                rankedCandidates: AttackPlanRobustnessRanker.rank(
                    report.rankedCandidates, objective: objective
                )
            )
        }
    }

    @Published private(set) var isSearching = false
    @Published private(set) var searchTitle = ""
    @Published private(set) var searchCompleted = 0
    @Published private(set) var searchTotal = 0
    @Published private(set) var searchMessage = ""
    private var searchTask: Task<Void, Never>?
    private var searchID: UUID?

    func cancelSearch() {
        guard isSearching else { return }
        searchTask?.cancel()
        searchTask = nil
        searchID = nil
        isSearching = false
        searchMessage = "Ricerca annullata. I risultati precedenti restano disponibili."
    }

    private func startSearch(
        title: String, total: Int,
        operation: @escaping @MainActor () async throws -> Void
    ) {
        cancelSearch()
        let id = UUID()
        searchID = id
        isSearching = true
        searchTitle = title
        searchTotal = total
        searchCompleted = 0
        searchMessage = ""
        searchTask = Task { @MainActor [weak self] in
            do {
                try Task.checkCancellation()
                try await operation()
                guard let self, self.searchID == id else { return }
                self.searchCompleted = self.searchTotal
                self.searchMessage = "Ricerca completata."
            } catch is CancellationError {
                guard let self, self.searchID == id else { return }
                self.searchMessage = "Ricerca annullata."
            } catch {
                guard let self, self.searchID == id else { return }
                self.searchMessage = "Ricerca non completata: \(error.localizedDescription)"
            }
            guard let self, self.searchID == id else { return }
            self.isSearching = false
            self.searchTask = nil
            self.searchID = nil
        }
    }

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
    @Published private(set) var savedBasePlanRankings:
        [SavedBasePlanRobustnessAnalysis] = []
    @Published private(set) var baseStrategyBook: BaseStrategyBook?
    @Published private(set) var savedBaseStrategies:
        [BaseStrategyRecord] = []
    @Published private(set) var scenarioAnalysis:
        AttackPlanScenarioAnalysis?
    @Published private(set) var resilientPlanRankings:
        [ScenarioPlanRobustnessAnalysis] = []
    @Published private(set) var heroAbilityMessage =
        "Le abilità degli eroi sono pronte dopo il loro schieramento."
    @Published private(set) var lastSpellOptimization:
        SpellPlanOptimizationResult?
    @Published private(set) var gameDataSource: GameDataSource = .prototype
    @Published private(set) var gameDataError: String?

    @Published private(set) var scene: BattleScene

    var candidatePlanCount: Int {
        candidatePlans.count
    }

    func activateHeroAbility(for kind: BattleEntityKind) {
        cancelSearch()
        let definition = gameData.definition(for: kind)
        let stateBeforeActivation = scene.heroAbilityState(for: kind)

        if scene.activateHeroAbility(for: kind) {
            activePlan = scene.recordedAttackPlan
            heroAbilityMessage = "\(definition.heroAbility?.displayName ?? definition.displayName) attivata e registrata nel piano."
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
            .archerQueen,
            .wallWrecker,
            .stoneSlammer
        ].filter { armyConfiguration.troopCount(for: $0) > 0 }
    }

    var manualSpellChoices: [BattleSpellKind] {
        [.heal, .rage, .freeze, .lightning, .earthquake].filter {
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

    private var arena: BattleArena
    private var gameData: any GameDataProviding
    private var navigationGrid: NavigationGrid
    private var baseEntities: [BattleEntity]
    private var candidatePlans: [AttackPlan]
    private var evaluator: AttackPlanEvaluator
    private var activePlan: AttackPlan
    private let planLibrary = AttackPlanLibrary()
    private let historyStore = AttackHistoryStore()
    private let baseLibrary = BaseSnapshotLibrary()
    private let baseStrategyLibrary = BaseStrategyLibrary()

    init() {
        let arena = BattleArena.prototype
        let gameData = arena.gameData
        let navigationGrid = arena.navigationGrid
        let layout = PrototypeBaseLayout.fortress
        let baseEntities = arena.makeBaseEntities(layout: layout)
        let configuration = arena.defaultArmy
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
            entryAdvice: initialEntryAdvice,
            baseEntities: baseEntities,
            gameData: gameData,
            armyRules: arena.armyRules
        ).generate()
        let initialPlan = candidatePlans[0]

        self.armyConfiguration = configuration
        self.baseLayout = layout
        self.activeBaseSnapshot = arena.makeBaseSnapshot(layout: layout)
        self.arena = arena
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

        self.scene = Self.makeScene(
            arena: arena,
            entities: baseEntities,
            plan: initialPlan
        )
        self.selectedPlanID = initialPlan.id
        self.savedPlans = planLibrary.plans
        self.attackHistory = historyStore.entries
        self.savedBases = baseLibrary.bases
        self.savedBaseStrategies = baseStrategyLibrary.records
        self.armyEntryAdvice = initialEntryAdvice
        installSimulationFinishedHandler()
    }

    private static func makeScene(
        arena: BattleArena,
        entities: [BattleEntity],
        plan: AttackPlan
    ) -> BattleScene {
        BattleScene(
            size: arena.sceneSize,
            simulation: SimulationEngine(
                entities: entities,
                attackPlan: plan,
                gameData: arena.gameData,
                navigationGrid: arena.navigationGrid
            ),
            navigationGrid: arena.navigationGrid,
            attackPlan: plan
        )
    }

    private func installSimulationFinishedHandler() {
        scene.simulationFinishedHandler = { [weak self] result in
            guard let self else { return }
            self.lastSimulationResult = result
            self.historyStore.record(
                AttackHistoryEntry(
                    plan: self.scene.recordedAttackPlan,
                    result: result,
                    baseLayout: self.baseLayout,
                    baseSnapshot: self.activeBaseSnapshot
                )
            )
            self.attackHistory = self.historyStore.entries
        }
    }

    /// True while battles use the real map, statistics and army limits.
    var isRealArena: Bool {
        arena.isReal
    }

    var armyRules: ArmyCapacityRules {
        arena.armyRules
    }

    var defaultArmy: ArmyConfiguration {
        arena.defaultArmy
    }

    /// Stress-tests the current plan under three bounded prototype conditions.
    /// This is an explainable sensitivity check, not a probability claim.
    func analyzeCurrentPlanUnderScenarios() {
        guard !isManualPlanning else { return }
        resilientPlanRankings = []
        let plan = activePlan
        let entities = baseEntities
        let scenarios = PrototypeCombatScenario.allCases

        startSearch(
            title: "Stress test del piano",
            total: scenarios.count
        ) { [weak self] in
            guard let self else { return }
            var entries: [ScenarioAttackEvaluation] = []

            for scenario in scenarios {
                try Task.checkCancellation()
                let scenarioData = ScenarioAdjustedGameData(
                    base: self.gameData,
                    scenario: scenario
                )
                let evaluator = AttackPlanEvaluator(
                    baseEntities: entities,
                    gameData: scenarioData,
                    navigationGrid: self.navigationGrid
                )
                let results = try await evaluator.evaluateAsync([plan])
                try Task.checkCancellation()
                if let evaluation = results.first {
                    entries.append(
                        ScenarioAttackEvaluation(
                            scenario: scenario,
                            evaluation: evaluation
                        )
                    )
                }
                self.searchCompleted += 1
                await Task.yield()
            }

            self.scenarioAnalysis = AttackPlanScenarioAnalysis(
                plan: plan,
                entries: entries
            )
        }
    }

    /// Searches a bounded army/deploy set and ranks candidates by their
    /// weakest combat scenario before considering average performance.
    func findMostResilientArmyAndAttack() {
        guard !isManualPlanning else { return }
        let sourcePlan = activePlan
        let variants = ArmyCompositionSearch.variants(
            from: sourcePlan.armyConfiguration,
            rules: arena.armyRules
        )
        guard !variants.isEmpty else { return }
        let scenarios = PrototypeCombatScenario.allCases

        startSearch(
            title: "Ricerca piano resistente",
            total: 1 + variants.count * 12
        ) { [weak self] in
            guard let self else { return }
            var plans = [sourcePlan]

            for variant in variants {
                try Task.checkCancellation()
                let guidance = self.makeGuidedCandidatePlans(
                    for: variant.configuration,
                    entities: self.baseEntities,
                    baseName: self.activeBaseSnapshot.name
                )
                plans += guidance.plans.prefix(12).map {
                    self.plan(
                        $0,
                        named: "\(variant.name) · \($0.name)",
                        transferringHeroTimingFrom: sourcePlan
                    )
                }
                await Task.yield()
            }

            self.searchTotal = plans.count * scenarios.count
            var completed = 0
            var analyses: [ScenarioPlanRobustnessAnalysis] = []

            for plan in plans {
                try Task.checkCancellation()
                var entries: [ScenarioAttackEvaluation] = []

                for scenario in scenarios {
                    try Task.checkCancellation()
                    let evaluator = AttackPlanEvaluator(
                        baseEntities: self.baseEntities,
                        gameData: ScenarioAdjustedGameData(
                            base: self.gameData,
                            scenario: scenario
                        ),
                        navigationGrid: self.navigationGrid
                    )
                    let results = try await evaluator.evaluateAsync([plan])
                    try Task.checkCancellation()
                    if let evaluation = results.first {
                        entries.append(
                            ScenarioAttackEvaluation(
                                scenario: scenario,
                                evaluation: evaluation
                            )
                        )
                    }
                    completed += 1
                    self.searchCompleted = completed
                }

                analyses.append(
                    ScenarioPlanRobustnessAnalysis(
                        plan: plan,
                        entries: entries
                    )
                )
                await Task.yield()
            }

            self.resilientPlanRankings = ScenarioPlanRobustnessRanker.rank(
                analyses
            )
        }
    }

    func loadResilientPlan(_ analysis: ScenarioPlanRobustnessAnalysis) {
        guard let evaluation = analysis.neutralEvaluation ??
            analysis.entries.first?.evaluation else {
            return
        }
        applyEvaluationSelection(evaluation)
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
    /// Tests generated army/deploy candidates against the active base and all
    /// compatible bases saved locally. No remote data leaves the Mac.
    func findReliableArmyAndAttackAcrossSavedBases() {
        guard !isManualPlanning else { return }
        let sourcePlan = activePlan
        let bases = comparableSavedBases()
        guard !bases.isEmpty else { return }
        let variants = ArmyCompositionSearch.variants(
            from: sourcePlan.armyConfiguration,
            rules: arena.armyRules
        )
        guard !variants.isEmpty else { return }

        startSearch(
            title: "Ricerca affidabile su basi locali",
            total: 1 + variants.count * 24
        ) { [weak self] in
            guard let self else { return }
            var plans = [sourcePlan]
            for variant in variants {
                try Task.checkCancellation()
                let guidance = self.makeGuidedCandidatePlans(
                    for: variant.configuration,
                    entities: self.baseEntities,
                    baseName: self.activeBaseSnapshot.name
                )
                plans += guidance.plans.map {
                    self.plan(
                        $0,
                        named: "\(variant.name) · \($0.name)",
                        transferringHeroTimingFrom: sourcePlan
                    )
                }
                await Task.yield()
            }
            self.searchTotal = plans.count * bases.count
            let analyses = try await self.analyze(
                plans: plans, across: bases
            )
            try Task.checkCancellation()
            self.savedBasePlanRankings = SavedBasePlanRanker.rank(
                analyses, objective: self.robustnessObjective
            )
            if let winner = self.savedBasePlanRankings.first {
                self.applyReliableSavedBasePlan(winner)
            }
        }
    }


    /// Builds a separate recommendation for every compatible local/imported
    /// base. Candidate generation adapts to each base layout before evaluation.
    func findBestAttackForEachSavedBase() {
        guard !isManualPlanning else { return }
        let sourcePlan = activePlan
        let bases = comparableSavedBases()
        let variants = ArmyCompositionSearch.variants(
            from: sourcePlan.armyConfiguration,
            rules: arena.armyRules
        )
        guard !bases.isEmpty, !variants.isEmpty else { return }

        startSearch(
            title: "Strategie personalizzate per le basi",
            total: bases.count * (1 + variants.count * 18)
        ) { [weak self] in
            guard let self else { return }
            var candidateSets: [(BaseSnapshot, [AttackPlan])] = []

            for base in bases {
                try Task.checkCancellation()
                let entities = base.makeEntities(
                    navigationGrid: self.navigationGrid
                )
                var plans = [sourcePlan]
                for variant in variants {
                    try Task.checkCancellation()
                    let guidance = self.makeGuidedCandidatePlans(
                        for: variant.configuration,
                        entities: entities,
                        baseName: base.name
                    )
                    plans += guidance.plans.prefix(18).map {
                        self.plan(
                            $0,
                            named: "\(variant.name) · \($0.name)",
                            transferringHeroTimingFrom: sourcePlan
                        )
                    }
                    await Task.yield()
                }
                candidateSets.append((base, plans))
            }

            self.searchTotal = candidateSets.reduce(0) { total, item in
                total + item.1.count
            }
            var completed = 0
            var recommendations: [BaseStrategyRecommendation] = []

            for (base, plans) in candidateSets {
                try Task.checkCancellation()
                let evaluator = AttackPlanEvaluator(
                    baseEntities: base.makeEntities(
                        navigationGrid: self.navigationGrid
                    ),
                    gameData: self.gameData,
                    navigationGrid: self.navigationGrid
                )
                let results = try await evaluator.evaluateAsync(plans) {
                    self.searchCompleted = completed + $0
                }
                try Task.checkCancellation()
                if let evaluation = results.first {
                    recommendations.append(
                        BaseStrategyRecommendation(
                            base: base,
                            evaluation: evaluation,
                            candidateCount: plans.count
                        )
                    )
                }
                completed += plans.count
                self.searchCompleted = completed
                await Task.yield()
            }

            self.baseStrategyBook = BaseStrategyBook(
                recommendations: recommendations
            )
            self.baseStrategyLibrary.save(
                recommendations.map { BaseStrategyRecord(recommendation: $0) }
            )
            self.savedBaseStrategies = self.baseStrategyLibrary.records
        }
    }

    /// Reopens a durable recommendation from the local strategy archive.
    func loadSavedBaseStrategy(_ record: BaseStrategyRecord) {
        guard !isManualPlanning else { return }
        applyImportedBase(record.base)
        loadSavedPlan(record.plan)
    }

    func deleteSavedBaseStrategy(_ record: BaseStrategyRecord) {
        baseStrategyLibrary.delete(record)
        savedBaseStrategies = baseStrategyLibrary.records
    }

    func clearSavedBaseStrategies() {
        baseStrategyLibrary.clear()
        savedBaseStrategies = []
    }

    /// Opens the base first, then applies the plan created specifically for it.
    func loadBaseStrategy(_ recommendation: BaseStrategyRecommendation) {
        guard !isManualPlanning else { return }
        applyImportedBase(recommendation.base)
        applyEvaluationSelection(recommendation.evaluation)
    }

    func loadReliableSavedBasePlan(
        _ analysis: SavedBasePlanRobustnessAnalysis
    ) {
        guard let evaluation = analysis.entries.first(
            where: { $0.base.id == activeBaseSnapshot.id }
        )?.evaluation ?? analysis.entries.first?.evaluation else {
            return
        }
        applyEvaluationSelection(evaluation)
    }

    private func applyReliableSavedBasePlan(
        _ analysis: SavedBasePlanRobustnessAnalysis
    ) {
        loadReliableSavedBasePlan(analysis)
    }

    private func comparableSavedBases() -> [BaseSnapshot] {
        // Saved bases are drawn on the prototype grid.
        guard !arena.isReal else { return [] }
        var seen = Set<UUID>()
        return ([activeBaseSnapshot] + savedBases).filter {
            seen.insert($0.id).inserted && $0.isValid(on: navigationGrid)
        }
    }

    private func analyze(
        plans: [AttackPlan],
        across bases: [BaseSnapshot]
    ) async throws -> [SavedBasePlanRobustnessAnalysis] {
        var analyses: [SavedBasePlanRobustnessAnalysis] = []
        for plan in plans {
            try Task.checkCancellation()
            var entries: [CustomBaseAttackEvaluation] = []
            for base in bases {
                try Task.checkCancellation()
                let evaluator = AttackPlanEvaluator(
                    baseEntities: base.makeEntities(navigationGrid: navigationGrid),
                    gameData: gameData, navigationGrid: navigationGrid
                )
                let results = try await evaluator.evaluateAsync([plan])
                try Task.checkCancellation()
                guard let evaluation = results.first else {
                    throw AttackPlanEvaluator.EvaluationError.incompleteSimulation
                }
                entries.append(
                    CustomBaseAttackEvaluation(base: base, evaluation: evaluation)
                )
                searchCompleted += 1
            }
            analyses.append(
                SavedBasePlanRobustnessAnalysis(plan: plan, entries: entries)
            )
            await Task.yield()
        }
        return analyses
    }

    private func plan(
        _ source: AttackPlan,
        named name: String,
        transferringHeroTimingFrom original: AttackPlan
    ) -> AttackPlan {
        AttackPlan(
            name: name,
            deployments: source.deployments,
            spellDeployments: source.spellDeployments,
            heroAbilityOrders: source.deployments.compactMap { deployment in
                guard let originalDeployment = original.deployments.first(
                    where: { $0.kind == deployment.kind }
                ), let command = original.heroAbilityOrders.first(
                    where: { $0.entityID == originalDeployment.entityID }
                ) else { return nil }
                return HeroAbilityOrder(
                    entityID: deployment.entityID,
                    activationTime: min(
                        59,
                        max(
                            deployment.deploymentTime,
                            deployment.deploymentTime +
                                command.activationTime -
                                originalDeployment.deploymentTime
                        )
                    )
                )
            }
        )
    }

    func analyzeCurrentPlanAcrossSavedBases() {
        guard !isManualPlanning, !arena.isReal else { return }
        let plan = activePlan
        var seen = Set<UUID>()
        let bases = ([activeBaseSnapshot] + savedBases).filter {
            seen.insert($0.id).inserted && $0.isValid(on: navigationGrid)
        }
        startSearch(title: "Analisi basi salvate", total: bases.count) { [weak self] in
            guard let self else { return }
            var entries: [CustomBaseAttackEvaluation] = []
            for snapshot in bases {
                try Task.checkCancellation()
                let evaluator = AttackPlanEvaluator(
                    baseEntities: snapshot.makeEntities(navigationGrid: self.navigationGrid),
                    gameData: self.gameData, navigationGrid: self.navigationGrid
                )
                let results = try await evaluator.evaluateAsync([plan])
                try Task.checkCancellation()
                if let evaluation = results.first {
                    entries.append(CustomBaseAttackEvaluation(base: snapshot, evaluation: evaluation))
                }
                self.searchCompleted += 1
            }
            self.savedBasePlanAnalysis = SavedBasePlanAnalysis(plan: plan, entries: entries)
        }
    }

    func analyzeCurrentPlanAcrossBases() {
        guard !isManualPlanning else { return }
        let plan = activePlan
        startSearch(title: "Analisi su più basi", total: PrototypeBaseLayout.allCases.count) { [weak self] in
            guard let self else { return }
            let result = try await self.makeRobustnessAnalysis(for: plan)
            try Task.checkCancellation()
            self.currentPlanAnalysis = result
        }
    }

    func rankSavedPlansAcrossBases() {
        guard !isManualPlanning else { return }
        var seen = Set<UUID>()
        let plans = ([activePlan] + savedPlans).filter { seen.insert($0.id).inserted }
        startSearch(title: "Classifica piani salvati", total: plans.count * PrototypeBaseLayout.allCases.count) { [weak self] in
            guard let self else { return }
            let results = try await self.analyzePlans(plans)
            try Task.checkCancellation()
            self.robustnessRankings = results
        }
    }

    /// Runs the automatically generated plans against every prototype base.
    ///
    /// Unlike the normal finder, this does not optimize only the base currently
    /// on screen. The result is a robustness tournament that exposes strategies
    /// which remain effective when the layout changes.
    func rankGeneratedPlansAcrossBases() {
        guard !isManualPlanning else { return }
        let plans = candidatePlans
        startSearch(title: "Torneo strategie", total: plans.count * PrototypeBaseLayout.allCases.count) { [weak self] in
            guard let self else { return }
            let results = try await self.analyzePlans(plans)
            try Task.checkCancellation()
            self.generatedPlanRankings = results
        }
    }

    func loadGeneratedPlan(_ plan: AttackPlan) {
        loadSavedPlan(plan)
        analyzeCurrentPlanAcrossBases()
    }

    /// Searches lane and deployment-tempo variants of the active plan.
    ///
    /// Each candidate is tested on every available prototype base before the
    /// deterministic ranking chooses the recommendation.
    func refineCurrentPlanAcrossBases() {
        guard !isManualPlanning else { return }
        let plan = activePlan
        let variants = AttackPlanRefiner(navigationGrid: navigationGrid).variants(for: plan)
        startSearch(title: "Ottimizzazione", total: variants.count * PrototypeBaseLayout.allCases.count) { [weak self] in
            guard let self else { return }
            let results = try await self.analyzePlans(variants)
            try Task.checkCancellation()
            self.refinementReport = AttackPlanRefinementReport(
                sourcePlan: plan, rankedCandidates: results
            )
        }
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
            entryAdvice: advice,
            baseEntities: entities,
            gameData: gameData,
            armyRules: arena.armyRules
        ).generate()

        return (plans, advice)
    }

    private func makeRobustnessAnalysis(
        for plan: AttackPlan
    ) async throws -> AttackPlanRobustnessAnalysis {
        var entries: [BaseAttackEvaluation] = []
        for layout in PrototypeBaseLayout.allCases {
            try Task.checkCancellation()
            let entities = arena.makeBaseEntities(layout: layout)
            let evaluator = AttackPlanEvaluator(
                baseEntities: entities, gameData: gameData,
                navigationGrid: navigationGrid
            )
            let results = try await evaluator.evaluateAsync([plan])
            try Task.checkCancellation()
            if let evaluation = results.first {
                entries.append(BaseAttackEvaluation(layout: layout, evaluation: evaluation))
            }
            searchCompleted += 1
        }
        return AttackPlanRobustnessAnalysis(plan: plan, entries: entries)
    }

    private func analyzePlans(
        _ plans: [AttackPlan]
    ) async throws -> [AttackPlanRobustnessAnalysis] {
        var results: [AttackPlanRobustnessAnalysis] = []
        for plan in plans {
            results.append(try await makeRobustnessAnalysis(for: plan))
        }
        try Task.checkCancellation()
        return AttackPlanRobustnessRanker.rank(results, objective: robustnessObjective)
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

        if arena.isReal {
            guard let layout = entry.baseLayout else { return }
            applyBaseLayout(layout)
        } else if let snapshot = entry.baseSnapshot {
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
        guard !isManualPlanning else { return }
        let evaluator = self.evaluator
        startSearch(title: "Confronto piani", total: plans.count) { [weak self] in
            guard let self else { return }
            let results = try await evaluator.evaluateAsync(plans) {
                self.searchCompleted = $0
            }
            try Task.checkCancellation()
            self.comparisonEvaluations = results
        }
    }

    func exportAttackPlans(_ plans: [AttackPlan]) throws -> Data {
        try AttackPlanArchiveCodec.encode(plans, on: navigationGrid)
    }

    @discardableResult
    func importAttackPlans(_ data: Data) throws -> Int {
        let count = try planLibrary.importArchive(data, on: navigationGrid)
        savedPlans = planLibrary.plans
        return count
    }

    func saveCurrentPlan() {
        planLibrary.save(activePlan)
        savedPlans = planLibrary.plans
    }

    func loadSavedPlan(_ plan: AttackPlan) {
        cancelSearch()
        guard !isManualPlanning else { return }
        if plan.armyConfiguration.isValid(under: arena.armyRules) &&
            plan.armyConfiguration != armyConfiguration {
            applyArmyConfiguration(plan.armyConfiguration)
        }
        activePlan = plan
        selectedPlanID = plan.id
        evaluations = []
        scenarioAnalysis = nil
        resilientPlanRankings = []
        lastSimulationResult = nil
        scenarioAnalysis = nil
        scene.loadAttackPlan(plan)
    }

    func editSavedPlan(_ plan: AttackPlan) {
        cancelSearch()
        guard !isManualPlanning else { return }

        loadSavedPlan(plan)
        manualPlan = ManualAttackPlan(
            id: plan.id,
            name: plan.name,
            deployments: plan.deployments,
            spellDeployments: plan.spellDeployments,
            heroAbilityOrders: plan.heroAbilityOrders
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
        guard !isManualPlanning else { return }
        let plans = candidatePlans
        let evaluator = self.evaluator
        startSearch(title: "Ricerca attacco", total: plans.count) { [weak self] in
            guard let self else { return }
            let results = try await evaluator.evaluateAsync(plans) {
                self.searchCompleted = $0
            }
            try Task.checkCancellation()
            self.evaluations = results
            if let best = results.first {
                self.applyEvaluationSelection(best)
            }
        }
    }

    /// Search equal-capacity armies against the active base, using the same
    /// formation matrix for each. Keep the user's current plan as baseline.
    func findBestArmyAndAttack() {
        guard !isManualPlanning else { return }
        let sourcePlan = activePlan
        let sourceArmy = sourcePlan.armyConfiguration
        let variants = ArmyCompositionSearch.variants(
            from: sourceArmy,
            rules: arena.armyRules
        )
        guard !variants.isEmpty else { return }
        let evaluator = self.evaluator
        startSearch(
            title: "Ricerca eserciti e deploy",
            total: 1 + variants.count * 30
        ) { [weak self] in
            guard let self else { return }
            var plans = [sourcePlan]
            for variant in variants {
                try Task.checkCancellation()
                let guidance = self.makeGuidedCandidatePlans(
                    for: variant.configuration,
                    entities: self.baseEntities,
                    baseName: self.activeBaseSnapshot.name
                )
                plans += guidance.plans.map { plan in
                    AttackPlan(
                        name: "\(variant.name) · \(plan.name)",
                        deployments: plan.deployments,
                        spellDeployments: plan.spellDeployments,
                        heroAbilityOrders: plan.deployments.compactMap { deployment in
                            guard let original = sourcePlan.deployments.first(where: {
                                $0.kind == deployment.kind
                            }), let command = sourcePlan.heroAbilityOrders.first(where: {
                                $0.entityID == original.entityID
                            }) else { return nil }
                            return HeroAbilityOrder(
                                entityID: deployment.entityID,
                                activationTime: min(59, max(deployment.deploymentTime,
                                    deployment.deploymentTime + command.activationTime -
                                        original.deploymentTime))
                            )
                        }
                    )
                }
                await Task.yield()
            }
            try Task.checkCancellation()
            self.searchTotal = plans.count
            let results = try await evaluator.evaluateAsync(plans) {
                self.searchCompleted = $0
            }
            try Task.checkCancellation()
            self.evaluations = results
            if let best = results.first {
                self.applyEvaluationSelection(best)
            }
        }
    }

    private func applyEvaluationSelection(_ evaluation: AttackPlanEvaluation) {
        let configuration = evaluation.plan.armyConfiguration
        if configuration.isValid(under: arena.armyRules) &&
            configuration != armyConfiguration {
            let guidance = makeGuidedCandidatePlans(
                for: configuration, entities: baseEntities,
                baseName: activeBaseSnapshot.name
            )
            armyConfiguration = configuration
            armyEntryAdvice = guidance.advice
            candidatePlans = guidance.plans
            resetManualDraft()
        }
        activePlan = evaluation.plan
        selectedPlanID = evaluation.plan.id
        lastSimulationResult = nil
        scenarioAnalysis = nil
        scene.loadAttackPlan(evaluation.plan)
    }

    func applyArmyConfiguration(
        _ configuration: ArmyConfiguration
    ) {
        cancelSearch()
        guard configuration.isValid(under: arena.armyRules) else {
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
        scenarioAnalysis = nil
        activePlan = firstPlan
        selectedPlanID = firstPlan.id
        resetManualDraft()
        scene.loadAttackPlan(firstPlan)
    }

    /// Switches between the prototype lab and a real battle at a Town Hall
    /// (real map, statistics and army limits), then rebuilds the base,
    /// plans, analyses and battle scene.
    func applyGameDataSource(_ source: GameDataSource) {
        guard source != gameDataSource, !isManualPlanning else {
            return
        }

        let newArena: BattleArena
        do {
            newArena = try BattleArena.make(for: source)
        } catch {
            gameDataError =
                "Dati reali non disponibili: \(error.localizedDescription)"
            return
        }

        cancelSearch()
        let keepsArmy = newArena.isReal == arena.isReal &&
            armyConfiguration.isValid(under: newArena.armyRules)
        let configuration = keepsArmy
            ? armyConfiguration
            : newArena.defaultArmy
        let entities = newArena.makeBaseEntities(layout: baseLayout)

        arena = newArena
        gameData = newArena.gameData
        navigationGrid = newArena.navigationGrid
        gameDataSource = source
        gameDataError = nil
        armyConfiguration = configuration
        baseEntities = entities
        activeBaseSnapshot = newArena.makeBaseSnapshot(layout: baseLayout)
        evaluator = AttackPlanEvaluator(
            baseEntities: entities,
            gameData: gameData,
            navigationGrid: navigationGrid
        )

        let guidance = makeGuidedCandidatePlans(
            for: configuration,
            entities: entities,
            baseName: activeBaseSnapshot.name
        )
        armyEntryAdvice = guidance.advice
        candidatePlans = guidance.plans
        if let firstPlan = guidance.plans.first {
            activePlan = firstPlan
            selectedPlanID = firstPlan.id
        }
        resetManualDraft()

        evaluations = []
        comparisonEvaluations = []
        lastSimulationResult = nil
        currentPlanAnalysis = nil
        robustnessRankings = []
        refinementReport = nil
        generatedPlanRankings = []
        baseReconnaissance = nil
        savedBasePlanAnalysis = nil
        savedBasePlanRankings = []
        baseStrategyBook = nil
        scenarioAnalysis = nil
        resilientPlanRankings = []
        lastSpellOptimization = nil

        scene = Self.makeScene(
            arena: newArena,
            entities: entities,
            plan: activePlan
        )
        installSimulationFinishedHandler()
    }

    func applyBaseLayout(_ layout: PrototypeBaseLayout) {
        cancelSearch()
        let entities = arena.makeBaseEntities(layout: layout)

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
        activeBaseSnapshot = arena.makeBaseSnapshot(layout: layout)
        baseEntities = entities
        evaluator = AttackPlanEvaluator(
            baseEntities: entities,
            gameData: gameData,
            navigationGrid: navigationGrid
        )
        evaluations = []
        scenarioAnalysis = nil
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
        cancelSearch()
        guard
            !isManualPlanning,
            !arena.isReal,
            snapshot.isValid(on: navigationGrid)
        else {
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
        scenarioAnalysis = nil
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
        cancelSearch()
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
        scenarioAnalysis = nil
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

    func setManualHeroAbilityTime(entityID: UUID, to time: TimeInterval) {
        guard isManualPlanning else { return }
        manualPlan.setHeroAbilityTime(entityID: entityID, to: time)
        scene.loadAttackPlan(manualPlan.makeAttackPlan())
    }

    func removeManualHeroAbility(entityID: UUID) {
        guard isManualPlanning else { return }
        manualPlan.removeHeroAbility(entityID: entityID)
        scene.loadAttackPlan(manualPlan.makeAttackPlan())
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
        cancelSearch()
        guard !isManualPlanning else {
            return
        }

        applyEvaluationSelection(evaluation)
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


extension AttackLabSession {
    var currentSpellImpactAnalysis: SpellImpactAnalysis {
        SpellImpactAnalyzer(gameData: gameData).analyze(
            plan: activePlan,
            entities: baseEntities
        )
    }
}


extension AttackLabSession {
    func optimizeCurrentPlanSpells() {
        cancelSearch()
        guard !isManualPlanning else { return }
        let result = OffensiveSpellPlanOptimizer(
            navigationGrid: navigationGrid,
            gameData: gameData
        ).optimize(plan: activePlan, entities: baseEntities)
        lastSpellOptimization = result
        guard result.movedCastCount > 0 else { return }
        loadSavedPlan(result.optimizedPlan)
    }
}
