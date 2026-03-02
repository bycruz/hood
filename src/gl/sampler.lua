local gl = require("glapi")
local glConversions = require("hood.convert.gl")

local ffi = require("ffi")

---@class hood.gl.Sampler
---@field id number
local GLSampler = {}
GLSampler.__index = GLSampler

---@param desc hood.SamplerDescriptor
function GLSampler.new(desc)
	local id = gl.genSamplers(1)[1]

	gl.samplerParameteri(id, gl.TEXTURE_WRAP_S, glConversions.addressMode[desc.addressModeU])
	gl.samplerParameteri(id, gl.TEXTURE_WRAP_T, glConversions.addressMode[desc.addressModeV])
	gl.samplerParameteri(id, gl.TEXTURE_WRAP_R, glConversions.addressMode[desc.addressModeW])

	gl.samplerParameteri(id, gl.TEXTURE_MIN_FILTER, glConversions.filterMode[desc.minFilter])
	gl.samplerParameteri(id, gl.TEXTURE_MAG_FILTER, glConversions.filterMode[desc.magFilter])

	if desc.lodMinClamp then
		gl.samplerParameterf(id, gl.TEXTURE_MIN_LOD, desc.lodMinClamp)
	end

	if desc.lodMaxClamp then
		gl.samplerParameterf(id, gl.TEXTURE_MAX_LOD, desc.lodMaxClamp)
	end

	if desc.compareOp then
		gl.samplerParameteri(id, gl.TEXTURE_COMPARE_MODE, gl.COMPARE_REF_TO_TEXTURE)
		gl.samplerParameteri(id, gl.TEXTURE_COMPARE_FUNC, glConversions.compareFunction[desc.compareOp])
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
