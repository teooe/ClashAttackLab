import Foundation

/// Explores small, explainable variations of an existing attack plan.
///
/// It keeps the selected army exactly unchanged. Only the deployment lane and
/// timing are varied, so every proposed improvement can still be understood
/// and edited by the player.
nonisolated struct AttackPlanRefiner {
    private let navigationGrid: NavigationGrid

    private let laneOffsets = [-2, -1, 0, 1, 2]
    private let tempoMultipliers = [0.8, 1.0, 1.2]

    init(navigationGrid: NavigationGrid) {
        self.navigationGrid = navigationGrid
    }

    func variants(for sourcePlan: AttackPlan) -> [AttackPlan] {
        laneOffsets.flatMap { laneOffset in
            tempoMultipliers.map { tempoMultiplier in
                makeVariant(
                    from: sourcePlan,
                    laneOffset: laneOffset,
                    tempoMultiplier: tempoMultiplier
                )
            }
        }
    }

    private func makeVariant(
        from sourcePlan: AttackPlan,
        laneOffset: Int,
        tempoMultiplier: Double
    ) -> AttackPlan {
        guard laneOffset != 0 || tempoMultiplier != 1 else {
            return sourcePlan
        }

        let deployments = sourcePlan.deployments.map { order in
            DeploymentOrder(
                id: order.id,
                entityID: order.entityID,
                kind: order.kind,
                position: shiftedPosition(
                    from: order.position,
                    by: laneOffset
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
                position: shiftedPosition(
                    from: order.position,
                    by: laneOffset
                ),
                deploymentTime: adjustedTime(
                    order.deploymentTime,
                    multiplier: tempoMultiplier
                )
            )
        }

        return AttackPlan(
            name: variantName(
                for: sourcePlan,
                laneOffset: laneOffset,
                tempoMultiplier: tempoMultiplier
            ),
            deployments: deployments,
            spellDeployments: spellDeployments
        )
    }

    private func shiftedPosition(
        from position: WorldPosition,
        by laneOffset: Int
    ) -> WorldPosition {
        guard let coordinate = navigationGrid.coordinate(for: position) else {
            return position
        }

        let row = min(
            navigationGrid.rows - 1,
            max(0, coordinate.row + laneOffset)
        )

        return navigationGrid.worldPosition(
            for: GridCoordinate(
                column: coordinate.column,
                row: row
            )
        )
    }

    private func adjustedTime(
        _ time: TimeInterval,
        multiplier: Double
    ) -> TimeInterval {
        min(59, max(0, time * multiplier))
    }

    private func variantName(
        for sourcePlan: AttackPlan,
        laneOffset: Int,
        tempoMultiplier: Double
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

        return "\(sourcePlan.name) · \(laneLabel) · ritmo \(tempoPercent)%"
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
