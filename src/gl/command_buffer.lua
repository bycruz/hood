local gl = require("glapi")
local glConversions = require("hood.convert.gl")
local ffi = require("ffi")

local GLVAO = require("hood.gl.vao")

---@class hood.gl.CommandBuffer
---@field private commands hood.gl.Command[]
---@field private svbCache table # tbd
local GLCommandBuffer = {}
GLCommandBuffer.__index = GLCommandBuffer

---@param commands hood.gl.Command[]
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

---@type table<hood.gl.Context, hood.gl.VAO>
local vaos = setmetatable({}, {
	__mode = "k",
})

--- TODO: Probably need to support multiple contexts too?
---@type table<hood.gl.Pipeline, hood.gl.RawPipeline>
local pipelines = setmetatable({}, {
	__mode = "k",
})

---@type table<hood.gl.ComputePipeline, hood.gl.RawComputePipeline>
local computePipelines = setmetatable({}, {
	__mode = "k",
})

---@param queueCtx hood.gl.Context # The queue's context; used as fallback for offscreen textures
function GLCommandBuffer:execute(queueCtx)
	---@type hood.gl.ComputePipeline?
	local computePipeline

	---@type hood.gl.Pipeline?
	local pipeline

	---@type hood.gl.VAO?
	local vao

	local indexType = gl.UNSIGNED_INT

	for _, command in ipairs(self.commands) do
		if command.type == "beginRendering" then
			local attachments = command.descriptor.colorAttachments
			for _, attachment in ipairs(attachments) do
				local texture = attachment.texture --[[@as hood.gl.Texture]]

				-- Use the texture's context for the swapchain (id is nil),
				-- or fall back to the queue's context for offscreen textures
				local ctx = not texture.id and texture.context or queueCtx
				ctx:makeCurrent()

				if not vaos[ctx] then
					local newVao = GLVAO.new()
					vaos[ctx] = newVao
				end
				vao = vaos[ctx]
				vao:bind()

				assert(texture.framebuffer == 0, "Unimplemented: support for different frame buffers")
				gl.bindFramebuffer(gl.FRAMEBUFFER, texture.framebuffer)
				executeOp(attachment.op)
			end

			-- TODO: Support separate depth/stencil textures
			local depthStencilAttachment = command.descriptor.depthStencilAttachment
			if depthStencilAttachment then
				local texture = depthStencilAttachment.texture --[[@as hood.gl.Texture]]
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
			gl.bindFramebuffer(gl.FRAMEBUFFER, 0)
		elseif command.type == "setVertexBuffer" then
			if not pipeline then
				error("Pipeline must be set before setting vertex buffers")
			end

			local descriptor = pipeline.vertex.buffers[command.slot + 1]
			vao:setVertexBuffer(command.buffer, descriptor, command.slot)
		elseif command.type == "setIndexBuffer" then
			vao:setIndexBuffer(command.buffer)
			indexType = glConversions.indexFormat[command.format]
		elseif command.type == "writeBuffer" then
			command.buffer:setSlice(command.size, command.data, command.offset)
		elseif command.type == "writeTexture" then
			command.texture:writeData(command.descriptor, command.data)
		elseif command.type == "copyTextureToBuffer" then
			local texture = command.source.texture --[[@as hood.gl.Texture]]
			local buffer = command.destination.buffer --[[@as hood.gl.Buffer]]
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
					local buffer = entry.buffer --[[@as hood.gl.Buffer]]
					if buffer.isUniform then
						gl.bindBufferBase(gl.UNIFORM_BUFFER, entry.binding, buffer.id)
					elseif buffer.isStorage then
						gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, entry.binding, buffer.id)
					else
						error("Only uniform or storage buffers are supported in bind groups for now")
					end
				elseif entry.type == "texture" then
					local texture = entry.texture --[[@as hood.gl.TextureView]]
					gl.bindTextureUnit(entry.binding, texture.id)
				elseif entry.type == "sampler" then
					local sampler = entry.sampler --[[@as hood.gl.Sampler]]
					gl.bindSampler(entry.binding, sampler.id)
				elseif entry.type == "storageTexture" then
					local texture = entry.texture --[[@as hood.gl.TextureView]]

					gl.bindImageTexture(
						entry.binding,
						texture.id,
						0,
						entry.layer and 0 or 1,
						entry.layer or 0,
						glConversions.storageAccess[entry.access],
						glConversions.textureFormat[texture.format]
					)
				end
			end
		elseif command.type == "drawIndexed" then
			gl.drawElements(gl.TRIANGLES, command.indexCount, indexType, nil)
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
