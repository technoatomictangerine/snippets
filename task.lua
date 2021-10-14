local yield = coroutine.yield
local create = coroutine.create
local resume = coroutine.resume
local timerSimple = timer.Simple
local SysTime = SysTime
local call = hook.Run

local Create, GetTable do
	local Run, co, running, start
	local pcall, ErrorNoHalt = pcall, ErrorNoHalt
	local index, list, names = 0, {}, {}
	local rate = 1 / 300
	local wait = 1 / 16

	function GetTable() return list, index end

	function Create(name, fn, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
		index = index + 1
		names[index] = name
		list[index] = function()
			return pcall(fn, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
		end
		if not running then
			running = true
			timerSimple(wait, Run)
		end
		return index
	end

	function Run()
		start = SysTime()
		local success, breakruntime = resume(co)
		if not success or breakruntime then
			running = false
		else
			timerSimple(wait, Run)
		end
	end

	co = create(function()
		while true do
			local fn, name = list[index], names[index]
			index = index - 1
			if fn ~= nil then
				if SysTime() - start > rate then yield() end
				local succ, err = fn()
				if not succ then
					ErrorNoHalt('Task failed: ', name, '\n\t', err, '\n')
				end
			end
			if index == 0 then yield(true) end
		end
	end)
end

local NewThread, GetThreadTable do
	local format = string.format
	local timerCreate = timer.Create
	local timerRemove = timer.Remove
	local wait = coroutine.wait
	local status = coroutine.status
	local start = 0
	local mt = {counter = 0}
	local pool = {}
	mt.__index = mt

	function mt:Remove()
		timerRemove(self.id)
		call('ThreadDestroy', self.name)
	end

	function mt:Destroy()
		self.Callback()
		timerRemove(self.id)
		call('ThreadDestroy', self.name)
	end

	function mt:SetRemoveCondition(fn)
		self.shouldrm = fn
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

	function mt:limit(c)
		if SysTime() - start > c then yield() end
	end

	function mt:status()
		return status(self.thread)
	end

	function mt:wrap(fn, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
		local co = create(fn)
		self.Callback = function()
			if status(co) == 'dead' or (self.shouldrm and self:shouldrm()) then self:Remove() return end
			start = SysTime()
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
		call('ThreadRunning', name)
		local id = format('ThreadObject::%s', name)
		local obj = setmetatable({name = name, id = id, start = SysTime()}, mt)
		timerCreate(id,
			rate, 0, obj:wrap(fn, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8))
		return obj
	end

	function GetThreadTable()
		return pool
	end
end

task = {
	Create = Create,
	GetTable = GetTable,
	NewThread = NewThread,
	GetThreadTable = GetThreadTable
}
