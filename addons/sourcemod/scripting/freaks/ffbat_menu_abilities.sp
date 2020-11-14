#pragma semicolon 1

/*
			  Menu Abilities,
			 aka Menu Manager,
			aka Project Spider

	   This is pretty much a fan-made recreation of
	   Versus Marxvee ability system, let's just say
	    I'm  r e a l l y  like the concept, and uh,
	    kinda look up to Marxvee as an inspiration
	    towards making new things and concepts for
	  Freak Fortress. This was originally made for a
	  specific boss but was modified to be allow more 
	  control and removed exclusive features in-code.
*/

#define CONFIG		"special_menu_manager"
#define FF2_USING_AUTO_PLUGIN__OLD		// 01Pollux: buttonmode doesnt exists anymore in VSH2 FF2! "old args" if you want to use old { "arg%i", "" } system thing, else use { "key", "" }

/*
	Core:
		1 - Menu Tick Interval		[Formula]
		2 - Holding Weapon Slot		[Integer]
		3 - Jarate Cooldown		[Formula]
		4 - Random Amount of Spells	[Integer]
		5 - Refresh Spells When		[Flags]
		6 - Normal Rage Toggle		[Integer]

	Manas:
		X0 - Name of Mana		[String]
		X1 - Maximum Amount		[Formula]
		X2 - Starting Amount		[Formula]
		X3 - Rolling Counter		[Formula]
		X4 - Amount on Kill		[Formula]
		X5 - Amount per Damage Dealt	[Formula]
		x6 - Amount per Damage Taken	[Formula]
		X7 - Amount every Menu Tick	[Formula]
		X8 - Amount on Airblasted	[Formula]
		X9 - Amount on Boss Death	[Formula]

	Spells:
		X00 - Name of Spell		[String]
		X01 - Ability Name		[String]
		X02 - Plugin Name		[String]
		X03 - Ability Slot		[Integer]
		X04 - Ability Buttonmode	[Integer]

		X1X - Mana Cost			[Formula]

		X20 - Initial Cooldown		[Formula]
		X21 - Spell Cooldown		[Formula]
		X22 - Global Cooldown		[Formula]
		X23 - Spell Type		[Flags]
		X24 - Shuffle Index		[Integer]

		X31 - Particle Effect		[String]
		X32 - Particle Attachment	[String]
*/

/*
	Developer Note:

	I did use some of Sarsya's methods such as defining
	how big the variables are, using PreThink hook for
	spell casters and GetEngineTime(). I always think
	that I shouldn't use engine time incase of any
	slowmotion rages so things such as cooldowns
	line up with it, but I also think that it isn't
	really a big deal lol.

	If you try to compile with pre 1.11 FF2 include,
	you'll get errors and is nessary for compiling
	but not for running (not sure how old it can get
	down too). You'll get a warning about Unofficial
	variable being unused, it's just there to tell
	if Unofficial FF2 include is used, of course if
	you compile with that you can use official versions
	still as backwards compatibility stocks are used.

	Also I have no idea why I'm using VSH_OnDoRage
	forward, guess it's just a habit. No idea if this
	is used by anything else.

	Also I like Spiders.
*/

/*
	How long has it been since I wrote this? Felt
	like a long time. Anyways, releasing this to
	the public now, hopefully will be a better
	alterative towards AMS. I wanted to release
	due to the servers I gave this to declined
	or shut down, which is also the reason why
	I lacked development on Unofficial FF2.
	Maybe I'll come back to the public scene?
	For now I'll work on my own gamemodes.

	Now go enjoy Freak Fortress 2.
*/


#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_dynamic_defaults>

#pragma newdecls required

#define MAJOR_REVISION	"1"
#define MINOR_REVISION	"0"
#define STABLE_REVISION	"0"
#define PLUGIN_VERSION	MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define MAX_SOUND_LENGTH	80	// Maximum Sound Filepath
#define MAX_MODEL_LENGTH	128	// Maximum Model Filepath
#define MAX_MATERIAL_LENGTH	128	// Maximum Material Filepath
#define MAX_ENTITY_LENGTH	48	// Maximum Entity Name
#define MAX_EFFECT_LENGTH	48	// Maximum Effect Name
#define MAX_ATTACHMENT_LENGTH	48	// Maximum Attachment Name
#define HEX_OR_DEC_LENGTH	12	// Maximum Hex String Length
#define MAX_ATTRIBUTE_LENGTH	256	// Maximum Attribute List Length
#define MAX_BOSSNAME_LENGTH	64	// Maximum Boss Name
#define MAX_ABILITY_LENGTH	64	// Maximum Ability Name
#define MAX_PLUGIN_LENGTH	64	// Maximum Plugin Name
#define MAX_MENUITEM_LENGTH	48	// Maximum Menu Item Length
#define MAX_MENUTITLE_LENGTH	192	// Maximum Menu Title Length
#define MAX_MENU_ITEMS		10	// Maximum Number of Menu Items
#define MAX_TF2_PLAYERS		36	// Maximum Number of Players/Bots in TF2
#define VOID_ARG		-1	// Only Named Arg

#define FAR_FUTURE	100000000.0		// Further and Beyond
#define NOPE_AVI	"vo/engineer_no01.mp3"	// nope.avi

#define MAX_SPELLS	21	// Maximum Spells
#define MAX_TYPES	8	// Maximum Manas	(Can't be more than 26)
#define MAX_SPECIALS	8	// Maximum Abilities	(Can't be more than 27)

#define MAG_MAGIC	0x0001	// Can be blocked by sapper effect
#define MAG_MIND		0x0002	// Can't be blocked by stun effects
#define MAG_SUMMON	0x0004	// Require dead players to use
#define MAG_PARTNER	0x0008	// Require an teammate to use
#define MAG_LASTLIFE	0x0010	// Require having no extra lives left

#define RAN_ONKILL	0x0001	// Refresh on kill
#define RAN_ONUSE	0x0002	// Refresh on usage

static const char ABC[][] =
{
	"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
	"n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"
};

enum Operators
{
	Operator_None = 0,
	Operator_Add,
	Operator_Subtract,
	Operator_Multiply,
	Operator_Divide,
	Operator_Exponent,
};

float OFF_THE_MAP[3] = {16383.0, 16383.0, -16383.0};	// Kill without mayhem

Handle OnHaleRage;	// Old VSH rage forward
Handle OnCastSpell;	// Before casted a spell
Handle OnCastSpellP;	// After casted a spell
Handle OnRefresh;	// Before refreshed spell list
Handle OnRefreshP;	// After refreshed spell list
Handle OnMakeBoss;	// Before created spellcaster
Handle OnMakeBossP;	// After created spellcaster
Handle OnMenuThink;	// Before menu tick
Handle OnMenuThinkP;	// After menu tick

bool Enabled;		// Is this plugin being used
int StartingPlayers;	// Total players this round
int CurrentPlayers;	// Alive players left
int MercPlayers;	// MercTeam players
int BossPlayers;	// BossTeam players

// Main Stuff
bool IsWizard[MAX_TF2_PLAYERS];				// Has ability
char BossName[MAX_TF2_PLAYERS][MAX_BOSSNAME_LENGTH];	// Boss name (Client)
char BossFile[MAX_TF2_PLAYERS][MAX_BOSSNAME_LENGTH];	// Boss name (Server)
bool NewArgs[MAX_TF2_PLAYERS];				// Using named args
bool Indexed[MAX_TF2_PLAYERS][MAX_SPELLS];		// Is using that spell index
int Abilities[MAX_TF2_PLAYERS];				// Amount of abilities the boss has

int Weapon[MAX_TF2_PLAYERS];			// Required weapon slot
float NextMenu[MAX_TF2_PLAYERS];			// Menu tick interval
float NextMenuAt[MAX_TF2_PLAYERS];		// Next menu tick
float Jarate[MAX_TF2_PLAYERS];			// Jarate blockage time
int Randomize[MAX_TF2_PLAYERS];			// Randomize spells
int Refresh[MAX_TF2_PLAYERS];			// Refresh spells flags
bool Disabled[MAX_TF2_PLAYERS][MAX_SPELLS];	// Current disabled spells
int Rage[MAX_TF2_PLAYERS];			// Toggle disabling RAGE

// Manas
char Mana[MAX_TF2_PLAYERS][MAX_TYPES][MAX_MENUITEM_LENGTH];	// Name of mana type
float Maximum[MAX_TF2_PLAYERS][MAX_TYPES];			// Maximum value
float Current[MAX_TF2_PLAYERS][MAX_TYPES];			// Current real value
float Display[MAX_TF2_PLAYERS][MAX_TYPES];			// Current shown value
float Rolling[MAX_TF2_PLAYERS][MAX_TYPES];			// Rolling counter speed
float OnKill[MAX_TF2_PLAYERS][MAX_TYPES];				// Amount on kill
float OnHit[MAX_TF2_PLAYERS][MAX_TYPES];				// Amount per damage dealt
float OnHurt[MAX_TF2_PLAYERS][MAX_TYPES];				// Amount per damage taken
float OnTime[MAX_TF2_PLAYERS][MAX_TYPES];				// Amount over time
float OnBlast[MAX_TF2_PLAYERS][MAX_TYPES];			// Amount upon airblasted
float OnDeath[MAX_TF2_PLAYERS][MAX_TYPES];			// Amount upon friendly death

// Spells
char Name[MAX_TF2_PLAYERS][MAX_SPELLS][MAX_MENUITEM_LENGTH];				// Name of spell
char Ability[MAX_TF2_PLAYERS][MAX_SPELLS][MAX_SPECIALS][MAX_ABILITY_LENGTH];		// Ability name
char PluginName[MAX_TF2_PLAYERS][MAX_SPELLS][MAX_SPECIALS][MAX_ABILITY_LENGTH];	// Ability plugin name
int Slot[MAX_TF2_PLAYERS][MAX_SPELLS][MAX_SPECIALS];					// Ability slot
int Buttonmode[MAX_TF2_PLAYERS][MAX_SPELLS][MAX_SPECIALS];				// Ability buttonmode

