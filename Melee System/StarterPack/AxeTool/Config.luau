--[[
	settings for melee
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeleeEnums = require(ReplicatedStorage.MeleeSystem.MeleeEnums)

local animationsFolder = script:WaitForChild("Animations")
local soundsFolder = script:WaitForChild("Sounds")

return {
	AttackType = MeleeEnums.attackTypesString.BaseAttack;
	
	-- general actions
	General = {
		Idle = {
			Animation = {
				Instance = animationsFolder.Idle;
				Priority = Enum.AnimationPriority.Movement;
				Looped = true;
			}
		};
		Aim = {
			Animation = {
				Instance = animationsFolder.Aim;
				Priority = Enum.AnimationPriority.Movement;
				Looped = true;
			}
		};
		Equip = {
			Sound = soundsFolder.Equip;
		};
	};
	
	-- attack actions
	Attacks = {
		HeavyAttack1 = {
			Animation = {
				Instance = animationsFolder.HeavyAttack1;
				Priority = Enum.AnimationPriority.Action;
			};
			Sound = {
				Swing = soundsFolder.Swing;
				Hit = soundsFolder.Hit;
			};

			Order = 1;
			Cooldown = 2;
			
			Damage = 28;
			SwingSpeed = 0.7;
			OnSwingMovement = Vector3.new(0, 0, -5);
		};
		HeavyAttack2 = {
			Animation = {
				Instance = animationsFolder.HeavyAttack2;
				Priority = Enum.AnimationPriority.Action;
			};
			Sound = {
				Swing = soundsFolder.Swing;
				Hit = soundsFolder.Hit;
			};

			Order = 2;
			Cooldown = 2;
			
			Damage = 32;
			SwingSpeed = 0.8;
			OnSwingMovement = Vector3.new(0, 0, -8);
		};
	};
}
