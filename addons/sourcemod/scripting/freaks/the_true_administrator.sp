#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <ff2_ams>
#include <ff2_dynamic_defaults>
#include <tf2attributes>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#define INACTIVE 100000000.0

#define SCOUT_SUMMONING "administrator_scout_summoning"
#define SOLDIER_SUMMONING "administrator_soldier_summoning"
#define PYRO_SUMMONING "administrator_pyro_summoning"
#define DEMOMAN_SUMMONING "administrator_demoman_summoning"
#define HEAVY_SUMMONING "administrator_heavy_summoning"
#define ENGINEER_SUMMONING "administrator_engineer_summoning"
#define MEDIC_SUMMONING "administrator_medic_summoning"
#define SNIPER_SUMMONING "administrator_sniper_summoning"
#define SPY_SUMMONING "administrator_spy_summoning"
#define ULTIMATE_SUMMONING "administrator_ultimate_summoning"

enum VoiceMode
{
	VoiceMode_Normal,
	VoiceMode_Robot,
}

new SummonerIndex[MAXPLAYERS+1];
VoiceMode VOMode[MAXPLAYERS+1];

public Plugin:myinfo = {
	name	= "Freak Fortress 2: The Administrator",
	author	= "M7",
	version = "1.0",
};

public OnPluginStart2()
{
	HookEvent("arena_round_start", event_round_start, EventHookMode_PostNoCopy);
	HookEvent("player_death", event_player_death);
	
	AddNormalSoundHook(SoundHook);
}

public Action:event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
	
	for(new client=1;client<=MaxClients;client++)
	{
		if(!IsValidClient(client))
			continue;
		
		SummonerIndex[client]=-1;
		VOMode[client]=VoiceMode_Normal;
		
		new boss=FF2_GetBossIndex(client);
		if(boss>=0)
		{
			if(FF2_HasAbility(boss, this_plugin_name, SCOUT_SUMMONING))
			{
				AMS_InitSubability(boss, client, this_plugin_name, SCOUT_SUMMONING, "SUM1"); // Important function to tell AMS that this subplugin supports it
			}
			if(FF2_HasAbility(boss, this_plugin_name, SOLDIER_SUMMONING))
			{
				AMS_InitSubability(boss, client, this_plugin_name, SOLDIER_SUMMONING, "SUM2"); // Important function to tell AMS that this subplugin supports it
			}
			if(FF2_HasAbility(boss, this_plugin_name, PYRO_SUMMONING))
			{
				AMS_InitSubability(boss, client, this_plugin_name, PYRO_SUMMONING, "SUM3"); // Important function to tell AMS that this subplugin supports it
			}
			if(FF2_HasAbility(boss, this_plugin_name, DEMOMAN_SUMMONING))
			{
				AMS_InitSubability(boss, client, this_plugin_name, DEMOMAN_SUMMONING, "SUM4"); // Important function to tell AMS that this subplugin supports it
			}
			if(FF2_HasAbility(boss, this_plugin_name, HEAVY_SUMMONING))
			{
				AMS_InitSubability(boss, client, this_plugin_name, HEAVY_SUMMONING, "SUM5"); // Important function to tell AMS that this subplugin supports it
			}
			if(FF2_HasAbility(boss, this_plugin_name, ENGINEER_SUMMONING))
			{
				AMS_InitSubability(boss, client, this_plugin_name, ENGINEER_SUMMONING, "SUM6"); // Important function to tell AMS that this subplugin supports it
			}
			if(FF2_HasAbility(boss, this_plugin_name, MEDIC_SUMMONING))
			{
				AMS_InitSubability(boss, client, this_plugin_name, MEDIC_SUMMONING, "SUM7"); // Important function to tell AMS that this subplugin supports it
			}
			if(FF2_HasAbility(boss, this_plugin_name, SNIPER_SUMMONING))
			{
				AMS_InitSubability(boss, client, this_plugin_name, SNIPER_SUMMONING, "SUM8"); // Important function to tell AMS that this subplugin supports it
			}
			if(FF2_HasAbility(boss, this_plugin_name, SPY_SUMMONING))
			{
				AMS_InitSubability(boss, client, this_plugin_name, SPY_SUMMONING, "SUM9"); // Important function to tell AMS that this subplugin supports it
			}
			if(FF2_HasAbility(boss, this_plugin_name, ULTIMATE_SUMMONING))
			{
				AMS_InitSubability(boss, client, this_plugin_name, ULTIMATE_SUMMONING, "SU10"); // Important function to tell AMS that this subplugin supports it
			}
		}
	}
}

