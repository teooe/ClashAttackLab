import Foundation
import Testing
@testable import ClashAttackLabMac

struct EvolutionaryAttackSearchTests {
    private let smallSearch = EvolutionaryAttackSearch.Parameters(
        populationSize: 6,
        offspringPerGeneration: 6,
        generations: 2,
        seed: 42
    )

    private func prototypeSetup() -> (NavigationGrid, AttackPlanEvaluator, [AttackPlan]) {
        let grid = PrototypeBattleMap.makeNavigationGrid()
        let evaluator = AttackPlanEvaluator(
            baseEntities: PrototypeBattleMap.makeBaseEntities(navigationGrid: grid),
            gameData: PrototypeGameData(),
            navigationGrid: grid
        )
        let seeds = Array(AttackPlanGenerator(navigationGrid: grid).generate().prefix(6))
        return (grid, evaluator, seeds)
    }

    private func isAtLeastAsGood(
        _ first: EvolutionGenerationSummary,
        as second: EvolutionGenerationSummary
    ) -> Bool {
        first.bestStars > second.bestStars ||
            (first.bestStars == second.bestStars &&
                first.bestDestruction >= second.bestDestruction)
    }

    @Test
    func randomNumbersRepeatForTheSameSeed() {
        var first = SeededRandomGenerator(seed: 7)
        var second = SeededRandomGenerator(seed: 7)
        var other = SeededRandomGenerator(seed: 8)
        let a = (0..<5).map { _ in first.next() }
        let b = (0..<5).map { _ in second.next() }
        let c = (0..<5).map { _ in other.next() }

        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func evolutionNeverLosesItsBestPlan() async throws {
        let (grid, evaluator, seeds) = prototypeSetup()
        let search = EvolutionaryAttackSearch(
            navigationGrid: grid,
            latestOrderTime: BattleTiming.prototypeLatestOrderTime,
            parameters: smallSearch
        )
        var progress: [Int] = []
        let outcome = try await search.run(
            seeds: seeds,
            evaluate: { try await evaluator.evaluateAsync($0) },
            progress: { progress.append($0) }
        )

        #expect(outcome.generations.map(\.generation) == [0, 1, 2])
        for (earlier, later) in zip(outcome.generations, outcome.generations.dropFirst()) {
            #expect(isAtLeastAsGood(later, as: earlier))
        }
        let best = try #require(outcome.ranking.first)
        let bestSeed = try #require(try await evaluator.evaluateAsync(seeds).first)
        #expect(best.stars > bestSeed.stars ||
            (best.stars == bestSeed.stars && best.destructionPercentage >= bestSeed.destructionPercentage))
        // Every distinct plan is simulated once.
        #expect(progress.last == outcome.ranking.count)
        #expect(Set(outcome.ranking.map { EvolutionaryAttackSearch.signature(of: $0.plan) }).count ==
            outcome.ranking.count)
    }

    @Test
    func sameSeedGivesTheSameSearch() async throws {
        let (grid, evaluator, seeds) = prototypeSetup()
        let search = EvolutionaryAttackSearch(
            navigationGrid: grid,
            latestOrderTime: BattleTiming.prototypeLatestOrderTime,
            parameters: smallSearch
        )
        let first = try await search.run(seeds: seeds, evaluate: { try await evaluator.evaluateAsync($0) })
        let second = try await search.run(seeds: seeds, evaluate: { try await evaluator.evaluateAsync($0) })

        #expect(first.generations == second.generations)
        #expect(first.ranking.map { EvolutionaryAttackSearch.signature(of: $0.plan) } ==
            second.ranking.map { EvolutionaryAttackSearch.signature(of: $0.plan) })
    }

    @Test
    func mutationsKeepRealPlansLegal() throws {
        let arena = try BattleArena.make(for: .reference(townHall: 15))
        let grid = arena.navigationGrid
        let latest = BattleTiming.latestOrderTime(forBattleDuration: arena.gameData.battleDuration)
        let plan = try #require(AttackPlanGenerator(
            navigationGrid: grid,
            armyConfiguration: arena.defaultArmy,
            baseEntities: arena.makeBaseEntities(layout: .fortress),
            gameData: arena.gameData,
            armyRules: arena.armyRules
        ).generate().first)
        let search = EvolutionaryAttackSearch(navigationGrid: grid, latestOrderTime: latest)
        var random = SeededRandomGenerator(seed: 1)

        var mutated = plan
        for _ in 0..<200 {
            mutated = search.mutate(mutated, using: &random)
            #expect(mutated.deployments.count == plan.deployments.count)
            #expect(mutated.spellDeployments.count == plan.spellDeployments.count)
            #expect(mutated.armyConfiguration == plan.armyConfiguration)
            for order in mutated.deployments {
                let cell = try #require(grid.coordinate(for: order.position))
                #expect(grid.isDeploymentCell(cell), "\(order.kind) at \(cell)")
                #expect((0...latest).contains(order.deploymentTime))
            }
            for spell in mutated.spellDeployments {
                #expect(grid.coordinate(for: spell.position) != nil)
                #expect((0...latest).contains(spell.deploymentTime))
            }
            for command in mutated.heroAbilityOrders {
                let hero = try #require(mutated.deployments.first { $0.entityID == command.entityID })
                #expect(command.activationTime >= hero.deploymentTime)
                #expect(command.activationTime <= latest)
            }
        }
        #expect(EvolutionaryAttackSearch.signature(of: mutated) !=
            EvolutionaryAttackSearch.signature(of: plan))
    }

    @Test
    func crossoverTakesTroopsFromOneParentAndSpellsFromTheOther() throws {
        let (grid, _, seeds) = prototypeSetup()
        let search = EvolutionaryAttackSearch(
            navigationGrid: grid,
            latestOrderTime: BattleTiming.prototypeLatestOrderTime
        )
        let first = seeds[0]
        #expect(!first.spellDeployments.isEmpty)
        let other = seeds[1]
        let second = AttackPlan(
            name: "Altri incantesimi",
            deployments: other.deployments,
            spellDeployments: first.spellDeployments.map {
                SpellDeploymentOrder(
                    kind: $0.kind,
                    position: WorldPosition(x: $0.position.x + 40, y: $0.position.y),
                    deploymentTime: $0.deploymentTime + 1
                )
            },
            heroAbilityOrders: other.heroAbilityOrders
        )
        let child = search.crossover(first, second)

        #expect(child.deployments.map(\.position) == first.deployments.map(\.position))
        #expect(child.heroAbilityOrders.map(\.entityID) == first.heroAbilityOrders.map(\.entityID))
        #expect(child.spellDeployments.map(\.position) == second.spellDeployments.map(\.position))
    }

    @Test
    func signatureIgnoresNamesAndIdentifiers() throws {
        let (_, _, seeds) = prototypeSetup()
        let plan = seeds[0]
        let renamed = AttackPlan(
            name: "Altro nome",
            deployments: plan.deployments.map {
                DeploymentOrder(kind: $0.kind, position: $0.position, deploymentTime: $0.deploymentTime)
            },
            spellDeployments: plan.spellDeployments.map {
                SpellDeploymentOrder(kind: $0.kind, position: $0.position, deploymentTime: $0.deploymentTime)
            }
        )

        #expect(EvolutionaryAttackSearch.signature(of: renamed) ==
            EvolutionaryAttackSearch.signature(of: AttackPlan(
                name: plan.name,
                deployments: plan.deployments,
                spellDeployments: plan.spellDeployments
            )))
    }
}
