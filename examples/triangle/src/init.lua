local ffi = require("ffi")
local winit = require("winit")
local hood = require("hood")

---@type hood.InstanceBackend
local backend = os.getenv("VULKAN") and "vulkan" or "opengl"
print("Using backend:", backend)

---@type string
local dirName = debug.getinfo(1, "S").source:sub(2):match("(.*/)")

-- Create event loop and window
local eventLoop = winit.EventLoop.new()
local window = winit.Window.new(eventLoop, 800, 600)
eventLoop:register(window)
window:setTitle("Triangle - Running on " .. backend .. " backend")

-- Create hood instance, adapter, and device
local instance = hood.Instance.new({ backend = backend, flags = {} })
local adapter = instance:requestAdapter({ powerPreference = "high-performance" })
local device = adapter:requestDevice()

-- Create surface and swapchain
local surface = instance:createSurface(window)
local swapchain = surface:configure(device, { presentMode = "immediate" })

-- Define vertex layout: position (vec3) + color (vec4)
local vertexLayout = hood.VertexLayout.new()
	:withAttribute({ type = "f32", size = 3, offset = 0 }) -- position
	:withAttribute({ type = "f32", size = 4, offset = 12 }) -- color

-- Triangle vertices (centered on screen in NDC coordinates)
-- Format: x, y, z, r, g, b, a
local vertices = {
	-- Top vertex (red)
	0.0, 0.5, 0.0, 1.0, 0.0, 0.0, 1.0,
	-- Bottom left vertex (green)
	-0.5, -0.5, 0.0, 0.0, 1.0, 0.0, 1.0,
	-- Bottom right vertex (blue)
	0.5, -0.5, 0.0, 0.0, 0.0, 1.0, 1.0,
}

local indices = { 0, 1, 2 }

-- Create vertex and index buffers
local vertexBuffer = device:createBuffer({
	size = vertexLayout:getStride() * 3,
	usages = { "VERTEX", "COPY_DST" },
})

local indexBuffer = device:createBuffer({
	size = ffi.sizeof("uint32_t") * 3,
	usages = { "INDEX", "COPY_DST" },
})

-- Write data to buffers
device.queue:writeBuffer(
	vertexBuffer,
	ffi.sizeof("float") * #vertices,
	ffi.new("float[?]", #vertices, vertices)
)

device.queue:writeBuffer(
	indexBuffer,
	ffi.sizeof("uint32_t") * #indices,
	ffi.new("uint32_t[?]", #indices, indices)
)

local shaderType = backend == "opengl" and "glsl" or "spirv"
local shaderExt = backend == "opengl" and "glsl" or "spv"

-- None needed for this example.
-- In the future, this will not be needed with spirv reflection.
local bindGroupLayout = device:createBindGroupLayout({})

-- Create pipeline
local pipeline = device:createPipeline({
	layout = bindGroupLayout,
	vertex = {
		module = {
			type = shaderType,
			source = io.open(dirName .. "../../shaders/triangle.vert." .. shaderExt, "r"):read("*a"),
		},
		buffers = { vertexLayout },
	},
	fragment = {
		module = {
			type = shaderType,
			source = io.open(dirName .. "../../shaders/triangle.frag." .. shaderExt, "r"):read("*a"),
		},
		targets = {
			{
				blend = "alpha-blending",
				writeMask = hood.ColorWrites.All,
				format = swapchain.format,
			},
		},
	},
})

-- Main render loop
eventLoop:run(function(event, handler)
	if event.name == "windowClose" then
		handler:exit()
	elseif event.name == "redraw" then
		local encoder = device:createCommandEncoder()

		encoder:beginRendering({
			colorAttachments = {
				{
					op = {
						type = "clear",
						color = { r = 0.1, g = 0.1, b = 0.1, a = 1.0 },
					},
					texture = swapchain:getCurrentTexture(),
				},
			},
		})

		encoder:setPipeline(pipeline)
		encoder:setViewport(0, 0, window.width, window.height)
		encoder:setVertexBuffer(0, vertexBuffer)
		encoder:setIndexBuffer(indexBuffer, "u32")
		encoder:drawIndexed(3, 1)
		encoder:endRendering()

		local commandBuffer = encoder:finish()
		device.queue:submit(commandBuffer, swapchain)
		device.queue:present(swapchain)
	elseif event.name == "aboutToWait" then
		handler:requestRedraw(window)
	end
end)
