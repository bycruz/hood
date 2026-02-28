---@class hood.AdapterConfig
---@field powerPreference? "low-power" | "high-performance"

---@class hood.Adapter
---@field requestDevice fun(self: hood.Adapter): hood.Device
local Adapter = VULKAN and require("hood.vk.adapter") or require("hood.gl.adapter") --[[@as hood.Adapter]]

return Adapter
