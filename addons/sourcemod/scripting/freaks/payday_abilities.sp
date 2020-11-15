#define FF2_USING_AUTO_PLUGIN__OLD

#include <sdkhooks>
#include <tf2_stocks>
#include <ff2_ams2>
#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

#define INACTIVE 100000000.0

#define REVIVE_BOSSES "rage_revive_bosses"
bool ReviveBosses_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS
#define HEAL_BOSSES "rage_heal_bosses"
bool HealBosses_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS
#define KINGS_POWERUP "rage_kings_powerup"
bool KingsPowerup_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS
#define LIFELOSE "lifelose_payday"
float SpeedTemporarily[MAXPLAYERS+1];

public Plugin myinfo = {
	name	= "Freak Fortress 2: PayDay Abilities",
	author	= "M7",
	version = "1.0",
};

public void OnPluginStart2()
{
	HookEvent("arena_win_panel", event_round_end, EventHookMode_PostNoCopy);
}

public Action event_round_end(Event event, const char[] name, bool dontBroadcast)
{
	for(int client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			ReviveBosses_TriggerAMS[client]=false;
			HealBosses_TriggerAMS[client]=false;
			KingsPowerup_TriggerAMS[client]=false;
			
			SpeedTemporarily[client]=0.0;
		}
	}
}

public void FF2AMS_PreRoundStart(int client)
{
	int boss = FF2_GetBossIndex(client);
	if(FF2_HasAbility(boss, this_plugin_name, REVIVE_BOSSES)) {
		ReviveBosses_TriggerAMS[client] = AMS_REG(client)(rage_revive_bosses.REBO);
	}
	if(FF2_HasAbility(boss, this_plugin_name, HEAL_BOSSES)) {
		ReviveBosses_TriggerAMS[client] = AMS_REG(client)(rage_heal_bosses.HEBO);
	}
	if(FF2_HasAbility(boss, this_plugin_name, KINGS_POWERUP)) {
		ReviveBosses_TriggerAMS[client] = AMS_REG(client)(rage_kings_powerup.KIPO);
	}
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue; // Because some FF2 forks still allow RAGE to be activated when the round is over....
	
	int client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!strcmp(ability_name,REVIVE_BOSSES))	// Defenses
	{
		if(!LibraryExists("FF2AMS")) // Fail state?
		{
			ReviveBosses_TriggerAMS[client]=false;
		}
		
		if(!ReviveBosses_TriggerAMS[client])
			REBO_Invoke(client, -1);
	}
	else if(!strcmp(ability_name,HEAL_BOSSES))	// Defenses
	{
		if(!LibraryExists("FF2AMS")) // Fail state?
		{
			HealBosses_TriggerAMS[client]=false;
		}
		
		if(!HealBosses_TriggerAMS[client])
			HEBO_Invoke(client, -1);
	}
	else if(!strcmp(ability_name,KINGS_POWERUP))	// Defenses
	{
		if(!LibraryExists("FF2AMS")) // Fail state?
		{
			KingsPowerup_TriggerAMS[client]=false;
		}
		
		if(!KingsPowerup_TriggerAMS[client])
			KIPO_Invoke(client, -1);
	}
	else if (!strcmp(ability_name, LIFELOSE))
	{
		char Temporarily[10]; // Foolproof way so that args always return floats instead of ints
		FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 1, Temporarily, sizeof(Temporarily));
		
		SpeedTemporarily[client]=StringToFloat(Temporarily); // Boss Move Speed
		CreateTimer(FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 2, 8.0), Timer_ActivateLifelose, boss);
		SDKHook(client, SDKHook_PreThink, Temporarily_Prethink);
		
		TF2_AddCondition(client, TFCond_Ubercharged, FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 3, 5.0));
		SetEntProp(client, Prop_Data, "m_takedamage", 0);
		CreateTimer(FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 3, 5.0), Timer_StopUber, boss);
	}
	
	return Plugin_Continue;
}

public void Temporarily_Prethink(int client)
{
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", SpeedTemporarily[client]);
}

public Action Timer_ActivateLifelose(Handle timer, any boss)
{
	int client=GetClientOfUserId(FF2_GetBossUserId(boss));
	TF2_AddCondition(client, TFCond_DefenseBuffed, FF2_GetAbilityArgumentFloat(boss, this_plugin_name, LIFELOSE, 4, 5.0));
	TF2_StunPlayer(client, FF2_GetAbilityArgumentFloat(boss, this_plugin_name, LIFELOSE, 5, 5.0), 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT, client);
	int flags=GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT);
	SetCommandFlags("r_screenoverlay", flags);
	ClientCommand(client, "r_screenoverlay \"%s\"", "debug/yuv");
	SDKUnhook(client, SDKHook_PreThink, Temporarily_Prethink);
	return Plugin_Continue;
}

public Action Timer_StopUber(Handle timer, any boss)
{
	SetEntProp(GetClientOfUserId(FF2_GetBossUserId(boss)), Prop_Data, "m_takedamage", 2);
	return Plugin_Continue;
}


