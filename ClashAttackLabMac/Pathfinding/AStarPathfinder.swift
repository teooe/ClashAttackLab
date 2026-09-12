import Foundation

nonisolated struct PathfindingResult {
    let waypoints: [WorldPosition]
    let totalCost: Double
}

nonisolated struct AStarPathfinder {
    func findPath(
        from startPosition: WorldPosition,
        to goalPosition: WorldPosition,
        in grid: NavigationGrid,
        breakableCells: Set<GridCoordinate> = [],
        breakableTraversalCost: Double = 0
    ) -> PathfindingResult? {
        guard
            let start = grid.coordinate(for: startPosition),
            let goal = grid.coordinate(for: goalPosition),
            grid.isWalkable(start),
            grid.isWalkable(goal)
        else {
            return nil
        }

        var openSet: Set<GridCoordinate> = [start]
        var cameFrom: [GridCoordinate: GridCoordinate] = [:]
        var costFromStart: [GridCoordinate: Double] = [start: 0]
        var estimatedTotalCost: [GridCoordinate: Double] = [
            start: heuristic(from: start, to: goal, cellSize: grid.cellSize)
        ]

        while let current = openSet.min(by: {
            let firstCost = estimatedTotalCost[$0, default: .infinity]
            let secondCost = estimatedTotalCost[$1, default: .infinity]
            if firstCost != secondCost { return firstCost < secondCost }
            // Set iteration order is randomized. Resolve equal costs with a
            // total coordinate ordering so replays choose the same route.
            if $0.row != $1.row { return $0.row < $1.row }
            return $0.column < $1.column
        }) {
            if current == goal {
                let coordinates = reconstructPath(
                    endingAt: current,
                    cameFrom: cameFrom
                )
                var waypoints = coordinates
                    .dropFirst()
                    .map { grid.worldPosition(for: $0) }

                if waypoints.last != goalPosition {
                    waypoints.append(goalPosition)
                }

                return PathfindingResult(
                    waypoints: waypoints,
                    totalCost: costFromStart[current, default: 0]
                )
            }

            openSet.remove(current)

            for neighbor in grid.neighbors(of: current) {
                guard !cutsBreakableCorner(
                    from: current,
                    to: neighbor,
                    breakableCells: breakableCells
                ) else {
                    continue
                }

                let wallCost = breakableCells.contains(neighbor)
                    ? breakableTraversalCost
                    : 0
                let tentativeCost =
                    costFromStart[current, default: .infinity] +
                    grid.movementCost(from: current, to: neighbor) +
                    wallCost

                guard tentativeCost <
                    costFromStart[neighbor, default: .infinity]
                else {
                    continue
                }

                cameFrom[neighbor] = current
                costFromStart[neighbor] = tentativeCost
                estimatedTotalCost[neighbor] =
                    tentativeCost +
                    heuristic(
                        from: neighbor,
                        to: goal,
                        cellSize: grid.cellSize
                    )
                openSet.insert(neighbor)
            }
        }

        return nil
    }

    private func cutsBreakableCorner(
        from first: GridCoordinate,
        to second: GridCoordinate,
        breakableCells: Set<GridCoordinate>
    ) -> Bool {
        let columnOffset = second.column - first.column
        let rowOffset = second.row - first.row

        guard abs(columnOffset) == 1, abs(rowOffset) == 1 else {
            return false
        }

        let horizontal = GridCoordinate(
            column: first.column + columnOffset,
            row: first.row
        )
        let vertical = GridCoordinate(
            column: first.column,
            row: first.row + rowOffset
        )

        return breakableCells.contains(horizontal) ||
            breakableCells.contains(vertical)
    }

    private func reconstructPath(
        endingAt goal: GridCoordinate,
        cameFrom: [GridCoordinate: GridCoordinate]
    ) -> [GridCoordinate] {
        var current = goal
        var path = [current]

        while let previous = cameFrom[current] {
            current = previous
            path.append(current)
        }

        return Array(path.reversed())
    }

    private func heuristic(
        from first: GridCoordinate,
        to second: GridCoordinate,
        cellSize: Double
    ) -> Double {
        let columnDistance = abs(first.column - second.column)
        let rowDistance = abs(first.row - second.row)
        let diagonalSteps = min(columnDistance, rowDistance)
        let straightSteps = max(columnDistance, rowDistance) - diagonalSteps

        return (
            Double(diagonalSteps) * sqrt(2) +
            Double(straightSteps)
        ) * cellSize
    }
}
