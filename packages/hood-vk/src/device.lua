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
---@field _renderPassCache table<string, vk.ffi.RenderPass> # Render passes by attachment signature
---@field _framebufferCache table<string, vk.ffi.Framebuffer> # Framebuffers by render pass and images
---@field _commandPool vk.ffi.CommandPool? # Made when the first command buffer is, one per device
local VKDevice = {}
VKDevice.__index = VKDevice

---@param adapter hood-vk.Adapter
function VKDevice.new(adapter)
	local extensions = { "VK_KHR_maintenance1" }
	if not adapter.headless then
		extensions[#extensions + 1] = "VK_KHR_swapchain"
	end

	-- Relied on rather than merely tolerated: enabling a feature is separate from supporting it,
	-- and without multiDrawIndirect a drawCount above 1 is invalid while without
	-- drawIndirectFirstInstance a nonzero firstInstance is.
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
			{ queueFamilyIndex = adapter.gfxQueueFamilyIdx, queuePriorities = { 1.0 }, queueCount = 1 },
		},
	})

	local device = setmetatable({ pd = adapter.pd, handle = handle }, VKDevice)
	device.queue = VKQueue.new(device, adapter.gfxQueueFamilyIdx, 0)

	device.descriptorPools = {}
	device.descriptorSetPools = {}
	device.descriptorPool = device:createDescriptorPool()

	-- Keyed by what they were made from, so a frame that renders the same way reuses them.
	device._renderPassCache = {}
	device._framebufferCache = {}

	return device
end

-- How many sets a pool holds and how many of each descriptor they may name. A full pool is
-- joined by another, since an app with a bind group per picture outgrows one long before it runs
-- out of anything else.
local POOL_SETS = 512
local POOL_DESCRIPTORS = 256

--- A pool for descriptor sets to be handed out of. A freed set returns to its pool, so an app
--- that makes and drops them reuses the room it has.
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
		maxSets = POOL_SETS, poolSizeCount = #types, pPoolSizes = sizes,
	})

	self.descriptorPools[#self.descriptorPools + 1] = pool

	return pool
end

--- Allocate a descriptor set from the open pool, or from a new one when that is full: a pool's
--- capacity is fixed when it is made.
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

	local ok, sets = pcall(self.handle.allocateDescriptorSets, self.handle,
		{ descriptorPool = pool, descriptorSetCount = 1, pSetLayouts = layouts })

	if not ok then
		-- Out of sets or out of descriptors; the caller makes another pool.
		return nil
	end

	return sets[1]
end

--- Hand a descriptor set back to its pool. The set is not usable afterwards, and what it named
--- is not this call's to free.
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

--- The pool command buffers are allocated from, which belongs to the device: a pool is hundreds
--- of kilobytes, so a buffer carrying its own would grow the process by a pool per buffer.
--- Buffers are handed back instead: see `VKCommandBuffer:destroy`.
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

--- Hand a command buffer back to its pool, to be handed out again by the next allocation. The
--- device does it because the pool is the device's.
---@param pool vk.ffi.CommandPool
---@param buffer vk.ffi.CommandBuffer
function VKDevice:freeCommandBuffers(pool, buffer)
	self.handle:freeCommandBuffers(pool, buffer)
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

	-- A samplable texture goes into the layout its descriptors name straight away, so binding it
	-- before anything was written to it is valid. The rest are left to the passes that use them.
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
