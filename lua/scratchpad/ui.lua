---@diagnostic disable-next-line: unused-local
local log = require("scratchpad.log")

---@alias ScratchpadUIData string
---@class ScratchpadUI
---@field win_id number
---@field bufnr number
---@field settings ScratchpadSettings
---@field buf_data ScratchpadUIData
local ScratchpadUI = {}

ScratchpadUI.__index = ScratchpadUI

local scratchpad_MENU = "__scratchpad-menu__"
local scratchpad_menu_id = math.random(1000000)

local function get_scratchpad_menu_name()
	scratchpad_menu_id = scratchpad_menu_id + 1
	return scratchpad_MENU .. scratchpad_menu_id
end

local function create_scratchpad_window(config, enter)
	if enter == nil then
		enter = false
	end

	local buf = vim.api.nvim_create_buf(false, true) -- No file, scratch buffer
	local win = vim.api.nvim_open_win(buf, enter or false, config)

	local _ = vim.api.nvim_set_option_value("winhl", "Normal:MyHighlight", {})

	if vim.api.nvim_buf_get_name(buf) == "" then
		vim.api.nvim_buf_set_name(buf, get_scratchpad_menu_name())
	end

	vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
	return { buf = buf, win = win }
end

local restore = {
	cmdheight = {
		original = vim.o.cmdheight,
		scratchpad = 1,
	},
	guicursor = {
		original = vim.o.guicursor,
		scratchpad = "n:NormalFloat",
	},
	wrap = {
		original = vim.o.wrap,
		scratchpad = true,
	},
	breakindent = {
		original = vim.o.breakindent,
		scratchpad = true,
	},
	breakindentopt = {
		original = vim.o.breakindentopt,
		scratchpad = "list:-1",
	},
}

local create_scratchpad_configurations = function(filename, config)
	local width = math.floor(vim.o.columns * 0.80)
	local height = math.floor(vim.o.lines * 0.60)

	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	return {
		background = {
			relative = "editor",
			width = width + 2,
			height = height + 2,
			style = "minimal",
			col = col,
			row = row,
			zindex = 1,
		},
		body = {
			relative = "editor",
			width = width,
			height = height,
			style = "minimal",
			--border = { " ", " ", " ", " ", " ", " ", " ", " " },
			border = "rounded",
			title = { { config.settings.title } },
			title_pos = "center",
			col = col,
			row = row,
			footer = filename,
			footer_pos = "center",
		},
	}
end

local state = {
	floats = {},
}

local foreach_float = function(cb)
	for name, float in pairs(state.floats) do
		cb(name, float)
	end
end

local scratchpad_keymap = function(mode, key, callback)
	vim.keymap.set(mode, key, callback, {
		buffer = state.floats.body.buf,
	})
end

local create_window = function(filename, data)
	local config = data.config
	data = data.scratch
	local windows = create_scratchpad_configurations(filename, config)

	--state.floats.background = create_scratchpad_window(windows.background, nil)
	state.floats.body = create_scratchpad_window(windows.body, true)

	vim.api.nvim_buf_set_lines(state.floats.body.buf, 0, -1, false, vim.split(data.body, "\n"))
	local pos = { data.cur_pos.r, data.cur_pos.c }

	-- temp fix: Cursor position outside buffer
	-- TODO: why this happens, needs to be figured out
	local lc = vim.api.nvim_buf_line_count(state.floats.body.buf)
	pos[1] = math.min(math.max(pos[1], 1), lc)

	vim.api.nvim_win_set_cursor(state.floats.body.win, pos)

	for option, temp_config in pairs(restore) do
		vim.opt[option] = temp_config.scratchpad
	end

	scratchpad_keymap("n", "q", function()
		vim.schedule(function()
			require("scratchpad").ui:close_menu()
		end)
	end)

	scratchpad_keymap("n", "<Esc>", function()
		vim.schedule(function()
			require("scratchpad").ui:close_menu()
		end)
	end)

	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = state.floats.body.buf,
		callback = function()
			vim.schedule(function()
				require("scratchpad").ui:sync()
				require("scratchpad").ui:close_menu()
			end)
		end,
	})

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = state.floats.body.buf,
		callback = function()
			vim.schedule(function()
				require("scratchpad").ui:close_menu()
			end)
		end,
	})

	--local set_win_contents = function(window)
	--  --vim.api.nvim_buf_set_lines(state.floats.body.buf, 0, -1, false, body)
	--end

	vim.api.nvim_create_autocmd("VimResized", {
		group = vim.api.nvim_create_augroup("scratchpad-resized", {}),
		callback = function()
			if not vim.api.nvim_win_is_valid(state.floats.body.win) or state.floats.body.win == nil then
				return
			end

			local updated = create_scratchpad_configurations()
			foreach_float(function(name, _)
				vim.api.nvim_win_set_config(state.floats[name].win, updated[name])
			end)

			-- Re-calculates contents
			--set_win_contents(updated)
		end,
	})
	return state.floats
