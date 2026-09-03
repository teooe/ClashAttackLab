import Foundation

/// Result of applying one attack plan to one curated base layout.
struct BaseAttackEvaluation: Identifiable {
    let id: String
    let layout: PrototypeBaseLayout
    let evaluation: AttackPlanEvaluation

    init(layout: PrototypeBaseLayout, evaluation: AttackPlanEvaluation) {
        self.id = "\(layout.id)-\(evaluation.plan.id.uuidString)"
        self.layout = layout
        self.evaluation = evaluation
    }
}

/// A repeatable robustness check: the same plan is evaluated on every base.
struct AttackPlanRobustnessAnalysis {
    let plan: AttackPlan
    let entries: [BaseAttackEvaluation]

    var averageStars: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map { Double($0.evaluation.stars) }
            .reduce(0, +) / Double(entries.count)
    }

    var averageDestruction: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map { $0.evaluation.destructionPercentage }
            .reduce(0, +) / Double(entries.count)
    }

    var averageSurvivors: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map {
            Double($0.evaluation.result.survivingTroops)
        }.reduce(0, +) / Double(entries.count)
    }

    var averageDuration: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map { $0.evaluation.result.elapsedTime }
            .reduce(0, +) / Double(entries.count)
    }

    var threeStarCount: Int {
        entries.filter { $0.evaluation.stars == 3 }.count
    }
}
