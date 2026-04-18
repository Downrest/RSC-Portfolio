local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Modules.Janitor)
local Config = require(script.Parent.Config)
local Signal = require(ReplicatedStorage.Modules.Signal)
local Timer = {}

--[[
	main functions
]]

function Timer.new(): Config.TimerData
	local timerData = {}

	timerData.IntValue = Instance.new("IntValue")
	timerData.BPM = Config.DEFAULT_GAMEPLAY_BPM

	timerData.TimerEnded = Signal.new()
	timerData.TimerBeatChanged = Signal.new()

	timerData._signals = {
		timerData.TimerEnded;
		timerData.TimerBeatChanged;
	}
	timerData._janitor = Janitor.new()

	return timerData
end

function Timer.Start(timerData: Config.TimerData)
	timerData._janitor:Add(task.spawn(function()
		local beatsPerSecond = Timer.ConvertBPMToPerSecond(timerData.BPM)
		local beatsDuration = Timer.ConvertSongDurationToBeats(timerData.IntValue.Value, beatsPerSecond)

		for currentBeat = beatsDuration, 1, -1 do
			timerData.TimerBeatChanged:Fire(currentBeat)

			task.wait(beatsPerSecond / 4)
		end

		timerData.TimerEnded:Fire()
	end))
end

function Timer.Stop(timerData: Config.TimerData)
	timerData._janitor:Cleanup()
end

function Timer.SetDuration(timerData: Config.TimerData, newTimerDuration: number)
	timerData.IntValue.Value = newTimerDuration
end

function Timer.SetBPM(timerData: Config.TimerData, newBPM: number)
	timerData.BPM = newBPM
end

--[[
	utility functions
]]

function Timer.ConvertBPMToPerSecond(givenBeatsPerMinute: number): number
	return givenBeatsPerMinute / 60
end

function Timer.ConvertSongDurationToBeats(givenDuration: number, beatsPerSecond: number): number	
	return givenDuration * beatsPerSecond + (beatsPerSecond / 2)
end
	

return Timer
