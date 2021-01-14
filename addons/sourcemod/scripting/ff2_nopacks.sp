/*
	Expose FF2FLAG_ALLOW_AMMO_PICKUPS and FF2FLAG_ALLOW_HEALTH_PICKUPS flags from other versions of FF2
	
	FF2Player.bNoHealthPacks
	FF2Player.bNoAmmoPacks
*/

#include <sdkhooks>
#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

FF2GameMode ff2_gm;

public Plugin myinfo = 
{
	name		= "[FF2] Disallow ammo and healthpack pickup",
	author		= "01Pollux",
	version 	= "1.0",
};

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] err, int maxlen)
{
	RegPluginLibrary("FF2_AMMO_AND_HEALTH");
}

public void OnLibraryAdded(const char[] name)
{
	if( !strcmp(name, "VSH2") ) {
		VSH2_Hook(OnRoundStart, _OnRoundStart);
		
		if( ff2_gm.RoundState == StateRunning ) {
			VSH2Player[] pl2 = new VSH2Player[MaxClients];
			int pl = FF2GameMode.GetBosses(pl2);
			_OnRoundStart(pl2, pl, pl2, 0);
		}
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if( !strcmp(name, "VSH2") ) {
		VSH2_Unhook(OnRoundStart, _OnRoundStart);
	}
}

public void OnEntityCreated(int entity, const char[] clsname)
{
	if( !ff2_gm.FF2IsOn )
		return;
	if( StrContains(clsname, "item_healthkit") != -1 || 
	    StrContains(clsname, "item_ammopack") != -1 || 
	    !strcmp(clsname, "tf_ammo_pack") )
	    SDKHook(entity, SDKHook_Spawn, _OnItemSpawned);
}

public void _OnItemSpawned(int entity)
{
	SDKHook(entity, SDKHook_StartTouch, _OnItemPickup);
	SDKHook(entity, SDKHook_Touch, 		_OnItemPickup);
}

public Action _OnItemPickup(int entity, int client)
{
	if( 0 < client <= MaxClients && IsClientInGame(client) )
	{
		FF2Player player = FF2Player(client);
		
		static char classname[64];
		GetEntityClassname(entity, classname, sizeof(classname));
		if( !StrContains(classname, "item_healthkit") && player.GetPropAny("bNoHealthPacks") )
			return Plugin_Handled;
		else if( (!StrContains(classname, "item_ammopack") ||
				 StrEqual(classname, "tf_ammo_pack")) && player.GetPropAny("bNoAmmoPacks") )
			return Plugin_Handled;
	}
	return Plugin_Continue;
}


public void _OnRoundStart(const VSH2Player[] bosses, const int boss_count, const VSH2Player[] red_players, const int red_count)
{
	FF2Player player;
	for( int i = 0; i < red_count; i++ ) {
		player = ToFF2Player(red_players[i]);
		ResetPlayer(player);
	}
	for( int i = 0; i < boss_count; i++ ) {
		player = ToFF2Player(bosses[i]);
		ResetPlayer(player);
	}
}


public void OnClientPutInServer(int client)
{
	RequestFrame(_NextFrame_ResetPlayer, client);
}

void _NextFrame_ResetPlayer(int client)
{
	if( !ff2_gm.FF2IsOn ) {
		FF2Player player = FF2Player(client);
		ResetPlayer(player);
	}
}

void ResetPlayer(const FF2Player player)
{
	player.SetPropAny("bNoHealthPacks", false);
	player.SetPropAny("bNoAmmoPacks", false);
}
