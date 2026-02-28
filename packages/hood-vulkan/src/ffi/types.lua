---@class vk.ffi.BaseStruct
---@field sType vk.StructureType?
---@field pNext ffi.cdata*?
---@field flags number?

---@alias vk.ImageAspectFlags number
---@alias vk.Flags number

---@class vk.ffi.Instance: number
---@class vk.ffi.Result: number
---@class vk.ffi.PhysicalDevice: ffi.cdata*
---@class vk.ffi.Device: number
---@class vk.ffi.PipelineCache: number
---@class vk.ffi.DeviceSize: number
---@class vk.ffi.Buffer: number
---@class vk.ffi.PipelineLayout: number
---@class vk.ffi.Pipeline: number
---@class vk.ffi.RenderPass: number
---@class vk.ffi.Framebuffer: number
---@class vk.ffi.ShaderModule: number
---@class vk.ffi.CommandPool: number
---@class vk.ffi.CommandBuffer: number
---@class vk.ffi.DescriptorSetLayout: number
---@class vk.ffi.DescriptorPool: number
---@class vk.ffi.DescriptorSet: number
---@class vk.ffi.Queue: number
---@class vk.ffi.Semaphore: number
---@class vk.ffi.Fence: number
---@class vk.ffi.Image: number
---@class vk.ffi.DeviceMemory: number
---@class vk.ffi.Sampler: number
---@class vk.ffi.ImageView: number
---@class vk.ffi.SwapchainKHR: number
---@class vk.ffi.SurfaceKHR: number

---@class vk.ffi.MemoryRequirements: ffi.cdata*
---@field size vk.ffi.DeviceSize
---@field alignment vk.ffi.DeviceSize
---@field memoryTypeBits number

---@class vk.ffi.CreateImageInfo: vk.ffi.BaseStruct
---@field imageType vk.ImageType
---@field format vk.Format
---@field extent vk.ffi.Extent3D
---@field mipLevels number
---@field arrayLayers number
---@field samples vk.SampleCountFlagBits
---@field tiling vk.ImageTiling
---@field usage vk.ImageUsageFlagBits
---@field sharingMode vk.SharingMode
---@field queueFamilyIndexCount number?
---@field pQueueFamilyIndices ffi.cdata*?
---@field initialLayout vk.ImageLayout

---@class vk.ffi.MemoryType: ffi.cdata*
---@field propertyFlags number
---@field heapIndex number

---@class vk.ffi.MemoryHeap: ffi.cdata*
---@field size number
---@field flags number

---@class vk.ffi.Extent2D: ffi.cdata*
---@field width number
---@field height number

---@class vk.ffi.Extent3D: ffi.cdata*
---@field width number
---@field height number
---@field depth number

---@class vk.ffi.PhysicalDeviceMemoryProperties: ffi.cdata*
---@field memoryTypeCount number
---@field memoryTypes ffi.cdata*
---@field memoryHeapCount number
---@field memoryHeaps ffi.cdata*

---@class vk.ffi.QueueFamilyProperties: ffi.cdata*
---@field queueFlags number
---@field queueCount number
---@field timestampValidBits number
---@field minImageTransferGranularity vk.ffi.Extent3D

---@class vk.ffi.MemoryAllocateInfo: vk.ffi.BaseStruct
---@field allocationSize number
---@field memoryTypeIndex number

---@class vk.ffi.SurfaceCapabilitiesKHR: ffi.cdata*
---@field minImageCount number
---@field maxImageCount number
---@field currentExtent vk.ffi.Extent2D
---@field minImageExtent vk.ffi.Extent2D
---@field maxImageExtent vk.ffi.Extent2D
---@field maxImageArrayLayers number
---@field supportedTransforms number
---@field currentTransform number
---@field supportedCompositeAlpha number
---@field supportedUsageFlags number

---@class vk.ffi.SurfaceFormatKHR: ffi.cdata*
---@field format vk.Format
---@field colorSpace number

---@class vk.ffi.ApplicationInfo: vk.ffi.BaseStruct
---@field pApplicationName ffi.cdata*?
---@field applicationVersion number
---@field pEngineName ffi.cdata*?
---@field engineVersion number
---@field apiVersion vk.ApiVersion

---@class vk.ffi.InstanceCreateInfo: vk.ffi.BaseStruct
---@field pApplicationInfo vk.ffi.ApplicationInfo?
---@field enabledLayerCount number?
---@field ppEnabledLayerNames ffi.cdata*?
---@field enabledExtensionCount number?
---@field ppEnabledExtensionNames ffi.cdata*?

