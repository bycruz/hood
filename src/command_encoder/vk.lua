local ffi = require("ffi")
local vk = require("vkapi")
local hood = require("hood")

local VKCommandBuffer = require("hood.command_buffer.vk")

---@class hood.vk.CommandEncoder
---@field buffer hood.vk.CommandBuffer
---@field device hood.vk.Device
---@field pendingDescriptor hood.RenderPassDescriptor?
---@field imageViews vk.ffi.ImageView[]
---@field framebuffers vk.ffi.Framebuffer[]
local VKCommandEncoder = {}
VKCommandEncoder.__index = VKCommandEncoder

---@param device hood.vk.Device
---@return hood.vk.CommandEncoder
function VKCommandEncoder.new(device)
	local buffer = VKCommandBuffer.new(device)
	device.handle:beginCommandBuffer(buffer.handle)
	return setmetatable({
		device = device,
		buffer = buffer,
		imageViews = {},
		framebuffers = {},
	}, VKCommandEncoder)
end

---@param descriptor hood.RenderPassDescriptor
function VKCommandEncoder:beginRendering(descriptor)
	self.pendingDescriptor = descriptor
end

---@param pipeline hood.vk.Pipeline
function VKCommandEncoder:setPipeline(pipeline)
	if self.pendingDescriptor then
		self:_beginRenderPass(pipeline.renderPass, self.pendingDescriptor)
		self.pendingDescriptor = nil
	end

	self.device.handle:cmdBindPipeline(self.buffer.handle, vk.PipelineBindPoint.GRAPHICS, pipeline.handle)
end

---@param renderPass vk.ffi.RenderPass
---@param descriptor hood.RenderPassDescriptor
function VKCommandEncoder:_beginRenderPass(renderPass, descriptor)
	local colorAttachments = descriptor.colorAttachments or {}
	local depthAttachment = descriptor.depthStencilAttachment
	local totalAttachments = #colorAttachments + (depthAttachment and 1 or 0)

	local firstTexture = colorAttachments[1] and colorAttachments[1].texture
		or depthAttachment and depthAttachment.texture
	local width = firstTexture.width
	local height = firstTexture.height

	local imageViews = ffi.new("VkImageView[?]", totalAttachments)

	for i, att in ipairs(colorAttachments) do
		local iv = self.device.handle:createImageView({
			image = att.texture.handle,
			viewType = vk.ImageViewType.TYPE_2D,
			format = att.texture.format,
			subresourceRange = {
				aspectMask = vk.ImageAspectFlagBits.COLOR,
				baseMipLevel = 0,
				levelCount = 1,
				baseArrayLayer = 0,
				layerCount = 1,
			},
		})
		imageViews[i - 1] = iv
		self.imageViews[#self.imageViews + 1] = iv
	end

	if depthAttachment then
		local iv = self.device.handle:createImageView({
			image = depthAttachment.texture.handle,
			viewType = vk.ImageViewType.TYPE_2D,
			format = depthAttachment.texture.format,
			subresourceRange = {
				aspectMask = vk.ImageAspectFlagBits.DEPTH,
				baseMipLevel = 0,
				levelCount = 1,
				baseArrayLayer = 0,
				layerCount = 1,
			},
		})
		imageViews[totalAttachments - 1] = iv
		self.imageViews[#self.imageViews + 1] = iv
	end

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

local indexTypeMap = {
	[hood.IndexType.u16] = 0, -- VK_INDEX_TYPE_UINT16
	[hood.IndexType.u32] = 1, -- VK_INDEX_TYPE_UINT32
}

---@param buffer hood.vk.Buffer
---@param format hood.IndexFormat
---@param offset number?
function VKCommandEncoder:setIndexBuffer(buffer, format, offset)
	self.device.handle:cmdBindIndexBuffer(self.buffer.handle, buffer.handle, offset or 0, indexTypeMap[format])
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

---@param index number
---@param bindGroup hood.BindGroup
function VKCommandEncoder:setBindGroup(index, bindGroup)
	-- TODO: implement descriptor set binding for Vulkan
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
	local typeBits = tonumber(requirements.memoryTypeBits)
	local count = tonumber(memProps.memoryTypeCount)
	for i = 0, count - 1 do
		if (typeBits == 0 or bit.band(typeBits, bit.lshift(1, i)) ~= 0)
			and bit.band(tonumber(memProps.memoryTypes[i].propertyFlags), requiredFlags) == requiredFlags then
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
	local oldLayout = texture.currentLayout or vk.ImageLayout.UNDEFINED
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

	-- Track current layout
	texture.currentLayout = vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL
end

---@param descriptor hood.ComputePassDescriptor
function VKCommandEncoder:beginComputePass(descriptor)
end

---@param pipeline hood.vk.ComputePipeline
function VKCommandEncoder:setComputePipeline(pipeline)
	self.device.handle:cmdBindPipeline(self.buffer.handle, vk.PipelineBindPoint.COMPUTE, pipeline.handle)
end

---@param x number
---@param y number
---@param z number
function VKCommandEncoder:dispatchWorkgroups(x, y, z)
	self.device.handle:cmdDispatch(self.buffer.handle, x, y, z)
end

function VKCommandEncoder:endComputePass()
	-- Memory barrier to ensure compute writes are visible to subsequent passes
	local barrier = vk.MemoryBarrier({
		srcAccessMask = bit.bor(vk.AccessFlags.SHADER_READ, vk.AccessFlags.SHADER_WRITE),
		dstAccessMask = bit.bor(vk.AccessFlags.SHADER_READ, vk.AccessFlags.SHADER_WRITE,
			vk.AccessFlags.VERTEX_ATTRIBUTE_READ, vk.AccessFlags.INDEX_READ),
	})

	self.device.handle:cmdPipelineBarrier(
		self.buffer.handle,
		vk.PipelineStageFlagBits.COMPUTE_SHADER,
		bit.bor(vk.PipelineStageFlagBits.VERTEX_INPUT, vk.PipelineStageFlagBits.VERTEX_SHADER,
			vk.PipelineStageFlagBits.FRAGMENT_SHADER, vk.PipelineStageFlagBits.COMPUTE_SHADER),
		0, nil, 1, barrier)
end

function VKCommandEncoder:finish()
	self.device.handle:endCommandBuffer(self.buffer.handle)

	-- Transfer ownership of transient resources to the command buffer for deferred cleanup
	self.buffer.imageViews = self.imageViews
	self.buffer.framebuffers = self.framebuffers

	return self.buffer
end

return VKCommandEncoder
