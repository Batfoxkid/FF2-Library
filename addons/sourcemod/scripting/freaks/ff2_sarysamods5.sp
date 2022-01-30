// no warranty blah blah don't sue blah blah doing this for fun blah blah...

#define FF2_USING_AUTO_PLUGIN__OLD

#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>
#include <ff2_dynamic_defaults>

#pragma semicolon 1
#pragma newdecls required

/**
 * My fifth VSP rage pack, rages for Daring Do. It's so massive because of the rope which is a super jump replacement.
 *
 * FF2Rope: A replacement for Super Jump which shoots out a rope. It can connect to the skybox since the player would
 *	    have accessibility issues if it couldn't.
 * Known Issues: To keep the data size low, stuff like materials, models, and error messages are shared in a multi-boss setup.
 *		 However, gameplay features like rage cost and reel in speed are not affected. It's purely for data-heavy stuff
 *		 (i.e. strings) one wouldn't expect a multi-boss to differ in.
 *		 Tiny obstructions like the narrow bridge  with the healthpack in Crevice may sometimes not cause the rope to
 *		 snap when crossed under. Unavoidable as it would require very expensive calculations which would often be in
 *		 error.
 *		 If the boss doesn't have glow enabled, the "rope" shortly disappears after being created. I hit my limit
 *		 trying to fix this and ended up going with the hack-fix, because there is no freaking reason it should
 *		 be disappearing the way it does. (and reappearing while the hale is glowing? SERIOUSLY?!)
 *		 Rope disappears for user in first person view. Third person and other players see it fine. (related to above issue)
 * Credits: KissLick - based my env_beam code off https://forums.alliedmods.net/showthread.php?t=249891
 *
 * EventSapphireStone: Spawns a sapphire stone into the world at a given interval. Typically goes to the control point, but falls
 *		       back to a random powerup spot and finally BLU spawn. Can be used by RED or BLU, though requires more REDs
 *		       to function. Triggers...stuff. It's a very specific rage for Daring Do, but could be applied to a non-ponified counterpart.
 * Known Issues: By design, only one boss can have this rage in a multi-boss setup. It'd make no sense to allow multiple for many reasons.
 * Credits: RTD beacon, which I directly ripped since it's a familiar style of beacon.
 *          War3 for the point hurt, as there was one instance I had to hurt the hale and have it stick.
 *
 * HookshotWeighdown: A direct copy of FF2's weighdown, which won't operate while the hook is out.
 * Credits: The FF2 team made the thing. I just needed to rip it off so I could regulate it better.
 *
 * ElementalTotems: Summons various user-selected support/damage totems.
 * Known Issues: Do not include uber with ice totem with a boss that can get uber from some other means. It will cause issues.
 *		 Players remain slow after round ends if the boss dies while victim is in ice totem space. Round change fixes it.
 */

 
#define ARG_LENGTH 256
 
bool PRINT_DEBUG_INFO = true;
bool PRINT_DEBUG_SPAM = false;

#define NOPE_AVI "vo/engineer_no01.mp3" // DO NOT DELETE FROM FUTURE PACKS

// text string limits
#define MAX_SOUND_FILE_LENGTH 80
#define MAX_MODEL_FILE_LENGTH 128
#define MAX_MATERIAL_FILE_LENGTH 128
#define MAX_EFFECT_NAME_LENGTH 48
#define MAX_ENTITY_CLASSNAME_LENGTH 48
#define MAX_CENTER_TEXT_LENGTH 128
#define MAX_HULL_STRING_LENGTH 197
#define MAX_ATTACHMENT_NAME_LENGTH 48
#define COLOR_BUFFER_SIZE 12
#define HEX_OR_DEC_STRING_LENGTH 12 // max -2 billion is 11 chars + null termination

#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

int BossTeam = view_as<int>(TFTeam_Blue);

int RoundInProgress = false;
bool PluginActiveThisRound = false;

public Plugin myinfo = {
	name = "Freak Fortress 2: sarysa's mods, fifth pack",
	author = "sarysa",
	version = "1.1.1",
}

#define FAR_FUTURE 100000000.0
#define IsEmptyString(%1) (%1[0] == 0)

/**
 * Hookshot
 */
#define HS_STRING "ff2_rope"
#define HS_MIN_LENGTH 20.0 // hammer units, minimum length of hookshot relative to eye level
#define HS_CHECK_INTERVAL 0.05
#define HS_LIMP_MIN_DISTANCE 100.0 // if the player is this many HU closer to the hook than they should be, the rope is limp, and does not affect their motion
#define HS_ROPE_TOP_DISCREPANCY_ALLOWANCE 50.0 // HU of allowed discrepancy in any axis for the end points of the rope (prevents oddities in the ceiling from snapping the rope)
#define HS_DEFAULT_ELASTIC_INTENSITY 900.0
#define HS_ELASTIC_BASE_DISTANCE 100.0
#define HS_HUD_TEXT_LENGTH (MAX_CENTER_TEXT_LENGTH*2)
#define HS_FLAG_COOLDOWN_ON_UNHOOK 0x0001
#define HS_FLAG_GLOW_HACK 0x0002
bool HS_ActiveThisRound = false; // internal
bool HS_CanUse[MAX_PLAYERS_ARRAY]; // internal
float HS_LastUpdateAt[MAX_PLAYERS_ARRAY]; // internal
bool HS_AltFireDown[MAX_PLAYERS_ARRAY]; // internal
bool HS_DuckKeyDown[MAX_PLAYERS_ARRAY]; // internal
bool HS_JumpKeyDown[MAX_PLAYERS_ARRAY]; // internal
bool HS_HookshotOut[MAX_PLAYERS_ARRAY]; // internal
float HS_HookshotReelDistance[MAX_PLAYERS_ARRAY]; // internal
int HS_HUDErrorIdx[MAX_PLAYERS_ARRAY];
char HS_HUDText[MAX_PLAYERS_ARRAY][HS_HUD_TEXT_LENGTH]; // internal, yeah this is about 10k data usage. ouch.
float HS_HudRefreshAt[MAX_PLAYERS_ARRAY]; // internal
float HS_HudErrorClearAt[MAX_PLAYERS_ARRAY]; // internal
float HS_HookPosition[MAX_PLAYERS_ARRAY][3]; // internal, position of the hook when it's out
float HS_LastCheckAt[MAX_PLAYERS_ARRAY]; // internal, we won't adjust player motion on every tick
float HS_HookshotFiredAt[MAX_PLAYERS_ARRAY]; // internal
float HS_UsableAt[MAX_PLAYERS_ARRAY]; // internal (cooldown related)
int HS_HookEntRef[MAX_PLAYERS_ARRAY]; // internal
int HS_BeamEntRef[MAX_PLAYERS_ARRAY][2]; // internal
float HS_ReelInSpeed[MAX_PLAYERS_ARRAY]; // arg1, speed of going up on rope
float HS_ReelOutSpeed[MAX_PLAYERS_ARRAY]; // arg2, speed of going down on rope
float HS_Cooldown[MAX_PLAYERS_ARRAY]; // arg3
float HS_RageCost[MAX_PLAYERS_ARRAY]; // arg4
float HS_MaxFiringAngle[MAX_PLAYERS_ARRAY]; // arg5
char HS_RopeTextureStr[MAX_MATERIAL_FILE_LENGTH]; // arg6, assumed both bosses in multi-boss would share this
char HS_HookModel[MAX_MODEL_FILE_LENGTH]; // arg7, assumed both bosses in multi-boss would share this
char HS_HookFiringSound[MAX_SOUND_FILE_LENGTH]; // arg8, assumed both bosses in multi-boss would share this
float HS_ElasticityModifier[MAX_PLAYERS_ARRAY]; // arg9
float HS_MaxSwingSpeed[MAX_PLAYERS_ARRAY]; // arg10
float HS_MaxSwingDuration[MAX_PLAYERS_ARRAY]; // arg11
float HS_NegativeZDegradationFactor[MAX_PLAYERS_ARRAY]; // arg12
float HS_HorizontalMotionFactor[MAX_PLAYERS_ARRAY]; // arg13
int HS_Flags[MAX_PLAYERS_ARRAY]; // arg19
// strings, all assumed to be shared by multi-bosses. also, don't want to balloon the data size.
#define HSS_STRING "rope_strings"
#define HS_ERROR_NONE 0
#define HS_ERROR_ROPE_SNAPPED 1
#define HS_ERROR_TIME_LIMIT 2
#define HS_ERROR_HIT_GROUND 3
#define HS_ERROR_STUNNED 4
#define HS_ERROR_ON_GROUND 5
#define HS_ERROR_BAD_ANGLE 6
#define HS_ERROR_INSUFFICIENT_RAGE 7
#define HS_ERROR_WEIGHDOWN_ACTIVE 8
char HS_RopeSnappedStr[MAX_CENTER_TEXT_LENGTH]; // arg1
char HS_TimeLimitReachedStr[MAX_CENTER_TEXT_LENGTH]; // arg2
char HS_HitGroundOrWaterStr[MAX_CENTER_TEXT_LENGTH]; // arg3, 
char HS_InstructionHUDTemplate[MAX_CENTER_TEXT_LENGTH]; // arg4
char HS_InUseHUDTemplate[MAX_CENTER_TEXT_LENGTH]; // arg5
char HS_CooldownHUDTemplate[MAX_CENTER_TEXT_LENGTH]; // arg6
char HS_RageCostHUDTemplate[MAX_CENTER_TEXT_LENGTH]; // arg7
char HS_StunnedStr[MAX_CENTER_TEXT_LENGTH]; // arg8
char HS_OnGroundStr[MAX_CENTER_TEXT_LENGTH]; // arg9
char HS_BadAngleStr[MAX_CENTER_TEXT_LENGTH]; // arg10
char HS_NotEnoughRageStr[MAX_CENTER_TEXT_LENGTH]; // arg11
char HS_WeighdownActiveStr[MAX_CENTER_TEXT_LENGTH]; // arg12

/**
 * Sapphire Stone
 */
// sapphire stone. since this is typically an event, none of the args are in array form.
// it'd make no sense to have multiple of these in a single boss battle.
#define RSS_STRING "rage_sapphire_stone"
#define ESS_STRING "event_sapphire_stone"
#define SS_FLAG_BOSS_CAN_USE 0x000001 // yes this will virtually always be on
#define SS_FLAG_PLAYERS_CAN_USE 0x000002
#define SS_FLAG_ALL_LIVING_PLAYERS_CAN_USE 0x000004 // so if there's only 4 players living but 5 are required to use the stone, those 4 can still activate it
#define SS_FLAG_BEACON 0x000010
#define SS_FLAG_DROP_ROCKS 0x000100
#define SS_FLAG_DAMAGE_EARTHQUAKE 0x000200
#define SS_FLAG_EARTHQUAKE_HAS_PHYSICS 0x001000
#define SS_FLAG_ROCK_SOFT_STUN 0x010000
#define SS_FLAG_ROCK_HARD_STUN 0x020000 // stuns also affect the boss
#define SS_FLAG_SPAWN_ON_CP 0x100000 // not recommended if CP is cappable
#define SS_FLAG_SPAWN_ON_PICKUP 0x200000
bool SS_ActiveThisRound = false;
bool SS_IsRage; // depends on which string above was used for the ability
int SS_EntRef; // internal
float SS_ActivePosition[3]; // internal, since the statue doesn't move
float SS_NextSpawnAt; // internal
float SS_EventInterval; // arg1, only used for event version
char SS_MainModel[MAX_MODEL_FILE_LENGTH]; // arg2, model name for sapphire stone
float SS_StoneCollisionRadius; // arg3, radius for the stone
int SS_MinPlayersToUse; // arg4, only works if players can use
float SS_PlayersForStoneFactor; // arg5
float SS_RockDamage; // arg6, if drop rocks used, 
int SS_RockMax; // arg7, maximum number of rocks to drop on peoples' heads
float SS_RockKnockbackIntensity; // arg8, intensity of rock knockback.
char SS_RockModel[MAX_MODEL_FILE_LENGTH]; // arg9
float SS_RockAreaRect[2][3]; // arg10, area rect for the rocks
float SS_RockCollisionRect[2][3]; // arg10 child, collision rect for the rocks
float SS_RockStunDuration; // arg11
float SS_RockTimeToLive; // arg12
float SS_RockMinSpeedEffective; // arg13
float SS_QuakeDuration; // arg14
float SS_QuakeDamage; // arg15
float SS_BossDamageMultiplier; // arg16
int SS_Flags; // arg19

// second set of parameters, mostly aesthetics
//#define SSA_STRING "sapphire_stone_aesthetics" // I chose the word order carefully here
#define SSA_STRING "sapphire_stone2"
// strings
char SS_StrStoneAppeared[MAX_CENTER_TEXT_LENGTH]; // arg1
char SS_BossGotStone[MAX_CENTER_TEXT_LENGTH]; // arg2
char SS_PlayersGotStone[MAX_CENTER_TEXT_LENGTH]; // arg3
char SS_MercStoneDisplayStr[MAX_CENTER_TEXT_LENGTH]; // arg4
// sounds
char SS_RockHitSound[MAX_SOUND_FILE_LENGTH]; // arg7
char SS_QuakeSound[MAX_SOUND_FILE_LENGTH]; // arg8
char SS_BossGotStoneSound[MAX_SOUND_FILE_LENGTH]; // arg9
char SS_MercsGotStoneSound[MAX_SOUND_FILE_LENGTH]; // arg10
char SS_StoneSpawnSound[MAX_SOUND_FILE_LENGTH]; // arg10
// particles
char SS_RockHitParticle[MAX_EFFECT_NAME_LENGTH]; // arg13
char SS_QuakeParticle[MAX_EFFECT_NAME_LENGTH]; // arg14

// individual rocks
#define MAX_ROCKS 20
#define ROCK_COLLISION_INTERVAL 0.05
#define ROCK_FIRING_INTERVAL 0.5
#define ROCK_COLLISION_RECT_EXTENSION 20.0
#define ROCK_SPAWN_SAFETY_SPACE 25.0
#define ROCK_DEFAULT_VEL_INTENSITY 1000.0
#define ROCK_HEIGHT_CAP 1000.0
#define ROCK_FIRING_ANGLE_NEAR 45.0
#define ROCK_FIRING_ANGLE_FAR 80.0
int RockEntRef[MAX_ROCKS];
float RockSpawnedAt[MAX_ROCKS];
float RockCollisionCheckAt[MAX_ROCKS]; // I'm going simpler with this than I did with Maud's rocks and Thi's props
float RockLastPosition[MAX_ROCKS][3];
float RockLastCollisionCheckAt[MAX_ROCKS];
float RockNextSpawnAt;
int RocksPendingSpawn;
bool RocksAreBossTeam;

// safe spawning
#define SS_MAX_SPAWNS 50
int SS_SpawnLocationCount = 0;
float SS_Spawn[SS_MAX_SPAWNS][3];
#define SS_MAX_PICKUPS 4
char SS_Pickups[SS_MAX_PICKUPS][48] = { "item_ammopack_small", "item_healthkit_small", "item_healthkit_medium", "item_healthkit_large" };

// hud management
#define SS_HUD_POSITION 0.60
#define SS_HUD_CHECK_INTERVAL 0.10
#define SS_HUD_DURATION 5.0
#define SS_HUD_MSG_NONE 0
#define SS_HUD_MSG_APPEARED 1
#define SS_HUD_MSG_BOSS_FOUND 2
#define SS_HUD_MSG_MERCS_FOUND 3
#define SS_HUD_MSG_NUM_MERCS_ON_STONE 4
float SS_HUDNextCheck;
int SS_HUDMessageIdx = 0;
float SS_HUDMessageExpirationTime;
int SS_HUDNumMercs;
int SS_HUDMercsRequired;

// beacon
#define SS_BEACON_DELAY 1.0
#define SS_BEACON_SOUND "buttons/blip1.wav"
float SS_NextBeaconAt;
int BEACON_BEAM;
int BEACON_HALO;

/**
 * Elemental totems
 */
#define ET_STRING "rage_elemental_totem"
#define ET_HUD_POSITION 0.68
#define ET_HUD_CHECK_INTERVAL 0.10
#define ET_FIRE 0
#define ET_ICE 1
#define ET_WIND 2
#define ET_ELECTRIC 3
#define ET_TYPE_COUNT 4
bool ET_ActiveThisRound = false;
bool ET_CanUse[MAX_PLAYERS_ARRAY];
bool ET_ReloadDown[MAX_PLAYERS_ARRAY]; // internal
int ET_CurrentSelection[MAX_PLAYERS_ARRAY]; // internal, initialized as arg5
float ET_UpdateHUDAt[MAX_PLAYERS_ARRAY]; // internal
float ET_ExpectedSpeed[MAX_PLAYERS_ARRAY]; // internal, related to slowdown
bool ET_IsSpeedAdjusted[MAX_PLAYERS_ARRAY]; // internal
float ET_SpeedAdjust[MAX_PLAYERS_ARRAY]; // internal
float ET_RemoveAfterburnAt[MAX_PLAYERS_ARRAY]; // internal
bool ET_FireEnabled[MAX_PLAYERS_ARRAY]; // arg1
bool ET_IceEnabled[MAX_PLAYERS_ARRAY]; // arg2
bool ET_WindEnabled[MAX_PLAYERS_ARRAY]; // arg3
bool ET_ElectricEnabled[MAX_PLAYERS_ARRAY]; // arg4
// arg5 is not stored. it is the default totem, before RELOAD is pressed
// arg6-9 aren't stored, they're models for the totems
char ET_FireHUDStr[MAX_CENTER_TEXT_LENGTH]; // arg10
char ET_IceHUDStr[MAX_CENTER_TEXT_LENGTH]; // arg11
char ET_WindHUDStr[MAX_CENTER_TEXT_LENGTH]; // arg12
char ET_ElectricHUDStr[MAX_CENTER_TEXT_LENGTH]; // arg13
char ET_InstructionHUDStr[MAX_CENTER_TEXT_LENGTH]; // arg14

// pertaining to the fog controller
#define ET_FOG_TRANSITION_INTERVAL 0.025
#define ET_FOG_TRANSITION_TIME 1.0
#define ET_FOG_DEFAULT_COLOR 0x000000
float ET_FogExpiresAt; // when this happens, a detransition occurs.
float ET_FogLastCheckAt = 0.0;
float ET_FogTransitionElapsed = ET_FOG_TRANSITION_TIME;
float ET_FogCurrentDensity = 0.0;
float ET_FogStartingDensity = 0.0;
float ET_FogTargetDensity;
int ET_FogCurrentColor = ET_FOG_DEFAULT_COLOR;
int ET_FogStartingColor = ET_FOG_DEFAULT_COLOR;
int ET_FogTargetColor;

// fire totem
#define FET_STRING "fire_elemental_totem"
#define FET_HELLFIRE_RADIUS 350.0

// ice totem
#define IET_STRING "ice_elemental_totem"
#define IET_FLAG_UBER 0x0001

// wind totem
#define WET_STRING "wind_elemental_totem"
#define WET_KNOCK_UP_INTENSITY 2.5
#define WET_VORTEX_INTENSITY 3.0 //1.5
#define WET_MAX_HEIGHT 400.0
#define WET_MAX_VELOCITY 1150.0
#define WET_TORNADO_INTERVAL 0.05
#define WET_TORNADO_ANGLE 35.0
#define WET_TRAPPED_LIFT 1.2
#define WET_EXCESS_DISTANCE_RADIUS_FACTOR 1.1

// electric totem
#define EET_STRING "electric_elemental_totem"
#define EET_FLAG_DRAIN_SPIES 0x0001
#define EET_FLAG_SPEED_ON_MINOR_HIT 0x0002
int EET_BoltMaterial;