---@class vk.ffi.DeviceQueueCreateInfo: vk.ffi.BaseStruct
---@field queueFamilyIndex number
---@field queueCount number
---@field pQueuePriorities ffi.cdata*

---@class vk.ffi.DeviceCreateInfo: vk.ffi.BaseStruct
---@field queueCreateInfoCount number?
---@field pQueueCreateInfos vk.ffi.DeviceQueueCreateInfo?
---@field enabledExtensionCount number?
---@field ppEnabledExtensionNames ffi.cdata*?
---@field pEnabledFeatures ffi.cdata*?

---@class vk.ffi.BufferCreateInfo: vk.ffi.BaseStruct
---@field size number
---@field usage vk.BufferUsage
---@field sharingMode vk.SharingMode?
---@field queueFamilyIndexCount number?
---@field pQueueFamilyIndices ffi.cdata*?

---@class vk.ffi.ShaderModuleCreateInfo: vk.ffi.BaseStruct
---@field codeSize number
---@field pCode ffi.cdata*

---@class vk.ffi.PushConstantRange: ffi.cdata*
---@field stageFlags vk.ShaderStageFlagBits
---@field offset number
---@field size number

---@class vk.ffi.PipelineLayoutCreateInfo: vk.ffi.BaseStruct
---@field setLayoutCount number?
---@field pSetLayouts ffi.cdata*?
---@field pushConstantRangeCount number?
---@field pPushConstantRanges vk.ffi.PushConstantRange?

---@class vk.ffi.SpecializationInfo: ffi.cdata*
---@field mapEntryCount number
---@field pMapEntries ffi.cdata*
---@field dataSize number
---@field pData ffi.cdata*

---@class vk.ffi.PipelineShaderStageCreateInfo: vk.ffi.BaseStruct
---@field stage vk.ShaderStageFlagBits
---@field module vk.ffi.ShaderModule
---@field pName ffi.cdata*
---@field pSpecializationInfo vk.ffi.SpecializationInfo?

---@class vk.ffi.VertexInputBindingDescription: ffi.cdata*
---@field binding number
---@field stride number
---@field inputRate vk.VertexInputRate

---@class vk.ffi.VertexInputAttributeDescription: ffi.cdata*
---@field location number
---@field binding number
---@field format vk.Format
---@field offset number

---@class vk.ffi.PipelineVertexInputStateCreateInfo: vk.ffi.BaseStruct
---@field vertexBindingDescriptionCount number
---@field pVertexBindingDescriptions vk.ffi.VertexInputBindingDescription*
---@field vertexAttributeDescriptionCount number
---@field pVertexAttributeDescriptions vk.ffi.VertexInputAttributeDescription*

---@class vk.ffi.PipelineInputAssemblyStateCreateInfo: vk.ffi.BaseStruct
---@field topology vk.PrimitiveTopology
---@field primitiveRestartEnable number

---@class vk.ffi.PipelineTessellationStateCreateInfo: vk.ffi.BaseStruct
---@field patchControlPoints number

---@class vk.ffi.Viewport: ffi.cdata*
---@field x number
---@field y number
---@field width number
---@field height number
---@field minDepth number
---@field maxDepth number

---@class vk.ffi.Offset2D: ffi.cdata*
---@field x number
---@field y number

---@class vk.ffi.Rect2D: ffi.cdata*
---@field offset vk.ffi.Offset2D
---@field extent vk.ffi.Extent2D

---@class vk.ffi.PipelineViewportStateCreateInfo: vk.ffi.BaseStruct
---@field viewportCount number
---@field pViewports vk.ffi.Viewport?
---@field scissorCount number
---@field pScissors vk.ffi.Rect2D?

---@class vk.ffi.PipelineRasterizationStateCreateInfo: vk.ffi.BaseStruct
---@field depthClampEnable number
---@field rasterizerDiscardEnable number
---@field polygonMode vk.PolygonMode
---@field cullMode vk.CullModeFlags
---@field frontFace vk.FrontFace
---@field depthBiasEnable number
---@field depthBiasConstantFactor number
---@field depthBiasClamp number
---@field depthBiasSlopeFactor number
---@field lineWidth number

---@class vk.ffi.PipelineMultisampleStateCreateInfo: vk.ffi.BaseStruct
---@field rasterizationSamples vk.SampleCountFlagBits
---@field sampleShadingEnable number
---@field minSampleShading number
---@field pSampleMask ffi.cdata*?
---@field alphaToCoverageEnable number
---@field alphaToOneEnable number

