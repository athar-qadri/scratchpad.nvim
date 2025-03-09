---@diagnostic disable-next-line: unused-local
local log = require("scratchpad.log")

local M = {}
local DEFAULT_LIST = "__scratchpad_files"
M.DEFAULT_LIST = DEFAULT_LIST

---@class ScratchpadPartialConfigItem
---@field select_with_nil? boolean defaults to false
---@field title? string defaults to "Scratch Pad"
---@field get_root_dir? fun(): string

---@class ScratchpadSettings
---@field save_on_toggle boolean defaults to false
---@field sync_on_ui_close? boolean
---@field key (fun(): string)

---@class ScratchpadPartialSettings
---@field save_on_toggle? boolean
---@field sync_on_ui_close? boolean
---@field key? (fun(): string)

---@class ScratchpadConfig
---@field default ScratchpadPartialConfigItem
---@field settings ScratchpadSettings
---@field [string] ScratchpadPartialConfigItem

---@class ScratchpadPartialConfig
---@field default? ScratchpadPartialConfigItem
---@field settings? ScratchpadPartialSettings
---@field [string] ScratchpadPartialConfigItem

---@return ScratchpadPartialConfigItem
function M.get_config(config, name)
	return vim.tbl_extend("force", {}, config.default, config[name] or {})
end

---@return ScratchpadConfig
function M.get_default_config()
	return {
		settings = {
			save_on_toggle = false,
			sync_on_ui_close = false,
			title = "Scratch Pad",
		},

		default = {

			--- select_with_nill allows for a list to call select even if the provided item is nil
			select_with_nil = false,

			autocmds = { "BufLeave" },
			root_patterns = {
				-- General project identifiers
				".git",
				".hg",
				".svn",
				".project",
				"README.md",
				"README",

				-- Rust
				"Cargo.toml",
				"Cargo.lock",

				-- Python
				"pyproject.toml",
				"setup.py",
				"requirements.txt",
				"Pipfile",
				"Pipfile.lock",

				-- JavaScript/TypeScript
				"package.json",
				"tsconfig.json",
				"yarn.lock",
				"pnpm-lock.yaml",

				-- Java
				"pom.xml",
				"build.gradle",
				"build.gradle.kts",
				".classpath",
				".project",

				-- C/C++
				"CMakeLists.txt",
				"Makefile",
				"configure.ac",

				-- Go
				"go.mod",
				"go.sum",

				-- Ruby
				"Gemfile",
				"Gemfile.lock",
				".ruby-version",

				-- PHP
				"composer.json",
				"composer.lock",

				-- Dart/Flutter
				"pubspec.yaml",

				-- .NET (C#, F#)
				".csproj",
				".fsproj",
				".vbproj",
				"global.json",

				-- Elixir
				"mix.exs",

				-- Haskell
				"stack.yaml",
				"cabal.project",

				-- Framework-Specific Identifiers
				-- Frontend frameworks
				"angular.json",
				"vue.config.js",
				"next.config.js",

				-- Backend frameworks
				"flask_app.py",
				"django_project/",
				"config.ru",

				-- Mobile Development
				"AndroidManifest.xml",
				"Info.plist",
				"fastlane/",

				-- DevOps and Deployment Identifiers
				"Dockerfile",
				"docker-compose.yml",
				".vagrant",
				"terraform.tf",
				"main.tf",

				-- Game Development
				"Game.unity",
				"project.godot",
				".uproject",

				-- Monorepo Identifiers
				"lerna.json",
				"nx.json",
			},
		},
	}
end

---@return ScratchpadConfig
function M.merge_config(partial_config, latest_config)
	partial_config = partial_config or {}
	local config = latest_config or M.get_default_config()
	for k, v in pairs(partial_config) do
		if k == "settings" then
			config.settings = vim.tbl_extend("force", config.settings, v)
		elseif k == "default" then
			config.default = vim.tbl_extend("force", config.default, v)
		else
			config[k] = vim.tbl_extend("force", config[k] or {}, v)
		end
	end
	return config
end

---@param settings ScratchpadPartialSettings
function M.create_config(settings)
	local config = M.get_default_config()
	for k, v in ipairs(settings) do
		config.settings[k] = v
	end
	return config
end

return M
