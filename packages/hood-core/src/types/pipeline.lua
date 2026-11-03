---@alias hood.ShaderStage
--- | "VERTEX"
--- | "FRAGMENT"
--- | "COMPUTE"

---@class hood.BindGroupLayout
---@field destroy fun(self: hood.BindGroupLayout)

---@class hood.BindingLayout.Base
---@field binding number
---@field visibility hood.ShaderStage[]

---@class hood.BindingLayout.UniformBuffer: hood.BindingLayout.Base
---@field type "uniform-buffer"

---@class hood.BindingLayout.StorageBuffer: hood.BindingLayout.Base
---@field type "storage-buffer"

---@class hood.BindingLayout.Buffer: hood.BindingLayout.Base -- deprecated: use uniform-buffer or storage-buffer
---@field type "buffer"

---@class hood.BindingLayout.Sampler: hood.BindingLayout.Base
---@field type "sampler"

---@class hood.BindingLayout.Texture: hood.BindingLayout.Base
---@field type "texture"

---@class hood.BindingLayout.StorageTexture: hood.BindingLayout.Base
---@field type "storageTexture"

---@alias hood.BindingLayout
--- | hood.BindingLayout.UniformBuffer
--- | hood.BindingLayout.StorageBuffer
--- | hood.BindingLayout.Buffer
--- | hood.BindingLayout.Sampler
--- | hood.BindingLayout.Texture
--- | hood.BindingLayout.StorageTexture

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

---@class hood.BindGroup
---@field set number|ffi.cdata*
---@field entries hood.Binding[]
---@field destroy fun(self: hood.BindGroup)

---@class hood.BindGroupDescriptor
---@field layout hood.BindGroupLayout
---@field entries hood.Binding[]

---@alias hood.LoadOp
--- | { type: "clear", color: hood.Color }
--- | { type: "load" }

---@alias hood.DepthOp
--- | { type: "clear", depth: number }

---@alias hood.CompareFunction
--- | "never"
--- | "less"
--- | "equal"
--- | "less-equal"
--- | "greater"
--- | "not-equal"
--- | "greater-equal"
--- | "always"

---@alias hood.InstanceBackend "vulkan" | "opengl"
---@alias hood.InstanceFlag "validate" | "headless"

--- TODO: This will be entirely removed and reworked, use with caution
---@alias hood.BlendState
--- | "alpha-blending"

---@alias hood.FilterMode
--- | "nearest"
--- | "linear"

---@alias hood.IndexFormat
--- | "u16"
--- | "u32"

---@alias hood.ShaderModule
---| { type: "glsl", source: string }
---| { type: "spirv", source: string }

---@alias hood.Color { r: number, g: number, b: number, a: number }

---@alias hood.CullMode
--- | "none"
--- | "front"
--- | "back"

---@alias hood.FrontFace
--- | "clockwise"
--- | "counter-clockwise"

---@class hood.DepthStencilState
---@field depthWriteEnabled boolean
---@field depthCompare hood.CompareFunction
---@field format hood.TextureFormat

---@class hood.VertexState
---@field module hood.ShaderModule
---@field buffers hood.VertexLayout[]

---@class hood.ColorTargetState
---@field format hood.TextureFormat
---@field blend? hood.BlendState
---@field writeMask? number

---@class hood.FragmentState
---@field module hood.ShaderModule
---@field targets? hood.ColorTargetState[]

---@class hood.PrimitiveState
---@field cullMode hood.CullMode?
---@field frontFace hood.FrontFace?

---@class hood.PipelineDescriptor
---@field layout hood.BindGroupLayout?
---@field vertex hood.VertexState
---@field fragment hood.FragmentState
---@field primitive hood.PrimitiveState?
---@field depthStencil? hood.DepthStencilState

---@class hood.Pipeline
---@field handle number|ffi.cdata*
---@field destroy fun(self: hood.Pipeline)

---@class hood.ComputePipelineDescriptor
---@field module hood.ShaderModule
---@field layout hood.BindGroupLayout

---@class hood.ComputePipeline
---@field handle number|ffi.cdata*
---@field destroy fun(self: hood.ComputePipeline)
