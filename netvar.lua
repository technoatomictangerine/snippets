local vars, storage = {}, {}
local SERVER, CLIENT, _R = SERVER, CLIENT, debug.getregistry()
local AddReceiver, AddNetworkString = net.Receive, util.AddNetworkString
local EntIndex, Entity, next = _R.Entity.EntIndex, Entity, next
local NewVar, GetNetVar

do
	local mt = {__index = {
		Unrealiable = true,
		Read = net.ReadType, Write = net.WriteType,
		Send = net.Broadcast, PreSync = false}}
	local ReadUInt, WriteUInt, Start = net.ReadUInt, net.WriteUInt, net.Start

	function NewVar(name, funcs)
		local str = 'nw.' .. name
		local var = setmetatable(funcs or {}, mt)
		vars[name] = var

		if SERVER then
			AddNetworkString(str)
			var.OnChange = nil
			local Write, Send, Realiable, OnChanged =
				var.Write, var.Send, var.Unrealiable, var.OnServerChanged

			var.WriteFunction = function(ent, index, v)
				Start(str, Unrealiable)
				WriteUInt(index, 13)
				Write(v)
				Send(ent)
				if OnChanged ~= nil then
					OnChanged(ent, v)
				end
			end
		else
			var.OnServerChange = nil
			local Read, OnChanged = var.Read, var.OnChanged
			AddReceiver(str, function(l, pl)
				local id = ReadUInt(13)
				if storage[id] == nil then storage[id] = {} end
				local v = Read()
				storage[id][name] = v
				if OnChanged ~= nil then
					OnChanged(Entity(id), v)
				end
			end)
		end
	end
end

function GetNetVar(ent, name, default)
	local id = EntIndex(ent)
	if storage[id] == nil then return default end
	return storage[id][name] or default
end

local function BitLength(n)
	return math.floor(math.log(n, 2) + 1)
end

local function AccessorFunc(tab, key, name, def)
	tab['Get' .. name] = function(obj)
		local id = EntIndex(obj)
		if storage[id] == nil then return def end
		return storage[id][key] or def
	end

	if SERVER then
		tab['Set' .. name] = function(obj, val)
			local id, var = EntIndex(obj), vars[key]
			if var ~= nil then
				if storage[id] == nil then storage[id] = {} end
				storage[id][key] = val
				var.WriteFunction(obj, id, val)
			end
		end
	else
		tab['Set' .. name] = function(obj, val)
			local id, var = EntIndex(obj), vars[key]
			if var ~= nil then
				if storage[id] == nil then storage[id] = {} end
				storage[id][key] = val
			end
		end
	end
end

_R.Entity.GetNetVar = GetNetVar
_R.Player.GetNetVar = GetNetVar

if SERVER then
	AddNetworkString'nw.Remove'
	AddNetworkString'nw.Ping'

	function _R.Entity.SetNetVar(ent, name, v)
		local id, var = EntIndex(ent), vars[name]
		if var ~= nil then
			if storage[id] == nil then storage[id] = {} end
			storage[id][name] = v
			var.WriteFunction(ent, id, v)
		end
	end

	do
		local Run, Entity, IsValid, task, timer_Create, timer_Remove = 
			hook.Run, Entity, IsValid, task.Create, timer.Create, timer.Remove
		local wrap, yield = 
			coroutine.wrap, coroutine.yield

		local function SyncVars(pl)
			for id, list in next, storage do
				local ent = Entity(id)
				for name, v in next, list do
					if not IsValid(ent) then break end
					local var = vars[name]
					if var ~= nil and var.PreSync then
						var.WriteFunction(ent, id, v)
						yield(false)
					end
				end
			end
			yield(true)
		end

		AddReceiver('nw.Ping', function(l, pl)
			if pl._nwLoaded then return end
			pl._nwLoaded = true
			
			local name, thread = 
				'nw.Sync_' .. pl:UniqueID(), wrap(SyncVars)

			timer_Create(name, 0, 0, function()
				if not IsValid(pl) then
					timer_Remove(name)
					thread = nil
				elseif thread(pl) then
					timer_Remove(name)
					thread = nil
					Run('PlayerNetworkLoaded', pl)
					net.Start('nw.Ping')
					net.Send(pl)
				end
			end)
		end)
	end

	local Broadcast, Start, UInt = net.Broadcast, net.Start, net.WriteUInt
	hook.Add('EntityRemoved', 'nw.EntityRemoved', function(ent)
		local id = EntIndex(ent)
		if storage[id] ~= nil then
			storage[id] = nil
			Start('nw.Remove')
			UInt(id, 13)
			Broadcast()
		end
	end)
