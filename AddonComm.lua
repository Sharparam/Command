--[[
	* Copyright (c) 2011 by Adam Hellberg.
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

local C = Command

local GT = C.GroupTools
local CES = C.Extensions.String
local CET = C.Extensions.Table

local log = C.Logger

C.AddonComm = {
	GroupMaster = true, -- Whether or not we are currently the "master" instance in group
	GuildMaster = true, -- Whether or not we are currently the "master" instance in guild
	Type = {
		VersionUpdate = "COMM_VU",
		HandleCommand = "COMM_DO"
	},
	Format = {
		VersionUpdate = "%s",
		HandleCommand = "%s;&%s;&%s"
	},
	Last = {
		Sender = nil,
		Message = nil,
		Channel = nil
	}
}

local AC = C.AddonComm

function AC:Init()
	--self:LoadSavedVars()
	for _,v in pairs(self.Type) do
		RegisterAddonMessagePrefix(v)
	end
end

function AC:LoadSavedVars()
	
end

function AC:Receive(msgType, msg, channel, sender)
	if msgType == self.Type.VersionUpdate then
		local t = CES:Split(msg, ":")
		if #t < 1 then return end
		local ver = tonumber(t[1])
		if type(t[1]) ~= "number" then return end
		C:CheckVersion(ver)
	elseif msgType == self.Type.HandleCommand then
		local t = CES:Split(msg, ";&")
		if #t < 3 then return end
		local name = tostring(t[1])
		local sent = tostring(t[2])
		local chan = tostring(t[3])
		if type(t[1]) ~= "string" or type(t[2]) ~= "string" or type(t[3]) ~= "string" then return end
		self.Last.Sender = name
		self.Last.Message = sent
		self.Last.Channel = chan
	end
end

function AC:Send(msgType, msg, channel, target)
	channel = channel or "RAID"
	if not CET:HasValue(self.Type, msgType) then
		error("Invalid Message Type specified: " .. tostring(msgType))
		return
	end
	SendAddonMessage(msgType, msg, channel, target)
end

function AC:Handled(msg, sender, channel)
	if channel == "WHISPER" then return end
	if self:IsHandled(msg, sender, channel) then return false end
	self:Send(self.Type.HandleCommand, self.Format.HandleCommand:format(sender, msg, channel), channel)
	return true
end

function AC:IsHandled(msg, sender, channel)
	if channel == "WHISPER" then return false end
	if tostring(msg) == self.Last.Message and tostring(sender) == self.Last.Sender and tostring(channel) == self.Last.Channel then
		return true
	end
	return false
end