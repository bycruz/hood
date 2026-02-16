typedef unsigned long long uint64_t;
typedef unsigned int uint32_t;

typedef long long int64_t;
typedef int int32_t;

typedef uint64_t size_t;
typedef unsigned char uint8_t;

typedef void *VkInstance;
typedef void *VkDevice;
typedef void *VkPipelineCache;
typedef int32_t VkResult;
typedef int32_t VkStructureType;
typedef uint32_t VkFlags;
typedef void *VkPhysicalDevice;
typedef uint32_t VkBool32;
typedef VkFlags VkSampleCountFlags;
typedef uint64_t VkDeviceSize;
typedef uint32_t VkPhysicalDeviceType;
typedef uint64_t VkBuffer;
typedef VkFlags VkBufferCreateFlags;
typedef VkFlags VkBufferUsageFlags;
typedef uint32_t VkSharingMode;
typedef void VkAllocationCallbacks;
typedef VkFlags VkShaderModuleCreateFlags;
typedef uint64_t VkShaderModule;
typedef uint64_t VkPipelineLayout;
typedef uint64_t VkPipeline;
typedef uint64_t VkRenderPass;
typedef uint64_t VkFramebuffer;
typedef uint64_t VkCommandPool;
typedef void *VkCommandBuffer;
typedef void *VkQueue;
typedef uint64_t VkSemaphore;
typedef uint64_t VkFence;
typedef uint64_t VkImage;
typedef uint64_t VkDeviceMemory;
typedef uint64_t VkSampler;
typedef uint64_t VkImageView;
typedef uint64_t VkDescriptorSetLayout;
typedef uint64_t VkDescriptorPool;
typedef uint64_t VkDescriptorSet;
typedef VkFlags VkMemoryPropertyFlags;
typedef VkFlags VkMemoryHeapFlags;
typedef VkFlags VkDescriptorSetLayoutCreateFlags;
typedef VkFlags VkDescriptorPoolCreateFlags;
typedef int32_t VkDescriptorType;
typedef VkFlags VkShaderStageFlags;
typedef int32_t VkFormat;
typedef int32_t VkColorSpaceKHR;
typedef int32_t VkPresentModeKHR;
typedef int32_t VkSurfaceTransformFlagBitsKHR;
typedef int32_t VkCompositeAlphaFlagBitsKHR;
typedef VkFlags VkImageUsageFlags;
typedef VkFlags VkSwapchainCreateFlagsKHR;
typedef VkFlags VkSurfaceTransformFlagsKHR;
typedef VkFlags VkCompositeAlphaFlagsKHR;
typedef VkFlags VkPipelineLayoutCreateFlags;
typedef VkFlags VkPipelineCreateFlags;
typedef VkFlags VkRenderPassCreateFlags;
typedef VkFlags VkFramebufferCreateFlags;
typedef VkFlags VkCommandPoolCreateFlags;
typedef VkFlags VkCommandBufferUsageFlags;
typedef int32_t VkPipelineBindPoint;
typedef int32_t VkSubpassContents;
typedef int32_t VkCommandBufferLevel;
typedef VkFlags VkImageCreateFlags;
typedef int32_t VkImageType;
typedef int32_t VkImageTiling;
typedef int32_t VkImageLayout;
typedef VkFlags VkImageAspectFlags;
typedef VkFlags VkQueueFlags;
typedef int32_t VkImageViewType;
typedef int32_t VkComponentSwizzle;

typedef struct {
  uint32_t width;
  uint32_t height;
  uint32_t depth;
} VkExtent3D;

typedef struct {
  VkQueueFlags queueFlags;
  uint32_t queueCount;
  uint32_t timestampValidBits;
  VkExtent3D minImageTransferGranularity;
} VkQueueFamilyProperties;

typedef struct {
  int32_t x;
  int32_t y;
  int32_t z;
} VkOffset3D;

typedef struct {
  int32_t x;
  int32_t y;
} VkOffset2D;

typedef struct {
  uint32_t width;
  uint32_t height;
} VkExtent2D;

typedef struct {
  VkOffset2D offset;
  VkExtent2D extent;
} VkRect2D;

typedef uint64_t VkSwapchainKHR;
typedef uint64_t VkSurfaceKHR;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  const char *pApplicationName;
  uint32_t applicationVersion;
  const char *pEngineName;
  uint32_t engineVersion;
  uint32_t apiVersion;
} VkApplicationInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags flags;
  const VkApplicationInfo *pApplicationInfo;
  uint32_t enabledLayerCount;
  const char *const *ppEnabledLayerNames;
  uint32_t enabledExtensionCount;
  const char *const *ppEnabledExtensionNames;
} VkInstanceCreateInfo;

void *vkGetInstanceProcAddr(VkInstance instance, const char *pName);
void *vkGetDeviceProcAddr(VkDevice device, const char *pName);

VkResult vkCreateInstance(const VkInstanceCreateInfo *pCreateInfo,
                          const VkAllocationCallbacks *pAllocator,
                          VkInstance *pInstance);

VkResult vkEnumeratePhysicalDevices(VkInstance instance,
                                    uint32_t *pPhysicalDeviceCount,
                                    VkPhysicalDevice *pPhysicalDevices);

