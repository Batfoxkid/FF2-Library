/*
	This is the source code of Freak Fortress 2: Pause Ability
	Version: 0.4
	Description: Pause the entire server. 
	To-do:
	1) Remove "PAUSED" overlay
	2) Fix prediction for the weapons
	3) Clean up the plugin

*/
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

//Defines
#define PLUGIN_VERSION "0.5.1"
#define ABILITY "ff2_pause"

//Declarations
ConVar pauseCVar;
bool paused;
bool IsProxy[MAXPLAYERS+1];
Handle rageTM[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "Freak Fortress 2: Pause Ability", 
	author = "Naydef",
	description = "Subplugin, which can pause the whole server!",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/forumdisplay.php?f=154"
};

public void OnPluginStart2()
{
	pauseCVar = FindConVar("sv_pausable");
	if(!pauseCVar) {
		SetFailState("sv_pausable convar not found. Subplugin disabled!!!");
	}
	AddCommandListener(Listener_PauseCommand, "pause");
	AddCommandListener(Listener_PauseCommand, "unpause"); // For safety
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int action)
{
	if(StrEqual(ability_name, ABILITY, false))
	{
		int client=GetClientOfUserId(FF2_GetBossUserId(boss));
		float time=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ABILITY, 1, 0.0);
		PauseRage(client, time);
	}
	return Plugin_Continue;
}

public void PauseRage(int client, float time)
{
	if(IsValidClient(client))
	{
		for(int i=1; i<=MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				SetNextAttack(i, time);
			}
		}
		SilentCvarChange(pauseCVar, true);
		SetConVarBool(pauseCVar, true);
		pauseCVar.BoolValue = true;
		SilentCvarChange(pauseCVar, false);
		if(!paused)
		{
			IsProxy[client]=true;
			FakeClientCommand(client, "pause");
			IsProxy[client]=false;
		}
		paused=true;
		//CreateTimer(1.0, Timer_RemOverlay, _, TIMER_FLAG_NO_MAPCHANGE);
		DataPack packet;
		rageTM[client]=CreateDataTimer(time, Timer_UnPause, packet, TIMER_FLAG_NO_MAPCHANGE);
		packet.WriteCell(GetClientSerial(client));
	}
}

public void OnClientDisconnect(int client)
{
	if(rageTM[client]!=INVALID_HANDLE)
	{
		TriggerTimer(rageTM[client]);
		delete rageTM[client];
	}
	IsProxy[client]=false;
}

public Action Listener_PauseCommand(int client, const char[] command, int argc)
{
	if(!IsProxy[client])
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Timer_UnPause(Handle htimer, DataPack packet)
{
	packet.Reset();
	int client=GetClientFromSerial(packet.ReadCell());
	if(!IsValidClient(client))
	{
		return Plugin_Stop;
	}
	SilentCvarChange(pauseCVar, true);
	pauseCVar.BoolValue = false;
	SilentCvarChange(pauseCVar, false);
	IsProxy[client]=true;
	if(paused)
	{
		FakeClientCommand(client, "pause");
	}
	paused=false;
	IsProxy[client]=false;
	rageTM[client] = null;
	for(int i=1; i<=MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			SetNextAttack(i, 0.1);
		}
	}
	return Plugin_Continue;
}

/*
public Action:Timer_RemOverlay(Handle:htimer)
{
	for(int i=1; i<=MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			DoOverlay(i, "");
		}
	}
	return Plugin_Continue;
}
*/

/*                                   Stocks                                            */
bool IsValidClient(int client, bool replaycheck=true) //From Freak Fortress 2
{
	if(client<=0 || client>MaxClients)
	{
		return false;
	}

	if(!IsClientInGame(client))
	{
		return false;
	}

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
	{
		return false;
	}

	if(replaycheck)
	{
		if(IsClientSourceTV(client) || IsClientReplay(client))
		{
			return false;
		}
	}
	return true;
}


void SilentCvarChange(const ConVar cvar, bool setsilent=true)
{
	int flags=GetConVarFlags(cvar);
	(setsilent) ? (flags^=FCVAR_NOTIFY) : (flags|=FCVAR_NOTIFY);
	SetConVarFlags(cvar, flags);
}

void SetNextAttack(int client, float time) // Fix prediction
{
	if(IsValidClient(client))
	{
		SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime()+time);
		for(int i=0; i<=2; i++)
		{
			int weapon=GetPlayerWeaponSlot(client, i);
			if(IsValidEntity(weapon))
			{
				SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime()+time);
			}
		}
	}
}

/*
DoOverlay(client, const String:overlay[]) //Copied from FF2
{
	PrintToChatAll("Removing overlay for %N", client);
	int flags=GetCommandFlags("r_screenoverlay");
	SetCommandFlags("r_screenoverlay", flags & ~FCVAR_CHEAT);
	ClientCommand(client, "r_screenoverlay \"%s\"", overlay);
	SetCommandFlags("r_screenoverlay", flags);
}
*/
