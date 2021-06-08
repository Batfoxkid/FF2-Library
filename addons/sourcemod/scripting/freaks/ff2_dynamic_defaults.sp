// no warranty blah blah don't sue blah blah doing this for fun blah blah...

// don't like the angles for jump/teleport/weighdown? change them here.
#define JUMP_TELEPORT_MAX_ANGLE -45.0
#define WEIGHDOWN_MIN_ANGLE 60.0 // first went with 45 but it mistriggered in ways I'd never done.

#define FF2_USING_AUTO_PLUGIN__OLD

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>
#undef REQUIRE_PLUGIN
#tryinclude <goomba>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

/**
 * Dynamic Defaults. Default mobility abilities (super jump, teleport) but with some improvements:
 * - The means for outside plugins to regulate the availability of these mobility options, hence the name "dynamic"
 * - Using OnGameFrame to ensure abilities are more responsive.
 * - Option to limit the number of uses of any ability.
 * - Option to attempt to teleport outside the target before teleporting into them.
 *
 * Original abilities were created and coded by Rainbolt Dash
 * Concept of improved teleport by Friagram, though no code was referenced.
 * Improvements by sarysa
 */
 
#define ARG_LENGTH 256
 
bool PRINT_DEBUG_INFO = true;
bool PRINT_DEBUG_SPAM = false;

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
#define INVALID_ENTREF INVALID_ENT_REFERENCE

//int MercTeam = view_as<int>(TFTeam_Red);
int BossTeam = view_as<int>(TFTeam_Blue);

float OFF_THE_MAP[3] = { 16383.0, 16383.0, -16383.0 };

#define NOPE_AVI "vo/engineer_no01.mp3"

int RoundInProgress = false;

public Plugin myinfo = {
	name = "Freak Fortress 2: Dynamic Defaults*",
	author = "sarysa, with a small amount of code by RainBolt Dash",
	version = "1.3.3",
}

#define IsEmptyString(%1) (%1[0] == 0)

#define FAR_FUTURE 100000000.0
#define COND_JARATE_WATER 86

#define HUD_Y 0.88
#define HUD_INTERVAL 0.2
#define HUD_LINGER 0.01
#define HUD_ALPHA 192
#define HUD_R_OK 255
#define HUD_G_OK 255
#define HUD_B_OK 255
#define HUD_R_ERROR 255
#define HUD_G_ERROR 64
#define HUD_B_ERROR 64


void __NoDefaultSuperJump(FF2Player player) {
	player.SetPropAny("bNoSuperJump", true);
}

void __HideHUD(FF2Player player) {
	player.SetPropAny("bHideHUD", true);
}

bool __IsHUDVisible(FF2Player player) {
	return player.GetPropAny("bHideHUD") == 0;
}


/**
 * Everything
 */
bool DD_BypassHUDRestrictions[MAX_PLAYERS_ARRAY]; // internal
Handle DD_HUDHandle; // internal

/**
 * Dynamic Jump
 */
#define DJ_STRING "dynamic_jump"
bool DJ_ActiveThisRound;
bool DJ_CanUse[MAX_PLAYERS_ARRAY];
float DJ_CrouchOrAltFireDownSince[MAX_PLAYERS_ARRAY]; // internal
bool DJ_EmergencyReady[MAX_PLAYERS_ARRAY]; // internal
float DJ_UpdateHUDAt[MAX_PLAYERS_ARRAY]; // internal
bool DJ_IsDisabled[MAX_PLAYERS_ARRAY]; // internal, initialized by arg3
int DJ_UsesRemaining[MAX_PLAYERS_ARRAY]; // internal, initialized by arg4
float DJ_OnCooldownUntil[MAX_PLAYERS_ARRAY]; // internal, initialized by arg5
float DJ_ChargeTime[MAX_PLAYERS_ARRAY]; // arg1
float DJ_Cooldown[MAX_PLAYERS_ARRAY]; // arg2
float DJ_MinEmergencyDamage[MAX_PLAYERS_ARRAY]; // arg6
bool DJ_UseCrappyJump[MAX_PLAYERS_ARRAY]; // arg7, bitterly opinionated...but I have to support it.
float DJ_Multiplier[MAX_PLAYERS_ARRAY]; // arg8
bool DJ_UseReload[MAX_PLAYERS_ARRAY]; // arg9
bool DJ_DontAffectWeighdown[MAX_PLAYERS_ARRAY]; // arg10
char DJ_EmergencyJumpString[MAX_CENTER_TEXT_LENGTH]; // arg17
char DJ_JumpCooldownString[MAX_CENTER_TEXT_LENGTH]; // arg18
char DJ_JumpReadyString[MAX_CENTER_TEXT_LENGTH]; // arg19

/**
 * Dynamic Teleport
 */
#define DT_STRING "dynamic_teleport"
bool DT_ActiveThisRound;
bool DT_CanUse[MAX_PLAYERS_ARRAY];
float DT_CrouchOrAltFireDownSince[MAX_PLAYERS_ARRAY]; // internal
bool DT_EmergencyReady[MAX_PLAYERS_ARRAY]; // internal
float DT_UpdateHUDAt[MAX_PLAYERS_ARRAY]; // internal
float DT_BlockAttacksUntil[MAX_PLAYERS_ARRAY]; // internal
float DT_GoombaBlockedUntil[MAX_PLAYERS_ARRAY]; // internal
bool DT_IsDisabled[MAX_PLAYERS_ARRAY]; // internal, initialized by arg4
int DT_UsesRemaining[MAX_PLAYERS_ARRAY]; // internal, initialized by arg5
float DT_OnCooldownUntil[MAX_PLAYERS_ARRAY]; // internal, initialized by arg6
float DT_ChargeTime[MAX_PLAYERS_ARRAY]; // arg1
float DT_Cooldown[MAX_PLAYERS_ARRAY]; // arg2
// did you know arg3 was an attached particle? I didn't, until I looked at the code/HHH's file
float DT_MinEmergencyDamage[MAX_PLAYERS_ARRAY]; // arg7
bool DT_TryTeleportAbove[MAX_PLAYERS_ARRAY]; // arg8
bool DT_TryTeleportSide[MAX_PLAYERS_ARRAY]; // arg9
float DT_StunDuration[MAX_PLAYERS_ARRAY]; // arg10
bool DT_UseReload[MAX_PLAYERS_ARRAY]; // arg11
bool DT_SameTeam[MAX_PLAYERS_ARRAY]; // arg12
bool DT_IsReverseTeleport[MAX_PLAYERS_ARRAY]; // arg13
char DT_NoMinionString[MAX_CENTER_TEXT_LENGTH]; // arg16
char DT_EmergencyTeleportString[MAX_CENTER_TEXT_LENGTH]; // arg17
char DT_TeleportCooldownString[MAX_CENTER_TEXT_LENGTH]; // arg18
char DT_TeleportReadyString[MAX_CENTER_TEXT_LENGTH]; // arg19

/**
 * Dynamic Weighdown
 */
#define DW_STRING "dynamic_weighdown"
bool DW_ActiveThisRound;
bool DW_CanUse[MAX_PLAYERS_ARRAY];
float DW_OnCooldownUntil[MAX_PLAYERS_ARRAY]; // internal
float DW_RestoreGravityAt[MAX_PLAYERS_ARRAY]; // internal
bool DW_IsDisabled[MAX_PLAYERS_ARRAY]; // internal, initialized by arg1
int DW_UsesRemaining[MAX_PLAYERS_ARRAY]; // internal, initialized by arg2
float DW_DefaultGravity[MAX_PLAYERS_ARRAY]; // arg3
char DW_UsageString[MAX_CENTER_TEXT_LENGTH]; // arg19

/**
 * Dynamic Glide
 */
#define DG_STRING "dynamic_glide"
bool DG_ActiveThisRound = false;
bool DG_CanUse[MAX_PLAYERS_ARRAY]; // internal
bool DG_IsUsing[MAX_PLAYERS_ARRAY]; // internal
float DG_SingleUseEndTime[MAX_PLAYERS_ARRAY]; // internal, if max duration is set
float DG_SingleUseStartTime[MAX_PLAYERS_ARRAY]; // internal, if max duration is set
bool DG_SpaceBarWasDown[MAX_PLAYERS_ARRAY]; // internal
bool DG_IsDisabled[MAX_PLAYERS_ARRAY]; // internal, based on arg1
float DG_OriginalMaxVelocity[MAX_PLAYERS_ARRAY]; // arg2
float DG_DecayPerSecond[MAX_PLAYERS_ARRAY]; // arg3
float DG_Cooldown[MAX_PLAYERS_ARRAY]; // arg4
float DG_MaxDuration[MAX_PLAYERS_ARRAY]; // arg5
char DG_UseSound[MAX_SOUND_FILE_LENGTH]; // arg6
bool DG_UseHoldControls[MAX_PLAYERS_ARRAY]; // arg7

/**
 * Dynamic Stun Sentry Gun
 */
#define DSSG_STRING "dynamic_stunsg"
#define MAX_SENTRIES 10
int DSSG_EntRef[MAX_SENTRIES] = { INVALID_ENT_REFERENCE, ... };
int DSSG_ParticleEntRef[MAX_SENTRIES] = { INVALID_ENT_REFERENCE, ... };
float DSSG_UnstunAt[MAX_SENTRIES];
int DSSG_NormalAmmo[MAX_SENTRIES];
int DSSG_RocketAmmo[MAX_SENTRIES];

/**
 * Dynamic Speed Management
 */
#define DSM_STRING "dynamic_speed_management"
bool DSM_ActiveThisRound;
bool DSM_CanUse[MAX_PLAYERS_ARRAY];
int DSM_MaxHP[MAX_PLAYERS_ARRAY]; // internal, grab this only once
float DSM_OverrideSpeed[MAX_PLAYERS_ARRAY]; // internal
bool DSM_OverrideUseModifiers[MAX_PLAYERS_ARRAY]; // internal
float DSM_LowSpeed[MAX_PLAYERS_ARRAY]; // arg1
float DSM_HighSpeed[MAX_PLAYERS_ARRAY]; // arg2
bool DSM_UseBFB[MAX_PLAYERS_ARRAY]; // arg3
float DSM_BFBModifier[MAX_PLAYERS_ARRAY]; // arg4
bool DSM_UseRifle[MAX_PLAYERS_ARRAY]; // arg5
float DSM_RifleModifier[MAX_PLAYERS_ARRAY]; // arg6
bool DSM_UseBow[MAX_PLAYERS_ARRAY]; // arg7
float DSM_BowModifier[MAX_PLAYERS_ARRAY]; // arg8
bool DSM_UseMinigun[MAX_PLAYERS_ARRAY]; // arg9
float DSM_MinigunModifier[MAX_PLAYERS_ARRAY]; // arg10
bool DSM_UseCritACola[MAX_PLAYERS_ARRAY]; // arg11
float DSM_CritAColaModifier[MAX_PLAYERS_ARRAY]; // arg12
bool DSM_UseWhip[MAX_PLAYERS_ARRAY]; // arg13 (also for concheror and others)
float DSM_WhipModifier[MAX_PLAYERS_ARRAY]; // arg14
bool DSM_UseDazed[MAX_PLAYERS_ARRAY]; // arg15
float DSM_DazedModifier[MAX_PLAYERS_ARRAY]; // arg16
bool DSM_UseDisguiseSpeed[MAX_PLAYERS_ARRAY]; // arg17
bool DSM_DisguiseCanIncreaseSpeed[MAX_PLAYERS_ARRAY]; // arg18
bool DSM_UseSlowed[MAX_PLAYERS_ARRAY]; // deprecated
float DSM_SlowedModifier[MAX_PLAYERS_ARRAY]; // deprecated

/**
 * Dynamic Melee Management - For when you absolutely positively need your weapon stats to be accurate.
 */
#define DMM_STRING "dynamic_melee_management"
bool DMM_ActiveThisRound;
bool DMM_CanUse[MAX_PLAYERS_ARRAY];
float DMM_ResetWeaponAt[MAX_PLAYERS_ARRAY]; // internal, need to do this after FF2's done

/**
 * Dynamic Parkour - A super jump replacement
 */
#define DP_STRING "dynamic_parkour"
#define DP_MOTION_INTERVAL 0.05
#define DP_REQUIRED_GROUND_CLEARANCE 20.0
#define DP_GRACE_PERIOD 0.2
#define DP_HUD_STATE_ON_GROUND 0
#define DP_HUD_STATE_IN_WATER 1
#define DP_HUD_STATE_USING 2
#define DP_HUD_STATE_AVAILABLE 3
bool DP_ActiveThisRound;
bool DP_CanUse[MAX_PLAYERS_ARRAY];
bool DP_Latched[MAX_PLAYERS_ARRAY]; // internal
float DP_KnockbackImmuneUntil[MAX_PLAYERS_ARRAY]; // internal
bool DP_JumpKeyDown[MAX_PLAYERS_ARRAY]; // internal
float DP_ClimbingYaw[MAX_PLAYERS_ARRAY]; // internal
bool DP_ShouldWeaponSwitch[MAX_PLAYERS_ARRAY]; // internal, derived from validity of arg12
float DP_IgnoreActivationUntil[MAX_PLAYERS_ARRAY]; // internal
float DP_NextMoveAt[MAX_PLAYERS_ARRAY]; // internal
float DP_ResetAirJumpsAt[MAX_PLAYERS_ARRAY]; // internal
int DP_HUDState[MAX_PLAYERS_ARRAY]; // internal
float DP_NextHUDAt[MAX_PLAYERS_ARRAY]; // internal
int DP_ActivationKey[MAX_PLAYERS_ARRAY]; // derived from arg1
float DP_MaxDistance[MAX_PLAYERS_ARRAY]; // arg2
float DP_WallJumpIntensity[MAX_PLAYERS_ARRAY]; // arg3
float DP_WallJumpPitch[MAX_PLAYERS_ARRAY]; // arg4
float DP_WallClimbIntensity[MAX_PLAYERS_ARRAY]; // arg5
bool DP_ShouldKnockbackImmune[MAX_PLAYERS_ARRAY]; // arg6
float DP_KnockbackImmunityLinger[MAX_PLAYERS_ARRAY]; // arg7
int DP_TraceOptions[MAX_PLAYERS_ARRAY]; // derived from arg8
float DP_MaxYawDeviation[MAX_PLAYERS_ARRAY]; // arg9
float DP_UDPitchThreshold[MAX_PLAYERS_ARRAY]; // arg10
float DP_AirblastUnlatchDuration[MAX_PLAYERS_ARRAY]; // arg11
float DP_NormalForwardPush[MAX_PLAYERS_ARRAY]; // arg12
float DP_ForwardPushWhileMovingBack[MAX_PLAYERS_ARRAY]; // arg13
// arg 21-24 are not stored
bool DP_DisableHUD[MAX_CENTER_TEXT_LENGTH]; // arg31
char DP_HUDAvailable[MAX_CENTER_TEXT_LENGTH]; // arg32
char DP_HUDUsing[MAX_CENTER_TEXT_LENGTH]; // arg33
char DP_HUDOnGround[MAX_CENTER_TEXT_LENGTH]; // arg34
char DP_HUDInWater[MAX_CENTER_TEXT_LENGTH]; // arg35

/**
 * Dynamic Environmental Management
 */
#define DEM_STRING "dynamic_env_management"
bool DEM_ActiveThisRound;
bool DEM_CanUse[MAX_PLAYERS_ARRAY];
float DEM_InvincibleUntil[MAX_PLAYERS_ARRAY]; // internal
float DEM_DamageThreshold[MAX_PLAYERS_ARRAY]; // arg1
float DEM_InvincibilityDuration[MAX_PLAYERS_ARRAY]; // arg2
bool DEM_NoUber[MAX_PLAYERS_ARRAY]; // arg3
bool DEM_ShouldTeleport[MAX_PLAYERS_ARRAY]; // arg11
bool DEM_TeleportOnTop[MAX_PLAYERS_ARRAY]; // arg12
bool DEM_TeleportSide[MAX_PLAYERS_ARRAY]; // arg13
float DEM_TeleportStunDuration[MAX_PLAYERS_ARRAY]; // arg14

/**
 * Dynamic Point Teleport: originally wrote on 2015-03-26
 * Originally written for a Blitzkrieg derivative, I've since moved it here.
 * It's a replacement for the buggy War3Source version.
 */