---@class vk.ffi.StencilOpState: ffi.cdata*
---@field failOp vk.StencilOp
---@field passOp vk.StencilOp
---@field depthFailOp vk.StencilOp
---@field compareOp vk.CompareOp
---@field compareMask number
---@field writeMask number
---@field reference number

---@class vk.ffi.PipelineDepthStencilStateCreateInfo: vk.ffi.BaseStruct
---@field depthTestEnable number
---@field depthWriteEnable number
---@field depthCompareOp vk.CompareOp
---@field depthBoundsTestEnable number
---@field stencilTestEnable number
---@field front vk.ffi.StencilOpState
---@field back vk.ffi.StencilOpState
---@field minDepthBounds number
---@field maxDepthBounds number

---@class vk.ffi.PipelineColorBlendAttachmentState: ffi.cdata*
---@field blendEnable number
---@field srcColorBlendFactor vk.BlendFactor
---@field dstColorBlendFactor vk.BlendFactor
---@field colorBlendOp vk.BlendOp
---@field srcAlphaBlendFactor vk.BlendFactor
---@field dstAlphaBlendFactor vk.BlendFactor
---@field alphaBlendOp vk.BlendOp
---@field colorWriteMask vk.ColorComponentFlags

---@class vk.ffi.PipelineColorBlendStateCreateInfo: vk.ffi.BaseStruct
---@field logicOpEnable number
---@field logicOp vk.LogicOp
---@field attachmentCount number
---@field pAttachments vk.ffi.PipelineColorBlendAttachmentState?
---@field blendConstants ffi.cdata*

---@class vk.ffi.PipelineDynamicStateCreateInfo: vk.ffi.BaseStruct
---@field dynamicStateCount number
---@field pDynamicStates ffi.cdata*

---@class vk.ffi.GraphicsPipelineCreateInfo: vk.ffi.BaseStruct
---@field stageCount number
---@field pStages vk.ffi.PipelineShaderStageCreateInfo
---@field pVertexInputState vk.ffi.PipelineVertexInputStateCreateInfo?
---@field pInputAssemblyState vk.ffi.PipelineInputAssemblyStateCreateInfo?
---@field pTessellationState vk.ffi.PipelineTessellationStateCreateInfo?
---@field pViewportState vk.ffi.PipelineViewportStateCreateInfo?
---@field pRasterizationState vk.ffi.PipelineRasterizationStateCreateInfo?
---@field pMultisampleState vk.ffi.PipelineMultisampleStateCreateInfo?
---@field pDepthStencilState vk.ffi.PipelineDepthStencilStateCreateInfo?
---@field pColorBlendState vk.ffi.PipelineColorBlendStateCreateInfo?
---@field pDynamicState vk.ffi.PipelineDynamicStateCreateInfo?
---@field layout vk.ffi.PipelineLayout
---@field renderPass vk.ffi.RenderPass
---@field subpass number?

---@class vk.ffi.AttachmentDescription: ffi.cdata*
---@field flags number
---@field format vk.Format
---@field samples vk.SampleCountFlagBits
---@field loadOp vk.AttachmentLoadOp
---@field storeOp vk.AttachmentStoreOp
---@field stencilLoadOp vk.AttachmentLoadOp
---@field stencilStoreOp vk.AttachmentStoreOp
---@field initialLayout vk.ImageLayout
---@field finalLayout vk.ImageLayout

---@class vk.ffi.AttachmentReference: ffi.cdata*
---@field attachment number
---@field layout vk.ImageLayout

---@class vk.ffi.SubpassDescription: ffi.cdata*
---@field flags number
---@field pipelineBindPoint vk.PipelineBindPoint
---@field inputAttachmentCount number
---@field pInputAttachments vk.ffi.AttachmentReference?
---@field colorAttachmentCount number
---@field pColorAttachments vk.ffi.AttachmentReference?
---@field pResolveAttachments vk.ffi.AttachmentReference?
---@field pDepthStencilAttachment vk.ffi.AttachmentReference?
---@field preserveAttachmentCount number
---@field pPreserveAttachments ffi.cdata*?

---@class vk.ffi.SubpassDependency: ffi.cdata*
---@field srcSubpass number
---@field dstSubpass number
---@field srcStageMask vk.PipelineStageFlags
---@field dstStageMask vk.PipelineStageFlags
---@field srcAccessMask vk.AccessFlags
---@field dstAccessMask vk.AccessFlags
---@field dependencyFlags number

