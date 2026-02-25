local ffi = require("ffi")

---@param vk vk
return function(vk)
	local VKDevice = require("hood-vulkan.device")(vk)

	---@class vk.Instance
	---@field handle vk.ffi.Instance
	---@field v1_0 vk.Instance.Fns
	local VKInstance = {}
	VKInstance.__index = VKInstance

	---@class vk.DeviceQueueCreateInfo
	---@field queueFamilyIndex integer
	---@field queueCount integer
	---@field queuePriorities number[]

	---@class vk.DeviceCreateInfo
	---@field queueCreateInfos vk.DeviceQueueCreateInfo[]
	---@field enabledExtensionNames vk.DeviceExtensionName[]

	---@param physicalDevice vk.ffi.PhysicalDevice
	---@param info vk.DeviceCreateInfo?
	---@param allocator ffi.cdata*?
	---@return vk.Device
	function VKInstance:createDevice(physicalDevice, info, allocator)
		local device = ffi.new("VkDevice[1]")
		info = info or {}

		-- Convert queue create infos
		local queueCreateInfos = nil
		local queueCreateInfoCount = 0
		if info.queueCreateInfos and #info.queueCreateInfos > 0 then
			queueCreateInfoCount = #info.queueCreateInfos
			queueCreateInfos = vk.DeviceQueueCreateInfoArray(queueCreateInfoCount)
			for i, qci in ipairs(info.queueCreateInfos) do
				queueCreateInfos[i - 1].queueFamilyIndex = qci.queueFamilyIndex
				queueCreateInfos[i - 1].queueCount = qci.queueCount
				queueCreateInfos[i - 1].pQueuePriorities = ffi.new("float[?]", #qci.queuePriorities, qci.queuePriorities)
			end
		end

		-- Convert extension names
		local extensionNames = nil
		local extensionCount = 0
		if info.enabledExtensionNames and #info.enabledExtensionNames > 0 then
			extensionCount = #info.enabledExtensionNames
			extensionNames = ffi.new("const char*[?]", extensionCount)
			for i, name in ipairs(info.enabledExtensionNames) do
				extensionNames[i - 1] = name
			end
		end

		local deviceCreateInfo = vk.DeviceCreateInfo({
			queueCreateInfoCount = queueCreateInfoCount,
			pQueueCreateInfos = queueCreateInfos,
			enabledExtensionCount = extensionCount,
			ppEnabledExtensionNames = extensionNames,
			-- The other stuff is legacy so leave it zeroed
		})

		local result = self.v1_0.vkCreateDevice(physicalDevice, deviceCreateInfo, allocator, device)
		if result ~= 0 then
			error("Failed to create Vulkan device, error code: " .. tostring(result))
		end

		return VKDevice.new(device[0])
	end

	---@return vk.ffi.PhysicalDevice[]
	function VKInstance:enumeratePhysicalDevices()
		local deviceCount = ffi.new("uint32_t[1]", 0)
		local result = self.v1_0.vkEnumeratePhysicalDevices(self.handle, deviceCount, nil)
		if result ~= 0 then
			error("Failed to enumerate physical devices, error code: " .. tostring(result))
		end

		local devices = ffi.new("VkPhysicalDevice[?]", deviceCount[0])
		result = self.v1_0.vkEnumeratePhysicalDevices(self.handle, deviceCount, devices)
		if result ~= 0 then
			error("Failed to enumerate physical devices, error code: " .. tostring(result))
		end

		local deviceList = {}
		for i = 0, deviceCount[0] - 1 do
			deviceList[i + 1] = devices[i]
		end

		return deviceList
	end

	---@param createInfo vk.ffi.XlibSurfaceCreateInfoKHR
	---@param allocator ffi.cdata*?
	---@return vk.ffi.SurfaceKHR
	function VKInstance:createXlibSurfaceKHR(createInfo, allocator)
		local surface = ffi.new("VkSurfaceKHR[1]")

		local createInfo = vk.XlibSurfaceCreateInfoKHR(createInfo)

		local result = self.v1_0.vkCreateXlibSurfaceKHR(self.handle, createInfo, allocator, surface)
		if result ~= 0 then
			error("Failed to create Xlib surface, error code: " .. tostring(result))
		end

		return surface[0]
	end

	---@param createInfo vk.ffi.Win32SurfaceCreateInfoKHR
	---@param allocator ffi.cdata*?
	---@return vk.ffi.SurfaceKHR
	function VKInstance:createWin32SurfaceKHR(createInfo, allocator)
		local surface = ffi.new("VkSurfaceKHR[1]")

		local createInfo = vk.Win32SurfaceCreateInfoKHR(createInfo)

		local result = self.v1_0.vkCreateWin32SurfaceKHR(self.handle, createInfo, allocator, surface)
		if result ~= 0 then
			error("Failed to create Win32 surface, error code: " .. tostring(result))
		end

		return surface[0]
	end

	---@class vk.Instance.Fns
	---@field vkCreateDevice fun(physicalDevice: vk.ffi.PhysicalDevice, info: vk.ffi.DeviceCreateInfo?, allocator: ffi.cdata*?, device: vk.ffi.Device*): vk.ffi.Result
	---@field vkEnumeratePhysicalDevices fun(instance: vk.ffi.Instance, count: ffi.cdata*, devices: ffi.cdata*?): vk.ffi.Result
	---@field vkCreateXlibSurfaceKHR fun(instance: vk.ffi.Instance, info: ffi.cdata*, allocator: ffi.cdata*?, surface: ffi.cdata*): vk.ffi.Result
	---@field vkCreateWin32SurfaceKHR fun(instance: vk.ffi.Instance, info: ffi.cdata*, allocator: ffi.cdata*?, surface: ffi.cdata*): vk.ffi.Result

	---@param handle vk.ffi.Instance
	function VKInstance.new(handle)
		local v1_0Types = {
			vkCreateDevice = "VkResult(*)(VkPhysicalDevice, const VkDeviceCreateInfo*, const void*, VkDevice*)",
			vkEnumeratePhysicalDevices = "VkResult(*)(VkInstance, uint32_t*, VkPhysicalDevice*)",
			vkCreateXlibSurfaceKHR =
			"VkResult(*)(VkInstance, const VkXlibSurfaceCreateInfoKHR*, const VkAllocationCallbacks*, VkSurfaceKHR*)",
			vkCreateWin32SurfaceKHR =
			"VkResult(*)(VkInstance, const VkWin32SurfaceCreateInfoKHR*, const VkAllocationCallbacks*, VkSurfaceKHR*)",
		}

		---@type vk.Instance.Fns
		local v1_0 = {}
		for name, funcType in pairs(v1_0Types) do
			v1_0[name] = ffi.cast(funcType, vk.getInstanceProcAddr(handle, name))
		end

		return setmetatable({
			handle = handle,
			v1_0 = v1_0,
		}, VKInstance)
	end

	return VKInstance
end
