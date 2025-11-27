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

function print_table (t)
  for key, value in pairs(t) do
    print(key .. ":" .. value)
  end
end

local master = function()
  local mast = {
    master_ratio = 0.5,
    stack = {},
    master = nil,
  }

  local tile_views = function ()
    local res = mez.output.get_resolution(0)

    if #mast.stack == 0 then
      mez.view.set_size(mast.master, res.width, res.height)
      mez.view.set_position(mast.master, 0, 0)
    else
      mez.view.set_size(mast.master, res.width * mast.master_ratio, res.height)
      mez.view.set_position(mast.master, 0, 0)

      for i, stack_id in ipairs(mast.stack) do
        mez.view.set_size(stack_id, res.width * (1 - mast.master_ratio), res.height / #mast.stack)
        mez.view.set_position(stack_id, res.width * mast.master_ratio, (res.height / #mast.stack * (i - 1)))
      end
    end
  end

  mez.hook.add("ViewMapPre", {
    callback = function(v)
      mez.view.set_focused(v)

      if mast.master == nil then
        mast.master = v
      else
        table.insert(mast.stack, #mast.stack + 1, v)
      end

      tile_views()
    end
  })

  mez.hook.add("ViewUnmapPost", {
    callback = function(v)
      if v == mast.master then
        if #mast.stack > 0 then
          mast.master = table.remove(mast.stack, 1)
        else
          mast.master = nil
        end
      else
        for i, id in ipairs(mast.stack) do
          if id == v then
            if i == 1 then
              mez.view.set_focused(mast.master)
            elseif i == #mast.stack then
              mez.view.set_focused(mast.stack[i - 1])
            else
              mez.view.set_focused(mast.stack[i + 1])
            end

            table.remove(mast.stack, i)
          end
        end
      end

      tile_views()
    end
  })

  mez.input.add_keymap("alt|shift", "Return", {
    press = function()
      mez.api.spawn("alacritty")
    end,
  })

  mez.input.add_keymap("alt|shift", "C", {
    press = function ()
      mez.view.close(0)
    end
  })

  mez.input.add_keymap("alt|shift", "q", {
    press = function ()
      mez.api.exit();
    end
  })

  mez.input.add_keymap("alt", "Return", {
    press = function()
      local focused = mez.view.get_focused_id()

      if focused == mast.master then return end

      for i, id in ipairs(mast.stack) do
        if focused == id then
          local t = mast.master
          mast.master = mast.stack[i]
          mast.stack[i] = t
        end
      end

      tile_views()
    end,
  })

  mez.input.add_keymap("alt", "j", {
    press = function ()
      local focused = mez.view.get_focused_id()

      if focused == mast.master then
        mez.view.set_focused(mast.stack[1])
      elseif focused == mast.stack[#mast.stack] then
        mez.view.set_focused(mast.master)
      else
        for i, id in ipairs(mast.stack) do
          -- TODO: use table.find
          if focused == id then
            mez.view.set_focused(mast.stack[i + 1])
          end
        end
      end
    end
  })

  mez.input.add_keymap("alt", "k", {
    press = function ()
      local focused = mez.view.get_focused_id()

      if focused == mast.master then
        mez.view.set_focused(mast.stack[#mast.stack])
      elseif focused == mast.stack[1] then
        mez.view.set_focused(mast.master)
      else
        for i, id in ipairs(mast.stack) do
          -- TODO: use table.find
          if focused == id then
            mez.view.set_focused(mast.stack[i - 1])
          end
        end
      end
    end
  })

  mez.input.add_keymap("alt", "h", {
    press = function()
      if mast.master_ratio > 0.15 then
        mast.master_ratio = mast.master_ratio - 0.05
        tile_views()
      end
    end
  })

  mez.input.add_keymap("alt", "l", {
    press = function()
      if mast.master_ratio < 0.85 then
        mast.master_ratio = mast.master_ratio + 0.05
        tile_views()
      end
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
end

master()

for i = 1, 12 do
  mez.input.add_keymap("ctrl|alt", "XF86Switch_VT_"..i, {
    press = function() mez.api.change_vt(i) end
  })
end

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
  local focused_output = mez.output.get_focused_id()
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
