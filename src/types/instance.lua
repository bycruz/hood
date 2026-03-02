---@class hood.Instance
---@field new fun(descriptor: hood.InstanceDescriptor): hood.Instance
---@field requestAdapter fun(self: hood.Instance, options: hood.AdapterConfig?): hood.Adapter
---@field createSurface fun(self: hood.Instance, window: winit.Window)

---@class hood.InstanceDescriptor
---@field backend hood.InstanceBackend
---@field flags hood.InstanceFlag[]
