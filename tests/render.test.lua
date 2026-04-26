local ffi = require("ffi")
local test = require("lde-test")
local hood = require("hood")
local glslc = require("tests.fixtures.glslc")
local makeCtx = require("tests.fixtures.context")

-- Shaders compiled once at module load; results are cached to disk by glslc fixture.
local vertSpv = glslc.compile([[
#version 430 core
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec4 aColor;
layout(location = 0) out vec4 vColor;
void main() {
    gl_Position = vec4(aPos, 1.0);
    vColor = aColor;
}
]], "vert")

local fragSpv = glslc.compile([[
#version 430 core
layout(location = 0) in vec4 vColor;
layout(location = 0) out vec4 fragColor;
void main() {
    fragColor = vColor;
}
]], "frag")

local W, H = 64, 64
local ctx = makeCtx.new(W, H)

local vertexLayout = hood.VertexLayout.new()
	:withAttribute({ type = "f32", size = 3, offset = 0 })
	:withAttribute({ type = "f32", size = 4, offset = 12 })

local function makePipeline(depthStencil)
	return ctx.device:createPipeline({
		layout = ctx.device:createBindGroupLayout({}),
		vertex = {
			module = { type = "spirv", source = vertSpv },
			buffers = { vertexLayout },
		},
		fragment = {
			module = { type = "spirv", source = fragSpv },
			targets = { {
				format = "rgba8unorm",
				blend = "alpha-blending",
				writeMask = hood.ColorWrites.All,
			} },
		},
		depthStencil = depthStencil,
	})
end

local pipeline = makePipeline()

-- Triangle: top=red, bottom-left=green, bottom-right=blue (NDC coords)
local triVerts = ffi.new("float[21]", {
	 0.0,  0.5, 0.0,  1.0, 0.0, 0.0, 1.0,
	-0.5, -0.5, 0.0,  0.0, 1.0, 0.0, 1.0,
	 0.5, -0.5, 0.0,  0.0, 0.0, 1.0, 1.0,
})
local triIndices = ffi.new("uint32_t[3]", { 0, 1, 2 })

local triVbuf = ctx.device:createBuffer({
	size = vertexLayout:getStride() * 3,
	usages = { "VERTEX", "COPY_DST" },
})
local triIbuf = ctx.device:createBuffer({
	size = ffi.sizeof("uint32_t") * 3,
	usages = { "INDEX", "COPY_DST" },
})
ctx.device.queue:writeBuffer(triVbuf, ffi.sizeof(triVerts), triVerts)
ctx.device.queue:writeBuffer(triIbuf, ffi.sizeof(triIndices), triIndices)

local function drawTri(enc)
	enc:setVertexBuffer(0, triVbuf)
	enc:setIndexBuffer(triIbuf, "u32")
	enc:drawIndexed(3, 1)
end

-- Screen-space mapping for a 64x64 target with the inverted-Y Vulkan viewport:
--   screen_x = (NDC_x + 1) * 32
--   screen_y = 64 - (NDC_y + 1) * 32
-- Top vertex (0, 0.5)   → (32, 16)
-- BL vertex (-0.5,-0.5) → (16, 48)
-- BR vertex ( 0.5,-0.5) → (48, 48)

-- ─── Clear colour ────────────────────────────────────────────────────────────

test.it("render: clear to opaque black by default", function()
	local px = ctx:frame({ pipeline = pipeline })
	local r, g, b, a = px.at(0, 0)
	test.equal(r, 0) test.equal(g, 0) test.equal(b, 0) test.equal(a, 255)
	-- check all four corners
	local r2, g2, b2 = px.at(W - 1, H - 1)
	test.equal(r2, 0) test.equal(g2, 0) test.equal(b2, 0)
end)

test.it("render: clear to red fills every sampled pixel", function()
	local px = ctx:frame({ pipeline = pipeline, clearColor = { r = 1, g = 0, b = 0, a = 1 } })
	for _, xy in ipairs({ { 0, 0 }, { W - 1, 0 }, { 0, H - 1 }, { W - 1, H - 1 }, { W / 2, H / 2 } }) do
		local r, g, b = px.at(xy[1], xy[2])
		test.greater(r, 200) test.less(g, 10) test.less(b, 10)
	end
end)

