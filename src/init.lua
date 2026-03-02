-- TODO: turn this into a feature flag when those exist in lpm
---@type boolean
VULKAN = os.getenv("VULKAN") == "1"

---@alias hood.Color { r: number, g: number, b: number, a: number }

local hood = {}

-- For self referential requires
package.loaded[(...)] = hood

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

--- No. You aren't getting a full implementation of this anytime soon.
---@enum hood.BlendState
hood.BlendState = {
	AlphaBlending = 1,
}

---@enum hood.ColorWrites
hood.ColorWrites = {
	Red = 0b1,
	Green = 0b10,
	Blue = 0b100,
	Alpha = 0b1000,
	Color = 0b0111,
	All = 0b1111,
}

---@enum hood.TextureFormat
hood.TextureFormat = {
	Rgba8UNorm = 1,
	Rgba8Uint = 2,

	Depth16Unorm = 3,
	Depth24Plus = 4,
	Depth32Float = 5,

	Bgra8UNorm = 6,
	Bgra8Srgb = 7,
}

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