float Cost[MAX_TF2_PLAYERS][MAX_SPELLS][MAX_TYPES];	// Cost for spell

float Cooldown[MAX_TF2_PLAYERS][MAX_SPELLS];		// Initial cooldown on spell
float SpellCool[MAX_TF2_PLAYERS][MAX_SPELLS];		// Cooldown on spell
float GlobalCool[MAX_TF2_PLAYERS][MAX_SPELLS];	// Global cooldown on spell
int Magic[MAX_TF2_PLAYERS][MAX_SPELLS];		// Spell flags
int Index[MAX_TF2_PLAYERS][MAX_SPELLS];		// Spell index

char Particle[MAX_TF2_PLAYERS][MAX_SPELLS][MAX_EFFECT_LENGTH];	// Particle Effect
char Attachment[MAX_TF2_PLAYERS][MAX_SPELLS][MAX_ATTACHMENT_LENGTH];	// Particle Attachment


enum struct _SingleTimer {
	bool bStarted;
	void Begin()
	{
		if(!this.bStarted)
			CreateTimer(0.1, Timer_CheckAlivePlayers, .flags = TIMER_FLAG_NO_MAPCHANGE);
	}
	void End()
	{
		this.bStarted = false;
	}
}
_SingleTimer TimerCheckPlayers;

public Plugin myinfo =
{
	name = "Freak Fortress 2: Menu Abilities",
	description = "I'm coming for you!",
	author = "Batfoxkid",
	version = PLUGIN_VERSION
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("MA_SetBool", Native_SetBool);
	CreateNative("MA_GetBool", Native_GetBool);
	CreateNative("MA_SetInteger", Native_SetInteger);
	CreateNative("MA_GetInteger", Native_GetInteger);
	CreateNative("MA_SetBossBool", Native_SetBossBool);
	CreateNative("MA_GetBossBool", Native_GetBossBool);
	CreateNative("MA_SetBossInteger", Native_SetBossInteger);
	CreateNative("MA_GetBossInteger", Native_GetBossInteger);
	CreateNative("MA_SetBossFloat", Native_SetBossFloat);
	CreateNative("MA_GetBossFloat", Native_GetBossFloat);
	CreateNative("MA_SetBossString", Native_SetBossString);
	CreateNative("MA_GetBossString", Native_GetBossString);
	CreateNative("MA_SetManaBool", Native_SetManaBool);
	CreateNative("MA_GetManaBool", Native_GetManaBool);
	CreateNative("MA_SetManaFloat", Native_SetManaFloat);
	CreateNative("MA_GetManaFloat", Native_GetManaFloat);
	CreateNative("MA_SetManaString", Native_SetManaString);
	CreateNative("MA_GetManaString", Native_GetManaString);
	CreateNative("MA_SetSpellBool", Native_SetSpellBool);
	CreateNative("MA_GetSpellBool", Native_GetSpellBool);
	CreateNative("MA_SetSpellInteger", Native_SetSpellInteger);
	CreateNative("MA_GetSpellInteger", Native_GetSpellInteger);
	CreateNative("MA_SetSpellFloat", Native_SetSpellFloat);
	CreateNative("MA_GetSpellFloat", Native_GetSpellFloat);
	CreateNative("MA_SetSpellString", Native_SetSpellString);
	CreateNative("MA_GetSpellString", Native_GetSpellString);
	//CreateNative("MA_Set", Native_Set);
	//CreateNative("MA_Get", Native_Get);
	CreateNative("MA_MakeBoss", Native_MakeBoss);
	CreateNative("MA_Refresh", Native_Refresh);

	OnHaleRage = CreateGlobalForward("VSH_OnDoRage", ET_Hook, Param_FloatByRef);
	OnCastSpell = CreateGlobalForward("MA_OnCastSpell", ET_Hook, Param_Cell, Param_String, Param_CellByRef);
	OnCastSpellP = CreateGlobalForward("MA_OnCastSpellPost", ET_Hook, Param_Cell, Param_String, Param_Cell, Param_Cell);
	OnRefresh = CreateGlobalForward("MA_OnRefresh", ET_Hook, Param_Cell, Param_CellByRef);
	OnRefreshP = CreateGlobalForward("MA_OnRefreshPost", ET_Hook, Param_Cell, Param_Cell);
	OnMakeBoss = CreateGlobalForward("MA_OnMakeBoss", ET_Hook, Param_Cell, Param_Cell);
	OnMakeBossP = CreateGlobalForward("MA_OnMakeBossPost", ET_Hook, Param_Cell, Param_Cell);
	OnMenuThink = CreateGlobalForward("MA_OnMenuThink", ET_Hook, Param_Cell, Param_CellByRef, Param_FloatByRef);
	OnMenuThinkP = CreateGlobalForward("MA_OnMenuThinkPost", ET_Hook, Param_Cell, Param_Float);

	return APLRes_Success;
}

public void OnPluginStart2()
{
	#if defined DEBUG
	else
	{
		AddCommandListener(OnDebugCommand, "ff2_setrage");
		AddCommandListener(OnDebugCommand, "ff2_addrage");
		AddCommandListener(OnDebugCommand, "ff2_setcharge");
		AddCommandListener(OnDebugCommand, "ff2_addcharge");
		AddCommandListener(OnInfCommand, "ff2_setinfiniterage");
	}
	#endif

	HookEvent("arena_round_start", _OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("player_hurt", _OnPlayerHurt);
	HookEvent("object_deflected", OnObjectDeflected);

	HookUserMessage(GetUserMessageId("PlayerJarated"), OnJarate);

	if(FF2_IsFF2Enabled())	// In case the plugin is loaded in late
	{
		if(FF2_GetRoundState() == 1)
			_OnRoundStart(view_as<Event>(INVALID_HANDLE), "plugin_lateload", false);
	}
}

/*
	FF2Dbg Commands
*/

#if defined DEBUG
public Action OnDebugCommand(int client, const char[] command, int args)
{
	if(!Enabled || !CheckCommandAccess(client, command, ADMFLAG_CHEATS))
		return Plugin_Continue;

	if(!IsWizard[0])
		return Plugin_Continue;

	bool isCharge;
	if(StrEqual(command, "ff2_setcharge", false) || StrEqual(command, "ff2_addcharge", false))
		isCharge = true;

	float rageMeter;
	if((isCharge && args==2) || (!isCharge && args==1))
	{
		if(!IsBoss(client) || !IsPlayerAlive(client))
			return Plugin_Continue;
			
		char ragePCT[80];
		if(isCharge)
		{
			GetCmdArg(2, ragePCT, sizeof(ragePCT));
		}
		else
		{
			GetCmdArg(1, ragePCT, sizeof(ragePCT));
		}
		rageMeter = StringToFloat(ragePCT);
	}
	else
	{
		static char ragePCT[80];
		static char targetName[PLATFORM_MAX_PATH];
		GetCmdArg(1, targetName, sizeof(targetName));
		if(isCharge)
		{
			GetCmdArg(3, ragePCT, sizeof(ragePCT));
		}
		else
		{
			GetCmdArg(2, ragePCT, sizeof(ragePCT));
		}
		rageMeter = StringToFloat(ragePCT);

		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAX_TF2_PLAYERS], target_count;
		bool tn_is_ml;
	
		if((target_count=ProcessTargetString(targetName, client, target_list, MaxClients, 0, target_name, sizeof(target_name), tn_is_ml))<=0)
			return Plugin_Continue;

		for(int target; target<target_count; target++)
		{
			if(!IsBoss(target_list[target]) || !IsPlayerAlive(target_list[target]))
				return Plugin_Continue;
		}
	}

	if(StrEqual(command, "ff2_setrage", false))
	{
		if(Maximum[0][0])
		{
			Current[0][0] += rageMeter;
			if(Maximum[0][0]>0 && Current[0][0]>Maximum[0][0])
				Current[0][0] = Maximum[0][0];
		}
	}
	else if(StrEqual(command, "ff2_addrage", false))
	{
		if(Maximum[0][0])
		{
			Current[0][0] += rageMeter;
			if(Maximum[0][0]>0 && Current[0][0]>Maximum[0][0])
				Current[0][0] = Maximum[0][0];
		}
	}
	else if(StrEqual(command, "ff2_setcharge", false))
	{
		for(int mana=1; mana<MAX_TYPES; mana++)
		{
			if(Maximum[0][mana])
			{
				Current[0][mana] += rageMeter;
				if(Maximum[0][mana]>0 && Current[0][mana]>Maximum[0][mana])
					Current[0][mana] = Maximum[0][mana];
			}
		}
	}
	else if(StrEqual(command, "ff2_addcharge", false))
	{
		for(int mana=1; mana<MAX_TYPES; mana++)
		{
			if(Maximum[0][mana])
			{
				Current[0][mana] += rageMeter;
				if(Maximum[0][mana]>0 && Current[0][mana]>Maximum[0][mana])
					Current[0][mana] = Maximum[0][mana];
			}
		}
	}
	FF2_SetCheats(true);
	return Plugin_Continue;
}

public Action OnInfCommand(int client, const char[] command, int args)
{
	if(!Enabled || !CheckCommandAccess(client, command, ADMFLAG_CHEATS))
		return Plugin_Continue;

	if(args == 0)
	{
		if(!IsValidClient(client))
			return Plugin_Continue;

		int boss = FF2_GetBossIndex(client);
		if(boss<0 || !IsPlayerAlive(client))
			return Plugin_Continue;

		if(!IsWizard[client])
			return Plugin_Continue;

		for(int mana; mana<MAX_TYPES; mana++)
		{
			if(Maximum[0][mana])
			{
				Maximum[0][mana] = 999999.9;
				Current[0][mana] = 999999.9;
			}
		}
		FF2_SetCheats(true);
		return Plugin_Continue;
	}

	if(!IsWizard[0])
		return Plugin_Continue;

	static char targetName[PLATFORM_MAX_PATH];
	GetCmdArg(1, targetName, sizeof(targetName));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAX_TF2_PLAYERS], target_count;
	bool tn_is_ml;
	
	if((target_count=ProcessTargetString(targetName, client, target_list, MaxClients, 0, target_name, sizeof(target_name), tn_is_ml))<=0)
		return Plugin_Continue;

	for(int target; target<target_count; target++)
	{
		if(!IsBoss(target_list[target]) || !IsPlayerAlive(target_list[target]))
			return Plugin_Continue;
	}

	for(int mana; mana<MAX_TYPES; mana++)
	{
		if(Maximum[0][mana])
		{
			Maximum[0][mana] = 999999.9;
			Current[0][mana] = 999999.9;
		}
	}
	FF2_SetCheats(true);
	return Plugin_Continue;
}
#endif

