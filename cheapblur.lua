local render, shouldupdate = render
local rt = GetRenderTarget('blurscreen_cache', 256, 256)
local mat = CreateMaterial('blurscreen_cache', 'UnlitGeneric', {
	['$translucent'] = 1,
	['$alpha'] = 1,
	['$basetexture'] = rt:GetName(),
	['$vertexalpha'] = 1,
})

do
	local ScrW, ScrH = ScrW, ScrH
	
	function draw.Blur(x, y)
		local w, h = ScrW(), ScrH()
		render.SetMaterial(mat)
		render.DrawScreenQuadEx(x, y, w, h)
		shouldupdate = true
	end
end

do
	local cvRate = CreateConVar('r_blurframes', '31', FCVAR_ARCHIVE, '', 1, 61)
	local nextupd, blurvalue = 0, ScrW() / 256 + 3
	local screen = render.GetRefractTexture()

	local function DoBlur(rt)
		render.PushRenderTarget(rt)
		render.DrawTextureToScreen(screen)
		render.BlurRenderTarget(rt, blurvalue, blurvalue, 3)
		render.PopRenderTarget()
	end

	hook.Add('PostDrawEffects', 'UpdateBlur', function()
		if shouldupdate ~= true then return end
		local now, w, h = RealTime(), ScrW(), ScrH()

		shouldupdate = false
		if now > nextupd then
			nextupd = now + (1 / cvRate:GetInt())

			render.UpdateRefractTexture()
			render.CopyTexture(screen, rt)
			DoBlur(rt)
		end
	end)
end
