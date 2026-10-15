import Foundation

/// A real village typed in by hand or transcribed from a screenshot.
///
/// Coordinates use the 44×44 buildable area as seen from above: column 0
/// is the left edge, row 0 the top edge, and every building is placed by
/// the top-left tile of its footprint.
nonisolated struct RealBaseLayout: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String

    /// Town Hall level the base belongs to, when the file names one.
    var townHall: Int?

    var buildings: [RealBaseBuilding]

    init(
        id: UUID = UUID(),
        name: String,
        townHall: Int? = nil,
        buildings: [RealBaseBuilding]
    ) {
        self.id = id
        self.name = name
        self.townHall = townHall
        self.buildings = buildings
    }
}

nonisolated struct RealBaseBuilding: Codable, Equatable {
    let kind: BattleEntityKind
    let column: Int
    let row: Int
}

nonisolated struct RealBaseIssue: Equatable, Identifiable {
    let isError: Bool
    let text: String

    var id: String {
        "\(isError)-\(text)"
    }
}

/// Base picked in the real mode's menu.
nonisolated enum RealBaseChoice: Hashable {
    case generated(PrototypeBaseLayout)
    case imported(UUID)
}

/// Outcome of importing a base file, with the messages to show.
nonisolated struct RealBaseImportReport: Equatable {
    let imported: Bool
    let messages: [String]
}

// MARK: - Validation and placement

extension RealBaseLayout {
    /// Footprint side in tiles; traps and walls take one tile.
    static func footprint(
        of kind: BattleEntityKind,
        catalog: ReferenceGameCatalog
    ) -> Int {
        min(max(catalog.unit(for: kind)?.size ?? 1, 1), RealBattleMap.buildableTiles)
    }

    /// Errors make the base unusable; warnings only flag unusual counts.
    func issues(catalog: ReferenceGameCatalog) -> [RealBaseIssue] {
        var issues: [RealBaseIssue] = []
        let size = RealBattleMap.buildableTiles

        if let townHall, !GameDataSource.referenceTownHalls.contains(townHall) {
            issues.append(RealBaseIssue(
                isError: true,
                text: "Municipio \(townHall) non supportato: usa un livello da \(GameDataSource.referenceTownHalls.first ?? 7) a \(GameDataSource.referenceTownHalls.last ?? 18)."
            ))
        }

        let townHalls = buildings.filter { $0.kind == .townHall }.count
        if townHalls != 1 {
            issues.append(RealBaseIssue(
                isError: true,
                text: "Serve esattamente un Municipio (trovati \(townHalls))."
            ))
        }

        let troops = Set(buildings.map(\.kind).filter {
            PrototypeGameData().definition(for: $0).role == .troop
        })
        for kind in troops.sorted(by: { $0.referenceKey < $1.referenceKey }) {
            issues.append(RealBaseIssue(
                isError: true,
                text: "\(PrototypeGameData().definition(for: kind).displayName) è una truppa, non un edificio."
            ))
        }

        var owner: [GridCoordinate: Int] = [:]
        var reportedOverlaps: Set<String> = []
        for (index, building) in buildings.enumerated() where !troops.contains(building.kind) {
            let side = Self.footprint(of: building.kind, catalog: catalog)
            let name = PrototypeGameData().definition(for: building.kind).displayName
            guard
                building.column >= 0, building.row >= 0,
                building.column + side <= size, building.row + side <= size
            else {
                issues.append(RealBaseIssue(
                    isError: true,
                    text: "\(name) in \(building.column),\(building.row) esce dalla mappa 44×44."
                ))
                continue
            }
            for column in building.column..<(building.column + side) {
                for row in building.row..<(building.row + side) {
                    let tile = GridCoordinate(column: column, row: row)
                    if let other = owner[tile] {
                        let otherBuilding = buildings[other]
                        let key = "\(other)-\(index)"
                        if reportedOverlaps.insert(key).inserted {
                            let otherName = PrototypeGameData()
                                .definition(for: otherBuilding.kind).displayName
                            issues.append(RealBaseIssue(
                                isError: true,
                                text: "\(name) in \(building.column),\(building.row) si sovrappone a \(otherName) in \(otherBuilding.column),\(otherBuilding.row)."
                            ))
                        }
                    } else {
                        owner[tile] = index
                    }
                }
            }
        }

        if let townHall {
            let counts = Dictionary(grouping: buildings, by: \.kind).mapValues(\.count)
            for (kind, count) in counts.sorted(by: { $0.key.referenceKey < $1.key.referenceKey }) {
                guard
                    let unit = catalog.unit(for: kind),
                    unit.countByTownHall != nil
                else {
                    continue
                }
                let allowed = unit.count(atTownHall: townHall)
                if count > allowed {
                    issues.append(RealBaseIssue(
                        isError: false,
                        text: "\(PrototypeGameData().definition(for: kind).displayName): \(count) piazzati, al Municipio \(townHall) ne sono permessi \(allowed)."
                    ))
                }
            }
        } else {
            issues.append(RealBaseIssue(
                isError: false,
                text: "Il file non indica il livello del Municipio: uso quello della modalità scelta."
            ))
        }

        return issues
    }

