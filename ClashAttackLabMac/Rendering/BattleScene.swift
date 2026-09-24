import AppKit
import SpriteKit

final class BattleScene: SKScene {
    private struct EntityVisual {
        let root: SKNode
        let healthBackground: SKSpriteNode
        let healthFill: SKSpriteNode
        let healthLabel: SKLabelNode

        /// Only troops and defenses draw a line to their target.
        let targetLine: SKShapeNode?

        /// Walls hide their health bar until they are damaged.
        let hidesHealthWhenFull: Bool
    }

    private let simulation: SimulationEngine
    private let navigationGrid: NavigationGrid
    private var attackPlan: AttackPlan
    private var entityVisuals: [UUID: EntityVisual] = [:]
    private var projectileVisuals: [UUID: SKShapeNode] = [:]
    private var deploymentMarkers: [UUID: SKNode] = [:]
    private var spellMarkers: [UUID: SKNode] = [:]
    private var activeSpellVisuals: [UUID: SKNode] = [:]
    private var aliveEntityIDs: Set<UUID> = []
    private var lastUpdateTime: TimeInterval?
    private var manualPlacementHandler: ((WorldPosition) -> Void)?
    var simulationFinishedHandler: ((SimulationResult) -> Void)?
    private var didReportFinishedSimulation = false
    private var manualPlacementUsesWholeArena = false
    private let manualPlacementZone = SKShapeNode()

    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let spellStatusLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let resultLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let resultDetailLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")

    var simulationSpeed: Double = 1

    /// Scenes larger than the prototype are shrunk to fit the view, so
    /// interface text and strokes grow by the same factor to stay legible.
    private var uiScale: CGFloat {
        max(1, size.height / 760)
    }

    /// Troops are drawn smaller on the real map, where one tile is tiny.
    private var troopBodyScale: CGFloat {
        navigationGrid.isLarge ? 0.55 : 1
    }

    init(
        size: CGSize,
        simulation: SimulationEngine,
        navigationGrid: NavigationGrid,
        attackPlan: AttackPlan
    ) {
        self.simulation = simulation
        self.navigationGrid = navigationGrid
        self.attackPlan = attackPlan
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
        configureManualPlacementZone()
        drawDeploymentMarkers()
        drawSpellMarkers()
        configureLabels()
        createEntityNodes()
        updatePresentation()
    }

    override func mouseDown(with event: NSEvent) {
        guard let manualPlacementHandler else {
            return
        }

        let location = event.location(in: self)
        let position = WorldPosition(
            x: Double(location.x),
            y: Double(location.y)
        )

        guard
            let coordinate = navigationGrid.coordinate(for: position),
            manualPlacementUsesWholeArena ||
                navigationGrid.isDeploymentCell(coordinate)
        else {
            return
        }

        manualPlacementHandler(
            navigationGrid.worldPosition(for: coordinate)
        )
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

        if case .finished(let result) = simulation.status,
           !didReportFinishedSimulation {
            didReportFinishedSimulation = true
            simulationFinishedHandler?(result)
        }

        updatePresentation()
    }

    func setManualPlacementHandler(
        _ handler: ((WorldPosition) -> Void)?
    ) {
        manualPlacementHandler = handler
        manualPlacementZone.isHidden = handler == nil
        updateManualPlacementZone()
    }

    func setManualPlacementUsesWholeArena(_ value: Bool) {
        manualPlacementUsesWholeArena = value
        updateManualPlacementZone()
    }

    func startSimulation() {
        simulation.start()
    }

    func togglePause() {
        simulation.togglePause()
    }

    var recordedAttackPlan: AttackPlan { simulation.recordedAttackPlan }

    func heroAbilityState(for kind: BattleEntityKind) -> HeroAbilityState {
        simulation.heroAbilityState(for: kind)
    }

    @discardableResult
    func activateHeroAbility(for kind: BattleEntityKind) -> Bool {
        let didActivate = simulation.activateHeroAbility(for: kind)
        updatePresentation()
        return didActivate
    }

    func restartSimulation() {
        simulation.reset()
        lastUpdateTime = nil
        didReportFinishedSimulation = false
        updatePresentation()
    }

    func loadAttackPlan(_ attackPlan: AttackPlan) {
        self.attackPlan = attackPlan
        simulation.loadAttackPlan(attackPlan)
        refreshDeploymentMarkers()

        lastUpdateTime = nil
        didReportFinishedSimulation = false
        updatePresentation()
    }

