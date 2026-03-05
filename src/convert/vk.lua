local vk = require("vkapi")

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

---@type table<hood.TextureFormat, vk.Format>
vkConversions.textureFormat = {
	["rgba8unorm"] = vk.Format.R8G8B8A8_UNORM,
	["rgba8uint"] = vk.Format.R8G8B8A8_UINT,
	["depth16unorm"] = vk.Format.D16_UNORM,
	["depth24plus"] = vk.Format.X8_D24_UNORM_PACK32,
	["depth32float"] = vk.Format.D32_SFLOAT,
	["bgra8unorm"] = vk.Format.B8G8R8A8_UNORM,
	["bgra8unorm-srgb"] = vk.Format.B8G8R8A8_SRGB
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

---@type table<hood.TextureUsage, vk.ImageUsageFlagBits>
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
	["buffer"] = vk.DescriptorType.STORAGE_BUFFER,
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

local function invert(t)
	local inverted = {}
	for k, v in pairs(t) do
		inverted[v] = k
	end
	return inverted
end

--- LuaLS sucks so I have to do the typing manually here, generics don't resolve.
vkConversions.from = {}
vkConversions.from.textureFormat = invert(vkConversions.textureFormat) ---@type table<vk.Format, hood.TextureFormat>

return vkConversions
