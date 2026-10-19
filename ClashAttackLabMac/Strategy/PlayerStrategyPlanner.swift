import Foundation

/// The player's own attack, rebuilt on any base:
///
/// 1. the Royal Champion walks to the Eagle Artillery under a chain of
///    Invisibility Spells and fires her ability when they run out;
/// 2. the Archer Queen follows towards the Air Sweepers and uses her
///    ability on them;
/// 3. the rest of the army, with the Grand Warden, heads for the Town
///    Hall, the Rage Spell landing on their way;
/// 4. the Dragon Duke comes last in support.
nonisolated struct PlayerStrategyPlanner {
    static let planName = "La mia strategia"

    /// Seconds between two Invisibility Spells on the Champion.
    static let invisibilityInterval: TimeInterval = 4

    let navigationGrid: NavigationGrid
    let latestOrderTime: TimeInterval

    func plan(
        for army: ArmyConfiguration,
        against base: [BattleEntity]
    ) -> AttackPlan? {
        guard let townHall = base.first(where: { $0.kind == .townHall }) ?? base.first else {
            return nil
        }
        let eagle = base.first { $0.kind == .eagleArtillery } ??
            AttackPlanGenerator.overgrowthTarget(in: base) ??
            townHall
        let sweepers = base.filter { $0.kind == .airSweeper }

        var deployments: [DeploymentOrder] = []
        var spells: [SpellDeploymentOrder] = []
        var abilities: [HeroAbilityOrder] = []
        var clock: TimeInterval = 0

        func time(_ value: TimeInterval) -> TimeInterval {
            min(max(0, value), latestOrderTime)
        }

        // 1. Champion and the Invisibility chain.
        let championStart = edgeCell(nearest: eagle.position)
        var championID: UUID?
        if army[troop: .royalChampion] > 0 {
            let order = DeploymentOrder(kind: .royalChampion, position: championStart, deploymentTime: 0)
            championID = order.entityID
            deployments.append(order)
        }
        let invisibilities = army[spell: .invisibility]
        for index in 0..<invisibilities {
            // Along her walk: early casts near the edge, the last ones on
            // the Eagle.
            let progress = min(1, Double(index + 1) / Double(max(invisibilities / 2, 1)))
            spells.append(SpellDeploymentOrder(
                kind: .invisibility,
                position: interpolate(championStart, eagle.position, progress),
                deploymentTime: time(2 + Double(index) * Self.invisibilityInterval)
            ))
        }
        clock = 2 + Double(invisibilities) * Self.invisibilityInterval
        if let championID {
            abilities.append(HeroAbilityOrder(entityID: championID, activationTime: time(clock)))
        }

        // 2. Queen towards the Air Sweepers.
        clock += 1
        if army[troop: .archerQueen] > 0 {
            let goal = sweepers.min {
                distance($0.position, championStart) < distance($1.position, championStart)
            }?.position ?? eagle.position
            let order = DeploymentOrder(kind: .archerQueen, position: edgeCell(nearest: goal), deploymentTime: time(clock))
            deployments.append(order)
            abilities.append(HeroAbilityOrder(entityID: order.entityID, activationTime: time(clock + 6)))
        }

        // 3. The army and the Warden towards the Town Hall.
        clock += 4
        let troopStart = edgeCell(nearest: townHall.position)
        let lane = laneDirection(at: troopStart)
        let troopKinds = army.deploymentSequence.filter {
            !$0.isHero && !$0.isSiegeMachine
        }
        for (index, kind) in troopKinds.enumerated() {
            let offset = Double(index % 9 - 4) * navigationGrid.cellSize
            deployments.append(DeploymentOrder(
                kind: kind,
                position: snapped(WorldPosition(
                    x: troopStart.x + lane.x * offset,
                    y: troopStart.y + lane.y * offset
                )),
                deploymentTime: time(clock + Double(index) * 0.2)
            ))
        }
        for kind in BattleEntityKind.siegeMachineKinds where army[troop: kind] > 0 {
            deployments.append(DeploymentOrder(kind: kind, position: troopStart, deploymentTime: time(clock)))
        }
        let troopsDone = clock + Double(troopKinds.count) * 0.2
        if army[troop: .grandWarden] > 0 {
            let order = DeploymentOrder(kind: .grandWarden, position: troopStart, deploymentTime: time(troopsDone))
            deployments.append(order)
            abilities.append(HeroAbilityOrder(entityID: order.entityID, activationTime: time(troopsDone + 15)))
        }
        for _ in 0..<army[spell: .rage] {
            spells.append(SpellDeploymentOrder(
                kind: .rage,
                position: interpolate(troopStart, townHall.position, 0.6),
                deploymentTime: time(troopsDone + 8)
            ))
        }

        // 4. Dragon Duke in support, then any other hero.
        let lateHeroes = [BattleEntityKind.dragonDuke, .barbarianKing]
            .filter { army[troop: $0] > 0 }
        for (index, hero) in lateHeroes.enumerated() {
            deployments.append(DeploymentOrder(
                kind: hero,
                position: troopStart,
                deploymentTime: time(troopsDone + 6 + Double(index) * 2)
            ))
        }

        guard !deployments.isEmpty else {
            return nil
        }
        return AttackPlan(
            name: Self.planName,
            deployments: deployments,
            spellDeployments: spells,
            heroAbilityOrders: abilities
        )
    }

    // MARK: Geometry

    private func distance(_ first: WorldPosition, _ second: WorldPosition) -> Double {
        hypot(first.x - second.x, first.y - second.y)
    }

    private func interpolate(_ from: WorldPosition, _ to: WorldPosition, _ fraction: Double) -> WorldPosition {
        WorldPosition(
            x: from.x + (to.x - from.x) * fraction,
            y: from.y + (to.y - from.y) * fraction
        )
    }

    /// Centre of the deployment cell closest to `position`.
    private func edgeCell(nearest position: WorldPosition) -> WorldPosition {
        var best: GridCoordinate?
        var shortest = Double.infinity
        for row in 0..<navigationGrid.rows {
            for column in 0..<navigationGrid.columns {
                let cell = GridCoordinate(column: column, row: row)
                guard navigationGrid.isDeploymentCell(cell) else {
                    continue
                }
                let gap = distance(navigationGrid.worldPosition(for: cell), position)
                if gap < shortest {
                    shortest = gap
                    best = cell
                }
            }
        }
        return best.map { navigationGrid.worldPosition(for: $0) } ?? position
    }

    /// The deployment cell closest to `position`, so spread troops stay
    /// on legal ground.
    private func snapped(_ position: WorldPosition) -> WorldPosition {
        edgeCell(nearest: position)
    }

    /// Unit vector along the map edge at `position`.
    private func laneDirection(at position: WorldPosition) -> WorldPosition {
        let minimumX = navigationGrid.origin.x
        let minimumY = navigationGrid.origin.y
        let maximumX = minimumX + Double(navigationGrid.columns) * navigationGrid.cellSize
        let maximumY = minimumY + Double(navigationGrid.rows) * navigationGrid.cellSize
        let toVerticalEdge = min(position.x - minimumX, maximumX - position.x)
        let toHorizontalEdge = min(position.y - minimumY, maximumY - position.y)
        // On a left or right edge spread up and down, otherwise sideways.
        return toVerticalEdge < toHorizontalEdge
            ? WorldPosition(x: 0, y: 1)
            : WorldPosition(x: 1, y: 0)
    }
}
