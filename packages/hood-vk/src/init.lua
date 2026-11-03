---@class hood-vk.ReusablePass
---@field colorAttachments { op: { type: "clear", color: { r: number, g: number, b: number, a: number } }, texture: hood.TextureView? }[]

---@class hood-vk.VkExtras
---@field MemoryBarrierArray fun(n: number): vk.ffi.MemoryBarrier[]
---@field REMAINING_MIP_LEVELS integer
---@field REMAINING_ARRAY_LAYERS integer
---@field WHOLE_SIZE integer
---@field SUBPASS_EXTERNAL integer

-- The vulkan backend, as hood asks for it: an instance, made from a descriptor. What is
-- behind that is everything a vulkan program needs, and nothing a program on the other
-- backend would be carrying around.
return require("hood-vk.instance")
