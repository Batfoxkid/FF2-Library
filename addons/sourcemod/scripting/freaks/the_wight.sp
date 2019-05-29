#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#define SOUND_WIGHT			"freak_fortress_2/thewight/wight_theme2.mp3"		// life lost, will be stopped when round ends
#define MODEL_WIGHT			"models/freak_fortress_2/waails/wight_witchhat.mdl"
#define WIGHT_SCALE		1.0

new wight_life;
new wight_boss;
new String:wight_model[PLATFORM_MAX_PATH]; // model to set

#define WIGHT "wrath_of_the_wight"
#define INACTIVE 100000000.0

public Plugin:myinfo = {
	name	= "FF2: The Wight's abilities",
	author	= "M7",
	version = "1.0",
};

public OnPluginStart2()
{
	HookEvent("teamplay_round_start", event_round_start, EventHookMode_PostNoCopy);
	
	HookEvent("teamplay_round_active", event_round_active, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", event_round_active, EventHookMode_PostNoCopy);
	
	HookEvent("teamplay_round_win", event_round_end, EventHookMode_PostNoCopy);
	
	HookEvent("player_death", event_player_death, EventHookMode_PostNoCopy);
	
	PrecacheSound(SOUND_WIGHT);
	PrecacheModel(MODEL_WIGHT);
}

public event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
	
	wight_life = 0;
	wight_boss = 0;
}

public event_round_active(Handle:event, const String:name[], bool:dontBroadcast)
{
	GetBossVars();
}

GetBossVars()
{
	if (FF2_HasAbility(0, this_plugin_name, WIGHT))
	{
		new userid = FF2_GetBossUserId(0);
		new client = GetClientOfUserId(userid);
		if (client && IsClientInGame(client) && IsPlayerAlive(client))
		{
			wight_boss = client;
			return;
		}
	}
	
	wight_boss = 0;
}

public event_round_end(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			wight_life = 0;
			wight_boss = 0;
			StopSound(client, SNDCHAN_AUTO, SOUND_WIGHT);
		}
	}
}

public Action:FF2_OnLoseLife(index)
{		
	if (!wight_life && wight_boss && GetClientOfUserId(FF2_GetBossUserId(index)) == wight_boss && IsPlayerAlive(wight_boss))
	{
		FF2_GetAbilityArgumentString(index, this_plugin_name, WIGHT, 2, wight_model, sizeof(wight_model));
		
		SetVariantString(wight_model);
		AcceptEntityInput(wight_boss, "SetCustomModel");
		SetEntProp(wight_boss, Prop_Send, "m_bUseClassAnimations", 1);
		
		FF2_StopMusic(0);
		
		EmitSoundToAll(SOUND_WIGHT);
		
		wight_life++;
	}
	return Plugin_Continue;
}

public Action:FF2_OnMusic(String:path[], &Float:time)
{
	if (wight_life)
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:FF2_OnAbility2(clientIdx, const String:plugin_name[], const String:ability_name[], status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue;
	
	new bossIdx=GetClientOfUserId(FF2_GetBossUserId(clientIdx));
	new Float:bossPosition[3], Float:targetPosition[3];
	new Float:distance=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, WIGHT, 1, FF2_GetRageDist(bossIdx, this_plugin_name, WIGHT));
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossPosition);
	
	for(new target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam())
		{
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPosition);
			if(GetVectorDistance(bossPosition, targetPosition)<=distance)
			{
				SDKHooks_TakeDamage(target, bossIdx, bossIdx, 9999.9, DMG_BLAST);
			}
		}
	}
	
	return Plugin_Continue;
}

public event_player_death(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (client > 0 && client <= MaxClients)
	{
		if (client == wight_boss)
		{
			new prop = CreateEntityByName("prop_physics_override");
			if (prop != -1)
			{
				RemoveRagdoll(client);
				
				decl Float:pos[3], Float:ang[3];
				
				GetClientAbsOrigin(client, pos);
				GetClientAbsAngles(client, ang);
				
				DispatchKeyValueVector(prop, "origin", pos);
				DispatchKeyValueVector(prop, "angles", ang);
				DispatchKeyValue(prop, "model", MODEL_WIGHT);
				DispatchKeyValue(prop, "disableshadows", "1");
				
				SetEntProp(prop, Prop_Send, "m_CollisionGroup", 1);
				SetEntProp(prop, Prop_Send, "m_usSolidFlags", 16);
				
				DispatchSpawn(prop);
				
				ActivateEntity(prop);
				AcceptEntityInput(prop, "EnableMotion");
				
				SetEntPropFloat(prop, Prop_Send, "m_flModelScale", WIGHT_SCALE);
			}
			
			wight_boss = 0;
		}
	}
}

stock RemoveRagdoll(client)
{
	RequestFrame(Frame_RemoveRagdoll, GetClientUserId(client));
}
public Frame_RemoveRagdoll(any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client && IsClientInGame(client))
	{
		new ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		if (ragdoll > MaxClients)
		{
			AcceptEntityInput(ragdoll, "Kill");
		}
	}
}

stock bool:IsValidClient(client, bool:isPlayerAlive=false)
{
	if (client <= 0 || client > MaxClients) return false;
	if(isPlayerAlive) return IsClientInGame(client) && IsPlayerAlive(client);
	return IsClientInGame(client);
}