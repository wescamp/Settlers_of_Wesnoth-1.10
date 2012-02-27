if not wesnoth then
	package.path = package.path .. ";C:/WesnothTrunk/data/lua/?.lua"
	wesnoth = require("wesnoth")
end

local data = {}

data.miscellaneous =
{
	development_card_used = false,
	free_roads = 0,
	victory_points_needed = 10,
	trade_offers_left = max_trade_offers,
}
data.choosing_turn =
{
	active = false,
	stop_at_side = 0,
	type = nil,
	specifications = {}
}
data.a_player =
{
	valid = true,
	resources =
	{
		lumber = 4,
		grain = 2,
		wool = 2,
		brick = 4,
		ore = 0,
		resources = 12
	},
	development =
	{
		knight = 0,
		monopoly = 0,
		plenty = 0,
		road = 0,
		victory = 0,
		development = 0
	},
	victory =
	{
		road = 0,
		knight = 0,
		victory = 0
	}
}
data.player = {}
data.development_cards_deck =
{
	knight = 0,
	monopoly = 0,
	plenty = 0,
	road = 0,
	victory = 0
}
data.ais = {}


function data.of_wml_var()
	local saved = wesnoth.get_variable("sow_data")
	for i = 1, #wesnoth.sides do
		table.insert(data.ais, sow_ai.of_wml_var(i))
	end
	if saved then
		data.miscellaneous = helper.get_child(saved, "miscellaneous")
		data.choosing_turn = sow_tools.convert_from_wml_table(helper.get_child(saved, "choosing_turn"))
		data.development_cards_deck = helper.get_child(saved, "development_cards_deck")
		for player in helper.child_range(saved, "player") do
			table.insert(data.player, player)
		end
	end
end
data.of_wml_var()

function data.valid_player_range()

end

function data.on_save()
	wesnoth.set_variable("sow_data.miscellaneous", data.miscellaneous)
	wesnoth.set_variable("sow_data.choosing_turn", sow_tools.convert_to_wml_table(data.choosing_turn))
	wesnoth.set_variable("sow_data.development_cards_deck", data.development_cards_deck)
	for i = 1, #wesnoth.sides do
		wesnoth.set_variable(string.format("sow_data.player[%u]", i - 1), sow_tools.convert_to_wml_table(data.player[i]))
	end
	for i, v in ipairs(data.ais) do
		v:on_save()
	end
end


local renamings =
{
	dev_used = "development_card_used",
	free_road = "free_roads",
	goal = "victory_points_needed",
	ressources = "resources",
	points = "victory"
}

function data.of_sow_game_stats()
	local sow_game_stats = wesnoth.get_variable("sow_game_stats")
	local function rename(arg_table)
		for k, v in pairs(arg_table) do
			if renamings[k] then
				arg_table[renamings[k]] = v
				arg_table[k] = nil
			end
			if v == "ressources" then
				arg_table[1] = "resources"
			end
			if type(v) == "table" then rename(arg_table[k]) end
		end
	end
	rename(sow_game_stats)

	data.miscellaneous.development_card_used = sow_game_stats.development_card_used
	data.miscellaneous.free_roads = sow_game_stats.free_roads
	data.miscellaneous.victory_points_needed = sow_game_stats.victory_points_needed
	data.miscellaneous.trade_offers_left = sow_game_stats.trade_offers_left

	data.choosing_turn = helper.get_child(sow_game_stats, "choosing_turn")
	data.development_cards_deck = helper.get_child(sow_game_stats, "dev_deck")

	local i = 0
	for player in helper.child_range(sow_game_stats, "player") do
		if i ~= 0 then
			local development = helper.get_child(player, "development")
			if development then
				local sum = 0
				for k, v in pairs(development) do
					sum = sum + v
				end
				development.development = sum
			end
			data.player[i] = sow_tools.convert_from_wml_table(player)
		end
		i = i + 1
	end
end

function data.to_sow_game_stats()
	local sow_data = helper.deep_copy(sow_data)
	dbms(sow_data)
	local function rename(arg_table)
		local renamings = sow_tools.swap_table(renamings)
		for k, v in pairs(arg_table) do
			if type(v) == "table" then rename(arg_table[k]) end
			if renamings[k] then
				arg_table[renamings[k]] = v
				arg_table[k] = nil
			end
			if k == "resources" then
				arg_table.ressources = v
				arg_table.resources = nil
			end
		end
	end
	rename(sow_data)
	dbms(sow_data)

	wesnoth.set_variable("sow_game_stats.dev_used", sow_data.miscellaneous.dev_used)
	wesnoth.set_variable("sow_game_stats.free_road", sow_data.miscellaneous.free_road)
	wesnoth.set_variable("sow_game_stats.goal", sow_data.miscellaneous.goal)
	wesnoth.set_variable("sow_game_stats.trade_offers_left", sow_data.miscellaneous.trade_offers_left)

	wesnoth.set_variable("sow_game_stats.choosing_turn", sow_tools.convert_to_wml_table(sow_data.choosing_turn))
	wesnoth.set_variable("sow_game_stats.dev_deck", sow_data.development_cards_deck)
	for i = 1, #wesnoth.sides do
		sow_data.player[i].development.development = nil
		wesnoth.set_variable(string.format("sow_game_stats.player[%u]", i), sow_tools.convert_to_wml_table(sow_data.player[i]))
	end
end

return data
