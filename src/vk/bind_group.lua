local ffi = require("ffi")

local vk = require("vkapi")
local vkConversions = require("hood.convert.vk")

---@class hood.vk.BindGroup: hood.BindGroup
---@field layout vk.ffi.DescriptorSetLayout
---@field set vk.ffi.DescriptorSet
local BindGroup = {}
BindGroup.__index = BindGroup

---@param device hood.vk.Device
---@param entries hood.Binding[]
function BindGroup.new(device, entries)
	local bindings = vk.DescriptorSetLayoutBindingArray(#entries)
	for i, entry in ipairs(entries) do
		local stageFlags = 0
		for _, stage in ipairs(entry.visibility) do
			stageFlags = bit.bor(stageFlags, vkConversions.shaderStage[stage])
		end

		bindings[i - 1].binding = entry.binding
		bindings[i - 1].descriptorType = vkConversions.bindingType[entry.type]
		bindings[i - 1].descriptorCount = 1
		bindings[i - 1].stageFlags = stageFlags
	end

	local layout = device.handle:createDescriptorSetLayout({
		bindingCount = #entries,
		pBindings = bindings
	})

	-- SAFETY: Vulkan only needs to read it for the lifetime of the call
	local layoutArray = vk.DescriptorSetLayoutArray(1)
	layoutArray[0] = layout

	local set = device.handle:allocateDescriptorSets({
		descriptorPool = device.descriptorPool,
		descriptorSetCount = 1,
		pSetLayouts = layoutArray
	})[1]

	local writes = vk.WriteDescriptorSetArray(#entries)
	for i, entry in ipairs(entries) do
		writes[i - 1].dstSet = set
		writes[i - 1].dstBinding = entry.binding
		writes[i - 1].descriptorCount = 1 -- TODO: Support types with count?
		writes[i - 1].descriptorType = vkConversions.bindingType[entry.type]
	end

	device.handle:updateDescriptorSets(1, writes)

	return setmetatable({ layout = layout, set = set, entries = entries }, BindGroup)
end

return BindGroup
