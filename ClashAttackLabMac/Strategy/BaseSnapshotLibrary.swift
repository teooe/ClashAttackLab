import Foundation

/// Persistent local library for editable and imported base snapshots.
final class BaseSnapshotLibrary {
    private(set) var bases: [BaseSnapshot] = []

    private let storageKey: String

    init(storageKey: String = "clashAttackLab.baseSnapshotLibrary") {
        self.storageKey = storageKey

        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(
                [BaseSnapshot].self,
                from: data
            )
        else {
            return
        }

        bases = decoded
    }

    func save(_ snapshot: BaseSnapshot) {
        if let index = bases.firstIndex(where: { $0.id == snapshot.id }) {
            bases[index] = snapshot
        } else {
            bases.insert(snapshot, at: 0)
        }

        persist()
    }

    func delete(_ snapshot: BaseSnapshot) {
        bases.removeAll { $0.id == snapshot.id }
        persist()
    }

    func clear() {
        bases = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(bases) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }
}


/// Durable strategy recommendation tied to the exact snapshot it was evaluated
/// against. Results are prototype estimates, retained for comparison/replay.
nonisolated struct BaseStrategyRecord: Identifiable, Codable {
    let id: UUID
    let savedAt: Date
    let base: BaseSnapshot
    let plan: AttackPlan
    let stars: Int
    let destructionPercentage: Double
    let survivingTroops: Int
    let duration: TimeInterval
    let candidateCount: Int

    init(
        id: UUID = UUID(),
        savedAt: Date = Date(),
        recommendation: BaseStrategyRecommendation
    ) {
        self.id = id
        self.savedAt = savedAt
        self.base = recommendation.base
        self.plan = recommendation.evaluation.plan
        self.stars = recommendation.stars
        self.destructionPercentage = recommendation.destructionPercentage
        self.survivingTroops = recommendation.survivors
        self.duration = recommendation.evaluation.result.elapsedTime
        self.candidateCount = recommendation.candidateCount
    }
}

/// Small local archive of the latest recommended plan for each saved base.
final class BaseStrategyLibrary {
    private(set) var records: [BaseStrategyRecord] = []

    private let storageKey: String

    init(storageKey: String = "clashAttackLab.baseStrategyLibrary") {
        self.storageKey = storageKey
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(
                [BaseStrategyRecord].self,
                from: data
            )
        else {
            return
        }
        records = decoded
    }

    func save(_ newRecords: [BaseStrategyRecord]) {
        for record in newRecords {
            if let index = records.firstIndex(where: {
                $0.base.id == record.base.id
            }) {
                records[index] = record
            } else {
                records.insert(record, at: 0)
            }
        }
        records.sort { $0.savedAt > $1.savedAt }
        persist()
    }

    func delete(_ record: BaseStrategyRecord) {
        records.removeAll { $0.id == record.id }
        persist()
    }

    func clear() {
        records = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else {
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
