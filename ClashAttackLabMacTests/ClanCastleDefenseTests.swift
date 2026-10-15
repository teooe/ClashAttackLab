import Foundation
import Testing
@testable import ClashAttackLabMac

/// Real data with the Clan Castle's hit points or trigger radius changed.
private struct CastleTweakedGameData: GameDataProviding {
    let base: ReferenceGameData
    var castleHitPoints: Double?
    var triggerRadius: Double?

    func definition(for kind: BattleEntityKind) -> CombatDefinition {
        var definition = base.definition(for: kind)
        if kind == .clanCastle {
            if let castleHitPoints {
                definition.maxHitPoints = castleHitPoints
            }
            if let triggerRadius {
                definition.garrisonTriggerRadius = triggerRadius
            }
        }
        return definition
    }

    func spellDefinition(for kind: BattleSpellKind) -> SpellDefinition {
        base.spellDefinition(for: kind)
    }

    var battleDuration: TimeInterval {
        base.battleDuration
    }
}

struct ClanCastleDefenseTests {
    private let grid = RealBattleMap.makeNavigationGrid()

    private func position(column: Int, row: Int) -> WorldPosition {
        grid.worldPosition(for: GridCoordinate(column: column, row: row))
    }

    private func referenceData(
        townHall: Int = 15,
        troops: [BattleEntityKind]? = nil
    ) throws -> ReferenceGameData {
        var data = ReferenceGameData(
            catalog: try ReferenceGameCatalog.loadBundled(),
            profile: ReferenceLevelProfile(townHall: townHall)
        )
        data.clanCastleTroops = troops
        return data
    }

    private func engine(
        _ entities: [BattleEntity],
        _ deployments: [DeploymentOrder],
        gameData: any GameDataProviding
    ) -> SimulationEngine {
        let engine = SimulationEngine(
            entities: entities,
            attackPlan: AttackPlan(name: "Castello", deployments: deployments),
            gameData: gameData,
            navigationGrid: grid
        )
        engine.start()
        return engine
    }

    private func advance(_ engine: SimulationEngine, seconds: Double) {
        for _ in 0..<Int((seconds * 60).rounded()) {
            engine.advance(by: 1.0 / 60.0)
        }
    }

    // MARK: Data

    @Test
    func townHall15CastleHoldsFiftyHousingOfDefenders() throws {
        let data = try referenceData()
        let castle = data.definition(for: .clanCastle)

        #expect(castle.garrison == [.dragon, .dragon, .wizard, .wizard, .archer, .archer])
        #expect(castle.garrison.reduce(0) { $0 + data.definition(for: $1).housingSpace } == 50)
        #expect(castle.garrisonTriggerRadius == 13 * 40)
    }

    @Test
    func smallerCastlesGetASmallerDefaultGarrison() throws {
        let data = try referenceData(townHall: 9)
        let garrison = data.definition(for: .clanCastle).garrison

        #expect(garrison == [.dragon, .wizard, .wizard, .archer, .archer])
        #expect(data.defaultGarrison(capacity: 0).isEmpty)
    }

    @Test
    func chosenReinforcementsReplaceTheDefault() throws {
        let data = try referenceData(troops: [.valkyrie, .valkyrie])
        #expect(data.definition(for: .clanCastle).garrison == [.valkyrie, .valkyrie])
        #expect(PrototypeGameData().definition(for: .clanCastle).garrison.isEmpty)
    }

    // MARK: Battle

