local vk = require("vkapi") ---@cast vk vk & hood-vk.VkExtras
local ffi = require("ffi")

local VKCommandBuffer = require("hood-vk.command_buffer")
local VKCommandEncoder = require("hood-vk.command_encoder")

---@class hood-vk.Queue
---@field device hood-vk.Device
---@field handle vk.ffi.Queue
---@field familyIdx number
---@field idx number
---@field _serial number # How many submissions this queue has made
---@field _completed number # The last serial whose submission has finished
---@field _inflight { serial: number, fence: vk.ffi.Fence, buffer: hood-vk.CommandBuffer? }[] # In submission order
---@field _fences vk.ffi.Fence[] # Fences free for the next submission
---@field _doomed { serial: number, dispose: fun() }[] # Resources waiting for their last reader to finish
---@field _buffers hood-vk.CommandBuffer[] # Command buffers waiting to record the next pending writes
---@field _pending hood-vk.CommandBuffer? # Where writes not yet submitted are recorded
---@field _pendingEncoder hood-vk.CommandEncoder? # And the encoder over it
---@field _collecting boolean # Set while fences are being checked, which frees can re-enter
local VKQueue = {}
VKQueue.__index = VKQueue

---@param device hood-vk.Device
---@param familyIdx number
---@param idx number
---@return hood-vk.Queue
function VKQueue.new(device, familyIdx, idx)
	local handle = device.handle:getDeviceQueue(familyIdx, idx)
	return setmetatable({
		device = device,
		handle = handle,
		familyIdx = familyIdx,
		idx = idx,
		_serial = 0,
		_completed = 0,
		_inflight = {},
		_fences = {},
		_doomed = {},
		_buffers = {},
		_collecting = false,
	}, VKQueue)
end

local commandBuffers = ffi.new("VkCommandBuffer[2]")
local waitSemaphores = ffi.new("VkSemaphore[1]")
local signalSemaphores = ffi.new("VkSemaphore[1]")
local fenceArray = vk.FenceArray(1)
local waitStages = ffi.new("uint32_t[1]", vk.PipelineStageFlagBits.COLOR_ATTACHMENT_OUTPUT)
local submitArray = vk.SubmitInfoArray(1)

-- Cold path: formatting kept out of submit() so its trace stays small enough to compile.
local function submitFailed(result)
	error("Failed to submit to Vulkan queue, error code: " .. tostring(result))
end

--- A command buffer to record pending writes into, reused once its own submission has finished.
---@return hood-vk.CommandBuffer
---@param self hood-vk.Queue
function VKQueue:_takeBuffer()
	local buffer = table.remove(self._buffers)

	return buffer or VKCommandBuffer.new(self.device)
end

--- A fence no submission is using, reset for the next one.
---@return vk.ffi.Fence
---@param self hood-vk.Queue
function VKQueue:_takeFence()
	local fence = table.remove(self._fences)

	if fence then
		fenceArray[0] = fence
		self.device.handle:resetFences(1, fenceArray)

		return fence
	end

	return self.device.handle:createFence({})
end

--- Destroy what a finished submission had been keeping alive, oldest first.
---@param self hood-vk.Queue
function VKQueue:_releaseDoomed()
	local doomed = self._doomed

	while #doomed > 0 and doomed[1].serial <= self._completed do
		local entry = table.remove(doomed, 1)
		entry.dispose()
	end
end

