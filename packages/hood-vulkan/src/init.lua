local ffi = require("ffi")

ffi.cdef([[#embed "ffi/ffidefs.h"]])

local vkEnums = require("hood-vulkan.ffi.enums")

---@class vk: vk.RawEnums
---@field ApplicationInfo fun(init: vk.ffi.ApplicationInfo?): vk.ffi.ApplicationInfo
---@field InstanceCreateInfo fun(init: vk.ffi.InstanceCreateInfo?): vk.ffi.InstanceCreateInfo
---@field DeviceQueueCreateInfo fun(init: vk.ffi.DeviceQueueCreateInfo?): vk.ffi.DeviceQueueCreateInfo
---@field DeviceCreateInfo fun(init: vk.ffi.DeviceCreateInfo?): vk.ffi.DeviceCreateInfo
---@field BufferCreateInfo fun(init: vk.ffi.BufferCreateInfo?): vk.ffi.BufferCreateInfo
---@field ShaderModuleCreateInfo fun(init: vk.ffi.ShaderModuleCreateInfo?): vk.ffi.ShaderModuleCreateInfo
---@field PipelineLayoutCreateInfo fun(init: vk.ffi.PipelineLayoutCreateInfo?): vk.ffi.PipelineLayoutCreateInfo
---@field PipelineShaderStageCreateInfo fun(init: vk.ffi.PipelineShaderStageCreateInfo?): vk.ffi.PipelineShaderStageCreateInfo
---@field PipelineVertexInputStateCreateInfo fun(init: vk.ffi.PipelineVertexInputStateCreateInfo?): vk.ffi.PipelineVertexInputStateCreateInfo
---@field PipelineInputAssemblyStateCreateInfo fun(init: vk.ffi.PipelineInputAssemblyStateCreateInfo?): vk.ffi.PipelineInputAssemblyStateCreateInfo
---@field PipelineViewportStateCreateInfo fun(init: vk.ffi.PipelineViewportStateCreateInfo?): vk.ffi.PipelineViewportStateCreateInfo
---@field PipelineRasterizationStateCreateInfo fun(init: vk.ffi.PipelineRasterizationStateCreateInfo?): vk.ffi.PipelineRasterizationStateCreateInfo
---@field PipelineMultisampleStateCreateInfo fun(init: vk.ffi.PipelineMultisampleStateCreateInfo?): vk.ffi.PipelineMultisampleStateCreateInfo
---@field PipelineDepthStencilStateCreateInfo fun(init: vk.ffi.PipelineDepthStencilStateCreateInfo?): vk.ffi.PipelineDepthStencilStateCreateInfo
---@field PipelineColorBlendStateCreateInfo fun(init: vk.ffi.PipelineColorBlendStateCreateInfo?): vk.ffi.PipelineColorBlendStateCreateInfo
---@field PipelineDynamicStateCreateInfo fun(init: vk.ffi.PipelineDynamicStateCreateInfo?): vk.ffi.PipelineDynamicStateCreateInfo
---@field GraphicsPipelineCreateInfo fun(init: vk.ffi.GraphicsPipelineCreateInfo?): vk.ffi.GraphicsPipelineCreateInfo
---@field ComputePipelineCreateInfo fun(init: vk.ffi.ComputePipelineCreateInfo?): vk.ffi.ComputePipelineCreateInfo
---@field AttachmentReference fun(init: vk.ffi.AttachmentReference?): vk.ffi.AttachmentReference
---@field AttachmentDescription fun(init: vk.ffi.AttachmentDescription?): vk.ffi.AttachmentDescription
---@field SubpassDescription fun(init: vk.ffi.SubpassDescription?): vk.ffi.SubpassDescription
---@field SubpassDependency fun(init: vk.ffi.SubpassDependency?): vk.ffi.SubpassDependency
---@field VertexInputBindingDescription fun(init: vk.ffi.VertexInputBindingDescription?): vk.ffi.VertexInputBindingDescription
---@field VertexInputAttributeDescription fun(init: vk.ffi.VertexInputAttributeDescription?): vk.ffi.VertexInputAttributeDescription
---@field PipelineColorBlendAttachmentState fun(init: vk.ffi.PipelineColorBlendAttachmentState?): vk.ffi.PipelineColorBlendAttachmentState
---@field PushConstantRange fun(init: vk.ffi.PushConstantRange?): vk.ffi.PushConstantRange
---@field AttachmentReferenceArray fun(count: number): vk.ffi.AttachmentReference[]
---@field AttachmentDescriptionArray fun(count: number): vk.ffi.AttachmentDescription[]
---@field SubpassDescriptionArray fun(count: number): vk.ffi.SubpassDescription[]
---@field SubpassDependencyArray fun(count: number): vk.ffi.SubpassDependency[]
---@field VertexInputBindingDescriptionArray fun(count: number): vk.ffi.VertexInputBindingDescription[]
---@field VertexInputAttributeDescriptionArray fun(count: number): vk.ffi.VertexInputAttributeDescription[]
---@field PipelineColorBlendAttachmentStateArray fun(count: number): vk.ffi.PipelineColorBlendAttachmentState[]
---@field RenderPassCreateInfo fun(init: vk.ffi.RenderPassCreateInfo?): vk.ffi.RenderPassCreateInfo
---@field ImageViewCreateInfo fun(init: vk.ffi.ImageViewCreateInfo?): vk.ffi.ImageViewCreateInfo
---@field FramebufferCreateInfo fun(init: vk.ffi.FramebufferCreateInfo?): vk.ffi.FramebufferCreateInfo
---@field CommandPoolCreateInfo fun(init: vk.ffi.CommandPoolCreateInfo?): vk.ffi.CommandPoolCreateInfo
---@field MemoryRequirements fun(init: vk.ffi.MemoryRequirements?): vk.ffi.MemoryRequirements
---@field MemoryAllocateInfo fun(init: vk.ffi.MemoryAllocateInfo?): vk.ffi.MemoryAllocateInfo
---@field ImageCreateInfo fun(init: vk.ffi.CreateImageInfo?): vk.ffi.CreateImageInfo
---@field SamplerCreateInfo fun(init: vk.ffi.SamplerCreateInfo?): vk.ffi.SamplerCreateInfo
---@field DescriptorSetLayoutCreateInfo fun(init: vk.ffi.DescriptorSetLayoutCreateInfo?): vk.ffi.DescriptorSetLayoutCreateInfo
---@field DescriptorPoolCreateInfo fun(init: vk.ffi.DescriptorPoolCreateInfo?): vk.ffi.DescriptorPoolCreateInfo
---@field DescriptorSetAllocateInfo fun(init: vk.ffi.DescriptorSetAllocateInfo?): vk.ffi.DescriptorSetAllocateInfo
---@field WriteDescriptorSet fun(init: vk.ffi.WriteDescriptorSet?): vk.ffi.WriteDescriptorSet
---@field CommandBufferAllocateInfo fun(init: vk.ffi.CommandBufferAllocateInfo?): vk.ffi.CommandBufferAllocateInfo
---@field CommandBufferBeginInfo fun(init: vk.ffi.CommandBufferBeginInfo?): vk.ffi.CommandBufferBeginInfo
---@field SemaphoreCreateInfo fun(init: vk.ffi.SemaphoreCreateInfo?): vk.ffi.SemaphoreCreateInfo
---@field FenceCreateInfo fun(init: vk.ffi.FenceCreateInfo?): vk.ffi.FenceCreateInfo
---@field SwapchainCreateInfoKHR fun(init: vk.ffi.SwapchainCreateInfoKHR?): vk.ffi.SwapchainCreateInfoKHR
---@field XlibSurfaceCreateInfoKHR fun(init: vk.ffi.XlibSurfaceCreateInfoKHR?): vk.ffi.XlibSurfaceCreateInfoKHR
---@field Win32SurfaceCreateInfoKHR fun(init: vk.ffi.Win32SurfaceCreateInfoKHR?): vk.ffi.Win32SurfaceCreateInfoKHR
---@field PresentInfoKHR fun(init: vk.ffi.PresentInfoKHR?): vk.ffi.PresentInfoKHR
---@field RenderPassBeginInfo fun(init: vk.ffi.RenderPassBeginInfo?): vk.ffi.RenderPassBeginInfo
---@field PhysicalDeviceProperties fun(init: vk.ffi.PhysicalDeviceProperties?): vk.ffi.PhysicalDeviceProperties
---@field PhysicalDeviceMemoryProperties fun(init: vk.ffi.PhysicalDeviceMemoryProperties?): vk.ffi.PhysicalDeviceMemoryProperties
---@field SurfaceCapabilitiesKHR fun(init: vk.ffi.SurfaceCapabilitiesKHR?): vk.ffi.SurfaceCapabilitiesKHR
---@field SubmitInfo fun(init: vk.ffi.SubmitInfo?): vk.ffi.SubmitInfo
---@field DeviceQueueCreateInfoArray fun(count: number): vk.ffi.DeviceQueueCreateInfo[]
---@field PipelineShaderStageCreateInfoArray fun(count: number): vk.ffi.PipelineShaderStageCreateInfo[]
---@field GraphicsPipelineCreateInfoArray fun(count: number): vk.ffi.GraphicsPipelineCreateInfo[]
---@field WriteDescriptorSetArray fun(count: number): vk.ffi.WriteDescriptorSet[]
---@field SubmitInfoArray fun(count: number): vk.ffi.SubmitInfo[]
local vk = {}
for k, v in pairs(vkEnums) do
	vk[k] = v
end

-- Type constructors (typed as fields above)
do
	---@param ffiName string
	---@param structureTypeName string
	local function defStruct(ffiName, structureTypeName)
		local cons = ffi.typeof("Vk" .. ffiName)
			or error("Failed to find FFI type for Vk" .. ffiName)

		local structType = vk.StructureType[structureTypeName]
			or error("Failed to find structure type for " .. structureTypeName)

		vk[ffiName] = function(init)
			local info = cons(init)
			info.sType = structType
			return info
		end

		local arrayCons = ffi.typeof("Vk" .. ffiName .. "[?]")
		vk[ffiName .. "Array"] = function(count)
			local array = arrayCons(count)

			for i = 0, count - 1 do
				array[i].sType = structType
			end

			return array
		end
	end

	local function defType(ffiName)
		local cons = ffi.typeof("Vk" .. ffiName)
			or error("Failed to find FFI type for Vk" .. ffiName)

		local arrayCons = ffi.typeof("Vk" .. ffiName .. "[?]")

		vk[ffiName] = cons
		vk[ffiName .. "Array"] = arrayCons
	end

	defStruct("ApplicationInfo", "APPLICATION_INFO")
	defStruct("InstanceCreateInfo", "INSTANCE_CREATE_INFO")
	defStruct("DeviceQueueCreateInfo", "DEVICE_QUEUE_CREATE_INFO")
	defStruct("DeviceCreateInfo", "DEVICE_CREATE_INFO")
	defStruct("BufferCreateInfo", "BUFFER_CREATE_INFO")
	defStruct("ShaderModuleCreateInfo", "SHADER_MODULE_CREATE_INFO")
	defStruct("PipelineLayoutCreateInfo", "PIPELINE_LAYOUT_CREATE_INFO")
	defStruct("PipelineShaderStageCreateInfo", "PIPELINE_SHADER_STAGE_CREATE_INFO")
	defStruct("PipelineVertexInputStateCreateInfo", "PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO")
	defStruct("PipelineInputAssemblyStateCreateInfo", "PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO")
	defStruct("PipelineViewportStateCreateInfo", "PIPELINE_VIEWPORT_STATE_CREATE_INFO")
	defStruct("PipelineRasterizationStateCreateInfo", "PIPELINE_RASTERIZATION_STATE_CREATE_INFO")
	defStruct("PipelineMultisampleStateCreateInfo", "PIPELINE_MULTISAMPLE_STATE_CREATE_INFO")
	defStruct("PipelineDepthStencilStateCreateInfo", "PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO")
	defStruct("PipelineColorBlendStateCreateInfo", "PIPELINE_COLOR_BLEND_STATE_CREATE_INFO")
	defStruct("PipelineDynamicStateCreateInfo", "PIPELINE_DYNAMIC_STATE_CREATE_INFO")
	defStruct("GraphicsPipelineCreateInfo", "GRAPHICS_PIPELINE_CREATE_INFO")
	defStruct("ComputePipelineCreateInfo", "COMPUTE_PIPELINE_CREATE_INFO")
	defType("AttachmentReference")
	defType("AttachmentDescription")
	defType("SubpassDescription")
	defType("SubpassDependency")
	defType("VertexInputBindingDescription")
	defType("VertexInputAttributeDescription")
	defType("PipelineColorBlendAttachmentState")
	defType("PushConstantRange")
	defStruct("RenderPassCreateInfo", "RENDER_PASS_CREATE_INFO")
	defStruct("ImageViewCreateInfo", "IMAGE_VIEW_CREATE_INFO")
	defStruct("FramebufferCreateInfo", "FRAMEBUFFER_CREATE_INFO")
	defStruct("CommandPoolCreateInfo", "COMMAND_POOL_CREATE_INFO")
	defType("MemoryRequirements")
	defStruct("MemoryAllocateInfo", "MEMORY_ALLOCATE_INFO")
	defStruct("ImageCreateInfo", "IMAGE_CREATE_INFO")
	defStruct("SamplerCreateInfo", "SAMPLER_CREATE_INFO")
	defStruct("DescriptorSetLayoutCreateInfo", "DESCRIPTOR_SET_LAYOUT_CREATE_INFO")
	defStruct("DescriptorPoolCreateInfo", "DESCRIPTOR_POOL_CREATE_INFO")
	defStruct("DescriptorSetAllocateInfo", "DESCRIPTOR_SET_ALLOCATE_INFO")
	defStruct("WriteDescriptorSet", "WRITE_DESCRIPTOR_SET")
	defStruct("CommandBufferAllocateInfo", "COMMAND_BUFFER_ALLOCATE_INFO")
	defStruct("CommandBufferBeginInfo", "COMMAND_BUFFER_BEGIN_INFO")
	defStruct("SemaphoreCreateInfo", "SEMAPHORE_CREATE_INFO")
	defStruct("FenceCreateInfo", "FENCE_CREATE_INFO")
	defStruct("SwapchainCreateInfoKHR", "SWAPCHAIN_CREATE_INFO_KHR")
	defStruct("XlibSurfaceCreateInfoKHR", "XLIB_SURFACE_CREATE_INFO_KHR")
	defStruct("Win32SurfaceCreateInfoKHR", "WIN32_SURFACE_CREATE_INFO_KHR")
	defStruct("PresentInfoKHR", "PRESENT_INFO_KHR")
	defStruct("RenderPassBeginInfo", "RENDER_PASS_BEGIN_INFO")
	defType("PhysicalDeviceProperties")
	defType("PhysicalDeviceMemoryProperties")
	defType("SurfaceCapabilitiesKHR")
	defStruct("SubmitInfo", "SUBMIT_INFO")
end

-- Constants
do
	vk.NULL = 0
	vk.SUBPASS_EXTERNAL = 0xFFFFFFFF
end

local VKInstance = require("hood-vulkan.instance")(vk)

do
	local C = ffi.load("vulkan.so.1")

	---@class vk.ApplicationInfo
	---@field name string
	---@field version number
	---@field engineName string
	---@field engineVersion number
	---@field apiVersion vk.ApiVersion

	---@class vk.InstanceCreateInfo
	---@field applicationInfo vk.ApplicationInfo
	---@field enabledLayerNames string[]
	---@field enabledExtensionNames vk.InstanceExtensionName[]

	---@param info vk.InstanceCreateInfo
	---@param allocator ffi.cdata*?
	---@return vk.Instance
	function vk.createInstance(info, allocator)
		local instance = ffi.new("VkInstance[1]")

		local layerCount = info.enabledLayerNames and #info.enabledLayerNames or 0
		local layerNames = ffi.new("const char*[?]", math.max(layerCount, 1))
		for i = 1, layerCount do
			layerNames[i - 1] = ffi.cast("const char*", info.enabledLayerNames[i])
		end

		local extCount = info.enabledExtensionNames and #info.enabledExtensionNames or 0
		local extNames = ffi.new("const char*[?]", math.max(extCount, 1))
		for i = 1, extCount do
			extNames[i - 1] = ffi.cast("const char*", info.enabledExtensionNames[i])
		end

		local appInfo = vk.ApplicationInfo()
		appInfo.pApplicationName = info.applicationInfo.name
		appInfo.applicationVersion = info.applicationInfo.version
		appInfo.pEngineName = info.applicationInfo.engineName
		appInfo.engineVersion = info.applicationInfo.engineVersion
		appInfo.apiVersion = info.applicationInfo.apiVersion

		local createInfo = vk.InstanceCreateInfo()
		createInfo.flags = 0
		createInfo.pApplicationInfo = appInfo
		createInfo.enabledLayerCount = layerCount
		createInfo.ppEnabledLayerNames = layerNames
		createInfo.enabledExtensionCount = extCount
		createInfo.ppEnabledExtensionNames = extNames

		local result = C.vkCreateInstance(createInfo, allocator, instance)
		if result ~= 0 then
			error("Failed to create Vulkan instance, error code: " .. tostring(result))
		end

		return VKInstance.new(instance[0])
	end

	---@param physicalDevice vk.ffi.PhysicalDevice
	function vk.getPhysicalDeviceProperties(physicalDevice)
		local properties = vk.PhysicalDeviceProperties()
		C.vkGetPhysicalDeviceProperties(physicalDevice, properties)
		return properties --[[@as vk.ffi.PhysicalDeviceProperties]]
	end

	---@param physicalDevice vk.ffi.PhysicalDevice
	---@return vk.ffi.PhysicalDeviceMemoryProperties
	function vk.getPhysicalDeviceMemoryProperties(physicalDevice)
		local memProperties = vk.PhysicalDeviceMemoryProperties()
		C.vkGetPhysicalDeviceMemoryProperties(physicalDevice, memProperties)
		return memProperties --[[@as vk.ffi.PhysicalDeviceMemoryProperties]]
	end

	---@param physicalDevice vk.ffi.PhysicalDevice
	---@return vk.ffi.QueueFamilyProperties[]
	function vk.getPhysicalDeviceQueueFamilyProperties(physicalDevice)
		local count = ffi.new("uint32_t[1]")
		C.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, count, nil)

		local properties = ffi.new("VkQueueFamilyProperties[?]", count[0])
		C.vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, count, properties)

		local propertyTable = {}
		for i = 0, count[0] - 1 do
			propertyTable[i + 1] = properties[i]
		end
		return propertyTable
	end

	---@param physicalDevice vk.ffi.PhysicalDevice
	---@param surface vk.ffi.SurfaceKHR
	---@return vk.ffi.SurfaceCapabilitiesKHR
	function vk.getPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface)
		local capabilities = vk.SurfaceCapabilitiesKHR()
		local result = C.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, capabilities)
		if result ~= 0 then
			error("Failed to get physical device surface capabilities, error code: " .. tostring(result))
		end
		return capabilities --[[@as vk.ffi.SurfaceCapabilitiesKHR]]
	end

	---@param physicalDevice vk.ffi.PhysicalDevice
	---@param surface vk.ffi.SurfaceKHR
	---@return vk.ffi.SurfaceFormatKHR[]
	function vk.getPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface)
		local count = ffi.new("uint32_t[1]")
		local result = C.vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, count, nil)
		if result ~= 0 then
			error("Failed to get surface format count, error code: " .. tostring(result))
		end

		local formats = ffi.new("VkSurfaceFormatKHR[?]", count[0])
		result = C.vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, count, formats)
		if result ~= 0 then
			error("Failed to get surface formats, error code: " .. tostring(result))
		end

		local formatTable = {}
		for i = 0, count[0] - 1 do
			formatTable[i + 1] = formats[i]
		end
		return formatTable
	end

	---@param physicalDevice vk.ffi.PhysicalDevice
	---@param surface vk.ffi.SurfaceKHR
	---@return vk.PresentModeKHR[]
	function vk.getPhysicalDeviceSurfacePresentModesKHR(physicalDevice, surface)
		local count = ffi.new("uint32_t[1]")
		local result = C.vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, surface, count, nil)
		if result ~= 0 then
			error("Failed to get present mode count, error code: " .. tostring(result))
		end

		local modes = ffi.new("VkPresentModeKHR[?]", count[0])
		result = C.vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, surface, count, modes)
		if result ~= 0 then
			error("Failed to get present modes, error code: " .. tostring(result))
		end

		local modeTable = {}
		for i = 0, count[0] - 1 do
			modeTable[i + 1] = modes[i]
		end
		return modeTable
	end

	---@type fun(instance: vk.ffi.Instance, name: string): ffi.cdata*
	vk.getInstanceProcAddr = C.vkGetInstanceProcAddr

	---@type fun(device: vk.ffi.Device, name: string): ffi.cdata*
	vk.getDeviceProcAddr = C.vkGetDeviceProcAddr
end

return vk
