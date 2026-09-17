import Foundation

nonisolated struct SpellImpactEntry: Identifiable {
    let id: UUID
    let kind: BattleSpellKind
    let targetCount: Int
    let defenseCount: Int
    let buildingCount: Int
    let wallCount: Int
    let rawDamage: Double
    let usefulDamage: Double

    var wastedDamage: Double {
        max(0, rawDamage - usefulDamage)
    }

    var efficiency: Double {
        guard rawDamage > 0 else { return 0 }
        return usefulDamage / rawDamage
    }

    var qualityLabel: String {
        if targetCount == 0 { return "Fuori bersaglio" }
        if targetCount >= 3 && efficiency >= 0.75 { return "Ottimo" }
        if targetCount >= 2 && efficiency >= 0.55 { return "Buono" }
        return "Debole"
    }
}

nonisolated struct SpellImpactAnalysis {
    let entries: [SpellImpactEntry]

    var totalUsefulDamage: Double {
        entries.reduce(0) { $0 + $1.usefulDamage }
    }

    var totalWastedDamage: Double {
        entries.reduce(0) { $0 + $1.wastedDamage }
    }

    var averageEfficiency: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.reduce(0) { $0 + $1.efficiency } /
            Double(entries.count)
    }

    var missedCastCount: Int {
        entries.filter { $0.targetCount == 0 }.count
    }
}

/// Static, deterministic preview for instant-damage spells.
/// Values come from the active GameData provider and remain prototype tuning.
nonisolated struct SpellImpactAnalyzer {
    let gameData: any GameDataProviding

    func analyze(
        plan: AttackPlan,
        entities: [BattleEntity]
    ) -> SpellImpactAnalysis {
        let entries = plan.orderedSpellDeployments.compactMap { order -> SpellImpactEntry? in
            let spell = gameData.spellDefinition(for: order.kind)
            guard spell.instantDamage > 0 else { return nil }

            var targetCount = 0
            var defenseCount = 0
            var buildingCount = 0
            var wallCount = 0
            var rawDamage = 0.0
            var usefulDamage = 0.0

            for entity in entities where entity.isAlive {
                let definition = gameData.definition(for: entity.kind)
                let canHit =
                    definition.role == .defense ||
                    definition.role == .building ||
                    (order.kind == .earthquake && definition.role == .wall)
                guard canHit, hypot(
                    entity.position.x - order.position.x,
                    entity.position.y - order.position.y
                ) <= spell.radius else { continue }

                let multiplier = definition.role == .wall ? 4.0 : 1.0
                let damage = spell.instantDamage * multiplier
                targetCount += 1
                rawDamage += damage
                usefulDamage += min(entity.hitPoints, damage)
                switch definition.role {
                case .defense: defenseCount += 1
                case .building: buildingCount += 1
                case .wall: wallCount += 1
                case .troop: break
                }
            }

            return SpellImpactEntry(
                id: order.id,
                kind: order.kind,
                targetCount: targetCount,
                defenseCount: defenseCount,
                buildingCount: buildingCount,
                wallCount: wallCount,
                rawDamage: rawDamage,
                usefulDamage: usefulDamage
            )
        }
        return SpellImpactAnalysis(entries: entries)
    }
}


nonisolated struct SpellPlanOptimizationResult {
    let originalPlan: AttackPlan
    let optimizedPlan: AttackPlan
    let movedSpellIDs: Set<UUID>
    let before: SpellImpactAnalysis
    let after: SpellImpactAnalysis

    var movedCastCount: Int { movedSpellIDs.count }
    var usefulDamageGain: Double {
        after.totalUsefulDamage - before.totalUsefulDamage
    }
}

/// Repositions only instant-damage spells and accepts strictly better casts.
nonisolated struct OffensiveSpellPlanOptimizer {
    let navigationGrid: NavigationGrid
    let gameData: any GameDataProviding

    func optimize(
        plan: AttackPlan,
        entities: [BattleEntity]
    ) -> SpellPlanOptimizationResult {
        let analyzer = SpellImpactAnalyzer(gameData: gameData)
        let before = analyzer.analyze(plan: plan, entities: entities)
        let lightningPlanner = LightningPlacementPlanner(
            navigationGrid: navigationGrid,
            gameData: gameData
        )
        let earthquakePlanner = EarthquakePlacementPlanner(
            navigationGrid: navigationGrid,
            gameData: gameData
        )
        var lightningPositions: [WorldPosition] = []
        var earthquakePositions: [WorldPosition] = []
        var moved: Set<UUID> = []

        let spells = plan.spellDeployments.map { order -> SpellDeploymentOrder in
            let proposed: WorldPosition?
            switch order.kind {
            case .lightning:
                proposed = lightningPlanner.position(
                    entities: entities,
                    previousPositions: lightningPositions
                )
            case .earthquake:
                proposed = earthquakePlanner.position(
                    entities: entities,
                    previousPositions: earthquakePositions
                )
            case .heal, .rage, .freeze:
                proposed = nil
            }

            guard let proposed else { return order }
            let candidate = SpellDeploymentOrder(
                id: order.id,
                kind: order.kind,
                position: proposed,
                deploymentTime: order.deploymentTime
            )
            let currentImpact = impact(
                of: order,
                analyzer: analyzer,
                entities: entities
            )
            let candidateImpact = impact(
                of: candidate,
                analyzer: analyzer,
                entities: entities
            )
            let improves = candidateImpact.usefulDamage >
                currentImpact.usefulDamage + 0.001

            let selected = improves ? candidate : order
            if improves { moved.insert(order.id) }
            switch order.kind {
            case .lightning:
                lightningPositions.append(selected.position)
            case .earthquake:
                earthquakePositions.append(selected.position)
            case .heal, .rage, .freeze:
                break
            }
            return selected
        }

        let optimized = AttackPlan(
            name: moved.isEmpty ? plan.name : "\(plan.name) · magie ottimizzate",
            deployments: plan.deployments,
            spellDeployments: spells,
            heroAbilityOrders: plan.heroAbilityOrders
        )
        return SpellPlanOptimizationResult(
            originalPlan: plan,
            optimizedPlan: optimized,
            movedSpellIDs: moved,
            before: before,
            after: analyzer.analyze(plan: optimized, entities: entities)
        )
    }

    private func impact(
        of order: SpellDeploymentOrder,
        analyzer: SpellImpactAnalyzer,
        entities: [BattleEntity]
    ) -> SpellImpactEntry {
        analyzer.analyze(
            plan: AttackPlan(
                name: "Valutazione lancio",
                deployments: [],
                spellDeployments: [order]
            ),
            entities: entities
        ).entries[0]
    }
}
