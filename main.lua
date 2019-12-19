local upAt = love.timer.getTime()

camera = require 'lib.camera'
gamestate = require 'lib.gamestate'
signal = require 'lib.signal'
gametimer = require 'lib.timer'
timer = require 'lib.timer copy' -- lua is stupid so i have to do this
ease = require 'lib.easing'
json = require 'lib.json'
ctrl = require 'lib.ctrl'()

rendering = require 'rendering'
require 'utils'
require 'audio'
require 'vals'

-- set up camera stuff
worldcam = camera()
worldcam.smoother = camera.smooth.damped(15)

sprites = {}
fonts = {}
sounds = {}

seedebug = false -- see the debug values

ineditor = false -- whether youre editing a level or not

carlschut = 0 -- the carl shooting timer
carlschutorigin = {0, 0} -- where carl shot from
carlschutloc = {0, 0} -- where the bullet is heading towards

carlweapon = 0 -- what weapon carl is using (0-2)
carlammo = 5 -- how much bullets carl has

carlblink = 0 -- blink timer

carlcanjump = false -- i think you can guess

carldead = false -- if carl is dead or not
recentdeath = love.timer.getTime() -- tween stuff

carlcheck = {400, 400} -- the last checkpoint carl was at

oldmousepos = {love.mouse.getX(), love.mouse.getY()} -- old mouse position, for menu stuff

aimpos = {0, 0, false} -- where carl is aiming (for pause compatability)

oldcarlpos = {nil, nil} -- for the carl trail

pause = false -- if the game is paused or not
gametime = 0 -- game timer
recentpause = 0 -- tween stuff

ontitlescreen = true -- whether the player is on the title screen or not
titlescreentweenstart = -90 -- tween stuff

madecocksfx = true -- whether the cock sfx has been made yet or not

local zoom = 0 -- editor zoom amount
speed = 1.0 -- game speed (experimental)
tool = 0 -- editor tool
toolprop = nil -- properties of the tool

-- temp
level = json.decode(love.filesystem.read('level.json'))

-- world/level stuff
world = love.physics.newWorld(0, 0, false)
objects = {}
objects.grounds = {}
objects.dirt = {}
objects.ball = {}

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

function editorcreateshape()
  local body
  local shape
  local fixture

  local type
      
  if tool == 1 then
    local x, y = worldcam:worldCoords(love.mouse.getX(), love.mouse.getY())
    local x2, y2 = toolprop[1], toolprop[2]

    body = love.physics.newBody(world, x2, y2, "static")
    shape = love.physics.newCircleShape(math.abs(x - x2) + math.abs(y - y2))
    type = "circle"
  elseif tool == 2 then
    local x, y = worldcam:worldCoords(love.mouse.getX(), love.mouse.getY())
    local width = (x - toolprop[1])
    local height = (y - toolprop[2])

    body = love.physics.newBody(world, x - width/2, y - height/2)
    shape = love.physics.newRectangleShape(width, height)
    type = "rectangle"
  elseif tool == 3 then
    local x, y = worldcam:worldCoords(toolprop[1][1], toolprop[1][2])

    local vertices = {}
    for _,v in ipairs(toolprop) do
      table.insert(vertices, v[1] - x)
      table.insert(vertices, v[2] - y)
    end

    body = love.physics.newBody(world, x, y)
    shape = love.physics.newPolygonShape(vertices)
    type = "polygon"
  else
    error("invalid object type (must be rectangle, polygon or circle)")
  end

  fixture = love.physics.newFixture(body, shape)
  fixture:setFriction(0.5)
  fixture:setMask(2)
      
  body:setUserData({
    color = {1, 1, 0},
    type = type,
  })

  table.insert(objects.grounds, {
    body = body, shape = shape, fixture = fixture
  })
  toolprop = nil
end

function killcarl()
  if carldead then return end
  carldead = true
  recentdeath = gametime

  local keepx = objects.ball.body:getX()
  local keepy = objects.ball.body:getY()

  playSound('carlcry'..math.random(1,5))

  madecocksfx = true
  carlschut = 0

  gametimer.during(0.6, function()
    objects.ball.body:setPosition(keepx, keepy)
    objects.ball.body:setLinearVelocity(0, 0)
  end, function()
    carldead = false
    madecocksfx = false
    carlschut = 20
    carlschutloc = {0,9000}
    carlschutorigin = {-1,9000}
    objects.ball.body:setPosition(carlcheck[1], carlcheck[2])
    objects.ball.body:setLinearVelocity(0, 0.1)
  end)
