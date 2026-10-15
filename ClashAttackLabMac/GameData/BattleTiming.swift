import Foundation

/// Bounds for when attack orders (deployments, spells, hero abilities)
/// may be scheduled.
nonisolated enum BattleTiming {
    /// Prototype battles last 60 s, so orders start by 59 s.
    static let prototypeLatestOrderTime: TimeInterval = 59

    /// Latest bound of any supported battle: three-minute real battles.
    static let maximumOrderTime = latestOrderTime(
        forBattleDuration: ReferenceGameData.realBattleDuration
    )

    /// Orders start at least one second before the battle ends.
    static func latestOrderTime(
        forBattleDuration duration: TimeInterval
    ) -> TimeInterval {
        max(0, duration - 1)
    }
}