// active totems
#define MAX_TOTEMS 10
int Totem_Type[MAX_TOTEMS];
int Totem_EntRef[MAX_TOTEMS];
int Totem_Owner[MAX_TOTEMS];
float Totem_ExpiresAt[MAX_TOTEMS];
float Totem_VisualEffectRadius[MAX_TOTEMS];
float Totem_VisualEffectInterval[MAX_TOTEMS];
float Totem_VisualEffectDamage[MAX_TOTEMS];
char Totem_VisualEffectParticle[MAX_TOTEMS][MAX_EFFECT_NAME_LENGTH];
float Totem_DamageEffectRadius[MAX_TOTEMS];
float Totem_DamageEffectInterval[MAX_TOTEMS];
float Totem_DamageEffectDamage[MAX_TOTEMS];
float Totem_SkyDarkenPercent[MAX_TOTEMS];
char Totem_RepeatingSound[MAX_TOTEMS][MAX_SOUND_FILE_LENGTH];
float Totem_SoundRepeatInterval[MAX_TOTEMS];
char Totem_DamageSound[MAX_TOTEMS][MAX_SOUND_FILE_LENGTH];
int Totem_Flags[MAX_TOTEMS];
bool Totem_Victims[MAX_TOTEMS][MAX_PLAYERS_ARRAY];
float Totem_KnockbackIntensity[MAX_TOTEMS];
float Totem_NextInternalAt[MAX_TOTEMS];
float Totem_DamageCylinderHeight[MAX_TOTEMS];
float Totem_AfterburnDuration[MAX_TOTEMS];
float Totem_SlowdownFactor[MAX_TOTEMS];
char Totem_TotemParticle[MAX_TOTEMS][MAX_EFFECT_NAME_LENGTH];
float Totem_TotemParticleInterval[MAX_TOTEMS];
int Totem_DynamicLight[MAX_TOTEMS];
// the variables below are internal, used for intervals
float Totem_NextVisualAt[MAX_TOTEMS];
float Totem_NextDamageAt[MAX_TOTEMS];
float Totem_NextSoundPlayAt[MAX_TOTEMS];
float Totem_NextSpecialAt[MAX_TOTEMS];
float Totem_NextParticleAt[MAX_TOTEMS];

/**
 * Teleport to spawn
 *
 * Since hookshot doesn't have any decent Super Duper Jump equivalent and the unlucky person could take lots of damage.
 */
#define TTS_STRING "ff2_teleport_to_spawn"
bool TTS_ActiveThisRound;
bool TTS_CanUse[MAX_PLAYERS_ARRAY]; // internal
//float TTS_RedSpawn[3]; // internal
//float TTS_BluSpawn[3]; // internal
float TTS_MinimumDamage[MAX_PLAYERS_ARRAY]; // arg1
bool TTS_AlsoUseRedSpawn[MAX_PLAYERS_ARRAY]; // arg2
float TTS_AllowRedSpawnAt[MAX_PLAYERS_ARRAY]; // arg3 + roundstarttime
bool TTS_OverrideVSPMethod[MAX_PLAYERS_ARRAY]; // arg4

 
public void OnPluginStart2()
{
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	
	//EET_BoltMaterial = PrecacheModel("materials/sprites/laser.vmt");
	//EET_BoltMaterial = PrecacheModel("sprites/glow02.vmt");
	EET_BoltMaterial = PrecacheModel("materials/sprites/white.vmt");
	PrecacheSound(NOPE_AVI); // DO NOT DELETE IN FUTURE MOD PACKS
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	RoundInProgress = true;
	PluginActiveThisRound = false;
	
	// initialize variables
	ET_ActiveThisRound = false;
	HS_ActiveThisRound = false;
	SS_ActiveThisRound = false;
	TTS_ActiveThisRound = false;
	SS_EntRef = 0;
	for (int i = 0; i < MAX_ROCKS; i++)
	{
		RockEntRef[i] = 0;
		RockSpawnedAt[i] = FAR_FUTURE;
		RockCollisionCheckAt[i] = FAR_FUTURE;
	}
	SS_HUDNextCheck = GetGameTime() + SS_HUD_CHECK_INTERVAL;
	SS_HUDMessageIdx = SS_HUD_MSG_NONE;
	RocksPendingSpawn = 0;
	for (int i = 0; i < MAX_TOTEMS; i++)
		Totem_Type[i] = -1;
		
	// fog controller variable init
	ET_FogTransitionElapsed = ET_FOG_TRANSITION_TIME;
	ET_FogCurrentDensity = 0.0;
	ET_FogStartingDensity = 0.0;
	ET_FogCurrentColor = ET_FOG_DEFAULT_COLOR;
	ET_FogStartingColor = ET_FOG_DEFAULT_COLOR;
	
	// initialize arrays
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		// all client inits
		HS_CanUse[clientIdx] = false;
		HS_AltFireDown[clientIdx] = false;
		HS_DuckKeyDown[clientIdx] = false;
		HS_JumpKeyDown[clientIdx] = false;
		HS_HookshotOut[clientIdx] = false;
		HS_UsableAt[clientIdx] = 0.0;
		HS_HookEntRef[clientIdx] = 0;
		HS_HudErrorClearAt[clientIdx] = 0.0;
		HS_BeamEntRef[clientIdx][0] = 0;
		HS_BeamEntRef[clientIdx][1] = 0;
		ET_CanUse[clientIdx] = false;
		ET_ExpectedSpeed[clientIdx] = -1.0;
		ET_IsSpeedAdjusted[clientIdx] = false;
		ET_SpeedAdjust[clientIdx] = 1.0;
		ET_RemoveAfterburnAt[clientIdx] = FAR_FUTURE;
		TTS_CanUse[clientIdx] = false;
	
		// boss-only inits
		int bossIdx = FF2_GetBossIndex(clientIdx);
		if (bossIdx < 0)
			continue;
			
		// hookshot
		HS_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, HS_STRING);
		if (HS_CanUse[clientIdx])
		{
			HS_LastUpdateAt[clientIdx] = GetGameTime();
			HS_HUDText[clientIdx][0] = 0;
			HS_HudRefreshAt[clientIdx] = GetGameTime();
			
			HS_ActiveThisRound = true;
			PluginActiveThisRound = true;
		
			// ability props
			HS_ReelInSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HS_STRING, 1);
			HS_ReelOutSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HS_STRING, 2);
			HS_Cooldown[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HS_STRING, 3);
			HS_RageCost[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HS_STRING, 4);
			HS_MaxFiringAngle[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HS_STRING, 5);
			ReadMaterial(bossIdx, HS_STRING, 6, HS_RopeTextureStr);
			ReadModel(bossIdx, HS_STRING, 7, HS_HookModel);
			ReadSound(bossIdx, HS_STRING, 8, HS_HookFiringSound);
			HS_ElasticityModifier[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HS_STRING, 9);
			HS_MaxSwingSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HS_STRING, 10);
			HS_MaxSwingDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HS_STRING, 11);
			HS_NegativeZDegradationFactor[clientIdx] = 1.0 - FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HS_STRING, 12);
			HS_HorizontalMotionFactor[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HS_STRING, 13);
			
			// strings (different ability)
			if (FF2_HasAbility(bossIdx, this_plugin_name, HSS_STRING))
			{
				ReadCenterText(bossIdx, HSS_STRING, 1, HS_RopeSnappedStr);
				ReadCenterText(bossIdx, HSS_STRING, 2, HS_TimeLimitReachedStr);
				ReadCenterText(bossIdx, HSS_STRING, 3, HS_HitGroundOrWaterStr);
				ReadCenterText(bossIdx, HSS_STRING, 4, HS_InstructionHUDTemplate);
				ReadCenterText(bossIdx, HSS_STRING, 5, HS_InUseHUDTemplate);
				ReadCenterText(bossIdx, HSS_STRING, 6, HS_CooldownHUDTemplate);
				ReadCenterText(bossIdx, HSS_STRING, 7, HS_RageCostHUDTemplate);
				ReadCenterText(bossIdx, HSS_STRING, 8, HS_StunnedStr);
				ReadCenterText(bossIdx, HSS_STRING, 9, HS_OnGroundStr);
				ReadCenterText(bossIdx, HSS_STRING, 10, HS_BadAngleStr);
				ReadCenterText(bossIdx, HSS_STRING, 11, HS_NotEnoughRageStr);
				ReadCenterText(bossIdx, HSS_STRING, 12, HS_WeighdownActiveStr);
			}
			
			// flags
			HS_Flags[clientIdx] = ReadHexOrDecString(bossIdx, HS_STRING, 19);
			
			// init HUD
			UpdateHookshotHUD(clientIdx, HS_ERROR_NONE);
			
			// rope needs a default
			if (strlen(HS_RopeTextureStr) <= 3)
			{
				HS_RopeTextureStr = "materials/sprites/laser.vmt";
				PrecacheModel(HS_RopeTextureStr);
			}
				
			if (PRINT_DEBUG_INFO)
				PrintToServer("[sarysamods5] Client %d will use hookshot. Cooldown=%f Rage=%f ReelSpeeds=%f/%f maxangle=%f ropetex=%s", clientIdx, HS_Cooldown[clientIdx], HS_RageCost[clientIdx], HS_ReelInSpeed[clientIdx], HS_ReelOutSpeed[clientIdx], HS_MaxFiringAngle[clientIdx], HS_RopeTextureStr);
		}
		
		// sapphire stone
		if (FF2_HasAbility(bossIdx, this_plugin_name, RSS_STRING) || FF2_HasAbility(bossIdx, this_plugin_name, ESS_STRING))
		{
			SS_ActiveThisRound = true; // not set outside in case this is used in a multi-boss, i.e. RBD and Daring Do
			PluginActiveThisRound = true;
			
			char abilityName[30] = ESS_STRING;
			SS_IsRage = FF2_HasAbility(bossIdx, this_plugin_name, RSS_STRING);
			if (SS_IsRage)
			{
				abilityName = RSS_STRING;
				SS_EventInterval = 99999.0;
			}
			else
				SS_EventInterval = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, abilityName, 1);
			SS_NextSpawnAt = GetGameTime() + SS_EventInterval;
			ReadModel(bossIdx, abilityName, 2, SS_MainModel);
			SS_StoneCollisionRadius = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, abilityName, 3);
			SS_MinPlayersToUse = FF2_GetAbilityArgument(bossIdx, this_plugin_name, abilityName, 4);
			SS_PlayersForStoneFactor = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, abilityName, 5) * 0.01;
			SS_RockDamage = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, abilityName, 6);
			SS_RockMax = FF2_GetAbilityArgument(bossIdx, this_plugin_name, abilityName, 7);
			SS_RockKnockbackIntensity = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, abilityName, 8);
			ReadModel(bossIdx, abilityName, 9, SS_RockModel);
			ReadHull(bossIdx, abilityName, 10, SS_RockAreaRect);
			SS_RockStunDuration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, abilityName, 11);
			SS_RockTimeToLive = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, abilityName, 12);
			SS_RockMinSpeedEffective = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, abilityName, 13);
			SS_QuakeDuration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, abilityName, 14);
			SS_QuakeDamage = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, abilityName, 15);
			SS_BossDamageMultiplier = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, abilityName, 16);
			
			// second set, if applicable
			if (FF2_HasAbility(bossIdx, this_plugin_name, SSA_STRING))
			{
				// various messages
				ReadCenterText(bossIdx, SSA_STRING, 1, SS_StrStoneAppeared);
				ReadCenterText(bossIdx, SSA_STRING, 2, SS_BossGotStone);
				ReadCenterText(bossIdx, SSA_STRING, 3, SS_PlayersGotStone);
				ReadCenterText(bossIdx, SSA_STRING, 4, SS_MercStoneDisplayStr);

				// sounds (and precache)
				ReadSound(bossIdx, SSA_STRING, 7, SS_RockHitSound);
				ReadSound(bossIdx, SSA_STRING, 8, SS_QuakeSound);
				ReadSound(bossIdx, SSA_STRING, 9, SS_BossGotStoneSound);
				ReadSound(bossIdx, SSA_STRING, 10, SS_MercsGotStoneSound);
				ReadSound(bossIdx, SSA_STRING, 11, SS_StoneSpawnSound);
				
				// particles
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SSA_STRING, 13, SS_RockHitParticle, MAX_EFFECT_NAME_LENGTH);
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SSA_STRING, 14, SS_QuakeParticle, MAX_EFFECT_NAME_LENGTH);
			}
			else
				PrintToServer("[sarysamods5] WARNING: Hale has ability %s but is missing companion ability %s!", abilityName, SSA_STRING);
			
			// flags
			SS_Flags = ReadHexOrDecString(bossIdx, abilityName, 19);
			
			// sanity
			if (strlen(SS_MainModel) <= 3)
			{
				PrintToServer("[sarysamods5] ERROR: %s active this round but no model for the stone specified. Disabling.");
				SS_ActiveThisRound = false;
			}
			
			// derive collision rect for rocks from area rect
			SS_RockCollisionRect[0][0] = SS_RockAreaRect[0][0] - ROCK_COLLISION_RECT_EXTENSION;
			SS_RockCollisionRect[0][1] = SS_RockAreaRect[0][1] - ROCK_COLLISION_RECT_EXTENSION;
			SS_RockCollisionRect[0][2] = SS_RockAreaRect[0][2] - 83.0; // the height of a player, since we're only checking their origin
			SS_RockCollisionRect[1][0] = SS_RockAreaRect[1][0] + ROCK_COLLISION_RECT_EXTENSION;
			SS_RockCollisionRect[1][1] = SS_RockAreaRect[1][1] + ROCK_COLLISION_RECT_EXTENSION;
			SS_RockCollisionRect[1][2] = SS_RockAreaRect[1][2] + ROCK_COLLISION_RECT_EXTENSION;
			
			if (strlen(SS_RockModel) <= 3 && (SS_Flags & SS_FLAG_DROP_ROCKS) != 0)
			{
				PrintToServer("[sarysamods5] ERROR: %s has drop rocks specified but no rock model. Disabling rock trap.");
				SS_Flags &= ~SS_FLAG_DROP_ROCKS;
			}
		}
		
		// elemental totems
		ET_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, ET_STRING);
		if (ET_CanUse[clientIdx])
		{
			ET_ReloadDown[clientIdx] = false;
			
			ET_FireEnabled[clientIdx] = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, ET_STRING, 1) == 1);
			ET_IceEnabled[clientIdx] = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, ET_STRING, 2) == 1);
			ET_WindEnabled[clientIdx] = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, ET_STRING, 3) == 1);
			ET_ElectricEnabled[clientIdx] = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, ET_STRING, 4) == 1);
			ET_CurrentSelection[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ET_STRING, 5);
			
			// precache models
			for (int i = 0; i < ET_TYPE_COUNT; i++)
				ReadModelToInt(bossIdx, ET_STRING, 6 + i);
			
			// 2014-12-11, lets precache this again just in case
			EET_BoltMaterial = PrecacheModel("materials/sprites/white.vmt");
			
			// HUD strings
			ReadCenterText(bossIdx, ET_STRING, 10, ET_FireHUDStr);
			ReadCenterText(bossIdx, ET_STRING, 11, ET_IceHUDStr);
			ReadCenterText(bossIdx, ET_STRING, 12, ET_WindHUDStr);
			ReadCenterText(bossIdx, ET_STRING, 13, ET_ElectricHUDStr);
			ReadCenterText(bossIdx, ET_STRING, 14, ET_InstructionHUDStr);
			
			// verify required abilities exist, and precache sounds
			char soundFile[MAX_SOUND_FILE_LENGTH];
			if (ET_FireEnabled[clientIdx])
			{
				if (FF2_HasAbility(bossIdx, this_plugin_name, FET_STRING))
				{
					ReadSound(bossIdx, FET_STRING, 3, soundFile);
				}
				else
				{
					PrintToServer("[sarysamods5] WARNING: Fire totem enabled but rage %s missing. Disabling.", FET_STRING);
					ET_FireEnabled[clientIdx] = false;
				}
			}
			
			if (ET_IceEnabled[clientIdx])
			{
				if (FF2_HasAbility(bossIdx, this_plugin_name, IET_STRING))
				{
					ReadSound(bossIdx, IET_STRING, 3, soundFile);
				}
				else
				{
					PrintToServer("[sarysamods5] WARNING: Ice totem enabled but rage %s missing. Disabling.", IET_STRING);
					ET_IceEnabled[clientIdx] = false;
				}
			}

			if (ET_WindEnabled[clientIdx])
			{
				if (FF2_HasAbility(bossIdx, this_plugin_name, WET_STRING))
				{
					ReadSound(bossIdx, WET_STRING, 3, soundFile);
				}
				else
				{
					PrintToServer("[sarysamods5] WARNING: Wind totem enabled but rage %s missing. Disabling.", WET_STRING);
					ET_WindEnabled[clientIdx] = false;
				}
			}

			if (ET_ElectricEnabled[clientIdx])
			{
				if (FF2_HasAbility(bossIdx, this_plugin_name, EET_STRING))
				{
					ReadSound(bossIdx, EET_STRING, 3, soundFile);
					ReadSound(bossIdx, EET_STRING, 12, soundFile);
				}
				else
				{
					PrintToServer("[sarysamods5] WARNING: Electric totem enabled but rage %s missing. Disabling.", EET_STRING);
					ET_ElectricEnabled[clientIdx] = false;
				}
			}
			
			if (!ET_FireEnabled[clientIdx] && !ET_IceEnabled[clientIdx] && !ET_WindEnabled[clientIdx] && !ET_ElectricEnabled[clientIdx])
			{
				PrintToServer("[sarysamods5] ERROR: %s rage enabled no totems specified. Disabling the entire rage.", ET_STRING);
				ET_CanUse[clientIdx] = false;
			}
			else
			{
				ET_UpdateHUDAt[clientIdx] = GetGameTime();
			
				ET_ActiveThisRound = true;
				PluginActiveThisRound = true;
				
				// adjust current selection if invalid
				if (ET_CurrentSelection[clientIdx] > 3 || ET_CurrentSelection[clientIdx] < 0)
					ET_CurrentSelection[clientIdx] = 0;
					
				// increment if set to a disabled totem
				if (ET_CurrentSelection[clientIdx] == ET_FIRE && !ET_FireEnabled[clientIdx])
					IncrementTotemSelection(clientIdx);
				else if (ET_CurrentSelection[clientIdx] == ET_ICE && !ET_IceEnabled[clientIdx])
					IncrementTotemSelection(clientIdx);
				else if (ET_CurrentSelection[clientIdx] == ET_WIND && !ET_WindEnabled[clientIdx])
					IncrementTotemSelection(clientIdx);
				else if (ET_CurrentSelection[clientIdx] == ET_ELECTRIC && !ET_ElectricEnabled[clientIdx])
					IncrementTotemSelection(clientIdx);
			}
		}
		
		// teleport to spawn
		TTS_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, TTS_STRING);
		if (TTS_CanUse[clientIdx])
		{
			// messing with this to only allow it to work on Volcanic
			static char mapName[64];
			GetCurrentMap(mapName, 64);
		
			if (StrContains(mapName, "volcanic") >= 0)
			{
				TTS_ActiveThisRound = true;
				TTS_MinimumDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, TTS_STRING, 1);
				TTS_AlsoUseRedSpawn[clientIdx] = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, TTS_STRING, 2) == 1);
				TTS_AllowRedSpawnAt[clientIdx] = GetGameTime() + FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, TTS_STRING, 3);
				TTS_OverrideVSPMethod[clientIdx] = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, TTS_STRING, 4) == 1);
			}
			else
				TTS_CanUse[clientIdx] = false;
		}
	}
	
	SS_SpawnLocationCount = 0;
	if (SS_ActiveThisRound)
	{
		int entity = 0;
		
		// first, the control points
		if (SS_Flags & SS_FLAG_SPAWN_ON_CP)
		{
			while ((entity = FindEntityByClassname(entity, "team_control_point")) != -1 && SS_SpawnLocationCount < SS_MAX_SPAWNS)
			{
				GetEntPropVector(entity, Prop_Data, "m_vecOrigin", SS_Spawn[SS_SpawnLocationCount]);
				SS_Spawn[SS_SpawnLocationCount][2] += 15; // lift the Z slightly, since the CP is curved
				SS_SpawnLocationCount++;
			}
		}
		
		// second, item pickups
		if (SS_Flags & SS_FLAG_SPAWN_ON_PICKUP)
		{
			for (int i = 0; i < SS_MAX_PICKUPS; i++)
			{
				entity = 0;
				while ((entity = FindEntityByClassname(entity, SS_Pickups[i])) != -1 && SS_SpawnLocationCount < SS_MAX_SPAWNS)
				{
					GetEntPropVector(entity, Prop_Data, "m_vecOrigin", SS_Spawn[SS_SpawnLocationCount]);
					SS_Spawn[SS_SpawnLocationCount][2] += 5; // lift the Z very slightly off the ground
					SS_SpawnLocationCount++;
				}
			}
		}
		
		// beacon, if necessary
		if (SS_Flags & SS_FLAG_BEACON)
		{
			// precache stuff for beacon
			BEACON_BEAM = PrecacheModel("materials/sprites/laser.vmt");
			BEACON_HALO = PrecacheModel("materials/sprites/halo01.vmt");
			PrecacheSound(SS_BEACON_SOUND);
		}
		
		// final (required) is player spawn points, but we only take four from each team to keep CP's from being chosen too often
		// the reason I'm making it 4 is some maps have a variety of spawn points. i.e. vsh_west_fix has a ton for BLU
		// it's unlikely that RED's would be spaced apart, since even with multiple spawn hubs they're usually clumped together.
		int redCount = 0;
		int bluCount = 0;
		entity = 0;
		while ((entity = FindEntityByClassname(entity, "info_player_teamspawn")) != -1 && SS_SpawnLocationCount < SS_MAX_SPAWNS)
		{
			int teamNum = GetEntProp(entity, Prop_Send, "m_iTeamNum");
			if (teamNum == BossTeam)
			{
				if (bluCount >= 4)
					continue;
				bluCount++;
			}
			else
			{
				if (redCount >= 4)
					continue;
				redCount++;
			}
			
			GetEntPropVector(entity, Prop_Data, "m_vecOrigin", SS_Spawn[SS_SpawnLocationCount]);
			SS_Spawn[SS_SpawnLocationCount][2] += 5; // lift the Z very slightly off the ground
			SS_SpawnLocationCount++;
		}
		
		if (SS_SpawnLocationCount == 0)
		{
			PrintToServer("[sarysamods5] ERROR: No valid locations to spawn the Sapphire Stone on this map. Disabling.");
			SS_ActiveThisRound = false;
		}
		
		// hook player death event
		if (SS_ActiveThisRound)
			HookEvent("player_death", SS_PlayerDeath);
	}
	
	if (TTS_ActiveThisRound)
	{
		/*
		01Pollux: don't need it? remove it! those packs are already very full of unneeded things
		
		// find a random red spawn and BLU spawn by finding living players in each
		int randomRed = FindRandomPlayer(false);
		int randomBlu = FindRandomPlayer(true);
		if (IsValidEntity(randomRed))
		{
			GetEntPropVector(randomRed, Prop_Send, "m_vecOrigin", TTS_RedSpawn);
		}
		else
		{
			TTS_RedSpawn[0] = OFF_THE_MAP[0];
			TTS_RedSpawn[1] = OFF_THE_MAP[1];
			TTS_RedSpawn[2] = OFF_THE_MAP[2];
		}
		
		if (IsValidEntity(randomBlu))
		{
			GetEntPropVector(randomBlu, Prop_Send, "m_vecOrigin", TTS_BluSpawn);
		}
		else
		{
			TTS_BluSpawn[0] = OFF_THE_MAP[0];
			TTS_BluSpawn[1] = OFF_THE_MAP[1];
			TTS_BluSpawn[2] = OFF_THE_MAP[2];
		}
		*/
		
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (!IsLivingPlayer(clientIdx) || !TTS_CanUse[clientIdx])
				continue;
			SDKHook(clientIdx, SDKHook_OnTakeDamage, TTS_OnTakeDamage);
		}
	}
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	RoundInProgress = false;
	
	// hookshot, need to clean up any existing entities related to it
	if (HS_ActiveThisRound)
	{
		HS_ActiveThisRound = false;
	}
	
	// sapphire stone cleanup
	if (SS_ActiveThisRound)
	{
		// unhook event
		UnhookEvent("player_death", SS_PlayerDeath);
		
		SS_ActiveThisRound = false;
	}
	
	// elemental totem cleanup
	if (ET_ActiveThisRound)
	{
		// fix the fog, lest it leak into future rounds
		ET_FogTransitionElapsed = ET_FOG_TRANSITION_TIME;
		ET_FogCurrentDensity = 0.0;
		ET_FogStartingDensity = 0.0;
		ET_FogCurrentColor = ET_FOG_DEFAULT_COLOR;
		ET_FogStartingColor = ET_FOG_DEFAULT_COLOR;
		SetFog(ET_FogCurrentColor, ET_FogCurrentDensity);
	
		ET_ActiveThisRound = false;
	}
	
	// teleport to spawn cleanup
	if (TTS_ActiveThisRound)
	{
		TTS_ActiveThisRound = false;
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (!TTS_CanUse[clientIdx])
				continue;
			SDKUnhook(clientIdx, SDKHook_OnTakeDamage, TTS_OnTakeDamage);
		}
	}
}

