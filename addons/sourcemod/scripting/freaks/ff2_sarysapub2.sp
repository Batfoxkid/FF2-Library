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

#pragma semicolon 1

#include <sourcemod>
#include <tf2items>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_functions>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <morecolors>
#undef REQUIRE_PLUGIN
#include <goomba>
#define REQUIRE_PLUGIN

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
 
new bool:DEBUG_FORCE_RAGE = false;
#define ARG_LENGTH 256
 
new bool:PRINT_DEBUG_INFO = true;
new bool:PRINT_DEBUG_SPAM = false;

new Float:OFF_THE_MAP[3] = { 16383.0, 16383.0, -16383.0 };
#define FAR_FUTURE 100000000.0
#define COND_JARATE_WATER 86
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

new MercTeam = _:TFTeam_Red;
new BossTeam = _:TFTeam_Blue;

new RoundInProgress = false;

public Plugin:myinfo = {
	name = "Freak Fortress 2: sarysa's public mods, second pack",
	author = "sarysa",
	version = "1.0.2",
}

// parasite
#define RP_STRING "rage_parasite"
#define RP_Z_OFFSET 40.0 // the standard z offset relative to player origin
new RP_ActiveThisRound = false;
new RP_DamageHooksNeeded = false;
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
new String:RP_EffectName[MAX_PLAYERS_ARRAY][MAX_EFFECT_NAME_LENGTH]; // arg2, which sadly needs to be stored due to particle effects not being very malleable
// arg3 only needed at spawn time
new String:RP_AttachmentPoint[MAX_PLAYERS_ARRAY][MAX_ATTACHMENT_NAME_LENGTH]; // arg4
new Float:RP_ParasiteZOffset[MAX_PLAYERS_ARRAY]; // arg5
new Float:RP_CollisionHull[MAX_PLAYERS_ARRAY][2][3]; // arg6
new Float:RP_DamagePerTick[MAX_PLAYERS_ARRAY]; // arg7
new Float:RP_TickInterval[MAX_PLAYERS_ARRAY]; // arg8
new Float:RP_StickDuration[MAX_PLAYERS_ARRAY]; // arg9
// arg9 only needed at spawn time
new Float:RP_ImmunityDuration[MAX_PLAYERS_ARRAY]; // arg11
// arg11 only needed at spawn time
new Float:RP_ToxicRadius[MAX_PLAYERS_ARRAY]; // arg13
new RP_Flags[MAX_PLAYERS_ARRAY]; // arg19

// the individual parasites
#define MAX_PARASITES 50
new RPP_Owner[MAX_PARASITES]; // not using user ID since living player is verified every frame.
new RPP_ModelEntRef[MAX_PARASITES];
new RPP_ParticleEntRef[MAX_PARASITES];
new RPP_CurrentVictim[MAX_PARASITES];
new Float:RPP_DetachFromVictimAt[MAX_PARASITES];
new Float:RPP_DieNaturallyAt[MAX_PARASITES];
new RPP_ImmuneVictim[MAX_PARASITES]; // yes, in edge cases where users rapidly go in and out of parasite (i.e. uber) the user can be victim more often
new Float:RPP_ImmunityEndsAt[MAX_PARASITES]; // than they should, but it's just not worth the data size requirements for such a minor issue
new Float:RPP_ActivateAt[MAX_PARASITES];
new Float:RPP_NextDamageAt[MAX_PARASITES];
new Float:RPP_SelfYawAtAttachTime[MAX_PARASITES];
new Float:RPP_VictimYawAtAttachTime[MAX_PARASITES];
new Float:RPP_VictimLastValidOrigin[MAX_PARASITES][3];
new Float:RPP_LastTickTime = 0.0; // they all use a cached time variable, not GetEngineTime(), so they're all the same

// zatoichi workaround
#define ZW_STRING "ff2_zatoichi_workaround"
new bool:ZW_IsUsing[MAX_PLAYERS_ARRAY];
new Float:ZW_StandardBaseDamage = 65.0;

/**
 * Water Arena
 */
#define WA_STRING "ff2_water_arena"
#define WA_MAX_HP_DRAIN_WEAPONS 10
#define WA_MAX_ROCKET_MINICRIT_BLACKLIST 30
new bool:WA_ActiveThisRound;
new Float:WA_FixOverlayAt; // internal
new Float:WA_PlayWaterSoundAt[MAX_PLAYERS_ARRAY]; // internal
new Float:WA_RestoreWaterAt[MAX_PLAYERS_ARRAY]; // internal
new bool:WA_AltFireDown[MAX_PLAYERS_ARRAY]; // internal
new bool:WA_FireDown[MAX_PLAYERS_ARRAY]; // internal
new bool:WA_CrouchDown[MAX_PLAYERS_ARRAY]; // internal
new bool:WA_UsingSpellbookLameWater[MAX_PLAYERS_ARRAY]; // internal
new bool:WA_IsThirdPerson[MAX_PLAYERS_ARRAY]; // internal, reflects their setting on the other mod
new bool:WA_OverlayOptOut[MAX_PLAYERS_ARRAY]; // internal, setting for water overlay
new bool:WA_OverlaySupported[MAX_PLAYERS_ARRAY]; // internal, determined by dx80 check
new WA_OOOUserId[MAX_PLAYERS_ARRAY]; // internal, check this every round start that matters
// sandvich and dalokah's handling
#define WA_HEAVY_CONSUMPTION_TIME 4.3
#define WA_HEAVY_EATING_SOUND "vo/sandwicheat09.wav"
new bool:WA_IsEatingHeavyFood[MAX_PLAYERS_ARRAY]; // internal
new bool:WA_IsDalokohs[MAX_PLAYERS_ARRAY]; // internal
new WA_HeavyFoodHPPerTick[MAX_PLAYERS_ARRAY]; // internal
new WA_HeavyFoodTickCount[MAX_PLAYERS_ARRAY]; // internal
new Float:WA_HeavyFoodStartedAt[MAX_PLAYERS_ARRAY]; // internal
// bonk and crit-a-cola handling
#define WA_SCOUT_DRINKING_SOUND "player/pl_scout_dodge_can_drink.wav"
new bool:WA_IsDrinking[MAX_PLAYERS_ARRAY]; // internal
new bool:WA_IsBonk[MAX_PLAYERS_ARRAY]; // internal
new Float:WA_DrinkingUntil[MAX_PLAYERS_ARRAY]; // internal
new Float:WA_EffectLastsUntil[MAX_PLAYERS_ARRAY]; // internal
// consumable handling
new Float:WA_ConsumableCooldownUntil[MAX_PLAYERS_ARRAY];
// sandman handling
#define WA_SANDMAN_LAMEWATER_DURATION 0.5 // note, it has to be artificially long because sometimes firstperson fails otherwise
new Float:WA_RemoveLameWaterAt[MAX_PLAYERS_ARRAY];
// fix for bug where condition 86 is lost when a player almost lags out
#define WA_WATER_RESTORE_INTERVAL 0.05
new Float:WA_MassRestoreWaterAt;
// the crouch problem
#define WA_CROUCH_JEER_SOUND "vo/scout_jeers06.wav"
new Float:WA_NoWaterUntil[MAX_PLAYERS_ARRAY];
// 2014-12-23, sometimes the perspective doesn't fix itself
#define FIX_PERSPECTIVE_COUNT 3
new Float:WA_FixPerspectiveAt[MAX_PLAYERS_ARRAY][FIX_PERSPECTIVE_COUNT];
// 2014-12-23, swap the hale to good water when all engies are dead, since lame water is troubled
new bool:WA_AllEngiesDead;
// server operator args
new Float:WA_PyroSecondaryBoost; // arg1
new Float:WA_PyroMeleeBoost; // arg2
new Float:WA_FixInterval; // arg3
new String:WA_UnderwaterSound[MAX_SOUND_FILE_LENGTH]; // arg4
new Float:WA_SoundLoopInterval; // arg5
new Float:WA_Damage; // arg6
new Float:WA_Velocity; // arg7
new bool:WA_AllowSandman; // arg8
new String:WA_UnderwaterOverlay[MAX_MATERIAL_FILE_LENGTH]; // arg9
new Float:WA_HeavyDalokohsBoost; // arg10
new WA_HeavyDalokohsTick; // arg11
new WA_HeavySandvichTick; // arg12
new String:WA_PyroShotgunArgs[MAX_WEAPON_ARG_LENGTH]; // arg13
new String:WA_SniperRifleArgs[MAX_WEAPON_ARG_LENGTH]; // arg14
new WA_HeavyHPDrainWeapons[WA_MAX_HP_DRAIN_WEAPONS]; // arg15
new bool:WA_DontShowNoOverlayInstructions; // arg16
new bool:WA_DontSwitchToGoodWater; // arg17
new bool:WA_RocketMinicritDisabled; // arg18 (related)
new WA_SoldierNoMinicritWeapons[WA_MAX_ROCKET_MINICRIT_BLACKLIST]; // arg18

