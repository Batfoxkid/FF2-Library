#pragma semicolon 1

#include <tf2_stocks>
#include <sdkhooks>
#include <ff2_ams2>
#include <ff2_dynamic_defaults>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma newdecls required

#define MAJOR_REVISION "1"
#define MINOR_REVISION "3"
#define PATCH_REVISION "4"

#if !defined PATCH_REVISION
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION
#else
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...PATCH_REVISION
#endif

// Movespeed
float NewSpeed[MAXPLAYERS+1];
float NewSpeedDuration[MAXPLAYERS+1];
bool NewSpeed_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS
bool DSM_SpeedOverride[MAXPLAYERS+1];

#define INACTIVE 100000000.0
#define MOVESPEED "rage_movespeed"
#define MOVESPEEDALIAS "MVS"

public Plugin myinfo = {
    name = "Freak Fortress 2: Move Speed",
    author = "SHADoW NiNE TR3S",
    version = PLUGIN_VERSION,
};

public void OnPluginStart2()
{
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("arena_win_panel", Event_WinPanel);
	
	if(FF2_GetRoundState()==1)
	{
		PrepareAbilities(); // late-load ? reload?
	}
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	PrepareAbilities();
}

public void PrepareAbilities()
{
	for(int client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			DSM_SpeedOverride[client]=false;
			NewSpeed[client]=0.0;
			NewSpeedDuration[client]=INACTIVE;
		}
	}
}

public void FF2AMS_PreRoundStart(int client)
{
	int boss=FF2_GetBossIndex(client);
	if(FF2_HasAbility(boss, this_plugin_name, MOVESPEED))
	{
		NewSpeed_TriggerAMS[client] = FF2AMS_PushToAMS(client, this_plugin_name, MOVESPEED, MOVESPEEDALIAS);
	}
}

public Action Event_WinPanel(Event event, const char[] name, bool dontBroadcast)
{
	for(int client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			DSM_SpeedOverride[client]=false;
			NewSpeed_TriggerAMS[client]=false; // Cleanup
			SDKUnhook(client, SDKHook_PreThink, MoveSpeed_Prethink);
			NewSpeed[client]=0.0;
			NewSpeedDuration[client]=INACTIVE;
		}
	}
}

public AMSResult MVS_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

void Rage_MoveSpeed(int client)
{
	if(NewSpeed_TriggerAMS[client]) // Prevent normal 100% RAGE activation if using AMS
	{
		if(!LibraryExists("FF2AMS")) // Fail state?
		{
			NewSpeed_TriggerAMS[client]=false;
		}
		else
		{
			return;
		}
	}
	MVS_Invoke(client, -1); // Activate RAGE normally, if ability is configured to be used as a normal RAGE.
}

public void MVS_Invoke(int client, int index)
{
	// 01Pollux: ?????? Dont convert String to float just to get a value!!! FF2_GetAbilityArgumentFloat already does that!
	int boss=FF2_GetBossIndex(client);
	if(!NewSpeed[client]) {
		NewSpeed[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, MOVESPEED, 1);
	}
	
	float nDuration = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, MOVESPEED, 2);
	
	if(NewSpeedDuration[client] != INACTIVE) {
		NewSpeedDuration[client] += nDuration;
	}
	NewSpeedDuration[client] = nDuration + (NewSpeedDuration[client] == INACTIVE ? GetGameTime():NewSpeedDuration[client]);
	
	if(NewSpeed_TriggerAMS[client])
	{
		static char snd[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_movespeed_start", snd, sizeof(snd), boss))
		{
			EmitSoundToAll(snd, client);
			EmitSoundToAll(snd, client);
		}		
	}
	
	if(!DSM_SpeedOverride[client]) {
		DSM_SpeedOverride[client] = FF2_HasAbility(boss, "ff2_dynamic_defaults", "dynamic_speed_management");
		if(DSM_SpeedOverride[client])
		{
			DSM_SetOverrideSpeed(client, NewSpeed[client]);
		}
		SDKHook(client, SDKHook_PreThink, MoveSpeed_Prethink);
	}
	
	float dist2=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, MOVESPEED, 3, -1.0);
	if(dist2)
	{
		if(dist2==-1)
		{
			dist2=FF2_GetRageDist(boss, this_plugin_name, MOVESPEED);
		}
		
		float speed = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, MOVESPEED, 4);
		nDuration = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, MOVESPEED, 5);
		
		static float pos[3], pos2[3], dist;
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
		for(int target=1;target<=MaxClients;target++)
		{
			if(!IsValidClient(target))
				continue;
		
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
			dist=GetVectorDistance( pos, pos2 );
			if (dist<dist2 && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam())
			{
				SDKHook(target, SDKHook_PreThink, MoveSpeed_Prethink);
				NewSpeed[target]=speed; // Victim Move Speed
				if(NewSpeedDuration[target]!=INACTIVE)
				{
					NewSpeedDuration[target]+=nDuration; // Add time if rage is active?
				}
				else
				{
					NewSpeedDuration[target]=GetGameTime()+nDuration; // Victim Move Speed Duration
				}
			}
		}
	}
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue; // Because some FF2 forks still allow RAGE to be activated when the round is over....
		
	int client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!strcmp(ability_name, MOVESPEED))
	{
		Rage_MoveSpeed(client);
	}
	return Plugin_Continue;
}

public void MoveSpeed_Prethink(int client)
{
	if(!DSM_SpeedOverride[client])
	{
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", NewSpeed[client]);
	}
	SpeedTick(client, GetGameTime());
}

public int SpeedTick(int client, float gameTime)
{
	// Move Speed
	if(gameTime>=NewSpeedDuration[client])
	{
		if(DSM_SpeedOverride[client])
		{
			DSM_SpeedOverride[client]=false;
			DSM_SetOverrideSpeed(client, -1.0);
		}
		
		int boss=FF2_GetBossIndex(client);
		if(boss>=0)
		{
			static char snd[PLATFORM_MAX_PATH];
			if(FF2_RandomSound("sound_movespeed_finish", snd, sizeof(snd), boss))
			{
				EmitSoundToAll(snd, client);
				EmitSoundToAll(snd, client);
			}
		}
	
		NewSpeed[client]=0.0;
		NewSpeedDuration[client]=INACTIVE;
		SDKUnhook(client, SDKHook_PreThink, MoveSpeed_Prethink);
	}
}

stock bool IsValidClient(int client, bool isPlayerAlive=false)
{
	if (client <= 0 || client > MaxClients)
		return false;
	if(!isPlayerAlive)
		return IsClientInGame(client);
	return IsClientInGame(client) && IsPlayerAlive(client);
}
