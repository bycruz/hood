local vk = require("hood-vulkan")

---@class hood.vk.Buffer
---@field handle vk.ffi.Buffer
---@field device hood.vk.Device
---@field descriptor hood.BufferDescriptor
local VKBuffer = {}
VKBuffer.__index = VKBuffer

---@param device hood.vk.Device
---@param descriptor hood.BufferDescriptor
function VKBuffer.new(device, descriptor)
	local vkUsage = 0

	for _, usage in ipairs(descriptor.usages) do
		if usage == "VERTEX" then
			vkUsage = bit.bor(vkUsage, vk.BufferUsage.VERTEX_BUFFER)
		elseif usage == "INDEX" then
			vkUsage = bit.bor(vkUsage, vk.BufferUsage.INDEX_BUFFER)
		elseif usage == "UNIFORM" then
			vkUsage = bit.bor(vkUsage, vk.BufferUsage.UNIFORM_BUFFER)
		elseif usage == "COPY_DST" then
			vkUsage = bit.bor(vkUsage, vk.BufferUsage.TRANSFER_DST)
		elseif usage == "COPY_SRC" then
			vkUsage = bit.bor(vkUsage, vk.BufferUsage.TRANSFER_SRC)
		elseif usage == "STORAGE" then
			vkUsage = bit.bor(vkUsage, vk.BufferUsage.STORAGE_BUFFER)
		else
			error("Invalid buffer usage: " .. tostring(usage))
		end
	end

	if vkUsage == 0 then
		error("No valid buffer usage specified")
	end

	---@diagnostic disable-next-line: assign-type-mismatch: vkUsage is checked above
	local handle = device.handle:createBuffer({ size = descriptor.size, usage = vkUsage })

	-- Allocate and attach memory
	local requirements = device.handle:getBufferMemoryRequirements(handle)
	local memProps = vk.getPhysicalDeviceMemoryProperties(device.pd)
	local memTypeIndex = nil
	local fallbackIndex = nil

	-- Prefer DEVICE_LOCAL, fall back to any compatible type
	-- TODO: Refactor this slop
	local typeBits = tonumber(requirements.memoryTypeBits)
	local count = tonumber(memProps.memoryTypeCount)
	for i = 0, count - 1 do
		-- If memoryTypeBits is 0 (driver doesn't constrain), consider all types
		if typeBits == 0 or bit.band(typeBits, bit.lshift(1, i)) ~= 0 then
			if not fallbackIndex then
				fallbackIndex = i
			end

			if bit.band(tonumber(memProps.memoryTypes[i].propertyFlags), vk.MemoryPropertyFlags.DEVICE_LOCAL) ~= 0 then
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

	return setmetatable({ device = device, handle = handle, descriptor = descriptor }, VKBuffer)
end

function VKBuffer:destroy()
	self.device.handle:destroyBuffer(self.handle)
end

function VKBuffer:__tostring()
	return "VKBuffer(" .. tostring(self.handle) .. ")"
end

return VKBuffer
