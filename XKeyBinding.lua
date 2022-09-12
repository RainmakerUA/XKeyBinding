--[=====[
		## Extended Key Binding ver. @@release-version@@
		## XKeyBinding.lua - module
		Main module for XKeyBinding addon
--]=====]

local addonName = ...
local XKeyBinding = LibStub("AceAddon-3.0"):NewAddon(addonName)
local Main = XKeyBinding:NewModule("Main")

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local setglobal = setglobal
local tinsert = table.insert
local type = type
local GetAddOnMetadata = GetAddOnMetadata
local UIErrorsFrame = UIErrorsFrame
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
local LE_GAME_ERR_SYSTEM = LE_GAME_ERR_SYSTEM

local mod = Main

local Config
local Buttons

local notificationColors = {}

function mod:OnInitialize()
	Config = XKeyBinding:GetModule("Config")
	Buttons = XKeyBinding:GetModule("Buttons")

	--@debug@
	_G["XKeyBinding"] = XKeyBinding
	XKeyBinding.Buttons = Buttons
	XKeyBinding.Config = Config
	XKeyBinding.Main = Main
	--@end-debug@

	local name = GetAddOnMetadata(addonName, "Title")
	setglobal("XKB_ADDON", name)
	setglobal("BINDING_HEADER_XBOUND_KEYS", name)
	for i = 1, Config.COMMAND_NUMBER do
		setglobal(("BINDING_NAME_CLICK XBoundButton%02d:LeftButton"):format(i), L["Command #"] .. i)
	end

	do
		local function getColorTable(r, g, b)
			return { r = r, g = g, b = b }
		end
		local types = Config.TYPES

		notificationColors[types.DISABLED] = getColorTable(1, 0.3, 0.3)
		notificationColors[types.MACRO_NAME] = getColorTable(0.3, 0.3, 1)
		notificationColors[types.MACRO_TEXT] = getColorTable(0.5, 0.5, 1)
		notificationColors[types.CVAR_TOGGLE] = getColorTable(0.8, 0.8, 0.8)
		notificationColors[types.LUA_CODE] = getColorTable(1, 1, 0.5)
	end
end

function mod:OnEnable()
	Config:SetConfigChanged(self)
	Buttons:SetNotify(self)

	self:OnConfigChanged()
end

function mod:OnConfigChanged(data)
	if type(data) == "table" then
		Buttons:RefreshButtons(data.commands)
	else
		local db = Config:GetDB()
		if not data or data == "general" then
			-- Empty
		end
		if not data or data == "commands" then
			Buttons:RefreshButtons(db.commands)
		end
	end
end

function mod:OnNotify(index, cmdType, message)
	local colors = notificationColors[cmdType]
	local frames = {}
	local cmd = Config:GetDB().commands[index]
	if cmd.notifyScreen then
		tinsert(frames, UIErrorsFrame)
	end
	if cmd.notifyChat then
		tinsert(frames, DEFAULT_CHAT_FRAME)
	end
	for _, fr in ipairs(frames) do
		fr:AddMessage(message, colors.r, colors.g, colors.b, 1, LE_GAME_ERR_SYSTEM)
	end
end
