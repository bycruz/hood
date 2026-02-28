---@class hood.SurfaceConfig
---@field presentMode hood.PresentMode

---@class hood.Surface
---@field new fun(window: winit.Window): hood.Surface
---@field configure fun(self: hood.Surface, device: hood.Device, config: hood.SurfaceConfig): hood.Swapchain
local Surface = VULKAN and require("hood.vk.surface") or require("hood.gl.surface") --[[@as hood.Surface]]

return Surface