typedef struct {
  VkBool32 robustBufferAccess;
  VkBool32 fullDrawIndexUint32;
  VkBool32 imageCubeArray;
  VkBool32 independentBlend;
  VkBool32 geometryShader;
  VkBool32 tessellationShader;
  VkBool32 sampleRateShading;
  VkBool32 dualSrcBlend;
  VkBool32 logicOp;
  VkBool32 multiDrawIndirect;
  VkBool32 drawIndirectFirstInstance;
  VkBool32 depthClamp;
  VkBool32 depthBiasClamp;
  VkBool32 fillModeNonSolid;
  VkBool32 depthBounds;
  VkBool32 wideLines;
  VkBool32 largePoints;
  VkBool32 alphaToOne;
  VkBool32 multiViewport;
  VkBool32 samplerAnisotropy;
  VkBool32 textureCompressionETC2;
  VkBool32 textureCompressionASTC_LDR;
  VkBool32 textureCompressionBC;
  VkBool32 occlusionQueryPrecise;
  VkBool32 pipelineStatisticsQuery;
  VkBool32 vertexPipelineStoresAndAtomics;
  VkBool32 fragmentStoresAndAtomics;
  VkBool32 shaderTessellationAndGeometryPointSize;
  VkBool32 shaderImageGatherExtended;
  VkBool32 shaderStorageImageExtendedFormats;
  VkBool32 shaderStorageImageMultisample;
  VkBool32 shaderStorageImageReadWithoutFormat;
  VkBool32 shaderStorageImageWriteWithoutFormat;
  VkBool32 shaderUniformBufferArrayDynamicIndexing;
  VkBool32 shaderSampledImageArrayDynamicIndexing;
  VkBool32 shaderStorageBufferArrayDynamicIndexing;
  VkBool32 shaderStorageImageArrayDynamicIndexing;
  VkBool32 shaderClipDistance;
  VkBool32 shaderCullDistance;
  VkBool32 shaderFloat64;
  VkBool32 shaderInt64;
  VkBool32 shaderInt16;
  VkBool32 shaderResourceResidency;
  VkBool32 shaderResourceMinLod;
  VkBool32 sparseBinding;
  VkBool32 sparseResidencyBuffer;
  VkBool32 sparseResidencyImage2D;
  VkBool32 sparseResidencyImage3D;
  VkBool32 sparseResidency2Samples;
  VkBool32 sparseResidency4Samples;
  VkBool32 sparseResidency8Samples;
  VkBool32 sparseResidency16Samples;
  VkBool32 sparseResidencyAliased;
  VkBool32 variableMultisampleRate;
  VkBool32 inheritedQueries;
} VkPhysicalDeviceFeatures;

