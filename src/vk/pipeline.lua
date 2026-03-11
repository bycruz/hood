local ffi = require("ffi")

local vk = require("vkapi")
local vkConversions = require("hood.convert.vk")

---@type table<string, vk.Format[]>
local attributeFormatMap = {
	f32 = {
		[1] = vk.Format.R32_SFLOAT,
		[2] = vk.Format.R32G32_SFLOAT,
		[3] = vk.Format.R32G32B32_SFLOAT,
		[4] = vk.Format.R32G32B32A32_SFLOAT,
	},
	i32 = {
		[1] = vk.Format.R32_SINT,
		[2] = vk.Format.R32G32_SINT,
		[3] = vk.Format.R32G32B32_SINT,
		[4] = vk.Format.R32G32B32A32_SINT,
	},
}

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
			inputRate = vk.VertexInputRate.VERTEX,
		}

		for _, attr in ipairs(layout.attributes) do
			local fmt = attributeFormatMap[attr.type] and attributeFormatMap[attr.type][attr.size]
			if not fmt then
				error("Unsupported vertex attribute: type=" .. attr.type .. " size=" .. attr.size)
			end
			attributes[#attributes + 1] = {
				location = #attributes,
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
		--- Flip it since we invert Y viewport
		---@type table<vk.FrontFace, vk.FrontFace>
		local inverse = {
			[vk.FrontFace.CLOCKWISE] = vk.FrontFace.COUNTER_CLOCKWISE,
			[vk.FrontFace.COUNTER_CLOCKWISE] = vk.FrontFace.CLOCKWISE
		}

		if descriptor.primitive.frontFace then
			frontFace = inverse[vkConversions.frontFace[descriptor.primitive.frontFace]]
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
		handle = pipelines[1],
		layout = layout,
		renderPass = renderPass,
		descriptor = descriptor,
	}, VKPipeline)
end

return VKPipeline
