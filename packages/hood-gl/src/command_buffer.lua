local gl = require("glapi")
local glConversions = require("hood-gl.convert")
local ffi = require("ffi")

local GLVAO = require("hood-gl.vao")

-- Clip control's own tokens, which glapi's enum tables do not carry: which corner of the
-- framebuffer window coordinates are counted from, and which depth range z is measured in.
local LOWER_LEFT, UPPER_LEFT = 0x8CA1, 0x8CA2
local NEGATIVE_ONE_TO_ONE = 0x935E

---@class hood-gl.CommandBuffer
---@field private commands hood-gl.Command[]
---@field private svbCache table # tbd
local GLCommandBuffer = {}
GLCommandBuffer.__index = GLCommandBuffer

---@param commands hood-gl.Command[]
function GLCommandBuffer.new(commands)
	return setmetatable({ svbCache = {}, commands = commands }, GLCommandBuffer)
end

---@param op hood.LoadOp
local function executeOp(op)
	if op.type == "clear" then
		gl.clearColor(op.color.r, op.color.g, op.color.b, op.color.a)
		gl.clear(gl.COLOR_BUFFER_BIT)
	elseif op.type == "load" then
		-- Do nothing, just keep the existing content
	end
end

---@param op hood.DepthOp
local function executeDepthOp(op)
	if op.type == "clear" then
		gl.depthMask(true)
		gl.clearDepthf(op.depth)
		gl.clear(gl.DEPTH_BUFFER_BIT)
	end
end

---@type table<hood-gl.Context, hood-gl.VAO>
local vaos = setmetatable({}, {
	__mode = "k",
})

--- TODO: Probably need to support multiple contexts too?
---@type table<hood-gl.Pipeline, hood-gl.RawPipeline>
local pipelines = setmetatable({}, {
	__mode = "k",
})

---@type table<hood-gl.ComputePipeline, hood-gl.RawComputePipeline>
local computePipelines = setmetatable({}, {
	__mode = "k",
})

-- FBO cache, keyed first by context (weak) then by attachment signature.
-- FBOs cannot be shared across GL contexts, so the per-context inner table
-- keeps them separate. Outer weak keys let entries be collected when a
-- context is garbage-collected.
---@type table<hood-gl.Context, table<string, number>>
local fboCache = setmetatable({}, { __mode = "k" })

