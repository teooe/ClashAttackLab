import SwiftUI

/// Picks the two pieces each hero wears in real battles.
struct HeroEquipmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [BattleEntityKind: [HeroEquipmentKind]]
    @State private var pets: [BattleEntityKind: BattleEntityKind]

    private let heroes: [BattleEntityKind]
    private let onApply: ([BattleEntityKind: [HeroEquipmentKind]], [BattleEntityKind: BattleEntityKind]) -> Void

    init(
        loadouts: [BattleEntityKind: [HeroEquipmentKind]],
        pets: [BattleEntityKind: BattleEntityKind] = [:],
        heroes: [BattleEntityKind] = BattleEntityKind.heroKinds,
        onApply: @escaping ([BattleEntityKind: [HeroEquipmentKind]], [BattleEntityKind: BattleEntityKind]) -> Void
    ) {
        _draft = State(initialValue: loadouts)
        _pets = State(initialValue: pets)
        self.heroes = heroes
        self.onApply = onApply
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Equipaggiamento e famigli")
                    .font(.title2.bold())
                Text("Ogni eroe porta due pezzi, al livello massimo del Fabbro per il Municipio scelto.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
            ForEach(heroes, id: \.self) { hero in
                GroupBox(TroopStyle.style(for: hero).displayName) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            ForEach(0..<HeroEquipmentKind.piecesPerHero, id: \.self) { slot in
                                Picker("Pezzo \(slot + 1)", selection: binding(for: hero, slot: slot)) {
                                    Text("Nessuno").tag(HeroEquipmentKind?.none)
                                    ForEach(HeroEquipmentKind.available(for: hero), id: \.self) { piece in
                                        Text(piece.displayName).tag(HeroEquipmentKind?.some(piece))
                                    }
                                }
                            }
                        }
                        Picker("Famiglio", selection: petBinding(for: hero)) {
                            Text("Nessuno").tag(BattleEntityKind?.none)
                            ForEach(BattleEntityKind.petKinds, id: \.self) { pet in
                                Text(TroopStyle.style(for: pet).displayName).tag(BattleEntityKind?.some(pet))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            }
            .frame(maxHeight: 520)

            HStack {
                Button("Annulla") {
                    dismiss()
                }
                Spacer()
                Button("Ripristina") {
                    draft = HeroEquipmentKind.defaultLoadouts
                    pets = BattleEntityKind.defaultPets
                }
                Button("Applica") {
                    onApply(draft, pets)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    /// A hero's pet; a pet already with another hero moves over.
    private func petBinding(for hero: BattleEntityKind) -> Binding<BattleEntityKind?> {
        Binding(
            get: { pets[hero] },
            set: { pet in
                if let pet, let other = pets.first(where: { $0.value == pet && $0.key != hero })?.key {
                    pets[other] = nil
                }
                pets[hero] = pet
            }
        )
    }

    /// A slot's piece; picking one the other slot already holds swaps them.
    private func binding(for hero: BattleEntityKind, slot: Int) -> Binding<HeroEquipmentKind?> {
        Binding(
            get: {
                let pieces = draft[hero] ?? []
                return slot < pieces.count ? pieces[slot] : nil
            },
            set: { piece in
                var slots = (draft[hero] ?? []).map { Optional($0) }
                while slots.count < HeroEquipmentKind.piecesPerHero {
                    slots.append(nil)
                }
                if let piece, let other = slots.firstIndex(of: piece), other != slot {
                    slots[other] = slots[slot]
                }
                slots[slot] = piece
                draft[hero] = slots.compactMap { $0 }
            }
        )
    }
}
