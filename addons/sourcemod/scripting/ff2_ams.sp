#include <sourcemod>
#include <tf2_stocks>
#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

#define ToAMSUser(%0) view_as<AMSUser>(%0)
#define MAXCLIENTS MAXPLAYERS + 1
#define _AMS_TAG "ams_sys." ... 
Handle hAMSHud;

FF2GameMode ff2_gm;

enum {
	hPreAbility,
	hOnAbility,
	hPreForceEnd,
	hPreRoundStart,
	MAXFORWARDS
};
GlobalForward AMSForward[MAXFORWARDS];
float AMS_HudUpdate[MAXCLIENTS];

#include "include/ff2_ams_helper.sp"

public Plugin myinfo = 
{
	name		= "[FF2] Ability Management System",
	author		= "01Pollux",
	version 	= "1.0",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	AMSForward[hPreAbility] 	= new GlobalForward("FF2AMS_PreAbility", 	ET_Event, 	Param_Cell, Param_CellByRef, 	Param_CellByRef);
	AMSForward[hOnAbility] 		= new GlobalForward("FF2AMS_OnAbility", 	ET_Ignore, 	Param_Cell,	Param_Cell);
	AMSForward[hPreForceEnd] 	= new GlobalForward("FF2AMS_OnForceEnd", 	ET_Event, 	Param_Cell, Param_CellByRef,	Param_CellByRef);
	AMSForward[hPreRoundStart] 	= new GlobalForward("FF2AMS_PreRoundStart", ET_Ignore, 	Param_Cell);
	
	CreateNative("FF2AMS_PushToAMS",			Native_PushToAMS);
	CreateNative("FF2AMS_PushToAMSEx", 			Native_PushToAMSEx);
	CreateNative("FF2AMS_GetAMSAbilities",		Native_GetAMSAbilities);
	CreateNative("FF2AMS_IsAMSActivatedFor",	Native_IsAMSReadyFor);
	CreateNative("FF2AMS_IsAMSActive", 			Native_IsAMSActive);
	
	RegPluginLibrary("FF2AMS");
}

public void OnMapStart()
{
	hAMSHud = CreateHudSynchronizer();
}

