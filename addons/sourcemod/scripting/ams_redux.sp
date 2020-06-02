/*
	"ams_base"
	{
		"name"			"gentlespy"		//boss cfg name
		"activation"	"0"
		"selection"		"reload"
		"reverse"		"mouse3"
		
		"hud"
		{
			"cinactive"	"0xFF0000"
			"inactive"	"%s (%.2f rage) [RELOAD (R) to change]\n%s\nAbility is currently unavailable."
			
			"cactive"	"0x00FF00"
			"active"	"%s (%.2f rage) [RELOAD (R) to change]\n%s\nAbility is available. (press E)"
			
			"y"			"0.68"
			
			"yreplace"		"0.83"
			"replace"		"RAGE Meter: %.2f%%\nHP: %i / %i"
		}
		
		"cast-particle"	"ghost_smoke"
	}
	
	"abilityX"
	{
		"name"		"stun_redux"
		
		...
		
		"initial cd"	"5.0"
		"ability cd"	"10.0"
		"this_name"		"ability name here"
		"display_desc"	"ham ham ham"
		"cost"			"10.0"
		"can end"		"0"
		
		"plugin_name"	"ff2_dynamic_abilities"
	}
	
	credit to sarysa for the original AMS, that he/she used for epic scout.
	unfortunately it doesn't support backward compatibility. But to update it, all you have to do is :
	-update AMS_InitSubAbility() to FF2AMS_PushToAMS() or FF2AMS_PushToAMSEx().
	-return AMS_Accept or any value you want (check .inc file) for _CanInvoke instead of true.
	-if needed, use FF2AMS_IsAMSActivatedFor() instead of AMS_IsSubAbilityReady().
	
	what's so different about this version?
	-now you can dynamically change boss' AMS Abilities, for example name/desc and so on.
	-this version aim for better/smoother access to any ams ability.
	-many new forwards/natives/functions to expand ability
	thats all i can think of right now, enjoy.
*/
#include <sdkhooks>
#include <ff2_helper>
#include <ff2ability>

#pragma semicolon 1
#pragma newdecls required

#define MaxBosses (RoundToCeil(view_as<float>(MaxClients)/2.0))
#define ACTIVATE GlobalAMS[client].GetButton("activation", 0)
#define FORWARD GlobalAMS[client].GetButton("selection", IN_RELOAD)
#define REVERSE GlobalAMS[client].GetButton("reverse", IN_ATTACK3)

#define MAXABILITIES 10

enum {
	Current,
	Stack,
	MAXPOSITION
};

enum AMSResult {
	AMS_INVALID = -1,
	AMS_Ignore,
	AMS_Deny,
	AMS_Accept,
	AMS_Overwrite
};

enum {
	hPreAbility,
	hOnAbility,
	hPreForceEnd,
	hPreRoundStart,
	MAXFORWARDS
};

enum {
	Inactive,
	Active,
	Replace,
	MAXFORMATS
};

GlobalForward AMSForward[MAXFORWARDS];
Handle AMS_HUDHandle, AMS_HUDHandleReplace;

bool AMS_Bypass[MAXCLIENTS], AMS_CallMedic[MAXCLIENTS], AMS_IsActive;
float AMS_HudUpdate[MAXCLIENTS];
int AMS_Position[MAXCLIENTS][MAXPOSITION], AMS_Color[MAXCLIENTS][2];
static char GlobalFormat[MAXCLIENTS][MAXFORMATS][360];

#include "ams_helper.sp"

public Plugin myinfo = 
{
	name			= "[FF2] AMS Dynamic",
	author		= "sarysa, rework by 01Pollux",
	description = "allow boss to use multiple rages"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	AMSForward[hPreAbility] = new GlobalForward("FF2AMS_PreAbility", ET_Event, Param_Cell, Param_CellByRef, Param_CellByRef);
	AMSForward[hOnAbility] = new GlobalForward("FF2AMS_OnAbility", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String);
	AMSForward[hPreForceEnd] = new GlobalForward("FF2AMS_OnForceEnd", ET_Event, Param_Cell, Param_CellByRef, Param_CellByRef);
	AMSForward[hPreRoundStart] = new GlobalForward("FF2AMS_PreRoundStart", ET_Ignore, Param_Cell);
	
	CreateNative("FF2AMS_PushToAMS", Native_PushToAMS);
	CreateNative("FF2AMS_PushToAMSEx", Native_PushToAMSEx);
	CreateNative("FF2AMS_GetTotalAbilities", Native_GetTotalAbilities);
	CreateNative("FF2AMS_GetAMSHashMap", Native_GetAMSHandle);
	CreateNative("FF2AMS_GetGlobalAMSHashMap", Native_GetAMSGlobalHandle);
	CreateNative("FF2AMS_IsAMSActivatedFor", Native_IsAMSReadyFor);
	CreateNative("FF2AMS_IsAMSActive", Native_IsAMSActive);
	
	RegPluginLibrary("FF2AMS");
}

