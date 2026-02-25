local ffi = require("ffi")

---@param vk vk
return function(vk)
	---@class vk.Device
	---@field handle vk.ffi.Device
	---@field v1_0 vk.Device.Fns
	local VKDevice = {}
	VKDevice.__index = VKDevice

	---@param info vk.ffi.BufferCreateInfo
	---@param allocator ffi.cdata*?
	---@return vk.ffi.Buffer
	function VKDevice:createBuffer(info, allocator)
		local createInfo = vk.BufferCreateInfo(info)
		local buffer = ffi.new("VkBuffer[1]")
		local result = self.v1_0.vkCreateBuffer(self.handle, createInfo, allocator, buffer)
		if result ~= 0 then
			error("Failed to create Vulkan buffer, error code: " .. tostring(result))
		end
		return buffer[0]
	end

	---@param buffer vk.ffi.Buffer
	---@param allocator ffi.cdata*?
	function VKDevice:destroyBuffer(buffer, allocator)
		self.v1_0.vkDestroyBuffer(self.handle, buffer, allocator)
	end

	---@param info vk.ffi.ShaderModuleCreateInfo
	---@param allocator ffi.cdata*?
	---@return vk.ffi.ShaderModule
	function VKDevice:createShaderModule(info, allocator)
		local createInfo = vk.ShaderModuleCreateInfo(info)
		local shaderModule = ffi.new("VkShaderModule[1]")
		local result = self.v1_0.vkCreateShaderModule(self.handle, createInfo, allocator, shaderModule)
		if result ~= 0 then
			error("Failed to create Vulkan shader module, error code: " .. tostring(result))
		end
		return shaderModule[0]
	end

	---@class vk.PushConstantRange
	---@field stageFlags vk.ShaderStageFlagBits
	---@field offset number
	---@field size number

	---@class vk.PipelineLayoutCreateInfo
	---@field descriptorSetLayouts vk.ffi.DescriptorSetLayout[]?
	---@field pushConstantRanges vk.PushConstantRange[]?

	---@param info vk.PipelineLayoutCreateInfo
	---@return ffi.cdata* VkPipelineLayoutCreateInfo
	local function pipelineLayoutCreateInfoToFFI(info)
		local createInfo = vk.PipelineLayoutCreateInfo()

		local layouts = info.descriptorSetLayouts
		if layouts and #layouts > 0 then
			local layoutArray = ffi.new("VkDescriptorSetLayout[?]", #layouts)
			for i, l in ipairs(layouts) do
				layoutArray[i - 1] = l
			end
			createInfo.setLayoutCount = #layouts
			createInfo.pSetLayouts = layoutArray
		end

		local ranges = info.pushConstantRanges
		if ranges and #ranges > 0 then
			local rangeArray = vk.PushConstantRangeArray(#ranges)
			for i, r in ipairs(ranges) do
				rangeArray[i - 1].stageFlags = r.stageFlags
				rangeArray[i - 1].offset = r.offset
				rangeArray[i - 1].size = r.size
			end
			createInfo.pushConstantRangeCount = #ranges
			createInfo.pPushConstantRanges = rangeArray
		end

		return createInfo
	end

	---@param info vk.PipelineLayoutCreateInfo
	---@param allocator ffi.cdata*?
	---@return vk.ffi.PipelineLayout
	function VKDevice:createPipelineLayout(info, allocator)
		local createInfo = pipelineLayoutCreateInfoToFFI(info)
		local pipelineLayout = ffi.new("VkPipelineLayout[1]")
		local result = self.v1_0.vkCreatePipelineLayout(self.handle, createInfo, allocator, pipelineLayout)
		if result ~= 0 then
			error("Failed to create Vulkan pipeline layout, error code: " .. tostring(result))
		end
		return pipelineLayout[0]
	end

	---@class vk.PipelineShaderStageCreateInfo
	---@field stage vk.ShaderStageFlagBits
	---@field module vk.ffi.ShaderModule
	---@field name string?

	---@class vk.ComputePipelineCreateInfo
	---@field stage vk.PipelineShaderStageCreateInfo
	---@field layout vk.ffi.PipelineLayout

	---@class vk.VertexInputBindingDescription
	---@field binding number
	---@field stride number
	---@field inputRate vk.VertexInputRate

	---@class vk.VertexInputAttributeDescription
	---@field location number
	---@field binding number
	---@field format vk.Format
	---@field offset number

	---@class vk.PipelineVertexInputStateCreateInfo
	---@field bindings vk.VertexInputBindingDescription[]?
	---@field attributes vk.VertexInputAttributeDescription[]?

	---@class vk.PipelineInputAssemblyStateCreateInfo
	---@field topology vk.PrimitiveTopology
	---@field primitiveRestartEnable boolean?

	---@class vk.PipelineViewportStateCreateInfo
	---@field viewportCount number?
	---@field scissorCount number?

	---@class vk.PipelineRasterizationStateCreateInfo
	---@field depthClampEnable boolean?
	---@field rasterizerDiscardEnable boolean?
	---@field polygonMode vk.PolygonMode
	---@field cullMode vk.CullModeFlags
	---@field frontFace vk.FrontFace
	---@field depthBiasEnable boolean?
	---@field depthBiasConstantFactor number?
	---@field depthBiasClamp number?
	---@field depthBiasSlopeFactor number?
	---@field lineWidth number

	---@class vk.PipelineMultisampleStateCreateInfo
	---@field rasterizationSamples vk.SampleCountFlagBits
	---@field sampleShadingEnable boolean?
	---@field minSampleShading number?

	---@class vk.PipelineDepthStencilStateCreateInfo
	---@field depthTestEnable boolean?
	---@field depthWriteEnable boolean?
	---@field depthCompareOp vk.CompareOp?

	---@class vk.PipelineColorBlendAttachmentState
	---@field blendEnable boolean?
	---@field srcColorBlendFactor vk.BlendFactor?
	---@field dstColorBlendFactor vk.BlendFactor?
	---@field colorBlendOp vk.BlendOp?
	---@field srcAlphaBlendFactor vk.BlendFactor?
	---@field dstAlphaBlendFactor vk.BlendFactor?
	---@field alphaBlendOp vk.BlendOp?
	---@field colorWriteMask vk.ColorComponentFlags?

	---@class vk.PipelineColorBlendStateCreateInfo
	---@field logicOpEnable boolean?
	---@field logicOp vk.LogicOp?
	---@field attachments vk.PipelineColorBlendAttachmentState[]?

	---@class vk.PipelineDynamicStateCreateInfo
	---@field dynamicStates vk.DynamicState[]

	---@class vk.GraphicsPipelineCreateInfo
	---@field stages vk.PipelineShaderStageCreateInfo[]
	---@field vertexInputState vk.PipelineVertexInputStateCreateInfo?
	---@field inputAssemblyState vk.PipelineInputAssemblyStateCreateInfo?
	---@field viewportState vk.PipelineViewportStateCreateInfo?
	---@field rasterizationState vk.PipelineRasterizationStateCreateInfo?
	---@field multisampleState vk.PipelineMultisampleStateCreateInfo?
	---@field depthStencilState vk.PipelineDepthStencilStateCreateInfo?
	---@field colorBlendState vk.PipelineColorBlendStateCreateInfo?
	---@field dynamicState vk.PipelineDynamicStateCreateInfo?
	---@field layout vk.ffi.PipelineLayout
	---@field renderPass vk.ffi.RenderPass
	---@field subpass number?

	---@param pipelineCache vk.ffi.PipelineCache?
	---@param infos vk.GraphicsPipelineCreateInfo[]
	---@param allocator ffi.cdata*?
	---@return vk.ffi.Pipeline[]
	function VKDevice:createGraphicsPipelines(pipelineCache, infos, allocator)
		local count = #infos
		local infoArray = vk.GraphicsPipelineCreateInfoArray(count)

		for i = 1, count do
			local info = infos[i]

			local stageCount = #info.stages
			local stages = vk.PipelineShaderStageCreateInfoArray(stageCount)
			for j, stage in ipairs(info.stages) do
				stages[j - 1].stage = stage.stage
				stages[j - 1].module = stage.module
				stages[j - 1].pName = stage.name or "main"
			end

			---@type vk.ffi.PipelineVertexInputStateCreateInfo?
			local vertexInputState = nil
			if info.vertexInputState then
				local bindings = info.vertexInputState.bindings or {}
				local attributes = info.vertexInputState.attributes or {}

				local bindingArray = vk.VertexInputBindingDescriptionArray(math.max(#bindings, 1))
				for j, b in ipairs(bindings) do
					bindingArray[j - 1].binding = b.binding
					bindingArray[j - 1].stride = b.stride
					bindingArray[j - 1].inputRate = b.inputRate
				end

				local attrArray = vk.VertexInputAttributeDescriptionArray(math.max(#attributes, 1))
				for j, a in ipairs(attributes) do
					attrArray[j - 1].location = a.location
					attrArray[j - 1].binding = a.binding
					attrArray[j - 1].format = a.format
					attrArray[j - 1].offset = a.offset
				end

				vertexInputState = vk.PipelineVertexInputStateCreateInfo({
					vertexBindingDescriptionCount = #bindings,
					pVertexBindingDescriptions = bindingArray,
					vertexAttributeDescriptionCount = #attributes,
					pVertexAttributeDescriptions = attrArray,
				})
			end

			---@type vk.ffi.PipelineInputAssemblyStateCreateInfo?
			local inputAssemblyState = nil
			if info.inputAssemblyState then
				inputAssemblyState = vk.PipelineInputAssemblyStateCreateInfo({
					topology = info.inputAssemblyState.topology,
					primitiveRestartEnable = info.inputAssemblyState.primitiveRestartEnable and 1 or 0,
				})
			end

			---@type vk.ffi.PipelineViewportStateCreateInfo?
			local viewportState = nil
			if info.viewportState then
				viewportState = vk.PipelineViewportStateCreateInfo({
					viewportCount = info.viewportState.viewportCount or 1,
					scissorCount = info.viewportState.scissorCount or 1,
				})
			end

			---@type vk.ffi.PipelineRasterizationStateCreateInfo?
			local rasterizationState = nil
			if info.rasterizationState then
				local rs = info.rasterizationState ---@cast rs -nil
				rasterizationState = vk.PipelineRasterizationStateCreateInfo({
					depthClampEnable = rs.depthClampEnable and 1 or 0,
					rasterizerDiscardEnable = rs.rasterizerDiscardEnable and 1 or 0,
					polygonMode = rs.polygonMode,
					cullMode = rs.cullMode,
					frontFace = rs.frontFace,
					depthBiasEnable = rs.depthBiasEnable and 1 or 0,
					depthBiasConstantFactor = rs.depthBiasConstantFactor or 0,
					depthBiasClamp = rs.depthBiasClamp or 0,
					depthBiasSlopeFactor = rs.depthBiasSlopeFactor or 0,
					lineWidth = rs.lineWidth,
				})
			end

			---@type vk.ffi.PipelineMultisampleStateCreateInfo?
			local multisampleState = nil
			if info.multisampleState then
				multisampleState = vk.PipelineMultisampleStateCreateInfo({
					rasterizationSamples = info.multisampleState.rasterizationSamples,
					sampleShadingEnable = info.multisampleState.sampleShadingEnable and 1 or 0,
					minSampleShading = info.multisampleState.minSampleShading or 0,
				})
			end

			---@type vk.ffi.PipelineDepthStencilStateCreateInfo?
			local depthStencilState = nil
			if info.depthStencilState then
				local ds = info.depthStencilState ---@cast ds -nil
				depthStencilState = vk.PipelineDepthStencilStateCreateInfo({
					depthTestEnable = ds.depthTestEnable and 1 or 0,
					depthWriteEnable = ds.depthWriteEnable and 1 or 0,
					depthCompareOp = ds.depthCompareOp or 0,
				})
			end

			---@type vk.ffi.PipelineColorBlendStateCreateInfo?
			local colorBlendState = nil
			if info.colorBlendState then
				local cb = info.colorBlendState ---@cast cb -nil
				local attachments = cb.attachments or {}
				local attachmentArray = vk.PipelineColorBlendAttachmentStateArray(math.max(#attachments, 1))
				for j, att in ipairs(attachments) do
					attachmentArray[j - 1].blendEnable = att.blendEnable and 1 or 0
					attachmentArray[j - 1].srcColorBlendFactor = att.srcColorBlendFactor or 0
					attachmentArray[j - 1].dstColorBlendFactor = att.dstColorBlendFactor or 0
					attachmentArray[j - 1].colorBlendOp = att.colorBlendOp or 0
					attachmentArray[j - 1].srcAlphaBlendFactor = att.srcAlphaBlendFactor or 0
					attachmentArray[j - 1].dstAlphaBlendFactor = att.dstAlphaBlendFactor or 0
					attachmentArray[j - 1].alphaBlendOp = att.alphaBlendOp or 0
					attachmentArray[j - 1].colorWriteMask = att.colorWriteMask or 0xF
				end

				colorBlendState = vk.PipelineColorBlendStateCreateInfo({
					logicOpEnable = cb.logicOpEnable and 1 or 0,
					logicOp = cb.logicOp or 0,
					attachmentCount = #attachments,
					pAttachments = attachmentArray,
				})
			end

			---@type vk.ffi.PipelineDynamicStateCreateInfo?
			local dynamicState = nil
			if info.dynamicState then
				local ds = info.dynamicState.dynamicStates
				local stateArray = ffi.new("int32_t[?]", #ds, ds)
				dynamicState = vk.PipelineDynamicStateCreateInfo({
					dynamicStateCount = #ds,
					pDynamicStates = stateArray,
				})
			end

			infoArray[i - 1].stageCount = stageCount
			infoArray[i - 1].pStages = stages
			infoArray[i - 1].pVertexInputState = vertexInputState
			infoArray[i - 1].pInputAssemblyState = inputAssemblyState
			infoArray[i - 1].pViewportState = viewportState
			infoArray[i - 1].pRasterizationState = rasterizationState
			infoArray[i - 1].pMultisampleState = multisampleState
			infoArray[i - 1].pDepthStencilState = depthStencilState
			infoArray[i - 1].pColorBlendState = colorBlendState
			infoArray[i - 1].pDynamicState = dynamicState
			infoArray[i - 1].layout = info.layout
			infoArray[i - 1].renderPass = info.renderPass
			infoArray[i - 1].subpass = info.subpass or 0
		end

		local pipelines = ffi.new("VkPipeline[?]", count)
		local result = self.v1_0.vkCreateGraphicsPipelines(self.handle, pipelineCache or vk.NULL, count, infoArray,
			allocator,
			pipelines)
		if result ~= 0 then
			error("Failed to create Vulkan graphics pipelines, error code: " .. tostring(result))
		end

		local pipelineList = {}
		for i = 0, count - 1 do
			pipelineList[i + 1] = pipelines[i]
		end
		return pipelineList
	end

	---@param pipelineCache vk.ffi.PipelineCache?
	---@param info vk.ComputePipelineCreateInfo
	---@param allocator ffi.cdata*?
	---@return vk.ffi.Pipeline
	function VKDevice:createComputePipeline(pipelineCache, info, allocator)
		local createInfo = vk.ComputePipelineCreateInfo()
		createInfo.stage.stage = info.stage.stage
		createInfo.stage.module = info.stage.module
		createInfo.stage.pName = info.stage.name or "main"
		createInfo.layout = info.layout

		local pipeline = ffi.new("VkPipeline[1]")
		local result = self.v1_0.vkCreateComputePipelines(self.handle, pipelineCache or vk.NULL, 1, createInfo, allocator,
			pipeline)
		if result ~= 0 then
			error("Failed to create Vulkan compute pipeline, error code: " .. tostring(result))
		end
		return pipeline[0]
	end

	---@class vk.AttachmentDescription
	---@field format vk.Format
	---@field samples vk.SampleCountFlagBits?
	---@field loadOp vk.AttachmentLoadOp
	---@field storeOp vk.AttachmentStoreOp
	---@field stencilLoadOp vk.AttachmentLoadOp?
	---@field stencilStoreOp vk.AttachmentStoreOp?
	---@field initialLayout vk.ImageLayout
	---@field finalLayout vk.ImageLayout

	---@class vk.AttachmentReference
	---@field attachment number
	---@field layout vk.ImageLayout

	---@class vk.SubpassDescription
	---@field pipelineBindPoint vk.PipelineBindPoint
	---@field inputAttachments vk.AttachmentReference[]?
	---@field colorAttachments vk.AttachmentReference[]?
	---@field resolveAttachments vk.AttachmentReference[]?
	---@field depthStencilAttachment vk.AttachmentReference?
	---@field preserveAttachments number[]?

	---@class vk.SubpassDependency
	---@field srcSubpass number
	---@field dstSubpass number
	---@field srcStageMask vk.PipelineStageFlags
	---@field dstStageMask vk.PipelineStageFlags
	---@field srcAccessMask vk.AccessFlags?
	---@field dstAccessMask vk.AccessFlags?
	---@field dependencyFlags number?

	---@class vk.RenderPassCreateInfo
	---@field attachments vk.AttachmentDescription[]?
	---@field subpasses vk.SubpassDescription[]
	---@field dependencies vk.SubpassDependency[]?

	---@param info vk.RenderPassCreateInfo
	---@param allocator ffi.cdata*?
	---@return vk.ffi.RenderPass
	function VKDevice:createRenderPass(info, allocator)
		local attachments = info.attachments or {}
		local subpasses = info.subpasses
		local dependencies = info.dependencies or {}

		local attachmentArray = vk.AttachmentDescriptionArray(math.max(#attachments, 1))
		for i, att in ipairs(attachments) do
			attachmentArray[i - 1].format = att.format
			attachmentArray[i - 1].samples = att.samples or 1
			attachmentArray[i - 1].loadOp = att.loadOp
			attachmentArray[i - 1].storeOp = att.storeOp
			attachmentArray[i - 1].stencilLoadOp = att.stencilLoadOp or 0
			attachmentArray[i - 1].stencilStoreOp = att.stencilStoreOp or 0
			attachmentArray[i - 1].initialLayout = att.initialLayout
			attachmentArray[i - 1].finalLayout = att.finalLayout
		end

		local subpassArray = vk.SubpassDescriptionArray(#subpasses)
		local refArrays = {}
		for i, sub in ipairs(subpasses) do
			subpassArray[i - 1].pipelineBindPoint = sub.pipelineBindPoint

			local colorAtts = sub.colorAttachments or {}
			if #colorAtts > 0 then
				local colorRefArray = vk.AttachmentReferenceArray(#colorAtts)
				for j, ref in ipairs(colorAtts) do
					colorRefArray[j - 1].attachment = ref.attachment
					colorRefArray[j - 1].layout = ref.layout
				end
				subpassArray[i - 1].colorAttachmentCount = #colorAtts
				subpassArray[i - 1].pColorAttachments = colorRefArray
				refArrays[#refArrays + 1] = colorRefArray
			end

			local inputAtts = sub.inputAttachments or {}
			if #inputAtts > 0 then
				local inputRefArray = vk.AttachmentReferenceArray(#inputAtts)
				for j, ref in ipairs(inputAtts) do
					inputRefArray[j - 1].attachment = ref.attachment
					inputRefArray[j - 1].layout = ref.layout
				end
				subpassArray[i - 1].inputAttachmentCount = #inputAtts
				subpassArray[i - 1].pInputAttachments = inputRefArray
				refArrays[#refArrays + 1] = inputRefArray
			end

			local resolveAtts = sub.resolveAttachments or {}
			if #resolveAtts > 0 then
				local resolveRefArray = vk.AttachmentReferenceArray(#resolveAtts)
				for j, ref in ipairs(resolveAtts) do
					resolveRefArray[j - 1].attachment = ref.attachment
					resolveRefArray[j - 1].layout = ref.layout
				end
				subpassArray[i - 1].pResolveAttachments = resolveRefArray
				refArrays[#refArrays + 1] = resolveRefArray
			end

			if sub.depthStencilAttachment then
				local depthRef = vk.AttachmentReference()
				depthRef.attachment = sub.depthStencilAttachment.attachment
				depthRef.layout = sub.depthStencilAttachment.layout
				subpassArray[i - 1].pDepthStencilAttachment = depthRef
				refArrays[#refArrays + 1] = depthRef
			end

			local preserveAtts = sub.preserveAttachments or {}
			if #preserveAtts > 0 then
				local preserveArray = ffi.new("uint32_t[?]", #preserveAtts, preserveAtts)
				subpassArray[i - 1].preserveAttachmentCount = #preserveAtts
				subpassArray[i - 1].pPreserveAttachments = preserveArray
				refArrays[#refArrays + 1] = preserveArray
			end
		end

		local dependencyArray = vk.SubpassDependencyArray(math.max(#dependencies, 1))
		for i, dep in ipairs(dependencies) do
			dependencyArray[i - 1].srcSubpass = dep.srcSubpass
			dependencyArray[i - 1].dstSubpass = dep.dstSubpass
			dependencyArray[i - 1].srcStageMask = dep.srcStageMask
			dependencyArray[i - 1].dstStageMask = dep.dstStageMask
			dependencyArray[i - 1].srcAccessMask = dep.srcAccessMask or 0
			dependencyArray[i - 1].dstAccessMask = dep.dstAccessMask or 0
			dependencyArray[i - 1].dependencyFlags = dep.dependencyFlags or 0
		end

		local createInfo = vk.RenderPassCreateInfo({
			attachmentCount = #attachments,
			pAttachments = attachmentArray,
			subpassCount = #subpasses,
			pSubpasses = subpassArray,
			dependencyCount = #dependencies,
			pDependencies = dependencyArray,
		})

		local renderPass = ffi.new("VkRenderPass[1]")
		local result = self.v1_0.vkCreateRenderPass(self.handle, createInfo, allocator, renderPass)
		if result ~= 0 then
			error("Failed to create Vulkan render pass, error code: " .. tostring(result))
		end
		return renderPass[0]
	end

	---@param info vk.ffi.ImageViewCreateInfo
	---@param allocator ffi.cdata*?
	---@return vk.ffi.ImageView
	function VKDevice:createImageView(info, allocator)
		local createInfo = vk.ImageViewCreateInfo(info)
		local imageView = ffi.new("VkImageView[1]")
		local result = self.v1_0.vkCreateImageView(self.handle, createInfo, allocator, imageView)
		if result ~= 0 then
			error("Failed to create Vulkan image view, error code: " .. tostring(result))
		end
		return imageView[0]
	end

	---@param info vk.ffi.FramebufferCreateInfo
	---@param allocator ffi.cdata*?
	---@return vk.ffi.Framebuffer
	function VKDevice:createFramebuffer(info, allocator)
		local createInfo = vk.FramebufferCreateInfo(info)
		local framebuffer = ffi.new("VkFramebuffer[1]")
		local result = self.v1_0.vkCreateFramebuffer(self.handle, createInfo, allocator, framebuffer)
		if result ~= 0 then
			error("Failed to create Vulkan framebuffer, error code: " .. tostring(result))
		end
		return framebuffer[0]
	end

	---@param info vk.ffi.CommandPoolCreateInfo
	---@param allocator ffi.cdata*?
	---@return vk.ffi.CommandPool
	function VKDevice:createCommandPool(info, allocator)
		local createInfo = vk.CommandPoolCreateInfo(info)
		local commandPool = ffi.new("VkCommandPool[1]")
		local result = self.v1_0.vkCreateCommandPool(self.handle, createInfo, allocator, commandPool)
		if result ~= 0 then
			error("Failed to create Vulkan command pool, error code: " .. tostring(result))
		end
		return commandPool[0]
	end

	---@param buffer vk.ffi.Buffer
	---@return vk.ffi.MemoryRequirements
	function VKDevice:getBufferMemoryRequirements(buffer)
		local memRequirements = vk.MemoryRequirements()
		self.v1_0.vkGetBufferMemoryRequirements(self.handle, buffer, memRequirements)
		return memRequirements
	end

	---@param image vk.ffi.Image
	---@return vk.ffi.MemoryRequirements
	function VKDevice:getImageMemoryRequirements(image)
		local memRequirements = vk.MemoryRequirements()
		self.v1_0.vkGetImageMemoryRequirements(self.handle, image, memRequirements)
		return memRequirements
	end

	---@param createInfo vk.ffi.CreateImageInfo
	---@param allocator ffi.cdata*?
	---@return vk.ffi.Image
	function VKDevice:createImage(createInfo, allocator)
		local info = vk.ImageCreateInfo(createInfo)
		local image = ffi.new("VkImage[1]")
		local result = self.v1_0.vkCreateImage(self.handle, info, allocator, image)
		if result ~= 0 then
			error("Failed to create Vulkan image, error code: " .. tostring(result))
		end
		return image[0]
	end

	---@param image vk.ffi.Image
	---@param memory vk.ffi.DeviceMemory
	---@param memoryOffset vk.ffi.DeviceSize
	function VKDevice:bindImageMemory(image, memory, memoryOffset)
		local result = self.v1_0.vkBindImageMemory(self.handle, image, memory, memoryOffset)
		if result ~= 0 then
			error("Failed to bind image memory, error code: " .. tostring(result))
		end
	end

	---@param createInfo vk.ffi.SamplerCreateInfo
	---@param allocator ffi.cdata*?
	---@return vk.ffi.Sampler
	function VKDevice:createSampler(createInfo, allocator)
		local info = vk.SamplerCreateInfo(createInfo)
		local sampler = ffi.new("VkSampler[1]")
		local result = self.v1_0.vkCreateSampler(self.handle, info, allocator, sampler)
		if result ~= 0 then
			error("Failed to create Vulkan sampler, error code: " .. tostring(result))
		end
		return sampler[0]
	end

	---@param sampler vk.ffi.Sampler
	---@param allocator ffi.cdata*?
	function VKDevice:destroySampler(sampler, allocator)
		self.v1_0.vkDestroySampler(self.handle, sampler, allocator)
	end

	---@param imageView vk.ffi.ImageView
	---@param allocator ffi.cdata*?
	function VKDevice:destroyImageView(imageView, allocator)
		self.v1_0.vkDestroyImageView(self.handle, imageView, allocator)
	end

	---@param framebuffer vk.ffi.Framebuffer
	---@param allocator ffi.cdata*?
	function VKDevice:destroyFramebuffer(framebuffer, allocator)
		self.v1_0.vkDestroyFramebuffer(self.handle, framebuffer, allocator)
	end

	---@param commandPool vk.ffi.CommandPool
	---@param allocator ffi.cdata*?
	function VKDevice:destroyCommandPool(commandPool, allocator)
		self.v1_0.vkDestroyCommandPool(self.handle, commandPool, allocator)
	end

	---@param shaderModule vk.ffi.ShaderModule
	---@param allocator ffi.cdata*?
	function VKDevice:destroyShaderModule(shaderModule, allocator)
		self.v1_0.vkDestroyShaderModule(self.handle, shaderModule, allocator)
	end

	---@param fence vk.ffi.Fence
	---@param allocator ffi.cdata*?
	function VKDevice:destroyFence(fence, allocator)
		self.v1_0.vkDestroyFence(self.handle, fence, allocator)
	end

	---@param memory vk.ffi.DeviceMemory
	---@param allocator ffi.cdata*?
	function VKDevice:freeMemory(memory, allocator)
		self.v1_0.vkFreeMemory(self.handle, memory, allocator)
	end

	---@param commandPool vk.ffi.CommandPool
	---@param flags number?
	function VKDevice:resetCommandPool(commandPool, flags)
		local result = self.v1_0.vkResetCommandPool(self.handle, commandPool, flags or 0)
		if result ~= 0 then
			error("Failed to reset command pool, error code: " .. tostring(result))
		end
	end

	---@param info vk.ffi.MemoryAllocateInfo
	---@param allocator ffi.cdata*?
	---@return vk.ffi.DeviceMemory
	function VKDevice:allocateMemory(info, allocator)
		local allocInfo = vk.MemoryAllocateInfo(info)
		local memory = ffi.new("VkDeviceMemory[1]")
		local result = self.v1_0.vkAllocateMemory(self.handle, allocInfo, allocator, memory)
		if result ~= 0 then
			error("Failed to allocate Vulkan memory, error code: " .. tostring(result))
		end
		return memory[0]
	end

	---@param buffer vk.ffi.Buffer
	---@param memory vk.ffi.DeviceMemory
	---@param memoryOffset vk.ffi.DeviceSize
	function VKDevice:bindBufferMemory(buffer, memory, memoryOffset)
		local result = self.v1_0.vkBindBufferMemory(self.handle, buffer, memory, memoryOffset)
		if result ~= 0 then
			error("Failed to bind buffer memory, error code: " .. tostring(result))
		end
	end

	---@param memory vk.ffi.DeviceMemory
	---@param offset number
	---@param size number
	---@param flags number?
	---@return ffi.cdata*
	function VKDevice:mapMemory(memory, offset, size, flags)
		local data = ffi.new("void*[1]")
		local result = self.v1_0.vkMapMemory(self.handle, memory, offset, size, flags or 0, data)
		if result ~= 0 then
			error("Failed to map memory, error code: " .. tostring(result))
		end
		return data[0]
	end

	---@param memory vk.ffi.DeviceMemory
	function VKDevice:unmapMemory(memory)
		self.v1_0.vkUnmapMemory(self.handle, memory)
	end

	---@param info vk.ffi.DescriptorSetLayoutCreateInfo
	---@param allocator ffi.cdata*?
	---@return vk.ffi.DescriptorSetLayout
	function VKDevice:createDescriptorSetLayout(info, allocator)
		local createInfo = vk.DescriptorSetLayoutCreateInfo(info)
		local layout = ffi.new("VkDescriptorSetLayout[1]")
		local result = self.v1_0.vkCreateDescriptorSetLayout(self.handle, createInfo, allocator, layout)
		if result ~= 0 then
			error("Failed to create Vulkan descriptor set layout, error code: " .. tostring(result))
		end
		return layout[0]
	end

	---@param info vk.ffi.DescriptorPoolCreateInfo
	---@param allocator ffi.cdata*?
	---@return vk.ffi.DescriptorPool
	function VKDevice:createDescriptorPool(info, allocator)
		local createInfo = vk.DescriptorPoolCreateInfo(info)
		local pool = ffi.new("VkDescriptorPool[1]")
		local result = self.v1_0.vkCreateDescriptorPool(self.handle, createInfo, allocator, pool)
		if result ~= 0 then
			error("Failed to create Vulkan descriptor pool, error code: " .. tostring(result))
		end
		return pool[0]
	end

	---@param info vk.ffi.DescriptorSetAllocateInfo
	---@return vk.ffi.DescriptorSet[]
	function VKDevice:allocateDescriptorSets(info)
		local allocInfo = vk.DescriptorSetAllocateInfo(info)
		local descriptorSets = ffi.new("VkDescriptorSet[?]", allocInfo.descriptorSetCount)
		local result = self.v1_0.vkAllocateDescriptorSets(self.handle, allocInfo, descriptorSets)
		if result ~= 0 then
			error("Failed to allocate Vulkan descriptor sets, error code: " .. tostring(result))
		end
		local sets = {}
		for i = 0, allocInfo.descriptorSetCount - 1 do
			sets[i + 1] = descriptorSets[i]
		end
		return sets
	end

	---@param writes vk.ffi.WriteDescriptorSet[]
	function VKDevice:updateDescriptorSets(writes)
		local count = #writes
		local writeArray = vk.WriteDescriptorSetArray(count)
		for i, write in ipairs(writes) do
			writeArray[i - 1] = vk.WriteDescriptorSet(write)
		end
		self.v1_0.vkUpdateDescriptorSets(self.handle, count, writeArray, 0, nil)
	end

	---@param info vk.ffi.CommandBufferAllocateInfo
	---@return vk.ffi.CommandBuffer[]
	function VKDevice:allocateCommandBuffers(info)
		local allocInfo = vk.CommandBufferAllocateInfo(info)
		local commandBuffers = ffi.new("VkCommandBuffer[?]", allocInfo.commandBufferCount)
		local result = self.v1_0.vkAllocateCommandBuffers(self.handle, allocInfo, commandBuffers)
		if result ~= 0 then
			error("Failed to allocate Vulkan command buffers, error code: " .. tostring(result))
		end
		local commandBufferList = {}
		for i = 0, allocInfo.commandBufferCount - 1 do
			commandBufferList[i + 1] = commandBuffers[i]
		end
		return commandBufferList
	end

	---@param commandBuffer vk.ffi.CommandBuffer
	---@param info vk.ffi.CommandBufferBeginInfo?
	function VKDevice:beginCommandBuffer(commandBuffer, info)
		local beginInfo = vk.CommandBufferBeginInfo(info)
		local result = self.v1_0.vkBeginCommandBuffer(commandBuffer, beginInfo)
		if result ~= 0 then
			error("Failed to begin Vulkan command buffer, error code: " .. tostring(result))
		end
	end

	---@param commandBuffer vk.ffi.CommandBuffer
	function VKDevice:endCommandBuffer(commandBuffer)
		local result = self.v1_0.vkEndCommandBuffer(commandBuffer)
		if result ~= 0 then
			error("Failed to end Vulkan command buffer, error code: " .. tostring(result))
		end
	end

	---@param commandBuffer vk.ffi.CommandBuffer
	---@param info vk.ffi.RenderPassBeginInfo
	---@param contents vk.SubpassContents
	function VKDevice:cmdBeginRenderPass(commandBuffer, info, contents)
		self.v1_0.vkCmdBeginRenderPass(commandBuffer, info, contents)
	end

	---@param commandBuffer vk.ffi.CommandBuffer
	function VKDevice:cmdEndRenderPass(commandBuffer)
		self.v1_0.vkCmdEndRenderPass(commandBuffer)
	end

	---@param commandBuffer vk.ffi.CommandBuffer
	---@param pipelineBindPoint vk.PipelineBindPoint
	---@param pipeline vk.ffi.Pipeline
	function VKDevice:cmdBindPipeline(commandBuffer, pipelineBindPoint, pipeline)
		self.v1_0.vkCmdBindPipeline(commandBuffer, pipelineBindPoint, pipeline)
	end

	---@param commandBuffer vk.ffi.CommandBuffer
	---@param pipelineBindPoint vk.PipelineBindPoint
	---@param layout vk.ffi.PipelineLayout
	---@param firstSet number
	---@param descriptorSetCount number
	---@param descriptorSets ffi.cdata*
	---@param dynamicOffsetCount number
	---@param dynamicOffsets ffi.cdata*?
	function VKDevice:cmdBindDescriptorSets(commandBuffer, pipelineBindPoint, layout, firstSet, descriptorSetCount,
											descriptorSets, dynamicOffsetCount, dynamicOffsets)
		self.v1_0.vkCmdBindDescriptorSets(commandBuffer, pipelineBindPoint, layout, firstSet, descriptorSetCount,
			descriptorSets, dynamicOffsetCount, dynamicOffsets)
	end

	---@param commandBuffer vk.ffi.CommandBuffer
	---@param vertexCount number
	---@param instanceCount number
	---@param firstVertex number
	---@param firstInstance number
	function VKDevice:cmdDraw(commandBuffer, vertexCount, instanceCount, firstVertex, firstInstance)
		self.v1_0.vkCmdDraw(commandBuffer, vertexCount, instanceCount, firstVertex, firstInstance)
	end

	---@param commandBuffer vk.ffi.CommandBuffer
	---@param dstBuffer vk.ffi.Buffer
	---@param dstOffset vk.ffi.DeviceSize
	---@param dataSize vk.ffi.DeviceSize
	---@param pData ffi.cdata*
	function VKDevice:cmdUpdateBuffer(commandBuffer, dstBuffer, dstOffset, dataSize, pData)
		self.v1_0.vkCmdUpdateBuffer(commandBuffer, dstBuffer, dstOffset, dataSize, pData)
	end

	---@param commandBuffer vk.ffi.CommandBuffer
	---@param srcBuffer vk.ffi.Buffer
	---@param dstImage vk.ffi.Image
	---@param dstImageLayout vk.ImageLayout
	---@param regionCount number
	---@param pRegions ffi.cdata*
	function VKDevice:cmdCopyBufferToImage(commandBuffer, srcBuffer, dstImage, dstImageLayout, regionCount, pRegions)
		self.v1_0.vkCmdCopyBufferToImage(commandBuffer, srcBuffer, dstImage, dstImageLayout, regionCount, pRegions)
	end

	---@param commandBuffer vk.ffi.CommandBuffer
	---@param groupCountX number
	---@param groupCountY number
	---@param groupCountZ number
	function VKDevice:cmdDispatch(commandBuffer, groupCountX, groupCountY, groupCountZ)
		self.v1_0.vkCmdDispatch(commandBuffer, groupCountX, groupCountY, groupCountZ)
	end

	---@param commandBuffer vk.ffi.CommandBuffer
	---@param srcStageMask vk.PipelineStageFlags
	---@param dstStageMask vk.PipelineStageFlags
	---@param imageMemoryBarrierCount number
	---@param pImageMemoryBarriers ffi.cdata*?
	---@param memoryBarrierCount number?
	---@param pMemoryBarriers ffi.cdata*?
	function VKDevice:cmdPipelineBarrier(commandBuffer, srcStageMask, dstStageMask, imageMemoryBarrierCount,
										 pImageMemoryBarriers, memoryBarrierCount, pMemoryBarriers)
		self.v1_0.vkCmdPipelineBarrier(commandBuffer, srcStageMask, dstStageMask, 0,
			memoryBarrierCount or 0, pMemoryBarriers,
			0, nil,
			imageMemoryBarrierCount, pImageMemoryBarriers)
	end

	---@param fences vk.ffi.Fence[]
	---@param waitAll boolean
	---@param timeout number
	function VKDevice:waitForFences(fences, waitAll, timeout)
		local count = #fences
		local fenceArray = ffi.new("VkFence[?]", count)
		for i = 1, count do
			fenceArray[i - 1] = fences[i]
		end
		local result = self.v1_0.vkWaitForFences(self.handle, count, fenceArray, waitAll and 1 or 0, timeout)
		if result ~= 0 then
			error("Failed to wait for fences, error code: " .. tostring(result))
		end
	end

	---@param fences vk.ffi.Fence[]
	function VKDevice:resetFences(fences)
		local count = #fences
		local fenceArray = ffi.new("VkFence[?]", count)
		for i = 1, count do
			fenceArray[i - 1] = fences[i]
		end
		local result = self.v1_0.vkResetFences(self.handle, count, fenceArray)
		if result ~= 0 then
			error("Failed to reset fences, error code: " .. tostring(result))
		end
	end

	---@param commandBuffer vk.ffi.CommandBuffer
	---@param firstViewport number
	---@param viewportCount number
	---@param pViewports ffi.cdata*
	function VKDevice:cmdSetViewport(commandBuffer, firstViewport, viewportCount, pViewports)
		self.v1_0.vkCmdSetViewport(commandBuffer, firstViewport, viewportCount, pViewports)
	end

	---@param commandBuffer vk.ffi.CommandBuffer
	---@param firstScissor number
	---@param scissorCount number
	---@param pScissors ffi.cdata*
	function VKDevice:cmdSetScissor(commandBuffer, firstScissor, scissorCount, pScissors)
		self.v1_0.vkCmdSetScissor(commandBuffer, firstScissor, scissorCount, pScissors)
	end

	---@param commandBuffer vk.ffi.CommandBuffer
	---@param firstBinding number
	---@param bindingCount number
	---@param pBuffers ffi.cdata*
	---@param pOffsets ffi.cdata*
	function VKDevice:cmdBindVertexBuffers(commandBuffer, firstBinding, bindingCount, pBuffers, pOffsets)
		self.v1_0.vkCmdBindVertexBuffers(commandBuffer, firstBinding, bindingCount, pBuffers, pOffsets)
	end

	---@param commandBuffer vk.ffi.CommandBuffer
	---@param buffer vk.ffi.Buffer
	---@param offset number
	---@param indexType number
	function VKDevice:cmdBindIndexBuffer(commandBuffer, buffer, offset, indexType)
		self.v1_0.vkCmdBindIndexBuffer(commandBuffer, buffer, offset, indexType)
	end

	---@param commandBuffer vk.ffi.CommandBuffer
	---@param indexCount number
	---@param instanceCount number
	---@param firstIndex number
	---@param vertexOffset number
	---@param firstInstance number
	function VKDevice:cmdDrawIndexed(commandBuffer, indexCount, instanceCount, firstIndex, vertexOffset, firstInstance)
		self.v1_0.vkCmdDrawIndexed(commandBuffer, indexCount, instanceCount, firstIndex, vertexOffset, firstInstance)
	end

	---@param queue vk.ffi.Queue
	---@param submits vk.ffi.SubmitInfo[]
	---@param fence number?
	function VKDevice:queueSubmit(queue, submits, fence)
		local count = #submits
		local submitArray = vk.SubmitInfoArray(count)
		for i = 1, count do
			local s = submits[i]
			submitArray[i - 1].waitSemaphoreCount = s.waitSemaphoreCount or 0
			submitArray[i - 1].pWaitSemaphores = s.pWaitSemaphores
			submitArray[i - 1].pWaitDstStageMask = s.pWaitDstStageMask
			submitArray[i - 1].commandBufferCount = s.commandBufferCount or 0
			submitArray[i - 1].pCommandBuffers = s.pCommandBuffers
			submitArray[i - 1].signalSemaphoreCount = s.signalSemaphoreCount or 0
			submitArray[i - 1].pSignalSemaphores = s.pSignalSemaphores
		end
		local result = self.v1_0.vkQueueSubmit(queue, count, submitArray, fence or 0)
		if result ~= 0 then
			error("Failed to submit to Vulkan queue, error code: " .. tostring(result))
		end
	end

	---@param queue vk.ffi.Queue
	function VKDevice:queueWaitIdle(queue)
		local result = self.v1_0.vkQueueWaitIdle(queue)
		if result ~= 0 then
			error("Failed to wait for Vulkan queue idle, error code: " .. tostring(result))
		end
	end

	---@param queueFamilyIndex number
	---@param queueIndex number
	---@return vk.ffi.Queue
	function VKDevice:getDeviceQueue(queueFamilyIndex, queueIndex)
		local queue = ffi.new("VkQueue[1]")
		self.v1_0.vkGetDeviceQueue(self.handle, queueFamilyIndex, queueIndex, queue)
		return queue[0]
	end

	---@param info vk.ffi.SemaphoreCreateInfo
	---@param allocator ffi.cdata*?
	---@return vk.ffi.Semaphore
	function VKDevice:createSemaphore(info, allocator)
		local createInfo = vk.SemaphoreCreateInfo(info)
		local semaphore = ffi.new("VkSemaphore[1]")
		local result = self.v1_0.vkCreateSemaphore(self.handle, createInfo, allocator, semaphore)
		if result ~= 0 then
			error("Failed to create Vulkan semaphore, error code: " .. tostring(result))
		end
		return semaphore[0]
	end

	---@param info vk.ffi.FenceCreateInfo
	---@param allocator ffi.cdata*?
	---@return vk.ffi.Fence
	function VKDevice:createFence(info, allocator)
		local createInfo = vk.FenceCreateInfo(info)
		local fence = ffi.new("VkFence[1]")
		local result = self.v1_0.vkCreateFence(self.handle, createInfo, allocator, fence)
		if result ~= 0 then
			error("Failed to create Vulkan fence, error code: " .. tostring(result))
		end
		return fence[0]
	end

	---@param info vk.ffi.SwapchainCreateInfoKHR
	---@param allocator ffi.cdata*?
	---@return vk.ffi.SwapchainKHR
	function VKDevice:createSwapchainKHR(info, allocator)
		local createInfo = vk.SwapchainCreateInfoKHR(info)
		local swapchain = ffi.new("VkSwapchainKHR[1]")
		local result = self.v1_0.vkCreateSwapchainKHR(self.handle, createInfo, allocator, swapchain)
		if result ~= 0 then
			error("Failed to create Vulkan swapchain, error code: " .. tostring(result))
		end
		return swapchain[0]
	end

	---@param swapchain vk.ffi.SwapchainKHR
	---@return vk.ffi.Image[]
	function VKDevice:getSwapchainImagesKHR(swapchain)
		local count = ffi.new("uint32_t[1]")
		local result = self.v1_0.vkGetSwapchainImagesKHR(self.handle, swapchain, count, nil)
		if result ~= 0 then
			error("Failed to get swapchain image count, error code: " .. tostring(result))
		end

		local images = ffi.new("VkImage[?]", count[0])
		result = self.v1_0.vkGetSwapchainImagesKHR(self.handle, swapchain, count, images)
		if result ~= 0 then
			error("Failed to get swapchain images, error code: " .. tostring(result))
		end

		local imageTable = {}
		for i = 0, count[0] - 1 do
			imageTable[i + 1] = images[i]
		end

		return imageTable
	end

	---@param swapchain vk.ffi.SwapchainKHR
	---@param timeout number
	---@param semaphore vk.ffi.Semaphore?
	---@param fence vk.ffi.Fence?
	---@return number imageIndex
	function VKDevice:acquireNextImageKHR(swapchain, timeout, semaphore, fence)
		local imageIndex = ffi.new("uint32_t[1]")
		local result = self.v1_0.vkAcquireNextImageKHR(self.handle, swapchain, timeout, semaphore or 0, fence or 0,
			imageIndex)
		if result ~= 0 then
			error("Failed to acquire next swapchain image, error code: " .. tostring(result))
		end
		return imageIndex[0]
	end

	do
		local swapchains = ffi.new("VkSwapchainKHR[1]")
		local imageIndices = ffi.new("uint32_t[1]")
		local semaphores = ffi.new("VkSemaphore[1]")

		local info = vk.PresentInfoKHR()
		info.swapchainCount = 1
		info.pSwapchains = swapchains
		info.pImageIndices = imageIndices

		---@param queue vk.ffi.Queue
		---@param handle vk.ffi.SwapchainKHR
		---@param imageIndex number
		---@param waitSemaphore vk.ffi.Semaphore?
		function VKDevice:queuePresentKHR(queue, handle, imageIndex, waitSemaphore)
			swapchains[0] = handle
			imageIndices[0] = imageIndex
			if waitSemaphore then
				semaphores[0] = waitSemaphore
				info.pWaitSemaphores = semaphores
				info.waitSemaphoreCount = 1
			else
				info.waitSemaphoreCount = 0
			end

			local result = self.v1_0.vkQueuePresentKHR(queue, info)
			if result < 0 then
				error("Failed to present queue, error code: " .. tostring(result))
			end
		end
	end

	---@class vk.Device.Fns
	---@field vkCreateBuffer fun(device: vk.ffi.Device, info: ffi.cdata*, allocator: ffi.cdata*?, buffer: ffi.cdata*): vk.ffi.Result
	---@field vkDestroyBuffer fun(device: vk.ffi.Device, buffer: vk.ffi.Buffer, allocator: ffi.cdata*?)
	---@field vkCreateShaderModule fun(device: vk.ffi.Device, info: ffi.cdata*, allocator: ffi.cdata*?, shaderModule: ffi.cdata*): vk.ffi.Result
	---@field vkCreatePipelineLayout fun(device: vk.ffi.Device, info: ffi.cdata*, allocator: ffi.cdata*?, pipelineLayout: ffi.cdata*): vk.ffi.Result
	---@field vkCreateGraphicsPipelines fun(device: vk.ffi.Device, pipelineCache: vk.ffi.PipelineCache, count: number, infos: ffi.cdata*, allocator: ffi.cdata*?, pipelines: ffi.cdata*): vk.ffi.Result
	---@field vkCreateRenderPass fun(device: vk.ffi.Device, info: ffi.cdata*, allocator: ffi.cdata*?, renderPass: ffi.cdata*): vk.ffi.Result
	---@field vkCreateImageView fun(device: vk.ffi.Device, info: ffi.cdata*, allocator: ffi.cdata*?, imageView: ffi.cdata*): vk.ffi.Result
	---@field vkCreateFramebuffer fun(device: vk.ffi.Device, info: ffi.cdata*, allocator: ffi.cdata*?, framebuffer: ffi.cdata*): vk.ffi.Result
	---@field vkGetBufferMemoryRequirements fun(device: vk.ffi.Device, buffer: vk.ffi.Buffer, memRequirements: ffi.cdata*)
	---@field vkGetImageMemoryRequirements fun(device: vk.ffi.Device, image: vk.ffi.Image, memRequirements: ffi.cdata*)
	---@field vkCreateImage fun(device: vk.ffi.Device, info: ffi.cdata*, allocator: ffi.cdata*?, image: ffi.cdata*): vk.ffi.Result
	---@field vkBindImageMemory fun(device: vk.ffi.Device, image: vk.ffi.Image, memory: vk.ffi.DeviceMemory, offset: number): vk.ffi.Result
	---@field vkAllocateMemory fun(device: vk.ffi.Device, info: ffi.cdata*, allocator: ffi.cdata*?, memory: ffi.cdata*): vk.ffi.Result
	---@field vkBindBufferMemory fun(device: vk.ffi.Device, buffer: vk.ffi.Buffer, memory: vk.ffi.DeviceMemory, offset: number): vk.ffi.Result
	---@field vkMapMemory fun(device: vk.ffi.Device, memory: vk.ffi.DeviceMemory, offset: number, size: number, flags: number, data: ffi.cdata*): vk.ffi.Result
	---@field vkUnmapMemory fun(device: vk.ffi.Device, memory: vk.ffi.DeviceMemory)
	---@field vkCreateCommandPool fun(device: vk.ffi.Device, info: ffi.cdata*, allocator: ffi.cdata*?, commandPool: ffi.cdata*): vk.ffi.Result
	---@field vkCreateDescriptorSetLayout fun(device: vk.ffi.Device, info: ffi.cdata*, allocator: ffi.cdata*?, layout: ffi.cdata*): vk.ffi.Result
	---@field vkCreateDescriptorPool fun(device: vk.ffi.Device, info: ffi.cdata*, allocator: ffi.cdata*?, pool: ffi.cdata*): vk.ffi.Result
	---@field vkAllocateDescriptorSets fun(device: vk.ffi.Device, info: ffi.cdata*, descriptorSets: ffi.cdata*): vk.ffi.Result
	---@field vkUpdateDescriptorSets fun(device: vk.ffi.Device, writeCount: number, writes: ffi.cdata*, copyCount: number, copies: ffi.cdata*?)
	---@field vkAllocateCommandBuffers fun(device: vk.ffi.Device, info: ffi.cdata*, commandBuffers: ffi.cdata*): vk.ffi.Result
	---@field vkBeginCommandBuffer fun(commandBuffer: vk.ffi.CommandBuffer, info: ffi.cdata*): vk.ffi.Result
	---@field vkEndCommandBuffer fun(commandBuffer: vk.ffi.CommandBuffer): vk.ffi.Result
	---@field vkCmdBeginRenderPass fun(commandBuffer: vk.ffi.CommandBuffer, info: ffi.cdata*, contents: vk.SubpassContents)
	---@field vkCmdEndRenderPass fun(commandBuffer: vk.ffi.CommandBuffer)
	---@field vkCmdBindPipeline fun(commandBuffer: vk.ffi.CommandBuffer, pipelineBindPoint: vk.PipelineBindPoint, pipeline: vk.ffi.Pipeline)
	---@field vkCmdBindDescriptorSets fun(commandBuffer: vk.ffi.CommandBuffer, pipelineBindPoint: vk.PipelineBindPoint, layout: vk.ffi.PipelineLayout, firstSet: number, count: number, sets: ffi.cdata*, dynamicOffsetCount: number, dynamicOffsets: ffi.cdata*?)
	---@field vkCmdDraw fun(commandBuffer: vk.ffi.CommandBuffer, vertexCount: number, instanceCount: number, firstVertex: number, firstInstance: number)
	---@field vkCmdUpdateBuffer fun(commandBuffer: vk.ffi.CommandBuffer, dstBuffer: vk.ffi.Buffer, dstOffset: number, dataSize: number, pData: ffi.cdata*)
	---@field vkCmdCopyBufferToImage fun(commandBuffer: vk.ffi.CommandBuffer, srcBuffer: vk.ffi.Buffer, dstImage: vk.ffi.Image, dstImageLayout: vk.ImageLayout, regionCount: number, pRegions: ffi.cdata*)
	---@field vkCmdSetViewport fun(commandBuffer: vk.ffi.CommandBuffer, firstViewport: number, viewportCount: number, pViewports: ffi.cdata*)
	---@field vkCmdSetScissor fun(commandBuffer: vk.ffi.CommandBuffer, firstScissor: number, scissorCount: number, pScissors: ffi.cdata*)
	---@field vkCmdBindVertexBuffers fun(commandBuffer: vk.ffi.CommandBuffer, firstBinding: number, bindingCount: number, pBuffers: ffi.cdata*, pOffsets: ffi.cdata*)
	---@field vkCmdBindIndexBuffer fun(commandBuffer: vk.ffi.CommandBuffer, buffer: vk.ffi.Buffer, offset: number, indexType: number)
	---@field vkCmdDrawIndexed fun(commandBuffer: vk.ffi.CommandBuffer, indexCount: number, instanceCount: number, firstIndex: number, vertexOffset: number, firstInstance: number)
	---@field vkQueueSubmit fun(queue: vk.ffi.Queue, submitCount: number, submits: ffi.cdata*, fence: number): vk.ffi.Result
	---@field vkQueueWaitIdle fun(queue: vk.ffi.Queue): vk.ffi.Result
	---@field vkGetDeviceQueue fun(device: vk.ffi.Device, queueFamilyIndex: number, queueIndex: number, queue: ffi.cdata*)
	---@field vkCreateSemaphore fun(device: vk.ffi.Device, info: ffi.cdata*, allocator: ffi.cdata*?, semaphore: ffi.cdata*): vk.ffi.Result
	---@field vkCreateFence fun(device: vk.ffi.Device, info: ffi.cdata*, allocator: ffi.cdata*?, fence: ffi.cdata*): vk.ffi.Result
	---@field vkWaitForFences fun(device: vk.ffi.Device, fenceCount: number, pFences: ffi.cdata*, waitAll: number, timeout: number): vk.ffi.Result
	---@field vkResetFences fun(device: vk.ffi.Device, fenceCount: number, pFences: ffi.cdata*): vk.ffi.Result
	---@field vkCreateSwapchainKHR fun(device: vk.ffi.Device, info: ffi.cdata*, allocator: ffi.cdata*?, swapchain: ffi.cdata*): vk.ffi.Result
	---@field vkGetSwapchainImagesKHR fun(device: vk.ffi.Device, swapchain: vk.ffi.SwapchainKHR, count: ffi.cdata*, images: ffi.cdata*?): vk.ffi.Result
	---@field vkAcquireNextImageKHR fun(device: vk.ffi.Device, swapchain: vk.ffi.SwapchainKHR, timeout: number, semaphore: vk.ffi.Semaphore?, fence: vk.ffi.Fence?, imageIndex: ffi.cdata*): vk.ffi.Result
	---@field vkQueuePresentKHR fun(queue: vk.ffi.Queue, info: vk.ffi.PresentInfoKHR): vk.ffi.Result
	---@field vkCreateSampler fun(device: vk.ffi.Device, info: ffi.cdata*, allocator: ffi.cdata*?, sampler: ffi.cdata*): vk.ffi.Result
	---@field vkDestroySampler fun(device: vk.ffi.Device, sampler: vk.ffi.Sampler, allocator: ffi.cdata*?)
	---@field vkCmdPipelineBarrier fun(commandBuffer: vk.ffi.CommandBuffer, srcStageMask: number, dstStageMask: number, dependencyFlags: number, memoryBarrierCount: number, pMemoryBarriers: ffi.cdata*?, bufferMemoryBarrierCount: number, pBufferMemoryBarriers: ffi.cdata*?, imageMemoryBarrierCount: number, pImageMemoryBarriers: ffi.cdata*?)
	---@field vkCreateComputePipelines fun(device: vk.ffi.Device, pipelineCache: number, count: number, infos: ffi.cdata*, allocator: ffi.cdata*?, pipelines: ffi.cdata*): vk.ffi.Result
	---@field vkCmdDispatch fun(commandBuffer: vk.ffi.CommandBuffer, groupCountX: number, groupCountY: number, groupCountZ: number)

	---@param handle vk.ffi.Device
	function VKDevice.new(handle)
		---@format disable-next
		local v1_0Types = {
			vkCreateBuffer = "VkResult(*)(VkDevice, const VkBufferCreateInfo*, const VkAllocationCallbacks*, VkBuffer*)",
			vkDestroyBuffer = "void(*)(VkDevice, VkBuffer, const VkAllocationCallbacks*)",
			vkCreateShaderModule = "VkResult(*)(VkDevice, const VkShaderModuleCreateInfo*, const VkAllocationCallbacks*, VkShaderModule*)",
			vkCreatePipelineLayout = "VkResult(*)(VkDevice, const VkPipelineLayoutCreateInfo*, const VkAllocationCallbacks*, VkPipelineLayout*)",
			vkCreateGraphicsPipelines = "VkResult(*)(VkDevice, uint64_t, uint32_t, const VkGraphicsPipelineCreateInfo*, const VkAllocationCallbacks*, VkPipeline*)",
			vkCreateRenderPass = "VkResult(*)(VkDevice, const VkRenderPassCreateInfo*, const VkAllocationCallbacks*, VkRenderPass*)",
			vkCreateImageView = "VkResult(*)(VkDevice, const VkImageViewCreateInfo*, const VkAllocationCallbacks*, VkImageView*)",
			vkCreateFramebuffer = "VkResult(*)(VkDevice, const VkFramebufferCreateInfo*, const VkAllocationCallbacks*, VkFramebuffer*)",
			vkGetBufferMemoryRequirements = "void(*)(VkDevice, VkBuffer, VkMemoryRequirements*)",
			vkGetImageMemoryRequirements = "void(*)(VkDevice, VkImage, VkMemoryRequirements*)",
			vkCreateImage = "VkResult(*)(VkDevice, const VkImageCreateInfo*, const VkAllocationCallbacks*, VkImage*)",
			vkBindImageMemory = "VkResult(*)(VkDevice, VkImage, VkDeviceMemory, VkDeviceSize)",
			vkAllocateMemory = "VkResult(*)(VkDevice, const VkMemoryAllocateInfo*, const VkAllocationCallbacks*, VkDeviceMemory*)",
			vkBindBufferMemory = "VkResult(*)(VkDevice, VkBuffer, VkDeviceMemory, VkDeviceSize)",
			vkMapMemory = "VkResult(*)(VkDevice, VkDeviceMemory, VkDeviceSize, VkDeviceSize, VkFlags, void**)",
			vkUnmapMemory = "void(*)(VkDevice, VkDeviceMemory)",
			vkCreateCommandPool = "VkResult(*)(VkDevice, const VkCommandPoolCreateInfo*, const VkAllocationCallbacks*, VkCommandPool*)",
			vkCreateDescriptorSetLayout = "VkResult(*)(VkDevice, const VkDescriptorSetLayoutCreateInfo*, const VkAllocationCallbacks*, VkDescriptorSetLayout*)",
			vkCreateDescriptorPool = "VkResult(*)(VkDevice, const VkDescriptorPoolCreateInfo*, const VkAllocationCallbacks*, VkDescriptorPool*)",
			vkAllocateDescriptorSets = "VkResult(*)(VkDevice, const VkDescriptorSetAllocateInfo*, VkDescriptorSet*)",
			vkUpdateDescriptorSets = "void(*)(VkDevice, uint32_t, const VkWriteDescriptorSet*, uint32_t, const void*)",
			vkAllocateCommandBuffers = "VkResult(*)(VkDevice, const VkCommandBufferAllocateInfo*, VkCommandBuffer*)",
			vkBeginCommandBuffer = "VkResult(*)(VkCommandBuffer, const VkCommandBufferBeginInfo*)",
			vkEndCommandBuffer = "VkResult(*)(VkCommandBuffer)",
			vkCmdBeginRenderPass = "void(*)(VkCommandBuffer, const VkRenderPassBeginInfo*, VkSubpassContents)",
			vkCmdEndRenderPass = "void(*)(VkCommandBuffer)",
			vkCmdBindPipeline = "void(*)(VkCommandBuffer, VkPipelineBindPoint, VkPipeline)",
			vkCmdDraw = "void(*)(VkCommandBuffer, uint32_t, uint32_t, uint32_t, uint32_t)",
			vkCmdBindDescriptorSets = "void(*)(VkCommandBuffer, VkPipelineBindPoint, VkPipelineLayout, uint32_t, uint32_t, const VkDescriptorSet*, uint32_t, const uint32_t*)",
			vkCmdCopyBufferToImage = "void(*)(VkCommandBuffer, VkBuffer, VkImage, VkImageLayout, uint32_t, const VkBufferImageCopy*)",
			vkCmdUpdateBuffer = "void(*)(VkCommandBuffer, VkBuffer, VkDeviceSize, VkDeviceSize, const void*)",
			vkCmdSetViewport = "void(*)(VkCommandBuffer, uint32_t, uint32_t, const VkViewport*)",
			vkCmdSetScissor = "void(*)(VkCommandBuffer, uint32_t, uint32_t, const VkRect2D*)",
			vkCmdBindVertexBuffers = "void(*)(VkCommandBuffer, uint32_t, uint32_t, const VkBuffer*, const VkDeviceSize*)",
			vkCmdBindIndexBuffer = "void(*)(VkCommandBuffer, VkBuffer, VkDeviceSize, VkIndexType)",
			vkCmdDrawIndexed = "void(*)(VkCommandBuffer, uint32_t, uint32_t, uint32_t, int32_t, uint32_t)",
			vkQueueSubmit = "VkResult(*)(VkQueue, uint32_t, const VkSubmitInfo*, uint64_t)",
			vkQueueWaitIdle = "VkResult(*)(VkQueue)",
			vkGetDeviceQueue = "void(*)(VkDevice, uint32_t, uint32_t, VkQueue*)",
			vkCreateSemaphore = "VkResult(*)(VkDevice, const VkSemaphoreCreateInfo*, const VkAllocationCallbacks*, VkSemaphore*)",
			vkCreateFence = "VkResult(*)(VkDevice, const VkFenceCreateInfo*, const VkAllocationCallbacks*, VkFence*)",
			vkWaitForFences = "VkResult(*)(VkDevice, uint32_t, const VkFence*, VkBool32, uint64_t)",
			vkResetFences = "VkResult(*)(VkDevice, uint32_t, const VkFence*)",
			vkCreateSwapchainKHR = "VkResult(*)(VkDevice, const VkSwapchainCreateInfoKHR*, const VkAllocationCallbacks*, VkSwapchainKHR*)",
			vkGetSwapchainImagesKHR = "VkResult(*)(VkDevice, VkSwapchainKHR, uint32_t*, VkImage*)",
			vkAcquireNextImageKHR = "VkResult(*)(VkDevice, VkSwapchainKHR, uint64_t, VkSemaphore, VkFence, uint32_t*)",
			vkQueuePresentKHR = "VkResult(*)(VkQueue, const VkPresentInfoKHR*)",
			vkCreateSampler = "VkResult(*)(VkDevice, const VkSamplerCreateInfo*, const VkAllocationCallbacks*, VkSampler*)",
			vkDestroySampler = "void(*)(VkDevice, VkSampler, const VkAllocationCallbacks*)",
			vkDestroyImageView = "void(*)(VkDevice, VkImageView, const VkAllocationCallbacks*)",
			vkDestroyFramebuffer = "void(*)(VkDevice, VkFramebuffer, const VkAllocationCallbacks*)",
			vkDestroyCommandPool = "void(*)(VkDevice, VkCommandPool, const VkAllocationCallbacks*)",
			vkDestroyShaderModule = "void(*)(VkDevice, VkShaderModule, const VkAllocationCallbacks*)",
			vkDestroyFence = "void(*)(VkDevice, VkFence, const VkAllocationCallbacks*)",
			vkFreeMemory = "void(*)(VkDevice, VkDeviceMemory, const VkAllocationCallbacks*)",
			vkResetCommandPool = "VkResult(*)(VkDevice, VkCommandPool, VkFlags)",
			vkCmdPipelineBarrier = "void(*)(VkCommandBuffer, VkFlags, VkFlags, VkFlags, uint32_t, const void*, uint32_t, const void*, uint32_t, const VkImageMemoryBarrier*)",
			vkCreateComputePipelines = "VkResult(*)(VkDevice, uint64_t, uint32_t, const VkComputePipelineCreateInfo*, const VkAllocationCallbacks*, VkPipeline*)",
			vkCmdDispatch = "void(*)(VkCommandBuffer, uint32_t, uint32_t, uint32_t)",
		}

		---@type vk.Device.Fns
		local v1_0 = {}
		for name, funcType in pairs(v1_0Types) do
			v1_0[name] = ffi.cast(funcType, vk.getDeviceProcAddr(handle, name))
		end

		return setmetatable({
			handle = handle,
			v1_0 = v1_0,
		}, VKDevice)
	end

	return VKDevice
end
