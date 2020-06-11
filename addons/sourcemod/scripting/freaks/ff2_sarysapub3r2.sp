
#include <sdkhooks>
#include <ff2_helper>
#include <ff2_ams2>
#include <ff2_dynamic_defaults>
#include <freak_fortress_2_subplugin>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

enum {
	Weapon_Switch,
	GetSlot,
	
	MAXCALLS
};
Handle SDKCalls[MAXCALLS];

#include "sarysapub3/rage_random_weapon.sp"
#include "sarysapub3/rage_steal_next_weapon.sp"

public Plugin myinfo = {
	name = "Freak Fortress 2: sarysa's mods, second pack rework",
	author = "sarysa, 01Pollux",
	version = "1.1.1",
};

public void OnPluginStart2()
{
	LoadGameData();
	HookEvent("arena_win_panel", Post_RoundEnd, EventHookMode_PostNoCopy);
}

public void OnClientDisconnect(int client)
{
	RRW_ClientDisconnect(client);
	SNW_ClientDisconnect(client);
}

public Action Post_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	RRW_RoundEnd();
	SNW_RoundEnd();
}

public void FF2AMS_PreRoundStart(int client)
{
	FF2Prep player = FF2Prep(client);
	if(player.HasAbility(FAST_REG(rage_random_weapon))) {
		RRW_AMS[client] = player.GetArgI(FAST_REG(rage_random_weapon), "ams", .def = 1) != 0 && AMS_REG(client)(rage_random_weapon.RRW);
	}
	if(player.HasAbility(FAST_REG(rage_random_weapon))) {
		SNW_AMS[client] = player.GetArgI(FAST_REG(rage_steal_next_weapon), "ams", .def = 1) != 0 && AMS_REG(client)(rage_steal_next_weapon.SNW);
	}
}

public void FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	if(!IsRoundActive()) {
		return;
	}
	
	if(!strcmp(ability_name, "rage_random_weapon")) {
		int client = BossToClient(boss);
		if(!RRW_AMS[client]) {
			RRW_Invoke(client, -1);
		}
	}
	else if(!strcmp(ability_name, "rage_random_weapon")) {
		int client = BossToClient(boss);
		if(!SNW_AMS[client]) {
			SNW_Invoke(client, -1);
		}
	}
}

void UTIL_SwitchToNextBestWeapon(int client, int slot)
{
	int activeweapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(IsValidEntity(activeweapon)) {
		SetEntProp(activeweapon, Prop_Send, "m_bResetParity", !GetEntProp(activeweapon, Prop_Send, "m_bResetParity"));
	}
	int weapon = GetPlayerWeaponSlot(client, slot);
	if(weapon == activeweapon) {
		for(int i = 0; i < 5; i++) {
			weapon = GetPlayerWeaponSlot(client, i);
			if(IsValidEntity(weapon) && weapon != activeweapon) {
				break;
			}
		}
	}
	
	if(IsValidEntity(weapon)) {
		SDKCall(SDKCalls[Weapon_Switch], client, weapon, 0);
	}
}

int UTIL_GetWeaponSlot(int weapon)
{
	return SDKCall(SDKCalls[GetSlot], weapon);
}

stock bool PlayerIsInvun(int client)
{
	if (TF2_IsPlayerInCondition(client, TFCond_Ubercharged) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedCanteen) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedOnTakeDamage) ||
		TF2_IsPlayerInCondition(client, TFCond_Bonked)) {
		return false;
	}
	return GetEntProp(client, Prop_Data, "m_takedamage") != 0;
}

void LoadGameData()
{
	hConfig = new GameData("ff2.sarysapack");
	if(!hConfig) {
		SetFailState("Failed to load gamedata \"ff2.sarysapack\".");
		return;
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConfig, SDKConf_Virtual, "CTFPlayer::Weapon_Switch");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	SDKCalls[Weapon_Switch] = EndPrepSDKCall();
	if(!SDKCalls[Weapon_Switch]) {
		SetFailState("Failed to create a call for \"CTFPlayer::Weapon_Switch\"");
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConfig, SDKConf_Virtual, "CBaseCombatWeapon::GetSlot");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	SDKCalls[GetSlot] = EndPrepSDKCall();
	if(!SDKCalls[GetSlot]) {
		SetFailState("Failed to create a call for \"CBaseCombatWeapon::GetSlot\"");
	}
	
	delete hConfig;
}
