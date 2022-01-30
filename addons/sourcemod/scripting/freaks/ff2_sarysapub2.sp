/**
 * CREATIVE COMMONS ATTRIBUTION 3.0 LICENSE
 *
 * You are free to:
 *	Share - copy and redistribute the material in any medium or format
 * 	Adapt - remix, transform, and build upon the material for any purpose, even commercially.
 *
 * The licensor cannot revoke these freedoms as long as you follow the license terms.
 *
 * Under the following terms:
 * Attribution
 *	You must give appropriate credit, provide a link to the license, and indicate if changes were made.
 *	You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
 *
 * No additional restrictions - You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.
 *
 * This applies to the parts written by the module author: sarysa [sarysa2@yahoo.com and sarysa on Steam]
 * Parts taken from other sources have due credit given, or are clearly adapted from the Freak Fortress 2 base.
 *
 * Full license info located here: https://creativecommons.org/licenses/by/3.0/us/legalcode
 *
 * Basically, just give me credit if you reuse my code elsewhere. :P I didn't read through the above link either.
 */

#define FF2_USING_AUTO_PLUGIN__OLD

#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

/**
 * Various public rages, starting off with requests from Blinx.
 *
 * RageParasite: Attaches a parasite model or particle effect to the victim which drains their health.
 * Known Issues: Even the smoother variety of parasite is a little jerky due to the unpredictable nature of network traffic.
 *		 (basically the timing of the server sending net messages reporting the entity's velocity will not come in within the same
 *		 intervals for the player, hence the jerkiness)
 *		 Common player attachment points may fail utterly because you're using custom player models which don't
 *		 handle them right. Take it from me, I wasted a lot of time thanks to this.
 *
 * FF2WaterArena: Sets the arena to be underwater for the entire round. Solves most problems for you, but allows setting of pyro damage, dalokohs
 *		  overheal, damage of fireball spell, and will be modified in the future for future problems...
 * Credits: Phatrages' drown ability is the basis for the alternate version of water.
 *	    EasSidezz for the DX8 fix: https://forums.alliedmods.net/showthread.php?t=257118
 *
 * FF2UnderwaterCharge: A velocity push similar to RageTorpedoAttack but it gives more play control options, cooldown option, and does no damage.
 *                      It's intended to be the underwater equivalent of super jump.
 *
 * FF2UnderwaterSpeed: Since lame water breaks the hale's speed modifications, I made my own.
 */
 
// copied from tf2 sdk
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
 
#define ARG_LENGTH 256
 
bool PRINT_DEBUG_INFO = true;
bool PRINT_DEBUG_SPAM = false;

#define FAR_FUTURE 100000000.0
TFCond COND_JARATE_WATER=TFCond_SwimmingCurse;
#define NOPE_AVI "vo/engineer_no01.wav" // DO NOT DELETE FROM FUTURE PACKS

// text string limits
#define MAX_SOUND_FILE_LENGTH 80
#define MAX_MODEL_NAME_LENGTH 128
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

bool RoundInProgress = false;

public Plugin myinfo = {
	name = "Freak Fortress 2: sarysa's public mods, second pack",
	author = "sarysa",
	version = "1.0.2",
}

// parasite
#define RP_STRING "rage_parasite"
#define RP_Z_OFFSET 40.0 // the standard z offset relative to player origin
int RP_ActiveThisRound = false;
int RP_DamageHooksNeeded = false;
#define RP_FLAG_CYLINDER_COLLISION 0x0001
#define RP_FLAG_ATTACH 0x0002
#define RP_FLAG_MULTIPLE_HOSTS 0x0004
#define RP_FLAG_REMOVED_ON_UBER 0x0008
#define RP_FLAG_SURVIVE_UBER_REMOVAL 0x0010
#define RP_FLAG_SELF_DAMAGE_REMOVAL 0x0020
#define RP_FLAG_PENETRATE_UBER 0x0040
#define RP_FLAG_PLAYERS_ON_RAY_TRACE 0x0080
#define RP_FLAG_TOXIC_UNCONNECTED 0x0100
#define RP_FLAG_TOXIC_CONNECTED 0x0200
#define RP_FLAG_FLYING_PARASITE 0x0400
#define RP_FLAG_IMPERFECT_FLIGHT 0x0800
#define RP_FLAG_TOXIC_PLAYER_POSITION 0x1000
// arg1 only needed at spawn time
char RP_EffectName[MAX_PLAYERS_ARRAY][MAX_EFFECT_NAME_LENGTH]; // arg2, which sadly needs to be stored due to particle effects not being very malleable
// arg3 only needed at spawn time
char RP_AttachmentPoint[MAX_PLAYERS_ARRAY][MAX_ATTACHMENT_NAME_LENGTH]; // arg4
float RP_ParasiteZOffset[MAX_PLAYERS_ARRAY]; // arg5
float RP_CollisionHull[MAX_PLAYERS_ARRAY][2][3]; // arg6
float RP_DamagePerTick[MAX_PLAYERS_ARRAY]; // arg7
float RP_TickInterval[MAX_PLAYERS_ARRAY]; // arg8
float RP_StickDuration[MAX_PLAYERS_ARRAY]; // arg9
// arg9 only needed at spawn time
float RP_ImmunityDuration[MAX_PLAYERS_ARRAY]; // arg11
// arg11 only needed at spawn time
float RP_ToxicRadius[MAX_PLAYERS_ARRAY]; // arg13
int RP_Flags[MAX_PLAYERS_ARRAY]; // arg19

// the individual parasites
#define MAX_PARASITES 50
int RPP_Owner[MAX_PARASITES]; // not using user ID since living player is verified every frame.
int RPP_ModelEntRef[MAX_PARASITES];
int RPP_ParticleEntRef[MAX_PARASITES];
int RPP_CurrentVictim[MAX_PARASITES];
float RPP_DetachFromVictimAt[MAX_PARASITES];
float RPP_DieNaturallyAt[MAX_PARASITES];
int RPP_ImmuneVictim[MAX_PARASITES]; // yes, in edge cases where users rapidly go in and out of parasite (i.e. uber) the user can be victim more often
float RPP_ImmunityEndsAt[MAX_PARASITES]; // than they should, but it's just not worth the data size requirements for such a minor issue
float RPP_ActivateAt[MAX_PARASITES];
float RPP_NextDamageAt[MAX_PARASITES];
float RPP_SelfYawAtAttachTime[MAX_PARASITES];
float RPP_VictimYawAtAttachTime[MAX_PARASITES];
float RPP_VictimLastValidOrigin[MAX_PARASITES][3];
float RPP_LastTickTime = 0.0; // they all use a cached time variable, not GetEngineTime(), so they're all the same

// zatoichi workaround
#define ZW_STRING "ff2_zatoichi_workaround"
bool ZW_IsUsing[MAX_PLAYERS_ARRAY];
float ZW_StandardBaseDamage = 65.0;

/**
 * Water Arena
 */
#define WA_STRING "ff2_water_arena"
#define WA_MAX_HP_DRAIN_WEAPONS 10
#define WA_MAX_ROCKET_MINICRIT_BLACKLIST 30
bool WA_ActiveThisRound;
float WA_FixOverlayAt; // internal
float WA_PlayWaterSoundAt[MAX_PLAYERS_ARRAY]; // internal
float WA_RestoreWaterAt[MAX_PLAYERS_ARRAY]; // internal
bool WA_AltFireDown[MAX_PLAYERS_ARRAY]; // internal
bool WA_FireDown[MAX_PLAYERS_ARRAY]; // internal
bool WA_CrouchDown[MAX_PLAYERS_ARRAY]; // internal
bool WA_UsingSpellbookLameWater[MAX_PLAYERS_ARRAY]; // internal
bool WA_IsThirdPerson[MAX_PLAYERS_ARRAY]; // internal, reflects their setting on the other mod
bool WA_OverlayOptOut[MAX_PLAYERS_ARRAY]; // internal, setting for water overlay
bool WA_OverlaySupported[MAX_PLAYERS_ARRAY]; // internal, determined by dx80 check
int WA_OOOUserId[MAX_PLAYERS_ARRAY]; // internal, check this every round start that matters
// sandvich and dalokah's handling
#define WA_HEAVY_CONSUMPTION_TIME 4.3
#define WA_HEAVY_EATING_SOUND "vo/sandwicheat09.wav"
bool WA_IsEatingHeavyFood[MAX_PLAYERS_ARRAY]; // internal
bool WA_IsDalokohs[MAX_PLAYERS_ARRAY]; // internal
int WA_HeavyFoodHPPerTick[MAX_PLAYERS_ARRAY]; // internal
int WA_HeavyFoodTickCount[MAX_PLAYERS_ARRAY]; // internal
float WA_HeavyFoodStartedAt[MAX_PLAYERS_ARRAY]; // internal
// bonk and crit-a-cola handling
#define WA_SCOUT_DRINKING_SOUND "player/pl_scout_dodge_can_drink.wav"
bool WA_IsDrinking[MAX_PLAYERS_ARRAY]; // internal
bool WA_IsBonk[MAX_PLAYERS_ARRAY]; // internal
float WA_DrinkingUntil[MAX_PLAYERS_ARRAY]; // internal
float WA_EffectLastsUntil[MAX_PLAYERS_ARRAY]; // internal
// consumable handling
float WA_ConsumableCooldownUntil[MAX_PLAYERS_ARRAY];
// sandman handling
#define WA_SANDMAN_LAMEWATER_DURATION 0.5 // note, it has to be artificially long because sometimes firstperson fails otherwise
float WA_RemoveLameWaterAt[MAX_PLAYERS_ARRAY];
// fix for bug where condition 86 is lost when a player almost lags out
#define WA_WATER_RESTORE_INTERVAL 0.05
float WA_MassRestoreWaterAt;
// the crouch problem
#define WA_CROUCH_JEER_SOUND "vo/scout_jeers06.wav"
float WA_NoWaterUntil[MAX_PLAYERS_ARRAY];
// 2014-12-23, sometimes the perspective doesn't fix itself
#define FIX_PERSPECTIVE_COUNT 3
float WA_FixPerspectiveAt[MAX_PLAYERS_ARRAY][FIX_PERSPECTIVE_COUNT];
// 2014-12-23, swap the hale to good water when all engies are dead, since lame water is troubled
bool WA_AllEngiesDead;
// server operator args
float WA_PyroSecondaryBoost; // arg1
float WA_PyroMeleeBoost; // arg2
float WA_FixInterval; // arg3
char WA_UnderwaterSound[MAX_SOUND_FILE_LENGTH]; // arg4
float WA_SoundLoopInterval; // arg5
float WA_Damage; // arg6
float WA_Velocity; // arg7
bool WA_AllowSandman; // arg8
char WA_UnderwaterOverlay[MAX_MATERIAL_FILE_LENGTH]; // arg9
float WA_HeavyDalokohsBoost; // arg10
int WA_HeavyDalokohsTick; // arg11
int WA_HeavySandvichTick; // arg12
char WA_PyroShotgunArgs[MAX_WEAPON_ARG_LENGTH]; // arg13
char WA_SniperRifleArgs[MAX_WEAPON_ARG_LENGTH]; // arg14
int WA_HeavyHPDrainWeapons[WA_MAX_HP_DRAIN_WEAPONS]; // arg15
bool WA_DontShowNoOverlayInstructions; // arg16
bool WA_DontSwitchToGoodWater; // arg17
bool WA_RocketMinicritDisabled; // arg18 (related)
int WA_SoldierNoMinicritWeapons[WA_MAX_ROCKET_MINICRIT_BLACKLIST]; // arg18

/**
 * Underwater Charge
 */
