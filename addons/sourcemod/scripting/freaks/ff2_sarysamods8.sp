// no warranty blah blah don't sue blah blah doing this for fun blah blah...

#pragma semicolon 1

#include <sourcemod>
#include <tf2items>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_functions>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <drain_over_time>
#include <drain_over_time_subplugin>
#include <tf2attributes>
#include <ff2_dynamic_defaults>

/**
 * My eighth VSP rage pack, rages for DJ Pon-3, Fluttershy, Surprise, Tirek, and FNAP.
 *
 * RageEarthquakeMachine: Create a machine that causes earthquake, damage and random knockback to players.
 *
 * DOTGuitarHero: Does the guitar taunt, at the end deals massive damage and knockback to players and buildings.
 *
 * FF2HeadCollection: The basis for any abilities whose power levels vary on number of heads collected
 * Known Issues: Not recommended for multi-boss use. Note that dead players award heads to both players, regardless of kill by player or world.
 *               Players cannot go into third person. This is for two reasons: Third person interacts poorly with different sizes, and condition 74 causes problems.
 */
 
// copied from tf2 sdk
// effects, for m_fEffects
#define EF_BONEMERGE 0x001	// Performs bone merge on client side
#define EF_BRIGHTLIGHT 0x002	// DLIGHT centered at entity origin
#define EF_DIMLIGHT 0x004	// player flashlight
#define EF_NOINTERP 0x008	// don't interpolate the next frame
#define EF_NOSHADOW 0x010	// Don't cast no shadow
#define EF_NODRAW 0x020		// don't draw entity
#define EF_NORECEIVESHADOW 0x040	// Don't receive no shadow
#define EF_BONEMERGE_FASTCULL 0x080	// For use with EF_BONEMERGE. If this is set, then it places this ent's origin at its
#define EF_ITEM_BLINK 0x100	// blink an item so that the user notices it.
#define EF_PARENT_ANIMATES 0x200	// always assume that the parent entity is animating

// solid types
#define SOLID_NONE 0 // no solid model
#define SOLID_BSP 1 // a BSP tree
#define SOLID_BBOX 2 // an AABB
#define SOLID_OBB 3 // an OBB (not implemented yet)
#define SOLID_OBB_YAW 4 // an OBB, constrained so that it can only yaw
#define SOLID_CUSTOM 5 // Always call into the entity for tests
#define SOLID_VPHYSICS 6 // solid vphysics object, get vcollide from the model and collide with that

#define FSOLID_CUSTOMRAYTEST 0x0001 // Ignore solid type + always call into the entity for ray tests
#define FSOLID_CUSTOMBOXTEST 0x0002 // Ignore solid type + always call into the entity for swept box tests
#define FSOLID_NOT_SOLID 0x0004 // Are we currently not solid?
#define FSOLID_TRIGGER 0x0008 // This is something may be collideable but fires touch functions
#define FSOLID_NOT_STANDABLE 0x0010 // You can't stand on this
#define FSOLID_VOLUME_CONTENTS 0x0020 // Contains volumetric contents (like water)
#define FSOLID_FORCE_WORLD_ALIGNED 0x0040 // Forces the collision rep to be world-aligned even if it's SOLID_BSP or SOLID_VPHYSICS
#define FSOLID_USE_TRIGGER_BOUNDS 0x0080 // Uses a special trigger bounds separate from the normal OBB
#define FSOLID_ROOT_PARENT_ALIGNED 0x0100 // Collisions are defined in root parent's local coordinate space
#define FSOLID_TRIGGER_TOUCH_DEBRIS 0x0200 // This trigger will touch debris objects

#define IsEmptyString(%1) (%1[0] == 0)

enum // Collision_Group_t in const.h
{
	COLLISION_GROUP_NONE  = 0,
	COLLISION_GROUP_DEBRIS,			// Collides with nothing but world and static stuff
	COLLISION_GROUP_DEBRIS_TRIGGER, // Same as debris, but hits triggers
	COLLISION_GROUP_INTERACTIVE_DEBRIS,	// Collides with everything except other interactive debris or debris
	COLLISION_GROUP_INTERACTIVE,	// Collides with everything except interactive debris or debris
	COLLISION_GROUP_PLAYER,
	COLLISION_GROUP_BREAKABLE_GLASS,
	COLLISION_GROUP_VEHICLE,
	COLLISION_GROUP_PLAYER_MOVEMENT,  // For HL2, same as Collision_Group_Player, for
										// TF2, this filters out other players and CBaseObjects
	COLLISION_GROUP_NPC,			// Generic NPC group
	COLLISION_GROUP_IN_VEHICLE,		// for any entity inside a vehicle
	COLLISION_GROUP_WEAPON,			// for any weapons that need collision detection
	COLLISION_GROUP_VEHICLE_CLIP,	// vehicle clip brush to restrict vehicle movement
	COLLISION_GROUP_PROJECTILE,		// Projectiles!
	COLLISION_GROUP_DOOR_BLOCKER,	// Blocks entities not permitted to get near moving doors
	COLLISION_GROUP_PASSABLE_DOOR,	// ** sarysa TF2 note: Must be scripted, not passable on physics prop (Doors that the player shouldn't collide with)
	COLLISION_GROUP_DISSOLVING,		// Things that are dissolving are in this group
	COLLISION_GROUP_PUSHAWAY,		// ** sarysa TF2 note: I could swear the collision detection is better for this than NONE. (Nonsolid on client and server, pushaway in player code)

	COLLISION_GROUP_NPC_ACTOR,		// Used so NPCs in scripts ignore the player.
	COLLISION_GROUP_NPC_SCRIPTED,	// USed for NPCs in scripts that should not collide with each other

	LAST_SHARED_COLLISION_GROUP
};
 
new bool:DEBUG_FORCE_RAGE = false;
#define ARG_LENGTH 256
 
new bool:PRINT_DEBUG_INFO = true;
new bool:PRINT_DEBUG_SPAM = false;

new Float:OFF_THE_MAP[3] = { 16383.0, 16383.0, -16383.0 };

#define NOPE_AVI "vo/engineer_no01.mp3" // DO NOT DELETE FROM FUTURE PACKS
#define INVALID_ENTREF INVALID_ENT_REFERENCE

// text string limits
#define MAX_SOUND_FILE_LENGTH 80
#define MAX_MODEL_FILE_LENGTH 128
#define MAX_MATERIAL_FILE_LENGTH 128
#define MAX_WEAPON_NAME_LENGTH 64
#define MAX_WEAPON_ARG_LENGTH 256
#define MAX_EFFECT_NAME_LENGTH 48
#define MAX_ENTITY_CLASSNAME_LENGTH 48
#define MAX_CENTER_TEXT_LENGTH 256
#define MAX_RANGE_STRING_LENGTH 66
#define MAX_HULL_STRING_LENGTH 197
#define MAX_ATTACHMENT_NAME_LENGTH 48
#define COLOR_BUFFER_SIZE 12
#define HEX_OR_DEC_STRING_LENGTH 12 // max -2 billion is 11 chars + null termination
#define MAX_TERMINOLOGY_LENGTH 24
#define MAX_ABILITY_NAME_LENGTH 33

#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

new bool:NULL_BLACKLIST[MAX_PLAYERS_ARRAY];

new MercTeam = _:TFTeam_Red;
new BossTeam = _:TFTeam_Blue;

new RoundInProgress = false;
new bool:PluginActiveThisRound = false;

public Plugin:myinfo = {
	name = "Freak Fortress 2: sarysa's mods, eighth pack",
	author = "sarysa",
	version = "1.2.3",
}

#define FAR_FUTURE 100000000.0
#define COND_JARATE_WATER 86

new NULL_CELL; // REMOVE FROM PACK9

/**
 * Earthquake Machine
 */
#define EM_STRING "rage_earthquake_machine"
#define EM_START_VELOCITY_Z -100.0
#define EM_POSITION_CHECK_INTERVAL 0.05
#define EM_FLAG_PREVENT_RESUMMON 0x0001
#define EM_FLAG_EXPONENTIAL_DAMAGE 0x0002
#define EM_FLAG_KNOCK_AROUND_ADDITIVE 0x0004
#define EM_FLAG_IMMUNE_IN_WATER 0x0008
#define EM_FLAG_NO_EARTHQUAKE 0x0010
#define EM_FLAG_NO_BUILDING_DAMAGE 0x0020
#define EM_FLAG_SILENCE_HITSOUNDS 0x0040
new bool:EM_ActiveThisRound;
new bool:EM_CanUse[MAX_PLAYERS_ARRAY];
new EM_MachineEntRef[MAX_PLAYERS_ARRAY]; // internal
new EM_ParticleEntRef[MAX_PLAYERS_ARRAY]; // internal
new Float:EM_NextDamageAt[MAX_PLAYERS_ARRAY]; // internal
new Float:EM_NextKnockAroundAt[MAX_PLAYERS_ARRAY]; // internal
new Float:EM_NextSonicWaveAt[MAX_PLAYERS_ARRAY]; // internal
new Float:EM_DespawnAt[MAX_PLAYERS_ARRAY]; // internal
new bool:EM_IsFalling[MAX_PLAYERS_ARRAY]; // internal
new bool:EM_AlreadyStruck[MAX_PLAYERS_ARRAY]; // internal
new Float:EM_LastPosition[MAX_PLAYERS_ARRAY][3]; // internal
new Float:EM_CheckPositionAt[MAX_PLAYERS_ARRAY]; // internal
new Float:EM_Duration[MAX_PLAYERS_ARRAY]; // arg1
new Float:EM_Radius[MAX_PLAYERS_ARRAY]; // arg2
new Float:EM_ImmunityClearance[MAX_PLAYERS_ARRAY]; // arg3
new Float:EM_MaxDamage[MAX_PLAYERS_ARRAY]; // arg4
new Float:EM_DamageInterval[MAX_PLAYERS_ARRAY]; // arg5
new Float:EM_KnockAroundIntensity[MAX_PLAYERS_ARRAY]; // arg6
new Float:EM_KnockAroundMinZ[MAX_PLAYERS_ARRAY]; // arg7
new Float:EM_KnockAroundChance[MAX_PLAYERS_ARRAY]; // arg8
new Float:EM_KnockAroundInterval[MAX_PLAYERS_ARRAY]; // arg9
new Float:EM_Gravity[MAX_PLAYERS_ARRAY]; // arg10
new Float:EM_PlayerStrikeDamage[MAX_PLAYERS_ARRAY]; // arg11
new Float:EM_PlayerStrikeKnockback[MAX_PLAYERS_ARRAY]; // arg12
new Float:EM_CollisionHeight[MAX_PLAYERS_ARRAY]; // arg13
new Float:EM_CollisionRadius[MAX_PLAYERS_ARRAY]; // arg14
new Float:EM_Exponent[MAX_PLAYERS_ARRAY]; // arg15
new Float:EM_BuildingDamageModifier[MAX_PLAYERS_ARRAY]; // arg16
new EM_Flags[MAX_PLAYERS_ARRAY]; // arg19

// aesthetics -- shared in a multi-boss setup, though this is not intended to be used by multiple hales in one battle.
#define EMA_STRING "earthquake_machine_aesthetics"
new String:EMA_AmbientSound[MAX_SOUND_FILE_LENGTH]; // arg1
new String:EMA_CrashSound[MAX_SOUND_FILE_LENGTH]; // arg2
new String:EMA_RageSound[MAX_SOUND_FILE_LENGTH]; // arg3
new String:EMA_MachineModelFalling[MAX_MODEL_FILE_LENGTH]; // arg7
new String:EMA_MachineModelOnGround[MAX_MODEL_FILE_LENGTH]; // arg8
new EMA_BeaconMaterial; // arg9
new Float:EMA_BeaconLoopInterval; // arg10
new Float:EMA_BeaconRadius; // arg11
new Float:EMA_BeaconSpeedFactor; // arg12
new EMA_BeaconColor; // arg13
new Float:EMA_BeaconZOffset; // arg14
new String:EMA_CrashEffect[MAX_EFFECT_NAME_LENGTH]; // arg15
new String:EMA_PersistentEffect[MAX_EFFECT_NAME_LENGTH]; // arg16
new String:EMA_RageSpamMessage[MAX_CENTER_TEXT_LENGTH]; // arg19

// derp
new BEACON_HALO;

/**
 * Guitar Hero
 */
#define GH_STRING "dot_guitar_hero"
#define GH_GUITAR_SOUND "player/brutal_legend_taunt.wav"
new bool:GH_ActiveThisRound;
new bool:GH_CanUse[MAX_PLAYERS_ARRAY];
new bool:GH_IsUsing[MAX_PLAYERS_ARRAY];
new Float:GH_EffectsAt[MAX_PLAYERS_ARRAY]; // internal
new bool:GH_GuitarIsKilling; // internal
new Float:GH_EffectDelay[MAX_PLAYERS_ARRAY]; // arg1
new Float:GH_Radius[MAX_PLAYERS_ARRAY]; // arg2
new Float:GH_Damage[MAX_PLAYERS_ARRAY]; // arg3
new Float:GH_Knockback[MAX_PLAYERS_ARRAY]; // arg4
new Float:GH_MinZ[MAX_PLAYERS_ARRAY]; // arg5
new bool:GH_MakeInvincible[MAX_PLAYERS_ARRAY]; // arg6
new Float:GH_BuildingDamageFactor[MAX_PLAYERS_ARRAY]; // arg7
new String:GH_ErrorMessage[MAX_CENTER_TEXT_LENGTH]; // arg8
new GH_SoundRepeatCount[MAX_PLAYERS_ARRAY]; // arg9

/**
 * Medic Minion
 */
#define MM_STRING "rage_medic_minion"
#define MM2_STRING "medic_minion2"
#define MM_SHIELD_NONE 0
#define MM_SHIELD_TYPICAL 1
#define MM_SHIELD_VSP 2
#define MM_MAX_REVENGE_CONDITIONS 10
#define MM_FLAG_SUICIDE_BLACKLIST 0x0001
#define MM_FLAG_MINION_SUICIDE_PUNISHMENT 0x0002
#define MM_FLAG_MINION_FREE_QUOTA 0x0004
#define MM_FLAG_MINION_DIE_WITH_BOSS 0x0008
#define MM_FLAG_REVENGE_INVINCIBLE 0x0010
#define MM_FLAG_ALLOW_CHOICE 0x0020
#define MM_FLAG_ONCE_AS_MINION_PER_ROUND 0x0040
#define MM_HUD_INTERVAL 0.1
#define MM_HUD_Y 0.68
new bool:MM_ActiveThisRound;
new bool:MM_CanUse[MAX_PLAYERS_ARRAY]; 
new Float:MM_RefundRageAt[MAX_PLAYERS_ARRAY]; // internal
new Float:MM_RevengeUntil[MAX_PLAYERS_ARRAY]; // internal
new MM_BackstabPendingAgainst[MAX_PLAYERS_ARRAY]; // internal, a variable for ordinary players
new MM_AttackNextFrame[MAX_PLAYERS_ARRAY]; // internal
new Float:MM_ANFDamage[MAX_PLAYERS_ARRAY]; // internal, pre-crit damage
new MM_ANFAttacker[MAX_PLAYERS_ARRAY]; // internal, original attacker so point hurt can be placed properly
new MM_CurrentMinionChoice[MAX_PLAYERS_ARRAY]; // internal
new bool:MM_SpecialDown[MAX_PLAYERS_ARRAY]; // internal
new Float:MM_NextHUDAt[MAX_PLAYERS_ARRAY]; // internal
// arg1-arg6 are not stored, though arg1 doees need to be precached
new MM_MaxHP[MAX_PLAYERS_ARRAY]; // arg7
new Float:MM_MinionNormalSpeed[MAX_PLAYERS_ARRAY]; // arg8
new Float:MM_MinionHealedSpeed[MAX_PLAYERS_ARRAY]; // arg9
new Float:MM_MinionUberedSpeed[MAX_PLAYERS_ARRAY]; // arg10
new String:MM_MinionHealedEffect[MAX_EFFECT_NAME_LENGTH]; // arg11
new Float:MM_MinionRefundTime[MAX_PLAYERS_ARRAY]; // arg12
new Float:MM_MinionRefundDelay[MAX_PLAYERS_ARRAY]; // arg13
new String:MM_MinionSpawnEffect[MAX_EFFECT_NAME_LENGTH]; // arg14
new Float:MM_RevengeDuration[MAX_PLAYERS_ARRAY]; // arg15
new TFCond:MM_RevengeConditions[MAX_PLAYERS_ARRAY][MM_MAX_REVENGE_CONDITIONS]; // arg16
new String:MM_RevengeSound[MAX_SOUND_FILE_LENGTH]; // arg17
new Float:MM_SpeedLinger[MAX_PLAYERS_ARRAY]; // arg18
new MM_Flags; // arg19
new Float:MM_BackstabMultiplier = 0.5; // rage2 arg1
new MM_ShieldHandling = 1; // rage2 arg2
new Float:MM_MinionNormalVulnerability[MAX_PLAYERS_ARRAY]; // rage2 arg3
new Float:MM_MinionHealedVulnerability[MAX_PLAYERS_ARRAY]; // rage2 arg4
new Float:MM_MinionUberedVulnerability[MAX_PLAYERS_ARRAY]; // rage2 arg5
new Float:MM_RevengeBuildingMult[MAX_PLAYERS_ARRAY]; // rage2 arg6
new String:MM_MinionKillSound[MAX_SOUND_FILE_LENGTH]; // rage2 arg7
new String:MM_ChoiceHUDMessage[MAX_CENTER_TEXT_LENGTH]; // rage2 arg8
new Float:MM_BossUberedVulnerability[MAX_PLAYERS_ARRAY]; // rage2 arg9

// medic minion minions :P
new bool:MMM_IsMinion[MAX_PLAYERS_ARRAY];
new MMM_Owner[MAX_PLAYERS_ARRAY];
new TFClassType:MMM_LastClass[MAX_PLAYERS_ARRAY];
new MMM_RemodelCount[MAX_PLAYERS_ARRAY]; // for model not sticking workaround
new Float:MMM_RemodelAt[MAX_PLAYERS_ARRAY]; // for model not sticking workaround
new Float:MMM_MinionSpawnedAt[MAX_PLAYERS_ARRAY];
new Float:MMM_RemoveInvincibilityAt[MAX_PLAYERS_ARRAY];
new bool:MMM_Blacklisted[MAX_PLAYERS_ARRAY];
new Float:MMM_SpeedBuffedUntil[MAX_PLAYERS_ARRAY];
new MMM_ParticleEntRef[MAX_PLAYERS_ARRAY];
new bool:MMM_DamageHooked[MAX_PLAYERS_ARRAY];
new Float:MMM_DamageVulnerability[MAX_PLAYERS_ARRAY];
new MMM_LastKillCount[MAX_PLAYERS_ARRAY]; // used for kill sound

/**
 * Mobility by Weapon
 */
#define MBW_STRING "ff2_mobility_by_weapon"
#define MBW_MAX_WEAPONS 10
#define MBW_JUMP 0
#define MBW_TELEPORT 1
new bool:MBW_ActiveThisRound;
new bool:MBW_CanUse[MAX_PLAYERS_ARRAY];
new MBW_LastSlotOrWeapon[MAX_PLAYERS_ARRAY]; // internal
new MBW_SlotsOrWeapons[MAX_PLAYERS_ARRAY][MBW_MAX_WEAPONS]; // arg1
new MBW_AbilityIdx[MAX_PLAYERS_ARRAY][MBW_MAX_WEAPONS]; // arg2

/**
 * DOT Stare
 */
#define DS_STRING "dot_stare"
new bool:DS_ActiveThisRound;
new bool:DS_CanUse[MAX_PLAYERS_ARRAY];
new Float:DS_AffectedUntil[MAX_PLAYERS_ARRAY]; // internal
new Float:DS_ExpectedSpeed[MAX_PLAYERS_ARRAY]; // internal
new Float:DS_MySlowMultiplier[MAX_PLAYERS_ARRAY]; // internal
new DS_ParticleEntRef[MAX_PLAYERS_ARRAY]; // internal
new Float:DS_Radius[MAX_PLAYERS_ARRAY]; // arg1
new Float:DS_Duration[MAX_PLAYERS_ARRAY]; // arg2
new Float:DS_SpeedMultiplier[MAX_PLAYERS_ARRAY]; // arg3
new Float:DS_Damage[MAX_PLAYERS_ARRAY]; // arg4
new Float:DS_AmmoDrain[MAX_PLAYERS_ARRAY]; // arg5
new String:DS_RageSound[MAX_SOUND_FILE_LENGTH]; // arg6
new String:DS_Effect[MAX_EFFECT_NAME_LENGTH]; // arg7
new Float:DS_SentryBulletDrain[MAX_PLAYERS_ARRAY]; // arg8
new Float:DS_SentryRocketDrain[MAX_PLAYERS_ARRAY]; // arg9

/**
 * Medigun Fixes
 */
#define MF_STRING "ff2_medigun_fixes"
new bool:MF_ActiveThisRound;
new bool:MF_CanUse[MAX_PLAYERS_ARRAY];
new Float:MF_LastMedigunLevel[MAX_PLAYERS_ARRAY]; // internal
new Float:MF_RemoveWearablesAt[MAX_PLAYERS_ARRAY]; // internal
new bool:MF_RemoveWearables[MAX_PLAYERS_ARRAY]; // arg1
new bool:MF_UndoFreeUber[MAX_PLAYERS_ARRAY]; // arg2
new bool:MF_UndoOvercharge[MAX_PLAYERS_ARRAY]; // arg3

/**
 * Safe Resize, for Surprise
 */
#define SR_STRING "rage_safe_resize"
#define SR_MODE_PLAYERS 0
#define SR_MODE_BOSSES 1
#define SR_MODE_EVERYONE 2
#define SR_RETRY_INTERVAL 0.1
new bool:SR_ActiveThisRound;
new Float:SR_SetSizeAt[MAX_PLAYERS_ARRAY]; // internal
new Float:SR_PendingSize[MAX_PLAYERS_ARRAY]; // internal
new Float:SR_RestoreSizeAt[MAX_PLAYERS_ARRAY]; // internal
new Float:SR_ResizeSlayAt[MAX_PLAYERS_ARRAY]; // internal
new SR_LastWarningNum[MAX_PLAYERS_ARRAY]; // internal
new Float:SR_Radius[MAX_PLAYERS_ARRAY]; // arg1
new Float:SR_Duration[MAX_PLAYERS_ARRAY]; // arg2
new Float:SR_ScaleFactor[MAX_PLAYERS_ARRAY]; // arg3
new Float:SR_DurationVariance[MAX_PLAYERS_ARRAY]; // arg4
new Float:SR_ScaleVariance[MAX_PLAYERS_ARRAY]; // arg5
new SR_SlayGracePeriod; // arg6
new SR_ScaleMode[MAX_PLAYERS_ARRAY]; // arg7
new String:SR_WarningMessage[MAX_CENTER_TEXT_LENGTH]; // arg8
		
/**
 * Head Collection
 */
#define HC_STRING "ff2_head_collection"
#define HC_PS_NEVER_VALID 0
#define HC_PS_ALIVE 1
#define HC_PS_DEAD 2
#define HC_DEAD_INTERVAL 0.05
#define HC_RESIZE_INTERVAL 0.2
#define HC_FP_INTERVAL 0.5
#define HC_WEAPON_NORMAL 0
#define HC_WEAPON_BAT 1
#define HC_WEAPON_KNIFE 2
#define HC_FLAG_FIX_DAMAGE_TRIPLING 0x0001
#define HC_FLAG_SUICIDES_REDUCE_TOTAL 0x0002
#define HC_FLAG_CONDITION_74 0x0004
#define HC_FLAG_DAMAGE_CEILING 0x0010
#define HC_FLAG_BUILDING_DAMAGE_CEILING 0x0020
#define HC_FLAG_KNOCKBACK_FLOOR 0x0040
#define HC_FLAG_HEIGHT_CEILING 0x0080
new bool:HC_ActiveThisRound;
new bool:HC_CanUse[MAX_PLAYERS_ARRAY];
new bool:HC_Initialized[MAX_PLAYERS_ARRAY]; // internal
new HC_FPRetriesLeft[MAX_PLAYERS_ARRAY]; // internal
new Float:HC_NextFPRetryAt[MAX_PLAYERS_ARRAY]; // internal
new Float:HC_TouchEffectImmuneUntil[MAX_PLAYERS_ARRAY]; // internal, meant for enemies
new HC_PendingHeads[MAX_PLAYERS_ARRAY]; // internal
new HC_CurrentHeads[MAX_PLAYERS_ARRAY]; // internal
new Float:HC_NextResizeAttemptAt[MAX_PLAYERS_ARRAY]; // internal
new Float:HC_HeadMultiplierReduction[MAX_PLAYERS_ARRAY]; // internal, though only outside rages can change this 
new bool:HC_RageDisabledResize[MAX_PLAYERS_ARRAY]; // internal, though only outside rages can change this 
new HC_PlayerStates[MAX_PLAYERS_ARRAY]; // internal
new bool:HC_ForceReadjust[MAX_PLAYERS_ARRAY]; // internal, for when the hale's rage adjusts their power level
new HC_HPForWeapon[MAX_PLAYERS_ARRAY]; // internal, appended to any weapon swap the hale gets
new HC_PlayerCount; // internal, shared in unlikely multiboss scenario
new HC_PendingPlayerCount; // internal, handling of suicides and DC's
new Float:HC_CheckDeadAt; // internal
new HC_WeaponType[MAX_PLAYERS_ARRAY]; // arg1
new Float:HC_HalfPowerAt[MAX_PLAYERS_ARRAY]; // arg2
new Float:HC_FullPowerAt[MAX_PLAYERS_ARRAY]; // arg3
new Float:HC_HeightLandmarks[MAX_PLAYERS_ARRAY][3]; // arg4
new Float:HC_PlayerDamageLandmarks[MAX_PLAYERS_ARRAY][3]; // arg5
new Float:HC_BuildingDamageLandmarks[MAX_PLAYERS_ARRAY][3]; // arg6
new Float:HC_KnockbackLandmarks[MAX_PLAYERS_ARRAY][3]; // arg7
new String:HC_ResizeParticle[MAX_EFFECT_NAME_LENGTH]; // arg8
new Float:HC_PyroTeleportCooldownReduction[MAX_PLAYERS_ARRAY]; // arg9. also I'll probably never make variable names this long ever again...
new Float:HC_TouchEffectInterval[MAX_PLAYERS_ARRAY]; // arg12
new Float:HC_TouchEffectDamage[MAX_PLAYERS_ARRAY]; // arg13
new Float:HC_TouchEffectUberDrain[MAX_PLAYERS_ARRAY]; // arg14
// arg15 (weaponName), arg16 (weaponIdx), arg17 (weaponArgs), arg18 (weaponVis) not preloaded
new HC_Flags[MAX_PLAYERS_ARRAY]; // arg19

/**
 * Head Powers
 */
#define HP_STRING "ff2_head_powers"
new bool:HP_ActiveThisRound;
new bool:HP_CanUse[MAX_PLAYERS_ARRAY];
new Float:HP_LastPowerLevel[MAX_PLAYERS_ARRAY]; // internal, so I don't have to spam reflected methods every frame
new Float:HP_TeleportPower[MAX_PLAYERS_ARRAY]; // arg1
new String:HP_TeleportName[MAX_TERMINOLOGY_LENGTH]; // arg2
new Float:HP_SuperJumpPower[MAX_PLAYERS_ARRAY]; // arg3
new String:HP_SuperJumpName[MAX_TERMINOLOGY_LENGTH]; // arg4
new Float:HP_GlidePower[MAX_PLAYERS_ARRAY]; // arg5
new String:HP_GlideName[MAX_TERMINOLOGY_LENGTH]; // arg6

/**
 * Head Drain
 */
#define HD_STRING "dot_head_drain"
new bool:HD_CanUse[MAX_PLAYERS_ARRAY];
new Float:HD_DrainWithMax[MAX_PLAYERS_ARRAY]; // arg1, drain vs 31 players
new Float:HD_DrainWithMin[MAX_PLAYERS_ARRAY]; // arg2, drain vs 2 players

/**
 * Head Controlled Rage
 */
#define HCR_STRING "ff2_head_controlled_rage"
new bool:HCR_ActiveThisRound;
new bool:HCR_CanUse[MAX_PLAYERS_ARRAY];
new Float:HCR_MinPowerLevel[MAX_PLAYERS_ARRAY]; // arg1
new bool:HCR_HideFF2HUD[MAX_PLAYERS_ARRAY]; // arg2
new bool:HCR_HideDDHUD[MAX_PLAYERS_ARRAY]; // arg3
new bool:HCR_RageOnGround[MAX_PLAYERS_ARRAY]; // arg4

/**
 * Head Annihilation
 */
#define HA_STRING "rage_head_annihilation"
#define HA2_STRING "head_annihilation2"
#define HA_FLAG_DAMAGE_CAPPED 0x0001
#define HA_FLAG_RANGE_CAPPED 0x0002
#define HA_FLAG_CAST_TIME_CAPPED 0x0004
#define HA_FLAG_RECOVERY_TIME_CAPPED 0x0008
#define HA_FLAG_HOOKED_DAMAGE 0x0010
#define HA_FLAG_FIX_BONK_BLEED 0x0020
new bool:HA_ActiveThisRound;
new bool:HA_CanUse[MAX_PLAYERS_ARRAY];
new Float:HA_RageStartedAt[MAX_PLAYERS_ARRAY]; // internal
new Float:HA_RageEndsAt[MAX_PLAYERS_ARRAY]; // internal
new Float:HA_PlaySecondSoundAt[MAX_PLAYERS_ARRAY]; // internal
new Float:HA_PlayThirdSoundAt[MAX_PLAYERS_ARRAY]; // internal
new Float:HA_ReenableRageAt[MAX_PLAYERS_ARRAY]; // internal
new HA_AttachmentEntRef[MAX_PLAYERS_ARRAY]; // internal
new Float:HA_ConsumptionThisRage[MAX_PLAYERS_ARRAY]; // internal
new Float:HA_DamageLinear[MAX_PLAYERS_ARRAY]; // internal
new Float:HA_DamageFactor[MAX_PLAYERS_ARRAY]; // internal
new Float:HA_Radius[MAX_PLAYERS_ARRAY]; // internal
new Float:HA_CastTime[MAX_PLAYERS_ARRAY]; // internal
new Float:HA_Recovery[MAX_PLAYERS_ARRAY]; // internal
new bool:HA_Anemia[MAX_PLAYERS_ARRAY]; // internal
new bool:HA_SharedStun[MAX_PLAYERS_ARRAY]; // internal
new bool:HA_MedigunDrain[MAX_PLAYERS_ARRAY]; // internal
new HC_BallEntRef[MAX_PLAYERS_ARRAY]; // internal
new Float:HA_PostRageCooldownUntil[MAX_PLAYERS_ARRAY]; // internal
new Float:HA_DamageLandmarks[MAX_PLAYERS_ARRAY][3]; // arg1
new Float:HA_DamageMultLandmarks[MAX_PLAYERS_ARRAY][3]; // arg2
new Float:HA_RadiusLandmarks[MAX_PLAYERS_ARRAY][3]; // arg3
new Float:HA_CastTimeLandmarks[MAX_PLAYERS_ARRAY][3]; // arg4
new Float:HA_RecoveryLandmarks[MAX_PLAYERS_ARRAY][3]; // arg5
new Float:HA_AnemiaBonusAt[MAX_PLAYERS_ARRAY]; // arg6
new Float:HA_SharedStunBonusAt[MAX_PLAYERS_ARRAY]; // arg7
new Float:HA_MedigunDrainBonusAt[MAX_PLAYERS_ARRAY]; // arg8
new Float:HA_HeadPowerRemovalFactor[MAX_PLAYERS_ARRAY]; // arg9
new String:HA_Model[MAX_MODEL_FILE_LENGTH]; // arg10
new Float:HA_ToNormalSizeFactor[MAX_PLAYERS_ARRAY]; // arg11
new Float:HA_ToMaxSizeFactor[MAX_PLAYERS_ARRAY]; // arg12
new Float:HA_ModelRadius[MAX_PLAYERS_ARRAY]; // arg13
new Float:HA_MaxResizeFactor[MAX_PLAYERS_ARRAY]; // arg14
new String:HA_FirstSound[MAX_SOUND_FILE_LENGTH]; // arg15
new String:HA_SecondSound[MAX_SOUND_FILE_LENGTH]; // arg16
new String:HA_ThirdSound[MAX_SOUND_FILE_LENGTH]; // arg17
new String:HA_FourthSound[MAX_SOUND_FILE_LENGTH]; // arg18
new HA_Flags[MAX_PLAYERS_ARRAY]; // arg19
new HA_MaxFogColor[MAX_PLAYERS_ARRAY]; // rage2 arg1
new String:HA_AttachmentName[MAX_ATTACHMENT_NAME_LENGTH]; // rage2 arg2
new String:HA_AnemiaName[MAX_TERMINOLOGY_LENGTH]; // rage2 arg3
new String:HA_SharedStunName[MAX_TERMINOLOGY_LENGTH]; // rage2 arg4
new String:HA_MedigunDrainName[MAX_TERMINOLOGY_LENGTH]; // rage2 arg5
new Float:HA_CooldownDuration[MAX_PLAYERS_ARRAY]; // rage2 arg6

/**
 * Head HUDs
 */
#define HH_STRING "ff2_head_huds"
#define HH_INTERVAL 0.1
new bool:HH_ActiveThisRound;
new bool:HH_CanUse[MAX_PLAYERS_ARRAY];
new Float:HH_UpdateAt[MAX_PLAYERS_ARRAY]; // internal
new Float:HH_NaturalHudX[MAX_PLAYERS_ARRAY]; // arg1
new Float:HH_NaturalHudY[MAX_PLAYERS_ARRAY]; // arg2
new HH_NaturalHudColor[MAX_PLAYERS_ARRAY]; // arg3
new String:HH_NaturalHudMessage[MAX_CENTER_TEXT_LENGTH]; // arg4
new Float:HH_RageHudY[MAX_PLAYERS_ARRAY]; // arg5
new HH_RageHudColor[MAX_PLAYERS_ARRAY]; // arg6
new String:HH_RageHudDOTMessage[MAX_CENTER_TEXT_LENGTH]; // arg7
new String:HH_RageHudNotReady[MAX_CENTER_TEXT_LENGTH]; // arg8
new String:HH_RageHudReady[MAX_CENTER_TEXT_LENGTH]; // arg9
new String:HH_RageHudStats[MAX_CENTER_TEXT_LENGTH]; // arg10

/**
 * FNAP Rages
 */
#define FNAP_STRING "fnap_rages"
#define FNAP2_STRING "fnap2"
#define FNAP_HUD_INTERVAL 0.1
#define FNAP_COUNT 6
#define FNAP_RAGEDAMAGE 2000.0
new bool:FNAP_ActiveThisRound;
new bool:FNAP_CanUse[MAX_PLAYERS_ARRAY];
new Float:FNAP_ActualRage[MAX_PLAYERS_ARRAY]; // internal, since it must be managed manually
new FNAP_CurrentLife[MAX_PLAYERS_ARRAY]; // internal
new Float:FNAP_UpdateHUDAt[MAX_PLAYERS_ARRAY]; // internal
new Float:FNAP_SpeedOverride[MAX_PLAYERS_ARRAY]; // internal
new Float:FNAP_TeleportStun[MAX_PLAYERS_ARRAY]; // internal
new Float:FNAP_TeleportCooldown[MAX_PLAYERS_ARRAY]; // internal
new Float:FNAP_TeleportChargeTime[MAX_PLAYERS_ARRAY]; // internal
new Float:FNAP_ShowTimeHUDUntil; // internal
new FNAP_IsSuperJump[FNAP_COUNT]; // arg1
new String:FNAP_Rages[FNAP_COUNT][MAX_ABILITY_NAME_LENGTH]; // arg2
new Float:FNAP_RageDamage[FNAP_COUNT]; // arg3
new Float:FNAP_Speed[FNAP_COUNT]; // arg4
new String:FNAP_Overlays[FNAP_COUNT][MAX_MATERIAL_FILE_LENGTH]; // arg5
new String:FNAP_Models[FNAP_COUNT][MAX_MODEL_FILE_LENGTH]; // arg6
new Float:FNAP_DescHudY[MAX_PLAYERS_ARRAY]; // arg7
new String:FNAP_DescHuds[FNAP_COUNT][MAX_CENTER_TEXT_LENGTH]; // arg8-arg13
new Float:FNAP_OverlayDuration; // arg14
new String:FNAP_DeathSound[MAX_SOUND_FILE_LENGTH]; // arg15
new Float:FNAP_HudY[MAX_PLAYERS_ARRAY]; // arg16
new String:FNAP_NotReadyStr[MAX_CENTER_TEXT_LENGTH]; // arg17
new String:FNAP_ReadyStr[MAX_CENTER_TEXT_LENGTH]; // arg18
new Float:FNAP_RageReductionPerLife[MAX_PLAYERS_ARRAY]; // arg19
new String:FNAP_WeaponNames[FNAP_COUNT][MAX_WEAPON_NAME_LENGTH]; // rage2 arg1
new FNAP_WeaponIndexes[FNAP_COUNT]; // rage2 arg2
new FNAP_WeaponVisibilities[FNAP_COUNT]; // rage2 arg3
new String:FNAP_WeaponArgs[FNAP_COUNT][MAX_WEAPON_ARG_LENGTH]; // rage2 arg4-arg9. was tempted to named this FNAP_WeaponArgses
new Float:FNAP_SentryStunRadius[FNAP_COUNT]; // rage2 arg10
new Float:FNAP_SentryStunDuration[FNAP_COUNT]; // rage2 arg11
new FNAP_PinkieTeleportDefault[MAX_PLAYERS_ARRAY]; // rage2 arg12
new Float:FNAP_TimeHudDuration; // rage2 arg13
new Float:FNAP_TimeHudX; // rage2 arg14
new Float:FNAP_TimeHudY; // rage2 arg15
new String:FNAP_TimeHudMessage[MAX_CENTER_TEXT_LENGTH]; // rage2 arg16

