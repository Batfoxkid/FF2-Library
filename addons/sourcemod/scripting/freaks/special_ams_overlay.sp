/*
rage_ams_overlay:	arg0 - slot (def.0)
				arg1 - path to overlay ("root" is \tf\materials\)
				arg2 - duration (def.6)
*/
#pragma semicolon 1

#include <sourcemod>
#include <tf2items>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <ff2_ams>

public Plugin:myinfo=
{
	name="Freak Fortress 2: Overlay Rage for AMS",
	author="M76030",
	description="The Stock FF2 ability rage_overlay, now compatible with AMS",
	version="1.0.0",
};

#define OVERLAY "rage_ams_overlay"
new bool:Overlay_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS

public OnPluginStart2()
{
	HookEvent("arena_round_start", event_round_start, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", event_round_end, EventHookMode_PostNoCopy);
}

public Action:event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
		
	PrepareAbilities();
}

public PrepareAbilities()
{
	for(new client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			Overlay_TriggerAMS[client]=false;
			
			new boss=FF2_GetBossIndex(client);
			if(boss>=0)
			{
				if(FF2_HasAbility(boss, this_plugin_name, OVERLAY))
				{
					Overlay_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, OVERLAY);
					if(Overlay_TriggerAMS[client])
					{
						AMS_InitSubability(boss, client, this_plugin_name, OVERLAY, "RAOV"); // Important function to tell AMS that this subplugin supports it
					}
				}
			}
		}
	}
}

public Action:event_round_end(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			Overlay_TriggerAMS[client] = false;
		}
	}
}

public Action:FF2_OnAbility2(boss, const String:plugin_name[], const String:ability_name[], status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue; // Because some FF2 forks still allow RAGE to be activated when the round is over....
	
	new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!strcmp(ability_name, OVERLAY))	// Defenses
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			Overlay_TriggerAMS[client]=false;
		}
		
		if(!Overlay_TriggerAMS[client])
			RAOV_Invoke(client);
	}
	return Plugin_Continue;
}

public bool:RAOV_CanInvoke(client)
{
	return true;
}

public RAOV_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	
	decl String:overlay[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, OVERLAY, 1, overlay, PLATFORM_MAX_PATH);
	
	if(Overlay_TriggerAMS[client])
	{
		new String:sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_ams_overlay", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);	
		}
	}
	
	Format(overlay, PLATFORM_MAX_PATH, "r_screenoverlay \"%s\"", overlay);
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
	for(new target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam())
		{
			ClientCommand(target, overlay);
		}
	}

	CreateTimer(FF2_GetAbilityArgumentFloat(boss, this_plugin_name, OVERLAY, 2, 6.0), Timer_Remove_Overlay, _, TIMER_FLAG_NO_MAPCHANGE);
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
}

public Action:Timer_Remove_Overlay(Handle:timer)
{
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
	for(new target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam())
		{
			ClientCommand(target, "r_screenoverlay \"\"");
		}
	}
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
	return Plugin_Continue;
}

stock bool:IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client) || !IsClientConnected(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}