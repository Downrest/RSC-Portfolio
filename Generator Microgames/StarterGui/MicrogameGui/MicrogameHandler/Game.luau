local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Modules.Janitor)
local Config = require(script.Parent.Config)

local Game = {}

Game.MicrogameList = {
	[Config.MicrogameNames.BlotweilerDrawing] = require(script.BlotweilerDrawing)
}:: Config.MicrogameList

Game.CurrentBPM = Config.DEFAULT_GAMEPLAY_BPM

local randomGen = Random.new()

local function getCurrentMicrogame(gameData: Config.GameData, microgameName: string): Config.MicrogameModule & number
	local targetCurrentMicrogame
	local targetIndex

	for currentIndex, currentMicrogame in gameData.CurrentMicrogames do
		if currentMicrogame.MICROGAME_NAME == microgameName then
			targetCurrentMicrogame = currentMicrogame
			targetIndex = currentIndex
			break
		end
	end
	
	return targetCurrentMicrogame, targetIndex
end

function Game.new(startingLives: number): Config.GameData
	local gameData = {}

	gameData.CurrentMicrogames = {}
	gameData.MicrogamesPlayed = 0

	gameData.CurrentLives = startingLives

	gameData._janitor = Janitor.new()

	for _, microgameModule: Config.MicrogameModule in Game.MicrogameList do
		table.insert(gameData.CurrentMicrogames, microgameModule)
	end

	return gameData
end

function Game.RemoveLives(gameData: Config.GameData, removedLives: number)
	gameData.CurrentLives -= removedLives
end

function Game.HasMicrogames(gameData: Config.GameData): boolean
	return (#gameData.CurrentMicrogames > 0)
end

function Game.PopRandom(gameData: Config.GameData): Config.MicrogameModule
	local randomIndex = randomGen:NextInteger(1, #gameData.CurrentMicrogames)
	local randomMicrogame = gameData.CurrentMicrogames[randomIndex] 

	gameData._janitor:Add(randomMicrogame.Started:Once(function()
		gameData.MicrogamesPlayed += 1
	end), "Disconnect")

	table.remove(gameData.CurrentMicrogames, randomIndex)
	return randomMicrogame
end

function Game.PopSpecific(gameData: Config.GameData, microgameName: Config.MicrogameNames): Config.MicrogameModule
	local specificMicrogame, specificIndex = getCurrentMicrogame(gameData, microgameName)
	assert(specificMicrogame ~= nil, "specific microgame not found!")

	gameData._janitor:Add(specificMicrogame.Started:Once(function()
		gameData.MicrogamesPlayed += 1
	end), "Disconnect")

	table.remove(gameData.CurrentMicrogames, specificIndex)
	return specificMicrogame
end

function Game.Destroy(_gameData: Config.GameData)
	_gameData._janitor:Cleanup()
	_gameData = nil -- set entire dictionary to nil, allowing for gc cleanup
end

return Game
