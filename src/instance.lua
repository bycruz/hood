local Instance = {}

---@param descriptor hood.InstanceDescriptor
---@return hood.Instance
function Instance.new(descriptor)
	-- NOTE: This dynamically requires the backend specific module to avoid loading unnecessary code
	if descriptor.backend == "vulkan" then
		local VKInstance = require("hood.vk.instance")
		return VKInstance.new(descriptor)
	elseif descriptor.backend == "opengl" then
		local GLInstance = require("hood.gl.instance")
		return GLInstance.new(descriptor)
	else
		error("No supported backends specified in instance descriptor.")
	end
end

return Instance
