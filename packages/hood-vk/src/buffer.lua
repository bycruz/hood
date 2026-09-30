local ffi = require("ffi")
local vk = require("vkapi")

local layout = require("hood-core.layout")
local memory = require("hood-vk.memory")

---@class hood-vk.Buffer: hood.Buffer
---@field handle vk.ffi.Buffer
---@field memory vk.ffi.DeviceMemory
---@field device hood-vk.Device
---@field descriptor hood.BufferDescriptor
---@field private mappedBase ffi.cdata*? # Present exactly when the memory is permanently mapped
---@field staging table? # Bump cursor into this buffer when it serves as upload staging
local VKBuffer = {}
VKBuffer.__index = VKBuffer

---@type table<hood.BufferUsage, number>
local usageFlags = {
	VERTEX = vk.BufferUsageFlagBits.VERTEX_BUFFER,
	INDEX = vk.BufferUsageFlagBits.INDEX_BUFFER,
	UNIFORM = vk.BufferUsageFlagBits.UNIFORM_BUFFER,
	COPY_DST = vk.BufferUsageFlagBits.TRANSFER_DST,
	COPY_SRC = vk.BufferUsageFlagBits.TRANSFER_SRC,
	STORAGE = vk.BufferUsageFlagBits.STORAGE_BUFFER,
	INDIRECT = vk.BufferUsageFlagBits.INDIRECT_BUFFER,
	MAP_READ = vk.BufferUsageFlagBits.TRANSFER_DST,
}

--- Usages that need the CPU to reach this memory: a readback has to be mapped at some point.
---@type table<hood.BufferUsage, boolean>
local hostVisibleUsages = {
	MAP_READ = true,
}

---@param device hood-vk.Device
---@param descriptor hood.BufferDescriptor
function VKBuffer.new(device, descriptor)
	local wantsMapped = descriptor.mapped == true
	local vkUsage = 0
	local hostVisible = wantsMapped

	for _, usage in ipairs(descriptor.usages) do
		local flag = usageFlags[usage]

		if not flag then
			error("Invalid buffer usage: " .. tostring(usage))
		end

		vkUsage = bit.bor(vkUsage, flag)
		hostVisible = hostVisible or hostVisibleUsages[usage] == true
	end

	if vkUsage == 0 then
		error("No valid buffer usage specified")
	end

	local handle = device.handle:createBuffer({ size = descriptor.size, usage = vkUsage })
	local requirements = device.handle:getBufferMemoryRequirements(handle)

	local requiredFlags = hostVisible
		and memory.HOST_VISIBLE_FLAGS
		or vk.MemoryPropertyFlagBits.DEVICE_LOCAL

	-- Worth asking for even when not required: a GPU reading host-visible memory out of device
	-- memory rather than over the bus is what makes uploads fast.
	local preferredFlags = hostVisible and vk.MemoryPropertyFlagBits.DEVICE_LOCAL or 0

	local deviceMemory = memory.allocate(device, requirements, requiredFlags, preferredFlags, "buffer")
	device.handle:bindBufferMemory(handle, deviceMemory, 0)

	local buffer = setmetatable({
		device = device,
		handle = handle,
		memory = deviceMemory,
		descriptor = descriptor,
		isMapped = wantsMapped,
		mappedBase = nil,
	}, VKBuffer)

	-- Coherent memory needs no flush, and remapping per write would cost more than the write.
	if wantsMapped then
		buffer.mappedBase = ffi.cast("uint8_t*", device.handle:mapMemory(deviceMemory, 0, descriptor.size))
	end

	return buffer
end

--- Pointer to `offset` bytes into a mapped buffer, for direct CPU writes.
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
	self.device.handle:freeMemory(self.memory)
end

---@param size number bytes to write
---@param offset number? byte offset into the buffer, defaults to 0
---@param data ffi.cdata*? source data, checked when its size is knowable
function VKBuffer:assertWriteFits(size, offset, data)
	layout.assertWriteFits(self, size, offset, data)
end

function VKBuffer:mapAsync()
	-- Coherent memory needs no flush; the caller must still wait for the GPU to finish.
end

--- Range of the buffer visible to the CPU. A mapped buffer offsets its existing pointer
--- rather than asking the driver for a second mapping.
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
	if self.mappedBase then
		return
	end

	self.device.handle:unmapMemory(self.memory)
end

function VKBuffer:__tostring()
	return "VKBuffer(" .. tostring(self.handle) .. ")"
end

return VKBuffer
