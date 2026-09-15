local gl = require("glapi")
local ffi = require("ffi")

---@class hood.gl.VAO
---@field id number
local GLVAO = {}
GLVAO.__index = GLVAO

function GLVAO.new()
	local handle = ffi.new("GLuint[1]")
	gl.createVertexArrays(1, handle)
	return setmetatable({ id = handle[0] }, GLVAO)
end

function GLVAO:bind()
	gl.bindVertexArray(self.id)
end

function GLVAO:unbind()
	gl.bindVertexArray(0)
end

---@param buffer hood.gl.Buffer
---@param descriptor hood.VertexLayout
---@param bindingIndex number?
---@param offset number? byte offset into the buffer
---@param locationBase number? first attribute location this layout owns
function GLVAO:setVertexBuffer(buffer, descriptor, bindingIndex, offset, locationBase)
	bindingIndex = bindingIndex or 0
	offset = offset or 0

	gl.vertexArrayVertexBuffer(self.id, bindingIndex, buffer.id, offset, descriptor:getStride())

	-- Attribute locations are assigned across every layout in the pipeline, in
	-- order, so a second layout does not start at location 0. Deriving them from
	-- the index within this layout alone made a two-buffer pipeline bind both
	-- buffers to the same locations.
	local location = locationBase or 0

	for _, attr in ipairs(descriptor.attributes) do
		local glType
		local normalized = attr.normalized and 1 or 0

		if attr.type == "f32" then
			glType = gl.FLOAT
		elseif attr.type == "i32" then
			glType = gl.INT
		else
			error("Unsupported attribute type: " .. tostring(attr.type))
		end

		gl.enableVertexArrayAttrib(self.id, location)
		gl.vertexArrayAttribFormat(self.id, location, attr.size, glType, normalized, attr.offset)
		gl.vertexArrayAttribBinding(self.id, location, bindingIndex)

		location = location + 1
	end

	-- Divisor 0 advances this binding once per vertex, 1 once per instance.
	gl.vertexArrayBindingDivisor(self.id, bindingIndex, descriptor:isInstanceRate() and 1 or 0)
end

---@param buffer hood.gl.Buffer
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
