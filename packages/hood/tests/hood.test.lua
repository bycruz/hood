-- The facade: what an app depends on when it only wants hood's API, and the one thing it
-- does with it, which is hand an instance to whichever backend the app asked for.
local test = require("lde-test")
local hood = require("hood")

test.it("hood: the enums and the vertex layout come from the core, and an instance is here", function()
	test.truthy(hood.Instance, "an instance can be made")
	test.truthy(hood.VertexLayout, "a pipeline can be described")
	test.equal(hood.ColorWrites.All, 0b1111, "and the enums are the core's")
end)

test.it("hood: a backend it does not have is refused, and says so", function()
	local ok, err = pcall(function()
		return hood.Instance.new({ backend = "metal" })
	end)

	test.falsy(ok, "a backend that is not vulkan or opengl is not one")
	test.truthy(tostring(err):match("No supported backends"), "and the descriptor is what named it")
end)

-- The two backends are packages of their own and this one installs neither: an app says
-- which backend it runs on. So this holds on an install of hood alone, which is what the
-- suite here has.
test.it("hood: a backend that was not installed says which feature to name", function()
	local hasVk = pcall(require, "hood-vk")
	local hasGl = pcall(require, "hood-gl")

	if hasVk or hasGl then
		return
	end

	local ok, err = pcall(function()
		return hood.Instance.new({ backend = "vulkan" })
	end)

	test.falsy(ok)
	test.truthy(tostring(err):match("features"), "the error names what to put in lde.json")
end)
