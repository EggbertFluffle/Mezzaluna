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
