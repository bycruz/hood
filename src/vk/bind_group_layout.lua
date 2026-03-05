local vk = require("vkapi")
local vkConversions = require("hood.convert.vk")

---@class hood.vk.BindGroupLayout: hood.BindGroupLayout
---@field handle vk.ffi.DescriptorSetLayout
local VKBindGroupLayout = {}

---@param device hood.vk.Device
---@param entries hood.BindingLayout[]
---@return hood.vk.BindGroupLayout
function VKBindGroupLayout.new(device, entries)
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

	local handle = device.handle:createDescriptorSetLayout({
		bindingCount = #entries,
		pBindings = bindings
	})

	return setmetatable({ handle = handle, entries = entries }, VKBindGroupLayout)
end

return VKBindGroupLayout
