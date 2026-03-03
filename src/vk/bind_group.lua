local ffi = require("ffi")

---@class hood.vk.BindGroup: hood.BindGroup
---@field layout vk.ffi.DescriptorSetLayout
---@field set vk.ffi.DescriptorSet
local BindGroup = {}
BindGroup.__index = BindGroup

---@param device hood.vk.Device
---@param entries hood.BindGroupEntry[]
function BindGroup.new(device, entries)
	local layout = device.handle:createDescriptorSetLayout({})
	local set = device.handle:allocateDescriptorSets({
		descriptorPool = device.descriptorPool,
		descriptorSetCount = 1,
		-- SAFETY: Vulkan only needs to read it for the lifetime of the call
		pSetLayouts = ffi.new("VkDescriptorSetLayout*", layout)
	})[1]

	return setmetatable({ layout = layout, set = set, entries = entries }, BindGroup)
end

return BindGroup
