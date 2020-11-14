#define FF2_USING_AUTO_PLUGIN__OLD

#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name	= "Freak Fortress 2: Timed Weapon Rage",
	author	= "Deathreus",
	version = "1.0"
};

int BossTeam = VSH2Team_Boss;

float WeaponTime[MAXPLAYERS+1];

public void OnPluginStart2() 
{
	
}

public void FF2_OnAbility2(int iIndex, const char[] pluginName, const char[] abilityName, int iStatus) {
	if (!strcmp(abilityName, "rage_timed_new_weapon"))
		Rage_Timed_New_Weapon(iIndex, abilityName);
}

void Rage_Timed_New_Weapon(int iBIndex, const char[] ability_name)
{
	int iBoss = GetClientOfUserId(FF2_GetBossUserId(iBIndex));
	static char sAttributes[256], sClassname[96];
	WeaponTime[iBoss] = FF2_GetAbilityArgumentFloat(iBIndex, this_plugin_name, ability_name, 8, 10.0);

	// Weapons classname
	FF2_GetAbilityArgumentString(iBIndex, this_plugin_name, ability_name, 1, sClassname, 96);
	// Attributes to apply to the weapon
	FF2_GetAbilityArgumentString(iBIndex, this_plugin_name, ability_name, 3, sAttributes, 256);

	// Slot of the weapon 0=Primary(Or sapper), 1=Secondary(Or spies revolver), 2=Melee, 3=PDA1(Build tool, disguise kit), 4=PDA2(Destroy tool, cloak), 5=Building
	int iSlot = FF2_GetAbilityArgument(iBIndex, this_plugin_name, ability_name, 4);
	TF2_RemoveWeaponSlot(iBoss, iSlot);
	
	int iIndex = FF2_GetAbilityArgument(iBIndex, this_plugin_name, ability_name, 2);
	
	bool bHide = FF2_GetAbilityArgument(iBIndex, this_plugin_name, ability_name, 9, 0) != 0;

	int iWep = SpawnWeapon(iBoss, sClassname, iIndex, 100, 5, sAttributes, bHide);
	
	// Make them equip it?
	if (FF2_GetAbilityArgument(iBIndex, this_plugin_name, ability_name, 7))
		SetEntPropEnt(iBoss, Prop_Send, "m_hActiveWeapon", iWep);
	
	int iAmmo = FF2_GetAbilityArgument(iBIndex, this_plugin_name, ability_name, 5, 0);
	int iClip = FF2_GetAbilityArgument(iBIndex, this_plugin_name, ability_name, 6, 0);
	if(iAmmo || iClip) FF2_SetAmmo(iBoss, iWep, iAmmo, iClip);

	if(WeaponTime[iBoss] > 0.0)
	{
		// Duration to keep the weapon, set to 0 or -1 to keep the weapon
		WeaponTime[iBoss] += GetEngineTime();
		SDKHook(iBoss, SDKHook_PreThink, Boss_Think);
	}
}

public void Boss_Think(int iBoss)
{
	if(GetEngineTime() >= WeaponTime[iBoss])
	{
		RemoveWeapons(iBoss);
		ApplyDefaultWeapons(iBoss);
		
		SDKUnhook(iBoss, SDKHook_PreThink, Boss_Think);
	}
}

stock void RemoveWeapons(int iClient)
{
	if (IsValidClient(iClient, true, true))
	{
		if(GetPlayerWeaponSlot(iClient, 0) != -1)
			TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Primary);
		
		if(GetPlayerWeaponSlot(iClient, 1) != -1)
			TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Secondary);
		
		if(GetPlayerWeaponSlot(iClient, 2) != -1)
			TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Melee);
		
		SwitchtoSlot(iClient, TFWeaponSlot_Melee);
	}
}

stock void SwitchtoSlot(int iClient, int iSlot)
{
	if (iSlot >= 0 && iSlot <= 5 && IsValidClient(iClient, true))
	{
		char sClassname[96];
		int iWep = GetPlayerWeaponSlot(iClient, iSlot);
		if (iWep > MaxClients && IsValidEdict(iWep) && GetEdictClassname(iWep, sClassname, sizeof(sClassname)))
		{
			FakeClientCommandEx(iClient, "use %s", sClassname);
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWep);
		}
	}
}

