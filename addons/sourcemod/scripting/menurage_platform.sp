#include <ff2_helper>
#include <ff2ability>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define MAXABILITIES 20

bool MenuRage_Available;
bool BlockRage[MAXCLIENTS] = { true, ... };

int button[MAXCLIENTS];
int max[MAXCLIENTS];
float Cooldown[MAXCLIENTS][MAXABILITIES];

enum {
	PreRoundStart,
	OnProvokeRage,
	OnTakeDamage,
	OnPlayerDeath,
	
	MAX_FORWARDS
};
GlobalForward Forwards[MAX_FORWARDS];

#include "include/menu_helper.sp"

public Plugin myinfo = 
{
	name		= "[FF2]MenuRage Platform",
	author		= "01Pollux."
};

public APLRes AskPluginLoad2(Handle Plugin, bool late, char[] err, int err_max)
{
	/*
	Forwards[PreRoundStart] = new GlobalForward("FF2MenuRage_PreRoundStart", ET_Ignore, Param_Cell);
	Forwards[OnProvokeRage] = new GlobalForward("FF2MenuRage_OnStartRage", ET_Hook, Param_Cell, Param_CellByRef, Param_CellByRef, Param_String, Param_String);
	Forwards[OnTakeDamage] = new GlobalForward("FF2MenuRage_OnTakeDamageAlive", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	Forwards[OnPlayerDeath] = new GlobalForward("FF2MenuRage_OnPlayerDeath", ET_Hook, Param_Cell, Param_Cell);
	
	CreateNative("FF2MenuRage_GetHashMap", Native_GetHashMap);
	CreateNative("FF2MenuRage_PeekValue", Native_PeekValue);
	CreateNative("FF2MenuRage_SetValue", Native_SetValue);
	CreateNative("FF2MenuRage_SetCooldown", Native_SetCooldown);
	CreateNative("FF2MenuRage_IsActive", Native_IsActive);
	CreateNative("FF2MenuRage_HasAbility", Native_HasAbiltiy);
	CreateNative("FF2MenuRage_DoAbility", Native_DoAbiltiy);
	
	RegPluginLibrary("FF2MenuRage");
	*/
	Format(err, err_max, "Unfinished");
	return APLRes_Failure;
}

public void OnPluginStart()
{
	HookEvent("player_death", Post_PlayerDeath, EventHookMode_Post);
	HookEvent("player_hurt", Post_PlayerHurt, EventHookMode_Post);
	HookEvent("arena_round_start", Post_RoundStart, EventHookMode_Post);
	HookEvent("arena_win_panel", Post_RoundEnd, EventHookMode_Post);
	
	PointsHud = CreateHudSynchronizer();
}

public void Post_RoundStart(Event hEvent, const char[] Name, bool broadcast)
{
	if(!IsRoundActive()) {
		return;
	}
	
	FF2Prep player;
	int client;
	for(int x; ; x++) {
		player = FF2Prep(x, false);
		client = player.Index;
		if(!client) {
			break;
		}
		
		if(!FF2CreateMenu(player)) {
			continue;
		}
		
		Points[client] = new PointsMap(BossMap[client].GetInt("max pts", 9001));
		button[client] = BossMap[client].GetButton("button", IN_RELOAD);
		max[client] = BossMap[client].GetInt("hook->num");
		SDKHook(client, SDKHook_PostThinkPost, Post_ClientThinkPost);
		
		Call_StartForward(Forwards[PreRoundStart]);
		Call_PushCell(client);
		Call_Finish();
	}
}

public void Post_RoundEnd(Event hEvent, const char[] Name, bool broadcast)
{
	if(MenuRage_Available)
	{
		for (int x = 1; x <= MaxClients; x++) {
			if(Points[x]) {
				Points[x].Purge();
				delete BossMap[x];
				SDKUnhook(x, SDKHook_PostThinkPost, Post_ClientThinkPost);
			}
		}
		MenuRage_Available = false;
	}
}

