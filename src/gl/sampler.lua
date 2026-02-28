local gl = require("glapi")
local hood = require("hood")
local ffi = require("ffi")

---@class hood.gl.Sampler
---@field id number
local GLSampler = {}
GLSampler.__index = GLSampler

local addressModesMap = {
	[hood.AddressMode.ClampToEdge] = gl.CLAMP_TO_EDGE,
	[hood.AddressMode.Repeat] = gl.REPEAT,
	[hood.AddressMode.MirroredRepeat] = gl.MIRRORED_REPEAT,
}

local filterModesMap = {
	[hood.FilterMode.Nearest] = gl.NEAREST,
	[hood.FilterMode.Linear] = gl.LINEAR,
}

local compareFnsMap = {
	[hood.CompareFunction.Never] = gl.NEVER,
	[hood.CompareFunction.Less] = gl.LESS,
	[hood.CompareFunction.Equal] = gl.EQUAL,
	[hood.CompareFunction.LessEqual] = gl.LESS_EQUAL,
	[hood.CompareFunction.Greater] = gl.GREATER,
	[hood.CompareFunction.NotEqual] = gl.NOTEQUAL,
	[hood.CompareFunction.GreaterEqual] = gl.GREATER_EQUAL,
	[hood.CompareFunction.Always] = gl.ALWAYS,
}

---@param desc hood.SamplerDescriptor
function GLSampler.new(desc)
	local id = gl.genSamplers(1)[1]

	gl.samplerParameteri(id, gl.TEXTURE_WRAP_S, addressModesMap[desc.addressModeU])
	gl.samplerParameteri(id, gl.TEXTURE_WRAP_T, addressModesMap[desc.addressModeV])
	gl.samplerParameteri(id, gl.TEXTURE_WRAP_R, addressModesMap[desc.addressModeW])

	gl.samplerParameteri(id, gl.TEXTURE_MIN_FILTER, filterModesMap[desc.minFilter])
	gl.samplerParameteri(id, gl.TEXTURE_MAG_FILTER, filterModesMap[desc.magFilter])

	if desc.lodMinClamp then
		gl.samplerParameterf(id, gl.TEXTURE_MIN_LOD, desc.lodMinClamp)
	end

	if desc.lodMaxClamp then
		gl.samplerParameterf(id, gl.TEXTURE_MAX_LOD, desc.lodMaxClamp)
	end

	if desc.compareOp then
		gl.samplerParameteri(id, gl.TEXTURE_COMPARE_MODE, gl.COMPARE_REF_TO_TEXTURE)
		gl.samplerParameteri(id, gl.TEXTURE_COMPARE_FUNC, compareFnsMap[desc.compareOp])
	else
		gl.samplerParameteri(id, gl.TEXTURE_COMPARE_MODE, gl.NONE)
	end

	if desc.maxAnisotropy then
		gl.samplerParameterf(id, gl.TEXTURE_MAX_ANISOTROPY, desc.maxAnisotropy)
	end

	return setmetatable({ id = id }, GLSampler)
end

function GLSampler:destroy()
	gl.deleteSamplers(1, ffi.new("GLuint[1]", self.id))
end

return GLSampler
