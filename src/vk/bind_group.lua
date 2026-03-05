local ffi = require("ffi")

local vk = require("vkapi")
local vkConversions = require("hood.convert.vk")

---@class hood.vk.BindGroup: hood.BindGroup
---@field layout vk.ffi.DescriptorSetLayout
---@field set vk.ffi.DescriptorSet
local BindGroup = {}
BindGroup.__index = BindGroup

---@param device hood.vk.Device
---@param descriptor hood.BindGroupDescriptor
function BindGroup.new(device, descriptor)
	local entries = descriptor.entries
	local layout = descriptor.layout --[[@as hood.vk.BindGroupLayout]]

	-- SAFETY: Vulkan only needs to read it for the lifetime of the call
	local layoutArray = vk.DescriptorSetLayoutArray(1)
	layoutArray[0] = layout.handle

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

		if entry.type == "buffer" then
			local vkBuffer = entry.buffer --[[@as hood.vk.Buffer]]

			local bufferInfos = vk.DescriptorBufferInfoArray(1)
			bufferInfos[0].buffer = vkBuffer.handle
			bufferInfos[0].offset = 0
			bufferInfos[0].range = vk.WHOLE_SIZE

			writes[i - 1].pBufferInfo = bufferInfos
		elseif entry.type == "texture" then
			local vkTextureView = entry.texture --[[@as hood.vk.TextureView]]

			local imageInfos = vk.DescriptorImageInfoArray(1)
			imageInfos[0].imageView = vkTextureView.handle
			imageInfos[0].imageLayout = vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL

			writes[i - 1].pImageInfo = imageInfos
		end
	end

	device.handle:updateDescriptorSets(1, writes)

	return setmetatable({ layout = layout, set = set, entries = entries }, BindGroup)
end

return BindGroup
