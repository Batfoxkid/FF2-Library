/*
rage_ams_overlay:	arg0 - slot (def.0)
				arg1 - path to overlay ("root" is \tf\materials\)
				arg2 - duration (def.6)
*/
#pragma semicolon 1
#define FF2_USING_AUTO_PLUGIN__OLD

#include <tf2_stocks>
#include <ff2_ams2>
#include <freak_fortress_2>

#pragma newdecls required

public Plugin myinfo =
{
	name="Freak Fortress 2: Overlay Rage for AMS",
	author="M76030",
	description="The Stock FF2 ability rage_overlay, now compatible with AMS",
	version="1.0.0",
};

#define OVERLAY "rage_ams_overlay"
bool Overlay_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS

public void OnPluginStart2()
{
	HookEvent("arena_win_panel", event_round_end, EventHookMode_PostNoCopy);
}

public void FF2AMS_PreRoundStart(int client)
{
	if(FF2_HasAbility(FF2_GetBossIndex(client), this_plugin_name, OVERLAY))
	{
		Overlay_TriggerAMS[client] = FF2AMS_PushToAMS(client, this_plugin_name, OVERLAY, "RAOV");
	}
}

public Action event_round_end(Event event, const char[] name, bool dontBroadcast)
{
	for(int client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			Overlay_TriggerAMS[client] = false;
		}
	}
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue; // Because some FF2 forks still allow RAGE to be activated when the round is over....
	
	int client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!strcmp(ability_name, OVERLAY))	// Defenses
	{
		if(!LibraryExists("FF2AMS"))
		{
			Overlay_TriggerAMS[client]=false;
		}
		
		if(!Overlay_TriggerAMS[client])
			RAOV_Invoke(client, -1);
	}
	return Plugin_Continue;
}

public AMSResult RAOV_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void RAOV_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	
	char overlay[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, OVERLAY, 1, overlay, PLATFORM_MAX_PATH);
	
	if(Overlay_TriggerAMS[client])
	{
		static char sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_ams_overlay", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);	
		}
	}
	
	Format(overlay, PLATFORM_MAX_PATH, "r_screenoverlay \"%s\"", overlay);
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
	for(int target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam())
		{
			ClientCommand(target, overlay);
		}
	}

	CreateTimer(FF2_GetAbilityArgumentFloat(boss, this_plugin_name, OVERLAY, 2, 6.0), Timer_Remove_Overlay, _, TIMER_FLAG_NO_MAPCHANGE);
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
}

public Action Timer_Remove_Overlay(Handle timer)
{
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
	for(int target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam())
		{
			ClientCommand(target, "r_screenoverlay \"\"");
		}
	}
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
	return Plugin_Continue;
}

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client) || !IsClientConnected(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}
