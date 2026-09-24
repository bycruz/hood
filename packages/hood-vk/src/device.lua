local vk = require("vkapi")

local VKBuffer = require("hood-vk.buffer")
local VKQueue = require("hood-vk.queue")
local VKPipeline = require("hood-vk.pipeline")
local VKCommandEncoder = require("hood-vk.command_encoder")
local VKSampler = require("hood-vk.sampler")
local VKTexture = require("hood-vk.texture")
local VKComputePipeline = require("hood-vk.compute_pipeline")
local VKBindGroup = require("hood-vk.bind_group")
local VKBindGroupLayout = require("hood-vk.bind_group_layout")
local VKTextureView = require("hood-vk.texture_view")

---@class hood-vk.Device
---@field public queue hood-vk.Queue
---@field handle vk.Device
---@field pd vk.ffi.PhysicalDevice
---@field descriptorPool vk.ffi.DescriptorPool
---@field _renderPassCache table<string, vk.ffi.RenderPass>
local VKDevice = {}
VKDevice.__index = VKDevice

---@param adapter hood-vk.Adapter
function VKDevice.new(adapter)
	local extensions = { "VK_KHR_maintenance1" }
	if not adapter.headless then
		extensions[#extensions + 1] = "VK_KHR_swapchain"
	end

	-- Features the renderer relies on rather than merely tolerates. Supporting a
	-- feature is not the same as enabling it: leaving multiDrawIndirect off makes
	-- a drawCount above 1 invalid, and leaving drawIndirectFirstInstance off makes
	-- a nonzero firstInstance invalid, which is exactly what batched instanced
	-- draws use to address a run partway into a shared instance buffer.
	local supported = vk.getPhysicalDeviceFeatures(adapter.pd)
	local enabledFeatures = {}
	if supported.multiDrawIndirect ~= 0 then
		enabledFeatures.multiDrawIndirect = true
	end
	if supported.drawIndirectFirstInstance ~= 0 then
		enabledFeatures.drawIndirectFirstInstance = true
	end
	if supported.samplerAnisotropy ~= 0 then
		enabledFeatures.samplerAnisotropy = true
	end

	local handle = adapter.instance.handle:createDevice(adapter.pd, {
		enabledExtensionNames = extensions,
		enabledFeatures = enabledFeatures,
		queueCreateInfos = {
			{
				queueFamilyIndex = adapter.gfxQueueFamilyIdx,
				queuePriorities = { 1.0 },
				queueCount = 1,
			},
		},
	})

	local device = setmetatable({ pd = adapter.pd, handle = handle }, VKDevice)
	device.queue = VKQueue.new(device, adapter.gfxQueueFamilyIdx, 0)

	local sizes = vk.DescriptorPoolSizeArray(5)
	sizes[0].type = vk.DescriptorType.STORAGE_BUFFER
	sizes[0].descriptorCount = 256
	sizes[1].type = vk.DescriptorType.SAMPLED_IMAGE
	sizes[1].descriptorCount = 256
	sizes[2].type = vk.DescriptorType.STORAGE_IMAGE
	sizes[2].descriptorCount = 256
	sizes[3].type = vk.DescriptorType.SAMPLER
	sizes[3].descriptorCount = 256
	sizes[4].type = vk.DescriptorType.UNIFORM_BUFFER
	sizes[4].descriptorCount = 256

	-- TODO: Replace with a growing array of descriptor pools later
	device.descriptorPool = handle:createDescriptorPool({
		flags = vk.DescriptorPoolCreateFlagBits.FREE_DESCRIPTOR_SET,
		maxSets = 512,
		poolSizeCount = 5,
		pPoolSizes = sizes,
	})

	-- Cache for render passes keyed by attachment configuration, so we don't
	-- create VkRenderPass objects every frame (they're usually reused).
	device._renderPassCache = {}

	return device
end

---@param descriptor hood.BufferDescriptor
function VKDevice:createBuffer(descriptor)
	return VKBuffer.new(self, descriptor)
end

---@param descriptor hood.PipelineDescriptor
function VKDevice:createPipeline(descriptor)
	return VKPipeline.new(self, descriptor)
end

function VKDevice:createCommandEncoder()
	return VKCommandEncoder.new(self)
end

---@param descriptor hood.BindGroupDescriptor
---@return hood-vk.BindGroup
function VKDevice:createBindGroup(descriptor)
	return VKBindGroup.new(self, descriptor)
end

---@param entries hood.BindingLayout[]
---@return hood.BindGroupLayout{ entries = entries }
function VKDevice:createBindGroupLayout(entries)
	return VKBindGroupLayout.new(self, entries)
end

---@param descriptor hood.TextureDescriptor
function VKDevice:createTexture(descriptor)
	local texture = VKTexture.new(self, descriptor)

	-- A texture that can be sampled is put into the layout descriptors name for
	-- it straight away, so binding it before anything has been written to it is
	-- still valid. Textures that cannot be sampled are left alone: their layouts
	-- belong to the passes and copies that use them.
	self.queue:claimTexture(texture)

	return texture
end

---@param descriptor hood.SamplerDescriptor
function VKDevice:createSampler(descriptor)
	return VKSampler.new(self, descriptor)
end

---@param descriptor hood.ComputePipelineDescriptor
function VKDevice:createComputePipeline(descriptor)
	return VKComputePipeline.new(self, descriptor)
end

return VKDevice
