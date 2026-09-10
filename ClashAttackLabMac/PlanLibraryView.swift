import SwiftUI

struct PlanLibraryView: View {
    @ObservedObject var session: AttackLabSession
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlanIDs: Set<UUID> = []
    @State private var showingRename = false
    @State private var renameText = ""
    @State private var planToRename: AttackPlan?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Piani d’attacco", systemImage: "tray.full")
                    .font(.title2.bold())
                Spacer()
                Button("Fine") { dismiss() }
            }

            Text("Le abilità attivate durante l’attacco vengono registrate nel piano e riprodotte al riavvio.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    session.saveCurrentPlan()
                } label: {
                    Label("Salva piano corrente", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    session.compareSavedPlans(
                        session.savedPlans.filter {
                            selectedPlanIDs.contains($0.id)
                        }
                    )
                } label: {
                    Label(
                        "Confronta \(selectedPlanIDs.count)",
                        systemImage: "arrow.left.arrow.right"
                    )
                }
                .disabled(selectedPlanIDs.count < 2)

                Spacer()

                Text("\(session.savedPlans.count) salvati")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if session.savedPlans.isEmpty {
                ContentUnavailableView(
                    "Nessun piano salvato",
                    systemImage: "tray",
                    description: Text("Salva il piano corrente per ritrovarlo qui.")
                )
            } else {
                List {
                    ForEach(session.savedPlans) { plan in
                        HStack(spacing: 10) {
                            Toggle(
                                isOn: Binding(
                                    get: { selectedPlanIDs.contains(plan.id) },
                                    set: { selected in
                                        if selected {
                                            selectedPlanIDs.insert(plan.id)
                                        } else {
                                            selectedPlanIDs.remove(plan.id)
                                        }
                                    }
                                )
                            ) {
                                EmptyView()
                            }
                            .toggleStyle(.checkbox)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(plan.name)
                                    .font(.headline)
                                Text(
                                    "\(plan.totalDeploymentCount) truppe · \(plan.totalSpellCount) incantesimi · \(plan.heroAbilityOrders.count) comandi eroe · ultimo ordine \(String(format: "%.1f", plan.latestDeploymentTime)) s"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Apri") {
                                session.loadSavedPlan(plan)
                                dismiss()
                            }
                            .buttonStyle(.bordered)

                            Button("Modifica") {
                                session.editSavedPlan(plan)
                                dismiss()
                            }
                            .buttonStyle(.bordered)

                            Menu {
                                Button("Rinomina") {
                                    planToRename = plan
                                    renameText = plan.name
                                    showingRename = true
                                }
                                Button("Duplica") {
                                    session.duplicateSavedPlan(plan)
                                }
                                Button("Elimina", role: .destructive) {
                                    session.deleteSavedPlan(plan)
                                    selectedPlanIDs.remove(plan.id)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .menuStyle(.borderlessButton)
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { offsets, destination in
                        session.moveSavedPlans(from: offsets, to: destination)
                    }
                }
                .frame(minHeight: 230)
            }

            if !session.comparisonEvaluations.isEmpty {
                Divider()
                Text("Confronto simulato")
                    .font(.headline)

                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(session.comparisonEvaluations) { evaluation in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(evaluation.plan.name)
                                    .font(.subheadline.bold())
                                Text("⭐ \(evaluation.stars) · \(evaluation.destructionPercentage, specifier: "%.1f")%")
                                Text("Superstiti: \(evaluation.result.survivingTroops)")
                                Text("Persi: \(evaluation.result.metrics.troopsLost)")
                                Text("Durata: \(evaluation.result.elapsedTime, specifier: "%.1f") s")
                                Text("Danno: \(evaluation.result.metrics.damageToBase, specifier: "%.0f")")
                            }
                            .font(.caption)
                            .padding(10)
                            .frame(width: 190, alignment: .leading)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 560)
        .alert("Rinomina piano", isPresented: $showingRename) {
            TextField("Nome", text: $renameText)
            Button("Annulla", role: .cancel) {}
            Button("Salva") {
                if let plan = planToRename {
                    session.renameSavedPlan(plan, to: renameText)
                }
            }
        }
    }
}
