local ffi = require("ffi")
local vk = require("vkapi")

local VKTexture = require("hood-vk.texture")
local VKCommandBuffer = require("hood-vk.command_buffer")
local VKCommandEncoder = require("hood-vk.command_encoder")


---@class hood-vk.Swapchain
---@field handle vk.ffi.SwapchainKHR
---@field device hood-vk.Device
---@field surface hood-vk.Surface? # What it was made for, which is what says whether it still fits
---@field stale boolean? # What the last present said: the surface has left this swapchain behind
---@field images vk.ffi.Image[] # 1 indexed array of VkImage handles
---@field currentVkImageIdx integer
---@field imageAvailableSemaphores vk.ffi.Semaphore[]
---@field renderFinishedSemaphores vk.ffi.Semaphore[]
---@field inFlightFences vk.ffi.Fence[]
---@field currentFrame integer
---@field imageFormat vk.Format
---@field format hood.TextureFormat
---@field width number
---@field height number
---@field commandBuffers hood-vk.CommandBuffer[] Pre-allocated command buffers, one per swapchain image
---@field imageCount integer Number of swapchain images (cached to avoid #images per frame)
---@field imageViews vk.ffi.ImageView[] # 1 indexed array of pre-created VkImageViews
---@field _framebufferCache table<userdata, table<integer, { framebuffer: vk.ffi.Framebuffer, width: number, height: number }>>
---@field _retiredFramebuffers vk.ffi.Framebuffer[] # Replaced framebuffers, freed once the device is idle
local VKSwapchain = {}
VKSwapchain.__index = VKSwapchain

---@param device hood-vk.Device
---@param format hood.TextureFormat
---@param info vk.ffi.SwapchainCreateInfoKHR
function VKSwapchain.new(device, format, info)
	local handle = device.handle:createSwapchainKHR(info)
	local images = device.handle:getSwapchainImagesKHR(handle)

	local imageAvailableSemaphores = {}
	local renderFinishedSemaphores = {}
	local inFlightFences = {}
	for i = 1, #images do
		imageAvailableSemaphores[i] = device.handle:createSemaphore({})
		renderFinishedSemaphores[i] = device.handle:createSemaphore({})
		inFlightFences[i] = device.handle:createFence({ flags = vk.FenceCreateFlagBits.SIGNALED })
	end

	-- One per swapchain image, so a frame does not allocate a command buffer.
	local commandBuffers = {}
	for i = 1, #images do
		commandBuffers[i] = VKCommandBuffer.new(device)
	end

	-- One per swapchain image, since they are bound on every frame.
	local imageViews = {}

	for i = 1, #images do
		imageViews[i] = device.handle:createImageView({
			image = images[i],
			viewType = vk.ImageViewType.TYPE_2D,
			format = info.imageFormat,
			subresourceRange = { aspectMask = vk.ImageAspectFlagBits.COLOR, baseMipLevel = 0,
				levelCount = 1, baseArrayLayer = 0, layerCount = 1 },
			components = nil, --[[@type vk.ffi.ComponentMapping]]
		})
	end

	-- Framebuffer cache: renderPass -> "WxH" string -> imageIdx -> VkFramebuffer
	local framebufferCache = {}

	return setmetatable({
		images = images,
		imageCount = #images,
		imageViews = imageViews,
		device = device,
		handle = handle,
		imageAvailableSemaphores = imageAvailableSemaphores,
		renderFinishedSemaphores = renderFinishedSemaphores,
		inFlightFences = inFlightFences,
		commandBuffers = commandBuffers,
		currentFrame = 1,
		_framebufferCache = framebufferCache,
		_retiredFramebuffers = {},
		imageFormat = info.imageFormat,
		format = format,
		width = info.imageExtent.width,
		height = info.imageExtent.height,
	}, VKSwapchain)
end

local fenceArray = vk.FenceArray(1)

-- How long an acquire waits for an image, in nanoseconds.
--
-- A swapchain whose window is not being presented -- minimized, hidden, or made for a window
-- of no size -- never gets its images back from the presentation engine, so the acquire answers
-- VK_TIMEOUT instead of waiting forever. A second is longer than any display's frame, so a wait
-- this long is only spent on a swapchain that is not going to produce one.
local ACQUIRE_TIMEOUT = 1000000000

---@return boolean
function VKSwapchain:leftBehind()
	local surface = self.surface
	if surface == nil then
		return false
	end

	local window = surface.window
	if window == nil then
		return false
	end

	return window.width ~= self.width or window.height ~= self.height
end

function VKSwapchain:getCurrentTexture()
	if self.stale then
		self.stale = false
		return nil
	end

	local fence = self.inFlightFences[self.currentFrame]
	fenceArray[0] = fence

	-- Wait for this frame's previous work to complete before reusing its semaphores
	self.device.handle:waitForFences(1, fenceArray, true, math.huge)

	local sem = self.imageAvailableSemaphores[self.currentFrame]
	local result, currentVkImageIdx = self.device.handle:acquireNextImageKHR(self.handle, ACQUIRE_TIMEOUT, sem)

	if result == vk.Result.ERROR_OUT_OF_DATE_KHR or result == vk.Result.TIMEOUT or result == vk.Result.NOT_READY then
		return nil
	elseif result ~= vk.Result.SUCCESS and result ~= vk.Result.SUBOPTIMAL_KHR then
		error("Failed to acquire next image: " .. tostring(result))
	end

	-- SUBOPTIMAL_KHR hands back a usable image, and compositors report it routinely: treating
	-- it as a failure freezes the app.

	-- An image is held now, so this frame is committed to being submitted.
	self.device.handle:resetFences(1, fenceArray)

	local imageHandle = self.images[currentVkImageIdx + 1]

	self.currentVkImageIdx = currentVkImageIdx

	-- One reused texture, so its cached views survive across frames.
	if not self._currentTexture then
		self._currentTexture = VKTexture.fromSwapchainImg(self.device, self, imageHandle,
			self.imageFormat, self.width, self.height, currentVkImageIdx)
	end
	self._currentTexture.handle = imageHandle
	self._currentTexture.swapchainImageIdx = currentVkImageIdx
	return self._currentTexture
end

--- A command encoder over the pre-allocated command buffer for the current frame slot.
---@return hood-vk.CommandEncoder
function VKSwapchain:createCommandEncoder()
	return VKCommandEncoder.new(self.device, self.commandBuffers[self.currentFrame])
end

--- The framebuffer for a render pass and the current swapchain image, cached by image index
--- and dimensions. A `depthView` is part of the cache identity, so a depth-attached pass is
--- cached like any other.
---@param renderPass vk.ffi.RenderPass
---@param width number
---@param height number
---@param depthView vk.ffi.ImageView?
function VKSwapchain:getFramebuffer(renderPass, width, height, depthView)
	local imgIdx = self.currentVkImageIdx -- 0-based

	local cache = self._framebufferCache[renderPass]
	if not cache then
		cache = {}
		self._framebufferCache[renderPass] = cache
	end

	local entry = cache[imgIdx]
	if entry and entry.width == width and entry.height == height and entry.depthView == depthView then
		return entry.framebuffer
	end

	local attachmentCount = depthView and 2 or 1
	local fbViews = ffi.new("VkImageView[?]", attachmentCount)
	fbViews[0] = self.imageViews[imgIdx + 1]
	if depthView then
		fbViews[1] = depthView
	end
	local framebuffer = self.device.handle:createFramebuffer({
		renderPass = renderPass,
		attachmentCount = attachmentCount,
		pAttachments = fbViews,
		width = width,
		height = height,
		layers = 1,
	})

	-- Retired rather than destroyed: a command buffer may still reference it.
	if entry and entry.framebuffer then
		self._retiredFramebuffers[#self._retiredFramebuffers + 1] = entry.framebuffer
	end

	cache[imgIdx] = {
		framebuffer = framebuffer,
		width = width,
		height = height,
		depthView = depthView,
	}

	return framebuffer
end

function VKSwapchain:_destroySyncObjects()
	self.device.handle:queueWaitIdle(self.device.queue.handle)
	for i = 1, #self.images do
		self.device.handle:destroySemaphore(self.imageAvailableSemaphores[i])
		self.device.handle:destroySemaphore(self.renderFinishedSemaphores[i])
		self.device.handle:destroyFence(self.inFlightFences[i])
	end
end

function VKSwapchain:destroy()
	self:_destroySyncObjects()

	-- Destroy pre-allocated command buffers
	for _, buf in ipairs(self.commandBuffers) do
		buf:destroy()
	end

	-- Destroy cached framebuffers
	for _, cache in pairs(self._framebufferCache) do
		for _, entry in pairs(cache) do
			self.device.handle:destroyFramebuffer(entry.framebuffer)
		end
	end

	-- Destroy framebuffers that were replaced in the cache
	for _, fb in ipairs(self._retiredFramebuffers) do
		self.device.handle:destroyFramebuffer(fb)
	end
	self._retiredFramebuffers = {}

	-- Destroy pre-created image views
	for _, iv in ipairs(self.imageViews) do
		self.device.handle:destroyImageView(iv)
	end

	self.device.handle:destroySwapchainKHR(self.handle)
end

return VKSwapchain
