local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GuiCollisionService = require(ReplicatedStorage.Modules.GuiCollisionService)
local Janitor = require(ReplicatedStorage.Modules.Janitor)
local Signal = require(ReplicatedStorage.Modules.Signal)
local Config = require(StarterGui.Microgame.MicrogameHandler.Config)

local BlotweilerDrawing: Config.MicrogameModule = {}

--[[
    public variables
]]

BlotweilerDrawing.MICROGAME_NAME = "BlotweilerDrawing"
BlotweilerDrawing.CONTROL_HINT_KEY = Config.ControlKeys.Mouse
BlotweilerDrawing.CONTROL_HINT_TEXT = "DRAW"
BlotweilerDrawing.SONG_NAME = "BlotweilerDrawing"
BlotweilerDrawing.SONG_END_TIME_POSITION = 3

BlotweilerDrawing.OnGameOver = Signal.new()
BlotweilerDrawing.Started = Signal.new()

BlotweilerDrawing._janitor = Janitor.new()
BlotweilerDrawing._currentGameGui = nil
BlotweilerDrawing._hasWon = false

--[[
    internal (state) variables
]]

local randomGen = Random.new()

local originalSmeargleSize: UDim2
local originalSmearglePosition: UDim2
local originalEasleOutSize: UDim2
local originalEasleOutPosition: UDim2

local gameModule = script.Parent
local microgameHandler = gameModule.Parent
local gui = microgameHandler.Parent

local isPainting = false
local drawingAccuracy = 0

local taskNames = {
    ["GameThread"] = "GameThread";
    ["GameGui"] = "GameGui";

    ["BrushRenderStep"] = "BrushRenderStep";
    ["BrushInputBegan"] = "BrushInputBegan";
    ["BrushInputEnded"] = "BrushInputEnded";
    ["BrushPaintingTween"] = "BrushPaintingTween";
}

--[[
    config
]]

-- magic numbers (on scale) used for createdPaintHolder at the last part of the microgame
local OUT_PAINT_HOLDER_POSITION = UDim2.fromScale(.278, .778)
local OUT_PAINT_HOLDER_SIZE = UDim2.fromScale(.494, .557)

-- offset on where the brush is offset from the mouse
local BRUSH_OFFSET_X = -.05
local BRUSH_OFFSET_Y = -.07

-- for BindToRenderStep
local DRAWING_RENDER_STEP_PRIORITY = 0

-- minimum drawing accuracy before winning condition is reached
local MINIMUM_WIN_DRAWING_ACCURACY = 90 
--[[
    the bigger the number, the stronger effect that innacurate ink blobs
    (that didnt hit the doodle) have on decreasing drawing accuracy
]]
local INCORRECT_BLOBS_INACCURACY_WEIGHT = .5 

function BlotweilerDrawing.GetWinState(): boolean
    return BlotweilerDrawing._hasWon
end

local function startIdleSmeagleAnimation(
    start1Smeargle,
    start2Smeargle,

    iterations: number
)
    for _ = 1, iterations do
        start1Smeargle.Visible = not start1Smeargle.Visible
        start2Smeargle.Visible = not start2Smeargle.Visible
        task.wait(.333)
    end
end

