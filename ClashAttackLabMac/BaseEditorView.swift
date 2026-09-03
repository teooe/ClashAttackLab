import SwiftUI
import UniformTypeIdentifiers

struct BaseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PrototypeBaseLayout
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument: BaseSnapshotDocument?

    let currentSnapshot: BaseSnapshot
    private let onApply: (PrototypeBaseLayout) -> Void
    private let onImport: (BaseSnapshot) -> Void

    init(
        layout: PrototypeBaseLayout,
        snapshot: BaseSnapshot,
        onApply: @escaping (PrototypeBaseLayout) -> Void,
        onImport: @escaping (BaseSnapshot) -> Void
    ) {
        _selection = State(initialValue: layout)
        self.currentSnapshot = snapshot
        self.onApply = onApply
        self.onImport = onImport
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
                    "Scegli una base prototipo oppure importa/esporta una base JSON."
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

            Divider()

            HStack {
                Button {
                    showingImporter = true
                } label: {
                    Label("Importa JSON", systemImage: "square.and.arrow.down")
                }

                Button {
                    exportDocument = BaseSnapshotDocument(
                        snapshot: currentSnapshot
                    )
                    showingExporter = true
                } label: {
                    Label("Esporta JSON", systemImage: "square.and.arrow.up")
                }

                Spacer()

                Button("Annulla") {
                    dismiss()
                }

                Button("Carica base") {
                    onApply(selection)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 600)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json]
        ) { result in
            guard case .success(let url) = result else {
                return
            }

            do {
                let data = try Data(contentsOf: url)
                let snapshot = try JSONDecoder().decode(
                    BaseSnapshot.self,
                    from: data
                )
                guard snapshot.isValid else {
                    return
                }
                onImport(snapshot)
                dismiss()
            } catch {
                // Invalid files are ignored; the caller keeps the current base.
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: currentSnapshot.name
        ) { _ in
            exportDocument = nil
        }
    }
}
