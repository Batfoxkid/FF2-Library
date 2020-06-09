
#include <ff2_ams2>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

bool AMSOnly[MAXPLAYERS+1]=false;
int alives = 0;

public Plugin myinfo = {
	name = "Freak Fortress 2: Simple Custom Bowrage",
	author = "Koishi",
	version = "1.2"
};

public void OnPluginStart2() {	
}

public void FF2AMS_PreRoundStart(int client)
{
	int boss = FF2_GetBossIndex(client);
	if(FF2_HasAbility(boss, this_plugin_name, "rage_new_bowrage")) {
		AMSOnly[client] = FF2AMS_PushToAMS(client, this_plugin_name, "rage_new_bowrage", "BOW");
	}
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int action)
{
	int client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(strcmp(ability_name, "rage_new_bowrage") && !AMSOnly[client])
	{
		BOW_Invoke(client, -1);						// Standard Bowrage
	}
	return Plugin_Continue;
}

stock int SpawnWeapon(int client, char[] name, int index, int level, int qual, char[] att)
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

public void BOW_Invoke(int client, int index)
{
	int weapon;
	char attributes[126] = "";
	int boss=FF2_GetBossIndex(client);
	int bowtype=FF2_GetAbilityArgument(boss,this_plugin_name,"rage_new_bowrage", 1);	// Bow type? (0: Huntsman, 1: Festive Huntsman, 2: Fortified Compound, 3: Crusader's Crossbow, 4: Festive Crusader's crossbow)
	int kson=FF2_GetAbilityArgument(boss,this_plugin_name,"rage_new_bowrage", 2);	// Killstreaks? (0: Off, 1: On)
	int ammo=FF2_GetAbilityArgument(boss,this_plugin_name,"rage_new_bowrage", 3);	// Ammo amount (0 will match to # of alive players)
	int clip=FF2_GetAbilityArgument(boss,this_plugin_name,"rage_new_bowrage", 4);	// Clip amount
	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "rage_new_bowrage", 5, attributes, sizeof(attributes));
	if(kson) {
		StrCat(attributes, sizeof(attributes), attributes[0] == '\0' ? "2025 ; 1":" ; 2025 ; 1");
	}
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
	switch(bowtype)
	{
		case 1:
			weapon = SpawnWeapon(client, "tf_weapon_compound_bow", 1005, 101, 5, attributes);
		case 2:
			weapon = SpawnWeapon(client, "tf_weapon_compound_bow", 1092, 101, 5, attributes);
		case 3:
			weapon = SpawnWeapon(client, "tf_weapon_crossbow", 305, 101, 5, attributes);
		case 4:
			weapon = SpawnWeapon(client, "tf_weapon_crossbow", 1079, 101, 5, attributes);
		default:
			weapon = SpawnWeapon(client, "tf_weapon_compound_bow", 56, 101, 5, attributes);
	}
	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	if(ammo<0)
		ammo = alives;
	if(ammo)
		SetAmmo(client, weapon , ammo);
	if(clip)
		SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
}

public void FF2_OnAlivePlayersChanged(int players, int bosses)
{
	alives = players + bosses;
}