local function outTransitionIntro(
    smeargleFrame,
    startBG,
    easleOut
)
    TweenService:Create(
        smeargleFrame,
        TweenInfo.new(.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
        {
            Size = UDim2.fromScale(
                smeargleFrame.Size.X.Scale * 1.2, 
                smeargleFrame.Size.Y.Scale * 1.2
            ),
            Position = UDim2.fromScale(
                smeargleFrame.Position.X.Scale * 1.2, 
                smeargleFrame.Position.Y.Scale * 1.05
            )
        }
    ):Play()
    TweenService:Create(
        startBG,
        TweenInfo.new(.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
        {
            Size = UDim2.fromScale(
                startBG.Size.X.Scale * 1.2, 
                startBG.Size.Y.Scale * 1.2
            ),
            Position = UDim2.fromScale(
                startBG.Position.X.Scale * 1.2, 
                startBG.Position.Y.Scale
            )
        }
    ):Play()
    TweenService:Create(
        easleOut,
        TweenInfo.new(.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
        {
            Size = UDim2.fromScale(
                easleOut.Size.X.Scale * 1.2, 
                easleOut.Size.Y.Scale * 1.2
            ),
            Position = UDim2.fromScale(
                easleOut.Position.X.Scale * 1.2, 
                easleOut.Position.Y.Scale * 1.05
            )
        }
    ):Play()
end

local function inTransitionGameplay(
    startBG,
    drawingBG,
    smeargleFrame,
    start1Smeargle,
    start2Smeargle,
    easleIn,
    easleOut,
    idlePaint,
    activePaint,
    inkBlobTemplate,
    brushCursor,

    randomPaintColor
)
    startBG.Visible = false
    smeargleFrame.Visible = false
    start1Smeargle.Visible = false
    start2Smeargle.Visible = false
    easleOut.Visible = false
    
    idlePaint.ImageColor3 = randomPaintColor
    activePaint.ImageColor3 = randomPaintColor
    inkBlobTemplate.BackgroundColor3 = randomPaintColor
    brushCursor.Visible = true
    
    easleIn.Visible = true
    drawingBG.Visible = true
    easleIn.Size = UDim2.fromScale(
        easleIn.Size.X.Scale * .9, 
        easleIn.Size.Y.Scale * .9
    )
    TweenService:Create(
        easleIn,
        TweenInfo.new(.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {
            Size = UDim2.fromScale(
                easleIn.Size.X.Scale * 1.1, 
                easleIn.Size.Y.Scale * 1.1
            ),
        }
    ):Play()
    TweenService:Create(
        drawingBG,
        TweenInfo.new(.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {
            Size = UDim2.fromScale(
                startBG.Size.X.Scale * 1.1, 
                startBG.Size.Y.Scale * 1.1
            )
        }
    ):Play()
end

local function alignBrushCursorToMouse(
    brushCursor, 
    mouseLocation
)
    brushCursor.Position = UDim2.new(
        BRUSH_OFFSET_X, 
        mouseLocation.X,
        BRUSH_OFFSET_Y,
        mouseLocation.Y
    )
end

local function createInkBlobOnMouse(
    inkBlobTemplate,
    createdPaintHolder,
    mouseLocation
): Frame
    local newInkBlob = inkBlobTemplate:Clone()
    newInkBlob.Visible = true
    newInkBlob.Parent = createdPaintHolder
    newInkBlob.Position = UDim2.new(
        0, 
        mouseLocation.X,
        0,
        mouseLocation.Y
    )

    return newInkBlob
end

local function updateDrawingAccuracy(
    collidedHitboxes,
    totalHitboxAmount,
    incorrectInkBlobs
)
    if drawingAccuracy < MINIMUM_WIN_DRAWING_ACCURACY then
        drawingAccuracy = (((#collidedHitboxes + 1) / (totalHitboxAmount + 1)) * 100) - (incorrectInkBlobs * INCORRECT_BLOBS_INACCURACY_WEIGHT)

    elseif 
        drawingAccuracy >= MINIMUM_WIN_DRAWING_ACCURACY
        and not BlotweilerDrawing._hasWon
    then
        BlotweilerDrawing._hasWon = true
    end
end

local function setupPaintOnRenderStep(
    randomDoodle,
    brushCursor,
    inkBlobTemplate,
    topLeftInset,
    paintDrawbox,
    previousMouseLocation,
    createdPaintHolder
)
    local totalHitboxes: {Frame} = randomDoodle:GetChildren()
    local totalHitboxAmount = #totalHitboxes
    local collidedHitboxes: {Frame} = {}
    local incorrectInkBlobs = 0
    
    RunService:BindToRenderStep(taskNames.BrushRenderStep, DRAWING_RENDER_STEP_PRIORITY, function()
        local mouseLocation = UserInputService:GetMouseLocation()
        alignBrushCursorToMouse(brushCursor, mouseLocation)

        -- if isPainting and avoid duplicates if mouse not moving
        local isWithinDrawingHitbox = GuiCollisionService.isInCore(
            {
                AbsoluteSize = inkBlobTemplate.AbsoluteSize,
                AbsolutePosition = Vector2.new(
                    mouseLocation.X,
                    mouseLocation.Y - topLeftInset.Y
                ),
            }, 
            paintDrawbox
        )

        if 
            isPainting 
            and mouseLocation ~= previousMouseLocation 
            and isWithinDrawingHitbox
        then
            local inkBlob = createInkBlobOnMouse(
                inkBlobTemplate,
                createdPaintHolder,
                mouseLocation
            )

            if not BlotweilerDrawing._hasWon then
                local hasCollided = false
                for _, hitboxFrame in totalHitboxes do
                    if GuiCollisionService.isColliding(hitboxFrame, inkBlob) then
                        hasCollided = true

                        if not table.find(collidedHitboxes, hitboxFrame) then
                            table.insert(collidedHitboxes, hitboxFrame)
                            break
                        end
                    end
                end

                if not hasCollided then
                    incorrectInkBlobs += 1
                end
            end
        end

        previousMouseLocation = mouseLocation

        updateDrawingAccuracy(collidedHitboxes, totalHitboxAmount, incorrectInkBlobs)
    end)
end

local function startPaintingOnInputStart(
    isTyping,
    input,
    idleBrush,
    idlePaint,
    activeBrush,
    activePaint,
    brushCursorTween
)
    if isTyping then
        return
    end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        idleBrush.Visible = false
        idlePaint.Visible = false
        activeBrush.Visible = true
        activePaint.Visible = true

        isPainting = true

        brushCursorTween:Play()
    end
end

local function stopPaintingOnInputEnd(
    isTyping,
    input,
    idleBrush,
    idlePaint,
    activeBrush,
    activePaint,
    brushCursorTween
)
    if isTyping then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        idleBrush.Visible = true
        idlePaint.Visible = true
        activeBrush.Visible = false
        activePaint.Visible = false
        
        isPainting = false
        brushCursorTween:Cancel()
    end
end

function BlotweilerDrawing.StartGame()
    local janitor = BlotweilerDrawing._janitor
	local currentGameGui
	
    janitor:Add(task.spawn(function()
        currentGameGui = janitor:Add(
            script.BlotweilerDrawing:Clone(), 
            nil,
            taskNames.GameGui
		)
		BlotweilerDrawing._currentGameGui = currentGameGui
		
		currentGameGui.Visible = true
		currentGameGui.Parent = gui

        local bgFolder: Folder = currentGameGui.BG
        local startBG: ImageLabel = bgFolder.StartBG
        local drawingBG: ImageLabel = bgFolder.DrawingBG
        
        local brushCursor: Frame = currentGameGui.BrushCursor
        local idleBrush: ImageLabel = brushCursor.IdleBrush
        local idlePaint: ImageLabel = brushCursor.IdlePaint
        local activeBrush: ImageLabel = brushCursor.ActiveBrush
        local activePaint: ImageLabel = brushCursor.ActivePaint
        
        local smeargleFrame: Frame = currentGameGui.Smeargle
        local start1Smeargle: ImageLabel = smeargleFrame.Start1
        local start2Smeargle: ImageLabel = smeargleFrame.Start2
        
        local easleIn: ImageLabel = currentGameGui.EasleIn
        local easleOut: ImageLabel = currentGameGui.EasleOut
		
		local paintDrawbox: Frame = easleIn.Drawbox -- you can only draw within this hitbox
        local createdPaintHolder: Frame = currentGameGui.CreatedPaintHolder
        local inkBlobTemplate: Frame = currentGameGui.InkBlobTemplate

        local doodlesEasleOut: {ImageLabel} = {
            easleOut.EeveeDoodle;
            easleOut.SpoinkDoodle;
            easleOut.SudoDoodle;
        }
        local randomDoodleEasleOut = doodlesEasleOut[randomGen:NextInteger(1, #doodlesEasleOut)]
        randomDoodleEasleOut.Visible = true
   
        -- this will be the color of the brush + paint strokes
        local randomPaintColor = Color3.fromRGB(
            randomGen:NextInteger(0, 255),
            randomGen:NextInteger(0, 255),
            randomGen:NextInteger(0, 255)
        )

        originalSmeargleSize = smeargleFrame.Size
        originalSmearglePosition = smeargleFrame.Position
        originalEasleOutSize = easleOut.Size
        originalEasleOutPosition = easleOut.Position
    
        -- intro cutscene
        task.spawn(function()
            startIdleSmeagleAnimation(start1Smeargle, start2Smeargle, 6)            
        end)

        -- out transition of intro
        task.spawn(function()
            task.wait(1.75)
            
            outTransitionIntro(
                smeargleFrame,
                startBG,
                easleOut
            )
        end)
        task.wait(2) -- yield before in transition

        -- in transition of gameplay
        inTransitionGameplay(
            startBG,
            drawingBG,
            smeargleFrame,
            start1Smeargle,
            start2Smeargle,
            easleIn,
            easleOut,
            idlePaint,
            activePaint,
            inkBlobTemplate,
            brushCursor,
            randomPaintColor
        )

        -- gameplay code itself
        local brushCursorTween: Tween = BlotweilerDrawing._janitor:Add(
            TweenService:Create(
                brushCursor,
                TweenInfo.new(.25, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut, -1, true),
                {
                    Rotation = -10
                }
            ),

            "Cancel", taskNames.BrushPaintingTween
        )

        local previousMouseLocation = UserInputService:GetMouseLocation()
        local topLeftInset, _ = GuiService:GetGuiInset()

        --[[
            this section implements
                brush cursor 
                drawing mechanic on cursor position
                drawing accuracy depending on doodle
        ]]
        local randomDoodleEasleIn: ImageLabel = easleIn:FindFirstChild(randomDoodleEasleOut.Name)
        randomDoodleEasleIn.Visible = true

		setupPaintOnRenderStep(
            randomDoodleEasleIn,
                brushCursor,
                inkBlobTemplate,
                topLeftInset,
                paintDrawbox,
                previousMouseLocation,
                createdPaintHolder
            )
        
        --[[
            acknowledges input start for painting (start painting)
        ]]
        janitor:Add(UserInputService.InputBegan:Connect(function(input, isTyping)
            startPaintingOnInputStart(
                isTyping,
                input,
                idleBrush,
                idlePaint,
                activeBrush,
                activePaint,
                brushCursorTween
            )
        end), nil, taskNames.BrushInputBegan)

        --[[
            acknowledges input end for painting (stop painting)
        ]]
        janitor:Add(UserInputService.InputEnded:Connect(function(input, isTyping)
            stopPaintingOnInputEnd(
                isTyping,
                input,
                idleBrush,
                idlePaint,
                activeBrush,
                activePaint,
                brushCursorTween
            )
        end), nil, taskNames.BrushInputEnded)
    end), nil, taskNames.GameThread)
end

local function updateDrawingsToOutTransition(createdPaintHolder)
    for _,blob: Frame in createdPaintHolder:GetChildren() do
		blob.Position = UDim2.new(
			blob.Position.X.Offset / createdPaintHolder.AbsoluteSize.X,
			0, 
			blob.Position.Y.Offset / createdPaintHolder.AbsoluteSize.Y,
			0
		)
	end
end

local function outTransitionGameplay(
    easleIn,
    drawingBG,
    startBG,
    endBG,
    createdPaintHolder
)
	TweenService:Create(
		easleIn,
		TweenInfo.new(.15, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
		{
			Size = UDim2.fromScale(
				easleIn.Size.X.Scale * .8, 
				easleIn.Size.Y.Scale * .8
			),
		}
	):Play()
	TweenService:Create(
		drawingBG,
		TweenInfo.new(.15, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
		{
			Size = UDim2.fromScale(
				startBG.Size.X.Scale * .8, 
				startBG.Size.Y.Scale * .8
			)
		}
	):Play()
	TweenService:Create(
		createdPaintHolder,
		TweenInfo.new(.15, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
		{
			Size = UDim2.fromScale(
				createdPaintHolder.Size.X.Scale * .8, 
				createdPaintHolder.Size.Y.Scale * .8
			)
		}
	):Play()
	endBG.Size = UDim2.fromScale(
		endBG.Size.X.Scale * 1.2, 
		endBG.Size.Y.Scale * 1.2
	)
	endBG.Position = UDim2.fromScale(
		endBG.Position.X.Scale * 1.2, 
		endBG.Position.Y.Scale
	)
end

local function inTransitionOutro(
    easleIn,
    drawingBG,
    easleOut,
    endBG,
    smeargleFrame,
    end1Smeargle,
    createdPaintHolder,
    activeBrush,
    activePaint,
    idleBrush
)
    easleIn.Visible = false
	drawingBG.Visible = false

	easleOut.Visible = true
	endBG.Visible = true
	smeargleFrame.Visible = true
	end1Smeargle.Visible = true

    --[[
        magic numbers for the exact scale position and size
        of createdPaintHolder (where ink blobs are created)
        to fit with smaller easle
    ]]
	createdPaintHolder.Size = UDim2.fromScale(
		OUT_PAINT_HOLDER_SIZE.X.Scale * 1.2, 
		OUT_PAINT_HOLDER_SIZE.Y.Scale * 1.2
	)
	createdPaintHolder.Position = UDim2.fromScale(
		OUT_PAINT_HOLDER_POSITION.X.Scale * 1.2, 
		OUT_PAINT_HOLDER_POSITION.Y.Scale
	)

	activeBrush.Visible = false
	activePaint.Visible = false
	idleBrush.Visible = true
	idleBrush.Visible = true

	TweenService:Create(
		endBG,
		TweenInfo.new(.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{
			Size = UDim2.fromScale(1.01, 1.01),
			Position = UDim2.fromScale(.5, .5)
		}
	):Play()
	TweenService:Create(
		createdPaintHolder,
		TweenInfo.new(.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{
			Size = OUT_PAINT_HOLDER_SIZE,
			Position = OUT_PAINT_HOLDER_POSITION
		}
	):Play()
	TweenService:Create(
		easleOut,
		TweenInfo.new(.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{
			Size = originalEasleOutSize,
			Position = originalEasleOutPosition
		}
	):Play()
	TweenService:Create(
		smeargleFrame,
		TweenInfo.new(.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{
			Size = originalSmeargleSize,
			Position = originalSmearglePosition
		}
	):Play()
end

local function endIdleSmeagleAnimation(end1Smeargle, end2Smeargle)
    for _ = 1, 6 do
		end1Smeargle.Visible = not end1Smeargle.Visible
		end2Smeargle.Visible = not end2Smeargle.Visible
		task.wait(.333)
	end
end

function BlotweilerDrawing.EndGame(forceWinState: boolean)
    local winState = forceWinState or BlotweilerDrawing._hasWon
    local currentGameGui = BlotweilerDrawing._currentGameGui

    local bgFolder: Folder = currentGameGui.BG
    local startBG: ImageLabel = bgFolder.StartBG
    local drawingBG: ImageLabel = bgFolder.DrawingBG
    local endBG: ImageLabel = bgFolder.EndBG
    
    local brushCursor: Frame = currentGameGui.BrushCursor
    local idleBrush: ImageLabel = brushCursor.IdleBrush
    local activeBrush: ImageLabel = brushCursor.ActiveBrush
    local activePaint: ImageLabel = brushCursor.ActivePaint
    
    local smeargleFrame: Frame = currentGameGui.Smeargle
    local end1Smeargle: ImageLabel = smeargleFrame:WaitForChild("End1")
    local end2Smeargle: ImageLabel = smeargleFrame:WaitForChild("End2")
    
    local easleIn: ImageLabel = currentGameGui.EasleIn
    local easleOut: ImageLabel = currentGameGui.EasleOut
    
    local createdPaintHolder: Frame = currentGameGui.CreatedPaintHolder

    -- clean out previous connections (except for brushrenderstep)
    BlotweilerDrawing._janitor:RemoveList(
        taskNames.GameThread,
        taskNames.BrushInputBegan,
        taskNames.BrushInputEnded,
        taskNames.BrushPaintingTween
    )
    isPainting = false

    -- size down drawings to match with out transition (EasleOut)
	updateDrawingsToOutTransition(createdPaintHolder)

	-- out transition of gameplay
	outTransitionGameplay(
        easleIn,
        drawingBG,
        startBG,
        endBG,
        createdPaintHolder
    )
	task.wait(.15) -- yield before in transition

	-- in transition + outro cutscene
	inTransitionOutro(
        easleIn,
        drawingBG,
        easleOut,
        endBG,
        smeargleFrame,
        end1Smeargle,
        createdPaintHolder,
        activeBrush,
        activePaint,
        idleBrush
    )

    -- this acts as the yield for the entire end cutscene
	endIdleSmeagleAnimation(end1Smeargle, end2Smeargle)

    RunService:UnbindFromRenderStep(taskNames.BrushRenderStep)
end

function BlotweilerDrawing.DestroyGame()
	BlotweilerDrawing._janitor:Cleanup()
	BlotweilerDrawing._hasWon = false
	BlotweilerDrawing._currentGameGui = nil
	
	isPainting = false
	drawingAccuracy = 0
end

return BlotweilerDrawing
