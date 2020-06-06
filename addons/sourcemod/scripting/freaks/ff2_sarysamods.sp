#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

/**
 * A bunch of original code and others' tweaked code for mechanics related to my Cheese Sandwich boss.
 * Everything with "Delayable" in the name has an optional time delay. If it's 0 it executes immediately.
 *
 * OVERALL Known Issues:
 * - Single bosses have been tested thoroughly. Multi-bosses support was added on 2014-04-20 but has only had limited testing.
 * - If you have the RTD mod installed on your server and non-engies can make sentry guns, search and remove if check with TFClass_Engineer
 * - Don't time any of the delayables longer than it'd take between last end of round and next round respawn
 *
 * DelayableDamage: Damage in a radius with no visual effect, which allows a delay before execution.
 *	Credits: Took minor samples from phatrages and other minor sources while making this.
 *
 * DelayableEarthquake: Display an earthquake to living non-hale players for a period, optionally play a sound.
 *	Credits: Ripped some functions straight from phatrages.
 *		 Took minor samples from phatrages and other minor sources while making this.
 *
 * DelayableBuildingDestruction: Destroys all buildings of specified types except the ones the engie is holding.
 *
 * DelayableParticleEffect: Display a particle effect on all players in a radius for N seconds.
 *	Credits: Took some of the code used when sentries are raged.
 *
 * Airblast Immunity: Airblast immunity for N seconds.
 *
 * Mapwide Sound: And you thought the above was reinventing the wheel. Plays a map-wide sound on rage, instead of the standard local rage sound.
 *
 * ======= Revised on 2015-03-20, with plenty of opportunity to laugh at my old work from 2014-03-2X =======
 */

// change this to minimize console output
bool PRINT_DEBUG_INFO = true;

#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

// text string limits
#define MAX_SOUND_FILE_LENGTH 128
#define MAX_MODEL_SWAP_LENGTH 128
#define MAX_WEAPON_NAME_LENGTH 64
#define MAX_WEAPON_ARG_LENGTH 128
// messages already truncated so may as well waste less memory space
#define MAX_TUTORIAL_MESSAGE_LENGTH 170
#define MAX_EFFECT_NAME_LENGTH 64

#define FAR_FUTURE 100000000.0

// don't let timed rages be activated after round ends, they WILL leak over otherwise!
bool PluginActiveThisRound = false;
bool RoundInProgress = false;

// for airblast immunity
#define AI_STRING "rage_airblast_immunity"
bool AI_ActiveThisRound;
bool AI_CanUse[MAX_PLAYERS_ARRAY];
float AI_EndsAt[MAX_PLAYERS_ARRAY];

// for delayable damage
#define DD_STRING "rage_delayable_damage"
bool DD_ActiveThisRound;
bool DD_CanUse[MAX_PLAYERS_ARRAY];
float DD_ExecuteRageAt[MAX_PLAYERS_ARRAY]; // internal

// for delayable earthquake
#define DE_STRING "rage_delayable_earthquake"
bool DE_ActiveThisRound;
bool DE_CanUse[MAX_PLAYERS_ARRAY];
float DE_ExecuteRageAt[MAX_PLAYERS_ARRAY]; // internal

// for delayable building destruction
#define DBD_STRING "rage_delayable_building_destruction"
bool DBD_ActiveThisRound;
bool DBD_CanUse[MAX_PLAYERS_ARRAY];
float DBD_ExecuteRageAt[MAX_PLAYERS_ARRAY]; // internal

// for delayable particle effect
#define DPE_STRING "rage_delayable_particle_effect"
bool DPE_ActiveThisRound;
bool DPE_CanUse[MAX_PLAYERS_ARRAY];
float DPE_ExecuteRageAt[MAX_PLAYERS_ARRAY]; // internal

// for mapwide sound
#define MWS_STRING "rage_mapwide_sound_sarysamods"

// for rage gain with few players
#define SERG_STRING "ff2_scaled_endgame_rage_gain"
#define SERG_INTERVAL 1.0
bool SERG_ActiveThisRound = false;
float SERG_NextCheckAt;
bool SERG_CanUse[MAX_PLAYERS_ARRAY];
int SERG_PlayersAliveToStart[MAX_PLAYERS_ARRAY];
float SERG_OnePlayerRPS[MAX_PLAYERS_ARRAY];

