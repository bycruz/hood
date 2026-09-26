local vk = require("vkapi")
local vkConversions = require("hood-vk.convert")

local VKSwapchain = require("hood-vk.swapchain")

local isWindows = jit.os == "Windows"

---@class hood-vk.Surface
---@field window winit.Window
---@field handle vk.ffi.SurfaceKHR
---@field instance hood-vk.Instance
local VKSurface = {}
VKSurface.__index = VKSurface

---@param instance hood-vk.Instance
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

---@param device hood-vk.Device
---@param config hood.SurfaceConfig
---@param oldSwapchain hood-vk.Swapchain?
---@return hood-vk.Swapchain? swapchain # Nothing where the surface has no size to make one for
function VKSurface:configure(device, config, oldSwapchain)
	-- The old swapchain is deliberately not torn down here: it is still needed
	-- as the `oldSwapchain` argument below so the new one can take over its
	-- images. It is destroyed in full once the replacement exists.

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

	-- A surface with no size has no swapchain to make, and what is answered is nothing: the
	-- caller keeps the swapchain it has and drops the frame.
	--
	-- A window that is minimized, or one being dragged, comes to nought by nought -- windows
	-- answers an iconized window with an extent of 120x0 -- and a swapchain made for an extent
	-- like that is one the presentation engine never gives an image back from, which an acquire
	-- can only report as VK_TIMEOUT. There is nothing a frame can do about that, so it is not
	-- made in the first place: the swapchain the window already had is a better thing to hold
	-- on to, and the window has a size again the moment it is restored.
	if extent.width == 0 or extent.height == 0 then
		return nil
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

    local swapchainInfo = vk.SwapchainCreateInfoKHR({
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

	local newSwapchain = VKSwapchain.new(device, hoodFormat, swapchainInfo)
	newSwapchain.surface = self

	if oldSwapchain then
		-- Full teardown, not just the sync objects and command buffers: the
		-- old swapchain's framebuffers and image views reference images that
		-- destroySwapchainKHR is about to invalidate, so they have to go first.
		-- This waits for the queue to go idle, which also makes it safe for the
		-- caller to drop anything the old swapchain was rendering into.
		oldSwapchain:destroy()
	end

	return newSwapchain
end

return VKSurface