public void OnMapStart() 
{
	AMS_HUDHandle = CreateHudSynchronizer();
	AMS_HUDHandleReplace = CreateHudSynchronizer();
}

public void OnPluginStart()
{
	HookEvent("arena_win_panel", Post_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Pre_RoundStart, EventHookMode_Pre);
}

public void Post_RoundEnd(Event hEvent, const char[] nName, bool bBroadcast)
{
	if(AMS_IsActive) {
		for(int i = 1; i <= MaxClients; i++) {
			if(GlobalAMS[i] != null) {
				delete GlobalAMS[i];
				
				AMS_CallMedic[i] = false;
			
				int boss = ClientToBoss(i);
				AMS_Bypass[boss] = false;
			
				for(int j; j < MAXABILITIES; j++) {
					if(AMS_Settings[i][j] == null) {
						break;
					}
					delete AMS_Settings[i][j];
				}
				CleanStack(i);
			}
		}
		RemoveCommandListener(Pre_ClientCallForMedic, "voicemenu");
		AMS_IsActive = false;
	}
}

public void Pre_RoundStart(Event hEvent, const char[] nName, bool bBroadcast)
{
	if(!IsRoundActive())
		return;
	
	AMS_IsActive = false;
	FF2Prep player;
	for(int i; i <= MaxBosses; i++)
	{
		player = FF2Prep(i, false);
		int client = player.Index;
		if(!client)
			break;
		
		if(!CreateAMS(player)) {
			continue;
		}
	
		Call_StartForward(AMSForward[hPreRoundStart]);
		Call_PushCell(client);
		Call_Finish();
		
		AMS_HudUpdate[client] = GetGameTime() + 0.1;
		if(!AMS_IsActive) {
			AddCommandListener(Pre_ClientCallForMedic, "voicemenu");
			AMS_IsActive = true;
		}
	}
}

static bool CreateAMS(FF2Prep player)
{
	int client = player.Index;
	
	char path[PLATFORM_MAX_PATH];
	if(!player.BuildBoss(path, sizeof(path), "ams_base")) {
		return false;
	}
	
	GlobalAMS[client] = new FF2Parse(path, "ams_base");
	if(GlobalAMS[client] == null) {
		return false;
	}

	FF2_SetFF2flags(client, FF2_GetFF2flags(client) | FF2FLAG_HUDDISABLED);
	
	GlobalAMS[client].GetString("hud->active", GlobalFormat[client][Active], sizeof(GlobalFormat[][]));
	ReplaceString(GlobalFormat[client][Active], sizeof(GlobalFormat[][]), "\\n", "\n");
	
	GlobalAMS[client].GetString("hud->inactive", GlobalFormat[client][Inactive], sizeof(GlobalFormat[][]));
	ReplaceString(GlobalFormat[client][Inactive], sizeof(GlobalFormat[][]), "\\n", "\n");
	
	GlobalAMS[client].GetString("hud->replace", GlobalFormat[client][Replace], sizeof(GlobalFormat[][]));
	ReplaceString(GlobalFormat[client][Replace], sizeof(GlobalFormat[][]), "\\n", "\n");
	
	int hex;
	GlobalAMS[client].GetString("hud->cactive", path, 16);
	AMS_Color[client][Active] = StringToHex(path, hex) ? hex:0x00FF00;
	
	GlobalAMS[client].GetString("hud->cinactive", path, 16);
	AMS_Color[client][Inactive] = StringToHex(path, hex) ? hex:0xFF0000;
	
	return true;
}


public Action Pre_ClientCallForMedic(int client, const char[] command, int args)
{
	if(!IsRoundActive() || !AMS_IsActive)
		return Plugin_Continue;
	
	if(!ValidatePlayer(client, AnyAlive))
		return Plugin_Continue;
	
	if(GlobalAMS[client] == null || ACTIVATE)
		return Plugin_Continue;
	
	static char cmd[4];
	GetCmdArgString(cmd, 4);
	if (!strcmp(cmd, "0 0"))
		AMS_CallMedic[client] = true;
	
	return Plugin_Continue;
}

