/*
	UNFINISHED
	template : 
	
	"ams_base"
	{
		...
		"hook"
		{
			"1"
			{
				"ability"		"abilityX"
				"min"
				{
					"players"	"int"
					"health"	"float"
					"kills"		"int"
					"lives"		"int"
					"minions"	"int"
				}
				"max"
				{
					"players"	"int"
					"health"	"float"
					"kills"		"int"
					"lives"		"int"
					"minions"	"int"
				}
			}
			"2"	
			{
				"ability"		"abilityY"
				...
			}
		}
	}
	
//	hook->X->ability = abilityZ
	"abilityZ"
	{
		"name"		"ability_name"
		
		...
		...
		...
		...
		...
		
		"plugin_name"	"plugin_name"
	}
*/

#include <ff2_ams2>
#include <ff2_helper>
#include <ff2ability>

#pragma semicolon 1
#pragma newdecls required

#define MaxBosses (RoundToCeil(view_as<float>(MaxClients)/2.0))
#define FAST_FORMAT_TO_HOOK(%1) (FormatEx(__key, sizeof(__key), "hook->%i->%s", __vidx, %1));
#define Loop(%1) for(__L = 1; __L < %1; ++__L)

#define FF2AMS_MANUAL_RECONFIGURE() \
		_map.SetString("this_plugin2", plugin_name); \
		_map.SetValue("cooldown", GetGameTime() + player.GetArgF(plugin_name, this_ability_name, "initial cd", 1001, 0.0)); \
		_map.SetValue("abilitycd", GetGameTime() + player.GetArgF(plugin_name, this_ability_name, "ability cd", 1002, 10.0)); \
		static char str[128]; player.GetArgS(plugin_name, this_ability_name, "this_name", 1003, str, sizeof(str)); \
		_map.SetString("this_name", str); \
		player.GetArgS(plugin_name, this_ability_name, "display_desc", 1004, str, sizeof(str)); \
		_map.SetString("display_desc", str); \
		_map.SetValue("this_cost", player.GetArgF(plugin_name, this_ability_name, "cost", 1005, 25.0)); \
		_map.SetValue("this_end", player.GetArgI(plugin_name, this_ability_name, "can end", 1006, 0)); 


FF2Parse GlobalMap[MAXCLIENTS] =  { null, ... };
StringMap Fake_AMSMap[MAXCLIENTS] =  { null, ... };

enum {
	min,
	max,
	_MAX_VALS
};

int iPlayers[MAXCLIENTS][_MAX_VALS][10];
float flHealth[MAXCLIENTS][_MAX_VALS][10];
int iDeads[MAXCLIENTS][_MAX_VALS][10];
int iLives[MAXCLIENTS][_MAX_VALS][10];
int iMinions[MAXCLIENTS][_MAX_VALS][10];

bool IsActive;

int Players, Bosses;
char this_plugin_name[48] = "ff2_fakeams";

public Plugin myinfo = 
{
	name		= "[FF2] Fake AMS2",
	author		= "BatFoxKid, remade by 01Pollux"
};

public void OnPluginStart()
{
	HookEvent("arena_win_panel", Post_RoundEnd, EventHookMode_PostNoCopy);
}

public void Post_RoundEnd(Event event, const char[] name, bool bDontBroadCast)
{
	if(IsActive) {
		for(int i = 0; i < MaxClients; i++) {
			if(Fake_AMSMap[i] != null) {
				delete Fake_AMSMap[i];
			}
		}
	}
}

public void FF2AMS_PreRoundStart(int client)
{
	FF2Prep player = FF2Prep(client);
	GlobalMap[client] = view_as<FF2Parse>(FF2AMS_GetGlobalAMSHashMap(client));
	
	static char ability_key[32];
	if(!GlobalMap[client].GetString("hook->1->ability", ability_key, sizeof(ability_key))) {
		return;
	}
	
	int __L, index;
	static char this_ability_name[64], plugin_name[64];
	char pfx[6];
	char[] key = new char[32];
	
	static KeyValues BossKV = null;
	
	BossKV = player.KeyValues;
	
	Loop(10) {
		BossKV.Rewind();
		
		FormatEx(key, 32, "hook->%i->ability", __L);
		if(!GlobalMap[client].GetString(key, ability_key, sizeof(ability_key))) {
			break;
		}
		
		
		if(!BossKV.JumpToKey(ability_key)
			|| !BossKV.GetString("name", this_ability_name, sizeof(this_ability_name))
			|| !BossKV.GetString("plugin_name", plugin_name, sizeof(plugin_name))) {
			LogError("Missing : %s / %s", ability_key, plugin_name);
			continue;
		}
		
		FormatEx(pfx, sizeof(pfx), "FAKE%i", __L);
		if((index = FF2AMS_PushToAMSEx(client, this_plugin_name, this_ability_name, pfx)) == -1) {
			break;
		}
		
		
		StringMap _map = FF2AMS_GetAMSHashMap(client, index);
		FF2AMS_MANUAL_RECONFIGURE()
		
		if(!Fake_AMSMap[client]) {
			Fake_AMSMap[client] = new StringMap();
		}
		Fake_AMSMap[client].SetValue(this_ability_name, index);
		Fast_Format(client, __L);
	}
	
	delete BossKV;
}


public AMSResult FAKE1_CanInvoke(int client, int index)
{
	return Global_CanInvokeFake(client, 1);
}

public AMSResult FAKE2_CanInvoke(int client, int index)
{
	return Global_CanInvokeFake(client, 2);
}

public AMSResult FAKE3_CanInvoke(int client, int index)
{
	return Global_CanInvokeFake(client, 3);
}

public AMSResult FAKE4_CanInvoke(int client, int index)
{
	return Global_CanInvokeFake(client, 4);
}

