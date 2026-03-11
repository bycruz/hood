local vk = require("vkapi")

---@class hood.vk.CommandBuffer
---@field device hood.vk.Device
---@field pool vk.ffi.CommandPool
---@field handle vk.ffi.CommandBuffer
local VKCommandBuffer = {}
VKCommandBuffer.__index = VKCommandBuffer

---@param device hood.vk.Device
function VKCommandBuffer.new(device)
	local pool = device.handle:createCommandPool({
		flags = vk.CommandPoolCreateFlagBits.RESET_COMMAND_BUFFER,
		queueFamilyIndex = device.queue.familyIdx,
	})

	local handle = device.handle:allocateCommandBuffers({
		commandPool = pool,
		level = vk.CommandBufferLevel.PRIMARY,
		commandBufferCount = 1,
	})[1]

	return setmetatable({
		device = device,
		pool = pool,
		handle = handle,
		stagingResources = nil,
	}, VKCommandBuffer)
end

function VKCommandBuffer:destroy()
	-- Free staging resources
	if self.stagingResources then
		for _, res in ipairs(self.stagingResources) do
			self.device.handle:destroyBuffer(res.buffer)
			self.device.handle:freeMemory(res.memory)
		end
		self.stagingResources = nil
	end

	-- Free image views
	if self.imageViews then
		for _, iv in ipairs(self.imageViews) do
			self.device.handle:destroyImageView(iv)
		end
		self.imageViews = nil
	end

	-- Free framebuffers
	if self.framebuffers then
		for _, fb in ipairs(self.framebuffers) do
			self.device.handle:destroyFramebuffer(fb)
		end
		self.framebuffers = nil
	end

	-- Free render passes
	if self.renderPasses then
		for _, rp in ipairs(self.renderPasses) do
			self.device.handle:destroyRenderPass(rp)
		end
		self.renderPasses = nil
	end

	-- Destroying the pool implicitly frees all command buffers allocated from it
	self.device.handle:destroyCommandPool(self.pool)
end

return VKCommandBuffer
