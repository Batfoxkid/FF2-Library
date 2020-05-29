// no warranty blah blah don't sue blah blah doing this for fun blah blah...

#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <drain_over_time>
#include <drain_over_time_subplugin>
#include <tf2attributes>
#include <ff2_dynamic_defaults>

#pragma semicolon 1
#pragma newdecls required

/**
 * My seventh VSP rage pack, rages for Sea Pony, Fluffle Puff, and Mega Pony
 *
 * DOTEntrapment: Fire a homing projectile. Upon hit, it gets replaced with another model and slowly drains the player's health.
 *
 * RageSkyNuke: Send one or more projectiles that the player can control to some degree from the noclip skies.
 * Known Issues: Two bosses using this in a duo boss setup will have issues if either have a model to swap to.
 *
 * DOTSuckAndChuck: 
 * Known Issues: Two bosses cannot have access to this rage at once, due to issues with the collision group settings.
 *               If you have maps where RED spawn eventually becomes uninhabitable, like run blitz, the anti-punking options will get the mercs killed on these maps.
 *		 Because of workarounds I've had to implement re: body blocking, collision is server-based thus sluggish the round this rage is active.
 *
 * General credits: Asherkin and voogru created the original rocket spawning code that I have used probably too many times now.
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
 
bool DEBUG_FORCE_RAGE = false;
#define ARG_LENGTH 256
 
bool PRINT_DEBUG_INFO = true;
bool PRINT_DEBUG_SPAM = false;

float OFF_THE_MAP[3] = { 16383.0, 16383.0, -16383.0 };

#define NOPE_AVI "vo/engineer_no01.mp3" // DO NOT DELETE FROM FUTURE PACKS

// text string limits
#define MAX_SOUND_FILE_LENGTH 80
#define MAX_MODEL_FILE_LENGTH 128
#define MAX_MATERIAL_FILE_LENGTH 128
#define MAX_WEAPON_NAME_LENGTH 64
#define MAX_WEAPON_ARG_LENGTH 256
#define MAX_EFFECT_NAME_LENGTH 48
#define MAX_ENTITY_CLASSNAME_LENGTH 48
#define MAX_CENTER_TEXT_LENGTH 128
#define MAX_RANGE_STRING_LENGTH 66
#define MAX_HULL_STRING_LENGTH 197
#define MAX_ATTACHMENT_NAME_LENGTH 48
#define COLOR_BUFFER_SIZE 12
#define HEX_OR_DEC_STRING_LENGTH 12 // max -2 billion is 11 chars + null termination

#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

int MercTeam = view_as<int>(TFTeam_Red);
int BossTeam = view_as<int>(TFTeam_Blue);

int RoundInProgress = false;
bool PluginActiveThisRound = false;

public Plugin myinfo = {
	name = "Freak Fortress 2: sarysa's mods, seventh pack",
	author = "sarysa",
	version = "1.3.1",
}

#define FAR_FUTURE 100000000.0
#define IsEmptyString(%1) (%1[0] == 0)
#define COND_JARATE_WATER 86

/**
 * DOT Entrapment
 */
#define DE_STRING "dot_entrapment"
#define DE_FLAG_HIDE_VICTIM 0x0001
#define DE_FLAG_NO_NORMAL_ATTACKS 0x0002
#define DE_FLAG_NO_VICTIM_HEALING 0x0004
#define DE_FLAG_UBER_KILLS_OBJECT 0x0008
#define DE_FLAG_SMART_FIRST_TARGET 0x0010
#define DE_FLAG_TRAP_MODEL_ON_PLAYER_ORIGIN 0x0020
#define DE_FLAG_ONE_OBJECT_PER_PERSON 0x0040
#define DE_FLAG_ANTIMAGIC 0x0080
#define DE_FLAG_MEGAHEAL_ALLOWS_HEALING 0x0100
#define DE_FLAG_BATTALIONS_REDUCTION 0x0200
#define DE_FLAG_MMMPH_NULLIFY 0x0400
#define DE_ANGLE_ADJUST_INTERVAL 0.05
#define DE_RETARGET_INTERVAL 0.05
#define DE_HUD_POSITION 0.68
#define DE_HUD_REFRESH_INTERVAL 0.1
bool DE_ActiveThisRound;
bool DE_CanUse[MAX_PLAYERS_ARRAY]; // internal
float DE_NextHUDAt[MAX_PLAYERS_ARRAY]; // internal
bool DE_OneObjectPerPerson;
float DE_GraceEndsAt[MAX_PLAYERS_ARRAY]; // internal, victim use only
float DE_Velocity[MAX_PLAYERS_ARRAY]; // arg1
float DE_AnglePerSecond[MAX_PLAYERS_ARRAY]; // arg2
float DE_Lifetime[MAX_PLAYERS_ARRAY]; // arg3
float DE_DamageInterval[MAX_PLAYERS_ARRAY]; // arg4
float DE_DamagePerTick[MAX_PLAYERS_ARRAY]; // arg5
int DE_ReskinnedModelIdx[MAX_PLAYERS_ARRAY]; // arg6
char DE_TrappedModel[MAX_MODEL_FILE_LENGTH]; // arg7
char DE_TrapSound[MAX_SOUND_FILE_LENGTH]; // arg8
float DE_SoundInterval[MAX_PLAYERS_ARRAY]; // arg9
char DE_TrapLoopingSound[MAX_SOUND_FILE_LENGTH]; // arg10
char DE_HudMessage[MAX_CENTER_TEXT_LENGTH]; // arg11
int DE_Flags[MAX_PLAYERS_ARRAY]; // arg19

//  dot entrapment projectile
#define DET_MAX_PROJECTILES 10
int DET_EntRef[DET_MAX_PROJECTILES];
int DET_Owner[DET_MAX_PROJECTILES];
bool DET_IsTrapping[DET_MAX_PROJECTILES];
int DET_HomingTarget[DET_MAX_PROJECTILES];
float DET_RetargetAt[DET_MAX_PROJECTILES];
float DET_ReangleAt[DET_MAX_PROJECTILES];
float DET_DamageAt[DET_MAX_PROJECTILES];
int DET_VictimExpectedHP[DET_MAX_PROJECTILES];
float DET_SoundAt[DET_MAX_PROJECTILES];
float DET_DieAt[DET_MAX_PROJECTILES];
float DET_LastPosition[DET_MAX_PROJECTILES][3]; // only used by the projectile version

/**
 * Stop Micromovement
 */
#define SM_STRING "ff2_stop_micromovement"
bool SM_ActiveThisRound;
bool SM_CanUse[MAX_PLAYERS_ARRAY];
float SM_LastPosition[MAX_PLAYERS_ARRAY][3];
float SM_MinPosChange[MAX_PLAYERS_ARRAY]; // arg1
bool SM_BlockX[MAX_PLAYERS_ARRAY]; // arg2
bool SM_BlockY[MAX_PLAYERS_ARRAY]; // arg3
bool SM_BlockZ[MAX_PLAYERS_ARRAY]; // arg4

/**
 * Rocket Ring
 */
#define RR_STRING "rage_rocket_ring"
bool RR_ActiveThisRound;
bool RR_CanUse[MAX_PLAYERS_ARRAY];
float RR_ReorientAt; // internal
int RR_RocketCount[MAX_PLAYERS_ARRAY]; // arg1
float RR_RocketYawPerSecond[MAX_PLAYERS_ARRAY]; // arg2
float RR_RocketReangleInterval; // arg3
float RR_RocketDamage[MAX_PLAYERS_ARRAY]; // arg4
float RR_Lifespan[MAX_PLAYERS_ARRAY]; // arg5
bool RR_UsePitch[MAX_PLAYERS_ARRAY]; // arg6
int RR_ModelReskin[MAX_PLAYERS_ARRAY]; // based on arg7, which is a string
float RR_StartVelocity[MAX_PLAYERS_ARRAY]; // arg8
float RR_EndVelocity[MAX_PLAYERS_ARRAY]; // arg9
float RR_VelocityScaleFactor[MAX_PLAYERS_ARRAY]; // arg10

// rocket ring projectiles
#define RRP_MAX_PROJECTILES 50
int RRP_EntRef[RRP_MAX_PROJECTILES];
int RRP_Owner[RRP_MAX_PROJECTILES];
float RRP_PitchAtZeroYaw[RRP_MAX_PROJECTILES]; // should be negative the pitch of the user's eye angles
float RRP_YawOffset[RRP_MAX_PROJECTILES];
float RRP_SpawnedAt[RRP_MAX_PROJECTILES];
float RRP_FullRotationTime[RRP_MAX_PROJECTILES];
float RRP_TimeInCurrentRotation[RRP_MAX_PROJECTILES];

/**
 * Designer Kill
 */
#define DK_STRING "ff2_designer_kill"
#define DK_CRIT_SOUND "player/crit_received1.wav"
#define DK_CRIT_SOUND_ATTACKER "player/crit_hit.wav"
#define DK_FLAG_EXPLODE 0x0001
#define DK_FLAG_ANTIMAGIC 0x0002
#define DK_FLAG_CANCEL_PAIN_SOUNDS 0x0004
#define DK_FLAG_SMART_BLAST_HANDLING 0x0008
bool DK_ActiveThisRound;
bool DK_CanUse[MAX_PLAYERS_ARRAY];
float DK_SuicideAt[MAX_PLAYERS_ARRAY]; // internal, defaults to FAR_FUTURE
int DK_ParticleEntRef[MAX_PLAYERS_ARRAY]; // internal, particle effect on players
int DK_PreviousHP[MAX_PLAYERS_ARRAY]; // internal
float DK_RemoveParticleAt[MAX_PLAYERS_ARRAY]; // internal, defaults to FAR_FUTURE
float DK_ActualAttackBaseDamage[MAX_PLAYERS_ARRAY]; // internal
bool DK_IgnoreOneAttack[MAX_PLAYERS_ARRAY]; // internal, used for spies
float DK_DamageFactorMin[MAX_PLAYERS_ARRAY]; // arg1
float DK_DamageFactorMax[MAX_PLAYERS_ARRAY]; // arg2
char DK_ParticleName[MAX_EFFECT_NAME_LENGTH]; // arg3
float DK_BattalionsDamageFactor[MAX_PLAYERS_ARRAY]; // arg4
float DK_NonFatalEffectDuration[MAX_PLAYERS_ARRAY]; // arg5
float DK_FatalityDuration[MAX_PLAYERS_ARRAY]; // arg6
float DK_CritChance[MAX_PLAYERS_ARRAY]; // arg7
// class death sounds
char DK_ScoutDeathSound[MAX_SOUND_FILE_LENGTH]; // arg10
char DK_SoldierDeathSound[MAX_SOUND_FILE_LENGTH]; // arg11
char DK_PyroDeathSound[MAX_SOUND_FILE_LENGTH]; // arg12
char DK_DemoDeathSound[MAX_SOUND_FILE_LENGTH]; // arg13
char DK_HeavyDeathSound[MAX_SOUND_FILE_LENGTH]; // arg14
char DK_EngieDeathSound[MAX_SOUND_FILE_LENGTH]; // arg15
char DK_MedicDeathSound[MAX_SOUND_FILE_LENGTH]; // arg16
char DK_SniperDeathSound[MAX_SOUND_FILE_LENGTH]; // arg17
char DK_SpyDeathSound[MAX_SOUND_FILE_LENGTH]; // arg18
// flags
int DK_Flags; // arg19

/**
 * Sky Nuke
 */
#define SN_STRING "rage_sky_nuke"
#define SNA_STRING "sky_nuke_aesthetics"
#define SN_FLAG_RELOAD_ARMS 0x0001
#define SN_FLAG_KILL_ON_AIRBLAST 0x0002
#define SN_FLAG_LOOPING_SOUND_ONCE 0x0004
#define SN_FLAG_HIGHLIGHT_MERCS 0x0008
bool SN_ActiveThisRound = false;
bool SN_CanUse[MAX_PLAYERS_ARRAY]; // internal
bool SN_IsUsing[MAX_PLAYERS_ARRAY]; // internal
bool SN_DestroyKeyDown[MAX_PLAYERS_ARRAY]; // internal
bool SN_IsArming[MAX_PLAYERS_ARRAY]; // internal
bool SN_ArmWasForced[MAX_PLAYERS_ARRAY]; // internal
float SN_PushAt[MAX_PLAYERS_ARRAY]; // internal
float SN_OriginalPosition[MAX_PLAYERS_ARRAY][3]; // internal
float SN_LastLegitPosition[MAX_PLAYERS_ARRAY][3]; // internal
float SN_InvincibilityEndsAt[MAX_PLAYERS_ARRAY]; // internal
float SN_StartedAt[MAX_PLAYERS_ARRAY]; // internal
float SN_EndsAt[MAX_PLAYERS_ARRAY]; // internal, set by arg1
float SN_ForceAngleUntil[MAX_PLAYERS_ARRAY]; // internal
bool SN_WasDeflected[MAX_PLAYERS_ARRAY]; // internal
int SN_Airblaster[MAX_PLAYERS_ARRAY]; // internal
bool SN_ProjectileActive[MAX_PLAYERS_ARRAY]; // internal
int SN_ProjectilesRemaining[MAX_PLAYERS_ARRAY]; // internal
bool SN_StartNextFrame[MAX_PLAYERS_ARRAY]; // internal
bool SN_WasDucking[MAX_PLAYERS_ARRAY]; // internal
float SN_DopplePushAt[MAX_PLAYERS_ARRAY]; // internal
int SN_ProjectilesPerRage[MAX_PLAYERS_ARRAY]; // arg1
float SN_Duration[MAX_PLAYERS_ARRAY]; // arg2
float SN_StartingVelocity[MAX_PLAYERS_ARRAY]; // arg3
float SN_EndingVelocity[MAX_PLAYERS_ARRAY]; // arg4
float SN_StartingZOffset[MAX_PLAYERS_ARRAY]; // arg5, though only used at spawn time
float SN_RocketDamage[MAX_PLAYERS_ARRAY]; // arg6
float SN_RocketRadius[MAX_PLAYERS_ARRAY]; // arg7
float SN_ArmTime[MAX_PLAYERS_ARRAY]; // arg8
float SN_ResidualInvincibilityTime[MAX_PLAYERS_ARRAY]; // arg9
float SN_MaxPitchDeviation[MAX_PLAYERS_ARRAY]; // arg10
float SN_PushInterval[MAX_PLAYERS_ARRAY]; // arg11
float SN_DopplePushIntensity[MAX_PLAYERS_ARRAY]; // arg12
float SN_DopplePushRadius[MAX_PLAYERS_ARRAY]; // arg13
int SN_Flags[MAX_PLAYERS_ARRAY]; // arg19
// aesthetics, shared by players if multi-boss
#define SNA_HUD_POSITION 0.60
#define SNA_HUD_REFRESH_INTERVAL 0.1
#define SNA_HUD_ERROR_DURATION 5.0
#define SNA_OVERLAY_REFRESH_INTERVAL 0.5
float SNA_LoopAt[MAX_PLAYERS_ARRAY]; // internal
float SNA_DGLoopAt[MAX_PLAYERS_ARRAY]; // internal
float SNA_UpdateHUDAt[MAX_PLAYERS_ARRAY]; // internal
float SNA_RefreshOverlayAt[MAX_PLAYERS_ARRAY]; // internal
int SNA_TrailEntRef[MAX_PLAYERS_ARRAY]; // internal
int SNA_DopplegangerEntRef[MAX_PLAYERS_ARRAY]; // internal
char SNA_OriginalModel[MAX_MODEL_FILE_LENGTH]; 
char SNA_LoopingSound[MAX_SOUND_FILE_LENGTH]; // arg1
float SNA_LoopInterval; // arg2
char SNA_ArmingSound[MAX_SOUND_FILE_LENGTH]; // arg3
char SNA_ExplodeSound[MAX_SOUND_FILE_LENGTH]; // arg4
char SNA_Overlay[MAX_MATERIAL_FILE_LENGTH]; // arg6
char SNA_ModelOverride[MAX_MODEL_FILE_LENGTH]; // arg7
char SNA_TrailName[MAX_EFFECT_NAME_LENGTH]; // arg8
char SNA_DopplegangerModel[MAX_MODEL_FILE_LENGTH]; // arg9
char SNA_ExplosionEffect[MAX_EFFECT_NAME_LENGTH]; // arg10
char SNA_HudInstructions[MAX_CENTER_TEXT_LENGTH]; // arg11
char SNA_HudAirblasted[MAX_CENTER_TEXT_LENGTH]; // arg12
char SNA_HudExploded[MAX_CENTER_TEXT_LENGTH]; // arg13
char SNA_WASDIsBad[MAX_CENTER_TEXT_LENGTH]; // arg14
char SNA_CheatingIsWorse[MAX_CENTER_TEXT_LENGTH]; // arg15
char SNA_DGLoopingSound[MAX_SOUND_FILE_LENGTH]; // arg16
float SNA_DGLoopInterval; // arg17

/**
 * DOT Suck and Chuck
 */
#define SAC_STRING "dot_suck_and_chuck"
#define SAC_FLAG_USE_POINT_HURT 0x0001
#define SAC_FLAG_PREVENT_TRAPPING 0x0002
#define SAC_FLAG_PIT_WORKAROUND 0x0004
bool SAC_ActiveThisRound;
bool SAC_CanUse[MAX_PLAYERS_ARRAY]; // internal
bool SAC_IsActive[MAX_PLAYERS_ARRAY]; // internal
float SAC_NextLoopAt[MAX_PLAYERS_ARRAY]; // internal
int SAC_CurrentOverlayFrame; // internal
float SAC_UnstuckCoords[3]; // internal
float SAC_RestoreCollisionGroupAt; // internal
float SAC_LastValidBossPos[MAX_PLAYERS_ARRAY][3]; // internal
float SAC_StopBlockingTouchesAt; // internal
float SAC_MaxVelocity[MAX_PLAYERS_ARRAY]; // arg1
float SAC_MaxVelocityShiftPerTick[MAX_PLAYERS_ARRAY]; // arg2
float SAC_MaxSuctionRadius[MAX_PLAYERS_ARRAY]; // arg3
float SAC_DamagePerTick[MAX_PLAYERS_ARRAY]; // arg4
float SAC_CollisionRadius[MAX_PLAYERS_ARRAY]; // arg5
char SAC_Overlay[MAX_MATERIAL_FILE_LENGTH]; // arg6
int SAC_OverlayFrames; // arg7
float SAC_EscapeVelocity[MAX_PLAYERS_ARRAY]; // arg8
char SAC_LoopingSound[MAX_SOUND_FILE_LENGTH]; // arg9
float SAC_LoopInterval; // arg10
float SAC_PitImmunityDuration; // arg11
float SAC_DamageCap[MAX_PLAYERS_ARRAY]; // arg12
int SAC_Flags; // arg19
// victims
#define SACV_MAX_ENVIRONMENTAL_DAMAGE 40.0
bool SACV_IsTrapped[MAX_PLAYERS_ARRAY];
int SACV_Trapper[MAX_PLAYERS_ARRAY];
float SACV_AccumulatedDamage[MAX_PLAYERS_ARRAY];
float SACV_ImmuneToEnvironmentUntil[MAX_PLAYERS_ARRAY];

/**
 * Class Nerfs -- Nerf a specific slot's damage. (or buff, optionally)
 */
#define CN_STRING "ff2_class_nerfs"
bool CN_ActiveThisRound;
bool CN_CanUse[MAX_PLAYERS_ARRAY]; // internal
float CN_DamageMultipliers[MAX_PLAYERS_ARRAY][10][4];

/**
 * Mega Buster
 */
#define MB_STRING "ff2_mega_buster"
#define MB_TEST_PROJECTILE_MAX_FAILURES 3
#define MB_HARD_PROJECTILE_MAX 10
#define MB_FLAG_NORMAL_SHOT_CRIT 0x0001
#define MB_FLAG_HALF_CHARGE_CRIT 0x0002
#define MB_FLAG_FULL_CHARGE_CRIT 0x0004
#define MB_FLAG_NORMAL_SHOT_PENETRATE 0x0010
#define MB_FLAG_HALF_CHARGE_PENETRATE 0x0020
#define MB_FLAG_FULL_CHARGE_PENETRATE 0x0040
#define MB_FLAG_HOLD_CHARGE_ON_SWITCH 0x0100
#define MB_FALLOFF_NONE 0
#define MB_FALLOFF_DECREASE 1
#define MB_FALLOFF_INCREASE 2
bool MB_ActiveThisRound;
bool MB_CanUse[MAX_PLAYERS_ARRAY];
int MB_InertShotgunEntRef[MAX_PLAYERS_ARRAY]; // internal, need to set the shotgun's ammo to zero at round start, and again if it's ever refreshed
bool MB_FireDown[MAX_PLAYERS_ARRAY]; // internal, used for charging
float MB_FireDownSince[MAX_PLAYERS_ARRAY]; // internal, used for charging
float MB_PlayChargeSoundOneAt[MAX_PLAYERS_ARRAY]; // internal
float MB_PlayChargeSoundTwoAt[MAX_PLAYERS_ARRAY]; // internal
bool MB_IsDisabled[MAX_PLAYERS_ARRAY]; // internal, used by mega abilities
float MB_BaseDamage[MAX_PLAYERS_ARRAY]; // arg1
float MB_HalfChargeDamage[MAX_PLAYERS_ARRAY]; // arg2
float MB_FullChargeDamage[MAX_PLAYERS_ARRAY]; // arg3
int MB_MaxProjectiles[MAX_PLAYERS_ARRAY]; // arg4
float MB_MaxDistance[MAX_PLAYERS_ARRAY]; // arg5
float MB_HalfChargeTime[MAX_PLAYERS_ARRAY]; // arg6
float MB_FullChargeTime[MAX_PLAYERS_ARRAY]; // arg7
float MB_BaseSpeed[MAX_PLAYERS_ARRAY]; // arg8
float MB_HalfChargeSpeed[MAX_PLAYERS_ARRAY]; // arg9
float MB_FullChargeSpeed[MAX_PLAYERS_ARRAY]; // arg10
float MB_BaseBuildingDamage[MAX_PLAYERS_ARRAY]; // arg11
float MB_HalfChargeBuildingDamage[MAX_PLAYERS_ARRAY]; // arg12
float MB_FullChargeBuildingDamage[MAX_PLAYERS_ARRAY]; // arg13
float MB_BonusDamagePercent[MAX_PLAYERS_ARRAY]; // arg14
float MB_BonusDamageExp[MAX_PLAYERS_ARRAY]; // arg15
int MB_DamageFalloffType[MAX_PLAYERS_ARRAY]; // arg18
int MB_Flags[MAX_PLAYERS_ARRAY]; // arg19

