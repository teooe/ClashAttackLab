import Foundation
import Testing
@testable import ClashAttackLabMac

struct AttackerClanCastleTests {
    private func rules(townHall: Int) throws -> ArmyCapacityRules {
        ArmyCapacityRules.real(
            townHall: townHall,
            catalog: try ReferenceGameCatalog.loadBundled()
        )
    }

    @Test
    func theClanCastleAddsReinforcementsAndSpells() throws {
        let th15 = try rules(townHall: 15)
        #expect(th15.clanCastleTroopCapacity == 50)
        #expect(th15.clanCastleSpellCapacity == 3)
        #expect(th15.totalTroopCapacity == th15.troopCapacity + 50)
        #expect(th15.totalSpellCapacity == th15.spellCapacity + 3)

        // Below Town Hall 8 the castle holds no spells.
        let th7 = try rules(townHall: 7)
        #expect(th7.clanCastleSpellCapacity == 0)
        #expect(th7.clanCastleTroopCapacity > 0)
        #expect(ArmyCapacityRules.prototype.clanCastleTroopCapacity == 0)
    }

    @Test
    func defaultArmiesFillTheCastleToo() throws {
        let th15 = try rules(townHall: 15)
        let army = ArmyConfiguration.realDefault(for: th15)

        #expect(army.isValid(under: th15))
        #expect(army.troopCapacityUsed(under: th15) > th15.troopCapacity)
        #expect(army.troopCapacityUsed(under: th15) <= th15.totalTroopCapacity)
        #expect(army.spellCapacityUsed(under: th15) > th15.spellCapacity)
        #expect(army.spellCapacityUsed(under: th15) <= th15.totalSpellCapacity)
    }

    @Test
    func armiesBeyondCampsAndCastleAreRejected() throws {
        let th15 = try rules(townHall: 15)
        var army = ArmyConfiguration.realDefault(for: th15)
        let free = th15.totalTroopCapacity - army.troopCapacityUsed(under: th15)
        army.archers += free
        #expect(army.isValid(under: th15))
        army.archers += 1
        #expect(army.validationMessage(under: th15) == "Capacità truppe superata.")
    }
}
