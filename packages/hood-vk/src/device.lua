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
---@field descriptorPool vk.ffi.DescriptorPool # The pool descriptor sets are handed out of
---@field descriptorPools vk.ffi.DescriptorPool[] # And the ones before it, once it filled up
---@field descriptorSetPools table<vk.ffi.DescriptorSet, vk.ffi.DescriptorPool> # Which pool a set came from
---@field _renderPassCache table<string, vk.ffi.RenderPass>
---@field _commandPool vk.ffi.CommandPool? # Made when the first command buffer is, one per device
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

	device.descriptorPools = {}
	device.descriptorSetPools = {}
	device.descriptorPool = device:createDescriptorPool()

	-- Cache for render passes keyed by attachment configuration, so we don't
	-- create VkRenderPass objects every frame (they're usually reused).
	device._renderPassCache = {}

	return device
end

-- How many descriptor sets a pool holds, and how many of each kind of descriptor they may name.
-- A pool cannot hand out more than this, and one that has handed out all of them is joined by
-- another: a screen with a bind group per picture is a screen that outgrows one pool long before
-- it runs out of anything else.
local POOL_SETS = 512
local POOL_DESCRIPTORS = 256

--- A pool for descriptor sets to be handed out of. A set goes back to the pool it came from when
--- it is freed, so a program that makes and drops them over and over reuses the room it has.
---@return vk.ffi.DescriptorPool
function VKDevice:createDescriptorPool()
	local types = {
		vk.DescriptorType.STORAGE_BUFFER,
		vk.DescriptorType.SAMPLED_IMAGE,
		vk.DescriptorType.STORAGE_IMAGE,
		vk.DescriptorType.SAMPLER,
		vk.DescriptorType.UNIFORM_BUFFER,
	}

	local sizes = vk.DescriptorPoolSizeArray(#types)
	for index, kind in ipairs(types) do
		sizes[index - 1].type = kind
		sizes[index - 1].descriptorCount = POOL_DESCRIPTORS
	end

	local pool = self.handle:createDescriptorPool({
		flags = vk.DescriptorPoolCreateFlagBits.FREE_DESCRIPTOR_SET,
		maxSets = POOL_SETS,
		poolSizeCount = #types,
		pPoolSizes = sizes,
	})

	self.descriptorPools[#self.descriptorPools + 1] = pool

	return pool
end

--- Allocates a descriptor set from the layout, out of the pool that is open, and out of a new pool
--- when that one is full: what a pool has room for is fixed when it is made, so an app that makes
--- a bind group per picture would otherwise stop being able to draw one.
---@param layout vk.ffi.DescriptorSetLayout
---@return vk.ffi.DescriptorSet
function VKDevice:createDescriptorSet(layout)
	local set = self:tryDescriptorSet(self.descriptorPool, layout)

	if not set then
		self.descriptorPool = self:createDescriptorPool()
		set = self:tryDescriptorSet(self.descriptorPool, layout)
	end

	if not set then
		error("hood: a descriptor set could not be allocated from a pool of " .. POOL_SETS .. " sets")
	end

	self.descriptorSetPools[set] = self.descriptorPool

	return set
end

---@param pool vk.ffi.DescriptorPool
---@param layout vk.ffi.DescriptorSetLayout
---@return vk.ffi.DescriptorSet? set # Nothing when the pool has no room for one
function VKDevice:tryDescriptorSet(pool, layout)
	local layouts = vk.DescriptorSetLayoutArray(1)
	layouts[0] = layout

	local ok, sets = pcall(self.handle.allocateDescriptorSets, self.handle, {
		descriptorPool = pool,
		descriptorSetCount = 1,
		pSetLayouts = layouts,
	})

	if not ok then
		-- The pool is out of sets or out of descriptors: an empty one is made for this one to
		-- come out of, which is the caller's to do.
		return nil
	end

	return sets[1]
end

--- Hands a descriptor set back to the pool it came from. The set is not to be used again after
--- this, and what it named -- a texture, a buffer, a sampler -- is not this call's to free.
---@param set vk.ffi.DescriptorSet
function VKDevice:freeDescriptorSet(set)
	local pool = self.descriptorSetPools[set]

	if pool == nil then
		return
	end

	self.descriptorSetPools[set] = nil
	self.handle:freeDescriptorSets(pool, { set })
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

--- The pool command buffers are allocated from, which belongs to the device rather
--- than to each of them. A command buffer is small; a pool is the driver's to size and
--- is hundreds of kilobytes, so an app that records a frame into a fresh buffer every
--- frame -- which is the obvious way to write one -- would grow by a pool a frame if
--- each buffer carried its own. Buffers are handed back to the pool instead: see
--- `VKCommandBuffer:destroy`.
---@return vk.ffi.CommandPool
function VKDevice:commandPool()
	if not self._commandPool then
		self._commandPool = self.handle:createCommandPool({
			flags = vk.CommandPoolCreateFlagBits.RESET_COMMAND_BUFFER,
			queueFamilyIndex = self.queue.familyIdx,
		})
	end

	return self._commandPool
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
