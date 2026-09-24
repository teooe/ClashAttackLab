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

    /// Evaluates plans in parallel on every CPU core. Each battle runs in
    /// its own deterministic engine, so results do not depend on scheduling;
    /// they are reported in the original order before ranking.
    func evaluateAsync(
        _ plans: [AttackPlan],
        progress: (Int) -> Void = { _ in }
    ) async throws -> [AttackPlanEvaluation] {
        try Task.checkCancellation()
        progress(0)
        let jobs = plans.map {
            ParallelBattleRunner.Job(
                entities: baseEntities,
                plan: $0,
                gameData: gameData,
                navigationGrid: navigationGrid
            )
        }
        let results = try await ParallelBattleRunner.run(jobs, progress: progress)
        try Task.checkCancellation()
        var evaluations: [AttackPlanEvaluation] = []
        for (plan, result) in zip(plans, results) {
            guard let result else {
                throw EvaluationError.incompleteSimulation
            }
            evaluations.append(AttackPlanEvaluation(plan: plan, result: result))
        }
        return evaluations.sorted(by: isBetter)
    }

    enum EvaluationError: Error {
        case incompleteSimulation
    }

    private func evaluate(
        _ plan: AttackPlan
    ) -> AttackPlanEvaluation? {
        ParallelBattleRunner.simulate(
            ParallelBattleRunner.Job(
                entities: baseEntities,
                plan: plan,
                gameData: gameData,
                navigationGrid: navigationGrid
            )
        ).map {
            AttackPlanEvaluation(plan: plan, result: $0)
        }
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

        if
            first.result.metrics.damageToBase !=
            second.result.metrics.damageToBase
        {
            return first.result.metrics.damageToBase >
                second.result.metrics.damageToBase
        }

        if first.result.metrics.troopsLost != second.result.metrics.troopsLost {
            return first.result.metrics.troopsLost <
                second.result.metrics.troopsLost
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


/// Bounded prototype conditions used to stress-test a strategy. They model
/// tuning uncertainty, not official game modes or real matchmaking variance.
nonisolated enum PrototypeCombatScenario: String, CaseIterable, Identifiable {
    case neutral
    case attackerFavored
    case defenseFavored

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neutral: return "Neutra"
        case .attackerFavored: return "Attacco +10%"
        case .defenseFavored: return "Difese +10%"
        }
    }

    var explanation: String {
        switch self {
        case .neutral:
            return "Valori sintetici di riferimento."
        case .attackerFavored:
            return "Vita e danno delle truppe aumentati del 10%."
        case .defenseFavored:
            return "Vita e danno di difese, edifici e muri aumentati del 10%."
        }
    }

    var troopMultiplier: Double {
        self == .attackerFavored ? 1.1 :
            self == .defenseFavored ? 0.9 : 1
    }

    var baseMultiplier: Double {
        self == .defenseFavored ? 1.1 :
            self == .attackerFavored ? 0.9 : 1
    }
}

