local vk = require("vkapi") ---@cast vk vk & hood-vk.VkExtras

local vkConversions = {}

---@type table<hood.TextureDimension, vk.ImageType>
vkConversions.textureType = {
	["1d"] = vk.ImageType.TYPE_1D,
	["2d"] = vk.ImageType.TYPE_2D,
	["3d"] = vk.ImageType.TYPE_3D
}

---@type table<hood.PresentMode, vk.PresentModeKHR>
vkConversions.presentMode = {
	["immediate"] = vk.PresentModeKHR.IMMEDIATE,
	["fifo"] = vk.PresentModeKHR.FIFO,
	["fifo-relaxed"] = vk.PresentModeKHR.FIFO_RELAXED,
	["mailbox"] = vk.PresentModeKHR.MAILBOX,
}

---@type table<hood.TextureViewDimension, vk.SampleCountFlagBits>
vkConversions.textureViewType = {
	["1d"] = vk.ImageViewType.TYPE_1D,
	["2d"] = vk.ImageViewType.TYPE_2D,
	["3d"] = vk.ImageViewType.TYPE_3D,
	["cube"] = vk.ImageViewType.CUBE,
	["1d_array"] = vk.ImageViewType.TYPE_1D_ARRAY,
	["2d_array"] = vk.ImageViewType.TYPE_2D_ARRAY,
	["cube_array"] = vk.ImageViewType.CUBE_ARRAY,
}

---@type table<hood.TextureFormat, number>
vkConversions.textureFormat = {
	["rgba8unorm"] = vk.Format.R8G8B8A8_UNORM,
	["r8unorm"] = vk.Format.R8_UNORM,
	["rgba8unorm-srgb"] = vk.Format.R8G8B8A8_SRGB,
	["rgba8uint"] = vk.Format.R8G8B8A8_UINT,
	["depth16unorm"] = vk.Format.D16_UNORM,
	["depth24plus"] = vk.Format.X8_D24_UNORM_PACK32,
	["depth32float"] = vk.Format.D32_SFLOAT,
	["bgra8unorm"] = vk.Format.B8G8R8A8_UNORM,
	["bgra8unorm-srgb"] = vk.Format.B8G8R8A8_SRGB,
}

---@type table<hood.TextureAspect, number>
vkConversions.textureAspect = {
	["color"] = vk.ImageAspectFlagBits.COLOR,
	["depth"] = vk.ImageAspectFlagBits.DEPTH,
	["stencil"] = vk.ImageAspectFlagBits.STENCIL,
	["all"] = bit.bor(vk.ImageAspectFlagBits.COLOR, vk.ImageAspectFlagBits.DEPTH, vk.ImageAspectFlagBits.STENCIL),
}

---@type table<number, vk.SampleCountFlagBits>
vkConversions.sampleCount = {
	[1] = vk.SampleCountFlagBits.COUNT_1,
	[2] = vk.SampleCountFlagBits.COUNT_2,
	[4] = vk.SampleCountFlagBits.COUNT_4,
	[8] = vk.SampleCountFlagBits.COUNT_8,
	[16] = vk.SampleCountFlagBits.COUNT_16,
	[32] = vk.SampleCountFlagBits.COUNT_32,
	[64] = vk.SampleCountFlagBits.COUNT_64,
}

---@type table<hood.TextureUsage, number>
vkConversions.textureUsage = {
	["COPY_SRC"] = vk.ImageUsageFlagBits.TRANSFER_SRC,
	["COPY_DST"] = vk.ImageUsageFlagBits.TRANSFER_DST,
	["TEXTURE_BINDING"] = vk.ImageUsageFlagBits.SAMPLED,
	["STORAGE_BINDING"] = vk.ImageUsageFlagBits.STORAGE,
	["RENDER_ATTACHMENT"] = vk.ImageUsageFlagBits.COLOR_ATTACHMENT,
}

---@type table<hood.CompareFunction, vk.CompareOp>
vkConversions.compareFunction = {
	["never"] = vk.CompareOp.NEVER,
	["less"] = vk.CompareOp.LESS,
	["equal"] = vk.CompareOp.EQUAL,
	["less-equal"] = vk.CompareOp.LESS_OR_EQUAL,
	["greater"] = vk.CompareOp.GREATER,
	["not-equal"] = vk.CompareOp.NOT_EQUAL,
	["greater-equal"] = vk.CompareOp.GREATER_OR_EQUAL,
	["always"] = vk.CompareOp.ALWAYS,
}

---@type table<hood.FilterMode, vk.Filter>
vkConversions.filterMode = {
	["nearest"] = vk.Filter.NEAREST,
	["linear"] = vk.Filter.LINEAR,
}

---@type table<hood.AddressMode, vk.SamplerAddressMode>
vkConversions.addressMode = {
	["clamp-to-edge"] = vk.SamplerAddressMode.CLAMP_TO_EDGE,
	["repeat"] = vk.SamplerAddressMode.REPEAT,
	["mirrored-repeat"] = vk.SamplerAddressMode.MIRRORED_REPEAT,
}

---@type table<hood.IndexFormat, vk.IndexType>
vkConversions.indexFormat = {
	["u16"] = vk.IndexType.UINT16,
	["u32"] = vk.IndexType.UINT32,
}

---@type table<hood.BindingType, vk.DescriptorType>
vkConversions.bindingType = {
	["uniform-buffer"] = vk.DescriptorType.UNIFORM_BUFFER,
	["storage-buffer"] = vk.DescriptorType.STORAGE_BUFFER,
	["buffer"] = vk.DescriptorType.STORAGE_BUFFER, -- deprecated alias for storage-buffer
	["sampler"] = vk.DescriptorType.SAMPLER,
	["texture"] = vk.DescriptorType.SAMPLED_IMAGE,
	["storageTexture"] = vk.DescriptorType.STORAGE_IMAGE,
}