/**
 * Underwater Charge
 */
#define UC_STRING "ff2_underwater_charge"
#define UC_TYPE_RESTRICTED 0
#define UC_TYPE_FREE 1
#define UC_HUD_POSITION 0.87
#define UC_HUD_REFRESH_INTERVAL 0.1
new bool:UC_ActiveThisRound;
new bool:UC_CanUse[MAX_PLAYERS_ARRAY]; // internal
new Float:UC_LockedAngle[MAX_PLAYERS_ARRAY][3]; // internal, if arg1 is 0
new Float:UC_RefreshChargeAt[MAX_PLAYERS_ARRAY]; // internal, related to arg3
new Float:UC_EndChargeAt[MAX_PLAYERS_ARRAY]; // internal, related to arg5
new Float:UC_UsableAt[MAX_PLAYERS_ARRAY]; // internal, related to arg6
new bool:UC_KeyDown[MAX_PLAYERS_ARRAY]; // internal, related to arg9
new Float:UC_NextHUDAt[MAX_PLAYERS_ARRAY]; // internal
new UC_ChargeType[MAX_PLAYERS_ARRAY]; // arg1
new Float:UC_VelDampening[MAX_PLAYERS_ARRAY]; // arg2
new Float:UC_ChargeVel[MAX_PLAYERS_ARRAY]; // arg3
new Float:UC_ChargeRefreshInterval[MAX_PLAYERS_ARRAY]; // arg4
new Float:UC_Duration[MAX_PLAYERS_ARRAY]; // arg5
new Float:UC_Cooldown[MAX_PLAYERS_ARRAY]; // arg6
new String:UC_Sound[MAX_SOUND_FILE_LENGTH]; // arg7
new Float:UC_RageCost[MAX_PLAYERS_ARRAY]; // arg8
new bool:UC_AltFireActivated[MAX_PLAYERS_ARRAY]; // arg9
new String:UC_CooldownStr[MAX_CENTER_TEXT_LENGTH]; // arg16
new String:UC_InstructionStr[MAX_CENTER_TEXT_LENGTH]; // arg17
new String:UC_NotEnoughRageStr[MAX_CENTER_TEXT_LENGTH]; // arg18

/**
 * Underwater Speed
 */
#define US_STRING "ff2_underwater_speed"
new bool:US_ActiveThisRound;
new bool:US_CanUse[MAX_PLAYERS_ARRAY];
new US_TicksForMaxHP[MAX_PLAYERS_ARRAY]; // internal, if this is greater than 0, max hp is unknown
new US_MaxHP[MAX_PLAYERS_ARRAY]; // internal
new Float:US_StartSpeed[MAX_PLAYERS_ARRAY]; // arg1
new Float:US_EndSpeed[MAX_PLAYERS_ARRAY]; // arg2

/**
 * METHODS REQUIRED BY ff2 subplugin
 */
PrintRageWarning()
{
	PrintToServer("*********************************************************************");
	PrintToServer("*                             WARNING                               *");
	PrintToServer("*       DEBUG_FORCE_RAGE in ff2_sarysapub2.sp is set to true!       *");
	PrintToServer("*  Any admin can use the 'rage' command to use rages in this pack!  *");
	PrintToServer("*  This is only for test servers. Disable this on your live server. *");
	PrintToServer("*********************************************************************");
}
 
