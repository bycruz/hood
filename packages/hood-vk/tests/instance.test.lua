local test = require("lde-test")
local vk = require("vkapi")
local hoodvk = require("hood-vk")

local T = vk.PhysicalDeviceType

local preferences = { "default", "low-power", "high-performance" }
local gpuTypes = { T.INTEGRATED_GPU, T.DISCRETE_GPU, T.VIRTUAL_GPU, T.OTHER }

---@param deviceType vk.PhysicalDeviceType
---@param preference string
local function rank(deviceType, preference)
	if preference == "default" then preference = nil end
	return hoodvk.rankDeviceType(deviceType, preference)
end

test.it("adapter ranking: CPU never outranks a GPU, for every preference", function()
	for _, preference in ipairs(preferences) do
		local cpu = rank(T.CPU, preference)
		for _, gpuType in ipairs(gpuTypes) do
			test.greater(rank(gpuType, preference), cpu,
				"preference=" .. preference .. " gpuType=" .. tostring(gpuType))
		end
	end
end)

test.it("adapter ranking: default prefers integrated over discrete", function()
	test.greater(rank(T.INTEGRATED_GPU, "default"), rank(T.DISCRETE_GPU, "default"))
end)

test.it("adapter ranking: low-power prefers integrated over discrete", function()
	test.greater(rank(T.INTEGRATED_GPU, "low-power"), rank(T.DISCRETE_GPU, "low-power"))
end)

test.it("adapter ranking: high-performance prefers discrete over integrated", function()
	test.greater(rank(T.DISCRETE_GPU, "high-performance"), rank(T.INTEGRATED_GPU, "high-performance"))
end)

test.it("adapter ranking: virtual then other, both above CPU", function()
	for _, preference in ipairs(preferences) do
		local other = rank(T.OTHER, preference)
		test.greater(rank(T.VIRTUAL_GPU, preference), other)
		test.greater(other, rank(T.CPU, preference))
	end
end)