public Plugin myinfo = {
	name = "Freak Fortress 2: sarysa's mods",
	author = "sarysa",
	version = "1.1.0",
};
	
public void OnPluginStart2()
{
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public Action Event_RoundStart(Event event,const char[] name, bool dontBroadcast)
{
	// various non-array inits
	PluginActiveThisRound = false;
	SERG_ActiveThisRound = false;
	AI_ActiveThisRound = false;
	DD_ActiveThisRound = false;
	DE_ActiveThisRound = false;
	DBD_ActiveThisRound = false;
	DPE_ActiveThisRound = false;
	
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		// various array inits
		AI_CanUse[clientIdx] = false;
		SERG_CanUse[clientIdx] = false;
		DD_CanUse[clientIdx] = false;
		DE_CanUse[clientIdx] = false;
		DBD_CanUse[clientIdx] = false;
		DPE_CanUse[clientIdx] = false;

		if (!IsLivingPlayer(clientIdx) || GetClientTeam(clientIdx) != FF2_GetBossTeam())
			continue;
		int bossIdx = FF2_GetBossIndex(clientIdx);
		if (bossIdx < 0)
			continue;

		if ((SERG_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, SERG_STRING)) == true)
		{
			PluginActiveThisRound = true;
			SERG_ActiveThisRound = true;
			SERG_PlayersAliveToStart[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, SERG_STRING, 1);
			SERG_OnePlayerRPS[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SERG_STRING, 2);
		}

		if ((DD_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, DD_STRING)) == true)
		{
			PluginActiveThisRound = true;
			DD_ActiveThisRound = true;
			DD_ExecuteRageAt[clientIdx] = FAR_FUTURE;
		}
		
		if ((DE_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, DE_STRING)) == true)
		{
			PluginActiveThisRound = true;
			DE_ActiveThisRound = true;
			DE_ExecuteRageAt[clientIdx] = FAR_FUTURE;

			static char soundFile[MAX_SOUND_FILE_LENGTH];
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DE_STRING, 6, soundFile, MAX_SOUND_FILE_LENGTH);
			if (strlen(soundFile) > 3)
				PrecacheSound(soundFile);
		}
		
		if ((DBD_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, DBD_STRING)) == true)
		{
			PluginActiveThisRound = true;
			DBD_ActiveThisRound = true;
			DBD_ExecuteRageAt[clientIdx] = FAR_FUTURE;
		}
		
		if ((DPE_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, DPE_STRING)) == true)
		{
			PluginActiveThisRound = true;
			DPE_ActiveThisRound = true;
			DPE_ExecuteRageAt[clientIdx] = FAR_FUTURE;
		}

		if ((AI_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, AI_STRING)) == true)
		{
			PluginActiveThisRound = true;
			AI_ActiveThisRound = true;
			AI_EndsAt[clientIdx] = FAR_FUTURE;
		}

		if (FF2_HasAbility(bossIdx, this_plugin_name, MWS_STRING))
		{
			static char soundFile[MAX_SOUND_FILE_LENGTH];
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MWS_STRING, 1, soundFile, MAX_SOUND_FILE_LENGTH);
			if (strlen(soundFile) > 3)
				PrecacheSound(soundFile);
		}
	}
	
	// allow game frame rages to execute
	RoundInProgress = true;

	if (SERG_ActiveThisRound)
		SERG_NextCheckAt = GetEngineTime() + SERG_INTERVAL;
}

public Action Event_RoundEnd(Event event,const char[] name, bool dontBroadcast)
{
	// don't activate timed rages anymore
	RoundInProgress = false;
}