    func loadScenario(
        entities: [BattleEntity],
        attackPlan: AttackPlan,
        gameData: (any GameDataProviding)? = nil
    ) {
        self.attackPlan = attackPlan
        simulation.loadScenario(
            entities: entities,
            attackPlan: attackPlan,
            gameData: gameData
        )
        refreshDeploymentMarkers()

        lastUpdateTime = nil
        didReportFinishedSimulation = false
        updatePresentation()
    }

    private func refreshDeploymentMarkers() {
        for marker in deploymentMarkers.values {
            marker.removeFromParent()
        }
        for marker in spellMarkers.values {
            marker.removeFromParent()
        }
        deploymentMarkers.removeAll()
        spellMarkers.removeAll()
        drawDeploymentMarkers()
        drawSpellMarkers()
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

    private func configureManualPlacementZone() {
        manualPlacementZone.fillColor =
            .systemCyan.withAlphaComponent(0.12)
        manualPlacementZone.strokeColor =
            .systemCyan.withAlphaComponent(0.78)
        manualPlacementZone.lineWidth = 2
        manualPlacementZone.zPosition = 4
        addChild(manualPlacementZone)
        updateManualPlacementZone()
    }

    private func updateManualPlacementZone() {
        if
            !manualPlacementUsesWholeArena,
            navigationGrid.isLarge,
            navigationGrid.isSquare
        {
            // Deployment border on every side: outer square minus inner.
            let cell = navigationGrid.cellSize
            let depth = Double(NavigationGrid.deploymentDepth) * cell
            let outer = CGRect(
                x: navigationGrid.origin.x,
                y: navigationGrid.origin.y,
                width: cell * Double(navigationGrid.columns),
                height: cell * Double(navigationGrid.rows)
            )
            let inner = outer.insetBy(dx: depth, dy: depth)
            let ring = CGMutablePath()
            ring.addRect(outer)
            // Opposite winding keeps the inner square unfilled.
            ring.move(to: CGPoint(x: inner.minX, y: inner.minY))
            ring.addLine(to: CGPoint(x: inner.minX, y: inner.maxY))
            ring.addLine(to: CGPoint(x: inner.maxX, y: inner.maxY))
            ring.addLine(to: CGPoint(x: inner.maxX, y: inner.minY))
            ring.closeSubpath()
            manualPlacementZone.path = ring
            manualPlacementZone.isHidden = manualPlacementHandler == nil
            return
        }

        let width =
            navigationGrid.cellSize *
            Double(
                manualPlacementUsesWholeArena
                    ? navigationGrid.columns
                    : 3
            )
        let zone = CGRect(
            x: navigationGrid.origin.x,
            y: navigationGrid.origin.y,
            width: width,
            height: navigationGrid.cellSize *
                Double(navigationGrid.rows)
        )
        manualPlacementZone.path = CGPath(rect: zone, transform: nil)
        manualPlacementZone.isHidden =
            manualPlacementHandler == nil
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
        statusLabel.fontSize = 17 * uiScale
        statusLabel.fontColor = .white
        statusLabel.horizontalAlignmentMode = .left
        statusLabel.position = CGPoint(x: 65, y: size.height - 30 * uiScale)
        statusLabel.zPosition = 40
        addChild(statusLabel)

        spellStatusLabel.fontSize = 13 * uiScale
        spellStatusLabel.fontColor = .white.withAlphaComponent(0.78)
        spellStatusLabel.horizontalAlignmentMode = .left
        spellStatusLabel.position = CGPoint(
            x: 65,
            y: size.height - 53 * uiScale
        )
        spellStatusLabel.zPosition = 40
        addChild(spellStatusLabel)

        scoreLabel.fontSize = 20 * uiScale
        scoreLabel.fontColor = .systemYellow
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(
            x: size.width - 65,
            y: size.height - 30 * uiScale
        )
        scoreLabel.zPosition = 40
        addChild(scoreLabel)

        resultLabel.fontSize = 18 * uiScale
        resultLabel.fontColor = .white
        resultLabel.position = CGPoint(x: size.width / 2, y: 65 * uiScale)
        resultLabel.zPosition = 40
        resultLabel.isHidden = true
        addChild(resultLabel)

        resultDetailLabel.fontSize = 13 * uiScale
        resultDetailLabel.fontColor = .white.withAlphaComponent(0.82)
        resultDetailLabel.position = CGPoint(
            x: size.width / 2,
            y: 39 * uiScale
        )
        resultDetailLabel.zPosition = 40
        resultDetailLabel.isHidden = true
        addChild(resultDetailLabel)
    }

    private func drawDeploymentMarkers() {
        for order in attackPlan.deployments {
            let root = SKNode()
            root.position = CGPoint(
                x: order.position.x,
                y: order.position.y
            )
            root.zPosition = 8

            let markerColor = deploymentMarkerColor(for: order.kind)
            let marker = SKShapeNode(circleOfRadius: 22)
            marker.fillColor = markerColor.withAlphaComponent(0.16)
            marker.strokeColor = markerColor
            marker.lineWidth = 2
            root.addChild(marker)

            let label = SKLabelNode(
                text: String(
                    format: "%@ %.1f s",
                    shortSymbol(for: order.kind),
                    order.deploymentTime
                )
            )
            label.fontName = "AvenirNext-Bold"
            label.fontSize = 12
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            root.addChild(label)

            deploymentMarkers[order.entityID] = root
            addChild(root)
        }
    }

    private func drawSpellMarkers() {
        for order in attackPlan.spellDeployments {
            let root = SKNode()
            root.position = CGPoint(
                x: order.position.x,
                y: order.position.y
            )
            root.zPosition = 9

            let color = spellColor(for: order.kind)
            let marker = SKShapeNode(circleOfRadius: 28)
            marker.fillColor = color.withAlphaComponent(0.12)
            marker.strokeColor = color.withAlphaComponent(0.8)
            marker.lineWidth = 3
            root.addChild(marker)

            let label = SKLabelNode(
                text: String(
                    format: "%@ %.1f s",
                    spellSymbol(for: order.kind),
                    order.deploymentTime
                )
            )
            label.fontName = "AvenirNext-Bold"
            label.fontSize = 12
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            root.addChild(label)

            spellMarkers[order.id] = root
            addChild(root)
        }
    }

    private func createEntityNodes() {
        for entity in simulation.entities {
            createEntityVisual(for: entity)
        }
    }

    private func reconcileEntityVisuals() {
        let currentIDs = Set(simulation.entities.map(\.id))
        let removedIDs = entityVisuals.keys.filter {
            !currentIDs.contains($0)
        }

        for id in removedIDs {
            entityVisuals[id]?.root.removeFromParent()
            entityVisuals[id]?.targetLine?.removeFromParent()
            entityVisuals.removeValue(forKey: id)
        }

        for entity in simulation.entities
        where entityVisuals[entity.id] == nil {
            createEntityVisual(for: entity)
        }
    }

    private func reconcileActiveSpellVisuals() {
        let currentIDs = Set(simulation.activeSpells.map(\.id))
        let removedIDs = activeSpellVisuals.keys.filter {
            !currentIDs.contains($0)
        }

        for id in removedIDs {
            activeSpellVisuals[id]?.removeFromParent()
            activeSpellVisuals.removeValue(forKey: id)
        }

        for spell in simulation.activeSpells {
            let node: SKNode

            if let existing = activeSpellVisuals[spell.id] {
                node = existing
            } else {
                node = makeActiveSpellNode(for: spell)
                activeSpellVisuals[spell.id] = node
                addChild(node)
            }

            node.position = CGPoint(
                x: spell.position.x,
                y: spell.position.y
            )
        }
    }

    private func makeActiveSpellNode(
        for spell: ActiveBattleSpell
    ) -> SKNode {
        let definition = simulation.spellDefinition(for: spell.kind)
        let color = spellColor(for: spell.kind)
        let root = SKNode()
        root.zPosition = 6

        let zone = SKShapeNode(
            circleOfRadius: definition.radius
        )
        zone.fillColor = color.withAlphaComponent(0.09)
        zone.strokeColor = color.withAlphaComponent(0.72)
        zone.lineWidth = 4
        zone.glowWidth = 5
        root.addChild(zone)

        let label = SKLabelNode(
            text: spellSymbol(for: spell.kind)
        )
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 22
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.zPosition = 1
        root.addChild(label)

        let pulse = SKAction.sequence([
            .fadeAlpha(to: 0.55, duration: 0.55),
            .fadeAlpha(to: 1, duration: 0.55)
        ])
        root.run(.repeatForever(pulse))
        return root
    }

    private func reconcileProjectileVisuals() {
        let currentIDs = Set(simulation.projectiles.map(\.id))
        let removedIDs = projectileVisuals.keys.filter {
            !currentIDs.contains($0)
        }

        for id in removedIDs {
            projectileVisuals[id]?.removeFromParent()
            projectileVisuals.removeValue(forKey: id)
        }

        for projectile in simulation.projectiles {
            let node: SKShapeNode

            if let existing = projectileVisuals[projectile.id] {
                node = existing
            } else {
                node = makeProjectileNode(for: projectile.kind)
                projectileVisuals[projectile.id] = node
                addChild(node)
            }

            node.position = CGPoint(
                x: projectile.position.x,
                y: projectile.position.y
            )
        }
    }

    private func makeProjectileNode(
        for kind: ProjectileKind
    ) -> SKShapeNode {
        let node: SKShapeNode

        switch kind {
        case .arrow:
            node = SKShapeNode(rectOf: CGSize(width: 12, height: 4))
            node.fillColor = .systemYellow
        case .cannonball:
            node = SKShapeNode(circleOfRadius: 7)
            node.fillColor = .darkGray
        case .mortarShell:
            node = SKShapeNode(circleOfRadius: 10)
            node.fillColor = .systemOrange
            node.glowWidth = 4
        case .fireball:
            node = SKShapeNode(circleOfRadius: 8)
            node.fillColor = .systemBlue
            node.glowWidth = 7
        case .bomb:
            node = SKShapeNode(circleOfRadius: 10)
            node.fillColor = .darkGray
            node.glowWidth = 3
        case .dragonFire:
            node = SKShapeNode(circleOfRadius: 10)
            node.fillColor = .systemGreen
            node.glowWidth = 9
        case .airBolt:
            node = SKShapeNode(rectOf: CGSize(width: 14, height: 5))
            node.fillColor = .systemIndigo
            node.glowWidth = 5
        }

        node.strokeColor = .white
        node.lineWidth = 1.5
        node.zPosition = 30
        return node
    }

    private func createEntityVisual(for entity: BattleEntity) {
        let definition = simulation.definition(for: entity.kind)
        let root = SKNode()
        let body = makeBody(for: entity.kind)
        let footprint = CGFloat(definition.footprintSize)
        let isWall = definition.role == .wall
        if footprint > 0 {
            // Fit the drawn body inside the real footprint.
            body.setScale(footprint * 0.9 / (isWall ? 36 : 80))
        } else if definition.role == .troop {
            body.setScale(troopBodyScale)
        }
        root.addChild(body)
        addRangeRings(for: definition, to: root)

        let healthWidth: Double
        let healthY: Double
        if footprint > 0 {
            healthWidth = Double(footprint) * 0.8
            healthY = -Double(footprint) / 2 + 6
        } else {
            let scale = definition.role == .troop ? Double(troopBodyScale) : 1
            healthWidth = (isWall ? 34.0 : 88.0) * scale
            healthY = (isWall ? -25.0 : -52.0) * scale
        }

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
        healthLabel.isHidden = isWall || navigationGrid.isLarge
        root.addChild(healthLabel)

        var targetLine: SKShapeNode?
        if definition.role == .troop || definition.role == .defense {
            let line = SKShapeNode()
            if definition.role == .troop {
                line.strokeColor =
                    definition.movementDomain == .air
                        ? .systemCyan
                        : .systemYellow
            } else {
                line.strokeColor = .systemRed
            }
            line.lineWidth = 2 * uiScale
            line.alpha = 0.48
            line.zPosition = 5
            addChild(line)
            targetLine = line
        }

        root.zPosition = isWall ? 7 : 15

        let hidesHealthWhenFull = isWall && navigationGrid.isLarge
        healthBackground.isHidden = hidesHealthWhenFull
        healthFill.isHidden = hidesHealthWhenFull

        entityVisuals[entity.id] = EntityVisual(
            root: root,
            healthBackground: healthBackground,
            healthFill: healthFill,
            healthLabel: healthLabel,
            targetLine: targetLine,
            hidesHealthWhenFull: hidesHealthWhenFull
        )
        addChild(root)
    }

    private func addRangeRings(
        for definition: CombatDefinition,
        to root: SKNode
    ) {
        // Dozens of large rings on the real map cost frame rate and hide the
        // battle; they are only drawn on the prototype arena.
        guard
            !navigationGrid.isLarge,
            definition.role == .defense,
            definition.attackRange > 0
        else {
            return
        }

        let maximumRing = SKShapeNode(
            circleOfRadius: definition.attackRange
        )
        maximumRing.strokeColor = .systemRed.withAlphaComponent(0.16)
        maximumRing.lineWidth = 2
        maximumRing.fillColor = .clear
        maximumRing.zPosition = -2
        root.addChild(maximumRing)

        guard definition.minimumAttackRange > 0 else {
            return
        }

        let minimumRing = SKShapeNode(
            circleOfRadius: definition.minimumAttackRange
        )
        minimumRing.strokeColor = .systemOrange.withAlphaComponent(0.28)
        minimumRing.lineWidth = 2
        minimumRing.fillColor = .clear
        minimumRing.zPosition = -1
        root.addChild(minimumRing)
    }

    private func updateDeploymentMarkers() {
        let deployedIDs = Set(simulation.entities.map(\.id))

        for (entityID, marker) in deploymentMarkers {
            marker.isHidden = deployedIDs.contains(entityID)
        }
    }

    private func updateSpellMarkers() {
        let pendingIDs = simulation.pendingSpellIDs

        for (spellID, marker) in spellMarkers {
            marker.isHidden = !pendingIDs.contains(spellID)
        }
    }

    private func separatedDisplayPositions(
        for entities: [BattleEntity]
    ) -> [UUID: WorldPosition] {
        var result = Dictionary(
            uniqueKeysWithValues: entities.map { ($0.id, $0.position) }
        )
        let livingTroops = entities
            .filter {
                $0.isAlive &&
                    simulation.definition(for: $0.kind).role == .troop
            }
            .sorted { $0.id.uuidString < $1.id.uuidString }

        var clusters: [[BattleEntity]] = []
        let overlapDistance = 18.0

        for troop in livingTroops {
            if let clusterIndex = clusters.firstIndex(where: { cluster in
                cluster.contains { member in
                    squaredDistance(
                        from: troop.position,
                        to: member.position
                    ) <= overlapDistance * overlapDistance
                }
            }) {
                clusters[clusterIndex].append(troop)
            } else {
                clusters.append([troop])
            }
        }

        for cluster in clusters where cluster.count > 1 {
            let radius = min(
                44.0,
                18.0 + Double(cluster.count) * 4.0
            )

            for (index, troop) in cluster.enumerated() {
                let angle =
                    (Double(index) / Double(cluster.count)) *
                    Double.pi *
                    2 -
                    Double.pi / 2
                result[troop.id] = WorldPosition(
                    x: troop.position.x + cos(angle) * radius,
                    y: troop.position.y + sin(angle) * radius
                )
            }
        }

        return result
    }

    private func squaredDistance(
        from first: WorldPosition,
        to second: WorldPosition
    ) -> Double {
        let deltaX = second.x - first.x
        let deltaY = second.y - first.y
        return deltaX * deltaX + deltaY * deltaY
    }

    private func showDestructionExplosions(
        for entities: [BattleEntity]
    ) {
        let livingIDs = Set(
            entities.filter(\.isAlive).map(\.id)
        )
        let newlyDefeatedIDs = aliveEntityIDs.subtracting(livingIDs)

        for entity in entities
        where
            newlyDefeatedIDs.contains(entity.id) &&
            (entity.kind == .wallBreaker || entity.kind.isTrap)
        {
            let definition = simulation.definition(for: entity.kind)
            let radius = entity.kind.isTrap
                ? definition.destructionRadius
                : 30
            let explosion = SKShapeNode(circleOfRadius: radius)
            explosion.position = CGPoint(
                x: entity.position.x,
                y: entity.position.y
            )
            switch entity.kind {
            case .giantBomb:
                explosion.fillColor = .systemRed.withAlphaComponent(0.42)
                explosion.strokeColor = .systemOrange
            case .airBomb:
                explosion.fillColor = .systemCyan.withAlphaComponent(0.38)
                explosion.strokeColor = .systemBlue
            default:
                explosion.fillColor = .systemYellow.withAlphaComponent(0.5)
                explosion.strokeColor = .systemOrange
            }
            explosion.lineWidth = 5
            explosion.glowWidth = 10
            explosion.zPosition = 35
            explosion.setScale(0.25)
            addChild(explosion)

            explosion.run(
                .sequence([
                    .group([
                        .scale(to: 2.2, duration: 0.28),
                        .fadeOut(withDuration: 0.28)
                    ]),
                    .removeFromParent()
                ])
            )
        }

        aliveEntityIDs = livingIDs
    }

    private func updatePresentation() {
        reconcileEntityVisuals()
        reconcileProjectileVisuals()
        reconcileActiveSpellVisuals()
        updateDeploymentMarkers()
        updateSpellMarkers()
        showDestructionExplosions(for: simulation.entities)

        let displayPositions = separatedDisplayPositions(
            for: simulation.entities
        )
        let entitiesByID = Dictionary(
            uniqueKeysWithValues: simulation.entities.map { ($0.id, $0) }
        )

        for entity in simulation.entities {
            guard let visual = entityVisuals[entity.id] else {
                continue
            }

            let definition = simulation.definition(for: entity.kind)
            let healthFraction = simulation.healthFraction(for: entity)

            let displayPosition =
                displayPositions[entity.id] ?? entity.position
            visual.root.position = CGPoint(
                x: displayPosition.x,
                y: displayPosition.y
            )
            let isFrozen = simulation.isDefenseDisabled(entity.id)
            let isHiddenDefense = definition.startsHidden &&
                !entity.isRevealed
            visual.root.alpha = isHiddenDefense
                ? 0
                : (entity.isAlive ? (isFrozen ? 0.62 : 1) : 0.08)
            visual.root.setScale(
                entity.heroAbilityIsActive ? 1.12 : 1
            )
            if visual.hidesHealthWhenFull {
                let showsHealth = entity.isAlive && healthFraction < 1
                visual.healthBackground.isHidden = !showsHealth
                visual.healthFill.isHidden = !showsHealth
            }
            if visual.healthFill.xScale != healthFraction {
                visual.healthFill.xScale = healthFraction
                visual.healthFill.color =
                    healthFraction > 0.35 ? .systemGreen : .systemRed
            }
            if !visual.healthLabel.isHidden {
                let abilityLabel = entity.heroAbilityIsActive
                    ? " · \(definition.heroAbility?.displayName ?? "")"
                    : ""
                let frozenLabel = isFrozen ? " · CONGELATA" : ""
                let text =
                    "\(definition.displayName): \(Int(entity.hitPoints.rounded(.up)))/\(Int(definition.maxHitPoints))\(abilityLabel)\(frozenLabel)"
                // Re-rendering label text is costly; only touch it on change.
                if visual.healthLabel.text != text {
                    visual.healthLabel.text = text
                }
            }

            guard let targetLine = visual.targetLine else {
                continue
            }

            let visibleTargetID =
                entity.blockingWallID ??
                entity.currentTargetID

            let target = visibleTargetID.flatMap { entitiesByID[$0] }
            updateTargetPath(
                targetLine,
                from: entity,
                displayPosition: displayPosition,
                target: target,
                targetDisplayPosition: target.flatMap {
                    displayPositions[$0.id]
                }
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
            statusLabel.text =
                "Pronto · \(attackPlan.name) · \(armySummary()) · premi Avvia"
            spellStatusLabel.text = spellScheduleSummary()
            resultLabel.isHidden = true
            resultDetailLabel.isHidden = true

        case .running:
            statusLabel.text = String(
                format: "Tempo: %.1f s · Vive: %d · Schierate: %d/%d · In attesa: %d",
                simulation.remainingTime,
                simulation.livingTroopCount,
                simulation.deployedTroopCount,
                attackPlan.totalDeploymentCount,
                simulation.pendingDeploymentCount
            )
            spellStatusLabel.text = String(
                format: "Incantesimi lanciati: %d/%d · Zone attive: %d",
                simulation.deployedSpellCount,
                attackPlan.totalSpellCount,
                simulation.activeSpells.count
            )
            resultLabel.isHidden = true
            resultDetailLabel.isHidden = true

        case .paused:
            statusLabel.text = String(
                format: "In pausa · %.1f s rimasti · Vive: %d",
                simulation.remainingTime,
                simulation.livingTroopCount
            )
            spellStatusLabel.text = "Incantesimi e timer in pausa"
            resultLabel.isHidden = true
            resultDetailLabel.isHidden = true

        case .finished(let result):
            statusLabel.text = result.finishReason.displayName
            spellStatusLabel.text = String(
                format: "Incantesimi usati: %d/%d",
                result.metrics.spellsCast,
                attackPlan.totalSpellCount
            )
            resultLabel.text = String(
                format: "%@ · %d stelle · %.0f%% · %.1f s · Superstiti: %d",
                result.winner.displayName,
                result.score.stars,
                result.score.destructionPercentage,
                result.elapsedTime,
                result.survivingTroops
            )
            resultDetailLabel.text = String(
                format: "%@ · Danno base: %.0f · PV esercito persi: %.0f · Truppe perse: %d · Muri: %d",
                result.finishReason.displayName,
                result.metrics.damageToBase,
                result.metrics.hitPointsLostByArmy,
                result.metrics.troopsLost,
                result.metrics.destroyedWalls
            )
            resultLabel.isHidden = false
            resultDetailLabel.isHidden = false
        }
    }

    private func updateTargetPath(
        _ line: SKShapeNode,
        from entity: BattleEntity,
        displayPosition: WorldPosition,
        target: BattleEntity?,
        targetDisplayPosition: WorldPosition?
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
            to: CGPoint(
                x: displayPosition.x,
                y: displayPosition.y
            )
        )

        let movementPath = simulation.movementPath(for: entity.id)

        if definition.role == .troop, !movementPath.isEmpty {
            for waypoint in movementPath {
                path.addLine(
                    to: CGPoint(x: waypoint.x, y: waypoint.y)
                )
            }
        } else {
            let targetPosition =
                targetDisplayPosition ?? target.position
            path.addLine(
                to: CGPoint(
                    x: targetPosition.x,
                    y: targetPosition.y
                )
            )
        }

        line.path = path
    }

    private func armySummary() -> String {
        attackPlan.troopKindsInDeploymentOrder
            .map { kind in
                let name = simulation.definition(for: kind).displayName
                let count = attackPlan.deploymentCount(for: kind)
                return "\(name) ×\(count)"
            }
            .joined(separator: " · ")
    }

    private func spellScheduleSummary() -> String {
        let entries = attackPlan.orderedSpellDeployments.map { order in
            let name = simulation
                .spellDefinition(for: order.kind)
                .displayName
            return String(
                format: "%@ @ %.1f s",
                name,
                order.deploymentTime
            )
        }

        return entries.isEmpty
            ? "Nessun incantesimo programmato"
            : "Incantesimi: " + entries.joined(separator: " · ")
    }

    private func spellColor(for kind: BattleSpellKind) -> SKColor {
        switch kind {
        case .heal:
            return .systemGreen
        case .rage:
            return .systemPurple
        case .freeze:
            return .systemCyan
        case .lightning:
            return .systemYellow
        case .earthquake:
            return .systemOrange
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
        case .earthquake:
            return "E"
        }
    }

    private func deploymentMarkerColor(
        for kind: BattleEntityKind
    ) -> SKColor {
        switch kind {
        case .giant:
            return .systemOrange
        case .barbarian:
            return .systemRed
        case .archer:
            return .systemPink
        case .wallBreaker:
            return .systemGreen
        case .wizard:
            return .systemBlue
        case .balloon:
            return .systemIndigo
        case .dragon:
            return .systemMint
        case .barbarianKing:
            return .systemYellow
        case .archerQueen:
            return .systemPurple
        case .wallWrecker:
            return .systemBrown
        case .stoneSlammer:
            return .systemCyan
        case .cannon, .archerTower, .mortar, .wizardTower, .infernoTower, .bombTower, .hiddenTesla, .giantBomb, .airBomb, .airSweeper, .airDefense,
             .townHall, .goldStorage, .wall,
             .goldMine, .elixirCollector, .darkElixirDrill, .elixirStorage, .darkElixirStorage, .clanCastle, .armyCamp, .barracks, .darkBarracks, .laboratory, .spellFactory, .darkSpellFactory, .workshop, .heroHall, .petHouse, .blacksmith, .builderHut, .helperHut:
            return .systemCyan
        }
    }

    private func shortSymbol(for kind: BattleEntityKind) -> String {
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
        case .cannon:
            return "C"
        case .archerTower:
            return "TA"
        case .mortar:
            return "MO"
        case .wizardTower:
            return "TZ"
        case .infernoTower:
            return "TI"
        case .bombTower:
            return "TB"
        case .hiddenTesla:
            return "TO"
        case .giantBomb:
            return "BG"
        case .airBomb:
            return "BA"
        case .airSweeper:
            return "SP"
        case .airDefense:
            return "AD"
        case .townHall:
            return "TH"
        case .goldStorage:
            return "D"
        case .wall:
            return "M"
        case .goldMine, .elixirCollector, .darkElixirDrill, .elixirStorage, .darkElixirStorage, .clanCastle, .armyCamp, .barracks, .darkBarracks, .laboratory, .spellFactory, .darkSpellFactory, .workshop, .heroHall, .petHouse, .blacksmith, .builderHut, .helperHut:
            return UtilityBuildingStyle.style(for: kind).symbol
        }
    }

