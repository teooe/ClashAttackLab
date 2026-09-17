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

    /// Validate the whole document before touching the archive. Imported plans
    /// get new plan IDs; order and entity IDs remain scoped to each plan.
    @discardableResult
    func importArchive(_ data: Data, on grid: NavigationGrid) throws -> Int {
        let decoded = try AttackPlanArchiveCodec.decode(data, on: grid)
        let copies = decoded.map {
            AttackPlan(
                name: $0.name, deployments: $0.deployments,
                spellDeployments: $0.spellDeployments,
                heroAbilityOrders: $0.heroAbilityOrders
            )
        }
        let updated = copies + plans
        let encoded = try JSONEncoder().encode(updated)
        UserDefaults.standard.set(encoded, forKey: storageKey)
        plans = updated
        return copies.count
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


nonisolated struct AttackPlanArchive: Codable {
    let format: String
    let version: Int
    let profile: String
    let columns: Int
    let rows: Int
    let cellSize: Double
    let origin: WorldPosition
    let plans: [AttackPlan]
}

nonisolated enum AttackPlanArchiveError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self {
        case .invalid(let reason): return reason
        }
    }
}

/// Portable plan files describe orders on a compatible grid, not a base.
/// Limits are prototype constraints and are checked before any simulation.
nonisolated enum AttackPlanArchiveCodec {
    static let maximumBytes = 1_048_576
    static let maximumPlans = 50

    static func encode(_ plans: [AttackPlan], on grid: NavigationGrid) throws -> Data {
        try validate(plans, on: grid)
        let archive = AttackPlanArchive(
            format: "clash-attack-lab-plans", version: 1, profile: "prototype-v1",
            columns: grid.columns, rows: grid.rows, cellSize: grid.cellSize,
            origin: grid.origin, plans: plans
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(archive)
        guard data.count <= maximumBytes else {
            throw AttackPlanArchiveError.invalid("Archivio troppo grande: massimo 1 MB.")
        }
        return data
    }

    static func decode(_ data: Data, on grid: NavigationGrid) throws -> [AttackPlan] {
        guard data.count <= maximumBytes else {
            throw AttackPlanArchiveError.invalid("Archivio troppo grande: massimo 1 MB.")
        }
        let archive: AttackPlanArchive
        do {
            archive = try JSONDecoder().decode(AttackPlanArchive.self, from: data)
        } catch {
            throw AttackPlanArchiveError.invalid("Il file non contiene un archivio di piani valido.")
        }
        guard archive.format == "clash-attack-lab-plans",
            archive.version == 1, archive.profile == "prototype-v1" else {
            throw AttackPlanArchiveError.invalid("Formato o versione del simulatore non supportati.")
        }
        guard archive.columns == grid.columns, archive.rows == grid.rows,
            archive.cellSize == grid.cellSize, archive.origin == grid.origin else {
            throw AttackPlanArchiveError.invalid("Il piano usa una griglia diversa da quella del simulatore.")
        }
        try validate(archive.plans, on: grid)
        return archive.plans
    }

    static func validate(_ plans: [AttackPlan], on grid: NavigationGrid) throws {
        guard !plans.isEmpty, plans.count <= maximumPlans else {
            throw AttackPlanArchiveError.invalid("Seleziona da 1 a 50 piani.")
        }
        guard Set(plans.map(\.id)).count == plans.count else {
            throw AttackPlanArchiveError.invalid("L’archivio contiene identificativi di piano duplicati.")
        }
        for plan in plans {
            let name = plan.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.count <= 512 else {
                throw AttackPlanArchiveError.invalid("Nome piano mancante o troppo lungo.")
            }
            guard plan.deployments.count <= 128,
                plan.spellDeployments.count <= 4, plan.heroAbilityOrders.count <= 2 else {
                throw AttackPlanArchiveError.invalid("Il piano supera i limiti di ordini del prototipo.")
            }
            let orderIDs = plan.deployments.map(\.id) +
                plan.spellDeployments.map(\.id) + plan.heroAbilityOrders.map(\.id)
            guard Set(orderIDs).count == orderIDs.count,
                Set(plan.deployments.map(\.entityID)).count == plan.deployments.count else {
                throw AttackPlanArchiveError.invalid("Il piano contiene ordini o truppe con identificativi duplicati.")
            }
            for order in plan.deployments {
                guard isTroop(order.kind), validTime(order.deploymentTime),
                    inBounds(order.position, grid: grid),
                    let cell = grid.coordinate(for: order.position),
                    cell.column <= 2, grid.isWalkable(cell) else {
                    throw AttackPlanArchiveError.invalid("Deploy non valido: truppa, tempo o posizione fuori dalla fascia consentita.")
                }
            }
            for order in plan.spellDeployments {
                guard validTime(order.deploymentTime),
                    inBounds(order.position, grid: grid) else {
                    throw AttackPlanArchiveError.invalid("Incantesimo con tempo o posizione non validi.")
                }
            }
            guard plan.armyConfiguration.isValid else {
                throw AttackPlanArchiveError.invalid(
                    plan.armyConfiguration.validationMessage ?? "Esercito non valido."
                )
            }
            var commanded = Set<UUID>()
            for command in plan.heroAbilityOrders {
                guard validTime(command.activationTime),
                    commanded.insert(command.entityID).inserted,
                    let hero = plan.deployments.first(where: { $0.entityID == command.entityID }),
                    hero.kind == .barbarianKing || hero.kind == .archerQueen,
                    command.activationTime >= hero.deploymentTime else {
                    throw AttackPlanArchiveError.invalid("Comando eroe duplicato, senza eroe o precedente al suo deploy.")
                }
            }
        }
    }

    private static func validTime(_ time: TimeInterval) -> Bool {
        time.isFinite && (0...59).contains(time)
    }

    private static func inBounds(_ position: WorldPosition, grid: NavigationGrid) -> Bool {
        position.x.isFinite && position.y.isFinite &&
            position.x >= grid.origin.x && position.y >= grid.origin.y &&
            position.x < grid.origin.x + Double(grid.columns) * grid.cellSize &&
            position.y < grid.origin.y + Double(grid.rows) * grid.cellSize
    }

    private static func isTroop(_ kind: BattleEntityKind) -> Bool {
        switch kind {
        case .cannon, .archerTower, .mortar, .wizardTower, .infernoTower, .bombTower, .hiddenTesla, .giantBomb, .airSweeper, .airDefense, .townHall, .goldStorage, .wall:
            return false
        default:
            return true
        }
    }
}