#define CMD_FORCE_RAGE "rage"
public OnPluginStart2()
{
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	
	if (DEBUG_FORCE_RAGE)
	{
		PrintRageWarning();
		RegAdminCmd(CMD_FORCE_RAGE, CmdForceRage, ADMFLAG_GENERIC);
	}
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
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
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
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
		for (new i = 0; i < FIX_PERSPECTIVE_COUNT; i++)
			WA_FixPerspectiveAt[clientIdx][i] = FAR_FUTURE;
		UC_CanUse[clientIdx] = false;
		US_CanUse[clientIdx] = false;
	
		// boss-only inits
		new bossIdx = FF2_GetBossIndex(clientIdx);
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
			new String:modelName[MAX_MODEL_NAME_LENGTH];
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
			new String:heavyHPDrainWeapons[WA_MAX_HP_DRAIN_WEAPONS * 6];
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, WA_STRING, 15, heavyHPDrainWeapons, WA_MAX_HP_DRAIN_WEAPONS * 6);
			new String:hhdwStrings[WA_MAX_HP_DRAIN_WEAPONS][6];
			ExplodeString(heavyHPDrainWeapons, ",", hhdwStrings, WA_MAX_HP_DRAIN_WEAPONS, 6);
			for (new i = 0; i < WA_MAX_HP_DRAIN_WEAPONS; i++)
				WA_HeavyHPDrainWeapons[i] = StringToInt(hhdwStrings[i]);
				
			// arg 16 and 17
			WA_DontShowNoOverlayInstructions = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, WA_STRING, 16) == 1);
			WA_DontSwitchToGoodWater = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, WA_STRING, 17) == 1);
			
			// rocket minicrit blacklist
			new String:rocketMinicritBlacklist[WA_MAX_ROCKET_MINICRIT_BLACKLIST * 6];
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, WA_STRING, 18, rocketMinicritBlacklist, WA_MAX_ROCKET_MINICRIT_BLACKLIST * 6);
			WA_RocketMinicritDisabled = !strcmp(rocketMinicritBlacklist, "*");
			if (!WA_RocketMinicritDisabled)
			{
				new String:rmdStrings[WA_MAX_ROCKET_MINICRIT_BLACKLIST][6];
				ExplodeString(rocketMinicritBlacklist, ",", rmdStrings, WA_MAX_ROCKET_MINICRIT_BLACKLIST, 6);
				for (new i = 0; i < WA_MAX_ROCKET_MINICRIT_BLACKLIST; i++)
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
		for (new i = 0; i < MAX_PARASITES; i++)
		{
			RPP_Owner[i] = -1;
		}
		
		if (RP_DamageHooksNeeded)
		{
			for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
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
		for (new clientIdx = 0; clientIdx < MAX_PLAYERS; clientIdx++)
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
		new triggerPush = -1;
		while ((triggerPush = FindEntityByClassname(triggerPush, "trigger_push")) != -1)
			AcceptEntityInput(triggerPush, "kill");
	}
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	RoundInProgress = false;
	
	// parasites
	if (RP_ActiveThisRound)
	{
		RP_ActiveThisRound = false;
		if (RP_DamageHooksNeeded)
		{
			RP_DamageHooksNeeded = false;
			for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
			{
				if (IsClientInGame(clientIdx))
					SDKUnhook(clientIdx, SDKHook_OnTakeDamage, RP_OnTakeDamage);
			}
		}

	}
	
	// zatoichi workaround
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
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

public Action:FF2_OnAbility2(bossIdx, const String:plugin_name[], const String:ability_name[], status)
{
	if (strcmp(plugin_name, this_plugin_name) != 0)
		return Plugin_Continue;
	else if (!RoundInProgress) // don't execute these rages with 0 players alive
		return Plugin_Continue;

	if (!strcmp(ability_name, RP_STRING))
		Rage_Parasite(ability_name, bossIdx);
		
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
	
	if (!strcmp("parasite", unparsedArgs))
	{
		PrintToConsole(user, "Parasite rage.");
		Rage_Parasite(RP_STRING, 0);
		return Plugin_Handled;
	}
	
	PrintToServer("[sarysapub2] Rage not found: %s", unparsedArgs);
	return Plugin_Continue;
}

/**
 * Parasite
 */
#define SPAWN_TYPE_ON_HALE 0
#define SPAWN_TYPE_RAY_TRACE 1
#define SPAWN_TYPE_NEAREST_ENEMY 2
#define SPAWN_TYPE_RANDOM_ENEMY 3
public Rage_Parasite(const String:ability_name[], bossIdx)
{
	new clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	// variables only needed at spawn time
	new String:modelName[MAX_MODEL_NAME_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, 1, modelName, MAX_MODEL_NAME_LENGTH);
	new spawnType = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 3);
	new Float:timeToLive = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 10);
	new Float:delayToStart = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 12);
	
	// figure out where to spawn the entity
	new Float:bossOrigin[3];
	GetEntPropVector(clientIdx, Prop_Data, "m_vecOrigin", bossOrigin);
	new Float:victimOrigin[3];
	new Float:spawnPoint[3];
	if (spawnType == SPAWN_TYPE_RAY_TRACE)
	{
		new Float:eyeAngles[3];
		new Float:eyePosition[3];
		GetClientEyeAngles(clientIdx, eyeAngles);
		GetClientEyePosition(clientIdx, eyePosition);
		
		new Handle:trace;
		if ((RP_Flags[clientIdx] & RP_FLAG_PLAYERS_ON_RAY_TRACE) != 0)
			trace = TR_TraceRayFilterEx(eyePosition, eyeAngles, MASK_ALL, RayType_Infinite, TraceRedPlayers);
		else
			trace = TR_TraceRayFilterEx(eyePosition, eyeAngles, MASK_ALL, RayType_Infinite, TraceWallsOnly);
		new bool:playerHit = TR_GetHitGroup(trace) > 0; // group 0 is "generic" which I hope includes nothing. 1=head 2=chest 3=stomach 4=leftarm 5=rightarm 6=leftleg 7=rightleg (shareddefs.h)
		TR_GetEndPosition(spawnPoint, trace);
		CloseHandle(trace);
		
		// if we hit a wall, shorten the distance by about 25 so our object doesn't spawn half in a wall
		if (!playerHit)
		{
			new Float:distance = GetVectorDistance(spawnPoint, eyePosition);
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
		new randomLivingPlayer = -1;
		for (new i = 0; i < 50; i++)
		{
			new testPlayer = GetRandomInt(1, MAX_PLAYERS);
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
		new Float:shortestDistance = 99999.0 * 99999.0;
		new nearestVictim = clientIdx; // default to boss on failure
		for (new i = 1; i < MAX_PLAYERS; i++)
		{
			if (IsLivingPlayer(i) && GetClientTeam(i) != BossTeam)
			{
				GetEntPropVector(i, Prop_Data, "m_vecOrigin", victimOrigin);
				new Float:distance = GetVectorDistance(victimOrigin, bossOrigin, true);
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
	new prop = -1;
	if (strlen(modelName) > 3)
		prop = CreateEntityByName("prop_physics_override");
	if (IsValidEntity(prop))
	{
		SetEntProp(prop, Prop_Data, "m_takedamage", 0);
		
		// give it a random yaw
		new Float:angles[3];
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
	new effect = -1;
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
	new paraIdx = RPP_FindFreeIndex();
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

public RPP_RemoveParasiteAt(paraIdx)
{
	// clean this up
	RemoveEntity(INVALID_HANDLE, RPP_ParticleEntRef[paraIdx]); // particle goes first since it may be a child of the model
	RemoveEntity(INVALID_HANDLE, RPP_ModelEntRef[paraIdx]);

	// push everything down one
	for (new i = paraIdx; i < MAX_PARASITES - 1; i++)
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

public RPP_FindFreeIndex()
{
	for (new i = 0; i < MAX_PARASITES; i++)
	{
		if (RPP_Owner[i] == -1)
			return i;
	}
	
	// we're full, remove the first parasite and assign the last
	RPP_RemoveParasiteAt(0);
	return MAX_PARASITES - 1;
}

public RPP_DetachFromHost(paraIdx)
{
	new prop = EntRefToEntIndex(RPP_ModelEntRef[paraIdx]);
	new effect = EntRefToEntIndex(RPP_ParticleEntRef[paraIdx]);
	if (IsValidEntity(prop))
	{
		SetEntityMoveType(prop, MOVETYPE_NONE);
		
		if (IsLivingPlayer(RPP_CurrentVictim[paraIdx]))
		{
			static Float:victimOrigin[3];
			GetEntPropVector(RPP_CurrentVictim[paraIdx], Prop_Data, "m_vecOrigin", victimOrigin);
			victimOrigin[2] += RP_ParasiteZOffset[RPP_Owner[paraIdx]];
			SetEntPropVector(prop, Prop_Data, "m_vecOrigin", victimOrigin);
		}
	}
	else if (IsValidEntity(effect)) // else if because if both exist, effect is always attached to prop
	{
		// trying to detach is a bit troublesome
		// so just spawn a new one in its place
		//static Float:spawnPoint[3];
		//GetEntPropVector(effect, Prop_Data, "m_vecOrigin", spawnPoint); // for some reason this is returning crap.
		RemoveEntity(INVALID_HANDLE, RPP_ParticleEntRef[paraIdx]);
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

public Action:RP_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
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
	if (victim == attacker && (damagetype & DMG_FALL) == 0)
	{
		// don't include damage over time from GRU or other health drain attributes
		if (!(damagetype == 0 && damagecustom == 0))
		{
			// see if this player has parasites attached, remove them all if so
			for (new i = MAX_PARASITES - 1; i >= 0; i--)
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
public WA_DX80Result(QueryCookie:cookie, clientIdx, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
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
 
public Action:WA_PerformDX80Check()
{
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		WA_OverlaySupported[clientIdx] = false;
		if (IsClientInGame(clientIdx))
		{
			WA_OverlaySupported[clientIdx] = true;
			QueryClientConVar(clientIdx, "mat_dxlevel", WA_DX80Result);
		}
	}
}
 
public Action:WA_NoOverlay(clientIdx, argsInt)
{
	WA_OverlayOptOut[clientIdx] = true;
	WA_OOOUserId[clientIdx] = GetClientUserId(clientIdx);
	if (WA_ActiveThisRound)
		WA_FixOverlay(clientIdx, true);

	PrintCenterText(clientIdx, "You have chosen not to show the water overlay.\nThis setting will remain until map change or you log out.\nType !yesoverlay to restore water overlay.");
	return Plugin_Handled;
}

public Action:WA_YesOverlay(clientIdx, argsInt)
{
	WA_OverlayOptOut[clientIdx] = false;
	if (WA_ActiveThisRound)
		WA_FixOverlay(clientIdx, false);
		
	PrintCenterText(clientIdx, "You have chosen to show the water overlay.\nType !nooverlay if you have problems with it.");
	return Plugin_Handled;
}
 
public WA_SetToFirstPerson(clientIdx)
{
	new flags = GetCommandFlags("firstperson");
	SetCommandFlags("firstperson", flags & ~FCVAR_CHEAT);
	ClientCommand(clientIdx, "firstperson");
	SetCommandFlags("firstperson", flags);
}

public WA_SetToThirdPerson(clientIdx)
{
	new flags = GetCommandFlags("thirdperson");
	SetCommandFlags("thirdperson", flags & ~FCVAR_CHEAT);
	ClientCommand(clientIdx, "thirdperson");
	SetCommandFlags("thirdperson", flags);
}
 
public Action:WA_OnCmdThirdPerson(clientIdx, const String:command[], argc)
{
	if (!WA_ActiveThisRound)
		return Plugin_Continue; // just in case
		
	WA_IsThirdPerson[clientIdx] = true;
	if (IsLivingPlayer(clientIdx) && TF2_IsPlayerInCondition(clientIdx, TFCond:COND_JARATE_WATER))
		WA_SetToThirdPerson(clientIdx);
		
	return Plugin_Continue;
}

public Action:WA_OnCmdFirstPerson(clientIdx, const String:command[], argc)
{
	if (!WA_ActiveThisRound)
		return Plugin_Continue; // just in case
		
	WA_IsThirdPerson[clientIdx] = false;
	if (IsLivingPlayer(clientIdx) && TF2_IsPlayerInCondition(clientIdx, TFCond:COND_JARATE_WATER))
		WA_SetToFirstPerson(clientIdx);
		
	return Plugin_Continue;
}

public Action:OnStomp(attacker, victim, &Float:damageMultiplier, &Float:damageBonus, &Float:JumpPower)
{
	// disable goombas entirely in a water arena
	if (WA_ActiveThisRound)
		return Plugin_Handled;
		
	return Plugin_Continue;
}

// only do this once. people shouldn't be latespawning at all, after all...
public WA_ReplaceBrokenWeapons()
{
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!IsLivingPlayer(clientIdx))
			continue;
	
		new TFClassType:playerClass = TF2_GetPlayerClass(clientIdx);
		if (playerClass == TFClass_Pyro)
		{
			// only allow shotgun secondary. replace all others with stock shotgun.
			new secondary = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Secondary);
			if (!IsValidEntity(secondary))
				continue;
				
			new String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
			GetEntityClassname(secondary, classname, MAX_ENTITY_CLASSNAME_LENGTH);
			if (StrContains(classname, "tf_weapon_shotgun") == -1) // this should be 95% future-proof.
			{
				TF2_RemoveWeaponSlot(clientIdx, TFWeaponSlot_Secondary);
				new weapon = SpawnWeapon(clientIdx, "tf_weapon_shotgun_pyro", 12, 1, 0, WA_PyroShotgunArgs);
				if (IsValidEntity(weapon))
				{
					new offset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1);
					SetEntProp(clientIdx, Prop_Send, "m_iAmmo", 32, 4, offset);
				}
				PrintToChat(clientIdx, "Your Pyro secondary doesn't work in water. Replaced with a shotgun.");
			}
		}
		else if (playerClass == TFClass_Sniper)
		{
			// only allow shotgun secondary. replace all others with stock shotgun.
			new primary = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary);
			if (!IsValidEntity(primary))
				continue;
				
			new String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
			GetEntityClassname(primary, classname, MAX_ENTITY_CLASSNAME_LENGTH);
			if (!strcmp(classname, "tf_weapon_compound_bow")) // this should be 95% future-proof.
			{
				TF2_RemoveWeaponSlot(clientIdx, TFWeaponSlot_Primary);
				new weapon = SpawnWeapon(clientIdx, "tf_weapon_sniperrifle", 14, 1, 0, WA_SniperRifleArgs);
				if (IsValidEntity(weapon))
				{
					SetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon", weapon);
					new offset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1);
					SetEntProp(clientIdx, Prop_Send, "m_iAmmo", 25, 4, offset);
				}
				PrintToChat(clientIdx, "Your bow doesn't work in water. Replaced with a sniper rifle.");
			}
		}
		else if (playerClass == TFClass_Heavy)
		{
			// dalokohs or fishcake secondary
			new secondary = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Secondary);
			if (!IsValidEntity(secondary))
				continue;
				
			new weaponIdx = GetEntProp(secondary, Prop_Send, "m_iItemDefinitionIndex");
			if (weaponIdx == 159 || weaponIdx == 433)
			{
				TF2_RemoveWeaponSlot(clientIdx, TFWeaponSlot_Secondary);
				new String:attr[20];
				Format(attr, sizeof(attr), "26 ; %f", WA_HeavyDalokohsBoost);
				SpawnWeapon(clientIdx, "tf_weapon_lunchbox", weaponIdx, 1, 0, attr);
				PrintToChat(clientIdx, "Your Dalokohs has given you a permanent HP boost this round.");
			}
		}
	}
}

public bool:WA_ShouldHaveLameWater(clientIdx)
{
	return IsLivingPlayer(clientIdx) && ((GetClientTeam(clientIdx) == BossTeam && !WA_AllEngiesDead) || WA_UsingSpellbookLameWater[clientIdx] || WA_RemoveLameWaterAt[clientIdx] != FAR_FUTURE);
}

public WA_PreThink(clientIdx) // credit to phatrages. knew about this prop but I would never have thought I needed to do this in a think.
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
			new Float:healthFactor = 1.0 - (float(GetEntProp(clientIdx, Prop_Data, "m_iHealth")) / float(US_MaxHP[clientIdx]));
			new Float:moveSpeed = US_StartSpeed[clientIdx] + ((US_EndSpeed[clientIdx] - US_StartSpeed[clientIdx]) * healthFactor);
			if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed))
				moveSpeed *= 0.5;
			SetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed", moveSpeed);
		}
	}
}

