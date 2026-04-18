local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Modules.Janitor)
local Signal = require(ReplicatedStorage.Modules.Signal)
local Config = require(script.Config)
local Game = require(script.Game)
local Intermission = require(script.Intermission)
local Timer = require(script.Timer)

local gui = script.Parent
local songsFolder = gui.Songs
local generatorRequest = ReplicatedStorage.RemoteEvents.GeneratorRequest

local timerGen = Timer.new()
Timer.SetBPM(timerGen, Config.DEFAULT_GAMEPLAY_BPM)

local gameOverJanitor = Janitor.new()
local gameOverSignal = Signal.new()

local function toggleGui(isEnabled: boolean)
    if isEnabled then
        gui.Enabled = true
    else
        gui.Enabled = false
    end
end

local function runMicrogameTimer(timerData: Config.TimerData, microgameModule: Config.MicrogameModule)
    local microgameSong: Sound = songsFolder:FindFirstChild(microgameModule.SONG_NAME)
    assert(microgameSong ~= nil, "NEEDS MICROGAMESONG")

    Timer.SetDuration(timerData, microgameSong.TimeLength)
    Timer.Start(timerData)
end

local function listenForGameOver(microgame: Config.MicrogameModule): boolean
    gameOverJanitor:Add(microgame.OnGameOver:Once(function()
        gameOverSignal:Fire(microgame.GetWinState())
    end), "Disconnect")

    gameOverJanitor:Add(timerGen.TimerEnded:Once(function()
        gameOverSignal:Fire(microgame.GetWinState())
    end), "Disconnect") 

    return gameOverSignal:Wait()
end

local function gameOverCleanup()
    gameOverJanitor:Cleanup()
    Timer.Stop(timerGen)
end

-- when the player triggers a generator (as seen by the server), start the microgames
generatorRequest.OnClientEvent:Connect(function(
    generatorModel: Model,
    MICROGAME_AMOUNT: number,
    MAX_LIVES: number
)
    local newGame = Game.new(MAX_LIVES)

    -- enable game gui
    toggleGui(true)

    -- cycle through all microgames
    while true do
        if 
            not Game.HasMicrogames(newGame) 
            or newGame.MicrogamesPlayed >= MICROGAME_AMOUNT
            or newGame.CurrentLives <= 0
        then
            break
        end

        -- choose random microgame + pop it from "current" microgame list
        local microgame = Game.PopRandom(newGame)
        
        -- intro intermission (pre-microgame hints)
        Intermission.StartIntro(microgame)

        -- run microgame + timer
		runMicrogameTimer(timerGen, microgame)
        microgame.StartGame()

        --[[
            yield until
                microgame reaches "game over" state
                microgame timer runs out
        ]]
        local hasWon: boolean = listenForGameOver(microgame)
        if not hasWon then 
            Game.RemoveLives(newGame, 1) -- if lost, remove 1 life
        end

        gameOverCleanup() -- cleans up all logic related to yielding game over state

        -- end microgame (yields; can also play end cutscenes)
        microgame.EndGame(hasWon)
        microgame.DestroyGame() -- destroys gui and all remaining connections after EndGame()

        -- outro intermission (win/lose visuals)
		Intermission.StartOutro(hasWon)
    end

    -- disable game gui (end of game)
    toggleGui(false)

    -- destroys game object to clear up memory
    Game.Destroy(newGame)
end)