/*
	TF2 Events
*/

public void _OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(!FF2_IsFF2Enabled())
		return;

	StartingPlayers = 0;
	int bossTeam = FF2_GetBossTeam();
	int clientTeam;
	for(int client=1; client<=MaxClients; client++)
	{
		if(!IsValidClient(client))
			continue;

		clientTeam = GetClientTeam(client);
		if(clientTeam <= view_as<int>(TFTeam_Spectator))
			continue;

		StartingPlayers++;
		if(clientTeam == bossTeam)
		{
			BossPlayers++;
		}
		else
		{
			MercPlayers++;
		}
	}
	CurrentPlayers = StartingPlayers;

	FF2Player boss;
	for(int client = 1; client<=MaxClients; client++)
	{
		if(!IsValidClient(client))
			continue;
		
		IsWizard[client] = false;
		boss = FF2Player(client);
		if(boss.HasAbility(this_plugin_name, CONFIG))
			MakeBoss(boss, 2);
	}
}

public void OnClientDisconnect(int client)
{
	TimerCheckPlayers.Begin();
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	Enabled = false;
	// Note I'm recycling most variables instead of clearing them.
	// Only vars that's cleared is Enabled and IsWizard[] because
	// those check if the boss/round has the ability enabled
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if(!Enabled)
		return;

	TimerCheckPlayers.Begin();

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;

	FF2Player boss;
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(IsBoss(attacker))
	{
		boss = FF2Player(attacker);
		if(IsWizard[client])
		{
			if(Refresh[client] & RAN_ONKILL)
				RefreshSpells(boss.userid, Randomize[client], true);

			for(int mana; mana<MAX_TYPES; mana++)
			{
				if(Maximum[client][mana] != 0)
				{
					Current[client][mana] += OnKill[client][mana];
					if(Maximum[client][mana]>0 && Current[client][mana]>Maximum[client][mana])
					{
						Current[client][mana] = Maximum[client][mana];
					}
					else if(Current[client][mana] < 0)
					{
						Current[client][mana] = 0.0;
					}
				}
			}
		}
	}

	boss = FF2Player(client);
	if(!boss.bIsBoss)
		return;

	for(int target=1; target<=MaxClients; target++)
	{
		if(!IsValidClient(target))
			continue;

		FF2Player boss2 = FF2Player(target);
		int client2 = boss2.index;
		if(boss2.bIsBoss && IsWizard[client2])
		{
			for(int mana; mana<MAX_TYPES; mana++)
			{
				if(Maximum[client2][mana] != 0)
				{
					Current[client2][mana] += OnDeath[client2][mana];
					if(Maximum[client2][mana]>0 && Current[client2][mana]>Maximum[client2][mana])
					{
						Current[client2][mana] = Maximum[client2][mana];
					}
					else if(Current[client2][mana] < 0)
					{
						Current[client2][mana] = 0.0;
					}
				}
			}
		}
	}

	if(!IsWizard[client])
		return;

	float engineTime = GetEngineTime();
	for(int ability; ability<MAX_SPELLS; ability++)
	{
		Cooldown[client][ability] = engineTime+GetRandomFloat(10.0, 40.0);
	}
	return;
}

public void _OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if(!Enabled)
		return;

	int damage = event.GetInt("damageamount");
	if(damage <= 0)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;

	int boss;
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(IsBoss(attacker))
	{
		boss = FF2_GetBossIndex(attacker);
		if(IsWizard[client])
		{
			for(int mana; mana<MAX_TYPES; mana++)
			{
				if(Maximum[client][mana] != 0)
				{
					Current[client][mana] += OnHit[client][mana]*damage;
					if(Maximum[client][mana]>0 && Current[client][mana]>Maximum[client][mana])
					{
						Current[client][mana] = Maximum[client][mana];
					}
					else if(Current[client][mana] < 0)
					{
						Current[client][mana] = 0.0;
					}
				}
			}
		}
	}

	boss = FF2_GetBossIndex(client);
	if(boss < 0)
		return;

	if(!IsWizard[client])
		return;

	for(int mana; mana<MAX_TYPES; mana++)
	{
		if(Maximum[client][mana] != 0)
		{
			Current[client][mana] += OnHurt[client][mana]*damage;
			if(Maximum[client][mana]>0 && Current[client][mana]>Maximum[client][mana])
			{
				Current[client][mana] = Maximum[client][mana];
			}
			else if(Current[client][mana] < 0)
			{
				Current[client][mana] = 0.0;
			}
		}
	}
}

public void OnObjectDeflected(Event event, const char[] name, bool dontBroadcast)
{
	if(!Enabled || event.GetInt("weaponid"))  // 0 means that the client was airblasted, which is what we want
		return;

	int client = GetClientOfUserId(event.GetInt("ownerid"));
	int boss = FF2_GetBossIndex(client);
	if(boss < 0)
		return;

	if(!IsWizard[client])
		return;

	for(int mana; mana<MAX_TYPES; mana++)
	{
		if(Maximum[client][mana] != 0)
		{
			Current[client][mana] += OnBlast[client][mana];
			if(Maximum[client][mana]>0 && Current[client][mana]>Maximum[client][mana])
			{
				Current[client][mana] = Maximum[client][mana];
			}
			else if(Current[client][mana] < 0)
			{
				Current[client][mana] = 0.0;
			}
		}
	}
}

public Action OnJarate(UserMsg msg_id, BfRead bf, const int[] players, int playersNum, bool reliable, bool init)
{
	if(!Enabled)
		return Plugin_Continue;

	int client = bf.ReadByte();
	int jarate = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if(jarate == -1)
		return Plugin_Continue;

	int victim = bf.ReadByte();
	int boss = FF2_GetBossIndex(victim);
	if(boss < 0)
		return Plugin_Continue;

	if(!IsWizard[client])
		return Plugin_Continue;

	int index = GetEntProp(jarate, Prop_Send, "m_iItemDefinitionIndex");
	if((index==58 || index==1083 || index==1105) && GetEntProp(jarate, Prop_Send, "m_iEntityLevel")!=-122)  //-122 is the Jar of Ants which isn't really Jarate
	{
		float engineTime = GetEngineTime();
		for(int ability; ability<MAX_SPELLS; ability++)
		{
			if(Cooldown[client][ability] < engineTime+Jarate[client])
				Cooldown[client][ability] = engineTime+Jarate[client];
		}

		static char sound[MAX_SOUND_LENGTH];
		if(FF2_RandomSound("sound_jarated", sound, MAX_SOUND_LENGTH, boss))
			EmitVoiceToAll(sound, victim);
	}
	return Plugin_Continue;
}

/*
	FF2 Events
*/

/*public void FF2_PreAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, bool &enabled)
{
	if(Enabled && IsWizard[client] && !slot && Rage[client])
		enabled = false;
}*/

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	return Plugin_Continue;
}

public Action Timer_CheckAlivePlayers(Handle timer)
{
	TimerCheckPlayers.End();
	
	if(!FF2_GetRoundState())
		return Plugin_Continue;
	
	CurrentPlayers = 0;
	BossPlayers = 0;
	MercPlayers = 0;
	int bossTeam = FF2_GetBossTeam();
	for(int client=1; client<=MaxClients; client++)
	{
		if(!IsClientInGame(client) || !IsPlayerAlive(client))
			continue;

		CurrentPlayers++;
		if(GetClientTeam(client) == bossTeam)
		{
			BossPlayers++;
		}
		else 
		{
			MercPlayers++;
		}
	}
	return Plugin_Continue;
}

/*
	Menu Timer
*/

