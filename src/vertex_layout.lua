local ffi = require("ffi")

---@alias hood.VertexLayout.AttributeType "f32" | "i32"
---@alias hood.VertexLayout.Attribute { type: "f32" | "i32", size: number, offset: number, normalized: boolean }

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

function VertexLayout:getStride()
	if self.stride and self.stride > 0 then
		return self.stride
	end

	local maxEnd = 0
	for _, attr in ipairs(self.attributes) do
		local typeSize
		if attr.type == "f32" then
			typeSize = ffi.sizeof("float")
		elseif attr.type == "i32" then
			typeSize = ffi.sizeof("int32_t")
		else
			error("Unknown attribute type: " .. tostring(attr.type))
		end

		local attrEnd = attr.offset + (typeSize * attr.size)
		maxEnd = math.max(maxEnd, attrEnd)
	end

	return maxEnd
end

return VertexLayout
