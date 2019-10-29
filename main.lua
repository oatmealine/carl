camera = require 'lib.camera'
gamestate = require 'lib.gamestate'
signal = require 'lib.signal'
gametimer = require 'lib.timer'
timer = require 'lib.timer copy' -- lua is stupid so i have to do this
ease = require 'lib.easing'

rendering = require 'rendering'
require 'utils'

worldcam = camera()
worldcam.smoother = camera.smooth.damped(15)

sprites = {}
fonts = {}

carlschut = 0
carlschutorigin = {0,0}
carlschutloc = {0,0}

carlcanjump = false

carldead = false
recentdeath = love.timer.getTime()

carlcheck = {800/2, 800/2}

oldmousepos = {love.mouse.getX(), love.mouse.getY()}

aimpos = {0,0,false}

pause = false
gametime = 0
recentpause = 0

ontitlescreen = true
titlescreentweenstart = -90

-- main menu stuff
buttons = {'resume', 'reset', 'exit'}
buttonactions = {function()
  pause = false
  recentpause = love.timer.getTime()
end, function()
  killcarl()
  pause = false
  recentpause = love.timer.getTime()
end,function()
  love.event.quit()
end}
mouseonbutton = false

function killcarl()
  carldead = true
  recentdeath = love.timer.getTime()

  local keepx = objects.ball.body:getX()
  local keepy = objects.ball.body:getY()

  gametimer.during(0.6, function()
    objects.ball.body:setPosition(keepx, keepy)
    objects.ball.body:setLinearVelocity(0, 0)
  end, function()
    carldead = false
    objects.ball.body:setPosition(carlcheck[1], carlcheck[2])
    objects.ball.body:setLinearVelocity(0, 0)
  end)
end

function love.load()
  local function addsprites(d)
    local dir = "assets/sprites"
    if d then
      dir = dir .. "/" .. d
    end
    local files = love.filesystem.getDirectoryItems(dir)
    for _,file in ipairs(files) do
      if string.sub(file, -4) == ".png" then
        local spritename = string.sub(file, 1, -5)
        local sprite = love.graphics.newImage(dir .. "/" .. file)
        if d then
          spritename = d .. "/" .. spritename
        end
        sprites[spritename] = sprite
      elseif love.filesystem.getInfo(dir .. "/" .. file).type == "directory" then
        local newdir = file
        if d then
          newdir = d .. "/" .. newdir
        end
        addsprites(file)
      end
    end
  end
  addsprites()

  love.physics.setMeter(64)
  world = love.physics.newWorld(0, 9.81*64, true)

  objects = {}

  objects.grounds = {}

  local body = love.physics.newBody(world, -500, 800-50/2)
  local shape  = love.physics.newRectangleShape(2400, 70)
  table.insert(objects.grounds, {
  body = body, shape = shape,
  fixture = love.physics.newFixture(body, shape)})

  for _,obj in ipairs(objects.grounds) do
    obj.fixture:setFriction(0.5)
    obj.fixture:setUserData('grass')
  end

  objects.dirt = {}
  
  local body = love.physics.newBody(world, -480, 800-50/2 + 560/2 + 10)
  local shape  = love.physics.newRectangleShape(2340, 560)
  table.insert(objects.dirt, {
  body = body, shape = shape,
  fixture = love.physics.newFixture(body, shape)})

  for _,obj in ipairs(objects.dirt) do
    obj.fixture:setFriction(0.4)
    obj.fixture:setUserData('dirt')
  end

  objects.ball = {}
  objects.ball.body = love.physics.newBody(world, carlcheck[1], carlcheck[2], "dynamic")
  objects.ball.shape = love.physics.newCircleShape(25)
  objects.ball.fixture = love.physics.newFixture(objects.ball.body, objects.ball.shape, 1)
  objects.ball.fixture:setRestitution(0.03)
  objects.ball.fixture:setFriction(0.1)
  objects.ball.body:setFixedRotation(true)
  objects.ball.fixture:setUserData('carl')

  local function checkcarlcoll(func)
    return function(fixture1, fixture2, coll)
      local hascarl = false
      local hasground = false

      for _,f in ipairs(objects.ball.body:getFixtures()) do
        if f == fixture1 or f == fixture2 then
          hascarl = true
        end
      end

      for _,g in ipairs(objects.grounds) do
        for _,f in ipairs(g.body:getFixtures()) do
          if f == fixture1 or f == fixture2 then
            hasground = true
          end
        end
      end

      if hascarl and hasground then
        func(coll)
      end
    end
  end

  world:setCallbacks(checkcarlcoll(function() carlcanjump = true end), checkcarlcoll(function() carlcanjump = false end))

  --[[
    fonts:
    1 - defualt, regular size
    2 - default, big (for menu elements)
    3 - handwriting, beeeg (for title screen)
  ]]

  fonts = {
    love.graphics.newFont(12),
    love.graphics.newFont(24),
    love.graphics.newFont('assets/fonts/KaushanScript-Regular.ttf', 46)
  }

  love.graphics.setBackgroundColor(0.41, 0.53, 0.97)
  love.window.setMode(1200, 800)
