local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.Config)
local Game = require(script.Parent.Game)
local Timer = require(script.Parent.Timer)

local Intermission = {}

local microgameHandler = script.Parent
local gui = microgameHandler.Parent

local controlFrame = gui.Control
local controlHint = controlFrame.Hint

local intermissionFrame = gui.Intermission

local sfxFolder = gui.SFX
local intermissionSounds = {
    transitionFail = sfxFolder.TransitionFail;
    transitionWin = sfxFolder.TransitionWin;
    transitionNormal = sfxFolder.TransitionNormal;
    transitionFaster = sfxFolder.TransitionFaster;
}
local voicelineSounds = {
	lose = {
		gui.Voiceline.LoseVoiceline1;
		gui.Voiceline.LoseVoiceline2;
        gui.Voiceline.LoseVoiceline3;
        gui.Voiceline.LoseVoiceline4;
	};
	win = {
		gui.Voiceline.WinVoiceline1;
		gui.Voiceline.WinVoiceline2;
        gui.Voiceline.WinVoiceline3;
	}
}

local randomGen = Random.new()

--[[
    local functions
]]

local function showControlHint(
    givenControlKey: string, 
    givenControlHintText: string, 
    delayBetweenKeyAndHint: number, 
    delayBeforeHintDisappear: number
)
	local givenControlKeyImage: ImageLabel = controlFrame:FindFirstChild(givenControlKey)
	
    if 
        not givenControlKeyImage
        or not givenControlHintText
        or not delayBetweenKeyAndHint
        or not delayBeforeHintDisappear
    then
        return
    end

    local ogKeySize = givenControlKeyImage.Size
    local ogHintSize = controlHint.Size
    
    -- in transition of control key
    givenControlKeyImage.Visible = true
    givenControlKeyImage.Size = UDim2.fromScale(ogKeySize.X.Scale * .5, ogKeySize.X.Scale * .5)
    TweenService:Create(givenControlKeyImage, TweenInfo.new(.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(ogKeySize.X.Scale, ogKeySize.Y.Scale)
    }):Play()
    
    task.wait(delayBetweenKeyAndHint)
    
    -- out transition of control key + gc
    local outTweenControlKey: Tween = TweenService:Create(givenControlKeyImage, TweenInfo.new(.25, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(0, 0)
    })
    outTweenControlKey:Play()
    outTweenControlKey.Completed:Once(function()
        givenControlKeyImage.Visible = false
        givenControlKeyImage.Size = ogKeySize
        outTweenControlKey = nil
    end)
    
    -- in transition of control hint
    controlHint.Text = givenControlHintText
    controlHint.Visible = true
    controlHint.Size = UDim2.fromScale(ogHintSize.X.Scale * .5, ogHintSize.Y.Scale * .5)
    TweenService:Create(controlHint, TweenInfo.new(.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(ogHintSize.X.Scale, ogHintSize.Y.Scale)
    }):Play()

    -- out transition of control hint
    task.spawn(function()
        task.wait(delayBeforeHintDisappear)
        TweenService:Create(controlHint, TweenInfo.new(.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Size = UDim2.fromScale(0, 0)
        }):Play()
        
        task.wait(.5)
        controlHint.Visible = false
        controlHint.Size = ogHintSize
    end)
end

--[[
    public functions
]]

function Intermission.StartIntro(microgame: Config.MicrogameModule)
    intermissionFrame.Visible = true

    intermissionSounds.transitionNormal:Play()
    task.spawn(function()
        showControlHint(
            microgame.CONTROL_HINT_KEY,
            microgame.CONTROL_HINT_TEXT,
            Config.DELAY_BETWEEN_KEY_AND_HINT,
            Timer.ConvertBPMToPerSecond(Game.CurrentBPM)
        )
    end)

    task.wait(intermissionSounds.transitionNormal.TimeLength)
    
	intermissionFrame.Visible = false
end

function Intermission.StartOutro(hasWon: boolean)
    if hasWon then
        local randomWinSound = voicelineSounds.win[randomGen:NextInteger(1, #voicelineSounds.win)]
        
        randomWinSound:Play()
        intermissionSounds.transitionWin:Play()
        
        intermissionSounds.transitionWin.Ended:Wait()
    else
        local randomLoseSound = voicelineSounds.lose[randomGen:NextInteger(1, #voicelineSounds.lose)]
   
        randomLoseSound:Play()

        intermissionSounds.transitionFail:Play()
        intermissionSounds.transitionFail.Ended:Wait()
    end
end

return Intermission
