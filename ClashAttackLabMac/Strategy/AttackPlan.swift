import Foundation

nonisolated struct DeploymentOrder: Identifiable {
    let id: UUID
    let entityID: UUID
    let kind: BattleEntityKind
    let position: WorldPosition
    let deploymentTime: TimeInterval

    init(
        id: UUID = UUID(),
        entityID: UUID = UUID(),
        kind: BattleEntityKind,
        position: WorldPosition,
        deploymentTime: TimeInterval
    ) {
        self.id = id
        self.entityID = entityID
        self.kind = kind
        self.position = position
        self.deploymentTime = deploymentTime
    }
}

nonisolated struct SpellDeploymentOrder: Identifiable {
    let id: UUID
    let kind: BattleSpellKind
    let position: WorldPosition
    let deploymentTime: TimeInterval

    init(
        id: UUID = UUID(),
        kind: BattleSpellKind,
        position: WorldPosition,
        deploymentTime: TimeInterval
    ) {
        self.id = id
        self.kind = kind
        self.position = position
        self.deploymentTime = deploymentTime
    }
}

nonisolated struct AttackPlan: Identifiable {
    let id: UUID
    let name: String
    let deployments: [DeploymentOrder]
    let spellDeployments: [SpellDeploymentOrder]

    init(
        id: UUID = UUID(),
        name: String,
        deployments: [DeploymentOrder],
        spellDeployments: [SpellDeploymentOrder] = []
    ) {
        self.id = id
        self.name = name
        self.deployments = deployments
        self.spellDeployments = spellDeployments
    }

    var orderedDeployments: [DeploymentOrder] {
        deployments.sorted {
            if $0.deploymentTime == $1.deploymentTime {
                return $0.id.uuidString < $1.id.uuidString
            }

            return $0.deploymentTime < $1.deploymentTime
        }
    }

    var orderedSpellDeployments: [SpellDeploymentOrder] {
        spellDeployments.sorted {
            if $0.deploymentTime == $1.deploymentTime {
                return $0.id.uuidString < $1.id.uuidString
            }

            return $0.deploymentTime < $1.deploymentTime
        }
    }

    var totalDeploymentCount: Int {
        deployments.count
    }

    var totalSpellCount: Int {
        spellDeployments.count
    }

    var troopKindsInDeploymentOrder: [BattleEntityKind] {
        var seen: Set<BattleEntityKind> = []

        return orderedDeployments.compactMap { deployment in
            guard seen.insert(deployment.kind).inserted else {
                return nil
            }

            return deployment.kind
        }
    }

    func deploymentCount(for kind: BattleEntityKind) -> Int {
        deployments.filter { $0.kind == kind }.count
    }
}
