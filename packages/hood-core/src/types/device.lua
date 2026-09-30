---@class hood.Device
---@field queue hood.Queue
---@field createPipeline fun(self: hood.Device, descriptor: hood.PipelineDescriptor): hood.Pipeline
---@field createBuffer fun(self: hood.Device, descriptor: hood.BufferDescriptor): hood.Buffer
---@field createCommandEncoder fun(self: hood.Device): hood.CommandEncoder
---@field createBindGroup fun(self: hood.Device, entries: hood.BindGroupDescriptor): hood.BindGroup
---@field createBindGroupLayout fun(self: hood.Device, entries: hood.BindingLayout[]): hood.BindGroupLayout
---@field createSampler fun(self: hood.Device, descriptor: hood.SamplerDescriptor): hood.Sampler
---@field createTexture fun(self: hood.Device, descriptor: hood.TextureDescriptor): hood.Texture
---@field createTextureView fun(self: hood.Device, descriptor: hood.TextureViewDescriptor): hood.TextureView
---@field createComputePipeline fun(self: hood.Device, descriptor: hood.ComputePipelineDescriptor): hood.ComputePipeline

---@class hood.AdapterConfig
---@field powerPreference? "low-power" | "high-performance"

---@class hood.Adapter
---@field requestDevice fun(self: hood.Adapter): hood.Device

---@alias hood.PresentMode
--- | "immediate"
--- | "fifo"
--- | "fifo-relaxed"
--- | "mailbox"

---@class hood.SurfaceConfig
---@field presentMode hood.PresentMode
---@field format hood.TextureFormat?

---@class hood.Surface
---@field new fun(window: winit.Window): hood.Surface
---@field configure fun(self: hood.Surface, device: hood.Device, config: hood.SurfaceConfig, oldSwapchain: hood.Swapchain?): hood.Swapchain? # Nothing where the window has no size to make one for, which is what a minimized one is

---@class hood.Swapchain
---@field width number
---@field height number
---@field present fun(self: hood.Swapchain)
---@field getCurrentTexture fun(self: hood.Swapchain): hood.Texture?
---@field createCommandEncoder fun(self: hood.Swapchain): hood.CommandEncoder # one per image, free to record into
---@field destroy fun(self: hood.Swapchain)
