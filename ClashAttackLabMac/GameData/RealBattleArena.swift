import CoreGraphics
import Foundation

// MARK: - Arena

/// Everything that changes between the prototype lab and real battles:
/// map size, statistics, army limits and the bases under attack.
nonisolated struct BattleArena {
    let source: GameDataSource
    let navigationGrid: NavigationGrid
    let gameData: any GameDataProviding
    let armyRules: ArmyCapacityRules
    let defaultArmy: ArmyConfiguration
    let sceneSize: CGSize

    private let catalog: ReferenceGameCatalog?

    static var prototype: BattleArena {
        BattleArena(
            source: .prototype,
            navigationGrid: PrototypeBattleMap.makeNavigationGrid(),
            gameData: PrecomputedGameData(PrototypeGameData()),
            armyRules: .prototype,
            defaultArmy: .prototypeDefault,
            sceneSize: CGSize(width: 1_100, height: 760),
            catalog: nil
        )
    }

    static func make(
        for source: GameDataSource,
        catalog: () throws -> ReferenceGameCatalog = ReferenceGameCatalog.loadBundled
    ) throws -> BattleArena {
        switch source {
        case .prototype:
            return .prototype

        case .reference(let townHall):
            let catalog = try catalog()
            let grid = RealBattleMap.makeNavigationGrid()
            let rules = ArmyCapacityRules.real(
                townHall: townHall,
                catalog: catalog
            )
            return BattleArena(
                source: source,
                navigationGrid: grid,
                gameData: PrecomputedGameData(
                    ReferenceGameData(
                        catalog: catalog,
                        profile: ReferenceLevelProfile(townHall: townHall),
                        tileSize: grid.cellSize
                    )
                ),
                armyRules: rules,
                defaultArmy: ArmyConfiguration.realDefault(for: rules),
                sceneSize: RealBattleMap.sceneSize,
                catalog: catalog
            )
        }
    }

    var isReal: Bool {
        source != .prototype
    }

    func makeBaseEntities(layout: PrototypeBaseLayout) -> [BattleEntity] {
        guard
            let catalog,
            case .reference(let townHall) = source
        else {
            return PrototypeBattleMap.makeBaseEntities(
                navigationGrid: navigationGrid,
                layout: layout
            )
        }

        return RealBaseLayoutGenerator(
            catalog: catalog,
            townHall: townHall,
            navigationGrid: navigationGrid
        ).makeEntities(variant: layout)
    }

    func makeBaseSnapshot(layout: PrototypeBaseLayout) -> BaseSnapshot {
        guard isReal else {
            return BaseSnapshot.make(from: layout, navigationGrid: navigationGrid)
        }

        return BaseSnapshot.make(
            named: layout.displayName,
            entities: makeBaseEntities(layout: layout),
            navigationGrid: navigationGrid
        )
    }
}

// MARK: - Map

/// Real village battlefield: a 44×44 buildable area surrounded by a
/// three-tile deployment border, one world cell per game tile.
nonisolated enum RealBattleMap {
    static let buildableTiles = 44
    static let borderTiles = 3
    static let tileSize = 40.0

    static var gridTiles: Int {
        buildableTiles + borderTiles * 2
    }

    static let sceneSize = CGSize(width: 2_100, height: 2_300)

    static func makeNavigationGrid() -> NavigationGrid {
        NavigationGrid(
            columns: gridTiles,
            rows: gridTiles,
            cellSize: tileSize,
            origin: WorldPosition(x: 50, y: 110),
            blockedCells: []
        )
    }
}

// MARK: - Base generator

