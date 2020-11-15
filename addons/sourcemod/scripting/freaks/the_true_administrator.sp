#define FF2_USING_AUTO_PLUGIN__OLD

#include <tf2_stocks>
#include <ff2_ams2>
#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

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
	VoiceMode_Robot
};

int SummonerIndex[MAXPLAYERS+1];
VoiceMode VOMode[MAXPLAYERS+1];

public Plugin myinfo = {
	name	= "Freak Fortress 2: The Administrator",
	author	= "M7",
	version = "1.0",
};

public void OnPluginStart2()
{
	HookEvent("arena_round_start", event_round_start, EventHookMode_PostNoCopy);
	HookEvent("player_death", event_player_death);
	
	AddNormalSoundHook(SoundHook);
}

public void FF2AMS_PreRoundStart(int client)
{
	int boss = FF2_GetBossIndex(client);
	if(FF2_HasAbility(boss, this_plugin_name, SCOUT_SUMMONING))
	{
		FF2AMS_PushToAMS(client, this_plugin_name, SCOUT_SUMMONING, "SUM1"); // Important function to tell AMS that this subplugin supports it
	}
	if(FF2_HasAbility(boss, this_plugin_name, SOLDIER_SUMMONING))
	{
		FF2AMS_PushToAMS(client, this_plugin_name, SOLDIER_SUMMONING, "SUM2"); // Important function to tell AMS that this subplugin supports it
	}
	if(FF2_HasAbility(boss, this_plugin_name, PYRO_SUMMONING))
	{
		FF2AMS_PushToAMS(client, this_plugin_name, PYRO_SUMMONING, "SUM3"); // Important function to tell AMS that this subplugin supports it
	}
	if(FF2_HasAbility(boss, this_plugin_name, DEMOMAN_SUMMONING))
	{
		FF2AMS_PushToAMS(client, this_plugin_name, DEMOMAN_SUMMONING, "SUM4"); // Important function to tell AMS that this subplugin supports it
	}
	if(FF2_HasAbility(boss, this_plugin_name, HEAVY_SUMMONING))
	{
		FF2AMS_PushToAMS(client, this_plugin_name, HEAVY_SUMMONING, "SUM5"); // Important function to tell AMS that this subplugin supports it
	}
	if(FF2_HasAbility(boss, this_plugin_name, ENGINEER_SUMMONING))
	{
		FF2AMS_PushToAMS(client, this_plugin_name, ENGINEER_SUMMONING, "SUM6"); // Important function to tell AMS that this subplugin supports it
	}
	if(FF2_HasAbility(boss, this_plugin_name, MEDIC_SUMMONING))
	{
		FF2AMS_PushToAMS(client, this_plugin_name, MEDIC_SUMMONING, "SUM7"); // Important function to tell AMS that this subplugin supports it
	}
	if(FF2_HasAbility(boss, this_plugin_name, SNIPER_SUMMONING))
	{
		FF2AMS_PushToAMS(client, this_plugin_name, SNIPER_SUMMONING, "SUM8"); // Important function to tell AMS that this subplugin supports it
	}
	if(FF2_HasAbility(boss, this_plugin_name, SPY_SUMMONING))
	{
		FF2AMS_PushToAMS(client, this_plugin_name, SPY_SUMMONING, "SUM9"); // Important function to tell AMS that this subplugin supports it
	}
	if(FF2_HasAbility(boss, this_plugin_name, ULTIMATE_SUMMONING))
	{
		FF2AMS_PushToAMS(client, this_plugin_name, ULTIMATE_SUMMONING, "SU10"); // Important function to tell AMS that this subplugin supports it
	}
}

public void event_round_start(Event event, const char[] name, bool dontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
	
	for(int client=1; client<=MaxClients; client++)
	{
		if(!IsValidClient(client))
			continue;
		
		SummonerIndex[client]=-1;
		VOMode[client]=VoiceMode_Normal;
	}
}

