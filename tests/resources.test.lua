local ffi = require("ffi")
local test = require("lde-test")
local hood = require("hood")

local instance = hood.Instance.new({ backend = "vulkan", flags = { "headless" } })
local device = instance:requestAdapter({}):requestDevice()

-- ─── Buffer ───────────────────────────────────────────────────────────────────

test.it("buffer: create with VERTEX usage", function()
	local buf = device:createBuffer({ size = 256, usages = { "VERTEX", "COPY_DST" } })
	test.equal(type(buf), "table")
end)

test.it("buffer: create with INDEX usage", function()
	local buf = device:createBuffer({ size = 64, usages = { "INDEX", "COPY_DST" } })
	test.equal(type(buf), "table")
end)

test.it("buffer: create with UNIFORM usage", function()
	local buf = device:createBuffer({ size = 64, usages = { "UNIFORM", "COPY_DST" } })
	test.equal(type(buf), "table")
end)

test.it("buffer: create with STORAGE usage", function()
	local buf = device:createBuffer({ size = 256, usages = { "STORAGE" } })
	test.equal(type(buf), "table")
end)

test.it("buffer: float round-trip via queue:writeBuffer + getMappedRange", function()
	local N = 8
	local src = ffi.new("float[8]", { 1.5, -2.0, 3.14, 0.0, -1.0, 100.0, 0.001, 42.0 })
	local buf = device:createBuffer({ size = N * ffi.sizeof("float"), usages = { "MAP_READ" } })

	device.queue:writeBuffer(buf, ffi.sizeof(src), src)

	buf:mapAsync()
	local dst = ffi.cast("float*", buf:getMappedRange())
	for i = 0, N - 1 do
		-- Compare via string to avoid direct float == float issues in assertions
		test.equal(tostring(dst[i]), tostring(src[i]))
	end
	buf:unmap()
end)

test.it("buffer: uint32 round-trip via queue:writeBuffer", function()
	local N = 16
	local src = ffi.new("uint32_t[16]")
	for i = 0, N - 1 do src[i] = i * 3 + 7 end

	local buf = device:createBuffer({ size = N * ffi.sizeof("uint32_t"), usages = { "MAP_READ" } })
	device.queue:writeBuffer(buf, ffi.sizeof(src), src)

	buf:mapAsync()
	local dst = ffi.cast("uint32_t*", buf:getMappedRange())
	for i = 0, N - 1 do
		test.equal(tonumber(dst[i]), tonumber(src[i]))
	end
	buf:unmap()
end)

test.it("buffer: large write (>65536 bytes) is chunked correctly", function()
	-- vkCmdUpdateBuffer limit is 65536; writeBuffer must chunk automatically.
	local BYTES = 128 * 1024  -- 131072 bytes = 32768 uint32s
	local N = BYTES / ffi.sizeof("uint32_t")

	local src = ffi.new("uint32_t[?]", N)
	for i = 0, N - 1 do src[i] = i % 65537 end  -- value pattern that wraps differently from chunk boundary

	local buf = device:createBuffer({ size = BYTES, usages = { "MAP_READ" } })
	device.queue:writeBuffer(buf, BYTES, src)

	buf:mapAsync()
	local dst = ffi.cast("uint32_t*", buf:getMappedRange())
	-- Spot-check: first, last, and the boundary around the 65536-byte mark
	test.equal(tonumber(dst[0]),     tonumber(src[0]))
	test.equal(tonumber(dst[N - 1]), tonumber(src[N - 1]))
	-- Exact boundary: byte 65536 = element 16384
	test.equal(tonumber(dst[16383]), tonumber(src[16383]))
	test.equal(tonumber(dst[16384]), tonumber(src[16384]))
	buf:unmap()
end)

test.it("buffer: destroy does not error", function()
	local buf = device:createBuffer({ size = 64, usages = { "VERTEX", "COPY_DST" } })
	buf:destroy()
	test.equal(true, true)
end)

-- ─── Texture ─────────────────────────────────────────────────────────────────

test.it("texture: create 2D rgba8unorm", function()
	local tex = device:createTexture({
		extents = { dim = "2d", width = 8, height = 8 },
		format = "rgba8unorm",
		usages = { "RENDER_ATTACHMENT", "COPY_SRC" },
	})
	test.equal(type(tex), "table")
end)