/// Builds a deterministic real base for a Town Hall from catalog counts
/// and footprints.
///
/// Buildings sit in 4×4-tile slots (a footprint up to 3×3 plus a one-tile
/// lane), arranged in square rings around the Town Hall. Walls follow the
/// lanes between rings and traps take free lane crossings, so nothing
/// overlaps. The three prototype layouts map to three wall and priority
/// patterns. Non-defensive buildings the simulator does not model yet
/// (collectors, camps, barracks…) are left out.
nonisolated struct RealBaseLayoutGenerator {
    private struct Variant {
        let wallRings: [Int]
        let priority: [BattleEntityKind]
        let rotation: Int
    }

    static let slotPitch = 4
    static let slotsPerSide = 11
    static let centerSlot = 5

    let catalog: ReferenceGameCatalog
    let townHall: Int
    let navigationGrid: NavigationGrid

    func makeEntities(variant layout: PrototypeBaseLayout) -> [BattleEntity] {
        let variant = Self.variant(for: layout)
        var entities: [BattleEntity] = []
        var occupied: Set<GridCoordinate> = []

        func place(
            _ kind: BattleEntityKind,
            column: Int,
            row: Int,
            size: Int
        ) {
            for tileColumn in column..<(column + size) {
                for tileRow in row..<(row + size) {
                    occupied.insert(
                        GridCoordinate(column: tileColumn, row: tileRow)
                    )
                }
            }
            entities.append(
                BattleEntity(
                    id: SimulationIdentity.make(
                        "real:\(layout.id):\(townHall):\(kind):\(column):\(row)"
                    ),
                    kind: kind,
                    position: center(column: column, row: row, size: size)
                )
            )
        }

        let townHallOrigin = slotOrigin(Self.centerSlot)
        place(.townHall, column: townHallOrigin, row: townHallOrigin, size: 4)

        let slots = orderedSlots(rotation: variant.rotation)
        let buildings = interleaved(variant.priority) +
            interleaved(Self.utilityPriority)
        for (kind, slot) in zip(buildings, slots) {
            let size = footprint(of: kind)
            let offset = size >= 3 ? 0 : 1
            place(
                kind,
                column: slotOrigin(slot.column) + offset,
                row: slotOrigin(slot.row) + offset,
                size: size
            )
        }

        let wallBudget = count(of: .wall)
        var wallCells: [GridCoordinate] = []
        for ring in variant.wallRings {
            let cells = wallRing(ring).filter { !occupied.contains($0) }
            guard wallCells.count + cells.count <= wallBudget else {
                break
            }
            wallCells += cells
            occupied.formUnion(cells)
        }

        let crossings = slots.map {
            GridCoordinate(
                column: slotOrigin($0.column) + Self.slotPitch - 1,
                row: slotOrigin($0.row) + Self.slotPitch - 1
            )
        }.filter { !occupied.contains($0) && navigationGrid.contains($0) }
        for (kind, cell) in zip(interleaved([.giantBomb, .airBomb]), crossings) {
            place(kind, column: cell.column, row: cell.row, size: 1)
        }

        entities += wallCells.map {
            BattleEntity(
                id: SimulationIdentity.make(
                    "real-wall:\(layout.id):\(townHall):\($0.column):\($0.row)"
                ),
                kind: .wall,
                position: navigationGrid.worldPosition(for: $0)
            )
        }
        return entities
    }

    // MARK: Geometry

    private func slotOrigin(_ slot: Int) -> Int {
        RealBattleMap.borderTiles + slot * Self.slotPitch
    }

    private func center(column: Int, row: Int, size: Int) -> WorldPosition {
        WorldPosition(
            x: navigationGrid.origin.x +
                (Double(column) + Double(size) / 2) * navigationGrid.cellSize,
            y: navigationGrid.origin.y +
                (Double(row) + Double(size) / 2) * navigationGrid.cellSize
        )
    }

    /// Slots ordered ring by ring from the Town Hall outward. Inside a
    /// ring, slots alternate between opposite sides to spread each kind.
    private func orderedSlots(rotation: Int) -> [GridCoordinate] {
        var result: [GridCoordinate] = []
        for ring in 1...Self.centerSlot {
            var ringSlots: [GridCoordinate] = []
            for column in 0..<Self.slotsPerSide {
                for row in 0..<Self.slotsPerSide where
                    max(
                        abs(column - Self.centerSlot),
                        abs(row - Self.centerSlot)
                    ) == ring
                {
                    ringSlots.append(GridCoordinate(column: column, row: row))
                }
            }
            ringSlots.sort {
                let first = angle(of: $0)
                let second = angle(of: $1)
                if first == second {
                    return $0.column == $1.column
                        ? $0.row < $1.row
                        : $0.column < $1.column
                }
                return first < second
            }
            let shift = rotation % ringSlots.count
            ringSlots = Array(ringSlots[shift...] + ringSlots[..<shift])

            let half = (ringSlots.count + 1) / 2
            for index in 0..<half {
                result.append(ringSlots[index])
                if index + half < ringSlots.count {
                    result.append(ringSlots[index + half])
                }
            }
        }
        return result
    }

    private func angle(of slot: GridCoordinate) -> Double {
        atan2(
            Double(slot.row - Self.centerSlot),
            Double(slot.column - Self.centerSlot)
        )
    }

    /// Wall cells on the lane around every slot within `ring` of the centre.
    private func wallRing(_ ring: Int) -> [GridCoordinate] {
        let low = slotOrigin(Self.centerSlot - ring) - 1
        let high = slotOrigin(Self.centerSlot + ring) + Self.slotPitch - 1
        var cells: [GridCoordinate] = []
        for column in low...high {
            cells.append(GridCoordinate(column: column, row: low))
            cells.append(GridCoordinate(column: column, row: high))
        }
        for row in (low + 1)..<high {
            cells.append(GridCoordinate(column: low, row: row))
            cells.append(GridCoordinate(column: high, row: row))
        }
        return cells
    }

    // MARK: Catalog

    private func count(of kind: BattleEntityKind) -> Int {
        catalog.unit(for: kind)?.count(atTownHall: townHall) ?? 0
    }

    private func footprint(of kind: BattleEntityKind) -> Int {
        min(max(catalog.unit(for: kind)?.size ?? 1, 1), Self.slotPitch)
    }

    /// Takes one of each kind in priority order until every count is used.
    private func interleaved(_ kinds: [BattleEntityKind]) -> [BattleEntityKind] {
        var remaining = kinds.map { count(of: $0) }
        var result: [BattleEntityKind] = []
        while remaining.contains(where: { $0 > 0 }) {
            for index in kinds.indices where remaining[index] > 0 {
                result.append(kinds[index])
                remaining[index] -= 1
            }
        }
        return result
    }

    /// Non-defensive buildings fill the rings after the defenses: the clan
    /// castle and storages first, collectors and huts on the outside.
    static let utilityPriority: [BattleEntityKind] = [
        .clanCastle, .elixirStorage, .darkElixirStorage, .laboratory,
        .spellFactory, .darkSpellFactory, .heroHall, .blacksmith, .petHouse,
        .workshop, .barracks, .darkBarracks, .armyCamp, .goldMine,
        .elixirCollector, .darkElixirDrill, .builderHut, .helperHut
    ]

    private static func variant(for layout: PrototypeBaseLayout) -> Variant {
        switch layout {
        case .fortress:
            return Variant(
                wallRings: [1, 3],
                priority: [
                    .infernoTower, .airDefense, .wizardTower, .bombTower,
                    .hiddenTesla, .mortar, .archerTower, .cannon,
                    .airSweeper, .goldStorage
                ],
                rotation: 0
            )
        case .corridor:
            return Variant(
                wallRings: [2, 4],
                priority: [
                    .goldStorage, .mortar, .airDefense, .wizardTower,
                    .infernoTower, .hiddenTesla, .cannon, .archerTower,
                    .bombTower, .airSweeper
                ],
                rotation: 3
            )
        case .doubleCore:
            return Variant(
                wallRings: [1, 2, 4],
                priority: [
                    .airDefense, .infernoTower, .goldStorage, .wizardTower,
                    .bombTower, .mortar, .hiddenTesla, .archerTower,
                    .cannon, .airSweeper
                ],
                rotation: 5
            )
        }
    }
}

