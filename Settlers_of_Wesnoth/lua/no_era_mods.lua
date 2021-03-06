local with_wesnoth = wesnoth
if not wesnoth then
	package.path = package.path .. ";../../../../../data/lua/?.lua"
	wesnoth = require("wesnoth")
end

local loaded, debug_utils = pcall(wesnoth.dofile, "~add-ons/Wesnoth_Lua_Pack/debug_utils.lua")
local dbms = debug_utils.dbms or function() return "" end
local sdbms = debug_utils.sdbms

local helper = wesnoth.require "lua/helper.lua"
local wml_actions = wesnoth.wml_actions

local sow_units = wesnoth.get_variable("sow_units")
local sow_terrain_types_temp =  wesnoth.get_variable("sow_terrain_types")
local sow_terrain_types = {}
sow_no_era_terrain_replacements = {}
if with_wesnoth then
	for k, v in pairs(sow_terrain_types_temp) do
		if v[1] == "terrain_type" then
			table.insert(sow_terrain_types, v)
			sow_no_era_terrain_replacements[v[2].string] = v[2].replacement
		end
	end
	sow_terrain_types_temp = nil
	wesnoth.set_variable("sow_terrain_types", sow_terrain_types)
end

sow_images = {}
for k, v in pairs(wesnoth.get_variable("sow_images") or {}) do
	local new_key = string.gsub(k, "_", "/")
	sow_images[new_key] = v
end

if not sow_tools then sow_tools = {} end
function sow_tools.custom_image_to_core(image)
	assert(not sow_era_is_used)

	local dot = string.find(image, "%.")
	image = string.sub(image, 1, dot - 1)
	local result = sow_images[image]
	if result then return result end

	assert(false, "image not found: " .. image)
end

function sow_put_unit(x, y, cfg)
	assert(not sow_era_is_used)

	local variabletype = type(x)
	if variabletype == "userdata" then
		assert(not y)
		wesnoth.put_unit(x)
		return
	end
	if variabletype == "number" and not cfg then
		assert(type(y) == "number")
		wesnoth.put_unit(x, y)
		return
	end

	assert(type(cfg) == "table")
	local type = cfg.type
	assert(cfg.side)
	cfg = helper.deep_copy(cfg)
	cfg.type = "Fog Clearer"
	cfg.image = wesnoth.unit_types[cfg.type].__cfg.image
	local unit_type_id
	for unit_type in helper.child_range(sow_units, "unit_type") do
		unit_type_id = unit_type.id
		assert(unit_type_id)
		if unit_type_id == type then
			unit_type = helper.deep_copy(unit_type)
			unit_type.id = nil
			unit_type.max_moves = unit_type.movement; unit_type.movement = nil
			unit_type.max_experience = unit_type.experience; unit_type.experience = nil
			unit_type.ellipse = nil
			unit_type.die_sound = nil --this attribute isn't recognized by the unit constructor

			local road = false
			local building = false
			local port = false
			local image = sow_tools.custom_image_to_core(unit_type.image)
			local terrain
			if unit_type_id == "sow_roadn" then
				road = true
			elseif unit_type_id == "sow_roadne" then
				assert(false)
			elseif unit_type_id == "sow_roadnw" then
				road = true
				if cfg.facing == "nw" then image = sow_tools.custom_image_to_core("units/roadnwfacingnw.png") end
			elseif unit_type_id == "sow_settle" then
				building = true
			elseif unit_type_id == "sow_city" then
				building = true
			elseif unit_type_id == "sow_grain" then
				port = true
				terrain = "Wwt"
			elseif unit_type_id == "sow_wool" then
				port = true
				terrain = "Wwt"
			elseif unit_type_id == "sow_brick" then
				port = true
				terrain = "Wwt"
			elseif unit_type_id == "sow_ore" then
				port = true
				terrain = "Wwt"
			elseif unit_type_id == "sow_lumber" then
				port = true
				terrain = "Wwt"
			elseif unit_type_id == "sow_any" then
				port = true
				terrain = "Wwt"
			elseif unit_type_id == "sow_robber" then
			elseif unit_type_id == "sow_largest" then
			elseif unit_type_id == "sow_longest" then
			elseif unit_type_id == "sow_leader" then
			else
				assert(false)
			end

			helper.shallow_copy(cfg, unit_type)
			local function blit_unit_image(unit_cfg, image)
-- 				wml_actions.wml_message({ logger = "debug", message = "image: " .. image .. "; uw: " .. uw .. "; ow: " .. ow .. "; uh: " .. uh .. "; oh: " .. oh })
				assert(not unit_cfg.overlays, "overlay already set; " .. dbms(unit_cfg, false, "unit_cfg", false, false, true))
				unit_cfg.overlays = sow_image.create(unit_cfg.image):blit(sow_image.create(image)).image
			end
			blit_unit_image(unit_type, image)
			table.insert(unit_type, {"variables", { type = unit_type_id, road = road, building = building, port = port, image = unit_type.overlays }})
			wesnoth.put_unit(x, y, unit_type)
			if terrain then wesnoth.set_terrain(x, y, terrain) end
			sow_tools.teamcolorize_unit_image(wesnoth.get_unit(x, y))
			return
		end
	end
	assert(false)
end

function sow_tools.teamcolorize_unit_image(unit)
	assert(not sow_era_is_used)
	assert(type(unit) == "userdata" and getmetatable(unit) == "unit")
	local ucfg = unit.__cfg
	ucfg.overlays = sow_image.create(unit.variables.image):tc_shift(unit.side).image
	wesnoth.put_unit(ucfg)
end

function sow_tools.custom_terrain_to_core(terrain)
	assert(not sow_era_is_used)
	if terrain == false and type(terrain) == "boolean" then return terrain end
	local result = ""
	local found = false
	for t in string.gmatch(terrain, "[^%s,][^,]*") do
		assert(string.sub(t, 3, 3) == "^")
		if(sow_no_era_terrain_replacements[string.sub(t, 3)]) then
			found = true
			result = result .. ", " .. string.sub(t, 1, 2) .. sow_no_era_terrain_replacements[string.sub(t, 3)]
		else
			result = result .. ", " .. t
		end
	end
	result = string.sub(result, 2)
	assert(found)
	return result
end

function sow_tools.core_terrain_to_custom(terrain)
	assert(not sow_era_is_used)
	if(terrain == "Rb") then return "Rzn" end
	if(terrain == "Gll") then return "Rzne" end
	if(terrain == "Rd") then return "Rznw" end
	assert(false)
end

function sow_tools.sugarize_number_terrain(x, y, t)
	assert(not sow_era_is_used)
	local length = string.len(t)
	assert(length >= 3)
	t = string.sub(t, length -2, length)
	for terrain_type in helper.child_range(sow_terrain_types, "terrain_type") do
		if terrain_type.string == t then
			wml_actions.item({ x = x, y = y, image = "terrain/mask.png" })
			wml_actions.label({ x = x, y = y, text = string.format("%u\n%s", terrain_type.number, terrain_type.frequency), color = "255, 255, 255" })
			return
		end
	end
	assert(false)
end

