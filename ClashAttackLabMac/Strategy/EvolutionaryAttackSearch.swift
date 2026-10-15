import Foundation

/// Deterministic pseudo-random numbers (SplitMix64), so the same seed
/// always produces the same search.
nonisolated struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

/// Best result of one generation, for the progress report.
nonisolated struct EvolutionGenerationSummary: Equatable {
    let generation: Int
    let bestStars: Int
    let bestDestruction: Double
    let evaluatedPlans: Int
}

/// Genetic search over attack plans for one army against one base.
///
/// Each generation keeps the best plans, then breeds new ones by mixing
/// two parents (troops and hero timings from one, spells from the other)
/// and mutating them: troop groups slide along the edge they deploy from,
/// waves start earlier or later, spells move and change timing, hero
/// abilities fire at other moments. Every child stays a legal plan: troops
/// land on deployment cells, spells inside the map, times inside the
/// battle. Plans already simulated are never simulated again.
nonisolated struct EvolutionaryAttackSearch {
    struct Parameters: Equatable {
        /// Plans kept alive between generations.
        var populationSize = 16
        /// New plans bred every generation.
        var offspringPerGeneration = 16
        var generations = 6
        var seed: UInt64 = 0xC1A5_A77A

        static let standard = Parameters()
    }

    struct Outcome {
        /// Every distinct plan simulated, best first.
        let ranking: [AttackPlanEvaluation]
        let generations: [EvolutionGenerationSummary]
    }

    let navigationGrid: NavigationGrid
    let latestOrderTime: TimeInterval
    let parameters: Parameters

    init(
        navigationGrid: NavigationGrid,
        latestOrderTime: TimeInterval,
        parameters: Parameters = .standard
    ) {
        self.navigationGrid = navigationGrid
        self.latestOrderTime = latestOrderTime
        self.parameters = parameters
    }

    /// Runs the search. `evaluate` simulates a batch of plans and returns
    /// them ranked best first; `progress` receives the number of plans
    /// simulated so far. Breeding and bookkeeping stay on the caller's
    /// actor; `evaluate` decides where the battles run.
    func run(
        seeds: [AttackPlan],
        isolation: isolated (any Actor)? = #isolation,
        evaluate: ([AttackPlan]) async throws -> [AttackPlanEvaluation],
        progress: (Int) -> Void = { _ in }
    ) async throws -> Outcome {
        var random = SeededRandomGenerator(seed: parameters.seed)
        var state = SearchState()
        var summaries: [EvolutionGenerationSummary] = []

        guard !seeds.isEmpty else {
            return Outcome(ranking: [], generations: [])
        }

        var population = Array(Self.ranked(try await simulate(
            seeds,
            state: &state,
            isolation: isolation,
            evaluate: evaluate,
            progress: progress
        )).prefix(parameters.populationSize))
        summaries.append(summary(generation: 0, population: population, simulated: state.simulated))

        for generation in 1...max(parameters.generations, 1) {
            try Task.checkCancellation()
            guard !population.isEmpty else {
                break
            }
            var children: [AttackPlan] = []
            for index in 0..<parameters.offspringPerGeneration {
                let first = select(from: population, using: &random).plan
                let second = select(from: population, using: &random).plan
                var child = Bool.random(using: &random)
                    ? crossover(first, second)
                    : first
                child = mutate(child, using: &random)
                children.append(rename(child, generation: generation, index: index))
            }
            let offspring = try await simulate(
                children,
                state: &state,
                isolation: isolation,
                evaluate: evaluate,
                progress: progress
            )
            var kept: [AttackPlanEvaluation] = []
            var keptSignatures: Set<String> = []
            for evaluation in Self.ranked(population + offspring)
            where keptSignatures.insert(Self.signature(of: evaluation.plan)).inserted {
                kept.append(evaluation)
            }
            // Parents and children compete together, so the best plan
            // found so far always survives.
            population = Array(kept.prefix(parameters.populationSize))
            summaries.append(summary(generation: generation, population: population, simulated: state.simulated))
        }

        return Outcome(
            ranking: Self.ranked(Array(state.seen.values)),
            generations: summaries
        )
    }

    private struct SearchState {
        var seen: [String: AttackPlanEvaluation] = [:]
        var simulated = 0
    }

    /// Simulates the plans not seen yet and returns an evaluation for
    /// every plan in `plans`.
    private func simulate(
        _ plans: [AttackPlan],
        state: inout SearchState,
        isolation: isolated (any Actor)?,
        evaluate: ([AttackPlan]) async throws -> [AttackPlanEvaluation],
        progress: (Int) -> Void
    ) async throws -> [AttackPlanEvaluation] {
        var fresh: [AttackPlan] = []
        var freshSignatures: Set<String> = []
        for plan in plans {
            let signature = Self.signature(of: plan)
            if state.seen[signature] == nil, freshSignatures.insert(signature).inserted {
                fresh.append(plan)
            }
        }
        if !fresh.isEmpty {
            for evaluation in try await evaluate(fresh) {
                state.seen[Self.signature(of: evaluation.plan)] = evaluation
            }
            state.simulated += fresh.count
            progress(state.simulated)
        }
        return plans.compactMap { state.seen[Self.signature(of: $0)] }
    }

    // MARK: Selection

    /// Tournament of two: the better of two random plans, so strong plans
    /// breed more often without wiping out the rest.
    private func select(
        from population: [AttackPlanEvaluation],
        using random: inout SeededRandomGenerator
    ) -> AttackPlanEvaluation {
        let first = Int.random(in: 0..<population.count, using: &random)
        let second = Int.random(in: 0..<population.count, using: &random)
        return population[min(first, second)]
    }

    private func summary(
        generation: Int,
        population: [AttackPlanEvaluation],
        simulated: Int
    ) -> EvolutionGenerationSummary {
        EvolutionGenerationSummary(
            generation: generation,
            bestStars: population.first?.stars ?? 0,
            bestDestruction: population.first?.destructionPercentage ?? 0,
            evaluatedPlans: simulated
        )
    }

    // MARK: Breeding

    /// Troops (with their hero commands) from the first parent, spells from
    /// the second when both carry the same spells.
    func crossover(_ first: AttackPlan, _ second: AttackPlan) -> AttackPlan {
        let sameSpells = first.spellDeployments.map(\.kind).sorted(by: Self.spellOrder) ==
            second.spellDeployments.map(\.kind).sorted(by: Self.spellOrder)
        return AttackPlan(
            name: first.name,
            deployments: first.deployments,
            spellDeployments: sameSpells ? second.spellDeployments : first.spellDeployments,
            heroAbilityOrders: first.heroAbilityOrders
        )
    }

    func mutate(
        _ plan: AttackPlan,
        using random: inout SeededRandomGenerator
    ) -> AttackPlan {
        var deployments = plan.deployments
        var spells = plan.spellDeployments
        var heroOrders = plan.heroAbilityOrders
        let mutations = Int.random(in: 1...3, using: &random)

        for _ in 0..<mutations {
            switch Int.random(in: 0..<6, using: &random) {
            case 0:
                // Slide one troop group along its edge.
                let kinds = Array(Set(deployments.map(\.kind))).sorted { $0.referenceKey < $1.referenceKey }
                guard let kind = kinds.randomElement(using: &random) else { break }
                let step = Double(Int.random(in: -4...4, using: &random)) * navigationGrid.cellSize
                let alongX = Bool.random(using: &random)
                deployments = deployments.map { order in
                    guard order.kind == kind else { return order }
                    let moved = WorldPosition(
                        x: order.position.x + (alongX ? step : 0),
                        y: order.position.y + (alongX ? 0 : step)
                    )
                    return relocated(order, to: snappedDeploymentPosition(moved, fallback: order.position))
                }
            case 1:
                // Start one group's wave earlier or later.
                let kinds = Array(Set(deployments.map(\.kind))).sorted { $0.referenceKey < $1.referenceKey }
                guard let kind = kinds.randomElement(using: &random) else { break }
                let shift = Double(Int.random(in: -6...6, using: &random)) * 0.5
                deployments = deployments.map { order in
                    order.kind == kind ? retimed(order, to: order.deploymentTime + shift) : order
                }
            case 2:
                // Faster or slower tempo for the whole army.
                let tempo = [0.75, 0.85, 1.15, 1.3].randomElement(using: &random) ?? 1
                deployments = deployments.map { retimed($0, to: $0.deploymentTime * tempo) }
            case 3:
                // Move one spell.
                guard !spells.isEmpty else { break }
                let index = Int.random(in: 0..<spells.count, using: &random)
                let spell = spells[index]
                let moved = WorldPosition(
                    x: spell.position.x + Double(Int.random(in: -3...3, using: &random)) * navigationGrid.cellSize,
                    y: spell.position.y + Double(Int.random(in: -3...3, using: &random)) * navigationGrid.cellSize
                )
                spells[index] = SpellDeploymentOrder(
                    id: spell.id,
                    kind: spell.kind,
                    position: clampedToGrid(moved),
                    deploymentTime: spell.deploymentTime
                )
            case 4:
                // Cast one spell at another moment.
                guard !spells.isEmpty else { break }
                let index = Int.random(in: 0..<spells.count, using: &random)
                let spell = spells[index]
                spells[index] = SpellDeploymentOrder(
                    id: spell.id,
                    kind: spell.kind,
                    position: spell.position,
                    deploymentTime: clampedTime(
                        spell.deploymentTime + Double(Int.random(in: -8...8, using: &random)) * 0.5
                    )
                )
            default:
                // Fire a hero ability at another moment, or leave it to
                // the automatic low-health trigger.
                let heroes = deployments.filter { $0.kind.isHero }
                guard let hero = heroes.randomElement(using: &random) else { break }
                let existing = heroOrders.first { $0.entityID == hero.entityID }
                heroOrders.removeAll { $0.entityID == hero.entityID }
                if Int.random(in: 0..<4, using: &random) > 0 {
                    let anchor = existing?.activationTime ?? hero.deploymentTime + 6
                    let time = anchor + Double(Int.random(in: -8...8, using: &random)) * 0.5
                    heroOrders.append(HeroAbilityOrder(
                        id: existing?.id ?? UUID(),
                        entityID: hero.entityID,
                        activationTime: min(latestOrderTime, max(hero.deploymentTime, time))
                    ))
                }
            }
        }

        // Hero commands never come before their hero.
        heroOrders = heroOrders.compactMap { command in
            guard let hero = deployments.first(where: { $0.entityID == command.entityID }) else {
                return nil
            }
            return HeroAbilityOrder(
                id: command.id,
                entityID: command.entityID,
                activationTime: min(latestOrderTime, max(hero.deploymentTime, command.activationTime))
            )
        }

        return AttackPlan(
            name: plan.name,
            deployments: deployments,
            spellDeployments: spells,
            heroAbilityOrders: heroOrders
        )
    }

    private func rename(_ plan: AttackPlan, generation: Int, index: Int) -> AttackPlan {
        let base = plan.name.components(separatedBy: " · evo ").first ?? plan.name
        return AttackPlan(
            name: "\(base) · evo g\(generation).\(index + 1)",
            deployments: plan.deployments,
            spellDeployments: plan.spellDeployments,
            heroAbilityOrders: plan.heroAbilityOrders
        )
    }

    // MARK: Legal positions and times

    private func relocated(_ order: DeploymentOrder, to position: WorldPosition) -> DeploymentOrder {
        DeploymentOrder(
            id: order.id,
            entityID: order.entityID,
            kind: order.kind,
            position: position,
            deploymentTime: order.deploymentTime
        )
    }

    private func retimed(_ order: DeploymentOrder, to time: TimeInterval) -> DeploymentOrder {
        DeploymentOrder(
            id: order.id,
            entityID: order.entityID,
            kind: order.kind,
            position: order.position,
            deploymentTime: clampedTime(time)
        )
    }

    private func clampedTime(_ time: TimeInterval) -> TimeInterval {
        min(latestOrderTime, max(0, (time * 10).rounded() / 10))
    }

    private func clampedToGrid(_ position: WorldPosition) -> WorldPosition {
        let column = min(max(Int(floor((position.x - navigationGrid.origin.x) / navigationGrid.cellSize)), 0), navigationGrid.columns - 1)
        let row = min(max(Int(floor((position.y - navigationGrid.origin.y) / navigationGrid.cellSize)), 0), navigationGrid.rows - 1)
        return navigationGrid.worldPosition(for: GridCoordinate(column: column, row: row))
    }

    /// The deployment cell closest to `position`, or `fallback` when none
    /// lies within a few tiles.
    func snappedDeploymentPosition(
        _ position: WorldPosition,
        fallback: WorldPosition
    ) -> WorldPosition {
        let target = clampedToGrid(position)
        guard let center = navigationGrid.coordinate(for: target) else {
            return fallback
        }
        if navigationGrid.isDeploymentCell(center) {
            return target
        }
        var best: (GridCoordinate, Int)?
        for radius in 1...4 {
            for column in (center.column - radius)...(center.column + radius) {
                for row in (center.row - radius)...(center.row + radius) {
                    let cell = GridCoordinate(column: column, row: row)
                    guard navigationGrid.isDeploymentCell(cell) else { continue }
                    let distance = abs(cell.column - center.column) + abs(cell.row - center.row)
                    if best == nil || distance < best!.1 {
                        best = (cell, distance)
                    }
                }
            }
            if let best {
                return navigationGrid.worldPosition(for: best.0)
            }
        }
        return fallback
    }

    // MARK: Ranking and identity

    /// Plans with the same orders (rounded to tenths of a second and whole
    /// world units) count as one plan.
    static func signature(of plan: AttackPlan) -> String {
        let troops = plan.deployments.map {
            "\($0.kind.referenceKey)@\(Int($0.position.x.rounded())),\(Int($0.position.y.rounded()))t\(Int(($0.deploymentTime * 10).rounded()))"
        }.sorted()
        let spells = plan.spellDeployments.map {
            "\($0.kind)@\(Int($0.position.x.rounded())),\(Int($0.position.y.rounded()))t\(Int(($0.deploymentTime * 10).rounded()))"
        }.sorted()
        let heroes = plan.heroAbilityOrders.compactMap { command -> String? in
            guard let hero = plan.deployments.first(where: { $0.entityID == command.entityID }) else {
                return nil
            }
            return "\(hero.kind.referenceKey)!\(Int((command.activationTime * 10).rounded()))"
        }.sorted()
        return (troops + ["|"] + spells + ["|"] + heroes).joined(separator: ";")
    }

    private static func spellOrder(_ first: BattleSpellKind, _ second: BattleSpellKind) -> Bool {
        "\(first)" < "\(second)"
    }

    /// Same order as the evaluator: stars, destruction, Town Hall, damage,
    /// troops lost, then name for a stable tie-break.
    static func ranked(_ evaluations: [AttackPlanEvaluation]) -> [AttackPlanEvaluation] {
        evaluations.sorted { first, second in
            if first.stars != second.stars {
                return first.stars > second.stars
            }
            if first.destructionPercentage != second.destructionPercentage {
                return first.destructionPercentage > second.destructionPercentage
            }
            if first.result.score.townHallDestroyed != second.result.score.townHallDestroyed {
                return first.result.score.townHallDestroyed
            }
            if first.result.metrics.damageToBase != second.result.metrics.damageToBase {
                return first.result.metrics.damageToBase > second.result.metrics.damageToBase
            }
            if first.result.metrics.troopsLost != second.result.metrics.troopsLost {
                return first.result.metrics.troopsLost < second.result.metrics.troopsLost
            }
            return first.plan.name < second.plan.name
        }
    }
}