#define UC_STRING "ff2_underwater_charge"
#define UC_TYPE_RESTRICTED 0
#define UC_TYPE_FREE 1
#define UC_HUD_POSITION 0.87
#define UC_HUD_REFRESH_INTERVAL 0.1
bool UC_ActiveThisRound;
bool UC_CanUse[MAX_PLAYERS_ARRAY]; // internal
float UC_LockedAngle[MAX_PLAYERS_ARRAY][3]; // internal, if arg1 is 0
float UC_RefreshChargeAt[MAX_PLAYERS_ARRAY]; // internal, related to arg3
float UC_EndChargeAt[MAX_PLAYERS_ARRAY]; // internal, related to arg5
float UC_UsableAt[MAX_PLAYERS_ARRAY]; // internal, related to arg6
bool UC_KeyDown[MAX_PLAYERS_ARRAY]; // internal, related to arg9
float UC_NextHUDAt[MAX_PLAYERS_ARRAY]; // internal
int UC_ChargeType[MAX_PLAYERS_ARRAY]; // arg1
float UC_VelDampening[MAX_PLAYERS_ARRAY]; // arg2
float UC_ChargeVel[MAX_PLAYERS_ARRAY]; // arg3
float UC_ChargeRefreshInterval[MAX_PLAYERS_ARRAY]; // arg4
float UC_Duration[MAX_PLAYERS_ARRAY]; // arg5
float UC_Cooldown[MAX_PLAYERS_ARRAY]; // arg6
char UC_Sound[MAX_SOUND_FILE_LENGTH]; // arg7
float UC_RageCost[MAX_PLAYERS_ARRAY]; // arg8
bool UC_AltFireActivated[MAX_PLAYERS_ARRAY]; // arg9
char UC_CooldownStr[MAX_CENTER_TEXT_LENGTH]; // arg16
char UC_InstructionStr[MAX_CENTER_TEXT_LENGTH]; // arg17
char UC_NotEnoughRageStr[MAX_CENTER_TEXT_LENGTH]; // arg18

/**
 * Underwater Speed
 */
#define US_STRING "ff2_underwater_speed"
bool US_ActiveThisRound;
bool US_CanUse[MAX_PLAYERS_ARRAY];
int US_TicksForMaxHP[MAX_PLAYERS_ARRAY]; // internal, if this is greater than 0, max hp is unknown
int US_MaxHP[MAX_PLAYERS_ARRAY]; // internal
float US_StartSpeed[MAX_PLAYERS_ARRAY]; // arg1
float US_EndSpeed[MAX_PLAYERS_ARRAY]; // arg2
 
public void OnPluginStart2()
{
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	RoundInProgress = true;
	
	// initialize variables
	RP_ActiveThisRound = false;
	RP_DamageHooksNeeded = false;
	if (WA_ActiveThisRound) // in case by some freak circumstance it did not unload last round
		WA_RemoveHooks();
	WA_ActiveThisRound = false;
	WA_AllEngiesDead = false;
	UC_ActiveThisRound = false;
	US_ActiveThisRound = false;
	
	// initialize arrays
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		// all client inits
		ZW_IsUsing[clientIdx] = false;
		WA_RestoreWaterAt[clientIdx] = FAR_FUTURE;
		WA_AltFireDown[clientIdx] = false;
		WA_FireDown[clientIdx] = false;
		WA_UsingSpellbookLameWater[clientIdx] = false;
		WA_IsEatingHeavyFood[clientIdx] = false;
		WA_ConsumableCooldownUntil[clientIdx] = 0.0;
		WA_IsDrinking[clientIdx] = false;
		WA_EffectLastsUntil[clientIdx] = 0.0;
		WA_RemoveLameWaterAt[clientIdx] = FAR_FUTURE;
		WA_CrouchDown[clientIdx] = false;
		WA_NoWaterUntil[clientIdx] = 0.0;
		WA_OverlaySupported[clientIdx] = true;
		for (int i = 0; i < FIX_PERSPECTIVE_COUNT; i++)
			WA_FixPerspectiveAt[clientIdx][i] = FAR_FUTURE;
		UC_CanUse[clientIdx] = false;
		US_CanUse[clientIdx] = false;
	
		// boss-only inits
		int bossIdx = FF2_GetBossIndex(clientIdx);
		if (bossIdx < 0)
			continue;
			
		// parasite
		if (FF2_HasAbility(bossIdx, this_plugin_name, RP_STRING))
		{
			RP_ActiveThisRound = true;
		
			// the overarching rage props (arg1-arg4, arg9, arg11 not needed here)
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RP_STRING, 2, RP_EffectName[clientIdx], MAX_EFFECT_NAME_LENGTH);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RP_STRING, 4, RP_AttachmentPoint[clientIdx], MAX_ATTACHMENT_NAME_LENGTH);
			RP_ParasiteZOffset[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RP_STRING, 5);
			ReadHull(bossIdx, RP_STRING, 6, RP_CollisionHull[clientIdx]);
			RP_DamagePerTick[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RP_STRING, 7);
			RP_TickInterval[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RP_STRING, 8);
			RP_StickDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RP_STRING, 9);
			RP_ImmunityDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RP_STRING, 11);
			RP_ToxicRadius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RP_STRING, 13);
			
			// the flags
			RP_Flags[clientIdx] = ReadHexOrDecString(bossIdx, RP_STRING, 19);
			
			// self damage removing parasite
			RP_DamageHooksNeeded = RP_DamageHooksNeeded || ((RP_Flags[clientIdx] & RP_FLAG_SELF_DAMAGE_REMOVAL) != 0);
			
			// though we don't need the model yet, we do need to precache it
			char modelName[MAX_MODEL_NAME_LENGTH];
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RP_STRING, 1, modelName, MAX_MODEL_NAME_LENGTH);
			if (strlen(modelName) > 3)
				PrecacheModel(modelName);
				
			if (PRINT_DEBUG_INFO)
				PrintToServer("boss %d (client %d) will use %s   flags=0x%x", bossIdx, clientIdx, RP_STRING, RP_Flags[clientIdx]);
		}
		
		// zatoichi workaround
		ZW_IsUsing[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, ZW_STRING);
		if (ZW_IsUsing[clientIdx])
		{
			ZW_StandardBaseDamage = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ZW_STRING, 1);
			if (ZW_StandardBaseDamage <= 0.0)
				ZW_StandardBaseDamage = 65.0;
			SDKHook(clientIdx, SDKHook_OnTakeDamage, OnTakeDamageZatoichi);
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, WA_STRING))
		{
			WA_ActiveThisRound = true;
			WA_FixOverlayAt = GetEngineTime();
			WA_MassRestoreWaterAt = GetEngineTime() + 1.0;

			WA_PyroSecondaryBoost = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WA_STRING, 1);
			WA_PyroMeleeBoost = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WA_STRING, 2);
			WA_FixInterval = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WA_STRING, 3);
			
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, WA_STRING, 4, WA_UnderwaterSound, MAX_SOUND_FILE_LENGTH);
			WA_SoundLoopInterval = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WA_STRING, 5);
			WA_Damage = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WA_STRING, 6);
			WA_Velocity = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WA_STRING, 7);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, WA_STRING, 8, WA_UnderwaterOverlay, MAX_MATERIAL_FILE_LENGTH);
			WA_AllowSandman = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, WA_STRING, 9) == 1);
			WA_HeavyDalokohsBoost = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WA_STRING, 10);
			WA_HeavyDalokohsTick = FF2_GetAbilityArgument(bossIdx, this_plugin_name, WA_STRING, 11);
			WA_HeavySandvichTick = FF2_GetAbilityArgument(bossIdx, this_plugin_name, WA_STRING, 12);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, WA_STRING, 13, WA_PyroShotgunArgs, MAX_WEAPON_ARG_LENGTH);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, WA_STRING, 14, WA_SniperRifleArgs, MAX_WEAPON_ARG_LENGTH);
			
			// heavy HP drain weapons
			char heavyHPDrainWeapons[WA_MAX_HP_DRAIN_WEAPONS * 6];
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, WA_STRING, 15, heavyHPDrainWeapons, WA_MAX_HP_DRAIN_WEAPONS * 6);
			char hhdwStrings[WA_MAX_HP_DRAIN_WEAPONS][6];
			ExplodeString(heavyHPDrainWeapons, ",", hhdwStrings, WA_MAX_HP_DRAIN_WEAPONS, 6);
			for (int i = 0; i < WA_MAX_HP_DRAIN_WEAPONS; i++)
				WA_HeavyHPDrainWeapons[i] = StringToInt(hhdwStrings[i]);
				
			// arg 16 and 17
			WA_DontShowNoOverlayInstructions = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, WA_STRING, 16) == 1);
			WA_DontSwitchToGoodWater = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, WA_STRING, 17) == 1);
			
			// rocket minicrit blacklist
			char rocketMinicritBlacklist[WA_MAX_ROCKET_MINICRIT_BLACKLIST * 6];
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, WA_STRING, 18, rocketMinicritBlacklist, WA_MAX_ROCKET_MINICRIT_BLACKLIST * 6);
			WA_RocketMinicritDisabled = !strcmp(rocketMinicritBlacklist, "*");
			if (!WA_RocketMinicritDisabled)
			{
				char rmdStrings[WA_MAX_ROCKET_MINICRIT_BLACKLIST][6];
				ExplodeString(rocketMinicritBlacklist, ",", rmdStrings, WA_MAX_ROCKET_MINICRIT_BLACKLIST, 6);
				for (int i = 0; i < WA_MAX_ROCKET_MINICRIT_BLACKLIST; i++)
					WA_SoldierNoMinicritWeapons[i] = StringToInt(rmdStrings[i]);
			}
			
			// precache
			if (strlen(WA_UnderwaterSound) > 3)
				PrecacheSound(WA_UnderwaterSound);
			PrecacheSound(WA_HEAVY_EATING_SOUND);
			PrecacheSound(WA_SCOUT_DRINKING_SOUND);
			PrecacheSound(WA_CROUCH_JEER_SOUND);
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, UC_STRING))
		{
			UC_ActiveThisRound = true;
			UC_CanUse[clientIdx] = true;
			
			UC_ChargeType[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, UC_STRING, 1);
			UC_VelDampening[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, UC_STRING, 2);
			UC_ChargeVel[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, UC_STRING, 3);
			UC_ChargeRefreshInterval[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, UC_STRING, 4);
			UC_Duration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, UC_STRING, 5);
			UC_Cooldown[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, UC_STRING, 6);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, UC_STRING, 7, UC_Sound, MAX_SOUND_FILE_LENGTH);
			UC_RageCost[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, UC_STRING, 8);
			UC_AltFireActivated[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, UC_STRING, 9) == 1;
			
			// HUD strings
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, UC_STRING, 16, UC_CooldownStr, MAX_CENTER_TEXT_LENGTH);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, UC_STRING, 17, UC_InstructionStr, MAX_CENTER_TEXT_LENGTH);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, UC_STRING, 18, UC_NotEnoughRageStr, MAX_CENTER_TEXT_LENGTH);

			// precaches and inits
			if (strlen(UC_Sound) > 3)
				PrecacheSound(UC_Sound);
			UC_EndChargeAt[clientIdx] = FAR_FUTURE;
			UC_RefreshChargeAt[clientIdx] = FAR_FUTURE;
			UC_UsableAt[clientIdx] = GetEngineTime();
			UC_KeyDown[clientIdx] = false;
			UC_NextHUDAt[clientIdx] = GetEngineTime();
			
			// warn user they're using a bad ability combo
			if (UC_CanUse[clientIdx] && !WA_ActiveThisRound)
				PrintToServer("[sarysamods6] WARNING: You're using ability %s without ability %s. If this is part of a duo boss and the other has %s, that is fine. Otherwise, expect ability performance to suck.", UC_STRING, UC_STRING, WA_STRING);
				
			if (PRINT_DEBUG_INFO)
				PrintToServer("[sarysamods6] %d using underwater charge this round.", clientIdx);
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, US_STRING))
		{
			US_ActiveThisRound = true;
			US_CanUse[clientIdx] = true;
			US_MaxHP[clientIdx] = 300;
			US_TicksForMaxHP[clientIdx] = 66; // one full second
			
			US_StartSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, US_STRING, 1);
			US_EndSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, US_STRING, 2);
		}
	}
	
	if (RP_ActiveThisRound)
	{
		for (int i = 0; i < MAX_PARASITES; i++)
		{
			RPP_Owner[i] = -1;
		}
		
		if (RP_DamageHooksNeeded)
		{
			for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
			{
				if (IsClientInGame(clientIdx))
					SDKHook(clientIdx, SDKHook_OnTakeDamage, RP_OnTakeDamage);
			}
		}
	}
	
	if (WA_ActiveThisRound)
	{
		WA_AddHooks();
		WA_ReplaceBrokenWeapons();
		WA_PerformDX80Check();

		// check user IDs for overlay opt out still match
		for (int clientIdx = 0; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (!IsLivingPlayer(clientIdx))
				continue;
				
			if (WA_OverlayOptOut[clientIdx] && WA_OOOUserId[clientIdx] != GetClientUserId(clientIdx))
				WA_OverlayOptOut[clientIdx] = false;
			
			if (!WA_DontShowNoOverlayInstructions)
			{
				PrintCenterText(clientIdx, "If the water overlay is a missing texture\nand you cannot see anything, type\n!nooverlay in chat to remove.");
				CPrintToChat(clientIdx, "{black}If the water overlay is a missing texture\nand you cannot see anything, type\n!nooverlay in chat to remove.");
			}
		}
		
		// destroy all trigger_push entities on the map, since maps like crevice have a problem where you can't swim back up
		int triggerPush = -1;
		while ((triggerPush = FindEntityByClassname(triggerPush, "trigger_push")) != -1)
			AcceptEntityInput(triggerPush, "kill");
	}
}