/// Runs complete headless battles, spreading independent jobs over every
/// CPU core. Results come back in job order, so rankings stay deterministic.
nonisolated enum ParallelBattleRunner {
    /// Immutable inputs of one battle. Every field is a value that is never
    /// mutated after creation, so sharing it between tasks is safe.
    nonisolated struct Job: @unchecked Sendable {
        let entities: [BattleEntity]
        let plan: AttackPlan
        let gameData: any GameDataProviding
        let navigationGrid: NavigationGrid
    }

    nonisolated private struct Outcome: @unchecked Sendable {
        let index: Int
        let result: SimulationResult?
    }

    /// Simulated seconds per engine step.
    static let stepDuration: TimeInterval = 0.25

    static var workerCount: Int {
        max(1, ProcessInfo.processInfo.activeProcessorCount)
    }

    /// Runs `jobs` concurrently, at most one per core, and calls `progress`
    /// with the number of finished battles. A nil entry means the battle
    /// did not finish within its time limit.
    ///
    /// Coordination and `progress` stay on the caller's actor; only the
    /// battles themselves run on background threads.
    static func run(
        _ jobs: [Job],
        isolation: isolated (any Actor)? = #isolation,
        progress: (Int) -> Void = { _ in }
    ) async throws -> [SimulationResult?] {
        guard !jobs.isEmpty else {
            return []
        }

        var results = [SimulationResult?](repeating: nil, count: jobs.count)
        var completed = 0

        try await withThrowingTaskGroup(of: Outcome.self) { group in
            var nextIndex = 0

            func enqueueNext() {
                guard nextIndex < jobs.count else {
                    return
                }
                let index = nextIndex
                let job = jobs[index]
                nextIndex += 1
                group.addTask {
                    try Task.checkCancellation()
                    return Outcome(index: index, result: simulate(job))
                }
            }

            for _ in 0..<min(workerCount, jobs.count) {
                enqueueNext()
            }

            while let outcome = try await group.next() {
                results[outcome.index] = outcome.result
                completed += 1
                progress(completed)
                try Task.checkCancellation()
                enqueueNext()
            }
        }

        return results
    }

    /// Plays one battle to the end; nil if it is cancelled or never ends.
    static func simulate(_ job: Job) -> SimulationResult? {
        let engine = SimulationEngine(
            entities: job.entities,
            attackPlan: job.plan,
            gameData: job.gameData,
            navigationGrid: job.navigationGrid
        )
        engine.start()

        // A small margin past the time limit lets the engine report the end.
        let maximumSteps = Int(
            (job.gameData.battleDuration / stepDuration).rounded(.up)
        ) + 20

        for step in 0..<maximumSteps {
            if case .finished(let result) = engine.status {
                return result
            }
            if step.isMultiple(of: 16), Task.isCancelled {
                return nil
            }
            engine.advance(by: stepDuration)
        }

        if case .finished(let result) = engine.status {
            return result
        }
        return nil
    }
}

/// Decorates the versioned prototype data without touching the deterministic
/// engine. Spells and target-selection rules remain unchanged.
nonisolated struct ScenarioAdjustedGameData: GameDataProviding {
    let base: any GameDataProviding
    let scenario: PrototypeCombatScenario

    func definition(for kind: BattleEntityKind) -> CombatDefinition {
        let definition = base.definition(for: kind)
        let multiplier: Double

        switch definition.role {
        case .troop:
            multiplier = scenario.troopMultiplier
        case .defense, .building, .wall, .trap:
            multiplier = scenario.baseMultiplier
        }

        return CombatDefinition(
            displayName: definition.displayName,
            role: definition.role,
            maxHitPoints: definition.maxHitPoints * multiplier,
            movementSpeed: definition.movementSpeed,
            attackDamage: definition.attackDamage * multiplier,
            damageMultiplierAgainstWalls: definition.damageMultiplierAgainstWalls,
            minimumAttackRange: definition.minimumAttackRange,
            attackRange: definition.attackRange,
            attackInterval: definition.attackInterval,
            canMove: definition.canMove,
            projectileKind: definition.projectileKind,
            projectileSpeed: definition.projectileSpeed,
            splashRadius: definition.splashRadius,
            selfDestructsOnAttack: definition.selfDestructsOnAttack,
            damageRampMultipliers: definition.damageRampMultipliers,
            destructionDamage: definition.destructionDamage,
            destructionRadius: definition.destructionRadius,
            destructionTargetLayer: definition.destructionTargetLayer,
            startsHidden: definition.startsHidden,
            activationRange: definition.activationRange,
            pushbackDistance: definition.pushbackDistance,
            movementDomain: definition.movementDomain,
            attackTargetLayer: definition.attackTargetLayer,
            targetingProfile: definition.targetingProfile,
            heroAbility: definition.heroAbility,
            siegePayload: definition.siegePayload,
            footprintSize: definition.footprintSize
        )
    }

    func spellDefinition(for kind: BattleSpellKind) -> SpellDefinition {
        base.spellDefinition(for: kind)
    }

    var battleDuration: TimeInterval {
        base.battleDuration
    }
}

