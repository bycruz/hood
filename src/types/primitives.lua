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
---@alias hood.InstanceFlag "validate"

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
