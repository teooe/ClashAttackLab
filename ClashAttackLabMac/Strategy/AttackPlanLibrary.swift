import Combine
import Foundation

/// Local plan archive. Plans are stored as JSON in UserDefaults so the
/// simulator remains self-contained and does not require a server or database.
final class AttackPlanLibrary: ObservableObject {
    @Published private(set) var plans: [AttackPlan] = []

    private let storageKey = "clashAttackLab.savedAttackPlans"

    init() {
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
            spellDeployments: plan.spellDeployments
        )
        persist()
    }

    @discardableResult
    func duplicate(_ plan: AttackPlan) -> AttackPlan {
        let copy = AttackPlan(
            name: "\(plan.name) · copia",
            deployments: plan.deployments.map {
                DeploymentOrder(
                    kind: $0.kind,
                    position: $0.position,
                    deploymentTime: $0.deploymentTime
                )
            },
            spellDeployments: plan.spellDeployments.map {
                SpellDeploymentOrder(
                    kind: $0.kind,
                    position: $0.position,
                    deploymentTime: $0.deploymentTime
                )
            }
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
        plans.move(fromOffsets: offsets, toOffset: destination)
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
