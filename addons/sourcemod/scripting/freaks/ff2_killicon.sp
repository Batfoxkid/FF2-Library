/*
	This is the source code of Freak Fortress 2: Kill Icon Changer
	Version: 0.3
	Description: Changes the kill icon of the bosses. Created especially for Freak Fortress 2,
	because VS Saxton Hale changes the icon of the Saxton Hale from shovel to fists, but FF2 doesn't.
	Developer(s):
	Naydef
	
*/

#include <tf2>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin> 

#pragma semicolon 1
#pragma newdecls required

//Defines
#define PLUGIN_VERSION "0.4"
#define WSLOTS 6
#define Ability "ff2_changekillicon"


public Plugin myinfo =
{
	name = "Freak Fortress 2: Kill Icon Changer", 
	author = "Naydef",
	description = "Subplugin, which change the kill icon of the boss",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(!IsTF2())
	{
		strcopy(error, err_max, "This plugin is only for Team Fortress 2. Remove the plugin!");
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public void OnPluginStart2()
{
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("object_destroyed", Event_ObjectDestroy, EventHookMode_Pre);
	//LogMessage("Freak Fortress 2: Kill Icon Modifier subplugin started successfully!");
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int action)
{
	return Plugin_Continue; // Not used.
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if(!FF2_IsFF2Enabled())
	{
		return Plugin_Continue;
	}
	int killer=GetClientOfUserId(GetEventInt(event, "attacker"));
	if(!IsValidClient(killer))
	{
		return Plugin_Continue;
	}
	int boss=FF2_GetBossIndex(killer);
	if(GetClientOfUserId(FF2_GetBossUserId(boss))!=killer)
	{
		return Plugin_Continue;
	}
	if(!FF2_HasAbility(boss, this_plugin_name, Ability))
	{
		return Plugin_Continue;
	}
	char mode[3];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, Ability, 1, mode, sizeof(mode));
	switch(StringToInt(mode))
	{
	case 0: //0. Set kill icon by item index of the weapon, used for the kill.
		{
			char buffer[8];
			FF2_GetAbilityArgumentString(boss, this_plugin_name, Ability, 2, buffer, sizeof(buffer));
			int itemindex1=StringToInt(buffer);
			int itemidex2=event.GetInt("weapon_def_index");
			if(itemindex1==itemidex2)
			{
				char killicon[32];
				FF2_GetAbilityArgumentString(boss, this_plugin_name, Ability, 3, killicon, sizeof(killicon));
				event.SetString("weapon", killicon);
			}
		}
	case 1: //1. Set kill icon by specified weapon slot
		{
			char buffer[10];
			FF2_GetAbilityArgumentString(boss, this_plugin_name, Ability, 2, buffer, sizeof(buffer));
			int slot=StringToInt(buffer);
			int killitemindex=GetEventInt(event, "weapon_def_index");
			for(int i=0; i<=WSLOTS; i++)
			{
				int weapon=GetPlayerWeaponSlot(killer, i);
				if(IsValidEntity(weapon))
				{
					if(slot==i)
					{
						int itemindex=GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
						if(itemindex==killitemindex)
						{
							char killicon[32];
							FF2_GetAbilityArgumentString(boss, this_plugin_name, Ability, 3, killicon, sizeof(killicon));
							event.SetString("weapon", killicon);
							break; // Only the first weapon, matching all criteria
						}
					}
				}
			}
		}
	case 2:    //2. Set kill icon by another weapon icon (name)
		{
			char wepname1[32];
			char wepname2[32];
			FF2_GetAbilityArgumentString(boss, this_plugin_name, Ability, 2, wepname1, sizeof(wepname1));
			GetEventString(event, "weapon", wepname2, sizeof(wepname2));
			if(StrEqual(wepname1, wepname2, false))
			{
				char killicon[32];
				FF2_GetAbilityArgumentString(boss, this_plugin_name, Ability, 3, killicon, sizeof(killicon));
				event.SetString("weapon", killicon);
			}
		}
	case 3:    //3. Always use this kill icon
		{
			char killicon[32];
			FF2_GetAbilityArgumentString(boss, this_plugin_name, Ability, 2, killicon, sizeof(killicon));
			event.SetString("weapon", killicon);
		}
	case 4:   //4. No kill icon at all
		{
			return Plugin_Handled;
		}
	default:
		{
			FF2Dbg("Error: The first ability argument is invalid. Mode: %i", StringToInt(mode[0]));
			LogError("[FF2 Subplugin] Error: The first ability argument is invalid. Mode: %i", StringToInt(mode[0]));
		}
	}
	return Plugin_Continue;
}

public Action Event_ObjectDestroy(Event event, const char[] name, bool dontBroadcast)
{
	if(!FF2_IsFF2Enabled())
	{
		return Plugin_Continue;
	}
	int killer=GetClientOfUserId(event.GetInt("attacker"));
	if(!IsValidClient(killer))
	{
		return Plugin_Continue;
	}
	int boss=FF2_GetBossIndex(killer);
	if(GetClientOfUserId(FF2_GetBossUserId(boss))!=killer)
	{
		return Plugin_Continue;
	}
	if(!FF2_HasAbility(boss, this_plugin_name, Ability))
	{
		return Plugin_Continue;
	}
	char mode[3];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, Ability, 1, mode, sizeof(mode));
	switch(StringToInt(mode))
	{
	case 2:    //2. Set kill icon by another weapon icon (name)
		{
			char wepname1[32];
			char wepname2[32];
			FF2_GetAbilityArgumentString(boss, this_plugin_name, Ability, 2, wepname1, sizeof(wepname1));
			event.GetString("weapon", wepname2, sizeof(wepname2));
			if(StrEqual(wepname1, wepname2, false))
			{
				char killicon[32];
				FF2_GetAbilityArgumentString(boss, this_plugin_name, Ability, 3, killicon, sizeof(killicon));
				event.SetString("weapon", killicon);
			}
		}
	case 3:    //3. Always use this kill icon
		{
			char killicon[32];
			FF2_GetAbilityArgumentString(boss, this_plugin_name, Ability, 2, killicon, sizeof(killicon));
			event.SetString("weapon", killicon);
		}
	case 4:   //4. No kill icon at all
		{
			return Plugin_Handled;
		}
	case 0, 1:
		{
			return Plugin_Continue;
		}
	default:
		{
			FF2Dbg("Error: The first ability argument is invalid. Mode: %i", StringToInt(mode[0]));
			LogError("[FF2 Subplugin] Error: The first ability argument is invalid. Mode: %i", StringToInt(mode[0]));
		}
	}
	return Plugin_Continue;
}


/*                                  Stocks                                              */          
bool IsValidClient(int client, bool replaycheck=true)//From Freak Fortress 2
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

bool IsTF2()
{
	return (GetEngineVersion()==Engine_TF2) ?  true : false;
}
