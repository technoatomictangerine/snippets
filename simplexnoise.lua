--[[Original: http://staffwww.itn.liu.se/~stegu/simplexnoise/simplexnoise.pdf
	The original implementation by Ken Perlin
	Translated and modified by @scuroin]]

local noise = {}
local floor = math.floor

local grd = {	
	[0] = {1, 1, 0}, 	[1] = {-1, 1, 0}, 	[2] = {1, -1, 0}, 	[3] = {-1, -1, 0},
	[4] = {1,0,1}, 		[5] = {-1,0,1}, 	[6] = {1,0,-1}, 	[7] = {-1,0,-1},
	[8] = {0,1,1}, 		[9] = {0,-1,1}, 	[10] = {0,1,-1}, 	[11] = {0,-1,-1}
}

local function dot(tab, x, y)
	return tab[1] * x + tab[2] * y
end

local prv, prm = {}, {}

function noise.make(x, y)
	if prv[x] and prv[x][y] then return prv[x][y] end 

	local n0, n1, n2
	local f = .5 * (3 ^ .5 - 1)
	local s = (x + y) * f
	local i = floor(x + s)
	local j = floor(y + s)
	local g = (3 - 3 ^ .5) / 6
	
	local t = (i + j) * g
	local X0, Y0 = i - t, j - t
	local x0, y0 = x - X0, y - Y0
	
	local i1, j1
	if x0 > y0 then 
		i1 = 1
		j1 = 0
	else
		i1 = 0
		j1 = 1
	end

	local x1 = x0 - i1 + g
	local y1 = y0 - j1 + g
	local x2 = x0 - 1 + 2 * g
	local y2 = y0 - 1 + 2 * g

	local ii = i % 255
	local jj = j % 255
	local gi0 = prm[ii + prm[jj]] % 12
	local gi1 = prm[ii + i1 + prm[jj + j1]] % 12
	local gi2 = prm[ii + 1 + prm[jj + 1]] % 12

	local t0 = 0.5 - x0 * x0 - y0 * y0
	if t0 < 0 then 
		n0 = 0
	else
		t0 = t0 * t0
		n0 = t0 * t0 * dot(grd[gi0], x0, y0)
	end
	
	local t1 = .5 - x1 * x1 - y1 * y1;
	if t1 < 0 then
		n1 = 0
	else
		t1 = t1 * t1
		n1 = t1 * t1 * dot(grd[gi1], x1, y1)
	end
	
	local t2 = .5 - x2 * x2 - y2 * y2;
	if (t2 < 0) then
		n2 = 0
	else
		t2 = t2 * t2
		n2 = t2 * t2 * dot(grd[gi2], x2, y2)
	end

	local out = 70 * (n0 + n1 + n2)
	
	if not prv[x] then prv[x] = {} end
	prv[x][y] = out
	
	return out
end

function noise.seed(seed)
  local s = floor(seed * math.pi * 5051671)

  local p = {}
  prv = {}

  for i = 1, 256 do
    p[i - 1] = (s + floor(s / i)) % 256
  end

  for i = 0, 255 do
    prm[i] = p[i]
    prm[i + 256] = p[i]
    prm[i + 512] = p[i]
  end
end

return noise
