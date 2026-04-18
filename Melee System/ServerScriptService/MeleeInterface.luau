--[[
    acts as interface for multiple modules + internal logic
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Signal = require(ReplicatedStorage.MODULES.GENERIC.Signal)
local Warden = require(ReplicatedStorage.MODULES.SPECIFIC.MorphSystem.Morphs.Warden)
local MeleeEnums = require(ReplicatedStorage.MeleeSystem.MeleeEnums)
local Hitbox = require(ServerScriptService.MeleeSystem.MeleeInit.MeleeInterface.Hitbox)
local Validation = require(ServerScriptService.MeleeSystem.MeleeInit.MeleeInterface.Validation)

local MeleeInterface = {}
MeleeInterface.toolDataList = {}:: {MeleeEnums.ToolData}

--[[
    config
]]
local ATTACK_BUFFER_DURATION = .25
local ATTACK_MOVEMENT_DURATION = .1

local function findAttackConfigFromOrder(configData: MeleeEnums.ConfigData, order: number)
    local attacksConfig = configData.Attacks

    for _, config in attacksConfig do
        if config.Order == order then
            return config
        end
    end

    return
end

local function incrementClampedAttackOrder(data: MeleeEnums.ToolData, incrementOrder: number)
    local state = data.State
	local orderSum = (state.CurrentAttackOrder + incrementOrder)

	if
		orderSum > state.MaxAttackOrder -- beyond max order
		or orderSum < 1 -- below min order
	then
		state.CurrentAttackOrder = 1 -- reset back to starting value (min order)
	else
		state.CurrentAttackOrder = orderSum
	end
end

local function getHitboxParts(tool: Tool): {BasePart}   
    local hitboxParts = {}

    for _, part in tool:GetDescendants() do
        if part:IsA("BasePart") then
            table.insert(hitboxParts, part)
        end
    end

    return hitboxParts
end

local function getAttackAnims(configData: {}, animator: Animator): {AnimationTrack}
    local attackAnims: {AnimationTrack} = {}

    for _, attackAction in configData.Attacks do
        local attackOrder = attackAction.Order
        local attackAnim = attackAction.Animation.Instance

        attackAnims[attackOrder] = animator:LoadAnimation(attackAnim)
    end

    return attackAnims
end

local function getOverlapParams(filterInstances: {Instance}): OverlapParams
    local overlapParams = OverlapParams.new()

	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = filterInstances

    return overlapParams
end

local function validateTool(player: Player, tool: Tool): boolean
    return Validation.ValidateToolInit(player, tool)
end

--[[
    some weapons have movement
]]
local function getAttackMovementConstraint(
    char: Model,
    attachment: Attachment
): LinearVelocity   
    local newConstraint = Instance.new("LinearVelocity")

    newConstraint.Parent = char
    newConstraint.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
    newConstraint.Attachment0 = attachment
    newConstraint.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    newConstraint.MaxAxesForce = Vector3.new(100000, 0, 100000)
    newConstraint.Enabled = false

    return newConstraint
end

local function applyAttackMovement(toolData: MeleeEnums.ToolData, movementVector: Vector3)
    local movementConstraint = toolData.MovementConstraint
    -- local HRP = toolData.HumanoidRootPart

    movementConstraint.VectorVelocity = movementVector

    movementConstraint.Enabled = true
    task.delay(ATTACK_MOVEMENT_DURATION, function()
        movementConstraint.Enabled = false
    end)
end

-- id assumed to also include "rbxassetid://"
local function newActionSound(id: number, parent: Instance): Sound
    local newSound = Instance.new("Sound")

    newSound.RollOffMode = Enum.RollOffMode.Linear
    newSound.RollOffMinDistance = 0
    newSound.RollOffMaxDistance = 20
    newSound.SoundId = id
    newSound.Parent = parent

    return newSound
end

--[[
    delay the initial attack request IF the server thinks the sword is still attacking
    as an attempt to compensate for ping
]]
local function handleAttackBuffer(state)
    local isAttacking: unknown = state.IsAttacking

    if isAttacking then
        local initialTime = os.clock()

        repeat 
            task.wait()
        until (os.clock() - initialTime) >= ATTACK_BUFFER_DURATION
    end
end

local function applyAttackAnimationsToList(
    configData,
    soundsList,
    HRP
)
    for configName, config in configData.Attacks do
        soundsList[configName] = {}

        local soundConfig = config.Sound

        for soundName, sound in soundConfig do
            soundsList[configName][soundName] = newActionSound(sound.SoundId, HRP)
        end
    end
end

function MeleeInterface.Init(player: Player, tool: Tool)
    -- validate tool init (avoids exploitation)
    if not validateTool(player, tool) then
        return
    end

    local char = player.Character
    local humanoid: Humanoid? = char:FindFirstChildWhichIsA("Humanoid")

    local HRP: BasePart = char:FindFirstChild("HumanoidRootPart")
    local HRPAttachment = HRP:FindFirstChildWhichIsA("Attachment")
    local movementConstraint = getAttackMovementConstraint(char, HRPAttachment)

    local animator: Animator = humanoid:FindFirstChildWhichIsA("Animator")

    local configModule = tool:FindFirstChild("Config")
    local configData: MeleeEnums.ConfigData = require(configModule)

    local attackAnims = getAttackAnims(configData, animator)

    local overlapParams = getOverlapParams({char})

    local hitboxParts = getHitboxParts(tool)

    -- sounds
    local soundsList = {
        Equip = newActionSound(configData.General.Equip.Sound.SoundId, HRP);
    }
    applyAttackAnimationsToList(configData, soundsList, HRP)

    MeleeInterface.toolDataList[tool] = {
        Player = player;
        Character = char;
        HumanoidRootPart = HRP;
        Humanoid = humanoid;
        Animator = animator;
        ConfigData = configData;

        -- attack
        OverlapParams = overlapParams;
        HitboxParts = hitboxParts;
        MovementConstraint = movementConstraint;
        AttackAnims = attackAnims;

        -- sounds
        SoundsList = soundsList;

        State = {
            IsAttacking = false; -- debounce

            -- attack orders
            CurrentAttackOrder = 1;
            MaxAttackOrder = #attackAnims;
        }
    }
end

local function handleAttack(
    currentSwingSound,
    currentAnim,
    tool,
    currentHitboxParts,
    currentDamage,
    currentOverlapParams,
    currentAttackType,
    soundsList,
    currentHitSound,
    postSwingMovement,
    toolData
)
    currentSwingSound:Play()
    currentAnim:Play()

    local didHitSignal, didUnequipSignal = Hitbox.CalculateHitbox(
        currentAnim, 
        tool,
        currentHitboxParts,
        currentDamage, 
        currentOverlapParams,
        currentAttackType,
        soundsList
    )

    didHitSignal:Connect(function() -- this will be automatically disconnected by Hitbox
        currentHitSound:Play()
    end)
    didUnequipSignal:Once(function()
        currentAnim:Stop() -- trigger stop anim 
    end)

    currentAnim.Ended:Once(function()
         if postSwingMovement then
            applyAttackMovement(toolData, postSwingMovement)
        end
    end)    
end

function MeleeInterface.Attack(tool: Tool)
    local toolData = MeleeInterface.toolDataList[tool]
    assert(toolData ~= nil, "Attack() failed: tool does not have tool data.")

    local state = toolData.State

    handleAttackBuffer(state) -- yields (acts as buffer incase still attacking)
    if state.IsAttacking then -- if still attacking even after buffer, reject attack
        return
    end

    local currentAttackOrder = toolData.State.CurrentAttackOrder
    local currentAnim = toolData.AttackAnims[currentAttackOrder]
    local currentOverlapParams = toolData.OverlapParams
    local currentHitboxParts = toolData.HitboxParts

    local currentConfigData = toolData.ConfigData
    local currentAttackType = currentConfigData.AttackType
    local currentActionConfig = findAttackConfigFromOrder(
        currentConfigData, currentAttackOrder
    )
    local currentDamage = currentActionConfig.Damage
    local currentCooldown = currentActionConfig.Cooldown

    local onSwingMovement = currentActionConfig.OnSwingMovement
    local postSwingMovement = currentActionConfig.PostSwingMovement

    local soundsList = toolData.SoundsList
    
    local currentSoundList = soundsList[currentAnim.Name]
    local currentSwingSound: Sound = currentSoundList.Swing
    local currentHitSound: Sound = currentSoundList.Hit

    state.IsAttacking = true

    incrementClampedAttackOrder(toolData, 1)

    if onSwingMovement then
        applyAttackMovement(toolData, onSwingMovement)
    end

    handleAttack(
        currentSwingSound,
        currentAnim,
        tool,
        currentHitboxParts,
        currentDamage,
        currentOverlapParams,
        currentAttackType,
        soundsList,
        currentHitSound,
        postSwingMovement,
        toolData
    )

    task.wait(currentCooldown) -- attack cooldown for specific tool

    state.IsAttacking = false
end

function MeleeInterface.PlaySound(tool: Tool, soundName: string)
    local toolData = MeleeInterface.toolDataList[tool]
    assert(toolData ~= nil, "PlaySound() failed: tool does not have tool data.")

    local sound = toolData.SoundsList[soundName]
    assert(sound ~= nil, "PlaySound() failed: tool does not have sound specified.")

    sound:Play()
end

return MeleeInterface
