local test = require("lde-test")
local core = require("hood-core")

test.it("VertexLayout: starts with empty attributes", function()
	test.equal(#core.VertexLayout.new().attributes, 0)
end)

test.it("VertexLayout: empty layout has zero stride", function()
	test.equal(core.VertexLayout.new():getStride(), 0)
end)

test.it("VertexLayout: withAttribute returns self for chaining", function()
	local layout = core.VertexLayout.new()
	test.equal(layout:withAttribute({ type = "f32", size = 1, offset = 0 }), layout)
end)

test.it("VertexLayout: withAttribute stores the attribute", function()
	local layout = core.VertexLayout.new()
		:withAttribute({ type = "f32", size = 3, offset = 0 })
	test.equal(#layout.attributes, 1)
	test.equal(layout.attributes[1].type, "f32")
	test.equal(layout.attributes[1].size, 3)
end)

-- Every component size the layout knows, at one component each.
test.it("VertexLayout: stride is the component size times the count", function()
	---@type table<string, number>
	local expected = { f32 = 4, i32 = 4, u32 = 4, f16 = 2, i16 = 2, u16 = 2, i8 = 1, u8 = 1 }

	for type, size in pairs(expected) do
		---@cast type string
		---@cast size number
		for count = 1, 4 do
			local layout = core.VertexLayout.new()
				:withAttribute({ type = type, size = count, offset = 0 })
			test.equal(layout:getStride(), size * count, type .. " x" .. count)
		end
	end
end)

test.it("VertexLayout: stride is the furthest attribute end, not the last one added", function()
	-- pos f32x3 at 0 ends at 12; colour f32x4 at 12 ends at 28.
	local interleaved = core.VertexLayout.new()
		:withAttribute({ type = "f32", size = 3, offset = 0 })
		:withAttribute({ type = "f32", size = 4, offset = 12 })
	test.equal(interleaved:getStride(), 28)

	-- Out of order: the first attribute is the one that reaches furthest.
	local outOfOrder = core.VertexLayout.new()
		:withAttribute({ type = "f32", size = 4, offset = 0 })  -- ends at 16
		:withAttribute({ type = "f32", size = 1, offset = 4 })  -- ends at  8
	test.equal(outOfOrder:getStride(), 16)

	-- A lone attribute at a non-zero offset is measured from the buffer's start.
	local offset = core.VertexLayout.new()
		:withAttribute({ type = "f32", size = 1, offset = 20 })
	test.equal(offset:getStride(), 24)
end)

test.it("VertexLayout: instance rate is what the layout was asked for", function()
	local layout = core.VertexLayout.new()
	test.equal(layout:isInstanceRate(), false)
	test.equal(layout:withInstanceRate():isInstanceRate(), true)
	test.equal(layout.stepMode, "instance")
end)

test.it("VertexLayout: manual stride field overrides computed value", function()
	local layout = core.VertexLayout.new()
	layout.stride = 48
	layout:withAttribute({ type = "f32", size = 3, offset = 0 })  -- would be 12
	test.equal(layout:getStride(), 48)
end)

test.it("VertexLayout: getStride errors on unknown attribute type", function()
	local layout = core.VertexLayout.new()
		:withAttribute({ type = "vec3", size = 3, offset = 0 })
	local ok = pcall(function() layout:getStride() end)
	test.equal(ok, false)
end)

-- ─── resolveLocations ─────────────────────────────────────────────────────────
--- Locations run across every layout in a pipeline, and an attribute may name its own, which
--- is what keeps a declaration's order from having to match the shader's.

test.it("resolveLocations: numbers attributes across buffers in declaration order", function()
	local positions = core.VertexLayout.new()
		:withAttribute({ type = "f32", size = 3, offset = 0 })
	local colours = core.VertexLayout.new()
		:withAttribute({ type = "f32", size = 4, offset = 0 })
		:withAttribute({ type = "f32", size = 2, offset = 16 })

	local resolved = core.VertexLayout.resolveLocations({ positions, colours })

	test.equal(#resolved, 3)
	test.equal(resolved[1].location, 0)
	test.equal(resolved[1].bufferIndex, 1)
	test.equal(resolved[2].location, 1)
	test.equal(resolved[2].bufferIndex, 2)
	test.equal(resolved[3].location, 2)
	test.equal(resolved[2].attribute.size, 4)
end)

test.it("resolveLocations: an attribute that names its own location keeps it", function()
	local layout = core.VertexLayout.new()
		:withAttribute({ type = "f32", size = 3, offset = 0 })
		:withAttribute({ type = "f32", size = 4, offset = 12, location = 5 })

	local resolved = core.VertexLayout.resolveLocations({ layout })

	-- The explicit one is 5; the one before it still took 0, and it does not shift the rest.
	test.equal(resolved[1].location, 0)
	test.equal(resolved[2].location, 5)
end)

test.it("resolveLocations: no layouts resolve to no attributes", function()
	test.equal(#core.VertexLayout.resolveLocations({}), 0)
end)

-- ─── Layout helpers ───────────────────────────────────────────────────────────
--- The helpers both backends reach for, so they are checked where they are defined.

test.it("Layout.isDepthFormat: only depth formats are depth", function()
	test.equal(core.Layout.isDepthFormat("depth16unorm"), true)
	test.equal(core.Layout.isDepthFormat("depth24plus"), true)
	test.equal(core.Layout.isDepthFormat("depth32float"), true)
	test.equal(core.Layout.isDepthFormat("rgba8unorm"), false)
	test.equal(core.Layout.isDepthFormat("bgra8unorm-srgb"), false)
end)

test.it("Layout.assertWriteFits: a write that fits is accepted", function()
	local buffer = { descriptor = { size = 16, usages = { "VERTEX" } } }
	core.Layout.assertWriteFits(buffer, 16, 0, nil)
	core.Layout.assertWriteFits(buffer, 8, 8, nil)
	test.equal(true, true)
end)

test.it("Layout.assertWriteFits: a write past the end is refused, and says why", function()
	local buffer = { descriptor = { size = 16, usages = { "VERTEX", "COPY_DST" } } }

	local ok, err = pcall(core.Layout.assertWriteFits, buffer, 32, 0, nil)
	test.equal(ok, false)
	test.truthy(tostring(err):match("32 bytes at offset 0 exceeds the 16 byte buffer"))
	test.truthy(tostring(err):match("VERTEX, COPY_DST"))

	local negative = pcall(core.Layout.assertWriteFits, buffer, 8, -1, nil)
	test.equal(negative, false)
end)

test.it("Layout.assertWriteFits: a source smaller than the size is refused", function()
	local buffer = { descriptor = { size = 64, usages = { "MAP_READ" } } }
	local small = require("ffi").new("uint8_t[8]")

	local ok, err = pcall(core.Layout.assertWriteFits, buffer, 16, 0, small)
	test.equal(ok, false)
	test.truthy(tostring(err):match("reads past the end of its 8 byte source"))
end)
