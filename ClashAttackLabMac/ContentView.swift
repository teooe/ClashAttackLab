import Foundation
import SpriteKit
import SwiftUI

struct ContentView: View {
    @StateObject private var session = AttackLabSession()
    @State private var showingArmyBuilder = false
    @State private var showingBaseLibrary = false
    @State private var showingSavedBaseLibrary = false
    @State private var showingPlanLibrary = false
    @State private var showingAttackHistory = false
    @State private var showingStrategyAnalysis = false

    var body: some View {
        VStack(spacing: 0) {
            SearchProgressView(session: session)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clash Attack Lab")
                        .font(.title2.bold())

                    Text(
                        "Milestone 19 · \(session.activeBaseSnapshot.name) · Piano manuale"
                    )
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                Menu {
                    Button("Ottimizza deploy · esercito invariato") {
                        session.findBestAttack()
                    }
                    Button("Confronta anche altri eserciti") {
                        session.findBestArmyAndAttack()
                    }
                } label: {
                    Label("Trova attacco", systemImage: "wand.and.stars")
                }
                .disabled(session.isManualPlanning)
                .help("La ricerca degli eserciti usa sostituzioni a pari capacità del prototipo.")

                Button {
                    showingArmyBuilder = true
                } label: {
                    Label("Esercito", systemImage: "person.3.fill")
                }

                Button {
                    showingBaseLibrary = true
                } label: {
                    Label("Base", systemImage: "square.grid.3x3.fill")
                }

                Button {
                    showingSavedBaseLibrary = true
                } label: {
                    Label(
                        "Basi salvate",
                        systemImage: "square.stack.3d.up"
                    )
                }

                Button {
                    showingPlanLibrary = true
                } label: {
                    Label("Piani", systemImage: "tray.full")
                }

                Button {
                    showingAttackHistory = true
                } label: {
                    Label("Storico", systemImage: "clock.arrow.circlepath")
                }

                Button {
                    showingStrategyAnalysis = true
                } label: {
                    Label("Analisi", systemImage: "chart.bar.xaxis")
                }

                Button {
                    if session.isManualPlanning {
                        session.cancelManualPlanning()
                    } else {
                        session.beginManualPlanning()
                    }
                } label: {
                    Label(
                        session.isManualPlanning
                            ? "Annulla piano"
                            : "Piano manuale",
                        systemImage: "cursorarrow.rays"
                    )
                }

                Button {
                    session.scene.startSimulation()
                } label: {
                    Label("Avvia", systemImage: "play.fill")
                }
                .disabled(session.isManualPlanning)

                Button {
                    session.scene.togglePause()
                } label: {
                    Label("Pausa / Riprendi", systemImage: "pause.fill")
                }

                Menu("Velocità") {
                    Button("1×") {
                        session.scene.simulationSpeed = 1
                    }
                    Button("2×") {
                        session.scene.simulationSpeed = 2
                    }
                    Button("4×") {
                        session.scene.simulationSpeed = 4
                    }
                }

                Button {
                    session.restartSimulation()
                } label: {
                    Label("Riavvia", systemImage: "arrow.counterclockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
            .padding(.horizontal)
            .padding(.top)

            HStack(spacing: 12) {
                Button {
                    session.activateHeroAbility(for: .barbarianKing)
                } label: {
                    Label("Pugno di ferro", systemImage: "crown.fill")
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button {
                    session.activateHeroAbility(for: .archerQueen)
                } label: {
                    Label("Manto reale", systemImage: "scope")
                }
                .keyboardShortcut("2", modifiers: [.command])

                Text(session.heroAbilityMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()
            }
            .disabled(session.isManualPlanning)
            .padding(.horizontal)
            .padding(.bottom)

            Divider()

            VStack(spacing: 8) {
                HStack(spacing: 18) {
                    legendItem(
                        symbol: "G",
                        color: .orange,
                        title: "Gigante",
                        detail: "terra · difese"
                    )

                    legendItem(
                        symbol: "B",
                        color: .red,
                        title: "Barbaro",
                        detail: "terra · edifici"
                    )

                    legendItem(
                        symbol: "A",
                        color: .pink,
                        title: "Arciera",
                        detail: "terra · distanza"
                    )

                    legendItem(
                        symbol: "WB",
                        color: .green,
                        title: "Spaccamuro",
                        detail: "terra · muri"
                    )

                    legendItem(
                        symbol: "W",
                        color: .blue,
                        title: "Mago",
                        detail: "terra · area"
                    )
                }

                HStack(spacing: 18) {
                    legendItem(
                        symbol: "BL",
                        color: .indigo,
                        title: "Mongolfiera",
                        detail: "aria · difese"
                    )

                    legendItem(
                        symbol: "DR",
                        color: .mint,
                        title: "Drago",
                        detail: "aria · edifici"
                    )

                    legendItem(
                        symbol: "BK",
                        color: .yellow,
                        title: "Re barbaro",
                        detail: "eroe · corpo a corpo"
                    )

                    legendItem(
                        symbol: "AQ",
                        color: .purple,
                        title: "Regina",
                        detail: "eroe · distanza"
                    )

                    legendItem(
                        symbol: "AR",
                        color: .brown,
                        title: "Ariete",
                        detail: "Municipio · carico terrestre"
                    )

                    legendItem(
                        symbol: "SP",
                        color: .cyan,
                        title: "Schiantapietre",
                        detail: "aria · carico aereo"
                    )

                    Spacer()

                    Text("Ciano = traiettoria aerea diretta sui muri")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 18) {
                    legendItem(
                        symbol: "H",
                        color: .green,
                        title: "Cura",
                        detail: "recupero nella zona"
                    )

                    legendItem(
                        symbol: "R",
                        color: .purple,
                        title: "Furia",
                        detail: "danno + velocità"
                    )

                    legendItem(
                        symbol: "F",
                        color: .cyan,
                        title: "Gelo",
                        detail: "blocca le difese"
                    )

                    Spacer()

                    Text("Comportamenti e valori: prototipo esplicito")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 18) {
                    legendItem(
                        symbol: "C",
                        color: .gray,
                        title: "Cannone",
                        detail: "solo terra"
                    )

                    legendItem(
                        symbol: "TA",
                        color: .cyan,
                        title: "Torre",
                        detail: "terra + aria"
                    )

                    legendItem(
                        symbol: "MO",
                        color: .brown,
                        title: "Mortaio",
                        detail: "solo terra"
                    )

                    legendItem(
                        symbol: "AD",
                        color: .indigo,
                        title: "Difesa aerea",
                        detail: "solo aria"
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.thinMaterial)

            if session.isManualPlanning {
                Divider()
                manualPlannerBar
            }

            if !session.evaluations.isEmpty {
                Divider()
                comparisonBar
            }

            Divider()

            if let result = session.lastSimulationResult {
                Divider()
                simulationReport(result)
            }

            SpriteView(scene: session.scene)
                .frame(minWidth: 840, minHeight: 600)
        }
        .sheet(isPresented: $showingArmyBuilder) {
            ArmyEditorView(
                configuration: session.armyConfiguration
            ) { configuration in
                session.applyArmyConfiguration(configuration)
            }
        }
        .sheet(isPresented: $showingBaseLibrary) {
            BaseEditorView(
                layout: session.baseLayout,
                snapshot: session.activeBaseSnapshot,
                navigationGrid: session.editorNavigationGrid,
                savedBases: session.savedBases,
                onApply: { layout in
                    session.applyBaseLayout(layout)
                },
                onApplySnapshot: { snapshot in
                    session.applyImportedBase(snapshot)
                },
                onSaveSnapshot: { snapshot in
                    session.saveBaseSnapshot(snapshot)
                }
            )
        }
        .sheet(isPresented: $showingSavedBaseLibrary) {
            BaseLibraryManagerView(session: session)
        }
        .sheet(isPresented: $showingPlanLibrary) {
            PlanLibraryView(session: session)
        }
        .sheet(isPresented: $showingAttackHistory) {
            AttackHistoryView(session: session)
        }
        .sheet(isPresented: $showingStrategyAnalysis) {
            StrategyAnalysisView(session: session)
        }
    }


    private var manualPlannerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label(
                    "Piano manuale",
                    systemImage: "cursorarrow.rays"
                )
                .font(.headline)

                Text(
                    "Scegli una pedina, poi \(session.manualPlacementInstruction)."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Text(
                    String(
                        format: "prossimo @ %.1f s",
                        session.manualNextDeploymentTime
                    )
                )
                .font(.caption.monospacedDigit())

                Button("−0,5") {
                    session.adjustManualDeploymentTime(by: -0.5)
                }
                .font(.caption)

                Button("+0,5") {
                    session.adjustManualDeploymentTime(by: 0.5)
                }
                .font(.caption)
            }

            HStack(spacing: 8) {
                ForEach(session.manualTroopChoices, id: \.self) { kind in
                    manualChoice(
                        symbol: troopSymbol(for: kind),
                        color: troopColor(for: kind),
                        title: troopName(for: kind),
                        remaining:
                            session.armyConfiguration.troopCount(
                                for: kind
                            ) - session.manualPlan.troopCount(for: kind),
                        isSelected:
                            session.manualSelection == .troop(kind)
                    ) {
                        session.selectManualPlacement(.troop(kind))
                    }
                }

                Divider()
                    .frame(height: 30)

                ForEach(session.manualSpellChoices, id: \.self) { kind in
                    manualChoice(
                        symbol: spellSymbol(for: kind),
                        color: spellColor(for: kind),
                        title: spellName(for: kind),
                        remaining:
                            session.armyConfiguration.spellCount(
                                for: kind
                            ) - session.manualPlan.spellCount(for: kind),
                        isSelected:
                            session.manualSelection == .spell(kind)
                    ) {
                        session.selectManualPlacement(.spell(kind))
                    }
                }
            }

            manualHeroCommands

            if session.manualPlan.totalOrderCount == 0 {
                Text("Nessun ordine: scegli una truppa o un incantesimo e clicca nella fascia ciano.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(
                            session.manualPlan.orderedDeployments
                        ) { order in
                            manualOrderChip(
                                symbol: troopSymbol(for: order.kind),
                                color: troopColor(for: order.kind),
                                time: order.deploymentTime,
                                location:
                                    session.manualGridLabel(
                                        for: order.position
                                    )
                            )
                            .contextMenu {
                                Button("Anticipa di 0,5 s") {
                                    session.updateManualOrderTime(
                                        id: order.id,
                                        to: order.deploymentTime - 0.5
                                    )
                                }
                                Button("Ritarda di 0,5 s") {
                                    session.updateManualOrderTime(
                                        id: order.id,
                                        to: order.deploymentTime + 0.5
                                    )
                                }
                                Divider()
                                Button("Rimuovi ordine", role: .destructive) {
                                    session.removeManualOrder(id: order.id)
                                }
                            }
                        }

                        ForEach(
                            session.manualPlan.orderedSpellDeployments
                        ) { order in
                            manualOrderChip(
                                symbol: spellSymbol(for: order.kind),
                                color: spellColor(for: order.kind),
                                time: order.deploymentTime,
                                location:
                                    session.manualGridLabel(
                                        for: order.position
                                    )
                            )
                            .contextMenu {
                                Button("Anticipa di 0,5 s") {
                                    session.updateManualOrderTime(
                                        id: order.id,
                                        to: order.deploymentTime - 0.5
                                    )
                                }
                                Button("Ritarda di 0,5 s") {
                                    session.updateManualOrderTime(
                                        id: order.id,
                                        to: order.deploymentTime + 0.5
                                    )
                                }
                                Divider()
                                Button("Rimuovi ordine", role: .destructive) {
                                    session.removeManualOrder(id: order.id)
                                }
                            }
                        }
                    }
                }
            }

            HStack {
                Text(
                    "\(session.manualPlan.totalOrderCount) ordini · la simulazione resta ferma finché non carichi il piano"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)

                Spacer()

                Button("Rimuovi ultimo") {
                    session.removeLastManualOrder()
                }
                .disabled(session.manualPlan.totalOrderCount == 0)

                Button("Svuota") {
                    session.clearManualOrders()
                }
                .disabled(session.manualPlan.totalOrderCount == 0)

                Button("Carica piano") {
                    session.finishManualPlanning()
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.manualPlan.totalOrderCount == 0)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.cyan.opacity(0.08))
    }

    private var manualHeroCommands: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !session.manualPlan.heroDeployments.isEmpty {
                Text("Abilità eroi · l’attivazione automatica a vita bassa resta disponibile")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(session.manualPlan.heroDeployments) { deployment in
                    manualHeroCommandRow(deployment)
                }
            }
        }
    }

    private func manualHeroCommandRow(_ deployment: DeploymentOrder) -> some View {
        let command = session.manualPlan.heroAbilityOrders.first {
            $0.entityID == deployment.entityID
        }
        return HStack(spacing: 10) {
            Text(troopName(for: deployment.kind))
                .font(.caption.bold())
            if let command {
                Stepper(
                    value: Binding(
                        get: { command.activationTime },
                        set: { session.setManualHeroAbilityTime(
                            entityID: deployment.entityID, to: $0
                        ) }
                    ),
                    in: deployment.deploymentTime...59,
                    step: 0.5
                ) {
                    Text("Abilità @ \(command.activationTime, specifier: "%.1f") s")
                        .font(.caption.monospacedDigit())
                }
                .frame(width: 230)
                Button("Solo automatica") {
                    session.removeManualHeroAbility(entityID: deployment.entityID)
                }
                .font(.caption)
            } else {
                Text("Automatica")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Programma abilità") {
                    session.setManualHeroAbilityTime(
                        entityID: deployment.entityID,
                        to: deployment.deploymentTime + 4
                    )
                }
                .font(.caption)
            }
            Spacer()
        }
    }

