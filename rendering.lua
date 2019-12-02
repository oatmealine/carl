local this = {}
local particles = {}

this.renderWorld = function(camera)
  -- carl
  local mx, my = camera:worldCoords(aimpos[1], aimpos[2])
  local carlrot = math.atan2(my-objects.ball.body:getY(), mx-objects.ball.body:getX())
  local carlflipped = math.abs(carlrot) < math.pi/2

  local eyes = sprites["carleyes"]

  if not carldead then
    love.graphics.setColor(1, 198/255, 13/255)
    love.graphics.circle("fill", objects.ball.body:getX(), objects.ball.body:getY(), objects.ball.shape:getRadius())

    love.graphics.setColor(aimpos[3] and {0.9,0.9,0.9} or {0.1,0.1,0.1})
    love.graphics.circle("line", objects.ball.body:getX(), objects.ball.body:getY(), objects.ball.shape:getRadius())

    love.graphics.setColor(1,1,1)
    if not seedebug then
      love.graphics.draw(eyes, objects.ball.body:getX()-objects.ball.shape:getRadius() * (carlflipped and 1 or -1), objects.ball.body:getY()-objects.ball.shape:getRadius(), 0, (objects.ball.shape:getRadius()*2)/eyes:getWidth() * (carlflipped and 1 or -1), (objects.ball.shape:getRadius()*2)/eyes:getHeight())
    end
  else
    eyes = sprites["carleyescry"]
    local yoff = ease.outQuad(love.timer.getTime()-recentdeath, 0, 1, 0.6)*200

    love.graphics.push()

    love.graphics.translate(objects.ball.body:getX()+objects.ball.shape:getRadius()/2, objects.ball.body:getY()+objects.ball.shape:getRadius()/2-yoff)
    love.graphics.rotate(yoff/200*math.pi/3*2)
    love.graphics.translate(-objects.ball.body:getX()-objects.ball.shape:getRadius()/2, -objects.ball.body:getY()-objects.ball.shape:getRadius()/2+yoff)

    love.graphics.setColor(1, 198/255, 13/255, 1-(love.timer.getTime()-recentdeath)/0.5)
    love.graphics.circle("fill", objects.ball.body:getX(), objects.ball.body:getY()-yoff, objects.ball.shape:getRadius())

    love.graphics.setColor(0.1,0.1,0.1, 1-(love.timer.getTime()-recentdeath)/0.5)
    love.graphics.circle("line", objects.ball.body:getX(), objects.ball.body:getY()-yoff, objects.ball.shape:getRadius())

    love.graphics.setColor(1,1,1, 1-(love.timer.getTime()-recentdeath)/0.5)
    love.graphics.draw(eyes, objects.ball.body:getX()-objects.ball.shape:getRadius(), objects.ball.body:getY()-objects.ball.shape:getRadius()-yoff, 0, (objects.ball.shape:getRadius()*2)/eyes:getWidth(), (objects.ball.shape:getRadius()*2)/eyes:getHeight())
    love.graphics.pop()
  end

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
  for _,g in ipairs(objects.dirt) do
    love.graphics.setColor(156/255, 83/255, 0)
    love.graphics.polygon("fill", g.body:getWorldPoints(g.shape:getPoints()))
    love.graphics.setColor(207/255, 110/255, 0)
    love.graphics.polygon("line", g.body:getWorldPoints(g.shape:getPoints()))
  end

  for _,g in ipairs(objects.grounds) do
    love.graphics.setColor(0.28, 0.63, 0.05)
    love.graphics.polygon("fill", g.body:getWorldPoints(g.shape:getPoints()))
    love.graphics.setColor(0.14, 0.31, 0.02)
    love.graphics.polygon("line", g.body:getWorldPoints(g.shape:getPoints()))
  end

  -- drawing gun and the bullet (???)
  local gun = sprites["gun"]
  local gunscale = (objects.ball.shape:getRadius()*3)/gun:getWidth()

  local gunshotdistance = {carlschutorigin[1]-carlschutloc[1], carlschutorigin[2]-carlschutloc[2]}

  love.graphics.setColor(1,1,1,carlschut/40)
  love.graphics.line(carlschutorigin[1], carlschutorigin[2], carlschutloc[1]-(gunshotdistance[1]*math.abs(love.graphics.getWidth()*2/(gunshotdistance[1]+gunshotdistance[2]))), carlschutloc[2]-(gunshotdistance[2]*math.abs(love.graphics.getWidth()*2/(gunshotdistance[1]+gunshotdistance[2])))) -- this code sucks

  love.graphics.setColor(1,1,1)
  if not carldead then
    love.graphics.draw(gun, objects.ball.body:getX(), objects.ball.body:getY(), carlrot, gunscale, gunscale * (carlflipped and 1 or -1))
  end
