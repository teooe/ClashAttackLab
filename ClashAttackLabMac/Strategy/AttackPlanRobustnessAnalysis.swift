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
struct AttackPlanRobustnessAnalysis: Identifiable {
    let plan: AttackPlan
    let entries: [BaseAttackEvaluation]

    var id: UUID {
        plan.id
    }

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

    /// Lowest outcome by stars, then destruction on that same base.
    var weakestEntry: BaseAttackEvaluation? {
        entries.min {
            if $0.evaluation.stars != $1.evaluation.stars {
                return $0.evaluation.stars < $1.evaluation.stars
            }
            if $0.evaluation.destructionPercentage != $1.evaluation.destructionPercentage {
                return $0.evaluation.destructionPercentage < $1.evaluation.destructionPercentage
            }
            return $0.layout.id < $1.layout.id
        }
    }

    var weakestBaseSummary: String {
        guard let entry = weakestEntry else { return "Nessuna base valutata" }
        return "Base peggiore: \(entry.layout.displayName) · \(entry.evaluation.stars)★ · \(String(format: "%.1f", entry.evaluation.destructionPercentage))%"
    }

    var threeStarCount: Int {
        entries.filter { $0.evaluation.stars == 3 }.count
    }

    /// Difference between the best and worst destruction outcome.
    var destructionSpread: Double {
        guard
            let minimum = entries.map(\.evaluation.destructionPercentage).min(),
            let maximum = entries.map(\.evaluation.destructionPercentage).max()
        else { return 0 }
        return maximum - minimum
    }

    /// Repeatable label derived only from the curated base results.
    var stabilityLabel: String {
        switch destructionSpread {
        case ..<12: return "Molto stabile"
        case ..<28: return "Stabile"
        case ..<45: return "Variabile"
        default: return "Fragile"
        }
    }

    var reliabilitySummary: String {
        "\(stabilityLabel) · escursione \(String(format: "%.1f", destructionSpread))%"
    }
}


nonisolated enum RobustnessObjective: String, CaseIterable, Identifiable {
    case average
    case weakestBase
    var id: String { rawValue }
    var title: String {
        switch self {
        case .average: return "Media"
        case .weakestBase: return "Base peggiore"
        }
    }
    var explanation: String {
        switch self {
        case .average:
            return "Ordina per stelle medie, distruzione, superstiti e durata."
        case .weakestBase:
            return "Privilegia stelle e distruzione sulla base peggiore; a parità confronta le medie."
        }
    }
}

/// Human-readable reason for the difference between two ranked plans.
nonisolated enum StrategyComparisonExplanation {
    static func text(
        winner: AttackPlanRobustnessAnalysis,
        runnerUp: AttackPlanRobustnessAnalysis,
        objective: RobustnessObjective
    ) -> String {
        if objective == .weakestBase {
            let winnerWorst = winner.weakestEntry?.evaluation.destructionPercentage ?? 0
            let runnerWorst = runnerUp.weakestEntry?.evaluation.destructionPercentage ?? 0
            let gap = winnerWorst - runnerWorst
            if abs(gap) >= 0.05 {
                return "Scelto per il caso peggiore: +\(String(format: "%.1f", gap))% sulla base più difficile."
            }
        }
        let starsGap = winner.averageStars - runnerUp.averageStars
        if abs(starsGap) >= 0.01 {
            return "Scelto per +\(String(format: "%.2f", starsGap)) stelle medie rispetto al secondo."
        }
        let destructionGap = winner.averageDestruction - runnerUp.averageDestruction
        if abs(destructionGap) >= 0.05 {
            return "Scelto per +\(String(format: "%.1f", destructionGap))% di distruzione media."
        }
        let stabilityGap = runnerUp.destructionSpread - winner.destructionSpread
        if abs(stabilityGap) >= 0.05 {
            return "Risultato simile, ma più stabile: escursione ridotta di \(String(format: "%.1f", stabilityGap)) punti."
        }
        return "Risultato quasi equivalente: la scelta segue i criteri deterministici di superstiti e durata."
    }
}

/// Deterministic ordering used when comparing saved strategies across bases.
enum AttackPlanRobustnessRanker {
    static func rank(
        _ analyses: [AttackPlanRobustnessAnalysis],
        objective: RobustnessObjective = .average
    ) -> [AttackPlanRobustnessAnalysis] {
        analyses.sorted { first, second in
            if first.entries.isEmpty != second.entries.isEmpty {
                return !first.entries.isEmpty
            }
            if objective == .weakestBase {
                let firstStars = first.weakestEntry?.evaluation.stars ?? 0
                let secondStars = second.weakestEntry?.evaluation.stars ?? 0
                if firstStars != secondStars { return firstStars > secondStars }
                let firstDestruction = first.weakestEntry?.evaluation.destructionPercentage ?? 0
                let secondDestruction = second.weakestEntry?.evaluation.destructionPercentage ?? 0
                if firstDestruction != secondDestruction {
                    return firstDestruction > secondDestruction
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