public void FF2_PreAbility(int boss, const char[] plugin, const char[] ability, int slot, bool &enabled)
{
	if(!AMS_IsActive || !IsRoundActive())
		return;
	
	int client = BossToClient(boss);
	if(GlobalAMS[client] != null && !AMS_Bypass[boss]) {
		enabled = false;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float ang[3], int &weapon, int &sub, int &cmd, int &tick, int &seed, int mouse[2])
{
	if(!AMS_IsActive || !IsRoundActive()) {
		return Plugin_Continue;
	}
	if(ValidatePlayer(client, AnyAlive) && GlobalAMS[client] != null && AMS_Position[client][Stack]) {
		Handle_AMSTick(client, buttons);
	}
	return Plugin_Continue;
}

static float flNextPress[MAXCLIENTS];
void Handle_AMSTick(int client, int &buttons)
{
	float gpCurtime = GetGameTime();
	
	if(flNextPress[client] <= gpCurtime) {
		flNextPress[client] = gpCurtime + 0.17;
		
		if(buttons & FORWARD) {
			buttons ^= FORWARD;
			++AMS_Position[client][Current];
			AMS_Position[client][Current] %= AMS_Position[client][Stack];
			AMS_HudUpdate[client] = gpCurtime;
		}
		
		else if(buttons & REVERSE) {
			buttons ^= REVERSE;
			AMS_Position[client][Current] = AMS_Position[client][Current] == 0 ? AMS_Position[client][Stack] - 1:--AMS_Position[client][Current];
			AMS_HudUpdate[client] = gpCurtime;
		}
		
		bool activate = buttons & ACTIVATE && ACTIVATE != 0;
		int boss = ClientToBoss(client);
		if(activate || AMS_CallMedic[client]) {
			int index = AMS_Position[client][Current];
			AMS_CallMedic[client] = false;
			activate = false;
			buttons ^= ACTIVATE;
			
			if(FF2_GetAMSType(client, index) == AMS_Accept) {
				Handle_AMSOnAbility(client, index);
				
				FF2_SetBossCharge(boss, 0, FF2_GetBossCharge(boss, 0) - AMS_Settings[client][index].GetCost());
				AMS_Settings[client][index].AddCooldown();
				AMS_HudUpdate[client] = gpCurtime;
				AMS_Bypass[boss] = true;
				CreateTimer(0.205, Timer_RemoveBypass, boss, TIMER_FLAG_NO_MAPCHANGE);
			} else if(AMS_Settings[client][index].CanEnd()) {
				Handle_AMSOnEnd(client, index);
			}
		}
	}
	
	if(gpCurtime >= AMS_HudUpdate[client])
	{
		AMS_HudUpdate[client] = gpCurtime + 0.2;
		
		int boss = ClientToBoss(client);
		int index = AMS_Position[client][Current];
		bool available = FF2_GetAMSType(client, index, true) == AMS_Accept;
		static char other[32], other2[48];
		
		AMS_Settings[client][index].GetString("this_name", other, sizeof(other));
		AMS_Settings[client][index].GetString("display_desc", other2, sizeof(other2));
		
		if(available) {
			SetHudTextParams(-1.0, GlobalAMS[client].GetFloat("hud->y"), 0.25, GetR(AMS_Color[client][Active]), GetG(AMS_Color[client][Active]), GetB(AMS_Color[client][Active]), 255);
			ShowSyncHudText(client, AMS_HUDHandle, GlobalFormat[client][Active], other, AMS_Settings[client][index].GetCost(), other2);
		} else {
			SetHudTextParams(-1.0, GlobalAMS[client].GetFloat("hud->y"), 0.25, GetR(AMS_Color[client][Inactive]), GetG(AMS_Color[client][Inactive]), GetB(AMS_Color[client][Inactive]), 255);
			ShowSyncHudText(client, AMS_HUDHandle, GlobalFormat[client][Inactive], other, AMS_Settings[client][index].GetCost(), other2);
		}
		
		if(!IsEmptyString(GlobalFormat[client][Replace])) {
			SetHudTextParams(-1.0, GlobalAMS[client].GetFloat("hud->yreplace"), 0.25, 255, 255, 255, 255);
			ShowSyncHudText(client, AMS_HUDHandleReplace, GlobalFormat[client][Replace], FF2_GetBossCharge(boss, 0), FF2_GetBossHealth(boss), FF2_GetBossMaxHealth(boss)*FF2_GetBossMaxLives(boss));
		}
	}
}

static AMSResult FF2_GetAMSType(int client, int index, bool hud=false)
{
	if(TF2_IsPlayerInCondition(client, TFCond_Dazed))
		return AMS_Deny;
	
	if(AMS_Settings[client][index].GetCurrentCooldown() > GetGameTime())
		return AMS_Deny;
	
	int boss = ClientToBoss(client);
	if(FF2_GetBossCharge(boss, 0) < AMS_Settings[client][index].GetCost())
		return AMS_Deny;
	
	return hud ? AMS_Accept:Handle_AMSPreAbility(client, index);
}

public int FF2_PushToAMS(int client, Handle pContext, const char[] plugin, const char[] ability, const char[] prefix)
{
	FF2Prep player = FF2Prep(client);
	
	if(AMS_Position[client][Stack] >= MAXABILITIES) {
		return -1;
	}
	
	int index = AMS_Position[client][Stack];
	AMS_Settings[client][AMS_Position[client][Stack]++] = new AMSSettings(player, pContext, plugin, ability, prefix);
	return index;
}

public Action Timer_RemoveBypass(Handle Timer, int boss)
{
	AMS_Bypass[boss] = false;
}

public any Native_PushToAMSEx(Handle pContext, int Params) 
{
	int client = GetNativeCell(1);
	if (client < 0 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%i)", client);
	}
	
	char plugin[64]; GetNativeString(2, plugin, sizeof(plugin));
	char ability[64]; GetNativeString(3, ability, sizeof(ability));
	char prefix[6]; GetNativeString(4, prefix, sizeof(prefix));
	
	if (IsEmptyString(plugin) || IsEmptyString(ability) || IsEmptyString(prefix)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "plugin(%s)/ability(%s)/prefix(%s) cannot be empty!", plugin, ability, prefix);
	}
	
	return FF2_PushToAMS(client, pContext, plugin, ability, prefix);
}

