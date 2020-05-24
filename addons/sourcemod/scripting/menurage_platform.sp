#include <sdkhooks>
#include <ff2_helper>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

#define MAXCLIENTS (MAXPLAYERS+1)
#define MAXABILITIES 248
#define this_ability_name "menu_platform"

StringMap Points[MAXCLIENTS];

bool MenuRage_Available;
bool IsMenuRage[12];

int button[MAXCLIENTS];
int max[MAXCLIENTS];
float Cooldown[MAXCLIENTS][20];
char Abilities[MAXCLIENTS][MAXABILITIES];

Handle PointsHud;
KeyValues BossKV[MAXCLIENTS];

GlobalForward MenuRage_OnProvokeRage;
GlobalForward MenuRage_OnTakeDamage;
GlobalForward MenuRage_OnPlayerDeath;

public Plugin myinfo = 
{
	name			= "[FF2]MenuRage Platform",
	author		= "01Pollux."
};

public APLRes AskPluginLoad2(Handle Plugin, bool late, char[] err, int err_max)
{
	CreateNative("FF2MenuRage_PeekValue", Native_PeekValue);
	CreateNative("FF2MenuRage_SetValue", Native_SetValue);
	CreateNative("FF2MenuRage_SetCooldown", Native_SetCooldown);
	CreateNative("FF2MenuRage_FindIndex", Native_FindIndex);
	CreateNative("FF2MenuRage_IsActive", Native_IsActive);
	CreateNative("FF2MenuRage_HasAbility", Native_HasAbiltiy);
	CreateNative("FF2MenuRage_DoAbility", Native_DoAbiltiy);
	MenuRage_OnProvokeRage = new GlobalForward("FF2MenuRage_OnStartRage", ET_Hook, Param_Cell, Param_CellByRef, Param_String, Param_String);
	MenuRage_OnTakeDamage = new GlobalForward("FF2MenuRage_OnTakeDamageAlive", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	MenuRage_OnPlayerDeath = new GlobalForward("FF2MenuRage_OnPlayerDeath", ET_Hook, Param_Cell, Param_Cell);
	RegPluginLibrary("FF2MenuRage");
}

public void OnPluginStart2()
{
	HookEvent("player_death", Post_PlayerDeath, EventHookMode_Post);
	HookEvent("player_hurt", Post_PlayerHurt, EventHookMode_Post);
	HookEvent("arena_round_start", Post_RoundStart, EventHookMode_Post);
	HookEvent("arena_win_panel", Post_RoundEnd, EventHookMode_Post);
	PointsHud = CreateHudSynchronizer();
	
	if(IsRoundActive())
		Post_RoundStart(null, "plugin_lateload", false);
}

public void OnMapEnd()
{
	Post_RoundEnd(null, "plugin_unload", false);
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
		Action action = Plugin_Continue;
		Call_StartForward(MenuRage_OnPlayerDeath);
		Call_PushCell(client);
		Call_PushCell(victim);
		Call_Finish(action);
		if(action != Plugin_Continue)
			return;
		
		FF2Prep player = FF2Prep(client);
		int calcpts = GetValue(client, "points") + player.GetArgI(this_plugin_name, this_ability_name, "gain per kill", 11, 45);
		if(calcpts > max[client])
			calcpts = max[client];
		
		Points[client].SetValue("points", calcpts);
	}
}

public void Post_RoundStart(Event hEvent, const char[] Name, bool broadcast)
{
	for(int x; x <= MaxClients; x++)
	{
		if(!ValidatePlayer(x, Any))
			continue;
			
		FF2Prep player = FF2Prep(x);
		if(player.HasAbility(this_plugin_name, this_ability_name))
		{
			int client = player.Index;
			MenuRage_Available = true;
			button[client] = player.GetButton(this_plugin_name, this_ability_name, "button", 1, IN_RELOAD);
			max[client] = player.GetArgI(this_plugin_name, this_ability_name, "max pts", 9, 350);
			
			Points[client] = new StringMap();
			BossKV[client] = FF2_GetSpecialKV2(x);
			
			char[] stack = new char[246];
			static char buffer[36];
			for(int y = 1; y < 30; y++)
			{
				BossKV[client].Rewind();
				FormatEx(buffer, sizeof(buffer), "ability%i", y);
				if(!BossKV[client].JumpToKey(buffer))
					break;
					
				if(BossKV[client].JumpToKey("menu")){
					if(!stack[0]) 
						FormatEx(stack, 246, buffer);
					else Format(stack, 246, "%s - %s", stack, buffer);
				}
			}
			if(!stack[0])
				continue;
			
			FormatEx(Abilities[client], sizeof(Abilities[]), stack);
			Points[client].SetValue("max", player.GetArgI(this_plugin_name, this_ability_name, "max abilities", 2, 0));
			Points[client].SetValue("points", 0);
			Points[client].SetValue("damage", 0);
			Points[client].SetValue("stack", 0);
			
			SDKHook(client, SDKHook_PostThinkPost, Post_ClientThinkPost);
		}
	}
}

