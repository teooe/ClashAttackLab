import Foundation

nonisolated struct NavigationGrid {
    let columns: Int
    let rows: Int
    let cellSize: Double
    let origin: WorldPosition
    let blockedCells: Set<GridCoordinate>

    static let prototypeColumns = 25
    static let prototypeRows = 16

    /// Grids larger than the prototype arena switch to cheaper heuristics,
    /// such as considering only the nearest candidate targets.
    var isLarge: Bool {
        columns * rows > 1_000
    }

    /// On large grids keeps only the `limit` entities closest to `position`,
    /// bounding the number of A* searches; small grids keep every entity.
    func routingCandidates(
        _ entities: [BattleEntity],
        near position: WorldPosition,
        limit: Int = 6
    ) -> [BattleEntity] {
        guard isLarge, entities.count > limit else {
            return entities
        }
        func squaredDistance(_ entity: BattleEntity) -> Double {
            let deltaX = entity.position.x - position.x
            let deltaY = entity.position.y - position.y
            return deltaX * deltaX + deltaY * deltaY
        }
        return Array(entities.sorted {
            let first = squaredDistance($0)
            let second = squaredDistance($1)
            return first == second
                ? $0.id.uuidString < $1.id.uuidString
                : first < second
        }.prefix(limit))
    }

    /// Maps a row chosen for the 16-row prototype arena onto this grid.
    func scaledRow(fromPrototype row: Int) -> Int {
        guard rows != Self.prototypeRows else {
            return row
        }
        let scaled = Int(
            (Double(row) + 0.5) * Double(rows) / Double(Self.prototypeRows)
        )
        return min(max(scaled, 0), rows - 1)
    }

    /// Maps a column chosen for the 25-column prototype arena onto this grid.
    func scaledColumn(fromPrototype column: Int) -> Int {
        guard columns != Self.prototypeColumns else {
            return column
        }
        let scaled = Int(
            (Double(column) + 0.5) * Double(columns) /
                Double(Self.prototypeColumns)
        )
        return min(max(scaled, 0), columns - 1)
    }

    func contains(_ coordinate: GridCoordinate) -> Bool {
        coordinate.column >= 0 &&
            coordinate.column < columns &&
            coordinate.row >= 0 &&
            coordinate.row < rows
    }

    func isWalkable(_ coordinate: GridCoordinate) -> Bool {
        contains(coordinate) && !blockedCells.contains(coordinate)
    }

    func coordinate(for position: WorldPosition) -> GridCoordinate? {
        let column = Int(floor((position.x - origin.x) / cellSize))
        let row = Int(floor((position.y - origin.y) / cellSize))
        let coordinate = GridCoordinate(column: column, row: row)

        return contains(coordinate) ? coordinate : nil
    }

    func worldPosition(for coordinate: GridCoordinate) -> WorldPosition {
        WorldPosition(
            x: origin.x + (Double(coordinate.column) + 0.5) * cellSize,
            y: origin.y + (Double(coordinate.row) + 0.5) * cellSize
        )
    }

    func neighbors(of coordinate: GridCoordinate) -> [GridCoordinate] {
        var result: [GridCoordinate] = []

        for columnOffset in -1...1 {
            for rowOffset in -1...1 {
                guard columnOffset != 0 || rowOffset != 0 else {
                    continue
                }

                let candidate = GridCoordinate(
                    column: coordinate.column + columnOffset,
                    row: coordinate.row + rowOffset
                )

                guard isWalkable(candidate) else {
                    continue
                }

                if abs(columnOffset) == 1 && abs(rowOffset) == 1 {
                    let horizontal = GridCoordinate(
                        column: coordinate.column + columnOffset,
                        row: coordinate.row
                    )
                    let vertical = GridCoordinate(
                        column: coordinate.column,
                        row: coordinate.row + rowOffset
                    )

                    guard isWalkable(horizontal), isWalkable(vertical) else {
                        continue
                    }
                }

                result.append(candidate)
            }
        }

        return result
    }

    func movementCost(
        from first: GridCoordinate,
        to second: GridCoordinate
    ) -> Double {
        let isDiagonal =
            first.column != second.column &&
            first.row != second.row

        return (isDiagonal ? sqrt(2) : 1) * cellSize
    }
}
