import Foundation
import Testing
@testable import ClashAttackLabMac

struct RealBaseLayoutTests {
    private func catalog() throws -> ReferenceGameCatalog {
        try ReferenceGameCatalog.loadBundled()
    }

    private func parseError(_ text: String) -> RealBaseParseError? {
        do {
            _ = try RealBaseLayoutText.parse(text)
            return nil
        } catch let error as RealBaseParseError {
            return error
        } catch {
            return nil
        }
    }

    // MARK: Text format

    @Test
    func parsesNamesLevelsLinesAndComments() throws {
        let layout = try RealBaseLayoutText.parse("""
        # Una base di prova
        nome Prova
        livello 15

        townHall 20 20
        torreinfernale 10 10   # nome italiano senza spazi
        balestra 30 30
        ARCHERTOWER 5 5
        muro 0 0 - 3 0
        wall 43 43 - 43 41
        """)

        #expect(layout.name == "Prova")
        #expect(layout.townHall == 15)
        #expect(layout.buildings.first == RealBaseBuilding(kind: .townHall, column: 20, row: 20))
        #expect(layout.buildings.contains(RealBaseBuilding(kind: .infernoTower, column: 10, row: 10)))
        #expect(layout.buildings.contains(RealBaseBuilding(kind: .xBow, column: 30, row: 30)))
        #expect(layout.buildings.contains(RealBaseBuilding(kind: .archerTower, column: 5, row: 5)))
        let walls = layout.buildings.filter { $0.kind == .wall }
        #expect(walls.count == 7)
        #expect(walls.contains(RealBaseBuilding(kind: .wall, column: 3, row: 0)))
        #expect(walls.contains(RealBaseBuilding(kind: .wall, column: 43, row: 41)))
    }

    @Test
    func reportsTheLineOfEveryMistake() {
        #expect(parseError("townHall 1 1\nfantasma 3 3")?.line == 2)
        #expect(parseError("townHall 1 1\ncannon 3")?.line == 2)
        #expect(parseError("cannon a b")?.line == 1)
        #expect(parseError("wall 0 0 - 5 5")?.message.contains("orizzontali") == true)
        #expect(parseError("livello quindici")?.line == 1)
        #expect(parseError("# solo commenti")?.line == 0)
    }

    @Test
    func formatRoundTripsThroughTheParser() throws {
        let layout = RealBaseLayout(
            name: "Giro",
            townHall: 14,
            buildings: [
                RealBaseBuilding(kind: .townHall, column: 20, row: 20),
                RealBaseBuilding(kind: .eagleArtillery, column: 2, row: 3),
                RealBaseBuilding(kind: .springTrap, column: 40, row: 1)
            ]
        )
        let parsed = try RealBaseLayoutText.parse(RealBaseLayoutText.format(layout))

        #expect(parsed.name == layout.name)
        #expect(parsed.townHall == layout.townHall)
        #expect(parsed.buildings == layout.buildings)
    }

    @Test
    func everyBuildingKindHasAName() {
        for kind in BattleEntityKind.allCases {
            #expect(RealBaseLayoutText.kind(named: kind.referenceKey) == kind, "\(kind)")
        }
        #expect(RealBaseLayoutText.kind(named: "Torre dell’Arciera") == .archerTower)
        #expect(RealBaseLayoutText.kind(named: "aquila") == .eagleArtillery)
    }

    // MARK: Validation

    @Test
    func findsOverlapsBoundsAndMissingTownHalls() throws {
        let catalog = try catalog()
        let broken = RealBaseLayout(
            name: "Rotta",
            townHall: 15,
            buildings: [
                RealBaseBuilding(kind: .cannon, column: 10, row: 10),
                RealBaseBuilding(kind: .cannon, column: 12, row: 12),
                RealBaseBuilding(kind: .xBow, column: 42, row: 0),
                RealBaseBuilding(kind: .giant, column: 30, row: 30)
            ]
        )
        let errors = broken.issues(catalog: catalog).filter(\.isError).map(\.text)

        #expect(errors.contains { $0.contains("si sovrappone") })
        #expect(errors.contains { $0.contains("esce dalla mappa") })
        #expect(errors.contains { $0.contains("esattamente un Municipio") })
        #expect(errors.contains { $0.contains("è una truppa") })
        #expect(!broken.isUsable(catalog: catalog))
    }

