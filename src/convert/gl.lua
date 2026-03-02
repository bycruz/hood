local gl = require("glapi")

local glConversions = {}

--- This is what is used for the stored data
---@type table<hood.TextureFormat, number>
glConversions.internalTextureFormat = {
	["rgba8unorm"] = gl.RGBA8,
	["depth24plus"] = gl.DEPTH_COMPONENT24,
}

--- This is whats used to access the data
---@type table<hood.TextureFormat, number>
glConversions.textureFormat = {
	["rgba8unorm"] = gl.RGBA,
}

--- Gets texture type of format
---@type table<hood.TextureFormat, number>
glConversions.textureType = {
	["rgba8unorm"] = gl.UNSIGNED_BYTE,
}

---@type table<hood.IndexFormat, number>
glConversions.indexFormat = {
	["u16"] = gl.UNSIGNED_SHORT,
	["u32"] = gl.UNSIGNED_INT,
}

---@type table<hood.CompareFunction, number>
glConversions.compareFunction = {
	["never"] = gl.NEVER,
	["less"] = gl.LESS,
	["equal"] = gl.EQUAL,
	["less-equal"] = gl.LEQUAL,
	["greater"] = gl.GREATER,
	["not-equal"] = gl.NOTEQUAL,
	["greater-equal"] = gl.GEQUAL,
	["always"] = gl.ALWAYS,
}

---@type table<hood.StorageAccess, number>
glConversions.storageAccess = {
	["READ_ONLY"] = gl.READ_ONLY,
	["WRITE_ONLY"] = gl.WRITE_ONLY,
	["READ_WRITE"] = gl.READ_WRITE,
}

---@type table<hood.AddressMode, number>
glConversions.addressMode = {
	["clamp-to-edge"] = gl.CLAMP_TO_EDGE,
	["repeat"] = gl.REPEAT,
	["mirrored-repeat"] = gl.MIRRORED_REPEAT,
}

---@type table<hood.FilterMode, number>
glConversions.filterMode = {
	["nearest"] = gl.NEAREST,
	["linear"] = gl.LINEAR,
}

---@type table<hood.CompareFunction, number>
glConversions.compareFunction = {
	["never"] = gl.NEVER,
	["less"] = gl.LESS,
	["equal"] = gl.EQUAL,
	["less-equal"] = gl.LESS_EQUAL,
	["greater"] = gl.GREATER,
	["not-equal"] = gl.NOTEQUAL,
	["greater-equal"] = gl.GREATER_EQUAL,
	["always"] = gl.ALWAYS,
}

return glConversions
