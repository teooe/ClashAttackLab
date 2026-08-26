import SpriteKit

final class BattleScene: SKScene {
    private let simulation: SimulationEngine
    private var entityNodes: [UUID: SKNode] = [:]
    private var lastUpdateTime: TimeInterval?

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
        createEntityNodes()
    }

    override func update(_ currentTime: TimeInterval) {
        let deltaTime: TimeInterval

        if let lastUpdateTime {
            deltaTime = min(currentTime - lastUpdateTime, 0.05)
        } else {
            deltaTime = 0
        }

        self.lastUpdateTime = currentTime
        simulation.step(deltaTime: deltaTime)
        synchronizeEntityNodes()
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

    private func createEntityNodes() {
        for entity in simulation.entities {
            let node: SKNode

            switch entity.kind {
            case .giant:
                node = makeGiantNode()
            case .cannon:
                node = makeCannonNode()
            }

            entityNodes[entity.id] = node
            addChild(node)
        }

        synchronizeEntityNodes()
    }

    private func synchronizeEntityNodes() {
        for entity in simulation.entities {
            entityNodes[entity.id]?.position = CGPoint(
                x: entity.position.x,
                y: entity.position.y
            )
        }
    }

    private func makeGiantNode() -> SKNode {
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

    private func makeCannonNode() -> SKNode {
        let body = SKShapeNode(rectOf: CGSize(width: 66, height: 66), cornerRadius: 10)
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