public void MenuThink(int client)
{
	FF2Player player = FF2Player(client);
	if(!Enabled || !player.bIsBoss || IsFakeClient(client))
	{
		if(player.bIsBoss && Rage[client]>1)
			player.SetPropAny("bHideHUD", false);

		CancelClientMenu(client, false);
		SDKUnhook(client, SDKHook_PreThink, MenuThink);
		return;
	}

	float engineTime = GetEngineTime();
	if(NextMenuAt[client] > engineTime)
		return;

	/*if(NextMenuAt[client] > engineTime+0.1)
		FF2Dbg("Was late by %.5f seconds");*/

	NextMenuAt[client] = engineTime+NextMenu[client];
	bool disable, force;
	Action action = Plugin_Continue;
	Call_StartForward(OnMenuThink);
	Call_PushCell(player.userid);
	Call_PushCellRef(force);
	Call_PushFloatRef(NextMenuAt[client]);
	Call_Finish(action);
	switch(action)
	{
		case Plugin_Handled:
		{
			disable = true;
			force = true;
		}
		case Plugin_Stop:
		{
			return;
		}
		default:
		{
			NextMenuAt[client] = engineTime+NextMenu[client];
			force = false;
		}
	}

	if(Rage[client] > 1)
	{
		player.SetPropFloat("flRAGE", 0.0);
		DD_SetForceHUDEnabled(client, true);
		player.SetPropAny("bHideHUD", true);
	}

	if(!force && Weapon[client]>=0)
	{
		if(!IsPlayerAlive(client))
		{
			disable = true;
		}
		else if(Weapon[client] > 9)
		{
			int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if(weapon<=MaxClients || !IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
				disable = true;

			if(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") != Weapon[client])
				disable = true;
		}
		else if(GetPlayerWeaponSlot(client, Weapon[client]) != GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))
		{
			disable = true;
		}
	}

	Menu menu = new Menu(MenuHandle);
	SetGlobalTransTarget(client);
	static char menuItem[MAX_MENUTITLE_LENGTH];
	Format(menuItem, sizeof(menuItem), "%s\n%i / %i HP\n", BossName[client], IsPlayerAlive(client) ? GetClientHealth(client) : 0, player.GetPropInt("iMaxHealth"));
	if(player.GetPropInt("iMaxLives")>1)
		Format(menuItem, sizeof(menuItem), "%s%i / %i Lives\n", menuItem, player.GetPropInt("iLives"), player.GetPropInt("iMaxLives"));

	for(int mana; mana<MAX_TYPES; mana++)
	{
		if(Maximum[client][mana] != 0)
		{
			Current[client][mana] += OnTime[client][mana];
			if(Maximum[client][mana]>0 && Current[client][mana]>Maximum[client][mana])
			{
				Current[client][mana] = Maximum[client][mana];
			}
			else if(Current[client][mana] < 0)
			{
				Current[client][mana] = 0.0;
			}

			if(!Rolling[client][mana])
			{
				Display[client][mana] = Current[client][mana];
			}
			else if(Display[client][mana] > Current[client][mana])
			{
				Display[client][mana] -= Rolling[client][mana];
				if(Display[client][mana] < Current[client][mana])
					Display[client][mana] = Current[client][mana];
			}
			else if(Display[client][mana] < Current[client][mana])
			{
				Display[client][mana] += Rolling[client][mana];
				if(Display[client][mana] > Current[client][mana])
					Display[client][mana] = Current[client][mana];
			}

			if(Maximum[client][mana] > 0)
			{
				Format(menuItem, sizeof(menuItem), "%s%i / %i %s\n", menuItem, RoundToFloor(Display[client][mana]), RoundToFloor(Maximum[client][mana]), Mana[client][mana]);
			}
			else
			{
				Format(menuItem, sizeof(menuItem), "%s%i %s\n", menuItem, RoundToFloor(Display[client][mana]), Mana[client][mana]);
			}
		}
	}
	menu.SetTitle(menuItem);
	
	if(disable)
	{
		menu.ExitButton = false;
		menu.Pagination = false;
		menu.OptionFlags |= MENUFLAG_NO_SOUND;
		menu.Display(client, RoundToCeil(NextMenu[client]));
		return;
	}

	int amount;
	bool blocked;
	for(int ability; ability<MAX_SPELLS; ability++)
	{
		if(amount > MAX_MENU_ITEMS)
			break;

		if(Disabled[client][ability])
		{
			if(!Randomize[client])
			{
				menu.AddItem("-1", "", ITEMDRAW_DISABLED|ITEMDRAW_NOTEXT);
				amount++;
			}
			continue;
		}

		amount++;
		strcopy(menuItem, MAX_MENUITEM_LENGTH, Name[client][ability]);
		if(IsPlayerAlive(client))
		{
			blocked = false;
			for(int mana; mana<MAX_TYPES; mana++)
			{
				if(Cost[client][ability][mana] <= 0)
					continue;

				Format(menuItem, MAX_MENUITEM_LENGTH, "%s (%i %s)", menuItem, RoundToFloor(Cost[client][ability][mana]), Mana[client][mana]);
				if(Cost[client][ability][mana] > Current[client][mana])
					blocked = true;
			}

			if((Magic[client][ability] & MAG_SUMMON) && StartingPlayers-CurrentPlayers<=0)
				blocked = true;

			if((Magic[client][ability] & MAG_PARTNER))
			{
				if((GetClientTeam(client)==FF2_GetBossTeam() && BossPlayers<2) || (GetClientTeam(client)!=FF2_GetBossTeam() && MercPlayers<2))
					blocked = true;
			}

			if((Magic[client][ability] & MAG_LASTLIFE) && player.GetPropInt("iLives")!=1)
				blocked = true;
		}
		else
		{
			blocked = true;
		}

		if(Cooldown[client][ability] > engineTime)
		{
			if(Cooldown[client][ability] < (engineTime+1500.0))
				Format(menuItem, MAX_MENUITEM_LENGTH, "%s [%.1f]", menuItem, Cooldown[client][ability]-engineTime);

			menu.AddItem("-1", menuItem, ITEMDRAW_DISABLED);
			continue;
		}

		if(TF2_IsPlayerInCondition(client, TFCond_Sapped) && (Magic[client][ability] & MAG_MAGIC))
			blocked = true;

		if((TF2_IsPlayerInCondition(client, TFCond_Dazed) || TF2_IsPlayerInCondition(client, TFCond_Gas)) && !(Magic[client][ability] & MAG_MIND))
			blocked = true;

		if(blocked)
		{
			menu.AddItem("-1", menuItem, ITEMDRAW_DISABLED);
		}
		else
		{
			static char menuId[5];
			IntToString(ability, menuId, sizeof(menuId));
			menu.AddItem(menuId, menuItem);
		}
	}

	menu.ExitButton = false;
	menu.Pagination = false;
	menu.OptionFlags |= MENUFLAG_NO_SOUND;
	menu.Display(client, RoundToCeil(NextMenu[client]));

	Call_StartForward(OnMenuThinkP);
	Call_PushCell(player.userid);
	Call_PushFloat(NextMenuAt[client]);
	Call_Finish();
}

public int MenuHandle(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			if(!Enabled || !IsPlayerAlive(client))
				return;

			int boss = FF2_GetBossIndex(client);
			if(Weapon[client] >= 0)
			{
				if(Weapon[client] > 9)
				{
					int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
					if(weapon<=MaxClients || !IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
						return;

					if(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") != Weapon[client])
						return;
				}
				else if(GetPlayerWeaponSlot(client, Weapon[client]) != GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))
				{
					return;
				}
			}

			static char menuItem[MAX_MENUTITLE_LENGTH], temp[MAX_MENUTITLE_LENGTH], menuId[5];
			menu.GetItem(selection, menuId, sizeof(menuId), _, menuItem, MAX_MENUTITLE_LENGTH);
			int ability = StringToInt(menuId);
			if(ability < 0)
				return;

			bool blocked = false;
			Action action2 = Plugin_Continue;
			strcopy(temp, MAX_MENUTITLE_LENGTH, menuItem);
			Call_StartForward(OnCastSpell);
			Call_PushCell(boss);
			Call_PushString(menuItem);
			Call_PushCellRef(ability);
			Call_Finish(action2);
			switch(action2)
			{
				case Plugin_Handled:
				{
					blocked = true;
				}
				case Plugin_Stop:
				{
					return;
				}
				case Plugin_Continue:
				{
					ability = StringToInt(menuId);
					strcopy(menuItem, MAX_MENUTITLE_LENGTH, temp);
				}
			}

			float engineTime = GetEngineTime();
			if(GlobalCool[client][ability] > 0)
			{
				for(int abilities; abilities<MAX_SPELLS; abilities++)
				{
					if(Cooldown[client][abilities] < engineTime+GlobalCool[client][ability])
						Cooldown[client][abilities] = engineTime+GlobalCool[client][ability];
				}
			}
			else if(GlobalCool[client][ability] < 0)
			{
				for(int abilities; abilities<MAX_SPELLS; abilities++)
				{
					Cooldown[client][abilities] += GlobalCool[client][ability];
				}
			}
			Cooldown[client][ability] = engineTime+SpellCool[client][ability];

			for(int mana; mana<MAX_TYPES; mana++)
			{
				if(!Cost[client][ability][mana])
					continue;

				Current[client][mana] -= Cost[client][ability][mana];
				if(Maximum[client][mana]>0 && Current[client][mana]>Maximum[client][mana])
				{
					Current[client][mana] = Maximum[client][mana];
				}
				else if(Current[client][mana] < 0)
				{
					Current[client][mana] = 0.0;
				}
			}

			if(!blocked)
			{
				for(int i; i<MAX_SPECIALS; i++)
				{
					if(strlen(Ability[client][ability][i]) && strlen(PluginName[client][ability][i]))
						FF2_DoAbility2(boss, PluginName[client][ability][i], Ability[client][ability][i], Slot[client][ability][i]==-2 ? 0 : Slot[client][ability][i], Buttonmode[client][ability][i]);
				}
			}

			if(strlen(Particle[client][ability]))
			{
				int particle = -1;
				if(strlen(Attachment[client][ability]))
				{
					particle = AttachParticleToAttachment(client, Particle[client][ability], Attachment[client][ability]);
				}
				else
				{
					particle = AttachParticle(client, Particle[client][ability], 70.0, true);
				}

				if(IsValidEntity(particle))
					CreateTimer(1.0, Timer_RemoveEntity, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
			}

			if(Refresh[client] & RAN_ONUSE)
				RefreshSpells(boss, Randomize[client], true);

			static char sound[MAX_SOUND_LENGTH];
			Format(sound, MAX_SOUND_LENGTH, "sound_menu_%i", ability+1);
			if(FF2_RandomSound(sound, sound, MAX_SOUND_LENGTH, boss))
				EmitVoiceToAll(sound, client);

			Call_StartForward(OnCastSpellP);
			Call_PushCell(boss);
			Call_PushString(menuItem);
			Call_PushCell(ability);
			Call_PushCell(blocked);
			Call_Finish();

			NextMenuAt[client] = 0.0;
			MenuThink(client);

			action2 = Plugin_Continue;
			Call_StartForward(OnHaleRage);
			float distance = FF2_GetRageDist(boss, this_plugin_name, CONFIG);
			Call_PushFloatRef(distance);
			Call_Finish(action2);
		}
	}
}

public void MenuBot(int client)
{
	int boss = FF2_GetBossIndex(client);
	if(!Enabled || boss<0 || !IsFakeClient(client))
	{
		SDKUnhook(client, SDKHook_PreThink, MenuBot);
		return;
	}

	float engineTime = GetEngineTime();
	if(NextMenuAt[client]>engineTime || !IsPlayerAlive(client))
		return;

	if(Rage[client] > 1)
		FF2_SetBossCharge(boss, 0, 0.0);

	for(int mana; mana<MAX_TYPES; mana++)
	{
		if(Maximum[client][mana] != 0)
		{
			Current[client][mana] += OnTime[client][mana];
			if(Maximum[client][mana]>0 && Current[client][mana]>Maximum[client][mana])
			{
				Current[client][mana] = Maximum[client][mana];
			}
			else if(Current[client][mana] < 0)
			{
				Current[client][mana] = 0.0;
			}
		}
	}

	bool force;
	Action action = Plugin_Continue;
	Call_StartForward(OnMenuThink);
	Call_PushCell(boss);
	Call_PushCellRef(force);
	Call_PushFloatRef(NextMenuAt[client]);
	Call_Finish(action);
	switch(action)
	{
		case Plugin_Handled:
		{
			force = true;
		}
		case Plugin_Stop:
		{
			return;
		}
		case Plugin_Continue:
		{
			NextMenuAt[client] = engineTime+NextMenu[client];
			force = false;
		}
	}

	if(!force && Weapon[client]>=0)
	{
		if(Weapon[client] > 9)
		{
			int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if(weapon<=MaxClients || !IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
				return;

			if(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") != Weapon[client])
				return;
		}
		else if(GetPlayerWeaponSlot(client, Weapon[client]) != GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))
		{
			return;
		}
	}

	Call_StartForward(OnMenuThinkP);
	Call_PushCell(boss);
	Call_PushFloat(NextMenuAt[client]);
	Call_Finish();

	int ability = GetRandomInt((MAX_SPELLS*-1), (MAX_SPELLS-1)); // Bot thinks which ability to use
	if(!IsValidSpell(ability, boss))
		return;

	if(Disabled[client][ability])
		return;

	if(Cooldown[client][ability] > engineTime) 
		return;

	if(TF2_IsPlayerInCondition(client, TFCond_Sapped) && (Magic[client][ability] & MAG_MAGIC))
		return;

	if((TF2_IsPlayerInCondition(client, TFCond_Dazed) || TF2_IsPlayerInCondition(client, TFCond_Gas)) && !(Magic[client][ability] & MAG_MIND))
		return;

	if((Magic[client][ability] & MAG_SUMMON) && StartingPlayers-CurrentPlayers<=0)
		return;
		
	if((Magic[client][ability] & MAG_PARTNER) && BossPlayers<2)
		return;

	for(int mana; mana<MAX_TYPES; mana++)
	{
		if(Cost[client][ability][mana] <= 0)
			continue;

		if(Cost[client][ability][mana] > Current[client][mana])
			return;
	}

	static char num[5];
	Menu menu = new Menu(MenuHandle);
	IntToString(ability, num, 5);
	menu.AddItem(num, Name[client][ability]);
	MenuHandle(menu, MenuAction_Select, client, 0);
	delete menu;
}

/*
	Actions
*/

public void MakeBoss(FF2Player player, int callMode)
{
	int client = player.index;
	int boss = player.userid;
	bool blocked;
	if(callMode)
	{
		Action action = Plugin_Continue;
		Call_StartForward(OnMakeBoss);
		Call_PushCell(boss);
		Call_PushCell(callMode>1 ? false : true);
		Call_Finish(action);
		switch(action)
		{
			case Plugin_Handled:
			{
				blocked = true;
			}
			case Plugin_Stop:
			{
				return;
			}
		}
	}

	GetBossName(boss, BossName[client], MAX_BOSSNAME_LENGTH, 0);
	GetBossName(boss, BossFile[client], MAX_BOSSNAME_LENGTH, 1);

	NewArgs[client] = !FF2_GetArgNamedI(boss, this_plugin_name, CONFIG, "old args", 0);
	NextMenu[client] = GetArgF(boss, "tick", 1, 0.1, 1);
	Weapon[client] = RoundFloat(GetArgF(boss, "weapon", 2, -1.0, 0));
	Jarate[client] = GetArgF(boss, "jarate", 3, 10.0, 1);
	Randomize[client] = RoundFloat(GetArgF(boss, "random", 4, 0.0, 1));
	Refresh[client] = GetArgI(boss, "refresh", 5);
	Rage[client] = RoundFloat(GetArgF(boss, "rage", 6, 0.0, 1));

	static char abilityFormat[MAX_ABILITY_LENGTH];
	#if MAX_TYPES>8
	for(int mana; mana<9; mana++)
	#else
	for(int mana; mana<MAX_TYPES; mana++)
	#endif
	{
		Format(abilityFormat, MAX_ABILITY_LENGTH, "max%i", mana+1);
		Maximum[client][mana] = GetArgF(boss, abilityFormat, (mana*10)+11, 0.0, 0);
		if(Maximum[client][mana] == 0)
			continue;

		Format(abilityFormat, MAX_ABILITY_LENGTH, "mana%i", mana+1);
		GetArgS(boss, abilityFormat, (mana*10)+10, Mana[client][mana], MAX_MENUITEM_LENGTH);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "start%i", mana+1);
		Current[client][mana] = GetArgF(boss, abilityFormat, (mana*10)+12, 0.0, 0);
		Display[client][mana] = Current[client][mana];

		Format(abilityFormat, MAX_ABILITY_LENGTH, "roll%i", mana+1);
		Rolling[client][mana] = GetArgF(boss, abilityFormat, (mana*10)+13, 0.0, 0);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "kill%i", mana+1);
		OnKill[client][mana] = GetArgF(boss, abilityFormat, (mana*10)+14, 0.0, 0);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "hit%i", mana+1);
		OnHit[client][mana] = GetArgF(boss, abilityFormat, (mana*10)+15, 0.0, 0);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "hurt%i", mana+1);
		OnHurt[client][mana] = GetArgF(boss, abilityFormat, (mana*10)+16, 0.0, 0);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "time%i", mana+1);
		OnTime[client][mana] = GetArgF(boss, abilityFormat, (mana*10)+17, 0.0, 0);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "blast%i", mana+1);
		OnBlast[client][mana] = GetArgF(boss, abilityFormat, (mana*10)+18, 0.0, 0);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "death%i", mana+1);
		OnDeath[client][mana] = GetArgF(boss, abilityFormat, (mana*10)+19, 0.0, 0);
	}

	#if MAX_TYPES>8
	if(NewArgs[client])
	{
		for(int mana=9; mana<MAX_TYPES; mana++)
		{
			Format(abilityFormat, MAX_ABILITY_LENGTH, "max%i", mana+1);
			Maximum[client][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);
			if(Maximum[client][mana] == 0)
				continue;

			Format(abilityFormat, MAX_ABILITY_LENGTH, "mana%i", mana+1);
			FF2_GetArgNamedS(boss, this_plugin_name, CONFIG, abilityFormat, Mana[client][mana], MAX_MENUITEM_LENGTH);

			Format(abilityFormat, MAX_ABILITY_LENGTH, "start%i", mana+1);
			Current[client][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);
			Display[client][mana] = Current[client][mana];

			Format(abilityFormat, MAX_ABILITY_LENGTH, "roll%i", mana+1);
			Rolling[client][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);

			Format(abilityFormat, MAX_ABILITY_LENGTH, "kill%i", mana+1);
			OnKill[client][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);

			Format(abilityFormat, MAX_ABILITY_LENGTH, "hit%i", mana+1);
			OnHit[client][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);

			Format(abilityFormat, MAX_ABILITY_LENGTH, "hurt%i", mana+1);
			OnHurt[client][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);

			Format(abilityFormat, MAX_ABILITY_LENGTH, "time%i", mana+1);
			OnTime[client][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);

			Format(abilityFormat, MAX_ABILITY_LENGTH, "blast%i", mana+1);
			OnBlast[client][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);

			Format(abilityFormat, MAX_ABILITY_LENGTH, "death%i", mana+1);
			OnDeath[client][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);
		}
	}
	#endif

	Abilities[client] = 0;
	float engineTime = GetEngineTime();
	for(int ability; ability<MAX_SPELLS; ability++)
	{
		Format(abilityFormat, MAX_ABILITY_LENGTH, "name%i", ability+1);
		if(!GetArgS(boss, abilityFormat, (ability*100)+100, Name[client][ability], MAX_MENUITEM_LENGTH))
		{
			Disabled[client][ability] = true;
			continue;
		}

		Abilities[client]++;
		Disabled[client][ability] = false;
		Format(abilityFormat, MAX_ABILITY_LENGTH, "ability%ia", ability+1);
		GetArgS(boss, abilityFormat, (ability*100)+101, Ability[client][ability][0], MAX_ABILITY_LENGTH);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "plugin%ia", ability+1);
		GetArgS(boss, abilityFormat, (ability*100)+102, PluginName[client][ability][0], MAX_PLUGIN_LENGTH);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "slot%ia", ability+1);
		Slot[client][ability][0] = RoundFloat(GetArgF(boss, abilityFormat, (ability*100)+103, 0.0, 0));

		Format(abilityFormat, MAX_ABILITY_LENGTH, "button%ia", ability+1);
		Buttonmode[client][ability][0] = RoundFloat(GetArgF(boss, abilityFormat, (ability*100)+104, 0.0, 1));

		#if MAX_SPECIALS>0
		if(NewArgs[client])
		{
			for(int i=1; i<MAX_SPECIALS; i++)
			{
				Format(abilityFormat, MAX_ABILITY_LENGTH, "ability%i%s", ability+1, ABC[i]);
				FF2_GetArgNamedS(boss, this_plugin_name, CONFIG, abilityFormat, Ability[client][ability][i], MAX_ABILITY_LENGTH);

				Format(abilityFormat, MAX_ABILITY_LENGTH, "plugin%i%s", ability+1, ABC[i]);
				FF2_GetArgNamedS(boss, this_plugin_name, CONFIG, abilityFormat, PluginName[client][ability][i], MAX_PLUGIN_LENGTH);

				Format(abilityFormat, MAX_ABILITY_LENGTH, "slot%i%s", ability+1, ABC[i]);
				Slot[client][ability][i] = RoundFloat(GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0));

				Format(abilityFormat, MAX_ABILITY_LENGTH, "button%i%s", ability+1, ABC[i]);
				Buttonmode[client][ability][i] = RoundFloat(GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 1));
			}
		}
		#endif

		#if MAX_TYPES>8
		for(int mana; mana<9; mana++)
		#else
		for(int mana; mana<MAX_TYPES; mana++)
		#endif
		{
			Format(abilityFormat, MAX_ABILITY_LENGTH, "cost%i%s", ability+1, ABC[mana]);
			Cost[client][ability][mana] = GetArgF(boss, abilityFormat, (ability*100)+mana+110, 0.0, 1);
		}

		#if MAX_TYPES>8
		if(NewArgs[client])
		{
			for(int mana=9; mana<MAX_TYPES; mana++)
			{
				Format(abilityFormat, MAX_ABILITY_LENGTH, "cost%i%s", ability+1, ABC[mana]);
				Cost[client][ability][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 1);
			}
		}
		#endif

		Format(abilityFormat, MAX_ABILITY_LENGTH, "initial%i", ability+1);
		Cooldown[client][ability] = engineTime+GetArgF(boss, abilityFormat, (ability*100)+120, 0.0, 1);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "cooldown%i", ability+1);
		SpellCool[client][ability] = GetArgF(boss, abilityFormat, (ability*100)+121, 0.0, 1);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "global%i", ability+1);
		GlobalCool[client][ability] = GetArgF(boss, abilityFormat, (ability*100)+122, 0.0, 0);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "spell%i", ability+1);
		Magic[client][ability] = GetArgI(boss, abilityFormat, (ability*100)+123);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "index%i", ability+1);
		Index[client][ability] = RoundFloat(GetArgF(boss, abilityFormat, (ability*100)+124, 0.0, 1));

		Format(abilityFormat, MAX_ABILITY_LENGTH, "particle%i", ability+1);
		GetArgS(boss, abilityFormat, (ability*100)+131, Particle[client][ability], MAX_EFFECT_LENGTH);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "attach%i", ability+1);
		GetArgS(boss, abilityFormat, (ability*100)+132, Attachment[client][ability], MAX_ATTACHMENT_LENGTH);
	}

	Enabled = true;
	IsWizard[client] = true;
	RefreshSpells(boss, Randomize[client], true);
	if(!blocked)
	{
		if(IsFakeClient(client))
		{
			SDKHook(client, SDKHook_PreThink, MenuBot);
		}
		else
		{
			SDKHook(client, SDKHook_PreThink, MenuThink);
		}
	}

	if(callMode > 1)
	{
		Call_StartForward(OnMakeBossP);
		Call_PushCell(boss);
		Call_PushCell(callMode>1 ? false : true);
		Call_Finish();
	}
}