end


function love.update(dt)
  timer.update(dt)
  love.mouse.setVisible(pause)

  if pause then return end
  gametimer.update(dt)
  world:update(dt)
  gametime = gametime + dt

  aimpos = {love.mouse.getX(), love.mouse.getY(), love.mouse.isDown(2)}

  if gametime-titlescreentweenstart < 2 then
    worldcam:lockPosition(math.max(objects.ball.body:getX(), 100),
    objects.ball.body:getY() - 600 + ease.inOutSine(gametime-titlescreentweenstart, 0, 600, 2))
  else
    worldcam:lockPosition(math.max(objects.ball.body:getX() + (love.mouse.getX()-love.graphics.getWidth())/(love.graphics.getWidth()/2)*24, 100),
    math.min(objects.ball.body:getY() + (love.mouse.getY()-love.graphics.getHeight())/(love.graphics.getHeight()/2)*20, 800))
  end

  if love.keyboard.isDown("d") and not ontitlescreen then
    objects.ball.body:applyForce(400, 0)
  elseif love.keyboard.isDown("a") and not ontitlescreen then
    objects.ball.body:applyForce(-400, 0)
  end

  if love.keyboard.isDown("w") and carlcanjump and not ontitlescreen then
    objects.ball.body:applyForce(0, -12000)
    carlcanjump = false
  end

  if love.mouse.isDown(2) and not ontitlescreen then
    objects.ball.fixture:setRestitution(0)
    objects.ball.body:setLinearDamping(1.3)
    objects.ball.fixture:setDensity(2)
  else
    objects.ball.fixture:setRestitution(0.02)
    objects.ball.body:setLinearDamping(0.12)
    objects.ball.fixture:setDensity(1)
  end

  if objects.ball.body:getX() > love.graphics.getWidth()+100 then
    objects.ball.body:applyForce(-2000, 0)
  end
  if objects.ball.body:getX() < -100 then
    objects.ball.body:applyForce(2000, 0)
  end

  if objects.ball.body:getY() > 1300 and not carldead then
    killcarl()
  end

  if love.mouse.isDown(1) and carlschut < 10 then
    local gunwidth = objects.ball.shape:getRadius()*3
    local mx,my = worldcam:mousePosition()
    local carlrot = math.atan2(my-objects.ball.body:getY(), mx-objects.ball.body:getX())
    carlschutorigin = {objects.ball.body:getX()+math.cos(carlrot)*gunwidth, objects.ball.body:getY()+math.sin(carlrot)*gunwidth}
    carlschutloc = {mx+((math.random(30, 100)/100 * carlschut * (math.random(0,1)*2-1))/10*50), my+((math.random(30, 100)/100 * carlschut * (math.random(0,1)*2-1))/10*50)}

    carlschut = 40
    
    if ontitlescreen then
      ontitlescreen = false
      titlescreentweenstart = gametime
    end
  end

  if carlschut > 0 then 
    carlschut = carlschut - dt*64
  else
    carlschut = 0
  end
end

function love.draw()
  love.graphics.setFont(fonts[1])
  worldcam:attach()

  love.graphics.push()

  -- janky solution time
  love.graphics.translate(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  love.graphics.rotate(ease.outExpo(love.timer.getTime() - recentpause, pause and 0 or 0.2, 0.2 * (pause and 1 or -1), 0.4))
  love.graphics.scale(ease.outExpo(love.timer.getTime() - recentpause, pause and 1 or 1.2, 0.2 * (pause and 1 or -1), 0.35))
  love.graphics.translate(-love.graphics.getWidth()/2, -love.graphics.getHeight()/2)

  rendering.renderWorld(worldcam)

  love.graphics.pop()

  worldcam:detach()

  if not ontitlescreen then
    rendering:renderUI()
  end

  if ontitlescreen then
    titlescreentweenstart = gametime
  else
    if gametime-titlescreentweenstart > 2 then
      titlescreentweenstart = gametime-2
    end
  end

  love.graphics.setColor(1,1,1,1-ease.inOutSine(gametime-titlescreentweenstart, 0, 1, 2))
  love.graphics.setFont(fonts[3])
  love.graphics.printf('Carl', 0, 90, love.graphics.getWidth(), 'center')
  love.graphics.setFont(fonts[1])
  love.graphics.printf('Press M1 to start', 0, 90+10+fonts[3]:getHeight(), love.graphics.getWidth(), 'center')

  if pause and not love.keyboard.isDown('tab') then
    rendering:renderPause()
  end
end

function love.keypressed(key)
  if key == 'r' and not carldead and not ontitlescreen then
    killcarl()
  elseif key == 'escape' and not ontitlescreen then
    pause = not pause
    recentpause = love.timer.getTime()
  end
end

function love.mousereleased(x, y, m)
  if m == 1 and mouseonbutton ~= false and pause then
    buttonactions[mouseonbutton]()
  end
end