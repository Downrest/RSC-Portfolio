--[[
    hitbox designed to work with attack animations and their respective KeyframeMarkers
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")

local Janitor = require(ReplicatedStorage.MODULES.GENERIC.Janitor)
local Signal = require(ReplicatedStorage.MODULES.GENERIC.Signal)

local Hitbox = {}
Hitbox.attackTypes = {
	BaseAttack = require(ServerScriptService.MeleeSystem.MeleeInit.MeleeInterface.Hitbox.AttackTypes.BaseAttack);
}

--[[
    config
]]
local HITBOX_CALCULATION_RATE = .0075

function Hitbox.CalculateHitbox(
	attackAnimation: AnimationTrack, 
	tool: Tool, 
	hitboxParts: {BasePart}, 
	damage: number, 
	overlapParams: OverlapParams, 
	attackType: string
): (Signal.Signal<>, Signal.Signal<>)
	
	local humDamaged: {Humanoid} = {}

	local janitor = Janitor.new()
	local didHitSignal = janitor:Add(Signal.new())
	local didUnequipSignal = janitor:Add(Signal.new())

	local attackTypeFunction: () -> ()
	attackTypeFunction = Hitbox.attackTypes[attackType]

	if not attackTypeFunction then
		return
	end

	attackAnimation:GetMarkerReachedSignal("StartHitbox"):Once(function()
		janitor:Add(task.spawn(function()
			while true do
				for _, hitboxPart: BasePart in hitboxParts do
					local collidedParts = workspace:GetPartBoundsInBox(
						hitboxPart.CFrame,
						hitboxPart.Size,
						overlapParams
					)

					for _, part in collidedParts do
						local char = part:FindFirstAncestorWhichIsA("Model")
						local humanoid: Humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
						
						if not humanoid then
							continue
						end

						if not table.find(humDamaged, humanoid) then
							didHitSignal:Fire()
							attackTypeFunction(humanoid, damage)
							table.insert(humDamaged, humanoid)
						end
					end
				end

				task.wait(HITBOX_CALCULATION_RATE)
			end
		end))
	end)
	attackAnimation:GetMarkerReachedSignal("EndHitbox"):Once(function()
		janitor:Cleanup()
	end)
	janitor:Add(tool.Unequipped:Once(function()
		didUnequipSignal:Fire()
		janitor:Cleanup()
	end))

	return didHitSignal, didUnequipSignal
end

return Hitbox
