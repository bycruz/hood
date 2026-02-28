local hood = require("hood")
local vk = require("vkapi")

---@class hood.vk.Sampler
---@field handle vk.ffi.Sampler
---@field device hood.vk.Device
local VKSampler = {}
VKSampler.__index = VKSampler

---@type table<hood.AddressMode, vk.SamplerAddressMode>
local addressModeMap = {
	[hood.AddressMode.ClampToEdge] = vk.SamplerAddressMode.CLAMP_TO_EDGE,
	[hood.AddressMode.Repeat] = vk.SamplerAddressMode.REPEAT,
	[hood.AddressMode.MirroredRepeat] = vk.SamplerAddressMode.MIRRORED_REPEAT,
}

---@type table<hood.FilterMode, vk.Filter>
local filterModeMap = {
	[hood.FilterMode.Nearest] = vk.Filter.NEAREST,
	[hood.FilterMode.Linear] = vk.Filter.LINEAR,
}

---@type table<hood.CompareFunction, vk.CompareOp>
local compareOpMap = {
	[hood.CompareFunction.Never] = vk.CompareOp.NEVER,
	[hood.CompareFunction.Less] = vk.CompareOp.LESS,
	[hood.CompareFunction.Equal] = vk.CompareOp.EQUAL,
	[hood.CompareFunction.LessEqual] = vk.CompareOp.LESS_OR_EQUAL,
	[hood.CompareFunction.Greater] = vk.CompareOp.GREATER,
	[hood.CompareFunction.NotEqual] = vk.CompareOp.NOT_EQUAL,
	[hood.CompareFunction.GreaterEqual] = vk.CompareOp.GREATER_OR_EQUAL,
	[hood.CompareFunction.Always] = vk.CompareOp.ALWAYS,
}

---@param device hood.vk.Device
---@param desc hood.SamplerDescriptor
function VKSampler.new(device, desc)
	local handle = device.handle:createSampler({
		magFilter = filterModeMap[desc.magFilter],
		minFilter = filterModeMap[desc.minFilter],
		mipmapMode = vk.SamplerMipmapMode.LINEAR,
		addressModeU = addressModeMap[desc.addressModeU],
		addressModeV = addressModeMap[desc.addressModeV],
		addressModeW = addressModeMap[desc.addressModeW],
		mipLodBias = 0,
		anisotropyEnable = desc.maxAnisotropy and 1 or 0,
		maxAnisotropy = desc.maxAnisotropy or 1.0,
		compareEnable = desc.compareOp and 1 or 0,
		compareOp = desc.compareOp and compareOpMap[desc.compareOp] or 0,
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
