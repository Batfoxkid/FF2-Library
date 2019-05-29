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

#define SOUND_SCT_LIFE			"freak_fortress_2/somecleantrash/sct_second_live.mp3"		// life lost, will be stopped when round ends
new g_sct_life;
new sct_boss;
#define SCT "somecleantrash_themechange"
#define INACTIVE 100000000.0

#define SOMECLEANTRASH_MADMILK "somecleantrash_stunning_madmilk"
new bool:MadMilk_CanUse;
new Float:StunDuration;

public Plugin:myinfo = {
	name	= "Freak Fortress 2: Abilities for SomeCleanTrash",
	author	= "M7",
	version = "1.0",
};

public OnPluginStart2()
{
	HookEvent("teamplay_round_start", event_round_start, EventHookMode_PostNoCopy);
	
	HookEvent("teamplay_round_active", event_round_active, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", event_round_active, EventHookMode_PostNoCopy);
	
	HookEvent("teamplay_round_win", event_round_end, EventHookMode_PostNoCopy);
	
	PrecacheSound(SOUND_SCT_LIFE);
}

public event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
	
	g_sct_life = 0;
	sct_boss = 0;
	MadMilk_CanUse = false;
}

public TF2_OnConditionAdded(client, TFCond:condition)
{
    if((condition == TFCond_Milked || condition == TFCond_Jarated || condition == TFCond_Gas) && MadMilk_CanUse && GetClientTeam(client)!=FF2_GetBossTeam())
    {
		TF2_RemoveCondition(client, TFCond_Jarated);
		TF2_RemoveCondition(client, TFCond_Milked);
		TF2_RemoveCondition(client, TFCond_Gas);
		
		TF2_StunPlayer(client, StunDuration, 0.0, TF_STUNFLAGS_NORMALBONK);	
    }
}

public event_round_active(Handle:event, const String:name[], bool:dontBroadcast)
{
	GetBossVars();
}

GetBossVars()
{
	if (FF2_HasAbility(0, this_plugin_name, SCT))
	{
		new userid = FF2_GetBossUserId(0);
		new client = GetClientOfUserId(userid);
		if (client && IsClientInGame(client) && IsPlayerAlive(client))
		{
			sct_boss = client;
			return;
		}
	}
	
	sct_boss = 0;
}

public event_round_end(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			g_sct_life = 0;
			sct_boss = 0;
			MadMilk_CanUse = false;
			StopSound(client, SNDCHAN_AUTO, SOUND_SCT_LIFE);
		}
	}
}

public Action:FF2_OnAbility2(bossIdx, const String:plugin_name[], const String:ability_name[], status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue; // Because some FF2 forks still allow RAGE to be activated when the round is over....
		
	new clientIdx=GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	if(FF2_HasAbility(bossIdx, this_plugin_name, SOMECLEANTRASH_MADMILK))
	{
		decl String:attributes[256], String:classname[64];
				
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SOMECLEANTRASH_MADMILK, 1, classname, sizeof(classname));
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SOMECLEANTRASH_MADMILK, 2, attributes, sizeof(attributes));
				
		TF2_RemoveWeaponSlot(clientIdx, TFWeaponSlot_Secondary);

		new index=FF2_GetAbilityArgument(bossIdx, this_plugin_name, SOMECLEANTRASH_MADMILK, 3);
		new weapon=SpawnWeapon(clientIdx, classname, index, 101, 5, attributes, bool:FF2_GetAbilityArgument(bossIdx, this_plugin_name, SOMECLEANTRASH_MADMILK, 4));
		FF2_SetAmmo(clientIdx, weapon, 1, 1);
				
		MadMilk_CanUse = true;
		Float:StunDuration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SOMECLEANTRASH_MADMILK, 5);
	}
	
	return Plugin_Continue;
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

public Action:FF2_OnLoseLife(index)
{		
	if (!g_sct_life && sct_boss && GetClientOfUserId(FF2_GetBossUserId(index)) == sct_boss && IsPlayerAlive(sct_boss))
	{		
		FF2_StopMusic(0);
		
		EmitSoundToAll(SOUND_SCT_LIFE);
		
		g_sct_life++;
	}
	return Plugin_Continue;
}

public Action:FF2_OnMusic(String:path[], &Float:time)
{
	if (g_sct_life)
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

stock bool:IsValidClient(client, bool:isPlayerAlive=false)
{
	if (client <= 0 || client > MaxClients) return false;
	if(isPlayerAlive) return IsClientInGame(client) && IsPlayerAlive(client);
	return IsClientInGame(client);
}