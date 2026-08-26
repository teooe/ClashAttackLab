import Foundation

struct NavigationGrid {
    let columns: Int
    let rows: Int
    let cellSize: Double
    let origin: WorldPosition
    let blockedCells: Set<GridCoordinate>

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
