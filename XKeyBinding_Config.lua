--[=====[
		## Extended Key Binding ver. @@release-version@@
		## XKeyBinding_Config.lua - module
		Config module for XKeyBinding addon
--]=====]

local addonName = ...
local XKeyBinding = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Config = XKeyBinding:NewModule("Config")

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local type = type
local ipairs = ipairs
local pairs = pairs
local print = print
local random = math.random
local tinsert = table.insert
local tconcat = table.concat
local type = type
local unpack = unpack

local Event

local mod = Config

local function merge(target, source)
	if not source then
		target, source = {}, target
	elseif type(target) ~= "table" then
		target = {}
	end
	for k, v in pairs(source) do
		if type(v) == "table" then
			target[k] = merge(target[k], v)
		elseif target[k] == nil then
			target[k] = v
		end
	end
	return target
end

local function map(t, mapFunc)
	local res = {}
	for k, v in pairs(t) do
		res[k] = mapFunc(v, k, t)
	end
	return res
end

local function printf(str, ...)
	print(str:format(...))
end

local function printTable(t, name, maxLevel)
	--@debug@
	local function indent(i)
		return strrep("  ", i)
	end
	local function printIndent(i, s)
		print(indent(i) .. s)
	end
	local function printTableImpl(t, name, level, max)
		if level > max then
			return
		end

		printIndent(level, name .. " = {")

		for k, v in pairs(t) do
			local vType = type(v)
			if vType == "table" then
				printTableImpl(v, k, level + 1, max)
			elseif vType == "string" then
				printIndent(level + 1, k .. " = '" .. tostring(v) .. "',")
			else
				printIndent(level + 1, k .. " = " .. tostring(v) .. ",")
			end
		end
		printIndent(level, "},")
	end

	printTableImpl(t, name or "<unnamed>", 0, maxLevel or 16)
	--@end-debug@
end

local addonMetadata = map(
	{ title = "Title", description = "Notes", author = "Author", version = "Version", date = "X-ReleaseDate" },
	function(v, k, t)
		return GetAddOnMetadata(addonName, v)
	end
)

local COMMAND_NUMBER = 32
local commandTypes = {}
local commands = {}

do
	local typeNames = { "DISABLED", "MACRO_NAME", "MACRO_TEXT", "CVAR_TOGGLE", "LUA_CODE" }
	local typeIcons = { "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7", 133738, 1500878, 236188, 1500880 }

	for i, v in ipairs(typeNames) do
		local sortableName = "T" .. i .. "_" .. v
		commandTypes[v] = sortableName
		commands[sortableName] = {
			name = L[v .. ".TYPENAME"],
			icon = typeIcons[i],
			help = L[v .. ".TYPEZHELP"]
		}
	end
end

--[[
	Localized type strings to be found by localization script
	L["DISABLED.TYPENAME"]		L["DISABLED.TYPEZHELP"]
	L["MACRO_NAME.TYPENAME"]	L["MACRO_NAME.TYPEZHELP"]
	L["MACRO_TEXT.TYPENAME"]	L["MACRO_TEXT.TYPEZHELP"]
	L["CVAR_TOGGLE.TYPENAME"]	L["CVAR_TOGGLE.TYPEZHELP"]
	L["LUA_CODE.TYPENAME"]		L["LUA_CODE.TYPEZHELP"]
]]

-- Current settings
local db

local uniques = {}

-- Default settings
local defaults = {
	profile = {
		general = {
			showNumbers = true,
			showIcons = true,
			notifyScreen = true,
			notifyChat = true,
		},
		commands = {},
	},
}

local function isNilOrEmptyString(str)
	return str == nil or #str == 0
end

local function formatDate(dateMeta)
	if tonumber(dateMeta) then
		local year = tonumber(dateMeta:sub(1, 4))
		local month = tonumber(dateMeta:sub(5, 6))
		local day = tonumber(dateMeta:sub(7, 8))
		return ("%02d.%02d.%04d"):format(day, month, year)
	else
		return dateMeta
	end
end

local function mergeUniques(db)
	return merge(
		{ commands = map(uniques, function(v) return { unique = v } end) },
		db
	)
end

