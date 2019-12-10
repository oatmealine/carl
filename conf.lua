function love.conf(t)
  t.identity = 'carl'
  t.appendidentity = true
  t.version = "11.3"

  t.window.title = "carl"
  t.window.icon = 'assets/sprites/carleyes.png'
  t.window.width = 1200
  t.window.height = 800
  t.window.minwidth = 400
  t.window.minheight = 300
  t.window.borderless = false
  t.window.resizable = true

  t.modules.thread = false
  t.modules.touch = false
  t.modules.video = false
end