public Action Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	RoundInProgress = false;
	
	// parasites
	if (RP_ActiveThisRound)
	{
		RP_ActiveThisRound = false;
		if (RP_DamageHooksNeeded)
		{
			RP_DamageHooksNeeded = false;
			for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
			{
				if (IsClientInGame(clientIdx))
					SDKUnhook(clientIdx, SDKHook_OnTakeDamage, RP_OnTakeDamage);
			}
		}

	}
	
	// zatoichi workaround
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (ZW_IsUsing[clientIdx])
		{
			ZW_IsUsing[clientIdx] = false;
			SDKUnhook(clientIdx, SDKHook_OnTakeDamage, OnTakeDamageZatoichi);
		}
	}
	
	if (WA_ActiveThisRound)
	{
		WA_RemoveHooks();
		WA_ActiveThisRound = false;
	}
	
	UC_ActiveThisRound = false;
	US_ActiveThisRound = false;
}

public Action FF2_OnAbility2(int bossPlayer, const char[] plugin_name, const char[] ability_name, int status)
{
	if (!RoundInProgress) // don't execute these rages with 0 players alive
		return Plugin_Continue;

	if (!strcmp(ability_name, RP_STRING))
		Rage_Parasite(bossPlayer);
		
	return Plugin_Continue;
}


/**
 * Parasite
 */
#define SPAWN_TYPE_ON_HALE 0
#define SPAWN_TYPE_RAY_TRACE 1
#define SPAWN_TYPE_NEAREST_ENEMY 2
#define SPAWN_TYPE_RANDOM_ENEMY 3
public void Rage_Parasite(int bossIdx)
{
	int clientIdx = bossIdx;
	
	// variables only needed at spawn time
	char modelName[MAX_MODEL_NAME_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RP_STRING, 1, modelName, MAX_MODEL_NAME_LENGTH);
	int spawnType = FF2_GetAbilityArgument(bossIdx, this_plugin_name, RP_STRING, 3);
	float timeToLive = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RP_STRING, 10);
	float delayToStart = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RP_STRING, 12);
	
	// figure out where to spawn the entity
	float bossOrigin[3];
	GetEntPropVector(clientIdx, Prop_Data, "m_vecOrigin", bossOrigin);
	float victimOrigin[3];
	float spawnPoint[3];
	if (spawnType == SPAWN_TYPE_RAY_TRACE)
	{
		float eyeAngles[3];
		float eyePosition[3];
		GetClientEyeAngles(clientIdx, eyeAngles);
		GetClientEyePosition(clientIdx, eyePosition);
		
		Handle trace;
		if ((RP_Flags[clientIdx] & RP_FLAG_PLAYERS_ON_RAY_TRACE) != 0)
			trace = TR_TraceRayFilterEx(eyePosition, eyeAngles, MASK_ALL, RayType_Infinite, TraceRedPlayers);
		else
			trace = TR_TraceRayFilterEx(eyePosition, eyeAngles, MASK_ALL, RayType_Infinite, TraceWallsOnly);
		bool playerHit = TR_GetHitGroup(trace) > 0; // group 0 is "generic" which I hope includes nothing. 1=head 2=chest 3=stomach 4=leftarm 5=rightarm 6=leftleg 7=rightleg (shareddefs.h)
		TR_GetEndPosition(spawnPoint, trace);
		CloseHandle(trace);
		
		// if we hit a wall, shorten the distance by about 25 so our object doesn't spawn half in a wall
		if (!playerHit)
		{
			float distance = GetVectorDistance(spawnPoint, eyePosition);
			if (distance > 25.0)
				constrainDistance(eyePosition, spawnPoint, distance, distance - 25.0);
		}
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysapub2] Spawning a parasite by ray trace. playerHit=%d. tracingPlayers=%d. Spawn point will be %f,%f,%f", playerHit, ((RP_Flags[clientIdx] & RP_FLAG_PLAYERS_ON_RAY_TRACE) != 0), spawnPoint[0], spawnPoint[1], spawnPoint[2]);
	}
	else if (spawnType == SPAWN_TYPE_ON_HALE)
	{
		spawnPoint[0] = bossOrigin[0];
		spawnPoint[1] = bossOrigin[1];
		spawnPoint[2] = bossOrigin[2] + RP_Z_OFFSET;
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysapub2] Spawning a parasite on the hale. Spawn point will be %f,%f,%f", spawnPoint[0], spawnPoint[1], spawnPoint[2]);
	}
	else if (spawnType == SPAWN_TYPE_RANDOM_ENEMY)
	{
		// try 50 times to find a living enemy, then fall back to nearest enemy
		int randomLivingPlayer = -1;
		for (int i = 0; i < 50; i++)
		{
			int testPlayer = GetRandomInt(1, MAX_PLAYERS);
			if (IsLivingPlayer(testPlayer) && GetClientTeam(testPlayer) != BossTeam)
			{
				randomLivingPlayer = testPlayer;
				break;
			}
		}
		
		// on failure to find a random living player, fall back to nearest
		if (randomLivingPlayer == -1)
			spawnType = SPAWN_TYPE_NEAREST_ENEMY;
		else
		{
			GetEntPropVector(randomLivingPlayer, Prop_Data, "m_vecOrigin", spawnPoint);
			spawnPoint[2] += RP_Z_OFFSET;
			
			if (PRINT_DEBUG_INFO)
				PrintToServer("[sarysapub2] Spawning a parasite on random player %d. Spawn point will be %f,%f,%f", randomLivingPlayer, spawnPoint[0], spawnPoint[1], spawnPoint[2]);
		}
	}
	
	// no else here since it may fall through
	if (spawnType == SPAWN_TYPE_NEAREST_ENEMY)
	{
		float shortestDistance = 99999.0 * 99999.0;
		int nearestVictim = clientIdx; // default to boss on failure
		for (int i = 1; i < MAX_PLAYERS; i++)
		{
			if (IsLivingPlayer(i) && GetClientTeam(i) != BossTeam)
			{
				GetEntPropVector(i, Prop_Data, "m_vecOrigin", victimOrigin);
				float distance = GetVectorDistance(victimOrigin, bossOrigin, true);
				if (distance < shortestDistance)
				{
					shortestDistance = distance;
					nearestVictim = i;
				}
			}
		}
		GetEntPropVector(nearestVictim, Prop_Data, "m_vecOrigin", spawnPoint);
		spawnPoint[2] += RP_Z_OFFSET;
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysapub2] Spawning a parasite on nearest player %d. Spawn point will be %f,%f,%f", nearestVictim, spawnPoint[0], spawnPoint[1], spawnPoint[2]);
	}
	
	// the model is a little more involved
	int prop = -1;
	if (strlen(modelName) > 3)
		prop = CreateEntityByName("prop_physics_override");
	if (IsValidEntity(prop))
	{
		SetEntProp(prop, Prop_Data, "m_takedamage", 0);
		
		// give it a random yaw
		float angles[3];
		angles[0] = 0.0;
		angles[1] = GetRandomFloat(-179.9, 179.9);
		SetEntPropVector(prop, Prop_Data, "m_angRotation", angles);
		
		// set the model
		SetEntityModel(prop, modelName);
		
		// spawn and move it
		DispatchSpawn(prop);
		TeleportEntity(prop, spawnPoint, NULL_VECTOR, NULL_VECTOR);
		SetEntProp(prop, Prop_Data, "m_takedamage", 0); // redundancy is redundant
	
		// no collision
		//SetEntityMoveType(prop, MOVETYPE_NOCLIP);
		//SetEntProp(prop, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_NONE);
		//SetEntProp(prop, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID);
		//SetEntProp(prop, Prop_Send, "m_nSolidType", SOLID_NONE);
		SetEntityMoveType(prop, MOVETYPE_NONE);
		SetEntProp(prop, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS);
		SetEntProp(prop, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID);
		SetEntProp(prop, Prop_Send, "m_nSolidType", SOLID_VPHYSICS);
		SetEntityGravity(prop, 0.0);
	}
	
	// create our effect next. if there's a prop, the effect attaches to the prop and will never attach to players.
	int effect = -1;
	if (strlen(RP_EffectName[clientIdx]) > 3)
	{
		if (!IsValidEntity(prop))
			effect = ParticleEffectAt(spawnPoint, RP_EffectName[clientIdx], 0.0); // 0.0 duration means no destruction timer
		else
			effect = AttachParticle(prop, RP_EffectName[clientIdx], 0.0, true); // attach it to the model at 0,0,0
	}
	
	if (PRINT_DEBUG_SPAM)
		PrintToServer("[sarysapub2] Parasite effect=%d model=%d     %s / %s", effect, prop, RP_EffectName[clientIdx], modelName);
	
	// find an open spot for this parasite and assign values
	int paraIdx = RPP_FindFreeIndex();
	RPP_Owner[paraIdx] = clientIdx;
	RPP_ModelEntRef[paraIdx] = prop == -1 ? -1 : EntRefToEntIndex(prop);
	RPP_ParticleEntRef[paraIdx] = effect == -1 ? -1 : EntRefToEntIndex(effect);
	RPP_CurrentVictim[paraIdx] = -1;
	RPP_DetachFromVictimAt[paraIdx] = 0.0;
	RPP_DieNaturallyAt[paraIdx] = GetEngineTime() + timeToLive;
	RPP_ImmuneVictim[paraIdx] = -1;
	RPP_ImmunityEndsAt[paraIdx] = 0.0;
	RPP_ActivateAt[paraIdx] = GetEngineTime() + delayToStart;
	RPP_NextDamageAt[paraIdx] = RPP_ActivateAt[paraIdx];
}

public void RPP_RemoveParasiteAt(int paraIdx)
{
	// clean this up
	Timer_RemoveEntity(INVALID_HANDLE, RPP_ParticleEntRef[paraIdx]); // particle goes first since it may be a child of the model
	Timer_RemoveEntity(INVALID_HANDLE, RPP_ModelEntRef[paraIdx]);

	// push everything down one
	for (int i = paraIdx; i < MAX_PARASITES - 1; i++)
	{
		RPP_Owner[i] = RPP_Owner[i+1];
		RPP_ModelEntRef[i] = RPP_ModelEntRef[i+1];
		RPP_ParticleEntRef[i] = RPP_ParticleEntRef[i+1];
		RPP_CurrentVictim[i] = RPP_CurrentVictim[i+1];
		RPP_DetachFromVictimAt[i] = RPP_DetachFromVictimAt[i+1];
		RPP_DieNaturallyAt[i] = RPP_DieNaturallyAt[i+1];
		RPP_ImmuneVictim[i] = RPP_ImmuneVictim[i+1];
		RPP_ImmunityEndsAt[i] = RPP_ImmunityEndsAt[i+1];
		RPP_ActivateAt[i] = RPP_ActivateAt[i+1];
		RPP_NextDamageAt[i] = RPP_NextDamageAt[i+1];
		RPP_SelfYawAtAttachTime[i] = RPP_SelfYawAtAttachTime[i+1];
		RPP_VictimYawAtAttachTime[i] = RPP_VictimYawAtAttachTime[i+1];
	}
	
	// and this ensures all dead items are -1
	RPP_Owner[MAX_PARASITES - 1] = -1;
}

public int RPP_FindFreeIndex()
{
	for (int i = 0; i < MAX_PARASITES; i++)
	{
		if (RPP_Owner[i] == -1)
			return i;
	}
	
	// we're full, remove the first parasite and assign the last
	RPP_RemoveParasiteAt(0);
	return MAX_PARASITES - 1;
}

