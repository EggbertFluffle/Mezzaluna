local env_conf = os.getenv("XDG_CONFIG_HOME")
if not env_conf then
  env_conf = os.getenv("HOME")
  if not env_conf then
    error("Couldn't determine potential config directory is $HOME set?")
  end
  env_conf = mez.fs.joinpath(env_conf, ".config")
end

mez.path.config = mez.fs.joinpath(env_conf, "mez", "init.lua")
package.path = package.path..";"..mez.fs.joinpath(env_conf, "mez", "lua", "?.lua")

local test = function()
  -- View tests
  mez.api.spawn("alacritty")
  local focused_view = mez.view.get_focused_id()
  print(focused_view)

  for i = 0,4 do
    mez.api.spawn("alacritty")
  end

  local view_ids = mez.view.get_all_ids()
  for _, id in ipairs(view_ids) do
    print(id)
    mez.view.close(id)
  end

  print(mez.view.get_title(0))
  print(mez.view.get_title(focused_view))
  print(mez.view.get_app_id(0))
  print(mez.view.get_app_id(focused_view))

  mez.view.set_position(0, 100, 100)
  mez.view.set_position(focused_view, 200, 200)
  mez.view.set_size(0, 100, 100)
  mez.view.set_size(focused_view, 200, 200)

  -- Output tests
  local focused_output = mez.output.get_focused_id();
  print(focused_output)

  local output_ids = mez.output.get_all_ids()
  for _, id in ipairs(output_ids) do
    print(id)
  end

  print(mez.output.get_name(0))
  print(mez.output.get_name(focused_output))
  print(mez.output.get_description(0))
  print(mez.output.get_description(focused_output))
  print(mez.output.get_model(0))
  print(mez.output.get_model(focused_output))
  print(mez.output.get_make(0))
  print(mez.output.get_make(focused_output))
  print(mez.output.get_serial(0))
  print(mez.output.get_serial(focused_output))
  print(mez.output.get_rate(0))
  print(mez.output.get_rate(focused_output))

  local res = mez.output.get_resolution(0)
  print(res.width .. ", " .. res.height)
end

mez.input.add_keymap("alt", "Return", {
  press = function()
    -- foot doesnt resize on uneven columns
    -- this means alacritty is just better (period)
    mez.api.spawn("alacritty")
  end,
})

mez.input.add_keymap("alt", "c", {
  press = function ()
    print("closing")
    mez.view.close(0)
  end
})

mez.input.add_keymap("alt", "q", {
  press = function ()
    mez.api.exit();
  end
})

mez.input.add_keymap("alt", "v", {
  press = function ()
    print(mez.view.check())
  end
})

mez.input.add_keymap("alt", "Tab", {
  press = function ()
    local focused = mez.view.get_focused_id()
    local all = mez.view.get_all_ids()

    for _, id in ipairs(all) do
      if id ~= focused then
        mez.view.set_focused(id)
        return
      end
    end
  end
})

for i = 1, 12 do
  mez.input.add_keymap("ctrl|alt", "XF86Switch_VT_"..i, {
    press = function() mez.api.change_vt(i) end
  })
end

local tiler = function ()
  local res = mez.output.get_resolution(mez.output.get_focused_id())
  local all = mez.view.get_all_ids()

  for i, id in ipairs(all) do
    mez.view.set_position(id, (res.width/ #all) * (i - 1), 0)
    mez.view.set_size(id, res.width / #all, res.height)
  end
end

mez.input.add_keymap("alt", "t", {
  press = function() test() end
})

mez.hook.add("ViewMapPre", {
  callback = function(v)
    tiler()
    mez.view.set_focused(v)
  end
})
