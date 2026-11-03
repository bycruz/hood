local vk = require("vkapi") ---@cast vk vk & hood-vk.VkExtras

local VKAdapter = require("hood-vk.adapter")
local VKSurface = require("hood-vk.surface")

local isWindows = jit.os == "Windows"

---@class hood-vk.Instance: hood.Instance
---@field headless boolean
---@field handle vk.Instance
local VKInstance = {}
VKInstance.__index = VKInstance

---@param descriptor hood.InstanceDescriptor
function VKInstance.new(descriptor)
	local hasValidate = false
	local hasHeadless = false
	for _, flag in ipairs(descriptor.flags or {}) do
		if flag == "validate" then hasValidate = true end
		if flag == "headless" then hasHeadless = true end
	end

	---@type string[]
	local layers = {}
	if hasValidate then
		layers[#layers + 1] = "VK_LAYER_KHRONOS_validation"
	end

	if os.getenv("RENDERDOC_CAPTUREFILE_PREFIX") then
		layers[#layers + 1] = "VK_LAYER_RENDERDOC_Capture"
	end

	local handle = vk.createInstance({
		applicationInfo = {
			name = "Hood",
			version = 1,
			engineName = "Hood",
			engineVersion = 1,
			apiVersion = vk.ApiVersion.V1_0
		},
		enabledLayerNames = layers,
		enabledExtensionNames = hasHeadless and {} or {
			"VK_KHR_surface",
			isWindows and "VK_KHR_win32_surface" or "VK_KHR_xlib_surface",
		}
	})

	return setmetatable({ handle = handle, headless = hasHeadless }, VKInstance)
end

---@param config hood.AdapterConfig
---@param self hood-vk.Instance
---@return hood-vk.Adapter?
function VKInstance:requestAdapter(config)
	config = config or {}
	local deviceOrdering = {
		[vk.PhysicalDeviceType.DISCRETE_GPU] = 4,
		[vk.PhysicalDeviceType.INTEGRATED_GPU] = 3,
		[vk.PhysicalDeviceType.VIRTUAL_GPU] = 2,
		[vk.PhysicalDeviceType.CPU] = 1
	}

	local deviceOrderingFlip = config.powerPreference == "high-performance"
		and 1 or -1

	local devices = {}
	for _, physicalDevice in ipairs(self.handle:enumeratePhysicalDevices()) do
		local props = vk.getPhysicalDeviceProperties(physicalDevice)
		local ordering = deviceOrdering[props.deviceType] * deviceOrderingFlip

		devices[#devices + 1] = {
			device = physicalDevice,
			score = ordering
		}
	end

	table.sort(devices, function(a, b)
		return a.score > b.score
	end)

	if #devices > 0 then
		return VKAdapter.new(self, devices[1].device)
	end
end

---@param window winit.Window
---@param self hood-vk.Instance
---@return hood-vk.Surface
function VKInstance:createSurface(window)
	return VKSurface.new(self, window)
end

return VKInstance
