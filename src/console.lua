---@diagnostic disable: duplicate-set-field
local console = {
	opened = false,
	---Open the console.
	---@param self table
	open = function(self)
		self.opened = true
	end,
	---Close the console.
	---@param self table
	close = function(self)
		self.opened = false
	end,
	---Toggle the console.
	---@param self table
	toggle = function(self)
		self.opened = not self.opened
	end,
	---Set/get or list configuration parameter(s).
	---@param self table
	---@param conf_type setget
	---@param conf_param string
	---@param new_val any
	config = function(self, conf_type, conf_param, new_val)
		if conf_type == "list" then
			error("Can't list config parameters out of the console.")
		end
		self.COMMANDS.conf({ [1] = conf_type, [2] = conf_param, [3] = new_val })
	end,
	env = {},
	---Set a var inside the enviroment.
	---@param self table
	---@param var any Value
	---@param name string Name of the variable
	---@return any
	setVarInEnv = function(self, var, name)
		if name ~= "print" and name ~= "require" and name ~= "type" then
			self.env[name] = var
		end
		return var
	end,
	---Remove a var of the enviroment.
	---@param self table
	---@param name string Name of the variable.
	removeFromEnv = function(self, name)
		if self.env[name] then
			self.env[name] = nil
		end
	end,
	---Returns a variable from the enviroment.
	---@param self table
	---@param name string
	---@return any|nil Variable
	getEnvVar = function(self, name)
		return self.env[name] or nil
	end,
}

