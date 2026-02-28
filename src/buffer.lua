---@alias hood.Buffer.DataType "u32" | "f32"

---@class hood.Buffer
---@field destroy fun(self: hood.Buffer)
local Buffer = VULKAN and require("hood.buffer.vk") or require("hood.buffer.gl") --[[@as hood.Buffer]]

return Buffer