#define DPT_STRING "dynamic_point_teleport"
#define DPT_CENTER_TEXT_INTERVAL 0.5
bool DPT_ActiveThisRound;
bool DPT_CanUse[MAX_PLAYERS_ARRAY];
bool DPT_KeyDown[MAX_PLAYERS_ARRAY];
float DPT_NextCenterTextAt[MAX_PLAYERS_ARRAY];
int DPT_ChargesRemaining[MAX_PLAYERS_ARRAY]; // internal
int DPT_KeyToUse[MAX_PLAYERS_ARRAY]; // arg1, though it's immediately converted into an IN_BLAHBLAH flag
int DPT_NumSkills[MAX_PLAYERS_ARRAY]; // arg2
float DPT_MaxDistance[MAX_PLAYERS_ARRAY]; // arg3
char DPT_CenterText[MAX_CENTER_TEXT_LENGTH]; // arg4
char DPT_OldLocationParticleEffect[MAX_EFFECT_NAME_LENGTH]; // arg5
char DPT_NewLocationParticleEffect[MAX_EFFECT_NAME_LENGTH]; // arg6
char DPT_UseSound[MAX_SOUND_FILE_LENGTH]; // arg7
bool DPT_PreserveMomentum[MAX_PLAYERS_ARRAY]; // arg8
bool DPT_AddCharges[MAX_PLAYERS_ARRAY]; // arg9
bool DPT_EmptyClipOnTeleport[MAX_PLAYERS_ARRAY]; // arg10
float DPT_AttackDelayOnTeleport[MAX_PLAYERS_ARRAY]; // arg11

/**
 * Dynamic Stop Taunt (DPT was taken)
 */
#define DST_STRING "dynamic_stop_taunt"
bool DST_ActiveThisRound;
bool DST_CanUse[MAX_PLAYERS_ARRAY];
bool DST_ActivateNextTick[MAX_PLAYERS_ARRAY]; // internal
bool DST_DoNotStopMotion[MAX_PLAYERS_ARRAY]; // arg1

/**
 * METHODS REQUIRED BY ff2 subplugin
 */
#define CMD_FORCE_RAGE "rage"
public void OnPluginStart2()
{
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	DD_HUDHandle = CreateHudSynchronizer();
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	RoundInProgress = true;
	
	// initialize variables
	DJ_ActiveThisRound = false;
	DT_ActiveThisRound = false;
	DW_ActiveThisRound = false;
	DG_ActiveThisRound = false;
	DSM_ActiveThisRound = false;
	DMM_ActiveThisRound = false;
	DP_ActiveThisRound = false;
	DEM_ActiveThisRound = false;
	DPT_ActiveThisRound = false;
	
	// initialize arrays
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		// all client inits
		DJ_CanUse[clientIdx] = false;
		DT_CanUse[clientIdx] = false;
		DW_CanUse[clientIdx] = false;
		DG_CanUse[clientIdx] = false;
		DSM_CanUse[clientIdx] = false;
		DMM_CanUse[clientIdx] = false;
		DP_CanUse[clientIdx] = false;
		DP_Latched[clientIdx] = false;
		DEM_CanUse[clientIdx] = false;
		DPT_CanUse[clientIdx] = false;
		DT_GoombaBlockedUntil[clientIdx] = 0.0; // initialize here, since it can be used by other invocations of teleport

		// boss-only inits
		int bossIdx = FF2_GetBossIndex(clientIdx);
		if (bossIdx < 0)
			continue;

		DD_BypassHUDRestrictions[clientIdx] = false;
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, DJ_STRING))
		{
			DJ_ActiveThisRound = true;
			DJ_CanUse[clientIdx] = true;
			DJ_CrouchOrAltFireDownSince[clientIdx] = FAR_FUTURE;
			DJ_EmergencyReady[clientIdx] = false;
			
			DJ_ChargeTime[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DJ_STRING, 1);
			DJ_Cooldown[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DJ_STRING, 2);
			DJ_IsDisabled[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DJ_STRING, 3) == 1;
			DJ_UsesRemaining[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DJ_STRING, 4);
			DJ_OnCooldownUntil[clientIdx] = GetEngineTime() + FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DJ_STRING, 5);
			DJ_MinEmergencyDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DJ_STRING, 6);
			DJ_UseCrappyJump[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DJ_STRING, 7) == 1;
			DJ_Multiplier[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DJ_STRING, 8);
			DJ_UseReload[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DJ_STRING, 9) == 1;
			DJ_DontAffectWeighdown[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DJ_STRING, 10) == 1;
			
			ReadCenterText(bossIdx, DJ_STRING, 17, DJ_EmergencyJumpString);
			ReadCenterText(bossIdx, DJ_STRING, 18, DJ_JumpCooldownString);
			ReadCenterText(bossIdx, DJ_STRING, 19, DJ_JumpReadyString);
			
			if (DJ_UsesRemaining[clientIdx] <= 0)
				DJ_UsesRemaining[clientIdx] = 999999999;
				
			if (DJ_Multiplier[clientIdx] <= 0)
				DJ_Multiplier[clientIdx] = 1.0;
			
			__NoDefaultSuperJump(ToFF2Player(bossIdx));
			__HideHUD(ToFF2Player(bossIdx));
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, DT_STRING))
		{
			DT_ActiveThisRound = true;
			DT_CanUse[clientIdx] = true;
			DT_CrouchOrAltFireDownSince[clientIdx] = FAR_FUTURE;
			DT_EmergencyReady[clientIdx] = false;
			DT_BlockAttacksUntil[clientIdx] = FAR_FUTURE;
			DT_GoombaBlockedUntil[clientIdx] = 0.0;
			
			DT_ChargeTime[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DT_STRING, 1);
			DT_Cooldown[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DT_STRING, 2);
			DT_IsDisabled[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DT_STRING, 4) == 1;
			DT_UsesRemaining[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DT_STRING, 5);
			DT_OnCooldownUntil[clientIdx] = GetEngineTime() + FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DT_STRING, 6);
			DT_MinEmergencyDamage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DT_STRING, 7);
			DT_TryTeleportAbove[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DT_STRING, 8) == 1;
			DT_TryTeleportSide[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DT_STRING, 9) == 1;
			DT_StunDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DT_STRING, 10);
			DT_UseReload[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DT_STRING, 11) == 1;
			DT_SameTeam[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DT_STRING, 12) == 1;
			DT_IsReverseTeleport[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DT_STRING, 13) == 1;
			
			ReadCenterText(bossIdx, DT_STRING, 16, DT_NoMinionString);
			ReadCenterText(bossIdx, DT_STRING, 17, DT_EmergencyTeleportString);
			ReadCenterText(bossIdx, DT_STRING, 18, DT_TeleportCooldownString);
			ReadCenterText(bossIdx, DT_STRING, 19, DT_TeleportReadyString);
			
			if (DT_UsesRemaining[clientIdx] <= 0)
				DT_UsesRemaining[clientIdx] = 999999999;
			
			__NoDefaultSuperJump(ToFF2Player(bossIdx));
			__HideHUD(ToFF2Player(bossIdx));
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, DW_STRING))
		{
			DW_ActiveThisRound = true;
			DW_CanUse[clientIdx] = true;
			DW_RestoreGravityAt[clientIdx] = FAR_FUTURE;
			
			DW_IsDisabled[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DW_STRING, 1) == 1;
			DW_UsesRemaining[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DW_STRING, 2);
			DW_DefaultGravity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DW_STRING, 3);
			
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DW_STRING, 19, DW_UsageString, MAX_CENTER_TEXT_LENGTH);
			
			ReplaceString(DW_UsageString, MAX_CENTER_TEXT_LENGTH, "\\n", "\n");

			if (DW_UsesRemaining[clientIdx] <= 0)
				DW_UsesRemaining[clientIdx] = 999999999;
			
			// assume zero gravity is an error.
			if (DW_DefaultGravity[clientIdx] <= 0.0)
				DW_DefaultGravity[clientIdx] = 1.0;
			
			ToFF2Player(bossIdx).SetPropAny("bNoWeighdown", true);
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, DG_STRING))
		{
			DG_ActiveThisRound = true;
			DG_CanUse[clientIdx] = true;
			
			DG_IsDisabled[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DG_STRING, 1) == 1;
			DG_OriginalMaxVelocity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DG_STRING, 2);
			DG_DecayPerSecond[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DG_STRING, 3);
			DG_Cooldown[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DG_STRING, 4);
			DG_MaxDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DG_STRING, 5);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DG_STRING, 6, DG_UseSound, MAX_SOUND_FILE_LENGTH);
			DG_UseHoldControls[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DG_STRING, 7) == 1;
			
			// internal inits
			DG_IsUsing[clientIdx] = false;
			DG_SingleUseStartTime[clientIdx] = 0.0;
			DG_SingleUseEndTime[clientIdx] = 0.0;
			DG_SpaceBarWasDown[clientIdx] = false;
			if (DG_MaxDuration[clientIdx] <= 0.0) // usable as long as the user wants
				DG_MaxDuration[clientIdx] = 999999.0;
			
			// precache
			if (strlen(DG_UseSound) > 3)
				PrecacheSound(DG_UseSound);
				
			if (PRINT_DEBUG_INFO)
				PrintToServer("[ff2_dynamic_defaults] User %d using glide this round. disabled=%d glideVel=%f decayPS=%f cooldown=%f maxDur=%f", clientIdx,
						DG_IsDisabled[clientIdx], DG_OriginalMaxVelocity[clientIdx], DG_DecayPerSecond[clientIdx], DG_Cooldown[clientIdx], DG_MaxDuration[clientIdx]);
			
			__NoDefaultSuperJump(ToFF2Player(bossIdx));
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, DSM_STRING))
		{
			DSM_ActiveThisRound = true;
			DSM_CanUse[clientIdx] = true;
			DSM_OverrideSpeed[clientIdx] = -1.0;
			DSM_OverrideUseModifiers[clientIdx] = true;
			
			DSM_LowSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DSM_STRING, 1);
			DSM_HighSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DSM_STRING, 2);
			DSM_UseBFB[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DSM_STRING, 3, 1) == 1;
			DSM_BFBModifier[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DSM_STRING, 4);
			DSM_UseRifle[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DSM_STRING, 5, 1) == 1;
			DSM_RifleModifier[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DSM_STRING, 6);
			DSM_UseBow[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DSM_STRING, 7, 1) == 1;
			DSM_BowModifier[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DSM_STRING, 8);
			DSM_UseMinigun[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DSM_STRING, 9, 1) == 1;
			DSM_MinigunModifier[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DSM_STRING, 10);
			DSM_UseCritACola[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DSM_STRING, 11, 1) == 1;
			DSM_CritAColaModifier[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DSM_STRING, 12);
			DSM_UseWhip[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DSM_STRING, 13, 1) == 1;
			DSM_WhipModifier[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DSM_STRING, 14);
			DSM_UseDazed[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DSM_STRING, 15, 1) == 1;
			DSM_DazedModifier[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DSM_STRING, 16);
			DSM_UseDisguiseSpeed[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DSM_STRING, 17, 0) == 1;
			DSM_DisguiseCanIncreaseSpeed[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DSM_STRING, 18, 0) == 1;

			// these were in development, but now it seems slowed is too complex to mess with
			//DSM_UseSlowed[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DSM_STRING, 11, 1) == 1;
			//DSM_SlowedModifier[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DSM_STRING, 12);
			
			// fill these in now
			DSM_ValidateModifier(DSM_BFBModifier[clientIdx], DSM_UseBFB[clientIdx], 0.444);
			DSM_ValidateModifier(DSM_RifleModifier[clientIdx], DSM_UseRifle[clientIdx], 0.27);
			DSM_ValidateModifier(DSM_BowModifier[clientIdx], DSM_UseBow[clientIdx], 0.45);
			DSM_ValidateModifier(DSM_MinigunModifier[clientIdx], DSM_UseMinigun[clientIdx], 0.47);
			DSM_ValidateModifier(DSM_SlowedModifier[clientIdx], DSM_UseSlowed[clientIdx], 0.60);
			DSM_ValidateModifier(DSM_CritAColaModifier[clientIdx], DSM_UseCritACola[clientIdx], 1.35);
			DSM_ValidateModifier(DSM_WhipModifier[clientIdx], DSM_UseWhip[clientIdx], 1.35);
			DSM_ValidateModifier(DSM_DazedModifier[clientIdx], DSM_UseDazed[clientIdx], 0.75);
			
			// needs to be filled later
			DSM_MaxHP[clientIdx] = 0;
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, DMM_STRING))
		{
			DMM_ActiveThisRound = true;
			DMM_CanUse[clientIdx] = true;
			
			DMM_ResetWeaponAt[clientIdx] = GetEngineTime() + 0.5;
		}

		if (FF2_HasAbility(bossIdx, this_plugin_name, DP_STRING))
		{
			DP_ActiveThisRound = true;
			DP_CanUse[clientIdx] = true;
			DP_KnockbackImmuneUntil[clientIdx] = 0.0;
			DP_ResetAirJumpsAt[clientIdx] = FAR_FUTURE;
			
			// arg1 is special, and must be immediately modified
			DP_ActivationKey[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DP_STRING, 1);
			if (DP_ActivationKey[clientIdx] == 1)
				DP_ActivationKey[clientIdx] = IN_RELOAD;
			else if (DP_ActivationKey[clientIdx] == 2)
				DP_ActivationKey[clientIdx] = IN_ATTACK3;
			else if (DP_ActivationKey[clientIdx] == 3)
				DP_ActivationKey[clientIdx] = IN_USE;
			else // save the best for default
				DP_ActivationKey[clientIdx] = IN_ATTACK2;
				
			// other args, not so much
			DP_MaxDistance[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DP_STRING, 2);
			DP_WallJumpIntensity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DP_STRING, 3);
			DP_WallJumpPitch[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DP_STRING, 4);
			DP_WallClimbIntensity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DP_STRING, 5);
			DP_ShouldKnockbackImmune[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DP_STRING, 6) == 1;
			DP_KnockbackImmunityLinger[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DP_STRING, 7);
			bool canSkyboxClimb = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DP_STRING, 8) == 1;
			DP_TraceOptions[clientIdx] = canSkyboxClimb ? MASK_PLAYERSOLID_BRUSHONLY : (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE | CONTENTS_MOVEABLE);
			DP_MaxYawDeviation[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DP_STRING, 9);
			DP_UDPitchThreshold[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DP_STRING, 10);
			DP_AirblastUnlatchDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DP_STRING, 11);
			DP_NormalForwardPush[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DP_STRING, 12);
			DP_ForwardPushWhileMovingBack[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DP_STRING, 13);
			
			// while args 21-24 (weapon specification) are not stored, get their validity now so useless code isn't executed constantly later.
			static char weaponName[MAX_WEAPON_NAME_LENGTH];
			weaponName[0] = 0;
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DP_STRING, 22, weaponName, MAX_WEAPON_NAME_LENGTH);
			DP_ShouldWeaponSwitch[clientIdx] = !IsEmptyString(weaponName);
			
			// HUD related args
			DP_DisableHUD[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DP_STRING, 31) == 1;
			ReadCenterText(bossIdx, DP_STRING, 32, DP_HUDAvailable);
			ReadCenterText(bossIdx, DP_STRING, 33, DP_HUDUsing);
			ReadCenterText(bossIdx, DP_STRING, 34, DP_HUDOnGround);
			ReadCenterText(bossIdx, DP_STRING, 35, DP_HUDInWater);
			DP_NextHUDAt[clientIdx] = GetEngineTime() + (DP_DisableHUD[clientIdx] ? 99999.0 : HUD_INTERVAL); // need a short delay since HUD state will take a tick to get
			
			// other internal inits
			DP_JumpKeyDown[clientIdx] = (GetClientButtons(clientIdx) & IN_JUMP) != 0;
			DP_IgnoreActivationUntil[clientIdx] = 0.0;
			
			__NoDefaultSuperJump(ToFF2Player(bossIdx));
			__HideHUD(ToFF2Player(bossIdx));
		}

		if (FF2_HasAbility(bossIdx, this_plugin_name, DEM_STRING))
		{
			DEM_ActiveThisRound = true;
			DEM_CanUse[clientIdx] = true;
			DEM_InvincibleUntil[clientIdx] = FAR_FUTURE;

			DEM_DamageThreshold[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DEM_STRING, 1);
			DEM_InvincibilityDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DEM_STRING, 2);
			DEM_NoUber[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DEM_STRING, 3) == 1;
			DEM_ShouldTeleport[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DEM_STRING, 11) == 1;
			DEM_TeleportOnTop[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DEM_STRING, 12) == 1;
			DEM_TeleportSide[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DEM_STRING, 13) == 1;
			DEM_TeleportStunDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DEM_STRING, 14);
		}
		
		if (FF2_HasAbility(bossIdx, this_plugin_name, DPT_STRING))
		{
			DPT_CanUse[clientIdx] = true;
			DPT_ActiveThisRound = true;
			DPT_NextCenterTextAt[clientIdx] = GetEngineTime() + 1.0;
			DPT_ChargesRemaining[clientIdx] = 0;

			int keyId = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DPT_STRING, 1);
			if (keyId == 1)
				DPT_KeyToUse[clientIdx] = IN_ATTACK;
			else if (keyId == 2)
				DPT_KeyToUse[clientIdx] = IN_ATTACK2;
			else if (keyId == 3)
				DPT_KeyToUse[clientIdx] = IN_RELOAD;
			else if (keyId == 4)
				DPT_KeyToUse[clientIdx] = IN_ATTACK3;
			else
			{
				DPT_KeyToUse[clientIdx] = IN_RELOAD;
				PrintCenterText(clientIdx, "Invalid key specified for point teleport. Using RELOAD.\nNotify your admin!");
			}
			DPT_NumSkills[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DPT_STRING, 2);
			DPT_MaxDistance[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DPT_STRING, 3);
			ReadCenterText(bossIdx, DPT_STRING, 4, DPT_CenterText);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DPT_STRING, 5, DPT_OldLocationParticleEffect, MAX_EFFECT_NAME_LENGTH);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DPT_STRING, 6, DPT_NewLocationParticleEffect, MAX_EFFECT_NAME_LENGTH);
			ReadSound(bossIdx, DPT_STRING, 7, DPT_UseSound);
			DPT_PreserveMomentum[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DPT_STRING, 8) == 1;
			DPT_AddCharges[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DPT_STRING, 9) == 1;
			DPT_EmptyClipOnTeleport[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DPT_STRING, 10) == 1;
			DPT_AttackDelayOnTeleport[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DPT_STRING, 11);
			
			DPT_KeyDown[clientIdx] = (GetClientButtons(clientIdx) & DPT_KeyToUse[clientIdx]) != 0;
			
			PrecacheSound(NOPE_AVI);
		}

		if (FF2_HasAbility(bossIdx, this_plugin_name, DST_STRING))
		{
			DST_CanUse[clientIdx] = true;
			DST_ActiveThisRound = true;
			DST_ActivateNextTick[clientIdx] = false;
			
			DST_DoNotStopMotion[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DST_STRING, 1) == 1;
		}
	}
	
	if (DT_ActiveThisRound || DJ_ActiveThisRound)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (!IsClientInGame(clientIdx))
				continue;
		
			if (DT_CanUse[clientIdx] || DJ_CanUse[clientIdx])
				SDKHook(clientIdx, SDKHook_OnTakeDamage, CheckEnvironmentalDamage);
			
			// fix for the tele-attack exploit
			if (DT_ActiveThisRound)
				SDKHook(clientIdx, SDKHook_OnTakeDamage, DT_CheckTeleAttack);
		}
	}
	
	if (DSM_ActiveThisRound)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsLivingPlayer(clientIdx) && DSM_CanUse[clientIdx])
				SDKHook(clientIdx, SDKHook_PreThink, DSM_PreThink);
		}
	}
	
	if (DP_ActiveThisRound)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsLivingPlayer(clientIdx) && DP_CanUse[clientIdx])
				SDKHook(clientIdx, SDKHook_OnTakeDamage, DP_OnTakeDamage);
		}
		
		HookEvent("object_deflected", DP_OnDeflect, EventHookMode_Pre);
	}

	if (DEM_ActiveThisRound)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsLivingPlayer(clientIdx) && DEM_CanUse[clientIdx])
				SDKHook(clientIdx, SDKHook_OnTakeDamage, DEM_OnTakeDamage);
		}
	}

	for (int i = 0; i < MAX_SENTRIES; i++)
		DSSG_EntRef[i] = INVALID_ENTREF;
}