// aesthetics
#define MBA_STRING "mega_buster_aesthetics"
#define MBA_MAX_ATTACHMENT_NAME_LENGTH 16
float MBA_AttachParticleAt[MAX_PLAYERS_ARRAY]; // internal
int MBA_ParticleEntRef[MAX_PLAYERS_ARRAY]; // internal
int MBA_NormalReskin[MAX_PLAYERS_ARRAY]; // arg1, loaded up from a string
int MBA_HalfReskin[MAX_PLAYERS_ARRAY]; // arg2, loaded up from a string
int MBA_FullReskin[MAX_PLAYERS_ARRAY]; // arg3, loaded up from a string
float MBA_ChargeSoundOneDelay[MAX_PLAYERS_ARRAY]; // arg4
char MBA_ChargeSoundOne[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg5
float MBA_ChargeSoundTwoDelay[MAX_PLAYERS_ARRAY]; // arg6
char MBA_ChargeSoundTwo[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg7
float MBA_ChargeSoundLoopInterval[MAX_PLAYERS_ARRAY]; // arg8
char MBA_NormalFiringSound[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg9
char MBA_HalfChargeFiringSound[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg10
char MBA_FullChargeFiringSound[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg11
char MBA_HitSound[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg12
char MBA_DestroySound[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg13
char MBA_BounceSound[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg14
char MBA_AttachmentName[MAX_PLAYERS_ARRAY][MBA_MAX_ATTACHMENT_NAME_LENGTH]; // arg14
char MBA_AttachmentParticle[MAX_EFFECT_NAME_LENGTH]; // arg15, shared in a duo boss

// projectiles
int MB_ProjectileEntRefs[MAX_PLAYERS_ARRAY][MB_HARD_PROJECTILE_MAX];
bool MB_ProjectileMarkedForDeath[MAX_PLAYERS_ARRAY][MB_HARD_PROJECTILE_MAX];
float MB_ProjectilePlayerDamage[MAX_PLAYERS_ARRAY][MB_HARD_PROJECTILE_MAX];
float MB_ProjectileBuildingDamage[MAX_PLAYERS_ARRAY][MB_HARD_PROJECTILE_MAX];
bool MB_ProjectileHasCrits[MAX_PLAYERS_ARRAY][MB_HARD_PROJECTILE_MAX];
bool MB_ProjectileHasPenetration[MAX_PLAYERS_ARRAY][MB_HARD_PROJECTILE_MAX];
float MB_ProjectileSpawnPos[MAX_PLAYERS_ARRAY][MB_HARD_PROJECTILE_MAX][3];
float MB_ProjectileSpeed[MAX_PLAYERS_ARRAY][MB_HARD_PROJECTILE_MAX];

/**
 * Mega Abilities, which is simply a regulator for dynamically added abilities
 *
 * If I ever release a public version, it'll include callback support.
 */
#define MA_STRING "ff2_mega_abilities"
#define MA_FLAG_RECOLOR_PLAYER 0x0001
#define MA_FLAG_HIDE_HP_HUD 0x0002
#define MA_FLAG_HIDE_ENERGY_HUD 0x0004
#define MA_FLAG_IGNORE_SLOT_COMMANDS 0x0008
#define MA_HP_SEGMENTS 27
#define MA_ENERGY_SEGMENTS 28 // yep, energy has 1 more segment than health...at least in MM3
#define MA_HP_HUD_X 0.1
#define MA_HP_HUD_Y 0.03
#define MA_ENERGY_HUD_X MA_HP_HUD_X
#define MA_ENERGY_HUD_Y 0.07
#define MA_ABILITY_HUD_Y 0.60
#define MA_TUTORIAL_HUD_Y 0.68 // I can do this because the other HUD messages will be gone
#define MA_CHARGE_HUD_Y 0.88
#define MA_HUD_INTERVAL 0.1
#define MA_MAX_ABILITIES 16
#define MA_MAX_ABILITY_NAME_LENGTH 33
#define MA_MAX_NAME_LENGTH 21
#define MA_MAX_DESCRIPTION_LENGTH 61
bool MA_ActiveThisRound;
bool MA_CanUse[MAX_PLAYERS_ARRAY];
int MA_SelectedIndex[MAX_PLAYERS_ARRAY]; // internal
float MA_EnergyPercent[MAX_PLAYERS_ARRAY]; // the rage meter is completely taken over by this ability
bool MA_HasAbility[MAX_PLAYERS_ARRAY][MA_MAX_ABILITIES]; // abilities are stuck into a pool in case of a multiboss scenario, i.e. megaman + zero
float MA_UpdateHUDsAt[MAX_PLAYERS_ARRAY]; // internal
int MA_MaxHealth[MAX_PLAYERS_ARRAY]; // internal, used for interface
bool MA_ReloadDown[MAX_PLAYERS_ARRAY]; // internal
bool MA_UseDown[MAX_PLAYERS_ARRAY]; // internal
bool MA_SwitchBlocked[MAX_PLAYERS_ARRAY]; // internal
int MA_DefaultWeaponColor[MAX_PLAYERS_ARRAY]; // arg1
char MA_DepletedWeaponSound[MAX_SOUND_FILE_LENGTH]; // arg2, shared in a multiboss
char MA_WeaponSwitchSound[MAX_SOUND_FILE_LENGTH]; // arg3, shared in a multiboss
char MA_HUDMessage[MAX_CENTER_TEXT_LENGTH]; // arg4, shared in a multiboss
char MA_DefaultWeaponName[MAX_PLAYERS_ARRAY][MA_MAX_NAME_LENGTH]; // arg5, not shared especially since megaman + zero could be different
char MA_DefaultWeaponDesc[MAX_PLAYERS_ARRAY][MA_MAX_DESCRIPTION_LENGTH]; // arg6, not shared especially since megaman + zero could be different
char MA_SecondaryWeaponMessage[MAX_CENTER_TEXT_LENGTH]; // arg7
char MA_ChargeHUDMessage[MAX_CENTER_TEXT_LENGTH]; // arg8, replacement message for hidden charge HUD
char MA_ChargeFailHUDMessage[MAX_CENTER_TEXT_LENGTH]; // arg9, same

int MA_Flags[MAX_PLAYERS_ARRAY]; // arg19

// mega ability descriptors
bool MAD_AbilityExists[MA_MAX_ABILITIES];
char MAD_AbilityId[MA_MAX_ABILITIES][MA_MAX_ABILITY_NAME_LENGTH]; // i.e. ff2_mega_rainboom
char MAD_AbilityName[MA_MAX_ABILITIES][MA_MAX_NAME_LENGTH]; // arg1 of any ability
char MAD_AbilityDescription[MA_MAX_ABILITIES][MA_MAX_DESCRIPTION_LENGTH]; // arg2 of any ability
int MAD_AbilityColor[MA_MAX_ABILITIES]; // arg3 of any ability
float MAD_AbilityCosts[MA_MAX_ABILITIES]; // arg4 of any ability
float MAD_ClassModifiers[MA_MAX_ABILITIES][10]; // arg5 of any ability
int MAD_PlayerRecolor[MA_MAX_ABILITIES]; // arg18 of any ability

/**
 * Sonic Rainboom
 */
#define MR_STRING "ff2_mega_rainboom"
#define MR_VALIDATION_INTERVAL 0.05
bool MR_ActiveThisRound;
bool MR_CanUse[MAX_PLAYERS_ARRAY];
bool MR_AttackDown[MAX_PLAYERS_ARRAY]; // internal, a staple of all these mega abilities...
bool MR_HasToxicTouch[MAX_PLAYERS_ARRAY]; // internal, means rage is active and valid
float MR_VerifyRageAt[MAX_PLAYERS_ARRAY]; // internal
float MR_ForceFinishAt[MAX_PLAYERS_ARRAY]; // internal
float MR_PushYaw[MAX_PLAYERS_ARRAY]; // internal
bool MR_BouncePending[MAX_PLAYERS_ARRAY]; // internal
float MR_Damage[MAX_PLAYERS_ARRAY]; // arg6
float MR_ChargeIntensity[MAX_PLAYERS_ARRAY]; // arg7
float MR_ChargeDuration[MAX_PLAYERS_ARRAY]; // arg8
float MR_RequiredVelocity[MAX_PLAYERS_ARRAY]; // arg9
float MR_BounceIntensity[MAX_PLAYERS_ARRAY]; // arg10
char MR_UseSound[MAX_SOUND_FILE_LENGTH]; // arg11
float MR_MinZLift[MAX_PLAYERS_ARRAY]; // arg12
		
/**
 * Gem Seeker
 */
#define MG_STRING "ff2_mega_gem"
#define MG_HARD_PROJECTILE_MAX 10
bool MG_ActiveThisRound;
bool MG_CanUse[MAX_PLAYERS_ARRAY];
bool MG_AttackDown[MAX_PLAYERS_ARRAY]; // internal, a staple of all these mega abilities...
float MG_ForceEndImmunityAt[MAX_PLAYERS_ARRAY]; // internal
bool MG_IsImmune[MAX_PLAYERS_ARRAY]; // internal
int MG_EntRefs[MAX_PLAYERS_ARRAY][MG_HARD_PROJECTILE_MAX]; // internal
float MG_SpawnPos[MAX_PLAYERS_ARRAY][MG_HARD_PROJECTILE_MAX][3]; // internal
bool MG_MarkedForDeath[MAX_PLAYERS_ARRAY][MG_HARD_PROJECTILE_MAX]; // internal
float MG_ImmuneUntil[MAX_PLAYERS_ARRAY][MAX_PLAYERS_ARRAY]; // internal
float MG_ToxicRadius[MAX_PLAYERS_ARRAY]; // arg6
float MG_ToxicDamagePerTick[MAX_PLAYERS_ARRAY]; // arg7
float MG_ToxicImmunityPeriod[MAX_PLAYERS_ARRAY]; // arg8
float MG_ToxicImmunityDuration[MAX_PLAYERS_ARRAY]; // arg9
float MG_Damage[MAX_PLAYERS_ARRAY]; // arg10
float MG_DistanceLimit[MAX_PLAYERS_ARRAY]; // arg11
float MG_Speed[MAX_PLAYERS_ARRAY]; // arg12
int MG_MaxProjectiles[MAX_PLAYERS_ARRAY]; // arg13
int MG_Model[MAX_PLAYERS_ARRAY]; // arg14, derived from a string
char MG_FireSound[MAX_SOUND_FILE_LENGTH]; // arg15

/**
 * The Stare
 */
#define MS_STRING "ff2_mega_stare"
bool MS_ActiveThisRound;
bool MS_CanUse[MAX_PLAYERS_ARRAY];
bool MS_AttackDown[MAX_PLAYERS_ARRAY]; // internal, a staple of all these mega abilities...
float MS_VictimSpeedFactor[MAX_PLAYERS_ARRAY]; // internal, used for the victims
float MS_VictimSlowUntil[MAX_PLAYERS_ARRAY]; // internal, used for the victims
float MS_VictimExpectedSpeed[MAX_PLAYERS_ARRAY]; // internal, used for the victims
float MS_Radius[MAX_PLAYERS_ARRAY]; // arg6
float MS_Damage[MAX_PLAYERS_ARRAY]; // arg7
float MS_SlowFactor[MAX_PLAYERS_ARRAY]; // arg8
float MS_SlowDuration[MAX_PLAYERS_ARRAY]; // arg9
bool MS_HaltMotion[MAX_PLAYERS_ARRAY]; // arg10
char MS_UseSound[MAX_SOUND_FILE_LENGTH]; // arg11

/**
 * Magic Wave
 */
#define MM_STRING "ff2_mega_magic"
#define MM_HARD_PROJECTILE_MAX 10
#define MM_REANGLE_INTERVAL 0.1
bool MM_ActiveThisRound;
bool MM_CanUse[MAX_PLAYERS_ARRAY];
bool MM_AttackDown[MAX_PLAYERS_ARRAY]; // internal, a staple of all these mega abilities...
int MM_EntRefs[MAX_PLAYERS_ARRAY][MM_HARD_PROJECTILE_MAX]; // internal
int MM_ParentEntRef[MAX_PLAYERS_ARRAY][MM_HARD_PROJECTILE_MAX]; // internal
float MM_SpawnPos[MAX_PLAYERS_ARRAY][MM_HARD_PROJECTILE_MAX][3]; // internal
bool MM_MarkedForDeath[MAX_PLAYERS_ARRAY][MM_HARD_PROJECTILE_MAX];
float MM_ReangleAt[MAX_PLAYERS_ARRAY]; // internal
float MM_Damage[MAX_PLAYERS_ARRAY]; // arg6
float MM_Speed[MAX_PLAYERS_ARRAY]; // arg7
float MM_DistanceLimit[MAX_PLAYERS_ARRAY]; // arg8
int MM_MaxProjectiles[MAX_PLAYERS_ARRAY]; // arg9
float MM_AttractionFactor[MAX_PLAYERS_ARRAY]; // arg10
float MM_AttractionDistance[MAX_PLAYERS_ARRAY]; // arg11
int MM_Model[MAX_PLAYERS_ARRAY]; // arg12, derived from a string
char MM_Particle[MAX_EFFECT_NAME_LENGTH]; // arg13
char MM_FireSound[MAX_SOUND_FILE_LENGTH]; // arg14
float MM_AngleDeviation[MAX_PLAYERS_ARRAY]; // arg15

/**
 * Party Cannon
 */
#define MP_STRING "ff2_mega_party"
#define MP_HARD_PROJECTILE_MAX 10
#define MP_AUTO_DETONATION_INTERVAL 0.05
bool MP_ActiveThisRound;
bool MP_CanUse[MAX_PLAYERS_ARRAY];
bool MP_AttackDown[MAX_PLAYERS_ARRAY]; // internal, a staple of all these mega abilities...
int MP_EntRefs[MAX_PLAYERS_ARRAY][MP_HARD_PROJECTILE_MAX]; // internal
bool MP_PendingRelease[MAX_PLAYERS_ARRAY][MP_HARD_PROJECTILE_MAX]; // internal
float MP_DestroyAt[MAX_PLAYERS_ARRAY][MP_HARD_PROJECTILE_MAX]; // internal
float MP_CheckAutoDetonationAt[MAX_PLAYERS_ARRAY]; // internal
float MP_Damage[MAX_PLAYERS_ARRAY]; // arg6
float MP_Speed[MAX_PLAYERS_ARRAY]; // arg7
float MP_Lifetime[MAX_PLAYERS_ARRAY]; // arg8
int MP_Model[MAX_PLAYERS_ARRAY]; // arg9, derived from a model import
float MP_AutoDetonationDistance[MAX_PLAYERS_ARRAY]; // arg10
int MP_MaxProjectiles[MAX_PLAYERS_ARRAY]; // arg11
char MP_FireSound[MAX_SOUND_FILE_LENGTH]; // arg12

/**
 * Apple Bucker
 */
#define MAB_STRING "ff2_mega_apple"
#define MAB_HARD_PROJECTILE_MAX 10
bool MAB_ActiveThisRound;
bool MAB_CanUse[MAX_PLAYERS_ARRAY];
bool MAB_AttackDown[MAX_PLAYERS_ARRAY]; // internal, a staple of all these mega abilities...
int MAB_EntRefs[MAX_PLAYERS_ARRAY][MAB_HARD_PROJECTILE_MAX]; // internal
float MAB_Damage[MAX_PLAYERS_ARRAY]; // arg6
float MAB_Speed[MAX_PLAYERS_ARRAY]; // arg7
int MAB_Model[MAX_PLAYERS_ARRAY]; // arg8, derived from a model import
bool MAB_IsLooseCannon[MAX_PLAYERS_ARRAY]; // arg9
int MAB_MaxProjectiles[MAX_PLAYERS_ARRAY]; // arg10
		
/**
 * METHODS REQUIRED BY ff2 subplugin
 */
void PrintRageWarning()
{
	PrintToServer("*********************************************************************");
	PrintToServer("*                             WARNING                               *");
	PrintToServer("*       DEBUG_FORCE_RAGE in ff2_sarysamods7.sp is set to true!      *");
	PrintToServer("*  Any admin can use the 'rage' command to use rages in this pack!  *");
	PrintToServer("*  This is only for test servers. Disable this on your live server. *");
	PrintToServer("*********************************************************************");
}
 
#define CMD_FORCE_RAGE "rage"
public void OnPluginStart2()
{
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	PrecacheSound(NOPE_AVI); // DO NOT DELETE IN FUTURE MOD PACKS
	
	RegConsoleCmd("mega1", MA_MegaCommand);
	RegConsoleCmd("mega2", MA_MegaCommand);
	RegConsoleCmd("mega3", MA_MegaCommand);
	RegConsoleCmd("mega4", MA_MegaCommand);
	RegConsoleCmd("mega5", MA_MegaCommand);
	RegConsoleCmd("mega6", MA_MegaCommand);
	RegConsoleCmd("mega7", MA_MegaCommand);
	RegConsoleCmd("mega8", MA_MegaCommand);
	RegConsoleCmd("mega9", MA_MegaCommand);
	
	if (DEBUG_FORCE_RAGE)
	{
		PrintRageWarning();
		RegAdminCmd(CMD_FORCE_RAGE, CmdForceRage, ADMFLAG_GENERIC);
	}
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	RoundInProgress = true;
	
	// initialize variables
	PluginActiveThisRound = false;
	DE_ActiveThisRound = false;
	SM_ActiveThisRound = false;
	RR_ActiveThisRound = false;
	DK_ActiveThisRound = false;
	SN_ActiveThisRound = false;
	SAC_ActiveThisRound = false;
	SAC_RestoreCollisionGroupAt = FAR_FUTURE;
	SAC_StopBlockingTouchesAt = 0.0;
	CN_ActiveThisRound = false;
	MB_ActiveThisRound = false;
	MA_ActiveThisRound = false;
	for (int i = 0; i < MA_MAX_ABILITIES; i++)
		MAD_AbilityExists[i] = false;
	MS_ActiveThisRound = false;
	MR_ActiveThisRound = false;
	MG_ActiveThisRound = false;
	MM_ActiveThisRound = false;
	MP_ActiveThisRound = false;
	MAB_ActiveThisRound = false;
	
	// initialize arrays
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		// all client inits
		DE_CanUse[clientIdx] = false;
		DE_GraceEndsAt[clientIdx] = FAR_FUTURE;
		SM_CanUse[clientIdx] = false;
		RR_CanUse[clientIdx] = false;
		DK_CanUse[clientIdx] = false;
		DK_SuicideAt[clientIdx] = FAR_FUTURE;
		DK_ParticleEntRef[clientIdx] = 0;
		DK_RemoveParticleAt[clientIdx] = FAR_FUTURE;
		DK_IgnoreOneAttack[clientIdx] = false;
		SN_CanUse[clientIdx] = false;
		SN_IsUsing[clientIdx] = false;
		SN_InvincibilityEndsAt[clientIdx] = FAR_FUTURE;
		SN_StartNextFrame[clientIdx] = false;
		SAC_CanUse[clientIdx] = false;
		SAC_IsActive[clientIdx] = false;
		SACV_IsTrapped[clientIdx] = false;
		SACV_ImmuneToEnvironmentUntil[clientIdx] = 0.0;
		CN_CanUse[clientIdx] = false;
		MB_CanUse[clientIdx] = false;
		MB_IsDisabled[clientIdx] = false;
		MA_CanUse[clientIdx] = false;
		MA_SwitchBlocked[clientIdx] = false;
		MS_CanUse[clientIdx] = false;
		MS_AttackDown[clientIdx] = false;
		MS_VictimSlowUntil[clientIdx] = 0.0;
		MR_CanUse[clientIdx] = false;
		MR_AttackDown[clientIdx] = false;
		MR_BouncePending[clientIdx] = false;
		MG_CanUse[clientIdx] = false;
		MG_AttackDown[clientIdx] = false;
		MM_CanUse[clientIdx] = false;
		MM_AttackDown[clientIdx] = false;
		MP_CanUse[clientIdx] = false;
		MP_AttackDown[clientIdx] = false;
		MAB_CanUse[clientIdx] = false;
		MAB_AttackDown[clientIdx] = false;

		// boss-only inits
		int bossIdx = FF2_GetBossIndex(clientIdx);
		if (bossIdx < 0)
			continue;
		
		// DOT entrapment
		if (FF2_HasAbility(bossIdx, this_plugin_name, DE_STRING))
		{
			DE_ActiveThisRound = true;
			DE_CanUse[clientIdx] = true;
			DE_NextHUDAt[clientIdx] = GetEngineTime();
			
			DE_Velocity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DE_STRING, 1);
			DE_AnglePerSecond[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DE_STRING, 2);
			DE_Lifetime[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DE_STRING, 3);
			DE_DamageInterval[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DE_STRING, 4);
			DE_DamagePerTick[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DE_STRING, 5);
			DE_ReskinnedModelIdx[clientIdx] = ReadModelToInt(bossIdx, DE_STRING, 6);
			ReadModel(bossIdx, DE_STRING, 7, DE_TrappedModel);
			ReadSound(bossIdx, DE_STRING, 8, DE_TrapSound);
			DE_SoundInterval[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DE_STRING, 9);
			ReadSound(bossIdx, DE_STRING, 10, DE_TrapLoopingSound);
			ReadCenterText(bossIdx, DE_STRING, 11, DE_HudMessage);
			
			DE_Flags[clientIdx] = ReadHexOrDecString(bossIdx, DE_STRING, 19);
			DE_OneObjectPerPerson = (DE_Flags[clientIdx] & DE_FLAG_ONE_OBJECT_PER_PERSON) != 0;
			
			if (DE_ReskinnedModelIdx[clientIdx] == -1 || strlen(DE_TrappedModel) <= 3)
			{
				PrintToServer("[sarysamods7] ERROR: Invalid model specified for projectile reskin and/or entrapped model. Disabling %s", DE_STRING);
				DE_ActiveThisRound = false;
				DE_CanUse[clientIdx] = false;
			}
			else
			{
				PluginActiveThisRound = true;
			}
		}

		if (FF2_HasAbility(bossIdx, this_plugin_name, SM_STRING))
		{
			PluginActiveThisRound = true;
			SM_ActiveThisRound = true;
			SM_CanUse[clientIdx] = true;
			
			SM_MinPosChange[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SM_STRING, 1);
			SM_BlockX[clientIdx] = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, SM_STRING, 2) == 1);
			SM_BlockY[clientIdx] = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, SM_STRING, 3) == 1);
			SM_BlockZ[clientIdx] = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, SM_STRING, 4) == 1);
			
			if (PRINT_DEBUG_INFO)
				PrintToServer("[sarysamods7] User %d is using workaround for twitchy model.", clientIdx);
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, RR_STRING))
		{
			PluginActiveThisRound = true;
			RR_ActiveThisRound = true;
			RR_CanUse[clientIdx] = true;
			RR_ReorientAt = FAR_FUTURE;
			
			RR_RocketCount[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, RR_STRING, 1);
			RR_RocketYawPerSecond[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RR_STRING, 2);
			RR_RocketReangleInterval = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RR_STRING, 3);
			RR_RocketDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RR_STRING, 4);
			RR_Lifespan[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RR_STRING, 5);
			RR_UsePitch[clientIdx] = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, RR_STRING, 6) == 1);
			RR_ModelReskin[clientIdx] = ReadModelToInt(bossIdx, RR_STRING, 7);
			RR_StartVelocity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RR_STRING, 8);
			RR_EndVelocity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RR_STRING, 9);
			RR_VelocityScaleFactor[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RR_STRING, 10);
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, DK_STRING))
		{
			PluginActiveThisRound = true;
			DK_ActiveThisRound = true;
			DK_CanUse[clientIdx] = true;
			
			DK_DamageFactorMin[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DK_STRING, 1);
			DK_DamageFactorMax[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DK_STRING, 2);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DK_STRING, 3, DK_ParticleName, MAX_EFFECT_NAME_LENGTH);
			DK_BattalionsDamageFactor[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DK_STRING, 4);
			DK_NonFatalEffectDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DK_STRING, 5);
			DK_FatalityDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DK_STRING, 6);
			DK_CritChance[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DK_STRING, 7);
			
			// sound files, and their precaching
			ReadSound(bossIdx, DK_STRING, 10, DK_ScoutDeathSound);
			ReadSound(bossIdx, DK_STRING, 11, DK_SoldierDeathSound);
			ReadSound(bossIdx, DK_STRING, 12, DK_PyroDeathSound);
			ReadSound(bossIdx, DK_STRING, 13, DK_DemoDeathSound);
			ReadSound(bossIdx, DK_STRING, 14, DK_HeavyDeathSound);
			ReadSound(bossIdx, DK_STRING, 15, DK_EngieDeathSound);
			ReadSound(bossIdx, DK_STRING, 16, DK_MedicDeathSound);
			ReadSound(bossIdx, DK_STRING, 17, DK_SniperDeathSound);
			ReadSound(bossIdx, DK_STRING, 18, DK_SpyDeathSound);
			
			// flags
			DK_Flags = ReadHexOrDecString(bossIdx, DK_STRING, 19);
			
			// precache crit sound
			PrecacheSound(DK_CRIT_SOUND);
			PrecacheSound(DK_CRIT_SOUND_ATTACKER);
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, SN_STRING) && FF2_HasAbility(bossIdx, this_plugin_name, SNA_STRING))
		{
			PluginActiveThisRound = true;
			SN_ActiveThisRound = true;
			SN_CanUse[clientIdx] = true;
			
			// normal props
			SN_ProjectilesPerRage[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, SN_STRING, 1);
			SN_Duration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SN_STRING, 2);
			SN_StartingVelocity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SN_STRING, 3);
			SN_EndingVelocity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SN_STRING, 4);
			SN_StartingZOffset[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SN_STRING, 5);
			SN_RocketDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SN_STRING, 6);
			SN_RocketRadius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SN_STRING, 7);
			SN_ArmTime[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SN_STRING, 8);
			SN_ResidualInvincibilityTime[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SN_STRING, 9);
			SN_MaxPitchDeviation[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SN_STRING, 10);
			SN_PushInterval[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SN_STRING, 11);
			SN_DopplePushIntensity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SN_STRING, 12);
			SN_DopplePushRadius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SN_STRING, 13);
			SN_Flags[clientIdx] = ReadHexOrDecString(bossIdx, SN_STRING, 19);

			// aesthetic props
			ReadSound(bossIdx, SNA_STRING, 1, SNA_LoopingSound);
			SNA_LoopInterval = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SNA_STRING, 2);
			ReadSound(bossIdx, SNA_STRING, 3, SNA_ArmingSound);
			ReadSound(bossIdx, SNA_STRING, 4, SNA_ExplodeSound);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SNA_STRING, 6, SNA_Overlay, MAX_MATERIAL_FILE_LENGTH);
			ReadModel(bossIdx, SNA_STRING, 7, SNA_ModelOverride);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SNA_STRING, 8, SNA_TrailName, MAX_EFFECT_NAME_LENGTH);
			ReadModel(bossIdx, SNA_STRING, 9, SNA_DopplegangerModel);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SNA_STRING, 10, SNA_ExplosionEffect, MAX_EFFECT_NAME_LENGTH);
			ReadCenterText(bossIdx, SNA_STRING, 11, SNA_HudInstructions);
			ReadCenterText(bossIdx, SNA_STRING, 12, SNA_HudAirblasted);
			ReadCenterText(bossIdx, SNA_STRING, 13, SNA_HudExploded);
			ReadCenterText(bossIdx, SNA_STRING, 14, SNA_WASDIsBad);
			ReadCenterText(bossIdx, SNA_STRING, 15, SNA_CheatingIsWorse);
			ReadSound(bossIdx, SNA_STRING, 16, SNA_DGLoopingSound);
			SNA_DGLoopInterval = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SNA_STRING, 17);
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, SAC_STRING))
		{
			PluginActiveThisRound = true;
			SAC_ActiveThisRound = true;
			SAC_CanUse[clientIdx] = true;
			
			SAC_MaxVelocity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SAC_STRING, 1);
			SAC_MaxVelocityShiftPerTick[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SAC_STRING, 2);
			SAC_MaxSuctionRadius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SAC_STRING, 3);
			SAC_DamagePerTick[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SAC_STRING, 4);
			SAC_CollisionRadius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SAC_STRING, 5);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SAC_STRING, 6, SAC_Overlay, MAX_MATERIAL_FILE_LENGTH);
			SAC_OverlayFrames = FF2_GetAbilityArgument(bossIdx, this_plugin_name, SAC_STRING, 7);
			SAC_EscapeVelocity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SAC_STRING, 8);
			ReadSound(bossIdx, SAC_STRING, 9, SAC_LoopingSound);
			SAC_LoopInterval = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SAC_STRING, 10);
			SAC_PitImmunityDuration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SAC_STRING, 11);
			SAC_DamageCap[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SAC_STRING, 12);
			SAC_Flags = ReadHexOrDecString(bossIdx, SAC_STRING, 19);
			
			if (IsLivingPlayer(clientIdx))
				GetEntPropVector(clientIdx, Prop_Data, "m_vecOrigin", SAC_LastValidBossPos[clientIdx]);
			
			if (SAC_OverlayFrames <= 0)
				SAC_OverlayFrames = 1;
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, CN_STRING))
		{
			PluginActiveThisRound = true;
			CN_ActiveThisRound = true;
			CN_CanUse[clientIdx] = true;
			
			char unparsedString[40];
			char damageMultStrs[4][10];
			for (int i = 1; i <= 9; i++)
			{
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CN_STRING, i, unparsedString, 30);
				if (IsEmptyString(unparsedString))
				{
					CN_DamageMultipliers[clientIdx][i][0] = 1.0;
					CN_DamageMultipliers[clientIdx][i][1] = 1.0;
					CN_DamageMultipliers[clientIdx][i][2] = 1.0;
					CN_DamageMultipliers[clientIdx][i][3] = 1.0;
				}
				else
				{
					ExplodeString(unparsedString, ";", damageMultStrs, 4, 10);
					for (int j = 0; j < 4; j++)
					{
						CN_DamageMultipliers[clientIdx][i][j] = StringToFloat(damageMultStrs[j]);
						if (CN_DamageMultipliers[clientIdx][i][j] <= 0.0)
							CN_DamageMultipliers[clientIdx][i][j] = 1.0;
					}
				}
			}
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, MB_STRING))
		{
			MB_ActiveThisRound = true;
			MB_CanUse[clientIdx] = true;
			
			MB_BaseDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MB_STRING, 1);
			MB_HalfChargeDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MB_STRING, 2);
			MB_FullChargeDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MB_STRING, 3);
			MB_MaxProjectiles[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, MB_STRING, 4);
			MB_MaxDistance[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MB_STRING, 5);
			MB_HalfChargeTime[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MB_STRING, 6);
			MB_FullChargeTime[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MB_STRING, 7);
			MB_BaseSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MB_STRING, 8);
			MB_HalfChargeSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MB_STRING, 9);
			MB_FullChargeSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MB_STRING, 10);
			MB_BaseBuildingDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MB_STRING, 11);
			MB_HalfChargeBuildingDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MB_STRING, 12);
			MB_FullChargeBuildingDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MB_STRING, 13);
			MB_BonusDamagePercent[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MB_STRING, 14);
			MB_BonusDamageExp[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MB_STRING, 15);
			MB_DamageFalloffType[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, MB_STRING, 18);
			MB_Flags[clientIdx] = ReadHexOrDecString(bossIdx, MB_STRING, 19);
			
			if (FF2_HasAbility(bossIdx, this_plugin_name, MBA_STRING))
			{
				PluginActiveThisRound = true;

				MBA_NormalReskin[clientIdx] = ReadModelToInt(bossIdx, MBA_STRING, 1);
				MBA_HalfReskin[clientIdx] = ReadModelToInt(bossIdx, MBA_STRING, 2);
				MBA_FullReskin[clientIdx] = ReadModelToInt(bossIdx, MBA_STRING, 3);

				MBA_ChargeSoundOneDelay[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MBA_STRING, 4);
				ReadSound(bossIdx, MBA_STRING, 5, MBA_ChargeSoundOne[clientIdx]);
				MBA_ChargeSoundTwoDelay[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MBA_STRING, 6);
				ReadSound(bossIdx, MBA_STRING, 7, MBA_ChargeSoundTwo[clientIdx]);
				MBA_ChargeSoundLoopInterval[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MBA_STRING, 8);
				
				ReadSound(bossIdx, MBA_STRING, 9, MBA_NormalFiringSound[clientIdx]);
				ReadSound(bossIdx, MBA_STRING, 10, MBA_HalfChargeFiringSound[clientIdx]);
				ReadSound(bossIdx, MBA_STRING, 11, MBA_FullChargeFiringSound[clientIdx]);
				ReadSound(bossIdx, MBA_STRING, 12, MBA_HitSound[clientIdx]);
				ReadSound(bossIdx, MBA_STRING, 13, MBA_DestroySound[clientIdx]);
				ReadSound(bossIdx, MBA_STRING, 14, MBA_BounceSound[clientIdx]);

				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MBA_STRING, 15, MBA_AttachmentName[clientIdx], MBA_MAX_ATTACHMENT_NAME_LENGTH);
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MBA_STRING, 16, MBA_AttachmentParticle, MAX_EFFECT_NAME_LENGTH);
			
				// sanity
				if (MB_MaxProjectiles[clientIdx] > MB_HARD_PROJECTILE_MAX)
				{
					PrintToServer("[sarysamods7] WARNING: Mega Buster: You've specified a projectile max (%d) higher than hard maximum. (%d) Reducing.", MB_MaxProjectiles[clientIdx], MB_HARD_PROJECTILE_MAX);
					MB_MaxProjectiles[clientIdx] = MB_HARD_PROJECTILE_MAX;
				}
			
				// initialize
				for (int i = 0; i < MB_HARD_PROJECTILE_MAX; i++)
					MB_ProjectileEntRefs[clientIdx][i] = 0;
				
				if (PRINT_DEBUG_INFO)
					PrintToServer("[sarysamods7] Boss %d will use %s this round, reskins are %d %d %d", clientIdx, MB_STRING, MBA_NormalReskin[clientIdx], MBA_HalfReskin[clientIdx], MBA_FullReskin[clientIdx]);
					
				// schedule making the shotgun useless
				MB_InertShotgunEntRef[clientIdx] = 0;
				MB_FireDown[clientIdx] = false;
				
				// schedule attachment of effect, we can't do this immediately due to first round bug check
				MBA_AttachParticleAt[clientIdx] = GetEngineTime() + 0.3;
				MBA_ParticleEntRef[clientIdx] = 0;
			}
			else
			{
				PrintToServer("[sarysamods7] ERROR: %s also requires ability %s. Disabling.", MB_STRING, MBA_STRING);
				MB_ActiveThisRound = false;
				MB_CanUse[clientIdx] = false;
			}
		}
		
		if (MB_CanUse[clientIdx] && FF2_HasAbility(bossIdx, this_plugin_name, MA_STRING))
		{
			MA_ActiveThisRound = true;
			MA_CanUse[clientIdx] = true;
			MA_SelectedIndex[clientIdx] = -1; // needs to be adjusted after sub-abilities are loaded.
			MA_EnergyPercent[clientIdx] = 0.0;
			MA_UpdateHUDsAt[clientIdx] = GetEngineTime();
			for (int i = 0; i < MA_MAX_ABILITIES; i++)
				MA_HasAbility[clientIdx][i] = false;
			MA_MaxHealth[clientIdx] = 0;
			MA_ReloadDown[clientIdx] = false;
			MA_UseDown[clientIdx] = false;
			
			MA_DefaultWeaponColor[clientIdx] = ReadHexOrDecString(bossIdx, MA_STRING, 1);
			ReadSound(bossIdx, MA_STRING, 2, MA_DepletedWeaponSound);
			ReadSound(bossIdx, MA_STRING, 3, MA_WeaponSwitchSound);
			ReadCenterText(bossIdx, MA_STRING, 4, MA_HUDMessage);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MA_STRING, 5, MA_DefaultWeaponName[clientIdx], MA_MAX_NAME_LENGTH);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MA_STRING, 6, MA_DefaultWeaponDesc[clientIdx], MA_MAX_DESCRIPTION_LENGTH);
			ReadCenterText(bossIdx, MA_STRING, 7, MA_SecondaryWeaponMessage);
			ReadCenterText(bossIdx, MA_STRING, 8, MA_ChargeHUDMessage);
			ReadCenterText(bossIdx, MA_STRING, 9, MA_ChargeFailHUDMessage);
			
			MA_Flags[clientIdx] = ReadHexOrDecString(bossIdx, MA_STRING, 19);
		}
		
		// sub-abilities
		if (MA_CanUse[clientIdx])
		{
			if (FF2_HasAbility(bossIdx, this_plugin_name, MR_STRING))
			{
				MA_InitSubAbility(clientIdx, bossIdx, MR_STRING);
				
				MR_ActiveThisRound = true;
				MR_CanUse[clientIdx] = true;
				MR_HasToxicTouch[clientIdx] = false;
				MR_VerifyRageAt[clientIdx] = FAR_FUTURE;
				MR_ForceFinishAt[clientIdx] = FAR_FUTURE;
				
				MR_Damage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MR_STRING, 6);
				MR_ChargeIntensity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MR_STRING, 7);
				MR_ChargeDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MR_STRING, 8);
				MR_RequiredVelocity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MR_STRING, 9);
				MR_BounceIntensity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MR_STRING, 10);
				ReadSound(bossIdx, MR_STRING, 11, MR_UseSound);
				MR_MinZLift[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MR_STRING, 12);
			}

			if (FF2_HasAbility(bossIdx, this_plugin_name, MG_STRING))
			{
				MA_InitSubAbility(clientIdx, bossIdx, MG_STRING);
				
				MG_ActiveThisRound = true;
				MG_CanUse[clientIdx] = true;
				MG_IsImmune[clientIdx] = false;
				
				MG_ToxicRadius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MG_STRING, 6);
				MG_ToxicDamagePerTick[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MG_STRING, 7);
				MG_ToxicImmunityPeriod[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MG_STRING, 8);
				MG_ToxicImmunityDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MG_STRING, 9);
				MG_Damage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MG_STRING, 10);
				MG_DistanceLimit[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MG_STRING, 11);
				MG_Speed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MG_STRING, 12);
				MG_MaxProjectiles[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, MG_STRING, 13);
				MG_Model[clientIdx] = ReadModelToInt(bossIdx, MG_STRING, 14);
				ReadSound(bossIdx, MG_STRING, 15, MG_FireSound);
				
				if (MG_MaxProjectiles[clientIdx] > MG_HARD_PROJECTILE_MAX)
				{
					PrintToServer("[sarysamods7] WARNING (%s): Exceeded hard projectile max of %d. Reducing.", MG_STRING, MG_HARD_PROJECTILE_MAX);
					MG_MaxProjectiles[clientIdx] = MG_HARD_PROJECTILE_MAX;
				}
				
				for (int i = 0; i < MG_MaxProjectiles[clientIdx]; i++)
					MG_EntRefs[clientIdx][i] = 0;
			}

			if (FF2_HasAbility(bossIdx, this_plugin_name, MS_STRING))
			{
				MA_InitSubAbility(clientIdx, bossIdx, MS_STRING);
				
				MS_ActiveThisRound = true;
				MS_CanUse[clientIdx] = true;
				
				MS_Radius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MS_STRING, 6);
				MS_Damage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MS_STRING, 7);
				MS_SlowFactor[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MS_STRING, 8);
				MS_SlowDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MS_STRING, 9);
				MS_HaltMotion[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, MS_STRING, 10) == 1;
				ReadSound(bossIdx, MS_STRING, 11, MS_UseSound);
			}

			if (FF2_HasAbility(bossIdx, this_plugin_name, MM_STRING))
			{
				MA_InitSubAbility(clientIdx, bossIdx, MM_STRING);
				
				MM_ActiveThisRound = true;
				MM_CanUse[clientIdx] = true;
				MM_ReangleAt[clientIdx] = GetEngineTime();
				
				MM_Damage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM_STRING, 6);
				MM_Speed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM_STRING, 7);
				MM_DistanceLimit[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM_STRING, 8);
				MM_MaxProjectiles[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, MM_STRING, 9);
				MM_AttractionFactor[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM_STRING, 10);
				MM_AttractionDistance[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM_STRING, 11);
				MM_Model[clientIdx] = ReadModelToInt(bossIdx, MM_STRING, 12);
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MM_STRING, 13, MM_Particle, MAX_EFFECT_NAME_LENGTH);
				ReadSound(bossIdx, MM_STRING, 14, MM_FireSound);
				MM_AngleDeviation[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MM_STRING, 15);
				
				if (MM_MaxProjectiles[clientIdx] > MM_HARD_PROJECTILE_MAX)
				{
					PrintToServer("[sarysamods7] WARNING (%s): Exceeded hard projectile max of %d. Reducing.", MM_STRING, MM_HARD_PROJECTILE_MAX);
					MM_MaxProjectiles[clientIdx] = MM_HARD_PROJECTILE_MAX;
				}
				
				for (int i = 0; i < MM_MaxProjectiles[clientIdx]; i++)
				{
					MM_EntRefs[clientIdx][i] = 0;
					MM_ParentEntRef[clientIdx][i] = 0;
				}
			}

			if (FF2_HasAbility(bossIdx, this_plugin_name, MP_STRING))
			{
				MA_InitSubAbility(clientIdx, bossIdx, MP_STRING);
				
				MP_ActiveThisRound = true;
				MP_CanUse[clientIdx] = true;
				MP_CheckAutoDetonationAt[clientIdx] = GetEngineTime() + MP_AUTO_DETONATION_INTERVAL;
				
				MP_Damage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MP_STRING, 6);
				MP_Speed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MP_STRING, 7);
				MP_Lifetime[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MP_STRING, 8);
				MP_Model[clientIdx] = ReadModelToInt(bossIdx, MP_STRING, 9);
				MP_AutoDetonationDistance[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MP_STRING, 10);
				MP_MaxProjectiles[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, MP_STRING, 11);
				ReadSound(bossIdx, MP_STRING, 12, MP_FireSound);
				
				if (MP_MaxProjectiles[clientIdx] > MP_HARD_PROJECTILE_MAX)
				{
					PrintToServer("[sarysamods7] WARNING (%s): Exceeded hard projectile max of %d. Reducing.", MP_STRING, MP_HARD_PROJECTILE_MAX);
					MP_MaxProjectiles[clientIdx] = MP_HARD_PROJECTILE_MAX;
				}
				
				for (int i = 0; i < MP_MaxProjectiles[clientIdx]; i++)
					MP_EntRefs[clientIdx][i] = 0;
			}

			if (FF2_HasAbility(bossIdx, this_plugin_name, MAB_STRING))
			{
				MA_InitSubAbility(clientIdx, bossIdx, MAB_STRING);
				
				MAB_ActiveThisRound = true;
				MAB_CanUse[clientIdx] = true;
				
				MAB_Damage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MAB_STRING, 6);
				MAB_Speed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, MAB_STRING, 7);
				MAB_Model[clientIdx] = ReadModelToInt(bossIdx, MAB_STRING, 8);
				MAB_IsLooseCannon[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, MAB_STRING, 9) == 1;
				MAB_MaxProjectiles[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, MAB_STRING, 10);
				
				if (MAB_MaxProjectiles[clientIdx] > MAB_HARD_PROJECTILE_MAX)
				{
					PrintToServer("[sarysamods7] WARNING (%s): Exceeded hard projectile max of %d. Reducing.", MAB_STRING, MAB_HARD_PROJECTILE_MAX);
					MAB_MaxProjectiles[clientIdx] = MAB_HARD_PROJECTILE_MAX;
				}
				
				for (int i = 0; i < MAB_MaxProjectiles[clientIdx]; i++)
					MAB_EntRefs[clientIdx][i] = 0;
			}
		}
	}
	
	if (DE_ActiveThisRound)
	{
		for (int i = 0; i < DET_MAX_PROJECTILES; i++)
		{
			DET_EntRef[i] = 0;
			DET_HomingTarget[i] = -1;
		}
		
		// add hooks to all players
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsLivingPlayer(clientIdx))
				SDKHook(clientIdx, SDKHook_OnTakeDamage, DE_OnTakeDamage);
		}
	}

	if (SM_ActiveThisRound)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (SM_CanUse[clientIdx] && IsClientInGame(clientIdx))
			{
				SDKHook(clientIdx, SDKHook_PreThink, SM_PreThink);
			}
		}
	}
	
	if (RR_ActiveThisRound)
	{
		for (int i = 0; i < RRP_MAX_PROJECTILES; i++)
			RRP_EntRef[i] = 0;
	}
	
	if (DK_ActiveThisRound)
	{
		// add sound hook
		AddNormalSoundHook(DK_HookPainSounds);
	
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			// add damage hooks
			if (IsLivingPlayer(clientIdx))
			{
				SDKHook(clientIdx, SDKHook_OnTakeDamage, DK_OnTakeDamage);
				SDKHook(clientIdx, SDKHook_OnTakeDamagePost, DK_OnTakeDamagePost);
			}
		}
	}
	
	if (SN_ActiveThisRound)
	{
		HookEvent("object_deflected", SN_OnDeflect, EventHookMode_Pre);
	}

	if (SAC_ActiveThisRound)
	{
		// find the unstuck coords (due to megaman map, changed from teamspawn to a random player)
		int randomRed = FindRandomPlayer(false);
		if (IsValidEntity(randomRed))
			GetEntPropVector(randomRed, Prop_Data, "m_vecOrigin", SAC_UnstuckCoords);
			
		// add hooks
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsLivingPlayer(clientIdx))
			{
				//SDKHook(clientIdx, SDKHook_StartTouch, SAC_OnStartTouch);
//				SDKHook(clientIdx, SDKHook_ShouldCollide, SAC_OnCollide);
				SDKHook(clientIdx, SDKHook_OnTakeDamage, SAC_OnTakeDamage);
			}
		}
	}
	
	if (CN_ActiveThisRound)
	{
		// add hooks
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx) && CN_CanUse[clientIdx])
			{
				SDKHook(clientIdx, SDKHook_OnTakeDamage, CN_OnTakeDamage);
			}
		}
	}
	
	if (MB_ActiveThisRound)
	{
		// add hooks
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsLivingPlayer(clientIdx) && GetClientTeam(clientIdx) != BossTeam)
				SDKHook(clientIdx, SDKHook_OnTakeDamage, MB_OnTakeDamage);
		}
	}
	
	if (MA_ActiveThisRound)
	{
		// add hook for medic command
		AddCommandListener(MA_MedicCommand, "voicemenu");
	}

	if (MP_ActiveThisRound)
	{
		// add hooks
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsLivingPlayer(clientIdx) && GetClientTeam(clientIdx) != BossTeam)
			{
				SDKHook(clientIdx, SDKHook_OnTakeDamage, MP_OnTakeDamage);
				SDKHook(clientIdx, SDKHook_OnTakeDamagePost, MP_OnTakeDamagePost);
			}
		}
	}

	if (MAB_ActiveThisRound)
	{
		// add hooks
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsLivingPlayer(clientIdx) && GetClientTeam(clientIdx) != BossTeam)
			{
				SDKHook(clientIdx, SDKHook_OnTakeDamage, MAB_OnTakeDamage);
				SDKHook(clientIdx, SDKHook_OnTakeDamagePost, MAB_OnTakeDamagePost);
			}
		}
	}
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	RoundInProgress = false;
	
	if (DE_ActiveThisRound)
	{
		DE_ActiveThisRound = false;
		
		// cleanup, removing entities and fixing visibility
		for (int i = 0; i < DET_MAX_PROJECTILES; i++)
		{
			if (DET_EntRef[i] == 0)
				continue;
			
			RemoveEntityTele(DET_EntRef[i]);
			DET_EntRef[i] = 0;
			int victim = DET_HomingTarget[i];
			if (IsLivingPlayer(victim) && DET_IsTrapping[i])
			{
				if (DE_Flags[DET_Owner[i]] & DE_FLAG_HIDE_VICTIM)
				{
					ColorizePlayer(victim, view_as<int>( { 255, 255, 255, 255 } ));
				}
				TF2_RemoveCondition(victim, TFCond_Dazed);
				SetEntityMoveType(victim, MOVETYPE_WALK);
			}
		}
		
		// add hooks to all players
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx)) // must unhook dead players
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, DE_OnTakeDamage);
		}
	}
	
	if (SM_ActiveThisRound)
	{
		SM_ActiveThisRound = false;
		
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (SM_CanUse[clientIdx] && IsClientInGame(clientIdx))
			{
				SDKUnhook(clientIdx, SDKHook_PreThink, SM_PreThink);
				SM_CanUse[clientIdx] = false;
			}
		}
	}

	if (RR_ActiveThisRound)
	{
		RR_ActiveThisRound = false;
		
		for (int i = 0; i < RRP_MAX_PROJECTILES; i++)
			RRP_EntRef[i] = 0;
	}
	
	if (DK_ActiveThisRound)
	{
		DK_ActiveThisRound = false;
		
		// remove sound hook
		RemoveNormalSoundHook(DK_HookPainSounds);
		
		// remove damage hooks
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx)) // must unhook dead players
			{
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, DK_OnTakeDamage);
				SDKUnhook(clientIdx, SDKHook_OnTakeDamagePost, DK_OnTakeDamagePost);
			}

			// remove lingering particles
			if (DK_ParticleEntRef[clientIdx] != 0)
			{
				RemoveEntityTele(DK_ParticleEntRef[clientIdx]);
			}
		}
	}
	
	if (SN_ActiveThisRound)
	{
		SN_ActiveThisRound = false;
		UnhookEvent("object_deflected", SN_OnDeflect, EventHookMode_Pre);
		
		// post-rage cleanup
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (SN_CanUse[clientIdx] && SN_IsUsing[clientIdx])
				SN_EndRage(clientIdx, GetEngineTime());
		}
	}

	if (SAC_ActiveThisRound)
	{
		SAC_ActiveThisRound = false;
		
		// get people unstuck, as a courtesy. also restore their collision group.
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsLivingPlayer(clientIdx) && GetClientTeam(clientIdx) == MercTeam)
			{
				SetEntProp(clientIdx, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_PLAYER);
				
				if (SACV_IsTrapped[clientIdx])
				{
					SACV_IsTrapped[clientIdx] = false;
					TeleportEntity(clientIdx, SAC_UnstuckCoords, NULL_VECTOR, view_as<float>( { 0.0, 0.0, 0.0 } ));
				}
			}

			// remove hooks
			if (IsClientInGame(clientIdx))
			{
				//SDKUnhook(clientIdx, SDKHook_StartTouch, SAC_OnStartTouch);
//				SDKUnhook(clientIdx, SDKHook_ShouldCollide, SAC_OnCollide);
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, SAC_OnTakeDamage);
			}
		}
	}

	if (CN_ActiveThisRound)
	{
		// remove hooks
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx) && CN_CanUse[clientIdx])
			{
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, CN_OnTakeDamage);
			}
		}
	}
	
	if (MB_ActiveThisRound)
	{
		MB_ActiveThisRound = false;
	
		// remove damage hooks
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, MB_OnTakeDamage);
				
			if (MB_CanUse[clientIdx])
			{
				MB_CanUse[clientIdx] = false;
				for (int i = 0; i < MB_MaxProjectiles[clientIdx]; i++)
					if (MB_ProjectileEntRefs[clientIdx][i] != 0)
						RemoveEntityTele(MB_ProjectileEntRefs[clientIdx][i]);
			}
		}
	}
	
	if (MA_ActiveThisRound)
	{
		MA_ActiveThisRound = false;
	
		// add hook for medic command
		RemoveCommandListener(MA_MedicCommand, "voicemenu");
		
		// must re-enable HUD...this actually leaks into the next round!
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
			if (MA_CanUse[clientIdx])
				FF2_SetFF2flags(clientIdx, FF2_GetFF2flags(clientIdx) & (~FF2FLAG_HUDDISABLED));
	}
	
	if (MR_ActiveThisRound)
	{
		MR_ActiveThisRound = false;
		
		// remove that touch hook, which in rare cases may linger
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (MR_CanUse[clientIdx] && IsClientInGame(clientIdx))
			{
				MR_CanUse[clientIdx] = false;
				SDKUnhook(clientIdx, SDKHook_StartTouch, MR_OnStartTouch);
			}
		}
	}
	
	if (MP_ActiveThisRound)
	{
		MP_ActiveThisRound = false;
	
		// remove damage hooks
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
			{
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, MP_OnTakeDamage);
				SDKUnhook(clientIdx, SDKHook_OnTakeDamagePost, MP_OnTakeDamagePost);
			}
		}
	}
	
	if (MAB_ActiveThisRound)
	{
		MAB_ActiveThisRound = false;
	
		// remove damage hooks
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
			{
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, MAB_OnTakeDamage);
				SDKUnhook(clientIdx, SDKHook_OnTakeDamagePost, MAB_OnTakeDamagePost);
			}
		}
	}
}

