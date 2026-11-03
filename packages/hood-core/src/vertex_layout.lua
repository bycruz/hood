local ffi = require("ffi")

---@alias hood.VertexLayout.AttributeType "f32" | "f16" | "i32" | "u32" | "i16" | "u16" | "i8" | "u8"
--- Location defaults to the attribute's position, and an attribute may name its own.
---@alias hood.VertexLayout.Attribute { type: hood.VertexLayout.AttributeType, size: number, offset: number, normalized: boolean?, location: number? }

--- "vertex" advances per vertex and "instance" per instance.
---@alias hood.VertexLayout.StepMode "vertex" | "instance"

---@class hood.VertexLayout.ResolvedAttribute
---@field attribute hood.VertexLayout.Attribute
---@field bufferIndex number
---@field location number

---@class hood.VertexLayout
---@field new fun(descriptor?: { stride: number?, stepMode: hood.VertexLayout.StepMode }): hood.VertexLayout
---@field withAttribute fun(self: hood.VertexLayout, attribute: hood.VertexLayout.Attribute): hood.VertexLayout
---@field withInstanceRate fun(self: hood.VertexLayout): hood.VertexLayout
---@field isInstanceRate fun(self: hood.VertexLayout): boolean
---@field getStride fun(self: hood.VertexLayout): number
---@field resolveLocations fun(buffers: hood.VertexLayout[]): hood.VertexLayout.ResolvedAttribute[]
---@field attributes hood.VertexLayout.Attribute[]
---@field stride number?
---@field stepMode hood.VertexLayout.StepMode
local VertexLayout = {}
VertexLayout.__index = VertexLayout

---@param descriptor { stride: number?, stepMode: hood.VertexLayout.StepMode }?
---@return hood.VertexLayout
function VertexLayout.new(descriptor)
	descriptor = descriptor or {}

	return setmetatable({
		attributes = {},
		stride = descriptor.stride or 0,
		stepMode = descriptor.stepMode or "vertex",
	}, VertexLayout)
end

---@param attribute hood.VertexLayout.Attribute
---@param self hood.VertexLayout
---@return hood.VertexLayout
function VertexLayout:withAttribute(attribute)
	table.insert(self.attributes, attribute)
	return self
end

--- Mark this layout as per-instance data.
---@param self hood.VertexLayout
---@return hood.VertexLayout
function VertexLayout:withInstanceRate()
	self.stepMode = "instance"
	return self
end

---@return boolean
---@param self hood.VertexLayout
function VertexLayout:isInstanceRate()
	return self.stepMode == "instance"
end

--- Flatten several layouts into the attributes a pipeline reads, in declaration order.
--- Locations run on across every layout, and an attribute that names its own does not
--- consume a sequential one.
---@param buffers hood.VertexLayout[]
---@return hood.VertexLayout.ResolvedAttribute[]
function VertexLayout.resolveLocations(buffers)
	local resolved = {}

	for bufferIndex, buffer in ipairs(buffers) do
		for _, attribute in ipairs(buffer.attributes) do
			resolved[#resolved + 1] = {
				attribute = attribute,
				bufferIndex = bufferIndex,
				location = attribute.location or #resolved,
			}
		end
	end

	return resolved
end

--- Bytes one component of each attribute type takes.
local componentSize = {
	f32 = ffi.sizeof("float"),
	i32 = ffi.sizeof("int32_t"),
	u32 = ffi.sizeof("uint32_t"),
	f16 = 2,
	i16 = 2,
	u16 = 2,
	i8 = 1,
	u8 = 1,
}

---@param self hood.VertexLayout
---@return number
function VertexLayout:getStride()
	if self.stride and self.stride > 0 then
		return self.stride
	end

	local maxEnd = 0
	for _, attr in ipairs(self.attributes) do
		local typeSize = componentSize[attr.type]
		if not typeSize then
			error("Unknown attribute type: " .. tostring(attr.type))
		end

		local attrEnd = attr.offset + (typeSize * attr.size)
		maxEnd = math.max(maxEnd, attrEnd)
	end

	return maxEnd
end

return VertexLayout
