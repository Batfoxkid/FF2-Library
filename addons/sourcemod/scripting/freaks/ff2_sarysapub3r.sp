// no warranty blah blah don't sue blah blah doing this for fun blah blah...

#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <ff2_dynamic_defaults>
#include <ff2_ams2>
#undef REQUIRE_PLUGIN
#tryinclude <goomba>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

/**
 * Third pack of public rages primarily for Epic Scout
 *
 * Credits:
 * - Rages designed and coded by sarysa
 * - Some stocks from FF2 and Friagram
 * - Credit to Friagram for Epic Scout's razorback body group trick. Which ultimately Valve blocked anyway.
 *           One day I'll learn to give up on things like bodygroups.
 * - SHADoW helped with testing and snippets.
 * - Spawn Ragdoll code by bl4nk
 * - Mecha the Slag for the replay stuff
 * - Inspired by Rise of the Epic Scout by Crash Maul
 */
 
bool DEBUG_FORCE_RAGE = false;
#define ARG_LENGTH 256
 
bool PRINT_DEBUG_INFO = true;

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
#define MAX_TERMINOLOGY_LENGTH 25
#define MAX_DESCRIPTION_LENGTH 129
#define MAX_ABILITY_NAME_LENGTH 65 // seems to be double-wide now, was 33 but that limited it to 16
#define MAX_BODY_GROUP_LENGTH 48

// common array limits
#define MAX_CONDITIONS 10 // TF2 conditions (bleed, dazed, etc.)

#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

bool NULL_BLACKLIST[MAX_PLAYERS_ARRAY];

int MercTeam = view_as<int>(TFTeam_Red);
int BossTeam = view_as<int>(TFTeam_Blue);

bool RoundInProgress = false;

public Plugin myinfo = {
	name = "Freak Fortress 2: sarysa's public mods, third pack",
	author = "sarysa",
	version = "1.0.2 BBG",
}

#define FAR_FUTURE 100000000.0

// taken from 1st set abilities
ConVar cvarTimeScale = null;
ConVar cvarCheats = null;

/**
 * Rage Random Weapon, compatible with the AMS system
 */
#define RRW_STRING "rage_random_weapon"
#define RRW_TRIGGER_E 0
#define RRW_TRIGGER_AMS 1
#define RRW_MAX_WEAPONS 10
bool RRW_ActiveThisRound;
bool RRW_CanUse[MAX_PLAYERS_ARRAY];
int RRW_WeaponEntRef[MAX_PLAYERS_ARRAY][RRW_MAX_WEAPONS]; // internal
float RRW_RemoveWeaponAt[MAX_PLAYERS_ARRAY][RRW_MAX_WEAPONS]; // internal
int RRW_WearableEntRef[MAX_PLAYERS_ARRAY][RRW_MAX_WEAPONS]; // internal
int RRW_Trigger[MAX_PLAYERS_ARRAY]; // arg1
int RRW_WeaponCount[MAX_PLAYERS_ARRAY]; // arg2
float RRW_WeaponLifetime[MAX_PLAYERS_ARRAY]; // arg3 (0.0 = never expire)
int RRW_Slot[MAX_PLAYERS_ARRAY][RRW_MAX_WEAPONS]; // argX6 (16, 26, 36...106)
int RRW_TempWearable[MAX_PLAYERS_ARRAY][RRW_MAX_WEAPONS]; // argX7 (17, 27, 37...107)

/**
 * Rage Steal Next Weapon
 */
#define SNW_STRING "rage_steal_next_weapon"
#define SNW_TRIGGER_E 0
#define SNW_TRIGGER_AMS 1
#define SNW_NUM_WEAPONS 9
bool SNW_ActiveThisRound;
bool SNW_CanUse[MAX_PLAYERS_ARRAY];
float SNW_StealingUntil[MAX_PLAYERS_ARRAY]; // internal
int SNW_WeaponEntRef[MAX_PLAYERS_ARRAY][SNW_NUM_WEAPONS]; // internal
float SNW_RemoveWeaponAt[MAX_PLAYERS_ARRAY][SNW_NUM_WEAPONS]; // internal
int SNW_SuppressedSlot[MAX_PLAYERS_ARRAY]; // internal, note that this is used for VICTIMS, not the hale
float SNW_SlotSuppressedUntil[MAX_PLAYERS_ARRAY]; // internal, note that this is used for VICTIMS, not the hale
int SNW_Trigger[MAX_PLAYERS_ARRAY]; // arg1
float SNW_StealDuration[MAX_PLAYERS_ARRAY]; // arg2
float SNW_WeaponKeepDuration[MAX_PLAYERS_ARRAY]; // arg3
// arg4 is used at rage time
float SNW_SlotSuppressionDuration[MAX_PLAYERS_ARRAY]; // arg5
// args X1 to X8 also only used at rage time, except X6
int SNW_Slot[MAX_PLAYERS_ARRAY][SNW_NUM_WEAPONS]; // argX6 (16, 26, 36...96)

/**
 * Rage Front Protection
 */