/**
 * Prop Buff
 */
#define PB_STRING "rage_prop_buff"
#define MAX_CONDITIONS 10
new bool:PB_ActiveThisRound;
new bool:PB_CanUse[MAX_PLAYERS_ARRAY];
new PB_NumConditions[MAX_PLAYERS_ARRAY]; // internal
new Float:PB_RemoveConditionAt[MAX_PLAYERS_ARRAY][MAX_CONDITIONS]; // internal
new bool:PB_IsFNAP[MAX_PLAYERS_ARRAY]; // arg1
new String:PB_Model[MAX_MODEL_FILE_LENGTH]; // arg2
new PB_PossibleConditions[MAX_PLAYERS_ARRAY][MAX_CONDITIONS]; // arg3
new PB_MinConditions[MAX_PLAYERS_ARRAY]; // arg4
new PB_MaxConditions[MAX_PLAYERS_ARRAY]; // arg5
new Float:PB_Duration[MAX_PLAYERS_ARRAY]; // arg6
new Float:PB_ObjRadius[MAX_PLAYERS_ARRAY]; // arg7
new Float:PB_ObjHeight[MAX_PLAYERS_ARRAY]; // arg8
new Float:PB_MaxXYVelocity[MAX_PLAYERS_ARRAY]; // arg9
new Float:PB_ActivationDelay[MAX_PLAYERS_ARRAY]; // arg10
new PB_MinToSpawn[MAX_PLAYERS_ARRAY]; // arg11
new PB_MaxToSpawn[MAX_PLAYERS_ARRAY]; // arg12
new String:PB_Sound[MAX_SOUND_FILE_LENGTH]; // arg18

#define MAX_PROPS 20
new PBP_EntRef[MAX_PROPS];
new Float:PBP_ActivateAt[MAX_PROPS];
new PBP_Creator[MAX_PROPS];
new Float:PBP_CollisionTestAt[MAX_PROPS];
new Float:PBP_StopMovementAt[MAX_PROPS];

/**
 * Pickup Trap
 */
#define PT_STRING "rage_pickup_trap"
new bool:PT_ActiveThisRound;
new bool:PT_DispensersAreHarmful; // internal
new Float:PT_DispensersHarmUntil; // internal
new Float:PT_DispenserCheckAt; // internal
new PT_IsFNAP[MAX_PLAYERS_ARRAY]; // arg1
new Float:PT_Duration[MAX_PLAYERS_ARRAY]; // arg2
new PT_TrapCount[MAX_PLAYERS_ARRAY]; // arg3
new Float:PT_TrapHealthNerfAmount[MAX_PLAYERS_ARRAY]; // arg4
new Float:PT_TrapAmmoNerfAmount[MAX_PLAYERS_ARRAY]; // arg5
new PT_TrappedObjectRecolor[MAX_PLAYERS_ARRAY]; // arg6
new Float:PT_DispenserHarmDuration[MAX_PLAYERS_ARRAY]; // arg7
new Float:PT_DispenserHarmDamage; // arg8
new Float:PT_DispenserHarmInterval; // arg9
new String:PT_Sound[MAX_SOUND_FILE_LENGTH]; // arg18

#define MAX_TRAPS 50
new bool:PTT_TrapsNeverExpire;
new PTT_EntRef[MAX_TRAPS];
new PTT_Trapper[MAX_TRAPS];
new Float:PTT_TrappedUntil[MAX_TRAPS];

/**
 * Speed By Views
 */
#define SBV_STRING "ff2_speed_by_views"
new bool:SBV_ActiveThisRound;
new bool:SBV_CanUse[MAX_PLAYERS_ARRAY];
new Float:SBV_RecalculateAt[MAX_PLAYERS_ARRAY]; // internal
new Float:SBV_LastSpeed[MAX_PLAYERS_ARRAY]; // internal
new Float:SBV_RageUntil[MAX_PLAYERS_ARRAY]; // internal
new SBV_IsFNAP; // arg1
new Float:SBV_Duration[MAX_PLAYERS_ARRAY]; // arg2
new SBV_MaxPlayers[MAX_PLAYERS_ARRAY]; // arg3
new Float:SBV_MinSpeed[MAX_PLAYERS_ARRAY]; // arg4
new Float:SBV_MaxSpeed[MAX_PLAYERS_ARRAY]; // arg5
new Float:SBV_MaxAnglePitch[MAX_PLAYERS_ARRAY]; // arg6
new Float:SBV_MaxAngleYaw[MAX_PLAYERS_ARRAY]; // arg7
new Float:SBV_Interval[MAX_PLAYERS_ARRAY]; // arg8
new String:SBV_Overlay[MAX_MATERIAL_FILE_LENGTH]; // arg9
new String:SBV_Sound[MAX_SOUND_FILE_LENGTH]; // arg18

/**
 * Twisted Attraction
 */
#define TA_STRING "rage_twisted_attraction"
new bool:TA_ActiveThisRound;
new bool:TA_CanUse[MAX_PLAYERS_ARRAY];
new Float:TA_InvincibilityEndsAt[MAX_PLAYERS_ARRAY]; // internal
new Float:TA_DamageAt[MAX_PLAYERS_ARRAY]; // internal
new TA_OrbEntRef[MAX_PLAYERS_ARRAY]; // internal
new Float:TA_RemoveOrbAt[MAX_PLAYERS_ARRAY]; // internal
new bool:TA_IsFNAP[MAX_PLAYERS_ARRAY]; // arg1
new Float:TA_InvincibilityDuration[MAX_PLAYERS_ARRAY]; // arg2
new Float:TA_DamageDelay[MAX_PLAYERS_ARRAY]; // arg3
new bool:TA_ShouldImmobilize[MAX_PLAYERS_ARRAY]; // arg4
new Float:TA_AttractionRadius[MAX_PLAYERS_ARRAY]; // arg5
new Float:TA_MinAttraction[MAX_PLAYERS_ARRAY]; // arg6
new Float:TA_MaxAttraction[MAX_PLAYERS_ARRAY]; // arg7
new Float:TA_DamageRadius[MAX_PLAYERS_ARRAY]; // arg8
new Float:TA_BaseDamage[MAX_PLAYERS_ARRAY]; // arg9
new Float:TA_DamageFalloffExp[MAX_PLAYERS_ARRAY]; // arg10
new String:TA_DamageEffect[MAX_EFFECT_NAME_LENGTH]; // arg11
new String:TA_Sound[MAX_SOUND_FILE_LENGTH]; // arg18

/**
 * Instant Teleports
 */
#define IT_STRING "rage_instant_teleports"
new bool:IT_ActiveThisRound;
new bool:IT_CanUse[MAX_PLAYERS_ARRAY];
new bool:IT_ButtonDown[MAX_PLAYERS_ARRAY]; // internal
new bool:IT_CurrentlyTeleport[MAX_PLAYERS_ARRAY]; // internal
new bool:IT_IsFNAP[MAX_PLAYERS_ARRAY]; // arg1
new IT_TeleportPerRage[MAX_PLAYERS_ARRAY]; // arg2
new Float:IT_TeleportStun[MAX_PLAYERS_ARRAY]; // arg3
new Float:IT_TeleportCooldown[MAX_PLAYERS_ARRAY]; // arg4
new Float:IT_TeleportChargeTime[MAX_PLAYERS_ARRAY]; // arg5
new bool:IT_TeleportUsesSpecial[MAX_PLAYERS_ARRAY]; // arg6
new String:IT_Sound[MAX_SOUND_FILE_LENGTH]; // arg18

/**
 * Cripple Stacks
 */
#define CS_STRING "rage_cripple_stacks"
new bool:CS_ActiveThisRound;
new Float:CS_VictimDamageAt[MAX_PLAYERS_ARRAY]; // internal, victim use only
new Float:CS_VictimDamageInterval[MAX_PLAYERS_ARRAY]; // internal, victim use only
new Float:CS_VictimDamage[MAX_PLAYERS_ARRAY]; // internal, victim use only
new Float:CS_VictimSpeedFactor[MAX_PLAYERS_ARRAY]; // internal, victim use only
new Float:CS_VictimVulnerability[MAX_PLAYERS_ARRAY]; // internal, victim use only
new Float:CS_ExpectedSpeed[MAX_PLAYERS_ARRAY]; // internal
new CS_VictimKiller[MAX_PLAYERS_ARRAY]; // internal
new bool:CS_IsFNAP[MAX_PLAYERS_ARRAY]; // arg1
new Float:CS_EffectRadius[MAX_PLAYERS_ARRAY]; // arg2
new Float:CS_DamagePerStack[MAX_PLAYERS_ARRAY]; // arg3
new Float:CS_DamageInterval[MAX_PLAYERS_ARRAY]; // arg4
new Float:CS_SpeedFactorPerStack[MAX_PLAYERS_ARRAY]; // arg5
new Float:CS_VulnerabilityPerStack[MAX_PLAYERS_ARRAY]; // arg6
new bool:CS_UberSaves[MAX_PLAYERS_ARRAY]; // arg7
new String:CS_Sound[MAX_SOUND_FILE_LENGTH]; // arg18

/**
 * Low Population Damage Buff
 */
#define LPDB_STRING "ff2_low_pop_damage_buff"
new LPDB_ActiveThisRound;
new LPDB_CanUse[MAX_PLAYERS_ARRAY];
new Float:LPDB_DamageMultiplier[MAX_PLAYERS_ARRAY]; // internal, no arguments are stored.

/**
 * METHODS REQUIRED BY ff2 subplugin
 */
PrintRageWarning()
{
	PrintToServer("*********************************************************************");
	PrintToServer("*                             WARNING                               *");
	PrintToServer("*       DEBUG_FORCE_RAGE in ff2_sarysamods8.sp is set to true!      *");
	PrintToServer("*  Any admin can use the 'rage' command to use rages in this pack!  *");
	PrintToServer("*  This is only for test servers. Disable this on your live server. *");
	PrintToServer("*********************************************************************");
}
 
#define CMD_FORCE_RAGE "rage"
public OnPluginStart2()
{
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	PrecacheSound(NOPE_AVI); // DO NOT DELETE IN FUTURE MOD PACKS
	for (new i = 0; i < MAX_PLAYERS_ARRAY; i++) // MAX_PLAYERS_ARRAY is correct here, this one time
		NULL_BLACKLIST[i] = false;
	
	if (DEBUG_FORCE_RAGE)
	{
		PrintRageWarning();
		RegAdminCmd(CMD_FORCE_RAGE, CmdForceRage, ADMFLAG_GENERIC);
	}
	
	RegisterForceTaunt();
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	RoundInProgress = true;
	
	// initialize variables
	PluginActiveThisRound = false;
	EM_ActiveThisRound = false;
	GH_ActiveThisRound = false;
	GH_GuitarIsKilling = false;
	MM_ActiveThisRound = false;
	MBW_ActiveThisRound = false;
	DS_ActiveThisRound = false;
	MF_ActiveThisRound = false;
	SR_ActiveThisRound = false;
	HC_ActiveThisRound = false;
	HP_ActiveThisRound = false;
	HCR_ActiveThisRound = false;
	HA_ActiveThisRound = false;
	HH_ActiveThisRound = false;
	FNAP_ActiveThisRound = false;
	PB_ActiveThisRound = false;
	PT_ActiveThisRound = false;
	SBV_ActiveThisRound = false;
	TA_ActiveThisRound = false;
	IT_ActiveThisRound = false;
	CS_ActiveThisRound = false;
	LPDB_ActiveThisRound = false;
	
	// initialize arrays
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		// all client inits
		EM_CanUse[clientIdx] = false;
		EM_MachineEntRef[clientIdx] = INVALID_ENTREF;
		EM_ParticleEntRef[clientIdx] = INVALID_ENTREF;
		GH_CanUse[clientIdx] = false;
		GH_IsUsing[clientIdx] = false;
		MM_CanUse[clientIdx] = false;
		MMM_IsMinion[clientIdx] = false;
		MMM_Blacklisted[clientIdx] = false;
		MBW_CanUse[clientIdx] = false;
		DS_CanUse[clientIdx] = false;
		DS_AffectedUntil[clientIdx] = FAR_FUTURE;
		DS_ParticleEntRef[clientIdx] = INVALID_ENTREF;
		MF_CanUse[clientIdx] = false;
		SR_SetSizeAt[clientIdx] = FAR_FUTURE;
		SR_RestoreSizeAt[clientIdx] = FAR_FUTURE;
		HC_CanUse[clientIdx] = false;
		HC_TouchEffectImmuneUntil[clientIdx] = 0.0;
		HP_CanUse[clientIdx] = false;
		HD_CanUse[clientIdx] = false;
		HCR_CanUse[clientIdx] = false;
		HA_CanUse[clientIdx] = false;
		HH_CanUse[clientIdx] = false;
		FNAP_CanUse[clientIdx] = false;
		PB_CanUse[clientIdx] = false;
		SBV_CanUse[clientIdx] = false;
		TA_CanUse[clientIdx] = false;
		IT_CanUse[clientIdx] = false;
		CS_VictimDamageAt[clientIdx] = FAR_FUTURE;
		CS_VictimDamage[clientIdx] = 0.0;
		CS_VictimSpeedFactor[clientIdx] = 1.0;
		CS_VictimVulnerability[clientIdx] = 1.0;
		CS_VictimKiller[clientIdx] = -1;
		CS_ExpectedSpeed[clientIdx] = 0.0;
		LPDB_CanUse[clientIdx] = false;

		// boss-only inits
		new bossIdx = IsLivingPlayer(clientIdx) ? FF2_GetBossIndex(clientIdx) : -1;
		if (bossIdx < 0)
			continue;

		if (FF2_HasAbility(bossIdx, this_plugin_name, EM_STRING))
		{
			PluginActiveThisRound = true;
			EM_ActiveThisRound = true;
			EM_CanUse[clientIdx] = true;
		
			EM_Duration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EM_STRING, 1);
			EM_Radius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EM_STRING, 2);
			EM_ImmunityClearance[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EM_STRING, 3);
			EM_MaxDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EM_STRING, 4);
			EM_DamageInterval[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EM_STRING, 5);
			EM_KnockAroundIntensity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EM_STRING, 6);
			EM_KnockAroundMinZ[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EM_STRING, 7);
			EM_KnockAroundChance[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EM_STRING, 8);
			EM_KnockAroundInterval[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EM_STRING, 9);
			EM_Gravity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EM_STRING, 10);
			EM_PlayerStrikeDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EM_STRING, 11);
			EM_PlayerStrikeKnockback[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EM_STRING, 12);
			EM_CollisionHeight[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EM_STRING, 13);
			EM_CollisionRadius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EM_STRING, 14);
			EM_Exponent[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EM_STRING, 15);
			EM_BuildingDamageModifier[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EM_STRING, 16);
			EM_Flags[clientIdx] = ReadHexOrDecString(bossIdx, EM_STRING, 19);
			
			if (FF2_HasAbility(bossIdx, this_plugin_name, EMA_STRING))
			{
				ReadSound(bossIdx, EMA_STRING, 1, EMA_AmbientSound);
				ReadSound(bossIdx, EMA_STRING, 2, EMA_CrashSound);
				ReadSound(bossIdx, EMA_STRING, 3, EMA_RageSound);
				ReadModel(bossIdx, EMA_STRING, 7, EMA_MachineModelFalling);
				ReadModel(bossIdx, EMA_STRING, 8, EMA_MachineModelOnGround);
				EMA_BeaconMaterial = ReadMaterialToInt(bossIdx, EMA_STRING, 9);
				EMA_BeaconLoopInterval = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EMA_STRING, 10);
				EMA_BeaconRadius = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EMA_STRING, 11);
				EMA_BeaconSpeedFactor = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EMA_STRING, 12);
				EMA_BeaconColor = ReadHexOrDecString(bossIdx, EMA_STRING, 13);
				EMA_BeaconZOffset = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EMA_STRING, 14);
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, EMA_STRING, 15, EMA_CrashEffect, MAX_EFFECT_NAME_LENGTH);
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, EMA_STRING, 16, EMA_PersistentEffect, MAX_EFFECT_NAME_LENGTH);
				ReadCenterText(bossIdx, EMA_STRING, 19, EMA_RageSpamMessage);
				
				BEACON_HALO = PrecacheModel("materials/sprites/halo01.vmt");
				
				// models are required
				if (strlen(EMA_MachineModelFalling) <= 3 || strlen(EMA_MachineModelOnGround) <= 3)
				{
					PrintToServer("[sarysamods8] ERROR: arg7 and arg8 are required for %s. Disabling rage.", EMA_STRING);
					EM_ActiveThisRound = false;
					EM_CanUse[clientIdx] = false;
				}
				
				if (EM_Exponent[clientIdx] == 0.0)
				{
					EM_Exponent[clientIdx] = 1.0;
					EM_Flags[clientIdx] &= ~EM_FLAG_EXPONENTIAL_DAMAGE;
				}
			}
			else
			{
				PrintToServer("[sarysamods8] ERROR: Boss has %s but not %s. Disabling rage.", EM_STRING, EMA_STRING);
				EM_ActiveThisRound = false;
				EM_CanUse[clientIdx] = false;
			}
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, GH_STRING))
		{
			PluginActiveThisRound = true;
			GH_ActiveThisRound = true;
			GH_CanUse[clientIdx] = true;
			
			GH_EffectDelay[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GH_STRING, 1);
			GH_Radius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GH_STRING, 2);
			GH_Damage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GH_STRING, 3);
			GH_Knockback[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GH_STRING, 4);
			GH_MinZ[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GH_STRING, 5);
			GH_MakeInvincible[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, GH_STRING, 6) == 1;
			GH_BuildingDamageFactor[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GH_STRING, 7);
			ReadCenterText(bossIdx, GH_STRING, 8, GH_ErrorMessage);
			GH_SoundRepeatCount[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, GH_STRING, 9);
			PrecacheSound(GH_GUITAR_SOUND);
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, MM_STRING))
		{
			PluginActiveThisRound = true;
			MM_ActiveThisRound = true;
			MM_CanUse[clientIdx] = true;
			MM_RefundRageAt[clientIdx] = FAR_FUTURE;
			MM_RevengeUntil[clientIdx] = FAR_FUTURE;
			MM_AttackNextFrame[clientIdx] = -1;
			MM_CurrentMinionChoice[clientIdx] = -1;
			MM_SpecialDown[clientIdx] = false;
			MM_NextHUDAt[clientIdx] = GetEngineTime();
			
			// precache, but don't keep around
			static String:modelFile[MAX_MODEL_FILE_LENGTH];
			ReadModel(bossIdx, MM_STRING, 1, modelFile);
			
			// stuff that actually gets stored...not much since it's a minion rage
			MM_MaxHP[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, MM_STRING, 7);
			MM_MinionNormalSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM_STRING, 8);
			MM_MinionHealedSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM_STRING, 9);
			MM_MinionUberedSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM_STRING, 10);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MM_STRING, 11, MM_MinionHealedEffect, MAX_EFFECT_NAME_LENGTH);
			MM_MinionRefundTime[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM_STRING, 12);
			MM_MinionRefundDelay[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM_STRING, 13);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MM_STRING, 14, MM_MinionSpawnEffect, MAX_EFFECT_NAME_LENGTH);
			MM_RevengeDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM_STRING, 15);
			static String:revengeCondStr[4*MM_MAX_REVENGE_CONDITIONS];
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MM_STRING, 16, revengeCondStr, sizeof(revengeCondStr));
			new String:revengeCondStrs[MM_MAX_REVENGE_CONDITIONS][4];
			ExplodeString(revengeCondStr, ";", revengeCondStrs, MM_MAX_REVENGE_CONDITIONS, 4);
			for (new i = 0; i < MM_MAX_REVENGE_CONDITIONS; i++)
				MM_RevengeConditions[clientIdx][i] = TFCond:StringToInt(revengeCondStrs[i]);
			ReadSound(bossIdx, MM_STRING, 17, MM_RevengeSound);
			MM_SpeedLinger[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM_STRING, 18);
		
			// flags
			MM_Flags = ReadHexOrDecString(bossIdx, MM_STRING, 19);

			if (FF2_HasAbility(bossIdx, this_plugin_name, MM2_STRING))
			{
				MM_BackstabMultiplier = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM2_STRING, 1);
				MM_ShieldHandling = FF2_GetAbilityArgument(bossIdx, this_plugin_name, MM2_STRING, 2);
				MM_MinionNormalVulnerability[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM2_STRING, 3);
				MM_MinionHealedVulnerability[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM2_STRING, 4);
				MM_MinionUberedVulnerability[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM2_STRING, 5);
				MM_RevengeBuildingMult[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM2_STRING, 6);
				ReadSound(bossIdx, MM2_STRING, 7, MM_MinionKillSound);
				ReadCenterText(bossIdx, MM2_STRING, 8, MM_ChoiceHUDMessage);
				MM_BossUberedVulnerability[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM2_STRING, 9);
			}
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, MBW_STRING))
		{
			PluginActiveThisRound = true;
			MBW_ActiveThisRound = true;
			MBW_CanUse[clientIdx] = true;
			MBW_LastSlotOrWeapon[clientIdx] = -1;

			static String:intStr[5*MBW_MAX_WEAPONS];
			static String:intStrs[MBW_MAX_WEAPONS][5];
			
			// slots or weapons
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MBW_STRING, 1, intStr, sizeof(intStr));
			ExplodeString(intStr, ";", intStrs, MBW_MAX_WEAPONS, 5);
			for (new i = 0; i < MBW_MAX_WEAPONS; i++)
				MBW_SlotsOrWeapons[clientIdx][i] = IsEmptyString(intStrs[i]) ? -1 : StringToInt(intStrs[i]);
				
			// ability index
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MBW_STRING, 2, intStr, sizeof(intStr));
			ExplodeString(intStr, ";", intStrs, MBW_MAX_WEAPONS, 5);
			for (new i = 0; i < MBW_MAX_WEAPONS; i++)
				MBW_AbilityIdx[clientIdx][i] = IsEmptyString(intStrs[i]) ? -1 : StringToInt(intStrs[i]);
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, DS_STRING))
		{
			PluginActiveThisRound = true;
			DS_ActiveThisRound = true;
			DS_CanUse[clientIdx] = true;
			
			DS_Radius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DS_STRING, 1);
			DS_Duration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DS_STRING, 2);
			DS_SpeedMultiplier[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DS_STRING, 3);
			DS_Damage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DS_STRING, 4);
			DS_AmmoDrain[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DS_STRING, 5);
			ReadSound(bossIdx, DS_STRING, 6, DS_RageSound);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DS_STRING, 7, DS_Effect, MAX_EFFECT_NAME_LENGTH);
			DS_SentryBulletDrain[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DS_STRING, 8);
			DS_SentryRocketDrain[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DS_STRING, 9);
		}

		if (FF2_HasAbility(bossIdx, this_plugin_name, MF_STRING))
		{
			PluginActiveThisRound = true;
			MF_ActiveThisRound = true;
			MF_CanUse[clientIdx] = true;
			
			MF_RemoveWearables[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, MF_STRING, 1) == 1;
			MF_UndoFreeUber[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, MF_STRING, 2) == 1;
			MF_UndoOvercharge[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, MF_STRING, 3) == 1;
			static String:medigunMessage[MAX_CENTER_TEXT_LENGTH];
			ReadCenterText(bossIdx, MF_STRING, 4, medigunMessage);
			if (!IsEmptyString(medigunMessage))
				PrintCenterText(clientIdx, medigunMessage);
			
			if (MF_RemoveWearables[clientIdx])
				MF_RemoveWearablesAt[clientIdx] = GetEngineTime() + 1.0;
			else
				MF_RemoveWearablesAt[clientIdx] = FAR_FUTURE;
			MF_LastMedigunLevel[clientIdx] = 0.0;
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, SR_STRING))
		{
			PluginActiveThisRound = true;
			SR_ActiveThisRound = true;
			
			SR_Radius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SR_STRING, 1);
			SR_Duration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SR_STRING, 2);
			SR_ScaleFactor[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SR_STRING, 3);
			SR_DurationVariance[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SR_STRING, 4);
			SR_ScaleVariance[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SR_STRING, 5);
			SR_SlayGracePeriod = FF2_GetAbilityArgument(bossIdx, this_plugin_name, SR_STRING, 6);
			SR_ScaleMode[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, SR_STRING, 7);
			ReadCenterText(bossIdx, SR_STRING, 8, SR_WarningMessage);
		}

		if (FF2_HasAbility(bossIdx, this_plugin_name, HC_STRING))
		{
			PluginActiveThisRound = true;
			HC_ActiveThisRound = true;
			HC_CanUse[clientIdx] = true;
			HC_Initialized[clientIdx] = false; // pending initialization after 0.3s timer
			HC_FPRetriesLeft[clientIdx] = 0;
			HC_NextFPRetryAt[clientIdx] = FAR_FUTURE;
			HC_PlayerCount = 1;
			HC_PendingPlayerCount = 1;
			HC_PendingHeads[clientIdx] = 0;
			HC_CurrentHeads[clientIdx] = 0;
			HC_NextResizeAttemptAt[clientIdx] = 0.0;
			HC_CheckDeadAt = FAR_FUTURE;
			HC_HeadMultiplierReduction[clientIdx] = 0.0;
			HC_RageDisabledResize[clientIdx] = false;
			HC_ForceReadjust[clientIdx] = false;
			HC_BallEntRef[clientIdx] = INVALID_ENTREF;
			
			HC_WeaponType[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, HC_STRING, 1);
			HC_HalfPowerAt[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HC_STRING, 2);
			HC_FullPowerAt[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HC_STRING, 3);
			HC_ParseTriplet(bossIdx, HC_STRING, 4, HC_HeightLandmarks[clientIdx]);
			HC_ParseTriplet(bossIdx, HC_STRING, 5, HC_PlayerDamageLandmarks[clientIdx]);
			HC_ParseTriplet(bossIdx, HC_STRING, 6, HC_BuildingDamageLandmarks[clientIdx]);
			HC_ParseTriplet(bossIdx, HC_STRING, 7, HC_KnockbackLandmarks[clientIdx]);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, HC_STRING, 8, HC_ResizeParticle, MAX_EFFECT_NAME_LENGTH);
			HC_PyroTeleportCooldownReduction[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HC_STRING, 9);

			// uber workaround
			HC_TouchEffectInterval[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HC_STRING, 12);
			HC_TouchEffectDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HC_STRING, 13);
			HC_TouchEffectUberDrain[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HC_STRING, 14);
			
			// weapon args are not preloaded, so lets skip to flags
			HC_Flags[clientIdx] = ReadHexOrDecString(bossIdx, HC_STRING, 19);

			if (FF2_HasAbility(bossIdx, this_plugin_name, HP_STRING))
			{
				HP_ActiveThisRound = true;
				HP_CanUse[clientIdx] = true;
				HP_LastPowerLevel[clientIdx] = -1.0; // ensure that it's updated asap
			
				HP_TeleportPower[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HP_STRING, 1);
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, HP_STRING, 2, HP_TeleportName, MAX_EFFECT_NAME_LENGTH);
				HP_SuperJumpPower[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HP_STRING, 3);
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, HP_STRING, 4, HP_SuperJumpName, MAX_EFFECT_NAME_LENGTH);
				HP_GlidePower[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HP_STRING, 5);
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, HP_STRING, 6, HP_GlideName, MAX_EFFECT_NAME_LENGTH);
			}

			if (FF2_HasAbility(bossIdx, this_plugin_name, HD_STRING))
			{
				HD_CanUse[clientIdx] = true;
				
				HD_DrainWithMax[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HD_STRING, 1);
				HD_DrainWithMin[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HD_STRING, 2);
			}
			
			if (FF2_HasAbility(bossIdx, this_plugin_name, HCR_STRING))
			{
				HCR_ActiveThisRound = true;
				HCR_CanUse[clientIdx] = true;

				HCR_MinPowerLevel[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HCR_STRING, 1);
				HCR_HideFF2HUD[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, HCR_STRING, 2) == 1;
				HCR_HideDDHUD[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, HCR_STRING, 3) == 1;
				HCR_RageOnGround[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, HCR_STRING, 4) == 1;
			}
			
			if (FF2_HasAbility(bossIdx, this_plugin_name, HA_STRING))
			{
				HA_ActiveThisRound = true;
				HA_CanUse[clientIdx] = true;
				HA_RageStartedAt[clientIdx] = FAR_FUTURE;
				HA_ReenableRageAt[clientIdx] = FAR_FUTURE;
				HA_AttachmentEntRef[clientIdx] = INVALID_ENTREF;
				HA_PostRageCooldownUntil[clientIdx] = 0.0;
				
				// reuse existing triplet parsing code
				HC_ParseTriplet(bossIdx, HA_STRING, 1, HA_DamageLandmarks[clientIdx]);
				HC_ParseTriplet(bossIdx, HA_STRING, 2, HA_DamageMultLandmarks[clientIdx]);
				HC_ParseTriplet(bossIdx, HA_STRING, 3, HA_RadiusLandmarks[clientIdx]);
				HC_ParseTriplet(bossIdx, HA_STRING, 4, HA_CastTimeLandmarks[clientIdx]);
				HC_ParseTriplet(bossIdx, HA_STRING, 5, HA_RecoveryLandmarks[clientIdx]);
				HA_AnemiaBonusAt[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HA_STRING, 6);
				HA_SharedStunBonusAt[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HA_STRING, 7);
				HA_MedigunDrainBonusAt[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HA_STRING, 8);
				HA_HeadPowerRemovalFactor[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HA_STRING, 9);
				ReadModel(bossIdx, HA_STRING, 10, HA_Model);
				HA_ToNormalSizeFactor[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HA_STRING, 11);
				HA_ToMaxSizeFactor[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HA_STRING, 12);
				HA_ModelRadius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HA_STRING, 13);
				HA_MaxResizeFactor[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HA_STRING, 14);
				ReadSound(bossIdx, HA_STRING, 15, HA_FirstSound);
				ReadSound(bossIdx, HA_STRING, 16, HA_SecondSound);
				ReadSound(bossIdx, HA_STRING, 17, HA_ThirdSound);
				ReadSound(bossIdx, HA_STRING, 18, HA_FourthSound);
				
				HA_Flags[clientIdx] = ReadHexOrDecString(bossIdx, HA_STRING, 19);
				
				if (FF2_HasAbility(bossIdx, this_plugin_name, HA2_STRING))
				{
					HA_MaxFogColor[clientIdx] = ReadHexOrDecString(bossIdx, HA2_STRING, 1);
					FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, HA2_STRING, 2, HA_AttachmentName, MAX_ATTACHMENT_NAME_LENGTH);
					FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, HA2_STRING, 3, HA_AnemiaName, MAX_TERMINOLOGY_LENGTH);
					FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, HA2_STRING, 4, HA_SharedStunName, MAX_TERMINOLOGY_LENGTH);
					FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, HA2_STRING, 5, HA_MedigunDrainName, MAX_TERMINOLOGY_LENGTH);
					HA_CooldownDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HA2_STRING, 6);
				}
				
				// ensure there's a model
				if (strlen(HA_Model) <= 3)
				{
					PrintToServer("[sarysamods8] ERROR: %s needs a model! Disabling rage.", HA_STRING);
					HA_ActiveThisRound = false;
					HA_CanUse[clientIdx] = false;
				}
			}
			
			if (FF2_HasAbility(bossIdx, this_plugin_name, HH_STRING))
			{
				HH_ActiveThisRound = true;
				HH_CanUse[clientIdx] = true;
				HH_UpdateAt[clientIdx] = GetEngineTime();
				
				HH_NaturalHudX[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HH_STRING, 1);
				HH_NaturalHudY[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HH_STRING, 2);
				HH_NaturalHudColor[clientIdx] = ReadHexOrDecString(bossIdx, HH_STRING, 3);
				ReadCenterText(bossIdx, HH_STRING, 4, HH_NaturalHudMessage);
				HH_RageHudY[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HH_STRING, 5);
				HH_RageHudColor[clientIdx] = ReadHexOrDecString(bossIdx, HH_STRING, 6);
				ReadCenterText(bossIdx, HH_STRING, 7, HH_RageHudDOTMessage);
				ReadCenterText(bossIdx, HH_STRING, 8, HH_RageHudNotReady);
				ReadCenterText(bossIdx, HH_STRING, 9, HH_RageHudReady);
				ReadCenterText(bossIdx, HH_STRING, 10, HH_RageHudStats);
			}
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, FNAP_STRING))
		{
			PluginActiveThisRound = true;
			FNAP_ActiveThisRound = true;
			FNAP_CanUse[clientIdx] = true;
			FNAP_ActualRage[clientIdx] = 0.0;
			FNAP_CurrentLife[clientIdx] = 0;
			FNAP_UpdateHUDAt[clientIdx] = GetEngineTime();
			FNAP_SpeedOverride[clientIdx] = 0.0;

			FNAP_ReadInts(bossIdx, FNAP_STRING, 1, FNAP_IsSuperJump);
			FNAP_ReadStrings(bossIdx, FNAP_STRING, 2, FNAP_Rages, MAX_ABILITY_NAME_LENGTH);
			FNAP_ReadFloats(bossIdx, FNAP_STRING, 3, FNAP_RageDamage);
			FNAP_ReadFloats(bossIdx, FNAP_STRING, 4, FNAP_Speed);
			FNAP_ReadStrings(bossIdx, FNAP_STRING, 5, FNAP_Overlays, MAX_MATERIAL_FILE_LENGTH);
			FNAP_ReadStrings(bossIdx, FNAP_STRING, 6, FNAP_Models, MAX_MODEL_FILE_LENGTH);
			FNAP_DescHudY[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FNAP_STRING, 7);
			for (new i = 0; i < FNAP_COUNT; i++) // read in arg8-arg13
				ReadCenterText(bossIdx, FNAP_STRING, i+8, FNAP_DescHuds[i]);
			FNAP_OverlayDuration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FNAP_STRING, 14);
			ReadSound(bossIdx, FNAP_STRING, 15, FNAP_DeathSound);
			FNAP_HudY[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FNAP_STRING, 16);
			ReadCenterText(bossIdx, FNAP_STRING, 17, FNAP_NotReadyStr);
			ReadCenterText(bossIdx, FNAP_STRING, 18, FNAP_ReadyStr);
			FNAP_RageReductionPerLife[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FNAP_STRING, 19);
			
			if (FF2_HasAbility(bossIdx, this_plugin_name, FNAP2_STRING))
			{
				FNAP_ReadStrings(bossIdx, FNAP2_STRING, 1, FNAP_WeaponNames, MAX_WEAPON_NAME_LENGTH);
				FNAP_ReadInts(bossIdx, FNAP2_STRING, 2, FNAP_WeaponIndexes);
				FNAP_ReadInts(bossIdx, FNAP2_STRING, 3, FNAP_WeaponVisibilities);
				for (new i = 0; i < FNAP_COUNT; i++) // read in arg8-arg13
					FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, FNAP2_STRING, 4+i, FNAP_WeaponArgs[i], MAX_WEAPON_ARG_LENGTH);
				FNAP_ReadFloats(bossIdx, FNAP2_STRING, 10, FNAP_SentryStunRadius);
				FNAP_ReadFloats(bossIdx, FNAP2_STRING, 11, FNAP_SentryStunDuration);
				FNAP_PinkieTeleportDefault[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, FNAP2_STRING, 12);
				FNAP_TimeHudDuration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FNAP2_STRING, 13);
				FNAP_TimeHudX = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FNAP2_STRING, 14);
				FNAP_TimeHudY = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FNAP2_STRING, 15);
				ReadCenterText(bossIdx, FNAP2_STRING, 16, FNAP_TimeHudMessage);
				
				FNAP_ShowTimeHUDUntil = GetEngineTime() + FNAP_TimeHudDuration;
			}
			
			for (new i = 0; i < FNAP_COUNT; i++)
			{
				if (strlen(FNAP_Models[i]) > 3)
					PrecacheModel(FNAP_Models[i]);
					
				if (FNAP_RageDamage[i] <= 0.0)
					FNAP_RageDamage[i] = 2000.0;
			}
			
			// need to grab the preset teleport stats, as some rages will corrupt them
			static String:DT_STRING[20] = "dynamic_teleport";
			static String:DYNAMIC_DEFAULTS[25] = "ff2_dynamic_defaults";
			if (FF2_HasAbility(bossIdx, DYNAMIC_DEFAULTS, DT_STRING))
			{
				if (PRINT_DEBUG_INFO)
					PrintToServer("[sarysamods8] Loading default teleport options for FNAP.");
				FNAP_TeleportChargeTime[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, DYNAMIC_DEFAULTS, DT_STRING, 1);
				FNAP_TeleportCooldown[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, DYNAMIC_DEFAULTS, DT_STRING, 2);
				FNAP_TeleportStun[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, DYNAMIC_DEFAULTS, DT_STRING, 10);
			}
		}

		if (FF2_HasAbility(bossIdx, this_plugin_name, PB_STRING))
		{
			PluginActiveThisRound = true;
			PB_ActiveThisRound = true;
			PB_CanUse[clientIdx] = true;
				
			PB_IsFNAP[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PB_STRING, 1) == 1;
			ReadModel(bossIdx, PB_STRING, 2, PB_Model);
			static String:condStr[MAX_CONDITIONS * 4];
			static String:condStrs[MAX_CONDITIONS][4];
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, PB_STRING, 3, condStr, sizeof(condStr));
			ExplodeString(condStr, ";", condStrs, MAX_CONDITIONS, 4);
			PB_NumConditions[clientIdx] = 0;
			for (new i = 0; i < MAX_CONDITIONS; i++)
			{
				PB_PossibleConditions[clientIdx][i] = StringToInt(condStrs[i]);
				if (PB_PossibleConditions[clientIdx][i] > 0)
					PB_NumConditions[clientIdx]++;
				PB_RemoveConditionAt[clientIdx][i] = FAR_FUTURE;
			}
			PB_MinConditions[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PB_STRING, 4);
			PB_MaxConditions[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PB_STRING, 5);
			PB_Duration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PB_STRING, 6);
			PB_ObjRadius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PB_STRING, 7);
			PB_ObjHeight[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PB_STRING, 8);
			PB_MaxXYVelocity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PB_STRING, 9);
			PB_ActivationDelay[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PB_STRING, 10);
			PB_MinToSpawn[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PB_STRING, 11);
			PB_MaxToSpawn[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PB_STRING, 12);
			ReadSound(bossIdx, PB_STRING, 18, PB_Sound);
			
			// sanity
			if (PB_MaxConditions[clientIdx] > PB_NumConditions[clientIdx])
			{
				PrintToServer("[sarysamods8] WARNING: Number of conditions fewer than max conditions. Reducing.");
				PB_MaxConditions[clientIdx] = PB_NumConditions[clientIdx];
			}
		}

		if (FF2_HasAbility(bossIdx, this_plugin_name, PT_STRING))
		{
			PluginActiveThisRound = true;
			PT_ActiveThisRound = true;
			PT_DispensersAreHarmful = false;
				
			PT_IsFNAP[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PT_STRING, 1) == 1;
			PT_Duration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PT_STRING, 2);
			PT_TrapCount[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PT_STRING, 3);
			PT_TrapHealthNerfAmount[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PT_STRING, 4);
			PT_TrapAmmoNerfAmount[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PT_STRING, 5);
			PT_TrappedObjectRecolor[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, PT_STRING, 6);
			PT_DispenserHarmDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PT_STRING, 7);
			PT_DispenserHarmDamage = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PT_STRING, 8);
			PT_DispenserHarmInterval = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, PT_STRING, 9);
			ReadSound(bossIdx, PT_STRING, 18, PT_Sound);
			
			PTT_TrapsNeverExpire = (PT_Duration[clientIdx] <= 0.0);
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, SBV_STRING))
		{
			PluginActiveThisRound = true;
			SBV_ActiveThisRound = true;
			SBV_CanUse[clientIdx] = true;
			SBV_RecalculateAt[clientIdx] = GetEngineTime();
			SBV_LastSpeed[clientIdx] = 340.0; // very temporary...
			SBV_RageUntil[clientIdx] = 0.0;
			
			SBV_IsFNAP = FF2_GetAbilityArgument(bossIdx, this_plugin_name, SBV_STRING, 1) == 1;
			SBV_Duration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SBV_STRING, 2);
			SBV_MaxPlayers[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, SBV_STRING, 3);
			SBV_MinSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SBV_STRING, 4);
			SBV_MaxSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SBV_STRING, 5);
			SBV_MaxAnglePitch[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SBV_STRING, 6);
			SBV_MaxAngleYaw[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SBV_STRING, 7);
			SBV_Interval[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SBV_STRING, 8);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SBV_STRING, 9, SBV_Overlay, MAX_MATERIAL_FILE_LENGTH);
			ReadSound(bossIdx, SBV_STRING, 18, SBV_Sound);
		}

		if (FF2_HasAbility(bossIdx, this_plugin_name, TA_STRING))
		{
			PluginActiveThisRound = true;
			TA_ActiveThisRound = true;
			TA_CanUse[clientIdx] = true;
			TA_InvincibilityEndsAt[clientIdx] = FAR_FUTURE;
			TA_DamageAt[clientIdx] = FAR_FUTURE;
			TA_RemoveOrbAt[clientIdx] = FAR_FUTURE;
			TA_OrbEntRef[clientIdx] = INVALID_ENTREF;
			
			TA_IsFNAP[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, TA_STRING, 1) == 1;
			TA_InvincibilityDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, TA_STRING, 2);
			TA_DamageDelay[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, TA_STRING, 3);
			TA_ShouldImmobilize[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, TA_STRING, 4) == 1;
			TA_AttractionRadius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, TA_STRING, 5);
			TA_MinAttraction[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, TA_STRING, 6);
			TA_MaxAttraction[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, TA_STRING, 7);
			TA_DamageRadius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, TA_STRING, 8);
			TA_BaseDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, TA_STRING, 9);
			TA_DamageFalloffExp[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, TA_STRING, 10);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, TA_STRING, 11, TA_DamageEffect, MAX_EFFECT_NAME_LENGTH);
			ReadSound(bossIdx, TA_STRING, 18, TA_Sound);
		}

		if (FF2_HasAbility(bossIdx, this_plugin_name, IT_STRING))
		{
			PluginActiveThisRound = true;
			IT_ActiveThisRound = true;
			IT_CanUse[clientIdx] = true;
			IT_ButtonDown[clientIdx] = false;
			IT_CurrentlyTeleport[clientIdx] = false;
			
			IT_IsFNAP[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, IT_STRING, 1) == 1;
			IT_TeleportPerRage[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, IT_STRING, 2);
			IT_TeleportStun[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, IT_STRING, 3);
			IT_TeleportCooldown[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, IT_STRING, 4);
			IT_TeleportChargeTime[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, IT_STRING, 5);
			IT_TeleportUsesSpecial[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, IT_STRING, 6) == 1;
			ReadSound(bossIdx, IT_STRING, 18, IT_Sound);
		}

		if (FF2_HasAbility(bossIdx, this_plugin_name, CS_STRING))
		{
			PluginActiveThisRound = true;
			CS_ActiveThisRound = true;
			
			CS_IsFNAP[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CS_STRING, 1) == 1;
			CS_EffectRadius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CS_STRING, 2);
			CS_DamagePerStack[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CS_STRING, 3);
			CS_DamageInterval[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CS_STRING, 4);
			CS_SpeedFactorPerStack[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CS_STRING, 5);
			CS_VulnerabilityPerStack[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CS_STRING, 6);
			CS_UberSaves[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CS_STRING, 7) == 1;
			ReadSound(bossIdx, CS_STRING, 18, CS_Sound);
		}

		if (FF2_HasAbility(bossIdx, this_plugin_name, LPDB_STRING))
		{
			PluginActiveThisRound = true;
			new Float:pop1Multiplier = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, LPDB_STRING, 1);
			new noBuffPop = FF2_GetAbilityArgument(bossIdx, this_plugin_name, LPDB_STRING, 2);
			
			if (noBuffPop > 1)
			{
				new livingCount = 0;
				
				// get living population
				for (new living = 1; living < MAX_PLAYERS; living++)
				{
					if (IsLivingPlayer(living) && GetClientTeam(living) == MercTeam)
						livingCount++;
				}
				
				if (livingCount > 0 && livingCount < noBuffPop)
				{
					LPDB_ActiveThisRound = true;
					LPDB_CanUse[clientIdx] = true;
					LPDB_DamageMultiplier[clientIdx] = pop1Multiplier - ((pop1Multiplier - 1.0) * float(livingCount - 1) / float(noBuffPop - 1));
				}
			}
		}
	}
	
	if (GH_ActiveThisRound)
	{
		HookEvent("player_death", GH_PlayerDeath, EventHookMode_Pre);
	}
	
	if (MM_ActiveThisRound)
	{
		AddCommandListener(MM_CheckSuicide, "kill");
		AddCommandListener(MM_CheckSuicide, "explode");

		for (new i = 1; i < MAX_PLAYERS; i++)
		{
			if (MM_ShieldHandling != MM_SHIELD_NONE && IsClientInGame(i))
				SDKHook(i, SDKHook_OnTakeDamage, MM_ShieldCheck);
			MMM_DamageHooked[i] = false;
			MM_BackstabPendingAgainst[i] = -1;
			
			if (MM_CanUse[i])
				SDKHook(i, SDKHook_OnTakeDamage, MM_BossIncomingDamage);
		}
	}
	
	if (FNAP_ActiveThisRound)
	{
		HookEvent("player_death", FNAP_PlayerDeath, EventHookMode_Pre);

		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (FNAP_CanUse[clientIdx] && IsClientInGame(clientIdx))
			{
				SDKHook(clientIdx, SDKHook_PreThink, FNAP_PreThink);
			}
		}
	}
	
	if (PB_ActiveThisRound)
	{
		for (new i = 0; i < MAX_PROPS; i++)
			PBP_EntRef[i] = INVALID_ENTREF;
	}
	
	if (PT_ActiveThisRound)
	{
		for (new i = 0; i < MAX_TRAPS; i++)
			PTT_EntRef[i] = INVALID_ENTREF;
			
		HookEntityOutput("item_healthkit_small", "OnPlayerTouch", PT_ItemPickup);
		HookEntityOutput("item_healthkit_medium", "OnPlayerTouch", PT_ItemPickup);
		HookEntityOutput("item_healthkit_large", "OnPlayerTouch", PT_ItemPickup);
		HookEntityOutput("item_ammopack_small", "OnPlayerTouch", PT_ItemPickup);
	}
	
	if (TA_ActiveThisRound)
	{
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
				SDKHook(clientIdx, SDKHook_OnTakeDamage, TA_OnTakeDamage);
		}
	}
	
	if (SBV_ActiveThisRound)
	{
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (SBV_CanUse[clientIdx] && IsClientInGame(clientIdx) && !SBV_IsFNAP)
				SDKHook(clientIdx, SDKHook_PreThink, SBV_PreThink);
		}
	}
	
	if (CS_ActiveThisRound)
	{
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
				SDKHook(clientIdx, SDKHook_OnTakeDamage, CS_OnTakeDamage);
		}
	}

	if (LPDB_ActiveThisRound)
	{
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
				SDKHook(clientIdx, SDKHook_OnTakeDamage, LPDB_OnTakeDamage);
		}
	}
	
	CreateTimer(0.3, Timer_PostRoundStartInits, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_PostRoundStartInits(Handle:timer)
{
	// hale suicided
	if (!RoundInProgress)
		return Plugin_Handled;
	
	// initialize head collection
	if (HC_ActiveThisRound)
		HC_Initialize();

	// finish initialization of stuff
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (HCR_CanUse[clientIdx] && IsLivingPlayer(clientIdx))
		{
			if (HCR_HideFF2HUD[clientIdx])
			{
				FF2_SetFF2flags(clientIdx, FF2_GetFF2flags(clientIdx) | FF2FLAG_HUDDISABLED);
				if (!HCR_HideDDHUD[clientIdx])
					DD_SetForceHUDEnabled(clientIdx, true);
			}
		}

		if (HA_CanUse[clientIdx] && IsLivingPlayer(clientIdx))
		{
			HA_Initialize(clientIdx);
		}

		if (FNAP_CanUse[clientIdx])
		{
			FNAP_UpdateWeapon(clientIdx);
			FF2_SetFF2flags(clientIdx, FF2_GetFF2flags(clientIdx) | FF2FLAG_HUDDISABLED);
			DD_SetForceHUDEnabled(clientIdx, true);
		}
	}

	return Plugin_Handled;
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	RoundInProgress = false;
	
	if (EM_ActiveThisRound)
	{
		EM_ActiveThisRound = false;
		
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (EM_MachineEntRef[clientIdx] != INVALID_ENTREF)
			{
				RemoveEntity(INVALID_HANDLE, EM_MachineEntRef[clientIdx]);
				EM_MachineEntRef[clientIdx] = INVALID_ENTREF;
			}

			if (EM_ParticleEntRef[clientIdx] != INVALID_ENTREF)
			{
				RemoveEntity(INVALID_HANDLE, EM_ParticleEntRef[clientIdx]);
				EM_ParticleEntRef[clientIdx] = INVALID_ENTREF;
			}
		}
	}
	
	if (GH_ActiveThisRound)
	{
		GH_ActiveThisRound = false;
		
		UnhookEvent("player_death", GH_PlayerDeath, EventHookMode_Pre);
		
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (GH_CanUse[clientIdx] && IsLivingPlayer(clientIdx))
				SetEntityMoveType(clientIdx, MOVETYPE_WALK);
		}
	}
	
	if (HC_ActiveThisRound)
	{
		HC_ActiveThisRound = false;
		
		HC_Cleanup();
	}
	
	if (HCR_ActiveThisRound)
	{
		HCR_ActiveThisRound = false;
	
		// remove lingering huddisabled flag, which WILL leak between rounds otherwise
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (HCR_CanUse[clientIdx] && IsClientInGame(clientIdx))
				FF2_SetFF2flags(clientIdx, FF2_GetFF2flags(clientIdx) & (~FF2FLAG_HUDDISABLED));
		}
	}
	
	if (HA_ActiveThisRound)
	{
		HA_ActiveThisRound = false;
		
		// remove lingering ball...which would be kind of amusing if it stayed around, regardless...
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (!HC_CanUse[clientIdx])
				continue;
				
			if (HC_BallEntRef[clientIdx] != INVALID_ENTREF)
				RemoveEntity(INVALID_HANDLE, HC_BallEntRef[clientIdx]);
			HC_BallEntRef[clientIdx] = INVALID_ENTREF;
		}
	}
	
	if (MM_ActiveThisRound)
	{
		MM_ActiveThisRound = false;

		RemoveCommandListener(MM_CheckSuicide, "kill");
		RemoveCommandListener(MM_CheckSuicide, "explode");
		
		for (new minion = 1; minion < MAX_PLAYERS; minion++)
		{
			if (!IsClientInGame(minion))
				continue;
				
			if (MM_ShieldHandling != MM_SHIELD_NONE)
				SDKUnhook(minion, SDKHook_OnTakeDamage, MM_ShieldCheck);
			
			if (MMM_IsMinion[minion])
				MM_OnMinionDeath(minion);

			if (MMM_DamageHooked[minion])
			{
				SDKUnhook(minion, SDKHook_OnTakeDamage, MM_MinionIncomingDamage);
				MMM_DamageHooked[minion] = false;
			}
			
			SDKUnhook(minion, SDKHook_OnTakeDamage, MM_BossIncomingDamage);
		}
	}
	
	if (DS_ActiveThisRound)
	{
		DS_ActiveThisRound = false;

		for (new victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (DS_ParticleEntRef[victim] != INVALID_ENTREF)
			{
				RemoveEntity(INVALID_HANDLE, DS_ParticleEntRef[victim]);
				DS_ParticleEntRef[victim] = INVALID_ENTREF;
			}
		}
	}

	if (FNAP_ActiveThisRound)
	{
		FNAP_ActiveThisRound = false;
		UnhookEvent("player_death", FNAP_PlayerDeath, EventHookMode_Pre);
		
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (FNAP_CanUse[clientIdx] && IsClientInGame(clientIdx))
			{
				SDKUnhook(clientIdx, SDKHook_PreThink, FNAP_PreThink);
				FF2_SetFF2flags(clientIdx, FF2_GetFF2flags(clientIdx) & (~FF2FLAG_HUDDISABLED));
			}
		}
	}
	
	if (PT_ActiveThisRound)
	{
		PT_ActiveThisRound = false;
		UnhookEntityOutput("item_healthkit_small", "OnPlayerTouch", PT_ItemPickup);
		UnhookEntityOutput("item_healthkit_medium", "OnPlayerTouch", PT_ItemPickup);
		UnhookEntityOutput("item_healthkit_large", "OnPlayerTouch", PT_ItemPickup);
		UnhookEntityOutput("item_ammopack_small", "OnPlayerTouch", PT_ItemPickup);
	}
	
	if (SBV_ActiveThisRound)
	{
		SBV_ActiveThisRound = false;
		SBV_RemoveOverlayForAll();
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (SBV_CanUse[clientIdx] && IsClientInGame(clientIdx))
				SDKUnhook(clientIdx, SDKHook_PreThink, SBV_PreThink);
		}
	}
	
	if (TA_ActiveThisRound)
	{
		TA_ActiveThisRound = false;

		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (TA_CanUse[clientIdx] && IsLivingPlayer(clientIdx))
				SetEntityMoveType(clientIdx, MOVETYPE_WALK);

			if (IsClientInGame(clientIdx))
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, TA_OnTakeDamage);
		}
	}

	if (CS_ActiveThisRound)
	{
		CS_ActiveThisRound = false;
		
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, CS_OnTakeDamage);
		}
	}

	if (LPDB_ActiveThisRound)
	{
		LPDB_ActiveThisRound = false;
		
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, LPDB_OnTakeDamage);
		}
	}
	
	PluginActiveThisRound = false;
}

