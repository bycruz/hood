local ffi = require("ffi")

ffi.cdef([[#embed "ffi/ffidefs.h"]])

local vkEnums = require("hood-vulkan.ffi.enums")

---@class vk: vk.RawEnums
---@field PresentInfoKHR fun(): vk.ffi.PresentInfoKHR
---@field RenderPassBeginInfo fun(): vk.ffi.RenderPassBeginInfo
---@field PipelineLayoutCreateInfo fun(): vk.ffi.PipelineLayoutCreateInfo
local vk = {}
for k, v in pairs(vkEnums) do
	vk[k] = v
end

-- Type constructors (typed as fields above)
do
	---@param ffiName string
	---@param structureTypeName string
	local function defStruct(ffiName, structureTypeName)
		vk[ffiName] = function()
			local info = ffi.new("Vk" .. ffiName)
			info.sType = vk.StructureType[structureTypeName]
			return info
		end
	end

	local function defType(ffiName)
		vk[ffiName] = function()
			return ffi.new("Vk" .. ffiName)
		end
	end

	defStruct("PresentInfoKHR", "PRESENT_INFO_KHR")
	defStruct("RenderPassBeginInfo", "RENDER_PASS_BEGIN_INFO")
	defStruct("PipelineLayoutCreateInfo", "PIPELINE_LAYOUT_CREATE_INFO")
end

-- Constants
do
	vk.NULL = 0
	vk.SUBPASS_EXTERNAL = 0xFFFFFFFF
end

local VKInstance = require("hood-vulkan.instance")(vk)

do
	local C = ffi.load("vulkan.so.1")

	---@class vk.ApplicationInfo
	---@field name string
	---@field version number
	---@field engineName string
	---@field engineVersion number
	---@field apiVersion vk.ApiVersion

	---@class vk.InstanceCreateInfo
	---@field applicationInfo vk.ApplicationInfo
	---@field enabledLayerNames string[]
	---@field enabledExtensionNames vk.InstanceExtensionName[]

	---@param info vk.InstanceCreateInfo
	---@param allocator ffi.cdata*?
	---@return vk.Instance
	function vk.createInstance(info, allocator)
		local instance = ffi.new("VkInstance[1]")

		local layerCount = info.enabledLayerNames and #info.enabledLayerNames or 0
		local layerNames = ffi.new("const char*[?]", math.max(layerCount, 1))
		for i = 1, layerCount do
			layerNames[i - 1] = ffi.cast("const char*", info.enabledLayerNames[i])
		end

		local extCount = info.enabledExtensionNames and #info.enabledExtensionNames or 0
		local extNames = ffi.new("const char*[?]", math.max(extCount, 1))
		for i = 1, extCount do
			extNames[i - 1] = ffi.cast("const char*", info.enabledExtensionNames[i])
		end

		local appInfo = ffi.new("VkApplicationInfo", {
			sType = vkEnums.StructureType.APPLICATION_INFO,
			pApplicationName = info.applicationInfo.name,
			applicationVersion = info.applicationInfo.version,
			pEngineName = info.applicationInfo.engineName,
			engineVersion = info.applicationInfo.engineVersion,
			apiVersion = info.applicationInfo.apiVersion,
		})

		local createInfo = ffi.new("VkInstanceCreateInfo", {
			sType = vkEnums.StructureType.INSTANCE_CREATE_INFO,
			flags = 0,
			pApplicationInfo = appInfo,
			enabledLayerCount = layerCount,
			ppEnabledLayerNames = layerNames,
			enabledExtensionCount = extCount,
			ppEnabledExtensionNames = extNames,
		})

		local result = C.vkCreateInstance(createInfo, allocator, instance)
		if result ~= 0 then
			error("Failed to create Vulkan instance, error code: " .. tostring(result))
		end

		return VKInstance.new(instance[0])
	end

	---@param physicalDevice vk.ffi.PhysicalDevice
	function vk.getPhysicalDeviceProperties(physicalDevice)
		local properties = ffi.new("VkPhysicalDeviceProperties")
		C.vkGetPhysicalDeviceProperties(physicalDevice, properties)
		return properties --[[@as vk.ffi.PhysicalDeviceProperties]]
	end

	---@param physicalDevice vk.ffi.PhysicalDevice
	---@return vk.ffi.PhysicalDeviceMemoryProperties
	function vk.getPhysicalDeviceMemoryProperties(physicalDevice)
		local memProperties = ffi.new("VkPhysicalDeviceMemoryProperties")
		C.vkGetPhysicalDeviceMemoryProperties(physicalDevice, memProperties)
		return memProperties --[[@as vk.ffi.PhysicalDeviceMemoryProperties]]
	end

	---@param physicalDevice vk.ffi.PhysicalDevice
	---@return vk.ffi.QueueFamilyProperties[]
	function vk.getPhysicalDeviceQueueFamilyProperties(physicalDevice)
		local count = ffi.new("uint32_t[1]")
		C.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, count, nil)

		local properties = ffi.new("VkQueueFamilyProperties[?]", count[0])
		C.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, count, properties)

		local propertyTable = {}
		for i = 0, count[0] - 1 do
			propertyTable[i + 1] = properties[i]
		end
		return propertyTable
	end

	---@param physicalDevice vk.ffi.PhysicalDevice
	---@param surface vk.ffi.SurfaceKHR
	---@return vk.ffi.SurfaceCapabilitiesKHR
	function vk.getPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface)
		local capabilities = ffi.new("VkSurfaceCapabilitiesKHR")
		local result = C.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, capabilities)
		if result ~= 0 then
			error("Failed to get physical device surface capabilities, error code: " .. tostring(result))
		end
		return capabilities --[[@as vk.ffi.SurfaceCapabilitiesKHR]]
	end

	---@param physicalDevice vk.ffi.PhysicalDevice
	---@param surface vk.ffi.SurfaceKHR
	---@return vk.ffi.SurfaceFormatKHR[]
	function vk.getPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface)
		local count = ffi.new("uint32_t[1]")
		local result = C.vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, count, nil)
		if result ~= 0 then
			error("Failed to get surface format count, error code: " .. tostring(result))
		end

		local formats = ffi.new("VkSurfaceFormatKHR[?]", count[0])
		result = C.vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, count, formats)
		if result ~= 0 then
			error("Failed to get surface formats, error code: " .. tostring(result))
		end

		local formatTable = {}
		for i = 0, count[0] - 1 do
			formatTable[i + 1] = formats[i]
		end
		return formatTable
	end

	---@param physicalDevice vk.ffi.PhysicalDevice
	---@param surface vk.ffi.SurfaceKHR
	---@return vk.PresentModeKHR[]
	function vk.getPhysicalDeviceSurfacePresentModesKHR(physicalDevice, surface)
		local count = ffi.new("uint32_t[1]")
		local result = C.vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, surface, count, nil)
		if result ~= 0 then
			error("Failed to get present mode count, error code: " .. tostring(result))
		end

		local modes = ffi.new("VkPresentModeKHR[?]", count[0])
		result = C.vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, surface, count, modes)
		if result ~= 0 then
			error("Failed to get present modes, error code: " .. tostring(result))
		end

		local modeTable = {}
		for i = 0, count[0] - 1 do
			modeTable[i + 1] = modes[i]
		end
		return modeTable
	end

	---@type fun(instance: vk.ffi.Instance, name: string): ffi.cdata*
	vk.getInstanceProcAddr = C.vkGetInstanceProcAddr

	---@type fun(device: vk.ffi.Device, name: string): ffi.cdata*
	vk.getDeviceProcAddr = C.vkGetDeviceProcAddr
end

return vk