    @Test
    func warnsAboutTooManyCopiesForTheTownHall() throws {
        let catalog = try catalog()
        let layout = RealBaseLayout(
            name: "Troppe",
            townHall: 9,
            buildings: [RealBaseBuilding(kind: .townHall, column: 20, row: 20)] +
                (0..<3).map { RealBaseBuilding(kind: .xBow, column: $0 * 5, row: 0) }
        )
        let issues = layout.issues(catalog: catalog)

        #expect(layout.isUsable(catalog: catalog))
        #expect(issues.contains { !$0.isError && $0.text.contains("Balestra") })
    }

    @Test
    func placesBuildingsOnTheirFootprintCentres() throws {
        let arena = try BattleArena.make(for: .reference(townHall: 15))
        let layout = RealBaseLayout(
            name: "Centro",
            townHall: 15,
            buildings: [
                RealBaseBuilding(kind: .townHall, column: 20, row: 20),
                RealBaseBuilding(kind: .wall, column: 0, row: 0)
            ]
        )
        let entities = arena.makeEntities(for: layout)
        let generatedTownHall = try #require(
            arena.makeBaseEntities(layout: .fortress).first { $0.kind == .townHall }
        )
        let grid = arena.navigationGrid

        #expect(entities.count == 2)
        // The generated bases also put the Town Hall in tiles 20–23.
        #expect(entities[0].position == generatedTownHall.position)
        // Row 0 is the top edge of the buildable area.
        let wallCell = try #require(grid.coordinate(for: entities[1].position))
        #expect(wallCell.column == RealBattleMap.borderTiles)
        #expect(wallCell.row == RealBattleMap.borderTiles + RealBattleMap.buildableTiles - 1)
        #expect(Set(entities.map(\.id)).count == 2)
    }

    // MARK: Bundled bases and the session

    @Test
    func bundledExampleBaseIsComplete() throws {
        let catalog = try catalog()
        let example = try #require(
            RealBaseLayout.bundled().first { $0.name == "Esempio Municipio 15" }
        )

        #expect(example.townHall == 15)
        #expect(example.isUsable(catalog: catalog), "\(example.issues(catalog: catalog))")
        #expect(!example.issues(catalog: catalog).contains { !$0.isError && $0.text.contains("permessi") })
        #expect(example.buildings.filter { $0.kind == .xBow }.count == 4)
        #expect(example.buildings.filter { $0.kind == .wall }.count > 100)
    }

    @Test
    func sessionImportsAndAttacksARealBase() throws {
        let session = AttackLabSession()
        let report = session.importRealBase(
            text: """
            nome Base di prova importata
            livello 14
            townHall 20 20
            cannon 10 10
            archerTower 30 30
            wall 15 15 - 28 15
            """,
            fileName: "prova"
        )
        let imported = try #require(session.realBases.first { $0.name == "Base di prova importata" })
        defer { session.removeRealBase(id: imported.id) }

        #expect(report.imported, "\(report.messages)")
        #expect(session.isRealArena)
        #expect(session.gameDataSource == .reference(townHall: 14))
        #expect(session.selectedRealBaseID == imported.id)
        #expect(session.realBaseChoice == .imported(imported.id))
        #expect(session.activeBaseSnapshot.name == "Base di prova importata")
        #expect(session.candidatePlanCount > 0)
        #expect(session.canRemoveRealBase(id: imported.id))

        session.applyRealBaseChoice(.generated(.corridor))
        #expect(session.selectedRealBaseID == nil)
        #expect(session.realBaseChoice == .generated(.corridor))
    }

    @Test
    func sessionRejectsBrokenFilesWithTheirLine() {
        let session = AttackLabSession()
        let count = session.realBases.count
        let report = session.importRealBase(text: "townHall 20 20\nfantasma 5 5", fileName: "rotta")

        #expect(!report.imported)
        #expect(report.messages.first?.hasPrefix("Riga 2") == true)
        #expect(session.realBases.count == count)
        #expect(!session.isRealArena)
    }
}
