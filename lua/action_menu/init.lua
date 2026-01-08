local M = {}

---@class action_menu.State
---@field target nil | integer: the action_menu
---@field origin nil | integer: the window where the menu was opened
local state = {
	target = nil,
	origin = nil,
}

state.reset = function()
	state.target = nil
	state.origin = nil
end

---@param command action_menu.Command
---@return string
local function to_line(command)
	return string.format(" %s %s ", command.label, command.key)
end

--- types
---@class action_menu.Color
---@field fg string
---@field bg string
---@class action_menu.Colors
---@field key action_menu.Color
---@field label action_menu.Color
---@class action_menu.Keymap
---@field mode string | table<string>
---@field lhs string
---@class action_menu.Keymaps
---@field open_menu action_menu.Keymap
---@field close_menu action_menu.Keymap
---@field select_item action_menu.Keymap
---@class action_menu.Command
---@field key string
---@field label string
---@field action function
---@class action_menu.Config
---@field commands action_menu.Command[]
---@field keymaps action_menu.Keymaps
---@field colors action_menu.Colors

---@param config action_menu.Config
M.setup = function(config)
	vim.api.nvim_set_hl(0, "CommandKey", {
		fg = config.colors.key.fg,
		bg = config.colors.key.bg,
		bold = true,
	})

	vim.api.nvim_set_hl(0, "CommandLabel", {
		fg = config.colors.label.fg,
		bg = config.colors.label.bg,
	})
	local namespace = vim.api.nvim_create_namespace("action_menu")
	local buffer = vim.api.nvim_create_buf(false, true)
	local menu_items = {}
	for _, command in ipairs(config.commands) do
		table.insert(menu_items, to_line(command))
	end
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, menu_items)
	for i, cmd in ipairs(config.commands) do
		local line_idx = i - 1
		local key_text = " " .. cmd.label .. " "
		local label_text = cmd.key .. " "

		vim.api.nvim_buf_set_extmark(buffer, namespace, line_idx, 0, {
			end_col = #key_text,
			hl_group = "CommandKey",
		})

		vim.api.nvim_buf_set_extmark(buffer, namespace, line_idx, #key_text, {
			end_col = #key_text + #label_text,
			hl_group = "CommandLabel",
		})
	end

	vim.api.nvim_set_option_value("modifiable", false, { buf = buffer })
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buffer })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buffer })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buffer })

	for _, command in ipairs(config.commands) do
		vim.keymap.set("n", command.key, function()
			vim.api.nvim_win_close(state.target, true)
			vim.schedule(function()
				if vim.api.nvim_win_is_valid(state.origin) then
					vim.api.nvim_set_current_win(state.origin)
				end
				command.action()
				state.reset()
			end)
		end, { buffer = buffer })
	end

	vim.keymap.set(config.keymaps.close_menu.mode, config.keymaps.close_menu.lhs, function()
		if state.target then
			vim.api.nvim_win_close(state.target, true)
		end
		state.reset()
	end, { buffer = buffer })

	vim.keymap.set(config.keymaps.select_item.mode, config.keymaps.select_item.lhs, function()
		local line = vim.api.nvim_get_current_line()
		vim.api.nvim_win_close(state.target, true)
		vim.schedule(function()
			if vim.api.nvim_win_is_valid(state.origin) then
				vim.api.nvim_set_current_win(state.origin)
			end
			for _, command in ipairs(config.commands) do
				if line == to_line(command) then
					command.action()
				end
			end
			state.reset()
		end)
	end, { buffer = buffer })

	local width = 30
	local height = #config.commands
	local options = {
		relative = "cursor",
		row = 1,
		col = 0,
		width = width,
		height = height,
		style = "minimal",
		border = "none",
		focusable = false,
	}

	vim.keymap.set(config.keymaps.open_menu.mode, config.keymaps.open_menu.lhs, function()
		state.origin = vim.api.nvim_get_current_win()
		state.target = vim.api.nvim_open_win(buffer, true, options)
	end)
end

return M