public WA_FixOverlay(clientIdx, bool:remove)
{
	new flags = GetCommandFlags("r_screenoverlay");
	SetCommandFlags("r_screenoverlay", flags & ~FCVAR_CHEAT);
	if (remove || WA_OverlayOptOut[clientIdx] || !WA_OverlaySupported[clientIdx])
		ClientCommand(clientIdx, "r_screenoverlay \"\"");
	else
		ClientCommand(clientIdx, "r_screenoverlay \"%s\"", WA_UnderwaterOverlay);
	SetCommandFlags("r_screenoverlay", flags);
}

public WA_GoodWater(clientIdx)
{
	TF2_AddCondition(clientIdx, TFCond:COND_JARATE_WATER, -1.0);
	
	// fix to first person
	if (GetEntProp(clientIdx, Prop_Send, "m_nForceTauntCam") == 0)
	{
		WA_SetToFirstPerson(clientIdx);
		WA_IsThirdPerson[clientIdx] = false;
		for (new i = 0; i < FIX_PERSPECTIVE_COUNT; i++)
			WA_FixPerspectiveAt[clientIdx][i] = GetEngineTime() + (0.5 * (i+1)); // a backup perspective fix
	}
	else
		WA_IsThirdPerson[clientIdx] = true;
	
	// fix the overlay now
	WA_FixOverlay(clientIdx, false);
	
	// never play underwater sound
	WA_PlayWaterSoundAt[clientIdx] = FAR_FUTURE;
}