public any Native_PushToAMS(Handle pContext, int Params)
{
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%i)", client);
	}
	
	char plugin[64]; GetNativeString(2, plugin, sizeof(plugin));
	char ability[64]; GetNativeString(3, ability, sizeof(ability));
	char prefix[6]; GetNativeString(4, prefix, sizeof(prefix));
	
	if (IsEmptyString(plugin) || IsEmptyString(ability) || IsEmptyString(prefix)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "plugin(%s)/ability(%s)/prefix(%s) cannot be empty!", plugin, ability, prefix);
	}
	
	return FF2_PushToAMS(client, pContext, plugin, ability, prefix) != -1;
}

public any Native_GetTotalAbilities(Handle pContext, int Params)
{
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%i)", client);
	}
	return AMS_Position[client][Stack];
}

public any Native_GetAMSHandle(Handle pContext, int Params)
{
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients || GlobalAMS[client] == null) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%i)", client);
	}
	int index = GetNativeCell(2);
	if(index < 0 || index >= AMS_Position[client][Stack]) {
		return ThrowNativeError(SP_ERROR_ARRAY_BOUNDS, "client (%i) doesn't have an AMS ability", client);
	}
	
	return view_as<StringMap>(AMS_Settings[client][index]);
}

public any Native_GetAMSGlobalHandle(Handle pContext, int Params)
{
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%i)", client);
	}
	return view_as<StringMap>(GlobalAMS[client]);
}

public any Native_IsAMSReadyFor(Handle pContext, int Params)
{
	int client = GetNativeCell(1);
	if(client <= 0 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%i)", client);
	}
	return GlobalAMS[client] != null;
}

public any Native_IsAMSActive(Handle pContext, int Params)
{
	return AMS_IsActive;
}

static void CleanStack(int client)
{
	AMS_Position[client][Stack] = 0;
	AMS_Position[client][Current] = 0;
}

stock int IdxToButton(int button)
{
	switch(button) {
		case 0: return 0;
		case 1: return IN_RELOAD;
		case 2: return IN_USE;
		case 3: return IN_ATTACK3;
		case 4: return IN_ATTACK2;
	}
	return 0;
}

static int GetR(const int hex)
{
	int result = (hex >> 0x10) & 0xFF0;
	return (result < 0 ? -result:result);
}

static int GetG(const int hex)
{
	int result = (hex >> 0x8) & 0xFF;
	return (result < 0 ? -result:result);
}

static int GetB(const int hex)
{
	int result = (hex) & 0xFF;
	return (result < 0 ? -result:result);
}
