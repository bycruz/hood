local vk = require("vkapi")
local ffi = require("ffi")

local VKCommandEncoder = require("hood-vk.command_encoder")

---@class hood-vk.Queue
---@field device hood-vk.Device
---@field handle vk.ffi.Queue
---@field familyIdx number
---@field idx number
local VKQueue = {}
VKQueue.__index = VKQueue

---@param device hood-vk.Device
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

---@param buffer hood-vk.CommandBuffer
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
---@param buffer hood-vk.Buffer
---@param size number
---@param data ffi.cdata*
---@param offset number?
function VKQueue:writeBuffer(buffer, size, data, offset)
	offset = offset or 0
	if size == 0 then
		return
	end
	buffer:assertWriteFits(size, offset, data)

	-- A mapped buffer is written by the CPU directly, so there is nothing to
	-- record, submit and wait for.
	if buffer.isMapped then
		ffi.copy(buffer:mappedPointer(offset), data, size)
		return
	end

	local cmd = VKCommandEncoder.new(self.device)
	cmd:writeBuffer(buffer, size, data, offset)
	local buf = cmd:finish()
	self:submit(buf)
	self.device.handle:queueWaitIdle(self.handle)
	buf:destroy()
end

--- Helper method to write data to a texture
---@param texture hood-vk.Texture
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

--- Claim a freshly created texture's subresources so it can be drawn with.
---
--- Sampling goes through a view, and a descriptor covers the whole view, so a
--- texture drawn through it needs every layer in the layout that descriptor
--- names even before anything has been written to it. Doing that here rather
--- than where the texture is first bound or written keeps the barrier outside
--- any render pass, which is where hood's passes require barriers to be.
---@param texture hood-vk.Texture
function VKQueue:claimTexture(texture)
	local cmd = VKCommandEncoder.new(self.device)
	if not cmd:claimTexture(texture) then
		return
	end

	local buf = cmd:finish()
	self:submit(buf)
	self.device.handle:queueWaitIdle(self.handle)
	buf:destroy()
end

function VKQueue:waitIdle()
	self.device.handle:queueWaitIdle(self.handle)
end

---@param swapchain hood-vk.Swapchain
function VKQueue:present(swapchain)
	assert(swapchain.currentVkImageIdx ~= nil, "present() called without a successful getCurrentTexture()")
	-- Use the same per-frame renderFinished semaphore as submit
	local sem = swapchain.renderFinishedSemaphores[swapchain.currentFrame]
	swapchain.device.handle:queuePresentKHR(self.handle, swapchain.handle, swapchain.currentVkImageIdx, sem)

	swapchain.currentFrame = (swapchain.currentFrame % swapchain.imageCount) + 1
end

return VKQueue
