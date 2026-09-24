--- Device memory selection and staging allocations, shared by the Vulkan
--- buffer and command encoder paths.
---
--- Before this existed the "walk the memory types looking for flags" loop was
--- written out three times: twice in buffer creation and once inline in
--- writeTexture, each with slightly different fallback behaviour.
local vk = require("vkapi")
local ffi = require("ffi")

local M = {}

--- Every memory type index that satisfies `requiredFlags`, the ones that also satisfy
--- `preferredFlags` first.
---
--- The preference is what a machine is asked for first, not what it can only give: a host-visible
--- buffer is much faster for the GPU to read out of device-local memory, but the memory a driver
--- hands out that way is a small window rather than the whole card -- a resizable BAR is what a
--- machine with a large one has -- and that window can be full of what the window manager and
--- every other program on the machine are holding. The types after the preferred ones are the
--- same memory asked for without it, which is where an upload goes when the window is busy.
---@param device hood-vk.Device
---@param typeBits number? from VkMemoryRequirements.memoryTypeBits
---@param requiredFlags number
---@param preferredFlags number?
---@return number[] indices
function M.findTypes(device, typeBits, requiredFlags, preferredFlags)
	preferredFlags = preferredFlags or 0
	typeBits = typeBits and tonumber(typeBits) or 0

	local memProps = vk.getPhysicalDeviceMemoryProperties(device.pd)
	local count = tonumber(memProps.memoryTypeCount)
	local preferred, rest = {}, {}

	for i = 0, count - 1 do
		if typeBits == 0 or bit.band(typeBits, bit.lshift(1, i)) ~= 0 then
			local flags = tonumber(memProps.memoryTypes[i].propertyFlags)

			if bit.band(flags, requiredFlags) == requiredFlags then
				if bit.band(flags, preferredFlags) == preferredFlags then
					preferred[#preferred + 1] = i
				else
					rest[#rest + 1] = i
				end
			end
		end
	end

	for _, index in ipairs(rest) do
		preferred[#preferred + 1] = index
	end

	return preferred
end

--- Find a memory type index that satisfies `requiredFlags`, preferring one that
--- also satisfies `preferredFlags`. This is the first of `findTypes`, for a caller that
--- wants the one a machine would rather hand out rather than all of them.
---@param device hood-vk.Device
---@param typeBits number? from VkMemoryRequirements.memoryTypeBits
---@param requiredFlags number
---@param preferredFlags number?
---@return number? index nil when no type satisfies requiredFlags
function M.findType(device, typeBits, requiredFlags, preferredFlags)
	return M.findTypes(device, typeBits, requiredFlags, preferredFlags)[1]
end

--- Allocate device memory of the size `requirements` asks for, from the first type that has room
--- for it: a type being available is not the same as a type having space, which is what an
--- allocation that only ever tried the preferred one got wrong.
---
--- What a failed allocation says is the driver's -- out of device memory -- and the next type
--- along is asked before giving up, which is what lands an upload of a size the window cannot hold
--- in system memory rather than nowhere.
---@param device hood-vk.Device
---@param requirements vk.ffi.MemoryRequirements
---@param requiredFlags number
---@param preferredFlags number?
---@param what string # What is being allocated, for a message that says what failed
---@return vk.ffi.DeviceMemory
function M.allocate(device, requirements, requiredFlags, preferredFlags, what)
	local indices = M.findTypes(device, tonumber(requirements.memoryTypeBits), requiredFlags, preferredFlags)

	if #indices == 0 then
		error("hood: no memory type for a " .. what)
	end

	local failure

	for _, index in ipairs(indices) do
		local ok, memory = pcall(device.handle.allocateMemory, device.handle, {
			allocationSize = requirements.size,
			memoryTypeIndex = index,
		})

		if ok then
			return memory
		end

		failure = failure or memory
	end

	error(string.format("hood: could not allocate memory for a %s of %s bytes: %s", what,
		tostring(requirements.size), tostring(failure)))
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
---
--- Device-local host-visible memory is asked for first, because the GPU reading an upload out of
--- device memory rather than over the bus is what makes it fast, and system memory is taken when
--- that window has no room left: an upload of a size the window cannot hold is then slow rather
--- than impossible, which is what it used to be.
---@param device hood-vk.Device
---@param size number
---@param usage number
---@return { buffer: vk.ffi.Buffer, memory: vk.ffi.DeviceMemory, pointer: ffi.cdata*, size: number }
function M.createMapped(device, size, usage)
	local handle = device.handle:createBuffer({ size = size, usage = usage })
	local requirements = device.handle:getBufferMemoryRequirements(handle)

	local ok, memory = pcall(M.allocate, device, requirements, M.HOST_CACHED_FLAGS,
		vk.MemoryPropertyFlagBits.DEVICE_LOCAL, "host visible staging buffer")

	if not ok then
		device.handle:destroyBuffer(handle)
		error(memory)
	end

	device.handle:bindBufferMemory(handle, memory, 0)

	-- Mapped as a byte pointer so callers can offset it arithmetically; LuaJIT
	-- does not define arithmetic on void*.
	local pointer = ffi.cast("uint8_t*", device.handle:mapMemory(memory, 0, size))

	return { buffer = handle, memory = memory, pointer = pointer, size = size }
end

return M
