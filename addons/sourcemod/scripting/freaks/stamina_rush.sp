#include <sdkhooks>
#include <ff2menu_included>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

#define this_ability_name "energy_overload"
#define MAXCLIENTS (MAXPLAYERS + 1)
#define IsRoundActive()	(FF2_IsFF2Enabled() && FF2_GetRoundState() == 1)
#define IsValidPlayer(%1)	(%1 <= MaxClients && %1 > 0 && IsClientInGame(%1))

bool IsActive;

bool IsInRush[MAXCLIENTS];

public Plugin myinfo = 
{
	name			= "Stamina Rush",
	author		= "[01]Pollux."
};

public APLRes AskPluginLoad2(Handle Plugin, bool late, char[] err, int err_max)
{
	MarkNativeAsOptional("FF2MenuRage_PeekValue");
	MarkNativeAsOptional("FF2MenuRage_SetValue");
}

public void OnPluginStart2()
{
	HookEvent("arena_win_panel", Post_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Post_RoundStart, EventHookMode_PostNoCopy);
}

public void Post_RoundEnd(Event hevent, const char[] name, bool dontBroadcast)
{
	if(IsActive)
	{
		for (int x = 1; x <= MaxClients; x++) {
			if(!IsValidPlayer(x))
				continue;
			if(FF2_GetBossIndex(x) >= 0) {
				if(IsInRush[x]) {
					RemoveFromHook(x);
				}
			}
		}
		IsActive = false;
	}
}

public void Post_RoundStart(Event hevent, const char[] name, bool dontBroadcast)
{
	for (int boss; boss <= 12; boss++) 
	{
		int client = GetClientOfUserId(FF2_GetBossUserId(boss));
		if(!IsValidPlayer(client))
			continue;
		if(FF2_HasAbility(boss, this_plugin_name, this_ability_name))
		{
			IsActive = true;
			break;
		}
	}
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status){
}

