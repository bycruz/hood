local vk = require("vkapi")

local vkConvert = require("hood-vk.convert")
local memory = require("hood-vk.memory")

local VKTextureView = require("hood-vk.texture_view")

---@class hood-vk.Texture
---@field handle vk.ffi.Image
---@field memory vk.ffi.DeviceMemory?
---@field format vk.Format
---@field width number?
---@field height number?
---@field viewType vk.ImageViewType
---@field isDepth boolean?
---@field usage vk.ImageUsageFlagBits
---@field isSwapchain boolean?
---@field swapchain hood-vk.Swapchain?
---@field swapchainImageIdx integer? 0-based index into the swapchain images, set when isSwapchain is true
---@field private device hood-vk.Device
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

---@param device hood-vk.Device
---@param descriptor hood.TextureDescriptor
function VKTexture.new(device, descriptor)
	local samples = vkConvert.sampleCount[descriptor.sampleCount or 1]
	if not samples then
		error("Unsupported sample count: " .. tostring(descriptor.sampleCount))
	end

	-- An extents that names no count is one layer, which is what most textures are: reading the
	-- count straight off it makes an image with no layers at all
	local layers = descriptor.extents.dim ~= "3d" and (descriptor.extents.count or 1) or 1
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

	-- A texture is device-local memory, and the types beside that one are the same memory asked
	-- for without it: an image the first heap has no room for lands in the next one rather than
	-- nowhere.
	local requirements = device.handle:getImageMemoryRequirements(handle)
	local imageMemory = memory.allocate(device, requirements, vk.MemoryPropertyFlagBits.DEVICE_LOCAL, 0, "image")

	device.handle:bindImageMemory(handle, imageMemory, 0)

	return setmetatable({
		device = device,
		handle = handle,
		memory = imageMemory,
		format = format,
		width = descriptor.extents.width,
		height = descriptor.extents.height,
		isDepth = isDepth,
		viewType = viewTypeFromExtents(descriptor.extents),
		usage = vkUsage,
	}, VKTexture)
end

---@param device hood-vk.Device
---@param swapchain hood-vk.Swapchain
---@param handle vk.ffi.Image
---@param format vk.Format
---@param width number
---@param height number
---@param swapchainImageIdx integer 0-based index into the swapchain's images
function VKTexture.fromSwapchainImg(device, swapchain, handle, format, width, height, swapchainImageIdx)
	return setmetatable({
		device = device,
		swapchain = swapchain,
		handle = handle,
		format = format,
		width = width,
		height = height,
		isSwapchain = true,
		swapchainImageIdx = swapchainImageIdx,
		viewType = vk.ImageViewType.TYPE_2D,
	}, VKTexture)
end

function VKTexture:destroy()
	if self.isSwapchain then return end
	self.device.handle:destroyImage(self.handle)
	if self.memory then
		self.device.handle:freeMemory(self.memory)
	end
end

---@param descriptor hood.TextureViewDescriptor?
function VKTexture:createView(descriptor)
	-- For swapchain textures, lazily create and cache a view per swapchain image.
	-- The swapchain already has pre-created VkImageView handles, so we wrap one
	-- without calling createImageView. Subsequent frames reuse the cached view,
	-- eliminating the per-frame createImageView overhead.
	if self.isSwapchain and self.swapchain then
		self._viewCache = self._viewCache or {}
		local idx = self.swapchainImageIdx --[[@as integer]]
		local cached = self._viewCache[idx]
		if not cached then
			local rawHandle = self.swapchain.imageViews[idx + 1]
			-- descriptor is ignored for swapchain views (uses pre-created config)
			cached = VKTextureView.fromHandle(self.device, self, rawHandle, nil)
			self._viewCache[idx] = cached
		end
		return cached
	end
	return VKTextureView.new(self.device, self, descriptor or {})
end

return VKTexture