public void RefreshSpells(int boss, int random, bool call)
{
	int client = FF2Player(boss, true).index;
	
	if(!Enabled || !IsWizard[client] || random<=0 || !Refresh[client])
		return;

	Action action = Plugin_Continue;
	int random2 = random;
	bool blocked;
	if(call)
	{
		Call_StartForward(OnRefresh);
		Call_PushCell(boss);
		Call_PushCellRef(random2);
		Call_Finish(action);
		switch(action)
		{
			case Plugin_Handled:
			{
				blocked = true;
			}
			case Plugin_Stop:
			{
				return;
			}
			default:
			{
				random2 = random;
			}
		}
	}

	for(int ability; ability<MAX_SPELLS; ability++)
	{
		Disabled[client][ability] = true;
		Indexed[client][ability] = false;
	}

	if(blocked)
		return;

	int ability;
	for(int i; i<random2; i++)
	{
		ability = GetRandomValidSpell(boss);
		if(ability >= 0)
		{
			Disabled[client][ability] = false;
			if(Index[client][ability]>0 && Index[client][ability]<=MAX_SPELLS)
				Indexed[client][Index[client][ability]-1] = true;
		}
	}

	if(call)
	{
		Call_StartForward(OnRefreshP);
		Call_PushCell(boss);
		Call_PushCell(random2);
		Call_Finish();
	}
}

