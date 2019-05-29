#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <tf2attributes>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

new bool:Saitama = false;

public Plugin:myinfo = {
	name	= "One Punch Man",
	author	= "M7",
	version = "1.0",
};

public OnPluginStart2()
{
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_Post);
	
	for(new i=1; i<=MaxClients; i++)
    {
        if(IsClientInGame(i))
        {
            SDKHook(i, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
        }
    }
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public void Event_RoundStart(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
	
	for(new iBoss = 0; iBoss <= MaxClients; iBoss++)
	{
		if(FF2_HasAbility(iBoss, this_plugin_name, "One_Punch_Man"))
		{
			Saitama = true;
		}
	}
}

public OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype)
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

stock bool:IsValidClient(client)
{
	if (client <= 0 || client > MaxClients)
		return false;
		
	return IsClientInGame(client);
}