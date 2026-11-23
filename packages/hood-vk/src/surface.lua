local vk = require("vkapi") ---@cast vk vk & hood-vk.VkExtras
local bit = require("bit")
local vkConversions = require("hood-vk.convert")

local VKSwapchain = require("hood-vk.swapchain")

local isWindows = jit.os == "Windows"
local isAndroid = jit.android == true

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
	if isAndroid then ---@cast window winit-android.Window
		local native = window.nativeWindow
		if native == nil then
			error("hood-vk: the Android window has no native surface yet")
		end
		handle = instance.handle:createAndroidSurfaceKHR({ window = native })
	elseif isWindows then ---@cast window winit-win32.Window
		local kernel32 = require("winapi.kernel32")

		handle = instance.handle:createWin32SurfaceKHR({
			hinstance = kernel32.getModuleHandle(nil),
			hwnd = window.hwnd,
		})
	else ---@cast window winit-x11.Window
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
---@param self hood-vk.Surface
function VKSurface:configure(device, config, oldSwapchain)
	-- The old swapchain is not torn down here: it is the `oldSwapchain` argument below, and is
	-- destroyed in full once its replacement exists.

	local caps = vk.getPhysicalDeviceSurfaceCapabilitiesKHR(device.pd, self.handle)
	local formats = vk.getPhysicalDeviceSurfaceFormatsKHR(device.pd, self.handle)

	local format = vkConversions.pickSurfaceFormat(formats, config.format)

	local imageCount = caps.minImageCount + 1
	if caps.maxImageCount > 0 and imageCount > caps.maxImageCount then
		imageCount = caps.maxImageCount
	end

	local extent = caps.currentExtent
	if extent.width == 0xFFFFFFFF then
		extent.width = self.window.width
		extent.height = self.window.height
	elseif isAndroid and self.window.width > 0 and self.window.height > 0 then
		-- Android reports a rotated window's new size here a resize late: the extent it hands back
		-- while the window is turning is the size it had before, and a swapchain made at that is a
		-- frame the compositor squeezes into the new shape. The window's own size is current, and
		-- Android scales whatever extent a swapchain is made at, within the limits it reports.
		extent.width = math.max(caps.minImageExtent.width, math.min(caps.maxImageExtent.width, self.window.width))
		extent.height = math.max(caps.minImageExtent.height, math.min(caps.maxImageExtent.height, self.window.height))
	end

	-- A minimized or dragged window has no size to make a swapchain for, and one made for a
	-- degenerate extent is never given an image back. The caller keeps the swapchain it has and
	-- drops the frame; the window has a size again when it is restored.
	if extent.width == 0 or extent.height == 0 then
		return nil
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

    if not presentMode then -- Fall back to FIFO as IMMEDIATE is not guaranteed on android
        for _, mode in ipairs(presentModes) do
            if mode == vk.PresentModeKHR.FIFO then
                presentMode = mode
                break
            end
        end
    end
    if not presentMode then
        error("Requested present mode not supported: " .. tostring(config.presentMode))
    end

    -- What the compositor turns the frame by: the surface's current transform. `preTransform`
    -- tells the presentation engine whether the app has already made that turn. A screen here is
    -- laid out in the orientation the pixels are in, so the app has not: asking for IDENTITY makes
    -- the compositor turn it, and the frame is upright on a phone held sideways. The turn is only
    -- avoided where IDENTITY is not one of the transforms the surface supports.
    local preTransform = vk.SurfaceTransformFlagBitsKHR.IDENTITY
    if bit.band(caps.supportedTransforms, preTransform) == 0 then
    	preTransform = caps.currentTransform
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
		preTransform = preTransform,
		compositeAlpha = vk.CompositeAlphaFlagBitsKHR.OPAQUE,
		presentMode = presentMode,
		clipped = 1,
		oldSwapchain = oldSwapchain and oldSwapchain.handle or nil
    })

	local newSwapchain = VKSwapchain.new(device, vkConversions.from.textureFormat[format.format],
		swapchainInfo)
	newSwapchain.surface = self

	if oldSwapchain then
		-- Framebuffers and image views reference images destroySwapchainKHR is about to
		-- invalidate, so they go first. This waits for the queue to go idle, which also makes it
		-- safe for the caller to drop whatever the old swapchain was rendering into.
		oldSwapchain:destroy()
	end

	return newSwapchain
end

--- Gives the surface back. Android takes a window's surface away whenever the app goes to the
--- background, and the one it hands back on return is a new one this has to be made for again.
function VKSurface:destroy()
	self.instance.handle:destroySurfaceKHR(self.handle)
end

return VKSurface
