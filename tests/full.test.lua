local ffi = require("ffi")
local test = require("lde-test")

local hood = require("hood")
local glslc = require("tests.fixtures.glslc")

local vertSpv = glslc.compile([[
#version 430 core
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec4 aColor;
layout(location = 0) out vec4 vertexColor;
void main() {
    gl_Position = vec4(aPos, 1.0);
    vertexColor = aColor;
}
]], "vert")

local fragSpv = glslc.compile([[
#version 430 core
layout(location = 0) in vec4 vertexColor;
layout(location = 0) out vec4 fragColor;
void main() {
    fragColor = vertexColor;
}
]], "frag")

local WIDTH, HEIGHT = 64, 64

test.it("should work headless", function()
	local instance = hood.Instance.new({ backend = "vulkan", flags = { "headless" } })
	local adapter = instance:requestAdapter({ powerPreference = "high-performance" })
	local device = adapter:requestDevice()

	local renderTexture = device:createTexture({
		extents = { dim = "2d", width = WIDTH, height = HEIGHT },
		format = "rgba8unorm",
		usages = { "RENDER_ATTACHMENT", "COPY_SRC" },
	})

	local readbackBuffer = device:createBuffer({
		size = WIDTH * HEIGHT * 4,
		usages = { "MAP_READ" },
	})

	local vertexLayout = hood.VertexLayout.new()
		:withAttribute({ type = "f32", size = 3, offset = 0 })
		:withAttribute({ type = "f32", size = 4, offset = 12 })

	-- Triangle: top=red, bottom-left=green, bottom-right=blue
	local vertices = ffi.new("float[?]", 21, {
		0.0, 0.5, 0.0, 1.0, 0.0, 0.0, 1.0,
		-0.5, -0.5, 0.0, 0.0, 1.0, 0.0, 1.0,
		0.5, -0.5, 0.0, 0.0, 0.0, 1.0, 1.0,
	})
	local indices = ffi.new("uint32_t[3]", { 0, 1, 2 })

	local vertexBuffer = device:createBuffer({
		size = vertexLayout:getStride() * 3,
		usages = { "VERTEX", "COPY_DST" },
	})
	local indexBuffer = device:createBuffer({
		size = ffi.sizeof("uint32_t") * 3,
		usages = { "INDEX", "COPY_DST" },
	})

	device.queue:writeBuffer(vertexBuffer, ffi.sizeof(vertices), vertices)
	device.queue:writeBuffer(indexBuffer, ffi.sizeof(indices), indices)

	local bindGroupLayout = device:createBindGroupLayout({})

	local pipeline = device:createPipeline({
		layout = bindGroupLayout,
		vertex = {
			module = { type = "spirv", source = vertSpv },
			buffers = { vertexLayout },
		},
		fragment = {
			module = { type = "spirv", source = fragSpv },
			targets = {
				{
					blend = "alpha-blending",
					writeMask = hood.ColorWrites.All,
					format = "rgba8unorm",
				},
			},
		},
	})

	local encoder = device:createCommandEncoder()

	encoder:beginRendering({
		colorAttachments = {
			{
				op = { type = "clear", color = { r = 0.0, g = 0.0, b = 0.0, a = 1.0 } },
				texture = renderTexture:createView({}),
			},
		},
	})
	encoder:setPipeline(pipeline)
	encoder:setViewport(0, 0, WIDTH, HEIGHT)
	encoder:setVertexBuffer(0, vertexBuffer)
	encoder:setIndexBuffer(indexBuffer, "u32")
	encoder:drawIndexed(3, 1)
	encoder:endRendering()

	encoder:copyTextureToBuffer(
		{ texture = renderTexture },
		{ buffer = readbackBuffer, bytesPerRow = WIDTH * 4 },
		{ width = WIDTH, height = HEIGHT }
	)

	local cmd = encoder:finish()
	device.queue:submit(cmd)
	device.queue:waitIdle()

	readbackBuffer:mapAsync()
	local pixels = ffi.cast("uint8_t*", readbackBuffer:getMappedRange())

	local function pixelAt(x, y)
		local base = (y * WIDTH + x) * 4
		return pixels[base], pixels[base + 1], pixels[base + 2], pixels[base + 3]
	end

	-- Top-left corner is outside the triangle: should be the clear color (black)
	local r, g, b, a = pixelAt(0, 0)
	test.equal(r, 0)
	test.equal(g, 0)
	test.equal(b, 0)
	test.equal(a, 255)

	-- A few pixels below the top vertex (NDC 0,0.5 → screen 32,16), solidly inside the red region
	local tr, tg, tb = pixelAt(32, 20)
	test.greater(tr, 200)
	test.less(tg, 50)
	test.less(tb, 50)

	readbackBuffer:unmap()
end)
