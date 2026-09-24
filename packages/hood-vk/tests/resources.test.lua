local ffi = require("ffi")
local test = require("lde-test")
local core = require("hood-core")
local vk = require("hood-vk")

local instance = vk.new({ backend = "vulkan", flags = { "headless" } })
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

test.it("buffer: write past the end is rejected", function()
	local buf = device:createBuffer({ size = 256, usages = { "VERTEX", "COPY_DST" } })
	local src = ffi.new("char[512]")

	test.errors(function()
		device.queue:writeBuffer(buf, 512, src)
	end, "hood: buffer write of 512 bytes at offset 0 exceeds the 256 byte buffer [VERTEX, COPY_DST]")
end)

test.it("buffer: write that overruns through its offset is rejected", function()
	local buf = device:createBuffer({ size = 256, usages = { "VERTEX", "COPY_DST" } })
	local src = ffi.new("char[256]")

	test.errors(function()
		device.queue:writeBuffer(buf, 128, src, 192)
	end, "hood: buffer write of 128 bytes at offset 192 exceeds the 256 byte buffer [VERTEX, COPY_DST]")
end)

test.it("buffer: write larger than its source reads is rejected", function()
	local buf = device:createBuffer({ size = 256, usages = { "VERTEX", "COPY_DST" } })
	local src = ffi.new("char[64]")

	test.errors(function()
		device.queue:writeBuffer(buf, 128, src)
	end, "hood: buffer write of 128 bytes reads past the end of its 64 byte source")
end)

test.it("buffer: exact-fit write still succeeds", function()
	local N = 64
	local src = ffi.new("uint32_t[?]", N)
	for i = 0, N - 1 do src[i] = i * 2 + 1 end

	local size = N * ffi.sizeof("uint32_t")
	local buf = device:createBuffer({ size = size, usages = { "MAP_READ" } })
	device.queue:writeBuffer(buf, size, src)

	buf:mapAsync()
	local dst = ffi.cast("uint32_t*", buf:getMappedRange())
	test.equal(tonumber(dst[0]), 1)
	test.equal(tonumber(dst[N - 1]), tonumber(src[N - 1]))
	buf:unmap()
end)

test.it("buffer: mapped buffer is writable directly by the CPU", function()
	local N = 32
	local size = N * ffi.sizeof("uint32_t")
	local buf = device:createBuffer({ size = size, usages = { "VERTEX", "COPY_DST" }, mapped = true })

	test.equal(buf.isMapped, true)

	local src = ffi.new("uint32_t[?]", N)
	for i = 0, N - 1 do src[i] = i * 7 + 3 end
	device.queue:writeBuffer(buf, size, src)

	-- No submission and no staging: the bytes are in the buffer's own memory.
	local dst = ffi.cast("uint32_t*", buf:getMappedRange())
	test.equal(tonumber(dst[0]), 3)
	test.equal(tonumber(dst[N - 1]), tonumber(src[N - 1]))
end)

test.it("buffer: mapped write is visible to the GPU", function()
	-- A direct CPU write only matters if a later GPU operation sees it, so copy
	-- it with the GPU into a readback buffer instead of trusting the mapping.
	local N = 16
	local size = N * ffi.sizeof("uint32_t")
	local src = ffi.new("uint32_t[?]", N)
	for i = 0, N - 1 do src[i] = 100 + i end

	local mapped = device:createBuffer({ size = size, usages = { "COPY_SRC", "COPY_DST" }, mapped = true })
	device.queue:writeBuffer(mapped, size, src)

	local readback = device:createBuffer({ size = size, usages = { "MAP_READ", "COPY_DST" } })
	local encoder = device:createCommandEncoder()
	encoder:copyBuffer(mapped, readback, size)
	local cmd = encoder:finish()
	device.queue:submit(cmd)
	device.queue:waitIdle()

	readback:mapAsync()
	local dst = ffi.cast("uint32_t*", readback:getMappedRange())
	test.equal(tonumber(dst[0]), 100)
	test.equal(tonumber(dst[N - 1]), 100 + N - 1)
	readback:unmap()
end)