public Action FF2_OnAbility2(int bossIdx, const char[] plugin_name, const char[] ability_name, int status)
{
	// I'm allowing this to happen after hale wins. playing rage sounds after winning is a time-honored tradition. :D
	if (!strcmp(ability_name, MWS_STRING))
	{
		static char soundFile[MAX_SOUND_FILE_LENGTH];
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MWS_STRING, 1, soundFile, MAX_SOUND_FILE_LENGTH);
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods1] Playing important sound: %s", soundFile);
		
		if (strlen(soundFile) > 3)
			EmitSoundToAll(soundFile);
	}

	if (!RoundInProgress)
		return Plugin_Continue;

	// strictly enforce the correct plugin is specified.
	// these were working earlier with no specification...eep.
	if (strcmp(plugin_name, this_plugin_name))
		return Plugin_Continue;

	if (!strcmp(ability_name, DD_STRING))
		Rage_DelayableDamage(ability_name, bossIdx);
	else if (!strcmp(ability_name, DE_STRING))
		Rage_DelayableEarthquake(ability_name, bossIdx);
	else if (!strcmp(ability_name, DBD_STRING))
		Rage_DelayableBuildingDestruction(ability_name, bossIdx);
	else if (!strcmp(ability_name, DPE_STRING))
		Rage_DelayableParticleEffect(ability_name, bossIdx);
	else if (!strcmp(ability_name, AI_STRING))
		Rage_AirblastImmunity(ability_name, bossIdx);
		
	return Plugin_Continue;
}

/**
 * Airblast Immunity (fun fact, in March 2014 I actually made this as a standalone ability. lol)
 */
public void Rage_AirblastImmunity(const char[] ability_name, int bossIdx)
{
	// get rage metadata first
	int clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	float duration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 1);
	bool includeUber = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 2) == 1;
	
	// don't add effects if not necessary
	if (AI_EndsAt[clientIdx] == FAR_FUTURE)
	{
		TF2_AddCondition(clientIdx, TFCond_MegaHeal, -1.0);
		if (includeUber)
		{
			TF2_AddCondition(clientIdx, TFCond_Ubercharged, -1.0);
			SetEntProp(clientIdx, Prop_Data, "m_takedamage", 0);
		}
	}
	
	AI_EndsAt[clientIdx] = GetEngineTime() + duration;
}

public void AI_EndRage(int clientIdx)
{
	TF2_RemoveCondition(clientIdx, TFCond_MegaHeal);
	TF2_RemoveCondition(clientIdx, TFCond_Ubercharged);
	SetEntProp(clientIdx, Prop_Data, "m_takedamage", 2);
	
	AI_EndsAt[clientIdx] = FAR_FUTURE;
}

/**
 * Delayable Particle Effect
 */
void DelayableParticleEffect(int clientIdx)
{
	int bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;
		
	float duration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DPE_STRING, 2);
	float radiusSquared = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DPE_STRING, 3);
	radiusSquared = radiusSquared * radiusSquared;
	char effectName[MAX_EFFECT_NAME_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DPE_STRING, 4, effectName, MAX_EFFECT_NAME_LENGTH);

	if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods1] %s executing. clientIdx=%i, duration=%f, radius(square)=%f, effectName=%s", DPE_STRING, clientIdx, duration, radiusSquared, effectName);
	
	static float bossPos[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossPos);
	static float victimPos[3];
	for (int victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (IsLivingPlayer(victim) && GetClientTeam(victim) != FF2_GetBossTeam())
		{
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
			if (GetVectorDistance(bossPos, victimPos, true) <= radiusSquared)
			{
				int particle = AttachParticle(victim, effectName, 75.0);
				if (particle != -1)
					CreateTimer(duration, RemoveEntityDA, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE); // revamp note: I'm allowing this.
			}
		}
	}

	DPE_ExecuteRageAt[clientIdx] = FAR_FUTURE;
}

void Rage_DelayableParticleEffect(const char[] ability_name, int bossIdx)
{
	float delay = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 1);
	int clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	// everything looks good
	if (delay > 0)
		DPE_ExecuteRageAt[clientIdx] = GetEngineTime() + delay;
	else
		DelayableParticleEffect(clientIdx);
}

/**
 * Delayable Building Destruction
 */