public Action FF2_OnAbility2(int bossPlayer, const char[] plugin_name, const char[] ability_name, int status)
{
	if (!RoundInProgress) // don't execute these rages with 0 players alive
		return Plugin_Continue;

	if (!strcmp(ability_name, RSS_STRING))
	{
		// all this does is set the sapphire stone timer to now
		SS_NextSpawnAt = GetGameTime();
	}
	else if (!strcmp(ability_name, ET_STRING))
	{
		Rage_ElementalTotem(bossPlayer);
	}
		
	return Plugin_Continue;
}

/**
 * Hookshot
 */
public bool HS_IsValidHookshotState(int clientIdx)
{
	int flags = GetEntityFlags(clientIdx);
	if (flags & FL_ONGROUND)
		return false;
	if (flags & (FL_SWIM | FL_INWATER))
		return false;
	return true;
}
 
public void CancelHookshot(int clientIdx, bool ropeSnapped, int errorIdx)
{
	// 2015-10-03, this can now be called outside this plugin. so this is necessary.
	if (!HS_CanUse[clientIdx])
		return;

	if (PRINT_DEBUG_SPAM)
		PrintToServer("[sarysamods5] Client %d cancelled hookshot. (unintentional: %d)", clientIdx, ropeSnapped);
	
	HS_HookshotOut[clientIdx] = false;
	DD_SetDisabled(clientIdx, false, false, false);
	
	// remove hook entity
	if (HS_HookEntRef[clientIdx] != 0)
	{
		RemoveEntity(HS_HookEntRef[clientIdx]);
		RemoveEntity(HS_BeamEntRef[clientIdx][0]);
		RemoveEntity(HS_BeamEntRef[clientIdx][1]);
		HS_HookEntRef[clientIdx] = 0;
		HS_BeamEntRef[clientIdx][0] = 0;
		HS_BeamEntRef[clientIdx][1] = 0;
	}
	
	// start the cooldown timer, if applicable
	if ((HS_Flags[clientIdx] & HS_FLAG_COOLDOWN_ON_UNHOOK) == 0)
		HS_UsableAt[clientIdx] = GetGameTime() + HS_Cooldown[clientIdx];
		
	// remove glow hack
	if ((HS_Flags[clientIdx] & HS_FLAG_GLOW_HACK) != 0)
		SetEntProp(clientIdx, Prop_Send, "m_bGlowEnabled", 0);
	
	// update HUD
	UpdateHookshotHUD(clientIdx, errorIdx);
}

public void UpdateHookshotHUD(int clientIdx, int errorIdx)
{
	int bossIdx = FF2_GetBossIndex(clientIdx);
	float currentRage = FF2_GetBossCharge(bossIdx, 0);
	
	if (errorIdx != -1)
	{
		HS_HUDErrorIdx[clientIdx] = errorIdx;
		HS_HudErrorClearAt[clientIdx] = GetGameTime() + 5.0;
	}
		
	char hudError[HS_HUD_TEXT_LENGTH];
	if (HS_HUDErrorIdx[clientIdx] == HS_ERROR_ROPE_SNAPPED)
		hudError = HS_RopeSnappedStr;
	else if (HS_HUDErrorIdx[clientIdx] == HS_ERROR_TIME_LIMIT)
		hudError = HS_TimeLimitReachedStr;
	else if (HS_HUDErrorIdx[clientIdx] == HS_ERROR_HIT_GROUND)
		hudError = HS_HitGroundOrWaterStr;
	else if (HS_HUDErrorIdx[clientIdx] == HS_ERROR_STUNNED)
		hudError = HS_StunnedStr;
	else if (HS_HUDErrorIdx[clientIdx] == HS_ERROR_ON_GROUND)
		hudError = HS_OnGroundStr;
	else if (HS_HUDErrorIdx[clientIdx] == HS_ERROR_BAD_ANGLE)
		hudError = HS_BadAngleStr;
	else if (HS_HUDErrorIdx[clientIdx] == HS_ERROR_INSUFFICIENT_RAGE)
		hudError = HS_NotEnoughRageStr;
	else if (HS_HUDErrorIdx[clientIdx] == HS_ERROR_WEIGHDOWN_ACTIVE)
		hudError = HS_WeighdownActiveStr;
		
	if (currentRage < HS_RageCost[clientIdx])
	{
		Format(HS_HUDText[clientIdx], HS_HUD_TEXT_LENGTH, HS_RageCostHUDTemplate, HS_RageCost[clientIdx], hudError);
	}
	else if (HS_HookshotOut[clientIdx])
	{
		Format(HS_HUDText[clientIdx], HS_HUD_TEXT_LENGTH, HS_InUseHUDTemplate, hudError);
	}
	else if (HS_UsableAt[clientIdx] > GetGameTime())
	{
		Format(HS_HUDText[clientIdx], HS_HUD_TEXT_LENGTH, HS_CooldownHUDTemplate, HS_UsableAt[clientIdx] - GetGameTime(), hudError);
	}
	else
	{
		// TODO blank out the message if user is on cooldown
		Format(HS_HUDText[clientIdx], HS_HUD_TEXT_LENGTH, HS_InstructionHUDTemplate, hudError);
	}
	
	ReplaceString(HS_HUDText[clientIdx], HS_HUD_TEXT_LENGTH, "\\n", "\n");
	
	if (!IsEmptyString(hudError))
		HS_HudErrorClearAt[clientIdx] = GetGameTime() + 5.0;
}

//public HS_AdjustVelocity(clientIdx, float xAdjust, float yAdjust, float zAdjust, bool zeroZ)
//{
//	float velocity[3];
//	GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", velocity);
//	
//	if (zeroZ)
//		velocity[2] = 0.0;
//		
//	velocity[0] = xAdjust;
//	velocity[1] = yAdjust;
//	velocity[2] = zAdjust;
//	
//	SetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", velocity);
//	TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, velocity);
//}
 
/**
 * Sapphire Stone
 */
public void SS_SetHUDMessage(int messageIdx)
{
	SS_HUDMessageIdx = messageIdx;
	SS_HUDMessageExpirationTime = GetGameTime() + (messageIdx == SS_HUD_MSG_NUM_MERCS_ON_STONE ? 9999.0 : SS_HUD_DURATION);
}

public void SS_RefreshHUD(float curTime)
{
	if (curTime >= SS_HUDNextCheck)
	{
		if (curTime >= SS_HUDMessageExpirationTime)
			SS_HUDMessageIdx = SS_HUD_MSG_NONE;
	
		// going with the FF2 timer values, since I'd like it to be fairly responsive
		SetHudTextParams(-1.0, SS_HUD_POSITION, SS_HUD_CHECK_INTERVAL + 0.05, 255, 64, 64, 192);
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsLivingPlayer(clientIdx))
			{
				if (SS_HUDMessageIdx == SS_HUD_MSG_APPEARED)
					ShowHudText(clientIdx, -1, SS_StrStoneAppeared);
				else if (SS_HUDMessageIdx == SS_HUD_MSG_BOSS_FOUND)
					ShowHudText(clientIdx, -1, SS_BossGotStone);
				else if (SS_HUDMessageIdx == SS_HUD_MSG_MERCS_FOUND)
					ShowHudText(clientIdx, -1, SS_PlayersGotStone);
				else if (SS_HUDMessageIdx == SS_HUD_MSG_NUM_MERCS_ON_STONE)
					ShowHudText(clientIdx, -1, SS_MercStoneDisplayStr, SS_HUDNumMercs, SS_HUDMercsRequired);
			}
		}

		SS_HUDNextCheck = curTime + SS_HUD_CHECK_INTERVAL;
	}
}

public int SS_FindAttacker(bool bossTriggered)
{
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		if (IsLivingPlayer(clientIdx) && ((bossTriggered && GetClientTeam(clientIdx) == BossTeam) || (!bossTriggered && GetClientTeam(clientIdx) != BossTeam)))
			return clientIdx;
			
	return -1;
}

public void SS_StartEvent(bool bossTriggered)
{
	if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods5] Starting Sapphire Stone event. bossTriggered=%d", bossTriggered);
		
	// earthquake. I've modified it to optionally not mess with physics props.
	// too many potential issues
	env_shake(view_as<float>({0.0, 0.0, 0.0}), 120.0, 10000.0, SS_QuakeDuration, 250.0, (SS_Flags & SS_FLAG_EARTHQUAKE_HAS_PHYSICS) == 0);
	if (SS_QuakeDamage > 0.0)
	{
		// find an attacker for the event damage
		int attacker = SS_FindAttacker(bossTriggered);
		
		// do event damage to all potential victims
		if (attacker != -1) for (int victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (IsLivingPlayer(victim) && ((bossTriggered && GetClientTeam(victim) != BossTeam) || (!bossTriggered && GetClientTeam(victim) == BossTeam)))
			{
				SemiHookedDamage(victim, attacker, attacker, SS_QuakeDamage * (bossTriggered ? 1.0 : SS_BossDamageMultiplier), DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
				
				// particle effect on player
				if (!IsEmptyString(SS_RockHitParticle))
				{
					float playerOrigin[3];
					GetEntPropVector(victim, Prop_Data, "m_vecOrigin", playerOrigin);
					ParticleEffectAt(playerOrigin, SS_QuakeParticle);
				}
			}
		}

		// play quake sound for all
		if (strlen(SS_QuakeSound) > 3)
		{
			EmitSoundToAll(SS_QuakeSound);
			EmitSoundToAll(SS_QuakeSound);
			EmitSoundToAll(SS_QuakeSound);
		}
	}
	
	// spawn our physics rocks
	// basically, what is happening is these rocks will spawn above players' heads, but will NOT directly land on them.
	// instead, they'll be fired at a 45 degree angle with an intensity of around 1000.
	// random yaw.
	// since rocks can get stuck inside each other, there needs to be an 0.5s delay between firings.
	RockNextSpawnAt = GetGameTime() + ROCK_FIRING_INTERVAL;
	RocksPendingSpawn = SS_RockMax;
	RocksAreBossTeam = bossTriggered;
		
	// reset the timer
	SS_NextBeaconAt = GetGameTime() + SS_BEACON_DELAY;
	
	// play the get sound
	if (bossTriggered && strlen(SS_BossGotStoneSound) > 3)
	{
		EmitSoundToAll(SS_BossGotStoneSound);
		EmitSoundToAll(SS_BossGotStoneSound);
		EmitSoundToAll(SS_BossGotStoneSound);
	}
	else if (!bossTriggered && strlen(SS_MercsGotStoneSound) > 3)
	{
		EmitSoundToAll(SS_MercsGotStoneSound);
		EmitSoundToAll(SS_MercsGotStoneSound);
		EmitSoundToAll(SS_MercsGotStoneSound);
	}
	
	// remove the entity
	Timer_RemoveEntity(null, SS_EntRef);
	SS_EntRef = 0;
}

#define ROCK_TRACE_FLAGS (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE)
public void SS_SpawnRocks(float curTime)
{
	// checking if it's necessary in here
	if (RocksPendingSpawn <= 0 || RockNextSpawnAt > curTime)
		return;
		
	// only make 5 passes at finding a suitable spawn location, and then give up.
	for (int pass = 0; pass < 5; pass++)
	{
		// find a suitable victim
		int victim = FindRandomPlayer(!RocksAreBossTeam);
		
		// if it's -1 it'll never be valid
		if (victim == -1)
			break;
			
		// do a simple floor/ceiling check to ensure there's enough space
		Handle trace;
		float victimPos[3];
		float ceilingPos[3];
		float floorPos[3];
		GetEntPropVector(victim, Prop_Data, "m_vecOrigin", victimPos);
		trace = TR_TraceRayFilterEx(victimPos, view_as<float>({90.0, 0.0, 0.0}), ROCK_TRACE_FLAGS, RayType_Infinite, TraceWallsOnly);
		TR_GetEndPosition(floorPos, trace);
		CloseHandle(trace);
		trace = TR_TraceRayFilterEx(victimPos, view_as<float>({-90.0, 0.0, 0.0}), ROCK_TRACE_FLAGS, RayType_Infinite, TraceWallsOnly);
		TR_GetEndPosition(ceilingPos, trace);
		CloseHandle(trace);
		
		if (ceilingPos[2] - floorPos[2] < SS_RockAreaRect[1][2])
			continue; // failed. not enough room
		
		// success, lets get ready to spawn it
		bool useSafetySpace = ((ceilingPos[2] - floorPos[2]) - SS_RockAreaRect[1][2]) > ROCK_SPAWN_SAFETY_SPACE;
		float randomYaw = GetRandomFloat(-179.9, 179.9);
		float startingPos[3];
		startingPos[0] = ceilingPos[0];
		startingPos[1] = ceilingPos[1];
		startingPos[2] = ceilingPos[2] - SS_RockAreaRect[1][2] - (useSafetySpace ? ROCK_SPAWN_SAFETY_SPACE : 0.0);
		
		// cap distance of starting pos to 1000 hu above
		startingPos[2] = fmin(startingPos[2], floorPos[2] + ROCK_HEIGHT_CAP);
		
		// angle depends on distance from the floor to the spawn point
		float zDist = startingPos[2] - floorPos[2];
		float startingAngle[3];
		startingAngle[0] = ROCK_FIRING_ANGLE_NEAR + ((ROCK_FIRING_ANGLE_FAR - ROCK_FIRING_ANGLE_NEAR) * (zDist / ROCK_HEIGHT_CAP));
		startingAngle[1] = randomYaw;
		
		// velocity
		float startingVel[3];
		float tmpVec[3];
		trace = TR_TraceRayFilterEx(startingPos, startingAngle, ROCK_TRACE_FLAGS, RayType_Infinite, TraceWallsOnly);
		TR_GetEndPosition(tmpVec, trace);
		CloseHandle(trace);
		MakeVectorFromPoints(startingPos, tmpVec, startingVel);
		NormalizeVector(startingVel, startingVel);
		startingVel[0] *= ROCK_DEFAULT_VEL_INTENSITY;
		startingVel[1] *= ROCK_DEFAULT_VEL_INTENSITY;
		startingVel[2] *= ROCK_DEFAULT_VEL_INTENSITY;
		
		// it'll be a prop physics override. hopefully this should remove any player-like collision data for Friagram's tom rock.
		// if not will have to use a generic TF2 rock.
		int rock = CreateEntityByName("prop_physics_override"); //CreateEntityByName("gib");
		if (IsValidEntity(rock))
		{
			// the actual spawning process
			SetEntityModel(rock, SS_RockModel);
			DispatchSpawn(rock);
			TeleportEntity(rock, startingPos, startingAngle, startingVel);
			SetEntProp(rock, Prop_Data, "m_takedamage", 0);

			// I analyzed a shooter gib to get these collision values
			//SetEntityMoveType(rock, MOVETYPE_NONE);
			SetEntProp(rock, Prop_Send, "m_CollisionGroup", 1);
			SetEntProp(rock, Prop_Send, "m_usSolidFlags", 0x10);
			SetEntProp(rock, Prop_Send, "m_nSolidType", 2);

			// find a free entity slot. I'm just going to assume the user isn't careless enough
			// to allow this to overflow. otherwise there'll be a useless rock hanging around until round ends.
			for (int i = 0; i < MAX_ROCKS; i++)
			{
				if (RockEntRef[i] == 0)
				{
					RockEntRef[i] = EntIndexToEntRef(rock);
					RockSpawnedAt[i] = curTime;
					RockCollisionCheckAt[i] = curTime + ROCK_COLLISION_INTERVAL;
					RockLastCollisionCheckAt[i] = curTime;
					
					RockLastPosition[i][0] = startingPos[0];
					RockLastPosition[i][1] = startingPos[1];
					RockLastPosition[i][2] = startingPos[2];
					break;
				}
			}
		}
		
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods5] Spawned a rock for boss=%d  remaining=%d", RocksAreBossTeam, (RocksPendingSpawn - 1));
		break;
	}
		
	// prep the next rock if valid
	RockNextSpawnAt = curTime + ROCK_FIRING_INTERVAL;
	RocksPendingSpawn--;
}

