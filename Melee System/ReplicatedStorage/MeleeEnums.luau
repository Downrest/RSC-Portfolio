local MeleeEnums = {}

--[[
    public types
]]

type actionAnimation = {
    Instance: Animation;
    Priority: Enum.AnimationPriority;
    Looped: boolean;
}

type generalActionKey = "Idle" & "Aim" & "Equip" & "Hit" & string

type attackSound = {
    Swing: Sound;
    Hit: Sound;
}

export type ConfigData = {
	AttackType: string;

    General: {
        [generalActionKey]: actionAnimation & {
            Sound: Sound
        };
    };
    Attacks: {
        [string]: {
            Animation: actionAnimation;
            Sound: attackSound;

            Order: number;
            Cooldown: number;

            Damage: number;
			SwingSpeed: number;
            
			OnSwingMovement: Vector3;
            PostSwingMovement: Vector3;
        };
    };
}

export type ToolData = {
    Player: Player;
    Character: Model;
    HumanoidRootPart: BasePart;
    Humanoid: Humanoid;
    Animator: Animator;
    ConfigData: ConfigData;

    OverlapParams: OverlapParams;
    AttackAnims: {AnimationTrack};
    HitboxParts: {BasePart};
    MovementConstraint: LinearVelocity;

    SoundsList: {Sound};

    State: {
        IsAttacking: boolean;

        CurrentAttackOrder: number;
        MaxAttackOrder: number;
    }
}

--[[
    public enums
]]

MeleeEnums.attackTypesString = {
    BaseAttack = "BaseAttack";
}

MeleeEnums.meleeSounds = {
    Equip = "Equip";
}

return MeleeEnums