public WA_LameWater(clientIdx)
{
	WA_FixOverlay(clientIdx, false);
	WA_PlayWaterSoundAt[clientIdx] = GetEngineTime();
}

public bool:WA_SpellbookActive(clientIdx)
{
	new weapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(weapon))
		return false;
		
	static String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
	GetEntityClassname(weapon, classname, MAX_ENTITY_CLASSNAME_LENGTH);
	if (!strcmp(classname, "tf_weapon_spellbook"))
		return true;
	return false;
}

public Action:WA_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
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
 
public WA_AddHooks()
{
	HookEvent("player_spawn", WA_PlayerSpawn, EventHookMode_Post);
	AddCommandListener(WA_OnCmdThirdPerson, "tp");
	AddCommandListener(WA_OnCmdThirdPerson, "sm_thirdperson");
	AddCommandListener(WA_OnCmdFirstPerson, "fp");
	AddCommandListener(WA_OnCmdFirstPerson, "sm_firstperson");
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
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

public WA_RemoveHooks()
{
	UnhookEvent("player_spawn", WA_PlayerSpawn, EventHookMode_Post);
	RemoveCommandListener(WA_OnCmdThirdPerson, "tp");
	RemoveCommandListener(WA_OnCmdThirdPerson, "sm_thirdperson");
	RemoveCommandListener(WA_OnCmdFirstPerson, "fp");
	RemoveCommandListener(WA_OnCmdFirstPerson, "sm_firstperson");
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
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

			if (TF2_IsPlayerInCondition(clientIdx, TFCond:COND_JARATE_WATER))
				TF2_RemoveCondition(clientIdx, TFCond:COND_JARATE_WATER);
		}
	}
}

