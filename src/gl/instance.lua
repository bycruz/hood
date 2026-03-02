local GLAdapter = require("hood.gl.adapter")
local GLSurface = require("hood.gl.surface")

---@class hood.gl.Instance: hood.Instance
local GLInstance = {}
GLInstance.__index = GLInstance

---@param _descriptor hood.InstanceDescriptor
function GLInstance.new(_descriptor)
	return setmetatable({}, GLInstance)
end

---@param config hood.AdapterConfig
function GLInstance:requestAdapter(config)
	return GLAdapter.new(config)
end

---@param window winit.Window
function GLInstance:createSurface(window)
	return GLSurface.new(window)
end

return GLInstance
