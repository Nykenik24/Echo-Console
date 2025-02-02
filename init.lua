local function getScriptFolder()
	return (debug.getinfo(1, "S").source:sub(2):match("(.*/)"))
end
return require(getScriptFolder() .. "src.console")
