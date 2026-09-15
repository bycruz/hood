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

-- ─── Instancing ──────────────────────────────────────────────────────────────

-- One triangle per instance, with the instance data supplying both an offset
-- and a colour. A per-instance layout is the only way the second instance can
-- land somewhere else without the vertices being rewritten.
local instVertSpv = glslc.compile([[
#version 430 core
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec2 aOffset;
layout(location = 2) in vec4 aColor;
layout(location = 0) out vec4 vColor;
void main() {
    gl_Position = vec4(aPos.xy + aOffset, aPos.z, 1.0);
    vColor = aColor;
}
]], "vert")

local instFragSpv = glslc.compile([[
#version 430 core
layout(location = 0) in vec4 vColor;
layout(location = 0) out vec4 fragColor;
void main() {
    fragColor = vColor;
}
]], "frag")

-- Per-vertex data: one triangle, positions only.
local instVertexLayout = hood.VertexLayout.new()
	:withAttribute({ type = "f32", size = 3, offset = 0 })

-- Per-instance data: vec2 offset + vec4 colour, 24 bytes.
local instanceLayout = hood.VertexLayout.new()
	:withAttribute({ type = "f32", size = 2, offset = 0 })
	:withAttribute({ type = "f32", size = 4, offset = 8 })
	:withInstanceRate()

test.it("vertex layout: instance rate is reported", function()
	test.equal(instanceLayout:isInstanceRate(), true)
	test.equal(instVertexLayout:isInstanceRate(), false)
end)

local INSTANCE_STRIDE = 24

local instPipeline = ctx.device:createPipeline({
	layout = ctx.device:createBindGroupLayout({}),
	vertex = {
		module = { type = "spirv", source = instVertSpv },
		buffers = { instVertexLayout, instanceLayout },
	},
	fragment = {
		module = { type = "spirv", source = instFragSpv },
		targets = { { format = "rgba8unorm", writeMask = hood.ColorWrites.All } },
	},
})

-- A small triangle around the origin, so the instance offset decides where it
-- ends up on screen.
local instVerts = ffi.new("float[9]", {
	-0.2, -0.2, 0.0,
	 0.2, -0.2, 0.0,
	 0.0,  0.2, 0.0,
})
local instVbuf = ctx.device:createBuffer({
	size = ffi.sizeof(instVerts),
	usages = { "VERTEX", "COPY_DST" },
})
ctx.device.queue:writeBuffer(instVbuf, ffi.sizeof(instVerts), instVerts)

-- Instance 0 sits left and is red, instance 1 sits right and is green.
local instances = ffi.new("float[12]", {
	-0.5, 0.0,  1.0, 0.0, 0.0, 1.0,
	 0.5, 0.0,  0.0, 1.0, 0.0, 1.0,
})
local instBuf = ctx.device:createBuffer({
	size = ffi.sizeof(instances),
	usages = { "VERTEX", "COPY_DST" },
})
ctx.device.queue:writeBuffer(instBuf, ffi.sizeof(instances), instances)

test.it("render: one draw call places two instances from per-instance data", function()
	local px = ctx:frame({
		pipeline = instPipeline,
		draw = function(enc)
			enc:setVertexBuffer(0, instVbuf)
			enc:setVertexBuffer(1, instBuf)
			enc:draw(3, 2)
		end,
	})

	-- The instance offsets are in NDC, so +/-0.5 lands at screen x 16 and 48,
	-- and y = 32 is the vertical middle of the triangle.
	local lr, lg = px.at(16, 32)
	test.greater(lr, 150)
	test.less(lg, 100)

	local rr, rg = px.at(48, 32)
	test.less(rr, 100)
	test.greater(rg, 150)
end)

test.it("render: instance buffer offset selects which instance is drawn", function()
	-- Only the second instance, addressed by offsetting the instance buffer.
	-- This is how a run starting partway through a packed instance array is
	-- drawn, since a nonzero firstInstance needs a device feature.
	local px = ctx:frame({
		pipeline = instPipeline,
		draw = function(enc)
			enc:setVertexBuffer(0, instVbuf)
			enc:setVertexBuffer(1, instBuf, INSTANCE_STRIDE)
			enc:draw(3, 1)
		end,
	})

	local rr, rg = px.at(48, 32)
	test.less(rr, 100)
	test.greater(rg, 150)

	-- Nothing was drawn on the left this time.
	local lr, lg = px.at(16, 32)
	test.less(lr, 50)
	test.less(lg, 50)
end)

