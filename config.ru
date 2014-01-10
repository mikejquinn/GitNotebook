require "./app"

map GloGist.pinion.mount_point do
  run GloGist.pinion
end

map "/" do
  run GloGist
end
