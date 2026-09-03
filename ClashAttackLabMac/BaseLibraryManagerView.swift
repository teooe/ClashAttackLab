import SwiftUI

struct BaseLibraryManagerView: View {
    @ObservedObject var session: AttackLabSession

    @Environment(\.dismiss) private var dismiss

    @State private var selectedID: UUID?
    @State private var editedName = ""
    @State private var showingDeleteConfirmation = false

    private var selectedBase: BaseSnapshot? {
        guard let selectedID else {
            return nil
        }

        return session.savedBases.first { $0.id == selectedID }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Basi salvate", systemImage: "square.stack.3d.up")
                    .font(.title3.bold())

                Text("\(session.savedBases.count) nella libreria locale")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                List(selection: $selectedID) {
                    ForEach(session.savedBases) { base in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(base.name)
                                .font(.headline)
                            Text(
                                "\(base.objectiveCount) strutture · \(base.wallCount) muri"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                        .tag(base.id)
                    }
                }
                .onChange(of: selectedID) { newValue in
                    syncEditedName(with: newValue)
                }
            }
            .padding(18)
            .frame(width: 290)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(Color.secondary.opacity(0.08))

            Divider()

            Group {
                if let base = selectedBase {
                    editor(for: base)
                } else {
                    ContentUnavailableView(
                        "Nessuna base selezionata",
                        systemImage: "square.stack.3d.up",
                        description: Text(
                            "Crea o salva una base dall’editor per gestirla qui."
                        )
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 850, height: 520)
        .onAppear {
            selectInitialBaseIfNeeded()
        }
        .confirmationDialog(
            "Eliminare la base salvata?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Elimina", role: .destructive) {
                deleteSelectedBase()
            }
        } message: {
            Text("L’operazione rimuove solo la copia nella libreria locale.")
        }
    }

    @ViewBuilder
    private func editor(for base: BaseSnapshot) -> some View {
        let validation = base.validationReport(
            on: session.editorNavigationGrid
        )

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Dettagli base", systemImage: "slider.horizontal.3")
                    .font(.title3.bold())

                Spacer()

                Button("Carica") {
                    session.loadSavedBase(base)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            TextField("Nome base", text: $editedName)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    renameSelectedBase()
                }

            HStack(spacing: 10) {
                metric(
                    title: "Strutture",
                    value: "\(base.objectiveCount)"
                )
                metric(title: "Muri", value: "\(base.wallCount)")
                metric(
                    title: "Stato",
                    value: validation.isBuildable ? "Pronta" : "Da correggere"
                )
            }

            if !validation.messages.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(validation.messages) { message in
                        Label(
                            message.text,
                            systemImage:
                                message.severity == .error
                                ? "xmark.octagon.fill"
                                : "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            message.severity == .error
                                ? Color.red
                                : Color.orange
                        )
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }

            Text(
                "La base resta sul Mac. Caricarla la applica alla simulazione, senza eliminare le altre basi salvate."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Button("Salva nome") {
                    renameSelectedBase()
                }
                .disabled(
                    editedName.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                )

                Button("Duplica") {
                    duplicateSelectedBase()
                }

                Spacer()

                Button("Elimina", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .padding(24)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func selectInitialBaseIfNeeded() {
        guard selectedID == nil else {
            return
        }

        selectedID = session.savedBases.first?.id
        syncEditedName(with: selectedID)
    }

    private func syncEditedName(with id: UUID?) {
        editedName = session.savedBases.first {
            $0.id == id
        }?.name ?? ""
    }

    private func renameSelectedBase() {
        guard var base = selectedBase else {
            return
        }

        let trimmedName = editedName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedName.isEmpty else {
            return
        }

        base.name = trimmedName
        session.saveBaseSnapshot(base)
        selectedID = base.id
        editedName = trimmedName
    }

    private func duplicateSelectedBase() {
        guard let base = selectedBase else {
            return
        }

        let copy = base.duplicated()
        session.saveBaseSnapshot(copy)
        selectedID = copy.id
        editedName = copy.name
    }

    private func deleteSelectedBase() {
        guard let base = selectedBase else {
            return
        }

        session.deleteSavedBase(base)
        selectedID = session.savedBases.first?.id
        syncEditedName(with: selectedID)
    }
}
