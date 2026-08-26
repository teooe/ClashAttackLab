import SpriteKit

final class BattleScene: SKScene {
    private struct EntityVisual {
        let root: SKNode
        let healthFill: SKSpriteNode
        let healthLabel: SKLabelNode
    }

    private let simulation: SimulationEngine
    private var entityVisuals: [UUID: EntityVisual] = [:]
    private var lastUpdateTime: TimeInterval?

    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let resultLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    init(size: CGSize, simulation: SimulationEngine) {
        self.simulation = simulation
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

        let centerLine = SKShapeNode(
            rectOf: CGSize(width: 2, height: size.height - 120)
        )
        centerLine.fillColor = .white.withAlphaComponent(0.12)
        centerLine.strokeColor = .clear
        centerLine.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(centerLine)
    }

    private func configureLabels() {
        statusLabel.fontSize = 18
        statusLabel.fontColor = .white
        statusLabel.position = CGPoint(x: size.width / 2, y: size.height - 30)
        statusLabel.zPosition = 20
        addChild(statusLabel)

        resultLabel.fontSize = 20
        resultLabel.fontColor = .white
        resultLabel.position = CGPoint(x: size.width / 2, y: 58)
        resultLabel.zPosition = 20
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
            healthLabel.fontSize = 12
            healthLabel.fontColor = .white
            healthLabel.verticalAlignmentMode = .center
            healthLabel.position = CGPoint(x: 0, y: -69)
            healthLabel.zPosition = 12
            root.addChild(healthLabel)

            entityVisuals[entity.id] = EntityVisual(
                root: root,
                healthFill: healthFill,
                healthLabel: healthLabel
            )
            addChild(root)
        }
    }

    private func updatePresentation() {
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
            visual.root.alpha = entity.isAlive ? 1 : 0.25
            visual.healthFill.xScale = healthFraction
            visual.healthFill.color = healthFraction > 0.35 ? .systemGreen : .systemRed
            visual.healthLabel.text =
                "\(definition.displayName): \(Int(entity.hitPoints.rounded(.up)))/\(Int(definition.maxHitPoints))"
        }

        switch simulation.status {
        case .ready:
            statusLabel.text = "Pronto"
            resultLabel.isHidden = true

        case .running:
            statusLabel.text = String(
                format: "Simulazione · %.1f s",
                simulation.elapsedTime
            )
            resultLabel.isHidden = true

        case .finished(let result):
            statusLabel.text = "Simulazione terminata"
            resultLabel.text = String(
                format: "Vincitore: %@ · Tempo: %.1f s · Attacchi G/C: %d/%d",
                result.winner.displayName,
                result.elapsedTime,
                result.giantAttackCount,
                result.cannonAttackCount
            )
            resultLabel.isHidden = false
        }
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