public Action Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	RoundInProgress = false;
	
	if (DT_ActiveThisRound || DJ_ActiveThisRound)
	{
		DT_ActiveThisRound = false;
		DJ_ActiveThisRound = false;
		
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
			{
				// these can leak across multiple rounds if not cleaned up
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, CheckEnvironmentalDamage);
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, DT_CheckTeleAttack);
			}
		}
	}
	
	if (DW_ActiveThisRound)
	{
		DW_ActiveThisRound = false;
	
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
			{
				// this can leak across multiple rounds if not cleaned up
				SetEntityGravity(clientIdx, 1.0);
			}
		}
	}
	
	if (DSM_ActiveThisRound)
	{
		DSM_ActiveThisRound = false;
		
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx) && DSM_CanUse[clientIdx])
				SDKUnhook(clientIdx, SDKHook_PreThink, DSM_PreThink);
		}
	}

	if (DP_ActiveThisRound)
	{
		DP_ActiveThisRound = false;
		
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx) && DP_CanUse[clientIdx])
			{
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, DP_OnTakeDamage);
				SetEntityGravity(clientIdx, 1.0);
			}
		}
		
		UnhookEvent("object_deflected", DP_OnDeflect, EventHookMode_Pre);
	}
	
	if (DEM_ActiveThisRound)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx) && DEM_CanUse[clientIdx])
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, DEM_OnTakeDamage);
		}
	}
	
	DG_ActiveThisRound = false;
}

public Action FF2_OnAbility2(int bossIdx, const char[] plugin_name, const char[] ability_name, int slot)
{
	if (strcmp(plugin_name, this_plugin_name) != 0)
		return Plugin_Continue;
	else if (!RoundInProgress) // don't execute these rages with 0 players alive
		return Plugin_Continue;
		
	if (!strcmp(ability_name, DSSG_STRING))
	{
		float duration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DSSG_STRING, 1);
		float radius = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DSSG_STRING, 2);
		if (radius <= 0.0)
			radius = FF2_GetRageDist(bossIdx);
		DSSG_PerformStun(GetClientOfUserId(FF2_GetBossUserId(bossIdx)), radius, duration);
	}
	else if (!strcmp(ability_name, DPT_STRING))
		Rage_DynamicPointTeleport(bossIdx);
	else if (!strcmp(ability_name, DST_STRING))
		Rage_DynamicStopTaunt(bossIdx);

	return Plugin_Continue;
}

/**
 * Jump and Teleport
 */
public Action CheckEnvironmentalDamage(int clientIdx, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePos[3], int damagecustom)
{
	// I think I'm paranoid...
	if (!IsLivingPlayer(clientIdx))
		return Plugin_Continue;

	// ignore fall damage from self
	if (attacker == 0 && inflictor == 0 && (damagetype & DMG_FALL) != 0)
		return Plugin_Continue;
		
	// ignore damage from players
	if (attacker >= 1 && attacker <= MaxClients)
		return Plugin_Continue;
		
	// definitely environmental damage to a player. from here on checks depend on what abilities the hale theoretically has.
	if (DJ_CanUse[clientIdx] && !DJ_IsDisabled[clientIdx])
	{
		if (damage > DJ_MinEmergencyDamage[clientIdx])
		{
			DJ_EmergencyReady[clientIdx] = true;
			DJ_OnCooldownUntil[clientIdx] = FAR_FUTURE;
		}
	}

	if (DT_CanUse[clientIdx] && !DT_IsDisabled[clientIdx])
	{
		if (damage > DT_MinEmergencyDamage[clientIdx])
		{
			DT_EmergencyReady[clientIdx] = true;
			DT_OnCooldownUntil[clientIdx] = FAR_FUTURE;
		}
	}
	
	return Plugin_Continue;
}

public bool IsInInvalidCondition(int clientIdx)
{
	return TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed) || GetEntProp(clientIdx, Prop_Send, "movetype") == view_as<any>(MOVETYPE_NONE);
}

/**
 * Dynamic Jump
 */
#define SJ_TP_BUTTONS_ALT_FIRE (IN_DUCK | IN_ATTACK2)
#define SJ_TP_BUTTONS_RELOAD (IN_RELOAD)
public void DJ_Tick(int clientIdx, int buttons, float curTime)
{
	if (DJ_IsDisabled[clientIdx] || DJ_UsesRemaining[clientIdx] == 0)
		return;
		
	if (curTime >= DJ_OnCooldownUntil[clientIdx])
		DJ_OnCooldownUntil[clientIdx] = FAR_FUTURE;
		
	float chargePercent = 0.0;
	if (DJ_OnCooldownUntil[clientIdx] == FAR_FUTURE)
	{
		// get charge percent here, used by both the HUD and the actual jump
		if (DJ_CrouchOrAltFireDownSince[clientIdx] != FAR_FUTURE)
		{
			if (DJ_ChargeTime[clientIdx] <= 0.0)
				chargePercent = 100.0;
			else
				chargePercent = fmin((curTime - DJ_CrouchOrAltFireDownSince[clientIdx]) / DJ_ChargeTime[clientIdx], 1.0) * 100.0;
		}
			
		int validButtons = DJ_UseReload[clientIdx] ? SJ_TP_BUTTONS_RELOAD : SJ_TP_BUTTONS_ALT_FIRE;
		
		// do we start the charging now?
		if (DJ_CrouchOrAltFireDownSince[clientIdx] == FAR_FUTURE && (buttons & validButtons) != 0)
			DJ_CrouchOrAltFireDownSince[clientIdx] = curTime;
			
		// has key been released?
		if (DJ_CrouchOrAltFireDownSince[clientIdx] != FAR_FUTURE && (buttons & validButtons) == 0)
		{
			// is user's eye angle valid? if so, perform the jump
			static float eyeAngles[3];
			GetClientEyeAngles(clientIdx, eyeAngles);
			if (eyeAngles[0] <= JUMP_TELEPORT_MAX_ANGLE && !IsInInvalidCondition(clientIdx))
			{
				// unlike the original, I'm managing cooldown myself. so lets do it.
				// also doing it now to completely avoid that rare double SJ glitch I've seen
				DJ_OnCooldownUntil[clientIdx] = curTime + DJ_Cooldown[clientIdx];
				if (!DJ_DontAffectWeighdown[clientIdx])
					DW_CooldownUntil(clientIdx, DJ_OnCooldownUntil[clientIdx]);
					
				// taken from default_abilities, modified only lightly
				float multiplier = DJ_Multiplier[clientIdx];
				int bossIdx = FF2_GetBossIndex(clientIdx);
				static float position[3];
				static float velocity[3];
				GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", position);
				GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", velocity);

				if (!DJ_UseCrappyJump[clientIdx])
				{
					if (DJ_EmergencyReady[clientIdx])
					{
						velocity[2] = (750 + (chargePercent / 4) * 13.0) + 2000 * multiplier;
						DJ_EmergencyReady[clientIdx] = false;
					}
					else
					{
						velocity[2] = (750 + (chargePercent / 4) * 13.0) * multiplier;
					}
					SetEntProp(clientIdx, Prop_Send, "m_bJumping", 1);
					velocity[0] *= (1 + Sine((chargePercent / 4) * FLOAT_PI / 50)) * multiplier;
					velocity[1] *= (1 + Sine((chargePercent / 4) * FLOAT_PI / 50)) * multiplier;
				}
				else
				{
					if (DJ_EmergencyReady[clientIdx])
					{
						velocity[0] += Cosine(DegToRad(eyeAngles[0])) * Cosine(DegToRad(eyeAngles[1])) * 500 * multiplier;
						velocity[1] += Cosine(DegToRad(eyeAngles[0])) * Sine(DegToRad(eyeAngles[1])) * 500 * multiplier;
						velocity[2] = (750.0 + 175.0 * chargePercent / 70 + 2000) * multiplier;
						DJ_EmergencyReady[clientIdx] = false;
					}
					else
					{
						velocity[0] += Cosine(DegToRad(eyeAngles[0])) * Cosine(DegToRad(eyeAngles[1])) * 100 * multiplier;
						velocity[1] += Cosine(DegToRad(eyeAngles[0])) * Sine(DegToRad(eyeAngles[1])) * 100 * multiplier;
						velocity[2] = (750.0 + 175.0 * chargePercent / 70) * multiplier;
					}
				}

				TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, velocity);
				static char sound[PLATFORM_MAX_PATH];
				if (FF2_RandomSound("sound_ability", sound, PLATFORM_MAX_PATH, bossIdx, DJ_UseReload[clientIdx] ? 0b1000 /* CT_UNUSED_DEMO */ : 0b100 /* CT_CHARGE */ ))
				{
					EmitSoundToAll(sound, clientIdx, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, clientIdx, position, NULL_VECTOR, true, 0.0);
					EmitSoundToAll(sound, clientIdx, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, clientIdx, position, NULL_VECTOR, true, 0.0);

					for (int enemy = 1; enemy < MAX_PLAYERS; enemy++)
					{
						if (IsClientInGame(enemy) && enemy != clientIdx)
						{
							EmitSoundToClient(enemy, sound, clientIdx, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, clientIdx, position, NULL_VECTOR, true, 0.0);
							EmitSoundToClient(enemy, sound, clientIdx, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, clientIdx, position, NULL_VECTOR, true, 0.0);
						}
					}
				}
				
				// decrement uses remaining
				DJ_UsesRemaining[clientIdx]--;
			}
			
			// regardless of outcome, cancel the charge.
			DJ_CrouchOrAltFireDownSince[clientIdx] = FAR_FUTURE;
		}
	}
		
	// draw the HUD if it's time
	if (curTime >= DJ_UpdateHUDAt[clientIdx])
	{
		if (!__IsHUDVisible(FF2Player(clientIdx)) || DD_BypassHUDRestrictions[clientIdx])
		{
			if (DJ_EmergencyReady[clientIdx])
			{
				SetHudTextParams(-1.0, HUD_Y, HUD_INTERVAL + HUD_LINGER, HUD_R_ERROR, HUD_G_ERROR, HUD_B_ERROR, HUD_ALPHA);
				ShowSyncHudText(clientIdx, DD_HUDHandle, DJ_EmergencyJumpString);
			}
			else if (DJ_OnCooldownUntil[clientIdx] == FAR_FUTURE)
			{
				SetHudTextParams(-1.0, HUD_Y, HUD_INTERVAL + HUD_LINGER, HUD_R_OK, HUD_G_OK, HUD_B_OK, HUD_ALPHA);
				ShowSyncHudText(clientIdx, DD_HUDHandle, DJ_JumpReadyString, chargePercent);
			}
			else
			{
				SetHudTextParams(-1.0, HUD_Y, HUD_INTERVAL + HUD_LINGER, HUD_R_ERROR, HUD_G_ERROR, HUD_B_ERROR, HUD_ALPHA);
				ShowSyncHudText(clientIdx, DD_HUDHandle, DJ_JumpCooldownString, DJ_OnCooldownUntil[clientIdx] - curTime);
			}
		}
		
		DJ_UpdateHUDAt[clientIdx] = curTime + HUD_INTERVAL;
	}
}

/**
 * Teleport code, used by Dynamic Teleport, Reverse Teleport, and outside teleport calls
 */
public bool TestTeleportLocation(int clientIdx, float origin[3], float targetPos[3], float xOffset, float yOffset, float zOffset)
{
	// test the path to the offset, ensure no obstructions
	static float endPos[3];
	targetPos[0] = origin[0] + xOffset;
	targetPos[1] = origin[1] + yOffset;
	targetPos[2] = origin[2] + zOffset;
	
	static float mins[3];
	static float maxs[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecMins", mins);
	GetEntPropVector(clientIdx, Prop_Send, "m_vecMaxs", maxs);
	Handle trace = TR_TraceHullFilterEx(origin, targetPos, mins, maxs, MASK_PLAYERSOLID, TraceWallsOnly);
	TR_GetEndPosition(endPos, trace);
	CloseHandle(trace);
	
	// first, the distance check
	if (GetVectorDistance(origin, endPos, true) < GetVectorDistance(origin, targetPos, true))
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[ff2_dynamic_defaults] Distance check failed. Start: %f,%f,%f    End: %f,%f,%f", origin[0], origin[1], origin[2], endPos[0], endPos[1], endPos[2]);
		return false;
	}
		
	// if this is just a teleport above, we've already succeeded
	if (xOffset == 0.0 && yOffset == 0.0)
		return true;
		
	// otherwise, do the pit test, ensuring the teleporter doesn't teleport above a hole (don't want unreachable players)
	static float pitFailPos[3];
	pitFailPos[0] = targetPos[0];
	pitFailPos[1] = targetPos[1];
	pitFailPos[2] = targetPos[2] - 40.0;
	trace = TR_TraceHullFilterEx(targetPos, pitFailPos, mins, maxs, MASK_PLAYERSOLID, TraceWallsOnly);
	TR_GetEndPosition(endPos, trace);
	CloseHandle(trace);
	
	if (GetVectorDistance(targetPos, endPos, true) >= GetVectorDistance(targetPos, pitFailPos, true))
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[ff2_dynamic_defaults] Pit test failed. Start: %f,%f,%f    End: %f,%f,%f", targetPos[0], targetPos[1], targetPos[2], endPos[0], endPos[1], endPos[2]);
		return false;
	}
	
	// success!
	return true;
}

