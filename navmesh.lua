local _R = debug.getregistry()
local buffer = {}
local setmetatable, Vector, next =
	setmetatable, Vector, next
local ins, rm, Empty =
	table.insert, table.remove, table.Empty
local TraceHull, TraceLine =
	util.TraceHull, util.TraceLine
local rad, sin, cos =
	math.rad, math.sin, math.cos
local DistToSqr, Length, GetNormalized = 
	_R.Vector.DistToSqr, _R.Vector.Length, _R.Vector.GetNormalized
local huge = math.huge
local max = math.max
local abs = math.abs
local floor = math.floor

local function H(a, b)
	return abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z)
end

local IsLineNotIntersects, filter do
	local down = Vector(0, 0, -76)
	local tr = {
		collisiongroup = COLLISION_GROUP_WORLD,
		mask = MASK_PLAYERSOLID,
		mins = Vector(-16, -16, 0), maxs = Vector(16, 16, 72),
		output = {}
	}
	local data = tr.output

	function IsLineNotIntersects(self, b)
		local a = self.Pos
		tr.start, tr.endpos, tr.filter =
			a, b, self.Filter
		TraceHull(tr)
		if data.Hit then return false end
		local diff = b - a
		local dir, l =
			GetNormalized(diff), Length(diff)

		for i = 0, l, 64 do
			local pos = a + dir * i
			tr.start, tr.endpos =
				pos, pos + down
			TraceLine(tr)
			if not data.HitWorld then
				return false
			end
		end
		return true
	end
end

local function AproximateVector(v)
	return Vector(
		floor(v.x / 1024),
		floor(v.y / 1024),
		floor(v.z / 1024))
end

local CalcRadius do
	local trdata = {
		start = pos,
		mask = MASK_PLAYERSOLID_BRUSHONLY
	}

	function CalcRadius(self)
		local r = 512
		local pos = self.Pos
		local d = 512 * 512
		for i = 0, 315, 45 do
			local a = rad(i)
			local v = Vector(cos(a) * r, sin(a) * r)

			trdata.endpos = pos + v
			local tr = TraceLine(trdata)
			local dst = (v - pos):Length2DSqr()
			if dst < d then d = dst end
		end

		return d ^ .5
	end
end

local function Clear(self)
	for k, node in next, self.Points do 
		self.Points[k] = nil
		self.Binds[node] = nil
	end
end

local function Bind_Internal(self, node)
	self.Binds[node] = true
	ins(self.Points, node)
end

local function Bind(self, node)
	if self.Binds[node] == nil then
		ins(self.Points, node)
		self.Binds[node] = true
		if node.Binds[self] == nil then
			ins(node.Points, self)
		end
	end
end

local function SetPos(self, pos)
	self.Pos = pos
	self.FPos = AproximateVector(pos)
end

local node_meta = {
	Pos = Vector(),
	FPos = Vector(),
	Radius = 64,
	Clear = Clear,
	CalcRadius = CalcRadius,
	IsLineNotIntersects = IsLineNotIntersects,
	Bind = Bind,
	Bind_Internal = Bind_Internal,
	__tostring = function(self)
		return string.format('Node[%s]', self.Index)
	end
}
node_meta.__index = node_meta

_R.AINode = node_meta
AccessorFunc(node_meta, 'Pos', 'pos')
AccessorFunc(node_meta, 'Radius', 'radius')

local function NewNode(pos, radius)
	local t = setmetatable({
		Pos = pos * 1,
		FPos = AproximateVector(pos),
		Radius = radius,
		Points = {},
		Binds = {}},
		node_meta)

	t.Index = ins(buffer, t)
	return t
end

local function RemoveNode(node)
	for k, instance in next, buffer do
		if node == instance then
			rm(buffer, k)
			break
		end
	end
end

local function GetClosestsNode(a)
	local mx, dst, out = huge, huge
	local index = 0
	while true do
		index = index + 1
		local node = buffer[index]
		if node == nil then break end
		local b = node.Pos

		local d = abs(a.x - b.x)
		if d > mx then return out end
		d = d + abs(a.y - b.y) + abs(a.z - b.z)
		if d < dst then
			dst, out = d, node
		end
	end
	return out
end

local function BuildPath(start, goal)
	local cur, path, l =
		goal, {}, 0

	while cur ~= nil do
		l = l + 1
		path[l] = cur
		cur = cur.came
	end

	return path
end

local FindPath do
	local done, open = {}, {}
	function FindPath(startpos, endpos, limit)
		local start, goal = 
			GetClosestsNode(startpos),
			GetClosestsNode(endpos)
		Empty(done); Empty(open);

		open[start] = true
		local x = start
		local score, r = 0, 0
		local better = false
		start.g = 0
		start.h = H(start.Pos, goal.Pos)
		start.f = start.h
		start.came = nil

		while next(open) do
			local f, cur = huge, start
			for v in next, open do
				if v.f < f then
					f = v.f
					cur = v
				end
			end

			if cur == goal or r > limit then return BuildPath(start, goal) end
			open[cur] = nil
			done[cur] = true

			for _, node in next, cur.Points do
				if not done[node] then
					score = cur.g + H(cur.Pos, node.Pos)
					if not open[node] then
						better = true
						open[node] = true
					else
						better = score < node.g
					end

					if better then
						node.came = cur
						node.g = score
						node.h = H(node.Pos, goal.Pos)
						node.f = node.g + node.h
					end
				end
			end
			r = r + 1
		end
	end
end

local function WriteFile(f)
	table.sort(buffer, function(a, b)
		if a == nil or a.Pos == nil then return false end
		if b == nil or b.Pos == nil then return true end
		local a, b = a.Pos, b.Pos
		return a.x > b.x
	end)

	local l = #buffer
	for i = 1, l do
		buffer[i].Index = i
	end

	for i = 1, l do
		local node = buffer[i]
		local t, v, r =
			node.Points, node.Pos, node.Radius
		f:WriteShort(v.x)
		f:WriteShort(v.y)
		f:WriteShort(v.z)
		f:WriteUShort(r)
		f:WriteByte(#t)
		for i = 1, 255 do
			local bind = t[i]
			if bind == nil then break end
			f:WriteUShort(bind.Index)
		end
	end
	f:Flush()
end

local function ReadFile(f)
	for i = 1, #buffer do buffer[i] = nil end

	local binds = {}
	local v, index = Vector(), 0
	while not f:EndOfFile() do
		v.x, v.y, v.z =
			f:ReadShort(),
			f:ReadShort(),
			f:ReadShort()
		local r = f:ReadUShort()
		local node = NewNode(v, r)
		local l = f:ReadByte()
		index = index + 1
		binds[node] = {}

		for i = 1, l do
			local id = f:ReadUShort()
			binds[node][id] = true
		end
	end

	for node, tb in next, binds do
		for id in next, tb do
			local bind = buffer[id]
			if bind then
				Bind_Internal(node, buffer[id])
			end
		end
	end
end

nav = {
	buffer = buffer,
	GetClosestsNode = GetClosestsNode,
	RemoveNode = RemoveNode,
	NewNode = NewNode,
	FindPath = FindPath,
	WriteFile = WriteFile,
	ReadFile = ReadFile,
	AproximateVector = AproximateVector,
	GetClosestsNode = GetClosestsNode
}