stock bool IsValidClient(int iClient, bool bAlive = false, bool bTeam = false)
{
	if(iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return false;

	if(IsClientSourceTV(iClient) || IsClientReplay(iClient))
		return false;
	
	if(bAlive && !IsPlayerAlive(iClient))
		return false;
	
	if(bTeam && GetClientTeam(iClient) != BossTeam)
		return false;

	return true;
}

// If startEnt isn't valid shifting it back to the nearest valid one
stock int FindEntityByClassname2(int startEnt, const char[] sClassname)
{
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
	return FindEntityByClassname(startEnt, sClassname);
}

stock int SpawnWeapon(int iClient, char[] sClassname, int iIndex, int iLevel, int iQuality, const char[] sAttribute = "", bool bHide = false)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if (hWeapon == INVALID_HANDLE)
		return -1;
		
	TF2Items_SetClassname(hWeapon, sClassname);
	TF2Items_SetItemIndex(hWeapon, iIndex);
	TF2Items_SetLevel(hWeapon, iLevel);
	TF2Items_SetQuality(hWeapon, iQuality);
	
	char sAttributes[32][32];
	int iCount = ExplodeString(sAttribute, " ; ", sAttributes, 32, 32);
	if (iCount % 2)
		--iCount;
		
	if (iCount > 0)
	{
		TF2Items_SetNumAttributes(hWeapon, iCount/2);
		int i2;
		for(int i; i < iCount; i += 2)
		{
			int iAttrib = StringToInt(sAttributes[i]);
			if (!iAttrib)
			{
				LogError("Bad weapon attribute passed: %s ; %s", sAttributes[i], sAttributes[i+1]);
				delete hWeapon;
				return -1;
			}
			TF2Items_SetAttribute(hWeapon, i2, iAttrib, StringToFloat(sAttributes[i+1]));
			i2++;
		}
	}
	else
		TF2Items_SetNumAttributes(hWeapon, 0);
		
	int iEntity = TF2Items_GiveNamedItem(iClient, hWeapon);
	EquipPlayerWeapon(iClient, iEntity);
	delete hWeapon;
	
	if (bHide)
	{
		SetEntProp(iEntity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", 0.0001);
	}
	
	return iEntity;
}

void ApplyDefaultWeapons(int iClient)
{
	if(!IsValidClient(iClient))
	{
		return;
	}
	FF2Player player = FF2Player(iClient);
	TF2_RemoveAllWeapons(iClient);

	static char key[48], attributes[256], weapon[64];
	int val;
	
	for(int j=1; ; j++)
	{
		Format(key, 10, "weapon%i.name", j);

		if(player.GetString(key, weapon, sizeof(weapon)))
		{
			Format(key, 10, "weapon%i.index", j);
			if(!player.GetInt(key, val))
				continue;
			
			Format(key, 10, "weapon%i.attributes", j);
			if(player.GetString(key, attributes, sizeof(attributes)))
			{
				Format(attributes, sizeof(attributes), "68 ; 2.0 ; 2 ; 3.1 ; %s", attributes);
					//68: +2 cap rate
					//2: x3.1 damage
			}
			else
			{
				Format(attributes, sizeof(attributes), "68 ; 2.0 ; 2 ; 3.1");
					//68: +2 cap rate
					//2: x3.1 damage
			}

			int BossWeapon=SpawnWeapon(iClient, weapon, val, 101, 5, attributes);
			
			Format(key, 10, "weapon%i.show", j);
			if(player.GetInt(key, val) && !val)
			{
				SetEntProp(BossWeapon, Prop_Send, "m_iWorldModelIndex", -1);
				SetEntPropFloat(BossWeapon, Prop_Send, "m_flModelScale", 0.0001);
			}
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", BossWeapon);
		}
		else
		{
			break;
		}
	}
}
