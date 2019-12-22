-- constants

-- change this to true when presenting (for school project)
demo = false

-- how the gameplay feels
GRAVITY = 9.81*64
MOVEFORCE = 400
JUMPFORCE = 12000

-- key binding mappers
function reverseMapper(raw)
  return -raw
end

function deadzoneMapper(raw, old, args)
  return (math.abs(raw) < math.abs(args.deadzone or 0.1)) and 0 or raw
end

-- key bindings
function bindings()
  -- gun shoot
  ctrl:bind("fire", {"keyboard", "e"})
  ctrl:bind("fire", {"gamepad", "default", "axis", "triggerright"})
  ctrl:bind("fire", {"mouse", "left"})

  -- hardening
  ctrl:bind("harden", {"mouse", "right"})
  ctrl:bind("harden", {"gamepad", "default", "axis", "triggerleft"})
  ctrl:bind("harden", {"keyboard", "q"})

  -- movement
  ctrl:bind("left", {"keyboard", "a"})
  ctrl:bind("right", {"keyboard", "d"})
  ctrl:bind("down", {"keyboard", "s"})

  ctrl:bind("jump", {"keyboard", "w"})
  ctrl:bind("jump", {"keyboard", "space"})
  ctrl:bind("jump", {"gamepad", "default", "button", "a"})

  ctrl:bind("left", {"gamepad", "default", "axis", "leftx"}, {mapper = {func = reverseMapper}})
  ctrl:bind("right", {"gamepad", "default", "axis", "leftx"})
  ctrl:bind("jump", {"gamepad", "default", "axis", "lefty"}, {mapper = {func = reverseMapper}})

  -- aiming
  ctrl:bind("cursx", {"gamepad", "default", "axis", "rightx"}, {mapper = {func = deadzoneMapper, args = {deadzone = 0.3}}})
  ctrl:bind("cursy", {"gamepad", "default", "axis", "righty"}, {mapper = {func = deadzoneMapper, args = {deadzone = 0.3}}})

  -- meta
  ctrl:bind("reset", {"keyboard", "r"})
  ctrl:bind("reset", {"gamepad", "default", "button", "leftshoulder"})
  ctrl:bind("fullscreen", {"keyboard", "f11"})
  ctrl:bind("pause", {"keyboard", "escape"})
  ctrl:bind("pause", {"gamepad", "default", "button", "rightshoulder"})
  ctrl:bind("pausepeek", {"keyboard", "tab"})
  -- ctrl:bind("pause", {"gamepad", "default", "pause"})

  -- debug hotkeys
  ctrl:bind("editor", {"keyboard", "f2"})
  ctrl:bind("debug", {"keyboard", "f3"})
  ctrl:bind("reload", {"keyboard", "f5"})
end