public void Post_PlayerDeath(Event hEvent, const char[] Name, bool broadcast)
{
	if(!MenuRage_Available)
		return;
	
	if(!IsRoundActive())
		return;
	
	if(hEvent.GetInt("death_flags") & 0x20)
		return;
	
	int victim = GetClientOfUserId(hEvent.GetInt("userid"));
	if(Points[victim] != null)
		return;
		
	int client = GetClientOfUserId(hEvent.GetInt("attacker"));
	if(!ValidatePlayer(client, IsBoss))
		return;
	
	if(Points[client] !=null && ValidatePlayer(victim, Any))
	{
		Call_StartForward(Forwards[OnPlayerDeath]);
		Call_PushCell(client);
		Call_PushCell(victim);
		Action action = Plugin_Continue;
		Call_Finish(action);
		if(action >= Plugin_Handled)
			return;
		
		int calcpts = Points[client].points + BossMap[client].GetInt("gain per kill");
		if(calcpts > Points[client].max)
			calcpts = Points[client].max;
		
		Points[client].points = calcpts;
	}
}

public void Post_PlayerHurt(Event hEvent, const char[] sName, bool bBroadcast)
{
	if(!IsRoundActive())
		return;
	
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if(!ValidatePlayer(client, IsBoss))
		return;
	
	int attacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	if(client == attacker)
		return;
	
	int damage = hEvent.GetInt("damageamount");
	if(damage <= 0)
		return;
	
	if(Points[client] != null) {
		Call_StartForward(Forwards[OnTakeDamage]);
		Call_PushCell(client);
		Call_PushCell(attacker);
		Call_PushCell(damage);
		Action action = Plugin_Continue;
		Call_Finish(action);
		if(action != Plugin_Continue)
			return;
		
		int calcdmg = Points[client].damage + damage;
		int calcpts = Points[client].points;
		int dmg = BossMap[client].GetInt("damage taken");
		int pts = BossMap[client].GetInt("damage pts");
		
		while(calcdmg >= dmg) {
			calcdmg -= dmg;
			calcpts += pts;
		}
		if(calcpts >= Points[client].max)
			calcpts = Points[client].max;
		
		Points[client].points = calcpts;
		Points[client].damage = calcdmg;
		PrintHintText(client, "%i/%i", calcdmg, dmg);
	}
}

public Action FF2_OnLoseLife(int boss, int& lives, int maxLives)
{
	if(!lives) {
		return Plugin_Continue;
	}
	
	int client = BossToClient(boss);
	int calcpts = Points[client].points;
	int pts = BossMap[client].GetInt("life loss", 1000);
	
	char[][] mult = new char[maxLives][4];
	static char buffer[32];
	if(!BossMap[client].GetString("loss mult", buffer, sizeof(buffer))) {
		return Plugin_Continue;
	}
	
	ExplodeString(buffer, " - ", mult, maxLives, 4);

	calcpts += pts * StringToInt(mult[maxLives - lives]);
	
	if(calcpts >= Points[client].max) {
		calcpts = Points[client].max;
	}
	Points[client].points = calcpts;
	return Plugin_Continue;
}


static float NextHud[MAXCLIENTS];
public void Post_ClientThinkPost(int client)
{
	if(NextHud[client] > GetGameTime())
		return;
	if(IsRoundActive())
	{
		static char buffer[128];
		BossMap[client].GetString("hud format", buffer, sizeof(buffer));
		ReplaceString(buffer, strlen(buffer), "\\n", "\n");
		SetHudTextParams(-1.0, 0.73, 0.55, 255, 255, 255, 255);
		FF2_ShowSyncHudText(client, PointsHud, buffer, Points[client].points);
		NextHud[client] = GetGameTime() + 0.5;
	}
	else return;
}

