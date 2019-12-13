-- constants

-- change this to true when presenting (for school project)
demo = false

-- how the gameplay feels
GRAVITY = 9.81*64
MOVEFORCE = 400
JUMPFORCE = 12000

-- key bindings
function bindings()
  -- gun shoot
  ctrl:bind("fire", {"keyboard", "e"})
  ctrl:bind("fire", {"gamepad", "default", "button", "x"})
  ctrl:bind("fire", {"mouse", "left"})

  -- hardening
  ctrl:bind("harden", {"mouse", "right"})
  ctrl:bind("harden", {"keyboard", "q"})

  -- movement
  ctrl:bind("left", {"keyboard", "a"})
  ctrl:bind("right", {"keyboard", "d"})
  ctrl:bind("down", {"keyboard", "s"})

  ctrl:bind("jump", {"keyboard", "w"})
  ctrl:bind("jump", {"keyboard", "space"})
  ctrl:bind("jump", {"gamepad", "default", "button", "a"})

  -- meta
  ctrl:bind("reset", {"keyboard", "r"})
  ctrl:bind("fullscreen", {"keyboard", "f11"})
  ctrl:bind("pause", {"keyboard", "escape"})
  ctrl:bind("pausepeek", {"keyboard", "tab"})
  -- ctrl:bind("pause", {"gamepad", "default", "pause"})

  -- debug hotkeys
  ctrl:bind("editor", {"keyboard", "f2"})
  ctrl:bind("debug", {"keyboard", "f3"})
  ctrl:bind("reload", {"keyboard", "f5"})
end