---@class vk.ffi.RenderPassCreateInfo: vk.ffi.BaseStruct
---@field attachmentCount number?
---@field pAttachments vk.ffi.AttachmentDescription?
---@field subpassCount number
---@field pSubpasses vk.ffi.SubpassDescription
---@field dependencyCount number?
---@field pDependencies vk.ffi.SubpassDependency?

---@class vk.ffi.FramebufferCreateInfo: vk.ffi.BaseStruct
---@field renderPass vk.ffi.RenderPass
---@field attachmentCount number?
---@field pAttachments ffi.cdata*?
---@field width number
---@field height number
---@field layers number

---@class vk.ffi.CommandPoolCreateInfo: vk.ffi.BaseStruct
---@field flags number?
---@field queueFamilyIndex number

---@class vk.ffi.CommandBufferAllocateInfo: vk.ffi.BaseStruct
---@field commandPool vk.ffi.CommandPool
---@field level number
---@field commandBufferCount number

---@class vk.DescriptorSetLayoutBinding: ffi.cdata*
---@field binding number
---@field descriptorType number
---@field descriptorCount number
---@field stageFlags number
---@field pImmutableSamplers ffi.cdata*?

---@class vk.ffi.DescriptorSetLayoutCreateInfo: vk.ffi.BaseStruct
---@field bindingCount number?
---@field pBindings ffi.cdata*?

---@class vk.ffi.DescriptorPoolSize: ffi.cdata*
---@field type number
---@field descriptorCount number

---@class vk.ffi.DescriptorPoolCreateInfo: vk.ffi.BaseStruct
---@field maxSets number
---@field poolSizeCount number?
---@field pPoolSizes ffi.cdata*?

---@class vk.ffi.DescriptorSetAllocateInfo: vk.ffi.BaseStruct
---@field descriptorPool vk.ffi.DescriptorPool
---@field descriptorSetCount number
---@field pSetLayouts ffi.cdata*

---@class vk.ffi.DescriptorBufferInfo: ffi.cdata*
---@field buffer vk.ffi.Buffer
---@field offset number
---@field range number

---@class vk.ffi.DescriptorImageInfo: ffi.cdata*
---@field sampler number
---@field imageView number
---@field imageLayout number

---@class vk.ffi.WriteDescriptorSet: vk.ffi.BaseStruct
---@field dstSet vk.ffi.DescriptorSet
---@field dstBinding number
---@field dstArrayElement number
---@field descriptorCount number
---@field descriptorType number
---@field pImageInfo ffi.cdata*?
---@field pBufferInfo ffi.cdata*?
---@field pTexelBufferView ffi.cdata*?

---@class vk.ffi.SwapchainCreateInfoKHR: vk.ffi.BaseStruct
---@field surface vk.ffi.SurfaceKHR
---@field minImageCount number
---@field imageFormat vk.Format
---@field imageColorSpace number
---@field imageExtent vk.ffi.Extent2D
---@field imageArrayLayers number
---@field imageUsage vk.ImageUsageFlagBits
---@field imageSharingMode vk.SharingMode
---@field queueFamilyIndexCount number?
---@field pQueueFamilyIndices ffi.cdata*?
---@field preTransform number
---@field compositeAlpha number
---@field presentMode number
---@field clipped number
---@field oldSwapchain vk.ffi.SwapchainKHR

---@class vk.ffi.CommandBufferBeginInfo: vk.ffi.BaseStruct
---@field pInheritanceInfo ffi.cdata*?

---@class vk.ffi.RenderPassBeginInfo: vk.ffi.BaseStruct
---@field renderPass vk.ffi.RenderPass
---@field framebuffer vk.ffi.Framebuffer
---@field renderArea vk.ffi.Rect2D
---@field clearValueCount number?
---@field pClearValues ffi.cdata*?

---@class vk.ffi.SemaphoreCreateInfo: vk.ffi.BaseStruct

---@class vk.ffi.FenceCreateInfo: vk.ffi.BaseStruct

---@class vk.ffi.PresentInfoKHR: vk.ffi.BaseStruct
---@field waitSemaphoreCount number?
---@field pWaitSemaphores ffi.cdata*?
---@field swapchainCount number
---@field pSwapchains ffi.cdata*
---@field pImageIndices ffi.cdata*
---@field pResults ffi.cdata*?