test.it("texture: create 2D rgba8uint", function()
	local tex = device:createTexture({
		extents = { dim = "2d", width = 4, height = 4 },
		format = "rgba8uint",
		usages = { "STORAGE_BINDING", "COPY_SRC" },
	})
	test.equal(type(tex), "table")
end)

test.it("texture: createView infers format and aspect from texture", function()
	local tex = device:createTexture({
		extents = { dim = "2d", width = 4, height = 4 },
		format = "rgba8unorm",
		usages = { "TEXTURE_BINDING", "COPY_DST" },
	})
	local view = tex:createView({})
	test.equal(type(view), "table")
end)

test.it("texture: writeTexture + copyTextureToBuffer round-trip", function()
	local W, H = 4, 4
	local tex = device:createTexture({
		extents = { dim = "2d", width = W, height = H },
		format = "rgba8unorm",
		usages = { "COPY_DST", "COPY_SRC", "TEXTURE_BINDING" },
	})

	-- Fill with a recognisable per-byte pattern
	local src = ffi.new("uint8_t[64]")
	for i = 0, 63 do src[i] = i end

	device.queue:writeTexture(tex, { width = W, height = H, bytesPerRow = W * 4 }, src)

	local readback = device:createBuffer({ size = W * H * 4, usages = { "MAP_READ" } })

	local encoder = device:createCommandEncoder()
	encoder:copyTextureToBuffer(
		{ texture = tex },
		{ buffer = readback, bytesPerRow = W * 4 },
		{ width = W, height = H }
	)
	local cmd = encoder:finish()
	device.queue:submit(cmd)
	device.queue:waitIdle()

	readback:mapAsync()
	local dst = ffi.cast("uint8_t*", readback:getMappedRange())
	for i = 0, 63 do
		test.equal(tonumber(dst[i]), i)
	end
	readback:unmap()
end)

test.it("texture: destroy does not error", function()
	local tex = device:createTexture({
		extents = { dim = "2d", width = 4, height = 4 },
		format = "rgba8unorm",
		usages = { "RENDER_ATTACHMENT" },
	})
	tex:destroy()
	test.equal(true, true)
end)

-- ─── Sampler ─────────────────────────────────────────────────────────────────

test.it("sampler: nearest filter + clamp-to-edge", function()
	local s = device:createSampler({
		magFilter = "nearest", minFilter = "nearest",
		mipmapFilter = "nearest",
		addressModeU = "clamp-to-edge",
		addressModeV = "clamp-to-edge",
		addressModeW = "clamp-to-edge",
	})
	test.equal(type(s), "table")
end)

test.it("sampler: linear filter + repeat address modes", function()
	local s = device:createSampler({
		magFilter = "linear", minFilter = "linear",
		mipmapFilter = "linear",
		addressModeU = "repeat",
		addressModeV = "repeat",
		addressModeW = "repeat",
	})
	test.equal(type(s), "table")
end)

test.it("sampler: mirrored-repeat address mode", function()
	local s = device:createSampler({
		magFilter = "nearest", minFilter = "nearest",
		mipmapFilter = "nearest",
		addressModeU = "mirrored-repeat",
		addressModeV = "mirrored-repeat",
		addressModeW = "mirrored-repeat",
	})
	test.equal(type(s), "table")
end)

test.it("sampler: compare op for shadow sampling", function()
	local s = device:createSampler({
		magFilter = "linear", minFilter = "linear",
		mipmapFilter = "nearest",
		addressModeU = "clamp-to-edge",
		addressModeV = "clamp-to-edge",
		addressModeW = "clamp-to-edge",
		compareOp = "less",
	})
	test.equal(type(s), "table")
end)

test.it("sampler: destroy does not error", function()
	local s = device:createSampler({
		magFilter = "nearest", minFilter = "nearest",
		mipmapFilter = "nearest",
		addressModeU = "clamp-to-edge",
		addressModeV = "clamp-to-edge",
		addressModeW = "clamp-to-edge",
	})
	s:destroy()
	test.equal(true, true)
end)