public void Post_RoundEnd(Event hEvent, const char[] Name, bool broadcast)
{
	if(MenuRage_Available)
	{
		for (int x = 1; x <= MaxClients; x++) {
			if(Points[x] != null) {
				delete Points[x];
				delete BossKV[x];
			}
		}
		MenuRage_Available = false;
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
	
	if(Points[client] != null)
	{
		Action action = Plugin_Continue;
		Call_StartForward(MenuRage_OnTakeDamage);
		Call_PushCell(client);
		Call_PushCell(attacker);
		Call_PushCell(damage);
		Call_Finish(action);
		if(action != Plugin_Continue)
			return;
		
		FF2Prep player = FF2Prep(client);
		int calcdmg = GetValue(client, "damage") + damage;
		int calcpts = GetValue(client, "points");
		int dmg = player.GetArgI(this_plugin_name, this_ability_name, "damage taken", 5, 1000);
		int pts = player.GetArgI(this_plugin_name, this_ability_name, "damage pts", 6, 50);
		
		while(calcdmg >= dmg)
		{
			calcdmg -= dmg;
			calcpts += pts;
		}
		if(calcpts >= max[client])
			calcpts = max[client];
		
		Points[client].SetValue("points", calcpts);
		Points[client].SetValue("damage", calcdmg);
		PrintHintText(client, "%i/%i", calcdmg, dmg);
	}
}

public Action FF2_OnLoseLife(int boss, int &lives, int maxLives)
{
	FF2Prep player = FF2Prep(boss, false);
	if(!player.HasAbility(this_plugin_name, this_ability_name))
		return Plugin_Continue;
	if(!lives)
		return Plugin_Continue;
	
	int client = player.Index;
	int calcpts = GetValue(client, "points");
	int pts = player.GetArgI(this_plugin_name, this_ability_name, "life loss", 7, 1000);
	
	char[][] mult = new char[maxLives][4];
	static char buffer[32];
	player.GetArgS(this_plugin_name, this_ability_name, "loss mult", 8, buffer, sizeof(buffer));
	ExplodeString(buffer, " - ", mult, maxLives, 4);

	calcpts += pts * StringToInt(mult[maxLives - lives]);
	
	if(calcpts >= max[client]) {
		calcpts = max[client];
	}
	Points[client].SetValue("points", calcpts);
	return Plugin_Continue;
}


float NextHud[MAXCLIENTS];

public void Post_ClientThinkPost(int client)
{
	if(NextHud[client] > GetGameTime())
		return;
	if(IsRoundActive())
	{
		static char buffer[128];
		FF2Prep player = FF2Prep(client);
		player.GetArgS(this_plugin_name, this_ability_name, "hud format", 4, buffer, sizeof(buffer));
		player.PrepareString(0, buffer, sizeof(buffer));
		SetHudTextParams(-1.0, 0.73, 0.55, 255, 255, 255, 255);
		FF2_ShowSyncHudText(client, PointsHud, buffer, GetValue(client, "points"));
		NextHud[client] = GetGameTime() + 0.5;
	}
	else return;
}

public Action Menu_OnBossRunCmd(int client, int &buttons)
{
	if(Points[client] == null) {
		return Plugin_Continue;
	}
	
	if(!IsPlayerAlive(client))
		return Plugin_Continue;
				
	if(buttons & button[client])
	{
		buttons &= ~button[client];
		StartMenu(client);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

void StartMenu(int client)
{
	static char buffer[246];
	char[][] ability = new char[GetValue(client, "max") + 1][16];
	FF2Prep player = FF2Prep(client);
	
	Menu Main = new Menu(OnRageSelect);
	
	player.GetArgS(this_plugin_name, this_ability_name, "menu name", 3, buffer, sizeof(buffer));
	player.PrepareString(0, buffer, sizeof(buffer));
	Main.SetTitle(buffer, GetValue(client, "points"));
	
	ExplodeString(Abilities[client], " - ", ability, GetValue(client, "max") + 1, 16);
	
	for(int x; x < GetValue(client, "max"); x++)
	{
		BossKV[client].Rewind();
		BossKV[client].JumpToKey(ability[x]);
		BossKV[client].JumpToKey("menu");
		BossKV[client].GetString("rage title", buffer, sizeof(buffer), "UNKNWON");
		Main.AddItem(ability[x], buffer, Cooldown[client][x]  > GetGameTime() ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	}
	Main.Display(client, 10);
}

public int OnRageSelect(Menu Main, MenuAction action, int client, int option)
{
	switch(action) {
		case MenuAction_Select: {
			if(!IsPlayerAlive(client))
				return;
			
			int size = GetValue(client, "max");
			
			static char buffer[246], item[16];
			char[][] ability = new char[size][16];
			
			Main.GetItem(option, item, sizeof(item));
			
			ExplodeString(Abilities[client], " - ", ability, size, 16);
			for (int x ; x < size; x++)
			{
				if(!strcmp(item, ability[x], false))
				{
					Points[client].SetValue("stack", x);
					
					BossKV[client].Rewind();
					BossKV[client].JumpToKey(item);
					BossKV[client].JumpToKey("menu");
					
					Panel Mini = new Panel();
					
					BossKV[client].GetString("rage title", buffer, sizeof(buffer), "No Title");
					Mini.SetTitle(buffer);
					
					BossKV[client].GetString("rage info", buffer, sizeof(buffer), "No Description");
					ReplaceString(buffer, sizeof(buffer), "\\n", "\n");
					Mini.DrawText(buffer);
					
					int cur = GetValue(client, "points");
					
					Mini.DrawItem("Activate", cur >= BossKV[client].GetNum("rage cost") ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
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
			
			static char buffer[128], AbilityInfo[2][32];
			switch(option) {
				case 1: {
					Action act = Plugin_Continue;
					
					FF2Prep player = FF2Prep(client);
					int boss = player.boss;
					int index = GetValue(client, "stack");
					char[][] ability = new char[index + 1][16];
				
					BossKV[client].Rewind();
					ExplodeString(Abilities[client], " - ", ability, index + 1, 16);
					
					BossKV[client].JumpToKey(ability[index]);
					BossKV[client].JumpToKey("menu");
					int pts = GetValue(client, "points");
					int cost = BossKV[client].GetNum("rage cost");
					float cd = BossKV[client].GetFloat("rage cooldown", 10.0);
					BossKV[client].GoBack();
					
					BossKV[client].GetString("name", AbilityInfo[0], sizeof(AbilityInfo[]));
					
					Call_StartForward(MenuRage_OnProvokeRage);
					Call_PushCell(boss);
					Call_PushCellRef(pts);
					
					BossKV[client].GetString("plugin_name", AbilityInfo[1], sizeof(AbilityInfo[]));
					
					Call_PushString(AbilityInfo[1]);
					Call_PushString(AbilityInfo[0]);
					Call_Finish(act);
					
					if(act == Plugin_Stop) {
						return;
					}
					
					Cooldown[client][index] = cd + GetGameTime();
					IsMenuRage[boss] = true;
					CreateTimer(0.205, Timer_ResetRage, boss, TIMER_FLAG_NO_MAPCHANGE);
					
					if(act != Plugin_Continue) {
						Points[client].SetValue("points", pts - cost);
						return;
					}
					
					player.DoAbility(false, AbilityInfo[1], AbilityInfo[0], 4, 0);
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
	IsMenuRage[boss] = false;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!IsRoundActive()) {
		return Plugin_Continue;
	}
	
	if(MenuRage_Available && ValidatePlayer(client, IsBoss)) {
		return Menu_OnBossRunCmd(client, buttons);
	}
	return Plugin_Continue;
}

public void FF2_PreAbility(int boss, const char[] Plugin_Name, const char[] Ability_Name, int slot, bool &enabled)
{
	if(IsMenuRage[boss])
		return;
	
	if(!strcmp(Ability_Name, this_ability_name) && !strcmp(Plugin_Name, this_plugin_name)) 
	{
		FF2Prep player = FF2Prep(boss, false);
		if(player.HasAbility(this_plugin_name, this_ability_name)) 
		{
			FF2_SetBossCharge(boss, 0, 0.0);
			enabled = false;
			int client = BossToClient(boss);
			int calcpts = GetValue(client, "points") + player.GetArgI(this_plugin_name, this_ability_name, "gain per rage", 10, 60);
			if(calcpts >= max[client])
				calcpts = max[client];
			Points[client].SetValue("points", calcpts);
			return;
		}
	}
}

public Action FF2_OnAbility2(int iBoss, const char[] Plugin_Name, const char[] Ability_Name, int status) {
	return Plugin_Continue;
}

stock any GetValue(int client, const char[] index)
{
	if(Points[client] == null)
		return 0;
	
	any val;
	Points[client].GetValue(index, val);
	return val;
}

stock KeyValues FF2_GetSpecialKV2(int boss, int index=0)
{
	return view_as<KeyValues>(FF2_GetSpecialKV(boss, index));
}

//Natives
public any Native_PeekValue(Handle Plugin, int Params)
{
	int client = GetNativeCell(1);
	if(Points[client] == null)
		return -999;
	
	char context[16];
	GetNativeString(2, context, sizeof(context));
	
	return GetValue(client, context);
}

public int Native_SetValue(Handle Plugin, int Params)
{
	int client = GetNativeCell(1);
	if(Points[client] == null)
		return false;
	
	char context[16];
	GetNativeString(2, context, sizeof(context));
	if(strlen(context) < 3)
		return false;
	
	return Points[client].SetValue(context, GetNativeCell(3));
}

public int Native_SetCooldown(Handle Plugin, int Params)
{
	Cooldown[GetNativeCell(1)][GetNativeCell(2)] = GetNativeCell(3);
	return 0;
}

public int Native_FindIndex(Handle Plugin, int Params)
{
	int client = GetNativeCell(1);
	if(BossKV[client] == null)
		return -1;
	
	int size = GetValue(client, "max");
	static char buffer[246], Info[64];
	char[][] ability = new char[size][16];
	
	ExplodeString(Abilities[client], " - ", ability, size, 16);
	
	GetNativeString(3, buffer, sizeof(buffer));
	
	for (int x; x < size; x++)
	{
		BossKV[client].Rewind();
		BossKV[client].JumpToKey(ability[x]);
		BossKV[client].GetString("name", Info, sizeof(Info));
		if(!strcmp(buffer, Info))
		{
			BossKV[client].GetString("plugin_name", Info, sizeof(Info));
			GetNativeString(2, buffer, sizeof(buffer));
			if(!strcmp(Info, buffer))
				return x;
		}
	}
	return -1;
}

public int Native_IsActive(Handle Plugin, int Params)
{
	return MenuRage_Available;
}

public int Native_HasAbiltiy(Handle Plugin, int Params)
{
	int client = GetNativeCell(1);
	if(BossKV[client] == null)
		return false;
	return Points[client] != null;
}

public any Native_DoAbiltiy(Handle Plugin, int Params)
{
	int client = GetNativeCell(1);
	if(Points[client] == null || BossKV[client] == null)
		return false;
	
	int pts = GetNativeCell(2);
	if(pts < GetValue(client, "points"))
		return false;
	
	char Plugin_Name[48], Ability_Name[48];
	
	GetNativeString(3, Plugin_Name, sizeof(Plugin_Name));
	GetNativeString(4, Ability_Name, sizeof(Ability_Name));
	if(!Plugin_Name[0] || !Ability_Name[0])
		return false;
	
	int slot = GetNativeCell(5);
	int buttonmode = GetNativeCell(6);
	Points[client].SetValue("points", GetValue(client, "points") - pts);
	
	int boss = FF2_GetBossIndex(client);
	IsMenuRage[boss] = true;
	CreateTimer(0.205, Timer_ResetRage, boss, TIMER_FLAG_NO_MAPCHANGE);
	FF2_DoAbility(boss, Plugin_Name, Ability_Name, slot, buttonmode);
	
	return true;
}

#file "[FF2]MenuRage Platform"
