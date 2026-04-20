---@alias hood.Buffer.DataType "u32" | "f32"

---@alias hood.BufferUsage
--- | "COPY_DST"
--- | "COPY_SRC"
--- | "VERTEX"
--- | "INDEX"
--- | "UNIFORM"
--- | "STORAGE"
--- | "MAP_READ"

---@class hood.BufferDescriptor
---@field size number
---@field usages hood.BufferUsage[]

---@class hood.Buffer
---@field destroy fun(self: hood.Buffer)
---@field mapAsync fun(self: hood.Buffer)
---@field getMappedRange fun(self: hood.Buffer, offset: number?, size: number?): ffi.cdata*
---@field unmap fun(self: hood.Buffer)
