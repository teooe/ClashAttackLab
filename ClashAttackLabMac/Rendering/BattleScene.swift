import SpriteKit

final class BattleScene: SKScene {
    private struct EntityVisual {
        let root: SKNode
        let healthFill: SKSpriteNode
        let healthLabel: SKLabelNode
        let targetLine: SKShapeNode
    }

    private let simulation: SimulationEngine
    private let navigationGrid: NavigationGrid
    private var entityVisuals: [UUID: EntityVisual] = [:]
    private var lastUpdateTime: TimeInterval?

    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let resultLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    var simulationSpeed: Double = 1

    init(
        size: CGSize,
        simulation: SimulationEngine,
        navigationGrid: NavigationGrid
    ) {
        self.simulation = simulation
        self.navigationGrid = navigationGrid
        super.init(size: size)
        scaleMode = .aspectFit
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.16, green: 0.34, blue: 0.18, alpha: 1)
        drawArena()
        drawNavigationGrid()
        configureLabels()
        createEntityNodes()
        updatePresentation()
    }

    override func update(_ currentTime: TimeInterval) {
        let deltaTime: TimeInterval

        if let lastUpdateTime {
            deltaTime = min(currentTime - lastUpdateTime, 0.05)
        } else {
            deltaTime = 0
        }

        self.lastUpdateTime = currentTime
        simulation.advance(by: deltaTime * simulationSpeed)
        updatePresentation()
    }

    func restartSimulation() {
        simulation.reset()
        lastUpdateTime = nil
        updatePresentation()
    }

    private func drawArena() {
        let arena = SKShapeNode(
            rect: CGRect(
                x: 40,
                y: 40,
                width: size.width - 80,
                height: size.height - 80
            ),
            cornerRadius: 16
        )
        arena.fillColor = SKColor(
            red: 0.22,
            green: 0.46,
            blue: 0.24,
            alpha: 1
        )
        arena.strokeColor = .white.withAlphaComponent(0.35)
        arena.lineWidth = 3
        addChild(arena)
    }

    private func drawNavigationGrid() {
        for column in 0...navigationGrid.columns {
            let x = navigationGrid.origin.x +
                Double(column) * navigationGrid.cellSize
            let path = CGMutablePath()
            path.move(
                to: CGPoint(x: x, y: navigationGrid.origin.y)
            )
            path.addLine(
                to: CGPoint(
                    x: x,
                    y: navigationGrid.origin.y +
                        Double(navigationGrid.rows) *
                        navigationGrid.cellSize
                )
            )

            let line = SKShapeNode(path: path)
            line.strokeColor = .white.withAlphaComponent(0.04)
            line.lineWidth = 1
            line.zPosition = 1
            addChild(line)
        }

        for row in 0...navigationGrid.rows {
            let y = navigationGrid.origin.y +
                Double(row) * navigationGrid.cellSize
            let path = CGMutablePath()
            path.move(
                to: CGPoint(x: navigationGrid.origin.x, y: y)
            )
            path.addLine(
                to: CGPoint(
                    x: navigationGrid.origin.x +
                        Double(navigationGrid.columns) *
                        navigationGrid.cellSize,
                    y: y
                )
            )

            let line = SKShapeNode(path: path)
            line.strokeColor = .white.withAlphaComponent(0.04)
            line.lineWidth = 1
            line.zPosition = 1
            addChild(line)
        }
    }

    private func configureLabels() {
        statusLabel.fontSize = 17
        statusLabel.fontColor = .white
        statusLabel.horizontalAlignmentMode = .left
        statusLabel.position = CGPoint(x: 65, y: size.height - 30)
        statusLabel.zPosition = 40
        addChild(statusLabel)

        scoreLabel.fontSize = 20
        scoreLabel.fontColor = .systemYellow
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(
            x: size.width - 65,
            y: size.height - 30
        )
        scoreLabel.zPosition = 40
        addChild(scoreLabel)

        resultLabel.fontSize = 18
        resultLabel.fontColor = .white
        resultLabel.position = CGPoint(x: size.width / 2, y: 55)
        resultLabel.zPosition = 40
        resultLabel.isHidden = true
        addChild(resultLabel)
    }

    private func createEntityNodes() {
        for entity in simulation.entities {
            let definition = simulation.definition(for: entity.kind)
            let root = SKNode()
            let body = makeBody(for: entity.kind)
            root.addChild(body)

            let isWall = definition.role == .wall
            let healthWidth = isWall ? 34.0 : 88.0
            let healthY = isWall ? -25.0 : -52.0

            let healthBackground = SKSpriteNode(
                color: .black.withAlphaComponent(0.58),
                size: CGSize(width: healthWidth + 4, height: 10)
            )
            healthBackground.position = CGPoint(x: 0, y: healthY)
            healthBackground.zPosition = 10
            root.addChild(healthBackground)

            let healthFill = SKSpriteNode(
                color: .systemGreen,
                size: CGSize(width: healthWidth, height: 6)
            )
            healthFill.anchorPoint = CGPoint(x: 0, y: 0.5)
            healthFill.position = CGPoint(
                x: -healthWidth / 2,
                y: healthY
            )
            healthFill.zPosition = 11
            root.addChild(healthFill)

            let healthLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
            healthLabel.fontSize = 11
            healthLabel.fontColor = .white
            healthLabel.verticalAlignmentMode = .center
            healthLabel.position = CGPoint(x: 0, y: -69)
            healthLabel.zPosition = 12
            healthLabel.isHidden = isWall
            root.addChild(healthLabel)

            let targetLine = SKShapeNode()
            targetLine.strokeColor =
                definition.role == .troop
                    ? .systemYellow
                    : .systemRed
            targetLine.lineWidth = 2
            targetLine.alpha = 0.48
            targetLine.zPosition = 5
            addChild(targetLine)

            root.zPosition = isWall ? 7 : 15

            entityVisuals[entity.id] = EntityVisual(
                root: root,
                healthFill: healthFill,
                healthLabel: healthLabel,
                targetLine: targetLine
            )
            addChild(root)
        }
    }

    private func updatePresentation() {
        let entitiesByID = Dictionary(
            uniqueKeysWithValues: simulation.entities.map { ($0.id, $0) }
        )

        for entity in simulation.entities {
            guard let visual = entityVisuals[entity.id] else {
                continue
            }

            let definition = simulation.definition(for: entity.kind)
            let healthFraction = simulation.healthFraction(for: entity)

            visual.root.position = CGPoint(
                x: entity.position.x,
                y: entity.position.y
            )
            visual.root.alpha = entity.isAlive ? 1 : 0.08
            visual.healthFill.xScale = healthFraction
            visual.healthFill.color =
                healthFraction > 0.35 ? .systemGreen : .systemRed
            visual.healthLabel.text =
                "\(definition.displayName): \(Int(entity.hitPoints.rounded(.up)))/\(Int(definition.maxHitPoints))"

            let visibleTargetID =
                entity.blockingWallID ??
                entity.currentTargetID

            updateTargetPath(
                visual.targetLine,
                from: entity,
                target: visibleTargetID.flatMap { entitiesByID[$0] }
            )
        }

        let score = simulation.score
        let filledStars = String(repeating: "★", count: score.stars)
        let emptyStars = String(repeating: "☆", count: 3 - score.stars)
        scoreLabel.text = String(
            format: "%@%@  %.0f%%",
            filledStars,
            emptyStars,
            score.destructionPercentage
        )

        switch simulation.status {
        case .ready:
            statusLabel.text = "Pronto · muri distruttibili · 60 s"
            resultLabel.isHidden = true

        case .running:
            statusLabel.text = String(
                format: "Tempo: %.1f s · Edifici: %d/%d",
                simulation.remainingTime,
                score.destroyedBuildings,
                score.totalBuildings
            )
            resultLabel.isHidden = true

        case .finished(let result):
            statusLabel.text = result.timeExpired
                ? "Tempo scaduto"
                : "Simulazione terminata"
            resultLabel.text = String(
                format: "%@ · %d stelle · %.0f%% · %.1f s · Superstiti: %d",
                result.winner.displayName,
                result.score.stars,
                result.score.destructionPercentage,
                result.elapsedTime,
                result.survivingTroops
            )
            resultLabel.isHidden = false
        }
    }

    private func updateTargetPath(
        _ line: SKShapeNode,
        from entity: BattleEntity,
        target: BattleEntity?
    ) {
        let definition = simulation.definition(for: entity.kind)

        guard
            entity.isAlive,
            let target,
            target.isAlive,
            definition.role == .troop ||
                definition.role == .defense
        else {
            line.path = nil
            return
        }

        let path = CGMutablePath()
        path.move(
            to: CGPoint(x: entity.position.x, y: entity.position.y)
        )

        let movementPath = simulation.movementPath(for: entity.id)

        if definition.role == .troop, !movementPath.isEmpty {
            for waypoint in movementPath {
                path.addLine(
                    to: CGPoint(x: waypoint.x, y: waypoint.y)
                )
            }
        } else {
            path.addLine(
                to: CGPoint(x: target.position.x, y: target.position.y)
            )
        }

        line.path = path
    }

    private func makeBody(for kind: BattleEntityKind) -> SKNode {
        switch kind {
        case .giant:
            return makeLabeledCircle(
                radius: 30,
                color: .systemOrange,
                text: "G"
            )

        case .cannon:
            return makeLabeledRectangle(
                size: CGSize(width: 66, height: 66),
                color: .darkGray,
                text: "C"
            )

        case .townHall:
            return makeLabeledRectangle(
                size: CGSize(width: 82, height: 82),
                color: .systemPurple,
                text: "TH"
            )

        case .goldStorage:
            return makeLabeledCircle(
                radius: 35,
                color: .systemYellow,
                text: "D"
            )

        case .wall:
            return makeLabeledRectangle(
                size: CGSize(width: 36, height: 36),
                color: SKColor(
                    red: 0.44,
                    green: 0.31,
                    blue: 0.20,
                    alpha: 1
                ),
                text: ""
            )
        }
    }

    private func makeLabeledCircle(
        radius: CGFloat,
        color: SKColor,
        text: String
    ) -> SKNode {
        let body = SKShapeNode(circleOfRadius: radius)
        body.fillColor = color
        body.strokeColor = .white
        body.lineWidth = 3
        addLabel(text, to: body)
        return body
    }

    private func makeLabeledRectangle(
        size: CGSize,
        color: SKColor,
        text: String
    ) -> SKNode {
        let body = SKShapeNode(rectOf: size, cornerRadius: 7)
        body.fillColor = color
        body.strokeColor = .white
        body.lineWidth = 2
        addLabel(text, to: body)
        return body
    }

    private func addLabel(_ text: String, to node: SKNode) {
        guard !text.isEmpty else {
            return
        }

        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = text.count > 1 ? 19 : 24
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        node.addChild(label)
    }
}