public void RPP_DetachFromHost(int paraIdx)
{
	int prop = EntRefToEntIndex(RPP_ModelEntRef[paraIdx]);
	int effect = EntRefToEntIndex(RPP_ParticleEntRef[paraIdx]);
	if (IsValidEntity(prop))
	{
		SetEntityMoveType(prop, MOVETYPE_NONE);
		
		if (IsLivingPlayer(RPP_CurrentVictim[paraIdx]))
		{
			static float victimOrigin[3];
			GetEntPropVector(RPP_CurrentVictim[paraIdx], Prop_Data, "m_vecOrigin", victimOrigin);
			victimOrigin[2] += RP_ParasiteZOffset[RPP_Owner[paraIdx]];
			SetEntPropVector(prop, Prop_Data, "m_vecOrigin", victimOrigin);
		}
	}
	else if (IsValidEntity(effect)) // else if because if both exist, effect is always attached to prop
	{
		// trying to detach is a bit troublesome
		// so just spawn a int one in its place
		//static float spawnPoint[3];
		//GetEntPropVector(effect, Prop_Data, "m_vecOrigin", spawnPoint); // for some reason this is returning crap.
		Timer_RemoveEntity(INVALID_HANDLE, RPP_ParticleEntRef[paraIdx]);
		effect = ParticleEffectAt(RPP_VictimLastValidOrigin[paraIdx], RP_EffectName[RPP_Owner[paraIdx]], 0.0); // 0.0 duration means no destruction timer
		if (IsValidEntity(effect))
			RPP_ParticleEntRef[paraIdx] = EntIndexToEntRef(effect);
		else
			RPP_ParticleEntRef[paraIdx] = -1; // wtf?
	}
	
	RPP_ImmuneVictim[paraIdx] = RPP_CurrentVictim[paraIdx];
	RPP_ImmunityEndsAt[paraIdx] = GetEngineTime() + RP_ImmunityDuration[RPP_Owner[paraIdx]];
	
	RPP_CurrentVictim[paraIdx] = -1;
}

public Action RP_OnTakeDamage(int victim, int& attacker, int& inflictor, 
							float& damage, int& dmgtype, int& weapon, 
							float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
		return Plugin_Continue;
	if (!RP_ActiveThisRound || !RP_DamageHooksNeeded)
	{
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysapub2] Warning: Need to remove late parasite rage damage hook from player %d", victim);
		SDKUnhook(victim, SDKHook_OnTakeDamage, RP_OnTakeDamage);
		return Plugin_Continue;
	}
	
	// don't include fall damage
	if (victim == attacker && (dmgtype & DMG_FALL) == 0)
	{
		// don't include damage over time from GRU or other health drain attributes
		if (!(dmgtype == 0 && damagecustom == 0))
		{
			// see if this player has parasites attached, remove them all if so
			for (int i = MAX_PARASITES - 1; i >= 0; i--)
			{
				if (RPP_Owner[i] > 0 && RPP_CurrentVictim[i] == victim)
				{
					RPP_DetachFromHost(i);
					
					if ((RP_Flags[RPP_Owner[i]] & RP_FLAG_MULTIPLE_HOSTS) == 0)
						RPP_RemoveParasiteAt(i);
				}
			}
		}
	}
	
	return Plugin_Continue;
}

/**
 * Water Arena
 */
public void WA_DX80Result(QueryCookie cookie, int clientIdx, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	if (result == ConVarQuery_Okay)
	{
		if (cvarValue[0] > '0' && cvarValue[0] < '9')
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods7] Client %d has directX level below 9. Overlay is not supported.", clientIdx);
			WA_OverlaySupported[clientIdx] = false;
		}
	}
	else if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods7] WARNING: DX8 query failed for %d. Result is %d (note, this is rare, but expected)", clientIdx, result);
}
 
public Action WA_PerformDX80Check()
{
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		WA_OverlaySupported[clientIdx] = false;
		if (IsClientInGame(clientIdx))
		{
			WA_OverlaySupported[clientIdx] = true;
			QueryClientConVar(clientIdx, "mat_dxlevel", WA_DX80Result);
		}
	}
}
 
public Action WA_NoOverlay(int clientIdx, int argsInt)
{
	WA_OverlayOptOut[clientIdx] = true;
	WA_OOOUserId[clientIdx] = GetClientUserId(clientIdx);
	if (WA_ActiveThisRound)
		WA_FixOverlay(clientIdx, true);

	PrintCenterText(clientIdx, "You have chosen not to show the water overlay.\nThis setting will remain until map change or you log out.\nType !yesoverlay to restore water overlay.");
	return Plugin_Handled;
}

public Action WA_YesOverlay(int clientIdx, int argsInt)
{
	WA_OverlayOptOut[clientIdx] = false;
	if (WA_ActiveThisRound)
		WA_FixOverlay(clientIdx, false);
		
	PrintCenterText(clientIdx, "You have chosen to show the water overlay.\nType !nooverlay if you have problems with it.");
	return Plugin_Handled;
}
 
public void WA_SetToFirstPerson(int clientIdx)
{
	int flags = GetCommandFlags("firstperson");
	SetCommandFlags("firstperson", flags & ~FCVAR_CHEAT);
	ClientCommand(clientIdx, "firstperson");
	SetCommandFlags("firstperson", flags);
}

public void WA_SetToThirdPerson(int clientIdx)
{
	int flags = GetCommandFlags("thirdperson");
	SetCommandFlags("thirdperson", flags & ~FCVAR_CHEAT);
	ClientCommand(clientIdx, "thirdperson");
	SetCommandFlags("thirdperson", flags);
}
 
public Action WA_OnCmdThirdPerson(int clientIdx, const char[] command, int argc)
{
	if (!WA_ActiveThisRound)
		return Plugin_Continue; // just in case
		
	WA_IsThirdPerson[clientIdx] = true;
	if (IsLivingPlayer(clientIdx) && TF2_IsPlayerInCondition(clientIdx, COND_JARATE_WATER))
		WA_SetToThirdPerson(clientIdx);
		
	return Plugin_Continue;
}

public Action WA_OnCmdFirstPerson(int clientIdx, const char[] command, int argc)
{
	if (!WA_ActiveThisRound)
		return Plugin_Continue; // just in case
		
	WA_IsThirdPerson[clientIdx] = false;
	if (IsLivingPlayer(clientIdx) && TF2_IsPlayerInCondition(clientIdx, COND_JARATE_WATER))
		WA_SetToFirstPerson(clientIdx);
		
	return Plugin_Continue;
}

public Action OnStomp(int attacker, int victim, float& damageMultiplier, float& damageBonus, float& JumpPower)
{
	// disable goombas entirely in a water arena
	if (WA_ActiveThisRound)
		return Plugin_Handled;
		
	return Plugin_Continue;
}

// only do this once. people shouldn't be latespawning at all, after all...
public void WA_ReplaceBrokenWeapons()
{
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!IsLivingPlayer(clientIdx))
			continue;
	
		TFClassType playerClass = TF2_GetPlayerClass(clientIdx);
		if (playerClass == TFClass_Pyro)
		{
			// only allow shotgun secondary. replace all others with stock shotgun.
			int secondary = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Secondary);
			if (!IsValidEntity(secondary))
				continue;
				
			char classname[MAX_ENTITY_CLASSNAME_LENGTH];
			GetEntityClassname(secondary, classname, MAX_ENTITY_CLASSNAME_LENGTH);
			if (StrContains(classname, "tf_weapon_shotgun") == -1) // this should be 95% future-proof.
			{
				TF2_RemoveWeaponSlot(clientIdx, TFWeaponSlot_Secondary);
				int weapon = SpawnWeapon(clientIdx, "tf_weapon_shotgun_pyro", 12, 1, 0, WA_PyroShotgunArgs);
				if (IsValidEntity(weapon))
				{
					int offset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1);
					SetEntProp(clientIdx, Prop_Send, "m_iAmmo", 32, 4, offset);
				}
				PrintToChat(clientIdx, "Your Pyro secondary doesn't work in water. Replaced with a shotgun.");
			}
		}
		else if (playerClass == TFClass_Sniper)
		{
			// only allow shotgun secondary. replace all others with stock shotgun.
			int primary = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary);
			if (!IsValidEntity(primary))
				continue;
				
			char classname[MAX_ENTITY_CLASSNAME_LENGTH];
			GetEntityClassname(primary, classname, MAX_ENTITY_CLASSNAME_LENGTH);
			if (!strcmp(classname, "tf_weapon_compound_bow")) // this should be 95% future-proof.
			{
				TF2_RemoveWeaponSlot(clientIdx, TFWeaponSlot_Primary);
				int weapon = SpawnWeapon(clientIdx, "tf_weapon_sniperrifle", 14, 1, 0, WA_SniperRifleArgs);
				if (IsValidEntity(weapon))
				{
					SetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon", weapon);
					int offset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1);
					SetEntProp(clientIdx, Prop_Send, "m_iAmmo", 25, 4, offset);
				}
				PrintToChat(clientIdx, "Your bow doesn't work in water. Replaced with a sniper rifle.");
			}
		}
		else if (playerClass == TFClass_Heavy)
		{
			// dalokohs or fishcake secondary
			int secondary = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Secondary);
			if (!IsValidEntity(secondary))
				continue;
				
			int weaponIdx = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
			if (weaponIdx == 159 || weaponIdx == 433)
			{
				TF2_RemoveWeaponSlot(clientIdx, TFWeaponSlot_Secondary);
				char attr[20];
				Format(attr, sizeof(attr), "26 ; %f", WA_HeavyDalokohsBoost);
				SpawnWeapon(clientIdx, "tf_weapon_lunchbox", weaponIdx, 1, 0, attr);
				PrintToChat(clientIdx, "Your Dalokohs has given you a permanent HP boost this round.");
			}
		}
	}
}

public bool WA_ShouldHaveLameWater(int clientIdx)
{
	return IsLivingPlayer(clientIdx) && ((GetClientTeam(clientIdx) == BossTeam && !WA_AllEngiesDead) || WA_UsingSpellbookLameWater[clientIdx] || WA_RemoveLameWaterAt[clientIdx] != FAR_FUTURE);
}

public void WA_PreThink(int clientIdx) // credit to phatrages. kint about this prop but I would never have thought I needed to do this in a think.
{
	if (!WA_ActiveThisRound) // just in case
		SDKUnhook(clientIdx, SDKHook_PreThink, WA_PreThink);

	if (WA_ShouldHaveLameWater(clientIdx))
	{
		if (WA_NoWaterUntil[clientIdx] > GetEngineTime())
		{
			//PrintToServer("no water %d", clientIdx);
			SetEntProp(clientIdx, Prop_Send, "m_nWaterLevel", 0);
		}
		else
			SetEntProp(clientIdx, Prop_Send, "m_nWaterLevel", 3);
	}
	
	if (US_ActiveThisRound && IsLivingPlayer(clientIdx))
	{
		if (US_CanUse[clientIdx] && US_TicksForMaxHP[clientIdx] <= 0 && US_MaxHP[clientIdx] > 0)
		{
			float healthFactor = 1.0 - (float(GetEntProp(clientIdx, Prop_Data, "m_iHealth")) / float(US_MaxHP[clientIdx]));
			float moveSpeed = US_StartSpeed[clientIdx] + ((US_EndSpeed[clientIdx] - US_StartSpeed[clientIdx]) * healthFactor);
			if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed))
				moveSpeed *= 0.5;
			SetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed", moveSpeed);
		}
	}
}

public void WA_FixOverlay(int clientIdx, bool remove)
{
	int flags = GetCommandFlags("r_screenoverlay");
	SetCommandFlags("r_screenoverlay", flags & ~FCVAR_CHEAT);
	if (remove || WA_OverlayOptOut[clientIdx] || !WA_OverlaySupported[clientIdx])
		ClientCommand(clientIdx, "r_screenoverlay \"\"");
	else
		ClientCommand(clientIdx, "r_screenoverlay \"%s\"", WA_UnderwaterOverlay);
	SetCommandFlags("r_screenoverlay", flags);
}

public void WA_GoodWater(int clientIdx)
{
	TF2_AddCondition(clientIdx, COND_JARATE_WATER, -1.0);
	
	// fix to first person
	if (GetEntProp(clientIdx, Prop_Send, "m_nForceTauntCam") == 0)
	{
		WA_SetToFirstPerson(clientIdx);
		WA_IsThirdPerson[clientIdx] = false;
		for (int i = 0; i < FIX_PERSPECTIVE_COUNT; i++)
			WA_FixPerspectiveAt[clientIdx][i] = GetEngineTime() + (0.5 * (i+1)); // a backup perspective fix
	}
	else
		WA_IsThirdPerson[clientIdx] = true;
	
	// fix the overlay now
	WA_FixOverlay(clientIdx, false);
	
	// never play underwater sound
	WA_PlayWaterSoundAt[clientIdx] = FAR_FUTURE;
}

