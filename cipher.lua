local bit = assert(bit or require('bit32') or require('bit') or require('LuaBit'), 'There are no any BIT library')
local seed = 1337 --CHANGE ME
local char, byte, xor = string.char, string.byte, bit.bxor

local function random(k, i)
	return xor(seed * i + k * k, 2 ^ k - 1) % i
end

local function shuffle(k)
	local t = {}
	for i = 0, 255 do
		t[i] = i
	end

	for i = 255, 1, -1 do
		local j = random(k, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

local function revert(t)
	local out = {}
	for k, v in pairs(t) do
		out[v] = k
	end
	return out
end

local cipher = {}

function cipher.encode(str, k)
	local out, t = {}, shuffle(k)

	for i, b in pairs({byte(str, 1, #str)}) do
		out[i] = t[b]
	end

	return char(unpack(out))
end

function cipher.decode(str, k)
	local out, t = {}, revert(shuffle(k))

	for i, b in pairs({byte(str, 1, #str)}) do
		out[i] = t[b]
	end

	return char(unpack(out))
end

return cipher
