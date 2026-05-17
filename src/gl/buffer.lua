local gl = require("glapi")
local ffi = require("ffi")

---@class hood.gl.Buffer
---@field id number
---@field isUniform boolean
---@field isStorage boolean
---@field descriptor hood.BufferDescriptor
local GLBuffer = {}
GLBuffer.__index = GLBuffer

---@param descriptor hood.BufferDescriptor
function GLBuffer.new(descriptor)
	local handle = ffi.new("GLuint[1]")
	gl.createBuffers(1, handle)

	-- Allocate the buffer (might be necessary for setSlice to work)
	gl.namedBufferData(handle[0], descriptor.size, nil, gl.DYNAMIC_DRAW)

	local isUniform, isStorage = false, false
	for _, usage in ipairs(descriptor.usages) do
		if usage == "UNIFORM" then
			isUniform = true
			break
		end

		if usage == "STORAGE" then
			isStorage = true
			break
		end
	end

	return setmetatable({
		id = handle[0],
		isUniform = isUniform,
		isStorage = isStorage,
		descriptor = descriptor,
	}, GLBuffer)
end

---@param size number
---@param data ffi.cdata*
---@param offset number?
function GLBuffer:setSlice(size, data, offset)
	gl.namedBufferSubData(self.id, offset or 0, size, data)
end

--- Signal that the buffer will be read back by the CPU.
--- Caller must ensure GPU work is complete (e.g. queue:waitIdle) before this.
function GLBuffer:mapAsync()
	gl.finish()
end

---@param offset number?
---@param size number?
---@return ffi.cdata*
function GLBuffer:getMappedRange(offset, size)
	offset = offset or 0
	local mapSize = size or (self.descriptor.size - offset)
	self._mappedPtr = gl.mapNamedBufferRange(self.id, offset, mapSize, gl.MapBit.Read)
	if self._mappedPtr == nil then
		error("Failed to map buffer range")
	end
	return self._mappedPtr
end

function GLBuffer:unmap()
	if self._mappedPtr then
		gl.unmapNamedBuffer(self.id)
		self._mappedPtr = nil
	end
end

function GLBuffer:destroy()
	self:unmap()
	gl.deleteBuffers(1, ffi.new("GLuint[1]", self.id))
end

function GLBuffer:__tostring()
	if not gl.isBuffer(self.id) then
		return "GLBuffer(NULL)"
	end

	return "GLBuffer(" .. tostring(self.id) .. ")"
end

return GLBuffer