public void WA_LameWater(int clientIdx)
{
	WA_FixOverlay(clientIdx, false);
	WA_PlayWaterSoundAt[clientIdx] = GetEngineTime();
}

public bool WA_SpellbookActive(int clientIdx)
{
	int weapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(weapon))
		return false;
		
	static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
	GetEntityClassname(weapon, classname, MAX_ENTITY_CLASSNAME_LENGTH);
	if (!strcmp(classname, "tf_weapon_spellbook"))
		return true;
	return false;
}

public Action WA_OnTakeDamage(int victim, int& attacker, int& inflictor, 
							float& damage, int& damagetype, int& weapon,
							float damageForce[3], float damagePosition[3], int damagecustom)
{
	// don't let users drown or catch fire.
	if (damagetype & (DMG_DROWN | DMG_BURN))
		return Plugin_Handled;
		
	// boost pyro damage
	if (IsLivingPlayer(attacker) && TF2_GetPlayerClass(attacker) == TFClass_Pyro)
	{
		if (weapon == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Secondary))
		{
			damage *= WA_PyroSecondaryBoost;
			return Plugin_Changed;
		}
		else if (weapon == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee))
		{
			damage *= WA_PyroMeleeBoost;
			return Plugin_Changed;
		}
	}
		
	return Plugin_Continue;
}
 
public void WA_AddHooks()
{
	HookEvent("player_spawn", WA_PlayerSpawn, EventHookMode_Post);
	AddCommandListener(WA_OnCmdThirdPerson, "tp");
	AddCommandListener(WA_OnCmdThirdPerson, "sm_thirdperson");
	AddCommandListener(WA_OnCmdFirstPerson, "fp");
	AddCommandListener(WA_OnCmdFirstPerson, "sm_firstperson");
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!IsLivingPlayer(clientIdx))
			continue;
	
		if (GetClientTeam(clientIdx) == BossTeam)
			WA_LameWater(clientIdx);
		else
			WA_GoodWater(clientIdx);
		SDKHook(clientIdx, SDKHook_PreThink, WA_PreThink); // every player needs to use this, because of spellbook issue
		SDKHook(clientIdx, SDKHook_OnTakeDamage, WA_OnTakeDamage);
	}
}

public void WA_RemoveHooks()
{
	UnhookEvent("player_spawn", WA_PlayerSpawn, EventHookMode_Post);
	RemoveCommandListener(WA_OnCmdThirdPerson, "tp");
	RemoveCommandListener(WA_OnCmdThirdPerson, "sm_thirdperson");
	RemoveCommandListener(WA_OnCmdFirstPerson, "fp");
	RemoveCommandListener(WA_OnCmdFirstPerson, "sm_firstperson");
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		// must remove hooks from dead players as well.
		if (!IsClientInGame(clientIdx))
			continue;
	
		SDKUnhook(clientIdx, SDKHook_PreThink, WA_PreThink);
		SDKUnhook(clientIdx, SDKHook_OnTakeDamage, WA_OnTakeDamage);
		WA_FixOverlay(clientIdx, true); // remove water overlay
		
		// in case they're immobile or still in water
		if (IsLivingPlayer(clientIdx))
		{
			SetEntityMoveType(clientIdx, MOVETYPE_WALK);

			if (TF2_IsPlayerInCondition(clientIdx, COND_JARATE_WATER))
				TF2_RemoveCondition(clientIdx, COND_JARATE_WATER);
		}
	}
}

public Action WA_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int clientIdx = GetClientOfUserId(GetEventInt(event, "userid"));

	// if someone latespawned or was summoned, the hooks need to be applied to them
	if (GetClientTeam(clientIdx) == BossTeam)
		WA_LameWater(clientIdx);
	else
		WA_GoodWater(clientIdx);
	SDKHook(clientIdx, SDKHook_PreThink, WA_PreThink); // every player needs to use this, because of spellbook issue
	SDKHook(clientIdx, SDKHook_OnTakeDamage, WA_OnTakeDamage);
}

// based on asherkin and voogru's code, though this is almost exactly like the code used for Snowdrop's rockets
// luckily energy ball and sentry rocket derive from rocket so they should be easy
public void WA_CreateRocket(int owner, float position[3], float angle[3])
{
	// create our rocket. no matter what, it's going to spawn, even if it ends up being out of map
	float speed = WA_Velocity;
	float damage = WA_Damage;
	//PrintToServer("speed=%f    damage=%f", speed, damage);
	
	int rocket = CreateEntityByName("tf_projectile_rocket");
	if (!IsValidEntity(rocket))
	{
		PrintToServer("[sarysamods6] Error: Invalid entity \"tf_projectile_rocket\". Won't spawn rocket. This is sarysa's fault.");
		return;
	}
	
	// determine spawn position
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
	SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", owner);
	SetVariantInt(MercTeam);
	AcceptEntityInput(rocket, "TeamNum", -1, -1, 0);
	SetVariantInt(MercTeam);
	AcceptEntityInput(rocket, "SetTeam", -1, -1, 0); 
	DispatchSpawn(rocket);
	
	// to get stats from the sentry
	SetEntPropEnt(rocket, Prop_Send, "m_hOriginalLauncher", GetPlayerWeaponSlot(owner, TFWeaponSlot_Melee));
	SetEntPropEnt(rocket, Prop_Send, "m_hLauncher", GetPlayerWeaponSlot(owner, TFWeaponSlot_Melee));
}

public void WA_Tick(float curTime)
{
	// fix the water overlay periodically
	if (curTime >= WA_FixOverlayAt)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
				WA_FixOverlay(clientIdx, false);
		}
		
		WA_FixOverlayAt = curTime + WA_FixInterval;
	}
	
	// fix the water condition periodically
	if (curTime >= WA_MassRestoreWaterAt)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (!IsLivingPlayer(clientIdx))
				continue;
		
			if (!TF2_IsPlayerInCondition(clientIdx, COND_JARATE_WATER) && WA_RestoreWaterAt[clientIdx] == FAR_FUTURE && !WA_ShouldHaveLameWater(clientIdx))
				TF2_AddCondition(clientIdx, COND_JARATE_WATER, -1.0);
		}
	
		WA_MassRestoreWaterAt = curTime + WA_WATER_RESTORE_INTERVAL;
	}
	
	// individual intervals for special actions that must be handled
	bool engieFound = false;
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		// prevent replacement client, who could be dx8, from getting overlay in spectate if not supported
		if (!IsClientInGame(clientIdx))
			WA_OverlaySupported[clientIdx] = false;
	
		if (!IsLivingPlayer(clientIdx))
			continue;
			
		if (GetClientTeam(clientIdx) == MercTeam && TF2_GetPlayerClass(clientIdx) == TFClass_Engineer)
			engieFound = true;
			
		// remove jarate
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_Jarated))
			TF2_RemoveCondition(clientIdx, TFCond_Jarated);
		
		// boss checks every frame
		if (GetClientTeam(clientIdx) == BossTeam)
		{
			if (WA_AllEngiesDead && !TF2_IsPlayerInCondition(clientIdx, COND_JARATE_WATER))
				WA_GoodWater(clientIdx);
			
			if (TF2_IsPlayerInCondition(clientIdx, TFCond_OnFire))
				TF2_RemoveCondition(clientIdx, TFCond_OnFire);
		}
		
		// soldier rocket minicrits
		if (!WA_RocketMinicritDisabled && TF2_GetPlayerClass(clientIdx) == TFClass_Soldier)
		{
			bool shouldHaveMinicrits = false;
		
			int weaponIdx = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
			if (weaponIdx != -1 && weaponIdx == GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary))
			{
				bool blacklisted = false;
				for (int i = 0; i < WA_MAX_ROCKET_MINICRIT_BLACKLIST; i++)
				{
					if (WA_SoldierNoMinicritWeapons[i] == 0)
						break;
					else if (WA_SoldierNoMinicritWeapons[i] == weaponIdx)
					{
						blacklisted = true;
						break;
					}
				}
				
				if (!blacklisted)
					shouldHaveMinicrits = true;
			}
			
			if (TF2_IsPlayerInCondition(clientIdx, TFCond_CritCola) && !shouldHaveMinicrits)
				TF2_RemoveCondition(clientIdx, TFCond_CritCola);
			else if (!TF2_IsPlayerInCondition(clientIdx, TFCond_CritCola) && shouldHaveMinicrits)
				TF2_AddCondition(clientIdx, TFCond_CritCola, -1.0);
		}
		
		// in case the perspective isn't fixed the first time, which sometimes happens
		for (int i = 0; i < FIX_PERSPECTIVE_COUNT; i++)
		{
			if (curTime >= WA_FixPerspectiveAt[clientIdx][i])
			{
				WA_FixPerspectiveAt[clientIdx][i] = FAR_FUTURE;
				WA_SetToFirstPerson(clientIdx);
			}
		}

		// replay the water sound for folks with lame water
		if (curTime >= WA_PlayWaterSoundAt[clientIdx])
		{
			if (strlen(WA_UnderwaterSound) > 3)
				EmitSoundToClient(clientIdx, WA_UnderwaterSound);
			WA_PlayWaterSoundAt[clientIdx] = curTime + WA_SoundLoopInterval;
		}
		
		// restore water, i.e. for engineers. only good water users will ever need this.
		if (curTime >= WA_RestoreWaterAt[clientIdx] && !TF2_IsPlayerInCondition(clientIdx, TFCond_Taunting))
		{
			SetEntityMoveType(clientIdx, MOVETYPE_WALK);
			WA_GoodWater(clientIdx);
		}
		
		// heavy food, manual consumption
		if (WA_IsEatingHeavyFood[clientIdx])
		{
			int expectedTicks = RoundFloat((4.0 * (curTime - WA_HeavyFoodStartedAt[clientIdx])) / WA_HEAVY_CONSUMPTION_TIME);
			if (expectedTicks > 4)
				expectedTicks = 4;
			
			if (expectedTicks > WA_HeavyFoodTickCount[clientIdx])
			{
				WA_HeavyFoodTickCount[clientIdx]++;
				int actualMaxHP = (WA_IsDalokohs[clientIdx] ? RoundFloat(WA_HeavyDalokohsBoost) : 0) + GetEntProp(clientIdx, Prop_Data, "m_iMaxHealth");
				
				if (GetEntProp(clientIdx, Prop_Send, "m_iHealth") < actualMaxHP)
				{
					// sandvich or dalo..?
					int hpThisTick = WA_HeavyFoodHPPerTick[clientIdx];
					int hpToSet = GetEntProp(clientIdx, Prop_Send, "m_iHealth") + hpThisTick;
					hpToSet = min(hpToSet, actualMaxHP);
					SetEntProp(clientIdx, Prop_Data, "m_iHealth", hpToSet);
					SetEntProp(clientIdx, Prop_Send, "m_iHealth", hpToSet);
				}
			}
			
			if (curTime > WA_HeavyFoodStartedAt[clientIdx] + WA_HEAVY_CONSUMPTION_TIME)
			{
				SetEntityMoveType(clientIdx, MOVETYPE_WALK);
				TF2_RemoveCondition(clientIdx, TFCond_Dazed);
				if (!WA_IsThirdPerson[clientIdx])
					WA_SetToFirstPerson(clientIdx);
				WA_IsEatingHeavyFood[clientIdx] = false;
			}
		}
		else if (WA_EffectLastsUntil[clientIdx] != 0.0)
		{
			if (curTime >= WA_EffectLastsUntil[clientIdx] && !WA_IsDrinking[clientIdx])
			{
				if (WA_IsBonk[clientIdx] && TF2_IsPlayerInCondition(clientIdx, TFCond_Bonked))
					TF2_RemoveCondition(clientIdx, TFCond_Bonked);
				else if (!WA_IsBonk[clientIdx] && TF2_IsPlayerInCondition(clientIdx, TFCond_CritCola))
					TF2_RemoveCondition(clientIdx, TFCond_CritCola);
					
				if (!WA_IsThirdPerson[clientIdx] && WA_IsBonk[clientIdx])
					WA_SetToFirstPerson(clientIdx);
					
				WA_EffectLastsUntil[clientIdx] = 0.0;
			}
			else if (!WA_IsDrinking[clientIdx])
			{
				if (WA_IsBonk[clientIdx] && !TF2_IsPlayerInCondition(clientIdx, TFCond_Bonked))
					TF2_AddCondition(clientIdx, TFCond_Bonked, -1.0);
				else if (!WA_IsBonk[clientIdx] && !TF2_IsPlayerInCondition(clientIdx, TFCond_CritCola))
					TF2_AddCondition(clientIdx, TFCond_CritCola, -1.0);
			}
			
			if (WA_IsDrinking[clientIdx] && curTime >= WA_DrinkingUntil[clientIdx])
			{
				WA_DrinkingUntil[clientIdx] = FAR_FUTURE;
				WA_IsDrinking[clientIdx] = false;
				SetEntityMoveType(clientIdx, MOVETYPE_WALK);
				if (!WA_IsThirdPerson[clientIdx] && !WA_IsBonk[clientIdx])
					WA_SetToFirstPerson(clientIdx);
				TF2_RemoveCondition(clientIdx, TFCond_Dazed);
			}
		}
		
		// has to be checked every tick
		if (WA_UsingSpellbookLameWater[clientIdx] && !WA_SpellbookActive(clientIdx))
		{
			if (WA_RemoveLameWaterAt[clientIdx] == FAR_FUTURE)
				WA_GoodWater(clientIdx);
			WA_UsingSpellbookLameWater[clientIdx] = false;
		}
		else if (!WA_UsingSpellbookLameWater[clientIdx] && WA_SpellbookActive(clientIdx))
		{
			if (WA_RemoveLameWaterAt[clientIdx] == FAR_FUTURE)
			{
				TF2_RemoveCondition(clientIdx, COND_JARATE_WATER);
				WA_LameWater(clientIdx);
			}
			WA_UsingSpellbookLameWater[clientIdx] = true;
		}
		
		// remove lame water used by sandman at the appropriate time
		if (curTime >= WA_RemoveLameWaterAt[clientIdx] && WA_RemoveLameWaterAt[clientIdx] != FAR_FUTURE)
		{
			if (!WA_UsingSpellbookLameWater[clientIdx])
				WA_GoodWater(clientIdx);
				
			WA_RemoveLameWaterAt[clientIdx] = FAR_FUTURE;
		}
	}
	WA_AllEngiesDead = !engieFound && !WA_DontSwitchToGoodWater;
	
	// replace spell fireballs with rockets
	int fireball = FindEntityByClassname(-1, "tf_projectile_spellfireball");
	if (IsValidEntity(fireball))
	{
		int owner = GetEntPropEnt(fireball, Prop_Send, "m_hOwnerEntity");
		static float position[3];
		static float angle[3];
		GetEntPropVector(fireball, Prop_Data, "m_angRotation", angle);
		GetEntPropVector(fireball, Prop_Data, "m_vecOrigin", position);
		
		// the only way to tell a meteor fireball from the other kind is to guess based on distance
		bool isMeteor = false;
		if (!IsLivingPlayer(owner))
			isMeteor = true; // high probability
		else
		{
			static float adjustedOwnerPos[3];
			GetEntPropVector(owner, Prop_Data, "m_vecOrigin", adjustedOwnerPos);
			adjustedOwnerPos[2] += 60.0;
			if (GetVectorDistance(adjustedOwnerPos, position, true) > (120.0 * 120.0))
				isMeteor = true;
		}
		
		if (isMeteor) // angle is BS. point it straight down.
			angle[0] = 90.0;
	
		AcceptEntityInput(fireball, "kill");
		WA_CreateRocket(owner, position, angle);
	}
}

