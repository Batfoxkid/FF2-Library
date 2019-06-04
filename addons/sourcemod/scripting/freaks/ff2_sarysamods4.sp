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
#undef REQUIRE_PLUGIN
#include <goomba>
#define REQUIRE_PLUGIN

/**
 * A fourth wave of mods, composed entirely of rages for others' models.
 *
 * RollingRocks: Spawns players as rolling rocks that can either stun or damage on contact with a non-uber, and knockback anyone.
 *	Credits: As this is derived from the original spawn dead people rage, credit goes to the FF2 team for that code I stole.
 * Known Issues: Force forward perspective looks like this, which is why I don't recommend it: http://www.youtube.com/watch?v=K4dx42YzQCE
 *		 The pyro ignite sound is disabled for the round where this rage is active. This is due to it spamming the rocks with the block ignite flag.
 *
 * Glide: An improved glide that supports things like rage-only or all the time, cooldown, and duration.
 *
 * ImprovedStun: An improved stun rage with more medic options.
 *
 * MeteorShower: A localized meteor shower around the hale, which can do things like touch damage, trigger
 * 		 explosions, and freeze players.
 * Known Issues: If Quick Fix players don't get the MegaHeal condition, they will not be able to remove effects.
 *		 There's a low chance of rockets spawning in unreachable areas.
 *		 Due to FF2 instakilling issues with ignite and bleed, Spies don't get these ailments by design.
 *
 * DOTDisguise: Disguise as a reload-activated rage.
 * Known Issues: Disguise never goes away if a non-spy uses it or a spy with a non-spy melee weapon uses it.
 * Credits: Jug gave me his code, I moved some hardcoding into parameters and made it a reload rage.
 */
 
// NOTE: Added this due to issues with the bots after the taunt change. Do not have this set to true on your live server!
// otherwise, any admin could activate her rage at any time.
new bool:DEBUG_FORCE_RAGE = false;
#define ARG_LENGTH 256
 
new bool:PRINT_DEBUG_INFO = true;
new bool:PRINT_DEBUG_SPAM = false;
 
new Float:OFF_THE_MAP[3] = { 16383.0, 16383.0, -16383.0 };

#define REAL_FL_SWIM (FL_SWIM | FL_INWATER)

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
#define COLOR_BUFFER_SIZE 12
#define HEX_OR_DEC_STRING_LENGTH 12 // max -2 billion is 11 chars + null termination

#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

new MercTeam = _:TFTeam_Red;
new BossTeam = _:TFTeam_Blue;

new RoundInProgress = false;
new bool:PluginActiveThisRound = false;

public Plugin:myinfo = {
	name = "Freak Fortress 2: sarysa's mods, fourth pack",
	author = "sarysa",
	version = "1.4.2",
}

#define FAR_FUTURE 100000000.0
#define IsEmptyString(%1) (%1[0] == 0)

// rolling rocks
#define RR_STRING "rage_rolling_rocks"
#define RR_BLOCK_BACKSTAB 0x01
#define RR_BLOCK_HEADSHOT 0x02
#define RR_BLOCK_GOOMBA 0x04
#define RR_BLOCK_IGNITE 0x08
#define RR_BLOCK_LOW_WORLD_DAMAGE 0x10
#define RR_BLOCK_HIGH_WORLD_DAMAGE 0x20
#define RR_BLOCK_KNOCKBACK 0x40
#define RR_BLOCK_CRITICAL 0x80
#define RR_BLOCK_MOVEMENT_IMPAIR 0x100
#define RR_BLOCK_BLEED 0x200
#define RR_FORCE_FORWARD_PERSPECTIVE 0x10000
#define RR_DESTROY_BUILDINGS 0x20000

#define RR_STUN_NONE 0
#define RR_STUN_MOONSHOT 1
#define RR_STUN_FEAR 2

#define RR_PUSH_INTERVAL 0.025

#define FRAMES_BEFORE_VELOCITY_TEST 20
#define FORWARD_FAILS_BEFORE_TURN 3
#define LOW_WORLD_DAMAGE_THRESHOLD 100.0
#define ROCKS_MINIMUM_KNOCKBACK_Z 450.0 // needs to be higher than the absolute minimum 260 so users can get above hills
#define POST_SWIM_FREE_CONTROL_DURATION 1.0
new bool:RR_ActiveThisRound = false;
new String:RR_ModelName[MAX_MODEL_FILE_LENGTH];
// minion info
#define MI_TP_INTERVAL 1.0
new bool:MI_IsMonitoredClone[MAX_PLAYERS_ARRAY]; // internal
new TFClassType:MI_LastClass[MAX_PLAYERS_ARRAY]; // internal
new Float:MI_ImmuneUntil[MAX_PLAYERS_ARRAY][MAX_PLAYERS_ARRAY]; // internal
new MI_OwnerUserId[MAX_PLAYERS_ARRAY]; // internal
new Float:MI_LastSwamAt[MAX_PLAYERS_ARRAY]; // internal
new Float:MI_NextRollingSoundAt[MAX_PLAYERS_ARRAY]; // internal (for an aesthetic)
new bool:MI_WasOnGroundLastTick[MAX_PLAYERS_ARRAY]; // internal (for an aesthetic)
new Float:MI_PushAt[MAX_PLAYERS_ARRAY]; // internal, next velocity push
new Float:MI_PreviousYaw[MAX_PLAYERS_ARRAY]; // internal, prevent rock from turning too quickly
new Float:MI_RenewThirdPersonAt[MAX_PLAYERS_ARRAY]; // internal
// WASD prevention
#define WASD_HUD_INTERVAL 0.1
#define WASD_HUD_POSITION 0.60
#define WASD_DAMAGE_BEGIN_DELAY 1.0
new Float:MI_LastValidOrigin[MAX_PLAYERS_ARRAY][3];
new Float:MI_WASDDownSince[MAX_PLAYERS_ARRAY];
new Float:MI_AccumulatedWASD[MAX_PLAYERS_ARRAY];
new Float:MI_NextWASDHudAt[MAX_PLAYERS_ARRAY];
new Float:MI_EnableDamageAt[MAX_PLAYERS_ARRAY];
new Float:MI_EquipModelAt[MAX_PLAYERS_ARRAY];
new MI_EquipModelRetries[MAX_PLAYERS_ARRAY];
new Float:MI_FixTauntCamAt[MAX_PLAYERS_ARRAY];
// arguments more or less directly from the .cfg
new TFClassType:MI_ExpectedClass[MAX_PLAYERS_ARRAY]; // arg2
new Float:MI_TurnSpeed[MAX_PLAYERS_ARRAY]; // arg7
new Float:MI_MoveSpeed[MAX_PLAYERS_ARRAY]; // arg8
new Float:MI_DamageOnTouch[MAX_PLAYERS_ARRAY]; // arg9
new MI_StunType[MAX_PLAYERS_ARRAY]; // arg10
new Float:MI_StunDuration[MAX_PLAYERS_ARRAY]; // arg11
new Float:MI_KnockbackIntensity[MAX_PLAYERS_ARRAY]; // arg12
new Float:MI_ImmunityDuration[MAX_PLAYERS_ARRAY]; // arg13, immunity between hits
new Float:MI_HitDetectionHull[MAX_PLAYERS_ARRAY][2][3]; // arg14
new Float:MI_MaxIncomingDamage[MAX_PLAYERS_ARRAY]; // arg15
new Float:MI_RockNoDamageUntil[MAX_PLAYERS_ARRAY]; // arg17
new Float:MI_WASDDamage[MAX_PLAYERS_ARRAY]; // arg18
new MI_RockFlags[MAX_PLAYERS_ARRAY]; // arg19
// rolling rocks victim info
new RRVI_IsStunned[MAX_PLAYERS_ARRAY];
new Float:RRVI_StunnedUntil[MAX_PLAYERS_ARRAY];

// rolling rocks aesthetics
#define RRA_STRING "rolling_rocks_aesthetics"
new String:RRA_RollingSound[MAX_SOUND_FILE_LENGTH]; // arg1
new Float:RRA_RollingSoundLoopInterval = 0.0; // arg2
new String:RRA_PlayerHitSound[MAX_SOUND_FILE_LENGTH]; // arg3
new String:RRA_WallHitSound[MAX_SOUND_FILE_LENGTH]; // arg4, also plays when minion lands after falling
new String:RRA_PlayerHitEffect[MAX_EFFECT_NAME_LENGTH]; // arg5
// arg6 is displayed only at minion spawn, not needed here
new String:RRA_WASDMessage[MAX_CENTER_TEXT_LENGTH]; // arg7
new String:RRA_WASDSound[MAX_SOUND_FILE_LENGTH]; // arg8

// glide
#define GLIDE_STRING "ff2_glide"
new bool:GLIDE_ActiveThisRound = false;
new bool:GLIDE_CanUse[MAX_PLAYERS_ARRAY]; // internal
new bool:GLIDE_IsUsing[MAX_PLAYERS_ARRAY]; // internal
new Float:GLIDE_UsableUntil[MAX_PLAYERS_ARRAY]; // internal, if the glide is part of a rage and not an innate ability
new Float:GLIDE_SingleUseEndTime[MAX_PLAYERS_ARRAY]; // internal, if max duration is set
new Float:GLIDE_SingleUseStartTime[MAX_PLAYERS_ARRAY]; // internal, if max duration is set
new bool:GLIDE_SpaceBarWasDown[MAX_PLAYERS_ARRAY]; // internal
new bool:GLIDE_RageOnly[MAX_PLAYERS_ARRAY]; // arg1
// arg2 is duration if rage only, does not need to be stored
new Float:GLIDE_OriginalMaxVelocity[MAX_PLAYERS_ARRAY]; // arg3
new Float:GLIDE_DecayPerSecond[MAX_PLAYERS_ARRAY]; // arg4
new Float:GLIDE_Cooldown[MAX_PLAYERS_ARRAY]; // arg5
new Float:GLIDE_MaxDuration[MAX_PLAYERS_ARRAY]; // arg6
new String:GLIDE_UseSound[MAX_SOUND_FILE_LENGTH]; // arg7

// improved stun
#define IS_STRING "rage_improved_stun"
new IS_ActiveThisRound = false;
new bool:IS_IsStunned[MAX_PLAYERS_ARRAY];
new IS_ParticleEntRef[MAX_PLAYERS_ARRAY];
new Float:IS_StunnedUntil[MAX_PLAYERS_ARRAY];
new Float:IS_SpeedModifier[MAX_PLAYERS_ARRAY];
new Float:IS_ExpectedSpeed[MAX_PLAYERS_ARRAY];

// meteor shower
#define MS_STRING "rage_meteor_shower"
#define MS_DOT_STRING "dot_meteor_shower"
#define MS_ESCAPE_MASK (IN_ATTACK | IN_ATTACK2 | IN_JUMP | IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT)
#define MS_EFFECT_IGNITE 0x01
#define MS_EFFECT_BLEED 0x02
#define MS_EFFECT_FREEZE 0x04
#define MS_EFFECT_SLOW 0x08
#define MS_EFFECT_MELEE_DAMAGE_CANCEL 0x10
#define MS_EFFECT_FIRE_CANCEL 0x20 // i.e. pyro ignites self to break free
#define MS_EFFECT_WATER_CANCEL 0x40
#define MS_EFFECT_EXPLOSION_CANCEL 0x80 // i.e. demo or soldier rocket/stickies self
#define MS_EFFECT_UBER_CANCEL 0x100
#define MS_EFFECT_MEDIC_REDUCTION 0x200
#define MS_FLAG_IGNORE_WALL_TEST 0x10000
// bleed is a bit messed up, since it's always the same pool of damage spread out over time
// so I can't set the time to infinite. going with 6 seconds and refreshing since that's how bleed weapons work.
#define MS_BLEED_DURATION 6.0
#define MS_BLEED_REFRESH_INTERVAL 5.5
#define MS_ROCKET_LIFE 5.0 // don't want rockets flying perpetually out of the world
#define MS_ROCKET_MAX_SPAWN_HEIGHT 1500.0
#define MS_LOCATION_ATTEMPTS 5
#define MS_TEST_DEVIATION_ANGLE 25.0
#define MAX_ROCKET_MODELS 5
#define ROCKET_ARG_STRING_LENGTH ((MAX_MODEL_FILE_LENGTH * MAX_ROCKET_MODELS) + MAX_ROCKET_MODELS) // semicolon separated
new MS_ActiveThisRound = false;
new bool:MS_IsDOT[MAX_PLAYERS_ARRAY]; // internal
new bool:MS_CanUse[MAX_PLAYERS_ARRAY]; // internal, only used by the DOT version
new bool:MS_IsUsing[MAX_PLAYERS_ARRAY]; // internal
new Float:MS_StartTime[MAX_PLAYERS_ARRAY]; // internal
new Float:MS_SpawnMeteorsUntil[MAX_PLAYERS_ARRAY]; // internal, affected by arg1
new MS_ModelCount[MAX_PLAYERS_ARRAY]; // internal, related to arg8
new MS_SpawnCount[MAX_PLAYERS_ARRAY]; // internal
new MS_TotalRoundSpawnCount[MAX_PLAYERS_ARRAY]; // statistics
new MS_WallFailedCount[MAX_PLAYERS_ARRAY]; // statistics
new MS_EOLCount[MAX_PLAYERS_ARRAY]; // statistics
new Float:MS_SpeedFactor[MAX_PLAYERS_ARRAY]; // arg2
new Float:MS_Damage[MAX_PLAYERS_ARRAY]; // arg3
new Float:MS_SpawnRadius[MAX_PLAYERS_ARRAY]; // arg4
new MS_MeteorsPerSecond[MAX_PLAYERS_ARRAY]; // arg5
new Float:MS_Ang0Minimum[MAX_PLAYERS_ARRAY]; // arg6, angle the meteors fall will be minimum to 89.9
new MS_ModelIndices[MAX_PLAYERS_ARRAY][MAX_ROCKET_MODELS]; // arg7
new String:MS_TrailEffectOverride[MAX_PLAYERS_ARRAY][MAX_MATERIAL_FILE_LENGTH]; // arg8
new MS_EffectFlags[MAX_PLAYERS_ARRAY]; // arg9 (ignite, bleed, freeze, and what invalidates the effects...)
new Float:MS_EffectDuration[MAX_PLAYERS_ARRAY]; // arg10
new String:MS_EffectModel[MAX_PLAYERS_ARRAY][MAX_MODEL_FILE_LENGTH]; // arg11
new Float:MS_EffectOpacity[MAX_PLAYERS_ARRAY]; // arg12
new Float:MS_EffectIntensity[MAX_PLAYERS_ARRAY]; // arg13
new Float:MS_EffectMedicDurationLimit[MAX_PLAYERS_ARRAY]; // arg14
new MS_EffectHealth[MAX_PLAYERS_ARRAY]; // arg15
new MS_EscapeButtonMashCount[MAX_PLAYERS_ARRAY]; // arg16
// meteor shower victim info
new MSVI_Attacker[MAX_PLAYERS_ARRAY];
new Float:MSVI_EffectStartTime[MAX_PLAYERS_ARRAY];
new Float:MSVI_BleedingUntil[MAX_PLAYERS_ARRAY];
new Float:MSVI_OnFireUntil[MAX_PLAYERS_ARRAY];
new Float:MSVI_FrozenUntil[MAX_PLAYERS_ARRAY];
new MSVI_EscapeMask[MAX_PLAYERS_ARRAY];
new MSVI_EscapeButtonMashesRemaining[MAX_PLAYERS_ARRAY];
new Float:MSVI_SlowUntil[MAX_PLAYERS_ARRAY];
new MSVI_FrozenEntRef[MAX_PLAYERS_ARRAY];
new bool:MSVI_FreezeEntitySettled[MAX_PLAYERS_ARRAY];
new Float:MSVI_ExpectedSlowSpeed[MAX_PLAYERS_ARRAY];
new Float:MSVI_RefreshBleedAt[MAX_PLAYERS_ARRAY]; // workaround to bleed's odd mechanics, static damage pool spread out over specified bleed time

