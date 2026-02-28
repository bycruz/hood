---@class hood.TextureView
local TextureView = VULKAN and require("hood.texture_view.vk")
	or require("hood.texture_view.gl") --[[@as hood.TextureView]]

---@class hood.TextureViewDescriptor
---@field format hood.TextureFormat
---@field dimension hood.TextureViewDimension
---@field usages hood.TextureUsage[]
---@field aspect hood.TextureAspect
---@field baseMipLevel number
---@field levelCount number?
---@field baseArrayLayer number
---@field layerCount number?