/*
	Stocks
*/

stock int GetRandomValidSpell(int boss)
{
	int client = FF2Player(boss, true).index;
	static int abilities[MAX_SPELLS];
	int spells;
	float engineTime = GetEngineTime();
	for(int ability; ability<MAX_SPELLS; ability++)
	{
		if(strlen(Name[client][ability]) && Disabled[client][ability] && Cooldown[client][ability]<engineTime)
		{
			if(Index[client][ability]>0 && Index[client][ability]<=MAX_SPELLS)
			{
				if(Indexed[client][Index[client][ability]-1])
					continue;
			}
			abilities[spells++] = ability;
		}
	}

	if(spells)
		return abilities[GetRandomInt(0, spells-1)];

	// Retry spells on cooldowns
	for(int ability; ability<MAX_SPELLS; ability++)
	{
		if(strlen(Name[client][ability]) && Disabled[client][ability])
		{
			if(Index[client][ability]>0 && Index[client][ability]<=MAX_SPELLS)
			{
				if(Indexed[client][Index[client][ability]-1])
					continue;
			}
			abilities[spells++] = ability;
		}
	}

	return spells ? abilities[GetRandomInt(0, spells-1)] : -1;
}

stock bool IsValidSpell(int spell, int boss=-1)
{
	if(spell<0 || spell>=MAX_SPELLS)
		return false;

	int client = FF2Player(boss, true).index;
	if(boss>=0 && !strlen(Name[client][spell]))
		return false;

	return true;
}

stock bool IsValidClient(int client, bool replaycheck=true)
{
	if(client<=0 || client>MaxClients)
		return false;

	if(!IsClientInGame(client))
		return false;

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
		return false;

	if(replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
		return false;

	return true;
}

stock bool IsBoss(int client)
{
	if(!IsValidClient(client))
		return false;

	return FF2_GetBossIndex(client)>=0;
}

stock bool IsInvuln(int client)
{
	if(!IsValidClient(client))
		return true;

	return (TF2_IsPlayerInCondition(client, TFCond_Ubercharged) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedCanteen) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedOnTakeDamage) ||
		TF2_IsPlayerInCondition(client, TFCond_Bonked) ||
		TF2_IsPlayerInCondition(client, TFCond_HalloweenGhostMode) ||
		TF2_IsPlayerInCondition(client, TFCond_MegaHeal) ||
		!GetEntProp(client, Prop_Data, "m_takedamage"));
}

stock void Operate(ArrayList sumArray, int &bracket, float value, ArrayList _operator)
{
	float sum = sumArray.Get(bracket);
	switch(_operator.Get(bracket))
	{
		case Operator_Add:
		{
			sumArray.Set(bracket, sum+value);
		}
		case Operator_Subtract:
		{
			sumArray.Set(bracket, sum-value);
		}
		case Operator_Multiply:
		{
			sumArray.Set(bracket, sum*value);
		}
		case Operator_Divide:
		{
			if(!value)
			{
				FF2_LogError("[Boss] Detected a divide by 0 for %s!", CONFIG);
				bracket = 0;
				return;
			}
			sumArray.Set(bracket, sum/value);
		}
		case Operator_Exponent:
		{
			sumArray.Set(bracket, Pow(sum, value));
		}
		default:
		{
			sumArray.Set(bracket, value);  //This means we're dealing with a constant
		}
	}
	_operator.Set(bracket, Operator_None);
}

stock void OperateString(ArrayList sumArray, int &bracket, char[] value, int size, ArrayList _operator)
{
	if(!StrEqual(value, ""))  //Make sure 'value' isn't blank
	{
		Operate(sumArray, bracket, StringToFloat(value), _operator);
		strcopy(value, size, "");
	}
}

public float GetArgF(int boss, const char[] argName, int argNumber, float defaultValue, int valueCheck)
{
	static char buffer[1024];
	int client = FF2Player(boss, true).index;
	if(argNumber == VOID_ARG)
	{
		if(!NewArgs[client])
			return defaultValue;

		FF2_GetArgNamedS(boss, this_plugin_name, CONFIG, argName, buffer, sizeof(buffer));
	}
	else
	{
		GetArgS(boss, argName, argNumber, buffer, sizeof(buffer));
	}

	if(strlen(buffer))
	{
		float value = ParseFormula(boss, buffer, defaultValue, argName, argNumber, valueCheck);
		return value; 
	}
	else if((valueCheck==1 && defaultValue<0) || (valueCheck==2 && defaultValue<=0))
	{
		if(argNumber == VOID_ARG)
		{
			FF2_LogError("[Boss] %s's formula at %s for %s is not allowed to be blank.", BossFile[client], argName, CONFIG);
		}
		else
		{
			FF2_LogError("[Boss] %s's formula at arg%i/%s for %s is not allowed to be blank.", BossFile[client], argNumber, argName, CONFIG);
		}
		return 0.0;
	}
	return defaultValue;
}