else
	hook.Add('InitPostEntity', 'nw.PreSync', function()
		net.Start('nw.Ping')
		net.SendToServer()
	end)

	local UInt = net.ReadUInt
	AddReceiver('nw.Remove', function()
		storage[UInt(13)] = nil
	end)

	NWLOADED = false
	AddReceiver('nw.Ping', function()
		hook.Run('PlayerNetworkLoaded', LocalPlayer())
		NWLOADED = true
	end)
end

local WriteByte, ReadByte, WriteShort, ReadShort, WriteLong, ReadLong, WriteUByte, ReadUByte,
	WriteUShort, ReadUShort, WriteULong, ReadULong, SendSelf, SendPVS, SendPAS, WriterUInt,
	WriterInt, ReaderUInt, ReaderInt, WriterUFloat, WriterFloat, ReaderUFloat, ReaderFloat

do
	local wuint, ruint, wint, rint, send, sendpvs, sendpas = 
		net.WriteUInt, net.ReadUInt, net.WriteInt, net.ReadInt, net.Send, net.SendPVS, net.SendPAS
	local GetPos = _R.Entity.GetPos
	local fn = function()end

	if SERVER then
		local cached_wuint, cached_wint = {}, {}
		function WriterUInt(bits)
			local fn = cached_wuint[bits]
			if fn ~= nil then return fn end
			cached_wuint[bits] = function(v)
				wuint(v, bits)
			end
			return cached_wuint[bits]
		end

		function WriterInt(bits)
			local fn = cached_wint[bits]
			if fn ~= nil then return fn end
			cached_wint[bits] = function(v)
				wint(v, bits)
			end
			return cached_wint[bits]
		end

		function WriterUFloat(max, bits)
			local ml = (1 / max) * (2 ^ bits - 1)
			return function(v)
				return wuint(v * ml, bits)
			end
		end

		function WriterFloat(max, bits)
			local ml = (1 / max * .5) * (2 ^ bits - 1)
			return function(v)
				return wint(v * ml, bits)
			end
		end

		WriteByte = WriterInt(8)
		WriteShort = WriterInt(16)
		WriteLong = WriterInt(32)
		WriteUByte = WriterUInt(8)
		WriteUShort = WriterUInt(16)
		WriteULong = WriterUInt(32)

		function SendSelf(pl)send(pl)end
		function SendPVS(pl)sendpvs(GetPos(pl))end
		function SendPAS(pl)sendpas(GetPos(pl))end

		ReaderUInt = fn
		ReaderInt = fn
		ReaderUFloat = fn
		ReaderFloat = fn
	else
		local cached_ruint, cached_rint = {}, {}

		function ReaderUInt(bits)
			local fn = cached_ruint[bits]
			if fn ~= nil then return fn end
			cached_ruint[bits] = function()
				return ruint(bits)
			end
			return cached_ruint[bits]
		end

		function ReaderInt(bits)
			local fn = cached_rint[bits]
			if fn ~= nil then return fn end
			cached_rint[bits] = function()
				return rint(bits)
			end
			return cached_rint[bits]
		end

		function ReaderUFloat(max, bits)
			local ml = max / (2 ^ bits - 1)
			return function()
				return ruint(bits) * ml
			end
		end

		function ReaderFloat(max, bits)
			local ml = (max * .5) / (2 ^ bits - 1)
			return function()
				return rint(bits) * ml
			end
		end

		ReadByte = ReaderInt(8)
		ReadShort = ReaderInt(16)
		ReadLong = ReaderInt(32)
		ReadUByte = ReaderUInt(8)
		ReadUShort = ReaderUInt(16)
		ReadULong = ReaderUInt(32)

		WriterUInt = fn
		WriterInt = fn
		WriterUFloat = fn
		WriterFloat = fn
	end
end

nw = {RegisterVar = NewVar, GetNetVar = GetNetVar,
	WriteByte = WriteByte, ReadByte = ReadByte,
	WriteShort = WriteShort, ReadShort = ReadShort,
	WriteLong = WriteLong, ReadLong = ReadLong,
	WriteUByte = WriteUByte, ReadUByte = ReadUByte,
	WriteUShort = WriteUShort, ReadUShort = ReadUShort,
	WriteULong = WriteULong, ReadULong = ReadULong,
	SendSelf = SendSelf, SendPVS = SendPVS, SendPAS = SendPAS,
	WriterUInt = WriterUInt, WriterInt = WriterInt,
	ReaderUInt = ReaderUInt, ReaderInt = ReaderInt,
	WriterUFloat = WriterUFloat, WriterFloat = WriterFloat,
	ReaderUFloat = ReaderUFloat, ReaderFloat = ReaderFloat,
	BitLen = BitLength, AccessorFunc = AccessorFunc}
