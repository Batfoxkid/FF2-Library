#include <dhooks>
#include <sdkhooks>
#include <ff2_helper>
#include <ff2menu_included>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

#define BRS_CFG "brs_config"
#define COMMON "special_weapons_"
#define REALITY "reality_wrap"
#define UPGRADE "energy_upgrade"

enum WeaponType {
	Inactive,
	StunGun,
	Healing,
	Homing,
	Multiple
};

enum {
	SDKGetSlot,
	SDKFindEntityInSphere,
	hItemPostFrame,
	hPrimaryAttack,
	MAXHANDLES
};

enum struct TrackerInfo {
	float DmgSince;
	bool IsRaging;
}

TrackerInfo Tracker[MAXCLIENTS];
WeaponType iWeapon;
Handle Global[MAXHANDLES];
ArrayList ADTWeapons = null;
bool UnOfficialFF2;
bool IsBRSAcitve;
bool bIsBRSWeapon;

int m_vecTurretAngles;
int m_flRocketDamage;

#include "brs_hale/handles.sp"
#include "brs_hale/stocks.sp"

/*
	[FF2] Black Rock Shooter
	
	Model By : Litronom - https://steamcommunity.com/sharedfiles/filedetails/?id=930415844
	
	Some other Black Rock Shooters :
	https://forums.alliedmods.net/showpost.php?p=2510300?p=2510300
	https://forums.alliedmods.net/showpost.php?p=2155082?p=2155082
*/

public Plugin myinfo = 
{
	name		= "[FF2] Black Rock Shooter",
	author		= "01Pollux",
	description = "Yet another Black rock shooter.",
	version		= "1.1",
	url			= "no.where.net"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
#if defined _FFBAT_included
	MarkNativeAsOptional("FF2_EmitVoiceToAll");
#endif
	MarkNativeAsOptional("FF2MenuRage_PeekValue");
	MarkNativeAsOptional("FF2MenuRage_SetValue");
	return APLRes_Success;
}

public void OnPluginStart2()
{
	Prep_PluginStart();
	
	#if defined _FFBAT_included
	int Ver[3];
	FF2_GetForkVersion(Ver);
	if(Ver[0] && Ver[1])
		UnOfficialFF2 = true;
	#endif
	
	HookEvent("arena_win_panel", Post_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Post_RoundStart, EventHookMode_PostNoCopy);
	
	m_vecTurretAngles = FindSendPropInfo("CObjectSentrygun", "m_iAmmoShells") - 0x1C;
	m_flRocketDamage = FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 0x04;
	
	if(IsRoundActive())
		Post_RoundStart(null, "plugin_lateload", false);
}

public void OnMapEnd()
{
	Post_RoundEnd(null, "plugin_unload", false);
}

static void Prep_PluginStart()
{
	GameData Config = new GameData("brs_gamedata");
	if(!Config){
		SetFailState("[GameData] Failed to load \"brs_gamedata.txt\"");
		return;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(Config, SDKConf_Virtual, "CBaseCombatWeapon::GetSlot");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((Global[SDKGetSlot] = EndPrepSDKCall()) == null) {
		delete Config;
		SetFailState("[GameData] Failed to start a call for \"CBaseCombatWeapon::GetSlot\"");
		return;
	}
	
	StartPrepSDKCall(SDKCall_EntityList);
	PrepSDKCall_SetFromConf(Config, SDKConf_Signature, "CGlobalEntityList::FindEntityInSphere");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	if((Global[SDKFindEntityInSphere] = EndPrepSDKCall()) == null) {
		delete Config;
		SetFailState("[GameData] Failed to start a call for \"CGlobalEntityList::FindEntityInSphere\"");
		return;
	}
	
	Global[hItemPostFrame] = DHookCreateFromConf(Config, "CBaseCombatWeapon::ItemPostFrame");
	if(Global[hItemPostFrame] == null){
		delete Config;
		SetFailState("[GameData] Failed to create a hook for \"CBaseCombatWeapon::ItemPostFrame\"");
		return;
	}
	
	Global[hPrimaryAttack] = DHookCreateFromConf(Config, "CBaseCombatWeapon::PrimaryAttack");
	if(Global[hPrimaryAttack] == null){
		delete Config;
		SetFailState("[GameData] Failed to create a hook for \"CBaseCombatWeapon::PrimaryAttack\"");
		return;
	}
	
	Prep_Medigun(Config);
	delete Config;
}

public void Post_RoundEnd(Event hevent, const char[] name, bool dontBroadcast)
{
	RoundEnd_Cleanup();
}

public void Post_RoundStart(Event hevent, const char[] name, bool dontBroadcast)
{
	IsBRSAcitve = RoundStart_PrepAbilities();
}

public Action FF2_OnAbility2(int boss, const char[] Plugin_Name, const char[] Ability_Name, int status)
{
	if(!IsBRSAcitve)
		return Plugin_Continue;
	if(!IsRoundActive() || strcmp(Plugin_Name, this_plugin_name))
		return Plugin_Continue;

	if(!strcmp(Ability_Name, UPGRADE)) {
		FF2_OnAbility_Upgrade(boss);
	} 
	return Plugin_Continue;
}

public Action FF2MenuRage_OnStartRage(int boss, int& points, int& cooldown, const char[] Plugin_Name, const char[] Ability_Name)
{
	if(!IsBRSAcitve)
		return Plugin_Continue;
		
	if(!StrContains(Ability_Name, COMMON)) {
		if(Tracker[boss].IsRaging) {
			return Plugin_Stop;
		}
		FF2_OnAbility_PickWeapon(boss, Ability_Name);
		return Plugin_Changed;
	} else if(!strcmp(Ability_Name, REALITY)) {
		return FF2_OnAbility_RealityWrap(boss);
	}
	else return Plugin_Continue;
}

public void OnGameFrame()
{
	if(!IsBRSAcitve)
		return;
	if(!IsRoundActive())
		return;
	if(iWeapon != Homing)
		return;
	int rocket = -1;
	while((rocket = FindEntityByClassname(rocket, "tf_projectile_rocket")) > 0)
		Handle_HomingRocketThink(rocket);
}

#file "[FF2] Black Rock Shooter v3"
