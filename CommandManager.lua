--[[
	* Copyright (c) 2011-2012 by Adam Hellberg.
	*
	* This file is part of Command.
	*
	* Command is free software: you can redistribute it and/or modify
	* it under the terms of the GNU General Public License as published by
	* the Free Software Foundation, either version 3 of the License, or
	* (at your option) any later version.
	*
	* Command is distributed in the hope that it will be useful,
	* but WITHOUT ANY WARRANTY; without even the implied warranty of
	* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	* GNU General Public License for more details.
	*
	* You should have received a copy of the GNU General Public License
	* along with Command. If not, see <http://www.gnu.org/licenses/>.
--]]

-- Upvalues
local type = type
local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local select = select
local tinsert = table.insert
local tostring = tostring
local tonumber = tonumber

-- API Upvalues
local SetCVar = SetCVar
local UnitName = UnitName
local FollowUnit = FollowUnit
local ShowUIPanel = ShowUIPanel
local HideUIPanel = HideUIPanel
local AcceptGroup = AcceptGroup
local DoReadyCheck = DoReadyCheck
local ConvertToRaid = ConvertToRaid
local GetLFGProposal = GetLFGProposal
local ConvertToParty = ConvertToParty
local ConfirmReadyCheck = ConfirmReadyCheck
local StaticPopup_Visible = StaticPopup_Visible
local ClearAllLFGDungeons = ClearAllLFGDungeons
local GetReadyCheckStatus = GetReadyCheckStatus
local GetReadyCheckTimeLeft = GetReadyCheckTimeLeft

local C = Command

--- Table holding all CommandManager methods.
-- This is referenced "CM" in CommandManager.lua.
-- @name Command.CommandManager
-- @class table
-- @field Slash List of slash commands to register.
-- @field Commands Table holding all registered commands.
--
C.CommandManager = {
	Slash = {
		"command",
		"cmd"
	},
	Commands = {}
}

local L = C.LocaleManager
local CM = C.CommandManager
local PM = C.PlayerManager
local EM = C.EmoteManager
local QM = C.QueueManager
local RM = C.RollManager
local LM = C.LootManager
local GT = C.GroupTools
local AM = C.AuthManager
local DM = C.DeathManager
local SM = C.SummonManager
local IM = C.InviteManager
local FM = C.FactsManager
local CDM = C.DuelManager
local CRM = C.RoleManager
local RCM = C.ReadyCheckManager
local Chat
local CES = C.Extensions.String
local CET = C.Extensions.Table
local CEN = C.Extensions.Number

--- Initialize CommandManager.
--
function CM:Init()
	Chat = C.ChatManager
end

--- Register a new command.
-- @param command Table containing aliases for the command.
-- @param access Number depicting the access level needed to execute command.
-- @param func Function called to execute command. Called with params args, player and isChat.
-- @param help Message describing how the command should be used.
--
function CM:Register(names, access, func, help)
	help = help or "CM_NO_HELP"
	if type(names) == "string" then
		names = {names}
	end
	if names[1] ~= "__DEFAULT__" then
		names[1] = names[1]:lower()
	end
	local entry =
	{
		Name = names[1],
		Access = access,
		Call = func,
		Help = help or "CM_NO_HELP",
		Alias = {}
	}
	if #names > 1 then
		for i=2,#names do
			tinsert(entry.Alias, names[i]:lower())
		end
	end
	self.Commands[names[1]] = entry
end

--- Check whether or not a command is registered.
-- This does NOT take aliases into account.
-- @param command Command name to check.
--
function CM:HasCommand(command)
	command = command:lower()
	if self.Commands[command] then return true end
	for k,v in pairs(self.Commands) do
        if command:match(k) or CET:HasValue(v.Alias, command) then return true end
	end
	return false
end

--- Gets the callback for a command by name.
-- @param command Name of the command to get.
-- @return Callback for the command, nil if no command was found.
--
function CM:GetCommand(command)
	command = command:lower()
	if self.Commands[command] then
		return self.Commands[command]
	end
	for k,v in pairs(self.Commands) do
		if command:match(k) or CET:HasValue(v.Alias, command) then return v end
	end
	return self.Commands.__DEFAULT__ or nil -- We don't really need "or nil" here.
end

function CM:GetRealName(name)
	name = name:lower()
	if self.Commands[name] then return name end
	for k,v in pairs(self.Commands) do
		if name:match(k) or CET:HasValue(v.Alias, name) then return k end
	end
	return nil
end

function CM:GetCommands(all) -- NOTE: Only returns the NAMES, not the actual command function
	local t = {}
	for k,v in pairs(self.Commands) do
		if k ~= "__DEFAULT__" or all then
			tinsert(t, k)
		end
		if all and #v.Alias > 0 then
			for _,a in pairs(v.Alias) do
				tinsert(t, a)
			end
		end
	end
	return t
end

--- Calls command with supplied args.
-- @param command Command to call (name)
-- @param args Table with arguments for the command.
-- @param isChat Is the command called from chat?
-- @param player Player object of the calling player (if chat)
-- @param bnetInfo Information about the B.Net sender (if called from B.Net chat)
-- @return If successfull, returns result, otherwise false.
-- @return Error message if not successful, otherwise nil.
--
function CM:HandleCommand(command, args, isChat, player, bnetInfo)
	command = tostring(command):lower()
	local cmd = self:GetCommand(command)
	if cmd then
		if isChat then
			if not PM:IsCommandAllowed(cmd) and player.Info.Name ~= UnitName("player") then
				return false, "CM_ERR_NOTALLOWED", {cmd.Name, player.Info.Name}
			elseif not PM:HasAccess(player, cmd) then
				return false, "CM_ERR_NOACCESS", {player.Info.Name, cmd.Access, PM:GetAccess(player)}
			end
		end
		local result, arg, errArg = cmd.Call(args, player, isChat, bnetInfo)
		if type(result) == "nil" then
			return nil
		end
		return result, arg, errArg
	else
		return false, "CM_ERR_NOTREGGED", {tostring(command)}
	end
end

--- Prints all command names together with their help messages.
--
function CM:AutoHelp()
	local l = L:GetActive()
	for k,v in pairs(self.Commands) do
		C.Logger:Normal(("/%s %s"):format(self.Slash[1], k))
		C.Logger:Normal(("      - %s"):format(l[v.Help]))
	end
end

