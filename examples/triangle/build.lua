local sep = string.sub(package.config, 1, 1)

---@type string
local dirName = debug.getinfo(1, "S").source:sub(2):match("(.*)" .. sep)

---@param stage "vert" | "frag"
---@param glslPath string
---@param outputPath string
local function glslToSpirv(stage, glslPath, outputPath)
	local command = string.format("glslc -fshader-stage=%s %s -o %s", stage, glslPath, outputPath)

	local result = os.execute(command)
	if result ~= 0 then
		error("Failed to compile GLSL shader: " .. glslPath)
	end
end

---@param path string
local function exists(path)
	local handle = io.open(path, "r")
	if handle then
		handle:close()
		return true
	end

	return false
end

if os.getenv("VULKAN") then
	local inputVertex = dirName .. "/shaders/triangle.vert.glsl"
	local outputVertex = dirName .. "/shaders/triangle.vert.spv"
	if not exists(outputVertex) then
		print("SPIR-V vertex shader not found, compiling GLSL to SPIR-V...")
		glslToSpirv("vert", inputVertex, outputVertex)
	end

	local inputFragment = dirName .. "/shaders/triangle.frag.glsl"
	local outputFragment = dirName .. "/shaders/triangle.frag.spv"
	if not exists(outputFragment) then
		print("SPIR-V fragment shader not found, compiling GLSL to SPIR-V...")
		glslToSpirv("frag", inputFragment, outputFragment)
	end
end
