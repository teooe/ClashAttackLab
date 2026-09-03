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
