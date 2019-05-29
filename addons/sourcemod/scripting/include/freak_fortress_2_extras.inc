#if defined _FF2_Extras_included
 #endinput
#endif
#define _FF2_Extras_included

#include <tf2_stocks>
#include <tf2items>

#if !defined MAX_EDICT_BITS
	#define	MAX_EDICT_BITS	11
#endif

#if !defined MAX_EDICTS
	#define	MAX_EDICTS		(1 << MAX_EDICT_BITS)
#endif

enum BossType
{
	BossType_None=-1,
	BossType_Bosses,
	BossType_Minions
}

enum FF2Difficulty
{
    FF2Difficulty_Unknown=-1,
    FF2Difficulty_Normal=1,
    FF2Difficulty_Hard,
    FF2Difficulty_Lunatic,
    FF2Difficulty_Insane,
}

/**
 * Make a weapon or wearable visible to everyone
 **/
stock PrepareItem(client, entity, const String:classname[], visibility=false)
{
	if(!visibility)
	{
		SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
	}
	else
	{
		SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", 1); // Magic!
	}
	
	if (StrContains(classname, "tf_wearable")==-1)
	{
		EquipPlayerWeapon(client, entity);
	}
	else
	{
		Wearable_EquipWearable(client, entity);
	}
}

/**
 *	Make a weapon visible to everyone
 **/
stock PrepareWeapon(client, weapon, visibility=false)
{
	if(!visibility)
	{
		SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(weapon, Prop_Send, "m_flModelScale", 0.001);
	}
	else
	{
		SetEntProp(weapon, Prop_Send, "m_bValidatedAttachedEntity", 1); // Magic!
	}
	EquipPlayerWeapon(client, weapon);
}

Handle S93SF_equipWearable = null;
stock void Wearable_EquipWearable(int client, int wearable)
{
	if(S93SF_equipWearable==null)
	{
		Handle config=LoadGameConfigFile("equipwearable");
		if(config==null)
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

stock CreateAttachedAnnotation(client, entity, bool:effect=true, Float:time, String:buffer[], any:...)
{
    decl String:message[512];
    SetGlobalTransTarget(client);
    VFormat(message, sizeof(message), buffer, 6);
    ReplaceString(message, sizeof(message), "\n", "");  //Get rid of newlines
    
    new Handle:event = CreateEvent("show_annotation");
    if(event == INVALID_HANDLE)
    {
        return -1;
    }
    SetEventInt(event, "follow_entindex", entity);  
    SetEventFloat(event, "lifetime", time);
    SetEventInt(event, "visibilityBitfield", (1<<client));
    SetEventBool(event,"show_effect", effect);
    SetEventString(event, "text", message);
    SetEventInt(event, "id", entity); //What to enter inside? Need a way to identify annotations by entindex!
    FireEvent(event);
    return entity;
}

stock bool ShowGameText(int client, const char[] icon="leaderboard_streak", color=0, const char[] buffer, any ...)
{
    Handle bf;
    if(!client)
    {
        bf=StartMessageAll("HudNotifyCustom");
    }
    else
    {
        bf = StartMessageOne("HudNotifyCustom", client);
    }
    
    if(bf==null)
    {
        return false;
    }
    
    char message[512];
    SetGlobalTransTarget(client);
    VFormat(message, sizeof(message), buffer, 5);
    ReplaceString(message, sizeof(message), "\n", "");
    
    BfWriteString(bf, message);
    BfWriteString(bf, icon);
    BfWriteByte(bf, color);
    EndMessage();
    return true;
}

stock bool IsValidClient(int client, bool lifecheck=false)
{
    if(client<=0 || client>MaxClients) return false;
    return lifecheck ? IsClientInGame(client) && IsPlayerAlive(client) : IsClientInGame(client);
}

stock SpawnWeapon(client, String:name[], index, level, quality, String:attribute[], visible = 1, bool:preserve = false)
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

	new Handle:weapon = TF2Items_CreateItem((preserve ? PRESERVE_ATTRIBUTES : OVERRIDE_ALL) | FORCE_GENERATION);
	TF2Items_SetClassname(weapon, name);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, quality);
	new String:attributes[32][32];
	new count = ExplodeString(attribute, ";", attributes, 32, 32);
	if(count%2!=0)
	{
		count--;
	}
	
	if(count>0)
	{
		TF2Items_SetNumAttributes(weapon, count/2);
		new i2 = 0;
		for(new i = 0; i < count; i += 2)
		{
			new attrib = StringToInt(attributes[i]);
			if (attrib == 0)
			{
				LogError("Bad weapon attribute passed: %s ; %s", attributes[i], attributes[i+1]);
				return -1;
			}
			TF2Items_SetAttribute(weapon, i2, attrib, LibraryExists("tf2x10") ? StringToFloat(attributes[i+1])*10.0 : StringToFloat(attributes[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(weapon, 0);
	}

	if (weapon == INVALID_HANDLE)
	{
		PrintToServer("[sarysapub1] Error: Invalid weapon spawned. client=%d name=%s idx=%d attr=%s", client, name, index, attribute);
		return -1;
	}

	new entity = TF2Items_GiveNamedItem(client, weapon);
	CloseHandle(weapon);
	
	PrepareItem(client, entity, name, visible);
	
	return entity;
}
