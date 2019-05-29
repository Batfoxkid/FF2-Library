#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <ff2_ams>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#define INACTIVE 100000000.0

#define REVIVE_BOSSES "rage_revive_bosses"
new bool:ReviveBosses_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS
#define HEAL_BOSSES "rage_heal_bosses"
new bool:HealBosses_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS
#define KINGS_POWERUP "rage_kings_powerup"
new bool:KingsPowerup_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS
#define LIFELOSE "lifelose_payday"
new Float:SpeedTemporarily[MAXPLAYERS+1];

public Plugin:myinfo = {
	name	= "Freak Fortress 2: PayDay Abilities",
	author	= "M7",
	version = "1.0",
};

public OnPluginStart2()
{
	HookEvent("arena_round_start", event_round_start, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", event_round_end, EventHookMode_PostNoCopy);
}

public Action:event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrepareAbilities();
}

public PrepareAbilities()
{
	for(new client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			ReviveBosses_TriggerAMS[client]=false;
			HealBosses_TriggerAMS[client]=false;
			KingsPowerup_TriggerAMS[client]=false;
			
			SpeedTemporarily[client]=0.0;
			
			new boss=FF2_GetBossIndex(client);
			if(boss>=0)
			{
				if(FF2_HasAbility(boss, this_plugin_name, REVIVE_BOSSES))
				{
					ReviveBosses_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, REVIVE_BOSSES);
					if(ReviveBosses_TriggerAMS[client])
					{
						AMS_InitSubability(boss, client, this_plugin_name, REVIVE_BOSSES, "REBO"); // Important function to tell AMS that this subplugin supports it
					}
				}
				if(FF2_HasAbility(boss, this_plugin_name, HEAL_BOSSES))
				{
					HealBosses_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, HEAL_BOSSES);
					if(HealBosses_TriggerAMS[client])
					{
						AMS_InitSubability(boss, client, this_plugin_name, HEAL_BOSSES, "HEBO"); // Important function to tell AMS that this subplugin supports it
					}
				}
				if(FF2_HasAbility(boss, this_plugin_name, KINGS_POWERUP))
				{
					KingsPowerup_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, KINGS_POWERUP);
					if(KingsPowerup_TriggerAMS[client])
					{
						AMS_InitSubability(boss, client, this_plugin_name, KINGS_POWERUP, "KIPO"); // Important function to tell AMS that this subplugin supports it
					}
				}
			}
		}
	}
}

public Action:event_round_end(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1;client<=MaxClients;client++)
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
	
public Action:FF2_OnAbility2(boss, const String:plugin_name[], const String:ability_name[], status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue; // Because some FF2 forks still allow RAGE to be activated when the round is over....
	
	new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!strcmp(ability_name,REVIVE_BOSSES))	// Defenses
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			ReviveBosses_TriggerAMS[client]=false;
		}
		
		if(!ReviveBosses_TriggerAMS[client])
			REBO_Invoke(client);
	}
	else if(!strcmp(ability_name,HEAL_BOSSES))	// Defenses
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			HealBosses_TriggerAMS[client]=false;
		}
		
		if(!HealBosses_TriggerAMS[client])
			HEBO_Invoke(client);
	}
	else if(!strcmp(ability_name,KINGS_POWERUP))	// Defenses
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			KingsPowerup_TriggerAMS[client]=false;
		}
		
		if(!KingsPowerup_TriggerAMS[client])
			KIPO_Invoke(client);
	}
	else if (!strcmp(ability_name, LIFELOSE))
	{
		decl String:Temporarily[10]; // Foolproof way so that args always return floats instead of ints
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

public Temporarily_Prethink(client)
{
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", SpeedTemporarily[client]);
}

public Action:Timer_ActivateLifelose(Handle:timer, any:boss)
{
	new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	TF2_AddCondition(client, TFCond_DefenseBuffed, FF2_GetAbilityArgumentFloat(boss, this_plugin_name, LIFELOSE, 4, 5.0));
	TF2_StunPlayer(client, FF2_GetAbilityArgumentFloat(boss, this_plugin_name, LIFELOSE, 5, 5.0), 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT, client);
	new flags=GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT);
	SetCommandFlags("r_screenoverlay", flags);
	ClientCommand(client, "r_screenoverlay \"%s\"", "debug/yuv");
	SDKUnhook(client, SDKHook_PreThink, Temporarily_Prethink);
	return Plugin_Continue;
}