public Action:event_player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER)
	{
		return Plugin_Continue;
	}
	
	new client=GetClientOfUserId(GetEventInt(event, "userid"));

	new boss=FF2_GetBossIndex(client);	// Boss is the victim
	if(boss!=-1 && FF2_HasAbility(boss, this_plugin_name, ULTIMATE_SUMMONING) && !(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
	{
		for(new clone=1; clone<=MaxClients; clone++)
		{
			if(SummonerIndex[clone]==boss && IsValidClient(clone) && IsValidMinion(clone) && IsPlayerAlive(clone))
			{
				SummonerIndex[clone]=-1;
				VOMode[clone]=VoiceMode_Normal;
				ChangeClientTeam(clone, (FF2_GetBossTeam()==_:TFTeam_Blue) ? (_:TFTeam_Red) : (_:TFTeam_Blue));
			}
		}
	}
	
	return Plugin_Continue;
}


public Action:FF2_OnAbility2(boss, const String:plugin_name[], const String:ability_name[], status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue; // Because some FF2 forks still allow RAGE to be activated when the round is over....
	
	return Plugin_Continue;
}


public bool:SUM1_CanInvoke(client)
{
	return true;
}

public void SUM1_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:ScoutClassname[64], String:ScoutAttributes[256];
	
	new ScoutHealth = FF2_GetAbilityArgument(boss, this_plugin_name, SCOUT_SUMMONING, 1);
	new ScoutIndex = FF2_GetAbilityArgument(boss, this_plugin_name, SCOUT_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SCOUT_SUMMONING, 3, ScoutClassname, sizeof(ScoutClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SCOUT_SUMMONING, 4, ScoutAttributes, sizeof(ScoutAttributes));
	new TFClassType:ScoutClass = TFClassType:FF2_GetAbilityArgument(boss, this_plugin_name, SCOUT_SUMMONING, 5);
	new ScoutAmount = FF2_GetAbilityArgument(boss, this_plugin_name, SCOUT_SUMMONING, 6);
	new ScoutSpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, SCOUT_SUMMONING, 7);
	new ScoutAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, SCOUT_SUMMONING, 8, 0);
	new ScoutClip = FF2_GetAbilityArgument(boss, this_plugin_name, SCOUT_SUMMONING, 9, 0);
	new bool:ScoutRobot = bool:FF2_GetAbilityArgument(boss, this_plugin_name, SCOUT_SUMMONING, 10);
	
	new String:sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_scout", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, ScoutHealth, ScoutClassname, ScoutIndex, ScoutAttributes, ScoutClass, ScoutAmount, ScoutSpeciality, ScoutAmmo, ScoutClip, ScoutRobot);
}

public bool:SUM2_CanInvoke(client)
{
	return true;
}

public void SUM2_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:SoldierClassname[64], String:SoldierAttributes[256];
	
	new SoldierHealth = FF2_GetAbilityArgument(boss, this_plugin_name, SOLDIER_SUMMONING, 1);
	new SoldierIndex = FF2_GetAbilityArgument(boss, this_plugin_name, SOLDIER_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SOLDIER_SUMMONING, 3, SoldierClassname, sizeof(SoldierClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SOLDIER_SUMMONING, 4, SoldierAttributes, sizeof(SoldierAttributes));
	new TFClassType:SoldierClass = TFClassType:FF2_GetAbilityArgument(boss, this_plugin_name, SOLDIER_SUMMONING, 5);
	new SoldierAmount = FF2_GetAbilityArgument(boss, this_plugin_name, SOLDIER_SUMMONING, 6);
	new SoldierSpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, SOLDIER_SUMMONING, 7);
	new SoldierAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, SOLDIER_SUMMONING, 8, 0);
	new SoldierClip = FF2_GetAbilityArgument(boss, this_plugin_name, SOLDIER_SUMMONING, 9, 0);
	new bool:SoldierRobot = bool:FF2_GetAbilityArgument(boss, this_plugin_name, SOLDIER_SUMMONING, 10);
	
	new String:sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_soldier", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, SoldierHealth, SoldierClassname, SoldierIndex, SoldierAttributes, SoldierClass, SoldierAmount, SoldierSpeciality, SoldierAmmo, SoldierClip, SoldierRobot);
}