public Action FF2_OnAbility2(int bossIdx, const char[] plugin_name, const char[] ability_name, int status)
{
	if (strcmp(plugin_name, this_plugin_name) != 0)
		return Plugin_Continue;
	else if (!RoundInProgress) // don't execute these rages with 0 players alive
		return Plugin_Continue;
		
	if (!strcmp(ability_name, RR_STRING))
	{
		Rage_RocketRing(ability_name, bossIdx);
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods7] Initiating Rocket Ring");
	}
	else if (!strcmp(ability_name, SN_STRING))
	{
		Rage_SkyNuke(ability_name, bossIdx);
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods7] Initiating Sky Nuke");
	}
	else if (!strcmp(ability_name, MA_STRING))
	{
		int clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
		PrintToServer("[sarysamods7] Super rare edge case of rage executing with %s, this code isn't useless! Yay.", MA_STRING);
		
		MA_EnergyPercent[clientIdx] = 100.0;
	}
		
	return Plugin_Continue;
}

/**
 * Debug Only!
 */
public Action CmdForceRage(int user, int argsInt)
{
	// get actual args
	char unparsedArgs[ARG_LENGTH];
	GetCmdArgString(unparsedArgs, ARG_LENGTH);
	
	// gotta do this
	PrintRageWarning();
	
	if (!strcmp("fixme", unparsedArgs))
	{
		PrintToConsole(user, "Will trigger fixme.");
		//Rage_RocketBarrage(RB_STRING, 0);
		
		return Plugin_Handled;
	}
	
	PrintToServer("[sarysamods7] Rage not found: %s", unparsedArgs);
	return Plugin_Continue;
}

/**
 * DOTs
 */
void DOTPostRoundStartInit()
{
	if (!RoundInProgress)
	{
		PrintToServer("[sarysamods7] DOTPostRoundStartInit() called when the round is over?! Shouldn't be possible!");
		return;
	}
	
	// nothing to do
}
 
void OnDOTAbilityActivated(int clientIdx)
{
	if (!PluginActiveThisRound)
		return;

	if (DE_CanUse[clientIdx])
	{
		DE_CreateProjectile(clientIdx); // it cannot fail.
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods7] %d created trapping projectile.", clientIdx);
	}

	if (SAC_CanUse[clientIdx])
	{
		SAC_OnActivated(clientIdx);
	}
}

void OnDOTAbilityDeactivated(int clientIdx)
{
	if (!PluginActiveThisRound)
		return;

	if (SAC_CanUse[clientIdx])
	{
		SAC_OnDeactivated(clientIdx);
	}
}

void OnDOTUserDeath(int clientIdx, int isInGame)
{
	// suppress
	if (clientIdx || isInGame) { }
}

Action OnDOTAbilityTick(int clientIdx, int tickCount)
{	
	if (!PluginActiveThisRound)
		return;

	if (DE_CanUse[clientIdx])
	{
		// since DOT entrapment is one-time use, deactivate it.
		ForceDOTAbilityDeactivation(clientIdx);
	}
	
	if (SAC_CanUse[clientIdx])
	{
		SAC_DOTTick(clientIdx);
	}

	// suppress
	if (tickCount) { }
}

/**
 * DOT Entrapment
 */
public bool DE_PlayerTrappedAlready(int victim)
{
	if (DE_OneObjectPerPerson)
		return false;
		
	for (int i = 0; i < DET_MAX_PROJECTILES; i++)
	{
		if (DET_EntRef[i] == 0)
			break;
			
		if (DET_IsTrapping[i] && victim == DET_HomingTarget[i])
			return true;
	}
	
	return false;
}
 
public Action DE_OnTakeDamage(int victim, int& attacker, int& inflictor, 
							float& damage, int& damagetype, int& weapon, 
							float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsLivingPlayer(victim))
		return Plugin_Continue;
	else if (GetClientTeam(victim) == BossTeam)
		return Plugin_Continue;
		
	for (int i = 0; i < DET_MAX_PROJECTILES; i++)
	{
		if (DET_IsTrapping[i] && DET_HomingTarget[i] == victim)
		{
			if (DE_Flags[DET_Owner[i]] & DE_FLAG_NO_NORMAL_ATTACKS)
				return Plugin_Handled; // disable normal damage
		}
	}
		
	return Plugin_Continue;
}
 
int DET_TracingForIndex = -1;
public bool DET_TraceRedPlayers(int entity, int contentsMask)
{
	if (IsLivingPlayer(entity) && GetClientTeam(entity) != BossTeam)
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods7] Hit player %d on trace.", entity);
		DET_HomingTarget[DET_TracingForIndex] = entity;
		return true;
	}

	return false;
}

public Action DE_OtherTouches(int projectile, int victim)
{
	return Plugin_Handled; // prevent explosion
}
 
public Action DE_OnStartTouch(int projectile, int victim)
{
	bool deflect = false;

	if (!IsLivingPlayer(victim))
		deflect = true;
	else if (GetClientTeam(victim) == BossTeam)
		deflect = true;
	else if (DE_PlayerTrappedAlready(victim))
		deflect = true;
	
	// deflect the projectile, invert all velocities and fix the angle
	if (deflect)
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods7] Deflecting projectile %d which touched %d", projectile, victim);
	
		// invert velocity
		//float velocity[3];
		//GetEntPropVector(projectile, Prop_Data, "m_vecVelocity", velocity);
		//velocity[0] = -velocity[0];
		//velocity[1] = -velocity[1];
		//velocity[2] = -velocity[2];
		
		// invert angles
		float angle[3];
		GetEntPropVector(projectile, Prop_Data, "m_angRotation", angle);
		angle[0] = -angle[0]; //fixAngle(angle[0] + 180.0);
		angle[1] = fixAngle(angle[1] + 180.0);
		
		// redo velocity
		float velocity[3];
		GetAngleVectors(angle, velocity, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(velocity, 600.0);
		
		// move the projectile out a little to prevent touches from stacking
		float position[3];
		GetEntPropVector(projectile, Prop_Data, "m_vecOrigin", position);
		//float offset[3];
		//GetAngleVectors(angle, offset, NULL_VECTOR, NULL_VECTOR);
		//ScaleVector(offset, 5.0);
		//position[0] -= offset[0];
		//position[1] -= offset[1];
		//position[2] -= offset[2];
		
		// teleport
		TeleportEntity(projectile, position, angle, velocity);
		
		return Plugin_Handled;
	}
	
	// get the angle
	float oldAngle[3];
	GetEntPropVector(projectile, Prop_Data, "m_angRotation", oldAngle);
	
	// find out which projectile this is
	int trapIdx = -1;
	for (int i = 0; i < DET_MAX_PROJECTILES; i++)
	{
		if (DET_EntRef[i] != 0 && EntRefToEntIndex(DET_EntRef[i]) == projectile)
		{
			trapIdx = i;
			break;
		}
	}
	
	// wtf?
	if (trapIdx == -1)
	{
		PrintToServer("[sarysamods7] ERROR: An invalid entity got hooked to StartTouch somehow. Unhooking it.");
		SDKUnhook(projectile, SDKHook_StartTouch, DE_OnStartTouch);
		return Plugin_Continue;
	}
	
	// if it hits someone else en route to the intended target, since this is still used
	DET_HomingTarget[trapIdx] = victim;
	
	// need the owner
	int owner = DET_Owner[trapIdx];
	
	// destroy old entity, create int entity, begin entrapment
	RemoveEntityTele(DET_EntRef[trapIdx]);
	DET_EntRef[trapIdx] = 0;
	DET_VictimExpectedHP[trapIdx] = GetEntProp(victim, Prop_Send, "m_iHealth");
	DET_DamageAt[trapIdx] = GetEngineTime();
	DET_SoundAt[trapIdx] = GetEngineTime() + DE_SoundInterval[owner];
	DET_IsTrapping[trapIdx] = true;

	// the actual spawning process
	int prop = CreateEntityByName("prop_physics_override");
	if (!IsValidEntity(prop))
	{
		PrintToServer("[sarysamods7] Failed to create trap prop. Destroying.");
		DE_RemoveObject(trapIdx);
		return Plugin_Handled;
	}
	
	SetEntityModel(prop, DE_TrappedModel);
	DispatchSpawn(prop);
	if (DE_Flags[owner] & DE_FLAG_TRAP_MODEL_ON_PLAYER_ORIGIN)
		GetEntPropVector(victim, Prop_Data, "m_vecOrigin", DET_LastPosition[trapIdx]);
	TeleportEntity(prop, DET_LastPosition[trapIdx], oldAngle, NULL_VECTOR);
	SetEntProp(prop, Prop_Data, "m_takedamage", 0);

	SetEntityMoveType(prop, MOVETYPE_NONE);
	SetEntProp(prop, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_NONE);
	SetEntProp(prop, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(prop, Prop_Send, "m_nSolidType", 0);

	// save the entity ref
	DET_EntRef[trapIdx] = EntIndexToEntRef(prop);
	
	// play the sound if one exists
	if (strlen(DE_TrapSound) > 3)
		PseudoAmbientSound(victim, DE_TrapSound);
		
	// hide victim if victim should be hidden
	if (DE_Flags[owner] & DE_FLAG_HIDE_VICTIM)
	{
		ColorizePlayer(victim, view_as<int>( { 255, 255, 255, 0 } ));
	}
	TF2_StunPlayer(victim, 99999.0, 0.0, TF_STUNFLAG_BONKSTUCK | TF_STUNFLAG_NOSOUNDOREFFECT, owner);
	SetEntProp(DET_HomingTarget[trapIdx], Prop_Data, "m_takedamage", 0); // 2015-03-24, temporary invincibility so shields aren't broken
	SetEntityMoveType(victim, MOVETYPE_NONE);
	
	return Plugin_Handled;
}

public void DE_CreateProjectile(int clientIdx)
{
	// create our rocket. no matter what, it's going to spawn, even if it ends up being out of map
	float speed = DE_Velocity[clientIdx];
	float damage = 0.0;
	
	int rocket = CreateEntityByName("tf_projectile_rocket");
	if (!IsValidEntity(rocket))
	{
		PrintToServer("[sarysamods7] Error: Invalid entity \"tf_projectile_rocket\". Won't spawn rocket. This is sarysa's fault.");
		return;
	}
	
	// determine spawn position, angle, and velocity
	static float position[3];
	GetClientEyePosition(clientIdx, position);
	position[2] -= 20.0;
	static float angle[3];
	GetClientEyeAngles(clientIdx, angle);
	static float spawnVelocity[3];
	GetAngleVectors(angle, spawnVelocity, NULL_VECTOR, NULL_VECTOR);
	spawnVelocity[0] *= speed;
	spawnVelocity[1] *= speed;
	spawnVelocity[2] *= speed;
	
	// deploy!
	TeleportEntity(rocket, position, angle, spawnVelocity);
	SetEntProp(rocket, Prop_Send, "m_bCritical", false); // no random crits
	SetEntDataFloat(rocket, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, damage, true); // credit to voogru
	SetEntProp(rocket, Prop_Send, "m_nSkin", 0); // set skin to red team's
	SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", clientIdx);
	SetVariantInt(MercTeam);
	AcceptEntityInput(rocket, "TeamNum", -1, -1, 0);
	SetVariantInt(MercTeam);
	AcceptEntityInput(rocket, "SetTeam", -1, -1, 0); 
	DispatchSpawn(rocket);
	
	// reskin it
	if (DE_ReskinnedModelIdx[clientIdx] != -1)
		SetEntProp(rocket, Prop_Send, "m_nModelIndex", DE_ReskinnedModelIdx[clientIdx]);
	
	// this may or not be needed for this application
	SetEntPropEnt(rocket, Prop_Send, "m_hOriginalLauncher", GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Melee));
	SetEntPropEnt(rocket, Prop_Send, "m_hLauncher", GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Melee));
	
	// add the projectile to the array
	for (int i = 0; i < DET_MAX_PROJECTILES; i++)
	{
		if (DET_EntRef[i] != 0)
			continue;
			
		DET_EntRef[i] = EntIndexToEntRef(rocket);
		DET_Owner[i] = clientIdx;
		DET_IsTrapping[i] = false;
		DET_HomingTarget[i] = -1;
		DET_TracingForIndex = i;
		if (DE_Flags[clientIdx] & DE_FLAG_SMART_FIRST_TARGET)
		{
			// the trace method will set homing target. nothing else to do.
			Handle trace = TR_TraceRayFilterEx(position, angle, MASK_PLAYERSOLID, RayType_Infinite, DET_TraceRedPlayers);
			CloseHandle(trace);
		}
		DET_RetargetAt[i] = DET_HomingTarget[i] == -1 ? GetEngineTime() : FAR_FUTURE;
		DET_ReangleAt[i] = DET_HomingTarget[i] == -1 ? FAR_FUTURE : GetEngineTime(); // do not reangle until a target is found
		DET_DieAt[i] = GetEngineTime() + DE_Lifetime[clientIdx];
		GetEntPropVector(rocket, Prop_Data, "m_vecOrigin", DET_LastPosition[i]);
		
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods7] Projectile spawned with default target of %d", DET_HomingTarget[i]);
		
		break;
	}
	
	// hook touches
	SDKHook(rocket, SDKHook_StartTouch, DE_OnStartTouch);
	SDKHook(rocket, SDKHook_StartTouchPost, DE_OtherTouches);
	SDKHook(rocket, SDKHook_Touch, DE_OtherTouches);
	SDKHook(rocket, SDKHook_TouchPost, DE_OtherTouches);
	SDKHook(rocket, SDKHook_EndTouch, DE_OtherTouches);
	SDKHook(rocket, SDKHook_EndTouchPost, DE_OtherTouches);
}

public void DE_RemoveObject(int removeIdx)
{
	// show victim if victim was be hidden
	int victim = DET_HomingTarget[removeIdx];
	if (IsLivingPlayer(victim) && DET_IsTrapping[removeIdx])
	{
		if (DE_Flags[DET_Owner[removeIdx]] & DE_FLAG_HIDE_VICTIM)
		{
			ColorizePlayer(victim, view_as<int>( { 255, 255, 255, 255 } ));
		}
		TF2_RemoveCondition(victim, TFCond_Dazed);
		DE_GraceEndsAt[victim] = GetEngineTime() + 1.0;
		SetEntityMoveType(victim, MOVETYPE_WALK);
	}
	
	RemoveEntityTele(DET_EntRef[removeIdx]);
	DET_EntRef[removeIdx] = 0;
	for (int i = removeIdx; i < DET_MAX_PROJECTILES - 1; i++)
	{
		DET_EntRef[i] = DET_EntRef[i+1];
		DET_Owner[i] = DET_Owner[i+1];
		DET_IsTrapping[i] = DET_IsTrapping[i+1];
		DET_HomingTarget[i] = DET_HomingTarget[i+1];
		DET_RetargetAt[i] = DET_RetargetAt[i+1];
		DET_ReangleAt[i] = DET_ReangleAt[i+1];
		DET_DamageAt[i] = DET_DamageAt[i+1];
		DET_VictimExpectedHP[i] = DET_VictimExpectedHP[i+1];
		DET_SoundAt[i] = DET_SoundAt[i+1];
		DET_DieAt[i] = DET_DieAt[i+1];
		for (int j = 0; j < 3; j++)
			DET_LastPosition[i][j] = DET_LastPosition[i+1][j];
	}
}

