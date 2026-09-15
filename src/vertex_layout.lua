local ffi = require("ffi")

---@alias hood.VertexLayout.AttributeType "f32" | "f16" | "i32" | "u32" | "i16" | "u16" | "i8" | "u8"
--- The shader location is the attribute's position in the layout unless it
--- names one, so a layout can be written in whatever order reads best.
---@alias hood.VertexLayout.Attribute { type: hood.VertexLayout.AttributeType, size: number, offset: number, normalized: boolean, location: number? }

--- "vertex" advances one element per vertex, "instance" one element per
--- instance, which is what lets one draw reuse the same vertices for many
--- copies of them.
---@alias hood.VertexLayout.StepMode "vertex" | "instance"

---@class hood.VertexLayout
---@field attributes hood.VertexLayout.Attribute[]
---@field stride number?
---@field stepMode hood.VertexLayout.StepMode
local VertexLayout = {}
VertexLayout.__index = VertexLayout

---@param descriptor { stride: number?, stepMode: hood.VertexLayout.StepMode }?
function VertexLayout.new(descriptor)
	descriptor = descriptor or {}

	return setmetatable({
		attributes = {},
		stride = descriptor.stride or 0,
		stepMode = descriptor.stepMode or "vertex",
	}, VertexLayout)
end

---@param attribute hood.VertexLayout.Attribute
function VertexLayout:withAttribute(attribute)
	table.insert(self.attributes, attribute)
	return self
end

--- Mark this layout as per-instance data: a draw advances through it once per
--- instance rather than once per vertex.
function VertexLayout:withInstanceRate()
	self.stepMode = "instance"
	return self
end

---@return boolean
function VertexLayout:isInstanceRate()
	return self.stepMode == "instance"
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
