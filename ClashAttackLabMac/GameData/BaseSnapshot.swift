import Foundation
import SwiftUI
import UniformTypeIdentifiers

nonisolated struct BaseObjectSnapshot: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: BattleEntityKind
    let column: Int
    let row: Int

    init(
        id: UUID = UUID(),
        kind: BattleEntityKind,
        column: Int,
        row: Int
    ) {
        self.id = id
        self.kind = kind
        self.column = column
        self.row = row
    }
}

nonisolated struct BaseSnapshot: Identifiable, Codable, Equatable {
    static let currentFormatVersion = 1

    let id: UUID
    var name: String
    let formatVersion: Int
    var objects: [BaseObjectSnapshot]

    init(
        id: UUID = UUID(),
        name: String,
        objects: [BaseObjectSnapshot],
        formatVersion: Int = BaseSnapshot.currentFormatVersion
    ) {
        self.id = id
        self.name = name
        self.objects = objects
        self.formatVersion = formatVersion
    }

    static func make(
        from layout: PrototypeBaseLayout,
        navigationGrid: NavigationGrid
    ) -> BaseSnapshot {
        let entities = PrototypeBattleMap.makeBaseEntities(
            navigationGrid: navigationGrid,
            layout: layout
        )
        let objects = entities.compactMap { entity -> BaseObjectSnapshot? in
            guard let coordinate = navigationGrid.coordinate(
                for: entity.position
            ) else {
                return nil
            }

            return BaseObjectSnapshot(
                id: entity.id,
                kind: entity.kind,
                column: coordinate.column,
                row: coordinate.row
            )
        }

        return BaseSnapshot(name: layout.displayName, objects: objects)
    }

    func makeEntities(
        navigationGrid: NavigationGrid
    ) -> [BattleEntity] {
        objects.compactMap { object in
            let coordinate = GridCoordinate(
                column: object.column,
                row: object.row
            )
            guard navigationGrid.contains(coordinate) else {
                return nil
            }

            return BattleEntity(
                id: object.id,
                kind: object.kind,
                position: navigationGrid.worldPosition(for: coordinate)
            )
        }
    }

    var wallCount: Int {
        objects.filter { $0.kind == .wall }.count
    }

    var objectiveCount: Int {
        objects.filter { $0.kind != .wall }.count
    }

    var isValid: Bool {
        formatVersion == BaseSnapshot.currentFormatVersion &&
            !objects.isEmpty &&
            objectiveCount > 0 &&
            Set(objects.map { "\($0.column):\($0.row)" }).count ==
                objects.count
    }

    func object(
        atColumn column: Int,
        row: Int
    ) -> BaseObjectSnapshot? {
        objects.first {
            $0.column == column && $0.row == row
        }
    }

    func isValid(on grid: NavigationGrid) -> Bool {
        isValid &&
            objects.allSatisfy {
                grid.contains(
                    GridCoordinate(column: $0.column, row: $0.row)
                )
            }
    }

    mutating func place(
        _ kind: BattleEntityKind,
        atColumn column: Int,
        row: Int
    ) {
        objects.removeAll {
            $0.column == column && $0.row == row
        }
        objects.append(
            BaseObjectSnapshot(
                kind: kind,
                column: column,
                row: row
            )
        )
    }

    mutating func removeObject(atColumn column: Int, row: Int) {
        objects.removeAll {
            $0.column == column && $0.row == row
        }
    }

    func duplicated(named name: String? = nil) -> BaseSnapshot {
        BaseSnapshot(
            name: name ?? "\(self.name) copia",
            objects: objects,
            formatVersion: formatVersion
        )
    }
}

struct BaseSnapshotDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var snapshot: BaseSnapshot

    init(snapshot: BaseSnapshot) {
        self.snapshot = snapshot
    }

    init(configuration: ReadConfiguration) throws {
        snapshot = try JSONDecoder().decode(
            BaseSnapshot.self,
            from: configuration.file.regularFileContents ?? Data()
        )
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(snapshot))
    }
}