#define FP_STRING "rage_front_protection"
#define FP_TRIGGER_E 0
#define FP_TRIGGER_AMS 1
bool FP_ActiveThisRound;
bool FP_CanUse[MAX_PLAYERS_ARRAY];
float FP_ProtectedUntil[MAX_PLAYERS_ARRAY]; // internal
float FP_DamageRemaining[MAX_PLAYERS_ARRAY]; // internal
int FP_WearableEntRef[MAX_PLAYERS_ARRAY]; // internal
char FP_NormalModel[MAX_PLAYERS_ARRAY][MAX_MODEL_FILE_LENGTH]; // internal
int FP_Trigger[MAX_PLAYERS_ARRAY]; // arg1
float FP_Duration[MAX_PLAYERS_ARRAY]; // arg2
float FP_Damage[MAX_PLAYERS_ARRAY]; // arg3
char FP_ShotBlockedSound[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg4
float FP_MinYawBlock[MAX_PLAYERS_ARRAY]; // arg5
float FP_MaxYawBlock[MAX_PLAYERS_ARRAY]; // arg6
// arg8, mapwide rage sound, does not need to be stored
int FP_WearableIdx[MAX_PLAYERS_ARRAY]; // arg9
char FP_ShieldedModel[MAX_PLAYERS_ARRAY][MAX_MODEL_FILE_LENGTH]; // arg10

/**
 * Rage Fake Dead Ringer
 */
#define FDR_STRING "rage_fake_dead_ringer"
#define FDR_TRIGGER_E 0
#define FDR_TRIGGER_AMS 1
#define FDR_SOUND "player/spy_uncloak_feigndeath.wav"
bool FDR_ActiveThisRound;
bool FDR_CanUse[MAX_PLAYERS_ARRAY];
bool FDR_IsPending[MAX_PLAYERS_ARRAY]; // internal
float FDR_EndsAt[MAX_PLAYERS_ARRAY]; // internal
bool FDR_FirstTick[MAX_PLAYERS_ARRAY]; // internal
float FDR_GoombaBlockedUntil[MAX_PLAYERS_ARRAY]; // internal
int FDR_Trigger[MAX_PLAYERS_ARRAY]; // arg1
float FDR_MaxDuration[MAX_PLAYERS_ARRAY]; // arg2
float FDR_UncloakAttackWait[MAX_PLAYERS_ARRAY]; // arg3

/**
 * Rage Dodge Specific Damage
 */
#define DSD_STRING "rage_dodge_specific_damage"
#define DSD_TRIGGER_E 0
#define DSD_TRIGGER_AMS 1
bool DSD_ActiveThisRound;
bool DSD_CanUse[MAX_PLAYERS_ARRAY];
float DSD_ActiveUntil[MAX_PLAYERS_ARRAY]; // internal
int DSD_Trigger[MAX_PLAYERS_ARRAY]; // arg1
float DSD_Duration[MAX_PLAYERS_ARRAY]; // arg2
float DSD_MoveSpeed[MAX_PLAYERS_ARRAY]; // arg3
float DSD_ReplaySpeed[MAX_PLAYERS_ARRAY]; // arg4
bool DSD_DodgeBullets[MAX_PLAYERS_ARRAY]; // arg5
bool DSD_DodgeBlast[MAX_PLAYERS_ARRAY]; // arg6
bool DSD_DodgeFire[MAX_PLAYERS_ARRAY]; // arg7
bool DSD_DodgeMelee[MAX_PLAYERS_ARRAY]; // arg8
// arg9 is mapwide rage sound, does not need to be stored

/**
 * Rage AMS Dynamic Teleport
 */
#define ADT_STRING "rage_ams_dynamic_teleport"
#define ADT_TRIGGER_E 0
#define ADT_TRIGGER_AMS 1
// oddly enough, ActiveThisRound and CanUse are not needed for once.
int ADT_Trigger[MAX_PLAYERS_ARRAY]; // arg1
bool ADT_TeleportTop[MAX_PLAYERS_ARRAY]; // arg2
bool ADT_TeleportSide[MAX_PLAYERS_ARRAY]; // arg3
float ADT_SelfStunDuration[MAX_PLAYERS_ARRAY]; // arg4
// arg5 is mapwide rage sound, does not need to be stored
int ADT_MaxEnemiesToFunction[MAX_PLAYERS_ARRAY]; // arg6

/**
 * METHODS REQUIRED BY ff2 subplugin
 */
void PrintRageWarning()
{
	PrintToServer("*********************************************************************");
	PrintToServer("*                             WARNING                               *");
	PrintToServer("*       DEBUG_FORCE_RAGE in ff2_sarysapub3.sp is set to true!       *");
	PrintToServer("*  Any admin can use the 'rage' command to use rages in this pack!  *");
	PrintToServer("*  This is only for test servers. Disable this on your live server. *");
	PrintToServer("*********************************************************************");
}
 
#define CMD_FORCE_RAGE "rage"
public void OnPluginStart2()
{
	// special initialize here, since this can't be done in RoundStart
	cvarTimeScale = FindConVar("host_timescale");
	cvarCheats = FindConVar("sv_cheats");
	
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	for (int i = 0; i < MAX_PLAYERS_ARRAY; i++) // MAX_PLAYERS_ARRAY is correct here, this one time
		NULL_BLACKLIST[i] = false;
		
	if (DEBUG_FORCE_RAGE)
	{
		PrintRageWarning();
		RegAdminCmd(CMD_FORCE_RAGE, CmdForceRage, ADMFLAG_GENERIC);
	}
	if(FF2_GetRoundState()==1)
	{
		HookAbilities();
	}
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	HookAbilities();
}

public void HookAbilities()
{
	RoundInProgress = true;
	
	// initialize variables
	RRW_ActiveThisRound = false;
	SNW_ActiveThisRound = false;
	FP_ActiveThisRound = false;
	FDR_ActiveThisRound = false;
	DSD_ActiveThisRound = false;
	
	// initialize arrays
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		// all client inits
		RRW_CanUse[clientIdx] = false;
		SNW_SuppressedSlot[clientIdx] = -1;
		SNW_CanUse[clientIdx] = false;
		FP_CanUse[clientIdx] = false;
		FDR_CanUse[clientIdx] = false;
		DSD_CanUse[clientIdx] = false;

		// boss-only inits
		int bossIdx = IsLivingPlayer(clientIdx) ? FF2_GetBossIndex(clientIdx) : -1;
		if (bossIdx < 0)
			continue;

		if ((RRW_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, RRW_STRING)) == true)
		{
			RRW_ActiveThisRound = true;
			
			RRW_WeaponCount[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, RRW_STRING, 2);
			RRW_WeaponLifetime[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RRW_STRING, 3);
			
			RRW_WeaponCount[clientIdx] = min(RRW_WeaponCount[clientIdx], RRW_MAX_WEAPONS);
			for (int i = 0; i < RRW_WeaponCount[clientIdx]; i++)
			{
				int offset = (10 * (i + 1));
				RRW_WeaponEntRef[clientIdx][i] = INVALID_ENTREF;
				RRW_RemoveWeaponAt[clientIdx][i] = FAR_FUTURE;
				RRW_WearableEntRef[clientIdx][i] = INVALID_ENTREF;
				
				// a couple need to be stored as they're needed often
				RRW_Slot[clientIdx][i] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, RRW_STRING, 6 + offset);
				RRW_TempWearable[clientIdx][i] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, RRW_STRING, 7 + offset);
			}

			// sound to precache
			static char soundFile[MAX_SOUND_FILE_LENGTH];
			ReadSound(bossIdx, RRW_STRING, 4, soundFile);
		}

		if ((SNW_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, SNW_STRING)) == true)
		{
			SNW_ActiveThisRound = true;
			SNW_StealingUntil[clientIdx] = 0.0;

			// sound to precache
			static char soundFile[MAX_SOUND_FILE_LENGTH];
			ReadSound(bossIdx, SNW_STRING, 4, soundFile);
			
			SNW_StealDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SNW_STRING, 2);
			SNW_WeaponKeepDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SNW_STRING, 3);
			SNW_SlotSuppressionDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SNW_STRING, 5);
			for (int i = 0; i < SNW_NUM_WEAPONS; i++)
			{
				int offset = (10 * (i + 1));
				SNW_WeaponEntRef[clientIdx][i] = INVALID_ENTREF;
				SNW_RemoveWeaponAt[clientIdx][i] = FAR_FUTURE;
				
				// honestly there's no reason to store this version. meh.
				SNW_Slot[clientIdx][i] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, SNW_STRING, 6 + offset);
				ReadSound(bossIdx, SNW_STRING, 9 + offset, soundFile);
			}
		}

		if ((FP_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, FP_STRING)) == true)
		{
			FP_ActiveThisRound = true;
			FP_ProtectedUntil[clientIdx] = FAR_FUTURE;
			FP_DamageRemaining[clientIdx] = 0.0;
			FP_WearableEntRef[clientIdx] = INVALID_ENTREF;
			
			FP_Duration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FP_STRING, 2);
			FP_Damage[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FP_STRING, 3);
			ReadSound(bossIdx, FP_STRING, 4, FP_ShotBlockedSound[clientIdx]);
			FP_MinYawBlock[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FP_STRING, 5);
			FP_MaxYawBlock[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FP_STRING, 6);
			FP_WearableIdx[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, FP_STRING, 9);
			ReadModel(bossIdx, FP_STRING, 10, FP_ShieldedModel[clientIdx]);

			// sounds to precache
			static char soundFile[MAX_SOUND_FILE_LENGTH];
			ReadSound(bossIdx, FP_STRING, 7, soundFile);
			ReadSound(bossIdx, FP_STRING, 8, soundFile);
		}

		if ((FDR_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, FDR_STRING)) == true)
		{
			FDR_ActiveThisRound = true;
			FDR_EndsAt[clientIdx] = FAR_FUTURE;
			FDR_IsPending[clientIdx] = false;

			
			FDR_MaxDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FDR_STRING, 2);
			FDR_UncloakAttackWait[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FDR_STRING, 3);
			PrecacheSound(FDR_SOUND);
		}

		if ((DSD_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, DSD_STRING)) == true)
		{
			DSD_ActiveThisRound = true;
			DSD_ActiveUntil[clientIdx] = FAR_FUTURE;

			DSD_Duration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DSD_STRING, 2);
			DSD_MoveSpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DSD_STRING, 3);
			DSD_ReplaySpeed[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DSD_STRING, 4);
			DSD_DodgeBullets[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DSD_STRING, 5) == 1;
			DSD_DodgeBlast[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DSD_STRING, 6) == 1;
			DSD_DodgeFire[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DSD_STRING, 7) == 1;
			DSD_DodgeMelee[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DSD_STRING, 8) == 1;

			// sounds to precache
			static char soundFile[MAX_SOUND_FILE_LENGTH];
			ReadSound(bossIdx, DSD_STRING, 9, soundFile);
		}

		if (FF2_HasAbility(bossIdx, this_plugin_name, ADT_STRING))
		{
			ADT_TeleportTop[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ADT_STRING, 2) == 1;
			ADT_TeleportSide[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ADT_STRING, 3) == 1;
			ADT_SelfStunDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ADT_STRING, 4);
			ADT_MaxEnemiesToFunction[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ADT_STRING, 6);

			// sounds to precache
			static char soundFile[MAX_SOUND_FILE_LENGTH];
			ReadSound(bossIdx, ADT_STRING, 5, soundFile);
		}
	}
	
	if (SNW_ActiveThisRound)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
				SDKHook(clientIdx, SDKHook_OnTakeDamage, SNW_OnTakeDamage);
		}
	}
		
	if (FP_ActiveThisRound)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsLivingPlayer(clientIdx) && FP_CanUse[clientIdx])
				SDKHook(clientIdx, SDKHook_OnTakeDamageAlive, FP_OnTakeDamageAlive);
		}
	}

	if (FDR_ActiveThisRound)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsLivingPlayer(clientIdx) && FDR_CanUse[clientIdx])
			{
				SDKHook(clientIdx, SDKHook_PreThink, FDR_PreThink);
				SDKHook(clientIdx, SDKHook_OnTakeDamage, FDR_OnTakeDamage);
			}
		}
	}
		
	if (DSD_ActiveThisRound)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsLivingPlayer(clientIdx) && DSD_CanUse[clientIdx])
				SDKHook(clientIdx, SDKHook_OnTakeDamage, DSD_OnTakeDamage);
		}
	}
		
	CreateTimer(0.3, Timer_PostRoundStartInits, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_PostRoundStartInits(Handle timer)
{
	// hale suicided
	if (!RoundInProgress)
		return Plugin_Handled;
	
	// finish initialization of stuff
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!IsLivingPlayer(clientIdx))
			continue;

		// need to be well past the first round bug check
		if (FP_ActiveThisRound && FP_CanUse[clientIdx])
			GetEntPropString(clientIdx, Prop_Data, "m_ModelName", FP_NormalModel[clientIdx], MAX_MODEL_FILE_LENGTH);
	}

	return Plugin_Handled;
}

