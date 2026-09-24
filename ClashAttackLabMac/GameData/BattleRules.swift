import Foundation

/// Match rules shared by the simulator and the planning tools.
nonisolated enum BattleRules {
    /// Multiplayer battles last three minutes; scouting time is excluded.
    static let battleDuration: TimeInterval = 180

    /// Planned commands keep a one-second margin before the timer expires.
    static let latestCommandTime: TimeInterval = battleDuration - 1
}
