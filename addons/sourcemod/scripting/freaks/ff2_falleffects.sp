#define FF2_USING_AUTO_PLUGIN__OLD

#include <tf2>
#include <freak_fortress_2>
#include <sdkhooks>

#pragma newdecls required

#define PLUGIN_AUTHOR "Naydef"
#define PLUGIN_VERSION "0.4"
// All the abilities are passive
#define ABILITY_1 "ff2_falleffectsound"
/*
	Ability 1 prototype in config:
	"ability1"
	{
		"name" "ff2_falleffectsound"
		"arg0" "0"    // Ignored
		"arg1" "1500" // Sound distance
		"arg2" "2"    // Number of sounds which will be emitted randomly. Here we have 2 sounds. Every sound has GetRandomInt(1, sound_number) chance of being selected. 
		"arg3" "sound\freak_fortress_2\some_good_sound.wav"
		"arg4" "sound\freak_fortress_2\some_other_good_sound.wav"
		"plugin_name" "ff2_falleffects"
	}
*/

#define ABILITY_2 "ff2_falleffectshake"
/*
	Ability 2 prototype in config:
	"ability1"
	{
		"name" "ff2_falleffectshake"
		"arg0" "0"    // Ignored
		"arg1" "1500" // Shake distance
		"arg2" "1"    // Is the boss going to be shaked also
		"arg3" "1.0"  // Shake amplitude
		"arg4" "10.0" // Shake duration - in seconds
		"arg5" "4.5"  // frequency
		"plugin_name" "ff2_falleffects"

	}
*/
#define ABILITY_3 "ff2_falleffectdamage"
/*
	Ability 3 prototype in config:
	"ability1"
	{
		"name" "ff2_falleffectdamage"
		"arg0" "0"    // Ignored
		"arg1" "1500" // Damage distance
		"arg2" "40"   // Amount of damage (This will take a formula in future version)
		"plugin_name" "ff2_falleffects"

	}
*/
#define ABILITY_4 "ff2_falleffectparticle" // Not now!


public Plugin myinfo =
{
	name = "[TF2] Freak Fortress 2: Fall Effects", 
	author = PLUGIN_AUTHOR,
	description = "Some nice effects when bosses fall from height.",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(!IsTF2())
	{
		strcopy(error, err_max, "This plugin is only for Team Fortress 2. Remove the plugin!");
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public void OnPluginStart2()
{
	for(int i=1; i<=MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			SDKHook(i, SDKHook_OnTakeDamagePost, Hook_OnTakeDamagePost);
		}
	}
}

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_OnTakeDamagePost, Hook_OnTakeDamagePost);
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int action) // Not used.
{
	return Plugin_Continue;
}