public Action:WA_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new clientIdx = GetClientOfUserId(GetEventInt(event, "userid"));

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
public WA_CreateRocket(owner, Float:position[3], Float:angle[3])
{
	// create our rocket. no matter what, it's going to spawn, even if it ends up being out of map
	new Float:speed = WA_Velocity;
	new Float:damage = WA_Damage;
	//PrintToServer("speed=%f    damage=%f", speed, damage);
	new String:classname[MAX_ENTITY_CLASSNAME_LENGTH] = "CTFProjectile_Rocket";
	new String:entname[MAX_ENTITY_CLASSNAME_LENGTH] = "tf_projectile_rocket";
	
	new rocket = CreateEntityByName(entname);
	if (!IsValidEntity(rocket))
	{
		PrintToServer("[sarysamods6] Error: Invalid entity %s. Won't spawn rocket. This is sarysa's fault.", entname);
		return;
	}
	
	// determine spawn position
	static Float:spawnVelocity[3];
	GetAngleVectors(angle, spawnVelocity, NULL_VECTOR, NULL_VECTOR);
	spawnVelocity[0] *= speed;
	spawnVelocity[1] *= speed;
	spawnVelocity[2] *= speed;
	
	// deploy!
	TeleportEntity(rocket, position, angle, spawnVelocity);
	SetEntProp(rocket, Prop_Send, "m_bCritical", false); // no random crits
	SetEntDataFloat(rocket, FindSendPropOffs(classname, "m_iDeflected") + 4, damage, true); // credit to voogru
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

public WA_Tick(Float:curTime)
{
	// fix the water overlay periodically
	if (curTime >= WA_FixOverlayAt)
	{
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
				WA_FixOverlay(clientIdx, false);
		}
		
		WA_FixOverlayAt = curTime + WA_FixInterval;
	}
	
	// fix the water condition periodically
	if (curTime >= WA_MassRestoreWaterAt)
	{
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (!IsLivingPlayer(clientIdx))
				continue;
		
			if (!TF2_IsPlayerInCondition(clientIdx, TFCond:COND_JARATE_WATER) && WA_RestoreWaterAt[clientIdx] == FAR_FUTURE && !WA_ShouldHaveLameWater(clientIdx))
				TF2_AddCondition(clientIdx, TFCond:COND_JARATE_WATER, -1.0);
		}
	
		WA_MassRestoreWaterAt = curTime + WA_WATER_RESTORE_INTERVAL;
	}
	
	// individual intervals for special actions that must be handled
	new bool:engieFound = false;
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
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
			if (WA_AllEngiesDead && !TF2_IsPlayerInCondition(clientIdx, TFCond:COND_JARATE_WATER))
				WA_GoodWater(clientIdx);
			
			if (TF2_IsPlayerInCondition(clientIdx, TFCond_OnFire))
				TF2_RemoveCondition(clientIdx, TFCond_OnFire);
		}
		
		// soldier rocket minicrits
		if (!WA_RocketMinicritDisabled && TF2_GetPlayerClass(clientIdx) == TFClass_Soldier)
		{
			new bool:shouldHaveMinicrits = false;
		
			new weaponIdx = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
			if (weaponIdx != -1 && weaponIdx == GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary))
			{
				new bool:blacklisted = false;
				for (new i = 0; i < WA_MAX_ROCKET_MINICRIT_BLACKLIST; i++)
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
		for (new i = 0; i < FIX_PERSPECTIVE_COUNT; i++)
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
			new expectedTicks = RoundFloat((4.0 * (curTime - WA_HeavyFoodStartedAt[clientIdx])) / WA_HEAVY_CONSUMPTION_TIME);
			if (expectedTicks > 4)
				expectedTicks = 4;
			
			if (expectedTicks > WA_HeavyFoodTickCount[clientIdx])
			{
				WA_HeavyFoodTickCount[clientIdx]++;
				new actualMaxHP = (WA_IsDalokohs[clientIdx] ? RoundFloat(WA_HeavyDalokohsBoost) : 0) + GetEntProp(clientIdx, Prop_Data, "m_iMaxHealth");
				
				if (GetEntProp(clientIdx, Prop_Send, "m_iHealth") < actualMaxHP)
				{
					// sandvich or dalo..?
					new hpThisTick = WA_HeavyFoodHPPerTick[clientIdx];
					new hpToSet = GetEntProp(clientIdx, Prop_Send, "m_iHealth") + hpThisTick;
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
				TF2_RemoveCondition(clientIdx, TFCond:COND_JARATE_WATER);
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
	new fireball = FindEntityByClassname(-1, "tf_projectile_spellfireball");
	if (IsValidEntity(fireball))
	{
		new owner = GetEntPropEnt(fireball, Prop_Send, "m_hOwnerEntity");
		static Float:position[3];
		static Float:angle[3];
		GetEntPropVector(fireball, Prop_Data, "m_angRotation", angle);
		GetEntPropVector(fireball, Prop_Data, "m_vecOrigin", position);
		
		// the only way to tell a meteor fireball from the other kind is to guess based on distance
		new bool:isMeteor = false;
		if (!IsLivingPlayer(owner))
			isMeteor = true; // high probability
		else
		{
			static Float:adjustedOwnerPos[3];
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

public WA_OnPlayerRunCmd(clientIdx, buttons)
{
	if (TF2_GetPlayerClass(clientIdx) == TFClass_Engineer && !WA_UsingSpellbookLameWater[clientIdx])
	{
		new Float:curTime = GetEngineTime();
		new bool:useKeyDown = (buttons & IN_ATTACK2) != 0;
	
		if (useKeyDown && !WA_AltFireDown[clientIdx])
		{
			// make sure they're not using the wrangler. otherwise, they're trying to pick up a building.
			new weapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
			new bool:proceed = false;
			if (!IsValidEntity(weapon))
				proceed = true;
			else
			{
				new weaponIdx = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
				if (weaponIdx != 140 && weaponIdx != 1086) // wrangler and festive wrangler
					proceed = true;
			}
			
			// just in case, though the timing window for this weapon is miniscule
			if (!TF2_IsPlayerInCondition(clientIdx, TFCond:COND_JARATE_WATER))
				proceed = false;
			
			if (proceed)
			{
				TF2_RemoveCondition(clientIdx, TFCond:COND_JARATE_WATER);
				WA_FixOverlay(clientIdx, false);
				SetEntityMoveType(clientIdx, MOVETYPE_NONE);
				WA_RestoreWaterAt[clientIdx] = curTime + 0.01;
			}
		}
		
		WA_AltFireDown[clientIdx] = useKeyDown;
	}
	
	if (WA_AllowSandman && TF2_GetPlayerClass(clientIdx) == TFClass_Scout && !WA_UsingSpellbookLameWater[clientIdx] && WA_RemoveLameWaterAt[clientIdx] == FAR_FUTURE)
	{
		new Float:curTime = GetEngineTime();
		new bool:useKeyDown = (buttons & IN_ATTACK2) != 0;
	
		if (useKeyDown && !WA_AltFireDown[clientIdx])
		{
			// make sure they're not using the wrangler. otherwise, they're trying to pick up a building.
			new weapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
			new bool:proceed = false;
			if (IsValidEntity(weapon))
			{
				static String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
				GetEntityClassname(weapon, classname, MAX_ENTITY_CLASSNAME_LENGTH);
				if (!strcmp(classname, "tf_weapon_bat_wood"))
					proceed = true;
				else if (!strcmp(classname, "tf_weapon_bat_giftwrap"))
					proceed = true;
			}
			
			// just in case, though the timing window for this weapon is miniscule
			if (!TF2_IsPlayerInCondition(clientIdx, TFCond:COND_JARATE_WATER))
				proceed = false;
			
			if (proceed)
			{
				TF2_RemoveCondition(clientIdx, TFCond:COND_JARATE_WATER);
				WA_LameWater(clientIdx);
				WA_RemoveLameWaterAt[clientIdx] = curTime + WA_SANDMAN_LAMEWATER_DURATION;
			}
		}
		
		WA_AltFireDown[clientIdx] = useKeyDown;
	}
	
	if ((TF2_GetPlayerClass(clientIdx) == TFClass_Heavy || TF2_GetPlayerClass(clientIdx) == TFClass_Scout) && !WA_UsingSpellbookLameWater[clientIdx])
	{
		new Float:curTime = GetEngineTime();
		new bool:useKeyDown = (buttons & IN_ATTACK) != 0;
		
		if (useKeyDown && !WA_FireDown[clientIdx])
		{
			// is active weapon lunchbox?
			new weapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
			if (!IsValidEntity(weapon))
				return;
				
			new weaponIdx = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			new bool:consumedSomething = false;
			if (TF2_GetPlayerClass(clientIdx) == TFClass_Heavy && !WA_IsEatingHeavyFood[clientIdx])
			{
				if ((weaponIdx == 42 || weaponIdx == 863 || weaponIdx == 1002) // sandvich
					|| (weaponIdx == 159 || weaponIdx == 433)) // dalokohs
				{
					new actualMaxHP = (WA_IsDalokohs[clientIdx] ? RoundFloat(WA_HeavyDalokohsBoost) : 0) + GetEntProp(clientIdx, Prop_Data, "m_iMaxHealth");

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
						new weaponToSwap = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Melee);
						if (!IsValidEntity(weaponToSwap))
							weaponToSwap = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary);
						else
						{
							new meleeWeaponIdx = GetEntProp(weaponToSwap, Prop_Send, "m_iItemDefinitionIndex");

							// don't switch do a weapon that drains hp.
							for (new i = 0; i < WA_MAX_HP_DRAIN_WEAPONS; i++)
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
						new weaponToSwap = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary);
						if (!IsValidEntity(weaponToSwap))
							weaponToSwap = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Melee);
						if (IsValidEntity(weaponToSwap))
							SetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon", weaponToSwap);
					}
				}
			}
			
			if (consumedSomething)
			{
				new stunner = FindRandomPlayer(true);
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
public UC_Tick(clientIdx, Float:curTime, buttons)
{
	new bool:keyDown = UC_AltFireActivated[clientIdx] ? ((buttons & IN_ATTACK2) != 0) : ((buttons & IN_RELOAD) != 0);

	if (UC_EndChargeAt[clientIdx] != FAR_FUTURE)
	{
		if (curTime > UC_EndChargeAt[clientIdx])
		{
			UC_EndChargeAt[clientIdx] = FAR_FUTURE;
		}
	}
	else if (keyDown && !UC_KeyDown[clientIdx] && curTime >= UC_UsableAt[clientIdx])
	{
		new bossIdx = FF2_GetBossIndex(clientIdx);
		new Float:bossRage = FF2_GetBossCharge(bossIdx, 0);
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
			static Float:velocity[3];
			GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", velocity);
			ScaleVector(velocity, UC_VelDampening[clientIdx]);
			
			static Float:newVelocity[3];
			static Float:angleToUse[3];
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
public OnGameFrame()
{
	if (!RoundInProgress)
		return;
		
	new Float:curTime = GetEngineTime();

	if (RP_ActiveThisRound)
	{
		// we need to precache certain frequently accessed player data to save computational time
		static Float:clientBounds[MAX_PLAYERS_ARRAY][3];
		static bool:clientValid[MAX_PLAYERS_ARRAY];
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			clientValid[clientIdx] = IsLivingPlayer(clientIdx) && GetClientTeam(clientIdx) != BossTeam;
			if (clientValid[clientIdx])
			{
				GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", clientBounds[clientIdx]);
			}
		}
	
		for (new paraIdx = MAX_PARASITES - 1; paraIdx >= 0; paraIdx--)
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
			new prop = EntRefToEntIndex(RPP_ModelEntRef[paraIdx]);
			new effect = EntRefToEntIndex(RPP_ParticleEntRef[paraIdx]);
			new bestObject = IsValidEntity(prop) ? prop : effect;
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
			
			static Float:paraBounds[3];
			GetEntPropVector(bestObject, Prop_Data, "m_vecOrigin", paraBounds);
			new owner = RPP_Owner[paraIdx]; // for readability
			
			new bool:justAttached = false;
			
			// first check the validity of whatever we're currently attached to
			if (RPP_CurrentVictim[paraIdx] != -1)
			{
				new bool:shouldDetach = false;
				new bool:removedByUber = false;
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
			static Float:paraMin[3];
			static Float:paraMax[3];
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
				for (new victim = 1; victim < MAX_PLAYERS; victim++)
				{
					if (!clientValid[victim])
						continue;
					else if (RPP_ImmuneVictim[paraIdx] == victim && RPP_ImmunityEndsAt[paraIdx] > curTime)
						continue;
					else if (TF2_IsPlayerInCondition(victim, TFCond_Ubercharged) && (RP_Flags[owner] & RP_FLAG_REMOVED_ON_UBER) != 0)
						continue;
						
					new bool:shouldConnect = false;
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
							static Float:tmpAngle[3];
							GetEntPropVector(prop, Prop_Data, "m_angRotation", tmpAngle);
							RPP_SelfYawAtAttachTime[paraIdx] = tmpAngle[1];
							GetEntPropVector(RPP_CurrentVictim[paraIdx], Prop_Data, "m_angRotation", tmpAngle);
							RPP_VictimYawAtAttachTime[paraIdx] = tmpAngle[1];
						}
						else if (IsValidEntity(effect)) // else if ensures if both a prop AND an effect, the effect doesn't move
						{
							// trying to attach it later on is a bit troublesome
							// so just spawn a new one pre-attached to the player
							// first, remove the old of course...
							RemoveEntity(INVALID_HANDLE, RPP_ParticleEntRef[paraIdx]);
							
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
				static Float:victimAngle[3];
				GetEntPropVector(RPP_CurrentVictim[paraIdx], Prop_Data, "m_angRotation", victimAngle);
				static Float:newAngle[3];
				newAngle[0] = 0.0;
				newAngle[1] = fixAngle(RPP_SelfYawAtAttachTime[paraIdx] - (RPP_VictimYawAtAttachTime[paraIdx] - victimAngle[1]));
				newAngle[2] = 0.0;
				
				// offset the object accordingly
				static Float:newBounds[3];
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
						static Float:newPropVelocity[3];
						newPropVelocity[0] = (newBounds[0] - paraBounds[0]) / (curTime - RPP_LastTickTime);
						newPropVelocity[1] = (newBounds[1] - paraBounds[1]) / (curTime - RPP_LastTickTime);
						newPropVelocity[2] = (newBounds[2] - paraBounds[2]) / (curTime - RPP_LastTickTime);
					
						// if we're going for imperfect flight, need to blend the old velocity with the new velocity
						// with bias toward the old velocity. if it's not imperfect flight, we're done here.
						if ((RP_Flags[owner] & RP_FLAG_IMPERFECT_FLIGHT) != 0)
						{
							static Float:oldPropVelocity[3];
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
				new bool:shouldPerformToxic = false;
				new bool:shouldPerformStandard = false;
				
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
				new damageType = DMG_PREVENT_PHYSICS_FORCE;
				static Float:toxicBounds[3];
				toxicBounds[0] = paraBounds[0];
				toxicBounds[1] = paraBounds[1];
				toxicBounds[2] = paraBounds[2];
				if (IsLivingPlayer(RPP_CurrentVictim[paraIdx]))
				{
					new bool:tweakUber = TF2_IsPlayerInCondition(RPP_CurrentVictim[paraIdx], TFCond_Ubercharged) && (RP_Flags[owner] & RP_FLAG_PENETRATE_UBER) != 0;
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
					for (new victim = 1; victim < MAX_PLAYERS; victim++)
					{
						if (victim == RPP_CurrentVictim[paraIdx] || !clientValid[victim])
							continue;

						new bool:hit = false;

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
							new bool:tweakUber = TF2_IsPlayerInCondition(victim, TFCond_Ubercharged) && (RP_Flags[owner] & RP_FLAG_PENETRATE_UBER) != 0;
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
 
public Action:OnPlayerRunCmd(clientIdx, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
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
public Action:OnTakeDamageZatoichi(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	// this assumes you've only assigned this SDKHook to the boss
	if (damagecustom == TF_CUSTOM_DECAPITATION && IsValidEntity(weapon))
	{
		new String:classname[48];
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
stock PlaySoundLocal(clientIdx, String:soundPath[], bool:followPlayer = true, stack = 1)
{
	// play a speech sound that travels normally, local from the player.
	decl Float:playerPos[3];
	GetClientEyePosition(clientIdx, playerPos);
	//PrintToServer("eye pos=%f,%f,%f     sound=%s", playerPos[0], playerPos[1], playerPos[2], soundPath);
	for (new i = 0; i < stack; i++)
		EmitAmbientSound(soundPath, playerPos, followPlayer ? clientIdx : SOUND_FROM_WORLD);
}

stock ParticleEffectAt(Float:position[3], String:effectName[], Float:duration = 0.1)
{
	if (strlen(effectName) < 3)
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
			CreateTimer(duration, RemoveEntity, EntIndexToEntRef(particle));
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
stock AttachParticleToAttachment(entity, const String:particleType[], const String:attachmentPoint[])
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

	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
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

stock FindRandomLivingMerc(team = 2, exclude = -1)
{
	new sanity = 0;
	while (sanity < 100) // break inside
	{
		new i = GetRandomInt(1, 22);
		if (IsLivingPlayer(i) && GetClientTeam(i) == team && i != exclude)
			return i;
			
		sanity++;
	}
			
	return -1;
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
		PrintToServer("[sarysapub1] Error: Invalid weapon spawned. client=%d name=%s idx=%d attr=%s", client, name, index, attribute);
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

public bool:TraceWallsOnly(entity, contentsMask)
{
	return false;
}

public bool:TraceRedPlayers(entity, contentsMask)
{
	if (IsLivingPlayer(entity) && GetClientTeam(entity) != BossTeam)
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysapub2] Hit player %d on trace.", entity);
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

stock Float:fixDamageForFF2(Float:damage)
{
	if (damage <= 160.0)
		return damage / 3.0;
	return damage;
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

stock Float:getLinearVelocity(Float:vecVelocity[3])
{
	return SquareRoot((vecVelocity[0] * vecVelocity[0]) + (vecVelocity[1] * vecVelocity[1]) + (vecVelocity[2] * vecVelocity[2]));
}

stock Float:RandomNegative(Float:in)
{
	return in * (GetRandomInt(0, 1) == 1 ? 1.0 : -1.0);
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

// this version ignores obstacles
stock PseudoAmbientSound(clientIdx, String:soundPath[], count=1, Float:radius=1000.0, bool:skipSelf=false, bool:skipDead=false, Float:volumeFactor=1.0)
{
	decl Float:emitterPos[3];
	decl Float:listenerPos[3];
	GetClientEyePosition(clientIdx, emitterPos);
	for (new listener = 1; listener < MAX_PLAYERS; listener++)
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
		new Float:distance = GetVectorDistance(emitterPos, listenerPos);
		if (distance >= radius)
			continue;
		
		new Float:logMe = (radius - distance) / (radius / 10.0);
		if (logMe <= 0.0) // just a precaution, since EVERYTHING tosses an exception in this game
			continue;
			
		new Float:volume = Logarithm(logMe) * volumeFactor;
		if (volume <= 0.0)
			continue;
		else if (volume > 1.0)
		{
			PrintToServer("[sarysamods6] How the hell is volume greater than 1.0?");
			volume = 1.0;
		}
		
		for (new i = 0; i < count; i++)
			EmitSoundToClient(listener, soundPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume);
	}
}

stock Nope(clientIdx)
{
	EmitSoundToClient(clientIdx, NOPE_AVI);
}

stock bool:IsPlayerInRange(player, Float:position[3], Float:maxDistance)
{
	maxDistance *= maxDistance;
	
	static Float:playerPos[3];
	GetEntPropVector(player, Prop_Data, "m_vecOrigin", playerPos);
	return GetVectorDistance(position, playerPos, true) <= maxDistance;
}

stock FindRandomPlayer(bool:isBossTeam, Float:position[3] = NULL_VECTOR, Float:maxDistance = 0.0, bool:anyTeam = false)
{
	new player = -1;

	// first, get a player count for the team we care about
	new playerCount = 0;
	for (new clientIdx = 0; clientIdx < MAX_PLAYERS; clientIdx++)
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
	new rand = GetRandomInt(0, playerCount - 1);
	playerCount = 0;
	for (new clientIdx = 0; clientIdx < MAX_PLAYERS; clientIdx++)
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
