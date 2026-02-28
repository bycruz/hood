---@class hood.Swapchain
---@field present fun(self: hood.Swapchain)
---@field getCurrentTexture fun(self: hood.Swapchain): hood.Texture
local Swapchain = VULKAN and require("hood.swapchain.vk") or require("hood.swapchain.gl") --[[@as hood.Swapchain]]

return Swapchain