public void Hook_OnTakeDamagePost(int victim, int attacker, int inflictor, 
					float damage, int damagetype, int weapon,
					const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if(damagetype & DMG_FALL)
	{
		int bossindex=FF2_GetBossIndex(victim);
		if(bossindex==-1) return;
		if(FF2_HasAbility(bossindex, this_plugin_name, ABILITY_1))
		{
			char buffer[PLATFORM_MAX_PATH];
			int numberofsounds=FF2_GetAbilityArgument(bossindex, this_plugin_name, ABILITY_1, 2, -1);
			if(numberofsounds<=0)
			{
				FF2_GetBossSpecial(bossindex, buffer, sizeof(buffer), 0);
				LogError("[FF2 FallEffect Subplugin] Sounds less than 1 | Boss %s", buffer);
				return;
			}
			int random=GetRandomInt(1, numberofsounds);
			FF2_GetAbilityArgumentString(bossindex, this_plugin_name, ABILITY_1, 2+random , buffer, sizeof(buffer));
			if(!buffer[0])
			{
				FF2_GetBossSpecial(bossindex, buffer, sizeof(buffer), 0);
				LogError("[FF2 FallEffect Subplugin] Sound string is NULL! | Boss: %s", buffer);
				return;
			}
			char buffer1[PLATFORM_MAX_PATH];
			Format(buffer1, sizeof(buffer1), "sound/%s", buffer);
			if(!FileExists(buffer1))
			{
				FF2_GetBossSpecial(bossindex, buffer, sizeof(buffer), 0);
				LogError("[FF2 FallEffect Subplugin] Sound not found! | Sound: %s | Boss %s", buffer1, buffer);
				return;
			}
			PrecacheSound(buffer);
			int distance=FF2_GetAbilityArgument(bossindex, this_plugin_name, ABILITY_1, 1, -1);
			if(distance<=0)
			{
				EmitSoundToAll(buffer, victim, SNDCHAN_AUTO);
			}
			else
			{
				float PVectorBoss[3];
				float PVector[3];
				GetEntPropVector(victim, Prop_Send, "m_vecOrigin", PVectorBoss);
				for(int i=1; i<=MaxClients; i++)
				{
					if(IsValidClient(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", PVector);
						if(GetVectorDistance(PVectorBoss, PVector)<=distance)
						{
							EmitSoundToAll(buffer, victim, SNDCHAN_AUTO);
						}
					}
				}
			}
		}
		if(FF2_HasAbility(bossindex, this_plugin_name, ABILITY_2))
		{
			int distance=FF2_GetAbilityArgument(bossindex, this_plugin_name, ABILITY_2, 1, -1);
			int IsBossShaked=FF2_GetAbilityArgument(bossindex, this_plugin_name, ABILITY_2, 2, -1);
			float amplitude=FF2_GetAbilityArgumentFloat(bossindex, this_plugin_name, ABILITY_2, 3, -1.0);
			float duration=FF2_GetAbilityArgumentFloat(bossindex, this_plugin_name, ABILITY_2, 4, -1.0);
			float frequency=FF2_GetAbilityArgumentFloat(bossindex, this_plugin_name, ABILITY_2, 5, -1.0);
			if(distance<=0)
			{
				for(int i=1; i<=MaxClients; i++)
				{
					if(IsValidClient(i))
					{
						if(i==victim)
						{
							if(IsBossShaked)
							{
								ShakeScreen(i, amplitude, duration, frequency);
							}
							else
							{
								continue;
							}
						}
						else
						{
							ShakeScreen(i, amplitude, duration, frequency);
						}
						ShakeScreen(i, amplitude, duration, frequency)
					}
				}
			}
			else
			{
				float PVectorBoss[3];
				float PVector[3];
				GetEntPropVector(victim, Prop_Send, "m_vecOrigin", PVectorBoss);
				for(int i=1; i<=MaxClients; i++)
				{
					if(IsValidClient(i))
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", PVector);
						if(GetVectorDistance(PVectorBoss, PVector)<=distance)
						{
							if(i==victim)
							{
								if(IsBossShaked)
								{
									ShakeScreen(i, amplitude, duration, frequency);
								}
								else
								{
									continue;
								}
							}
							else
							{
								ShakeScreen(i, amplitude, duration, frequency);
							}
						}
					}
				}
			}
		}
		if(FF2_HasAbility(bossindex, this_plugin_name, ABILITY_3))
		{
			float PVectorBoss[3];
			float PVector[3];
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", PVectorBoss);
			float damagedist=FF2_GetAbilityArgumentFloat(bossindex, this_plugin_name, ABILITY_3, 1, -1.0);
			float pdamage=FF2_GetAbilityArgumentFloat(bossindex, this_plugin_name, ABILITY_3, 2, -1.0);
			if(pdamage<0.0)
			{
				char buffer[64];
				FF2_GetBossSpecial(bossindex, buffer, sizeof(buffer), 0);
				LogMessage("[FF2 FallEffect Subplugin] Negative damage?!?! | Boss: %s", buffer);
			}
			for(int i=1; i<=MaxClients; i++)
			{
				if(IsValidClient(i) && IsPlayerAlive(i) && FF2_GetBossIndex(i)==-1)
				{
					if(damagedist<=0)
					{
						SDKHooks_TakeDamage(i, victim, victim, pdamage, DMG_CLUB);
					}
					else
					{
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", PVector);
						if(GetVectorDistance(PVectorBoss, PVector)<=damagedist)
						{
							SDKHooks_TakeDamage(i, victim, victim, pdamage, DMG_CLUB);
						}
					}
				}
			}
		}
		if(FF2_HasAbility(bossindex, this_plugin_name, ABILITY_4))
		{
			char buffer[64];
			FF2_GetBossSpecial(bossindex, buffer, sizeof(buffer), 0);
			LogError("[FF2 FallEffect Subplugin] This version of the plugin does not support \"ff2_falleffectparticle\" ability! | Boss: %s", buffer);
		}
	}
}


stock bool IsValidClient(int client, bool replaycheck=true)//From Freak Fortress 2
{
	if(client<=0 || client>MaxClients)
	{
		return false;
	}

	if(!IsClientInGame(client))
	{
		return false;
	}

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
	{
		return false;
	}

	if(replaycheck)
	{
		if(IsClientSourceTV(client) || IsClientReplay(client))
		{
			return false;
		}
	}
	return true;
}

public void ShakeScreen(int client, float amplitude, float duration, float frequency)
{
	Handle usermessg=StartMessageOne("Shake", client);
	if(usermessg!=INVALID_HANDLE)
	{
		BfWriteByte(usermessg, 0);
		BfWriteFloat(usermessg, amplitude);
		BfWriteFloat(usermessg, frequency);
		BfWriteFloat(usermessg, duration);
		EndMessage();
	}
}

bool IsTF2()
{
	return (GetEngineVersion()==Engine_TF2) ?  true : false;
}
