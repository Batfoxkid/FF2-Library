
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
	EquipWearable,
	
	MAXCALLS
};
Handle SDKCalls[MAXCALLS];
ConVar sv_cheats = null;

#define LoopAnyValidPlayer(%1) \
		for(int _x = 1; _x <= MaxClients; _x++) {	\
			if(ValidatePlayer(_x, Any)) {	\
				%1	\
			}	\
		}
		
#include "sarysapub3/rage_random_weapon.sp"
#include "sarysapub3/rage_steal_next_weapon.sp"
#include "sarysapub3/rage_fake_dead_ringer.sp"
#include "sarysapub3/rage_front_protection.sp"
#include "sarysapub3/rage_dodge_specific_damage.sp"

public Plugin myinfo = {
	name = "Freak Fortress 2: sarysa's mods, second pack rework",
	author = "sarysa, 01Pollux",
	version = "1.1.1",
};

public void OnPluginStart2()
{
	LoadGameData();
	sv_cheats = FindConVar("sv_cheats");
	HookEvent("arena_win_panel", Post_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_win_start", Post_RoundStart, EventHookMode_PostNoCopy);
}

public Action Post_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	RRW_RoundEnd();
	SNW_RoundEnd();
	FDR_RoundEnd();
	FP_RoundEnd();
	DSD_RoundEnd();
}

public Action Post_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	FF2Prep player;
	int client;
	for(int i = 0; ; i++) {
		player = FF2Prep(i, false);
		client = player.Index;
		if(!client) {
			break;
		}
	}
}

public void FF2AMS_PreRoundStart(int client)
{
	FF2Prep player = FF2Prep(client);
	if(player.HasAbility(FAST_REG(rage_random_weapon)) && player.GetArgI(FAST_REG(rage_random_weapon), "ams", .def = 1)) {
		RRW_AMS[client] = AMS_REG(client)(rage_random_weapon.RRW);
	}
	if(player.HasAbility(FAST_REG(rage_steal_next_weapon)) && player.GetArgI(FAST_REG(rage_steal_next_weapon), "ams", .def = 1)) {
		if((SNW_AMS[client] = AMS_REG(client)(rage_steal_next_weapon.SNW)) == true) {
			SDKHook(client, SDKHook_OnTakeDamageAlive, SNW_OnTakeDamageAlive);
		}
	}
	if(player.HasAbility(FAST_REG(rage_fake_dead_ringer)) && player.GetArgI(FAST_REG(rage_fake_dead_ringer), "ams", .def = 1)) {
		if((SNW_AMS[client] = AMS_REG(client)(rage_fake_dead_ringer.FDR)) == true) {
			SDKHook(client, SDKHook_OnTakeDamageAlive, FDR_OnTakeDamageAlive);
		}
	}
	if(player.HasAbility(FAST_REG(rage_front_protection)) && player.GetArgI(FAST_REG(rage_front_protection), "ams", .def = 1)) {
		if((FP_AMS[client] = AMS_REG(client)(rage_front_protection.FP)) == true) {
			SDKHook(client, SDKHook_OnTakeDamageAlive, FP_OnTakeDamageAlive);
		}
	}
	if(player.HasAbility(FAST_REG(rage_dodge_specific_damage)) && player.GetArgI(FAST_REG(rage_dodge_specific_damage), "ams", .def = 1)) {
		if((DSD_AMS[client] = AMS_REG(client)(rage_dodge_specific_damage.DSD)) == true) {
			SDKHook(client, SDKHook_OnTakeDamageAlive, DSD_OnTakeDamageAlive);
		}
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
	else if(!strcmp(ability_name, "rage_steal_next_weapon")) {
		int client = BossToClient(boss);
		if(!SNW_AMS[client]) {
			SNW_Invoke(client, -1);
		}
	}
	else if(!strcmp(ability_name, "rage_fake_dead_ringer")) {
		int client = BossToClient(boss);
		if(!FDR_AMS[client]) {
			FDR_Invoke(client, -1);
		}
	}
	else if(!strcmp(ability_name, "rage_front_protection")) {
		int client = BossToClient(boss);
		if(!FP_AMS[client]) {
			FP_Invoke(client, -1);
		}
	}
	else if(!strcmp(ability_name, "rage_front_protection")) {
		int client = BossToClient(boss);
		if(!DSD_AMS[client]) {
			DSD_Invoke(client, -1);
		}
	}
}

#if defined _goomba_included_
public Action OnStomp(int attacker, int victim, float& damageMultiplier, float& damageBonus, float& JumpPower)
{
	return FDR_OnStomp(attacker, victim, damageMultiplier, damageBonus, JumpPower);
}
#endif


void UTIL_UpdateCheatValues(const char[] val)
{
	for(int client = 1; client <= MaxClients; client++) {
		if(IsClientInGame(client) && !IsFakeClient(client)) {
			sv_cheats.ReplicateToClient(client, val);
		}
	}
}

void UTIL_CreateRagdoll(int client)
{
	int ragdoll = CreateEntityByName("tf_ragdoll");
	if(IsValidEntity(ragdoll)) {
		float vecPos[3], vecAng[3];
		GetClientAbsOrigin(client, vecPos);
		GetClientAbsAngles(client, vecAng);
		
		TeleportEntity(ragdoll, vecPos, vecAng, NULL_VECTOR);
		
		SetEntProp(ragdoll, Prop_Send, "m_iPlayerIndex", client);
		SetEntProp(ragdoll, Prop_Send, "m_iTeam", GetClientTeam(client));
		SetEntProp(ragdoll, Prop_Send, "m_iClass", view_as<int>(TF2_GetPlayerClass(client)));
		SetEntProp(ragdoll, Prop_Send, "m_bOnGround", 1);
		
		SetEntityMoveType(ragdoll, MOVETYPE_NONE);
		
		DispatchSpawn(ragdoll);
		ActivateEntity(ragdoll);
		
		CreateTimer(3.0, Timer_KillEntity, EntIndexToEntRef(ragdoll), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_KillEntity(Handle timer, int ref)
{
	int entity = EntIndexToEntRef(ref);
	if(IsValidEntity(entity)) {
		RemoveEntity(entity);
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

bool PlayerIsInvun(int client)
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

int TF2_EquipWearable(int client, int defidx, const char[] clsname, const int quality = 5, const int level = 39)
{
	int entity = CreateEntityByName(clsname);
	if(!IsValidEntity(entity)) {
		return -1;
	}

	SetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex", defidx);
	SetEntProp(entity, Prop_Send, "m_bInitialized", 1);
	
	SetEntData(entity, GetEntSendPropOffs(entity, "m_iEntityQuality", true), quality);
	SetEntProp(entity, Prop_Send, "m_iEntityQuality", quality);

	SetEntData(entity, GetEntSendPropOffs(entity, "m_iEntityLevel", true), level);
	SetEntProp(entity, Prop_Send, "m_iEntityLevel", level);

	DispatchSpawn(entity);
	
	SDKCall(SDKCalls[EquipWearable], client, entity);
	return entity;
}

static void LoadGameData()
{
	GameData hConfig = new GameData("ff2.sarysapack");
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
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConfig, SDKConf_Virtual, "CBasePlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	SDKCalls[EquipWearable] = EndPrepSDKCall();
	if(!SDKCalls[EquipWearable]) {
		SetFailState("Failed to create a call for \"CBaseCombatWeapon::GetSlot\"");
	}
	
	delete hConfig;
}
