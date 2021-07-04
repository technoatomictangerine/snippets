local timerSimple, next, assert, isfunction, pcall = timer.Simple, next, assert, isfunction, pcall
local rate = 0

local GetTable, RemoveID, Create, GetCurrent do
	local tsks, rntsk, index = {}, false, 0

	local function _unpack(tb, k, l)
		local k, l = k or 1, l or #tb
		if k <= l then
			return tb[k], _unpack(tb, k + 1, l)
		end
	end

	local function RunNextTask()
		local k = next(tsks)

		if k == nil then
			rntsk = false
			return
		end

		local data = tsks[k]

		local s, err = pcall(data.func, data[1], data[2], data[3], data[4], data[5], data[6], data[7], data[8])
		if s ~= true then
			ErrorNoHalt('Failed task ', data.name, ' with error:\n\t', err, '\n')
		end
		tsks[k] = nil

		timerSimple(rate, RunNextTask)
	end

	function GetTable()
		return tasks
	end

	function Remove(name)
		for k, data in next, tsks do
			if data.name == name then
				tsks[k] = nil
			end
		end
	end

	function RemoveID(id)
		tsks[id] = nil
	end

	function Create(name, fn, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
		assert(isfunction(fn) == true)
		index = 1 + index
		local dbg = debug.getinfo(3, 'S')
		tsks[index] = {
			arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8,
			name = name,
			func = fn,
			src = dbg.short_src
		}

		if rntsk == false then
			rntsk = true
			timerSimple(rate, RunNextTask)
		end

		return id
	end

	function GetCurrent()
		return next(tsks)
	end
end

local NewThread, GetThreadTable do
	local timerCreate = timer.Create
	local timerRemove = timer.Remove
	local yield = coroutine.yield
	local wait = coroutine.wait
	local resume = coroutine.resume
	local create = coroutine.create
	local status = coroutine.status
	local SysTime = SysTime
	local mt = {counter = 0, __proto = 'threadobj'}
	local pool = {}
	mt.__index = mt

	function mt:Remove()
		timerRemove(self.name)
	end

	function mt:Destroy()
		self.Callback()
		timerRemove(self.name)
	end

	function mt:yield(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
		yield(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
	end

	function mt:wait(s)
		wait(s)
	end

	function mt:pause(c)
		self.counter = self.counter + 1
		if self.counter > c then
			self.counter = 0
			yield()
		end
	end

	function mt:status()
		return status(self.thread)
	end

	function mt:wrap(fn, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
		local co = create(fn)
		self.Callback = function()
			if status(co) == 'dead' then self:Remove() return end
			local succ, out1, out2, out3, out4, out5, out6, out7, out8 =
				resume(co, self, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
			if not succ then Error(out1) end
			return out1, out2, out3, out4, out5, out6, out7, out8
		end
		self.thread = co
		return self.Callback
	end

	function mt:GetRuntime()
		return SysTime() - self.start
	end

	function mt:__call()
		return self.fn()
	end

	function NewThread(name, rate, fn, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
		name = 'ContinuesThreadObject::' .. name
		local obj = setmetatable({name = name, start = SysTime()}, mt)
		timerCreate(name, rate, 0, obj:wrap(fn, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8))
		return obj
	end

	function GetThreadTable()
		return pool
	end
end

task = {
	GetTable = GetTable,
	RemoveID = RemoveID,
	Create = Create,
	GetCurrent = GetCurrent,
	NewThread = NewThread,
	GetThreadTable = GetThreadTable
}
