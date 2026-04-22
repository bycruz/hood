---@class hood.BindGroupLayout
---@field destroy fun(self: hood.BindGroupLayout)

---@class hood.BindingLayout.Base
---@field binding number
---@field visibility hood.ShaderStage[]

---@class hood.BindingLayout.Buffer: hood.BindingLayout.Base
---@field type "buffer"

---@class hood.BindingLayout.Sampler: hood.BindingLayout.Base
---@field type "sampler"

---@class hood.BindingLayout.Texture: hood.BindingLayout.Base
---@field type "texture"

---@class hood.BindingLayout.StorageTexture: hood.BindingLayout.Base
---@field type "storageTexture"

---@alias hood.BindingLayout
--- | hood.BindingLayout.Buffer
--- | hood.BindingLayout.Sampler
--- | hood.BindingLayout.Texture
--- | hood.BindingLayout.StorageTexture