// block all taunts (needed to work around an issue with the gentlemen rage)
// unlike other abilities, this one by design is not reset when the round ends
// rather, it gets reset only when the round begins
#define BAT_STRING "ff2_block_all_taunts"
new bool:BAT_ActiveThisRound;

// a limited disguise ability, released as a DOT
#define DD_STRING "dot_disguise"
new bool:DD_ActiveThisRound;
new bool:DD_CanUse[MAX_PLAYERS_ARRAY];
new bool:DD_IsUsing[MAX_PLAYERS_ARRAY];
new bool:DD_DisguiseInProgress[MAX_PLAYERS_ARRAY];
new Float:DD_ExecuteRageAt[MAX_PLAYERS_ARRAY];
new Float:DD_DisguiseDuration[MAX_PLAYERS_ARRAY]; // arg1

// exploit fixes
#define EF_STRING "ff2_exploit_fixes"
new bool:EF_ActiveThisRound;
new bool:EF_CanUse[MAX_PLAYERS_ARRAY];
new Float:EF_LastCloakedAt[MAX_PLAYERS_ARRAY]; // internal
new bool:EF_BlockingTelegoomba[MAX_PLAYERS_ARRAY]; // arg1
new Float:EF_UncloakGoombaFailTime[MAX_PLAYERS_ARRAY]; // arg2
new EF_TelegoombasAllowed[MAX_PLAYERS_ARRAY]; // arg3
new Float:EF_FlatReplacementDamage[MAX_PLAYERS_ARRAY]; // arg4
new Float:EF_ReplacementDamageMultiplier[MAX_PLAYERS_ARRAY]; // arg5
// exploit fixes: unreasonable distance test for telegoomba
#define EF_TERMINAL_VELOCITY 3500.0
#define EF_FRAME_HISTORY_SIZE 7
new Float:EF_FrameTime[MAX_PLAYERS_ARRAY][EF_FRAME_HISTORY_SIZE];
new Float:EF_FramePosition[MAX_PLAYERS_ARRAY][EF_FRAME_HISTORY_SIZE][3];

/**
 * METHODS REQUIRED BY ff2 subplugin
 */
PrintRageWarning()
{
	PrintToServer("*********************************************************************");
	PrintToServer("*                             WARNING                               *");
	PrintToServer("*       DEBUG_FORCE_RAGE in ff2_sarysamods4.sp is set to true!      *");
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
	// NOTE: For DOTs, only basic inits go here. The real init happens on a time delay shortly after.
	// It is recommended you don't load anything related to DOTs until then.
	RoundInProgress = true;
	PluginActiveThisRound = false;
	RR_ActiveThisRound = false;
	GLIDE_ActiveThisRound = false;
	IS_ActiveThisRound = false;
	BAT_ActiveThisRound = false;
	EF_ActiveThisRound = false;
		
	// initialize arrays
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		// rolling rocks
		MI_IsMonitoredClone[clientIdx] = false;
		MI_LastClass[clientIdx] = TFClass_Unknown;
		
		// glide
		GLIDE_CanUse[clientIdx] = false;
		
		// improved stun
		IS_IsStunned[clientIdx] = false;
		IS_StunnedUntil[clientIdx] = 0.0;
		IS_ParticleEntRef[clientIdx] = 0;
		IS_SpeedModifier[clientIdx] = 1.0;
		
		// meteor shower
		MS_IsDOT[clientIdx] = false;
		MS_CanUse[clientIdx] = false;
		MS_IsUsing[clientIdx] = false;
		MSVI_Attacker[clientIdx] = -1;
		MSVI_BleedingUntil[clientIdx] = 0.0;
		MSVI_OnFireUntil[clientIdx] = 0.0;
		MSVI_FrozenUntil[clientIdx] = 0.0;
		MSVI_SlowUntil[clientIdx] = 0.0;
		MSVI_FrozenEntRef[clientIdx] = 0;
		MS_SpawnCount[clientIdx] = 0;
		MS_TotalRoundSpawnCount[clientIdx] = 0;
		MS_WallFailedCount[clientIdx] = 0;
		MS_EOLCount[clientIdx] = 0;
		MSVI_ExpectedSlowSpeed[clientIdx] = 0.0;
		MS_SpawnMeteorsUntil[clientIdx] = 0.0;
		
		// disguise
		DD_CanUse[clientIdx] = false;
		DD_IsUsing[clientIdx] = false;
		DD_DisguiseInProgress[clientIdx] = false;
		DD_ExecuteRageAt[clientIdx] = FAR_FUTURE;
		
		// exploit fixes
		EF_CanUse[clientIdx] = false;
		EF_BlockingTelegoomba[clientIdx] = false;
		EF_UncloakGoombaFailTime[clientIdx] = 0.0;
		EF_LastCloakedAt[clientIdx] = 0.0;
		EF_TelegoombasAllowed[clientIdx] = 0;
		
		// precaches
		new bossIdx = FF2_GetBossIndex(clientIdx);
		if (bossIdx < 0)
			continue;
			
		// precache sounds for regeneration shockwave if applicable
		if (FF2_HasAbility(bossIdx, this_plugin_name, RR_STRING))
		{
			PluginActiveThisRound = true;
			RR_ActiveThisRound = true;
			
			// precache the model
			ReadModelToInt(bossIdx, RR_STRING, 1);
			
			// grab the aesthetics
			if (FF2_HasAbility(bossIdx, this_plugin_name, RRA_STRING))
			{
				ReadSound(bossIdx, RRA_STRING, 1, RRA_RollingSound);
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RRA_STRING, 1, RRA_RollingSound, MAX_SOUND_FILE_LENGTH);
				RRA_RollingSoundLoopInterval = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RRA_STRING, 2);
				ReadSound(bossIdx, RRA_STRING, 3, RRA_PlayerHitSound);
				ReadSound(bossIdx, RRA_STRING, 4, RRA_WallHitSound);
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RRA_STRING, 5, RRA_PlayerHitEffect, MAX_EFFECT_NAME_LENGTH);
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RRA_STRING, 7, RRA_WASDMessage, MAX_CENTER_TEXT_LENGTH);
				ReadSound(bossIdx, RRA_STRING, 8, RRA_WASDSound);
				
				// validity of sound loop interval
				if (RRA_RollingSoundLoopInterval <= 0.0 && strlen(RRA_RollingSound) > 3)
				{
					PrintToServer("[sarysamods4] ERROR: Sound loop interval for rolling sound <= 0.0. Will not use rolling sound.");
					RRA_RollingSound[0] = 0;
				}
			}
			else
			{
				RRA_RollingSound[0] = 0;
				RRA_RollingSoundLoopInterval = 0.0;
				RRA_PlayerHitSound[0] = 0;
				RRA_WallHitSound[0] = 0;
				RRA_PlayerHitEffect[0] = 0;
				RRA_WASDSound[0] = 0;
				RRA_WASDMessage[0] = 0;
			}
		}
		
		// glide
		GLIDE_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, GLIDE_STRING);
		if (GLIDE_CanUse[clientIdx])
		{
			PluginActiveThisRound = true;
			GLIDE_ActiveThisRound = true;
			
			GLIDE_RageOnly[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, GLIDE_STRING, 1) == 1;
			GLIDE_OriginalMaxVelocity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GLIDE_STRING, 3);
			GLIDE_DecayPerSecond[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GLIDE_STRING, 4);
			GLIDE_Cooldown[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GLIDE_STRING, 5);
			GLIDE_MaxDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GLIDE_STRING, 6);
			ReadSound(bossIdx, GLIDE_STRING, 7, GLIDE_UseSound);
			
			// internal inits
			GLIDE_IsUsing[clientIdx] = false;
			GLIDE_SingleUseStartTime[clientIdx] = 0.0;
			GLIDE_SingleUseEndTime[clientIdx] = 0.0;
			GLIDE_SpaceBarWasDown[clientIdx] = false;
			if (!GLIDE_RageOnly[clientIdx])
				GLIDE_UsableUntil[clientIdx] = 99999999.0; // usable forever
			else
				GLIDE_UsableUntil[clientIdx] = 0.0; // off for now
			if (GLIDE_MaxDuration[clientIdx] <= 0.0) // usable as long as the user wants
				GLIDE_MaxDuration[clientIdx] = 999999.0;
				
			if (PRINT_DEBUG_INFO)
				PrintToServer("[sarysamods4] User %d using glide this round. rageOnly=%d glideVel=%f decayPS=%f cooldown=%f maxDur=%f", clientIdx,
						GLIDE_RageOnly[clientIdx], GLIDE_OriginalMaxVelocity[clientIdx], GLIDE_DecayPerSecond[clientIdx], GLIDE_Cooldown[clientIdx], GLIDE_MaxDuration[clientIdx]);
		}
		
		// improved stun
		if (FF2_HasAbility(bossIdx, this_plugin_name, IS_STRING))
		{
			PluginActiveThisRound = true;
			IS_ActiveThisRound = true;
		}
			
		// meteor shower
		new String:msString[20] = MS_STRING;
		MS_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, msString);
		if (!MS_CanUse[clientIdx])
		{
			msString = MS_DOT_STRING;
			MS_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, msString);
			MS_IsDOT[clientIdx] = true;
		}
		if (MS_CanUse[clientIdx])
		{
			PluginActiveThisRound = true;
			MS_ActiveThisRound = true;
			MS_SpeedFactor[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, msString, 2);
			MS_Damage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, msString, 3);
			MS_SpawnRadius[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, msString, 4);
			MS_MeteorsPerSecond[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, msString, 5);
			MS_Ang0Minimum[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, msString, 6);
			static String:modelsStr[ROCKET_ARG_STRING_LENGTH];
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, msString, 7, modelsStr, ROCKET_ARG_STRING_LENGTH);
			new String:modelNames[MAX_ROCKET_MODELS][MAX_MODEL_FILE_LENGTH];
			ExplodeString(modelsStr, ";", modelNames, MAX_ROCKET_MODELS, MAX_MODEL_FILE_LENGTH);
			MS_ModelCount[clientIdx] = 0;
			for (new i = 0; i < MAX_ROCKET_MODELS; i++)
			{
				if (strlen(modelNames[i]) > 3)
				{
					if (MS_ModelCount[clientIdx] == i)
						MS_ModelCount[clientIdx]++; // in case there's a hole in the list
					MS_ModelIndices[clientIdx][i] = PrecacheModel(modelNames[i]);
				}
				else
					MS_ModelIndices[clientIdx][i] = 0;
			}
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, msString, 8, MS_TrailEffectOverride[clientIdx], MAX_MATERIAL_FILE_LENGTH);
			MS_EffectFlags[clientIdx] = ReadHexOrDecString(bossIdx, msString, 9);
			MS_EffectDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, msString, 10);
			ReadModel(bossIdx, msString, 11, MS_EffectModel[clientIdx]);
			MS_EffectOpacity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, msString, 12);
			MS_EffectIntensity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, msString, 13);
			MS_EffectMedicDurationLimit[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, msString, 14);
			MS_EffectHealth[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, msString, 15);
			MS_EscapeButtonMashCount[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, msString, 16);
		}
		
		// block all taunts
		BAT_ActiveThisRound = BAT_ActiveThisRound || FF2_HasAbility(bossIdx, this_plugin_name, BAT_STRING);
		
		// DOT disguise
		DD_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, DD_STRING);
		if (DD_CanUse[clientIdx])
		{
			PluginActiveThisRound = true;
			DD_ActiveThisRound = true;
			DD_DisguiseDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DD_STRING, 1);
		}
		
		// exploit fixes
		if (FF2_HasAbility(bossIdx, this_plugin_name, EF_STRING))
		{
			PluginActiveThisRound = true;
			EF_ActiveThisRound = true;
			EF_CanUse[clientIdx] = true;
			EF_BlockingTelegoomba[clientIdx] = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, EF_STRING, 1) == 1);
			EF_UncloakGoombaFailTime[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EF_STRING, 2);
			EF_TelegoombasAllowed[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, EF_STRING, 3);
			EF_FlatReplacementDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EF_STRING, 4);
			EF_ReplacementDamageMultiplier[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, EF_STRING, 5);
		}
	}
	
	if (RR_ActiveThisRound)
		RR_RegisterListeners();
		
	if (MS_ActiveThisRound)
		MS_RegisterListeners();
		
	if (BAT_ActiveThisRound)
	{
		AddCommandListener(BAT_BlockTaunt, "taunt");
		AddCommandListener(BAT_BlockTaunt, "+taunt");
		AddCommandListener(BAT_BlockTaunt, "-taunt");
		AddCommandListener(BAT_BlockTaunt, "taunt_by_name");
	}
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	RoundInProgress = false;
	
	if (RR_ActiveThisRound)
	{
		RR_ActiveThisRound = false;
		RR_UnregisterListeners();
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (MI_IsMonitoredClone[clientIdx] && IsLivingPlayer(clientIdx))
			{
				RR_UnregisterUserSpecificListeners(clientIdx);
				if (TF2_IsPlayerInCondition(clientIdx, TFCond_Taunting))
					TF2_RemoveCondition(clientIdx, TFCond_Taunting);
			}
				
			// known issue with this, it can mess with the class of someone if their client index changes
			if (IsClientInGame(clientIdx) && MI_LastClass[clientIdx] != TFClass_Unknown)
			{
				TF2_SetPlayerClass(clientIdx, MI_LastClass[clientIdx]);
				MI_LastClass[clientIdx] = TFClass_Unknown;
			}
			MI_IsMonitoredClone[clientIdx] = false; 
			
			// fix everyone's gravity, as gravity changes will roll over to subsequent rounds if left unfixed
			if (IsClientInGame(clientIdx))
				SetEntityGravity(clientIdx, 1.0);
		}
	}
	
	GLIDE_ActiveThisRound = false;
	
	if (IS_ActiveThisRound)
	{
		IS_ActiveThisRound = false;
		for (new victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (IS_IsStunned[victim])
			{
				if (TF2_IsPlayerInCondition(victim, TFCond_Dazed))
					TF2_RemoveCondition(victim, TFCond_Dazed);
				IS_IsStunned[victim] = false;
			}
			
			if (IS_ParticleEntRef[victim] != 0)
			{
				new particle = EntRefToEntIndex(IS_ParticleEntRef[victim]);
				if (IsValidEntity(particle))
					RemoveEntity(IS_ParticleEntRef[victim]);
				IS_ParticleEntRef[victim] = 0;
			}
		}
	}
	
	if (MS_ActiveThisRound)
	{
		MS_ActiveThisRound = false;
		MS_UnregisterListeners();
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsLivingPlayer(clientIdx) && GetClientTeam(clientIdx) != BossTeam)
				MS_RemoveAllAilments(clientIdx);
				
			if (MS_TotalRoundSpawnCount[clientIdx] > 0 && PRINT_DEBUG_INFO)
				PrintToServer("[sarysamods4] End of round for meteor shower. %d meteors spawned, %d failed wall test, %d destroyed by time limit.", MS_TotalRoundSpawnCount[clientIdx], MS_WallFailedCount[clientIdx], MS_EOLCount[clientIdx]);
		}
	}

	if (BAT_ActiveThisRound)
	{
		BAT_ActiveThisRound = false;
		RemoveCommandListener(BAT_BlockTaunt, "taunt");
		RemoveCommandListener(BAT_BlockTaunt, "+taunt");
		RemoveCommandListener(BAT_BlockTaunt, "-taunt");
		RemoveCommandListener(BAT_BlockTaunt, "taunt_by_name");
	}
}