public Action Menu_OnBossRunCmd(int client, int& buttons)
{
	if(!Points[client]) {
		return Plugin_Continue;
	}
	
	if(!IsPlayerAlive(client))
		return Plugin_Continue;
				
	if(buttons & button[client])
	{
		buttons &= ~button[client];
		StartMenu(client);
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

void StartMenu(int client)
{
	static char buffer[126];
	char num[2];
	char[] key = new char[48];
	
	Menu Main = new Menu(OnRageSelect);
	
	BossMap[client].GetString("menu name", buffer, sizeof(buffer));
	ReplaceString(buffer, strlen(buffer), "\\n", "\n");
	Main.SetTitle(buffer, Points[client].points);
	
	for(int x = 1; x <= max[client]; x++)
	{
		IntToString(x, num, sizeof(num));
		FormatEx(key, 48, "hook->%i->rage title", x);
		BossMap[client].GetString(key, buffer, sizeof(buffer));
		Main.AddItem(num, buffer, Cooldown[client][x] > GetGameTime() ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	}
	Main.Display(client, 10);
}

public int OnRageSelect(Menu Main, MenuAction action, int client, int option)
{
	switch(action) {
		case MenuAction_Select: {
			if(!IsPlayerAlive(client))
				return;
			
			int size = max[client];
			
			static char buffer[126], item[16];
			char num[2];
			char[] key = new char[48];
			
			Main.GetItem(option, item, sizeof(item));
			
			for (int x ; x <= size; x++)
			{
				IntToString(x, num, sizeof(num));
				if(!strcmp(item, num, false))
				{
					Points[client].stack = x;
					
					Panel Mini = new Panel();
					
					FormatEx(key, 48, "hook->%i->rage title", x);
					BossMap[client].GetString(key, buffer, sizeof(buffer));
					Mini.SetTitle(buffer);
					
					FormatEx(key, 48, "hook->%i->rage info", x);
					BossMap[client].GetString(key, buffer, sizeof(buffer));
					ReplaceString(buffer, sizeof(buffer), "\\n", "\n");
					Mini.DrawText(buffer);
					
					int cur = Points[client].points;
					
					FormatEx(key, 48, "hook->%i->rage cost", x);
					Mini.DrawItem("Activate", cur >= BossMap[client].GetInt(key) ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
					Mini.DrawItem("Cancel");
					Mini.Send(client, On_RageActivate, 30);
					delete Mini;
					break;
				}
			}
		}
		case MenuAction_End:{
			delete Main;
		}
	}
}

public int On_RageActivate(Menu Mini, MenuAction action, int client, int option)
{
	switch(action)
	{
		case MenuAction_Select:{
			if(!IsPlayerAlive(client))
				return;
			
			static char buffer[128], AbilityInfo[2][48];
			switch(option) {
				case 1: {
					
					FF2Prep player = FF2Prep(client);
					int boss = player.boss;
					char[] key = new char[48];
					int idx = Points[client].stack;
					int pts = Points[client].points;
					FormatEx(key, 48, "hook->%i->rage cost", idx);
					int cost = BossMap[client].GetInt(key);
					FormatEx(key, 48, "hook->%i->rage cooldown", idx);
					float cd = BossMap[client].GetFloat(key);
					
					FormatEx(key, 48, "hook->%i->name", idx);
					BossMap[client].GetString(key, AbilityInfo[0], sizeof(AbilityInfo[]));
					
					FormatEx(key, 48, "hook->%i->plugin_name", idx);
					BossMap[client].GetString(key, AbilityInfo[1], sizeof(AbilityInfo[]));
					
					Call_StartForward(Forwards[OnProvokeRage]);
					Call_PushCell(boss);
					Call_PushCellRef(pts);
					Call_PushCellRef(cost);
					Call_PushString(AbilityInfo[1]);
					Call_PushString(AbilityInfo[0]);
					Action act = Plugin_Continue;
					Call_Finish(act);
					
					if(act == Plugin_Stop) {
						return;
					}
					
					Cooldown[client][Points[client].stack] = cd + GetGameTime();
					BlockRage[boss] = false;
					CreateTimer(0.205, Timer_ResetRage, boss, TIMER_FLAG_NO_MAPCHANGE);
					
					Points[client].points = pts - cost;
					if(act == Plugin_Handled)
						return;
					
					player.ForceAbility(AbilityInfo[1], AbilityInfo[0]);
				}
				case 2:{
					if(FF2_RandomSound("sound_exit_menu", buffer, sizeof(buffer)))
						EmitSoundToClient(client, buffer);
				}
			}
		}
		case MenuAction_End :{
			delete Mini;
		}
	}
}

public Action Timer_ResetRage(Handle Timer, int boss)
{
	BlockRage[boss] = true;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, 
							float vel[3], float angles[3], int& weapon, 
							int &subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(!IsRoundActive()) {
		return Plugin_Continue;
	}
	
	if(MenuRage_Available && ValidatePlayer(client, IsBoss)) {
		Menu_OnBossRunCmd(client, buttons);
	}
	return Plugin_Continue;
}

public void FF2_PreAbility(int boss, const char[] Plugin_Name, const char[] Ability_Name, int slot, bool &enabled)
{
	if(!MenuRage_Available) {
		return;
	}
	int client = BossToClient(boss);
	if(!Points[client]) {
		return;
	}
	if(BlockRage[boss]) {
		return;
	}
	
	FF2_SetBossCharge(boss, 0, 0.0);
	enabled = false;
	int calcpts = Points[client].points + BossMap[client].GetInt("gain per rage");
	if(calcpts >= Points[client].max)
		calcpts = Points[client].max;
	Points[client].points = calcpts;
}


public any Native_GetHashMap(Handle pContext, int Params)
{
	int client = GetNativeCell(1);
	if(!BossMap[client]) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index \"%i\", user doesn't have a menu rage.", client);
	}
	return BossMap[client];
}

public any Native_PeekValue(Handle pContext, int Params)
{
	int client = GetNativeCell(1);
	if(!Points[client]) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index \"%i\", user doesn't have a menu rage.", client);
	}
	
	char context[16];
	GetNativeString(2, context, sizeof(context));
	
	int val;
	return Points[client].GetValue(context, val) ? val:ThrowNativeError(SP_ERROR_NATIVE, "Invalid context name : \"%s\"", context);
}