public Action event_player_death(Event event, const char[] name, bool dontBroadcast)
{
	if(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
	{
		return Plugin_Continue;
	}
	
	int client = GetClientOfUserId(event.GetInt("userid"));

	int boss = FF2_GetBossIndex(client); // Boss is the victim
	if(boss != -1 && FF2_HasAbility(boss, this_plugin_name, ULTIMATE_SUMMONING))
	{
		for(int clone=1; clone<=MaxClients; clone++)
		{
			if(SummonerIndex[clone]==boss && IsValidClient(clone) && IsValidMinion(clone) && IsPlayerAlive(clone))
			{
				SummonerIndex[clone]=-1;
				VOMode[clone]=VoiceMode_Normal;
				ChangeClientTeam(clone, (FF2_GetBossTeam()==view_as<int>(TFTeam_Blue) ? (view_as<int>(TFTeam_Red)) : (view_as<int>(TFTeam_Blue))));
			}
		}
	}
	return Plugin_Continue;
}


public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status) {
	return Plugin_Continue;
}


public AMSResult SUM1_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void SUM1_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	static char ScoutClassname[64], ScoutAttributes[256];
	
	int ScoutHealth = FF2_GetAbilityArgument(boss, this_plugin_name, SCOUT_SUMMONING, 1);
	int ScoutIndex = FF2_GetAbilityArgument(boss, this_plugin_name, SCOUT_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SCOUT_SUMMONING, 3, ScoutClassname, sizeof(ScoutClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SCOUT_SUMMONING, 4, ScoutAttributes, sizeof(ScoutAttributes));
	TFClassType ScoutClass = view_as<TFClassType>(FF2_GetAbilityArgument(boss, this_plugin_name, SCOUT_SUMMONING, 5));
	int ScoutAmount = FF2_GetAbilityArgument(boss, this_plugin_name, SCOUT_SUMMONING, 6);
	int ScoutSpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, SCOUT_SUMMONING, 7);
	int ScoutAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, SCOUT_SUMMONING, 8, 0);
	int ScoutClip = FF2_GetAbilityArgument(boss, this_plugin_name, SCOUT_SUMMONING, 9, 0);
	bool ScoutRobot = FF2_GetAbilityArgument(boss, this_plugin_name, SCOUT_SUMMONING, 10) != 0;
	
	char sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_scout", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, ScoutHealth, ScoutClassname, ScoutIndex, ScoutAttributes, ScoutClass, ScoutAmount, ScoutSpeciality, ScoutAmmo, ScoutClip, ScoutRobot);
}

public AMSResult SUM2_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void SUM2_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	static char SoldierClassname[64], SoldierAttributes[256];
	
	int SoldierHealth = FF2_GetAbilityArgument(boss, this_plugin_name, SOLDIER_SUMMONING, 1);
	int SoldierIndex = FF2_GetAbilityArgument(boss, this_plugin_name, SOLDIER_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SOLDIER_SUMMONING, 3, SoldierClassname, sizeof(SoldierClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SOLDIER_SUMMONING, 4, SoldierAttributes, sizeof(SoldierAttributes));
	TFClassType SoldierClass = view_as<TFClassType>(FF2_GetAbilityArgument(boss, this_plugin_name, SOLDIER_SUMMONING, 5));
	int SoldierAmount = FF2_GetAbilityArgument(boss, this_plugin_name, SOLDIER_SUMMONING, 6);
	int SoldierSpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, SOLDIER_SUMMONING, 7);
	int SoldierAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, SOLDIER_SUMMONING, 8, 0);
	int SoldierClip = FF2_GetAbilityArgument(boss, this_plugin_name, SOLDIER_SUMMONING, 9, 0);
	bool SoldierRobot = FF2_GetAbilityArgument(boss, this_plugin_name, SOLDIER_SUMMONING, 10) != 0;
	
	char sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_soldier", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, SoldierHealth, SoldierClassname, SoldierIndex, SoldierAttributes, SoldierClass, SoldierAmount, SoldierSpeciality, SoldierAmmo, SoldierClip, SoldierRobot);
}

public AMSResult SUM3_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void SUM3_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	static char PyroClassname[64], PyroAttributes[256];
	
	int PyroHealth = FF2_GetAbilityArgument(boss, this_plugin_name, PYRO_SUMMONING, 1);
	int PyroIndex = FF2_GetAbilityArgument(boss, this_plugin_name, PYRO_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, PYRO_SUMMONING, 3, PyroClassname, sizeof(PyroClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, PYRO_SUMMONING, 4, PyroAttributes, sizeof(PyroAttributes));
	TFClassType PyroClass = view_as<TFClassType>(FF2_GetAbilityArgument(boss, this_plugin_name, PYRO_SUMMONING, 5));
	int PyroAmount = FF2_GetAbilityArgument(boss, this_plugin_name, PYRO_SUMMONING, 6);
	int PyroSpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, PYRO_SUMMONING, 7);
	int PyroAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, PYRO_SUMMONING, 8, 0);
	int PyroClip = FF2_GetAbilityArgument(boss, this_plugin_name, PYRO_SUMMONING, 9, 0);
	bool PyroRobot = FF2_GetAbilityArgument(boss, this_plugin_name, PYRO_SUMMONING, 10) != 0;
	
	char sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_pyro", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, PyroHealth, PyroClassname, PyroIndex, PyroAttributes, PyroClass, PyroAmount, PyroSpeciality, PyroAmmo, PyroClip, PyroRobot);
}

