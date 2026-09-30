local vk = require("vkapi")

local M = {}

--- Every memory type index that satisfies `requiredFlags`, the ones that also satisfy
--- `preferredFlags` first.
---
--- The preference is what the machine is asked for first, not what it can only give: host-visible
--- memory that is also device-local is a small window rather than the whole card, and that window
--- can be full of what every other program on the machine is holding. The types after the
--- preferred ones are the same memory asked for without it, so an allocation falls back to
--- system memory instead of failing.
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

--- Allocate device memory of the size `requirements` asks for, from the first type that has room
--- for it: a type being available is not the same as a type having space, so a failed allocation is
--- retried against the next usable type rather than reported straight away.
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
		local ok, memory = pcall(device.handle.allocateMemory, device.handle,
			{ allocationSize = requirements.size, memoryTypeIndex = index })

		if ok then
			return memory
		end

		failure = failure or memory
	end

	error(string.format("hood: could not allocate memory for a %s of %s bytes: %s", what,
		tostring(requirements.size), tostring(failure)))
end

--- Host-visible, coherent memory. Coherent means no explicit vkFlushMappedMemoryRanges is
--- ever needed, which is what lets a mapped buffer be written by the CPU at any time.
M.HOST_VISIBLE_FLAGS = bit.bor(
	vk.MemoryPropertyFlagBits.HOST_VISIBLE,
	vk.MemoryPropertyFlagBits.HOST_COHERENT
)

return M
