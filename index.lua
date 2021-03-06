local s,c = pcall(function()
-- MarI/O by SethBling
-- Feel free to use this code, but please do not redistribute it.
-- Intended for use with the BizHawk emulator and Super Mario World or Super Mario Bros. ROM.
-- For SMW, make sure you have a save state named "DP1.state" at the beginning of a level,
-- and put a copy in both the Lua folder and the root directory of BizHawk.

package.loaded = {}
REAL_REQUIRE = REAL_REQUIRE or require
ffi = REAL_REQUIRE "ffi"

function require(mod)
    if (not package.loaded[mod]) then
        package.loaded[mod] = dofile(mod..".lua") or {}
    end
    return package.loaded[mod]
end


local math = math
local memory = memory

local function sigmoid(x)
	return 2/(1+math.exp(-4.9*x))-1
end
package.loaded = {}
local rio = io
local mutate    = require "mutate"
local new       = require "new"
local routine   = require "routine"
local global    = require "globals"
local construct = require "construct"
local ram       = require "ram"
local io        = require "io"
local SMW		= require "lib/SMW"
local osd		= require "osd"

local function fitnessAlreadyMeasured(pool)
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	
	return genome.fitness ~= 0
end

local function getCellScreen(x, y, curScreenX, curScreenY)
    return x + curScreenX, y + curScreenY
end
local validRenderValues = {
    [1] = 0x80000000,
    [-1] = 0x80ff0000,
}
local function displayGenome(genome)
    local curScreenX, curScreenY = 
        genome.curScreenX, genome.curScreenY
        
    local playerPosition = ram.getPlayerHitbox(curScreenX, curScreenY)
    
    gui.drawRectangle(playerPosition.x, playerPosition.y, playerPosition.w, playerPosition.h, 0x400000ff, 0x400000ff)
    
	local network = genome.network
    local neurons = network.neurons
    local i = 1
	for dy= -BoxRadius * 16, BoxRadius * 16 - 1 do
        local lastx, lastcol
		for dx= -BoxRadius * 16, BoxRadius * 16 - 1 do
            local cval = neurons[i].value
            local col = validRenderValues[cval]
            if (lastx and col ~= lastcol) then
                
                local cx, cy = getCellScreen(lastx, dy, curScreenX, curScreenY)
                
                gui.drawRectangle(cx, cy, dx - lastx, 1, lastcol, lastcol)
                lastx = nil
            end
            if (not lastx and col) then
                lastx = dx
                lastcol = col
            end
            i = i + 1
		end
        if (lastx) then

            local cx, cy = getCellScreen(lastx, dy, curScreenX, curScreenY)
            
            gui.drawRectangle(cx, cy, (BoxRadius * 16) - lastx, 1, lastcol, lastcol)
        end
	end
    --[[
	local biasCell = {}
	biasCell.x = 80
	biasCell.y = 110
	biasCell.value = network.neurons[Inputs].value
	cells[Inputs] = biasCell
	
	for o = 1,Outputs do
		cell = {}
		cell.x = 220
		cell.y = 30 + 8 * o
		cell.value = network.neurons[MaxNodes + o].value
		cells[MaxNodes+o] = cell
		local color
		if cell.value > 0 then
			color = 0xFF0000FF
		else
			color = 0xFF000000
		end
		gui.drawText(223, 24+8*o, ButtonNames[o], color, 9)
	end
	
	for n,neuron in pairs(network.neurons) do
		cell = {}
		if n > Inputs and n <= MaxNodes then
			cell.x = 140
			cell.y = 40
			cell.value = neuron.value
			cells[n] = cell
		end
	end
	
	for n=1,4 do
		for _,gene in pairs(genome.genes) do
			if gene.enabled then
				local c1 = cells[gene.into]
				local c2 = cells[gene.out]
				if gene.into > Inputs and gene.into <= MaxNodes then
					c1.x = 0.75*c1.x + 0.25*c2.x
					if c1.x >= c2.x then
						c1.x = c1.x - 40
					end
					if c1.x < 90 then
						c1.x = 90
					end
					
					if c1.x > 220 then
						c1.x = 220
					end
					c1.y = 0.75*c1.y + 0.25*c2.y
					
				end
				if gene.out > Inputs and gene.out <= MaxNodes then
					c2.x = 0.25*c1.x + 0.75*c2.x
					if c1.x >= c2.x then
						c2.x = c2.x + 40
					end
					if c2.x < 90 then
						c2.x = 90
					end
					if c2.x > 220 then
						c2.x = 220
					end
					c2.y = 0.25*c1.y + 0.75*c2.y
				end
			end
		end
	end
	
	gui.drawRectangle(0, 30, (1+BoxRadius*2)*16,(1+BoxRadius*2)*16,0xFF000000, 0x80808080)
	for n,cell in pairs(cells) do
		if n > Inputs or cell.value ~= 0 then
			local color = math.floor((cell.value+1)/2*256)
			if color > 255 then color = 255 end
			if color < 0 then color = 0 end
			local opacity = 0xFF000000
			if cell.value == 0 then
				opacity = 0x50000000
			end
			color = opacity + color*0x10000 + color*0x100 + color
			gui.drawRectangle(cell.x,cell.y,1,1,opacity,color)
		end
	end
	for _,gene in pairs(genome.genes) do
		if gene.enabled then
			local c1 = cells[gene.into]
			local c2 = cells[gene.out]
			local opacity = 0xA0000000
			if c1.value == 0 then
				opacity = 0x20000000
			end
			
			local color = 0x80-math.floor(math.abs(sigmoid(gene.weight))*0x80)
			if gene.weight > 0 then 
				color = opacity + 0x8000 + 0x10000*color
			else
				color = opacity + 0x800000 + 0x100*color
			end
		--	gui.drawRectangle(c1.x, c1.y, 1, 1, color)
		end
	end
	
	gui.drawRectangle(BoxRadius * 16,30 + BoxRadius * 16, 16, 16,0x80FF0000,0x80FF0000)
	
	if forms.ischecked(showMutationRates) then
		local pos = 100
		for mutation,rate in pairs(genome.mutationRates) do
			gui.drawText(100, pos, mutation .. ": " .. rate, 0xFF000000, 10)
			pos = pos + 8
		end
	end]]
end
local saveLoadFile
local maxFitnessLabel
local function savePool(pool)
	local filename = forms.gettext(saveLoadFile)
	io.writeFile(filename, pool)
end

local function loadPool()
	local filename = forms.gettext(saveLoadFile)
	local pool = io.loadFile(filename, maxFitnessLabel)
	while fitnessAlreadyMeasured(pool) do
		construct.nextGenome(pool)
	end
	routine.initializeRun(pool)
	pool.currentFrame = pool.currentFrame + 1
    return pool
end

local function playTop(pool)
	local maxfitness = 0
	local maxs, maxg
	for s,species in pairs(pool.species) do
		for g,genome in pairs(species.genomes) do
			if genome.fitness > maxfitness then
				maxfitness = genome.fitness
				maxs = s
				maxg = g
			end
		end
	end
	
	pool.currentSpecies = maxs
	pool.currentGenome = maxg
	pool.maxFitness = maxfitness
	forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
	routine.initializeRun(pool)
	pool.currentFrame = pool.currentFrame + 1
	return
end

local pool = new.newPool()
routine.initializePool(pool)

io.writeFile("temp.pool", pool)


local form = forms.newform(220, 264, "Fitness")
maxFitnessLabel = forms.label(form, "Max Fitness: " .. math.floor(pool.maxFitness), 5, 8)
local showNetwork = forms.checkbox(form, "Show Map", 6, 30)
local showOnScreenDisplay = forms.checkbox(form, "Show OSD", 6, 52)
local showButtonPresses = forms.checkbox(form, "Show Buttons", 6, 74)
local showMutationRates = false -- forms.checkbox(form, "Show M-Rates", 6, 96) --NOT IMPLEMENTED
saveLoadFile = forms.textbox(form, Filename .. ".pool", 149, 25, nil, 6, 142)
local saveLoadLabel = forms.label(form, "Save/Load:", 5, 128)
local saveButton = forms.button(form, "Save", function() savePool(pool) end, 5, 166)
local loadButton = forms.button(form, "Load", function() pool = loadPool() end, 80, 166)
local playTopButton = forms.button(form, "Play Top", function() playTop(pool) end, 5, 192)
local restartButton = forms.button(form, "Restart", function()
    pool = new.newPool()
    routine.initializePool(pool)
end, 80, 192)


event.onexit(function()
	gui.clearGraphics()
	forms.destroy(form)
end)

local time = os.clock


--[[
local logs = {}
local next_time = time() + .1
debug.sethook(function(_, l)
    local t = time()
    if (t > next_time) then
        next_time = t
        local source = debug.getinfo(2).short_src
        local index = source..":"..l
        logs[index] = (logs[index] or 0) + 1
    end
end, "l")
event.onexit(function()
    local t = {}
    for k,v in pairs(logs) do
        t[#t + 1] = {k,v}
    end
    table.sort(t, function(a, b) return a[2] > b[2] end)
    local f =  rio.open("log.txt", "w+")
    for i = 1, #t do
        f:write(t[i][1]..(" "):rep(60 - t[i][1]:len())..t[i][2].."\r\n")
    end
    f:close()
end)]]
local levelFitness = 0
local timeout = TimeoutConstant

while true do
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]

	local levelActive = memory.readbyte(SMW.WRAM.game_mode) == SMW.constant.game_mode_level
	local drumroll = memory.readbyte(SMW.WRAM.score_incrementing)
	local reachedGoal = (drumroll ~= 0x50) and (drumroll ~= 0)
	local levelEnd = memory.readbyte(0x0DDA) == 0xFF
	local timeoutBonus = pool.currentFrame / 4
	local shouldReset = timeout + timeoutBonus <= 0 or reachedGoal or not levelActive
	local fitness = levelFitness - pool.currentFrame / 2	
	timeout = timeout - 1

	
    if levelActive and not reachedGoal and not levelEnd then
		routine.evaluateCurrent(pool)
			
		local marioX, marioY = ram.getPosition()
		local startPos = ram.getStartPosition()
		local dist = math.sqrt((marioX - startPos.x) ^ 2 + (marioY - startPos.y) ^ 2) 
		
		if dist > levelFitness then
			levelFitness = dist
			timeout = TimeoutConstant
		end
	end

	
	if shouldReset then
		-- Update final fitness values before they are displayed on screen (one frame shouldn't matter, but it annoyed me :D)
		if reachedGoal then
			local timerBonus = math.floor(TimeBonusInitialValue * math.pow(1 + (TimeBonusGrowthRate / 100), ram.getTimerLeft()))
			fitness = fitness + timerBonus
			--console.writeline("MarI/O reached the goal! Fitness: "..fitness.." (bonus: "..timerBonus..")")
		else
			if not levelActive then
				fitness = fitness - DeathPenaltyValue
				--console.writeline("MarI/O died! Fitness: "..fitness.." (penalty: "..DeathPenaltyValue..")")
			end
		end
		if fitness <= 0 then
			fitness = -1
		end
	end
	
	
	if forms.ischecked(showNetwork) then
		displayGenome(genome)
	end

	if forms.ischecked(showButtonPresses) then
		osd.displayInputs(routine.getButtons())
	end
	
	if forms.ischecked(showOnScreenDisplay) then
    	local measured = 0
    	local total = 0
        local species = pool.species
        for i = 1, #species do
            local genomes = species[i].genomes
            for i = 1, #genomes do
                total = total + 1
                if (genomes[i].fitness ~= 0) then
                    measured = measured + 1
                end
            end
        end
		osd.displayBanner(
			"Gen: "..pool.generation..", Species: "..pool.currentSpecies..", Genome: "..pool.currentGenome.." ("..math.floor(measured/total*100).."%)",
			"Fitness: "..math.floor(levelFitness - (pool.currentFrame) / 2 - (timeout + timeoutBonus)*2/3).." (max: "..math.floor(pool.maxFitness)..")"
		)
	end
	
	
	if shouldReset then
		genome.fitness = fitness
		
		if fitness > pool.maxFitness then
			pool.maxFitness = fitness
			forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
			io.writeFile("backup." .. pool.generation .. "." .. forms.gettext(saveLoadFile), pool)
		end
		
		pool.currentSpecies = 1
		pool.currentGenome = 1
		while fitnessAlreadyMeasured(pool) do
			construct.nextGenome(pool)
		end
		routine.initializeRun(pool)
		levelFitness = 0
        timeout = TimeoutConstant
	else
		pool.currentFrame = pool.currentFrame + 1
	end
	
	emu.frameadvance();
    coroutine.yield()
    
end
end)

print(s,c)