public void FF2AMS_PreRoundStart(int client)
{
	if(!FF2AMS_IsAMSActivatedFor(client) || !LibraryExists("FF2AMS")) {
		return;
	}
	
	int boss = FF2_GetBossIndex(client);
	
	if(FF2_HasAbility(boss, this_plugin_name, RRW_STRING)) {
		RRW_Trigger[client] = FF2_GetAbilityArgument(boss, this_plugin_name, RRW_STRING, 1, 1) != 0
							&& FF2AMS_PushToAMS(client, this_plugin_name, RRW_STRING, "SNW") ? 1:0;
	}
	
	if(FF2_HasAbility(boss, this_plugin_name, SNW_STRING)) {
		SNW_Trigger[client] = FF2_GetAbilityArgument(boss, this_plugin_name, SNW_STRING, 1, 1) != 0
							&& FF2AMS_PushToAMS(client, this_plugin_name, SNW_STRING, "SNW") ? 1:0;
	}
	
	if(FF2_HasAbility(boss, this_plugin_name, FP_STRING)) {
		FP_Trigger[client] = FF2_GetAbilityArgument(boss, this_plugin_name, FP_STRING, 1, 1) != 0
							&& FF2AMS_PushToAMS(client, this_plugin_name, FP_STRING, "FP") ? 1:0;
	}
	
	if(FF2_HasAbility(boss, this_plugin_name, FDR_STRING)) {
		FDR_Trigger[client] = FF2_GetAbilityArgument(boss, this_plugin_name, FDR_STRING, 1, 1) != 0
							&& FF2AMS_PushToAMS(client, this_plugin_name, FDR_STRING, "FDR") ? 1:0;
	}
	
	if(FF2_HasAbility(boss, this_plugin_name, DSD_STRING)) {
		DSD_Trigger[client] = FF2_GetAbilityArgument(boss, this_plugin_name, DSD_STRING, 1, 1) != 0
							&& FF2AMS_PushToAMS(client, this_plugin_name, DSD_STRING, "DSD") ? 1:0;
	}
	
	if(FF2_HasAbility(boss, this_plugin_name, ADT_STRING)) {
		ADT_Trigger[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ADT_STRING, 1, 1) != 0
							&& FF2AMS_PushToAMS(client, this_plugin_name, ADT_STRING, "ADT") ? 1:0;
	}
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	RoundInProgress = false;
	
	if (SNW_ActiveThisRound)
	{
		SNW_ActiveThisRound = false;

		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, SNW_OnTakeDamage);
		}
	}

	if (FP_ActiveThisRound)
	{
		FP_ActiveThisRound = false;
	
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx) && FP_CanUse[clientIdx])
				SDKUnhook(clientIdx, SDKHook_OnTakeDamageAlive, FP_OnTakeDamageAlive);
		}
	}

	if (FDR_ActiveThisRound)
	{
		FDR_ActiveThisRound = false;
		
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx) && FDR_CanUse[clientIdx])
			{
				SDKUnhook(clientIdx, SDKHook_PreThink, FDR_PreThink);
				SDKUnhook(clientIdx, SDKHook_OnTakeDamage, FDR_OnTakeDamage);
			}
		}
	}
	
	if (DSD_ActiveThisRound)
	{
		DSD_ActiveThisRound = false;
	
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (DSD_CanUse[clientIdx])
			{
				if (IsClientInGame(clientIdx))
					SDKUnhook(clientIdx, SDKHook_OnTakeDamage, DSD_OnTakeDamage);

				if (DSD_ActiveUntil[clientIdx] != FAR_FUTURE && DSD_ReplaySpeed[clientIdx] > 0.0)
				{
					cvarTimeScale.SetFloat(1.0);
					DSD_UpdateClientCheatValue(0);
				}
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
		
	else if (!strcmp(ability_name, RRW_STRING))
	{
		Rage_RandomWeapon(GetClientOfUserId(FF2_GetBossUserId(bossIdx)));
	}
	else if (!strcmp(ability_name, SNW_STRING))
	{
		Rage_StealNextWeapon(GetClientOfUserId(FF2_GetBossUserId(bossIdx)));
	}
	else if (!strcmp(ability_name, FP_STRING))
	{
		Rage_FrontProtection(GetClientOfUserId(FF2_GetBossUserId(bossIdx)));
	}
	else if (!strcmp(ability_name, FDR_STRING))
	{
		Rage_FakeDeadRinger(GetClientOfUserId(FF2_GetBossUserId(bossIdx)));
	}
	else if (!strcmp(ability_name, DSD_STRING))
	{
		Rage_DodgeSpecificDamage(GetClientOfUserId(FF2_GetBossUserId(bossIdx)));
	}
	else if (!strcmp(ability_name, ADT_STRING))
	{
		Rage_AMSDynamicTeleport(GetClientOfUserId(FF2_GetBossUserId(bossIdx)));
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
	
	if (!strcmp("deadringer", unparsedArgs))
	{
		FDR_Invoke(GetClientOfUserId(FF2_GetBossUserId(0)), 0);
		PrintToConsole(user, "Forcing dead ringer.");
		
		return Plugin_Handled;
	}
	else if (!strcmp("robme", unparsedArgs))
	{
		SNW_SetClassWeapon(GetClientOfUserId(FF2_GetBossUserId(0)), user, view_as<int>(TF2_GetPlayerClass(user)));
		PrintToConsole(user, "Gonna get robbed.");
		
		return Plugin_Handled;
	}
	
	PrintToServer("[sarysapub3] Rage not found: %s", unparsedArgs);
	return Plugin_Continue;
}

/**
 * Rage Random Weapon
 */
public void Rage_RandomWeapon(int clientIdx)
{
	if (RRW_Trigger[clientIdx] != RRW_TRIGGER_E)
		return;
		
	RRW_Invoke(clientIdx, 0);
}

public AMSResult RRW_CanInvoke(int clientIdx, int index)
{
	return AMS_Accept; // no special conditions will prevent this ability
}

public void RRW_Invoke(int clientIdx, int index)
{
	int bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;

	int rand = GetRandomInt(0, RRW_WeaponCount[clientIdx] - 1);
	int argOffset = (rand + 1) * 10;
	
	static char weaponName[MAX_WEAPON_NAME_LENGTH];
	static char weaponArgs[MAX_WEAPON_ARG_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RRW_STRING, argOffset + 1, weaponName, MAX_WEAPON_NAME_LENGTH);
	int weaponIdx = FF2_GetAbilityArgument(bossIdx, this_plugin_name, RRW_STRING, argOffset + 2);
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RRW_STRING, argOffset + 3, weaponArgs, MAX_WEAPON_ARG_LENGTH);
	int weaponVisibility = FF2_GetAbilityArgument(bossIdx, this_plugin_name, RRW_STRING, argOffset + 4);
	int alpha = FF2_GetAbilityArgument(bossIdx, this_plugin_name, RRW_STRING, argOffset + 5);
	int clip = FF2_GetAbilityArgument(bossIdx, this_plugin_name, RRW_STRING, argOffset + 8);
	int ammo = FF2_GetAbilityArgument(bossIdx, this_plugin_name, RRW_STRING, argOffset + 9);
	
	PrepareForWeaponSwitch(clientIdx, true);
	TF2_RemoveWeaponSlot(clientIdx, RRW_Slot[clientIdx][rand]);
	int weapon = SpawnWeapon(clientIdx, weaponName, weaponIdx, 101, 5, weaponArgs, weaponVisibility);
	if (!IsValidEntity(weapon))
	{
		PrintCenterText(clientIdx, "Failed to spawn weapon %s / %d. Notify an admin!", weaponName, weaponIdx);
		return;
	}
	
	// alpha transparency, best if the viewmodel doesn't hold it well
	if (alpha != 255)
	{
		SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
		SetEntityRenderColor(weapon, 255, 255, 255, alpha);
	}
	
	// do not make it the active weapon if Dynamic Parkour is active
	if (!DP_IsLatched(clientIdx))
		SetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon", weapon);
		
	// set clip and ammo last
	int offset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1);
	if (offset >= 0)
	{
		SetEntProp(clientIdx, Prop_Send, "m_iAmmo", ammo, 4, offset);
			
		// the weirdness below is to avoid setting clips for invalid weapons like huntsman, flamethrower, minigun, and sniper rifles.
		// without the check below, these weapons would break.
		// as for energy weapons, I frankly don't care. they're a mess. don't use this code for making energy weapons.
		if (GetEntProp(weapon, Prop_Send, "m_iClip1") > 1 && GetEntProp(weapon, Prop_Send, "m_iClip1") < 128)
			SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
	}
	
	// delay primary/secondary attack ever so slightly
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.5);
	SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 0.5);
		
	// store what needs to be stored
	RRW_WeaponEntRef[clientIdx][rand] = EntIndexToEntRef(weapon);
	RRW_RemoveWeaponAt[clientIdx][rand] = (RRW_WeaponLifetime[clientIdx] <= 0.0 ? FAR_FUTURE : (GetEngineTime() + RRW_WeaponLifetime[clientIdx]));
	RRW_ToggleWearable(clientIdx, rand, false); // remove old wearable for this slot, if applicable
	
	// play the sound
	static char soundFile[MAX_SOUND_FILE_LENGTH];
	ReadSound(bossIdx, RRW_STRING, 4, soundFile);
	if (strlen(soundFile) > 3)
		EmitSoundToAll(soundFile);
}

