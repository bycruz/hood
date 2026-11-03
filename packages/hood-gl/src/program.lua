local gl = require("glapi") ---@cast gl gl & hood-gl.GlConstants

---@class hood-gl.Program
---@field id number
local Program = {}
Program.__index = Program

---@param type gl.ShaderType
---@param src string
function Program.new(type, src)
	local id = gl.createShaderProgram(type, src)
	return setmetatable({ id = id }, Program)
end

---@param self hood-gl.Program
function Program:destroy()
	gl.deleteProgram(self.id)
end

return Program
