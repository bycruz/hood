---@class hood.BindGroup
---@field entries hood.Binding[]
---@field destroy fun(self: hood.BindGroup)

---@class hood.BindGroupDescriptor
---@field layout hood.BindGroupLayout
---@field entries hood.Binding[]

---@alias hood.ShaderStage
--- | "VERTEX"
--- | "FRAGMENT"
--- | "COMPUTE"

---@alias hood.StorageAccess
--- | "READ_ONLY"
--- | "WRITE_ONLY"
--- | "READ_WRITE"

---@alias hood.BindingType
--- | "uniform-buffer"
--- | "storage-buffer"
--- | "buffer" -- deprecated alias for storage-buffer
--- | "sampler"
--- | "texture"
--- | "storageTexture"

---@class hood.Binding.Base
---@field binding number
---@field visibility hood.ShaderStage[]

---@class hood.Binding.UniformBuffer: hood.Binding.Base
---@field type "uniform-buffer"
---@field buffer hood.Buffer

---@class hood.Binding.StorageBuffer: hood.Binding.Base
---@field type "storage-buffer"
---@field buffer hood.Buffer

---@class hood.Binding.Buffer: hood.Binding.Base -- deprecated: use uniform-buffer or storage-buffer
---@field type "buffer"
---@field buffer hood.Buffer

---@class hood.Binding.Sampler: hood.Binding.Base
---@field type "sampler"
---@field sampler hood.Sampler

---@class hood.Binding.Texture: hood.Binding.Base
---@field type "texture"
---@field texture hood.TextureView

---@class hood.Binding.StorageTexture: hood.Binding.Base
---@field type "storageTexture"
---@field texture hood.TextureView
---@field layer number?
---@field access hood.StorageAccess

---@alias hood.Binding
--- | hood.Binding.UniformBuffer
--- | hood.Binding.StorageBuffer
--- | hood.Binding.Buffer
--- | hood.Binding.Sampler
--- | hood.Binding.Texture
--- | hood.Binding.StorageTexture
