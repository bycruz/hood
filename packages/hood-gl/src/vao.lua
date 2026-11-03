local gl = require("glapi") ---@cast gl gl & hood-gl.GlConstants
local ffi = require("ffi")

--- The GL type each attribute type is read as. The integer and half float types
--- let a vertex be packed; `normalized` on the attribute is what asks the
--- hardware to scale them into floats for the shader.
local glAttributeType = {
	f32 = gl.FLOAT,
	i32 = gl.INT,
	u32 = gl.UNSIGNED_INT,
	f16 = gl.HALF_FLOAT,
	i16 = gl.SHORT,
	u16 = gl.UNSIGNED_SHORT,
	i8 = gl.BYTE,
	u8 = gl.UNSIGNED_BYTE,
}

---@class hood-gl.VAO
---@field id number
local GLVAO = {}
GLVAO.__index = GLVAO

function GLVAO.new()
	local handle = ffi.new("GLuint[1]")
	gl.createVertexArrays(1, handle)
	return setmetatable({ id = handle[0] }, GLVAO)
end

---@param self hood-gl.VAO
function GLVAO:bind()
	gl.bindVertexArray(self.id)
end

function GLVAO:unbind()
	gl.bindVertexArray(0)
end

---@param buffer hood-gl.Buffer
---@param descriptor hood.VertexLayout
---@param bindingIndex number?
---@param offset number? byte offset into the buffer
---@param attributes hood.VertexLayout.ResolvedAttribute[]? every attribute of the pipeline, resolved
---@param self hood-gl.VAO
function GLVAO:setVertexBuffer(buffer, descriptor, bindingIndex, offset, attributes)
	bindingIndex = bindingIndex or 0
	offset = offset or 0

	gl.vertexArrayVertexBuffer(self.id, bindingIndex, buffer.id, offset, descriptor:getStride())

	-- Locations run across every layout in the pipeline and an attribute may name its own, so
	-- they are resolved together rather than counted per layout; this binding takes the ones
	-- that belong to it.
	for _, resolved in ipairs(attributes or {}) do
		if resolved.bufferIndex - 1 == bindingIndex then
			local attr = resolved.attribute
			local glType = glAttributeType[attr.type]

			if not glType then
				error("Unsupported attribute type: " .. tostring(attr.type))
			end

			gl.enableVertexArrayAttrib(self.id, resolved.location)
			gl.vertexArrayAttribFormat(self.id, resolved.location, attr.size, glType, attr.normalized and 1 or 0, attr.offset)
			gl.vertexArrayAttribBinding(self.id, resolved.location, bindingIndex)
		end
	end

	-- Divisor 0 advances this binding once per vertex, 1 once per instance.
	gl.vertexArrayBindingDivisor(self.id, bindingIndex, descriptor:isInstanceRate() and 1 or 0)
end

---@param buffer hood-gl.Buffer
---@param self hood-gl.VAO
function GLVAO:setIndexBuffer(buffer)
	gl.vertexArrayElementBuffer(self.id, buffer.id)
end

function GLVAO:destroy()
	local handle = ffi.new("GLuint[1]", self.id)
	gl.deleteVertexArrays(1, handle)
	self.id = 0
end

function GLVAO:__tostring()
	if not gl.isVertexArray(self.id) then
		return "GLVAO(NULL)"
	end

	return "GLVAO(" .. tostring(self.id) .. ")"
end

return GLVAO
