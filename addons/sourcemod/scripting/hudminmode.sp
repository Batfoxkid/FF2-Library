#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <colors>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <tf2items>
#define MB 3
#define ME 2048
public Plugin:myinfo = {
	name = "Freak Fortress 2: Minimalist HUD",
	author = "MasterOfTheXP",
	version = "1.0",
};
/*
This sub-plugin lets clients have their boss information be printed to them in what some would consider a neater fashion.
Bosses who enable this will see, on either the top or bottom of their screens, their health on the left and their rage on the right, as well as their jump charge in the center.
*/

new miniHUD[MAXPLAYERS + 1];
new Handle:HPHUD;
new Handle:RageHUD;
new Handle:ChargeHUD;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	return APLRes_Success;
}

public OnPluginStart2()
{
	RegConsoleCmd("ff2hud", Command_hud, "ff2hud - Enable/disable the minimalist HUD.");
	RegConsoleCmd("halehud", Command_hud, "halehud - Enable/disable the minimalist HUD.");
	RegConsoleCmd("ff2_mhud", Command_hud, "ff2_mhud - Enable/disable the minimalist HUD.");
	
	CreateTimer(0.1, Timer_Millisecond);
	HPHUD = CreateHudSynchronizer();
	RageHUD = CreateHudSynchronizer();
	ChargeHUD = CreateHudSynchronizer();
}

public Action:Timer_Millisecond(Handle:timer)
{
	CreateTimer(0.1, Timer_Millisecond);
	if (FF2_GetRoundState() != 1) return Plugin_Handled;
	for (new z = 1; z <= GetMaxClients(); z++)
	{
		if (IsClientInGame(z) && miniHUD[z] > 0)
		{
			new a_index = FF2_GetBossIndex(z);
			if (a_index != -1) // client is Hale
			{
				new Hale = z;
				SetGlobalTransTarget(Hale);
				new bool:hudIsDisabled = false;
				if (FF2_GetFF2flags(Hale) & FF2FLAG_HUDDISABLED) hudIsDisabled = true;
				if (!hudIsDisabled) FF2_SetFF2flags(Hale, FF2_GetFF2flags(Hale)|FF2FLAG_HUDDISABLED);
				new Float:yPos;
				new Rage = RoundFloat(FF2_GetBossCharge(a_index, 0));
				new rageColour = 255;
				if (Rage == 100) rageColour = 64;
				if (miniHUD[Hale] == 1) yPos = 1.0;
				if (miniHUD[Hale] == 2) yPos = 0.0;
				SetHudTextParams(0.0, yPos, 0.2, 255, 255, 255, 255);
				ShowSyncHudText(Hale, HPHUD, "HP: %i", GetClientHealth(Hale));
				SetHudTextParams(1.0, yPos, 0.2, 255, rageColour, rageColour, 255);
				if (Rage != 100 && Rage > 0) ShowSyncHudText(Hale, RageHUD, "RAGE: %i!", Rage);
				if (Rage < 1) ShowSyncHudText(Hale, RageHUD, "RAGE: %i", Rage);
				if (Rage == 100) ShowSyncHudText(Hale, RageHUD, "Press TAUNT to RAGE.");
				new Charge = RoundFloat(FF2_GetBossCharge(a_index, 1));
				if (Charge > 0)
				{
					SetHudTextParams(-1.0, yPos, 0.2, 255, 255, 255, 255);
					ShowSyncHudText(Hale, ChargeHUD, "%i", Charge);
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action:Command_hud(client, args)
{
	if (client == 0)
	{
		PrintToServer("[FF2] The minimalist HUD cannot be enabled by Console.");
		return Plugin_Handled;
	}
	HUDMenu(client);
	return Plugin_Handled;
}



public Action:HUDMenu(client)
{
	new Handle:smMenu = CreatePanel();
	decl String:text[128];
	SetGlobalTransTarget(client);
	Format(text, 128, "Turn the minimalist HUD for bosses...");
	SetPanelTitle(smMenu, text);
	Format(text, 256, "On, place on bottom of screen");
	DrawPanelItem(smMenu, text);
	Format(text, 256, "On, place at top of screen");
	DrawPanelItem(smMenu, text);
	Format(text, 256, "Off, I want the normal boss HUD");
	DrawPanelItem(smMenu, text);
	SendPanelToClient(smMenu, client, HUDSelector, MENU_TIME_FOREVER);
	CloseHandle(smMenu);
	return Plugin_Handled;
}

public HUDSelector(Handle:menu, MenuAction:action, client, p2)
{
	if (action == MenuAction_Select)
	{
		if (p2 == 1 || p2 == 2)
		{
			miniHUD[client] = p2;
			CPrintToChat(client, "{olive}[FF2]{default} You've enabled the minimalist HUD.");
			if (FF2_GetBossIndex(client) == -1) CPrintToChat(client, "{olive}[FF2]{default} You'll see it the next time you're boss!");
		}
		if (p2 == 3)
		{
			miniHUD[client] = 0;
			CPrintToChat(client, "{olive}[FF2]{default} You've disabled the minimalist HUD.");
			FF2_SetFF2flags(client, FF2_GetFF2flags(client)-FF2FLAG_HUDDISABLED);
		}
		else return;
	}
}

public OnClientPutInServer(client)
{
	miniHUD[client] = 0;
}

public Action:FF2_OnAbility2(index, const String:plugin_name[], const String:ability_name[], action)
{
	return Plugin_Continue;
}