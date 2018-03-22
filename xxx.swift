import SpriteKit
import GameplayKit

/// 游戏状态
enum GameStatus {
   case idle /// 初始化
   case running /// 游戏运行中
   case over /// 游戏结束
}

class GameScene: SKScene,SKPhysicsContactDelegate {
   
   /// 背景色
   var skyColor:SKColor!
   /// 小鸟精灵
   var bird :SKSpriteNode!
   /// 竖直管缺口
   let verticalPipeGap = 120.0;
   /// 向上管纹理
   var pipeTextureUp:SKTexture!
   /// 向下管纹理
   var pipeTextureDown:SKTexture!
   /// 储存陆地、天空和管道
   var moving:SKNode!
   /// 储存所有上下管道
   var pipes:SKNode!
   /// 游戏状态为初始状态
   var gameStatus:GameStatus = .idle
   /// 储存计分板视图
   var scoreCards:SKNode!
   /// 储存玩法帮助图
   var tutorials:SKNode!
   /// 分数
   var score: NSInteger = 0
   ///分数Label
   lazy var scoreLabelNode:SKLabelNode = {
       let label = SKLabelNode(fontNamed: "MarkerFelt-Wide")
       label.zPosition = 100
       label.text = "0"
       return label
   }()
   
   /// 设置物理体的标示符  <<左移运算符  左移一位，相当于扩大2倍
   let birdCategory: UInt32 = 1 << 0  //1
   let worldCategory: UInt32 = 1 << 1  //2
   let pipeCategory: UInt32 = 1 << 2  //4
   let scoreCategory: UInt32 = 1 << 3  //8
   
   override func didMove(to view: SKView) {
       
       skyColor = SKColor(red: 81.0/255.0, green: 192.0/255.0, blue: 201.0/255.0, alpha: 1.0)
       self.backgroundColor = skyColor
       //给场景添加一个物理体，限制了游戏范围
       self.physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)
       //物理世界的碰撞检测代理为场景自己
       self.physicsWorld.contactDelegate = self;
       //设置重力
       self.physicsWorld.gravity = CGVector(dx: 0.0, dy: -2.0)
       
       moving = SKNode()
       self.addChild(moving)
       pipes = SKNode()
       moving.addChild(pipes)
       scoreCards = SKNode()
       self.addChild(scoreCards)
       tutorials = SKNode()
       self.addChild(tutorials)
       
       // 地面
       let groundTexture = SKTexture(imageNamed: "floor")
       groundTexture.size()
       groundTexture.filteringMode = .linear
       for i in 0..<2 + Int(self.frame.size.width / (groundTexture.size().width)) {
           let i = CGFloat(i)
           let sprite = SKSpriteNode(texture: groundTexture)
           sprite.zPosition = -5
           // SKSpriteNode的默认锚点为(0.5,0.5)即它的中心点。
           sprite.anchorPoint = CGPoint(x: 0, y: 0)
           sprite.position = CGPoint(x: i * sprite.size.width, y: 0)
           self.moveGround(sprite: sprite, timer: 0.02)
           moving.addChild(sprite)
       }
       
       // 配置陆地物理体
       let ground = SKNode()
       ground.position = CGPoint(x: 0, y: groundTexture.size().height/2)
       ground.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: self.frame.size.width, height: groundTexture.size().height))
       ground.physicsBody?.isDynamic = false
       ground.physicsBody?.categoryBitMask = worldCategory
       self.addChild(ground)
       
       // 天空
       let skyTexture = SKTexture(imageNamed: "back")
       skyTexture.filteringMode = .nearest
       for i in 0..<2 + Int(self.frame.size.width / (skyTexture.size().width)) {
           let i = CGFloat(i)
           let sprite = SKSpriteNode(texture: skyTexture)
           // zPosition越大就越靠近玩家 zPosition默认值是0
           sprite.zPosition = -20
           sprite.anchorPoint = CGPoint(x: 0, y:0)
           sprite.position = CGPoint(x: i * sprite.size.width, y:groundTexture.size().height)
           self.moveGround(sprite: sprite, timer: 0.1)
           moving.addChild(sprite)
       }
       
       // 小鸟
       bird = SKSpriteNode(imageNamed: "bird_1")
       addChild(bird)
       
       // 配置小鸟物理体
       bird.physicsBody = SKPhysicsBody(circleOfRadius: bird.size.height / 2.0)
