local vk = require("vkapi")

local vkConvert = require("hood.convert.vk")

local VKTextureView = require("hood.vk.texture_view")

---@class hood.vk.Texture
---@field handle vk.ffi.Image
---@field memory vk.ffi.DeviceMemory?
---@field format vk.Format?
---@field width number?
---@field height number?
---@field viewType vk.ImageViewType
---@field isDepth boolean?
---@field private device hood.vk.Device
local VKTexture = {}
VKTexture.__index = VKTexture

--- TODO: Deduplicate this code from the pipeline
---@param format hood.TextureFormat
local function isDepthFormat(format)
	return format == "depth16unorm"
		or format == "depth24plus"
		or format == "depth32float"
end

---@param extents hood.TextureExtents
local function viewTypeFromExtents(extents)
	if extents.dim == "3d" then
		return vk.ImageViewType.TYPE_3D
	elseif extents.dim == "2d" and (extents.count and extents.count > 1) then
		return vk.ImageViewType.TYPE_2D_ARRAY
	elseif extents.dim == "2d" then
		return vk.ImageViewType.TYPE_2D
	elseif extents.dim == "1d" and (extents.count and extents.count > 1) then
		return vk.ImageViewType.TYPE_1D_ARRAY
	elseif extents.dim == "1d" then
		return vk.ImageViewType.TYPE_1D
	else
		error("Unsupported texture dimension: " .. tostring(extents.dim))
	end
end

---@param device hood.vk.Device
---@param descriptor hood.TextureDescriptor
function VKTexture.new(device, descriptor)
	local samples = vkConvert.sampleCount[descriptor.sampleCount or 1]
	if not samples then
		error("Unsupported sample count: " .. tostring(descriptor.sampleCount))
	end

	local layers = descriptor.extents.dim ~= "3d" and descriptor.extents.count or 1
	local isDepth = isDepthFormat(descriptor.format)

	---@type vk.ImageUsageFlagBits
	local vkUsage = 0
	for _, usage in ipairs(descriptor.usages) do
		local flag = vkConvert.textureUsage[usage]
		if usage == "RENDER_ATTACHMENT" and isDepth then
			flag = vk.ImageUsageFlagBits.DEPTH_STENCIL_ATTACHMENT
		end

		vkUsage = bit.bor(vkUsage, flag)
	end

	assert(descriptor.format, "Texture format must be specified")
	local format = vkConvert.textureFormat[descriptor.format]

	local handle = device.handle:createImage({
		imageType = vkConvert.textureType[descriptor.extents.dim],
		format = format,
		extent = {
			width = descriptor.extents.width,
			height = descriptor.extents.height,
			depth = descriptor.extents.depth or 1,
		},
		mipLevels = descriptor.mipLevelCount or 1,
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

			if bit.band(memProps.memoryTypes[i].propertyFlags, vk.MemoryPropertyFlagBits.DEVICE_LOCAL) ~= 0 then
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
		device = device,
		handle = handle,
		memory = memory,
		format = format,
		width = descriptor.extents.width,
		height = descriptor.extents.height,
		isDepth = isDepth,
		viewType = viewTypeFromExtents(descriptor.extents),
	}, VKTexture)
end

function VKTexture.fromRaw(device, handle, format, width, height)
	return setmetatable({ handle = handle, format = format, width = width, height = height }, VKTexture)
end

---@param descriptor hood.TextureViewDescriptor
function VKTexture:createView(descriptor)
	return VKTextureView.new(self.device, self, descriptor)
end

return VKTexture
