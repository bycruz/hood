---@class hood.SurfaceConfig
---@field presentMode hood.PresentMode

---@class hood.Surface
---@field new fun(window: winit.Window): hood.Surface
---@field configure fun(self: hood.Surface, device: hood.Device, config: hood.SurfaceConfig): hood.Swapchain
local Surface = VULKAN and require("hood.surface.vk") or require("hood.surface.gl") --[[@as hood.Surface]]

return Surface
