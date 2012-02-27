if not wesnoth then
	package.path = package.path .. ";../../../../../data/lua/?.lua"
	wesnoth = require("wesnoth")
end

local loaded, debug_utils = pcall(wesnoth.dofile, "~add-ons/Wesnoth_Lua_Pack/debug_utils.lua")
local dbms = debug_utils.dbms
local sdbms = debug_utils.sdbms

-- local helper = wesnoth.require "lua/helper.lua"
-- local wml_actions = wesnoth.wml_actions


local ok_cancel_buttons =
{ "grid",
	{
		{ "row",
			{
				{"column",
					{
						border_size = 5,
						border = "all",
						{ "button",
							{ label = _"okay", return_value = -1 }
						}
					}
				},
				{"column",
					{
						border_size = 5,
						border = "all",
						{ "button",
							{ label = _"cancel", return_value = -2 }
						}
					}
				}
			}
		}
	}
}

-----------------------------------------------------------------------------------

sow_dialogs = {}

function sow_dialogs.get_sides(side_numbers)
	local function sync()
		local chosen_sides = ""
		local button_id_string = "side_%u_button"
		local image_id_string = "side_%u_image"
		local label_id_string = "side_%u_label"
		local side_rows = {}
		for i, side_number in ipairs(side_numbers) do
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
										ok_cancel_buttons
									}
								}
							}
						}--row
					}
				}--grid
			}--dialog
		local function preshow()
			for i, side_number in ipairs(side_numbers) do
				wesnoth.set_dialog_value(true, string.format(button_id_string, side_number))
				local leader = wesnoth.get_units({ canrecruit = true, side = side_number })[1].__cfg
				local image
				if sow_era_is_used then
					image = string.format("%s~TC(%u, magenta)", leader.image, side_number)
				else
					image = string.format("terrain/alphamask.png~RC(000000>%s)", wesnoth.sides[side_number].color)
				end
				wesnoth.set_dialog_value(image, string.format(image_id_string, side_number))
 				wesnoth.set_dialog_value(
					string.format("%s (%s)",
						tostring(sow_constants.sow_labels_new.players[side_number].name),
						tostring(leader.name)),
					string.format(label_id_string, side_number))
			end
		end
		local function postshow()
			for i, side_number in ipairs(side_numbers) do
				if wesnoth.get_dialog_value(string.format(button_id_string, side_number)) then
					if string.len(chosen_sides) ~= 0 then
						chosen_sides = string.format("%s,", chosen_sides)
					end
					chosen_sides = string.format("%s%u", chosen_sides, side_number)
				end
			end
		end
 		local return_value = wesnoth.show_dialog(dialog, preshow, postshow)
		return { return_value = return_value, chosen_sides = chosen_sides }
	end
	return wesnoth.synchronize_choice(sync)
end

-----------------------------------------------------------------------------------
