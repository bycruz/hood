---@class hood.CommandBuffer
local CommandBuffer = VULKAN and require("hood.command_buffer.vk")
	or require("hood.command_buffer.gl") --[[@as hood.CommandBuffer]]

return CommandBuffer