void DestroyBuildingsOfType(const char[] classname, int clientIdx, bool saveByCarry, float radiusSquared)
{
	int building = 0;
	while ((building = FindEntityByClassname(building, classname)) != -1)
	{
		// ensure the building is in range
		static float bossPos[3];
		static float objPos[3];
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossPos);
		GetEntPropVector(building, Prop_Send, "m_vecOrigin", objPos);
		if (GetVectorDistance(bossPos, objPos, true) > radiusSquared)
			continue;
		
		// holy shit, TakeDamage does what I want to do with Cheese. makes up for how difficult texture swap was. :P
		// alas, I want to make this flexible, so gotta create the "destroy everything" version too
		if (saveByCarry)
			SDKHooks_TakeDamage(building, clientIdx, clientIdx, 5000.0, DMG_GENERIC, -1);
		else if (!(GetEntProp(building, Prop_Send, "m_bCarried") == 0 && GetEntProp(building, Prop_Send, "m_bPlacing") != 0))
		{
			if (GetEntProp(building, Prop_Send, "m_bPlacing"))
				Timer_RemoveEntity(building, 0.0);
			else
				SDKHooks_TakeDamage(building, clientIdx, clientIdx, 5000.0, DMG_GENERIC, -1);
		}
		
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods1] (probably) Destroyed %s, entity# %d", classname, building);
	}
}

void DelayableBuildingDestruction(int clientIdx)
{
	int bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;

	bool sentries = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DBD_STRING, 2) == 1;
	bool dispensers = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DBD_STRING, 3) == 1;
	bool teleporters = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DBD_STRING, 4) == 1;
	bool saveByCarry = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DBD_STRING, 5) == 1;
	float radiusSquared = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DBD_STRING, 6);
	radiusSquared = radiusSquared * radiusSquared;
	
	if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods1] %s executing. clientIdx=%i, sentries=%d, dispensers=%d, teleporters=%d, engiecansave=%d, radiusSquared=%f", DBD_STRING, clientIdx, sentries, dispensers, teleporters, saveByCarry, radiusSquared);
		
	if (sentries)
		DestroyBuildingsOfType("obj_sentrygun", clientIdx, saveByCarry, radiusSquared);
	if (dispensers)
		DestroyBuildingsOfType("obj_dispenser", clientIdx, saveByCarry, radiusSquared);
	if (teleporters)
		DestroyBuildingsOfType("obj_teleporter", clientIdx, saveByCarry, radiusSquared);

	DBD_ExecuteRageAt[clientIdx] = FAR_FUTURE;
}

void Rage_DelayableBuildingDestruction(const char[] ability_name, int bossIdx)
{
	float delay = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 1);
	int clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	// everything looks good
	if (delay > 0)
		DBD_ExecuteRageAt[clientIdx] = GetEngineTime() + delay;
	else
		DelayableBuildingDestruction(clientIdx);
}

/**
 * Delayable Earthquake
 */
void DelayableEarthquake(int clientIdx)
{
	int bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;
		
	float duration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DE_STRING, 2);
	float radiusSquared = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DE_STRING, 3);
	radiusSquared = radiusSquared * radiusSquared;
	float amplitude = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DE_STRING, 4);
	float frequency = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DE_STRING, 5);
	char soundFile[MAX_SOUND_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DE_STRING, 6, soundFile, MAX_SOUND_FILE_LENGTH);

	if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods1] %s executing. BossIdx=%i, duration=%f, radiusSquared=%f, amplitude=%f, frequency=%f, sound=%s", DE_STRING, clientIdx, duration, radiusSquared, amplitude, frequency, soundFile);
	
	// shake it, Gummy! Uh-huh! You know it!
	static float bossPos[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossPos);
	env_shake(bossPos, amplitude, radiusSquared, duration, frequency);
	
	// play optional sound
	if (strlen(soundFile) > 3)
	{
		static float victimPos[3];
		for (int victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (IsLivingPlayer(victim) && GetClientTeam(victim) != FF2_GetBossTeam())
			{
				GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
				if (GetVectorDistance(bossPos, victimPos, true) <= radiusSquared)
					EmitSoundToClient(victim, soundFile);
			}
		}
	}
		
	DE_ExecuteRageAt[clientIdx] = FAR_FUTURE;
}

