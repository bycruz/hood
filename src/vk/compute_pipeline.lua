local ffi = require("ffi")
local vk = require("vkapi")

---@class hood.vk.ComputePipeline
---@field handle vk.ffi.Pipeline
---@field layout vk.ffi.PipelineLayout
---@field device hood.vk.Device
local VKComputePipeline = {}
VKComputePipeline.__index = VKComputePipeline

---@param device hood.vk.Device
---@param descriptor hood.ComputePipelineDescriptor
function VKComputePipeline.new(device, descriptor)
	if descriptor.module.type ~= "spirv" then
		error("Only SPIR-V shaders are supported in the Vulkan backend.")
	end

	local shaderModule = device.handle:createShaderModule({
		codeSize = #descriptor.module.source,
		pCode = ffi.cast("const uint32_t*", descriptor.module.source),
	})

	local descriptorSetLayouts = vk.DescriptorSetLayoutArray(1)
	do
		local bgLayout = descriptor.layout --[[@as hood.vk.BindGroupLayout]]
		descriptorSetLayouts[0] = bgLayout.handle
	end

	local layout = device.handle:createPipelineLayout({
		setLayoutCount = 1,
		pSetLayouts = descriptorSetLayouts,
	})

	local handle = device.handle:createComputePipeline(nil, {
		stage = {
			stage = vk.ShaderStageFlagBits.COMPUTE,
			module = shaderModule,
			name = "main",
		},
		layout = layout,
	})

	-- No longer needed, pipeline stores whatever it needs
	-- TODO: Make this automatic via shaderModule gc
	device.handle:destroyShaderModule(shaderModule)

	return setmetatable({ handle = handle, layout = layout, device = device }, VKComputePipeline)
end

return VKComputePipeline
