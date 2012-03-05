
sow_image = {}
local image_methods = {}

function image_methods.blit(self, overlay)
	local msg = "failure to blit: " .. tostring(overlay) .. " onto " .. tostring(self)
	if getmetatable(overlay) ~= "sow_image" then
		local success, o = pcall(sow_image.create, overlay)
		if success then overlay = o else error(msg .. " (not a sow_image): " .. o) end
	end
	assert(self.w >= overlay.w and self.h >= overlay.h, msg .. " (overlay larger than base)")
	local function get_blit_coord(below, above)
		return math.floor(below/2.0) - math.floor(above/2.0)
	end
	local loc = { get_blit_coord(self.w, overlay.w), get_blit_coord(self.h, overlay.h) }
	return sow_image.create(string.format("%s~BLIT(%s, %u, %u)", self.image, overlay.image, loc[1], loc[2]))
end

function image_methods:scale(factor)
	return sow_image.create(string.format("%s~SCALE(%u, %u)", self.image, factor, factor))
end

function image_methods:item(x, y)
	wesnoth.wml_actions.item({ x = x, y = y, image = self.image })
end

local function normalize_to_average(color)
	local result = {}
	local average = (color[1] + color[2] + color[3]) / 3.0
	for i, v in ipairs(color) do
		local new = v - average
		if new >= 0 then result[i] = math.floor(new)
		else result[i] = math.ceil(new)
		end
	end
	return result
end
function image_methods:tc_shift(side)
	assert(sow_tools.check_integer(side, 1, #wesnoth.sides), "not a valid side number")
	local hex = sow_constants.sow_labels_new.players[side].color
	local rgb = normalize_to_average(sow_tools.hex2rgb(hex))
	return sow_image.create(string.format("%s~CS(%i,%i,%i)", self.image, rgb[1], rgb[2], rgb[3]))
end

function image_methods:tc(side)
	assert(sow_tools.check_integer(side, 1, #wesnoth.sides), "not a valid side number")
	return sow_image.create(string.format("%s~TC(%u,magenta)", self.image, side))
end

local function image_tostring(self)
	return string.format("%s:%ux%u", self.image, self.w, self.h)
end

local image_meta = {
	__index = image_methods,
	__tostring = image_tostring,
	__metatable = "sow_image"
}

function sow_image.create(image)
	assert(type(image) == "string")
	local w, h = wesnoth.get_image_size(image)
	assert(w, "image not found: " .. image)
	return setmetatable({ w = w, h = h, image = image }, image_meta)
end
