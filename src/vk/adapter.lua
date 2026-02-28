local vk = require("vkapi")

local VKDevice = require("hood.vk.device")

---@class hood.vk.Adapter
---@field instance hood.vk.Instance
---@field pd vk.ffi.PhysicalDevice
---@field gfxQueueFamilyIdx number
local VKAdapter = {}
VKAdapter.__index = VKAdapter

---@param instance hood.vk.Instance
---@param physicalDevice vk.ffi.PhysicalDevice
function VKAdapter.new(instance, physicalDevice)
	local queueFamilies = vk.getPhysicalDeviceQueueFamilyProperties(physicalDevice)

	local gfxQueueFamilyIdx = nil
	for i, family in ipairs(queueFamilies) do
		if bit.band(family.queueFlags, vk.QueueFlagBits.GRAPHICS) ~= 0 then
			gfxQueueFamilyIdx = i - 1 -- zero-based index
			break
		end
	end

	if not gfxQueueFamilyIdx then
		error("No graphics queue family found")
	end

	return setmetatable({ instance = instance, pd = physicalDevice, gfxQueueFamilyIdx = gfxQueueFamilyIdx }, VKAdapter)
end

function VKAdapter:requestDevice()
	return VKDevice.new(self)
end

return VKAdapter
