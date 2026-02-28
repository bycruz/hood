local VKBuffer = require("hood.buffer.vk")
local VKQueue = require("hood.queue.vk")
local VKPipeline = require("hood.pipeline.vk")
local VKCommandEncoder = require("hood.command_encoder.vk")
local VKSampler = require("hood.sampler.vk")
local VKTexture = require("hood.texture.vk")
local VKComputePipeline = require("hood.compute_pipeline.vk")

local BindGroup = require("hood.bind_group")

---@class hood.vk.Device
---@field public queue hood.vk.Queue
---@field handle vk.Device
---@field pd vk.ffi.PhysicalDevice
local VKDevice = {}
VKDevice.__index = VKDevice

---@param adapter hood.vk.Adapter
function VKDevice.new(adapter)
	local handle = adapter.instance.handle:createDevice(adapter.pd, {
		enabledExtensionNames = { "VK_KHR_swapchain", "VK_KHR_maintenance1" },
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

---@param entries hood.BindGroupEntry[]
function VKDevice:createBindGroup(entries)
	return BindGroup.new(entries)
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