public void RRW_ToggleWearable(int clientIdx, int weaponIdx, bool shouldAdd)
{
	if (RRW_TempWearable[clientIdx][weaponIdx] <= 0)
		return;
		
	if (shouldAdd && RRW_WearableEntRef[clientIdx][weaponIdx] == INVALID_ENTREF)
	{
		int wearable = SpawnWeapon(clientIdx, "tf_wearable", RRW_TempWearable[clientIdx][weaponIdx], 101, 5, "", 1);
		if (IsValidEntity(wearable))
		{
			RRW_WearableEntRef[clientIdx][weaponIdx] = EntIndexToEntRef(wearable);
			SetEntityRenderMode(wearable, RENDER_TRANSCOLOR);
			SetEntityRenderColor(wearable, 255, 255, 255, 0);
		}
	}
	else if (!shouldAdd && RRW_WearableEntRef[clientIdx][weaponIdx] != INVALID_ENTREF)
	{
		int wearable = EntRefToEntIndex(RRW_WearableEntRef[clientIdx][weaponIdx]);
		if (IsValidEntity(wearable))
			TF2_RemoveWearable(clientIdx, wearable);
		RRW_WearableEntRef[clientIdx][weaponIdx] = INVALID_ENTREF;
	}
}

public void RRW_Tick(int clientIdx, float curTime)
{
	for (int i = 0; i < RRW_WeaponCount[clientIdx]; i++)
	{
		if (RRW_WeaponEntRef[clientIdx][i] == INVALID_ENTREF)
			continue;
			
		int weapon = EntRefToEntIndex(RRW_WeaponEntRef[clientIdx][i]);
		if (!IsValidEntity(weapon))
		{
			RRW_ToggleWearable(clientIdx, i, false);
			RRW_WeaponEntRef[clientIdx][i] = INVALID_ENTREF;
			continue;
		}
		
		// this only happens if someone else's weapon spawning code is crap
		int weaponAtSlot = GetPlayerWeaponSlot(clientIdx, RRW_Slot[clientIdx][i]);
		if (weapon != weaponAtSlot)
		{
			if (PRINT_DEBUG_INFO)
				PrintToServer("[sarysapub3] WARNING: Multiple weapons at slot %d. Removing the old weapon. (someone's code sucks)", RRW_Slot[clientIdx][i]);
			RRW_ToggleWearable(clientIdx, i, false);
			AcceptEntityInput(weapon, "kill");
			RRW_WeaponEntRef[clientIdx][i] = INVALID_ENTREF;
			continue;
		}
		
		int activeWeapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
		if (curTime >= RRW_RemoveWeaponAt[clientIdx][i])
		{
			if (activeWeapon == weapon) // set them to melee
			{
				PrepareForWeaponSwitch(clientIdx, true);
		
				SetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(clientIdx, 2));
			}
			TF2_RemoveWeaponSlot(clientIdx, RRW_Slot[clientIdx][i]);
			RRW_ToggleWearable(clientIdx, i, false);
			RRW_WeaponEntRef[clientIdx][i] = INVALID_ENTREF;
			continue;
		}
		
		if (activeWeapon != weapon)
			RRW_ToggleWearable(clientIdx, i, false);
		else if (activeWeapon == weapon)
			RRW_ToggleWearable(clientIdx, i, true);
	}
}

/**
 * Rage Steal Next Weapon
 */
public void Rage_StealNextWeapon(int clientIdx)
{
	if (SNW_Trigger[clientIdx] != SNW_TRIGGER_E)
		return;
		
	SNW_Invoke(clientIdx, 0);
}

public AMSResult SNW_CanInvoke(int clientIdx, int index)
{
	return AMS_Accept; // no special conditions will prevent this ability
}

public void SNW_Invoke(int clientIdx, int index)
{
	int bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;

	SNW_StealingUntil[clientIdx] = GetEngineTime() + SNW_StealDuration[clientIdx];

	// play the sound, which serves as a warning to players
	static char soundFile[MAX_SOUND_FILE_LENGTH];
	ReadSound(bossIdx, SNW_STRING, 4, soundFile);
	if (strlen(soundFile) > 3)
		EmitSoundToAll(soundFile);
}

public Action SNW_OnTakeDamage(int victim, int &attacker, int &inflictor, 
							float &damage, int &damagetype, int &weapon, 
							float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsLivingPlayer(victim) || !IsLivingPlayer(attacker))
		return Plugin_Continue;
	else if (GetClientTeam(victim) == GetClientTeam(attacker))
		return Plugin_Continue; // tends to only pertain to self-damage
	else if (PlayerIsInvincible(victim))
		return Plugin_Continue;
		
	if (SNW_CanUse[attacker] && GetEngineTime() < SNW_StealingUntil[attacker] && (damagetype & DMG_CLUB) != 0)
		SNW_SetClassWeapon(attacker, victim, view_as<int>(TF2_GetPlayerClass(victim)));
		
	return Plugin_Continue;
}