public AMSResult FAKE5_CanInvoke(int client, int index)
{
	return Global_CanInvokeFake(client, 5);
}

public AMSResult FAKE6_CanInvoke(int client, int index)
{
	return Global_CanInvokeFake(client, 6);
}


public AMSResult FAKE7_CanInvoke(int client, int index)
{
	return Global_CanInvokeFake(client, 7);
}

public AMSResult FAKE8_CanInvoke(int client, int index)
{
	return Global_CanInvokeFake(client, 8);
}

public AMSResult FAKE9_CanInvoke(int client, int index)
{
	return Global_CanInvokeFake(client, 9);
}

public AMSResult FAKE10_CanInvoke(int client, int index)
{
	return Global_CanInvokeFake(client, 10);
}

AMSResult Global_CanInvokeFake(int client, int vidx)
{
	FF2Prep player = FF2Prep(client);
	int boss = player.boss;
	int temp;
	
	if(iPlayers[client][min][vidx] || iPlayers[client][max][vidx])
	{
		temp = GetClientTeam(client) == FF2_GetBossTeam() ? Players : Bosses;
		if (iPlayers[client][max][vidx] && iPlayers[client][max][vidx] < temp)
			return AMS_Deny;

		if (iPlayers[client][min][vidx] && iPlayers[client][min][vidx] > temp)
			return AMS_Deny;
	}
	
	if(flHealth[client][min][vidx] || flHealth[client][max][vidx])
	{
		temp = FF2_GetBossHealth(boss)/FF2_GetBossMaxLives(boss);
		float temp2 = view_as<float>(FF2_GetBossMaxHealth(boss));
		if (flHealth[client][min][vidx] && flHealth[client][max][vidx] < temp / temp2 * 100.0)
			return AMS_Deny;

		if (flHealth[client][min][vidx] && flHealth[client][max][vidx] > temp / temp2 * 100.0)
			return AMS_Deny;
	}
	
	if(iDeads[client][min][vidx] || iDeads[client][max][vidx])
	{
		temp = 0;
		TFTeam merc = TF2_GetClientTeam(client) == TFTeam_Red ? TFTeam_Blue : TFTeam_Red;
		for(int target=1; target<=MaxClients; target++)
		{
			if(IsClientInGame(target)) {
				if (TF2_GetClientTeam(target) == merc && !IsPlayerAlive(target))
					temp++;
			}
		}

		if (iDeads[client][max][vidx] && iDeads[client][max][vidx] < temp)
			return AMS_Deny;

		if (iDeads[client][min][vidx] && iDeads[client][min][vidx] > temp)
			return AMS_Deny;
	}

	if(iLives[client][min][vidx] || iLives[client][max][vidx])
	{
		temp = FF2_GetBossLives(FF2_GetBossIndex(client));
		if (iLives[client][max][vidx] && iLives[client][max][vidx] < temp)
			return AMS_Deny;

		if (iLives[client][min][vidx] && iLives[client][min][vidx] > temp)
			return AMS_Deny;
	}
	
	if(iMinions[client][max][vidx] || iMinions[client][min][vidx])
	{
		temp = GetClientTeam(client) == FF2_GetBossTeam() ? Bosses - 1 : Players - 1;
		if (iMinions[client][max][vidx] && iMinions[client][max][vidx] < temp)
			return AMS_Deny;

		if (iMinions[client][min][vidx] && iMinions[client][min][vidx] > temp)
			return AMS_Deny;
	}
	
	return AMS_Accept;
}

public void FF2AMS_OnAbility(int client, int index, const char[] plugin, const char[] ability)
{
	if(strcmp(plugin, this_plugin_name)) {
		return;
	}
	
	FF2Prep player = FF2Prep(client);
	int vidx; Fake_AMSMap[client].GetValue(ability, vidx);
	char actual_plugin_name[48]; FF2AMS_GetAMSHashMap(client, vidx).GetString("this_plugin2", actual_plugin_name, sizeof(actual_plugin_name));
	
	player.DoAbility(.plugin = actual_plugin_name, .ability = ability);
}

public void FF2_OnAlivePlayersChanged(int players, int bosses)
{
	Players = players;
	Bosses = bosses;
}

void Fast_Format(const int client, int __vidx)
{
	char __key[24];
	FAST_FORMAT_TO_HOOK("min->players")
	iPlayers[client][min][__vidx] = GlobalMap[client].GetInt(__key);
	FAST_FORMAT_TO_HOOK("min->health")
	flHealth[client][min][__vidx] = GlobalMap[client].GetFloat(__key);
	FAST_FORMAT_TO_HOOK("min->kills")
	iDeads[client][min][__vidx] = GlobalMap[client].GetInt(__key);
	FAST_FORMAT_TO_HOOK("min->lives")
	iLives[client][min][__vidx] = GlobalMap[client].GetInt(__key);
	FAST_FORMAT_TO_HOOK("min->minions")
	iMinions[client][min][__vidx] = GlobalMap[client].GetInt(__key);
	
	FAST_FORMAT_TO_HOOK("max->players")
	iPlayers[client][max][__vidx] = GlobalMap[client].GetInt(__key);
	FAST_FORMAT_TO_HOOK("max->health")
	flHealth[client][max][__vidx] = GlobalMap[client].GetFloat(__key);
	FAST_FORMAT_TO_HOOK("max->kills")
	iDeads[client][max][__vidx] = GlobalMap[client].GetInt(__key);
	FAST_FORMAT_TO_HOOK("max->lives")
	iLives[client][max][__vidx] = GlobalMap[client].GetInt(__key);
	FAST_FORMAT_TO_HOOK("max->minions")
	iMinions[client][max][__vidx] = GlobalMap[client].GetInt(__key);
}
