import Foundation

/// One step of an attack plan written for a person to follow by hand.
nonisolated struct PlanInstructionStep: Identifiable, Equatable {
    let id: Int
    /// Seconds from the start of the battle, rounded for reading.
    let time: TimeInterval
    let text: String

    var timeLabel: String {
        time < 1 ? "subito" : "~\(Int(time.rounded())) s"
    }
}

/// Turns an attack plan into numbered steps a player can repeat on a
/// phone: map sides and nearby buildings instead of coordinates, grouped
/// troops and spell chains instead of single orders.
nonisolated struct PlanInstructions {
    /// Buildings worth naming as landmarks, most recognizable first.
    static let landmarks: [BattleEntityKind] = [
        .townHall, .eagleArtillery, .infernoTower, .scattershot, .monolith,
        .xBow, .airDefense, .airSweeper, .clanCastle, .spellTower,
        .wizardTower, .bombTower, .archerTower, .cannon, .mortar
    ]

    /// Orders of the same troop this close in time and place are one step.
    static let groupingSeconds: TimeInterval = 1.5

    let navigationGrid: NavigationGrid
    let base: [BattleEntity]
    let gameData: any GameDataProviding

    func steps(for plan: AttackPlan) -> [PlanInstructionStep] {
        var events: [(time: TimeInterval, order: Int, text: String)] = []

        // Troops: one step per run of the same kind on the same side.
        var group: (kind: BattleEntityKind, time: TimeInterval, side: String, count: Int, position: WorldPosition)?
        func closeGroup() {
            guard let current = group else {
                return
            }
            let name = troopName(current.kind)
            let count = current.count > 1 ? "\(current.count) × " : ""
            events.append((
                current.time,
                events.count,
                "\(count)\(name) \(current.side)\(landmark(near: current.position, prefix: ", vicino a"))"
            ))
            group = nil
        }
        // Clan Castle troops riding a siege machine are part of its step.
        let carriers = Set(plan.deployments.filter { $0.kind.isSiegeMachine }.map(\.entityID))
        func isCarried(_ order: DeploymentOrder) -> Bool {
            order.carrierID.map(carriers.contains) ?? false
        }
        for order in plan.orderedDeployments where !isCarried(order) {
            let side = sideDescription(order.position)
            if order.recalledFrom != nil {
                closeGroup()
                events.append((
                    order.deploymentTime,
                    events.count,
                    "\(troopName(order.kind)) di nuovo in campo dal Richiamo \(side)" +
                        landmark(near: order.position, prefix: ", vicino a")
                ))
                continue
            }
            if
                let current = group,
                current.kind == order.kind,
                current.side == side,
                order.deploymentTime - current.time <= Self.groupingSeconds
            {
                group?.count += 1
                continue
            }
            closeGroup()
            group = (order.kind, order.deploymentTime, side, 1, order.position)
        }
        closeGroup()
        for carrier in plan.orderedDeployments where carriers.contains(carrier.entityID) {
            let riders = plan.orderedDeployments.filter { $0.carrierID == carrier.entityID }
            guard !riders.isEmpty else {
                continue
            }
            var counts: [(BattleEntityKind, Int)] = []
            for rider in riders {
                if let index = counts.firstIndex(where: { $0.0 == rider.kind }) {
                    counts[index].1 += 1
                } else {
                    counts.append((rider.kind, 1))
                }
            }
            let list = counts.map { "\($0.1) × \(troopName($0.0))" }.joined(separator: ", ")
            events.append((
                carrier.deploymentTime,
                events.count,
                "Nel \(troopName(carrier.kind)) le truppe del Castello: \(list); escono quando cade"
            ))
        }

        // Spells: a run of the same spell cast at a steady pace is one step.
        let spells = plan.orderedSpellDeployments
        var index = 0
        while index < spells.count {
            let first = spells[index]
            var last = index
            while
                last + 1 < spells.count,
                spells[last + 1].kind == first.kind
            {
                last += 1
            }
            let name = spellName(first.kind)
            if last == index {
                events.append((
                    first.deploymentTime,
                    events.count,
                    "\(name)\(landmark(near: first.position, prefix: " su"))"
                ))
            } else {
                let count = last - index + 1
                let pace = (spells[last].deploymentTime - first.deploymentTime) / Double(count - 1)
                let end = spells[last]
                events.append((
                    first.deploymentTime,
                    events.count,
                    "\(count) × \(name), una ogni ~\(Int(pace.rounded())) s" +
                        "\(landmark(near: first.position, prefix: ", partendo vicino a"))" +
                        "\(landmark(near: end.position, prefix: " fino a"))"
                ))
            }
            index = last + 1
        }

        // Hero abilities.
        for command in plan.orderedHeroAbilityOrders {
            guard let hero = plan.deployments.first(where: { $0.entityID == command.entityID }) else {
                continue
            }
            events.append((
                command.activationTime,
                events.count,
                "Abilità di \(troopName(hero.kind))"
            ))
        }

        return events
            .sorted { ($0.time, $0.order) < ($1.time, $1.order) }
            .enumerated()
            .map { PlanInstructionStep(id: $0.offset + 1, time: $0.element.time, text: $0.element.text) }
    }

    /// Steps as plain text, one per line, ready to paste anywhere.
    func text(for plan: AttackPlan) -> String {
        ([plan.name] + steps(for: plan).map { "\($0.id). [\($0.timeLabel)] \($0.text)" })
            .joined(separator: "\n")
    }

    // MARK: Wording

    private func troopName(_ kind: BattleEntityKind) -> String {
        gameData.definition(for: kind).displayName
    }

    private func spellName(_ kind: BattleSpellKind) -> String {
        gameData.spellDefinition(for: kind).displayName
    }

    /// Side of the map as drawn in the app, from the centre of the grid:
    /// "dal lato in alto a sinistra" and so on.
    func sideDescription(_ position: WorldPosition) -> String {
        let centreX = navigationGrid.origin.x + Double(navigationGrid.columns) * navigationGrid.cellSize / 2
        let centreY = navigationGrid.origin.y + Double(navigationGrid.rows) * navigationGrid.cellSize / 2
        let angle = atan2(position.y - centreY, position.x - centreX) * 180 / .pi
        let sectors = [
            "dal lato destro", "dall'angolo in alto a destra", "dal lato in alto",
            "dall'angolo in alto a sinistra", "dal lato sinistro",
            "dall'angolo in basso a sinistra", "dal lato in basso",
            "dall'angolo in basso a destra"
        ]
        let sector = Int(((angle + 360 + 22.5).truncatingRemainder(dividingBy: 360)) / 45)
        return sectors[min(max(sector, 0), sectors.count - 1)]
    }

    /// The most recognizable building within 6 tiles, or the closest
    /// building at all; empty on an empty base.
    func landmark(near position: WorldPosition, prefix: String) -> String {
        let reach = navigationGrid.cellSize * 6
        func gap(_ entity: BattleEntity) -> Double {
            hypot(entity.position.x - position.x, entity.position.y - position.y)
        }
        let buildings = base.filter {
            let role = gameData.definition(for: $0.kind).role
            return role == .defense || role == .building
        }
        for kind in Self.landmarks {
            if let match = buildings.filter({ $0.kind == kind && gap($0) <= reach }).min(by: { gap($0) < gap($1) }) {
                return "\(prefix) \(gameData.definition(for: match.kind).displayName)"
            }
        }
        guard let closest = buildings.min(by: { gap($0) < gap($1) }) else {
            return ""
        }
        return "\(prefix) \(gameData.definition(for: closest.kind).displayName)"
    }
}
