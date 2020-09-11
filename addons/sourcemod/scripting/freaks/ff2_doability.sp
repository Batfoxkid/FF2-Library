#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <tf2items>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <ff2_ams>

#pragma newdecls required

#define ABILITYRAGE	"rage_doability"
#define ABILITY		"ams_doability"
#define SOUNDRAGE	"sound_doability"
#define SOUND		"sound_doability_"
#define MAXTF2PLAYERS	36	// 32 players + console + 2 tvs + 1
#define MAXABILITYNAME	32
#define MAXPLUGINNAME	32
#define MAXARGNAME	32
#define MAXSOUNDNAME	32
#define MAXSOUNDPATH	80
#define MAXPREFIXNAME	6	// 5 limit + 1
#define MAXABILITIES	12	// 10 ams + 1 rage + 1
#define MAXRAGES	10	// 10 rages
#define LESSLOAD	false

bool UnofficialFF2;

// FF2_DoAbility Arguments
char AbilityName[MAXTF2PLAYERS][MAXABILITIES][MAXRAGES][MAXABILITYNAME];	// argX1
char PluginName[MAXTF2PLAYERS][MAXABILITIES][MAXRAGES][MAXPLUGINNAME];	// argX2
int AbilitySlot[MAXTF2PLAYERS][MAXABILITIES][MAXRAGES];			// argX3
int Buttonmode[MAXTF2PLAYERS][MAXABILITIES][MAXRAGES];			// argX4

// Requirements to use ability
int MinPlayers[MAXTF2PLAYERS][MAXABILITIES];	// arg101
int MaxPlayers[MAXTF2PLAYERS][MAXABILITIES];	// arg102
float MinHealth[MAXTF2PLAYERS][MAXABILITIES];	// arg103
float MaxHealth[MAXTF2PLAYERS][MAXABILITIES];	// arg104
int MinMinions[MAXTF2PLAYERS][MAXABILITIES];	// arg105
int MaxMinions[MAXTF2PLAYERS][MAXABILITIES];	// arg106
int MinDead[MAXTF2PLAYERS][MAXABILITIES];	// arg107
int MaxDead[MAXTF2PLAYERS][MAXABILITIES];	// arg108
int MinLives[MAXTF2PLAYERS][MAXABILITIES];	// arg109
int MaxLives[MAXTF2PLAYERS][MAXABILITIES];	// arg110

// Global Variables
int Players;
int Bosses;
bool UsingAbility[MAXTF2PLAYERS]/*[MAXABILITIES]*/;
char SoundNames[MAXABILITIES][MAXSOUNDPATH];

public Plugin myinfo =
{
	name		=	"Freak Fortress 2: AMS Do Ability",
	author		=	"Batfoxkid",
	description	=	"A way for non-ams abilities to use the Ability Management System",
	version		=	"1.1.1"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	#if defined _FFBAT_included
	MarkNativeAsOptional("FF2_EmitVoiceToAll");
	MarkNativeAsOptional("FF2_GetForkVersion");
	#endif
	return APLRes_Success;
}

public void OnPluginStart2()
{
	int version[3];
	FF2_GetFF2Version(version);
	if(version[0] != 1)
		SetFailState("This subplugin is only for FF2 v1.0 versions!");

	#if defined _FFBAT_included
	if(version[1] > 10)
	{
		FF2_GetForkVersion(version);
		//if(version[0]==1 && (version[1]>18 || (version[1]==18 && version[2]>5)))	Unofficial never had an official
		if(version[0] && version[1])	// version of 1.11 until it's 1.19, by that time everything here is included
			UnofficialFF2 = true;
	}
	#endif

	HookEvent("arena_round_start", OnRoundStart, EventHookMode_PostNoCopy);
	if(FF2_IsFF2Enabled() && FF2_GetRoundState()==1)
		OnRoundStart(view_as<Event>(INVALID_HANDLE), "plugin_lateload", false);

	for(int ability; ability<(MAXABILITIES-1); ability++)
	{
		Format(SoundNames[ability], MAXSOUNDPATH, "%s%i", SOUND, ability);
	}
}

