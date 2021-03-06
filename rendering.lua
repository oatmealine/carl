local this = {}
local particles = {}

local irisxoff = 0
local irisyoff = 0

local this = {}
local particles = {}

local irisxoff = 0
local irisyoff = 0

function renderCarl(x, y, alpha, camera)
  local carlx = x
  local carly = y

  local mx, my = camera:worldCoords(aimpos[1], aimpos[2])

  local carlrot = math.atan2(my-carly, mx-carlx)

  local carlflipped = math.abs(carlrot) < math.pi/2

  local eyes = sprites['carleyes']

  if carlblink > 510 then
    eyes = sprites['carleyes' .. (carlblink > 640 and 'blink' or 'tired')]
  elseif carlblink%130>120 then
    local frames = {'tired', 'tired', 'tired', 'blink', 'blink', 'blink', 'tired', 'tired', ''}
    eyes = sprites['carleyes' .. frames[carlblink%130-120]]
  end

  love.graphics.setLineWidth(love.graphics.getWidth()/10 / 130)

  if not carldead then
    love.graphics.setColor(1, 198/255, 13/255, alpha)

    if carlweapon == 2 and not ineditor and alpha >= 1.0 then
      -- fists
      -- oh no
      love.graphics.circle('fill', carlx + math.cos(carlrot) * objects.ball.shape:getRadius(), carly + math.sin(carlrot) * objects.ball.shape:getRadius(), objects.ball.shape:getRadius()/2)
      love.graphics.setColor(0.1,0.1,0.1, alpha)
      love.graphics.circle('line', carlx + math.cos(carlrot) * objects.ball.shape:getRadius(), carly + math.sin(carlrot) * objects.ball.shape:getRadius(), objects.ball.shape:getRadius()/2)
      love.graphics.setColor(1, 198/255, 13/255, alpha)
    end

    -- the ball
    love.graphics.circle("fill", carlx, carly, objects.ball.shape:getRadius())

    love.graphics.setColor((aimpos[3] and not ineditor) and {0.9,0.9,0.9, alpha} or {0.1,0.1,0.1, alpha}) -- change the outline if its hardening
    love.graphics.circle("line", carlx, carly, objects.ball.shape:getRadius())

    love.graphics.setColor(1,1,1, alpha)
    -- eyes rendering
    if not seedebug then
      local eyex = carlx-objects.ball.shape:getRadius() * (carlflipped and 1 or -1)
      local eyey = carly-objects.ball.shape:getRadius()
      local eyescalex = (objects.ball.shape:getRadius()*2)/eyes:getWidth() * (carlflipped and 1 or -1)
      local eyescaley = (objects.ball.shape:getRadius()*2)/eyes:getHeight()

      if eyes == sprites['carleyes'] then
        local camx, camy = worldcam:cameraCoords(carlx, carly)

        if not pause then
          irisxoff = math.max(math.min((camx/40 - cursorx/40), 2), -2)*-1
          irisyoff = math.max(math.min((camy/40 - cursory/40), 2), -2)*-1.8
        end

        love.graphics.draw(sprites['carleyesempty'], eyex, eyey, 0, eyescalex, eyescaley)
        love.graphics.draw(sprites['carleyesiris'], eyex+irisxoff, eyey+irisyoff, 0, eyescalex, eyescaley)
      else
        love.graphics.draw(eyes, eyex, eyey, 0, eyescalex, eyescaley)
      end
    end
  elseif alpha >= 1.0 then
    -- if carl is dying, render a tween of him dying
    eyes = sprites["carleyescry"]
    local yoff = ease.outQuad(gametime-recentdeath, 0, 1, 0.6)*200

    love.graphics.push()

    love.graphics.translate(carlx+objects.ball.shape:getRadius()/2, carly+objects.ball.shape:getRadius()/2-yoff)
    love.graphics.rotate(yoff/200*math.pi/3*2)
    love.graphics.translate(-carlx-objects.ball.shape:getRadius()/2, -carly-objects.ball.shape:getRadius()/2+yoff)

    love.graphics.setColor(1, 198/255, 13/255, 1-(gametime-recentdeath)/0.5)
    love.graphics.circle("fill", carlx, carly-yoff, objects.ball.shape:getRadius())

    love.graphics.setColor(0.1,0.1,0.1, 1-(gametime-recentdeath)/0.5)
    love.graphics.circle("line", carlx, carly-yoff, objects.ball.shape:getRadius())

    love.graphics.setColor(1,1,1, 1-(gametime-recentdeath)/0.5)
    love.graphics.draw(eyes, carlx-objects.ball.shape:getRadius(), carly-objects.ball.shape:getRadius()-yoff, 0, (objects.ball.shape:getRadius()*2)/eyes:getWidth(), (objects.ball.shape:getRadius()*2)/eyes:getHeight())
    love.graphics.pop()
  end