---@class vk.ffi.SubmitInfo: vk.ffi.BaseStruct
---@field waitSemaphoreCount number?
---@field pWaitSemaphores ffi.cdata*?
---@field pWaitDstStageMask ffi.cdata*?
---@field commandBufferCount number
---@field pCommandBuffers ffi.cdata*?
---@field signalSemaphoreCount number?
---@field pSignalSemaphores ffi.cdata*?

---@class vk.ffi.PhysicalDeviceProperties: ffi.cdata*
---@field apiVersion number
---@field driverVersion number
---@field vendorID number
---@field deviceID number
---@field deviceType vk.PhysicalDeviceType
---@field deviceName ffi.cdata*
---@field pipelineCacheUUID ffi.cdata*
---@field limits ffi.cdata*
---@field sparseProperties ffi.cdata*

---@class vk.ffi.ComputePipelineCreateInfo: vk.ffi.BaseStruct
---@field stage vk.ffi.PipelineShaderStageCreateInfo
---@field layout vk.ffi.PipelineLayout

---@class vk.ffi.SamplerCreateInfo: vk.ffi.BaseStruct
---@field magFilter vk.Filter
---@field minFilter vk.Filter
---@field mipmapMode vk.SamplerMipmapMode
---@field addressModeU vk.SamplerAddressMode
---@field addressModeV vk.SamplerAddressMode
---@field addressModeW vk.SamplerAddressMode
---@field mipLodBias number
---@field anisotropyEnable number
---@field maxAnisotropy number
---@field compareEnable number
---@field compareOp vk.CompareOp
---@field minLod number
---@field maxLod number
---@field borderColor vk.BorderColor
---@field unnormalizedCoordinates number

---@alias vk.ffi.Sampler ffi.cdata*

---@class vk.ffi.XlibSurfaceCreateInfoKHR: vk.ffi.BaseStruct
---@field dpy ffi.cdata*
---@field window number

---@class vk.ffi.Win32SurfaceCreateInfoKHR: vk.ffi.BaseStruct
---@field hinstance ffi.cdata*
---@field hwnd ffi.cdata*

---@class vk.ffi.ImageSubresourceRange: ffi.cdata*
---@field aspectMask vk.ImageAspectFlags
---@field baseMipLevel number
---@field levelCount number
---@field baseArrayLayer number
---@field layerCount number

---@class vk.ffi.ComponentMapping: ffi.cdata*
---@field r vk.ComponentSwizzle
---@field g vk.ComponentSwizzle
---@field b vk.ComponentSwizzle
---@field a vk.ComponentSwizzle

---@class vk.ffi.ImageViewCreateInfo: vk.ffi.BaseStruct
---@field image vk.ffi.Image
---@field viewType vk.ImageViewType
---@field format vk.Format
---@field components vk.ffi.ComponentMapping
---@field subresourceRange vk.ffi.ImageSubresourceRange

---@class vk.ffi.ImageMemoryBarrier: vk.ffi.BaseStruct
---@field srcAccessMask vk.AccessFlags
---@field dstAccessMask vk.AccessFlags
---@field oldLayout vk.ImageLayout
---@field newLayout vk.ImageLayout
---@field srcQueueFamilyIndex number
---@field dstQueueFamilyIndex number
---@field image vk.ffi.Image
---@field subresourceRange vk.ffi.ImageSubresourceRange

---@class vk.ffi.MemoryBarrier: vk.ffi.BaseStruct
---@field srcAccessMask vk.AccessFlags
---@field dstAccessMask vk.AccessFlags

---@class vk.ffi.ClearColorValue: ffi.cdata*
---@field float32 ffi.cdata*
---@field int32 ffi.cdata*
---@field uint32 ffi.cdata*

---@class vk.ffi.ClearDepthStencilValue: ffi.cdata*
---@field depth number
---@field stencil number

---@class vk.ffi.ClearValue: ffi.cdata*
---@field color vk.ffi.ClearColorValue
---@field depthStencil vk.ffi.ClearDepthStencilValue

---@class vk.ffi.ImageSubresourceLayers: ffi.cdata*
---@field aspectMask vk.ImageAspectFlags
---@field mipLevel number
---@field baseArrayLayer number
---@field layerCount number

---@class vk.ffi.Offset3D: ffi.cdata*
---@field x number
---@field y number
---@field z number

---@class vk.ffi.BufferImageCopy: ffi.cdata*
---@field bufferOffset number
---@field bufferRowLength number
---@field bufferImageHeight number
---@field imageSubresource vk.ffi.ImageSubresourceLayers
---@field imageOffset vk.ffi.Offset3D
---@field imageExtent vk.ffi.Extent3D