test.it("render: clear to green fills every sampled pixel", function()
	local px = ctx:frame({ pipeline = pipeline, clearColor = { r = 0, g = 1, b = 0, a = 1 } })
	local r, g, b = px.at(W / 2, H / 2)
	test.less(r, 10) test.greater(g, 200) test.less(b, 10)
end)

test.it("render: clear to white produces full-intensity RGBA", function()
	local px = ctx:frame({ pipeline = pipeline, clearColor = { r = 1, g = 1, b = 1, a = 1 } })
	local r, g, b, a = px.at(W / 2, H / 2)
	test.greater(r, 200) test.greater(g, 200) test.greater(b, 200) test.equal(a, 255)
end)

-- ─── Triangle colours ─────────────────────────────────────────────────────────

test.it("render: top vertex of triangle is red", function()
	local px = ctx:frame({ pipeline = pipeline, draw = drawTri })
	-- Sample just below the apex at screen (32, 16)
	local r, g, b = px.at(32, 18)
	test.greater(r, 200) test.less(g, 50) test.less(b, 50)
end)

test.it("render: bottom-left vertex of triangle is green", function()
	local px = ctx:frame({ pipeline = pipeline, draw = drawTri })
	-- One pixel inside the BL vertex at screen (16, 48)
	local r, g, b = px.at(17, 47)
	test.less(r, 100) test.greater(g, 150) test.less(b, 100)
end)

test.it("render: bottom-right vertex of triangle is blue", function()
	local px = ctx:frame({ pipeline = pipeline, draw = drawTri })
	local r, g, b = px.at(47, 47)
	test.less(r, 100) test.less(g, 100) test.greater(b, 150)
end)

test.it("render: pixels outside the triangle retain the clear colour", function()
	local px = ctx:frame({ pipeline = pipeline, clearColor = { r = 0, g = 0, b = 0, a = 1 }, draw = drawTri })
	local r, g, b, a = px.at(0, 0)
	test.equal(r, 0) test.equal(g, 0) test.equal(b, 0) test.equal(a, 255)
end)

-- ─── Index buffer variants ───────────────────────────────────────────────────

test.it("render: u16 index buffer produces the same triangle", function()
	local ibuf16 = ctx.device:createBuffer({
		size = ffi.sizeof("uint16_t") * 3,
		usages = { "INDEX", "COPY_DST" },
	})
	ctx.device.queue:writeBuffer(ibuf16, ffi.sizeof("uint16_t") * 3, ffi.new("uint16_t[3]", { 0, 1, 2 }))

	local px = ctx:frame({
		pipeline = pipeline,
		draw = function(enc)
			enc:setVertexBuffer(0, triVbuf)
			enc:setIndexBuffer(ibuf16, "u16")
			enc:drawIndexed(3, 1)
		end,
	})
	local r, g, b = px.at(32, 18)
	test.greater(r, 200) test.less(g, 50) test.less(b, 50)
end)

test.it("render: firstIndex offset skips leading indices", function()
	-- Vertex 0 is a dummy; real triangle starts at index 1
	local verts4 = ffi.new("float[28]", {
		 0.0, -1.0, 0.0,  0.5, 0.5, 0.5, 1.0,  -- index 0: off-screen dummy
		 0.0,  0.5, 0.0,  1.0, 0.0, 0.0, 1.0,  -- index 1: red top
		-0.5, -0.5, 0.0,  1.0, 0.0, 0.0, 1.0,  -- index 2: red BL
		 0.5, -0.5, 0.0,  1.0, 0.0, 0.0, 1.0,  -- index 3: red BR
	})
	local vbuf4 = ctx.device:createBuffer({ size = ffi.sizeof(verts4), usages = { "VERTEX", "COPY_DST" } })
	local ibuf4 = ctx.device:createBuffer({ size = ffi.sizeof("uint32_t") * 4, usages = { "INDEX", "COPY_DST" } })
	ctx.device.queue:writeBuffer(vbuf4, ffi.sizeof(verts4), verts4)
	ctx.device.queue:writeBuffer(ibuf4, ffi.sizeof("uint32_t") * 4, ffi.new("uint32_t[4]", { 0, 1, 2, 3 }))

	local px = ctx:frame({
		pipeline = pipeline,
		draw = function(enc)
			enc:setVertexBuffer(0, vbuf4)
			enc:setIndexBuffer(ibuf4, "u32")
			enc:drawIndexed(3, 1, 1)  -- firstIndex = 1 → uses verts 1,2,3
		end,
	})
	local r, g, b = px.at(32, 18)
	test.greater(r, 200) test.less(g, 50) test.less(b, 50)
end)