public float ParseFormula(int boss, const char[] key, float defaultValue, const char[] argName, int argNumber, int valueCheck)
{
	int client = FF2Player(boss, true).index;
	static char formula[1024];
	strcopy(formula, sizeof(formula), key);
	int size = 1;
	int matchingBrackets;
	for(int i; i<=strlen(formula); i++)  //Resize the arrays once so we don't have to worry about it later on
	{
		if(formula[i] == '(')
		{
			if(!matchingBrackets)
			{
				size++;
			}
			else
			{
				matchingBrackets--;
			}
		}
		else if(formula[i] == ')')
		{
			matchingBrackets++;
		}
	}

	ArrayList sumArray=CreateArray(_, size), _operator=CreateArray(_, size);
	int bracket;
	sumArray.Set(0, 0.0);
	_operator.Set(bracket, Operator_None);

	char character[2], value[16];
	for(int i; i<=strlen(formula); i++)
	{
		character[0] = formula[i];
		switch(character[0])
		{
			case ' ', '\t':
			{
				continue;
			}
			case '(':
			{
				bracket++;
				sumArray.Set(bracket, 0.0);
				_operator.Set(bracket, Operator_None);
			}
			case ')':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
				if(_operator.Get(bracket) != Operator_None)
				{
					if(argNumber == VOID_ARG)
					{
						FF2_LogError("[Boss] %s's formula at %s for %s has an invalid operator at character %i", BossFile[client], argName, key, CONFIG, i+1);
					}
					else
					{
						FF2_LogError("[Boss] %s's formula at arg%i/%s for %s has an invalid operator at character %i", BossFile[client], argNumber, argName, key, CONFIG, i+1);
					}
					delete sumArray;
					delete _operator;
					return defaultValue;
				}

				if(--bracket < 0)
				{
					if(argNumber == VOID_ARG)
					{
						FF2_LogError("[Boss] %s's formula at arg%i/%s for %s has an unbalanced parentheses at character %i", BossFile[client], argName, key, CONFIG, i+1);
					}
					else
					{
						FF2_LogError("[Boss] %s's formula at arg%i/%s for %s has an unbalanced parentheses at character %i", BossFile[client], argNumber, argName, key, CONFIG, i+1);
					}
					delete sumArray;
					delete _operator;
					return defaultValue;
				}

				Operate(sumArray, bracket, sumArray.Get(bracket+1), _operator);
			}
			case '\0':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
			}
			case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.':
			{
				StrCat(value, sizeof(value), character);
			}
			case 'n', 'x':
			{
				Operate(sumArray, bracket, float(StartingPlayers), _operator);
			}
			case 'a', 'y':
			{
				Operate(sumArray, bracket, float(CurrentPlayers), _operator);
			}
			case 'm', 'z':
			{
				Operate(sumArray, bracket, Current[client][0], _operator);
			}
			case '+', '-', '*', '/', '^':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
				switch(character[0])
				{
					case '+':
						_operator.Set(bracket, Operator_Add);

					case '-':
						_operator.Set(bracket, Operator_Subtract);

					case '*':
						_operator.Set(bracket, Operator_Multiply);

					case '/':
						_operator.Set(bracket, Operator_Divide);

					case '^':
						_operator.Set(bracket, Operator_Exponent);
				}
			}
		}
	}

	float result = sumArray.Get(0);
	delete sumArray;
	delete _operator;
	if((valueCheck==1 && result<0) || (valueCheck==2 && result<=0))
	{
		if(argNumber == VOID_ARG)
		{
			FF2_LogError("[Boss] %s has an invalid formula at %s for %s!", BossFile[client], argName, key, CONFIG);
		}
		else
		{
			FF2_LogError("[Boss] %s has an invalid formula at arg%i/%s for %s!", BossFile[client], argNumber, argName, key, CONFIG);
		}
		return defaultValue;
	}
	return result;
}

stock int FindEntityByClassname2(int startEnt, const char[] classname)
{
	while(startEnt>-1 && !IsValidEntity(startEnt))
	{
		startEnt--;
	}
	return FindEntityByClassname(startEnt, classname);
}

/*
	Sarsya Stocks	(Because their special)
*/

stock int AttachParticle(int entity, const char[] particleType, float offset=0.0, bool attach=true)
{
	int particle = CreateEntityByName("info_particle_system");
	
	if(!IsValidEntity(particle))
		return -1;

	static char targetName[128];
	static float position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	position[2] += offset;
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

	Format(targetName, sizeof(targetName), "target%i", entity);
	DispatchKeyValue(entity, "targetname", targetName);

	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", targetName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(targetName);

	if(attach)
	{
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	}

	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	return particle;
}

// adapted from the above and Friagram's halloween 2013 (which standing alone did not work for me)
stock int AttachParticleToAttachment(int entity, const char[] particleType, const char[] attachmentPoint) // m_vecAbsOrigin. you're welcome.
{
	int particle = CreateEntityByName("info_particle_system");
	
	if(!IsValidEntity(particle))
		return -1;

	static char targetName[128];
	static float position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

	Format(targetName, sizeof(targetName), "target%i", entity);
	DispatchKeyValue(entity, "targetname", targetName);

	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", targetName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(targetName);
	AcceptEntityInput(particle, "SetParent", particle, particle, 0);
	SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	
	SetVariantString(attachmentPoint);
	AcceptEntityInput(particle, "SetParentAttachment");

	if(strlen(particleType))
	{
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
	}
	return particle;
}

public Action Timer_RemoveEntity(Handle timer, any entid)
{
	int entity = EntRefToEntIndex(entid);
	if(IsValidEdict(entity) && entity>MaxClients)
	{
		TeleportEntity(entity, OFF_THE_MAP, NULL_VECTOR, NULL_VECTOR); // send it away first in case it feels like dying dramatically
		AcceptEntityInput(entity, "Kill");
	}
}

stock int ReadHexOrDecInt(char hexOrDecString[HEX_OR_DEC_LENGTH])
{
	if(!StrContains(hexOrDecString, "0x"))
	{
		int result = 0;
		for(int i=2; i<10 && hexOrDecString[i]!=0; i++)
		{
			result = result<<4;
				
			if(hexOrDecString[i]>='0' && hexOrDecString[i]<='9')
			{
				result += hexOrDecString[i]-'0';
			}
			else if(hexOrDecString[i]>='a' && hexOrDecString[i]<='f')
			{
				result += hexOrDecString[i]-'a'+10;
			}
			else if(hexOrDecString[i]>='A' && hexOrDecString[i]<='F')
			{
				result += hexOrDecString[i]-'A'+10;
			}
		}
		return result;
	}
	else
	{
		return StringToInt(hexOrDecString);
	}
}

/*
	Backward Complability Stocks
*/

stock int GetArgI(int boss, const char[] argument, int index=VOID_ARG)
{
	static char hexOrDecString[HEX_OR_DEC_LENGTH];
	int client = FF2Player(boss, true).index;
	if(index == VOID_ARG)
	{
		if(!NewArgs[client])
			return 0;

		FF2_GetArgNamedS(boss, this_plugin_name, CONFIG, argument, hexOrDecString, HEX_OR_DEC_LENGTH);
	}
	else
	{
		GetArgS(boss, argument, index, hexOrDecString, HEX_OR_DEC_LENGTH);
	}
	return ReadHexOrDecInt(hexOrDecString);
}

stock int GetArgS(int boss, const char[] argument, int index, char[] buffer, int bufferLength)
{
	int client = FF2Player(boss, true).index;
	if(NewArgs[client])
	{
		FF2_GetArgNamedS(boss, this_plugin_name, CONFIG, argument, buffer, bufferLength);
		if(!strlen(buffer))
			FF2_GetAbilityArgumentString(boss, this_plugin_name, CONFIG, index, buffer, bufferLength);
	}
	else
	{
		FF2_GetAbilityArgumentString(boss, this_plugin_name, CONFIG, index, buffer, bufferLength);
	}
	return strlen(buffer);
}

stock bool GetBossName(int boss=0, char[] buffer, int bufferLength, int bossMeaning=0)
{
	return FF2_GetBossSpecial(boss, buffer, bufferLength, bossMeaning);
}

stock void EmitVoiceToAll(const char[] sample, int entity=SOUND_FROM_PLAYER)
{
	EmitSoundToAll(sample, entity);
}

/*
	Natives
*/

public int Native_MakeBoss(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	MakeBoss(boss, GetNativeCell(2) ? 1 : 0);
}

public int Native_Refresh(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	RefreshSpells(boss.userid, GetNativeCell(3), GetNativeCell(2));
}

/*
	Global Variables
*/