-- ─── Indirect draws ──────────────────────────────────────────────────────────

-- One vkCmdDrawIndexedIndirect issuing two draws of different geometry. Both
-- draws share the bound buffers, so they select their mesh through firstIndex
-- and vertexOffset and their copies through firstInstance.
local indirectVertexLayout = hood.VertexLayout.new()
	:withAttribute({ type = "f32", size = 3, offset = 0 })

local indirectInstanceLayout = hood.VertexLayout.new()
	:withAttribute({ type = "f32", size = 2, offset = 0 })
	:withAttribute({ type = "f32", size = 4, offset = 8 })
	:withInstanceRate()

local indirectPipeline = ctx.device:createPipeline({
	layout = ctx.device:createBindGroupLayout({}),
	vertex = {
		module = { type = "spirv", source = instVertSpv },
		buffers = { indirectVertexLayout, indirectInstanceLayout },
	},
	fragment = {
		module = { type = "spirv", source = instFragSpv },
		targets = { { format = "rgba8unorm", writeMask = hood.ColorWrites.All } },
	},
})

-- Two triangles in one vertex buffer, at different heights so the rendered
-- result depends on which vertex range each command fetches. Mesh A sits in the
-- lower half, mesh B in the upper half.
local AB_VERTICES = ffi.new("float[18]", {
	-- mesh A: vertices 0..2, around y = -0.3
	-0.2, -0.45, 0.0,   0.2, -0.45, 0.0,   0.0, -0.15, 0.0,
	-- mesh B: vertices 3..5, around y = +0.3
	-0.2,  0.15, 0.0,   0.2,  0.15, 0.0,   0.0,  0.45, 0.0,
})
local abVbuf = ctx.device:createBuffer({
	size = ffi.sizeof(AB_VERTICES),
	usages = { "VERTEX", "COPY_DST" },
})
ctx.device.queue:writeBuffer(abVbuf, ffi.sizeof(AB_VERTICES), AB_VERTICES)

-- Index values are per-mesh and 0-based: mesh A occupies index slots 0..2,
-- mesh B 3..5, and vertexOffset shifts the values into the shared vertex buffer.
local AB_INDICES = ffi.new("uint32_t[6]", { 0, 1, 2, 0, 1, 2 })
local abIbuf = ctx.device:createBuffer({
	size = ffi.sizeof(AB_INDICES),
	usages = { "INDEX", "COPY_DST" },
})
ctx.device.queue:writeBuffer(abIbuf, ffi.sizeof(AB_INDICES), AB_INDICES)

-- One instance each: instance 0 is red and shifted left, instance 1 green and
-- shifted right.
local AB_INSTANCES = ffi.new("float[12]", {
	-0.5, 0.0,  1.0, 0.0, 0.0, 1.0,
	 0.5, 0.0,  0.0, 1.0, 0.0, 1.0,
})
local abInstanceBuf = ctx.device:createBuffer({
	size = ffi.sizeof(AB_INSTANCES),
	usages = { "VERTEX", "COPY_DST" },
})
ctx.device.queue:writeBuffer(abInstanceBuf, ffi.sizeof(AB_INSTANCES), AB_INSTANCES)

local indirectBuffer = ctx.device:createBuffer({
	size = 2 * 20,
	usages = { "INDIRECT", "COPY_DST" },
})

local vk = require("vkapi")
local indirectCommands = vk.DrawIndexedIndirectCommandArray(2)

-- Draw 1: mesh A, instance 0. Draw 2: mesh B, instance 1.
indirectCommands[0].indexCount = 3
indirectCommands[0].instanceCount = 1
indirectCommands[0].firstIndex = 0
indirectCommands[0].vertexOffset = 0
indirectCommands[0].firstInstance = 0
indirectCommands[1].indexCount = 3
indirectCommands[1].instanceCount = 1
indirectCommands[1].firstIndex = 3
indirectCommands[1].vertexOffset = 3
indirectCommands[1].firstInstance = 1

