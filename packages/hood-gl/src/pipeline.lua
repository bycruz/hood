local gl = require("glapi") ---@cast gl gl & hood-gl.GlConstants
local ffi = require("ffi")

local GLProgram = require("hood-gl.program")

---@class hood-gl.Pipeline
---@field fragment hood.FragmentState
---@field vertex hood.VertexState
---@field depthStencil? hood.DepthStencilState
---@field primitive? hood.PrimitiveState
local GLPipeline = {}
GLPipeline.__index = GLPipeline

---@param device hood-gl.Device
---@param descriptor hood.PipelineDescriptor
function GLPipeline.new(device, descriptor)
	if descriptor.vertex.module.type ~= "glsl" or descriptor.fragment.module.type ~= "glsl" then
		error("Only GLSL shaders are supported in the OpenGL backend.")
	end

	return setmetatable({
		fragment = descriptor.fragment,
		vertex = descriptor.vertex,
		depthStencil = descriptor.depthStencil,
		primitive = descriptor.primitive,
	}, GLPipeline)
end

---@class hood-gl.RawPipeline
---@field id number
local GLRawPipeline = {}
GLRawPipeline.__index = GLRawPipeline

function GLRawPipeline.new(id)
	return setmetatable({ id = id }, GLRawPipeline)
end

--- Built for the current context rather than at creation: contexts cannot share pipelines.
---@return hood-gl.RawPipeline
---@param self hood-gl.Pipeline
function GLPipeline:genForCurrentContext()
	local pipeline = gl.genProgramPipelines(1)[1]

	do -- Vertex
		local program = GLProgram.new(gl.ShaderType.Vertex, self.vertex.module.source)
		gl.useProgramStages(pipeline, gl.VERTEX_SHADER_BIT, program.id)
	end

	do -- Fragment
		local program = GLProgram.new(gl.ShaderType.Fragment, self.fragment.module.source)
		gl.useProgramStages(pipeline, gl.FRAGMENT_SHADER_BIT, program.id)
	end

	return GLRawPipeline.new(pipeline)
end

---@param self hood-gl.RawPipeline
function GLRawPipeline:bind()
	gl.bindProgramPipeline(self.id)
end

function GLRawPipeline:destroy()
	gl.deleteProgramPipelines(1, ffi.new("GLuint[1]", self.id))
end

--- A pipeline here is the descriptor it was made from. What GL has is a program pipeline per
--- context, made when first drawn with and freed with that context.
function GLPipeline:destroy()
	self.vertex, self.fragment = nil --[[@as hood.VertexState]], nil --[[@as hood.FragmentState]]
	self.depthStencil, self.primitive = nil, nil
end

---@param self hood-gl.RawPipeline
function GLRawPipeline:__tostring()
	return "GLRawPipeline(" .. tostring(self.id) .. ")"
end

return GLPipeline
