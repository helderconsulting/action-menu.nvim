---@class Keymap
---@field mode string | table<string>
---@field lhs string

---@class Keymaps
---@field open_menu Keymap
---@field close_menu Keymap
---@field select_item Keymap

---@class Command
---@field key string
---@field label string
---@field action function

---@class Config
---@field commands Command[]
---@field keymaps Keymaps

local M = {}
local state = {
	open = false,
	menu_items = {},
}

---@param config Config
M.setup = function(config)
	local function create_floating_menu()
		local original_window = vim.api.nvim_get_current_win()
		local ns_id = vim.api.nvim_create_namespace("my_commands")
		local buffer = vim.api.nvim_create_buf(false, true)
		for _, command in ipairs(config.commands) do
			table.insert(state.menu_items, string.format(" %s %s ", command.key, command.label))
		end
		vim.api.nvim_buf_set_lines(buffer, 0, -1, false, state.menu_items)
		for i, cmd in ipairs(config.commands) do
			local line_idx = i - 1
			local key_text = " " .. cmd.key .. " "
			local label_text = cmd.label .. " "

			vim.api.nvim_buf_set_extmark(buffer, ns_id, line_idx, 0, {
				end_col = #key_text,
				hl_group = "CommandKey",
			})

			vim.api.nvim_buf_set_extmark(buffer, ns_id, line_idx, #key_text, {
				end_col = #key_text + #label_text,
				hl_group = "CommandLabel",
			})
		end
		local width = 30
		local height = #config.commands
		local opts = {
			relative = "cursor",
			row = 1,
			col = 0,
			width = width,
			height = height,
			style = "minimal",
			border = "none",
			focusable = false,
		}

		vim.api.nvim_set_option_value("modifiable", false, { buf = buffer })
		vim.api.nvim_set_option_value("buftype", "nofile", { buf = buffer })
		vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buffer })
		vim.api.nvim_set_option_value("swapfile", false, { buf = buffer })

		local win = vim.api.nvim_open_win(buffer, true, opts)
		vim.keymap.set(config.keymaps.close_menu.mode, config.keymaps.close_menu.lhs, function()
			if state.open then
				vim.api.nvim_win_close(win, true)
			end
		end, { buffer = buffer })

		for _, command in ipairs(config.commands) do
			vim.keymap.set("n", command.key, function()
				vim.api.nvim_win_close(win, true)
				state.open = false
				vim.schedule(function()
					if vim.api.nvim_win_is_valid(original_window) then
						vim.api.nvim_set_current_win(original_window)
					end
					command.action()
				end)
			end, { buffer = buffer })
		end
		vim.keymap.set(config.keymaps.select_item.mode, config.keymaps.select_item.lhs, function()
			local line = vim.api.nvim_get_current_line()
			vim.api.nvim_win_close(win, true)
			state.open = false
			vim.schedule(function()
				if vim.api.nvim_win_is_valid(original_window) then
					vim.api.nvim_set_current_win(original_window)
				end
				for _, command in ipairs(config.commands) do
					if line == command.label then
						command.action()
					end
				end
			end)
		end, { buffer = buffer })
	end
	vim.keymap.set(config.keymaps.open_menu.mode, config.keymaps.open_menu.lhs, function()
		state.open = true

		create_floating_menu()
	end)
end

return M
