local user32 = require("winapi.user32")
local kernel32 = require("winapi.kernel32")
local wgl = require("winapi.wgl")
local gdi = require("winapi.gdi")

---@class Win32Context
---@field display user32.HDC
---@field ctx wgl.HGLRC
---@field _hwnd user32.HWND?
---@field _class string?
local Win32Context = {}
Win32Context.__index = Win32Context

local headlessClassCount = 0

---Register a window class for a headless OpenGL context.
---@return string, user32.HMODULE
local function registerHeadlessClass()
	headlessClassCount = headlessClassCount + 1
	local className = "Hood_Headless_GL_" .. tostring(headlessClassCount)

	local hInstance = kernel32.getModuleHandle(nil)

	local wc = user32.WndClassEx()
	wc.style = bit.bor(user32.CS.HREDRAW, user32.CS.VREDRAW)
	wc.lpfnWndProc = user32.WndProc(user32.defWindowProc)
	wc.hInstance = hInstance
	wc.hCursor = user32.loadCursor(nil, user32.IDC.ARROW)
	wc.lpszClassName = className
	wc.hbrBackground = user32.getSysColorBrush(user32.COLOR.WINDOW)

	local atom = user32.registerClass(wc)
	if atom == 0 then
		error("Failed to register headless window class: " .. tostring(kernel32.getLastErrorMessage()))
	end

	return className, hInstance
end

---Create a headless OpenGL context (no visible window).
---@param sharedCtx Win32Context?
function Win32Context.fromHeadless(sharedCtx)
	local className, hInstance = registerHeadlessClass()

	local hwnd = user32.createWindow(
		0,            -- dwExStyle
		className,    -- lpClassName
		"Hood Headless GL", -- lpWindowName
		user32.WS.POPUP, -- dwStyle (hidden popup window)
		0, 0, 1, 1,   -- x, y, width, height
		nil,          -- hWndParent
		nil,          -- hMenu
		hInstance,    -- hInstance
		nil           -- lpParam
	)

	if hwnd == nil then
		error("Failed to create headless window: " .. tostring(kernel32.getLastErrorMessage()))
	end

	local hdc = user32.getDC(hwnd)

	local pfDescriptor = gdi.newPFD()
	local pf = gdi.choosePixelFormat(hdc, pfDescriptor)
	if pf == 0 then
		user32.destroyWindow(hwnd)
		error("Failed to choose pixel format: " .. tostring(kernel32.getLastErrorMessage()))
	end

	if gdi.setPixelFormat(hdc, pf, pfDescriptor) == 0 then
		user32.destroyWindow(hwnd)
		error("Failed to set pixel format: " .. tostring(kernel32.getLastErrorMessage()))
	end

	local hglrc = wgl.createContext(hdc)
	if not hglrc then
		user32.destroyWindow(hwnd)
		error("Failed to create OpenGL context: " .. tostring(kernel32.getLastErrorMessage()))
	end

	if sharedCtx then
		if not wgl.shareLists(sharedCtx.ctx, hglrc) then
			wgl.deleteContext(hglrc)
			user32.destroyWindow(hwnd)
			error("Failed to share OpenGL lists: " .. tostring(kernel32.getLastErrorMessage()))
		end
	end

	return setmetatable({
		display = hdc,
		ctx = hglrc,
		_hwnd = hwnd,
		_class = className,
	}, Win32Context)
end

---@param window winit.win32.Window
---@param sharedCtx Win32Context?
function Win32Context.fromWindow(window, sharedCtx)
	local hdc = user32.getDC(window.hwnd)

	local pfDescriptor = gdi.newPFD()
	local pf = gdi.choosePixelFormat(hdc, pfDescriptor)
	if pf == 0 then
		error("Failed to choose pixel format: " .. tostring(kernel32.getLastErrorMessage()))
	end

	if gdi.setPixelFormat(hdc, pf, pfDescriptor) == 0 then
		error("Failed to set pixel format: " .. tostring(kernel32.getLastErrorMessage()))
	end

	local hglrc = wgl.createContext(hdc)
	if not hglrc then
		error("Failed to create OpenGL context: " .. tostring(kernel32.getLastErrorMessage()))
	end

	if sharedCtx then
		if not wgl.shareLists(sharedCtx.ctx, hglrc) then
			wgl.deleteContext(hglrc)
			error("Failed to share OpenGL lists: " .. tostring(kernel32.getLastErrorMessage()))
		end
	end

	return setmetatable({ display = hdc, ctx = hglrc }, Win32Context)
end

function Win32Context:makeCurrent()
	if wgl.makeCurrent(self.display, self.ctx) == 0 then
		error("Failed to make OpenGL context current: " .. tostring(kernel32.getLastErrorMessage()))
	end
end

function Win32Context:swapBuffers()
	gdi.swapBuffers(self.display)
end

function Win32Context:setSwapInterval(interval)
	if wgl.swapIntervalEXT then
		wgl.swapIntervalEXT(interval)
	end
end

function Win32Context:destroy()
	wgl.deleteContext(self.ctx)

	if self._hwnd then
		user32.destroyWindow(self._hwnd)
		if self._class then
			user32.unregisterClass(self._class, kernel32.getModuleHandle(nil))
		end
	end
end

return Win32Context
