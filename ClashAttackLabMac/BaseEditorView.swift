import SwiftUI

struct BaseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PrototypeBaseLayout

    private let onApply: (PrototypeBaseLayout) -> Void

    init(
        layout: PrototypeBaseLayout,
        onApply: @escaping (PrototypeBaseLayout) -> Void
    ) {
        _selection = State(initialValue: layout)
        self.onApply = onApply
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Label(
                    "Libreria basi",
                    systemImage: "square.grid.3x3.fill"
                )
                .font(.title2.bold())

                Text(
                    "Ogni base usa lo stesso inventario: il confronto misura percorsi, tempi e brecce."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(PrototypeBaseLayout.allCases) { layout in
                    Button {
                        selection = layout
                    } label: {
                        HStack(spacing: 12) {
                            Image(
                                systemName: selection == layout
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .font(.title3)
                            .foregroundStyle(
                                selection == layout
                                    ? Color.accentColor
                                    : Color.secondary
                            )

                            VStack(
                                alignment: .leading,
                                spacing: 3
                            ) {
                                Text(layout.displayName)
                                    .font(.headline)

                                Text(layout.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            selection == layout
                                ? Color.accentColor.opacity(0.12)
                                : Color.secondary.opacity(0.07)
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Button("Annulla") {
                    dismiss()
                }

                Spacer()

                Button("Carica base") {
                    onApply(selection)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 470)
    }
}