public Action:FF2_OnAbility2(bossIdx, const String:plugin_name[], const String:ability_name[], status)
{
	if (strcmp(plugin_name, this_plugin_name) != 0)
		return Plugin_Continue;
	else if (!RoundInProgress) // don't execute these rages with 0 players alive
		return Plugin_Continue;
		
	if (!strcmp(ability_name, EM_STRING))
	{
		if (!Rage_EarthquakeMachine(ability_name, bossIdx))
			return Plugin_Stop;
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods8] Initiating Earthquake Machine");
	}
	else if (!strcmp(ability_name, MM_STRING))
	{
		Rage_MedicMinion(bossIdx);
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods8] Initiating Medic Minion");
	}
	else if (!strcmp(ability_name, SR_STRING))
	{
		Rage_SafeResize(bossIdx);
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods8] Initiating Safe Resize");
	}
	else if (!strcmp(ability_name, HA_STRING))
	{
		Rage_HeadAnnihilation(GetClientOfUserId(FF2_GetBossUserId(bossIdx)));
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods8] Initiating Head Annihilation");
	}
	else if (!strcmp(ability_name, FNAP_STRING))
	{
		Rage_FNAPRages(GetClientOfUserId(FF2_GetBossUserId(bossIdx)));
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods8] FNAP Rages...user must have lost a life.");
	}
	else if (!strcmp(ability_name, PB_STRING))
		Rage_PropBuff(GetClientOfUserId(FF2_GetBossUserId(bossIdx)));
	else if (!strcmp(ability_name, PT_STRING))
		Rage_PickupTrap(GetClientOfUserId(FF2_GetBossUserId(bossIdx)));
	else if (!strcmp(ability_name, SBV_STRING))
		Rage_SpeedByViews(GetClientOfUserId(FF2_GetBossUserId(bossIdx)));
	else if (!strcmp(ability_name, TA_STRING))
		Rage_TwistedAttraction(GetClientOfUserId(FF2_GetBossUserId(bossIdx)));
	else if (!strcmp(ability_name, IT_STRING))
		Rage_InstantTeleports(GetClientOfUserId(FF2_GetBossUserId(bossIdx)));
	else if (!strcmp(ability_name, CS_STRING))
		Rage_CrippleStacks(GetClientOfUserId(FF2_GetBossUserId(bossIdx)));
	else if (!strcmp(ability_name, FNAP2_STRING))
		Rage_FNAPSentryStun(GetClientOfUserId(FF2_GetBossUserId(bossIdx)));

	return Plugin_Continue;
}

/**
 * Debug Only!
 */
public Action:CmdForceRage(user, argsInt)
{
	// get actual args
	new String:unparsedArgs[ARG_LENGTH];
	GetCmdArgString(unparsedArgs, ARG_LENGTH);
	
	// gotta do this
	PrintRageWarning();
	
	if (!strcmp("guitar", unparsedArgs))
	{
		PrintToConsole(user, "Will trigger guitar hero.");
		OnDOTAbilityActivated(GetClientOfUserId(FF2_GetBossUserId(0)));
		
		return Plugin_Handled;
	}
	else if (StrContains(unparsedArgs, "ddtest") == 0)
	{
		new clientIdx = GetClientOfUserId(FF2_GetBossUserId(0));
	
		if (unparsedArgs[6] == '0')
			DD_SetDisabled(clientIdx, true, false, false);
		else if (unparsedArgs[6] == '1')
			DJ_SetUsesRemaining(clientIdx, 3);
		else if (unparsedArgs[6] == '2')
			DJ_CooldownUntil(clientIdx, GetEngineTime() + 20.0);
		else if (unparsedArgs[6] == '3')
			DJ_ChangeFundamentalStats(clientIdx, 3.0, 2.0, 1.5);
		else if (unparsedArgs[6] == '4')
			DT_SetUsesRemaining(clientIdx, 2);
		else if (unparsedArgs[6] == '5')
			DT_CooldownUntil(clientIdx, FAR_FUTURE);
		else if (unparsedArgs[6] == '6')
			DT_ChangeFundamentalStats(clientIdx, 1.0, 10.0, 10.0);
		else if (unparsedArgs[6] == '7')
			DW_SetUsesRemaining(clientIdx, 5);
		else if (unparsedArgs[6] == '8')
			DW_CooldownUntil(clientIdx, GetEngineTime() + 5.0);
		else if (unparsedArgs[6] == '9')
			DW_SetDefaultGravity(clientIdx, 0.5);
		else
		{
			PrintToConsole(user, "DD_PerformTeleport(%d, %f, %d, %d, %d, %d)", clientIdx, 3.0, true, false, unparsedArgs[6] % 4 > 1, unparsedArgs[6] % 2 == 1);
			DD_PerformTeleport(clientIdx, 3.0, true, false, unparsedArgs[6] % 4 > 1, unparsedArgs[6] % 2 == 1);
		}
			
		PrintToConsole(user, "Performed dynamic test %d", unparsedArgs[6] - '0');
			
		return Plugin_Handled;
	}
	else if (StrContains(unparsedArgs, "headtest") == 0)
	{
		new clientIdx = GetClientOfUserId(FF2_GetBossUserId(0));
		
		new randomRed = FindRandomPlayer(false);
		if (randomRed != -1)
		{
			SDKHooks_TakeDamage(randomRed, clientIdx, clientIdx, 9999.0, DMG_GENERIC, -1);
			PrintToConsole(user, "Player %d killed, unless they're uber.", randomRed);
		}
			
		return Plugin_Handled;
	}
	else if (StrContains(unparsedArgs, "loveme") == 0)
	{
		DS_OnActivation(GetClientOfUserId(FF2_GetBossUserId(0)));
		PrintToConsole(user, "Activated DOT Stare");
		return Plugin_Handled;
	}
	else if (StrContains(unparsedArgs, "sadasdasd") == 0)
	{
		DT_SetTargetTeam(0, false);
		DT_SetIsReverse(0, false);
	}
	else if (StrContains(unparsedArgs, "fnap") == 0)
	{
		Rage_PropBuff(GetClientOfUserId(FF2_GetBossUserId(0)));
		Rage_PickupTrap(GetClientOfUserId(FF2_GetBossUserId(0)));
		Rage_SpeedByViews(GetClientOfUserId(FF2_GetBossUserId(0)));
		Rage_TwistedAttraction(GetClientOfUserId(FF2_GetBossUserId(0)));
		Rage_InstantTeleports(GetClientOfUserId(FF2_GetBossUserId(0)));
		Rage_CrippleStacks(GetClientOfUserId(FF2_GetBossUserId(0)));
	}
	
	PrintToServer("[sarysamods8] Rage not found: %s", unparsedArgs);
	return Plugin_Continue;
}

/**
 * DOTs
 */
DOTPostRoundStartInit()
{
	if (!RoundInProgress)
	{
		PrintToServer("DOTPostRoundStartInit() called when the round is over?! Shouldn't be possible!");
		return;
	}
	
	// nothing to do
}
 
OnDOTAbilityActivated(clientIdx)
{
	if (!PluginActiveThisRound)
		return;

	if (GH_CanUse[clientIdx])
	{
		new bool:willWork = true;
		
		if ((GetEntityFlags(clientIdx) & FL_ONGROUND) == 0)
			willWork = false;
		else if (GetEntityFlags(clientIdx) & (FL_INWATER | FL_SWIM))
			willWork = false;
		else if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed) || TF2_IsPlayerInCondition(clientIdx, TFCond_Taunting))
			willWork = false;
			
		if (!willWork)
		{
			PrintCenterText(clientIdx, GH_ErrorMessage);
			PrintToChat(clientIdx, GH_ErrorMessage);
			Nope(clientIdx);
			CancelDOTAbilityActivation(clientIdx);
			return;
		}
		
		ForceUserToShred(clientIdx);
		
		// rare...but this will surely happen once or twice
		if (!TF2_IsPlayerInCondition(clientIdx, TFCond_Taunting))
		{
			PrintCenterText(clientIdx, "Error initiating taunt. Signatures need to be updated.\nPlease note this on the forums.");
			PrintToServer("[sarysamods8] ERROR: Taunt failed to activate. Please update FlaminSarge's signatures.");
//			Nope(clientIdx);
//			CancelDOTAbilityActivation(clientIdx);
//			return;
		}
		
		// must add megaheal no matter what
		GH_EffectsAt[clientIdx] = GetEngineTime() + GH_EffectDelay[clientIdx];
		GH_IsUsing[clientIdx] = true;
		TF2_AddCondition(clientIdx, TFCond_MegaHeal, -1.0);
		SetEntityMoveType(clientIdx, MOVETYPE_NONE);
		
		// invincibility is highly recommended, but not required
		if (GH_MakeInvincible[clientIdx])
		{
			TF2_AddCondition(clientIdx, TFCond_Ubercharged, -1.0);
			SetEntProp(clientIdx, Prop_Data, "m_takedamage", 0);
		}
		
		// repeat sounds
		static Float:bossOrigin[3];
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
		PseudoAmbientSound(clientIdx, GH_GUITAR_SOUND, GH_SoundRepeatCount[clientIdx], GH_Radius[clientIdx] * 1.5, true);
	}
	
	if (DS_CanUse[clientIdx])
	{
		DS_OnActivation(clientIdx);
	}
	
	if (HC_CanUse[clientIdx])
	{
		HC_BeginConsumptionRage(clientIdx);
	}
}

OnDOTAbilityDeactivated(clientIdx)
{
	if (!PluginActiveThisRound)
		return;

	if (HC_CanUse[clientIdx])
	{
		HC_EndConsumptionRage(clientIdx);
	}
}

OnDOTUserDeath(clientIdx, isInGame)
{
	// suppress
	if (clientIdx || isInGame) { }
}

Action:OnDOTAbilityTick(clientIdx, tickCount)
{	
	if (!PluginActiveThisRound)
		return;

	if (GH_CanUse[clientIdx])
	{
		ForceDOTAbilityDeactivation(clientIdx);
		return;
	}
	
	if (DS_CanUse[clientIdx])
	{
		ForceDOTAbilityDeactivation(clientIdx);
		return;
	}

	if (HD_CanUse[clientIdx])
	{
		new Float:playerCount = float(max(2, HC_PlayerCount));
		new Float:drain = HD_DrainWithMax[clientIdx];
		drain += (HD_DrainWithMin[clientIdx] - HD_DrainWithMax[clientIdx]) * (1.0 - ((playerCount - 2.0) / 29.0));
		
		HC_ConsumeHeadMultiplier(clientIdx, drain);
	}

	// suppress
	if (tickCount) { }
}

/**
 * Earthquake Machine
 */
public Action:EM_RestoreRage(Handle:timer, any:bossIdx)
{
	if (RoundInProgress)
		FF2_SetBossCharge(bossIdx, 0, 100.0);
}

