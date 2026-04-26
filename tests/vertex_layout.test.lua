local test = require("lde-test")
local hood = require("hood")

test.it("VertexLayout: starts with empty attributes", function()
	test.equal(#hood.VertexLayout.new().attributes, 0)
end)

test.it("VertexLayout: empty layout has zero stride", function()
	test.equal(hood.VertexLayout.new():getStride(), 0)
end)

test.it("VertexLayout: withAttribute returns self for chaining", function()
	local layout = hood.VertexLayout.new()
	test.equal(layout:withAttribute({ type = "f32", size = 1, offset = 0 }), layout)
end)

test.it("VertexLayout: withAttribute stores the attribute", function()
	local layout = hood.VertexLayout.new()
		:withAttribute({ type = "f32", size = 3, offset = 0 })
	test.equal(#layout.attributes, 1)
	test.equal(layout.attributes[1].type, "f32")
	test.equal(layout.attributes[1].size, 3)
end)

test.it("VertexLayout: f32 scalar (size 1) stride is 4", function()
	local layout = hood.VertexLayout.new()
		:withAttribute({ type = "f32", size = 1, offset = 0 })
	test.equal(layout:getStride(), 4)
end)

test.it("VertexLayout: f32 vec3 (size 3) stride is 12", function()
	local layout = hood.VertexLayout.new()
		:withAttribute({ type = "f32", size = 3, offset = 0 })
	test.equal(layout:getStride(), 12)
end)

test.it("VertexLayout: f32 vec4 (size 4) stride is 16", function()
	local layout = hood.VertexLayout.new()
		:withAttribute({ type = "f32", size = 4, offset = 0 })
	test.equal(layout:getStride(), 16)
end)

test.it("VertexLayout: i32 scalar (size 1) stride is 4", function()
	local layout = hood.VertexLayout.new()
		:withAttribute({ type = "i32", size = 1, offset = 0 })
	test.equal(layout:getStride(), 4)
end)

test.it("VertexLayout: i32 vec2 (size 2) stride is 8", function()
	local layout = hood.VertexLayout.new()
		:withAttribute({ type = "i32", size = 2, offset = 0 })
	test.equal(layout:getStride(), 8)
end)

test.it("VertexLayout: interleaved pos(vec3)+color(vec4) stride is 28", function()
	-- pos f32x3 at offset 0 ends at 12; color f32x4 at offset 12 ends at 28
	local layout = hood.VertexLayout.new()
		:withAttribute({ type = "f32", size = 3, offset = 0 })
		:withAttribute({ type = "f32", size = 4, offset = 12 })
	test.equal(layout:getStride(), 28)
end)

test.it("VertexLayout: stride is max attribute end, not just the last one added", function()
	-- First attribute ends at 16, second at 8 — stride must be 16
	local layout = hood.VertexLayout.new()
		:withAttribute({ type = "f32", size = 4, offset = 0 })  -- ends at 16
		:withAttribute({ type = "f32", size = 1, offset = 4 })  -- ends at  8
	test.equal(layout:getStride(), 16)
end)

test.it("VertexLayout: non-zero attribute offset shifts the end boundary", function()
	-- A single f32 scalar at offset 20 ends at 24
	local layout = hood.VertexLayout.new()
		:withAttribute({ type = "f32", size = 1, offset = 20 })
	test.equal(layout:getStride(), 24)
end)

test.it("VertexLayout: manual stride field overrides computed value", function()
	local layout = hood.VertexLayout.new()
	layout.stride = 48
	layout:withAttribute({ type = "f32", size = 3, offset = 0 })  -- would be 12
	test.equal(layout:getStride(), 48)
end)

test.it("VertexLayout: getStride errors on unknown attribute type", function()
	local layout = hood.VertexLayout.new()
		:withAttribute({ type = "vec3", size = 3, offset = 0 })
	local ok = pcall(function() layout:getStride() end)
	test.equal(ok, false)
end)
