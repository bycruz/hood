local ffi = require("ffi")

---@class hood.Layout
local layout = {}

---@type table<hood.TextureFormat, boolean>
local depthFormats = {
	["depth16unorm"] = true,
	["depth24plus"] = true,
	["depth32float"] = true,
}

---@param format hood.TextureFormat
---@return boolean
function layout.isDepthFormat(format)
	return depthFormats[format] == true
end

--- Reject a write that does not fit its buffer, before it reaches a driver.
---
--- Neither vkCmdCopyBuffer nor glNamedBufferSubData bounds checks its destination: an
--- oversized write lands in whatever the driver placed after the buffer and surfaces later
--- as corrupted rendering or a device loss, pointing at nothing.
---@param buffer { descriptor: hood.BufferDescriptor }
---@param size number bytes to write
---@param offset number? byte offset into the buffer, defaults to 0
---@param data ffi.cdata*? source data, checked when its size is knowable
function layout.assertWriteFits(buffer, size, offset, data)
	offset = offset or 0

	if size < 0 or offset < 0 then
		error(string.format(
			"hood: buffer write has a negative size (%s) or offset (%s)",
			tostring(size), tostring(offset)))
	end

	local capacity = buffer.descriptor.size

	if offset + size > capacity then
		error(string.format(
			"hood: buffer write of %d bytes at offset %d exceeds the %d byte buffer [%s]",
			size, offset, capacity,
			table.concat(buffer.descriptor.usages, ", ")))
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

return layout