end

local lasthover = 0

this.renderPause = function()
  love.graphics.setFont(fonts[2])
  local buttonwidth = love.graphics.getWidth()/3
  local buttonheight = love.graphics.getHeight()/20
  local buttonx = (love.graphics.getWidth()-buttonwidth)/2

  local centeredoffset = (love.graphics.getHeight()-(buttonheight+10)*#buttons-10)/2

  love.graphics.setColor(0.12, 0.12, 0.12, math.min((love.timer.getTime()-recentpause)*3, 0.4))
  love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

  local mouseonbuttoncheck = false

  for i,b in ipairs(buttons) do
    local thisheight = -buttonheight + ease.outExpo(love.timer.getTime()-recentpause, -centeredoffset/(i*(buttonheight+10)), centeredoffset/(i*(buttonheight+10))+1, 1)*(i*(buttonheight+10)) + centeredoffset -- GOD i hate this code

    love.graphics.push()
    love.graphics.translate(buttonx+buttonwidth/2, thisheight+buttonheight/2)
    if mouseInBox(buttonx, thisheight, buttonwidth, buttonheight) then
      mouseonbuttoncheck = i
      if not pointInBox(oldmousepos[1], oldmousepos[2], buttonx, thisheight, buttonwidth, buttonheight) then
        lasthover = love.timer.getTime()
      end

      if love.timer.getTime()-lasthover < 0.2 then
        love.graphics.scale(ease.outCirc(love.timer.getTime()-lasthover, 1, 0.05, 0.2))
      else
        love.graphics.scale(1.05)
      end

      if love.mouse.isDown(1) then
        love.graphics.rotate(0.1)
      end
    end
    love.graphics.translate(-buttonx-buttonwidth/2, -thisheight-buttonheight/2)

    love.graphics.setColor(0,0,0)
    love.graphics.rectangle('fill', buttonx, thisheight, buttonwidth, buttonheight)
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle('line', buttonx, thisheight, buttonwidth, buttonheight)
    love.graphics.printf(b, buttonx, thisheight+buttonheight/2-(love.graphics.getFont():getHeight())/2, buttonwidth, 'center')

    love.graphics.pop()
  end
  mouseonbutton = mouseonbuttoncheck
  oldmousepos = {love.mouse.getX(), love.mouse.getY()}
end

this.renderUI = function()
  if not pause then
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

  if seedebug then
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
    love.graphics.print('x '..objects.ball.body:getX()..'\ny '..objects.ball.body:getY())
  else
    local i
    for i = 1, 5 do
      local bullet = sprites['bullet' .. (i <= carlammo and '' or 'empty')]
      local color = (i <= carlammo and 1 or 0.5)

      if carlammo <= 0 then color = 0.1 end

      love.graphics.setColor(color,color,color)
      love.graphics.draw(bullet, bullet:getWidth() * 3.5 * i - bullet:getWidth()*3.0, 3, 0, 3, 3)
    end
  end
end

function freshparticle()
  table.insert(particles, {y = math.random(-1000, 800), borndate = gametime})
  gametimer.after(0.07, freshparticle)
end

return this