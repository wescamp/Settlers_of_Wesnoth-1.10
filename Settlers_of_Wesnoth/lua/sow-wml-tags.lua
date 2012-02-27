if not wesnoth then
	package.path = package.path .. ";../../../../../data/lua/?.lua"
	wesnoth = require("wesnoth")
end

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

function wml_actions.sow_show_help(cfg)
	local dialog =
		{
			{"helptip", { id="helptip_large" } },
			{"tooltip", { id="tooltip_large" } },
			{"grid",
				{
					{"row",
						{
							{"column",
								{ border_size = 30, border = "all",
									{"label",
										{ label = cfg.title, definition = "title" }
									}
								}
							}
						}
					},
					{"row",
						{
							{"column",
								{
									{"grid",
										{
											{"row",
												{
													{"column",
														{ vertical_alignment = "top",
															{"image", { label = cfg.image }}
														}
													},
													{"column",
														{ border_size = 10, border = "all",
															{"label", { wrap = true, label = cfg.text }}
														}
													},
													{"column",
														{
															{"vertical_scrollbar", {}}
														}
													},
												}
											}
										}
									}
								}
							}
						}
					},
					{"row",
						{
							{"column",
								{
									{"button",
										{ label = _"close", return_value = 1 }
									}
								}
							}
						}
					}
				}
			}
		}
	if cfg.single_side then
		wesnoth.synchronize_choice(function() wesnoth.show_dialog(dialog) end)
	else
		wesnoth.show_dialog(dialog)
	end
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

