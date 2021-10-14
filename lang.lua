local locale = {}
local code = GetConVarString('gmod_language')
local gsub = string.gsub

local function GetLanguage()
	return code
end

local function Add(name, text)
	locale['#' .. name] = text
end

local function Get(s)
	return locale[s] or s
end

local function Translate(text)
	return gsub(text, '#[%w_%.]+', locale)
end

function Panel.SetText(self, text)
	SetText(self, Translate(text))
end

lang = {
	Table = locale,
	Add = Add,
	Get = Get,
	Translate = Translate,
	GetLanguage = GetLanguage
}
