local vk = require("vkapi")

--- Render passes and framebuffers.
---
--- A pipeline is created against a render pass and a framebuffer pairs one with the images a
--- draw renders into. Both are described the same way by a pipeline, which knows the formats it
--- was made for, and a frame, which knows the textures.
local pass = {}

---@class hood-vk.AttachmentSpec
---@field format number # vk.Format
---@field loadOp number # vk.AttachmentLoadOp
---@field initialLayout number # vk.ImageLayout
---@field finalLayout number # vk.ImageLayout
---@field sampled boolean # Whether the attachment can be sampled, which decides the layout it ends in

--- What makes two render passes interchangeable.
---
--- Vulkan pairs a pipeline with a framebuffer when the pass is *compatible*: same attachment
--- count, same formats and sample counts, same number of views. Load and store ops are not part
--- of it, so a pass defined for a format serves a pipeline made for that format.
---
--- The layouts a pass names are part of it, though: a pass ending an attachment in
--- SHADER_READ_ONLY_OPTIMAL may only be used with an image created to be sampled
--- (VUID-vkCmdBeginRenderPass-initialLayout-00897). So a pass is keyed by its attachments and
--- whether each is sampled.
---@param colorAttachments hood-vk.AttachmentSpec[]
---@param depthAttachment hood-vk.AttachmentSpec?
---@return string
function pass.signature(colorAttachments, depthAttachment)
	local parts = {}

	for i = 1, #colorAttachments do
		local spec = colorAttachments[i]
		parts[i] = tostring(spec.format) .. (spec.sampled and "s" or "r")
	end

	if depthAttachment then
		parts[#parts + 1] = "d"
		parts[#parts + 1] = tostring(depthAttachment.format) .. (depthAttachment.sampled and "s" or "r")
	end

	return table.concat(parts, ",")
end

--- Define, or reuse, the render pass for a set of attachments. Passes are cached on the device
--- by signature, so rendering the same configuration every frame defines one pass.
---@param device hood-vk.Device
---@param colorAttachments hood-vk.AttachmentSpec[]
---@param depthAttachment hood-vk.AttachmentSpec?
---@return vk.ffi.RenderPass
function pass.define(device, colorAttachments, depthAttachment)
	local signature = pass.signature(colorAttachments, depthAttachment)
	local cached = device._renderPassCache[signature]

	if cached then
		return cached
	end

	---@type vk.AttachmentDescription[]
	local attachmentDescs = {}
	---@type vk.AttachmentReference[]
	local colorRefs = {}
	local depthRef = nil
	local hasDepth = depthAttachment ~= nil

	for i = 1, #colorAttachments do
		local spec = colorAttachments[i]

		attachmentDescs[#attachmentDescs + 1] = {
			format = spec.format,
			samples = vk.SampleCountFlagBits.COUNT_1,
			loadOp = spec.loadOp,
			storeOp = vk.AttachmentStoreOp.STORE,
			stencilLoadOp = vk.AttachmentLoadOp.DONT_CARE,
			stencilStoreOp = vk.AttachmentStoreOp.DONT_CARE,
			initialLayout = spec.initialLayout,
			finalLayout = spec.finalLayout,
		}
		colorRefs[#colorRefs + 1] = {
			attachment = #attachmentDescs - 1,
			layout = vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL,
		}
	end

	if depthAttachment then
		attachmentDescs[#attachmentDescs + 1] = {
			format = depthAttachment.format,
			samples = vk.SampleCountFlagBits.COUNT_1,
			loadOp = depthAttachment.loadOp,
			storeOp = vk.AttachmentStoreOp.STORE,
			stencilLoadOp = vk.AttachmentLoadOp.DONT_CARE,
			stencilStoreOp = vk.AttachmentStoreOp.DONT_CARE,
			initialLayout = depthAttachment.initialLayout,
			finalLayout = depthAttachment.finalLayout,
		}
		depthRef = {
			attachment = #attachmentDescs - 1,
			layout = vk.ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		}
	end

	local stageMask = vk.PipelineStageFlagBits.COLOR_ATTACHMENT_OUTPUT
	local accessMask = vk.AccessFlags.COLOR_ATTACHMENT_WRITE

	if hasDepth then
		stageMask = bit.bor(stageMask, vk.PipelineStageFlagBits.EARLY_FRAGMENT_TESTS,
			vk.PipelineStageFlagBits.LATE_FRAGMENT_TESTS)
		accessMask = bit.bor(accessMask, vk.AccessFlags.DEPTH_STENCIL_ATTACHMENT_READ,
			vk.AccessFlags.DEPTH_STENCIL_ATTACHMENT_WRITE)
	end

	local handle = device.handle:createRenderPass({
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
				srcStageMask = stageMask,
				dstStageMask = stageMask,
				dstAccessMask = accessMask,
			},
		},
	})

	device._renderPassCache[signature] = handle

	return handle
end

--- The framebuffer pairing a render pass with one frame's images, cached by the images it was
--- made from. Keying on the handles keeps a frame that renders into different textures from
--- reusing a framebuffer pointing at images it no longer owns.
---@param device hood-vk.Device
---@param renderPass vk.ffi.RenderPass
---@param attachments vk.ffi.ImageView[] # one per attachment, in pass order
---@param handles vk.ffi.Image[] # the images those views see, for the cache key
---@param width number
---@param height number
---@return vk.ffi.Framebuffer
function pass.framebuffer(device, renderPass, attachments, handles, width, height)
	local parts = { tostring(renderPass), tostring(width), tostring(height) }

	for i = 1, #handles do
		parts[#parts + 1] = tostring(handles[i])
	end

	local key = table.concat(parts, ",")
	local cached = device._framebufferCache[key]

	if cached then
		return cached
	end

	local framebuffer = device.handle:createFramebuffer({
		renderPass = renderPass, attachmentCount = #handles, pAttachments = attachments,
		width = width, height = height, layers = 1,
	})

	device._framebufferCache[key] = framebuffer

	return framebuffer
end

return pass
