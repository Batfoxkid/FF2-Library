/*
overlay_on_kill:
	arg1 - path to overlay ("root" is \tf\materials\)
	arg2 - duration (def.6)
*/

#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.4"

float RemoveOverlayAt[MAXPLAYERS+1];
#define INACTIVE 100000000.0

public Plugin myinfo=
{
	name="Freak Fortress 2: Overlay on Kill",
	author="Jery0987, RainBolt Dash, SHADoW NiNE TR3S",
	description="FF2: Same as rage_overlay but when a player is killed.",
	version=PLUGIN_VERSION,
};

public void OnPluginStart2()
{
	HookEvent("arena_round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("arena_win_panel", Event_WinPanel);
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	// NOOP
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker=GetClientOfUserId(GetEventInt(event, "attacker"));
	int client=GetClientOfUserId(GetEventInt(event, "userid"));
	int boss=FF2_GetBossIndex(attacker);
	if(boss>=0)
	{
		static char overlay[PLATFORM_MAX_PATH];
		FF2_GetAbilityArgumentString(boss, this_plugin_name, "overlay_on_kill", 1, overlay, PLATFORM_MAX_PATH);
		Format(overlay, PLATFORM_MAX_PATH, "r_screenoverlay \"%s\"", overlay);
		SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
		float duration=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "overlay_on_kill", 2, 6.0);
		if(IsValidPlayer(client) && GetClientTeam(client)!=FF2_GetBossTeam())
		{
			if(duration)
			{	
				RemoveOverlayAt[client]=GetGameTime()+duration;
			}
			ClientCommand(client, overlay);
			SDKHook(client, SDKHook_PreThink, ShowOverlay_PreThink);
		}
		SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);	
	}
}

public void ShowOverlay_PreThink(int client)
{
	if(FF2_GetRoundState()!=1 || !IsValidPlayer(client))
	{
		SDKUnhook(client, SDKHook_PreThink, ShowOverlay_PreThink);
	}
	TimerTick(client, GetGameTime());
}
public void TimerTick(int client, float gameTime)
{
	if(gameTime>=RemoveOverlayAt[client])
	{
		SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
		if(IsValidPlayer(client))
		{
			ClientCommand(client, "r_screenoverlay \"\"");
		}	
		SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);	
		RemoveOverlayAt[client]=INACTIVE;
	}
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int client=1;client<=MaxClients;client++)
	{
		RemoveOverlayAt[client]=INACTIVE;
	}
}

public Action Event_WinPanel(Event event, const char[] name, bool dontBroadcast)
{
	for(int client=1;client<=MaxClients;client++)
	{
		SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
		if(IsValidPlayer(client))
		{
			ClientCommand(client, "r_screenoverlay \"\"");
		}
		SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
		RemoveOverlayAt[client]=INACTIVE;
		SDKUnhook(client, SDKHook_PreThink, ShowOverlay_PreThink);
	}
}

stock bool IsValidPlayer(int client)
{
	if (client <= 0 || client > MaxClients)
		return false;
		
	return IsClientInGame(client);
}
