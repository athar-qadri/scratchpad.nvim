local Path = require("plenary.path")
---@diagnostic disable-next-line: unused-local
local log = require("scratchpad.log")

local data_path = string.format("%s/scratchpad", vim.fn.stdpath("data"))
local ensured_data_path = false

local function ensure_data_path()
	if ensured_data_path then
		return
	end

	local path = Path:new(data_path)
	if not path:exists() then
		path:mkdir()
	end
	ensured_data_path = true
end

local filename = function(config)
	local project_root = vim.fs.root(0, config.default.root_patterns)
	if project_root == nil then
		project_root = vim.fn.getcwd()
	end
	return project_root
	--return config.settings.key()
end

local function hash(path)
	return vim.fn.sha256(path)
end

local function fullpath(config)
	local h = hash(filename(config))
	return string.format("%s/%s.json", data_path, h)
	--return string.format("%s/%s.json", data_path, h)
end

local function write_data(cur_pos, data, config)
	Path:new(fullpath(config)):write(vim.json.encode({ cur_pos = cur_pos, body = data }), "w")
end

--- @alias ScratchpadRawData { cur_pos: { r: integer, c: integer }, body: string }

local M = {}

function M.__dangerously_clear_data(config)
	local data = ""
	write_data({ r = 1, c = 0 }, data, config)
end

function M.info()
	return {
		data_path = data_path,
	}
end

--- @class ScratchpadData
--- @field scratch ScratchpadRawData
--- @field has_error boolean
--- @field config ScratchpadConfig
local Data = {}

Data.__index = Data

---@param config ScratchpadConfig
---@param provided_path string?
---@return ScratchpadRawData
local function read_data(config, provided_path)
	ensure_data_path()

	provided_path = provided_path or fullpath(config)
	local path = Path:new(provided_path)
	local exists = path:exists()

	if not exists then
		write_data({ r = 1, c = 0 }, "", config)
	end

	local out_data = path:read()

	if not out_data or out_data == "" then
		write_data({ r = 1, c = 0 }, "", config)
		out_data = { { r = 1, c = 0 }, body = "" }
	end
	local data = vim.json.decode(out_data)
	return data
end

function Data:fetch()
	local ok, data = pcall(read_data, self.config)
	self.scratch = data
	self.has_error = not ok
end

---@param config ScratchpadConfig
---@return ScratchpadData
function Data:new(config)
	return setmetatable({
		scratch = {
			body = "",
			cur_pos = {
				r = 1,
				c = 0,
			},
		},
		has_error = false,
		config = config,
	}, self)
end

---@param data ScratchpadUIData
---@param cur_pos any
function Data:sync_scratch(cur_pos, data)
	self.scratch.body = data
	self.scratch.cur_pos = cur_pos
	pcall(write_data, cur_pos, data, self.config)
end

M.Data = Data
M.test = {
	set_fullpath = function(fp)
		fullpath = fp
	end,

	read_data = read_data,
}

return M
