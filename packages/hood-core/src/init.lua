---@class hood-core.Enums: hood.Enums
---@field VertexLayout hood.VertexLayout
---@field Layout hood.Layout
---@type hood-core.Enums
local core = setmetatable({
	VertexLayout = require("hood-core.vertex_layout"),
	Layout = require("hood-core.layout"),
	ColorWrites = require("hood-core.enums").ColorWrites,
}, {
	__index = require("hood-core.enums"),
})

return core