public bool DD_PerformTeleport(int clientIdx, float stunDuration, bool tryAbove, bool trySide, bool sameTeam, bool reverseTeleport)
{
	// teleport code, which only uses light sprinkles of the original
	int target = FindRandomPlayer(GetClientTeam(clientIdx) == BossTeam ? sameTeam : !sameTeam, NULL_VECTOR, 0.0, false, clientIdx, true);
	if (IsLivingPlayer(target))
	{
		// the rare practical use for an xor swap :p
		if (reverseTeleport)
		{
			clientIdx ^= target;
			target ^= clientIdx;
			clientIdx ^= target;
		}
		
		static float targetOrigin[3];
		static float teleportCoords[3];
		bool coordsSet = false;
		bool mayNeedToDuck = false;
		GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetOrigin);

		if (GetEntPropFloat(clientIdx, Prop_Send, "m_flModelScale") < GetEntPropFloat(target, Prop_Send, "m_flModelScale"))
		{
			tryAbove = false;
			trySide = false;
		}

		// try teleporting above
		if (!coordsSet && tryAbove)
			coordsSet = TestTeleportLocation(clientIdx, targetOrigin, teleportCoords, 0.0, 0.0, 85.0);

		// try teleporting to the side. also, lol at this little arrangement.
		if (!coordsSet && trySide)
			if (!(coordsSet = TestTeleportLocation(clientIdx, targetOrigin, teleportCoords, 50.0, 0.0, 0.0)))
				if (!(coordsSet = TestTeleportLocation(clientIdx, targetOrigin, teleportCoords, -50.0, 0.0, 0.0)))
					if (!(coordsSet = TestTeleportLocation(clientIdx, targetOrigin, teleportCoords, 0.0, 50.0, 0.0)))
						coordsSet = TestTeleportLocation(clientIdx, targetOrigin, teleportCoords, 0.0, -50.0, 0.0);

		// hellooooooo up there...also, if all these have failed, time to fall back to what is guaranteed to work
		if (!coordsSet)
		{
			coordsSet = true;
			mayNeedToDuck = true;
			teleportCoords[0] = targetOrigin[0];
			teleportCoords[1] = targetOrigin[1];
			teleportCoords[2] = targetOrigin[2];
		}

		// stun before teleport
		if (stunDuration > 0.0)
		{
			TF2_StunPlayer(clientIdx, stunDuration, 0.0, TF_STUNFLAGS_SMALLBONK | TF_STUNFLAG_NOSOUNDOREFFECT);
		}

		// now, teleport!
		if (mayNeedToDuck)
		{
			// credit to FF2 base for this "force ducking" code
			SetEntPropVector(clientIdx, Prop_Send, "m_vecMaxs", view_as<float>({24.0, 24.0, 62.0}));
			SetEntProp(clientIdx, Prop_Send, "m_bDucked", 1);
			SetEntityFlags(clientIdx, GetEntityFlags(clientIdx) | FL_DUCKING);
		}
		TeleportEntity(clientIdx, teleportCoords, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
		
		DT_GoombaBlockedUntil[clientIdx] = GetEngineTime() + 2.0;
		return true;
	}
	
	return false;
}

/**
 * Dynamic Teleport
 */
public Action DT_CheckTeleAttack(int victim,int  &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePos[3], int damagecustom)
{
	if (IsLivingPlayer(attacker))
	{
		// block hale attacks when they shouldn't be able to deliver them
		if (DT_CanUse[attacker] && DT_BlockAttacksUntil[attacker] != FAR_FUTURE)
		{
			if (weapon == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee) && attacker == inflictor)
			{
				if (PRINT_DEBUG_INFO)
					PrintToServer("[ff2_dynamic_defaults] %d attempted TeleAttack exploit against %d, but it was blocked.", attacker, victim);
				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

public void DT_Tick(int clientIdx,int  buttons, float curTime)
{
	// this must be called even if teleport is disabled
	if (curTime >= DT_BlockAttacksUntil[clientIdx])
		DT_BlockAttacksUntil[clientIdx] = FAR_FUTURE;

	if (DT_IsDisabled[clientIdx] || DT_UsesRemaining[clientIdx] == 0)
		return;
		
	if (curTime >= DT_OnCooldownUntil[clientIdx])
		DT_OnCooldownUntil[clientIdx] = FAR_FUTURE;
		
	float chargePercent = 0.0;
	if (DT_OnCooldownUntil[clientIdx] == FAR_FUTURE)
	{
		// get charge percent here, used by both the HUD and the actual jump
		if (DT_CrouchOrAltFireDownSince[clientIdx] != FAR_FUTURE)
		{
			if (DT_ChargeTime[clientIdx] <= 0.0)
				chargePercent = 100.0;
			else
				chargePercent = fmin((curTime - DT_CrouchOrAltFireDownSince[clientIdx]) / DT_ChargeTime[clientIdx], 1.0) * 100.0;
		}
			
		int validButtons = DT_UseReload[clientIdx] ? SJ_TP_BUTTONS_RELOAD : SJ_TP_BUTTONS_ALT_FIRE;
		
		// do we start the charging now?
		if (DT_CrouchOrAltFireDownSince[clientIdx] == FAR_FUTURE && (buttons & validButtons) != 0)
			DT_CrouchOrAltFireDownSince[clientIdx] = curTime;
			
		// has key been released?
		if (DT_CrouchOrAltFireDownSince[clientIdx] != FAR_FUTURE && (buttons & validButtons) == 0)
		{
			// is user's eye angle valid? if so, perform the jump
			static float eyeAngles[3];
			GetClientEyeAngles(clientIdx, eyeAngles);
			if (eyeAngles[0] <= JUMP_TELEPORT_MAX_ANGLE && !IsInInvalidCondition(clientIdx) && (chargePercent >= 100.0 || DT_EmergencyReady[clientIdx]))
			{
				// taken from default_abilities, modified only lightly
				int bossIdx = FF2_GetBossIndex(clientIdx);
				static float bossOrigin[3];
				GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
				
				// perform teleport has been made its own thing now...
				float stunDuration = DT_StunDuration[clientIdx] * (DT_EmergencyReady[clientIdx] ? 2.0 : 1.0);
				if (DD_PerformTeleport(clientIdx, view_as<float>(stunDuration), DT_TryTeleportAbove[clientIdx], DT_TryTeleportSide[clientIdx], DT_SameTeam[clientIdx], DT_IsReverseTeleport[clientIdx]))
				{
					// unlike the original, I'm managing cooldown myself. so lets do it now.
					DT_OnCooldownUntil[clientIdx] = curTime + DT_Cooldown[clientIdx];
					
					if (stunDuration > 0.0)
						DT_BlockAttacksUntil[clientIdx] = curTime + stunDuration;

					// emergency teleport no longer needs to be ready
					DT_EmergencyReady[clientIdx] = false;
					
					// attach the particle...which I had no idea existed since it's broken in 1.9.2. lol
					static char particleName[MAX_EFFECT_NAME_LENGTH];
					FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DT_STRING, 3, particleName, MAX_EFFECT_NAME_LENGTH);
					if (strlen(particleName) > 0)
					{
						int particle = AttachParticle(clientIdx, particleName);
						if (IsValidEntity(particle))
							CreateTimer(3.0, Timer_RemoveEntity, EntIndexToEntRef(particle));		
					}
				}
				else if (strlen(DT_NoMinionString) > 0)
				{
					PrintToChat(clientIdx, "[FF2] %s", DT_NoMinionString);
					PrintCenterText(clientIdx, DT_NoMinionString);
				}
				
				// play the sound
				static char sound[PLATFORM_MAX_PATH];
				if (FF2_RandomSound("sound_ability", sound, PLATFORM_MAX_PATH, bossIdx, DT_UseReload[clientIdx] ? 0b1000 /* CT_UNUSED_DEMO */ : 0b100 /* CT_CHARGE */))
				{
					EmitSoundToAll(sound, clientIdx, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, clientIdx, bossOrigin, NULL_VECTOR, true, 0.0);
					EmitSoundToAll(sound, clientIdx, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, clientIdx, bossOrigin, NULL_VECTOR, true, 0.0);

					for (int enemy = 1; enemy < MAX_PLAYERS; enemy++)
					{
						if (IsClientInGame(enemy) && enemy != clientIdx)
						{
							EmitSoundToClient(enemy, sound, clientIdx, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, clientIdx, bossOrigin, NULL_VECTOR, true, 0.0);
							EmitSoundToClient(enemy, sound, clientIdx, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, clientIdx, bossOrigin, NULL_VECTOR, true, 0.0);
						}
					}
				}
				
				// decrement uses remaining
				DT_UsesRemaining[clientIdx]--;
			}
			
			// regardless of outcome, cancel the charge.
			DT_CrouchOrAltFireDownSince[clientIdx] = FAR_FUTURE;
		}
	}
		
	// draw the HUD if it's time
	if (curTime >= DT_UpdateHUDAt[clientIdx] && (buttons & IN_SCORE) == 0)
	{
		if (!__IsHUDVisible(FF2Player(clientIdx)) || DD_BypassHUDRestrictions[clientIdx])
		{
			if (!(DJ_ActiveThisRound && DJ_CanUse[clientIdx] && !DJ_IsDisabled[clientIdx]))
			{
				if (DT_EmergencyReady[clientIdx])
				{
					SetHudTextParams(-1.0, HUD_Y, HUD_INTERVAL + HUD_LINGER, HUD_R_ERROR, HUD_G_ERROR, HUD_B_ERROR, HUD_ALPHA);
					ShowSyncHudText(clientIdx, DD_HUDHandle, DT_EmergencyTeleportString);
				}
				else if (DT_OnCooldownUntil[clientIdx] == FAR_FUTURE)
				{
					SetHudTextParams(-1.0, HUD_Y, HUD_INTERVAL + HUD_LINGER, HUD_R_OK, HUD_G_OK, HUD_B_OK, HUD_ALPHA);
					ShowSyncHudText(clientIdx, DD_HUDHandle, DT_TeleportReadyString, chargePercent);
				}
				else
				{
					SetHudTextParams(-1.0, HUD_Y, HUD_INTERVAL + HUD_LINGER, HUD_R_ERROR, HUD_G_ERROR, HUD_B_ERROR, HUD_ALPHA);
					ShowSyncHudText(clientIdx, DD_HUDHandle, DT_TeleportCooldownString, DT_OnCooldownUntil[clientIdx] - curTime);
				}
			}
		}
		
		DT_UpdateHUDAt[clientIdx] = curTime + HUD_INTERVAL;
	}
}

/**
 * Dynamic Weighdown
 */
public void DW_Tick(int clientIdx, int buttons, float curTime)
{
	if (DW_IsDisabled[clientIdx])
		return;
		
	if (curTime >= DW_RestoreGravityAt[clientIdx])
	{
		SetEntityGravity(clientIdx, DW_DefaultGravity[clientIdx]);
		DW_RestoreGravityAt[clientIdx] = FAR_FUTURE;
	}
	
	if (curTime >= DW_OnCooldownUntil[clientIdx])
		DW_OnCooldownUntil[clientIdx] = FAR_FUTURE;
		
	if (DW_UsesRemaining[clientIdx] == 0)
		return; // no more uses.
		
	if (DW_OnCooldownUntil[clientIdx] == FAR_FUTURE)
	{
		if (buttons & IN_DUCK)
		{
			static float eyeAngles[3];
			GetClientEyeAngles(clientIdx, eyeAngles);
			
			if (eyeAngles[0] >= WEIGHDOWN_MIN_ANGLE && !IsInInvalidCondition(clientIdx))
			{
				SetEntityGravity(clientIdx, 6.0);
				DW_OnCooldownUntil[clientIdx] = curTime + 2.0;
				DW_RestoreGravityAt[clientIdx] = curTime + 2.0;
				DW_UsesRemaining[clientIdx]--;
				
				PrintToChat(clientIdx, DW_UsageString);
			}
		}
	}
}

/**
 * Dynamic Glide
 */
public void DG_Tick(int clientIdx, int buttons, float curTime)
{
	bool spaceBarIsDown = (buttons & IN_JUMP) != 0;
	bool onGround = (GetEntityFlags(clientIdx) & FL_ONGROUND) != 0;
	
	bool shouldActivate = false;
	bool shouldDeactivate = false;
	if (DG_UseHoldControls[clientIdx])
	{
		shouldActivate = (!DG_SpaceBarWasDown[clientIdx] && spaceBarIsDown);
		shouldDeactivate = (DG_SpaceBarWasDown[clientIdx] && !spaceBarIsDown);
	}
	else
	{
		shouldActivate = !DG_IsUsing[clientIdx] && (!DG_SpaceBarWasDown[clientIdx] && spaceBarIsDown);
		shouldDeactivate = DG_IsUsing[clientIdx] && (!DG_SpaceBarWasDown[clientIdx] && spaceBarIsDown);
	}

	// stop using if user releases key, if user is on ground, if user's rage ended and it's a rage-only ability, or if it's passed the max duration
	if (DG_IsUsing[clientIdx] && (shouldDeactivate || (onGround) || (DG_IsDisabled[clientIdx]) || (DG_SingleUseStartTime[clientIdx] + DG_MaxDuration[clientIdx] <= curTime)))
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[ff2_dynamic_defaults] Glide stopped for %d", clientIdx);

		// stop gliding
		DG_IsUsing[clientIdx] = false;

		// cooldown info needed
		DG_SingleUseEndTime[clientIdx] = curTime;
	}
	else if (!DG_IsUsing[clientIdx] && shouldActivate && !onGround)
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[ff2_dynamic_defaults] Glide may start for %d (if cooldown/rage check passes)", clientIdx);

		// but first check cooldown and if user is in a rage if such is required
		if (!DG_IsDisabled[clientIdx] && DG_SingleUseEndTime[clientIdx] + DG_Cooldown[clientIdx] <= curTime)
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[ff2_dynamic_defaults] Glide started for %d", clientIdx);

			// start gliding
			DG_IsUsing[clientIdx] = true;
			DG_SingleUseStartTime[clientIdx] = curTime;

			// play sound
			if (strlen(DG_UseSound) > 3)
				PlaySoundLocal(clientIdx, DG_UseSound, true, 3);
		}
	}

	// slow the player
	if (DG_IsUsing[clientIdx])
	{
		float currentVelocityLimit = -(DG_OriginalMaxVelocity[clientIdx] + ((curTime - DG_SingleUseStartTime[clientIdx]) * DG_DecayPerSecond[clientIdx]));

		float vecVelocity[3];
		GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", vecVelocity);
		if (vecVelocity[2] < currentVelocityLimit)
			vecVelocity[2] = currentVelocityLimit;
		SetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", vecVelocity);
		TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, vecVelocity);
	}

	DG_SpaceBarWasDown[clientIdx] = spaceBarIsDown;
}

/**
 * Dynamic StunSG
 */
