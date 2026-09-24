local GLBuffer = require("hood-gl.buffer")
local GLCommandEncoder = require("hood-gl.command_encoder")
local GLContext = require("hood-gl.context")
local GLQueue = require("hood-gl.queue")
local GLPipeline = require("hood-gl.pipeline")
local GLSampler = require("hood-gl.sampler")
local GLTexture = require("hood-gl.texture")
local GLComputePipeline = require("hood-gl.compute_pipeline")

---@class hood-gl.Device
---@field public queue hood-gl.Queue
---@field ctx hood-gl.Context
local GLDevice = {}
GLDevice.__index = GLDevice

function GLDevice.new()
	local ctx = GLContext.fromHeadless()
	local queue = GLQueue.new(ctx)

	return setmetatable({ queue = queue, ctx = ctx }, GLDevice)
end

---@param descriptor hood.BufferDescriptor
function GLDevice:createBuffer(descriptor)
	self.ctx:makeCurrent()
	return GLBuffer.new(descriptor)
end

function GLDevice:createCommandEncoder()
	return GLCommandEncoder.new()
end

---@param descriptor hood.PipelineDescriptor
function GLDevice:createPipeline(descriptor)
	self.ctx:makeCurrent()
	return GLPipeline.new(self, descriptor)
end

---@param descriptor hood.BindGroupDescriptor
---@return hood.BindGroup
function GLDevice:createBindGroup(descriptor)
	-- A group here is the entries a draw call binds and nothing else: what it names is bound when
	-- it is set, so there is no object of the driver's to free and `destroy` says so rather than
	-- being missing -- a caller that frees its groups should not have to ask whether this backend
	-- has any.
	return {
		entries = descriptor.entries,

		destroy = function(self)
			self.entries = {}
		end,
	}
end

---@param entries hood.BindingLayout[]
---@return hood.BindGroupLayout
function GLDevice:createBindGroupLayout(entries)
	return {
		entries = entries,

		destroy = function(self)
			self.entries = {}
		end,
	}
end

---@param descriptor hood.SamplerDescriptor
function GLDevice:createSampler(descriptor)
	self.ctx:makeCurrent()
	return GLSampler.new(descriptor)
end

---@param descriptor hood.TextureDescriptor
function GLDevice:createTexture(descriptor)
	self.ctx:makeCurrent()
	return GLTexture.new(self, descriptor)
end

---@param descriptor hood.ComputePipelineDescriptor
function GLDevice:createComputePipeline(descriptor)
	self.ctx:makeCurrent()
	return GLComputePipeline.new(self, descriptor)
end

return GLDevice