public void SS_TickRocks(float curTime)
{
	// first lets see what rocks we need to destroy
	for (int i = MAX_ROCKS - 1; i >= 0; i--)
	{
		if (RockEntRef[i] != 0 && curTime >= RockSpawnedAt[i] + SS_RockTimeToLive)
		{
			Timer_RemoveEntity(null, RockEntRef[i]);
			RockEntRef[i] = 0;
			RockSpawnedAt[i] = FAR_FUTURE;
			RockCollisionCheckAt[i] = FAR_FUTURE;
			for (int j = i; j < MAX_ROCKS - 2; j++)
			{
				RockEntRef[j] = RockEntRef[j+1];
				RockSpawnedAt[j] = RockSpawnedAt[j+1];
				RockCollisionCheckAt[j] = RockCollisionCheckAt[j+1];
			}
		}
	}
	
	// next, do collision checks, but only if we have rocks to check
	if (RockEntRef[0] != 0)
	{
		// find an attacker 
		int attacker = SS_FindAttacker(RocksAreBossTeam);

		if (attacker != -1) for (int i = 0; i < MAX_ROCKS; i++)
		{
			if (RockEntRef[i] != 0 && curTime >= RockCollisionCheckAt[i])
			{
				int rockEntity = EntRefToEntIndex(RockEntRef[i]);
				if (!IsValidEntity(rockEntity))
					continue;

				static float rockOrigin[3];
				GetEntPropVector(rockEntity, Prop_Data, "m_vecOrigin", rockOrigin);
				float rockVelocity = GetVelocityFromPointsAndInterval(rockOrigin, RockLastPosition[i], curTime - RockLastCollisionCheckAt[i]);
				if (rockVelocity >= SS_RockMinSpeedEffective)
				{
					static float rockHull[2][3];
					rockHull[0][0] = rockOrigin[0] + SS_RockCollisionRect[0][0];
					rockHull[0][1] = rockOrigin[1] + SS_RockCollisionRect[0][1];
					rockHull[0][2] = rockOrigin[2] + SS_RockCollisionRect[0][2];
					rockHull[1][0] = rockOrigin[0] + SS_RockCollisionRect[1][0];
					rockHull[1][1] = rockOrigin[1] + SS_RockCollisionRect[1][1];
					rockHull[1][2] = rockOrigin[2] + SS_RockCollisionRect[1][2];
					for (int victim = 1; victim < MAX_PLAYERS; victim++)
					{
						if (IsLivingPlayer(victim) && ((RocksAreBossTeam && GetClientTeam(victim) != BossTeam) || (!RocksAreBossTeam && GetClientTeam(victim) == BossTeam)))
						{
							static float clientOrigin[3];
							GetEntPropVector(victim, Prop_Data, "m_vecOrigin", clientOrigin);
							if (RectangleCollision(rockHull, clientOrigin))
							{
								// play the sound
								if (strlen(SS_RockHitSound) > 3)
									PseudoAmbientSound(victim, SS_RockHitSound);
									
								// particle effect
								if (!IsEmptyString(SS_RockHitParticle))
									ParticleEffectAt(clientOrigin, SS_RockHitParticle);
							
								// first, the stun if applicable
								if (SS_RockStunDuration > 0.0 && !TF2_IsPlayerInCondition(victim, TFCond_Ubercharged) && !TF2_IsPlayerInCondition(victim, TFCond_MegaHeal))
								{
									if (SS_Flags & SS_FLAG_ROCK_SOFT_STUN)
										TF2_StunPlayer(victim, SS_RockStunDuration, 0.0, TF_STUNFLAG_THIRDPERSON | TF_STUNFLAG_NOSOUNDOREFFECT | TF_STUNFLAGS_SMALLBONK, attacker);
									else if (SS_Flags & SS_FLAG_ROCK_HARD_STUN)
										TF2_StunPlayer(victim, SS_RockStunDuration, 0.0, TF_STUNFLAG_THIRDPERSON | TF_STUNFLAG_NOSOUNDOREFFECT | TF_STUNFLAG_BONKSTUCK, attacker);
									else
										PrintToServer("[sarysamods5] WARNING: Stun duration set to %f but none of the stun flags are set!", SS_RockStunDuration);
								}
								
								// next, the knockback. make it additive so it's more likely the victim gets knocked away and not demolished (unless it's a corner, then they should get demolished)
								if (SS_RockKnockbackIntensity > 0.0)
								{
									float knockbackVelocity[3];
									MakeVectorFromPoints(rockOrigin, clientOrigin, knockbackVelocity);
									NormalizeVector(knockbackVelocity, knockbackVelocity);
									knockbackVelocity[0] *= SS_RockKnockbackIntensity;
									knockbackVelocity[1] *= SS_RockKnockbackIntensity;
									knockbackVelocity[2] *= SS_RockKnockbackIntensity;
									if (knockbackVelocity[2] < 275.0) // apply a minimum z lift, otherwise they won't move
										knockbackVelocity[2] = 275.0;
										
									// overwrite the victim's velocity (I originally added it onto and that had problems)
									//float vecVelocity[3];
									//GetEntPropVector(victim, Prop_Data, "m_vecVelocity", vecVelocity);
									//vecVelocity[0] += knockbackVelocity[0];
									//vecVelocity[1] += knockbackVelocity[1];
									//vecVelocity[2] += knockbackVelocity[2];
									SetEntPropVector(victim, Prop_Data, "m_vecVelocity", knockbackVelocity);
									TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, knockbackVelocity);
								}
								
								// and last, in since we don't want victims dying in the middle of all this, the damage
								SemiHookedDamage(victim, attacker, attacker, SS_RockDamage * (RocksAreBossTeam ? 1.0 : SS_BossDamageMultiplier), DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
							}
						}
					}
				}
				else if (rockVelocity == 0.0) // queue kill on this rock
					RockSpawnedAt[i] = curTime - SS_RockTimeToLive;
				
				RockLastCollisionCheckAt[i] = curTime;
				RockLastPosition[i][0] = rockOrigin[0];
				RockLastPosition[i][1] = rockOrigin[1];
				RockLastPosition[i][2] = rockOrigin[2];
				RockCollisionCheckAt[i] += ROCK_COLLISION_INTERVAL;
			}
		}
	}
}

public void SS_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	SS_HUDMercsRequired = SS_GetNumPlayersRequired();
}

public int SS_GetNumPlayersRequired()
{
	int livingMercCount = GetLivingMercCount();
	int count = RoundFloat(livingMercCount * SS_PlayersForStoneFactor);
	if (count < SS_MinPlayersToUse)
		count = SS_MinPlayersToUse;
	if (count > livingMercCount)
		count = livingMercCount;
	return count;
}

/**
 * Elemental Totems
 */
float TE_TmpDamage = 0.0;
int TE_TmpAttacker = -1;
bool TE_GiveSpeed = false;
float TE_MaxDistance = 0.0;
float TE_TotemPos[3];
public bool TraceElectric(int entity, int contentsMask)
{
	// must be valid player
	if (!IsLivingPlayer(entity) || GetClientTeam(entity) == BossTeam)
		return false;
		
	// verify distance
	float victimPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", victimPos);
	if (GetVectorDistance(TE_TotemPos, victimPos) > TE_MaxDistance)
		return false;
		
	// give speed
	if (TE_GiveSpeed)
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods5] Giving shock speed to %d", entity);
		TF2_AddCondition(entity, TFCond_SpeedBuffAlly, 5.0);
	}
		
	// deal damage
	if (TE_TmpDamage > 0.0)
		SDKHooks_TakeDamage(entity, TE_TmpAttacker, TE_TmpAttacker, TE_TmpDamage, DMG_SHOCK, -1);
		
	return false;
}
 
public void DrawTotemHUD(int clientIdx)
{
	if (GetGameTime() >= ET_UpdateHUDAt[clientIdx])
	{
		static char hudMessage[(MAX_CENTER_TEXT_LENGTH * 2) + 2];
		if (ET_CurrentSelection[clientIdx] == ET_FIRE)
			FormatEx(hudMessage, sizeof(hudMessage), "%s\n%s", ET_FireHUDStr, ET_InstructionHUDStr);
		else if (ET_CurrentSelection[clientIdx] == ET_ICE)
			FormatEx(hudMessage, sizeof(hudMessage), "%s\n%s", ET_IceHUDStr, ET_InstructionHUDStr);
		else if (ET_CurrentSelection[clientIdx] == ET_WIND)
			FormatEx(hudMessage, sizeof(hudMessage), "%s\n%s", ET_WindHUDStr, ET_InstructionHUDStr);
		else if (ET_CurrentSelection[clientIdx] == ET_ELECTRIC)
			FormatEx(hudMessage, sizeof(hudMessage), "%s\n%s", ET_ElectricHUDStr, ET_InstructionHUDStr);
			
		SetHudTextParams(-1.0, ET_HUD_POSITION, ET_HUD_CHECK_INTERVAL + 0.05, 64, 255, 64, 192);
		ShowHudText(clientIdx, -1, hudMessage);
		ET_UpdateHUDAt[clientIdx] += ET_HUD_CHECK_INTERVAL;
	}
}

public void WindTotemKnockPlayerUp(int totemIdx, int victim, float intensityOverride)
{
	// overwrite the player's Z
	float vecVelocity[3];
	GetEntPropVector(victim, Prop_Data, "m_vecVelocity", vecVelocity);
	vecVelocity[2] = Totem_KnockbackIntensity[totemIdx] * intensityOverride;
	SetEntPropVector(victim, Prop_Data, "m_vecVelocity", vecVelocity);
	TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, vecVelocity);
}

public void WindTotemFindNewVictims(int totemIdx, float totemPos[3])
{
	for (int victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
			continue;
		else if (Totem_Victims[totemIdx][victim]) // already a victim?
			continue;
			
		float playerPos[3];
		GetEntPropVector(victim, Prop_Data, "m_vecOrigin", playerPos);
		if (CylinderCollision(totemPos, playerPos, Totem_DamageEffectRadius[totemIdx], totemPos[2] - 103.0, totemPos[2] + 1000.0))
		{
			Totem_Victims[totemIdx][victim] = true;
			if (playerPos[2] < totemPos[2] + WET_MAX_HEIGHT)
			{
				WindTotemKnockPlayerUp(totemIdx, victim, WET_KNOCK_UP_INTENSITY);
			}
		}
	}
}

public void SetFog(int color, float density)
{
	int fog = FindEntityByClassname(-1, "env_fog_controller");
	if (IsValidEntity(fog))
	{
		// hex color to "255 0 0" etc.
		static char colorBuffer[COLOR_BUFFER_SIZE];
		ColorToDecimalString(colorBuffer, color);
		
		// mess with the fog controller
		DispatchKeyValue(fog, "fogblend", "0");
		DispatchKeyValue(fog, "fogcolor", colorBuffer);
		DispatchKeyValue(fog, "fogcolor2", colorBuffer);
		DispatchKeyValueFloat(fog, "fogstart", 0.0);
		DispatchKeyValueFloat(fog, "fogend", 0.0001);
		DispatchKeyValueFloat(fog, "fogmaxdensity", density);
		DispatchKeyValue(fog, "foglerptime", "0");
		AcceptEntityInput(fog, "TurnOff"); // in testing I had to turn it off and on. bah
		AcceptEntityInput(fog, "TurnOn");
	}
}

public void TickFog(float curTime)
{
	// setup a int transition for expiration
	if (curTime > ET_FogExpiresAt && (ET_FogTargetColor != ET_FOG_DEFAULT_COLOR || ET_FogTargetDensity != 0.0))
	{
		ET_FogTransitionElapsed = 0.0;
		ET_FogTargetColor = ET_FOG_DEFAULT_COLOR;
		ET_FogTargetDensity = 0.0;
		ET_FogStartingDensity = ET_FogCurrentDensity;
		ET_FogStartingColor = ET_FogCurrentColor;
	}

	if (curTime < ET_FogLastCheckAt + ET_FOG_TRANSITION_INTERVAL)
		return;
	
	int fog = FindEntityByClassname(-1, "env_fog_controller");
	// ensure a transition is in progress, and that a fog controller exists
	if (ET_FogTransitionElapsed < ET_FOG_TRANSITION_TIME && IsValidEntity(fog))
	{
		float deltaTime = fmin(ET_FOG_TRANSITION_INTERVAL * 2, curTime - ET_FogLastCheckAt);
		
		// get current density and color
		ET_FogTransitionElapsed += deltaTime;
		if (ET_FogTransitionElapsed >= ET_FOG_TRANSITION_TIME)
		{
			ET_FogCurrentDensity = ET_FogTargetDensity;
			ET_FogCurrentColor = ET_FogTargetColor;
		}
		else
		{
			float newWeight = (ET_FogTransitionElapsed / ET_FOG_TRANSITION_TIME);
			float oldWeight = 1.0 - newWeight;
			ET_FogCurrentDensity = (ET_FogStartingDensity * oldWeight) + (ET_FogTargetDensity * newWeight);
			ET_FogCurrentColor = BlendColorsRGB(ET_FogStartingColor, oldWeight, ET_FogTargetColor, newWeight);
		}
		
		SetFog(ET_FogCurrentColor, ET_FogCurrentDensity);
		
		ET_FogLastCheckAt = curTime;
	}
}