public AMSResult SUM4_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void SUM4_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	static char DemoClassname[64], DemoAttributes[256];
	
	int DemoHealth = FF2_GetAbilityArgument(boss, this_plugin_name, DEMOMAN_SUMMONING, 1);
	int DemoIndex = FF2_GetAbilityArgument(boss, this_plugin_name, DEMOMAN_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, DEMOMAN_SUMMONING, 3, DemoClassname, sizeof(DemoClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, DEMOMAN_SUMMONING, 4, DemoAttributes, sizeof(DemoAttributes));
	TFClassType DemoClass = view_as<TFClassType>(FF2_GetAbilityArgument(boss, this_plugin_name, DEMOMAN_SUMMONING, 5));
	int DemoAmount = FF2_GetAbilityArgument(boss, this_plugin_name, DEMOMAN_SUMMONING, 6);
	int DemoSpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, DEMOMAN_SUMMONING, 7);
	int DemoAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, DEMOMAN_SUMMONING, 8, 0);
	int DemoClip = FF2_GetAbilityArgument(boss, this_plugin_name, DEMOMAN_SUMMONING, 9, 0);
	bool DemoRobot = FF2_GetAbilityArgument(boss, this_plugin_name, DEMOMAN_SUMMONING, 10) != 0;
	
	char sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_demoman", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, DemoHealth, DemoClassname, DemoIndex, DemoAttributes, DemoClass, DemoAmount, DemoSpeciality, DemoAmmo, DemoClip, DemoRobot);
}

public AMSResult SUM5_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void SUM5_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	static char HeavyClassname[64], HeavyAttributes[256];
	
	int HeavyHealth = FF2_GetAbilityArgument(boss, this_plugin_name, HEAVY_SUMMONING, 1);
	int HeavyIndex = FF2_GetAbilityArgument(boss, this_plugin_name, HEAVY_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, HEAVY_SUMMONING, 3, HeavyClassname, sizeof(HeavyClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, HEAVY_SUMMONING, 4, HeavyAttributes, sizeof(HeavyAttributes));
	TFClassType HeavyClass = view_as<TFClassType>(FF2_GetAbilityArgument(boss, this_plugin_name, HEAVY_SUMMONING, 5));
	int HeavyAmount = FF2_GetAbilityArgument(boss, this_plugin_name, HEAVY_SUMMONING, 6);
	int HeavySpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, HEAVY_SUMMONING, 7);
	int HeavyAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, HEAVY_SUMMONING, 8, 0);
	int HeavyClip = FF2_GetAbilityArgument(boss, this_plugin_name, HEAVY_SUMMONING, 9, 0);
	bool HeavyRobot = FF2_GetAbilityArgument(boss, this_plugin_name, HEAVY_SUMMONING, 10) != 0;
	
	char sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_heavy", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, HeavyHealth, HeavyClassname, HeavyIndex, HeavyAttributes, HeavyClass, HeavyAmount, HeavySpeciality, HeavyAmmo, HeavyClip, HeavyRobot);
}

