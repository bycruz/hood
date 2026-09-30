local ffi = require("ffi")

local vk = require("vkapi")
local vkConversions = require("hood-vk.convert")

local image = require("hood-vk.image")
local VKBuffer = require("hood-vk.buffer")
local VKCommandBuffer = require("hood-vk.command_buffer")

--- Staging allocations start at this size and grow to fit what is written, so a frame
--- that uploads a few small uniform blocks does not allocate per write.
local STAGING_MIN_SIZE = 256 * 1024

---@class hood-vk.CommandEncoder
---@field buffer hood-vk.CommandBuffer
---@field device hood-vk.Device
---@field pendingDescriptor any
---@field pipeline hood-vk.Pipeline?
---@field computePipeline hood-vk.ComputePipeline?
---@field bindGroups table<number, hood-vk.BindGroup>
---@field _attachments { texture: hood-vk.Texture, finalLayout: vk.ImageLayout }[] # Where the pass leaves each attachment
---@field bufferCopy vk.ffi.BufferCopy[] scratch for vkCmdCopyBuffer regions
---@field memoryBarrier vk.ffi.MemoryBarrier[] scratch for _flushStagedWrites
---@field depthBarrier vk.ffi.ImageMemoryBarrier[] scratch for endRendering
---@field stagedWrites boolean true while a staged copy is waiting to be made visible
---@field inRenderPass boolean true between beginRendering and endRendering
---@field sampleableDepth hood-vk.Texture?
---@field sampleableDepthLayers number?
---@field _swapchain hood-vk.Swapchain?
---@field _reusableRpDesc table?
local VKCommandEncoder = {}
VKCommandEncoder.__index = VKCommandEncoder

local beginInfo = vk.CommandBufferBeginInfo({})

-- Pre-allocated working buffers for the common single-attachment case.
-- These are reused across frames to avoid per-frame FFI allocation.
local _reusableClearValues = vk.ClearValueArray(1)
local _reusableBeginInfo = vk.RenderPassBeginInfo()
local _reusableImageViews = ffi.new("VkImageView[1]")

-- Same idea for the two-attachment case (colour + depth), which is what a
-- depth-tested 2D/3D pass uses.
local _reusableClearValues2 = vk.ClearValueArray(2)

---@param device hood-vk.Device
---@param reuseBuffer hood-vk.CommandBuffer? If provided, the buffer is reset and reused instead of allocating a new one.
---@return hood-vk.CommandEncoder
function VKCommandEncoder.new(device, reuseBuffer)
	local buffer
	if reuseBuffer then
		buffer = reuseBuffer
		buffer:reset()
	else
		buffer = VKCommandBuffer.new(device)
	end
	device.handle:beginCommandBuffer(buffer.handle, beginInfo)

	-- Reuse the encoder owned by this command buffer. Command buffers are
	-- pre-allocated per swapchain image, so the encoder and its tracking tables
	-- live as long as the swapchain instead of being allocated every frame.
	local encoder = buffer._encoder
	if encoder then
		encoder.pendingDescriptor = nil
		encoder.pipeline = nil
		encoder.inRenderPass = false
		encoder.computePipeline = nil
		encoder._swapchain = nil
		encoder.sampleableDepth = nil
		encoder.sampleableDepthLayers = nil

		-- Bind groups are only consulted by compute passes and attachment layouts by the end of
		-- a pass, so stale entries are dropped only where they were recorded. This costs
		-- nothing on the render-only path.
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

--- Begin a render pass.
--- Two calling conventions:
---   1. Full descriptor table: encoder:beginRendering({ colorAttachments = {...} })
---   2. Simple single-attachment: encoder:beginRendering(textureView, clearColor?)
---       where textureView is a hood-vk.TextureView. The descriptor tables are
---       allocated once and reused internally, avoiding per-frame table churn.
---@overload fun(self, textureView: hood-vk.TextureView, clearColor?: { r: number, g: number, b: number, a: number })
---@overload fun(self, descriptor: hood.RenderPassDescriptor)
function VKCommandEncoder:beginRendering(descriptor, clearColor)
	if descriptor and descriptor.colorAttachments then
		-- Full descriptor table (backward compatible)
		self.pendingDescriptor = descriptor
	else
		-- Simple path: descriptor is a TextureView, clearColor is optional.
		-- Use a reusable descriptor stored on the encoder to avoid allocation.
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
function VKCommandEncoder:setPipeline(pipeline)
	if self.pendingDescriptor then
		self:_beginRenderPass(pipeline, self.pendingDescriptor)
		self.pendingDescriptor = nil
	end

	self.pipeline = pipeline
	self.device.handle:cmdBindPipeline(self.buffer.handle, vk.PipelineBindPoint.GRAPHICS, pipeline.handle)
