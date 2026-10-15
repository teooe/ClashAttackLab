import Foundation

nonisolated struct PathfindingResult {
    let waypoints: [WorldPosition]
    let totalCost: Double
}

nonisolated struct AStarPathfinder {
    /// `obstacleCells` are cells the route may not enter on top of the
    /// grid's own blocked cells, such as standing buildings; diagonal
    /// moves may not cut their corners either.
    func findPath(
        from startPosition: WorldPosition,
        to goalPosition: WorldPosition,
        in grid: NavigationGrid,
        breakableCells: Set<GridCoordinate> = [],
        breakableTraversalCost: Double = 0,
        obstacleCells: Set<GridCoordinate> = []
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
        let startEstimate = heuristic(from: start, to: goal, cellSize: grid.cellSize)
        var estimatedTotalCost: [GridCoordinate: Double] = [start: startEstimate]
        // The heap holds one entry per push; entries whose node has left
        // the open set or found a cheaper estimate are skipped. Popping
        // follows the same total order as scanning the open set (estimate,
        // then row, then column), so routes stay identical and
        // deterministic, only faster.
        var frontier = OpenNodeHeap()
        frontier.push(OpenNode(estimate: startEstimate, coordinate: start))

        while let entry = frontier.pop() {
            let current = entry.coordinate
            guard
                openSet.contains(current),
                estimatedTotalCost[current] == entry.estimate
            else {
                continue
            }
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
                guard
                    obstacleCells.isEmpty ||
                        !touchesObstacle(from: current, to: neighbor, obstacleCells: obstacleCells)
                else {
                    continue
                }
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
                let estimate =
                    tentativeCost +
                    heuristic(
                        from: neighbor,
                        to: goal,
                        cellSize: grid.cellSize
                    )
                estimatedTotalCost[neighbor] = estimate
                openSet.insert(neighbor)
                frontier.push(OpenNode(estimate: estimate, coordinate: neighbor))
            }
        }

        return nil
    }

    /// True when the step enters an obstacle or cuts one of its corners.
    private func touchesObstacle(
        from first: GridCoordinate,
        to second: GridCoordinate,
        obstacleCells: Set<GridCoordinate>
    ) -> Bool {
        if obstacleCells.contains(second) {
            return true
        }
        guard first.column != second.column, first.row != second.row else {
            return false
        }
        return obstacleCells.contains(GridCoordinate(column: second.column, row: first.row)) ||
            obstacleCells.contains(GridCoordinate(column: first.column, row: second.row))
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

/// A node waiting in the A* frontier with its estimated total cost.
nonisolated struct OpenNode {
    let estimate: Double
    let coordinate: GridCoordinate

    /// Lower estimate first, then lower row, then lower column.
    func precedes(_ other: OpenNode) -> Bool {
        if estimate != other.estimate {
            return estimate < other.estimate
        }
        if coordinate.row != other.coordinate.row {
            return coordinate.row < other.coordinate.row
        }
        return coordinate.column < other.coordinate.column
    }
}

/// Binary min-heap of frontier nodes.
nonisolated struct OpenNodeHeap {
    private var nodes: [OpenNode] = []

    var isEmpty: Bool {
        nodes.isEmpty
    }

    mutating func push(_ node: OpenNode) {
        nodes.append(node)
        var child = nodes.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard nodes[child].precedes(nodes[parent]) else {
                break
            }
            nodes.swapAt(child, parent)
            child = parent
        }
    }

    mutating func pop() -> OpenNode? {
        guard !nodes.isEmpty else {
            return nil
        }
        nodes.swapAt(0, nodes.count - 1)
        let top = nodes.removeLast()
        var parent = 0
        while true {
            let left = parent * 2 + 1
            let right = left + 1
            var first = parent
            if left < nodes.count, nodes[left].precedes(nodes[first]) {
                first = left
            }
            if right < nodes.count, nodes[right].precedes(nodes[first]) {
                first = right
            }
            guard first != parent else {
                break
            }
            nodes.swapAt(parent, first)
            parent = first
        }
        return top
    }
}
