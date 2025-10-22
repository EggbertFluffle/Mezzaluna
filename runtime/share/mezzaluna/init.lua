local env_conf = os.getenv("XDG_CONFIG_HOME")
if not env_conf then
  env_conf = os.getenv("HOME")
  if not env_conf then
    error("Couldn't determine potential config directory is $HOME set?")
  end
  env_conf = env_conf.."/.config/"
end

mez.path.config = env_conf.."/mez/init.lua"
package.path = package.path..";"..env_conf.."/mez/lua/?.lua"
