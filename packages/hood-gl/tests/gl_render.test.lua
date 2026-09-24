--- The rows a texture is drawn into on the OpenGL backend.
---
--- OpenGL counts the rows of a framebuffer up from its bottom and Vulkan counts them down from
--- its top, so the same drawing went into opposite rows on the two backends: a texture rendered
--- here and read back came out upside down against the same render through Vulkan, and a texture
--- rendered and then sampled by another pass was sampled mirrored.
---
--- What this checks is what render.test.lua already checks through Vulkan -- that NDC +y is up
--- the screen, and that row zero of a texture is the top of what was drawn -- on the GL path.
---
--- A headless GL context is not available everywhere, so the whole file skips when one cannot
--- be created rather than failing.
local ffi = require("ffi")
local test = require("lde-test")
local core = require("hood-core")
local gl = require("hood-gl")

local contextOk, device = pcall(function()
	local instance = gl.new({ backend = "opengl", flags = { "headless" } })
	return instance:requestAdapter({}):requestDevice()
end)

if not contextOk then
	test.skip("opengl rows: skipped, no headless GL context", function() end)
	return
end

-- The entry point has to be redeclared for ARB_separate_shader_objects, which is how hood builds
-- GL programs.
local vertSrc = [[
#version 430 core
out gl_PerVertex { vec4 gl_Position; };
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec4 aColor;
out vec4 vColor;
void main() {
    gl_Position = vec4(aPos, 1.0);
    vColor = aColor;
}
]]

local fragSrc = [[
#version 430 core
in vec4 vColor;
out vec4 fragColor;
void main() { fragColor = vColor; }
]]

local vertexLayout = core.VertexLayout.new()
	:withAttribute({ type = "f32", size = 3, offset = 0 })
	:withAttribute({ type = "f32", size = 4, offset = 12 })

local pipeline = device:createPipeline({
	layout = device:createBindGroupLayout({}),
	vertex = {
		module = { type = "glsl", source = vertSrc },
		buffers = { vertexLayout },
	},
	fragment = {
		module = { type = "glsl", source = fragSrc },
		targets = { { format = "rgba8unorm", writeMask = core.ColorWrites.All } },
	},
})

local W, H = 64, 64

local tex = device:createTexture({
	extents = { dim = "2d", width = W, height = H },
	format = "rgba8unorm",
	usages = { "RENDER_ATTACHMENT", "COPY_SRC" },
})
local readback = device:createBuffer({ size = W * H * 4, usages = { "MAP_READ" } })

-- Triangle: top red, bottom-left green, bottom-right blue, the one render.test.lua draws.
local verts = ffi.new("float[21]", {
	0.0, 0.5, 0.0, 1.0, 0.0, 0.0, 1.0,
	-0.5, -0.5, 0.0, 0.0, 1.0, 0.0, 1.0,
	0.5, -0.5, 0.0, 0.0, 0.0, 1.0, 1.0,
})
local vertexBytes = ffi.sizeof(verts) --[[@as number]]

local vbuf = device:createBuffer({ size = vertexBytes, usages = { "VERTEX", "COPY_DST" } })
device.queue:writeBuffer(vbuf, vertexBytes, verts)

local indices = ffi.new("uint32_t[3]", { 0, 1, 2 })
local indexBytes = ffi.sizeof(indices) --[[@as number]]

local ebuf = device:createBuffer({ size = indexBytes, usages = { "INDEX", "COPY_DST" } })
device.queue:writeBuffer(ebuf, indexBytes, indices)

--- Render one frame into the texture and hand back a pixel accessor.
---@return fun(x: number, y: number): number, number, number
local function frame()
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
	encoder:setIndexBuffer(ebuf, "u32")
	encoder:drawIndexed(3, 1)
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
		local at = (y * W + x) * 4 + 1

		return string.byte(bytes, at), string.byte(bytes, at + 1), string.byte(bytes, at + 2)
	end
end

-- Screen-space mapping for a 64x64 target with a viewport that does not turn the drawing over:
--   screen_x = (NDC_x + 1) * 32
--   screen_y = (1 - NDC_y) * 32
-- Top vertex (0, 0.5) -> (32, 16), bottom-left (-0.5, -0.5) -> (16, 48), bottom-right -> (48, 48).
-- Row zero is the top of the texture, which is the row a texture is written from and read back
-- to, and the row the top of the screen is drawn in.
test.it("opengl rows: NDC +y is drawn up the screen, as it is through Vulkan", function()
	local px = frame()

	-- Above the apex there is nothing but the clear colour, and the row the apex is in is red:
	-- read the other way round, that red would be at the bottom.
	local clear = px(32, 4)
	test.less(clear, 50, "no drawing above the apex")

	local r, g, b = px(32, 18)
	test.greater(r, 200, "the apex is red") test.less(g, 50) test.less(b, 50)

	local gr, gg = px(17, 47)
	test.less(gr, 100, "the bottom left is green") test.greater(gg, 150)

	local _, _, bb = px(44, 44)
	test.greater(bb, 150, "and the bottom right is blue")
end)