public void TickTotems(float curTime)
{
	float speedAdjust[MAX_PLAYERS_ARRAY];
	bool shouldUber[MAX_PLAYERS_ARRAY];
	for (int i = 1; i < MAX_PLAYERS; i++)
	{
		speedAdjust[i] = 1.0;
		shouldUber[i] = false;
	}

	// tick the totems
	for (int totemIdx = 0; totemIdx < MAX_TOTEMS; totemIdx++)
	{
		if (Totem_EntRef[totemIdx] == 0 || Totem_Type[totemIdx] < 0)
			continue;

		if (curTime >= Totem_ExpiresAt[totemIdx] || !IsLivingPlayer(Totem_Owner[totemIdx]))
		{
			if (PRINT_DEBUG_INFO)
				PrintToServer("[sarysamods5] Despawned totem %d, it or its owner has expired.", totemIdx);
				
			RemoveTotemAt(totemIdx);
			totemIdx--;
			continue;
		}
		
		// get universally important things
		int totem = EntRefToEntIndex(Totem_EntRef[totemIdx]);
		if (!IsValidEntity(totem))
		{
			if (PRINT_DEBUG_INFO)
				PrintToServer("[sarysamods5] Despawned totem %d, invalid entity.", totemIdx);
		
			RemoveTotemAt(totemIdx);
			totemIdx--;
			continue;
		}
		static float totemPos[3];
		GetEntPropVector(totem, Prop_Data, "m_vecOrigin", totemPos);
		
		// need no Z for a couple things
		static float totemPosNoZ[3];
		totemPosNoZ[0] = totemPos[0];
		totemPosNoZ[1] = totemPos[1];
		totemPosNoZ[2] = 0.0;
				
		// special for wind: find int victims every tick
		if (Totem_Type[totemIdx] == ET_WIND)
			WindTotemFindNewVictims(totemIdx, totemPos);
		
		// special for ice, slowdown and uber
		if (Totem_SlowdownFactor[totemIdx] != 1.0 || Totem_Type[totemIdx] == ET_ICE)
		{
			float distanceSquared = Totem_VisualEffectRadius[totemIdx] * Totem_VisualEffectRadius[totemIdx];
		
			// effects for players and the hale
			for (int targetPlayer = 1; targetPlayer < MAX_PLAYERS; targetPlayer++)
			{
				if (!IsLivingPlayer(targetPlayer))
					continue;
			
				// player in range?
				static float playerOriginNoZ[3];
				GetEntPropVector(targetPlayer, Prop_Data, "m_vecOrigin", playerOriginNoZ);
				playerOriginNoZ[2] = 0.0;
				if (GetVectorDistance(playerOriginNoZ, totemPosNoZ, true) > distanceSquared)
					continue;
			
				if (Totem_Type[totemIdx] == ET_ICE && GetClientTeam(targetPlayer) == BossTeam && (Totem_Flags[totemIdx] & IET_FLAG_UBER) != 0)
					shouldUber[targetPlayer] = true;
				else if (GetClientTeam(targetPlayer) != BossTeam)
					speedAdjust[targetPlayer] = Totem_SlowdownFactor[totemIdx];
			}
		}
			
		// special interval, i.e. the tornado
		if (curTime >= Totem_NextInternalAt[totemIdx])
		{
			if (Totem_Type[totemIdx] == ET_WIND)
			{
				for (int victim = 1; victim < MAX_PLAYERS; victim++)
				{
					// valid?
					if (!IsLivingPlayer(victim) || !Totem_Victims[totemIdx][victim])
						continue;
						
					if (GetEntityFlags(victim) & FL_ONGROUND)
						WindTotemKnockPlayerUp(totemIdx, victim, WET_KNOCK_UP_INTENSITY * 0.75);
				
					// need the victim's position, and then the angle from our difference. (yaw only is important)
					static float victimOrigin[3];
					GetEntPropVector(victim, Prop_Data, "m_vecOrigin", victimOrigin);
					static float flightAngles[3];
					GetVectorAnglesTwoPoints(victimOrigin, totemPos, flightAngles);
					flightAngles[0] = 0.0; // toss out pitch
				
					// turning right subtracts from the yaw, so turn right N degrees so the victim goes in a relatively circular pattern
					flightAngles[1] = fixAngle(flightAngles[1] - WET_TORNADO_ANGLE);
					
					// trace and then get our velocity vector
					static float tmpPos[3];
					Handle trace = TR_TraceRayFilterEx(victimOrigin, flightAngles, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
					TR_GetEndPosition(tmpPos, trace);
					CloseHandle(trace);
					static float vortexVelocity[3];
					MakeVectorFromPoints(victimOrigin, tmpPos, vortexVelocity);
					NormalizeVector(vortexVelocity, vortexVelocity);
					
					// get actual velocity now
					static float victimVelocity[3];
					GetEntPropVector(victim, Prop_Data, "m_vecVelocity", victimVelocity);
					
					// get adjusted velocity modifier
					static float victimOriginNoZ[3];
					victimOriginNoZ[0] = victimOrigin[0];
					victimOriginNoZ[1] = victimOrigin[1];
					victimOriginNoZ[2] = 0.0;
					float velFactor = WET_VORTEX_INTENSITY * Totem_KnockbackIntensity[totemIdx] * WET_TORNADO_INTERVAL;
					float adjustedFactor = 1.0;
					float noZDistance = GetVectorDistance(victimOriginNoZ, totemPosNoZ);
					float radiusLimit = (Totem_DamageEffectRadius[totemIdx] * WET_EXCESS_DISTANCE_RADIUS_FACTOR);
					if (noZDistance > radiusLimit)
					{
						// will completely adjust the player's velocity to ensure they get back on track
						adjustedFactor = getLinearVelocity(victimVelocity);
						velFactor = 1.0;
					}
								
					// apply an arbitrary z if the player is under the limit, and apply the intensity
					if (victimOrigin[2] < totemPos[2] + WET_MAX_HEIGHT)
						vortexVelocity[2] = WET_TRAPPED_LIFT;
					vortexVelocity[0] *= velFactor * adjustedFactor;
					vortexVelocity[1] *= velFactor * adjustedFactor;
					vortexVelocity[2] *= velFactor; // no adjustment for Z, only need to ensure X and Y are near the vortex core
					
					// dampen negative Z of actual velocity significantly, but only if the player's not too high already
					if (victimVelocity[2] < 0.0 && victimOrigin[2] < totemPos[2] + WET_MAX_HEIGHT)
						victimVelocity[2] *= 0.25;
						
					// tweak their velocity and set
					if (noZDistance > radiusLimit) // they're getting out of the vortex radius, so dramatically adjust their trajectory
					{
						victimVelocity[0] = vortexVelocity[0];
						victimVelocity[1] = vortexVelocity[1];
						victimVelocity[2] = vortexVelocity[2];
					}
					else // otherwise, just tweak it a little
					{
						victimVelocity[0] += vortexVelocity[0];
						victimVelocity[1] += vortexVelocity[1];
						victimVelocity[2] += vortexVelocity[2];
					}
					
					// cap the player's velocity
					float vel = getLinearVelocity(victimVelocity);
					if (vel > WET_MAX_VELOCITY)
					{
						victimVelocity[0] *= WET_MAX_VELOCITY / vel;
						victimVelocity[1] *= WET_MAX_VELOCITY / vel;
						victimVelocity[2] *= WET_MAX_VELOCITY / vel;
					}
					
					SetEntPropVector(victim, Prop_Data, "m_vecVelocity", victimVelocity);
					TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, victimVelocity);
				}

				Totem_NextSpecialAt[totemIdx] += WET_TORNADO_INTERVAL;
			}
			else
				Totem_NextSpecialAt[totemIdx] += 10.0;
		}

		// visual effect interval
		if (curTime >= Totem_NextVisualAt[totemIdx])
		{
			if (Totem_Type[totemIdx] == ET_FIRE)
			{
				// TODO: Create a local fog controller and manipulate it.
			
				// find a distance and a random yaw for positioning the hellfire visual effect.
				float maxHellfireDistance = Totem_DamageEffectRadius[totemIdx] - FET_HELLFIRE_RADIUS;
				float hellfireDistance = (maxHellfireDistance <= 0.0 ? 0.0 : GetRandomFloat(0.0, maxHellfireDistance));
				static float randomAngle[3];
				randomAngle[0] = 0.0;
				randomAngle[1] = GetRandomFloat(-179.9, 179.9);
				randomAngle[2] = 0.0;
				
				// find the actual point to place the effect
				static float endPos[3];
				Handle trace = TR_TraceRayFilterEx(totemPos, randomAngle, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
				TR_GetEndPosition(endPos, trace);
				CloseHandle(trace);
				ConformLineDistance(endPos, totemPos, endPos, hellfireDistance, true);
				
				// place the effect
				ParticleEffectAt(endPos, "cinefx_goldrush", 3.0);
			}
			else if (Totem_Type[totemIdx] == ET_ICE)
			{
				// TODO: Create a local fog controller and manipulate it.
			}
			else if (Totem_Type[totemIdx] == ET_WIND)
			{
				// TODO: Manipulate the global fog controller.
			
				// simply schedule another particle effect. it'll overlap with the previous, and that's okay
				if (strlen(Totem_VisualEffectParticle[totemIdx]) > 3)
					ParticleEffectAt(totemPos, Totem_VisualEffectParticle[totemIdx], Totem_VisualEffectInterval[totemIdx]);
			}
			else if (Totem_Type[totemIdx] == ET_ELECTRIC)
			{
				// TODO: Manipulate the global fog controller.
				
				// do a random angle trace
				float endPos[3];
				float randomAngle[3];
				randomAngle[0] = GetRandomFloat(-10.0, -1.0);
				randomAngle[1] = GetRandomFloat(-179.9, 179.9);
				randomAngle[2] = 0.0;
				Handle trace = TR_TraceRayFilterEx(totemPos, randomAngle, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
				TR_GetEndPosition(endPos, trace);
				CloseHandle(trace);
				
				// constrain the distance to the specified maximum
				ConformLineDistance(endPos, totemPos, endPos, Totem_VisualEffectRadius[totemIdx]);
				
				// draw the effect
				TE_SetupBeamPoints(totemPos, endPos, EET_BoltMaterial, 0, 0, 0, 0.3, 5.0, 1.0, 0, 15.0, {255,238,7,255}, 3);
				TE_SendToAll();
				
				// see if players get hit
				TE_TmpDamage = Totem_VisualEffectDamage[totemIdx];
				TE_TmpAttacker = Totem_Owner[totemIdx];
				TE_GiveSpeed = (Totem_Flags[totemIdx] & EET_FLAG_SPEED_ON_MINOR_HIT) != 0;
				TE_MaxDistance = Totem_VisualEffectRadius[totemIdx];
				TE_TotemPos[0] = totemPos[0];
				TE_TotemPos[1] = totemPos[1];
				TE_TotemPos[2] = totemPos[2];
				trace = TR_TraceRayFilterEx(totemPos, randomAngle, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceElectric);
				CloseHandle(trace);
			}
		
			Totem_NextVisualAt[totemIdx] += Totem_VisualEffectInterval[totemIdx];
		}
		
		// damage effect interval
		if (curTime >= Totem_NextDamageAt[totemIdx])
		{
			if (Totem_Type[totemIdx] == ET_FIRE)
			{
				// just iterate through living trapped players in range and do damage
				for (int victim = 1; victim < MAX_PLAYERS; victim++)
				{
					if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
						continue;
				
					static float victimOrigin[3];
					GetEntPropVector(victim, Prop_Data, "m_vecOrigin", victimOrigin);
					
					if (CylinderCollision(totemPos, victimOrigin, Totem_DamageEffectRadius[totemIdx], totemPos[2] - 83.0, totemPos[2] + Totem_DamageCylinderHeight[totemIdx]))
					{
						if (!TF2_IsPlayerInCondition(victim, TFCond_Ubercharged))
						{
							TF2_IgnitePlayer(victim, Totem_Owner[totemIdx]);
							TF2_AddCondition(victim, TFCond_OnFire, Totem_AfterburnDuration[totemIdx]);
							ET_RemoveAfterburnAt[victim] = curTime + Totem_AfterburnDuration[totemIdx];
						}
						
						if (Totem_DamageEffectDamage[totemIdx] > 0.0)
							SDKHooks_TakeDamage(victim, Totem_Owner[totemIdx], Totem_Owner[totemIdx], Totem_DamageEffectDamage[totemIdx], DMG_BURN, -1);
					}
				}
			}
			else if (Totem_Type[totemIdx] == ET_WIND)
			{
				// just iterate through living trapped players and do damage
				for (int i = 1; i < MAX_PLAYERS; i++)
				{
					if (Totem_Victims[totemIdx][i])
					{
						if (!IsLivingPlayer(i))
							Totem_Victims[totemIdx][i] = false;
						else
							SDKHooks_TakeDamage(i, Totem_Owner[totemIdx], Totem_Owner[totemIdx], Totem_DamageEffectDamage[totemIdx], DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
					}
				}
			}
			else if (Totem_Type[totemIdx] == ET_ELECTRIC)
			{
				// find a victim
				int victim = FindRandomPlayer(false, totemPos, Totem_DamageEffectRadius[totemIdx]);
				
				if (IsLivingPlayer(victim))
				{
					// get a good position way above the victim to start our lightning bolt
					float victimPos[3];
					GetEntPropVector(victim, Prop_Data, "m_vecOrigin", victimPos);
					float boltStartPos[3];
					boltStartPos[0] = victimPos[0] + GetRandomFloat(-650.0, 650.0);
					boltStartPos[1] = victimPos[1] + GetRandomFloat(-650.0, 650.0);
					boltStartPos[2] = victimPos[2] + 1500.0;
					
					// drain a spy's cloak, if applicable
					if (TF2_GetPlayerClass(victim) == TFClass_Spy && (Totem_Flags[totemIdx] & EET_FLAG_DRAIN_SPIES) != 0)
					{
						SetEntPropFloat(victim, Prop_Send, "m_flCloakMeter", 0.0);
						if (TF2_IsPlayerInCondition(victim, TFCond_DeadRingered))
							TF2_RemoveCondition(victim, TFCond_DeadRingered);
						if (TF2_IsPlayerInCondition(victim, TFCond_Cloaked))
							TF2_RemoveCondition(victim, TFCond_Cloaked);
					}
					
					// fire it off and do damage
					TE_SetupBeamPoints(boltStartPos, victimPos, EET_BoltMaterial, 0, 0, 10, 0.6, 120.0, 1.0, 0, 5.0, {255,238,7,255}, 3);
					TE_SendToAll();
					SDKHooks_TakeDamage(victim, Totem_Owner[totemIdx], Totem_Owner[totemIdx], Totem_DamageEffectDamage[totemIdx], DMG_SHOCK, -1);
					
					// play the sound
					if (strlen(Totem_DamageSound[totemIdx]) > 3)
					{
						EmitSoundToAll(Totem_DamageSound[totemIdx]); // it's lightning. deserves mapwide sound
						EmitSoundToAll(Totem_DamageSound[totemIdx]);
					}
				}
			}
		
			Totem_NextDamageAt[totemIdx] += Totem_DamageEffectInterval[totemIdx];
		}
		
		// looping sound
		if (curTime >= Totem_NextSoundPlayAt[totemIdx] && Totem_NextSoundPlayAt[totemIdx] > 0.0)
		{
			if (strlen(Totem_RepeatingSound[totemIdx]) > 3)
			{
				EmitAmbientSound(Totem_RepeatingSound[totemIdx], totemPos, totem);
				EmitAmbientSound(Totem_RepeatingSound[totemIdx], totemPos, totem);
				EmitAmbientSound(Totem_RepeatingSound[totemIdx], totemPos, totem);
			}
		
			Totem_NextSoundPlayAt[totemIdx] += Totem_SoundRepeatInterval[totemIdx];
		}
		
		// particle on totem
		if (curTime >= Totem_NextParticleAt[totemIdx])
		{
			if (!IsEmptyString(Totem_TotemParticle[totemIdx]))
				ParticleEffectAt(totemPos, Totem_TotemParticle[totemIdx], Totem_TotemParticleInterval[totemIdx]);
			Totem_NextParticleAt[totemIdx] += Totem_TotemParticleInterval[totemIdx];
		}
	}
	
	for (int targetPlayer = 1; targetPlayer < MAX_PLAYERS; targetPlayer++)
	{
		if (!IsLivingPlayer(targetPlayer))
			continue;
	
		if (GetClientTeam(targetPlayer) == BossTeam)
		{
			// uber adjustment.
			if (!shouldUber[targetPlayer] && TF2_IsPlayerInCondition(targetPlayer, TFCond_Ubercharged))
			{
				TF2_RemoveCondition(targetPlayer, TFCond_Ubercharged);
				SetEntProp(targetPlayer, Prop_Data, "m_takedamage", 2);
			}
			else if (shouldUber[targetPlayer] && !TF2_IsPlayerInCondition(targetPlayer, TFCond_Ubercharged))
			{
				TF2_AddCondition(targetPlayer, TFCond_Ubercharged, -1.0);
				SetEntProp(targetPlayer, Prop_Data, "m_takedamage", 0);
			}
		}
		else
		{
			// adjust color first
			if (ET_IsSpeedAdjusted[targetPlayer] && speedAdjust[targetPlayer] == 1.0)
			{
				SetEntityRenderMode(targetPlayer, RENDER_TRANSCOLOR);
				SetEntityRenderColor(targetPlayer, 255, 255, 255, 255);
			}
			else if (!ET_IsSpeedAdjusted[targetPlayer] && speedAdjust[targetPlayer] != 1.0)
			{
				SetEntityRenderMode(targetPlayer, RENDER_TRANSCOLOR);
				SetEntityRenderColor(targetPlayer, 0, 0, 192, 255); // minor alpha
			}
		
			// speed adjustment. note that certain events can force readjustment, like a heavy and their minigun, or baby face's variable speed.
			// it's why checking the expected value is a must.
			if (speedAdjust[targetPlayer] == 1.0 && ET_IsSpeedAdjusted[targetPlayer])
			{
				ET_IsSpeedAdjusted[targetPlayer] = false;
				if (ET_SpeedAdjust[targetPlayer] > 0.0 && ET_SpeedAdjust[targetPlayer] < 1.0)
				{
					float maxspeed = GetEntPropFloat(targetPlayer, Prop_Send, "m_flMaxspeed");
					if (maxspeed == ET_ExpectedSpeed[targetPlayer]) // without this there'd be a super-rare potential glitch where target gets huge speed boost
						SetEntPropFloat(targetPlayer, Prop_Send, "m_flMaxspeed", GetEntPropFloat(targetPlayer, Prop_Send, "m_flMaxspeed") * (1.0 / ET_SpeedAdjust[targetPlayer]));
				}
				ET_SpeedAdjust[targetPlayer] = 1.0;
				ET_ExpectedSpeed[targetPlayer] = -1.0;
			}
			else if (speedAdjust[targetPlayer] != 1.0)
			{
				bool readjust = false;
				if (ET_SpeedAdjust[targetPlayer] == 1.0)
					readjust = true;
				ET_SpeedAdjust[targetPlayer] = speedAdjust[targetPlayer];
				
				float maxspeed = GetEntPropFloat(targetPlayer, Prop_Send, "m_flMaxspeed");
				if (maxspeed != ET_ExpectedSpeed[targetPlayer])
					readjust = true;
					
				if (readjust)
				{
					maxspeed *= ET_SpeedAdjust[targetPlayer];
					SetEntPropFloat(targetPlayer, Prop_Send, "m_flMaxspeed", maxspeed);
				}
				ET_ExpectedSpeed[targetPlayer] = maxspeed;
				ET_IsSpeedAdjusted[targetPlayer] = true;
			}
		}
	}
}

public void IncrementTotemSelection(int clientIdx)
{
	for (int i = 1; i <= ET_TYPE_COUNT; i++)
	{
		int nextSelection = (ET_CurrentSelection[clientIdx] + i) % ET_TYPE_COUNT;
		if (nextSelection == ET_FIRE && ET_FireEnabled[clientIdx])
		{
			ET_CurrentSelection[clientIdx] = nextSelection;
			break;
		}
		else if (nextSelection == ET_ICE && ET_IceEnabled[clientIdx])
		{
			ET_CurrentSelection[clientIdx] = nextSelection;
			break;
		}
		else if (nextSelection == ET_WIND && ET_WindEnabled[clientIdx])
		{
			ET_CurrentSelection[clientIdx] = nextSelection;
			break;
		}
		else if (nextSelection == ET_ELECTRIC && ET_ElectricEnabled[clientIdx])
		{
			ET_CurrentSelection[clientIdx] = nextSelection;
			break;
		}
	}
}

public void RemoveTotemAt(int totemIdx)
{
	if (Totem_EntRef[totemIdx] != 0)
		Timer_RemoveEntity(null, Totem_EntRef[totemIdx]);
	if (Totem_DynamicLight[totemIdx] != 0)
		Timer_RemoveEntity(null, Totem_DynamicLight[totemIdx]);

	for (int i = totemIdx; i < MAX_TOTEMS - 1; i++)
	{
		Totem_Type[i] = Totem_Type[i+1];
		Totem_EntRef[i] = Totem_EntRef[i+1];
		Totem_ExpiresAt[i] = Totem_ExpiresAt[i+1];
		Totem_NextSpecialAt[i] = Totem_NextSpecialAt[i+1];
		Totem_VisualEffectRadius[i] = Totem_VisualEffectRadius[i+1];
		Totem_VisualEffectInterval[i] = Totem_VisualEffectInterval[i+1];
		Totem_VisualEffectDamage[i] = Totem_VisualEffectDamage[i+1];
		Totem_VisualEffectParticle[i] = Totem_VisualEffectParticle[i+1];
		Totem_DamageEffectRadius[i] = Totem_DamageEffectRadius[i+1];
		Totem_DamageEffectInterval[i] = Totem_DamageEffectInterval[i+1];
		Totem_DamageEffectDamage[i] = Totem_DamageEffectDamage[i+1];
		Totem_SkyDarkenPercent[i] = Totem_SkyDarkenPercent[i+1];
		Totem_RepeatingSound[i] = Totem_RepeatingSound[i+1];
		Totem_SoundRepeatInterval[i] = Totem_SoundRepeatInterval[i+1];
		Totem_DamageSound[i] = Totem_DamageSound[i+1];
		Totem_NextVisualAt[i] = Totem_NextVisualAt[i+1];
		Totem_NextDamageAt[i] = Totem_NextDamageAt[i+1];
		Totem_NextSoundPlayAt[i] = Totem_NextSoundPlayAt[i+1];
		Totem_Flags[i] = Totem_Flags[i+1];
		Totem_Owner[i] = Totem_Owner[i+1];
		Totem_KnockbackIntensity[i] = Totem_KnockbackIntensity[i+1];
		Totem_NextInternalAt[i] = Totem_NextInternalAt[i+1];
		Totem_DamageCylinderHeight[i] = Totem_DamageCylinderHeight[i+1];
		Totem_AfterburnDuration[i] = Totem_AfterburnDuration[i+1];
		Totem_SlowdownFactor[i] = Totem_SlowdownFactor[i+1];
		Totem_DynamicLight[i] = Totem_DynamicLight[i+1];
		for (int j = 1; j < MAX_PLAYERS; j++)
			Totem_Victims[i][j] = Totem_Victims[i+1][j];
	}
	
	Totem_Type[MAX_TOTEMS - 1] = -1;
	Totem_EntRef[MAX_TOTEMS - 1] = 0;
}

public void Rage_ElementalTotem(int bossIdx)
{
	int clientIdx = bossIdx;
	if (!ET_CanUse[clientIdx]) // got disabled for some reason
		return;
	
	// find a free totem
	int totemIdx = -1;
	for (int i = 0; i < MAX_TOTEMS; i++)
	{
		if (Totem_Type[i] == -1)
		{
			totemIdx = i;
			break;
		}
	}
	
	// delete the oldest totem
	if (totemIdx == -1)
	{
		totemIdx = MAX_TOTEMS - 1;
		RemoveTotemAt(0);
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods5] Major ragespam. Boss somehow exceeded max totems.");
	}
	
	// initialize certain things where there's no checking if a particular totem supports it
	char modelName[MAX_MODEL_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ET_STRING, 6 + ET_CurrentSelection[clientIdx], modelName, MAX_MODEL_FILE_LENGTH);
	float duration = 0.0;
	float sentryStunRadius = 0.0;
	float buildingDestroyRadius = 0.0;
	Totem_SkyDarkenPercent[totemIdx] = 0.0;
	Totem_RepeatingSound[totemIdx] = "";
	Totem_DamageSound[totemIdx] = "";
	Totem_SoundRepeatInterval[totemIdx] = 1.0;
	Totem_SlowdownFactor[totemIdx] = 1.0;
	Totem_NextSoundPlayAt[totemIdx] = GetGameTime();
	Totem_NextSpecialAt[totemIdx] = GetGameTime();
	Totem_NextInternalAt[totemIdx] = GetGameTime();
	Totem_DynamicLight[totemIdx] = 0;
	Totem_Flags[totemIdx] = 0;
	for (int j = 1; j < MAX_PLAYERS; j++)
		Totem_Victims[totemIdx][j] = false;
		
	// need boss pos, and the no Z version for sentry manipulation
	float bossOrigin[3];
	GetEntPropVector(clientIdx, Prop_Data, "m_vecOrigin", bossOrigin);
	float bossPosNoZ[3];
	bossPosNoZ[0] = bossOrigin[0];
	bossPosNoZ[1] = bossOrigin[1];
	bossPosNoZ[2] = 0.0;
	
	// fog and extra particle which is intended for weather
	float targetDensity = 0.0;
	int targetColor = ET_FOG_DEFAULT_COLOR;
	char weatherEffect[MAX_EFFECT_NAME_LENGTH];
	float weatherZOffset = 0.0;
		
	if (ET_CurrentSelection[clientIdx] == ET_FIRE)
	{
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods5] %d created a fire totem.", clientIdx);
			
		duration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FET_STRING, 1);
		sentryStunRadius = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FET_STRING, 2);
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, FET_STRING, 3, Totem_RepeatingSound[totemIdx], MAX_SOUND_FILE_LENGTH);
		Totem_SoundRepeatInterval[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FET_STRING, 4);
		Totem_DamageEffectRadius[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FET_STRING, 5);
		Totem_DamageEffectDamage[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FET_STRING, 6);
		Totem_DamageEffectInterval[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FET_STRING, 7);
		Totem_DamageCylinderHeight[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FET_STRING, 8);
		Totem_AfterburnDuration[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FET_STRING, 9);
		Totem_VisualEffectInterval[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FET_STRING, 10);
		
		weatherZOffset = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FET_STRING, 13);
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, FET_STRING, 14, weatherEffect, MAX_EFFECT_NAME_LENGTH);
		targetColor = ReadHexOrDecString(bossIdx, FET_STRING, 15);
		targetDensity = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FET_STRING, 16);

		// particle on totem
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, FET_STRING, 17, Totem_TotemParticle[totemIdx], MAX_EFFECT_NAME_LENGTH);
		Totem_TotemParticleInterval[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FET_STRING, 18);
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods5] Spawning a fire totem. damRad=%f damDmg=%f damDelta=%f visDelta=%f", Totem_DamageEffectRadius[totemIdx], Totem_DamageEffectDamage[totemIdx], Totem_DamageEffectInterval[totemIdx], Totem_VisualEffectInterval[totemIdx]);
	}
	else if (ET_CurrentSelection[clientIdx] == ET_ICE)
	{
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods5] %d created an ice totem.", clientIdx);
			
		duration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, IET_STRING, 1);
		sentryStunRadius = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, IET_STRING, 2);
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, IET_STRING, 3, Totem_RepeatingSound[totemIdx], MAX_SOUND_FILE_LENGTH);
		Totem_SoundRepeatInterval[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, IET_STRING, 4);
		Totem_VisualEffectRadius[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, IET_STRING, 5);
		Totem_SlowdownFactor[totemIdx] = (100.0 - FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, IET_STRING, 6)) / 100.0;
		
		weatherZOffset = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, IET_STRING, 13);
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, IET_STRING, 14, weatherEffect, MAX_EFFECT_NAME_LENGTH);
		targetColor = ReadHexOrDecString(bossIdx, IET_STRING, 15);
		targetDensity = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, IET_STRING, 16);

		// particle on totem
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, IET_STRING, 17, Totem_TotemParticle[totemIdx], MAX_EFFECT_NAME_LENGTH);
		Totem_TotemParticleInterval[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, IET_STRING, 18);
		
		Totem_Flags[totemIdx] = ReadHexOrDecString(bossIdx, IET_STRING, 19);
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods5] Spawning an ice totem. visRad=%f slowdown=%f", Totem_VisualEffectRadius[totemIdx], Totem_SlowdownFactor[totemIdx]);
	}
	else if (ET_CurrentSelection[clientIdx] == ET_WIND)
	{
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods5] %d created a wind totem.", clientIdx);
	
		duration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WET_STRING, 1);
		buildingDestroyRadius = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WET_STRING, 2);
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, WET_STRING, 3, Totem_RepeatingSound[totemIdx], MAX_SOUND_FILE_LENGTH);
		Totem_SoundRepeatInterval[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WET_STRING, 4);
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, WET_STRING, 5, Totem_VisualEffectParticle[totemIdx], MAX_EFFECT_NAME_LENGTH);
		Totem_VisualEffectInterval[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WET_STRING, 6);
		Totem_DamageEffectRadius[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WET_STRING, 7);
		Totem_DamageEffectDamage[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WET_STRING, 8);
		Totem_DamageEffectInterval[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WET_STRING, 9);
		Totem_KnockbackIntensity[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WET_STRING, 10);
		
		weatherZOffset = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WET_STRING, 13);
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, WET_STRING, 14, weatherEffect, MAX_EFFECT_NAME_LENGTH);
		targetColor = ReadHexOrDecString(bossIdx, WET_STRING, 15);
		targetDensity = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WET_STRING, 16);

		// particle on totem
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, WET_STRING, 17, Totem_TotemParticle[totemIdx], MAX_EFFECT_NAME_LENGTH);
		Totem_TotemParticleInterval[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WET_STRING, 18);
		
		WindTotemFindNewVictims(totemIdx, bossOrigin);
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods5] Spawning a wind totem. damRad=%f damDmg=%f damDelta=%f visDelta=%f knockback=%f", Totem_DamageEffectRadius[totemIdx], Totem_DamageEffectDamage[totemIdx], Totem_DamageEffectInterval[totemIdx], Totem_VisualEffectInterval[totemIdx], Totem_KnockbackIntensity[totemIdx]);
	}
	else if (ET_CurrentSelection[clientIdx] == ET_ELECTRIC)
	{
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods5] %d created an electric totem.", clientIdx);
	
		duration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EET_STRING, 1);
		sentryStunRadius = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EET_STRING, 2);
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, EET_STRING, 3, Totem_RepeatingSound[totemIdx], MAX_SOUND_FILE_LENGTH);
		Totem_SoundRepeatInterval[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EET_STRING, 4);
		Totem_VisualEffectRadius[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EET_STRING, 5);
		Totem_VisualEffectDamage[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EET_STRING, 6);
		Totem_VisualEffectInterval[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EET_STRING, 7);
		Totem_SkyDarkenPercent[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EET_STRING, 8);
		Totem_DamageEffectRadius[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EET_STRING, 9);
		Totem_DamageEffectDamage[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EET_STRING, 10);
		Totem_DamageEffectInterval[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EET_STRING, 11);
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, EET_STRING, 12, Totem_DamageSound[totemIdx], MAX_SOUND_FILE_LENGTH);
		
		weatherZOffset = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EET_STRING, 13);
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, EET_STRING, 14, weatherEffect, MAX_EFFECT_NAME_LENGTH);
		targetColor = ReadHexOrDecString(bossIdx, EET_STRING, 15);
		targetDensity = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EET_STRING, 16);

		// particle on totem
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, EET_STRING, 17, Totem_TotemParticle[totemIdx], MAX_EFFECT_NAME_LENGTH);
		Totem_TotemParticleInterval[totemIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EET_STRING, 18);
		
		Totem_Flags[totemIdx] = ReadHexOrDecString(bossIdx, EET_STRING, 19);
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods5] Spawning an electric totem. damRad=%f damDmg=%f damDelta=%f visRad=%f visDmg=%f visDelta=%f", Totem_DamageEffectRadius[totemIdx], Totem_DamageEffectDamage[totemIdx], Totem_DamageEffectInterval[totemIdx], Totem_VisualEffectRadius[totemIdx], Totem_VisualEffectDamage[totemIdx], Totem_VisualEffectInterval[totemIdx]);
	}
	
	// various sanity checks
	if (duration <= 0.0)
		PrintToServer("[sarysamods5] ERROR: Duration for %s is 0.0 or less. Rage won't execute.", ET_STRING);
	else if (strlen(modelName) <= 3)
		PrintToServer("[sarysamods5] ERROR: Invalid model name for %s. Rage won't execute.", ET_STRING);
	else // success! spawn the totem.
	{
		Totem_Type[totemIdx] = ET_CurrentSelection[clientIdx];
		Totem_ExpiresAt[totemIdx] = GetGameTime() + duration;
		Totem_Owner[totemIdx] = clientIdx;
		Totem_NextVisualAt[totemIdx] = GetGameTime() + Totem_VisualEffectInterval[totemIdx];
		Totem_NextDamageAt[totemIdx] = GetGameTime() + Totem_DamageEffectInterval[totemIdx];
		Totem_NextParticleAt[totemIdx] = GetGameTime();
		
		// fog
		ET_FogTransitionElapsed = 0.0;
		ET_FogStartingDensity = ET_FogCurrentDensity;
		ET_FogStartingColor = ET_FogCurrentColor;
		ET_FogTargetDensity = targetDensity;
		ET_FogTargetColor = targetColor;
		ET_FogExpiresAt = fmax(ET_FogExpiresAt, Totem_ExpiresAt[totemIdx]);
		
		// use a trace to determine where to spawn it
		float spawnPos[3];
		Handle trace = TR_TraceRayFilterEx(bossOrigin, view_as<float>({90.0,0.0,0.0}), (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
		TR_GetEndPosition(spawnPos, trace);
		CloseHandle(trace);
		spawnPos[2] += 10.0; // lift it up a little in case of uneven ground
		
		// extra particle
		if (!IsEmptyString(weatherEffect))
		{
			float weatherSpawnPos[3];
			weatherSpawnPos[0] = spawnPos[0];
			weatherSpawnPos[1] = spawnPos[1];
			weatherSpawnPos[2] = spawnPos[2] + weatherZOffset;
			ParticleEffectAt(weatherSpawnPos, weatherEffect, duration);
		}
		
		// drop a totem at the boss' position, same collision properties as the rocks
		int totem = CreateEntityByName("prop_physics_override");
		if (IsValidEntity(totem))
		{
			// the actual spawning process
			SetEntityModel(totem, modelName);
			DispatchSpawn(totem);
			TeleportEntity(totem, spawnPos, view_as<float>({0.0,0.0,0.0}), view_as<float>({0.0,0.0,0.0}));
			SetEntProp(totem, Prop_Data, "m_takedamage", 0);

			// spawn it immobile
			SetEntityMoveType(totem, MOVETYPE_NONE);
			SetEntProp(totem, Prop_Send, "m_CollisionGroup", 0);
			SetEntProp(totem, Prop_Send, "m_usSolidFlags", 4); // not solid
			SetEntProp(totem, Prop_Send, "m_nSolidType", 0); // not solid
			
			// store ent ref
			Totem_EntRef[totemIdx] = EntIndexToEntRef(totem);
			
			// create dynamic light for fire and ice
			if (ET_CurrentSelection[clientIdx] == ET_FIRE || ET_CurrentSelection[clientIdx] == ET_ICE)
			{
				// need to find a suitable spawn position. spawning low looks like shit in a hilly situation.
				float tracePos[3];
				trace = TR_TraceRayFilterEx(bossOrigin, view_as<float>({-90.0,0.0,0.0}), MASK_PLAYERSOLID, RayType_Infinite, TraceWallsOnly);
				TR_GetEndPosition(tracePos, trace);
				CloseHandle(trace);
				float lightingPos[3];
				lightingPos[0] = spawnPos[0];
				lightingPos[1] = spawnPos[1];
				lightingPos[2] = spawnPos[2] + fmin(400.0, (tracePos[2] - spawnPos[2]) * 0.5);
			
				Totem_DynamicLight[totemIdx] = CreateEntityByName("light_dynamic");
				if (IsValidEntity(Totem_DynamicLight[totemIdx]))
				{
					if (ET_CurrentSelection[clientIdx] == ET_FIRE)
					{
						DispatchKeyValue(Totem_DynamicLight[totemIdx], "_light", "255 0 0"); 
						DispatchKeyValue(Totem_DynamicLight[totemIdx], "brightness", "10"); 
						DispatchKeyValue(Totem_DynamicLight[totemIdx], "style", "1");
						DispatchKeyValueFloat(Totem_DynamicLight[totemIdx], "distance", Totem_DamageEffectRadius[totemIdx]);
					}
					else if (ET_CurrentSelection[clientIdx] == ET_ICE)
					{
						DispatchKeyValue(Totem_DynamicLight[totemIdx], "_light", "0 255 255"); 
						DispatchKeyValue(Totem_DynamicLight[totemIdx], "brightness", "10"); 
						DispatchKeyValue(Totem_DynamicLight[totemIdx], "style", "0");
						DispatchKeyValueFloat(Totem_DynamicLight[totemIdx], "distance", Totem_VisualEffectRadius[totemIdx]);
					}
					
					TeleportEntity(Totem_DynamicLight[totemIdx], lightingPos, NULL_VECTOR, NULL_VECTOR);
					DispatchSpawn(Totem_DynamicLight[totemIdx]); 

					if (PRINT_DEBUG_SPAM)
						PrintToServer("[sarysamods5] Created dynamic lighting for a totem: %d", Totem_DynamicLight[totemIdx]);
				}
				else
				{
					Totem_DynamicLight[totemIdx] = 0;
					PrintToServer("[sarysamods5] WARNING: Failed to create dynamic lighting for totem.");
				}
			}
			
			// set the gravity high so it'll fall completely within 0.5 seconds
			SetEntityGravity(totem, 10.0);
		}
		
		// destroy buildings in a cylinder, in other words ignore Z
		if (buildingDestroyRadius > 0.0)
		{
			for (int i = 0; i < 3; i++)
			{
				char destroyType[32] = "obj_sentrygun";
				if (i == 1) destroyType = "obj_dispenser";
				else if (i == 2) destroyType = "obj_teleporter";
				
				int building = -1;
				while ((building = FindEntityByClassname(building, destroyType)) != -1)
				{
					// ensure the building is in range
					static float buildingPosNoZ[3];
					GetEntPropVector(building, Prop_Send, "m_vecOrigin", buildingPosNoZ);
					buildingPosNoZ[2] = 0.0;
					float distance = GetVectorDistance(bossPosNoZ, buildingPosNoZ);
					if (distance > buildingDestroyRadius)
						continue;

					// this automatically ignores carried buildings, which is what I want
					SDKHooks_TakeDamage(building, clientIdx, clientIdx, 5000.0, DMG_GENERIC, -1);
				}
			}
		}
		
		// stun the sentries in a cylinder, in other words ignore Z
		if (sentryStunRadius > 0.0)
		{
			// taken directly from default_abilities, shrunk, ...and fixed. lol guess 1.9.2 was buggy.
			// this iteration is the same that whooves uses, but with a radius limitation
			// note that Z is tossed away
			int sentry = -1;
			while ((sentry = FindEntityByClassname(sentry, "obj_sentrygun")) != -1)
			{
				float sentryPos[3];
				float sentryPosNoZ[3];
				GetEntPropVector(sentry, Prop_Data, "m_vecOrigin", sentryPos);
				GetEntPropVector(sentry, Prop_Data, "m_vecOrigin", sentryPosNoZ);
				sentryPosNoZ[2] = 0.0;
			
				if (GetVectorDistance(bossPosNoZ, sentryPosNoZ) <= sentryStunRadius)
				{
					// modified on 2015-03-23, handing the stun job off to dynamic defaults
					DSSG_PerformStunFromCoords(clientIdx, sentryPos, 1.0, duration);
				}
			}
		}
	}
}

/**
 * Teleport to Spawn
 */
public Action TTS_OnTakeDamage(int victim, int& attacker, int& inflictor, 
							float& damage, int& damagetype, int& weapon,
							float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsLivingPlayer(victim)) // wtf
		return Plugin_Continue;

	if (attacker <= 0 || attacker >= MAX_PLAYERS)
	{
		char classname[MAX_ENTITY_CLASSNAME_LENGTH];
		if (attacker >= MAX_PLAYERS)
			GetEntityClassname(attacker, classname, sizeof(classname));
	
		if (strcmp(classname, "obj_sentrygun")) // world damage is anything not from a sentry
		{
			if (damage > TTS_MinimumDamage[victim])
			{
				// find a random spawn point
				//int spawn = FindRandomSpawn(true, TTS_AlsoUseRedSpawn[victim] && GetGameTime() >= TTS_AllowRedSpawnAt[victim]);
				//if (!IsValidEntity(spawn))
				//{
				//	PrintToServer("[sarysamods5] TTS failed to find a player spawn?!");
				//	return Plugin_Continue;
				//}
				//float spawnOrigin[3];
				//GetEntPropVector(spawn, Prop_Data, "m_vecOrigin", spawnOrigin);
				//TeleportEntity(victim, spawnOrigin, NULL_VECTOR, view_as<float>({0.0,0.0,0.0})); // teleport needs to remove velocity
				
				// reassign damage to a random player?
				if (TTS_OverrideVSPMethod[victim])
				{
					int randomMerc = SS_FindAttacker(false);
					if (IsValidEntity(randomMerc))
					{
						SemiHookedDamage(victim, randomMerc, randomMerc, damage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE);
						return Plugin_Handled;
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

/**
 * OnPlayerRunCmd/OnGameFrame
 */
#define IMPERFECT_FLIGHT_FACTOR 25
public void OnGameFrame()
{
	if (!PluginActiveThisRound || !RoundInProgress)
		return;
		
	float curTime = GetGameTime();

	if (SS_ActiveThisRound)
	{
		if (SS_NextSpawnAt <= curTime)
		{
			if (SS_EntRef != 0)
			{
				Timer_RemoveEntity(null, SS_EntRef);
				SS_EntRef = 0;
				
				if (PRINT_DEBUG_SPAM)
					PrintToServer("[sarysamods5] Deleted an expired Sapphire Stone.");
			}
		
			// spawn the sapphire statue somewhere on the map
			int spawnIdx = GetRandomInt(0, SS_SpawnLocationCount - 1);
			int stoneEntity = CreateEntityByName("prop_physics_override");
			if (IsValidEntity(stoneEntity))
			{
				SS_ActivePosition[0] = SS_Spawn[spawnIdx][0];
				SS_ActivePosition[1] = SS_Spawn[spawnIdx][1];
				SS_ActivePosition[2] = SS_Spawn[spawnIdx][2];
			
				// the actual spawning process
				SetEntityModel(stoneEntity, SS_MainModel);
				DispatchSpawn(stoneEntity);
				TeleportEntity(stoneEntity, SS_ActivePosition, NULL_VECTOR, NULL_VECTOR);
				SetEntProp(stoneEntity, Prop_Data, "m_takedamage", 0);

				SetEntityMoveType(stoneEntity, MOVETYPE_NONE);
				SetEntProp(stoneEntity, Prop_Send, "m_CollisionGroup", 0);
				SetEntProp(stoneEntity, Prop_Send, "m_usSolidFlags", 4);
				SetEntProp(stoneEntity, Prop_Send, "m_nSolidType", 0);
				
				// notify all players and the hale that it exists. it's a one time HUD message.
				SS_SetHUDMessage(SS_HUD_MSG_APPEARED);
				SS_HUDNumMercs = 0;
				SS_HUDMercsRequired = SS_GetNumPlayersRequired();
				
				// play the sound
				if (strlen(SS_StoneSpawnSound) > 3)
				{
					EmitSoundToAll(SS_StoneSpawnSound);
					EmitSoundToAll(SS_StoneSpawnSound);
				}
				
				// save the entity ref
				SS_EntRef = EntIndexToEntRef(stoneEntity);
				
				// next beacon time
				SS_NextBeaconAt = curTime + SS_BEACON_DELAY;
				
				// notify
				if (PRINT_DEBUG_INFO)
					PrintToServer("[sarysamods5] Spawned a sapphire stone!");
			}
			
			// if the interval passes and no one triggers the event, assume it's in a terrible location
			// if it's a rage then this will not happen
			SS_NextSpawnAt = curTime + SS_EventInterval;
		}
		else if (SS_EntRef != 0) // intentionally withhold this until the next tick
		{
			// check everyone's location and compare it with the hale's
			int nearBossCount = 0;
			int nearMercCount = 0;
			int livingMercCount = 0;
			
			for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
			{
				if (IsLivingPlayer(clientIdx))
				{
					if (GetClientTeam(clientIdx) != BossTeam)
						livingMercCount++;
						
					static float clientOrigin[3];
					GetEntPropVector(clientIdx, Prop_Data, "m_vecOrigin", clientOrigin);
					if (CylinderCollision(SS_ActivePosition, clientOrigin, SS_StoneCollisionRadius, SS_ActivePosition[2] - 103.0, SS_ActivePosition[2] + 150.0))
					{
						if (GetClientTeam(clientIdx) == BossTeam)
							nearBossCount++;
						else
							nearMercCount++;
					}
				}
			}
			
			// how many players are required to activate?
			int requiredPlayers = SS_GetNumPlayersRequired();
			
			// priority goes to the boss
			if (nearBossCount > 0)
			{
				if (PRINT_DEBUG_SPAM)
					PrintToServer("[sarysamods5] Boss found the stone!");
					
				SS_SetHUDMessage(SS_HUD_MSG_BOSS_FOUND);
				SS_StartEvent(true);
				
				// push back the next trigger
				SS_NextSpawnAt = curTime + SS_EventInterval;
			}
			else if (nearMercCount >= requiredPlayers)
			{
				SS_SetHUDMessage(SS_HUD_MSG_MERCS_FOUND);
				SS_StartEvent(false);
				
				// push back the next trigger
				SS_NextSpawnAt = curTime + SS_EventInterval;
			}
			else if (nearMercCount != SS_HUDNumMercs || requiredPlayers != SS_HUDMercsRequired)
			{
				if (nearMercCount == 0)
					SS_SetHUDMessage(SS_HUD_MSG_APPEARED);
				else
					SS_SetHUDMessage(SS_HUD_MSG_NUM_MERCS_ON_STONE);
				SS_HUDNumMercs = nearMercCount;
				SS_HUDMercsRequired = requiredPlayers;
			}
		}
		
		// display the beacon if valid
		if (SS_EntRef != 0 && (SS_Flags & SS_FLAG_BEACON) != 0)
		{
			if (curTime >= SS_NextBeaconAt)
			{
				SS_NextBeaconAt = curTime + SS_BEACON_DELAY;
				
				// ripped straight from RTD beacon, since it's the kind everyone's familiar with already
				float beaconPos[3];
				beaconPos[0] = SS_ActivePosition[0];
				beaconPos[1] = SS_ActivePosition[1];
				beaconPos[2] = SS_ActivePosition[2] + 10.0;

				TE_SetupBeamRingPoint(beaconPos, 10.0, SS_StoneCollisionRadius, BEACON_BEAM, BEACON_HALO, 0, 15, 0.5, 5.0, 0.0, {128,128,128,255}, 10, 0);
				TE_SendToAll();
				TE_SetupBeamRingPoint(beaconPos, 10.0, SS_StoneCollisionRadius, BEACON_BEAM, BEACON_HALO, 0, 10, 0.6, 10.0, 0.5, {75,75,255,255}, 10, 0);
				TE_SendToAll();

				int stoneEntity = EntRefToEntIndex(SS_EntRef);
				if (IsValidEntity(stoneEntity))
				{
					EmitSoundToAll(SS_BEACON_SOUND, stoneEntity);
					EmitSoundToAll(SS_BEACON_SOUND, stoneEntity);
					EmitSoundToAll(SS_BEACON_SOUND, stoneEntity);
				}
			}
		}
		
		// to keep this method from being cluttered, other timed events are managed here
		SS_RefreshHUD(curTime);
		SS_SpawnRocks(curTime);
		SS_TickRocks(curTime);
	}
	
	if (ET_ActiveThisRound)
	{
		TickTotems(curTime);
		TickFog(curTime);
		
		// remove afterburn, since messing with OnFire duration doesn't work
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsLivingPlayer(clientIdx) && ET_RemoveAfterburnAt[clientIdx] <= curTime)
			{
				if (TF2_IsPlayerInCondition(clientIdx, TFCond_OnFire))
					TF2_RemoveCondition(clientIdx, TFCond_OnFire);
				ET_RemoveAfterburnAt[clientIdx] = FAR_FUTURE;
			}
		}
	}
}
 
public Action OnPlayerRunCmd(int clientIdx, int& buttons, int& impulse, 
							float vel[3], float ang[3], int& weapon, 
							int &subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (!PluginActiveThisRound || !RoundInProgress || !IsLivingPlayer(clientIdx))
		return Plugin_Continue;
		
	if (ET_ActiveThisRound && ET_CanUse[clientIdx])
	{
		// reload key increments totem selection
		bool reloadDown = (buttons & IN_RELOAD) != 0;
		if (reloadDown && !ET_ReloadDown[clientIdx])
			IncrementTotemSelection(clientIdx);
		ET_ReloadDown[clientIdx] = reloadDown;
		
		// draw the HUD
		DrawTotemHUD(clientIdx);
	}
	
	// since hookshot reacts mainly to player commands, it's managed here
	if (HS_ActiveThisRound && HS_CanUse[clientIdx])
	{
		float curTime = GetGameTime();
		float deltaTime = curTime - HS_LastUpdateAt[clientIdx];
		if (deltaTime >= 0.01) // ignore extremely small updates
		{
			int bossIdx = FF2_GetBossIndex(clientIdx);
		
			bool altFireDown = ((buttons & IN_ATTACK2) != 0);
			bool altFirePressed = !HS_AltFireDown[clientIdx] && altFireDown;
			//bool altFireReleased = HS_AltFireDown[clientIdx] && !altFireDown;
			bool duckDown = ((buttons & IN_DUCK) != 0);
			//bool duckPressed = !HS_DuckKeyDown[clientIdx] && duckDown;
			//bool duckReleased = HS_DuckKeyDown[clientIdx] && !duckDown;
			bool jumpDown = ((buttons & IN_JUMP) != 0);
			bool jumpPressed = !HS_JumpKeyDown[clientIdx] && jumpDown;
			//bool jumpReleased = HS_JumpKeyDown[clientIdx] && !jumpDown;
			bool forwardDown = ((buttons & IN_FORWARD) != 0);
			bool backDown = ((buttons & IN_BACK) != 0);
			bool validHSState = HS_IsValidHookshotState(clientIdx); //(GetEntityFlags(clientIdx) & FL_ONGROUND) != 0;

			bool ignoreBossActions = TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed);

			float currentRage = FF2_GetBossCharge(bossIdx, 0);

			if (HS_HookshotOut[clientIdx])
			{
				// ensure their eyes still have line of sight with the hook
				static float eyeOrigin[3];
				GetClientEyePosition(clientIdx, eyeOrigin);
				static float angles[3];
				GetVectorAnglesTwoPoints(eyeOrigin, HS_HookPosition[clientIdx], angles);

				Handle trace = TR_TraceRayFilterEx(eyeOrigin, angles, MASK_PLAYERSOLID, RayType_Infinite, TraceWallsOnly);
				static float tmpPos[3];
				TR_GetEndPosition(tmpPos, trace);
				CloseHandle(trace);

				// actual line-of-sight test
				bool losTestFailed = false;
				losTestFailed = losTestFailed || (fabs(tmpPos[0] - HS_HookPosition[clientIdx][0]) > HS_ROPE_TOP_DISCREPANCY_ALLOWANCE);
				losTestFailed = losTestFailed || (fabs(tmpPos[1] - HS_HookPosition[clientIdx][1]) > HS_ROPE_TOP_DISCREPANCY_ALLOWANCE);
				losTestFailed = losTestFailed || (fabs(tmpPos[2] - HS_HookPosition[clientIdx][2]) > HS_ROPE_TOP_DISCREPANCY_ALLOWANCE);

				// but make sure the distance isn't greater
				if (losTestFailed && GetVectorDistance(eyeOrigin, HS_HookPosition[clientIdx], true) < GetVectorDistance(eyeOrigin, tmpPos, true))
					losTestFailed = false; // since we're using absolute value, it's okay if the trace goes beyond the hook and this must be considered.

				// debug
				if (PRINT_DEBUG_SPAM && losTestFailed)
					PrintToServer("[sarysamods5] Line-of-sight test failed. hook=(%f,%f,%f) trace=(%f,%f,%f) angles=(%f,%f,0)",
							HS_HookPosition[clientIdx][0], HS_HookPosition[clientIdx][1], HS_HookPosition[clientIdx][2], 
							tmpPos[0], tmpPos[1], tmpPos[2], angles[0], angles[1]);

				if (losTestFailed)
					CancelHookshot(clientIdx, true, HS_ERROR_ROPE_SNAPPED);
				else if (!validHSState)
				{
					CancelHookshot(clientIdx, true, HS_ERROR_HIT_GROUND);

					// may end up being redundant, but this case will always be true
					HS_UsableAt[clientIdx] = curTime + HS_Cooldown[clientIdx];
				}
				else if (jumpPressed && !ignoreBossActions) // would be too clunky to use jumpDown here
					CancelHookshot(clientIdx, false, HS_ERROR_NONE);
				else if (curTime >= HS_HookshotFiredAt[clientIdx] + HS_MaxSwingDuration[clientIdx])
					CancelHookshot(clientIdx, true, HS_ERROR_TIME_LIMIT);

				// if hookshot hasn't been cancelled, lets continue
				if (HS_HookshotOut[clientIdx])
				{
					// need our check delta, not main update delta
					float checkDelta = curTime - HS_LastCheckAt[clientIdx];

					// need the current distance
					static float clientOrigin[3];
					GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", clientOrigin);
					float distance = GetVectorDistance(clientOrigin, HS_HookPosition[clientIdx]);

					// reel in?
					if (altFireDown && !ignoreBossActions)
						HS_HookshotReelDistance[clientIdx] = fmax(HS_MIN_LENGTH, HS_HookshotReelDistance[clientIdx] - (deltaTime * HS_ReelInSpeed[clientIdx]));

					// reel out? if both keys are pressed at once, then do both at once. :P
					if (duckDown && !ignoreBossActions)
						HS_HookshotReelDistance[clientIdx] = HS_HookshotReelDistance[clientIdx] + (deltaTime * HS_ReelInSpeed[clientIdx]);

					float excessDistance = distance - HS_HookshotReelDistance[clientIdx];
					float limpDistance = HS_HookshotReelDistance[clientIdx] - distance;

					// we do a number of checks in here. however, if the rope is limp, none of these checks apply.
					if (checkDelta >= HS_CHECK_INTERVAL && limpDistance < HS_LIMP_MIN_DISTANCE)
					{
						// get the player's current velocity
						static float bossVelocity[3];
						GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", bossVelocity);

						// degrade excess negative z, but only if there's excess distance
						if (bossVelocity[2] < 0 && excessDistance > 0.0)
							bossVelocity[2] *= HS_NegativeZDegradationFactor[clientIdx];

						// horizontal pull first. I'd rather keep the variables here limited in scope.
						// and also keep the indentation the same as the other velocity tweaks
						// though this always executes
						{
							// need adjust positions of things that 
							static float adjustedBossPos[3];
							adjustedBossPos[0] = clientOrigin[0];
							adjustedBossPos[1] = clientOrigin[1];
							adjustedBossPos[2] = 0.0;
							static float adjustedHookPos[3];
							adjustedHookPos[0] = HS_HookPosition[clientIdx][0];
							adjustedHookPos[1] = HS_HookPosition[clientIdx][1];
							adjustedHookPos[2] = 0.0;

							// get our velocity vector and normalize it
							static float elasticVelocity[3];
							MakeVectorFromPoints(clientOrigin, HS_HookPosition[clientIdx], elasticVelocity);
							NormalizeVector(elasticVelocity, elasticVelocity);

							// the pull in HUPS factors in the length of the rope. if I used a static speed,
							// the physics would seem screwy with long vs. short ropes
							for (int axis = 0; axis <= 1; axis++)
							{
								elasticVelocity[axis] *= ((HS_HorizontalMotionFactor[clientIdx] * HS_HookshotReelDistance[clientIdx]) * checkDelta);

								// add this to the player's current velocity. no limits.
								bossVelocity[axis] += elasticVelocity[axis];
							}
						}

						// player can use forward and back keys to speed up or slow down the rope's movement
						// getting a bit lazy with the math here, 
						bool moveForward = (forwardDown && !backDown);
						bool moveBack = (backDown && !forwardDown);
						if ((moveForward || moveBack) && !ignoreBossActions)
						{
							// need player view angle, but we only care about the yaw
							static float eyeAngles[3];
							GetClientEyeAngles(clientIdx, eyeAngles);
							eyeAngles[0] = 0.0; // throw the pitch away

							// if player hit back simply reverse the yaw.
							if (moveBack)
								eyeAngles[1] = fixAngle(eyeAngles[1] + 180.0);

							// to simplify things we'll just persuade the velocity in a straight line
							// gravity or elasticity will eventually pick up the slack
							static float playerMotionVelocity[3];
							static float velocityValuesLimit[3];
							//getBaseVelocityFromYaw(eyeAngles, playerMotionVelocity);

							// going to cheap out and do a trace since my maths skills are failing
							// (well, that, and the fact source engine scoffs at my unit circle)
							static float tmpEnd[3];
							trace = TR_TraceRayFilterEx(clientOrigin, eyeAngles, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
							TR_GetEndPosition(tmpEnd, trace);
							CloseHandle(trace);
							MakeVectorFromPoints(clientOrigin, tmpEnd, playerMotionVelocity);
							NormalizeVector(playerMotionVelocity, playerMotionVelocity);

							// get the limit before getting the current
							velocityValuesLimit[0] = playerMotionVelocity[0] * HS_MaxSwingSpeed[clientIdx];
							velocityValuesLimit[1] = playerMotionVelocity[1] * HS_MaxSwingSpeed[clientIdx];
							playerMotionVelocity[0] *= (HS_MaxSwingSpeed[clientIdx] * checkDelta);
							playerMotionVelocity[1] *= (HS_MaxSwingSpeed[clientIdx] * checkDelta);

							// now tweak the player's velocity if appropriate
							for (int axis = 0; axis <= 1; axis++)
							{
								if (velocityValuesLimit[axis] > 0 && bossVelocity[axis] < velocityValuesLimit[axis])
									bossVelocity[axis] = fmin(velocityValuesLimit[axis], bossVelocity[axis] + playerMotionVelocity[axis]);
								else if (velocityValuesLimit[axis] < 0 && bossVelocity[axis] > velocityValuesLimit[axis])
									bossVelocity[axis] = fmax(velocityValuesLimit[axis], bossVelocity[axis] + playerMotionVelocity[axis]);
							}
						}

						// now we need to persuade the user's position to match where we think it should be.
						// doing this every tick would have stability issues to say the least, so lets try doing it only 10 times per second
						if (excessDistance > 0.0)
						{
							// persuade the boss' position in the direction of the hook
							// unlike the player motion velocity, there are no limits.
							static float elasticVelocity[3];
							MakeVectorFromPoints(clientOrigin, HS_HookPosition[clientIdx], elasticVelocity);
							NormalizeVector(elasticVelocity, elasticVelocity);

							// our fun little equation for the velocity modifier
							for (int axis = 0; axis <= 2; axis++)
							{
								elasticVelocity[axis] *= HS_ElasticityModifier[clientIdx] * ((excessDistance / HS_ELASTIC_BASE_DISTANCE) * checkDelta * HS_DEFAULT_ELASTIC_INTENSITY);

								// add this to the player's current velocity. no limits.
								bossVelocity[axis] += elasticVelocity[axis];
							}
						}

						// apply the changes to player velocity
						SetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", bossVelocity);
						TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, bossVelocity);

						// finally, schedule the next check
						HS_LastCheckAt[clientIdx] = curTime;
					}
				}
			}
			else if (!HS_HookshotOut[clientIdx] && altFirePressed && !ignoreBossActions)
			{
				if (TF2_IsPlayerInCondition(clientIdx, TFCond_SwimmingCurse))
				{
					if (PRINT_DEBUG_SPAM)
						PrintToServer("[sarysamods5] Client %d attempted to hookshot in jarate water. Silent failure.", clientIdx);
				}
				else if (currentRage < HS_RageCost[clientIdx])
				{
					Nope(clientIdx);
					
					if (PRINT_DEBUG_SPAM)
						PrintToServer("[sarysamods5] Client %d attempted to hookshot but didn't have enough rage.", clientIdx);
				}
				else if (!validHSState)
				{
					UpdateHookshotHUD(clientIdx, HS_ERROR_ON_GROUND);
					Nope(clientIdx);

					if (PRINT_DEBUG_SPAM)
						PrintToServer("[sarysamods5] Client %d attempted to hookshot but was on ground or in water.", clientIdx);
				}
				else if (HS_UsableAt[clientIdx] > curTime)
				{
					Nope(clientIdx);
					
					if (PRINT_DEBUG_SPAM)
						PrintToServer("[sarysamods5] Client %d attempted to hookshot but was on ground or in water.", clientIdx);
				}
				else if (ignoreBossActions)
				{
					UpdateHookshotHUD(clientIdx, HS_ERROR_STUNNED);
					Nope(clientIdx);

					if (PRINT_DEBUG_SPAM)
						PrintToServer("[sarysamods5] Client %d attempted to hookshot but was stunned.", clientIdx);
				}
				else if (GetEntityGravity(clientIdx) > 1.0)
				{
					UpdateHookshotHUD(clientIdx, HS_ERROR_WEIGHDOWN_ACTIVE);
					Nope(clientIdx);

					if (PRINT_DEBUG_SPAM)
						PrintToServer("[sarysamods5] Client %d attempted to hookshot but was in weighdown.", clientIdx);
				}
				else
				{
					float eyeOrigin[3];
					float eyeAngles[3];
					GetClientEyePosition(clientIdx, eyeOrigin);
					GetClientEyeAngles(clientIdx, eyeAngles);

					if (eyeAngles[0] > HS_MaxFiringAngle[clientIdx])
					{
						UpdateHookshotHUD(clientIdx, HS_ERROR_BAD_ANGLE);
						Nope(clientIdx);

						if (PRINT_DEBUG_SPAM)
							PrintToServer("[sarysamods5] Client %d attempted to hookshot but was facing a bad angle=(%f,%f,0)", clientIdx, eyeAngles[0], eyeAngles[1]);
					}
					else
					{
						Handle trace = TR_TraceRayFilterEx(eyeOrigin, eyeAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceWallsOnly);
						TR_GetEndPosition(HS_HookPosition[clientIdx], trace);
						CloseHandle(trace);

						// set some other things we need to know. motion will be established in a future tick.
						// for distance, we need to use the player origin and not their eye origin.
						// this is because eye origin can shift around simply when the user turns their head.
						float clientOrigin[3];
						GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", clientOrigin);
						HS_HookshotReelDistance[clientIdx] = GetVectorDistance(clientOrigin, HS_HookPosition[clientIdx]);
						HS_HookshotOut[clientIdx] = true;
						DD_SetDisabled(clientIdx, false, false, true);

						// clear any error
						UpdateHookshotHUD(clientIdx, HS_ERROR_NONE);

						// prep for next time motion is checked
						HS_LastCheckAt[clientIdx] = curTime;

						// play sound
						if (strlen(HS_HookFiringSound) > 3)
							PseudoAmbientSound(clientIdx, HS_HookFiringSound, 3);

						// need this for the time limit
						HS_HookshotFiredAt[clientIdx] = curTime;

						// consume double-jumps
						SetEntProp(clientIdx, Prop_Send, "m_iAirDash", 30);

						// consume rage
						if (HS_RageCost[clientIdx] > 0.0)
							FF2_SetBossCharge(bossIdx, 0, currentRage - HS_RageCost[clientIdx]);

						// create hook entity
						if (strlen(HS_HookModel) > 3)
						{
							int hookEntity = CreateEntityByName("prop_physics_override");
							if (IsValidEntity(hookEntity))
							{
								// the actual spawning process
								SetEntityModel(hookEntity, HS_HookModel);
								DispatchSpawn(hookEntity);
								TeleportEntity(hookEntity, HS_HookPosition[clientIdx], eyeAngles, NULL_VECTOR);
								SetEntProp(hookEntity, Prop_Data, "m_takedamage", 0);

								SetEntityMoveType(hookEntity, MOVETYPE_NONE);
								SetEntProp(hookEntity, Prop_Send, "m_CollisionGroup", 0);
								SetEntProp(hookEntity, Prop_Send, "m_usSolidFlags", 4);
								SetEntProp(hookEntity, Prop_Send, "m_nSolidType", 0);

								// save the entity ref
								HS_HookEntRef[clientIdx] = EntIndexToEntRef(hookEntity);
								
								// create the beam
								SpawnBeamRope(HS_BeamEntRef[clientIdx], clientIdx, hookEntity, view_as<float>({75.0, 0.0}), HS_RopeTextureStr, 1.0);

								if (PRINT_DEBUG_SPAM)
									PrintToServer("[sarysamods5] Spawned a hook entity! %d", hookEntity);
							}
						}

						if (PRINT_DEBUG_SPAM)
							PrintToServer("[sarysamods5] Client %d is now in hookshot state. angle=(%f,%f,0) pos=(%f,%f,%f", clientIdx, eyeAngles[0], eyeAngles[1],
									HS_HookPosition[clientIdx][0], HS_HookPosition[clientIdx][1], HS_HookPosition[clientIdx][2]);
					}
				}
			}
			
			// glow hack, work around a WTF glitch with the beam
			if (HS_HookshotOut[clientIdx] && (HS_Flags[clientIdx] & HS_FLAG_GLOW_HACK) != 0)
			{
				if (GetEntProp(clientIdx, Prop_Send, "m_bGlowEnabled") == 0)
					SetEntProp(clientIdx, Prop_Send, "m_bGlowEnabled", 1);
			}

			HS_AltFireDown[clientIdx] = ((buttons & IN_ATTACK2) != 0);
			HS_DuckKeyDown[clientIdx] = ((buttons & IN_DUCK) != 0);
			HS_JumpKeyDown[clientIdx] = ((buttons & IN_JUMP) != 0);

			HS_LastUpdateAt[clientIdx] = curTime;

			// finally, update the HUD
			if (HS_HudRefreshAt[clientIdx] <= GetGameTime())
			{
				// if hookshot is on cooldown or if it's time to clear the error message, update the HUD message now
				// or if not enough rage
				if (HS_HudErrorClearAt[clientIdx] <= curTime)
					UpdateHookshotHUD(clientIdx, HS_ERROR_NONE);
				else
					UpdateHookshotHUD(clientIdx, -1);

				// going with the FF2 timer values, since I'd like it to be fairly responsive
				SetHudTextParams(-1.0, 0.87, 0.15, 64, 64, 255, 192);
				ShowHudText(clientIdx, -1, HS_HUDText[clientIdx]);
				HS_HudRefreshAt[clientIdx] = GetGameTime() + 0.1;
			}
		}
	}
	
	return Plugin_Continue;
}

/**
 * General helper stocks, some original, some taken/modified from other sources
 */
stock int ParticleEffectAt(float position[3], char[] effectName, float duration = 0.1)
{
	if (!IsEmptyString(effectName))
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
			CreateTimer(duration, Timer_RemoveEntity, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
	}
	return particle;
}

public Action Timer_RemoveEntity(Handle timer, any entid)
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

stock void SwitchWeapon(int bossClient, char[] weaponName, int weaponIdx, char[] weaponAttributes, int visible)
{
	TF2_RemoveWeaponSlot(bossClient, TFWeaponSlot_Primary);
	TF2_RemoveWeaponSlot(bossClient, TFWeaponSlot_Secondary);
	TF2_RemoveWeaponSlot(bossClient, TFWeaponSlot_Melee);
	int weapon;
	weapon = SpawnWeapon(bossClient, weaponName, weaponIdx, 101, 5, weaponAttributes, visible);
	SetEntPropEnt(bossClient, Prop_Data, "m_hActiveWeapon", weapon);
}

stock int SpawnWeapon(int client, char[] name, int index, int level, int quality, char[] attribute, int visible = 1)
{
	Handle weapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(weapon, name);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, quality);
	char attributes[32][32];
	int count = ExplodeString(attribute, ";", attributes, 32, 32);
	if(count%2!=0)
	{
		count--;
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(weapon, count/2);
		int i2 = 0;
		for(int i = 0; i < count; i += 2)
		{
			int attrib = StringToInt(attributes[i]);
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
		PrintToServer("[sarysamods5] Error: Invalid weapon spawned. client=%d name=%s idx=%d attr=%s", client, name, index, attribute);
		return -1;
	}

	int entity = TF2Items_GiveNamedItem(client, weapon);
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

stock bool IsPlayerInRange(int player, float position[3], float maxDistance)
{
	maxDistance *= maxDistance;
	
	static float playerPos[3];
	GetEntPropVector(player, Prop_Data, "m_vecOrigin", playerPos);
	return GetVectorDistance(position, playerPos, true) <= maxDistance;
}

stock int FindRandomPlayer(bool isBossTeam, float position[3] = NULL_VECTOR, float maxDistance = 0.0)
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

		if ((isBossTeam && GetClientTeam(clientIdx) == BossTeam) || (!isBossTeam && GetClientTeam(clientIdx) != BossTeam))
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
			
		if ((isBossTeam && GetClientTeam(clientIdx) == BossTeam) || (!isBossTeam && GetClientTeam(clientIdx) != BossTeam))
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
			
stock int FindRandomSpawn(bool bluSpawn, bool redSpawn)
{
	int spawn = -1;

	// first, get a spawn count for the team(s) we care about
	int spawnCount = 0;
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "info_player_teamspawn")) != -1)
	{
		int teamNum = GetEntProp(entity, Prop_Send, "m_iTeamNum");
		if ((teamNum == BossTeam && bluSpawn) || (teamNum != BossTeam && redSpawn))
			spawnCount++;
	}

	// ensure there's at least one valid spawn
	if (spawnCount <= 0)
		return -1;

	// now randomly choose our spawn
	int rand = GetRandomInt(0, spawnCount - 1);
	spawnCount = 0;
	while ((entity = FindEntityByClassname(entity, "info_player_teamspawn")) != -1)
	{
		int teamNum = GetEntProp(entity, Prop_Send, "m_iTeamNum");
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

stock int GetLivingMercCount()
{
	// recalculate living players
	int livingMercCount = 0;
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		if (IsLivingPlayer(clientIdx) && GetClientTeam(clientIdx) != BossTeam)
			livingMercCount++;
	
	return livingMercCount;
}
	
stock void ParseFloatRange(char[] rangeStr, float& min, float& max)
{
	char rangeStrs[2][32];
	ExplodeString(rangeStr, ",", rangeStrs, 2, 32);
	min = StringToFloat(rangeStrs[0]);
	max = StringToFloat(rangeStrs[1]);
}

stock void ParseHull(char[] hullStr, float hull[2][3])
{
	char hullStrs[2][MAX_HULL_STRING_LENGTH / 2];
	char vectorStrs[3][MAX_HULL_STRING_LENGTH / 6];
	ExplodeString(hullStr, " ", hullStrs, 2, MAX_HULL_STRING_LENGTH / 2);
	for (int i = 0; i < 2; i++)
	{
		ExplodeString(hullStrs[i], ",", vectorStrs, 3, MAX_HULL_STRING_LENGTH / 6);
		hull[i][0] = StringToFloat(vectorStrs[0]);
		hull[i][1] = StringToFloat(vectorStrs[1]);
		hull[i][2] = StringToFloat(vectorStrs[2]);
	}
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

stock int ReadModelToInt(int bossIdx, const char[] ability_name, int argInt)
{
	static char modelFile[MAX_MODEL_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, modelFile, MAX_MODEL_FILE_LENGTH);
	if (strlen(modelFile) > 3)
		return PrecacheModel(modelFile);
	return -1;
}

stock void ReadMaterial(int bossIdx, const char[] ability_name, int argInt, char[] modelFile)
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, modelFile, MAX_MATERIAL_FILE_LENGTH);
	if (strlen(modelFile) > 3)
		PrecacheModel(modelFile);
}

stock void ReadCenterText(int bossIdx, const char[] ability_name, int argInt, char[] centerText)
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, centerText, MAX_CENTER_TEXT_LENGTH);
	ReplaceString(centerText, MAX_CENTER_TEXT_LENGTH, "\\n", "\n");
}