nonisolated struct ScenarioAttackEvaluation: Identifiable {
    let scenario: PrototypeCombatScenario
    let evaluation: AttackPlanEvaluation

    var id: PrototypeCombatScenario { scenario }
}

nonisolated struct AttackPlanScenarioAnalysis {
    let plan: AttackPlan
    let entries: [ScenarioAttackEvaluation]

    var averageStars: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map { Double($0.evaluation.stars) }
            .reduce(0, +) / Double(entries.count)
    }

    var averageDestruction: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map(\.evaluation.destructionPercentage)
            .reduce(0, +) / Double(entries.count)
    }

    var worstCase: ScenarioAttackEvaluation? {
        entries.min {
            if $0.evaluation.stars != $1.evaluation.stars {
                return $0.evaluation.stars < $1.evaluation.stars
            }
            return $0.evaluation.destructionPercentage <
                $1.evaluation.destructionPercentage
        }
    }

    var isThreeStarStable: Bool {
        !entries.isEmpty && entries.allSatisfy {
            $0.evaluation.stars == 3
        }
    }

    var stabilityLabel: String {
        if isThreeStarStable {
            return "Tripla stabile"
        }
        guard let worstCase else { return "Nessun dato" }
        return "Caso peggiore: \(worstCase.evaluation.stars)★"
    }
}


/// One candidate evaluated under every bounded combat scenario. This is
/// separate from cross-base robustness: here the base stays fixed.
nonisolated struct ScenarioPlanRobustnessAnalysis: Identifiable {
    let plan: AttackPlan
    let entries: [ScenarioAttackEvaluation]

    var id: UUID { plan.id }

    var averageStars: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map { Double($0.evaluation.stars) }
            .reduce(0, +) / Double(entries.count)
    }

    var averageDestruction: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map(\.evaluation.destructionPercentage)
            .reduce(0, +) / Double(entries.count)
    }

    var averageSurvivors: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map {
            Double($0.evaluation.result.survivingTroops)
        }.reduce(0, +) / Double(entries.count)
    }

    var worstEntry: ScenarioAttackEvaluation? {
        entries.min {
            if $0.evaluation.stars != $1.evaluation.stars {
                return $0.evaluation.stars < $1.evaluation.stars
            }
            return $0.evaluation.destructionPercentage <
                $1.evaluation.destructionPercentage
        }
    }

    var neutralEvaluation: AttackPlanEvaluation? {
        entries.first(where: { $0.scenario == .neutral })?.evaluation
    }

    var isThreeStarStable: Bool {
        !entries.isEmpty && entries.allSatisfy {
            $0.evaluation.stars == 3
        }
    }
}

/// Orders plans primarily by their worst plausible prototype condition.
/// It avoids choosing a fragile high-average plan over a steadier alternative.
nonisolated enum ScenarioPlanRobustnessRanker {
    static func rank(
        _ analyses: [ScenarioPlanRobustnessAnalysis]
    ) -> [ScenarioPlanRobustnessAnalysis] {
        analyses.sorted { first, second in
            if first.entries.isEmpty != second.entries.isEmpty {
                return !first.entries.isEmpty
            }
            let firstWorst = first.worstEntry?.evaluation
            let secondWorst = second.worstEntry?.evaluation
            if firstWorst?.stars != secondWorst?.stars {
                return (firstWorst?.stars ?? 0) > (secondWorst?.stars ?? 0)
            }
            if firstWorst?.destructionPercentage !=
                secondWorst?.destructionPercentage {
                return (firstWorst?.destructionPercentage ?? 0) >
                    (secondWorst?.destructionPercentage ?? 0)
            }
            if first.averageStars != second.averageStars {
                return first.averageStars > second.averageStars
            }
            if first.averageDestruction != second.averageDestruction {
                return first.averageDestruction > second.averageDestruction
            }
            if first.averageSurvivors != second.averageSurvivors {
                return first.averageSurvivors > second.averageSurvivors
            }
            return first.plan.name < second.plan.name
        }
    }
}