function CM:GetHelp(cmd)
	cmd = tostring(cmd):lower()
	if not self:HasCommand(cmd) then return false, "CM_ERR_NOTREGGED" end
	local command = self:GetCommand(cmd)
	return command.Help or "CM_NO_HELP"
end


CM:Register({"__DEFAULT__"}, PM.Access.Local, function(args, sender, isChat, bnetInfo)
	if isChat then
		return "CM_DEFAULT_CHAT"
	end
	CM:AutoHelp()
	C.Logger:Normal(L("CM_DEFAULT_HELPCOMMAND"))
	return "CM_DEFAULT_END"
end, "CM_DEFAULT_HELP")

CM:Register({"help", "h"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if #args <= 0 then
		if isChat then
			return "CM_DEFAULT_CHAT"
		end
		return false, "CM_HELP_USAGE"
	end
	return CM:GetHelp(tostring(args[1]):lower())
end, "CM_HELP_HELP")

CM:Register({"commands", "cmds", "cmdlist", "listcmds", "listcommands", "commandlist"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	local all
	if #args > 0 then
		all = args[1] == "all"
	end
	local cmds = CM:GetCommands(all)
	return Chat.SpecialOutput.RawTable, CES:Fit(cmds, 240, ", ") -- Max length is 255, "[Command] " takes up 10. This leaves us with 5 characters grace.
end, "CM_COMMANDS_HELP")

CM:Register({"version", "ver", "v"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	return "CM_VERSION", {C.Version}
end, "CM_VERSION_HELP")

CM:Register({"set", "s"}, PM.Access.Groups.Admin.Level, function(args, sender, isChat, bnetInfo)
	if #args <= 0 then
		return false, "CM_SET_USAGE"
	end
	local mod = args[1]:lower()
	if mod:match("^c") then -- Command Char setting
		if #args < 2 then
			return false, "CM_ERR_NOCMDCHAR"
		end
		return Chat:SetCmdChar(args[2])
	elseif mod:match("^de") then -- DeathManager
		if #args < 2 then
			if DM:IsEnabled() then
				return "CM_SET_DM_ISENABLED"
			end
			return "CM_SET_DM_ISDISABLED"
		end
		if isChat then -- Players are only allowed to check status of DeathManager
			return false, "CM_ERR_NOCHAT"
		end
		local setting = args[2]:lower()
		if setting:match("^(s.*)?rel.*d") then -- (Set) release delay
			if #args < 3 then
				return "CM_SET_DM_RELEASEDELAY_CURRENT", {CEN:FormatSeconds(DM:GetReleaseDelay())}
			end
			local newDelay = tonumber(args[3])
			if not newDelay then return false, "CM_SET_DM_RELEASEDELAY_USAGE" end
			return DM:SetReleaseDelay(newDelay)
		elseif setting:match("^[eay].*rel.*a") then -- Enable release announce
			return DM:EnableReleaseAnnounce()
		elseif setting:match("^[dn].*rel.*a") then -- Disable release announce
			return DM:DisableReleaseAnnounce()
		elseif setting:match("^[eay].*rel") then -- Enable release
			return DM:EnableRelease()
		elseif setting:match("^[dn].*rel") then -- Disable release
			return DM:DisableRelease()
		elseif setting:match("^(s?.*)r.*d") then -- (Set) ress delay
			if #args < 3 then
				return "CM_SET_DM_RESURRECTDELAY_CURRENT", {CEN:FormatSeconds(DM:GetResurrectDelay())}
			end
			local newDelay = tonumber(args[3])
			if not newDelay then return false, "CM_SET_DM_RESURRECTDELAY_USAGE" end
			return DM:SetResurrectDelay(newDelay)
		elseif setting:match("^[eay].*r.*a") then -- Enable ress announce
			return DM:EnableResurrectAnnounce()
		elseif setting:match("^[dn].*r.*a") then -- Disable ress announce
			return DM:DisableResurrectAnnounce()
		elseif setting:match("^[eay].*r") then -- Enable ress
			return DM:EnableResurrect()
		elseif setting:match("^[dn].*r") then -- Disable ress
			return DM:DisableResurrect()
		elseif setting:match("^[eay]") then -- Enable
			return DM:Enable()
		elseif setting:match("^[dn]") then -- Disable
			return DM:Disable()
		elseif setting:match("^t.*rel.*a") then -- Toggle release announce
			return DM:ToggleReleaseAnnounce()
		elseif setting:match("^t.*rel") then -- Toggle release
			return DM:ToggleRelease()
		elseif setting:match("^t.*r.*a") then -- Toggle resurrect announce
			return DM:ToggleResurrectAnnounce()
		elseif setting:match("^t.*r") then -- Toggle resurrect
			return DM:ToggleResurrect()
		elseif setting:match("^t") then -- Toggle
			return DM:Toggle()
		end
		return false, "CM_SET_DM_USAGE"
	elseif mod:match("^s") then -- SummonManager
		if #args < 2 then
			if SM:IsEnabled() then
				return "CM_SET_SM_ISENABLED"
			end
			return "CM_SET_SM_ISDISABLED"
		end
		if isChat then -- Players are only allowed to check status of SummonManager
			return false, "CM_ERR_NOCHAT"
		end
		local setting = args[2]:lower()
		if setting:match("^[eay].*a") then -- Enable Announce
			return SM:EnableAnnounce()
		elseif setting:match("^[dn].*a") then -- Disable Announce
			return SM:DisableAnnounce()
		elseif setting:match("^a.*t") or setting:match("^t.*a") then -- Toggle Announce
			return SM:ToggleAnnounce()
		elseif setting:match("^[eay]") then -- Enable
			return SM:Enable()
		elseif setting:match("^di") or setting:match("^n") then -- Disable
			return SM:Disable()
		elseif setting:match("^to") then -- Toggle
			return SM:Toggle()
		elseif setting:match("^[std]") then -- (Set) Delay
			if #args < 3 then
				return "CM_SET_SM_DELAY_CURRENT", {SM:GetDelay()}
			end
			local newDelay = tonumber(args[3])
			if not newDelay then return false, "CM_SET_SM_DELAY_USAGE" end
			return SM:SetDelay(newDelay)
		end
		return false, "CM_SET_SM_USAGE"
	elseif mod:match("^i") then -- InviteManager
		if #args < 2 then
			if IM:IsEnabled() then
				return "CM_SET_IM_ISENABLED"
			end
			return "CM_SET_IM_ISDISABLED"
		end
		if isChat then -- Players are only allowed to check status of InviteManager
			return false, "CM_ERR_NOCHAT"
		end
		local setting = args[2]:lower()
		if setting:match("^[eay]") then -- Enable
			return IM:Enable()
		elseif setting:match("^[dn]") then -- Disable
			return IM:Disable()
		elseif setting:match("^t") then -- Toggle
			return IM:Toggle()
		elseif setting:match("^gu.*d") or setting:match("¨gu.*s.*d") then -- Set Guild Delay
			if #args < 3 then
				return "CM_SET_IM_GUILD_DELAY_CURRENT", {IM:GetGuildDelay()}
			end
			local newDelay = tonumber(args[3])
			if not newDelay then return false, "CM_SET_IM_GUILD_DELAY_USAGE" end
			return IM:SetGuildDelay(newDelay)
		elseif setting:match("^gu.*[dn].*d") then -- Disable Guild Delay
			return IM:DisableGuildDelay()
		elseif setting:match("^gu.*[eay].*a") then -- Enable Guild Announce
			return IM:EnableGuildAnnounce()
		elseif setting:match("^gu.*[dn].*a") then -- Disable Guild Announce
			return IM:DisableGuildAnnounce()
		elseif setting:match("^gu.*t.*a") then -- Toggle Guild Announce
			return IM:ToggleGuildAnnounce()
		elseif setting:match("^gu.*[eay].*o") then -- Enable Guild Override
			return IM:EnableGuildOverride()
		elseif setting:match("^gu.*[dn].*o") then -- Disable Guild Override
			return IM:DisableGuildOverride()
		elseif setting:match("^gu.*t.*o") then -- Toggle Guild Override
			return IM:ToggleGuildOverride()
		elseif setting:match("^gu.*[eay]") then -- Enable Guild
			return IM:EnableGuild()
		elseif setting:match("^gu.*[dn]") then -- Disable Guild
			return IM:DisableGuild()
		elseif setting:match("^gu.*t") then -- Toggle Guild
			return IM:ToggleGuild()
		elseif setting:match("^g.*d") or setting:match("^g.*s.*d") then -- Set Group Delay
			if #args < 3 then
				return "CM_SET_IM_GROUP_DELAY_CURRENT", {IM:GetGroupDelay()}
			end
			local newDelay = tonumber(args[3])
			if not newDelay then return false, "CM_SET_IM_GROUP_DELAY_USAGE" end
			return IM:SetGroupDelay(newDelay)
		elseif setting:match("^g.*[dn].*d") then -- Disable Group Delay
			return IM:DisableGroupDelay()
		elseif setting:match("^g.*[eay].*a") then -- Enable Group Announce
			return IM:EnableGroupAnnounce()
		elseif setting:match("^g.*[dn].*a") then -- Disable Group Announce
			return IM:DisableGroupAnnounce()
		elseif setting:match("^g.*t.*a") then -- Toggle Group Announce
			return IM:ToggleGroupAnnounce()
		elseif setting:match("^g.*[eay]") then -- Enable Group
			return IM:EnableGroup()
		elseif setting:match("^g.*[dn]") then -- Disable Group
			return IM:DisableGroup()
		elseif setting:match("^g.*t") then -- Toggle Group
			return IM:ToggleGroup()
		end
		return false, "CM_SET_IM_USAGE"
	elseif mod:match("^d") then -- DuelManager
		if #args < 2 then
			if CDM:IsEnabled() then
				return "CM_SET_CDM_ISENABLED"
			end
			return "CM_SET_CDM_ISDISABLED"
		end
		if isChat then -- Players are only allowed to check status of DuelManager
			return false, "CM_ERR_NOCHAT"
		end
		local setting = args[2]:lower()
		if setting:match("^[eay].*a") then -- Enable Announce
			return CDM:EnableAnnounce()
		elseif setting:match("^[dn].*a") then -- Disable Announce
			return CDM:DisableAnnounce()
		elseif setting:match("^a.*t") then -- Toggle Announce
			return CDM:ToggleAnnounce()
		elseif setting:match("^s.*d") or setting:match("^de") then -- Set Delay
			if #args < 3 then
				return "CM_SET_CDM_DELAY_CURRENT", {CDM:GetDelay()}
			end
			local newDelay = tonumber(args[3])
			if not newDelay then return false, "CM_SET_CDM_DELAY_USAGE" end
			return CDM:SetDelay(newDelay)
		elseif setting:match("^[eay]") then -- Enable
			return CDM:Enable()
		elseif setting:match("^[dn]") then -- Disable
			return CDM:Disable()
		end
		return false, "CM_SET_CDM_USAGE"
	elseif mod:match("^r") then -- RoleManager
		if #args < 2 then
			if CRM:IsEnabled() then
				return "CM_SET_CRM_ISENABLED"
			end
			return "CM_SET_CRM_ISDISABLED"
		end
		if isChat then -- Players are only allowed to check the status of RoleManager
			return false, "CM_ERR_NOCHAT"
		end
		local setting = args[2]:lower()
		if setting:match("^[eay].*a") then -- Enable Announce
			return CRM:EnableAnnounce()
		elseif setting:match("^[dn].*a") then -- Disable Announce
			return CRM:DisableAnnounce()
		elseif setting:match("^a.*t") or setting:match("^t.*a") then -- Toggle Announce
			return CRM:ToggleAnnounce()
		elseif setting:match("^s.*d") or setting:match("^de") then -- (Set) Delay
			if #args < 3 then
				return "CM_SET_CRM_DELAY_CURRENT", {CRM:GetDelay()}
			end
			local newDelay = tonumber(args[3])
			if not newDelay then return false, "CM_SET_CRM_DELAY_USAGE" end
			return CRM:SetDelay(newDelay)
		elseif setting:match("^[eay]") then -- Enable
			return CRM:Enable()
		elseif setting:match("^[dn]") then -- Disable
			return CRM:Disable()
		elseif setting:match("^t") then -- Toggle
			return CRM:Toggle()
		end
		return false, "CM_SET_CDM_USAGE"
	end
	return false, "CM_SET_USAGE"
end, "CM_SET_HELP")

CM:Register({"locale", "loc"}, PM.Access.Local, function(args, sender, isChat, bnetInfo)
	if isChat then return false, "CM_ERR_NOCHAT" end
	if #args <= 0 then
		return "CM_LOCALE_CURRENT", {L.Settings.LOCALE}
	end
	local arg = tostring(args[1]):lower()
	if arg:match("^s") then -- Set
		if #args < 2 then
			return false, "CM_LOCALE_SET_USAGE"
		end
		return L:SetLocale(tostring(args[2]):lower())
	elseif arg:match("^r") or arg:match("^u.*a") then -- Reset / Use Active
		return L:ResetLocale()
	elseif arg:match("^u.*m") then -- Use Master
		return L:UseMasterLocale()
	elseif arg:match("^p.*i") then -- Player Independent
		local enabled = tostring(args[3]):lower()
		if enabled:match("^[eay]") then
			return L:EnablePlayerIndependent()
		elseif enabled:match("^[dn]") then
			return L:DisablePlayerIndependent()
		end
		return L:TogglePlayerIndependent()
	end
	return false, "CM_LOCALE_USAGE"
end, "CM_LOCALE_HELP")

CM:Register({"mylocale", "ml"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not isChat then
		return false, "CM_ERR_CHATONLY"
	end
	if #args >= 1 then
		local locale = args[1]:lower()
		if L:LocaleLoaded(locale) then
			sender.Settings.Locale = locale
			PM:UpdatePlayer(sender)
			return "CM_MYLOCALE_SET", {locale}
		end
		return false, "LOCALE_NOT_LOADED"
	else -- Reset user locale
		sender.Settings.Locale = L.Active
		PM:UpdatePlayer(sender)
		return "CM_MYLOCALE_SET", {L.Active}
	end
end, "CM_MYLOCALE_HELP")

CM:Register({"lock", "lockdown"}, PM.Access.Groups.Admin.Level, function(args, sender, isChat, bnetInfo)
	if type(args[1]) == "string" then
		return PM:SetLocked(PM:GetOrCreatePlayer(args[1]), true)
	else
		return PM:SetLocked(sender, true)
	end
end, "CM_LOCK_HELP")

CM:Register({"unlock", "open"}, PM.Access.Groups.Admin.Level, function(args, sender, isChat, bnetInfo)
	if type(args[1]) == "string" then
		return PM:SetLocked(PM:GetOrCreatePlayer(args[1]), false)
	else
		return PM:SetLocked(sender, false)
	end
end, "CM_UNLOCK_HELP")

CM:Register({"getaccess"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if type(args[1]) == "string" then
		local player = PM:GetOrCreatePlayer(args[1])
		return "CM_GETACCESS_STRING", {player.Info.Name, PM.Access.Groups[player.Info.Group].Level, player.Info.Group}
	else
		return "CM_GETACCESS_STRING", {sender.Info.Name, PM.Access.Groups[sender.Info.Group].Level, sender.Info.Group}
	end
end, "CM_GETACCESS_HELP")

CM:Register({"setaccess"}, PM.Access.Local, function(args, sender, isChat, bnetInfo)
	if #args < 1 then
		return false, "CM_SETACCESS_USAGE"
	end
	if #args >= 2 then
		local player = PM:GetOrCreatePlayer(args[1])
		return PM:SetAccessGroup(player, args[2])
	else
		return PM:SetAccessGroup(sender, args[1])
	end
end, "CM_SETACCESS_HELP")

CM:Register({"owner"}, PM.Access.Local, function(args, sender, isChat, bnetInfo)
	if isChat then
		return false, "CM_ERR_NOCHAT"
	end
	local player = PM:GetOrCreatePlayer(UnitName("player"))
	return PM:SetOwner(player)
end, "CM_OWNER_HELP")

CM:Register({"admin"}, PM.Access.Groups.Owner.Level, function(args, sender, isChat, bnetInfo)
	if isChat then
		return false, "CM_ERR_NOCHAT"
	end
	if #args <= 0 then
		return false, "CM_ADMIN_USAGE"
	end
	local player = PM:GetOrCreatePlayer(args[1])
	return PM:SetAdmin(player)
end, "CM_ADMIN_HELP")

CM:Register({"op"}, PM.Access.Groups.Admin.Level, function(args, sender, isChat, bnetInfo)
	if type(args[1]) == "string" then
		local player = PM:GetOrCreatePlayer(args[1])
		return PM:SetOp(player)
	else
		return PM:SetOp(sender)
	end
end, "CM_OP_HELP")

CM:Register({"user"}, PM.Access.Groups.Op.Level, function(args, sender, isChat, bnetInfo)
	if type(args[1]) == "string" then
		local player = PM:GetOrCreatePlayer(args[1])
		return PM:SetUser(player)
	else
		return PM:SetUser(sender)
	end
end, "CM_USER_HELP")

CM:Register({"ban"}, PM.Access.Groups.Admin.Level, function(args, sender, isChat, bnetInfo)
	if #args <= 0 then
		return false, "CM_BAN_USAGE"
	end
	local player = PM:GetOrCreatePlayer(args[1])
	return PM:BanUser(player)
end, "CM_BAN_HELP")

CM:Register({"auth", "authenticate", "a"}, PM.Access.Local, function(args, sender, isChat, bnetInfo)
	if isChat and isChat ~= "WHISPER" then return false, "CM_ERR_NOCHAT" end
	if #args < 2 then return false, "CM_AUTH_USAGE" end
	local arg = tostring(args[1]):lower()
	local target = tostring(args[2]):upper()
	local notify = true
	if target == UnitName("player"):upper() then return false, "CM_AUTH_ERR_SELF" end
	if sender.Info.Name:upper() == target then notify = false end
	if arg:match("^a") then -- Add
		local level = tonumber(args[3])
		local pass = args[4]
		if not level then
			return false, "CM_AUTH_ADDUSAGE"
		end
		return AM:Add(target, level, pass, notify)
	elseif arg:match("^r") then -- Remove
		return AM:Remove(target)
	elseif arg:match("^e") then -- Enable
		return AM:Enable(target)
	elseif arg:match("^d") then -- Disable
		return AM:Disable(target)
	end
	return false, "CM_AUTH_USAGE"
end, "CM_AUTH_HELP")

CM:Register({"authme", "authenticateme", "am"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not isChat then return false, "CM_ERR_CHATONLY" end
	if #args <= 0 then return false, "CM_AUTHME_USAGE" end
	local pass = tostring(args[1])
	return AM:Authenticate(sender.Info.Name, pass)
end, "CM_AUTHME_HELP")

CM:Register({"accept", "acceptinvite", "acceptinv", "join", "joingroup"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not IM:IsEnabled() or not IM:IsGroupEnabled() then
		return "CM_ERR_DISABLED"
	end
	return IM:AcceptGroupInvite()
end, "CM_ACCEPTINVITE_HELP")

CM:Register({"decline", "declineinvite", "declineinv", "cancelinvite", "cancelinv"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not IM:IsEnabled() or not IM:IsGroupEnabled() then
		return "CM_ERR_DISABLED"
	end
	return IM:DeclineGroupInvite()
end, "CM_DECLINEINVITE_HELP")

CM:Register({"acceptguildinvite", "acceptginvite", "acceptguildinv", "acceptginv"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not IM:IsEnabled() or not IM:IsGuildEnabled() then
		return "CM_ERR_DISABLED"
	end
	return IM:AcceptGuildInvite()
end, "CM_ACCEPTGUILDINVITE_HELP")

CM:Register({"declineguildinvite", "declineginvite", "declineguildinv", "declineginv"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not IM:IsEnabled() or not IM:IsGuildEnabled() then
		return "CM_ERR_DISABLED"
	end
	return IM:DeclineGuildInvite()
end, "CM_DECLINEGUILDINVITE_HELP")

CM:Register({"invite", "inv"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	local pID
	if bnetInfo then pID = bnetInfo.PresenceID end
	if type(args[1]) == "string" then
		local player = PM:GetOrCreatePlayer(args[1])
		return PM:Invite(player, sender, pID, tostring(args[2]):lower():match("^f"))
	else
		return PM:Invite(sender, sender, pID)
	end
end, "CM_INVITE_HELP")

CM:Register({"inviteme", "invme"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not isChat then
		return false, "CM_ERR_CHATONLY"
	end
	local pID
	if bnetInfo then pID = bnetInfo.PresenceID end
	return PM:Invite(sender, sender, pID, tostring(args[2]):lower():match("^f"))
end, "CM_INVITEME_HELP")

CM:Register({"blockinvites", "blockinvite", "denyinvites", "denyinvite"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not isChat then
		return false, "CM_ERR_CHATONLY"
	end
	return PM:DenyInvites(sender, isChat == "WHISPER" or isChat == "BNET")
end, "CM_DENYINVITE_HELP")

CM:Register({"allowinvites", "allowinvite"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not isChat then
		return false, "CM_ERR_CHATONLY"
	end
	return PM:AllowInvites(sender, isChat == "WHISPER" or isChat == "BNET")
end, "CM_ALLOWINVITE_HELP")

CM:Register({"kick"}, PM.Access.Groups.Op.Level, function(args, sender, isChat, bnetInfo)
	if #args <= 0 then
		return false, "CM_KICK_USAGE"
	end
	local player = PM:GetOrCreatePlayer(args[1])
	local reason = (args[2] or ""):lower()
	local override = args[3] ~= nil
	if (reason == "override" or reason == "true") and #args == 2 then
		reason = nil
		override = true
	end
	return PM:Kick(player, sender, reason, override)
end, "CM_KICK_HELP")

CM:Register({"kingme", "givelead"}, PM.Access.Groups.Op.Level, function(args, sender, isChat, bnetInfo)
	if not isChat then
		return false, "CM_ERR_CHATONLY"
	end
	return PM:PromoteToLeader(sender)
end, "CM_KINGME_HELP")

CM:Register({"opme", "assistant", "assist"}, PM.Access.Groups.Op.Level, function(args, sender, isChat, bnetInfo)
	if not isChat then
		return false, "CM_ERR_CHATONLY"
	end
	return PM:PromoteToAssistant(sender)
end, "CM_OPME_HELP")

CM:Register({"deopme", "deassistant", "deassist"}, PM.Access.Groups.Op.Level, function(args, sender, isChat, bnetInfo)
	if not isChat then
		return false, "CM_ERR_CHATONLY"
	end
	return PM:DemoteAssistant(sender)
end, "CM_DEOPME_HELP")

CM:Register({"leader", "lead"}, PM.Access.Groups.Op.Level, function(args, sender, isChat, bnetInfo)
	if #args <= 0 then
		return false, "CM_LEADER_USAGE"
	end
	local player = PM:GetOrCreatePlayer(args[1])
	return PM:PromoteToLeader(player)
end, "CM_LEADER_HELP")

CM:Register({"promote"}, PM.Access.Groups.Op.Level, function(args, sender, isChat, bnetInfo)
	if #args <= 0 then
		return false, "CM_PROMOTE_USAGE"
	end
	local player = PM:GetOrCreatePlayer(args[1])
	return PM:PromoteToAssistant(player)
end, "CM_PROMOTE_HELP")

CM:Register({"demote"}, PM.Access.Groups.Op.Level, function(args, sender, isChat, bnetInfo)
	if #args <= 0 then
		return false, "CM_DEMOTE_USAGE"
	end
	local player = PM:GetOrCreatePlayer(args[1])
	return PM:DemoteAssistant(player)
end, "CM_DEMOTE_HELP")

CM:Register({"queue", "q"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if #args <= 0 then
		return false, "CM_QUEUE_USAGE"
	end
	ClearAllLFGDungeons()
	SetCVar("Sound_EnableSFX", 0)
	ShowUIPanel(LFDParentFrame)
	local index
	if args[1] == "current" then
		index = LFDQueueFrame.type
	else
		index = QM:GetIndex(args[1])
	end
	if not index then
		HideUIPanel(LFDParentFrame)
		SetCVar("Sound_EnableSFX", 1)
		return false, "CM_QUEUE_INVALID", {args[1]}
	end
	return QM:Queue(index)
end, "CM_QUEUE_HELP")

CM:Register({"leavelfg", "cancellfg", "cancel", "leavelfd", "cancellfd"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not QM.QueuedByCommand then
		return false, "CM_LEAVELFG_FAIL"
	end
	return QM:Cancel()
end, "CM_LEAVELFG_HELP")

-- So apparently Blizzard does not allow accepting invites without HW event... Making this command useless...
-- I'm keeping this command here for the future, if there will ever be a way to make this work.
CM:Register({"acceptlfg", "acceptlfd", "joinlfg", "joinlfd"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not C.Settings.DEBUG then
		return false, "CM_ERR_PERMDISABLED"
	end
	local exists = (select(1, GetLFGProposal()))
	if not QM.QueuedByCommand then
		return false, "CM_ACCEPTLFG_FAIL"
	elseif not exists then
		return false, "CM_ACCEPTLFG_NOEXIST"
	end
	return QM:Accept()
end, "CM_ACCEPTLFG_HELP")

CM:Register({"convert", "conv"}, PM.Access.Groups.Op.Level, function(args, sender, isChat, bnetInfo)
	if GT:IsLFGGroup() then
		return false, "CM_CONVERT_LFG"
	elseif not GT:IsGroup() then
		return false, "CM_CONVERT_NOGROUP"
	elseif not GT:IsGroupLeader() then
		return false, "CM_CONVERT_NOLEAD"
	elseif #args <= 0 then
		return false, "CM_CONVERT_USAGE"
	end
	args[1] = args[1]:lower()
	if args[1]:match("^p") then
		if GT:IsRaid() then
			ConvertToParty()
			return "CM_CONVERT_PARTY"
		else
			return false, "CM_CONVERT_PARTYFAIL"
		end
	elseif args[1]:match("^r") then
		if GT:IsRaid() then
			return false, "CM_CONVERT_RAIDFAIL"
		else
			ConvertToRaid()
			return "CM_CONVERT_RAID"
		end
	end
	return false, "CM_CONVERT_INVALID"
end, "CM_CONVERT_HELP")

CM:Register({"list"}, PM.Access.Groups.Admin.Level, function(args, sender, isChat, bnetInfo)
	if not args[1] then
		return false, "CM_LIST_USAGE"
	end
	return PM:ListToggle(args[1]:lower())
end, "CM_LIST_HELP")

CM:Register({"listmode", "lm", "lmode"}, PM.Access.Groups.Admin.Level, function(args, sender, isChat, bnetInfo)
	return PM:ToggleListMode()
end, "CM_LISTMODE_HELP")

CM:Register({"groupallow", "gallow"}, PM.Access.Groups.Admin.Level, function(args, sender, isChat, bnetInfo)
	if #args <= 1 then
		return false, "CM_GROUPALLOW_USAGE"
	end
	local group = args[1]:gsub("^%l", string.upper)
	local cmd = args[2]:lower()
	return PM:GroupAccess(group, cmd, true)
end, "CM_GROUPALLOW_HELP")

CM:Register({"groupdeny", "gdeny", "deny"}, PM.Access.Groups.Admin.Level, function(args, sender, isChat, bnetInfo)
	if #args <= 1 then
		return false, "CM_GROUPDENY_USAGE"
	end
	local group = args[1]:gsub("^%1", string.upper)
	local cmd = args[2]:lower()
	return PM:GroupAccess(group, cmd, false)
end, "CM_GROUPDENY_HELP")

CM:Register({"resetgroupaccess", "groupaccessreset", "removegroupaccess", "groupaccessremove", "rga", "gar"}, PM.Access.Groups.Admin.Level, function(args, sender, isChat, bnetInfo)
	if #args <= 1 then
		return false, "CM_RESETGROUPACCESS_USAGE"
	end
	local group = args[1]:gsub("^%1", string.upper)
	local cmd = args[2]:lower()
	return PM:GroupAccessRemove(group, cmd)
end, "CM_RESETGROUPACCESS_HELP")

CM:Register({"userallow", "uallow"}, PM.Access.Groups.Admin.Level, function(args, sender, isChat, bnetInfo)
	if #args <= 1 then
		return false, "CM_USERALLOW_USAGE"
	end
	local player = PM:GetOrCreatePlayer(args[1])
	local cmd = args[2]:lower()
	return PM:PlayerAccess(player, cmd, true)
end, "CM_USERALLOW_HELP")

CM:Register({"userdeny", "udeny"}, PM.Access.Groups.Admin.Level, function(args, sender, isChat, bnetInfo)
	if #args <= 1 then
		return false, "CM_USERDENY_USAGE"
	end
	local player = PM:GetOrCreatePlayer(args[1])
	local cmd = args[2]:lower()
	return PM:PlayerAccess(player, cmd, false)
end, "CM_USERDENY_HELP")

CM:Register({"resetuseraccess", "useraccessreset", "removeuseraccess", "useraccessremove", "rua", "uar"}, PM.Access.Groups.Admin.Level, function(args, sender, isChat, bnetInfo)
	if #args <= 1 then
		return false, "CM_RESETUSERACCESS_USAGE"
	end
	local player = PM:GetOrCreatePlayer(args[1])
	local cmd = args[2]:lower()
	return PM:PlayerAccessRemove(player, cmd)
end, "CM_RESETUSERACCESS_HELP")

CM:Register({"toggle", "t"}, PM.Access.Local, function(args, sender, isChat, bnetInfo)
	if isChat then
		return false, "CM_ERR_NOCHAT"
	end
	return C:Toggle()
end, "CM_TOGGLE_HELP")

CM:Register({"toggledebug", "td", "debug", "d"}, PM.Access.Local, function(args, sender, isChat, bnetInfo)
	if isChat then
		return false, "CM_ERR_NOCHAT"
	end
	return C:ToggleDebug()
end, "CM_TOGGLEDEBUG_HELP")

CM:Register({"readycheck", "rc"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if #args <= 0 then
		if PM:GetAccess(sender) > PM.Access.Groups.Op.Level then
			return "CM_ERR_NOACCESS", {sender.Info.Name, PM.Access.Groups.Op.Level, PM:GetAccess(sender)}
		else
			return RCM:Start(sender.Info.Name)
		end
	end
	local arg = tostring(args[1]):lower()
	if arg:match("^[ayr]") then -- Accept / Ready
		return RCM:Accept()
	elseif arg:match("^[dn]") then -- Decline
		return RCM:Decline()
	end
	return false, "CM_READYCHECK_USAGE"
end, "CM_READYCHECK_HELP")

CM:Register({"loot", "l"}, PM.Access.Groups.Op.Level, function(args, sender, isChat, bnetInfo)
	if GT:IsLFGGroup() then
		return false, "CM_LOOT_LFG"
	end
	local usage = "CM_LOOT_USAGE"
	if #args <= 0 then
		return false, usage
	end
	args[1] = args[1]:lower()
	if args[1]:match("^ty") or args[1]:match("^me") or args[1] == "t" then
		if #args < 2 then
			return false, "CM_LOOT_NOMETHOD"
		end
		local method = args[2]:lower()
		return LM:SetLootMethod(method, args[3])
	elseif args[1]:match("^th") or args[1]:match("^l") then
		if #args < 2 then
			return false, "CM_LOOT_NOTHRESHOLD"
		end
		return LM:SetLootThreshold(args[2])
	elseif args[1]:match("^m") then
		if #args < 2 then
			return false, "CM_LOOT_NOMASTER"
		end
		return LM:SetLootMaster(args[2])
	elseif args[1]:match("^p") then
		local p = args[2]
		if type(p) == "string" then
			if p:lower():match("^[eay]") then
				p = true
			elseif p:lower():match("^[dn]") then
				p = false
			else
				p = nil
			end
		else
			p = nil
		end
		return LM:SetLootPass(p)
	end
	return false, usage
end, "CM_LOOT_HELP")

CM:Register({"roll", "r"}, PM.Access.Groups.Op.Level, function(args, sender, isChat, bnetInfo)
	if #args <= 0 then
		return RM:StartRoll(sender.Info.Name)
	end
	args[1] = args[1]:lower()
	if args[1]:match("^sta") then
		if #args < 2 then
			return false, "CM_ROLL_START_USAGE"
		end
		local time = tonumber(args[2])
		local item
		if not time then
			item = args[2]
		end
		if #args >= 3 then
			if item then
				item = item .. " " .. args[3]
			else
				item = args[3]
			end
			if #args > 3 then
				for i = 4, #args do
					item = item .. " " .. args[i]
				end
			end
		end
		return RM:StartRoll(sender.Info.Name, item, time)
	elseif args[1]:match("^p") then
		return RM:PassRoll(sender.Info.Name)
	elseif args[1]:match("^sto") then
		return RM:StopRoll()
	elseif args[1]:match("^t") then
		return RM:GetTime()
	elseif args[1]:match("^d") then
		local min, max
		if #args >= 3 then
			min = tonumber(args[2])
			max = tonumber(args[3])
		end
		if not min and args[2]:match("^[ps]") then
			return RM:PassRoll()
		else
			return RM:DoRoll(min, max)
		end
	elseif args[1]:match("^se") then -- Set
		if #args < 3 then
			return false, "CM_ROLL_SET_USAGE"
		end
		args[2] = args[2]:lower()
		if args[2]:match("^mi") then
			return RM:SetMin(tonumber(args[3]))
		elseif args[2]:match("^ma") then
			return RM:SetMax(tonumber(args[3]))
		elseif args[2]:match("^t") then
			return RM:SetTime(tonumber(args[3]))
		else
			return false, "CM_ROLL_SET_USAGE"
		end
	end
	return false, "CM_ROLL_USAGE"
end, "CM_ROLL_HELP")

CM:Register({"raidwarning", "rw", "raid_warning"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not GT:IsRaid() then
		return false, "CM_RAIDWARNING_NORAID"
	elseif not GT:IsRaidLeaderOrAssistant() then
		return false, "CM_RAIDWARNING_NOPRIV"
	elseif #args <= 0 then
		return false, "CM_RAIDWARNING_USAGE"
	end
	local msg = args[1]
	if #args > 1 then
		for i = 2, #args do
			msg = msg .. " " .. args[i]
		end
	end
	Chat:SendMessage(msg, "RAID_WARNING")
	if isChat then
		return nil -- "CM_RAIDWARNING_SENT"
	end
	return "CM_RAIDWARNING_SENT"
end, "CM_RAIDWARNING_HELP")

CM:Register({"dungeondifficulty", "dungeondiff", "dd"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if #args < 1 then
		return GT:GetDungeonDifficultyString()
	end
	local diff = args[1]:lower()
	if diff:match("^n") then
		diff = GT.Difficulty.Dungeon.Normal
	elseif diff:match("^h") then
		diff = GT.Difficulty.Dungeon.Heroic
	elseif diff:match("^c") then
		diff = GT.Difficulty.Dungeon.Challenge
	elseif tonumber(diff) then
		diff = tonumber(diff)
	else
		return false, "CM_DUNGEONMODE_USAGE"
	end
	return GT:SetDungeonDifficulty(diff)
end, "CM_DUNGEONMODE_HELP")

CM:Register({"raiddifficulty", "raiddiff", "rd"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if #args < 1 then
		return GT:GetRaidDifficultyString()
	end
	local diff = args[1]:lower()
	if diff:match("^n.*1") then
		diff = GT.Difficulty.Raid.Normal10
	elseif diff:match("^n.*2") then
		diff = GT.Difficulty.Raid.Normal25
	elseif diff:match("^h.*1") then
		diff = GT.Difficulty.Raid.Heroic10
	elseif diff:match("^h.*2") then
		diff = GT.Difficulty.Raid.Heroic25
	elseif tonumber(diff) then
		diff = tonumber(diff)
	else
		return false, "CM_RAIDMODE_USAGE"
	end
	return GT:SetRaidDifficulty(diff)
end, "CM_RAIDMODE_HELP")

CM:Register({"release", "rel"}, PM.Access.Groups.Op.Level, function(args, sender, isChat, bnetInfo)
	if not DM:IsEnabled() or not DM:IsReleaseEnabled() then
		return false, "CM_ERR_DISABLED"
	end
	return DM:Release()
end, "CM_RELEASE_HELP")

CM:Register({"resurrect", "ressurrect", "ress", "res"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not DM:IsEnabled() or not DM:IsResurrectEnabled() then
		return false, "CM_ERR_DISABLED"
	end
	return DM:Resurrect()
end, "CM_RESURRECT_HELP")

CM:Register({"acceptsummon", "as", "acceptsumm", "asumm"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not SM:IsEnabled() then
		return false, "CM_ERR_DISABLED"
	end
	return SM:AcceptSummon()
end, "CM_ACCEPTSUMMON_HELP")

CM:Register({"declinesummon", "ds", "declinesumm", "dsumm", "cancelsummon", "csumm"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not SM:IsEnabled() then
		return false, "CM_ERR_DISABLED"
	end
	return SM:DeclineSummon()
end, "CM_DECLINESUMMON_HELP")

CM:Register({"acceptduel", "acceptd"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not CDM:IsEnabled() then
		return false, "CM_ERR_DISABLED"
	end
	return CDM:AcceptDuel()
end, "CM_ACCEPTDUEL_HELP")

CM:Register({"declineduel", "declined"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not CDM:IsEnabled() then
		return false, "CM_ERR_DISABLED"
	end
	return CDM:DeclineDuel()
end, "CM_DECLINEDUEL_HELP")

CM:Register({"startduel", "startd", "challenge"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not CDM:IsEnabled() then
		return false, "CM_ERR_DISABLED"
	end
	if #args < 1 then
		return false, "CM_STARTDUEL_USAGE"
	end
	return CDM:Challenge(args[1])
end, "CM_STARTDUEL_HELP")

CM:Register({"role", "rm"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if not CRM:IsEnabled() then
		return false, "CM_ERR_DISABLED"
	end
	if #args < 1 then
		return "CM_ROLE_CURRENT", {L(CRM.Roles[CRM:GetRole()])}
	end
	local arg = args[1]:lower()
	if arg:match("^st") or arg:match("^i") then -- Start/Initiate/Issue
		return CRM:Start()
	elseif arg:match("^[sa]") then -- Set/Assign (Role)
		if #args < 2 then
			return false, "CM_ROLE_SET_USAGE"
		end
		local role = args[2]:lower()
		if role:match("^[thd]") then
			return CRM:SetRole(role)
		end
		return false, "CM_ROLE_SET_USAGE"
	elseif arg:match("^c") then -- Confirm (Role)
		if not CRM:RolePollActive() then
			return false, "CM_ROLE_NOT_ACTIVE"
		elseif #args >= 2 then -- Role supplied as argument #2
			local role = args[2]:lower()
			if role:match("^[thd]") then
				return CRM:SetRole(role)
			end
			return false, "CM_ROLE_CONFIRM_USAGE"
		else -- No role specified
			-- Confirm the role last chosen by the player
			return CRM:ConfirmRole()
		end
	end
	return false, "CM_ROLE_USAGE"
end, "CM_ROLE_HELP")

CM:Register({"follow", "f"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	local name = args[1]
	if name then
		name = PM:GetOrCreatePlayer(name).Info.Name
	else
		name = sender.Info.Name
	end
	if name == UnitName("player") then
		return false, "CM_FOLLOW_SELF"
	end
	FollowUnit(name)
	return "CM_FOLLOW_STARTED", {name}
end, "CM_FOLLOW_HELP")

CM:Register({"emote", "em", "e"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if #args < 1 then
		return false, "CM_EMOTE_USAGE"
	end
	return EM:DoEmote(args[1])
end, "CM_EMOTE_HELP")

-- Alias for !emote sit
CM:Register({"sit"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	return EM:DoEmote(EM.Emotes.Sit)
end, "CM_SIT_HELP")

CM:Register({"fact", "facts"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if #args < 1 then
		return false, "CM_FACT_USAGE"
	end
	return FM:AnnounceFact(args[1], tonumber(args[2]))
end, "CM_FACT_HELP")

-- Alias for !fact cat
CM:Register({"cat", "c", "meow"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	return FM:AnnounceFact("cat", tonumber(args[1]))
end, "CM_CAT_HELP")

CM:Register({"factstats", "factstat", "fstat", "fs"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
	if #args < 1 then
		return FM:AnnounceLoadedTopics()
	end
	return FM:AnnounceTopicInfo(args[1])
end, "CM_FACTSTATS_HELP")

CM:Register({"factsettings", "factsetting", "factset"}, PM.Access.Groups.Admin.Level, function(args, sender, isChat, bnetInfo)
	if #args < 1 then
		if FM:IsEnabled() then
			return "CM_FACTSETTINGS_ENABLED"
		end
		return "CM_FACTSETTINGS_DISABLED"
	end
	local option = args[1]:lower()
	if option:match("^no") then -- NoDupe
		if sub:match("^[eay]") then -- Enable NoDupe
			return FM:EnableNoDupe()
		elseif sub:match("^[dnc]") then -- Disable NoDupe
			return FM:DisableNoDupe()
		elseif sub:match("^t") then -- Toggle NoDupe
			return FM:ToggleNoDupe()
		else
			if FM:IsNoDupeEnabled() then
				return "CM_FACTSETTINGS_NODUPE_ENABLED"
			end
			return "CM_FACTSETTINGS_NODUPE_DISABLED"
		end
	elseif option:match("^[eay]") then -- Enable
		return FM:Enable()
	elseif option:match("^[dnc][^o]") then -- Disable
		return FM:Disable()
	elseif option:match("^t") then -- Toggle
		return FM:Toggle()
	end
	return false, "CM_FACTSETTINGS_USAGE"
end, "CM_FACTSETTINGS_HELP")

CM:Register({"coinflip", "flip", "cf", "coin"}, PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
    local flip = math.random(0, 1)
    return flip == 0 and "CM_COINFLIP_HEADS" or "CM_COINFLIP_TAILS"
end, "CM_COINFLIP_HELP")

CM:Register("slap", PM.Access.Groups.User.Level, function(args, sender, isChat, bnetInfo)
    local target = args[1] or "everyone"
    return "CM_SLAP", {(UnitName("player")), target}
end, "CM_SLAP_HELP")

for i,v in ipairs(CM.Slash) do
	_G["SLASH_" .. C.Name:upper() .. i] = "/" .. v
end

SlashCmdList[C.Name:upper()] = function(msg, editBox)
	msg = CES:Trim(msg)
	local args = CES:Split(msg)
	local cmd = args[1]
	local t = {}
	if #args > 1 then
		for i=2,#args do
			tinsert(t, args[i])
		end
	end
	local result, arg, errArg = CM:HandleCommand(cmd, t, false, PM:GetOrCreatePlayer(UnitName("player")))
	local l = L:GetActive()
	if result then
		if type(result) == "table" then
			for _,v in ipairs(result) do
				if type(v) == "table" then
					local s = l[v[1]]
					if type(v[2]) == "table" then
						s = s:format(unpack(v[2]))
					end
					C.Logger:Normal(s)
				end
			end
		elseif result == Chat.SpecialOutput.RawTable then
			for _,v in ipairs(arg) do
				C.Logger:Normal(tostring(v))
			end
		elseif result == Chat.SpecialOutput.Raw then
			C.Logger:Normal(tostring(arg))
		else
			local s = l[result]
			if type(arg) == "table" then
				s = s:format(unpack(arg))
			end
			C.Logger:Normal(s)
		end
	elseif arg then
		local s = l[arg]
		if type(errArg) == "table" then
			s = s:format(unpack(errArg))
		end
		C.Logger:Error(s)
	end
end
