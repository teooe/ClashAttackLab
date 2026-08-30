import Foundation

nonisolated struct DeploymentOrder: Identifiable, Codable {
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

nonisolated struct SpellDeploymentOrder: Identifiable, Codable {
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

nonisolated struct AttackPlan: Identifiable, Codable {
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

    var latestDeploymentTime: TimeInterval {
        (deployments.map(\.deploymentTime) +
            spellDeployments.map(\.deploymentTime)
        ).max() ?? 0
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


nonisolated enum ManualPlacementSelection: Hashable {
    case troop(BattleEntityKind)
    case spell(BattleSpellKind)
}

/// Mutable draft used by the on-arena manual deployment mode.
///
/// The draft stays separate from the simulation until the user starts it.
/// This keeps the automatic finder and user-created plans comparable.
nonisolated struct ManualAttackPlan: Identifiable {
    let id: UUID
    let name: String
    private(set) var deployments: [DeploymentOrder]
    private(set) var spellDeployments: [SpellDeploymentOrder]

    init(
        id: UUID = UUID(),
        name: String = "Piano manuale",
        deployments: [DeploymentOrder] = [],
        spellDeployments: [SpellDeploymentOrder] = []
    ) {
        self.id = id
        self.name = name
        self.deployments = deployments
        self.spellDeployments = spellDeployments
    }

    var totalOrderCount: Int {
        deployments.count + spellDeployments.count
    }

    var latestDeploymentTime: TimeInterval {
        (deployments.map(\.deploymentTime) +
            spellDeployments.map(\.deploymentTime)
        ).max() ?? 0
    }

    var orderedDeployments: [DeploymentOrder] {
        makeAttackPlan().orderedDeployments
    }

    var orderedSpellDeployments: [SpellDeploymentOrder] {
        makeAttackPlan().orderedSpellDeployments
    }

    func troopCount(for kind: BattleEntityKind) -> Int {
        deployments.filter { $0.kind == kind }.count
    }

    func spellCount(for kind: BattleSpellKind) -> Int {
        spellDeployments.filter { $0.kind == kind }.count
    }

    mutating func append(
        _ selection: ManualPlacementSelection,
        at position: WorldPosition,
        time: TimeInterval
    ) {
        switch selection {
        case .troop(let kind):
            deployments.append(
                DeploymentOrder(
                    kind: kind,
                    position: position,
                    deploymentTime: time
                )
            )

        case .spell(let kind):
            spellDeployments.append(
                SpellDeploymentOrder(
                    kind: kind,
                    position: position,
                    deploymentTime: time
                )
            )
        }
    }

    mutating func removeMostRecentOrder() {
        let troopTime = deployments.map(\.deploymentTime).max()
        let spellTime = spellDeployments.map(\.deploymentTime).max()

        switch (troopTime, spellTime) {
        case let (troopTime?, spellTime?):
            if troopTime >= spellTime {
                removeMostRecentTroop()
            } else {
                removeMostRecentSpell()
            }

        case (.some, .none):
            removeMostRecentTroop()

        case (.none, .some):
            removeMostRecentSpell()

        case (.none, .none):
            break
        }
    }

    mutating func removeAllOrders() {
        deployments.removeAll()
        spellDeployments.removeAll()
    }

    func makeAttackPlan() -> AttackPlan {
        AttackPlan(
            id: id,
            name: name,
            deployments: deployments,
            spellDeployments: spellDeployments
        )
    }

    private mutating func removeMostRecentTroop() {
        guard
            let index = deployments.indices.max(by: {
                deployments[$0].deploymentTime <
                    deployments[$1].deploymentTime
            })
        else {
            return
        }

        deployments.remove(at: index)
    }

    private mutating func removeMostRecentSpell() {
        guard
            let index = spellDeployments.indices.max(by: {
                spellDeployments[$0].deploymentTime <
                    spellDeployments[$1].deploymentTime
            })
        else {
            return
        }

        spellDeployments.remove(at: index)
    }
}