public Action:FF2_OnAbility2(bossIdx, const String:plugin_name[], const String:ability_name[], status)
{
	if (strcmp(plugin_name, this_plugin_name) != 0)
		return Plugin_Continue;
	else if (!RoundInProgress) // don't execute these rages with 0 players alive
		return Plugin_Continue;

	if (!strcmp(ability_name, RR_STRING))
		Rage_RollingRocks(ability_name, bossIdx);
	else if (!strcmp(ability_name, GLIDE_STRING))
		Rage_Glide(ability_name, bossIdx);
	else if (!strcmp(ability_name, IS_STRING))
		Rage_ImprovedStun(ability_name, bossIdx);
	else if (!strcmp(ability_name, MS_STRING))
		Rage_MeteorShower(ability_name, bossIdx);
		
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
	
	if (!strcmp("rocks", unparsedArgs))
	{
		Rage_RollingRocks(RR_STRING, 0);
		return Plugin_Handled;
	}
	else if (!strcmp("stun", unparsedArgs))
	{
		Rage_ImprovedStun(IS_STRING, 0);
		return Plugin_Handled;
	}
	else if (!strcmp("meteor", unparsedArgs))
	{
		Rage_MeteorShower(MS_STRING, 0);
		return Plugin_Handled;
	}
	
	PrintToServer("[sarysamods4] Rage not found: %s", unparsedArgs);
	return Plugin_Continue;
}

/**
 * BAT workaround
 */
public Action:BAT_BlockTaunt(clientIdx, const String:command[], argc)
{
	if (IsLivingPlayer(clientIdx) && BAT_ActiveThisRound && GetClientTeam(clientIdx) == BossTeam)
		return Plugin_Stop;
		
	return Plugin_Continue;
}

/**
 * Required by DOT rages
 */
DOTPostRoundStartInit()
{
	// nothing to do
}

OnDOTAbilityActivated(clientIdx)
{
	if (MS_CanUse[clientIdx] && MS_IsDOT[clientIdx])
	{
		MS_SpawnMeteorsUntil[clientIdx] = GetEngineTime() + 9999.0;
		MS_IsUsing[clientIdx] = true;
		MS_SpawnCount[clientIdx] = 0;
		MS_StartTime[clientIdx] = GetEngineTime();
	}
	
	if (DD_CanUse[clientIdx])
	{
		if (!DOTDisguise(clientIdx))
			CancelDOTAbilityActivation(clientIdx);
		else
			DD_IsUsing[clientIdx] = true;
	}
}

OnDOTAbilityDeactivated(clientIdx)
{
	if (MS_CanUse[clientIdx] && MS_IsDOT[clientIdx])
	{
		MS_SpawnMeteorsUntil[clientIdx] = 0.0;
		MS_IsUsing[clientIdx] = false;
	}
}

OnDOTUserDeath(clientIdx, isInGame)
{
	// suppress
	if (isInGame || clientIdx) { }
} 

Action:OnDOTAbilityTick(clientIdx, tickCount)
{
	if (DD_CanUse[clientIdx] && DD_IsUsing[clientIdx])
		ForceDOTAbilityDeactivation(clientIdx);

	// suppress
	if (tickCount || clientIdx) { }
}

/**
 * Rolling Rocks helper methods
 */
public Action:Timer_RestoreLastClass(Handle:timer, any:userId)
{
	new clientIdx = GetClientOfUserId(userId);
	if (clientIdx < 1 || clientIdx >= MAX_PLAYERS)
		return Plugin_Continue;
	
	// don't do this if the player got quickly respawned after dying
	if (IsLivingPlayer(clientIdx))
		return Plugin_Continue;
		
	TF2_SetPlayerClass(clientIdx, MI_LastClass[clientIdx]);
	ChangeClientTeam(clientIdx, MercTeam);
	return Plugin_Continue;
}
 
public RR_RegisterListeners()
{
	if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods4] Rolling rocks this round. Registering taunt listeners.");

	AddCommandListener(BlockTaunt, "taunt");
	AddCommandListener(BlockTaunt, "+taunt");
	AddCommandListener(BlockTaunt, "-taunt");
	AddCommandListener(BlockTaunt, "taunt_by_name");
	AddNormalSoundHook(BlockSound);
	HookEvent("player_death", RR_PlayerDeath);
	HookEvent("player_disconnect", RR_PlayerDisconnect, EventHookMode_Pre);
}

public RR_UnregisterListeners()
{
	if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods4] Unregistering taunt listeners.");
		
	RemoveCommandListener(BlockTaunt, "taunt");
	RemoveCommandListener(BlockTaunt, "+taunt");
	RemoveCommandListener(BlockTaunt, "-taunt");
	RemoveCommandListener(BlockTaunt, "taunt_by_name");
	RemoveNormalSoundHook(BlockSound);
	UnhookEvent("player_death", RR_PlayerDeath);
	UnhookEvent("player_disconnect", RR_PlayerDisconnect, EventHookMode_Pre);
}

public RR_RegisterUserSpecificListeners(clientIdx)
{
	if (PRINT_DEBUG_SPAM)
		PrintToServer("[sarysamods4] Client %d is a rock, will get user-specific listeners.", clientIdx);
		
	SDKHook(clientIdx, SDKHook_OnTakeDamage, OnRocksTakeDamage);
	SDKHook(clientIdx, SDKHook_OnTakeDamagePost, OnRocksTakeDamagePost);
	if (RR_BLOCK_MOVEMENT_IMPAIR & MI_RockFlags[clientIdx])
		TF2_AddCondition(clientIdx, TFCond_MegaHeal, -1.0);
}

public RR_UnregisterUserSpecificListeners(clientIdx)
{
	if (PRINT_DEBUG_SPAM)
		PrintToServer("[sarysamods4] Client %d is a rock, will lose user-specific listeners.", clientIdx);
		
	SDKUnhook(clientIdx, SDKHook_OnTakeDamage, OnRocksTakeDamage);
	SDKUnhook(clientIdx, SDKHook_OnTakeDamagePost, OnRocksTakeDamagePost);
	if (RR_BLOCK_MOVEMENT_IMPAIR & MI_RockFlags[clientIdx])
		TF2_RemoveCondition(clientIdx, TFCond_MegaHeal);
}

public Action:BlockTaunt(client, const String:command[], argc)
{
	if (client > 0 && client < MAX_PLAYERS)
	{
		if (MI_IsMonitoredClone[client])
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

// tweaked from the FF2 version
public Action:BlockSound(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &clientIdx, &channel, &Float:volume, &level, &pitch, &flags)
{
	if (!IsLivingPlayer(clientIdx))
		return Plugin_Continue;
		
	//PrintToServer("Player sound: %s", sample);

	// in soviet russia, !StrContains() means StrContains()
	// gotta love those old poorly conceived std c methods given modern sounding names
	// that make you think they actually do what the sign says, eh?
	if (MI_IsMonitoredClone[clientIdx] && (!StrContains(sample, "vo") || StrContains(sample, "clap") >= 0 || StrContains(sample, "footstep") >= 0))
		return Plugin_Stop;
	else if (StrContains(sample, "flame_engulf") >= 0)
		return Plugin_Stop; // this sound spams the rocks, so just get rid of it this round.
	return Plugin_Continue;
}

Float:GetMoveSpeedModifier(Float:speed, TFClassType:class)
{
	new Float:baseSpeed = 300.0;
	if (class == TFClass_Scout)
		baseSpeed = 400.0;
	else if (class == TFClass_Soldier)
		baseSpeed = 240.0;
	else if (class == TFClass_DemoMan)
		baseSpeed = 280.0;
	else if (class == TFClass_Heavy)
		baseSpeed = 230.0;
	else if (class == TFClass_Medic)
		baseSpeed = 320.0;
		
	return speed / baseSpeed;
}

/**
 * Rolling Rocks
 *
 * The spawning portion is modified Rage_Clone from ff2_1st_set_abilities
 * While the control augmentation is my doing.
 */
public RR_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	// prevent client takeover from getting class switched
	new clientIdx = GetClientOfUserId(GetEventInt(event, "userid"));
	if (clientIdx < 1 && clientIdx > MAX_PLAYERS)
		MI_LastClass[clientIdx] = TFClass_Unknown;
}

public RR_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	//new killer = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (victim <= 0 || victim >= MAX_PLAYERS)
		return;
		
	if (MI_IsMonitoredClone[victim])
	{
		RR_UnregisterUserSpecificListeners(victim);
		MI_IsMonitoredClone[victim] = false;
	}
}

#define CRIT_MASK (DMG_CRIT | (DMG_CRIT<<1))
public Action:OnRocksTakeDamage(clientIdx, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (!IsLivingPlayer(clientIdx))
		return Plugin_Continue;
	else if (GetClientTeam(clientIdx) != BossTeam || !MI_IsMonitoredClone[clientIdx])
	{
		RR_UnregisterUserSpecificListeners(clientIdx);
		return Plugin_Continue;
	}
	
	if (PRINT_DEBUG_SPAM)
		PrintToServer("[sarysamods4] Rock took damage. %f 0x%x %d   attacker=%d   inflictor=%d   crit=0x%x", damage, damagetype, damagecustom, attacker, inflictor, DMG_CRIT);
	
	if (MI_RockFlags[clientIdx] & RR_BLOCK_KNOCKBACK)
		damagetype |= DMG_PREVENT_PHYSICS_FORCE;
	if (MI_RockFlags[clientIdx] & RR_BLOCK_CRITICAL)
		damagetype &= ~CRIT_MASK;

	if (attacker <= 0 || attacker >= MAX_PLAYERS)
	{
		new String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
		if (attacker >= MAX_PLAYERS)
			GetEntityClassname(attacker, classname, sizeof(classname));
	
		if (strcmp(classname, "obj_sentrygun")) // world damage is anything not from a sentry
		{
			if (damage < LOW_WORLD_DAMAGE_THRESHOLD && (MI_RockFlags[clientIdx] & RR_BLOCK_LOW_WORLD_DAMAGE))
				damage = 0.0;
			else if (damage >= LOW_WORLD_DAMAGE_THRESHOLD && (MI_RockFlags[clientIdx] & RR_BLOCK_HIGH_WORLD_DAMAGE))
				damage = 0.0;
				
			return Plugin_Changed;
		}
	}
	
	if (damagecustom == TF_CUSTOM_BACKSTAB && (MI_RockFlags[clientIdx] & RR_BLOCK_BACKSTAB))
	{
		damage = 35.0;
		damagetype &= ~CRIT_MASK;
	}
	
	if (damagecustom == TF_CUSTOM_HEADSHOT && (MI_RockFlags[clientIdx] & RR_BLOCK_HEADSHOT))
	{
		damage *= 3.0;
		damagetype &= ~CRIT_MASK;
	}
	
	// intentionally here because if world damage is not blocked, it probably should kill the rock or hurt them normally
	if (damage > MI_MaxIncomingDamage[clientIdx] && MI_MaxIncomingDamage[clientIdx] > 0.0)
		damage = MI_MaxIncomingDamage[clientIdx];
		
	return Plugin_Changed;
}