public void DE_Tick(float curTime)
{
	// 2015-03-24, remove grace invincibility
	for (int victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (IsLivingPlayer(victim) && GetClientTeam(victim) == MercTeam)
		{
			if (curTime >= DE_GraceEndsAt[victim])
			{
				DE_GraceEndsAt[victim] = FAR_FUTURE;
				SetEntProp(victim, Prop_Data, "m_takedamage", 2);
			}
		}
	}

	for (int i = DET_MAX_PROJECTILES - 1; i >= 0; i--)
	{
		if (DET_EntRef[i] == 0)
			continue;
		
		// basic checks
		int trapObject = EntRefToEntIndex(DET_EntRef[i]);
		if (!IsValidEntity(trapObject) || curTime >= DET_DieAt[i])
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods7] Object %d reached end of life or somehow self-destructed. Destroying.", i);

			DE_RemoveObject(i);
			continue;
		}
		
		// is owner alive?
		if (!IsLivingPlayer(DET_Owner[i]))
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods7] Object %d's owner is dead or logged off. Destroying.", i);

			DE_RemoveObject(i);
			continue;
		}
		
		int owner = DET_Owner[i];
		
		// used by multiple
		static float trapPos[3];
		static float trapAngle[3];
		GetEntPropVector(trapObject, Prop_Data, "m_vecOrigin", trapPos);
		GetEntPropVector(trapObject, Prop_Data, "m_angRotation", trapAngle);
		
		// some trapping conditions destroy the object
		if (DET_IsTrapping[i] && !IsLivingPlayer(DET_HomingTarget[i]))
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods7] Object killed off %d or they suicided. Destroying object.", DET_HomingTarget[i]);

			DE_RemoveObject(i);
			continue;
		}
		else if (DET_IsTrapping[i] && TF2_IsPlayerInCondition(DET_HomingTarget[i], TFCond_Ubercharged) && (DE_Flags[owner] & DE_FLAG_UBER_KILLS_OBJECT) != 0)
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods7] Object must die because %d was ubercharged.", DET_HomingTarget[i]);

			DE_RemoveObject(i);
			continue;
		}
		
		// perform wall test, trapped already test, and uber test
		if (DET_HomingTarget[i] != -1 && !DET_IsTrapping[i])
		{
			if (TF2_IsPlayerInCondition(DET_HomingTarget[i], TFCond_Ubercharged) || DE_PlayerTrappedAlready(DET_HomingTarget[i]))
			{
				DET_HomingTarget[i] = -1;
				DET_RetargetAt[i] = curTime;
			}
			else
			{
				// get angle to victim
				static float victimPos[3];
				static float angleToPlayer[3];
				GetEntPropVector(DET_HomingTarget[i], Prop_Data, "m_vecOrigin", victimPos);
				GetVectorAnglesTwoPoints(trapPos, victimPos, angleToPlayer);
				
				// trace
				static float endPos[3];
				Handle trace = TR_TraceRayFilterEx(trapPos, angleToPlayer, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
				TR_GetEndPosition(endPos, trace);
				CloseHandle(trace);
	
				// test distance to ensure no wall between the two
				float distance = GetVectorDistance(endPos, trapPos);
				float minDistance = GetVectorDistance(victimPos, trapPos) - 0.5; // give a little allowance
				if (distance < minDistance)
				{
					if (PRINT_DEBUG_SPAM)
						PrintToServer("[sarysamods7] Lost our target behind a wall. Seeking int target.");

					DET_HomingTarget[i] = -1; // no good, means we hit a wall between the two points.
					DET_RetargetAt[i] = curTime;
				}
			}
		}
		
		// find a target. if no target can be found, stop moving until one pops up.
		if (DET_HomingTarget[i] == -1 && curTime >= DET_RetargetAt[i])
		{
			int bestValidTarget = -1;
			float bestValidAngleDeviation = 999.0;
			
			for (int victim = 1; victim < MAX_PLAYERS; victim++)
			{
				if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
					continue;
				else if (TF2_IsPlayerInCondition(victim, TFCond_Ubercharged)) // do not pursue ubers
					continue;
				else if (DE_PlayerTrappedAlready(victim)) // do not pursue already trapped targets
					continue;
				
				// get information we need for the trace
				static float endPos[3];
				static float victimPos[3];
				static float angleToPlayer[3];
				GetEntPropVector(victim, Prop_Data, "m_vecOrigin", victimPos);
				GetVectorAnglesTwoPoints(trapPos, victimPos, angleToPlayer);
				
				// perform trace
				Handle trace = TR_TraceRayFilterEx(trapPos, angleToPlayer, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
				TR_GetEndPosition(endPos, trace);
				CloseHandle(trace);
				
				// test distance to ensure no wall between the two
				float distance = GetVectorDistance(endPos, trapPos);
				float minDistance = GetVectorDistance(victimPos, trapPos) - 0.5; // give a little allowance
				if (distance < minDistance)
					continue; // no good, means we hit a between the two points.
					
				// ensure angle deviation is the best we've got
				float angleDeviation = fmax(fabs(angleToPlayer[0] - trapAngle[0]), fabs(angleToPlayer[1] - trapAngle[1]));
				if (angleDeviation > 180.0) // 2015-01-12, fix obvious (now) fail math, was causing scallop to just run out to who knows where
					angleDeviation = fabs(360.0 - angleDeviation);
					
				if (angleDeviation < bestValidAngleDeviation)
				{
					bestValidTarget = victim;
					bestValidAngleDeviation = angleDeviation;
				}
			}
			
			// no good target? stop the rocket in its tracks
			if (bestValidTarget == -1)
			{
				static float velocity[3];
				GetEntPropVector(trapObject, Prop_Data, "m_vecVelocity", velocity);
				if (velocity[0] != 0.0 || velocity[1] != 0.0 || velocity[2] != 0.0) // don't waste net traffic
				{
					if (PRINT_DEBUG_SPAM)
						PrintToServer("[sarysamods7] Object %d could not find target. Stopping motion.", i);

					TeleportEntity(trapObject, NULL_VECTOR, NULL_VECTOR, view_as<float>( { 0.0, 0.0, 0.0 } ));
				}
					
				// don't retry immediately. I believe this is one thing that causes homing projectiles to lag the server
				DET_RetargetAt[i] = curTime + DE_RETARGET_INTERVAL;
			}
			else
			{
				if (PRINT_DEBUG_SPAM)
					PrintToServer("[sarysamods7] Object %d will now home in on %d.", i, bestValidTarget);

				DET_HomingTarget[i] = bestValidTarget;
				DET_ReangleAt[i] = curTime;
			}
		}
		
		// always store the last position
		if (!DET_IsTrapping[i])
		{
			GetEntPropVector(trapObject, Prop_Data, "m_vecOrigin", DET_LastPosition[i]);
		}
		
		// perform ticks for the rocket first, ticks for the trapping entity second
		if (DET_HomingTarget[i] != -1 && !DET_IsTrapping[i])
		{
			if (curTime >= DET_ReangleAt[i])
			{
				// need our delta time for accuracy
				float deltaTime = DE_ANGLE_ADJUST_INTERVAL + (curTime - DET_ReangleAt[i]);

				// get angle to victim
				static float victimPos[3];
				static float angleToPlayer[3];
				GetEntPropVector(DET_HomingTarget[i], Prop_Data, "m_vecOrigin", victimPos);
				victimPos[2] += 41.5; // seek their midsection, not their feet
				GetVectorAnglesTwoPoints(trapPos, victimPos, angleToPlayer);
				
				// how much should we deviate the angle this check?
				float maxDeviation = deltaTime * DE_AnglePerSecond[owner];
				for (int angleIdx = 0; angleIdx < 2; angleIdx++)
				{
					if (fabs(trapAngle[angleIdx] - angleToPlayer[angleIdx]) <= 180.0)
					{
						if (trapAngle[angleIdx] - angleToPlayer[angleIdx] < 0.0)
							trapAngle[angleIdx] += fmin(maxDeviation, angleToPlayer[angleIdx] - trapAngle[angleIdx]);
						else
							trapAngle[angleIdx] -= fmin(maxDeviation, trapAngle[angleIdx] - angleToPlayer[angleIdx]);
					}
					else // it wrapped around
					{
						float tmpRocketAngle = trapAngle[angleIdx];

						if (trapAngle[angleIdx] - angleToPlayer[angleIdx] < 0.0)
							tmpRocketAngle += 360.0;
						else
							tmpRocketAngle -= 360.0;

						if (tmpRocketAngle - angleToPlayer[angleIdx] < 0.0)
							trapAngle[angleIdx] += fmin(maxDeviation, angleToPlayer[angleIdx] - tmpRocketAngle);
						else
							trapAngle[angleIdx] -= fmin(maxDeviation, tmpRocketAngle - angleToPlayer[angleIdx]);
					}

					trapAngle[angleIdx] = fixAngle(trapAngle[angleIdx]);
				}
				
				// reangle the projectile and fix the velocity
				static float trapVelocity[3];
				GetAngleVectors(trapAngle, trapVelocity, NULL_VECTOR, NULL_VECTOR);
				ScaleVector(trapVelocity, DE_Velocity[owner]);
				TeleportEntity(trapObject, NULL_VECTOR, trapAngle, trapVelocity);
			
				DET_ReangleAt[i] += DE_ANGLE_ADJUST_INTERVAL;
			}
		}
		else if (DET_HomingTarget[i] != -1 && DET_IsTrapping[i])
		{
			// antimagic
			if (DE_Flags[owner] & DE_FLAG_ANTIMAGIC)
			{
				int weapon = GetEntPropEnt(DET_HomingTarget[i], Prop_Send, "m_hActiveWeapon");
				if (IsValidEntity(weapon))
				{
					static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
					GetEntityClassname(weapon, classname, MAX_ENTITY_CLASSNAME_LENGTH);
					if (!strcmp(classname, "tf_weapon_spellbook"))
					{
						for (int slot = 0; slot <= 2; slot++)
						{
							int newWeapon = GetPlayerWeaponSlot(DET_HomingTarget[i], slot);
							if (IsValidEntity(newWeapon))
							{
								SetEntPropEnt(DET_HomingTarget[i], Prop_Send, "m_hActiveWeapon", newWeapon);
								break;
							}
						}
					}
				}
			}
		
			// workaround, in case MOVETYPE_NONE or is lost somehow
			SetEntityMoveType(DET_HomingTarget[i], MOVETYPE_NONE);
					
			if (curTime >= DET_SoundAt[i])
			{
				if (strlen(DE_TrapLoopingSound) > 3)
					PseudoAmbientSound(DET_HomingTarget[i], DE_TrapLoopingSound);
				DET_SoundAt[i] += DE_SoundInterval[owner];
			}
			
			if (curTime >= DET_DamageAt[i])
			{
				if (PRINT_DEBUG_SPAM)
					PrintToServer("[sarysamods7] Victim %d being damaged by trap entity.", DET_HomingTarget[i]);
					
				// is the victim a cloaked spy?
				float actualDamage = DE_DamagePerTick[owner];
				int cloak = GetPlayerWeaponSlot(DET_HomingTarget[i], 4);
				if (TF2_GetPlayerClass(DET_HomingTarget[i]) == TFClass_Spy)
				{
					int weaponIdx = 1;
					
					if (IsValidEntity(cloak))
					{
						// ff2 does this for some reason
						static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
						GetEntityClassname(cloak, classname, MAX_ENTITY_CLASSNAME_LENGTH);

						weaponIdx = StrContains(classname, "tf_weapon") == 0 ? GetEntProp(cloak, Prop_Send, "m_iItemDefinitionIndex") : 1;
					}
					
					// cloak
					if (weaponIdx != 59 && TF2_IsPlayerInCondition(DET_HomingTarget[i], TFCond_Cloaked))
						actualDamage = fmax(actualDamage * 0.1, 1.0);
				}

				// battalion's backup
				if ((DE_Flags[owner] & DE_FLAG_BATTALIONS_REDUCTION) != 0 && TF2_IsPlayerInCondition(DET_HomingTarget[i], TFCond_DefenseBuffed))
					actualDamage = fmax(actualDamage * 0.4, 1.0);

				// mmmph defense buff (not applicable to sea pony), MUST BE LAST!
				if ((DE_Flags[owner] & DE_FLAG_MMMPH_NULLIFY) != 0 && TF2_IsPlayerInCondition(DET_HomingTarget[i], TFCond_DefenseBuffMmmph))
					actualDamage = 0.0;
					
				if (actualDamage > 0.0)
				{
					SetEntProp(DET_HomingTarget[i], Prop_Data, "m_takedamage", 2);
					SDKHooks_TakeDamage(DET_HomingTarget[i], owner, owner, actualDamage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
					if (IsLivingPlayer(DET_HomingTarget[i]))
						SetEntProp(DET_HomingTarget[i], Prop_Data, "m_takedamage", 0);
					DET_VictimExpectedHP[i] -= RoundFloat(actualDamage);
					DET_DamageAt[i] += DE_DamageInterval[owner];
				}
			}
		}
		
		// block healing
		if (DET_IsTrapping[i])
		{
			if (IsLivingPlayer(DET_HomingTarget[i]))
			{
				if (DE_Flags[owner] & DE_FLAG_NO_VICTIM_HEALING)
				{
					if ((DE_Flags[owner] & DE_FLAG_MEGAHEAL_ALLOWS_HEALING) != 0 && TF2_IsPlayerInCondition(DET_HomingTarget[i], TFCond_MegaHeal))
					{
						DET_VictimExpectedHP[i] = GetEntProp(DET_HomingTarget[i], Prop_Data, "m_iHealth");
					}
					else
					{
						SetEntProp(DET_HomingTarget[i], Prop_Data, "m_iHealth", DET_VictimExpectedHP[i]);
						SetEntProp(DET_HomingTarget[i], Prop_Send, "m_iHealth", DET_VictimExpectedHP[i]);
					}
				}
			}
		}
	}
}

/**
 * Stop Micromovement
 */
public void SM_PreThink(int clientIdx)
{
	if (!IsLivingPlayer(clientIdx))
		return;
		
//	static float velocity[3];
//	GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", velocity);
	
	// see if we should tamper with vel
//	bool shouldTamper = true;
//	if (SM_BlockX[clientIdx] && fabs(velocity[0]) >= SM_MinVelocity[clientIdx])
//		shouldTamper = false;
//	if (SM_BlockY[clientIdx] && fabs(velocity[1]) >= SM_MinVelocity[clientIdx])
//		shouldTamper = false;
//	if (SM_BlockZ[clientIdx] && fabs(velocity[2]) >= SM_MinVelocity[clientIdx])
//		shouldTamper = false;
		
	static float origin[3];
	GetEntPropVector(clientIdx, Prop_Data, "m_vecOrigin", origin);
	if (origin[0] != SM_LastPosition[clientIdx][0] && origin[1] != SM_LastPosition[clientIdx][1] && origin[2] != SM_LastPosition[clientIdx][2])
	{
		//PrintToServer("Origin changed: %f,%f,%f --> %f,%f,%f", SM_LastPosition[clientIdx][0], SM_LastPosition[clientIdx][1], SM_LastPosition[clientIdx][2], origin[0], origin[1], origin[2]);
		
		bool shouldTamper = true;
		if (SM_BlockX[clientIdx] && fabs(SM_LastPosition[clientIdx][0] - origin[0]) >= SM_MinPosChange[clientIdx])
			shouldTamper = false;
		else if (SM_BlockY[clientIdx] && fabs(SM_LastPosition[clientIdx][1] - origin[1]) >= SM_MinPosChange[clientIdx])
			shouldTamper = false;
		else if (SM_BlockZ[clientIdx] && fabs(SM_LastPosition[clientIdx][2] - origin[2]) >= SM_MinPosChange[clientIdx])
			shouldTamper = false;
		
		if (shouldTamper)
		{
			//PrintToServer("Tampering");
			if (SM_BlockX[clientIdx])
				origin[0] = SM_LastPosition[clientIdx][0];
			if (SM_BlockY[clientIdx])
				origin[1] = SM_LastPosition[clientIdx][1];
			if (SM_BlockZ[clientIdx])
				origin[2] = SM_LastPosition[clientIdx][2];
				
			TeleportEntity(clientIdx, origin, NULL_VECTOR, view_as<float>( { 0.0, 0.0, 0.0 } ));
		}

		SM_LastPosition[clientIdx][0] = origin[0];
		SM_LastPosition[clientIdx][1] = origin[1];
		SM_LastPosition[clientIdx][2] = origin[2];
	}
		
	// tamper with whatever we're set to tamper with
//	if (shouldTamper)
//	{
//		//if (velocity[0] != 0.0 && velocity[1] != 0.0)
//		//	PrintToServer("tampering with velocity, was %f, %f, %f", velocity[0], velocity[1], velocity[2]);
//		
//		if (SM_BlockX[clientIdx])
//			velocity[0] = 0.0;
//		if (SM_BlockY[clientIdx])
//			velocity[1] = 0.0;
//		if (SM_BlockZ[clientIdx])
//			velocity[2] = 0.0;
//		TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, velocity);
//	}
}

/**
 * Rocket Ring
 */
public void RR_RemoveRocket(int rrpIdx)
{
	RemoveEntityTele(RRP_EntRef[rrpIdx]);
	RRP_EntRef[rrpIdx] = 0;
	
	for (int i = rrpIdx; i < RRP_MAX_PROJECTILES - 1; i++)
	{
		RRP_EntRef[i] = RRP_EntRef[i+1];
		RRP_Owner[i] = RRP_Owner[i+1];
		RRP_PitchAtZeroYaw[i] = RRP_PitchAtZeroYaw[i+1];
		RRP_YawOffset[i] = RRP_YawOffset[i+1];
		RRP_SpawnedAt[i] = RRP_SpawnedAt[i+1];
		RRP_FullRotationTime[i] = RRP_FullRotationTime[i+1];
		RRP_TimeInCurrentRotation[i] = RRP_TimeInCurrentRotation[i+1];
	}
}

public void RR_GetRocketAngle(int rrpIdx, float angle[3])
{
	int owner = RRP_Owner[rrpIdx];
	float newYaw = fixAngle(-(360.0 * (RRP_TimeInCurrentRotation[rrpIdx] / RRP_FullRotationTime[rrpIdx])));
	float newPitch = 0.0;
	if (RR_UsePitch[owner])
	{
		if (newYaw >= -90.0 && newYaw <= 90.0)
			newPitch = (1.0 - (fabs(newYaw) / 90.0)) * RRP_PitchAtZeroYaw[rrpIdx];
		else if (newYaw < -90.0 || newYaw > 90.0)
			newPitch = -((fabs(newYaw) - 90.0) / 90.0) * RRP_PitchAtZeroYaw[rrpIdx];
	}
	newYaw = fixAngle(newYaw + RRP_YawOffset[rrpIdx]);
	
	angle[0] = newPitch;
	angle[1] = newYaw;
}

public void RR_ReorientRocket(int rrpIdx, float curTime)
{
	int rocket = EntRefToEntIndex(RRP_EntRef[rrpIdx]);
	if (!IsValidEntity(rocket))
	{
		// should never get here
		RR_RemoveRocket(rrpIdx);
		return;
	}
	
	static float angle[3];
	static float velocity[3];
	RR_GetRocketAngle(rrpIdx, angle);
	GetAngleVectors(angle, velocity, NULL_VECTOR, NULL_VECTOR);
	
	// velocity scaling requires knowing how far into the rocket's lifetime we are
	int owner = RRP_Owner[rrpIdx];
	float scaleFactor = RR_StartVelocity[owner] + (RR_VelocityScaleFactor[owner] * ((RR_EndVelocity[owner] - RR_StartVelocity[owner]) * ((curTime - RRP_SpawnedAt[rrpIdx]) / RR_Lifespan[owner])));
	scaleFactor = fmin(scaleFactor, fmax(RR_EndVelocity[owner], RR_StartVelocity[owner]));
	scaleFactor = fmax(scaleFactor, fmin(RR_EndVelocity[owner], RR_StartVelocity[owner]));
	ScaleVector(velocity, scaleFactor);
	
	TeleportEntity(rocket, NULL_VECTOR, angle, velocity);
}

// based on asherkin and voogru's code, though this is almost exactly like the code used for Snowdrop's rockets
// luckily energy ball and sentry rocket derive from rocket so they should be easy
public int RR_CreateRocket(int owner, float rocketMotionValue)
{
	// create our rocket. no matter what, it's going to spawn, even if it ends up being out of map
	float damage = fixDamageForFF2(RR_RocketDamage[owner]);
	
	int rocket = CreateEntityByName("tf_projectile_rocket");
	if (!IsValidEntity(rocket))
	{
		PrintToServer("[sarysamods7] Error: Invalid entity \"tf_projectile_rocket\". Won't spawn rocket. This is sarysa's fault.");
		return -1;
	}
	
	// need boss origin
	static float bossOrigin[3];
	GetEntPropVector(owner, Prop_Send, "m_vecOrigin", bossOrigin);
	bossOrigin[2] += 41.5; // don't spawn at the boss' feet
	
	// determine spawn position. no angle or velocity yet
	// position is basically, 1HU in front of the hale at 0.0N, 1HU behind the hale at 0.5N, going clockwise
	static float spawnPosition[3];
	static float tmpAngle[3];
	tmpAngle[0] = 0.0; // no pitch
	tmpAngle[1] = fixAngle(-rocketMotionValue * 360.0);
	tmpAngle[2] = 0.0; // no roll
	Handle trace = TR_TraceRayFilterEx(bossOrigin, tmpAngle, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
	TR_GetEndPosition(spawnPosition, trace);
	CloseHandle(trace);
	ConformLineDistance(spawnPosition, bossOrigin, spawnPosition, 1.0);
	
	// deploy!
	TeleportEntity(rocket, spawnPosition, NULL_VECTOR, NULL_VECTOR);
	SetEntProp(rocket, Prop_Send, "m_bCritical", false); // no random crits
	SetEntDataFloat(rocket, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, damage, true); // credit to voogru
	SetEntProp(rocket, Prop_Send, "m_nSkin", 0); // set skin to red team's
	SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", owner);
	SetVariantInt(MercTeam);
	AcceptEntityInput(rocket, "TeamNum", -1, -1, 0);
	SetVariantInt(MercTeam);
	AcceptEntityInput(rocket, "SetTeam", -1, -1, 0); 
	DispatchSpawn(rocket);
	
	// to get stats from the sentry
	SetEntPropEnt(rocket, Prop_Send, "m_hOriginalLauncher", GetPlayerWeaponSlot(owner, TFWeaponSlot_Melee));
	SetEntPropEnt(rocket, Prop_Send, "m_hLauncher", GetPlayerWeaponSlot(owner, TFWeaponSlot_Melee));
	
	// reskin after spawn
	if (RR_ModelReskin[owner] != -1)
		SetEntProp(rocket, Prop_Send, "m_nModelIndex", RR_ModelReskin[owner]);
	
	return rocket;
}

public void RR_Tick(float curTime)
{
	for (int rrpIdx = RRP_MAX_PROJECTILES - 1; rrpIdx >= 0; rrpIdx--)
	{
		if (RRP_EntRef[rrpIdx] == 0)
			continue;
		
		// hale must be alive
		int owner = RRP_Owner[rrpIdx];
		if (!IsLivingPlayer(owner))
		{
			RR_RemoveRocket(rrpIdx);
			continue;
		}
		
		// rocket must not have reached EOL
		if (curTime >= RRP_SpawnedAt[rrpIdx] + RR_Lifespan[owner])
		{
			RR_RemoveRocket(rrpIdx);
			continue;
		}
		
		// rocket must not have exploded
		int rocket = EntRefToEntIndex(RRP_EntRef[rrpIdx]);
		if (!IsValidEntity(rocket))
		{
			RR_RemoveRocket(rrpIdx);
			continue;
		}
		
		// all that's left to do is reorient, if valid
		float deltaTime = (curTime - RR_ReorientAt) + RR_RocketReangleInterval;
		if (deltaTime >= RR_RocketReangleInterval)
		{
			RRP_TimeInCurrentRotation[rrpIdx] += deltaTime;
			int sanity = 0;
			while (RRP_TimeInCurrentRotation[rrpIdx] > RRP_FullRotationTime[rrpIdx] && sanity < 50)
			{
				RRP_TimeInCurrentRotation[rrpIdx] -= RRP_FullRotationTime[rrpIdx];
				sanity++;
				
				if (sanity == 50)
					PrintToServer("[sarysamods7] ERROR: Sanity failed on rocket ring, time in current rotation.");
			}
			
			RR_ReorientRocket(rrpIdx, curTime);
		}
	}
	
	if (curTime >= RR_ReorientAt)
		RR_ReorientAt = curTime + RR_RocketReangleInterval;
}

public void Rage_RocketRing(const char[] ability_name, int bossIdx)
{
	int clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	// find the first free
	int startAt = 0;
	for (startAt = 0; startAt < RRP_MAX_PROJECTILES; startAt++)
	{
		if (RRP_EntRef[startAt] == 0)
			break;
	}
	
	// not good
	if (startAt == RRP_MAX_PROJECTILES)
	{
		PrintToServer("[sarysamods7] WARNING: Somehow user reached rocket ring projectile limit %d", RRP_MAX_PROJECTILES);
		return;
	}
	
	// and our ending position
	int endAt = min(startAt + RR_RocketCount[clientIdx], RRP_MAX_PROJECTILES) - 1;
	
	// get our rocket count, which is important for configuring our ring
	int rocketCount = (endAt - startAt) + 1;
	if (rocketCount <= 0)
	{
		PrintToServer("[sarysamods7] ERROR: Somehow set to spawn %d rockets. Aborting.", rocketCount);
		return;
	}
	
	// need the hale's eye angles
	float eyeAngles[3];
	GetClientEyeAngles(clientIdx, eyeAngles);
	
	// figure out the full rotation time now
	float fullRotationTime = 360.0 / RR_RocketYawPerSecond[clientIdx];
	
	// spawn 'em
	for (int rrpIdx = startAt; rrpIdx <= endAt; rrpIdx++)
	{
		float rocketMotionValue = (eyeAngles[1] / 360.0) + (float(rrpIdx - startAt) / float(rocketCount));
		if (rocketMotionValue < 0.0)
			rocketMotionValue += 1.0;
		else if (rocketMotionValue >= 1.0)
			rocketMotionValue -= 1.0;
		int rocket = RR_CreateRocket(clientIdx, rocketMotionValue);
		if (rocket == -1)
			break;
			
		RRP_EntRef[rrpIdx] = EntIndexToEntRef(rocket);
		RRP_Owner[rrpIdx] = clientIdx;
		RRP_PitchAtZeroYaw[rrpIdx] = eyeAngles[0];
		RRP_YawOffset[rrpIdx] = eyeAngles[1];
		RRP_SpawnedAt[rrpIdx] = GetEngineTime();
		RRP_FullRotationTime[rrpIdx] = fullRotationTime;
		RRP_TimeInCurrentRotation[rrpIdx] = rocketMotionValue * fullRotationTime;
		
		//PrintToServer("rocket %d, rmv=%f    timeincurrent=%f    fulltime=%f", rrpIdx, rocketMotionValue, RRP_TimeInCurrentRotation[rrpIdx], RRP_FullRotationTime[rrpIdx]);
	}
	
	// reset the reorientation timer
	RR_ReorientAt = GetEngineTime();
}

/**
 * Designer Kill
 */
public float DK_GetAttribute(int weapon, int attribute, float defaultValue)
{
	Address addr = TF2Attrib_GetByDefIndex(weapon, attribute);
	return addr == Address_Null ? defaultValue:TF2Attrib_GetValue(addr);
}
 
#define PROVIDE_ON_ACTIVE 128
#define MELEE_DAMAGE_INCREASE 206
#define ALL_DAMAGE_INCREASE 412
public float DK_GetCurrentDamageMultiplier(int clientIdx, int damagetype)
{
	float ret = 1.0;
	for (int pass = 0; pass <= 2; pass++)
	{
		int weapon = GetPlayerWeaponSlot(clientIdx, pass);
		if (!IsValidEntity(weapon))
			continue;
			
		// handle provide on active
		if (DK_GetAttribute(weapon, PROVIDE_ON_ACTIVE, 0.0))
			if (weapon != GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon"))
				continue;
		
		ret *= DK_GetAttribute(weapon, ALL_DAMAGE_INCREASE, 1.0);
			
		if (damagetype & DMG_CLUB)
			ret *= DK_GetAttribute(weapon, MELEE_DAMAGE_INCREASE, 1.0);
			
		if (damagetype & DMG_BURN)
		{
			ret *= DK_GetAttribute(weapon, 60, 1.0);
			ret *= DK_GetAttribute(weapon, 61, 1.0);
		}

		if (damagetype & DMG_BLAST)
		{
			ret *= DK_GetAttribute(weapon, 64, 1.0);
			ret *= DK_GetAttribute(weapon, 65, 1.0);
		}

		if (damagetype & DMG_BULLET)
		{
			ret *= DK_GetAttribute(weapon, 66, 1.0);
			ret *= DK_GetAttribute(weapon, 67, 1.0);
		}
		
		// crits are weird. 1/3 of the damage should still remain unaffected
		if (damagetype & DMG_CRIT)
		{
			float normalModifier = ret / 3.0;
			float critModifier = ret * 2.0 / 3.0;
			critModifier *= DK_GetAttribute(weapon, 66, 1.0);
			critModifier *= DK_GetAttribute(weapon, 67, 1.0);
			ret = normalModifier + critModifier;
		}
	}
	
	return ret;
}

#define BLAST_TEST_DAMAGE 10.0
public Action DK_OnTakeDamage(int victim, int& attacker, int& inflictor, 
							float& damage, int& damagetype, int& weapon, 
							float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsLivingPlayer(victim))
		return Plugin_Continue;
	else if (GetClientTeam(victim) == BossTeam)
		return Plugin_Continue;
	else if (DK_SuicideAt[victim] != FAR_FUTURE)
		return Plugin_Handled; // do not apply damage to someone about to die
	else if (!IsLivingPlayer(attacker))
		return Plugin_Continue;
	else if (!DK_CanUse[attacker])
		return Plugin_Continue;
		
	// ff2 has special handling for spies. they can't receive a designer death if dead ringer is up or they're cloaked.
	if (TF2_GetPlayerClass(victim) == TFClass_Spy)
	{
		if (GetEntProp(victim, Prop_Send, "m_bFeignDeathReady") != 0 || TF2_IsPlayerInCondition(victim, TFCond_Cloaked))
		{
			DK_IgnoreOneAttack[victim] = true;
			return Plugin_Continue;
		}
	}
		
	// store base damage for this attack
	DK_ActualAttackBaseDamage[victim] = damage;
		
	// set damage to 4, so user gets kill credit but the victim doesn't immediately die
	if ((damagetype & DMG_BLAST) != 0 && (DK_Flags & DK_FLAG_SMART_BLAST_HANDLING) != 0)
	{
		if (GetEntProp(victim, Prop_Data, "m_iHealth") < (RoundFloat(BLAST_TEST_DAMAGE) * 2))
			SetEntProp(victim, Prop_Data, "m_iHealth", (RoundFloat(BLAST_TEST_DAMAGE) * 2));

		damage = BLAST_TEST_DAMAGE;
	}
	else
	{
		damage = 4.0;
		
		// make sure they have enough HP to survive a 8 damage hit with leeway for increased incoming damage attributes
		// originally I had this set to 1 but when I gave scoutbot 95% damage resist, it nullified the attack. so I set it to 40.
		// then I realized that it'll interfere with legitimate low damage kills from rages. so now it's 8.
		if (GetEntProp(victim, Prop_Data, "m_iHealth") < 8)
			SetEntProp(victim, Prop_Data, "m_iHealth", 8);
	}
	
	// should it be a crit? (note, only melee can crit)
	bool isCritical = GetRandomFloat(0.001, 1.0) <= DK_CritChance[attacker];
	if (weapon != GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee))
		isCritical = false;
	if (isCritical)
	{
		damagetype |= DMG_CRIT;
		damage *= 0.33;
	}
	
	// store the victim's health, so we know if the hit went through (i.e. did a demo shield or uber block it)
	DK_PreviousHP[victim] = GetEntProp(victim, Prop_Data, "m_iHealth");
	
	return Plugin_Changed;
}

public void DK_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (!IsLivingPlayer(attacker) || !IsLivingPlayer(victim))
		return;
	else if (GetClientTeam(victim) == BossTeam)
		return;
	else if (!DK_CanUse[attacker])
		return;
	else if (DK_SuicideAt[victim] != FAR_FUTURE)
		return; // they're about to die already
	else if (DK_IgnoreOneAttack[victim])
	{
		DK_IgnoreOneAttack[victim] = false;
		return;
	}
	
	//PrintToServer("Damage delivered was %f    damage flags are 0x%x", damage, damagetype);
	
	// did the victim take damage?
	int curHP = GetEntProp(victim, Prop_Data, "m_iHealth");
	bool stillAlive = true;
	bool isCritical = (damagetype & DMG_CRIT) != 0;
	if (curHP < DK_PreviousHP[victim])
	{
		// figure out a good actual damage to apply to the victim
		float realDamage = DK_ActualAttackBaseDamage[victim];
		
		// smart blast damage handling
		if ((damagetype & DMG_BLAST) != 0 && (DK_Flags & DK_FLAG_SMART_BLAST_HANDLING) != 0)
		{
			realDamage *= damage / BLAST_TEST_DAMAGE;
			
			if (isCritical)
				realDamage *= 3.0;
		}
		else
		{
			if (DK_DamageFactorMin[attacker] != DK_DamageFactorMax[attacker])
				realDamage = GetRandomFloat(fmin(realDamage * DK_DamageFactorMin[attacker], realDamage * DK_DamageFactorMax[attacker]),
						fmax(realDamage * DK_DamageFactorMin[attacker], realDamage * DK_DamageFactorMax[attacker]));
		
			// battalion's modifier
			if (TF2_IsPlayerInCondition(victim, TFCond_DefenseBuffed))
				realDamage *= DK_BattalionsDamageFactor[attacker];
			else if (isCritical)
				realDamage = DK_ActualAttackBaseDamage[victim] * 3.0;
		}
			
		// apply weapon attribute modifiers (i.e. to recognize things like KGBs)
		float damageMult = DK_GetCurrentDamageMultiplier(victim, damagetype);
		realDamage *= damageMult;
		//PrintToServer("damage is now %f based on damage mult %f, but don't forget %f already applied (base=%f)", realDamage, damageMult, damage, DK_ActualAttackBaseDamage[victim]);
		
		// subtract the actual damage
		realDamage -= damage;
		int realDamageInt = RoundFloat(realDamage);
		
		// apply it, or trigger kill for the player
		if (realDamageInt >= curHP)
		{
			SetEntProp(victim, Prop_Data, "m_iHealth", 1);
			if (TF2_IsPlayerInCondition(victim, TFCond_OnFire))
				TF2_RemoveCondition(victim, TFCond_OnFire);
			if (TF2_IsPlayerInCondition(victim, TFCond_Bleeding))
				TF2_RemoveCondition(victim, TFCond_Bleeding);
				
			DK_SuicideAt[victim] = GetEngineTime() + DK_FatalityDuration[attacker];
			TF2_StunPlayer(victim, DK_FatalityDuration[attacker] + 0.1, 0.0, TF_STUNFLAG_BONKSTUCK | TF_STUNFLAG_NOSOUNDOREFFECT, attacker);
			if (DK_ParticleEntRef[victim] == 0 && !IsEmptyString(DK_ParticleName))
			{
				int particle = AttachParticle(victim, DK_ParticleName, 70.0);
				if (IsValidEntity(particle))
					DK_ParticleEntRef[victim] = EntIndexToEntRef(particle);
			}
			DK_RemoveParticleAt[victim] = DK_SuicideAt[victim] + 0.1;
			
			// play the sound
			TFClassType playerClass = TF2_GetPlayerClass(victim);
			static char soundName[MAX_SOUND_FILE_LENGTH];
			if (playerClass == TFClass_Scout) soundName = DK_ScoutDeathSound;
			else if (playerClass == TFClass_Soldier) soundName = DK_SoldierDeathSound;
			else if (playerClass == TFClass_Pyro) soundName = DK_PyroDeathSound;
			else if (playerClass == TFClass_DemoMan) soundName = DK_DemoDeathSound;
			else if (playerClass == TFClass_Heavy) soundName = DK_HeavyDeathSound;
			else if (playerClass == TFClass_Engineer) soundName = DK_EngieDeathSound;
			else if (playerClass == TFClass_Medic) soundName = DK_MedicDeathSound;
			else if (playerClass == TFClass_Sniper) soundName = DK_SniperDeathSound;
			else if (playerClass == TFClass_Spy) soundName = DK_SpyDeathSound;
			if (strlen(soundName) > 3)
				PseudoAmbientSound(victim, soundName, 1, 500.0);
				
			// dead, jim
			stillAlive = false;
		}
		else
		{
			SetEntProp(victim, Prop_Data, "m_iHealth", curHP - realDamageInt);
		}
	}
	
	// I'm still alive...
	if (stillAlive)
	{
		// particle (optional)
		if (DK_NonFatalEffectDuration[attacker] > 0.0 && DK_ParticleEntRef[victim] == 0 && !IsEmptyString(DK_ParticleName))
		{
			int particle = AttachParticle(victim, DK_ParticleName, 70.0);
			if (IsValidEntity(particle))
				DK_ParticleEntRef[victim] = EntIndexToEntRef(particle);
		}
		
		// out here, in case we just need to extend the duration of an existing particle
		if (DK_ParticleEntRef[victim] != 0)
			DK_RemoveParticleAt[victim] = GetEngineTime() + DK_NonFatalEffectDuration[attacker];
	}
	
	// play crit sound to the victim
	if (isCritical)
	{
		EmitSoundToClient(victim, DK_CRIT_SOUND);
		EmitSoundToClient(attacker, DK_CRIT_SOUND_ATTACKER);
	}
}

public void DK_Tick(float curTime)
{
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		// is it time to remove the particle? do this even if the player is dead.
		if (DK_RemoveParticleAt[clientIdx] != FAR_FUTURE && curTime >= DK_RemoveParticleAt[clientIdx])
		{
			if (DK_ParticleEntRef[clientIdx] != 0)
			{
				RemoveEntityTele(DK_ParticleEntRef[clientIdx]);
				DK_ParticleEntRef[clientIdx] = 0;
				DK_RemoveParticleAt[clientIdx] = FAR_FUTURE;
			}
		}
		
		if (!IsLivingPlayer(clientIdx))
			continue;
			
		// manage players who are about to die
		if (DK_SuicideAt[clientIdx] != FAR_FUTURE)
		{
			// block spellcasting?
			if (DK_Flags & DK_FLAG_ANTIMAGIC)
			{
				int weapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
				if (IsValidEntity(weapon))
				{
					static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
					GetEntityClassname(weapon, classname, MAX_ENTITY_CLASSNAME_LENGTH);
					if (!strcmp(classname, "tf_weapon_spellbook"))
					{
						for (int slot = 0; slot <= 2; slot++)
						{
							int changeWeapon = GetPlayerWeaponSlot(clientIdx, slot);
							if (IsValidEntity(changeWeapon))
							{
								SetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon", changeWeapon);
								break;
							}
						}
					}
				}
			}
		
			// time to suicide?
			if (curTime >= DK_SuicideAt[clientIdx])
			{
				SetEntProp(clientIdx, Prop_Data, "m_iHealth", 1);
				
				// remove potentially interfering conditions
				if (TF2_IsPlayerInCondition(clientIdx, TFCond_Ubercharged))
					TF2_RemoveCondition(clientIdx, TFCond_Ubercharged);
				if (TF2_IsPlayerInCondition(clientIdx, TFCond_Bonked))
					TF2_RemoveCondition(clientIdx, TFCond_Bonked);
				if (TF2_IsPlayerInCondition(clientIdx, TFCond_DefenseBuffMmmph))
					TF2_RemoveCondition(clientIdx, TFCond_DefenseBuffMmmph);
				if (TF2_IsPlayerInCondition(clientIdx, TFCond_DefenseBuffed))
					TF2_RemoveCondition(clientIdx, TFCond_DefenseBuffed);
					
				// apply damage
				if (DK_Flags & DK_FLAG_EXPLODE)
					SDKHooks_TakeDamage(clientIdx, 0, 0, 4.0, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE | DMG_ALWAYSGIB, -1);
				else
					SDKHooks_TakeDamage(clientIdx, 0, 0, 4.0, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
					
				DK_SuicideAt[clientIdx] = FAR_FUTURE;
			}
		}
	}
}

public Action DK_HookPainSounds(int clients[64], int& numClients, char sample[PLATFORM_MAX_PATH], 
							int& clientIdx, int& channel, float& volume, 
							int& level, int& pitch, int& flags)
{
	if (!DK_ActiveThisRound || (DK_Flags & DK_FLAG_CANCEL_PAIN_SOUNDS) == 0)
		return Plugin_Continue;
		
	// here we give poorly considered std c methods modern names, so StrContains can actually be numeric and not boolean!
	// but it's just like learning them again, since yanno, a modern sounding StrContains would be...a boolean...but it's not...
	// yeah.
	//PrintToServer("Sound is %s. %d %d", sample, StrContains(sample, "vo/"), StrContains(sample, "_pain"));
	if (StrContains(sample, "vo/") == 0 && (StrContains(sample, "_pain") != -1 || StrContains(sample, "_Pain") != -1))
		return Plugin_Stop; // cancel the sound
	
	return Plugin_Continue;
}

/**
 * Sky Nuke
 */
public Action SN_OnDeflect(Event event, const char[] name, bool dontBroadcast)
{
	if (event.GetInt("weaponid") != 0)
		return Plugin_Continue;
	
	int airblaster = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("ownerid"));
	if (!IsLivingPlayer(victim) || !IsLivingPlayer(airblaster))
		return Plugin_Continue;
		
	if (SN_CanUse[victim] && SN_IsUsing[victim])
	{
		SN_WasDeflected[victim] = true;
		SN_Airblaster[victim] = airblaster;
	}
	
	return Plugin_Continue;
}
 
