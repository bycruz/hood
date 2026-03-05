---@class hood.BindGroup
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
--- | "buffer"
--- | "sampler"
--- | "texture"
--- | "storageTexture"

---@class hood.Binding.Base
---@field binding number
---@field visibility hood.ShaderStage[]

---@class hood.Binding.Buffer: hood.Binding.Base
---@field type "buffer"
---@field buffer hood.Buffer

---@class hood.Binding.Sampler: hood.Binding.Base
---@field type "sampler"
---@field sampler hood.Sampler

---@class hood.Binding.Texture: hood.Binding.Base
---@field type "texture"
---@field texture hood.Texture

---@class hood.Binding.StorageTexture: hood.Binding.Base
---@field type "storageTexture"
---@field texture hood.Texture
---@field layer number?
---@field access hood.StorageAccess

---@alias hood.Binding
--- | hood.Binding.Buffer
--- | hood.Binding.Sampler
--- | hood.Binding.Texture
--- | hood.Binding.StorageTexture