// original credit to Phatrages, I only really tweaked it slightly.
stock EM_CreateEarthquake(clientIdx)
{
	if (EM_Flags[clientIdx] & EM_FLAG_NO_EARTHQUAKE)
		return;

	new Float:amplitude = 16.0;
	new Float:radius = EM_Radius[clientIdx];
	new Float:duration = EM_Duration[clientIdx];
	new Float:frequency = 255.0;

	new earthquake = CreateEntityByName("env_shake");
	if (IsValidEntity(earthquake))
	{
		static Float:victimOrigin[3];
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", victimOrigin);
	
		DispatchKeyValueFloat(earthquake, "amplitude", amplitude);
		DispatchKeyValueFloat(earthquake, "radius", radius * 2);
		DispatchKeyValueFloat(earthquake, "duration", duration + 2.0);
		DispatchKeyValueFloat(earthquake, "frequency", frequency);

		SetVariantString("spawnflags 4"); // no physics (physics is 8), affects people in air
		AcceptEntityInput(earthquake, "AddOutput");

		// create
		DispatchSpawn(earthquake);
		TeleportEntity(earthquake, victimOrigin, NULL_VECTOR, NULL_VECTOR);

		AcceptEntityInput(earthquake, "StartShake", 0);
		
		CreateTimer(duration + 0.1, RemoveEntity, EntIndexToEntRef(earthquake), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Float:EM_GetDamage(clientIdx, Float:distance)
{
	if (EM_Flags[clientIdx] & EM_FLAG_EXPONENTIAL_DAMAGE)
		return EM_MaxDamage[clientIdx] - (EM_MaxDamage[clientIdx] * (Pow(Pow(EM_Radius[clientIdx], EM_Exponent[clientIdx]) - Pow(EM_Radius[clientIdx] - distance, EM_Exponent[clientIdx]), 1 / EM_Exponent[clientIdx]) / EM_Radius[clientIdx]));
	else
		return EM_MaxDamage[clientIdx] * (EM_Radius[clientIdx] - distance) / EM_Radius[clientIdx];
}
 
public EM_Tick(clientIdx, Float:curTime)
{
	if (EM_MachineEntRef[clientIdx] != INVALID_ENTREF)
	{
		new machine = EntRefToEntIndex(EM_MachineEntRef[clientIdx]);
		if (!IsValidEntity(machine))
		{
			PrintToServer("[sarysamods8] ERROR: Earthquake machine entity invalid. This shouldn't ever happen. Ending rage.");
			EM_MachineEntRef[clientIdx] = INVALID_ENTREF;
			if (EM_ParticleEntRef[clientIdx] != INVALID_ENTREF)
			{
				RemoveEntity(INVALID_HANDLE, EM_ParticleEntRef[clientIdx]);
				EM_ParticleEntRef[clientIdx] = INVALID_ENTREF;
			}
			return;
		}
		
		// is it time to despawn the machine?
		if (curTime >= EM_DespawnAt[clientIdx])
		{
			RemoveEntity(INVALID_HANDLE, EM_MachineEntRef[clientIdx]);
			EM_MachineEntRef[clientIdx] = INVALID_ENTREF;
			if (EM_ParticleEntRef[clientIdx] != INVALID_ENTREF)
			{
				RemoveEntity(INVALID_HANDLE, EM_ParticleEntRef[clientIdx]);
				EM_ParticleEntRef[clientIdx] = INVALID_ENTREF;
			}
			return;
		}
		
		// regardless of which machine type we're dealing with, we'll need the origin
		static Float:machineOrigin[3];
		GetEntPropVector(machine, Prop_Send, "m_vecOrigin", machineOrigin);
		
		// different behaviors depending on whether or not the entity is falling
		if (EM_IsFalling[clientIdx])
		{
			if (curTime >= EM_CheckPositionAt[clientIdx])
			{
				new Float:deltaTime = (curTime - EM_CheckPositionAt[clientIdx]) + EM_POSITION_CHECK_INTERVAL;
				//PrintToServer("%f - %f > (%f * 0.8 * %f) --> %f > %f", machineOrigin[2], EM_LastPosition[clientIdx][2], EM_START_VELOCITY_Z, deltaTime, (machineOrigin[2] - EM_LastPosition[clientIdx][2]), (EM_START_VELOCITY_Z * 0.8 * deltaTime));
				if (machineOrigin[2] - EM_LastPosition[clientIdx][2] > (EM_START_VELOCITY_Z * 0.8 * deltaTime))
				{
					// play the crash particle effect now. it belongs to nothing.
					if (!IsEmptyString(EMA_CrashEffect))
						ParticleEffectAt(machineOrigin, EMA_CrashEffect, 5.0);
				
					// spawn angles
					static Float:angles[3];
					GetEntPropVector(machine, Prop_Send, "m_angRotation", angles);
	
					EM_CreateLandedMachine(clientIdx, machineOrigin, angles[1]);
	
					// play crash sound
					if (strlen(EMA_CrashSound) > 3)
						PseudoAmbientSound(EntRefToEntIndex(EM_MachineEntRef[clientIdx]), EMA_CrashSound, 2, 800.0);
	
					// don't need to tick the landed machine this frame. lets just get out of here.
					return;
				}
				
				EM_LastPosition[clientIdx][0] = machineOrigin[0];
				EM_LastPosition[clientIdx][1] = machineOrigin[1];
				EM_LastPosition[clientIdx][2] = machineOrigin[2];
				EM_CheckPositionAt[clientIdx] = curTime + EM_POSITION_CHECK_INTERVAL;
			}
		
			// perform cylinder collision check, since the object can be walked through.
			for (new victim = 1; victim < MAX_PLAYERS; victim++)
			{
				if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
					continue;
				else if (EM_AlreadyStruck[clientIdx])
					continue;
					
				static Float:victimOrigin[3];
				GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimOrigin);
				if (CylinderCollision(machineOrigin, victimOrigin, EM_CollisionRadius[clientIdx], machineOrigin[2] - 103.0, machineOrigin[2] + EM_CollisionHeight[clientIdx]))
				{
					EM_AlreadyStruck[clientIdx] = true;
					
					// knockback first, lest they expire...which they probably will. this hurts a lot.
					static Float:tmpVec1[3];
					static Float:tmpVec2[3];
					tmpVec1[0] = machineOrigin[0];
					tmpVec1[1] = machineOrigin[1];
					tmpVec1[2] = 0.0;
					tmpVec2[0] = victimOrigin[0];
					tmpVec2[1] = victimOrigin[1];
					tmpVec2[2] = 0.0;
					static Float:angles[3];
					GetVectorAnglesTwoPoints(tmpVec1, tmpVec2, angles);
					static Float:velocity[3];
					GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
					ScaleVector(velocity, EM_PlayerStrikeKnockback[clientIdx]);
					velocity[2] = EM_KnockAroundMinZ[clientIdx];
					TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, velocity);
					
					// damage
					SDKHooks_TakeDamage(victim, clientIdx, clientIdx, EM_PlayerStrikeDamage[clientIdx], DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
				}
			}
			
			// immediately destroy buildings
			for (new pass = 0; pass < 3; pass++)
			{
				static String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
				if (pass == 0) classname = "obj_sentrygun";
				else if (pass == 1) classname = "obj_dispenser";
				else if (pass == 2) classname = "obj_teleporter";

				new building = -1;
				while ((building = FindEntityByClassname(building, classname)) != -1)
				{
					static Float:buildingPos[3];
					GetEntPropVector(building, Prop_Send, "m_vecOrigin", buildingPos);
					if (CylinderCollision(machineOrigin, buildingPos, EM_CollisionRadius[clientIdx], machineOrigin[2] - 103.0, machineOrigin[2] + EM_CollisionHeight[clientIdx]))
						SDKHooks_TakeDamage(building, clientIdx, clientIdx, 9999.0, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
				}
			}
		}
		else
		{
			// damage interval
			if (curTime >= EM_NextDamageAt[clientIdx])
			{
				// players
				for (new victim = 1; victim < MAX_PLAYERS; victim++)
				{
					if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
						continue;
					
					// distance check
					static Float:victimOrigin[3];
					GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimOrigin);
					new Float:distance = GetVectorDistance(victimOrigin, machineOrigin);
					if (distance >= EM_Radius[clientIdx])
						continue;
						
					// water immunity?
					if ((EM_Flags[clientIdx] & EM_FLAG_IMMUNE_IN_WATER) != 0 && (GetEntityFlags(victim) & (FL_INWATER | FL_SWIM)) != 0)
						continue;
					
					// if player is too high in the air, skip them
					if (CheckGroundClearance(victim, EM_ImmunityClearance[clientIdx], true))
						continue;
						
					// is it standard or exponential?
					new Float:damage = EM_GetDamage(clientIdx, distance);
						
					// ensure minimum damage
					if (damage < 2.0)
						damage = 2.0;
					
					// do damage, without flooding the hale with loud dings
					if (EM_Flags[clientIdx] & EM_FLAG_SILENCE_HITSOUNDS)
						QuietDamage(victim, clientIdx, clientIdx, damage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
					else
						SDKHooks_TakeDamage(victim, clientIdx, clientIdx, damage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
				}
				
				// buildings
				for (new pass = 0; pass < 3; pass++)
				{
					static String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
					if (pass == 0) classname = "obj_sentrygun";
					else if (pass == 1) classname = "obj_dispenser";
					else if (pass == 2) classname = "obj_teleporter";

					new building = -1;
					while ((building = FindEntityByClassname(building, classname)) != -1)
					{
						static Float:buildingPos[3];
						GetEntPropVector(building, Prop_Send, "m_vecOrigin", buildingPos);
						
						new Float:distance = GetVectorDistance(buildingPos, machineOrigin);
						if (distance >= EM_Radius[clientIdx])
							continue;
							
						// no concerns for water immunity or ground clearance. lets get our damage.
						new Float:damage = EM_GetDamage(clientIdx, distance);
						
						// ensure minimum damage and then apply building damage modifier
						if (damage < 2.0)
							damage = 2.0;
						damage *= EM_BuildingDamageModifier[clientIdx];
						
						// damage it
						SDKHooks_TakeDamage(building, clientIdx, clientIdx, damage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
					}
				}
			
				EM_NextDamageAt[clientIdx] = curTime + EM_DamageInterval[clientIdx];
			}

			// knock around interval
			if (curTime >= EM_NextKnockAroundAt[clientIdx])
			{
				for (new victim = 1; victim < MAX_PLAYERS; victim++)
				{
					if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
						continue;
					
					// distance check
					static Float:victimOrigin[3];
					GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimOrigin);
					new Float:distance = GetVectorDistance(victimOrigin, machineOrigin);
					if (distance >= EM_Radius[clientIdx])
						continue;
						
					// water immunity?
					if ((EM_Flags[clientIdx] & EM_FLAG_IMMUNE_IN_WATER) != 0 && (GetEntityFlags(victim) & (FL_INWATER | FL_SWIM)) != 0)
						continue;
					
					// if player is too high in the air, skip them
					if (CheckGroundClearance(victim, EM_ImmunityClearance[clientIdx], true))
						continue;
						
					// a simple percentage check, which can be over 100
					new bool:shouldKnock = GetRandomFloat(0.0, 100.0) <= EM_KnockAroundChance[clientIdx] * (EM_Radius[clientIdx] - distance) / EM_Radius[clientIdx];
					if (shouldKnock)
					{
						static Float:angles[3];
						angles[0] = angles[2] = 0.0;
						angles[1] = GetRandomFloat(-179.9, 179.0);
						static Float:velocityMod[3];
						static Float:victimVelocity[3];
						GetEntPropVector(victim, Prop_Data, "m_vecVelocity", victimVelocity);
						GetAngleVectors(angles, velocityMod, NULL_VECTOR, NULL_VECTOR);
						ScaleVector(velocityMod, EM_KnockAroundIntensity[clientIdx] * (EM_Radius[clientIdx] - distance) / EM_Radius[clientIdx]);
						
						// how it's applied depends on a flag...
						if (EM_Flags[clientIdx] & EM_FLAG_KNOCK_AROUND_ADDITIVE)
						{
							victimVelocity[0] += velocityMod[0];
							victimVelocity[1] += velocityMod[1];
							victimVelocity[2] = fmax(victimVelocity[2], EM_KnockAroundMinZ[clientIdx]);
							TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, victimVelocity);
						}
						else
						{
							velocityMod[2] = EM_KnockAroundMinZ[clientIdx];
							TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, velocityMod);
						}
					}
				}
				
				EM_NextKnockAroundAt[clientIdx] = curTime + EM_KnockAroundInterval[clientIdx];
			}

			// sonic wave aesthetic interval
			if (curTime >= EM_NextSonicWaveAt[clientIdx])
			{
				static Float:beaconPos[3];
				beaconPos[0] = machineOrigin[0];
				beaconPos[1] = machineOrigin[1];
				beaconPos[2] = machineOrigin[2] + EMA_BeaconZOffset;
			
				static color[4];
				color[0] = (EMA_BeaconColor>>16)&0xff;
				color[1] = (EMA_BeaconColor>>8)&0xff;
				color[2] = (EMA_BeaconColor)&0xff;
				color[3] = 255;
				TE_SetupBeamRingPoint(beaconPos, 1.0, EM_Radius[clientIdx] * EMA_BeaconSpeedFactor, EMA_BeaconMaterial, BEACON_HALO, 0, 15, EMA_BeaconLoopInterval, EMA_BeaconRadius, 0.0, color, 1000, 0);
				TE_SendToAll();
			
				EM_NextSonicWaveAt[clientIdx] = curTime + EMA_BeaconLoopInterval;
			}
		}
	}
}

public EM_CreateMachineProp(Float:pos[3], Float:yaw, const String:modelName[MAX_MODEL_FILE_LENGTH])
{
	// create our physics object and set it to take damage 
	new machine = CreateEntityByName("prop_physics");
	if (!IsValidEntity(machine))
		return -1;
	SetEntProp(machine, Prop_Data, "m_takedamage", 0);
	
	// no pitch settings, only yaw.
	new Float:angles[3];
	angles[0] = angles[2] = 0.0;
	angles[1] = yaw;

	// tweak the model
	SetEntityModel(machine, modelName);

	// spawn and move it
	DispatchSpawn(machine);
	TeleportEntity(machine, pos, angles, Float:{0.0,0.0,EM_START_VELOCITY_Z});
	SetEntProp(machine, Prop_Data, "m_takedamage", 0);

	// collision
	SetEntProp(machine, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
	//SetEntProp(machine, Prop_Send, "m_usSolidFlags", 4); // not solid
	//SetEntProp(machine, Prop_Send, "m_nSolidType", 0); // not solid
	
	return machine;
}
 
public EM_CreateFallingMachine(clientIdx, Float:pos[3], Float:yaw)
{
	new machine = EM_CreateMachineProp(pos, yaw, EMA_MachineModelFalling);
	
	// this is necessary only if refund is disabled
	if (EM_MachineEntRef[clientIdx] != INVALID_ENTREF)
	{
		RemoveEntity(INVALID_HANDLE, EM_MachineEntRef[clientIdx]);
		EM_MachineEntRef[clientIdx] = INVALID_ENTREF;
		if (EM_ParticleEntRef[clientIdx] != INVALID_ENTREF)
		{
			RemoveEntity(INVALID_HANDLE, EM_ParticleEntRef[clientIdx]);
			EM_ParticleEntRef[clientIdx] = INVALID_ENTREF;
		}
	}
	
	if (machine == -1)
		return;
	
	// mess with its gravity
	EM_MachineEntRef[clientIdx] = EntIndexToEntRef(machine);
	SetEntityGravity(machine, EM_Gravity[clientIdx]);
	
	// position test is the only way I've been able to determine when the bass cannon hits the ground
	EM_CheckPositionAt[clientIdx] = GetEngineTime() + EM_POSITION_CHECK_INTERVAL;
	EM_LastPosition[clientIdx][0] = pos[0];
	EM_LastPosition[clientIdx][1] = pos[1];
	EM_LastPosition[clientIdx][2] = pos[2];

	// the 10.0 while falling is only for sanity purposes.
	EM_DespawnAt[clientIdx] = GetEngineTime() + 10.0;
}

public EM_CreateLandedMachine(clientIdx, Float:pos[3], Float:yaw)
{
	new machine = EM_CreateMachineProp(pos, yaw, EMA_MachineModelOnGround);
	
	if (EM_MachineEntRef[clientIdx] != INVALID_ENTREF)
	{
		RemoveEntity(INVALID_HANDLE, EM_MachineEntRef[clientIdx]);
		EM_MachineEntRef[clientIdx] = INVALID_ENTREF;
		if (EM_ParticleEntRef[clientIdx] != INVALID_ENTREF)
		{
			RemoveEntity(INVALID_HANDLE, EM_ParticleEntRef[clientIdx]);
			EM_ParticleEntRef[clientIdx] = INVALID_ENTREF;
		}
	}
	
	if (machine == -1)
		return;
	
	// set machine immobile
	EM_IsFalling[clientIdx] = false;
	EM_MachineEntRef[clientIdx] = EntIndexToEntRef(machine);
	SetEntityMoveType(machine, MOVETYPE_NONE);
	
	// create earthquake
	EM_CreateEarthquake(clientIdx);
	
	// play sound
	if (strlen(EMA_AmbientSound) > 3)
	{
		static Float:tmpPos[3];
		tmpPos[0] = pos[0];
		tmpPos[1] = pos[1];
		tmpPos[2] = pos[2] + 20.0;
		EmitAmbientSound(EMA_AmbientSound, tmpPos, machine);
		EmitAmbientSound(EMA_AmbientSound, tmpPos, machine);
		EmitAmbientSound(EMA_AmbientSound, tmpPos, machine);
	}
	
	// attach particle
	if (!IsEmptyString(EMA_PersistentEffect))
	{
		new particle = AttachParticle(machine, EMA_PersistentEffect);
		if (IsValidEntity(particle))
			EM_ParticleEntRef[clientIdx] = EntIndexToEntRef(particle);
	}
		
	EM_DespawnAt[clientIdx] = GetEngineTime() + EM_Duration[clientIdx];
}
 
public bool:Rage_EarthquakeMachine(const String:ability_name[], bossIdx)
{
	if (!EM_ActiveThisRound)
		return true; // in case the rage is invalid

	new clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	if (EM_Flags[clientIdx] & EM_FLAG_PREVENT_RESUMMON)
	{
		if (EM_MachineEntRef[clientIdx] != INVALID_ENTREF)
		{
			PrintCenterText(clientIdx, EMA_RageSpamMessage);
			PrintToChat(clientIdx, EMA_RageSpamMessage);
			
			// heresy...I'm creating a timer. though for once it's safe.
			CreateTimer(0.1, EM_RestoreRage, bossIdx, TIMER_FLAG_NO_MAPCHANGE);
			
			return false;
		}
	}
	
	// initialize
	EM_IsFalling[clientIdx] = (GetEntityFlags(clientIdx) & FL_ONGROUND) == 0;
	EM_AlreadyStruck[clientIdx] = false;
	EM_NextDamageAt[clientIdx] = GetEngineTime();
	EM_NextKnockAroundAt[clientIdx] = GetEngineTime();
	EM_NextSonicWaveAt[clientIdx] = GetEngineTime();
	
	// we always spawn the machine on top of the player
	static Float:spawnPos[3];
	static Float:eyeAngles[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", spawnPos);
	GetClientEyeAngles(clientIdx, eyeAngles);
	if (EM_IsFalling[clientIdx])
		EM_CreateFallingMachine(clientIdx, spawnPos, eyeAngles[1]);
	else // not falling
		EM_CreateLandedMachine(clientIdx, spawnPos, eyeAngles[1]);
		
	// rage sound
	if (strlen(EMA_RageSound) > 3)
		EmitSoundToAll(EMA_RageSound);
		
	return true;
}

/**
 * DOT Guitar Hero
 */
public Action:GH_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GH_GuitarIsKilling)
	{
		SetEventString(event, "weapon", "taunt_guitar_kill");
		SetEventString(event, "weapon_logclassname", "guitar");
	}
	
	return Plugin_Continue;
}
 
public GH_Tick(clientIdx, Float:curTime)
{
	if (GH_IsUsing[clientIdx] && curTime >= GH_EffectsAt[clientIdx])
	{
		// must remove megaheal no matter what
		GH_IsUsing[clientIdx] = false;
		TF2_RemoveCondition(clientIdx, TFCond_MegaHeal);
		SetEntityMoveType(clientIdx, MOVETYPE_WALK);
		
		// also remove invincibility
		if (GH_MakeInvincible[clientIdx])
		{
			TF2_RemoveCondition(clientIdx, TFCond_Ubercharged);
			SetEntProp(clientIdx, Prop_Data, "m_takedamage", 2);
		}
		
		// client pos
		static Float:bossPos[3];
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossPos);
		
		// for kill icon
		GH_GuitarIsKilling = true;
		
		// with the potentially detrimental stuff gone, do knockback and damage. been there done that.
		for (new victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
				continue;
		
			static Float:victimPos[3];
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
			new Float:distance = GetVectorDistance(victimPos, bossPos);
			
			if (distance >= GH_Radius[clientIdx])
				continue;
				
			// you know the drill. knockback first.
			static Float:angles[3];
			GetVectorAnglesTwoPoints(bossPos, victimPos, angles);
			static Float:velocity[3];
			GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(velocity, GH_Knockback[clientIdx] - (GH_Knockback[clientIdx] * distance / GH_Radius[clientIdx]));
			if (velocity[2] < GH_MinZ[clientIdx])
				velocity[2] = GH_MinZ[clientIdx];
			TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, velocity);
			
			// then damage
			new Float:damage = GH_Damage[clientIdx] - (GH_Damage[clientIdx] * distance / GH_Radius[clientIdx]);
			if (damage < 2.0)
				damage = 2.0;
				
			// 2015-10-03, non-spies should have managed damage, but only if damage is at least 2/3 of their health
			new health = GetEntProp(victim, Prop_Send, "m_iHealth");
			if (RoundFloat(damage) >= health * 2 / 3 && TF2_GetPlayerClass(victim) != TFClass_Spy)
				FullyHookedDamage(victim, clientIdx, clientIdx, damage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
			else
				SDKHooks_TakeDamage(victim, clientIdx, clientIdx, damage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
		}
		
		// now the buildings...
		for (new pass = 0; pass < 3; pass++)
		{
			static String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
			if (pass == 0) classname = "obj_sentrygun";
			else if (pass == 1) classname = "obj_dispenser";
			else if (pass == 2) classname = "obj_teleporter";

			new building = -1;
			while ((building = FindEntityByClassname(building, classname)) != -1)
			{
				static Float:buildingPos[3];
				GetEntPropVector(building, Prop_Send, "m_vecOrigin", buildingPos);

				new Float:distance = GetVectorDistance(buildingPos, bossPos);
				if (distance >= GH_Radius[clientIdx])
					continue;

				// just damage
				new Float:damage = GH_Damage[clientIdx] - (GH_Damage[clientIdx] * distance / GH_Radius[clientIdx]);
				damage *= GH_BuildingDamageFactor[clientIdx];
				if (damage > 0.0)
					SDKHooks_TakeDamage(building, clientIdx, clientIdx, damage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
			}
		}
		
		// for kill icon
		GH_GuitarIsKilling = false;
	}
}

/**
 * Medic Minion
 */
public Action:MM_ShieldCheck(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (!IsLivingPlayer(victim) || !IsLivingPlayer(attacker))
		return Plugin_Continue;
	else if (GetClientTeam(attacker) != BossTeam || !MMM_IsMinion[attacker])
		return Plugin_Continue;
		
	new shield = -1;
	if (TF2_GetPlayerClass(victim) == TFClass_Sniper)
	{
		while ((shield = FindEntityByClassname(shield, "tf_wearable")) != -1)
		{
			if (GetEntPropEnt(shield, Prop_Send, "m_hOwnerEntity") == victim && GetEntProp(shield, Prop_Send, "m_iItemDefinitionIndex") == 57)
				break;
		}
	}
	else if (TF2_GetPlayerClass(victim) == TFClass_DemoMan)
	{
		while ((shield = FindEntityByClassname(shield, "tf_wearable_demoshield")) != -1)
		{
			if (GetEntPropEnt(shield, Prop_Send, "m_hOwnerEntity") == victim)
				break;
		}
	}
	else
		return Plugin_Continue;
		
	if (!IsValidEntity(shield))
		return Plugin_Continue;

	// proper handling
	new bool:shouldHandle = MM_ShieldHandling == MM_SHIELD_TYPICAL;
	if (!shouldHandle && MM_ShieldHandling == MM_SHIELD_VSP)
	{
		//PrintToServer("clrRender=0x%x", GetEntProp(shield, Prop_Send, "m_clrRender"));
		shouldHandle = GetEntProp(shield, Prop_Send, "m_clrRender") == 0xffffffff;
	}

	if (shouldHandle)
	{
		MM_AttackNextFrame[MMM_Owner[attacker]] = victim;
		MM_ANFDamage[MMM_Owner[attacker]] = damage;
		MM_ANFAttacker[MMM_Owner[attacker]] = attacker;
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action:MM_BossIncomingDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (!IsLivingPlayer(victim) || !MM_CanUse[victim])
		return Plugin_Continue;
		
	if (TF2_IsPlayerInCondition(victim, TFCond_Kritzkrieged) || TF2_IsPlayerInCondition(victim, TFCond_MegaHeal) ||
		TF2_IsPlayerInCondition(victim, TFCond_BulletImmune) || TF2_IsPlayerInCondition(victim, TFCond_BlastImmune) ||
		TF2_IsPlayerInCondition(victim, TFCond_FireImmune))
	{
		damage *= MM_BossUberedVulnerability[victim];
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
 
public Action:MM_MinionIncomingDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (damagecustom == TF_CUSTOM_BACKSTAB)
	{
		new Float:bsDamage = MM_BackstabMultiplier * MM_MaxHP[MMM_Owner[victim]];
		if (bsDamage < GetEntProp(victim, Prop_Data, "m_iHealth"))
		{
			MM_BackstabPendingAgainst[attacker] = victim;
			return Plugin_Handled; // cancel the backstab
		}
	}
	else if (IsLivingPlayer(attacker) && MMM_DamageVulnerability[victim] != 1.0)
	{
		damage *= MMM_DamageVulnerability[victim];
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action:MM_BuildingRevengeCheck(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (!IsLivingPlayer(attacker) || !MM_CanUse[attacker])
		return Plugin_Continue;

	if (MM_RevengeUntil[attacker] != FAR_FUTURE && MM_RevengeBuildingMult[attacker] != 1.0)
	{
		damage *= MM_RevengeBuildingMult[attacker];
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public MM_OnEntityCreated(entity, const String:classname[])
{
	if (strcmp(classname, "obj_sentrygun") == 0 || strcmp(classname, "obj_teleporter") == 0 || strcmp(classname, "obj_dispenser") == 0)
		SDKHook(entity, SDKHook_OnTakeDamage, MM_BuildingRevengeCheck);
}

public Action:MM_CheckSuicide(clientIdx, const String:command[], argc)
{
	if (MM_Flags & MM_FLAG_SUICIDE_BLACKLIST)
	{
		if (MMM_IsMinion[clientIdx])
			MM_OnMinionSuicide(clientIdx, GetEngineTime(), (MM_Flags & MM_FLAG_MINION_SUICIDE_PUNISHMENT) != 0);
		MMM_Blacklisted[clientIdx] = true;
	}
}

public MM_TriggerRevenge(clientIdx)
{
	if (MM_RevengeDuration[clientIdx] <= 0.0)
		return;

	MM_RevengeUntil[clientIdx] = GetEngineTime() + MM_RevengeDuration[clientIdx];
	if (strlen(MM_RevengeSound) > 3)
		EmitSoundToAll(MM_RevengeSound);
}
 
public MM_OnMinionDeath(minion)
{
	MMM_IsMinion[minion] = false;
	if (IsClientInGame(minion))
	{
		TF2_SetPlayerClass(minion, MMM_LastClass[minion]);
		if (IsLivingPlayer(minion))
		{
			// workaround for the stalemate glitch, which I can't reproduce on my test server.
			// kill the minion.
			new killerRed = FindRandomPlayer(false);
			if (IsLivingPlayer(killerRed))
			{
				RemoveInvincibility(minion);
				SDKHooks_TakeDamage(minion, killerRed, killerRed, 9999.0, DMG_GENERIC, -1);
			}
		}
	}
		
	if (MMM_ParticleEntRef[minion] != INVALID_ENTREF)
	{
		RemoveEntity(INVALID_HANDLE, MMM_ParticleEntRef[minion]);
		MMM_ParticleEntRef[minion] = INVALID_ENTREF;
	}
}
 
public MM_KillMinion(minion)
{
	MMM_Owner[minion] = -1;
	new killer = FindRandomPlayer(false);
	if (killer == -1)
		killer = minion;

	SetEntProp(minion, Prop_Data, "m_takedamage", 2);
	if (TF2_IsPlayerInCondition(minion, TFCond_Ubercharged))
		TF2_RemoveCondition(minion, TFCond_Ubercharged);
	SDKHooks_TakeDamage(minion, killer, killer, 9999.0, DMG_GENERIC, -1);
	
	MM_OnMinionDeath(minion);
}

public bool:MM_ValidPotentialMinion(minion)
{
	if (!IsClientInGame(minion))
		return false;
	if (MMM_Blacklisted[minion])
		return false;
	if (IsLivingPlayer(minion))
		return false;
	if (GetClientTeam(minion) != BossTeam && GetClientTeam(minion) != MercTeam)
		return false;
	
	return true;
}

// another derived method from the stock summon rage
public Rage_MedicMinion(bossIdx)
{
	new clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));

	// bring in minion args
	static String:modelName[MAX_MODEL_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MM_STRING, 1, modelName, MAX_MODEL_FILE_LENGTH);
	new TFClassType:classType = TFClassType:FF2_GetAbilityArgument(bossIdx, this_plugin_name, MM_STRING, 2);
	static String:weaponName[MAX_WEAPON_NAME_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MM_STRING, 3, weaponName, MAX_WEAPON_NAME_LENGTH);
	new weaponIdx = FF2_GetAbilityArgument(bossIdx, this_plugin_name, MM_STRING, 4);
	static String:weaponArgs[MAX_WEAPON_ARG_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MM_STRING, 5, weaponArgs, MAX_WEAPON_ARG_LENGTH);
	new weaponVisibility = FF2_GetAbilityArgument(bossIdx, this_plugin_name, MM_STRING, 6);
	
	// find a player to revive
	new minion = -1;
	if (MM_Flags & MM_FLAG_ALLOW_CHOICE)
		minion = MM_CurrentMinionChoice[clientIdx];
	if (minion == -1 || !MM_ValidPotentialMinion(minion))
		minion = FindRandomPlayerBlacklist(false, MMM_Blacklisted, NULL_VECTOR, 0.0, true, true);
	if (minion == -1)
	{
		if (MM_MinionRefundDelay[clientIdx] > 0.0)
			MM_RefundRageAt[clientIdx] = GetEngineTime() + MM_MinionRefundDelay[clientIdx];
		return;
	}
	
	// this terrible "free quota" hack...
	if (MM_Flags & MM_FLAG_MINION_FREE_QUOTA)
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods8] There'd be free quota here, but it's not possible.");
	}
	
	// cancel any existing refund
	MM_RefundRageAt[clientIdx] = FAR_FUTURE;
	
	// revive the player
	MMM_LastClass[minion] = TF2_GetPlayerClass(minion);
	FF2_SetFF2flags(minion, FF2_GetFF2flags(minion) | FF2FLAG_ALLOWSPAWNINBOSSTEAM);
	ChangeClientTeam(minion, BossTeam);
	TF2_RespawnPlayer(minion);
	TF2_SetPlayerClass(minion, classType);
	
	// change model
	if (strlen(modelName) > 3)
	{
		SetVariantString(modelName);
		AcceptEntityInput(minion, "SetCustomModel");
		SetEntProp(minion, Prop_Send, "m_bUseClassAnimations", 1);
	}
	
	// strip all weapons and add the desired weapon
	new weapon;
	TF2_RemoveAllWeapons(minion);
	weapon = SpawnWeapon(minion, weaponName, weaponIdx, 101, 5, weaponArgs);
	if (IsValidEdict(weapon))
	{
		SetEntPropEnt(minion, Prop_Send, "m_hActiveWeapon", weapon);
		if (weaponVisibility == 0)
			SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", -1);
	}
	
	// set various clone properties (owner, time to die, model retry time, etc.)
	MMM_IsMinion[minion] = true;
	MMM_Owner[minion] = clientIdx;
	MMM_RemodelCount[minion] = 2;
	MMM_RemodelAt[minion] = GetEngineTime() + 0.2;
	MMM_MinionSpawnedAt[minion] = GetEngineTime();
	MMM_RemoveInvincibilityAt[minion] = GetEngineTime() + 2.0;
	MMM_SpeedBuffedUntil[minion] = 0.0;
	MMM_ParticleEntRef[minion] = INVALID_ENTREF;
	MMM_DamageVulnerability[minion] = 1.0;
	MMM_LastKillCount[minion] = GetEntProp(minion, Prop_Send, "m_iKills");
	if (!MMM_DamageHooked[minion])
	{
		SDKHook(minion, SDKHook_OnTakeDamage, MM_MinionIncomingDamage);
		MMM_DamageHooked[minion] = true;
	}
	
	// blacklist the minion if they only get one shot per round
	if (MM_Flags & MM_FLAG_ONCE_AS_MINION_PER_ROUND)
		MMM_Blacklisted[minion] = true;
	
	// teleport and heal the clone
	static Float:bossOrigin[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
	SetEntProp(minion, Prop_Data, "m_takedamage", 0);
	SetEntProp(minion, Prop_Data, "m_iHealth", MM_MaxHP[clientIdx]);
	SetEntProp(minion, Prop_Send, "m_iHealth", MM_MaxHP[clientIdx]);
	// set them to crouching position before teleporting
	SetEntPropVector(clientIdx, Prop_Send, "m_vecMaxs", Float:{24.0, 24.0, 62.0});
	SetEntProp(clientIdx, Prop_Send, "m_bDucked", 1);
	SetEntityFlags(clientIdx, GetEntityFlags(clientIdx) | FL_DUCKING);
	TeleportEntity(minion, bossOrigin, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
	
	// display a particle effect
	if (!IsEmptyString(MM_MinionSpawnEffect))
	{
		static Float:particleOrigin[3];
		particleOrigin[0] = bossOrigin[0];
		particleOrigin[1] = bossOrigin[1];
		particleOrigin[2] = bossOrigin[2] + 40.0;
		ParticleEffectAt(particleOrigin, MM_MinionSpawnEffect, 1.0);
	}
	
	// remove wearables
	new entity;
	new owner;
	while((entity=FindEntityByClassname(entity, "tf_wearable"))!=-1)
	{
		if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==BossTeam)
		{
			TF2_RemoveWearable(owner, entity);
		}
	}

	while((entity=FindEntityByClassname(entity, "tf_wearable_demoshield"))!=-1)
	{
		if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==BossTeam)
		{
			TF2_RemoveWearable(owner, entity);
		}
	}

	while((entity=FindEntityByClassname(entity, "tf_powerup_bottle"))!=-1)
	{
		if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==BossTeam)
		{
			TF2_RemoveWearable(owner, entity);
		}
	}
}

public MM_OnMinionSuicide(minion, Float:curTime, bool:punish)
{
	new owner = MMM_Owner[minion];
	if (curTime < MMM_MinionSpawnedAt[minion] + MM_MinionRefundTime[owner])
	{
		if (MM_MinionRefundDelay[owner] > 0.0)
			MM_RefundRageAt[owner] = MMM_MinionSpawnedAt[minion] + MM_MinionRefundDelay[owner];
			
		if (MM_Flags & MM_FLAG_SUICIDE_BLACKLIST)
			MMM_Blacklisted[minion] = true;
	}
	
	if (punish && PRINT_DEBUG_SPAM)
		PrintToServer("[sarysamods8] Would that I could, but I cannot punish players with 0 damage.");
	MM_OnMinionDeath(minion);
}

public MM_Tick(Float:curTime)
{
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (MM_CanUse[clientIdx])
		{
			// nothing here is meaningful is the boss is dead
			if (!IsLivingPlayer(clientIdx))
				continue;
				
			// verify validity of minion, and HUD message
			if (MM_Flags & MM_FLAG_ALLOW_CHOICE)
			{
				new bool:reseek = false;
				if (MM_CurrentMinionChoice[clientIdx] == -1)
					reseek = true;
				else if (!MM_ValidPotentialMinion(MM_CurrentMinionChoice[clientIdx]))
				{
					MM_CurrentMinionChoice[clientIdx] = -1;
					reseek = true;
				}
				
				if (reseek)
				{
					for (new candidate = 1; candidate < MAX_PLAYERS; candidate++)
					{
						if (MM_ValidPotentialMinion(candidate))
						{
							MM_CurrentMinionChoice[clientIdx] = candidate;
							break;
						}
					}
				}

				if (curTime >= MM_NextHUDAt[clientIdx])
				{
					MM_NextHUDAt[clientIdx] = curTime + MM_HUD_INTERVAL;
					SetHudTextParams(-1.0, MM_HUD_Y, MM_HUD_INTERVAL + 0.05, 64, 255, 64, 192);
					static String:playerName[33];
					if (MM_CurrentMinionChoice[clientIdx] == -1)
						playerName = "[NONE]";
					else
						GetClientName(MM_CurrentMinionChoice[clientIdx], playerName, sizeof(playerName));
					ShowHudText(clientIdx, -1, MM_ChoiceHUDMessage, playerName);
				}
			}

			if (MM_AttackNextFrame[clientIdx] != -1)
			{
				// set a proper attack position for this damage
				static Float:attackPos[3];
				if (IsLivingPlayer(MM_ANFAttacker[clientIdx]))
					GetEntPropVector(MM_ANFAttacker[clientIdx], Prop_Send, "m_vecOrigin", attackPos);
				else
					GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", attackPos);
					
				if (IsLivingPlayer(MM_AttackNextFrame[clientIdx]))
					FullyHookedDamage(MM_AttackNextFrame[clientIdx], clientIdx, clientIdx, MM_ANFDamage[clientIdx], DMG_GENERIC | DMG_CRIT | DMG_PREVENT_PHYSICS_FORCE, GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Secondary), attackPos);
				MM_AttackNextFrame[clientIdx] = -1;
			}
		
			if (curTime >= MM_RevengeUntil[clientIdx])
			{
				if ((MM_Flags & MM_FLAG_REVENGE_INVINCIBLE) != 0 && GetEntProp(clientIdx, Prop_Data, "m_takedamage") != 2)
					SetEntProp(clientIdx, Prop_Data, "m_takedamage", 2);
			
				for (new i = 0; i < MM_MAX_REVENGE_CONDITIONS; i++)
				{
					// we hit the end of the meaningful list
					if (MM_RevengeConditions[clientIdx][i] == TFCond:0)
						break;
				
					if (TF2_IsPlayerInCondition(clientIdx, MM_RevengeConditions[clientIdx][i]))
						TF2_RemoveCondition(clientIdx, MM_RevengeConditions[clientIdx][i]);
				}
				
				MM_RevengeUntil[clientIdx] = FAR_FUTURE;
			}
			else if (MM_RevengeUntil[clientIdx] != FAR_FUTURE)
			{
				if ((MM_Flags & MM_FLAG_REVENGE_INVINCIBLE) != 0 && GetEntProp(clientIdx, Prop_Data, "m_takedamage") != 0)
					SetEntProp(clientIdx, Prop_Data, "m_takedamage", 0);
					
				for (new i = 0; i < MM_MAX_REVENGE_CONDITIONS; i++)
				{
					// we hit the end of the meaningful list
					if (MM_RevengeConditions[clientIdx][i] == TFCond:0)
						break;
				
					if (!TF2_IsPlayerInCondition(clientIdx, MM_RevengeConditions[clientIdx][i]))
						TF2_AddCondition(clientIdx, MM_RevengeConditions[clientIdx][i], -1.0);
				}
			}
			
			// refund rage
			if (curTime > MM_RefundRageAt[clientIdx])
			{
				new bossIdx = FF2_GetBossIndex(clientIdx);
				if (bossIdx >= 0)
				{
					FF2_SetBossCharge(bossIdx, 0, 100.0);
					PrintCenterText(clientIdx, "Your rage has been refunded due to no\nminion available, or minion suicided.");
				}
				MM_RefundRageAt[clientIdx] = FAR_FUTURE;
			}
		}
		else if (MMM_IsMinion[clientIdx])
		{
			// did player log?
			if (!IsClientInGame(clientIdx))
			{
				MM_OnMinionSuicide(clientIdx, curTime, false);
				continue;
			}
			
			// is player dead?
			if (!IsLivingPlayer(clientIdx))
			{
				MM_TriggerRevenge(MMM_Owner[clientIdx]);
				MM_OnMinionDeath(clientIdx);
				continue;
			}
			
			// is owner dead?
			new owner = MMM_Owner[clientIdx];
			if (!IsLivingPlayer(owner))
			{
				if ((MM_Flags & MM_FLAG_MINION_DIE_WITH_BOSS) != 0)
				{
					MM_KillMinion(clientIdx);
					continue;
				}
				
				// regardless of the above, continue. nothing important applies to a minion without a hale
				continue;
			}

			// setting the model (backup)
			if (curTime >= MMM_RemodelAt[clientIdx])
			{
				new bossIdx = FF2_GetBossIndex(owner);
				static String:modelName[MAX_MODEL_FILE_LENGTH];
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MM_STRING, 1, modelName, MAX_MODEL_FILE_LENGTH);
				if (strlen(modelName) > 3)
				{
					SetVariantString(modelName);
					AcceptEntityInput(clientIdx, "SetCustomModel");
					SetEntProp(clientIdx, Prop_Send, "m_bUseClassAnimations", 1);
				}
				
				if (MMM_RemodelCount[clientIdx] > 0)
				{
					MMM_RemodelCount[clientIdx]--;
					MMM_RemodelAt[clientIdx] = curTime + 0.5;
				}
				else
					MMM_RemodelAt[clientIdx] = FAR_FUTURE;
			}
			
			if (curTime >= MMM_RemoveInvincibilityAt[clientIdx])
			{
				// no removal of uber, since this is a MEDIC MINION
				SetEntProp(clientIdx, Prop_Data, "m_takedamage", 2);
				MMM_RemoveInvincibilityAt[clientIdx] = FAR_FUTURE;
			}
			
			// what is the player's expected speed and damage vulnerability?
			new Float:speed = curTime < MMM_SpeedBuffedUntil[clientIdx] ? MM_MinionHealedSpeed[owner] : MM_MinionNormalSpeed[owner];
			MMM_DamageVulnerability[clientIdx] = curTime < MMM_SpeedBuffedUntil[clientIdx] ? MM_MinionHealedVulnerability[owner] : MM_MinionNormalVulnerability[owner];
			new medigun = GetPlayerWeaponSlot(owner, TFWeaponSlot_Secondary);
			if (IsValidEntity(medigun) && IsInstanceOf(medigun, "tf_weapon_medigun"))
			{
				new bool:ubering = (GetEntProp(medigun, Prop_Send, "m_bChargeRelease") & 0x1) == 1;
				new partner = GetEntProp(medigun, Prop_Send, "m_hHealingTarget") & 0x3ff;
				if (partner == clientIdx)
				{
					if (ubering)
					{
						speed = MM_MinionUberedSpeed[owner];
						MMM_DamageVulnerability[clientIdx] = MM_MinionUberedVulnerability[owner];
					}
					else
					{
						speed = MM_MinionHealedSpeed[owner];
						MMM_DamageVulnerability[clientIdx] = MM_MinionHealedVulnerability[owner];
					}

					MMM_SpeedBuffedUntil[clientIdx] = curTime + MM_SpeedLinger[owner];
				}
			}
			
			// play sound if kill count has changed
			new killCount = GetEntProp(clientIdx, Prop_Send, "m_iKills");
			if (MMM_LastKillCount[clientIdx] != killCount && strlen(MM_MinionKillSound) > 3)
				EmitSoundToAll(MM_MinionKillSound);
			MMM_LastKillCount[clientIdx] = killCount;
			
			// enforce it
			if (GetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed") != speed)
				SetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed", speed);
				
			// remove or add particle effect if applicable
			if (MMM_ParticleEntRef[clientIdx] != INVALID_ENTREF && speed == MM_MinionNormalSpeed[owner])
			{
				RemoveEntity(INVALID_HANDLE, MMM_ParticleEntRef[clientIdx]);
				MMM_ParticleEntRef[clientIdx] = INVALID_ENTREF;
			}
			else if (MMM_ParticleEntRef[clientIdx] == INVALID_ENTREF && speed != MM_MinionNormalSpeed[owner])
			{
				if (!IsEmptyString(MM_MinionHealedEffect))
				{
					// spawn it high enough to not be in their face
					new particle = AttachParticle(clientIdx, MM_MinionHealedEffect, 85.0);
					if (IsValidEntity(particle))
						MMM_ParticleEntRef[clientIdx] = EntIndexToEntRef(particle);
				}
			}
		}
		else if (IsLivingPlayer(clientIdx) && MM_BackstabPendingAgainst[clientIdx] != -1)
		{
			new victim = MM_BackstabPendingAgainst[clientIdx];
			new Float:bsDamage = MM_BackstabMultiplier * MM_MaxHP[MMM_Owner[victim]];
			if (IsLivingPlayer(victim))
				SDKHooks_TakeDamage(victim, clientIdx, clientIdx, bsDamage / 3.0, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE | DMG_CRIT, -1);
			MM_BackstabPendingAgainst[clientIdx] = -1;
		}
	}
}

public MM_OnPlayerRunCmd(clientIdx, buttons)
{
	if ((MM_Flags & MM_FLAG_ALLOW_CHOICE) == 0)
		return;

	new bool:specialDown = (buttons & IN_ATTACK3) != 0;
	if (!MM_SpecialDown[clientIdx] && specialDown)
	{
		for (new candidate = MM_CurrentMinionChoice[clientIdx] + 1; candidate != MM_CurrentMinionChoice[clientIdx]; candidate++)
		{
			if (candidate >= MAX_PLAYERS)
				candidate = 1;
				
			if (MM_ValidPotentialMinion(candidate))
			{
				MM_CurrentMinionChoice[clientIdx] = candidate;
				break;
			}
		}
	}
	MM_SpecialDown[clientIdx] = specialDown;
}

/**
 * Mobility by Weapon
 */
public MBW_Tick(clientIdx)
{
	// determine current slot or weapon and its index
	new curWeapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(curWeapon))
		return;
		
	new curSlot = -1;
	for (new i = 0; i < 6; i++)
	{
		if (GetPlayerWeaponSlot(clientIdx, i) == curWeapon)
		{
			curSlot = i;
			break;
		}
	}
	
	// see if the current weapon or slot has a config associated with it
	for (new i = 0; i < MBW_MAX_WEAPONS; i++)
	{
		if (MBW_SlotsOrWeapons[clientIdx][i] == -1)
			break;
	
		if (MBW_SlotsOrWeapons[clientIdx][i] == curSlot || MBW_SlotsOrWeapons[clientIdx][i] == curWeapon)
		{
			if (MBW_SlotsOrWeapons[clientIdx][i] == MBW_LastSlotOrWeapon[clientIdx])
				break; // nothing has changed
			
			// something changed. swap SJ/Teleport
			DD_SetDisabled(clientIdx, MBW_AbilityIdx[clientIdx][i] != MBW_JUMP, MBW_AbilityIdx[clientIdx][i] != MBW_TELEPORT, false);
			MBW_LastSlotOrWeapon[clientIdx] = MBW_SlotsOrWeapons[clientIdx][i];
		}
	}
}

/**
 * DOT Stare
 */
public DS_OnActivation(clientIdx)
{
	new Float:radiusSquared = DS_Radius[clientIdx] * DS_Radius[clientIdx];
	static Float:bossOrigin[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
	
	// drain the sentries first
	int sentry = -1;
	while ((sentry = FindEntityByClassname(sentry, "obj_sentrygun")) != -1)
	{
		static Float:sentryOrigin[3];
		GetEntPropVector(sentry, Prop_Send, "m_vecOrigin", sentryOrigin);
		if (GetVectorDistance(bossOrigin, sentryOrigin, true) <= radiusSquared)
		{
			SetEntProp(sentry, Prop_Send, "m_iAmmoRockets", RoundFloat(GetEntProp(sentry, Prop_Send, "m_iAmmoRockets") * DS_SentryRocketDrain[clientIdx]));
			SetEntProp(sentry, Prop_Send, "m_iAmmoShells", RoundFloat(GetEntProp(sentry, Prop_Send, "m_iAmmoShells") * DS_SentryBulletDrain[clientIdx]));
		}
	}
	
	for (new victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (!IsLivingPlayer(victim))
			continue;
	
		static Float:victimOrigin[3];
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimOrigin);
		
		if (GetVectorDistance(bossOrigin, victimOrigin, true) <= radiusSquared)
		{
			// play sound
			if (strlen(DS_RageSound) > 3)
				EmitSoundToClient(victim, DS_RageSound);
				
			// stop if victim is BLU
			if (GetClientTeam(victim) == BossTeam)
				continue;
				
			// stop if victim is ubercharged
			if (TF2_IsPlayerInCondition(victim, TFCond_Ubercharged))
				continue;
				
			// trigger slow for the player, assuming this isn't a rage spam
			if (!TF2_IsPlayerInCondition(victim, TFCond_MegaHeal)) // but not if they have megaheal
			{
				if (DS_SpeedMultiplier[clientIdx] != 1.0)
				{
					if (DS_AffectedUntil[victim] == FAR_FUTURE)
						DS_ExpectedSpeed[victim] = -1.0;
					DS_AffectedUntil[victim] = GetEngineTime() + DS_Duration[clientIdx];
					DS_MySlowMultiplier[victim] = DS_SpeedMultiplier[clientIdx];
					
					// halt their motion briefly
					TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
				}
			}
			
			// drain ammo
			if (DS_AmmoDrain[clientIdx] < 1.0)
			{
				for (new slot = 0; slot < 2; slot++)
				{
					new weapon = GetPlayerWeaponSlot(victim, slot);
					if (IsValidEntity(weapon))
					{
						new offset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1);
						if (offset < 0)
							continue;
							
						if (GetEntProp(victim, Prop_Send, "m_iAmmo", 4, offset) > 1)
							SetEntProp(victim, Prop_Send, "m_iAmmo", RoundFloat(GetEntProp(victim, Prop_Send, "m_iAmmo", 4, offset) * DS_AmmoDrain[clientIdx]), 4, offset);
						if (GetEntProp(weapon, Prop_Send, "m_iClip1") > 1 && GetEntProp(weapon, Prop_Send, "m_iClip1") < 128)
							SetEntProp(weapon, Prop_Send, "m_iClip1", RoundFloat(GetEntProp(weapon, Prop_Send, "m_iClip1") * DS_AmmoDrain[clientIdx]));
						//SetEntProp(weapon, Prop_Send, "m_iClip2", RoundFloat(GetEntProp(weapon, Prop_Send, "m_iClip2") * DS_AmmoDrain[clientIdx]));
					}
				}
				
				// if it's an engineer, drain metal
				if (TF2_GetPlayerClass(victim) == TFClass_Engineer)
				{
					new metalOffset = FindDataMapOffs(victim, "m_iAmmo") + (3 * 4);
					SetEntData(victim, metalOffset, RoundFloat(GetEntData(victim, metalOffset, 4) * DS_AmmoDrain[clientIdx]), 4);
				}
			}
			
			// apply damage
			if (DS_Damage[clientIdx] > 0.0)
			{
				SDKHooks_TakeDamage(victim, clientIdx, clientIdx, DS_Damage[clientIdx], DMG_GENERIC, -1);
			}
			
			// particle effect, if still alive
			if (IsLivingPlayer(victim) && !IsEmptyString(DS_Effect) && DS_ParticleEntRef[victim] == INVALID_ENTREF)
			{
				new particle = AttachParticle(victim, DS_Effect, 70.0, true);
				if (IsValidEntity(particle))
					DS_ParticleEntRef[victim] = EntIndexToEntRef(particle);
			}
		}
	}
}

