---@class hood.gl.TextureView
---@field texture hood.gl.Texture
---@field id number?           # same as texture.id (nil for backbuffer)
---@field context hood.gl.Context?
---@field framebuffer number
---@field format number?
---@field descriptor hood.TextureDescriptor?
---@field baseMipLevel integer
---@field levelCount integer
---@field baseArrayLayer integer
---@field layerCount integer?
local GLTextureView = {}
GLTextureView.__index = GLTextureView

---@param texture hood.gl.Texture
---@param descriptor hood.TextureViewDescriptor
function GLTextureView.new(texture, descriptor)
	descriptor = descriptor or {}
	local mipLevelCount = texture.descriptor and texture.descriptor.mipLevelCount or 1
	return setmetatable({
		texture = texture,
		id = texture.id,
		context = texture.context,
		framebuffer = texture.framebuffer,
		format = texture.format,
		descriptor = texture.descriptor,
		baseMipLevel = descriptor.baseMipLevel or 0,
		levelCount = descriptor.levelCount or mipLevelCount,
		baseArrayLayer = descriptor.baseArrayLayer or 0,
		layerCount = descriptor.layerCount,
	}, GLTextureView)
end

return GLTextureView