end

this.renderWorld = function(camera)
  -- grid
  local i
  if seedebug then
    love.graphics.setLineWidth(1)

    local x,y = camera:worldCoords(0,0)
    local x2,y2 = camera:worldCoords(love.graphics.getWidth(),love.graphics.getHeight())

    for i = -800, 1000 do
      love.graphics.setColor(1,1,1,0.7)
      love.graphics.line(i*12, y, i*12, y2)
    end

    for i = 0, 1200 do
      love.graphics.setColor(1,1,1,0.7)
      love.graphics.line(x, i*12, x2, i*12)
    end

    love.graphics.setColor(1,1,1,0.8)
    love.graphics.setLineWidth(4)
    love.graphics.line(0, y, 0, y2)
    love.graphics.line(x, 0, x2, 0)
  end

  -- carl

  local carlx, carly = objects.ball.body:getPosition()

  if oldcarlpos[1] ~= nil then
    renderCarl(oldcarlpos[1], oldcarlpos[2], 0.3, camera)
  end

  renderCarl(objects.ball.body:getX(), objects.ball.body:getY(), 1.0, camera)
  
   -- world boundaries / Cheap World Border Wind Trick
  if #particles == 0 then freshparticle() end
  for i,p in ipairs(particles) do
    love.graphics.setColor(1,1,1, 2-(gametime-p.borndate-0.4))
    love.graphics.rectangle('fill', -500+(gametime-p.borndate)*300, p.y, 6, 3)

    if 2-(gametime-p.borndate-0.4) < 0 and not pause then
      table.remove(particles, i)
    end
  end

  -- grounde
  for _,g in ipairs(objects.grounds) do
    if g.body:isDestroyed() then return end
    local data = g.body:getUserData()

    if g.shape:type() == "CircleShape" then
      local x,y = g.body:getPosition()
      love.graphics.setColor(data.color)
      love.graphics.circle('fill', x, y, g.shape:getRadius())
      love.graphics.setColor(table.add(data.color, -0.3))
      love.graphics.circle('line', x, y, g.shape:getRadius())
    else
      love.graphics.setColor(data.color)
      love.graphics.polygon("fill", g.body:getWorldPoints(g.shape:getPoints()))
      love.graphics.setColor(table.add(data.color, -0.3))
      love.graphics.polygon("line", g.body:getWorldPoints(g.shape:getPoints()))
    end
  end

  -- drawing gun and the bullet (???)
  local gun = sprites["gun"]

  if carlweapon == 1 then
    gun = sprites["bat"]
  end

  local gunscale = (objects.ball.shape:getRadius() * 3) / gun:getWidth()
  local gunwidth = gun:getWidth() * gunscale
  
  local mx, my = camera:worldCoords(aimpos[1], aimpos[2])
  local carlrot = math.atan2(my-carly, mx-carlx)
  local carlschutrot = math.atan2(carlschutloc[2]-carlschutorigin[2], carlschutloc[1]-carlschutorigin[1])

  love.graphics.setColor(1,1,1,carlschut/40)

  if carlschut > 0 and carlweapon == 0 and carlschutorigin ~= carlschutloc then
    -- multiply the location so the ray doesnt stop at where youre aiming (thank you box2d for making me do this)
    local multipliedloc = {carlschutloc[1] + (carlschutloc[1]-carlschutorigin[1])*2000,
    carlschutloc[2] + (carlschutloc[2]-carlschutorigin[2])*2000}

    -- the bullet needs to come out of the gun, not out of carl
    local schutoriginoffset = {carlschutorigin[1] + math.cos(carlschutrot) * gunwidth, carlschutorigin[2] + math.sin(carlschutrot) * gunwidth}

    -- get the lowest dist manually (thanks once again box2d)
    local lowestdist = {nil, {multipliedloc[1], multipliedloc[2]}}

    -- cast the ray
    world:rayCast(schutoriginoffset[1], schutoriginoffset[2], multipliedloc[1], multipliedloc[2], function(_, x, y)
      local dist = math.abs(carlschutorigin[1] - x) + math.abs(carlschutorigin[2] - y)

      if lowestdist[1] == nil or dist < lowestdist[1] then
        lowestdist = {dist, {x, y}}
      end

      -- stop the ray on ANY collision
      return 1
    end)

    love.graphics.line(schutoriginoffset[1], schutoriginoffset[2], lowestdist[2][1], lowestdist[2][2])
  end

  love.graphics.setColor(1,1,1)
  if not carldead and not ineditor then
    if carlweapon ~= 2 then
      -- fuck this code btw
      love.graphics.draw(gun, carlx - math.cos(carlrot) * carlschut/5, carly - math.sin(carlrot) * carlschut/5 + objects.ball.shape:getRadius()/4, carlrot, gunscale, gunscale * ((math.abs(carlrot) < math.pi/2) and 1 or -1))
    end
  end
