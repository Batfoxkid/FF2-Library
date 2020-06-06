#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name = "Freak Fortress 2: Damage Tracker",
	author = "MasterOfTheXP",
	version = "1.0",
};
/*
This plugin for a plugin (bwooong) allows clients to type "!ff2dmg <number 1 to 8>" to enable the damage tracker.
If a client enables it, the top X damagers will always be printed to the top left of their screen.
*/

int damageTracker[MAXPLAYERS + 1];
Handle damageHUD;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("ff2dmg", Command_damagetracker, "ff2dmg - Enable/disable the damage tracker.");
	RegConsoleCmd("haledmg", Command_damagetracker, "haledmg - Enable/disable the damage tracker.");
	
	CreateTimer(0.1, Timer_Millisecond);
	damageHUD = CreateHudSynchronizer();
}

public Action Timer_Millisecond(Handle timer)
{
	CreateTimer(0.1, Timer_Millisecond);
	if (FF2_GetRoundState() != 1) return Plugin_Handled;
	
	int highestDamage = 0;
	int highestDamageClient = -1;
	for (int z = 1; z <= MaxClients; z++)
	{
		if (IsClientInGame(z) && FF2_GetClientDamage(z) > highestDamage)
		{
			highestDamage = FF2_GetClientDamage(z);
			highestDamageClient = z;
		}
	}
	int secondHighestDamage = 0;
	int secondHighestDamageClient = -1;
	for (int z = 1; z <= MaxClients; z++)
	{
		if (IsClientInGame(z) && FF2_GetClientDamage(z) > secondHighestDamage && z != highestDamageClient)
		{
			secondHighestDamage = FF2_GetClientDamage(z);
			secondHighestDamageClient = z;
		}
	}
	int thirdHighestDamage = 0;
	int thirdHighestDamageClient = -1;
	for (int z = 1; z <= MaxClients; z++)
	{
		if (IsClientInGame(z) && FF2_GetClientDamage(z) > thirdHighestDamage && z != highestDamageClient && z != secondHighestDamageClient)
		{
			thirdHighestDamage = FF2_GetClientDamage(z);
			thirdHighestDamageClient = z;
		}
	}
	int fourthHighestDamage = 0;
	int fourthHighestDamageClient = -1;
	for (int z = 1; z <= MaxClients; z++)
	{
		if (IsClientInGame(z) && FF2_GetClientDamage(z) > fourthHighestDamage && z != highestDamageClient && z != secondHighestDamageClient && z != thirdHighestDamageClient)
		{
			fourthHighestDamage = FF2_GetClientDamage(z);
			fourthHighestDamageClient = z;
		}
	}
	int fifthHighestDamage = 0;
	int fifthHighestDamageClient = -1;
	for (int z = 1; z <= MaxClients; z++)
	{
		if (IsClientInGame(z) && FF2_GetClientDamage(z) > fifthHighestDamage && z != highestDamageClient && z != secondHighestDamageClient && z != thirdHighestDamageClient && z != fourthHighestDamageClient)
		{
			fifthHighestDamage = FF2_GetClientDamage(z);
			fifthHighestDamageClient = z;
		}
	}
	int sixthHighestDamage = 0;
	int sixthHighestDamageClient = -1;
	for (int z = 1; z <= MaxClients; z++)
	{
		if (IsClientInGame(z) && FF2_GetClientDamage(z) > sixthHighestDamage && z != highestDamageClient && z != secondHighestDamageClient && z != thirdHighestDamageClient && z != fourthHighestDamageClient && z != fifthHighestDamageClient)
		{
			sixthHighestDamage = FF2_GetClientDamage(z);
			sixthHighestDamageClient = z;
		}
	}
	int seventhHighestDamage = 0;
	int seventhHighestDamageClient = -1;
	for (int z = 1; z <= MaxClients; z++)
	{
		if (IsClientInGame(z) && FF2_GetClientDamage(z) > seventhHighestDamage && z != highestDamageClient && z != secondHighestDamageClient && z != thirdHighestDamageClient && z != fourthHighestDamageClient && z != fifthHighestDamageClient && z != sixthHighestDamageClient)
		{
			seventhHighestDamage = FF2_GetClientDamage(z);
			seventhHighestDamageClient = z;
		}
	}
	int eigthHighestDamage = 0;
	int eigthHighestDamageClient = -1;
	for (int z = 1; z <= MaxClients; z++)
	{
		if (IsClientInGame(z) && FF2_GetClientDamage(z) > eigthHighestDamage && z != highestDamageClient && z != secondHighestDamageClient && z != thirdHighestDamageClient && z != fourthHighestDamageClient && z != fifthHighestDamageClient && z != sixthHighestDamageClient && z != seventhHighestDamageClient)
		{
			eigthHighestDamage = FF2_GetClientDamage(z);
			eigthHighestDamageClient = z;
		}
	}
	for (int z = 1; z <= MaxClients; z++)
	{
		if (IsClientInGame(z) && !IsFakeClient(z) && damageTracker[z] > 0)
		{
			int a_index = FF2_GetBossIndex(z);
			if (a_index == -1) // client is not Hale
			{
				int userIsWinner = false;
				if (z == highestDamageClient) userIsWinner = true;
				if (damageTracker[z] > 1 && z == secondHighestDamageClient) userIsWinner = true;
				if (damageTracker[z] > 2 && z == thirdHighestDamageClient) userIsWinner = true;
				if (damageTracker[z] > 3 && z == fourthHighestDamageClient) userIsWinner = true;
				if (damageTracker[z] > 4 && z == fifthHighestDamageClient) userIsWinner = true;
				if (damageTracker[z] > 5 && z == sixthHighestDamageClient) userIsWinner = true;
				if (damageTracker[z] > 6 && z == seventhHighestDamageClient) userIsWinner = true;
				if (damageTracker[z] > 7 && z == eigthHighestDamageClient) userIsWinner = true;
				SetHudTextParams(0.0, 0.0, 0.2, 255, 255, 255, 255);
				SetGlobalTransTarget(z);
				char first[64];
				char second[64];
				char third[64];
				char fourth[64];
				char fifth[64];
				char sixth[64];
				char seventh[64];
				char eigth[64];
				char user[64];
				if (highestDamageClient != -1) Format(first, 64, "[1] %N : %i\n", highestDamageClient, highestDamage);
				if (highestDamageClient == -1) Format(first, 64, "[1]\n", highestDamageClient, highestDamage);
				if (damageTracker[z] > 1 && secondHighestDamageClient != -1) Format(second, 64, "[2] %N : %i\n", secondHighestDamageClient, secondHighestDamage);
				if (damageTracker[z] > 1 && secondHighestDamageClient == -1) Format(second, 64, "[2]\n", secondHighestDamageClient, secondHighestDamage);
				if (damageTracker[z] > 2 && thirdHighestDamageClient != -1) Format(third, 64, "[3] %N : %i\n", thirdHighestDamageClient, thirdHighestDamage);
				if (damageTracker[z] > 2 && thirdHighestDamageClient == -1) Format(third, 64, "[3]\n", thirdHighestDamageClient, thirdHighestDamage);
				if (damageTracker[z] > 3 && fourthHighestDamageClient != -1) Format(fourth, 64, "[4] %N : %i\n", fourthHighestDamageClient, fourthHighestDamage);
				if (damageTracker[z] > 3 && fourthHighestDamageClient == -1) Format(fourth, 64, "[4]\n", fourthHighestDamageClient, fourthHighestDamage);
				if (damageTracker[z] > 4 && fifthHighestDamageClient != -1) Format(fifth, 64, "[5] %N : %i\n", fifthHighestDamageClient, fifthHighestDamage);
				if (damageTracker[z] > 4 && fifthHighestDamageClient == -1) Format(fifth, 64, "[5]\n", fifthHighestDamageClient, fifthHighestDamage);
				if (damageTracker[z] > 5 && sixthHighestDamageClient != -1) Format(sixth, 64, "[6] %N : %i\n", sixthHighestDamageClient, sixthHighestDamage);
				if (damageTracker[z] > 5 && sixthHighestDamageClient == -1) Format(sixth, 64, "[6]\n", sixthHighestDamageClient, sixthHighestDamage);
				if (damageTracker[z] > 6 && seventhHighestDamageClient != -1) Format(seventh, 64, "[7] %N : %i\n", seventhHighestDamageClient, seventhHighestDamage);
				if (damageTracker[z] > 6 && seventhHighestDamageClient == -1) Format(seventh, 64, "[7]\n", seventhHighestDamageClient, seventhHighestDamage);
				if (damageTracker[z] > 7 && eigthHighestDamageClient != -1) Format(eigth, 64, "[8] %N : %i\n", eigthHighestDamageClient, eigthHighestDamage);
				if (damageTracker[z] > 7 && eigthHighestDamageClient == -1) Format(eigth, 64, "[8]\n", eigthHighestDamageClient, eigthHighestDamage);
				if (userIsWinner) Format(user, 64, " ");
				if (!userIsWinner) Format(user, 64, "---------\n[  ] %N : %i", z, FF2_GetClientDamage(z));
				if (z == secondHighestDamageClient && !userIsWinner) Format(user, 64, "---------\n[2] %N : %i", z, FF2_GetClientDamage(z));
				if (z == thirdHighestDamageClient && !userIsWinner) Format(user, 64, "---------\n[3] %N : %i", z, FF2_GetClientDamage(z));
				if (z == fourthHighestDamageClient && !userIsWinner) Format(user, 64, "---------\n[4] %N : %i", z, FF2_GetClientDamage(z));
				if (z == fifthHighestDamageClient && !userIsWinner) Format(user, 64, "---------\n[5] %N : %i", z, FF2_GetClientDamage(z));
				if (z == sixthHighestDamageClient && !userIsWinner) Format(user, 64, "---------\n[6] %N : %i", z, FF2_GetClientDamage(z));
				if (z == seventhHighestDamageClient && !userIsWinner) Format(user, 64, "---------\n[7] %N : %i", z, FF2_GetClientDamage(z));
				if (z == eigthHighestDamageClient && !userIsWinner) Format(user, 64, "---------\n[8] %N : %i", z, FF2_GetClientDamage(z));
				ShowSyncHudText(z, damageHUD, "%s%s%s%s%s%s%s%s%s", first, second, third, fourth, fifth, sixth, seventh, eigth, user);
			}
		}
	}
	return Plugin_Handled;
}