local function getCommandName(index)
	local data = db.commands[index]
	local name
	local icon

	if not data then
		-- Not configured item
		name = L[" (empty) "]
		icon = nil
	else
		if isNilOrEmptyString(data.name) then
			-- Item without name
			name = L["(no name)"]
		else
			name = data.name
		end
		icon = commands[data.type].icon
	end

	local spaceAdded = false

	if icon and db.general.showIcons then
		name = ("|T%s:20:20|t %s"):format(icon, name)
		spaceAdded = true
	end

	if db.general.showNumbers then
		name = ("%02d.%s%s"):format(index, spaceAdded and "" or " ", name)
	end

	return name
end

local function getCommandTypes(args)
	return map(
			commands,
			function(cmd)
				if db.general.showIcons then
					return ("|T%s:20:20|t %s"):format(cmd.icon, cmd.name)
				else
					return cmd.name
				end
			end
		)
end

local function getCommandShortcut(index)
	return map(
		{ GetBindingKey(("CLICK XBoundButton%02d:LeftButton"):format(index)) },
		function(str)
			if not str:find("-") then
				return str
			end
			local key = { str:match("%-([^-]+)$") }
			if str:match("SHIFT%-") then
				tinsert(key, 1, "Shift")
			end
			if str:match("ALT%-") then
				tinsert(key, 1, "Alt")
			end
			if str:match("CTRL%-") then
				tinsert(key, 1, "Ctrl")
			end
			return tconcat(key, "-")
		end
	)
end

local function getCommandProp(prop, index)
	local data = db.commands[index]
	local cmdType

	if not data then
		cmdType = commandTypes.DISABLED
	else
		cmdType = data.type
	end

	return commands[cmdType][prop]
end

local function clearCommands()
	for i, v in ipairs(db.commands) do
		if v.type == commandTypes.DISABLED and (not v.name or v.name == "") then
			db.commands[i] = nil
		end
	end
end