end

function ScratchpadUI:close_menu()
	if self.settings.sync_on_ui_close and self.bufnr ~= nil then
		require("scratchpad").ui:sync()
	end

	if self.closing then
		return
	end

	self.closing = true

	if self.bufnr ~= nil and vim.api.nvim_buf_is_valid(self.bufnr) then
		vim.api.nvim_buf_delete(self.bufnr, { force = true })
	end

	if self.win_id ~= nil and vim.api.nvim_win_is_valid(self.win_id) then
		vim.api.nvim_win_close(self.win_id, true)
	end

	self.buf_data = nil
	self.win_id = nil
	self.bufnr = nil
	self.closing = false

	--restoring original configuration
	for option, config in pairs(restore) do
		vim.opt[option] = config.original
	end
end

function ScratchpadUI:sync()
	if self.bufnr == nil then
		--if self bufnr is nil, we can consider that another buffer is loaded
		local mode = vim.api.nvim_get_mode()["mode"]
		if mode == "n" then
			--get current line
			local current_line = vim.api.nvim_get_current_line()
			if #current_line ~= 0 then
				local _data = require("scratchpad").ui.data.scratch
				local _sc, _cur_pos = _data.body, _data.cur_pos
				if #_sc ~= 0 then
					_sc = _sc .. "\n"
				end
				local new_data = _sc .. current_line
				local _ = require("scratchpad").ui.data:sync_scratch(_cur_pos, new_data)
			end
			return
		end

		if mode == "v" then
			local _, ls, cs = unpack(vim.fn.getpos("v"))
			local _, le, ce = unpack(vim.fn.getpos("."))
			local selected_text = table.concat(vim.api.nvim_buf_get_text(0, ls - 1, cs - 1, le - 1, ce, {}), "\n")

			if #selected_text ~= 0 then
				local _data = require("scratchpad").ui.data.scratch
				local _sc, _cur_pos = _data.body, _data.cur_pos
				if #_sc ~= 0 then
					_sc = _sc .. "\n"
				end
				local new_data = _sc .. selected_text
				local _ = require("scratchpad").ui.data:sync_scratch(_cur_pos, new_data)
				vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
			end
		end
		return
	end

	local bufnr = self.bufnr
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	--writing buffer content to scratch pad
	self.data:sync_scratch({ r = row, c = col }, table.concat(lines, "\n"))
end

function ScratchpadUI:new_scratchpad()
	if self.data.has_error == true then
		return
	end

	if self.win_id ~= nil then
		self:close_menu()
		return
	end

	local filename = vim.api.nvim_buf_get_name(0)

	local workspace = create_window(filename, self.data)

	self.bufnr = workspace.body.buf
	self.win_id = workspace.body.win

	vim.api.nvim_set_option_value("number", true, {
		win = self.win_id,
	})
end

---@param settings ScratchpadSettings
---@param data ScratchpadData
function ScratchpadUI:configure(data, settings)
	self.data = data
	self.settings = settings
end

---Constructor for the ScratchpadUI class.
---@param settings table
function ScratchpadUI:new(settings)
	return setmetatable({
		win_id = nil,
		bufnr = nil,
		buf_data = nil,
		settings = settings,
	}, self)
end

return ScratchpadUI
