import Foundation

/// Outcome of one plan simulated against a user-created or imported base.
nonisolated struct CustomBaseAttackEvaluation: Identifiable {
    let base: BaseSnapshot
    let evaluation: AttackPlanEvaluation

    var id: UUID {
        base.id
    }
}

/// Robustness report over the active base plus the locally saved base library.
nonisolated struct SavedBasePlanAnalysis: Identifiable {
    let plan: AttackPlan
    let entries: [CustomBaseAttackEvaluation]

    var id: UUID {
        plan.id
    }

    var averageStars: Double {
        guard !entries.isEmpty else {
            return 0
        }

        return entries.map { Double($0.evaluation.stars) }
            .reduce(0, +) / Double(entries.count)
    }

    var averageDestruction: Double {
        guard !entries.isEmpty else {
            return 0
        }

        return entries.map(\.evaluation.destructionPercentage)
            .reduce(0, +) / Double(entries.count)
    }

    var averageSurvivors: Double {
        guard !entries.isEmpty else {
            return 0
        }

        return entries.map {
            Double($0.evaluation.result.survivingTroops)
        }.reduce(0, +) / Double(entries.count)
    }

    var threeStarCount: Int {
        entries.filter { $0.evaluation.stars == 3 }.count
    }
}