local function getCommandOptions(index)
	local isControlDisabled = function()
		local cmd = db.commands[index]
		return not cmd or cmd.type == commandTypes.DISABLED
	end
	return {
		type = "group",
		order = index * 10,
		name = getCommandName(index),
		width = "full",
		get = function(item)
			local key = item[#item]
			local cmd = db.commands[index]
			if cmd and cmd[key] then
				return cmd[key]
			elseif key == "type" then
				return commandTypes.DISABLED
			else
				return nil
			end
		end,
		set = function(item, value)
			local key = item[#item]
			local cmd = db.commands[index] or {}
			cmd[key] = value
			db.commands[index] = cmd
			uniques[index] = random(999999)
		end,
		args = {
			type = {
				type = "select",
				order = 10,
				name = L["Type"],
				desc = L["Command type"],
				style = "dropdown",
				values = getCommandTypes,
			},
			name = {
				type = "input",
				order = 30,
				name = L["Name"],
				desc = L["Command name"],
				width = "full",
				disabled = isControlDisabled,
			},
			notifyScreen = {
				type = "toggle",
				order = 40,
				name = L["On-screen notification"],
				desc = L["Show on-screen notification when command is invoked"],
				disabled = isControlDisabled,
			},
			notifyChat = {
				type = "toggle",
				order = 50,
				name = L["Chat notification"],
				desc = L["Show chat notification when command is invoked"],
				disabled = isControlDisabled,
			},
			text = {
				type = "input",
				order = 60,
				name = L["Command Text"],
				width = "full",
				multiline = 10,
				disabled = isControlDisabled,
			},
			keybinding = {
				type = "group",
				order = 70,
				name = _G["KEY_BINDINGS"],
				guiInline = true,
				width = "full",
				args = {
					keybindingtext = {
						type = "description",
						order = 0,
						fontSize = "medium",
						name = function()
							local keys = getCommandShortcut(index)
							return #keys > 0 and tconcat(keys, ("\32"):rep(5)) or ("\32\32" .. L["(not assigned)"])
						end,
					}
				},
			},
			help = {
				type = "group",
				order = 80,
				name = L["Command Description"],
				guiInline = true,
				width = "full",
				args = {
					helptext = {
						type = "description",
						order = 0,
						fontSize = "medium",
						name = function () return getCommandProp("help", index) end,
						image = function () return getCommandProp("icon", index), 32, 32 end,
					},
				},
			},
		},
	}
end

local function getOptions(uiType, uiName, appName)
	if appName == (addonName .. "-General") then
		return {
			type = "group",
			order = 0,
			name = addonMetadata.title,
			args = {
				descr = {
					type = "description",
					order = 0,
					name = addonMetadata.description
				},
				releaseData = {
					type = "group",
					order = 10,
					name = "",
					guiInline = true,
					width = "full",
					args = {
						author = {
							type = "input",
							order = 10,
							name = L["Author"],
							get = function() return addonMetadata.author end,
							disabled = true,
						},
						version = {
							type = "input",
							order = 20,
							name = L["Version"],
							get = function() return addonMetadata.version end,
							disabled = true,
						},
						date = {
							type = "input",
							order = 30,
							name = L["Date"],
							get = function() return formatDate(addonMetadata.date) end,
							disabled = true,
						},
					},
				},
				commandList = {
					type = "group",
					order = 20,
					name = L["Command List"],
					guiInline = true,
					width = "full",
					get = function(item)
						return db.general[item[#item]]
					end,
					set = function (item, value)
						db.general[item[#item]] = value
					end,
					args = {
						showNumbers = {
							type = "toggle",
							order = 10,
							name = L["Show numbers"],
							desc = L["Show numbers in command list"],
						},
						showIcons = {
							type = "toggle",
							order = 20,
							name = L["Show icons"],
							desc = L["Show icons in command list"],
						},
						clean = {
							type = "execute",
							name = L["Clear"],
							desc = L["Clear unused command entries"],
							func = clearCommands,
						},
					},
				},
			},
		}
	elseif appName == (addonName .. "-Commands") then
		local cmdArgs = {}
		for i = 1, COMMAND_NUMBER do
			cmdArgs["cmd"..i] = getCommandOptions(i)
		end
		return {
			type = "group",
			name = L["Commands"],
			args = cmdArgs,
		}
	end
end

-- Event
local configChangedEvent

function mod:OnInitialize()
	local function handler(name, cat)
		local _, sectionName = ("-"):split(cat.obj.userdata.appName)
		sectionName = sectionName:lower()
		if name == "default" then
			db[sectionName] = merge({}, defaults.profile[sectionName])
		end
		configChangedEvent(sectionName)
	end
	local function addHandlers(category)
		-- OK clicked
		category.okay = function(cat) return handler("okay", cat) end
		-- Cancel clicked: we apply changes immediately and cannot revert them
		-- category.cancel = function(cat) return handler("cancel", cat) end
		-- default clicked
		category.default = function(cat) return handler("default", cat) end
		-- refresh requested: settings are refreshed automatically
		-- category.refresh = function(cat) return handler("refresh", cat) end
	end

	Event = XKeyBinding:GetModule("Event")

	configChangedEvent = Event:New("OnConfigChanged")

	self.db = LibStub("AceDB-3.0"):New(addonName .. "DB", defaults, true)
	db = self.db.profile

	local myName = addonMetadata.title
	local acRegistry = LibStub("AceConfigRegistry-3.0")
	local acDialog = LibStub("AceConfigDialog-3.0")

	acRegistry:RegisterOptionsTable(addonName .. "-General", getOptions)
	acRegistry:RegisterOptionsTable(addonName .. "-Commands", getOptions)

	addHandlers(acDialog:AddToBlizOptions(addonName .. "-General", myName))
	addHandlers(acDialog:AddToBlizOptions(addonName .. "-Commands", L["Commands"], myName))

	local popts = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	acRegistry:RegisterOptionsTable(addonName .. "-Profiles", popts)
	acDialog:AddToBlizOptions(addonName .. "-Profiles", L["Profiles"], myName)
--[[
	self:RegisterChatCommand("xpbar", openSettings)
]]

	self.db.RegisterCallback(self, "OnProfileChanged", self.RefreshConfig)
	self.db.RegisterCallback(self, "OnProfileCopied", self.RefreshConfig)
	self.db.RegisterCallback(self, "OnProfileReset", self.RefreshConfig)
end

function mod:RefreshConfig(event, data, newProfileKey)
	db = data.profile
	configChangedEvent(db)
end

mod.COMMAND_NUMBER = COMMAND_NUMBER

mod.TYPES = merge(commandTypes)

function mod:GetDB()
	return mergeUniques(db)
end

function mod:SetConfigChanged(func, receiver)
	configChangedEvent:AddHandler(func, receiver)
end
