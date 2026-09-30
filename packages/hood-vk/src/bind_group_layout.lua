local vk = require("vkapi")
local vkConversions = require("hood-vk.convert")

---@class hood-vk.BindGroupLayout: hood.BindGroupLayout
---@field handle vk.ffi.DescriptorSetLayout
---@field private device hood-vk.Device
local VKBindGroupLayout = {}
VKBindGroupLayout.__index = VKBindGroupLayout

---@param device hood-vk.Device
---@param entries hood.BindingLayout[]
---@return hood-vk.BindGroupLayout
function VKBindGroupLayout.new(device, entries)
	local bindings = vk.DescriptorSetLayoutBindingArray(#entries)
	for i, entry in ipairs(entries) do
		local stageFlags = 0
		for _, stage in ipairs(entry.visibility) do
			stageFlags = bit.bor(stageFlags, vkConversions.shaderStage[stage])
		end

		local binding = bindings[i - 1]
		binding.binding = entry.binding
		binding.descriptorType = vkConversions.bindingType[entry.type]
		binding.descriptorCount = 1
		binding.stageFlags = stageFlags
	end

	local handle = device.handle:createDescriptorSetLayout({ bindingCount = #entries, pBindings = bindings })

	return setmetatable({ device = device, handle = handle, entries = entries }, VKBindGroupLayout)
end

function VKBindGroupLayout:destroy()
	self.device.handle:destroyDescriptorSetLayout(self.handle)
end

return VKBindGroupLayout
