---@class hood.Enums
local enums = {}

---@enum hood.ColorWrites
enums.ColorWrites = {
	Red = 0b1,
	Green = 0b10,
	Blue = 0b100,
	Alpha = 0b1000,
	Color = 0b0111,
	All = 0b1111,
}

return enums
