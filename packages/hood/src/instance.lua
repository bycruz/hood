-- Which backend an instance is made on.
--
-- The backends are packages of their own and a program installs the one it runs on: an app
-- whose lde.json names hood with `"features": [ "vk" ]` is a vulkan program, "gl" is an
-- opengl one, and naming both is a program that picks at runtime. Neither is installed
-- unless it is named, because the backend a program does not run on is a graphics API's
-- worth of code sitting in its bundle for nothing -- so asking for one that is not here
-- says so, rather than failing somewhere inside a require.
local Instance = {}

---@type table<hood.InstanceBackend, string> # the package each backend lives in
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

	if not ok then
		error("hood was installed without the " .. backend .. " backend: name it where hood "
			.. "is depended on, as {\"features\": [\""
			.. (backend == "vulkan" and "vk" or "gl") .. "\"]}")
	end

	return instance.new(descriptor)
end

return Instance
