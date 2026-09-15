import Foundation

/// Explores small, explainable variations of an existing attack plan.
///
/// It keeps the selected army exactly unchanged. The search varies the lane,
/// deployment rhythm, depth inside the allowed deploy strip and spell timing.
/// This deliberately stays compact enough for a full cross-base evaluation.
nonisolated struct AttackPlanRefiner {
    private let navigationGrid: NavigationGrid

    private let laneOffsets = [-2, -1, 0, 1, 2]
    private let tempoMultipliers = [0.8, 1.0, 1.2]

    init(navigationGrid: NavigationGrid) {
        self.navigationGrid = navigationGrid
    }

    func variants(for sourcePlan: AttackPlan) -> [AttackPlan] {
        let laneAndTempoVariants = laneOffsets.flatMap { laneOffset in
            tempoMultipliers.map { tempoMultiplier in
                makeVariant(
                    from: sourcePlan,
                    laneOffset: laneOffset,
                    tempoMultiplier: tempoMultiplier
                )
            }
        }

        let tacticalVariants = [
            makeVariant(
                from: sourcePlan,
                laneOffset: 0,
                tempoMultiplier: 1,
                deploymentColumnOffset: -1,
                spellTimeOffset: 0
            ),
            makeVariant(
                from: sourcePlan,
                laneOffset: 0,
                tempoMultiplier: 1,
                deploymentColumnOffset: 1,
                spellTimeOffset: 0
            ),
            makeVariant(
                from: sourcePlan,
                laneOffset: 0,
                tempoMultiplier: 1,
                deploymentColumnOffset: 0,
                spellTimeOffset: -1.5
            ),
            makeVariant(
                from: sourcePlan,
                laneOffset: 0,
                tempoMultiplier: 1,
                deploymentColumnOffset: 0,
                spellTimeOffset: 1.5
            ),
            makeVariant(
                from: sourcePlan,
                laneOffset: 1,
                tempoMultiplier: 0.8,
                deploymentColumnOffset: 1,
                spellTimeOffset: -1
            ),
            makeVariant(
                from: sourcePlan,
                laneOffset: -1,
                tempoMultiplier: 1.2,
                deploymentColumnOffset: -1,
                spellTimeOffset: 1
            )
        ]

        return laneAndTempoVariants + tacticalVariants +
            heroTimingVariants(for: sourcePlan) +
            spellTacticalVariants(for: sourcePlan)
    }

    /// Explores every scheduled spell independently without changing the army.
    /// Four bounded alternatives per cast vary impact cell and timing.
    func spellTacticalVariants(for sourcePlan: AttackPlan) -> [AttackPlan] {
        var variants: [AttackPlan] = []
        for spellIndex in sourcePlan.spellDeployments.indices {
            let original = sourcePlan.spellDeployments[spellIndex]
            let alternatives: [(row: Int, column: Int, time: TimeInterval, label: String)] = [
                (-1, 0, 0, "alto"),
                (1, 0, 0, "basso"),
                (0, -1, -1, "anticipato"),
                (0, 1, 1, "ritardato")
            ]
            for alternative in alternatives {
                var spells = sourcePlan.spellDeployments
                spells[spellIndex] = SpellDeploymentOrder(
                    id: original.id,
                    kind: original.kind,
                    position: shiftedSpellPosition(
                        from: original.position,
                        rowOffset: alternative.row,
                        columnOffset: alternative.column
                    ),
                    deploymentTime: adjustedSpellTime(
                        original.deploymentTime,
                        multiplier: 1,
                        offset: alternative.time
                    )
                )
                variants.append(AttackPlan(
                    name: "\(sourcePlan.name) · magia \(spellIndex + 1) \(alternative.label)",
                    deployments: sourcePlan.deployments,
                    spellDeployments: spells,
                    heroAbilityOrders: sourcePlan.heroAbilityOrders
                ))
            }
        }
        return variants
    }

    /// A bounded search: at most nine extra simulations per base.
    /// It changes hero commands independently of deployment and spell timing.
    /// Automatic low-health activation remains enabled in every candidate.
    func heroTimingVariants(for sourcePlan: AttackPlan) -> [AttackPlan] {
        let heroes = Array(sourcePlan.orderedDeployments.filter {
            ($0.kind == .barbarianKing || $0.kind == .archerQueen) &&
                $0.deploymentTime.isFinite && (0...59).contains($0.deploymentTime)
        }.prefix(2))
        guard !heroes.isEmpty else { return [] }
        var result: [AttackPlan] = []
        var signatures: Set<String> = [heroSignature(sourcePlan.heroAbilityOrders)]

        func append(_ commands: [HeroAbilityOrder], label: String) {
            guard signatures.insert(heroSignature(commands)).inserted else {
                return
            }
            result.append(AttackPlan(
                name: "\(sourcePlan.name) · \(label)",
                deployments: sourcePlan.deployments,
                spellDeployments: sourcePlan.spellDeployments,
                heroAbilityOrders: commands
            ))
        }

        for hero in heroes {
            let existing = sourcePlan.heroAbilityOrders.first {
                $0.entityID == hero.entityID
            }
            let otherCommands = sourcePlan.heroAbilityOrders.filter {
                $0.entityID != hero.entityID
            }
            let heroName = hero.kind == .barbarianKing ? "Re" : "Regina"
            append(otherCommands, label: "\(heroName) automatica")
            let anchor = existing?.activationTime ?? (hero.deploymentTime + 6)
            for offset in [-2.0, 2.0] {
                let time = min(59, max(hero.deploymentTime, anchor + offset))
                let command = HeroAbilityOrder(
                    id: existing?.id ?? UUID(),
                    entityID: hero.entityID,
                    activationTime: time
                )
                append(otherCommands + [command],
                    label: "\(heroName) abilità @ \(String(format: "%.1f", time)) s")
            }
        }

        let heroIDs = Set(heroes.map(\.entityID))
        let remaining = sourcePlan.heroAbilityOrders.filter {
            !heroIDs.contains($0.entityID)
        }
        for delay in [4.0, 8.0, 12.0] {
            let commands = heroes.map { hero in
                HeroAbilityOrder(
                    entityID: hero.entityID,
                    activationTime: min(59, hero.deploymentTime + delay)
                )
            }
            append(remaining + commands,
                label: "eroi abilità a +\(Int(delay)) s dal deploy")
        }
        return result
    }

    private func heroSignature(_ commands: [HeroAbilityOrder]) -> String {
        commands.map {
            "\($0.entityID.uuidString):\($0.activationTime)"
        }.sorted().joined(separator: "|")
    }

    /// Builds one explainable lane/timing variation for an external planner.
    func variant(
        from sourcePlan: AttackPlan,
        laneOffset: Int,
        tempoMultiplier: Double = 1
    ) -> AttackPlan {
        makeVariant(
            from: sourcePlan,
            laneOffset: laneOffset,
            tempoMultiplier: tempoMultiplier
        )
    }

    private func makeVariant(
        from sourcePlan: AttackPlan,
        laneOffset: Int,
        tempoMultiplier: Double,
        deploymentColumnOffset: Int = 0,
        spellTimeOffset: TimeInterval = 0
    ) -> AttackPlan {
        guard
            laneOffset != 0 ||
                tempoMultiplier != 1 ||
                deploymentColumnOffset != 0 ||
                spellTimeOffset != 0
        else {
            return sourcePlan
        }

        let deployments = sourcePlan.deployments.map { order in
            DeploymentOrder(
                id: order.id,
                entityID: order.entityID,
                kind: order.kind,
                position: shiftedDeploymentPosition(
                    from: order.position,
                    rowOffset: laneOffset,
                    columnOffset: deploymentColumnOffset
                ),
                deploymentTime: adjustedTime(
                    order.deploymentTime,
                    multiplier: tempoMultiplier
                )
            )
        }
        let spellDeployments = sourcePlan.spellDeployments.map { order in
            SpellDeploymentOrder(
                id: order.id,
                kind: order.kind,
                // Freeze stays anchored to defenses when troop lanes move.
                position: order.kind == .freeze ? order.position : shiftedRow(
                    from: order.position,
                    by: laneOffset
                ),
                deploymentTime: adjustedSpellTime(
                    order.deploymentTime,
                    multiplier: tempoMultiplier,
                    offset: spellTimeOffset
                )
            )
        }

        return AttackPlan(
            name: variantName(
                for: sourcePlan,
                laneOffset: laneOffset,
                tempoMultiplier: tempoMultiplier,
                deploymentColumnOffset: deploymentColumnOffset,
                spellTimeOffset: spellTimeOffset
            ),
            deployments: deployments,
            spellDeployments: spellDeployments,
            heroAbilityOrders: sourcePlan.heroAbilityOrders.map { order in
                HeroAbilityOrder(
                    id: order.id,
                    entityID: order.entityID,
                    activationTime: adjustedTime(
                        order.activationTime, multiplier: tempoMultiplier
                    )
                )
            }
        )
    }

    private func shiftedDeploymentPosition(
        from position: WorldPosition,
        rowOffset: Int,
        columnOffset: Int
    ) -> WorldPosition {
        guard let coordinate = navigationGrid.coordinate(for: position) else {
            return position
        }

        let row = clampedRow(coordinate.row + rowOffset)
        let column = min(2, max(0, coordinate.column + columnOffset))

        return navigationGrid.worldPosition(
            for: GridCoordinate(column: column, row: row)
        )
    }

    private func shiftedSpellPosition(
        from position: WorldPosition,
        rowOffset: Int,
        columnOffset: Int
    ) -> WorldPosition {
        guard let coordinate = navigationGrid.coordinate(for: position) else {
            return position
        }
        return navigationGrid.worldPosition(
            for: GridCoordinate(
                column: min(navigationGrid.columns - 1, max(0, coordinate.column + columnOffset)),
                row: clampedRow(coordinate.row + rowOffset)
            )
        )
    }

    private func shiftedRow(
        from position: WorldPosition,
        by rowOffset: Int
    ) -> WorldPosition {
        guard let coordinate = navigationGrid.coordinate(for: position) else {
            return position
        }

        return navigationGrid.worldPosition(
            for: GridCoordinate(
                column: coordinate.column,
                row: clampedRow(coordinate.row + rowOffset)
            )
        )
    }

    private func clampedRow(_ row: Int) -> Int {
        min(navigationGrid.rows - 1, max(0, row))
    }

    private func adjustedTime(
        _ time: TimeInterval,
        multiplier: Double
    ) -> TimeInterval {
        min(59, max(0, time * multiplier))
    }

    private func adjustedSpellTime(
        _ time: TimeInterval,
        multiplier: Double,
        offset: TimeInterval
    ) -> TimeInterval {
        min(59, max(0, time * multiplier + offset))
    }

    private func variantName(
        for sourcePlan: AttackPlan,
        laneOffset: Int,
        tempoMultiplier: Double,
        deploymentColumnOffset: Int,
        spellTimeOffset: TimeInterval
    ) -> String {
        let laneLabel: String

        switch laneOffset {
        case 0:
            laneLabel = "corsia invariata"
        case let value where value > 0:
            laneLabel = "corsia +\(value)"
        default:
            laneLabel = "corsia \(laneOffset)"
        }

        let tempoPercent = Int((tempoMultiplier * 100).rounded())
        let depthLabel: String

        switch deploymentColumnOffset {
        case 0:
            depthLabel = "deploy invariato"
        case let value where value > 0:
            depthLabel = "deploy avanti"
        default:
            depthLabel = "deploy esterno"
        }

        let spellLabel: String

        switch spellTimeOffset {
        case 0:
            spellLabel = "magie standard"
        case let value where value < 0:
            spellLabel = "magie anticipate"
        default:
            spellLabel = "magie ritardate"
        }

        return "\(sourcePlan.name) · \(laneLabel) · ritmo \(tempoPercent)% · \(depthLabel) · \(spellLabel)"
    }
}

/// Cross-base result of refining a single plan.
///
/// The entries are already ordered by the same deterministic ranking used for
/// the strategy library, allowing the UI to load a recommendation directly.
nonisolated struct AttackPlanRefinementReport {
    let sourcePlan: AttackPlan
    let rankedCandidates: [AttackPlanRobustnessAnalysis]

    var candidateCount: Int {
        rankedCandidates.count
    }

    var recommendedPlan: AttackPlan? {
        rankedCandidates.first?.plan
    }
}
