---@alias hood.PresentMode
--- | "immediate"
--- | "fifo"
--- | "fifo-relaxed"
--- | "mailbox"

---@class hood.SurfaceConfig
---@field presentMode hood.PresentMode

---@class hood.Surface
---@field new fun(window: winit.Window): hood.Surface
---@field configure fun(self: hood.Surface, device: hood.Device, config: hood.SurfaceConfig, oldSwapchain: hood.Swapchain?): hood.Swapchain
