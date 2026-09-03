import Foundation

nonisolated enum BaseValidationSeverity: Hashable {
    case error
    case warning
}

nonisolated struct BaseValidationMessage: Identifiable, Hashable {
    let severity: BaseValidationSeverity
    let text: String

    var id: String {
        "\(severity)-\(text)"
    }
}

nonisolated struct BaseSnapshotValidationReport {
    let messages: [BaseValidationMessage]

    var errors: [BaseValidationMessage] {
        messages.filter { $0.severity == .error }
    }

    var warnings: [BaseValidationMessage] {
        messages.filter { $0.severity == .warning }
    }

    var isBuildable: Bool {
        errors.isEmpty
    }

    static func validate(
        _ snapshot: BaseSnapshot,
        on grid: NavigationGrid
    ) -> BaseSnapshotValidationReport {
        var messages: [BaseValidationMessage] = []

        if snapshot.formatVersion != BaseSnapshot.currentFormatVersion {
            messages.append(
                BaseValidationMessage(
                    severity: .error,
                    text: "Formato base non supportato."
                )
            )
        }

        if snapshot.objects.isEmpty {
            messages.append(
                BaseValidationMessage(
                    severity: .error,
                    text: "La base non contiene strutture."
                )
            )
        }

        let coordinates = snapshot.objects.map {
            "\($0.column):\($0.row)"
        }
        if Set(coordinates).count != coordinates.count {
            messages.append(
                BaseValidationMessage(
                    severity: .error,
                    text: "Due strutture occupano la stessa cella."
                )
            )
        }

        if snapshot.objects.contains(where: {
            !grid.contains(
                GridCoordinate(column: $0.column, row: $0.row)
            )
        }) {
            messages.append(
                BaseValidationMessage(
                    severity: .error,
                    text: "Una o più strutture sono fuori dalla griglia."
                )
            )
        }

        let townHallCount = snapshot.objects.filter {
            $0.kind == .townHall
        }.count
        if townHallCount != 1 {
            messages.append(
                BaseValidationMessage(
                    severity: .error,
                    text: "Serve esattamente un Municipio."
                )
            )
        }

        let defenseKinds: Set<BattleEntityKind> = [
            .cannon,
            .archerTower,
            .mortar,
            .airDefense
        ]
        let defenseCount = snapshot.objects.filter {
            defenseKinds.contains($0.kind)
        }.count
        if defenseCount == 0 {
            messages.append(
                BaseValidationMessage(
                    severity: .error,
                    text: "Aggiungi almeno una difesa."
                )
            )
        }

        if snapshot.objects.contains(where: { $0.column <= 2 }) {
            messages.append(
                BaseValidationMessage(
                    severity: .warning,
                    text: "La fascia di deploy è occupata: le truppe potrebbero partire dentro una struttura."
                )
            )
        }

        if snapshot.objects.allSatisfy({ $0.kind != .wall }) {
            messages.append(
                BaseValidationMessage(
                    severity: .warning,
                    text: "La base non contiene muri."
                )
            )
        }

        return BaseSnapshotValidationReport(messages: messages)
    }
}