stock void ReadHull(int bossIdx, const char[] ability_name, int argInt, float hull[2][3])
{
	static char hullStr[MAX_HULL_STRING_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, hullStr, MAX_HULL_STRING_LENGTH);
	ParseHull(hullStr, hull);
}

public bool TraceWallsOnly(int entity, int contentsMask)
{
	return false;
}

public bool TraceRedPlayers(int entity, int contentsMask)
{
	if (IsLivingPlayer(entity) && GetClientTeam(entity) != BossTeam)
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods5] Hit player %d on trace.", entity);
		return true;
	}

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
	//tmpVec[0] = startPos[0] - endPos[0];
	//tmpVec[1] = startPos[1] - endPos[1];
	//tmpVec[2] = startPos[2] - endPos[2];
	tmpVec[0] = endPos[0] - startPos[0];
	tmpVec[1] = endPos[1] - startPos[1];
	tmpVec[2] = endPos[2] - startPos[2];
	GetVectorAngles(tmpVec, angles);
}

stock float GetVelocityFromPointsAndInterval(float pointA[3], float pointB[3], float deltaTime)
{
	if (deltaTime <= 0.0)
		return 0.0;

	return GetVectorDistance(pointA, pointB) * (1.0 / deltaTime);
}

stock float fixDamageForFF2(float damage)
{
	if (damage <= 160.0)
		return damage / 3.0;
	return damage;
}