public void DSSG_PerformStun(int clientIdx, float radius, float duration) // ALSO AN EXPOSED INTERFACE
{
	static float bossOrigin[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
	DSSG_PerformStunFromCoords(clientIdx, bossOrigin[0], bossOrigin[1], bossOrigin[2], radius, duration);
}

public void DSSG_PerformStunFromCoords(int clientIdx, float x, float y, float z, float radius, float duration) // ALSO AN EXPOSED INTERFACE
{
	if (radius <= 0.0 || duration <= 0.0)
	{
		if (PRINT_DEBUG_INFO)
			PrintToServer("[ff2_dynamic_defaults] ERROR: Sentry stun duration/radius must be above 0. radius=%f duration=%f", radius, duration);
	}
	
	static float stunOrigin[3];
	stunOrigin[0] = x;
	stunOrigin[1] = y;
	stunOrigin[2] = z;

	// stun sentries laster than last
	float radiusSquared = radius * radius;
	int sentry = -1;
	while ((sentry = FindEntityByClassname(sentry, "obj_sentrygun")) != -1)
	{
		if (GetEntProp(sentry, Prop_Send, "m_bCarried") || GetEntProp(sentry, Prop_Send, "m_bPlacing"))
			continue; // invalid
			
		// ensure sentry's team is correct, for very rare cases like the mann bros hale or the summon ability
		if ((GetEntProp(sentry, Prop_Send, "m_nSkin") % 2) == (GetClientTeam(clientIdx) % 2))
			continue;
	
		static float sentryOrigin[3];
		GetEntPropVector(sentry, Prop_Send, "m_vecOrigin", sentryOrigin);
		if (GetVectorDistance(sentryOrigin, stunOrigin, true) > radiusSquared)
			continue;
		
		DSSG_StunOneSentry(sentry, duration);
	}
}

public void DSSG_StunOneSentry(int sentry, float duration)
{
	for (int i = 0; i < MAX_SENTRIES; i++)
	{
		if (DSSG_EntRef[i] == INVALID_ENTREF)
		{
			// if we're here, it means a int sentry stun has occured
			DSSG_EntRef[i] = EntIndexToEntRef(sentry);
			DSSG_ParticleEntRef[i] = EntIndexToEntRef(AttachParticle(sentry, "yikes_fx", 75.0));
			DSSG_UnstunAt[i] = GetEngineTime() + duration;
			DSSG_NormalAmmo[i] = GetEntProp(sentry, Prop_Send, "m_iAmmoShells");
			DSSG_RocketAmmo[i] = GetEntProp(sentry, Prop_Send, "m_iAmmoRockets");
			SetEntProp(sentry, Prop_Send, "m_bDisabled", 1);
			break;
		}
		else if (sentry == EntRefToEntIndex(DSSG_EntRef[i]))
		{
			// just extend the duration of an existing sentry stun
			DSSG_UnstunAt[i] = fmax(GetEngineTime() + duration, DSSG_UnstunAt[i]);
			break;
		}
	}
}

public void DSSG_UnstunOneSentry(int sentry)
{
	for (int i = 0; i < MAX_SENTRIES; i++)
	{
		if (DSSG_EntRef[i] == INVALID_ENTREF)
			break;
		else if (sentry == EntRefToEntIndex(DSSG_EntRef[i]))
		{
			DSSG_PerformUnstunActions(sentry, i);
			break;
		}
	}
}

public void DSSG_PerformUnstunActions(int sentry, int i)
{
	SetEntProp(sentry, Prop_Send, "m_bDisabled", 0);
	if (DSSG_NormalAmmo[i] > 0)
		SetEntProp(sentry, Prop_Send, "m_iAmmoShells", DSSG_NormalAmmo[i]);
	if (DSSG_RocketAmmo[i] > 0)
		SetEntProp(sentry, Prop_Send, "m_iAmmoRockets", DSSG_RocketAmmo[i]);
	DSSG_RemoveSentry(i);
}

public void DSSG_RemoveSentry(int sentryIdx)
{
	if (DSSG_ParticleEntRef[sentryIdx] != INVALID_ENTREF)
		RemoveEntity(DSSG_ParticleEntRef[sentryIdx]);
	DSSG_EntRef[sentryIdx] = INVALID_ENTREF;
	
	for (int i = sentryIdx; i < MAX_SENTRIES - 1; i++)
	{
		DSSG_EntRef[i] = DSSG_EntRef[i+1];
		DSSG_ParticleEntRef[i] = DSSG_ParticleEntRef[i+1];
		DSSG_UnstunAt[i] = DSSG_UnstunAt[i+1];
		DSSG_NormalAmmo[i] = DSSG_NormalAmmo[i+1];
		DSSG_RocketAmmo[i] = DSSG_RocketAmmo[i+1];
	}
	
	DSSG_EntRef[MAX_SENTRIES - 1] = INVALID_ENTREF;
}

public void DSSG_Tick(float curTime)
{
	for (int i = MAX_SENTRIES - 1; i >= 0; i--)
	{
		if (DSSG_EntRef[i] == INVALID_ENTREF)
			continue;
		
		int sentry = EntRefToEntIndex(DSSG_EntRef[i]);
		if (!IsValidEntity(sentry))
		{
			DSSG_RemoveSentry(i);
			continue;
		}
		
		if (curTime >= DSSG_UnstunAt[i])
		{
			DSSG_PerformUnstunActions(sentry, i);
			continue;
		}
		else if (GetEntProp(sentry, Prop_Send, "m_bDisabled") != 1)
		{
			// workaround for sentry being unstunned early due to the Cow Mangler charged shot
			SetEntProp(sentry, Prop_Send, "m_bDisabled", 1);
		}
	}
}

/**
 * Dynamic Speed Management
 */
public void DSM_PreThink(int clientIdx)
{
	if (IsLivingPlayer(clientIdx) && DSM_CanUse[clientIdx] && DSM_ActiveThisRound)
	{
		// it's imprecise, but it's the only way to deal with the multiple life problem while
		// maintaining backwards compatibility.
		if (DSM_MaxHP[clientIdx] <= 0)
		{
			int hp = GetEntProp(clientIdx, Prop_Send, "m_iHealth");
			if (hp > 500)
				DSM_MaxHP[clientIdx] = hp;

			if (DSM_MaxHP[clientIdx] <= 0)
				return;
		}

		float primaryModifier = 1.0;
		float conditionModifier = 1.0;
		
		// grab the player's primary weapon now, which is important for various calculations
		int primary = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary);
		bool primaryIsCurrent = (IsValidEntity(primary) && primary == GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon"));
		
		// weapon positives first
		bool bfbExists = false;
		if (IsValidEntity(primary) && IsInstanceOf(primary, "tf_weapon_pep_brawler_blaster")) // bfb
		{
			primaryModifier *= 1.0 + ((fmin(GetEntPropFloat(clientIdx, Prop_Send, "m_flHypeMeter"), 100.0) / 100.0) * DSM_BFBModifier[clientIdx]);
			if (DSM_UseBFB[clientIdx])
				bfbExists = true;
		}
		
		// next weapon negatives, which are not nullified by megaheal and need to disable the "slowed" condition
		bool slowedByWeapon = false;
		if (primaryIsCurrent)
		{
			slowedByWeapon = true;
			if (IsInstanceOf(primary, "tf_weapon_minigun") && GetEntProp(primary, Prop_Send, "m_iWeaponState") != 0)
				primaryModifier *= DSM_MinigunModifier[clientIdx]; // source: https://wiki.teamfortress.com/wiki/Minigun
			else if (IsInstanceOf(primary, "tf_weapon_compound_bow") && GetEntPropFloat(primary, Prop_Send, "m_flChargeBeginTime") > 0.0)
				primaryModifier *= DSM_BowModifier[clientIdx];
			else if (EntityStartsWith(primary, "tf_weapon_sniperrifle") && (GetEntPropFloat(primary, Prop_Send, "m_flChargedDamage") > 0.0 || TF2_IsPlayerInCondition(clientIdx, TFCond_Zoomed)) )
				primaryModifier *= DSM_RifleModifier[clientIdx];
			else
				slowedByWeapon = false;
		}
		
		// condition negatives
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed))
			conditionModifier *= DSM_DazedModifier[clientIdx];
		//else if (TF2_IsPlayerInCondition(clientIdx, TFCond_Slowed) && !slowedByWeapon)
		//	conditionModifier *= DSM_SlowedModifier[clientIdx];
		
		// slowed seems to automatically happen. need to override weapon slows
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_Slowed) && slowedByWeapon)
			TF2_RemoveCondition(clientIdx, TFCond_Slowed);
			
		// negatives are nullified by megaheal and condition 103
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_MegaHeal) || TF2_IsPlayerInCondition(clientIdx, view_as<TFCond>(103)))
			conditionModifier = 1.0;
			
		// finally, condition positives
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_CritCola))
			conditionModifier *= bfbExists ? (1.0 + ((DSM_CritAColaModifier[clientIdx] - 1.0) * 0.5)) : DSM_CritAColaModifier[clientIdx];
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_SpeedBuffAlly) ||
				TF2_IsPlayerInCondition(clientIdx, TFCond_RegenBuffed) || TF2_IsPlayerInCondition(clientIdx, TFCond_HalloweenSpeedBoost))
			conditionModifier *= bfbExists ? (1.0 + ((DSM_WhipModifier[clientIdx] - 1.0) * 0.5)) : DSM_WhipModifier[clientIdx];
		
		float modifier = primaryModifier * conditionModifier;
		
		int maxHP = DSM_MaxHP[clientIdx];
		if (maxHP > 0)
		{
			float baseSpeed = DSM_LowSpeed[clientIdx] + ((1.0 - (float(GetEntProp(clientIdx, Prop_Send, "m_iHealth")) / float(maxHP))) * (DSM_HighSpeed[clientIdx] - DSM_LowSpeed[clientIdx]));
			if (DSM_OverrideSpeed[clientIdx] != -1.0)
			{
				baseSpeed = DSM_OverrideSpeed[clientIdx];
				if (!DSM_OverrideUseModifiers[clientIdx])
					modifier = 1.0;
			}

			if (!(DSM_OverrideSpeed[clientIdx] != -1.0 && !DSM_OverrideUseModifiers[clientIdx]))
			{
				if (DSM_UseDisguiseSpeed[clientIdx] || DSM_DisguiseCanIncreaseSpeed[clientIdx])
				{
					int disguiseTarget = GetEntProp(clientIdx, Prop_Send, "m_iDisguiseTargetIndex");
					if (disguiseTarget > 0 && disguiseTarget < MAX_PLAYERS)
					{
						TFClassType disguiseClass = view_as<TFClassType>(GetEntProp(clientIdx, Prop_Send, "m_nDisguiseClass"));
						float maxSpeed = 300.0;
						if (disguiseClass == TFClass_Heavy)
							maxSpeed = 230.0;
						else if (disguiseClass == TFClass_Soldier)
							maxSpeed = 240.0;
						else if (disguiseClass == TFClass_DemoMan)
							maxSpeed = 280.0;
						else if (disguiseClass == TFClass_Medic)
							maxSpeed = 320.0;
						else if (disguiseClass == TFClass_Scout)
							maxSpeed = 400.0;
							
						if (DSM_UseDisguiseSpeed[clientIdx])
							baseSpeed = fmin(baseSpeed, maxSpeed);
						if (DSM_DisguiseCanIncreaseSpeed[clientIdx])
							baseSpeed = fmax(baseSpeed, maxSpeed);
					}
				}
			}
			SetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed", modifier * baseSpeed);
		}
	}
}

public void DSM_ValidateModifier(float &value, bool &canUse, float defaultValue)
{
	if (!canUse)
		value = 1.0;
	else if (value <= 0.0)
		value = defaultValue;
	else if (value == 1.0)
		canUse = false;
}

/**
 * Dynamic Melee Management - For when you absolutely positively need your weapon stats to be accurate.
 */
public void DMM_ResetWeapon(int clientIdx) // also an exposed interface
{
	if (!DMM_ActiveThisRound || !DMM_CanUse[clientIdx])
		return;
		
	int bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;

	static char weaponName[MAX_WEAPON_NAME_LENGTH];
	static char weaponArgs[MAX_WEAPON_ARG_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DMM_STRING, 1, weaponName, MAX_WEAPON_NAME_LENGTH);
	int weaponIdx = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DMM_STRING, 2);
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DMM_STRING, 3, weaponArgs, MAX_WEAPON_ARG_LENGTH);
	int weaponVisibility = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DMM_STRING, 4);
	
	PrepareForWeaponSwitch(clientIdx);
	TF2_RemoveWeaponSlot(clientIdx, TFWeaponSlot_Melee);
	int weapon = SpawnWeapon(clientIdx, weaponName, weaponIdx, 101, 5, weaponArgs, weaponVisibility);
	SetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon", weapon);
}

/**
 * Dynamic Parkour
 */
public void DP_SetTempWeapon(int clientIdx, bool shouldRemove)
{
	if (!DP_ShouldWeaponSwitch[clientIdx])
		return;
	
	int bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;
		
	int slot = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DP_STRING, 21);
	PrepareForWeaponSwitch(clientIdx);
	TF2_RemoveWeaponSlot(clientIdx, slot);
	if (shouldRemove)
	{
		if (slot == TFWeaponSlot_Melee)
			DMM_ResetWeapon(clientIdx);
	}
	else
	{
		static char weaponName[MAX_WEAPON_NAME_LENGTH];
		static char weaponArgs[MAX_WEAPON_ARG_LENGTH];
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DP_STRING, 22, weaponName, MAX_WEAPON_NAME_LENGTH);
		int weaponIdx = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DP_STRING, 23);
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DP_STRING, 24, weaponArgs, MAX_WEAPON_ARG_LENGTH);

		int weapon = SpawnWeapon(clientIdx, weaponName, weaponIdx, 101, 5, weaponArgs, 0);
		if (IsValidEntity(weapon))
		{
			SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
			SetEntityRenderColor(weapon, 255, 255, 255, 0);
			SetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon", weapon);
			SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 999999.0);
		}
	}
}

public void DP_Latch(int clientIdx, float curTime)
{
	DP_Latched[clientIdx] = true;
	DD_SetDisabled(clientIdx, true, true, true, true);
	SetEntityGravity(clientIdx, 0.00001); // can't set it to 0.0, as I learned with danmaku fortress...but this works!
	DSM_SetOverrideSpeed(clientIdx, 0.0, false); // do this to minimize the influence of the standard controls
	SetEntProp(clientIdx, Prop_Send, "m_iAirDash", 9999); // prevent double jumps
	DP_ResetAirJumpsAt[clientIdx] = FAR_FUTURE;
	DP_NextMoveAt[clientIdx] = curTime;
	DP_SetTempWeapon(clientIdx, false);
}

public void DP_Unlatch(int clientIdx, float curTime)
{
	DP_Latched[clientIdx] = false;
	DP_KnockbackImmuneUntil[clientIdx] = curTime + DP_KnockbackImmunityLinger[clientIdx];
	DD_SetDisabled(clientIdx, false, false, false, false);
	SetEntityGravity(clientIdx, 1.0);
	DSM_SetOverrideSpeed(clientIdx, -1.0, true);
	DP_ResetAirJumpsAt[clientIdx] = curTime + 0.05;
	DP_SetTempWeapon(clientIdx, true);
}

public Action DP_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePos[3], int damagecustom)
{
	if (!IsLivingPlayer(victim) || !DP_ShouldKnockbackImmune[victim])
		return Plugin_Continue;

	if (DP_Latched[victim] || GetEngineTime() < DP_KnockbackImmuneUntil[victim])
	{
		damagetype |= DMG_PREVENT_PHYSICS_FORCE;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public void DP_OnDeflect(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "ownerid"));
	if (!IsLivingPlayer(victim) || !DP_CanUse[victim])
		return;
		
	// unlatch the victim and give them a delay before they can relatch
	if (DP_Latched[victim])
	{
		if (DP_AirblastUnlatchDuration[victim] > 0.0)
		{
			float curTime = GetEngineTime();
			DP_Unlatch(victim, curTime);
			DP_IgnoreActivationUntil[victim] = curTime + DP_AirblastUnlatchDuration[victim];
		}
	}
}

