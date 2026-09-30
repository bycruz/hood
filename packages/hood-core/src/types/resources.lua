---@alias hood.Buffer.DataType "u32" | "f32"

---@alias hood.BufferUsage
--- | "COPY_DST"
--- | "COPY_SRC"
--- | "VERTEX"
--- | "INDEX"
--- | "UNIFORM"
--- | "STORAGE"
--- | "INDIRECT"
--- | "MAP_READ"

---@class hood.BufferDescriptor
---@field size number
---@field usages hood.BufferUsage[]
--- Asks for host-visible memory that stays mapped for the buffer's lifetime, so CPU writes
--- are a plain memcpy instead of a staged upload. Only worth it for data rewritten often:
--- Vulkan prefers device-local host-visible memory (resizable BAR) when the machine offers
--- it, and OpenGL ignores the flag because namedBufferSubData is already a direct upload.
---@field mapped boolean?

---@class hood.Buffer
---@field descriptor hood.BufferDescriptor
--- True when the CPU can write straight into the buffer's memory.
---@field isMapped boolean
---@field destroy fun(self: hood.Buffer)
---@field mapAsync fun(self: hood.Buffer)
---@field getMappedRange fun(self: hood.Buffer, offset: number?, size: number?): ffi.cdata*
---@field unmap fun(self: hood.Buffer)
---@field mappedPointer fun(self: hood.Buffer, offset: number?): ffi.cdata*
---@field assertWriteFits fun(self: hood.Buffer, size: number, offset: number?, data: ffi.cdata*?)

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

---@class hood.TextureView
---@field destroy fun(self: hood.TextureView)

---@class hood.TextureViewDescriptor
---@field format hood.TextureFormat?
---@field dimension hood.TextureViewDimension?
---@field usages hood.TextureUsage[]?
---@field aspect hood.TextureAspect?
---@field baseMipLevel number?
---@field levelCount number?
---@field baseArrayLayer number?
---@field layerCount number?

---@alias hood.AddressMode
--- | "clamp-to-edge"
--- | "repeat"
--- | "mirrored-repeat"

---@class hood.SamplerDescriptor
---@field addressModeU hood.AddressMode
---@field addressModeV hood.AddressMode
---@field addressModeW hood.AddressMode
---@field magFilter hood.FilterMode
---@field minFilter hood.FilterMode
---@field mipmapFilter hood.FilterMode
---@field lodMinClamp number?
---@field lodMaxClamp number?
---@field maxAnisotropy number?
---@field compareOp hood.CompareFunction?

---@class hood.Sampler
---@field new fun(desc: hood.SamplerDescriptor): hood.Sampler
---@field destroy fun(self: hood.Sampler)
