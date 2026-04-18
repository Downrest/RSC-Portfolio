--[[
	to validate an attempted attack (no hitboxes calculated yet):
		check if tool given requested for attack is truly equipped by player
		check if tool cooldown is valid, otherwise put in request buffer or eventually reject request
]]

local Validation = {}

local function getCharacterTools(char: Model): {Tool}
	local array = {}

	for _,tool in char:GetChildren() do
		if tool:IsA("Tool") then
			table.insert(array, tool)
		end
	end

	return array
end

--[[
	Validate MeleeInterface.Init() by checking:
		If tool is descendant of character (equipped)
		If tool is descendant of player (backpack)
		If there are no duplicate tools in the character (potential exploit trick)
]]
function Validation.ValidateToolInit(player: Player, tool: Tool): boolean
	local char = player.Character
	local currentToolsInCharacter = getCharacterTools(char)

	return not (
		not tool:IsDescendantOf(char)
		and not tool:IsDescendantOf(player)
		and #currentToolsInCharacter > 1
	)
end

return Validation
