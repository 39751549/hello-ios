import SceneKit
import UIKit

/// 游戏世界 3D 场景: 地面/角色/怪物/灯光/战斗动画
final class GameScene: SCNScene {

    // 节点引用
    let cameraNode = SCNNode()
    let lightNode = SCNNode()
    let playerNode = SCNNode()
    private let playerHpBar = SCNNode()
    private let playerHpFill = SCNNode()
    private var playerHpWidth: CGFloat = 1.2

    // 怪物节点 + 数据
    struct MonsterEntity {
        let node: SCNNode
        let name: String
        let level: Int
        let color: UIColor
        let isBoss: Bool
        let bossId: Int?
        var alive: Bool
        let hpBarNode: SCNNode
        let hpFillNode: SCNNode
        let hpBarWidth: CGFloat
        var hpPct: CGFloat = 1.0
    }
    private(set) var monsters: [MonsterEntity] = []

    // 移动控制
    private var moveVector = SIMD2<Float>(0, 0)
    /// 移动速度(由 RemoteConfig 提供,云更新可调)
    private var moveSpeed: Float {
        let v = RemoteConfig.shared.moveSpeed
        return v > 0 ? v : 4.0
    }

    var onPlayerMove: ((SCNVector3) -> Void)?
    var onMonsterTapped: ((MonsterEntity) -> Void)?

    // 地图边界
    private let mapHalf: Float = 18

    // 玩家跟随点光源
    private let playerLightNode = SCNNode()

    // 摄像机轨道(可旋转视角)
    private var cameraYaw: Float = 0
    private let cameraDistance: Float = 13
    private let cameraHeight: Float = 7.8

    // 角色骨骼关节(用于行走/idle/攻击动画)
    private var torsoNode: SCNNode?
    private var headNode: SCNNode?
    private var leftArmJoint: SCNNode?
    private var rightArmJoint: SCNNode?
    private var leftLegJoint: SCNNode?
    private var rightLegJoint: SCNNode?
    private var capeNode: SCNNode?
    private var isWalking = false
    private var isBusy = false  // 战斗中不播行走

