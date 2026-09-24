-- What both of hood's backends are made of: the enums the whole of hood shares, and the
-- vertex layout a pipeline is described with. Neither backend owns them, and a program that
-- runs on one of them should not have to install the other to reach them.
local core = {}

core.VertexLayout = require("hood-core.vertex_layout")

for name, value in pairs(require("hood-core.enums")) do
	core[name] = value
end

return core