public int Native_SetValue(Handle pContext, int Params)
{
	int client = GetNativeCell(1);
	if(!Points[client]) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index \"%i\", user doesn't have a menu rage.", client);
	}
	
	char context[16];
	GetNativeString(2, context, sizeof(context));
	if(strlen(context) < 3) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Empty context name : \"%s\"", context);
	}
	
	return Points[client].SetValue(context, GetNativeCell(3));
}

public int Native_SetCooldown(Handle pContext, int Params)
{
	int client = GetNativeCell(1);
	if(!Points[client]) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index \"%i\", user doesn't have a menu rage.", client);
	}
	int index = GetNativeCell(2);
	if(index <= 0 || Points[client].stack < index) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid rage index \"%i\"", index);
	}
	Cooldown[client][index] = GetNativeCell(3);
	return 0;
}

public int Native_IsActive(Handle pContext, int Params)
{
	return MenuRage_Available;
}

public int Native_HasAbiltiy(Handle pContext, int Params)
{
	int client = GetNativeCell(1);
	if(!BossMap[client])
		return false;
	return Points[client] != null;
}

public any Native_DoAbiltiy(Handle pContext, int Params)
{
	int client = GetNativeCell(1);
	if(!Points[client] || !BossMap[client]) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index \"%i\", user doesn't have a menu rage.", client);
	}
	
	int pts = GetNativeCell(2);
	if(pts < Points[client].points)
		return false;
	
	char Plugin_Name[48], Ability_Name[48];
	
	GetNativeString(3, Plugin_Name, sizeof(Plugin_Name));
	GetNativeString(4, Ability_Name, sizeof(Ability_Name));
	if(!Plugin_Name[0] || !Ability_Name[0]) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Empty ability/plugin name : \"%s/%s\".", Plugin_Name, Ability_Name);
	}
	
	int slot = GetNativeCell(5);
	FF2Prep player = FF2Prep(client);
	int boss = player.boss;
	
	Points[client].points -= pts;
	
	BlockRage[boss] = false;
	CreateTimer(0.205, Timer_ResetRage, boss, TIMER_FLAG_NO_MAPCHANGE);
	
	return player.ForceAbility(Plugin_Name, Ability_Name, slot);
}

#file "[FF2] MenuRage Platform"