public OnRocksTakeDamagePost(clientIdx, attacker, inflictor, Float:damage, damagetype)
{
	if (!IsLivingPlayer(clientIdx))
		return;
		
	if ((MI_RockFlags[clientIdx] & RR_BLOCK_IGNITE) && TF2_IsPlayerInCondition(clientIdx, TFCond_OnFire))
		TF2_RemoveCondition(clientIdx, TFCond_OnFire);
	if ((MI_RockFlags[clientIdx] & RR_BLOCK_BLEED) && TF2_IsPlayerInCondition(clientIdx, TFCond_Bleeding))
		TF2_RemoveCondition(clientIdx, TFCond_Bleeding);
}

public Action:OnStomp(attacker, victim, &Float:damageMultiplier, &Float:damageBonus, &Float:JumpPower)
{
	// note for all these goomba blocking cases
	// I tried Plugin_Stop but it does not prevent the victim from dying
	// so it has to be damage set to 0, even though the attacker still flies

	//PrintToServer("This works: %f, %f", damageMultiplier, damageBonus);
	if (RR_ActiveThisRound)
	{
		if (MI_IsMonitoredClone[victim] && (MI_RockFlags[victim] & RR_BLOCK_GOOMBA))
		{
			damageMultiplier = 0.0;
			damageBonus = 0.0;
			return Plugin_Changed;
		}
	}
	
	// sarysa 2014-10-08
	if (EF_BlockingTelegoomba[attacker])
	{
		new bool:shouldBlock = TF2_IsPlayerInCondition(attacker, TFCond_Dazed);
		if (!shouldBlock)
		{
			// do the distance test
			new Float:timeDiff = GetEngineTime() - EF_FrameTime[attacker][0];
			static Float:attackerPos[3];
			GetEntPropVector(attacker, Prop_Data, "m_vecOrigin", attackerPos);
			
			new Float:dist = GetVectorDistance(attackerPos, EF_FramePosition[attacker][0]);
			
			new Float:maxAllowedDistance = (EF_TERMINAL_VELOCITY * 1.3) * timeDiff;
			if (dist > maxAllowedDistance)
				shouldBlock = true;
		}

		if (shouldBlock)
		{
			if (EF_TelegoombasAllowed[attacker] > 0)
				EF_TelegoombasAllowed[attacker]--;
			else if (EF_FlatReplacementDamage[attacker] <= 0.0 && EF_ReplacementDamageMultiplier[attacker] <= 0.0)
				return Plugin_Handled;
			else
			{
				damageMultiplier = EF_ReplacementDamageMultiplier[attacker];
				damageBonus = EF_FlatReplacementDamage[attacker];
				return Plugin_Changed;
			}
		}
	}
	
	if (EF_UncloakGoombaFailTime[attacker] > 0.0)
	{
		if (EF_LastCloakedAt[attacker] + EF_UncloakGoombaFailTime[attacker] >= GetEngineTime())
		{
			if (PRINT_DEBUG_INFO)
				PrintToServer("[sarysamods4] Goomba by %d regulated. %f seconds since uncloak.", attacker, (GetEngineTime() - EF_LastCloakedAt[attacker]));
				
			if (EF_FlatReplacementDamage[attacker] <= 0.0 && EF_ReplacementDamageMultiplier[attacker] <= 0.0)
				return Plugin_Handled;
			else
			{
				damageMultiplier = EF_ReplacementDamageMultiplier[attacker];
				damageBonus = EF_FlatReplacementDamage[attacker];
				return Plugin_Changed;
			}
		}
		else if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods4] Goomba by %d not blocked. %f seconds since uncloak. %f", attacker, (GetEngineTime() - EF_LastCloakedAt[attacker]), EF_UncloakGoombaFailTime[attacker]);
	}
	
	return Plugin_Continue;
}