void SN_CreateExplosion(int clientIdx, int airblaster = -1)
{
	// create our rocket. no matter what, it's going to spawn, even if it ends up being out of map
	int explosion = CreateEntityByName("env_explosion");
	if (!IsValidEntity(explosion))
		return;
	char intAsString[12];
	Format(intAsString, 12, "%d", RoundFloat(SN_RocketDamage[clientIdx]));
	DispatchKeyValue(explosion, "iMagnitude", intAsString);
	DispatchKeyValueFloat(explosion, "DamageForce", 1.0);
	DispatchKeyValue(explosion, "spawnflags", "64"); // no sound
	Format(intAsString, 12, "%d", RoundFloat(SN_RocketRadius[clientIdx]));
	DispatchKeyValue(explosion, "iRadiusOverride", intAsString);

	// set data pertinent to the user
	SetEntPropEnt(explosion, Prop_Send, "m_hOwnerEntity", airblaster == -1 ? clientIdx : airblaster);

	// spawn
	float position[3];
	GetClientEyePosition(clientIdx, position);
	TeleportEntity(explosion, position, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(explosion);

	// explode!
	AcceptEntityInput(explosion, "Explode");
	AcceptEntityInput(explosion, "kill");
	if (PRINT_DEBUG_SPAM)
		PrintToServer("[sarysamods7] Explosion at %f,%f,%f", position[0], position[1], position[2]);
		
	// optional graphical effect
	if (!IsEmptyString(SNA_ExplosionEffect))
		ParticleEffectAt(position, SNA_ExplosionEffect, 1.0);
}

public void SN_UpdateHUD(int clientIdx, const char[] message, float duration, bool isRed)
{
	if (isRed)
		SetHudTextParams(-1.0, SNA_HUD_POSITION, duration + 0.05, 255, 64, 64, 192);
	else
		SetHudTextParams(-1.0, SNA_HUD_POSITION, duration + 0.05, 64, 255, 64, 192);
	ShowHudText(clientIdx, -1, message);
}

public void SN_EndRage(int clientIdx, float curTime)
{
	SN_IsUsing[clientIdx] = false;
	SN_InvincibilityEndsAt[clientIdx] = curTime + SN_ResidualInvincibilityTime[clientIdx];
	SN_WasDeflected[clientIdx] = false;
	
	//if (SN_WasDucking[clientIdx])
	{
		// credit to FF2 base for this "force ducking" code
		static float vectorsMax[3] = {24.0, 24.0, 62.0};
		SetEntPropVector(clientIdx, Prop_Send, "m_vecMaxs", vectorsMax);
		SetEntProp(clientIdx, Prop_Send, "m_bDucked", 1);
		SetEntityFlags(clientIdx, GetEntityFlags(clientIdx) | FL_DUCKING);
	}
	
	if (IsClientInGame(clientIdx))
	{
		// remove the overlay
		int flags = GetCommandFlags("r_screenoverlay");
		SetCommandFlags("r_screenoverlay", flags & ~FCVAR_CHEAT);
		ClientCommand(clientIdx, "r_screenoverlay \"\"");
		SetCommandFlags("r_screenoverlay", flags);
	}
	
	// destroy the particle trail
	if (SNA_TrailEntRef[clientIdx] != 0)
	{
		RemoveEntityTele(SNA_TrailEntRef[clientIdx]);
		SNA_TrailEntRef[clientIdx] = 0;
	}

	// destroy the doppleganger
	if (SNA_DopplegangerEntRef[clientIdx] != 0)
	{
		RemoveEntityTele(SNA_DopplegangerEntRef[clientIdx]);
		SNA_DopplegangerEntRef[clientIdx] = 0;
	}

	if (IsLivingPlayer(clientIdx))
	{
		// return to original position
		float angle[3];
		GetClientEyeAngles(clientIdx, angle);
		angle[0] = 0.0; // neutralize pitch
		SetEntityMoveType(clientIdx, MOVETYPE_WALK);
		
		// added on 2015-10-03, with a better noclip, you also need a better restore
		SetEntProp(clientIdx, Prop_Send, "m_usSolidFlags", FSOLID_NOT_STANDABLE); // default user solid flags
		SetEntProp(clientIdx, Prop_Send, "m_nSolidType", SOLID_BBOX); // default user solid type
		SetEntProp(clientIdx, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_PLAYER);
	
		TeleportEntity(clientIdx, SN_OriginalPosition[clientIdx], angle, view_as<float>( { 0.0, 0.0, 0.0 } ));
		
		// restore the original model
		if (strlen(SNA_OriginalModel) > 3)
			SN_SwapModel(clientIdx, SNA_OriginalModel);
			
		// show the player's viewmodel
		int viewModel = GetEntPropEnt(clientIdx, Prop_Send, "m_hViewModel");
		if (IsValidEntity(viewModel))
			SetEntProp(viewModel, Prop_Send, "m_fEffects", GetEntProp(viewModel, Prop_Send, "m_fEffects") & ~EF_NODRAW);
	}
	
	// remove the highlights
	int playerCount = 0;
	int loneVictim = -1;
	if (SN_Flags[clientIdx] & SN_FLAG_HIGHLIGHT_MERCS)
	{
		for (int victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (IsLivingPlayer(victim) && GetClientTeam(victim) == MercTeam)
			{
				SetEntProp(victim, Prop_Send, "m_bGlowEnabled", 0);
				playerCount++;
				loneVictim = victim;
			}
		}
	}
	
	// on second thought, FF2 wants this person to glow
	if (playerCount == 1 && IsLivingPlayer(loneVictim))
		SetEntProp(loneVictim, Prop_Send, "m_bGlowEnabled", 1);
}

void SN_EndProjectile(int clientIdx, float curTime, int airblaster = -1, bool isDud = false)
{
	// create and immediately explode a rocket where we were
	if (!isDud)
	{
		SN_CreateExplosion(clientIdx, airblaster);
		if (strlen(SNA_ExplodeSound) > 3)
			EmitSoundToAll(SNA_ExplodeSound);
	}
	
	SN_ProjectileActive[clientIdx] = false;
	if (SN_ProjectilesRemaining[clientIdx] <= 0)
		SN_EndRage(clientIdx, curTime);
}

public void SN_SwapModel(int clientIdx, const char[] model)
{
	SetVariantString(model);
	AcceptEntityInput(clientIdx, "SetCustomModel");
	SetEntProp(clientIdx, Prop_Send, "m_bUseClassAnimations", 1);
}

public void SN_Tick(int clientIdx, int buttons, float curTime)
{
	if (!IsLivingPlayer(clientIdx))
	{
		SN_IsUsing[clientIdx] = false;
		SN_CanUse[clientIdx] = false;
		SN_EndRage(clientIdx, curTime);
		return;
	}
	
	if (curTime >= SN_InvincibilityEndsAt[clientIdx])
	{
		SetEntProp(clientIdx, Prop_Data, "m_takedamage", 2);
		TF2_RemoveCondition(clientIdx, TFCond_Ubercharged);
		SN_InvincibilityEndsAt[clientIdx] = FAR_FUTURE;
	}
	
	if (SN_StartNextFrame[clientIdx])
	{
		SN_WasDucking[clientIdx] = (GetEntityFlags(clientIdx) & FL_DUCKING) != 0 || GetEntProp(clientIdx, Prop_Send, "m_bDucked");
		SN_StartNextFrame[clientIdx] = false;
		SN_StartSkyNuke(clientIdx);
	}

	if (!SN_IsUsing[clientIdx])
		return;
		
	// initialize if we have more pending projectiles
	if (!SN_ProjectileActive[clientIdx] && SN_ProjectilesRemaining[clientIdx] > 0)
	{
		SN_ProjectilesRemaining[clientIdx]--;
		SN_ProjectileActive[clientIdx] = true;
		
		// teleport (done twice intentionally so players don't see she becomes a pillow)
		SN_LastLegitPosition[clientIdx][0] = SN_OriginalPosition[clientIdx][0];
		SN_LastLegitPosition[clientIdx][1] = SN_OriginalPosition[clientIdx][1];
		SN_LastLegitPosition[clientIdx][2] = SN_OriginalPosition[clientIdx][2] + SN_StartingZOffset[clientIdx];
		TeleportEntity(clientIdx, SN_LastLegitPosition[clientIdx], view_as<float>( { 89.9, 0.0, 0.0 } ), NULL_VECTOR);
	
		// all the per-projectile inits...
		SN_StartedAt[clientIdx] = curTime;
		SN_EndsAt[clientIdx] = curTime + SN_Duration[clientIdx];
		SN_DestroyKeyDown[clientIdx] = ((SN_Flags[clientIdx] & SN_FLAG_RELOAD_ARMS) != 0 ? (buttons & IN_RELOAD) : (buttons & IN_ATTACK2)) != 0;
		SN_IsArming[clientIdx] = false;
		SN_PushAt[clientIdx] = curTime + SN_PushInterval[clientIdx];
		if ((SN_Flags[clientIdx] & SN_FLAG_LOOPING_SOUND_ONCE) == 0)
			SNA_LoopAt[clientIdx] = curTime; // trigger the sound loop
		SNA_DGLoopAt[clientIdx] = curTime;

		SNA_UpdateHUDAt[clientIdx] = curTime;
		SNA_RefreshOverlayAt[clientIdx] = curTime;
		SN_ForceAngleUntil[clientIdx] = curTime + 0.05;
		SN_WasDeflected[clientIdx] = false;
	}
		
	// ensure it wasn't airblasted
	if (SN_WasDeflected[clientIdx] && (SN_Flags[clientIdx] & SN_FLAG_KILL_ON_AIRBLAST) != 0)
	{
		SN_UpdateHUD(clientIdx, SNA_HudAirblasted, SNA_HUD_ERROR_DURATION, true);
		SN_EndProjectile(clientIdx, curTime, SN_Airblaster[clientIdx]);
		return;
	}
	
	// have we reached the time limit?
	if (curTime >= SN_EndsAt[clientIdx])
	{
		if (SN_ArmWasForced[clientIdx])
			SN_UpdateHUD(clientIdx, SNA_HudExploded, SNA_HUD_ERROR_DURATION, true);
		SN_EndProjectile(clientIdx, curTime);
		return;
	}
	
	// fix a bug with initial perspective being shit
	if (curTime < SN_ForceAngleUntil[clientIdx])
	{
		TeleportEntity(clientIdx, NULL_VECTOR, view_as<float>( { 89.9, 0.0, 0.0 } ), NULL_VECTOR);
	}
	
	// is the player holding WASD?
	bool usingWASD = (buttons & (IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT)) != 0;
	if (usingWASD)
	{
		// anti-cheating measure, don't want people holding back the nuke
		if (SN_IsArming[clientIdx])
		{
			SN_UpdateHUD(clientIdx, SNA_CheatingIsWorse, SNA_HUD_ERROR_DURATION, true);
			SN_EndProjectile(clientIdx, curTime, -1, true);
			return;
		}
		
		TeleportEntity(clientIdx, SN_LastLegitPosition[clientIdx], NULL_VECTOR, NULL_VECTOR);
	}
	
	// has the player armed it?
	bool armKeyPressed = ((SN_Flags[clientIdx] & SN_FLAG_RELOAD_ARMS) != 0 ? (buttons & IN_RELOAD) : (buttons & IN_ATTACK2)) != 0;
	if (!SN_IsArming[clientIdx] && armKeyPressed && !SN_DestroyKeyDown[clientIdx])
	{
		SN_IsArming[clientIdx] = true;
		SN_ArmWasForced[clientIdx] = false;
		if (strlen(SNA_ArmingSound) > 3)
			EmitSoundToAll(SNA_ArmingSound);
		SN_EndsAt[clientIdx] = curTime + SN_ArmTime[clientIdx];
	}
	SN_DestroyKeyDown[clientIdx] = armKeyPressed;
	
	// is it time to force arming?
	if (!SN_IsArming[clientIdx] && curTime >= SN_EndsAt[clientIdx] - SN_ArmTime[clientIdx])
	{
		SN_IsArming[clientIdx] = true;
		SN_ArmWasForced[clientIdx] = true;
		if (strlen(SNA_ArmingSound) > 3)
			EmitSoundToAll(SNA_ArmingSound);
	}
	
	// play control is NOT disabled while the nuke is arming (doesn't go well with player noclip version)
	if (curTime >= SN_PushAt[clientIdx])
	{
		float angle[3];
		GetClientEyeAngles(clientIdx, angle);
		float lowestValidPitch = 90.0 - SN_MaxPitchDeviation[clientIdx];
		bool angleWasInvalid = angle[0] < lowestValidPitch;
		if (angleWasInvalid)
			angle[0] = lowestValidPitch;

		float velocity[3];
		float naturalEndsAt = SN_StartedAt[clientIdx] + SN_Duration[clientIdx];
		float curVel = SN_StartingVelocity[clientIdx] + ((SN_EndingVelocity[clientIdx] - SN_StartingVelocity[clientIdx]) * (1.0 - ((naturalEndsAt - curTime) / SN_Duration[clientIdx])));
		GetAngleVectors(angle, velocity, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(velocity, curVel);
		if (GetEntityFlags(clientIdx) & FL_ONGROUND)
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods7] Noclip client is on ground. push through.");
			float position[3];
			GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", position);
			position[2] -= 1.0;
			TeleportEntity(clientIdx, position, angleWasInvalid ? angle : NULL_VECTOR, velocity);
		}
		else
			TeleportEntity(clientIdx, NULL_VECTOR, angleWasInvalid ? angle : NULL_VECTOR, velocity);
			
		// store their last legit position
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", SN_LastLegitPosition[clientIdx]);
		
		SN_PushAt[clientIdx] += SN_PushInterval[clientIdx];
	}
	
	// loop sound on rocket?
	if (curTime >= SNA_LoopAt[clientIdx])
	{
		if (strlen(SNA_LoopingSound) > 3)
		{
			static float position[3];
			GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", position);
			EmitAmbientSound(SNA_LoopingSound, position, clientIdx);
			EmitAmbientSound(SNA_LoopingSound, position, clientIdx);
		}
		
		if ((SN_Flags[clientIdx] & SN_FLAG_LOOPING_SOUND_ONCE) == 0)
			SNA_LoopAt[clientIdx] += SNA_LoopInterval;
		else
			SNA_LoopAt[clientIdx] = FAR_FUTURE;
	}
	
	// loop sound on doppleganger?
	if (curTime >= SNA_DGLoopAt[clientIdx])
	{
		if (strlen(SNA_DGLoopingSound) > 3 && SNA_DopplegangerEntRef[clientIdx] != 0)
		{
			int doppleganger = EntRefToEntIndex(SNA_DopplegangerEntRef[clientIdx]);
			if (IsValidEntity(doppleganger))
			{
				static float position[3];
				GetEntPropVector(doppleganger, Prop_Send, "m_vecOrigin", position);
				EmitAmbientSound(SNA_DGLoopingSound, position, doppleganger);
				EmitAmbientSound(SNA_DGLoopingSound, position, doppleganger);
				EmitAmbientSound(SNA_DGLoopingSound, position, doppleganger);
			}
		}
	
		SNA_DGLoopAt[clientIdx] += SNA_DGLoopInterval;
	}
	
	// overlay refresh?
	if (curTime >= SNA_RefreshOverlayAt[clientIdx])
	{
		if (strlen(SNA_Overlay) > 3)
		{
			int flags = GetCommandFlags("r_screenoverlay");
			SetCommandFlags("r_screenoverlay", flags & ~FCVAR_CHEAT);
			ClientCommand(clientIdx, "r_screenoverlay \"%s.vmt\"", SNA_Overlay);
			SetCommandFlags("r_screenoverlay", flags);
		}
		SNA_RefreshOverlayAt[clientIdx] += SNA_OVERLAY_REFRESH_INTERVAL;
	}
	
	// if we've gotten here, it means the HUD can still be updated normally
	if (curTime >= SNA_UpdateHUDAt[clientIdx])
	{
		SNA_UpdateHUDAt[clientIdx] = curTime + SNA_HUD_REFRESH_INTERVAL;
		if (usingWASD)
			SN_UpdateHUD(clientIdx, SNA_WASDIsBad, SNA_HUD_REFRESH_INTERVAL, true);
		else
			SN_UpdateHUD(clientIdx, SNA_HudInstructions, SNA_HUD_REFRESH_INTERVAL, false);
	}

	// doppleganger push?
	if (SN_DopplePushIntensity[clientIdx] > 0.0 && SN_DopplePushRadius[clientIdx] > 0.0 && curTime >= SN_DopplePushAt[clientIdx])
	{
		SN_DopplePushAt[clientIdx] = curTime + 0.05;
		float radiusSquared = SN_DopplePushRadius[clientIdx] * SN_DopplePushRadius[clientIdx];
		for (int victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (IsLivingPlayer(victim) && GetClientTeam(victim) == MercTeam)
			{
				static float victimPos[3];
				GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
				if (GetVectorDistance(SN_OriginalPosition[clientIdx], victimPos, true) < radiusSquared)
				{
					// since we don't want people taking advantage of this anti-trolling feature to jump off the dopple
					// we're going to throw out the Z entirely and just set it to 300.0
					static float angles[3];
					static float velocity[3];
					static float moddedDopplePos[3];
					moddedDopplePos[0] = SN_OriginalPosition[clientIdx][0];
					moddedDopplePos[1] = SN_OriginalPosition[clientIdx][1];
					moddedDopplePos[2] = 0.0;
					victimPos[2] = 0.0;
					GetVectorAnglesTwoPoints(moddedDopplePos, victimPos, angles);
					GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
					ScaleVector(velocity, SN_DopplePushIntensity[clientIdx]);
					velocity[2] = 300.0;
					TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, velocity);
				}
			}
		}
	}
	
	// add/remove highlights when appropriate
	if (SN_Flags[clientIdx] & SN_FLAG_HIGHLIGHT_MERCS)
	{
		for (int victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (IsLivingPlayer(victim) && GetClientTeam(victim) == MercTeam)
			{
				int correctState = 1;
				if (TF2_IsPlayerInCondition(victim, TFCond_Stealthed)) // magic!
					correctState = 0;
				else if (TF2_GetPlayerClass(victim) == TFClass_Spy && TF2_IsPlayerInCondition(victim, TFCond_Cloaked))
					correctState = 0;
					
				if (GetEntProp(victim, Prop_Send, "m_bGlowEnabled") != correctState)
					SetEntProp(victim, Prop_Send, "m_bGlowEnabled", correctState);
			}
		}
	}
}

public void Rage_SkyNuke(const char[] ability_name, int bossIdx)
{
	int clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	// freak circumstance, but very very possible...and problematic.
	// if I don't do this then players will be spit out way above the skybox.
	if (SAC_ActiveThisRound && SAC_CanUse[clientIdx] && SAC_IsActive[clientIdx])
		SAC_OnDeactivated(clientIdx);
	
	// remove stuns from player
	if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed))
		TF2_RemoveCondition(clientIdx, TFCond_Dazed);
	
	// player needs to be invincible
	SetEntProp(clientIdx, Prop_Data, "m_takedamage", 0);
	TF2_AddCondition(clientIdx, TFCond_Ubercharged, -1.0);
	
	SN_StartNextFrame[clientIdx] = true;
}

public void SN_StartSkyNuke(int clientIdx)
{
	SN_ProjectileActive[clientIdx] = false;
	SN_ProjectilesRemaining[clientIdx] = SN_ProjectilesPerRage[clientIdx];
	
	// get the player's original model
	GetEntPropString(clientIdx, Prop_Data, "m_ModelName", SNA_OriginalModel, MAX_MODEL_FILE_LENGTH);
	
	// move the player up and give them noclip
	SetEntityMoveType(clientIdx, MOVETYPE_NOCLIP);
	// added these three on 2015-10-03 for a better noclip
	SetEntProp(clientIdx, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID); // not solid
	SetEntProp(clientIdx, Prop_Send, "m_nSolidType", SOLID_NONE); // not solid
	SetEntProp(clientIdx, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS);
	
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", SN_OriginalPosition[clientIdx]);
	float originalAngle[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_angRotation", originalAngle);
	SN_LastLegitPosition[clientIdx][0] = SN_OriginalPosition[clientIdx][0];
	SN_LastLegitPosition[clientIdx][1] = SN_OriginalPosition[clientIdx][1];
	SN_LastLegitPosition[clientIdx][2] = SN_OriginalPosition[clientIdx][2] + SN_StartingZOffset[clientIdx];
	TeleportEntity(clientIdx, SN_LastLegitPosition[clientIdx], view_as<float>( { 89.9, 0.0, 0.0 } ), NULL_VECTOR);
	
	// once per rage settings
	SN_IsUsing[clientIdx] = true;
	SN_DopplePushAt[clientIdx] = GetEngineTime();
			
	SN_InvincibilityEndsAt[clientIdx] = FAR_FUTURE;
	if (SN_Flags[clientIdx] & SN_FLAG_LOOPING_SOUND_ONCE)
		SNA_LoopAt[clientIdx] = GetEngineTime(); // trigger the sound loop now, since it can't be done in tick with this flag
	
	// set their model
	if (strlen(SNA_ModelOverride) > 3)
		SN_SwapModel(clientIdx, SNA_ModelOverride);
		
	// create the trail
	SNA_TrailEntRef[clientIdx] = 0;
	if (!IsEmptyString(SNA_TrailName))
	{
		int particle = AttachParticle(clientIdx, SNA_TrailName, 0.0);
		if (IsValidEntity(particle))
			SNA_TrailEntRef[clientIdx] = EntIndexToEntRef(particle);
	}
	
	// create the doppleganger
	SNA_DopplegangerEntRef[clientIdx] = 0;
	if (strlen(SNA_DopplegangerModel) > 3)
	{
		int doppleganger = CreateEntityByName("prop_physics_override");
		if (IsValidEntity(doppleganger))
		{
			SetEntProp(doppleganger, Prop_Data, "m_takedamage", 0);
	
			// tweak the model
			SetEntityModel(doppleganger, SNA_DopplegangerModel);
	
			// spawn and move it
			DispatchSpawn(doppleganger);
			TeleportEntity(doppleganger, SN_OriginalPosition[clientIdx], originalAngle, NULL_VECTOR);
			SetEntProp(doppleganger, Prop_Send, "m_nSolidType", 0); // not solid
			SetEntProp(doppleganger, Prop_Send, "m_usSolidFlags", 0); // not solid
			SetEntProp(doppleganger, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_NONE);
			SetEntityMoveType(doppleganger, MOVETYPE_NONE);
			SetEntProp(doppleganger, Prop_Data, "m_takedamage", 0);
			
			SNA_DopplegangerEntRef[clientIdx] = EntIndexToEntRef(doppleganger);
			
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods7] Created a doppleganger %s", SNA_DopplegangerModel);
		}
	}
	
	// hide the player's viewmodel
	int viewModel = GetEntPropEnt(clientIdx, Prop_Send, "m_hViewModel");
	if (IsValidEntity(viewModel))
		SetEntProp(viewModel, Prop_Send, "m_fEffects", GetEntProp(viewModel, Prop_Send, "m_fEffects") | EF_NODRAW);
}

/**
 * DOT Suck and Chuck
 */
public void SAC_DisplayOverlay(int victim, const char[] overlay, bool isFramed)
{
	int flags = GetCommandFlags("r_screenoverlay");
	SetCommandFlags("r_screenoverlay", flags & ~FCVAR_CHEAT);
	if (IsEmptyString(overlay))
		ClientCommand(victim, "r_screenoverlay \"\"");
	else if (isFramed)
		ClientCommand(victim, "r_screenoverlay \"%s%d.vmt\"", overlay, SAC_CurrentOverlayFrame);
	else
		ClientCommand(victim, "r_screenoverlay \"%s.vmt\"", overlay);
	SetCommandFlags("r_screenoverlay", flags);
}
 
public void SAC_DOTTick(int clientIdx)
{
	// apply suction to all players not yet stuck
	static float bossPos[3];
	static float bossSuckToPos[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossPos);
	bossSuckToPos[0] = bossPos[0];
	bossSuckToPos[1] = bossPos[1];
	bossSuckToPos[2] = bossPos[2] + 20.0;
	for (int victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
			continue;
		else if (SACV_IsTrapped[victim])
			continue;
			
		// are they in a valid range for suction?
		static float victimPos[3];
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
		float distance = GetVectorDistance(bossSuckToPos, victimPos);
		if (distance >= SAC_MaxSuctionRadius[clientIdx])
			continue;
			
		// get angle, but since it's suction we get victim --> boss for once, instead of typical knockback
		static float angles[3];
		GetVectorAnglesTwoPoints(victimPos, bossSuckToPos, angles);
		
		// get velocity adjustment
		float velMult = (1.0 - (distance / SAC_MaxSuctionRadius[clientIdx])) * SAC_MaxVelocityShiftPerTick[clientIdx];
		static float velocityAdjust[3];
		GetAngleVectors(angles, velocityAdjust, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(velocityAdjust, velMult);
		
		// adjust velocity, cap it if's above the maximum
		static float velocity[3];
		GetEntPropVector(victim, Prop_Data, "m_vecVelocity", velocity);
		float oldVelocity = getLinearVelocity(velocity);
		velocity[0] += velocityAdjust[0];
		velocity[1] += velocityAdjust[1];
		velocity[2] += velocityAdjust[2];
		float newVelocity = getLinearVelocity(velocity);
		if (newVelocity > oldVelocity && newVelocity > SAC_MaxVelocity[clientIdx])
			ScaleVector(velocity, SAC_MaxVelocity[clientIdx] / newVelocity);
			
		// push!
		TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, velocity);
	}

	// display overlay to trapped players and add to their damage total
	SAC_CurrentOverlayFrame++;
	SAC_CurrentOverlayFrame %= SAC_OverlayFrames;
	for (int victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (SACV_IsTrapped[victim] && SACV_Trapper[victim] == clientIdx)
		{
			// check for suicide, remove overlay if so
			if (!IsLivingPlayer(victim))
			{
				SACV_IsTrapped[victim] = false;
				if (IsClientInGame(victim))
					SAC_DisplayOverlay(victim, "", false);
				continue;
			}

			// otherwise, just display it normally
			if (strlen(SAC_Overlay) > 3)
				SAC_DisplayOverlay(victim, SAC_Overlay, SAC_OverlayFrames > 1);

			// also, add to damage total
			SACV_AccumulatedDamage[victim] += SAC_DamagePerTick[clientIdx];
		}
	}
}

public void SAC_OnActivated(int clientIdx)
{
	SAC_IsActive[clientIdx] = true;
	SAC_NextLoopAt[clientIdx] = GetEngineTime();
	
	// set everyone alive to a neutral collision group, including the hale
	SAC_RestoreCollisionGroupAt = FAR_FUTURE;
	for (int playerIdx = 1; playerIdx < MAX_PLAYERS; playerIdx++)
	{
		if (IsLivingPlayer(playerIdx))
		{
			//PrintToServer("Collision group was %d (setting to debris)", GetEntProp(playerIdx, Prop_Send, "m_CollisionGroup"));
			SetEntProp(playerIdx, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
		}
	}
}

public void SAC_OnDeactivated(int clientIdx)
{
	if (!SAC_IsActive[clientIdx])
		return; // happens if the sky nuke rage deactivates it before the DOT can deactivate normally.

	SAC_IsActive[clientIdx] = false;

	// schedule fixing of collision group
	SAC_RestoreCollisionGroupAt = GetEngineTime() + 1.0;
	
	// spit anyone who is trapped back out
	for (int victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (!IsLivingPlayer(victim) || !SACV_IsTrapped[victim])
		{
			SACV_IsTrapped[victim] = false; // in case of suicide
			if (IsClientInGame(victim))
				SAC_DisplayOverlay(victim, "", false);
			continue;
		}
		else if (SACV_Trapper[victim] != clientIdx)
			continue;
			
		// remove overlay
		SAC_DisplayOverlay(victim, "", false);
		
		// pit workaround
		if (SAC_Flags & SAC_FLAG_PIT_WORKAROUND)
			SACV_ImmuneToEnvironmentUntil[victim] = GetEngineTime() + SAC_PitImmunityDuration;
			
		// not trapped anymore
		SACV_IsTrapped[victim] = false;
			
		// send them flying out first
		static float playerAngle[3];
		GetClientEyeAngles(victim, playerAngle);
		playerAngle[0] = 0.0; // toss out pitch
		static float velocity[3];
		GetAngleVectors(playerAngle, velocity, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(velocity, SAC_EscapeVelocity[clientIdx]);
		velocity[2] = 450.0;
		TeleportEntity(victim, SAC_LastValidBossPos[clientIdx], NULL_VECTOR, velocity);
		
		// apply damage
		if (SACV_AccumulatedDamage[victim] > 0.0)
		{
			float actualDamage = fmin(SACV_AccumulatedDamage[victim], SAC_DamageCap[clientIdx]);
		
			if (SAC_Flags & SAC_FLAG_USE_POINT_HURT)
			{
				// took this from war3...I hope it doesn't double damage like I've heard old versions do
				int pointHurt = CreateEntityByName("point_hurt");
				if (IsValidEntity(pointHurt))
				{
					DispatchKeyValueFormat(victim, "targetname", "halevictim%d", victim);
					DispatchKeyValueFormat(pointHurt, "DamageTarget", "halevictim%d", victim);
					DispatchKeyValueFormat(pointHurt, "Damage", "%d", RoundFloat(fixDamageForFF2(actualDamage)));
					DispatchKeyValueFormat(pointHurt, "DamageType", "%d", (DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE));

					DispatchSpawn(pointHurt);
					AcceptEntityInput(pointHurt, "Hurt", clientIdx);
					DispatchKeyValue(pointHurt, "classname", "point_hurt");
					DispatchKeyValueFormat(victim, "targetname", "whatisthis%d", victim);
					RemoveEntityTele(EntIndexToEntRef(pointHurt));
					
					if (PRINT_DEBUG_SPAM)
						PrintToServer("Point hurt applied to %d with damage %f", victim, actualDamage);
				}
			}
			else
				SDKHooks_TakeDamage(victim, clientIdx, clientIdx, actualDamage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
		}
	}
}

public void SAC_HighResTick(float curTime)
{
	// need high resolution frames to do a decent collision test
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!SAC_IsActive[clientIdx] || !IsLivingPlayer(clientIdx))
			continue;
		
		static float bossPos[3];
		GetEntPropVector(clientIdx, Prop_Data, "m_vecOrigin", bossPos);
		for (int victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (victim == clientIdx || !IsLivingPlayer(victim))
				continue;
				
			static float victimPos[3];
			GetEntPropVector(victim, Prop_Data, "m_vecOrigin", victimPos);
			
			if (CylinderCollision(bossPos, victimPos, SAC_CollisionRadius[clientIdx], bossPos[2] - 83.0, bossPos[2] + 83.0))
			{
				SACV_IsTrapped[victim] = true;
				SACV_Trapper[victim] = clientIdx;
				SACV_AccumulatedDamage[victim] = 0.0;
				TeleportEntity(victim, OFF_THE_MAP, NULL_VECTOR, view_as<float>( { 0.0, 0.0, 0.0 } ));
			}
		}
		
		// looping sound (this must be last, as it corrupts bossPos)
		bossPos[2] += 41.5; // emit sound from center of boss
		if (curTime >= SAC_NextLoopAt[clientIdx])
		{
			if (strlen(SAC_LoopingSound) > 3)
				EmitAmbientSound(SAC_LoopingSound, bossPos, clientIdx);
			SAC_NextLoopAt[clientIdx] = GetEngineTime() + SAC_LoopInterval;
		}
	}
			
	if (curTime >= SAC_RestoreCollisionGroupAt)
	{
		if (SAC_Flags & SAC_FLAG_PREVENT_TRAPPING)
			SAC_StopBlockingTouchesAt = curTime + 0.05;
			
		for (int playerIdx = 1; playerIdx < MAX_PLAYERS; playerIdx++)
		{
			if (IsLivingPlayer(playerIdx))
			{
				//PrintToServer("Collision group was %d (setting to player)", GetEntProp(playerIdx, Prop_Send, "m_CollisionGroup"));
				SetEntProp(playerIdx, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_PLAYER);
			}
		}
		SAC_RestoreCollisionGroupAt = FAR_FUTURE;
	}
	
	if (curTime >= SAC_StopBlockingTouchesAt)
		SAC_StopBlockingTouchesAt = 0.0;
	
	// get last valid position, can't have players be tossed out where the hale was ducking
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (IsLivingPlayer(clientIdx) && SAC_CanUse[clientIdx])
			if ((GetEntityFlags(clientIdx) & FL_DUCKING) == 0)
				GetEntPropVector(clientIdx, Prop_Data, "m_vecOrigin", SAC_LastValidBossPos[clientIdx]);
				
		// also check this
		if (curTime >= SACV_ImmuneToEnvironmentUntil[clientIdx])
			SACV_ImmuneToEnvironmentUntil[clientIdx] = 0.0;
	}
}

public bool SAC_OnCollide(int clientIdx, int collisionGroup, int contentsMask, bool result)
{
	if (!IsLivingPlayer(clientIdx))
		return result;
		
	// prevent same team trapping, which this whole rage seems to be reeking of...
	if (GetClientTeam(clientIdx) == MercTeam && (contentsMask & CONTENTS_TEAM1) != 0)
	{
		result = false;
		return result;
	}
		
	if (SAC_StopBlockingTouchesAt == 0.0)
		return result;
		
	if (GetClientTeam(clientIdx) == MercTeam && (contentsMask & CONTENTS_TEAM2) != 0)
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("Player %d is probably stuck in a BLU. Teleporting them to spawn.", clientIdx);
			
		result = false;
		TeleportEntity(clientIdx, SAC_UnstuckCoords, NULL_VECTOR, view_as<float>( { 0.0, 0.0, 0.0 } ));
	}
		
	//PrintToServer("player=%d collisionGroup=%d contentsMask=0x%x result=%d", player, collisionGroup, contentsMask, result);
	return result;
}

//public Action SAC_OnStartTouch(toucher, touchee)
//{
//	if (SAC_StopBlockingTouchesAt == 0.0)
//		return Plugin_Handled;
//	else if (!IsLivingPlayer(toucher) || !IsLivingPlayer(touchee))
//		return Plugin_Handled;
//		
//	if ((GetClientTeam(toucher) == BossTeam && GetClientTeam(touchee) == MercTeam) ||
//		(GetClientTeam(toucher) == MercTeam && GetClientTeam(touchee) == BossTeam))
//	{
//		int teleportMe = GetClientTeam(toucher) == MercTeam ? toucher : touchee;
//		TeleportEntity(teleportMe, SAC_UnstuckCoords, NULL_VECTOR, float {0.0,0.0,0.0});
//		return Plugin_Handled;
//	}
//	
//	return Plugin_Continue;
//}

public Action SAC_OnTakeDamage(int victim, int& attacker, int& inflictor, 
							float& damage, int& damagetype, int& weapon, 
							float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (IsLivingPlayer(attacker) || !IsLivingPlayer(victim))
		return Plugin_Continue;
	else if (SACV_ImmuneToEnvironmentUntil[victim] == 0.0)
		return Plugin_Continue;
		
	if (damage > SACV_MAX_ENVIRONMENTAL_DAMAGE)
	{
		damage = 0.0;
		TeleportEntity(victim, SAC_UnstuckCoords, NULL_VECTOR, view_as<float>( { 0.0, 0.0, 0.0 } ));
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

/**
 * Class Nerfs
 */
public Action CN_OnTakeDamage(int victim, int& attacker, int& inflictor, 
							float& damage, int& damagetype, int& weapon, 
							float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsLivingPlayer(victim) || !CN_CanUse[victim])
		return Plugin_Continue;
	else if (!IsLivingPlayer(attacker))
		return Plugin_Continue;
		
	TFClassType playerClass = TF2_GetPlayerClass(attacker);
	int playerClassInt = view_as<int>(playerClass);
	
	float damageMult = 1.0;
	if (weapon == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Primary))
		damageMult = CN_DamageMultipliers[victim][playerClassInt][0];
	else if (weapon == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Secondary))
		damageMult = CN_DamageMultipliers[victim][playerClassInt][1];
	else if (weapon == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee))
	{
		if (playerClass != TFClass_Spy) // don't mess with spy backstab damage. won't work anyway.
			damageMult = CN_DamageMultipliers[victim][playerClassInt][2];
	}
	else if (playerClass == TFClass_Engineer) // must be their sentry
		damageMult = CN_DamageMultipliers[victim][playerClassInt][3];
	
	if (damageMult == 1.0)
		return Plugin_Continue;

	damage *= damageMult;	
	return Plugin_Changed;
}

/**
 * Mega Buster
 */
public Action MB_OnTakeDamage(int victim, int& attacker, int& inflictor, 
							float& damage, int& damagetype, int& weapon, 
							float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsLivingPlayer(victim) || !IsLivingPlayer(attacker))
		return Plugin_Continue;
	else if (!MB_CanUse[attacker])
		return Plugin_Continue;
		
	// do not allow projectiles to directly damage people
	// this is a fallback in case other means to prevent this fail
	for (int i = 0; i < MB_MaxProjectiles[attacker]; i++)
	{
		if (MB_ProjectileEntRefs[attacker][i] == 0)
			continue;
			
		if (EntRefToEntIndex(MB_ProjectileEntRefs[attacker][i]) == inflictor)
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods7] WARNING: Direct projectile damage against %d had to be nullified.", victim);
		
			damage = 0.0;
			damagetype |= DMG_PREVENT_PHYSICS_FORCE;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

public void MB_QueueDiscreteDestruction(int clientIdx, int index)
{
	MB_ProjectileMarkedForDeath[clientIdx][index] = true;
}

public void MB_FindProjectileData(const int projectile, int& owner, int& index)
{
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (MB_CanUse[clientIdx])
		{
			for (int i = 0; i < MB_MaxProjectiles[clientIdx]; i++)
			{
				if (MB_ProjectileEntRefs[clientIdx][i] != 0 && EntRefToEntIndex(MB_ProjectileEntRefs[clientIdx][i]) == projectile)
				{
					owner = clientIdx;
					index = i;
					return;
				}
			}
		}
	}
	
	owner = -1;
}

float MB_CalculateDamageFalloff(int projectile, float damage, int clientIdx, int index, bool isPlayer = false)
{
	// need the projectile distance to get the falloff factor. also need it for the little bonus which isn't traditional falloff.
	static float projectilePos[3];
	GetEntPropVector(projectile, Prop_Send, "m_vecOrigin", projectilePos);
	float distance = GetVectorDistance(projectilePos, MB_ProjectileSpawnPos[clientIdx][index]);
	
	// must calculate the bonus here
	if (isPlayer)
	{
		if (MB_BonusDamagePercent[clientIdx] > 0.0)
		{
			float bonusMax = MB_BonusDamagePercent[clientIdx] * MB_ProjectilePlayerDamage[clientIdx][index];
			damage += bonusMax - (bonusMax * (Pow(Pow(MB_MaxDistance[clientIdx], MB_BonusDamageExp[clientIdx]) - Pow(MB_MaxDistance[clientIdx] - distance, MB_BonusDamageExp[clientIdx]), 1 / MB_BonusDamageExp[clientIdx]) / MB_MaxDistance[clientIdx]));
		}
	}
	
	if (MB_DamageFalloffType[clientIdx] == MB_FALLOFF_NONE)
		return damage;
		
	float halfMax = MB_MaxDistance[clientIdx] * 0.5;
	float factor = 1.0;
	if (MB_DamageFalloffType[clientIdx] == MB_FALLOFF_DECREASE)
	{
		if (distance < halfMax)
			factor = 1.0 + (0.5 - (0.5 * (distance / halfMax)));
		else
			factor = 1.0 - (0.33 * ((distance - halfMax) / halfMax));
	}
	else if (MB_DamageFalloffType[clientIdx] == MB_FALLOFF_INCREASE)
	{
		if (distance > halfMax)
			factor = 1.0 + (0.5 * ((distance - halfMax) / halfMax));
		else
			factor = 1.0 - (0.33 - (0.33 * (distance / halfMax)));
	}
	
	return damage * factor;
}

public Action MB_OnStartTouch(int projectile, int victim)
{
	// look up the projectile so we can get its data
	int clientIdx = -1;
	int index = 0;
	MB_FindProjectileData(projectile, clientIdx, index);
			
	if (clientIdx == -1)
	{
		// something went wrong
		PrintToServer("[sarysamods7] WARNING: Destroying obsolete managed projectile. Not sure why this happened.");
		RemoveEntity(projectile);
		return Plugin_Handled;
	}
	
	if (MB_ProjectileMarkedForDeath[clientIdx][index])
		return Plugin_Handled; // do nothing

	if (IsLivingPlayer(victim))
	{
		if (GetClientTeam(victim) == BossTeam)
			return Plugin_Handled; // prevent explosion
		else
		{
			// we can continue if owner is dead, but not if they rage quit
			if (!IsClientInGame(clientIdx))
			{
				MB_QueueDiscreteDestruction(clientIdx, index);
				return Plugin_Handled;
			}
			
			// valid hit. hit the victim, but it needs to be a point hurt, lest we have invis watch spies be almost impossible to kill
			FullyHookedDamage(victim, clientIdx, clientIdx, fixDamageForFF2(MB_CalculateDamageFalloff(projectile, MB_ProjectilePlayerDamage[clientIdx][index], clientIdx, index, true)), MB_ProjectileHasCrits[clientIdx][index] ? DMG_CRIT : DMG_GENERIC);
			
			// destroy the projectile if the victim didn't die, or the projectile has no penetration
			bool playerKilled = !IsLivingPlayer(victim);
			bool shouldDestroyProjectile = !MB_ProjectileHasPenetration[clientIdx][index] || !playerKilled;
				
			// play sound first
			if (playerKilled && strlen(MBA_DestroySound[clientIdx]) > 3)
				PseudoAmbientSound(projectile, MBA_DestroySound[clientIdx], 2, 800.0);
			else if (!playerKilled)
			{
				if (PlayerIsInvincible(victim))
				{
					if (strlen(MBA_BounceSound[clientIdx]) > 3)
						PseudoAmbientSound(projectile, MBA_BounceSound[clientIdx], 1, 800.0);
				}
				else if (strlen(MBA_HitSound[clientIdx]) > 3)
					PseudoAmbientSound(projectile, MBA_HitSound[clientIdx], 1, 800.0);
			}
				
			if (shouldDestroyProjectile)
			{
				MB_QueueDiscreteDestruction(clientIdx, index);

				if (PRINT_DEBUG_SPAM)
					PrintToServer("[sarysamods7] Projectile %d hit player %d. Destroying projectile.", projectile, victim);
			}
			else if (PRINT_DEBUG_SPAM)
			{
				PrintToServer("[sarysamods7] Projectile %d hit player %d, killing them. Projectile lives on.", projectile, victim);
			}

			return Plugin_Handled;
		}
	}
	else if (IsValidEntity(victim))
	{
		// did we hit a building?
		char classname[MAX_ENTITY_CLASSNAME_LENGTH];
		GetEntityClassname(victim, classname, MAX_ENTITY_CLASSNAME_LENGTH);
		bool isFuncBreakable = strcmp(classname, "func_breakable") == 0;
		bool buildingHit = (strcmp(classname, "obj_sentrygun") == 0) || (strcmp(classname, "obj_dispenser") == 0) || (strcmp(classname, "obj_teleporter") == 0);
		
		if (isFuncBreakable)
		{
			SDKHooks_TakeDamage(victim, clientIdx, clientIdx, MB_ProjectilePlayerDamage[clientIdx][index] * 2, DMG_GENERIC, -1);
			PseudoAmbientSound(projectile, MBA_HitSound[clientIdx], 1, 800.0);
			MB_QueueDiscreteDestruction(clientIdx, index);
		}
		else if (buildingHit)
		{
			SDKHooks_TakeDamage(victim, clientIdx, clientIdx, MB_CalculateDamageFalloff(projectile, MB_ProjectileBuildingDamage[clientIdx][index], clientIdx, index), DMG_GENERIC, -1);
			
			// destroy the projectile if the building didn't die, or the projectile has no penetration
			bool buildingDestroyed = GetEntProp(victim, Prop_Send, "m_iHealth") <= 0;
			bool shouldDestroyProjectile = !buildingDestroyed || !MB_ProjectileHasPenetration[clientIdx][index];
			
			// play sound first
			if (buildingDestroyed && strlen(MBA_DestroySound[clientIdx]) > 3)
				PseudoAmbientSound(projectile, MBA_DestroySound[clientIdx], 2, 800.0);
			else if (!buildingDestroyed && strlen(MBA_HitSound[clientIdx]) > 3)
				PseudoAmbientSound(projectile, MBA_HitSound[clientIdx], 1, 800.0);
				
			// destroy projectile?
			if (shouldDestroyProjectile)
			{
				if (PRINT_DEBUG_SPAM)
					PrintToServer("[sarysamods7] Projectile %d hit an building of type %s, which now has %d HP. Destroying projectile.", projectile, classname, GetEntProp(victim, Prop_Send, "m_iHealth"));
		
				MB_QueueDiscreteDestruction(clientIdx, index);
			}
			else if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods7] Projectile %d hit a building of type %s, destroying it.", projectile, classname);
		}
		else
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods7] Projectile %d hit an object (%s) that may as well be a wall. Destroying.", projectile, classname);
		
			// hit the equivalent of a wall. destroy the projectile.
			MB_QueueDiscreteDestruction(clientIdx, index);
		}
		
		return Plugin_Handled;
	}
	
	// if we're here, it hit a wall. destroy it
	if (PRINT_DEBUG_SPAM)
		PrintToServer("[sarysamods7] Projectile %d hit a wall. Destroying.", projectile);
		
	MB_QueueDiscreteDestruction(clientIdx, index);
	return Plugin_Handled;
}

