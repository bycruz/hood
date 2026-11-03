local gl = require("glapi") ---@cast gl gl & hood-gl.GlConstants
local ffi = require("ffi")

---@class hood-gl.Buffer
---@field id number
---@field isUniform boolean
---@field isStorage boolean
---@field descriptor hood.BufferDescriptor
---@field _mappedPtr ffi.cdata*?
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
---@param self hood-gl.Buffer
function GLBuffer:setSlice(size, data, offset)
	gl.namedBufferSubData(self.id, offset or 0, size, data)
end

---@param size number bytes to write
---@param offset number? byte offset into the buffer, defaults to 0
---@param data ffi.cdata*? source data, checked when its size is knowable
function GLBuffer:assertWriteFits(size, offset, data)
	offset = offset or 0

	if size < 0 or offset < 0 then
		error(string.format(
			"hood: buffer write has a negative size (%s) or offset (%s)",
			tostring(size), tostring(offset)))
	end

	if offset + size > self.descriptor.size then
		error(string.format(
			"hood: buffer write of %d bytes at offset %d exceeds the %d byte buffer [%s]",
			size, offset, self.descriptor.size,
			table.concat(self.descriptor.usages, ", ")))
	end

	if data ~= nil then
		local ok, sourceSize = pcall(ffi.sizeof, data)
		if ok and type(sourceSize) == "number" and sourceSize < size then
			error(string.format(
				"hood: buffer write of %d bytes reads past the end of its %d byte source",
				size, sourceSize))
		end
	end
end

--- Signal that the CPU will read this back. The caller must still wait for the GPU first.
---@param self hood-gl.Buffer
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

---@param self hood-gl.Buffer
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

---@param self hood-gl.Buffer
function GLBuffer:__tostring()
	if not gl.isBuffer(self.id) then
		return "GLBuffer(NULL)"
	end

	return "GLBuffer(" .. tostring(self.id) .. ")"
end

return GLBuffer
