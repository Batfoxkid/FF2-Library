#define FF2_USING_AUTO_PLUGIN__OLD

#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_ams2>

#pragma semicolon 1
#pragma newdecls required

#define CLIPLESS "rage_cliplessweapons"
bool Clipless_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS
char Attributes[125];
char Classname[64];

public Plugin myinfo = {
	name = "FF2 Ability: Customizable Clipless Weapons",
	author = "M7",
};

public void OnPluginStart2()
{
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_Pre);
}

public void FF2AMS_PreRoundStart(int client)
{
	int boss = FF2_GetBossIndex(client);
	if(FF2_HasAbility(boss, this_plugin_name, CLIPLESS))
	{
		Clipless_TriggerAMS[client]= FF2_GetAbilityArgument(boss, this_plugin_name, CLIPLESS, 7) != 0
								&& FF2AMS_PushToAMS(client, this_plugin_name, CLIPLESS, "CLIP");
	}
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			Clipless_TriggerAMS[client]=false;
		}
	}
}
			

public Action FF2_OnAbility2(int boss,const char[] plugin_name,const char[] ability_name, int action)
{
	int client=GetClientOfUserId(FF2_GetBossUserId(boss));
	
	if(!strcmp(ability_name, CLIPLESS))  // Vaccinator resistances
	{
		Rage_Cliplessweapons(client);
	}
	return Plugin_Continue;
}


void Rage_Cliplessweapons(int client)
{
	if(Clipless_TriggerAMS[client])
		return;
	
	CLIP_Invoke(client, 0);
}

public AMSResult CLIP_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void CLIP_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	
	int Index = FF2_GetAbilityArgument(boss, this_plugin_name, CLIPLESS, 1);	// weaponindex
	FF2_GetAbilityArgumentString(boss, this_plugin_name, CLIPLESS, 2, Classname, sizeof(Classname));	// weapon attribute
	FF2_GetAbilityArgumentString(boss, this_plugin_name, CLIPLESS, 3, Attributes, sizeof(Attributes));	// weapon classname
	int Ammo = FF2_GetAbilityArgument(boss, this_plugin_name, CLIPLESS, 5);	// weaponindex
	int slot = FF2_GetAbilityArgument(boss, this_plugin_name, CLIPLESS, 6);
	
	TF2_RemoveWeaponSlot(client, slot);
	
	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, Classname, Index, 100, 5, Attributes), FF2_GetAbilityArgument(boss, this_plugin_name, CLIPLESS, 4) != 0);
	
	if(Ammo)
	{
		SetAmmo(client, slot, Ammo);
	}
	
	if(Clipless_TriggerAMS[client])
	{
		char snd[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_clipless_weapon", snd, sizeof(snd), boss))
		{
			EmitSoundToAll(snd, client);
			EmitSoundToAll(snd, client);
		}		
	}
}

stock int SpawnWeapon(int client,char[] name, int index, int level, int qual, char[] att, bool isVisible=false)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	char atts[32][32];
	int count = ExplodeString(att, " ; ", atts, 32, 32);
	if (count > 0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		int i2 = 0;
		for (int i = 0; i < count; i+=2)
		{
			TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
			i2++;
		}
	}
	else
		TF2Items_SetNumAttributes(hWeapon, 0);
	if (hWeapon==INVALID_HANDLE)
		return -1;
	int entity = TF2Items_GiveNamedItem(client, hWeapon);
	delete hWeapon;
	
	if(!isVisible)
	{
		SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
	}
	#if defined _FF2_Extras_included
	else
	{
		PrepareWeapon(entity);
	}
	#endif	
	
	EquipPlayerWeapon(client, entity);
	return entity;
}

stock void SetAmmo(int client, int slot, int ammo)
{
	int weapon = GetPlayerWeaponSlot(client, slot);
	if (IsValidEntity(weapon))
	{
		int iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		static int iAmmoTable = 0;
		if(!iAmmoTable) {
			iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		}
		SetEntData(client, iAmmoTable+iOffset, ammo, 4, true);
	}
}

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients)
		return false;
		
	return IsClientInGame(client);
}