public DS_Tick(Float:curTime)
{
	for (new victim = 1; victim < MAX_PLAYERS; victim++)
	{
		// is it time to end the effects?
		if (curTime >= DS_AffectedUntil[victim])
		{
			if (IsLivingPlayer(victim))
			{
				// fix speed
				if (DS_MySlowMultiplier[victim] > 0.0 && DS_MySlowMultiplier[victim] != 1.0)
				{
					new Float:curSpeed = GetEntPropFloat(victim, Prop_Send, "m_flMaxspeed");
					if (curSpeed == DS_ExpectedSpeed[victim])
						SetEntPropFloat(victim, Prop_Send, "m_flMaxspeed", curSpeed / DS_MySlowMultiplier[victim]);
				}
			}


			DS_AffectedUntil[victim] = FAR_FUTURE;
		}
		else if (DS_AffectedUntil[victim] != FAR_FUTURE)
		{
			if (!IsLivingPlayer(victim))
			{
				// remove particle
				if (DS_ParticleEntRef[victim] != INVALID_ENTREF)
				{
					RemoveEntity(INVALID_HANDLE, DS_ParticleEntRef[victim]);
					DS_ParticleEntRef[victim] = INVALID_ENTREF;
				}
				DS_AffectedUntil[victim] = FAR_FUTURE;
				
				continue;
			}
		
			// fix speed if it's not what's expected
			new Float:curSpeed = GetEntPropFloat(victim, Prop_Send, "m_flMaxspeed");
			if (curSpeed != DS_ExpectedSpeed[victim])
			{
				DS_ExpectedSpeed[victim] = curSpeed * DS_MySlowMultiplier[victim];
				SetEntPropFloat(victim, Prop_Send, "m_flMaxspeed", DS_ExpectedSpeed[victim]);
			}
		}
	}
}

/**
 * Medigun Fixes
 */
public MF_Tick(clientIdx, Float:curTime)
{
	if (curTime >= MF_RemoveWearablesAt[clientIdx])
	{
		MF_RemoveWearablesAt[clientIdx] = FAR_FUTURE;

		// remove wearables
		new entity;
		new owner;
		while((entity=FindEntityByClassname(entity, "tf_wearable"))!=-1)
		{
			if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==BossTeam)
			{
				TF2_RemoveWearable(owner, entity);
			}
		}
	}
	
	// compare current with last medigun level
	new medigun = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Secondary);
	if (IsValidEntity(medigun) && IsInstanceOf(medigun, "tf_weapon_medigun"))
	{
		new Float:curCharge = GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel");
		if (curCharge > 1.0 && MF_UndoOvercharge[clientIdx])
			SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", 1.0);
		else if (curCharge <= 1.0 && curCharge - MF_LastMedigunLevel[clientIdx] > 0.4 && MF_UndoFreeUber[clientIdx])
			SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", curCharge - 0.4);
		MF_LastMedigunLevel[clientIdx] = GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel");
	}
}

/**
 * Used by Head Collections and Rage Safe Resize
 */
new bool:ResizeTraceFailed;
new ResizeMyTeam;
public bool:Resize_TracePlayersAndBuildings(entity, contentsMask)
{
	if (IsLivingPlayer(entity))
	{
		if (GetClientTeam(entity) != ResizeMyTeam)
		{
			ResizeTraceFailed = true;
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods8] Player %d stopped trace.", entity);
		}
	}
	else if (IsValidEntity(entity))
	{
		static String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
		GetEntityClassname(entity, classname, sizeof(classname));
		if ((strcmp(classname, "obj_sentrygun") == 0) || (strcmp(classname, "obj_dispenser") == 0) || (strcmp(classname, "obj_teleporter") == 0)
			|| (strcmp(classname, "prop_dynamic") == 0) || (strcmp(classname, "func_physbox") == 0) || (strcmp(classname, "func_breakable") == 0))
		{
			ResizeTraceFailed = true;
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods8] %s %d stopped trace.", classname, entity);
		}
		else
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods8] Neutral entity %d/%s crossed by trace.", entity, classname);
		}
	}
	else
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods8] Trace picked up Santa Claus, I guess? entity=%d", entity);
	}

	return false;
}

bool:Resize_OneTrace(const Float:startPos[3], const Float:endPos[3])
{
	static Float:result[3];
	TR_TraceRayFilter(startPos, endPos, MASK_PLAYERSOLID, RayType_EndPoint, Resize_TracePlayersAndBuildings);
	if (ResizeTraceFailed)
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods8] Could not resize player. Players are in the way. Offsets: %f, %f, %f", startPos[0] - endPos[0], startPos[1] - endPos[1], startPos[2] - endPos[2]);
		return false;
	}
	TR_GetEndPosition(result);
	if (endPos[0] != result[0] || endPos[1] != result[1] || endPos[2] != result[2])
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods8] Could not resize player. Hit a wall. Offsets: %f, %f, %f", startPos[0] - endPos[0], startPos[1] - endPos[1], startPos[2] - endPos[2]);
		return false;
	}
	
	return true;
}

// the purpose of this method is to first trace outward, upward, and then back in.
bool:Resize_TestResizeOffset(const Float:bossOrigin[3], Float:xOffset, Float:yOffset, Float:zOffset)
{
	static Float:tmpOrigin[3];
	tmpOrigin[0] = bossOrigin[0];
	tmpOrigin[1] = bossOrigin[1];
	tmpOrigin[2] = bossOrigin[2];
	static Float:targetOrigin[3];
	targetOrigin[0] = bossOrigin[0] + xOffset;
	targetOrigin[1] = bossOrigin[1] + yOffset;
	targetOrigin[2] = bossOrigin[2];
	
	if (!(xOffset == 0.0 && yOffset == 0.0))
		if (!Resize_OneTrace(tmpOrigin, targetOrigin))
			return false;
		
	tmpOrigin[0] = targetOrigin[0];
	tmpOrigin[1] = targetOrigin[1];
	tmpOrigin[2] = targetOrigin[2] + zOffset;

	if (!Resize_OneTrace(targetOrigin, tmpOrigin))
		return false;
		
	targetOrigin[0] = bossOrigin[0];
	targetOrigin[1] = bossOrigin[1];
	targetOrigin[2] = bossOrigin[2] + zOffset;
		
	if (!(xOffset == 0.0 && yOffset == 0.0))
		if (!Resize_OneTrace(tmpOrigin, targetOrigin))
			return false;
		
	return true;
}

bool:Resize_TestSquare(const Float:bossOrigin[3], Float:xmin, Float:xmax, Float:ymin, Float:ymax, Float:zOffset)
{
	static Float:pointA[3];
	static Float:pointB[3];
	for (new phase = 0; phase <= 7; phase++)
	{
		// going counterclockwise
		if (phase == 0)
		{
			pointA[0] = bossOrigin[0] + 0.0;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + ymax;
		}
		else if (phase == 1)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + 0.0;
		}
		else if (phase == 2)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + 0.0;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 3)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + 0.0;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 4)
		{
			pointA[0] = bossOrigin[0] + 0.0;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 5)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + 0.0;
		}
		else if (phase == 6)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + 0.0;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + ymax;
		}
		else if (phase == 7)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + 0.0;
			pointB[1] = bossOrigin[1] + ymax;
		}

		for (new shouldZ = 0; shouldZ <= 1; shouldZ++)
		{
			pointA[2] = pointB[2] = shouldZ == 0 ? bossOrigin[2] : (bossOrigin[2] + zOffset);
			if (!Resize_OneTrace(pointA, pointB))
				return false;
		}
	}
		
	return true;
}

public bool:AttemptResize(clientIdx, bool:force, Float:sizeMultiplier)
{
	// trace a hull a miniscule distance from origin. if we can't reach the end, or if we hit a player or building, give up this time
	static Float:playerPos[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", playerPos);
	new Float:existingSize = GetEntPropFloat(clientIdx, Prop_Send, "m_flModelScale");
	if (existingSize >= sizeMultiplier)
	{
		if (PRINT_DEBUG_SPAM)
		{
			PrintToServer("[sarysamods8] Size has not changed or has shrunk. Resize automatically successful. %f vs. %f", existingSize, sizeMultiplier);
			if (GetUserAdmin(clientIdx) != INVALID_ADMIN_ID && existingSize != sizeMultiplier) // only show this debug message to admins, not players.
				PrintCenterText(clientIdx, "resizing from %f to %f", existingSize, sizeMultiplier);
		}
	}
	else
	{
		ResizeTraceFailed = false;
		ResizeMyTeam = GetClientTeam(clientIdx);
		static Float:mins[3];
		static Float:maxs[3];
		mins[0] = -24.0 * sizeMultiplier;
		mins[1] = -24.0 * sizeMultiplier;
		mins[2] = 0.0;
		maxs[0] = 24.0 * sizeMultiplier;
		maxs[1] = 24.0 * sizeMultiplier;
		maxs[2] = 82.0 * sizeMultiplier;

		// the eight 45 degree angles and center, which only checks the z offset
		if (!Resize_TestResizeOffset(playerPos, mins[0], mins[1], maxs[2])) return false;
		if (!Resize_TestResizeOffset(playerPos, mins[0], 0.0, maxs[2])) return false;
		if (!Resize_TestResizeOffset(playerPos, mins[0], maxs[1], maxs[2])) return false;
		if (!Resize_TestResizeOffset(playerPos, 0.0, mins[1], maxs[2])) return false;
		if (!Resize_TestResizeOffset(playerPos, 0.0, 0.0, maxs[2])) return false;
		if (!Resize_TestResizeOffset(playerPos, 0.0, maxs[1], maxs[2])) return false;
		if (!Resize_TestResizeOffset(playerPos, maxs[0], mins[1], maxs[2])) return false;
		if (!Resize_TestResizeOffset(playerPos, maxs[0], 0.0, maxs[2])) return false;
		if (!Resize_TestResizeOffset(playerPos, maxs[0], maxs[1], maxs[2])) return false;
		
		// 22.5 angles as well, for paranoia sake
		if (!Resize_TestResizeOffset(playerPos, mins[0], mins[1] * 0.5, maxs[2])) return false;
		if (!Resize_TestResizeOffset(playerPos, mins[0], maxs[1] * 0.5, maxs[2])) return false;
		if (!Resize_TestResizeOffset(playerPos, maxs[0], mins[1] * 0.5, maxs[2])) return false;
		if (!Resize_TestResizeOffset(playerPos, maxs[0], maxs[1] * 0.5, maxs[2])) return false;
		if (!Resize_TestResizeOffset(playerPos, mins[0] * 0.5, mins[1], maxs[2])) return false;
		if (!Resize_TestResizeOffset(playerPos, maxs[0] * 0.5, mins[1], maxs[2])) return false;
		if (!Resize_TestResizeOffset(playerPos, mins[0] * 0.5, maxs[1], maxs[2])) return false;
		if (!Resize_TestResizeOffset(playerPos, maxs[0] * 0.5, maxs[1], maxs[2])) return false;
		
		// four square tests
		if (!Resize_TestSquare(playerPos, mins[0], maxs[0], mins[1], maxs[1], maxs[2])) return false;
		if (!Resize_TestSquare(playerPos, mins[0] * 0.75, maxs[0] * 0.75, mins[1] * 0.75, maxs[1] * 0.75, maxs[2])) return false;
		if (!Resize_TestSquare(playerPos, mins[0] * 0.5, maxs[0] * 0.5, mins[1] * 0.5, maxs[1] * 0.5, maxs[2])) return false;
		if (!Resize_TestSquare(playerPos, mins[0] * 0.25, maxs[0] * 0.25, mins[1] * 0.25, maxs[1] * 0.25, maxs[2])) return false;
		
		// if we got this far, it succeeded.
		if (PRINT_DEBUG_SPAM)
		{
			PrintToServer("[sarysamods8] Success! Will resize player from %f to %f", existingSize, sizeMultiplier);
			if (GetUserAdmin(clientIdx) != INVALID_ADMIN_ID) // only show this debug message to admins, not players.
				PrintCenterText(clientIdx, "resizing from %f to %f", existingSize, sizeMultiplier);
		}
	}

	SetEntPropFloat(clientIdx, Prop_Send, "m_flModelScale", sizeMultiplier);
	
	return true;
}

public bool:IsSpotSafe(clientIdx, Float:x, Float:y, Float:z, Float:sizeMultiplier)
{
	static Float:playerPos[3];
	playerPos[0] = x;
	playerPos[1] = y;
	playerPos[2] = z;

	ResizeTraceFailed = false;
	ResizeMyTeam = GetClientTeam(clientIdx);
	static Float:mins[3];
	static Float:maxs[3];
	mins[0] = -24.0 * sizeMultiplier;
	mins[1] = -24.0 * sizeMultiplier;
	mins[2] = 0.0;
	maxs[0] = 24.0 * sizeMultiplier;
	maxs[1] = 24.0 * sizeMultiplier;
	maxs[2] = 82.0 * sizeMultiplier;

	// the eight 45 degree angles and center, which only checks the z offset
	if (!Resize_TestResizeOffset(playerPos, mins[0], mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], 0.0, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], maxs[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, 0.0, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, maxs[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], 0.0, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], maxs[1], maxs[2])) return false;

	// 22.5 angles as well, for paranoia sake
	if (!Resize_TestResizeOffset(playerPos, mins[0], mins[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], maxs[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], mins[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], maxs[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0] * 0.5, mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0] * 0.5, mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0] * 0.5, maxs[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0] * 0.5, maxs[1], maxs[2])) return false;

	// four square tests
	if (!Resize_TestSquare(playerPos, mins[0], maxs[0], mins[1], maxs[1], maxs[2])) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.75, maxs[0] * 0.75, mins[1] * 0.75, maxs[1] * 0.75, maxs[2])) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.5, maxs[0] * 0.5, mins[1] * 0.5, maxs[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.25, maxs[0] * 0.25, mins[1] * 0.25, maxs[1] * 0.25, maxs[2])) return false;
	
	return true;
}

/**
 * Safe Resize
 */
public Rage_SafeResize(bossIdx)
{
	new clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	new Float:radius = SR_Radius[clientIdx] * SR_Radius[clientIdx];

	static Float:bossOrigin[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
	for (new target = 1; target < MAX_PLAYERS; target++)
	{
		// basic validity
		if (!IsLivingPlayer(target))
			continue;
		else if (GetClientTeam(target) == BossTeam && SR_ScaleMode[clientIdx] == SR_MODE_PLAYERS)
			continue;
		else if (GetClientTeam(target) == MercTeam && SR_ScaleMode[clientIdx] == SR_MODE_BOSSES)
			continue;
			
		// radius check
		if (radius > 0.0)
		{
			static Float:targetOrigin[3];
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetOrigin);
			if (GetVectorDistance(bossOrigin, targetOrigin, true) > radius)
				continue;
		}
			
		// queue resize for next frame, along with other inits
		SR_SetSizeAt[target] = GetEngineTime();
		SR_PendingSize[target] = SR_ScaleFactor[clientIdx] + (SR_ScaleVariance[clientIdx] == 0.0 ? 0.0 : GetRandomFloat(-SR_ScaleVariance[clientIdx], SR_ScaleVariance[clientIdx]));
		SR_RestoreSizeAt[target] = GetEngineTime() + SR_Duration[clientIdx] + (SR_DurationVariance[clientIdx] == 0.0 ? 0.0 : GetRandomFloat(-SR_DurationVariance[clientIdx], SR_DurationVariance[clientIdx]));
		if (SR_ResizeSlayAt[target] != FAR_FUTURE)
			PrintCenterText(target, " "); // this removes any slay warning message there might be
		SR_ResizeSlayAt[target] = FAR_FUTURE;
		SR_LastWarningNum[target] = SR_SlayGracePeriod;
	}
}

public SR_Tick(clientIdx, Float:curTime)
{
	if (curTime >= SR_SetSizeAt[clientIdx])
	{
		//PrintToServer("%f >= %f also %f for %d", curTime, SR_SetSizeAt[clientIdx], SR_PendingSize[clientIdx], clientIdx);
		if (AttemptResize(clientIdx, false, SR_PendingSize[clientIdx]))
			SR_SetSizeAt[clientIdx] = FAR_FUTURE;
		else
			SR_SetSizeAt[clientIdx] += SR_RETRY_INTERVAL;
	}

	if (curTime >= SR_RestoreSizeAt[clientIdx])
	{
		//PrintToServer("%f >= %f for %d", curTime, SR_RestoreSizeAt[clientIdx], clientIdx);
		if (AttemptResize(clientIdx, false, 1.0))
		{
			if (SR_ResizeSlayAt[clientIdx] != FAR_FUTURE)
				PrintCenterText(clientIdx, " "); // this removes any slay warning message there might be
			SR_ResizeSlayAt[clientIdx] = FAR_FUTURE;
			SR_RestoreSizeAt[clientIdx] = FAR_FUTURE;
		}
		else
		{
			if (curTime >= SR_ResizeSlayAt[clientIdx])
			{
				ForcePlayerSuicide(clientIdx);
			}
			else
			{
				// handle slay
				if (SR_SlayGracePeriod > 0 && GetClientTeam(clientIdx) != BossTeam)
				{
					// initialize slay timer and check said timer
					if (SR_ResizeSlayAt[clientIdx] == FAR_FUTURE)
						SR_ResizeSlayAt[clientIdx] = curTime + float(SR_SlayGracePeriod);
					else if (curTime >= SR_ResizeSlayAt[clientIdx])
					{
						ForcePlayerSuicide(clientIdx);
						SR_RestoreSizeAt[clientIdx] = FAR_FUTURE;
						return;
					}
					
					// print the center text
					if (float(SR_LastWarningNum[clientIdx]) >= SR_ResizeSlayAt[clientIdx] - curTime)
					{
						if (SR_WarningMessage[0] != 0)
							PrintCenterText(clientIdx, SR_WarningMessage, SR_LastWarningNum[clientIdx]);
						SR_LastWarningNum[clientIdx]--;
					}
				}
				
				// if we're here, no slay. so trigger retry
				SR_RestoreSizeAt[clientIdx] += SR_RETRY_INTERVAL;
			}
		}
	}
}

/**
 * Head Collection
 */
public HC_ParseTriplet(bossIdx, const String:ability_name[], paramIdx, Float:triplet[3])
{
	static String:tripletStr[100];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, paramIdx, tripletStr, sizeof(tripletStr));
	static String:tripletStrs[3][32];
	ExplodeString(tripletStr, ";", tripletStrs, 3, 32);
	triplet[0] = StringToFloat(tripletStrs[0]);
	triplet[1] = StringToFloat(tripletStrs[1]);
	triplet[2] = StringToFloat(tripletStrs[2]);
}

// returns count
public HC_GetLivingMercStates(bool:states[MAX_PLAYERS_ARRAY])
{
	new count = 0;
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (IsLivingPlayer(clientIdx) && GetClientTeam(clientIdx) == MercTeam)
		{
			states[clientIdx] = true;
			count++;
		}
		else
			states[clientIdx] = false;
	}
	return count;
}

public Action:HC_OnDeflect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new clientIdx = GetClientOfUserId(GetEventInt(event, "ownerid"));
	if (IsLivingPlayer(clientIdx) && HC_CanUse[clientIdx])
		DT_AdjustCooldownTimer(clientIdx, -HC_PyroTeleportCooldownReduction[clientIdx]);

	return Plugin_Continue;
}

public HC_Initialize()
{
	// need to hook player death, i.e. if heads should be awarded another way
	HookEvent("player_death", HC_PlayerDeath, EventHookMode_Pre);
	
	// hook object deflected to work with the pyro trapping problem
	// I'd rather not make it its own rage when it's so stupid simple
	HookEvent("object_deflected", HC_OnDeflect, EventHookMode_Pre);
	
	// grab our total players for this round now
	static bool:livingStates[MAX_PLAYERS_ARRAY];
	HC_PlayerCount = HC_GetLivingMercStates(livingStates);
	HC_PendingPlayerCount = HC_PlayerCount;
	
	// individual inits
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		// initialize living state for anyone
		if (livingStates[clientIdx])
			HC_PlayerStates[clientIdx] = HC_PS_ALIVE;
		else
			HC_PlayerStates[clientIdx] = HC_PS_NEVER_VALID;
	
		if (!IsLivingPlayer(clientIdx) || !HC_CanUse[clientIdx])
			continue;
		
		new TFClassType:playerClass = TF2_GetPlayerClass(clientIdx);
		new hpMult = (HC_Flags[clientIdx] & HC_FLAG_CONDITION_74) ? 10 : 1;
		if (playerClass == TFClass_DemoMan || playerClass == TFClass_Pyro)
			HC_HPForWeapon[clientIdx] = FF2_GetBossMaxHealth(FF2_GetBossIndex(clientIdx)) - (175 * hpMult);
		else if (playerClass == TFClass_Soldier)
			HC_HPForWeapon[clientIdx] = FF2_GetBossMaxHealth(FF2_GetBossIndex(clientIdx)) - (200 * hpMult);
		else if (playerClass == TFClass_Heavy)
			HC_HPForWeapon[clientIdx] = FF2_GetBossMaxHealth(FF2_GetBossIndex(clientIdx)) - (300 * hpMult);
		else if (playerClass == TFClass_Medic)
			HC_HPForWeapon[clientIdx] = FF2_GetBossMaxHealth(FF2_GetBossIndex(clientIdx)) - (150 * hpMult);
		else
			HC_HPForWeapon[clientIdx] = FF2_GetBossMaxHealth(FF2_GetBossIndex(clientIdx)) - (125 * hpMult);
		
		// allow the various loops to commence
		HC_Initialized[clientIdx] = true;
			
		// add condition 74 (if appropriate) and schedule first person enforcement
		if (HC_Flags[clientIdx] & HC_FLAG_CONDITION_74)
		{
			TF2_AddCondition(clientIdx, TFCond:74, -1.0);
			HC_QueueFPAttempts(clientIdx);
			HC_HPForWeapon[clientIdx] /= 10;
			HC_HPForWeapon[clientIdx] += 1; // this works around rounding issues
		}
		else
			HC_HPForWeapon[clientIdx] += 0;//5; // so my inaccuracies aren't obvious
		
		// scale the player down, if applicable. this must be done BEFORE updating the weapon!
		SetEntPropFloat(clientIdx, Prop_Send, "m_flModelScale", HC_HeightLandmarks[clientIdx][0]);

		// update the weapon
		HC_UpdateWeapon(clientIdx);

		// hook touch for touch drain
		if (HC_CanUse[clientIdx] && (HC_TouchEffectDamage[clientIdx] > 0.0 || HC_TouchEffectUberDrain[clientIdx] > 0.0))
			SDKHook(clientIdx, SDKHook_StartTouch, HC_OnStartTouch);
	}

	// start verifying the dead/living, deal with anomalies
	HC_CheckDeadAt = GetEngineTime();
}

public HC_Cleanup()
{
	// unhook player death and deflected
	UnhookEvent("player_death", HC_PlayerDeath, EventHookMode_Pre);
	UnhookEvent("object_deflected", HC_OnDeflect, EventHookMode_Pre);
	
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!IsClientInGame(clientIdx) || !HC_CanUse[clientIdx])
			continue;
	
		// unhook touch for touch drain
		SDKUnhook(clientIdx, SDKHook_StartTouch, HC_OnStartTouch);
		
		// remove condition 74, so player can see themself. :p
		if (HC_Flags[clientIdx] & HC_FLAG_CONDITION_74)
			TF2_RemoveCondition(clientIdx, TFCond:74);
	}
}

public bool:HC_DrainMedic(clientIdx, medic)
{
	new medigun = GetPlayerWeaponSlot(medic, TFWeaponSlot_Secondary);
	if (IsValidEntity(medigun) && IsInstanceOf(medigun, "tf_weapon_medigun"))
	{
		if (GetEntProp(medigun, Prop_Send, "m_bChargeRelease"))
		{
			if (GetEngineTime() >= HC_TouchEffectImmuneUntil[medic])
			{
				new Float:curCharge = GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel");
				if (curCharge > 1.0)
					SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", fmax(1.0, curCharge - HC_TouchEffectUberDrain[clientIdx]));
				HC_TouchEffectImmuneUntil[medic] = GetEngineTime() + HC_TouchEffectInterval[clientIdx];
			}
			return true;
		}
	}
	return false;
}
			
public Action:HC_OnStartTouch(clientIdx, victim)
{
	if (!IsLivingPlayer(clientIdx))
		return Plugin_Continue;
	if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
		return Plugin_Continue;

	if (TF2_IsPlayerInCondition(victim, TFCond_Ubercharged))
	{
		if (HC_TouchEffectUberDrain[clientIdx] > 0.0)
		{
			// find out who's ubering them. first check self
			if (TF2_GetPlayerClass(victim) == TFClass_Medic)
			{
				if (HC_DrainMedic(clientIdx, victim))
					return Plugin_Continue;
			}
			
			// if we're not there yet, find out which medic is healing this person
			for (new medic = 1; medic < MAX_PLAYERS; medic++)
			{
				if (!IsLivingPlayer(medic) || GetClientTeam(medic) == BossTeam)
					continue;
				else if (TF2_GetPlayerClass(victim) != TFClass_Medic)
					continue;
				
				if (HC_DrainMedic(clientIdx, medic))
					return Plugin_Continue;
			}
		}
	}
	else
	{
		if (HC_TouchEffectDamage[clientIdx] > 0.0 && GetEngineTime() >= HC_TouchEffectImmuneUntil[victim])
		{
			SDKHooks_TakeDamage(victim, clientIdx, clientIdx, HC_TouchEffectDamage[clientIdx], DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
			HC_TouchEffectImmuneUntil[victim] = GetEngineTime() + HC_TouchEffectInterval[clientIdx];
		}
	}
	
	return Plugin_Continue;
}

public HC_UpdateWeapon(clientIdx)
{
	new bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;

	TF2_RemoveWeaponSlot(clientIdx, TFWeaponSlot_Melee);
	new weapon;
	static String:weaponName[MAX_WEAPON_NAME_LENGTH];
	static String:baseWeaponArgs[MAX_WEAPON_ARG_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, HC_STRING, 15, weaponName, MAX_WEAPON_NAME_LENGTH);
	new weaponIdx = FF2_GetAbilityArgument(bossIdx, this_plugin_name, HC_STRING, 16);
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, HC_STRING, 17, baseWeaponArgs, MAX_WEAPON_ARG_LENGTH);
	new visible = FF2_GetAbilityArgument(bossIdx, this_plugin_name, HC_STRING, 18);
	
	// calculate damage and knockback attributes
	new Float:damage, Float:buildingDamage, Float:knockback;
	HC_GetDamageAndKnockback(clientIdx, false, damage, buildingDamage, knockback);
	
	// get damage divisor based on weapon type
	new Float:damageDivisor = 65.0;
	if (HC_WeaponType[clientIdx] == HC_WEAPON_BAT)
		damageDivisor = 35.0;
	else if (HC_WeaponType[clientIdx] == HC_WEAPON_KNIFE)
		damageDivisor = 40.0;
	
	// fix damage for FF2, and get multipliers for it and buildings based on that
	if (HC_Flags[clientIdx] & HC_FLAG_FIX_DAMAGE_TRIPLING)
		damage = fixDamageForFF2(damage);
	new Float:damageMultiplier = damage / damageDivisor;
	new Float:damageNerfMultiplier = (damageMultiplier < 1.0) ? damageMultiplier : 1.0;
	new Float:damageBuffMultiplier = (damageMultiplier >= 1.0) ? damageMultiplier : 1.0;
	new Float:buildingMultiplier = buildingDamage / damage;
	
	// adjust knockback multiplier based on player scale
	// I have a feeling that the multiplier may need to ^4 the scale, due to how 3d scaling works...
	new Float:modelScale = GetEntPropFloat(clientIdx, Prop_Send, "m_flModelScale");
	if (modelScale <= 0.0)
		modelScale = 1.0;
	new Float:knockbackMultiplier = knockback * modelScale;
	
	// forge our arg string. finally.
	static String:weaponArgs[MAX_WEAPON_ARG_LENGTH];
	if (strlen(baseWeaponArgs) > 4)
	{
		Format(weaponArgs, MAX_WEAPON_ARG_LENGTH, "%s ; 1 ; %f ; 2 ; %f ; 252 ; %f ; 137 ; %f ; 26 ; %d", baseWeaponArgs,
						damageNerfMultiplier, damageBuffMultiplier, knockbackMultiplier, buildingMultiplier, HC_HPForWeapon[clientIdx]);
	}
	else
	{
		Format(weaponArgs, MAX_WEAPON_ARG_LENGTH, "1 ; %f ; 2 ; %f ; 252 ; %f ; 137 ; %f ; 26 ; %d",
						damageNerfMultiplier, damageBuffMultiplier, knockbackMultiplier, buildingMultiplier, HC_HPForWeapon[clientIdx]);
	}
	
	weapon = SpawnWeapon(clientIdx, weaponName, weaponIdx, 101, 5, weaponArgs, visible);
	SetEntPropEnt(clientIdx, Prop_Data, "m_hActiveWeapon", weapon);
}

public HC_FirstPerson(clientIdx)
{
	if (HC_Flags[clientIdx] & HC_FLAG_CONDITION_74)
	{
		new flags = GetCommandFlags("firstperson");
		SetCommandFlags("firstperson", flags & ~FCVAR_CHEAT);
		ClientCommand(clientIdx, "firstperson");
		SetCommandFlags("firstperson", flags);
	}
}

public HC_ThirdPerson(clientIdx)
{
	if (HC_Flags[clientIdx] & HC_FLAG_CONDITION_74)
	{
		new flags = GetCommandFlags("thirdperson");
		SetCommandFlags("thirdperson", flags & ~FCVAR_CHEAT);
		ClientCommand(clientIdx, "thirdperson");
		SetCommandFlags("thirdperson", flags);
	}
}

public HC_QueueFPAttempts(clientIdx)
{
	HC_FPRetriesLeft[clientIdx] = 3;
	HC_NextFPRetryAt[clientIdx] = GetEngineTime() + HC_FP_INTERVAL;
}

public Action:HC_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	// exclude dead ringer death
	if ((GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER) != 0)
		return Plugin_Continue;
	
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new killer = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (GetClientTeam(victim) == BossTeam)
		return Plugin_Continue;
		
	new bool:isSuicide = victim == killer || !IsLivingPlayer(killer);
	
	// a player died. assign heads to anyone who can receive them.
	// though there may be special handling for suicides.
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!HC_CanUse[clientIdx] || !HC_Initialized[clientIdx])
			continue;
			
		if ((HC_Flags[clientIdx] & HC_FLAG_SUICIDES_REDUCE_TOTAL) != 0 && isSuicide)
			break;
			
		HC_PlayerStates[victim] = HC_PS_DEAD;
		HC_PendingHeads[clientIdx]++;
	}
	
	return Plugin_Continue;
}

public HC_AttemptResize(clientIdx, bool:force)
{
	// even if force is true, there's no need to resize if these haven't changed
	if (HC_PendingHeads[clientIdx] == HC_CurrentHeads[clientIdx] && HC_PendingPlayerCount == HC_PlayerCount && !HC_ForceReadjust[clientIdx])
		return;
		
	// figure out what size the player needs to be, with the pending number of heads
	new Float:sizeMultiplier = HC_GetSizeMultiplier(clientIdx, true);
	
	// trace a hull a miniscule distance from origin. if we can't reach the end, or if we hit a player or building, give up this time
	if (!AttemptResize(clientIdx, force, sizeMultiplier))
		return;
	
	if (PRINT_DEBUG_SPAM)
		PrintToServer("[sarysamods8] Resize: %d == %d && %d == %d", HC_PendingHeads[clientIdx], HC_CurrentHeads[clientIdx], HC_PendingPlayerCount, HC_PlayerCount);
	
	// display a particle effect if valid
	if (!IsEmptyString(HC_ResizeParticle))
	{
		static Float:bossOrigin[3];
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
		ParticleEffectAt(bossOrigin, HC_ResizeParticle);
	}
	
	// we got this far. all that's left is to update the counts and the player's weapon
	HC_CurrentHeads[clientIdx] = HC_PendingHeads[clientIdx];
	HC_PlayerCount = HC_PendingPlayerCount;
	HC_UpdateWeapon(clientIdx);
	
	// if we're forcing a readjust, stop doing so
	HC_ForceReadjust[clientIdx] = false;
}

public HC_GameFrame(Float:curTime)
{
	// check this once per second
	if (curTime >= HC_CheckDeadAt)
	{
		// this should work both ways, detecting latespawn as well as DC's
		static bool:livingStates[MAX_PLAYERS_ARRAY];
		HC_GetLivingMercStates(livingStates);
		
		// compare lists. if something's wrong, adjust for DC (captured suicide) or latespawn
		new countOffset = 0;
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			// check for latespawn
			if (HC_PlayerStates[clientIdx] == HC_PS_NEVER_VALID && livingStates[clientIdx])
			{
				countOffset++;
				HC_PlayerStates[clientIdx] = HC_PS_ALIVE;

				if (PRINT_DEBUG_SPAM)
					PrintToServer("[sarysamods8] Living player count is wrong! %d latespawned.", clientIdx);
			}
			else if (HC_PlayerStates[clientIdx] == HC_PS_DEAD && livingStates[clientIdx])
			{
				// respawned, kill them
				TF2_RemoveCondition(clientIdx, TFCond_Ubercharged);
				TF2_RemoveCondition(clientIdx, TFCond_UberchargedCanteen);
				TF2_RemoveCondition(clientIdx, TFCond_UberchargedHidden);
				TF2_RemoveCondition(clientIdx, TFCond_UberchargedOnTakeDamage);
				TF2_RemoveCondition(clientIdx, TFCond_Bonked);
				SetEntProp(clientIdx, Prop_Data, "m_takedamage", 2);
				SDKHooks_TakeDamage(clientIdx, clientIdx, clientIdx, 9999.0, DMG_GENERIC, -1);
				static String:cheater[34];
				GetClientName(clientIdx, cheater, sizeof(cheater));
				static String:cheaterId[34];
				GetClientAuthId(clientIdx, AuthId_Engine, cheaterId, sizeof(cheaterId));
				
				// for the sake of any admins present...
				PrintToChatAll("[SM] Automatically slew %s (%s) who somehow respawned.", cheater, cheaterId);
			}
			else if (HC_PlayerStates[clientIdx] == HC_PS_ALIVE && !livingStates[clientIdx])
			{
				countOffset--;
				HC_PlayerStates[clientIdx] = HC_PS_NEVER_VALID;

				if (PRINT_DEBUG_SPAM)
					PrintToServer("[sarysamods8] Living player count is wrong! %d DC'd or suicided (if suicide is handled this way).", clientIdx);
			}
		}

		HC_PendingPlayerCount += countOffset;
	
		HC_CheckDeadAt = curTime + HC_DEAD_INTERVAL;
	}
}

public HC_Tick(clientIdx, Float:curTime)
{
	if (curTime >= HC_NextFPRetryAt[clientIdx])
	{
		HC_FirstPerson(clientIdx);
		if (HC_FPRetriesLeft[clientIdx] > 0)
		{
			HC_FPRetriesLeft[clientIdx]--;
			HC_NextFPRetryAt[clientIdx] = curTime + HC_FP_INTERVAL;
		}
		else
			HC_NextFPRetryAt[clientIdx] = FAR_FUTURE;
	}
	
	if (!HC_Initialized[clientIdx])
		return;
		
	if (curTime >= HC_NextResizeAttemptAt[clientIdx] && !HC_RageDisabledResize[clientIdx])
	{
		HC_AttemptResize(clientIdx, false);
	
		HC_NextResizeAttemptAt[clientIdx] = curTime + HC_RESIZE_INTERVAL;
	}
}

