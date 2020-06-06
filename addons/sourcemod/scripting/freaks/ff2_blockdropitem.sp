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

#include <sdkhooks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma newdecls required

#define PLUGIN_NAME     "Freak Fortress 2: Block Item/PowerUp dropping"
#define PLUGIN_AUTHOR   "Naydef"
#define PLUGIN_VERSION  "1.1"
#define ABILITY_NAME "blockdropitem"
#define POWERUP         "item_powerup_rune"

bool BossExists;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	version = PLUGIN_VERSION,
};

public void OnPluginStart2()
{
	HookEvent("arena_round_start", Post_RoundStart);
	HookEvent("arena_win_panel", Post_RoundEnd);
	AddCommandListener(Command_DropItem, "dropitem");
}

public void Post_RoundEnd(Event event, const char[] name, bool broadcast)
{
	BossExists = false;
}

public void Post_RoundStart(Event event, const char[] name, bool broadcast)
{
	for(int bossidx; bossidx<=MaxClients; bossidx++)
	{
		if(!IsValidClient(GetClientOfUserId(FF2_GetBossUserId(bossidx))))
			continue;

		if(!FF2_HasAbility(bossidx, this_plugin_name, ABILITY_NAME))
			continue;
		
		BossExists = true;
		break;
	}
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
	if(!BossExists)
		return;
	
	if(!strcmp(classname, POWERUP))
		SDKHook(entity, SDKHook_Spawn, KillOnSpawn);
}

public void KillOnSpawn(int entity)
{
	if(IsValidEntity(entity) && entity>MaxClients)
		RemoveEntity(entity);
	SDKUnhook(entity, SDKHook_Spawn, KillOnSpawn);
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
