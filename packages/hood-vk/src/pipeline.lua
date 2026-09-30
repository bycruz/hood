local ffi = require("ffi")

local vk = require("vkapi")
local coreLayout = require("hood-core.layout")
local pass = require("hood-vk.pass")
local vkConversions = require("hood-vk.convert")

--- Vertex attribute formats, keyed by the layout's attribute type and size.
---
--- The narrow types exist so a vertex can be packed: a normal costs four bytes
--- as 8 bit signed normalized components rather than twelve as floats, and a
--- colour costs four as unsigned normalized rather than sixteen. Sizes without
--- a format -- three components of anything smaller than 32 bits, since there is
--- no 24 bit RGB vertex format -- are rejected by the lookup below.
---@type table<string, vk.Format[]>
local attributeFormatMap = {
	f32 = {
		[1] = vk.Format.R32_SFLOAT,
		[2] = vk.Format.R32G32_SFLOAT,
		[3] = vk.Format.R32G32B32_SFLOAT,
		[4] = vk.Format.R32G32B32A32_SFLOAT,
	},
	f16 = {
		[1] = vk.Format.R16_SFLOAT,
		[2] = vk.Format.R16G16_SFLOAT,
		[3] = vk.Format.R16G16B16_SFLOAT,
		[4] = vk.Format.R16G16B16A16_SFLOAT,
	},
	i32 = {
		[1] = vk.Format.R32_SINT,
		[2] = vk.Format.R32G32_SINT,
		[3] = vk.Format.R32G32B32_SINT,
		[4] = vk.Format.R32G32B32A32_SINT,
	},
	u32 = {
		[1] = vk.Format.R32_UINT,
		[2] = vk.Format.R32G32_UINT,
		[3] = vk.Format.R32G32B32_UINT,
		[4] = vk.Format.R32G32B32A32_UINT,
	},
	i16 = {
		[1] = vk.Format.R16_SINT,
		[2] = vk.Format.R16G16_SINT,
		[3] = vk.Format.R16G16B16_SINT,
		[4] = vk.Format.R16G16B16A16_SINT,
	},
	u16 = {
		[1] = vk.Format.R16_UINT,
		[2] = vk.Format.R16G16_UINT,
		[3] = vk.Format.R16G16B16_UINT,
		[4] = vk.Format.R16G16B16A16_UINT,
	},
	i8 = {
		[1] = vk.Format.R8_SINT,
		[2] = vk.Format.R8G8_SINT,
		[4] = vk.Format.R8G8B8A8_SINT,
	},
	u8 = {
		[1] = vk.Format.R8_UINT,
		[2] = vk.Format.R8G8_UINT,
		[4] = vk.Format.R8G8B8A8_UINT,
	},
}

--- The same formats with `normalized = true`, where the hardware scales each
--- component into a float for the shader. Only integer types have anything to
--- normalize: a float attribute is already a float.
---@type table<string, vk.Format[]>
local normalizedFormatMap = {
	i16 = {
		[1] = vk.Format.R16_SNORM,
		[2] = vk.Format.R16G16_SNORM,
		[3] = vk.Format.R16G16B16_SNORM,
		[4] = vk.Format.R16G16B16A16_SNORM,
	},
	u16 = {
		[1] = vk.Format.R16_UNORM,
		[2] = vk.Format.R16G16_UNORM,
		[3] = vk.Format.R16G16B16_UNORM,
		[4] = vk.Format.R16G16B16A16_UNORM,
	},
	i8 = {
		[1] = vk.Format.R8_SNORM,
		[2] = vk.Format.R8G8_SNORM,
		[4] = vk.Format.R8G8B8A8_SNORM,
	},
	u8 = {
		[1] = vk.Format.R8_UNORM,
		[2] = vk.Format.R8G8_UNORM,
		[4] = vk.Format.R8G8B8A8_UNORM,
	},
}