end

function loadMap(lvl)
  -- remove all objects
  objects = {}
  objects.grounds = {}
  objects.dirt = {}
  objects.ball = {}

  -- create a new world
  local wrd = love.physics.newWorld(0, GRAVITY, true)

  -- process each ground object
  for _,obj in ipairs(lvl.grass) do
    local body = love.physics.newBody(wrd, obj.x, obj.y, obj.dynamic and "dynamic" or "static")
    local shape
    local fixture

    -- type handling
    if obj.type == 'rectangle' then
      shape = love.physics.newRectangleShape(obj.width, obj.height)
    elseif obj.type == 'polygon' then
      local vertices = {}
      for _,v in ipairs(obj.vertices) do
        table.insert(vertices, v[1])
        table.insert(vertices, v[2])
      end

      shape = love.physics.newPolygonShape(vertices)
    elseif obj.type == 'circle' then
      shape = love.physics.newCircleShape(obj.radius)
    else
      error("invalid object type (must be rectangle, polygon or circle)")
    end

    fixture = love.physics.newFixture(body, shape)
    fixture:setFriction(0.5)
    fixture:setMask(2)
    body:setUserData(obj) -- for non-box2d values

    table.insert(objects.grounds, {
      body = body, shape = shape, fixture = fixture
    })
  end

  -- add carl
  objects.ball.body = love.physics.newBody(wrd, lvl.properties.spawnloc[1], lvl.properties.spawnloc[2], ineditor and "static" or "dynamic")
  objects.ball.shape = love.physics.newCircleShape(25)
  objects.ball.fixture = love.physics.newFixture(objects.ball.body, objects.ball.shape, 1)
  objects.ball.fixture:setRestitution(0.03)
  objects.ball.fixture:setFriction(0.1)
  objects.ball.body:setFixedRotation(true)

  -- add jump collision
  if not ineditor then
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
            if (f == fixture1 or f == fixture2) then
              hasground = true
            end
          end
        end

        if hascarl and hasground then
          func(coll)
        end
      end
    end

    wrd:setCallbacks(checkcarlcoll(function() carlcanjump = true end))
  else
    objects.ball.fixture:setCategory(2)
  end

  return wrd
end

function love.load()
  -- give a warm welcome
  print(
    'hello! carl running on '..love.system.getOS()..', love v'..love.getVersion()..'\n'..
    '(we couldnt afford fancy ascii art. please enjoy a circle)\n'..
    'o\n'
  )

  -- resource loading
  local spritecount = 0
  local audiocount = 0

  -- adding sprites
  local function addSprites(d)
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
        spritecount = spritecount + 1
        sprites[spritename] = sprite
      elseif love.filesystem.getInfo(dir .. "/" .. file).type == "directory" then
        local newdir = file
        if d then
          newdir = d .. "/" .. newdir
        end
        addSprites(file)
      end
    end
  end
  addSprites()
  print('loaded '..spritecount..' sprites')

  -- audio
  sound_exists = {}
  local function addAudio(d)
    local dir = "assets/audio"
    if d then
      dir = dir .. "/" .. d
    end
    local files = love.filesystem.getDirectoryItems(dir)
    for _,file in ipairs(files) do
      if love.filesystem.getInfo(dir .. "/" .. file).type == "directory" then
        local newdir = file
        if d then
          newdir = d .. "/" .. newdir
        end
        addAudio(file)
      else
        local audioname = file
        if file:ends(".wav") then audioname = file:sub(1, -5) end
        if file:ends(".mp3") then audioname = file:sub(1, -5) end
        if file:ends(".ogg") then audioname = file:sub(1, -5) end
        if file:ends(".flac") then audioname = file:sub(1, -5) end
        if file:ends(".xm") then audioname = file:sub(1, -4) end

        sound_exists[audioname] = true
        audiocount = audiocount + 1
      end
    end
  end
  addAudio()
  print('loaded '..audiocount..' audio files')

  registerSound('shotgun_cock', 1.0)
  registerSound('shotgun_fire1', 1.0)
  registerSound('shotgun_fire2', 1.0)
  registerSound('doop', 1.0)

  for i=1,5 do
    registerSound('carlcry'..i, 0.5)
  end

  -- let vals.lua handle it
  bindings()

  -- setting up love.physics and the world
  love.physics.setMeter(64)
  world:destroy()
  world = loadMap(level)

  --[[
    fonts:
    1 - defualt, regular size
    2 - default, big (for menu elements)
    3 - handwriting, beeeg (for title screen)
  ]]

  fonts = {
    love.graphics.newFont(12),
    love.graphics.newFont(24),
    love.graphics.newFont(demo and 'assets/fonts/AndantinoScript.ttf' or 'assets/fonts/KaushanScript-Regular.ttf', 128)
  }

  love.graphics.setBackgroundColor(0.41, 0.53, 0.97)
  love.graphics.setDefaultFilter('nearest','nearest', 2)

  print('boot took ' .. math.floor(love.timer.getTime() - upAt) .. 'ms!')