typedef struct {
  uint32_t maxImageDimension1D;
  uint32_t maxImageDimension2D;
  uint32_t maxImageDimension3D;
  uint32_t maxImageDimensionCube;
  uint32_t maxImageArrayLayers;
  uint32_t maxTexelBufferElements;
  uint32_t maxUniformBufferRange;
  uint32_t maxStorageBufferRange;
  uint32_t maxPushConstantsSize;
  uint32_t maxMemoryAllocationCount;
  uint32_t maxSamplerAllocationCount;
  VkDeviceSize bufferImageGranularity;
  VkDeviceSize sparseAddressSpaceSize;
  uint32_t maxBoundDescriptorSets;
  uint32_t maxPerStageDescriptorSamplers;
  uint32_t maxPerStageDescriptorUniformBuffers;
  uint32_t maxPerStageDescriptorStorageBuffers;
  uint32_t maxPerStageDescriptorSampledImages;
  uint32_t maxPerStageDescriptorStorageImages;
  uint32_t maxPerStageDescriptorInputAttachments;
  uint32_t maxPerStageResources;
  uint32_t maxDescriptorSetSamplers;
  uint32_t maxDescriptorSetUniformBuffers;
  uint32_t maxDescriptorSetUniformBuffersDynamic;
  uint32_t maxDescriptorSetStorageBuffers;
  uint32_t maxDescriptorSetStorageBuffersDynamic;
  uint32_t maxDescriptorSetSampledImages;
  uint32_t maxDescriptorSetStorageImages;
  uint32_t maxDescriptorSetInputAttachments;
  uint32_t maxVertexInputAttributes;
  uint32_t maxVertexInputBindings;
  uint32_t maxVertexInputAttributeOffset;
  uint32_t maxVertexInputBindingStride;
  uint32_t maxVertexOutputComponents;
  uint32_t maxTessellationGenerationLevel;
  uint32_t maxTessellationPatchSize;
  uint32_t maxTessellationControlPerVertexInputComponents;
  uint32_t maxTessellationControlPerVertexOutputComponents;
  uint32_t maxTessellationControlPerPatchOutputComponents;
  uint32_t maxTessellationControlTotalOutputComponents;
  uint32_t maxTessellationEvaluationInputComponents;
  uint32_t maxTessellationEvaluationOutputComponents;
  uint32_t maxGeometryShaderInvocations;
  uint32_t maxGeometryInputComponents;
  uint32_t maxGeometryOutputComponents;
  uint32_t maxGeometryOutputVertices;
  uint32_t maxGeometryTotalOutputComponents;
  uint32_t maxFragmentInputComponents;
  uint32_t maxFragmentOutputAttachments;
  uint32_t maxFragmentDualSrcAttachments;
  uint32_t maxFragmentCombinedOutputResources;
  uint32_t maxComputeSharedMemorySize;
  uint32_t maxComputeWorkGroupCount[3];
  uint32_t maxComputeWorkGroupInvocations;
  uint32_t maxComputeWorkGroupSize[3];
  uint32_t subPixelPrecisionBits;
  uint32_t subTexelPrecisionBits;
  uint32_t mipmapPrecisionBits;
  uint32_t maxDrawIndexedIndexValue;
  uint32_t maxDrawIndirectCount;
  float maxSamplerLodBias;
  float maxSamplerAnisotropy;
  uint32_t maxViewports;
  uint32_t maxViewportDimensions[2];
  float viewportBoundsRange[2];
  uint32_t viewportSubPixelBits;
  size_t minMemoryMapAlignment;
  VkDeviceSize minTexelBufferOffsetAlignment;
  VkDeviceSize minUniformBufferOffsetAlignment;
  VkDeviceSize minStorageBufferOffsetAlignment;
  int32_t minTexelOffset;
  uint32_t maxTexelOffset;
  int32_t minTexelGatherOffset;
  uint32_t maxTexelGatherOffset;
  float minInterpolationOffset;
  float maxInterpolationOffset;
  uint32_t subPixelInterpolationOffsetBits;
  uint32_t maxFramebufferWidth;
  uint32_t maxFramebufferHeight;
  uint32_t maxFramebufferLayers;
  VkSampleCountFlags framebufferColorSampleCounts;
  VkSampleCountFlags framebufferDepthSampleCounts;
  VkSampleCountFlags framebufferStencilSampleCounts;
  VkSampleCountFlags framebufferNoAttachmentsSampleCounts;
  uint32_t maxColorAttachments;
  VkSampleCountFlags sampledImageColorSampleCounts;
  VkSampleCountFlags sampledImageIntegerSampleCounts;
  VkSampleCountFlags sampledImageDepthSampleCounts;
  VkSampleCountFlags sampledImageStencilSampleCounts;
  VkSampleCountFlags storageImageSampleCounts;
  uint32_t maxSampleMaskWords;
  VkBool32 timestampComputeAndGraphics;
  float timestampPeriod;
  uint32_t maxClipDistances;
  uint32_t maxCullDistances;
  uint32_t maxCombinedClipAndCullDistances;
  uint32_t discreteQueuePriorities;
  float pointSizeRange[2];
  float lineWidthRange[2];
  float pointSizeGranularity;
  float lineWidthGranularity;
  VkBool32 strictLines;
  VkBool32 standardSampleLocations;
  VkDeviceSize optimalBufferCopyOffsetAlignment;
  VkDeviceSize optimalBufferCopyRowPitchAlignment;
  VkDeviceSize nonCoherentAtomSize;
} VkPhysicalDeviceLimits;

typedef struct {
  VkBool32 residencyStandard2DBlockShape;
  VkBool32 residencyStandard2DMultisampleBlockShape;
  VkBool32 residencyStandard3DBlockShape;
  VkBool32 residencyAlignedMipSize;
  VkBool32 residencyNonResidentStrict;
} VkPhysicalDeviceSparseProperties;

typedef struct {
  uint32_t apiVersion;
  uint32_t driverVersion;
  uint32_t vendorID;
  uint32_t deviceID;
  VkPhysicalDeviceType deviceType;
  char deviceName[256];
  uint8_t pipelineCacheUUID[16];
  VkPhysicalDeviceLimits limits;
  VkPhysicalDeviceSparseProperties sparseProperties;
} VkPhysicalDeviceProperties;

typedef struct {
  VkDeviceSize size;
  uint32_t alignment;
  uint32_t memoryTypeBits;
} VkMemoryRequirements;

typedef struct {
  VkMemoryPropertyFlags propertyFlags;
  uint32_t heapIndex;
} VkMemoryType;

typedef struct {
  VkDeviceSize size;
  VkMemoryHeapFlags flags;
} VkMemoryHeap;

typedef struct {
  uint32_t memoryTypeCount;
  VkMemoryType memoryTypes[32];
  uint32_t memoryHeapCount;
  VkMemoryHeap memoryHeaps[16];
} VkPhysicalDeviceMemoryProperties;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkDeviceSize allocationSize;
  uint32_t memoryTypeIndex;
} VkMemoryAllocateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags flags;
  uint32_t queueFamilyIndex;
  uint32_t queueCount;
  const float *pQueuePriorities;
} VkDeviceQueueCreateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags flags;
  uint32_t queueCreateInfoCount;
  const VkDeviceQueueCreateInfo *pQueueCreateInfos;
  uint32_t _enabledLayerCount;
  const char *const *_ppEnabledLayerNames;
  uint32_t enabledExtensionCount;
  const char *const *ppEnabledExtensionNames;
  const VkPhysicalDeviceFeatures *pEnabledFeatures;
} VkDeviceCreateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkBufferCreateFlags flags;
  VkDeviceSize size;
  VkBufferUsageFlags usage;
  VkSharingMode sharingMode;
  uint32_t queueFamilyIndexCount;
  const uint32_t *pQueueFamilyIndices;
} VkBufferCreateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkImageCreateFlags flags;
  VkImageType imageType;
  VkFormat format;
  VkExtent3D extent;
  uint32_t mipLevels;
  uint32_t arrayLayers;
  VkSampleCountFlags samples;
  VkImageTiling tiling;
  VkImageUsageFlags usage;
  VkSharingMode sharingMode;
  uint32_t queueFamilyIndexCount;
  const uint32_t *pQueueFamilyIndices;
  VkImageLayout initialLayout;
} VkImageCreateInfo;

