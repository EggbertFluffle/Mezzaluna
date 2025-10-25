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
mez.api.add_keymap("alt", "a", function()
  print("hello from my keymap")
end)

mez.api.add_keymap("alt", "t", function()
	print("spawning foot")
	mez.api.spawn("foot")
end)

mez.api.add_keymap("alt", "p", function()
	print("spawning foot")
	mez.api.spawn("wmenu-run")
end)

-- mez.input.add_keymap("alt", "a", {
--   press = function()
--     print("hello from my keymap")
--   end,
--   release = function()
--     print("goodbye from my keymap")
--   end
-- })