public Action MB_OtherTouches(int projectile, int victim)
{
	return Plugin_Handled; // prevent explosion
}
 
#define MB_CHARGE_NORMAL 0
#define MB_CHARGE_HALF 1
#define MB_CHARGE_FULL 2
public void MB_GetIdealProjectileSpawnPos(int clientIdx, float spawnPos[3])
{
	int effect = -1;
	if (MBA_ParticleEntRef[clientIdx] != 0)
		effect = EntRefToEntIndex(MBA_ParticleEntRef[clientIdx]);

	if (IsValidEntity(effect))
	{
		GetEntPropVector(effect, Prop_Data, "m_vecAbsOrigin", spawnPos);
	}
	else
	{
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", spawnPos);
		spawnPos[2] += 61.5; // rough offset for spawning projectiles
	}
}
 
// based on asherkin and voogru's code, though this is almost exactly like the code used for Snowdrop's rockets
public int MB_CreateRocket(int clientIdx, int chargeLevel)
{
	// create our rocket. no matter what, it's going to spawn, even if it ends up being out of map
	float damage = 50.0; // damage isn't applied directly, except on airblast back to the hale
	
	int rocket = CreateEntityByName("tf_projectile_rocket");
	if (!IsValidEntity(rocket))
	{
		PrintToServer("[sarysamods7] Error: Invalid entity \"tf_projectile_rocket\". Won't spawn rocket. This is sarysa's fault.");
		return -1;
	}
	
	// need boss origin
	static float spawnPos[3];
	MB_GetIdealProjectileSpawnPos(clientIdx, spawnPos);
	
	// need eye angles for shooting, and derive velocity from that
	static float eyeAngles[3];
	GetClientEyeAngles(clientIdx, eyeAngles);
	static float velocity[3];
	GetAngleVectors(eyeAngles, velocity, NULL_VECTOR, NULL_VECTOR);
	if (chargeLevel == MB_CHARGE_NORMAL)
		ScaleVector(velocity, MB_BaseSpeed[clientIdx]);
	else if (chargeLevel == MB_CHARGE_HALF)
		ScaleVector(velocity, MB_HalfChargeSpeed[clientIdx]);
	else if (chargeLevel == MB_CHARGE_FULL)
		ScaleVector(velocity, MB_FullChargeSpeed[clientIdx]);
	
	// deploy!
	TeleportEntity(rocket, spawnPos, eyeAngles, velocity);
	SetEntProp(rocket, Prop_Send, "m_bCritical", false); // no random crits
	SetEntDataFloat(rocket, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, damage, true); // credit to voogru
	SetEntProp(rocket, Prop_Send, "m_nSkin", 1); // set skin to blu team's
	SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", clientIdx);
	SetVariantInt(BossTeam);
	AcceptEntityInput(rocket, "TeamNum", -1, -1, 0);
	SetVariantInt(BossTeam);
	AcceptEntityInput(rocket, "SetTeam", -1, -1, 0); 
	DispatchSpawn(rocket);
	
	// to get stats from the sentry
	SetEntPropEnt(rocket, Prop_Send, "m_hOriginalLauncher", GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon"));
	SetEntPropEnt(rocket, Prop_Send, "m_hLauncher", GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon"));
	
	// reskin after spawn
	if (chargeLevel == MB_CHARGE_NORMAL && MBA_NormalReskin[clientIdx] != -1)
		SetEntProp(rocket, Prop_Send, "m_nModelIndex", MBA_NormalReskin[clientIdx]);
	else if (chargeLevel == MB_CHARGE_HALF && MBA_HalfReskin[clientIdx] != -1)
		SetEntProp(rocket, Prop_Send, "m_nModelIndex", MBA_HalfReskin[clientIdx]);
	else if (chargeLevel == MB_CHARGE_FULL && MBA_FullReskin[clientIdx] != -1)
		SetEntProp(rocket, Prop_Send, "m_nModelIndex", MBA_FullReskin[clientIdx]);
		
	// hook touches
	SDKHook(rocket, SDKHook_StartTouch, MB_OnStartTouch);
	SDKHook(rocket, SDKHook_StartTouchPost, MB_OtherTouches);
	SDKHook(rocket, SDKHook_Touch, MB_OtherTouches);
	SDKHook(rocket, SDKHook_TouchPost, MB_OtherTouches);
	SDKHook(rocket, SDKHook_EndTouch, MB_OtherTouches);
	SDKHook(rocket, SDKHook_EndTouchPost, MB_OtherTouches);
	
	return rocket;
}

#define RAINBOW_LOOP_MS 800
#define RAINBOW_LOOP_SEGMENT ((RAINBOW_LOOP_MS / 6) + 1)
public void MB_Tick(int clientIdx, int buttons, float curTime)
{
	if (!IsLivingPlayer(clientIdx))
		return;
		
	// boss position is used multiple times
	static float bossPos[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossPos);
		
	// ensure the player's shotgun has been stripped of ammo and clip
	int dummyWeapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
	if (dummyWeapon != GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Melee)) // in the unlikely event the player has melee, don't do this
	{
		// if the weapon has changed, need to strip all ammo from the int one
		if (EntRefToEntIndex(MB_InertShotgunEntRef[clientIdx]) != dummyWeapon)
		{
			MB_InertShotgunEntRef[clientIdx] = EntIndexToEntRef(dummyWeapon);
			int offset = GetEntProp(dummyWeapon, Prop_Send, "m_iPrimaryAmmoType", 1);
			SetEntProp(clientIdx, Prop_Send, "m_iAmmo", 0, 4, offset);
			SetEntProp(dummyWeapon, Prop_Send, "m_iClip1", 0);
			SetEntProp(dummyWeapon, Prop_Send, "m_iClip2", 0);
		}
	}
	
	// attach the particle effect for the firing attachment now
	if (curTime >= MBA_AttachParticleAt[clientIdx])
	{
		MBA_AttachParticleAt[clientIdx] = FAR_FUTURE;
		
		if (!IsEmptyString(MBA_AttachmentName[clientIdx]))
		{
			int effect = AttachParticleToAttachment(clientIdx, MBA_AttachmentParticle, MBA_AttachmentName[clientIdx]);
			if (IsValidEntity(effect))
				MBA_ParticleEntRef[clientIdx] = EntIndexToEntRef(effect);
		}
	}

	// get an accurate count of currently existing projectiles, but also free up any invalid projectiles
	int projectileCount = 0;
	for (int i = 0; i < MB_MaxProjectiles[clientIdx]; i++)
	{
		if (MB_ProjectileEntRefs[clientIdx][i] != 0)
		{
			int rocket = EntRefToEntIndex(MB_ProjectileEntRefs[clientIdx][i]);
			// destroyed naturally
			if (!IsValidEntity(rocket))
			{
				MB_ProjectileEntRefs[clientIdx][i] = 0;
				continue;
			}
			
			// marked for death
			if (MB_ProjectileMarkedForDeath[clientIdx][i])
			{
				RemoveEntity(rocket);
				MB_ProjectileEntRefs[clientIdx][i] = 0;
				continue;
			}
			
			// airblasted. it now belongs to a pyro.
			if ((GetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity") & 0xff) != clientIdx)
			{
				MB_ProjectileEntRefs[clientIdx][i] = 0;
				continue;
			}
			
			// reached distance limit
			static float rocketPos[3];
			GetEntPropVector(rocket, Prop_Send, "m_vecOrigin", rocketPos);
			if (GetVectorDistance(MB_ProjectileSpawnPos[clientIdx][i], rocketPos, true) >= MB_MaxDistance[clientIdx] * MB_MaxDistance[clientIdx])
			{
				RemoveEntity(rocket);
				MB_ProjectileEntRefs[clientIdx][i] = 0;
				continue;
			}
			
			// while we're here, lets fix an irritating glitch that causes projectiles to stop dead sometimes after killing a player
			static float rocketVel[3];
			GetEntPropVector(rocket, Prop_Data, "m_vecVelocity", rocketVel);
			if (rocketVel[0] == 0.0 && rocketVel[1] == 0.0 && rocketVel[2] == 0.0)
			{
				if (PRINT_DEBUG_INFO)
					PrintToServer("[sarysamods7] Restarting stopped mega buster projectile. This is rare, but 'normal'...");
				
				static float rocketAngles[3];
				GetEntPropVector(rocket, Prop_Data, "m_angRotation", rocketAngles);
				GetAngleVectors(rocketAngles, rocketVel, NULL_VECTOR, NULL_VECTOR);
				ScaleVector(rocketVel, MB_ProjectileSpeed[clientIdx][i]);
				TeleportEntity(rocket, NULL_VECTOR, rocketAngles, rocketVel);
			}
		
			projectileCount++;
		}
	}
	
	// key states and charge states are ignored if this isn't the active weapon
	if (MB_IsDisabled[clientIdx])
		return;
	
	// regardless of the above, keep track of key states
	bool fireDown = (buttons & IN_ATTACK) != 0;
	if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed) || TF2_IsPlayerInCondition(clientIdx, TFCond_Taunting))
		fireDown = false;
		
	if (fireDown && !MB_FireDown[clientIdx])
	{
		MB_FireDownSince[clientIdx] = curTime;
		MB_PlayChargeSoundOneAt[clientIdx] = curTime + MBA_ChargeSoundOneDelay[clientIdx];
		MB_PlayChargeSoundTwoAt[clientIdx] = curTime + MBA_ChargeSoundTwoDelay[clientIdx];
	}
	else if (!fireDown && MB_FireDown[clientIdx] && !TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed) && !TF2_IsPlayerInCondition(clientIdx, TFCond_Taunting))
	{
		if (projectileCount < MB_MaxProjectiles[clientIdx])
		{
			int chargeLevel = MB_CHARGE_NORMAL;
			if (curTime - MB_FireDownSince[clientIdx] >= MB_FullChargeTime[clientIdx])
				chargeLevel = MB_CHARGE_FULL;
			else if (curTime - MB_FireDownSince[clientIdx] >= MB_HalfChargeTime[clientIdx])
				chargeLevel = MB_CHARGE_HALF;
				
			int projectile = MB_CreateRocket(clientIdx, chargeLevel);
			
			if (IsValidEntity(projectile))
			{
				for (int i = 0; i < MB_MaxProjectiles[clientIdx]; i++)
				{
					if (MB_ProjectileEntRefs[clientIdx][i] == 0)
					{
						MB_ProjectileEntRefs[clientIdx][i] = EntIndexToEntRef(projectile);
						MB_ProjectileMarkedForDeath[clientIdx][i] = false;
						if (chargeLevel == MB_CHARGE_NORMAL)
						{
							MB_ProjectilePlayerDamage[clientIdx][i] = MB_BaseDamage[clientIdx];
							MB_ProjectileBuildingDamage[clientIdx][i] = MB_BaseBuildingDamage[clientIdx];
							MB_ProjectileHasCrits[clientIdx][i] = (MB_Flags[clientIdx] & MB_FLAG_NORMAL_SHOT_CRIT) != 0;
							MB_ProjectileHasPenetration[clientIdx][i] = (MB_Flags[clientIdx] & MB_FLAG_NORMAL_SHOT_PENETRATE) != 0;
							MB_ProjectileSpeed[clientIdx][i] = MB_BaseSpeed[clientIdx];
							if (strlen(MBA_NormalFiringSound[clientIdx]) > 3)
								PseudoAmbientSound(clientIdx, MBA_NormalFiringSound[clientIdx], 1, 800.0);
						}
						else if (chargeLevel == MB_CHARGE_HALF)
						{
							MB_ProjectilePlayerDamage[clientIdx][i] = MB_HalfChargeDamage[clientIdx];
							MB_ProjectileBuildingDamage[clientIdx][i] = MB_HalfChargeBuildingDamage[clientIdx];
							MB_ProjectileHasCrits[clientIdx][i] = (MB_Flags[clientIdx] & MB_FLAG_HALF_CHARGE_CRIT) != 0;
							MB_ProjectileHasPenetration[clientIdx][i] = (MB_Flags[clientIdx] & MB_FLAG_HALF_CHARGE_PENETRATE) != 0;
							MB_ProjectileSpeed[clientIdx][i] = MB_HalfChargeSpeed[clientIdx];
							if (strlen(MBA_HalfChargeFiringSound[clientIdx]) > 3)
								PseudoAmbientSound(clientIdx, MBA_HalfChargeFiringSound[clientIdx], 1, 800.0);
						}
						else if (chargeLevel == MB_CHARGE_FULL)
						{
							MB_ProjectilePlayerDamage[clientIdx][i] = MB_FullChargeDamage[clientIdx];
							MB_ProjectileBuildingDamage[clientIdx][i] = MB_FullChargeBuildingDamage[clientIdx];
							MB_ProjectileHasCrits[clientIdx][i] = (MB_Flags[clientIdx] & MB_FLAG_FULL_CHARGE_CRIT) != 0;
							MB_ProjectileHasPenetration[clientIdx][i] = (MB_Flags[clientIdx] & MB_FLAG_FULL_CHARGE_PENETRATE) != 0;
							MB_ProjectileSpeed[clientIdx][i] = MB_FullChargeSpeed[clientIdx];
							if (strlen(MBA_FullChargeFiringSound[clientIdx]) > 3)
								PseudoAmbientSound(clientIdx, MBA_FullChargeFiringSound[clientIdx], 1, 800.0);
						}
						
						GetEntPropVector(projectile, Prop_Send, "m_vecOrigin", MB_ProjectileSpawnPos[clientIdx][i]);

						break;
					}
				}

				projectileCount++;

				if (PRINT_DEBUG_SPAM)
					PrintToServer("[sarysamods7] Created mega buster projectile, %d of %d", projectileCount, MB_MaxProjectiles[clientIdx]);
			}
		}
		else
		{
			// else do nothing, just quietly fail. since people would button mash in mega man games, a sound or notify would get irritating fast.
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods7] Reached projectile limit, %d of %d", projectileCount, MB_MaxProjectiles[clientIdx]);
		}
	}
	MB_FireDown[clientIdx] = fireDown;
	
	// play sounds if queued up, only if fire is actively held
	bool shouldCancelRecolor = true;
	if (MB_FireDown[clientIdx])
	{
		if (curTime >= MB_PlayChargeSoundOneAt[clientIdx])
		{
			if (strlen(MBA_ChargeSoundOne[clientIdx]) > 3)
			{
				EmitAmbientSound(MBA_ChargeSoundOne[clientIdx], bossPos, clientIdx);
				EmitAmbientSound(MBA_ChargeSoundOne[clientIdx], bossPos, clientIdx);
			}
			MB_PlayChargeSoundOneAt[clientIdx] = FAR_FUTURE;
		}

		if (curTime >= MB_PlayChargeSoundTwoAt[clientIdx])
		{
			if (strlen(MBA_ChargeSoundTwo[clientIdx]) > 3)
			{
				EmitAmbientSound(MBA_ChargeSoundTwo[clientIdx], bossPos, clientIdx);
				EmitAmbientSound(MBA_ChargeSoundTwo[clientIdx], bossPos, clientIdx);
			}
			MB_PlayChargeSoundTwoAt[clientIdx] = curTime + MBA_ChargeSoundLoopInterval[clientIdx];
		}
		
		// is it time to recolor?
		int deltaTimeMS = RoundFloat(((curTime - MB_FireDownSince[clientIdx]) - MBA_ChargeSoundOneDelay[clientIdx]) * 1000.0);
		if (deltaTimeMS > 0)
		{
			shouldCancelRecolor = false;
			
			int slowChargeDuration = RoundFloat((MB_FullChargeTime[clientIdx] - MB_HalfChargeTime[clientIdx]) * 1000.0);
			if (deltaTimeMS > slowChargeDuration)
				deltaTimeMS = (deltaTimeMS - slowChargeDuration) + (slowChargeDuration / 3);
			else
				deltaTimeMS /= 3;
				
			deltaTimeMS %= RAINBOW_LOOP_MS;
				
			if (deltaTimeMS > 0)
			{
				int red = 0;
				int green = 0;
				int blue = 0;
				
				// red
				if (deltaTimeMS < RAINBOW_LOOP_MS / 3)
					red = 255;
				else if (deltaTimeMS >= RAINBOW_LOOP_MS / 3 && deltaTimeMS < RAINBOW_LOOP_MS / 2)
					red = 255 * ((RAINBOW_LOOP_MS / 2) - deltaTimeMS) / RAINBOW_LOOP_SEGMENT;
				else if (deltaTimeMS > RAINBOW_LOOP_MS * 5 / 6)
					red = 255 * (RAINBOW_LOOP_MS - deltaTimeMS) / RAINBOW_LOOP_SEGMENT;
					
				// green
				if (deltaTimeMS > RAINBOW_LOOP_MS / 6 && deltaTimeMS < RAINBOW_LOOP_MS / 3)
					green = 255 * (deltaTimeMS - (RAINBOW_LOOP_MS / 6)) / RAINBOW_LOOP_SEGMENT;
				else if (deltaTimeMS >= RAINBOW_LOOP_MS / 3 && deltaTimeMS <= RAINBOW_LOOP_MS * 2 / 3)
					green = 255;
				else if (deltaTimeMS > RAINBOW_LOOP_MS * 2 / 3 && deltaTimeMS < RAINBOW_LOOP_MS * 5 / 6)
					green = 255 * ((RAINBOW_LOOP_MS * 5 / 6) - deltaTimeMS) / RAINBOW_LOOP_SEGMENT;
					
				// blue
				if (deltaTimeMS > RAINBOW_LOOP_MS / 2 && deltaTimeMS < RAINBOW_LOOP_MS * 2 / 3)
					blue = 255 * (deltaTimeMS - (RAINBOW_LOOP_MS / 2)) / RAINBOW_LOOP_SEGMENT;
				else if (deltaTimeMS >= RAINBOW_LOOP_MS * 2 / 3)
					blue = 255;
				else if (deltaTimeMS < RAINBOW_LOOP_MS / 6)
					blue = 255 * ((RAINBOW_LOOP_MS / 6) - deltaTimeMS) / RAINBOW_LOOP_SEGMENT;
					
				// recolor!
				SetEntityRenderMode(clientIdx, RENDER_TRANSCOLOR);
				SetEntityRenderColor(clientIdx, red, green, blue, 255);
			}
		}
	}
	
	// cancel recolor for charge
	if (shouldCancelRecolor)
	{
		if (GetEntProp(clientIdx, Prop_Send, "m_nRenderMode") != view_as<int>(RENDER_NORMAL))
		{
			SetEntityRenderMode(clientIdx, RENDER_NORMAL);
			SetEntityRenderColor(clientIdx, 255, 255, 255, 255);
		}
	}
}

public void MA_SetActive(int clientIdx, bool isActive)
{
	if (!isActive)
	{
		MB_IsDisabled[clientIdx] = true;
		if ((MB_Flags[clientIdx] & MB_FLAG_HOLD_CHARGE_ON_SWITCH) == 0)
			MB_FireDown[clientIdx] = false;
	}
	else
		MB_IsDisabled[clientIdx] = false;
}

/**
 * Mega Abilities
 */
// someday these abilities will have outside accessors
public void MA_PlayHitSound(int attacker, int victim)
{
	if (!IsLivingPlayer(victim) || !PlayerIsInvincible(victim))
	{
		if (strlen(MBA_HitSound[attacker]) > 3)
			PseudoAmbientSound(victim, MBA_HitSound[attacker], 1, 800.0);
	}
	else if (strlen(MBA_BounceSound[attacker]) > 3)
		PseudoAmbientSound(victim, MBA_BounceSound[attacker], 1, 800.0);
}

public void MA_PlayKillSound(int attacker, int victim)
{
	if (strlen(MBA_DestroySound[attacker]) > 3)
		PseudoAmbientSound(victim, MBA_DestroySound[attacker], 2, 800.0);
}

public void MA_PlayDepletedSound(int clientIdx)
{
	if (strlen(MA_DepletedWeaponSound) > 3)
		EmitSoundToClient(clientIdx, MA_DepletedWeaponSound);
}

public void MA_PlayWeaponSwitchSound(int clientIdx)
{
	if (strlen(MA_WeaponSwitchSound) > 3)
		EmitSoundToClient(clientIdx, MA_WeaponSwitchSound);
}

public void MA_PlayFireSound(int clientIdx)
{
	if (strlen(MBA_NormalFiringSound[clientIdx]) > 3)
		PseudoAmbientSound(clientIdx, MBA_NormalFiringSound[clientIdx], 1, 800.0);
}

public bool MA_AmIActive(int clientIdx, const char[] ability_name)
{
	if (!MB_IsDisabled[clientIdx] || MA_SelectedIndex[clientIdx] == -1)
		return false;
		
	return strcmp(ability_name, MAD_AbilityId[MA_SelectedIndex[clientIdx]]) == 0;
}

public void MA_GetIdealProjectileSpawnPos(int clientIdx, float spawnPos[3])
{
	MB_GetIdealProjectileSpawnPos(clientIdx, spawnPos);
}

public bool MA_ConsumeEnergy(int clientIdx) // this can only be called by the currently active ability
{
	float cost = MAD_AbilityCosts[MA_SelectedIndex[clientIdx]];
	if (cost > MA_EnergyPercent[clientIdx])
	{
		MA_PlayDepletedSound(clientIdx);
		return false;
	}
	
	MA_EnergyPercent[clientIdx] -= cost;
	return true;
}

public void MA_GetCurrentPlayerColor(int clientIdx, int& red, int& green, int& blue)
{
	int color = MAD_PlayerRecolor[MA_SelectedIndex[clientIdx]];
	red = (color>>16)&0xff;
	green = (color>>8)&0xff;
	blue = color&0xff;
}

public float MA_ClassDamageModifier(float damage, int clientIdx, int victim, const char[] abilityId)
{
	int abilityIdx = -1;
	for (int i = 0; i < MA_MAX_ABILITIES; i++)
	{
		if (!strcmp(MAD_AbilityId[i], abilityId))
		{
			abilityIdx = i;
			break;
		}
	}
	
	if (abilityIdx == -1)
	{
		PrintToServer("[sarysamods7] ERROR: Invalid ability for damage modifier %s, ignoring.", abilityId);
		return damage;
	}

	if (IsLivingPlayer(victim))
		return damage * MAD_ClassModifiers[MA_SelectedIndex[clientIdx]][view_as<int>(TF2_GetPlayerClass(victim))];
	return damage * MAD_ClassModifiers[MA_SelectedIndex[clientIdx]][0];
}

public void MA_SetSwitchBlocked(int clientIdx, bool isBlocked)
{
	MA_SwitchBlocked[clientIdx] = isBlocked;
}

public void MA_InitSubAbility(int clientIdx, int bossIdx, const char[] ability_name)
{
	// find a free slot for this index
	int slot = -1;
	for (int i = 0; i < MA_MAX_ABILITIES; i++)
	{
		if (!MAD_AbilityExists[i])
		{
			slot = i;
			break;
		}
		else if (!strcmp(MAD_AbilityId[i], ability_name))
		{
			slot = i;
			break;
		}
	}
	
	// this should never happen, but...
	if (slot == -1)
	{
		PrintToServer("[sarysamods7] ERROR: Somehow exceeded the generous mega-ability limit of %d. Cannot init %s", MA_MAX_ABILITIES, ability_name);
		return;
	}
	
	// add it to the list, if it's a int ability
	if (!MAD_AbilityExists[slot])
	{
		MAD_AbilityExists[slot] = true;
		strcopy(MAD_AbilityId[slot], sizeof(MAD_AbilityId[]), ability_name);
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, 1, MAD_AbilityName[slot], MA_MAX_NAME_LENGTH);
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, 2, MAD_AbilityDescription[slot], MA_MAX_DESCRIPTION_LENGTH);
		MAD_AbilityColor[slot] = ReadHexOrDecString(bossIdx, ability_name, 3);
		MAD_PlayerRecolor[slot] = ReadHexOrDecString(bossIdx, ability_name, 18); // added late, so it's a funny number
		MAD_AbilityCosts[slot] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 4);
		static char classModsStr[101];
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, 5, classModsStr, 101);
		static char classModsStrs[10][10];
		ExplodeString(classModsStr, "#", classModsStrs, 10, 10);
		for (int i = 0; i < 10; i++)
		{
			MAD_ClassModifiers[slot][i] = StringToFloat(classModsStrs[i]);
			if (MAD_ClassModifiers[slot][i] <= 0.0)
				MAD_ClassModifiers[slot][i] = 1.0;
		}
	}
	
	// assign it to the specific player
	MA_HasAbility[clientIdx][slot] = true;
	if (MA_SelectedIndex[clientIdx] == -1)
		MA_SelectedIndex[clientIdx] = slot;
}

// these abilities will not have outside accessors
public Action MA_MedicCommand(int clientIdx, const char[] command, int argc)
{
	if (MA_ActiveThisRound && MA_CanUse[clientIdx] && IsLivingPlayer(clientIdx) && !MA_SwitchBlocked[clientIdx])
	{
		char unparsedArgs[4];
		GetCmdArgString(unparsedArgs, 4);
		
		if (!strcmp(unparsedArgs, "0 0"))
		{
			// since disabled is the opposite of being active, this works
			// bad preplanning ftw.
			MA_SetActive(clientIdx, MB_IsDisabled[clientIdx]);
			MA_PlayWeaponSwitchSound(clientIdx);
		}
	}
}

// added 2015-02-10, cannot hook slot commands since they're hardcoded NOT to go to the server.
// instead, these are secret 
public Action MA_MegaCommand(int clientIdx, int args)
{
	if (MA_ActiveThisRound && MA_CanUse[clientIdx] && IsLivingPlayer(clientIdx) && !MA_SwitchBlocked[clientIdx])
	{
		static char command[6];
		GetCmdArg(0, command, sizeof(command));
		
		// zero will need this
		if (MA_Flags[clientIdx] & MA_FLAG_IGNORE_SLOT_COMMANDS)
			return;

		int desiredWeapon = command[4] - '1';

		// select find Nth available weapon
		bool found = false;
		int slot = 0;
		int numFound = 0;
		for (; slot < MA_MAX_ABILITIES; slot++)
		{
			if (MA_HasAbility[clientIdx][slot])
			{
				if (numFound == desiredWeapon)
				{
					found = true;
					break;
				}
				numFound++;
			}
		}

		if (found)
		{
			MA_SelectedIndex[clientIdx] = slot;
			MA_UpdateHUDsAt[clientIdx] = GetEngineTime();
			//if (MB_IsDisabled[clientIdx])
			MA_PlayWeaponSwitchSound(clientIdx);
		}
		else
		{
			MA_PlayDepletedSound(clientIdx);
		}
	}
}

public void MA_Tick(int clientIdx, int buttons, float curTime)
{
	if (!IsLivingPlayer(clientIdx))
		return;
		
	// determine player max health if not yet done
	if (MA_MaxHealth[clientIdx] == 0)
	{
		MA_MaxHealth[clientIdx] = GetEntProp(clientIdx, Prop_Data, "m_iHealth");
		if (MA_MaxHealth[clientIdx] <= 0)
		{
			PrintToServer("WARNING: Could not determine player max health. Health meter will not work.");
			MA_MaxHealth[clientIdx] = 100;
		}
	}
	
	// just do this always. heh. also those lowercase f's bother the hell out of me.
	FF2_SetFF2flags(clientIdx, FF2_GetFF2flags(clientIdx) | FF2FLAG_HUDDISABLED);
	
	// constantly deplete the FF2 rage meter. we're managing it ourselves and don't want
	// pressing E to screw things up
	int bossIdx = FF2_GetBossIndex(clientIdx);
	float charge = FF2_GetBossCharge(bossIdx, 0);
	if (charge > 0.0)
	{
		MA_EnergyPercent[clientIdx] += charge;
		if (MA_EnergyPercent[clientIdx] > 100.0)
			MA_EnergyPercent[clientIdx] = 100.0;
			
		FF2_SetBossCharge(bossIdx, 0, 0.0);
	}
	
	// key presses
	if (MA_SelectedIndex[clientIdx] != -1)
	{
		// reload keys selects forward
		bool reloadDown = (buttons & IN_RELOAD) != 0;
		if (!MA_ReloadDown[clientIdx] && reloadDown && !MA_SwitchBlocked[clientIdx])
		{
			// select next available weapon
			for (int i = MA_SelectedIndex[clientIdx] + 1; i != MA_SelectedIndex[clientIdx]; i++)
			{
				if (i >= MA_MAX_ABILITIES)
					i = 0;

				if (MA_HasAbility[clientIdx][i])
				{
					MA_SelectedIndex[clientIdx] = i;
					MA_UpdateHUDsAt[clientIdx] = curTime;
					//if (MB_IsDisabled[clientIdx])
					MA_PlayWeaponSwitchSound(clientIdx);
					break;
				}
			}
		}
		MA_ReloadDown[clientIdx] = reloadDown;
		
		// secret use key function selects backwards
		bool useDown = (buttons & IN_USE) != 0;
		if (!MA_UseDown[clientIdx] && useDown && !MA_SwitchBlocked[clientIdx])
		{
			// select previous available weapon
			for (int i = MA_SelectedIndex[clientIdx] - 1; i != MA_SelectedIndex[clientIdx]; i--)
			{
				if (i < 0)
					i = MA_MAX_ABILITIES - 1;

				if (MA_HasAbility[clientIdx][i])
				{
					MA_SelectedIndex[clientIdx] = i;
					MA_UpdateHUDsAt[clientIdx] = curTime;
					//if (MB_IsDisabled[clientIdx])
					MA_PlayWeaponSwitchSound(clientIdx);
					break;
				}
			}
		}
		MA_UseDown[clientIdx] = useDown;

		// recolor the player if their ability active
		if (MB_IsDisabled[clientIdx] && (MA_Flags[clientIdx] & MA_FLAG_RECOLOR_PLAYER) != 0)
		{
			int color = MAD_PlayerRecolor[MA_SelectedIndex[clientIdx]];
			SetEntityRenderMode(clientIdx, RENDER_TRANSCOLOR);
			SetEntityRenderColor(clientIdx, (color>>16) & 0xff, (color>>8) & 0xff, color & 0xff, 255);
		}
	}
	
	// update the HUDs
	if (curTime >= MA_UpdateHUDsAt[clientIdx])
	{
		// the primary HUD color for this, also need default color for HP
		int abilityIdx = MA_SelectedIndex[clientIdx];
		int abilityRed = abilityIdx == -1 ? 0xff : ((MAD_AbilityColor[abilityIdx]>>16) & 0xff);
		int abilityGreen = abilityIdx == -1 ? 0xff : ((MAD_AbilityColor[abilityIdx]>>8) & 0xff);
		int abilityBlue = abilityIdx == -1 ? 0xff : (MAD_AbilityColor[abilityIdx] & 0xff);
		//abilityRed /= 2;
		//abilityGreen /= 2;
		//abilityBlue /= 2;
		int color = (!MB_IsDisabled[clientIdx] || abilityIdx == -1) ? MA_DefaultWeaponColor[clientIdx] : ((abilityRed<<16) | (abilityGreen<<8) | abilityBlue);
		//PrintToServer("0x%x vs 0x%x %x %x", color, abilityRed, abilityGreen, abilityBlue);
		int red = (color>>16) & 0xff;
		int green = (color>>8) & 0xff;
		int blue = color & 0xff;
		int defaultRed = (MA_DefaultWeaponColor[clientIdx]>>16) & 0xff;
		int defaultGreen = (MA_DefaultWeaponColor[clientIdx]>>8) & 0xff;
		int defaultBlue = MA_DefaultWeaponColor[clientIdx] & 0xff;
		int alpha = 255;
		float messageDisplayExtra = 0.05;

		// hp meter
		if ((MA_Flags[clientIdx] & MA_FLAG_HIDE_HP_HUD) == 0)
		{
			static char hpStr[MA_HP_SEGMENTS+1];
			int hp = GetEntProp(clientIdx, Prop_Data, "m_iHealth");
			int segmentsRemaining = hp * MA_HP_SEGMENTS / MA_MaxHealth[clientIdx];
			if (segmentsRemaining <= 0)
				segmentsRemaining = 1;
			for (int i = 0; i < MA_HP_SEGMENTS; i++)
			{
				hpStr[i] = segmentsRemaining > 0 ? '|' : ' ';
				segmentsRemaining--;
			}
			hpStr[MA_HP_SEGMENTS] = 0;
			SetHudTextParams(MA_HP_HUD_X, MA_HP_HUD_Y, MA_HUD_INTERVAL + messageDisplayExtra, defaultRed, defaultGreen, defaultBlue, alpha);
			ShowHudText(clientIdx, -1, hpStr);
		}
	
		// energy meter
		if ((MA_Flags[clientIdx] & MA_FLAG_HIDE_ENERGY_HUD) == 0)
		{
			static char energyStr[MA_ENERGY_SEGMENTS+1];
			int segmentsRemaining = RoundFloat(MA_EnergyPercent[clientIdx] * MA_ENERGY_SEGMENTS / 100.0);
			for (int i = 0; i < MA_ENERGY_SEGMENTS; i++)
			{
				energyStr[i] = segmentsRemaining > 0 ? '|' : ' ';
				segmentsRemaining--;
			}
			energyStr[MA_ENERGY_SEGMENTS] = 0;
			SetHudTextParams(MA_ENERGY_HUD_X, MA_ENERGY_HUD_Y, MA_HUD_INTERVAL + messageDisplayExtra, abilityRed, abilityGreen, abilityBlue, alpha);
			ShowHudText(clientIdx, -1, energyStr);
		}
		
		// mobility variables
		float mobilityCooldown = DD_GetMobilityCooldown(clientIdx);
		float chargePercent = DD_GetChargePercent(clientIdx);
		if (mobilityCooldown == -1.0 || chargePercent == -1.0)
		{
			float bossCharge = FF2_GetBossCharge(bossIdx, 1);
			mobilityCooldown = (bossCharge < 0.0) ? -bossCharge : 0.0;
			chargePercent = (bossCharge < 0.0) ? 0.0 : bossCharge;
		}
		
		// charge HUD replacement
		static char chargeHUD[MAX_CENTER_TEXT_LENGTH];
		if (mobilityCooldown > 0.0)
		{
			//SetHudTextParams(-1.0, MA_CHARGE_HUD_Y, MA_HUD_INTERVAL + messageDisplayExtra, 255, 0, 0, alpha);
			//ShowHudText(clientIdx, -1, MA_ChargeFailHUDMessage, -FF2_GetBossCharge(bossIdx, 1));
			Format(chargeHUD, MAX_CENTER_TEXT_LENGTH, MA_ChargeFailHUDMessage, mobilityCooldown);
		}
		else
		{
			//SetHudTextParams(-1.0, MA_CHARGE_HUD_Y, MA_HUD_INTERVAL + messageDisplayExtra, 255, 255, 255, alpha);
			//ShowHudText(clientIdx, -1, MA_ChargeHUDMessage, RoundFloat(FF2_GetBossCharge(bossIdx, 1)));
			Format(chargeHUD, MAX_CENTER_TEXT_LENGTH, MA_ChargeHUDMessage, RoundFloat(chargePercent));
		}
		
		// selected weapon
		if (abilityIdx != -1)
		{
			SetHudTextParams(-1.0, MA_ABILITY_HUD_Y, MA_HUD_INTERVAL + messageDisplayExtra, abilityRed, abilityGreen, abilityBlue, alpha);
			ShowHudText(clientIdx, -1, MA_SecondaryWeaponMessage, MAD_AbilityName[abilityIdx], chargeHUD);
		}
		
		// normal HUD
		SetHudTextParams(-1.0, MA_TUTORIAL_HUD_Y, MA_HUD_INTERVAL + messageDisplayExtra, red, green, blue, alpha);
		if (!MB_IsDisabled[clientIdx] || abilityIdx == -1)
			ShowHudText(clientIdx, -1, MA_HUDMessage, MA_DefaultWeaponName[clientIdx], MA_DefaultWeaponDesc[clientIdx]);
		else
			ShowHudText(clientIdx, -1, MA_HUDMessage, MAD_AbilityName[abilityIdx], MAD_AbilityDescription[abilityIdx]);
	
		MA_UpdateHUDsAt[clientIdx] = curTime + MA_HUD_INTERVAL;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!MA_ActiveThisRound)
		return;
	
	// hook sentries to the various OnTakeDamage methods
	if (!strcmp(classname, "obj_sentrygun") || !strcmp(classname, "obj_dispenser") || !strcmp(classname, "obj_teleporter"))
	{
		// party cannon
		if (MP_ActiveThisRound)
		{
			SDKHook(entity, SDKHook_OnTakeDamage, MP_OnTakeDamage);
			SDKHook(entity, SDKHook_OnTakeDamagePost, MP_OnTakeDamagePost);
		}

		// apple bucker
		if (MAB_ActiveThisRound)
		{
			SDKHook(entity, SDKHook_OnTakeDamage, MAB_OnTakeDamage);
			SDKHook(entity, SDKHook_OnTakeDamagePost, MAB_OnTakeDamagePost);
		}
	}
}