public Action:RR_OnPlayerRunCmd(clientIdx, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	// rolling rocks
	if (RR_ActiveThisRound)
	{
		// frame by frame time deltas are extremely unreliable
		new Float:curTime = GetEngineTime();
				
		if (MI_IsMonitoredClone[clientIdx])
		{
			new bool:wasdPressed = false;
			if (buttons & (IN_MOVELEFT | IN_MOVERIGHT | IN_FORWARD | IN_BACK))
				wasdPressed = true;
			buttons = 0;

			if (!IsLivingPlayer(clientIdx))
			{
				MI_IsMonitoredClone[clientIdx] = false;
				//continue;
				return Plugin_Changed;
			}
			
			if (curTime >= MI_EnableDamageAt[clientIdx])
			{
				MI_EnableDamageAt[clientIdx] = FAR_FUTURE;
				SetEntProp(clientIdx, Prop_Data, "m_takedamage", 2);
				FF2_SetFF2flags(clientIdx, FF2_GetFF2flags(clientIdx) & ~FF2FLAG_ALLOWSPAWNINBOSSTEAM);
			}
			
			if (curTime >= MI_EquipModelAt[clientIdx])
			{
				if (strlen(RR_ModelName) > 3)
				{
					SetVariantString(RR_ModelName);
					AcceptEntityInput(clientIdx, "SetCustomModel");
					SetEntProp(clientIdx, Prop_Send, "m_bUseClassAnimations", 1);
					TF2_SetPlayerClass(clientIdx, MI_ExpectedClass[clientIdx]);
				}
				
				MI_EquipModelRetries[clientIdx]--;
				if (MI_EquipModelRetries[clientIdx] > 0)
					MI_EquipModelAt[clientIdx] = curTime + 0.5;
				else
					MI_EquipModelAt[clientIdx] = FAR_FUTURE;
			}
			
			if (curTime >= MI_FixTauntCamAt[clientIdx])
			{
				MI_FixTauntCamAt[clientIdx] = FAR_FUTURE;
				SetVariantInt(1);
				AcceptEntityInput(clientIdx, "SetForcedTauntCam");
			}

			// did the player hit the ground? if so, play a sound
			new bool:onGround = (GetEntityFlags(clientIdx) & FL_ONGROUND) != 0;
			if (onGround && !MI_WasOnGroundLastTick[clientIdx])
			{
				if (strlen(RRA_WallHitSound) > 3)
					PlaySoundLocal(clientIdx, RRA_WallHitSound, false, 2);
			}
			MI_WasOnGroundLastTick[clientIdx] = onGround;

			// if the user is on the ground now, we can play the rolling sound if applicable
			if (curTime >= MI_NextRollingSoundAt[clientIdx])
			{
				if (strlen(RRA_RollingSound) > 3)
					PlaySoundLocal(clientIdx, RRA_RollingSound, true, 2);
				MI_NextRollingSoundAt[clientIdx] = curTime + RRA_RollingSoundLoopInterval;
			}

			// ensure the owner is still alive. if not, kill off this rock.
			if (!IsLivingPlayer(GetClientOfUserId(MI_OwnerUserId[clientIdx])))
			{
				new rockSlayer = FindRandomPlayer(false);
				if (!IsLivingPlayer(rockSlayer)) // wtf?
				{
					MI_IsMonitoredClone[clientIdx] = false;
					return Plugin_Continue;
				}
				
				// sarysa 2014-09-23, remove uber and reenable damage! whoops.
				if (TF2_IsPlayerInCondition(clientIdx, TFCond_Ubercharged))
					TF2_RemoveCondition(clientIdx, TFCond_Ubercharged);
				SetEntProp(clientIdx, Prop_Data, "m_takedamage", 2);

				MI_MaxIncomingDamage[clientIdx] = 0.0;
				MI_RockFlags[clientIdx] = 0;
				SDKHooks_TakeDamage(clientIdx, rockSlayer, rockSlayer, 9999.0, DMG_GENERIC, -1);
				MI_IsMonitoredClone[clientIdx] = false;
				return Plugin_Continue;
			}

			new Float:rockOrigin[3];
			new Float:angRotation[3];
			new Float:vecVelocity[3];
			GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", rockOrigin);
			GetEntPropVector(clientIdx, Prop_Send, "m_angRotation", angRotation);
			GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", vecVelocity);
			new Float:velocityThisFrame = velocityFromVector(vecVelocity);

			// test every player for collision
			// it's a two-bit collision test to be sure, but it'll work since the rocks move slow enough
			// and their collision area is huge.
			new Float:min[3];
			new Float:max[3];
			min[0] = rockOrigin[0] + MI_HitDetectionHull[clientIdx][0][0];
			min[1] = rockOrigin[1] + MI_HitDetectionHull[clientIdx][0][1];
			min[2] = rockOrigin[2] + MI_HitDetectionHull[clientIdx][0][2];
			max[0] = rockOrigin[0] + MI_HitDetectionHull[clientIdx][1][0];
			max[1] = rockOrigin[1] + MI_HitDetectionHull[clientIdx][1][1];
			max[2] = rockOrigin[2] + MI_HitDetectionHull[clientIdx][1][2];
			new Float:victimOrigin[3];
			new Float:knockbackVelocity[3];
			if (curTime >= MI_RockNoDamageUntil[clientIdx])
			{
				for (new victim = 1; victim < MAX_PLAYERS; victim++)
				{
					if (!IsLivingPlayer(victim))
						continue;
					else if (GetClientTeam(victim) == BossTeam)
						continue;

					// test the top of the player and the bottom for collision in our simple rectangle
					// will work since the rocks' collision rects should be taller than players and extend well beyond the rocks
					GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimOrigin);
					new bool:withinBounds = WithinBounds(victimOrigin, min, max);
					victimOrigin[2] += 63.0;
					withinBounds = withinBounds || WithinBounds(victimOrigin, min, max);
					victimOrigin[2] -= 63.0;

					//PrintToServer("is %f,%f,%f   within bounds of   %f,%f,%f and %f,%f,%f ?", victimOrigin[0], victimOrigin[1], victimOrigin[2], min[0], min[1], min[2], max[0], max[1], max[2]);

					if (withinBounds && MI_ImmuneUntil[clientIdx][victim] <= curTime) // hit!
					{
						if (PRINT_DEBUG_SPAM)
							PrintToServer("[sarysamods4] Rock %d hit mercenary %d!", clientIdx, victim);

						MI_ImmuneUntil[clientIdx][victim] = curTime + MI_ImmunityDuration[clientIdx];

						// apply knockback
						if (MI_KnockbackIntensity[clientIdx] > 0.0)
						{
							MakeVectorFromPoints(rockOrigin, victimOrigin, knockbackVelocity);
							NormalizeVector(knockbackVelocity, knockbackVelocity);

							// figure out our knockback, override any existing velocity the player has
							knockbackVelocity[0] = (knockbackVelocity[0] * velocityThisFrame * MI_KnockbackIntensity[clientIdx]);
							knockbackVelocity[1] = (knockbackVelocity[1] * velocityThisFrame * MI_KnockbackIntensity[clientIdx]);
							knockbackVelocity[2] = (knockbackVelocity[2] * velocityThisFrame * MI_KnockbackIntensity[clientIdx]);

							// if rock isn't moving, just knock the player up
							if (velocityThisFrame == 0)
								knockbackVelocity[2] = 750.0 * MI_KnockbackIntensity[clientIdx];

							// absolute minimum Z is 300, otherwise victim will not move in many cases
							if (knockbackVelocity[2] < ROCKS_MINIMUM_KNOCKBACK_Z)
								knockbackVelocity[2] = ROCKS_MINIMUM_KNOCKBACK_Z;

							// knock the player back!
							TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, knockbackVelocity);
						}

						// the rest we don't do if user is ubered
						if (!TF2_IsPlayerInCondition(victim, TFCond_Ubercharged))
						{
							// apply stun
							if (MI_StunDuration[clientIdx] > 0.0 && MI_StunType[clientIdx] != RR_STUN_NONE)
							{
								if (PRINT_DEBUG_SPAM)
									PrintToServer("[sarysamods4] Client %d stunned %f", clientIdx, victim);

								new flags = MI_StunType[clientIdx] == RR_STUN_MOONSHOT ? (TF_STUNFLAG_BONKSTUCK | TF_STUNFLAG_NOSOUNDOREFFECT) : (TF_STUNFLAGS_SMALLBONK | TF_STUNFLAG_NOSOUNDOREFFECT);
								TF2_StunPlayer(victim, 99999.0, 0.0, flags, clientIdx);
								RRVI_IsStunned[victim] = true;
								RRVI_StunnedUntil[victim] = MI_StunDuration[clientIdx] + curTime;
							}

							// apply damage
							if (MI_DamageOnTouch[clientIdx] > 0.0)
								SDKHooks_TakeDamage(victim, clientIdx, clientIdx, MI_DamageOnTouch[clientIdx], DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
						}

						// play sound if applicable
						if (strlen(RRA_PlayerHitSound) > 3)
							PlaySoundLocal(victim, RRA_PlayerHitSound, false, 3);

						// particle effect if applicable
						if (!IsEmptyString(RRA_PlayerHitEffect))
						{
							victimOrigin[2] += 41.5;
							ParticleEffectAt(victimOrigin, RRA_PlayerHitEffect, 1.0);
							victimOrigin[2] -= 41.5;
						}
					}
				}

				if (MI_RockFlags[clientIdx] & RR_DESTROY_BUILDINGS)
				{
					new String:entName[MAX_ENTITY_CLASSNAME_LENGTH];
					for (new i = 0; i < 3; i++)
					{
						if (i == 0)
							entName = "obj_sentrygun";
						else if (i == 1)
							entName = "obj_dispenser";
						else if (i == 2)
							entName = "obj_teleporter";

						new building = -1;
						while ((building = FindEntityByClassname(building, entName)) != -1)
						{
							GetEntPropVector(building, Prop_Send, "m_vecOrigin", victimOrigin);
							new bool:withinBounds = WithinBounds(victimOrigin, min, max);
							victimOrigin[2] += 63.0;
							withinBounds = withinBounds || WithinBounds(victimOrigin, min, max);
							victimOrigin[2] -= 63.0;

							if (withinBounds)
							{
								if (PRINT_DEBUG_SPAM)
									PrintToServer("[sarysamods4] Building %d destroyed by rock.", building);

								// held buildings are already invalidated from this, I know from my work with Cheese
								SDKHooks_TakeDamage(building, clientIdx, clientIdx, 9999.0, DMG_GENERIC, -1);
							}
						}
					}
				}
			}
			
			// renew third person every second
			if (curTime >= MI_RenewThirdPersonAt[clientIdx])
			{
				SetVariantInt(1);
				AcceptEntityInput(clientIdx, "SetForcedTauntCam");
				MI_RenewThirdPersonAt[clientIdx] = curTime + MI_TP_INTERVAL;
			}
			
			// if player is swimming, give them free motion so they can get out of the water.
			if (GetEntityFlags(clientIdx) & REAL_FL_SWIM)
				MI_LastSwamAt[clientIdx] = curTime;
			if (curTime < MI_LastSwamAt[clientIdx] + POST_SWIM_FREE_CONTROL_DURATION)
				return Plugin_Continue;
			
			// otherwise, block WASD
			if (wasdPressed)
			{
				TeleportEntity(clientIdx, MI_LastValidOrigin[clientIdx], NULL_VECTOR, Float:{0.0,0.0,0.0});
				
				// wasd just got pressed
				if (MI_WASDDownSince[clientIdx] == FAR_FUTURE)
				{
					MI_WASDDownSince[clientIdx] = curTime;
					if (strlen(RRA_WASDSound) > 3)
						EmitSoundToClient(clientIdx, RRA_WASDSound);
				}
					
				// don't let holding WASD be a good thing. start damaging the rock for trying to abuse it.
				if (curTime >= (MI_WASDDownSince[clientIdx] + WASD_DAMAGE_BEGIN_DELAY) - MI_AccumulatedWASD[clientIdx])
					SDKHooks_TakeDamage(clientIdx, clientIdx, clientIdx, MI_WASDDamage[clientIdx], DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
					
				// display the WASD hud message
				if (curTime >= MI_NextWASDHudAt[clientIdx])
				{
					SetHudTextParams(-1.0, WASD_HUD_POSITION, WASD_HUD_INTERVAL + 0.05, 255, 64, 64, 192);
					ShowHudText(clientIdx, -1, RRA_WASDMessage);
					MI_NextWASDHudAt[clientIdx] = curTime + WASD_HUD_INTERVAL;
				}

				return Plugin_Changed;
			}
			
			// other stuff related to WASD management
			if (MI_WASDDownSince[clientIdx] != FAR_FUTURE)
			{
				MI_AccumulatedWASD[clientIdx] += curTime - MI_WASDDownSince[clientIdx];
				MI_WASDDownSince[clientIdx] = FAR_FUTURE;
			}
			GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", MI_LastValidOrigin[clientIdx]);

			// push the player if it's time to do so
			if (curTime >= MI_PushAt[clientIdx])
			{
				// figure out the actual time delta
				new Float:deltaTime = (curTime - MI_PushAt[clientIdx]) + RR_PUSH_INTERVAL;
				new Float:maxAngleDifference = deltaTime * MI_TurnSpeed[clientIdx];
				//PrintToServer("maxAngleDifference = %f ... turnspeed=%f", maxAngleDifference, MI_TurnSpeed[clientIdx]);
				
				// ensure the push angle doesn't exceed the maximum
				static Float:eyeAngles[3];
				GetClientEyeAngles(clientIdx, eyeAngles);
				eyeAngles[0] = 0.0; // 2015-03-23, toss out pitch, so the rocks can't throttle
				new bool:angleDecreased = MI_PreviousYaw[clientIdx] > eyeAngles[1];
				new Float:angleDifference = fabs(MI_PreviousYaw[clientIdx] - eyeAngles[1]);
				new bool:forceReangle = false; // only used by TeleportEntity, it'd be jarring to always change angles with that
				if (angleDifference > 180.0)
				{
					angleDifference = 360.0 - angleDifference;
					angleDecreased = !angleDecreased;
				}
				
				// force reangle if necessary
				if (angleDifference > maxAngleDifference)
				{
					// on second thought, a force reangle could be very jarring...especially at this frequency
					//forceReangle = true;
					if (angleDecreased)
						eyeAngles[1] = fixAngle(MI_PreviousYaw[clientIdx] - maxAngleDifference);
					else
						eyeAngles[1] = fixAngle(MI_PreviousYaw[clientIdx] + maxAngleDifference);
				}
			
				// get push velocity
				static Float:pushVel[3];
				static Float:curVel[3];

				GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", curVel);
				GetAngleVectors(eyeAngles, pushVel, NULL_VECTOR, NULL_VECTOR);
				ScaleVector(pushVel, MI_MoveSpeed[clientIdx] * (((GetEntityFlags(clientIdx) & FL_ONGROUND) != 0) ? 2.0 : 1.0));
				pushVel[2] = curVel[2];

				// push them and optionally force their eye angles
				TeleportEntity(clientIdx, NULL_VECTOR, forceReangle ? eyeAngles : NULL_VECTOR, pushVel);
				
				// schedule next push
				MI_PushAt[clientIdx] = curTime + RR_PUSH_INTERVAL;
				MI_PreviousYaw[clientIdx] = eyeAngles[1];
			}
		}
		else if (RRVI_IsStunned[clientIdx] && (RRVI_StunnedUntil[clientIdx] <= curTime))
		{
			if (IsLivingPlayer(clientIdx))
			{
				if (PRINT_DEBUG_SPAM)
					PrintToServer("[sarysamods4] Unstunning %d", clientIdx);
				TF2_RemoveCondition(clientIdx, TFCond_Dazed);
				RRVI_IsStunned[clientIdx] = false;
			}
		}
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Rage_RollingRocks(const String:ability_name[], bossIdx)
{
	// classic parameters for rage_clone_attack
	new clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	new String:modelName[MAX_MODEL_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, 1, modelName, MAX_MODEL_FILE_LENGTH);
	new classIdx = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 2);
	new Float:ratio = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 3);
	new String:weaponName[MAX_ENTITY_CLASSNAME_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, 4, weaponName, MAX_ENTITY_CLASSNAME_LENGTH);
	new weaponIdx = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 5);
	new String:attributes[MAX_WEAPON_ARG_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, 6, attributes, MAX_WEAPON_ARG_LENGTH);
	
	// parameters specific to rage_rolling_rocks
	new String:rangeStr[MAX_RANGE_STRING_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, 7, rangeStr, MAX_RANGE_STRING_LENGTH);
	new Float:minTurnSpeed;
	new Float:maxTurnSpeed;
	ParseFloatRange(rangeStr, minTurnSpeed, maxTurnSpeed);
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, 8, rangeStr, MAX_RANGE_STRING_LENGTH);
	new Float:minSpeed;
	new Float:maxSpeed;
	ParseFloatRange(rangeStr, minSpeed, maxSpeed);
	new Float:damageOnTouch = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 9);
	new stunTypeOnTouch = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 10);
	new Float:stunDuration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 11);
	new Float:knockbackIntensityModifier = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 12);
	new Float:immunityDuration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 13);
	new String:hullStr[MAX_HULL_STRING_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, 14, hullStr, MAX_HULL_STRING_LENGTH);
	new Float:hull[2][3];
	ParseHull(hullStr, hull);
	new Float:maxIncomingDamage = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 15);
	new maxHealth = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 16);
	new Float:rockDamageStartDelay = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 17);
	new Float:wasdDamage = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 18);
	new rockFlags = ReadHexOrDecString(bossIdx, ability_name, 19);
	
	// an aesthetic that only happens at spawn time
	new String:centerText[MAX_CENTER_TEXT_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RRA_STRING, 6, centerText, MAX_CENTER_TEXT_LENGTH);

	new Float:bossOrigin[3];
	new Float:velocity[3];
	GetEntPropVector(clientIdx, Prop_Data, "m_vecOrigin", bossOrigin);

	new alive = 0;
	new dead = 0;
	new Handle:players = CreateArray();
	for (new target = 1; target < MAX_PLAYERS; target++)
	{
		if (IsClientInGame(target))
		{
			new team = GetClientTeam(target);
			if (team > _:TFTeam_Spectator)
			{
				if (IsPlayerAlive(target) && team != BossTeam)
				{
					alive++;
				}
				else if (!IsPlayerAlive(target))
				{
					PushArrayCell(players, target);
					dead++;
				}
			}
			else if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods4] Skipping player %d because they're on spectator.", target);
		}
	}

	new totalMinions = RoundToCeil(alive * ratio);
	
	if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods4] Client %d executing %s, with up to %d minions, %d valid dead players.", clientIdx, RR_STRING, totalMinions, dead);
	
	if (ratio == 0.0)
	{
		totalMinions = alive;
	}
	new clone, temp;
	for (new i = 0; i < dead && i < totalMinions; i++)
	{
		// find a random player and store their class
		temp = GetRandomInt(0, GetArraySize(players) - 1);
		clone = GetArrayCell(players, temp);
		RemoveFromArray(players, temp);
		if (TF2_GetPlayerClass(clone) != TFClassType:classIdx)
			MI_LastClass[clone] = TF2_GetPlayerClass(clone);

		// respawn them as a blu
		FF2_SetFF2flags(clone, FF2_GetFF2flags(clone) | FF2FLAG_ALLOWSPAWNINBOSSTEAM);
		ChangeClientTeam(clone, BossTeam);
		TF2_RespawnPlayer(clone);
		TF2_SetPlayerClass(clone, TFClassType:classIdx);

		// change their model
		if (strlen(modelName) > 3)
		{
			SetVariantString(modelName);
			AcceptEntityInput(clone, "SetCustomModel");
			SetEntProp(clone, Prop_Send, "m_bUseClassAnimations", 1);
		}
		
		// tweak their weapon
		new weapon;
		TF2_RemoveAllWeapons(clone);
		new String:tweakedAttributes[MAX_WEAPON_ARG_LENGTH + 40];
		new Float:moveSpeed = GetRandomFloat(minSpeed, maxSpeed);
		new Float:moveSpeedModifier = GetMoveSpeedModifier(moveSpeed, TFClassType:classIdx);
		if (moveSpeedModifier == 1.0) // will almost never happen...
			Format(tweakedAttributes, sizeof(tweakedAttributes), "%s", attributes);
		else
		{
			new attr1 = moveSpeedModifier > 1.0 ? 107 : 54;
			if (strlen(attributes) < 3)
				Format(tweakedAttributes, sizeof(tweakedAttributes), "%d ; %f", attr1, moveSpeedModifier);
			else
				Format(tweakedAttributes, sizeof(tweakedAttributes), "%s ; %d ; %f", attributes, attr1, moveSpeedModifier);
		}
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods4] Clone %d will be created, class %d weaponName=%s weaponIdx=%d weaponAtt=%s", clone, classIdx, weaponName, weaponIdx, tweakedAttributes);
		weapon = SpawnWeapon(clone, weaponName, weaponIdx, 101, 5, tweakedAttributes);
		if(IsValidEdict(weapon))
		{
			SetEntPropEnt(clone, Prop_Send, "m_hActiveWeapon", weapon);
			SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", -1);
		}
		
		velocity[0] = GetRandomFloat(300.0, 500.0) * (GetRandomInt(0, 1) ? 1 : -1);
		velocity[1] = GetRandomFloat(300.0, 500.0) * (GetRandomInt(0, 1) ? 1 : -1);
		velocity[2] = GetRandomFloat(300.0, 500.0);
		new Float:startingYaw = GetRandomFloat(-179.9, 179.9);
		new Float:teleportAngle[3];
		teleportAngle[0] = 0.0;
		teleportAngle[1] = startingYaw;
		teleportAngle[2] = 0.0;
		TeleportEntity(clone, bossOrigin, teleportAngle, velocity);

		SetEntProp(clone, Prop_Data, "m_takedamage", 0);
		MI_EnableDamageAt[clone] = GetEngineTime() + rockDamageStartDelay;

		strcopy(RR_ModelName, MAX_MODEL_FILE_LENGTH, modelName);
		MI_EquipModelAt[clone] = GetEngineTime() + 0.5;
		MI_EquipModelRetries[clone] = 2;
		MI_FixTauntCamAt[clone] = GetEngineTime() + 0.5;
		
		// initialize the data we'll be following for this player
		MI_IsMonitoredClone[clone] = true;
		for (new j = 1; j < MAX_PLAYERS; j++)
			MI_ImmuneUntil[clone][j] = 0.0;
		MI_OwnerUserId[clone] = GetClientUserId(clientIdx);
		MI_ExpectedClass[clone] = TFClassType:classIdx;
		MI_MoveSpeed[clone] = moveSpeed;
		MI_TurnSpeed[clone] = GetRandomFloat(minTurnSpeed, maxTurnSpeed);
		MI_DamageOnTouch[clone] = damageOnTouch;
		MI_StunType[clone] = stunTypeOnTouch;
		MI_StunDuration[clone] = stunDuration;
		MI_KnockbackIntensity[clone] = knockbackIntensityModifier;
		MI_ImmunityDuration[clone] = immunityDuration;
		for (new j = 0; j <= 1; j++)
			for (new k = 0; k <= 2; k++)
				MI_HitDetectionHull[clone][j][k] = hull[j][k];
		MI_MaxIncomingDamage[clone] = maxIncomingDamage;
		MI_RockFlags[clone] = rockFlags;
		MI_RockNoDamageUntil[clone] = GetEngineTime() + rockDamageStartDelay;
		MI_NextRollingSoundAt[clone] = 0.0; // will play rolling sound the moment they hit the ground
		MI_WasOnGroundLastTick[clone] = true; // they won't be, but don't want a landing sound to play on spawn when not desired
		MI_LastSwamAt[clone] = 0.0;
		MI_PushAt[clone] = GetEngineTime();
		MI_PreviousYaw[clone] = startingYaw;
		MI_LastValidOrigin[clone][0] = bossOrigin[0];
		MI_LastValidOrigin[clone][1] = bossOrigin[1];
		MI_LastValidOrigin[clone][2] = bossOrigin[2];
		MI_WASDDownSince[clone] = FAR_FUTURE;
		MI_AccumulatedWASD[clone] = 0.0;
		MI_NextWASDHudAt[clone] = 0.0;
		MI_WASDDamage[clone] = wasdDamage;
		MI_RenewThirdPersonAt[clone] = GetEngineTime() + MI_TP_INTERVAL;
		
		// heal the clone
		SetEntProp(clone, Prop_Data, "m_iHealth", maxHealth);
		SetEntProp(clone, Prop_Send, "m_iHealth", maxHealth);

		// register listeners
		RR_RegisterUserSpecificListeners(clone);
		
		// center text tells user that they are a rock
		if (!IsEmptyString(centerText))
			PrintCenterText(clone, centerText);
			
		// tweak their gravity due to issues with lifts
		SetEntityGravity(clone, 0.70);
	}
	CloseHandle(players);

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

