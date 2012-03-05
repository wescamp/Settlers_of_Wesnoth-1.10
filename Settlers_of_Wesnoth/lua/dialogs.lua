if not wesnoth then
	package.path = package.path .. ";../../../../../data/lua/?.lua"
	wesnoth = require("wesnoth")
end
local _ = wesnoth.textdomain("wesnoth-Settlers_of_Wesnoth")

local loaded, debug_utils = pcall(wesnoth.dofile, "~add-ons/Wesnoth_Lua_Pack/debug_utils.lua")
local dbms = debug_utils.dbms
local sdbms = debug_utils.sdbms

-- local helper = wesnoth.require "lua/helper.lua"
-- local wml_actions = wesnoth.wml_actions

-----------------------------------------------------------------------------------

sow_dialogs = {}

sow_dialogs.result_type = { done = -1, back = -3, back_to_game = -2 }

-----------------------------------------------------------------------------------

local done_back_back_to_game_buttons =
{ "grid",
	{
		{ "row",
			{
				{"column",
					{
						border_size = 5,
						border = "all",
						{ "button",
							{ label = _"done", return_value = sow_dialogs.result_type.done }
						}
					}
				},
				{"column",
					{
						border_size = 5,
						border = "all",
						{ "button",
							{ label = _"back", return_value = sow_dialogs.result_type.back }
						}
					}
				},
				{"column",
					{
						border_size = 5,
						border = "all",
						{ "button",
							{ label = _"back to game", return_value = sow_dialogs.result_type.back_to_game }
						}
					}
				}
			}
		}
	}
}

-----------------------------------------------------------------------------------

