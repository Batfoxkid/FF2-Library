/*

	// Ability
	"abilityX"
	{
		"name" "blockdropitem"
		"arg1" "You were kicked because no one likes exploiters..."
		"plugin_name"    "ff2_blockdropitem"
	}
*/
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <tf2_stocks>

#pragma newdecls required

#define PLUGIN_NAME     "Freak Fortress 2: Block Item/PowerUp dropping"
#define PLUGIN_AUTHOR   "Naydef"
#define PLUGIN_VERSION  "1.1"
#define ABILITY_NAME "blockdropitem"
#define POWERUP         "item_powerup_rune"

float OFF_THE_MAP[3] = {16383.0, 16383.0, -16383.0};

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	version = PLUGIN_VERSION,
};

public void OnPluginStart2()
{
	AddCommandListener(Command_DropItem, "dropitem");
}

public Action Command_DropItem(int client, const char[] command, int argc)
{
	if(IsValidClient(client))
	{
		int bossidx=FF2_GetBossIndex(client);
		if(bossidx!=-1)
		{
			if(FF2_HasAbility(bossidx, this_plugin_name, ABILITY_NAME))
			{
				char str[64];
				FF2_GetAbilityArgumentString(bossidx, this_plugin_name, ABILITY_NAME, 1, str, sizeof(str));
				if(str[0]!='\0')
				{
					KickClient(client, str);
				}
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, POWERUP))
		return;

	for(int bossidx; bossidx<=MaxClients; bossidx++)
	{
		if(!IsValidClient(GetClientOfUserId(FF2_GetBossUserId(bossidx))))
			continue;

		if(!FF2_HasAbility(bossidx, this_plugin_name, ABILITY_NAME))
			continue;

		SDKHook(entity, SDKHook_Spawn, KillOnSpawn);
		break;
	}
}

public void KillOnSpawn(int entity)
{
	if(IsValidEdict(entity) && entity>MaxClients)
	{
		TeleportEntity(entity, OFF_THE_MAP, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "Kill");
	}
}

public void FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	//Nope
}


stock bool IsValidClient(int client)
{
	if(client<=0 || client>MaxClients) return false;
	return IsClientInGame(client);
}
