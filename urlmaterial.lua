local QueuedLoop
local GetRenderTargetEx = GetRenderTargetEx
local CreateMaterial = CreateMaterial
local filter_pass = 4
local empty = table.Empty
local hookRemove = hook.Remove
local hook = hook.Add
local qtex, qurl, qlen = {}, {}, 0
local timerSimple = timer.Simple

local html = [[<style>html{margin: -8px -8px;overflow: hidden;}</style>
<html><img width="%s" height="%s" onload="game.renderimg();" src="%s"/></html>]]

QueuedLoop = function()
	if qlen == 0 then
		empty(qurl)
		return
	end

	local pnl
	local url = qurl[qlen]
	local rt = qtex[url]
	local w, h =
		rt:Width(), rt:Height()
	qlen = qlen - 1

	local function LoadCallback(mat)
		timerSimple(0, function()
			hook('PostRender', 'RenderTexture', function()
				hookRemove('PostRender', 'RenderTexture')
				render.PushRenderTarget(rt, 0, 0, w, h)
				render.OverrideAlphaWriteEnable(true, true)
				render.Clear(0, 0, 0, 0, true, true)

				cam.Start2D()
				for i = 1, filter_pass do
					render.PushFilterMag(3)
					render.PushFilterMin(3)
				end
				
				pnl:PaintManual()

				for i = 1, filter_pass do
					render.PopFilterMag()
					render.PopFilterMin()
				end
				cam.End2D()

				render.OverrideAlphaWriteEnable(false)

				render.PopRenderTarget()
				pnl:Remove()
				timerSimple(0, QueuedLoop)
			end)
		end)
	end
	
	pnl = vgui.Create('DHTML')
	pnl:SetPaintedManually(true)
	pnl:AddFunction('game', 'renderimg', LoadCallback)
	pnl:SetHTML(html:format(w, h, url))
	pnl:SetVisible(true)
end

local mat_table = {
	['$basetexture'] = '_rt_FullFrameFB',
	['$translucent'] = 1,
	['$alpha'] = 1,
	['$vertexalpha'] = 1,
	['$vertexcolor'] = 1,
	['$noclamp'] = 1,
	['$nocull'] = 0,
	['$ignorez'] = 1,
	['$distancealpha'] = 1,
	['$softedges'] = 1,
	['$edgesoftnessstart'] = .45,
	['$edgesoftnessend'] = .3,
	['$scaleedgesoftnessbasedonscreenres'] = 1
}

function surface.GetURL(url, w, h)
	if qtex[url] then return qtex[url] end
	local mat = CreateMaterial(url, 'UnlitGeneric', mat_table)
	local rt = GetRenderTargetEx(url,
		w or 256, h or 256,
		0, 1, 16, 0, 0)
	mat:SetTexture('$basetexture', rt)
	qtex[url] = rt

	qlen = qlen + 1
	qurl[qlen] = url
	if qlen == 1 then timerSimple(0, QueuedLoop) end
	return mat
end