public AMSResult SUM6_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void SUM6_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	static char EngineerClassname[64], EngineerAttributes[256];
	
	int EngineerHealth = FF2_GetAbilityArgument(boss, this_plugin_name, ENGINEER_SUMMONING, 1);
	int EngineerIndex = FF2_GetAbilityArgument(boss, this_plugin_name, ENGINEER_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ENGINEER_SUMMONING, 3, EngineerClassname, sizeof(EngineerClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ENGINEER_SUMMONING, 4, EngineerAttributes, sizeof(EngineerAttributes));
	TFClassType EngineerClass = view_as<TFClassType>(FF2_GetAbilityArgument(boss, this_plugin_name, ENGINEER_SUMMONING, 5));
	int EngineerAmount = FF2_GetAbilityArgument(boss, this_plugin_name, ENGINEER_SUMMONING, 6);
	int EngineerSpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, ENGINEER_SUMMONING, 7);
	int EngineerAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, ENGINEER_SUMMONING, 8, 0);
	int EngineerClip = FF2_GetAbilityArgument(boss, this_plugin_name, ENGINEER_SUMMONING, 9, 0);
	bool EngineerRobot = FF2_GetAbilityArgument(boss, this_plugin_name, ENGINEER_SUMMONING, 10) != 0;
	
	char sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_engineer", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, EngineerHealth, EngineerClassname, EngineerIndex, EngineerAttributes, EngineerClass, EngineerAmount, EngineerSpeciality, EngineerAmmo, EngineerClip, EngineerRobot);
}

public AMSResult SUM7_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void SUM7_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	static char MedicClassname[64], MedicAttributes[256];
	
	int MedicHealth = FF2_GetAbilityArgument(boss, this_plugin_name, MEDIC_SUMMONING, 1);
	int MedicIndex = FF2_GetAbilityArgument(boss, this_plugin_name, MEDIC_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, MEDIC_SUMMONING, 3, MedicClassname, sizeof(MedicClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, MEDIC_SUMMONING, 4, MedicAttributes, sizeof(MedicAttributes));
	TFClassType MedicClass = view_as<TFClassType>(FF2_GetAbilityArgument(boss, this_plugin_name, MEDIC_SUMMONING, 5));
	int MedicAmount = FF2_GetAbilityArgument(boss, this_plugin_name, MEDIC_SUMMONING, 6);
	int MedicSpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, MEDIC_SUMMONING, 7);
	int MedicAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, MEDIC_SUMMONING, 8, 0);
	int MedicClip = FF2_GetAbilityArgument(boss, this_plugin_name, MEDIC_SUMMONING, 9, 0);
	bool MedicRobot = FF2_GetAbilityArgument(boss, this_plugin_name, MEDIC_SUMMONING, 10) != 0;
	
	char sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_medic", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, MedicHealth, MedicClassname, MedicIndex, MedicAttributes, MedicClass, MedicAmount, MedicSpeciality, MedicAmmo, MedicClip, MedicRobot);
}

public AMSResult SUM8_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void SUM8_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	static char SniperClassname[64], SniperAttributes[256];
	
	int SniperHealth = FF2_GetAbilityArgument(boss, this_plugin_name, SNIPER_SUMMONING, 1);
	int SniperIndex = FF2_GetAbilityArgument(boss, this_plugin_name, SNIPER_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SNIPER_SUMMONING, 3, SniperClassname, sizeof(SniperClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SNIPER_SUMMONING, 4, SniperAttributes, sizeof(SniperAttributes));
	TFClassType SniperClass = view_as<TFClassType>(FF2_GetAbilityArgument(boss, this_plugin_name, SNIPER_SUMMONING, 5));
	int SniperAmount = FF2_GetAbilityArgument(boss, this_plugin_name, SNIPER_SUMMONING, 6);
	int SniperSpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, SNIPER_SUMMONING, 7);
	int SniperAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, SNIPER_SUMMONING, 8, 0);
	int SniperClip = FF2_GetAbilityArgument(boss, this_plugin_name, SNIPER_SUMMONING, 9, 0);
	bool SniperRobot = FF2_GetAbilityArgument(boss, this_plugin_name, SNIPER_SUMMONING, 10) != 0;
	
	char sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_sniper", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, SniperHealth, SniperClassname, SniperIndex, SniperAttributes, SniperClass, SniperAmount, SniperSpeciality, SniperAmmo, SniperClip, SniperRobot);
}

