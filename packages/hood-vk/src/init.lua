-- The vulkan backend, as hood asks for it: an instance, made from a descriptor. What is
-- behind that is everything a vulkan program needs, and nothing a program on the other
-- backend would be carrying around.
return require("hood-vk.instance")
