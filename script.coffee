window.onload = ->


  window.requestAnimationFrame = (->
    window.requestAnimationFrame ||
    window.webkitRequestAnimationFrame ||
    window.mozRequestAnimationFrame ||
    (callback) ->
      window.setTimeout callback, 1000 / 60
  )()


  introDOM = document.getElementById("intro")
  loadingDOM = document.getElementById("loading")

  introDOM.className = "active"

  document.addEventListener("keydown", userConfirmed = (e) ->
    if e.keyCode == 32
      document.removeEventListener "keydown", userConfirmed
      loadingDOM.className = "active"
      introDOM.className = ""
      requirements.load()
  , false)


  requirements =
    done: 0
    required: 2
    load: ->
      @done++
      startGame() if @done == @required

  imgRepo =
    images: []
    loaded: 0
    paths: [
      "images/bg-o.png"
      "images/bg2.png"
      "images/explosion.png"
      "images/explosion2.png"
      "images/sprite.png"
    ]

    loadImages:  ->
      for path, i in @paths
        img = new Image()
        @images.push {"path": path, "img": img}

        img.onload = =>
          @loaded++
          requirements.load() if @loaded == @paths.length
        img.src = @paths[i]

    get: (path) ->
      result = @images.filter (img) -> img.path == path
      result[0].img

  imgRepo.loadImages()


  soundRepo =
    shoot: new Howl
      urls: ['sounds/shoot.ogg', 'sounds/shoot.mp3']
      volume: 0.14

    explosion: new Howl
      urls: ['sounds/explosion.ogg', 'sounds/explosion.mp3']
      volume: 0.5

    background: new Howl
      urls: ['sounds/background.ogg', 'sounds/background.mp3']
      loop: true
      buffer: true
      volume: 0.7



  startGame = ->

    contDOM = document.getElementById("cont")
    infoOverDOM = document.getElementById("game_over")
    infoLevelupDOM = document.getElementById("levelup")
    livesDOM = document.getElementById("lives")
    levelDOM = document.getElementById("ingame_level")
    infoLevelDOM = document.getElementById("info_level")
    muteDOM = document.getElementById("mute")
    canvasDOM = document.getElementById("game_screen")

    canvas = canvasDOM.getContext("2d")

    startTime = Date.now()

    rand = (min, max) ->
      Math.floor(Math.random() * (max - min + 1)) + min

    game =
      width: 900
      height: 630
      level: 0
      lives: 3
      timeOfLastDeath: 0
      deltaLastTime: 0
      paused: levelup: false, over: false
      muted: false
      time: ->
        Date.now() - startTime
    
    canvasDOM.width = game.width
    canvasDOM.height = game.height


    game.setSize = ->
      inWidth = window.innerWidth
      inHeight = window.innerHeight
      hRatio = (inHeight - 100) / game.height
      hRatio = 1.1 if hRatio > 1.1
      game.scale hRatio
      game.scale (inWidth - 40) / game.width if inWidth - 20 < +canvasDOM.style.width.replace "px", ""

    game.scale = (size) ->
      contDOM.style.width = game.width * size + "px"
      canvasDOM.style.width = game.width * size + "px"
      canvasDOM.style.height = game.height * size + "px"

    window.addEventListener("resize", ->
      game.setSize()
    , false)

    game.setSize()



    class Sprite

      constructor: (@image, @cTop, @cSize, @pos, @size, @speed, @frames, @once, @length) ->
        @ticker = 0

      animation: (frames, once) =>
        @frames = frames
        @once = once if once?
        @ticker = 0
        @done = false

      draw: =>
        if !@done

          if !@frames
            @frames = (num for num in [0..@length-1])

          @ticker += @speed * dt

          idx = Math.floor(@ticker)
          frame = @frames[idx % @frames.length]

          @cLeft = frame * @cSize[0]

          if @once && idx >= @frames.length-1
            @done = true

        canvas.drawImage @image, @cLeft, @cTop, @cSize[0], @cSize[1], @pos[0], @pos[1], @size[0], @size[1]



    class Bullet

      constructor: (@image, @height, @width, @top, @left, @isPlayers, @horzMovement) ->
        Bullet.bullets.push @

      @bullets: []

      @move: ->

        @bullets = @bullets.filter (b) -> !(b.top + b.height < 0 || b.top > game.height)

        for bullet in @bullets
          if bullet.isPlayers
            bullet.top -= Math.round(10 * dt)
          else
            left = Math.round((1 * bullet.horzMovement * game.level/8) * dt)
            top = Math.round((3 + game.level/4) * dt)
            bullet.left += left
            bullet.top += top
            bullet.image.pos[0] += left
            bullet.image.pos[1] += top

      @draw = ->
        for bullet in @bullets
          if bullet.isPlayers
            canvas.drawImage bullet.image, 0, 276, 7, 14, bullet.left, bullet.top, bullet.width, bullet.height
          else
            bullet.image.draw()



    player = width: 60, height: 60
    player.left = (game.width/2) - player.width/2
    player.top = game.height - player.height - 10

    player.sp = 30
    player.tp = 20

    player.sprite = new Sprite imgRepo.get("images/sprite.png"), 101, [128, 120], #crop position/size
    [player.left, player.top], [player.width+player.sp, player.height+player.tp], #position/size
    0.3, [3], "once" #speed

    player.move = -> 

      if @isMovingLeft && @left > 20
        @left -= Math.round(12*dt)
      else if @isMovingRight && @left < game.width - @width - 20
        @left += Math.round(12*dt)

      if @isMovingUp && @top > game.height - player.height - 100
        @top -= Math.round(6*dt)
      else if @isMovingDown && @top < game.height - player.height - 10
        @top += Math.round(6*dt)

      player.sprite.pos[0] = @left - player.sp/2
      player.sprite.pos[1] = @top - player.tp

    player.draw = ->
      # canvas.fillRect(@left-1, @top-1, @width+2, @height+2)
      player.sprite.draw()

    player.shoot = ->
      height = 18
      width = 9
      left = player.left + player.width/2 - width/2
      top = player.top - height

      new Bullet imgRepo.get("images/sprite.png"), height, width, top, left-15, true, null
      # new Bullet imgRepo.get("images/sprite.png"), height, width, top, left, true, null
      new Bullet imgRepo.get("images/sprite.png"), height, width, top, left+15, true, null

      @initMuzzleFlash()
      soundRepo.shoot.play() if !game.muted


    player.flashes = []
    player.initMuzzleFlash = ->
      player.flashes.push new Sprite imgRepo.get("images/sprite.png"), 240, [56,36], [0, 0], [32,32], 0.8, false, "once", 4
      player.flashes.push new Sprite imgRepo.get("images/sprite.png"), 240, [56,36], [0, 0], [32,32], 0.8, false, "once", 4

    player.drawFlashes = ->
      @flashes = @flashes.filter (flash) -> !flash.done
      for flash, i in @flashes
        offset = if i%2 == 0 then -15 else +15
        flash.pos[0] = player.left + player.width/2 + offset - 32/2 
        flash.pos[1] = player.top + 12 - 36
        flash.draw()



    class Invader

      constructor: (@cLeft, @cTop, @cWidth, @cHeight, @left, @top, @width, @height, @dead) ->
        @patrol = left: 0, top: 0
        @lives = 2
        Invader.invaders.push @

      @invaders: []

      @speed: 1
      @patrolSwitch: 0

      @deploy = ->

        sprites = [
          [105, 0, 100, 100]
          [205, 0, 103, 100]
          [312, 0, 103, 100]
          [415, 0, 103, 100]
          [631, 0, 104, 100]
          [738, 0, 100, 100]
          [845, 0, 105, 100]
          [954, 0, 103, 100]
          [0, 0, 105, 100]
          [518, 0, 111, 100]
        ]

        i = game.level % 10

        cLeft = sprites[i][0]
        cTop = sprites[i][1]
        cWidth = sprites[i][2]
        cHeight = sprites[i][3]

        w = 70
        h = 50
        @p = 15

        startTop = -(h+@p)*3
        startLeft = (game.width/2) - ((w+@p)*8-@p)/2

        for i in [0..23]
          new Invader cLeft, cTop, cWidth, cHeight, startLeft + (i%8) * (w+@p), startTop + (i%3) * (h+@p), w, h, false


      @move = ->

        leftValues = []
        rightValues = []
        for invader in @invaders
          leftValues.push invader.left
          rightValues.push invader.left + invader.width
        left = Math.min leftValues...
        right = Math.max rightValues...

        now = Date.now()
        if (left < 20 || right > game.width - 20) && now - @patrolSwitch > 1000
          @speed = -@speed
          @patrolSwitch = now

        for invader in Invader.invaders

          if invader.patrol.top < (invader.height+@p)*3+20
            invader.patrol.top += Math.round(2*dt)
            invader.top += Math.round(2*dt)
          else
            invader.left += Math.round(@speed*dt)


      @draw = ->
        for i in Invader.invaders
          # canvas.fillRect(i.left-1, i.top-1, i.width+2, i.height+2)
          canvas.drawImage(imgRepo.get("images/sprite.png"), i.cLeft, i.cTop, i.cWidth, i.cHeight, i.left, i.top, i.width, i.height)


      @shoot = ->
        for invader in Invader.invaders
          dontShoot = false

          for i in Invader.invaders
            if invader.top < i.top && (invader.left < i.left + invader.width && invader.left + invader.width > i.left)
              dontShoot = true

          if rand(-1000, 2+game.level/2) > -1 && !dontShoot
            
            size = 18
            top = invader.top + invader.height
            left = invader.left + invader.width/2 - size/2  
            horzMovement = rand(-10, 10) / 10
            sprite = new Sprite imgRepo.get("images/sprite.png"), 222, [size,size], [left,top], [size,size], 200, false, false, 18
            new Bullet sprite, size, size, top, left, false, horzMovement



    class Explosion

      constructor: (@left, @top, @size, @type) ->
        left = @left - @size/2
        top = @top - @size/2
        if @type == "shockwave"
          exp = new Sprite imgRepo.get("images/explosion2.png"), 0, [83.333,83], [left, top], [@size,@size], 0.65, false, "once", 48
        else
          exp = new Sprite imgRepo.get("images/explosion.png"), 0, [88,88], [left, top], [@size,@size], 0.8, false, "once", 64
        Explosion.explosions.push exp

      @explosions: []

      @draw: ->
        @explosions = @explosions.filter (exp) -> !exp.done
        for exp in @explosions
          exp.draw()



    game.colliding = (b1, b2) ->
      b1.left < b2.left + b2.width && b1.left + b1.width > b2.left && b1.top < b2.top + b2.height && b1.height + b1.top > b2.top

    game.handleCollisions = ->

      for bullet, i in Bullet.bullets

        if @colliding(player, bullet) && !bullet.isPlayers
          if @time() - @timeOfLastDeath > 800
            @lives--
            @timeOfLastDeath = @time()
            bullet.dead = true
            @updateScore()

            new Explosion player.left + player.width/2, player.top + 20, 120, "impact"
            soundRepo.explosion.play() if !game.muted

        for invader, j in Invader.invaders
          if @colliding(invader, bullet) && bullet.isPlayers
            bullet.dead = true
            invader.lives--
            invader.dead = true if !invader.lives

            type = if invader.dead && rand(-10,5) > 0 then "shockwave" else "impact"
            size = if type == "shockwave" then 100 + rand(1, 40) else 80 + rand(1, 40)

            new Explosion invader.left + invader.width/2, invader.top + invader.height/2, size, type
            soundRepo.explosion.play() if !game.muted


      Bullet.bullets = Bullet.bullets.filter (b) -> !b.dead
      Invader.invaders = Invader.invaders.filter (i) -> !i.dead



    game.bgPos = 0; game.bgPos2 = 0;
    game.loopBackground = ->
      @bgPos += Math.round dt*1
      @bgPos2 += Math.round dt*2

      height = game.height
      canvas.drawImage(imgRepo.get("images/bg-o.png"), 0, @bgPos, game.width, height)
      canvas.drawImage(imgRepo.get("images/bg-o.png"), 0, @bgPos - height, game.width, height)
      @bgPos = 0 if @bgPos >= height

      height2 = game.height
      canvas.drawImage(imgRepo.get("images/bg2.png"), 0, @bgPos2, game.width, height2)
      canvas.drawImage(imgRepo.get("images/bg2.png"), 0, @bgPos2 - height2, game.width, height2)
      @bgPos2 = 0 if @bgPos2 >= height2



    game.updateScore = ->
      ret = []
      if game.lives
        for i in [1..game.lives]
          ret.push "<img src='images/life.png'>"

      livesDOM.innerHTML = ret.join("")

      levelDOM.textContent = game.level
      infoLevelDOM.textContent = game.level



    dt = 0
    firstLoop = true
    game.setDeltaLastTime = ->
      if firstLoop
        firstLoop = false
        game.deltaLastTime = Date.now()
      now = Date.now()
      dt = ((now - game.deltaLastTime) / 1000.0)*60
      game.deltaLastTime = now


    game.dealWithEvents = ->

      if @lives == 0 && !@paused.over
        @paused.over = true
        setTimeout(=>
          document.addEventListener("keydown", restartGame = (e) =>
            if e.keyCode == 32
              document.removeEventListener "keydown", restartGame
              @paused.over = false
              infoOverDOM.className = ""
              soundRepo.background.pos(0)
              @init(1, 3)
          , false)
        , 1000)


      else if Invader.invaders.length == 0 && !@paused.levelup
        @paused.levelup = true
        @level++
        @updateScore()
        setTimeout(=>
          @paused.levelup = false
          infoLevelupDOM.className = ""
          @init(@level, @lives)
        , 2000)


      if @paused.over
        infoOverDOM.className = "active"
      else if @paused.levelup
        infoLevelupDOM.className = "active"



    game.update = ->
      # canvas.clearRect(0, 0, game.width, game.height)
      game.loopBackground()

      game.setDeltaLastTime()

      if !game.paused.over
        player.move()
        player.draw()

      if !game.paused.levelup
        Invader.move()
        Invader.draw()

      if !game.paused.over && !game.paused.levelup
        game.handleCollisions()
        Invader.shoot()

      Bullet.move()
      Bullet.draw()
      Explosion.draw()
      player.drawFlashes()

      game.dealWithEvents()

      requestAnimationFrame game.update



    game.init = (level, lives) ->
      @level = level
      @lives = lives

      Bullet.bullets = []
      Invader.invaders = []
      Invader.deploy()

      @updateScore()



    document.addEventListener( "keydown", (e) ->

      if e.keyCode == 37 #left

        player.sprite.animation [2,1,0] if !player.leftPressed

        player.leftPressed = true
        player.isMovingLeft = true
        player.isMovingRight = false

      else if e.keyCode == 39 #right

        player.sprite.animation [4,5,6] if !player.rightPressed

        player.rightPressed = true
        player.isMovingRight = true
        player.isMovingLeft = false

      else if e.keyCode == 38 #up

        player.upPressed = true
        player.isMovingUp = true
        player.isMovingDown = false

      else if e.keyCode == 40 #down

        player.downPressed = true
        player.isMovingDown = true
        player.isMovingUp = false

      else if e.keyCode == 32
        e.preventDefault()
        player.shoot() if !game.paused.over && !game.paused.levelup

    , false)


    document.addEventListener( "keyup", (e) ->

      if e.keyCode == 37 #left
        player.leftPressed = false
        player.isMovingLeft = false
        player.isMovingRight = true if player.rightPressed

        if !player.rightPressed then player.sprite.animation [1,2,3] else player.sprite.animation [4,5,6]

      else if e.keyCode == 39 #right
        player.rightPressed = false
        player.isMovingRight = false
        player.isMovingLeft = true if player.leftPressed

        if !player.leftPressed then player.sprite.animation [5,4,3] else player.sprite.animation [2,1,0]

      else if e.keyCode == 38 #up
        player.upPressed = false
        player.isMovingUp = false
        player.isMovingDown = true if player.downPressed

      else if e.keyCode == 40 #down
        player.downPressed = false
        player.isMovingDown = false
        player.isMovingUp = true if player.upPressed


    , false)


    muteDOM.addEventListener("click", ->
      if !game.muted then soundRepo.background.mute() else soundRepo.background.unmute()
      game.muted = !game.muted
    , false)


    game.update()
    loadingDOM.className = ""
    soundRepo.background.play()














