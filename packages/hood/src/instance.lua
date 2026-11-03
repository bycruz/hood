-- Which backend an instance is made on.
--
-- Each backend is a package of its own, installed only when the app names it in lde.json, so
-- asking for one that is not here says which feature to name rather than failing in a require.
local Instance = {}

local PACKAGES = {
	vulkan = "hood-vk",
	opengl = "hood-gl",
}

---@param descriptor hood.InstanceDescriptor
---@return hood.Instance
function Instance.new(descriptor)
	---@type hood.InstanceBackend
	local backend = descriptor.backend

	local package = PACKAGES[backend]
	if not package then
		error("No supported backends specified in instance descriptor.")
	end

	-- NOTE: This dynamically requires the backend specific module to avoid loading unnecessary code
	local ok, instance = pcall(require, package)
	---@cast instance hood.InstanceBackendModule

	if not ok then
		error("hood was installed without the " .. backend .. " backend: name it where hood "
			.. "is depended on, as {\"features\": [\""
			.. (backend == "vulkan" and "vk" or "gl") .. "\"]}")
	end

	return instance.new(descriptor)
end

return Instance
