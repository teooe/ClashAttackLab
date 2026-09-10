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

/// An explicit command applied at the end of a fixed simulation step.
/// Entity identity, rather than troop kind, keeps commands unambiguous.
nonisolated struct HeroAbilityOrder: Identifiable, Codable {
    let id: UUID
    let entityID: UUID
    let activationTime: TimeInterval

    init(id: UUID = UUID(), entityID: UUID, activationTime: TimeInterval) {
        self.id = id
        self.entityID = entityID
        self.activationTime = activationTime
    }
}

nonisolated struct AttackPlan: Identifiable, Codable {
    let id: UUID
    let name: String
    let deployments: [DeploymentOrder]
    let spellDeployments: [SpellDeploymentOrder]
    let heroAbilityOrders: [HeroAbilityOrder]

    init(
        id: UUID = UUID(),
        name: String,
        deployments: [DeploymentOrder],
        spellDeployments: [SpellDeploymentOrder] = [],
        heroAbilityOrders: [HeroAbilityOrder] = []
    ) {
        self.id = id
        self.name = name
        self.deployments = deployments
        self.spellDeployments = spellDeployments
        self.heroAbilityOrders = heroAbilityOrders
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, deployments, spellDeployments, heroAbilityOrders
    }

    // Existing archives predate hero commands and remain readable.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        deployments = try values.decode([DeploymentOrder].self, forKey: .deployments)
        spellDeployments = try values.decodeIfPresent(
            [SpellDeploymentOrder].self, forKey: .spellDeployments
        ) ?? []
        heroAbilityOrders = try values.decodeIfPresent(
            [HeroAbilityOrder].self, forKey: .heroAbilityOrders
        ) ?? []
    }

    var orderedHeroAbilityOrders: [HeroAbilityOrder] {
        heroAbilityOrders.filter {
            $0.activationTime.isFinite && $0.activationTime >= 0
        }.sorted {
            if $0.activationTime == $1.activationTime {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.activationTime < $1.activationTime
        }
    }

    func recordingHeroAbility(_ order: HeroAbilityOrder) -> AttackPlan {
        AttackPlan(
            id: id, name: name, deployments: deployments,
            spellDeployments: spellDeployments,
            heroAbilityOrders: heroAbilityOrders.filter {
                $0.entityID != order.entityID
            } + [order]
        )
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
            spellDeployments.map(\.deploymentTime) +
            heroAbilityOrders.map(\.activationTime)
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
    private(set) var heroAbilityOrders: [HeroAbilityOrder]

    init(
        id: UUID = UUID(),
        name: String = "Piano manuale",
        deployments: [DeploymentOrder] = [],
        spellDeployments: [SpellDeploymentOrder] = [],
        heroAbilityOrders: [HeroAbilityOrder] = []
    ) {
        self.id = id
        self.name = name
        self.deployments = deployments
        self.spellDeployments = spellDeployments
        self.heroAbilityOrders = heroAbilityOrders
    }

    var totalOrderCount: Int {
        deployments.count + spellDeployments.count + heroAbilityOrders.count
    }

    var latestDeploymentTime: TimeInterval {
        (deployments.map(\.deploymentTime) +
            spellDeployments.map(\.deploymentTime) +
            heroAbilityOrders.map(\.activationTime)
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

    var heroDeployments: [DeploymentOrder] {
        orderedDeployments.filter {
            ($0.kind == .barbarianKing || $0.kind == .archerQueen) &&
                $0.deploymentTime.isFinite &&
                (0...59).contains($0.deploymentTime)
        }
    }

    mutating func setHeroAbilityTime(entityID: UUID, to time: TimeInterval) {
        guard time.isFinite,
            let deployment = heroDeployments.first(where: { $0.entityID == entityID })
        else { return }
        let boundedTime = min(59, max(deployment.deploymentTime, time))
        let existingID = heroAbilityOrders.first { $0.entityID == entityID }?.id
        heroAbilityOrders.removeAll { $0.entityID == entityID }
        heroAbilityOrders.append(HeroAbilityOrder(
            id: existingID ?? UUID(), entityID: entityID,
            activationTime: boundedTime
        ))
    }

    mutating func removeHeroAbility(entityID: UUID) {
        heroAbilityOrders.removeAll { $0.entityID == entityID }
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

    mutating func removeOrder(id: UUID) {
        let removedIDs = Set(deployments.filter { $0.id == id }.map(\.entityID))
        heroAbilityOrders.removeAll { removedIDs.contains($0.entityID) }
        deployments.removeAll { $0.id == id }
        spellDeployments.removeAll { $0.id == id }
    }

    mutating func updateOrderTime(id: UUID, to time: TimeInterval) {
        if let index = deployments.firstIndex(where: { $0.id == id }) {
            let order = deployments[index]
            deployments[index] = DeploymentOrder(
                id: order.id,
                entityID: order.entityID,
                kind: order.kind,
                position: order.position,
                deploymentTime: min(59, max(0, time))
            )
            let newTime = min(59, max(0, time))
            heroAbilityOrders = heroAbilityOrders.map { command in
                guard command.entityID == order.entityID else { return command }
                return HeroAbilityOrder(
                    id: command.id, entityID: command.entityID,
                    activationTime: min(59, max(newTime,
                        command.activationTime + newTime - order.deploymentTime))
                )
            }
            return
        }

        if let index = spellDeployments.firstIndex(where: { $0.id == id }) {
            let order = spellDeployments[index]
            spellDeployments[index] = SpellDeploymentOrder(
                id: order.id,
                kind: order.kind,
                position: order.position,
                deploymentTime: min(59, max(0, time))
            )
        }
    }

    mutating func removeMostRecentOrder() {
        let latestDeployment = (deployments.map(\.deploymentTime) +
            spellDeployments.map(\.deploymentTime)).max() ?? -1
        if let command = heroAbilityOrders.max(by: {
            $0.activationTime < $1.activationTime
        }), command.activationTime >= latestDeployment {
            removeHeroAbility(entityID: command.entityID)
            return
        }
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
        heroAbilityOrders.removeAll()
    }

    func makeAttackPlan() -> AttackPlan {
        AttackPlan(
            id: id,
            name: name,
            deployments: deployments,
            spellDeployments: spellDeployments,
            heroAbilityOrders: heroAbilityOrders
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

        removeOrder(id: deployments[index].id)
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