    @Test
    func reinforcementsComeOutWhenAnAttackerGetsClose() throws {
        let data = try referenceData(troops: [.barbarian, .barbarian, .barbarian])
        let castle = BattleEntity(kind: .clanCastle, position: position(column: 25, row: 25))
        let archer = DeploymentOrder(kind: .archer, position: position(column: 6, row: 25), deploymentTime: 0)
        let engine = engine([castle], [archer], gameData: data)

        // 19 tiles away: outside the 13-tile trigger radius.
        engine.advance(by: 1.0 / 60.0)
        #expect(engine.releasedDefenderCount == 0)

        advance(engine, seconds: 20)
        #expect(engine.releasedDefenderCount == 3)
        let defenders = engine.entities.filter(\.isDefender)
        #expect(defenders.count == 3)
        #expect(defenders.allSatisfy { $0.kind == .barbarian })
        #expect(engine.timeline.contains { $0.kind == .clanCastleReinforcements })

        // The archer fought back and the barbarians fought the archer.
        let shooter = try #require(engine.entities.first { $0.id == archer.entityID })
        #expect(shooter.hitPoints < data.definition(for: .archer).maxHitPoints)
        #expect(defenders.contains {
            $0.hitPoints < data.definition(for: .barbarian).maxHitPoints
        })
    }

    @Test
    func defendersNeverCountAsAttackers() throws {
        let data = try referenceData(troops: [.barbarian, .barbarian])
        let castle = BattleEntity(kind: .clanCastle, position: position(column: 25, row: 25))
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 35, row: 35))
        let archer = DeploymentOrder(kind: .archer, position: position(column: 15, row: 25), deploymentTime: 0)
        let engine = engine([castle, storage], [archer], gameData: data)
        advance(engine, seconds: 1)

        #expect(engine.releasedDefenderCount > 0)
        #expect(engine.livingTroopCount <= 1)
        #expect(engine.deployedTroopCount == 1)
    }

    @Test
    func aFallenCastleReleasesEveryoneAtOnce() throws {
        let tweaked = CastleTweakedGameData(
            base: try referenceData(troops: Array(repeating: .archer, count: 5)),
            castleHitPoints: 1,
            triggerRadius: 0
        )
        let castle = BattleEntity(kind: .clanCastle, position: position(column: 25, row: 25))
        let storage = BattleEntity(kind: .goldStorage, position: position(column: 38, row: 38))
        let archer = DeploymentOrder(kind: .archer, position: position(column: 19, row: 25), deploymentTime: 0)
        let engine = engine([castle, storage], [archer], gameData: tweaked)

        var released = 0
        for _ in 0..<(60 * 10) {
            engine.advance(by: 1.0 / 60.0)
            let fallen = engine.entities.first { $0.id == castle.id }.map { !$0.isAlive } ?? false
            if fallen {
                // Damage dealt at the end of a tick opens the castle on
                // the next one.
                engine.advance(by: 1.0 / 60.0)
                released = engine.releasedDefenderCount
                break
            }
            #expect(engine.releasedDefenderCount == 0)
        }
        #expect(released == 5)
    }

    @Test
    func splashOnlyHitsTroopsOnTheTargetSide() throws {
        // A Wizard reinforcement splashes the attackers, never its friends.
        let data = try referenceData(troops: [.wizard, .barbarian, .barbarian, .barbarian])
        let castle = BattleEntity(kind: .clanCastle, position: position(column: 25, row: 25))
        let giant = DeploymentOrder(kind: .giant, position: position(column: 22, row: 25), deploymentTime: 0)
        let engine = engine([castle], [giant], gameData: data)
        advance(engine, seconds: 4)

        // Giants only hit defenses, so nothing but the Wizard's own side
        // could hurt the Barbarians.
        let barbarians = engine.entities.filter { $0.isDefender && $0.kind == .barbarian }
        #expect(barbarians.count == 3)
        #expect(barbarians.allSatisfy {
            $0.hitPoints == data.definition(for: .barbarian).maxHitPoints
        })
        let target = try #require(engine.entities.first { $0.id == giant.entityID })
        #expect(target.hitPoints < data.definition(for: .giant).maxHitPoints)
    }
}

