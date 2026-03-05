local vk = require("vkapi")
local vkConversions = require("hood.convert.vk")

---@class hood.vk.TextureView
---@field handle vk.ffi.ImageView
local VKTextureView = {}
VKTextureView.__index = VKTextureView

---@param device hood.vk.Device
---@param texture hood.vk.Texture
---@param descriptor hood.TextureViewDescriptor
function VKTextureView.new(device, texture, descriptor)
	local viewType ---@type vk.ImageViewType
	if descriptor.dimension then
		viewType = vkConversions.textureViewType[descriptor.dimension]
	else -- Infer from texture type
		viewType = texture.viewType
	end

	local format ---@type vk.Format
	if descriptor.format then
		format = vkConversions.textureFormat[descriptor.format]
	else -- Infer from texture format
		format = texture.format
	end

	local aspect ---@type vk.ImageAspectFlagBits
	if descriptor.aspect then
		aspect = vkConversions.textureAspect[descriptor.aspect]
	else -- Infer from texture format
		if texture.isDepth then
			aspect = vk.ImageAspectFlagBits.DEPTH
		else
			aspect = vk.ImageAspectFlagBits.COLOR
		end
	end

	local layerCount = descriptor.layerCount or vk.REMAINING_ARRAY_LAYERS

	local handle = device.handle:createImageView({
		image = texture.handle,
		viewType = viewType,
		format = format,
		subresourceRange = {
			aspectMask = aspect,
			baseMipLevel = descriptor.baseMipLevel or 0,
			levelCount = descriptor.levelCount or 1,
			baseArrayLayer = descriptor.baseArrayLayer or 0,
			layerCount = layerCount,
		},
		components = nil -- TODO: Support swizzling
	})

	return setmetatable({
		handle = handle,
		texture = texture,
		baseArrayLayer = descriptor.baseArrayLayer or 0,
		layerCount = layerCount,
	}, VKTextureView)
end

return VKTextureView