---@param descriptor hood.RenderPassDescriptor
---@return string
local function makeAttachmentKey(descriptor)
	local parts = {}
	for i, att in ipairs(descriptor.colorAttachments) do
		local view = att.texture --[[@as hood-gl.TextureView]]
		parts[#parts + 1] = string.format("c%d:%d:%d:%d", i, view.id, view.baseMipLevel, view.baseArrayLayer)
	end
	if descriptor.depthStencilAttachment then
		local view = descriptor.depthStencilAttachment.texture --[[@as hood-gl.TextureView]]
		parts[#parts + 1] = string.format("d:%d:%d:%d", view.id, view.baseMipLevel, view.baseArrayLayer)
	end
	return table.concat(parts, "|")
end

---@param fbo number
---@param glAttachment number
---@param view hood-gl.TextureView
local function attachTextureToFBO(fbo, glAttachment, view)
	local extents = view.descriptor and view.descriptor.extents
	local isLayered = extents and (extents.count ~= nil or extents.dim == "3d")
	if isLayered then
		gl.namedFramebufferTextureLayer(fbo, glAttachment, view.id, view.baseMipLevel, view.baseArrayLayer)
	else
		gl.namedFramebufferTexture(fbo, glAttachment, view.id, view.baseMipLevel)
	end
end

---@param ctx hood-gl.Context
---@param descriptor hood.RenderPassDescriptor
---@return number fbo GL framebuffer object handle
local function getOrCreateFBO(ctx, descriptor)
	if not fboCache[ctx] then
		fboCache[ctx] = {}
	end
	local cache = fboCache[ctx]
	local key = makeAttachmentKey(descriptor)
	if cache[key] then
		return cache[key]
	end

	local fbo = gl.createFramebuffer()

	for i, att in ipairs(descriptor.colorAttachments) do
		local view = att.texture --[[@as hood-gl.TextureView]]
		attachTextureToFBO(fbo, gl.COLOR_ATTACHMENT0 + (i - 1), view)
	end

	if descriptor.depthStencilAttachment then
		local view = descriptor.depthStencilAttachment.texture --[[@as hood-gl.TextureView]]
		attachTextureToFBO(fbo, gl.DEPTH_ATTACHMENT, view)
	end

	-- Depth-only FBOs need color reads/writes explicitly disabled.
	if #descriptor.colorAttachments == 0 then
		gl.namedFramebufferDrawBuffer(fbo, gl.NONE)
		gl.namedFramebufferReadBuffer(fbo, gl.NONE)
	end

	cache[key] = fbo
	return fbo
end

---@param queueCtx hood-gl.Context  # The headless context (resource ops, compute)
---@param renderCtx hood-gl.Context? # The window context for rendering; nil in headless-only setups
function GLCommandBuffer:execute(queueCtx, renderCtx)
	---@type hood-gl.ComputePipeline?
	local computePipeline

	---@type hood-gl.Pipeline?
	local pipeline

	---@type hood-gl.VAO?
	local vao

	local indexType = gl.UNSIGNED_INT
	local indexSize = 4

	-- Tracks whether a render pass is open, so a mismatched end is reported
	-- rather than silently unbinding someone else's framebuffer.
	local inRenderPass = false

	for _, command in ipairs(self.commands) do
		if command.type == "beginRendering" then
			if inRenderPass then
				error("hood: beginRendering was called while a render pass is already open")
			end
			inRenderPass = true

			local attachments = command.descriptor.colorAttachments
			local depthStencilAttachment = command.descriptor.depthStencilAttachment

			-- Determine which context to make current and whether we're targeting
			-- the default (screen) framebuffer or an offscreen FBO.
			-- Swapchain textures have no id and carry their own context;
			-- offscreen textures use the queue's shared headless context.
			local ctx
			local isBackbuffer = false			-- Offscreen rendering must use renderCtx (the window context) rather than
			-- queueCtx (the headless context) when a surface has been configured.
			-- Both contexts share the same GL objects, but creating FBOs in the
			-- headless context causes NVIDIA to crash on the next window→headless
			-- context switch due to the two contexts using different XDisplay connections.
			local offscreenCtx = renderCtx or queueCtx
			local firstColorView = #attachments > 0 and attachments[1].texture --[[@as hood-gl.TextureView?]]
			if firstColorView then
				isBackbuffer = firstColorView.id == nil
				ctx = isBackbuffer and firstColorView.context or offscreenCtx
			elseif depthStencilAttachment then
				local depthView = depthStencilAttachment.texture --[[@as hood-gl.TextureView]]
				isBackbuffer = depthView.id == nil
				ctx = isBackbuffer and depthView.context or offscreenCtx
			else
				ctx = offscreenCtx
			end

			ctx:makeCurrent()

			if not vaos[ctx] then
				vaos[ctx] = GLVAO.new()
			end
			vao = vaos[ctx]
			vao:bind()

			if isBackbuffer then
				gl.bindFramebuffer(gl.FRAMEBUFFER, 0)
			else
				local fbo = getOrCreateFBO(ctx, command.descriptor)
				gl.bindFramebuffer(gl.FRAMEBUFFER, fbo)
			end

			-- OpenGL counts the rows of a framebuffer up from its bottom and Vulkan counts them
			-- down from its top, so the same drawing ends up in opposite rows on the two: a
			-- texture drawn into here and read back came out upside down against what Vulkan
			-- read back, and a texture drawn into and then sampled by another pass was sampled
			-- mirrored. This is the state OpenGL has for exactly that: with the origin at the
			-- upper left the geometry is turned over inside the viewport, and a texture comes out
			-- in the row order Vulkan leaves it in.
			--
			-- The window is left as it is. What is displayed from it is its bottom row, and the
			-- image it shows is the one it has always shown.
			if isBackbuffer then
				gl.clipControl(LOWER_LEFT, NEGATIVE_ONE_TO_ONE)
			else
				gl.clipControl(UPPER_LEFT, NEGATIVE_ONE_TO_ONE)
			end

			for _, attachment in ipairs(attachments) do
				executeOp(attachment.op)
			end

			if depthStencilAttachment then
				executeDepthOp(depthStencilAttachment.op)
			end
		elseif command.type == "setPipeline" then
			-- todo: pipelines need to be fixed as they are created in the headless context atm
			pipeline = command.pipeline

			local rawPipeline = pipelines[pipeline]
			if not rawPipeline then
				rawPipeline = pipeline:genForCurrentContext()
				pipelines[pipeline] = rawPipeline
			end
			rawPipeline:bind()

			if pipeline.depthStencil then
				gl.enable(gl.DEPTH_TEST)

				local compareFunc = pipeline.depthStencil.depthCompare
				local glCompareFunc = glConversions.compareFunction[compareFunc]
				gl.depthFunc(glCompareFunc)
				gl.depthMask(pipeline.depthStencil.depthWriteEnabled)
			else
				gl.disable(gl.DEPTH_TEST)
			end

			if pipeline.primitive then
				local cullMode = pipeline.primitive.cullMode
				if cullMode and cullMode ~= "none" then
					gl.enable(gl.CULL_FACE)
					gl.cullFace(glConversions.cullMode[pipeline.primitive.cullMode])
				else
					gl.disable(gl.CULL_FACE)
				end

				if pipeline.primitive.frontFace then
					gl.frontFace(glConversions.frontFace[pipeline.primitive.frontFace])
				end
			else
				gl.disable(gl.CULL_FACE)
			end

			for _, target in ipairs(pipeline.fragment.targets) do
				if target.blend == "alpha-blending" then
					gl.enable(gl.BLEND)
					gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
				else
					gl.disable(gl.BLEND)
				end
			end
		elseif command.type == "setViewport" then
			gl.viewport(command.x, command.y, command.width, command.height)
		elseif command.type == "endRendering" then
			if not inRenderPass then
				error("hood: endRendering was called with no open render pass; a pass is "
					.. "started by setPipeline, so bind the pipeline before drawing, even "
					.. "for a frame with nothing in it")
			end
			inRenderPass = false

			gl.bindFramebuffer(gl.FRAMEBUFFER, 0)
		elseif command.type == "setVertexBuffer" then
			if not pipeline then
				error("Pipeline must be set before setting vertex buffers")
			end

			local descriptor = pipeline.vertex.buffers[command.slot + 1]

			-- Locations run across all of the pipeline's layouts in order, so
			-- this layout starts where the previous ones left off.
			local locationBase = 0
			for i = 1, command.slot do
				locationBase = locationBase + #pipeline.vertex.buffers[i].attributes
			end

			vao:setVertexBuffer(command.buffer, descriptor, command.slot, command.offset, locationBase)
		elseif command.type == "setIndexBuffer" then
			vao:setIndexBuffer(command.buffer)
			indexType = glConversions.indexFormat[command.format]
			indexSize = command.format == "u16" and 2 or 4
		elseif command.type == "writeBuffer" then
			command.buffer:setSlice(command.size, command.data, command.offset)
		elseif command.type == "writeTexture" then
			command.texture:writeData(command.descriptor, command.data)
		elseif command.type == "copyTextureToBuffer" then
			local texture = command.source.texture --[[@as hood-gl.Texture]]
			local buffer = command.destination.buffer --[[@as hood-gl.Buffer]]
			local mipLevel = command.source.mipLevel or 0
			local origin = command.source.origin or {}
			local copySize = command.copySize
			local destination = command.destination

			local format = assert(glConversions.textureFormat[texture.descriptor.format],
				"Unsupported texture format for copyTextureToBuffer")
			local dataType = assert(glConversions.textureType[texture.descriptor.format],
				"Unsupported texture format for copyTextureToBuffer")

			gl.pixelStorei(gl.PACK_ALIGNMENT, 1)
			gl.pixelStorei(gl.PACK_ROW_LENGTH, destination.bytesPerRow and (destination.bytesPerRow / 4) or 0)
			gl.pixelStorei(gl.PACK_IMAGE_HEIGHT, destination.rowsPerImage or 0)

			gl.bindBuffer(gl.PIXEL_PACK_BUFFER, buffer.id)
			gl.getTextureSubImage(
				texture.id, mipLevel,
				origin.x or 0, origin.y or 0, origin.z or 0,
				copySize.width, copySize.height, copySize.depthOrArrayLayers or 1,
				format, dataType,
				buffer.descriptor.size,
				ffi.cast("void*", destination.offset or 0)
			)
			gl.bindBuffer(gl.PIXEL_PACK_BUFFER, 0)

			gl.pixelStorei(gl.PACK_ALIGNMENT, 4)
			gl.pixelStorei(gl.PACK_ROW_LENGTH, 0)
			gl.pixelStorei(gl.PACK_IMAGE_HEIGHT, 0)
		elseif command.type == "setBindGroup" then
			for _, entry in ipairs(command.bindGroup.entries) do
				if entry.type == "buffer" or entry.type == "uniform-buffer" or entry.type == "storage-buffer" then
					local buffer = entry.buffer --[[@as hood-gl.Buffer]]
					if buffer.isUniform then
						gl.bindBufferBase(gl.UNIFORM_BUFFER, entry.binding, buffer.id)
					elseif buffer.isStorage then
						gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, entry.binding, buffer.id)
					else
						error("Only uniform or storage buffers are supported in bind groups for now")
					end
				elseif entry.type == "texture" then
					local texture = entry.texture --[[@as hood-gl.TextureView]]
					gl.bindTextureUnit(entry.binding, texture.id)
				elseif entry.type == "sampler" then
					local sampler = entry.sampler --[[@as hood-gl.Sampler]]
					gl.bindSampler(entry.binding, sampler.id)
				elseif entry.type == "storageTexture" then
					local texture = entry.texture --[[@as hood-gl.TextureView]]

					gl.bindImageTexture(
						entry.binding,
						texture.id,
						0,
						entry.layer and 0 or 1,
						entry.layer or 0,
						glConversions.storageAccess[entry.access],
						texture.format
					)
				end
			end
		elseif command.type == "drawIndexed" then
			-- Indices are addressed as a byte offset into the bound element
			-- buffer, so firstIndex is scaled by the index size here.
			local indices = ffi.cast("const void*", command.firstIndex * indexSize)

			if command.firstInstance and command.firstInstance ~= 0 then
				error("hood: the OpenGL backend has no firstInstance; offset the instance buffer instead")
			end

			-- One entry point covers both cases: an instance count of 1 is an
			-- ordinary indexed draw.
			gl.drawElementsInstancedBaseVertex(gl.TRIANGLES, command.indexCount,
				indexType, indices, command.instanceCount or 1, command.baseVertex)
		elseif command.type == "drawIndexedIndirect" then
			-- The commands live in a buffer, bound with the byte offset applied
			-- here, and each one carries its own firstIndex and base vertex.
			-- glDrawElementsIndirect issues exactly one draw and ignores the
			-- count entirely, so the multi form is what actually issues them all.
			gl.bindBuffer(gl.DRAW_INDIRECT_BUFFER, command.buffer.id)
			gl.multiDrawElementsIndirect(gl.TRIANGLES, indexType,
				ffi.cast("const void*", command.offset), command.drawCount, command.stride)
			gl.bindBuffer(gl.DRAW_INDIRECT_BUFFER, 0)
		elseif command.type == "draw" then
			if command.firstInstance and command.firstInstance ~= 0 then
				error("hood: the OpenGL backend has no firstInstance; offset the instance buffer instead")
			end

			gl.drawArraysInstanced(gl.TRIANGLES, command.firstVertex, command.vertexCount,
				command.instanceCount or 1)
		elseif command.type == "beginComputePass" then
			gl.bindVertexArray(0)
		elseif command.type == "endComputePass" then
			-- nothing
		elseif command.type == "setComputePipeline" then
			computePipeline = command.pipeline

			local rawComputePipeline = computePipelines[computePipeline]
			if not rawComputePipeline then
				rawComputePipeline = computePipeline:genForCurrentContext()
				computePipelines[computePipeline] = rawComputePipeline
			end
			rawComputePipeline:bind()
		elseif command.type == "dispatchWorkgroups" then
			gl.dispatchCompute(command.x, command.y, command.z)
			gl.memoryBarrier(gl.ALL_BARRIER_BITS)
			gl.finish()
		else
			print("Unknown command type: " .. tostring(command.type))
		end
	end
end

return GLCommandBuffer
