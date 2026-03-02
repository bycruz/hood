---@alias hood.Buffer.DataType "u32" | "f32"

---@alias hood.BufferUsage
--- | "COPY_DST"
--- | "COPY_SRC"
--- | "VERTEX"
--- | "INDEX"
--- | "UNIFORM"
--- | "STORAGE"

---@class hood.BufferDescriptor
---@field size number
---@field usages hood.BufferUsage[]

---@class hood.Buffer
---@field destroy fun(self: hood.Buffer)