/**
 * Sonic Rainboom
 */
public Action MR_OnStartTouch(int clientIdx, int victim)
{
	bool isValidTarget = false;
	bool isBuilding = false;
	bool isFuncBreakable = false;
	if (IsLivingPlayer(victim) && GetClientTeam(victim) != BossTeam)
		isValidTarget = true;
	else if (IsValidEntity(victim))
	{
		// did we hit a building?
		char classname[MAX_ENTITY_CLASSNAME_LENGTH];
		GetEntityClassname(victim, classname, MAX_ENTITY_CLASSNAME_LENGTH);
		isFuncBreakable = strcmp(classname, "func_breakable") == 0;
		isBuilding = (strcmp(classname, "obj_sentrygun") == 0) || (strcmp(classname, "obj_dispenser") == 0) || (strcmp(classname, "obj_teleporter") == 0);
		isValidTarget = isBuilding || isFuncBreakable;
	}
	
	if (!isValidTarget)
		return Plugin_Continue;
	
	// do damage, finish rage, and bounce
	if (isFuncBreakable)
	{
		MA_PlayHitSound(clientIdx, clientIdx);
		SDKHooks_TakeDamage(victim, clientIdx, clientIdx, MR_Damage[clientIdx], DMG_GENERIC, -1);
	}
	else if (isBuilding)
	{
		SDKHooks_TakeDamage(victim, clientIdx, clientIdx, MA_ClassDamageModifier(MR_Damage[clientIdx], clientIdx, victim, MR_STRING), DMG_GENERIC, -1);
		if (GetEntProp(victim, Prop_Send, "m_iHealth") <= 0)
			MA_PlayKillSound(clientIdx, victim);
		else
			MA_PlayHitSound(clientIdx, victim);
	}
	else
	{
		FullyHookedDamage(victim, clientIdx, clientIdx, fixDamageForFF2(MA_ClassDamageModifier(MR_Damage[clientIdx], clientIdx, victim, MR_STRING)), DMG_GENERIC, -1);
		if (!IsLivingPlayer(victim))
			MA_PlayKillSound(clientIdx, victim);
		else
			MA_PlayHitSound(clientIdx, victim);
	}
	MR_Finish(clientIdx, true);
	
	return Plugin_Handled;
}

public void MR_Finish(int clientIdx, bool bounce)
{
	SDKUnhook(clientIdx, SDKHook_StartTouch, MR_OnStartTouch);
	MA_SetSwitchBlocked(clientIdx, false);
	MR_HasToxicTouch[clientIdx] = false;
	MR_VerifyRageAt[clientIdx] = FAR_FUTURE;
	MR_ForceFinishAt[clientIdx] = FAR_FUTURE;
	TF2_RemoveCondition(clientIdx, TFCond_MegaHeal);
	TF2_RemoveCondition(clientIdx, TFCond_HalloweenKartDash);
	
	if (bounce)
		MR_BouncePending[clientIdx] = true;
}

public void MR_Tick(int clientIdx, int buttons, float curTime)
{
	bool attackDown = (buttons & IN_ATTACK) != 0;
	bool shouldFire = attackDown & !MR_AttackDown[clientIdx];
	MR_AttackDown[clientIdx] = attackDown;
	if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed) || TF2_IsPlayerInCondition(clientIdx, TFCond_Taunting))
		shouldFire = false;
	
	if (curTime >= MR_ForceFinishAt[clientIdx])
		MR_Finish(clientIdx, false);
	else if (curTime >= MR_VerifyRageAt[clientIdx])
	{
		static float velocity[3];
		GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", velocity);
		float linearVelocity = getLinearVelocity(velocity);
		if (linearVelocity < MR_RequiredVelocity[clientIdx])
		{
			MR_Finish(clientIdx, false);
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods7] Rainboom ended because velocity (%f) below minimum. (%f)", linearVelocity, MR_RequiredVelocity[clientIdx]);
		}
		else
			MR_VerifyRageAt[clientIdx] = curTime + MR_VALIDATION_INTERVAL;
	}

	if (MR_BouncePending[clientIdx])
	{
		static float angles[3];
		angles[0] = -45.0;
		angles[1] = fixAngle(MR_PushYaw[clientIdx] + 180.0);
		angles[2] = 0.0;
		static float velocity[3];
		GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(velocity, MR_BounceIntensity[clientIdx]);
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods7] Bouncing player %f,%f,%f", velocity[0], velocity[1], velocity[2]);
		TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, velocity);
		MR_BouncePending[clientIdx] = false;
		
		shouldFire = false; // would be a bit weird otherwise
	}

	if (!MA_AmIActive(clientIdx, MR_STRING))
		return;
		
	if (MR_HasToxicTouch[clientIdx])
		shouldFire = false; // already active
	
	if (shouldFire && MA_ConsumeEnergy(clientIdx))
	{
		// do the velocity push, similar to Button Mash's charge
		static float angles[3];
		GetClientEyeAngles(clientIdx, angles);
		static float velocity[3];
		GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(velocity, MR_ChargeIntensity[clientIdx]);
		if ((GetEntityFlags(clientIdx) & FL_ONGROUND) != 0 && velocity[2] < MR_MinZLift[clientIdx])
			velocity[2] = MR_MinZLift[clientIdx];
		TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, velocity);
	
		// temporarily listen to touches for the hale
		SDKHook(clientIdx, SDKHook_StartTouch, MR_OnStartTouch);
		
		// configure
		MA_SetSwitchBlocked(clientIdx, true);
		MR_HasToxicTouch[clientIdx] = true;
		MR_VerifyRageAt[clientIdx] = curTime + MR_VALIDATION_INTERVAL;
		MR_ForceFinishAt[clientIdx] = curTime + MR_ChargeDuration[clientIdx];
		MR_PushYaw[clientIdx] = angles[1];
		
		// knockback immune
		TF2_AddCondition(clientIdx, TFCond_MegaHeal, -1.0);
		TF2_AddCondition(clientIdx, TFCond_HalloweenKartDash, -1.0);
		
		// play the sound
		if (strlen(MR_UseSound) > 3)
			PseudoAmbientSound(clientIdx, MR_UseSound, 1, 800.0);
	}
}

/**
 * Gem Seeker
 */
public int MG_CreateRocket(int clientIdx, float spawnPos[3], float angles[3]) // z offset is handled by caller
{
	// create our rocket. no matter what, it's going to spawn, even if it ends up being out of map
	float damage = fixDamageForFF2(MG_Damage[clientIdx]);
	float speed = MG_Speed[clientIdx];
	
	int rocket = CreateEntityByName("tf_projectile_rocket");
	if (!IsValidEntity(rocket))
	{
		PrintToServer("[sarysamods7] Error: Invalid entity \"tf_projectile_rocket\". Won't spawn rocket. This is sarysa's fault.");
		return -1;
	}
	
	// get spawn position, angles, velocity
	static float velocity[3];
	GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(velocity, speed);
	
	// deploy!
	TeleportEntity(rocket, spawnPos, angles, velocity);
	SetEntProp(rocket, Prop_Send, "m_bCritical", false); // no random crits
	SetEntDataFloat(rocket, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, damage, true); // credit to voogru
	SetEntProp(rocket, Prop_Send, "m_nSkin", 1); // set skin to BLU team's
	SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", clientIdx);
	SetVariantInt(BossTeam);
	AcceptEntityInput(rocket, "TeamNum", -1, -1, 0);
	SetVariantInt(BossTeam);
	AcceptEntityInput(rocket, "SetTeam", -1, -1, 0); 
	DispatchSpawn(rocket);
	
	// reskin after spawn
	if (MG_Model[clientIdx] != -1)
		SetEntProp(rocket, Prop_Send, "m_nModelIndex", MG_Model[clientIdx]);

	// hook touches
	SDKHook(rocket, SDKHook_StartTouch, MG_OnStartTouch);
	SDKHook(rocket, SDKHook_StartTouchPost, MG_OtherTouches);
	SDKHook(rocket, SDKHook_Touch, MG_OtherTouches);
	SDKHook(rocket, SDKHook_TouchPost, MG_OtherTouches);
	SDKHook(rocket, SDKHook_EndTouch, MG_OtherTouches);
	SDKHook(rocket, SDKHook_EndTouchPost, MG_OtherTouches);
	
	return rocket;
}

public void MG_FindProjectileOwner(int projectile, int& returnClientIdx, int& index)
{
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!MG_CanUse[clientIdx])
			continue;
	
		for (int i = 0; i < MG_MaxProjectiles[clientIdx]; i++)
		{
			if (MG_EntRefs[clientIdx][i] == 0)
				continue;
			
			if (projectile == EntRefToEntIndex(MG_EntRefs[clientIdx][i]))
			{
				returnClientIdx = clientIdx;
				index = i;
				return;
			}
		}
	}
}

public Action MG_OnStartTouch(int projectile, int victim)
{
	bool isValidTarget = false;
	bool isBuilding = false;
	if (IsLivingPlayer(victim) && GetClientTeam(victim) != BossTeam)
		isValidTarget = true;
	else if (IsValidEntity(victim))
	{
		// did we hit a building?
		char classname[MAX_ENTITY_CLASSNAME_LENGTH];
		GetEntityClassname(victim, classname, MAX_ENTITY_CLASSNAME_LENGTH);
		isValidTarget = (strcmp(classname, "obj_sentrygun") == 0) || (strcmp(classname, "obj_dispenser") == 0) || (strcmp(classname, "obj_teleporter") == 0);
		isBuilding = isValidTarget;
	}
	
	if (!isValidTarget)
	{
		// mark for death
		MG_QueueDestruction(projectile);
		return Plugin_Handled;
	}
	
	int clientIdx = -1;
	int index = 0;
	MG_FindProjectileOwner(projectile, clientIdx, index);
	if (clientIdx == -1 || !IsClientInGame(clientIdx))
	{
		PrintToServer("[sarysamods7] WARNING (Gem Seeker): Cannot find projectile owner. It'll detonate normally.");
		return Plugin_Continue;
	}
	
	// maybe this is the source of my woes?
	if (MG_MarkedForDeath[clientIdx][index])
		return Plugin_Handled;
	
	// do damage, mark projectile for destruction
	if (isBuilding)
	{
		SDKHooks_TakeDamage(victim, clientIdx, clientIdx, MA_ClassDamageModifier(MG_Damage[clientIdx], clientIdx, victim, MG_STRING), DMG_GENERIC, -1);
		if (GetEntProp(victim, Prop_Send, "m_iHealth") <= 0)
			MA_PlayKillSound(clientIdx, victim);
		else
			MA_PlayHitSound(clientIdx, victim);
	}
	else
	{
		FullyHookedDamage(victim, clientIdx, clientIdx, fixDamageForFF2(MA_ClassDamageModifier(MG_Damage[clientIdx], clientIdx, victim, MG_STRING)), DMG_GENERIC, -1);
		if (!IsLivingPlayer(victim))
			MA_PlayKillSound(clientIdx, victim);
		else
			MA_PlayHitSound(clientIdx, victim);
	}
	MG_QueueDestruction(projectile);
	
	return Plugin_Handled;
}

public Action MG_OtherTouches(int projectile, int victim)
{
	return Plugin_Handled; // prevent explosion
}

public void MG_QueueDestruction(int rocket)
{
	int clientIdx = -1;
	int index = 0;
	MG_FindProjectileOwner(rocket, clientIdx, index);
	MG_MarkedForDeath[clientIdx][index] = true;
}
 
public void MG_DestroyRocketDiscretely(int rocket)
{
	TeleportEntity(rocket, OFF_THE_MAP, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(rocket, "KillHierarchy");
}

public void MG_EndImmunity(int clientIdx)
{
	// allow ability switching
	MA_SetSwitchBlocked(clientIdx, false);
	MG_IsImmune[clientIdx] = false;
	
	// remove ubercharge
	TF2_RemoveCondition(clientIdx, TFCond_Ubercharged);
	
	// projectile spawn position
	static float spawnPos[3];
	MA_GetIdealProjectileSpawnPos(clientIdx, spawnPos);

	// the projectiles will seek out interesting entities. if none can be found, they'll fly out in random directions.
	int validEntityCount = 0;
	static validEntities[40];
	static bool isTeleporter[40];
	for (int i = 0; i < 40; i++)
	{
		validEntities[i] = 0;
		isTeleporter[i] = false;
	}
	
	// players first
	for (int victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
			continue;
		else if (validEntityCount == 40)
			break;
			
		if (CheckLineOfSight(spawnPos, victim, 41.5))
		{
			validEntities[validEntityCount] = victim;
			validEntityCount++;
		}
	}
	
	// then buildings
	for (int pass = 0; pass < 3; pass++)
	{
		static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
		if (pass == 0) classname = "obj_sentrygun";
		else if (pass == 1) classname = "obj_dispenser";
		else if (pass == 2) classname = "obj_teleporter";

		int building = -1;
		while ((building = FindEntityByClassname(building, classname)) != -1)
		{
			if (validEntityCount == 40)
				break;
				
			if (CheckLineOfSight(spawnPos, building, pass == 2 ? 3.0 : 41.5))
			{
				validEntities[validEntityCount] = building;
				validEntityCount++;
				isTeleporter[validEntityCount] = (pass == 2);
			}
		}
	}
	
	// now spawn the rockets!
	for (int derp = 0; derp < 5; derp++)
	{
		static float angles[3];
		if (validEntityCount == 0)
		{
			angles[0] = GetRandomFloat(-45.0, 0.0);
			angles[1] = GetRandomFloat(-179.9, 179.9);
			angles[2] = 0.0;
		}
		else
		{
			int victimIdx = GetRandomInt(0, validEntityCount-1);
			int victim = validEntities[victimIdx];
			static float victimPos[3];
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
			victimPos[2] += isTeleporter[victimIdx] ? 3.0 : 41.5;
			GetVectorAnglesTwoPoints(spawnPos, victimPos, angles);
		}
		int rocket = MG_CreateRocket(clientIdx, spawnPos, angles);
		
		spawnPos[2] += 1.0;
		
		for (int i = 0; i < MG_MaxProjectiles[clientIdx]; i++)
		{
			if (MG_EntRefs[clientIdx][i] == 0)
			{
				MG_EntRefs[clientIdx][i] = EntIndexToEntRef(rocket);
				MG_SpawnPos[clientIdx][i][0] = spawnPos[0];
				MG_SpawnPos[clientIdx][i][1] = spawnPos[1];
				MG_SpawnPos[clientIdx][i][2] = spawnPos[2];
				MG_MarkedForDeath[clientIdx][i] = false;
				break;
			}
		}

		// workaround for gems being the wrong color
		int red, green, blue;
		MA_GetCurrentPlayerColor(clientIdx, red, green, blue);
		SetEntityRenderMode(rocket, RENDER_TRANSCOLOR);
		SetEntityRenderColor(rocket, red, green, blue, 255);
	}
}
 
public void MG_Tick(int clientIdx, int buttons, float curTime)
{
	bool attackDown = (buttons & IN_ATTACK) != 0;
	bool shouldFire = attackDown & !MG_AttackDown[clientIdx];
	bool shouldRelease = !attackDown & MG_AttackDown[clientIdx];
	MG_AttackDown[clientIdx] = attackDown;
	if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed) || TF2_IsPlayerInCondition(clientIdx, TFCond_Taunting))
		shouldFire = false;

	// verify the validity of existing projectiles, and count them
	int projectileCount = 0;
	float rangeLimitCheck = MG_DistanceLimit[clientIdx] * MG_DistanceLimit[clientIdx];
	for (int i = 0; i < MG_MaxProjectiles[clientIdx]; i++)
	{
		if (MG_EntRefs[clientIdx][i] == 0)
			continue;
		
		int projectile = EntRefToEntIndex(MG_EntRefs[clientIdx][i]);
		if (!IsValidEntity(projectile))
		{
			MG_EntRefs[clientIdx][i] = 0;
			continue;
		}
		
		// airblasted. it now belongs to a pyro.
		if ((GetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity") & 0xff) != clientIdx)
		{
			MG_EntRefs[clientIdx][i] = 0;
			continue;
		}
		
		if (MG_MarkedForDeath[clientIdx][i])
		{
			MG_DestroyRocketDiscretely(projectile);
			MG_EntRefs[clientIdx][i] = 0;
			continue;
		}
		
		float projectilePos[3];
		GetEntPropVector(projectile, Prop_Send, "m_vecOrigin", projectilePos);
		if (GetVectorDistance(MG_SpawnPos[clientIdx][i], projectilePos, true) > rangeLimitCheck)
		{
			MG_DestroyRocketDiscretely(projectile);
			MG_EntRefs[clientIdx][i] = 0;
			continue;
		}
		
		projectileCount++;
	}
	
	if (shouldRelease && MG_IsImmune[clientIdx])
		MG_EndImmunity(clientIdx);
	else if (MG_IsImmune[clientIdx] && curTime >= MG_ForceEndImmunityAt[clientIdx])
		MG_EndImmunity(clientIdx);
		
	// check toxicity
	if (MG_IsImmune[clientIdx])
	{
		static float bossPos[3];
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossPos);
		float toxicRangeCheck = MG_ToxicRadius[clientIdx] * MG_ToxicRadius[clientIdx];
		for (int victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
				continue;
			else if (MG_ImmuneUntil[clientIdx][victim] > curTime)
				continue;
				
			// do a range check
			static float victimPos[3];
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
			if (GetVectorDistance(victimPos, bossPos, true) < toxicRangeCheck)
			{
				MG_ImmuneUntil[clientIdx][victim] = curTime + MG_ToxicImmunityPeriod[clientIdx];
				
				// apply damage
				FullyHookedDamage(victim, clientIdx, clientIdx, fixDamageForFF2(MA_ClassDamageModifier(MG_ToxicDamagePerTick[clientIdx], clientIdx, victim, MG_STRING)), DMG_GENERIC, -1);
				if (!IsLivingPlayer(victim))
					MA_PlayKillSound(clientIdx, victim);
				else
					MA_PlayHitSound(clientIdx, victim);
			}
		}
	}

	if (!MA_AmIActive(clientIdx, MG_STRING))
		return;
		
	if (projectileCount + 5 > MG_MaxProjectiles[clientIdx])
		shouldFire = false;
	
	if (shouldFire && MA_ConsumeEnergy(clientIdx))
	{
		MG_IsImmune[clientIdx] = true;
		MA_SetSwitchBlocked(clientIdx, true); // this is very, very necessary
		MG_ForceEndImmunityAt[clientIdx] = curTime + MG_ToxicImmunityDuration[clientIdx];
		
		// ubercharged, but NOT m_takedamage 0. can still be backstabbed, but it'd unlikely.
		// more importantly, it allows knockback to still be received.
		TF2_AddCondition(clientIdx, TFCond_Ubercharged, -1.0);
				
		// play the sound
		if (strlen(MG_FireSound) > 3)
			PseudoAmbientSound(clientIdx, MG_FireSound, 1, 800.0);
	}
}

/**
 * The Stare
 */
public void MS_Tick(int clientIdx, int buttons, float curTime)
{
	// even if this ability isn't active, the player slows must still be managed
	for (int victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (MS_VictimSlowUntil[victim] > 0.0)
		{
			if (!IsLivingPlayer(victim))
			{
				MS_VictimSlowUntil[victim] = 0.0;
				continue;
			}
			
			float maxSpeed = GetEntPropFloat(victim, Prop_Send, "m_flMaxspeed");
			if (curTime >= MS_VictimSlowUntil[victim])
			{
				MS_VictimSlowUntil[victim] = 0.0;
				
				// restore speed if necessary
				if (maxSpeed == MS_VictimExpectedSpeed[victim] && MS_VictimSpeedFactor[victim] > 0.0)
					SetEntPropFloat(victim, Prop_Send, "m_flMaxspeed", maxSpeed / MS_VictimSpeedFactor[victim]);
					
				continue;
			}
			
			// nerf their speed if it's not what's expected, it means they performed some speed-altering action
			if (maxSpeed != MS_VictimExpectedSpeed[victim])
			{
				MS_VictimExpectedSpeed[victim] = maxSpeed * MS_VictimSpeedFactor[victim];
				SetEntPropFloat(victim, Prop_Send, "m_flMaxspeed", MS_VictimExpectedSpeed[victim]);
			}
		}
	}

	bool attackDown = (buttons & IN_ATTACK) != 0;
	bool shouldFire = attackDown & !MS_AttackDown[clientIdx];
	MS_AttackDown[clientIdx] = attackDown;
	if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed) || TF2_IsPlayerInCondition(clientIdx, TFCond_Taunting))
		shouldFire = false;

	if (!MA_AmIActive(clientIdx, MS_STRING))
		return;
	
	if (shouldFire && MA_ConsumeEnergy(clientIdx))
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("Executing THE STARE. Will do %f damage to players in a radius.", MS_Damage[clientIdx]);
	
		float rangeCheck = MS_Radius[clientIdx] * MS_Radius[clientIdx];
		static float bossOrigin[3];
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
		for (int victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
				continue;
				
			// ensure distance check
			static float victimOrigin[3];
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimOrigin);
			if (GetVectorDistance(bossOrigin, victimOrigin, true) > rangeCheck)
				continue;
				
			// apply damage via point hurt
			FullyHookedDamage(victim, clientIdx, clientIdx, fixDamageForFF2(MA_ClassDamageModifier(MS_Damage[clientIdx], clientIdx, victim, MS_STRING)), DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE);
			
			// play the proper sound
			if (!IsLivingPlayer(victim))
				MA_PlayKillSound(clientIdx, victim);
			else
				MA_PlayHitSound(clientIdx, victim);
				
			// apply slow, but only to non-invincible players. optionally apply velocity cancel.
			if (!PlayerIsInvincible(victim))
			{
				MS_VictimSpeedFactor[victim] = MS_SlowFactor[clientIdx];
				if (MS_VictimSlowUntil[victim] == 0.0) // sarysa 2015-02-10, need this to prevent stacking
					MS_VictimExpectedSpeed[victim] = 0.0; // this'll force it to reset
				MS_VictimSlowUntil[victim] = curTime + MS_SlowDuration[clientIdx];
				
				if (MS_HaltMotion[clientIdx])
					TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, view_as<float>( { 0.0, 0.0, 0.0 } ));
			}
		}
		
		// play the sound
		if (strlen(MS_UseSound) > 3)
			PseudoAmbientSound(clientIdx, MS_UseSound, 1, MS_Radius[clientIdx] * 2.0);
	}
}

/**
 * Magic Wave
 */
public int MM_CreateRocket(int clientIdx, bool isChild, float zOffset)
{
	// create our rocket. no matter what, it's going to spawn, even if it ends up being out of map
	float damage = fixDamageForFF2(MM_Damage[clientIdx]);
	float speed = MM_Speed[clientIdx];
	
	int rocket = CreateEntityByName("tf_projectile_rocket");
	if (!IsValidEntity(rocket))
	{
		PrintToServer("[sarysamods7] Error: Invalid entity \"tf_projectile_rocket\". Won't spawn rocket. This is sarysa's fault.");
		return -1;
	}
	
	// get spawn position, angles, velocity
	static float spawnPos[3];
	MA_GetIdealProjectileSpawnPos(clientIdx, spawnPos);
	spawnPos[2] += zOffset;
	static float angles[3];
	GetClientEyeAngles(clientIdx, angles);
	if (isChild)
	{
		// get random deviation, but unlike with beggar's it must ALWAYS be the maximum
		// the goal is to have children fly at a fairly uniform pattern
		float xOffset = GetRandomFloat(0.0, MM_AngleDeviation[clientIdx]);
		float yOffset = SquareRoot((MM_AngleDeviation[clientIdx] * MM_AngleDeviation[clientIdx]) - (xOffset * xOffset));
		if (GetRandomInt(0, 1) == 1)
			xOffset = -xOffset;
		if (GetRandomInt(0, 1) == 1)
			yOffset = -yOffset;
		angles[0] += xOffset;
		angles[1] += yOffset;
	}
	static float velocity[3];
	GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(velocity, speed);
	
	// deploy!
	TeleportEntity(rocket, spawnPos, angles, velocity);
	SetEntProp(rocket, Prop_Send, "m_bCritical", false); // no random crits
	SetEntDataFloat(rocket, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, damage, true); // credit to voogru
	SetEntProp(rocket, Prop_Send, "m_nSkin", 1); // set skin to BLU team's
	SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", clientIdx);
	SetVariantInt(BossTeam);
	AcceptEntityInput(rocket, "TeamNum", -1, -1, 0);
	SetVariantInt(BossTeam);
	AcceptEntityInput(rocket, "SetTeam", -1, -1, 0); 
	DispatchSpawn(rocket);
	
	// reskin after spawn
	if (MM_Model[clientIdx] != -1)
		SetEntProp(rocket, Prop_Send, "m_nModelIndex", MM_Model[clientIdx]);
		
	// play the firing sound
	if (strlen(MM_FireSound) > 3)
		PseudoAmbientSound(clientIdx, MM_FireSound, 1, 800.0);
	else
		MA_PlayFireSound(clientIdx);

	// hook touches
	SDKHook(rocket, SDKHook_StartTouch, MM_OnStartTouch);
	SDKHook(rocket, SDKHook_StartTouchPost, MM_OtherTouches);
	SDKHook(rocket, SDKHook_Touch, MM_OtherTouches);
	SDKHook(rocket, SDKHook_TouchPost, MM_OtherTouches);
	SDKHook(rocket, SDKHook_EndTouch, MM_OtherTouches);
	SDKHook(rocket, SDKHook_EndTouchPost, MM_OtherTouches);
	
	return rocket;
}

public void MM_FindProjectileOwner(int projectile, int& returnClientIdx, int& index)
{
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!MM_CanUse[clientIdx])
			continue;
	
		for (int i = 0; i < MM_MaxProjectiles[clientIdx]; i++)
		{
			if (MM_EntRefs[clientIdx][i] == 0)
				continue;
			
			if (projectile == EntRefToEntIndex(MM_EntRefs[clientIdx][i]))
			{
				returnClientIdx = clientIdx;
				index = i;
				return;
			}
		}
	}
}

public Action MM_OnStartTouch(int projectile, int victim)
{
	bool isValidTarget = false;
	bool isBuilding = false;
	bool isFuncBreakable = false;
	if (IsLivingPlayer(victim) && GetClientTeam(victim) != BossTeam)
		isValidTarget = true;
	else if (IsValidEntity(victim))
	{
		// did we hit a building?
		char classname[MAX_ENTITY_CLASSNAME_LENGTH];
		GetEntityClassname(victim, classname, MAX_ENTITY_CLASSNAME_LENGTH);
		isFuncBreakable = strcmp(classname, "func_breakable") == 0;
		isBuilding = (strcmp(classname, "obj_sentrygun") == 0) || (strcmp(classname, "obj_dispenser") == 0) || (strcmp(classname, "obj_teleporter") == 0);
		isValidTarget = isBuilding || isFuncBreakable;
	}
	
	if (!isValidTarget)
	{
		// mark for death
		MM_QueueDestruction(projectile);
		return Plugin_Handled;
	}
	
	int clientIdx = -1;
	int index = 0;
	MM_FindProjectileOwner(projectile, clientIdx, index);
	if (clientIdx == -1 || !IsClientInGame(clientIdx))
	{
		PrintToServer("WARNING (Magic Wave): Cannot find projectile owner. It'll detonate normally.");
		return Plugin_Continue;
	}
	
	// maybe this is the source of my woes?
	if (MM_MarkedForDeath[clientIdx][index])
		return Plugin_Handled;
	
	// do damage, mark projectile for destruction
	if (isFuncBreakable)
	{
		SDKHooks_TakeDamage(victim, clientIdx, clientIdx, MM_Damage[clientIdx], DMG_GENERIC, -1);
		MA_PlayHitSound(clientIdx, projectile);
	}
	else if (isBuilding)
	{
		SDKHooks_TakeDamage(victim, clientIdx, clientIdx, MA_ClassDamageModifier(MM_Damage[clientIdx], clientIdx, victim, MM_STRING), DMG_GENERIC, -1);
		if (GetEntProp(victim, Prop_Send, "m_iHealth") <= 0)
			MA_PlayKillSound(clientIdx, victim);
		else
			MA_PlayHitSound(clientIdx, victim);
	}
	else
	{
		FullyHookedDamage(victim, clientIdx, clientIdx, fixDamageForFF2(MA_ClassDamageModifier(MM_Damage[clientIdx], clientIdx, victim, MM_STRING)), DMG_GENERIC, -1);
		if (!IsLivingPlayer(victim))
			MA_PlayKillSound(clientIdx, victim);
		else
			MA_PlayHitSound(clientIdx, victim);
	}
	MM_QueueDestruction(projectile);
	
	return Plugin_Handled;
}

public Action MM_OtherTouches(int projectile, int victim)
{
	return Plugin_Handled; // prevent explosion
}

public void MM_QueueDestruction(int rocket)
{
	int clientIdx = -1;
	int index = 0;
	MM_FindProjectileOwner(rocket, clientIdx, index);
	MM_MarkedForDeath[clientIdx][index] = true;
}
 
