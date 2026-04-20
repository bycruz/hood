local vk = require("vkapi")

local VKBuffer = require("hood.vk.buffer")
local VKQueue = require("hood.vk.queue")
local VKPipeline = require("hood.vk.pipeline")
local VKCommandEncoder = require("hood.vk.command_encoder")
local VKSampler = require("hood.vk.sampler")
local VKTexture = require("hood.vk.texture")
local VKComputePipeline = require("hood.vk.compute_pipeline")
local VKBindGroup = require("hood.vk.bind_group")
local VKBindGroupLayout = require("hood.vk.bind_group_layout")
local VKTextureView = require("hood.vk.texture_view")

---@class hood.vk.Device
---@field public queue hood.vk.Queue
---@field handle vk.Device
---@field pd vk.ffi.PhysicalDevice
---@field descriptorPool vk.ffi.DescriptorPool
local VKDevice = {}
VKDevice.__index = VKDevice

---@param adapter hood.vk.Adapter
function VKDevice.new(adapter)
	local extensions = { "VK_KHR_maintenance1" }
	if not adapter.headless then
		extensions[#extensions + 1] = "VK_KHR_swapchain"
	end

	local handle = adapter.instance.handle:createDevice(adapter.pd, {
		enabledExtensionNames = extensions,
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
		maxSets = 512,
		poolSizeCount = 5,
		pPoolSizes = sizes,
	})

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
---@return hood.vk.BindGroup
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
	return VKTexture.new(self, descriptor)
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
