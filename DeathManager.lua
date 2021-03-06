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

-- Manages player death and resurrection
-- Disabled by default to prevent abuse
-- Enabled with /command set deathmanager enabled

-- Upvalues
local type = type

-- API Upvalues
local RepopMe = RepopMe
local CreateFrame = CreateFrame
local HasSoulstone = HasSoulstone
local UseSoulstone = UseSoulstone
local AcceptResurrect = AcceptResurrect
local StaticPopup_Hide = StaticPopup_Hide
local StaticPopup_Visible = StaticPopup_Visible
local ResurrectGetOfferer = ResurrectGetOfferer

local C = Command

C.DeathManager = {}

local L = C.LocaleManager
local DM = C.DeathManager
local CM
local CEN = C.Extensions.Number

local DEFAULT_RELEASE_DELAY = 5
local DEFAULT_RESURRECT_DELAY = 5
local MAX_RELEASE_DELAY = 60
local MAX_RESURRECT_DELAY = 55

local DeathAnnouncePending = false
local RessAnnouncePending = false

local SelfRessType = {
	None = 0,
	Soulstone = 1,
	Reincarnate = 2,
	Card = 3 -- Darkmoon Card: Twisting Nether
}

function DM:Init()
	CM = C.ChatManager
	self:LoadSavedVars()
end

function DM:LoadSavedVars()
	if type(C.Global["DEATH_MANAGER"]) ~= "table" then
		C.Global["DEATH_MANAGER"] = {}
	end
	self.Settings = C.Global["DEATH_MANAGER"]
	if type(self.Settings.ENABLED) ~= "boolean" then
		self.Settings.ENABLED = false
	end
	if type(self.Settings.RELEASE_ENABLED) ~= "boolean" then
		self.Settings.RELEASE_ENABLED = true
	end
	if type(self.Settings.RELEASE_ANNOUNCE) ~= "boolean" then
		self.Settings.RELEASE_ANNOUNCE = true
	end
	if type(self.Settings.RELEASE_DELAY) ~= "number" then
		self.Settings.RELEASE_DELAY = DEFAULT_RELEASE_DELAY
	end
	if type(self.Settings.RESURRECT_ENABLED) ~= "boolean" then
		self.Settings.RESURRECT_ENABLED = true
	end
	if type(self.Settings.RESURRECT_ANNOUNCE) ~= "boolean" then
		self.Settings.RESURRECT_ANNOUNCE = true
	end
	if type(self.Settings.RESURRECT_DELAY) ~= "number" then
		self.Settings.RESURRECT_DELAY = DEFAULT_RESURRECT_DELAY
	end
end

function DM:OnDeath()
	if not self.Settings.ENABLED or not self.Settings.RELEASE_ENABLED or not self.Settings.RELEASE_ANNOUNCE or DeathAnnouncePending then return end
	self.Dead = true
	if self.Settings.RELEASE_DELAY > 0 then
		DeathAnnouncePending = true
		local frame = CreateFrame("Frame")
		frame.Time = 0
		frame.Delay = self.Settings.RELEASE_DELAY
		frame:SetScript("OnUpdate", function(self, elapsed)
			self.Time = self.Time + elapsed
			if self.Time >= self.Delay then
				self:SetScript("OnUpdate", nil)
				self.Time = 0
				DeathAnnouncePending = false
				DM:AnnounceDeath()
			end
		end)
	else
		self:AnnounceDeath()
	end
end

function DM:OnResurrect(resser)
	if not self.Settings.ENABLED or not self.Settings.RESURRECT_ENABLED or not self.Settings.RESURRECT_ANNOUNCE or RessAnnouncePending then return end
	self.Resurrection = true
	if self.Settings.RESURRECT_DELAY > 0 then
		RessAnnouncePending = true
		local frame = CreateFrame("Frame")
		frame.Time = 0
		frame.Delay = self.Settings.RESURRECT_DELAY
		frame.Resser = resser
		frame:SetScript("OnUpdate", function(self, elapsed)
			self.Time = self.Time + elapsed
			if self.Time >= self.Delay then
				self:SetScript("OnUpdate", nil)
				self.Time = 0
				RessAnnouncePending = false
				DM:AnnounceResurrect(self.Resser)
			end
		end)
	else
		self:AnnounceResurrect(resser)
	end
end

function DM:AnnounceDeath()
	if not self.Dead then return end
	local t = self:HasSelfRess()
	if t == SelfRessType.SoulStone then
		CM:SendMessage(L("DM_ONDEATH_SOULSTONE"), "SMART")
	elseif t == SelfRessType.Reincarnate then
		CM:SendMessage(L("DM_ONDEATH_REINCARNATE"), "SMART")
	elseif t == SelfRessType.Card then
		CM:SendMessage(L("DM_ONDEATH_CARD"), "SMART")
	elseif self.Settings.RELEASE_ENABLED then
		CM:SendMessage(L("DM_ONDEATH"), "SMART")
	end
end

function DM:AnnounceResurrect(resser)
	if not self.Resurrection then return end
	CM:SendMessage(L("DM_ONRESS"):format(resser), "SMART")
end

-- Returns appropriate SelfRessType
function DM:HasSelfRess()
	local t = HasSoulstone()

	if not t then
		return SelfRessType.None
	elseif t:lower() == L("USE_SOULSTONE"):lower() then -- soulstone ("Use Soulstone")
		return SelfRessType.Soulstone
	elseif t:lower() == L("REINCARNATION"):lower() then -- Reincarnate
		return SelfRessType.Reincarnate
	elseif t:lower() == L("TWISTING_NETHER"):lower() then -- Darkmoon Card: Twisting Nether
		return SelfRessType.Card
	end

	return SelfRessType.None
