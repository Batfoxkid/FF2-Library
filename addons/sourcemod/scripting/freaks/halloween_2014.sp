#define FF2_USING_AUTO_PLUGIN__OLD
#pragma semicolon 1


//#define DEBUG // allows for late load or mid round load

#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
//#include <freak_fortress_2_subplugin>
#include <tf2items>
#pragma newdecls required

#include "../characters/halloween_framework.inc"

#undef REQUIRE_PLUGIN
#include <tf2attributes>
#define REQUIRE_PLUGIN

#define MAX_BOSSES  3

#define ACTION_CONTINUE 0
#define ACTION_CHANGED  1
#define ACTION_HANDLED  2

#define MODEL_TRIGGER	"models/items/ammopack_small.mdl"

Handle chargeHUD;

////////////////////////////// Natives
bool gb_tf2attributes;

///////////////////////////// User Vars
int g_boss;
int g_BossUserid[MAX_BOSSES];
int g_bosstype;
int g_bossteam = view_as<int>(TFTeam_Blue);
int g_otherteam = view_as<int>(TFTeam_Red);

////////////////////////////// Utility Stuff
#define MAX_CUSTOMS 3
float gf_RageTime[MAX_CUSTOMS];

//////////////// BOSS MODULES
#define BOSS_NONE         0
#define BOSS_NONE_KEY ""

#define BOSS_MUMMY        1
#include "../characters/mummy.sp"

#define BOSS_GREYALIEN    2
#include "../characters/greyalien.sp"

#define BOSS_OOGIEBOOGIE  3
#include "../characters/oogieboogie.sp"

#define BOSS_FASTZOMBIE   4
#include "../characters/fastzombie.sp"

#define BOSS_SPECIAL_ORB          5
#include "../characters/orb.sp"

//#define BOSS_MULTISET	6
//#include "../characters/special_multiset.sp"

static const char gs_bosskeyarray[][] =  {
	BOSS_NONE_KEY,
	BOSS_MUMMY_KEY,
	BOSS_GREYALIEN_KEY,
	BOSS_OOGIEBOOGIE_KEY,
	BOSS_FASTZOMBIE_KEY,
	BOSS_SPECIAL_ORB_KEY,
//	BOSS_MULTISET_KEY,
};

public Plugin myinfo =  {
	name = "Freak Fortress 2: Boss Framework",
	author = "Friagram",
};

/*
public Action:FF2_OnMusic(String:path[], &Float:time)
{
	switch (g_bosstype)
	{
		case BOSS_MULTISET:return Vergil_OnMusic();
	}

	return Plugin_Continue;
}
*/

public Action FF2_OnAbility2(int index, const char[] plugin_name, const char[] ability_name, int action)
{
	//////////////// BOSS MODULES
	switch (g_bosstype)
	{
		case BOSS_MUMMY:Mummy_FF2_OnAbility2(ability_name);
		case BOSS_GREYALIEN:Greyalien_FF2_OnAbility2(index, ability_name);
		case BOSS_OOGIEBOOGIE:Oogieboogie_FF2_OnAbility2(index, ability_name, action);
		case BOSS_FASTZOMBIE:Fastzombie_FF2_OnAbility2(index, ability_name);
		case BOSS_SPECIAL_ORB:Special_Orb_FF2_OnAbility2(ability_name);
//		case BOSS_MULTISET:Multiset_FF2_OnAbility2(ability_name);
	}
	return Plugin_Continue;
}

public void OnPluginStart2()
{
	HookEvent("teamplay_round_start", event_round_start, EventHookMode_PostNoCopy);

	HookEvent("teamplay_round_active", event_round_active, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", event_round_active, EventHookMode_PostNoCopy);

	HookEvent("teamplay_round_win", event_round_end, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", event_round_end, EventHookMode_PostNoCopy);

	HookEvent("player_death", event_player_death, EventHookMode_Pre);

	chargeHUD = CreateHudSynchronizer();

	gb_tf2attributes = LibraryExists("tf2attributes");

	//////////////// BOSS MODULES
	Oogieboogie_OnPluginStart2();

	for (int i = 1; i <= MaxClients; i++) // late load
	{
		if (IsClientInGame(i))
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "tf2attributes"))
	{
		gb_tf2attributes = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "tf2attributes"))
	{
		gb_tf2attributes = false;
	}
}

