import Foundation

struct DeploymentOrder: Identifiable {
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

struct AttackPlan {
    let name: String
    let deployments: [DeploymentOrder]

    var orderedDeployments: [DeploymentOrder] {
        deployments.sorted {
            if $0.deploymentTime == $1.deploymentTime {
                return $0.id.uuidString < $1.id.uuidString
            }

            return $0.deploymentTime < $1.deploymentTime
        }
    }
}
