import SwiftUI

/// Picks the two pieces each hero wears in real battles.
struct HeroEquipmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [BattleEntityKind: [HeroEquipmentKind]]

    private let heroes: [BattleEntityKind]
    private let onApply: ([BattleEntityKind: [HeroEquipmentKind]]) -> Void

    init(
        loadouts: [BattleEntityKind: [HeroEquipmentKind]],
        heroes: [BattleEntityKind] = BattleEntityKind.heroKinds,
        onApply: @escaping ([BattleEntityKind: [HeroEquipmentKind]]) -> Void
    ) {
        _draft = State(initialValue: loadouts)
        self.heroes = heroes
        self.onApply = onApply
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Equipaggiamento eroi")
                    .font(.title2.bold())
                Text("Ogni eroe porta due pezzi, al livello massimo del Fabbro per il Municipio scelto.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(heroes, id: \.self) { hero in
                GroupBox(TroopStyle.style(for: hero).displayName) {
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
                    .padding(.vertical, 4)
                }
            }

            HStack {
                Button("Annulla") {
                    dismiss()
                }
                Spacer()
                Button("Ripristina") {
                    draft = HeroEquipmentKind.defaultLoadouts
                }
                Button("Applica") {
                    onApply(draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 520)
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