    private func manualChoice(
        symbol: String,
        color: Color,
        title: String,
        remaining: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(symbol)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 22)
                    .background(color)
                    .clipShape(Capsule())

                Text("\(title) ×\(max(0, remaining))")
                    .font(.caption2.monospacedDigit())
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.18)
                    : Color.secondary.opacity(0.08)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(remaining <= 0)
        .opacity(remaining > 0 ? 1 : 0.38)
    }

    private func manualOrderChip(
        symbol: String,
        color: Color,
        time: TimeInterval,
        location: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(symbol)
                    .font(.caption2.bold())
                    .foregroundStyle(color)

                Text(String(format: "%.1f s", time))
                    .font(.caption2.monospacedDigit())
            }

            Text(location)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(7)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func troopName(for kind: BattleEntityKind) -> String {
        switch kind {
        case .giant:
            return "Gigante"
        case .barbarian:
            return "Barbaro"
        case .archer:
            return "Arciera"
        case .wallBreaker:
            return "Spaccamuro"
        case .wizard:
            return "Mago"
        case .balloon:
            return "Mongolfiera"
        case .dragon:
            return "Drago"
        case .barbarianKing:
            return "Re barbaro"
        case .archerQueen:
            return "Regina degli arcieri"
        case .wallWrecker:
            return "Ariete da guerra"
        case .stoneSlammer:
            return "Schiantapietre"
        case .cannon, .archerTower, .mortar, .airDefense,
             .townHall, .goldStorage, .wall:
            return "Edificio"
        }
    }

    private func troopSymbol(for kind: BattleEntityKind) -> String {
        switch kind {
        case .giant:
            return "G"
        case .barbarian:
            return "B"
        case .archer:
            return "A"
        case .wallBreaker:
            return "WB"
        case .wizard:
            return "W"
        case .balloon:
            return "BL"
        case .dragon:
            return "DR"
        case .barbarianKing:
            return "BK"
        case .archerQueen:
            return "AQ"
        case .wallWrecker:
            return "AR"
        case .stoneSlammer:
            return "SP"
        case .cannon, .archerTower, .mortar, .airDefense,
             .townHall, .goldStorage, .wall:
            return "?"
        }
    }

    private func troopColor(for kind: BattleEntityKind) -> Color {
        switch kind {
        case .giant:
            return .orange
        case .barbarian:
            return .red
        case .archer:
            return .pink
        case .wallBreaker:
            return .green
        case .wizard:
            return .blue
        case .balloon:
            return .indigo
        case .dragon:
            return .mint
        case .barbarianKing:
            return .yellow
        case .archerQueen:
            return .purple
        case .wallWrecker:
            return .brown
        case .stoneSlammer:
            return .cyan
        case .cannon, .archerTower, .mortar, .airDefense,
             .townHall, .goldStorage, .wall:
            return .gray
        }
    }

    private func spellName(for kind: BattleSpellKind) -> String {
        switch kind {
        case .heal:
            return "Cura"
        case .rage:
            return "Furia"
        case .freeze:
            return "Gelo"
        case .lightning:
            return "Fulmine"
        }
    }

    private func spellSymbol(for kind: BattleSpellKind) -> String {
        switch kind {
        case .heal:
            return "H"
        case .rage:
            return "R"
        case .freeze:
            return "F"
        case .lightning:
            return "L"
        }
    }

    private func spellColor(for kind: BattleSpellKind) -> Color {
        switch kind {
        case .heal:
            return .green
        case .rage:
            return .purple
        case .freeze:
            return .cyan
        case .lightning:
            return .yellow
        }
    }

    private func simulationReport(_ result: SimulationResult) -> some View {
        let attackersWon: Bool
        switch result.winner {
        case .attackers:
            attackersWon = true
        case .defenses:
            attackersWon = false
        }

        return HStack(spacing: 14) {
            Label(
                "\(result.winner.displayName) · \(result.finishReason.displayName)",
                systemImage: attackersWon
                    ? "checkmark.circle.fill"
                    : "xmark.circle.fill"
            )
            .foregroundStyle(
                attackersWon ? .green : .red
            )

            Text("⭐ \(result.score.stars)")
            Text("\(result.score.destructionPercentage, specifier: "%.1f")% distrutto")
            Text("Superstiti \(result.survivingTroops)")
            Text("Perse \(result.metrics.troopsLost)")
            Text("\(result.elapsedTime, specifier: "%.1f") s")
            Text("Danni \(result.metrics.damageToBase, specifier: "%.0f")")

            Spacer()
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
    }

    private var comparisonBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    "Piani simulati · \(session.activeBaseSnapshot.name)",
                    systemImage: "cpu"
                )
                .font(.caption.bold())

                Spacer()

                Text("Seleziona un risultato oppure premi Avvia per rivedere quello caricato")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(
                        session.evaluations.indices,
                        id: \.self
                    ) { index in
                        planCard(
                            evaluation: session.evaluations[index],
                            rank: index + 1
                        )
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.06))
    }

    private func planCard(
        evaluation: AttackPlanEvaluation,
        rank: Int
    ) -> some View {
        let isSelected = session.selectedPlanID == evaluation.plan.id
        let isBest = rank == 1

        return Button {
            session.select(evaluation)
        } label: {
            HStack(spacing: 10) {
                Text("#\(rank)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(isBest ? .green : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(evaluation.plan.name)
                            .font(.caption.bold())

                        if isBest {
                            Text("MIGLIORE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.green)
                        }
                    }

                    Text(armySummary(for: evaluation.plan.armyConfiguration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(
                        String(
                            format: "%d★ · %.0f%% · %.1f s · %d superstiti",
                            evaluation.stars,
                            evaluation.destructionPercentage,
                            evaluation.result.elapsedTime,
                            evaluation.result.survivingTroops
                        )
                    )
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)

                    Text(
                        String(
                            format: "Danno %.0f · Perse %d · Muri %d · %@",
                            evaluation.result.metrics.damageToBase,
                            evaluation.result.metrics.troopsLost,
                            evaluation.result.metrics.destroyedWalls,
                            evaluation.result.finishReason.displayName
                        )
                    )
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.16)
                    : Color.primary.opacity(0.045)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(
                        isSelected
                            ? Color.accentColor.opacity(0.8)
                            : Color.primary.opacity(0.1),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func armySummary(for army: ArmyConfiguration) -> String {
        let counts: [(String, Int)] = [
            ("G", army.giants), ("B", army.barbarians), ("A", army.archers),
            ("WB", army.wallBreakers), ("W", army.wizards),
            ("BL", army.balloons), ("DR", army.dragons),
            ("BK", army.barbarianKings), ("AQ", army.archerQueens),
            ("AR", army.wallWreckers), ("SP", army.stoneSlammers)
        ]
        let units = counts.filter { $0.1 > 0 }.map { "\($0.0)×\($0.1)" }
        return units.joined(separator: " · ")
    }

    private func legendItem(
        symbol: String,
        color: Color,
        title: String,
        detail: String
    ) -> some View {
        HStack(spacing: 7) {
            Text(symbol)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 28, height: 24)
                .background(color)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.bold())
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SearchProgressView: View {
    @ObservedObject var session: AttackLabSession

    var body: some View {
        if session.isSearching {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.searchTitle)
                        .font(.caption.bold())
                    ProgressView(
                        value: Double(session.searchCompleted),
                        total: Double(max(1, session.searchTotal))
                    )
                    Text("\(session.searchCompleted)/\(session.searchTotal) simulazioni")
                        .font(.caption2.monospacedDigit())
                }
                Button("Annulla ricerca") { session.cancelSearch() }
                    .font(.caption)
            }
            .padding(10)
            .background(Color.accentColor.opacity(0.08))
        } else if !session.searchMessage.isEmpty {
            Text(session.searchMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(6)
        }
    }
}

#Preview {
    ContentView()
}
