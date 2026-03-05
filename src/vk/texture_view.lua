local vkConversions = require("hood.convert.vk")

---@class hood.vk.TextureView
local VKTextureView = {}
VKTextureView.__index = VKTextureView

---@param device hood.vk.Device
---@param texture hood.vk.Texture
---@param descriptor hood.TextureViewDescriptor
function VKTextureView.new(device, texture, descriptor)
	local handle = device.handle:createImageView({
		image = texture.handle,
		viewType = vkConversions.textureViewDimension[descriptor.dimension],
		format = vkConversions.textureFormat[descriptor.format],
		subresourceRange = {
			aspectMask = vkConversions.textureAspect[descriptor.aspect],
			baseMipLevel = descriptor.baseMipLevel or 0,
			levelCount = descriptor.levelCount or 1,
			baseArrayLayer = descriptor.baseArrayLayer or 0,
			layerCount = descriptor.layerCount or 1,
		},
		components = nil -- TODO: Support swizzling
	})

	return setmetatable({ handle = handle }, VKTextureView)
end

return VKTextureView
