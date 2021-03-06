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

mobile = love.system.getOS() == 'Android' or love.system.getOS() == 'iOS' or mobileoverride

joystickx = 0 -- mobile stuff
joysticky = 0
joysticksize = 0
joysticktouch = nil

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

touchpos = nil

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

-- controller support shenanigans
cursorx = 0
cursory = 0

local usingcursor = false

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

  love.system.vibrate(0.4)

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

function exportMap()
  -- just set some defaults
  local level = {
    grass = {

    },
    properties = {
      sky = "normal",
      spawnloc = {400, 400}
    }
  }

  -- export each ground object
  for _,gr in ipairs(objects.grounds) do
    local data = gr.body:getUserData()
    local obj = {
      type = data.type,
      x = math.round(gr.body:getX()),
      y = math.round(gr.body:getY()),
      color = data.color
    }

    if data.type == "circle" then
      obj.radius = math.round(gr.shape:getRadius())
    elseif data.type == "rectangle" then
      -- here we just trust the data saying its a rectangle. this will fail MASSIVELY if it isnt
      local points = table.pack(gr.shape:getPoints())
      obj.width = math.abs(math.round(points[1] - points[3]))
      obj.height = math.abs(math.round(points[2] - points[8]))
    elseif data.type == "polygon" then
      local points = table.pack(gr.shape:getPoints())

      local vertices = {}
      for i=1, #points/2 do
        table.insert(vertices, {math.round(points[i*2-1]), math.round(points[i*2])})

        print(points[i*2-1], points[i*2])
        print(unpack(vertices[i]))
      end

      obj.vertices = vertices
    end

    table.insert(level.grass, obj)
  end

  -- export spawn location
  level.properties.spawnloc = carlcheck

  return level
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

  if mobile then
    love.window.setMode(732, 412, {fullscreen = false})

    if not mobileoverride then
      love.window.setFullscreen(true)
    end
  end

  print('boot took ' .. math.floor(love.timer.getTime() - upAt) .. 'ms!')
end


function love.update(dt)
  local joystickdx, joystickdy = 0, 0

  if joysticktouch then
    local touchx, touchy

    if joysticktouch == 'mouse' then
      touchx, touchy = love.mouse.getPosition()
    else
      touchx, touchy = love.touch.getPosition(joysticktouch)
    end

    joystickdx = touchx - joystickx
    joystickdy = touchy - joysticky
  end

  -- game speed
  dt = dt * speed

  -- update stuff
  timer.update(dt)
  love.mouse.setVisible(pause or ineditor)
  updateMusic()

  -- if its paused just stop there
  if pause then return end
  gametimer.update(dt)

  -- controller control stuff
  if not usingcursor then
    cursorx, cursory = love.mouse.getPosition()
  elseif mobile and not mobileoverride then
    if touchpos then
      cursorx = touchpos[1]
      cursory = touchpos[2]
    else
      cursorx = 0
      cursory = 0
    end
  else
    cursorx = cursorx + ctrl:getValue('cursx') * 20
    cursory = cursory + ctrl:getValue('cursy') * 20

    -- keep it in-range
    cursorx = math.min(love.graphics.getWidth(), cursorx)
    cursorx = math.max(0, cursorx)
    cursory = math.min(love.graphics.getHeight(), cursory)
    cursory = math.max(0, cursory)
  end
  
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
  aimpos = {cursorx, cursory, ctrl:isDown('harden')}

  if touchpos then
    aimpos = {touchpos[1], touchpos[2], ctrl:isDown('harden')}
  end

  -- camera positioning
  if gametime-titlescreentweenstart < 2 then
    worldcam:lockPosition(math.max(objects.ball.body:getX(), 100),
    objects.ball.body:getY() - 600 + ease.inOutSine(gametime-titlescreentweenstart, 0, 600, 2))
  else
    worldcam:lockPosition(math.max(objects.ball.body:getX() + (cursorx-love.graphics.getWidth())/(love.graphics.getWidth()/2)*24, 100),
    math.min(objects.ball.body:getY() + (cursory-love.graphics.getHeight())/(love.graphics.getHeight()/2)*20, 800))
  end

  -- input handling
  if (ctrl:isDown("right") or joystickdx > 10 or ctrl:getValue('right') > 0.1) and not ontitlescreen then
    if ineditor then
      local x,y = objects.ball.body:getPosition()
      objects.ball.body:setPosition(x + dt * 1000 * ctrl:getValue("right"), y)
    else
      objects.ball.body:applyForce(MOVEFORCE * (ctrl:getValue("right") + math.min(joystickdx / (joysticksize / 3), 1)), 0)
    end
  elseif (ctrl:isDown("left") or joystickdx < -10 or ctrl:getValue('left') > 0.1) and not ontitlescreen then
    if ineditor then
      local x,y = objects.ball.body:getPosition()
      objects.ball.body:setPosition(x - dt * 1000 * ctrl:getValue("left"), y)
    else
      objects.ball.body:applyForce(-MOVEFORCE * (ctrl:getValue("left") + math.min(-joystickdx / (joysticksize / 3), 1)), 0)
    end
  end

  if (ctrl:isDown("jump") or joystickdy < -30 or ctrl:getValue('jump') > 0.5) and carlcanjump and not ontitlescreen then
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

  local canshootjoystick = true

  if joysticktouch ~= nil then
    if #love.touch.getTouches() == 1 then
      canshootjoystick = false
    end
  end

  -- shooting
  if (ctrl:isDown("fire") and carlschut < 10 and not carldead and carlammo > 0 and not ineditor) and (canshootjoystick or ontitlescreen) then
    love.system.vibrate(0.05)
    
    if carlweapon == 0 then
      local gunwidth = objects.ball.shape:getRadius()*3
      local mx,my = worldcam:worldCoords(cursorx, cursory)
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