typedef struct {
  VkImageAspectFlags aspectMask;
  uint32_t mipLevel;
  uint32_t baseArrayLayer;
  uint32_t layerCount;
} VkImageSubresourceLayers;

typedef struct {
  VkDeviceSize bufferOffset;
  uint32_t bufferRowLength;
  uint32_t bufferImageHeight;
  VkImageSubresourceLayers imageSubresource;
  VkOffset3D imageOffset;
  VkExtent3D imageExtent;
} VkBufferImageCopy;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkShaderModuleCreateFlags flags;
  size_t codeSize;
  const uint32_t *pCode;
} VkShaderModuleCreateInfo;

typedef struct {
  VkShaderStageFlags stageFlags;
  uint32_t offset;
  uint32_t size;
} VkPushConstantRange;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkPipelineLayoutCreateFlags flags;
  uint32_t setLayoutCount;
  const VkDescriptorSetLayout *pSetLayouts;
  uint32_t pushConstantRangeCount;
  const VkPushConstantRange *pPushConstantRanges;
} VkPipelineLayoutCreateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags flags;
  int32_t stage;
  VkShaderModule module;
  const char *pName;
  const void *pSpecializationInfo;
} VkPipelineShaderStageCreateInfo;

typedef struct {
  uint32_t binding;
  uint32_t stride;
  int32_t inputRate;
} VkVertexInputBindingDescription;

typedef struct {
  uint32_t location;
  uint32_t binding;
  VkFormat format;
  uint32_t offset;
} VkVertexInputAttributeDescription;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags flags;
  uint32_t vertexBindingDescriptionCount;
  const VkVertexInputBindingDescription *pVertexBindingDescriptions;
  uint32_t vertexAttributeDescriptionCount;
  const VkVertexInputAttributeDescription *pVertexAttributeDescriptions;
} VkPipelineVertexInputStateCreateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags flags;
  int32_t topology;
  VkBool32 primitiveRestartEnable;
} VkPipelineInputAssemblyStateCreateInfo;

typedef struct {
  float x;
  float y;
  float width;
  float height;
  float minDepth;
  float maxDepth;
} VkViewport;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags flags;
  uint32_t viewportCount;
  const VkViewport *pViewports;
  uint32_t scissorCount;
  const VkRect2D *pScissors;
} VkPipelineViewportStateCreateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags flags;
  VkBool32 depthClampEnable;
  VkBool32 rasterizerDiscardEnable;
  int32_t polygonMode;
  VkFlags cullMode;
  int32_t frontFace;
  VkBool32 depthBiasEnable;
  float depthBiasConstantFactor;
  float depthBiasClamp;
  float depthBiasSlopeFactor;
  float lineWidth;
} VkPipelineRasterizationStateCreateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags flags;
  VkSampleCountFlags rasterizationSamples;
  VkBool32 sampleShadingEnable;
  float minSampleShading;
  const uint32_t *pSampleMask;
  VkBool32 alphaToCoverageEnable;
  VkBool32 alphaToOneEnable;
} VkPipelineMultisampleStateCreateInfo;

typedef struct {
  int32_t failOp;
  int32_t passOp;
  int32_t depthFailOp;
  int32_t compareOp;
  uint32_t compareMask;
  uint32_t writeMask;
  uint32_t reference;
} VkStencilOpState;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags flags;
  VkBool32 depthTestEnable;
  VkBool32 depthWriteEnable;
  int32_t depthCompareOp;
  VkBool32 depthBoundsTestEnable;
  VkBool32 stencilTestEnable;
  VkStencilOpState front;
  VkStencilOpState back;
  float minDepthBounds;
  float maxDepthBounds;
} VkPipelineDepthStencilStateCreateInfo;

typedef struct {
  VkBool32 blendEnable;
  int32_t srcColorBlendFactor;
  int32_t dstColorBlendFactor;
  int32_t colorBlendOp;
  int32_t srcAlphaBlendFactor;
  int32_t dstAlphaBlendFactor;
  int32_t alphaBlendOp;
  VkFlags colorWriteMask;
} VkPipelineColorBlendAttachmentState;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags flags;
  VkBool32 logicOpEnable;
  int32_t logicOp;
  uint32_t attachmentCount;
  const VkPipelineColorBlendAttachmentState *pAttachments;
  float blendConstants[4];
} VkPipelineColorBlendStateCreateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags flags;
  uint32_t dynamicStateCount;
  const int32_t *pDynamicStates;
} VkPipelineDynamicStateCreateInfo;

typedef struct {
  VkFlags flags;
  VkFormat format;
  VkSampleCountFlags samples;
  int32_t loadOp;
  int32_t storeOp;
  int32_t stencilLoadOp;
  int32_t stencilStoreOp;
  VkImageLayout initialLayout;
  VkImageLayout finalLayout;
} VkAttachmentDescription;

typedef struct {
  uint32_t attachment;
  VkImageLayout layout;
} VkAttachmentReference;

