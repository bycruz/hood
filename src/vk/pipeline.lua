local ffi = require("ffi")

local vk = require("vkapi")
local vkConversions = require("hood.convert.vk")

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

---@param format hood.TextureFormat
local function isDepthFormat(format)
	return format == "depth16unorm"
		or format == "depth24plus"
		or format == "depth32float"
end

---@class hood.vk.Pipeline
---@field handle vk.ffi.Pipeline
---@field layout vk.ffi.PipelineLayout
---@field renderPass vk.ffi.RenderPass
---@field descriptor hood.PipelineDescriptor
---@field private device hood.vk.Device
local VKPipeline = {}
VKPipeline.__index = VKPipeline

---@param device hood.vk.Device
---@param descriptor hood.PipelineDescriptor
---@return hood.vk.Pipeline
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
		local layout = descriptor.layout --[[@as hood.vk.BindGroupLayout]]
		descriptorSetLayouts[0] = layout.handle
	end

	local layout = device.handle:createPipelineLayout({
		setLayoutCount = 1,
		pSetLayouts = descriptorSetLayouts,
	})

	---@type vk.AttachmentDescription[]
	local attachmentDescs = {}
	---@type vk.AttachmentReference[]
	local colorRefs = {}

	for _, target in ipairs(targets) do
		local vkFormat = vkConversions.textureFormat[target.format]
		if not vkFormat then
			error("Unsupported texture format: " .. tostring(target.format))
		end
		if not isDepthFormat(target.format) then
			attachmentDescs[#attachmentDescs + 1] = {
				format = vkFormat,
				samples = vk.SampleCountFlagBits.COUNT_1,
				loadOp = vk.AttachmentLoadOp.CLEAR,
				storeOp = vk.AttachmentStoreOp.STORE,
				stencilLoadOp = vk.AttachmentLoadOp.DONT_CARE,
				stencilStoreOp = vk.AttachmentStoreOp.DONT_CARE,
				initialLayout = vk.ImageLayout.UNDEFINED,
				finalLayout = vk.ImageLayout.PRESENT_SRC_KHR,
			}
			colorRefs[#colorRefs + 1] = {
				attachment = #attachmentDescs - 1,
				layout = vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL,
			}
		end
	end

	---@type vk.AttachmentReference?
	local depthRef = nil
	if descriptor.depthStencil then
		local vkFormat = vkConversions.textureFormat[descriptor.depthStencil.format]
		if not vkFormat then
			error("Unsupported depth format: " .. tostring(descriptor.depthStencil.format))
		end
		attachmentDescs[#attachmentDescs + 1] = {
			format = vkFormat,
			samples = vk.SampleCountFlagBits.COUNT_1,
			loadOp = vk.AttachmentLoadOp.CLEAR,
			storeOp = vk.AttachmentStoreOp.STORE,
			stencilLoadOp = vk.AttachmentLoadOp.DONT_CARE,
			stencilStoreOp = vk.AttachmentStoreOp.DONT_CARE,
			initialLayout = vk.ImageLayout.UNDEFINED,
			finalLayout = vk.ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		}
		depthRef = {
			attachment = #attachmentDescs - 1,
			layout = vk.ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		}
	end

	local depthStageMask = 0
	local depthAccessMask = 0
	if descriptor.depthStencil then
		depthStageMask = bit.bor(vk.PipelineStageFlagBits.EARLY_FRAGMENT_TESTS,
			vk.PipelineStageFlagBits.LATE_FRAGMENT_TESTS)
		depthAccessMask = bit.bor(vk.AccessFlags.DEPTH_STENCIL_ATTACHMENT_READ,
			vk.AccessFlags.DEPTH_STENCIL_ATTACHMENT_WRITE)
	end

	local renderPass = device.handle:createRenderPass({
		attachments = attachmentDescs,
		subpasses = {
			{
				pipelineBindPoint = vk.PipelineBindPoint.GRAPHICS,
				colorAttachments = colorRefs,
				depthStencilAttachment = depthRef,
			},
		},
		dependencies = {
			{
				srcSubpass = vk.SUBPASS_EXTERNAL,
				dstSubpass = 0,
				srcStageMask = bit.bor(vk.PipelineStageFlagBits.COLOR_ATTACHMENT_OUTPUT, depthStageMask),
				dstStageMask = bit.bor(vk.PipelineStageFlagBits.COLOR_ATTACHMENT_OUTPUT, depthStageMask),
				dstAccessMask = bit.bor(vk.AccessFlags.COLOR_ATTACHMENT_WRITE, depthAccessMask),
			},
		},
	})

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

function VKPipeline:destroy()
	self.device.handle:destroyPipeline(self.handle)
	self.device.handle:destroyPipelineLayout(self.layout)
	self.device.handle:destroyRenderPass(self.renderPass)
end

return VKPipeline
