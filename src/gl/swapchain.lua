local GLTexture = require("hood.gl.texture")

---@class hood.gl.Swapchain
---@field ctx hood.gl.Context
---@field window winit.Window?
---@field width number
---@field height number
local GLSwapchain = {}
GLSwapchain.__index = GLSwapchain

---@param ctx hood.gl.Context
---@param width number
---@param height number
---@param window winit.Window?
function GLSwapchain.new(ctx, width, height, window)
	return setmetatable({ ctx = ctx, width = width, height = height, window = window }, GLSwapchain)
end

function GLSwapchain:getCurrentTexture()
	-- Sync dimensions with the window on every call, so the viewport is always
	-- up-to-date after a resize. Unlike Vulkan, OpenGL's backbuffer is always
	-- valid, so we can't rely on returning nil to trigger a reconfiguration.
	if self.window then
		self.width = self.window.width
		self.height = self.window.height
	end

	return GLTexture.forContextViewport(self.ctx)
end

function GLSwapchain:destroy()
end

function GLSwapchain:present()
	self.ctx:makeCurrent()
	self.ctx:swapBuffers()
end

return GLSwapchain