public void SNW_SetClassWeapon(int clientIdx, int victim, int classIdx)
{
	int bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;

	classIdx -= 1; // class 0 is "Unknown"
	classIdx = max(0, classIdx);
	int argOffset = (classIdx + 1) * 10;
	
	static char weaponName[MAX_WEAPON_NAME_LENGTH];
	static char weaponArgs[MAX_WEAPON_ARG_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SNW_STRING, argOffset + 1, weaponName, MAX_WEAPON_NAME_LENGTH);
	int weaponIdx = FF2_GetAbilityArgument(bossIdx, this_plugin_name, SNW_STRING, argOffset + 2);
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SNW_STRING, argOffset + 3, weaponArgs, MAX_WEAPON_ARG_LENGTH);
	int weaponVisibility = FF2_GetAbilityArgument(bossIdx, this_plugin_name, SNW_STRING, argOffset + 4);
	int alpha = FF2_GetAbilityArgument(bossIdx, this_plugin_name, SNW_STRING, argOffset + 5);
	
	PrepareForWeaponSwitch(clientIdx, true);
	TF2_RemoveWeaponSlot(clientIdx, SNW_Slot[clientIdx][classIdx]);
	int weapon = SpawnWeapon(clientIdx, weaponName, weaponIdx, 101, 5, weaponArgs, weaponVisibility);
	if (!IsValidEntity(weapon))
	{
		PrintCenterText(clientIdx, "Failed to spawn weapon %s / %d. Notify an admin!", weaponName, weaponIdx);
		return;
	}
	
	// alpha transparency, best if the viewmodel doesn't hold it well
	if (alpha != 255)
	{
		SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
		SetEntityRenderColor(weapon, 255, 255, 255, alpha);
	}
	
	// do not make it the active weapon if Dynamic Parkour is active
	if (!DP_IsLatched(clientIdx))
		SetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon", weapon);
		
	// play a sound on the victim
	static char soundFile[MAX_SOUND_FILE_LENGTH];
	ReadSound(bossIdx, SNW_STRING, 9 + argOffset, soundFile);
	if (strlen(soundFile) > 3)
		PseudoAmbientSound(victim, soundFile, 1, 1000.0);
		
	// ammo/clip last
	int clip = FF2_GetAbilityArgument(bossIdx, this_plugin_name, SNW_STRING, argOffset + 7);
	int ammo = FF2_GetAbilityArgument(bossIdx, this_plugin_name, SNW_STRING, argOffset + 8);

	int offset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1);
	if (offset >= 0)
	{
		SetEntProp(clientIdx, Prop_Send, "m_iAmmo", ammo, 4, offset);

		// the weirdness below is to avoid setting clips for invalid weapons like huntsman, flamethrower, minigun, and sniper rifles.
		// without the check below, these weapons would break.
		// as for energy weapons, I frankly don't care. they're a mess. don't use this code for making energy weapons.
		if (GetEntProp(weapon, Prop_Send, "m_iClip1") > 1 && GetEntProp(weapon, Prop_Send, "m_iClip1") < 128)
			SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
	}
		
	// delay primary/secondary attack ever so slightly
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.5);
	SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 0.5);
		
	// store what needs to be stored
	SNW_StealingUntil[clientIdx] = 0.0;
	SNW_WeaponEntRef[clientIdx][classIdx] = EntIndexToEntRef(weapon);
	SNW_RemoveWeaponAt[clientIdx][classIdx] = (SNW_WeaponKeepDuration[clientIdx] <= 0.0 ? FAR_FUTURE : (GetEngineTime() + SNW_WeaponKeepDuration[clientIdx]));
	SNW_SuppressedSlot[victim] = SNW_Slot[clientIdx][classIdx];
	SNW_SlotSuppressedUntil[victim] = GetEngineTime() + SNW_SlotSuppressionDuration[clientIdx];
}

public void SNW_Tick(float curTime)
{
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!IsLivingPlayer(clientIdx))
			continue;
		else if (!SNW_CanUse[clientIdx])
		{
			if (SNW_SuppressedSlot[clientIdx] != -1)
			{
				if (curTime >= SNW_SlotSuppressedUntil[clientIdx])
					SNW_SuppressedSlot[clientIdx] = -1;
				else if (GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon") == GetPlayerWeaponSlot(clientIdx, SNW_SuppressedSlot[clientIdx]))
				{
					for (int slot = 2; slot >= 0; slot--)
					{
						if (slot == SNW_SuppressedSlot[clientIdx])
							continue;
						int weapon = GetPlayerWeaponSlot(clientIdx, slot);
						if (IsValidEntity(weapon))
						{
							PrepareForWeaponSwitch(clientIdx, false);
		
							SetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon", weapon);
							break;
						}
					}
				}
			}
			continue;
		}
			
		// the rest only executes for the hale
		for (int i = 0; i < SNW_NUM_WEAPONS; i++)
		{
			if (SNW_WeaponEntRef[clientIdx][i] == INVALID_ENTREF)
				continue;

			int weapon = EntRefToEntIndex(SNW_WeaponEntRef[clientIdx][i]);
			if (!IsValidEntity(weapon))
			{
				SNW_WeaponEntRef[clientIdx][i] = INVALID_ENTREF;
				continue;
			}

			// this only happens if someone else's weapon spawning code is crap
			int weaponAtSlot = GetPlayerWeaponSlot(clientIdx, SNW_Slot[clientIdx][i]);
			if (weapon != weaponAtSlot)
			{
				if (PRINT_DEBUG_INFO)
					PrintToServer("[sarysapub3] WARNING: Multiple weapons at slot %d. Removing the old weapon. (someone's code sucks)", SNW_Slot[clientIdx][i]);
				AcceptEntityInput(weapon, "kill");
				SNW_WeaponEntRef[clientIdx][i] = INVALID_ENTREF;
				continue;
			}

			int activeWeapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
			if (curTime >= SNW_RemoveWeaponAt[clientIdx][i])
			{
				if (activeWeapon == weapon) // set them to melee
				{
					PrepareForWeaponSwitch(clientIdx, true);
		
					SetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(clientIdx, 2));
				}
				TF2_RemoveWeaponSlot(clientIdx, SNW_Slot[clientIdx][i]);
				SNW_WeaponEntRef[clientIdx][i] = INVALID_ENTREF;
				continue;
			}
		}
	}
}

/**
 * Rage Front Protection
 */
public void Rage_FrontProtection(int clientIdx)
{
	if (FP_Trigger[clientIdx] != FP_TRIGGER_E)
		return;
		
	FP_Invoke(clientIdx, 0);
}

public AMSResult FP_CanInvoke(int clientIdx, int index)
{
	return AMS_Accept; // no special conditions will prevent this ability
}

public void FP_EndRage(int clientIdx)
{
	FP_ProtectedUntil[clientIdx] = FAR_FUTURE;
	FP_DamageRemaining[clientIdx] = 0.0;

	int bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;

	static char soundFile[MAX_SOUND_FILE_LENGTH];
	ReadSound(bossIdx, FP_STRING, 7, soundFile);
	if (strlen(soundFile) > 3)
		EmitSoundToAll(soundFile);
		
	if (FP_WearableIdx[clientIdx] > 0 && FP_WearableEntRef[clientIdx] != INVALID_ENTREF)
	{
		int wearable = EntRefToEntIndex(FP_WearableEntRef[clientIdx]);
		if (IsValidEntity(wearable))
			TF2_RemoveWearable(clientIdx, wearable);
		FP_WearableEntRef[clientIdx] = INVALID_ENTREF;
	}

	if (strlen(FP_ShieldedModel[clientIdx]) > 3 && strlen(FP_NormalModel[clientIdx]) > 3)
		SwapModel(clientIdx, FP_NormalModel[clientIdx]);
}

