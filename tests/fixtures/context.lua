local ffi = require("ffi")
local hood = require("hood")

local M = {}
local Context = {}
Context.__index = Context

--- Create a headless Vulkan rendering context with a RGBA8 render target.
---@param w number? width (default 64)
---@param h number? height (default 64)
function M.new(w, h)
	w = w or 64
	h = h or 64

	local instance = hood.Instance.new({ backend = "vulkan", flags = { "headless" } })
	local adapter = instance:requestAdapter({})
	local device = adapter:requestDevice()

	local renderTex = device:createTexture({
		extents = { dim = "2d", width = w, height = h },
		format = "rgba8unorm",
		usages = { "RENDER_ATTACHMENT", "COPY_SRC" },
	})

	local readbackBuf = device:createBuffer({
		size = w * h * 4,
		usages = { "MAP_READ" },
	})

	return setmetatable({
		device = device,
		width = w,
		height = h,
		_tex = renderTex,
		_rbuf = readbackBuf,
	}, Context)
end

--- Render a frame and synchronously return a pixel accessor.
--- The readback buffer is unmapped before returning — pixel data is safe to
--- hold onto indefinitely as a Lua string.
---
--- opts.pipeline    — required render pipeline
--- opts.clearColor  — { r, g, b, a }, defaults to opaque black
--- opts.depthTexture — TextureView; enables a depth attachment cleared to 1.0
--- opts.draw        — function(encoder) called after pipeline + viewport are set
---@return { at: fun(x: number, y: number): number, number, number, number }
function Context:frame(opts)
	local encoder = self.device:createCommandEncoder()

	local desc = {
		colorAttachments = { {
			op = { type = "clear", color = opts.clearColor or { r = 0, g = 0, b = 0, a = 1 } },
			texture = self._tex:createView({}),
		} },
	}
	if opts.depthTexture then
		desc.depthStencilAttachment = {
			op = { type = "clear", depth = 1.0 },
			texture = opts.depthTexture,
		}
	end

	encoder:beginRendering(desc)
	encoder:setPipeline(opts.pipeline)
	encoder:setViewport(0, 0, self.width, self.height)
	if opts.draw then opts.draw(encoder) end
	encoder:endRendering()

	encoder:copyTextureToBuffer(
		{ texture = self._tex },
		{ buffer = self._rbuf, bytesPerRow = self.width * 4 },
		{ width = self.width, height = self.height }
	)

	local cmd = encoder:finish()
	self.device.queue:submit(cmd)
	self.device.queue:waitIdle()

	self._rbuf:mapAsync()
	local raw = ffi.cast("uint8_t*", self._rbuf:getMappedRange())
	local bytes = ffi.string(raw, self.width * self.height * 4)
	self._rbuf:unmap()

	local w = self.width
	return {
		at = function(x, y)
			local i = (y * w + x) * 4 + 1
			return string.byte(bytes, i),
				string.byte(bytes, i + 1),
				string.byte(bytes, i + 2),
				string.byte(bytes, i + 3)
		end,
	}
end

return M