/**
 * Glide
 */
public Action:GLIDE_OnPlayerRunCmd(clientIdx, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	// glide
	if (GLIDE_ActiveThisRound && GLIDE_CanUse[clientIdx])
	{
		new bool:spaceBarIsDown = (buttons & IN_JUMP) != 0;
		new bool:onGround = (GetEntityFlags(clientIdx) & FL_ONGROUND) != 0;
		
		// stop using if user releases key, if user is on ground, if user's rage ended and it's a rage-only ability, or if it's passed the max duration
		if (GLIDE_IsUsing[clientIdx] && ((GLIDE_SpaceBarWasDown[clientIdx] && !spaceBarIsDown) || (onGround) || (GetEngineTime() >= GLIDE_UsableUntil[clientIdx]) || (GLIDE_SingleUseStartTime[clientIdx] + GLIDE_MaxDuration[clientIdx] <= GetEngineTime())))
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods4] Glide stopped for %d", clientIdx);
			
			// stop gliding
			GLIDE_IsUsing[clientIdx] = false;
			
			// cooldown info needed
			GLIDE_SingleUseEndTime[clientIdx] = GetEngineTime();
		}
		else if (!GLIDE_IsUsing[clientIdx] && !GLIDE_SpaceBarWasDown[clientIdx] && spaceBarIsDown && !onGround)
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods4] Glide may start for %d (if cooldown/rage check passes)", clientIdx);
			
			// but first check cooldown and if user is in a rage if such is required
			if (GLIDE_SingleUseEndTime[clientIdx] + GLIDE_Cooldown[clientIdx] <= GetEngineTime() && GetEngineTime() < GLIDE_UsableUntil[clientIdx])
			{
				if (PRINT_DEBUG_SPAM)
					PrintToServer("[sarysamods4] Glide started for %d", clientIdx);

				// start gliding
				GLIDE_IsUsing[clientIdx] = true;
				GLIDE_SingleUseStartTime[clientIdx] = GetEngineTime();
				
				// play sound
				if (strlen(GLIDE_UseSound) > 3)
					PlaySoundLocal(clientIdx, GLIDE_UseSound, true, 3);
			}
		}
		
		// slow the player
		if (GLIDE_IsUsing[clientIdx])
		{
			//if (PRINT_DEBUG_SPAM)
			//	PrintToServer("[sarysamods4] %d is gliding.", clientIdx);
				
			new Float:currentVelocityLimit = -(GLIDE_OriginalMaxVelocity[clientIdx] + ((GetEngineTime() - GLIDE_SingleUseStartTime[clientIdx]) * GLIDE_DecayPerSecond[clientIdx]));
		
			new Float:vecVelocity[3];
			GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", vecVelocity);
			if (vecVelocity[2] < currentVelocityLimit)
				vecVelocity[2] = currentVelocityLimit;
			SetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", vecVelocity);
			TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, vecVelocity);
		}
		
		GLIDE_SpaceBarWasDown[clientIdx] = spaceBarIsDown;
	}
	
	return Plugin_Continue;
}

public Rage_Glide(const String:ability_name[], bossIdx)
{
	new clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	if (GLIDE_RageOnly[clientIdx])
		GLIDE_UsableUntil[clientIdx] = GetEngineTime() + FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 2);
}

/**
 * Improved Stun
 */
#define IMMUNE_NEVER 0
#define IMMUNE_UBER 1
#define IMMUNE_ALWAYS 2
public IS_Tick(clientIdx, Float:curTime)
{
	if (IS_IsStunned[clientIdx] && IS_StunnedUntil[clientIdx] <= GetEngineTime())
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[sarysamods4] Unstunning %d", clientIdx);
			
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed))
			TF2_RemoveCondition(clientIdx, TFCond_Dazed);
		IS_IsStunned[clientIdx] = false;
		
		if (IS_ParticleEntRef[clientIdx] != 0)
		{
			new particle = EntRefToEntIndex(IS_ParticleEntRef[clientIdx]);
			if (IsValidEntity(particle))
				RemoveEntity(IS_ParticleEntRef[clientIdx]);
			IS_ParticleEntRef[clientIdx] = 0;
		}
		
		new Float:speed = GetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed");
		if (speed == IS_ExpectedSpeed[clientIdx] && IS_SpeedModifier[clientIdx] != 1.0)
			SetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed", speed / IS_SpeedModifier[clientIdx]);
	}
	else if (IS_IsStunned[clientIdx])
	{
		new Float:speed = GetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed");
		if (speed != IS_ExpectedSpeed[clientIdx])
		{
			speed *= IS_SpeedModifier[clientIdx];
			SetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed", speed);
			IS_ExpectedSpeed[clientIdx] = speed;
		}
	}
}

public Rage_ImprovedStun(const String:ability_name[], bossIdx)
{
	new clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	new Float:duration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 1);
	new Float:radius = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 2);
	new bool:isHardStun = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 3) == 1;
	new Float:slowdown = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 4);
	new bool:playDefaultStunSound = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 5) == 1;
	new String:particleEffect[MAX_EFFECT_NAME_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, 6, particleEffect, MAX_EFFECT_NAME_LENGTH);
	new medigunUserImmune = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 7);
	new medigunPartnerImmune = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 8);
	new quickFixUserImmune = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 9);
	new quickFixPartnerImmune = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 10);
	new vaccinatorUserImmune = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 11);
	new vaccinatorPartnerImmune = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 12);
	new String:flagOverrideStr[HEX_OR_DEC_STRING_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, 13, flagOverrideStr, HEX_OR_DEC_STRING_LENGTH);
	new flagOverride = ReadHexOrDecInt(flagOverrideStr);
	new Float:speedFactor = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 14);
	if (speedFactor <= 0.0)
		speedFactor = 1.0;

	new stunFlags = isHardStun ? TF_STUNFLAG_BONKSTUCK : TF_STUNFLAGS_SMALLBONK;
	if (!playDefaultStunSound)
		stunFlags |= TF_STUNFLAG_NOSOUNDOREFFECT;
	if (flagOverride != 0)
		stunFlags = flagOverride;
	
	new Float:bossOrigin[3];
	new Float:victimOrigin[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
	
	static bool:isImmune[MAX_PLAYERS_ARRAY];
	for (new victim = 1; victim < MAX_PLAYERS; victim++) // initialize
		isImmune[victim] = false;
		
	// iterate through the list to see if targets are valid for stun
	for (new victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (isImmune[victim])
			continue; // this player has already been determined due to their link to a medic

		if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
			continue;
			
		// can't determine if the user isn't equipping a medigun
		new weapon = GetPlayerWeaponSlot(victim, TFWeaponSlot_Secondary);
		if (IsValidEntity(weapon))
		{
			static String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
			GetEntityClassname(weapon, classname, sizeof(classname));
			if (!strcmp(classname, "tf_weapon_medigun"))
			{
				new itemIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
				new bool:ubering = (GetEntProp(weapon, Prop_Send, "m_bChargeRelease") & 0x1) == 1;
				new partner = GetEntProp(weapon, Prop_Send, "m_hHealingTarget") & 0x3ff;
				
				new userImmune = medigunUserImmune;
				new partnerImmune = medigunPartnerImmune;
				
				if (itemIndex == 998) // vaccinator
				{
					userImmune = vaccinatorUserImmune;
					partnerImmune = vaccinatorPartnerImmune;
				}
				else if (itemIndex == 411) // quick fix
				{
					userImmune = quickFixUserImmune;
					partnerImmune = quickFixPartnerImmune;
				}

				if (ubering)
				{
					isImmune[victim] = userImmune >= IMMUNE_UBER;
					if (IsValidEntity(partner) && !isImmune[partner]) // don't override existing immunity (i.e. medic healing ubered medic)
						isImmune[partner] = partnerImmune >= IMMUNE_UBER;
				}
				else
				{
					isImmune[victim] = userImmune == IMMUNE_ALWAYS;
					if (IsValidEntity(partner) && !isImmune[partner]) // don't override existing immunity (i.e. medic healing ubered medic)
						isImmune[partner] = partnerImmune == IMMUNE_ALWAYS;
				}
			}
		}
	}
	
	// now stun valid targets
	for (new victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (isImmune[victim])
			continue;
			
		if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
			continue;
	
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimOrigin);
		if (GetVectorDistance(bossOrigin, victimOrigin) <= radius)
		{
			if (PRINT_DEBUG_SPAM)
			{
				PrintToServer("[sarysamods4] Stunning %d, %f,%f,%f <==> %f,%f,%f = %f", victim,
						bossOrigin[0], bossOrigin[1], bossOrigin[2], 
						victimOrigin[0], victimOrigin[1], victimOrigin[2], GetVectorDistance(bossOrigin, victimOrigin));
			}
					
			// the actual stun
			if (IS_IsStunned[victim]) // refresh if already stunned
				IS_StunnedUntil[victim] = GetEngineTime() + duration;
			else
			{
				TF2_StunPlayer(victim, 99999.0, slowdown, stunFlags, clientIdx);
				IS_IsStunned[victim] = true;
				IS_StunnedUntil[victim] = GetEngineTime() + duration;
				
				// particle
				if (!IsEmptyString(particleEffect))
				{
					if (IS_ParticleEntRef[victim] == 0)
					{
						new particle = AttachParticle(victim, particleEffect, 70.0, true);
						if (IsValidEntity(particle))
							IS_ParticleEntRef[victim] = EntIndexToEntRef(particle);
					}
				}
				
				// optional speed modifier
				IS_SpeedModifier[victim] = speedFactor;
				if (speedFactor != 1.0)
					IS_ExpectedSpeed[victim] = 0.0;
			}
		}
		else if (PRINT_DEBUG_SPAM)
		{
			PrintToServer("[sarysamods4] Not stunning %d, %f,%f,%f <==> %f,%f,%f = %f", victim,
						bossOrigin[0], bossOrigin[1], bossOrigin[2], 
						victimOrigin[0], victimOrigin[1], victimOrigin[2], GetVectorDistance(bossOrigin, victimOrigin));
		}
	}
}

/**
 * Meteor Shower
 */
public MS_FreezeIfValid(clientIdx)
{
	if (!MSVI_FreezeEntitySettled[clientIdx] && MSVI_FrozenEntRef[clientIdx] != 0)
	{
		new entity = EntRefToEntIndex(MSVI_FrozenEntRef[clientIdx]);
		if (IsValidEntity(entity))
		{
			new Float:origin[3];
			GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", origin);
			SetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
		}
	}
	
	if (GetEntityFlags(clientIdx) & FL_ONGROUND)
	{
		SetEntityMoveType(clientIdx, MOVETYPE_NONE);
		MSVI_FreezeEntitySettled[clientIdx] = true;
	}
	else
		MSVI_FreezeEntitySettled[clientIdx] = false;
}
 
public MS_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (victim <= 0 || victim >= MAX_PLAYERS)
		return;
		
	if (MSVI_FrozenEntRef[victim] != 0)
	{
		new entity = EntRefToEntIndex(MSVI_FrozenEntRef[victim]);
		if (IsValidEntity(entity))
			RemoveEntity(entity);
		MSVI_FrozenEntRef[victim] = 0;
	}
}

public MS_RegisterListeners()
{
	HookEvent("player_spawn", Event_PlayerSpawnMS, EventHookMode_Post);
	HookEvent("player_death", MS_PlayerDeath);
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (IsLivingPlayer(clientIdx) && GetClientTeam(clientIdx) != BossTeam)
		{
			SDKHook(clientIdx, SDKHook_OnTakeDamage, OnTakeDamageMS);
			//SDKHook(clientIdx, SDKHook_OnTakeDamagePost, OnTakeDamagePostMS);
		}
	}
}

