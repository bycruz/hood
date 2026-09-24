local ffi = require("ffi")

local vk = require("vkapi")
local vkConversions = require("hood-vk.convert")

---@class hood-vk.BindGroup: hood.BindGroup
---@field layout hood-vk.BindGroupLayout
---@field set vk.ffi.DescriptorSet
---@field private device hood-vk.Device
local BindGroup = {}
BindGroup.__index = BindGroup

---@param device hood-vk.Device
---@param descriptor hood.BindGroupDescriptor
function BindGroup.new(device, descriptor)
	local entries = descriptor.entries
	local layout = descriptor.layout --[[@as hood-vk.BindGroupLayout]]

	-- The set comes out of the device's open pool, and out of a new one when that is full: a
	-- bind group per texture is an app that makes hundreds of them.
	local set = device:createDescriptorSet(layout.handle)

	local writes = vk.WriteDescriptorSetArray(#entries)
	for i, entry in ipairs(entries) do
		writes[i - 1].dstSet = set
		writes[i - 1].dstBinding = entry.binding
		writes[i - 1].descriptorCount = 1 -- TODO: Support types with count?
		writes[i - 1].descriptorType = vkConversions.bindingType[entry.type]

		if entry.type == "uniform-buffer" or entry.type == "storage-buffer" or entry.type == "buffer" then
			local vkBuffer = entry.buffer --[[@as hood-vk.Buffer]]

			local bufferInfos = vk.DescriptorBufferInfoArray(1)
			bufferInfos[0].buffer = vkBuffer.handle
			bufferInfos[0].offset = 0
			bufferInfos[0].range = vk.WHOLE_SIZE

			writes[i - 1].pBufferInfo = bufferInfos
		elseif entry.type == "texture" then
			local vkTextureView = entry.texture --[[@as hood-vk.TextureView]]

			local imageInfos = vk.DescriptorImageInfoArray(1)
			imageInfos[0].imageView = vkTextureView.handle
			imageInfos[0].imageLayout = vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL

			writes[i - 1].pImageInfo = imageInfos
		elseif entry.type == "storageTexture" then
			local vkTextureView = entry.texture --[[@as hood-vk.TextureView]]

			local imageInfos = vk.DescriptorImageInfoArray(1)
			imageInfos[0].imageView = vkTextureView.handle
			imageInfos[0].imageLayout = vk.ImageLayout.GENERAL

			writes[i - 1].pImageInfo = imageInfos
		elseif entry.type == "sampler" then
			local vkSampler = entry.sampler --[[@as hood-vk.Sampler]]

			local imageInfos = vk.DescriptorImageInfoArray(1)
			imageInfos[0].sampler = vkSampler.handle

			writes[i - 1].pImageInfo = imageInfos
		else
			error("Unsupported bind group entry type: " .. entry.type)
		end
	end

	device.handle:updateDescriptorSets(#entries, writes)

	return setmetatable({ device = device, layout = layout, set = set, entries = entries }, BindGroup)
end

--- Hands the set back to the pool it came from, which is what it is to be dropped with.
---
--- The layout is not this group's to free: several groups are made with one layout, and a destroy
--- that freed it would leave every other group holding nothing. A layout is freed by the caller
--- that made it, once the groups that were made with it are gone.
function BindGroup:destroy()
	self.device:freeDescriptorSet(self.set)
	self.set = nil
end

return BindGroup
