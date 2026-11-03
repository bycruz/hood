local ffi = require("ffi")
local winit = require("winit")
local function loadHood()
	local module = require("hood")
	---@cast module hood
	return module
end
local hood = loadHood()

---@type hood.InstanceBackend
local backend = os.getenv("VULKAN") and "vulkan" or "opengl"
print("Using backend:", backend)

local pathSep = string.sub(package.config, 1, 1)
local entry = debug.getinfo(1, "S").source:sub(2)
---@param text string
local function directoryOf(text)
	local found = text:match("^(.*)" .. pathSep)
	if not found then error("cannot find the example directory") end
	---@cast found string
	return found
end
local dirName = directoryOf(entry)

-- Create event loop and window
local eventLoop = winit.EventLoop.new()
local window = winit.Window.new(eventLoop, 800, 600)
eventLoop:register(window)
window:setTitle("Triangle - Running on " .. backend .. " backend")

-- Create hood instance, adapter, and device
local instance = hood.Instance.new({ backend = backend, flags = {} })
local adapter = instance:requestAdapter({ powerPreference = "high-performance" }) or
	error("no graphics adapter is available")
local device = adapter:requestDevice()

-- Create surface and swapchain
--
-- Drivers disagree about which swapchain format to hand back first, and the format decides
-- whether the hardware encodes the shader's output again: the same triangle comes out washed
-- out on one GPU and correct on another. This example writes colours that are already
-- display-ready, so it takes the driver's choice. An app writing linear values would name
-- `format = "bgra8unorm-srgb"` here (Vulkan only; the OpenGL backend ignores the field).
local surfaceConfig = { presentMode = "immediate" }

local surface = instance:createSurface(window)
local swapchain = surface:configure(device, surfaceConfig) or
	error("the driver gave the surface no size to make a swapchain for")
local currentSwapchain = swapchain

-- Define vertex layout: position (vec3) + color (vec4)
local position = { type = "f32", size = 3, offset = 0 } --[[@as hood.VertexLayout.Attribute]]
local color = { type = "f32", size = 4, offset = 12 } --[[@as hood.VertexLayout.Attribute]]
local vertexLayout = hood.VertexLayout.new()
	:withAttribute(position)
	:withAttribute(color)

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
---@type string
local shaderExt = backend == "opengl" and "glsl" or "spv"

-- None needed for this example.
-- In the future, this will not be needed with spirv reflection.
local bindGroupLayout = device:createBindGroupLayout({})

-- Create pipeline
---@param path string
local function readFile(path)
	local handle = assert(io.open(path, "r"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local pipeline = device:createPipeline({
	layout = bindGroupLayout,
	vertex = {
		module = {
			type = shaderType,
			source = readFile(dirName .. "/../../shaders/triangle.vert." .. shaderExt),
		},
		buffers = { vertexLayout },
	},
	fragment = {
		module = {
			type = shaderType,
			source = readFile(dirName .. "/../../shaders/triangle.frag." .. shaderExt),
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
---@param event winit.Event
---@param handler winit.EventManager
local function onEvent(event, handler)
	if event.name == "windowClose" then
		handler:exit()
	elseif event.name == "redraw" then
		local texture = currentSwapchain:getCurrentTexture()

		-- Resize handling
		if not texture then
			currentSwapchain = surface:configure(device, surfaceConfig, currentSwapchain) or
				error("the driver gave the surface no size to make a swapchain for")
			texture = currentSwapchain:getCurrentTexture()

			if not texture then
				return
			end
		end

		local encoder = currentSwapchain:createCommandEncoder()

		encoder:beginRendering({
			colorAttachments = {
				{
					op = {
						type = "clear",
						color = { r = 0.1, g = 0.1, b = 0.1, a = 1.0 },
					},
					texture = texture:createView({}),
				},
			},
		})

		encoder:setPipeline(pipeline)
		encoder:setViewport(0, 0, currentSwapchain.width, currentSwapchain.height)
		encoder:setVertexBuffer(0, vertexBuffer)
		encoder:setIndexBuffer(indexBuffer, "u32")
		encoder:drawIndexed(3, 1)
		encoder:endRendering()

		local commandBuffer = encoder:finish()
		device.queue:submit(commandBuffer)
		device.queue:present(currentSwapchain)
	elseif event.name == "aboutToWait" then
		handler:requestRedraw(window)
	end
end

eventLoop:run(onEvent)
