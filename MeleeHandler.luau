--[[
	handles client logic of melee
		aiming
		movement 
		shoulder camera (switching shoulder offsets)
		animations (except for attack/swing)

	for server logic, check MeleeInit
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Janitor = require(ReplicatedStorage.MODULES.GENERIC.Janitor)
local MeleeEnums = require(ReplicatedStorage.MeleeSystem.MeleeEnums)

assert(
	RunService:IsClient(),
	"You can only require this module on the client, the hitbox validation code is handled by a server Script"
)

local MeleeHandler = {}
MeleeHandler.__index = MeleeHandler

--[[
	internal variables
]]

local remotesFolder = script.Parent.Remotes
MeleeHandler.remotes = {
	InitiateMelee = remotesFolder.InitiateMelee;
	AttackMelee = remotesFolder.AttackMelee;
	PlayMeleeSound = remotesFolder.PlayMeleeSound;
}

local taskNames = {
	["MeleeEquip"] = "MeleeEquip";
	["MeleeUnequip"] = "MeleeUnequip";
	["MeleeInputBegan"] = "MeleeInputBegan";
	["MeleeInputEnded"] = "MeleeInputEnded";

	["ShoulderCameraUpdate"] = "ShoulderCameraUpdate";
	["AimTorsoToCameraUpdate"] = "AimTorsoToCameraUpdate";
}

--[[
	config
]]
local KEY_TO_SHOULDER_TYPE = {
	[Enum.KeyCode.E] = 1;
	[Enum.KeyCode.Q] = -1;
}
local DEFAULT_SHOULDER_TYPE = 1

--[[
    helper functions
]]

local function applyAnimConfigToAnimation(animInstance: Animation, animConfig: {})
	for propertyName: string, propertyValue: any in animConfig do
		pcall(function()
			animInstance[propertyName] = propertyValue
		end)
	end
end

local function applyAttackActionsToAnimTable(self: MeleeHandler)
	for _, action: {} in self.attackActions do
		local loadedAnim = self.animator:LoadAnimation(action.Animation.Instance)

		self.attackAnimsInOrder[action.Order] = loadedAnim
		loadedAnim.Looped = false
		applyAnimConfigToAnimation(loadedAnim, action.Animation)
	end
end

local function isFirstPerson(self: MeleeHandler)
	return self.gunHandlerScript:GetAttribute("FirstPerson")
end

--[[
    internal functions
]]

--[[
    client handles animations and its own cooldown system (for UX)
    however, server handles hitbox validation
    
    to compensate for ping, each hit request will be put in a buffer
]]
local function attack(self: MeleeHandler)
	self.isAttacking = true

	-- sound is already handled on the server (alongside hitbox), so no need for PlayMeleeSound:FireServer()
	repeat
		MeleeHandler.remotes.AttackMelee:InvokeServer(self.tool)
	until not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	
	self.isAttacking = false
end

local function shoulderCameraUpdate(self: MeleeHandler): RBXScriptSignal
	return self.shoulderSide.Changed:Connect(function()
		if isFirstPerson(self) then
			return
		end

		-- reset shoulder camera
		if self.shoulderSide.Value == 0 then
			self.playerCameraModule:SetOffset(Vector3.zero)

		else
			local offsetX = self.shoulderSide.Value == 1 and self.shoulderCameraOffset.X or -self.shoulderCameraOffset.X

			self.playerCameraModule:SetOffset(Vector3.new(offsetX, 0, 0))
		end
	end)
end

local function aimTorsoToCameraUpdate(self: MeleeHandler): RBXScriptSignal
	return RunService.RenderStepped:Connect(function(deltaTime)
		local deltaRatio = deltaTime / (1 / 60)

		-- apparently u need to set this every step to take effect
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

		-- smoothly orient the character towards camera direction
		local cameraCFrame = self.camera.CFrame
		local cameraLookVector = cameraCFrame.LookVector
		local targetCFrame = CFrame.lookAt(self.HRP.Position, self.HRP.Position + Vector3.new(cameraLookVector.X, 0, cameraLookVector.Z))
		self.HRP.CFrame = self.HRP.CFrame:Lerp(targetCFrame, 0.3 * deltaRatio) -- affected by deltaTime
	end)
end

local function stopAnimations(self: MeleeHandler)
	for _, anim: AnimationTrack in self.generalAnims do
		anim:Stop()
	end
	for _, anim: AnimationTrack in self.attackAnimsInOrder do
		anim:Stop()
	end
end

local function tweenCrosshair(self: MeleeHandler, isEnabled: boolean)
	if isEnabled then
		TweenService:Create(self.meleeCrosshair, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
			ImageTransparency = 0
		}):Play()
		TweenService:Create(self.meleeCrosshair, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			Size = UDim2.fromOffset(
				self.camera.ViewportSize.Y * self.crosshairSizeToScreenRatio,
				self.camera.ViewportSize.Y * self.crosshairSizeToScreenRatio
			),
		}):Play()
	else
		TweenService:Create(self.meleeCrosshair, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
			ImageTransparency = 1
		}):Play()
		TweenService:Create(self.meleeCrosshair, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			Size = UDim2.fromScale(0, 0)
		}):Play()
	end
