if not wesnoth then
	package.path = package.path .. ";../../../../../data/lua/?.lua"
	wesnoth = require("wesnoth")
end
-----------------------------------------------------------------------------------
--disabling compatibility-1.8.lua
--I want this to check during 1.10 (stable).
--TODO: remove when that file gets removed
wesnoth["get_side"] = nil
wesnoth["get_side_count"] = nil
wesnoth["get_unit_type_ids"] = nil
wesnoth["get_unit_type"] = nil
wesnoth["register_wml_action"] = nil
--~ wesnoth["fire"] = nil
-----------------------------------------------------------------------------------

helper = wesnoth.require "lua/helper.lua"
function helper.shallow_copy(t, result)
	local u = result or {}
	for k,v in pairs(t) do
		u[k] = v
	end
	return setmetatable(u, getmetatable(t))
end
function helper.deep_copy(source)
	local copied = {}

	local function doit(src)
		local dst = {}
		copied[src] = dst
		for k,v in pairs(src) do
			if type(v) ~= "table" then
				dst[k] = v
			else
				dst[k] = copied[v] or doit(v)
			end
		end
		return setmetatable(dst, getmetatable(src))
	end

	if type(source) ~= "table" then
		return source
	else
		return doit(source)
	end
end

local load_string = "~add-ons/Settlers_of_Wesnoth/lua/"
wml_actions = wesnoth.wml_actions
local _ = wesnoth.textdomain("wesnoth-Settlers_of_Wesnoth")

local loaded, debug_utils = pcall(wesnoth.dofile, "~add-ons/Wesnoth_Lua_Pack/debug_utils.lua")
dbms = debug_utils.dbms or function() return "" end
sdbms = debug_utils.sdbms

sow_era_is_used = wesnoth.get_variable("sow_era_is_used")
if sow_era_is_used then
	wesnoth.dofile(load_string .. "constants.lua")
	wesnoth.dofile(load_string .. "tools.lua")
	wesnoth.dofile(load_string .. "sow-wml-tags.lua")
	wesnoth.dofile(load_string .. "dialogs.lua")
	wesnoth.dofile(load_string .. "image.lua")

	sow_put_unit = wesnoth.put_unit
	function sow_tools.custom_terrain_to_core(t) return t end
	function sow_tools.core_terrain_to_custom(t) return t end
	function sow_tools.custom_image_to_core(i) return i end
end
sow_ai = {}
function sow_ai.is_ai(side_number)
	return false
end

-----------------------------------------------------------------------------------

if wesnoth.theme_items then
	function wesnoth.theme_items.turn()
		local sow_game_turn = wesnoth.get_variable("sow_game_turn") or 1
		return { { "element", { text = sow_game_turn } } }
	end
end

-----------------------------------------------------------------------------------
-- Various all-purpose functions

function helper.warning(msg)
	wesnoth.message("Lua warning", msg)
end

local function you_currently_have(resources, headline)
	headline = headline or _"You currently have:"
	resources = helper.shallow_copy(resources)
	local result = string.format("<span weight='bold'>%s</span>", tostring(headline))
	local remove_colon = false
	local function add(resource, translatable_string)
		if resources[resource] == 0 then return end
		result = result .. sow_tools.format(_"\n\t%u units of %s;", resources[resource], translatable_string)
		remove_colon = true
	end
	add("lumber", _"lumber")
	add("grain", _"grain")
	add("wool", _"wool")
	add("brick", _"brick")
	add("ore", _"ore")
	if remove_colon then result = result:sub(1, result:len() - 1) .. "." end
	return result
end

local function choose_a_resource(specification, choices, scale)
	scale = scale or 30
	specification = specification or ""
	choices = choices or {}
	local function insert(translatable_string, resource)
		table.insert(choices, string.format("&" .. sow_tools.custom_image_to_core(string.format("icons/%s.png", resource)) .. "~SCALE(%u,%u)=%s%s", scale, scale, tostring(translatable_string), tostring(specification)))
	end
	local resource_table = { "lumber", "grain", "wool", "brick", "ore" }
	insert(_"Lumber", resource_table[1])
	insert(_"Grain", resource_table[2])
	insert(_"Wool", resource_table[3])
	insert(_"Brick", resource_table[4])
	insert(_"Ore", resource_table[5])
	return choices, resource_table
end

local function yes_no_buttons()
	local choices = {}
	local back_image = sow_tools.custom_image_to_core("icons/back.png")
	table.insert(choices, "&" .. back_image .. "~SCALE(20,20)~FL(horiz)=" .. tostring(_"yes"))
	table.insert(choices, "*&" .. back_image .. "~SCALE(20,20)=" .. tostring(_"no"))
	return choices
end

function sow_victory_manager(player, table)
	local victory = wesnoth.get_variable(string.format("sow_game_stats.player[%u].victory", player))
	for k, v in pairs(table) do
		victory[k] = victory[k] + v
	end
	wesnoth.set_variable(string.format("sow_game_stats.player[%u].victory", player), victory)
end

local function currently_unavailable(side_for)
	wml_actions.message({ speaker = "narrator", image = "wesnoth-icon.png", message = _"This feature is currently unavailable...", side_for = side_for })
end

local function check_required_resources(player, table, message)
	if message == nil then message = true end
	local resources = wesnoth.get_variable(string.format("sow_game_stats.player[%u].ressources", player))
	local required_resources_string = "("
	local sufficient = true
	for key, value in pairs(table) do
		value = math.abs(value)
		required_resources_string = string.format("%s%u %s, ", required_resources_string, value, key)
		if sufficient and resources[key] < value then
			sufficient = false
		end
	end
	if not sufficient and message then
		required_resources_string = required_resources_string:sub(1, required_resources_string:len() - 2)  .. ")"
		wml_actions.message({ speaker = "narrator", image = "wesnoth-icon.png", side_for = player,
			message = tostring(_"You don't have all the required resources! ") .. required_resources_string })
	end
	return sufficient
end

local function get_input_integer(default, allowed_min, allowed_max, side_for)
	local first = true
	local input_integer = default
	while first or not sow_tools.check_integer(input_integer, allowed_min, allowed_max) do
		if not first then wml_actions.message({ side_for = side_for, speaker = "narrator", image = "wesnoth-icon.png",
				message = string.format(tostring(_"Invalid input! Allowed are integer numbers between %i and %i"), allowed_min, allowed_max) })
		end
		first = false
		wml_actions.message({ speaker = "narrator", image = "wesnoth-icon.png", message =  _"How much ?",
			{"text_input", { text = default, variable = "sow_LUA_input_integer", label = _"number:"}} })
		input_integer = wesnoth.get_variable("sow_LUA_input_integer"); wesnoth.set_variable("sow_LUA_input_integer")
	end
	return input_integer
end


local function animate_resources_change(player, x, y, sound, resources_string)
	wesnoth.scroll_to_tile(x, y)
	if resources_string then wesnoth.float_label(x, y, string.format("<span color='%s'>%s</span>", sow_constants.sow_labels_new .players[player].color, resources_string)) end
	if sound then wesnoth.play_sound(sound) end
	wesnoth.delay(500)
end

--This function retrieves the complete numerical data displayed in the table in the upper left-corner from sow_game_stats
--and updates all entries for all players.
--Instead of changing single entries only this function should be called each time; it's bit ineffective but way cleaner in the long run.
local function update_displayed_numericals()
	local sow_game_stats = wesnoth.get_variable("sow_game_stats")
	local player_index = 0
	for player, index in sow_tools.valid_player_range() do
		local function update_category(tag, single, total)
			local category = helper.get_child(player, tag)
			if tag == "ressources" then tag = "resources" end -- backwards compat
			local sum = 0
			for key, value in pairs(category) do
				if key == "ressources" then key = "resources" end -- backwards compat
				if key == "points" then key = "victory" end -- backwards compat
				if total then sum = sum + value end
				if single then
					sow_tools.label(index, sow_constants.sow_labels_new [tag][key], value)
				end
			end
			if total then
				sow_tools.label(index, sow_constants.sow_labels_new [tag][tag], sum)
			end
		end
		update_category("ressources", true, false)
		update_category("development", true, true)
		update_category("victory", true, false)
	end
end

--can be called from right-click menu when in debug-mode for insta-testing lua stuff (reloads this file previously too)
function sow_main()
	sow_ressource_manager(1, { lumber = 100, grain = 100, wool = 100, brick = 100, ore = 100 })
	sow_ressource_manager(2, { lumber = 100, grain = 100, wool = 100, brick = 100, ore = 100 })
 	sow_ressource_manager(3, { lumber = 100, grain = 100, wool = 100, brick = 100, ore = 100 })

--~ 	for player, side_number in sow_tools.valid_player_range() do
--~ 		local development = helper.get_child(player, "development")
--~ 		development.knight = 2
--~ 		development.road = 2
--~ 		development.plenty = 2
--~ 		development.monopoly = 2
--~ 		development.victory = 2
--~ 		wesnoth.set_variable(sow_tools.format("sow_game_stats.player[%u].development", side_number), development)
--~ 	end
--~ 	update_displayed_numericals()

-- 	sdbms(sow_dialogs.confirm(_"Your offer/demand arrangement doesn't seem ready yet, do you really want to continue ?"))
-- 	local result = sow_dialogs.domestic_trade({ lumber = 1, grain = 3, wool = 2, brick = 1, ore = 0, resources = 7 }, { lumber = 0, grain = 0, wool = 0, brick = 0, ore = 0, resources = 0 }, "1,2,3")
-- 	dbms(result)

-- 	wml_actions.message({ message = "normal <b>bold </b><big>bigger <big>even bigger <span size = 'large'>large <span color = 'green'>large and green </span></span></big></big>" })

