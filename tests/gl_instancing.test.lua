--- Per-instance vertex layouts on the OpenGL backend.
---
--- render.test.lua covers instancing through Vulkan; this covers the GL path,
--- which needs the divisor and instanced-draw bindings from glapi, the VAO
--- attribute locations to continue across layouts, and the instance buffer
--- offset to be honoured.
---
--- A headless GL context is not available everywhere, so the whole file skips
--- when one cannot be created rather than failing.
local ffi = require("ffi")
local test = require("lde-test")
local hood = require("hood")

local contextOk, device = pcall(function()
	local instance = hood.Instance.new({ backend = "opengl", flags = { "headless" } })
	return instance:requestAdapter({}):requestDevice()
end)

if not contextOk then
	test.skip("opengl instancing: skipped, no headless GL context", function() end)
	return
end

-- The entry point has to be redeclared for ARB_separate_shader_objects, which
-- is how hood builds GL programs.
local vertSrc = [[
#version 430 core
out gl_PerVertex { vec4 gl_Position; };
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec2 aOffset;
layout(location = 2) in vec4 aColor;
out vec4 vColor;
void main() {
    gl_Position = vec4(aPos.xy + aOffset, aPos.z, 1.0);
    vColor = aColor;
}
]]

local fragSrc = [[
#version 430 core
in vec4 vColor;
out vec4 fragColor;
void main() { fragColor = vColor; }
]]

local vertexLayout = hood.VertexLayout.new()
	:withAttribute({ type = "f32", size = 3, offset = 0 })

local instanceLayout = hood.VertexLayout.new()
	:withAttribute({ type = "f32", size = 2, offset = 0 })
	:withAttribute({ type = "f32", size = 4, offset = 8 })
	:withInstanceRate()

local pipeline = device:createPipeline({
	layout = device:createBindGroupLayout({}),
	vertex = {
		module = { type = "glsl", source = vertSrc },
		buffers = { vertexLayout, instanceLayout },
	},
	fragment = {
		module = { type = "glsl", source = fragSrc },
		targets = { { format = "rgba8unorm", writeMask = hood.ColorWrites.All } },
	},
})

local W, H = 64, 64
local INSTANCE_STRIDE = 24

local tex = device:createTexture({
	extents = { dim = "2d", width = W, height = H },
	format = "rgba8unorm",
	usages = { "RENDER_ATTACHMENT", "COPY_SRC" },
})
local readback = device:createBuffer({ size = W * H * 4, usages = { "MAP_READ" } })

-- A small triangle around the origin: the instance offset places it, so the
-- vertices are never rewritten.
local verts = ffi.new("float[9]", {
	-0.2, -0.2, 0.0,
	 0.2, -0.2, 0.0,
	 0.0,  0.2, 0.0,
})
local vbuf = device:createBuffer({ size = ffi.sizeof(verts), usages = { "VERTEX", "COPY_DST" } })
device.queue:writeBuffer(vbuf, ffi.sizeof(verts), verts)

-- Instance 0 sits left and is red; instance 1 sits right and is green.
local instances = ffi.new("float[12]", {
	-0.5, 0.0,  1.0, 0.0, 0.0, 1.0,
	 0.5, 0.0,  0.0, 1.0, 0.0, 1.0,
})
local ibuf = device:createBuffer({ size = ffi.sizeof(instances), usages = { "VERTEX", "COPY_DST" } })
device.queue:writeBuffer(ibuf, ffi.sizeof(instances), instances)

local indices = ffi.new("uint32_t[3]", { 0, 1, 2 })
local ebuf = device:createBuffer({ size = ffi.sizeof(indices), usages = { "INDEX", "COPY_DST" } })
device.queue:writeBuffer(ebuf, ffi.sizeof(indices), indices)

--- Render one frame and hand back a pixel accessor.
---@param instanceOffset number byte offset into the instance buffer
---@param instanceCount number
---@param indexed boolean draw through the index buffer instead of directly
local function render(instanceOffset, instanceCount, indexed)
	local encoder = device:createCommandEncoder()
	encoder:beginRendering({
		colorAttachments = { {
			op = { type = "clear", color = { r = 0, g = 0, b = 0, a = 1 } },
			texture = tex:createView({}),
		} },
	})
	encoder:setPipeline(pipeline)
	encoder:setViewport(0, 0, W, H)
	encoder:setVertexBuffer(0, vbuf)
	encoder:setVertexBuffer(1, ibuf, instanceOffset)
	if indexed then
		encoder:setIndexBuffer(ebuf, "u32")
		encoder:drawIndexed(3, instanceCount)
	else
		encoder:draw(3, instanceCount)
	end
	encoder:endRendering()
	encoder:copyTextureToBuffer({ texture = tex }, { buffer = readback, bytesPerRow = W * 4 },
		{ width = W, height = H })

	local cmd = encoder:finish()
	device.queue:submit(cmd)
	device.queue:waitIdle()

	readback:mapAsync()
	local raw = ffi.cast("uint8_t*", readback:getMappedRange())
	local bytes = ffi.string(raw, W * H * 4)
	readback:unmap()

	return function(x, y)
		local i = (y * W + x) * 4 + 1
		return string.byte(bytes, i), string.byte(bytes, i + 1)
	end
end

--- The instance offsets are in NDC, so +/-0.5 lands at screen x 16 and 48.
local function assertBothInstances(px)
	local lr, lg = px(16, 32)
	test.greater(lr, 150) test.less(lg, 100)

	local rr, rg = px(48, 32)
	test.less(rr, 100) test.greater(rg, 150)
end

--- Only the second instance, addressed by offsetting the instance buffer.
local function assertSecondInstanceOnly(px)
	local lr, lg = px(16, 32)
	test.less(lr, 50) test.less(lg, 50)

	local rr, rg = px(48, 32)
	test.less(rr, 100) test.greater(rg, 150)
end

test.it("opengl: one draw call places two instances from per-instance data", function()
	assertBothInstances(render(0, 2, false))
end)

test.it("opengl: instance buffer offset selects which instance is drawn", function()
	assertSecondInstanceOnly(render(INSTANCE_STRIDE, 1, false))
end)

test.it("opengl: indexed instanced draw places both instances", function()
	assertBothInstances(render(0, 2, true))
end)

test.it("opengl: indexed draw at an instance offset draws only that instance", function()
	assertSecondInstanceOnly(render(INSTANCE_STRIDE, 1, true))
end)
