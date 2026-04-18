local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Modules.Janitor)
local Signal = require(ReplicatedStorage.Modules.Signal)
local Config = {}

--[[
	config
]]

Config.DEFAULT_GAMEPLAY_BPM = 120

Config.DELAY_BETWEEN_KEY_AND_HINT = 1

--[[
	public types & enum tables
]]

Config.ControlKeys = {
	["AnalogStick"] = "AnalogStick";
	["ArrowKey"] = "ArrowKey";
	["ArrowKeySpace"] = "ArrowKeySpace";
	["Buttons"] = "Buttons";
	["Keyboard"] = "Keyboard";
	["Mouse"] = "Mouse";
	["Nothing"] = "Nothing";
	["Space"] = "Space";
	["Tap"] = "Tap";
}
	
-- Game.luau

export type GameData = {
	CurrentMicrogames: {MicrogameModule};
	MicrogamesPlayed: number;

	CurrentLives: number;

	_janitor: Janitor.Janitor;
}

export type MicrogameNames = "BlotweilerDrawing";	
Config.MicrogameNames = {
	["BlotweilerDrawing"] = "BlotweilerDrawing";
}
export type MicrogameList = {
	[MicrogameNames]: MicrogameModule
}

export type MicrogameModule = {
	GetWinState: () -> (boolean);
	StartGame: () -> ();
	EndGame: (boolean) -> ();
	DestroyGame: () -> ();

	MICROGAME_NAME: string;
	CONTROL_HINT_IMAGE: ImageLabel;
	CONTROL_HINT_TEXT: string;
	SONG_END_TIME_POSITION: number;
	SONG_NAME: number;

	OnGameOver: Signal.Signal<>;
	Started: Signal.Signal<>;

	_janitor: Janitor.Janitor;
	_currentGameGui: ScreenGui;
	_hasWon: boolean;
}

-- Timer.luau

export type TimerData = {
	IntValue: IntValue;
	BPM: number;

	TimerEnded: Signal.Signal<>;
	TimerBeatChanged: Signal.Signal<>;

	_signals: {Signal.Signal<>};
	_janitor: Janitor.Janitor;
}

return Config
