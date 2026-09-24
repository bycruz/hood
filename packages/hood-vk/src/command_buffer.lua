local vk = require("vkapi")

---@class hood-vk.CommandBuffer
---@field device hood-vk.Device
---@field pool vk.ffi.CommandPool
---@field handle vk.ffi.CommandBuffer
---@field _swapchain hood-vk.Swapchain?
---@field _encoder hood-vk.CommandEncoder? Encoder reused for this buffer across frames
---@field staging table? Host-visible upload memory, kept across frames that reuse this buffer
---@field stagingResources { buffer: vk.ffi.Buffer, memory: vk.ffi.DeviceMemory }[]?
local VKCommandBuffer = {}
VKCommandBuffer.__index = VKCommandBuffer

--- A command buffer, allocated from the pool the device keeps. One pool per command
--- buffer is a pool per frame for an app that records a frame into a fresh buffer every
--- frame, and a pool is the driver's to size: what is allocated here is the buffer, and
--- what `destroy` does is hand it back.
---@param device hood-vk.Device
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
		stagingResources = nil,
	}, VKCommandBuffer)
end

--- Free transient resources without destroying the pool (for recycling).
--- The command buffer can be re-recorded after calling this.
--- Note: we do NOT need to call vkResetCommandPool here because the pool
--- was created with RESET_COMMAND_BUFFER, and vkBeginCommandBuffer
--- (called in VKCommandEncoder.new) implicitly resets the buffer.
function VKCommandBuffer:reset()
	-- The staging buffer is deliberately kept: it is reused by the next frame
	-- that reclaims this command buffer, and swapping it out every frame would
	-- mean allocating host-visible memory per frame. It is safe because the
	-- copies recorded from it are finished by the time the buffer is re-recorded
	-- (swapchain slots wait their fence in getCurrentTexture). Only the bump
	-- offset has to go back to the start.
	if self.staging then
		self.staging.offset = 0
	end

	-- Fast path: nothing transient was recorded, so skip the cleanup loops
	-- entirely. They abort JIT traces and are never entered in the common case
	-- (a swapchain frame tracks nothing: views, framebuffers and render passes
	-- are all cached on the swapchain).
	if not (self.stagingResources or self.imageViews or self.framebuffers or self.renderPasses) then
		self._swapchain = nil
		return
	end

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

	-- Clear tracked swapchain ref so the encoder builds it fresh
	self._swapchain = nil
end

--- Let go of the staging buffer a frame writes through.
---
--- It is kept between frames because a frame usually writes through it again, which is what makes
--- it worth having; the one thing that does not is an upload that has already been submitted and
--- waited for, where what is being held is a buffer the size of whatever was uploaded -- a
--- photograph's worth of memory kept for the rest of the process, for nothing.
function VKCommandBuffer:releaseStaging()
	if self.staging then
		self.device.handle:destroyBuffer(self.staging.buffer)
		self.device.handle:freeMemory(self.staging.memory)
		self.staging = nil
	end
end

function VKCommandBuffer:destroy()
	-- Free all transient resources first
	self:reset()

	-- The persistent staging buffer outlives reset() by design, so it is freed
	-- here instead.
	self:releaseStaging()

	-- The buffer goes back to the pool it came from, which is the device's and outlives
	-- it: the pool is what the driver sizes, and keeping the buffer would be a leak of one
	-- per frame for anything that makes one per frame. The command buffer has to be
	-- finished with -- submitted and not in flight -- which is what every caller that
	-- destroys one waits for first.
	self.device:freeCommandBuffers(self.pool, self.handle)
end

return VKCommandBuffer