public MS_UnregisterListeners()
{
	UnhookEvent("player_spawn", Event_PlayerSpawnMS, EventHookMode_Post);
	UnhookEvent("player_death", MS_PlayerDeath);
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (IsLivingPlayer(clientIdx) && GetClientTeam(clientIdx) != BossTeam)
		{
			SDKUnhook(clientIdx, SDKHook_OnTakeDamage, OnTakeDamageMS);
			//SDKUnhook(clientIdx, SDKHook_OnTakeDamagePost, OnTakeDamagePostMS);
		}
	}
}

MS_RemoveAllAilments(clientIdx)
{
	if (!IsLivingPlayer(clientIdx) || MSVI_Attacker[clientIdx] <= 0)
		return;
		
	if (PRINT_DEBUG_SPAM)
		PrintToServer("[sarysamods4] MS_RemoveAllAilments(%d)", clientIdx);
		
	if (MSVI_BleedingUntil[clientIdx] > 0.0)
	{
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_Bleeding))
			TF2_RemoveCondition(clientIdx, TFCond_Bleeding);
		MSVI_BleedingUntil[clientIdx] = 0.0;
	}
	if (MSVI_OnFireUntil[clientIdx] > 0.0)
	{
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_OnFire))
			TF2_RemoveCondition(clientIdx, TFCond_OnFire);
		MSVI_OnFireUntil[clientIdx] = 0.0;
	}
	if (MSVI_FrozenUntil[clientIdx] > 0.0)
	{
		SetEntityMoveType(clientIdx, MOVETYPE_WALK);
		if (MSVI_FrozenEntRef[clientIdx] != 0)
		{
			new entity = EntRefToEntIndex(MSVI_FrozenEntRef[clientIdx]);
			if (IsValidEntity(entity))
				RemoveEntity(entity);
		}
		MSVI_FrozenEntRef[clientIdx] = 0;
		MSVI_FrozenUntil[clientIdx] = 0.0;
	}
	if (MSVI_SlowUntil[clientIdx] > 0.0)
	{
		MSVI_SlowUntil[clientIdx] = 0.0;
		
		new Float:maxSpeed = GetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed");
		if (maxSpeed == MSVI_ExpectedSlowSpeed[clientIdx])
			SetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed", maxSpeed / MS_EffectIntensity[MSVI_Attacker[clientIdx]]);
	}
	
	MSVI_Attacker[clientIdx] = -1;
}

public Action:OnTakeDamageMS(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (!MS_ActiveThisRound) // it seems to have leaked
		return Plugin_Continue;
	if (!IsValidEntity(inflictor) || !IsLivingPlayer(victim))
		return Plugin_Continue;
	if (GetClientTeam(victim) == BossTeam) // there is boss self-damage, but I guess it's blocked by the FF2 plugin
		return Plugin_Continue;
		
	// all this is moot if the victim is ubercharged
	if (TF2_IsPlayerInCondition(victim, TFCond_MegaHeal) || TF2_IsPlayerInCondition(victim, TFCond_Ubercharged))
		return Plugin_Continue;
		
	new Float:curTime = GetEngineTime();

	// detecting the initial effect-triggering explosion requires the attacker to be a living player
	// so do certain cancel cases like explosion and melee damage (which is a two-bit lazy check)
	if (IsLivingPlayer(attacker))
	{
		new String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
		GetEntityClassname(inflictor, classname, sizeof(classname));
	
		if (!strcmp(classname, "tf_projectile_rocket") && GetClientTeam(attacker) == BossTeam)
		{
			new bool:secondaryEffect = false;

			if ((MS_EffectFlags[attacker] & MS_EFFECT_BLEED) != 0)
			{
				if (TF2_GetPlayerClass(victim) != TFClass_Spy)
				{
					TF2_MakeBleed(victim, attacker, MS_BLEED_DURATION);
					MSVI_RefreshBleedAt[victim] = curTime + MS_BLEED_REFRESH_INTERVAL;
				}
				//TF2_AddCondition(victim, TFCond_Bleeding, -1.0);
				MSVI_BleedingUntil[victim] = curTime + MS_EffectDuration[attacker];
				secondaryEffect = true;
			}
			if ((MS_EffectFlags[attacker] & MS_EFFECT_IGNITE) != 0)
			{
				if (TF2_GetPlayerClass(victim) != TFClass_Spy)
					TF2_IgnitePlayer(victim, attacker);
				//TF2_AddCondition(victim, TFCond_OnFire, -1.0);
				MSVI_OnFireUntil[victim] = curTime + MS_EffectDuration[attacker];
				secondaryEffect = true;
			}
			if ((MS_EffectFlags[attacker] & MS_EFFECT_FREEZE) != 0)
			{
				MS_FreezeIfValid(victim);
				SetEntProp(victim, Prop_Send, "m_iAirDash", 30); // use up their air jumps, even if they're soda popper
				MSVI_FrozenUntil[victim] = curTime + MS_EffectDuration[attacker];
				MSVI_EscapeMask[victim] = (GetClientButtons(victim) & MS_ESCAPE_MASK);
				MSVI_EscapeButtonMashesRemaining[victim] = MS_EscapeButtonMashCount[attacker];
				if (strlen(MS_EffectModel[attacker]) > 3 && MSVI_FrozenEntRef[victim] == 0)
				{
					new effect = CreateEntityByName("prop_physics_override");
					if (IsValidEntity(effect))
					{
						if (PRINT_DEBUG_SPAM)
							PrintToServer("[sarysamods4] Created freeze entity %d", effect);
					
						new Float:victimOrigin[3];
						GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimOrigin);
						SetEntityModel(effect, MS_EffectModel[attacker]);
						DispatchSpawn(effect);
						TeleportEntity(effect, victimOrigin, NULL_VECTOR, NULL_VECTOR);
						MSVI_FrozenEntRef[victim] = EntRefToEntIndex(effect);
						
						SetEntityMoveType(effect, MOVETYPE_NONE);
						SetEntProp(effect, Prop_Data, "m_takedamage", 2); // looks familiar.
						SetEntProp(effect, Prop_Send, "m_CollisionGroup", 0);
						SetEntProp(effect, Prop_Send, "m_usSolidFlags", 2);
						SetEntProp(effect, Prop_Send, "m_nSolidType", 6);
						SetEntProp(effect, Prop_Data, "m_iMaxHealth", MS_EffectHealth[attacker]);
						SetEntProp(effect, Prop_Data, "m_iHealth", MS_EffectHealth[attacker]);
						
						if (PRINT_DEBUG_SPAM)
							PrintToServer("[sarysamods4] Gave freeze prop health of %d", MS_EffectHealth[attacker]);
						
						//AcceptEntityInput(effect, "SetParent", effect, effect, 0);
						//SetEntPropEnt(effect, Prop_Send, "m_hOwnerEntity", victim);

						SetEntityRenderMode(effect, RENDER_TRANSCOLOR);
						SetEntityRenderColor(effect, 255, 255, 255, RoundFloat(255.0 * MS_EffectOpacity[attacker]));
					}
					else if (PRINT_DEBUG_INFO)
						PrintToServer("[sarysamods4] Failed to create freeze entity.");

				}
				secondaryEffect = true;
			}
			if ((MS_EffectFlags[attacker] & MS_EFFECT_SLOW) != 0)
			{
				//TF2_AddCondition(victim, TFCond_Slowed, -1.0); // does not work anymore, not even as the addcond cheat
				MSVI_SlowUntil[victim] = curTime + MS_EffectDuration[attacker];
				secondaryEffect = true;
			}

			if (secondaryEffect)
			{
				MSVI_Attacker[victim] = attacker;
				MSVI_EffectStartTime[victim] = curTime;
			}
		}
		
		if (attacker == inflictor && (damagetype & DMG_CLUB) && MSVI_Attacker[victim] > 0 && GetClientTeam(attacker) == BossTeam)
			if ((MS_EffectFlags[MSVI_Attacker[victim]] & MS_EFFECT_MELEE_DAMAGE_CANCEL) != 0)
				MS_RemoveAllAilments(victim);

		if ((damagetype & DMG_BLAST) && MSVI_Attacker[victim] > 0 && GetClientTeam(attacker) == MercTeam)
			if ((MS_EffectFlags[MSVI_Attacker[victim]] & MS_EFFECT_EXPLOSION_CANCEL) != 0)
				MS_RemoveAllAilments(victim);
	}
	
	// fire cancel does not require the attacker to be a player entity
	if (((damagetype & DMG_BURN) || damagecustom == TF_CUSTOM_FLARE_EXPLOSION) && MSVI_Attacker[victim] > 0)
		if ((MS_EffectFlags[MSVI_Attacker[victim]] & MS_EFFECT_FIRE_CANCEL) != 0)
			MS_RemoveAllAilments(victim);
			
	return Plugin_Continue;
}

public Action:Event_PlayerSpawnMS(Handle:event, const String:name[], bool:dontBroadcast)
{
	new clientIdx = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsLivingPlayer(clientIdx) && GetClientTeam(clientIdx) != BossTeam)
	{
		SDKHook(clientIdx, SDKHook_OnTakeDamage, OnTakeDamageMS);
		//SDKHook(clientIdx, SDKHook_OnTakeDamagePost, OnTakeDamagePostMS);
	}
}

public Action:RemoveRocket(Handle:timer, any:entRef)
{
	new entity = EntRefToEntIndex(entRef);
	if (IsValidEntity(entity))
	{
		new clientIdx = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if (IsLivingPlayer(clientIdx))
			MS_EOLCount[clientIdx]++;
		AcceptEntityInput(entity, "kill");
	}
}

