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

-- this is an example
mez.input.add_keymap("alt", "a", {
  press = function()
    print("hello from my keymap")
  end
})

mez.input.add_keymap("alt", "Return", {
  press = function()
    mez.api.spawn("foot")
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
		local view = mez.view.get_focused_id()
		mez.view.set_position(view, 100, 100)
		mez.view.set_size(view, 100, 100)
	end
})

mez.input.add_keymap("alt", "v", {
	press = function ()
		local view = mez.view.get_focused_id()
		mez.view.set_position(view, 100, 100)
		mez.view.set_size(view, 100, 100)
	end
})

mez.input.add_keymap("alt", "Tab", {
	press = function ()
		print("alt+tab")

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

mez.hook.add("ViewMapPre", {
  callback = function(v)
    mez.view.set_size(v, 1000, 1000)
	mez.view.set_focused(v)
  end
})