public void OnMapStart()
{
	PrecacheModel(MODEL_TRIGGER, true);

	#if defined DEBUG
	event_round_start(INVALID_HANDLE, "", false);
	event_round_active(INVALID_HANDLE, "", false);
	#endif
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void event_round_start(Event event, const char[] name, bool dontBroadcast)
{
	g_boss = 0;
	g_bosstype = BOSS_NONE;

	for (int i; i < MAX_BOSSES; i++)
	{
		g_BossUserid[i] = 0;
	}
	for (int i; i < MAX_CUSTOMS; i++)
	{
		gf_RageTime[i] = 0.0;
	}

}

void GetBossVars()
{
	g_bossteam = FF2_GetBossTeam();
	g_otherteam = g_bossteam == 2 ? 3 : 2;

	for (int i = 1; i < sizeof(gs_bosskeyarray); i++)
	{
		if (FF2_HasAbility(0, this_plugin_name, gs_bosskeyarray[i]))
		{
			int userid = FF2_GetBossUserId(0);
			int client = GetClientOfUserId(userid);
			if (client && IsClientInGame(client) && IsPlayerAlive(client))
			{
				g_boss = client;
				g_bosstype = i;
				g_BossUserid[0] = userid;

				LogMessage("Selected %d by Key: %s", i, gs_bosskeyarray[i]);

				return;
			}
		}
	}

	g_BossUserid[0] = 0;
	g_boss = 0;
	g_bosstype = 0;
}

public void event_round_active(Event event, const char[] name, bool dontBroadcast)
{
	GetBossVars();

	//////////////// BOSS MODULES
	switch (g_bosstype)
	{
		case BOSS_MUMMY:Mummy_event_round_active();
		case BOSS_GREYALIEN:Greyalien_event_round_active();
		case BOSS_OOGIEBOOGIE:Oogieboogie_event_round_active();
		case BOSS_FASTZOMBIE:Fastzombie_event_round_active();
		case BOSS_SPECIAL_ORB: Special_Orb_event_round_active();
//		case BOSS_MULTISET:Multiset_event_round_active();
	}
}

public Action event_player_death(Event hEvent, const char[] name, bool dontBroadcast)
{
	int userid = hEvent.GetInt("userid");
	int client = GetClientOfUserId(userid);
	int attackeruid = hEvent.GetInt("attacker");
	int attacker = GetClientOfUserId(attackeruid);
	int deathflags = hEvent.GetInt("death_flags");

	//////////////// BOSS MODULES
	switch (g_bosstype)
	{
		case BOSS_MUMMY:Mummy_event_player_death(client, userid, hEvent);
		case BOSS_GREYALIEN:Greyalien_event_player_death(client, userid, hEvent);
		case BOSS_OOGIEBOOGIE:Oogieboogie_event_death(client, hEvent);
		case BOSS_FASTZOMBIE:Fastzombie_event_player_death(client, userid, attacker, deathflags);
//		case BOSS_MULTISET:Vergil_event_player_death(deathflags);
	}

	return Plugin_Continue;
}

public void event_round_end(Event event, const char[] name, bool dontBroadcast)
{
	//////////////// BOSS MODULES
	switch (g_bosstype)
	{
		case BOSS_GREYALIEN:Greyalien_event_round_end();
		case BOSS_OOGIEBOOGIE:Oogieboogie_event_round_end();
		case BOSS_FASTZOMBIE:Fastzombie_event_round_end();
//		case BOSS_MULTISET:Vergil_event_round_end();
	}

	//////////////////////////////
	for (int i; i < MAX_CUSTOMS; i++)
	{
		gf_RageTime[i] = 0.0;
	}

	g_bosstype = BOSS_NONE;
	g_boss = 0;
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor,
							float& damage, int& damagetype, int& weapon,
							float damageForce[3], float damagePosition[3], int damagecustom)
{
	//int change;

	//////////////// BOSS MODULES
	switch (g_bosstype)
	{
		case BOSS_FASTZOMBIE:Fastzombie_OnTakeDamage(victim, damage, damagePosition);
		case BOSS_SPECIAL_ORB: Special_Orb_OnTakeDamage(attacker, damage, inflictor);
	}

	//////////////////////////////

	/**
    if(change & ACTION_HANDLED)
    {
        return Plugin_Handled;
    }
    if(change & ACTION_CHANGED)
    {
        return Plugin_Changed;
    }
**/
	return Plugin_Continue;
}

/////////////