function sow_dialogs.get_sides(side_numbers, active_sides, sync_it)
	local function sync()
		local chosen_sides = ""
		local button_id_string = "side_%s_button"
		local image_id_string = "side_%s_image"
		local label_id_string = "side_%s_label"
		local side_rows = {}
		for side_number in string.gmatch(side_numbers, "[^%s,][^,]*") do
			assert(sow_tools.check_integer(side_number, 1, #wesnoth.sides))
			local a_side_row =
				{ "row",
					{
						{ "column",
							{
								border = "all",
								border_size = 5,
								{ "toggle_button",
									{
										id = string.format(button_id_string, side_number)
									}
								}
							}
						},
						{ "column",
							{
								border = "all",
								border_size = 5,
								{ "image",
									{
										id = string.format(image_id_string, side_number)
									}
								}
							}
						},
						{ "column",
							{
								border = "all",
								border_size = 5,
								{ "label",
									{
										id = string.format(label_id_string, side_number)
									}
								}
							}
						}
					}
				} --row
			table.insert(side_rows, a_side_row )
		end
		local dialog =
			{
				{ "helptip", { id = "helptip_large" } },
				{ "tooltip", { id = "tooltip_large" } },
				{ "grid",
					{
						{ "row",
							{
								{ "column",
									{
										border = "all",
										border_size = 10,
										{ "label",
											{ label = _"Choose sides", definition = "title" }
										},
									}
								}--column
							}
						},--row
						{ "row",
							{
								{ "column",
									{
										border = "all",
										border_size = 10,
										{ "grid",
											side_rows
										}
									}
								}--column
							}
						},--row
						{ "row",
							{
								{ "column",
									{
										border = "all",
										border_size = 10,
										done_back_back_to_game_buttons
									}
								}
							}
						}--row
					}
				}--grid
			}--dialog
		local function preshow()
			local s, e = 1, 1
			for side_number in string.gmatch(side_numbers, "[^%s,][^,]*") do
				s, e = string.find(active_sides, side_number, e, true)
				if s then
					wesnoth.set_dialog_value(true, string.format(button_id_string, side_number))
				end
				local tonumbered_side = tonumber(side_number)
				local leader = wesnoth.get_units({ canrecruit = true, side = tonumbered_side })[1].__cfg
				local image
				if sow_era_is_used then
					image = string.format("%s~TC(%s, magenta)", leader.image, side_number)
				else
					image = string.format("terrain/alphamask.png~RC(000000>%s)", wesnoth.sides[tonumbered_side].color)
				end
				wesnoth.set_dialog_value(image, string.format(image_id_string, side_number))
				wesnoth.set_dialog_value(
					string.format(tostring(_"%s (%s, side %s)"),
						tostring(sow_constants.sow_labels_new.players[tonumbered_side].name),
						tostring(leader.name),
						side_number),
					string.format(label_id_string, side_number))
			end
		end
		local function postshow()
			for side_number in string.gmatch(side_numbers, "[^%s,][^,]*") do
				if wesnoth.get_dialog_value(string.format(button_id_string, side_number)) then
					if chosen_sides ~= "" then
						chosen_sides = string.format("%s,", chosen_sides)
					end
					chosen_sides = string.format("%s%s", chosen_sides, side_number)
				end
			end
		end
		local return_value = wesnoth.show_dialog(dialog, preshow, postshow)
		return { return_value = return_value, chosen_sides = chosen_sides }
	end
	if sync_it then return wesnoth.synchronize_choice(sync) end
	return sync()
end

-----------------------------------------------------------------------------------

function sow_dialogs.confirm(message)
	local function sync()
		local dialog =
		{
			{ "helptip", { id = "helptip_large" } },
			{ "tooltip", { id = "tooltip_large" } },
			{ "grid",
				{
					{ "row",
						{
							{ "column",
								{
									border = "all",
									border_size = 10,
									{ "label",
										{ label = _"Please confirm", definition = "title" }
									},
								}
							}--column
						}
					},--row
					{ "row",
						{
							{ "column",
								{
									border = "all",
									border_size = 10,
									{ "label",
										{ label = message }
									},
								}
							}--column
						}
					},--row
					{ "row",
						{
							{ "column",
								{
									border = "all",
									border_size = 10,
									done_back_back_to_game_buttons
								}
							}
						}
					}--row
				}
			}--grid
		}--dialog
		return { return_value = wesnoth.show_dialog(dialog) }
	end
	return wesnoth.synchronize_choice(sync).return_value
end

-----------------------------------------------------------------------------------

function sow_dialogs.domestic_trade(have, changes, sides, chosen_sides)
	local function sync()
		local resource_rows =
			{
				{ "row",
					{
						{ "column",
							{
								border = "all",
								border_size = 5,
								{ "spacer", { }}
							}
						},
						{ "column",
							{
								horizontal_alignment = "left",
								border = "all",
								border_size = 5,
								{ "label", { label = _"resource", tooltip = _"name of the resource to trade" }}
							}
						},
						{ "column",
							{
								horizontal_alignment = "left",
								border = "all",
								border_size = 5,
								{ "label", { label = _"available", tooltip = _"your current amount of this resource" }}
							}
						},
						{ "column",
							{
								border = "all",
								border_size = 5,
								{ "spacer", { }}
							}
						},
						{ "column",
							{
								border = "all",
								border_size = 5,
								{ "spacer", { }}
							}
						},
						{ "column",
							{
								horizontal_alignment = "left",
								border = "all",
								border_size = 5,
								{ "label", { label = _"changes (offer/demand)", tooltip = _"change applied to this resource in case of successful trade" }}
							}
						},
						{ "column",
							{
								horizontal_alignment = "left",
								border = "all",
								border_size = 5,
								{ "label", { label = _"result", tooltip = _"your resulting amount of this resource in case of successful trade" }}
							}
						}
					}
				}
			}
		local function add_resource_row(type)
			local a_resource_row =
				{ "row",
					{
						{ "column",
							{
								horizontal_alignment = "left",
								border = "all",
								border_size = 5,
								{ "image", { id = type .. "_image" }}
							}
						},
						{ "column",
							{
								horizontal_alignment = "left",
								border = "all",
								border_size = 5,
								{ "label", { label = translatable_resources[type] }}
							}
						},
						{ "column",
							{
								horizontal_alignment = "left",
								border = "all",
								border_size = 5,
								{ "label", { label = tostring(have[type]) }}
							}
						},
						{ "column",
							{
								horizontal_alignment = "left",
								border = "all",
								border_size = 5,
								{ "button", { id = type .. "_offer", label = _"- (offer)" }}
							}
						},
						{ "column",
							{
								horizontal_alignment = "left",
								border = "all",
								border_size = 5,
								{ "button", { id = type .. "_demand", label = _"+ (demand)" }}
							}
						},
						{ "column",
							{
								horizontal_grow= true,
								border = "all",
								border_size = 5,
								{ "label", { id = type .. "_change" }}
							}
						},
						{ "column",
							{
								horizontal_grow= true,
								border = "all",
								border_size = 5,
								{ "label", { id = type .. "_future" }}
							}
						}
					}
				}
			table.insert(resource_rows, a_resource_row)
		end
		add_resource_row("lumber")
		add_resource_row("grain")
		add_resource_row("wool")
		add_resource_row("brick")
		add_resource_row("ore")
		local total =
			{ "row",
				{
					{ "column",
						{
							border = "all",
							border_size = 5,
							{ "spacer", { }}
						}
					},
					{ "column",
						{
							horizontal_alignment = "left",
							border = "all",
							border_size = 5,
							{ "label", { label = _"total", tooltip = _"sum of your current resources" }}
						}
					},
					{ "column",
						{
							horizontal_alignment = "left",
							border = "all",
							border_size = 5,
							{ "label", { label = tostring(have.resources) }}
						}
					},
					{ "column",
						{
							border = "all",
							border_size = 5,
							{ "spacer", { }}
						}
					},
					{ "column",
						{
							border = "all",
							border_size = 5,
							{ "spacer", { }}
						}
					},
					{ "column",
						{
							horizontal_grow= true,
							border = "all",
							border_size = 5,
							{ "label", { id = "resources_change", tooltip = _"sum of applied changes" }}
						}
					},
					{ "column",
						{
							horizontal_alignment = "left",
							border = "all",
							border_size = 5,
							{ "label", { id = "resources_future", tooltip = _"sum of resulting resources" }}
						}
					}
				}
			}
		table.insert(resource_rows, total)
		local specify_tooltip = _"Only the players with the listed side numbers will be asked whether to accept the trade offer\n(default: all other players)."
		local grid =
			{
				{ "row",
					{
						{ "column",
							{
								border = "all",
								border_size = 40,
								{ "label",
									{ label = _"Domestic Trade", definition = "title" }
								}
							}
						}--column
					}
				},--row
				{ "row",
					{
						{ "column",
							{
								border = "all",
								border_size = 20,
								horizontal_alignment = "left",
								{ "label", { label = _"Attempting trade. Please choose." }
								}
							}
						}--column
					}
				},--row
				{ "row",
					{
						{ "column",
							{
								border_size = 5,
								{ "grid",
									resource_rows
								}
							}
						}--column
					}
				},--row
				{ "row",
					{
						{ "column",
							{
								border = "all",
								border_size = 10,
								{ "grid",
									{
										{ "row",
											{
												{ "column",
													{
														border = "all",
														border_size = 10,
														{ "label", { label = _"target sides:", tooltip = specify_tooltip }}
													}
												},
												{ "column",
													{
														horizontal_grow= true,
														border = "all",
														border_size = 10,
														{ "label", { id = "target_sides", tooltip = specify_tooltip  } }
													}
												},
												{ "column",
													{
														border = "all",
														border_size = 10,
														{ "button", { label = _"specify", id = "specify_target_sides", return_value = sow_dialogs.result_type.back_to_game } }
													}
												}
											}
										}
									}
								}
							}
						}--column
					}
				},--row
				{ "row",
					{
						{ "column",
							{
								border = "all",
								border_size = 10,
								done_back_back_to_game_buttons
							}
						}
					}
				}--row
			}
		local dialog =
			{
				{ "helptip", { id = "helptip_large" } },
				{ "tooltip", { id = "tooltip_large" } },
				{ "grid",
					grid
				}
			}--dialog
		local continue = true
		local function preshow()
			wesnoth.set_dialog_value(chosen_sides, "target_sides")
			local function specify()
				local result = sow_dialogs.get_sides(sides, chosen_sides)
				if result.return_value == sow_dialogs.result_type.back_to_game then return end
				if result.return_value == sow_dialogs.result_type.done and result.chosen_sides ~= "" then
					chosen_sides = result.chosen_sides
				end
				continue = true
			end
			wesnoth.set_dialog_callback(specify, "specify_target_sides")

			local function update_displayed_numericals()
				for k, v in pairs(changes) do
					local text = ""
					if changes[k] < 0 then text = string.format(tostring(_" (offering %u)"), -1 * changes[k])
					elseif changes[k] > 0 then text = string.format(tostring(_" (demanding %u)"), changes[k])
					end
					wesnoth.set_dialog_value(tostring(changes[k]) .. tostring(text), k .. "_change")
					wesnoth.set_dialog_value(tostring(have[k] + changes[k]), k .. "_future")
				end
			end
			local function init_a_resource_row(type)
				wesnoth.set_dialog_value(sow_tools.custom_image_to_core(string.format("icons/%s.png", type)) .. "~SCALE(40,40)", type .. "_image")
				local function offer()
					if changes[type] == -1 * have[type] then return end
					changes[type] = changes[type] - 1
					changes.resources = changes.resources - 1
					update_displayed_numericals()
				end
				local function demand()
					local max_demand = 9
					if changes[type] == max_demand then return end
					changes[type] = changes[type] + 1
					changes.resources = changes.resources + 1
					update_displayed_numericals()
				end
				wesnoth.set_dialog_callback(offer, type .. "_offer")
				wesnoth.set_dialog_callback(demand, type .. "_demand")
			end
			for k, v in pairs(have) do
				if k ~= "resources" then init_a_resource_row(k) end
			end
			update_displayed_numericals()
		end

		local return_value
		while continue do
			continue = false
			return_value = wesnoth.show_dialog(dialog, preshow, postshow)
		end
		return { return_value = return_value, { "changes", changes }, chosen_sides = chosen_sides}
	end
	return wesnoth.synchronize_choice(sync)
end
