local Players = game:GetService("Players")

local GeneratorInit = require(script.GeneratorInit)

--[[
	config
]]
local INTERMISSION_TIME: number = 1 -- intermission between rounds
local ROUND_TIME: number = 200 -- round time, if generators arent done by this time, all survivors lose
local ESCAPE_TIME: number = 120 -- after gens are finished the door will open, time before door closes

local MINIMUM_PLAYERS_PER_ROUND: number = 0 -- minimum amount of players before round starts	
local REFRESH_RATE_MINIMUM_PLAYERS: number = .5 -- time between each player amount check

while true do
	-- if not enough players then wait
	repeat 
		task.wait(REFRESH_RATE_MINIMUM_PLAYERS)
	until #Players:GetPlayers() >= MINIMUM_PLAYERS_PER_ROUND
	
	--[[
		INTERMISSION
	]]
	
	-- incase of map change, therefore, new gen spots
	GeneratorInit.GeneratorParent = workspace.Map1.Interactable.Generators
	GeneratorInit.GeneratorPointParent = workspace.Map1.Interactable.Generators.Points
	GeneratorInit.Initialize()
	GeneratorInit.CreateGenerators().Run()
	
	task.wait(INTERMISSION_TIME)
	
	--[[
		ROUND START (FINISH ALL GENERATORS)
	]]
	
	local currentGeneratorsActive = {}
	local roundEnd = Instance.new("BindableEvent")
	
	-- end if round time finishes
	local delayThread
	delayThread = task.delay(ROUND_TIME, function()
		roundEnd:Fire()
	end)
	
	-- proceed if all generators were finished
	for generatorModel,generatorData in GeneratorInit.CurrentGenerators do
		table.insert(currentGeneratorsActive, generatorModel)
		
		-- can only ran if turned to true
		generatorData.IsFinished.Changed:Once(function()
			if generatorData.IsFinished.Value then
				table.remove(currentGeneratorsActive, table.find(currentGeneratorsActive, generatorModel))
				
				if #currentGeneratorsActive == 0 then
					roundEnd:Fire()
				end
			end
		end)
	end
	
	--[[
		ROUND ENDED
	]]
	
	roundEnd.Event:Wait()
	roundEnd:Destroy()
	task.cancel(delayThread)
	
	if #currentGeneratorsActive ~= 0 then -- failed to finish all generators in time, end round
		continue 
	end
	
	--[[
		if finished all generators,
		EXIT RUN START (RUN TO THE EXIT)
	]]
	
	--TO BE CONTINUED
end