end

function DM:Release()
	if not UnitIsDead("player") then
		return false, "DM_RELEASE_NOTDEAD"
	end

	RepopMe()

	if StaticPopup_Visible("DEATH") then
		StaticPopup_Hide("DEATH")
	end

	return "DM_RELEASED"
end

function DM:Resurrect()
	if not UnitIsDeadOrGhost("player") then
		return false, "DM_ERR_NOTDEAD"
	end

	local result = "DM_RESURRECTED"
	local selfRess = DM:HasSelfRess()
	local resser = ResurrectGetOfferer()
	if selfRess ~= SelfRessType.None then
		UseSoulstone()
		if selfRess == SelfRessType.Soulstone then
			result = "DM_RESURRECTED_SOULSTONE"
		elseif selfRess == SelfRessType.Reincarnate then
			result = "DM_RESURRECTED_REINCARNATE"
		elseif selfRess == SelfRessType.Card then
			result = "DM_RESURRECTED_CARD"
		end
	else
		if not resser then
			return false, "DM_RESURRECT_NOTACTIVE"
		end
		AcceptResurrect()
		result = "DM_RESURRECTED_PLAYER"
	end

	if StaticPopup_Visible("RESURRECT") then -- Never seems to show, but just in case
		StaticPopup_Hide("RESURRECT")
	elseif StaticPopup_Visible("RESURRECT_NO_TIMER") then
		StaticPopup_Hide("RESURRECT_NO_TIMER")
	elseif StaticPopup_Visible("RESURRECT_NO_SICKNESS") then
		StaticPopup_Hide("RESURRECT_NO_SICKNESS")
	end

	return result, {resser}
end

function DM:IsEnabled()
	return self.Settings.ENABLED
end

function DM:Enable()
	self.Settings.ENABLED = true
	return "DM_ENABLED"
end

function DM:Disable()
	self.Settings.ENABLED = false
	return "DM_DISABLED"
end

function DM:Toggle()
	if self:IsEnabled() then
		return self:Disable()
	end
	return self:Enable()
end

function DM:IsReleaseEnabled()
	return self.Settings.RELEASE_ENABLED
end

function DM:EnableRelease()
	self.Settings.RELEASE_ENABLED = true
	return "DM_RELEASE_ENABLED"
end

function DM:DisableRelease()
	self.Settings.RELEASE_ENABLED = false
	return "DM_RELEASE_DISABLED"
end

function DM:ToggleRelease()
	if self:IsReleaseEnabled() then
		return self:DisableRelease()
	end
	return self:EnableRelease()
end

function DM:IsReleaseAnnounceEnabled()
	return self.Settings.RELEASE_ANNOUNCE
end

function DM:EnableReleaseAnnounce()
	self.Settings.RELEASE_ANNOUNCE = true
	return "DM_RELEASE_ANNOUNCE_ENABLED"
end

function DM:DisableReleaseAnnounce()
	self.Settings.RELEASE_ANNOUNE = false
	return "DM_RELEASE_ANNOUNCE_DISABLED"
end

function DM:ToggleReleaseAnnounce()
	if self:IsReleaseAnnounceEnabled() then
		return self:DisableReleaseAnnounce()
	end
	return self:EnableReleaseAnnounce()
end

function DM:GetReleaseDelay()
	return self.Settings.RELEASE_DELAY
end

function DM:SetReleaseDelay(amount)
	if amount < 0 then
		amount = 0
	elseif amount > MAX_RELEASE_DELAY then
		amount = MAX_RELEASE_DELAY
	end
	self.Settings.RELEASE_DELAY = amount
	if amount > 0 then
		return "DM_RELEASE_SETDELAY_SUCCESS", {CEN:FormatSeconds(amount)}
	end
	return "DM_RELEASE_SETDELAY_INSTANT"
end

function DM:IsResurrectEnabled()
	return self.Settings.RESURRECT_ENABLED
end

function DM:EnableResurrect()
	self.Settings.RESURRECT_ENABLED = true
	return "DM_RESURRECT_ENABLED"
end

function DM:DisableResurrect()
	self.Settings.RESURRECT_ENABLED = false
	return "DM_RESURRECT_DISABLED"
end

function DM:ToggleResurrect()
	if self:IsResurrectEnabled() then
		return self:DisableResurrect()
	end
	return self:EnableResurrect()
end

function DM:IsResurrectAnnounceEnabled()
	return self.Settings.RESURRECT_ANNOUNCE
end

function DM:EnableResurrectAnnounce()
	self.Settings.RESURRECT_ANNOUNCE = true
	return "DM_RESURRECT_ANNOUNCE_ENABLED"
end

function DM:DisableResurrectAnnounce()
	self.Settings.RESURRECT_ANNOUNE = false
	return "DM_RESURRECT_ANNOUNCE_DISABLED"
end

function DM:ToggleResurrectAnnounce()
	if self:IsResurrectAnnounceEnabled() then
		return self:DisableResurrectAnnounce()
	end
	return self:EnableResurrectAnnounce()
end

function DM:GetResurrectDelay()
	return self.Settings.RESURRECT_DELAY
end

function DM:SetResurrectDelay(amount)
	if amount < 0 then
		amount = 0
	elseif amount > MAX_RESURRECT_DELAY then
		amount = MAX_RESURRECT_DELAY
	end
	self.Settings.RESURRECT_DELAY = amount
	if amount > 0 then
		return "DM_RESURRECT_SETDELAY_SUCCESS", {CEN:FormatSeconds(amount)}
	end
	return "DM_RESURRECT_SETDELAY_INSTANT"
end