public Action FF2MenuRage_OnStartRage(int boss, int &pts, int& rcost, const char[] Plugin_Name, const char[] Ability_Name)
{
	if(strcmp(Plugin_Name, this_plugin_name))
		return Plugin_Continue;
	if(!strcmp(Ability_Name, this_ability_name)) {
		int client = GetClientOfUserId(FF2_GetBossUserId(boss));
		switch(IsInRush[client]) {
			case true: {
				int cost = FF2_GetArgNamedI(boss, this_plugin_name, this_ability_name, "exit cost", 10);
				if(pts >= cost) {
					FF2MenuRage_SetValue(client, "points", pts - cost);
				} else FF2MenuRage_SetValue(client, "points", 0);
				RemoveFromHook(client);
			}
			case false: {
				int cost = FF2_GetArgNamedI(boss, this_plugin_name, this_ability_name, "enter cost", 0);
				if(pts < cost) {
					static char message[64];
					FF2_GetArgNamedS(boss, this_plugin_name, this_ability_name, "too low", message, sizeof(message));
					PrintHintText(client, message, cost);
					return Plugin_Stop;
				}
				FF2MenuRage_SetValue(client, "points", pts - cost);
				AddToHook(client);
			}
		}
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

float flNextThink[MAXCLIENTS];
public void Post_RushThinkPost(int client)
{
	if(flNextThink[client] > GetGameTime())
		return;
	
	int boss = FF2_GetBossIndex(client);
	int pts = FF2MenuRage_PeekValue(client, "points");
	pts -= FF2_GetArgNamedI(boss, this_plugin_name, this_ability_name, "drain rate", 1);
	if(pts < 0) {
		RemoveFromHook(client);
		return;
	}
	
	FF2MenuRage_SetValue(client, "points", pts);
	float flthink = FF2_GetArgNamedF(boss, this_plugin_name, this_ability_name, "think time", 0.5);
	flNextThink[client] = GetGameTime() + flthink;
}

public Action On_RushTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(!IsRoundActive())
		return Plugin_Continue;
	
	if(IsPlayerAlive(victim) && IsPlayerAlive(attacker)) {
		if(!IsInRush[victim])
			return Plugin_Continue;
		if(!IsValidEntity(inflictor))
			return Plugin_Continue;
		
		static char cls[64];
		if(GetEntityClassname(inflictor, cls, sizeof(cls)) && (StrContains(cls, "sentry") != -1))
		{
			damagetype |= DMG_PREVENT_PHYSICS_FORCE;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

void ApplyOnEnter(int client)
{
	int boss = FF2_GetBossIndex(client);
	if(boss < 0)
		return;
	
	static char buffer[64];
	if(FF2_RandomSound("sound_start_rush", buffer, sizeof(buffer), boss))
		FF2_EmitVoiceToAll(buffer, client);
	
	FF2_GetArgNamedS(boss, this_plugin_name, this_ability_name, "particle_start", buffer, sizeof(buffer));
	if(strlen(buffer) > 3) {
		static float pos[3];
		FixParticlesName(buffer, sizeof(buffer), TF2_GetClientTeam(client));
		GetClientAbsOrigin(client, pos);
		CreateTimedParticle(client, buffer, pos, 1.5);
	}
	char[][] Cond = new char[12][4];
	FF2_GetArgNamedS(boss, this_plugin_name, this_ability_name, "conds", buffer, sizeof(buffer));
	int size = ExplodeString(buffer, " - ", Cond, 12, 4);
	
	while(size > 0) {
		TF2_AddCondition(client, view_as<TFCond>(StringToInt(Cond[size-1])), TFCondDuration_Infinite);
		--size;
	}
}


void ApplyOnExit(int client)
{
	int boss = FF2_GetBossIndex(client);
	if(boss < 0)
		return;
	
	static char buffer[64];
	if(FF2_RandomSound("sound_end_rush", buffer, sizeof(buffer), boss))
		FF2_EmitVoiceToAll(buffer, client);
	
	FF2_GetArgNamedS(boss, this_plugin_name, this_ability_name, "particle_end", buffer, sizeof(buffer));
	if(strlen(buffer) > 3) {
		static float pos[3];
		FixParticlesName(buffer, sizeof(buffer), TF2_GetClientTeam(client));
		GetClientAbsOrigin(client, pos);
		CreateTimedParticle(client, buffer, pos, 1.5);
	}
	char[][] Cond = new char[12][4];
	FF2_GetArgNamedS(boss, this_plugin_name, this_ability_name, "conds", buffer, sizeof(buffer));
	int size = ExplodeString(buffer, " - ", Cond, 12, 4);
	
	while(size > 0) {
		TF2_RemoveCondition(client, view_as<TFCond>(StringToInt(Cond[size-1])));
		--size;
	}
}

void AddToHook(int client) {
	if(IsInRush[client])
		return;
	IsInRush[client] = true;
	SDKHook(client, SDKHook_OnTakeDamageAlive, On_RushTakeDamage);
	SDKHook(client, SDKHook_PostThinkPost, Post_RushThinkPost);
	if(IsClientInGame(client) && IsPlayerAlive(client))
		ApplyOnEnter(client);
}

void RemoveFromHook(int client) {
	if(!IsInRush[client])
		return;
	IsInRush[client] = false;
	SDKUnhook(client, SDKHook_OnTakeDamageAlive, On_RushTakeDamage);
	SDKUnhook(client, SDKHook_PostThinkPost, Post_RushThinkPost);
	if(IsClientInGame(client) && IsPlayerAlive(client))
		ApplyOnExit(client);
}

stock void CreateTimedParticle(int owner, const char[] Name, float SpawnPos[3], float duration, bool bFollow = true)
{
	CreateTimer(duration, Timer_KillEntity, EntIndexToEntRef(AttachParticle(owner, Name, SpawnPos, bFollow)), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_KillEntity(Handle timer, any EntRef)
{
	int entity = EntRefToEntIndex(EntRef);
	if(IsValidEntity(entity))
		RemoveEntity(entity);
}

stock int AttachParticle(int owner, const char[] ParticleName, float SpawnPos[3], bool bFollow)
{
	int entity = CreateEntityByName("info_particle_system");

	TeleportEntity(entity, SpawnPos, NULL_VECTOR, NULL_VECTOR);

	static char buffer[64];
	FormatEx(buffer, sizeof(buffer), "target%i", owner);
	DispatchKeyValue(owner, "targetname", buffer);

	DispatchKeyValue(entity, "targetname", "tf2particle");
	DispatchKeyValue(entity, "parentname", buffer);
	DispatchKeyValue(entity, "effect_name", ParticleName);
	DispatchSpawn(entity);
	
	if(bFollow) {
		SetVariantString(buffer);
		AcceptEntityInput(entity, "SetParent", entity, entity);
	}
	
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", owner);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "start");
	
	return entity; 
}

stock bool FixParticlesName(char[] buffer, int size, const TFTeam iTeam)
{
	if((StrContains(buffer, "...") != -1) && iTeam == TFTeam_Red)  {
		ReplaceString(buffer, size, "...", "red");
		return true;
	} else if((StrContains(buffer, "...") != -1) && iTeam == TFTeam_Blue) {
		ReplaceString(buffer, size, "...", "blue");
		return true;
	}
	else return false;
}
