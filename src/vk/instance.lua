local ffi = require("ffi")
local vk = require("vkapi")

local VKAdapter = require("hood.vk.adapter")
local VKSurface = require("hood.vk.surface")

local isWindows = jit.os == "Windows"

---@class hood.vk.Instance
---@field handle vk.Instance
local VKInstance = {}
VKInstance.__index = VKInstance

---@param descriptor hood.InstanceDescriptor
function VKInstance.new(descriptor)
	local hasValidate = false
	for _, flag in ipairs(descriptor.flags or {}) do
		if flag == "validate" then
			hasValidate = true
			break
		end
	end

	local handle = vk.createInstance({
		applicationInfo = {
			name = "Hood",
			version = 1,
			engineName = "Hood",
			engineVersion = 1,
			apiVersion = vk.ApiVersion.V1_0
		},
		enabledLayerNames = hasValidate and { "VK_LAYER_KHRONOS_validation" },
		enabledExtensionNames = {
			"VK_KHR_surface",
			isWindows and "VK_KHR_win32_surface" or "VK_KHR_xlib_surface",
		}
	})

	return setmetatable({ handle = handle }, VKInstance)
end

---@param config hood.AdapterConfig
function VKInstance:requestAdapter(config)
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
function VKInstance:createSurface(window)
	return VKSurface.new(self, window)
end

return VKInstance