end


function love.update(dt)
  -- game speed
  dt = dt * speed

  -- update stuff
  timer.update(dt)
  love.mouse.setVisible(pause or ineditor)
  updateMusic()

  -- if its paused just stop there
  if pause then return end
  gametimer.update(dt)
  
  -- carl trail
  local vx, vy = objects.ball.body:getLinearVelocity()
  if math.abs(vx) + math.abs(vy) > 1200 then
    oldcarlpos = {objects.ball.body:getX(), objects.ball.body:getY()}
  else
    oldcarlpos = {nil, nil}
  end

  world:update(dt)
  gametime = gametime + dt

  -- aiming position for rendering
  aimpos = {love.mouse.getX(), love.mouse.getY(), ctrl:isDown('harden')}

  -- camera positioning
  if gametime-titlescreentweenstart < 2 then
    worldcam:lockPosition(math.max(objects.ball.body:getX(), 100),
    objects.ball.body:getY() - 600 + ease.inOutSine(gametime-titlescreentweenstart, 0, 600, 2))
  else
    worldcam:lockPosition(math.max(objects.ball.body:getX() + (love.mouse.getX()-love.graphics.getWidth())/(love.graphics.getWidth()/2)*24, 100),
    math.min(objects.ball.body:getY() + (love.mouse.getY()-love.graphics.getHeight())/(love.graphics.getHeight()/2)*20, 800))
  end

  -- input handling
  if ctrl:isDown("right") and not ontitlescreen then
    if ineditor then
      local x,y = objects.ball.body:getPosition()
      objects.ball.body:setPosition(x + dt * 1000 * ctrl:getValue("right"), y)
    else
      objects.ball.body:applyForce(MOVEFORCE * ctrl:getValue("right"), 0)
    end
  elseif ctrl:isDown("left") and not ontitlescreen then
    if ineditor then
      local x,y = objects.ball.body:getPosition()
      objects.ball.body:setPosition(x - dt * 1000 * ctrl:getValue("left"), y)
    else
      objects.ball.body:applyForce(-MOVEFORCE * ctrl:getValue("left"), 0)
    end
  end

  if ctrl:isDown("jump") and carlcanjump and not ontitlescreen then
    if ineditor then
      local x,y = objects.ball.body:getPosition()
      objects.ball.body:setPosition(x, y - dt * 1000 * ctrl:getValue("jump"))
    else
      objects.ball.body:applyForce(0, -JUMPFORCE/speed)
      carlcanjump = false
    end
  end

  if ctrl:isDown("down") and ineditor then
    local x,y = objects.ball.body:getPosition()
    objects.ball.body:setPosition(x, y + dt * 1000 * ctrl:getValue("down"))
  end

  if ctrl:isDown("harden") and not ontitlescreen and not ineditor then
    objects.ball.fixture:setRestitution(0)
    objects.ball.body:setLinearDamping(1.3)
    objects.ball.fixture:setDensity(2)
  else
    objects.ball.fixture:setRestitution(0.02)
    objects.ball.body:setLinearDamping(0.12)
    objects.ball.fixture:setDensity(1)
  end

  -- shooting
  if ctrl:isDown("fire") and carlschut < 10 and not carldead and carlammo > 0 and not ineditor then
    if carlweapon == 0 then
      local gunwidth = objects.ball.shape:getRadius()*3
      local mx,my = worldcam:mousePosition()
      local carlrot = math.atan2(my-objects.ball.body:getY(), mx-objects.ball.body:getX())
      carlschutorigin = {objects.ball.body:getX(), objects.ball.body:getY()}
      carlschutloc = {mx + ((math.random(30, 100) / 100 * carlschut * (math.random(0, 1) * 2 - 1)) / 10 * 50), my+((math.random(30, 100) / 100 * carlschut * (math.random(0, 1) * 2 - 1)) / 10 * 50)}

      carlschut = 40 + carlschut / 4
      carlammo = carlammo - 1

      if madecocksfx then madecocksfx = false end

      if ontitlescreen then
        ontitlescreen = false
        titlescreentweenstart = gametime
        gametimer.after(1, function()
          playMusic('carltheme', 0.9)
        end)
      else
        objects.ball.body:applyForce(math.max(math.min((carlschutorigin[1] / 40 - carlschutloc[1] / 40), 2), -2) * 1500 / speed,
        math.max(math.min((carlschutorigin[2] / 40 - carlschutloc[2] / 40), 2), -2) * 2000 / speed)
        
        local multipliedloc = {carlschutloc[1] + (carlschutloc[1] - carlschutorigin[1]) * 2000,
        carlschutloc[2] + (carlschutloc[2] - carlschutorigin[2]) * 2000}

        local lowestdist = {nil, nil}

        world:rayCast(carlschutorigin[1], carlschutorigin[2], multipliedloc[1], multipliedloc[2], function(fix, x, y)
          local dist = math.abs(carlschutorigin[1] - x) + math.abs(carlschutorigin[2] - y)

          if lowestdist[1] == nil or dist < lowestdist[1] then
            lowestdist = {dist, fix}
          end

          return 1
        end)

        if lowestdist[2] ~= nil then
          local body = lowestdist[2]:getBody()

          local xforce = math.max(math.min((carlschutorigin[1] / 40 - carlschutloc[1] / 40), 2), -2) * -1500
          local yforce = math.max(math.min((carlschutorigin[2] / 40 - carlschutloc[2] / 40), 2), -2) * -1500

          if body:getType() == "dynamic" then
            body:applyForce(xforce/speed, yforce/speed)
          end
        end
      end

    playSound('shotgun_fire'..math.random(1, 2), 0.5)
    end
  elseif carlammo == 0 then
    carlammo = -1
    carlschut = 60
    madecocksfx = false
  end

  if carlschut > 0 then
    carlschut = carlschut - dt * 64
  else
    carlschut = 0
  end

  if objects.ball.body:getX() < -100 then
    objects.ball.body:applyForce(2000, 0)
  end

  if objects.ball.body:getY() > 1300 and not carldead and not ineditor then
    killcarl()
  end

  if carlschut < 5 and not madecocksfx and not ineditor then
    madecocksfx = true
    carlammo = 5
    playSound('shotgun_cock', 0.4)
  end

  -- remove each destroyed object
  for i,obj in ipairs(objects.grounds) do
    if obj.body:isDestroyed() or obj.fixture:isDestroyed() then
      table.remove(objects.grounds, i)
    end
  end