//        bird.physicsBody = SKPhysicsBody(texture: bird.texture!, size: bird.size)
       bird.physicsBody?.allowsRotation = false
       bird.physicsBody?.categoryBitMask = birdCategory
       bird.physicsBody?.contactTestBitMask = worldCategory | pipeCategory
       
       self.idleStatus()
       
   }
   func idleStatus() {
       gameStatus = .idle
       
       removeAllPipesNode()
       removeScoreCard()
       
       bird.position = CGPoint(x: self.frame.size.width * 0.32, y: self.frame.size.height * 0.55)
       // isDynamic的作用是设置这个物理体当前是否会受到物理环境的影响，默认是true
       bird.physicsBody?.isDynamic = false
       self.birdStartFly()
       
       setupTutorial()
       // 重新开始动画
       moving.speed = 1
   }
   func runningStatus() {
       gameStatus = .running
       
       removeTutorial()
       
       // 重设分数
       score = 0
       scoreLabelNode.text = String(score)
       self.addChild(scoreLabelNode)
       scoreLabelNode.position = CGPoint(x: self.frame.midX, y: 3 * self.frame.size.height / 4)
       
       bird.physicsBody?.isDynamic = true
       bird.physicsBody?.collisionBitMask = worldCategory | pipeCategory
       
       startCreateRandomPipes()
   }
   func overStatus() {
       gameStatus = .over
       
       birdStopFly()
       
       stopCreateRandomPipes()
       // 移除分数提示
       scoreLabelNode.removeFromParent()
       
       bgFlash()
       
       setupScoreCard()
   }
   
   override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
       switch gameStatus {
       case .idle:
           runningStatus()
           
           break
       case .running:
           for _ in touches {
               self.run(SKAction.playSoundFileNamed("flap.wav", waitForCompletion: false))
               
               bird.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
               // 施加一个均匀作用于物理体的推力
               bird.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 4))
           }
           break
           
       case .over:
           /// 防按钮事件
           for touch in touches{
               let location = touch.location(in: self)
               for node in nodes(at:location){
                   if node.name == "ok"{
                       
                       idleStatus()
                   }
               }
           }
           break
      }
   }
   
   /// SKPhysicsContact对象是包含着碰撞的两个物理体的,分别是bodyA和bodyB
   ///
   /// - Parameter contact: SKPhysicsContact
   func didBegin(_ contact: SKPhysicsContact) {
       
       if gameStatus != .running {
           return
       }
       // 如果通过分数区域 按位与运算 4&5的值为4。这里4的二进制是“100”，5的二进制是“101” 按位与就是100&101=100（即十进制为4）
       if (contact.bodyA.categoryBitMask & scoreCategory) == scoreCategory || (contact.bodyB.categoryBitMask & scoreCategory) == scoreCategory {
           self.run(SKAction.playSoundFileNamed("point.mp3", waitForCompletion: false))
           score += 1
           scoreLabelNode.text = String(score)
           
           scoreLabelNode.run(SKAction.sequence([SKAction.scale(to: 1.5, duration: TimeInterval(0.1)),SKAction.scale(to: 1.0, duration: TimeInterval(0.1))]))
       }else{
           self.run(SKAction.playSoundFileNamed("punch.wav", waitForCompletion: false))
           
           moving.speed = 0
           bird.physicsBody?.collisionBitMask = worldCategory
           //碰撞翻转
//            bird.run(SKAction.rotate(byAngle: .pi * CGFloat(bird.position.y) * 0.01, duration: 1))
           
           overStatus()
       }
   }
   /// 背景闪光
   func bgFlash() {
       let bgFlash = SKAction.run({
           self.backgroundColor = SKColor(red: 1, green: 0, blue: 0, alpha: 1.0)}
       )
       let bgNormal = SKAction.run({
           self.backgroundColor = self.skyColor;
       })
       let bgFlashAndNormal = SKAction.sequence([bgFlash,SKAction.wait(forDuration: (0.05)),bgNormal,SKAction.wait(forDuration: (0.05))])
       self.run(SKAction.sequence([SKAction.repeat(bgFlashAndNormal, count: 4)]), withKey: "falsh")
       self.removeAction(forKey: "flash")
   }
   //陆地移动动画
   func moveGround(sprite:SKSpriteNode,timer:CGFloat) {
       let moveGroupSprite = SKAction.moveBy(x: -sprite.size.width, y: 0, duration: TimeInterval(timer * sprite.size.width))
       let resetGroupSprite = SKAction.moveBy(x: sprite.size.width, y: 0, duration: 0.0)
       //永远移动 组动作
       let moveGroundSpritesForever = SKAction.repeatForever(SKAction.sequence([moveGroupSprite,resetGroupSprite]))
       sprite.run(moveGroundSpritesForever)
   }
   
   ///  小鸟飞的动画
   func birdStartFly()  {
       let birdTexture1 = SKTexture(imageNamed: "bird_1")
       birdTexture1.filteringMode = .nearest
       let birdTexture2 = SKTexture(imageNamed: "bird_2")
       birdTexture2.filteringMode = .nearest
       let birdTexture3 = SKTexture(imageNamed: "bird_3")
       birdTexture3.filteringMode = .nearest
       let anim = SKAction.animate(with: [birdTexture1,birdTexture2,birdTexture3], timePerFrame: 0.2)
       bird.run(SKAction.repeatForever(anim), withKey: "fly")
   }
   ///  小鸟停止飞动画
   func birdStopFly()  {
       bird.removeAction(forKey: "fly")
   }
   
   /// 随机 创建
   func startCreateRandomPipes() {
       let spawn = SKAction.run {
           self.creatSpawnPipes()
       }
       let delay = SKAction.wait(forDuration: TimeInterval(2.0))
       let spawnThenDelay = SKAction.sequence([spawn,delay])
       let spawnThenDelayForever = SKAction.repeatForever(spawnThenDelay)
       self.run(spawnThenDelayForever, withKey: "createPipe")
   }
   ///停止创建管道
   func stopCreateRandomPipes() {
       self.removeAction(forKey: "createPipe")
   }
   /// 移除所有已经存在的上下管
   func removeAllPipesNode() {
       pipes.removeAllChildren()
   }
   ///创建一对水管
   func creatSpawnPipes() {
       // 管道纹理
       pipeTextureUp = SKTexture(imageNamed: "pipe_bottom")
       pipeTextureUp.filteringMode = .nearest
       pipeTextureDown = SKTexture(imageNamed: "pipe_top")
       pipeTextureDown.filteringMode = .nearest
       
       let pipePair = SKNode()
       pipePair.position = CGPoint(x: self.frame.size.width + pipeTextureUp.size().width, y: 0)
       // z值的节点(用于排序)。负z是”进入“屏幕,正面z是“出去”屏幕。
       pipePair.zPosition = -10;
       
       // 随机的Y值
       let height = UInt32(self.frame.size.height / 4)
       let y = Double(arc4random_uniform(height))
       let pipeDown = SKSpriteNode(texture: pipeTextureDown)
       pipeDown.position = CGPoint(x: 0.0, y: y + Double(pipeDown.size.height)+verticalPipeGap)
       
       pipeDown.physicsBody = SKPhysicsBody(rectangleOf: pipeDown.size)
       pipeDown.physicsBody?.isDynamic = false
       pipeDown.physicsBody?.categoryBitMask = pipeCategory
       pipeDown.physicsBody?.contactTestBitMask = birdCategory
       pipePair.addChild(pipeDown)
       
       let pipeUp = SKSpriteNode(texture: pipeTextureUp)
       pipeUp.position = CGPoint(x: 0.0, y: y)
       pipeUp.physicsBody = SKPhysicsBody(rectangleOf: pipeUp.size)
       pipeUp.physicsBody?.isDynamic = false
       pipeUp.physicsBody?.categoryBitMask = pipeCategory
       pipeUp.physicsBody?.contactTestBitMask = birdCategory
       pipePair.addChild(pipeUp)
       
       let contactNode = SKNode()
       contactNode.position = CGPoint(x: pipeDown.size.width, y: self.frame.midY)
       contactNode.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: pipeUp.size.width, height: self.frame.size.height))
       contactNode.physicsBody?.isDynamic = false
       contactNode.physicsBody?.categoryBitMask = scoreCategory
       contactNode.physicsBody?.contactTestBitMask = birdCategory
       pipePair.addChild(contactNode)
       
       // 管道移动动作
       let distanceToMove = CGFloat(self.frame.size.width + pipeTextureUp.size().width)
       let movePipes = SKAction.moveBy(x: -distanceToMove, y: 0.0, duration: TimeInterval(0.01 * distanceToMove))
       let removePipes = SKAction.removeFromParent()
       let movePipesAndRemove = SKAction.sequence([movePipes,removePipes])
       pipePair.run(movePipesAndRemove)
       
       pipes.addChild(pipePair)
   }
   func setBestScore(score:Int) {
       UserDefaults.standard.set(score, forKey: "bestScore")
       UserDefaults.standard.synchronize()
   }
   func bestScore()->Int{
       return UserDefaults.standard.integer(forKey: "bestScore")
   }
   
   func setupScoreCard() {
       if score > bestScore() {
           setBestScore(score: score)
       }
       
       let whiteNode = SKSpriteNode(color: SKColor.white, size: size)
       whiteNode.alpha = 0
       whiteNode.zPosition = 100
       whiteNode.position = CGPoint(x: size.width/2, y: size.height/2)
       scoreCards.addChild(whiteNode)
       
       // 1 得分面板背景
       let scorecard = SKSpriteNode(imageNamed: "scoreCard")
       scorecard.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
       scorecard.name = "scorecard"
       scorecard.zPosition = 101
       scoreCards.addChild(scorecard)
       
       // 2 本次得分
       let lastScore = SKLabelNode(fontNamed: "MarkerFelt-Wide")
       lastScore.fontColor = SKColor.white
       lastScore.position = CGPoint(x: scorecard.size.width * 0.30, y:0)
       lastScore.text = String(score)
       lastScore.zPosition = 102
       scorecard.addChild(lastScore)
       
       // 3 最好成绩
       let bestScoreLabel = SKLabelNode(fontNamed: "MarkerFelt-Wide")
       bestScoreLabel.fontColor = SKColor.white
       bestScoreLabel.position = CGPoint(x: scorecard.size.width * 0.30, y: -scorecard.size.height * 0.32)
       bestScoreLabel.zPosition = 102
       bestScoreLabel.text = String(bestScore())
       scorecard.addChild(bestScoreLabel)
       
       // 4 游戏结束
       let gameOver = SKSpriteNode(imageNamed: "game_over")
       gameOver.position = CGPoint(x: size.width/2, y: size.height/2 + scorecard.size.height/2 + 50 + gameOver.size.height/2)
       gameOver.zPosition = 101
       scoreCards.addChild(gameOver)
       
       // 5 ok按钮背景以及ok标签
       let okButton = SKSpriteNode(imageNamed: "confirm")
       okButton.position = CGPoint(x: size.width * 0.5, y: size.height/2 - scorecard.size.height/2 - 50 - okButton.size.height/2)
       okButton.zPosition = 101
       // 作用于按钮事件
       okButton.name = "ok"
       scoreCards.addChild(okButton)
       
       //添加一个常量 用于定义动画时间
       let animDelay = 0.3

       let whiteNodeIn = SKAction.sequence([SKAction.wait(forDuration: 1.0),SKAction.fadeAlpha(to: 0.3, duration: 0.3)])
       whiteNode.run(whiteNodeIn)

       gameOver.setScale(0)
       let group = SKAction.scale(to: 1.0, duration: animDelay)
       group.timingMode = .linear
       gameOver.run(SKAction.sequence([SKAction.wait(forDuration: 1),group]))

       scorecard.position = CGPoint(x: size.width * 0.5, y: -scorecard.size.height/2)
       let moveTo = SKAction.moveTo(y: size.height/2, duration: animDelay)
       moveTo.timingMode = .linear
       scorecard.run(SKAction.sequence([SKAction.wait(forDuration: 1),moveTo]))

       okButton.position = CGPoint(x: size.width * 0.5, y: -scorecard.size.height - 50 - okButton.size.height/2)
       let moveTo2 = SKAction.moveTo(y:  size.height/2 - scorecard.size.height/2 - 50 - okButton.size.height/2, duration: animDelay)
       moveTo2.timingMode = .linear
       okButton.run(SKAction.sequence([SKAction.wait(forDuration: 1),moveTo2]))

   }
   /// 移除计分板
   func removeScoreCard() {
       scoreCards.removeAllChildren()
   }
   
   func setupTutorial() {
       
       let tutorial = SKSpriteNode(imageNamed: "taptap")
       tutorial.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
       tutorial.name = "Tutorial"
       tutorial.zPosition = 100
       tutorials.addChild(tutorial)
       
       let ready = SKSpriteNode(imageNamed: "get_ready")
       ready.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5 + 100)
       ready.name = "Tutorial"
       ready.zPosition = 100
       tutorials.addChild(ready)
   }

   /// 移除引导提示图
   func removeTutorial() {
       tutorials.removeAllChildren()
   }
   
   // update()方法为SKScene自带的系统方法，在画面每一帧刷新的时候就会调用一次
   override func update(_ currentTime: TimeInterval) {
       // 保持脸先着地
       
       let value = bird.physicsBody!.velocity.dy * (bird.physicsBody!.velocity.dy < 0 ? 0.003 : 0.001)
       
       bird.zRotation = min(max(-1, value),0.5)
       
   }
}