// fun fact: OTDA is completely inaccurate if the target is ubered. (instead of "what if not ubered" damage, it's just the same arbitrary base damage that OTD uses)
public Action FP_OnTakeDamageAlive(int victim, int &attacker, int &inflictor, 
								float &damage, int &damagetype, int &weapon,
								float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsLivingPlayer(victim) || !IsLivingPlayer(attacker))
		return Plugin_Continue;
	else if (!FP_CanUse[victim] || FP_DamageRemaining[victim] == 0.0 || damagecustom == TF_CUSTOM_BACKSTAB)
		return Plugin_Continue;
	else if (TF2_IsPlayerInCondition(victim, TFCond_Ubercharged)) // it still goes through
		return Plugin_Continue;
		
	// need position of either the inflictor or the attacker
	int posEntity = IsValidEntity(inflictor) ? inflictor : attacker;
	static float actualDamagePos[3];
	static float victimPos[3];
	static float angle[3];
	static float eyeAngles[3];
	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
	GetEntPropVector(posEntity, Prop_Send, "m_vecOrigin", actualDamagePos);
	GetVectorAnglesTwoPoints(victimPos, actualDamagePos, angle);
	GetClientEyeAngles(victim, eyeAngles);
	
	// need the yaw offset from the player's POV, and set it up to be between (-180.0..180.0]
	float yawOffset = fixAngle(angle[1]) - fixAngle(eyeAngles[1]);
	if (yawOffset <= -180.0)
		yawOffset += 360.0;
	else if (yawOffset > 180.0)
		yawOffset -= 360.0;
		
	// now it's a simple check
	if (yawOffset >= FP_MinYawBlock[victim] && yawOffset <= FP_MaxYawBlock[victim])
	{
		FP_DamageRemaining[victim] -= damage;
		if (FP_DamageRemaining[victim] <= 0.0)
			FP_EndRage(victim);
		else if (strlen(FP_ShotBlockedSound[victim]) > 3)
		{
			EmitSoundToClient(victim, FP_ShotBlockedSound[victim]);
			EmitSoundToClient(attacker, FP_ShotBlockedSound[victim]);
		}
		damage = 0.0; // intentionally not doing partial damage cutting. entire big hits can be lost even if the shield only has 5HP.
		damagetype |= DMG_PREVENT_PHYSICS_FORCE;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public void FP_Invoke(int clientIdx, int index)
{
	int bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;

	// play the sound, which serves as a warning to players
	static char soundFile[MAX_SOUND_FILE_LENGTH];
	ReadSound(bossIdx, FP_STRING, 8, soundFile);
	if (strlen(soundFile) > 3)
		EmitSoundToAll(soundFile);
		
	// set the settings
	FP_ProtectedUntil[clientIdx] = FP_Duration[clientIdx] <= 0.0 ? FAR_FUTURE : (GetEngineTime() + FP_Duration[clientIdx]);
	FP_DamageRemaining[clientIdx] = FP_Damage[clientIdx];
	
	// toggle bodygroups
	if (FP_WearableIdx[clientIdx] > 0 && FP_WearableEntRef[clientIdx] == INVALID_ENTREF)
	{
		int wearable = SpawnWeapon(clientIdx, "tf_wearable", FP_WearableIdx[clientIdx], 101, 5, "", 1);
		if (IsValidEntity(wearable))
		{
			FP_WearableEntRef[clientIdx] = EntIndexToEntRef(wearable);
			
			// this might seem unnecessary since Valve supposedly hides it, but I was seeing self-wearables on my test server.
			SetEntityRenderMode(wearable, RENDER_TRANSCOLOR);
			SetEntityRenderColor(wearable, 255, 255, 255, 0);
		}
	}

	if (strlen(FP_ShieldedModel[clientIdx]) > 3 && strlen(FP_NormalModel[clientIdx]) > 3)
		SwapModel(clientIdx, FP_ShieldedModel[clientIdx]);
}

public void FP_Tick(int clientIdx, float curTime)
{
	if (curTime >= FP_ProtectedUntil[clientIdx])
		FP_EndRage(clientIdx);
}

/**
 * Rage Fake Dead Ringer
 */
public void Rage_FakeDeadRinger(int clientIdx)
{
	if (FDR_Trigger[clientIdx] != FDR_TRIGGER_E)
		return;
		
	FDR_Invoke(clientIdx, 0);
}

public AMSResult FDR_CanInvoke(int clientIdx, int index)
{
	return FDR_EndsAt[clientIdx] == FAR_FUTURE ? AMS_Accept:AMS_Deny;
}

public void FDR_Invoke(int clientIdx, int index)
{
	int bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;

	FDR_IsPending[clientIdx] = true;
}

public void FDR_EndAbility(int clientIdx, int index)
{
	if (FDR_EndsAt[clientIdx] == FAR_FUTURE)
		return; // common concern with the AMS

	FDR_DelayWeaponsBy(clientIdx, FDR_UncloakAttackWait[clientIdx]);
	FDR_EndsAt[clientIdx] = FAR_FUTURE;
	static float bossPos[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossPos);
	bossPos[2] += 41.0;
	EmitAmbientSound(FDR_SOUND, bossPos, clientIdx);
	EmitAmbientSound(FDR_SOUND, bossPos, clientIdx);
	
	if (TF2_IsPlayerInCondition(clientIdx, TFCond_Cloaked))
		TF2_RemoveCondition(clientIdx, TFCond_Cloaked);
	TF2_AddCondition(clientIdx, TFCond_Cloaked, 0.05); // allow for fade out
	if (TF2_IsPlayerInCondition(clientIdx, TFCond_DeadRingered))
		TF2_RemoveCondition(clientIdx, TFCond_DeadRingered);
	if (TF2_IsPlayerInCondition(clientIdx, TFCond_Stealthed))
		TF2_RemoveCondition(clientIdx, TFCond_Stealthed);

	FDR_GoombaBlockedUntil[clientIdx]  = GetEngineTime() + FDR_UncloakAttackWait[clientIdx];
}

public void FDR_DelayWeaponsBy(int clientIdx, float delayTime)
{
	for (int slot = 0; slot <= 2; slot++)
	{
		int weapon = GetPlayerWeaponSlot(clientIdx, slot);
		if (IsValidEntity(weapon))
		{
			SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + delayTime);
			SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + delayTime);
		}
	}
}

public Action FDR_OnTakeDamage(int victim, int &attacker, int &inflictor, 
								float &damage, int &damagetype, int &weapon,
								float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsLivingPlayer(victim) || !FDR_CanUse[victim])
		return Plugin_Continue;
	else if (FDR_EndsAt[victim] != FAR_FUTURE)
	{
		damage *= 0.1;
		return Plugin_Changed;
	}
	else if (!FDR_IsPending[victim])
		return Plugin_Continue;
	
	damage *= 0.1;
	FDR_FeignDeath(victim);
	return Plugin_Changed;
}

public void FDR_FeignDeath(int victim)
{
	FDR_IsPending[victim] = false;
	CreateRagdoll(victim, 0.0, false);
	FDR_EndsAt[victim] = GetEngineTime() + FDR_MaxDuration[victim];
	FDR_DelayWeaponsBy(victim, FDR_MaxDuration[victim] + FDR_UncloakAttackWait[victim]);
	SetEntPropFloat(victim, Prop_Send, "m_flCloakMeter", 100.0);
	//TF2_AddCondition(victim, TFCond_Cloaked, FDR_MaxDuration[victim]);
	TF2_AddCondition(victim, TFCond_DeadRingered, FDR_MaxDuration[victim]);
	TF2_AddCondition(victim, TFCond_Stealthed, FDR_MaxDuration[victim]);
	FDR_FirstTick[victim] = true; // trigger things like losing afterburn
}