test.it("buffer: two staged writes in one frame do not clobber each other", function()
	-- Both writes land in the same shared staging buffer, so the second one must
	-- not overwrite the first one's bytes before the GPU has copied them out.
	local N = 8
	local size = N * ffi.sizeof("uint32_t")
	local first = device:createBuffer({ size = size, usages = { "MAP_READ", "COPY_DST" } })
	local second = device:createBuffer({ size = size, usages = { "MAP_READ", "COPY_DST" } })

	local a = ffi.new("uint32_t[?]", N)
	local b = ffi.new("uint32_t[?]", N)
	for i = 0, N - 1 do a[i] = 1000 + i; b[i] = 2000 + i end

	local encoder = device:createCommandEncoder()
	encoder:writeBuffer(first, size, a)
	encoder:writeBuffer(second, size, b)
	local cmd = encoder:finish()
	device.queue:submit(cmd)
	device.queue:waitIdle()

	first:mapAsync()
	local da = ffi.cast("uint32_t*", first:getMappedRange())
	second:mapAsync()
	local db = ffi.cast("uint32_t*", second:getMappedRange())
	test.equal(tonumber(da[0]), 1000)
	test.equal(tonumber(da[N - 1]), 1000 + N - 1)
	test.equal(tonumber(db[0]), 2000)
	test.equal(tonumber(db[N - 1]), 2000 + N - 1)
	first:unmap()
	second:unmap()
end)

test.it("buffer: upload bigger than the staging buffer still round-trips", function()
	-- Larger than the starting staging size, so staging has to grow, and the
	-- bytes written before the growth must not be lost.
	local BYTES = 1024 * 1024
	local N = BYTES / ffi.sizeof("uint32_t")
	local src = ffi.new("uint32_t[?]", N)
	for i = 0, N - 1 do src[i] = i % 65521 end

	local dst = device:createBuffer({ size = BYTES, usages = { "MAP_READ", "COPY_DST" } })
	device.queue:writeBuffer(dst, BYTES, src)

	dst:mapAsync()
	local got = ffi.cast("uint32_t*", dst:getMappedRange())
	test.equal(tonumber(got[0]), 0)
	test.equal(tonumber(got[1]), 1)
	test.equal(tonumber(got[N - 1]), tonumber(src[N - 1]))
	dst:unmap()
end)

test.it("buffer: destroy does not error", function()
	local buf = device:createBuffer({ size = 64, usages = { "VERTEX", "COPY_DST" } })
	buf:destroy()
	test.equal(true, true)
end)

-- ─── BindGroupLayout / BindGroup ─────────────────────────────────────────────

test.it("bind group layout: uniform-buffer binding", function()
	local layout = device:createBindGroupLayout({
		{ binding = 0, visibility = { "VERTEX" }, type = "uniform-buffer" },
	})
	test.equal(type(layout), "table")
	layout:destroy()
end)

test.it("bind group layout: storage-buffer binding", function()
	local layout = device:createBindGroupLayout({
		{ binding = 0, visibility = { "COMPUTE" }, type = "storage-buffer" },
	})
	test.equal(type(layout), "table")
	layout:destroy()
end)

test.it("bind group: uniform-buffer binding round-trip", function()
	local layout = device:createBindGroupLayout({
		{ binding = 0, visibility = { "VERTEX", "FRAGMENT" }, type = "uniform-buffer" },
	})
	local buf = device:createBuffer({ size = 64, usages = { "UNIFORM", "COPY_DST" } })
	local group = device:createBindGroup({
		layout = layout,
		entries = {
			{ binding = 0, visibility = { "VERTEX", "FRAGMENT" }, type = "uniform-buffer", buffer = buf },
		},
	})
	test.equal(type(group), "table")
	group:destroy()
	buf:destroy()
	layout:destroy()
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
