import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct BaseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PrototypeBaseLayout
    @State private var draftSnapshot: BaseSnapshot
    @State private var selectedKind: BattleEntityKind = .wall
    @State private var eraseMode = false
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument: BaseSnapshotDocument?

    let navigationGrid: NavigationGrid
    let savedBases: [BaseSnapshot]
    private let onApply: (PrototypeBaseLayout) -> Void
    private let onApplySnapshot: (BaseSnapshot) -> Void
    private let onSaveSnapshot: (BaseSnapshot) -> Void

    init(
        layout: PrototypeBaseLayout,
        snapshot: BaseSnapshot,
        navigationGrid: NavigationGrid,
        savedBases: [BaseSnapshot],
        onApply: @escaping (PrototypeBaseLayout) -> Void,
        onApplySnapshot: @escaping (BaseSnapshot) -> Void,
        onSaveSnapshot: @escaping (BaseSnapshot) -> Void
    ) {
        _selection = State(initialValue: layout)
        _draftSnapshot = State(initialValue: snapshot)
        self.navigationGrid = navigationGrid
        self.savedBases = savedBases
        self.onApply = onApply
        self.onApplySnapshot = onApplySnapshot
        self.onSaveSnapshot = onSaveSnapshot
    }

    private var editableKinds: [BattleEntityKind] {
        [
            .wall,
            .cannon,
            .archerTower,
            .mortar,
            .airDefense,
            .townHall,
            .goldStorage
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Label(
                    "Editor della base",
                    systemImage: "square.grid.3x3.fill"
                )
                .font(.title2.bold())

                Text(
                    "Seleziona un elemento e clicca una cella. Cliccando una seconda volta lo sostituisci."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                TextField("Nome della base", text: $draftSnapshot.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 190)

                Menu("Basi salvate") {
                    if savedBases.isEmpty {
                        Text("Nessuna base salvata")
                    } else {
                        ForEach(savedBases) { snapshot in
                            Button(snapshot.name) {
                                draftSnapshot = snapshot
                            }
                        }
                    }
                }

                Menu {
                    ForEach(editableKinds, id: \.self) { kind in
                        Button {
                            selectedKind = kind
                            eraseMode = false
                        } label: {
                            Label(title(for: kind), systemImage: icon(for: kind))
                        }
                    }
                } label: {
                    Label(
                        eraseMode
                            ? "Gomma"
                            : title(for: selectedKind),
                        systemImage: eraseMode
                            ? "eraser"
                            : icon(for: selectedKind)
                    )
                }

                Toggle("Gomma", isOn: $eraseMode)
                    .toggleStyle(.switch)

                Spacer()

                Text(
                    "\(draftSnapshot.objectiveCount) strutture · \(draftSnapshot.wallCount) muri"
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 2) {
                    ForEach(0..<navigationGrid.rows, id: \.self) { row in
                        HStack(spacing: 2) {
                            ForEach(
                                0..<navigationGrid.columns,
                                id: \.self
                            ) { column in
                                let object = draftSnapshot.object(
                                    atColumn: column,
                                    row: row
                                )

                                Button {
                                    if eraseMode {
                                        draftSnapshot.removeObject(
                                            atColumn: column,
                                            row: row
                                        )
                                    } else {
                                        draftSnapshot.place(
                                            selectedKind,
                                            atColumn: column,
                                            row: row
                                        )
                                    }
                                } label: {
                                    Text(
                                        object.map {
                                            symbol(for: $0.kind)
                                        } ?? "·"
                                    )
                                    .font(.caption2.bold())
                                    .foregroundStyle(
                                        object == nil
                                            ? Color.secondary.opacity(0.45)
                                            : .white
                                    )
                                    .frame(width: 25, height: 25)
                                    .background(
                                        object.map {
                                            color(for: $0.kind)
                                        } ?? Color.secondary.opacity(0.08)
                                    )
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 4)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(height: 290)

            Divider()

            HStack(spacing: 10) {
                Button("Importa JSON") {
                    showingImporter = true
                }

                Button("Esporta JSON") {
                    exportDocument = BaseSnapshotDocument(
                        snapshot: draftSnapshot
                    )
                    showingExporter = true
                }

                Button("Salva in libreria") {
                    onSaveSnapshot(draftSnapshot)
                }
                .disabled(!draftSnapshot.isValid(on: navigationGrid))

                Spacer()

                Button("Annulla") {
                    dismiss()
                }

                Button("Carica base prototipo") {
                    onApply(selection)
                    dismiss()
                }

                Button("Applica modifiche") {
                    onApplySnapshot(draftSnapshot)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 980, height: 620)
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
                guard snapshot.isValid(on: navigationGrid) else {
                    return
                }
                draftSnapshot = snapshot
            } catch {
                return
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: draftSnapshot.name
        ) { _ in
            exportDocument = nil
        }
    }

    private func title(for kind: BattleEntityKind) -> String {
        switch kind {
        case .wall:
            return "Muro"
        case .cannon:
            return "Cannone"
        case .archerTower:
            return "Torre arcieri"
        case .mortar:
            return "Mortaio"
        case .airDefense:
            return "Difesa aerea"
        case .townHall:
            return "Municipio"
        case .goldStorage:
            return "Deposito oro"
        default:
            return "Elemento"
        }
    }

    private func symbol(for kind: BattleEntityKind) -> String {
        switch kind {
        case .wall:
            return "W"
        case .cannon:
            return "C"
        case .archerTower:
            return "T"
        case .mortar:
            return "M"
        case .airDefense:
            return "A"
        case .townHall:
            return "H"
        case .goldStorage:
            return "S"
        default:
            return "?"
        }
    }

    private func icon(for kind: BattleEntityKind) -> String {
        switch kind {
        case .wall:
            return "rectangle.fill"
        case .cannon:
            return "scope"
        case .archerTower:
            return "arrow.up"
        case .mortar:
            return "circle.dotted"
        case .airDefense:
            return "wind"
        case .townHall:
            return "building.2"
        case .goldStorage:
            return "shippingbox"
        default:
            return "square"
        }
    }

    private func color(for kind: BattleEntityKind) -> Color {
        switch kind {
        case .wall:
            return .brown
        case .cannon:
            return .gray
        case .archerTower:
            return .purple
        case .mortar:
            return .orange
        case .airDefense:
            return .indigo
        case .townHall:
            return .blue
        case .goldStorage:
            return .yellow
        default:
            return .secondary
        }
    }
}
