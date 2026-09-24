-- TODO: turn this into a feature flag when those exist in lpm
---@type boolean
VULKAN = os.getenv("VULKAN") == "1"

---@class hood: hood.Enums
local hood = {}

hood.Instance = require("hood.instance")
hood.VertexLayout = require("hood-core.vertex_layout")

local enums = require("hood-core.enums")
for k, v in pairs(enums) do
	hood[k] = v
end

return hood
