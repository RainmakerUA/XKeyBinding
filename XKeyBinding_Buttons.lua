--[=====[
		## Extended Key Binding ver. @@release-version@@
		## XKeyBinding_Buttons.lua - module
		Buttons module for XKeyBinding addon
--]=====]

local addonName = ...
local XKeyBinding = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Buttons = XKeyBinding:NewModule("Buttons")

local Utils = LibStub("rmUtils-1.1")

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local loadstring = loadstring
local pcall = pcall
local tinsert = table.insert
local tostring = tostring
local unpack = unpack
local CreateFrame = CreateFrame
local UIParent = UIParent
local GetCVar = C_CVar.GetCVar
local GetCVarDefault = C_CVar.GetCVarDefault
local SetCVar = C_CVar.SetCVar

local Config

local mod = Buttons

local buttons = {}
local types

local notifyEvent

--@debug@
Buttons.buttons = buttons
--@end-debug@

local function createButton(index)
	local name = ("XBoundButton%02d"):format(index)
	local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
	button:SetSize(1, 1)
	button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -1, - 1)
	button:RegisterForClicks("LeftButtonDown")
	button:Show()
	return button
end

local function enableButton(button)
	if button then
		button:Enable()
		button:Show()
		button:SetParent(UIParent)
	end
	return button
end

local function disableButton(button)
	button:Disable()
	button:Hide()
	button:SetParent(nil)
end

local function getMainHandler(cmdType, text)
	if cmdType == types.CVAR_TOGGLE then
		local params = {}
		for str in text:gmatch("[^%s]+") do
			tinsert(params, str)
		end
		local cvar, off, on = unpack(params)
		local def = GetCVarDefault(cvar)
		return function()
			local old = GetCVar(cvar) or def
			if old then
				if old == off then
					SetCVar(cvar, on)
					return cvar, true
				end
				if old == on then
					SetCVar(cvar, off)
					return cvar, false
				end
			end
			return cvar, nil
		end
	elseif cmdType == types.LUA_CODE then
		local func, error = loadstring(text, "Lua block")
		if func then
			return function()
				local success, result = pcall(func)
				return success, result
			end
		else
			return function()
				return nil, error
			end
		end
	else
		return nil
	end
end

local function getNotifyHandler(cmd, index)
	local failType = types.DISABLED
	local cmdType = cmd.type
	local shortName = "XKB: "
	local handler = nil
	if cmdType == types.MACRO_NAME then
		handler = shortName .. L["Invoked Macro by name: "] .. cmd.text:trim()
	elseif cmdType == types.MACRO_TEXT then
		handler = shortName .. L["Invoked Macro sequence "] .. cmd.name
	elseif cmdType == types.CVAR_TOGGLE then
		handler = function(cvar, result)
			if result == nil then
				notifyEvent(index, failType, shortName .. L["CVar not found or inaccessible: "] .. cvar)
			else
				notifyEvent(index, cmdType, shortName .. L["CVar |c20ff20ff%s|r was set to "]:format(cvar)
														.. (result and L["|cff00ff00On|r"] or L["|cffff1010Off|r"]))
			end
		end
	elseif cmdType == types.LUA_CODE then
		handler = function(result, msg)
			if result == nil then
				notifyEvent(index, failType, shortName .. L["Error while parsing code:\n"] .. msg)
			elseif not result then
				notifyEvent(index, failType, shortName .. L["Error while running code:\n"] .. msg)
			else
				if msg then
					result = shortName .. L["Lua code: "] .. tostring(msg)
				else
					result = shortName .. L["Lua code executed"]
				end
				return notifyEvent(index, cmdType, result)
			end
		end
	end

	return type(handler) == "function" and handler
			or function()
					notifyEvent(index, cmdType, handler)
				end
end

local function getOnClickHandler(cmd, index)
	local main = getMainHandler(cmd.type, cmd.text)
	local notify = getNotifyHandler(cmd, index)
	if main then
		return function(--[[self, button, down]])
			notify(main())
		end
	else
		return notify
	end
end

function mod:OnInitialize()
    notifyEvent = Utils.Event.New("OnNotify")

	Config = XKeyBinding:GetModule("Config")
	types = Config.TYPES
end

function mod:RefreshButtons(data)
	for i, cmd in ipairs(data) do
		local btn = buttons[i]
		if not btn or btn.unique ~= cmd.unique then
			if cmd and cmd.type ~= types.DISABLED and cmd.text and #(cmd.text:trim()) > 0 then
				local text = cmd.text:trim()
				btn = enableButton(btn) or createButton(i, btn)
				btn.unique = cmd.unique
				buttons[i] = btn
				if cmd.type == types.MACRO_NAME then
					btn:SetAttribute("type", "macro")
					btn:SetAttribute("macrotext", nil)
					btn:SetAttribute("macro", text)
				elseif cmd.type == types.MACRO_TEXT then
					btn:SetAttribute("type", "macro")
					btn:SetAttribute("macro", nil)
					btn:SetAttribute("macrotext", text)
				else
					btn:SetAttribute("type", nil)
					btn:SetAttribute("macro", nil)
					btn:SetAttribute("macrotext", nil)
				end
				btn:SetScript("PostClick", getOnClickHandler(cmd, i))
			elseif btn then
				disableButton(btn)
			end
		end
	end
end

function mod:SetNotify(func, receiver)
	notifyEvent:AddHandler(func, receiver)
end
