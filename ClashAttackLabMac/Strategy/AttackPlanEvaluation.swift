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

    /// Cooperative evaluation on the simulation actor. Yields between bounded
    /// batches so UI events and cancellation can run without changing ticks.
    func evaluateAsync(
        _ plans: [AttackPlan],
        progress: (Int) -> Void = { _ in }
    ) async throws -> [AttackPlanEvaluation] {
        var evaluations: [AttackPlanEvaluation] = []
        try Task.checkCancellation()
        progress(0)
        for (index, plan) in plans.enumerated() {
            let engine = SimulationEngine(
                entities: baseEntities, attackPlan: plan,
                gameData: gameData, navigationGrid: navigationGrid
            )
            engine.start()
            for iteration in 0..<300 {
                try Task.checkCancellation()
                if case .finished = engine.status { break }
                engine.advance(by: 0.25)
                if iteration.isMultiple(of: 4) {
                    await Task.yield()
                }
            }
            try Task.checkCancellation()
            guard case .finished(let result) = engine.status else {
                throw EvaluationError.incompleteSimulation
            }
            evaluations.append(AttackPlanEvaluation(plan: plan, result: result))
            progress(index + 1)
            await Task.yield()
        }
        try Task.checkCancellation()
        return evaluations.sorted(by: isBetter)
    }

    enum EvaluationError: Error {
        case incompleteSimulation
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
        case .defense, .building, .wall:
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
            movementDomain: definition.movementDomain,
            attackTargetLayer: definition.attackTargetLayer,
            targetingProfile: definition.targetingProfile,
            heroAbility: definition.heroAbility,
            siegePayload: definition.siegePayload
        )
    }

    func spellDefinition(for kind: BattleSpellKind) -> SpellDefinition {
        base.spellDefinition(for: kind)
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
