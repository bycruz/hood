---@class hood.Swapchain
---@field present fun(self: hood.Swapchain)
---@field getCurrentTexture fun(self: hood.Swapchain): hood.Texture
local Swapchain = VULKAN and require("hood.vk.swapchain") or require("hood.gl.swapchain") --[[@as hood.Swapchain]]

return Swapchain
