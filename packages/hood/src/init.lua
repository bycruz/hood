---@class hood: hood-core.Enums
---@field Instance hood.Instance
---@field VertexLayout hood.VertexLayout
---@field Layout hood.Layout
---@field ColorWrites hood.ColorWrites
---@type hood
local hood = setmetatable({
	Instance = require("hood.instance"),
}, {
	__index = require("hood-core"),
})

return hood