end

local function toggleGUICrosshair(self: MeleeHandler, isEnabled: boolean)
	UserInputService.MouseIconEnabled = not isEnabled
	tweenCrosshair(self, isEnabled)
end

local function toggleCameraZoom(self: MeleeHandler, isZooming: boolean)
	if isZooming then
		self.playerCameraModule:SetFOV(50, 12, 0.9)
		self.playerCameraModule:MaxAndMin(2, 8, 7)
	else
		self.playerCameraModule:SetFOV(70, 14, 1)
		self.playerCameraModule:MaxAndMin(4, 12, 7)
	end
end

local function toggleAim(self: MeleeHandler, isAiming: boolean)
	local janitor = self.janitor

	if isAiming then
		self.generalAnims.Aim:Play()

		-- custom camera module for zoom
		toggleCameraZoom(self, true)

		-- third person, allow shoulder view
		janitor:Add(aimTorsoToCameraUpdate(self), nil, taskNames.AimTorsoToCameraUpdate)	

		-- crosshair tween + position update
		UserInputService.MouseIconEnabled = false
		toggleGUICrosshair(self, true)

		-- "set aiming attribute" no idea what this does tho
		self.gunHandlerScript:SetAttribute("Aiming", true)
	else
		janitor:Remove(taskNames.AimTorsoToCameraUpdate)

		self.generalAnims.Aim:Stop()

		toggleGUICrosshair(self, false)
		toggleCameraZoom(self, false)

		self.gunHandlerScript:SetAttribute("Aiming", false)

		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

-- to see the shoulder code, check shoulderCameraUpdate()
local function setShoulderSide(self: MeleeHandler, shoulderType: number)
	self.shoulderSide.Value = shoulderType or 0
end

local function equip(self: MeleeHandler)
	-- idle
	self.generalAnims.Idle:Play()

	setShoulderSide(self, DEFAULT_SHOULDER_TYPE) -- right-side shoulder camera
	MeleeHandler.remotes.PlayMeleeSound:FireServer(self.tool, MeleeEnums.meleeSounds.Equip)

	self.isEquipped = true
end

local function unequip(self: MeleeHandler)
	stopAnimations(self)

	UserInputService.MouseIconEnabled = true

	setShoulderSide(self, false)

	toggleAim(self, false)
	toggleCameraZoom(self, false)
	toggleGUICrosshair(self, false)

	self.gunHandlerScript:SetAttribute("Aiming", false)
	self.isEquipped = false
end
--[[
    public functions
]]

