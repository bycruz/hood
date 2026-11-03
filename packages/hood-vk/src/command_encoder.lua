local ffi = require("ffi")

local vk = require("vkapi") ---@cast vk vk & hood-vk.VkExtras
local vkConversions = require("hood-vk.convert")

local image = require("hood-vk.image")
local pass = require("hood-vk.pass")
local VKBuffer = require("hood-vk.buffer")
local VKCommandBuffer = require("hood-vk.command_buffer")

--- Staging starts here and grows to fit, so small uploads do not allocate per write.
local STAGING_MIN_SIZE = 256 * 1024

---@class hood-vk.CommandEncoder: hood.CommandEncoder
---@field buffer hood-vk.CommandBuffer
---@field device hood-vk.Device
---@field pendingDescriptor (hood.RenderPassDescriptor|hood-vk.ReusablePass)?
---@field pipeline hood-vk.Pipeline?
---@field computePipeline hood-vk.ComputePipeline?
---@field bindGroups table<number, hood-vk.BindGroup>
---@field _attachments { texture: hood-vk.Texture, finalLayout: number }[] # Where the pass leaves each attachment
---@field bufferCopy vk.ffi.BufferCopy[] scratch for vkCmdCopyBuffer regions
---@field memoryBarrier vk.ffi.MemoryBarrier[] scratch for _flushStagedWrites
---@field depthBarrier vk.ffi.ImageMemoryBarrier[] scratch for endRendering
---@field stagedWrites boolean true while a staged copy is waiting to be made visible
---@field inRenderPass boolean true between beginRendering and endRendering
---@field sampleableDepth hood-vk.Texture?
---@field sampleableDepthLayers number?
---@field _swapchain hood-vk.Swapchain?
---@field _reusableRpDesc hood-vk.ReusablePass?
local VKCommandEncoder = {}
VKCommandEncoder.__index = VKCommandEncoder

local beginInfo = vk.CommandBufferBeginInfo({})

-- Reused across frames: allocating these per frame is FFI churn on the hot path.
local _reusableClearValues = vk.ClearValueArray(1)
local _reusableBeginInfo = vk.RenderPassBeginInfo()
local _reusableImageViews = ffi.new("VkImageView[1]")

-- The colour + depth case, which is what a depth-tested pass uses.
local _reusableClearValues2 = vk.ClearValueArray(2)

---@param device hood-vk.Device
---@param reuseBuffer hood-vk.CommandBuffer? reset and reused rather than allocating a new one
---@return hood-vk.CommandEncoder
function VKCommandEncoder.new(device, reuseBuffer)
	local buffer = reuseBuffer or VKCommandBuffer.new(device)

	if reuseBuffer then
		buffer:reset()
	end

	device.handle:beginCommandBuffer(buffer.handle, beginInfo)

	-- Swapchain command buffers are kept per frame slot, so the encoder's tables live as long
	-- as the swapchain rather than being rebuilt every frame.
	local encoder = buffer._encoder
	if encoder then
		encoder.pendingDescriptor = nil
		encoder.pipeline = nil
		encoder.inRenderPass = false
		encoder.computePipeline = nil
		encoder._swapchain = nil
		encoder.sampleableDepth = nil
		encoder.sampleableDepthLayers = nil

		-- Only compute passes consult bind groups, and only a pass that wrote an attachment
		-- records one, so emptying them here costs nothing on the render-only path.
		if next(encoder.bindGroups) ~= nil then
			encoder.bindGroups = {}
		end

		if #encoder._attachments ~= 0 then
			encoder._attachments = {}
		end

		return encoder
	end

	encoder = setmetatable({
		device = device,
		buffer = buffer,
		bindGroups = {},
		_attachments = {},
		bufferCopy = vk.BufferCopyArray(1),
		memoryBarrier = vk.MemoryBarrierArray(1),
		depthBarrier = vk.ImageMemoryBarrierArray(1),
		inRenderPass = false,
		stagedWrites = false,
		sampleableDepth = nil,
		sampleableDepthLayers = nil,
		_swapchain = nil,
	}, VKCommandEncoder)
	buffer._encoder = encoder
	return encoder
