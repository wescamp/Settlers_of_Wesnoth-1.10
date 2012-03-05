if not wesnoth then
	package.path = package.path .. ";../../../../../data/lua/?.lua"
	wesnoth = require("wesnoth")
end
local _ = wesnoth.textdomain("wesnoth-Settlers_of_Wesnoth")

local wml_actions = wesnoth.wml_actions

local function version_checker(actual, operator, required)
	local function version_is_sufficient()
		if not wesnoth.compare_versions then return false end
		return wesnoth.compare_versions(actual, operator, required)
	end
	local sync = function()
		return { sufficient = version_is_sufficient() }
	end
	return wesnoth.synchronize_choice(sync).sufficient
end
function wml_actions.check_version(cfg)
-- 	wesnoth.message("check_version: " .. tostring(version_checker(wesnoth.game_config.version, ">=", cfg.required)))
	if not version_checker(wesnoth.game_config.version, ">=", cfg.required) then wesnoth.fire_event("wrong_bfw_version_message") end
end
function wml_actions.check_sow_version(cfg)
-- 	wesnoth.message("check_sow_version:" .. tostring(version_checker(cfg.actual, "==", cfg.required)))
	if not version_checker(cfg.actual, "==", cfg.required) then wesnoth.fire_event("wrong_sow_version_message") end
end

function wml_actions.sow_check_player_valid(cfg)
	-- Don't make a player invalid or valid while a choosing turn is active
	-- or the reverse turns aren't yet over.
	-- Not sure what would happen in those cases...probably everything gets messed up.
	if wesnoth.get_variable("sow_game_stats.choosing_turn.active") then return end
	if wesnoth.get_variable("sow_reverse_turn_side_numbers.length") > 0 then return end
	local sync = function()
		return { valid = wesnoth.sides[wesnoth.current.side].controller == "human" }
	end
	local valid = wesnoth.synchronize_choice(sync).valid
	wesnoth.set_variable("sow_game_stats.player[" .. tostring(wesnoth.current.side) .. "].valid", valid)
end

local function generate_help()
	local max_i = wesnoth.get_variable("sow_help.length") - 1
	local help = tostring(wesnoth.get_variable("sow_help[0].title"))
	for i = 0, max_i, 1 do
		local text = wesnoth.get_variable(string.format("sow_help[%u].text", i))
		help = string.format("%s\n%s", help, tostring(text))
	end
	return help
end
function wml_actions.sow_objectives(cfg)
	cfg = helper.parsed(cfg)
	table.insert(cfg, {"note", { description = generate_help() }})
	wml_actions.objectives(cfg)
end
function wml_actions.sow_help(cfg)
	wml_actions.message({ speaker = "narrator", image = "wesnoth-icon.png", message = generate_help(), side_for = cfg.side })
end
