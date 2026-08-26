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
    private let resultLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

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
        drawWalls()
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
        simulation.advance(by: deltaTime)
        updatePresentation()
    }

    func restartSimulation() {
        simulation.reset()
        lastUpdateTime = nil
        updatePresentation()
    }

    private func drawArena() {
        let arena = SKShapeNode(
            rect: CGRect(x: 40, y: 40, width: size.width - 80, height: size.height - 80),
            cornerRadius: 16
        )
        arena.fillColor = SKColor(red: 0.22, green: 0.46, blue: 0.24, alpha: 1)
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
            line.strokeColor = .white.withAlphaComponent(0.045)
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
            line.strokeColor = .white.withAlphaComponent(0.045)
            line.lineWidth = 1
            line.zPosition = 1
            addChild(line)
        }
    }

    private func drawWalls() {
        for coordinate in navigationGrid.blockedCells {
            let position = navigationGrid.worldPosition(for: coordinate)
            let wall = SKShapeNode(
                rectOf: CGSize(
                    width: navigationGrid.cellSize - 4,
                    height: navigationGrid.cellSize - 4
                ),
                cornerRadius: 6
            )
            wall.position = CGPoint(x: position.x, y: position.y)
            wall.fillColor = SKColor(
                red: 0.44,
                green: 0.31,
                blue: 0.20,
                alpha: 1
            )
            wall.strokeColor = SKColor(
                red: 0.72,
                green: 0.60,
                blue: 0.42,
                alpha: 1
            )
            wall.lineWidth = 2
            wall.zPosition = 4
            addChild(wall)
        }
    }

    private func configureLabels() {
        statusLabel.fontSize = 18
        statusLabel.fontColor = .white
        statusLabel.position = CGPoint(x: size.width / 2, y: size.height - 30)
        statusLabel.zPosition = 30
        addChild(statusLabel)

        resultLabel.fontSize = 19
        resultLabel.fontColor = .white
        resultLabel.position = CGPoint(x: size.width / 2, y: 56)
        resultLabel.zPosition = 30
        resultLabel.isHidden = true
        addChild(resultLabel)
    }

    private func createEntityNodes() {
        for entity in simulation.entities {
            let root = SKNode()
            let body: SKNode

            switch entity.kind {
            case .giant:
                body = makeGiantBody()
            case .cannon:
                body = makeCannonBody()
            }

            root.addChild(body)

            let healthBackground = SKSpriteNode(
                color: .black.withAlphaComponent(0.55),
                size: CGSize(width: 92, height: 10)
            )
            healthBackground.position = CGPoint(x: 0, y: -52)
            healthBackground.zPosition = 10
            root.addChild(healthBackground)

            let healthFill = SKSpriteNode(
                color: .systemGreen,
                size: CGSize(width: 88, height: 6)
            )
            healthFill.anchorPoint = CGPoint(x: 0, y: 0.5)
            healthFill.position = CGPoint(x: -44, y: -52)
            healthFill.zPosition = 11
            root.addChild(healthFill)

            let healthLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
            healthLabel.fontSize = 11
            healthLabel.fontColor = .white
            healthLabel.verticalAlignmentMode = .center
            healthLabel.position = CGPoint(x: 0, y: -69)
            healthLabel.zPosition = 12
            root.addChild(healthLabel)

            let targetLine = SKShapeNode()
            targetLine.strokeColor =
                simulation.definition(for: entity.kind).role == .troop
                    ? .systemYellow
                    : .systemRed
            targetLine.lineWidth = 2
            targetLine.alpha = 0.48
            targetLine.zPosition = 5
            addChild(targetLine)

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
            visual.root.alpha = entity.isAlive ? 1 : 0.2
            visual.healthFill.xScale = healthFraction
            visual.healthFill.color =
                healthFraction > 0.35 ? .systemGreen : .systemRed
            visual.healthLabel.text =
                "\(definition.displayName): \(Int(entity.hitPoints.rounded(.up)))/\(Int(definition.maxHitPoints))"

            updateTargetPath(
                visual.targetLine,
                from: entity,
                target: entity.currentTargetID.flatMap { entitiesByID[$0] }
            )
        }

        switch simulation.status {
        case .ready:
            statusLabel.text = "Pronto · A* a 8 direzioni · muri statici"
            resultLabel.isHidden = true

        case .running:
            statusLabel.text = String(
                format: "Pathfinding A* · %.1f s",
                simulation.elapsedTime
            )
            resultLabel.isHidden = true

        case .finished(let result):
            statusLabel.text = "Simulazione terminata"
            resultLabel.text = String(
                format: "Vincitore: %@ · %.1f s · Superstiti T/D: %d/%d · Attacchi T/D: %d/%d",
                result.winner.displayName,
                result.elapsedTime,
                result.survivingTroops,
                result.survivingDefenses,
                result.troopAttackCount,
                result.defenseAttackCount
            )
            resultLabel.isHidden = false
        }
    }

    private func updateTargetPath(
        _ line: SKShapeNode,
        from entity: BattleEntity,
        target: BattleEntity?
    ) {
        guard entity.isAlive, let target, target.isAlive else {
            line.path = nil
            return
        }

        let definition = simulation.definition(for: entity.kind)
        let path = CGMutablePath()
        path.move(
            to: CGPoint(x: entity.position.x, y: entity.position.y)
        )

        if definition.role == .troop {
            for waypoint in simulation.movementPath(for: entity.id) {
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

    private func makeGiantBody() -> SKNode {
        let body = SKShapeNode(circleOfRadius: 30)
        body.fillColor = .systemOrange
        body.strokeColor = .white
        body.lineWidth = 3

        let label = SKLabelNode(text: "G")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 24
        label.verticalAlignmentMode = .center
        body.addChild(label)

        return body
    }

    private func makeCannonBody() -> SKNode {
        let body = SKShapeNode(
            rectOf: CGSize(width: 66, height: 66),
            cornerRadius: 10
        )
        body.fillColor = .darkGray
        body.strokeColor = .white
        body.lineWidth = 3

        let label = SKLabelNode(text: "C")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 24
        label.verticalAlignmentMode = .center
        body.addChild(label)

        return body
    }
}