// MARK: - Army

extension ArmyCapacityRules {
    /// Real camp and spell space, housing and unlocks at a Town Hall.
    nonisolated static func real(
        townHall: Int,
        catalog: ReferenceGameCatalog
    ) -> ArmyCapacityRules {
        var troopHousing: [BattleEntityKind: Int] = [:]
        var unlockedTroops: Set<BattleEntityKind> = []
        for kind in ArmyConfiguration.troopKinds {
            guard let unit = catalog.unit(for: kind) else {
                continue
            }
            if unit.unlockTownHall <= townHall {
                unlockedTroops.insert(kind)
            }
            // Heroes and siege machines do not use army camp space.
            if !Self.campFreeKinds.contains(kind) {
                troopHousing[kind] = unit.housingSpace ?? 0
            }
        }

        var spellHousing: [BattleSpellKind: Int] = [:]
        var unlockedSpells: Set<BattleSpellKind> = []
        for kind in ArmyConfiguration.spellKinds {
            guard let spell = catalog.spell(for: kind) else {
                continue
            }
            spellHousing[kind] = spell.housingSpace ?? 1
            if spell.unlockTownHall <= townHall {
                unlockedSpells.insert(kind)
            }
        }

        return ArmyCapacityRules(
            troopCapacity: catalog.army?.troops(atTownHall: townHall) ?? 0,
            spellCapacity: catalog.army?.spells(atTownHall: townHall) ?? 0,
            troopHousing: troopHousing,
            spellHousing: spellHousing,
            unlockedTroops: unlockedTroops,
            unlockedSpells: unlockedSpells,
            label: "Municipio \(townHall)"
        )
    }