-- 	wml_actions.objectives({ note =  _"normal <b>bold </b><big>bigger <big>even bigger <span size = 'large'>large <span color = 'green'>large and green </span></span></big></big>" })
-- 	wml_actions.modify_unit({ {"filter", { x = 11, y = 4 }}, name = _"normal <b>bold </b><big>bigger <big>even bigger <span size = 'large'>large <span color = 'green'>large and green </span></span></big></big>" })

-- 	wml_actions.modify_side({ side = 5, controller = "ai" })

-- 	wesnoth.fire_event("sow_set_sow_help")
-- 	local help = wesnoth.get_variable("sow_help[1]")
-- 	wml_actions.message({ speaker = "narrator", message = help.text })

-- 	wml_actions.remove_item({})
-- 	local image = sow_image.create("wesnoth-icon.png")
-- 	image = image:scale(72):blit(sow_image.create("units/trolls/grunt.png"):scale(73))
-- 	image = sow_image.create("terrain/village/human-city.png")
-- 	image = image:tc_shift(9)
--  	image:item(9, 5)

	sow_activate_robber(1)
end

-----------------------------------------------------------------------------------

function sow_manage_leaders()
	local title = wesnoth.get_variable("sow_help[0].title")
	for i in ipairs(wesnoth.sides) do
		local loc = wesnoth.get_starting_location(i)
		local original_leader = wesnoth.get_unit(loc[1], loc[2])
		local player
		if original_leader then
			player = original_leader.name
		end
		wesnoth.put_unit(loc[1], loc[2])
		local text = ""
		local max_i = wesnoth.get_variable("sow_help.length") - 1
		if i == 9 then
			text = wesnoth.get_variable("sow_help[0].text")
		elseif i <= max_i then
			text = wesnoth.get_variable(string.format("sow_help[%u].text", i))
		end
		local description = string.format("<small>%s\n%s</small>", tostring(title), tostring(text))
		sow_put_unit(loc[1], loc[2], { type = "sow_leader", facing = "se", canrecruit = true, side = i, name = player, description = description })
	end
end

-- Function to randomly generate map at game turn 1

function sow_mapgen()

	-- Determining amount of players, Generating Variables, Placing Labels, Removing Shroud
	--choosing_turn: for when the robber gets moved or trade is active (will replace)
	game_stats = { dev_used = false, goal = 10, free_road = 0, players_qty = 0, map = "", trade_offers_left = max_trade_offers}
	table.insert(game_stats, { "choosing_turn", { active = false, type = nil, stop_at_side = 0, {"specifications", {}} }})
	table.insert(game_stats, { "leading_player", { active = false, side = 0, points = 0, limit = sow_constants.MAX_UNSIGNED } })
	table.insert(game_stats, {"player", { valid = false }}) --this is a dirty hack  to work around arrays starting at 1 in lua but 0 in wml (?)
	for i,v in ipairs(wesnoth.sides) do

		if i ~= 9 then
			if v.controller ~= "null" then
				-- Creating variable
				--initialize the resources table with exactly those resources needed to build 2 settlements and 2 roads
				--so that the player's don't go into negative resources during the first two turns
				--ressources: the sum; TODO: rename - named so to match the key in sow_labels
				local resources = { lumber = 4, wool = 2, grain = 2, brick = 4, ore = 0, ressources = 12 }
				table.insert(game_stats, {"player", { valid = true, {"ressources", resources },
				{"development", { victory = 0, monopoly = 0, road = 0, plenty = 0, knight = 0 }},
				{"victory", { points = 0, road = 0, knight = 0 }} }})
-- 				sow_data.player[i] = helper.deep_copy(sow_data.a_player)
				game_stats.players_qty = game_stats.players_qty + 1

				-- Placing labels & icons
				sow_tools.label(i, sow_constants.sow_labels_new.name, sow_constants.sow_labels_new.players[i].name)
				local function overlay(key)
					local image = sow_image.create(sow_tools.custom_image_to_core(string.format("items/%s.png", key)))
					if not sow_era_is_used then
						image = sow_image.create("misc/blank-hex.png"):blit(image:scale(40))
					end
					image:item(sow_constants.sow_labels_new.players[i].x, sow_constants.sow_labels_new.resources[key])
				end
				overlay("lumber")
				overlay("grain")
				overlay("wool")
				overlay("brick")
				overlay("ore")
			else
				table.insert(game_stats, {"player", { valid = false }})
-- 				sow_data.player[i] = helper.shallow_copy({ valid = false })
			end
		else
			--i == 9 here
			-- Placing main labels & icons
			local function label(y, text)
				sow_tools.label(9, y, text)
			end
			label(sow_constants.sow_labels_new.victory.victory, _"Victory Points")
			label(sow_constants.sow_labels_new.resources.resources, _"Resources")
			label(sow_constants.sow_labels_new.development.development, _"Development")
			label(sow_constants.sow_labels_new.victory.road, _"Longest Road")
			label(sow_constants.sow_labels_new.victory.knight, _"Largest Army")

			label(sow_constants.sow_labels_new.resources.lumber, _"lumber")
			label(sow_constants.sow_labels_new.resources.grain, _"grain")
			label(sow_constants.sow_labels_new.resources.wool, _"wool")
			label(sow_constants.sow_labels_new.resources.brick, _"brick")
			label(sow_constants.sow_labels_new.resources.ore, _"ore")

			label(sow_constants.sow_labels_new.development.knight, _"knight cards")
			label(sow_constants.sow_labels_new.development.monopoly, _"monopoly cards")
			label(sow_constants.sow_labels_new.development.plenty, _"plenty cards")
			label(sow_constants.sow_labels_new.development.road, _"road cards")
			label(sow_constants.sow_labels_new.development.victory, _"victory cards")

			sow_put_unit(sow_constants.sow_labels_new.players[i].x, sow_constants.sow_labels_new.victory.road, { side=i, type = "sow_longest" })
			sow_put_unit(sow_constants.sow_labels_new.players[i].x, sow_constants.sow_labels_new.victory.knight, { side=i, type = "sow_largest" })
			table.insert(game_stats, {"player", { valid = false }})
-- 			sow_data.player[i] = helper.shallow_copy({ valid = false })
		end
	end

	-- Selecting the map
	--the more players, the larger the map
	local n = sow_tools.sow_random(100)
	if game_stats.players_qty < 4 then
		if n <= 25 then game_stats.map="a"
		elseif n <= 50 then game_stats.map="b"
		else game_stats.map="c" end

	elseif game_stats.players_qty == 4 then
		if n <= 75 then game_stats.map="c"
		else game_stats.map="d" end

	elseif game_stats.players_qty == 5 then
		if n <= 40 then game_stats.map="e"
		elseif n <= 70 then game_stats.map="g"
		else game_stats.map="h" end

	elseif game_stats.players_qty == 6 then
		if n <= 30 then game_stats.map="h"
		elseif n <= 60 then game_stats.map="i"
		elseif n <= 80 then game_stats.map="f"
		else game_stats.map="g" end

	elseif game_stats.players_qty == 7 then
		if n <= 40 then game_stats.map="j"
		elseif n <= 60 then game_stats.map="k"
		elseif n <= 80 then game_stats.map="l"
		else game_stats.map="m" end

	elseif game_stats.players_qty == 8 then
		if n <= 35 then game_stats.map="k"
		elseif n <= 70 then game_stats.map="l"
		else game_stats.map="m" end
	end