public Action:Timer_StopUber(Handle:timer, any:boss)
{
	SetEntProp(GetClientOfUserId(FF2_GetBossUserId(boss)), Prop_Data, "m_takedamage", 2);
	return Plugin_Continue;
}


public bool REBO_CanInvoke(int client)
{
	if(!(GetEntityFlags(client) & FL_ONGROUND))
		return false;
		
	return DeadCompanions(client) ? true : false;
}

public void REBO_Invoke(int client)
{
	int boss=FF2_GetBossIndex(client);
	
	if(ReviveBosses_TriggerAMS[client])
	{
		new String:sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_revive_bosses", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);
		}
	}
	
	new quantity=FF2_GetAbilityArgument(boss, this_plugin_name, REVIVE_BOSSES, 1);
	new Float:revivedhealth=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, REVIVE_BOSSES, 2);

	new revivedboss;
	for(new target=0; target<=quantity; target++)
	{
		revivedboss = GetRandomDeadBoss();
		new bossIndex=FF2_GetBossIndex(revivedboss);
		if(revivedboss!=-1 && bossIndex!=-1)
		{
			FF2_SetFF2flags(revivedboss,FF2_GetFF2flags(revivedboss)|FF2FLAG_ALLOWSPAWNINBOSSTEAM);
			ChangeClientTeam(revivedboss,FF2_GetBossTeam());
			TF2_RespawnPlayer(revivedboss);
			
			new health;
			new maxhealth = FF2_GetBossMaxHealth(bossIndex);

			health = RoundToCeil(maxhealth * revivedhealth);
				
			FF2_SetBossHealth(bossIndex, health);
		}
	}
}


public bool HEBO_CanInvoke(int client)
{
	return true;
}

public void HEBO_Invoke(int client)
{
	int boss=FF2_GetBossIndex(client);
	new Float:pos[3], Float:pos2[3], Float:dist;
	new Float:distance=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, HEAL_BOSSES, 1);
	new Float:healing=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, HEAL_BOSSES, 2);
	new bool:selfheal=bool:FF2_GetAbilityArgument(boss, this_plugin_name, HEAL_BOSSES, 3);
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	
	if(HealBosses_TriggerAMS[client])
	{
		new String:sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_healing_bosses", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);
		}
	}
	
	if(selfheal)
	{
		new Selfhealth = FF2_GetBossHealth(boss);
		new Selfmaxhealth = FF2_GetBossMaxHealth(boss);
				
		Selfhealth = RoundToCeil(Selfhealth + (Selfmaxhealth * healing));
		if(Selfhealth > Selfmaxhealth)
		{
			Selfhealth = Selfmaxhealth;
		}
				
		FF2_SetBossHealth(boss, Selfhealth);
	}
	
	for(new companion=1; companion<=MaxClients; companion++)
	{
		if(IsValidClient(companion) && GetClientTeam(companion) == FF2_GetBossTeam())
		{
			int companionIndex=FF2_GetBossIndex(companion);
			GetEntPropVector(companion, Prop_Send, "m_vecOrigin", pos2);
			dist=GetVectorDistance(pos,pos2);
			if(dist<distance && companionIndex>=0)
			{
				new health = FF2_GetBossHealth(companionIndex);
				new maxhealth = FF2_GetBossMaxHealth(companionIndex);
				
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


public bool KIPO_CanInvoke(int client)
{
	return true;
}

public void KIPO_Invoke(int client)
{
	int boss=FF2_GetBossIndex(client);
	new Float:pos[3], Float:pos2[3], Float:dist;
	new Float:distance=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, KINGS_POWERUP, 1);
	new Float:duration=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, KINGS_POWERUP, 2);
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	
	if(KingsPowerup_TriggerAMS[client])
	{
		new String:sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_kingspowerup", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);
		}
	}
	
	TF2_AddCondition(client, TFCond_KingRune, duration);
	
	for(new companion=1; companion<=MaxClients; companion++)
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
		if(IsValidEdict(i) && IsValidClient(i) && !IsPlayerAlive(i) && FF2_GetBossIndex(i)>=0 && (GetClientTeam(i) > 1))
		{
			clients[clientCount++] = i;
		}
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

stock bool:IsBoss(client)
{
	if(FF2_GetBossIndex(client)==-1) return false;
	if(GetClientTeam(client)!=FF2_GetBossTeam()) return false;
	return true;
}

stock bool:IsValidClient(client, bool:isPlayerAlive=false)
{
	if (client <= 0 || client > MaxClients) return false;
	if(isPlayerAlive) return IsClientInGame(client) && IsPlayerAlive(client);
	return IsClientInGame(client);
}