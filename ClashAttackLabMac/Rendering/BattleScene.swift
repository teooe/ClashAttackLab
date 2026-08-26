import SpriteKit

final class BattleScene: SKScene {
    private let entities: [BattleEntity]

    init(size: CGSize, entities: [BattleEntity]) {
        self.entities = entities
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
        drawEntities()
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

    private func drawEntities() {
        for entity in entities {
            let node: SKNode

            switch entity.kind {
            case .giant:
                node = makeGiantNode()
            case .cannon:
                node = makeCannonNode()
            }

            node.position = CGPoint(x: entity.position.x, y: entity.position.y)
            addChild(node)
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
