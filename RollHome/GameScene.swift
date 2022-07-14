//
//  GameScene.swift
//  SchoolhouseSkateboarder
//
//  Created by a96 on 26/01/2020.
//  Copyright © 2020 Tony R Inc. All rights reserved.
//

import SpriteKit
import GameplayKit

/// Эта структура содержит различные физические категории, и мы можем определить,
/// какие типы объектов сталкиваются или контактируют друг с другом
    struct PhysicsCategory {
    static let skater: UInt32 = 0x1 << 0
    static let brick: UInt32 = 0x1 << 1
    static let gem: UInt32 = 0x1 << 2
    static let house: UInt32 = 0x1 << 3
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    // Enum (перечисление) для положения секции по y
    // Секции на земле низкие, а секции на верхней платформе высокие
    enum BrickLevel: CGFloat {
        case low = 0.0
        case high = 100.0
        case higherThanLow = 10.0
        case higher = 110.0
    }
    
    // Этот enum определяет состояния, в которых может находиться игра
    enum GameState {
        case notRunning
        case running
        case paused
    }
    
    // Массив, содержащий все текущие секции тротуара
    var bricks = [SKSpriteNode]()
    
    // Массив,содержащий все активные алмазы
    var gems = [SKSpriteNode]()
    
    // Размер секций на тротуаре
    var brickSize = CGSize.zero
    
    // Текущий уровень определяет положение по оси y для новых секций
    var brickLevel = BrickLevel.low
    
    var numberOfBricks: Int = 0 //Количество секций между разрывами, или изменением уровня
    
    // Отслеживаем текущее состояние игры
    var gameState = GameState.notRunning
    
    // Настройка скорости движения направо для игры
    // Это значение может увеличиваться по мере продвижения пользователя в игре
    var scrollSpeed: CGFloat = 5.0
    
    let startingScrollSpeed: CGFloat = 5.0
    
    // Константа для гравитации (того, как быстро объекты падают на Землю)
    let gravitySpeed: CGFloat = 1.5
    
    // Свойства для отслеживания результата
    var score: Int = 0
    var highScore: Int = 0
    var lastScoreUpdateTime: TimeInterval = 0.0
    
    var lastOffsetUpdateTime: TimeInterval = 0.0
    
    // Время последнего вызова для метода обновления
    var lastUpdateTime: TimeInterval?
    
    // Здесь мы создаем героя игры - скейтбордистку
    let skater = Skater(imageNamed: "skater")
    
    //Создаем изменяющийся фон
    var background: SKSpriteNode!
    
    //Создаем номер места действия. От него зависит внешний вид фона и секций
    var placeNumber: Int = 1
    
    //Создаем дом – финиш
    let house = SKSpriteNode(imageNamed: "house")
    
    //Размер дома (для правильного отображения на тротуаре)
    var houseSize = CGSize.zero
    
    //Переменная для создания только 1 дома
    var houseSpawned = false
    
    //Переменная для определения того, когда скейтер доедет до дома
    var skaterAtHome = false
    
    //Создаем изменяющуюся фоновую музыку
    var backgroundMusic: SKAudioNode!
    
    override func didMove(to view: SKView) { //Функция изначальной настройки
        // Get label node from scene and store it for use later
        
        physicsWorld.gravity = CGVector(dx: 0.0, dy: -6.0)
        
        physicsWorld.contactDelegate = self
        
        anchorPoint = CGPoint.zero //Задаем точку привязки в левом нижнем углу (0, 0)
        
        background = SKSpriteNode(imageNamed: "background0")
        let xMid = frame.midX
        let yMid = frame.midY
        background.position = CGPoint(x: xMid, y: yMid)
        addChild(background)
        
        setupLabels()
        
        // Настраиваем свойства скейтбордистки и добавляем ее к сцене
        skater.setupPhysicsBody()
        addChild(skater)
        
        //Обновляем свойство HouseSize реальным значением размера дома
        houseSize = house.size
        
        // Добавляем распознаватель нажатия, чтобы знать, когда пользователь нажимает на экран
        let tapMethod = #selector(GameScene.handleTap(tapGesture:))
        let tapGesture = UITapGestureRecognizer(target: self, action: tapMethod)
        view.addGestureRecognizer(tapGesture)
        
        //Добавляем 2-й распознаватель нажатия, чтобы знать, когда пользователь нажимает на экран двумя пальцами
        let twoFingersTapMethod = #selector(GameScene.handleTwoFingersTap(tapGesture:))
        let twoFingersTapGesture = UITapGestureRecognizer(target: self, action: twoFingersTapMethod)
        twoFingersTapGesture.numberOfTouchesRequired = 2
        view.addGestureRecognizer(twoFingersTapGesture)
        
        //Добавляем 3-й распознаватель нажатия, чтобы знать, когда пользователь делает свайп по экрану (влево и вправо)
        let swipeLeftGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(swipeGesture:)))
        let swipeRightGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(swipeGesture:)))
        swipeLeftGesture.direction = UISwipeGestureRecognizer.Direction.left
        swipeRightGesture.direction = UISwipeGestureRecognizer.Direction.right
        view.addGestureRecognizer(swipeLeftGesture)
        view.addGestureRecognizer(swipeRightGesture)
        
        // Добавляем слой меню с текстом "Нажмите, чтобы играть"
        let menuBackgroundColor = UIColor.black.withAlphaComponent(0.4)
        let menuLayer = MenuLayer(color: menuBackgroundColor, size: frame.size)
        menuLayer.anchorPoint = CGPoint(x: 0.0, y: 0.0)
        menuLayer.position = CGPoint(x: 0.0, y: 0.0)
        menuLayer.zPosition = 30
        menuLayer.name = "menuLayer"
        menuLayer.display(message: "Нажми, чтобы играть", score: nil)
        addChild(menuLayer)
    }
    
    func resetSkater() {
        // Задаем начальное положение скейтбордистки, zPosition и minimumY
        let skaterX = frame.midX / 2.0
        let skaterY = skater.frame.height / 2.0 + 64.0
        skater.position = CGPoint(x: skaterX, y: skaterY)
        skater.zPosition = 10
        skater.minimumY = skaterY
        
        skater.zRotation = 0.0
        skater.physicsBody?.velocity = CGVector(dx: 0.0, dy: 0.0)
        skater.physicsBody?.angularVelocity = 0.0
    }
    
    func setupLabels() {
        // Надпись со словами "очки" в верхнем левом углу
        let scoreTextLabel: SKLabelNode = SKLabelNode(text: "очки")
        scoreTextLabel.position = CGPoint(x: 14.0, y: frame.size.height - 20.0)
        scoreTextLabel.horizontalAlignmentMode = .left
        
        scoreTextLabel.fontName = "Courier-Bold"
        scoreTextLabel.fontSize = 14.0
        scoreTextLabel.zPosition = 20
        addChild(scoreTextLabel)
        
        // Надпись с количеством очков игрока в текущей игре
        let scoreLabel: SKLabelNode = SKLabelNode(text: "0")
        scoreLabel.position = CGPoint(x: 14.0, y: frame.size.height - 40.0)
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.fontName = "Courier-Bold"
        scoreLabel.fontSize = 18.0
        scoreLabel.name = "scoreLabel"
        scoreLabel.zPosition = 20
        addChild(scoreLabel)
        
        // Надпись "лучший результат" в правом верхнем углу
        let highScoreTextLabel: SKLabelNode = SKLabelNode(text: "лучший результат")
        highScoreTextLabel.position = CGPoint(x: frame.size.width - 14.0, y: frame.size.height - 20.0)
        highScoreTextLabel.horizontalAlignmentMode = .right
        highScoreTextLabel.fontName = "Courier-Bold"
        highScoreTextLabel.fontSize = 14.0
        highScoreTextLabel.zPosition = 20
        addChild(highScoreTextLabel)
        
        // Надпись с максимумом набранных игроком очков
        let highScoreLabel: SKLabelNode = SKLabelNode(text: "0")
        highScoreLabel.position = CGPoint(x: frame.size.width - 14.0, y: frame.size.height - 40.0)
        highScoreLabel.horizontalAlignmentMode = .right
        highScoreLabel.fontName = "Courier-Bold"
        highScoreLabel.fontSize = 18.0
        highScoreLabel.name = "highScoreLabel"
        highScoreLabel.zPosition = 20
        addChild(highScoreLabel)
    }
    
    func updateScoreLabelText() {
        if let scoreLabel = childNode(withName: "scoreLabel") as? SKLabelNode {
            scoreLabel.text = String(format: "%04d", score)
        }
    }
    
    func updateHighScoreLabelText() {
        if let highScoreLabel = childNode(withName: "highScoreLabel") as? SKLabelNode {
            highScoreLabel.text = String(format: "%04d", highScore)
        }
    }
    
    func startGame() {
        // Возвращение к начальным условиям при запуске новой игры
        gameState = .running
        
        resetSkater()
        
        score = 0
        
        scrollSpeed = startingScrollSpeed
        
        brickLevel = .low
        
        lastUpdateTime = nil
        
        for brick in bricks {
            brick.removeFromParent()
        }
        bricks.removeAll(keepingCapacity: true)
        
        for gem in gems {
            removeGem(gem)
        }
        
        //Удаляем старый фон и создаем новый
        background.removeFromParent()
        
        placeNumber = 1
        
        background = SKSpriteNode(imageNamed: "background\(placeNumber)")
        let xMid = frame.midX
        let yMid = frame.midY
        background.position = CGPoint(x: xMid, y: yMid)
        addChild(background)
        
        //Удаляем дом
        house.removeFromParent()
        houseSpawned = false
        skaterAtHome = false
        
        //Добавляем случайную зацикленную фоновую музыку
        let randomNumber = arc4random_uniform(8)
        
        if let musicURL = Bundle.main.url(forResource: "background_music\(randomNumber + 1)", withExtension: "mp3") {
            backgroundMusic = SKAudioNode(url: musicURL)
            addChild(backgroundMusic)
        }
        
        run(SKAction.playSoundFileNamed("go.wav", waitForCompletion: false))
    }
    
    func pausedGame() {
        gameState = .paused
        
        backgroundMusic.run(SKAction.pause())
        
        // Добавляем слой меню с текстом "Нажмите, чтобы продолжить"
        let menuBackgroundColor = UIColor.black.withAlphaComponent(0.4)
        let menuLayer = MenuLayer(color: menuBackgroundColor, size: frame.size)
        menuLayer.anchorPoint = CGPoint(x: 0.0, y: 0.0)
        menuLayer.position = CGPoint(x: 0.0, y: 0.0)
        menuLayer.zPosition = 30
        menuLayer.name = "menuLayer"
        menuLayer.display(message: "Нажми, чтобы продолжить", score: nil)
        addChild(menuLayer)
    }
    
    func finishGame() {
        gameState = .paused
        
        backgroundMusic.run(SKAction.pause())
        
        //Удаляем старый фон и создаем новый
        background.removeFromParent()
        
        background = SKSpriteNode(imageNamed: "background5")
        let xMid = frame.midX
        let yMid = frame.midY
        background.position = CGPoint(x: xMid, y: yMid)
        addChild(background)
        
        //Проверяем, добился ли игрок нового рекорда
        if score > highScore {
            highScore = score
            updateHighScoreLabelText()
        }
        
        // Добавляем слой меню с текстом "Нажмите, чтобы продолжить"
        let menuBackgroundColor = UIColor.black.withAlphaComponent(0.4)
        let menuLayer = MenuLayer(color: menuBackgroundColor, size: frame.size)
        menuLayer.anchorPoint = CGPoint(x: 0.0, y: 0.0)
        menuLayer.position = CGPoint(x: 0.0, y: 0.0)
        menuLayer.zPosition = 30
        menuLayer.name = "menuLayer"
        menuLayer.display(message: "Нажми, чтобы продолжить", score: score)
        addChild(menuLayer)
    }
    
    func gameOver() {
        // По завершении игры проверяем, добился ли игрок нового рекорда
        gameState = .notRunning
        
        backgroundMusic.run(SKAction.stop())
        backgroundMusic.removeFromParent()
        
        if score > highScore {
            highScore = score
            updateHighScoreLabelText()
            
            run(SKAction.playSoundFileNamed("new_highscore.wav", waitForCompletion: false))
        }
        else {
            run(SKAction.playSoundFileNamed("game_over.wav", waitForCompletion: false))
        }
        
        // Показываем надпись "Игра окончена!"
        let menuBackgroundColor = UIColor.black.withAlphaComponent(0.4)
        let menuLayer = MenuLayer(color: menuBackgroundColor, size: frame.size)
        menuLayer.anchorPoint = CGPoint.zero
        menuLayer.position = CGPoint.zero
        menuLayer.zPosition = 30
        menuLayer.name = "menuLayer"
        menuLayer.display(message: "Игра окончена!", score: score)
        addChild(menuLayer)
    }
    
    func spawnBrick (atPosition position: CGPoint) -> SKSpriteNode {
        // Создаем спрайт секции и добавляем его к сцене
        let brick = SKSpriteNode(imageNamed: "sidewalk\(placeNumber)")
        brick.position = position
        brick.zPosition = 8
        addChild(brick)
        
        // Обновляем свойство brickSize реальным значением размера секции
        brickSize = brick.size
        
        // Добавляем новую секцию к массиву
        bricks.append(brick)
        
        // Настройка физического тела секции
        let center = brick.centerRect.origin
        brick.physicsBody = SKPhysicsBody(rectangleOf: brick.size, center: center)
        brick.physicsBody?.affectedByGravity = false
        
        brick.physicsBody?.categoryBitMask = PhysicsCategory.brick
        brick.physicsBody?.collisionBitMask = 0
        
        // Возвращаем новую секцию вызывающему коду
        return brick
    }
    
    func spawnGem(atPosition position: CGPoint) {
        // Создаем спрайт для алмаза и добавляем его к сцене
        let gem = SKSpriteNode(imageNamed: "gem")
        gem.position = position
        gem.zPosition = 9
        addChild(gem)
        gem.physicsBody = SKPhysicsBody(rectangleOf: gem.size, center: gem.centerRect.origin)
        gem.physicsBody?.categoryBitMask = PhysicsCategory.gem
        gem.physicsBody?.affectedByGravity = false
        
        // Добавляем новый алмаз к массиву
        gems.append(gem)
    }
    
    func spawnHouse(atPosition position: CGPoint) {
        //Добавляем спрайт дома его к сцене
        house.position = position
        house.zPosition = 7
        addChild(house)
        
        //Настройка физического тела дома
        house.physicsBody = SKPhysicsBody(rectangleOf: house.size, center: house.centerRect.origin)
        house.physicsBody?.affectedByGravity = false

        house.physicsBody?.categoryBitMask = PhysicsCategory.house
        house.physicsBody?.collisionBitMask = 0
    }
    
    func removeGem(_ gem: SKSpriteNode) {
        gem.removeFromParent()
        
        if let gemIndex = gems.index(of: gem) {
            gems.remove(at: gemIndex)
        }
    }
    
    func updateBricks(withScrollAmount currentScrollAmount: CGFloat) {
        // Отслеживаем самое большое значение по оси x для всех существующих секций
        var farthestRightBrickX: CGFloat = 0.0
        
        for brick in bricks {
            let newX = brick.position.x - currentScrollAmount
            
            // Если секция сместилась слишком далеко влево (за пределы экрана), удалите ее
            if newX < -brickSize.width {
            
                brick.removeFromParent()
            
                if let brickIndex = bricks.index(of: brick) {
                    bricks.remove(at: brickIndex)
                    }
                
            } else {
                // Для секции, оставшейся на экране, обновляем положение
                brick.position = CGPoint(x: newX, y: brick.position.y)
                
                //Обновляем значение для крайней правой секции
                if brick.position.x > farthestRightBrickX {
                    farthestRightBrickX = brick.position.x
                    }
            }
        }
        
        //Задаем положение дома и вызываем функцию его создания
        //после того, как скорость движения игры достигла 15.0; кол-во секций между разрывом, или изменением уровня стало достаточным; уровень секции стал низким; и если дом еще не был создан
        if scrollSpeed > 15 && numberOfBricks >= Int(2 * scrollSpeed) && brickLevel == .low && houseSpawned == false {
            let houseX = farthestRightBrickX + houseSize.width + 1.0
            let houseY = brickSize.height + (houseSize.height / 2.0) + brickLevel.rawValue
            
            spawnHouse(atPosition: CGPoint(x: houseX, y: houseY))
            
            houseSpawned = true
            
            numberOfBricks = 0 //Обнуляем кол-во секций, чтобы дом не стоял на разрыве, или перед изменением уровня
        }
        
        // Цикл while, обеспечивающий постоянное наполнение экрана секциями
        while farthestRightBrickX < frame.width {
            var brickX = farthestRightBrickX + brickSize.width + 1.0
            
            var brickY = (brickSize.height / 2.0) + brickLevel.rawValue

            //Если ступенька началась, то нужно вернуть уровень секции Y к норм. значению, чтобы ее завершить
            if brickLevel == .higher {
                brickLevel = .high
            }
            else if brickLevel == .higherThanLow {
                brickLevel = .low
            }
            
            // Время от времени мы оставляем разрывы, через которые герой должен перепрыгнуть
            let randomNumber = arc4random_uniform(100)
            
            if randomNumber < 2 && score > 10 && numberOfBricks >= Int(2 * scrollSpeed) {
                // 2-процентный шанс на то, что у нас возникнет разрыв между
                // секциями после того, как игрок набрал 10 призовых очков //, и кол-во секций между разрывом, или изменением уровня стало достаточным
                let gap = 28.0 * scrollSpeed
                brickX += gap
                
                // На каждом разрыве добавляем алмаз
                let randomGemYAmount = CGFloat(arc4random_uniform(150))
                let newGemY = brickY + skater.size.height + randomGemYAmount
                let newGemX = brickX - gap / 2.0
                spawnGem(atPosition: CGPoint(x: newGemX, y: newGemY))
                
                numberOfBricks = 0 //Обнуляем кол-во секций, т.к. произошел разрыв
            }
            
            else if randomNumber < 4 && score > 50 && numberOfBricks >= Int(2 * scrollSpeed) {
                // 2-процентный шанс на то, что уровень секции Y изменится
                // после того, как игрок набрал 50 призовых очков //, и кол-во секций между разрывом, или изменением уровня стало достаточным
                if brickLevel == .high {
                    brickLevel = .low
                }
                else if brickLevel == .low {
                    brickLevel = .high
                }
                
                numberOfBricks = 0 //Обнуляем кол-во секций, т.к. произошло изменение уровня
            }
            
            else if randomNumber < 6 && score > 100 && numberOfBricks >= Int(2 * scrollSpeed) {
                //2-процентный шанс на то, что у нас возникнет разрыв между
                //секциями и уровень секции Y изменится
                //после того, как игрок набрал 100 призовых очков //, и кол-во секций между разрывом, или изменением уровня стало достаточным
                let gap = 20.0 * scrollSpeed
                brickX += gap
                
                // На каждом разрыве добавляем алмаз
                let randomGemYAmount = CGFloat(arc4random_uniform(150))
                let newGemY = brickY + skater.size.height + randomGemYAmount
                let newGemX = brickX - gap / 2.0
                spawnGem(atPosition: CGPoint(x: newGemX, y: newGemY))
                
                
                if brickLevel == .high {
                    brickLevel = .low
                }
                else if brickLevel == .low {
                    brickLevel = .high
                }
                
                //Между разрывом и изменением уровня секции Y остается 1 секция на прежнем уровне "___   _---", "---   -___".
                //50%-й шанс на то, что ее не будет "___   ----", "---   ____"
                if randomNumber == 5 {
                    brickY = (brickSize.height / 2.0) + brickLevel.rawValue
                }
                
                numberOfBricks = 0 //Обнуляем кол-во секций, т.к. произошло изменение уровня
            }
            
            else if randomNumber < 8 && score > 10 && numberOfBricks >= Int(2 * scrollSpeed) {
                //2-процентный шанс на то, что у нас возникнет пробел между
                //секциями после того, как игрок набрал 10 призовых очков //, и кол-во секций между разрывом, или изменением уровня стало достаточным
                let gap = brickSize.width
                brickX += gap
                
                // На каждом разрыве добавляем алмаз
                let randomGemYAmount = CGFloat(arc4random_uniform(150))
                let newGemY = brickY + skater.size.height + randomGemYAmount
                let newGemX = brickX - gap / 2.0
                spawnGem(atPosition: CGPoint(x: newGemX, y: newGemY))
                
                //Не обнуляем кол-во секций, т.к. через пробел можно переехать
            }
            
            else if randomNumber < 10 && score > 10 && numberOfBricks >= Int(2 * scrollSpeed) {
                //2-процентный шанс на то, что у нас начнется ступенька
                //после того, как игрок набрал 10 призовых очков //, и кол-во секций между разрывом, или изменением уровня стало достаточным
                if brickLevel == .high {
                    brickLevel = .higher
                }
                else if brickLevel == .low {
                    brickLevel = .higherThanLow
                }
                
                //Не обнуляем кол-во секций, т.к. через ступеньку можно переехать
            }
            
            // Добавляем новую секцию и обновляем положение самой правой
            let newBrick = spawnBrick(atPosition: CGPoint(x: brickX, y: brickY))
                farthestRightBrickX = newBrick.position.x
            
            numberOfBricks += 1 //+1 к кол-ву секций
        }
    }
    
    func updateGems(withScrollAmount currentScrollAmount: CGFloat) {
        for gem in gems {
            // Обновляем положение каждого алмаза
            let thisGemX = gem.position.x - currentScrollAmount
            gem.position = CGPoint(x: thisGemX, y: gem.position.y)
            
            // Удаляем любые алмазы, ушедшие с экрана
            if gem.position.x < 0.0 {
                removeGem(gem)
            }
        }
    }
    
    func updateSkater(withCurrentTime currentTime: TimeInterval) {
        // Определяем, находится ли скейтбордистка на земле
        if let velocityY = skater.physicsBody?.velocity.dy {
            if velocityY < -100.0 || velocityY > 100.0 {
                skater.isOnGround = false
            }
        }
        
        // Проверяем, должна ли игра закончиться
        let isOffScreen = skater.position.y < 0.0 || skater.position.x < 0.0
        
        let maxRotation = CGFloat(GLKMathDegreesToRadians(85.0))
        let isTippedOver = skater.zRotation > maxRotation || skater.zRotation < -maxRotation
        
        if isOffScreen || isTippedOver {
            gameOver()
        }
        
        //Величина смещения скейтера изменяется по мере задевания им секций, за счет прыжков и приземлений
        //Излишнее смещение компенсируется импульсом каждую десятую долю секунды
        let elapsedTime = currentTime - lastOffsetUpdateTime
        
        if elapsedTime > 0.1 {
            let offset = skater.position.x - frame.midX / 2.0
            
            //Если скейтер слишком сместился влево
            if offset < -10 {
                //Добавляем компенсирующий положит. импульс по X
                skater.physicsBody?.applyImpulse(CGVector(dx: 1.0, dy: 0.0))
            }
            //Если скейтер слишком сместился вправо
            else if offset > 10 {
                //Добавляем компенсирующий отриц. импульс по X
                skater.physicsBody?.applyImpulse(CGVector(dx: -1.0, dy: 0.0))
            }
            
            //Присваиваем свойству lastOffsetUpdateTime значение текущего времени
            lastOffsetUpdateTime = currentTime
        }
    }
    
    func updateScore(withCurrentTime currentTime: TimeInterval) {
        // Количество очков игрока увеличивается по мере игры
        // Счет обновляется каждую секунду
        let elapsedTime = currentTime - lastScoreUpdateTime
        
        if elapsedTime > 1.0 {
            // Увеличиваем количество очков
            score += Int(scrollSpeed)
            
            // Присваиваем свойству lastScoreUpdateTime значение текущего времени
            lastScoreUpdateTime = currentTime
            updateScoreLabelText()
        }
    }
    
    func updatePlace() {
        if scrollSpeed > 7.5 && placeNumber == 1 || scrollSpeed > 10 && placeNumber == 2 || scrollSpeed > 12.5 && placeNumber == 3  {
            //Анимируем движение старого фона за левый край экрана
            var finalX = -frame.midX
            var moveToAction = SKAction.moveTo(x: finalX, duration: TimeInterval(11.2 / scrollSpeed))
            background.run(moveToAction)
            
            //Ждем окончания анимации, а затем удаляем старый фон
            var waitAction = SKAction.wait(forDuration: TimeInterval(11.2 / scrollSpeed))
            let removeAction = SKAction.removeFromParent()
            let waitThenRemove = SKAction.sequence([waitAction, removeAction])
            background.run(waitThenRemove)
            
            //Создаем новый фон
            placeNumber += 1
            
            background = SKSpriteNode(imageNamed: "background\(placeNumber)")
            let xMid = 3 * frame.midX
            let yMid = frame.midY
            background.position = CGPoint(x: xMid, y: yMid)
            addChild(background)
            
            //Анимируем движение нового фона из-за правого края к центру экрана
            finalX = frame.midX
            moveToAction = SKAction.moveTo(x: finalX, duration: TimeInterval(11.2 / scrollSpeed))
            background.run(moveToAction)
            
            //Уменьшаем громкость фоновой музыки на момент воспроизведения фразы
            let changeAction = SKAction.changeVolume(by: -0.5, duration: 0)
            waitAction = SKAction.wait(forDuration: 0.5)
            let returnAction = SKAction.changeVolume(by: 0.5, duration: 0)
            let changeWaitReturn = SKAction.sequence([changeAction, waitAction, returnAction])
            backgroundMusic.run(changeWaitReturn)
            
            run(SKAction.playSoundFileNamed("hurry_up.wav", waitForCompletion: false))
        }
    }
    
    func updateHouse(withScrollAmount currentScrollAmount: CGFloat) {
        //Обновляем положение дома
        let thisHouseX = house.position.x - currentScrollAmount
        house.position = CGPoint(x: thisHouseX, y: house.position.y)

        //Удаляем дом, ушедший с экрана
        if house.position.x < -(houseSize.width / 2.0) {
            house.removeFromParent()
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered (вызывается перед отрисовкой каждого кадра)
        
        //Ограничение скейтера по углу наклона
        if skater.zRotation < CGFloat(GLKMathDegreesToRadians(-35.0)) {
            skater.zRotation = CGFloat(GLKMathDegreesToRadians(-35.0))
        }
        else if skater.zRotation > CGFloat(GLKMathDegreesToRadians(30.0)) {
            skater.zRotation = CGFloat(GLKMathDegreesToRadians(30.0))
        }
        
        if gameState != .running {
               return
        }
        
        // Медленно увеличиваем значение scrollSpeed по мере развития игры
        scrollSpeed += 0.001
        
        // Определяем время, прошедшее с момента последнего вызова update
        var elapsedTime: TimeInterval = 0.0
        if let lastTimeStamp = lastUpdateTime {
            elapsedTime = currentTime - lastTimeStamp
        }
        
        lastUpdateTime = currentTime
        
        let expectedElapsedTime: TimeInterval = 1.0 / 60.0
        
        // Рассчитываем, насколько далеко должны сдвинуться объекты при данном обновлении
        let scrollAdjustment = CGFloat(elapsedTime / expectedElapsedTime)
        let currentScrollAmount = scrollSpeed * scrollAdjustment
        
        updateBricks(withScrollAmount: currentScrollAmount)
        
        updateSkater(withCurrentTime: currentTime)
        
        updateGems(withScrollAmount: currentScrollAmount)
        
        updateScore(withCurrentTime: currentTime)
        
        updatePlace()
        
        updateHouse(withScrollAmount: currentScrollAmount)
    }
    
    @objc func handleTap(tapGesture: UITapGestureRecognizer) {
        if gameState == .running {
            
            // Заставляем скейтбордистку прыгнуть нажатием на экран, пока она находится на земле
            if skater.isOnGround {
                skater.physicsBody?.applyImpulse(CGVector(dx: 0.0, dy: 260.0))
                
                run(SKAction.playSoundFileNamed("jump.wav", waitForCompletion: false))
            }
            
        } else if gameState == .notRunning {
            // Если игра не запущена, нажатие на экран запускает новую игру
            if let menuLayer: SKSpriteNode = childNode(withName: "menuLayer") as? SKSpriteNode {
                menuLayer.removeFromParent()
            }
            
            startGame()
        } else {
            //Если игра на паузе, нажатие на экран продолжает игру
            if let menuLayer: SKSpriteNode = childNode(withName: "menuLayer") as? SKSpriteNode {
                menuLayer.removeFromParent()
            }
            
            if skaterAtHome == true {
                //Удаляем старый фон и создаем новый
                background.removeFromParent()
                
                background = SKSpriteNode(imageNamed: "background\(placeNumber)")
                let xMid = frame.midX
                let yMid = frame.midY
                background.position = CGPoint(x: xMid, y: yMid)
                addChild(background)
            }
            
            gameState = .running
            lastUpdateTime = nil
            
            backgroundMusic.run(SKAction.play())
        }
    }
    
    @objc func handleTwoFingersTap(tapGesture: UITapGestureRecognizer) {
        if gameState == .running {
            //Ставим игру на паузу нажатием двумя пальцами на экран
            pausedGame()
        }
    }
    
    @objc func handleSwipe(swipeGesture: UISwipeGestureRecognizer) {
        if swipeGesture.direction == UISwipeGestureRecognizer.Direction.left {
            
        } else if swipeGesture.direction == UISwipeGestureRecognizer.Direction.right {
            
        }
    }
    
    // MARK:- SKPhysicsContactDelegate Methods
    func didBegin(_ contact: SKPhysicsContact) {
        // Проверяем, есть ли контакт между скейтбордисткой и секцией
        if contact.bodyA.categoryBitMask == PhysicsCategory.skater && contact.bodyB.categoryBitMask == PhysicsCategory.brick {
            
            if let velocityY = skater.physicsBody?.velocity.dy {
                if !skater.isOnGround && velocityY < 100.0 {
                    skater.createSparks()
                    
                    let randomNumber = arc4random_uniform(3)
                    
                    run(SKAction.playSoundFileNamed("land\(randomNumber + 1)", waitForCompletion: false))
                }
            }
            
            skater.isOnGround = true
        }
        
        else if contact.bodyA.categoryBitMask == PhysicsCategory.skater && contact.bodyB.categoryBitMask == PhysicsCategory.gem {
               
            // Скейтбордистка коснулась алмаза, поэтому мы его убираем
            if let gem = contact.bodyB.node as? SKSpriteNode {
                removeGem(gem)
                
                // Даем игроку 50 очков за собранный алмаз
                score += 50
                updateScoreLabelText()
                
                run(SKAction.playSoundFileNamed("gem.wav", waitForCompletion: false))
            }
        }
        
        else if contact.bodyA.categoryBitMask == PhysicsCategory.skater && contact.bodyB.categoryBitMask == PhysicsCategory.house && skaterAtHome == false {
               
            // Скейтбордистка коснулась дома, поэтому
            if let house = contact.bodyB.node as? SKSpriteNode {
                finishGame()
                
                skaterAtHome = true
                
                run(SKAction.playSoundFileNamed("congratulations.wav", waitForCompletion: false))
            }
        }
    }
}