    func isUsable(catalog: ReferenceGameCatalog) -> Bool {
        !issues(catalog: catalog).contains(where: \.isError)
    }

    /// Battle entities centred on their footprints on the real map.
    func makeEntities(
        navigationGrid: NavigationGrid,
        catalog: ReferenceGameCatalog
    ) -> [BattleEntity] {
        let border = RealBattleMap.borderTiles
        let size = RealBattleMap.buildableTiles
        return buildings.map { building in
            let side = Self.footprint(of: building.kind, catalog: catalog)
            // Rows count from the top in the file and from the bottom on
            // the grid.
            let gridColumn = border + building.column
            let gridRow = border + size - building.row - side
            return BattleEntity(
                id: SimulationIdentity.make(
                    "imported:\(id):\(building.kind):\(building.column):\(building.row)"
                ),
                kind: building.kind,
                position: WorldPosition(
                    x: navigationGrid.origin.x +
                        (Double(gridColumn) + Double(side) / 2) * navigationGrid.cellSize,
                    y: navigationGrid.origin.y +
                        (Double(gridRow) + Double(side) / 2) * navigationGrid.cellSize
                )
            )
        }
    }
}

// MARK: - Text format

nonisolated struct RealBaseParseError: Error, Equatable {
    let line: Int
    let message: String

    var description: String {
        "Riga \(line): \(message)"
    }
}

