local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeleeHandler = require(ReplicatedStorage.MeleeSystem.MeleeHandler)

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local currentTools = {}

local function handleMelee(tool: Tool)
	local melee = MeleeHandler.Init(tool)
	
	melee:Start()

	local toolDestroyedConn: RBXScriptConnection
	toolDestroyedConn = tool.AncestryChanged:Connect(function()
		-- if tool has been destroyed, clean up melee object
		if tool.Parent == nil then 
			melee:Destroy()
			toolDestroyedConn:Disconnect()
		end
	end)
end

local function attemptInitTool(tool: Tool)
	if 
		not tool:IsA("Tool") 
		or not tool:FindFirstChild("Config")
		or currentTools[tool] 
	then
		return
	end

	currentTools[tool] = true

	handleMelee(tool)
end

local function connectToolInitToChildren(parent: Instance)
	parent.ChildAdded:Connect(attemptInitTool)
	for _, tool in player.Backpack:GetChildren() do
		attemptInitTool(tool)
	end
end

-- attempt to listen for new tools added
connectToolInitToChildren(player.Backpack)
connectToolInitToChildren(char)