public void WA_OnPlayerRunCmd(int clientIdx, int buttons)
{
	if (TF2_GetPlayerClass(clientIdx) == TFClass_Engineer && !WA_UsingSpellbookLameWater[clientIdx])
	{
		float curTime = GetEngineTime();
		bool useKeyDown = (buttons & IN_ATTACK2) != 0;
	
		if (useKeyDown && !WA_AltFireDown[clientIdx])
		{
			// make sure they're not using the wrangler. otherwise, they're trying to pick up a building.
			int weapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
			bool proceed = false;
			if (!IsValidEntity(weapon))
				proceed = true;
			else
			{
				int weaponIdx = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
				if (weaponIdx != 140 && weaponIdx != 1086) // wrangler and festive wrangler
					proceed = true;
			}
			
			// just in case, though the timing window for this weapon is miniscule
			if (!TF2_IsPlayerInCondition(clientIdx, COND_JARATE_WATER))
				proceed = false;
			
			if (proceed)
			{
				TF2_RemoveCondition(clientIdx, COND_JARATE_WATER);
				WA_FixOverlay(clientIdx, false);
				SetEntityMoveType(clientIdx, MOVETYPE_NONE);
				WA_RestoreWaterAt[clientIdx] = curTime + 0.01;
			}
		}
		
		WA_AltFireDown[clientIdx] = useKeyDown;
	}
	
	if (WA_AllowSandman && TF2_GetPlayerClass(clientIdx) == TFClass_Scout && !WA_UsingSpellbookLameWater[clientIdx] && WA_RemoveLameWaterAt[clientIdx] == FAR_FUTURE)
	{
		float curTime = GetEngineTime();
		bool useKeyDown = (buttons & IN_ATTACK2) != 0;
	
		if (useKeyDown && !WA_AltFireDown[clientIdx])
		{
			// make sure they're not using the wrangler. otherwise, they're trying to pick up a building.
			int weapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
			bool proceed = false;
			if (IsValidEntity(weapon))
			{
				static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
				GetEntityClassname(weapon, classname, MAX_ENTITY_CLASSNAME_LENGTH);
				if (!strcmp(classname, "tf_weapon_bat_wood"))
					proceed = true;
				else if (!strcmp(classname, "tf_weapon_bat_giftwrap"))
					proceed = true;
			}
			
			// just in case, though the timing window for this weapon is miniscule
			if (!TF2_IsPlayerInCondition(clientIdx, COND_JARATE_WATER))
				proceed = false;
			
			if (proceed)
			{
				TF2_RemoveCondition(clientIdx, COND_JARATE_WATER);
				WA_LameWater(clientIdx);
				WA_RemoveLameWaterAt[clientIdx] = curTime + WA_SANDMAN_LAMEWATER_DURATION;
			}
		}
		
		WA_AltFireDown[clientIdx] = useKeyDown;
	}
	
	if ((TF2_GetPlayerClass(clientIdx) == TFClass_Heavy || TF2_GetPlayerClass(clientIdx) == TFClass_Scout) && !WA_UsingSpellbookLameWater[clientIdx])
	{
		float curTime = GetEngineTime();
		bool useKeyDown = (buttons & IN_ATTACK) != 0;
		
		if (useKeyDown && !WA_FireDown[clientIdx])
		{
			// is active weapon lunchbox?
			int weapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
			if (!IsValidEntity(weapon))
				return;
				
			int weaponIdx = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			bool consumedSomething = false;
			if (TF2_GetPlayerClass(clientIdx) == TFClass_Heavy && !WA_IsEatingHeavyFood[clientIdx])
			{
				if ((weaponIdx == 42 || weaponIdx == 863 || weaponIdx == 1002) // sandvich
					|| (weaponIdx == 159 || weaponIdx == 433)) // dalokohs
				{
					int actualMaxHP = (WA_IsDalokohs[clientIdx] ? RoundFloat(WA_HeavyDalokohsBoost) : 0) + GetEntProp(clientIdx, Prop_Data, "m_iMaxHealth");

					if (curTime < WA_ConsumableCooldownUntil[clientIdx])
					{
						Nope(clientIdx);
						PrintCenterText(clientIdx, "%.1f seconds cooldown remaining.", WA_ConsumableCooldownUntil[clientIdx] - curTime);
					}
					else if (GetEntProp(clientIdx, Prop_Send, "m_iHealth") >= actualMaxHP)
					{
						Nope(clientIdx);
						PrintCenterText(clientIdx, "Your health is already full!");
					}
					else
					{
						consumedSomething = true;
						PseudoAmbientSound(clientIdx, WA_HEAVY_EATING_SOUND, 1, 500.0);
						WA_HeavyFoodStartedAt[clientIdx] = curTime;
						WA_IsEatingHeavyFood[clientIdx] = true;
						WA_HeavyFoodTickCount[clientIdx] = 0;

						if (weaponIdx == 159 || weaponIdx == 433)
						{
							WA_IsDalokohs[clientIdx] = true;
							WA_HeavyFoodHPPerTick[clientIdx] = WA_HeavyDalokohsTick;
						}
						else
						{
							WA_ConsumableCooldownUntil[clientIdx] = curTime + 30.0; // this is so fucking lame, but I can't figure out the good way
							WA_IsDalokohs[clientIdx] = false;
							WA_HeavyFoodHPPerTick[clientIdx] = WA_HeavySandvichTick;
						}
							
						// heavy will toss sandvich when bonkstuck, need to swap to a different item if possible
						// sarysa 2014-12-23, rarely tosses dalokohs as well, which is bad because it never regenerates.
						int weaponToSwap = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Melee);
						if (!IsValidEntity(weaponToSwap))
							weaponToSwap = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary);
						else
						{
							int meleeWeaponIdx = GetEntProp(weaponToSwap, Prop_Send, "m_iItemDefinitionIndex");

							// don't switch do a weapon that drains hp.
							for (int i = 0; i < WA_MAX_HP_DRAIN_WEAPONS; i++)
							{
								if (WA_HeavyHPDrainWeapons[i] == meleeWeaponIdx)
								{
									weaponToSwap = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary);
									break;
								}
							}
						}

						if (IsValidEntity(weaponToSwap))
							SetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon", weaponToSwap);
					}
				}
			}
			else if (TF2_GetPlayerClass(clientIdx) == TFClass_Scout && !WA_IsDrinking[clientIdx])
			{
				if (weaponIdx == 46 || weaponIdx == 163)
				{
					if (curTime < WA_ConsumableCooldownUntil[clientIdx])
					{
						Nope(clientIdx);
						PrintCenterText(clientIdx, "%.1f seconds cooldown remaining.", WA_ConsumableCooldownUntil[clientIdx] - curTime);
					}
					else
					{
						consumedSomething = true;
						PseudoAmbientSound(clientIdx, WA_SCOUT_DRINKING_SOUND, 1, 500.0);
						WA_IsDrinking[clientIdx] = true;
						WA_IsBonk[clientIdx] = (weaponIdx == 46);
						WA_DrinkingUntil[clientIdx] = curTime + 1.2;
						WA_EffectLastsUntil[clientIdx] = WA_DrinkingUntil[clientIdx] + 8.0;
						WA_ConsumableCooldownUntil[clientIdx] = curTime + 30.0; // this is so fucking lame, but I can't figure out the good way
						
						// swap to primary first, melee second. mainly for crit-a-cola
						int weaponToSwap = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary);
						if (!IsValidEntity(weaponToSwap))
							weaponToSwap = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Melee);
						if (IsValidEntity(weaponToSwap))
							SetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon", weaponToSwap);
					}
				}
			}
			
			if (consumedSomething)
			{
				int stunner = FindRandomPlayer(true);
				if (IsLivingPlayer(stunner))
					TF2_StunPlayer(clientIdx, 99999.0, 0.0, TF_STUNFLAG_BONKSTUCK | TF_STUNFLAG_NOSOUNDOREFFECT, stunner);
				SetEntityMoveType(clientIdx, MOVETYPE_NONE);
				WA_SetToThirdPerson(clientIdx);
			}
		}
	
		WA_FireDown[clientIdx] = useKeyDown;
	}
}

/**
 * Underwater Charge
 */
