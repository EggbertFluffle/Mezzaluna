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

mez.input.add_keymap("alt", "Return", {
  press = function()
    -- foot doesnt resize on uneven columns
    -- this means alacritty is just better (period)
    mez.api.spawn("alacritty")
  end,
})

mez.input.add_keymap("alt", "c", {
  press = function ()
    mez.api.close()
  end
})

mez.input.add_keymap("alt", "q", {
  press = function ()
    mez.api.exit();
  end
})

mez.input.add_keymap("alt", "v", {
  press = function ()
    local id = mez.view.get_focused_id()

    local details = mez.view.get_details(id);
    print(details.title);
    print(details.app_id);
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

mez.input.add_keymap("alt", "t", {
  press = function() tiler() end
})

local tiler = function ()
  local all = mez.view.get_all_ids()

  for i, id in ipairs(all) do
    mez.view.set_position(id, (1920 / #all) * (i - 1), 0)
    mez.view.set_size(id, 1920 / #all, 1080)
  end
end

mez.hook.add("ViewMapPre", {
  callback = function(v)
    tiler()
    mez.view.set_focused(v)
  end
})