/// Reads and writes the plain-text base format.
///
/// ```
/// # Comments start with a hash.
/// nome La mia base
/// livello 15
/// townHall 20 20
/// xBow 14 14
/// wall 10 10 - 33 10
/// ```
///
/// Each building line holds a kind and the top-left tile of its footprint.
/// Kinds accept the catalog key (`infernoTower`) or the Italian name
/// without spaces (`torreinfernale`), in any case. A `-` between two
/// tiles draws a straight line of walls or other one-tile pieces.
nonisolated enum RealBaseLayoutText {
    static func parse(_ text: String, defaultName: String = "Base importata") throws -> RealBaseLayout {
        var name = defaultName
        var townHall: Int?
        var buildings: [RealBaseBuilding] = []

        for (offset, rawLine) in text.components(separatedBy: .newlines).enumerated() {
            let lineNumber = offset + 1
            let line = rawLine
                .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
                .first.map(String.init)?
                .trimmingCharacters(in: .whitespaces) ?? ""
            guard !line.isEmpty else {
                continue
            }
            let words = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            let keyword = normalized(words[0])

            if keyword == "nome" || keyword == "name" {
                let value = words.dropFirst().joined(separator: " ")
                guard !value.isEmpty else {
                    throw RealBaseParseError(line: lineNumber, message: "manca il nome della base.")
                }
                name = value
                continue
            }
            if keyword == "livello" || keyword == "th" || keyword == "level" {
                guard words.count == 2, let level = Int(words[1]) else {
                    throw RealBaseParseError(line: lineNumber, message: "scrivi il livello così: livello 15.")
                }
                townHall = level
                continue
            }

            guard let kind = kind(named: words[0]) else {
                throw RealBaseParseError(line: lineNumber, message: "edificio sconosciuto «\(words[0])».")
            }
            let numbers = words.dropFirst().filter { $0 != "-" }
            let isLine = words.contains("-")
            guard numbers.allSatisfy({ Int($0) != nil }) else {
                throw RealBaseParseError(line: lineNumber, message: "le coordinate devono essere numeri interi.")
            }
            let values = numbers.compactMap { Int($0) }

            if isLine {
                guard values.count == 4 else {
                    throw RealBaseParseError(line: lineNumber, message: "una linea va scritta così: \(words[0]) 10 5 - 20 5.")
                }
                let (fromColumn, fromRow, toColumn, toRow) = (values[0], values[1], values[2], values[3])
                guard fromColumn == toColumn || fromRow == toRow else {
                    throw RealBaseParseError(line: lineNumber, message: "le linee devono essere orizzontali o verticali.")
                }
                let columnStep = toColumn == fromColumn ? 0 : (toColumn > fromColumn ? 1 : -1)
                let rowStep = toRow == fromRow ? 0 : (toRow > fromRow ? 1 : -1)
                let length = max(abs(toColumn - fromColumn), abs(toRow - fromRow))
                for step in 0...length {
                    buildings.append(RealBaseBuilding(
                        kind: kind,
                        column: fromColumn + step * columnStep,
                        row: fromRow + step * rowStep
                    ))
                }
            } else {
                guard values.count == 2 else {
                    throw RealBaseParseError(line: lineNumber, message: "scrivi edificio, colonna e riga: \(words[0]) 12 7.")
                }
                buildings.append(RealBaseBuilding(kind: kind, column: values[0], row: values[1]))
            }
        }

        guard !buildings.isEmpty else {
            throw RealBaseParseError(line: 0, message: "il file non contiene edifici.")
        }
        return RealBaseLayout(name: name, townHall: townHall, buildings: buildings)
    }

    /// Writes a layout back in the same format, one building per line.
    static func format(_ layout: RealBaseLayout) -> String {
        var lines = ["nome \(layout.name)"]
        if let townHall = layout.townHall {
            lines.append("livello \(townHall)")
        }
        lines += layout.buildings.map {
            "\($0.kind.referenceKey) \($0.column) \($0.row)"
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Kind for a catalog key or an Italian display name, ignoring case,
    /// accents, spaces and punctuation.
    static func kind(named word: String) -> BattleEntityKind? {
        names[normalized(word)]
    }

    /// Every accepted spelling, built once: aliases first, then display
    /// names, then catalog keys, so the more precise spelling wins.
    private static let names: [String: BattleEntityKind] = {
        var names = aliases
        let prototype = PrototypeGameData()
        for kind in BattleEntityKind.allCases {
            names[normalized(prototype.definition(for: kind).displayName)] = kind
        }
        for kind in BattleEntityKind.allCases {
            names[normalized(kind.referenceKey)] = kind
        }
        return names
    }()

    private static let aliases: [String: BattleEntityKind] = [
        "municipio": .townHall,
        "muro": .wall,
        "balestra": .xBow,
        "aquila": .eagleArtillery,
        "inferno": .infernoTower,
        "tesla": .hiddenTesla,
        "scattershot": .scattershot,
        "deposito": .goldStorage,
        "depositooro": .goldStorage,
        "capanna": .builderHut
    ]

    static func normalized(_ word: String) -> String {
        word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .filter { $0.isLetter || $0.isNumber }
            .lowercased()
    }
}

// MARK: - Bundled bases

extension RealBaseLayout {
    /// Bases shipped in the app's `Bases` folder, sorted by name. Files
    /// that do not parse are skipped.
    static func bundled() -> [RealBaseLayout] {
        let bundle = Bundle(for: RealBaseBundleToken.self)
        let urls = bundle.urls(forResourcesWithExtension: "txt", subdirectory: nil) ?? []
        return urls.compactMap { url -> RealBaseLayout? in
            guard
                let text = try? String(contentsOf: url, encoding: .utf8),
                var layout = try? RealBaseLayoutText.parse(
                    text,
                    defaultName: url.deletingPathExtension().lastPathComponent
                )
            else {
                return nil
            }
            // A stable identity keeps the base selected across launches.
            layout.id = SimulationIdentity.make("bundled-base:\(url.lastPathComponent)")
            return layout
        }
        .sorted { $0.name < $1.name }
    }
}

nonisolated private final class RealBaseBundleToken {}
