---@class hood.ComputePipelineDescriptor
---@field module hood.ShaderModule

---@class hood.ComputePipeline
local ComputePipeline = VULKAN and require("hood.vk.compute_pipeline")
	or require("hood.gl.compute_pipeline") --[[@as hood.ComputePipeline]]

return ComputePipeline
