/*
rage_overlay_v2:	arg0 - slot (def.0)
					arg1 - number of overlays
					arg2 - path to overlay 1 ("root" is \tf\materials\)
					arg3 - duration 1 (def.6)
					arg4 - path to overlay 2 ("root" is \tf\materials\)
					arg5 - duration 2 (def.6)
					etc.
*/

#define FF2_USING_AUTO_PLUGIN__OLD

#include <tf2_stocks>
#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

int BossTeam = view_as<int>(TFTeam_Blue);

#define PLUGIN_VERSION "2.0.0"

public Plugin myinfo=
{
	name="Freak Fortress 2: rage_overlay_2",
	author="Jery0987, RainBolt Dash, Naydef",
	description="FF2: Ability that covers all living, non-boss team players screens with an image, now with option to use more than 1 image",
	version=PLUGIN_VERSION,
};

public void OnPluginStart2()
{
	HookEvent("teamplay_round_start", _OnRoundStart);
}

public Action _OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.3, Timer_GetBossTeam, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action Timer_GetBossTeam(Handle hTimer)
{
	BossTeam=FF2_GetBossTeam();
	return Plugin_Continue;
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	if(!strcmp(ability_name, "rage_overlay_v2"))
	{
		Rage_Overlay(boss, ability_name);
	}
	return Plugin_Continue;
}

void Rage_Overlay(int boss, const char[] ability_name)
{
	char overlay[PLATFORM_MAX_PATH];
	char buffer[PLATFORM_MAX_PATH];
	
	int numberofsounds=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 1, -1);
	if(numberofsounds<=0)
	{
		FF2_GetBossSpecial(boss, buffer, sizeof(buffer), 0);
		LogError("[FF2 Overlay v2] Sounds less than 1 | Boss %s", buffer);
		return;
	}
	
	int random=2*GetRandomInt(1, numberofsounds); // Only even numbers
	
	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, random , buffer, sizeof(buffer));
	if(!buffer[0])
	{
		FF2_GetBossSpecial(boss, buffer, sizeof(buffer), 0);
		LogError("[FF2 Overlay v2] Sound string is NULL! | Boss: %s", buffer);
		return;
	}
	
	Format(overlay, sizeof(overlay), "r_screenoverlay \"%s\"", buffer);
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
	for(int target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=BossTeam)
		{
			ClientCommand(target, overlay);
		}
	}

	CreateTimer(FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, random+1, 6.0), Timer_Remove_Overlay, _, TIMER_FLAG_NO_MAPCHANGE);
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
}

public Action Timer_Remove_Overlay(Handle timer)
{
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
	for(int target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=BossTeam)
		{
			ClientCommand(target, "r_screenoverlay \"\"");
		}
	}
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
	return Plugin_Continue;
}