public void MM_DestroyRocketDiscretely(int rocket)
{
	TeleportEntity(rocket, OFF_THE_MAP, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(rocket, "KillHierarchy");
}

public void MM_Tick(int clientIdx, int buttons, float curTime)
{
	bool attackDown = (buttons & IN_ATTACK) != 0;
	bool shouldFire = attackDown & !MM_AttackDown[clientIdx];
	MM_AttackDown[clientIdx] = attackDown;
	if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed) || TF2_IsPlayerInCondition(clientIdx, TFCond_Taunting))
		shouldFire = false;
	
	// verify the validity of existing projectiles, and count them
	int projectileCount = 0;
	float rangeLimitCheck = MM_DistanceLimit[clientIdx] * MM_DistanceLimit[clientIdx];
	for (int i = 0; i < MM_MaxProjectiles[clientIdx]; i++)
	{
		if (MM_EntRefs[clientIdx][i] == 0)
			continue;
		
		int projectile = EntRefToEntIndex(MM_EntRefs[clientIdx][i]);
		if (!IsValidEntity(projectile))
		{
			MM_EntRefs[clientIdx][i] = 0;
			continue;
		}
		
		// airblasted. it now belongs to a pyro.
		if ((GetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity") & 0xff) != clientIdx)
		{
			MM_EntRefs[clientIdx][i] = 0;
			continue;
		}
		
		if (MM_MarkedForDeath[clientIdx][i])
		{
			MM_DestroyRocketDiscretely(projectile);
			MM_EntRefs[clientIdx][i] = 0;
			continue;
		}
		
		float projectilePos[3];
		GetEntPropVector(projectile, Prop_Send, "m_vecOrigin", projectilePos);
		if (GetVectorDistance(MM_SpawnPos[clientIdx][i], projectilePos, true) > rangeLimitCheck)
		{
			MM_DestroyRocketDiscretely(projectile);
			MM_EntRefs[clientIdx][i] = 0;
			continue;
		}
		
		projectileCount++;
	}
	
	if (curTime >= MM_ReangleAt[clientIdx])
	{
		if (projectileCount > 0)
		{
			for (int i = 0; i < MM_MaxProjectiles[clientIdx]; i++)
			{
				if (MM_ParentEntRef[clientIdx][i] == 0 || MM_EntRefs[clientIdx][i] == 0)
					continue;
					
				int parent = EntRefToEntIndex(MM_ParentEntRef[clientIdx][i]);
				if (!IsValidEntity(parent))
				{
					MM_ParentEntRef[clientIdx][i] = 0;
					continue;
				}
				
				int projectile = EntRefToEntIndex(MM_EntRefs[clientIdx][i]);
				if (!IsValidEntity(projectile))
				{
					if (PRINT_DEBUG_SPAM)
						PrintToServer("[sarysamods7] MAGIC WAVE: Somehow an invalid projectile leaked to the reangle test?!");
					MM_EntRefs[clientIdx][i] = 0;
					continue;
				}
				float projectilePos[3];
				GetEntPropVector(projectile, Prop_Send, "m_vecOrigin", projectilePos);
				float parentPos[3];
				GetEntPropVector(parent, Prop_Send, "m_vecOrigin", parentPos);
				
				float distance = GetVectorDistance(parentPos, projectilePos);
				if (distance > MM_AttractionDistance[clientIdx] && distance < 10.0 * MM_AttractionDistance[clientIdx]) // sanity
				{
					float oldAngle[3];
					float newAngle[3];
					GetEntPropVector(projectile, Prop_Data, "m_angRotation", oldAngle);
					GetEntPropVector(parent, Prop_Data, "m_angRotation", newAngle);
					newAngle[0] += newAngle[0] - oldAngle[0];
					newAngle[1] += newAngle[1] - oldAngle[1];
					newAngle[2] += newAngle[2] - oldAngle[2];
					float velocity[3];
					GetAngleVectors(newAngle, velocity, NULL_VECTOR, NULL_VECTOR);
					ScaleVector(velocity, MM_Speed[clientIdx] + (distance * MM_AttractionFactor[clientIdx]));
					
					// throw out absurd velocities. clearly the parent is marked for death
					TeleportEntity(projectile, NULL_VECTOR, newAngle, velocity);
				}
			}
		}
		
		MM_ReangleAt[clientIdx] = curTime + MM_REANGLE_INTERVAL;
	}

	if (!MA_AmIActive(clientIdx, MM_STRING))
		return;
		
	if (projectileCount + 2 >= MM_MaxProjectiles[clientIdx])
		shouldFire = false;
	
	if (shouldFire && MA_ConsumeEnergy(clientIdx))
	{
		int parent = MM_CreateRocket(clientIdx, false, 0.0);
		int child1 = MM_CreateRocket(clientIdx, true, 0.1);
		int child2 = MM_CreateRocket(clientIdx, true, 0.2);
		
		for (int pass = 0; pass < 3; pass++)
		{
			int projectile = (pass == 0 ? parent : (pass == 1 ? child1 : child2));
			
			// create parent-child relationships
			for (int i = 0; i < MM_MaxProjectiles[clientIdx]; i++)
			{
				if (MM_EntRefs[clientIdx][i] == 0)
				{
					MM_EntRefs[clientIdx][i] = EntIndexToEntRef(projectile);
					MM_ParentEntRef[clientIdx][i] = pass > 0 ? EntIndexToEntRef(parent) : 0;
					GetEntPropVector(projectile, Prop_Send, "m_vecOrigin", MM_SpawnPos[clientIdx][i]);
					MM_MarkedForDeath[clientIdx][i] = false;
					break;
				}
			}
			
			// create particle effects
			if (!IsEmptyString(MM_Particle))
				AttachParticle(projectile, MM_Particle);
		}
	}
}

/**
 * Party Cannon
 */
public Action MP_OnTakeDamage(int victim, int& attacker, int& inflictor, 
							float& damage, int& damagetype, int& weapon, 
							float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsLivingPlayer(attacker) || !MP_CanUse[attacker])
		return Plugin_Continue;
	
	for (int i = 0; i < MP_MaxProjectiles[attacker]; i++)
	{
		if (MP_EntRefs[attacker][i] == 0)
			continue;
	
		if (inflictor == EntRefToEntIndex(MP_EntRefs[attacker][i]))
		{
			damage = MA_ClassDamageModifier(damage, attacker, victim, MP_STRING);
			if (!IsLivingPlayer(victim))
			{
				damage *= 3.0;
				if (IsValidEntity(victim))
					MA_PlayHitSound(attacker, victim); // play hit sound on a sentry, since it's too much of a pain to determine destroyed or not
			}
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

public void MP_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (!IsLivingPlayer(attacker) || !MP_CanUse[attacker])
		return;

	if (victim >= 1 && victim < MAX_PLAYERS)
	{
		for (int i = 0; i < MP_MaxProjectiles[attacker]; i++)
		{
			if (MP_EntRefs[attacker][i] == 0)
				continue;

			if (inflictor == EntRefToEntIndex(MP_EntRefs[attacker][i]))
			{
				if (!IsLivingPlayer(victim))
					MA_PlayKillSound(attacker, victim);
				else
					MA_PlayHitSound(attacker, victim);
			}
		}
	}
}

public int MP_CreateRocket(int clientIdx)
{
	// create our rocket. no matter what, it's going to spawn, even if it ends up being out of map
	float damage = fixDamageForFF2(MP_Damage[clientIdx]);
	float speed = MP_Speed[clientIdx];
	
	int rocket = CreateEntityByName("tf_projectile_rocket");
	if (!IsValidEntity(rocket))
	{
		PrintToServer("[sarysamods7] Error: Invalid entity \"tf_projectile_rocket\". Won't spawn rocket. This is sarysa's fault.");
		return -1;
	}
	
	// get spawn position, angles, velocity
	static float spawnPos[3];
	MA_GetIdealProjectileSpawnPos(clientIdx, spawnPos);
	static float angles[3];
	GetClientEyeAngles(clientIdx, angles);
	static float velocity[3];
	GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(velocity, speed);
	
	// deploy!
	TeleportEntity(rocket, spawnPos, angles, velocity);
	SetEntProp(rocket, Prop_Send, "m_bCritical", false); // no random crits
	SetEntDataFloat(rocket, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, damage, true); // credit to voogru
	SetEntProp(rocket, Prop_Send, "m_nSkin", 1); // set skin to BLU team's
	SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", clientIdx);
	SetVariantInt(BossTeam);
	AcceptEntityInput(rocket, "TeamNum", -1, -1, 0);
	SetVariantInt(BossTeam);
	AcceptEntityInput(rocket, "SetTeam", -1, -1, 0); 
	DispatchSpawn(rocket);
	
	// reskin after spawn
	if (MP_Model[clientIdx] != -1)
		SetEntProp(rocket, Prop_Send, "m_nModelIndex", MP_Model[clientIdx]);
		
	// play the firing sound
	if (strlen(MP_FireSound) > 3)
		PseudoAmbientSound(clientIdx, MP_FireSound, 1, 800.0);
	else
		MA_PlayFireSound(clientIdx);
	
	return rocket;
}

public void MP_DetonateRocket(int clientIdx, float rocketPos[3])
{
	// the only way to detonate the rocket in midair is to spawn another rocket that'll clip with it
	// causing both to explode
	
	int rocket = CreateEntityByName("tf_projectile_rocket");
	if (IsValidEntity(rocket))
	{	
		TeleportEntity(rocket, rocketPos, NULL_VECTOR, NULL_VECTOR);
		SetEntProp(rocket, Prop_Send, "m_bCritical", false); // no random crits
		SetEntDataFloat(rocket, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, 0.0, true); // credit to voogru
		SetEntProp(rocket, Prop_Send, "m_nSkin", 1); // set skin to BLU team's
		SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", clientIdx);
		SetVariantInt(BossTeam);
		AcceptEntityInput(rocket, "TeamNum", -1, -1, 0);
		SetVariantInt(BossTeam);
		AcceptEntityInput(rocket, "SetTeam", -1, -1, 0); 
		DispatchSpawn(rocket);
		CreateTimer(0.05, Timer_RemoveEntityTele, EntIndexToEntRef(rocket), TIMER_FLAG_NO_MAPCHANGE); // timers...UNCLEAN!!! though admittedly useful in this one hack fix.
	}
}

public void MP_Tick(int clientIdx, int buttons, float curTime)
{
	bool attackDown = (buttons & IN_ATTACK) != 0;
	bool shouldFire = attackDown & !MP_AttackDown[clientIdx];
	bool shouldRelease = !attackDown & MP_AttackDown[clientIdx];
	MP_AttackDown[clientIdx] = attackDown;
	if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed) || TF2_IsPlayerInCondition(clientIdx, TFCond_Taunting))
	{
		shouldFire = false;
		shouldRelease = true;
	}

	// verify the validity of existing projectiles, and count them
	int projectileCount = 0;
	for (int i = 0; i < MP_MaxProjectiles[clientIdx]; i++)
	{
		if (MP_EntRefs[clientIdx][i] == 0)
			continue;
		
		int projectile = EntRefToEntIndex(MP_EntRefs[clientIdx][i]);
		if (!IsValidEntity(projectile))
		{
			MP_EntRefs[clientIdx][i] = 0;
			continue;
		}
		
		// airblasted. it now belongs to a pyro.
		if ((GetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity") & 0xff) != clientIdx)
		{
			MP_EntRefs[clientIdx][i] = 0;
			continue;
		}

		if (curTime >= MP_DestroyAt[clientIdx][i])
		{
			// NOTE: keeping it in the loop in case it hits something in the explosion
			// next frame it'll be removed from the array, being invalid and all.
			static float rocketPos[3];
			GetEntPropVector(projectile, Prop_Send, "m_vecOrigin", rocketPos);
			MP_DetonateRocket(clientIdx, rocketPos);
		}
		
		projectileCount++;
	}
	
	// check auto-detonation
	if (curTime >= MP_CheckAutoDetonationAt[clientIdx])
	{
		if (projectileCount > 0)
		{
			float rangeCheck = MP_AutoDetonationDistance[clientIdx] * MP_AutoDetonationDistance[clientIdx];
			for (int i = 0; i < MP_MaxProjectiles[clientIdx]; i++)
			{
				if (MP_EntRefs[clientIdx][i] == 0)
					continue;
				else if (MP_PendingRelease[clientIdx][i])
					continue; // don't auto-detonate until projectile is flying upwards

				int projectile = EntRefToEntIndex(MP_EntRefs[clientIdx][i]);
				if (!IsValidEntity(projectile))
					continue;
			
				bool isDead = false;
				static float projectilePos[3];
				GetEntPropVector(projectile, Prop_Send, "m_vecOrigin", projectilePos);
				for (int victim = 1; victim < MAX_PLAYERS; victim++)
				{
					if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
						continue;
					
					static float victimPos[3];
					GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
					if (GetVectorDistance(victimPos, projectilePos, true) <= rangeCheck) // kablooie!
					{
						MP_DetonateRocket(clientIdx, projectilePos);
						isDead = true;
						break;
					}
				}
				
				// now we need to check for buildings
				for (int pass = 0; pass < 3; pass++)
				{
					if (isDead)
						break;
					
					static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
					if (pass == 0) classname = "obj_sentrygun";
					else if (pass == 1) classname = "obj_dispenser";
					else if (pass == 2) classname = "obj_teleporter";
					
					int building = -1;
					while ((building = FindEntityByClassname(building, classname)) != -1)
					{
						static float buildingPos[3];
						GetEntPropVector(building, Prop_Send, "m_vecOrigin", buildingPos);
						if (GetVectorDistance(buildingPos, projectilePos, true) <= rangeCheck) // kablooie!
						{
							MP_DetonateRocket(clientIdx, projectilePos);
							isDead = true;
							break;
						}
					}
				}
			}
		}
		
		MP_CheckAutoDetonationAt[clientIdx] = curTime + MP_AUTO_DETONATION_INTERVAL;
	}
	
	if (shouldRelease && projectileCount > 0)
	{
		for (int i = 0; i < MP_MaxProjectiles[clientIdx]; i++)
		{
			if (MP_EntRefs[clientIdx][i] == 0 || !MP_PendingRelease[clientIdx][i])
				continue;
			
			int projectile = EntRefToEntIndex(MP_EntRefs[clientIdx][i]);
			if (!IsValidEntity(projectile))
				continue;
				
			MP_PendingRelease[clientIdx][i] = false;
			static float angles[3] = {-89.9,0.0,0.0};
			static float velocity[3];
			GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(velocity, MP_Speed[clientIdx]);
			TeleportEntity(projectile, NULL_VECTOR, angles, velocity);
		}
	}

	if (!MA_AmIActive(clientIdx, MP_STRING))
		return;
	
	if (projectileCount >= MP_MaxProjectiles[clientIdx])
		shouldFire = false;
		
	if (shouldFire && MA_ConsumeEnergy(clientIdx))
	{
		int projectile = MP_CreateRocket(clientIdx);
		
		for (int i = 0; i < MP_MaxProjectiles[clientIdx]; i++)
		{
			if (MP_EntRefs[clientIdx][i] == 0)
			{
				MP_EntRefs[clientIdx][i] = EntIndexToEntRef(projectile);
				MP_PendingRelease[clientIdx][i] = true; // when key is released, balloon shoots up
				MP_DestroyAt[clientIdx][i] = curTime + MP_Lifetime[clientIdx];
				break;
			}
		}
	}
}

/**
 * Apple Bucker
 */
public Action MAB_OnTakeDamage(int victim, int& attacker, int& inflictor, 
							float& damage, int& damagetype, int& weapon, 
							float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsLivingPlayer(attacker) || !MAB_CanUse[attacker])
		return Plugin_Continue;
		
	for (int i = 0; i < MAB_MaxProjectiles[attacker]; i++)
	{
		if (MAB_EntRefs[attacker][i] == 0)
			continue;

		if (inflictor == EntRefToEntIndex(MAB_EntRefs[attacker][i]))
		{
			damage = MA_ClassDamageModifier(damage, attacker, victim, MAB_STRING);
			if (!IsLivingPlayer(victim))
			{
				damage *= 3.0;
				if (IsValidEntity(victim))
					MA_PlayHitSound(attacker, victim); // play hit sound on a sentry, since it's too much of a pain to determine destroyed or not
			}
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

public void MAB_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (!IsLivingPlayer(attacker) || !MAB_CanUse[attacker])
		return;

	if (victim >= 1 && victim < MAX_PLAYERS)
	{
		for (int i = 0; i < MAB_MaxProjectiles[attacker]; i++)
		{
			if (MAB_EntRefs[attacker][i] == 0)
				continue;

			if (inflictor == EntRefToEntIndex(MAB_EntRefs[attacker][i]))
			{
				if (!IsLivingPlayer(victim))
					MA_PlayKillSound(attacker, victim);
				else
					MA_PlayHitSound(attacker, victim);
			}
		}
	}
}

public int MAB_CreateApple(int clientIdx)
{
	float speed = MAB_Speed[clientIdx];
	float damage = fixDamageForFF2(MAB_Damage[clientIdx]);
	char entname[MAX_ENTITY_CLASSNAME_LENGTH] = "tf_projectile_pipe";
	
	int projectileEntity = CreateEntityByName(entname);
	
	if (!IsValidEntity(projectileEntity))
	{
		PrintToServer("[projectile_turret] Error: Invalid entity %s. Won't spawn projectile.", entname);
		return -1;
	}
	
	static float angles[3];
	GetClientEyeAngles(clientIdx, angles);
	static float velocity[3];
	GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(velocity, speed);
	
	// give grenades an extra 75, cause without this they'll hit nothing...
	velocity[2] += 75.0;
	
	// grenades have to be moved AFTER they spawn into the world, here's why.
	// CPhysicsCannister::CannisterActivate in the TF2 code
	// properties of all physics cannisters (i.e. grenade, loose cannon, etc) are determined after spawn
	// and are somewhat linked to some weapon. since this grenade's being spawned on the fly and has no weapon
	// it just chooses the default physics cannister (grenade) but with no weapon with properties to draw from
	// the projectile's velocity defaults to 0.
	if (MAB_IsLooseCannon[clientIdx])
		SetEntProp(projectileEntity, Prop_Send, "m_iType", 3); // type 0 is grenade, type 3 is loose cannon. 1 is probably sticky and 2 is probably scottish resistance.
	
	//PrintToServer("spawning projectile. pos=%f,%f,%f  angles=%f,%f,%f  velocity=%f,%f,%f", vPosition[0], vPosition[1], vPosition[2], vAngles[0], vAngles[1], vAngles[2], vVelocity[0], vVelocity[1], vVelocity[2]);
	
	SetEntProp(projectileEntity, Prop_Send, "m_bCritical", false); // I have no idea if this overrides random crits. I hope it does. (later note: it appears to)

	// luckily, grenades have a simple convenient netprop to set for damage...unlike rockets and arrows...
	SetEntPropFloat(projectileEntity, Prop_Send, "m_flDamage", damage);
	
	SetEntProp(projectileEntity, Prop_Send, "m_nSkin", 1); // set skin to blue team's
	SetEntPropEnt(projectileEntity, Prop_Send, "m_hOwnerEntity", clientIdx);
	SetVariantInt(BossTeam);
	AcceptEntityInput(projectileEntity, "TeamNum", -1, -1, 0);
	SetVariantInt(BossTeam);
	AcceptEntityInput(projectileEntity, "SetTeam", -1, -1, 0); 
	
	DispatchSpawn(projectileEntity);
	
	// must reskin after spawn
	if (MAB_Model[clientIdx] != -1)
		SetEntProp(projectileEntity, Prop_Send, "m_nModelIndex", MAB_Model[clientIdx]);
	
	// grenade must be moved after it spawns
	static float spawnPos[3];
	MA_GetIdealProjectileSpawnPos(clientIdx, spawnPos);
	TeleportEntity(projectileEntity, spawnPos, angles, velocity);
	
	// play the firing sound
	MA_PlayFireSound(clientIdx);
	
	return projectileEntity;
}
 
public void MAB_Tick(int clientIdx, int buttons, float curTime)
{
	bool attackDown = (buttons & IN_ATTACK) != 0;
	bool shouldFire = attackDown & !MAB_AttackDown[clientIdx];
	MAB_AttackDown[clientIdx] = attackDown;
	if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed) || TF2_IsPlayerInCondition(clientIdx, TFCond_Taunting))
		shouldFire = false;
	
	// verify the validity of existing projectiles, and count them
	int projectileCount = 0;
	for (int i = 0; i < MAB_MaxProjectiles[clientIdx]; i++)
	{
		if (MAB_EntRefs[clientIdx][i] == 0)
			continue;
		
		int projectile = EntRefToEntIndex(MAB_EntRefs[clientIdx][i]);
		if (!IsValidEntity(projectile))
		{
			MAB_EntRefs[clientIdx][i] = 0;
			continue;
		}
		
		// airblasted. it now belongs to a pyro.
		if ((GetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity") & 0xff) != clientIdx)
		{
			MAB_EntRefs[clientIdx][i] = 0;
			continue;
		}
		
		projectileCount++;
	}

	if (!MA_AmIActive(clientIdx, MAB_STRING))
		return;
	
	if (projectileCount >= MAB_MaxProjectiles[clientIdx])
		shouldFire = false;
	
	if (shouldFire && MA_ConsumeEnergy(clientIdx))
	{
		int projectile = MAB_CreateApple(clientIdx);
		if (IsValidEntity(projectile))
		{
			for (int i = 0; i < MAB_MaxProjectiles[clientIdx]; i++)
			{
				if (MAB_EntRefs[clientIdx][i] == 0)
				{
					MAB_EntRefs[clientIdx][i] = EntIndexToEntRef(projectile);
					break;
				}
			}
		}
	}
}

/**
 * OnPlayerRunCmd/OnGameFrame
 */
#define IMPERFECT_FLIGHT_FACTOR 25
public void OnGameFrame()
{
	if (!PluginActiveThisRound || !RoundInProgress)
		return;
		
	float curTime = GetEngineTime();

	if (DE_ActiveThisRound)
	{
		DE_Tick(curTime);
	}
	
	if (RR_ActiveThisRound)
	{
		RR_Tick(curTime);
	}

	if (DK_ActiveThisRound)
	{
		DK_Tick(curTime);
	}
	
	if (SAC_ActiveThisRound)
	{
		SAC_HighResTick(curTime);
	}
}
 
public Action OnPlayerRunCmd(int clientIdx, int &buttons, int &impulse, 
							float vel[3], float angles[3], int &weapon, 
							int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!PluginActiveThisRound || !RoundInProgress)
		return Plugin_Continue;
	else if (!IsLivingPlayer(clientIdx))
		return Plugin_Continue;
		
	if (DE_ActiveThisRound && DE_CanUse[clientIdx])
	{
		float curTime = GetEngineTime();
	
		// update the hud
		if (curTime >= DE_NextHUDAt[clientIdx])
		{
			SetHudTextParams(-1.0, DE_HUD_POSITION, DE_HUD_REFRESH_INTERVAL + 0.05, 64, 255, 64, 192);
			ShowHudText(clientIdx, -1, DE_HudMessage);
			DE_NextHUDAt[clientIdx] = curTime + DE_HUD_REFRESH_INTERVAL;
		}
	}
	
	if (SN_ActiveThisRound && SN_CanUse[clientIdx])
	{
		SN_Tick(clientIdx, buttons, GetEngineTime());
	}

	if (MB_ActiveThisRound && MB_CanUse[clientIdx])
	{
		MB_Tick(clientIdx, buttons, GetEngineTime());

		if (MA_ActiveThisRound && MA_CanUse[clientIdx])
		{
			MA_Tick(clientIdx, buttons, GetEngineTime());
		}

		if (MS_ActiveThisRound && MS_CanUse[clientIdx])
		{
			MS_Tick(clientIdx, buttons, GetEngineTime());
		}

		if (MR_ActiveThisRound && MR_CanUse[clientIdx])
		{
			MR_Tick(clientIdx, buttons, GetEngineTime());
		}

		if (MG_ActiveThisRound && MG_CanUse[clientIdx])
		{
			MG_Tick(clientIdx, buttons, GetEngineTime());
		}

		if (MM_ActiveThisRound && MM_CanUse[clientIdx])
		{
			MM_Tick(clientIdx, buttons, GetEngineTime());
		}

		if (MP_ActiveThisRound && MP_CanUse[clientIdx])
		{
			MP_Tick(clientIdx, buttons, GetEngineTime());
		}

		if (MAB_ActiveThisRound && MAB_CanUse[clientIdx])
		{
			MAB_Tick(clientIdx, buttons, GetEngineTime());
		}
	}
	
	return Plugin_Continue;
}

/**
 * General helper stocks, some original, some taken/modified from other sources
 */
stock void PlaySoundLocal(int clientIdx, char[] soundPath, bool followPlayer = true, int stack = 1)
{
	// play a speech sound that travels normally, local from the player.
	static float playerPos[3];
	GetClientEyePosition(clientIdx, playerPos);
	//PrintToServer("[sarysamods7] eye pos=%f,%f,%f     sound=%s", playerPos[0], playerPos[1], playerPos[2], soundPath);
	for (int i = 0; i < stack; i++)
		EmitAmbientSound(soundPath, playerPos, followPlayer ? clientIdx : SOUND_FROM_WORLD);
}

stock int ParticleEffectAt(float position[3], char[] effectName, float duration = 0.1)
{
	if (IsEmptyString(effectName))
		return -1; // nothing to display
		
	int particle = CreateEntityByName("info_particle_system");
	if (particle != -1)
	{
		TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "effect_name", effectName);
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		if (duration > 0.0)
			CreateTimer(duration, Timer_RemoveEntityTele, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
	}
	return particle;
}

stock int AttachParticle(int entity, const char[] particleType, float offset=0.0, bool attach=true)
{
	int particle = CreateEntityByName("info_particle_system");
	
	if (!IsValidEntity(particle))
		return -1;

	static char targetName[128];
	static float position[3];
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
stock int AttachParticleToAttachment(int entity, const char[] particleType, const char[] attachmentPoint) // m_vecAbsOrigin. you're welcome.
{
	int particle = CreateEntityByName("info_particle_system");
	
	if (!IsValidEntity(particle))
		return -1;

	static char targetName[128];
	static float position[3];
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

public Action Timer_RemoveEntityTele(Handle timer, any entid)
{
	int entity = EntRefToEntIndex(entid);
	if (IsValidEntity(entity))
		RemoveEntity(entity);
}

public void RemoveEntityTele(int entid)
{
	int entity = EntRefToEntIndex(entid);
	if (IsValidEntity(entity))
		RemoveEntity(entity);
}

stock bool IsLivingPlayer(int clientIdx)
{
	if (clientIdx <= 0 || clientIdx >= MAX_PLAYERS)
		return false;
		
	return IsClientInGame(clientIdx) && IsPlayerAlive(clientIdx);
}

stock bool IsValidBoss(int clientIdx)
{
	if (!IsLivingPlayer(clientIdx))
		return false;
		
	return GetClientTeam(clientIdx) == BossTeam;
}

stock bool IsPlayerInRange(int player, float position[3], float maxDistance)
{
	maxDistance *= maxDistance;
	
	static float playerPos[3];
	GetEntPropVector(player, Prop_Data, "m_vecOrigin", playerPos);
	return GetVectorDistance(position, playerPos, true) <= maxDistance;
}

stock int FindRandomPlayer(bool isBossTeam, float position[3] = NULL_VECTOR, float maxDistance = 0.0, bool anyTeam = false)
{
	int player = -1;

	// first, get a player count for the team we care about
	int playerCount = 0;
	for (int clientIdx = 0; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!IsLivingPlayer(clientIdx))
			continue;
			
		if (maxDistance > 0.0 && !IsPlayerInRange(clientIdx, position, maxDistance))
			continue;

		if ((isBossTeam && GetClientTeam(clientIdx) == BossTeam) || (!isBossTeam && GetClientTeam(clientIdx) != BossTeam) || anyTeam)
			playerCount++;
	}

	// ensure there's at least one living valid player
	if (playerCount <= 0)
		return -1;

	// now randomly choose our victim
	int rand = GetRandomInt(0, playerCount - 1);
	playerCount = 0;
	for (int clientIdx = 0; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!IsLivingPlayer(clientIdx))
			continue;

		if (maxDistance > 0.0 && !IsPlayerInRange(clientIdx, position, maxDistance))
			continue;
			
		if ((isBossTeam && GetClientTeam(clientIdx) == BossTeam) || (!isBossTeam && GetClientTeam(clientIdx) != BossTeam) || anyTeam)
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

stock bool CheckLineOfSight(float position[3], int targetEntity, float zOffset)
{
	static float targetPos[3];
	GetEntPropVector(targetEntity, Prop_Send, "m_vecOrigin", targetPos);
	targetPos[2] += zOffset;
	static float angles[3];
	GetVectorAnglesTwoPoints(position, targetPos, angles);
	
	Handle trace = TR_TraceRayFilterEx(position, angles, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
	static float endPos[3];
	TR_GetEndPosition(endPos, trace);
	CloseHandle(trace);
	
	return GetVectorDistance(position, targetPos, true) <= GetVectorDistance(position, endPos, true);
}

stock void ReadSound(int bossIdx, const char[] ability_name, int argInt, char[] soundFile)
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, soundFile, MAX_SOUND_FILE_LENGTH);
	if (strlen(soundFile) > 3)
		PrecacheSound(soundFile);
}

stock void ReadModel(int bossIdx, const char[] ability_name, int argInt, char[] modelFile)
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, modelFile, MAX_MODEL_FILE_LENGTH);
	if (strlen(modelFile) > 3)
		PrecacheModel(modelFile);
}

stock int  ReadModelToInt(int bossIdx, const char[] ability_name, int argInt)
{
	static char modelFile[MAX_MODEL_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, modelFile, MAX_MODEL_FILE_LENGTH);
	if (strlen(modelFile) > 3)
		return PrecacheModel(modelFile);
	return -1;
}

stock void ReadCenterText(int bossIdx, const char[] ability_name, int argInt, char[] centerText)
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, centerText, MAX_CENTER_TEXT_LENGTH);
	ReplaceString(centerText, MAX_CENTER_TEXT_LENGTH, "\\n", "\n");
}

public bool TraceWallsOnly(int entity, int contentsMask)
{
	return false;
}

stock float fixAngle(float angle)
{
	int sanity = 0;
	while (angle < -180.0 && (sanity++) <= 10)
		angle = angle + 360.0;
	while (angle > 180.0 && (sanity++) <= 10)
		angle = angle - 360.0;
		
	return angle;
}

// really wish that the original GetVectorAngles() worked this way.
stock float GetVectorAnglesTwoPoints(const float startPos[3], const float endPos[3], float angles[3])
{
	static float tmpVec[3];
	MakeVectorFromPoints(endPos, startPos, tmpVec);
	GetVectorAngles(tmpVec, angles);
}

stock float fixDamageForFF2(float damage)
{
	if (damage <= 160.0)
		return damage / 3.0;
	return damage;
}

stock void FullyHookedDamage(int victim, int inflictor, int attacker, float damage, int damageType=DMG_GENERIC, int weapon=-1)
{
	char dmgStr[16];
	IntToString(RoundFloat(damage), dmgStr, sizeof(dmgStr));

	// took this from war3...I hope it doesn't double damage like I've heard old versions do
	int pointHurt = CreateEntityByName("point_hurt");
	if (IsValidEntity(pointHurt))
	{
		DispatchKeyValue(victim, "targetname", "halevictim");
		DispatchKeyValue(pointHurt, "DamageTarget", "halevictim");
		DispatchKeyValue(pointHurt, "Damage", dmgStr);
		DispatchKeyValueFormat(pointHurt, "DamageType", "%d", damageType);

		DispatchSpawn(pointHurt);
		if (IsLivingPlayer(attacker))
		{
			static float attackerOrigin[3];
			GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", attackerOrigin);
			TeleportEntity(pointHurt, attackerOrigin, NULL_VECTOR, NULL_VECTOR);
		}
		AcceptEntityInput(pointHurt, "Hurt", attacker);
		DispatchKeyValue(pointHurt, "classname", "point_hurt");
		DispatchKeyValue(victim, "targetname", "noonespecial");
		RemoveEntityTele(EntIndexToEntRef(pointHurt));
	}
}

// this version ignores obstacles
stock void PseudoAmbientSound(int clientIdx, char[] soundPath, int count=1, float radius=1000.0, bool skipSelf=false, bool skipDead=false, float volumeFactor=1.0)
{
	static float emitterPos[3];
	static float listenerPos[3];
	if (!IsLivingPlayer(clientIdx)) // updated 2015-01-16 to allow non-players...finally.
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", emitterPos);
	else
		GetClientEyePosition(clientIdx, emitterPos);
	for (int listener = 1; listener < MAX_PLAYERS; listener++)
	{
		if (!IsClientInGame(listener))
			continue;
		else if (skipSelf && listener == clientIdx)
			continue;
		else if (skipDead && !IsLivingPlayer(listener))
			continue;
			
		// knowing virtually nothing about sound engineering, I'm kind of BSing this here...
		// but I'm pretty sure decibal dropoff is best done logarithmically.
		// so I'm doing that here.
		GetClientEyePosition(listener, listenerPos);
		float distance = GetVectorDistance(emitterPos, listenerPos);
		if (distance >= radius)
			continue;
		
		float logMe = (radius - distance) / (radius / 10.0);
		if (logMe <= 0.0) // just a precaution, since EVERYTHING tosses an exception in this game
			continue;
			
		float volume = Logarithm(logMe) * volumeFactor;
		if (volume <= 0.0)
			continue;
		else if (volume > 1.0)
		{
			PrintToServer("[sarysamods7] How the hell is volume greater than 1.0?");
			volume = 1.0;
		}
		
		for (int i = 0; i < count; i++)
			EmitSoundToClient(listener, soundPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume);
	}
}

stock float fabs(float x)
{
	return x < 0 ? -x : x;
}

stock int min(int n1, int n2)
{
	return n1 < n2 ? n1 : n2;
}

stock float fmin(float n1, float n2)
{
	return n1 < n2 ? n1 : n2;
}

stock float fmax(float n1, float n2)
{
	return n1 > n2 ? n1 : n2;
}

stock int ReadHexOrDecInt(char[] hexOrDecString)
{
	if (StrContains(hexOrDecString, "0x") == 0)
	{
		int result = 0;
		for (int i = 2; i < 10 && hexOrDecString[i] != 0; i++)
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

stock int ReadHexOrDecString(int bossIdx, const char[] ability_name, int argIdx)
{
	static char hexOrDecString[HEX_OR_DEC_STRING_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argIdx, hexOrDecString, HEX_OR_DEC_STRING_LENGTH);
	return ReadHexOrDecInt(hexOrDecString);
}

stock float ConformAxisValue(float src, float dst, float distCorrectionFactor)
{
	return src - ((src - dst) * distCorrectionFactor);
}

stock void ConformLineDistance(float result[3], const float src[3], const float dst[3], float maxDistance, bool canExtend = false)
{
	float distance = GetVectorDistance(src, dst);
	if (distance <= maxDistance && !canExtend)
	{
		// everything's okay.
		result[0] = dst[0];
		result[1] = dst[1];
		result[2] = dst[2];
	}
	else
	{
		// need to find a point at roughly maxdistance. (FP irregularities aside)
		float distCorrectionFactor = maxDistance / distance;
		result[0] = ConformAxisValue(src[0], dst[0], distCorrectionFactor);
		result[1] = ConformAxisValue(src[1], dst[1], distCorrectionFactor);
		result[2] = ConformAxisValue(src[2], dst[2], distCorrectionFactor);
	}
}

stock bool CylinderCollision(float cylinderOrigin[3], float colliderOrigin[3], float maxDistance, float zMin, float zMax)
{
	if (colliderOrigin[2] < zMin || colliderOrigin[2] > zMax)
		return false;

	static float tmpVec1[3];
	tmpVec1[0] = cylinderOrigin[0];
	tmpVec1[1] = cylinderOrigin[1];
	tmpVec1[2] = 0.0;
	static float tmpVec2[3];
	tmpVec2[0] = colliderOrigin[0];
	tmpVec2[1] = colliderOrigin[1];
	tmpVec2[2] = 0.0;
	
	return GetVectorDistance(tmpVec1, tmpVec2, true) <= maxDistance * maxDistance;
}

stock float getLinearVelocity(float vecVelocity[3])
{
	return SquareRoot((vecVelocity[0] * vecVelocity[0]) + (vecVelocity[1] * vecVelocity[1]) + (vecVelocity[2] * vecVelocity[2]));
}

// stole this stock from KissLick. it's a good stock!
stock void DispatchKeyValueFormat(int entity, const char[] keyName, const char[] format, any ...)
{
	static char value[256];
	VFormat(value, sizeof(value), format, 4);

	DispatchKeyValue(entity, keyName, value);
} 

stock bool PlayerIsInvincible(int clientIdx)
{
	return TF2_IsPlayerInCondition(clientIdx, TFCond_Ubercharged) ||
		TF2_IsPlayerInCondition(clientIdx, TFCond_UberchargedHidden) ||
		TF2_IsPlayerInCondition(clientIdx, TFCond_UberchargedCanteen) ||
		TF2_IsPlayerInCondition(clientIdx, TFCond_UberchargedOnTakeDamage) ||
		TF2_IsPlayerInCondition(clientIdx, TFCond_Bonked);
}

/**
 * TAKEN DIRECTLY FROM Roll the Dice MOD
 * I claim no credit.
 */
stock void ColorizePlayer(int client, const int iColor[4])
{
	SetEntityColor(client, iColor);
	
	for(int i=0; i<3; i++)
	{
		int iWeapon = GetPlayerWeaponSlot(client, i);
		if(iWeapon > MaxClients && IsValidEntity(iWeapon))
		{
			SetEntityColor(iWeapon, iColor);
		}
	}
	
	static char strClass[64];
	int next = MaxClients + 1;
	
	while((next = FindEntityByClassname(next, "tf_wearable*")) != -1 || (next = FindEntityByClassname(next, "tf_powerup*")) != -1) {
		GetEntityClassname(next, strClass, sizeof(strClass));
		if(!strncmp(strClass, "tf_powerup", 10) && GetEntPropEnt(next, Prop_Send, "m_hOwnerEntity") != client)
			continue;
		SetEntityColor(next, iColor);
	}
	//01Pollux : why would you even loop through all server entities just to check their classname then color them... 
	
	int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hDisguiseWeapon");
	if(iWeapon > MaxClients && IsValidEntity(iWeapon))
	{
		SetEntityColor(iWeapon, iColor);
	}
}

stock void SetEntityColor(int iEntity, const iColor[4])
{
	SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iEntity, iColor[0], iColor[1], iColor[2], iColor[3]);
}

/**
 * DO NOT COPY THE ABOVE METHODS TO PACK 8!
 */
