import Foundation

nonisolated struct BaseScoreSnapshot {
    let destructionPercentage: Double
    let stars: Int
    let townHallDestroyed: Bool
    let destroyedBuildings: Int
    let totalBuildings: Int

    static let zero = BaseScoreSnapshot(
        destructionPercentage: 0,
        stars: 0,
        townHallDestroyed: false,
        destroyedBuildings: 0,
        totalBuildings: 0
    )
}

struct BaseScoringSystem {
    func calculate(
        entities: [BattleEntity],
        gameData: any GameDataProviding
    ) -> BaseScoreSnapshot {
        let buildings = entities.filter {
            gameData.definition(for: $0.kind).countsForDestruction
        }
        let destroyedBuildings = buildings.filter { !$0.isAlive }.count
        let percentage: Double

        if buildings.isEmpty {
            percentage = 0
        } else {
            percentage =
                Double(destroyedBuildings) /
                Double(buildings.count) *
                100
        }

        let townHallDestroyed = entities.contains {
            $0.kind == .townHall && !$0.isAlive
        }

        var stars = 0

        if percentage >= 50 {
            stars += 1
        }

        if townHallDestroyed {
            stars += 1
        }

        if percentage >= 100 {
            stars += 1
        }

        return BaseScoreSnapshot(
            destructionPercentage: percentage,
            stars: min(stars, 3),
            townHallDestroyed: townHallDestroyed,
            destroyedBuildings: destroyedBuildings,
            totalBuildings: buildings.count
        )
    }
}
