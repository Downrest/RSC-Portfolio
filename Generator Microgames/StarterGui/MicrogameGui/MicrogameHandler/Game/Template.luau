local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Janitor = require(ReplicatedStorage.Modules.Janitor)
local Signal = require(ReplicatedStorage.Modules.Signal)
local Config = require(StarterGui.Microgame.MicrogameHandler.Config)

local Template: Config.MicrogameModule = {}

--[[
    public variables
]]

Template.MICROGAME_NAME = "Template"
Template.CONTROL_HINT_KEY = Config.ControlKeys.Mouse
Template.CONTROL_HINT_TEXT = "DRAW"
Template.SONG_NAME = "Template"
Template.SONG_END_TIME_POSITION = 3

Template.OnGameOver = Signal.new()
Template.Started = Signal.new()

Template._janitor = Janitor.new()
Template._currentGameGui = nil
Template._hasWon = false

--[[
    internal (state) variables
]]

-- incase you ever want to tag specific Janitor objects for cleanup, use this table like an enum
local taskNames = { 
    ["GameThread"] = "GameThread";
    ["GameGui"] = "GameGui";
}

--[[
    config
]]

local INSERT_CONSTANT

function Template.GetWinState(): boolean
    return Template._hasWon
end

function Template.StartGame()
    local janitor = Template._janitor
    local currentGameGui

    janitor:Add(task.spawn(function()
        currentGameGui = janitor:Add(
            script.Template:Clone(), 
            nil,
            taskNames.GameGui
		)
		Template._currentGameGui = currentGameGui

        --[[
            at some point if microgame has ended.
            
            change _hasWon and/or run OnGameOver:Fire() WHICH IS
            OPTIONAL -- you can just not do this if u want a win condition to
            not end the game (aka timer will end the game)
        ]]
    end), nil, taskNames.GameThread)
end

function Template.EndGame(forceWinState: boolean)
    local winState = forceWinState or Template._hasWon
    local currentGameGui = Template._currentGameGui

    --[[
        this is where you clear the game thread from StartGame()
        you can also play end cutscenes here, just yield as animations are playing
    ]]
end

function Template.DestroyGame()
    Template._janitor:Cleanup()
	Template._hasWon = false
	Template._currentGameGui = nil

    --[[
        this is where you 
            destroy the gui
            clean remaining/all connections
            reset values
    ]]
end

return Template