public Action Command_damagetracker(int client, int args)
{
	if (client == 0)
	{
		PrintToServer("[FF2] The damage tracker cannot be enabled by Console.");
		return Plugin_Handled;
	}
	if (args == 0)
	{
		char playersetting[3];
		if (damageTracker[client] == 0) playersetting = "Off";
		if (damageTracker[client] > 0) playersetting = "On";
		CPrintToChat(client, "{olive}[FF2]{default} The damage tracker is {olive}%s{default}.\n{olive}[FF2]{default} Change it by saying \"!ff2dmg on\" or \"!ff2dmg off\"!\n{olive}[FF2]{default} Or, specify a number (!ff2dmg <#>) for that many slots to track!", playersetting);
		return Plugin_Handled;
	}
	char arg1[64];
	int newval = 3;
	GetCmdArgString(arg1, sizeof(arg1));
	if (StrEqual(arg1,"off",false)) damageTracker[client] = 0;
	if (StrEqual(arg1,"on",false)) damageTracker[client] = 3;
	if (StrEqual(arg1,"0",false)) damageTracker[client] = 0;
	if (StrEqual(arg1,"of",false)) damageTracker[client] = 0;
	if (!StrEqual(arg1,"off",false) && !StrEqual(arg1,"on",false) && !StrEqual(arg1,"0",false) && !StrEqual(arg1,"of",false))
	{
		newval = StringToInt(arg1);
		char newsetting[3];
		if (newval > 8) newval = 8;
		if (newval != 0) damageTracker[client] = newval;
		if (newval != 0 && damageTracker[client] == 0) newsetting = "off";
		if (newval != 0 && damageTracker[client] > 0) newsetting = "on";
		CPrintToChat(client, "{olive}[FF2]{default} The damage tracker is now {lightgreen}%s{default}!", newsetting);
	}
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	damageTracker[client] = 0;
}