// TF2 Events

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(!FF2_IsFF2Enabled())
		return;

	char abilityFormat[MAXABILITYNAME], abilityArg[MAXARGNAME], abilityPrefix[MAXPREFIXNAME];
	int client;
	for(int boss; boss<=MaxClients; boss++)
	{
		client = GetClientOfUserId(FF2_GetBossUserId(boss));
		if(!IsValidClient(client))
			continue;

		for(int ability; ability<MAXABILITIES; ability++)
		{
			if(!ability)
			{
				Format(abilityFormat, MAXABILITYNAME, ABILITYRAGE);
			}
			else
			{
				Format(abilityFormat, MAXABILITYNAME, "%s%i", ABILITY, ability-1);
			}

			if(FF2_HasAbility(boss, this_plugin_name, abilityFormat))
			{
				for(int rage; rage<MAXRAGES; rage++)
				{
					Format(abilityArg, MAXARGNAME, "ability%i", rage+1);
					FF2_GetArgS(boss, this_plugin_name, abilityFormat, abilityArg, (rage*10)+1, AbilityName[client][ability][rage], MAXABILITYNAME);
					Format(abilityArg, MAXARGNAME, "plugin%i", rage+1);
					FF2_GetArgS(boss, this_plugin_name, abilityFormat, abilityArg, (rage*10)+2, PluginName[client][ability][rage], MAXABILITYNAME);
				}

				if(ability)
				{
					if(AMS_IsSubabilityReady(boss, this_plugin_name, abilityFormat))
					{
	#if MAXABILITIES>10
						if(ability < 10)
						{
							Format(abilityPrefix, MAXPREFIXNAME, "D0%i", ability);
						}
						else
						{
							Format(abilityPrefix, MAXPREFIXNAME, "D%i", ability);
						}
	#else
						Format(abilityPrefix, MAXPREFIXNAME, "D0%i", ability);
	#endif
						AMS_InitSubability(boss, client, this_plugin_name, abilityFormat, abilityPrefix);
					}
					else
					{
	#if LESSLOAD
						break;
	#else
						continue;
	#endif
					}
				}

				for(int rage; rage<MAXRAGES; rage++)
				{
					Format(abilityArg, MAXARGNAME, "slot%i", rage+1);
					AbilitySlot[client][ability][rage] = FF2_GetArgI(boss, this_plugin_name, abilityFormat, abilityArg, (rage*10)+3);
					if(!AbilitySlot[client][ability][rage])
						AbilitySlot[client][ability][rage] = -1;

					Format(abilityArg, MAXARGNAME, "button%i", rage+1);
					Buttonmode[client][ability][rage] = FF2_GetArgI(boss, this_plugin_name, abilityFormat, abilityArg, (rage*10)+4);
				}

				MinPlayers[client][ability] = FF2_GetArgI(boss, this_plugin_name, abilityFormat, "alive min", 101);
				MaxPlayers[client][ability] = FF2_GetArgI(boss, this_plugin_name, abilityFormat, "alive max", 102);
				MinHealth[client][ability] = FF2_GetArgF(boss, this_plugin_name, abilityFormat, "health min", 103);
				MaxHealth[client][ability] = FF2_GetArgF(boss, this_plugin_name, abilityFormat, "health max", 104);
				MinMinions[client][ability] = FF2_GetArgI(boss, this_plugin_name, abilityFormat, "clone min", 105);
				MaxMinions[client][ability] = FF2_GetArgI(boss, this_plugin_name, abilityFormat, "clone max", 106);
				MinDead[client][ability] = FF2_GetArgI(boss, this_plugin_name, abilityFormat, "dead min", 107);
				MaxDead[client][ability] = FF2_GetArgI(boss, this_plugin_name, abilityFormat, "dead max", 108);
				MinLives[client][ability] = FF2_GetArgI(boss, this_plugin_name, abilityFormat, "life min", 109);
				MaxLives[client][ability] = FF2_GetArgI(boss, this_plugin_name, abilityFormat, "life max", 110);
			}
	#if LESSLOAD
			else if(ability)
			{
				break;
			}
	#endif
		}
	}
}