typedef struct {
  VkFlags flags;
  int32_t pipelineBindPoint;
  uint32_t inputAttachmentCount;
  const VkAttachmentReference *pInputAttachments;
  uint32_t colorAttachmentCount;
  const VkAttachmentReference *pColorAttachments;
  const VkAttachmentReference *pResolveAttachments;
  const VkAttachmentReference *pDepthStencilAttachment;
  uint32_t preserveAttachmentCount;
  const uint32_t *pPreserveAttachments;
} VkSubpassDescription;

typedef struct {
  uint32_t srcSubpass;
  uint32_t dstSubpass;
  VkFlags srcStageMask;
  VkFlags dstStageMask;
  VkFlags srcAccessMask;
  VkFlags dstAccessMask;
  VkFlags dependencyFlags;
} VkSubpassDependency;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkPipelineCreateFlags flags;
  uint32_t stageCount;
  const VkPipelineShaderStageCreateInfo *pStages;
  const VkPipelineVertexInputStateCreateInfo *pVertexInputState;
  const VkPipelineInputAssemblyStateCreateInfo *pInputAssemblyState;
  const void *pTessellationState;
  const VkPipelineViewportStateCreateInfo *pViewportState;
  const VkPipelineRasterizationStateCreateInfo *pRasterizationState;
  const VkPipelineMultisampleStateCreateInfo *pMultisampleState;
  const VkPipelineDepthStencilStateCreateInfo *pDepthStencilState;
  const VkPipelineColorBlendStateCreateInfo *pColorBlendState;
  const VkPipelineDynamicStateCreateInfo *pDynamicState;
  VkPipelineLayout layout;
  VkRenderPass renderPass;
  uint32_t subpass;
  VkPipeline basePipelineHandle;
  int32_t basePipelineIndex;
} VkGraphicsPipelineCreateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkPipelineCreateFlags flags;
  VkPipelineShaderStageCreateInfo stage;
  VkPipelineLayout layout;
  VkPipeline basePipelineHandle;
  int32_t basePipelineIndex;
} VkComputePipelineCreateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkRenderPassCreateFlags flags;
  uint32_t attachmentCount;
  const VkAttachmentDescription *pAttachments;
  uint32_t subpassCount;
  const VkSubpassDescription *pSubpasses;
  uint32_t dependencyCount;
  const VkSubpassDependency *pDependencies;
} VkRenderPassCreateInfo;

typedef struct {
  VkComponentSwizzle r;
  VkComponentSwizzle g;
  VkComponentSwizzle b;
  VkComponentSwizzle a;
} VkComponentMapping;

typedef struct {
  VkImageAspectFlags aspectMask;
  uint32_t baseMipLevel;
  uint32_t levelCount;
  uint32_t baseArrayLayer;
  uint32_t layerCount;
} VkImageSubresourceRange;

typedef union {
  float float32[4];
  int32_t int32[4];
  uint32_t uint32[4];
} VkClearColorValue;

typedef struct {
  float depth;
  uint32_t stencil;
} VkClearDepthStencilValue;

typedef union {
  VkClearColorValue color;
  VkClearDepthStencilValue depthStencil;
} VkClearValue;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags flags;
  VkImage image;
  VkImageViewType viewType;
  VkFormat format;
  VkComponentMapping components;
  VkImageSubresourceRange subresourceRange;
} VkImageViewCreateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFramebufferCreateFlags flags;
  VkRenderPass renderPass;
  uint32_t attachmentCount;
  const void *pAttachments;
  uint32_t width;
  uint32_t height;
  uint32_t layers;
} VkFramebufferCreateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkCommandPoolCreateFlags flags;
  uint32_t queueFamilyIndex;
} VkCommandPoolCreateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkCommandPool commandPool;
  VkCommandBufferLevel level;
  uint32_t commandBufferCount;
} VkCommandBufferAllocateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkCommandBufferUsageFlags flags;
  const void *pInheritanceInfo;
} VkCommandBufferBeginInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags flags;
} VkSemaphoreCreateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags flags;
} VkFenceCreateInfo;

typedef struct {
  uint32_t binding;
  VkDescriptorType descriptorType;
  uint32_t descriptorCount;
  VkShaderStageFlags stageFlags;
  const void *pImmutableSamplers;
} VkDescriptorSetLayoutBinding;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkDescriptorSetLayoutCreateFlags flags;
  uint32_t bindingCount;
  const VkDescriptorSetLayoutBinding *pBindings;
} VkDescriptorSetLayoutCreateInfo;

typedef struct {
  VkDescriptorType type;
  uint32_t descriptorCount;
} VkDescriptorPoolSize;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkDescriptorPoolCreateFlags flags;
  uint32_t maxSets;
  uint32_t poolSizeCount;
  const VkDescriptorPoolSize *pPoolSizes;
} VkDescriptorPoolCreateInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkDescriptorPool descriptorPool;
  uint32_t descriptorSetCount;
  const VkDescriptorSetLayout *pSetLayouts;
} VkDescriptorSetAllocateInfo;

typedef struct {
  VkBuffer buffer;
  VkDeviceSize offset;
  VkDeviceSize range;
} VkDescriptorBufferInfo;

