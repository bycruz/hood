local ffi = require("ffi")
local test = require("lde-test")
local core = require("hood-core")
local vk = require("hood-vk")
local vkConversions = require("hood-vk.convert")

local instance = vk.new({ backend = "vulkan", flags = { "headless" } })
local device = instance:requestAdapter({}):requestDevice()

-- ─── Buffer ───────────────────────────────────────────────────────────────────

test.it("buffer: every usage flag creates", function()
	for _, usage in ipairs({ "VERTEX", "INDEX", "UNIFORM", "STORAGE", "COPY_DST", "COPY_SRC",
		"INDIRECT", "MAP_READ" }) do
		local buf = device:createBuffer({ size = 256, usages = { usage } })
		test.equal(type(buf), "table", usage)
		buf:destroy()
	end
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

test.it("buffer: a write that does not fit is rejected", function()
	local buf = device:createBuffer({ size = 256, usages = { "VERTEX", "COPY_DST" } })

	test.errors(function()
		device.queue:writeBuffer(buf, 512, ffi.new("char[512]"))
	end, "hood: buffer write of 512 bytes at offset 0 exceeds the 256 byte buffer [VERTEX, COPY_DST]")

	test.errors(function()
		device.queue:writeBuffer(buf, 128, ffi.new("char[256]"), 192)
	end, "hood: buffer write of 128 bytes at offset 192 exceeds the 256 byte buffer [VERTEX, COPY_DST]")

	test.errors(function()
		device.queue:writeBuffer(buf, 128, ffi.new("char[64]"))
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

-- Host visible memory is a window on most machines -- a resizable BAR is what a large one is --
-- and it can be full of what the window manager and every other program are holding, so a buffer
-- of a size the window has no room for is asked of the memory beside it rather than failing.
test.it("buffer: a mapped buffer larger than the window host memory is allocated", function()
	local megabytes = 64
	local buffer = device:createBuffer({
		size = megabytes * 1024 * 1024,
		usages = { "COPY_SRC" },
		mapped = true,
	})

	test.truthy(buffer.isMapped, "a mapped buffer is one the CPU can write into")

	local pointer = buffer:mappedPointer()
	pointer[0] = 7
	pointer[megabytes * 1024 * 1024 - 1] = 9

	test.equal(tonumber(pointer[0]), 7, "and the whole of it is there to write into")
	test.equal(tonumber(pointer[megabytes * 1024 * 1024 - 1]), 9)

	buffer:destroy()
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

-- A layout is not the first group's to free: several groups are made with one, and a
-- destroy that freed it left every other group holding nothing.
test.it("bind group: a layout outlives the groups made with it", function()
	local layout = device:createBindGroupLayout({
		{ binding = 0, visibility = { "VERTEX", "FRAGMENT" }, type = "uniform-buffer" },
	})
	local buf = device:createBuffer({ size = 64, usages = { "UNIFORM", "COPY_DST" } })

	local first = device:createBindGroup({
		layout = layout,
		entries = { { binding = 0, visibility = { "VERTEX", "FRAGMENT" }, type = "uniform-buffer", buffer = buf } },
	})
	local second = device:createBindGroup({
		layout = layout,
		entries = { { binding = 0, visibility = { "VERTEX", "FRAGMENT" }, type = "uniform-buffer", buffer = buf } },
	})

	first:destroy()

	-- Still usable: the second group is made with the layout the first was, and a group
	-- made after both are freed is made with it as well.
	local third = device:createBindGroup({
		layout = layout,
		entries = { { binding = 0, visibility = { "VERTEX", "FRAGMENT" }, type = "uniform-buffer", buffer = buf } },
	})

	test.equal(type(third), "table")

	second:destroy()
	third:destroy()
	buf:destroy()
	layout:destroy()
end)

-- What a pool holds is fixed when it is made, so groups that are dropped have to give their
-- sets back: a screen with a bind group per picture makes hundreds of them.
test.it("bind group: sets are reused once their groups are dropped", function()
	local layout = device:createBindGroupLayout({
		{ binding = 0, visibility = { "VERTEX", "FRAGMENT" }, type = "uniform-buffer" },
	})
	local buf = device:createBuffer({ size = 64, usages = { "UNIFORM", "COPY_DST" } })

	for _ = 1, 2000 do
		local group = device:createBindGroup({
			layout = layout,
			entries = { { binding = 0, visibility = { "VERTEX", "FRAGMENT" }, type = "uniform-buffer", buffer = buf } },
		})

		group:destroy()
	end

	buf:destroy()
	layout:destroy()
end)

-- A screen with a bind group per picture is hundreds of them held at once. How many a pool
-- holds is the driver's to enforce -- this one hands out more than its own maxSets says it has,
-- and a driver that does refuse gets another pool made for it -- so what is checked here is that
-- the sets are handed out and given back without anything falling over.
test.it("bind group: hundreds of groups held at once", function()
	local layout = device:createBindGroupLayout({
		{ binding = 0, visibility = { "VERTEX", "FRAGMENT" }, type = "uniform-buffer" },
	})
	local buf = device:createBuffer({ size = 64, usages = { "UNIFORM", "COPY_DST" } })
	local groups = {}

	for index = 1, 900 do
		groups[index] = device:createBindGroup({
			layout = layout,
			entries = { { binding = 0, visibility = { "VERTEX", "FRAGMENT" }, type = "uniform-buffer", buffer = buf } },
		})
	end

	test.equal(#groups, 900, "nine hundred groups are held at once")

	for _, group in ipairs(groups) do
		group:destroy()
	end

	buf:destroy()
	layout:destroy()
end)

-- ─── Command buffer ──────────────────────────────────────────────────────────

-- A command buffer is handed back to the device's pool when it is done with, which is a call on
-- the device: the pool is the device's, and the buffer does not carry which one it came from.
test.it("command buffer: destroy hands it back to the device's pool", function()
	local encoder = device:createCommandEncoder()
	local buffer = encoder:finish()

	buffer:destroy()

	test.equal(true, true)
end)

-- ─── Texture ─────────────────────────────────────────────────────────────────

test.it("texture: colour formats create", function()
	for _, format in ipairs({ "rgba8unorm", "rgba8uint", "bgra8unorm", "bgra8unorm-srgb" }) do
		local tex = device:createTexture({
			extents = { dim = "2d", width = 4, height = 4 },
			format = format,
			usages = { "COPY_SRC" },
		})
		test.equal(type(tex), "table", format)
		tex:destroy()
	end
end)

test.it("texture: depth formats create", function()
	for _, format in ipairs({ "depth16unorm", "depth24plus", "depth32float" }) do
		local tex = device:createTexture({
			extents = { dim = "2d", width = 4, height = 4 },
			format = format,
			usages = { "RENDER_ATTACHMENT" },
		})
		test.equal(type(tex), "table", format)
		tex:destroy()
	end
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

test.it("sampler: filter and address modes are accepted", function()
	for _, filter in ipairs({ "nearest", "linear" }) do
		for _, address in ipairs({ "clamp-to-edge", "repeat", "mirrored-repeat" }) do
			local s = device:createSampler({
				magFilter = filter, minFilter = filter, mipmapFilter = filter,
				addressModeU = address, addressModeV = address, addressModeW = address,
			})
			test.equal(type(s), "table", filter .. " + " .. address)
			s:destroy()
		end
	end
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

-- ─── Surface format choice ────────────────────────────────────────────────────
--- Which format a swapchain is made in decides how a shader's output is stored: write linear
--- values into an `-srgb` format and the hardware encodes them again, which is the difference
--- between the same app looking right and looking washed out. Drivers disagree about which
--- format to list first, so the choice cannot be left to the driver.

local ffiSurface = function(fmt)
	return { format = fmt, colorSpace = 0 }
end

local vkEnums = require("vkapi.ffi.enums")

test.it("surface format: no request takes the driver's first choice", function()
	local formats = { ffiSurface(vkEnums.Format.B8G8R8A8_UNORM),
		ffiSurface(vkEnums.Format.B8G8R8A8_SRGB) }

	local picked = vkConversions.pickSurfaceFormat(formats, nil)
	test.equal(picked.format, vkEnums.Format.B8G8R8A8_UNORM)
end)

test.it("surface format: a request is honoured wherever it sits in the list", function()
	-- The same set of formats in either order must answer the same thing when asked.
	local linear = vkEnums.Format.B8G8R8A8_UNORM
	local srgb = vkEnums.Format.B8G8R8A8_SRGB

	local first = vkConversions.pickSurfaceFormat({ ffiSurface(linear), ffiSurface(srgb) }, "bgra8unorm-srgb")
	local second = vkConversions.pickSurfaceFormat({ ffiSurface(srgb), ffiSurface(linear) }, "bgra8unorm-srgb")

	test.equal(first.format, srgb)
	test.equal(second.format, srgb)
end)

test.it("surface format: one the surface does not support is refused", function()
	local ok, err = pcall(vkConversions.pickSurfaceFormat,
		{ ffiSurface(vkEnums.Format.B8G8R8A8_UNORM) }, "bgra8unorm-srgb")

	test.equal(ok, false)
	test.truthy(tostring(err):match("Requested surface format not supported"))
end)

test.it("surface format: every format hood names converts and inverts back", function()
	local names = { "rgba8unorm", "rgba8unorm-srgb", "rgba8uint", "bgra8unorm",
		"bgra8unorm-srgb", "depth16unorm", "depth24plus", "depth32float" }

	for _, name in ipairs(names) do
		local vkFormat = vkConversions.textureFormat[name]
		test.truthy(vkFormat, name .. " converts")
		test.equal(vkConversions.from.textureFormat[vkFormat], name,
			name .. " inverts back to itself")
	end
end)