// FF2 Events

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int action)
{
	if(!strcmp(ability_name, ABILITYRAGE))
	{
		int client = GetClientOfUserId(FF2_GetBossUserId(boss));
		if(!Global_CanInvoke(client, 0))
			return Plugin_Continue;

		/*DataPack data;
		CreateDataTimer(0.3, ResetUsedAbility, data, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(data, FF2_GetBossIndex(client));
		WritePackCell(data, 0);*/

		UsingAbility[boss] = true;
		CreateTimer(0.2, ResetUsedAbility, boss, TIMER_FLAG_NO_MAPCHANGE);

		char sound[MAXSOUNDPATH];
		if(FF2_RandomSound(SOUNDRAGE, sound, MAXSOUNDPATH, boss))
			EmitVoiceToAll(sound);

		char pluginName[MAXPLUGINNAME], abilityName[MAXABILITYNAME];
		for(int rage; rage<MAXRAGES; rage++)
		{
			strcopy(pluginName, MAXPLUGINNAME, PluginName[client][0][rage]);
			strcopy(abilityName, MAXABILITYNAME, AbilityName[client][0][rage]);
			if(!strlen(pluginName) || !strlen(abilityName))
		#if LESSLOAD
				break;
		#else
				continue;
		#endif
			FF2_DoAbility(boss, pluginName, abilityName, AbilitySlot[client][0][rage], Buttonmode[client][0][rage]);
		}
	}
	return Plugin_Continue;
}

public void FF2_OnAlivePlayersChanged(int players, int bosses)
{
	Players = players;
	Bosses = bosses;
}

public void FF2_PreAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, bool &enabled)
{
	if(UsingAbility[boss])
		return;

	if(FF2_HasAbility(boss, this_plugin_name, ABILITYRAGE))
	{
		//if(UsingAbility[boss][0])
			//return;

		int client = GetClientOfUserId(FF2_GetBossUserId(boss));
		char pluginName2[MAXPLUGINNAME], abilityName2[MAXABILITYNAME], argName[MAXABILITYNAME];
		for(int rage; rage<MAXRAGES; rage++)
		{
			strcopy(pluginName2, MAXPLUGINNAME, PluginName[client][0][rage]);
			strcopy(abilityName2, MAXABILITYNAME, AbilityName[client][0][rage]);
			Format(argName, MAXARGNAME, "block%i", rage+1);
			if(StrEqual(pluginName, pluginName2, false) && StrEqual(abilityName, abilityName2, false) && FF2_GetArgI(boss, this_plugin_name, ABILITYRAGE, argName, (rage*10)+5, 1))
			{
				enabled = false;
				return;
			}
		}
		return;
	}

	char abilityFormat[MAXABILITYNAME];
	for(int ability=1; ability<MAXABILITIES; ability++)
	{
		//if(UsingAbility[boss][ability])
			//return;

		Format(abilityFormat, MAXABILITYNAME, "%s%i", ABILITY, ability-1);
		if(FF2_HasAbility(boss, this_plugin_name, abilityFormat))
		{
			int client = GetClientOfUserId(FF2_GetBossUserId(boss));
			char pluginName2[MAXPLUGINNAME], abilityName2[MAXABILITYNAME];
			for(int rage; rage<MAXRAGES; rage++)
			{
				strcopy(pluginName2, MAXPLUGINNAME, PluginName[client][ability][rage]);
				strcopy(abilityName2, MAXABILITYNAME, AbilityName[client][ability][rage]);
				Format(abilityFormat, MAXARGNAME, "block%i", rage+1);
				if(StrEqual(pluginName, pluginName2, false) && StrEqual(abilityName, abilityName2, false) && FF2_GetArgI(boss, this_plugin_name, ABILITYRAGE, abilityFormat, (rage*10)+5, 1))
				{
					enabled = false;
					return;
				}
			}
		}
	}
}

