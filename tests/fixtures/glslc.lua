local bit = require("bit")

local M = {}

local stageMap = {
	vert = "vertex",
	frag = "fragment",
	comp = "compute",
}

-- DJB2 hash — 31-bit to stay positive, good enough for a cache key
local function djb2(s)
	local h = 5381
	for i = 1, #s do
		h = bit.band(bit.lshift(h, 5) + h + string.byte(s, i), 0x7FFFFFFF)
	end
	return string.format("%07x", h)
end

local cacheDir = (os.getenv("TMPDIR") or "/tmp") .. "/hood-shader-cache"
os.execute("mkdir -p " .. cacheDir)

--- Compile GLSL source to SPIR-V via glslc, caching results by content hash.
---@param source string GLSL source code
---@param stage "vert"|"frag"|"comp" shader stage
---@return string SPIR-V binary
function M.compile(source, stage)
	local glslcStage = assert(stageMap[stage], "Unknown shader stage: " .. tostring(stage))
	local key = djb2(source .. "\0" .. stage)
	local outPath = cacheDir .. "/" .. key .. ".spv"

	local f = io.open(outPath, "rb")
	if f then
		local spv = f:read("*a")
		f:close()
		return spv
	end

	local srcPath = cacheDir .. "/" .. key .. "." .. stage
	local sf = assert(io.open(srcPath, "w"), "cannot write to cache dir: " .. cacheDir)
	sf:write(source)
	sf:close()

	local cmd = string.format('glslc -fshader-stage=%s "%s" -o "%s" 2>&1', glslcStage, srcPath, outPath)
	local pipe = io.popen(cmd)
	local output = pipe:read("*a")
	pipe:close()

	f = io.open(outPath, "rb")
	assert(f, "glslc compilation failed (is glslc installed?):\n" .. output)
	local spv = f:read("*a")
	f:close()
	return spv
end

return M