/**
 * Head Collection - Exposed Interfaces, used by rages beneath this one.
 */
public bool:HC_IsInitialized(clientIdx)
{
	return HC_Initialized[clientIdx];
}
 
public HC_BeginConsumptionRage(clientIdx)
{
	HC_RageDisabledResize[clientIdx] = true;
}

public HC_ConsumeHeadMultiplier(clientIdx, Float:amount)
{
	HC_HeadMultiplierReduction[clientIdx] += amount;
}

public HC_EndConsumptionRage(clientIdx)
{
	HC_RageDisabledResize[clientIdx] = false;
	HC_ForceReadjust[clientIdx] = true;
}

public bool:HC_RageInProgress(clientIdx)
{
	return HC_RageDisabledResize[clientIdx];
}

public bool:HC_RageOnCooldown(clientIdx)
{
	return GetEngineTime() < HA_PostRageCooldownUntil[clientIdx];
}

public Float:HC_GetHeadMultiplier(clientIdx, bool:getPending)
{
	new playerCount = getPending ? HC_PendingPlayerCount : HC_PlayerCount;
	new headCount = getPending ? HC_PendingHeads[clientIdx] : HC_CurrentHeads[clientIdx];

	if (playerCount <= 0)
		playerCount = 1; // sanity, would only apply I suppose if everyone suicided
	return (float(headCount) / float(playerCount)) - HC_HeadMultiplierReduction[clientIdx];
}

public Float:HC_GetLandmarkMultiplier(clientIdx, bool:getPending, &arrayOffset)
{
	new Float:headMultiplier = HC_GetHeadMultiplier(clientIdx, getPending);
	if (headMultiplier <= HC_HalfPowerAt[clientIdx])
	{
		arrayOffset = 0;
		return headMultiplier / HC_HalfPowerAt[clientIdx];
	}
	else
	{
		// note, this can and will exceed maximum
		arrayOffset = 1;
		return (headMultiplier - HC_HalfPowerAt[clientIdx]) / (HC_FullPowerAt[clientIdx] - HC_HalfPowerAt[clientIdx]);
	}
}

public HC_GetDamageAndKnockback(clientIdx, bool:getPending, &Float:damage, &Float:buildingDamage, &Float:knockback)
{
	new arrayOffset = 0;
	new Float:landmarkMultiplier = HC_GetLandmarkMultiplier(clientIdx, getPending, arrayOffset);
	
	damage = HC_PlayerDamageLandmarks[clientIdx][0 + arrayOffset] + ((HC_PlayerDamageLandmarks[clientIdx][1 + arrayOffset] - HC_PlayerDamageLandmarks[clientIdx][0 + arrayOffset]) * landmarkMultiplier);
	buildingDamage = HC_BuildingDamageLandmarks[clientIdx][0 + arrayOffset] + ((HC_BuildingDamageLandmarks[clientIdx][1 + arrayOffset] - HC_BuildingDamageLandmarks[clientIdx][0 + arrayOffset]) * landmarkMultiplier);
	knockback = HC_KnockbackLandmarks[clientIdx][0 + arrayOffset] + ((HC_KnockbackLandmarks[clientIdx][1 + arrayOffset] - HC_KnockbackLandmarks[clientIdx][0 + arrayOffset]) * landmarkMultiplier);
	if (HC_Flags[clientIdx] & HC_FLAG_DAMAGE_CEILING)
		damage = fmin(HC_PlayerDamageLandmarks[clientIdx][2], damage);
	if (HC_Flags[clientIdx] & HC_FLAG_BUILDING_DAMAGE_CEILING)
		buildingDamage = fmin(HC_BuildingDamageLandmarks[clientIdx][2], buildingDamage);
	if (HC_Flags[clientIdx] & HC_FLAG_KNOCKBACK_FLOOR)
		knockback = fmax(HC_KnockbackLandmarks[clientIdx][2], knockback);
}

public Float:HC_GetSizeMultiplier(clientIdx, bool:getPending)
{
	new arrayOffset = 0;
	new Float:landmarkMultiplier = HC_GetLandmarkMultiplier(clientIdx, getPending, arrayOffset);

	new Float:sizeMultiplier = HC_HeightLandmarks[clientIdx][0 + arrayOffset] + ((HC_HeightLandmarks[clientIdx][1 + arrayOffset] - HC_HeightLandmarks[clientIdx][0 + arrayOffset]) * landmarkMultiplier);
	if (HC_Flags[clientIdx] & HC_FLAG_HEIGHT_CEILING)
		sizeMultiplier = fmin(HC_HeightLandmarks[clientIdx][2], sizeMultiplier);
	return sizeMultiplier;
}

/**
 * Head Powers (core abilities like SJ, teleport)
 */
// public interface for the HUD as well
public HP_GetExtrasEnabled(clientIdx, &bool:teleportEnabled, &bool:superJumpEnabled, &bool:glideEnabled)
{
	new bool:teleportDisabled = HP_LastPowerLevel[clientIdx] < HP_TeleportPower[clientIdx];
	new bool:superJumpDisabled = HP_LastPowerLevel[clientIdx] < HP_SuperJumpPower[clientIdx];
	new bool:glideDisabled = HP_LastPowerLevel[clientIdx] < HP_GlidePower[clientIdx];

	if (!teleportDisabled && !superJumpDisabled)
	{
		teleportDisabled = HP_SuperJumpPower[clientIdx] > HP_TeleportPower[clientIdx];
		superJumpDisabled = HP_SuperJumpPower[clientIdx] < HP_TeleportPower[clientIdx];
	}
	
	teleportEnabled = !teleportDisabled; superJumpEnabled = !superJumpDisabled; glideEnabled = !glideDisabled;
}

public HP_GetExtraNames(clientIdx, String:teleportName[MAX_TERMINOLOGY_LENGTH], String:superJumpName[MAX_TERMINOLOGY_LENGTH], String:glideName[MAX_TERMINOLOGY_LENGTH])
{
	teleportName = HP_TeleportName;
	superJumpName = HP_SuperJumpName;
	glideName = HP_GlideName;
}
 
public HP_Tick(clientIdx)
{
	if (!HC_IsInitialized(clientIdx))
		return;
	
	new Float:landmarkMultiplier = HC_GetLandmarkMultiplier(clientIdx, false, NULL_CELL);
	new Float:powerLevel = (0.5 * NULL_CELL) + (0.5 * landmarkMultiplier);
	if (powerLevel != HP_LastPowerLevel[clientIdx])
	{
		HP_LastPowerLevel[clientIdx] = powerLevel;
		new bool:teleportEnabled, bool:superJumpEnabled, bool:glideEnabled;
		HP_GetExtrasEnabled(clientIdx, teleportEnabled, superJumpEnabled, glideEnabled);
		
		DD_SetDisabled(clientIdx, !superJumpEnabled, !teleportEnabled, false, !glideEnabled);
	}
}

/**
 * Head Controlled Rage
 */
public HCR_Tick(clientIdx)
{
	if (!HC_IsInitialized(clientIdx))
		return;
		
	new bossIdx = FF2_GetBossIndex(clientIdx);
	
	new Float:landmarkMultiplier = HC_GetLandmarkMultiplier(clientIdx, false, NULL_CELL);
	new Float:powerLevel = (0.5 * NULL_CELL) + (0.5 * landmarkMultiplier);
	if (powerLevel >= HCR_MinPowerLevel[clientIdx])
	{
		if (HC_RageInProgress(clientIdx))
			FF2_SetBossCharge(bossIdx, 0, 25.0);
		else if (HC_RageOnCooldown(clientIdx) || (HCR_RageOnGround[clientIdx] && (GetEntityFlags(clientIdx) & FL_ONGROUND) == 0))
			FF2_SetBossCharge(bossIdx, 0, 50.0);
		else
			FF2_SetBossCharge(bossIdx, 0, 100.0);
	}
	else
		FF2_SetBossCharge(bossIdx, 0, 0.0);
}

/**
 * Head Annihilation
 */
// public interfaces
public HA_GetHAStats(clientIdx, bool:getPending, &Float:damageLinear, &Float:damageFactor, &Float:radius, &Float:castTime, &Float:recovery)
{
	new arrayOffset = 0;
	new Float:landmarkMultiplier = HC_GetLandmarkMultiplier(clientIdx, getPending, arrayOffset);
	
	damageLinear = HA_DamageLandmarks[clientIdx][0 + arrayOffset] + ((HA_DamageLandmarks[clientIdx][1 + arrayOffset] - HA_DamageLandmarks[clientIdx][0 + arrayOffset]) * landmarkMultiplier);
	damageFactor = HA_DamageMultLandmarks[clientIdx][0 + arrayOffset] + ((HA_DamageMultLandmarks[clientIdx][1 + arrayOffset] - HA_DamageMultLandmarks[clientIdx][0 + arrayOffset]) * landmarkMultiplier);
	radius = HA_RadiusLandmarks[clientIdx][0 + arrayOffset] + ((HA_RadiusLandmarks[clientIdx][1 + arrayOffset] - HA_RadiusLandmarks[clientIdx][0 + arrayOffset]) * landmarkMultiplier);
	castTime = HA_CastTimeLandmarks[clientIdx][0 + arrayOffset] + ((HA_CastTimeLandmarks[clientIdx][1 + arrayOffset] - HA_CastTimeLandmarks[clientIdx][0 + arrayOffset]) * landmarkMultiplier);
	recovery = HA_RecoveryLandmarks[clientIdx][0 + arrayOffset] + ((HA_RecoveryLandmarks[clientIdx][1 + arrayOffset] - HA_RecoveryLandmarks[clientIdx][0 + arrayOffset]) * landmarkMultiplier);

	if (HA_Flags[clientIdx] & HA_FLAG_DAMAGE_CAPPED)
	{
		damageLinear = (HA_DamageLandmarks[clientIdx][2] > HA_DamageLandmarks[clientIdx][0]) ? fmin(HA_DamageLandmarks[clientIdx][2], damageLinear) : fmax(HA_DamageLandmarks[clientIdx][2], damageLinear);
		damageFactor = (HA_DamageMultLandmarks[clientIdx][2] > HA_DamageMultLandmarks[clientIdx][0]) ? fmin(HA_DamageMultLandmarks[clientIdx][2], damageFactor) : fmax(HA_DamageMultLandmarks[clientIdx][2], damageFactor);
	}
	if (HA_Flags[clientIdx] & HA_FLAG_RANGE_CAPPED)
		radius = (HA_RadiusLandmarks[clientIdx][2] > HA_RadiusLandmarks[clientIdx][0]) ? fmin(HA_RadiusLandmarks[clientIdx][2], radius) : fmax(HA_RadiusLandmarks[clientIdx][2], radius);
	if (HA_Flags[clientIdx] & HA_FLAG_CAST_TIME_CAPPED)
		castTime = (HA_CastTimeLandmarks[clientIdx][2] > HA_CastTimeLandmarks[clientIdx][0]) ? fmin(HA_CastTimeLandmarks[clientIdx][2], castTime) : fmax(HA_CastTimeLandmarks[clientIdx][2], castTime);
	if (HA_Flags[clientIdx] & HA_FLAG_RECOVERY_TIME_CAPPED)
		recovery = (HA_RecoveryLandmarks[clientIdx][2] > HA_RecoveryLandmarks[clientIdx][0]) ? fmin(HA_RecoveryLandmarks[clientIdx][2], recovery) : fmax(HA_RecoveryLandmarks[clientIdx][2], recovery);
}

public HA_GetExtrasEnabled(clientIdx, bool:getPending, &bool:anemia, &bool:sharedStun, &bool:medigunDrain)
{
	new Float:landmarkMultiplier = HC_GetLandmarkMultiplier(clientIdx, getPending, NULL_CELL);
	new Float:powerLevel = (0.5 * NULL_CELL) + (0.5 * landmarkMultiplier);
	
	anemia = powerLevel >= HA_AnemiaBonusAt[clientIdx];
	sharedStun = powerLevel >= HA_SharedStunBonusAt[clientIdx];
	medigunDrain = powerLevel >= HA_MedigunDrainBonusAt[clientIdx];
}

public HA_GetExtraNames(clientIdx, String:anemiaName[MAX_TERMINOLOGY_LENGTH], String:sharedStunName[MAX_TERMINOLOGY_LENGTH], String:medigunDrainName[MAX_TERMINOLOGY_LENGTH])
{
	anemiaName = HA_AnemiaName;
	sharedStunName = HA_SharedStunName;
	medigunDrainName = HA_MedigunDrainName;
}

public HA_Initialize(clientIdx)
{
	new particle = !IsEmptyString(HA_AttachmentName) ? AttachParticleToAttachment(clientIdx, "", HA_AttachmentName) : -1;
	if (IsValidEntity(particle))
		HA_AttachmentEntRef[clientIdx] = EntIndexToEntRef(particle);
	else
		HA_AttachmentEntRef[clientIdx] = INVALID_ENTREF;
}

// rage activated
public Rage_HeadAnnihilation(clientIdx)
{
	// did it get rejected?
	if (!HA_ActiveThisRound)
		return;

	// sanity, don't let this be activated if the user is not on the ground
	if ((GetEntityFlags(clientIdx) & FL_ONGROUND) == 0)
		return;
		
	// sanity, don't let this be activated while on cooldown
	if (HC_RageOnCooldown(clientIdx))
		return;
		
	// figure out where to spawn the ball
	static Float:spawnPos[3];
	if (HA_AttachmentEntRef[clientIdx] == INVALID_ENTREF || !IsValidEntity(EntRefToEntIndex(HA_AttachmentEntRef[clientIdx])))
	{
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", spawnPos);
		spawnPos[2] += 80 * HC_GetSizeMultiplier(clientIdx, false);
	}
	else
		GetEntPropVector(EntRefToEntIndex(HA_AttachmentEntRef[clientIdx]), Prop_Data, "m_vecAbsOrigin", spawnPos);
	
	// spawn the ball entity, make it very small
	new prop = CreateEntityByName("prop_physics");
	if (!IsValidEntity(prop))
	{
		PrintToServer("[sarysamods8] ERROR: Prop for %s could not be initialized. This shouldn't ever happen.", HA_STRING);
		PrintCenterText(clientIdx, "Error executing rage. Use your RELOAD rage instead.\nPlease report this error on the forums.");
		return;
	}
	SetEntProp(prop, Prop_Data, "m_takedamage", 0);

	// tweak the model (note, its validity has already been verified)
	SetEntityModel(prop, HA_Model);

	// spawn and move it
	DispatchSpawn(prop);
	TeleportEntity(prop, spawnPos, Float:{0.0,0.0,0.0}, Float:{0.0,0.0,0.0});
	SetEntProp(prop, Prop_Data, "m_takedamage", 0);

	// collision, movetype, and scale
	SetEntProp(prop, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
	SetEntProp(prop, Prop_Send, "m_usSolidFlags", 4); // not solid
	SetEntProp(prop, Prop_Send, "m_nSolidType", 0); // not solid
	SetEntityMoveType(prop, MOVETYPE_NONE);
	SetEntPropFloat(prop, Prop_Send, "m_flModelScale", 0.01);
	
	// store the prop's ent ref
	HC_BallEntRef[clientIdx] = EntIndexToEntRef(prop);
	
	// send user into third person
	HC_ThirdPerson(clientIdx);

	// force the user to taunt, since that's part of the aesthetic. enforce it by blocking movement
	if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed))
		TF2_RemoveCondition(clientIdx, TFCond_Dazed);
	TF2_AddCondition(clientIdx, TFCond_MegaHeal, -1.0);
	FakeClientCommand(clientIdx, "taunt");
	SetEntityMoveType(clientIdx, MOVETYPE_NONE);
	
	// put head collection into active rage mode and store the important stats now
	HC_BeginConsumptionRage(clientIdx);
	HA_ConsumptionThisRage[clientIdx] = HC_GetHeadMultiplier(clientIdx, false) * HA_HeadPowerRemovalFactor[clientIdx];
	HA_GetHAStats(clientIdx, false, HA_DamageLinear[clientIdx], HA_DamageFactor[clientIdx], HA_Radius[clientIdx], HA_CastTime[clientIdx], HA_Recovery[clientIdx]);
	HA_GetExtrasEnabled(clientIdx, false, HA_Anemia[clientIdx], HA_SharedStun[clientIdx], HA_MedigunDrain[clientIdx]);
	
	// start and end times
	HA_RageStartedAt[clientIdx] = GetEngineTime();
	HA_RageEndsAt[clientIdx] = HA_RageStartedAt[clientIdx] + HA_CastTime[clientIdx];
	HA_ReenableRageAt[clientIdx] = FAR_FUTURE;
	
	// play the first sound, queue the others
	if (strlen(HA_FirstSound) > 3)
		EmitSoundToAll(HA_FirstSound);
	HA_PlaySecondSoundAt[clientIdx] = HA_RageStartedAt[clientIdx] + (HA_ToNormalSizeFactor[clientIdx] * HA_CastTime[clientIdx]);
	HA_PlayThirdSoundAt[clientIdx] = HA_RageStartedAt[clientIdx] + (HA_ToMaxSizeFactor[clientIdx] * HA_CastTime[clientIdx]);
}

// tick
public HA_Tick(clientIdx, Float:curTime)
{
	if (curTime >= HA_RageStartedAt[clientIdx])
	{
		if (curTime >= HA_PlaySecondSoundAt[clientIdx])
		{
			if (strlen(HA_SecondSound) > 3)
				EmitSoundToAll(HA_SecondSound);
			HA_PlaySecondSoundAt[clientIdx] = FAR_FUTURE;
		}
		
		if (curTime >= HA_PlayThirdSoundAt[clientIdx])
		{
			if (strlen(HA_ThirdSound) > 3)
				EmitSoundToAll(HA_ThirdSound);
			HA_PlayThirdSoundAt[clientIdx] = FAR_FUTURE;
		}
		
		if (curTime >= HA_RageEndsAt[clientIdx])
		{
			HA_RageEndsAt[clientIdx] = FAR_FUTURE;
			HA_RageStartedAt[clientIdx] = FAR_FUTURE;
			
			// play the sound
			if (strlen(HA_FourthSound) > 3)
				EmitSoundToAll(HA_FourthSound);
				
			// setup for effect on players
			new Float:radiusSquared = HA_Radius[clientIdx] * HA_Radius[clientIdx];
			static Float:bossOrigin[3];
			new prop = EntRefToEntIndex(HC_BallEntRef[clientIdx]);
			GetEntPropVector(IsValidEntity(prop) ? prop : clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
			
			// apply damage/effects to players
			for (new victim = 1; victim < MAX_PLAYERS; victim++)
			{
				if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
					continue;
					
				// range check
				static Float:victimOrigin[3];
				GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimOrigin);
				if (GetVectorDistance(bossOrigin, victimOrigin, true) > radiusSquared)
					continue;
					
				// dead ringer needs special damage handling
				new bool:shouldHookDamage = (HA_Flags[clientIdx] & HA_FLAG_HOOKED_DAMAGE) != 0;
				if (!shouldHookDamage && TF2_GetPlayerClass(victim) == TFClass_Spy)
				{
					new invisWatch = GetPlayerWeaponSlot(clientIdx, 4);
					if (IsValidEntity(invisWatch) && GetEntProp(invisWatch, Prop_Send, "m_iItemDefinitionIndex") == 59)
						shouldHookDamage = true;
				}
				
				// apply damage
				new Float:damage = (HA_DamageFactor[clientIdx] * GetEntProp(victim, Prop_Data, "m_iMaxHealth")) + HA_DamageLinear[clientIdx];
				if (shouldHookDamage)
					FullyHookedDamage(victim, clientIdx, clientIdx, fixDamageForFF2(damage), DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
				else
					SDKHooks_TakeDamage(victim, clientIdx, clientIdx, fixDamageForFF2(damage), DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
				
				// after damage, most players will be just flat dead if the player used it correctly.
				// apply various debuffs to the survivors
				if (!IsLivingPlayer(victim))
					continue;
					
				if (HA_Recovery[clientIdx] > 0.0 && HA_SharedStun[clientIdx])
					TF2_StunPlayer(victim, HA_Recovery[clientIdx], 0.0, TF_STUNFLAG_BONKSTUCK | TF_STUNFLAG_NOSOUNDOREFFECT);
					
				if (HA_Anemia[clientIdx])
					SetEntProp(victim, Prop_Send, "m_iHealth", 1);
					
				if (HA_MedigunDrain[clientIdx])
				{
					if (TF2_GetPlayerClass(victim) == TFClass_Medic)
					{
						new medigun = GetPlayerWeaponSlot(victim, TFWeaponSlot_Secondary);
						if (IsValidEntity(medigun) && IsInstanceOf(medigun, "tf_weapon_medigun"))
						{
							if (GetEntProp(medigun, Prop_Send, "m_bChargeRelease"))
								SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", 0.001);
							else
								SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", 0.4);
						}
					}
					else
					{
						// remove other invincibility/defensives
						if (TF2_GetPlayerClass(victim) == TFClass_Spy)
							SetEntPropFloat(victim, Prop_Send, "m_flCloakMeter", 0.001);
						else if (TF2_GetPlayerClass(victim) == TFClass_Scout && TF2_IsPlayerInCondition(victim, TFCond_Bonked))
						{
							TF2_RemoveCondition(victim, TFCond_Bonked);
							if (HA_Flags[clientIdx] & HA_FLAG_FIX_BONK_BLEED)
							{
								SetEntProp(victim, Prop_Data, "m_takedamage", 0);
								CreateTimer(1.0, HA_FixBonkBleed, victim, TIMER_FLAG_NO_MAPCHANGE); // unclean! heathen!
							}
						}
						
						// other conditions to remove, though magic SHOULD ultimately get blocked...
						if (TF2_IsPlayerInCondition(victim, TFCond_Ubercharged)) // companion ubercharge
							TF2_RemoveCondition(victim, TFCond_Ubercharged);
						if (TF2_IsPlayerInCondition(victim, TFCond_UberchargedCanteen)) // is this the magic one?
							TF2_RemoveCondition(victim, TFCond_UberchargedCanteen);
						if (TF2_IsPlayerInCondition(victim, TFCond_UberchargedHidden)) // or is it this?
							TF2_RemoveCondition(victim, TFCond_UberchargedHidden);
						if (TF2_IsPlayerInCondition(victim, TFCond_UberchargedOnTakeDamage)) // probably not this
							TF2_RemoveCondition(victim, TFCond_UberchargedOnTakeDamage);
					}
				}
			}
			
			// remove megaheal and stun the hale
			SetEntityMoveType(clientIdx, MOVETYPE_WALK);
			if (TF2_IsPlayerInCondition(clientIdx, TFCond_MegaHeal))
				TF2_RemoveCondition(clientIdx, TFCond_MegaHeal);
			if (HA_Recovery[clientIdx] > 0.0)
				TF2_StunPlayer(clientIdx, HA_Recovery[clientIdx], 0.0, TF_STUNFLAG_BONKSTUCK | TF_STUNFLAG_NOSOUNDOREFFECT);
				
			// queue reenabling of rage, as well as putting the hale back in 1p
			HA_ReenableRageAt[clientIdx] = curTime + HA_Recovery[clientIdx];
			
			// consume head power and force the hale to be resized
			HC_EndConsumptionRage(clientIdx);
			HC_ConsumeHeadMultiplier(clientIdx, HA_ConsumptionThisRage[clientIdx]);
			HC_BeginConsumptionRage(clientIdx); // gotta keep the hale from raging still
			
			// remove the prop
			if (HC_BallEntRef[clientIdx] != INVALID_ENTREF)
				RemoveEntity(INVALID_HANDLE, HC_BallEntRef[clientIdx]);
			HC_BallEntRef[clientIdx] = INVALID_ENTREF;
			
			// prevent ragespamming
			HA_PostRageCooldownUntil[clientIdx] = curTime + HA_CooldownDuration[clientIdx];
		}
		else
		{
			new prop = EntRefToEntIndex(HC_BallEntRef[clientIdx]);
			if (IsValidEntity(prop))
			{
				// update the model's scale every tick
				new Float:modelScale = GetEntPropFloat(clientIdx, Prop_Send, "m_flModelScale"); // middle size should scale up/down with hale
				new Float:firstResizeEndsAt = HA_RageStartedAt[clientIdx] + (HA_ToNormalSizeFactor[clientIdx] * HA_CastTime[clientIdx]);
				new Float:secondResizeStartsAt = HA_RageStartedAt[clientIdx] + (HA_ToMaxSizeFactor[clientIdx] * HA_CastTime[clientIdx]);
				new Float:maxScale = (HA_MaxResizeFactor[clientIdx] * HA_Radius[clientIdx]) / (HA_ModelRadius[clientIdx] <= 0.0 ? 1.0 : HA_ModelRadius[clientIdx]);
				if (curTime < firstResizeEndsAt && HA_ToNormalSizeFactor[clientIdx] > 0.0)
					modelScale = ((curTime - HA_RageStartedAt[clientIdx]) / (curTime - firstResizeEndsAt)) * modelScale;
				else if (curTime > secondResizeStartsAt && HA_ToMaxSizeFactor[clientIdx] > 0.0 && HA_ToMaxSizeFactor[clientIdx] < 1.0 && maxScale > 1.0)
					modelScale = modelScale + ((maxScale - modelScale) * ((curTime - secondResizeStartsAt) / (HA_RageEndsAt[clientIdx] - secondResizeStartsAt)));
				SetEntPropFloat(prop, Prop_Send, "m_flModelScale", modelScale < 0.01 ? 0.01 : modelScale);
				PrintToServer("modelScale=%f", modelScale);
			}
		}
	}
	
	if (curTime >= HA_ReenableRageAt[clientIdx])
	{
		HC_EndConsumptionRage(clientIdx);
		HC_QueueFPAttempts(clientIdx);
		HA_ReenableRageAt[clientIdx] = FAR_FUTURE;
	}
}

// that awkward moment when a timer ends up being safe and way easier to execute.
public Action:HA_FixBonkBleed(Handle:hTimer, any:victim)
{
	if (IsLivingPlayer(victim))
	{
		if (TF2_IsPlayerInCondition(victim, TFCond_Bleeding))
			TF2_RemoveCondition(victim, TFCond_Bleeding);
		SetEntProp(victim, Prop_Data, "m_takedamage", 2);
	}
	
	return Plugin_Continue;
}


/*
new HA_MaxFogColor[MAX_PLAYERS_ARRAY]; // arg18
*/

/**
 * Head HUDs
 */
public HH_Tick(clientIdx, Float:curTime)
{
	if (curTime >= HH_UpdateAt[clientIdx])
	{
		// display the natural stats HUD, which unquestionably must exist. start by getting natural abilities.
		new bool:teleportEnabled, bool:superJumpEnabled, bool:glideEnabled;
		static String:teleportName[MAX_TERMINOLOGY_LENGTH], String:superJumpName[MAX_TERMINOLOGY_LENGTH], String:glideName[MAX_TERMINOLOGY_LENGTH];
		HP_GetExtrasEnabled(clientIdx, teleportEnabled, superJumpEnabled, glideEnabled);
		HP_GetExtraNames(clientIdx, teleportName, superJumpName, glideName);
		static String:extraList[128];
		Format(extraList, sizeof(extraList), (glideEnabled ? "%s, %s" : "%s"), (teleportEnabled ? teleportName : (superJumpEnabled ? superJumpName : "[NONE]")), glideName);
		
		// get natural stats
		new Float:naturalDamage, Float:naturalBuildingDamage, Float:naturalKnockback, Float:naturalSize;
		HC_GetDamageAndKnockback(clientIdx, false, naturalDamage, naturalBuildingDamage, naturalKnockback);
		naturalSize = HC_GetSizeMultiplier(clientIdx, false);
		new Float:landmarkMultiplier = HC_GetLandmarkMultiplier(clientIdx, false, NULL_CELL);
		new Float:naturalPower = (0.5 * NULL_CELL) + (0.5 * landmarkMultiplier);
		
		// turn natural stuff into a HUD message
		SetHudTextParams(HH_NaturalHudX[clientIdx], HH_NaturalHudY[clientIdx], HH_INTERVAL + 0.05, GetR(HH_NaturalHudColor[clientIdx]), GetG(HH_NaturalHudColor[clientIdx]), GetB(HH_NaturalHudColor[clientIdx]), 192);
		ShowHudText(clientIdx, -1, HH_NaturalHudMessage, naturalPower * 100.0, naturalSize * 100.0, naturalDamage, naturalBuildingDamage, naturalKnockback * 100.0, extraList);
		
		// rage HUD next. get various abilities and stats.
		new Float:damageLinear, Float:damageFactor, Float:radius, Float:castTime, Float:recovery;
		HA_GetHAStats(clientIdx, false, damageLinear, damageFactor, radius, castTime, recovery);
		new bool:anemiaReady, bool:sharedStunReady, bool:medigunDrainReady;
		HA_GetExtrasEnabled(clientIdx, false, anemiaReady, sharedStunReady, medigunDrainReady);
		static String:anemiaName[MAX_TERMINOLOGY_LENGTH], String:sharedStunName[MAX_TERMINOLOGY_LENGTH], String:medigunDrainName[MAX_TERMINOLOGY_LENGTH];
		HA_GetExtraNames(clientIdx, anemiaName, sharedStunName, medigunDrainName);
		
		// get ability string
		extraList = "[NONE]";
		static String:tmpStr[sizeof(extraList)];
		new bool:firstHandled = false;
		for (new i = 0; i < 3; i++)
		{
			static String:oneStr[MAX_TERMINOLOGY_LENGTH];
			new bool:oneBool = false;
			if (i == 0)
			{
				oneStr = anemiaName;
				oneBool = anemiaReady;
			}
			else if (i == 1)
			{
				oneStr = sharedStunName;
				oneBool = sharedStunReady;
			}
			else if (i == 2)
			{
				oneStr = medigunDrainName;
				oneBool = medigunDrainReady;
			}
		
			if (oneBool)
			{
				if (firstHandled)
				{
					tmpStr = extraList;
					Format(extraList, sizeof(extraList), "%s, %s", tmpStr, oneStr);
				}
				else
					extraList = oneStr;
				firstHandled = true;
			}
		}
			
		// format stats string, the result will be part of a greater formatted string
		static String:rageStats[MAX_CENTER_TEXT_LENGTH];
		Format(rageStats, sizeof(rageStats), HH_RageHudStats, damageFactor * 100.0, damageLinear, radius, castTime, recovery, extraList);
			
		// turn rage stuff into a HUD message
		new bossIdx = FF2_GetBossIndex(clientIdx);
		new Float:charge = FF2_GetBossCharge(bossIdx, 0);
		SetHudTextParams(-1.0, HH_RageHudY[clientIdx], HH_INTERVAL + 0.05, GetR(HH_RageHudColor[clientIdx]), GetG(HH_RageHudColor[clientIdx]), GetB(HH_RageHudColor[clientIdx]), 192);
		ShowHudText(clientIdx, -1, "%s\n\n%s\n%s", (charge >= 49.0 ? HH_RageHudDOTMessage : ""), (charge >= 99.0 ? HH_RageHudReady : HH_RageHudNotReady), rageStats);
	
		HH_UpdateAt[clientIdx] = curTime + HH_INTERVAL;
	}
}

/**
 * FNAP Rages
 */
new String:FNAP_BigString[(MAX_MATERIAL_FILE_LENGTH + 1) * FNAP_COUNT];
new String:FNAP_Substrings[FNAP_COUNT][MAX_MATERIAL_FILE_LENGTH];
public FNAP_ReadInts(bossIdx, const String:abilityName[MAX_ABILITY_NAME_LENGTH], argIdx, theArray[FNAP_COUNT])
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, abilityName, argIdx, FNAP_BigString, sizeof(FNAP_BigString));
	ExplodeString(FNAP_BigString, ";", FNAP_Substrings, FNAP_COUNT, MAX_MATERIAL_FILE_LENGTH);
	for (new i = 0; i < FNAP_COUNT; i++)
		theArray[i] = StringToInt(FNAP_Substrings[i]);
}

public FNAP_ReadFloats(bossIdx, const String:abilityName[MAX_ABILITY_NAME_LENGTH], argIdx, Float:theArray[FNAP_COUNT])
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, abilityName, argIdx, FNAP_BigString, sizeof(FNAP_BigString));
	ExplodeString(FNAP_BigString, ";", FNAP_Substrings, FNAP_COUNT, MAX_MATERIAL_FILE_LENGTH);
	for (new i = 0; i < FNAP_COUNT; i++)
		theArray[i] = StringToFloat(FNAP_Substrings[i]);
}

public FNAP_ReadStrings(bossIdx, const String:abilityName[MAX_ABILITY_NAME_LENGTH], argIdx, String:theArray[FNAP_COUNT][], len)
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, abilityName, argIdx, FNAP_BigString, sizeof(FNAP_BigString));
	ExplodeString(FNAP_BigString, ";", FNAP_Substrings, FNAP_COUNT, MAX_MATERIAL_FILE_LENGTH);
	for (new i = 0; i < FNAP_COUNT; i++)
		strcopy(theArray[i], len, FNAP_Substrings[i]);
}

public FNAP_PreThink(clientIdx)
{
	if (!IsLivingPlayer(clientIdx))
		return;

	new Float:speed = FNAP_Speed[FNAP_CurrentLife[clientIdx]];
	if (FNAP_SpeedOverride[clientIdx] > 0.0)
		speed = FNAP_SpeedOverride[clientIdx];
		
	if (GetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed") != speed)
		SetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed", speed);
}

public FNAP_UpdateWeapon(clientIdx)
{
	new curLife = FNAP_CurrentLife[clientIdx];

	TF2_RemoveWeaponSlot(clientIdx, TFWeaponSlot_Melee);
	new weapon;
	weapon = SpawnWeapon(clientIdx, FNAP_WeaponNames[curLife], FNAP_WeaponIndexes[curLife], 101, 5, FNAP_WeaponArgs[curLife], FNAP_WeaponVisibilities[curLife]);
	SetEntPropEnt(clientIdx, Prop_Data, "m_hActiveWeapon", weapon);
}

// the heresy continues...
#define HUD_HIDE_NONE 0
#define HUD_HIDE_ALL (1<<2)
#define HUD_HIDE_AVATAR (1<<3)
#define HUD_HIDE_RETICLE_AVATAR_AMMO (1<<4)
#define HUD_HIDE_POINT_RAGE (1<<6)
#define HUD_HIDE_CHAT (1<<7)
#define HUD_HIDE_RETICLE (1<<8)
public Action:FNAP_RemoveOverlay(Handle:hTimer, any:victim)
{
	if (IsClientInGame(victim))
	{
		new flags = GetCommandFlags("r_screenoverlay");
		SetCommandFlags("r_screenoverlay", flags & ~FCVAR_CHEAT);
		ClientCommand(victim, "r_screenoverlay \"\"");
		SetCommandFlags("r_screenoverlay", flags);
		
		//SetEntProp(victim, Prop_Send, "m_iHideHUD", HUD_HIDE_NONE);
		FF2_SetFF2flags(victim, FF2_GetFF2flags(victim) & (~FF2FLAG_HUDDISABLED));
	}
	return Plugin_Continue;
}

public Action:FNAP_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	// exclude dead ringer death
	if ((GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER) != 0)
		return Plugin_Continue;
	
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientInGame(victim) || GetClientTeam(victim) == BossTeam)
		return Plugin_Continue;
	
	// find the boss
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (IsLivingPlayer(clientIdx) && FNAP_CanUse[clientIdx])
		{
			// overlay
			if (!IsEmptyString(FNAP_Overlays[FNAP_CurrentLife[clientIdx]]))
			{
				new flags = GetCommandFlags("r_screenoverlay");
				SetCommandFlags("r_screenoverlay", flags & ~FCVAR_CHEAT);
				ClientCommand(victim, "r_screenoverlay \"%s.vmt\"", FNAP_Overlays[FNAP_CurrentLife[clientIdx]]);
				SetCommandFlags("r_screenoverlay", flags);
				
				// hide HUD briefly
				//SetEntProp(victim, Prop_Send, "m_iHideHUD", HUD_HIDE_RETICLE_AVATAR_AMMO | HUD_HIDE_POINT_RAGE | HUD_HIDE_CHAT | HUD_HIDE_ALL);
				FF2_SetFF2flags(victim, FF2_GetFF2flags(victim) | FF2FLAG_HUDDISABLED);
				
				CreateTimer(FNAP_OverlayDuration, FNAP_RemoveOverlay, victim, TIMER_FLAG_NO_MAPCHANGE);
			}
			
			// kill sound
			if (strlen(FNAP_DeathSound) > 3)
				EmitSoundToClient(victim, FNAP_DeathSound);
		}
	}
	return Plugin_Continue;
}