// this is needed mainly for enforcement, since I doubt the system really enjoys cloaking scouts
public void FDR_PreThink(int clientIdx)
{
	float curTime = GetEngineTime();

	if (FDR_EndsAt[clientIdx] != FAR_FUTURE)
	{
		if (curTime >= FDR_EndsAt[clientIdx])
			FDR_EndAbility(clientIdx, 0);
		else
		{
			//if (!TF2_IsPlayerInCondition(clientIdx, TFCond_Cloaked))
			//	TF2_AddCondition(clientIdx, TFCond_Cloaked, FDR_MaxDuration[clientIdx]);
			if (!TF2_IsPlayerInCondition(clientIdx, TFCond_DeadRingered))
				TF2_AddCondition(clientIdx, TFCond_DeadRingered, FDR_MaxDuration[clientIdx]);
			if (!TF2_IsPlayerInCondition(clientIdx, TFCond_Stealthed))
				TF2_AddCondition(clientIdx, TFCond_Stealthed, FDR_MaxDuration[clientIdx]);
			if (GetEntPropFloat(clientIdx, Prop_Send, "m_flCloakMeter") != 100.0)
				SetEntPropFloat(clientIdx, Prop_Send, "m_flCloakMeter", 100.0);
				
			if (FDR_FirstTick[clientIdx])
			{
				FDR_FirstTick[clientIdx] = false;
				if (TF2_IsPlayerInCondition(clientIdx, TFCond_OnFire))
					TF2_RemoveCondition(clientIdx, TFCond_OnFire);
				if (TF2_IsPlayerInCondition(clientIdx, TFCond_Bleeding))
					TF2_RemoveCondition(clientIdx, TFCond_Bleeding);
				if (TF2_IsPlayerInCondition(clientIdx, TFCond_MarkedForDeath))
					TF2_RemoveCondition(clientIdx, TFCond_MarkedForDeath);
			}
		}
	}
}

public Action FDR_OnStomp(int attacker, int victim, float& damageMultiplier, float& damageBonus, float& JumpPower)
{
	if (FDR_CanUse[attacker])
	{
		if (FDR_EndsAt[attacker] != FAR_FUTURE || GetEngineTime() < FDR_GoombaBlockedUntil[attacker])
			return Plugin_Handled;
	}
	else if (FDR_CanUse[victim])
	{
		if (FDR_IsPending[victim])
		{
			FDR_FeignDeath(victim);
			damageMultiplier *= 0.1;
			damageBonus *= 0.1;
			return Plugin_Changed;
		}
		else if (FDR_EndsAt[victim] != FAR_FUTURE)
		{
			damageMultiplier *= 0.1;
			damageBonus *= 0.1;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

/**
 * Rage Dodge Specific Damage
 */
public Action DSD_OnTakeDamage(int victim, int &attacker, int &inflictor, 
								float &damage, int &damagetype, int &weapon,
								float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsLivingPlayer(victim) || !DSD_CanUse[victim])
		return Plugin_Continue;
		
	if (DSD_ActiveUntil[victim] != FAR_FUTURE && GetEngineTime() < DSD_ActiveUntil[victim])
	{
		if ((DSD_DodgeBullets[victim] && (damagetype & (DMG_BULLET | DMG_BUCKSHOT) != 0)) ||
			(DSD_DodgeBlast[victim] && (damagetype & (DMG_BLAST) != 0)) ||
			(DSD_DodgeFire[victim] && (damagetype & (DMG_BURN) != 0)) ||
			(DSD_DodgeMelee[victim] && (damagetype & (DMG_CLUB) != 0)))
		{
			damage = 0.0;
			damagetype |= DMG_PREVENT_PHYSICS_FORCE;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

public void Rage_DodgeSpecificDamage(int clientIdx)
{
	if (DSD_Trigger[clientIdx] != DSD_TRIGGER_E)
		return;
		
	DSD_Invoke(clientIdx, 0);
}

public AMSResult DSD_CanInvoke(int clientIdx, int index)
{
	return AMS_Accept;
}

public void DSD_Invoke(int clientIdx, int index)
{
	int bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;

	DSD_ActiveUntil[clientIdx] = GetEngineTime() + DSD_Duration[clientIdx];
	if (DSD_ReplaySpeed[clientIdx] > 0.0)
	{
		DSD_UpdateClientCheatValue(1);
		SetConVarFloat(cvarTimeScale, DSD_ReplaySpeed[clientIdx]);
	}
	if (DSD_MoveSpeed[clientIdx] > 0.0)
		DSM_SetOverrideSpeed(clientIdx, DSD_MoveSpeed[clientIdx]);

	static char soundFile[MAX_SOUND_FILE_LENGTH];
	ReadSound(bossIdx, DSD_STRING, 9, soundFile);
	if (strlen(soundFile) > 3)
		EmitSoundToAll(soundFile);
}

public void DSD_Tick(int clientIdx, float curTime)
{
	if (DSD_ActiveUntil[clientIdx] == FAR_FUTURE)
		return;
		
	if (curTime >= DSD_ActiveUntil[clientIdx])
	{
		DSD_ActiveUntil[clientIdx] = FAR_FUTURE;
		if (DSD_ReplaySpeed[clientIdx] > 0.0)
		{
			SetConVarFloat(cvarTimeScale, 1.0);
			DSD_UpdateClientCheatValue(0);
		}
		if (DSD_MoveSpeed[clientIdx] > 0.0)
			DSM_SetOverrideSpeed(clientIdx);
	}
}

// By Mecha the Slag, lifted from 1st set abilities and tweaked
void DSD_UpdateClientCheatValue(int valueInt)
{
	if (cvarCheats == null)
		return;

	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (IsClientInGame(clientIdx) && !IsFakeClient(clientIdx))
		{
			static char valueS[2];
			IntToString(valueInt, valueS, sizeof(valueS));
			cvarCheats.ReplicateToClient(clientIdx, valueS);
		}
	}
}

/**
 * Rage AMS Dynamic Teleport
 */
public void Rage_AMSDynamicTeleport(int clientIdx)
{
	if (ADT_Trigger[clientIdx] != ADT_TRIGGER_E)
		return;
		
	ADT_Invoke(clientIdx, 0);
}

public AMSResult ADT_CanInvoke(int clientIdx, int index)
{
	if (ADT_MaxEnemiesToFunction[clientIdx] == 0)
		return AMS_Accept;
		
	int numPlayers = 0;
	int enemyTeam = GetClientTeam(clientIdx) == BossTeam ? MercTeam : BossTeam; // why the fuck are mercs allowed on BLU? seriously. WHY THE FUCK.
	for (int enemy = 1; enemy < MAX_PLAYERS; enemy++)
	{
		if (IsLivingPlayer(enemy) && GetClientTeam(enemy) == enemyTeam)
			numPlayers++;
	}
	return numPlayers <= ADT_MaxEnemiesToFunction[clientIdx] ? AMS_Accept:AMS_Deny;
}

public void ADT_Invoke(int clientIdx, int index)
{
	int bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;

	// perform the teleport
	DD_PerformTeleport(clientIdx, ADT_SelfStunDuration[clientIdx], ADT_TeleportTop[clientIdx], ADT_TeleportSide[clientIdx], false, false);

	// play the sound
	static char soundFile[MAX_SOUND_FILE_LENGTH];
	ReadSound(bossIdx, ADT_STRING, 5, soundFile);
	if (strlen(soundFile) > 3)
		EmitSoundToAll(soundFile);
}

/**
 * OnPlayerRunCmd/OnGameFrame, with special guest OnStomp
 */
public void OnGameFrame()
{
	if (!RoundInProgress)
		return;
		
	float curTime = GetEngineTime();
	
	if (RRW_ActiveThisRound || FP_ActiveThisRound || DSD_ActiveThisRound)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (!IsLivingPlayer(clientIdx))
				continue;
		
			if (RRW_CanUse[clientIdx])
				RRW_Tick(clientIdx, curTime);
			if (FP_CanUse[clientIdx])
				FP_Tick(clientIdx, curTime);
			if (DSD_CanUse[clientIdx])
				DSD_Tick(clientIdx, curTime);
		}
	}
	
	if (SNW_ActiveThisRound)
		SNW_Tick(curTime);
}

public Action OnStomp(int attacker, int victim, float& damageMultiplier, float& damageBonus, float& JumpPower)
{
	return FDR_OnStomp(attacker, victim, damageMultiplier, damageBonus, JumpPower);
}

/**
 * General helper stocks, some original, some taken/modified from other sources
 */
public Action RemoveEntity2(Handle timer, any entid)
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

// need to briefly stun the target if they have continuous or other special weapons out
// these weapons can do so much as crash the user's client if they're quick switched
// the stun-unstun will prevent this from happening, but it may or may not stop the target's motion if on ground
stock int PrepareForWeaponSwitch(int clientIdx, bool isBoss)
{
	int primary = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary);
	if (!IsValidEntity(primary) || primary != GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon"))
		return;
	
	bool shouldStun = false;
	static char restoreClassname[MAX_ENTITY_CLASSNAME_LENGTH];
	int itemDefinitionIndex = -1;
	if (EntityStartsWith(primary, "tf_weapon_minigun") || EntityStartsWith(primary, "tf_weapon_compound_bow"))
	{
		//SetEntProp(primary, Prop_Send, "m_iWeaponState", 0);
		if (!isBoss)
		{
			GetEntityClassname(primary, restoreClassname, MAX_ENTITY_CLASSNAME_LENGTH);
			itemDefinitionIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
			TF2_RemoveWeaponSlot(clientIdx, TFWeaponSlot_Primary);
		}
		shouldStun = true;
	}
	else if (EntityStartsWith(primary, "tf_weapon_sniperrifle") || EntityStartsWith(primary, "tf_weapon_flamethrower"))
		shouldStun = true;

	if (shouldStun)
	{
		TF2_StunPlayer(clientIdx, 0.1, 0.0, TF_STUNFLAG_BONKSTUCK | TF_STUNFLAG_NOSOUNDOREFFECT);
		TF2_RemoveCondition(clientIdx, TFCond_Dazed);
	}
	
	if (itemDefinitionIndex != -1)
	{
		if (!strcmp(restoreClassname, "tf_weapon_compound_bow"))
		{
//			SpawnWeapon(clientIdx, restoreClassname, itemDefinitionIndex, 5, 10, "37 ; 0.5 ; 328 ; 1.0 ; 2 ; 1.5", 1, true);
			SpawnWeapon(clientIdx, restoreClassname, itemDefinitionIndex, 5, 10, "2 ; 1.5", 1, true);
		}
		else
		{
			switch (itemDefinitionIndex)
			{
//				case 312: // brass beast
//					SpawnWeapon(clientIdx, restoreClassname, itemDefinitionIndex, 5, 10, "2 ; 1.2 ; 86 ; 1.5 ; 183 ; 0.4", 1, true);
//				case 424: // tomislav
//					SpawnWeapon(clientIdx, restoreClassname, itemDefinitionIndex, 5, 10, "5 ; 1.1 ; 87 ; 1.1 ; 238 ; 1 ; 375 ; 50", 1, true);
//				case 811, 832: // huo-long heater
//					SpawnWeapon(clientIdx, restoreClassname, itemDefinitionIndex, 5, 10, "430 ; 15.0 ; 431 ; 6.0 ; 153 ; 1.0", 1, true);
				default:
					SpawnWeapon(clientIdx, restoreClassname, itemDefinitionIndex, 5, 10, "", 1, true);
			}
		}
	}
}

#if !defined _FF2_Extras_included
stock int SpawnWeapon(int client, char[] name, int index, int level, int quality, char[] attribute, int visible = 1, bool preserve = false)
{
	Handle weapon = TF2Items_CreateItem((preserve ? PRESERVE_ATTRIBUTES : OVERRIDE_ALL) | FORCE_GENERATION);
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
	
	// sarysa addition
	if (!visible)
	{
		SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
	}
	
	if (StrContains(name, "tf_wearable") != 0)
		EquipPlayerWeapon(client, entity);
	else
		Wearable_EquipWearable(client, entity);
	return entity;
}

stock int Wearable_EquipWearable(int client, int wearable)
{
	static Handle S93SF_equipWearable = null;
	if(!S93SF_equipWearable)
	{
		GameData config = new GameData("equipwearable");
		if(config==null)
		{
			LogError("[FF2] EquipWearable gamedata could not be found; make sure /gamedata/equipwearable.txt exists.");
			return;
		}

		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "EquipWearable");
		CloseHandle(config);
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		if((S93SF_equipWearable=EndPrepSDKCall())==null)
		{
			LogError("[FF2] Couldn't load SDK function (CTFPlayer::EquipWearable). SDK call failed.");
			return;
		}
	}
	SDKCall(S93SF_equipWearable, client, wearable);
}
#endif

stock bool IsPlayerInRange(int player, float position[3], float maxDistance)
{
	maxDistance *= maxDistance;
	
	static float playerPos[3];
	GetEntPropVector(player, Prop_Data, "m_vecOrigin", playerPos);
	return GetVectorDistance(position, playerPos, true) <= maxDistance;
}

stock void ReadSound(int bossIdx, const char[] ability_name, int argInt, char soundFile[MAX_SOUND_FILE_LENGTH])
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, soundFile, MAX_SOUND_FILE_LENGTH);
	if (strlen(soundFile) > 3)
		PrecacheSound(soundFile);
}