-- ─── Multiple frames ──────────────────────────────────────────────────────────

test.it("render: second frame fully overwrites contents of the first", function()
	ctx:frame({ pipeline = pipeline, clearColor = { r = 1, g = 0, b = 0, a = 1 } })  -- all red

	local px = ctx:frame({ pipeline = pipeline, clearColor = { r = 0, g = 0, b = 1, a = 1 } })  -- all blue
	local r, g, b = px.at(0, 0)
	test.less(r, 10) test.less(g, 10) test.greater(b, 200)
end)

-- ─── Depth testing ───────────────────────────────────────────────────────────

test.it("render: depth test (less) keeps the closer triangle", function()
	local depthTex = ctx.device:createTexture({
		extents = { dim = "2d", width = W, height = H },
		format = "depth32float",
		usages = { "RENDER_ATTACHMENT" },
	})
	local depthView = depthTex:createView({})

	local depthPipeline = makePipeline({
		format = "depth32float",
		depthWriteEnabled = true,
		depthCompare = "less",
	})

	-- Red triangle at z=0.3 (closer), green at z=0.7 (farther), same XY footprint.
	-- Draw green first so that without depth testing green would win; with depth
	-- testing red must win everywhere the triangles overlap.
	local farVerts = ffi.new("float[21]", {
		 0.0,  0.5, 0.7,  0.0, 1.0, 0.0, 1.0,
		-0.5, -0.5, 0.7,  0.0, 1.0, 0.0, 1.0,
		 0.5, -0.5, 0.7,  0.0, 1.0, 0.0, 1.0,
	})
	local nearVerts = ffi.new("float[21]", {
		 0.0,  0.5, 0.3,  1.0, 0.0, 0.0, 1.0,
		-0.5, -0.5, 0.3,  1.0, 0.0, 0.0, 1.0,
		 0.5, -0.5, 0.3,  1.0, 0.0, 0.0, 1.0,
	})

	local stride = vertexLayout:getStride()
	local farVbuf  = ctx.device:createBuffer({ size = stride * 3, usages = { "VERTEX", "COPY_DST" } })
	local nearVbuf = ctx.device:createBuffer({ size = stride * 3, usages = { "VERTEX", "COPY_DST" } })
	ctx.device.queue:writeBuffer(farVbuf,  ffi.sizeof(farVerts),  farVerts)
	ctx.device.queue:writeBuffer(nearVbuf, ffi.sizeof(nearVerts), nearVerts)

	local px = ctx:frame({
		pipeline = depthPipeline,
		depthTexture = depthView,
		draw = function(enc)
			-- green (far) drawn first, red (near) second
			enc:setVertexBuffer(0, farVbuf)
			enc:setIndexBuffer(triIbuf, "u32")
			enc:drawIndexed(3, 1)

			enc:setVertexBuffer(0, nearVbuf)
			enc:drawIndexed(3, 1)
		end,
	})

	-- Centre of the triangle at screen (32, 32): red must dominate
	local r, g, b = px.at(32, 32)
	test.greater(r, 100) test.less(g, 100)
end)

-- ─── writeMask ───────────────────────────────────────────────────────────────

test.it("render: writeMask Color suppresses the alpha channel", function()
	local maskPipeline = ctx.device:createPipeline({
		layout = ctx.device:createBindGroupLayout({}),
		vertex = {
			module = { type = "spirv", source = vertSpv },
			buffers = { vertexLayout },
		},
		fragment = {
			module = { type = "spirv", source = fragSpv },
			targets = { {
				format = "rgba8unorm",
				writeMask = hood.ColorWrites.Color,  -- RGB only, no alpha write
			} },
		},
	})

	-- Clear to transparent black, draw a solid red triangle.
	-- With writeMask = Color the alpha channel must remain at the cleared value (0).
	local px = ctx:frame({
		pipeline = maskPipeline,
		clearColor = { r = 0, g = 0, b = 0, a = 0 },
		draw = drawTri,
	})
	local r, _, _, a = px.at(32, 18)
	test.greater(r, 150)
	test.equal(a, 0)
end)