public bool DP_AttemptLatch(int clientIdx)
{
	// ensure the player has decent enough ground clearance and isn't in water
	if (!CheckGroundClearance(clientIdx, DP_REQUIRED_GROUND_CLEARANCE, true))
		return false;

	// a few lazy constants...these constants ensure minimal weird behaviors around displacements
	float feetOffset = 20.0;
	float headOffset = 61.0;
	float headLength = headOffset - feetOffset;
	float increment = 5.0;

	// need head and origin positions
	static float bossFeetPos[3];
	static float bossHeadPos[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossFeetPos);
	CopyVector(bossHeadPos, bossFeetPos);
	bossFeetPos[2] += feetOffset;
	bossHeadPos[2] += headOffset;

	// iterate through a bunch of yaws and see if we should latch
	int iterations = RoundFloat(360.0 / increment);
	float startYaw = 0.0;
	float yaw = startYaw;
	float closestYaw = yaw;
	float closestDistance = 100000000.0;
	for (int i = 0; i < iterations; i++)
	{
		float thisDistance = 100000000.0;
		float tmpDistance;
		yaw = fixAngle(yaw + increment);
		
		static float angle[3];
		angle[0] = angle[2] = 0.0;
		angle[1] = yaw;
		static float endPos[3];
		static float otherEndPos[3];
		
		// trace a line to from the boss' feet outward, and then another line from that point upward
		TR_TraceRayFilter(bossFeetPos, angle, DP_TraceOptions[clientIdx], RayType_Infinite, TraceWallsOnly);
		TR_GetEndPosition(endPos);
		tmpDistance = GetVectorDistance(bossFeetPos, endPos);
		thisDistance = fmin(thisDistance, tmpDistance);
		if (thisDistance > DP_MaxDistance[clientIdx])
		{
			// trace upwards to see if there's something blocking which is fairly short, occupying space between the player's feet and head
			ConformLineDistance(endPos, bossFeetPos, endPos, DP_MaxDistance[clientIdx], false);
			angle[0] = -90.0;
			TR_TraceRayFilter(endPos, angle, DP_TraceOptions[clientIdx], RayType_Infinite, TraceWallsOnly);
			TR_GetEndPosition(otherEndPos);
			if (GetVectorDistance(endPos, otherEndPos) < headLength)
				thisDistance = fmin(thisDistance, DP_MaxDistance[clientIdx] - 0.1);
		}
		
		// now trace a line from the boss' head outward. even if we already know this is a potential latch point, we want the SHORTEST DISTANCE yaw
		angle[0] = 0.0;
		TR_TraceRayFilter(bossHeadPos, angle, DP_TraceOptions[clientIdx], RayType_Infinite, TraceWallsOnly);
		TR_GetEndPosition(endPos);
		tmpDistance = GetVectorDistance(bossHeadPos, endPos);
		thisDistance = fmin(thisDistance, tmpDistance);
		if (thisDistance > DP_MaxDistance[clientIdx])
		{
			// trace downwards to see if there's something blocking which is fairly short, occupying space between the player's head and feet
			// this second trace is not redundant! sometimes crappy map geometry will allow a trace to go one way but not the other.
			ConformLineDistance(endPos, bossHeadPos, endPos, DP_MaxDistance[clientIdx], false);
			angle[0] = 90.0;
			TR_TraceRayFilter(endPos, angle, DP_TraceOptions[clientIdx], RayType_Infinite, TraceWallsOnly);
			TR_GetEndPosition(otherEndPos);
			if (GetVectorDistance(endPos, otherEndPos) < headLength)
				thisDistance = fmin(thisDistance, DP_MaxDistance[clientIdx] - 0.1);
		}
		
		// report if it's the lowest distance yaw so far. this funny logic will allow going left-right around angled walls, but not 90 degree angles
		if (thisDistance < closestDistance)
		{
			closestDistance = thisDistance;
			closestYaw = yaw;
		}
	}
	
	// special logic, to minimize certain weird behaviors. only applies when already latched
	// one weird behavior is not 
	if (DP_Latched[clientIdx])
	{
		static float endPos[3];
		static float otherEndPos[3];
		static float yetAnotherEndPos[3];
		bossFeetPos[2] -= feetOffset;
		bossHeadPos[2] += 81.0 - headOffset;
		bool tossOutYawChanges = false;
		
		// the cheaper one, see if we're balanced on a thin ramp and suddenly getting influenced by the ramp itself, from a different angle
		// most commonly reproduced on a map like vsh_weaponsdepot_final, which has thin ramps by the control point
		bool excessYawShift = fabs(DP_ClimbingYaw[clientIdx] - closestYaw) > 8.0 &&
					fabs(DP_ClimbingYaw[clientIdx] - closestYaw) < (360.0 - 8.0);
		if (excessYawShift)
		{
			static float angle[3];
			angle[0] = angle[2] = 0.0;
			angle[1] = DP_ClimbingYaw[clientIdx]; // the old yaw

			TR_TraceRayFilter(bossFeetPos, angle, DP_TraceOptions[clientIdx], RayType_Infinite, TraceWallsOnly);
			TR_GetEndPosition(endPos);
			TR_TraceRayFilter(bossHeadPos, angle, DP_TraceOptions[clientIdx], RayType_Infinite, TraceWallsOnly);
			TR_GetEndPosition(otherEndPos);
			if (GetVectorDistance(endPos, bossFeetPos) > DP_MaxDistance[clientIdx] && GetVectorDistance(otherEndPos, bossHeadPos) > DP_MaxDistance[clientIdx])
				tossOutYawChanges = true; // but don't do it yet, otherwise the more important test will fail (these two tests can and do overlap)
		}
		
		// the pricier one, test if we're nearing an edge
		excessYawShift = fabs(DP_ClimbingYaw[clientIdx] - closestYaw) > 20.0 &&
					fabs(DP_ClimbingYaw[clientIdx] - closestYaw) < (360.0 - 20.0);
		if (excessYawShift)
		{
			for (int pass = 0; pass < 2; pass++)
			{
				static float angle[3];
				angle[0] = angle[2] = 0.0;
				angle[1] = DP_ClimbingYaw[clientIdx]; // the old yaw
				
				// first we need to trace a little to the sides
				static float tmpAngle[3];
				CopyVector(angle, tmpAngle);
				tmpAngle[1] = fixAngle(tmpAngle[1] + (pass == 0 ? 90.0 : -90.0));
				static float adjHeadPos[3];
				static float adjFeetPos[3];
				TR_TraceRayFilter(bossFeetPos, tmpAngle, DP_TraceOptions[clientIdx], RayType_Infinite, TraceWallsOnly);
				TR_GetEndPosition(adjFeetPos);
				ConformLineDistance(adjFeetPos, bossFeetPos, adjFeetPos, 10.0, false);
				CopyVector(adjHeadPos, adjFeetPos);
				adjHeadPos[2] = bossHeadPos[2];

				// now trace outwards. if we exceed a little over max distance here, we have a problem
				float maxLeeway = 10.0;
				TR_TraceRayFilter(bossFeetPos, angle, DP_TraceOptions[clientIdx], RayType_Infinite, TraceWallsOnly);
				TR_GetEndPosition(endPos);
				TR_TraceRayFilter(bossHeadPos, angle, DP_TraceOptions[clientIdx], RayType_Infinite, TraceWallsOnly);
				TR_GetEndPosition(otherEndPos);
				if (GetVectorDistance(endPos, bossFeetPos) > DP_MaxDistance[clientIdx] + maxLeeway && GetVectorDistance(otherEndPos, bossHeadPos) > DP_MaxDistance[clientIdx] + maxLeeway)
				{
					ConformLineDistance(endPos, bossFeetPos, endPos, DP_MaxDistance[clientIdx] + maxLeeway, false);
					ConformLineDistance(otherEndPos, bossHeadPos, otherEndPos, DP_MaxDistance[clientIdx] + maxLeeway, false);
					angle[0] = 90.0;
					TR_TraceRayFilter(otherEndPos, angle, DP_TraceOptions[clientIdx], RayType_Infinite, TraceWallsOnly);
					TR_GetEndPosition(yetAnotherEndPos);
					if (GetVectorDistance(otherEndPos, yetAnotherEndPos) > bossHeadPos[2] - bossFeetPos[2])
					{
						// again, seemingly redundant test due to many maps have faulty geometry
						angle[0] = -90.0;
						TR_TraceRayFilter(endPos, angle, DP_TraceOptions[clientIdx], RayType_Infinite, TraceWallsOnly);
						TR_GetEndPosition(yetAnotherEndPos);
						if (GetVectorDistance(otherEndPos, yetAnotherEndPos) > bossHeadPos[2] - bossFeetPos[2])
							return false; // we've gone off the edge. time to end this latch and allow the user to fly off.
					}
				}
			}
		}

		if (tossOutYawChanges)
			closestYaw = DP_ClimbingYaw[clientIdx];
	}
	
	DP_ClimbingYaw[clientIdx] = closestYaw;
	return closestDistance <= DP_MaxDistance[clientIdx];
}

public void DP_Tick(int clientIdx, int &buttons, float curTime)
{
	bool justLatched = false; // don't repeat some expensive code
	
	bool activationKeyDown = (buttons & DP_ActivationKey[clientIdx]) != 0;
	if (activationKeyDown && !DP_Latched[clientIdx] && curTime >= DP_IgnoreActivationUntil[clientIdx])
	{
		if (DP_AttemptLatch(clientIdx))
		{
			DP_Latch(clientIdx, curTime);
			justLatched = true;
		}
	}
	else if (!activationKeyDown && DP_Latched[clientIdx])
	{
		// just unceremoniously unlatch. nothing else to do.
		DP_Unlatch(clientIdx, curTime);
	}
	
	// see if should jump (and unlatch) before performing any additional latch-only checks
	bool jumpKeyDown = (buttons & IN_JUMP) != 0;
	if (DP_Latched[clientIdx] && jumpKeyDown && !DP_JumpKeyDown[clientIdx])
	{
		DP_Unlatch(clientIdx, curTime);
		DP_IgnoreActivationUntil[clientIdx] = curTime + DP_GRACE_PERIOD; // a little grace period which allows the jump to execute properly
		
		// perform a wall jump
		static float adjustedAngles[3];
		adjustedAngles[0] = DP_WallJumpPitch[clientIdx];
		if (buttons & IN_MOVELEFT)
			adjustedAngles[1] = fixAngle(DP_ClimbingYaw[clientIdx] + 105.0); // a little outwards so the user clears the wall
		else if (buttons & IN_MOVERIGHT)
			adjustedAngles[1] = fixAngle(DP_ClimbingYaw[clientIdx] - 105.0); // a little outwards so the user clears the wall
		else
			adjustedAngles[1] = fixAngle(DP_ClimbingYaw[clientIdx] + 180.0);
		adjustedAngles[2] = 0.0;
		static float velocity[3];
		GetAngleVectors(adjustedAngles, velocity, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(velocity, DP_WallJumpIntensity[clientIdx]);
		
		TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, velocity);
		buttons &= (~IN_JUMP);
	}
	DP_JumpKeyDown[clientIdx] = jumpKeyDown;
	
	// check for validity of latching and see if we need to reangle
	if (DP_Latched[clientIdx])
	{
		if (!justLatched && !DP_AttemptLatch(clientIdx))
		{
			DP_Unlatch(clientIdx, curTime);
			DP_IgnoreActivationUntil[clientIdx] = curTime + DP_GRACE_PERIOD; // a little grace period which allows the user to move away from the wall
		}
	}
	
	// now for movement along the walls
	if (DP_Latched[clientIdx] && curTime >= DP_NextMoveAt[clientIdx])
	{
		DP_NextMoveAt[clientIdx] = curTime + DP_MOTION_INTERVAL;

		bool forwardPressed = (buttons & IN_FORWARD) != 0;
		bool backPressed = (buttons & IN_BACK) != 0;
		if (justLatched || (forwardPressed && backPressed))
		{
			forwardPressed = false;
			backPressed = false;
		}
		
		bool leftPressed = (buttons & IN_MOVELEFT) != 0;
		bool rightPressed = (buttons & IN_MOVERIGHT) != 0;
		if (justLatched || (leftPressed && rightPressed))
		{
			leftPressed = false;
			rightPressed = false;
		}
		
		static float eyeAngles[3];
		GetClientEyeAngles(clientIdx, eyeAngles);
		eyeAngles[1] = fixAngle(eyeAngles[1]); // angles are a real pain in the arse...since their range in source engine often exceeds 360 degrees
		static float forcedAngle[3];
		forcedAngle[0] = eyeAngles[0];
		forcedAngle[1] = fixAngle(DP_ClimbingYaw[clientIdx]);
		forcedAngle[2] = eyeAngles[2];
		static float motionAngle[3];
		motionAngle[0] = 0.0;
		motionAngle[1] = forcedAngle[1];
		motionAngle[2] = 0.0;

		// moving up and down depends on both the client's eye angles and the motion key being pressed
		bool movingUp = false;
		bool movingDown = false;
		if (forwardPressed)
		{
			if (eyeAngles[0] <= -DP_UDPitchThreshold[clientIdx])
				movingUp = true;
			else if (eyeAngles[0] >= DP_UDPitchThreshold[clientIdx])
				movingDown = true;
		}
		else if (backPressed)
		{
			if (eyeAngles[0] <= -DP_UDPitchThreshold[clientIdx])
				movingDown = true;
			else if (eyeAngles[0] >= DP_UDPitchThreshold[clientIdx])
				movingUp = true;
		}
		
		// regardless of whether the player's moving or not, we need to prevent minor drifts out of the wall
		static float attractVelocity[3];
		GetAngleVectors(motionAngle, attractVelocity, NULL_VECTOR, NULL_VECTOR);
		if (buttons & IN_BACK)
			ScaleVector(attractVelocity, DP_ForwardPushWhileMovingBack[clientIdx]); // geez you have to set it high to counter tf2
		else
			ScaleVector(attractVelocity, DP_NormalForwardPush[clientIdx]); // geez you have to set it high to counter tf2
		
		// test left-right motion
		static float motionVelocity[3];
		motionVelocity[0] = motionVelocity[1] = motionVelocity[2] = 0.0;
		if (leftPressed)
		{
			motionAngle[1] = fixAngle(motionAngle[1] + 90.0);
			if (movingUp)
				motionAngle[0] = -45.0;
			else if (movingDown)
				motionAngle[0] = 45.0;
			GetAngleVectors(motionAngle, motionVelocity, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(motionVelocity, DP_WallClimbIntensity[clientIdx]);
		}
		else if (rightPressed)
		{
			motionAngle[1] = fixAngle(motionAngle[1] - 90.0);
			if (movingUp)
				motionAngle[0] = -45.0;
			else if (movingDown)
				motionAngle[0] = 45.0;
			GetAngleVectors(motionAngle, motionVelocity, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(motionVelocity, DP_WallClimbIntensity[clientIdx]);
		}
		else if (movingUp) // else is intended. diagonal motion is handled above. straight up and down are handled separately.
		{
			motionVelocity[2] = DP_WallClimbIntensity[clientIdx];
		}
		else if (movingDown)
		{
			motionVelocity[2] = -DP_WallClimbIntensity[clientIdx];
		}
		motionVelocity[0] += attractVelocity[0];
		motionVelocity[1] += attractVelocity[1];
		
		// should we force angle?
		bool shouldForceAngle = fabs(forcedAngle[1] - eyeAngles[1]) > DP_MaxYawDeviation[clientIdx] &&
					fabs(forcedAngle[1] - eyeAngles[1]) < (360.0 - DP_MaxYawDeviation[clientIdx]);
		if (shouldForceAngle && !justLatched)
		{
			// force it which way?
			if (eyeAngles[1] < forcedAngle[1] || (eyeAngles[1] > forcedAngle[1] && eyeAngles[1] - forcedAngle[1] > 180.0))
				forcedAngle[1] = fixAngle(forcedAngle[1] - DP_MaxYawDeviation[clientIdx]);
			else
				forcedAngle[1] = fixAngle(forcedAngle[1] + DP_MaxYawDeviation[clientIdx]);
		}

		// finally, move along the wall
		if (shouldForceAngle)
			TeleportEntity(clientIdx, NULL_VECTOR, forcedAngle, motionVelocity);
		else
			TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, motionVelocity);
	}
	
	// is it time to reset double jumps?
	if (curTime >= DP_ResetAirJumpsAt[clientIdx])
	{
		DP_ResetAirJumpsAt[clientIdx] = FAR_FUTURE;
		SetEntProp(clientIdx, Prop_Send, "m_iAirDash", 0); // restore double jumps, if applicable
	}

	// used for HUD state
	if (DP_Latched[clientIdx])
		DP_HUDState[clientIdx] = DP_HUD_STATE_USING;
	else if (!CheckGroundClearance(clientIdx, DP_REQUIRED_GROUND_CLEARANCE, true))
	{
		if (GetEntityFlags(clientIdx) & (FL_SWIM | FL_INWATER))
			DP_HUDState[clientIdx] = DP_HUD_STATE_IN_WATER;
		else
			DP_HUDState[clientIdx] = DP_HUD_STATE_ON_GROUND;
	}
	else
		DP_HUDState[clientIdx] = DP_HUD_STATE_AVAILABLE;
		
	// print the HUD message
	if (curTime >= DP_NextHUDAt[clientIdx])
	{
		if (!__IsHUDVisible(FF2Player(clientIdx)) || DD_BypassHUDRestrictions[clientIdx])
		{
			static char hudMessage[MAX_CENTER_TEXT_LENGTH];
			bool isError = DP_GetHUDStateString(clientIdx, hudMessage, MAX_CENTER_TEXT_LENGTH);
			SetHudTextParams(-1.0, HUD_Y, HUD_INTERVAL + HUD_LINGER, isError ? HUD_R_ERROR : HUD_R_OK, isError ? HUD_G_ERROR : HUD_G_OK, isError ? HUD_B_ERROR : HUD_B_OK, HUD_ALPHA);
			ShowSyncHudText(clientIdx, DD_HUDHandle, hudMessage);
		}
		
		DP_NextHUDAt[clientIdx] = curTime + HUD_INTERVAL;
	}
}

// also an exposed interface, which is why I'm not relying on MAX_CENTER_TEXT_LENGTH
// returns true if not in a usable state (aka in an "error state", as far as the user is concerned)
public bool DP_GetHUDStateString(int clientIdx, char[] hudStr, int length)
{
	if (DP_HUDState[clientIdx] == DP_HUD_STATE_ON_GROUND)
	{
		strcopy(hudStr, length, DP_HUDOnGround);
		return true;
	}
	else if (DP_HUDState[clientIdx] == DP_HUD_STATE_IN_WATER)
	{
		strcopy(hudStr, length, DP_HUDInWater);
		return true;
	}
	else if (DP_HUDState[clientIdx] == DP_HUD_STATE_USING)
	{
		strcopy(hudStr, length, DP_HUDUsing);
		return false;
	}
	else if (DP_HUDState[clientIdx] == DP_HUD_STATE_AVAILABLE)
	{
		strcopy(hudStr, length, DP_HUDAvailable);
		return false;
	}
	
	strcopy(hudStr, length, "bad state for dynamic_parkour");
	return true;
}

/**
 * Dynamic Environmental Management
 */
public Action DEM_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePos[3], int damagecustom)
{
	// various validity checks
	if (!DEM_ActiveThisRound || !IsLivingPlayer(victim))
		return Plugin_Continue;
	else if (!DEM_CanUse[victim])
		return Plugin_Continue;
	
	// ensure attacker is not a player
	if (attacker >= 1 && attacker <= MaxClients)
		return Plugin_Continue;
		
	// exclude fall damage from self
	if (attacker == 0 && inflictor == 0 && (damagetype & DMG_FALL) != 0)
		return Plugin_Continue;
		
	// we now know it's world damage. do whatever is set to be done.
	if (damage < DEM_DamageThreshold[victim] || DEM_DamageThreshold[victim] <= 0.0)
		return Plugin_Continue;
		
	if (DEM_InvincibilityDuration[victim] > 0.0)
		DEM_InvincibleUntil[victim] = GetEngineTime() + DEM_InvincibilityDuration[victim]; // it'll happen when it ticks
		
	if (DEM_ShouldTeleport[victim])
		DD_PerformTeleport(victim, DEM_TeleportStunDuration[victim], DEM_TeleportOnTop[victim], DEM_TeleportSide[victim], false, false);
		
	return Plugin_Continue;
}