function ctrl:inputmoved(name, value)
  if value > 0.1 then carlblink = 0 end

  if name == 'cursx' or name == 'cursy' and value > 0.5 then
    usingcursor = true
  end
end

function love.keypressed(key)
  -- saving
  if key == 's' and love.keyboard.isDown('lctrl') and ineditor then
    love.filesystem.write('level.json', json.encode(exportMap()))
  end
end

function love.mousepressed(x, y, button)
  if pointInBox(x, y, joystickx - joysticksize / 2, joysticky - joysticksize / 2, joysticksize, joysticksize) and mobileoverride and button == 1 then
    joysticktouch = 'mouse'
    return
  end
  
  --tool selection
  local i
  for i = 0,3 do
    if ineditor and mouseInBox(5 + i * (40 + 2), 5, 40, 40) and button == 1 then
      tool = i
    end
  end

  -- speed resetting
  if button == 3 then
    speed = 1
  end

  -- object manipulation
  if love.mouse.getY() > 50 and ineditor then
    -- placing
    if button == 1 then
      local x, y = worldcam:worldCoords(love.mouse.getX(), love.mouse.getY())

      -- rectangles & circles
      if tool == 1 or tool == 2 then
        toolprop = {x, y}
      end
      -- polygons
      if tool == 3 then
        if toolprop == nil then toolprop = {} end
        table.insert(toolprop, {x, y})

        -- max out vertices at 8
        if #toolprop == 8 then
          editorcreateshape()
          toolprop = nil
        end
      end
      -- dragging
      if tool == 0 then
        local body
        local x, y = worldcam:worldCoords(love.mouse.getX(), love.mouse.getY())
        for _,i in ipairs(world:getBodies()) do
          for _,b in ipairs(i:getFixtures()) do
            if b:testPoint(x, y) then
              body = i
            end
          end
        end

        if body then
          toolprop = {body:getX() - x, body:getY() - y, body}
        end
      end
    elseif button == 2 then
      -- deleting & undoing placements
      if toolprop ~= nil then
        -- circles and rectangles get cancelled on right click
        if tool == 1 or tool == 2 then
          toolprop = nil
        end

        -- polygons only get cancelled if its an incomplete polygon
        if tool == 3 then
          if #toolprop >= 3 then
            editorcreateshape()
          else
            toolprop = nil
          end
        end
      elseif tool == 0 then
        -- deletion
        for _,i in ipairs(world:getBodies()) do
          for _,b in ipairs(i:getFixtures()) do
            local x, y = worldcam:worldCoords(love.mouse.getX(), love.mouse.getY())
            if b:testPoint(x, y) then
              b:destroy()
            end
          end
        end
      end
    end
  end
end

function love.mousereleased(x, y, m)
  if joysticktouch == 'mouse' and m == 1 then
    joysticktouch = nil
  end

  if m == 1 and ineditor and toolprop ~= nil then
    if tool == 1 or tool == 2 then
      editorcreateshape()
    elseif tool == 0 then
      toolprop = nil
    end
  end

  if m == 1 and mouseonbutton ~= false and pause then
    buttonactions[mouseonbutton]()
  end
end

function love.mousemoved(x, y, dx, dy)
  if dx ~= 0 and dy ~= 0 then
    carlblink = 0
    usingcursor = false
  end

  if ineditor and toolprop ~= nil and tool == 0 then
    local body = toolprop[3]
    x, y = worldcam:worldCoords(x, y)
    
    body:setPosition(x + toolprop[1], y + toolprop[2])
    body:setLinearVelocity(0, 0)
  end
end

function love.wheelmoved(x, y)
  if ineditor and y ~= 0 then
    zoom = zoom + y/12
  else
    carlweapon = (carlweapon + y)%3
  end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
  if pointInBox(x, y, joystickx - joysticksize / 2, joysticky - joysticksize / 2, joysticksize, joysticksize) then
    joysticktouch = id
  else
    if id == joysticktouch then return end
    touchpos = {x, y}
    love.mousepressed(x, y, 1)
  end
end

function love.touchreleased(id, x, y)
  if joysticktouch == id then
    joysticktouch = nil
  end
end

ctrl:hookup()