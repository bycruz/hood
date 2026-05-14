local ffi = require("ffi")

local vk = require("vkapi")
local vkConversions = require("hood.convert.vk")

local VKCommandBuffer = require("hood.vk.command_buffer")

---@class hood.vk.CommandEncoder
---@field buffer hood.vk.CommandBuffer
---@field device hood.vk.Device
---@field pendingDescriptor hood.RenderPassDescriptor?
---@field imageViews vk.ffi.ImageView[]
---@field framebuffers vk.ffi.Framebuffer[]
---@field pipeline hood.vk.Pipeline?
---@field computePipeline hood.vk.ComputePipeline?
---@field bindGroups table<number, hood.vk.BindGroup>
---@field renderPasses vk.ffi.RenderPass[]
---@field swapchains table<hood.vk.Swapchain, boolean>
local VKCommandEncoder = {}
VKCommandEncoder.__index = VKCommandEncoder

local beginInfo = vk.CommandBufferBeginInfo({
	flags = vk.CommandBufferUsageFlagBits.SIMULTANEOUS_USE
})

---@param device hood.vk.Device
---@return hood.vk.CommandEncoder
function VKCommandEncoder.new(device)
	local buffer = VKCommandBuffer.new(device)
	device.handle:beginCommandBuffer(buffer.handle, beginInfo)
	return setmetatable({
		device = device,
		buffer = buffer,
		imageViews = {},
		framebuffers = {},
		renderPasses = {},
		bindGroups = {},
		swapchains = {},
	}, VKCommandEncoder)
end

---@param descriptor hood.RenderPassDescriptor
function VKCommandEncoder:beginRendering(descriptor)
	self.pendingDescriptor = descriptor
end

---@param pipeline hood.vk.Pipeline
function VKCommandEncoder:setPipeline(pipeline)
	if self.pendingDescriptor then
		self:_beginRenderPass(pipeline, self.pendingDescriptor)
		self.pendingDescriptor = nil
	end

	self.pipeline = pipeline
	self.device.handle:cmdBindPipeline(self.buffer.handle, vk.PipelineBindPoint.GRAPHICS, pipeline.handle)
end

