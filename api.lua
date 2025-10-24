---------------- Windowing ----------------
local root_tile = {
	tile_parent = nil,
	direction = "horizontal", -- or "vertical"
	children = { },
}

local window = {
	pos = { x = 100, y = 200 },
	size = { w = 640, h = 360 },
	window = nil
}

-- Master stack as an example, using attach asside
mez.add_hook("NewWindow", {
	-- pattern = { "foot", "firefox" },
	callback = function (new_window)
		local root = mez.get_root_tile() -- Maybe mez.get_current_workspace().root_tile

		if (#root.children == 0) then
			root.children[#root.children + 1] = new_window
		elseif (#root.children == 1) then
			root.children[#root.children + 1] = mez.tile.create(root, "vertical", { new_window })
		else
			local stack = root.children[2]
			stack.children[#stack.children + 1] = new_window
		end
	end
})

-- Floating
mez.add_hook("NewWindow", {
	callback = function (new_window)
		local last_window = mez.floating_windows[#mez.floating_windows]

		new_window.pos = { last_window.pos.x + 50, last_window.pos.y + 50 }
		new_window.size = last_window.size

		mez.floating_windows[#mez.floating_windows + 1] = new_window

	end
})

mez.add_hook("NewWindowPre", {
	callback = function (new_window)
		local last_window = mez.floating_windows[#mez.floating_windows]

		new_window.pos = { last_window.pos.x + 50, last_window.pos.y + 50 }
		new_window.size = last_window.size

		mez.floating_windows[#mez.floating_windows + 1] = new_window

	end
})

---------------- Options ----------------

mez.options = {
	windows = {
		borders = {
			{ thickness = 3, color = "#ff0000" },
			{ thickness = 3, color = "#00ff00" },
			{ thickness = 3, color = "#0000ff" },
		},
		border_radius = 5,
		gaps = {
			inner = 10,
			outer = 100 -- lukesmith ahh desktop
		}
	},
	popups = nil, -- same options as windows, mimic window options if nil
	output = {
		["eDP-1"] = { 
			brightness = 0.25,
			rate = "60.00",
			resolution = "1920x1080",
			right_of = "HDMI-1"
		},
		["HDMI-1"] = { }
	}
}

---------------- Keybinds ----------------
mez.add_keybind("modifier", "keycode", function()
  -- callback
end, {
    -- additional options
})

-- Virtual terminal switching