// for when damage to a hale needs to be recognized
stock void SemiHookedDamage(int victim, int inflictor, int attacker, float damage, int damageType=DMG_GENERIC, int weapon=-1)
{
	if (GetClientTeam(victim) != BossTeam)
		SDKHooks_TakeDamage(victim, inflictor, attacker, damage, damageType, weapon);
	else
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
			AcceptEntityInput(pointHurt, "Hurt", attacker);
			DispatchKeyValue(pointHurt, "classname", "point_hurt");
			DispatchKeyValue(victim, "targetname", "noonespecial");
			Timer_RemoveEntity(null, EntIndexToEntRef(pointHurt));
		}
	}
}

// this version ignores obstacles
#define PSEUDO_AMBIENT_SOUND_DISTANCE 1000.0
stock void PseudoAmbientSound(int clientIdx, char[] soundPath, int count=1)
{
	static float emitterPos[3];
	static float listenerPos[3];
	GetClientEyePosition(clientIdx, emitterPos);
	for (int listener = 1; listener < MAX_PLAYERS; listener++)
	{
		if (!IsClientInGame(listener))
			continue;
			
		// knowing virtually nothing about sound engineering, I'm kind of BSing this here...
		// but I'm pretty sure decibal dropoff is best done logarithmically.
		// so I'm doing that here.
		GetClientEyePosition(listener, listenerPos);
		float distance = GetVectorDistance(emitterPos, listenerPos);
		if (distance >= PSEUDO_AMBIENT_SOUND_DISTANCE)
			continue;
		
		float logMe = (PSEUDO_AMBIENT_SOUND_DISTANCE - distance) / (PSEUDO_AMBIENT_SOUND_DISTANCE / 10.0);
		if (logMe <= 0.0) // just a precaution, since EVERYTHING tosses an exception in this game
			continue;
			
		float volume = Logarithm(logMe);
		if (volume <= 0.0)
			continue;
		else if (volume > 1.0)
		{
			PrintToServer("[sarysamods5] How the hell is volume greater than 1.0?");
			volume = 1.0;
		}
		
		for (int i = 0; i < count; i++)
			EmitSoundToClient(listener, soundPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume);
	}
}

