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


/// Cross-base ranking over real local/imported bases, rather than only the
/// curated prototype layouts. It is local-only and deterministic.
nonisolated struct SavedBasePlanRobustnessAnalysis: Identifiable {
    let plan: AttackPlan
    let entries: [CustomBaseAttackEvaluation]

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
        return entries.map { Double($0.evaluation.result.survivingTroops) }
            .reduce(0, +) / Double(entries.count)
    }

    var averageDuration: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map { $0.evaluation.result.elapsedTime }
            .reduce(0, +) / Double(entries.count)
    }

    var threeStarCount: Int {
        entries.filter { $0.evaluation.stars == 3 }.count
    }

    var weakestEntry: CustomBaseAttackEvaluation? {
        entries.min {
            if $0.evaluation.stars != $1.evaluation.stars {
                return $0.evaluation.stars < $1.evaluation.stars
            }
            if $0.evaluation.destructionPercentage !=
                $1.evaluation.destructionPercentage {
                return $0.evaluation.destructionPercentage <
                    $1.evaluation.destructionPercentage
            }
            return $0.base.name < $1.base.name
        }
    }

    var weakestBaseSummary: String {
        guard let entry = weakestEntry else { return "Nessuna base valutata" }
        return "\(entry.base.name) · \(entry.evaluation.stars)★ · " +
            String(format: "%.1f%%", entry.evaluation.destructionPercentage)
    }
}

nonisolated enum SavedBasePlanRanker {
    static func rank(
        _ analyses: [SavedBasePlanRobustnessAnalysis],
        objective: RobustnessObjective
    ) -> [SavedBasePlanRobustnessAnalysis] {
        analyses.sorted { first, second in
            if first.entries.isEmpty != second.entries.isEmpty {
                return !first.entries.isEmpty
            }
            if objective == .weakestBase {
                let firstWeak = first.weakestEntry?.evaluation
                let secondWeak = second.weakestEntry?.evaluation
                if firstWeak?.stars != secondWeak?.stars {
                    return (firstWeak?.stars ?? 0) > (secondWeak?.stars ?? 0)
                }
                if firstWeak?.destructionPercentage !=
                    secondWeak?.destructionPercentage {
                    return (firstWeak?.destructionPercentage ?? 0) >
                        (secondWeak?.destructionPercentage ?? 0)
                }
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
            if first.averageDuration != second.averageDuration {
                return first.averageDuration < second.averageDuration
            }
            return first.plan.name < second.plan.name
        }
    }
}


/// A recommendation tailored to one saved/imported base. It is produced
/// locally from bounded prototype candidates and does not claim game-perfect AI.
nonisolated struct BaseStrategyRecommendation: Identifiable {
    let base: BaseSnapshot
    let evaluation: AttackPlanEvaluation
    let candidateCount: Int

    var id: UUID { base.id }
    var stars: Int { evaluation.stars }
    var destructionPercentage: Double {
        evaluation.destructionPercentage
    }
    var survivors: Int {
        evaluation.result.survivingTroops
    }
}

/// A batch of independently optimized recommendations, one for each base.
/// This differs from a robust plan: every base receives its own deploy plan.
nonisolated struct BaseStrategyBook {
    let recommendations: [BaseStrategyRecommendation]

    var baseCount: Int { recommendations.count }
    var threeStarCount: Int {
        recommendations.filter { $0.stars == 3 }.count
    }
    var averageStars: Double {
        guard !recommendations.isEmpty else { return 0 }
        return recommendations.map { Double($0.stars) }
            .reduce(0, +) / Double(recommendations.count)
    }
    var averageDestruction: Double {
        guard !recommendations.isEmpty else { return 0 }
        return recommendations.map(\.destructionPercentage)
            .reduce(0, +) / Double(recommendations.count)
    }
}
