--- Device memory selection and staging allocations, shared by the Vulkan
--- buffer and command encoder paths.
---
--- Before this existed the "walk the memory types looking for flags" loop was
--- written out three times: twice in buffer creation and once inline in
--- writeTexture, each with slightly different fallback behaviour.
local vk = require("vkapi")
local ffi = require("ffi")

local M = {}

--- Find a memory type index that satisfies `requiredFlags`, preferring one that
--- also satisfies `preferredFlags`.
---
--- The preference matters for the two cases this is used for: a host-visible
--- buffer is much faster for the GPU to read if it also happens to be
--- device-local (resizable BAR), and a device-local buffer for GPU-only use
--- should not fall back to system memory unless nothing else is offered.
---
--- Falls back to the first type satisfying `requiredFlags` when no type
--- satisfies both, so a machine without the preferred combination still works.
---@param device hood-vk.Device
---@param typeBits number? from VkMemoryRequirements.memoryTypeBits
---@param requiredFlags number
---@param preferredFlags number?
---@return number? index nil when no type satisfies requiredFlags
function M.findType(device, typeBits, requiredFlags, preferredFlags)
	preferredFlags = preferredFlags or 0
	typeBits = typeBits and tonumber(typeBits) or 0

	local memProps = vk.getPhysicalDeviceMemoryProperties(device.pd)
	local count = tonumber(memProps.memoryTypeCount)
	local fallback

	for i = 0, count - 1 do
		if typeBits == 0 or bit.band(typeBits, bit.lshift(1, i)) ~= 0 then
			local flags = tonumber(memProps.memoryTypes[i].propertyFlags)
			if bit.band(flags, requiredFlags) == requiredFlags then
				if bit.band(flags, preferredFlags) == preferredFlags then
					return i
				end
				if not fallback then
					fallback = i
				end
			end
		end
	end

	return fallback
end

--- Host-visible and coherent memory, preferring device-local. Coherent means no
--- explicit vkFlushMappedMemoryRanges is ever needed.
M.HOST_CACHED_FLAGS = bit.bor(
	vk.MemoryPropertyFlagBits.HOST_VISIBLE,
	vk.MemoryPropertyFlagBits.HOST_COHERENT
)

--- Create a host-visible buffer of `size` bytes and map it permanently.
---
--- Used for staging uploads and by buffers created with `mapped = true`. The
--- mapping is never released: coherent memory needs no flush, and remapping per
--- use would defeat the point.
---@param device hood-vk.Device
---@param size number
---@param usage number
---@return { buffer: vk.ffi.Buffer, memory: vk.ffi.DeviceMemory, pointer: ffi.cdata*, size: number }
function M.createMapped(device, size, usage)
	local handle = device.handle:createBuffer({ size = size, usage = usage })
	local requirements = device.handle:getBufferMemoryRequirements(handle)

	local index = M.findType(device, tonumber(requirements.memoryTypeBits),
		M.HOST_CACHED_FLAGS, vk.MemoryPropertyFlagBits.DEVICE_LOCAL)
	if not index then
		device.handle:destroyBuffer(handle)
		error("hood: no host-visible coherent memory type available")
	end

	local memory = device.handle:allocateMemory({
		allocationSize = requirements.size,
		memoryTypeIndex = index,
	})
	device.handle:bindBufferMemory(handle, memory, 0)

	-- Mapped as a byte pointer so callers can offset it arithmetically; LuaJIT
	-- does not define arithmetic on void*.
	local pointer = ffi.cast("uint8_t*", device.handle:mapMemory(memory, 0, size))

	return { buffer = handle, memory = memory, pointer = pointer, size = size }
end

return M
