local vkConvert = require("hood.convert.vk")

---@class hood.vk.TextureView
local VKTextureView = {}
VKTextureView.__index = VKTextureView

---@param texture hood.vk.Texture
---@param descriptor hood.TextureViewDescriptor
function VKTextureView.new(texture, descriptor)
	local format = vkConvert.textureFormat[descriptor.format]
end

return VKTextureView