public int Native_SetBool(Handle plugin, int numParams)
{
	switch(GetNativeCell(1))
	{
		case 0:
			Enabled = GetNativeCell(2);
		case 1: {}
//			Unofficial = GetNativeCell(2);
		case 2: {}
//			OldVersion = GetNativeCell(2);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetBool(Handle plugin, int numParams)
{
	switch(GetNativeCell(1))
	{
		case 0:
			return view_as<int>(Enabled);
		case 1: {}
//			return view_as<int>(Unofficial);
		case 2: {}
//			return view_as<int>(OldVersion);
	}
	return 0;
}

public int Native_SetInteger(Handle plugin, int numParams)
{
	switch(GetNativeCell(1))
	{
		case 3:
			StartingPlayers = GetNativeCell(2);
		case 4:
			CurrentPlayers = GetNativeCell(2);
		case 5:
			BossPlayers = GetNativeCell(2);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetInteger(Handle plugin, int numParams)
{
	switch(GetNativeCell(2))
	{
		case 0:
			return MAX_SPELLS;
		case 1:
			return MAX_TYPES;
		case 2:
			return MAX_SPECIALS;
		case 3:
			return StartingPlayers;
		case 4:
			return CurrentPlayers;
		case 5:
			return BossPlayers;
	}
	return 0;
}

/*
	Boss Variables
*/

public int Native_SetBossBool(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	switch(GetNativeCell(2))
	{
		case 0:
			IsWizard[client] = GetNativeCell(3);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetBossBool(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	switch(GetNativeCell(2))
	{
		case 0:
			return view_as<int>(IsWizard[client]);
	}
	return 0;
}

public int Native_SetBossInteger(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	switch(GetNativeCell(2))
	{
		case 0:
			Abilities[client] = GetNativeCell(3);
		case 1:
			Weapon[client] = GetNativeCell(3);
		case 2:
			Randomize[client] = GetNativeCell(3);
		case 3:
			Refresh[client] = GetNativeCell(3);
		case 4:
			Rage[client] = GetNativeCell(3);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetBossInteger(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	switch(GetNativeCell(2))
	{
		case 0:
			return Abilities[client];
		case 1:
			return Weapon[client];
		case 2:
			return Randomize[client];
		case 3:
			return Refresh[client];
		case 4:
			return Rage[client];
	}
	return 0;
}

public int Native_SetBossFloat(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	switch(GetNativeCell(2))
	{
		case 0:
			NextMenu[client] = GetNativeCell(3);
		case 1:
			NextMenuAt[client] = GetNativeCell(3);
		case 2:
			Jarate[client] = GetNativeCell(3);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetBossFloat(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	switch(GetNativeCell(2))
	{
		case 0:
			return view_as<int>(NextMenu[client]);
		case 1:
			return view_as<int>(NextMenuAt[client]);
		case 2:
			return view_as<int>(Jarate[client]);
	}
	return 0;
}

public int Native_SetBossString(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	switch(GetNativeCell(2))
	{
		case 0:
			GetNativeString(3, BossFile[client], MAX_BOSSNAME_LENGTH);
		case 1:
			GetNativeString(3, BossName[client], MAX_BOSSNAME_LENGTH);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetBossString(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	switch(GetNativeCell(2))
	{
		case 0:
		{
			SetNativeString(3, BossFile[client], GetNativeCell(4));
			return strlen(BossFile[client]);
		}
		case 1:
		{
			SetNativeString(3, BossName[client], GetNativeCell(4));
			return strlen(BossName[client]);
		}
	}
	return 0;
}

/*
	Mana Variables
*/

public int Native_SetManaBool(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	int mana = GetNativeCell(2);
	if(mana<0 || mana>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Mana Index: %i", mana);

	switch(GetNativeCell(3))
	{
		case 0:
			Indexed[client][mana] = GetNativeCell(4);
		case 1:
			Disabled[client][mana] = GetNativeCell(4);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetManaBool(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	int mana = GetNativeCell(2);
	if(mana<0 || mana>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Mana Index: %i", mana);

	switch(GetNativeCell(3))
	{
		case 0:
			return view_as<int>(Indexed[client][mana]);
		case 1:
			return view_as<int>(Disabled[client][mana]);
	}
	return 0;
}

public int Native_SetManaFloat(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	int mana = GetNativeCell(2);
	if(mana<0 || mana>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Mana Index: %i", mana);

	switch(GetNativeCell(3))
	{
		case 0:
			Maximum[client][mana] = GetNativeCell(4);
		case 1:
			Current[client][mana] = GetNativeCell(4);
		case 2:
			Display[client][mana] = GetNativeCell(4);
		case 3:
			Rolling[client][mana] = GetNativeCell(4);
		case 4:
			OnKill[client][mana] = GetNativeCell(4);
		case 5:
			OnHit[client][mana] = GetNativeCell(4);
		case 6:
			OnHurt[client][mana] = GetNativeCell(4);
		case 7:
			OnTime[client][mana] = GetNativeCell(4);
		case 8:
			OnBlast[client][mana] = GetNativeCell(4);
		case 9:
			OnDeath[client][mana] = GetNativeCell(4);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetManaFloat(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	int mana = GetNativeCell(2);
	if(mana<0 || mana>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Mana Index: %i", mana);

	switch(GetNativeCell(3))
	{
		case 0:
			return view_as<int>(Maximum[client][mana]);
		case 1:
			return view_as<int>(Current[client][mana]);
		case 2:
			return view_as<int>(Display[client][mana]);
		case 3:
			return view_as<int>(Rolling[client][mana]);
		case 4:
			return view_as<int>(OnKill[client][mana]);
		case 5:
			return view_as<int>(OnHit[client][mana]);
		case 6:
			return view_as<int>(OnHurt[client][mana]);
		case 7:
			return view_as<int>(OnTime[client][mana]);
		case 8:
			return view_as<int>(OnBlast[client][mana]);
	}
	return 0;
}

public int Native_SetManaString(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	int mana = GetNativeCell(2);
	if(mana<0 || mana>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Mana Index: %i", mana);

	switch(GetNativeCell(3))
	{
		case 0:
			GetNativeString(4, Mana[client][mana], MAX_MENUITEM_LENGTH);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetManaString(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	int mana = GetNativeCell(2);
	if(mana<0 || mana>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Mana Index: %i", mana);

	switch(GetNativeCell(3))
	{
		case 0:
		{
			SetNativeString(4, Mana[client][mana], GetNativeCell(5));
			return strlen(Mana[client][mana]);
		}
	}
	return 0;
}

/*
	Spell Variables
*/

public int Native_SetSpellBool(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	int spell = GetNativeCell(2);
	if(spell<0 || spell>=MAX_SPECIALS)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Spell Index: %i", spell);

	switch(GetNativeCell(3))
	{
		case 0:
			Indexed[client][spell] = GetNativeCell(4);
		case 1:
			Disabled[client][spell] = GetNativeCell(4);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetSpellBool(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	int spell = GetNativeCell(2);
	if(spell<0 || spell>=MAX_SPECIALS)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Spell Index: %i", spell);

	switch(GetNativeCell(3))
	{
		case 0:
			return view_as<int>(Indexed[client][spell]);
		case 1:
			return view_as<int>(Disabled[client][spell]);
	}
	return 0;
}

public int Native_SetSpellInteger(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	int spell = GetNativeCell(2);
	if(spell<0 || spell>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Spell Index: %i", spell);

	int index = GetNativeCell(3);
	int slot = GetNativeCell(5);
	if(index<2 && (slot<0 || slot>=MAX_SPELLS))
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Ability Index: %i", slot);

	switch(index)
	{
		case 0:
			Slot[client][spell][slot] = GetNativeCell(4);
		case 1:
			Buttonmode[client][spell][slot] = GetNativeCell(4);
		case 2:
			Magic[client][spell] = GetNativeCell(4);
		case 3:
			Index[client][spell] = GetNativeCell(4);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetSpellInteger(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	int spell = GetNativeCell(2);
	if(spell<0 || spell>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Spell Index: %i", spell);

	int index = GetNativeCell(3);
	int slot = GetNativeCell(5);
	if(index<2 && (slot<0 || slot>=MAX_SPELLS))
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Ability Index: %i", slot);

	switch(GetNativeCell(3))
	{
		case 0:
			return Slot[client][spell][slot];
		case 1:
			return Buttonmode[client][spell][slot];
		case 2:
			return Magic[client][spell];
		case 3:
			return Index[client][spell];
	}
	return 0;
}

public int Native_SetSpellFloat(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	int spell = GetNativeCell(2);
	if(spell<0 || spell>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Spell Index: %i", spell);

	int index = GetNativeCell(3);
	int slot = GetNativeCell(5);
	if(!index && (slot<0 || slot>=MAX_SPELLS))
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Mana Index: %i", slot);

	switch(GetNativeCell(3))
	{
		case 0:
			Cost[client][spell][slot] = GetNativeCell(4);
		case 1:
			Cooldown[client][spell] = GetNativeCell(4);
		case 2:
			SpellCool[client][spell] = GetNativeCell(4);
		case 3:
			GlobalCool[client][spell] = GetNativeCell(4);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetSpellFloat(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	int spell = GetNativeCell(2);
	if(spell<0 || spell>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Spell Index: %i", spell);

	int index = GetNativeCell(3);
	int slot = GetNativeCell(5);
	if(!index && (slot<0 || slot>=MAX_SPELLS))
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Mana Index: %i", slot);

	switch(GetNativeCell(3))
	{
		case 0:
			return view_as<int>(Cost[client][spell][slot]);
		case 1:
			return view_as<int>(Cooldown[client][spell]);
		case 2:
			return view_as<int>(SpellCool[client][spell]);
		case 3:
			return view_as<int>(GlobalCool[client][spell]);
	}
	return 0;
}

public int Native_SetSpellString(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	int spell = GetNativeCell(2);
	if(spell<0 || spell>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Spell Index: %i", spell);

	int index = GetNativeCell(3);
	int slot = GetNativeCell(5);
	if((index==1 || index==2) && (slot<0 || slot>=MAX_SPELLS))
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Ability Index: %i", slot);

	switch(index)
	{
		case 0:
			GetNativeString(4, Name[client][spell], MAX_MENUITEM_LENGTH);
		case 1:
			GetNativeString(4, Ability[client][spell][slot], MAX_ABILITY_LENGTH);
		case 2:
			GetNativeString(4, PluginName[client][spell][slot], MAX_PLUGIN_LENGTH);
		case 3:
			GetNativeString(4, Particle[client][spell], MAX_EFFECT_LENGTH);
		case 4:
			GetNativeString(4, Attachment[client][spell], MAX_ATTACHMENT_LENGTH);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetSpellString(Handle plugin, int numParams)
{
	FF2Player boss = FF2Player(GetNativeCell(1), true);
	if(!boss.Valid || !boss.bIsBoss)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);
	
	int client = boss.index;
	int spell = GetNativeCell(2);
	if(spell<0 || spell>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Spell Index: %i", spell);

	int index = GetNativeCell(3);
	int slot = GetNativeCell(5);
	if((index==1 || index==2) && (slot<0 || slot>=MAX_SPELLS))
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Ability Index: %i", slot);

	switch(index)
	{
		case 0:
		{
			SetNativeString(4, Name[client][spell], GetNativeCell(5));
			return strlen(Name[client][spell]);
		}
		case 1:
		{
			SetNativeString(4, Ability[client][spell][slot], GetNativeCell(5));
			return strlen(Ability[client][spell][slot]);
		}
		case 2:
		{
			SetNativeString(4, PluginName[client][spell][slot], GetNativeCell(5));
			return strlen(PluginName[client][spell][slot]);
		}
		case 3:
		{
			SetNativeString(4, Particle[client][spell], GetNativeCell(5));
			return strlen(Particle[client][spell]);
		}
		case 4:
		{
			SetNativeString(4, Attachment[client][spell], GetNativeCell(5));
			return strlen(Attachment[client][spell]);
		}
	}
	return 0;
}

void FF2_DoAbility2(int boss, const char[] pluginName, const char[] abilityName, int slot, int button)
{
#pragma unused button
	FF2_DoAbility(boss, pluginName, abilityName, slot);
}

//#file "FF2 Subplugin: Menu Abilities"