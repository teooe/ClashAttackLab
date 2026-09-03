import Combine
import Foundation

/// A compact, persistent record of one completed battle.
struct AttackHistoryEntry: Identifiable, Codable {
    let id: UUID
    let planID: UUID
    let planName: String
    /// Stored for battles recorded by recent app versions.
    /// Older local history entries decode with nil and remain visible.
    let attackPlan: AttackPlan?
    let baseLayout: PrototypeBaseLayout?
    let completedAt: Date
    let winnerName: String
    let finishReasonName: String
    let stars: Int
    let destructionPercentage: Double
    let elapsedTime: TimeInterval
    let survivingTroops: Int
    let troopsLost: Int
    let damageToBase: Double
    let spellsCast: Int
    let destroyedWalls: Int

    init(
        id: UUID = UUID(),
        plan: AttackPlan,
        result: SimulationResult,
        baseLayout: PrototypeBaseLayout? = nil,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.planID = plan.id
        self.planName = plan.name
        self.attackPlan = plan
        self.baseLayout = baseLayout
        self.completedAt = completedAt
        self.winnerName = result.winner.displayName
        self.finishReasonName = result.finishReason.displayName
        self.stars = result.score.stars
        self.destructionPercentage = result.score.destructionPercentage
        self.elapsedTime = result.elapsedTime
        self.survivingTroops = result.survivingTroops
        self.troopsLost = result.metrics.troopsLost
        self.damageToBase = result.metrics.damageToBase
        self.spellsCast = result.metrics.spellsCast
        self.destroyedWalls = result.metrics.destroyedWalls
    }
}

final class AttackHistoryStore: ObservableObject {
    @Published private(set) var entries: [AttackHistoryEntry] = []

    private let storageKey = "clashAttackLab.attackHistory"

    init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(
                [AttackHistoryEntry].self,
                from: data
              ) else {
            return
        }

        entries = decoded
    }

    func record(_ entry: AttackHistoryEntry) {
        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(50))
        persist()
    }

    func clear() {
        entries = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }
}


/// Aggregated performance indicators for the local battle archive.
struct AttackHistorySummary {
    let entries: [AttackHistoryEntry]

    var battleCount: Int {
        entries.count
    }

    var averageStars: Double {
        guard !entries.isEmpty else {
            return 0
        }

        return entries.map { Double($0.stars) }.reduce(0, +) /
            Double(entries.count)
    }

    var averageDestruction: Double {
        guard !entries.isEmpty else {
            return 0
        }

        return entries.map(\.destructionPercentage).reduce(0, +) /
            Double(entries.count)
    }

    var bestEntry: AttackHistoryEntry? {
        entries.max { first, second in
            if first.stars != second.stars {
                return first.stars < second.stars
            }

            if first.destructionPercentage != second.destructionPercentage {
                return first.destructionPercentage <
                    second.destructionPercentage
            }

            return first.survivingTroops < second.survivingTroops
        }
    }

    var replayableCount: Int {
        entries.filter { $0.attackPlan != nil && $0.baseLayout != nil }.count
    }
}
