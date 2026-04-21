local vk = require("vkapi")
local ffi = require("ffi")

local VKTexture = require("hood.vk.texture")


---@class hood.vk.Swapchain
---@field handle vk.ffi.SwapchainKHR
---@field device hood.vk.Device
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
local VKSwapchain = {}
VKSwapchain.__index = VKSwapchain

---@param device hood.vk.Device
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

	-- Track per-frame command buffers for deferred cleanup
	-- TODO: We probably don't want to be doing this in the future.
	local pendingCommandBuffers = {}
	for i = 1, #images do
		pendingCommandBuffers[i] = nil
	end

	return setmetatable({
		images = images,
		device = device,
		handle = handle,
		imageAvailableSemaphores = imageAvailableSemaphores,
		renderFinishedSemaphores = renderFinishedSemaphores,
		inFlightFences = inFlightFences,
		pendingCommandBuffers = pendingCommandBuffers,
		currentFrame = 1,
		imageFormat = info.imageFormat,
		format = format,
		width = info.imageExtent.width,
		height = info.imageExtent.height,
	}, VKSwapchain)
end

local fenceArray = vk.FenceArray(1)

function VKSwapchain:getCurrentTexture()
	local fence = self.inFlightFences[self.currentFrame]
	fenceArray[0] = fence

	-- Wait for this frame's previous work to complete before reusing its semaphores
	self.device.handle:waitForFences(1, fenceArray, true, math.huge)
	self.device.handle:resetFences(1, fenceArray)

	local prevBuf = self.pendingCommandBuffers[self.currentFrame]
	if prevBuf then
		prevBuf:destroy()
		self.pendingCommandBuffers[self.currentFrame] = nil
	end

	local sem = self.imageAvailableSemaphores[self.currentFrame]
	local result, currentVkImageIdx = self.device.handle:acquireNextImageKHR(self.handle, math.huge, sem)
	if result == vk.Result.ERROR_OUT_OF_DATE_KHR then
		return nil
	elseif result ~= vk.Result.SUCCESS then
		error("Failed to acquire next image: " .. result)
	end

	local imageHandle = self.images[currentVkImageIdx + 1]

	self.currentVkImageIdx = currentVkImageIdx
	return VKTexture.fromSwapchainImg(self.device, imageHandle, self.imageFormat, self.width, self.height)
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
	self.device.handle:destroySwapchainKHR(self.handle)
end

return VKSwapchain