public void DEM_Tick(int clientIdx, float curTime)
{
	if (curTime >= DEM_InvincibleUntil[clientIdx])
	{
		SetEntProp(clientIdx, Prop_Data, "m_takedamage", 2);
		if (!DEM_NoUber[clientIdx])
			if (TF2_IsPlayerInCondition(clientIdx, TFCond_Ubercharged))
				TF2_RemoveCondition(clientIdx, TFCond_Ubercharged);
		DEM_InvincibleUntil[clientIdx] = FAR_FUTURE;
	}
	else if (DEM_InvincibleUntil[clientIdx] != FAR_FUTURE)
	{
		// maintain what should be there, as this could interact badly with other plugins that handle environmental damage
		SetEntProp(clientIdx, Prop_Data, "m_takedamage", 0);
		if (!DEM_NoUber[clientIdx])
			if (!TF2_IsPlayerInCondition(clientIdx, TFCond_Ubercharged))
				TF2_AddCondition(clientIdx, TFCond_Ubercharged, -1.0);
	}
}

/**
 * Dynamic Point Teleport
 */
int DPT_Player;
public bool DPT_TracePlayersAndBuildings(int entity, int contentsMask)
{
	if (IsLivingPlayer(entity) && GetClientTeam(entity) != GetClientTeam(DPT_Player))
		return true;
	else if (IsLivingPlayer(entity))
		return false;
		
	return IsValidEntity(entity);
}

public bool DPT_TraceWallsOnly(int entity, int contentsMask)
{
	return false;
}
 
public bool DPT_TryTeleport(int clientIdx)
{
	float sizeMultiplier = GetEntPropFloat(clientIdx, Prop_Send, "m_flModelScale");
	static float startPos[3];
	static float endPos[3];
	static float testPos[3];
	static float eyeAngles[3];
	GetClientEyePosition(clientIdx, startPos);
	GetClientEyeAngles(clientIdx, eyeAngles);
	DPT_Player = clientIdx;
	TR_TraceRayFilter(startPos, eyeAngles, MASK_PLAYERSOLID, RayType_Infinite, DPT_TracePlayersAndBuildings);
	TR_GetEndPosition(endPos);
	
	// don't even try if the distance is less than 82
	float distance = GetVectorDistance(startPos, endPos);
	if (distance < 82.0)
	{
		Nope(clientIdx);
		return false;
	}
		
	if (distance > DPT_MaxDistance[clientIdx])
		constrainDistance(startPos, endPos, distance, DPT_MaxDistance[clientIdx]);
	else // shave just a tiny bit off the end position so our point isn't directly on top of a wall
		constrainDistance(startPos, endPos, distance, distance - 1.0);
	
	// now for the tests. I go 1 extra on the standard mins/maxs on purpose.
	bool found = false;
	for (int x = 0; x < 3; x++)
	{
		if (found)
			break;
	
		float xOffset;
		if (x == 0)
			xOffset = 0.0;
		else if (x == 1)
			xOffset = 12.5 * sizeMultiplier;
		else
			xOffset = 25.0 * sizeMultiplier;
		
		if (endPos[0] < startPos[0])
			testPos[0] = endPos[0] + xOffset;
		else if (endPos[0] > startPos[0])
			testPos[0] = endPos[0] - xOffset;
		else if (xOffset != 0.0)
			break; // super rare but not impossible, no sense wasting on unnecessary tests
	
		for (int y = 0; y < 3; y++)
		{
			if (found)
				break;

			float yOffset;
			if (y == 0)
				yOffset = 0.0;
			else if (y == 1)
				yOffset = 12.5 * sizeMultiplier;
			else
				yOffset = 25.0 * sizeMultiplier;

			if (endPos[1] < startPos[1])
				testPos[1] = endPos[1] + yOffset;
			else if (endPos[1] > startPos[1])
				testPos[1] = endPos[1] - yOffset;
			else if (yOffset != 0.0)
				break; // super rare but not impossible, no sense wasting on unnecessary tests
		
			for (int z = 0; z < 3; z++)
			{
				if (found)
					break;

				float zOffset;
				if (z == 0)
					zOffset = 0.0;
				else if (z == 1)
					zOffset = 41.5 * sizeMultiplier;
				else
					zOffset = 83.0 * sizeMultiplier;

				if (endPos[2] < startPos[2])
					testPos[2] = endPos[2] + zOffset;
				else if (endPos[2] > startPos[2])
					testPos[2] = endPos[2] - zOffset;
				else if (zOffset != 0.0)
					break; // super rare but not impossible, no sense wasting on unnecessary tests

				// before we test this position, ensure it has line of sight from the point our player looked from
				// this ensures the player can't teleport through walls
				static float tmpPos[3];
				TR_TraceRayFilter(endPos, testPos, MASK_PLAYERSOLID, RayType_EndPoint, DPT_TraceWallsOnly);
				TR_GetEndPosition(tmpPos);
				if (testPos[0] != tmpPos[0] || testPos[1] != tmpPos[1] || testPos[2] != tmpPos[2])
					continue;
				
				// now we do our very expensive test. thankfully there's only 27 of these calls, worst case scenario.
				if (PRINT_DEBUG_SPAM)
					PrintToServer("testing %f, %f, %f", testPos[0], testPos[1], testPos[2]);
				found = IsSpotSafe(clientIdx, testPos, sizeMultiplier);
			}
		}
	}
	
	if (!found)
	{
		Nope(clientIdx);
		return false;
	}
		
	if (DPT_PreserveMomentum[clientIdx])
		TeleportEntity(clientIdx, testPos, NULL_VECTOR, NULL_VECTOR);
	else
		TeleportEntity(clientIdx, testPos, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
		
	// particles and sound
	if (strlen(DPT_UseSound) > 3)
	{
		EmitSoundToAll(DPT_UseSound);
		EmitSoundToAll(DPT_UseSound);
	}
	
	if (!IsEmptyString(DPT_OldLocationParticleEffect))
		ParticleEffectAt(startPos, DPT_OldLocationParticleEffect);
	if (!IsEmptyString(DPT_NewLocationParticleEffect))
		ParticleEffectAt(testPos, DPT_NewLocationParticleEffect);
		
	// empty clip?
	if (DPT_EmptyClipOnTeleport[clientIdx])
	{
		int weapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
		if (IsValidEntity(weapon))
		{
			SetEntProp(weapon, Prop_Send, "m_iClip1", 0);
			SetEntProp(weapon, Prop_Send, "m_iClip2", 0);
		}
	}
	
	// attack delay?
	if (DPT_AttackDelayOnTeleport[clientIdx] > 0.0)
	{
		for (int i = 0; i <= 2; i++)
		{
			int weapon = GetPlayerWeaponSlot(clientIdx, i);
			if (IsValidEntity(weapon))
				SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + DPT_AttackDelayOnTeleport[clientIdx]);
		}
	}
		
	return true;
}

public void Rage_DynamicPointTeleport(int bossIdx)
{
	int clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	if (!IsLivingPlayer(clientIdx) || !DPT_CanUse[clientIdx])
		return;
	
	if (DPT_AddCharges[clientIdx])
		DPT_ChargesRemaining[clientIdx] += DPT_NumSkills[clientIdx];
	else
		DPT_ChargesRemaining[clientIdx] = DPT_NumSkills[clientIdx];
}

public void DPT_Tick(int clientIdx, int buttons, float curTime)
{
	bool countChanged = false;
	bool keyDown = (buttons & DPT_KeyToUse[clientIdx]) != 0;
	if (keyDown && !DPT_KeyDown[clientIdx])
	{
		if (DPT_ChargesRemaining[clientIdx] > 0 && DPT_TryTeleport(clientIdx))
		{
			DPT_ChargesRemaining[clientIdx]--;
			countChanged = true;
		}
	}
	DPT_KeyDown[clientIdx] = keyDown;

	// HUD message (center text, same as original)
	if (countChanged || curTime >= DPT_NextCenterTextAt[clientIdx])
	{
		if (DPT_ChargesRemaining[clientIdx] > 0)
			PrintCenterText(clientIdx, DPT_CenterText, DPT_ChargesRemaining[clientIdx]);
		else if (countChanged)
			PrintCenterText(clientIdx, ""); // clear the outdated message

		DPT_NextCenterTextAt[clientIdx] = curTime + DPT_CENTER_TEXT_INTERVAL;
	}
}

/**
 * Dynamic Stop Taunt
 */
public void Rage_DynamicStopTaunt(int bossIdx)
{
	int clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	if (!IsLivingPlayer(clientIdx) || !DST_CanUse[clientIdx])
		return;
		
	DST_ActivateNextTick[clientIdx] = true;
}

public void DST_Tick(int clientIdx)
{
	if (DST_ActivateNextTick[clientIdx])
	{
		DST_ActivateNextTick[clientIdx] = false;
		
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_Taunting))
			TF2_RemoveCondition(clientIdx, TFCond_Taunting);
		if (!DST_DoNotStopMotion[clientIdx])
			TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 200.0})); // it's what stock does. shrug.
	}
}

/**
 * Exposed Interfaces
 */
public void DD_SetDisabled(int clientIdx, bool superjump, bool teleport, bool weighdown, bool glide)
{
	// super jump
	if (DJ_CanUse[clientIdx])
	{
		DJ_IsDisabled[clientIdx] = superjump;
		if (DJ_IsDisabled[clientIdx])
			DJ_CrouchOrAltFireDownSince[clientIdx] = FAR_FUTURE;
	}

	// teleport
	if (DT_CanUse[clientIdx])
	{
		DT_IsDisabled[clientIdx] = teleport;
		if (DT_IsDisabled[clientIdx])
			DT_CrouchOrAltFireDownSince[clientIdx] = FAR_FUTURE;
	}
		
	// weighdown
	if (DW_CanUse[clientIdx])
	{
		DW_IsDisabled[clientIdx] = weighdown;
		if (DW_IsDisabled[clientIdx])
		{
			if (!DP_Latched[clientIdx])
				SetEntityGravity(clientIdx, DW_DefaultGravity[clientIdx]);
			DW_RestoreGravityAt[clientIdx] = FAR_FUTURE;
		}
	}
	
	// glide
	if (DG_CanUse[clientIdx])
	{
		DG_IsDisabled[clientIdx] = glide;
	}
}

public void DD_SetForceHUDEnabled(int clientIdx, bool force)
{
	DD_BypassHUDRestrictions[clientIdx] = force;
}

public float DD_GetMobilityCooldown(int clientIdx)
{
	if (DJ_CanUse[clientIdx] && !DJ_IsDisabled[clientIdx])
		return (DJ_OnCooldownUntil[clientIdx] == FAR_FUTURE) ? 0.0 : (DJ_OnCooldownUntil[clientIdx] - GetEngineTime());
	else if (DT_CanUse[clientIdx] && !DT_IsDisabled[clientIdx])
		return (DT_OnCooldownUntil[clientIdx] == FAR_FUTURE) ? 0.0 : (DT_OnCooldownUntil[clientIdx] - GetEngineTime());
	
	return -1.0;
}

public float DD_GetChargePercent(int clientIdx)
{
	if (DJ_CanUse[clientIdx] && !DJ_IsDisabled[clientIdx])
	{
		if (DJ_ChargeTime[clientIdx] <= 0.0)
			return 100.0;
		else if (DJ_CrouchOrAltFireDownSince[clientIdx] == FAR_FUTURE)
			return 0.0;
		return (DJ_OnCooldownUntil[clientIdx] != FAR_FUTURE) ? 0.0 : (fmin((GetEngineTime() - DJ_CrouchOrAltFireDownSince[clientIdx]) / DJ_ChargeTime[clientIdx], 1.0) * 100.0);
	}
	else if (DT_CanUse[clientIdx] && !DT_IsDisabled[clientIdx])
	{
		if (DT_ChargeTime[clientIdx] <= 0.0)
			return 100.0;
		else if (DT_CrouchOrAltFireDownSince[clientIdx] == FAR_FUTURE)
			return 0.0;
		return (DT_OnCooldownUntil[clientIdx] != FAR_FUTURE) ? 0.0 : (fmin((GetEngineTime() - DT_CrouchOrAltFireDownSince[clientIdx]) / DT_ChargeTime[clientIdx], 1.0) * 100.0);
	}
	
	return 0.0;
}

public void DJ_SetUsesRemaining(int clientIdx, int usesRemaining)
{
	if (DJ_CanUse[clientIdx])
		DJ_UsesRemaining[clientIdx] = usesRemaining;
}

public void DJ_CooldownUntil(int clientIdx, float cooldownEndTime)
{
	if (DJ_CanUse[clientIdx])
	{
		if (DJ_OnCooldownUntil[clientIdx] == FAR_FUTURE || cooldownEndTime > DJ_OnCooldownUntil[clientIdx])
		{
			DJ_OnCooldownUntil[clientIdx] = cooldownEndTime;
			DJ_EmergencyReady[clientIdx] = false;
		}
	}
}

public void DJ_AdjustCooldownTimer(int clientIdx, float offset)
{
	if (DJ_CanUse[clientIdx] && DJ_OnCooldownUntil[clientIdx] != FAR_FUTURE)
		DJ_OnCooldownUntil[clientIdx] += offset;
}

// if you don't want to change a particular stat, set it to -1
public void DJ_ChangeFundamentalStats(int clientIdx, float chargeTime, float cooldown, float multiplier)
{
	if (chargeTime != -1.0)
		DJ_ChargeTime[clientIdx] = chargeTime;
	if (cooldown != -1.0)
		DJ_Cooldown[clientIdx] = cooldown;
	if (multiplier != -1.0)
		DJ_Multiplier[clientIdx] = multiplier;
}

public void DT_SetUsesRemaining(int clientIdx, int usesRemaining)
{
	if (DT_CanUse[clientIdx])
		DT_UsesRemaining[clientIdx] = usesRemaining;
}

public void DT_CooldownUntil(int clientIdx, float cooldownEndTime)
{
	if (DT_CanUse[clientIdx])
	{
		if (DT_OnCooldownUntil[clientIdx] == FAR_FUTURE || cooldownEndTime > DT_OnCooldownUntil[clientIdx])
		{
			DT_OnCooldownUntil[clientIdx] = cooldownEndTime;
			DT_EmergencyReady[clientIdx] = false;
		}
	}
}

public void DT_AdjustCooldownTimer(int clientIdx, float offset)
{
	if (DT_CanUse[clientIdx] && DT_OnCooldownUntil[clientIdx] != FAR_FUTURE)
		DT_OnCooldownUntil[clientIdx] += offset;
}

// if you don't want to change a particular stat, set it to -1
public void DT_ChangeFundamentalStats(int clientIdx, float chargeTime, float cooldown, float stunDuration)
{
	if (chargeTime != -1.0)
		DT_ChargeTime[clientIdx] = chargeTime;
	if (cooldown != -1.0)
		DT_Cooldown[clientIdx] = cooldown;
	if (stunDuration != -1.0)
		DT_StunDuration[clientIdx] = stunDuration;
}

public void DT_SetTargetTeam(int clientIdx, bool sameTeam)
{
	DT_SameTeam[clientIdx] = sameTeam;
}

public void DT_SetIsReverse(int clientIdx, bool isReverse)
{
	DT_IsReverseTeleport[clientIdx] = isReverse;
}

public void DT_SetAboveSide(int clientIdx, bool canTeleportAbove, bool canTeleportSide)
{
	DT_TryTeleportAbove[clientIdx] = canTeleportAbove;
	DT_TryTeleportSide[clientIdx] = canTeleportSide;
}

public void DW_SetUsesRemaining(int clientIdx, int usesRemaining)
{
	if (DW_CanUse[clientIdx])
		DW_UsesRemaining[clientIdx] = usesRemaining;
}

// note that this is the gravity that the user is restored to when weighdown is complete (weighdown gravity is 6.0)
public void DW_SetDefaultGravity(int clientIdx, float gravity)
{
	if (DW_CanUse[clientIdx])
		DW_DefaultGravity[clientIdx] = gravity;
}

// note that this cannot be set to some time sooner than it already is. (though FAR_FUTURE 100000000.0 can be used to take it off cooldown entirely)
public void DW_CooldownUntil(int clientIdx, float cooldownEndTime)
{
	if (DW_CanUse[clientIdx])
	{
		if (DW_OnCooldownUntil[clientIdx] == FAR_FUTURE || cooldownEndTime > DW_OnCooldownUntil[clientIdx])
			DW_OnCooldownUntil[clientIdx] = cooldownEndTime;
	}
}

public void DG_ChangeFundamentalStats(int clientIdx, float startVelocity, float decayPerSecond, float cooldown, float maxDuration)
{
	if (DG_CanUse[clientIdx])
	{
		if (startVelocity != -1.0)
			DG_OriginalMaxVelocity[clientIdx] = startVelocity;
		if (decayPerSecond != -1.0)
			DG_DecayPerSecond[clientIdx] = decayPerSecond;
		if (cooldown != -1.0)
			DG_Cooldown[clientIdx] = cooldown;
		if (maxDuration != -1.0)
			DG_MaxDuration[clientIdx] = maxDuration;
	}
}

