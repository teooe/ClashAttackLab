import Foundation

/// Prototype obstacle layout used to validate navigation.
/// Walls are static and indestructible in this milestone.
enum PrototypeBattleMap {
    static func makeNavigationGrid() -> NavigationGrid {
        var walls: Set<GridCoordinate> = []

        for row in 1...14 where row != 7 && row != 8 {
            walls.insert(GridCoordinate(column: 11, row: row))
        }

        for column in 15...20 {
            walls.insert(GridCoordinate(column: column, row: 10))
        }

        walls.remove(GridCoordinate(column: 18, row: 10))

        return NavigationGrid(
            columns: 25,
            rows: 16,
            cellSize: 40,
            origin: WorldPosition(x: 50, y: 60),
            blockedCells: walls
        )
    }
}