---@type table<hood.ShaderStage, vk.ShaderStageFlagBits>
vkConversions.shaderStage = {
	["VERTEX"] = vk.ShaderStageFlagBits.VERTEX,
	["FRAGMENT"] = vk.ShaderStageFlagBits.FRAGMENT,
	["COMPUTE"] = vk.ShaderStageFlagBits.COMPUTE,
}

---@type table<hood.CullMode, vk.CullModeFlagBits>
vkConversions.cullMode = {
	["none"] = vk.CullModeFlagBits.NONE,
	["front"] = vk.CullModeFlagBits.FRONT,
	["back"] = vk.CullModeFlagBits.BACK,
}

---@type table<hood.FrontFace, vk.FrontFace>
vkConversions.frontFace = {
	["clockwise"] = vk.FrontFace.CLOCKWISE,
	["counter-clockwise"] = vk.FrontFace.COUNTER_CLOCKWISE,
}

local function invert(t)
	local inverted = {}
	for k, v in pairs(t) do
		inverted[v] = k
	end
	return inverted
end

--- Generics do not resolve through LuaLS, so these are typed by hand.
vkConversions.from = {}
vkConversions.from.textureFormat = invert(vkConversions.textureFormat) ---@type table<number, hood.TextureFormat>

--- The surface formats a swapchain is made in when the caller names none, in the order tried.
---
--- A swapchain format decides how a shader's output is stored, not how it is computed: an
--- `-srgb` format makes the hardware encode the values a shader writes, a plain one stores them
--- as they are. The shaders this library is used with write sRGB-encoded colour -- a theme's
--- colour is the bytes of its hex string, a picture is uploaded as `rgba8unorm`, and the fragment
--- shader converts between encoded and linear nowhere -- so an `-srgb` format would encode those
--- bytes a second time. That is the washed-out look, and it is why no `-srgb` format is ever
--- chosen by default, however early a driver lists one.
---
--- B8G8R8A8 is first because it is what desktop WSI implementations present natively; R8G8B8A8
--- is what Android's surface offers. A driver's own order is not a preference: Mesa's X11 surface
--- lists B8G8R8A8_SRGB first and Android's lists R8G8B8A8_UNORM, which is the same app looking
--- different on each GPU.
---@type hood.TextureFormat[]
vkConversions.defaultSurfaceFormats = { "bgra8unorm", "rgba8unorm" }

--- The surface format a swapchain is made in.
---
--- The colour space is the transfer function the display shows the written bytes through. What
--- the shaders write is already encoded, so `SRGB_NONLINEAR` is the space wanted; where the
--- surface offers it, only formats in that space are candidates. Another space, where the surface
--- offers sRGB for nothing, would show the same bytes through another function, so it is taken
--- only as a last resort.
---
--- `VK_FORMAT_UNDEFINED` as the surface's only format is the old way of saying any format is
--- supported: the first preference is then handed back for a swapchain to be made in.
---@param formats vk.ffi.SurfaceFormatKHR[]
---@param requested hood.TextureFormat? # An exact format, overriding any preference
---@param preferred hood.TextureFormat[]? # The formats to try in order when none is requested; nil takes `defaultSurfaceFormats`
---@return vk.ffi.SurfaceFormatKHR
function vkConversions.pickSurfaceFormat(formats, requested, preferred)
	if #formats == 0 then
		error("The surface offers no format")
	end

	if #formats == 1 and formats[1].format == vk.Format.UNDEFINED then
		local wanted = requested or (preferred or vkConversions.defaultSurfaceFormats)[1]
		local format = assert(vkConversions.textureFormat[wanted],
			"Unknown surface format: " .. tostring(wanted))
		return { format = format, colorSpace = vk.ColorSpaceKHR.SRGB_NONLINEAR }
	end

	-- The formats offered in the colour space a display shows encoded bytes through: a driver may
	-- list a format in more than one space, and only the space entries are candidates.
	local nonlinear = {}
	for _, format in ipairs(formats) do
		if format.colorSpace == vk.ColorSpaceKHR.SRGB_NONLINEAR then
			nonlinear[#nonlinear + 1] = format
		end
	end
	local candidates = #nonlinear > 0 and nonlinear or formats

	if requested then
		local wanted = assert(vkConversions.textureFormat[requested],
			"Unknown surface format: " .. tostring(requested))

		for _, format in ipairs(candidates) do
			if format.format == wanted then
				return format
			end
		end

		-- The format exists, in a colour space other than sRGB non-linear: an explicit request is
		-- honoured over the colour-space preference, since the caller named the format it draws.
		for _, format in ipairs(formats) do
			if format.format == wanted then
				return format
			end
		end

		error("Requested surface format not supported: " .. tostring(requested))
	end

	for _, name in ipairs(preferred or vkConversions.defaultSurfaceFormats) do
		local wanted = vkConversions.textureFormat[name]
		if wanted ~= nil then
			for _, format in ipairs(candidates) do
				if format.format == wanted then
					return format
				end
			end
		end
	end

	-- What is left is a surface that cannot store an encoded colour as it is: the alternative is
	-- drawing every frame into a format that would encode it again, which is worse than saying so.
	local offered = {}
	for _, format in ipairs(formats) do
		local name = vkConversions.from.textureFormat[format.format]
			or ("format " .. tostring(format.format))
		offered[#offered + 1] = string.format("%s (colour space %s)", name, tostring(format.colorSpace))
	end

	error(string.format(
		"Surface offers none of the preferred formats (%s), and this renderer writes encoded colour: %s",
		table.concat(preferred or vkConversions.defaultSurfaceFormats, ", "),
		table.concat(offered, ", ")))
end

return vkConversions
