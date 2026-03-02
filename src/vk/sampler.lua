local vk = require("vkapi")
local vkConvert = require("hood.convert.vk")

---@class hood.vk.Sampler
---@field handle vk.ffi.Sampler
---@field device hood.vk.Device
local VKSampler = {}
VKSampler.__index = VKSampler

---@param device hood.vk.Device
---@param desc hood.SamplerDescriptor
function VKSampler.new(device, desc)
	local handle = device.handle:createSampler({
		magFilter = vkConvert.filterMode[desc.magFilter],
		minFilter = vkConvert.filterMode[desc.minFilter],
		mipmapMode = vk.SamplerMipmapMode.LINEAR,
		addressModeU = vkConvert.addressMode[desc.addressModeU],
		addressModeV = vkConvert.addressMode[desc.addressModeV],
		addressModeW = vkConvert.addressMode[desc.addressModeW],
		mipLodBias = 0,
		anisotropyEnable = desc.maxAnisotropy and 1 or 0,
		maxAnisotropy = desc.maxAnisotropy or 1.0,
		compareEnable = desc.compareOp and 1 or 0,
		compareOp = desc.compareOp and vkConvert.compareFunction[desc.compareOp] or 0,
		minLod = desc.lodMinClamp or 0,
		maxLod = desc.lodMaxClamp or 1000,
		borderColor = vk.BorderColor.FLOAT_TRANSPARENT_BLACK,
		unnormalizedCoordinates = 0,
	})

	return setmetatable({ handle = handle, device = device }, VKSampler)
end

function VKSampler:destroy()
	self.device.handle:destroySampler(self.handle)
end

return VKSampler