    override init() {
        super.init()
        background.contents = gradientImage()
        // PBR 环境光照(让 physicallyBased 材质有反射,否则全黑)
        lightingEnvironment.contents = makeEnvMap()
        lightingEnvironment.intensity = 1.2
        setupLighting()
        setupGround()
        setupSkyAndClouds()
        setupPlayer()
        spawnMonsters()
        setupFireflies()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 设置
    private func gradientImage() -> UIImage {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = [UIColor(hex: 0x1a2b4a).cgColor, UIColor(hex: 0x0a0f1c).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
    }

    /// PBR 环境贴图(简易球面渐变,提供反射光)
    private func makeEnvMap() -> UIImage {
        let size = CGSize(width: 256, height: 128)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            // 上半:天空暖光 / 下半:地面反射
            let sky = [UIColor(hex: 0x6b8db5).cgColor, UIColor(hex: 0x2a3a5a).cgColor] as CFArray
            let g1 = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: sky, locations: [0, 1])!
            cg.drawLinearGradient(g1, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height * 0.6), options: [])
            let ground = [UIColor(hex: 0x3a3a2a).cgColor, UIColor(hex: 0x1a1a14).cgColor] as CFArray
            let g2 = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: ground, locations: [0, 1])!
            cg.drawLinearGradient(g2, start: CGPoint(x: 0, y: size.height * 0.6), end: CGPoint(x: 0, y: size.height), options: [])
        }
    }

    private func setupLighting() {
        // 环境光
        let ambient = SCNNode()
        let a = SCNLight()
        a.type = .ambient
        a.color = UIColor(white: 0.55, alpha: 1)
        a.intensity = 600
        ambient.light = a
        rootNode.addChildNode(ambient)

        // 主方向光(带阴影)
        lightNode.name = "sun"
        let sun = SCNLight()
        sun.type = .directional
        sun.color = UIColor(white: 1.0, alpha: 1)
        sun.intensity = 1100
        sun.castsShadow = true
        sun.shadowMode = .deferred
        sun.shadowSampleCount = 8
        sun.shadowRadius = 6
        sun.shadowMapSize = CGSize(width: 2048, height: 2048)
        sun.orthographicScale = 15
        sun.shadowColor = UIColor.black.withAlphaComponent(0.55)
        lightNode.light = sun
        lightNode.eulerAngles = SCNVector3(-Float.pi/2.6, Float.pi/6, 0)
        lightNode.position = SCNVector3(10, 30, 10)
        rootNode.addChildNode(lightNode)

        // 雾效
        fogStartDistance = 30
        fogEndDistance = 70
        fogColor = UIColor(hex: 0x0a0f1c)
    }

    private func setupGround() {
        // 草地
        let groundGeo = SCNFloor()
        groundGeo.reflectivity = 0.05
        let mat = SCNMaterial()
        mat.diffuse.contents = makeGroundTexture()
        mat.diffuse.wrapS = .repeat
        mat.diffuse.wrapT = .repeat
        mat.diffuse.mipFilter = .linear
        mat.roughness.contents = UIColor(white: 0.85, alpha: 1)
        mat.lightingModel = .physicallyBased
        groundGeo.materials = [mat]
        let ground = SCNNode(geometry: groundGeo)
        rootNode.addChildNode(ground)

        // 边界石墙(4面)
        addWall(pos: SCNVector3(0, 0.5, -mapHalf), size: SCNVector3(mapHalf*2+2, 1.2, 0.5))
        addWall(pos: SCNVector3(0, 0.5, mapHalf), size: SCNVector3(mapHalf*2+2, 1.2, 0.5))
        addWall(pos: SCNVector3(-mapHalf, 0.5, 0), size: SCNVector3(0.5, 1.2, mapHalf*2+2))
        addWall(pos: SCNVector3(mapHalf, 0.5, 0), size: SCNVector3(0.5, 1.2, mapHalf*2+2))

        // 装饰: 散布几棵"树"(圆锥+圆柱)
        let treePositions: [SIMD2<Float>] = [
            [-12,-12],[-10,8],[12,-10],[14,8],
            [-6,14],[6,-14],[0,16],[-15,2],[15,-2]
        ]
        for p in treePositions {
            addTree(at: SCNVector3(p.x, 0, p.y))
        }
        // 装饰: 中心水晶
        addCrystal(at: SCNVector3(0, 0, 0))
    }

    private func makeGroundTexture() -> UIImage {
        let size = CGSize(width: 256, height: 256)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            UIColor(hex: 0x2a4a2e).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            // 草纹噪点
            for _ in 0..<600 {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)
                let r = CGFloat.random(in: 1...3)
                cg.setFillColor(UIColor(hex: 0x3a5d3e).withAlphaComponent(0.5).cgColor)
                cg.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
            // 一些暗纹
            for _ in 0..<200 {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)
                let r = CGFloat.random(in: 0.5...1.5)
                cg.setFillColor(UIColor(hex: 0x1a2e1c).cgColor)
                cg.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
        }
    }

    private func addWall(pos: SCNVector3, size: SCNVector3) {
        let geo = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: 0.1)
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(hex: 0x555a64)
        m.roughness.contents = 0.9
        m.lightingModel = .physicallyBased
        geo.materials = [m]
        let n = SCNNode(geometry: geo)
        n.position = pos
        n.castsShadow = true
        rootNode.addChildNode(n)
    }

    private func addTree(at pos: SCNVector3) {
        // 树干
        let trunkGeo = SCNCylinder(radius: 0.18, height: 1.0)
        let barkMat = SCNMaterial()
        barkMat.diffuse.contents = UIColor(hex: 0x6d4c41)
        barkMat.roughness.contents = 0.95
        barkMat.lightingModel = .physicallyBased
        trunkGeo.materials = [barkMat]
        let trunk = SCNNode(geometry: trunkGeo)
        trunk.position = SCNVector3(pos.x, 0.5, pos.z)
        trunk.castsShadow = true
        rootNode.addChildNode(trunk)

        // 树冠(三层圆锥)
        for i in 0..<3 {
            let coneGeo = SCNCone(topRadius: 0.05, bottomRadius: 0.9 - CGFloat(i)*0.18, height: 1.1)
            let leafMat = SCNMaterial()
            leafMat.diffuse.contents = UIColor(hex: 0x2e7d32).withAlphaComponent(1)
            leafMat.roughness.contents = 0.7
            leafMat.lightingModel = .physicallyBased
            coneGeo.materials = [leafMat]
            let cone = SCNNode(geometry: coneGeo)
            cone.position = SCNVector3(pos.x, 1.0 + Float(i)*0.55, pos.z)
            cone.castsShadow = true
            rootNode.addChildNode(cone)
        }
    }

    private func addCrystal(at pos: SCNVector3) {
        let geo = SCNCone(topRadius: 0, bottomRadius: 0.4, height: 1.2)
        let m = SCNMaterial()
        m.diffuse.contents = UIColor.primary
        m.emission.contents = UIColor.primary.withAlphaComponent(0.8)
        m.transparent.contents = UIColor.white.withAlphaComponent(0.85)
        m.transparencyMode = .rgbZero
        m.lightingModel = .blinn
        geo.materials = [m]
        let node = SCNNode(geometry: geo)
        node.position = SCNVector3(pos.x, 0.6, pos.z)
        node.name = "crystal"
        node.runAction(SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.rotateBy(x: 0, y: CGFloat.pi*2, z: 0, duration: 5),
            SCNAction.moveBy(x: 0, y: 0.3, z: 0, duration: 1.5),
            SCNAction.moveBy(x: 0, y: -0.3, z: 0, duration: 1.5),
        ])))
        rootNode.addChildNode(node)
    }

    // MARK: - 天空与云朵
    private func setupSkyAndClouds() {
        // 漂浮云朵(半透明白色扁球体,高空缓慢移动)
        let cloudPositions: [(Float, Float, Float, Float)] = [
            (-10, 14, -8, 2.5), (8, 16, -12, 3.0), (-4, 15, 10, 2.2),
            (12, 17, 6, 2.8), (-14, 14, 4, 2.4), (2, 18, -4, 3.2),
        ]
        for (x, y, z, s) in cloudPositions {
            let cloud = makeCloud(scale: s)
            cloud.position = SCNVector3(x, y, z)
            // 缓慢漂移
            let drift = SCNAction.repeatForever(SCNAction.sequence([
                SCNAction.moveBy(x: 6, y: 0, z: 0, duration: 18),
                SCNAction.moveBy(x: -6, y: 0, z: 0, duration: 18),
            ]))
            cloud.runAction(drift)
            rootNode.addChildNode(cloud)
        }

        // 月亮(高空发光圆盘,用球体)
        let moonGeo = SCNSphere(radius: 2.2)
        let moonMat = SCNMaterial()
        moonMat.diffuse.contents = UIColor(hex: 0xfff8e1)
        moonMat.emission.contents = UIColor(hex: 0xfff8e1).withAlphaComponent(0.95)
        moonMat.lightingModel = .constant
        moonGeo.materials = [moonMat]
        let moon = SCNNode(geometry: moonGeo)
        moon.position = SCNVector3(-22, 20, -25)
        moon.name = "moon"
        rootNode.addChildNode(moon)
    }

    private func makeCloud(scale: Float) -> SCNNode {
        let cloud = SCNNode()
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.white.withAlphaComponent(0.55)
        mat.lightingModel = .constant
        mat.transparencyMode = .rgbZero
        mat.transparent.contents = UIColor.white.withAlphaComponent(0.5)
        for i in 0..<4 {
            let r = CGFloat(1.2 + Float(i)*0.25)
            let g = SCNSphere(radius: r)
            g.materials = [mat]
            let n = SCNNode(geometry: g)
            n.position = SCNVector3(Float(i)*0.8 - 1.2, Float.random(in: -0.2...0.2), 0)
            cloud.addChildNode(n)
        }
        cloud.scale = SCNVector3(scale, scale*0.6, scale)
        return cloud
    }

    // MARK: - 环境萤火虫(用小型发光球体节点模拟)
    private func setupFireflies() {
        for _ in 0..<25 {
            let geo = SCNSphere(radius: 0.08)
            let m = SCNMaterial()
            m.diffuse.contents = UIColor(hex: 0xffe082)
            m.emission.contents = UIColor(hex: 0xffe082)
            m.lightingModel = .constant
            geo.materials = [m]
            let n = SCNNode(geometry: geo)
            let x = Float.random(in: -mapHalf...mapHalf)
            let y = Float.random(in: 1...6)
            let z = Float.random(in: -mapHalf...mapHalf)
            n.position = SCNVector3(x, y, z)
            n.opacity = 0.7
            rootNode.addChildNode(n)
            // 缓慢漂浮 + 闪烁
            let floatUp = SCNAction.moveBy(x: CGFloat(Float.random(in: -2...2)), y: CGFloat(Float.random(in: 1...3)), z: CGFloat(Float.random(in: -2...2)), duration: TimeInterval(Float.random(in: 6...12)))
            let floatBack = floatUp.reversed()
            let pulse = SCNAction.sequence([
                SCNAction.fadeOpacity(to: 0.2, duration: 1.5),
                SCNAction.fadeOpacity(to: 0.8, duration: 1.5),
            ])
            n.runAction(SCNAction.repeatForever(SCNAction.sequence([floatUp, floatBack])))
            n.runAction(SCNAction.repeatForever(pulse))
        }
    }

    // MARK: - 通用粒子生成器(基于节点,兼容性最佳)
    /// 生成 count 个小球,向随机方向飞散并淡出
    private func spawnNodeParticles(at pos: SCNVector3, color: UIColor, count: Int, speed: Float, duration: TimeInterval, size: CGFloat, gravityY: Float = 0) {
        let container = SCNNode()
        container.position = pos
        rootNode.addChildNode(container)
        for _ in 0..<count {
            let geo = SCNSphere(radius: size)
            let m = SCNMaterial()
            m.diffuse.contents = color
            m.emission.contents = color
            m.lightingModel = .constant
            geo.materials = [m]
            let p = SCNNode(geometry: geo)
            p.position = SCNVector3(0, 0, 0)
            container.addChildNode(p)
            // 随机方向
            let dx = Float.random(in: -1...1) * speed
            let dy = Float.random(in: -0.3...1) * speed + gravityY
            let dz = Float.random(in: -1...1) * speed
            let move = SCNAction.moveBy(x: CGFloat(dx), y: CGFloat(dy), z: CGFloat(dz), duration: duration)
            let fade = SCNAction.fadeOut(duration: duration)
            p.runAction(SCNAction.group([move, fade, SCNAction.scale(to: 0.01, duration: duration)]))
        }
        // 结束后移除容器
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
            container.removeFromParentNode()
        }
    }

    // MARK: - 战斗粒子特效
    /// 受击火花
    func spawnHitSparks(at pos: SCNVector3, color: UIColor = .gold) {
        spawnNodeParticles(at: pos, color: color, count: 12, speed: 3, duration: 0.4, size: 0.06, gravityY: 1)
    }

    /// 死亡爆裂
    func spawnDeathBurst(at pos: SCNVector3, color: UIColor) {
        spawnNodeParticles(at: pos, color: color, count: 24, speed: 5, duration: 0.9, size: 0.1, gravityY: -1)
    }

    /// 升级金光(向上飘)
    func spawnLevelUpBurst(at pos: SCNVector3) {
        spawnNodeParticles(at: pos, color: .gold, count: 30, speed: 4, duration: 1.2, size: 0.12, gravityY: 4)
    }

    /// 治疗光环(向上飘)
    func spawnHealEffect(at pos: SCNVector3) {
        spawnNodeParticles(at: pos, color: UIColor(hex: 0x66bb6a), count: 20, speed: 2, duration: 1.0, size: 0.1, gravityY: 3)
    }

    /// 烈焰技能特效
    func spawnFlameSkill(at pos: SCNVector3) {
        spawnNodeParticles(at: pos, color: UIColor(hex: 0xff5722), count: 35, speed: 6, duration: 0.8, size: 0.14, gravityY: 2)
        // 额外加一些黄色火星
        spawnNodeParticles(at: pos, color: UIColor(hex: 0xffd54f), count: 15, speed: 4, duration: 0.6, size: 0.08, gravityY: 1)
    }

    // MARK: - 玩家(关节骨骼模型)
    private func setupPlayer() {
        // 材质
        let armorMat = SCNMaterial()
        armorMat.diffuse.contents = UIColor.primary
        armorMat.emission.contents = UIColor.primary.withAlphaComponent(0.12)
        armorMat.metalness.contents = 0.7
        armorMat.roughness.contents = 0.3
        armorMat.lightingModel = .physicallyBased

        let skinMat = SCNMaterial()
        skinMat.diffuse.contents = UIColor(hex: 0xffe0b2)
        skinMat.roughness.contents = 0.55
        skinMat.lightingModel = .physicallyBased

        let leatherMat = SCNMaterial()
        leatherMat.diffuse.contents = UIColor(hex: 0x37474f)
        leatherMat.roughness.contents = 0.8
        leatherMat.lightingModel = .physicallyBased

        let goldMat = SCNMaterial()
        goldMat.diffuse.contents = UIColor(hex: 0xffd54f)
        goldMat.metalness.contents = 0.9
        goldMat.roughness.contents = 0.2
        goldMat.lightingModel = .physicallyBased

        let bladeMat = SCNMaterial()
        bladeMat.diffuse.contents = UIColor(hex: 0xeceff1)
        bladeMat.metalness.contents = 0.95
        bladeMat.roughness.contents = 0.12
        bladeMat.lightingModel = .physicallyBased

        // 用一个"根骨骼"节点承载身体,便于整体呼吸/跳跃
        let root = SCNNode()
        root.position = SCNVector3(0, 0, 0)
        playerNode.addChildNode(root)
        torsoNode = root

        // 1) 躯干
        let bodyGeo = SCNCapsule(capRadius: 0.3, height: 0.9)
        bodyGeo.materials = [armorMat]
        let body = SCNNode(geometry: bodyGeo)
        body.position = SCNVector3(0, 0.62, 0)
        body.castsShadow = true
        root.addChildNode(body)

        // 胸甲金饰
        let chestGeo = SCNBox(width: 0.22, height: 0.22, length: 0.06, chamferRadius: 0.02)
        chestGeo.materials = [goldMat]
        let chest = SCNNode(geometry: chestGeo)
        chest.position = SCNVector3(0, 0.68, 0.26)
        root.addChildNode(chest)

        // 肩甲
        let shoulderGeo = SCNSphere(radius: 0.16)
        shoulderGeo.materials = [armorMat]
        let lShoulder = SCNNode(geometry: shoulderGeo)
        lShoulder.position = SCNVector3(-0.32, 0.92, 0)
        lShoulder.castsShadow = true
        root.addChildNode(lShoulder)
        let rShoulder = SCNNode(geometry: shoulderGeo)
        rShoulder.position = SCNVector3(0.32, 0.92, 0)
        rShoulder.castsShadow = true
        root.addChildNode(rShoulder)

        // 2) 头部(独立节点,可点头)
        let headRoot = SCNNode()
        headRoot.position = SCNVector3(0, 1.05, 0)
        root.addChildNode(headRoot)
        headNode = headRoot

        let headGeo = SCNSphere(radius: 0.22)
        headGeo.materials = [skinMat]
        let head = SCNNode(geometry: headGeo)
        head.position = SCNVector3(0, 0.18, 0)
        head.castsShadow = true
        headRoot.addChildNode(head)

        let helmGeo = SCNSphere(radius: 0.25)
        helmGeo.materials = [armorMat]
        let helm = SCNNode(geometry: helmGeo)
        helm.position = SCNVector3(0, 0.22, 0)
        helm.scale = SCNVector3(1, 0.65, 1)
        headRoot.addChildNode(helm)
        let plumeGeo = SCNCone(topRadius: 0, bottomRadius: 0.05, height: 0.25)
        plumeGeo.materials = [goldMat]
        let plume = SCNNode(geometry: plumeGeo)
        plume.position = SCNVector3(0, 0.48, 0)
        headRoot.addChildNode(plume)
        // 眼睛(发光)
        let eyeMat = SCNMaterial()
        eyeMat.diffuse.contents = UIColor.white
        eyeMat.emission.contents = UIColor.cyan
        eyeMat.lightingModel = .constant
        let eyeGeo = SCNSphere(radius: 0.03)
        eyeGeo.materials = [eyeMat]
        let lEye = SCNNode(geometry: eyeGeo); lEye.position = SCNVector3(-0.07, 0.18, 0.2)
        let rEye = SCNNode(geometry: eyeGeo); rEye.position = SCNVector3(0.07, 0.18, 0.2)
        headRoot.addChildNode(lEye); headRoot.addChildNode(rEye)

        // 3) 左臂(关节在肩膀)
        leftArmJoint = makeLimb(jointAt: SCNVector3(-0.34, 0.92, 0), length: 0.6, radius: 0.09, mat: armorMat)
        root.addChildNode(leftArmJoint!)
        // 4) 右臂(持剑)
        rightArmJoint = makeLimb(jointAt: SCNVector3(0.34, 0.92, 0), length: 0.6, radius: 0.09, mat: armorMat)
        root.addChildNode(rightArmJoint!)
        // 把剑挂到右手末端
        let swordNode = SCNNode()
        let bladeGeo = SCNBox(width: 0.05, height: 0.85, length: 0.015, chamferRadius: 0.008)
        bladeGeo.materials = [bladeMat]
        let blade = SCNNode(geometry: bladeGeo)
        blade.position = SCNVector3(0, 0.42, 0)
        swordNode.addChildNode(blade)
        let guardGeo = SCNBox(width: 0.2, height: 0.035, length: 0.05, chamferRadius: 0.008)
        guardGeo.materials = [goldMat]
        let guardNode = SCNNode(geometry: guardGeo)
        swordNode.addChildNode(guardNode)
        let hiltGeo = SCNCylinder(radius: 0.028, height: 0.14)
        hiltGeo.materials = [leatherMat]
        let hilt = SCNNode(geometry: hiltGeo)
        hilt.position = SCNVector3(0, -0.1, 0)
        swordNode.addChildNode(hilt)
        swordNode.position = SCNVector3(0, -0.32, 0.04)
        swordNode.eulerAngles = SCNVector3(0, 0, Float.pi/9)
        swordNode.castsShadow = true
        rightArmJoint?.addChildNode(swordNode)

        // 5) 左腿(关节在髋部)
        leftLegJoint = makeLimb(jointAt: SCNVector3(-0.15, 0.36, 0), length: 0.55, radius: 0.11, mat: leatherMat)
        root.addChildNode(leftLegJoint!)
        // 6) 右腿
        rightLegJoint = makeLimb(jointAt: SCNVector3(0.15, 0.36, 0), length: 0.55, radius: 0.11, mat: leatherMat)
        root.addChildNode(rightLegJoint!)

        // 7) 披风
        let capeGeo = SCNBox(width: 0.48, height: 0.85, length: 0.03, chamferRadius: 0.02)
        let capeMat = SCNMaterial()
        capeMat.diffuse.contents = UIColor.danger.withAlphaComponent(0.92)
        capeMat.emission.contents = UIColor.danger.withAlphaComponent(0.18)
        capeMat.roughness.contents = 0.6
        capeMat.lightingModel = .physicallyBased
        capeGeo.materials = [capeMat]
        let cape = SCNNode(geometry: capeGeo)
        cape.position = SCNVector3(0, 0.68, -0.22)
        cape.eulerAngles = SCNVector3(-0.12, 0, 0)
        root.addChildNode(cape)
        capeNode = cape

        playerNode.position = SCNVector3(0, 0, 6)
        rootNode.addChildNode(playerNode)

        // 玩家头顶血条
        setupHpBar(playerHpBar, fill: playerHpFill, width: playerHpWidth, color: .danger, parent: playerNode, yOffset: 1.85)

        // 摄像机(轨道环绕 + 始终看向玩家)
        let cam = SCNCamera()
        cam.fieldOfView = 55
        cam.zNear = 0.1
        cam.zFar = 200
        cameraNode.camera = cam
        rootNode.addChildNode(cameraNode)
        let look = SCNLookAtConstraint(target: playerNode)
        look.isGimbalLockEnabled = true
        cameraNode.constraints = [look]
        updateCameraPosition()

        // 玩家跟随点光源
        let pLight = SCNLight()
        pLight.type = .omni
        pLight.color = UIColor(hex: 0xffe0b2, alpha: 0.9)
        pLight.intensity = 900
        pLight.castsShadow = false
        pLight.attenuationStartDistance = 8
        pLight.attenuationEndDistance = 18
        playerLightNode.light = pLight
        playerLightNode.position = SCNVector3(0, 3, 0)
        playerNode.addChildNode(playerLightNode)

        // 启动 idle 呼吸动画
        startIdle()
    }

    /// 构造一个以 jointAt 为旋转中心的肢体(胶囊向下偏移)
    private func makeLimb(jointAt: SCNVector3, length: CGFloat, radius: CGFloat, mat: SCNMaterial) -> SCNNode {
        let joint = SCNNode()
        joint.position = jointAt
        let geo = SCNCapsule(capRadius: radius, height: length)
        geo.materials = [mat]
        let limb = SCNNode(geometry: geo)
        limb.position = SCNVector3(0, -Float(length)/2, 0)
        limb.castsShadow = true
        joint.addChildNode(limb)
        return joint
    }

    /// 更新摄像机轨道位置
    func updateCameraPosition() {
        let p = playerNode.position
        cameraNode.position = SCNVector3(
            p.x + sin(cameraYaw) * cameraDistance,
            cameraHeight,
            p.z + cos(cameraYaw) * cameraDistance
        )
        lightNode.position = SCNVector3(p.x + sin(cameraYaw + Float.pi/4) * 12, 30, p.z + cos(cameraYaw + Float.pi/4) * 12)
    }

    /// 手势旋转视角
    func orbitCamera(deltaYaw: Float) {
        cameraYaw += deltaYaw
        updateCameraPosition()
    }

    // MARK: - 角色动画
    private func startIdle() {
        torsoNode?.removeAction(forKey: "walk")
        guard let torso = torsoNode else { return }
        let bob = SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0.04, z: 0, duration: 1.6),
            SCNAction.moveBy(x: 0, y: -0.04, z: 0, duration: 1.6),
        ]))
        bob.timingMode = .easeInEaseOut
        torso.runAction(bob, forKey: "idle")
        // 手臂自然垂下
        leftArmJoint?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2))
        rightArmJoint?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi/8, duration: 0.2))
    }

    private func startWalk() {
        torsoNode?.removeAction(forKey: "idle")
        guard !isBusy else { return }
        let swing: Float = 0.6
        let dur: TimeInterval = 0.32
        let lArm = SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.rotateTo(x: CGFloat(swing), y: 0, z: 0, duration: dur),
            SCNAction.rotateTo(x: CGFloat(-swing), y: 0, z: 0, duration: dur),
        ]))
        let rArm = SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.rotateTo(x: CGFloat(-swing), y: 0, z: CGFloat.pi/8, duration: dur),
            SCNAction.rotateTo(x: CGFloat(swing), y: 0, z: CGFloat.pi/8, duration: dur),
        ]))
        let lLeg = SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.rotateTo(x: CGFloat(-swing), y: 0, z: 0, duration: dur),
            SCNAction.rotateTo(x: CGFloat(swing), y: 0, z: 0, duration: dur),
        ]))
        let rLeg = SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.rotateTo(x: CGFloat(swing), y: 0, z: 0, duration: dur),
            SCNAction.rotateTo(x: CGFloat(-swing), y: 0, z: 0, duration: dur),
        ]))
        lArm.timingMode = .easeInEaseOut
        rArm.timingMode = .easeInEaseOut
        leftArmJoint?.runAction(lArm, forKey: "walk")
        rightArmJoint?.runAction(rArm, forKey: "walk")
        leftLegJoint?.runAction(lLeg, forKey: "walk")
        rightLegJoint?.runAction(rLeg, forKey: "walk")
    }

    private func stopWalk() {
        leftArmJoint?.removeAction(forKey: "walk")
        rightArmJoint?.removeAction(forKey: "walk")
        leftLegJoint?.removeAction(forKey: "walk")
        rightLegJoint?.removeAction(forKey: "walk")
        startIdle()
    }

    /// 挥砍动画(右手高举劈下,不含身体位移,避免与移动序列冲突)
    func playJumpSlash() {
        let raise = SCNAction.rotateTo(x: CGFloat(-2.2), y: 0, z: CGFloat.pi/8, duration: 0.18)
        let chop = SCNAction.rotateTo(x: CGFloat(1.3), y: 0, z: CGFloat.pi/8, duration: 0.16)
        chop.timingMode = .easeIn
        rightArmJoint?.runAction(SCNAction.sequence([raise, chop, SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi/8, duration: 0.12)]))
    }

    private func setupHpBar(_ bar: SCNNode, fill: SCNNode, width: CGFloat, color: UIColor, parent: SCNNode, yOffset: Float) {
        let bgPlane = SCNPlane(width: width, height: 0.12)
        let bgMat = SCNMaterial()
        bgMat.diffuse.contents = UIColor.black.withAlphaComponent(0.6)
        bgMat.isDoubleSided = true
        bgMat.lightingModel = .constant
        bgPlane.materials = [bgMat]
        bar.geometry = bgPlane
        bar.constraints = [SCNBillboardConstraint()]
        bar.position = SCNVector3(0, yOffset, 0)
        parent.addChildNode(bar)

        let fillPlane = SCNPlane(width: width, height: 0.10)
        let fillMat = SCNMaterial()
        fillMat.diffuse.contents = color
        fillMat.emission.contents = color.withAlphaComponent(0.6)
        fillMat.isDoubleSided = true
        fillMat.lightingModel = .constant
        fillPlane.materials = [fillMat]
        fill.geometry = fillPlane
        fill.position = SCNVector3(0, 0, 0.001)
        bar.addChildNode(fill)
    }

    // MARK: - 怪物
    func spawnMonsters() {
        // 清理旧的
        for m in monsters {
            m.node.removeFromParentNode()
        }
        monsters.removeAll()

        // 6只普通怪 + 1只 boss
        let wildConfigs: [(String, Int, UIColor)] = [
            ("史莱姆", 1, UIColor(hex: 0x66bb6a)),
            ("野狼", 3, UIColor(hex: 0x90a4ae)),
            ("哥布林", 5, UIColor(hex: 0x8bc34a)),
            ("蜘蛛", 8, UIColor(hex: 0x5c6bc0)),
            ("骷髅兵", 10, UIColor(hex: 0xeceff1)),
            ("石巨人", 12, UIColor(hex: 0x7e8a97)),
        ]
        for (i, (name, lvl, color)) in wildConfigs.enumerated() {
            let angle = Float(i) / Float(wildConfigs.count) * Float.pi * 2
            let r: Float = 7 + Float(i).truncatingRemainder(dividingBy: 3) * 2
            let pos = SCNVector3(cos(angle)*r, 0, sin(angle)*r)
            spawnMonster(name: name, level: lvl, color: color, pos: pos, isBoss: false, bossId: nil, scale: 1.0)
        }
        // Boss 在角落
        spawnMonster(name: "哥布林首领", level: 5, color: UIColor(hex: 0x558b2f), pos: SCNVector3(-14, 0, -14), isBoss: true, bossId: 1, scale: 1.6)
    }

    private func spawnMonster(name: String, level: Int, color: UIColor, pos: SCNVector3, isBoss: Bool, bossId: Int?, scale: Float) {
        let node = SCNNode()
        // 身体
        let bodyGeo: SCNGeometry
        if isBoss {
            bodyGeo = SCNCapsule(capRadius: 0.55, height: 2.0)
        } else {
            bodyGeo = SCNCapsule(capRadius: 0.35, height: 1.3)
        }
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.emission.contents = color.withAlphaComponent(0.18)
        m.roughness.contents = 0.6
        m.lightingModel = .physicallyBased
        bodyGeo.materials = [m]
        let body = SCNNode(geometry: bodyGeo)
        body.position = SCNVector3(0, isBoss ? 1.0 : 0.65, 0)
        body.castsShadow = true
        node.addChildNode(body)

        // 眼睛(发光)
        let eyeGeo = SCNSphere(radius: 0.06)
        let eyeMat = SCNMaterial()
        eyeMat.diffuse.contents = UIColor.white
        eyeMat.emission.contents = UIColor.red
        eyeMat.lightingModel = .constant
        eyeGeo.materials = [eyeMat]
        let lEye = SCNNode(geometry: eyeGeo)
        lEye.position = SCNVector3(-0.12, isBoss ? 1.3 : 0.95, 0.28)
        let rEye = lEye.clone()
        rEye.position = SCNVector3(0.12, isBoss ? 1.3 : 0.95, 0.28)
        node.addChildNode(lEye)
        node.addChildNode(rEye)

        // 等级标牌(3D text)
        let lvlText = SCNText(string: "Lv.\(level)", extrusionDepth: 0.05)
        lvlText.font = UIFont.systemFont(ofSize: 0.5, weight: .bold)
        lvlText.firstMaterial?.diffuse.contents = isBoss ? UIColor.gold : UIColor.white
        lvlText.firstMaterial?.emission.contents = isBoss ? UIColor.gold : UIColor.white
        lvlText.firstMaterial?.lightingModel = .constant
        let lvlNode = SCNNode(geometry: lvlText)
        lvlNode.position = SCNVector3(-0.4, isBoss ? 2.5 : 1.8, 0)
        lvlNode.scale = SCNVector3(0.5, 0.5, 0.5)
        lvlNode.constraints = [SCNBillboardConstraint()]
        node.addChildNode(lvlNode)

        node.position = pos
        node.scale = SCNVector3(scale, scale, scale)
        node.name = "monster_\(name)"
        rootNode.addChildNode(node)

        // 血条
        let bar = SCNNode()
        let fill = SCNNode()
        let w: CGFloat = isBoss ? 1.6 : 1.0
        setupHpBar(bar, fill: fill, width: w, color: isBoss ? .gold : .danger, parent: node, yOffset: isBoss ? 3.0 : 2.2)

        let entity = MonsterEntity(
            node: node, name: name, level: level, color: color,
            isBoss: isBoss, bossId: bossId, alive: true,
            hpBarNode: bar, hpFillNode: fill, hpBarWidth: w
        )
        monsters.append(entity)

        // 闲置漂浮
        node.runAction(SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 1.4),
            SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 1.4),
        ])))
    }

    // MARK: - 输入控制
    func setMoveVector(_ v: SIMD2<Float>) {
        moveVector = v
    }

    func update(deltaTime: Float) {
        // 玩家移动(相机相对: 推上=向屏幕里走,推下=向屏幕外走)
        let mag = sqrt(moveVector.x*moveVector.x + moveVector.y*moveVector.y)
        if mag > 0.05 && !isBusy {
            let jx = moveVector.x / max(mag, 0.001)
            let jy = moveVector.y / max(mag, 0.001)
            // 相机到玩家方向 = "前方"(指向屏幕深处)
            let camP = cameraNode.position
            var fwd = SIMD2<Float>(playerNode.position.x - camP.x, playerNode.position.z - camP.z)
            let flen = sqrt(fwd.x*fwd.x + fwd.y*fwd.y)
            if flen > 0.001 { fwd = SIMD2<Float>(fwd.x/flen, fwd.y/flen) }
            let right = SIMD2<Float>(-fwd.y, fwd.x)
            let moveDir = SIMD2<Float>(fwd.x * jy + right.x * jx, fwd.y * jy + right.y * jx)
            let speed = moveSpeed * min(mag, 1.0)
            var np = playerNode.simdPosition
            np.x = clamp(np.x + moveDir.x * speed * deltaTime, -mapHalf+1, mapHalf-1)
            np.z = clamp(np.z + moveDir.y * speed * deltaTime, -mapHalf+1, mapHalf-1)
            playerNode.simdPosition = np

            // 朝向移动方向(模型默认面向 +Z)
            let angle = atan2(moveDir.x, moveDir.y)
            playerNode.eulerAngles.y = -angle

            updateCameraPosition()
            onPlayerMove?(playerNode.position)

            if !isWalking { isWalking = true; startWalk() }
        } else {
            if isWalking { isWalking = false; stopWalk() }
        }
        // 怪物面向玩家
        for m in monsters where m.alive {
            let dx = playerNode.position.x - m.node.position.x
            let dz = playerNode.position.z - m.node.position.z
            m.node.eulerAngles.y = -atan2(dx, dz)
        }
    }

    private func clamp(_ v: Float, _ lo: Float, _ hi: Float) -> Float { min(max(v, lo), hi) }

    // MARK: - 怪物点击检测
    func hitTestMonster(at point: CGPoint, in view: SCNView) -> Int? {
        let opts: [SCNHitTestOption: Any] = [
            .boundingBoxOnly: false,
            .firstFoundOnly: true,
            .ignoreChildNodes: false,
        ]
        let hits = view.hitTest(point, options: opts)
        for h in hits {
            var n: SCNNode? = h.node
            while let cur = n {
                if let name = cur.name, name.hasPrefix("monster_") {
                    if let idx = monsters.firstIndex(where: { $0.node === cur && $0.alive }) {
                        return idx
                    }
                }
                n = cur.parent
            }
        }
        return nil
    }

    // MARK: - 战斗动画
    /// 播放攻击动画:玩家冲向怪物 -> 跳劈+受击粒子+伤害数字 -> 怪物血条变化 -> 怪物倒下爆裂
    func playBattleAnimation(monsterIdx: Int, win: Bool, rounds: Int, monsterHpPct: CGFloat, playerAtk: Int, completion: @escaping () -> Void) {
        guard monsterIdx < monsters.count else { completion(); return }
        let m = monsters[monsterIdx]
        isBusy = true
        if isWalking { isWalking = false; stopWalk() }
        let origPos = playerNode.position
        let targetPos = SCNVector3(
            m.node.position.x - Float(m.node.scale.x) * 0.8,
            origPos.y,
            m.node.position.z
        )
        let dist = sqrt(pow(Float(targetPos.x - origPos.x), 2) + pow(Float(targetPos.z - origPos.z), 2))

        // 怪物头顶位置(粒子/飘字基准点)
        let monsterTop = SCNVector3(m.node.position.x, m.node.position.y + Float(m.node.scale.x) * 1.8, m.node.position.z)

        // 面向怪物
        let faceAngle = atan2(targetPos.x - origPos.x, targetPos.z - origPos.z)
        playerNode.runAction(SCNAction.rotateTo(x: 0, y: CGFloat(-faceAngle), z: 0, duration: 0.12))

        // 1) 冲过去
        let rush = SCNAction.move(to: targetPos, duration: TimeInterval(min(0.32, dist/8)))
        rush.timingMode = .easeInEaseOut

        // 3) 受击闪烁
        let origEmission = m.color.withAlphaComponent(0.18)
        let blink = SCNAction.sequence([
            SCNAction.run { node in
                if let mat = node.geometry?.materials.first { mat.emission.contents = UIColor.white }
            },
            SCNAction.wait(duration: 0.07),
            SCNAction.run { node in
                if let mat = node.geometry?.materials.first { mat.emission.contents = origEmission }
            },
            SCNAction.wait(duration: 0.07),
            SCNAction.run { node in
                if let mat = node.geometry?.materials.first { mat.emission.contents = UIColor.white }
            },
            SCNAction.wait(duration: 0.07),
            SCNAction.run { node in
                if let mat = node.geometry?.materials.first { mat.emission.contents = origEmission }
            },
        ])

        // 到达怪物后:跳劈 + 闪烁 + 粒子 + 伤害数字 + 音效
        let hitImpact = SCNAction.run { [weak self] _ in
            guard let self = self else { return }
            self.playJumpSlash()
            SoundManager.shared.play(.attack)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                SoundManager.shared.play(.hit)
            }
            // 只对 body 子节点(第一个子节点)播闪烁,若已无子节点则跳过
            if let bodyNode = m.node.childNodes.first {
                bodyNode.runAction(blink)
            }
            self.spawnHitSparks(at: monsterTop, color: m.color)
            let dmg1 = max(1, playerAtk + Int.random(in: -5...15))
            self.showDamageNumber("\(dmg1)", color: .white, at: monsterTop, scale: 1.0)

            let segments = min(max(rounds, 1), 3)
            for i in 1..<segments {
                let delay = TimeInterval(i) * 0.18
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self = self else { return }
                    guard self.monsters.indices.contains(monsterIdx) else { return }
                    guard self.monsters[monsterIdx].alive || win else { return }
                    self.spawnHitSparks(at: monsterTop, color: m.color)
                    SoundManager.shared.play(.hit)
                    let dmg = max(1, playerAtk + Int.random(in: -8...20))
                    let col: UIColor = i == segments - 1 && win ? .gold : .white
                    self.showDamageNumber("\(dmg)", color: col, at: monsterTop, scale: i == segments - 1 ? 1.3 : 1.0)
                }
            }
        }

        // 4) 怪物血条变化(命中后)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.setMonsterHp(idx: monsterIdx, pct: win ? 0 : monsterHpPct)
        }

        // 5) 起跳劈砍 + 回到原位
        let hop = SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 1.2, z: 0, duration: 0.18),
            SCNAction.moveBy(x: 0, y: -1.2, z: 0, duration: 0.15),
        ])
        let back = SCNAction.move(to: origPos, duration: 0.3)
        back.timingMode = .easeInEaseOut

        playerNode.runAction(SCNAction.sequence([rush, SCNAction.group([hitImpact, hop]), SCNAction.wait(duration: 0.4), back])) { [weak self] in
            // SCNAction 完成回调线程不保证是主线程,统一切回主线程
            DispatchQueue.main.async {
                guard let self = self else { completion(); return }
                self.isBusy = false
                if win {
                    SoundManager.shared.play(.death)
                    self.spawnDeathBurst(at: monsterTop, color: m.color)
                    self.spawnDeathBurst(at: monsterTop, color: .gold)
                    let fall = SCNAction.sequence([
                        SCNAction.rotateTo(x: CGFloat.pi/2, y: 0, z: 0, duration: 0.3),
                        SCNAction.fadeOut(duration: 0.35),
                        SCNAction.run { node in node.isHidden = true }
                    ])
                    m.node.runAction(fall) { [weak self] in
                        // 再次切回主线程(完成回调可能仍在渲染线程)
                        DispatchQueue.main.async {
                            guard let self = self else { completion(); return }
                            if self.monsters.indices.contains(monsterIdx) {
                                self.monsters[monsterIdx].alive = false
                            }
                            let delay = RemoteConfig.shared.monsterRespawnDelay
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                                guard let self = self, self.monsters.indices.contains(monsterIdx) else { return }
                                self.respawn(monsterIdx: monsterIdx)
                            }
                            completion()
                        }
                    }
                } else {
                    completion()
                }
            }
        }
    }

    // MARK: - AOE 群攻特效(命中范围内所有可见怪物)
    func playAOESkill(centerPos: SCNVector3) {
        SoundManager.shared.play(.aoe)
        // 中心爆炸
        spawnNodeParticles(at: centerPos, color: UIColor(hex: 0xff7043), count: 40, speed: 7, duration: 0.9, size: 0.16, gravityY: 1)
        spawnNodeParticles(at: centerPos, color: UIColor(hex: 0xffd54f), count: 25, speed: 5, duration: 0.7, size: 0.1, gravityY: 2)
        // 冲击波环(扁平放大圆环)
        let ringGeo = SCNTorus(ringRadius: 0.3, pipeRadius: 0.06)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = UIColor(hex: 0xff7043)
        ringMat.emission.contents = UIColor(hex: 0xff7043)
        ringMat.lightingModel = .constant
        ringGeo.materials = [ringMat]
        let ring = SCNNode(geometry: ringGeo)
        ring.position = SCNVector3(centerPos.x, 0.3, centerPos.z)
        ring.eulerAngles.x = Float.pi/2
        rootNode.addChildNode(ring)
        ring.runAction(SCNAction.sequence([
            SCNAction.scale(to: 6, duration: 0.5),
            SCNAction.fadeOut(duration: 0.2),
            SCNAction.removeFromParentNode(),
        ]))
        // 对范围内每只活着的怪播受击火花+伤害数字
        for m in monsters where m.alive {
            let dx = m.node.position.x - centerPos.x
            let dz = m.node.position.z - centerPos.z
            if sqrt(dx*dx + dz*dz) < 4.5 {
                let top = SCNVector3(m.node.position.x, m.node.position.y + 1.6, m.node.position.z)
                spawnHitSparks(at: top, color: .gold)
                showDamageNumber("\(Int.random(in: 80...220))", color: .gold, at: top, scale: 1.2)
                m.node.childNodes.first?.runAction(SCNAction.sequence([
                    SCNAction.moveBy(x: 0, y: 0.2, z: 0, duration: 0.1),
                    SCNAction.moveBy(x: 0, y: -0.2, z: 0, duration: 0.1),
                ]))
            }
        }
    }

    /// 把玩家瞬移到指定怪物旁(用于 BOSS 跳转)
    func teleportToMonster(idx: Int) {
        guard monsters.indices.contains(idx) else { return }
        let m = monsters[idx]
        let ang = Float.random(in: 0...(Float.pi*2))
        let pos = SCNVector3(m.node.position.x + cos(ang)*2.2, 0, m.node.position.z + sin(ang)*2.2)
        playerNode.position = pos
        updateCameraPosition()
        // 瞬移光效
        spawnNodeParticles(at: SCNVector3(pos.x, 1, pos.z), color: .primary, count: 20, speed: 4, duration: 0.6, size: 0.1, gravityY: 2)
    }

    /// 显示伤害数字(比飘字更大更醒目)
    func showDamageNumber(_ text: String, color: UIColor, at pos: SCNVector3, scale: Float = 1.0) {
        let txtGeo = SCNText(string: text, extrusionDepth: 0.06)
        txtGeo.font = UIFont.systemFont(ofSize: 0.6, weight: .heavy)
        txtGeo.firstMaterial?.diffuse.contents = color
        txtGeo.firstMaterial?.emission.contents = color
        txtGeo.firstMaterial?.lightingModel = .constant
        let n = SCNNode(geometry: txtGeo)
        n.position = SCNVector3(pos.x + Float.random(in: -0.3...0.3), pos.y + 0.5, pos.z)
        n.scale = SCNVector3(scale, scale, scale)
        n.constraints = [SCNBillboardConstraint()]
        rootNode.addChildNode(n)
        // 弹跳上浮 + 淡出
        let action = SCNAction.group([
            SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.4, z: 0, duration: 0.15),
                SCNAction.moveBy(x: 0, y: 1.0, z: 0, duration: 0.7),
            ]),
            SCNAction.sequence([
                SCNAction.wait(duration: 0.15),
                SCNAction.fadeOut(duration: 0.7),
            ]),
            SCNAction.sequence([
                SCNAction.scale(to: CGFloat(scale * 1.2), duration: 0.1),
                SCNAction.scale(to: CGFloat(scale), duration: 0.1),
            ]),
        ])
        n.runAction(SCNAction.sequence([action, SCNAction.removeFromParentNode()]))
    }

    private func respawn(monsterIdx: Int) {
        guard monsterIdx < monsters.count else { return }
        var m = monsters[monsterIdx]
        m.node.isHidden = false
        m.node.opacity = 1
        m.node.eulerAngles.x = 0
        m.alive = true
        monsters[monsterIdx] = m
        setMonsterHp(idx: monsterIdx, pct: 1.0)
        // 重生淡入
        m.node.opacity = 0
        m.node.runAction(SCNAction.fadeIn(duration: 0.5))
    }

    /// 外部设置怪物存活状态(monsters 为 private(set))
    func setMonsterAlive(idx: Int, alive: Bool) {
        guard monsters.indices.contains(idx) else { return }
        monsters[idx].alive = alive
    }

    /// 公开的重生接口
    func respawnPublic(idx: Int) { respawn(monsterIdx: idx) }

    func setPlayerHp(pct: CGFloat) {
        let target = max(0, min(1, pct))
        let start = CGFloat(playerHpFill.scale.x)
        let w = playerHpWidth
        let action = SCNAction.customAction(duration: 0.3) { node, t in
            let cur = start + (target - start) * CGFloat(t)
            node.scale.x = Float(cur)
            let newW = w * cur
            node.position = SCNVector3(Float(-(w - newW) / 2), 0, 0.001)
        }
        action.timingMode = .easeOut
        playerHpFill.runAction(action)
    }

    func setMonsterHp(idx: Int, pct: CGFloat) {
        guard idx < monsters.count else { return }
        let m = monsters[idx]
        let w = m.hpBarWidth
        let start = CGFloat(m.hpFillNode.scale.x)
        let target = max(0, min(1, pct))
        let action = SCNAction.customAction(duration: 0.3) { node, t in
            let cur = start + (target - start) * CGFloat(t)
            node.scale.x = Float(cur)
            let newW = w * cur
            node.position = SCNVector3(Float(-(w - newW) / 2), 0, 0.001)
        }
        m.hpFillNode.runAction(action)
        var ent = monsters[idx]
        ent.hpPct = target
        monsters[idx] = ent
        m.hpBarNode.opacity = (target >= 1.0) ? 0.6 : 1.0
    }

    /// 显示飘字(伤害/经验)
    func showFloatText(_ text: String, color: UIColor, at pos: SCNVector3) {
        let txtGeo = SCNText(string: text, extrusionDepth: 0.05)
        txtGeo.font = UIFont.systemFont(ofSize: 0.5, weight: .bold)
        txtGeo.firstMaterial?.diffuse.contents = color
        txtGeo.firstMaterial?.emission.contents = color
        txtGeo.firstMaterial?.lightingModel = .constant
        let n = SCNNode(geometry: txtGeo)
        n.position = pos
        n.scale = SCNVector3(0.8, 0.8, 0.8)
        n.constraints = [SCNBillboardConstraint()]
        rootNode.addChildNode(n)
        let action = SCNAction.sequence([
            SCNAction.group([
                SCNAction.moveBy(x: 0, y: 1.5, z: 0, duration: 1.2),
                SCNAction.fadeOut(duration: 1.2),
            ]),
            SCNAction.removeFromParentNode(),
        ])
        n.runAction(action)
    }
}
