require "./app"

map GitNotebook.pinion.mount_point do
  run GitNotebook.pinion
end

map "/" do
  run GitNotebook
end
