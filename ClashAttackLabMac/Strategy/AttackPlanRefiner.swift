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

        return laneAndTempoVariants + tacticalVariants
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
            spellDeployments: spellDeployments
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
