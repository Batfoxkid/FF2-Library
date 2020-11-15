#define FF2_USING_AUTO_PLUGIN__OLD

#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

bool Saitama = false;

public Plugin myinfo = {
	name	= "One Punch Man",
	author	= "M7",
	version = "1.0",
};

public void OnPluginStart2()
{
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_Post);
	
	for(int i=1; i<=MaxClients; i++)
    {
        if(IsClientInGame(i))
        {
            SDKHook(i, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
        }
    }
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public void Event_RoundStart(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
	
	for(int iBoss = 0; iBoss <= MaxClients; iBoss++)
	{
		if(FF2_HasAbility(iBoss, this_plugin_name, "One_Punch_Man"))
		{
			Saitama = true;
		}
	}
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, 
					float damage, int damagetype, int weapon,
				const float damageForce[3], const float damagePosition[3], int damagecustom)
{
    if(Saitama && victim != attacker && attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && GetClientTeam(attacker) == FF2_GetBossTeam())
    {
        FakeClientCommand(victim, "Explode");									// ff2's ontakedamage also hits here if we used ontakedamage....
    }
}

public void Event_RoundEnd(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	Saitama = false;
}

public void FF2_OnAbility2(int iBoss, const char[] pluginName, const char[] abilityName, int iStatus){}

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients)
		return false;
		
	return IsClientInGame(client);
}