end

function love.draw()
  -- everything is reset incase dum jilly forgets
  love.graphics.setFont(fonts[1])
  love.graphics.setColor(1, 1, 1)
  love.graphics.setLineWidth(1)

  -- blinnk
  if not pause then carlblink = carlblink + 1 end
  
  -- camera stuff
  worldcam:attach()
  local zoomease = ease.outExpo(love.timer.getTime() - recentpause, pause and 1 or 1.2, 0.2 * (pause and 1 or -1), 0.35)
  local rotease = ease.outExpo(love.timer.getTime() - recentpause, pause and 0 or 0.2, 0.2 * (pause and 1 or -1), 0.4)
  worldcam:rotateTo(rotease)
  worldcam:zoomTo((zoomease + zoom) * love.graphics.getWidth()/10 / 120)

  -- pass the rendering to rendering.lua
  rendering.renderWorld(worldcam)

  worldcam:detach()

  if not ontitlescreen then
    rendering:renderUI()
  end

  -- tweens are done horribly. please ignore for the time being
  if ontitlescreen then
    titlescreentweenstart = gametime
  else
    if gametime-titlescreentweenstart > 2 then
      titlescreentweenstart = gametime-2
    end
  end

  -- title screen
  love.graphics.setFont(fonts[3])

  local tween = ease.inOutSine(gametime-titlescreentweenstart, 0, 1, 2)

  for _,o in ipairs({{0,1},{1,0},{1,1},{1,-1}}) do
    love.graphics.setColor(0,0,0,1-tween)
    love.graphics.printf(demo and 'Колобок' or 'Carl', 0+o[1], 90+o[2]-tween*(80+fonts[3]:getHeight()), love.graphics.getWidth(), 'center')
    love.graphics.printf(demo and 'Колобок' or 'Carl', 0-o[1], 90-o[2]-tween*(80+fonts[3]:getHeight()), love.graphics.getWidth(), 'center')
  end

  love.graphics.setColor(1,1,1,1-tween)
  love.graphics.printf(demo and 'Колобок' or 'Carl', 0, 90-tween*(80+fonts[3]:getHeight()), love.graphics.getWidth(), 'center')

  love.graphics.setFont(fonts[1])
  love.graphics.printf('Press M1 to start', 0, (1-tween)*(90+10+fonts[3]:getHeight()), love.graphics.getWidth(), 'center')

  -- render pause screen
  if pause and not ctrl:isDown('pausepeek') then
    rendering:renderPause()
  end

  -- fadein
  love.graphics.setColor(1,1,1,1-(gametime-0))
  love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