public bool:SUM3_CanInvoke(client)
{
	return true;
}

public void SUM3_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:PyroClassname[64], String:PyroAttributes[256];
	
	new PyroHealth = FF2_GetAbilityArgument(boss, this_plugin_name, PYRO_SUMMONING, 1);
	new PyroIndex = FF2_GetAbilityArgument(boss, this_plugin_name, PYRO_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, PYRO_SUMMONING, 3, PyroClassname, sizeof(PyroClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, PYRO_SUMMONING, 4, PyroAttributes, sizeof(PyroAttributes));
	new TFClassType:PyroClass = TFClassType:FF2_GetAbilityArgument(boss, this_plugin_name, PYRO_SUMMONING, 5);
	new PyroAmount = FF2_GetAbilityArgument(boss, this_plugin_name, PYRO_SUMMONING, 6);
	new PyroSpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, PYRO_SUMMONING, 7);
	new PyroAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, PYRO_SUMMONING, 8, 0);
	new PyroClip = FF2_GetAbilityArgument(boss, this_plugin_name, PYRO_SUMMONING, 9, 0);
	new bool:PyroRobot = bool:FF2_GetAbilityArgument(boss, this_plugin_name, PYRO_SUMMONING, 10);
	
	new String:sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_pyro", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, PyroHealth, PyroClassname, PyroIndex, PyroAttributes, PyroClass, PyroAmount, PyroSpeciality, PyroAmmo, PyroClip, PyroRobot);
}

public bool:SUM4_CanInvoke(client)
{
	return true;
}

public void SUM4_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:DemoClassname[64], String:DemoAttributes[256];
	
	new DemoHealth = FF2_GetAbilityArgument(boss, this_plugin_name, DEMOMAN_SUMMONING, 1);
	new DemoIndex = FF2_GetAbilityArgument(boss, this_plugin_name, DEMOMAN_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, DEMOMAN_SUMMONING, 3, DemoClassname, sizeof(DemoClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, DEMOMAN_SUMMONING, 4, DemoAttributes, sizeof(DemoAttributes));
	new TFClassType:DemoClass = TFClassType:FF2_GetAbilityArgument(boss, this_plugin_name, DEMOMAN_SUMMONING, 5);
	new DemoAmount = FF2_GetAbilityArgument(boss, this_plugin_name, DEMOMAN_SUMMONING, 6);
	new DemoSpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, DEMOMAN_SUMMONING, 7);
	new DemoAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, DEMOMAN_SUMMONING, 8, 0);
	new DemoClip = FF2_GetAbilityArgument(boss, this_plugin_name, DEMOMAN_SUMMONING, 9, 0);
	new bool:DemoRobot = bool:FF2_GetAbilityArgument(boss, this_plugin_name, DEMOMAN_SUMMONING, 10);
	
	new String:sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_demoman", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, DemoHealth, DemoClassname, DemoIndex, DemoAttributes, DemoClass, DemoAmount, DemoSpeciality, DemoAmmo, DemoClip, DemoRobot);
}

public bool:SUM5_CanInvoke(client)
{
	return true;
}

public void SUM5_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:HeavyClassname[64], String:HeavyAttributes[256];
	
	new HeavyHealth = FF2_GetAbilityArgument(boss, this_plugin_name, HEAVY_SUMMONING, 1);
	new HeavyIndex = FF2_GetAbilityArgument(boss, this_plugin_name, HEAVY_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, HEAVY_SUMMONING, 3, HeavyClassname, sizeof(HeavyClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, HEAVY_SUMMONING, 4, HeavyAttributes, sizeof(HeavyAttributes));
	new TFClassType:HeavyClass = TFClassType:FF2_GetAbilityArgument(boss, this_plugin_name, HEAVY_SUMMONING, 5);
	new HeavyAmount = FF2_GetAbilityArgument(boss, this_plugin_name, HEAVY_SUMMONING, 6);
	new HeavySpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, HEAVY_SUMMONING, 7);
	new HeavyAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, HEAVY_SUMMONING, 8, 0);
	new HeavyClip = FF2_GetAbilityArgument(boss, this_plugin_name, HEAVY_SUMMONING, 9, 0);
	new bool:HeavyRobot = bool:FF2_GetAbilityArgument(boss, this_plugin_name, HEAVY_SUMMONING, 10);
	
	new String:sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_heavy", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, HeavyHealth, HeavyClassname, HeavyIndex, HeavyAttributes, HeavyClass, HeavyAmount, HeavySpeciality, HeavyAmmo, HeavyClip, HeavyRobot);
}

