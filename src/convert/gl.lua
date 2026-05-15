local gl = require("glapi")

local glConversions = {}

--- This is what is used for the stored data
---@type table<hood.TextureFormat, number>
glConversions.internalTextureFormat = {
	["rgba8unorm"] = gl.InternalFormat.Rgba8,
	["depth24plus"] = gl.InternalFormat.DepthComponent24,
}

--- This is whats used to access the data
---@type table<hood.TextureFormat, number>
glConversions.textureFormat = {
	["rgba8unorm"] = gl.PixelFormat.Rgba,
}

--- Gets texture type of format
---@type table<hood.TextureFormat, number>
glConversions.textureType = {
	["rgba8unorm"] = gl.DataType.UnsignedByte,
}

---@type table<hood.IndexFormat, number>
glConversions.indexFormat = {
	["u16"] = gl.DataType.UnsignedShort,
	["u32"] = gl.DataType.UnsignedInt,
}

---@type table<hood.StorageAccess, number>
glConversions.storageAccess = {
	["READ_ONLY"] = gl.BufferAccess.ReadOnly,
	["WRITE_ONLY"] = gl.BufferAccess.WriteOnly,
	["READ_WRITE"] = gl.BufferAccess.ReadWrite,
}

---@type table<hood.AddressMode, number>
glConversions.addressMode = {
	["clamp-to-edge"] = gl.TextureWrap.ClampToEdge,
	["repeat"] = gl.TextureWrap.Repeat,
	["mirrored-repeat"] = gl.TextureWrap.MirroredRepeat,
}

---@type table<hood.FilterMode, number>
glConversions.filterMode = {
	["nearest"] = gl.TextureFilter.Nearest,
	["linear"] = gl.TextureFilter.Linear,
}

---@type table<hood.CompareFunction, number>
glConversions.compareFunction = {
	["never"] = gl.CompareFunc.Never,
	["less"] = gl.CompareFunc.Less,
	["equal"] = gl.CompareFunc.Equal,
	["less-equal"] = gl.CompareFunc.LessEqual,
	["greater"] = gl.CompareFunc.Greater,
	["not-equal"] = gl.CompareFunc.NotEqual,
	["greater-equal"] = gl.CompareFunc.GreaterEqual,
	["always"] = gl.CompareFunc.Always
}

---@type table<hood.CullMode, number>
glConversions.cullMode = {
	["front"] = gl.CullMode.Front,
	["back"] = gl.CullMode.Back,
}

---@type table<hood.FrontFace, number>
glConversions.frontFace = {
	["clockwise"] = gl.FrontFace.Cw,
	["counter-clockwise"] = gl.FrontFace.Ccw,
}

return glConversions
