---@class hood.CommandBuffer
local CommandBuffer = VULKAN and require("hood.vk.command_buffer")
	or require("hood.gl.command_buffer") --[[@as hood.CommandBuffer]]

return CommandBuffer