public bool:SUM6_CanInvoke(client)
{
	return true;
}

public void SUM6_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:EngineerClassname[64], String:EngineerAttributes[256];
	
	new EngineerHealth = FF2_GetAbilityArgument(boss, this_plugin_name, ENGINEER_SUMMONING, 1);
	new EngineerIndex = FF2_GetAbilityArgument(boss, this_plugin_name, ENGINEER_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ENGINEER_SUMMONING, 3, EngineerClassname, sizeof(EngineerClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ENGINEER_SUMMONING, 4, EngineerAttributes, sizeof(EngineerAttributes));
	new TFClassType:EngineerClass = TFClassType:FF2_GetAbilityArgument(boss, this_plugin_name, ENGINEER_SUMMONING, 5);
	new EngineerAmount = FF2_GetAbilityArgument(boss, this_plugin_name, ENGINEER_SUMMONING, 6);
	new EngineerSpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, ENGINEER_SUMMONING, 7);
	new EngineerAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, ENGINEER_SUMMONING, 8, 0);
	new EngineerClip = FF2_GetAbilityArgument(boss, this_plugin_name, ENGINEER_SUMMONING, 9, 0);
	new bool:EngineerRobot = bool:FF2_GetAbilityArgument(boss, this_plugin_name, ENGINEER_SUMMONING, 10);
	
	new String:sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_engineer", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, EngineerHealth, EngineerClassname, EngineerIndex, EngineerAttributes, EngineerClass, EngineerAmount, EngineerSpeciality, EngineerAmmo, EngineerClip, EngineerRobot);
}

public bool:SUM7_CanInvoke(client)
{
	return true;
}

public void SUM7_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:MedicClassname[64], String:MedicAttributes[256];
	
	new MedicHealth = FF2_GetAbilityArgument(boss, this_plugin_name, MEDIC_SUMMONING, 1);
	new MedicIndex = FF2_GetAbilityArgument(boss, this_plugin_name, MEDIC_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, MEDIC_SUMMONING, 3, MedicClassname, sizeof(MedicClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, MEDIC_SUMMONING, 4, MedicAttributes, sizeof(MedicAttributes));
	new TFClassType:MedicClass = TFClassType:FF2_GetAbilityArgument(boss, this_plugin_name, MEDIC_SUMMONING, 5);
	new MedicAmount = FF2_GetAbilityArgument(boss, this_plugin_name, MEDIC_SUMMONING, 6);
	new MedicSpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, MEDIC_SUMMONING, 7);
	new MedicAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, MEDIC_SUMMONING, 8, 0);
	new MedicClip = FF2_GetAbilityArgument(boss, this_plugin_name, MEDIC_SUMMONING, 9, 0);
	new bool:MedicRobot = bool:FF2_GetAbilityArgument(boss, this_plugin_name, MEDIC_SUMMONING, 10);
	
	new String:sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_medic", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, MedicHealth, MedicClassname, MedicIndex, MedicAttributes, MedicClass, MedicAmount, MedicSpeciality, MedicAmmo, MedicClip, MedicRobot);
}

public bool:SUM8_CanInvoke(client)
{
	return true;
}

public void SUM8_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:SniperClassname[64], String:SniperAttributes[256];
	
	new SniperHealth = FF2_GetAbilityArgument(boss, this_plugin_name, SNIPER_SUMMONING, 1);
	new SniperIndex = FF2_GetAbilityArgument(boss, this_plugin_name, SNIPER_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SNIPER_SUMMONING, 3, SniperClassname, sizeof(SniperClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SNIPER_SUMMONING, 4, SniperAttributes, sizeof(SniperAttributes));
	new TFClassType:SniperClass = TFClassType:FF2_GetAbilityArgument(boss, this_plugin_name, SNIPER_SUMMONING, 5);
	new SniperAmount = FF2_GetAbilityArgument(boss, this_plugin_name, SNIPER_SUMMONING, 6);
	new SniperSpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, SNIPER_SUMMONING, 7);
	new SniperAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, SNIPER_SUMMONING, 8, 0);
	new SniperClip = FF2_GetAbilityArgument(boss, this_plugin_name, SNIPER_SUMMONING, 9, 0);
	new bool:SniperRobot = bool:FF2_GetAbilityArgument(boss, this_plugin_name, SNIPER_SUMMONING, 10);
	
	
	new String:sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_sniper", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, SniperHealth, SniperClassname, SniperIndex, SniperAttributes, SniperClass, SniperAmount, SniperSpeciality, SniperAmmo, SniperClip, SniperRobot);
}