-- Screen positions: instance centres are NDC x = +/-0.5 -> screen x 16 / 48, and
-- the mesh centres are NDC y = -0.3 / +0.3 -> screen y 42 / 22.
local function drawIndirect(enc, drawCount)
	enc:setVertexBuffer(0, abVbuf)
	enc:setVertexBuffer(1, abInstanceBuf)
	enc:setIndexBuffer(abIbuf, "u32")
	enc:drawIndexedIndirect(indirectBuffer, 0, drawCount, 20)
end

test.it("render: one indirect call draws two meshes", function()
	ctx.device.queue:writeBuffer(indirectBuffer, 2 * 20, indirectCommands)

	local px = ctx:frame({
		pipeline = indirectPipeline,
		draw = function(enc) drawIndirect(enc, 2) end,
	})

	-- Mesh A with instance 0: red, lower left.
	local ar, ag = px.at(16, 42)
	test.greater(ar, 150) test.less(ag, 100)

	-- Mesh B with instance 1: green, upper right. If firstIndex/vertexOffset
	-- were ignored both draws would fetch mesh A and land at the same height.
	local br, bg = px.at(48, 22)
	test.less(br, 100) test.greater(bg, 150)

	-- Nothing drew mesh B's range in the lower right, or mesh A's in the upper
	-- left, so the ranges really are distinct.
	local lr, lg = px.at(48, 42)
	test.less(lr, 50) test.less(lg, 50)
	local ur, ug = px.at(16, 22)
	test.less(ur, 50) test.less(ug, 50)
end)

test.it("render: indirect draw count controls how many are issued", function()
	ctx.device.queue:writeBuffer(indirectBuffer, 2 * 20, indirectCommands)

	-- Only the first command: mesh A appears and mesh B does not.
	local px = ctx:frame({
		pipeline = indirectPipeline,
		draw = function(enc) drawIndirect(enc, 1) end,
	})

	local ar, ag = px.at(16, 42)
	test.greater(ar, 150) test.less(ag, 100)

	local br, bg = px.at(48, 22)
	test.less(br, 50) test.less(bg, 50)
end)

-- ─── Render pass state ───────────────────────────────────────────────────────

-- A pass is only started when a pipeline is bound, because that is when the
-- render pass and framebuffer are known. Ending one that never started produced a
-- command buffer the driver executed into a segfault, so the mismatch is caught
-- here instead.

test.it("render pass: endRendering with no pass open is reported", function()
	local enc = ctx.device:createCommandEncoder()
	enc:beginRendering({
		colorAttachments = { {
			op = { type = "clear", color = { r = 0, g = 0, b = 0, a = 1 } },
			texture = ctx._tex:createView({}),
		} },
	})

	test.errors(function() enc:endRendering() end,
		"hood: endRendering was called with no open render pass; a pass is started by "
			.. "setPipeline, so bind the pipeline before drawing, even for a frame with nothing in it")
end)

test.it("render pass: finish with a pass still open is reported", function()
	local enc = ctx.device:createCommandEncoder()
	enc:beginRendering({
		colorAttachments = { {
			op = { type = "clear", color = { r = 0, g = 0, b = 0, a = 1 } },
			texture = ctx._tex:createView({}),
		} },
	})
	enc:setPipeline(pipeline)

	test.errors(function() enc:finish() end,
		"hood: finish() was called with a render pass still open; endRendering() first")
end)

test.it("render pass: a second beginRendering without ending is reported", function()
	local enc = ctx.device:createCommandEncoder()
	local desc = {
		colorAttachments = { {
			op = { type = "clear", color = { r = 0, g = 0, b = 0, a = 1 } },
			texture = ctx._tex:createView({}),
		} },
	}

	enc:beginRendering(desc)
	enc:setPipeline(pipeline)
	enc:beginRendering(desc)

	test.errors(function() enc:setPipeline(pipeline) end,
		"hood: beginRendering was called while a render pass is already open")
end)

test.it("render pass: an empty frame clears and presents", function()
	-- The case that used to crash: nothing drawn, so no pipeline was ever bound.
	-- Binding it is what starts the pass, and this is the shape lupa now uses.
	local px = ctx:frame({
		pipeline = pipeline,
		clearColor = { r = 0, g = 0, b = 1, a = 1 },
		draw = function() end,
	})

	local r, g, b = px.at(32, 32)
	test.less(r, 50) test.less(g, 50) test.greater(b, 200)
end)
