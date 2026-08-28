import Foundation

/// Produces deterministic candidate plans from independent strategy axes.
///
/// The same troop and spell identifiers are reused in every candidate so the
/// headless comparison changes only placement and timing, never army content.
nonisolated struct AttackPlanGenerator {
    private struct Formation {
        let name: String
        let firstRow: Int
        let secondRow: Int
    }

    private struct Tempo {
        let name: String
        let troopTimes: [TimeInterval]
        let healTime: TimeInterval
        let rageTime: TimeInterval
    }

    private struct BreachStyle {
        let name: String
        let wallBreakerOffset: Int
    }

    private let navigationGrid: NavigationGrid

    init(navigationGrid: NavigationGrid) {
        self.navigationGrid = navigationGrid
    }

    func generate() -> [AttackPlan] {
        let entityIDs = (0..<10).map { _ in UUID() }
        let spellIDs = (0..<2).map { _ in UUID() }

        return formations.flatMap { formation in
            tempos.flatMap { tempo in
                breachStyles.map { breachStyle in
                    makePlan(
                        formation: formation,
                        tempo: tempo,
                        breachStyle: breachStyle,
                        entityIDs: entityIDs,
                        spellIDs: spellIDs
                    )
                }
            }
        }
    }

    private var formations: [Formation] {
        [
            Formation(name: "Alta", firstRow: 4, secondRow: 5),
            Formation(name: "Centro", firstRow: 8, secondRow: 9),
            Formation(name: "Bassa", firstRow: 12, secondRow: 11),
            Formation(name: "Divisa", firstRow: 4, secondRow: 12)
        ]
    }

    private var tempos: [Tempo] {
        [
            Tempo(
                name: "Rapida",
                troopTimes: [
                    0, 0.3, 0.8, 1.0, 2.4,
                    2.7, 3.2, 3.6, 4.8, 5.1
                ],
                healTime: 4.8,
                rageTime: 7.4
            ),
            Tempo(
                name: "Bilanciata",
                troopTimes: [
                    0, 0.4, 1.0, 1.2, 3.0,
                    3.4, 4.0, 4.5, 6.2, 6.7
                ],
                healTime: 6.0,
                rageTime: 9.0
            ),
            Tempo(
                name: "Paziente",
                troopTimes: [
                    0, 0.6, 1.4, 1.8, 4.2,
                    4.8, 5.6, 6.2, 8.2, 8.8
                ],
                healTime: 7.4,
                rageTime: 10.8
            )
        ]
    }

    private var breachStyles: [BreachStyle] {
        [
            BreachStyle(
                name: "Breccia stretta",
                wallBreakerOffset: 0
            ),
            BreachStyle(
                name: "Breccia larga",
                wallBreakerOffset: 1
            )
        ]
    }

    private func makePlan(
        formation: Formation,
        tempo: Tempo,
        breachStyle: BreachStyle,
        entityIDs: [UUID],
        spellIDs: [UUID]
    ) -> AttackPlan {
        let first = formation.firstRow
        let second = formation.secondRow
        let offset = breachStyle.wallBreakerOffset
        let rows = [
            clampedRow(first - offset),
            clampedRow(first),
            clampedRow(first - 1),
            clampedRow(first + 1),
            clampedRow(second + offset),
            clampedRow(second),
            clampedRow(second + 1),
            clampedRow(second - 1),
            clampedRow(first),
            clampedRow(second)
        ]
        let kinds: [BattleEntityKind] = [
            .wallBreaker,
            .giant,
            .barbarian,
            .archer,
            .wallBreaker,
            .giant,
            .barbarian,
            .archer,
            .barbarian,
            .archer
        ]
        let columns = [2, 2, 1, 1, 2, 2, 1, 1, 2, 1]

        precondition(rows.count == kinds.count)
        precondition(kinds.count == tempo.troopTimes.count)
        precondition(entityIDs.count == kinds.count)
        precondition(spellIDs.count == 2)

        let deployments = kinds.indices.map { index in
            DeploymentOrder(
                entityID: entityIDs[index],
                kind: kinds[index],
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(
                        column: columns[index],
                        row: rows[index]
                    )
                ),
                deploymentTime: tempo.troopTimes[index]
            )
        }
        let spellDeployments = [
            SpellDeploymentOrder(
                id: spellIDs[0],
                kind: .heal,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(
                        column: 13,
                        row: clampedRow(first)
                    )
                ),
                deploymentTime: tempo.healTime
            ),
            SpellDeploymentOrder(
                id: spellIDs[1],
                kind: .rage,
                position: navigationGrid.worldPosition(
                    for: GridCoordinate(
                        column: 18,
                        row: clampedRow(second)
                    )
                ),
                deploymentTime: tempo.rageTime
            )
        ]

        return AttackPlan(
            name: "\(formation.name) · \(tempo.name) · \(breachStyle.name)",
            deployments: deployments,
            spellDeployments: spellDeployments
        )
    }

    private func clampedRow(_ row: Int) -> Int {
        min(max(row, 0), navigationGrid.rows - 1)
    }
}
