local vk = require("vkapi") ---@cast vk vk & hood-vk.VkExtras

---@class hood-vk.CommandBuffer: hood.CommandBuffer
---@field device hood-vk.Device
---@field pool vk.ffi.CommandPool
---@field handle vk.ffi.CommandBuffer
---@field _swapchain hood-vk.Swapchain?
---@field _encoder hood-vk.CommandEncoder? # Encoder reused for this buffer across frames
---@field stagingBuffer hood-vk.Buffer? # Upload memory kept across frames that reuse this buffer
---@field stagingResources hood-vk.Buffer[]? # Staging buffers this buffer outgrew
local VKCommandBuffer = {}
VKCommandBuffer.__index = VKCommandBuffer

--- A command buffer, allocated from the pool the device keeps. `destroy` hands it back.
---@param device hood-vk.Device
---@return hood-vk.CommandBuffer
function VKCommandBuffer.new(device)
	local pool = device:commandPool()

	local handle = device.handle:allocateCommandBuffers({
		commandPool = pool,
		level = vk.CommandBufferLevel.PRIMARY,
		commandBufferCount = 1,
	})[1]

	return setmetatable({
		device = device,
		pool = pool,
		handle = handle,
	}, VKCommandBuffer)
end

--- Reset the buffer for re-recording.
---
--- No vkResetCommandPool: the pool was made with RESET_COMMAND_BUFFER and vkBeginCommandBuffer
--- resets implicitly. The staging buffer is kept, since the copies recorded from it have
--- finished by the time this buffer is recorded again.
---@param self hood-vk.CommandBuffer
function VKCommandBuffer:reset()
	if self.stagingBuffer then
		self.stagingBuffer.staging = { offset = 0 }
	end

	if self.stagingResources then
		for _, buffer in ipairs(self.stagingResources) do
			buffer:destroy()
		end

		self.stagingResources = nil
	end

	self._swapchain = nil
end

--- Let go of the staging buffer, for an upload already submitted and waited for: what it
--- holds is a buffer the size of whatever was uploaded, and nothing is about to reuse it.
---@param self hood-vk.CommandBuffer
function VKCommandBuffer:releaseStaging()
	if self.stagingBuffer then
		self.stagingBuffer:destroy()
		self.stagingBuffer = nil
	end
end

function VKCommandBuffer:destroy()
	self:reset()
	self:releaseStaging()

	self.device:freeCommandBuffers(self.pool, self.handle)
end

return VKCommandBuffer
