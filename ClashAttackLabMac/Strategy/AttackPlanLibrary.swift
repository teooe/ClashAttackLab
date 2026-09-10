import Combine
import Foundation

/// Local plan archive. Plans are stored as JSON in UserDefaults so the
/// simulator remains self-contained and does not require a server or database.
final class AttackPlanLibrary: ObservableObject {
    @Published private(set) var plans: [AttackPlan] = []

    private let storageKey: String

    init(storageKey: String = "clashAttackLab.savedAttackPlans") {
        self.storageKey = storageKey
        load()
    }

    func save(_ plan: AttackPlan) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else {
            plans.insert(plan, at: 0)
        }
        persist()
    }

    func rename(_ plan: AttackPlan, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = plans.firstIndex(where: { $0.id == plan.id }) else {
            return
        }

        plans[index] = AttackPlan(
            id: plan.id,
            name: trimmed,
            deployments: plan.deployments,
            spellDeployments: plan.spellDeployments,
            heroAbilityOrders: plan.heroAbilityOrders
        )
        persist()
    }

    @discardableResult
    func duplicate(_ plan: AttackPlan) -> AttackPlan {
        let copy = AttackPlan(
            name: "\(plan.name) · copia",
            // Orders are value types, scoped to each plan. Keeping their IDs
            // also preserves tie-breaking and hero-command references.
            deployments: plan.deployments,
            spellDeployments: plan.spellDeployments,
            heroAbilityOrders: plan.heroAbilityOrders
        )
        plans.insert(copy, at: 0)
        persist()
        return copy
    }

    func delete(_ plan: AttackPlan) {
        plans.removeAll { $0.id == plan.id }
        persist()
    }

    func move(from offsets: IndexSet, to destination: Int) {
        let moving = offsets.sorted().map { plans[$0] }
        let remaining = plans.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)
        let insertionIndex = min(destination, remaining.count)
        var reordered = remaining
        reordered.insert(contentsOf: moving, at: insertionIndex)
        plans = reordered
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(
                [AttackPlan].self,
                from: data
              ) else {
            plans = []
            return
        }

        plans = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(plans) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
