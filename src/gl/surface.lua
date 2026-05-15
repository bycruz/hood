local GLContext = require("hood.gl.context")
local GLSwapchain = require("hood.gl.swapchain")

---@class hood.gl.Surface
---@field window winit.Window
local GLSurface = {}
GLSurface.__index = GLSurface

---@param window winit.win32.Window
function GLSurface.new(window)
	return setmetatable({ window = window }, GLSurface)
end

---@param device hood.gl.Device
---@param config hood.SurfaceConfig
function GLSurface:configure(device, config)
	local context = GLContext.fromWindow(self.window, device.ctx)

	context:makeCurrent()

	if config.presentMode == "immediate" then
		context:setSwapInterval(0)
	else
		context:setSwapInterval(1)
	end

	return GLSwapchain.new(context, self.window.width, self.window.height, self.window)
end

return GLSurface
