local GLAdapter = require("hood-gl.adapter")
local GLSurface = require("hood-gl.surface")

---@class hood-gl.Instance: hood.Instance
local GLInstance = {}
GLInstance.__index = GLInstance

---@param _descriptor hood.InstanceDescriptor
function GLInstance.new(_descriptor)
	return setmetatable({}, GLInstance)
end

---@param config hood.AdapterConfig
---@param self hood-gl.Instance
function GLInstance:requestAdapter(config)
	return GLAdapter.new(config or {})
end

---@param window winit.Window
function GLInstance:createSurface(window)
	---@cast window winit-win32.Window
	return GLSurface.new(window)
end

return GLInstance
