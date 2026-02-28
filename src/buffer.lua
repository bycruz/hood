---@alias hood.Buffer.DataType "u32" | "f32"

---@class hood.Buffer
---@field destroy fun(self: hood.Buffer)
local Buffer = VULKAN and require("hood.vk.buffer") or require("hood.gl.buffer") --[[@as hood.Buffer]]

return Buffer
