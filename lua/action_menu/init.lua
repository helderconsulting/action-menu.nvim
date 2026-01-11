local M = {}

---@class action_menu.State
---@field target nil | integer: the action_menu
---@field origin nil | integer: the window where the menu was opened
local state = {
	target = nil,
	origin = nil,
	buffer = nil,
	namespace = vim.api.nvim_create_namespace("action_menu"),
	width = 30,
	commands = {},
}

local map_commands_to_keybind = function()
	for _, command in ipairs(state.commands) do
		vim.keymap.set("n", command.key, function()
			vim.api.nvim_win_close(state.target, true)
			vim.schedule(function()
				if vim.api.nvim_win_is_valid(state.origin) then
					vim.api.nvim_set_current_win(state.origin)
				end
				command.action()
				state.reset()
			end)
		end, { buffer = state.buffer })
	end
end

local unmap_commands_from_keybind = function()
	for _, command in ipairs(state.commands) do
		vim.keymap.del("n", command.key, { buffer = state.buffer })
	end
end

state.reset = function()
	state.target = nil
	state.origin = nil
	state.buffer = nil
end

---@param command action_menu.Command
---@param width integer
---@return string
local function to_line(command, width)
	local key = string.format(" %s ", command.key)
	local label = string.format(" %s", command.label)
	local padding = width - string.len(label) - string.len(key)
	local spacing = string.rep(" ", padding)
	return label .. spacing .. key
end

--- types
---@class action_menu.Color
---@field fg string
---@field bg string
---@class action_menu.Colors
---@field key action_menu.Color
---@field label action_menu.Color
---@class action_menu.Command
---@field key string
---@field label string
---@field action function
---@class action_menu.Config
---@field commands action_menu.Command[]
---@field colors action_menu.Colors

M.select = function()
	local line = vim.api.nvim_get_current_line()
	vim.api.nvim_win_close(state.target, true)
	vim.schedule(function()
		if vim.api.nvim_win_is_valid(state.origin) then
			vim.api.nvim_set_current_win(state.origin)
		end
		for _, command in ipairs(state.commands) do
			if line == to_line(command, state.width) then
				command.action()
			end
		end

		unmap_commands_from_keybind()
		state.reset()
	end)
end

M.open = function()
	if state.buffer then
		return
	end
	local menu_items = {}
	for _, command in ipairs(state.commands) do
		table.insert(menu_items, to_line(command, state.width))
	end
	state.buffer = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, menu_items)

	for i, cmd in ipairs(state.commands) do
		local line_idx = i - 1
		local key = string.format(" %s ", cmd.key)
		local label = string.format(" %s", cmd.label)

		local padding = state.width - string.len(label) - string.len(key)
		local spacing = string.rep(" ", padding)

		vim.api.nvim_buf_set_extmark(state.buffer, state.namespace, line_idx, #spacing + #label, {
			end_col = #spacing + #label + #key,
			hl_group = "CommandLabel",
		})

		vim.api.nvim_buf_set_extmark(state.buffer, state.namespace, line_idx, 0, {
			end_col = #spacing + #label,
			hl_group = "CommandKey",
		})
	end

	vim.api.nvim_set_option_value("modifiable", false, { buf = state.buffer })
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = state.buffer })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = state.buffer })
	vim.api.nvim_set_option_value("swapfile", false, { buf = state.buffer })
	local height = #state.commands
	local options = {
		relative = "cursor",
		row = 0,
		col = 0,
		width = state.width,
		height = height,
		style = "minimal",
		border = "none",
		focusable = false,
	}
	map_commands_to_keybind()
	state.origin = vim.api.nvim_get_current_win()
	state.target = vim.api.nvim_open_win(state.buffer, true, options)
end

M.close = function()
	if state.target then
		unmap_commands_from_keybind()
		vim.api.nvim_win_close(state.target, true)
	end
	state.reset()
end

---@param config action_menu.Config
M.setup = function(config)
	state.commands = config.commands
	vim.api.nvim_set_hl(0, "CommandKey", {
		fg = config.colors.key.fg,
		bg = config.colors.key.bg,
		bold = true,
	})

	vim.api.nvim_set_hl(0, "CommandLabel", {
		fg = config.colors.label.fg,
		bg = config.colors.label.bg,
	})
end

return M