    nonisolated static let campFreeKinds: Set<BattleEntityKind> = [
        .barbarianKing, .archerQueen, .wallWrecker, .stoneSlammer
    ]
}

extension ArmyConfiguration {
    /// A balanced mixed army that fills the real capacity with few, heavy
    /// units: wall breakers and giants open the way, dragons, balloons and
    /// wizards deal the damage, archers fill the last spaces.
    nonisolated static func realDefault(
        for rules: ArmyCapacityRules
    ) -> ArmyConfiguration {
        var army = ArmyConfiguration(
            giants: 0,
            barbarians: 0,
            archers: 0,
            wallBreakers: 0,
            wizards: 0,
            healSpells: 0,
            rageSpells: 0
        )
        var free = rules.troopCapacity

        func add(
            _ kind: BattleEntityKind,
            count: Int,
            to keyPath: WritableKeyPath<ArmyConfiguration, Int>
        ) {
            guard rules.allows(kind), count > 0 else {
                return
            }
            let housing = rules.housing(for: kind)
            let affordable = housing > 0 ? min(count, free / housing) : count
            army[keyPath: keyPath] += affordable
            free -= affordable * housing
        }

        add(.wallBreaker, count: 6, to: \.wallBreakers)
        add(.giant, count: 12, to: \.giants)
        add(
            .dragon,
            count: Int(Double(rules.troopCapacity) * 0.45) /
                max(rules.housing(for: .dragon), 1),
            to: \.dragons
        )
        add(
            .balloon,
            count: Int(Double(rules.troopCapacity) * 0.15) /
                max(rules.housing(for: .balloon), 1),
            to: \.balloons
        )
        add(.wizard, count: free / max(rules.housing(for: .wizard), 1), to: \.wizards)
        add(.archer, count: free, to: \.archers)
        add(.barbarianKing, count: 1, to: \.barbarianKings)
        add(.archerQueen, count: 1, to: \.archerQueens)
        add(.wallWrecker, count: 1, to: \.wallWreckers)

        var spellSpace = rules.spellCapacity
        let spellOrder: [(BattleSpellKind, WritableKeyPath<ArmyConfiguration, Int>)] = [
            (.rage, \.rageSpells),
            (.heal, \.healSpells),
            (.freeze, \.freezeSpells),
            (.lightning, \.lightningSpells),
            (.earthquake, \.earthquakeSpells)
        ]
        var added = true
        while added {
            added = false
            for (kind, keyPath) in spellOrder where rules.allows(kind) {
                let housing = max(rules.housing(for: kind), 1)
                if housing <= spellSpace {
                    army[keyPath: keyPath] += 1
                    spellSpace -= housing
                    added = true
                }
            }
        }

        return army
    }
}