end

---@param pipeline hood-vk.Pipeline
---@param descriptor hood.RenderPassDescriptor
function VKCommandEncoder:_beginRenderPass(pipeline, descriptor)
	-- Anything staged earlier has to be visible before the first draw reads it.
	self:_flushStagedWrites()

	local colorAttachments = descriptor.colorAttachments or {}
	local depthAttachment = descriptor.depthStencilAttachment
	local totalAttachments = #colorAttachments + (depthAttachment and 1 or 0)

	local width, height
	if colorAttachments[1] then
		local view = colorAttachments[1].texture --[[@as hood-vk.TextureView]]
		width, height = view.texture.width, view.texture.height
	elseif depthAttachment then
		local view = depthAttachment.texture --[[@as hood-vk.TextureView]]
		width, height = view.texture.width, view.texture.height
	end

	-- Detect if the first color attachment is a swapchain texture, so we can
	-- use pre-created image views and cached framebuffers from the swapchain.
	local swapchainForFB = nil
	if colorAttachments[1] then
		local view = colorAttachments[1].texture --[[@as hood-vk.TextureView]]
		if view.texture and view.texture.isSwapchain and view.texture.swapchain then
			swapchainForFB = view.texture.swapchain
		end
	end

	-- Fast path: rendering into the swapchain with the render pass already
	-- cached. Everything below only exists to *create* the render pass and its
	-- framebuffer, so on a cache hit we skip all of it (no tables, no loops,
	-- no per-frame allocation) and go straight to vkCmdBeginRenderPass.
	--
	-- This covers any attachment count, including the colour + depth pass lupa
	-- uses; previously it was limited to a single colour attachment, which made
	-- every depth-attached frame rebuild two attachment tables and create and
	-- destroy a VkFramebuffer.
	if swapchainForFB and swapchainForFB._cachedRenderPass then
		self._swapchain = swapchainForFB

		local renderPass = swapchainForFB._cachedRenderPass

		local depthView = nil
		if depthAttachment then
			depthView = depthAttachment.texture.handle
		end
		local framebuffer = swapchainForFB:getFramebuffer(renderPass, width, height, depthView)

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

		self:_beginRenderPassRaw(beginInfo)
		return
	end

	local imageViews
	if totalAttachments == 1 then
		imageViews = _reusableImageViews
	else
		imageViews = ffi.new("VkImageView[?]", totalAttachments)
	end
	local attachmentDescs = {}
	local colorRefs = {}

	for i = 1, #colorAttachments do
		local att = colorAttachments[i]
		local view = att.texture --[[@as hood-vk.TextureView]]
		local texture = view.texture
		local isSwapchain = texture.isSwapchain == true

		if isSwapchain and texture.swapchain then
			self._swapchain = texture.swapchain
		end
		imageViews[i - 1] = view.handle

		local initialLayout, finalLayout = image.passLayouts(view, isSwapchain, att.op)

		attachmentDescs[#attachmentDescs + 1] = {
			format = texture.format,
			samples = vk.SampleCountFlagBits.COUNT_1,
			loadOp = att.op.type == "clear" and vk.AttachmentLoadOp.CLEAR or vk.AttachmentLoadOp.LOAD,
			storeOp = vk.AttachmentStoreOp.STORE,
			stencilLoadOp = vk.AttachmentLoadOp.DONT_CARE,
			stencilStoreOp = vk.AttachmentStoreOp.DONT_CARE,
			initialLayout = initialLayout,
			finalLayout = finalLayout,
		}

		colorRefs[#colorRefs + 1] = {
			attachment = #attachmentDescs - 1,
			layout = vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL,
		}

		self._attachments[#self._attachments + 1] = { texture = texture, finalLayout = finalLayout }
	end

	local depthRef = nil
	if depthAttachment then
		local view = depthAttachment.texture --[[@as hood-vk.TextureView]]
		local texture = view.texture
		imageViews[totalAttachments - 1] = view.handle

		local initialLayout, finalLayout = image.passLayouts(view, false, depthAttachment.op)

		attachmentDescs[#attachmentDescs + 1] = {
			format = texture.format,
			samples = vk.SampleCountFlagBits.COUNT_1,
			loadOp = depthAttachment.op.type == "clear" and vk.AttachmentLoadOp.CLEAR or vk.AttachmentLoadOp.LOAD,
			storeOp = vk.AttachmentStoreOp.STORE,
			stencilLoadOp = vk.AttachmentLoadOp.DONT_CARE,
			stencilStoreOp = vk.AttachmentStoreOp.DONT_CARE,
			initialLayout = initialLayout,
			finalLayout = finalLayout,
		}

		-- A depth texture left in the layout a shader reads has its writes made visible after
		-- the pass: a barrier cannot be recorded inside one.
		if finalLayout == vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL then
			self.sampleableDepth = texture
			self.sampleableDepthLayers = view.layerCount
		end

		self._attachments[#self._attachments + 1] = { texture = texture, finalLayout = finalLayout }

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

	-- Look up the render pass: for swapchain, store directly on the swapchain
	-- (avoids building a string key every frame). For non-swapchain, use the
	-- device-level cache with a string key.
	local renderPass
	if swapchainForFB then
		renderPass = swapchainForFB._cachedRenderPass
		if not renderPass then
			renderPass = self.device.handle:createRenderPass({
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
			swapchainForFB._cachedRenderPass = renderPass
		end
	else
		-- Build a cache key from attachment properties for non-swapchain rendering
		local cacheKey = ""
		for attIdx = 1, #attachmentDescs do
			local att = attachmentDescs[attIdx]
			cacheKey = cacheKey .. "," .. att.format .. "," .. att.loadOp .. "," .. att.finalLayout
		end
		cacheKey = cacheKey .. ",d=" .. (depthAttachment and "1" or "0")

		renderPass = self.device._renderPassCache[cacheKey]
		if not renderPass then
			renderPass = self.device.handle:createRenderPass({
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
			self.device._renderPassCache[cacheKey] = renderPass
		end
	end

	-- Use a cached framebuffer when rendering to a swapchain (the common case), and a
	-- framebuffer of this pass's own otherwise.
	local framebuffer
	if swapchainForFB then
		local depthView = nil
		if depthAttachment then
			depthView = depthAttachment.texture.handle
		end
		framebuffer = swapchainForFB:getFramebuffer(renderPass, width, height, depthView)
	else
		framebuffer = self.device.handle:createFramebuffer({
			renderPass = renderPass,
			attachmentCount = totalAttachments,
			pAttachments = imageViews,
			width = width,
			height = height,
			layers = 1,
		})
	end

	local clearValues
	if totalAttachments == 1 then
		clearValues = _reusableClearValues
	else
		clearValues = vk.ClearValueArray(totalAttachments)
	end

	for i = 1, #colorAttachments do
		local att = colorAttachments[i]
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

	local beginInfo = _reusableBeginInfo
	beginInfo.renderPass = renderPass
	beginInfo.framebuffer = framebuffer
	beginInfo.renderArea.offset.x = 0
	beginInfo.renderArea.offset.y = 0
	beginInfo.renderArea.extent.width = width
	beginInfo.renderArea.extent.height = height
	beginInfo.clearValueCount = totalAttachments
	beginInfo.pClearValues = clearValues

	self:_beginRenderPassRaw(beginInfo)
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
	---@param buffer hood-vk.Buffer
	---@param offset number?
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

---@param vertexCount number
---@param instanceCount number
---@param firstVertex number?
---@param firstInstance number?
function VKCommandEncoder:draw(vertexCount, instanceCount, firstVertex, firstInstance)
	self.device.handle:cmdDraw(self.buffer.handle, vertexCount, instanceCount or 1, firstVertex or 0,
		firstInstance or 0)
end

local descriptorSetArray = vk.DescriptorSetArray(1)

---@param index number
---@param bindGroup hood-vk.BindGroup
--- Move every subresource of a freshly created texture into one layout.
---
--- Sampling goes through a view and a descriptor covers the whole view, so every layer of a
--- sampled texture has to be in the layout the descriptor is written with -- even the ones
--- nothing was ever written to. A layer left in UNDEFINED reads as nothing, so writing layer 0
--- of an array would otherwise make every later layer sample as empty.
---
--- This belongs at creation, which is the only point with a command buffer of its own outside
--- a render pass: barriers cannot be recorded within one.
---@param texture hood-vk.Texture
---@return boolean claimed
function VKCommandEncoder:claimTexture(texture)
	-- A depth texture is left alone: a depth image is moved into the layout a shader reads by
	-- the pass that writes it, which is the only place that can put it there before it is
	-- sampled.
	if texture.isDepth then
		return false
	end

	-- Only a texture that can be sampled is moved into a shader read layout:
	-- VUID-VkImageMemoryBarrier-oldLayout-01211 requires the SAMPLED usage for it, and render
	-- attachment layouts are the render pass's business.
	if bit.band(texture.usage, vk.ImageUsageFlagBits.SAMPLED) == 0 then
		return false
	end

	return image.transition(self.device, self.buffer.handle, texture,
		vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL, vk.PipelineStageFlagBits.FRAGMENT_SHADER,
		vk.AccessFlags.SHADER_READ)
end

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

	self.device.handle:cmdBindDescriptorSets(self.buffer.handle, bindPoint, layout, index, 1,
		descriptorSetArray, 0)
end

--- End the open render pass.
---
--- A pass is only started when a pipeline is bound, so calling this without one
--- means the frame recorded an end with no matching begin. The driver does not
--- validate that: it executes a command buffer whose render pass never started,
--- which on at least one desktop driver is a segfault rather than an error.
function VKCommandEncoder:endRendering()
	if not self.inRenderPass then
		error("hood: endRendering was called with no open render pass; a pass is "
			.. "started by setPipeline, so bind the pipeline before drawing, even "
			.. "for a frame with nothing in it")
	end

	self.inRenderPass = false
	self.device.handle:cmdEndRenderPass(self.buffer.handle)

	-- Remember where the pass left each attachment, so the next pass or copy finds it there.
	local attachments = self._attachments
	for i = 1, #attachments do
		local attachment = attachments[i]
		attachment.texture.layout = attachment.finalLayout
	end
	self._attachments = {}

	-- A depth attachment the frame goes on to sample was left by the pass in the layout a
	-- shader reads, so what is left is to make its writes visible to those reads. The pass
	-- cannot record that barrier itself: barriers are not recordable within a render pass.
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

--- Begin the pass, refusing to nest one inside another.
---
--- Vulkan rejects a second vkCmdBeginRenderPass before the matching end, and the
--- driver's response to the resulting command stream is a crash rather than an
--- error, so this is checked here where the offending call is identifiable.
---@param beginInfo vk.ffi.RenderPassBeginInfo
---@private
function VKCommandEncoder:_beginRenderPassRaw(beginInfo)
	if self.inRenderPass then
		error("hood: beginRendering was called while a render pass is already open")
	end

	self.inRenderPass = true
	self.device.handle:cmdBeginRenderPass(self.buffer.handle, beginInfo, vk.SubpassContents.INLINE)
end

--- Make staged uploads visible to the commands that read them.
---
--- A vkCmdCopyBuffer into a buffer that a later draw reads is a transfer write
--- followed by a read with no dependency between them, which is undefined
--- behaviour; sync validation reports it as SYNC-HAZARD-READ-AFTER-WRITE. The
--- previous vkCmdUpdateBuffer path had exactly the same hole, so this is a
--- pre-existing bug rather than one the staging rewrite introduced.
---
--- One barrier covers everything staged in this command buffer, emitted when
--- the reads are about to start rather than after every copy.
---@private
function VKCommandEncoder:_flushStagedWrites()
	if not self.stagedWrites then
		return
	end
	self.stagedWrites = false

	local barrier = self.memoryBarrier[0]
	barrier.srcAccessMask = vk.AccessFlags.TRANSFER_WRITE
	barrier.dstAccessMask = bit.bor(
		vk.AccessFlags.MEMORY_READ,
		vk.AccessFlags.INDEX_READ,
		vk.AccessFlags.VERTEX_ATTRIBUTE_READ,
		vk.AccessFlags.UNIFORM_READ,
		vk.AccessFlags.SHADER_READ,
		vk.AccessFlags.INDIRECT_COMMAND_READ)

	-- Not usable inside a render pass, where the stage masks have to stay within
	-- the graphics stages; both call sites are outside one.
	self.device.handle:cmdPipelineBarrier(self.buffer.handle, vk.PipelineStageFlagBits.TRANSFER,
		vk.PipelineStageFlagBits.ALL_COMMANDS, 0, nil, 1, self.memoryBarrier)
end

--- Hand out `size` bytes of host-visible staging memory for this command buffer, growing the
--- staging buffer as needed.
---
--- The staging buffer lives on the command buffer rather than the encoder, because the copies
--- recorded out of it finish only when the command buffer retires. Swapchain command buffers are
--- reused per frame slot and the slot waits its fence before being re-recorded, so the same
--- allocation is safely reused next frame; a command buffer used once frees it with everything
--- else.
---
--- It is made the size it has to be rather than the next power of two past it: an upload of a
--- picture is one of these, and doubling a four megabyte one to eight is memory asked of a driver
--- that may not have it to spare.
---@param size number
---@return hood-vk.Buffer staging
---@private
function VKCommandEncoder:_staging(size)
	local staging = self.buffer.stagingBuffer

	if staging then
		if staging.staging.offset + size <= staging.descriptor.size then
			return staging
		end

		-- Copies already recorded out of this one still reference it, so it is kept until the
		-- command buffer is recycled rather than freed here.
		self.buffer.stagingResources = self.buffer.stagingResources or {}
		table.insert(self.buffer.stagingResources, staging)
	end

	local capacity = math.max(STAGING_MIN_SIZE, (staging and staging.staging.offset or 0) + size)
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
--- A mapped buffer is written directly by the CPU: no staging, no copy command, nothing submitted.
--- That is the path per-frame data should take, and what `VKQueue:writeBuffer` routes to for a
--- buffer it can write inline.
---
--- Everything else goes through host-visible staging memory and a vkCmdCopyBuffer, which is
--- intended for this unlike vkCmdUpdateBuffer: that one requires a dataSize that is a multiple of
--- 4 (VUID-vkCmdUpdateBuffer-dataSize-00038) and caps at 65536 bytes per call.
---@param buffer hood-vk.Buffer
---@param size number
---@param data ffi.cdata*
---@param offset number?
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

--- Issue `drawCount` indexed draws recorded in `buffer`, reading one command
--- every `stride` bytes from `offset`.
---
--- Every draw shares the bound vertex buffers and index buffer, so each command
--- selects its geometry through firstIndex and vertexOffset rather than by
--- rebinding. That is what lets a whole frame's instanced draws go out as one
--- call, and it costs one 20 byte record per draw instead of a draw command in
--- the command stream.
---
--- The buffer needs the INDIRECT usage, and its commands need the
--- drawIndirectFirstInstance feature when firstInstance is nonzero.
---@param buffer hood-vk.Buffer
---@param offset number
---@param drawCount number
---@param stride number
function VKCommandEncoder:drawIndexedIndirect(buffer, offset, drawCount, stride)
	self.device.handle:cmdDrawIndexedIndirect(self.buffer.handle, buffer.handle,
		offset or 0, drawCount, stride)
end

--- Copy bytes between two buffers on the GPU. The source needs COPY_SRC and
--- the destination COPY_DST.
---
--- Vulkan only for now: the OpenGL backend would need
--- glCopyNamedBufferSubData, which glapi does not expose yet.
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

	-- The region points at this upload's slice of the staging allocation rather than assuming
	-- the data starts at zero.
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

	-- Back to wherever this texture lives when nothing holds it: a readback target is not
	-- necessarily one that can be sampled.
	image.transition(self.device, self.buffer.handle, texture, image.restingLayout(texture),
		vk.PipelineStageFlagBits.FRAGMENT_SHADER, vk.AccessFlags.SHADER_READ)
end

---@param descriptor hood.ComputePassDescriptor
function VKCommandEncoder:beginComputePass(descriptor)
	-- Same reasoning as the render pass: staged writes must be visible before the dispatch
	-- reads them.
	self:_flushStagedWrites()

	-- A storage texture is written through a descriptor, and a descriptor names one layout for
	-- the whole view, so it has to be GENERAL for the dispatch.
	image.eachStorageTexture(self.bindGroups, function(texture)
		image.transition(self.device, self.buffer.handle, texture,
			vk.ImageLayout.GENERAL, vk.PipelineStageFlagBits.COMPUTE_SHADER, vk.AccessFlags.SHADER_WRITE)
	end)
end

---@param pipeline hood-vk.ComputePipeline
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
