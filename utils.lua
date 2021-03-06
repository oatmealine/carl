function mouseInBox(x,y,w,h)
  local mx,my = love.mouse.getPosition()
  return pointInBox(mx,my,x,y,w,h)
end

function pointInBox(x1,y1,x2,y2,w,h)
  return x1 > x2 and x1 < x2+w and y1 > y2 and y1 < y2+h
end

function string.starts(str, start)
  return str:sub(1, #start) == start
end

function string.ends(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end

function table.add(table, num)
  local new = {}
  for i,v in ipairs(table) do
    new[i] = v + num
  end
  return new
end

function math.round(num)
  if num%1 > 0.4 then
    return math.ceil(num)
  else
    return math.floor(num)
  end
end

function table.pack(...)
    return {...}
end