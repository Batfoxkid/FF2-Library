#define FF2_USING_AUTO_PLUGIN__OLD

#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

#define BARON_LIFE			"freak_fortress_2/blackbaron/socoldfix.mp3"		// life lost, will be stopped when round ends
int g_baron_life;
int baron_boss;

#define BARON "instrumental_to_vocal"
#define INACTIVE 100000000.0

public Plugin myinfo = {
	name	= "Change Theme on Lifelose",
	author	= "M7",
	version = "1.0",
};

public void OnPluginStart2()
{
	HookEvent("teamplay_round_start", event_round_start, EventHookMode_PostNoCopy);
	
	HookEvent("teamplay_round_active", event_round_active, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", event_round_active, EventHookMode_PostNoCopy);
	
	HookEvent("teamplay_round_win", event_round_end, EventHookMode_PostNoCopy);
	
	PrecacheSound(BARON_LIFE);
}

public void event_round_start(Event event, const char[] name, bool dontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
	
	g_baron_life = 0;
	baron_boss = 0;
}

public void event_round_active(Event event, const char[] name, bool dontBroadcast)
{
	GetBossVars();
}

void GetBossVars()
{
	if (FF2_HasAbility(0, this_plugin_name, BARON))
	{
		int userid = FF2_GetBossUserId(0);
		int client = GetClientOfUserId(userid);
		if (client && IsClientInGame(client) && IsPlayerAlive(client))
		{
			baron_boss = client;
			return;
		}
	}
	
	baron_boss = 0;
}

public void event_round_end(Event event, const char[] name, bool dontBroadcast)
{
	for(int client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			g_baron_life = 0;
			baron_boss = 0;
			StopSound(client, SNDCHAN_AUTO, BARON_LIFE);
		}
	}
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	return Plugin_Continue;
}

public Action FF2_OnLoseLife(int index, int& lives, int maxLives)
{		
	if (!g_baron_life && baron_boss && GetClientOfUserId(FF2_GetBossUserId(index)) == baron_boss && IsPlayerAlive(baron_boss))
	{		
		FF2_StopMusic(0);
		
		EmitSoundToAll(BARON_LIFE);
		
		g_baron_life++;
	}
	return Plugin_Continue;
}

public Action FF2_OnMusic(char[] path, float& time)
{
	if (g_baron_life)
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

stock bool IsValidClient(int client, bool isPlayerAlive=false)
{
	if (client <= 0 || client > MaxClients) return false;
	if(isPlayerAlive) return IsClientInGame(client) && IsPlayerAlive(client);
	return IsClientInGame(client);
}