end

--- Begin a render pass, from a descriptor or from a single texture view and clear colour.
---@overload fun(self: hood-vk.CommandEncoder, textureView: hood-vk.TextureView, clearColor?: { r: number, g: number, b: number, a: number })
---@overload fun(self: hood-vk.CommandEncoder, descriptor: hood.RenderPassDescriptor)
---@param self hood-vk.CommandEncoder
---@param descriptor hood.RenderPassDescriptor
---@param clearColor { r: number, g: number, b: number, a: number }?
function VKCommandEncoder:beginRendering(descriptor, clearColor)
	local fullDescriptor = descriptor --[[@as hood.RenderPassDescriptor]]
	if fullDescriptor and fullDescriptor.colorAttachments then
		-- Full descriptor table (backward compatible)
		self.pendingDescriptor = fullDescriptor
	else
		---@cast descriptor hood-vk.TextureView
		-- The descriptor table is built once and reused, so this path allocates nothing.
		local d = self._reusableRpDesc
		if not d then
			local clear = { r = 0, g = 0, b = 0, a = 1 }
			local op = { type = "clear", color = clear }
			d = {
				colorAttachments = { {
					op = op,
					texture = nil,
				} },
			}
			self._reusableRpDesc = d
		end
		d.colorAttachments[1].texture = descriptor
		if clearColor then
			local c = d.colorAttachments[1].op.color
			c.r = clearColor.r
			c.g = clearColor.g
			c.b = clearColor.b
			c.a = clearColor.a
		end
		self.pendingDescriptor = d
	end
end

---@param pipeline hood-vk.Pipeline
---@param self hood-vk.CommandEncoder
function VKCommandEncoder:setPipeline(pipeline)
	if self.pendingDescriptor then
		self:_beginRenderPass(self.pendingDescriptor)
		self.pendingDescriptor = nil
	end

	self.pipeline = pipeline
	self.device.handle:cmdBindPipeline(self.buffer.handle, vk.PipelineBindPoint.GRAPHICS, pipeline.handle)
end