    private func makeBody(for kind: BattleEntityKind) -> SKNode {
        switch kind {
        case .giant:
            return makeLabeledCircle(
                radius: 30,
                color: .systemOrange,
                text: "G"
            )

        case .barbarian:
            return makeLabeledCircle(
                radius: 22,
                color: .systemRed,
                text: "B"
            )

        case .archer:
            return makeLabeledCircle(
                radius: 20,
                color: .systemPink,
                text: "A"
            )

        case .wallBreaker:
            return makeLabeledCircle(
                radius: 18,
                color: .systemGreen,
                text: "WB"
            )

        case .wizard:
            return makeLabeledCircle(
                radius: 22,
                color: .systemBlue,
                text: "W"
            )

        case .balloon:
            return makeLabeledCircle(
                radius: 27,
                color: .systemIndigo,
                text: "BL"
            )

        case .dragon:
            return makeLabeledCircle(
                radius: 32,
                color: .systemMint,
                text: "DR"
            )

        case .barbarianKing:
            return makeLabeledCircle(
                radius: 34,
                color: .systemYellow,
                text: "BK"
            )

        case .archerQueen:
            return makeLabeledCircle(
                radius: 32,
                color: .systemPurple,
                text: "AQ"
            )

        case .wallWrecker:
            return makeLabeledRectangle(
                size: CGSize(width: 72, height: 52),
                color: .systemBrown,
                text: "AR"
            )

        case .stoneSlammer:
            return makeLabeledCircle(
                radius: 35,
                color: .systemCyan,
                text: "SP"
            )

        case .cannon:
            return makeLabeledRectangle(
                size: CGSize(width: 66, height: 66),
                color: .darkGray,
                text: "C"
            )

        case .archerTower:
            return makeLabeledRectangle(
                size: CGSize(width: 62, height: 78),
                color: .systemTeal,
                text: "TA"
            )

        case .mortar:
            return makeLabeledCircle(
                radius: 36,
                color: SKColor(
                    red: 0.35,
                    green: 0.25,
                    blue: 0.18,
                    alpha: 1
                ),
                text: "MO"
            )

        case .wizardTower:
            return makeLabeledCircle(
                radius: 35,
                color: .systemPink,
                text: "TZ"
            )

        case .infernoTower:
            return makeLabeledRectangle(
                size: CGSize(width: 68, height: 78),
                color: .systemRed,
                text: "TI"
            )

        case .bombTower:
            return makeLabeledCircle(
                radius: 36,
                color: .systemOrange,
                text: "TB"
            )

        case .hiddenTesla:
            return makeLabeledRectangle(
                size: CGSize(width: 58, height: 72),
                color: .systemCyan,
                text: "TO"
            )

        case .giantBomb:
            return makeLabeledCircle(
                radius: 24,
                color: .systemRed,
                text: "BG"
            )

        case .airBomb:
            return makeLabeledCircle(
                radius: 22,
                color: .systemCyan,
                text: "BA"
            )

        case .airSweeper:
            return makeLabeledRectangle(
                size: CGSize(width: 62, height: 62),
                color: .systemMint,
                text: "SP"
            )

        case .airDefense:
            return makeLabeledRectangle(
                size: CGSize(width: 70, height: 70),
                color: .systemIndigo,
                text: "AD"
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

        case .goldMine, .elixirCollector, .darkElixirDrill, .elixirStorage, .darkElixirStorage, .clanCastle, .armyCamp, .barracks, .darkBarracks, .laboratory, .spellFactory, .darkSpellFactory, .workshop, .heroHall, .petHouse, .blacksmith, .builderHut, .helperHut:
            let style = UtilityBuildingStyle.style(for: kind)
            return makeLabeledRectangle(
                size: CGSize(width: 70, height: 70),
                color: SKColor(
                    red: style.red,
                    green: style.green,
                    blue: style.blue,
                    alpha: 1
                ),
                text: style.symbol
            )

        case .wall:
            // Plain sprites batch far better than hundreds of shape nodes.
            let wall = SKSpriteNode(
                color: SKColor(
                    red: 0.44,
                    green: 0.31,
                    blue: 0.20,
                    alpha: 1
                ),
                size: CGSize(width: 36, height: 36)
            )
            return wall
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
