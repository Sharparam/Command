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

if type(Command.Extensions) ~= "table" then
	Command.Extensions = {}
end

Command.Extensions.Table = {}

local CET = Command.Extensions.Table

function CET:HasKey(tbl, key)
	for k,_ in pairs(tbl) do
		if k == key then return true end
	end
	return false
end

function CET:HasValue(tbl, value)
	for _,v in pairs(tbl) do
		if v == value then return true end
	end
	return false
end

-- Thanks to ITSBTH for the table copy function
function CET:Copy(tbl, cache)
	if type(tbl) ~= "table" then return tbl end
	cache = cache or {}
	if cache[tbl] then return cache[tbl] end
	local copy = {}
	cache[tbl] = copy
	for k, v in pairs(tbl) do
		copy[self:Copy(k, cache)] = self:Copy(v, cache)
	end
	return copy
end
