local vk = require("vkapi")
local ffi = require("ffi")

local VKCommandEncoder = require("hood.vk.command_encoder")

---@class hood.vk.Queue
---@field device hood.vk.Device
---@field handle vk.ffi.Queue
---@field familyIdx number
---@field idx number
local VKQueue = {}
VKQueue.__index = VKQueue

---@param device hood.vk.Device
---@param familyIdx number
---@param idx number
function VKQueue.new(device, familyIdx, idx)
	local handle = device.handle:getDeviceQueue(familyIdx, idx)
	return setmetatable({ device = device, handle = handle, familyIdx = familyIdx, idx = idx }, VKQueue)
end

local commandBuffers = ffi.new("VkCommandBuffer[1]")
local waitSemaphores = ffi.new("VkSemaphore[1]")
local signalSemaphores = ffi.new("VkSemaphore[1]")
local waitStages = ffi.new("uint32_t[1]", vk.PipelineStageFlagBits.COLOR_ATTACHMENT_OUTPUT)
local submitArray = vk.SubmitInfoArray(1)

-- Cold path: keep the message formatting out of the hot function so the trace
-- recorded for submit() stays small enough to compile.
local function submitFailed(result)
	error("Failed to submit to Vulkan queue, error code: " .. tostring(result))
end

---@param buffer hood.vk.CommandBuffer
function VKQueue:submit(buffer)
	commandBuffers[0] = buffer.handle

	local info = submitArray[0]
	info.commandBufferCount = 1
	info.pCommandBuffers = commandBuffers

	-- Use the swapchain directly (stored as a single ref, not a table)
	local swapchain = buffer._swapchain
	local fence

	if swapchain then
		-- Both semaphores are indexed by currentFrame (per frame-in-flight).
		-- This ensures each frame slot has a dedicated pair of semaphores,
		-- avoiding index desync between currentFrame and currentVkImageIdx.
		local frame = swapchain.currentFrame
		waitSemaphores[0] = swapchain.imageAvailableSemaphores[frame]
		signalSemaphores[0] = swapchain.renderFinishedSemaphores[frame]
		info.waitSemaphoreCount = 1
		info.pWaitSemaphores = waitSemaphores
		info.pWaitDstStageMask = waitStages
		info.signalSemaphoreCount = 1
		info.pSignalSemaphores = signalSemaphores
		fence = swapchain.inFlightFences[frame]
	else
		info.waitSemaphoreCount = 0
		info.pWaitSemaphores = nil
		info.pWaitDstStageMask = nil
		info.signalSemaphoreCount = 0
		info.pSignalSemaphores = nil
		fence = 0
	end

	local result = self.device.handle.v1_0.vkQueueSubmit(self.handle, 1, submitArray, fence)
	if result ~= 0 then
		submitFailed(result)
	end
end

-- TODO: This currently uses a blocking wait for simplicity and to avoid a use after free (from lua's gc)
-- Should eventually use a form of garbage collection managed by the VKQueue

--- Helper method to write data to a buffer
---@param buffer hood.gl.Buffer
---@param size number
---@param data ffi.cdata*
---@param offset number?
function VKQueue:writeBuffer(buffer, size, data, offset)
	local cmd = VKCommandEncoder.new(self.device)
	cmd:writeBuffer(buffer, size, data, offset)
	local buf = cmd:finish()
	self:submit(buf)
	self.device.handle:queueWaitIdle(self.handle)
	buf:destroy()
end

--- Helper method to write data to a texture
---@param texture hood.vk.Texture
---@param descriptor hood.TextureWriteDescriptor
---@param data ffi.cdata*
function VKQueue:writeTexture(texture, descriptor, data)
	local cmd = VKCommandEncoder.new(self.device)
	cmd:writeTexture(texture, descriptor, data)
	local buf = cmd:finish()
	self:submit(buf)
	self.device.handle:queueWaitIdle(self.handle)
	buf:destroy()
end

function VKQueue:waitIdle()
	self.device.handle:queueWaitIdle(self.handle)
end

---@param swapchain hood.vk.Swapchain
function VKQueue:present(swapchain)
	assert(swapchain.currentVkImageIdx ~= nil, "present() called without a successful getCurrentTexture()")
	-- Use the same per-frame renderFinished semaphore as submit
	local sem = swapchain.renderFinishedSemaphores[swapchain.currentFrame]
	swapchain.device.handle:queuePresentKHR(self.handle, swapchain.handle, swapchain.currentVkImageIdx, sem)

	swapchain.currentFrame = (swapchain.currentFrame % swapchain.imageCount) + 1
end

return VKQueue