public bool:SUM9_CanInvoke(client)
{
	return true;
}

public void SUM9_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:SpyClassname[64], String:SpyAttributes[256];
	
	new SpyHealth = FF2_GetAbilityArgument(boss, this_plugin_name, SPY_SUMMONING, 1);
	new SpyIndex = FF2_GetAbilityArgument(boss, this_plugin_name, SPY_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SPY_SUMMONING, 3, SpyClassname, sizeof(SpyClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SPY_SUMMONING, 4, SpyAttributes, sizeof(SpyAttributes));
	new TFClassType:SpyClass = TFClassType:FF2_GetAbilityArgument(boss, this_plugin_name, SPY_SUMMONING, 5);
	new SpyAmount = FF2_GetAbilityArgument(boss, this_plugin_name, SPY_SUMMONING, 6);
	new SpySpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, SPY_SUMMONING, 7);
	new SpyAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, SPY_SUMMONING, 8, 0);
	new SpyClip = FF2_GetAbilityArgument(boss, this_plugin_name, SPY_SUMMONING, 9, 0);
	new bool:SpyRobot = bool:FF2_GetAbilityArgument(boss, this_plugin_name, SPY_SUMMONING, 10);
	
	new String:sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_spy", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, SpyHealth, SpyClassname, SpyIndex, SpyAttributes, SpyClass, SpyAmount, SpySpeciality, SpyAmmo, SpyClip, SpyRobot);
}

public bool:SU10_CanInvoke(client)
{
	return true;
}

public void SU10_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:UltimateClassname[64], String:UltimateAttributes[256];
	
	new UltimateHealth = FF2_GetAbilityArgument(boss, this_plugin_name, ULTIMATE_SUMMONING, 1);
	new UltimateIndex = FF2_GetAbilityArgument(boss, this_plugin_name, ULTIMATE_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ULTIMATE_SUMMONING, 3, UltimateClassname, sizeof(UltimateClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ULTIMATE_SUMMONING, 4, UltimateAttributes, sizeof(UltimateAttributes));
	new TFClassType:UltimateClass = TFClassType:FF2_GetAbilityArgument(boss, this_plugin_name, ULTIMATE_SUMMONING, 5);
	new UltimateAmount = FF2_GetAbilityArgument(boss, this_plugin_name, ULTIMATE_SUMMONING, 6);
	new UltimateSpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, ULTIMATE_SUMMONING, 7);
	new UltimateAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, ULTIMATE_SUMMONING, 8, 0);
	new UltimateClip = FF2_GetAbilityArgument(boss, this_plugin_name, ULTIMATE_SUMMONING, 9, 0);
	new bool:UltimateRobot = bool:FF2_GetAbilityArgument(boss, this_plugin_name, ULTIMATE_SUMMONING, 10);
	
	new String:sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_ultimate_summoning", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, UltimateHealth, UltimateClassname, UltimateIndex, UltimateAttributes, UltimateClass, UltimateAmount, UltimateSpeciality, UltimateAmmo, UltimateClip, UltimateRobot);
}