end

local lasthover = 0

this.renderPause = function()
  love.graphics.setFont(fonts[2])

  local buttonwidth = love.graphics.getWidth() / 3
  local buttonheight = love.graphics.getHeight() / 20
  local buttonx = (love.graphics.getWidth() - buttonwidth) / 2

  local centeredoffset = (love.graphics.getHeight()-(buttonheight+10)*#buttons-10)/2

  love.graphics.setColor(0.12, 0.12, 0.12, math.min((love.timer.getTime() - recentpause) * 3, 0.4))
  love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

  local mouseonbuttoncheck = false

  for i,b in ipairs(buttons) do
    -- FUCK tweens
    local thisheight = -buttonheight + ease.outExpo(love.timer.getTime()-recentpause, -centeredoffset/(i*(buttonheight+10)), centeredoffset/(i*(buttonheight+10))+1, 1)*(i*(buttonheight+10)) + centeredoffset -- GOD i hate this code

    love.graphics.push()
    love.graphics.translate(buttonx + buttonwidth / 2, thisheight + buttonheight / 2)
    if mouseInBox(buttonx, thisheight, buttonwidth, buttonheight) then
      mouseonbuttoncheck = i
      if not pointInBox(oldmousepos[1], oldmousepos[2], buttonx, thisheight, buttonwidth, buttonheight) then
        lasthover = love.timer.getTime()
        playSound('doop', 0.6)
      end

      if love.timer.getTime()-lasthover < 0.2 then
        love.graphics.scale(ease.outCirc(love.timer.getTime() - lasthover, 1, 0.05, 0.2))
      else
        love.graphics.scale(1.05)
      end

      if love.mouse.isDown(1) then
        love.graphics.rotate(0.1)
      end
    end
    love.graphics.translate(-buttonx - buttonwidth / 2, -thisheight - buttonheight / 2)

    love.graphics.setColor(0,0,0)
    love.graphics.rectangle('fill', buttonx, thisheight, buttonwidth, buttonheight)
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle('line', buttonx, thisheight, buttonwidth, buttonheight)
    love.graphics.printf(b, buttonx, thisheight + buttonheight / 2 - (love.graphics.getFont():getHeight()) / 2, buttonwidth, 'center')

    love.graphics.pop()
  end
  mouseonbutton = mouseonbuttoncheck
  oldmousepos = {love.mouse.getX(), love.mouse.getY()}
  if touchpos then
    oldmousepos = touchpos
  end
end

this.renderUI = function()
  if not pause and not ineditor then
    -- render the selector thingy
    local canschut = carlschut < 10
    love.graphics.push()
    love.graphics.translate(aimpos[1], aimpos[2])
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle('fill', -5-carlschut-9, -2, 9, 4)
    love.graphics.rectangle('fill', -2, 5+carlschut, 4, 9)
    love.graphics.rectangle('fill', 5+carlschut, -2, 9, 4)
    love.graphics.rectangle('fill', -2, -5-carlschut-9, 4, 9)
    love.graphics.setColor(carlschut/40/3, carlschut/40/3, carlschut/40/3)
    love.graphics.rectangle('line', -5-carlschut-9, -2, 9, 4)
    love.graphics.rectangle('line', -2, 5+carlschut, 4, 9)
    love.graphics.rectangle('line', 5+carlschut, -2, 9, 4)
    love.graphics.rectangle('line', -2, -5-carlschut-9, 4, 9)
    love.graphics.pop()
  end

  if ineditor then
    -- editor mouse stuff
    worldcam:attach()
    if tool ~= 0 and love.mouse.getY() > 50 then
      local mx, my = worldcam:worldCoords(love.mouse.getX(), love.mouse.getY())
      if tool == 1 then
        local radius = 6
        local pos = {mx, my}
        if toolprop ~= nil then
          radius = math.abs(mx - toolprop[1]) + math.abs(my - toolprop[2])
          pos = {toolprop[1], toolprop[2]}
        end

        love.graphics.setColor(1, 1, 0, 0.5)
        love.graphics.circle('fill', pos[1], pos[2], radius)
      elseif tool == 2 then
        local pos = {mx - 3, my - 3}
        local width = 6
        local height = 6

        if toolprop ~= nil then
          pos = {toolprop[1], toolprop[2]}
          width = mx - toolprop[1]
          height = my - toolprop[2]
        end

        love.graphics.setColor(1, 1, 0, 0.5)
        love.graphics.rectangle('fill', pos[1], pos[2], width, height)
      elseif tool == 3 then
        if toolprop ~= nil then
          love.graphics.setLineWidth(3)

          local vertices = {}

          for i,b in ipairs(toolprop) do
            love.graphics.setColor(1, 1, 0, 0.7)
            love.graphics.circle('fill', b[1], b[2], 6)
            if toolprop[i + 1] then
              love.graphics.line(b[1], b[2], toolprop[i + 1][1], toolprop[i + 1][2])
            end

            table.insert(vertices, b[1])
            table.insert(vertices, b[2])
          end

          if #toolprop >= 3 and love.math.isConvex(vertices) then
            love.graphics.setColor(1, 1, 0, 0.4)
            love.graphics.polygon('fill', vertices)
            love.graphics.setColor(1, 1, 0, 0.5)
            love.graphics.polygon('line', vertices)
          end

          if #toolprop >= 3 then
            love.graphics.setColor(1, 1, 0, 0.5)
            love.graphics.line(mx, my, toolprop[1][1], toolprop[1][2])
          end

          love.graphics.setColor(1, 1, 0, 0.5)
          love.graphics.line(toolprop[#toolprop][1], toolprop[#toolprop][2], mx, my)
          love.graphics.circle('fill', mx, my, 6)
        else
          love.graphics.setColor(1, 1, 0, 0.5)
          love.graphics.circle('fill', mx, my, 6)
        end
      end
    end
    worldcam:detach()

    -- editor buttons!
    love.graphics.setColor(0.45,0.45,0.45)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), 50)
    love.graphics.setColor(0.3,0.3,0.3)
    love.graphics.setLineWidth(1)
    love.graphics.line(0, 50, love.graphics.getWidth(), 50)

    local i
    for i = 0,3 do
      local bright = mouseInBox(5 + i * (40 + 2), 5, 40, 40) and 1 or 0.8

      love.graphics.setColor(0.4,0.4,0.4)
      love.graphics.rectangle('fill', 5 + i * (40 + 2), 5, 40, 40)
      love.graphics.setColor(bright, bright, bright)
      love.graphics.draw(sprites['editorbutton'..i], 5 + i * (40 + 2), 5)
    end
  end

  if seedebug then
    -- debug stuff
    local carlx, carly = worldcam:cameraCoords(objects.ball.body:getX(), objects.ball.body:getY())
    local velx, vely = objects.ball.body:getLinearVelocity()

    local xarrow = math.max(math.min(carlx+velx/2, carlx+100), carlx-100)
    local yarrow = math.max(math.min(carly+vely/2, carly+100), carly-100)

    local xarrowoff = (velx > 0) and 10 or -10
    local yarrowoff = (vely > 0) and 10 or -10

    love.graphics.setColor(1,0,0)
    love.graphics.line(carlx, carly, xarrow, carly)
    love.graphics.polygon('fill', {
      xarrow, carly+10,
      xarrow+xarrowoff, carly,
      xarrow, carly-10
    })

    love.graphics.setColor(0,1,0)
    love.graphics.line(carlx, carly, carlx, yarrow)
    love.graphics.polygon('fill', {
      carlx+10, yarrow,
      carlx, yarrow+yarrowoff,
      carlx-10, yarrow
    })

    love.graphics.setColor(1,1,1)
    love.graphics.print(math.floor(velx), xarrow, carly)
    love.graphics.print(math.floor(vely), carlx, yarrow)

    love.graphics.setColor(0,0,0)
    love.graphics.print('x '..carlx..'\n'..
    'y '..carly..'\n'..
    'running at '..speed..'x speed')
  elseif not ineditor then
    local i
    for i = 1, 5 do
      local bullet = sprites['bullet' .. (i <= carlammo and '' or 'empty')]
      local color = (i <= carlammo and 1 or 0.5)

      if carlammo <= 0 then color = 0.1 end

      love.graphics.setColor(color,color,color)
      love.graphics.draw(bullet, bullet:getWidth() * 3.5 * i - bullet:getWidth()*3.0, 3, 0, 3, 3)
    end
  end

  if mobile and not ineditor and not pause then
    love.graphics.setColor(0.3, 0.3, 0.3)

    local marginsize = love.graphics.getWidth() / 20

    joysticksize = love.graphics.getHeight() / 3

    joystickx = joysticksize / 2 + marginsize
    joysticky = love.graphics.getHeight() - joysticksize / 2 - marginsize
    
    love.graphics.circle('fill', joystickx, joysticky, joysticksize / 2)
  
    local touchx, touchy

    if not joysticktouch then
      touchx = joystickx
      touchy = joysticky
    elseif joysticktouch == 'mouse' then
      touchx, touchy = love.mouse.getPosition()
    else
      touchx, touchy = love.touch.getPosition(joysticktouch)
    end

    touchx = math.min(touchx, joystickx + joysticksize / 4)
    touchx = math.max(touchx, joystickx - joysticksize / 4)
    touchy = math.min(touchy, joysticky + joysticksize / 4)
    touchy = math.max(touchy, joysticky - joysticksize / 4)

    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.circle('fill', touchx, touchy, joysticksize / 4)
  end
end

function freshparticle()
  table.insert(particles, {y = math.random(-1000, 800), borndate = gametime})
  gametimer.after(0.07, freshparticle)
end

return this