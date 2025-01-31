---@diagnostic disable: duplicate-set-field

function love.load()
	CONSOLE = require("src.console")
	CONSOLE:init()

	local font = love.graphics.newFont("font.ttf")
	love.graphics.setFont(font)

	love.window.setMode(1280, 720)

	CONSOLE:setVarInEnv(CONSOLE, "console")
	love.graphics.setDefaultFilter("nearest", "nearest")

	PLAYER = CONSOLE:setVarInEnv({
		x = 200,
		y = 300,
		w = 50,
		h = 50,
	}, "PLAYER")
	CONSOLE:setVarInEnv(love, "love")
	CONSOLE.log("Hello, World!")
end

function love.update(dt)
	CONSOLE:update()
	CONSOLE:setVarInEnv(dt, "dt")
end

function love.draw()
	love.graphics.rectangle("line", PLAYER.x, PLAYER.y, PLAYER.w, PLAYER.h)

	CONSOLE:draw()
end

function love.keypressed(key)
	CONSOLE:keypressed(key)
end

function love.textinput(t)
	CONSOLE:textinput(t)
end