public AMSResult SUM9_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void SUM9_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	static char SpyClassname[64], SpyAttributes[256];
	
	int SpyHealth = FF2_GetAbilityArgument(boss, this_plugin_name, SPY_SUMMONING, 1);
	int SpyIndex = FF2_GetAbilityArgument(boss, this_plugin_name, SPY_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SPY_SUMMONING, 3, SpyClassname, sizeof(SpyClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SPY_SUMMONING, 4, SpyAttributes, sizeof(SpyAttributes));
	TFClassType SpyClass = view_as<TFClassType>(FF2_GetAbilityArgument(boss, this_plugin_name, SPY_SUMMONING, 5));
	int SpyAmount = FF2_GetAbilityArgument(boss, this_plugin_name, SPY_SUMMONING, 6);
	int SpySpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, SPY_SUMMONING, 7);
	int SpyAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, SPY_SUMMONING, 8, 0);
	int SpyClip = FF2_GetAbilityArgument(boss, this_plugin_name, SPY_SUMMONING, 9, 0);
	bool SpyRobot = FF2_GetAbilityArgument(boss, this_plugin_name, SPY_SUMMONING, 10) != 0;
	
	char sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_summoning_spy", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, SpyHealth, SpyClassname, SpyIndex, SpyAttributes, SpyClass, SpyAmount, SpySpeciality, SpyAmmo, SpyClip, SpyRobot);
}

public AMSResult SU10_CanInvoke(int client, int index) 
{
	return AMS_Accept;
}

public void SU10_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	static char UltimateClassname[64], UltimateAttributes[256];
	
	int UltimateHealth = FF2_GetAbilityArgument(boss, this_plugin_name, ULTIMATE_SUMMONING, 1);
	int UltimateIndex = FF2_GetAbilityArgument(boss, this_plugin_name, ULTIMATE_SUMMONING, 2);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ULTIMATE_SUMMONING, 3, UltimateClassname, sizeof(UltimateClassname));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ULTIMATE_SUMMONING, 4, UltimateAttributes, sizeof(UltimateAttributes));
	TFClassType UltimateClass = view_as<TFClassType>(FF2_GetAbilityArgument(boss, this_plugin_name, ULTIMATE_SUMMONING, 5));
	int UltimateAmount = FF2_GetAbilityArgument(boss, this_plugin_name, ULTIMATE_SUMMONING, 6);
	int UltimateSpeciality = FF2_GetAbilityArgument(boss, this_plugin_name, ULTIMATE_SUMMONING, 7);
	int UltimateAmmo = FF2_GetAbilityArgument(boss, this_plugin_name, ULTIMATE_SUMMONING, 8, 0);
	int UltimateClip = FF2_GetAbilityArgument(boss, this_plugin_name, ULTIMATE_SUMMONING, 9, 0);
	bool UltimateRobot = FF2_GetAbilityArgument(boss, this_plugin_name, ULTIMATE_SUMMONING, 10) != 0;
	
	char sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_ultimate_summoning", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}
	
	SpawnMecenaries(client, UltimateHealth, UltimateClassname, UltimateIndex, UltimateAttributes, UltimateClass, UltimateAmount, UltimateSpeciality, UltimateAmmo, UltimateClip, UltimateRobot);
}

