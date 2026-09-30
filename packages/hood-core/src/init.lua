---@class hood-core.Enums: hood.Enums
---@field VertexLayout hood.VertexLayout
---@field Layout hood.Layout
local core = setmetatable({
	VertexLayout = require("hood-core.vertex_layout"),
	Layout = require("hood-core.layout"),
}, {
	__index = require("hood-core.enums"),
})

---@cast core hood-core.Enums
return core