public SpawnMeteor(clientIdx)
{
	// get the modified position of the player, for our ray traces
	new Float:bossOrigin[3];
	new Float:bossRayOrigin[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
	bossRayOrigin[0] = bossOrigin[0];
	bossRayOrigin[1] = bossOrigin[1];
	bossRayOrigin[2] = bossOrigin[2] + 41.5;
	
	// create our rocket. no matter what, it's going to spawn, even if it ends up being out of map
	new Float:speed = 1100.0 * MS_SpeedFactor[clientIdx];
	new Float:damage = fixDamageForFF2(MS_Damage[clientIdx]);
	new String:classname[MAX_ENTITY_CLASSNAME_LENGTH] = "CTFProjectile_Rocket";
	new String:entname[MAX_ENTITY_CLASSNAME_LENGTH] = "tf_projectile_rocket";
	new rocket = CreateEntityByName(entname);
	if (!IsValidEntity(rocket))
	{
		PrintToServer("[sarysamods4] Error: Invalid entity %s. Won't spawn rocket.", entname);
		return;
	}
	
	// make a whole bunch of attempts at finding a good spawn position
	new Float:spawnPosition[3];
	new Float:traceEndPosition[3];
	new Float:traceAngles[3];
	new Handle:trace;
	new Float:minDistance;
	new Float:traceDistance;
	new bool:foundValidPoint = false;
	new locationAttempts = (MS_EffectFlags[clientIdx] & MS_FLAG_IGNORE_WALL_TEST) ? 1 : MS_LOCATION_ATTEMPTS;
	for (new i = 0; i < locationAttempts; i++)
	{
		traceAngles[1] = GetRandomFloat(-179.9, 179.9);
		minDistance = GetRandomFloat(0.0, MS_SpawnRadius[clientIdx]);
		for (new j = 0; j < 3; j++)
		{
			traceAngles[0] = j == 0 ? 0.0 : (j == 1 ? MS_TEST_DEVIATION_ANGLE : -MS_TEST_DEVIATION_ANGLE);
			
			trace = TR_TraceRayFilterEx(bossRayOrigin, traceAngles, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
			TR_GetEndPosition(traceEndPosition, trace);
			CloseHandle(trace);
			traceDistance = GetVectorDistance(bossRayOrigin, traceEndPosition);
			if (traceDistance >= minDistance)
			{
				foundValidPoint = true;
				ConformLineDistance(traceEndPosition, bossRayOrigin, traceEndPosition, minDistance);
			}
		}
		
		if (foundValidPoint)
			break;
		
		// push the point out so it goes beyond the map bounds
		// this way raging in a tight area won't just annihalate everything around
		if (i + 1 == locationAttempts)
			ConformLineDistance(traceEndPosition, bossRayOrigin, traceEndPosition, minDistance, true);
	}
	
	// statistics
	if (!foundValidPoint)
		MS_WallFailedCount[clientIdx]++;
	
	// even if we didn't find a valid point, we go with the last one and pray for rain
	// it's deliberately slightly higher than the player
	// now trace another ray to the ceiling and that's our spawn position, well Z-20 is anyway
	traceAngles[0] = -89.9;
	trace = TR_TraceRayFilterEx(traceEndPosition, traceAngles, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
	TR_GetEndPosition(spawnPosition, trace);
	CloseHandle(trace);
	spawnPosition[2] -= 20.0;
	
	// constrain the height, don't let it be so high that most snowflakes will run out of time on maps like vsh_barricade
	spawnPosition[2] = fmin(spawnPosition[2], bossOrigin[2] + MS_ROCKET_MAX_SPAWN_HEIGHT);
	
	// come up with random angles
	new Float:spawnAngles[3];
	spawnAngles[0] = GetRandomFloat(MS_Ang0Minimum[clientIdx], 89.9);
	spawnAngles[1] = GetRandomFloat(-179.9, 179.9);
	
	// determine velocity
	new Float:spawnVelocity[3];
	GetAngleVectors(spawnAngles, spawnVelocity, NULL_VECTOR, NULL_VECTOR);
	spawnVelocity[0] *= speed;
	spawnVelocity[1] *= speed;
	spawnVelocity[2] *= speed;
	
	// deploy!
	TeleportEntity(rocket, spawnPosition, spawnAngles, spawnVelocity);
	SetEntProp(rocket, Prop_Send, "m_bCritical", false); // no random crits
	SetEntDataFloat(rocket, FindSendPropOffs(classname, "m_iDeflected") + 4, damage, true); // credit to voogru
	SetEntProp(rocket, Prop_Send, "m_nSkin", 1); // set skin to blue team's
	SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", clientIdx);
	SetVariantInt(BossTeam);
	AcceptEntityInput(rocket, "TeamNum", -1, -1, 0);
	SetVariantInt(BossTeam);
	AcceptEntityInput(rocket, "SetTeam", -1, -1, 0); 
	DispatchSpawn(rocket);
	
	// to get stats from the user's melee weapon
	SetEntPropEnt(rocket, Prop_Send, "m_hOriginalLauncher", GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Melee));
	SetEntPropEnt(rocket, Prop_Send, "m_hLauncher", GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Melee));

	// must reskin after spawn
	new model = MS_ModelCount[clientIdx] == 0 ? 0 : MS_ModelIndices[clientIdx][GetRandomInt(0, MS_ModelCount[clientIdx] - 1)];
	SetEntProp(rocket, Prop_Send, "m_nModelIndex", model);
	
	// trail override
	if (!IsEmptyString(MS_TrailEffectOverride[clientIdx]))
	{
		new particle = AttachParticle(rocket, MS_TrailEffectOverride[clientIdx]);
		if (IsValidEntity(particle))
			CreateTimer(MS_ROCKET_LIFE, Timer_RemoveEntity, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
	}
	
	// statistics
	MS_TotalRoundSpawnCount[clientIdx]++;
	
	// destruction timer, a precaution
	CreateTimer(MS_ROCKET_LIFE, RemoveRocket, EntIndexToEntRef(rocket), TIMER_FLAG_NO_MAPCHANGE); // I'm deciding to allow this timer to stay. the alternative would be inefficient.
}

public MS_Tick(clientIdx, Float:curTime)
{
	if (MS_IsUsing[clientIdx])
	{
		if (MS_SpawnMeteorsUntil[clientIdx] <= curTime)
		{
			MS_IsUsing[clientIdx] = false;
			return;
		}

		// time since this instance of the rage began
		new Float:timeSinceStart = curTime - MS_StartTime[clientIdx];

		// how many should have been spawned by now?
		new expectedMeteorCount = RoundFloat(timeSinceStart * float(MS_MeteorsPerSecond[clientIdx]));

		// spawn meteors
		for (new i = MS_SpawnCount[clientIdx]; i < expectedMeteorCount; i++)
			SpawnMeteor(clientIdx);
		MS_TotalRoundSpawnCount[clientIdx] += expectedMeteorCount - MS_SpawnCount[clientIdx];
		MS_SpawnCount[clientIdx] = expectedMeteorCount;
	}
	else if (MSVI_Attacker[clientIdx] > 0) // is a victim
	{
		new attacker = MSVI_Attacker[clientIdx];
		if (!IsLivingPlayer(attacker))
		{
			MS_RemoveAllAilments(clientIdx);
			return;
		}

		// refresh bleeding if necessary
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_Bleeding) && MSVI_BleedingUntil[clientIdx] > curTime)
		{
			if (MSVI_RefreshBleedAt[clientIdx] <= curTime)
			{
				TF2_MakeBleed(clientIdx, attacker, MS_BLEED_DURATION);
				MSVI_RefreshBleedAt[clientIdx] = curTime + MS_BLEED_REFRESH_INTERVAL;
			}
		}

		// remove freeze if the freeze entity is gone
		if (MSVI_FrozenEntRef[clientIdx] != 0)
		{
			new freezeObject = EntRefToEntIndex(MSVI_FrozenEntRef[clientIdx]);
			if (!IsValidEntity(freezeObject))
			{
				SetEntityMoveType(clientIdx, MOVETYPE_WALK);
				MSVI_FrozenEntRef[clientIdx] = 0;
				MSVI_FrozenUntil[clientIdx] = 0.0;
			}
		}

		// refresh freeze if necessary
		if (MSVI_FrozenUntil[clientIdx] > curTime)
			MS_FreezeIfValid(clientIdx);

		// refresh slow if necessary
		if (MSVI_SlowUntil[clientIdx] > curTime)
		{
			new Float:maxSpeed = GetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed");
			if (maxSpeed != MSVI_ExpectedSlowSpeed[clientIdx])
			{
				MSVI_ExpectedSlowSpeed[clientIdx] = maxSpeed * MS_EffectIntensity[attacker];
				SetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed", MSVI_ExpectedSlowSpeed[clientIdx]);
			}
		}

		// water cancel
		if ((MS_EffectFlags[attacker] & MS_EFFECT_WATER_CANCEL) != 0)
			if ((GetEntityFlags(clientIdx) & REAL_FL_SWIM) != 0)
				MS_RemoveAllAilments(clientIdx);

		// time cancel
		if (MSVI_BleedingUntil[clientIdx] > 0.0 && MSVI_BleedingUntil[clientIdx] <= curTime)
			MS_RemoveAllAilments(clientIdx);
		else if (MSVI_OnFireUntil[clientIdx] > 0.0 && MSVI_OnFireUntil[clientIdx] <= curTime)
			MS_RemoveAllAilments(clientIdx);
		else if (MSVI_FrozenUntil[clientIdx] > 0.0 && MSVI_FrozenUntil[clientIdx] <= curTime)
			MS_RemoveAllAilments(clientIdx);
		else if (MSVI_SlowUntil[clientIdx] > 0.0 && MSVI_SlowUntil[clientIdx] <= curTime)
			MS_RemoveAllAilments(clientIdx);

		// uber cancel
		if ((MS_EffectFlags[attacker] & MS_EFFECT_UBER_CANCEL) != 0)
			if (TF2_IsPlayerInCondition(clientIdx, TFCond_MegaHeal) || TF2_IsPlayerInCondition(clientIdx, TFCond_Ubercharged))
				MS_RemoveAllAilments(clientIdx);

		// special medic time cancel
		if ((MS_EffectFlags[attacker] & MS_EFFECT_MEDIC_REDUCTION) != 0)
			if (TF2_GetPlayerClass(clientIdx) == TFClass_Medic && MSVI_EffectStartTime[clientIdx] + MS_EffectMedicDurationLimit[attacker] <= curTime)
				MS_RemoveAllAilments(clientIdx);
	}
}

public Action:MS_OnPlayerRunCmd(clientIdx, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (MSVI_Attacker[clientIdx] > 0 && MSVI_FrozenUntil[clientIdx] > 0.0 && MSVI_EscapeButtonMashesRemaining[clientIdx] > 0)
	{
		new escapeMask = (buttons & MS_ESCAPE_MASK);
		new escapeCount = 0;
		for (new i = 0; i < 32; i++)
			if ((escapeMask & (1<<i)) != 0 && (MSVI_EscapeMask[clientIdx] & (1<<i)) == 0)
				escapeCount++;
		
		MSVI_EscapeMask[clientIdx] = escapeMask;
		
		MSVI_EscapeButtonMashesRemaining[clientIdx] -= escapeCount;
		if (MSVI_EscapeButtonMashesRemaining[clientIdx] <= 0)
			MSVI_FrozenUntil[clientIdx] = GetEngineTime(); // queue unfreeze
		else if (escapeCount > 0)
		{
			static Float:punchVel[3];
			punchVel[0] = punchVel[1] = punchVel[2] = 25.0 * float(escapeCount);
			SetEntPropVector(clientIdx, Prop_Send, "m_vecPunchAngleVel", punchVel);
		}
	}
	
	return Plugin_Continue;
}

public Rage_MeteorShower(const String:ability_name[], bossIdx)
{
	// all this method does is trigger the beginning of the meteor shower
	new clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	new Float:duration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 1);
	MS_SpawnMeteorsUntil[clientIdx] = GetEngineTime() + duration;
	MS_IsUsing[clientIdx] = true;
	MS_SpawnCount[clientIdx] = 0;
	MS_StartTime[clientIdx] = GetEngineTime();
}

/**
 * DOT Disguise
 */
public bool:DOTDisguise(clientIdx)
{
	if (DD_DisguiseInProgress[clientIdx])
		return false;
		
	TF2_AddCondition(clientIdx, TFCond_Disguising, DD_DisguiseDuration[clientIdx], clientIdx);
	DD_ExecuteRageAt[clientIdx] = GetEngineTime() + DD_DisguiseDuration[clientIdx];
	DD_DisguiseInProgress[clientIdx] = true;
	return true;
}

public DD_Tick(clientIdx, Float:curTime)
{
	if (curTime >= DD_ExecuteRageAt[clientIdx])
	{
		DD_ExecuteRageAt[clientIdx] = FAR_FUTURE;
		DD_DisguiseInProgress[clientIdx] = false;

		new randomMerc = FindRandomPlayer(false);
		if (randomMerc == -1)
			return;

		// disguise boss
		TF2_DisguisePlayer(clientIdx, TFTeam_Red, TF2_GetPlayerClass(randomMerc), randomMerc);
	}
}

/**
 * Exploit Fixes
 */
public EF_Tick(clientIdx, Float:curTime)
{
	if (EF_UncloakGoombaFailTime[clientIdx] > 0.0 && TF2_IsPlayerInCondition(clientIdx, TFCond_Cloaked))
	{
		EF_LastCloakedAt[clientIdx] = curTime;
	}
	
	if (EF_BlockingTelegoomba[clientIdx])
	{
		// move back all the previous stored positions by 1
		for (new i = 0; i < EF_FRAME_HISTORY_SIZE - 1; i++)
		{
			EF_FrameTime[clientIdx][i] = EF_FrameTime[clientIdx][i+1];
			EF_FramePosition[clientIdx][i][0] = EF_FramePosition[clientIdx][i+1][0];
			EF_FramePosition[clientIdx][i][1] = EF_FramePosition[clientIdx][i+1][1];
			EF_FramePosition[clientIdx][i][2] = EF_FramePosition[clientIdx][i+1][2];
		}
		
		// store the current position and time as last in index
		EF_FrameTime[clientIdx][EF_FRAME_HISTORY_SIZE - 1] = GetEngineTime();
		GetEntPropVector(clientIdx, Prop_Data, "m_vecOrigin", EF_FramePosition[clientIdx][EF_FRAME_HISTORY_SIZE - 1]);
	}
}

/**
 * OnGameFrame/OnPlayerRunCmd, needed by one or more rages.
 */
public OnGameFrame()
{
	if (!PluginActiveThisRound || !RoundInProgress)
		return;
		
	new Float:curTime = GetEngineTime();
		
	if (DD_ActiveThisRound || MS_ActiveThisRound || EF_ActiveThisRound || IS_ActiveThisRound)
	{
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (!IsLivingPlayer(clientIdx))
				continue;
		
			// meteor shower ticks for hale and players
			if (MS_ActiveThisRound)
				MS_Tick(clientIdx, curTime);
			
			// improved stun ticks only for victims
			if (IS_ActiveThisRound)
				IS_Tick(clientIdx, curTime);
		
			if (GetClientTeam(clientIdx) != BossTeam)
				continue;
				
			if (DD_CanUse[clientIdx])
				DD_Tick(clientIdx, curTime);
				
			if (EF_CanUse[clientIdx])
				EF_Tick(clientIdx, curTime);
		}
	}
}
 
public Action:OnPlayerRunCmd(clientIdx, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (!PluginActiveThisRound)
		return Plugin_Continue;

	new Action:resultRR = RR_OnPlayerRunCmd(clientIdx, buttons, impulse, vel, angles, weapon);
	new Action:resultGlide = GLIDE_OnPlayerRunCmd(clientIdx, buttons, impulse, vel, angles, weapon);
	new Action:resultMS = MS_OnPlayerRunCmd(clientIdx, buttons, impulse, vel, angles, weapon);
	
	if (resultRR != Plugin_Continue)
		return resultRR;
	if (resultGlide != Plugin_Continue)
		return resultGlide;
	if (resultMS != Plugin_Continue)
		return resultMS;
		
	return Plugin_Continue;
}

/**
 * General helper stocks, some original, some taken/modified from other sources
 */
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
 
stock PlaySoundLocal(clientIdx, String:soundPath[], bool:followPlayer = true, repeat = 1)
{
	// play a speech sound that travels normally, local from the player.
	decl Float:playerPos[3];
	GetClientEyePosition(clientIdx, playerPos);
	//PrintToServer("eye pos=%f,%f,%f     sound=%s", playerPos[0], playerPos[1], playerPos[2], soundPath);
	for (new i = 0; i < repeat; i++)
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
			CreateTimer(duration, Timer_RemoveEntity, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
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

public Action:Timer_RemoveEntity(Handle:timer, any:entid)
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
		new i = GetRandomInt(1, 32);
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
		PrintToServer("[sarysamods4] Error: Invalid weapon spawned. client=%d name=%s idx=%d attr=%s", client, name, index, attribute);
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

public bool:TraceWallsOnly(entity, contentsMask)
{
	return false;
}

stock FindRandomPlayer(bool:isBossTeam)
{
	new player = -1;

	// first, get a player count for the team we care about
	new playerCount = 0;
	for (new clientIdx = 0; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!IsLivingPlayer(clientIdx))
			continue;

		if ((isBossTeam && GetClientTeam(clientIdx) == BossTeam) || (!isBossTeam && GetClientTeam(clientIdx) != BossTeam))
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

stock Float:fixAngle(Float:angle)
{
	new sanity = 0;
	while (angle < -180.0 && (sanity++) <= 10)
		angle = angle + 360.0;
	while (angle > 180.0 && (sanity++) <= 10)
		angle = angle - 360.0;
		
	return angle;
}

stock Float:fmin(Float:one, Float:two)
{
	return one < two ? one : two;
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

stock Float:velocityFromVector(Float:vecVelocity[3])
{
	return SquareRoot((vecVelocity[0] * vecVelocity[0]) + (vecVelocity[1] * vecVelocity[1]));
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