typedef struct {
  VkSampler sampler;
  VkImageView imageView;
  VkImageLayout imageLayout;
} VkDescriptorImageInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkDescriptorSet dstSet;
  uint32_t dstBinding;
  uint32_t dstArrayElement;
  uint32_t descriptorCount;
  VkDescriptorType descriptorType;
  const VkDescriptorImageInfo *pImageInfo;
  const VkDescriptorBufferInfo *pBufferInfo;
  const void *pTexelBufferView;
} VkWriteDescriptorSet;

typedef struct {
  uint32_t minImageCount;
  uint32_t maxImageCount;
  VkExtent2D currentExtent;
  VkExtent2D minImageExtent;
  VkExtent2D maxImageExtent;
  uint32_t maxImageArrayLayers;
  VkSurfaceTransformFlagsKHR supportedTransforms;
  VkSurfaceTransformFlagBitsKHR currentTransform;
  VkCompositeAlphaFlagsKHR supportedCompositeAlpha;
  VkImageUsageFlags supportedUsageFlags;
} VkSurfaceCapabilitiesKHR;

typedef struct {
  VkFormat format;
  VkColorSpaceKHR colorSpace;
} VkSurfaceFormatKHR;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkSwapchainCreateFlagsKHR flags;
  VkSurfaceKHR surface;
  uint32_t minImageCount;
  VkFormat imageFormat;
  VkColorSpaceKHR imageColorSpace;
  VkExtent2D imageExtent;
  uint32_t imageArrayLayers;
  VkImageUsageFlags imageUsage;
  VkSharingMode imageSharingMode;
  uint32_t queueFamilyIndexCount;
  const uint32_t *pQueueFamilyIndices;
  VkSurfaceTransformFlagBitsKHR preTransform;
  VkCompositeAlphaFlagBitsKHR compositeAlpha;
  VkPresentModeKHR presentMode;
  VkBool32 clipped;
  VkSwapchainKHR oldSwapchain;
} VkSwapchainCreateInfoKHR;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkRenderPass renderPass;
  VkFramebuffer framebuffer;
  VkRect2D renderArea;
  uint32_t clearValueCount;
  const void *pClearValues;
} VkRenderPassBeginInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  uint32_t waitSemaphoreCount;
  const VkSemaphore *pWaitSemaphores;
  const void *pWaitDstStageMask;
  uint32_t commandBufferCount;
  const VkCommandBuffer *pCommandBuffers;
  uint32_t signalSemaphoreCount;
  const VkSemaphore *pSignalSemaphores;
} VkSubmitInfo;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  uint32_t waitSemaphoreCount;
  const VkSemaphore *pWaitSemaphores;
  uint32_t swapchainCount;
  const VkSwapchainKHR *pSwapchains;
  const uint32_t *pImageIndices;
  VkResult *pResults;
} VkPresentInfoKHR;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags srcAccessMask;
  VkFlags dstAccessMask;
  VkImageLayout oldLayout;
  VkImageLayout newLayout;
  uint32_t srcQueueFamilyIndex;
  uint32_t dstQueueFamilyIndex;
  VkImage image;
  VkImageSubresourceRange subresourceRange;
} VkImageMemoryBarrier;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkFlags srcAccessMask;
  VkFlags dstAccessMask;
} VkMemoryBarrier;

typedef int32_t VkFilter;
typedef int32_t VkSamplerMipmapMode;
typedef int32_t VkSamplerAddressMode;
typedef int32_t VkBorderColor;
typedef VkFlags VkSamplerCreateFlags;

typedef struct {
  VkStructureType sType;
  const void *pNext;
  VkSamplerCreateFlags flags;
  VkFilter magFilter;
  VkFilter minFilter;
  VkSamplerMipmapMode mipmapMode;
  VkSamplerAddressMode addressModeU;
  VkSamplerAddressMode addressModeV;
  VkSamplerAddressMode addressModeW;
  float mipLodBias;
  VkBool32 anisotropyEnable;
  float maxAnisotropy;
  VkBool32 compareEnable;
  int32_t compareOp;
  float minLod;
  float maxLod;
  VkBorderColor borderColor;
  VkBool32 unnormalizedCoordinates;
} VkSamplerCreateInfo;

VkResult vkGetPhysicalDeviceProperties(VkPhysicalDevice physicalDevice,
                                       VkPhysicalDeviceProperties *pProperties);

void vkGetPhysicalDeviceMemoryProperties(
    VkPhysicalDevice physicalDevice,
    VkPhysicalDeviceMemoryProperties *pMemoryProperties);

void vkGetPhysicalDeviceQueueFamilyProperties(
    VkPhysicalDevice physicalDevice, uint32_t *pQueueFamilyPropertyCount,
    VkQueueFamilyProperties *pQueueFamilyProperties);

VkResult vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
    VkPhysicalDevice physicalDevice, VkSurfaceKHR surface,
    VkSurfaceCapabilitiesKHR *pSurfaceCapabilities);

VkResult vkGetPhysicalDeviceSurfaceFormatsKHR(
    VkPhysicalDevice physicalDevice, VkSurfaceKHR surface,
    uint32_t *pSurfaceFormatCount, VkSurfaceFormatKHR *pSurfaceFormats);

VkResult vkGetPhysicalDeviceSurfacePresentModesKHR(
    VkPhysicalDevice physicalDevice, VkSurfaceKHR surface,
    uint32_t *pPresentModeCount, VkPresentModeKHR *pPresentModes);