--[[
    Setups variables for melee object
]]
function MeleeHandler.Init(tool: Tool): MeleeHandler
	local self: MeleeHandler = setmetatable({}, MeleeHandler)

	-- config
	self.shoulderCameraOffset = Vector2.new(2.045, 0.082)
	self.crosshairSizeToScreenRatio = 0.02

	self.tool = tool

	self.player = Players.LocalPlayer
	self.char = self.player.Character or self.player.CharacterAdded:Wait()
	self.HRP = self.char:WaitForChild("HumanoidRootPart")
	self.humanoid = self.char:WaitForChild("Humanoid")
	self.animator = self.humanoid:WaitForChild("Animator")
	self.camera = workspace.CurrentCamera
	self.mouse = self.player:GetMouse()

	-- assets
	self.configModule = require(tool:WaitForChild("Config"))
	self.runFrameworkScript = self.player.PlayerScripts:WaitForChild("RunFramework")
	self.playerClassFolder = self.runFrameworkScript:WaitForChild("PlayerClass")
	self.playerCameraModule = require(self.playerClassFolder:WaitForChild("PlayerCamera"))

	self.gunHandlerScript = self.playerClassFolder:WaitForChild("GunHandler") -- dont require

	self.meleeGui = self.player.PlayerGui:WaitForChild("GunGui")
	self.meleeCrosshair = self.meleeGui:WaitForChild("Crosshair")
	self.meleeHitmarker = self.meleeGui:WaitForChild("Hitmarker")

	-- actions
	self.generalActions = self.configModule.General
	self.generalAnims = {
		Idle = self.animator:LoadAnimation(self.generalActions.Idle.Animation.Instance),
		Aim = self.animator:LoadAnimation(self.generalActions.Aim.Animation.Instance),
	}
	for _, anim in self.generalAnims do
		applyAnimConfigToAnimation(anim, self.generalActions[anim.Name].Animation)
	end

	self.attackActions = self.configModule.Attacks
	self.attackAnimsInOrder = {}
	applyAttackActionsToAnimTable(self)

	MeleeHandler.remotes.InitiateMelee:FireServer(self.tool)

	self.currentAttackOrder = Instance.new("IntValue")
	self.currentAttackOrder.Value = 1 -- default
	self.attackOrderMin = 1
	self.attackOrderMax = #self.attackAnimsInOrder

	-- states
	self.isEquipped = false
	self.isAttacking = false
	self.shoulderSide = Instance.new("IntValue")

	self.janitor = Janitor.new()

	return self
end

--[[
    Runs melee code, should be ran after MeleeHandler:Init()
]]
function MeleeHandler.Start(self: MeleeHandler)
	local janitor = self.janitor

	janitor:Add(shoulderCameraUpdate(self), nil, taskNames.ShoulderCameraUpdate)

	janitor:Add(self.tool.Equipped:Connect(function()
		equip(self)
	end), nil, taskNames.MeleeEquip)

	janitor:Add(self.tool.Unequipped:Connect(function()
		unequip(self)
	end), nil, taskNames.MeleeUnequip)

	janitor:Add(UserInputService.InputBegan:Connect(function(input, isTyping)
		if isTyping or not self.isEquipped then
			return
		end

		-- attack
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not self.isAttacking then
			attack(self)

		-- shoulder switching camera
		elseif KEY_TO_SHOULDER_TYPE[input.KeyCode] and not isFirstPerson(self) then
			setShoulderSide(self, KEY_TO_SHOULDER_TYPE[input.KeyCode])

		-- starting aim
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			toggleAim(self, true)
		end
	end), nil, taskNames.MeleeInputBegan)
	
	janitor:Add(UserInputService.InputEnded:Connect(function(input, isTyping)
		if isTyping or not self.isEquipped then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			toggleAim(self, false)
		end
	end), nil, taskNames.MeleeInputEnded)
end

function MeleeHandler.Destroy(self: MeleeHandler)
	stopAnimations(self)

	setShoulderSide(self, false)
	toggleAim(self, false)
	toggleCameraZoom(self, false)
	toggleGUICrosshair(self, false)

	self.janitor:Destroy()
	self = nil
end

-- export module + self
export type MeleeHandler = typeof(MeleeHandler) & {
	shoulderCameraOffset: Vector2;
	crosshairSizeToScreenRatio: number;

	tool: Tool;

	player: Player;
	char: Model;
	HRP: BasePart;
	humanoid: Humanoid;
	animator: Animator;
	camera: Camera;
	mouse: Mouse;

	configModule: {};
	runFrameworkScript: Script;
	playerClassFolder: Folder;
	playerCameraModule: {};
	gunHandlerScript: Script;
	meleeGui: ScreenGui;
	meleeCrosshair: ImageLabel;
	meleeHitmarker: ImageLabel;

	isEquipped: boolean;
	isAttacking: boolean;
	shoulderSide: IntValue;

	generalActions: {};
	generalAnims: {
		["Idle"]: AnimationTrack;
		["Aim"]: AnimationTrack;
	};
	attackActions: {};
	attackAnimsInOrder: {
		[number]: AnimationTrack;
	};
	currentAttackOrder: IntValue;
	attackOrderMin: number;
	attackOrderMax: number;

	janitor: Janitor.Janitor;
}

return MeleeHandler :: MeleeHandler
