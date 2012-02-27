if not helper then
	helper = {}
	function helper.shallow_copy() end
end

local sow_ai = {}

--terrain_weights is a constant, port_weights and resource_weights are variable
local terrain_weights = { ["Re^Ya"] = 1, ["Re^Yb"] = 2, ["Re^Yc"] = 3, ["Re^Yd"] = 4, ["Re^Ye"] = 5, ["Re^Yf"] = 5, ["Re^Yg"] = 4, ["Re^Yh"] = 3, ["Re^Yi"] = 2, ["Re^Yj"] = 1}
local port_weights = { sow_any = 6, sow_lumber = 3, sow_grain = 3, sow_wool = 3, sow_brick = 3, sow_ore = 3 }
local resource_weights = { lumber = 1, grain = 0, wool = 0, brick = 1.5, ore = 0 }
local number_terrains = ""
for k, v in pairs(terrain_weights) do
	number_terrains = string.format("%s%s,", number_terrains, k)
end
number_terrains = number_terrains:sub(1, number_terrains:len() - 1)

function sow_ai.is_ai(side_number)
	if not wesnoth.game_config.debug then return false end
	return wesnoth.sides[side_number].controller == "ai" or wesnoth.sides[side_number].controller == "human_ai"
end

local methods = {}
local sow_ai_meta = { __index = methods }
function methods:calc_settle_pos_weight(position)
	local filter = { terrain = number_terrains, {"or", { {"filter", { type = "sow_any,sow_lumber,sow_grain,sow_wool,sow_brick,sow_ore" }} }}, {"and", { x = position[1], y = position[2], radius = 2 }} }
	local numbers_and_ports = wesnoth.get_locations(filter)
	local weight = 0
	for i, v in ipairs(numbers_and_ports) do
		local port = wesnoth.get_units({ x = v[1], y = v[2] })[1]
		if port then weight = weight + self.port_weights[port.type]
		else
			local number = wesnoth.get_terrain(v[1], v[2])
			weight = weight + terrain_weights[number]
			local terrain = wesnoth.get_terrain(v[1], v[2] - 1)
			weight = weight + self.resource_weights[resource_letter[terrain]]
		end
	end
	return weight
end

function methods:get_settle_pos(needs_road)
	local filter = { terrain = "Rrc", {"not", { {"filter",{}} }}, {"not", { {"filter", { type = "sow_settle, sow_city" }}, radius = 2 }} }
	if needs_road then
		table.insert(filter, {"filter_adjacent_location", { {"filter", { side_number = side_number, type = "sow_roadn,sow_roadne,sow_roadnw" }} }})
	end
	local positions = wesnoth.get_locations(filter)
	local best_choice = 1
	for i, v in pairs(positions) do
		v.weight = self:calc_settle_pos_weight(v)
		if v.weight > positions[best_choice].weight then best_choice = i end
	end
	positions[best_choice].weight = nil
	return positions[best_choice]
end

function methods:recalc_weights(new_position)
	local ports = wesnoth.get_units({ side = self.side_number, type = "sow_any, sow_lumber, sow_grain, sow_wool, sow_brick, sow_ore"})
	for i, port in ipairs(ports) do
		if port.side == self.side_number then self.port_weights[port.type] = 0 end
	end

	local building = wesnoth.get_units({ x = new_position[1], y = new_position[2] })[1]
	local type = building.type
	local function calc_for_buildings(city)
		city = city or 1
		local numbers = wesnoth.get_locations({ terrain = number_terrains, {"and", { x = new_position[1], y = new_position[2], radius = 2 }} })
		for i, number in ipairs(numbers) do
			local terrain = wesnoth.get_terrain(number[1], number[2] - 1)
			local modification = 0.4 * terrain_weights[wesnoth.get_terrain(number[1], number[2])] * city
			self.resource_weights[resource_letter[terrain]] = self.resource_weights[resource_letter[terrain]] - modification
			for k, v in pairs(self.resource_weights) do
				if k ~= resource_letter[terrain] then
					self.resource_weights[k] = self.resource_weights[k] + modification / 4
				end
			end
		end
	end
	if type == "sow_settle" then
		calc_for_buildings()
	else
		calc_for_buildings(2)
	end
end

function methods:calc_road_pos_weight(position)



	return position[1]
end


function methods:get_road_pos(all_choices)
	local best_choice = 1
	for i, v in ipairs(all_choices) do
		v.weight = self:calc_road_pos_weight(v)
		if v.weight > all_choices[best_choice].weight then best_choice = i end
	end
	all_choices[best_choice].weight = nil
	return all_choices[best_choice]
end

function methods:build_adjacent_road(position)
	local possible = wesnoth.get_locations({ terrain ="Rz*", {"not", { {"filter",{}} }}, {"filter_adjacent_location", { x = position[1], y = position[2] }} })
	local position = self:get_road_pos(possible)
	sow_build_road(self.side_number, position[1], position[2])
end

function methods:build_road()
	local possible = wesnoth.get_locations({ terrain ="Rz*", {"not", { {"filter",{}} }}, {"and", { radius = 2, {"filter", { type = "sow_roadn,sow_roadne,sow_roadnw", side = self.side_number }} }} })
	local position = self:get_road_pos(possible)
	sow_build_road(self.side_number, position[1], position[2])
end

function methods:decide_action()

end


function methods:sow_half_ai_resources()

end

function methods.new_ai_turn(self, turn_number)
	if turn_number == 1 then
		local position = self:get_settle_pos(false)
		sow_build_settle(self.side_number, position[1], position[2])
		self:build_adjacent_road(position)
		return
	end
	if turn_number == 2 then
		local position = self:get_settle_pos(false)
		sow_build_second_settle(self.side_number, position[1], position[2])
		self:build_adjacent_road(position)
		return
	end

	self:build_road()
end

function methods:on_ai_activated_robber()

end

-----------------------------------------------
function methods:on_save()
	wesnoth.set_variable(string.format("sow_data.sow_ai[%u]", self.side_number - 1),
		{
			{"resource_weights", self.resource_weights },
			{"port_weights", self.port_weights }
		})
end

function sow_ai.create(side_number)
	return setmetatable(
	{
		port_weights = helper.shallow_copy(port_weights),
		resource_weights = helper.shallow_copy(resource_weights),
		side_number = side_number
	},
	sow_ai_meta)
end

function sow_ai.of_wml_var(side_number)
	local sow_ai = sow_ai.create(side_number)
	local saved = wesnoth.get_variable(string.format("sow_data"))
	if saved then
		saved = wesnoth.get_variable(string.format("sow_data.sow_ai[%u]", side_number - 1))
		sow_ai.resource_weights = helper.get_child(saved, "resource_weights")
		sow_ai.port_weights = helper.get_child(saved, "port_weights")
	end
	return sow_ai
end

return sow_ai