VkResult vkCreatePipelineLayout(VkDevice device,
                                const VkPipelineLayoutCreateInfo *pCreateInfo,
                                const VkAllocationCallbacks *pAllocator,
                                VkPipelineLayout *pPipelineLayout);

VkResult vkCreateGraphicsPipelines(
    VkDevice device, VkPipelineCache pipelineCache, uint32_t createInfoCount,
    const VkGraphicsPipelineCreateInfo *pCreateInfos,
    const VkAllocationCallbacks *pAllocator, VkPipeline *pPipelines);

VkResult vkCreateRenderPass(VkDevice device,
                            const VkRenderPassCreateInfo *pCreateInfo,
                            const VkAllocationCallbacks *pAllocator,
                            VkRenderPass *pRenderPass);

VkResult vkCreateImageView(VkDevice device,
                           const VkImageViewCreateInfo *pCreateInfo,
                           const VkAllocationCallbacks *pAllocator,
                           VkImageView *pView);

VkResult vkCreateFramebuffer(VkDevice device,
                             const VkFramebufferCreateInfo *pCreateInfo,
                             const VkAllocationCallbacks *pAllocator,
                             VkFramebuffer *pFramebuffer);

void vkGetBufferMemoryRequirements(VkDevice device, VkBuffer buffer,
                                   VkMemoryRequirements *pMemoryRequirements);

void vkGetImageMemoryRequirements(VkDevice device, VkImage image,
                                  VkMemoryRequirements *pMemoryRequirements);

VkResult vkCreateImage(VkDevice device, const VkImageCreateInfo *pCreateInfo,
                       const VkAllocationCallbacks *pAllocator,
                       VkImage *pImage);

VkResult vkBindImageMemory(VkDevice device, VkImage image,
                           VkDeviceMemory memory, VkDeviceSize memoryOffset);

void vkCmdCopyBufferToImage(VkCommandBuffer commandBuffer, VkBuffer srcBuffer,
                            VkImage dstImage, VkImageLayout dstImageLayout,
                            uint32_t regionCount,
                            const VkBufferImageCopy *pRegions);

VkResult vkAllocateMemory(VkDevice device,
                          const VkMemoryAllocateInfo *pAllocateInfo,
                          const VkAllocationCallbacks *pAllocator,
                          VkDeviceMemory *pMemory);

VkResult vkBindBufferMemory(VkDevice device, VkBuffer buffer,
                            VkDeviceMemory memory, VkDeviceSize memoryOffset);

VkResult vkMapMemory(VkDevice device, VkDeviceMemory memory,
                     VkDeviceSize offset, VkDeviceSize size, VkFlags flags,
                     void **ppData);

void vkUnmapMemory(VkDevice device, VkDeviceMemory memory);

VkResult vkCreateCommandPool(VkDevice device,
                             const VkCommandPoolCreateInfo *pCreateInfo,
                             const VkAllocationCallbacks *pAllocator,
                             VkCommandPool *pCommandPool);

VkResult vkCreateDescriptorSetLayout(
    VkDevice device, const VkDescriptorSetLayoutCreateInfo *pCreateInfo,
    const VkAllocationCallbacks *pAllocator, VkDescriptorSetLayout *pSetLayout);

VkResult vkCreateDescriptorPool(VkDevice device,
                                const VkDescriptorPoolCreateInfo *pCreateInfo,
                                const VkAllocationCallbacks *pAllocator,
                                VkDescriptorPool *pDescriptorPool);

VkResult
vkAllocateDescriptorSets(VkDevice device,
                         const VkDescriptorSetAllocateInfo *pAllocateInfo,
                         VkDescriptorSet *pDescriptorSets);

void vkUpdateDescriptorSets(VkDevice device, uint32_t descriptorWriteCount,
                            const VkWriteDescriptorSet *pDescriptorWrites,
                            uint32_t descriptorCopyCount,
                            const void *pDescriptorCopies);

VkResult
vkAllocateCommandBuffers(VkDevice device,
                         const VkCommandBufferAllocateInfo *pAllocateInfo,
                         VkCommandBuffer *pCommandBuffers);

VkResult vkBeginCommandBuffer(VkCommandBuffer commandBuffer,
                              const VkCommandBufferBeginInfo *pBeginInfo);

VkResult vkEndCommandBuffer(VkCommandBuffer commandBuffer);

void vkCmdBeginRenderPass(VkCommandBuffer commandBuffer,
                          const VkRenderPassBeginInfo *pRenderPassBegin,
                          VkSubpassContents contents);

void vkCmdEndRenderPass(VkCommandBuffer commandBuffer);

void vkCmdBindPipeline(VkCommandBuffer commandBuffer,
                       VkPipelineBindPoint pipelineBindPoint,
                       VkPipeline pipeline);

void vkCmdDraw(VkCommandBuffer commandBuffer, uint32_t vertexCount,
               uint32_t instanceCount, uint32_t firstVertex,
               uint32_t firstInstance);

VkResult vkQueueSubmit(VkQueue queue, uint32_t submitCount,
                       const VkSubmitInfo *pSubmits, uint64_t fence);

VkResult vkQueueWaitIdle(VkQueue queue);