public AMSResult REBO_CanInvoke(int client, int index)
{
	if(!(GetEntityFlags(client) & FL_ONGROUND))
		return AMS_Deny;
		
	return DeadCompanions(client) ? AMS_Accept : AMS_Deny;
}

public void REBO_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	
	if(ReviveBosses_TriggerAMS[client])
	{
		char sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_revive_bosses", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);
		}
	}
	
	int quantity=FF2_GetAbilityArgument(boss, this_plugin_name, REVIVE_BOSSES, 1);
	float revivedhealth=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, REVIVE_BOSSES, 2);

	int revivedboss;
	for(int target=0; target<=quantity; target++)
	{
		revivedboss = GetRandomDeadBoss();
		int bossIndex=FF2_GetBossIndex(revivedboss);
		if(revivedboss!=-1 && bossIndex!=-1)
		{
			FF2Player player = FF2Player(revivedboss);
			player.SetPropAny("bIsMinion", true);
			player.ForceTeamChange(VSH2Team_Boss);
			
			int health;
			int maxhealth = FF2_GetBossMaxHealth(bossIndex);

			health = RoundToCeil(maxhealth * revivedhealth);
				
			FF2_SetBossHealth(bossIndex, health);
		}
	}
}

public void HEBO_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	float pos[3], pos2[3], dist;
	float distance=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, HEAL_BOSSES, 1);
	float healing=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, HEAL_BOSSES, 2);
	bool selfheal=FF2_GetAbilityArgument(boss, this_plugin_name, HEAL_BOSSES, 3) != 0;
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	
	if(HealBosses_TriggerAMS[client])
	{
		char sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_healing_bosses", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);
		}
	}
	
	if(selfheal)
	{
		int Selfhealth = FF2_GetBossHealth(boss);
		int Selfmaxhealth = FF2_GetBossMaxHealth(boss);
				
		Selfhealth = RoundToCeil(Selfhealth + (Selfmaxhealth * healing));
		if(Selfhealth > Selfmaxhealth)
		{
			Selfhealth = Selfmaxhealth;
		}
				
		FF2_SetBossHealth(boss, Selfhealth);
	}
	
	for(int companion=1; companion<=MaxClients; companion++)
	{
		if(IsValidClient(companion) && GetClientTeam(companion) == FF2_GetBossTeam())
		{
			int companionIndex=FF2_GetBossIndex(companion);
			GetEntPropVector(companion, Prop_Send, "m_vecOrigin", pos2);
			dist=GetVectorDistance(pos,pos2);
			if(dist<distance && companionIndex>=0)
			{
				int health = FF2_GetBossHealth(companionIndex);
				int maxhealth = FF2_GetBossMaxHealth(companionIndex);
				
				health = RoundToCeil(health + (maxhealth * healing));
				if(health > maxhealth)
				{
					health = maxhealth;
				}
				
				FF2_SetBossHealth(companionIndex, health);
			}
		}
	}
}

public void KIPO_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	float pos[3], pos2[3], dist;
	float distance=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, KINGS_POWERUP, 1);
	float duration=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, KINGS_POWERUP, 2);
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	
	if(KingsPowerup_TriggerAMS[client])
	{
		char sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_kingspowerup", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);
		}
	}
	
	TF2_AddCondition(client, TFCond_KingRune, duration);
	
	for(int companion=1; companion<=MaxClients; companion++)
	{
		if(IsValidClient(companion) && GetClientTeam(companion) == FF2_GetBossTeam())
		{
			int companionIndex=FF2_GetBossIndex(companion);
			GetEntPropVector(companion, Prop_Send, "m_vecOrigin", pos2);
			dist=GetVectorDistance(pos,pos2);
			if(dist<distance && companionIndex>=0)
			{
				TF2_AddCondition(companionIndex, TFCond_KingAura, duration);
			}
		}
	}
}

stock bool DeadCompanions(int clientIdx)
{
	int dead;
	for(int playing=1;playing<=MaxClients;playing++)
	{
		if(!IsValidClient(playing))
			continue;
		if(FF2_GetBossIndex(playing)>=0 && !IsPlayerAlive(playing) && playing!=clientIdx)
		{
			dead++;
		}
	}
	return !dead ? false : true;
}

stock int GetRandomDeadBoss()
{
	int[] clients = new int[MaxClients+1];
	int clientCount;
	for(int i=1;i<=MaxClients;i++)
	{
		if(IsValidEntity(i) && IsValidClient(i) && !IsPlayerAlive(i) && FF2_GetBossIndex(i)>=0 && (GetClientTeam(i) > 1))
		{
			clients[clientCount++] = i;
		}
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

stock bool IsBoss(int client)
{
	if(FF2_GetBossIndex(client)==-1) return false;
	if(GetClientTeam(client)!=FF2_GetBossTeam()) return false;
	return true;
}

stock bool IsValidClient(int client, bool isPlayerAlive=false)
{
	if (client <= 0 || client > MaxClients) return false;
	if(isPlayerAlive) return IsClientInGame(client) && IsPlayerAlive(client);
	return IsClientInGame(client);
}
