local vk = require("vkapi")

--- Image layout transitions for the Vulkan backend.
---
--- Vulkan requires an image to be in a layout that matches how it is about to be used, and
--- the barrier that moves it there must name the stage and access that produced the current
--- contents. Both halves follow from the layout alone, so they live here rather than being
--- spelled out at every call site.
---
--- Layouts are tracked one per texture. Every barrier below covers the image's whole
--- subresource range, which is what a descriptor does: a view bound to a shader covers all of
--- its layers, so a layer left in the wrong layout is a layer that reads as nothing.
local image = {}

--- VK_QUEUE_FAMILY_IGNORED: hood does not share images between queues.
image.QUEUE_FAMILY_IGNORED = 0xFFFFFFFF

---@type table<number, { stage: number, access: number }>
local producers = {
	[vk.ImageLayout.UNDEFINED] = { stage = vk.PipelineStageFlagBits.TOP_OF_PIPE, access = 0 },
	[vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL] = {
		stage = vk.PipelineStageFlagBits.FRAGMENT_SHADER,
		access = vk.AccessFlags.SHADER_READ,
	},
	[vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL] = {
		stage = vk.PipelineStageFlagBits.COLOR_ATTACHMENT_OUTPUT,
		access = vk.AccessFlags.COLOR_ATTACHMENT_WRITE,
	},
	[vk.ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL] = {
		stage = bit.bor(vk.PipelineStageFlagBits.EARLY_FRAGMENT_TESTS,
			vk.PipelineStageFlagBits.LATE_FRAGMENT_TESTS),
		access = bit.bor(vk.AccessFlags.DEPTH_STENCIL_ATTACHMENT_READ,
			vk.AccessFlags.DEPTH_STENCIL_ATTACHMENT_WRITE),
	},
	[vk.ImageLayout.TRANSFER_DST_OPTIMAL] = {
		stage = vk.PipelineStageFlagBits.TRANSFER,
		access = vk.AccessFlags.TRANSFER_WRITE,
	},
	[vk.ImageLayout.TRANSFER_SRC_OPTIMAL] = {
		stage = vk.PipelineStageFlagBits.TRANSFER,
		access = vk.AccessFlags.TRANSFER_READ,
	},
	[vk.ImageLayout.GENERAL] = {
		stage = vk.PipelineStageFlagBits.COMPUTE_SHADER,
		access = bit.bor(vk.AccessFlags.SHADER_READ, vk.AccessFlags.SHADER_WRITE),
	},
}

--- The layout a texture is in before anything has been recorded against it.
---@param texture hood-vk.Texture
---@return vk.ImageLayout
function image.currentLayout(texture)
	return texture.layout or vk.ImageLayout.UNDEFINED
end

--- Record the barrier that moves `texture` into `newLayout`, and remember it.
---
--- A texture already in `newLayout` is left alone: the barrier would be a no-op, and matching
--- the old layout to the real one is what keeps the driver from discarding contents it is
--- about to read.
---@param device hood-vk.Device
---@param commandBuffer vk.ffi.CommandBuffer
---@param texture hood-vk.Texture
---@param newLayout vk.ImageLayout
---@param dstStage number # The stage that will next touch the image
---@param dstAccess number # What that stage will do with it
---@param aspect number? defaults to colour; depth attachments pass DEPTH
---@return boolean transitioned
function image.transition(device, commandBuffer, texture, newLayout, dstStage, dstAccess, aspect)
	local oldLayout = image.currentLayout(texture)

	if oldLayout == newLayout then
		return false
	end

	local producer = producers[oldLayout]
	local barrier = vk.ImageMemoryBarrier({
		srcAccessMask = producer.access,
		dstAccessMask = dstAccess,
		oldLayout = oldLayout,
		newLayout = newLayout,
		srcQueueFamilyIndex = image.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = image.QUEUE_FAMILY_IGNORED,
		image = texture.handle,
	})

	barrier.subresourceRange.aspectMask = aspect or vk.ImageAspectFlagBits.COLOR
	barrier.subresourceRange.baseMipLevel = 0
	barrier.subresourceRange.levelCount = vk.REMAINING_MIP_LEVELS
	barrier.subresourceRange.baseArrayLayer = 0
	barrier.subresourceRange.layerCount = vk.REMAINING_ARRAY_LAYERS

	device.handle.v1_0.vkCmdPipelineBarrier(commandBuffer, producer.stage, dstStage, 0,
		0, nil, 0, nil, 1, barrier)

	texture.layout = newLayout

	return true
end