void vkGetDeviceQueue(VkDevice device, uint32_t queueFamilyIndex,
                      uint32_t queueIndex, VkQueue *pQueue);

VkResult vkCreateSemaphore(VkDevice device,
                           const VkSemaphoreCreateInfo *pCreateInfo,
                           const VkAllocationCallbacks *pAllocator,
                           VkSemaphore *pSemaphore);

VkResult vkCreateFence(VkDevice device, const VkFenceCreateInfo *pCreateInfo,
                       const VkAllocationCallbacks *pAllocator,
                       VkFence *pFence);

VkResult vkCreateSwapchainKHR(VkDevice device,
                              const VkSwapchainCreateInfoKHR *pCreateInfo,
                              const VkAllocationCallbacks *pAllocator,
                              VkSwapchainKHR *pSwapchain);

VkResult vkGetSwapchainImagesKHR(VkDevice device, VkSwapchainKHR swapchain,
                                 uint32_t *pSwapchainImageCount,
                                 VkImage *pSwapchainImages);

VkResult vkAcquireNextImageKHR(VkDevice device, VkSwapchainKHR swapchain,
                               uint64_t timeout, VkSemaphore semaphore,
                               VkFence fence, uint32_t *pImageIndex);

VkResult vkQueuePresentKHR(VkQueue queue, const VkPresentInfoKHR *pPresentInfo);

void vkCmdUpdateBuffer(VkCommandBuffer commandBuffer, VkBuffer dstBuffer,
                       VkDeviceSize dstOffset, VkDeviceSize dataSize,
                       const void *pData);

VkResult vkWaitForFences(VkDevice device, uint32_t fenceCount,
                         const VkFence *pFences, VkBool32 waitAll,
                         uint64_t timeout);

VkResult vkResetFences(VkDevice device, uint32_t fenceCount,
                       const VkFence *pFences);

void vkCmdSetViewport(VkCommandBuffer commandBuffer, uint32_t firstViewport,
                      uint32_t viewportCount, const VkViewport *pViewports);

void vkCmdSetScissor(VkCommandBuffer commandBuffer, uint32_t firstScissor,
                     uint32_t scissorCount, const VkRect2D *pScissors);

void vkCmdBindVertexBuffers(VkCommandBuffer commandBuffer,
                            uint32_t firstBinding, uint32_t bindingCount,
                            const VkBuffer *pBuffers,
                            const VkDeviceSize *pOffsets);

typedef int32_t VkIndexType;

void vkCmdBindIndexBuffer(VkCommandBuffer commandBuffer, VkBuffer buffer,
                          VkDeviceSize offset, VkIndexType indexType);

void vkCmdDrawIndexed(VkCommandBuffer commandBuffer, uint32_t indexCount,
                      uint32_t instanceCount, uint32_t firstIndex,
                      int32_t vertexOffset, uint32_t firstInstance);

typedef uint32_t VkXlibSurfaceCreateFlagsKHR;
typedef uint32_t VkWin32SurfaceCreateFlagsKHR;

typedef struct VkXlibSurfaceCreateInfoKHR {
  VkStructureType sType;
  const void *pNext;
  VkXlibSurfaceCreateFlagsKHR flags;
  void *dpy;
  uint64_t window;
} VkXlibSurfaceCreateInfoKHR;

typedef struct VkWin32SurfaceCreateInfoKHR {
  VkStructureType sType;
  const void *pNext;
  VkWin32SurfaceCreateFlagsKHR flags;
  void *hinstance;
  void *hwnd;
} VkWin32SurfaceCreateInfoKHR;

VkResult vkCreateXlibSurfaceKHR(VkInstance instance,
                                const VkXlibSurfaceCreateInfoKHR *pCreateInfo,
                                const VkAllocationCallbacks *pAllocator,
                                VkSurfaceKHR *pSurface);

VkResult vkCreateWin32SurfaceKHR(VkInstance instance,
                                 const VkWin32SurfaceCreateInfoKHR *pCreateInfo,
                                 const VkAllocationCallbacks *pAllocator,
                                 VkSurfaceKHR *pSurface);

VkResult vkCreateSampler(VkDevice device,
                         const VkSamplerCreateInfo *pCreateInfo,
                         const VkAllocationCallbacks *pAllocator,
                         VkSampler *pSampler);

void vkDestroySampler(VkDevice device, VkSampler sampler,
                      const VkAllocationCallbacks *pAllocator);

VkResult vkCreateComputePipelines(
    VkDevice device, VkPipelineCache pipelineCache, uint32_t createInfoCount,
    const VkComputePipelineCreateInfo *pCreateInfos,
    const VkAllocationCallbacks *pAllocator, VkPipeline *pPipelines);

void vkCmdDispatch(VkCommandBuffer commandBuffer, uint32_t groupCountX,
                   uint32_t groupCountY, uint32_t groupCountZ);

void vkCmdPipelineBarrier(VkCommandBuffer commandBuffer, VkFlags srcStageMask,
                          VkFlags dstStageMask, VkFlags dependencyFlags,
                          uint32_t memoryBarrierCount,
                          const void *pMemoryBarriers,
                          uint32_t bufferMemoryBarrierCount,
                          const void *pBufferMemoryBarriers,
                          uint32_t imageMemoryBarrierCount,
                          const VkImageMemoryBarrier *pImageMemoryBarriers);