void SpawnMecenaries(int boss, int health, char[] classname, int index, char[] attributes, 
				TFClassType classnumber, int amount, int speciality, int ammo, int clip, int robots)
{
	int client;
	int bossIdx=FF2_GetBossIndex(boss);
	for (int mercenary=0; mercenary<amount; mercenary++)
	{
		client = GetRandomDeadPlayer();
		if(client != -1)
		{
			FF2Player player = FF2Player(client);
			player.SetPropAny("bNoHealthPacks", true);
			player.SetPropAny("bNoAmmoPacks", true);
			player.SetPropAny("bIsMinion", true);
			
			player.ForceTeamChange(VSH2Team_Boss);
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
				
				int weapon=SpawnWeapon(client, classname, index, 100, 5, attributes);
				
				if(speciality==1)
				{
					SpawnWeapon(client, "tf_weapon_pda_engineer_build", 25, 101, 5, "292 ; 3 ; 293 ; 59 ; 391 ; 2 ; 495 ; 60"); // Build PDA
					SpawnWeapon(client, "tf_weapon_pda_engineer_destroy", 26, 101, 5, "391 ; 2"); // Destroy PDA
					int PDA = SpawnWeapon(client, "tf_weapon_builder", 28, 101, 5, "391 ; 2"); // Builder
					SetEntProp(PDA, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
					SetEntProp(PDA, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
					SetEntProp(PDA, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
					SetEntProp(PDA, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
				}
				
				if(speciality==2)
				{
					SpawnWeapon(client, "tf_weapon_invis", 30, 1, 0, "391 ; 2");
					SpawnWeapon(client, "tf_weapon_pda_spy", 27, 1, 0, "391 ; 2");
					int sapper = SpawnWeapon(client, "tf_weapon_builder", 735, 101, 5, "391 ; 2");
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
				int offset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1);
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
			
			int owner, entity;
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
				static char pclassname[10], model[PLATFORM_MAX_PATH];
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

stock void Wearable_EquipWearable(int client, int wearable)
{
	static Handle S93SF_equipWearable = INVALID_HANDLE;
	if(!S93SF_equipWearable)
	{
		GameData config = new GameData("equipwearable");
		if(config == null)
		{
			LogError("[FF2] EquipWearable gamedata could not be found; make sure /gamedata/equipwearable.txt exists.");
			return;
		}

		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "EquipWearable");
		delete config;
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		if((S93SF_equipWearable=EndPrepSDKCall())==null)
		{
			LogError("[FF2] Couldn't load SDK function (CTFPlayer::EquipWearable). SDK call failed.");
			return;
		}
	}
	SDKCall(S93SF_equipWearable, client, wearable);
}
#endif


stock bool IsBoss(int client)
{
	if(FF2_GetBossIndex(client)==-1) return false;
	if(GetClientTeam(client)!=FF2_GetBossTeam()) return false;
	return true;
}

stock bool IsValidMinion(int client)
{
	if (GetClientTeam(client)!=FF2_GetBossTeam()) return false;
	if (FF2_GetBossIndex(client) != -1) return false;
	if (SummonerIndex[client] == -1) return false;
	return true;
}

stock bool IsValidClient(int client, bool isPlayerAlive=false)
{
	if (client <= 0 || client > MaxClients) return false;
	if(isPlayerAlive) return IsClientInGame(client) && IsPlayerAlive(client);
	return IsClientInGame(client);
}

stock int GetRandomDeadPlayer()
{
	int clientCount;
	int[] clients = new int[MaxClients+1];
	for(int i=1;i<=MaxClients;i++)
	{
		if(IsValidEdict(i) && IsValidClient(i) && !IsPlayerAlive(i) && !IsBoss(i) && (GetClientTeam(i) > 1))
		{
			clients[clientCount++] = i;
		}
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

public Action SoundHook(int clients[MAXPLAYERS], int& numClients, char vl[PLATFORM_MAX_PATH],
	  int& client, int& channel, float& volume, int& level, int& pitch, int& flags,
	  char soundEntry[PLATFORM_MAX_PATH], int& seed)
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
					int rand = GetRandomInt(1,18);
					FormatEx(vl, sizeof(vl), "mvm/player/footsteps/robostep_%s%i.wav", (rand < 10) ? "0" : "", rand);
					pitch = GetRandomInt(95, 100);
					EmitSoundToAll(vl, client, _, _, _, 0.25, pitch);
				}
				
				if(channel==SNDCHAN_VOICE)
				{
					if (volume == 0.99997) return Plugin_Continue;
					ReplaceString(vl, sizeof(vl), "vo/", "vo/mvm/norm/", false);
					ReplaceString(vl, sizeof(vl), ".wav", ".mp3", false);
					static char classname[10], classname_mvm[15];
					TF2_GetNameOfClass(TF2_GetPlayerClass(client), classname, sizeof(classname));
					Format(classname_mvm, sizeof(classname_mvm), "%s_mvm", classname);
					ReplaceString(vl, sizeof(vl), classname, classname_mvm, false);
					static char nSnd[PLATFORM_MAX_PATH];
					FormatEx(nSnd, sizeof(nSnd), "sound/%s", vl);
					PrecacheSound(vl);
				}
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

stock void TF2_GetNameOfClass(TFClassType class, char[] name, int maxlen) // Retrieves player class name
{
	switch (class)
	{
		case TFClass_Scout: FormatEx(name, maxlen, "scout");
		case TFClass_Soldier: FormatEx(name, maxlen, "soldier");
		case TFClass_Pyro: FormatEx(name, maxlen, "pyro");
		case TFClass_DemoMan: FormatEx(name, maxlen, "demoman");
		case TFClass_Heavy: FormatEx(name, maxlen, "heavy");
		case TFClass_Engineer: FormatEx(name, maxlen, "engineer");
		case TFClass_Medic: FormatEx(name, maxlen, "medic");
		case TFClass_Sniper: FormatEx(name, maxlen, "sniper");
		case TFClass_Spy: FormatEx(name, maxlen, "spy");
	}
}
