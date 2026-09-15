local ffi = require("ffi")

local vk = require("vkapi")
local vkConversions = require("hood.convert.vk")
local memory = require("hood.vk.memory")

local VKCommandBuffer = require("hood.vk.command_buffer")

--- Staging allocations start at this much memory and grow by doubling, so a
--- frame that uploads a few small uniform blocks does not allocate per write.
local STAGING_MIN_SIZE = 256 * 1024

---@class hood.vk.CommandEncoder
---@field buffer hood.vk.CommandBuffer
---@field device hood.vk.Device
---@field pendingDescriptor any
---@field imageViews vk.ffi.ImageView[]
---@field framebuffers vk.ffi.Framebuffer[]
---@field pipeline hood.vk.Pipeline?
---@field computePipeline hood.vk.ComputePipeline?
---@field bindGroups table<number, hood.vk.BindGroup>
---@field renderPasses vk.ffi.RenderPass[]
---@field bufferCopy vk.ffi.BufferCopy[] scratch for vkCmdCopyBuffer regions
---@field memoryBarrier vk.ffi.MemoryBarrier[] scratch for _flushStagedWrites
---@field stagedWrites boolean true while a staged copy is waiting to be made visible
---@field inRenderPass boolean true between beginRendering and endRendering
---@field _swapchain hood.vk.Swapchain?
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

---@param device hood.vk.Device
---@param reuseBuffer hood.vk.CommandBuffer? If provided, the buffer is reset and reused instead of allocating a new one.
---@return hood.vk.CommandEncoder
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

		-- Bind groups are only consulted by compute passes; drop stale entries
		-- so a later frame never sees groups from an earlier one. This costs
		-- nothing on the render-only path.
		if next(encoder.bindGroups) ~= nil then
			encoder.bindGroups = {}
		end

		return encoder
	end

	encoder = setmetatable({
		device = device,
		buffer = buffer,
		imageViews = {},
		framebuffers = {},
		renderPasses = {},
		bindGroups = {},
		bufferCopy = vk.BufferCopyArray(1),
		memoryBarrier = vk.MemoryBarrierArray(1),
		inRenderPass = false,
		stagedWrites = false,
		_swapchain = nil,
	}, VKCommandEncoder)
	buffer._encoder = encoder
	return encoder
end