public void UC_Tick(int clientIdx, float curTime, int buttons)
{
	bool keyDown = UC_AltFireActivated[clientIdx] ? ((buttons & IN_ATTACK2) != 0) : ((buttons & IN_RELOAD) != 0);

	if (UC_EndChargeAt[clientIdx] != FAR_FUTURE)
	{
		if (curTime > UC_EndChargeAt[clientIdx])
		{
			UC_EndChargeAt[clientIdx] = FAR_FUTURE;
		}
	}
	else if (keyDown && !UC_KeyDown[clientIdx] && curTime >= UC_UsableAt[clientIdx])
	{
		int bossIdx = FF2_GetBossIndex(clientIdx);
		float bossRage = FF2_GetBossCharge(bossIdx, 0);
		if (UC_RageCost[clientIdx] > bossRage)
		{
			PrintCenterText(clientIdx, UC_NotEnoughRageStr, UC_RageCost[clientIdx]);
		}
		else
		{
			if (UC_RageCost[clientIdx] > 0.0)
				FF2_SetBossCharge(bossIdx, 0, bossRage - UC_RageCost[clientIdx]);
		
			// start the charge
			UC_EndChargeAt[clientIdx] = curTime + UC_Duration[clientIdx];
			UC_RefreshChargeAt[clientIdx] = curTime; // now!
			GetClientEyeAngles(clientIdx, UC_LockedAngle[clientIdx]);
			
			// play the sound
			if (strlen(UC_Sound) > 3)
				PseudoAmbientSound(clientIdx, UC_Sound);
			
			// cooldown!
			UC_UsableAt[clientIdx] = curTime + UC_Cooldown[clientIdx];
		}
	}
	
	// charge ticks
	if (UC_EndChargeAt[clientIdx] != FAR_FUTURE)
	{
		// force player angle if restricted type
		if (UC_ChargeType[clientIdx] == UC_TYPE_RESTRICTED)
		{
			TeleportEntity(clientIdx, NULL_VECTOR, UC_LockedAngle[clientIdx], NULL_VECTOR);
		}
		
		if (curTime >= UC_RefreshChargeAt[clientIdx])
		{
			static float velocity[3];
			GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", velocity);
			ScaleVector(velocity, UC_VelDampening[clientIdx]);
			
			static float newVelocity[3];
			static float angleToUse[3];
			if (UC_ChargeType[clientIdx] == UC_TYPE_RESTRICTED)
			{
				angleToUse[0] = UC_LockedAngle[clientIdx][0];
				angleToUse[1] = UC_LockedAngle[clientIdx][1];
				angleToUse[2] = UC_LockedAngle[clientIdx][2];
			}
			else
				GetClientEyeAngles(clientIdx, angleToUse);
			GetAngleVectors(angleToUse, newVelocity, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(newVelocity, UC_ChargeVel[clientIdx]);
			
			newVelocity[0] += velocity[0];
			newVelocity[1] += velocity[1];
			newVelocity[2] += velocity[2];
				
			TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, newVelocity);
			
			UC_RefreshChargeAt[clientIdx] = curTime + UC_ChargeRefreshInterval[clientIdx];
		}
	}
	
	// refresh the HUD
	if (curTime >= UC_NextHUDAt[clientIdx])
	{
		if (curTime >= UC_UsableAt[clientIdx])
		{
			SetHudTextParams(-1.0, UC_HUD_POSITION, UC_HUD_REFRESH_INTERVAL + 0.05, 64, 255, 64, 192);
			ShowHudText(clientIdx, -1, UC_InstructionStr);
		}
		else
		{
			SetHudTextParams(-1.0, UC_HUD_POSITION, UC_HUD_REFRESH_INTERVAL + 0.05, 255, 64, 64, 192);
			ShowHudText(clientIdx, -1, UC_CooldownStr, UC_UsableAt[clientIdx] - curTime);
		}

		UC_NextHUDAt[clientIdx] = curTime + UC_HUD_REFRESH_INTERVAL;
	}

	UC_KeyDown[clientIdx] = keyDown;
}

/**
 * OnPlayerRunCmd/OnGameFrame
 */
#define IMPERFECT_FLIGHT_FACTOR 25
public void OnGameFrame()
{
	if (!RoundInProgress)
		return;
		
	float curTime = GetEngineTime();

	if (RP_ActiveThisRound)
	{
		// we need to precache certain frequently accessed player data to save computational time
		static float clientBounds[MAX_PLAYERS_ARRAY][3];
		static bool clientValid[MAX_PLAYERS_ARRAY];
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			clientValid[clientIdx] = IsLivingPlayer(clientIdx) && GetClientTeam(clientIdx) != BossTeam;
			if (clientValid[clientIdx])
			{
				GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", clientBounds[clientIdx]);
			}
		}
	
		for (int paraIdx = MAX_PARASITES - 1; paraIdx >= 0; paraIdx--)
		{
			if (RPP_Owner[paraIdx] == -1)
				continue;
			else if (!IsLivingPlayer(RPP_Owner[paraIdx]))
			{
				RPP_RemoveParasiteAt(paraIdx);
				continue;
			}
			
			// don't do anything if it's not time to start this parasite
			if (RPP_ActivateAt[paraIdx] > curTime)
				continue;
				
			// need the bounds of this parasite, which may change over time
			int prop = EntRefToEntIndex(RPP_ModelEntRef[paraIdx]);
			int effect = EntRefToEntIndex(RPP_ParticleEntRef[paraIdx]);
			int bestObject = IsValidEntity(prop) ? prop : effect;
			if (!IsValidEntity(bestObject))
			{
				// wtf if it gets here, but I'm paranoid
				PrintToServer("[sarysapub2] ERROR: Somehow a parasite exists but there's no valid entity for it?!");
				RPP_RemoveParasiteAt(paraIdx);
				continue;
			}
			
			// is it time to die naturally?
			if (curTime >= RPP_DieNaturallyAt[paraIdx])
			{
				if (PRINT_DEBUG_SPAM)
					PrintToServer("[sarysapub2] Despawning parasite which reached its natural end of life.");
				RPP_RemoveParasiteAt(paraIdx);
				continue;
			}
			
			static float paraBounds[3];
			GetEntPropVector(bestObject, Prop_Data, "m_vecOrigin", paraBounds);
			int owner = RPP_Owner[paraIdx]; // for readability
			
			bool justAttached = false;
			
			// first check the validity of whatever we're currently attached to
			if (RPP_CurrentVictim[paraIdx] != -1)
			{
				bool shouldDetach = false;
				bool removedByUber = false;
				if (!IsLivingPlayer(RPP_CurrentVictim[paraIdx]))
				{
					if (PRINT_DEBUG_SPAM)
						PrintToServer("[sarysapub2] Detaching from dead victim %d", RPP_CurrentVictim[paraIdx]);
					shouldDetach = true;
				}
				else if (RPP_DetachFromVictimAt[paraIdx] <= curTime)
				{
					if (PRINT_DEBUG_SPAM)
						PrintToServer("[sarysapub2] Detaching from victim %d due to time limit", RPP_CurrentVictim[paraIdx]);
					shouldDetach = true;
				}
				else if (TF2_IsPlayerInCondition(RPP_CurrentVictim[paraIdx], TFCond_Ubercharged) && (RP_Flags[owner] & RP_FLAG_REMOVED_ON_UBER) != 0)
				{
					if (PRINT_DEBUG_SPAM)
						PrintToServer("[sarysapub2] Detaching from victim %d due to ubercharge", RPP_CurrentVictim[paraIdx]);
					shouldDetach = true;
					removedByUber = true;
				}
				
				if (shouldDetach)
				{
					RPP_DetachFromHost(paraIdx);
					
					if ((RP_Flags[owner] & RP_FLAG_MULTIPLE_HOSTS) == 0 || (removedByUber && (RP_Flags[owner] & RP_FLAG_SURVIVE_UBER_REMOVAL) == 0))
					{
						RPP_RemoveParasiteAt(paraIdx);
						continue;
					}
				}
			}
			
			// min and max bounds for parasite
			static float paraMin[3];
			static float paraMax[3];
			if ((RP_Flags[owner] & RP_FLAG_CYLINDER_COLLISION) == 0)
			{
				paraMin[0] = paraBounds[0] + RP_CollisionHull[owner][0][0];
				paraMin[1] = paraBounds[1] + RP_CollisionHull[owner][0][1];
				paraMin[2] = (paraBounds[2] + RP_CollisionHull[owner][0][2]) - 83.0;
				paraMax[0] = paraBounds[0] + RP_CollisionHull[owner][1][0];
				paraMax[1] = paraBounds[1] + RP_CollisionHull[owner][1][1];
				paraMax[2] = paraBounds[2] + RP_CollisionHull[owner][1][2];
			}

			// next, see if we should connect to something new
			if (!IsLivingPlayer(RPP_CurrentVictim[paraIdx]) && (RP_Flags[owner] & RP_FLAG_ATTACH) != 0)
			{
				for (int victim = 1; victim < MAX_PLAYERS; victim++)
				{
					if (!clientValid[victim])
						continue;
					else if (RPP_ImmuneVictim[paraIdx] == victim && RPP_ImmunityEndsAt[paraIdx] > curTime)
						continue;
					else if (TF2_IsPlayerInCondition(victim, TFCond_Ubercharged) && (RP_Flags[owner] & RP_FLAG_REMOVED_ON_UBER) != 0)
						continue;
						
					bool shouldConnect = false;
					if (RP_Flags[owner] & RP_FLAG_CYLINDER_COLLISION)
						shouldConnect = CylinderCollision(paraBounds, clientBounds[victim], fabs(RP_CollisionHull[owner][0][0]), (paraBounds[2] + RP_CollisionHull[owner][0][2]) - 83.0, paraBounds[2] + RP_CollisionHull[owner][1][2]);
					else
						shouldConnect = WithinBounds(clientBounds[victim], paraMin, paraMax);
						
					if (shouldConnect)
					{
						if (PRINT_DEBUG_SPAM)
							PrintToServer("[sarysapub2] Parasite will connect to user %d", victim);
					
						RPP_CurrentVictim[paraIdx] = victim;
						RPP_DetachFromVictimAt[paraIdx] = curTime + RP_StickDuration[owner];
						
						if (IsValidEntity(prop))
						{
							// bias toward lower client index, sucks to be you :P
							SetEntityMoveType(prop, MOVETYPE_VPHYSICS); // only vphysics work, not fly or noclip or anything else

							// get the yaw of both the prop and the player
							static float tmpAngle[3];
							GetEntPropVector(prop, Prop_Data, "m_angRotation", tmpAngle);
							RPP_SelfYawAtAttachTime[paraIdx] = tmpAngle[1];
							GetEntPropVector(RPP_CurrentVictim[paraIdx], Prop_Data, "m_angRotation", tmpAngle);
							RPP_VictimYawAtAttachTime[paraIdx] = tmpAngle[1];
						}
						else if (IsValidEntity(effect)) // else if ensures if both a prop AND an effect, the effect doesn't move
						{
							// trying to attach it later on is a bit troublesome
							// so just spawn a int one pre-attached to the player
							// first, remove the old of course...
							Timer_RemoveEntity(INVALID_HANDLE, RPP_ParticleEntRef[paraIdx]);
							
							// and then spawn the new.
							effect = AttachParticleToAttachment(victim, RP_EffectName[owner], RP_AttachmentPoint[owner]);
							if (IsValidEntity(effect))
								RPP_ParticleEntRef[paraIdx] = EntIndexToEntRef(effect);
							else
								RPP_ParticleEntRef[paraIdx] = -1; // wtf?

							if (PRINT_DEBUG_SPAM)
								PrintToServer("[sarysapub2] Parasite is an effect. Will connect to attachment point %s", RP_AttachmentPoint[owner]);
						}
						
						// signal that it just attached
						justAttached = true;
						
						break;
					}
				}
			}
			
			// now if we're connected to a victim still, teleport the model only to them (not the effect)
			if (IsLivingPlayer(RPP_CurrentVictim[paraIdx]) && IsValidEntity(prop))
			{
				// make sure the prop rotates with the victim
				static float victimAngle[3];
				GetEntPropVector(RPP_CurrentVictim[paraIdx], Prop_Data, "m_angRotation", victimAngle);
				static float newAngle[3];
				newAngle[0] = 0.0;
				newAngle[1] = fixAngle(RPP_SelfYawAtAttachTime[paraIdx] - (RPP_VictimYawAtAttachTime[paraIdx] - victimAngle[1]));
				newAngle[2] = 0.0;
				
				// offset the object accordingly
				static float newBounds[3];
				newBounds[0] = clientBounds[RPP_CurrentVictim[paraIdx]][0];
				newBounds[1] = clientBounds[RPP_CurrentVictim[paraIdx]][1];
				newBounds[2] = clientBounds[RPP_CurrentVictim[paraIdx]][2] + RP_ParasiteZOffset[owner];
				
				// teleport the prop if the jerky version is being used
				if (justAttached || ((RP_Flags[owner] & RP_FLAG_FLYING_PARASITE) == 0))
				{
					TeleportEntity(prop, newBounds, newAngle, NULL_VECTOR);
				}
				else
				{
					// the smoother version will just constantly attract the object to the moving player
					// it'll be close but by no means exact. exact is pretty much impossible.
					// also, the reason the below is 0.001 is because frames sometimes clump together
					// these clumped frames can cause the prop to jerk around in a different way than the intentionally jerky version
					if (curTime - RPP_LastTickTime > 0.001)
					{
						// make a velocity vector based on the bounds of the prop and the bounds of the victim
						static float newPropVelocity[3];
						newPropVelocity[0] = (newBounds[0] - paraBounds[0]) / (curTime - RPP_LastTickTime);
						newPropVelocity[1] = (newBounds[1] - paraBounds[1]) / (curTime - RPP_LastTickTime);
						newPropVelocity[2] = (newBounds[2] - paraBounds[2]) / (curTime - RPP_LastTickTime);
					
						// if we're going for imperfect flight, need to blend the old velocity with the int velocity
						// with bias toward the old velocity. if it's not imperfect flight, we're done here.
						if ((RP_Flags[owner] & RP_FLAG_IMPERFECT_FLIGHT) != 0)
						{
							static float oldPropVelocity[3];
							GetEntPropVector(prop, Prop_Data, "m_vecVelocity", oldPropVelocity);
							
							// lets try a ratio of 4:1 old:new
							newPropVelocity[0] = (oldPropVelocity[0] * float(IMPERFECT_FLIGHT_FACTOR-1) / float(IMPERFECT_FLIGHT_FACTOR)) + (newPropVelocity[0] / float(IMPERFECT_FLIGHT_FACTOR));
							newPropVelocity[1] = (oldPropVelocity[1] * float(IMPERFECT_FLIGHT_FACTOR-1) / float(IMPERFECT_FLIGHT_FACTOR)) + (newPropVelocity[1] / float(IMPERFECT_FLIGHT_FACTOR));
							// leave Z out of this, it doesn't look good
							//newPropVelocity[2] = (oldPropVelocity[2] * float(IMPERFECT_FLIGHT_FACTOR-1) / float(IMPERFECT_FLIGHT_FACTOR)) + (newPropVelocity[2] / float(IMPERFECT_FLIGHT_FACTOR));
						}
						//PrintToServer("vel = %f,%f,%f", newPropVelocity[0], newPropVelocity[1], newPropVelocity[2]);
						
						TeleportEntity(prop, NULL_VECTOR, newAngle, newPropVelocity);
					}
				}
			}
			else if (IsLivingPlayer(RPP_CurrentVictim[paraIdx]) && IsValidEntity(effect))
			{
				GetEntPropVector(RPP_CurrentVictim[paraIdx], Prop_Data, "m_vecOrigin", RPP_VictimLastValidOrigin[paraIdx]);
				RPP_VictimLastValidOrigin[paraIdx][2] += RP_Z_OFFSET;
			}
			
			// damage
			if (curTime >= RPP_NextDamageAt[paraIdx])
			{
				bool shouldPerformToxic = false;
				bool shouldPerformStandard = false;
				
				// first see if we should do toxic. if we do, we won't do standard collision damage
				if ((RP_Flags[owner] & RP_FLAG_TOXIC_UNCONNECTED) != 0 && !IsLivingPlayer(RPP_CurrentVictim[paraIdx]))
					shouldPerformToxic = true;
				else if ((RP_Flags[owner] & RP_FLAG_TOXIC_CONNECTED) != 0 && IsLivingPlayer(RPP_CurrentVictim[paraIdx]))
					shouldPerformToxic = true;
					
				// should we do standard collision damage instead?
				if ((RP_Flags[owner] & RP_FLAG_ATTACH) == 0 && !shouldPerformToxic)
					shouldPerformStandard = true;
					
				// always damage the attached player. we'll make sure not to double damage them later.
				// which bounds do we use as the center point for our toxic damage?
				int damageType = DMG_PREVENT_PHYSICS_FORCE;
				static float toxicBounds[3];
				toxicBounds[0] = paraBounds[0];
				toxicBounds[1] = paraBounds[1];
				toxicBounds[2] = paraBounds[2];
				if (IsLivingPlayer(RPP_CurrentVictim[paraIdx]))
				{
					bool tweakUber = TF2_IsPlayerInCondition(RPP_CurrentVictim[paraIdx], TFCond_Ubercharged) && (RP_Flags[owner] & RP_FLAG_PENETRATE_UBER) != 0;
					if (tweakUber)
						TF2_RemoveCondition(RPP_CurrentVictim[paraIdx], TFCond_Ubercharged);
					SDKHooks_TakeDamage(RPP_CurrentVictim[paraIdx], owner, owner, RP_DamagePerTick[owner], damageType, -1);
					if (tweakUber)
						TF2_AddCondition(RPP_CurrentVictim[paraIdx], TFCond_Ubercharged, -1.0);
						
					if ((RP_Flags[paraIdx] & RP_FLAG_TOXIC_PLAYER_POSITION) != 0)
					{
						toxicBounds[0] = clientBounds[RPP_CurrentVictim[paraIdx]][0];
						toxicBounds[1] = clientBounds[RPP_CurrentVictim[paraIdx]][1];
						toxicBounds[2] = clientBounds[RPP_CurrentVictim[paraIdx]][2];
					}
				}
					
				// now cycle through potential victims and damage them if appropriate
				if (shouldPerformToxic || shouldPerformStandard)
				{
					for (int victim = 1; victim < MAX_PLAYERS; victim++)
					{
						if (victim == RPP_CurrentVictim[paraIdx] || !clientValid[victim])
							continue;

						bool hit = false;

						if (shouldPerformToxic)
						{
							hit = GetVectorDistance(toxicBounds, clientBounds[victim], true) <= (RP_ToxicRadius[owner] * RP_ToxicRadius[owner]);
						}
						else if (shouldPerformStandard)
						{
							if (RP_Flags[owner] & RP_FLAG_CYLINDER_COLLISION)
								hit = CylinderCollision(paraBounds, clientBounds[victim], fabs(RP_CollisionHull[owner][0][0]), (paraBounds[2] + RP_CollisionHull[owner][0][2]) - 83.0, paraBounds[2] + RP_CollisionHull[owner][1][2]);
							else
								hit = WithinBounds(clientBounds[victim], paraMin, paraMax);
						}
						
						if (hit)
						{
							bool tweakUber = TF2_IsPlayerInCondition(victim, TFCond_Ubercharged) && (RP_Flags[owner] & RP_FLAG_PENETRATE_UBER) != 0;
							if (tweakUber)
								TF2_RemoveCondition(victim, TFCond_Ubercharged);
							SDKHooks_TakeDamage(victim, owner, owner, RP_DamagePerTick[owner], damageType, -1);
							if (tweakUber)
								TF2_AddCondition(victim, TFCond_Ubercharged, -1.0);
						}
					}
				}
			
				RPP_NextDamageAt[paraIdx] += RP_TickInterval[owner];
			}
		}
		
		if (curTime - RPP_LastTickTime > 0.001)
			RPP_LastTickTime = curTime;
	}
	
	if (WA_ActiveThisRound)
	{
		WA_Tick(curTime);
	}
}
 
