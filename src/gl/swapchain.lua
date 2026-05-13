local GLTexture = require("hood.gl.texture")

---@class hood.gl.Swapchain
---@field ctx hood.gl.Context
---@field width number
---@field height number
local GLSwapchain = {}
GLSwapchain.__index = GLSwapchain

---@param ctx hood.gl.Context
---@param width number
---@param height number
function GLSwapchain.new(ctx, width, height)
	return setmetatable({ ctx = ctx, width = width, height = height }, GLSwapchain)
end

function GLSwapchain:getCurrentTexture()
	return GLTexture.forContextViewport(self.ctx)
end

function GLSwapchain:destroy()
end

function GLSwapchain:present()
	self.ctx:makeCurrent()
	self.ctx:swapBuffers()
end

return GLSwapchain
