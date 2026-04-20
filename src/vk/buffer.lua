local vk = require("vkapi")

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
	local memProps = vk.getPhysicalDeviceMemoryProperties(device.pd)
	local memTypeIndex = nil
	local fallbackIndex = nil

	local requiredFlags = needsHostVisible
		and bit.bor(vk.MemoryPropertyFlagBits.HOST_VISIBLE, vk.MemoryPropertyFlagBits.HOST_COHERENT)
		or vk.MemoryPropertyFlagBits.DEVICE_LOCAL

	-- TODO: Refactor this slop
	local typeBits = tonumber(requirements.memoryTypeBits)
	local count = tonumber(memProps.memoryTypeCount)
	for i = 0, count - 1 do
		if typeBits == 0 or bit.band(typeBits, bit.lshift(1, i)) ~= 0 then
			if not fallbackIndex then
				fallbackIndex = i
			end
			if bit.band(tonumber(memProps.memoryTypes[i].propertyFlags), requiredFlags) == requiredFlags then
				memTypeIndex = i
				break
			end
		end
	end

	memTypeIndex = memTypeIndex or fallbackIndex
	if not memTypeIndex then
		error("Failed to find compatible memory type for buffer")
	end

	local memory = device.handle:allocateMemory({
		allocationSize = requirements.size,
		memoryTypeIndex = memTypeIndex,
	})
	device.handle:bindBufferMemory(handle, memory, 0)

	return setmetatable({ device = device, handle = handle, memory = memory, descriptor = descriptor }, VKBuffer)
end

function VKBuffer:destroy()
	self.device.handle:destroyBuffer(self.handle)
end

function VKBuffer:mapAsync()
	-- No-op: memory is HOST_COHERENT, no explicit flush needed.
	-- Caller must ensure GPU work is complete (queue:waitIdle) before reading.
end

---@param offset number?
---@param size number?
---@return ffi.cdata*
function VKBuffer:getMappedRange(offset, size)
	return self.device.handle:mapMemory(self.memory, offset or 0, size or self.descriptor.size)
end

function VKBuffer:unmap()
	self.device.handle:unmapMemory(self.memory)
end

function VKBuffer:__tostring()
	return "VKBuffer(" .. tostring(self.handle) .. ")"
end

return VKBuffer
