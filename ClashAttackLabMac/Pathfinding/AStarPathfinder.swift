import Foundation

struct PathfindingResult {
    let waypoints: [WorldPosition]
    let totalCost: Double
}

struct AStarPathfinder {
    func findPath(
        from startPosition: WorldPosition,
        to goalPosition: WorldPosition,
        in grid: NavigationGrid
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
            estimatedTotalCost[$0, default: .infinity] <
                estimatedTotalCost[$1, default: .infinity]
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
                let tentativeCost =
                    costFromStart[current, default: .infinity] +
                    grid.movementCost(from: current, to: neighbor)

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

        return path.reversed()
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