end

function ctrl:inputpressed(name, value)
  carlblink = 0

  if name == 'reset' and not carldead and not ontitlescreen and not ineditor then
    killcarl()
  elseif name == 'reload' then
    world:destroy()
    world = loadMap(json.decode(love.filesystem.read('level.json')))
  elseif name == 'editor' and not pause then
    ineditor = not ineditor
    zoom = 0
    titlescreentweenstart = 0
    ontitlescreen = false
    carldead = false
    carlcanjump = true
    love.mouse.setVisible(ineditor)

    objects.ball.body:setPosition(carlcheck[1], carlcheck[2])
    objects.ball.body:setLinearVelocity(0, 0)
    objects.ball.body:setType(ineditor and "static" or "dynamic")
  elseif name == 'debug' then
    seedebug = not seedebug
  elseif name == 'fullscreen' then
    love.window.setFullscreen(not love.window.getFullscreen())
  elseif name == 'pause' and not ontitlescreen then
    pause = not pause
    resetMusic('carltheme', pause and 0.4 or 0.9) -- set the music to be quieter
    recentpause = love.timer.getTime() -- for tweens
  end
end

function love.mousepressed(x, y, button)
  local i
  for i = 0,3 do
    if ineditor and mouseInBox(5 + i * (40 + 2), 5, 40, 40) and button == 1 then
      tool = i
    end
  end

  if button == 3 then
    speed = 1
  end

  if love.mouse.getY() > 50 and ineditor then
    if button == 1 then
      if tool == 1 or tool == 2 then
        local x, y = worldcam:worldCoords(love.mouse.getX(), love.mouse.getY())
        toolprop = {x, y}
      end

      if tool == 3 then
        local x, y = worldcam:worldCoords(love.mouse.getX(), love.mouse.getY())
        if toolprop == nil then toolprop = {} end
        table.insert(toolprop, {x, y})

        if #toolprop == 8 then
          editorcreateshape()
          toolprop = nil
        end
      end
    elseif button == 2 then
      if toolprop ~= nil then
        if tool == 1 or tool == 2 then
          toolprop = nil
        end

        if tool == 3 then
          if #toolprop >= 3 then
            editorcreateshape()
          else
            toolprop = nil
          end
        end
      elseif tool == 0 then
        for _,i in ipairs(world:getBodies()) do
          for _,b in ipairs(i:getFixtures()) do
            local x, y = worldcam:worldCoords(love.mouse.getX(), love.mouse.getY())
            if b:testPoint(x, y) then
              b:destroy()
              print('destroyed body')
            end
          end
        end
      end
    end
  end
end

function love.mousereleased(x, y, m)
  if m == 1 and ineditor and toolprop ~= nil then
    if tool == 1 or tool == 2 then
      editorcreateshape()
    end
  end

  if m == 1 and mouseonbutton ~= false and pause then
    buttonactions[mouseonbutton]()
  end
end

function love.mousemoved(x, y, dx, dy)
  if dx ~= 0 and dy ~= 0 then carlblink = 0 end
end

function love.wheelmoved(x, y)
  if ineditor and y ~= 0 then
    zoom = zoom + y/12
  else
    carlweapon = (carlweapon + y)%3
  end
end

ctrl:hookup()