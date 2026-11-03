local GLDevice = require("hood-gl.device")

---@class hood-gl.Adapter
local GLAdapter = {}
GLAdapter.__index = GLAdapter

---@param config hood.AdapterConfig
function GLAdapter.new(config)
	return setmetatable({ config = config }, GLAdapter)
end

---@param self hood-gl.Adapter
function GLAdapter:requestDevice()
	return GLDevice.new()
end

return GLAdapter