public Rage_FNAPRages(clientIdx)
{
	// current life and rage reduction...
	FNAP_CurrentLife[clientIdx]++;
	if (FNAP_RageReductionPerLife[clientIdx] > 0.0 && FNAP_RageReductionPerLife[clientIdx] <= 1.0)
		FNAP_ActualRage[clientIdx] -= (FNAP_ActualRage[clientIdx] * FNAP_RageReductionPerLife[clientIdx]);
		
	// sanity
	if (FNAP_CurrentLife[clientIdx] >= FNAP_COUNT)
	{
		PrintToServer("[sarysamods8] ERROR: FNAP lives somehow exceeded maximum.");
		FNAP_CurrentLife[clientIdx] = FNAP_COUNT - 1;
	}
	new curLife = FNAP_CurrentLife[clientIdx];
		
	// change model if applicable
	if (strlen(FNAP_Models[curLife]) > 3)
	{
		SetVariantString(FNAP_Models[curLife]);
		AcceptEntityInput(clientIdx, "SetCustomModel");
		SetEntProp(clientIdx, Prop_Send, "m_bUseClassAnimations", 1);
	}
	
	// change their mobility option
	DD_SetDisabled(clientIdx, FNAP_IsSuperJump[curLife] != 1, FNAP_IsSuperJump[curLife] == 1, false, false);
	DJ_CooldownUntil(clientIdx, FAR_FUTURE);
	DT_CooldownUntil(clientIdx, FAR_FUTURE);

	// fix stats on teleport, because these stats are corrupted by some variants
	DT_ChangeFundamentalStats(clientIdx, FNAP_TeleportChargeTime[clientIdx], FNAP_TeleportCooldown[clientIdx], FNAP_TeleportStun[clientIdx]);
	if (FNAP_IsCurrentRage(clientIdx, IT_STRING)) // special for pinkie's rage
		IT_GiveTeleports(clientIdx, FNAP_PinkieTeleportDefault[clientIdx]);
	else
		DT_SetUsesRemaining(clientIdx, 9999999);

	// show time HUD message
	FNAP_ShowTimeHUDUntil = GetEngineTime() + FNAP_TimeHudDuration;
	
	// change weapon last
	FNAP_UpdateWeapon(clientIdx);
}

public Rage_FNAPSentryStun(clientIdx)
{
	new curLife = FNAP_CurrentLife[clientIdx];
	if (FNAP_SentryStunRadius[curLife] > 0.0 && FNAP_SentryStunDuration[curLife] > 0.0)
		DSSG_PerformStun(clientIdx, FNAP_SentryStunRadius[curLife], FNAP_SentryStunDuration[curLife]);
}

public FNAP_Tick(Float:curTime)
{
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!IsLivingPlayer(clientIdx) || GetClientTeam(clientIdx) != BossTeam)
			continue;
		else if (!FNAP_CanUse[clientIdx])
			continue;
	
		// constantly rob the bank of FF2 rage, and translate it into actual rage
		new curLife = FNAP_CurrentLife[clientIdx];
		new bossIdx = FF2_GetBossIndex(clientIdx);
		new Float:rage = FF2_GetBossCharge(bossIdx, 0);
		if (FNAP_ActualRage[clientIdx] >= 100.0)
		{
			if (rage < 100.0) // some rage reduction thing was used on the hale
			{
				FNAP_ActualRage[clientIdx] = rage;
				FF2_SetBossCharge(bossIdx, 0, 0.0);
			}
		}
		else
		{
			FNAP_ActualRage[clientIdx] += rage * (FNAP_RAGEDAMAGE / FNAP_RageDamage[curLife]);
			if (FNAP_ActualRage[clientIdx] >= 100.0)
				FF2_SetBossCharge(bossIdx, 0, 100.0);
			else
				FF2_SetBossCharge(bossIdx, 0, 0.0);
		}

		// update the HUD
		if (curTime >= FNAP_UpdateHUDAt[clientIdx])
		{
			// per-subboss HUD
			SetHudTextParams(-1.0, FNAP_DescHudY[clientIdx], FNAP_HUD_INTERVAL + 0.05, 64, 255, 64, 192);
			new currentLifeMaxHP = FF2_GetBossMaxHealth(bossIdx);
			new currentLifeHP = GetEntProp(clientIdx, Prop_Data, "m_iHealth") - ((5 - curLife) * currentLifeMaxHP);
			//PrintToServer("health=%d   curLife=%d   curMaxHP=%d", GetEntProp(clientIdx, Prop_Data, "m_iHealth"), curLife, currentLifeMaxHP);
			new hpPercent = (currentLifeMaxHP > 0 ? min(100, max(1, (currentLifeHP * 100 / currentLifeMaxHP) + 1)) : 100);
			static String:fullText[512];
			//static String:lineOneTwo[256];
			//static String:lineThreeFour[256];
			if (FNAP_IsCurrentRage(clientIdx, SBV_STRING))
				Format(fullText, sizeof(fullText), FNAP_DescHuds[curLife], GetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed"), hpPercent);
			else
				Format(fullText, sizeof(fullText), FNAP_DescHuds[curLife], hpPercent);
			//new newlinePos = -1;
			//new newlineCount = 0;
			//new ftStrlen = strlen(fullText);
			//for (new i = 0; i < ftStrlen; i++)
			//{
			//	if (fullText[i] == '\n')
			//	{
			//		newlineCount++;
			//		if (newlineCount == 2)
			//		{
			//			newlinePos = i;
			//			break;
			//		}
			//	}
			//}
			
			//if (newlinePos != -12)
			ShowHudText(clientIdx, -1, fullText);
			//else
			//{
			//	lineThreeFour[0] = lineThreeFour[1] = '\n';
			//	for (new i = 0; i < ftStrlen + 1; i++) // gotta copy the null terminator
			//	{
			//		if (i < newlinePos)
			//			lineOneTwo[i] = fullText[i];
			//		else if (i == newlinePos)
			//			lineOneTwo[i] = 0;
			//		else if (i > newlinePos)
			//			lineThreeFour[i - (newlinePos - 1)] = fullText[i];
			//	}
			//	ShowHudText(clientIdx, -1, lineOneTwo);
			//	ShowHudText(clientIdx, -1, lineThreeFour);
			//}

			// rage HUD
			if (FNAP_ActualRage[clientIdx] >= 100.0)
			{
				SetHudTextParams(-1.0, FNAP_HudY[clientIdx], FNAP_HUD_INTERVAL + 0.05, 255, 64, 64, 192);
				ShowHudText(clientIdx, -1, FNAP_ReadyStr);
			}
			else
			{
				SetHudTextParams(-1.0, FNAP_HudY[clientIdx], FNAP_HUD_INTERVAL + 0.05, 255, 255, 255, 192);
				ShowHudText(clientIdx, -1, FNAP_NotReadyStr, FNAP_ActualRage[clientIdx]);
			}
			FNAP_UpdateHUDAt[clientIdx] = curTime + FNAP_HUD_INTERVAL;
			
			// time HUD (non-boss only)
			if (FNAP_ShowTimeHUDUntil > curTime)
			{
				new timeDisplay = (curLife == 0) ? 12 : curLife;
				for (new victim = 1; victim < MAX_PLAYERS; victim++)
				{
					if (IsLivingPlayer(victim) && GetClientTeam(victim) != BossTeam)
					{
						SetHudTextParams(FNAP_TimeHudX, FNAP_TimeHudY, FNAP_HUD_INTERVAL + 0.05, 255, 255, 255, 192);
						ShowHudText(victim, -1, FNAP_TimeHudMessage, timeDisplay);
					}
				}
			}
		}
	}
}

// PUBLIC INTERFACES
public bool:FNAP_IsCurrentRage(clientIdx, const String:abilityName[])
{
	return strcmp(FNAP_Rages[FNAP_CurrentLife[clientIdx]], abilityName) == 0;
}

public FNAP_SetSpeedOverride(clientIdx, Float:speed)
{
	FNAP_SpeedOverride[clientIdx] = speed;
}

/**
 * Prop Buff
 */
public Rage_PropBuff(clientIdx)
{
	if (PB_IsFNAP[clientIdx] && !FNAP_IsCurrentRage(clientIdx, PB_STRING))
		return;
		
	// do nothing if max props have been reached
	new firstAvailable = 0;
	new spawnCount = GetRandomInt(PB_MinToSpawn[clientIdx], PB_MaxToSpawn[clientIdx]);
	for (new derp = 0; derp < spawnCount; derp++)
	{
		for (; firstAvailable <= MAX_PROPS; firstAvailable++)
		{
			if (firstAvailable == MAX_PROPS)
				break;
			if (PBP_EntRef[firstAvailable] == INVALID_ENTREF)
				break;
		}
		
		// no more available to spawn
		if (firstAvailable == MAX_PROPS)
			break;

		// create a prop and toss it
		static Float:spawnPos[3];
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", spawnPos);
		spawnPos[2] += 30.0;
		static Float:velocity[3];
		velocity[0] = GetRandomFloat(-PB_MaxXYVelocity[clientIdx], PB_MaxXYVelocity[clientIdx]);
		velocity[1] = GetRandomFloat(-PB_MaxXYVelocity[clientIdx], PB_MaxXYVelocity[clientIdx]);
		velocity[2] = 325.0;
		new prop = CreateEntityByName("prop_physics_override");
		if (!IsValidEntity(prop))
			return;
		SetEntProp(prop, Prop_Data, "m_takedamage", 0);

		// tweak the model (note, its validity has already been verified)
		SetEntityModel(prop, PB_Model);

		// spawn and move it
		DispatchSpawn(prop);
		TeleportEntity(prop, spawnPos, Float:{0.0,0.0,0.0}, velocity);
		SetEntProp(prop, Prop_Data, "m_takedamage", 0);

		// collision, movetype, and scale
		SetEntProp(prop, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
		//SetEntProp(prop, Prop_Send, "m_usSolidFlags", 4); // not solid
		//SetEntProp(prop, Prop_Send, "m_nSolidType", 0); // not solid

		// keep track of this prop
		PBP_EntRef[firstAvailable] = EntIndexToEntRef(prop);
		PBP_CollisionTestAt[firstAvailable] = PBP_ActivateAt[firstAvailable] = GetEngineTime() + PB_ActivationDelay[clientIdx];
		PBP_Creator[firstAvailable] = clientIdx;
		PBP_StopMovementAt[firstAvailable] = GetEngineTime() + 3.0;
	}
	
	// oh hey, nothing went wrong. play the mapwide sound.
	if (strlen(PB_Sound) > 3)
		EmitSoundToAll(PB_Sound);
}

public PB_RemoveObject(index)
{
	RemoveEntity(INVALID_HANDLE, PBP_EntRef[index]);
	PBP_EntRef[index] = INVALID_ENTREF;
	
	for (new i = index; i < MAX_PROPS - 1; i++)
	{
		PBP_EntRef[i] = PBP_EntRef[i + 1];
		PBP_ActivateAt[i] = PBP_ActivateAt[i + 1];
		PBP_Creator[i] = PBP_Creator[i + 1];
		PBP_CollisionTestAt[i] = PBP_CollisionTestAt[i + 1];
		PBP_StopMovementAt[i] = PBP_StopMovementAt[i + 1];
	}
	
	PBP_EntRef[MAX_PROPS - 1] = INVALID_ENTREF;
}

public PB_Tick(Float:curTime)
{
	// perform collision tests, remove dead objects if they exist...
	for (new i = MAX_PROPS - 1; i >= 0; i--)
	{
		if (PBP_EntRef[i] == INVALID_ENTREF)
			continue;
			
		new prop = EntRefToEntIndex(PBP_EntRef[i]);
		if (!IsValidEntity(prop) || !IsLivingPlayer(PBP_Creator[i]))
		{
			PB_RemoveObject(i);
			continue;
		}
		
		if (curTime >= PBP_ActivateAt[i] && curTime >= PBP_CollisionTestAt[i])
		{
			// test the owner's position
			new clientIdx = PBP_Creator[i];
			static Float:ownerPos[3];
			static Float:propPos[3];
			GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", ownerPos);
			GetEntPropVector(prop, Prop_Send, "m_vecOrigin", propPos);
			
			if (CylinderCollision(propPos, ownerPos, PB_ObjRadius[clientIdx], propPos[2] - 83.0, propPos[2] + PB_ObjHeight[clientIdx]))
			{
				// apply random conditions
				static bool:spent[MAX_CONDITIONS];
				for (new cond = 0; cond < MAX_CONDITIONS; cond++)
					spent[cond] = false;
				new conditionsAvailable = PB_NumConditions[clientIdx];
				new conditionsRemaining = GetRandomInt(PB_MinConditions[clientIdx], PB_MaxConditions[clientIdx]);
				while (conditionsRemaining > 0)
				{
					new condRand = GetRandomInt(0, conditionsAvailable - 1);
					for (new cond = 0; cond < PB_NumConditions[clientIdx]; cond++)
					{
						if (condRand == 0 && !spent[cond])
						{
							spent[cond] = true;
							TF2_AddCondition(clientIdx, TFCond:PB_PossibleConditions[clientIdx][cond], -1.0);
							PB_RemoveConditionAt[clientIdx][cond] = curTime + PB_Duration[clientIdx];
							conditionsAvailable--;
							break;
						}
						
						if (!spent[cond])
							condRand--;
					}
					conditionsRemaining--;
				}
				
				// this prop has been spent...
				PB_RemoveObject(i);
				continue;
			}
			
			PBP_CollisionTestAt[i] = curTime + 0.01;
		}
		
		if (curTime >= PBP_StopMovementAt[i])
		{
			PBP_StopMovementAt[i] = FAR_FUTURE;
			SetEntityMoveType(prop, MOVETYPE_NONE);
		}
	}
	
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (PB_CanUse[clientIdx])
		{
			// when it's time for conditions to expire...
			for (new i = 0; i < MAX_CONDITIONS; i++)
			{
				if (curTime >= PB_RemoveConditionAt[clientIdx][i])
				{
					if (TF2_IsPlayerInCondition(clientIdx, TFCond:PB_PossibleConditions[clientIdx][i]))
						TF2_RemoveCondition(clientIdx, TFCond:PB_PossibleConditions[clientIdx][i]);
					PB_RemoveConditionAt[clientIdx][i] = FAR_FUTURE;
				}
			}
		}
	}
}

/**
 * Pickup Trap
 */
public PT_ItemPickup(const String:output[], caller, victim, Float:delay)
{
	if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
		return;
		
	// is this item trapped?
	for (new i = 0; i < MAX_TRAPS; i++)
	{
		if (PTT_EntRef[i] == INVALID_ENTREF)
			continue;
		else if (!IsLivingPlayer(PTT_Trapper[i]))
			continue;
			
		if (EntRefToEntIndex(PTT_EntRef[i]) == caller)
		{
			// before any of this, change the color back...
			SetEntityRenderColor(caller, 255, 255, 255, 255);
		
			static String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
			GetEntityClassname(caller, classname, sizeof(classname));
			if (!strcmp(classname, "item_ammopack_small"))
			{
				new Float:ammoFactor = 1.0 - PT_TrapAmmoNerfAmount[PTT_Trapper[i]];
				for (new slot = 0; slot < 2; slot++)
				{
					new weapon = GetPlayerWeaponSlot(victim, slot);
					if (IsValidEntity(weapon))
					{
						new offset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1);
						if (offset < 0)
							continue;
							
						if (GetEntProp(victim, Prop_Send, "m_iAmmo", 4, offset) > 1)
							SetEntProp(victim, Prop_Send, "m_iAmmo", RoundFloat(GetEntProp(victim, Prop_Send, "m_iAmmo", 4, offset) * ammoFactor), 4, offset);
						if (GetEntProp(weapon, Prop_Send, "m_iClip1") > 1 && GetEntProp(weapon, Prop_Send, "m_iClip1") < 128)
							SetEntProp(weapon, Prop_Send, "m_iClip1", RoundFloat(GetEntProp(weapon, Prop_Send, "m_iClip1") * ammoFactor));
						//SetEntProp(weapon, Prop_Send, "m_iClip2", RoundFloat(GetEntProp(weapon, Prop_Send, "m_iClip2") * ammoFactor));
					}
				}
				
				// if it's an engineer, drain metal
				if (TF2_GetPlayerClass(victim) == TFClass_Engineer)
				{
					new metalOffset = FindDataMapOffs(victim, "m_iAmmo") + (3 * 4);
					SetEntData(victim, metalOffset, RoundFloat(GetEntData(victim, metalOffset, 4) * ammoFactor), 4);
				}
			}
			else
			{
				new Float:hpDrain = 0.2;
				if (!strcmp(classname, "item_healthkit_medium"))
					hpDrain = 0.5;
				else if (!strcmp(classname, "item_healthkit_large"))
					hpDrain = 1.0;
				hpDrain *= PT_TrapHealthNerfAmount[PTT_Trapper[i]];
					
				new Float:damage = ((float(GetEntProp(victim, Prop_Data, "m_iMaxHealth")) * hpDrain) / 3.0) + 1.0;
				damage = fixDamageForFF2(damage);
				if (PRINT_DEBUG_SPAM)
					PrintToServer("[sarysamods8] Will damage %d HP victim for %f", GetEntProp(victim, Prop_Data, "m_iMaxHealth"), damage);
				FullyHookedDamage(victim, PTT_Trapper[i], PTT_Trapper[i], damage, DMG_GENERIC | DMG_CRIT | DMG_PREVENT_PHYSICS_FORCE, -1);
			}
			
			// permanently remove the resource
			AcceptEntityInput(caller, "kill");
			
			PT_RemoveObject(i);
			break;
		}
	}
}

public Rage_PickupTrap(clientIdx)
{
	if (PT_IsFNAP[clientIdx] && !FNAP_IsCurrentRage(clientIdx, PT_STRING))
		return;
	
	new firstAvailable = 0;
	for (new derp = 0; derp < PT_TrapCount[clientIdx]; derp++)
	{
		// find first available
		for (; firstAvailable <= MAX_TRAPS; firstAvailable++)
		{
			if (firstAvailable == MAX_TRAPS)
				break;
			if (PTT_EntRef[firstAvailable] == INVALID_ENTREF)
				break;
		}
		
		// max reached
		if (firstAvailable == MAX_TRAPS)
			break;
			
		// iterate through potential entities for trapping...
		static potentials[200];
		new validCount = 0;
		static String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
		for (new pass = 0; pass < 4; pass++)
		{
			new entity = -1;
			if (pass == 0)
				classname = "item_ammopack_small";
			else if (pass == 1)
				classname = "item_healthkit_small";
			else if (pass == 2)
				classname = "item_healthkit_medium";
			else if (pass == 3)
				classname = "item_healthkit_large";

			while ((entity = FindEntityByClassname(entity, classname)) != -1)
			{
				new bool:tryNextObject = false;
				for (new i = 0; i < MAX_TRAPS; i++)
				{
					if (PTT_EntRef[i] != INVALID_ENTREF && EntRefToEntIndex(PTT_EntRef[i]) == entity)
					{
						tryNextObject = true;
						break;
					}
					else if (PTT_EntRef[i] == INVALID_ENTREF)
						break; // we reached the end, it's the whole point of me maintaining the list...
				}
				
				if (tryNextObject)
					continue;
					
				potentials[validCount] = entity;
				validCount++;
			}
		}
		
		// are we out of packs to trap?
		if (validCount == 0)
		{
			if (PRINT_DEBUG_INFO)
				PrintToServer("[sarysamods8] No health or ammo packs remaining to trap.");
			break;
		}
		
		// trap our object
		new trappedObject = potentials[GetRandomInt(0, validCount - 1)];
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods8] Will trap object %d", trappedObject);
		SetEntityRenderMode(trappedObject, RENDER_TRANSCOLOR);
		SetEntityRenderColor(trappedObject, GetR(PT_TrappedObjectRecolor[clientIdx]), GetG(PT_TrappedObjectRecolor[clientIdx]), GetB(PT_TrappedObjectRecolor[clientIdx]), 255);
		PTT_EntRef[firstAvailable] = EntIndexToEntRef(trappedObject);
		PTT_Trapper[firstAvailable] = clientIdx;
		PTT_TrappedUntil[firstAvailable] = GetEngineTime() + PT_Duration[clientIdx];
	}

	// dispenser harm
	if (PT_DispenserHarmDuration[clientIdx] > 0.0)
	{
		PT_DispensersAreHarmful = true;
		PT_DispensersHarmUntil = GetEngineTime() + PT_DispenserHarmDuration[clientIdx];
		PT_DispenserCheckAt = GetEngineTime() + PT_DispenserHarmInterval;
	}
		
	// play the mapwide sound.
	if (strlen(PT_Sound) > 3)
		EmitSoundToAll(PT_Sound);
}

public PT_RemoveObject(index)
{
	for (new i = index; i < MAX_TRAPS - 1; i++)
	{
		PTT_EntRef[i] = PTT_EntRef[i + 1];
		PTT_Trapper[i] = PTT_Trapper[i + 1];
		PTT_TrappedUntil[i] = PTT_TrappedUntil[i + 1];
	}
	
	PTT_EntRef[MAX_TRAPS - 1] = INVALID_ENTREF;
}

public PT_Tick(Float:curTime)
{
	// check all players being healed and damage them if a dispenser's healing them
	if (PT_DispensersAreHarmful)
	{
		if (curTime >= PT_DispensersHarmUntil)
		{
			PT_DispensersAreHarmful = false;
		
			// remove recoloring on dispensers
			new dispenser = -1;
			while ((dispenser = FindEntityByClassname(dispenser, "obj_dispenser")) != -1)
			{
				SetEntityRenderMode(dispenser, RENDER_TRANSCOLOR);
				SetEntityRenderColor(dispenser, 255, 255, 255, 255);
			}
		}
		else if (curTime >= PT_DispenserCheckAt)
		{
			PT_DispenserCheckAt += PT_DispenserHarmInterval;
		
			// enforce recoloring of dispensers
			new dispenser = -1;
			while ((dispenser = FindEntityByClassname(dispenser, "obj_dispenser")) != -1)
			{
				SetEntityRenderMode(dispenser, RENDER_TRANSCOLOR);
				SetEntityRenderColor(dispenser, 0, 0, 0, 255);
			}

			static medicHealCount[MAX_PLAYERS_ARRAY];
			for (new victim = 1; victim < MAX_PLAYERS; victim++)
				medicHealCount[victim] = 0;
			for (new medic = 1; medic < MAX_PLAYERS; medic++)
			{
				if (!IsLivingPlayer(medic) || GetClientTeam(medic) == BossTeam)
					continue;
				else if (TF2_GetPlayerClass(medic) != TFClass_Medic)
					continue;

				new medigun = GetPlayerWeaponSlot(medic, TFWeaponSlot_Secondary);
				if (IsValidEntity(medigun) && IsInstanceOf(medigun, "tf_weapon_medigun"))
				{
					new partner = GetEntProp(medigun, Prop_Send, "m_hHealingTarget") & 0x3ff;
					if (IsLivingPlayer(partner))
						medicHealCount[partner]++;
				}
			}

			new attacker = FindRandomPlayer(true);
			if (IsLivingPlayer(attacker)) for (new victim = 1; victim < MAX_PLAYERS; victim++)
			{
				if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
					continue;

				new stacks = GetEntProp(victim, Prop_Send, "m_nNumHealers") - medicHealCount[victim];
				if (stacks > 0)
				{
					if (PRINT_DEBUG_SPAM)
						PrintToServer("[sarysamods8] Will damage %d, being healed by spencer pootis. (stacks=%d)", victim, stacks);
					QuietDamage(victim, attacker, attacker, PT_DispenserHarmDamage * stacks, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
				}
			}
		}
	}

	if (PTT_TrapsNeverExpire)
		return;
		
	for (new i = MAX_TRAPS - 1; i >= 0; i--)
	{
		if (PTT_EntRef[i] != INVALID_ENTREF && curTime >= PTT_TrappedUntil[i])
			PT_RemoveObject(i);
	}
}

/**
 * Speed by Views
 */
public SBV_PreThink(clientIdx)
{
	if (!IsLivingPlayer(clientIdx))
		return;

	if (GetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed") != SBV_LastSpeed[clientIdx])
		SetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed", SBV_LastSpeed[clientIdx]);
}

public SBV_RemoveOverlayForAll()
{
	for (new victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (IsClientInGame(victim))
		{
			new flags = GetCommandFlags("r_screenoverlay");
			SetCommandFlags("r_screenoverlay", flags & ~FCVAR_CHEAT);
			ClientCommand(victim, "r_screenoverlay \"\"");
			SetCommandFlags("r_screenoverlay", flags);
		}
	}
}
 
public Rage_SpeedByViews(clientIdx)
{
	if (SBV_IsFNAP && !FNAP_IsCurrentRage(clientIdx, SBV_STRING))
		return;
	
	// most complicated rage ever.
	SBV_RageUntil[clientIdx] = GetEngineTime() + SBV_Duration[clientIdx];
	
	// forgot about this...
	if (!IsEmptyString(SBV_Overlay))
	{
		for (new victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
				continue;
				
			new flags = GetCommandFlags("r_screenoverlay");
			SetCommandFlags("r_screenoverlay", flags & ~FCVAR_CHEAT);
			ClientCommand(victim, "r_screenoverlay \"%s.vmt\"", SBV_Overlay);
			SetCommandFlags("r_screenoverlay", flags);
		}
	}
	
	// oh yeah, and this...
	if (strlen(SBV_Sound) > 3)
		EmitSoundToAll(SBV_Sound);
}

public SBV_Tick(clientIdx, Float:curTime)
{
	if (curTime >= SBV_RageUntil[clientIdx] && SBV_RageUntil[clientIdx] != 0.0)
	{
		// remove the overlay
		SBV_RemoveOverlayForAll();
		SBV_RageUntil[clientIdx] = 0.0;
	}

	if (SBV_RageUntil[clientIdx] > curTime)
		SBV_LastSpeed[clientIdx] = SBV_MaxSpeed[clientIdx];
	else if (SBV_IsFNAP && !FNAP_IsCurrentRage(clientIdx, SBV_STRING))
		SBV_LastSpeed[clientIdx] = 0.0;
	else if (curTime >= SBV_RecalculateAt[clientIdx])
	{		
		new totalLiving = 0;
		new totalViewing = 0;
		new Float:bossPos[3];
		GetClientEyePosition(clientIdx, bossPos);
		for (new enemy = 1; enemy < MAX_PLAYERS; enemy++)
		{
			if (!IsLivingPlayer(enemy) || GetClientTeam(enemy) == BossTeam)
				continue;
				
			totalLiving++;
				
			static Float:enemyPos[3];
			static Float:enemyAngles[3];
			GetClientEyePosition(enemy, enemyPos);
			GetClientEyeAngles(enemy, enemyAngles);
			static Float:anglesToBoss[3];
			GetVectorAnglesTwoPoints(enemyPos, bossPos, anglesToBoss);
			
			// fix all angles
			enemyAngles[0] = fixAngle(enemyAngles[0]);
			enemyAngles[1] = fixAngle(enemyAngles[1]);
			anglesToBoss[0] = fixAngle(anglesToBoss[0]);
			anglesToBoss[1] = fixAngle(anglesToBoss[1]);
			
			// verify angle validity
			if (!(fabs(enemyAngles[0] - anglesToBoss[0]) <= SBV_MaxAnglePitch[clientIdx] ||
					(fabs(enemyAngles[0] - anglesToBoss[0]) >= (360.0 - SBV_MaxAnglePitch[clientIdx]))))
				continue;
			if (!(fabs(enemyAngles[1] - anglesToBoss[1]) <= SBV_MaxAngleYaw[clientIdx] ||
					(fabs(enemyAngles[1] - anglesToBoss[1]) >= (360.0 - SBV_MaxAngleYaw[clientIdx]))))
				continue;
				
			// ensure no wall is obstructing
			static Float:result[3];
			TR_TraceRayFilter(enemyPos, bossPos, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_EndPoint, TraceWallsOnly);
			TR_GetEndPosition(result);
			if (result[0] != bossPos[0] || result[1] != bossPos[1] || result[2] != bossPos[2])
				continue;
			
			// success...for this one person.
			totalViewing++;
		}
		
		if (totalLiving > 0)
		{
			new trueMax = min(totalLiving, SBV_MaxPlayers[clientIdx]);
			new trueViewers = min(totalViewing, SBV_MaxPlayers[clientIdx]);
			new Float:speedFactor = 1.0 - (float(trueViewers) / float(trueMax));
			SBV_LastSpeed[clientIdx] = SBV_MinSpeed[clientIdx] + ((SBV_MaxSpeed[clientIdx] - SBV_MinSpeed[clientIdx]) * speedFactor);
		}
	
		SBV_RecalculateAt[clientIdx] = curTime + SBV_Interval[clientIdx];
	}
	
	FNAP_SetSpeedOverride(clientIdx, SBV_LastSpeed[clientIdx]);
}

/**
 * Twisted Attraction
 */
public Action:TA_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (!IsLivingPlayer(attacker) || GetClientTeam(attacker) != BossTeam)
		return Plugin_Continue;
		
	if (TA_OrbEntRef[attacker] != INVALID_ENTREF && EntRefToEntIndex(TA_OrbEntRef[attacker]) == inflictor)
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
 
public TA_CreateOrb(clientIdx, const Float:orbPos[3])
{
	// spawn our orb
	new String:classname[MAX_ENTITY_CLASSNAME_LENGTH] = "CTFProjectile_SpellLightningOrb";
	new String:entname[MAX_ENTITY_CLASSNAME_LENGTH] = "tf_projectile_lightningorb";
	new orb = CreateEntityByName(entname);
	if (!IsValidEntity(orb))
	{
		PrintToServer("[sarysamods8] Error: Invalid entity %s. Won't spawn orb. This is sarysa's fault.", entname);
		return;
	}
	
	// deploy!
	TeleportEntity(orb, orbPos, Float:{0.0,0.0,0.0}, Float:{0.0,0.0,0.0});
	SetEntProp(orb, Prop_Send, "m_bCritical", false); // no random crits
	SetEntDataFloat(orb, FindSendPropOffs(classname, "m_iDeflected") + 4, 0.0, true); // credit to voogru (damage setter [which does jack shit for orb spell])
	SetEntProp(orb, Prop_Send, "m_nSkin", 1); // set skin to BLU team's
	SetEntPropEnt(orb, Prop_Send, "m_hOwnerEntity", clientIdx);
	SetVariantInt(BossTeam);
	AcceptEntityInput(orb, "TeamNum", -1, -1, 0);
	SetVariantInt(BossTeam);
	AcceptEntityInput(orb, "SetTeam", -1, -1, 0); 
	DispatchSpawn(orb);
	
	// replace existing object
	if (TA_OrbEntRef[clientIdx] != INVALID_ENTREF)
		RemoveEntity(INVALID_HANDLE, TA_OrbEntRef[clientIdx]);
	TA_OrbEntRef[clientIdx] = EntIndexToEntRef(orb);
}
 
public Rage_TwistedAttraction(clientIdx)
{
	if (TA_IsFNAP[clientIdx] && !FNAP_IsCurrentRage(clientIdx, TA_STRING))
		return;
	
	// just attract the players for now. damage them later.
	static Float:bossOrigin[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
	bossOrigin[2] += 41.5; // attract to midsection
	for (new victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
			continue;
			
		static Float:victimOrigin[3];
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimOrigin);
		new Float:distance = GetVectorDistance(bossOrigin, victimOrigin);
		if (distance > TA_AttractionRadius[clientIdx])
			continue;
			
		// for once, knockback (attraction) intensity is actually INCREASED by distance
		new Float:intensity = TA_MinAttraction[clientIdx] + ((TA_MaxAttraction[clientIdx] - TA_MinAttraction[clientIdx]) * (distance / TA_AttractionRadius[clientIdx]));
		static Float:angles[3];
		GetVectorAnglesTwoPoints(victimOrigin, bossOrigin, angles);
		static Float:velocity[3];
		GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(velocity, intensity);
		
		// min Z and set
		if (velocity[2] < 325.0 && !CheckGroundClearance(victim, 60.0, false))
			velocity[2] = 325.0;
		TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, velocity);
	}
	
	// immobilize?
	if (TA_ShouldImmobilize[clientIdx])
		SetEntityMoveType(clientIdx, MOVETYPE_NONE);
	
	// create the orb...it's only an aesthetic, so it will do zero damage
	TA_CreateOrb(clientIdx, bossOrigin);
	
	// make user invincible?
	if (TA_InvincibilityDuration[clientIdx] > 0.0)
	{
		TF2_AddCondition(clientIdx, TFCond_Ubercharged, -1.0);
		SetEntProp(clientIdx, Prop_Data, "m_takedamage", 0);
		TA_InvincibilityEndsAt[clientIdx] = GetEngineTime() + TA_InvincibilityDuration[clientIdx];
	}
	
	// set timers
	TA_RemoveOrbAt[clientIdx] = TA_DamageAt[clientIdx] = GetEngineTime() + TA_DamageDelay[clientIdx];
	
	// horror sound
	if (strlen(TA_Sound) > 3)
		EmitSoundToAll(TA_Sound);
}

public TA_Tick(clientIdx, Float:curTime)
{
	if (curTime >= TA_InvincibilityEndsAt[clientIdx])
	{
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_Ubercharged))
			TF2_RemoveCondition(clientIdx, TFCond_Ubercharged);
		SetEntProp(clientIdx, Prop_Data, "m_takedamage", 2);
		TA_InvincibilityEndsAt[clientIdx] = FAR_FUTURE;
	}
	
	if (curTime >= TA_DamageAt[clientIdx])
	{
		if (TA_ShouldImmobilize[clientIdx])
			SetEntityMoveType(clientIdx, MOVETYPE_WALK);
			
		static Float:bossOrigin[3];
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
		for (new victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
				continue;

			static Float:victimOrigin[3];
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimOrigin);
			new Float:distance = GetVectorDistance(bossOrigin, victimOrigin);
			if (distance > TA_DamageRadius[clientIdx])
				continue;
				
			// do exponential damage
			new Float:damage = TA_BaseDamage[clientIdx] - (TA_BaseDamage[clientIdx] * (Pow(Pow(TA_DamageRadius[clientIdx], TA_DamageFalloffExp[clientIdx]) -
				Pow(TA_DamageRadius[clientIdx] - distance, TA_DamageFalloffExp[clientIdx]), 1.0 / TA_DamageFalloffExp[clientIdx]) / TA_DamageRadius[clientIdx]));
			damage = fixDamageForFF2(damage);
			FullyHookedDamage(victim, clientIdx, clientIdx, damage / 3.0, DMG_GENERIC | DMG_CRIT | DMG_PREVENT_PHYSICS_FORCE, -1);
		}
		
		// particle effect
		if (!IsEmptyString(TA_DamageEffect))
			ParticleEffectAt(bossOrigin, TA_DamageEffect, 3.0);
		
		TA_DamageAt[clientIdx] = FAR_FUTURE;
	}
	
	if (curTime >= TA_RemoveOrbAt[clientIdx])
	{
		if (TA_OrbEntRef[clientIdx] != INVALID_ENTREF)
			RemoveEntity(INVALID_HANDLE, TA_OrbEntRef[clientIdx]);
		TA_OrbEntRef[clientIdx] = INVALID_ENTREF;
		TA_RemoveOrbAt[clientIdx] = FAR_FUTURE;
	}
}

/**
 * Instant Teleports
 */
public IT_GiveTeleports(clientIdx, teleportCount)
{
	DT_ChangeFundamentalStats(clientIdx, IT_TeleportChargeTime[clientIdx], IT_TeleportCooldown[clientIdx], IT_TeleportStun[clientIdx]);
	DT_SetUsesRemaining(clientIdx, IT_TeleportPerRage[clientIdx]);
	DT_CooldownUntil(clientIdx, FAR_FUTURE); // remove the cooldown, if present
}
 
public Rage_InstantTeleports(clientIdx)
{
	if (IT_IsFNAP[clientIdx] && !FNAP_IsCurrentRage(clientIdx, IT_STRING))
		return;
		
	// just change teleport stats
	IT_GiveTeleports(clientIdx, IT_TeleportPerRage[clientIdx]);

	// horror sound
	if (strlen(IT_Sound) > 3)
		EmitSoundToAll(IT_Sound);
}

public IT_Tick(clientIdx, buttons)
{
	new usefulButton = IT_TeleportUsesSpecial[clientIdx] ? IN_ATTACK3 : IN_RELOAD;
	new bool:buttonDown = (buttons & usefulButton) != 0;
	if (buttonDown && !IT_ButtonDown[clientIdx] && !(IT_IsFNAP[clientIdx] && !FNAP_IsCurrentRage(clientIdx, IT_STRING)))
	{
		IT_CurrentlyTeleport[clientIdx] = !IT_CurrentlyTeleport[clientIdx];
		DD_SetDisabled(clientIdx, IT_CurrentlyTeleport[clientIdx], !IT_CurrentlyTeleport[clientIdx], false, false);
	}
	IT_ButtonDown[clientIdx] = buttonDown;
}

/**
 * Cripple Stacks
 */
public Action:CS_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (CS_VictimVulnerability[victim] == 1.0 || !IsLivingPlayer(CS_VictimKiller[victim]))
		return Plugin_Continue;
	else if (CS_VictimKiller[victim] != attacker)
		return Plugin_Continue;
	
	damage *= CS_VictimVulnerability[victim];
	return Plugin_Changed;
}
 
public Rage_CrippleStacks(clientIdx)
{
	if (CS_IsFNAP[clientIdx] && !FNAP_IsCurrentRage(clientIdx, CS_STRING))
		return;
		
	// add stacks to anyone who's valid
	new Float:radiusSquared = CS_EffectRadius[clientIdx] * CS_EffectRadius[clientIdx];
	static Float:bossOrigin[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
	for (new victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
			continue;
			
		// uber test first
		if (CS_UberSaves[victim] && TF2_IsPlayerInCondition(victim, TFCond_Ubercharged))
			continue;

		// range check
		if (radiusSquared > 0.0)
		{
			static Float:victimOrigin[3];
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimOrigin);
			if (GetVectorDistance(bossOrigin, victimOrigin, true) > radiusSquared)
				continue;
		}
		
		// before messing with speed, remove the effects of any existing speed tweak
		if (CS_VictimSpeedFactor[victim] > 0.0 && CS_VictimSpeedFactor[victim] != 1.0)
		{
			new Float:curSpeed = GetEntPropFloat(victim, Prop_Send, "m_flMaxspeed");
			if (curSpeed == CS_ExpectedSpeed[victim])
				SetEntPropFloat(victim, Prop_Send, "m_flMaxspeed", curSpeed / CS_VictimSpeedFactor[victim]);
			CS_ExpectedSpeed[victim] = 0.0;
		}
		
		// apply the stack
		CS_VictimDamage[victim] += CS_DamagePerStack[clientIdx];
		CS_VictimSpeedFactor[victim] *= CS_SpeedFactorPerStack[clientIdx];
		CS_VictimVulnerability[victim] *= CS_VulnerabilityPerStack[clientIdx];
		CS_VictimDamageInterval[victim] = CS_DamageInterval[clientIdx];
		CS_VictimKiller[victim] = clientIdx;
		if (CS_VictimDamageAt[victim] == FAR_FUTURE)
			CS_VictimDamageAt[victim] = GetEngineTime();
	}

	// horror sound
	if (strlen(CS_Sound) > 3)
		EmitSoundToAll(CS_Sound);
}