public Action OnPlayerRunCmd(int clientIdx, int &buttons, int &impulse, 
							float vel[3], float angles[3], int &weapon, 
							int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!RoundInProgress || !IsLivingPlayer(clientIdx))
		return Plugin_Continue;
		
	if (WA_ActiveThisRound)
	{
		if (GetClientTeam(clientIdx) != BossTeam)
			WA_OnPlayerRunCmd(clientIdx, buttons);
		else if (!WA_AllEngiesDead)
		{
			if ((buttons & IN_DUCK) != 0 && !WA_CrouchDown[clientIdx])
			{
				EmitSoundToClient(clientIdx, WA_CROUCH_JEER_SOUND);
				PrintCenterText(clientIdx, "Don't crouch! It causes earthquakes.\nTo fix, very rapidly double crouch.\nOr spam crouches on the ocean floor.\nIt may take a few tries to work.");
			}
			else if (WA_CrouchDown[clientIdx] && (buttons & IN_DUCK) == 0)
			{
				WA_NoWaterUntil[clientIdx] = GetEngineTime() + 0.05;
				SetEntProp(clientIdx, Prop_Send, "m_nWaterLevel", 0);
			}
			
			WA_CrouchDown[clientIdx] = (buttons & IN_DUCK) != 0;
		}
	}
		
	if (UC_ActiveThisRound && UC_CanUse[clientIdx])
		UC_Tick(clientIdx, GetEngineTime(), buttons);
		
	if (US_ActiveThisRound && US_CanUse[clientIdx])
	{
		if (US_TicksForMaxHP[clientIdx] > 0 && IsLivingPlayer(clientIdx))
		{
			US_TicksForMaxHP[clientIdx]--;
			US_MaxHP[clientIdx] = max(US_MaxHP[clientIdx], GetEntProp(clientIdx, Prop_Data, "m_iHealth"));
		}
	}

	return Plugin_Continue;
}

/**
 * Zatoichi Workaround
 */
public Action OnTakeDamageZatoichi(int victim, int& attacker, int& inflictor, 
								float& damage, int& damagetype, int& weapon, 
								float damageForce[3], float damagePosition[3], int damagecustom)
{
	// this assumes you've only assigned this SDKHook to the boss
	if (damagecustom == TF_CUSTOM_DECAPITATION && IsValidEntity(weapon))
	{
		char classname[48];
		GetEntityClassname(weapon, classname, sizeof(classname));
		if (!strcmp(classname, "tf_weapon_katana") && damage > ZW_StandardBaseDamage)
		{
			damage = ZW_StandardBaseDamage;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

/**
 * General helper stocks, some original, some taken/modified from other sources
 */

stock int ParticleEffectAt(float position[3], char[] effectName, float duration = 0.1)
{
	if (strlen(effectName) < 3)
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
			CreateTimer(duration, Timer_RemoveEntity, EntIndexToEntRef(particle));
	}
	return particle;
}

stock int AttachParticle(int entity, const char[] particleType, float offset=0.0, bool attach=true)
{
	int particle = CreateEntityByName("info_particle_system");
	
	if (!IsValidEntity(particle))
		return -1;

	static char targetName[128];
	float position[3];
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
stock int AttachParticleToAttachment(int entity, const char[] particleType, const char[] attachmentPoint)
{
	int particle = CreateEntityByName("info_particle_system");
	
	if (!IsValidEntity(particle))
		return -1;

	static char targetName[128];
	float position[3];
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

	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
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
		PrintToServer("[sarysapub1] Error: Invalid weapon spawned. client=%d name=%s idx=%d attr=%s", client, name, index, attribute);
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

stock void ParseHull(char hullStr[MAX_HULL_STRING_LENGTH], float hull[2][3])
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
			PrintToServer("[sarysapub2] Hit player %d on trace.", entity);
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

stock float fabs(float x)
{
	return x < 0 ? -x : x;
}

stock int min(int n1, int n2)
{
	return n1 < n2 ? n1 : n2;
}

stock int max(int n1, int n2)
{
	return n1 > n2 ? n1 : n2;
}

stock bool WithinBounds(float point[3], float min[3], float max[3])
{
	return point[0] >= min[0] && point[0] <= max[0] &&
		point[1] >= min[1] && point[1] <= max[1] &&
		point[2] >= min[2] && point[2] <= max[2];
}

stock int ReadHexOrDecInt(char hexOrDecString[HEX_OR_DEC_STRING_LENGTH])
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

stock void constrainDistance(const float[] startPoint, float[] endPoint, float distance, float maxDistance)
{
	if (distance <= maxDistance)
		return; // nothing to do
		
	float constrainFactor = maxDistance / distance;
	endPoint[0] = ((endPoint[0] - startPoint[0]) * constrainFactor) + startPoint[0];
	endPoint[1] = ((endPoint[1] - startPoint[1]) * constrainFactor) + startPoint[1];
	endPoint[2] = ((endPoint[2] - startPoint[2]) * constrainFactor) + startPoint[2];
}

// this version ignores obstacles
stock void PseudoAmbientSound(int clientIdx, char[] soundPath, int count=1, float radius=1000.0, bool skipSelf=false, bool skipDead=false, float volumeFactor=1.0)
{
	float emitterPos[3];
	float listenerPos[3];
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
			PrintToServer("[sarysamods6] How the hell is volume greater than 1.0?");
			volume = 1.0;
		}
		
		for (int i = 0; i < count; i++)
			EmitSoundToClient(listener, soundPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume);
	}
}

stock void Nope(int clientIdx)
{
	EmitSoundToClient(clientIdx, NOPE_AVI);
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