--- The layout a texture rests in when nothing is holding it: the one a shader reads if it can be
--- sampled, and the one an attachment is written in otherwise.
---
--- VUID-VkImageMemoryBarrier-oldLayout-01211: only a texture created with the SAMPLED usage may
--- be in SHADER_READ_ONLY_OPTIMAL, so a render target that is never sampled belongs in an
--- attachment layout.
---@param texture hood-vk.Texture
---@return vk.ImageLayout
function image.restingLayout(texture)
	if bit.band(texture.usage, vk.ImageUsageFlagBits.SAMPLED) ~= 0 then
		return vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL
	end

	if texture.isDepth then
		return vk.ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL
	end

	return vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL
end

--- The layouts a render pass leaves its attachments in, so that later passes and copies find
--- them where the pass put them.
---
--- A pass that loads an attachment must say which layout it is loading from, and the layout a
--- descriptor names is the one it must have been written to in. So the attachment ends where the
--- next reader expects it: PRESENT_SRC for a swapchain image, and otherwise the layout the
--- texture rests in.
---@param view hood-vk.TextureView
---@param isSwapchain boolean
---@param op hood.LoadOp|hood.DepthOp
---@return vk.ImageLayout initialLayout, vk.ImageLayout finalLayout
function image.passLayouts(view, isSwapchain, op)
	local texture = view.texture

	if isSwapchain then
		return vk.ImageLayout.UNDEFINED, vk.ImageLayout.PRESENT_SRC_KHR
	end

	local finalLayout = image.restingLayout(texture)

	if not texture.isDepth then
		-- A colour attachment is written from scratch: its contents do not survive a pass.
		return vk.ImageLayout.UNDEFINED, finalLayout
	end

	local current = image.currentLayout(texture)
	local initial = vk.ImageLayout.UNDEFINED

	if current ~= vk.ImageLayout.UNDEFINED then
		-- Loading a depth texture gives the pass the layout it is already in to load from;
		-- anything else is written from scratch.
		initial = op.type == "clear" and vk.ImageLayout.UNDEFINED or current
	end

	return initial, finalLayout
end

--- Record a barrier over one image without moving it, so that writes on `srcStage` with
--- `srcAccess` are visible to `dstStage` with `dstAccess`.
---
--- A render pass leaves its depth attachment in the layout a shader reads, but the pass cannot
--- record that writes are visible: a barrier is not recordable within a render pass. This is for
--- that barrier and others like it, where the layout is already right and only the dependency is
--- missing.
---@param device hood-vk.Device
---@param commandBuffer vk.ffi.CommandBuffer
---@param scratch vk.ffi.ImageMemoryBarrier[] # A one-element array to fill in
---@param texture hood-vk.Texture
---@param layout vk.ImageLayout
---@param srcStage number
---@param srcAccess number
---@param dstAccess number
---@param dstStage number
---@param aspect number
---@param layerCount number
function image.barrier(device, commandBuffer, scratch, texture, layout, srcStage, srcAccess,
	dstAccess, dstStage, aspect, layerCount)
	local barrier = scratch[0]
	barrier.srcAccessMask = srcAccess
	barrier.dstAccessMask = dstAccess
	barrier.oldLayout = layout
	barrier.newLayout = layout
	barrier.srcQueueFamilyIndex = image.QUEUE_FAMILY_IGNORED
	barrier.dstQueueFamilyIndex = image.QUEUE_FAMILY_IGNORED
	barrier.image = texture.handle

	barrier.subresourceRange.aspectMask = aspect
	barrier.subresourceRange.baseMipLevel = 0
	barrier.subresourceRange.levelCount = 1
	barrier.subresourceRange.baseArrayLayer = 0
	barrier.subresourceRange.layerCount = layerCount

	device.handle.v1_0.vkCmdPipelineBarrier(commandBuffer, srcStage, dstStage, 0, 0, nil, 0, nil, 1, scratch)
end

--- Call `fn` once for every texture bound as a storage texture across the given bind groups.
---
--- A bind group that names a storage texture is the only place a dispatch states which image
--- it writes to, so the passes consult the bound groups rather than being told separately.
---@param bindGroups table<number, hood-vk.BindGroup>
---@param fn fun(texture: hood-vk.Texture)
function image.eachStorageTexture(bindGroups, fn)
	for _, bindGroup in pairs(bindGroups) do
		for _, entry in ipairs(bindGroup.entries) do
			if entry.type == "storageTexture" then
				fn((entry.texture --[[@as hood-vk.TextureView]]).texture)
			end
		end
	end
end

return image
