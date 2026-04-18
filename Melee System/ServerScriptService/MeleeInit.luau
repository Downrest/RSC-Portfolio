--[[
	handles server logic of melee
		attack (swing animation, hitbox validation, damage) + anti-exploit measures

	for client logic, check MeleeHandler
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MeleeInterface = require(ServerScriptService.MeleeSystem.MeleeInit.MeleeInterface)

local meleeSystemFolder = ReplicatedStorage.MeleeSystem
local attackMeleeEvent = meleeSystemFolder.Remotes.AttackMelee
local initiateMeleeEvent = meleeSystemFolder.Remotes.InitiateMelee
local playMeleeSoundEvent: RemoteEvent = meleeSystemFolder.Remotes.PlayMeleeSound

initiateMeleeEvent.OnServerEvent:Connect(function(player, tool: Tool)
	MeleeInterface.Init(player, tool)
end)

attackMeleeEvent.OnServerInvoke = function(_, tool: Tool)
	MeleeInterface.Attack(tool)	
end

playMeleeSoundEvent.OnServerEvent:Connect(function(_, tool: Tool, soundName: string)
	MeleeInterface.PlaySound(tool, soundName)
end)