void Rage_DelayableEarthquake(const char[] ability_name, int bossIdx)
{
	float delay = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 1);
	int clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	// everything looks good
	if (delay > 0)
		DE_ExecuteRageAt[clientIdx] = GetEngineTime() + delay;
	else
		DelayableEarthquake(clientIdx);
}

/**
 * Delayable Damage
 */
void DelayableDamage(int clientIdx)
{
	int bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;
		
	float damage = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DD_STRING, 2);
	float radius = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DD_STRING, 3);
	//int weapon = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DD_STRING, 4); // useless, but I can't reclaim this prop since it's an old old boss :P
	float knockback = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DD_STRING, 5);
	bool scaleByDistance = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DD_STRING, 6) == 1;
	bool liftLowZ = FF2_GetAbilityArgument(bossIdx, this_plugin_name, DD_STRING, 7) == 1;

	if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods1] %s executing. clientIdx=%i, damage=%f, radius=%i, knockback=%f, scaleByDistance=%i, liftLowZ=%i", DD_STRING, clientIdx, damage, radius, knockback, scaleByDistance, liftLowZ);
	
	static float bossPos[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossPos);
	static float victimPos[3];
	static float kbTarget[3];
	for (int victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (IsLivingPlayer(victim) && GetClientTeam(victim) != FF2_GetBossTeam())
		{
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
			float distance = GetVectorDistance(bossPos, victimPos);
			if (distance < radius && !TF2_IsPlayerInCondition(victim, TFCond_Ubercharged))
			{
				SDKHooks_TakeDamage(victim, clientIdx, clientIdx, damage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
				
				// this seems to be how the cool kids are doing knockback...and subsequently how I do it for a zillion packs. hasn't gone wrong yet.
				// dear god. early work. even at my age I still cringe at it.
				if (knockback > 0.0)
				{
					MakeVectorFromPoints(bossPos, victimPos, kbTarget);
					NormalizeVector(kbTarget, kbTarget);
					
					// replace low Z values to give some lift, and give the hale designer more flexibility with the knockback.
					if (kbTarget[2] < 0.1 && !(kbTarget[2] < 0 && liftLowZ))
						kbTarget[2] = 0.1;
					
					ScaleVector(kbTarget, (scaleByDistance ? knockback : (knockback * (((radius - distance) * 2) / radius)))); // can opt to factor distance

					TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, kbTarget);
				}
			}
		}
	}
	
	DD_ExecuteRageAt[clientIdx] = FAR_FUTURE;
}

void Rage_DelayableDamage(const char[] ability_name, int bossIdx)
{
	float delay = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 1);
	int clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	// everything looks good
	if (delay > 0)
		DD_ExecuteRageAt[clientIdx] = GetEngineTime() + delay;
	else
		DelayableDamage(clientIdx);
}

/**
 * Scaled Endgame Rage Gain (SERG)
 */
public void SERG_GiveRageIfNecessary()
{
	// get a living red team count first of all
	int clientCount = 0;
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (IsLivingPlayer(clientIdx) && GetClientTeam(clientIdx) != FF2_GetBossTeam())
			clientCount++;
	}
	
	// now see if any of the hales get rage
	if (clientCount > 0)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (!IsLivingPlayer(clientIdx))
				continue;

			if (SERG_CanUse[clientIdx] && SERG_PlayersAliveToStart[clientIdx] >= clientCount)
			{
				int bossIdx = FF2_GetBossIndex(clientIdx);
				if (bossIdx < 0) // wtf?
					continue;

				float rageToGive = (SERG_OnePlayerRPS[clientIdx] * ((SERG_PlayersAliveToStart[clientIdx] - clientCount) + 1)) / SERG_PlayersAliveToStart[clientIdx];
				float rage = FF2_GetBossCharge(bossIdx, 0);
				rage += rageToGive;
				if (rage > 100.0)
					rage = 100.0;
				FF2_SetBossCharge(bossIdx, 0, rage);
			}
		}
	}
	
	SERG_NextCheckAt += SERG_INTERVAL;
}

/**
 * OnGameFrame, ditching the old timers
 */
