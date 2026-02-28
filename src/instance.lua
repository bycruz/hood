---@class hood.Instance
---@field new fun(descriptor: hood.InstanceDescriptor): hood.Instance
---@field requestAdapter fun(self: hood.Instance, options: hood.AdapterConfig?): hood.Adapter
---@field createSurface fun(self: hood.Instance, window: winit.Window)

local Instance = {}

---@class hood.InstanceDescriptor
---@field backend hood.InstanceBackend
---@field flags hood.InstanceFlag[]

---@param descriptor hood.InstanceDescriptor
---@return hood.Instance
function Instance.new(descriptor)
	-- NOTE: This dynamically requires the backend specific module to avoid loading unnecessary code
	if descriptor.backend == "vulkan" then
		local VKInstance = require("hood.instance.vk")
		return VKInstance.new(descriptor)
	elseif descriptor.backend == "opengl" then
		local GLInstance = require("hood.instance.gl")
		return GLInstance.new(descriptor)
	else
		error("No supported backends specified in instance descriptor.")
	end
end

return Instance