--- Begin a render pass.
--- Two calling conventions:
---   1. Full descriptor table: encoder:beginRendering({ colorAttachments = {...} })
---   2. Simple single-attachment: encoder:beginRendering(textureView, clearColor?)
---       where textureView is a hood.vk.TextureView. The descriptor tables are
---       allocated once and reused internally, avoiding per-frame table churn.
---@overload fun(self, textureView: hood.vk.TextureView, clearColor?: { r: number, g: number, b: number, a: number })
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
	-- Anything staged earlier has to be visible before the first draw reads it.
	self:_flushStagedWrites()

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

	-- Detect if the first color attachment is a swapchain texture, so we can
	-- use pre-created image views and cached framebuffers from the swapchain.
	local swapchainForFB = nil
	if colorAttachments[1] then
		local view = colorAttachments[1].texture --[[@as hood.vk.TextureView]]
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

	-- Color attachments — use numeric for loop for JIT-friendliness
	for i = 1, #colorAttachments do
		local att = colorAttachments[i]
		local view = att.texture --[[@as hood.vk.TextureView]]
		local isSwapchain = view.texture and view.texture.isSwapchain

		-- Image views are owned by their textures and must outlive this command
		-- buffer, so they are never tracked here for cleanup.
		if isSwapchain and view.texture.swapchain then
			self._swapchain = view.texture.swapchain
		end
		imageViews[i - 1] = view.handle

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

	-- Use a cached framebuffer when rendering to a swapchain (the common case).
	-- Swapchain framebuffers are lazily created and cached per
	-- (renderPass, imageIdx, dimensions) -- and per depth view when one is
	-- attached, so a depth-attached pass is cached too rather than building and
	-- destroying a VkFramebuffer every frame.
	-- For non-swapchain rendering, create a transient framebuffer tracked per-frame.
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
		self.framebuffers[#self.framebuffers + 1] = framebuffer
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
---@param bindGroup hood.vk.BindGroup
--- Put every subresource of a freshly created texture into one layout.
---
--- A texture is sampled through a view, and a descriptor covers the whole view,
--- so every layer of a sampled texture has to be in the layout the descriptor is
--- written with -- even the ones nothing was ever written to. A layer left in
--- UNDEFINED fails VUID-vkCmdDraw-None-09600 and reads as nothing, so writing
--- layer 0 of an array would otherwise make every later layer sample as empty.
---
--- This belongs at creation, which is the only point with a command buffer of
--- its own outside a render pass: hood's render passes do not allow barriers
--- within them (VUID-vkCmdPipelineBarrier-None-07889).
---
--- Only correct before the image has been written to, since a layer with its own
--- tracked layout has already been moved somewhere deliberately. Texture
--- creators call it once; `texture.layoutDefault` records the result.
---@param texture hood.vk.Texture
---@return boolean claimed
function VKCommandEncoder:claimTexture(texture)
	if texture.layoutDefault then
		return false
	end

	-- Only a texture that can be sampled is moved into a shader read layout:
	-- VUID-VkImageMemoryBarrier-oldLayout-01211 requires the SAMPLED usage for
	-- it, and render attachment layouts are the render pass's business.
	local canSample = texture.usage
		and bit.band(texture.usage, vk.ImageUsageFlagBits.SAMPLED) ~= 0
	if not canSample then
		return false
	end

	local whole = vk.ImageMemoryBarrierArray(1)
	whole[0].srcAccessMask = 0
	whole[0].dstAccessMask = vk.AccessFlags.SHADER_READ
	whole[0].oldLayout = vk.ImageLayout.UNDEFINED
	whole[0].newLayout = vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL
	whole[0].srcQueueFamilyIndex = 0xFFFFFFFF -- VK_QUEUE_FAMILY_IGNORED
	whole[0].dstQueueFamilyIndex = 0xFFFFFFFF
	whole[0].image = texture.handle
	whole[0].subresourceRange.aspectMask = vk.ImageAspectFlagBits.COLOR
	whole[0].subresourceRange.baseMipLevel = 0
	whole[0].subresourceRange.levelCount = vk.REMAINING_MIP_LEVELS
	whole[0].subresourceRange.baseArrayLayer = 0
	whole[0].subresourceRange.layerCount = vk.REMAINING_ARRAY_LAYERS

	self.device.handle:cmdPipelineBarrier(
		self.buffer.handle,
		vk.PipelineStageFlagBits.TOP_OF_PIPE,
		vk.PipelineStageFlagBits.FRAGMENT_SHADER,
		1, whole)

	texture.layerLayouts = {}
	texture.layoutDefault = vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL
	return true
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
	self.device.handle:cmdPipelineBarrier(
		self.buffer.handle,
		vk.PipelineStageFlagBits.TRANSFER,
		vk.PipelineStageFlagBits.ALL_COMMANDS,
		0, nil,
		1, self.memoryBarrier)
end

--- Hand out `size` bytes of host-visible staging memory for this command
--- buffer, allocating or growing the staging buffer as needed.
---
--- The staging buffer lives on the command buffer rather than the encoder,
--- because copies recorded from it are only finished once the command buffer
--- retires at the end of the frame. Swapchain command buffers are reused per
--- frame slot and the slot waits its fence before being re-recorded, so the
--- same allocation is safely reused next frame; a command buffer destroyed
--- after one use frees it with everything else.
---
--- A staging buffer that is outgrown mid-frame is still referenced by copies
--- already recorded into it, so it is handed to the transient resource list and
--- freed when the command buffer is recycled instead of immediately.
---@param size number
---@return { buffer: vk.ffi.Buffer, memory: vk.ffi.DeviceMemory, pointer: ffi.cdata*, size: number, offset: number }
---@private
function VKCommandEncoder:_staging(size)
	local staging = self.buffer.staging

	if staging and staging.offset + size <= staging.size then
		return staging
	end

	if staging then
		self:_trackStagingResource(staging.buffer, staging.memory)
	end

	local capacity = staging and staging.size or STAGING_MIN_SIZE
	local needed = (staging and staging.offset or 0) + size
	while capacity < needed do
		capacity = capacity * 2
	end

	staging = memory.createMapped(self.device, capacity,
		vk.BufferUsageFlagBits.TRANSFER_SRC)
	staging.offset = 0
	self.buffer.staging = staging

	return staging
end

--- Upload CPU data into a buffer.
---
--- A mapped buffer is written directly by the CPU: no staging, no copy command,
--- nothing submitted. That is the path per-frame data should take.
---
--- Everything else goes through host-visible staging memory and a
--- vkCmdCopyBuffer. vkCmdUpdateBuffer was the old path here, but the spec
--- intends it for small updates only, and it is stricter than a copy: its
--- dataSize must be a multiple of 4 (validation reports
--- VUID-vkCmdUpdateBuffer-dataSize-00038), so writing a 6 byte index buffer was
--- never actually valid, and it is capped at 65536 bytes per call, which hood
--- used to work around by chunking. vkCmdCopyBuffer has neither restriction,
--- and drivers implement it as a straight transfer instead of as an internal
--- update path intended for a few hundred bytes.
---@param buffer hood.vk.Buffer
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
	ffi.copy(staging.pointer + staging.offset, data, size)

	local region = self.bufferCopy[0]
	region.srcOffset = staging.offset
	region.dstOffset = offset
	region.size = size

	self.device.handle:cmdCopyBuffer(self.buffer.handle, staging.buffer,
		buffer.handle, 1, self.bufferCopy)

	staging.offset = staging.offset + size
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
---@param buffer hood.vk.Buffer
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
---@param source hood.vk.Buffer
---@param destination hood.vk.Buffer
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

	self.device.handle:cmdCopyBuffer(self.buffer.handle, source.handle,
		destination.handle, 1, self.bufferCopy)
	self.stagedWrites = true
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

	-- Staging is bump-allocated per command buffer and shared with buffer
	-- uploads, instead of a fresh buffer, memory allocation and mapping on
	-- every single texture.
	local staging = self:_staging(dataSize)
	local stagingBuffer = staging.buffer
	local stagingOffset = staging.offset

	ffi.copy(staging.pointer + stagingOffset, data + (descriptor.offset or 0), dataSize)
	staging.offset = stagingOffset + math.ceil(dataSize / 4) * 4

	-- Transition image to TRANSFER_DST_OPTIMAL
	local mip = descriptor.mip or 0
	local layer = descriptor.layer or 0

	-- Use tracked layout if available, then whatever the image was claimed with
	-- at creation, and only then UNDEFINED for a texture nothing has touched.
	texture.layerLayouts = texture.layerLayouts or {}
	local oldLayout = texture.layerLayouts[layer] or texture.layoutDefault or vk.ImageLayout.UNDEFINED
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

	-- Copy buffer to image. The staging allocation is bump-allocated, so the
	-- region has to point at this upload's slice of it rather than assuming the
	-- data starts at zero.
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
	-- Same reasoning as the render pass: staged writes must be visible before
	-- the dispatch reads them.
	self:_flushStagedWrites()

	for _, bindGroup in pairs(self.bindGroups) do
		for _, entry in ipairs(bindGroup.entries) do
			if entry.type == "storageTexture" then
				local view = entry.texture --[[@as hood.vk.TextureView]]
				local tex = view.texture
				local layer = view.baseArrayLayer
				tex.layerLayouts = tex.layerLayouts or {}
				local currentLayout = tex.layerLayouts[layer] or tex.layoutDefault or vk.ImageLayout.UNDEFINED
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
				local currentLayout = tex.layerLayouts[layer] or tex.layoutDefault or vk.ImageLayout.UNDEFINED
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
	if self.inRenderPass then
		error("hood: finish() was called with a render pass still open; endRendering() first")
	end

	self.device.handle:endCommandBuffer(self.buffer.handle)

	local buffer = self.buffer
	local imageViews, framebuffers, renderPasses = self.imageViews, self.framebuffers, self.renderPasses

	-- Hand the tracking tables over to the command buffer only when something
	-- transient was recorded. The common swapchain path tracks nothing (views,
	-- framebuffers and render passes are all cached on the swapchain), so the
	-- encoder keeps its tables and nothing is allocated per frame.
	if #imageViews ~= 0 or #framebuffers ~= 0 or #renderPasses ~= 0 then
		buffer.imageViews = imageViews
		buffer.framebuffers = framebuffers
		buffer.renderPasses = renderPasses
		self.imageViews = {}
		self.framebuffers = {}
		self.renderPasses = {}
	else
		buffer.imageViews = nil
		buffer.framebuffers = nil
		buffer.renderPasses = nil
	end

	buffer._swapchain = self._swapchain

	return buffer
end

return VKCommandEncoder