---@param descriptor hood.RenderPassDescriptor|hood-vk.ReusablePass
---@param self hood-vk.CommandEncoder
function VKCommandEncoder:_beginRenderPass(descriptor)
	-- Anything staged earlier has to be visible before the first draw reads it.
	self:_flushStagedWrites()

	local colorAttachments = descriptor.colorAttachments or {}
	local depthAttachment = descriptor.depthStencilAttachment
	local totalAttachments = #colorAttachments + (depthAttachment and 1 or 0)

	-- This only describes the attachments; pass.define finds or creates the pass.
	local colorSpecs = {}
	local depthSpec = nil
	local imageViews = totalAttachments == 1 and _reusableImageViews
		or ffi.new("VkImageView[?]", totalAttachments)
	local handles = {}
	local width, height = nil, nil

	for i = 1, #colorAttachments do
		local att = colorAttachments[i]
		local view = att.texture --[[@as hood-vk.TextureView]]
		local texture = view.texture
		local isSwapchain = texture.isSwapchain == true
		local initialLayout, finalLayout = image.passLayouts(view, isSwapchain, att.op)

		if isSwapchain then
			self._swapchain = texture.swapchain
		end
		imageViews[i - 1] = view.handle

		colorSpecs[i] = {
			format = texture.format,
			loadOp = att.op.type == "clear" and vk.AttachmentLoadOp.CLEAR or vk.AttachmentLoadOp.LOAD,
			initialLayout = initialLayout,
			finalLayout = finalLayout,
			sampled = finalLayout == vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL,
		}

		-- A swapchain image is identified by its index, not its handle: the swapchain turns
		-- them over.
		handles[i] = isSwapchain and (texture.swapchainImageIdx or 0) or texture.handle

		self._attachments[#self._attachments + 1] = { texture = texture, finalLayout = finalLayout }
		width, height = texture.width, texture.height
	end

	if depthAttachment then
		local view = depthAttachment.texture --[[@as hood-vk.TextureView]]
		local texture = view.texture
		local initialLayout, finalLayout = image.passLayouts(view, false, depthAttachment.op)

		imageViews[totalAttachments - 1] = view.handle
		handles[totalAttachments] = texture.handle

		depthSpec = {
			format = texture.format,
			loadOp = depthAttachment.op.type == "clear" and vk.AttachmentLoadOp.CLEAR or vk.AttachmentLoadOp.LOAD,
			initialLayout = initialLayout,
			finalLayout = finalLayout,
			sampled = finalLayout == vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL,
		}

		-- This one's writes are made visible after the pass; see endRendering.
		if finalLayout == vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL then
			self.sampleableDepth = texture
			self.sampleableDepthLayers = view.layerCount
		end

		self._attachments[#self._attachments + 1] = { texture = texture, finalLayout = finalLayout }
		width, height = width or texture.width, height or texture.height
	end

	assert(width ~= nil)
	assert(height ~= nil)
	local renderPass = pass.define(self.device, colorSpecs, depthSpec)
	local swapchain = self._swapchain

	local framebuffer
	if swapchain and swapchain.currentVkImageIdx ~= nil then
		-- The swapchain keeps its own framebuffers, and its depth view can change per frame.
		local depthView = depthAttachment and (depthAttachment.texture --[[@as hood-vk.TextureView]]).handle or nil
		framebuffer = swapchain:getFramebuffer(renderPass, width, height, depthView)
	else
		framebuffer = pass.framebuffer(self.device, renderPass, imageViews, handles, width, height)
	end

	local clearValues
	if totalAttachments == 1 then
		clearValues = _reusableClearValues
	elseif totalAttachments == 2 then
		clearValues = _reusableClearValues2
	else
		clearValues = vk.ClearValueArray(totalAttachments)
	end

	for i = 1, #colorAttachments do
		local att = colorAttachments[i]
		if att.op.type == "clear" then
			local c = att.op.color
			local v = clearValues[i - 1].color.float32
			v[0] = c.r
			v[1] = c.g
			v[2] = c.b
			v[3] = c.a
		end
	end

	if depthAttachment and depthAttachment.op.type == "clear" then
		local ds = clearValues[totalAttachments - 1].depthStencil
		ds.depth = depthAttachment.op.depth
		ds.stencil = 0
	end

	local beginInfo = _reusableBeginInfo
	beginInfo.renderPass = renderPass
	beginInfo.framebuffer = framebuffer
	beginInfo.renderArea.offset.x = 0
	beginInfo.renderArea.offset.y = 0
	beginInfo.renderArea.extent.width = width
	beginInfo.renderArea.extent.height = height
	beginInfo.clearValueCount = totalAttachments
	beginInfo.pClearValues = clearValues

	-- The pass is recorded now, so every attachment is where the pass leaves it.
	for _, attachment in ipairs(self._attachments) do
		attachment.texture.layout = attachment.finalLayout
	end

	self:_beginRenderPassRaw(beginInfo)
end

do
	local viewport = vk.Viewport()
	local scissor = vk.Rect2D()

	---@param x number
	---@param y number
	---@param width number
	---@param height number
---@param self hood-vk.CommandEncoder
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
	---@param buffer hood-vk.Buffer
	---@param offset number?
---@param self hood-vk.CommandEncoder
	function VKCommandEncoder:setVertexBuffer(slot, buffer, offset)
		buffers[0] = buffer.handle
		offsets[0] = offset or 0
		self.device.handle:cmdBindVertexBuffers(self.buffer.handle, slot, 1, buffers, offsets)
	end
end

---@param buffer hood-vk.Buffer
---@param format hood.IndexFormat
---@param offset number?
function VKCommandEncoder:setIndexBuffer(buffer, format, offset)
	self.device.handle:cmdBindIndexBuffer(self.buffer.handle, buffer.handle, offset or 0, vkConversions.indexFormat[format])
end

---@param indexCount number
---@param instanceCount number
---@param firstIndex number?
---@param baseVertex number?
---@param firstInstance number?
---@param self hood-vk.CommandEncoder
function VKCommandEncoder:drawIndexed(indexCount, instanceCount, firstIndex, baseVertex, firstInstance)
	self.device.handle:cmdDrawIndexed(self.buffer.handle, indexCount, instanceCount or 1,
		firstIndex or 0, baseVertex or 0, firstInstance or 0)
end

---@param vertexCount number
---@param instanceCount number
---@param firstVertex number?
---@param firstInstance number?
function VKCommandEncoder:draw(vertexCount, instanceCount, firstVertex, firstInstance)
	self.device.handle:cmdDraw(self.buffer.handle, vertexCount, instanceCount or 1, firstVertex or 0, firstInstance or 0)
end

local descriptorSetArray = vk.DescriptorSetArray(1)

--- Move a freshly created texture's subresources into the layout a descriptor names.
---
--- A descriptor covers the whole view, so every layer has to be in that layout -- including the
--- ones nothing was written to, which would otherwise sample as empty.
---
--- Done at creation because that is the only point outside a render pass, where this barrier is
--- legal to record.
---@param texture hood-vk.Texture
---@return boolean claimed
---@param self hood-vk.CommandEncoder
function VKCommandEncoder:claimTexture(texture)
	-- A depth image is put in the layout a shader reads by the pass that writes it instead.
	if texture.isDepth then
		return false
	end

	-- VUID-VkImageMemoryBarrier-oldLayout-01211: SHADER_READ_ONLY_OPTIMAL requires the SAMPLED
	-- usage, and attachment layouts belong to the render pass.
	if bit.band(texture.usage, vk.ImageUsageFlagBits.SAMPLED) == 0 then
		return false
	end

	return image.transition(self.device, self.buffer.handle, texture,
		vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL, vk.PipelineStageFlagBits.FRAGMENT_SHADER,
		vk.AccessFlags.SHADER_READ)
end

---@param index number
---@param bindGroup hood-vk.BindGroup
---@param self hood-vk.CommandEncoder
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

	self.device.handle:cmdBindDescriptorSets(self.buffer.handle, bindPoint, layout, index, 1, descriptorSetArray, 0)
end

--- End the open render pass.
---
--- A pass only starts when a pipeline is bound, so an end without one means the frame never
--- began a pass. Drivers do not validate that: they execute a command buffer whose pass never
--- started, which is a segfault rather than an error.
---@param self hood-vk.CommandEncoder
function VKCommandEncoder:endRendering()
	if not self.inRenderPass then
		error("hood: endRendering was called with no open render pass; a pass is "
			.. "started by setPipeline, so bind the pipeline before drawing, even "
			.. "for a frame with nothing in it")
	end

	self.inRenderPass = false
	self.device.handle:cmdEndRenderPass(self.buffer.handle)

	-- Make a sampled depth attachment's writes visible. The pass cannot record this itself:
	-- barriers are not recordable within a render pass.
	local depth = self.sampleableDepth
	if depth then
		image.barrier(self.device, self.buffer.handle, self.depthBarrier, depth,
			vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL,
			vk.PipelineStageFlagBits.LATE_FRAGMENT_TESTS,
			vk.AccessFlags.DEPTH_STENCIL_ATTACHMENT_WRITE,
			vk.AccessFlags.SHADER_READ,
			vk.PipelineStageFlagBits.FRAGMENT_SHADER,
			vk.ImageAspectFlagBits.DEPTH,
			self.sampleableDepthLayers or 1)

		self.sampleableDepth = nil
		self.sampleableDepthLayers = nil
	end
end

--- Begin the pass, refusing to nest one inside another: a second vkCmdBeginRenderPass before
--- the matching end is a driver crash rather than a reportable error.
---@param beginInfo vk.ffi.RenderPassBeginInfo
---@private
---@param self hood-vk.CommandEncoder
function VKCommandEncoder:_beginRenderPassRaw(beginInfo)
	if self.inRenderPass then
		error("hood: beginRendering was called while a render pass is already open")
	end

	self.inRenderPass = true
	self.device.handle:cmdBeginRenderPass(self.buffer.handle, beginInfo, vk.SubpassContents.INLINE)
end

--- Make staged uploads visible to the commands that read them.
---
--- A copy into a buffer a later draw reads is a transfer write followed by a read with no
--- dependency between them: undefined behaviour, reported as SYNC-HAZARD-READ-AFTER-WRITE.
---
--- One barrier covers everything staged so far, emitted when the reads are about to start.
---@private
---@param self hood-vk.CommandEncoder
function VKCommandEncoder:_flushStagedWrites()
	if not self.stagedWrites then
		return
	end
	self.stagedWrites = false

	local barrier = self.memoryBarrier[0]
	barrier.srcAccessMask = vk.AccessFlags.TRANSFER_WRITE
	barrier.dstAccessMask = assert(tonumber(bit.bor(
		vk.AccessFlags.MEMORY_READ,
		vk.AccessFlags.INDEX_READ,
		vk.AccessFlags.VERTEX_ATTRIBUTE_READ,
		vk.AccessFlags.UNIFORM_READ,
		vk.AccessFlags.SHADER_READ,
		vk.AccessFlags.INDIRECT_COMMAND_READ)))

	-- Only legal outside a render pass, where the stage masks may name any stage.
	self.device.handle:cmdPipelineBarrier(self.buffer.handle, vk.PipelineStageFlagBits.TRANSFER,
		vk.PipelineStageFlagBits.ALL_COMMANDS, 0, nil, 1, self.memoryBarrier)
end

--- Hand out `size` bytes of staging memory for this command buffer, growing the buffer as
--- needed.
---
--- It lives on the command buffer rather than the encoder because the copies recorded out of it
--- finish only when the command buffer retires. Swapchain command buffers are reused per frame
--- slot and the slot waits its fence before re-recording, so the same allocation is safely
--- reused; a one-shot buffer frees it with everything else.
---
--- Sized to fit rather than rounded up: an upload of a picture is one of these, and doubling a
--- four megabyte one to eight is memory a driver may not have to spare.
---@param size number
---@return hood-vk.Buffer staging
---@private
---@param self hood-vk.CommandEncoder
function VKCommandEncoder:_staging(size)
	local staging = self.buffer.stagingBuffer

	if staging then
		if staging.staging ~= nil and staging.staging.offset + size <= staging.descriptor.size then
			return staging
		end

		-- Recorded copies still reference it, so it survives until the buffer is recycled.
		local resources = self.buffer.stagingResources or {}
		self.buffer.stagingResources = resources
		table.insert(resources, staging)
	end

	local capacity = math.max(STAGING_MIN_SIZE, (staging and staging.staging and staging.staging.offset or 0) + size)
	staging = VKBuffer.new(self.device, {
		size = capacity,
		usages = { "COPY_SRC" },
		mapped = true,
	})
	staging.staging = { offset = 0 }
	self.buffer.stagingBuffer = staging

	return staging
end

--- Upload CPU data into a buffer.
---
--- A mapped buffer is written straight by the CPU with nothing submitted, which is the path
--- per-frame data should take. Everything else goes through staging and vkCmdCopyBuffer, which
--- has no alignment or size restrictions unlike vkCmdUpdateBuffer.
---@param buffer hood-vk.Buffer
---@param size number
---@param data ffi.cdata*
---@param offset number?
---@param self hood-vk.CommandEncoder
function VKCommandEncoder:writeBuffer(buffer, size, data, offset)
	offset = offset or 0
	if size == 0 then
		return
	end

	buffer:assertWriteFits(size, offset, data)

	if buffer.isMapped then
		ffi.copy(buffer:mappedPointer(offset), data, size)
		return
	end

	local staging = self:_staging(size)
	local stagingOffset = staging.staging.offset

	ffi.copy(staging:mappedPointer(stagingOffset), data, size)
	staging.staging.offset = stagingOffset + size

	local region = self.bufferCopy[0]
	region.srcOffset = stagingOffset
	region.dstOffset = offset
	region.size = size

	self.device.handle:cmdCopyBuffer(self.buffer.handle, staging.handle, buffer.handle, 1, self.bufferCopy)

	self.stagedWrites = true
end

--- Issue `drawCount` indexed draws recorded in `buffer`, one command every `stride` bytes from
--- `offset`.
---
--- Every draw shares the bound vertex and index buffers, selecting its geometry through
--- firstIndex and vertexOffset, so a frame's instanced draws go out as one call for 20 bytes
--- each instead of a command apiece.
---
--- The buffer needs INDIRECT, and a nonzero firstInstance needs the drawIndirectFirstInstance
--- feature.
---@param buffer hood-vk.Buffer
---@param offset number
---@param drawCount number
---@param stride number
---@param self hood-vk.CommandEncoder
function VKCommandEncoder:drawIndexedIndirect(buffer, offset, drawCount, stride)
	self.device.handle:cmdDrawIndexedIndirect(self.buffer.handle, buffer.handle, offset or 0, drawCount, stride)
end

--- Copy bytes between two buffers on the GPU. The source needs COPY_SRC and the destination
--- COPY_DST. Vulkan only: it would need glCopyNamedBufferSubData on the OpenGL backend.
---@param source hood-vk.Buffer
---@param destination hood-vk.Buffer
---@param size number
---@param sourceOffset number?
---@param destinationOffset number?
function VKCommandEncoder:copyBuffer(source, destination, size, sourceOffset, destinationOffset)
	sourceOffset = sourceOffset or 0
	destinationOffset = destinationOffset or 0
	if size == 0 then
		return
	end

	-- Both the read and the write have to stay inside their own buffer.
	source:assertWriteFits(size, sourceOffset)
	destination:assertWriteFits(size, destinationOffset)

	local region = self.bufferCopy[0]
	region.srcOffset = sourceOffset
	region.dstOffset = destinationOffset
	region.size = size

	self.device.handle:cmdCopyBuffer(self.buffer.handle, source.handle, destination.handle, 1, self.bufferCopy)
	self.stagedWrites = true
end

---@param texture hood-vk.Texture
---@param descriptor hood.TextureWriteDescriptor
---@param data ffi.cdata*
---@param self hood-vk.CommandEncoder
function VKCommandEncoder:writeTexture(texture, descriptor, data)
	local width = descriptor.width
	local height = descriptor.height
	local depth = descriptor.depth or 1
	local dataSize = (descriptor.bytesPerRow or (width * 4)) * height * depth

	local staging = self:_staging(dataSize)
	local stagingOffset = staging.staging.offset

	ffi.copy(staging:mappedPointer(stagingOffset), data + (descriptor.offset or 0), dataSize)
	-- Rounded up to 4: a vkCmdCopyBufferToImage source offset must be a multiple of 4.
	staging.staging.offset = stagingOffset + math.ceil(dataSize / 4) * 4

	local mip = descriptor.mip or 0
	local layer = descriptor.layer or 0

	image.transition(self.device, self.buffer.handle, texture,
		vk.ImageLayout.TRANSFER_DST_OPTIMAL, vk.PipelineStageFlagBits.TRANSFER, vk.AccessFlags.TRANSFER_WRITE)

	-- Points at this upload's slice of staging, not the start of it.
	local region = vk.BufferImageCopyArray(1)
	region[0].bufferOffset = stagingOffset
	region[0].bufferRowLength = descriptor.bytesPerRow and (descriptor.bytesPerRow / 4) or 0
	region[0].bufferImageHeight = descriptor.rowsPerImage or 0
	region[0].imageSubresource.aspectMask = vk.ImageAspectFlagBits.COLOR
	region[0].imageSubresource.mipLevel = mip
	region[0].imageSubresource.baseArrayLayer = layer
	region[0].imageSubresource.layerCount = 1
	region[0].imageExtent.width = width
	region[0].imageExtent.height = height
	region[0].imageExtent.depth = depth

	self.device.handle:cmdCopyBufferToImage(self.buffer.handle, staging.handle, texture.handle,
		vk.ImageLayout.TRANSFER_DST_OPTIMAL, 1, region)

	image.transition(self.device, self.buffer.handle, texture, vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL,
		vk.PipelineStageFlagBits.FRAGMENT_SHADER, vk.AccessFlags.SHADER_READ)
end

---@param source hood.ImageCopyTexture
---@param destination hood.ImageCopyBuffer
---@param copySize hood.Extent3D
---@param self hood-vk.CommandEncoder
function VKCommandEncoder:copyTextureToBuffer(source, destination, copySize)
	local texture = source.texture --[[@as hood-vk.Texture]]
	local buffer = destination.buffer --[[@as hood-vk.Buffer]]
	local mipLevel = source.mipLevel or 0
	local origin = source.origin or {}
	local layer = origin.z or 0

	image.transition(self.device, self.buffer.handle, texture,
		vk.ImageLayout.TRANSFER_SRC_OPTIMAL, vk.PipelineStageFlagBits.TRANSFER, vk.AccessFlags.TRANSFER_READ)

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

	self.device.handle:cmdCopyImageToBuffer(self.buffer.handle, texture.handle,
		vk.ImageLayout.TRANSFER_SRC_OPTIMAL, buffer.handle, 1, region)

	-- Back to this texture's resting layout: a readback target is not necessarily samplable.
	image.transition(self.device, self.buffer.handle, texture, image.restingLayout(texture),
		vk.PipelineStageFlagBits.FRAGMENT_SHADER, vk.AccessFlags.SHADER_READ)
end

---@param descriptor hood.ComputePassDescriptor
---@param self hood-vk.CommandEncoder
function VKCommandEncoder:beginComputePass(descriptor)
	-- Staged writes have to be visible before the dispatch reads them.
	self:_flushStagedWrites()

	-- A descriptor names one layout for the whole view, and a storage image needs GENERAL.
	image.eachStorageTexture(self.bindGroups, function(texture)
		image.transition(self.device, self.buffer.handle, texture,
			vk.ImageLayout.GENERAL, vk.PipelineStageFlagBits.COMPUTE_SHADER, vk.AccessFlags.SHADER_WRITE)
	end)
end

---@param pipeline hood-vk.ComputePipeline
---@param self hood-vk.CommandEncoder
function VKCommandEncoder:setComputePipeline(pipeline)
	---@cast pipeline hood-vk.ComputePipeline
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

---@param self hood-vk.CommandEncoder
function VKCommandEncoder:endComputePass()
	-- Back to the layout a render pass samples from, so the same texture can be drawn with.
	image.eachStorageTexture(self.bindGroups, function(texture)
		image.transition(self.device, self.buffer.handle, texture,
			vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL, vk.PipelineStageFlagBits.FRAGMENT_SHADER,
			vk.AccessFlags.SHADER_READ)
	end)
end

function VKCommandEncoder:finish()
	if self.inRenderPass then
		error("hood: finish() was called with a render pass still open; endRendering() first")
	end

	self.device.handle:endCommandBuffer(self.buffer.handle)
	self.buffer._swapchain = self._swapchain

	return self.buffer
end

return VKCommandEncoder
