#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

public Plugin:myinfo = {
	name	= "Freak Fortress 2: Timed Weapon Rage",
	author	= "Deathreus",
	version = "1.0"
};

new BossTeam = _:TFTeam_Blue;

new Float:WeaponTime[MAXPLAYERS+1];

public OnPluginStart2() 
{
	HookEvent("arena_round_start", Event_RoundStart);
	LoadTranslations("freak_fortress_2.phrases");
}

public FF2_OnAbility2(iIndex, const String:pluginName[], const String:abilityName[], iStatus) {
	if (!strcmp(abilityName, "rage_timed_new_weapon"))
		Rage_Timed_New_Weapon(iIndex, abilityName);
}

public Event_RoundStart(Handle:hEvent, const String:sName[], bool:bDontBroadcast) {
	BossTeam = FF2_GetBossTeam();
}

Rage_Timed_New_Weapon(iBIndex, const String:ability_name[])
{
	new iBoss = GetClientOfUserId(FF2_GetBossUserId(iBIndex));
	decl String:sAttributes[256], String:sClassname[96];
	WeaponTime[iBoss] = FF2_GetAbilityArgumentFloat(iBIndex, this_plugin_name, ability_name, 8, 10.0);

	// Weapons classname
	FF2_GetAbilityArgumentString(iBIndex, this_plugin_name, ability_name, 1, sClassname, 96);
	// Attributes to apply to the weapon
	FF2_GetAbilityArgumentString(iBIndex, this_plugin_name, ability_name, 3, sAttributes, 256);

	// Slot of the weapon 0=Primary(Or sapper), 1=Secondary(Or spies revolver), 2=Melee, 3=PDA1(Build tool, disguise kit), 4=PDA2(Destroy tool, cloak), 5=Building
	new iSlot = FF2_GetAbilityArgument(iBIndex, this_plugin_name, ability_name, 4);
	TF2_RemoveWeaponSlot(iBoss, iSlot);
	
	new iIndex = FF2_GetAbilityArgument(iBIndex, this_plugin_name, ability_name, 2);
	
	new bool:bHide = bool:FF2_GetAbilityArgument(iBIndex, this_plugin_name, ability_name, 9, 0);

	new iWep = SpawnWeapon(iBoss, sClassname, iBIndex, 100, 5, sAttributes, bHide);
	
	// Make them equip it?
	if (FF2_GetAbilityArgument(iBIndex, this_plugin_name, ability_name, 7))
		SetEntPropEnt(iBoss, Prop_Send, "m_hActiveWeapon", iWep);
	
	new iAmmo = FF2_GetAbilityArgument(iBIndex, this_plugin_name, ability_name, 5, 0);
	new iClip = FF2_GetAbilityArgument(iBIndex, this_plugin_name, ability_name, 6, 0);
	if(iAmmo || iClip) FF2_SetAmmo(iBoss, iWep, iAmmo, iClip);

	if(WeaponTime[iBoss] > 0.0)
	{
		// Duration to keep the weapon, set to 0 or -1 to keep the weapon
		WeaponTime[iBoss] += GetEngineTime();
		SDKHook(iBoss, SDKHook_PreThink, Boss_Think);
	}
}

public Boss_Think(iBoss)
{
	if(GetEngineTime() >= WeaponTime[iBoss])
	{
		RemoveWeapons(iBoss);
		ApplyDefaultWeapons(iBoss);
		
		SDKUnhook(iBoss, SDKHook_PreThink, Boss_Think);
	}
}

stock RemoveWeapons(iClient)
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

stock SwitchtoSlot(iClient, iSlot)
{
	if (iSlot >= 0 && iSlot <= 5 && IsValidClient(iClient, true))
	{
		decl String:sClassname[96];
		new iWep = GetPlayerWeaponSlot(iClient, iSlot);
		if (iWep > MaxClients && IsValidEdict(iWep) && GetEdictClassname(iWep, sClassname, sizeof(sClassname)))
		{
			FakeClientCommandEx(iClient, "use %s", sClassname);
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWep);
		}
	}
}

stock bool:IsValidClient(iClient, bool:bAlive = false, bool:bTeam = false)
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
stock FindEntityByClassname2(startEnt, const String:sClassname[])
{
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
	return FindEntityByClassname(startEnt, sClassname);
}

stock SpawnWeapon(iClient, String:sClassname[], iIndex, iLevel, iQuality, const String:sAttribute[] = "", bool:bHide = false)
{
	new Handle:hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if (hWeapon == INVALID_HANDLE)
		return -1;
		
	TF2Items_SetClassname(hWeapon, sClassname);
	TF2Items_SetItemIndex(hWeapon, iIndex);
	TF2Items_SetLevel(hWeapon, iLevel);
	TF2Items_SetQuality(hWeapon, iQuality);
	
	decl String:sAttributes[32][32];
	new iCount = ExplodeString(sAttribute, " ; ", sAttributes, 32, 32);
	if (iCount % 2)
		--iCount;
		
	if (iCount > 0)
	{
		TF2Items_SetNumAttributes(hWeapon, iCount/2);
		new i2;
		for(new i; i < iCount; i += 2)
		{
			new iAttrib = StringToInt(sAttributes[i]);
			if (!iAttrib)
			{
				LogError("Bad weapon attribute passed: %s ; %s", sAttributes[i], sAttributes[i+1]);
				CloseHandle(hWeapon);
				return -1;
			}
			TF2Items_SetAttribute(hWeapon, i2, iAttrib, StringToFloat(sAttributes[i+1]));
			i2++;
		}
	}
	else
		TF2Items_SetNumAttributes(hWeapon, 0);
		
	new iEntity = TF2Items_GiveNamedItem(iClient, hWeapon);
	EquipPlayerWeapon(iClient, iEntity);
	CloseHandle(hWeapon);
	
	if (bHide)
	{
		SetEntProp(iEntity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", 0.0001);
	}
	
	return iEntity;
}

ApplyDefaultWeapons(iClient)
{
	if(!IsValidClient(iClient))
	{
		return;
	}
	TF2_RemoveAllWeapons(iClient);
	new boss=FF2_GetBossIndex(iClient);

	decl String:weapon[64], String:attributes[256];
	new Handle:config = FF2_GetSpecialKV(boss);

	for(new j=1; ; j++)
	{
		KvRewind(config);
		Format(weapon, 10, "weapon%i", j);

		if(KvJumpToKey(config, weapon))
		{
			KvGetString(config, "name", weapon, sizeof(weapon));
			KvGetString(config, "attributes", attributes, sizeof(attributes));
			if(attributes[0]!='\0')
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

			new BossWeapon=SpawnWeapon(iClient, weapon, KvGetNum(config, "index"), 101, 5, attributes);
			if(!KvGetNum(config, "show", 0))
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