// AMS Events

#if MAXABILITIES>1
public bool D01_CanInvoke(int client)
{
	return Global_CanInvoke(client, 1);
}

public void D01_Invoke(int client)
{
	Global_Invoke(client, 1);
}
#endif

#if MAXABILITIES>2
public bool D02_CanInvoke(int client)
{
	return Global_CanInvoke(client, 2);
}

public void D02_Invoke(int client)
{
	Global_Invoke(client, 2);
}
#endif

#if MAXABILITIES>3
public bool D03_CanInvoke(int client)
{
	return Global_CanInvoke(client, 3);
}

public void D03_Invoke(int client)
{
	Global_Invoke(client, 3);
}
#endif

#if MAXABILITIES>4
public bool D04_CanInvoke(int client)
{
	return Global_CanInvoke(client, 4);
}

public void D04_Invoke(int client)
{
	Global_Invoke(client, 4);
}
#endif

#if MAXABILITIES>5
public bool D05_CanInvoke(int client)
{
	return Global_CanInvoke(client, 5);
}

public void D05_Invoke(int client)
{
	Global_Invoke(client, 5);
}
#endif

#if MAXABILITIES>6
public bool D06_CanInvoke(int client)
{
	return Global_CanInvoke(client, 6);
}

public void D06_Invoke(int client)
{
	Global_Invoke(client, 6);
}
#endif

#if MAXABILITIES>7
public bool D07_CanInvoke(int client)
{
	return Global_CanInvoke(client, 7);
}

public void D07_Invoke(int client)
{
	Global_Invoke(client, 7);
}
#endif

#if MAXABILITIES>8
public bool D08_CanInvoke(int client)
{
	return Global_CanInvoke(client, 8);
}

public void D08_Invoke(int client)
{
	Global_Invoke(client, 8);
}
#endif

#if MAXABILITIES>9
public bool D09_CanInvoke(int client)
{
	return Global_CanInvoke(client, 9);
}

public void D09_Invoke(int client)
{
	Global_Invoke(client, 9);
}
#endif

#if MAXABILITIES>10
public bool D10_CanInvoke(int client)
{
	return Global_CanInvoke(client, 10);
}

public void D10_Invoke(int client)
{
	Global_Invoke(client, 10);
}
#endif

#if MAXABILITIES>11
public bool D11_CanInvoke(int client)
{
	return Global_CanInvoke(client, 11);
}

public void D11_Invoke(int client)
{
	Global_Invoke(client, 11);
}
#endif

// Plugin Events