SpawnMecenaries(boss, health, String:classname[], index, String:attributes[], TFClassType:classnumber, amount, speciality, ammo, clip, robots)
{
	new client;
	new bossIdx=FF2_GetBossIndex(boss);
	for (new mercenary=0; mercenary<amount; mercenary++)
	{
		client = GetRandomDeadPlayer();
		if(client != -1)
		{
			FF2_SetFF2flags(client,FF2_GetFF2flags(client)|FF2FLAG_ALLOWSPAWNINBOSSTEAM); // Spawn in Boss team
			FF2_SetFF2flags(client,FF2_GetFF2flags(client)|FF2FLAG_ALLOW_AMMO_PICKUPS); // Ammo Pickup
			FF2_SetFF2flags(client,FF2_GetFF2flags(client)|FF2FLAG_ALLOW_HEALTH_PICKUPS); // NO HP Pickups!
			
			ChangeClientTeam(client,FF2_GetBossTeam());
			TF2_RespawnPlayer(client);
			SummonerIndex[client]=bossIdx;
			
			if(classnumber)
			{
				switch(classnumber)
				{
					case 1:
						TF2_SetPlayerClass(client, TFClass_Scout, _, false);
					case 2:
						TF2_SetPlayerClass(client, TFClass_Sniper, _, false);
					case 3:
						TF2_SetPlayerClass(client, TFClass_Soldier, _, false);
					case 4:
						TF2_SetPlayerClass(client, TFClass_DemoMan, _, false);
					case 5:
						TF2_SetPlayerClass(client, TFClass_Medic, _, false);
					case 6:
						TF2_SetPlayerClass(client, TFClass_Heavy, _, false);
					case 7:
						TF2_SetPlayerClass(client, TFClass_Pyro, _, false);
					case 8:
						TF2_SetPlayerClass(client, TFClass_Spy, _, false);
					case 9:
						TF2_SetPlayerClass(client, TFClass_Engineer, _, false);
				}
				TF2_RemoveAllWeapons(client);
				
				new weapon=SpawnWeapon(client, classname, index, 100, 5, attributes);
				
				if(speciality==1)
				{
					SpawnWeapon(client, "tf_weapon_pda_engineer_build", 25, 101, 5, "292 ; 3 ; 293 ; 59 ; 391 ; 2 ; 495 ; 60"); // Build PDA
					SpawnWeapon(client, "tf_weapon_pda_engineer_destroy", 26, 101, 5, "391 ; 2"); // Destroy PDA
					new PDA = SpawnWeapon(client, "tf_weapon_builder", 28, 101, 5, "391 ; 2"); // Builder
					SetEntProp(PDA, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
					SetEntProp(PDA, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
					SetEntProp(PDA, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
					SetEntProp(PDA, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
				}
				
				if(speciality==2)
				{
					SpawnWeapon(client, "tf_weapon_invis", 30, 1, 0, "391 ; 2");
					SpawnWeapon(client, "tf_weapon_pda_spy", 27, 1, 0, "391 ; 2");
					new sapper = SpawnWeapon(client, "tf_weapon_builder", 735, 101, 5, "391 ; 2");
					SetEntProp(sapper, Prop_Send, "m_iObjectType", 3);
					SetEntProp(sapper, Prop_Data, "m_iSubType", 3);
					SetEntProp(sapper, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
					SetEntProp(sapper, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
					SetEntProp(sapper, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
					SetEntProp(sapper, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
				}
				
				if(speciality==3)
				{
					SpawnWeapon(client, "tf_weapon_medigun", 29, 100, 5, "2025 ; 2 ; 2014 ; 1");
				}
				
				// set clip and ammo last
				new offset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1);
				if (offset >= 0)
				{
					SetEntProp(client, Prop_Send, "m_iAmmo", ammo, 4, offset);
					
					// the weirdness below is to avoid setting clips for invalid weapons like huntsman, flamethrower, minigun, and sniper rifles.
					// without the check below, these weapons would break.
					// as for energy weapons, I frankly don't care. they're a mess. don't use this code for making energy weapons.
					if (GetEntProp(weapon, Prop_Send, "m_iClip1") > 1 && GetEntProp(weapon, Prop_Send, "m_iClip1") < 128)
						SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
				}
				
				SetEntProp(client, Prop_Data, "m_iMaxHealth", health);
				SetEntProp(client, Prop_Data, "m_iHealth", health);
				SetEntProp(client, Prop_Send, "m_iHealth", health);
			}
			
			new owner, entity;
			while((entity=FindEntityByClassname(entity, "tf_wearable"))!=-1)
				if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==FF2_GetBossTeam())
					TF2_RemoveWearable(owner, entity);
			while((entity=FindEntityByClassname(entity, "tf_wearable_demoshield"))!=-1)
				if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==FF2_GetBossTeam())
					TF2_RemoveWearable(owner, entity);
			while((entity=FindEntityByClassname(entity, "tf_powerup_bottle"))!=-1)
					if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==FF2_GetBossTeam())
						TF2_RemoveWearable(owner, entity);
						
			if(robots)
			{				
				new String:pclassname[10], String:model[PLATFORM_MAX_PATH];
				TF2_GetNameOfClass(TF2_GetPlayerClass(client), pclassname, sizeof(pclassname));
				Format(model, sizeof(model), "models/bots/%s/bot_%s.mdl", pclassname, pclassname);
				ReplaceString(model, sizeof(model), "demoman", "demo", false);
				PrecacheModel(model);
				SetVariantString(model);
				AcceptEntityInput(client, "SetCustomModel");
				SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
				VOMode[client]=VoiceMode_Robot;
			}
			
			if(robots)
				TF2_AddCondition(client, TFCond_UberchargedHidden, 3.0);
			else
				TF2_AddCondition(client, TFCond_Ubercharged, 3.0);
		}
	}
}

#if !defined _FF2_Extras_included
stock int SpawnWeapon(int client, char[] name, int index, int level, int quality, char[] attribute, int visible = 1, bool preserve = false)
{
	if(StrEqual(name,"saxxy", false)) // if "saxxy" is specified as the name, replace with appropiate name
	{ 
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Scout: ReplaceString(name, 64, "saxxy", "tf_weapon_bat", false);
			case TFClass_Soldier: ReplaceString(name, 64, "saxxy", "tf_weapon_shovel", false);
			case TFClass_Pyro: ReplaceString(name, 64, "saxxy", "tf_weapon_fireaxe", false);
			case TFClass_DemoMan: ReplaceString(name, 64, "saxxy", "tf_weapon_bottle", false);
			case TFClass_Heavy: ReplaceString(name, 64, "saxxy", "tf_weapon_fists", false);
			case TFClass_Engineer: ReplaceString(name, 64, "saxxy", "tf_weapon_wrench", false);
			case TFClass_Medic: ReplaceString(name, 64, "saxxy", "tf_weapon_bonesaw", false);
			case TFClass_Sniper: ReplaceString(name, 64, "saxxy", "tf_weapon_club", false);
			case TFClass_Spy: ReplaceString(name, 64, "saxxy", "tf_weapon_knife", false);
		}
	}
	
	if(StrEqual(name, "tf_weapon_shotgun", false)) // If using tf_weapon_shotgun for Soldier/Pyro/Heavy/Engineer
	{
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Soldier:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_soldier", false);
			case TFClass_Pyro:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_pyro", false);
			case TFClass_Heavy:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_hwg", false);
			case TFClass_Engineer:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_primary", false);
		}
	}

	Handle weapon = TF2Items_CreateItem((preserve ? PRESERVE_ATTRIBUTES : OVERRIDE_ALL) | FORCE_GENERATION);
	TF2Items_SetClassname(weapon, name);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, quality);
	char attributes[32][32];
	int count = ExplodeString(attribute, ";", attributes, 32, 32);
	if(count%2!=0)
	{
		count--;
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(weapon, count/2);
		int i2 = 0;
		for(int i = 0; i < count; i += 2)
		{
			int attrib = StringToInt(attributes[i]);
			if (attrib == 0)
			{
				LogError("Bad weapon attribute passed: %s ; %s", attributes[i], attributes[i+1]);
				return -1;
			}
			TF2Items_SetAttribute(weapon, i2, attrib, StringToFloat(attributes[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(weapon, 0);
	}

	if (weapon == INVALID_HANDLE)
	{
		PrintToServer("[SpawnWeapon] Error: Invalid weapon spawned. client=%d name=%s idx=%d attr=%s", client, name, index, attribute);
		return -1;
	}

	int entity = TF2Items_GiveNamedItem(client, weapon);
	delete weapon;
	
	if(!visible)
	{
		SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
	}
	
	if (StrContains(name, "tf_wearable")==-1)
	{
		EquipPlayerWeapon(client, entity);
	}
	else
	{
		Wearable_EquipWearable(client, entity);
	}
	
	return entity;
}

Handle S93SF_equipWearable = INVALID_HANDLE;
stock void Wearable_EquipWearable(client, wearable)
{
	if(S93SF_equipWearable==INVALID_HANDLE)
	{
		Handle config=LoadGameConfigFile("equipwearable");
		if(config==INVALID_HANDLE)
		{
			LogError("[FF2] EquipWearable gamedata could not be found; make sure /gamedata/equipwearable.txt exists.");
			return;
		}

		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "EquipWearable");
		CloseHandle(config);
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		if((S93SF_equipWearable=EndPrepSDKCall())==INVALID_HANDLE)
		{
			LogError("[FF2] Couldn't load SDK function (CTFPlayer::EquipWearable). SDK call failed.");
			return;
		}
	}
	SDKCall(S93SF_equipWearable, client, wearable);
}
#endif

stock SetAmmo(client, slot, ammo)
{
	new weapon2 = GetPlayerWeaponSlot(client, slot);
	if (IsValidEntity(weapon2))
	{
		new iOffset = GetEntProp(weapon2, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		new iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		SetEntData(client, iAmmoTable+iOffset, ammo, 4, true);
	}
}

stock bool:IsBoss(client)
{
	if(FF2_GetBossIndex(client)==-1) return false;
	if(GetClientTeam(client)!=FF2_GetBossTeam()) return false;
	return true;
}

stock bool:IsValidMinion(client)
{
	if (GetClientTeam(client)!=FF2_GetBossTeam()) return false;
	if (FF2_GetBossIndex(client) != -1) return false;
	if (SummonerIndex[client] == -1) return false;
	return true;
}

stock bool:IsValidClient(client, bool:isPlayerAlive=false)
{
	if (client <= 0 || client > MaxClients) return false;
	if(isPlayerAlive) return IsClientInGame(client) && IsPlayerAlive(client);
	return IsClientInGame(client);
}

stock GetRandomDeadPlayer()
{
	new clients[MaxClients+1], clientCount;
	for(new i=1;i<=MaxClients;i++)
	{
		if(IsValidEdict(i) && IsValidClient(i) && !IsPlayerAlive(i) && !IsBoss(i) && (GetClientTeam(i) > 1))
		{
			clients[clientCount++] = i;
		}
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

#if SOURCEMOD_V_MAJOR==1 && SOURCEMOD_V_MINOR<=7
public Action:SoundHook(clients[64], &numClients, String:vl[PLATFORM_MAX_PATH], &client, &channel, &Float:volume, &level, &pitch, &flags)
#else
public Action:SoundHook(clients[64], &numClients, String:vl[PLATFORM_MAX_PATH], &client, &channel, &Float:volume, &level, &pitch, &flags, String:soundEntry[PLATFORM_MAX_PATH], &seed)
#endif
{
	if(!IsValidClient(client) || channel<1)
	{
		return Plugin_Continue;
	}

	switch(VOMode[client])
	{
		case VoiceMode_Robot:	// Robot VO
		{
			if(!TF2_IsPlayerInCondition(client, TFCond_Disguised)) // Robot voice lines & footsteps
			{
				if (StrContains(vl, "player/footsteps/", false) != -1 && TF2_GetPlayerClass(client) != TFClass_Medic)
				{
					new rand = GetRandomInt(1,18);
					Format(vl, sizeof(vl), "mvm/player/footsteps/robostep_%s%i.wav", (rand < 10) ? "0" : "", rand);
					pitch = GetRandomInt(95, 100);
					EmitSoundToAll(vl, client, _, _, _, 0.25, pitch);
				}
				
				if(channel==SNDCHAN_VOICE)
				{
					if (volume == 0.99997) return Plugin_Continue;
					ReplaceString(vl, sizeof(vl), "vo/", "vo/mvm/norm/", false);
					ReplaceString(vl, sizeof(vl), ".wav", ".mp3", false);
					new String:classname[10], String:classname_mvm[15];
					TF2_GetNameOfClass(TF2_GetPlayerClass(client), classname, sizeof(classname));
					Format(classname_mvm, sizeof(classname_mvm), "%s_mvm", classname);
					ReplaceString(vl, sizeof(vl), classname, classname_mvm, false);
					new String:nSnd[PLATFORM_MAX_PATH];
					Format(nSnd, sizeof(nSnd), "sound/%s", vl);
					PrecacheSound(vl);
				}
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

stock TF2_GetNameOfClass(TFClassType:class, String:name[], maxlen) // Retrieves player class name
{
	switch (class)
	{
		case TFClass_Scout: Format(name, maxlen, "scout");
		case TFClass_Soldier: Format(name, maxlen, "soldier");
		case TFClass_Pyro: Format(name, maxlen, "pyro");
		case TFClass_DemoMan: Format(name, maxlen, "demoman");
		case TFClass_Heavy: Format(name, maxlen, "heavy");
		case TFClass_Engineer: Format(name, maxlen, "engineer");
		case TFClass_Medic: Format(name, maxlen, "medic");
		case TFClass_Sniper: Format(name, maxlen, "sniper");
		case TFClass_Spy: Format(name, maxlen, "spy");
	}
}