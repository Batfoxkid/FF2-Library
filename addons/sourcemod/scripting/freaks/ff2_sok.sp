#pragma semicolon 1

#include <sourcemod>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <tf2_stocks>

#pragma newdecls required

public Plugin myinfo=
{
	name        = "Freak Fortress 2: Sound On Kill",
	author      = "Deathreus",
	description = "Emits the sound to only the recipient",
	version     = "1.0",
};

#define MAX_SOUND_FILE_LENGTH 80
#define MAX_RAGE_SOUNDS 5

char g_sRageSound[MAX_RAGE_SOUNDS][MAX_SOUND_FILE_LENGTH];
int BossTeam = view_as<int>(TFTeam_Blue);

public void OnPluginStart2()
{
	HookEvent("player_death", Event_PlayerDeath);
}

public void FF2_OnAbility2(int iClient, const char[] plugin_name, const char[] ability_name, int iStatus)
{
	// Will do nothing, but compiler needs it
}

public Action Event_PlayerDeath(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	if (GetEventInt(hEvent, "death_flags") & TF_DEATHFLAG_DEADRINGER)
		return Plugin_Continue;
	int iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int a_index = FF2_GetBossIndex(iAttacker);
	if(iVictim != -1)
	{
		if(FF2_HasAbility(a_index, this_plugin_name, "kill_sound"))
		{
			ReadSounds(a_index, "kill_sound", 1);
			if(GetClientTeam(iVictim) != BossTeam && IsValidClient(iVictim))
				EmitRandomClientSound(iVictim);
		}
	}
	return Plugin_Continue;
}

stock bool IsValidClient(int iClient)
{
	if(iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return false;

	if(IsClientSourceTV(iClient) || IsClientReplay(iClient))
		return false;

	return true;
}

void ReadSounds(int iClient, const char[] ability_name, int iArg)
{
	static char strSound[(MAX_SOUND_FILE_LENGTH + 1) * MAX_RAGE_SOUNDS];
	FF2_GetAbilityArgumentString(iClient, this_plugin_name, ability_name, iArg, strSound, sizeof(strSound));
	ExplodeString(strSound, ";", g_sRageSound, MAX_RAGE_SOUNDS, MAX_SOUND_FILE_LENGTH);
	for (int i = 0; i < MAX_RAGE_SOUNDS; i++)
		if (strlen(g_sRageSound[i]) > 3)
			PrecacheSound(g_sRageSound[i]);
}

void EmitRandomClientSound(int iClient)
{
	int count = 0;
	for (int i = 0; i < MAX_RAGE_SOUNDS; i++)
		if (strlen(g_sRageSound[i]) > 3)
			count++;
			
	if (count == 0)
		return;
		
	int rand = GetRandomInt(0, count-1);
	if (strlen(g_sRageSound[rand]) > 3)
	{
		EmitSoundToClient(iClient, g_sRageSound[rand]);
	}
}