public CS_Tick(Float:curTime)
{
	for (new victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (!IsLivingPlayer(victim))
			continue;
		else if (CS_VictimKiller[victim] == -1 || !IsLivingPlayer(CS_VictimKiller[victim]))
			continue;
	
		// cause damage if appropriate
		if (curTime >= CS_VictimDamageAt[victim] && CS_VictimDamage[victim] > 0.0)
		{
			QuietDamage(victim, CS_VictimKiller[victim], CS_VictimKiller[victim], CS_VictimDamage[victim], DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
			
			// don't let server lag slow the rate of damage
			CS_VictimDamageAt[victim] += CS_VictimDamageInterval[victim];
		}
		
		// slow if appropriate
		if (CS_VictimSpeedFactor[victim] != 1.0)
		{
			new Float:curSpeed = GetEntPropFloat(victim, Prop_Send, "m_flMaxspeed");
			if (curSpeed != CS_ExpectedSpeed[victim])
			{
				curSpeed *= CS_VictimSpeedFactor[victim];
				CS_ExpectedSpeed[victim] = curSpeed;
				SetEntPropFloat(victim, Prop_Send, "m_flMaxspeed", CS_ExpectedSpeed[victim]);
			}
		}
	}
}

/**
 * Low Population Damage Buff
 */
public Action:LPDB_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (IsLivingPlayer(attacker) && LPDB_CanUse[attacker])
	{
		damage *= LPDB_DamageMultiplier[attacker];
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

/**
 * OnPlayerRunCmd/OnGameFrame, with special guest star OnEntityCreated
 */
#define IMPERFECT_FLIGHT_FACTOR 25
public OnGameFrame()
{
	if (!PluginActiveThisRound || !RoundInProgress)
		return;
		
	new Float:curTime = GetEngineTime();
	
	if (HC_ActiveThisRound)
	{
		HC_GameFrame(curTime);
	}
	
	if (MM_ActiveThisRound)
	{
		MM_Tick(curTime);
	}

	if (DS_ActiveThisRound)
	{
		DS_Tick(curTime);
	}
	
	if (FNAP_ActiveThisRound)
	{
		FNAP_Tick(curTime);
	}
	
	if (PB_ActiveThisRound)
	{
		PB_Tick(curTime);
	}
	
	if (PT_ActiveThisRound)
	{
		PT_Tick(curTime);
	}
	
	if (CS_ActiveThisRound)
	{
		CS_Tick(curTime);
	}
	
	// doing this to HOPEFULLY reduce the rate of 
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!IsLivingPlayer(clientIdx) || GetClientTeam(clientIdx) != BossTeam)
			continue;
	
		if (EM_ActiveThisRound && EM_CanUse[clientIdx])
		{
			EM_Tick(clientIdx, GetEngineTime());
		}
	}
}
 
public Action:OnPlayerRunCmd(clientIdx, &buttons, &impulse, Float:vel[3], Float:unusedangles[3], &weapon)
{
	if (!PluginActiveThisRound || !RoundInProgress)
		return Plugin_Continue;
	else if (!IsLivingPlayer(clientIdx))
		return Plugin_Continue;
		
	if (GH_ActiveThisRound && GH_CanUse[clientIdx])
	{
		GH_Tick(clientIdx, GetEngineTime());
	}
	
	if (MM_ActiveThisRound && MM_CanUse[clientIdx])
	{
		MM_OnPlayerRunCmd(clientIdx, buttons);
	}
	
	if (MBW_ActiveThisRound && MBW_CanUse[clientIdx])
	{
		MBW_Tick(clientIdx);
	}
	
	if (MF_ActiveThisRound && MF_CanUse[clientIdx])
	{
		MF_Tick(clientIdx, GetEngineTime());
	}
	
	if (SR_ActiveThisRound)
	{
		SR_Tick(clientIdx, GetEngineTime());
	}
	
	if (HC_ActiveThisRound && HC_CanUse[clientIdx])
	{
		new Float:curTime = GetEngineTime();
		HC_Tick(clientIdx, curTime);
		
		if (HP_ActiveThisRound && HP_CanUse[clientIdx])
			HP_Tick(clientIdx);
		if (HCR_ActiveThisRound && HCR_CanUse[clientIdx])
			HCR_Tick(clientIdx);
		if (HA_ActiveThisRound && HA_CanUse[clientIdx])
			HA_Tick(clientIdx, curTime);
			
		// HUD last
		if (HH_ActiveThisRound && HH_CanUse[clientIdx])
			HH_Tick(clientIdx, curTime);
	}
	
	if (SBV_ActiveThisRound && SBV_CanUse[clientIdx])
	{
		SBV_Tick(clientIdx, GetEngineTime());
	}
	
	if (TA_ActiveThisRound && TA_CanUse[clientIdx])
	{
		TA_Tick(clientIdx, GetEngineTime());
	}
	
	if (IT_ActiveThisRound && IT_CanUse[clientIdx])
	{
		IT_Tick(clientIdx, buttons);
	}
	
	return Plugin_Continue;
}

public OnEntityCreated(entity, const String:classname[])
{
	if (MM_ActiveThisRound)
		MM_OnEntityCreated(entity, classname);
}

/**
 * General helper stocks, some original, some taken/modified from other sources
 */
stock PlaySoundLocal(clientIdx, String:soundPath[], bool:followPlayer = true, stack = 1)
{
	// play a speech sound that travels normally, local from the player.
	decl Float:playerPos[3];
	GetClientEyePosition(clientIdx, playerPos);
	//PrintToServer("[sarysamods8] eye pos=%f,%f,%f     sound=%s", playerPos[0], playerPos[1], playerPos[2], soundPath);
	for (new i = 0; i < stack; i++)
		EmitAmbientSound(soundPath, playerPos, followPlayer ? clientIdx : SOUND_FROM_WORLD);
}

stock ParticleEffectAt(Float:position[3], String:effectName[], Float:duration = 0.1)
{
	if (!IsEmptyString(effectName))
		return -1; // nothing to display
		
	new particle = CreateEntityByName("info_particle_system");
	if (particle != -1)
	{
		TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "effect_name", effectName);
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		if (duration > 0.0)
			CreateTimer(duration, RemoveEntity, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
	}
	return particle;
}

stock AttachParticle(entity, const String:particleType[], Float:offset=0.0, bool:attach=true)
{
	new particle = CreateEntityByName("info_particle_system");
	
	if (!IsValidEntity(particle))
		return -1;

	decl String:targetName[128];
	decl Float:position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	position[2] += offset;
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

	Format(targetName, sizeof(targetName), "target%i", entity);
	DispatchKeyValue(entity, "targetname", targetName);

	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", targetName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(targetName);
	if (attach)
	{
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	}
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	return particle;
}

// adapted from the above and Friagram's halloween 2013 (which standing alone did not work for me)
stock AttachParticleToAttachment(entity, const String:particleType[], const String:attachmentPoint[]) // m_vecAbsOrigin. you're welcome.
{
	new particle = CreateEntityByName("info_particle_system");
	
	if (!IsValidEntity(particle))
		return -1;

	decl String:targetName[128];
	decl Float:position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

	Format(targetName, sizeof(targetName), "target%i", entity);
	DispatchKeyValue(entity, "targetname", targetName);

	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", targetName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(targetName);
	AcceptEntityInput(particle, "SetParent", particle, particle, 0);
	SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	
	SetVariantString(attachmentPoint);
	AcceptEntityInput(particle, "SetParentAttachment");

	if (!IsEmptyString(particleType))
	{
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
	}
	return particle;
}

public Action:RemoveEntity(Handle:timer, any:entid)
{
	new entity = EntRefToEntIndex(entid);
	if (IsValidEdict(entity) && entity > MaxClients)
	{
		TeleportEntity(entity, OFF_THE_MAP, NULL_VECTOR, NULL_VECTOR); // send it away first in case it feels like dying dramatically
		AcceptEntityInput(entity, "Kill");
	}
}

public Action:RemoveEntityNoTele(Handle:timer, any:entid)
{
	new entity = EntRefToEntIndex(entid);
	if (IsValidEdict(entity) && entity > MaxClients)
		AcceptEntityInput(entity, "Kill");
}

stock bool:IsLivingPlayer(clientIdx)
{
	if (clientIdx <= 0 || clientIdx >= MAX_PLAYERS)
		return false;
		
	return IsClientInGame(clientIdx) && IsPlayerAlive(clientIdx);
}

stock bool:IsValidBoss(clientIdx)
{
	if (!IsLivingPlayer(clientIdx))
		return false;
		
	return GetClientTeam(clientIdx) == BossTeam;
}

stock SwitchWeapon(bossClient, String:weaponName[], weaponIdx, String:weaponAttributes[], visible)
{
	TF2_RemoveWeaponSlot(bossClient, TFWeaponSlot_Primary);
	TF2_RemoveWeaponSlot(bossClient, TFWeaponSlot_Secondary);
	TF2_RemoveWeaponSlot(bossClient, TFWeaponSlot_Melee);
	new weapon;
	weapon = SpawnWeapon(bossClient, weaponName, weaponIdx, 101, 5, weaponAttributes, visible);
	SetEntPropEnt(bossClient, Prop_Data, "m_hActiveWeapon", weapon);
}

stock SpawnWeapon(client, String:name[], index, level, quality, String:attribute[], visible = 1)
{
	new Handle:weapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(weapon, name);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, quality);
	new String:attributes[32][32];
	new count = ExplodeString(attribute, ";", attributes, 32, 32);
	if(count%2!=0)
	{
		count--;
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(weapon, count/2);
		new i2 = 0;
		for(new i = 0; i < count; i += 2)
		{
			new attrib = StringToInt(attributes[i]);
			if (attrib == 0)
			{
				LogError("Bad weapon attribute passed: %s ; %s", attributes[i], attributes[i+1]);
				return -1;
			}
			TF2Items_SetAttribute(weapon, i2, attrib, StringToFloat(attributes[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(weapon, 0);
	}

	if (weapon == INVALID_HANDLE)
	{
		PrintToServer("[sarysamods8] Error: Invalid weapon spawned. client=%d name=%s idx=%d attr=%s", client, name, index, attribute);
		return -1;
	}

	new entity = TF2Items_GiveNamedItem(client, weapon);
	CloseHandle(weapon);
	EquipPlayerWeapon(client, entity);
	
	// sarysa addition
	if (!visible)
	{
		SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
	}
	
	return entity;
}

stock bool:IsPlayerInRange(player, Float:position[3], Float:maxDistance)
{
	maxDistance *= maxDistance;
	
	static Float:playerPos[3];
	GetEntPropVector(player, Prop_Data, "m_vecOrigin", playerPos);
	return GetVectorDistance(position, playerPos, true) <= maxDistance;
}

stock FindRandomPlayer(bool:isBossTeam, Float:position[3] = NULL_VECTOR, Float:maxDistance = 0.0, bool:anyTeam = false, bool:deadOnly = false)
{
	return FindRandomPlayerBlacklist(isBossTeam, NULL_BLACKLIST, position, maxDistance, anyTeam, deadOnly);
}

stock FindRandomPlayerBlacklist(bool:isBossTeam, const bool:blacklist[MAX_PLAYERS_ARRAY], Float:position[3] = NULL_VECTOR, Float:maxDistance = 0.0, bool:anyTeam = false, bool:deadOnly = false)
{
	new player = -1;

	// first, get a player count for the team we care about
	new playerCount = 0;
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!deadOnly && !IsLivingPlayer(clientIdx))
			continue;
		else if (deadOnly)
		{
			if (!IsClientInGame(clientIdx) || IsLivingPlayer(clientIdx))
				continue;
		}
			
		if (!deadOnly && maxDistance > 0.0 && !IsPlayerInRange(clientIdx, position, maxDistance))
			continue;
			
		if (blacklist[clientIdx])
			continue;

		// fixed to not grab people in spectator, since we can now include the dead
		new bool:valid = anyTeam && (GetClientTeam(clientIdx) == BossTeam || GetClientTeam(clientIdx) == MercTeam);
		if (!valid)
			valid = (isBossTeam && GetClientTeam(clientIdx) == BossTeam) || (!isBossTeam && GetClientTeam(clientIdx) == MercTeam);
			
		if (valid)
			playerCount++;
	}

	// ensure there's at least one living valid player
	if (playerCount <= 0)
		return -1;

	// now randomly choose our victim
	new rand = GetRandomInt(0, playerCount - 1);
	playerCount = 0;
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!deadOnly && !IsLivingPlayer(clientIdx))
			continue;
		else if (deadOnly)
		{
			if (!IsClientInGame(clientIdx) || IsLivingPlayer(clientIdx))
				continue;
		}
			
		if (!deadOnly && maxDistance > 0.0 && !IsPlayerInRange(clientIdx, position, maxDistance))
			continue;

		if (blacklist[clientIdx])
			continue;

		// fixed to not grab people in spectator, since we can now include the dead
		new bool:valid = anyTeam && (GetClientTeam(clientIdx) == BossTeam || GetClientTeam(clientIdx) == MercTeam);
		if (!valid)
			valid = (isBossTeam && GetClientTeam(clientIdx) == BossTeam) || (!isBossTeam && GetClientTeam(clientIdx) == MercTeam);
			
		if (valid)
		{
			if (playerCount == rand) // needed if rand is 0
			{
				player = clientIdx;
				break;
			}
			playerCount++;
			if (playerCount == rand) // needed if rand is playerCount - 1, executes for all others except 0
			{
				player = clientIdx;
				break;
			}
		}
	}
	
	return player;
}

stock bool:CheckLineOfSight(Float:position[3], targetEntity, Float:zOffset)
{
	static Float:targetPos[3];
	GetEntPropVector(targetEntity, Prop_Send, "m_vecOrigin", targetPos);
	targetPos[2] += zOffset;
	static Float:angles[3];
	GetVectorAnglesTwoPoints(position, targetPos, angles);
	
	new Handle:trace = TR_TraceRayFilterEx(position, angles, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
	static Float:endPos[3];
	TR_GetEndPosition(endPos, trace);
	CloseHandle(trace);
	
	return GetVectorDistance(position, targetPos, true) <= GetVectorDistance(position, endPos, true);
}
			
stock FindRandomSpawn(bool:bluSpawn, bool:redSpawn)
{
	new spawn = -1;

	// first, get a spawn count for the team(s) we care about
	new spawnCount = 0;
	new entity = -1;
	while ((entity = FindEntityByClassname(entity, "info_player_teamspawn")) != -1)
	{
		new teamNum = GetEntProp(entity, Prop_Send, "m_iTeamNum");
		if ((teamNum == BossTeam && bluSpawn) || (teamNum != BossTeam && redSpawn))
			spawnCount++;
	}

	// ensure there's at least one valid spawn
	if (spawnCount <= 0)
		return -1;

	// now randomly choose our spawn
	new rand = GetRandomInt(0, spawnCount - 1);
	spawnCount = 0;
	while ((entity = FindEntityByClassname(entity, "info_player_teamspawn")) != -1)
	{
		new teamNum = GetEntProp(entity, Prop_Send, "m_iTeamNum");
		if ((teamNum == BossTeam && bluSpawn) || (teamNum != BossTeam && redSpawn))
		{
			if (spawnCount == rand)
				spawn = entity;
			spawnCount++;
			if (spawnCount == rand)
				spawn = entity;
		}
	}
	
	return spawn;
}

stock GetLivingMercCount()
{
	// recalculate living players
	new livingMercCount = 0;
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		if (IsLivingPlayer(clientIdx) && GetClientTeam(clientIdx) != BossTeam)
			livingMercCount++;
	
	return livingMercCount;
}
	
stock ParseFloatRange(String:rangeStr[MAX_RANGE_STRING_LENGTH], &Float:min, &Float:max)
{
	new String:rangeStrs[2][32];
	ExplodeString(rangeStr, ",", rangeStrs, 2, 32);
	min = StringToFloat(rangeStrs[0]);
	max = StringToFloat(rangeStrs[1]);
}

stock ParseHull(String:hullStr[MAX_HULL_STRING_LENGTH], Float:hull[2][3])
{
	new String:hullStrs[2][MAX_HULL_STRING_LENGTH / 2];
	new String:vectorStrs[3][MAX_HULL_STRING_LENGTH / 6];
	ExplodeString(hullStr, " ", hullStrs, 2, MAX_HULL_STRING_LENGTH / 2);
	for (new i = 0; i < 2; i++)
	{
		ExplodeString(hullStrs[i], ",", vectorStrs, 3, MAX_HULL_STRING_LENGTH / 6);
		hull[i][0] = StringToFloat(vectorStrs[0]);
		hull[i][1] = StringToFloat(vectorStrs[1]);
		hull[i][2] = StringToFloat(vectorStrs[2]);
	}
}

stock ReadHull(bossIdx, const String:ability_name[], argInt, Float:hull[2][3])
{
	static String:hullStr[MAX_HULL_STRING_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, hullStr, MAX_HULL_STRING_LENGTH);
	ParseHull(hullStr, hull);
}

stock ReadSound(bossIdx, const String:ability_name[], argInt, String:soundFile[MAX_SOUND_FILE_LENGTH])
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, soundFile, MAX_SOUND_FILE_LENGTH);
	if (strlen(soundFile) > 3)
		PrecacheSound(soundFile);
}

stock ReadModel(bossIdx, const String:ability_name[], argInt, String:modelFile[MAX_MODEL_FILE_LENGTH])
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, modelFile, MAX_MODEL_FILE_LENGTH);
	if (strlen(modelFile) > 3)
		PrecacheModel(modelFile);
}

stock ReadModelToInt(bossIdx, const String:ability_name[], argInt)
{
	static String:modelFile[MAX_MODEL_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, modelFile, MAX_MODEL_FILE_LENGTH);
	if (strlen(modelFile) > 3)
		return PrecacheModel(modelFile);
	return -1;
}

stock ReadMaterial(bossIdx, const String:ability_name[], argInt, String:modelFile[MAX_MATERIAL_FILE_LENGTH])
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, modelFile, MAX_MATERIAL_FILE_LENGTH);
	if (strlen(modelFile) > 3)
		PrecacheModel(modelFile);
}

stock ReadMaterialToInt(bossIdx, const String:ability_name[], argInt)
{
	static String:modelFile[MAX_MATERIAL_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, modelFile, MAX_MATERIAL_FILE_LENGTH);
	if (strlen(modelFile) > 3)
		return PrecacheModel(modelFile);
	return -1;
}

stock ReadCenterText(bossIdx, const String:ability_name[], argInt, String:centerText[MAX_CENTER_TEXT_LENGTH])
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, centerText, MAX_CENTER_TEXT_LENGTH);
	ReplaceString(centerText, MAX_CENTER_TEXT_LENGTH, "\\n", "\n");
}

public bool:TraceWallsOnly(entity, contentsMask)
{
	return false;
}

public bool:TraceRedPlayers(entity, contentsMask)
{
	if (IsLivingPlayer(entity) && GetClientTeam(entity) != BossTeam)
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods8] Hit player %d on trace.", entity);
		return true;
	}

	return false;
}

public bool:TraceRedPlayersAndBuildings(entity, contentsMask)
{
	if (IsLivingPlayer(entity) && GetClientTeam(entity) != BossTeam)
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods8] Hit player %d on trace.", entity);
		return true;
	}
	else if (IsValidEntity(entity))
	{
		static String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
		GetEntityClassname(entity, classname, sizeof(classname));
		classname[4] = 0;
		if (!strcmp(classname, "obj_")) // all buildings start with this
			return true;
	}

	return false;
}

stock Float:fixAngle(Float:angle)
{
	new sanity = 0;
	while (angle < -180.0 && (sanity++) <= 10)
		angle = angle + 360.0;
	while (angle > 180.0 && (sanity++) <= 10)
		angle = angle - 360.0;
		
	return angle;
}

// really wish that the original GetVectorAngles() worked this way.
stock Float:GetVectorAnglesTwoPoints(const Float:startPos[3], const Float:endPos[3], Float:angles[3])
{
	static Float:tmpVec[3];
	tmpVec[0] = endPos[0] - startPos[0];
	tmpVec[1] = endPos[1] - startPos[1];
	tmpVec[2] = endPos[2] - startPos[2];
	GetVectorAngles(tmpVec, angles);
}

stock Float:GetVelocityFromPointsAndInterval(Float:pointA[3], Float:pointB[3], Float:deltaTime)
{
	if (deltaTime <= 0.0)
		return 0.0;

	return GetVectorDistance(pointA, pointB) * (1.0 / deltaTime);
}

stock Float:fixDamageForFF2(Float:damage)
{
	if (damage <= 160.0)
		return damage / 3.0;
	return damage;
}

stock QuietDamage(victim, inflictor, attacker, Float:damage, damageType=DMG_GENERIC, weapon=-1)
{
	new takedamage = GetEntProp(victim, Prop_Data, "m_takedamage");
	SetEntProp(victim, Prop_Data, "m_takedamage", 0);
	SDKHooks_TakeDamage(victim, inflictor, attacker, damage, damageType, weapon);
	SetEntProp(victim, Prop_Data, "m_takedamage", takedamage);
	SDKHooks_TakeDamage(victim, victim, victim, damage, damageType, weapon);
}

// for when damage to a hale needs to be recognized
stock SemiHookedDamage(victim, inflictor, attacker, Float:damage, damageType=DMG_GENERIC, weapon=-1)
{
	if (GetClientTeam(victim) != BossTeam)
		SDKHooks_TakeDamage(victim, inflictor, attacker, damage, damageType, weapon);
	else
		FullyHookedDamage(victim, inflictor, attacker, damage, damageType, weapon);
}

stock FullyHookedDamage(victim, inflictor, attacker, Float:damage, damageType=DMG_GENERIC, weapon=-1, Float:attackPos[3] = NULL_VECTOR)
{
	static String:dmgStr[16];
	IntToString(RoundFloat(damage), dmgStr, sizeof(dmgStr));

	// took this from war3...I hope it doesn't double damage like I've heard old versions do
	new pointHurt = CreateEntityByName("point_hurt");
	if (IsValidEntity(pointHurt))
	{
		DispatchKeyValue(victim, "targetname", "halevictim");
		DispatchKeyValue(pointHurt, "DamageTarget", "halevictim");
		DispatchKeyValue(pointHurt, "Damage", dmgStr);
		DispatchKeyValueFormat(pointHurt, "DamageType", "%d", damageType);

		DispatchSpawn(pointHurt);
		if (!(attackPos[0] == NULL_VECTOR[0] && attackPos[1] == NULL_VECTOR[1] && attackPos[2] == NULL_VECTOR[2]))
		{
			TeleportEntity(pointHurt, attackPos, NULL_VECTOR, NULL_VECTOR);
		}
		else if (IsLivingPlayer(attacker))
		{
			static Float:attackerOrigin[3];
			GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", attackerOrigin);
			TeleportEntity(pointHurt, attackerOrigin, NULL_VECTOR, NULL_VECTOR);
		}
		AcceptEntityInput(pointHurt, "Hurt", attacker);
		DispatchKeyValue(pointHurt, "classname", "point_hurt");
		DispatchKeyValue(victim, "targetname", "noonespecial");
		RemoveEntity(INVALID_HANDLE, EntIndexToEntRef(pointHurt));
	}
}

// this version ignores obstacles
stock PseudoAmbientSound(clientIdx, String:soundPath[], count=1, Float:radius=1000.0, bool:skipSelf=false, bool:skipDead=false, Float:volumeFactor=1.0)
{
	decl Float:emitterPos[3];
	decl Float:listenerPos[3];
	if (!IsLivingPlayer(clientIdx)) // updated 2015-01-16 to allow non-players...finally.
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", emitterPos);
	else
		GetClientEyePosition(clientIdx, emitterPos);
	for (new listener = 1; listener < MAX_PLAYERS; listener++)
	{
		if (!IsClientInGame(listener))
			continue;
		else if (skipSelf && listener == clientIdx)
			continue;
		else if (skipDead && !IsLivingPlayer(listener))
			continue;
			
		GetClientEyePosition(listener, listenerPos);
		new Float:distance = GetVectorDistance(emitterPos, listenerPos);
		if (distance >= radius)
			continue;
		
		new Float:volume = (radius - distance) / radius;
		if (volume <= 0.0)
			continue;
		else if (volume > 1.0)
		{
			PrintToServer("[sarysamods8] How the hell is volume greater than 1.0?");
			volume = 1.0;
		}
		
		for (new i = 0; i < count; i++)
			EmitSoundToClient(listener, soundPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume);
	}
}

stock fixAngles(Float:angles[3])
{
	for (new i = 0; i < 3; i++)
		angles[i] = fixAngle(angles[i]);
}

stock abs(x)
{
	return x < 0 ? -x : x;
}

stock Float:fabs(Float:x)
{
	return x < 0 ? -x : x;
}

stock min(n1, n2)
{
	return n1 < n2 ? n1 : n2;
}

stock Float:fmin(Float:n1, Float:n2)
{
	return n1 < n2 ? n1 : n2;
}

stock max(n1, n2)
{
	return n1 > n2 ? n1 : n2;
}

stock Float:fmax(Float:n1, Float:n2)
{
	return n1 > n2 ? n1 : n2;
}

stock Float:fsquare(Float:x)
{
	return x * x;
}

stock Float:DEG2RAD(Float:n) { return n * 0.017453; }

stock Float:RAD2DEG(Float:n) { return n * 57.29578; }

stock bool:WithinBounds(Float:point[3], Float:min[3], Float:max[3])
{
	return point[0] >= min[0] && point[0] <= max[0] &&
		point[1] >= min[1] && point[1] <= max[1] &&
		point[2] >= min[2] && point[2] <= max[2];
}

stock ReadHexOrDecInt(String:hexOrDecString[HEX_OR_DEC_STRING_LENGTH])
{
	if (StrContains(hexOrDecString, "0x") == 0)
	{
		new result = 0;
		for (new i = 2; i < 10 && hexOrDecString[i] != 0; i++)
		{
			result = result<<4;
				
			if (hexOrDecString[i] >= '0' && hexOrDecString[i] <= '9')
				result += hexOrDecString[i] - '0';
			else if (hexOrDecString[i] >= 'a' && hexOrDecString[i] <= 'f')
				result += hexOrDecString[i] - 'a' + 10;
			else if (hexOrDecString[i] >= 'A' && hexOrDecString[i] <= 'F')
				result += hexOrDecString[i] - 'A' + 10;
		}
		
		return result;
	}
	else
		return StringToInt(hexOrDecString);
}

stock ReadHexOrDecString(bossIdx, const String:ability_name[], argIdx)
{
	static String:hexOrDecString[HEX_OR_DEC_STRING_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argIdx, hexOrDecString, HEX_OR_DEC_STRING_LENGTH);
	return ReadHexOrDecInt(hexOrDecString);
}

stock Float:ConformAxisValue(Float:src, Float:dst, Float:distCorrectionFactor)
{
	return src - ((src - dst) * distCorrectionFactor);
}

stock ConformLineDistance(Float:result[3], const Float:src[3], const Float:dst[3], Float:maxDistance, bool:canExtend = false)
{
	new Float:distance = GetVectorDistance(src, dst);
	if ((distance <= maxDistance && !canExtend) || distance <= 0.0)
	{
		// everything's okay.
		result[0] = dst[0];
		result[1] = dst[1];
		result[2] = dst[2];
	}
	else
	{
		// need to find a point at roughly maxdistance. (FP irregularities aside)
		new Float:distCorrectionFactor = maxDistance / distance;
		result[0] = ConformAxisValue(src[0], dst[0], distCorrectionFactor);
		result[1] = ConformAxisValue(src[1], dst[1], distCorrectionFactor);
		result[2] = ConformAxisValue(src[2], dst[2], distCorrectionFactor);
	}
}

stock bool:CylinderCollision(Float:cylinderOrigin[3], Float:colliderOrigin[3], Float:maxDistance, Float:zMin, Float:zMax)
{
	if (colliderOrigin[2] < zMin || colliderOrigin[2] > zMax)
		return false;

	static Float:tmpVec1[3];
	tmpVec1[0] = cylinderOrigin[0];
	tmpVec1[1] = cylinderOrigin[1];
	tmpVec1[2] = 0.0;
	static Float:tmpVec2[3];
	tmpVec2[0] = colliderOrigin[0];
	tmpVec2[1] = colliderOrigin[1];
	tmpVec2[2] = 0.0;
	
	return GetVectorDistance(tmpVec1, tmpVec2, true) <= maxDistance * maxDistance;
}

stock bool:RectangleCollision(Float:hull[2][3], Float:point[3])
{
	return (point[0] >= hull[0][0] && point[0] <= hull[1][0]) &&
		(point[1] >= hull[0][1] && point[1] <= hull[1][1]) &&
		(point[2] >= hull[0][2] && point[2] <= hull[1][2]);
}

stock Float:getLinearVelocity(Float:vecVelocity[3])
{
	return SquareRoot((vecVelocity[0] * vecVelocity[0]) + (vecVelocity[1] * vecVelocity[1]) + (vecVelocity[2] * vecVelocity[2]));
}

stock Float:getBaseVelocityFromYaw(const Float:angle[3], Float:vel[3])
{
	vel[0] = Cosine(angle[1]); // same as unit circle
	//vel[1] = -Sine(angle[1]); // inverse of unit circle
	vel[1] = Sine(angle[1]); // ...or also same of unit circle? must not test in game at 3am...
	vel[2] = 0.0; // unaffected
}

stock Float:RandomNegative(Float:someVal)
{
	return someVal * (GetRandomInt(0, 1) == 1 ? 1.0 : -1.0);
}

stock Float:GetRayAngles(Float:startPoint[3], Float:endPoint[3], Float:angle[3])
{
	static Float:tmpVec[3];
	tmpVec[0] = endPoint[0] - startPoint[0];
	tmpVec[1] = endPoint[1] - startPoint[1];
	tmpVec[2] = endPoint[2] - startPoint[2];
	GetVectorAngles(tmpVec, angle);
}

stock bool:AngleWithinTolerance(Float:entityAngles[3], Float:targetAngles[3], Float:tolerance)
{
	static bool:tests[2];
	
	for (new i = 0; i < 2; i++)
		tests[i] = fabs(entityAngles[i] - targetAngles[i]) <= tolerance || fabs(entityAngles[i] - targetAngles[i]) >= 360.0 - tolerance;
	
	return tests[0] && tests[1];
}

stock constrainDistance(const Float:startPoint[], Float:endPoint[], Float:distance, Float:maxDistance)
{
	if (distance <= maxDistance)
		return; // nothing to do
		
	new Float:constrainFactor = maxDistance / distance;
	endPoint[0] = ((endPoint[0] - startPoint[0]) * constrainFactor) + startPoint[0];
	endPoint[1] = ((endPoint[1] - startPoint[1]) * constrainFactor) + startPoint[1];
	endPoint[2] = ((endPoint[2] - startPoint[2]) * constrainFactor) + startPoint[2];
}

stock bool:signIsDifferent(const Float:one, const Float:two)
{
	return one < 0.0 && two > 0.0 || one > 0.0 && two < 0.0;
}

stock GetA(c) { return abs(c>>24); }
stock GetR(c) { return abs((c>>16)&0xff); }
stock GetG(c) { return abs((c>>8 )&0xff); }
stock GetB(c) { return abs((c    )&0xff); }

stock ColorToDecimalString(String:buffer[COLOR_BUFFER_SIZE], rgb)
{
	Format(buffer, COLOR_BUFFER_SIZE, "%d %d %d", GetR(rgb), GetG(rgb), GetB(rgb));
}

stock BlendColorsRGB(oldColor, Float:oldWeight, newColor, Float:newWeight)
{
	new r = min(RoundFloat((GetR(oldColor) * oldWeight) + (GetR(newColor) * newWeight)), 255);
	new g = min(RoundFloat((GetG(oldColor) * oldWeight) + (GetG(newColor) * newWeight)), 255);
	new b = min(RoundFloat((GetB(oldColor) * oldWeight) + (GetB(newColor) * newWeight)), 255);
	return (r<<16) + (g<<8) + b;
}

stock Nope(clientIdx)
{
	EmitSoundToClient(clientIdx, NOPE_AVI);
}

// stole this stock from KissLick. it's a good stock!
stock DispatchKeyValueFormat(entity, const String:keyName[], const String:format[], any:...)
{
	static String:value[256];
	VFormat(value, sizeof(value), format, 4);

	DispatchKeyValue(entity, keyName, value);
} 

stock bool:PlayerIsInvincible(clientIdx)
{
	return TF2_IsPlayerInCondition(clientIdx, TFCond_Ubercharged) ||
		TF2_IsPlayerInCondition(clientIdx, TFCond_UberchargedHidden) ||
		TF2_IsPlayerInCondition(clientIdx, TFCond_UberchargedCanteen) ||
		TF2_IsPlayerInCondition(clientIdx, TFCond_UberchargedOnTakeDamage) ||
		TF2_IsPlayerInCondition(clientIdx, TFCond_Bonked);
}

stock bool:CheckGroundClearance(clientIdx, Float:minClearance, bool:failInWater)
{
	// standing? automatic fail.
	if (GetEntityFlags(clientIdx) & FL_ONGROUND)
		return false;
	else if (failInWater && (GetEntityFlags(clientIdx) & (FL_SWIM | FL_INWATER)))
		return false;
		
	// need to do a trace
	static Float:origin[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", origin);
	
	new Handle:trace = TR_TraceRayFilterEx(origin, Float:{90.0,0.0,0.0}, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
	static Float:endPos[3];
	TR_GetEndPosition(endPos, trace);
	CloseHandle(trace);
	
	// only Z should change, so this is easy.
	return origin[2] - endPos[2] >= minClearance;
}

stock bool:IsInstanceOf(entity, const String:desiredClassname[])
{
	static String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, MAX_ENTITY_CLASSNAME_LENGTH);
	return strcmp(classname, desiredClassname) == 0;
}

stock RemoveInvincibility(victim)
{
	if (TF2_IsPlayerInCondition(victim, TFCond_Ubercharged))
		TF2_RemoveCondition(victim, TFCond_Ubercharged);
	if (TF2_IsPlayerInCondition(victim, TFCond_UberchargedHidden))
		TF2_RemoveCondition(victim, TFCond_UberchargedHidden);
	if (TF2_IsPlayerInCondition(victim, TFCond_UberchargedCanteen))
		TF2_RemoveCondition(victim, TFCond_UberchargedCanteen);
	if (TF2_IsPlayerInCondition(victim, TFCond_UberchargedOnTakeDamage))
		TF2_RemoveCondition(victim, TFCond_UberchargedOnTakeDamage);
	if (TF2_IsPlayerInCondition(victim, TFCond_Bonked))
		TF2_RemoveCondition(victim, TFCond_Bonked);
	if (TF2_IsPlayerInCondition(victim, TFCond_DefenseBuffMmmph))
		TF2_RemoveCondition(victim, TFCond_DefenseBuffMmmph);

	SetEntProp(victim, Prop_Data, "m_takedamage", 2);
}

/**
 * Credit to FlaminSarge (DO NOT COPY THESE TO PACK9!)
 */
new Handle:hPlayTaunt;
public RegisterForceTaunt()
{
	new Handle:conf = LoadGameConfigFile("tf2.tauntem");
	if (conf == INVALID_HANDLE)
	{
		PrintToServer("[sarysamods8] Unable to load gamedata/tf2.tauntem.txt. Guitar Hero DOT will not function.");
		return;
	}
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "CTFPlayer::PlayTauntSceneFromItem");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	hPlayTaunt = EndPrepSDKCall();
	if (hPlayTaunt == INVALID_HANDLE)
	{
		SetFailState("[sarysamods8] Unable to initialize call to CTFPlayer::PlayTauntSceneFromItem. Need to get updated tf2.tauntem.txt method signatures. Guitar Hero DOT will not function.");
		CloseHandle(conf);
		return;
	}
	CloseHandle(conf);
}

new congaFailurePrintout = false;
public ForceUserToShred(clientIdx)
{
	if (hPlayTaunt == INVALID_HANDLE)
		return; // return silently
		
	new itemdef = 1015; // shred alert
		
	new ent = MakeCEIVEnt(clientIdx, itemdef);
	if (!IsValidEntity(ent))
	{
		if (!congaFailurePrintout)
		{
			PrintToServer("[sarysamods8] Could not create shred alert taunt entity.");
			congaFailurePrintout = true;
		}
		return;
	}
	new Address:pEconItemView = GetEntityAddress(ent) + Address:FindSendPropInfo("CTFWearable", "m_Item");
	if (pEconItemView <= Address_MinimumValid)
	{
		if (!congaFailurePrintout)
		{
			PrintToServer("[sarysamods8] Couldn't find CEconItemView for shred alert.");
			congaFailurePrintout = true;
		}
		AcceptEntityInput(ent, "Kill");
		return;
	}
	
	new bool:success = SDKCall(hPlayTaunt, clientIdx, pEconItemView);
	AcceptEntityInput(ent, "Kill");
	//PrintToServer("Conga entity is %d", ent);
	
	if (!success && PRINT_DEBUG_SPAM)
		PrintToServer("[sarysamods8] Failed to force %d to shred alert.", clientIdx);
}

stock MakeCEIVEnt(client, itemdef)
{
	static Handle:hItem;
	if (hItem == INVALID_HANDLE)
	{
		hItem = TF2Items_CreateItem(OVERRIDE_ALL|PRESERVE_ATTRIBUTES|FORCE_GENERATION);
		TF2Items_SetClassname(hItem, "tf_wearable_vm");
		TF2Items_SetQuality(hItem, 6);
		TF2Items_SetLevel(hItem, 1);
		TF2Items_SetNumAttributes(hItem, 0);
	}
	TF2Items_SetItemIndex(hItem, itemdef);
	return TF2Items_GiveNamedItem(client, hItem);
}
