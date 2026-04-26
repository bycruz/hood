local ffi = require("ffi")
local test = require("lde-test")
local hood = require("hood")
local glslc = require("tests.fixtures.glslc")

-- One device shared across all compute tests in this file.
local instance = hood.Instance.new({ backend = "vulkan", flags = { "headless" } })
local device = instance:requestAdapter({}):requestDevice()

-- ─── Helpers ─────────────────────────────────────────────────────────────────

--- Compile and dispatch a compute shader, return mapped uint32 output.
--- The shader MUST write only uint values to binding 0 (storage buffer).
---@param glsl string  GLSL compute source
---@param count number  number of uint32 elements in the output buffer
---@param dispatch table  { x, y, z } workgroup counts
---@return ffi.cdata*, function  (ptr, unmap_fn)
local function runCompute(glsl, count, dispatch)
	local spv = glslc.compile(glsl, "comp")

	local bgl = device:createBindGroupLayout({
		{ type = "buffer", binding = 0, visibility = { "COMPUTE" } },
	})

	local cp = device:createComputePipeline({
		module = { type = "spirv", source = spv },
		layout = bgl,
	})

	local bufSize = count * ffi.sizeof("uint32_t")
	local outBuf = device:createBuffer({ size = bufSize, usages = { "STORAGE", "MAP_READ" } })

	local bg = device:createBindGroup({
		layout = bgl,
		entries = { { type = "buffer", binding = 0, visibility = { "COMPUTE" }, buffer = outBuf } },
	})

	local encoder = device:createCommandEncoder()
	encoder:setComputePipeline(cp)
	encoder:setBindGroup(0, bg)
	encoder:beginComputePass({})
	encoder:dispatchWorkgroups(dispatch.x or 1, dispatch.y or 1, dispatch.z or 1)
	encoder:endComputePass()

	local cmd = encoder:finish()
	device.queue:submit(cmd)
	device.queue:waitIdle()

	outBuf:mapAsync()
	local ptr = ffi.cast("uint32_t*", outBuf:getMappedRange())
	return ptr, function() outBuf:unmap() end
end

-- ─── Tests ───────────────────────────────────────────────────────────────────

test.it("compute: each invocation writes its global index", function()
	-- 64 invocations; data[i] = i
	local ptr, unmap = runCompute([[
#version 430 core
layout(local_size_x = 64) in;
layout(set = 0, binding = 0) buffer Out { uint data[]; };
void main() {
    data[gl_GlobalInvocationID.x] = gl_GlobalInvocationID.x;
}
]], 64, { x = 1 })

	for i = 0, 63 do
		test.equal(tonumber(ptr[i]), i)
	end
	unmap()
end)

test.it("compute: each invocation writes index * 2", function()
	local ptr, unmap = runCompute([[
#version 430 core
layout(local_size_x = 64) in;
layout(set = 0, binding = 0) buffer Out { uint data[]; };
void main() {
    uint i = gl_GlobalInvocationID.x;
    data[i] = i * 2u;
}
]], 64, { x = 1 })

	for i = 0, 63 do
		test.equal(tonumber(ptr[i]), i * 2)
	end
	unmap()
end)

test.it("compute: multiple workgroups cover the full output range", function()
	-- 4 workgroups × 16 threads = 64 invocations; each writes its flat index
	local ptr, unmap = runCompute([[
#version 430 core
layout(local_size_x = 16) in;
layout(set = 0, binding = 0) buffer Out { uint data[]; };
void main() {
    uint i = gl_GlobalInvocationID.x;
    data[i] = i;
}
]], 64, { x = 4 })

	for i = 0, 63 do
		test.equal(tonumber(ptr[i]), i)
	end
	unmap()
end)

test.it("compute: constant fill across all elements", function()
	local MAGIC = 0xDEADBEEF

	local ptr, unmap = runCompute(string.format([[
#version 430 core
layout(local_size_x = 32) in;
layout(set = 0, binding = 0) buffer Out { uint data[]; };
void main() {
    data[gl_GlobalInvocationID.x] = 0x%Xu;
}
]], MAGIC), 32, { x = 1 })

	for i = 0, 31 do
		test.equal(tonumber(ptr[i]), MAGIC)
	end
	unmap()
end)
