#define FF2_USING_AUTO_PLUGIN__OLD

#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

#define TAUNT "special_tauntonrage"
#define RAGEKILLINSTANTLY "rage_instakill_on_hit"
#define SAITAMA "one_punch_man"
bool Saitama = false;
bool RageActive = false;

#define DRAINHEALTH "rage_draining_health"
#define DRAINING_TICK			1.0
float draintimer;
float drainrange;
int drainamount;
int drainmode;
bool drainrageactivate;
float drainragetimer;

#define STUNONHIT_RAGE		"rage_stunonhit"
float stuntime_rage;
float stun_rage_timer;
bool stunrage_active;

#define STUNONHIT_ALLROUND	"special_stunonhit"
float stuntime_allround;
bool stunallaround_active;

public Plugin myinfo = {
	name	= "Freak Fortress 2: Scooty's Abilities",
	author	= "M7",
	version = "2.0",
};

public void OnPluginStart2()
{
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_Post);
	HookEvent("player_hurt", event_player_hurt);
	
	for(int i=1; i<=MaxClients; i++)
    {
        if(IsClientInGame(i))
        {
            SDKHook(i, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
        }
    }
}

public void Event_RoundStart(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
	
	for(int iBoss = 0; iBoss <= MaxClients; iBoss++)
	{
		if(!IsValidClient(iBoss))
			continue;
		
		Saitama = false;
		RageActive = false;
		drainrageactivate = false;
		stunallaround_active = false;
		stunrage_active = false;
		
		int client=FF2_GetBossIndex(iBoss);
		if(client>=0)
		{
			if(FF2_HasAbility(client, this_plugin_name, SAITAMA))
			{
				Saitama = true;
			}
			if(FF2_HasAbility(client, this_plugin_name, DRAINHEALTH))
			{
				draintimer = FF2_GetAbilityArgumentFloat(client, this_plugin_name, DRAINHEALTH, 1);
				drainrange = FF2_GetAbilityArgumentFloat(client, this_plugin_name, DRAINHEALTH, 2, FF2_GetRageDist(client, this_plugin_name, DRAINHEALTH));
				drainamount = FF2_GetAbilityArgument(client, this_plugin_name, DRAINHEALTH, 3);
				drainmode = FF2_GetAbilityArgument(client, this_plugin_name, DRAINHEALTH, 4);
			}
			if(FF2_HasAbility(client, this_plugin_name, STUNONHIT_ALLROUND))
			{
				stuntime_allround = FF2_GetAbilityArgumentFloat(client, this_plugin_name, STUNONHIT_ALLROUND, 1);
				stunallaround_active = true;
			}
		}
	}
}

public void Event_RoundEnd(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	Saitama = false;
	RageActive = false;
	drainrageactivate = false;
	stunallaround_active = false;
	stunrage_active = false;
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue;
		
	int client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if (!strcmp(ability_name,TAUNT))
	{
		if(!TF2_IsPlayerInCondition(client, TFCond_Taunting))
			FakeClientCommand(client, "taunt");
	}
	else if (!strcmp(ability_name,RAGEKILLINSTANTLY))
	{
		RageActive = true;
		CreateTimer(FF2_GetAbilityArgumentFloat(boss,this_plugin_name,ability_name,1,5.0), RageIsOver);
	}
	else if (!strcmp(ability_name,DRAINHEALTH))
	{
		if (!drainrageactivate)
		{
			CreateTimer(0.1, Timer_DrainHealth, GetClientSerial(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
		drainrageactivate = true;
		drainragetimer = GetEngineTime() + draintimer;
	}
	else if (!strcmp(ability_name,STUNONHIT_RAGE))
	{
		stunrage_active = true;
		stuntime_rage = FF2_GetAbilityArgumentFloat(client, this_plugin_name, STUNONHIT_RAGE, 1);
		stun_rage_timer = FF2_GetAbilityArgumentFloat(client, this_plugin_name, STUNONHIT_RAGE, 2);
		CreateTimer(stun_rage_timer, Stunisover);
	}
	return Plugin_Continue;
}
public Action Stunisover(Handle timer)
{
	stunrage_active = false;
}

public Action Timer_DrainHealth(Handle timer, int serial)
{
	int client = GetClientFromSerial(client);
	int boss=FF2_GetBossIndex(client);
	if (FF2_HasAbility(boss, this_plugin_name, DRAINHEALTH))
	{
		float bossPosition[3], targetPosition[3];
		float time = GetEngineTime();
		static float lastdamage;
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", bossPosition);
		
		if (drainragetimer > time)
		{
			if(lastdamage < time)																	// heal the boss
			{
				lastdamage = time + DRAINING_TICK;
				for(int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)!= FF2_GetBossTeam())
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", targetPosition);
						if(GetVectorDistance(bossPosition, targetPosition)<=drainrange)
						{
							if(drainmode == 0)
							{
								SDKHooks_TakeDamage(i, client, client, float(drainamount), DMG_SLASH);
							}
							if(drainmode == 1)
							{
								int maxHealth = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, i);
								maxHealth -= drainamount;
								SetEntityHealth(i, maxHealth);
							}
							if(drainmode == 2)
							{
								int health=GetClientHealth(i);
								SetEntityHealth(i, health-drainamount);
							}
						}
					}
				}
			}
		}
	}
	drainrageactivate = false;
	return Plugin_Stop;
}

public Action RageIsOver(Handle timer)
{
	RageActive = false;
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, 
					float damage, int damagetype, int weapon,
				const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if((Saitama || RageActive) && victim != attacker && IsValidClient(attacker) && GetClientTeam(attacker) == FF2_GetBossTeam())
	{
		FakeClientCommand(victim, "Explode");									// ff2's ontakedamage also hits here if we used ontakedamage....
	}
}

public void event_player_hurt(Event hEvent, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(hEvent.GetInt("userid"));
	int attacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	
	if(victim != attacker && IsValidClient(attacker) && stunallaround_active)
	{
		if(IsValidClient(victim) && hEvent.GetInt("health") > 0 && !TF2_IsPlayerInCondition(victim, TFCond_Dazed))
		{
			TF2_StunPlayer(victim, stuntime_allround, 0.0, TF_STUNFLAGS_GHOSTSCARE|TF_STUNFLAG_NOSOUNDOREFFECT);
		}
	}
	else if(victim != attacker && IsValidClient(attacker) && stunrage_active)
	{
		if(IsValidClient(victim) && hEvent.GetInt("health") > 0 && !TF2_IsPlayerInCondition(victim, TFCond_Dazed))
		{
			TF2_StunPlayer(victim, stuntime_rage, 0.0, TF_STUNFLAGS_GHOSTSCARE|TF_STUNFLAG_NOSOUNDOREFFECT);
		}
	}
}

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients)
		return false;
		
	return IsClientInGame(client);
}