--- Advance past every submission whose fence has signalled.
---
--- Submissions are checked in the order they were made and the count stops at the first one still
--- running, so `_completed` only ever names a serial every submission up to it has finished --
--- which is what makes it safe to free anything from an earlier one.
---@param self hood-vk.Queue
function VKQueue:_collect()
	if self._collecting then
		return
	end

	self._collecting = true

	local inflight = self._inflight
	local device = self.device

	while #inflight > 0 do
		local entry = inflight[1]
		fenceArray[0] = entry.fence

		-- A zero timeout is the poll: it answers SUCCESS once the submission has finished and
		-- TIMEOUT otherwise, without blocking the frame that is about to be built.
		local result = device.handle.v1_0.vkWaitForFences(device.handle.handle, 1, fenceArray, 1, 0)

		if result ~= vk.Result.SUCCESS then
			break
		end

		table.remove(inflight, 1)
		self._completed = entry.serial

		if entry.buffer then
			-- Its copies are done, so the staging they read can be reused or let go of.
			entry.buffer:reset()
			self._buffers[#self._buffers + 1] = entry.buffer
		end

		device.handle:resetFences(1, fenceArray)
		self._fences[#self._fences + 1] = entry.fence

		self:_releaseDoomed()
	end

	self._collecting = false
end

--- Run `dispose` once no submission that could still read what it frees is running.
---
--- A resource is named by command buffers submitted before the call, and by the pending writes of
--- the next submission, so what it has to outlive is the last serial made and any submission that
--- carries those writes. Waiting on a serial rather than on the swapchain that happened to draw
--- it keeps this working for a window, a screenshot and a test alike.
---@param dispose fun()
---@param self hood-vk.Queue
function VKQueue:defer(dispose)
	self:_collect()

	local serial = self._pending and (self._serial + 1) or self._serial

	if serial <= self._completed then
		dispose()
		return
	end

	self._doomed[#self._doomed + 1] = { serial = serial, dispose = dispose }
end

--- Waits for the submission made with `serial`, then frees whatever has finished.
---@param serial number
---@param self hood-vk.Queue
function VKQueue:waitSerial(serial)
	if serial <= self._completed then
		return
	end

	local inflight = self._inflight

	for index = 1, #inflight do
		local entry = inflight[index]

		if entry.serial == serial then
			fenceArray[0] = entry.fence
			self.device.handle:waitForFences(1, fenceArray, true, math.huge)
			break
		end
	end

	self:_collect()
end

--- The command buffer pending writes are recorded into, made the first time one arrives.
---@return hood-vk.CommandEncoder
---@param self hood-vk.Queue
function VKQueue:_pendingEncoderForWrites()
	if self._pendingEncoder == nil then
		local buffer = self:_takeBuffer()

		self._pending = buffer
		self._pendingEncoder = VKCommandEncoder.new(self.device, buffer)
	end

	return self._pendingEncoder
end

--- Finish the writes recorded so far, which a submission then hands to the gpu.
---@return hood-vk.CommandBuffer?
---@param self hood-vk.Queue
function VKQueue:_finishPending()
	local encoder = self._pendingEncoder

	if encoder == nil then
		return nil
	end

	local buffer = encoder:finish()

	self._pending = nil
	self._pendingEncoder = nil

	return buffer
end

--- Submit the writes that are waiting, with no frame to go with them. `waitIdle` does this so a
--- readback that follows sees them, and a submission with a frame batches them with it instead.
---@param self hood-vk.Queue
function VKQueue:_submitPending()
	local pending = self:_finishPending()

	if pending == nil then
		return
	end

	self:_collect()

	local fence = self:_takeFence()
	local info = submitArray[0]

	commandBuffers[0] = pending.handle
	info.commandBufferCount = 1
	info.pCommandBuffers = commandBuffers
	info.waitSemaphoreCount = 0
	info.pWaitSemaphores = nil
	info.pWaitDstStageMask = nil
	info.signalSemaphoreCount = 0
	info.pSignalSemaphores = nil

	local result = self.device.handle.v1_0.vkQueueSubmit(self.handle, 1, submitArray, fence)
	if result ~= 0 then
		submitFailed(result)
	end

	self._serial = self._serial + 1

	self._inflight[#self._inflight + 1] = {
		serial = self._serial,
		fence = fence,
		buffer = pending,
	}
end

--- Helper method to write data to a buffer.
---
--- The data is copied into staging now and the copy is recorded into the queue's pending writes,
--- which the next submission executes before the commands it was given: nothing is submitted or
--- waited for here. See `submit`, which is what makes the write the gpu's.
---@param buffer hood-vk.Buffer
---@param size number
---@param data ffi.cdata*
---@param offset number?
---@param self hood-vk.Queue
function VKQueue:writeBuffer(buffer, size, data, offset)
	offset = offset or 0
	if size == 0 then
		return
	end

	buffer:assertWriteFits(size, offset, data)

	-- A mapped buffer is written by the CPU, so nothing is recorded or submitted.
	if buffer.isMapped then
		ffi.copy(buffer:mappedPointer(offset), data, size)
		return
	end

	self:_pendingEncoderForWrites():writeBuffer(buffer, size, data, offset)
end

--- Helper method to write data to a texture: staged and recorded, and executed by the next
--- submission. Nothing is submitted or waited for here.
---@param texture hood-vk.Texture
---@param descriptor hood.TextureWriteDescriptor
---@param data ffi.cdata*
---@param self hood-vk.Queue
function VKQueue:writeTexture(texture, descriptor, data)
	self:_pendingEncoderForWrites():writeTexture(texture, descriptor, data)
end

--- Record a freshly created texture's first layout transition as a pending write, rather than
--- submitting it and waiting. `createTexture` is where every samplable texture starts, and it is
--- on the frame path, so what it costs here has to be a copy of a few bytes and no gpu wait.
---@param texture hood-vk.Texture
---@param self hood-vk.Queue
function VKQueue:claimTexture(texture)
	local started = self._pendingEncoder ~= nil
	local encoder = self:_pendingEncoderForWrites()

	if encoder:claimTexture(texture) == false and not started then
		-- Nothing was recorded after all: hand the buffer back rather than leaving an empty
		-- command buffer for the next submission to carry.
		encoder:finish()
		table.insert(self._buffers, 1, self._pending)
		self._pending = nil
		self._pendingEncoder = nil
	end
end

--- Submit a frame, with the writes recorded since the last submission before it.
---
--- A single vkQueueSubmit carries both command buffers, pending writes first: the writes and the
--- frame that samples them reach the gpu in one submission, so no new barriers are needed between
--- them and no frame waits for the queue to go idle.
---@param buffer hood-vk.CommandBuffer
---@param self hood-vk.Queue
function VKQueue:submit(buffer)
	self:_collect()

	local pending = self:_finishPending()

	-- Use the swapchain directly (stored as a single ref, not a table)
	local swapchain = buffer._swapchain
	local fence = self:_takeFence()
	local count = pending and 2 or 1

	if pending then
		commandBuffers[0] = pending.handle
	end

	commandBuffers[count - 1] = buffer.handle

	local info = submitArray[0]
	info.commandBufferCount = count
	info.pCommandBuffers = commandBuffers

	if swapchain then
		-- Indexed by frame slot, not by image: each slot gets its own semaphore pair, so
		-- currentFrame and the acquired image index cannot desync.
		local frame = swapchain.currentFrame
		waitSemaphores[0] = swapchain.imageAvailableSemaphores[frame]
		signalSemaphores[0] = swapchain.renderFinishedSemaphores[frame]
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

	local result = self.device.handle.v1_0.vkQueueSubmit(self.handle, 1, submitArray, fence)
	if result ~= 0 then
		submitFailed(result)
	end

	self._serial = self._serial + 1

	self._inflight[#self._inflight + 1] = {
		serial = self._serial,
		fence = fence,
		buffer = pending,
	}

	-- The swapchain image is handed out again only once the submission that last drew into it has
	-- finished: what `getCurrentTexture` waits for.
	if swapchain then
		swapchain._slotSerial[swapchain.currentFrame] = self._serial
	end
end

function VKQueue:waitIdle()
	-- Writes nothing has submitted yet are made the gpu's first, so waiting means everything the
	-- queue was given is done and every readback that follows sees it.
	self:_submitPending()

	self.device.handle:queueWaitIdle(self.handle)

	local inflight = self._inflight

	for index = 1, #inflight do
		local entry = inflight[index]

		self._completed = entry.serial

		if entry.buffer then
			entry.buffer:reset()
			self._buffers[#self._buffers + 1] = entry.buffer
		end

		fenceArray[0] = entry.fence
		self.device.handle:resetFences(1, fenceArray)
		self._fences[#self._fences + 1] = entry.fence
	end

	self._inflight = {}
	self:_releaseDoomed()
end

---@param swapchain hood-vk.Swapchain
---@param self hood-vk.Queue
function VKQueue:present(swapchain)
	assert(swapchain.currentVkImageIdx ~= nil, "present() called without a successful getCurrentTexture()")
	-- Use the same per-frame renderFinished semaphore as submit
	local sem = swapchain.renderFinishedSemaphores[swapchain.currentFrame]

	local result = swapchain.device.handle:queuePresentKHR(self.handle, swapchain.handle, swapchain.currentVkImageIdx, sem)
	if (result == vk.Result.ERROR_OUT_OF_DATE_KHR or result == vk.Result.SUBOPTIMAL_KHR) and swapchain:leftBehind() then
		swapchain.stale = true
	end

	swapchain.currentFrame = (swapchain.currentFrame % swapchain.imageCount) + 1
end

return VKQueue
