local hood = require("hood")
local vk = require("hood-vulkan")

local vkConvert = require("hood.convert.vk")

---@class hood.vk.Texture
---@field handle vk.ffi.Image
---@field memory vk.ffi.DeviceMemory?
---@field format vk.Format?
---@field width number?
---@field height number?
local VKTexture = {}
VKTexture.__index = VKTexture

---@param device hood.vk.Device
---@param descriptor hood.TextureDescriptor
function VKTexture.new(device, descriptor)
	local samples = vkConvert.sampleCount[descriptor.sampleCount or 1]
	if not samples then
		error("Unsupported sample count: " .. tostring(descriptor.sampleCount))
	end

	local layers = descriptor.extents.dim ~= "3d" and descriptor.extents.count or 1

	---@type vk.ImageUsageFlagBits
	local vkUsage = 0
	for _, usage in ipairs(descriptor.usages) do
		vkUsage = bit.bor(vkUsage, vkConvert.textureUsage[usage])
	end

	local handle = device.handle:createImage({
		imageType = vkConvert.textureType[descriptor.extents.dim],
		format = vkConvert.textureFormat[descriptor.format],
		extent = {
			width = descriptor.extents.width,
			height = descriptor.extents.height,
			depth = descriptor.extents.depth,
		},
		mipLevels = descriptor.mipLevelCount,
		arrayLayers = layers,
		samples = samples,
		tiling = vk.ImageTiling.OPTIMAL,
		usage = vkUsage,
		sharingMode = vk.SharingMode.EXCLUSIVE,
		initialLayout = vk.ImageLayout.UNDEFINED,
	})

	-- TODO: Rewrite and reuse this logic
	-- Allocate and bind memory (prefer DEVICE_LOCAL, fall back to any compatible type)
	local requirements = device.handle:getImageMemoryRequirements(handle)
	local memProps = vk.getPhysicalDeviceMemoryProperties(device.pd)
	local memTypeIndex = nil
	local fallbackIndex = nil

	local typeBits = tonumber(requirements.memoryTypeBits)
	local count = tonumber(memProps.memoryTypeCount)
	for i = 0, count - 1 do
		-- If memoryTypeBits is 0 (driver doesn't constrain), consider all types
		if typeBits == 0 or bit.band(typeBits, bit.lshift(1, i)) ~= 0 then
			if not fallbackIndex then
				fallbackIndex = i
			end
			if bit.band(tonumber(memProps.memoryTypes[i].propertyFlags), vk.MemoryPropertyFlags.DEVICE_LOCAL) ~= 0 then
				memTypeIndex = i
				break
			end
		end
	end

	memTypeIndex = memTypeIndex or fallbackIndex
	if not memTypeIndex then
		error("Failed to find compatible memory type for image")
	end

	local memory = device.handle:allocateMemory({
		allocationSize = requirements.size,
		memoryTypeIndex = memTypeIndex,
	})
	device.handle:bindImageMemory(handle, memory, 0)

	return setmetatable({
		handle = handle,
		memory = memory,
		format = vkConvert.textureFormat[descriptor.format],
		width = descriptor.extents.width,
		height = descriptor.extents.height,
	}, VKTexture)
end

function VKTexture.fromRaw(device, handle, format, width, height)
	return setmetatable({ handle = handle, format = format, width = width, height = height }, VKTexture)
end

function VKTexture:createView(descriptor)
end

return VKTexture
