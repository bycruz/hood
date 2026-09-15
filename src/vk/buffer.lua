local ffi = require("ffi")
local vk = require("vkapi")

local memory = require("hood.vk.memory")

---@class hood.vk.Buffer: hood.Buffer
---@field handle vk.ffi.Buffer
---@field memory vk.ffi.DeviceMemory
---@field device hood.vk.Device
---@field descriptor hood.BufferDescriptor
local VKBuffer = {}
VKBuffer.__index = VKBuffer

---@param device hood.vk.Device
---@param descriptor hood.BufferDescriptor
function VKBuffer.new(device, descriptor)
	local vkUsage = 0
	local needsHostVisible = false
	local wantsMapped = descriptor.mapped and true or false

	for _, usage in ipairs(descriptor.usages) do
		if usage == "VERTEX" then
			vkUsage = bit.bor(vkUsage, vk.BufferUsageFlagBits.VERTEX_BUFFER)
		elseif usage == "INDEX" then
			vkUsage = bit.bor(vkUsage, vk.BufferUsageFlagBits.INDEX_BUFFER)
		elseif usage == "UNIFORM" then
			vkUsage = bit.bor(vkUsage, vk.BufferUsageFlagBits.UNIFORM_BUFFER)
		elseif usage == "COPY_DST" then
			vkUsage = bit.bor(vkUsage, vk.BufferUsageFlagBits.TRANSFER_DST)
		elseif usage == "COPY_SRC" then
			vkUsage = bit.bor(vkUsage, vk.BufferUsageFlagBits.TRANSFER_SRC)
		elseif usage == "STORAGE" then
			vkUsage = bit.bor(vkUsage, vk.BufferUsageFlagBits.STORAGE_BUFFER)
		elseif usage == "MAP_READ" then
			needsHostVisible = true
			vkUsage = bit.bor(vkUsage, vk.BufferUsageFlagBits.TRANSFER_DST)
		else
			error("Invalid buffer usage: " .. tostring(usage))
		end
	end

	if vkUsage == 0 then
		error("No valid buffer usage specified")
	end

	---@diagnostic disable-next-line: assign-type-mismatch: vkUsage is checked above
	local handle = device.handle:createBuffer({ size = descriptor.size, usage = vkUsage })

	local requirements = device.handle:getBufferMemoryRequirements(handle)

	-- A mapped buffer is host visible by definition; MAP_READ buffers are too,
	-- because reading back means the CPU has to map them at some point.
	local hostVisible = needsHostVisible or wantsMapped
	local requiredFlags = hostVisible
		and bit.bor(vk.MemoryPropertyFlagBits.HOST_VISIBLE, vk.MemoryPropertyFlagBits.HOST_COHERENT)
		or vk.MemoryPropertyFlagBits.DEVICE_LOCAL

	-- Host-visible memory that is also device-local is the good case: the GPU
	-- reads it over the bus instead of from system memory.
	local preferredFlags = hostVisible and vk.MemoryPropertyFlagBits.DEVICE_LOCAL or 0

	local memTypeIndex = memory.findType(device, tonumber(requirements.memoryTypeBits),
		requiredFlags, preferredFlags)
	if not memTypeIndex then
		error("Failed to find compatible memory type for buffer")
	end

	local deviceMemory = device.handle:allocateMemory({
		allocationSize = requirements.size,
		memoryTypeIndex = memTypeIndex,
	})
	device.handle:bindBufferMemory(handle, deviceMemory, 0)

	local buffer = setmetatable({
		device = device,
		handle = handle,
		memory = deviceMemory,
		descriptor = descriptor,
		isMapped = wantsMapped,
		mappedBase = nil,
	}, VKBuffer)

	-- A mapped buffer stays mapped for its whole life. The memory is coherent,
	-- so there is nothing to flush, and remapping per write would cost more
	-- than the write itself.
	if wantsMapped then
		buffer.mappedBase = ffi.cast("uint8_t*",
			device.handle:mapMemory(deviceMemory, 0, descriptor.size))
	end

	return buffer
end

--- Pointer to `offset` bytes into a mapped buffer, for direct CPU writes.
--- Errors on an unmapped buffer rather than handing back a pointer that the
--- driver never agreed to.
---@param offset number?
---@return ffi.cdata*
function VKBuffer:mappedPointer(offset)
	if not self.mappedBase then
		error("hood: buffer is not mapped; create it with { mapped = true }")
	end
	return self.mappedBase + (offset or 0)
end

function VKBuffer:destroy()
	if self.mappedBase then
		self.mappedBase = nil
		self.device.handle:unmapMemory(self.memory)
	end
	self.device.handle:destroyBuffer(self.handle)
end

--- Reject a write that does not fit the allocation, before it reaches the
--- driver. vkCmdUpdateBuffer does not bounds check its destination: an
--- oversized write lands in whatever the driver placed after the buffer and
--- only surfaces later as corrupted rendering or VK_ERROR_DEVICE_LOST, with
--- nothing pointing back at the offending call. Checking here keeps the error
--- attached to the write that caused it.
---
--- `data` is optional. When its size can be determined the source is checked
--- too, which catches a size computed from a count that disagrees with the
--- array it was derived from.
---@param size number bytes to write
---@param offset number? byte offset into the buffer, defaults to 0
---@param data ffi.cdata*? source data, checked when its size is knowable
function VKBuffer:assertWriteFits(size, offset, data)
	offset = offset or 0

	if size < 0 or offset < 0 then
		error(string.format(
			"hood: buffer write has a negative size (%s) or offset (%s)",
			tostring(size), tostring(offset)))
	end

	if offset + size > self.descriptor.size then
		error(string.format(
			"hood: buffer write of %d bytes at offset %d exceeds the %d byte buffer [%s]",
			size, offset, self.descriptor.size,
			table.concat(self.descriptor.usages, ", ")))
	end

	if data ~= nil then
		local ok, sourceSize = pcall(ffi.sizeof, data)
		if ok and type(sourceSize) == "number" and sourceSize < size then
			error(string.format(
				"hood: buffer write of %d bytes reads past the end of its %d byte source",
				size, sourceSize))
		end
	end
end

function VKBuffer:mapAsync()
	-- No-op: memory is HOST_COHERENT, no explicit flush needed.
	-- Caller must ensure GPU work is complete (queue:waitIdle) before reading.
end

--- Range of the buffer visible to the CPU. A mapped buffer is already mapped,
--- so this just offsets the permanent pointer instead of asking the driver for
--- a second mapping of the same memory.
---@param offset number?
---@param size number? only meaningful for an unmapped buffer
---@return ffi.cdata*
function VKBuffer:getMappedRange(offset, size)
	if self.mappedBase then
		return self.mappedBase + (offset or 0)
	end
	return self.device.handle:mapMemory(self.memory, offset or 0, size or self.descriptor.size)
end

function VKBuffer:unmap()
	-- A mapped buffer keeps its mapping for its lifetime; dropping it here would
	-- leave mappedPointer handing out a stale pointer.
	if self.mappedBase then
		return
	end
	self.device.handle:unmapMemory(self.memory)
end

function VKBuffer:__tostring()
	return "VKBuffer(" .. tostring(self.handle) .. ")"
end

return VKBuffer
