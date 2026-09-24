---@alias hood.TextureUsage
--- | "COPY_SRC"
--- | "COPY_DST"
--- | "TEXTURE_BINDING"
--- | "RENDER_ATTACHMENT"
--- | "STORAGE_BINDING"

---@alias hood.TextureDimension
--- | "1d"
--- | "2d"
--- | "3d"

---@alias hood.TextureExtents
--- | { dim: "3d", width: number, height: number, depth: number }
--- | { dim: "2d", width: number, height: number, count?: number }
--- | { dim: "1d", width: number, count?: number }

---@alias hood.TextureFormat
--- | "rgba8unorm"
--- | "rgba8uint"
--- | "bgra8unorm"
--- | "bgra8unorm-srgb"
--- | "depth16unorm"
--- | "depth24plus"
--- | "depth32float"


---@alias hood.TextureViewDimension
--- | "1d"
--- | "2d"
--- | "3d"
--- | "cube"
--- | "1d-array"
--- | "2d-array"
--- | "cube-array"

---@alias hood.TextureAspect
--- | "all"
--- | "stencil"
--- | "depth"
--- | "color"

---@class hood.TextureDescriptor
---@field extents hood.TextureExtents
---@field format hood.TextureFormat
---@field usages hood.TextureUsage[]
---@field mipLevelCount number?
---@field sampleCount number?

---@class hood.Texture
---@field new fun(device: hood.Device, descriptor: hood.TextureDescriptor): hood.Texture
---@field destroy fun(self: hood.Texture)
---@field createView fun(self: hood.Texture, descriptor: hood.TextureViewDescriptor): hood.TextureView