local function SplitString(str, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for s in string.gmatch(str, "([^" .. sep .. "]+)") do
		table.insert(t, s)
	end
	return t
end

local function StripString(str)
	return str:gsub("%s+", "")
end

local function StringToAny(str)
	if str == "nil" then
		return nil
	elseif str == "true" then
		return true
	elseif str == "false" then
		return false
	elseif tonumber(str) then
		return tonumber(str)
	else
		return str
	end
end

local function PrintToConsole(msg, custom_color, msg_type, flags)
	flags = flags or {}

	local color = custom_color or console.COLORS.green
	if not msg then
		table.insert(console.HISTORY, {
			time = console.TIME,
			text = "Expected string",
			isOutput = true,
			color = console.COLORS.red,
		})
		color = console.COLORS.red
		return "Expected string"
	end

	if type(msg) == "table" then
		msg = table.concat(msg, " ")
	end

	table.insert(console.HISTORY, {
		time = console.TIME,
		text = msg,
		isOutput = true,
		color = color,
		type = msg_type or nil,
		custom_prompt = flags.custom_prompt or nil,
	})
end

local function ExecEntry(entry)
	local splitted_entry = SplitString(entry)
	if #splitted_entry == 0 then
		PrintToConsole("Empty input", console.COLORS.red, "ERROR")
		return
	end

	local args = {}
	for i = 2, #splitted_entry do -- skip first argument (command)
		table.insert(args, splitted_entry[i])
	end

	local command_name = splitted_entry[1]:lower()

	local function execcmd(cmd)
		---@diagnostic disable-next-line
		local no_errors, returned, msg = pcall(cmd, args)

		if no_errors then
			local status = returned
			if status == 1 then
				PrintToConsole(msg, console.COLORS.red, "ERROR")
				if console.conf.show_tips then
					PrintToConsole(('Try using "help %s"'):format(command_name), console.COLORS.cyan, "TIP")
				end
			elseif status == -1 then
				PrintToConsole(msg, console.COLORS.yellow, "WARNING")
			elseif status == 0 and msg then
				PrintToConsole(msg, console.COLORS.cyan, "MSG")
			end
		else
			PrintToConsole(returned, console.COLORS.red, "ERROR")
		end
	end

	if type(command_name) == "string" then
		if command_name:sub(1, 1) == "_" then
			PrintToConsole("Trying to use internal command/command description", console.COLORS.red, "ERROR")
			return nil
		end

		if console.COMMANDS[command_name] and type(console.COMMANDS[command_name]) == "function" then
			execcmd(console.COMMANDS[command_name])
		else
			local alias_name = ("_%s_alias"):format(command_name)
			if console.COMMANDS[alias_name] and type(console.COMMANDS[alias_name]) == "function" then
				execcmd(console.COMMANDS[alias_name])
				return
			else
				PrintToConsole(("Unrecognized command: %s"):format(command_name), console.COLORS.red, "ERROR")
			end
		end
	else
		PrintToConsole("Invalid command name, expected string", console.COLORS.red, "ERROR")
	end
end

local function ExecLastEntry()
	local last_entry = console.HISTORY[#console.HISTORY].text
	ExecEntry(last_entry)
end

function console:init(conf)
	self.env = {
		print = PrintToConsole,
		require = function(modname)
			local no_errors, returned = pcall(require, modname)
			if no_errors then
				return returned -- return module
			else
				return nil
			end
		end,
		type = type,
		tonumber = tonumber,
		tostring = tostring,
		pairs = pairs,
		ipairs = ipairs,
		pcall = pcall,
		math = math,
		string = string,
		table = table,
		error = error,
	}

	math.randomseed(os.time())
	math.random() -- pop first number, as it will always be the same

	self.HISTORY = {}
	self.CURRENT_TEXT = ""

	self.COLORS = {
		black = { 0, 0, 0 },
		red = { 1, 0, 0 },
		green = { 0, 1, 0 },
		yellow = { 1, 1, 0 },
		blue = { 0, 0, 1 },
		magenta = { 1, 0, 1 },
		cyan = { 0, 0.5, 0.5 },
		white = { 1, 1, 1 },
		light_blue = { 0.5, 0.5, 1 },
		light_red = { 1, 0.5, 0.5 },
		light_green = { 0.5, 1, 0.5 },
	}

	conf = conf or {}
	self.conf = {
		open_keybind = conf.open_keybind or "`",
		text_size = conf.text_size or 1,
		bg_opacity = conf.bg_opacity or 0.5,
		bg_color = conf.bg_color or { 0, 0, 0 },
		fg_opacity = conf.fg_opacity or 1,
		show_tips = conf.show_tips or true,
		show_dir_in_prompt = conf.show_dir_in_prompt or true,
	}

	self.COMMANDS = {
		echo = PrintToConsole,
		_echo_desc = "Print something to console. Arguments: string...",
		exit = function()
			love.event.quit(0)
		end,
		_exit_desc = "Quit.",
		restart = function()
			love.event.quit("restart")
		end,
		_restart_desc = "Restart.",
		clear = function()
			self.HISTORY = {}
		end,
		_clear_desc = "Clear the screen.",
		lua = function(args)
			local forbidden_terms = {
				"while",
				"repeat",
				"until",
			}
			for _, v in ipairs(args) do
				for _, forbidden in ipairs(forbidden_terms) do
					if v == forbidden then
						return 1, "Used forbidden terms, e.g " .. forbidden_terms[math.random(1, #forbidden_terms)]
					end
				end
			end

			local code = table.concat(args, " ")

			local chunk, error_msg = load(code, "user code", "bt", self.env)

			if chunk and not error_msg then
				local no_errors, returned = pcall(chunk)
				if no_errors then
					return 0
				else
					return 1, returned
				end
			else
				return 1, error_msg
			end
		end,
		_lua_desc = "Run lua code. Arguments: code...",
		setvar = function(args)
			local var_name = args[1]

			if not var_name then
				return 1, "Didn't give any var name"
			end

			if var_name:sub(1, 1) == "_" then
				return 1, "Can't change var, not authorized"
			end

			if tonumber(var_name) then
				return 1, "Variable name is not valid"
			end

			local forbidden_names = {
				"COLORS",
				"COMMANDS",
				"love",
				"HISTORY",
				"TIME",
				"CURRENT_TEXT",
				"PrintToConsole",
				"ExecLastEntry",
				"SplitString",
				"table",
				"string",
			}

			for _, forbidden in ipairs(forbidden_names) do
				if var_name == forbidden then
					return 1, "Can't change var, not authorized"
				end
			end

			local raw_val = {}
			for i = 2, #args do
				table.insert(raw_val, args[i])
			end

			local val = table.concat(raw_val, " ")
			---@diagnostic disable: cast-local-type
			if val then
				val = StringToAny(val)
				---@diagnostic enable: cast-local-type

				_G[var_name] = val
			else
				return 1, "Didn't give any value"
			end

			PrintToConsole(('Set var "%s" to %s'):format(args[1], val))
			return 0
		end,
		_setvar_desc = "Set a global variable. Arguments: name, val.",
		getvar = function(args)
			if not args or not args[1] then
				return 1, "Variable name was not given"
			end

			local var_name = args[1]

			if var_name == "all" then
				for name, var in pairs(_G) do
					PrintToConsole(("%s: %s\n"):format(name, var), console.COLORS.light_red, "GLOBAL VAR")
				end
				return
			end

			if _G[var_name] ~= nil then
				local var = _G[var_name]
				PrintToConsole(('Variable "%s" is %s and has type "%s"'):format(var_name, var, type(var)))
				return var
			else
				return 1, "Variable doesn't exist"
			end
		end,
		_getvar_desc = "Get a global variable. Arguments: var_name.",
		echovar = function(args)
			if _G[args[1]] ~= nil then
				local var = _G[args[1]]
				PrintToConsole(tostring(var))
				return var
			else
				return 1, "Variable doesn't exist"
			end
		end,
		_echovar_desc = "Print a variable to the console. Similar to getvar. Arguments: var_name.",
		calc = function(args)
			local forbidden_terms = {
				"while",
				"repeat",
				"until",
			}
			for _, v in ipairs(args) do
				for _, forbidden in ipairs(forbidden_terms) do
					if v == forbidden then
						return 1, "Used forbidden terms, e.g " .. forbidden_terms[math.random(1, #forbidden_terms)]
					end
				end
			end

			local operation = "return " .. table.concat(args, " ")

			local chunk, error_msg = load(operation, "operation", "bt", {})

			if chunk then
				local result = chunk()
				if type(result) == "number" then
					PrintToConsole(("%s = %s"):format(operation:sub(#"return ", #operation), result))
				else
					return 1, "Operation did not return a single number."
				end
			else
				return 1, error_msg
			end
		end,
		_calc_desc = "Make a calculation. Arguments: operation...",
		close = function()
			console:close()
		end,
		_close_desc = "Close the console.",
		func = function(args)
			local raw_code = {}
			for i = 2, #args do
				table.insert(raw_code, args[i])
			end

			local cmd_name = args[1]
			local code = "return function(args) " .. table.concat(raw_code, " ") .. " end"

			local cmd, error_msg = load(code, cmd_name, "bt", self.env)

			if self.COMMANDS[cmd_name] then
				return 1, "Command already exists, can't override"
			end

			if cmd then
				local no_errors, returned = pcall(cmd)
				if no_errors then
					self.COMMANDS[cmd_name] = function(cmd_args)
						for i in ipairs(cmd_args) do
							cmd_args[i] = StringToAny(cmd_args[i])
						end

						local errors, msg = pcall(cmd(), cmd_args)
						if not errors then
							PrintToConsole(msg, console.COLORS.red, "ERROR")
						end
					end

					self.COMMANDS[("_%s_desc"):format(cmd_name)] = "User defined command."
					return 0
				else
					return 1, returned
				end
			else
				return 1, error_msg
			end
		end,
		_func_desc = "Create a function (custom command). Arguments: name, code...",
		conf = function(args)
			---@alias conf_type string
			---| "set" set a parameter
			---| "get" get a parameter
			---| "list" list parameters and their values
			---@type conf_type
			local conf_type = args[1]

			local conf_param = args[2]
			if conf_type == "set" then
				local new_val = args[3]
				if not new_val then
					return 1, "Didn't give any values"
				else
					new_val = StringToAny(new_val)
				end

				if console.conf[conf_param] ~= nil then
					console.conf[conf_param] = new_val
					return 0, "Configuration changed succesfully"
				else
					return 1, "Param doesn't exist"
				end
			elseif conf_type == "get" then
				if console.conf[conf_param] then
					return 0, ('Parameter "%s" is %s '):format(conf_param, console.conf[conf_param])
				else
					return 1, "Param doesn't exist"
				end
			elseif conf_type == "list" then
				for name, val in pairs(console.conf) do
					PrintToConsole(('%s: "%s"'):format(name, val), console.COLORS.light_green, "CONF PARAM")
				end
			else
				return 1, "Expected set, get or list as first argument"
			end
		end,
		_conf_desc = "Set/get a console config parameter. You can also list the current configuration. Arguments: set/get/list, param[, val].",
		env = function(args)
			---@alias setget string
			---| "set" set value
			---| "get" get value
			---@type setget
			local setget = args[1]
			local var_name = args[2]

			if setget == "set" then
				if var_name == "print" or var_name == "require" or var_name == "type" then
					return 1, "Can't change print, require or type."
				end
				local new_val_raw = {}
				for i = 3, #args do
					table.insert(new_val_raw, args[i])
				end
				local new_val = table.concat(new_val_raw, " ")
				---@diagnostic disable-next-line
				console.env[var_name] = StringToAny(new_val)
			elseif setget == "get" then
				if StripString(var_name) == "all" then
					local list = ""
					for k, v in pairs(console.env) do
						list = list .. ("var %s: %s\n"):format(k, v)
						PrintToConsole(
							("var %s: %s (type: %s)"):format(k, v, type(v)),
							console.COLORS.light_red,
							"ENV VAR"
						)
					end
					return 0
				end

				if console.env[var_name] ~= nil then
					PrintToConsole(
						('Variable "%s" is %s and has type "%s"'):format(
							var_name,
							console.env[var_name],
							type(console.env[var_name])
						)
					)

					return 0
				else
					return 1, "Variable doesn't exist inside env"
				end
			else
				return 1, "Expected set/get as first argument"
			end
		end,
		_env_desc = "Set/get an enviroment variable. Arguments: set/get, name[, val]",
		flexists = function(args)
			local filename = args[1]
			if not filename then
				return 1, "File name expected as first argument"
			end

			if filename:find(".lua") then
				PrintToConsole(".lua is not needed when using flexists", console.COLORS.yellow, "WARNING")
				filename = filename:sub(1, #filename - #".lua")
			end

			local exists = pcall(require, filename)
			if exists then
				return 0, ("File %s.lua exists in this directory"):format(filename)
			else
				return 1, ("File %s.lua doesn't exist in this directory"):format(filename)
			end
		end,
		_flexists_desc = "Check if a file exists inside the current directory. Arguments: filename",
		love = function(args)
			local code = table.concat(args, " ")
			local chunk, chunk_error_msg = load(code, "love user code", "bt", {
				love = love,
				print = PrintToConsole,
				lg = love.graphics,
				lw = love.window,
				lms = love.mouse,
				lm = love.math,
				lp = love.physics,
				lt = love.timer,
			})

			if chunk then
				local no_errors, error_msg = pcall(chunk)
				if no_errors then
					return 0
				else
					return 1, error_msg
				end
			else
				return 1, chunk_error_msg
			end
		end,
		_love_desc = 'Execute love code (has the "love" var as an enviroment variable). Arguments: code...',
		alias = function(args)
			local alias = args[1]
			if not alias then
				return 1, "Expected alias as first argument"
			end

			local cmd = args[2]
			if not cmd then
				return 1, "Expected command as second argument"
			elseif cmd:sub(1, 1) == "_" then
				return 1, "Can't make alias for internal variables"
			end

			if console.COMMANDS[cmd] then
				console.COMMANDS[("_%s_alias"):format(alias)] = console.COMMANDS[cmd]
				return 0, "Alias created succesfully"
			else
				return 1, "Command doesn't exist"
			end
		end,
		_alias_desc = "Create an alias for a command. Arguments: alias, command",
		msg = function(args)
			local msg_type = args[1]
			if not msg_type then
				return 1, "Expected message type as first argument"
			end

			local msg_raw = {}
			for i = 2, #args do
				table.insert(msg_raw, args[i])
			end
			local msg = table.concat(msg_raw, " ")

			local msg_types = {
				error = {
					color = console.COLORS.red,
					name = "ERROR",
				},
				debug = {
					color = console.COLORS.cyan,
					name = "DEBUG",
				},
				warning = {
					color = console.COLORS.yellow,
					name = "WARNING",
				},
				log = {
					color = console.COLORS.light_blue,
					name = "LOG",
				},
				regular = {
					color = console.COLORS.white,
					name = "OUT",
				},
				help = {
					color = console.COLORS.light_green,
					name = "HELP",
				},
			}

			if msg_types[msg_type] then
				msg_type = msg_types[msg_type]
				PrintToConsole(msg, msg_type.color, msg_type.name)
				return 0
			else
				return 1, "Message type doesn't exist"
			end
		end,
		_msg_desc = "Prints a message with a specific type to the console. Arguments: type, msg...",
		about = function(args)
			local about = {
				"Author: Nykenik24",
				"License: MIT",
				"Description: Echo Console is a simple terminal emulator inside Love2d,",
				'it offers various commands, like "lua" to run sandboxed lua code, "env"',
				'to modify the enviroment (set/get enviroment variables), "func" to make',
				"custom commands, etc.",
				"",
				"Through a simple but deep system, it offers a safe to use console to",
				"make debugging and developing easier and faster.",
			}
			for _, line in ipairs(about) do
				PrintToConsole(line, console.COLORS.light_blue, "ABOUT")
			end
			return 0
		end,
		_about_desc = "About the library.",
	}

	self.COMMANDS.help = function(args)
		---@param command string
		local function getDesc(command)
			for name, desc in pairs(self.COMMANDS) do
				if name:sub(1, 1) == "_" and name:find("desc") and name:find(command) then
					name = name:sub(2, #name)

					---@diagnostic disable-next-line
					name = SplitString(name, "_")

					local cmd_name, cmd_desc = command, desc

					return cmd_name, cmd_desc
				end
			end
			return nil, nil
		end

		if not args[1] then
			local cmd_count = 0
			for cmd in pairs(self.COMMANDS) do
				if cmd:sub(1, 1) ~= "_" then
					local cmd_name, cmd_desc = getDesc(cmd)
					if cmd_name and cmd_desc then
						if cmd_desc == "User defined command." then
							PrintToConsole(("%s - %s"):format(cmd_name, cmd_desc), self.COLORS.light_blue, "HELP")
						else
							PrintToConsole(("%s - %s"):format(cmd_name, cmd_desc), self.COLORS.light_green, "HELP")
						end
					end
					cmd_count = cmd_count + 1
				end
			end
			PrintToConsole(tostring(cmd_count) .. " commands", self.COLORS.light_red, "HELP")
		else
			local cmd_name, cmd_desc = getDesc(args[1])
			if cmd_name and cmd_desc then
				PrintToConsole(("%s - %s"):format(cmd_name, cmd_desc), self.COLORS.light_green, "HELP")
			else
				return 1, ("Command %s doesn't exist"):format(args[1])
			end
		end
	end

	if self.conf.show_tips then
		PrintToConsole('type "help" to get all commands', self.COLORS.cyan, "TIP")
		PrintToConsole('To disable tips, use "conf set show_tips false"', console.COLORS.cyan, "TIP")
	end
end

function console:update()
	self.TIME = os.date("%H:%M:%S") or "00:00:00"
	if #self.HISTORY > love.graphics.getHeight() / 25 - 2 then
		table.remove(self.HISTORY, 1)
	end
	return self.opened
end

function console:draw()
	if console.opened then
		local bg_color = self.COLORS[self.conf.bg_color] or { 0, 0, 0 }
		love.graphics.setColor(bg_color[1], bg_color[2], bg_color[3], tonumber(self.conf.bg_opacity) or 0.5)
		love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

		love.graphics.setColor(1, 1, 1, tonumber(self.conf.fg_opacity) or 1)

		-- local line_limit = love.graphics.getWidth() - 80

		local current_i = 0
		for i, v in ipairs(self.HISTORY) do
			local x, y = 20, i * 25 / self.conf.text_size
			if v.isInput then
				love.graphics.print(
					("%s at %s > %s"):format(
						os.getenv("USER") or os.getenv("USERNAME") or "USER",
						v.time or "00:00:00",
						v.text
					),
					x,
					y,
					0,
					self.conf.text_size,
					self.conf.text_size
				)
			else
				love.graphics.setColor(v.color or self.COLORS.green)
				if not v.custom_prompt then
					love.graphics.print(
						("%s >> %s"):format(v.type or v.time or "00:00:00", v.text),
						x,
						y,
						0,
						self.conf.text_size,
						self.conf.text_size
					)
				else
					love.graphics.print(
						("%s %s %s"):format(v.type or v.time or "00:00:00", v.custom_prompt, v.text),
						x,
						y,
						0,
						self.conf.text_size,
						self.conf.text_size
					)
				end
				love.graphics.setColor(self.COLORS.white)
			end
			current_i = i + 1
		end
		local prompt
		if not self.conf.show_dir_in_prompt then
			prompt = ("%s > "):format(self.TIME)
		else
			prompt = ("%s %s > "):format(self.TIME, love.filesystem.getWorkingDirectory())
		end

		love.graphics.print(
			("%s%s"):format(prompt, self.CURRENT_TEXT),
			20,
			current_i * 25,
			0,
			self.conf.text_size,
			self.conf.text_size
		)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

function console:textinput(t)
	if self.opened then
		self.CURRENT_TEXT = self.CURRENT_TEXT .. t
	end
end

function console:keypressed(k)
	---@param key love.KeyConstant
	local function Pressed(key)
		return k == key
	end

	if Pressed(self.conf.open_keybind) then
		console:toggle()
	end

	if self.opened then
		if Pressed("backspace") then
			self.CURRENT_TEXT = self.CURRENT_TEXT:sub(1, #self.CURRENT_TEXT - 1)
		elseif Pressed("return") then
			if love.keyboard.isDown("lshift") then
				self.CURRENT_TEXT = self.CURRENT_TEXT .. "\n"
			else
				table.insert(self.HISTORY, { time = self.TIME, text = self.CURRENT_TEXT, isInput = true })
				ExecLastEntry()
				self.CURRENT_TEXT = ""
			end
		elseif Pressed("up") then
			if #self.HISTORY > 0 then
				local last_input
				for i = #self.HISTORY, 1, -1 do
					local entry = self.HISTORY[i]
					if entry.isInput then
						last_input = entry
						break
					end
				end

				if last_input then
					self.CURRENT_TEXT = last_input.text
				end
			end
		elseif Pressed("tab") then
			self.CURRENT_TEXT = self.CURRENT_TEXT .. "\t"
		end
	end
end

function console.log(msg)
	PrintToConsole(msg, console.COLORS.light_blue, "LOG")
end

function console.cmd(cmd)
	ExecEntry(cmd)
end

console.utils = {
	---Make a global variable be an enviroment variable.
	---@param global_var string Global variable name
	---@param env_var string Enviroment variable name
	---@return any|nil Variable `nil` if variable doesn't exist.
	linkGlobalToEnvVariable = function(global_var, env_var)
		local env = console.env

		if env[env_var] ~= nil then
			_G[global_var] = env[env_var]
			return env[env_var]
		else
			return nil
		end
	end,
	---Make an enviroment variable be a global variable.
	---@param global_var string Global variable name
	---@param env_var string Enviroment variable name
	---@return any|nil Variable `nil` if variable doesn't exist or can't be changed.
	linkEnvToGlobalVariable = function(global_var, env_var)
		local env = console.env

		if env_var == "print" or env_var == "require" then
			return nil
		end

		if _G[global_var] then
			env[env_var] = _G[global_var]
			return _G[global_var]
		else
			return nil
		end
	end,
	---Make the env contain all global variables.
	---
	---Excludes `print` because of `PrintToConsole` and `require` because of the safe require.
	---@return boolean Succes
	syncGlobalsToEnv = function()
		for name, var in pairs(_G) do
			if name ~= "print" or name ~= "require" then
				console.env[name] = var
			end
		end
		return true
	end,
}

return console