public void OnLibraryAdded(const char[] name)
{
	if(!strcmp(name, "VSH2")) {
		VSH2_Hook(OnRoundStart, 	_OnRoundStart);
		HookEvent("arena_win_panel", _OnRoundEnd, EventHookMode_PostNoCopy);
		VSH2_Hook(OnBossThink, 		_OnBossThink);
		VSH2_Hook(OnBossMedicCall, 	_OnBossRage);
		VSH2_Hook(OnBossTaunt, 		_OnBossRage);
		
		if(ff2_gm.RoundState == StateRunning) {
			VSH2Player[] pl2 = new VSH2Player[MaxClients];
			int pl = FF2GameMode.GetBosses(pl2);
			_OnRoundStart(pl2, pl, pl2, 0);
		}
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(!strcmp(name, "VSH2")) {
		VSH2_Unhook(OnRoundStart, _OnRoundStart);
		UnhookEvent("arena_win_panel", _OnRoundEnd, EventHookMode_PostNoCopy);
		VSH2_Unhook(OnBossThink, _OnBossThink);
		VSH2_Unhook(OnBossMedicCall, _OnBossRage);
		VSH2_Unhook(OnBossTaunt, _OnBossRage);
	}
}


public void _OnRoundStart(const VSH2Player[] bosses, const int boss_count, const VSH2Player[] red_players, const int red_count)
{
	AMSUser player;
	
	bool exists;
	for(int i = 0; i < boss_count; i++) 
	{
		player = ToAMSUser(bosses[i]);
		if(!FF2GameMode.Validate(view_as<VSH2Player>(player)))
			continue;
		
		if(!CreateAMS(player))
			continue;
		
		exists = true;
		
		Call_StartForward(AMSForward[hPreRoundStart]);
		Call_PushCell(player.index);
		Call_Finish();
	}
	
	if(exists)
		FF2GameMode.SetProp("bAMSExists", true);
}

public void _OnRoundEnd(Event hEvent, const char[] nName, bool bBroadcast)
{
	if(!FF2GameMode.GetPropAny("bAMSExists"))
		return;
	
	AMSUser player;
	for(int client = MaxClients; client > 0; client--)
	{
		player = AMSUser(client);
		if(!player.Valid)
			continue;
		
		if(player.bHasAMS)
		{
			player.bHasAMS = false;
			player.SetPropAny("bSupressRAGE", false);
			ResetPlayer(client);
		}
	}
	
	FF2GameMode.SetProp("bAMSExists", false);
}

public void _OnBossThink(const VSH2Player vsh2player)
{
	if(ff2_gm.RoundState != StateRunning)
		return;
	
	AMSUser player = ToAMSUser(vsh2player);
	if(!player.bHasAMS || !IsPlayerAlive(player.index)) 
		return;
	
	Handle_AMSThink(player);
}

public Action _OnBossRage(const VSH2Player vsh2player)
{
	AMSUser player = ToAMSUser(vsh2player);
	if(!player.bHasAMS)
		return Plugin_Continue;
		
	player.bWantsToRage = true;
	return Plugin_Stop;
}


public void OnClientDisconnect(int client)
{
	if(ff2_gm.FF2IsOn)
	{
		AMSUser player = AMSUser(client);
		if(!player.bHasAMS)
			return;
			
		player.bHasAMS = false;
		ResetPlayer(client);
	}
}


void Handle_AMSThink(const AMSUser player)
{
	int client = player.index;
	static AMSData_t data; data = AMSData[client];
	if(!data.hAbilities.Length)
		return;
	
	static float flNextPress[MAXCLIENTS];
	
	float curTime = GetGameTime();
	int buttons = GetClientButtons(client);
	
	if(flNextPress[client] <= curTime) 
	{
		if(buttons & data.iForwardKey) 
		{
			SetEntProp(client, Prop_Data, "m_nButtons", buttons ^ data.iForwardKey);
			AMSData[client].MoveForward();
			
			AMS_HudUpdate[client] = curTime;
			flNextPress[client] = curTime + 0.12;
		}
		else if(buttons & data.iReverseKey)
		{
			SetEntProp(client, Prop_Data, "m_nButtons", buttons ^ data.iReverseKey);
			AMSData[client].MoveBackward();
			
			AMS_HudUpdate[client] = curTime;
			flNextPress[client] = curTime + 0.12;
		}
	}
	
	{
		bool activate = buttons & data.iActivateKey && data.iActivateKey;
		if(activate || player.bWantsToRage)
		{
			AMSHash hash = data.hAbilities.Get(data.Pos);
			player.bWantsToRage = false;
			
			if(FF2_GetAMSType(player, hash) == AMS_Accept)
			{
				Handle_AMSOnAbility(player, hash);
				
				player.SetPropFloat("flRAGE", player.GetPropFloat("flRAGE") - hash.flCost);
				AMS_HudUpdate[client] = curTime;
			}
			else if(hash.bCanEnd) {
				Handle_AMSOnEnd(client, hash);
			}
		}
	}
	
	if(curTime >= AMS_HudUpdate[client])
	{
		AMS_HudUpdate[client] = curTime + 0.2;
		AMSHash hash = data.hAbilities.Get(data.Pos);
		bool available = FF2_GetAMSType(player, hash, true) >= AMS_Accept;
		
		static char other[48], other2[48];
		hash.GetString("this_name", other, sizeof(other));
		hash.GetString("ability desc", other2, sizeof(other2));
		
		static int color[4]; GetRGBA(available ? player.rgba_on : player.rgba_off, color);
		
		SetHudTextParams(-1.0, 
						data.flHudPos, 
						0.25, 
						color[0], color[1], color[2], 255);
		
		ShowSyncHudText(client, 
						hAMSHud, 
						available ? data.szActive : data.szInactive, 
						other, 
						hash.flCost, 
						other2);
	}
}

static AMSResult FF2_GetAMSType(AMSUser player, AMSHash _data, bool hud=false)
{
	int client = player.index;
	if(TF2_IsPlayerInCondition(client, TFCond_Dazed))
		return AMS_Deny;
	
	if(_data.flCooldown > GetGameTime())
		return AMS_Deny;
	
	if(player.GetPropFloat("flRAGE") < _data.flCost)
		return AMS_Deny;
	
	return hud ? AMS_Accept:Handle_AMSPreAbility(client, _data);
}

void GetRGBA(const int hex, int color[4])
{
	static char fmt[16], c[2];
	FormatEx(fmt, sizeof(fmt), "%8x", hex);
	for(int i; i < 4; i++)
	{
		c[0] = fmt[i * 2] & 0xFF;
		c[1] = fmt[i * 2 + 1] & 0xFF;
		color[i] = StringToInt(c, 16);
	}
}



public int FF2_PushToAMS(int client, Handle hPlugin, const char[] pl_name, const char[] ab_name, const char[] prefix)
{
	return AMSData[client].hAbilities.Register(FF2Player(client), hPlugin, pl_name, ab_name, prefix);
}

public any Native_PushToAMSEx(Handle pContext, int Params) 
{
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%i)", client);
	
	char plugin[64]; GetNativeString(2, plugin, sizeof(plugin));
	char ability[64]; GetNativeString(3, ability, sizeof(ability));
	char prefix[6]; GetNativeString(4, prefix, sizeof(prefix));
	
	if (!plugin[0] || !ability[0] || !prefix[0])
		return ThrowNativeError(SP_ERROR_NATIVE, "plugin(%s)/ability(%s)/prefix(%s) cannot be empty!", plugin, ability, prefix);
	
	return FF2_PushToAMS(client, pContext, plugin, ability, prefix);
}

public any Native_PushToAMS(Handle pContext, int Params)
{
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients) 
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%i)", client);
	
	char plugin[64]; GetNativeString(2, plugin, sizeof(plugin));
	char ability[64]; GetNativeString(3, ability, sizeof(ability));
	char prefix[6]; GetNativeString(4, prefix, sizeof(prefix));
	
	if (!plugin[0] || !ability[0] || !prefix[0])
		return ThrowNativeError(SP_ERROR_NATIVE, "plugin(%s)/ability(%s)/prefix(%s) cannot be empty!", plugin, ability, prefix);
	
	return FF2_PushToAMS(client, pContext, plugin, ability, prefix) != -1;
}

public any Native_GetAMSAbilities(Handle pContext, int Params)
{
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients) 
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%i)", client);
	
	return AMSData[client].hAbilities;
}

public any Native_IsAMSReadyFor(Handle pContext, int Params)
{
	int client = GetNativeCell(1);
	if(client <= 0 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%i)", client);
	
	return AMSData[client].hAbilities != null;
}

public any Native_IsAMSActive(Handle pContext, int Params)
{
	return FF2GameMode.GetPropAny("bAMSExists");
}


static void ResetPlayer(const int client)
{
	AMSSettings settings = AMSData[client].hAbilities;
	for(int i = settings.Length - 1; i >= 0; i--)
		delete view_as<AMSHash>(settings.Get(i));
			
	delete AMSData[client].hAbilities;
	AMSData[client].Pos = 0;
}