public void OnGameFrame()
{
	if (!PluginActiveThisRound || !RoundInProgress)
		return;
	
	float curTime = GetEngineTime();
	
	if (SERG_ActiveThisRound && curTime >= SERG_NextCheckAt)
		SERG_GiveRageIfNecessary();

	// combining things that need to loop through clients, for efficiency
	if (DD_ActiveThisRound || DE_ActiveThisRound || DBD_ActiveThisRound || DPE_ActiveThisRound || AI_ActiveThisRound)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (!IsLivingPlayer(clientIdx) || GetClientTeam(clientIdx) != FF2_GetBossTeam())
				continue;
				
			if (DD_CanUse[clientIdx] && curTime >= DD_ExecuteRageAt[clientIdx])
				DelayableDamage(clientIdx);
			if (DE_CanUse[clientIdx] && curTime >= DE_ExecuteRageAt[clientIdx])
				DelayableEarthquake(clientIdx);
			if (DBD_CanUse[clientIdx] && curTime >= DBD_ExecuteRageAt[clientIdx])
				DelayableBuildingDestruction(clientIdx);
			if (DPE_CanUse[clientIdx] && curTime >= DPE_ExecuteRageAt[clientIdx])
				DelayableParticleEffect(clientIdx);
			if (AI_CanUse[clientIdx] && curTime >= AI_EndsAt[clientIdx])
				AI_EndRage(clientIdx);
		}
	}
}

/**
 * Stocks
 */
stock bool IsLivingPlayer(int clientIdx)
{
	if (clientIdx <= 0 || clientIdx >= MAX_PLAYERS)
		return false;
		
	return IsClientInGame(clientIdx) && IsPlayerAlive(clientIdx);
}

/**
 * CODE BELOW WAS TAKEN STRAIGHT FROM PHATRAGES, I TAKE NO CREDIT FOR IT
 */
void env_shake(float Origin[3], float Amplitude, float Radius, float Duration, float Frequency)
{
	static int Ent;

	//Initialize:
	Ent = CreateEntityByName("env_shake");
		
	//Spawn:
	if (IsValidEntity(Ent))
	{
		//Properties:
		DispatchKeyValueFloat(Ent, "amplitude", Amplitude);
		DispatchKeyValueFloat(Ent, "radius", Radius);
		DispatchKeyValueFloat(Ent, "duration", Duration);
		DispatchKeyValueFloat(Ent, "frequency", Frequency);

		SetVariantString("spawnflags 8");
		AcceptEntityInput(Ent,"AddOutput");

		//Input:
		AcceptEntityInput(Ent, "StartShake", 0);
		
		// create
		DispatchSpawn(Ent);
		
		//Send:
		TeleportEntity(Ent, Origin, NULL_VECTOR, NULL_VECTOR);

		//Delete:
		Timer_RemoveEntity(Ent, Duration + 1.0);
	}
}

void Timer_RemoveEntity(int entity, float time = 0.0)
{
	if (time == 0.0)
	{
		if(IsValidEntity(entity))
		{
			RemoveEntity(entity);
		}
	}
	else
	{
		CreateTimer(time, RemoveEntityTimer, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action RemoveEntityTimer(Handle Timer, any entRef)
{
	int entity = EntRefToEntIndex(entRef);
	if(IsValidEntity(entity))
		RemoveEntity(entity);
	
	return Plugin_Stop;
}

/**
 * CODE BELOW TAKEN FROM default_abilities, I CLAIM NO CREDIT
 */
public Action RemoveEntityDA(Handle timer, any entid)
{
	int entity=EntRefToEntIndex(entid);
	if(IsValidEdict(entity) && entity>MAX_PLAYERS)
	{
		RemoveEntity(entity);
	}
}

stock int AttachParticle(int entity, char[] particleType, float offset=0.0, bool attach=true)
{
	int particle = CreateEntityByName("info_particle_system");
	if (!IsValidEntity(particle))
		return -1;

	static char targetName[128];
	static float position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	position[2]+=offset;
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

	Format(targetName, sizeof(targetName), "target%i", entity);
	DispatchKeyValue(entity, "targetname", targetName);

	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", targetName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(targetName);
	if(attach)
	{
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	}
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	return particle;
}