---@param pipeline hood.vk.Pipeline
---@param descriptor hood.RenderPassDescriptor
function VKCommandEncoder:_beginRenderPass(pipeline, descriptor)
	local colorAttachments = descriptor.colorAttachments or {}
	local depthAttachment = descriptor.depthStencilAttachment
	local totalAttachments = #colorAttachments + (depthAttachment and 1 or 0)

	local width, height
	if colorAttachments[1] then
		local view = colorAttachments[1].texture --[[@as hood.vk.TextureView]]
		width, height = view.texture.width, view.texture.height
	elseif depthAttachment then
		local view = depthAttachment.texture --[[@as hood.vk.TextureView]]
		width, height = view.texture.width, view.texture.height
	end

	local imageViews = ffi.new("VkImageView[?]", totalAttachments)
	local attachmentDescs = {}
	local colorRefs = {}

	-- Color attachments: att.texture is a TextureView, att.texture.handle is already a VkImageView
	for i, att in ipairs(colorAttachments) do
		local view = att.texture --[[@as hood.vk.TextureView]]
		imageViews[i - 1] = view.handle

		local isSwapchain = view.texture and view.texture.isSwapchain
		if isSwapchain and view.texture.swapchain then
			self.swapchains[view.texture.swapchain] = true
		end
		attachmentDescs[#attachmentDescs + 1] = {
			format = view.texture.format,
			samples = vk.SampleCountFlagBits.COUNT_1,
			loadOp = att.op.type == "clear" and vk.AttachmentLoadOp.CLEAR or vk.AttachmentLoadOp.LOAD,
			storeOp = vk.AttachmentStoreOp.STORE,
			stencilLoadOp = vk.AttachmentLoadOp.DONT_CARE,
			stencilStoreOp = vk.AttachmentStoreOp.DONT_CARE,
			initialLayout = vk.ImageLayout.UNDEFINED,
			finalLayout = isSwapchain and vk.ImageLayout.PRESENT_SRC_KHR or vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL,
		}

		colorRefs[#colorRefs + 1] = {
			attachment = #attachmentDescs - 1,
			layout = vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL
		}
	end

	local depthRef = nil
	if depthAttachment then
		local view = depthAttachment.texture --[[@as hood.vk.TextureView]]
		imageViews[totalAttachments - 1] = view.handle

		attachmentDescs[#attachmentDescs + 1] = {
			format = view.texture.format,
			samples = vk.SampleCountFlagBits.COUNT_1,
			loadOp = depthAttachment.op.type == "clear" and vk.AttachmentLoadOp.CLEAR or vk.AttachmentLoadOp.LOAD,
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
	if depthAttachment then
		depthStageMask = bit.bor(vk.PipelineStageFlagBits.EARLY_FRAGMENT_TESTS,
			vk.PipelineStageFlagBits.LATE_FRAGMENT_TESTS)
		depthAccessMask = bit.bor(vk.AccessFlags.DEPTH_STENCIL_ATTACHMENT_READ,
			vk.AccessFlags.DEPTH_STENCIL_ATTACHMENT_WRITE)
	end

	local renderPass = self.device.handle:createRenderPass({
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
	self.renderPasses[#self.renderPasses + 1] = renderPass

	local framebuffer = self.device.handle:createFramebuffer({
		renderPass = renderPass,
		attachmentCount = totalAttachments,
		pAttachments = imageViews,
		width = width,
		height = height,
		layers = 1,
	})
	self.framebuffers[#self.framebuffers + 1] = framebuffer

	local clearValues = vk.ClearValueArray(totalAttachments)

	for i, att in ipairs(colorAttachments) do
		if att.op.type == "clear" then
			local c = att.op.color
			clearValues[i - 1].color.float32[0] = c.r
			clearValues[i - 1].color.float32[1] = c.g
			clearValues[i - 1].color.float32[2] = c.b
			clearValues[i - 1].color.float32[3] = c.a
		end
	end

	if depthAttachment and depthAttachment.op.type == "clear" then
		clearValues[totalAttachments - 1].depthStencil.depth = depthAttachment.op.depth
		clearValues[totalAttachments - 1].depthStencil.stencil = 0
	end

	local beginInfo = vk.RenderPassBeginInfo()
	beginInfo.renderPass = renderPass
	beginInfo.framebuffer = framebuffer
	beginInfo.renderArea.offset.x = 0
	beginInfo.renderArea.offset.y = 0
	beginInfo.renderArea.extent.width = width
	beginInfo.renderArea.extent.height = height
	beginInfo.clearValueCount = totalAttachments
	beginInfo.pClearValues = clearValues

	self.device.handle:cmdBeginRenderPass(self.buffer.handle, beginInfo, vk.SubpassContents.INLINE)
end

do
	local viewport = vk.Viewport()
	local scissor = vk.Rect2D()

	---@param x number
	---@param y number
	---@param width number
	---@param height number
	function VKCommandEncoder:setViewport(x, y, width, height)
		viewport.x = x
		viewport.y = y + height
		viewport.width = width
		viewport.height = -height
		viewport.minDepth = 0
		viewport.maxDepth = 1

		scissor.offset.x = x
		scissor.offset.y = y
		scissor.extent.width = width
		scissor.extent.height = height

		self.device.handle:cmdSetViewport(self.buffer.handle, 0, 1, viewport)
		self.device.handle:cmdSetScissor(self.buffer.handle, 0, 1, scissor)
	end
end

do
	local buffers = ffi.new("VkBuffer[1]")
	local offsets = ffi.new("VkDeviceSize[1]")

	---@param slot number
	---@param buffer hood.vk.Buffer
	---@param offset number?
	function VKCommandEncoder:setVertexBuffer(slot, buffer, offset)
		buffers[0] = buffer.handle
		offsets[0] = offset or 0
		self.device.handle:cmdBindVertexBuffers(self.buffer.handle, slot, 1, buffers, offsets)
	end
end

---@param buffer hood.vk.Buffer
---@param format hood.IndexFormat
---@param offset number?
function VKCommandEncoder:setIndexBuffer(buffer, format, offset)
	self.device.handle:cmdBindIndexBuffer(self.buffer.handle, buffer.handle, offset or 0,
		vkConversions.indexFormat[format])
end

---@param indexCount number
---@param instanceCount number
---@param firstIndex number?
---@param baseVertex number?
---@param firstInstance number?
function VKCommandEncoder:drawIndexed(indexCount, instanceCount, firstIndex, baseVertex, firstInstance)
	self.device.handle:cmdDrawIndexed(self.buffer.handle, indexCount, instanceCount or 1, firstIndex or 0,
		baseVertex or 0, firstInstance or 0)
end

local descriptorSetArray = vk.DescriptorSetArray(1)

---@param index number
---@param bindGroup hood.vk.BindGroup
function VKCommandEncoder:setBindGroup(index, bindGroup)
	local bindPoint, layout
	if self.pipeline then
		bindPoint = vk.PipelineBindPoint.GRAPHICS
		layout = self.pipeline.layout
	elseif self.computePipeline then
		bindPoint = vk.PipelineBindPoint.COMPUTE
		layout = self.computePipeline.layout
	else
		error("No pipeline set")
	end

	self.bindGroups[index] = bindGroup
	descriptorSetArray[0] = bindGroup.set

	self.device.handle:cmdBindDescriptorSets(
		self.buffer.handle,
		bindPoint,
		layout,
		index,
		1,
		descriptorSetArray,
		0
	)
end

function VKCommandEncoder:endRendering()
	self.device.handle:cmdEndRenderPass(self.buffer.handle)
end

---@param buffer hood.vk.Buffer
---@param size number
---@param data ffi.cdata*
---@param offset number?
function VKCommandEncoder:writeBuffer(buffer, size, data, offset)
	-- TODO: Use a staging buffer instead of this slop
	offset = offset or 0

	-- vkCmdUpdateBuffer is limited to 65536 bytes per call; chunk if needed
	local chunkSize = 65536
	local remaining = size
	local srcOffset = 0
	while remaining > 0 do
		local writeSize = math.min(remaining, chunkSize)
		self.device.handle:cmdUpdateBuffer(
			self.buffer.handle, buffer.handle, offset + srcOffset, writeSize,
			ffi.cast("const char*", data) + srcOffset)
		srcOffset = srcOffset + writeSize
		remaining = remaining - writeSize
	end
end

---@param stagingBuffer vk.ffi.Buffer
---@param stagingMemory vk.ffi.DeviceMemory
function VKCommandEncoder:_trackStagingResource(stagingBuffer, stagingMemory)
	if not self.buffer.stagingResources then
		self.buffer.stagingResources = {}
	end
	self.buffer.stagingResources[#self.buffer.stagingResources + 1] = {
		buffer = stagingBuffer,
		memory = stagingMemory,
	}
end

-- TODO: Completely rewrite this
---@param texture hood.vk.Texture
---@param descriptor hood.TextureWriteDescriptor
---@param data ffi.cdata*
function VKCommandEncoder:writeTexture(texture, descriptor, data)
	local width = descriptor.width
	local height = descriptor.height
	local depth = descriptor.depth or 1
	local dataSize = (descriptor.bytesPerRow or (width * 4)) * height * depth

	-- Create staging buffer
	local stagingBuffer = self.device.handle:createBuffer({
		size = dataSize,
		usage = vk.BufferUsageFlagBits.TRANSFER_SRC,
	})

	local memProps = vk.getPhysicalDeviceMemoryProperties(self.device.pd)
	local requiredFlags = bit.bor(vk.MemoryPropertyFlagBits.HOST_VISIBLE, vk.MemoryPropertyFlagBits.HOST_COHERENT)
	local memTypeIndex
	local requirements = self.device.handle:getBufferMemoryRequirements(stagingBuffer)
	local typeBits = requirements.memoryTypeBits
	local count = memProps.memoryTypeCount
	for i = 0, count - 1 do
		if (typeBits == 0 or bit.band(typeBits, bit.lshift(1, i)) ~= 0)
			and bit.band(memProps.memoryTypes[i].propertyFlags, requiredFlags) == requiredFlags then
			memTypeIndex = i
			break
		end
	end
	if not memTypeIndex then
		error("Failed to find host-visible memory type")
	end
	local stagingMemory = self.device.handle:allocateMemory({
		allocationSize = requirements.size,
		memoryTypeIndex = memTypeIndex,
	})
	self.device.handle:bindBufferMemory(stagingBuffer, stagingMemory, 0)

	-- Track staging resources for cleanup after GPU finishes
	self:_trackStagingResource(stagingBuffer, stagingMemory)

	-- Map, copy, unmap
	local mapped = self.device.handle:mapMemory(stagingMemory, 0, dataSize)
	ffi.copy(mapped, data + (descriptor.offset or 0), dataSize)
	self.device.handle:unmapMemory(stagingMemory)

	-- Transition image to TRANSFER_DST_OPTIMAL
	local mip = descriptor.mip or 0
	local layer = descriptor.layer or 0

	-- Use tracked layout if available, otherwise UNDEFINED for first use
	texture.layerLayouts = texture.layerLayouts or {}
	local oldLayout = texture.layerLayouts[layer] or vk.ImageLayout.UNDEFINED
	local srcAccessMask = 0
	local srcStage = vk.PipelineStageFlagBits.TOP_OF_PIPE
	if oldLayout == vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL then
		srcAccessMask = vk.AccessFlags.SHADER_READ
		srcStage = vk.PipelineStageFlagBits.FRAGMENT_SHADER
	end

	local barriers = vk.ImageMemoryBarrierArray(1)
	barriers[0].srcAccessMask = srcAccessMask
	barriers[0].dstAccessMask = vk.AccessFlags.TRANSFER_WRITE
	barriers[0].oldLayout = oldLayout
	barriers[0].newLayout = vk.ImageLayout.TRANSFER_DST_OPTIMAL
	barriers[0].srcQueueFamilyIndex = 0xFFFFFFFF -- VK_QUEUE_FAMILY_IGNORED
	barriers[0].dstQueueFamilyIndex = 0xFFFFFFFF
	barriers[0].image = texture.handle
	barriers[0].subresourceRange.aspectMask = vk.ImageAspectFlagBits.COLOR
	barriers[0].subresourceRange.baseMipLevel = mip
	barriers[0].subresourceRange.levelCount = 1
	barriers[0].subresourceRange.baseArrayLayer = layer
	barriers[0].subresourceRange.layerCount = 1

	self.device.handle:cmdPipelineBarrier(
		self.buffer.handle,
		srcStage,
		vk.PipelineStageFlagBits.TRANSFER,
		1, barriers)

	-- Copy buffer to image
	local region = vk.BufferImageCopyArray(1)
	region[0].bufferRowLength = descriptor.bytesPerRow and (descriptor.bytesPerRow / 4) or 0
	region[0].bufferImageHeight = descriptor.rowsPerImage or 0
	region[0].imageSubresource.aspectMask = vk.ImageAspectFlagBits.COLOR
	region[0].imageSubresource.mipLevel = mip
	region[0].imageSubresource.baseArrayLayer = layer
	region[0].imageSubresource.layerCount = 1
	region[0].imageExtent.width = width
	region[0].imageExtent.height = height
	region[0].imageExtent.depth = depth

	self.device.handle:cmdCopyBufferToImage(
		self.buffer.handle, stagingBuffer, texture.handle,
		vk.ImageLayout.TRANSFER_DST_OPTIMAL, 1, region)

	-- Transition image to SHADER_READ_ONLY_OPTIMAL
	barriers[0].srcAccessMask = vk.AccessFlags.TRANSFER_WRITE
	barriers[0].dstAccessMask = vk.AccessFlags.SHADER_READ
	barriers[0].oldLayout = vk.ImageLayout.TRANSFER_DST_OPTIMAL
	barriers[0].newLayout = vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL

	self.device.handle:cmdPipelineBarrier(
		self.buffer.handle,
		vk.PipelineStageFlagBits.TRANSFER,
		vk.PipelineStageFlagBits.FRAGMENT_SHADER,
		1, barriers)

	-- Track current layout per layer
	texture.layerLayouts[layer] = vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL
end

local copyBarrier = vk.ImageMemoryBarrierArray(1)

---@param source hood.ImageCopyTexture
---@param destination hood.ImageCopyBuffer
---@param copySize hood.Extent3D
function VKCommandEncoder:copyTextureToBuffer(source, destination, copySize)
	local texture = source.texture --[[@as hood.vk.Texture]]
	local buffer = destination.buffer --[[@as hood.vk.Buffer]]
	local mipLevel = source.mipLevel or 0
	local origin = source.origin or {}
	local layer = origin.z or 0

	texture.layerLayouts = texture.layerLayouts or {}
	local oldLayout = texture.layerLayouts[layer] or vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL

	local srcAccessMask = vk.AccessFlags.COLOR_ATTACHMENT_WRITE
	local srcStage = vk.PipelineStageFlagBits.COLOR_ATTACHMENT_OUTPUT
	if oldLayout == vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL then
		srcAccessMask = vk.AccessFlags.SHADER_READ
		srcStage = vk.PipelineStageFlagBits.FRAGMENT_SHADER
	end

	copyBarrier[0].srcAccessMask = srcAccessMask
	copyBarrier[0].dstAccessMask = vk.AccessFlags.TRANSFER_READ
	copyBarrier[0].oldLayout = oldLayout
	copyBarrier[0].newLayout = vk.ImageLayout.TRANSFER_SRC_OPTIMAL
	copyBarrier[0].srcQueueFamilyIndex = 0xFFFFFFFF
	copyBarrier[0].dstQueueFamilyIndex = 0xFFFFFFFF
	copyBarrier[0].image = texture.handle
	copyBarrier[0].subresourceRange.aspectMask = vk.ImageAspectFlagBits.COLOR
	copyBarrier[0].subresourceRange.baseMipLevel = mipLevel
	copyBarrier[0].subresourceRange.levelCount = 1
	copyBarrier[0].subresourceRange.baseArrayLayer = layer
	copyBarrier[0].subresourceRange.layerCount = 1

	self.device.handle:cmdPipelineBarrier(
		self.buffer.handle,
		srcStage,
		vk.PipelineStageFlagBits.TRANSFER,
		1, copyBarrier)

	local region = vk.BufferImageCopyArray(1)
	region[0].bufferOffset = destination.offset or 0
	region[0].bufferRowLength = destination.bytesPerRow and (destination.bytesPerRow / 4) or 0
	region[0].bufferImageHeight = destination.rowsPerImage or 0
	region[0].imageSubresource.aspectMask = vk.ImageAspectFlagBits.COLOR
	region[0].imageSubresource.mipLevel = mipLevel
	region[0].imageSubresource.baseArrayLayer = layer
	region[0].imageSubresource.layerCount = 1
	region[0].imageOffset.x = origin.x or 0
	region[0].imageOffset.y = origin.y or 0
	region[0].imageOffset.z = 0
	region[0].imageExtent.width = copySize.width
	region[0].imageExtent.height = copySize.height
	region[0].imageExtent.depth = copySize.depthOrArrayLayers or 1

	self.device.handle:cmdCopyImageToBuffer(
		self.buffer.handle, texture.handle,
		vk.ImageLayout.TRANSFER_SRC_OPTIMAL, buffer.handle, 1, region)

	-- Transition back so the next writeTexture on this layer sees the correct layout
	copyBarrier[0].srcAccessMask = vk.AccessFlags.TRANSFER_READ
	copyBarrier[0].dstAccessMask = vk.AccessFlags.SHADER_READ
	copyBarrier[0].oldLayout = vk.ImageLayout.TRANSFER_SRC_OPTIMAL
	copyBarrier[0].newLayout = vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL

	self.device.handle:cmdPipelineBarrier(
		self.buffer.handle,
		vk.PipelineStageFlagBits.TRANSFER,
		vk.PipelineStageFlagBits.FRAGMENT_SHADER,
		1, copyBarrier)

	texture.layerLayouts[layer] = vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL
end

local storageBarrier = vk.ImageMemoryBarrierArray(1)

---@param descriptor hood.ComputePassDescriptor
function VKCommandEncoder:beginComputePass(descriptor)
	for _, bindGroup in pairs(self.bindGroups) do
		for _, entry in ipairs(bindGroup.entries) do
			if entry.type == "storageTexture" then
				local view = entry.texture --[[@as hood.vk.TextureView]]
				local tex = view.texture
				local layer = view.baseArrayLayer
				tex.layerLayouts = tex.layerLayouts or {}
				local currentLayout = tex.layerLayouts[layer] or vk.ImageLayout.UNDEFINED
				if currentLayout ~= vk.ImageLayout.GENERAL then
					local srcAccess = 0
					local srcStage = vk.PipelineStageFlagBits.TOP_OF_PIPE
					if currentLayout == vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL then
						srcAccess = vk.AccessFlags.SHADER_READ
						srcStage = vk.PipelineStageFlagBits.FRAGMENT_SHADER
					end
					storageBarrier[0].srcAccessMask = srcAccess
					storageBarrier[0].dstAccessMask = vk.AccessFlags.SHADER_WRITE
					storageBarrier[0].oldLayout = currentLayout
					storageBarrier[0].newLayout = vk.ImageLayout.GENERAL
					storageBarrier[0].srcQueueFamilyIndex = 0xFFFFFFFF
					storageBarrier[0].dstQueueFamilyIndex = 0xFFFFFFFF
					storageBarrier[0].image = tex.handle
					storageBarrier[0].subresourceRange.aspectMask = vk.ImageAspectFlagBits.COLOR
					storageBarrier[0].subresourceRange.baseMipLevel = 0
					storageBarrier[0].subresourceRange.levelCount = 1
					storageBarrier[0].subresourceRange.baseArrayLayer = layer
					storageBarrier[0].subresourceRange.layerCount = view.layerCount
					self.device.handle:cmdPipelineBarrier(
						self.buffer.handle,
						srcStage,
						vk.PipelineStageFlagBits.COMPUTE_SHADER,
						1, storageBarrier)
					tex.layerLayouts[layer] = vk.ImageLayout.GENERAL
				end
			end
		end
	end
end

---@param pipeline hood.vk.ComputePipeline
function VKCommandEncoder:setComputePipeline(pipeline)
	self.computePipeline = pipeline
	self.pipeline = nil
	self.device.handle:cmdBindPipeline(self.buffer.handle, vk.PipelineBindPoint.COMPUTE, pipeline.handle)
end

---@param x number
---@param y number
---@param z number
function VKCommandEncoder:dispatchWorkgroups(x, y, z)
	self.device.handle:cmdDispatch(self.buffer.handle, x, y, z)
end

function VKCommandEncoder:endComputePass()
	-- Transition storage textures back to SHADER_READ_ONLY_OPTIMAL so the render pass can sample them
	for _, bindGroup in pairs(self.bindGroups) do
		for _, entry in ipairs(bindGroup.entries) do
			if entry.type == "storageTexture" then
				local view = entry.texture --[[@as hood.vk.TextureView]]
				local tex = view.texture
				local layer = view.baseArrayLayer
				tex.layerLayouts = tex.layerLayouts or {}
				local currentLayout = tex.layerLayouts[layer] or vk.ImageLayout.UNDEFINED
				if currentLayout ~= vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL then
					storageBarrier[0].srcAccessMask = vk.AccessFlags.SHADER_WRITE
					storageBarrier[0].dstAccessMask = vk.AccessFlags.SHADER_READ
					storageBarrier[0].oldLayout = currentLayout
					storageBarrier[0].newLayout = vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL
					storageBarrier[0].srcQueueFamilyIndex = 0xFFFFFFFF
					storageBarrier[0].dstQueueFamilyIndex = 0xFFFFFFFF
					storageBarrier[0].image = tex.handle
					storageBarrier[0].subresourceRange.aspectMask = vk.ImageAspectFlagBits.COLOR
					storageBarrier[0].subresourceRange.baseMipLevel = 0
					storageBarrier[0].subresourceRange.levelCount = 1
					storageBarrier[0].subresourceRange.baseArrayLayer = layer
					storageBarrier[0].subresourceRange.layerCount = view.layerCount
					self.device.handle:cmdPipelineBarrier(
						self.buffer.handle,
						vk.PipelineStageFlagBits.COMPUTE_SHADER,
						vk.PipelineStageFlagBits.FRAGMENT_SHADER,
						1, storageBarrier)
					tex.layerLayouts[layer] = vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL
				end
			end
		end
	end
end

function VKCommandEncoder:finish()
	self.device.handle:endCommandBuffer(self.buffer.handle)

	-- Transfer ownership of transient resources to the command buffer for deferred cleanup
	self.buffer.imageViews = self.imageViews
	self.buffer.framebuffers = self.framebuffers
	self.buffer.renderPasses = self.renderPasses
	self.buffer.swapchains = self.swapchains

	return self.buffer
end

return VKCommandEncoder