public void DSM_SetModifiers(int clientIdx, float bfb, float rifle, float bow, float minigun, float slowed, float critcola, float whip, float dazed)
{
	if (bfb > -1.0)
	{
		DSM_BFBModifier[clientIdx] = bfb;
		DSM_UseBFB[clientIdx] = true;
		DSM_ValidateModifier(DSM_BFBModifier[clientIdx], DSM_UseBFB[clientIdx], 0.444);
	}
	
	if (rifle > -1.0)
	{
		DSM_RifleModifier[clientIdx] = rifle;
		DSM_UseRifle[clientIdx] = true;
		DSM_ValidateModifier(DSM_RifleModifier[clientIdx], DSM_UseRifle[clientIdx], 0.27);
	}
	
	if (bow > -1.0)
	{
		DSM_BowModifier[clientIdx] = bow;
		DSM_UseBow[clientIdx] = true;
		DSM_ValidateModifier(DSM_BowModifier[clientIdx], DSM_UseBow[clientIdx], 0.45);
	}
	
	if (minigun > -1.0)
	{
		DSM_MinigunModifier[clientIdx] = minigun;
		DSM_UseMinigun[clientIdx] = true;
		DSM_ValidateModifier(DSM_MinigunModifier[clientIdx], DSM_UseMinigun[clientIdx], 0.47);
	}
	
	if (slowed > -1.0)
	{
		DSM_SlowedModifier[clientIdx] = slowed;
		DSM_UseSlowed[clientIdx] = true;
		DSM_ValidateModifier(DSM_SlowedModifier[clientIdx], DSM_UseSlowed[clientIdx], 0.60);
	}
	
	if (critcola > -1.0)
	{
		DSM_CritAColaModifier[clientIdx] = critcola;
		DSM_UseCritACola[clientIdx] = true;
		DSM_ValidateModifier(DSM_CritAColaModifier[clientIdx], DSM_UseCritACola[clientIdx], 1.35);
	}
	
	if (whip > -1.0)
	{
		DSM_WhipModifier[clientIdx] = whip;
		DSM_UseWhip[clientIdx] = true;
		DSM_ValidateModifier(DSM_WhipModifier[clientIdx], DSM_UseWhip[clientIdx], 1.35);
	}
	
	if (dazed > -1.0)
	{
		DSM_DazedModifier[clientIdx] = dazed;
		DSM_UseDazed[clientIdx] = true;
		DSM_ValidateModifier(DSM_DazedModifier[clientIdx], DSM_UseDazed[clientIdx], 0.75);
	}
}

public void DSM_SetDisguiseSettings(int clientIdx, bool useDisguiseSpeed, bool disguiseIncreasesSpeed)
{
	DSM_UseDisguiseSpeed[clientIdx] = useDisguiseSpeed;
	DSM_DisguiseCanIncreaseSpeed[clientIdx] = disguiseIncreasesSpeed;
}

public void DSM_SetOverrideSpeed(int clientIdx, float overrideSpeed, bool applyModifiers)
{
	DSM_OverrideSpeed[clientIdx] = overrideSpeed;
	DSM_OverrideUseModifiers[clientIdx] = applyModifiers;
}

public bool DP_IsLatched(int clientIdx)
{
	return DP_Latched[clientIdx];
}

/**
 * OnPlayerRunCmd/OnGameFrame, now with OnStomp
 */
public void OnGameFrame()
{
	if (!RoundInProgress)
		return;

	DSSG_Tick(GetEngineTime());
}
 
public Action OnPlayerRunCmd(int clientIdx, int &buttons, int &impulse, float vel[3], float unusedangles[3], int &weapon)
{
	if (!RoundInProgress)
		return Plugin_Continue;
	else if (!IsLivingPlayer(clientIdx))
		return Plugin_Continue;
		
	bool changed = false;
		
	if (DJ_ActiveThisRound && DJ_CanUse[clientIdx])
	{
		DJ_Tick(clientIdx, buttons, GetEngineTime());
	}
	
	if (DT_ActiveThisRound && DT_CanUse[clientIdx])
	{
		DT_Tick(clientIdx, buttons, GetEngineTime());
	}
	
	if (DW_ActiveThisRound && DW_CanUse[clientIdx])
	{
		DW_Tick(clientIdx, buttons, GetEngineTime());
	}
	
	if (DG_ActiveThisRound && DG_CanUse[clientIdx])
	{
		DG_Tick(clientIdx, buttons, GetEngineTime());
	}
	
	if (DMM_ActiveThisRound && DMM_CanUse[clientIdx])
	{
		if (GetEngineTime() >= DMM_ResetWeaponAt[clientIdx])
		{
			DMM_ResetWeapon(clientIdx);
			DMM_ResetWeaponAt[clientIdx] = FAR_FUTURE;
		}
	}

	if (DP_ActiveThisRound && DP_CanUse[clientIdx])
	{
		int oldButtons = buttons;
		DP_Tick(clientIdx, buttons, GetEngineTime());
		changed = changed & (buttons != oldButtons);
	}
	
	if (DEM_ActiveThisRound && DEM_CanUse[clientIdx])
	{
		DEM_Tick(clientIdx, GetEngineTime());
	}
	
	if (DPT_ActiveThisRound && DPT_CanUse[clientIdx])
	{
		DPT_Tick(clientIdx, buttons, GetEngineTime());
	}
	
	if (DST_ActiveThisRound && DST_CanUse[clientIdx])
	{
		DST_Tick(clientIdx);
	}
	
	if (changed)
		return Plugin_Changed;
	return Plugin_Continue;
}

public Action OnStomp(int attacker, int victim, float &damageMult, float &damageBonus, float &jumpPower)
{
	if (IsLivingPlayer(attacker) && DT_GoombaBlockedUntil[attacker] > GetEngineTime())
	{
		// I'm doing it this way instead of Plugin_Handled so the boss also gets out of goomba range
		// this method causes the boss to jump up when the 0 damage goomba happens.
		damageMult = 0.0;
		damageBonus = 0.0;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

/**
 * General helper stocks, some original, some taken/modified from other sources
 */
stock bool IsLivingPlayer(int clientIdx)
{
	if (clientIdx <= 0 || clientIdx >= MAX_PLAYERS)
		return false;
		
	return IsClientInGame(clientIdx) && IsPlayerAlive(clientIdx);
}

stock float fmin(float n1, float n2)
{
	return n1 < n2 ? n1 : n2;
}

stock float fmax(float n1, float n2)
{
	return n1 > n2 ? n1 : n2;
}

stock float fabs(float x)
{
	return x < 0 ? -x : x;
}

stock int FindRandomPlayer(bool isBossTeam, float position[3] = NULL_VECTOR, float maxDistance = 0.0, bool anyTeam = false, int exclude = -1, bool sizeTests = false)
{
	int player = -1;
	if (!IsLivingPlayer(exclude))
		sizeTests = false;

	// first, get a player count for the team we care about
	int playerCount = 0;
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (clientIdx == exclude)
			continue;
	
		if (!IsLivingPlayer(clientIdx))
			continue;
			
		if (maxDistance > 0.0 && !IsPlayerInRange(clientIdx, position, maxDistance))
			continue;
			
		if (GetEntPropFloat(exclude, Prop_Send, "m_flModelScale") > GetEntPropFloat(clientIdx, Prop_Send, "m_flModelScale"))
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
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (clientIdx == exclude)
			continue;
	
		if (!IsLivingPlayer(clientIdx))
			continue;

		if (maxDistance > 0.0 && !IsPlayerInRange(clientIdx, position, maxDistance))
			continue;
			
		if (GetEntPropFloat(exclude, Prop_Send, "m_flModelScale") > GetEntPropFloat(clientIdx, Prop_Send, "m_flModelScale"))
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

public bool TraceWallsOnly(int entity, int contentsMask)
{
	return false;
}

stock bool IsPlayerInRange(int player, float position[3], float maxDistance)
{
	maxDistance *= maxDistance;
	
	static float playerPos[3];
	GetEntPropVector(player, Prop_Data, "m_vecOrigin", playerPos);
	return GetVectorDistance(position, playerPos, true) <= maxDistance;
}

stock int AttachParticle(int entity, const char[] particleType, float offset=0.0, bool attach=true)
{
	int particle = CreateEntityByName("info_particle_system");
	
	if (!IsValidEntity(particle))
		return -1;

	char targetName[128];
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

public Action Timer_RemoveEntity(Handle timer, any entid)
{
	int entity = EntRefToEntIndex(entid);
	if (IsValidEdict(entity) && entity > MaxClients)
	{
		TeleportEntity(entity, OFF_THE_MAP, NULL_VECTOR, NULL_VECTOR); // send it away first in case it feels like dying dramatically
		AcceptEntityInput(entity, "Kill");
	}
}

stock void PlaySoundLocal(int clientIdx, char[] soundPath, bool followPlayer = true, int repeat = 1)
{
	// play a speech sound that travels normally, local from the player.
	float playerPos[3];
	GetClientEyePosition(clientIdx, playerPos);
	//PrintToServer("eye pos=%f,%f,%f     sound=%s", playerPos[0], playerPos[1], playerPos[2], soundPath);
	for (int i = 0; i < repeat; i++)
		EmitAmbientSound(soundPath, playerPos, followPlayer ? clientIdx : SOUND_FROM_WORLD);
}

stock bool IsInstanceOf(int entity, const char[] desiredClassname)
{
	static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, MAX_ENTITY_CLASSNAME_LENGTH);
	return strcmp(classname, desiredClassname) == 0;
}

stock bool EntityStartsWith(int entity, const char[] desiredPrefix)
{
	static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, MAX_ENTITY_CLASSNAME_LENGTH);
	return StrContains(classname, desiredPrefix) == 0;
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

// long overdue that I fixed this stock, 2015-07-17
stock float fixAngle(float angle)
{
	if (angle >= 0.0)
		angle = FloatModulus(angle, 360.0);
	else
		angle = 360.0 - FloatModulus(-angle, 360.0);
		
	if (angle > 180.0)
		angle -= 360.0;
		
	return angle;
}

stock float FloatModulus(float value, float divisor)
{
	float tmp = value / divisor;
	tmp = getFloatDecimalComponent(tmp);
	return tmp * divisor;
}

stock float ConformAxisValue(float src, float dst, float distCorrectionFactor)
{
	return src - ((src - dst) * distCorrectionFactor);
}

stock bool ConformLineDistance(float result[3], const float src[3], const float dst[3], float maxDistance, bool canExtend = false)
{
	float distance = GetVectorDistance(src, dst);
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
		float distCorrectionFactor = maxDistance / distance;
		result[0] = ConformAxisValue(src[0], dst[0], distCorrectionFactor);
		result[1] = ConformAxisValue(src[1], dst[1], distCorrectionFactor);
		result[2] = ConformAxisValue(src[2], dst[2], distCorrectionFactor);
	}
	
	return distance != 0.0;
}

stock void CopyVector(float dst[3], const float src[3])
{
	dst[0] = src[0];
	dst[1] = src[1];
	dst[2] = src[2];
}

stock float getFloatDecimalComponent(float x)
{
	int xInt = RoundFloat(x);
	if (float(xInt) > x)
		xInt--;
	return fabs(x - float(xInt));
}

stock bool CheckGroundClearance(int clientIdx, float minClearance, bool failInWater)
{
	// standing? automatic fail.
	if (GetEntityFlags(clientIdx) & FL_ONGROUND)
		return false;
	else if (failInWater && (GetEntityFlags(clientIdx) & (FL_SWIM | FL_INWATER)))
		return false;
		
	// need to do a trace
	static float origin[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", origin);
	
	Handle trace = TR_TraceRayFilterEx(origin, view_as<float>({90.0,0.0,0.0}), (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
	static float endPos[3];
	TR_GetEndPosition(endPos, trace);
	CloseHandle(trace);
	
	// only Z should change, so this is easy.
	return origin[2] - endPos[2] >= minClearance;
}

stock void ReadCenterText(int bossIdx, const char[] ability_name, int argInt, char centerText[MAX_CENTER_TEXT_LENGTH])
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, centerText, MAX_CENTER_TEXT_LENGTH);
	ReplaceString(centerText, MAX_CENTER_TEXT_LENGTH, "\\n", "\n");
}

stock void Nope(int clientIdx)
{
	EmitSoundToClient(clientIdx, NOPE_AVI);
}

stock void ReadSound(int bossIdx, const char[] ability_name, int argInt, char soundFile[MAX_SOUND_FILE_LENGTH])
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, soundFile, MAX_SOUND_FILE_LENGTH);
	if (strlen(soundFile) > 3)
		PrecacheSound(soundFile);
}

stock void constrainDistance(const float[] startPoint, float[] endPoint, float distance, float maxDistance)
{
	float constrainFactor = maxDistance / distance;
	endPoint[0] = ((endPoint[0] - startPoint[0]) * constrainFactor) + startPoint[0];
	endPoint[1] = ((endPoint[1] - startPoint[1]) * constrainFactor) + startPoint[1];
	endPoint[2] = ((endPoint[2] - startPoint[2]) * constrainFactor) + startPoint[2];
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
			CreateTimer(duration, Timer_RemoveEntity, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
	}
	return particle;
}

// need to briefly stun the target if they have continuous or other special weapons out
// these weapons can do so much as crash the user's client if they're quick switched
// the stun-unstun will prevent this from happening, but it may or may not stop the target's motion if on ground
stock void PrepareForWeaponSwitch(int clientIdx)
{
	int primary = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary);
	if (!IsValidEntity(primary) || primary != GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon"))
		return;
	
	bool shouldStun = false;
	if (EntityStartsWith(primary, "tf_weapon_minigun"))
	{
		SetEntProp(primary, Prop_Send, "m_iWeaponState", 0);
		shouldStun = true;
	}
	else if (EntityStartsWith(primary, "tf_weapon_compound_bow") || EntityStartsWith(primary, "tf_weapon_sniperrifle") || EntityStartsWith(primary, "tf_weapon_flamethrower"))
		shouldStun = true;

	if (shouldStun)
	{
		TF2_StunPlayer(clientIdx, 0.1, 0.0, TF_STUNFLAG_BONKSTUCK | TF_STUNFLAG_NOSOUNDOREFFECT);
		TF2_RemoveCondition(clientIdx, TFCond_Dazed);
	}
}

/**
 * The below is sarysa's safe location code (which I also use for resizing)
 */
bool ResizeTraceFailed;
int ResizeMyTeam;
public bool Resize_TracePlayersAndBuildings(int entity, int contentsMask)
{
	if (IsLivingPlayer(entity))
	{
		if (GetClientTeam(entity) != ResizeMyTeam)
		{
			ResizeTraceFailed = true;
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[ff2_dynamic_defaults] Player %d stopped trace.", entity);
		}
	}
	else if (IsValidEntity(entity))
	{
		static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
		GetEntityClassname(entity, classname, sizeof(classname));
		if ((strcmp(classname, "obj_sentrygun") == 0) || (strcmp(classname, "obj_dispenser") == 0) || (strcmp(classname, "obj_teleporter") == 0)
			|| (strcmp(classname, "prop_dynamic") == 0) || (strcmp(classname, "func_physbox") == 0) || (strcmp(classname, "func_breakable") == 0))
		{
			ResizeTraceFailed = true;
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[ff2_dynamic_defaults] %s %d stopped trace.", classname, entity);
		}
		else
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[ff2_dynamic_defaults] Neutral entity %d/%s crossed by trace.", entity, classname);
		}
	}
	else
	{
		if (PRINT_DEBUG_SPAM)
			PrintToServer("[ff2_dynamic_defaults] Trace picked up Santa Claus, I guess? entity=%d", entity);
	}

	return false;
}

bool Resize_OneTrace(const float startPos[3], const float endPos[3])
{
	static float result[3];
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
			PrintToServer("[ff2_dynamic_defaults] Could not resize player. Hit a wall. Offsets: %f, %f, %f", startPos[0] - endPos[0], startPos[1] - endPos[1], startPos[2] - endPos[2]);
		return false;
	}
	
	return true;
}

// the purpose of this method is to first trace outward, upward, and then back in.
bool Resize_TestResizeOffset(const float bossOrigin[3], float xOffset, float yOffset, float zOffset)
{
	static float tmpOrigin[3];
	tmpOrigin[0] = bossOrigin[0];
	tmpOrigin[1] = bossOrigin[1];
	tmpOrigin[2] = bossOrigin[2];
	static float targetOrigin[3];
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

bool Resize_TestSquare(const float bossOrigin[3], float xmin, float xmax, float ymin, float ymax, float zOffset)
{
	static float pointA[3];
	static float pointB[3];
	for (int phase = 0; phase <= 7; phase++)
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

		for (int shouldZ = 0; shouldZ <= 1; shouldZ++)
		{
			pointA[2] = pointB[2] = shouldZ == 0 ? bossOrigin[2] : (bossOrigin[2] + zOffset);
			if (!Resize_OneTrace(pointA, pointB))
				return false;
		}
	}
		
	return true;
}

public bool IsSpotSafe(int clientIdx, float playerPos[3], float sizeMultiplier)
{
	ResizeTraceFailed = false;
	ResizeMyTeam = GetClientTeam(clientIdx);
	static float mins[3];
	static float maxs[3];
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

#file "FF2 Subplugin: Dynamic Defaults"