public bool Global_CanInvoke(int client, int abililty)
{
	int tempInteger;
	if(MaxPlayers[client][abililty] || MinPlayers[client][abililty])
	{
		tempInteger = GetClientTeam(client)==FF2_GetBossTeam() ? Players : Bosses;
		if(MaxPlayers[client][abililty] && MaxPlayers[client][abililty]<tempInteger)
			return false;

		if(MinPlayers[client][abililty] && MinPlayers[client][abililty]>tempInteger)
			return false;
	}

	if(MaxHealth[client][abililty] || MinHealth[client][abililty])
	{
		tempInteger = FF2_GetBossHealth(FF2_GetBossIndex(client))/FF2_GetBossMaxLives(FF2_GetBossIndex(client));
		float tempFloat = float(FF2_GetBossMaxHealth(FF2_GetBossIndex(client)));
		if(MaxHealth[client][abililty] && MaxHealth[client][abililty]<tempInteger/tempFloat*100.0)
			return false;

		if(MinHealth[client][abililty] && MinHealth[client][abililty]>tempInteger/tempFloat*100.0)
			return false;
	}

	if(MaxMinions[client][abililty] || MinMinions[client][abililty])
	{
		tempInteger = GetClientTeam(client)==FF2_GetBossTeam() ? Bosses-1 : Players-1;
		if(MaxMinions[client][abililty] && MaxMinions[client][abililty]<tempInteger)
			return false;

		if(MinMinions[client][abililty] && MinMinions[client][abililty]>tempInteger)
			return false;
	}

	if(MaxDead[client][abililty] || MinDead[client][abililty])
	{
		tempInteger = 0;
		TFTeam mercTeam = TF2_GetClientTeam(client)==TFTeam_Red ? TFTeam_Blue : TFTeam_Red;
		for(int target=1; target<=MaxClients; target++)
		{
			if(IsClientInGame(target))
			{
				if(TF2_GetClientTeam(target)==mercTeam && !IsPlayerAlive(target))
					tempInteger++;
			}
		}

		if(MaxDead[client][abililty] && MaxDead[client][abililty]<tempInteger)
			return false;

		if(MinDead[client][abililty] && MinDead[client][abililty]>tempInteger)
			return false;
	}

	if(MaxLives[client][abililty] || MinLives[client][abililty])
	{
		tempInteger = FF2_GetBossLives(FF2_GetBossIndex(client));
		if(MaxLives[client][abililty] && MaxLives[client][abililty]<tempInteger)
			return false;

		if(MinLives[client][abililty] && MinLives[client][abililty]>tempInteger)
			return false;
	}

	return true;
}

public void Global_Invoke(int client, int abililty)
{
	int boss = FF2_GetBossIndex(client);
	UsingAbility[boss] = true;
	CreateTimer(0.2, ResetUsedAbility, boss, TIMER_FLAG_NO_MAPCHANGE);

	char sound[MAXSOUNDPATH];
	if(FF2_RandomSound(SoundNames[abililty], sound, MAXSOUNDPATH, boss))
		EmitVoiceToAll(sound);

	char abilityName[MAXABILITYNAME];
	/*Format(abilityName, MAXABILITYNAME, "%s%i", ABILITY-1);
	FF2_SetBossCharge(boss, 0, FF2_GetBossCharge(boss, 0)+FF2_GetAbilityArgument(boss, this_plugin_name, abilityName, 1005));*/

	char pluginName[MAXPLUGINNAME];
	for(int rage; rage<MAXRAGES; rage++)
	{
		strcopy(pluginName, MAXPLUGINNAME, PluginName[client][abililty][rage]);
		strcopy(abilityName, MAXABILITYNAME, AbilityName[client][abililty][rage]);
		if(!strlen(pluginName) || !strlen(abilityName))
	#if LESSLOAD
			break;
	#else
			continue;
	#endif
		FF2_DoAbility(boss, pluginName, abilityName, AbilitySlot[client][abililty][rage], Buttonmode[client][abililty][rage]);
	}
}

//public Action ResetUsedAbility(Handle timer, any pack)
public Action ResetUsedAbility(Handle timer, int boss)
{
	//UsingAbility[ReadPackCell(pack)][ReadPackCell(pack)] = false;
	UsingAbility[boss] = false;
}

// Stocks

stock bool IsValidClient(int client, bool replaycheck=true)
{
	if(client<=0 || client>MaxClients)
		return false;

	if(!IsClientInGame(client))
		return false;

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
		return false;

	if(replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
		return false;

	return true;
}

stock void EmitVoiceToAll(const char[] sample, int entity=SOUND_FROM_PLAYER)
{
	#if defined _FFBAT_included
	if(UnofficialFF2)
	{
		FF2_EmitVoiceToAll(sample, entity);
	}
	else
	{
		EmitSoundToAll(sample, entity);
	}
	#else
	EmitSoundToAll(sample, entity);
	#endif
}

#file "FF2 Subplugin: AMS Do Ability"
