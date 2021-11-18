local gc = collectgarbage
local floor, max = math.floor, math.max
local SysTime = SysTime
local limit, die, start = 1 / 300, 0, 0
local create, yield, resume =
	coroutine.create, coroutine.yield, coroutine.resume
local format = string.format
local timerCreate = timer.Create
local running = false
local notice, kill, progress

if SERVER then
	local fn = function()end
	notice = fn
	progress = fn
	kill = fn
else
	notice = notification.AddLegacy
	kill = notification.Kill
	progress = notification.AddProgress
end

local phrase, progressphrase do
	if CLIENT then
		local cc = GetConVarString('gmod_language')

		if cc == 'ru' or cc == 'uk' then
			phrase = 'Очищено %.2fМБ за %d мс'
			progressphrase = 'Убираю мусор...'
		else
			phrase = 'Garbage collected %.2fMB in %d ms'
			progressphrase = 'Collecting garbage...'
		end
	end
end

local function _gc()
	local kb = gc'count'
	while gc('step', 1) do
		if SysTime() > die then yield() end
	end

	kb = max(0, floor(kb - gc'count')) * 1024
	local ms = 1000 * (SysTime() - start)
	notice(format(phrase, kb, ms), 3, 3)
end

timerCreate('CollectGarbage', 300, 0, function()
	if running then return end
	running = true
	start = SysTime()
	local co = create(_gc)
	progress('CollectGarbage.Process', progressphrase)
	timerCreate('CollectGarbage.Process', 0, 0, function()
		if co == nil or not resume(co) then
			timer.Remove('CollectGarbage.Process')
			kill('CollectGarbage.Process')
			running = false
		end
	end)
end)

gc'stop'
