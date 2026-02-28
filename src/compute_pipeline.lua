---@class hood.ComputePipelineDescriptor
---@field module hood.ShaderModule

---@class hood.ComputePipeline
local ComputePipeline = VULKAN and require("hood.compute_pipeline.vk")
	or require("hood.compute_pipeline.gl") --[[@as hood.ComputePipeline]]

return ComputePipeline