stock void fixAngles(float angles[3])
{
	for (int i = 0; i < 3; i++)
		angles[i] = fixAngle(angles[i]);
}

stock int abs(int x)
{
	return x < 0 ? -x : x;
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

stock bool RectangleCollision(float hull[2][3], float point[3])
{
	return (point[0] >= hull[0][0] && point[0] <= hull[1][0]) &&
		(point[1] >= hull[0][1] && point[1] <= hull[1][1]) &&
		(point[2] >= hull[0][2] && point[2] <= hull[1][2]);
}

stock float getLinearVelocity(float vecVelocity[3])
{
	return SquareRoot((vecVelocity[0] * vecVelocity[0]) + (vecVelocity[1] * vecVelocity[1]) + (vecVelocity[2] * vecVelocity[2]));
}

stock float getBaseVelocityFromYaw(const float angle[3], float vel[3])
{
	vel[0] = Cosine(angle[1]); // same as unit circle
	//vel[1] = -Sine(angle[1]); // inverse of unit circle
	vel[1] = Sine(angle[1]); // ...or also same of unit circle? must not test in game at 3am...
	vel[2] = 0.0; // unaffected
}

stock float RandomNegative(float val)
{
	return val * (GetRandomInt(0, 1) == 1 ? 1.0 : -1.0);
}

stock float GetRayAngles(float startPoint[3], float endPoint[3], float angle[3])
{
	static float tmpVec[3];
	tmpVec[0] = endPoint[0] - startPoint[0];
	tmpVec[1] = endPoint[1] - startPoint[1];
	tmpVec[2] = endPoint[2] - startPoint[2];
	GetVectorAngles(tmpVec, angle);
}

stock bool AngleWithinTolerance(float entityAngles[3], float targetAngles[3], float tolerance)
{
	static bool tests[2];
	
	for (int i = 0; i < 2; i++)
		tests[i] = fabs(entityAngles[i] - targetAngles[i]) <= tolerance || fabs(entityAngles[i] - targetAngles[i]) >= 360.0 - tolerance;
	
	return tests[0] && tests[1];
}

stock int GetA(int c) { return abs(c>>24); }
stock int GetR(int c) { return abs((c>>16)&0xff); }
stock int GetG(int c) { return abs((c>>8 )&0xff); }
stock int GetB(int c) { return abs((c    )&0xff); }

stock void ColorToDecimalString(char[] buffer, int rgb)
{
	FormatEx(buffer, COLOR_BUFFER_SIZE, "%d %d %d", GetR(rgb), GetG(rgb), GetB(rgb));
}

int BlendColorsRGB(int oldColor, float oldWeight, int newColor, float newWeight)
{
	int r = min(RoundFloat((GetR(oldColor) * oldWeight) + (GetR(newColor) * newWeight)), 255);
	int g = min(RoundFloat((GetG(oldColor) * oldWeight) + (GetG(newColor) * newWeight)), 255);
	int b = min(RoundFloat((GetB(oldColor) * oldWeight) + (GetB(newColor) * newWeight)), 255);
	return (r<<16) + (g<<8) + b;
}

stock void Nope(int clientIdx)
{
	EmitSoundToClient(clientIdx, NOPE_AVI);
}

/**
 * Based heavily on KissLick's beam code
 * https://forums.alliedmods.net/showthread.php?t=249891
 */
void SpawnBeamRope(int beams[2], int entity1, int entity2, const float zOffsets[2], const char[] BeamMaterial, float width = 5.0, rgba[4] = { 255, 255, 255, 255 })
{
	static const char nodeNames[2][64] =  { "rope1", "rope2" };
	
	for (int i = 0; i < 2; i++)
	{
		beams[i] = CreateEntityByName("env_beam");
		if (!IsValidEntity(beams[i]))
			return;
			
		int currentEntity = i == 0 ? entity1 : entity2;
			
		DispatchKeyValue(beams[i], "targetname", nodeNames[i]);
		DispatchKeyValue(beams[i], "texture", BeamMaterial);
		DispatchKeyValueFormat(beams[i], "BoltWidth", "%f", width);
		DispatchKeyValue(beams[i], "life", "0");
		DispatchKeyValueFormat(beams[i], "rendercolor", "%d %d %d", rgba[0], rgba[1], rgba[2]);
		DispatchKeyValueFormat(beams[i], "renderamt", "%d", rgba[3]);
		DispatchKeyValue(beams[i], "TextureScroll", "0");
		DispatchKeyValue(beams[i], "LightningStart", nodeNames[i]);
		DispatchKeyValue(beams[i], "LightningEnd", nodeNames[(i+1)%2]);
		
		static float node[3];
		GetEntPropVector(currentEntity, Prop_Data, "m_vecOrigin", node);
		node[2] += zOffsets[i];
		TeleportEntity(beams[i], node, NULL_VECTOR, NULL_VECTOR);
		
		static char targetName[128];
		Format(targetName, sizeof(targetName), "target%i", currentEntity);
		DispatchKeyValue(currentEntity, "targetname", targetName);

		DispatchKeyValue(beams[i], "parentname", targetName);
		DispatchSpawn(beams[i]);
		SetVariantString(targetName);
		AcceptEntityInput(beams[i], "SetParent", beams[i], beams[i], 0);
	}
	
	for (int i = 0; i < 2; i++)
	{
		ActivateEntity(beams[i]);
		AcceptEntityInput(beams[i], "TurnOn");
		beams[i] = EntIndexToEntRef(beams[i]);
	}
}

stock void DispatchKeyValueFormat(int entity, const char[] keyName, const char[] format, any ...)
{
	static char value[256];
	VFormat(value, sizeof( value ), format, 4);

	DispatchKeyValue(entity, keyName, value);
} 

/**
 * CODE BELOW WAS TAKEN STRAIGHT FROM PHATRAGES, I TAKE NO CREDIT FOR IT
 * (though I have modified it slightly)
 */
stock void env_shake(const float Origin[3], float Amplitude, float Radius, float Duration, float Frequency, bool noPhysics = false)
{
	//Initialize:
	int Ent = CreateEntityByName("env_shake");
		
	//Spawn:
	if (IsValidEntity(Ent))
	{
		//Properties:
		DispatchKeyValueFloat(Ent, "amplitude", Amplitude);
		DispatchKeyValueFloat(Ent, "radius", Radius);
		DispatchKeyValueFloat(Ent, "duration", Duration);
		DispatchKeyValueFloat(Ent, "frequency", Frequency);

		SetVariantString(noPhysics ? "spawnflags 0":"spawnflags 8");
		AcceptEntityInput(Ent,"AddOutput");

		//Input:
		AcceptEntityInput(Ent, "StartShake", 0);
		
		//Send:
		TeleportEntity(Ent, Origin, NULL_VECTOR, NULL_VECTOR);
		
		// create
		DispatchSpawn(Ent);
		
		//Delete:
		CreateTimer(Duration + 1.0, Timer_RemoveEntity, EntIndexToEntRef(Ent), TIMER_FLAG_NO_MAPCHANGE);
	}
}

