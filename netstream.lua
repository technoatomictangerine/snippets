AddCSLuaFile()
AddCSLuaFile('pon/pon.lua')

local string, net, table, assert, math, player, pairs, select = string, net, table, assert, math, player, pairs, select
local pon = assert(include('pon/pon.lua'), [[Unable to include "pon/pon.lua"]])
local NIL, cvMaxbytes = 'NULL', CreateConVar('netstream_maxbytes', 32768, {FCVAR_LUA_SERVER, FCVAR_LUA_SERVER, FCVAR_REPLICATED, FCVAR_DONTRECORD, FCVAR_SERVER_CAN_EXECUTE}, 'Maximum netstream chunk lenght', 8, 32768)
netstream = netstream or {}
netstream.cbs = netstream.cbs or {}
netstream.names = netstream.names or {}

local function packtable(...)
	local l, out = select('#', ...), {...}
	for i = 1, l do
		if out[i] == nil then out[i] = NIL end
	end
	return out
end

local function unpacktable(t)
	if #t > 0 then
		local v = table.remove(t, 1)
		if v == NIL then v = nil end
		return v, unpacktable(t)
	end
end

local function FindID(name)
	local name = string.lower(name)
	for id, v in pairs(netstream.names) do
		if v == name then return id end
	end
end

local function Bits(n)
	return math.floor(math.log(n, 2)) + 1
end

local function SplitData(data, size)
	local l, out = #data, {}
	for i = 0, l, size do
		out[#out + 1] = string.sub(data, i, i + size - 1)
	end
	return out
end

function netstream.Receive(name, cb)
	netstream.cbs[name] = assert(isfunction(cb) and cb, '#arg2 must be a function')
end

function netstream.Register(name)
	local name = string.lower(name)
	netstream.names[#netstream.names + 1] = name
	table.sort(netstream.names, function(a, b)
		return a < b
	end)
end

if SERVER then
	util.AddNetworkString('netstream')

	function netstream.Start(pl, name, ...)
		local pl = pl or player.GetHumans()
		local id, chunk_l = assert(FindID(name), 'unable to find ID for "' .. name .. '" (netstream.Register)'), cvMaxbytes:GetInt()
		local data = packtable(...)

		if #data == 0 then return end
		local encoded = pon.encode(data)
		local split = SplitData(encoded, chunk_l)
		local len, bits = #split, Bits(chunk_l)

		for i = 1, len do
			local chunk = split[i]
			net.Start('netstream')
			net.WriteUInt(id, Bits(#netstream.names))

			local l = #chunk
			net.WriteUInt(l, bits)
			net.WriteData(chunk, l)
			net.WriteBool(i == len)
			net.Send(pl)
		end
	end

	net.Receive('netstream', function(l, pl)
		local chunk_l = cvMaxbytes:GetInt()
		local id, len = net.ReadUInt(Bits(#netstream.names)), net.ReadUInt(Bits(chunk_l))
		local data, completed = net.ReadData(len), net.ReadBool()

		pl.NSDATA = pl.NSDATA or {}
		local tab = pl.NSDATA
		tab[#tab + 1] = data

		if completed then
			local raw, name = '', assert(netstream.names[id], 'Got corrupted ID from ' .. tostring(pl))
			local cb = netstream.cbs[name]
			if !cb then return end

			for i = 1, #tab do
				raw = raw .. tab[i]
			end

			local out = assert(raw, 'Got corrupted data from ' .. tostring(pl))
			if #out < 1 then cb() return end
			local t = assert(pon.decode(out), 'Got corrupted data from ' .. tostring(pl))
			cb(pl, unpacktable(t))
			pl.NSDATA = nil
		end
	end)
else
	local NSDATA

	function netstream.Start(name, ...)
		local id, chunk_l = assert(FindID(name), 'unable to find ID for "' .. name .. '" (netstream.Register)'), cvMaxbytes:GetInt()
		local data = packtable(...)
		if #data == 0 then return end
		local encoded = pon.encode(data)
		local split = SplitData(encoded, chunk_l)
		local len, bits = #split, Bits(chunk_l)

		for i = 1, len do
			local chunk = split[i]
			net.Start('netstream')
			net.WriteUInt(id, Bits(#netstream.names))

			local l = #chunk
			net.WriteUInt(l, bits)
			net.WriteData(chunk, l)
			net.WriteBool(i == len)
			net.SendToServer()
		end
	end

	net.Receive('netstream', function(l)
		local chunk_l = cvMaxbytes:GetInt()
		local id, len = net.ReadUInt(Bits(#netstream.names)), net.ReadUInt(Bits(chunk_l))
		local data, completed = net.ReadData(len), net.ReadBool()

		NSDATA = NSDATA or {}
		local tab = NSDATA
		tab[#tab + 1] = data

		if completed then
			local raw, name = '', assert(netstream.names[id], 'Got corrupted ID from SERVER')
			local cb = netstream.cbs[name]
			if !cb then return end

			for i = 1, #tab do
				raw = raw .. tab[i]
			end

			local out = assert(raw, 'Got corrupted data from SERVER')
			if #out < 1 then cb() return end
			local t = assert(pon.decode(out), 'Got corrupted data from SERVER')
			cb(unpacktable(t))
			NSDATA = nil
		end
	end)
end

return netstream