--~ 	if wesnoth.game_config.debug then game_stats.map = "k" end
	local sow_map_file
	if sow_era_is_used then
		sow_map_file = wesnoth.dofile(string.format("~add-ons/Settlers_of_Wesnoth/maps/sow_%s.lua", game_stats.map))
	else
		sow_map_file = wesnoth.get_variable(string.format("sow_maps.sow_%s", game_stats.map))
		wesnoth.set_variable("sow_maps")
		sow_map_file = string.gsub(sow_map_file, "Rznw", sow_no_era_terrain_replacements.Rznw)
		sow_map_file = string.gsub(sow_map_file, "Rzne", sow_no_era_terrain_replacements.Rzne)
		sow_map_file = string.gsub(sow_map_file, "Rzn", sow_no_era_terrain_replacements.Rzn)
	end
	wml_actions.replace_map({ map = sow_map_file, expand = true, shrink = true })

	local longest = wesnoth.get_units({ type = "sow_longest", {"or", { {"filter_wml", { {"variables", { type = "sow_longest" }} }} }} })[1]
	local largest = wesnoth.get_units({ type = "sow_largest", {"or", { {"filter_wml", { {"variables", { type = "sow_largest" }} }} }} })[1]
	wesnoth.set_terrain(longest.x, longest.y, "Rrc")
	wesnoth.set_terrain(largest.x, largest.y, "Rrc")
	for index, unit in ipairs(wesnoth.get_units({ canrecruit = true })) do wesnoth.set_terrain(unit.x, unit.y, "Rrc") end
	--These are the void-hexes which were supposed to be hidden below  largest army and longest road but are no longer
	-- due to coordinates downshift
	wesnoth.set_terrain(2, 6, "Wwt")
	wesnoth.set_terrain(2, 8, "Wwt")

	-- Removing shroud
	-- in an additional loop since the map can have be made larger
	for side_number = 1, #wesnoth.sides do
		if side_number >= 9 then break end
		wml_actions.remove_shroud({ side = side_number, x = string.format("%i-%i", sow_constants.sow_labels_new.players[side_number].x - 1, sow_constants.sow_labels_new.players[side_number].x  + 1)})
		wml_actions.remove_shroud({ side = side_number, {"not", { x="0-19", y = "13- 999"}} })
		wml_actions.remove_shroud({ side = side_number, x = "0-3", y = "0- 999" })
	end


	-- Setting the resource tiles
	--sow_hexes are the center hexes of the resource tiles (the ones that get the number terrains)
	local sow_hexes = wesnoth.get_locations({ terrain = "Xv", {"filter_adjacent_location", { terrain="Xv", count = 6 }} })
	--TODO: can the following 2 loops be merged ?
	-- Setting the 6s and 8s first to make sure they ain't adjacent
	local shift_index = 0
	for i, v in ipairs(sow_maps[game_stats.map].numbers) do
		i = i + shift_index --this line is needed due to the modification of sow_maps[game_stats.map].numbers inside of this loop
		v = sow_maps[game_stats.map].numbers[i] --same
		if v == "Re^Ye" or v == "Re^Yf" then --"Re^Ye" = terrain string for number 6; "Re^Yf" = terrain string for number 8
			while true do
				local hex = sow_tools.sow_random(#sow_hexes)
				if wesnoth.eval_conditional({ {"have_location", { x = sow_hexes[hex][1], y = sow_hexes[hex][2], {"not", { radius = 4, terrain = sow_tools.custom_terrain_to_core("Re^Ye, Re^Yf") }}  }} }) then
					--That means, no tile adjacent to this tile already has the number 6 or 8 in its center
					--(otherwise, don't break out of the loop and again choose a random tile)
					-- Setting the terrain around the numbers
					while true do
						local n = sow_tools.sow_random(#sow_maps[game_stats.map].ressources)
						if sow_maps[game_stats.map].ressources[n] ~= "Dd" then
							for i, loc in ipairs(wesnoth.get_locations{ {"filter_adjacent_location", { x = sow_hexes[hex][1], y = sow_hexes[hex][2]}} }) do
								wesnoth.set_terrain(loc[1], loc[2], sow_maps[game_stats.map].ressources[n])
							end
							table.remove(sow_maps[game_stats.map].ressources, n)
							break
						end
					end
					-- Setting the number
					wesnoth.set_terrain(sow_hexes[hex][1], sow_hexes[hex][2], sow_tools.custom_terrain_to_core(v))
					if not sow_era_is_used then sow_tools.sugarize_number_terrain(sow_hexes[hex][1], sow_hexes[hex][2], v) end
					table.remove(sow_hexes, hex)
					break
				end
			end
			table.remove(sow_maps[game_stats.map].numbers, i); shift_index = shift_index - 1
		end
	end

	-- Setting the other hexes
	for i,v in ipairs(sow_hexes) do
		-- Setting the terrain
		local n = sow_tools.sow_random(#sow_maps[game_stats.map].ressources)
		for i, loc in ipairs(wesnoth.get_locations{ {"filter_adjacent_location", { x = v[1], y = v[2] }} }) do
			wesnoth.set_terrain(loc[1], loc[2], sow_maps[game_stats.map].ressources[n])
		end

		-- Setting the number
		if sow_maps[game_stats.map].ressources[n] == "Dd" then
			wesnoth.set_terrain(v[1], v[2], "Dd^Do")
			local robber = wesnoth.get_units({ type = "sow_robber", {"or", { {"filter_wml", { {"variables", { type = "sow_robber" }} }} }} })[1]
			if not robber then
				sow_put_unit(v[1],v[2], { type="sow_robber", side = 9 })
			end
		else
			local n = sow_tools.sow_random(#sow_maps[game_stats.map].numbers)
			if sow_maps[game_stats.map].numbers[n] == "Re^Ye" or sow_maps[game_stats.map].numbers[n] == "Re^Yf" then
				helper.warning("encountered a number 6 or 8 hex too late")
			end
			wesnoth.set_terrain(v[1], v[2], sow_tools.custom_terrain_to_core(sow_maps[game_stats.map].numbers[n]))
			if not sow_era_is_used then sow_tools.sugarize_number_terrain(v[1], v[2], sow_maps[game_stats.map].numbers[n]) end
			table.remove(sow_maps[game_stats.map].numbers, n)
		end
		table.remove(sow_maps[game_stats.map].ressources, n)
	end
	if #sow_maps[game_stats.map].ressources ~= 0 then helper.warning("not all resource tiles distributed") end
	if #sow_maps[game_stats.map].numbers ~= 0 then helper.warning("not all number hexes distributed") end

	-- Setting the ports
	for i,v in ipairs(wesnoth.get_locations({ terrain="Xv", {"filter_adjacent_location", { terrain="Wwt^Bw*" }} })) do
		local n = sow_tools.sow_random(#sow_maps[game_stats.map].ports)
		sow_put_unit(v[1], v[2], { type=string.format("sow_%s", sow_maps[game_stats.map].ports[n]), side = 9, facing = "se" })
		table.remove(sow_maps[game_stats.map].ports, n)
	end
	if #sow_maps[game_stats.map].ports ~= 0 then helper.warning("not all ports distributed") end

	table.insert(game_stats, {"dev_deck", sow_maps[game_stats.map].dev_deck})
	wesnoth.set_variable("sow_game_stats", game_stats)
	update_displayed_numericals()
end

-----------------------------------------------------------------------------------

-- Function to manage ressources
-- The table must consist of sets of key=value where key="ressource type" and value="amount to add". Value can be negative.

function sow_ressource_manager(player, table, invert)
	assert(wesnoth.sides[player])
	local inventory = wesnoth.get_variable(string.format("sow_game_stats.player[%i]", player))
	local resources = helper.get_child(inventory, "ressources")
	for k, v in pairs(table) do
		if invert then v = -v end
		resources[k] = resources[k] + v
		assert(resources[k] >= 0)
		resources.ressources = resources.ressources + v
	end
	--note that the resources table within the inventory table has changed, since it is a pointer type!!
	wesnoth.set_variable(string.format("sow_game_stats.player[%i]", player), inventory)
end

-----------------------------------------------------------------------------------

-- Build Functions

local function get_lose_longest_road()
	local filter = { type = "sow_roadn,sow_roadne,sow_roadnw", side = player }
	if not sow_era_is_used then
		filter.type = nil
		table.insert(filter, {"filter_wml", { {"variables", { road = true }} }})
	end
	local roads = wesnoth.get_units(filter)
	local best_length = 0
	for i, v in ipairs(roads) do best_length = math.max(best_length, sow_getting_path_length(player, v, 0, nil, v.id)) end

	local longest = wesnoth.get_units({ type = "sow_longest", {"or", { {"filter_wml", { {"variables", { type = "sow_longest" }} }} }} })[1]

	return getter, loser
end

local function check_for_longest_road(player)
	-- Looking wether he gets or keeps the longest road award
	local inventory = wesnoth.get_variable(string.format("sow_game_stats.player[%i]", player))
	--TODO: maybe put complete victory points calculation for all players into sow_victory_check()
	local victory = helper.get_child(inventory, "victory")
	local settings = { speaker = "narrator", caption = _"Longest Road", image = "icons/crossed_sword_and_hammer.png" .. "~SCALE(120,120)" }

	--returns the length of that player's longest road (integer)
	local function sow_longest_check(player)
		local filter = { type = "sow_roadn,sow_roadne,sow_roadnw", side = player }
		if not sow_era_is_used then
			filter.type = nil
			table.insert(filter, {"filter_wml", { {"variables", { road = true }} }})
		end
		local roads = wesnoth.get_units(filter)
		local best_length = 0
		for i, v in ipairs(roads) do best_length = math.max(best_length, sow_getting_path_length(player, v, 0, nil, v.id)) end
		return best_length
	end
	victory.road = sow_longest_check(player)
	local longest = wesnoth.get_units({ type = "sow_longest", {"or", { {"filter_wml", { {"variables", { type = "sow_longest" }} }} }} })[1]
	local road = { size = 0, side = 0, word = "none" }--the new longest road

	local min_longest_road_length = 5
--~ 	if wesnoth.game_config.debug then min_longest_road_length = 3 end
	if victory.road >= min_longest_road_length then
		if longest.side == 9 then
			road.size = 5; road.side = player
		else
			local other_victory = wesnoth.get_variable(string.format("sow_game_stats.player[%i].victory", longest.side))
			if victory.road > other_victory.road then
				road.size = victory.road; road.side = player
				other_victory.points = other_victory.points - 2
			end
			wesnoth.set_variable(string.format("sow_game_stats.player[%i].victory", longest.side), other_victory)
		end
	end

	--TODO: can the above and below blocks be merged ?
	--TODO: translatability, maybe convert to wml ?
	settings.message = string.format(tostring(_"\n%s's longest road is now %i units long."), tostring(sow_constants.sow_labels_new.players[player].name), victory.road)
	if road.side == player then
		if longest.side == player then road.word = "keeps"
		else
			road.word = "gets"
			longest.side = player
			if not sow_era_is_used then sow_tools.teamcolorize_unit_image(longest) end
			--victory points are set in sow_victory_check
		end
		settings.message = settings.message .. string.format(tostring(_"\n%s %s the Longest Road award, worth 2 victory points!"), tostring(sow_constants.sow_labels_new.players[player].name), road.word)
		sow_tools.message(settings)
	end
	wesnoth.set_variable(string.format("sow_game_stats.player[%i]", player), inventory)
end

function sow_build_road(player, x, y)
	local free_road = wesnoth.get_variable("sow_game_stats.free_road")

	local resources_string = "- 1 lumber, - 1 brick"
	if free_road > 0 then
		free_road = free_road - 1
		wesnoth.set_variable("sow_game_stats.free_road", free_road)
		resources_string = nil
	else
		local resources_change = { lumber = -1, brick = -1 }
		if not check_required_resources(player, resources_change ) then return false end
		sow_ressource_manager(player, resources_change )
	end
	local direction = string.sub(sow_tools.core_terrain_to_custom(wesnoth.get_terrain(x, y)), 3)
	local road_type = "sow_roadnw"
	if direction == "n" then road_type = "sow_roadn" end
	sow_put_unit(x, y, { type = road_type, side = player, facing = sow_tools.direction_to_facing(direction) })
	wml_actions.redraw({})
	local sound = "build.wav"
	if not sow_era_is_used then sound = "mace.wav" end
	animate_resources_change(player, x, y, sound, resources_string)

	check_for_longest_road(player)
	sow_victory_check(player)
	update_displayed_numericals()
end

function sow_build_settle(player, x, y)
	local resources_change = { brick = -1, wool = -1, grain = -1, lumber = -1 }
	if not check_required_resources(player, resources_change ) then return false end
	sow_ressource_manager(player, resources_change)
	sow_put_unit(x, y, { type = "sow_settle", side = player })
	wml_actions.redraw({})
	local sound = "build.wav"
	if not sow_era_is_used then sound = "mace.wav" end
	animate_resources_change(player, x, y, sound, "- 1 lumber, - 1 grain, -1 wool, - 1 brick")

	-- Checking if there's a port to be given nearby
	if wesnoth.eval_conditional({ {"have_location",{ x = x, y = y, { "filter_adjacent_location", { terrain = "Wwt^Bw*" }} }} }) then
		local filter = { type = "sow_grain,sow_wool,sow_brick,sow_ore,sow_lumber,sow_any", { "filter_location", { x = x, y = y, radius = 2 }} }
		if not sow_era_is_used then
			filter.type = nil
			table.insert(filter, {"filter_wml", { {"variables", { port = true }} }})
		end
		local port = wesnoth.get_units(filter)
		for i,v in ipairs(port) do
			v.side = player
			if not sow_era_is_used then sow_tools.teamcolorize_unit_image(v) end
		end
	end
	sow_victory_check(player)
	update_displayed_numericals()
-- 	sow_data.ais[player]:recalc_weights({ x, y })
end

function sow_build_city(player, x, y)
	local resources_change = { grain = -2, ore = -3 }
	if not check_required_resources(player, resources_change ) then return false end
	sow_ressource_manager(player, resources_change)
	sow_put_unit(x, y, { type = "sow_city", side = player })
	wml_actions.redraw({})
	local sound = "build.wav"
	if not sow_era_is_used then sound = "mace.wav" end
	animate_resources_change(player, x, y, sound, "- 2 grain, - 3 ore")
	sow_victory_check(player)
	update_displayed_numericals()
-- 	sow_data.ais[player]:recalc_weights({ x, y })
end

function sow_build_second_settle(player, x, y)
	sow_build_settle(player, x, y)

	-- Giving initial resources
	local ress = { lumber = 0, grain = 0, wool = 0, brick = 0, ore = 0 }
	--TODO: this resource_letter variable appears more than once...
	for i,v in ipairs(wesnoth.get_locations({ {"not", { terrain = "Rrc,Rz*,Rd,Gll,Rb,Xv,Wwt,Wwt^Bw*" }}, {"and", { x = x, y = y, radius = 1 }} })) do
		local terrain = wesnoth.get_terrain(v[1], v[2])
		if resource_letter[terrain] then
			ress[resource_letter[terrain]] = ress[resource_letter[terrain]] + 1
		end
	end
	local resources_string = "\n\n"
	for key, value in pairs(ress) do
		if value > 0 then
			resources_string = string.format("%s+ %i %s,", resources_string, value, key)
		end
	end
	resources_string = string.sub(resources_string, 1, string.len(resources_string) - 1)
	animate_resources_change(player, x, y, nil, resources_string)
	sow_ressource_manager(player, ress)
	update_displayed_numericals()
end

function sow_random_initial_settlements(turn_number, side_number)
	local function handle_turn(arg_turn_number)
		if turn_number ~= arg_turn_number then return end

		local function units_are_sufficient(types, count)
			return wesnoth.eval_conditional({ {"have_unit", { type = types, side = side_number, count = count }} })
		end

		local units_are_sufficient_var
		if sow_era_is_used then
			units_are_sufficient_var = units_are_sufficient("sow_settle", arg_turn_number)
		else
			units_are_sufficient_var = wesnoth.eval_conditional({ {"have_unit", { {"filter_wml", { {"variables", { type = "sow_settle"}} }}, count = arg_turn_number, side = side_number }} })
		end
		if not units_are_sufficient_var then
			--TODO: these SLFs are analog to the ones for the set_menu_items
			local filter = { type = "sow_settle, sow_city" }
			if not sow_era_is_used then
				filter = { {"filter_wml", { {"variables", { building = true }} }} }
			end
			local positions = wesnoth.get_locations({ terrain = "Rrc", {"not", { {"filter",{}} }}, {"not", { {"filter", filter }, radius = 2 }} })
			local position = positions[sow_tools.sow_random(#positions)]
			if arg_turn_number == 1 then
				sow_build_settle(side_number, position[1], position[2])
			else
				sow_build_second_settle(side_number, position[1], position[2])
			end
		end

		if sow_era_is_used then
			units_are_sufficient_var = units_are_sufficient("sow_roadn,sow_roadne,sow_roadnw", arg_turn_number)
		else
			units_are_sufficient_var = wesnoth.eval_conditional({ {"have_unit", { {"filter_wml", { {"variables", { road = true }} }}, count = arg_turn_number, side = side_number }} })
		end
		if not units_are_sufficient_var then
			local buildings = { type = "sow_settle,sow_city", side = side_number }
			local roads = { type = "sow_roadn,sow_roadne,sow_roadnw", side = side_number }
			if not sow_era_is_used then
				buildings.type = nil
				table.insert(buildings, {"filter_wml", { {"variables", { building = true }} }})
				roads.type = nil
				table.insert(roads, {"filter_wml", { {"variables", { road = true }} }})
			end
			local positions = wesnoth.get_locations({ terrain ="Rz*,Rd,Gll,Rb", {"not", { {"filter",{}} }},
				{"filter_adjacent_location", { {"filter", buildings } }},
				{"not", { {"filter", roads }, radius = 2 }}
			})
			local position = positions[sow_tools.sow_random(#positions)]
			sow_build_road(side_number, position[1], position[2])
		end
	end
	handle_turn(1)
	handle_turn(2)
end

-----------------------------------------------------------------------------------
-- Robber's Functions

local function sow_end_robber(choosing_turn)
	local specifications = helper.get_child(choosing_turn, "specifications")
	wesnoth.set_variable("sow_game_stats.choosing_turn", { active = false, type = nil, stop_at_side = 0, {"specifications", {}}})
	if specifications.random then return end

	local filter = { type = "sow_city,sow_settle", {"filter_location", { x = specifications.x, y = specifications.y, radius = 2 }}, {"not", { side = choosing_turn.stop_at_side }} }
	if not sow_era_is_used then
		filter.type = nil
		table.insert(filter, {"filter_wml", { {"variables", { building = true }} }} )
	end
	local targets = wesnoth.get_units(filter)
	if not targets[1] then return end

	local settings = { speaker = "narrator", caption = _"Steal resources", image = "units/human-outlaws/bandit.png" .. "~SCALE(120,120)", message = _"Who will you steal from ?"}
	local target_resources = { target_sides = {} }
	local choices = {}
	for index, target in ipairs(targets) do
		local image
		if sow_era_is_used then
			image = sow_image.create(target.__cfg.image)
			image = image:tc(target.side)
		else
			image = sow_image.create(target.variables.image)
			image = image:tc_shift(target.side)
		end
		if not target_resources[target.side] then
			table.insert(target_resources, target.side, wesnoth.get_variable(string.format("sow_game_stats.player[%u].ressources", target.side)))
			table.insert(target_resources.target_sides, target.side)
			table.insert(choices, sow_tools.format("&%s=<span weight='bold'>%s</span> (%u %s)", image.image, tostring(sow_constants.sow_labels_new.players[target.side].name), target_resources[target.side].ressources, _"resources left"))
		end
	end
	local choice = 1; if target_resources.target_sides[2] then choice = helper.get_user_choice(settings, choices) end
	local chosen_side = target_resources.target_sides[choice]
	target_resources[chosen_side].ressources = nil
	local possible_resources = {}
	for key, value in pairs(target_resources[chosen_side]) do
		while value > 0 do
			table.insert(possible_resources, key)
			value = value - 1
		end
	end
	settings = { speaker = "narrator", caption = _"Resource theft report", image = "units/human-outlaws/bandit.png" .. "~SCALE(120,120)", side_for = string.format("%u,%u", choosing_turn.stop_at_side, chosen_side) }
	if #possible_resources == 0 then
		settings.message = string.format(tostring(_"%s had no resources for %s to steal..."), tostring(sow_constants.sow_labels_new.players[chosen_side].name), tostring(sow_constants.sow_labels_new.players[choosing_turn.stop_at_side].name))
		wml_actions.message(settings)
		return
	else
		local chosen_resource = possible_resources[sow_tools.sow_random(#possible_resources)]
		--TODO: chosen_resource isn't translatable that way
		settings.message = string.format(tostring(_"%s stole a unit of %s from %s."), tostring(sow_constants.sow_labels_new.players[choosing_turn.stop_at_side].name), chosen_resource, tostring(sow_constants.sow_labels_new.players[chosen_side].name))
		sow_ressource_manager(choosing_turn.stop_at_side, { [chosen_resource] = 1 })
		sow_ressource_manager(chosen_side, { [chosen_resource] = -1 })
	end
	settings.side_for = nil
	sow_tools.message(settings)
	update_displayed_numericals()
end

function sow_half_resources(side_number)
	if sow_ai.is_ai(side_number) then sow_data.ais[side_number]:sow_half_ai_resources() return end
	local choosing_turn = wesnoth.get_variable("sow_game_stats.choosing_turn")
	local function local_half_resources()
		local variable = string.format("sow_game_stats.player[%u].ressources", side_number)
		local resources = wesnoth.get_variable(variable)
		if resources.ressources <= sow_constants.halfing_limit then return end
		local halfed_resources = math.ceil(resources.ressources / 2.0)
		local res_to_lose = resources.ressources - halfed_resources
		wml_actions.print({ text = string.format("<span color='%s'>%s %s %s %u %s!</span>", sow_constants.sow_labels_new.players[side_number].color, tostring(_"Too many resources!"), tostring(sow_constants.sow_labels_new.players[side_number].name), tostring(_"lost"), res_to_lose, tostring(_"units of resources")), size=34, duration = 700 })
		wesnoth.synchronize_choice(function() wesnoth.play_sound("bell.wav") end)
		while resources.ressources > halfed_resources do
			wesnoth.set_variable("resources", resources); wesnoth.set_variable("halfed_resources", halfed_resources); wesnoth.set_variable("units_left", res_to_lose)
			wesnoth.fire_event("sow_too_many_resources_message")
			local chosen_resource = wesnoth.get_variable("chosen_resource")
			wesnoth.set_variable("chosen_resource"); wesnoth.set_variable("resources"); wesnoth.set_variable("halfed_resources"); wesnoth.set_variable("units_left")
			local amount = get_input_integer(math.min(resources[chosen_resource], res_to_lose), 0, resources[chosen_resource], side_number)
			resources[chosen_resource] = resources[chosen_resource] - amount
			resources.ressources = resources.ressources - amount
			res_to_lose = res_to_lose - amount
		end
		wesnoth.set_variable(variable, resources)
		update_displayed_numericals()
	end
	local_half_resources()
	if side_number == choosing_turn.stop_at_side then
		sow_end_robber(choosing_turn)
	else
		wml_actions.end_turn({})
	end
end

function sow_start_robber(player, x, y, random)
	local robber = wesnoth.get_units({ type = "sow_robber", {"or", { {"filter_wml", { {"variables", { type = "sow_robber" }} }} }} })[1]
	wesnoth.extract_unit(robber)
	robber.side = 9; robber.x = x; robber.y = y
	wesnoth.scroll_to_tile(x, y)
	sow_put_unit(robber)
	if not sow_era_is_used then sow_tools.teamcolorize_unit_image(robber) end
	wesnoth.play_sound("gold.ogg")
	wml_actions.redraw({})
	wesnoth.delay(250)

	local choosing_turn = { active = false, type = "half_resources", stop_at_side = player, {"specifications", { random = random, x = x, y = y }}}
	if robber.variables.half_resources then
		--This causes the roundtrip for resource halfings to be omitted if no side's resources need to be halfed
		for player, side_number in sow_tools.valid_player_range() do
			if helper.get_child(player, "ressources").ressources > sow_constants.halfing_limit then
				choosing_turn.active = true
				if not random then wml_actions.end_turn({}) end
				break
			end
		end
		robber.variables.half_resources = nil
	end
	wesnoth.set_variable("sow_game_stats.choosing_turn", choosing_turn)
	if not choosing_turn.active then sow_end_robber(choosing_turn) end
end

function sow_randomize_robber(player)
	local l = wesnoth.get_locations({ terrain = "Re^*,Dd^Do", {"not", { {"filter", { type = "sow_robber", {"or", { {"filter_wml", { {"variables", { type = "sow_robber" }} }} }} }} }} })
	local n = sow_tools.sow_random(#l)
	sow_start_robber(player, l[n][1], l[n][2], true)
end

--TODO: make local
function sow_activate_robber(player, half_resources)
	local u = wesnoth.get_units({ type = "sow_robber", {"or", { {"filter_wml", { {"variables", { type = "sow_robber" }} }} }} })[1]
	u.side = player
	if not sow_era_is_used then sow_tools.teamcolorize_unit_image(u) end
	wesnoth.scroll_to_tile(u.x, u.y)
	wml_actions.print({ text = string.format("<span color='%s'>%s %s!</span>", sow_constants.sow_labels_new.players[player].color, tostring(_"Robber activated by"), tostring(sow_constants.sow_labels_new.players[player].name)), size=34, duration = 700 })
	u.variables.half_resources = half_resources
	if sow_ai.is_ai(player) then sow_data.ais[player]:on_ai_activated_robber() end
end

-----------------------------------------------------------------------------------

-- Development Cards functions


local function sow_build_dev(player, inventory, total_dev_cards, dev_deck)
	if not check_required_resources(player, { grain = 1, wool = 1, ore = 1 }) then return sow_dialogs.result_type.back_to_game end

	local development = helper.get_child(inventory, "development")

	local settings = { speaker = "narrator", caption = _"Development Card", image = "icons/scroll_red.png" .. "~SCALE(120,120)", side_for = player}
	if total_dev_cards <= 0 then
		settings.message = _"The development cards' deck is empty, you cannot buy development cards anymore."
		wml_actions.message(settings)
		return sow_dialogs.result_type.back_to_game
	end

	local comparison_sum = 0
	local random = sow_tools.sow_random(total_dev_cards)
	local function get_card(type, message, image_name)
		local to_core = image_name == nil
		image_name = image_name or type
		development[type] = development[type] + 1
		dev_deck[type] = dev_deck[type] - 1
		settings.message = message
		if to_core then
			settings.image = sow_tools.custom_image_to_core(string.format("icons/%s.png", image_name)) .. "~SCALE(120,120)"
		else
			settings.image = string.format("%s.png", image_name) .. "~SCALE(120,120)"
		end
	end
	local function sum(type)
		comparison_sum = comparison_sum + dev_deck[type]
		return comparison_sum
	end
	local victory_check = false
	if random <= sum("victory") then
		get_card("victory", _"Recent developments in your settlements and cities earn you one victory point! You keep this card in your hand until the end of the game, when it is revealed. It counts towards the victory points goal at any time, even if it is not shown on your score.")
		victory_check = true
	elseif random <= sum("road") then
		get_card("road", _"Recent developments in your settlements and cities earn you a Build Road card, which you can use later to build two roads for free. This does not allow you to go over your 15 roads limit, and if you already topped it, this card is wasted on you.", "icons/crossed_sword_and_hammer")
	elseif random <= sum("plenty") then
		get_card("plenty", _"Recent developments in your settlements and cities earn you a Year of Plenty card, which you can use later to earn two resources of any kind.", "attacks/thorns")
	elseif random <= sum("monopoly") then
		get_card("monopoly", _"Recent developments in your settlements and cities earn you a Monopoly card, which you can use later to claim a single ressource type from all the other players.")
	elseif random <= sum("knight") then
		get_card("knight", _"Recent developments in your settlements and cities earn you a Knight card, which you can use later to move the robber, with everything it implies.", "icons/helmet_corinthian")
	end
	wml_actions.message(settings)
	settings.message = string.format(tostring(_"%s bought a Development Card."), tostring(sow_constants.sow_labels_new.players[player].name))
	settings.side_for = nil; settings.image = "icons/scroll_red.png" .. "~SCALE(120,120)"

	sow_tools.message(settings)
	wesnoth.set_variable(string.format("sow_game_stats.player[%u].development", player), development)
	wesnoth.set_variable("sow_game_stats.dev_deck", dev_deck)
	sow_ressource_manager(player, { grain = -1, wool = -1, ore = -1 })
	if victory_check then sow_victory_check(player) end
	return sow_dialogs.result_type.done
end


local function sow_use_dev(player, inventory, card, resources, development)
	local victory = helper.get_child(inventory, "victory")

	development[card] = development[card] - 1
	wesnoth.set_variable(string.format("sow_game_stats.player[%u].development", player), development)
	wesnoth.set_variable("sow_game_stats.dev_used", true)

	local settings = { speaker = "narrator", side_for = player }
	if card == "plenty" then
		local n = 2
		settings.caption = _"Development: Year of Plenty"; settings.image = "attacks/thorns.png" .. "~SCALE(120,120)"
		local res = { lumber = 0, grain = 0, wool = 0, brick = 0, ore = 0 }
		local choices, resource_table = choose_a_resource()
		while n > 0 do
			settings.message = string.format(tostring(_"Plentyful harvest allows you to claim two resource units.\nYou have %u more units to choose.\n%s\nWhat do you choose ?"), n, you_currently_have(resources))
			local result = resource_table[helper.get_user_choice(settings, choices)]
			resources[result] = resources[result] + 1
			res[result] = res[result] + 1
			n = n - 1
		end
		settings.side_for = nil
		settings.message = string.format(tostring(_"Plentyful harvest allowed %s to claim the following extra resources:"), tostring(sow_constants.sow_labels_new.players[player].name))
		for k, v in pairs (res) do
			if v == 0 then
				res[k] = nil
			else
				settings.message = settings.message .. string.format(tostring(_"\n\t%u units of %s;"), v, k)
			end
		end
		settings.message = settings.message:sub(1, settings.message:len() - 1)
		sow_tools.message(settings)
		sow_ressource_manager(player, res)

	elseif card == "monopoly" then
		settings.caption = _"Development: Monopoly"
		settings.message = string.format(tostring(_"What resource type will you have monopoly on?\n %s"), you_currently_have(resources))
		settings.image = sow_tools.custom_image_to_core("icons/monopoly.png") .. "~SCALE(120,120)"
		local choices, resource_table = choose_a_resource()
		local result = resource_table[helper.get_user_choice(settings, choices)]
		settings.side_for = nil
		settings.message = sow_tools.format(_"%s used a Monopoly development card and claimed:", sow_constants.sow_labels_new.players[player].name)

		for player_var, side_number in sow_tools.valid_player_range() do
			if side_number ~= player then
				local other_resources = helper.get_child(player_var, "ressources")
				if other_resources[result] > 0 then
					settings.message = sow_tools.format(_"%s\n\t%u units of %s from %s;", settings.message, other_resources[result], result, sow_constants.sow_labels_new.players[side_number].name)
					sow_ressource_manager(side_number, { [result] = -other_resources[result] })
					sow_ressource_manager(player, { [result] = other_resources[result] })
				end
			end
		end
		settings.message = settings.message:sub(1, settings.message:len() - 1)
		sow_tools.message(settings)

	elseif card == "road" then
		sow_tools.message({ speaker = "narrator", caption = _"Development: Road Building", message = sow_tools.format(_"%s used a Build Road development card, which allows him to place two free roads. This does not allow him to have more than 15 road units, however. Also, if he ends his turn before placing one or both roads, they will be lost.", sow_constants.sow_labels_new.players[player].name), image="icons/crossed_sword_and_hammer.png" .. "~SCALE(120,120)"})
		wesnoth.set_variable("sow_game_stats.free_road", 2)

	else --card == "knight"
		settings.caption = _"Development: Knight"
		victory.knight = victory.knight + 1
		settings.message = sow_tools.format(_"%s used a knight to move the robber.\n%s has used a total of %u Knights.", sow_constants.sow_labels_new.players[player].name, sow_constants.sow_labels_new.players[player].name, victory.knight)
		settings.image = "icons/helmet_corinthian.png" .. "~SCALE(120,120)"
		settings.side_for = nil
		local largest = wesnoth.get_units({ type = "sow_largest", {"or", { {"filter_wml", { {"variables", { type="sow_largest" }} }} }} })[1]

		local min_knights = 3
--~ 		if wesnoth.game_config.debug then min_knights = 1 end
		local keeps = (largest.side == player)
		local gets = keeps
		if not keeps and victory.knight >= min_knights then
			if largest.side == 9 then
				gets = true
			else
				gets = wesnoth.get_variable(string.format("sow_game_stats.player[%u].victory", largest.side)).knight < victory.knight
			end
		end
		local word = _"gets"
		if gets and not keeps then
			sow_victory_manager(player, { ["points"] = 2 })
			if largest.side ~= 9 then sow_victory_manager(largest.side, { ["points"] = -2 } ) end
			largest.side = player
			if not sow_era_is_used then sow_tools.teamcolorize_unit_image(largest) end
			sow_victory_check(player)
		elseif keeps then
			word = _"keeps"
		end
		sow_victory_manager(player, { ["knight"]  = 1 })
		if gets or keeps then
			settings.message = sow_tools.format(_"%s\n%s %s the Largest Army award, worth 2 victory points!", settings.message, sow_constants.sow_labels_new.players[player].name, word)
		end
		sow_tools.message(settings)
		sow_activate_robber(player, false)
	end
end

local function sow_menu_use_dev(player, inventory, resources, development, dev_tot, settings)
	if wesnoth.get_variable("sow_game_stats.dev_used") then
		settings.message = _"You already have used a development card this turn."
		wml_actions.message(settings)
		return sow_dialogs.result_type.back_to_game
	else
		while true do
			settings.message = string.format(tostring(_"You have a total of %u development cards. Which will you use ?"), dev_tot)
			local choices = {}
			local choices_key = {}
			local function insert(type, name, image_name)
				if development[type] == 0 then return end
				local to_core = image_name == nil
				image_name = image_name or type
				image_name = string.format("%s.png", image_name)
				if to_core then image_name = sow_tools.custom_image_to_core("icons/" .. image_name) end
				table.insert(choices, string.format("&" .. image_name .. "=<span weight='bold'>%s</span> (%u %s)", tostring(name), development[type], tostring(_"available")))
				table.insert(choices_key, type)
			end
			insert("victory", _"Victory Card")
			insert("road", _"Road Building Card", "icons/crossed_sword_and_hammer")
			insert("plenty", _"Year of Plenty Card", "attacks/thorns")
			insert("monopoly", _"Monopoly Card")
			insert("knight", _"Knight Card", "icons/helmet_corinthian")
			table.insert(choices, string.format("*&" .. sow_tools.custom_image_to_core("icons/back.png") .. "=<span weight='bold'>%s</span>", tostring(_"Back"))); table.insert(choices_key, "back")
			table.insert(choices, string.format("&" .. sow_tools.custom_image_to_core("icons/back.png") .. "=<span weight='bold'>%s</span>", tostring(_"Back to game"))); table.insert(choices_key, "back_to_game")
			local result = helper.get_user_choice (settings, choices)
			if choices_key[result] == "victory" then
				settings.message = _"Victory cards cannot be used. They are kept in your hand until you have enough victory points (counting them) to win the game, at which point they are revealed."
				settings.image = sow_tools.custom_image_to_core("icons/victory.png") .. "~SCALE(120,120)"
				wml_actions.message(settings)
				settings.image = "icons/scroll_red.png" .. "~SCALE(120,120)"
			elseif choices_key[result] == "back" then return sow_dialogs.result_type.back
			elseif choices_key[result] == "back_to_game" then return sow_dialogs.result_type.back_to_game
			else
				sow_use_dev(player, inventory, choices_key[result], resources, development)
				return sow_dialogs.result_type.done
			end
		end
	end
end

function sow_menu_dev(player)
	while true do
		local inventory = wesnoth.get_variable(string.format("sow_game_stats.player[%i]", player))
		local resources = helper.get_child(inventory, "ressources")
		local development = helper.get_child(inventory, "development")
		local dev_deck = wesnoth.get_variable("sow_game_stats.dev_deck")
		local total_dev_cards = 0
		for k, v in pairs(dev_deck) do total_dev_cards = total_dev_cards + v end

		local dev_tot = development.victory + development.knight + development.monopoly + development.plenty + development.road
		local settings = { speaker = "narrator", caption = _"Development Cards", image = "icons/scroll_red.png" .. "~SCALE(120,120)", side_for = player }
		settings.message = you_currently_have(resources)
		local choices = {}
		table.insert(choices, string.format("&icons/scroll_red.png" .. "=%s<span weight='bold'> (%u %s)</span>", tostring(_"Use Development Card"), dev_tot, tostring(_"available")))
		table.insert(choices, string.format("&icons/coins_copper.png=<span weight='bold'>%s (%u %s)</span>", tostring(_"Buy Development Card (G, W, O)"), total_dev_cards, tostring(_"available")))
		table.insert(choices, string.format("*&" .. sow_tools.custom_image_to_core("icons/back.png") .. "=<span weight='bold'>%s</span>", tostring(_"Back to game")))
		local result = helper.get_user_choice(settings, choices)

		local dialog_result
		if result == 1 then -- Use Dev Card Menu
			dialog_result = sow_menu_use_dev(player, inventory, resources, development, dev_tot, settings)
		elseif result == 2 then -- Buy Dev Card
			dialog_result = sow_build_dev(player, inventory, total_dev_cards, dev_deck)
		else return
		end
		if dialog_result == sow_dialogs.result_type.back then
		elseif dialog_result == sow_dialogs.result_type.back_to_game then return
		elseif dialog_result == sow_dialogs.result_type.done then break
		end
	end --end while true do
	update_displayed_numericals()
end

-----------------------------------------------------------------------------------

-- Trade functions

local function sow_end_trade(choosing_turn)
	if not helper.get_child(choosing_turn, "specifications").accepted then
		local settings = { speaker = "narrator", image = "icons/coins_copper.png~SCALE(120,120)", caption = _"Domestic Trade",
			message = string.format("%s %s...", tostring(_"Nobody wished to or could accept the trade offer by"), tostring(sow_constants.sow_labels_new.players[choosing_turn.stop_at_side].name))
		}
		sow_tools.message(settings)
	end
	choosing_turn = { active = false, type = nil, stop_at_side = 0, {"specifications", { }} }
	wesnoth.set_variable("sow_game_stats.choosing_turn", choosing_turn)
end

local function changes_to_offer_and_demand(changes)
	local offer = {}
	local demand = {}
	for k, v in pairs(changes) do
		if v > 0 then
			offer[k] = 0
			demand[k] = v
		elseif v == 0 then
			offer[k] = 0
			demand[k] = 0
		else
			offer[k] = -1 * v
			demand[k] = 0
		end
	end
	return offer, demand
end

function sow_continue_trade(side_number)
	local choosing_turn = wesnoth.get_variable("sow_game_stats.choosing_turn")
	if choosing_turn.stop_at_side == side_number then
		sow_end_trade(choosing_turn)
		return
	end
	local specifications = helper.get_child(choosing_turn, "specifications")
	local changes = helper.get_child(specifications, "changes")
	local offer, demand = changes_to_offer_and_demand(changes)

	local resources =  wesnoth.get_variable(string.format("sow_game_stats.player[%u].ressources", side_number))
	if specifications.accepted or not sow_tools.swap_table(sow_tools.split(tostring(specifications.target_sides)))[tostring(side_number)] or not check_required_resources(side_number, demand, false) or sow_ai.is_ai(side_number) then
		wml_actions.end_turn({})
		return
	end

	local settings = { speaker = "narrator", image = "icons/coins_copper.png~SCALE(120,120)", caption = sow_tools.format(_"Domestic Trade between %s and %s", sow_constants.sow_labels_new .players[choosing_turn.stop_at_side].name, sow_constants.sow_labels_new .players[side_number].name),
		message = string.format("%s\n%s\n%s", you_currently_have(resources), you_currently_have(offer, _"You are offered:"), you_currently_have(demand, _"You are demanded:")), sound = "bell.wav"
		}
	local result = helper.get_user_choice(settings, { _"*&icons/coins_copper.png~SCALE(30,30)=Accept Trade", string.format("&" .. sow_tools.custom_image_to_core("icons/back.png") .. "~SCALE(30,30)=" .. tostring(_"Refuse Trade"))})
	settings.sound = nil
	if result == 1 then
		settings.message = sow_tools.format(_"<span weight='bold'>%s accepted the following deal offered by %s:</span>", sow_constants.sow_labels_new .players[side_number].name, sow_constants.sow_labels_new .players[choosing_turn.stop_at_side].name)
		for k, v in pairs(offer) do
			if v > 0 then
				settings.message = sow_tools.format(_"%s\n\t%u units of %s", settings.message, v, translatable_resources[k])
			end
		end
		settings.message = settings.message .. tostring(_"\nwas offered and")
		for k, v in pairs(demand) do
			if v > 0 then
				settings.message = sow_tools.format(_"%s\n\t%u units of %s", settings.message, v, translatable_resources[k])
			end
		end
		settings.message = settings.message .. tostring(_"\nwas demanded.")
		sow_tools.message(settings)
		specifications.accepted = true
		wesnoth.set_variable("sow_game_stats.choosing_turn", choosing_turn)
		sow_ressource_manager(choosing_turn.stop_at_side, changes)
		sow_ressource_manager(side_number, changes, true)
		update_displayed_numericals()
	end
	wml_actions.end_turn({})
end

local function sow_start_trade(player)
	local offers_left = wesnoth.get_variable("sow_game_stats.trade_offers_left")
	local settings = { speaker = "narrator", image = "icons/coins_copper.png" .. "~SCALE(120,120)", side_for = player, caption = _"Domestic Trade" }
	if offers_left == 0 then
		settings.message = _"You have reached the maximum number of trade offers per turn, domestic trade unavailable until your next turn!"
		wml_actions.message(settings)
		return sow_dialogs.result_type.back
	end

	local resources = wesnoth.get_variable(string.format("sow_game_stats.player[%u].ressources", player))
	resources.resources = resources.ressources
	resources.ressources = nil
	local changes = { lumber = 0, grain = 0, wool = 0, brick = 0, ore = 0, resources = 0 }
	local target_sides = ""
	for team, side_number in sow_tools.valid_player_range() do
		if side_number ~= player then
			if target_sides ~= "" then
				target_sides = target_sides .. ","
			end
			target_sides = target_sides .. tostring(side_number)
		end
	end
	local chosen_sides = target_sides

	while true do
		local result = sow_dialogs.domestic_trade(resources, changes, target_sides, chosen_sides)
		changes = helper.get_child(result, "changes")
		chosen_sides = result.chosen_sides
		if result.return_value == sow_dialogs.result_type.done then
			local function trade_ok(t)
				local demand = false
				local offer = false
				for k, v in pairs(t) do
					if not demand and v > 0 then demand = true
					elseif not offer and v < 0 then offer = true
					end
					if demand and offer then return true end
				end
				return false
			end
			if trade_ok(changes) then break
			else
				local result = sow_dialogs.confirm(_"Your offer/demand arrangement doesn't seem ready yet, do you really wish to continue ?")
				if result == sow_dialogs.result_type.done then
					break
				elseif result == sow_dialogs.result_type.back_to_game then
					return sow_dialogs.result_type.back_to_game
				end
			end
		else
			return result.return_value
		end
	end
	offers_left = offers_left - 1
	wesnoth.set_variable("sow_game_stats.trade_offers_left", offers_left)
	changes.resources = nil
	local choosing_turn = { active = true, type = "domestic_trade", stop_at_side = player, {"specifications", {
		target_sides = chosen_sides, accepted = false, { "changes", changes }
	}} }
	wesnoth.set_variable("sow_game_stats.choosing_turn", choosing_turn)
	wml_actions.end_turn({ })
	return sow_dialogs.result_type.done
end

local function sow_trade_overseas(player)
	while true do
		local inventory = wesnoth.get_variable(string.format("sow_game_stats.player[%u]", player) )
		local resources = helper.get_child(inventory, "ressources"); resources.ressources = nil
		local ports = { any = false, lumber = false, grain = false, wool = false, brick = false, ore = false }
		local filter = { side=player, type = "sow_any,sow_lumber,sow_grain,sow_wool,sow_brick,sow_ore"}
		if not sow_era_is_used then
			filter.type = nil
			table.insert(filter, {"filter_wml", { {"variables", { port = true }} }})
		end
		for i, v in ipairs(wesnoth.get_units(filter) ) do
			if sow_era_is_used then
				ports[string.gsub(v.type, "sow_", "")] = true
			else
				ports[string.gsub(v.variables.type, "sow_", "")] = true
			end
		end

		-- Choosing what to trade
		local settings = { speaker = "narrator", image = "icons/coins_copper.png~SCALE(120,120)", caption = tostring(_"Trade Overseas")}
		settings.message = string.format(tostring(_"<span weight='bold'>What will you trade ?\n</span>%s"), you_currently_have(resources))
		local choices = {}
		local offer = {}
		for k, v in pairs(resources) do
			--TODO: k not translatable
			local function insert(number)
				table.insert(choices, string.format("&" .. sow_tools.custom_image_to_core(string.format("icons/%s.png", k)) .. "~SCALE(30,30)=%u %s %s", number, tostring(_"units of"), k))
				table.insert(offer, { resource = k, amount = number })
			end
			if ports[k] == true and v >= 2 then insert(2)
			elseif ports.any == true and v >= 3 then insert(3)
			elseif v >= 4 then insert(4)
			end
		end
		table.insert(choices, string.format("*&" .. sow_tools.custom_image_to_core("icons/back.png") .. "~SCALE(30,30)=%s", tostring(_"Back"))); table.insert(offer, "back")
		table.insert(choices, string.format("&" .. sow_tools.custom_image_to_core("icons/back.png") .. "~SCALE(30,30)=%s", tostring(_"Back to game"))); table.insert(offer, "back_to_game")
		local key_a = helper.get_user_choice(settings, choices)
		if offer[key_a]  == "back" then return sow_dialogs.result_type.back
		elseif offer[key_a]  == "back_to_game" then return sow_dialogs.result_type.back_to_game
		end

		-- Choosing what to get in exchange
		--TODO offer[key_a].resource not translatable
		settings.message = string.format(tostring(_"<span weight='bold'>What will you take in exchange ?\nYou are offering:</span>\n\t%u units of %s\n%s"), offer[key_a].amount, offer[key_a].resource, you_currently_have(resources))
		choices = {}
		local function insert(translatable_string, resource)
			table.insert(choices, string.format("&" .. sow_tools.custom_image_to_core(string.format("icons/%s.png", resource)) .. "~SCALE(30,30)=%s", tostring(translatable_string)))
		end
		insert(_"A unit of Lumber", "lumber")
		insert(_"A unit of Grain", "grain")
		insert(_"A unit of Wool", "wool")
		insert(_"A unit of Brick", "brick")
		insert(_"A unit of Ore", "ore")
		insert(_"Change my offer", "back")
		insert(_"Back to game", "back")
		local trade = {"lumber", "grain", "wool", "brick", "ore"}
		local key_b = helper.get_user_choice(settings, choices)
		if key_b <= 5 then
			settings.message = string.format(tostring(_"%s traded %u units of %s overseas in exchange for a unit of %s."), tostring(sow_constants.sow_labels_new.players[player].name), offer[key_a].amount, offer[key_a].resource, trade[key_b])
			sow_tools.message(settings)
			local res = {}
			res[offer[key_a].resource] = - offer[key_a].amount; res[trade[key_b]] = 1
			sow_ressource_manager(player, res)
			return sow_dialogs.result_type.done
		elseif key_b == 6 then
		elseif key_b == 7 then
			return sow_dialogs.result_type.back_to_game
		else assert(false)
		end
	end
end

function sow_menu_trade(player)
	while true do
		local inventory = wesnoth.get_variable(string.format("sow_game_stats.player[%u]", player) )
		local resources = helper.get_child(inventory, "ressources")
		local settings = { speaker = "narrator", image = "icons/coins_copper.png~SCALE(120,120)", caption = _"Trade" }
		settings.message = string.format(tostring(_"Select what trade type you want to engage in?\n%s"), you_currently_have(resources))
		local choices = { string.format("&icons/coins_copper.png=%s", tostring(_"Domestic trade (with other players)")), string.format("*&icons/coins_copper.png=%s", tostring(_"Trade overseas (with the bank)")), string.format("*&%s=%s", sow_tools.custom_image_to_core("icons/back.png"), tostring(_"Back to game"))}
		local result = helper.get_user_choice(settings, choices)
		local dialog_result
		if result == 1 then
			dialog_result = sow_start_trade(player)
		elseif result == 2 then
			dialog_result = sow_trade_overseas(player)
		else
			return
		end
		if dialog_result == sow_dialogs.result_type.back then
		elseif dialog_result == sow_dialogs.result_type.back_to_game then return
		elseif dialog_result == sow_dialogs.result_type.done then break
		else assert(false)
		end
	end
	update_displayed_numericals()
end

-----------------------------------------------------------------------------------

-- Functions to initiate a new side-turn

function sow_new_side_turn(player)
	--sow_game_stats.dev_used controls that in every turn a player can use at max 1 dev card; set it back when next player starts
	wesnoth.set_variable("sow_game_stats.dev_used", false)
	wesnoth.set_variable("sow_game_stats.free_road", 0)
	wesnoth.set_variable("sow_game_stats.trade_offers_left", max_trade_offers)

	local roll_a = sow_tools.sow_random(6)
	local roll_b = sow_tools.sow_random(6)
	local roll_tot = roll_a + roll_b
	if sow_era_is_used then wesnoth.play_sound("roll.wav") end
	wml_actions.print({ text = string.format("%i + %i = %i", roll_a, roll_b, roll_tot), size=34, red=200, green=200, blue=200, duration = 700 })
	wesnoth.delay(500)

	local roll_letter = { false, "Re^Ya", "Re^Yb", "Re^Yc", "Re^Yd", "Re^Ye", false, "Re^Yf", "Re^Yg", "Re^Yh", "Re^Yi", "Re^Yj" }
	if roll_tot == 7 then
		sow_activate_robber(player, true)
	else
		for i,loc in ipairs(wesnoth.get_locations({ terrain = sow_tools.custom_terrain_to_core(roll_letter[roll_tot]), {"not", { {"filter", { type = "sow_robber", {"or", { {"filter_wml", { {"variables", { type = "sow_robber" }} }} }} }} }} })) do
			local l = wesnoth.get_locations({ {"filter_adjacent_location", { x = loc[1], y = loc[2]}} })[1]
			local resource = resource_letter[wesnoth.get_terrain(l[1], l[2])]
			local filter = { type = "sow_city, sow_settle", {"filter_location", { x = loc[1], y = loc[2], radius=2 }} }
			if not sow_era_is_used then
				filter.type = nil
				table.insert(filter, {"filter_wml", { {"variables", { building = true }} }})
			end
			local t = wesnoth.get_units(filter)
			if t then
				for i,target in ipairs(t) do
-- 					if wesnoth.get_variable(string.format("sow_game_stats.player[%u].valid", target.side)) then
						local to_give = {}
						to_give[resource] = target.hitpoints
						sow_ressource_manager(target.side, to_give)
						animate_resources_change(target.side, target.x, target.y, "gold.ogg", string.format("+ %i %s", target.hitpoints, resource))
-- 					end
				end
			end
		end
		update_displayed_numericals()
	end
end

-----------------------------------------------------------------------------------

function sow_set_goal()
	local settings = { speaker = "narrator", image = sow_tools.custom_image_to_core("icons/victory.png") .. "~SCALE(120,120)", caption = tostring(_"Set Game Length"),
		message = _"Please select the game's length (the amount of victory points to win; the default value is 10). If you have no idea, just choose that."}

		local choices = {}
		table.insert(choices, _"Very Short (6 Victory Points)")
		table.insert(choices, _"Short (8 Victory Points)")
		table.insert(choices, _"*Medium (10 Victory Points)")
		table.insert(choices, _"Long (12 Victory Points)")
		table.insert(choices, _"Very Long (14 Victory Points)")
		table.insert(choices, _"Infinite (The game is not automatically ended - there will never be a winner.)")
		table.insert(choices, _"turn limited (The game ends after given turn, player with most victory points wins.)")
		table.insert(choices, _"Enter Manually")
		local result = helper.get_user_choice(settings, choices)
		local goal = 6
		local side_number = wesnoth.get_variable("side_number")
		if result <= 5 then
			goal = goal + (result - 1) * 2
		elseif result == 6 then
			goal = sow_constants.MAX_UNSIGNED
		elseif result == 7 then
			goal = sow_constants.MAX_UNSIGNED
			local leading_player = wesnoth.get_variable("sow_game_stats.leading_player")
			leading_player.limit = get_input_integer(30, 1, sow_constants.MAX_UNSIGNED, side_number)
			leading_player.active = leading_player.limit > 0
			wesnoth.set_variable("sow_game_stats.leading_player", leading_player)
		else
			goal = get_input_integer(10, 1, sow_constants.MAX_UNSIGNED, side_number)
		end
		wesnoth.set_variable("sow_game_stats.goal", goal)
end

--this is to disable the annoying "you didn't yet move any unit - really end your turn ? - dialog"
function sow_disable_turn_done_confirm(side_number)
	local leader = wesnoth.get_units({ side = side_number, canrecruit = true })[1]
	if leader then leader.moves = 0 end
end

-----------------------------------------------------------------------------------

-- Function to update score and check for victory
--TODO: this function doesn't need to be global; it's only called by sow_build_road
function sow_getting_path_length(player, start, length, seen_ids, temp_ignore)
	if seen_ids then seen_ids = string.format("%s,%s", start.id, seen_ids) else seen_ids = start.id end
	local actual_length = 1 + length
	local best_length = actual_length
	local filter = { type="sow_roadn,sow_roadne,sow_roadnw", side = player, {"not", { id = string.format("%s,%s", seen_ids, temp_ignore) }}, {"filter_location", { {"and", { radius = 2, {"filter", { id = start.id }} }} }} }
	if not sow_era_is_used then
		filter.type = nil
		table.insert(filter, {"filter_wml", { {"variables", { road = true }} }})
	end
	local next_road = wesnoth.get_units(filter)
	--This deletes those next roads cut off by an enemy settle/city
--~ 	local interupters = wesnoth.get_units({ type = "sow_settle,sow_city", {"not", { side = player }}, {"filter_adjacent", { id = start.id }} })
--~ 	for i, interupter in ipairs(interupters) do
--~ 		for i, road in ipairs(next_road) do
--~ 			dbms({"have_unit", { id = road.id, {"filter_adjacent", { id = interupter.id }} }})
--~ 			if wesnoth.eval_conditional({ {"have_unit", { id = road.id, {"filter_adjacent", { id = interupter.id }} }} }) then
--~ 				next_road[i] = nil
--~ 			end
--~ 		end
--~ 	end
--~ 	if interupters[1] then next_road = sow_tools.remove_empty_table_indices(next_road) end

	local temp_ignore = start.id
	for i, v in ipairs(next_road) do
		temp_ignore = string.format("%s,%s", v.id, temp_ignore)
	end
	for i, v in ipairs(next_road) do
		best_length = math.max(best_length, sow_getting_path_length(player, v, actual_length, seen_ids, temp_ignore))
	end
	return best_length
end

function sow_victory_check(player, force)
	local goal = wesnoth.get_variable("sow_game_stats.goal")
	local leading_player = wesnoth.get_variable("sow_game_stats.leading_player")
	local inventory = wesnoth.get_variable(string.format("sow_game_stats.player[%u]", player))
	local development = helper.get_child(inventory, "development")
	local victory = helper.get_child(inventory, "victory")

	local filter = { type = "sow_settle", side = player }
	if not sow_era_is_used then
		filter.type = nil
		table.insert(filter, {"filter_wml", { {"variables", { type = "sow_settle" }} }})
	end
	local settlements = wesnoth.get_units(filter)
	filter = { type = "sow_city", side = player }
	if not sow_era_is_used then
		filter.type = nil
		table.insert(filter, {"filter_wml", { {"variables", { type = "sow_city" }} }})
	end
	local cities = wesnoth.get_units(filter)
	local largest = 0
	local longest = 0
	local largest_filter = { type = "sow_largest", side = player}
	local longest_filter = { type = "sow_longest", side = player}
	if not sow_era_is_used then
		largest_filter.type = nil
		longest_filter.type = nil
		table.insert(largest_filter, {"filter_wml", { {"variables", { type = "sow_largest" }} }})
		table.insert(longest_filter, {"filter_wml", { {"variables", { type = "sow_longest" }} }})
	end
	if wesnoth.get_units(largest_filter)[1] then largest = 2 end
	if wesnoth.get_units(longest_filter)[1] then longest = 2 end

	victory.points = #settlements + #cities * 2 + largest + longest
	wesnoth.set_variable(string.format("sow_game_stats.player[%i]", player), inventory)
	if not force then
		if leading_player.active then
			local points = victory.points + development.victory
			if leading_player.points < points then
				leading_player.side = player
				leading_player.points = points
				wesnoth.set_variable("sow_game_stats.leading_player", leading_player)
			end
		end
	end

	if victory.points + development.victory >= goal or force then
		--TODO: the message needs to be translatable
		local settings = { speaker = "narrator", caption = _"Victory!", image = sow_tools.custom_image_to_core("icons/victory.png") .. "~SCALE(120,120)",
			message = string.format(tostring(_"<span weight='bold'>%s wins the game with %i points!</span>\n\n<span weight='bold'>Settlements : </span>%i (%i victory points)\n<span weight='bold'>Cities : </span>%i (%i victory points)\n<span weight='bold'>Victory Development Cards : </span>%i (%i victory points)"), tostring(sow_constants.sow_labels_new.players[player].name), victory.points + development.victory, #settlements, #settlements, #cities, #cities * 2, development.victory, development.victory)}
		if longest > 0 then settings.message = settings.message .. string.format(tostring(_"\n<span weight='bold'>Longest Road : </span>%i units long (%i victory points)"), victory.road, longest) end
		if largest > 0 then settings.message = settings.message .. string.format(tostring(_"\n<span weight='bold'>Largest Army : </span>%i knights used (%i victory points)"), victory.knight, largest) end
		wml_actions.message(settings)
		wml_actions.kill({ canrecruit = true, { "not", { side = player }} })
		wml_actions.end_turn({})
	end
end

---------------------------------------------------------------------------

function sow_new_ai_turn(side_number, turn_number)
-- 	if sow_ai.is_ai(side_number) then sow_data.ais[side_number]:new_ai_turn(turn_number) end
end

function sow_set_reverse_turn_side_numbers()
	local side_numbers = {}
	local k = 1
	for i = #wesnoth.sides - 1, 1, -1 do
		if wesnoth.sides[i].controller ~= "null" then
			table.insert(side_numbers, { number = i })
		end
	end
	helper.set_variable_array("sow_reverse_turn_side_numbers", side_numbers)
end

-- local on_save = wesnoth.game_events.on_save
-- function wesnoth.game_events.on_save()
-- 	local cfg = on_save()
-- 	sow_data.on_save()
-- 	return cfg
-- end

