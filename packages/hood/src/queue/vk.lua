local vk = require("hood-vulkan")
local ffi = require("ffi")

local VKCommandEncoder = require("hood.command_encoder.vk")

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
local waitStages = ffi.new("uint32_t[1]", vk.PipelineStageFlags.COLOR_ATTACHMENT_OUTPUT)
local submitArray = ffi.new("VkSubmitInfo[1]")

---@param buffer hood.vk.CommandBuffer
---@param swapchain hood.vk.Swapchain?
function VKQueue:submit(buffer, swapchain)
	-- Track command buffer for deferred cleanup after GPU completes
	if swapchain then
		swapchain.pendingCommandBuffers[swapchain.currentFrame] = buffer
	end

	commandBuffers[0] = buffer.handle

	local info = submitArray[0]
	info.sType = vk.StructureType.SUBMIT_INFO
	info.commandBufferCount = 1
	info.pCommandBuffers = commandBuffers

	if swapchain then
		waitSemaphores[0] = swapchain.imageAvailableSemaphores[swapchain.currentFrame]
		signalSemaphores[0] = swapchain.renderFinishedSemaphores[swapchain.currentFrame]
		info.waitSemaphoreCount = 1
		info.pWaitSemaphores = waitSemaphores
		info.pWaitDstStageMask = waitStages
		info.signalSemaphoreCount = 1
		info.pSignalSemaphores = signalSemaphores
	else
		info.waitSemaphoreCount = 0
		info.pWaitSemaphores = nil
		info.pWaitDstStageMask = nil
		info.signalSemaphoreCount = 0
		info.pSignalSemaphores = nil
	end

	local fence = swapchain and swapchain.inFlightFences[swapchain.currentFrame] or 0
	local result = self.device.handle.v1_0.vkQueueSubmit(self.handle, 1, submitArray, fence)
	if result ~= 0 then
		error("Failed to submit to Vulkan queue, error code: " .. tostring(result))
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

---@param swapchain hood.vk.Swapchain
function VKQueue:present(swapchain)
	swapchain:present(self)
end

return VKQueue
