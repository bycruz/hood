local vk = require("vkapi") ---@cast vk vk & hood-vk.VkExtras

local VKAdapter = require("hood-vk.adapter")
local VKSurface = require("hood-vk.surface")

local isWindows = jit.os == "Windows"
local isAndroid = jit.android == true

---@class hood-vk.Instance: hood.Instance
---@field headless boolean
---@field handle vk.Instance
---@field rankDeviceType fun(deviceType: vk.PhysicalDeviceType, powerPreference: "low-power"|"high-performance"|nil): number # static helper, not a method
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
			isAndroid and "VK_KHR_android_surface"
				or isWindows and "VK_KHR_win32_surface"
				or "VK_KHR_xlib_surface",
		}
	})

	return setmetatable({ handle = handle, headless = hasHeadless }, VKInstance)
end

-- Higher wins. The CPU device type is a software rasterizer (lavapipe, llvmpipe,
-- ...): it is ranked below every GPU type so it is only picked when the machine
-- has no GPU at all. No preference is the battery-friendly ordering, which is
-- what "low-power" asks for.
local deviceTypeRanks = {
	lowPower = {
		[vk.PhysicalDeviceType.INTEGRATED_GPU] = 5,
		[vk.PhysicalDeviceType.DISCRETE_GPU] = 4,
		[vk.PhysicalDeviceType.VIRTUAL_GPU] = 3,
		[vk.PhysicalDeviceType.OTHER] = 2,
		[vk.PhysicalDeviceType.CPU] = 0,
	},
	highPerformance = {
		[vk.PhysicalDeviceType.DISCRETE_GPU] = 5,
		[vk.PhysicalDeviceType.INTEGRATED_GPU] = 4,
		[vk.PhysicalDeviceType.VIRTUAL_GPU] = 3,
		[vk.PhysicalDeviceType.OTHER] = 2,
		[vk.PhysicalDeviceType.CPU] = 0,
	},
}

--- Rank a physical device type for adapter selection; higher is better. CPU
--- always ranks last, whatever the preference, so a software renderer is never
--- chosen over an available GPU.
---@param deviceType vk.PhysicalDeviceType
---@param powerPreference "low-power"|"high-performance"|nil
---@return number
local function rankDeviceType(deviceType, powerPreference)
	local ranks = powerPreference == "high-performance"
		and deviceTypeRanks.highPerformance
		or deviceTypeRanks.lowPower
	local rank = ranks[deviceType]
	return rank ~= nil and rank or ranks[vk.PhysicalDeviceType.OTHER]
end
VKInstance.rankDeviceType = rankDeviceType

---@param config hood.AdapterConfig
---@param self hood-vk.Instance
---@return hood-vk.Adapter?
function VKInstance:requestAdapter(config)
	config = config or {}

	local devices = {}
	for _, physicalDevice in ipairs(self.handle:enumeratePhysicalDevices()) do
		local props = vk.getPhysicalDeviceProperties(physicalDevice)

		devices[#devices + 1] = {
			device = physicalDevice,
			score = rankDeviceType(props.deviceType, config.powerPreference)
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
