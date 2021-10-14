local meta = FindMetaTable('Player')
local vars = {}
local deffered = false
local assert = assert
local format = string.format
local query = sql.Query
local queryval = sql.QueryValue
local commit = sql.Commit
local commit_rate = 30
local timerSimple = timer.Simple
local esc, escv

local function begin()
	query('BEGIN TRANSACTION;')
end

do
	local repl = {['"'] = '\\"', ["'"] = "\\'", ['\0'] = '\\0', ['\\'] = '\\\\'}
	local tostring = tostring
	
	esc = function(arg)
		assert(arg, 'arg#1 should be a something')
		return tostring(arg):gsub("['\"\\%z]", repl)
	end

	escv = function(arg)
		if arg == nil then return[["NULL"]]end
		return format('"%s"', tostring(arg):gsub("['\"\\%z]", repl))
	end
end

local function DoCommit()
	if deffered then
		deffered = false
		commit()
	end
end

local function CreateVar(name, t)
	if vars[name] then return end
	local safe = esc(name)
	query(format('ALTER TABLE "asgpdata" ADD COLUMN "%s" %s;', safe, t))
	vars[name] = safe
end


local function GetPData(sid, name, v)
	name = vars[name]
	if name == nil then return def end
	DoCommit()

	local val = queryval(format('SELECT %s FROM "asgpdata" WHERE "sid" = "%s" LIMIT 1;', name, sid))
	if val == 'NULL' or val == nil then return def end
	return val
end

local function SetPData(sid, name, val)
	name = vars[name]
	assert(name)

	if not deffered then
		begin()
		deffered = true
		timerSimple(commit_rate, DoCommit)
	end

	return query(
		format('UPDATE "asgpdata" SET "%s" = %s WHERE "sid" = "%s";', name, escv(val), sid))
end

function meta:GetPData(name, def)
	name = vars[name]
	if name == nil then return def end
	DoCommit()

	local sid = self.SID
	local val = queryval(format('SELECT %s FROM "asgpdata" WHERE "sid" = "%s" LIMIT 1;', name, sid))
	if val == 'NULL' or val == nil then return def end
	return val
end

function meta:SetPData(name, val)
	name = vars[name]
	assert(name)

	if not deffered then
		begin()
		deffered = true
		timerSimple(commit_rate, DoCommit)
	end

	local sid = self.SID
	return query(
		format('UPDATE "asgpdata" SET "%s" = %s WHERE "sid" = "%s";', name, escv(val), sid))
end

function meta:SetupPData()
	local sid = self.SID
	query(
		format('INSERT OR IGNORE INTO asgpdata(sid) VALUES(%s);', sid))
end

do
	DoCommit()
	query('CREATE TABLE IF NOT EXISTS asgpdata("sid" INT NOT NULL PRIMARY KEY);')

	local out = query('PRAGMA table_info("asgpdata");')
	for _, t in next, out do
		local name = t.name
		local v = esc(name)
		vars[name] = v
	end
end

function sql.Query(q)
	DoCommit()
	return query(q)
end

hook.Add('ShutDown', 'SQLCommit', DoCommit)

sql.CreatePlayerVar = CreateVar
sql.EndCommit = DoCommit
sql.GetPData = GetPData
sql.SetPData = SetPData

sql.m_strError = nil
setmetatable(sql, {__newindex = function(_, k, v)
	if k == 'm_strError' and v then
		ErrorNoHalt('[SQL ERROR] ', v, '\n')

		for i = 2, 8 do
			local info = debug.getinfo(i, 'Sfl')
			if info == nil then break end
			ErrorNoHalt(string.rep(' ', i + 2), i - 1, '. ', info.short_src, ':', info.currentline, '\n')
		end
	end
end})
