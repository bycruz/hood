---@class hood.ImageCopyTexture
---@field texture hood.Texture
---@field mipLevel number?
---@field origin { x: number?, y: number?, z: number? }?

---@class hood.ImageCopyBuffer
---@field buffer hood.Buffer
---@field offset number?
---@field bytesPerRow number
---@field rowsPerImage number?

---@class hood.Extent3D
---@field width number
---@field height number
---@field depthOrArrayLayers number?

---@class hood.TextureWriteDescriptor
---@field width number
---@field height number
---@field depth number? # For 3D textures
---@field mip number?
---@field layer number?
---@field offset number?
---@field bytesPerRow number?
---@field rowsPerImage number?

---@class hood.RenderPassDescriptor
---@field colorAttachments { op: hood.LoadOp, texture: hood.TextureView }[]
---@field depthStencilAttachment? { op: hood.DepthOp, texture: hood.TextureView }

---@class hood.ComputePassDescriptor

---@class hood.CommandEncoder
---@field finish fun(self: hood.CommandEncoder): hood.CommandBuffer
---@field beginRendering fun(self: hood.CommandEncoder, descriptor: hood.RenderPassDescriptor)
---@field endRendering fun(self: hood.CommandEncoder)
---@field setViewport fun(self: hood.CommandEncoder, x: number, y: number, width: number, height: number)
---@field setVertexBuffer fun(self: hood.CommandEncoder, slot: number, buffer: hood.Buffer, offset: number?)
---@field setIndexBuffer fun(self: hood.CommandEncoder, buffer: hood.Buffer, format: hood.IndexFormat, offset: number?)
---@field setBindGroup fun(self: hood.CommandEncoder, index: number, bindGroup: hood.BindGroup)
---@field setPipeline fun(self: hood.CommandEncoder, pipeline: hood.Pipeline)
---@field draw fun(self: hood.CommandEncoder, vertexCount: number, instanceCount: number, firstVertex: number?, firstInstance: number?)
---@field drawIndexed fun(self: hood.CommandEncoder, indexCount: number, instanceCount: number, firstIndex: number?, baseVertex: number?, firstInstance: number?)
---@field writeBuffer fun(self: hood.CommandEncoder, buffer: hood.Buffer, size: number, data: ffi.cdata*, offset: number?)
---@field writeTexture fun(self: hood.CommandEncoder, texture: hood.Texture, descriptor: hood.TextureWriteDescriptor, data: ffi.cdata*)
---@field copyTextureToBuffer fun(self: hood.CommandEncoder, source: hood.ImageCopyTexture, destination: hood.ImageCopyBuffer, copySize: hood.Extent3D)
--- Compute
---@field beginComputePass fun(self: hood.CommandEncoder, descriptor: hood.ComputePassDescriptor)
---@field endComputePass fun(self: hood.CommandEncoder)
---@field dispatchWorkgroups fun(self: hood.CommandEncoder, x: number, y: number, z: number)
---@field setComputePipeline fun(self: hood.CommandEncoder, pipeline: hood.ComputePipeline)