stock void ReadModel(int bossIdx, const char[] ability_name, int argInt, char modelFile[MAX_MODEL_FILE_LENGTH])
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, modelFile, MAX_MODEL_FILE_LENGTH);
	if (strlen(modelFile) > 3)
		PrecacheModel(modelFile);
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
	MakeVectorFromPoints(startPos, endPos, tmpVec);
	GetVectorAngles(tmpVec, angles);
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
			
		GetClientEyePosition(listener, listenerPos);
		float distance = GetVectorDistance(emitterPos, listenerPos);
		if (distance >= radius)
			continue;
		
		float volume = (radius - distance) / radius;
		if (volume <= 0.0)
			continue;
		else if (volume > 1.0)
		{
			PrintToServer("[sarysapub3] How the hell is volume greater than 1.0?");
			volume = 1.0;
		}
		
		for (int i = 0; i < count; i++)
			EmitSoundToClient(listener, soundPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume);
	}
}

stock int min(int n1, int n2)
{
	return n1 < n2 ? n1 : n2;
}

stock int max(int n1, int n2)
{
	return n1 > n2 ? n1 : n2;
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

stock bool EntityStartsWith(int entity, const char[] desiredPrefix)
{
	static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, MAX_ENTITY_CLASSNAME_LENGTH);
	return StrContains(classname, desiredPrefix) == 0;
}

void SwapModel(int clientIdx, const char[] model)
{
	// standard important check here...
	if (!IsClientInGame(clientIdx) || !IsPlayerAlive(clientIdx))
		return;
		
	SetVariantString(model);
	AcceptEntityInput(clientIdx, "SetCustomModel");
	SetEntProp(clientIdx, Prop_Send, "m_bUseClassAnimations", 1);
}

/**
 * Taken from Roll the Dice mod by bl4nk
 */
int CreateRagdoll(int client, float flSelfDestruct=0.0, bool isIce=false)
{
	int iRag = CreateEntityByName("tf_ragdoll");
	if (iRag > MaxClients && IsValidEntity(iRag))
	{
		float flPos[3];
		float flAng[3];
		float flVel[3];
		GetClientAbsOrigin(client, flPos);
		GetClientAbsAngles(client, flAng);
		
		TeleportEntity(iRag, flPos, flAng, flVel);
		
		SetEntProp(iRag, Prop_Send, "m_iPlayerIndex", client);
		if (isIce)
			SetEntProp(iRag, Prop_Send, "m_bIceRagdoll", 1);
		SetEntProp(iRag, Prop_Send, "m_iTeam", GetClientTeam(client));
		SetEntProp(iRag, Prop_Send, "m_iClass", view_as<int>(TF2_GetPlayerClass(client)));
		SetEntProp(iRag, Prop_Send, "m_bOnGround", 1);
		
		SetEntityMoveType(iRag, MOVETYPE_NONE);
		
		DispatchSpawn(iRag);
		ActivateEntity(iRag);
		
		if (flSelfDestruct > 0.0)
			CreateTimer(flSelfDestruct, RemoveEntity2, EntIndexToEntRef(iRag), TIMER_FLAG_NO_MAPCHANGE);
		
		return iRag;
	}
	
	return -1;
}
