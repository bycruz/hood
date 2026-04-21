local vk = require("vkapi")
local vkConversions = require("hood.convert.vk")

local VKSwapchain = require("hood.vk.swapchain")

local isWindows = jit.os == "Windows"

---@class hood.vk.Surface
---@field window winit.Window
---@field handle vk.ffi.SurfaceKHR
---@field instance hood.vk.Instance
local VKSurface = {}
VKSurface.__index = VKSurface

---@param instance hood.vk.Instance
---@param window winit.Window
function VKSurface.new(instance, window)
	local handle ---@type vk.ffi.SurfaceKHR
	if isWindows then ---@cast window winit.win32.Window
		local kernel32 = require("winapi.kernel32")

		handle = instance.handle:createWin32SurfaceKHR({
			hinstance = kernel32.getModuleHandle(nil),
			hwnd = window.hwnd,
		})
	else ---@cast window winit.x11.Window
		handle = instance.handle:createXlibSurfaceKHR({
			dpy = window.display,
			window = window.id,
		})
	end

	return setmetatable({ window = window, handle = handle, instance = instance }, VKSurface)
end

---@param device hood.vk.Device
---@param config hood.SurfaceConfig
---@param oldSwapchain hood.vk.Swapchain?
---@return hood.vk.Swapchain
function VKSurface:configure(device, config, oldSwapchain)
	local caps = vk.getPhysicalDeviceSurfaceCapabilitiesKHR(device.pd, self.handle)
	local formats = vk.getPhysicalDeviceSurfaceFormatsKHR(device.pd, self.handle)

	---@type vk.ffi.SurfaceFormatKHR
	local format = formats[1]

	local imageCount = caps.minImageCount + 1
	if caps.maxImageCount > 0 and imageCount > caps.maxImageCount then
		imageCount = caps.maxImageCount
	end

	local extent = caps.currentExtent
	if extent.width == 0xFFFFFFFF then
		extent.width = self.window.width
		extent.height = self.window.height
	end

	local hoodFormat = vkConversions.from.textureFormat[format.format]
	if not hoodFormat then
		error("Unsupported swapchain format: " .. tostring(format.format))
	end

	-- Query supported present modes and validate requested mode
	local presentModes = vk.getPhysicalDeviceSurfacePresentModesKHR(device.pd, self.handle)
	local requestedPresentMode = vkConversions.presentMode[config.presentMode]

	---@type vk.PresentModeKHR?
	local presentMode = nil
	for _, mode in ipairs(presentModes) do
		if mode == requestedPresentMode then
			presentMode = requestedPresentMode
			break
		end
	end

	if not presentMode then
		error("Requested present mode not supported: " .. tostring(config.presentMode))
	end

	return VKSwapchain.new(device, hoodFormat, {
		surface = self.handle,
		minImageCount = imageCount,
		imageFormat = format.format,
		imageColorSpace = format.colorSpace,
		imageExtent = extent,
		imageArrayLayers = 1,
		imageUsage = vk.ImageUsageFlagBits.COLOR_ATTACHMENT,
		imageSharingMode = vk.SharingMode.EXCLUSIVE,
		preTransform = caps.currentTransform,
		compositeAlpha = vk.CompositeAlphaFlagBitsKHR.OPAQUE,
		presentMode = presentMode,
		clipped = 1,
		oldSwapchain = oldSwapchain and oldSwapchain.handle or nil
	})
end

return VKSurface
