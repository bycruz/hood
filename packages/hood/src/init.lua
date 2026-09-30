---@class hood: hood-core.Enums
local hood = setmetatable({
	Instance = require("hood.instance"),
}, {
	__index = require("hood-core"),
})

---@cast hood hood-core.Enums
return hood