struct ClanCastleReinforcementTextTests {
    @Test
    func parsesReinforcementsWithOptionalCounts() throws {
        let layout = try RealBaseLayoutText.parse("""
        livello 15
        townHall 20 20
        rinforzi drago 2 stregone 2 arciere
        """)
        #expect(layout.clanCastleTroops == [.dragon, .dragon, .wizard, .wizard, .archer])

        let empty = try RealBaseLayoutText.parse("townHall 20 20\nrinforzi nessuno")
        #expect(empty.clanCastleTroops == [])

        let none = try RealBaseLayoutText.parse("townHall 20 20")
        #expect(none.clanCastleTroops == nil)
    }

    @Test
    func reportsBadReinforcementLines() {
        func line(of text: String) -> Int? {
            do {
                _ = try RealBaseLayoutText.parse(text)
                return nil
            } catch let error as RealBaseParseError {
                return error.line
            } catch {
                return nil
            }
        }
        #expect(line(of: "townHall 20 20\nrinforzi unicorno 2") == 2)
        #expect(line(of: "townHall 20 20\nrinforzi dragon 99") == 2)
        #expect(line(of: "townHall 20 20\nrinforzi") == 2)
    }

    @Test
    func formatKeepsTheReinforcements() throws {
        let layout = RealBaseLayout(
            name: "Con rinforzi",
            townHall: 15,
            buildings: [RealBaseBuilding(kind: .townHall, column: 20, row: 20)],
            clanCastleTroops: [.valkyrie, .valkyrie, .archer]
        )
        let parsed = try RealBaseLayoutText.parse(RealBaseLayoutText.format(layout))
        #expect(parsed.clanCastleTroops == layout.clanCastleTroops)

        var empty = layout
        empty.clanCastleTroops = []
        #expect(try RealBaseLayoutText.parse(RealBaseLayoutText.format(empty)).clanCastleTroops == [])
    }

    @Test
    func validatesWhatGoesInTheCastle() throws {
        let catalog = try ReferenceGameCatalog.loadBundled()
        let heroes = RealBaseLayout(
            name: "Eroi",
            townHall: 15,
            buildings: [RealBaseBuilding(kind: .townHall, column: 20, row: 20)],
            clanCastleTroops: [.archerQueen, .lavaPup]
        )
        let errors = heroes.issues(catalog: catalog).filter(\.isError).map(\.text)
        #expect(errors.filter { $0.contains("Castello del clan") }.count == 2)

        let crowded = RealBaseLayout(
            name: "Troppi",
            townHall: 9,
            buildings: [RealBaseBuilding(kind: .townHall, column: 20, row: 20)],
            clanCastleTroops: [.dragon, .dragon]
        )
        #expect(crowded.isUsable(catalog: catalog))
        #expect(crowded.issues(catalog: catalog).contains {
            !$0.isError && $0.text.contains("Rinforzi da 40 posti")
        })
    }

    @Test
    func sessionUsesTheReinforcementsOfTheBase() throws {
        let session = AttackLabSession()
        let report = session.importRealBase(
            text: """
            nome Base con rinforzi di prova
            livello 15
            townHall 20 20
            clanCastle 10 10
            cannon 30 30
            rinforzi valkyrie 3
            """,
            fileName: "rinforzi"
        )
        let imported = try #require(session.realBases.first { $0.name == "Base con rinforzi di prova" })
        defer { session.removeRealBase(id: imported.id) }

        #expect(report.imported, "\(report.messages)")
        #expect(session.clanCastleTroops == [.valkyrie, .valkyrie, .valkyrie])

        session.applyRealBaseChoice(.generated(.corridor))
        #expect(session.clanCastleTroops == nil)
    }

    @Test
    func bundledExampleListsItsReinforcements() throws {
        let example = try #require(
            RealBaseLayout.bundled().first { $0.name == "Esempio Municipio 15" }
        )
        #expect(example.clanCastleTroops == [.dragon, .dragon, .wizard, .wizard, .archer, .archer])
    }
}
