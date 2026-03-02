-- TODO: turn this into a feature flag when those exist in lpm
---@type boolean
VULKAN = os.getenv("VULKAN") == "1"

---@alias hood.Color { r: number, g: number, b: number, a: number }

local hood = {}

hood.Instance = require("hood.instance")

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

---@alias hood.PresentMode
--- | "immediate"
--- | "fifo"
--- | "fifo-relaxed"
--- | "mailbox"

---@alias hood.CompareFunction
--- | "never"
--- | "less"
--- | "equal"
--- | "less-equal"
--- | "greater"
--- | "not-equal"
--- | "greater-equal"
--- | "always"

---@alias hood.AddressMode
--- | "clamp-to-edge"
--- | "repeat"
--- | "mirrored-repeat"

---@alias hood.InstanceBackend "vulkan" | "opengl"
---@alias hood.InstanceFlag "validate"

--- TODO: This will be entirely removed and reworked, use with caution
---@alias hood.BlendState
--- | "alpha-blending"

---@enum hood.ColorWrites
hood.ColorWrites = {
	Red = 0b1,
	Green = 0b10,
	Blue = 0b100,
	Alpha = 0b1000,
	Color = 0b0111,
	All = 0b1111,
}

---@alias hood.TextureFormat
--- | "rgba8unorm"
--- | "rgba8uint"
--- | "bgra8unorm"
--- | "bgra8unorm-srgb"
--- | "depth16unorm"
--- | "depth24plus"
--- | "depth32float"

---@alias hood.FilterMode
--- | "nearest"
--- | "linear"

---@alias hood.IndexFormat
--- | "u16"
--- | "u32"

---@alias hood.ShaderModule
---| { type: "glsl", source: string }
---| { type: "spirv", source: string }

return hood
