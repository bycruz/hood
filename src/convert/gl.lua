local hood = require("hood")
local gl = require("glapi")

local glConversions = {}

--- This is what is used for the stored data
---@type table<hood.TextureFormat, number>
glConversions.internalTextureFormat = {
	[hood.TextureFormat.Rgba8UNorm] = gl.RGBA8,
	[hood.TextureFormat.Depth24Plus] = gl.DEPTH_COMPONENT24,
}

--- This is whats used to access the data
---@type table<hood.TextureFormat, number>
glConversions.textureFormat = {
	[hood.TextureFormat.Rgba8UNorm] = gl.RGBA,
}

--- Gets texture type of format
---@type table<hood.TextureFormat, number>
glConversions.textureType = {
	[hood.TextureFormat.Rgba8UNorm] = gl.UNSIGNED_BYTE,
}

return glConversions
