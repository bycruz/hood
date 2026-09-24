local vk = require("vkapi")
local vkConversions = require("hood-vk.convert")

---@class hood-vk.TextureView
---@field handle vk.ffi.ImageView
---@field texture hood-vk.Texture
---@field baseArrayLayer integer
---@field layerCount integer
---@field private _fromSwapchain boolean
---@field private device hood-vk.Device
local VKTextureView = {}
VKTextureView.__index = VKTextureView

---@param device hood-vk.Device
---@param texture hood-vk.Texture
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
		device = device,
		handle = handle,
		texture = texture,
		baseArrayLayer = descriptor.baseArrayLayer or 0,
		layerCount = layerCount,
	}, VKTextureView)
end

--- Wrap an existing VkImageView handle (e.g. from a swapchain's pre-created views)
--- without creating a new Vulkan image view.
---@param device hood-vk.Device
---@param texture hood-vk.Texture
---@param handle vk.ffi.ImageView
---@param descriptor hood.TextureViewDescriptor
---@return hood-vk.TextureView
function VKTextureView.fromHandle(device, texture, handle, descriptor)
	return setmetatable({
		device = device,
		handle = handle,
		texture = texture,
		baseArrayLayer = descriptor and descriptor.baseArrayLayer or 0,
		layerCount = (descriptor and descriptor.layerCount) or vk.REMAINING_ARRAY_LAYERS,
		_fromSwapchain = true,
	}, VKTextureView)
end

function VKTextureView:destroy()
	if self._fromSwapchain then return end
	self.device.handle:destroyImageView(self.handle)
end

return VKTextureView