--- The format one attribute's bytes are read as, or nil when nothing matches.
---@param attr hood.VertexLayout.Attribute
---@return vk.Format? format
local function attributeFormat(attr)
	local map = attr.normalized and normalizedFormatMap[attr.type] or attributeFormatMap[attr.type]
	return map and map[attr.size] or nil
end

---@class hood-vk.Pipeline
---@field handle vk.ffi.Pipeline
---@field layout vk.ffi.PipelineLayout
---@field renderPass vk.ffi.RenderPass
---@field descriptor hood.PipelineDescriptor
---@field private device hood-vk.Device
local VKPipeline = {}
VKPipeline.__index = VKPipeline

---@param device hood-vk.Device
---@param descriptor hood.PipelineDescriptor
---@return hood-vk.Pipeline
function VKPipeline.new(device, descriptor)
	if descriptor.fragment.module.type ~= "spirv" or descriptor.vertex.module.type ~= "spirv" then
		error("Only SPIR-V shaders are supported in the Vulkan backend.")
	end

	local vertModule = device.handle:createShaderModule({
		codeSize = #descriptor.vertex.module.source,
		pCode = ffi.cast("const uint32_t*", descriptor.vertex.module.source),
	})

	local fragModule = device.handle:createShaderModule({
		codeSize = #descriptor.fragment.module.source,
		pCode = ffi.cast("const uint32_t*", descriptor.fragment.module.source),
	})

	local buffers = descriptor.vertex.buffers or {}
	---@type vk.VertexInputBindingDescription[]
	local bindings = {}
	---@type vk.VertexInputAttributeDescription[]
	local attributes = {}

	for i, layout in ipairs(buffers) do
		bindings[#bindings + 1] = {
			binding = i - 1,
			stride = layout:getStride(),
			inputRate = layout:isInstanceRate()
				and vk.VertexInputRate.INSTANCE
				or vk.VertexInputRate.VERTEX,
		}

		for _, attr in ipairs(layout.attributes) do
			local fmt = attributeFormat(attr)
			if not fmt then
				error(string.format(
					"Unsupported vertex attribute: type=%s size=%d normalized=%s",
					attr.type, attr.size, tostring(attr.normalized or false)))
			end
			-- Locations run on across every layout in the pipeline, so a second
			-- layout does not start at location 0. An attribute may state its
			-- own location instead, which is what keeps a declaration's order
			-- from having to match the shader's.
			attributes[#attributes + 1] = {
				location = attr.location or #attributes,
				binding = i - 1,
				format = fmt,
				offset = attr.offset,
			}
		end
	end

	local targets = descriptor.fragment.targets or {}
	---@type vk.PipelineColorBlendAttachmentState[]
	local blendAttachments = {}

	for _, target in ipairs(targets) do
		---@type vk.PipelineColorBlendAttachmentState
		local att = {
			colorWriteMask = target.writeMask or 0xF,
		}

		if target.blend == "alpha-blending" then
			att.blendEnable = true
			att.srcColorBlendFactor = vk.BlendFactor.SRC_ALPHA
			att.dstColorBlendFactor = vk.BlendFactor.ONE_MINUS_SRC_ALPHA
			att.colorBlendOp = vk.BlendOp.ADD
			att.srcAlphaBlendFactor = vk.BlendFactor.ONE
			att.dstAlphaBlendFactor = vk.BlendFactor.ONE_MINUS_SRC_ALPHA
			att.alphaBlendOp = vk.BlendOp.ADD
		end

		blendAttachments[#blendAttachments + 1] = att
	end

	---@type vk.PipelineDepthStencilStateCreateInfo?
	local depthStencilState = nil
	if descriptor.depthStencil then
		depthStencilState = {
			depthTestEnable = true,
			depthWriteEnable = descriptor.depthStencil.depthWriteEnabled,
			depthCompareOp = vkConversions.compareFunction[descriptor.depthStencil.depthCompare],
		}
	end

	-- TODO: Support multiple descriptor set layouts when we have bind group support
	local descriptorSetLayouts = vk.DescriptorSetLayoutArray(1)
	do
		local layout = descriptor.layout --[[@as hood-vk.BindGroupLayout]]
		descriptorSetLayouts[0] = layout.handle
	end

	local layout = device.handle:createPipelineLayout({
		setLayoutCount = 1,
		pSetLayouts = descriptorSetLayouts,
	})

	-- The pass the pipeline was made against: the formats it renders to are all it needs, and
	-- a frame rendering into textures of those formats uses the same pass.
	local colorSpecs = {}
	local depthSpec = nil

	for i, target in ipairs(targets) do
		local vkFormat = vkConversions.textureFormat[target.format]

		if not vkFormat then
			error("Unsupported texture format: " .. tostring(target.format))
		end

		if not coreLayout.isDepthFormat(target.format) then
			-- A pipeline is made against formats and cannot know which of them the app goes on
			-- to sample, so it states the sampled case: that is what a colour target is for,
			-- and a frame that renders one it never samples gets a pass of its own.
			colorSpecs[#colorSpecs + 1] = {
				format = vkFormat,
				loadOp = vk.AttachmentLoadOp.CLEAR,
				initialLayout = vk.ImageLayout.UNDEFINED,
				finalLayout = vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL,
				sampled = true,
			}
		end
	end

	if descriptor.depthStencil then
		local depthFormat = vkConversions.textureFormat[descriptor.depthStencil.format]

		if not depthFormat then
			error("Unsupported depth format: " .. tostring(descriptor.depthStencil.format))
		end

		depthSpec = {
			format = depthFormat,
			loadOp = vk.AttachmentLoadOp.CLEAR,
			initialLayout = vk.ImageLayout.UNDEFINED,
			finalLayout = vk.ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
			sampled = false,
		}
	end

	local renderPass = pass.define(device, colorSpecs, depthSpec)

	local frontFace, cullMode = vk.FrontFace.COUNTER_CLOCKWISE, vk.CullModeFlagBits.NONE
	if descriptor.primitive then
		if descriptor.primitive.frontFace then
			frontFace = vkConversions.frontFace[descriptor.primitive.frontFace]
		end

		if descriptor.primitive.cullMode then
			cullMode = vkConversions.cullMode[descriptor.primitive.cullMode]
		end
	end

	local pipelines = device.handle:createGraphicsPipelines(0, {
		{
			stages = {
				{ stage = vk.ShaderStageFlagBits.VERTEX,   module = vertModule },
				{ stage = vk.ShaderStageFlagBits.FRAGMENT, module = fragModule },
			},
			vertexInputState = {
				bindings = bindings,
				attributes = attributes,
			},
			inputAssemblyState = {
				topology = vk.PrimitiveTopology.TRIANGLE_LIST,
			},
			viewportState = {
				viewportCount = 1,
				scissorCount = 1,
			},
			rasterizationState = {
				polygonMode = vk.PolygonMode.FILL,
				cullMode = cullMode,
				frontFace = frontFace,
				lineWidth = 1.0,
			},
			multisampleState = {
				rasterizationSamples = vk.SampleCountFlagBits.COUNT_1,
			},
			depthStencilState = depthStencilState,
			colorBlendState = {
				attachments = blendAttachments,
			},
			dynamicState = {
				dynamicStates = { vk.DynamicState.VIEWPORT, vk.DynamicState.SCISSOR },
			},
			layout = layout,
			renderPass = renderPass,
			subpass = 0,
		},
	})

	-- TODO: Make this automatic via shaderModule gc
	device.handle:destroyShaderModule(vertModule)
	device.handle:destroyShaderModule(fragModule)

	return setmetatable({
		device = device,
		handle = pipelines[1],
		layout = layout,
		renderPass = renderPass,
		descriptor = descriptor,
	}, VKPipeline)
end

--- The render pass is not this pipeline's to free: it belongs to the device's cache and other
--- pipelines and frames made against the same formats are still using it.
function VKPipeline:destroy()
	self.device.handle:destroyPipeline(self.handle)
	self.device.handle:destroyPipelineLayout(self.layout)
end

return VKPipeline
