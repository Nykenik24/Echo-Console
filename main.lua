---@diagnostic disable: duplicate-set-field

function love.load()
	CONSOLE = require("src.console")
	CONSOLE:init()

	local font = love.graphics.newFont("font.ttf")
	love.graphics.setFont(font)

	love.window.setMode(1280, 720)

	CONSOLE:setVarInEnv(CONSOLE, "console")
	love.graphics.setDefaultFilter("nearest", "nearest")

	RECTANGLES = CONSOLE:setVarInEnv({}, "RECTANGLES")

	CONSOLE:setVarInEnv(love, "love")

	CONSOLE:setVarInEnv(SpawnRect, "SpawnRect")
	CONSOLE.cmd("func spawn SpawnRect(args[1], args[2])")
	CONSOLE.cmd(
		"func randomspawn SpawnRect(math.random(0, love.graphics.getWidth()), math.random(0, love.graphics.getHeight()))"
	)

	CONSOLE:setVarInEnv(DespawnRect, "DespawnRect")
	CONSOLE.cmd("func despawn DespawnRect(args[1])")

	CONSOLE:setVarInEnv(ChangeRectangleSpeed, "ChangeRectSpeed")
	CONSOLE.cmd("func chspeed ChangeRectSpeed(args[1])")

	RECT_SPEED = CONSOLE:setVarInEnv(200, "RECT_SPEED")

	PAUSED = CONSOLE:setVarInEnv(true, "PAUSED")
	CONSOLE.cmd("func pause PAUSED = true")
	CONSOLE.cmd("func resume PAUSED = false")

	for _ = 1, 5 do
		CONSOLE.cmd("randomspawn")
	end

	FULLSCREEN = false
	WAS_IN_FULSCREEN = FULLSCREEN
end

function love.update(dt)
	CONSOLE.utils.linkGlobalToEnvVariable("PAUSED", "PAUSED")
	CONSOLE.utils.linkGlobalToEnvVariable("RECTANGLES", "RECTANGLES")

	if not PAUSED then
		for _, rect in ipairs(RECTANGLES) do
			rect.x = rect.x + RECT_SPEED * dt
			if rect.x > love.graphics.getWidth() then
				rect.x = 0 - rect.w
			end
		end
	end

	CONSOLE:setVarInEnv(dt, "dt")

	if WAS_IN_FULSCREEN ~= FULLSCREEN then
		love.window.setFullscreen(FULLSCREEN)
	end
	WAS_IN_FULSCREEN = FULLSCREEN

	CONSOLE:update()
end

function love.draw()
	for index, rect in ipairs(RECTANGLES) do
		love.graphics.setColor(rect.color.r, rect.color.g, rect.color.b)
		love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
		love.graphics.print(tostring(index), rect.x + 5, rect.y + 5)
		love.graphics.setColor(1, 1, 1)
	end

	CONSOLE:draw()
end

function love.keypressed(key)
	CONSOLE:keypressed(key)
end

function love.textinput(t)
	CONSOLE:textinput(t)
end

function SpawnRect(x, y)
	table.insert(RECTANGLES, {
		x = x,
		y = y,
		w = math.random(25, 100),
		h = math.random(25, 100),
		color = { r = math.random(0, 1), g = math.random(0, 1), b = math.random(0, 1) },
	})
	CONSOLE.log("Spawned rectangle")
end

function DespawnRect(rect_index)
	table.remove(RECTANGLES, rect_index)
	CONSOLE.log("Despawned rectangle " .. tostring(rect_index))
end

function ChangeRectangleSpeed(speed)
	RECT_SPEED = speed
end
