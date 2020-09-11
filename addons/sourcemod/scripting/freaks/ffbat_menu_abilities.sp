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

#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
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

bool Unofficial;	// Determine if Unofficial is running
bool OldVersion;	// Determine if older than 1.11 is running
bool OldFork;	// DISC-FF or VSP fork is running

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

	MarkNativeAsOptional("FF2_GetArgNamedI");
	MarkNativeAsOptional("FF2_GetArgNamedF");
	MarkNativeAsOptional("FF2_GetArgNamedS");
	MarkNativeAsOptional("FF2_GetBossMaxLives");
	MarkNativeAsOptional("FF2_GetBossLives");

	#if defined _FFBAT_included
	MarkNativeAsOptional("FF2_EmitVoiceToAll");
	MarkNativeAsOptional("FF2_GetBossName");
	MarkNativeAsOptional("FF2_GetForkVersion");
	MarkNativeAsOptional("FF2_LogError");
	MarkNativeAsOptional("FF2_SetCheats");
	#endif
	return APLRes_Success;
}

public void OnPluginStart2()
{
	if(GetFeatureStatus(FeatureType_Native, "FF2_GetBossLives") != FeatureStatus_Available)
	{
		OldFork = true;
		OldVersion = true;
	}
	else if(GetFeatureStatus(FeatureType_Native, "FF2_GetForkVersion") != FeatureStatus_Available)
	{
		OldVersion = true;
	}
	#if defined _FFBAT_included
	else
	{
		int version[3];
		FF2_GetForkVersion(version);
		if(version[0] && version[1])
		{
			Unofficial = true;
			AddCommandListener(OnDebugCommand, "ff2_setrage");
			AddCommandListener(OnDebugCommand, "ff2_addrage");
			AddCommandListener(OnDebugCommand, "ff2_setcharge");
			AddCommandListener(OnDebugCommand, "ff2_addcharge");
			AddCommandListener(OnInfCommand, "ff2_setinfiniterage");
		}
	}
	#endif

	HookEvent("arena_round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("player_hurt", OnPlayerHurt);
	HookEvent("object_deflected", OnObjectDeflected);

	HookUserMessage(GetUserMessageId("PlayerJarated"), OnJarate);

	if(FF2_IsFF2Enabled())	// In case the plugin is loaded in late
	{
		if(FF2_GetRoundState() == 1)
			OnRoundStart(view_as<Event>(INVALID_HANDLE), "plugin_lateload", false);
	}
}

/*
	FF2Dbg Commands
*/

#if defined _FFBAT_included
public Action OnDebugCommand(int client, const char[] command, int args)
{
	if(!Enabled || !Unofficial || !CheckCommandAccess(client, command, ADMFLAG_CHEATS))
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
	if(!Enabled || !Unofficial || !CheckCommandAccess(client, command, ADMFLAG_CHEATS))
		return Plugin_Continue;

	if(args == 0)
	{
		if(!IsValidClient(client))
			return Plugin_Continue;

		int boss = FF2_GetBossIndex(client);
		if(boss<0 || !IsPlayerAlive(client))
			return Plugin_Continue;

		if(!IsWizard[boss])
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

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
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

	int client;
	for(int boss; boss<=MaxClients; boss++)
	{
		IsWizard[boss] = false;
		client = GetClientOfUserId(FF2_GetBossUserId(boss));
		if(IsValidClient(client))
		{
			if(FF2_HasAbility(boss, this_plugin_name, CONFIG))
				MakeBoss(boss, client, 2);
		}
	}
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

	if(OldFork)
		CreateTimer(0.1, Timer_CheckAlivePlayers, _, TIMER_FLAG_NO_MAPCHANGE);

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;

	int boss;
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(IsBoss(attacker))
	{
		boss = FF2_GetBossIndex(attacker);
		if(IsWizard[boss])
		{
			if(Refresh[boss] & RAN_ONKILL)
				RefreshSpells(boss, Randomize[boss], true);

			for(int mana; mana<MAX_TYPES; mana++)
			{
				if(Maximum[boss][mana] != 0)
				{
					Current[boss][mana] += OnKill[boss][mana];
					if(Maximum[boss][mana]>0 && Current[boss][mana]>Maximum[boss][mana])
					{
						Current[boss][mana] = Maximum[boss][mana];
					}
					else if(Current[boss][mana] < 0)
					{
						Current[boss][mana] = 0.0;
					}
				}
			}
		}
	}

	boss = FF2_GetBossIndex(client);
	if(boss < 0)
		return;

	for(int target=1; target<=MaxClients; target++)
	{
		if(!IsValidClient(target))
			continue;

		int boss2 = FF2_GetBossIndex(target);
		if(boss2>=0 && IsWizard[boss2])
		{
			for(int mana; mana<MAX_TYPES; mana++)
			{
				if(Maximum[boss2][mana] != 0)
				{
					Current[boss2][mana] += OnDeath[boss2][mana];
					if(Maximum[boss2][mana]>0 && Current[boss2][mana]>Maximum[boss2][mana])
					{
						Current[boss2][mana] = Maximum[boss2][mana];
					}
					else if(Current[boss2][mana] < 0)
					{
						Current[boss2][mana] = 0.0;
					}
				}
			}
		}
	}

	if(!IsWizard[boss])
		return;

	float engineTime = GetEngineTime();
	for(int ability; ability<MAX_SPELLS; ability++)
	{
		Cooldown[boss][ability] = engineTime+GetRandomFloat(10.0, 40.0);
	}
	return;
}

public void OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
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
		if(IsWizard[boss])
		{
			for(int mana; mana<MAX_TYPES; mana++)
			{
				if(Maximum[boss][mana] != 0)
				{
					Current[boss][mana] += OnHit[boss][mana]*damage;
					if(Maximum[boss][mana]>0 && Current[boss][mana]>Maximum[boss][mana])
					{
						Current[boss][mana] = Maximum[boss][mana];
					}
					else if(Current[boss][mana] < 0)
					{
						Current[boss][mana] = 0.0;
					}
				}
			}
		}
	}

	boss = FF2_GetBossIndex(client);
	if(boss < 0)
		return;

	if(!IsWizard[boss])
		return;

	for(int mana; mana<MAX_TYPES; mana++)
	{
		if(Maximum[boss][mana] != 0)
		{
			Current[boss][mana] += OnHurt[boss][mana]*damage;
			if(Maximum[boss][mana]>0 && Current[boss][mana]>Maximum[boss][mana])
			{
				Current[boss][mana] = Maximum[boss][mana];
			}
			else if(Current[boss][mana] < 0)
			{
				Current[boss][mana] = 0.0;
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

	if(!IsWizard[boss])
		return;

	for(int mana; mana<MAX_TYPES; mana++)
	{
		if(Maximum[boss][mana] != 0)
		{
			Current[boss][mana] += OnBlast[boss][mana];
			if(Maximum[boss][mana]>0 && Current[boss][mana]>Maximum[boss][mana])
			{
				Current[boss][mana] = Maximum[boss][mana];
			}
			else if(Current[boss][mana] < 0)
			{
				Current[boss][mana] = 0.0;
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

	if(!IsWizard[boss])
		return Plugin_Continue;

	int index = GetEntProp(jarate, Prop_Send, "m_iItemDefinitionIndex");
	if((index==58 || index==1083 || index==1105) && GetEntProp(jarate, Prop_Send, "m_iEntityLevel")!=-122)  //-122 is the Jar of Ants which isn't really Jarate
	{
		float engineTime = GetEngineTime();
		for(int ability; ability<MAX_SPELLS; ability++)
		{
			if(Cooldown[boss][ability] < engineTime+Jarate[boss])
				Cooldown[boss][ability] = engineTime+Jarate[boss];
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
	if(Enabled && IsWizard[boss] && !slot && Rage[boss])
		enabled = false;
}*/

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	return Plugin_Continue;
}

public Action Timer_CheckAlivePlayers(Handle timer)
{
	CurrentPlayers = 0;
	BossPlayers = 0;
	MercPlayers = 0;
	int bossTeam = FF2_GetBossTeam();
	for(int client=1; client<=MaxClients; client++)
	{
		if(!IsValidClient(client) || !IsPlayerAlive(client))
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

public void FF2_OnAlivePlayersChanged(int players, int bosses)
{
	CurrentPlayers = players+bosses;
	BossPlayers = bosses;
	MercPlayers = players;
}

/*
	Menu Timer
*/

public void MenuThink(int client)
{
	int boss = FF2_GetBossIndex(client);
	if(!Enabled || boss<0 || IsFakeClient(client))
	{
		if(boss>=0 && Rage[FF2_GetBossIndex(client)]>1)
			FF2_SetFF2flags(client, FF2_GetFF2flags(client) & (~FF2FLAG_HUDDISABLED));

		CancelClientMenu(client, false);
		SDKUnhook(client, SDKHook_PreThink, MenuThink);
		return;
	}

	float engineTime = GetEngineTime();
	if(NextMenuAt[boss] > engineTime)
		return;

	/*if(NextMenuAt[boss] > engineTime+0.1)
		FF2Dbg("Was late by %.5f seconds");*/

	NextMenuAt[boss] = engineTime+NextMenu[boss];
	bool disable, force;
	Action action = Plugin_Continue;
	Call_StartForward(OnMenuThink);
	Call_PushCell(boss);
	Call_PushCellRef(force);
	Call_PushFloatRef(NextMenuAt[boss]);
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
			NextMenuAt[boss] = engineTime+NextMenu[boss];
			force = false;
		}
	}

	if(Rage[boss] > 1)
	{
		FF2_SetBossCharge(boss, 0, 0.0);
		DD_SetForceHUDEnabled(client, true);
		FF2_SetFF2flags(client, FF2_GetFF2flags(client) | FF2FLAG_HUDDISABLED);
	}

	if(!force && Weapon[boss]>=0)
	{
		if(!IsPlayerAlive(client))
		{
			disable = true;
		}
		else if(Weapon[boss] > 9)
		{
			int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if(weapon<=MaxClients || !IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
				disable = true;

			if(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") != Weapon[boss])
				disable = true;
		}
		else if(GetPlayerWeaponSlot(client, Weapon[boss]) != GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))
		{
			disable = true;
		}
	}

	Menu menu = new Menu(MenuHandle);
	SetGlobalTransTarget(client);
	static char menuItem[MAX_MENUTITLE_LENGTH];
	Format(menuItem, sizeof(menuItem), "%s\n%i / %i HP\n", BossName[boss], IsPlayerAlive(client) ? GetClientHealth(client) : 0, FF2_GetBossMaxHealth(boss));
	if(!OldFork && FF2_GetBossMaxLives(boss)>1)
		Format(menuItem, sizeof(menuItem), "%s%i / %i Lives\n", menuItem, FF2_GetBossLives(boss), FF2_GetBossMaxLives(boss));

	for(int mana; mana<MAX_TYPES; mana++)
	{
		if(Maximum[boss][mana] != 0)
		{
			Current[boss][mana] += OnTime[boss][mana];
			if(Maximum[boss][mana]>0 && Current[boss][mana]>Maximum[boss][mana])
			{
				Current[boss][mana] = Maximum[boss][mana];
			}
			else if(Current[boss][mana] < 0)
			{
				Current[boss][mana] = 0.0;
			}

			if(!Rolling[boss][mana])
			{
				Display[boss][mana] = Current[boss][mana];
			}
			else if(Display[boss][mana] > Current[boss][mana])
			{
				Display[boss][mana] -= Rolling[boss][mana];
				if(Display[boss][mana] < Current[boss][mana])
					Display[boss][mana] = Current[boss][mana];
			}
			else if(Display[boss][mana] < Current[boss][mana])
			{
				Display[boss][mana] += Rolling[boss][mana];
				if(Display[boss][mana] > Current[boss][mana])
					Display[boss][mana] = Current[boss][mana];
			}

			if(Maximum[boss][mana] > 0)
			{
				Format(menuItem, sizeof(menuItem), "%s%i / %i %s\n", menuItem, RoundToFloor(Display[boss][mana]), RoundToFloor(Maximum[boss][mana]), Mana[boss][mana]);
			}
			else
			{
				Format(menuItem, sizeof(menuItem), "%s%i %s\n", menuItem, RoundToFloor(Display[boss][mana]), Mana[boss][mana]);
			}
		}
	}
	menu.SetTitle(menuItem);

	if(disable)
	{
		menu.ExitButton = false;
		menu.Pagination = false;
		menu.OptionFlags |= MENUFLAG_NO_SOUND;
		menu.Display(client, RoundToCeil(NextMenu[boss]));
		return;
	}

	int amount;
	bool blocked;
	for(int ability; ability<MAX_SPELLS; ability++)
	{
		if(amount > MAX_MENU_ITEMS)
			break;

		if(Disabled[boss][ability])
		{
			if(!Randomize[boss])
			{
				menu.AddItem("-1", "", ITEMDRAW_DISABLED|ITEMDRAW_NOTEXT);
				amount++;
			}
			continue;
		}

		amount++;
		strcopy(menuItem, MAX_MENUITEM_LENGTH, Name[boss][ability]);
		if(IsPlayerAlive(client))
		{
			blocked = false;
			for(int mana; mana<MAX_TYPES; mana++)
			{
				if(Cost[boss][ability][mana] <= 0)
					continue;

				Format(menuItem, MAX_MENUITEM_LENGTH, "%s (%i %s)", menuItem, RoundToFloor(Cost[boss][ability][mana]), Mana[boss][mana]);
				if(Cost[boss][ability][mana] > Current[boss][mana])
					blocked = true;
			}

			if((Magic[boss][ability] & MAG_SUMMON) && StartingPlayers-CurrentPlayers<=0)
				blocked = true;

			if((Magic[boss][ability] & MAG_PARTNER))
			{
				if((GetClientTeam(client)==FF2_GetBossTeam() && BossPlayers<2) || (GetClientTeam(client)!=FF2_GetBossTeam() && MercPlayers<2))
					blocked = true;
			}

			if(!OldFork && (Magic[boss][ability] & MAG_LASTLIFE) && FF2_GetBossLives(boss)!=1)
				blocked = true;
		}
		else
		{
			blocked = true;
		}

		if(Cooldown[boss][ability] > engineTime)
		{
			if(Cooldown[boss][ability] < (engineTime+1500.0))
				Format(menuItem, MAX_MENUITEM_LENGTH, "%s [%.1f]", menuItem, Cooldown[boss][ability]-engineTime);

			menu.AddItem("-1", menuItem, ITEMDRAW_DISABLED);
			continue;
		}

		if(TF2_IsPlayerInCondition(client, TFCond_Sapped) && (Magic[boss][ability] & MAG_MAGIC))
			blocked = true;

		if((TF2_IsPlayerInCondition(client, TFCond_Dazed) || TF2_IsPlayerInCondition(client, TFCond_Gas)) && !(Magic[boss][ability] & MAG_MIND))
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
	menu.Display(client, RoundToCeil(NextMenu[boss]));

	Call_StartForward(OnMenuThinkP);
	Call_PushCell(boss);
	Call_PushFloat(NextMenuAt[boss]);
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
			if(Weapon[boss] >= 0)
			{
				if(Weapon[boss] > 9)
				{
					int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
					if(weapon<=MaxClients || !IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
						return;

					if(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") != Weapon[boss])
						return;
				}
				else if(GetPlayerWeaponSlot(client, Weapon[boss]) != GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))
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
			if(GlobalCool[boss][ability] > 0)
			{
				for(int abilities; abilities<MAX_SPELLS; abilities++)
				{
					if(Cooldown[boss][abilities] < engineTime+GlobalCool[boss][ability])
						Cooldown[boss][abilities] = engineTime+GlobalCool[boss][ability];
				}
			}
			else if(GlobalCool[boss][ability] < 0)
			{
				for(int abilities; abilities<MAX_SPELLS; abilities++)
				{
					Cooldown[boss][abilities] += GlobalCool[boss][ability];
				}
			}
			Cooldown[boss][ability] = engineTime+SpellCool[boss][ability];

			for(int mana; mana<MAX_TYPES; mana++)
			{
				if(!Cost[boss][ability][mana])
					continue;

				Current[boss][mana] -= Cost[boss][ability][mana];
				if(Maximum[boss][mana]>0 && Current[boss][mana]>Maximum[boss][mana])
				{
					Current[boss][mana] = Maximum[boss][mana];
				}
				else if(Current[boss][mana] < 0)
				{
					Current[boss][mana] = 0.0;
				}
			}

			if(!blocked)
			{
				for(int i; i<MAX_SPECIALS; i++)
				{
					if(strlen(Ability[boss][ability][i]) && strlen(PluginName[boss][ability][i]))
						FF2_DoAbility(boss, PluginName[boss][ability][i], Ability[boss][ability][i], Slot[boss][ability][i]==-2 ? 0 : Slot[boss][ability][i], Buttonmode[boss][ability][i]);
				}
			}

			if(strlen(Particle[boss][ability]))
			{
				int particle = -1;
				if(strlen(Attachment[boss][ability]))
				{
					particle = AttachParticleToAttachment(client, Particle[boss][ability], Attachment[boss][ability]);
				}
				else
				{
					particle = AttachParticle(client, Particle[boss][ability], 70.0, true);
				}

				if(IsValidEntity(particle))
					CreateTimer(1.0, Timer_RemoveEntity, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
			}

			if(Refresh[boss] & RAN_ONUSE)
				RefreshSpells(boss, Randomize[boss], true);

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

			NextMenuAt[boss] = 0.0;
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
	if(NextMenuAt[boss]>engineTime || !IsPlayerAlive(client))
		return;

	if(Rage[boss] > 1)
		FF2_SetBossCharge(boss, 0, 0.0);

	for(int mana; mana<MAX_TYPES; mana++)
	{
		if(Maximum[boss][mana] != 0)
		{
			Current[boss][mana] += OnTime[boss][mana];
			if(Maximum[boss][mana]>0 && Current[boss][mana]>Maximum[boss][mana])
			{
				Current[boss][mana] = Maximum[boss][mana];
			}
			else if(Current[boss][mana] < 0)
			{
				Current[boss][mana] = 0.0;
			}
		}
	}

	bool force;
	Action action = Plugin_Continue;
	Call_StartForward(OnMenuThink);
	Call_PushCell(boss);
	Call_PushCellRef(force);
	Call_PushFloatRef(NextMenuAt[boss]);
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
			NextMenuAt[boss] = engineTime+NextMenu[boss];
			force = false;
		}
	}

	if(!force && Weapon[boss]>=0)
	{
		if(Weapon[boss] > 9)
		{
			int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if(weapon<=MaxClients || !IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
				return;

			if(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") != Weapon[boss])
				return;
		}
		else if(GetPlayerWeaponSlot(client, Weapon[boss]) != GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))
		{
			return;
		}
	}

	Call_StartForward(OnMenuThinkP);
	Call_PushCell(boss);
	Call_PushFloat(NextMenuAt[boss]);
	Call_Finish();

	int ability = GetRandomInt((MAX_SPELLS*-1), (MAX_SPELLS-1)); // Bot thinks which ability to use
	if(!IsValidSpell(ability, boss))
		return;

	if(Disabled[boss][ability])
		return;

	if(Cooldown[boss][ability] > engineTime) 
		return;

	if(TF2_IsPlayerInCondition(client, TFCond_Sapped) && (Magic[boss][ability] & MAG_MAGIC))
		return;

	if((TF2_IsPlayerInCondition(client, TFCond_Dazed) || TF2_IsPlayerInCondition(client, TFCond_Gas)) && !(Magic[boss][ability] & MAG_MIND))
		return;

	if((Magic[boss][ability] & MAG_SUMMON) && StartingPlayers-CurrentPlayers<=0)
		return;

	if((Magic[boss][ability] & MAG_PARTNER) && BossPlayers<2)
		return;

	for(int mana; mana<MAX_TYPES; mana++)
	{
		if(Cost[boss][ability][mana] <= 0)
			continue;

		if(Cost[boss][ability][mana] > Current[boss][mana])
			return;
	}

	static char num[5];
	Menu menu = new Menu(MenuHandle);
	IntToString(ability, num, 5);
	menu.AddItem(num, Name[boss][ability]);
	MenuHandle(menu, MenuAction_Select, client, 0);
	delete menu;
}

/*
	Actions
*/

public void MakeBoss(int boss, int client, int callMode)
{
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

	GetBossName(boss, BossName[boss], MAX_BOSSNAME_LENGTH, 0, client);
	GetBossName(boss, BossFile[boss], MAX_BOSSNAME_LENGTH);

	NewArgs[boss] = OldVersion ? false : FF2_NamedArgumentsUsed(boss, this_plugin_name, CONFIG);
	NextMenu[boss] = GetArgF(boss, "tick", 1, 0.1, 1);
	Weapon[boss] = RoundFloat(GetArgF(boss, "weapon", 2, -1.0, 0));
	Jarate[boss] = GetArgF(boss, "jarate", 3, 10.0, 1);
	Randomize[boss] = RoundFloat(GetArgF(boss, "random", 4, 0.0, 1));
	Refresh[boss] = GetArgI(boss, "refresh", 5);
	Rage[boss] = RoundFloat(GetArgF(boss, "rage", 6, 0.0, 1));

	static char abilityFormat[MAX_ABILITY_LENGTH];
	#if MAX_TYPES>8
	for(int mana; mana<9; mana++)
	#else
	for(int mana; mana<MAX_TYPES; mana++)
	#endif
	{
		Format(abilityFormat, MAX_ABILITY_LENGTH, "max%i", mana+1);
		Maximum[boss][mana] = GetArgF(boss, abilityFormat, (mana*10)+11, 0.0, 0);
		if(Maximum[boss][mana] == 0)
			continue;

		Format(abilityFormat, MAX_ABILITY_LENGTH, "mana%i", mana+1);
		GetArgS(boss, abilityFormat, (mana*10)+10, Mana[boss][mana], MAX_MENUITEM_LENGTH);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "start%i", mana+1);
		Current[boss][mana] = GetArgF(boss, abilityFormat, (mana*10)+12, 0.0, 0);
		Display[boss][mana] = Current[boss][mana];

		Format(abilityFormat, MAX_ABILITY_LENGTH, "roll%i", mana+1);
		Rolling[boss][mana] = GetArgF(boss, abilityFormat, (mana*10)+13, 0.0, 0);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "kill%i", mana+1);
		OnKill[boss][mana] = GetArgF(boss, abilityFormat, (mana*10)+14, 0.0, 0);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "hit%i", mana+1);
		OnHit[boss][mana] = GetArgF(boss, abilityFormat, (mana*10)+15, 0.0, 0);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "hurt%i", mana+1);
		OnHurt[boss][mana] = GetArgF(boss, abilityFormat, (mana*10)+16, 0.0, 0);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "time%i", mana+1);
		OnTime[boss][mana] = GetArgF(boss, abilityFormat, (mana*10)+17, 0.0, 0);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "blast%i", mana+1);
		OnBlast[boss][mana] = GetArgF(boss, abilityFormat, (mana*10)+18, 0.0, 0);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "death%i", mana+1);
		OnDeath[boss][mana] = GetArgF(boss, abilityFormat, (mana*10)+19, 0.0, 0);
	}

	#if MAX_TYPES>8
	if(NewArgs[boss])
	{
		for(int mana=9; mana<MAX_TYPES; mana++)
		{
			Format(abilityFormat, MAX_ABILITY_LENGTH, "max%i", mana+1);
			Maximum[boss][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);
			if(Maximum[boss][mana] == 0)
				continue;

			Format(abilityFormat, MAX_ABILITY_LENGTH, "mana%i", mana+1);
			FF2_GetArgNamedS(boss, this_plugin_name, CONFIG, abilityFormat, Mana[boss][mana], MAX_MENUITEM_LENGTH);

			Format(abilityFormat, MAX_ABILITY_LENGTH, "start%i", mana+1);
			Current[boss][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);
			Display[boss][mana] = Current[boss][mana];

			Format(abilityFormat, MAX_ABILITY_LENGTH, "roll%i", mana+1);
			Rolling[boss][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);

			Format(abilityFormat, MAX_ABILITY_LENGTH, "kill%i", mana+1);
			OnKill[boss][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);

			Format(abilityFormat, MAX_ABILITY_LENGTH, "hit%i", mana+1);
			OnHit[boss][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);

			Format(abilityFormat, MAX_ABILITY_LENGTH, "hurt%i", mana+1);
			OnHurt[boss][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);

			Format(abilityFormat, MAX_ABILITY_LENGTH, "time%i", mana+1);
			OnTime[boss][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);

			Format(abilityFormat, MAX_ABILITY_LENGTH, "blast%i", mana+1);
			OnBlast[boss][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);

			Format(abilityFormat, MAX_ABILITY_LENGTH, "death%i", mana+1);
			OnDeath[boss][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0);
		}
	}
	#endif

	Abilities[boss] = 0;
	float engineTime = GetEngineTime();
	for(int ability; ability<MAX_SPELLS; ability++)
	{
		Format(abilityFormat, MAX_ABILITY_LENGTH, "name%i", ability+1);
		if(!GetArgS(boss, abilityFormat, (ability*100)+100, Name[boss][ability], MAX_MENUITEM_LENGTH))
		{
			Disabled[boss][ability] = true;
			continue;
		}

		Abilities[boss]++;
		Disabled[boss][ability] = false;
		Format(abilityFormat, MAX_ABILITY_LENGTH, "ability%ia", ability+1);
		GetArgS(boss, abilityFormat, (ability*100)+101, Ability[boss][ability][0], MAX_ABILITY_LENGTH);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "plugin%ia", ability+1);
		GetArgS(boss, abilityFormat, (ability*100)+102, PluginName[boss][ability][0], MAX_PLUGIN_LENGTH);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "slot%ia", ability+1);
		Slot[boss][ability][0] = RoundFloat(GetArgF(boss, abilityFormat, (ability*100)+103, 0.0, 0));

		Format(abilityFormat, MAX_ABILITY_LENGTH, "button%ia", ability+1);
		Buttonmode[boss][ability][0] = RoundFloat(GetArgF(boss, abilityFormat, (ability*100)+104, 0.0, 1));

		#if MAX_SPECIALS>0
		if(NewArgs[boss])
		{
			for(int i=1; i<MAX_SPECIALS; i++)
			{
				Format(abilityFormat, MAX_ABILITY_LENGTH, "ability%i%s", ability+1, ABC[i]);
				FF2_GetArgNamedS(boss, this_plugin_name, CONFIG, abilityFormat, Ability[boss][ability][i], MAX_ABILITY_LENGTH);

				Format(abilityFormat, MAX_ABILITY_LENGTH, "plugin%i%s", ability+1, ABC[i]);
				FF2_GetArgNamedS(boss, this_plugin_name, CONFIG, abilityFormat, PluginName[boss][ability][i], MAX_PLUGIN_LENGTH);

				Format(abilityFormat, MAX_ABILITY_LENGTH, "slot%i%s", ability+1, ABC[i]);
				Slot[boss][ability][i] = RoundFloat(GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 0));

				Format(abilityFormat, MAX_ABILITY_LENGTH, "button%i%s", ability+1, ABC[i]);
				Buttonmode[boss][ability][i] = RoundFloat(GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 1));
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
			Cost[boss][ability][mana] = GetArgF(boss, abilityFormat, (ability*100)+mana+110, 0.0, 1);
		}

		#if MAX_TYPES>8
		if(NewArgs[boss])
		{
			for(int mana=9; mana<MAX_TYPES; mana++)
			{
				Format(abilityFormat, MAX_ABILITY_LENGTH, "cost%i%s", ability+1, ABC[mana]);
				Cost[boss][ability][mana] = GetArgF(boss, abilityFormat, VOID_ARG, 0.0, 1);
			}
		}
		#endif

		Format(abilityFormat, MAX_ABILITY_LENGTH, "initial%i", ability+1);
		Cooldown[boss][ability] = engineTime+GetArgF(boss, abilityFormat, (ability*100)+120, 0.0, 1);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "cooldown%i", ability+1);
		SpellCool[boss][ability] = GetArgF(boss, abilityFormat, (ability*100)+121, 0.0, 1);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "global%i", ability+1);
		GlobalCool[boss][ability] = GetArgF(boss, abilityFormat, (ability*100)+122, 0.0, 0);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "spell%i", ability+1);
		Magic[boss][ability] = GetArgI(boss, abilityFormat, (ability*100)+123);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "index%i", ability+1);
		Index[boss][ability] = RoundFloat(GetArgF(boss, abilityFormat, (ability*100)+124, 0.0, 1));

		Format(abilityFormat, MAX_ABILITY_LENGTH, "particle%i", ability+1);
		GetArgS(boss, abilityFormat, (ability*100)+131, Particle[boss][ability], MAX_EFFECT_LENGTH);

		Format(abilityFormat, MAX_ABILITY_LENGTH, "attach%i", ability+1);
		GetArgS(boss, abilityFormat, (ability*100)+132, Attachment[boss][ability], MAX_ATTACHMENT_LENGTH);
	}

	Enabled = true;
	IsWizard[boss] = true;
	RefreshSpells(boss, Randomize[boss], true);
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
	if(!Enabled || !IsWizard[boss] || random<=0 || !Refresh[boss])
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
		Disabled[boss][ability] = true;
		Indexed[boss][ability] = false;
	}

	if(blocked)
		return;

	int ability;
	for(int i; i<random2; i++)
	{
		ability = GetRandomValidSpell(boss);
		if(ability >= 0)
		{
			Disabled[boss][ability] = false;
			if(Index[boss][ability]>0 && Index[boss][ability]<=MAX_SPELLS)
				Indexed[boss][Index[boss][ability]-1] = true;
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
	static int abilities[MAX_SPELLS];
	int spells;
	float engineTime = GetEngineTime();
	for(int ability; ability<MAX_SPELLS; ability++)
	{
		if(strlen(Name[boss][ability]) && Disabled[boss][ability] && Cooldown[boss][ability]<engineTime)
		{
			if(Index[boss][ability]>0 && Index[boss][ability]<=MAX_SPELLS)
			{
				if(Indexed[boss][Index[boss][ability]-1])
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
		if(strlen(Name[boss][ability]) && Disabled[boss][ability])
		{
			if(Index[boss][ability]>0 && Index[boss][ability]<=MAX_SPELLS)
			{
				if(Indexed[boss][Index[boss][ability]-1])
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

	if(boss>=0 && !strlen(Name[boss][spell]))
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
				LogError2("[Boss] Detected a divide by 0 for %s!", CONFIG);
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
	if(argNumber == VOID_ARG)
	{
		if(!NewArgs[boss])
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
			LogError2("[Boss] %s's formula at %s for %s is not allowed to be blank.", BossFile[boss], argName, CONFIG);
		}
		else
		{
			LogError2("[Boss] %s's formula at arg%i/%s for %s is not allowed to be blank.", BossFile[boss], argNumber, argName, CONFIG);
		}
		return 0.0;
	}
	return defaultValue;
}

public float ParseFormula(int boss, const char[] key, float defaultValue, const char[] argName, int argNumber, int valueCheck)
{
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
						LogError2("[Boss] %s's formula at %s for %s has an invalid operator at character %i", BossFile[boss], argName, key, CONFIG, i+1);
					}
					else
					{
						LogError2("[Boss] %s's formula at arg%i/%s for %s has an invalid operator at character %i", BossFile[boss], argNumber, argName, key, CONFIG, i+1);
					}
					delete sumArray;
					delete _operator;
					return defaultValue;
				}

				if(--bracket < 0)
				{
					if(argNumber == VOID_ARG)
					{
						LogError2("[Boss] %s's formula at arg%i/%s for %s has an unbalanced parentheses at character %i", BossFile[boss], argName, key, CONFIG, i+1);
					}
					else
					{
						LogError2("[Boss] %s's formula at arg%i/%s for %s has an unbalanced parentheses at character %i", BossFile[boss], argNumber, argName, key, CONFIG, i+1);
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
				Operate(sumArray, bracket, Current[boss][0], _operator);
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
			LogError2("[Boss] %s has an invalid formula at %s for %s!", BossFile[boss], argName, key, CONFIG);
		}
		else
		{
			LogError2("[Boss] %s has an invalid formula at arg%i/%s for %s!", BossFile[boss], argNumber, argName, key, CONFIG);
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
	if(index == VOID_ARG)
	{
		if(!NewArgs[boss])
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
	if(NewArgs[boss])
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

stock bool GetBossName(int boss=0, char[] buffer, int bufferLength, int bossMeaning=0, int client=0)
{
	#if defined _FFBAT_included
	if(Unofficial)
		return FF2_GetBossName(boss, buffer, bufferLength, bossMeaning, client);
	#endif
	return FF2_GetBossSpecial(boss, buffer, bufferLength, bossMeaning);
}

stock void LogError2(const char[] message, any ...)
{
	char buffer[MAX_BUFFER_LENGTH], buffer2[MAX_BUFFER_LENGTH];
	Format(buffer, sizeof(buffer), "%s", message);
	VFormat(buffer2, sizeof(buffer2), buffer, 2);

	#if defined _FFBAT_included
	if(Unofficial)
	{
		FF2_LogError(buffer2);
	}
	else
	{
		LogError(buffer2);
	}
	#else
	LogError(buffer2);
	#endif
}

stock void EmitVoiceToAll(const char[] sample, int entity=SOUND_FROM_PLAYER)
{
	#if defined _FFBAT_included
	if(Unofficial)
	{
		FF2_EmitVoiceToAll(sample, entity);
	}
	else
	{
		EmitSoundToAll(sample, entity);
	}
	#else
	EmitSoundToAll(sample, entity);
	#endif
}

/*
	Natives
*/

public int Native_MakeBoss(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	MakeBoss(boss, GetClientOfUserId(FF2_GetBossUserId(boss)), GetNativeCell(2) ? 1 : 0);
}

public int Native_Refresh(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	RefreshSpells(boss, GetNativeCell(3), GetNativeCell(2));
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
		case 1:
			Unofficial = GetNativeCell(2);
		case 2:
			OldVersion = GetNativeCell(2);
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
		case 1:
			return view_as<int>(Unofficial);
		case 2:
			return view_as<int>(OldVersion);
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
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	switch(GetNativeCell(2))
	{
		case 0:
			IsWizard[boss] = GetNativeCell(3);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetBossBool(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	switch(GetNativeCell(2))
	{
		case 0:
			return view_as<int>(IsWizard[boss]);
	}
	return 0;
}

public int Native_SetBossInteger(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	switch(GetNativeCell(2))
	{
		case 0:
			Abilities[boss] = GetNativeCell(3);
		case 1:
			Weapon[boss] = GetNativeCell(3);
		case 2:
			Randomize[boss] = GetNativeCell(3);
		case 3:
			Refresh[boss] = GetNativeCell(3);
		case 4:
			Rage[boss] = GetNativeCell(3);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetBossInteger(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	switch(GetNativeCell(2))
	{
		case 0:
			return Abilities[boss];
		case 1:
			return Weapon[boss];
		case 2:
			return Randomize[boss];
		case 3:
			return Refresh[boss];
		case 4:
			return Rage[boss];
	}
	return 0;
}

public int Native_SetBossFloat(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	switch(GetNativeCell(2))
	{
		case 0:
			NextMenu[boss] = GetNativeCell(3);
		case 1:
			NextMenuAt[boss] = GetNativeCell(3);
		case 2:
			Jarate[boss] = GetNativeCell(3);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetBossFloat(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	switch(GetNativeCell(2))
	{
		case 0:
			return view_as<int>(NextMenu[boss]);
		case 1:
			return view_as<int>(NextMenuAt[boss]);
		case 2:
			return view_as<int>(Jarate[boss]);
	}
	return 0;
}

public int Native_SetBossString(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	switch(GetNativeCell(2))
	{
		case 0:
			GetNativeString(3, BossFile[boss], MAX_BOSSNAME_LENGTH);
		case 1:
			GetNativeString(3, BossName[boss], MAX_BOSSNAME_LENGTH);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetBossString(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	switch(GetNativeCell(2))
	{
		case 0:
		{
			SetNativeString(3, BossFile[boss], GetNativeCell(4));
			return strlen(BossFile[boss]);
		}
		case 1:
		{
			SetNativeString(3, BossName[boss], GetNativeCell(4));
			return strlen(BossName[boss]);
		}
	}
	return 0;
}

/*
	Mana Variables
*/

public int Native_SetManaBool(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	int mana = GetNativeCell(2);
	if(mana<0 || mana>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Mana Index: %i", mana);

	switch(GetNativeCell(3))
	{
		case 0:
			Indexed[boss][mana] = GetNativeCell(4);
		case 1:
			Disabled[boss][mana] = GetNativeCell(4);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetManaBool(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	int mana = GetNativeCell(2);
	if(mana<0 || mana>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Mana Index: %i", mana);

	switch(GetNativeCell(3))
	{
		case 0:
			return view_as<int>(Indexed[boss][mana]);
		case 1:
			return view_as<int>(Disabled[boss][mana]);
	}
	return 0;
}

public int Native_SetManaFloat(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	int mana = GetNativeCell(2);
	if(mana<0 || mana>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Mana Index: %i", mana);

	switch(GetNativeCell(3))
	{
		case 0:
			Maximum[boss][mana] = GetNativeCell(4);
		case 1:
			Current[boss][mana] = GetNativeCell(4);
		case 2:
			Display[boss][mana] = GetNativeCell(4);
		case 3:
			Rolling[boss][mana] = GetNativeCell(4);
		case 4:
			OnKill[boss][mana] = GetNativeCell(4);
		case 5:
			OnHit[boss][mana] = GetNativeCell(4);
		case 6:
			OnHurt[boss][mana] = GetNativeCell(4);
		case 7:
			OnTime[boss][mana] = GetNativeCell(4);
		case 8:
			OnBlast[boss][mana] = GetNativeCell(4);
		case 9:
			OnDeath[boss][mana] = GetNativeCell(4);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetManaFloat(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	int mana = GetNativeCell(2);
	if(mana<0 || mana>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Mana Index: %i", mana);

	switch(GetNativeCell(3))
	{
		case 0:
			return view_as<int>(Maximum[boss][mana]);
		case 1:
			return view_as<int>(Current[boss][mana]);
		case 2:
			return view_as<int>(Display[boss][mana]);
		case 3:
			return view_as<int>(Rolling[boss][mana]);
		case 4:
			return view_as<int>(OnKill[boss][mana]);
		case 5:
			return view_as<int>(OnHit[boss][mana]);
		case 6:
			return view_as<int>(OnHurt[boss][mana]);
		case 7:
			return view_as<int>(OnTime[boss][mana]);
		case 8:
			return view_as<int>(OnBlast[boss][mana]);
	}
	return 0;
}

public int Native_SetManaString(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	int mana = GetNativeCell(2);
	if(mana<0 || mana>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Mana Index: %i", mana);

	switch(GetNativeCell(3))
	{
		case 0:
			GetNativeString(4, Mana[boss][mana], MAX_MENUITEM_LENGTH);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetManaString(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	int mana = GetNativeCell(2);
	if(mana<0 || mana>=MAX_TYPES)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Mana Index: %i", mana);

	switch(GetNativeCell(3))
	{
		case 0:
		{
			SetNativeString(4, Mana[boss][mana], GetNativeCell(5));
			return strlen(Mana[boss][mana]);
		}
	}
	return 0;
}

/*
	Spell Variables
*/

public int Native_SetSpellBool(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	int spell = GetNativeCell(2);
	if(spell<0 || spell>=MAX_SPECIALS)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Spell Index: %i", spell);

	switch(GetNativeCell(3))
	{
		case 0:
			Indexed[boss][spell] = GetNativeCell(4);
		case 1:
			Disabled[boss][spell] = GetNativeCell(4);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetSpellBool(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

	int spell = GetNativeCell(2);
	if(spell<0 || spell>=MAX_SPECIALS)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Spell Index: %i", spell);

	switch(GetNativeCell(3))
	{
		case 0:
			return view_as<int>(Indexed[boss][spell]);
		case 1:
			return view_as<int>(Disabled[boss][spell]);
	}
	return 0;
}

public int Native_SetSpellInteger(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

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
			Slot[boss][spell][slot] = GetNativeCell(4);
		case 1:
			Buttonmode[boss][spell][slot] = GetNativeCell(4);
		case 2:
			Magic[boss][spell] = GetNativeCell(4);
		case 3:
			Index[boss][spell] = GetNativeCell(4);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetSpellInteger(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

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
			return Slot[boss][spell][slot];
		case 1:
			return Buttonmode[boss][spell][slot];
		case 2:
			return Magic[boss][spell];
		case 3:
			return Index[boss][spell];
	}
	return 0;
}

public int Native_SetSpellFloat(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

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
			Cost[boss][spell][slot] = GetNativeCell(4);
		case 1:
			Cooldown[boss][spell] = GetNativeCell(4);
		case 2:
			SpellCool[boss][spell] = GetNativeCell(4);
		case 3:
			GlobalCool[boss][spell] = GetNativeCell(4);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetSpellFloat(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

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
			return view_as<int>(Cost[boss][spell][slot]);
		case 1:
			return view_as<int>(Cooldown[boss][spell]);
		case 2:
			return view_as<int>(SpellCool[boss][spell]);
		case 3:
			return view_as<int>(GlobalCool[boss][spell]);
	}
	return 0;
}

public int Native_SetSpellString(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

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
			GetNativeString(4, Name[boss][spell], MAX_MENUITEM_LENGTH);
		case 1:
			GetNativeString(4, Ability[boss][spell][slot], MAX_ABILITY_LENGTH);
		case 2:
			GetNativeString(4, PluginName[boss][spell][slot], MAX_PLUGIN_LENGTH);
		case 3:
			GetNativeString(4, Particle[boss][spell], MAX_EFFECT_LENGTH);
		case 4:
			GetNativeString(4, Attachment[boss][spell], MAX_ATTACHMENT_LENGTH);
		default:
			return view_as<int>(false);
	}
	return view_as<int>(true);
}

public int Native_GetSpellString(Handle plugin, int numParams)
{
	int boss = GetNativeCell(1);
	if(boss<0 || boss>MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid Boss Index: %i", boss);

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
			SetNativeString(4, Name[boss][spell], GetNativeCell(5));
			return strlen(Name[boss][spell]);
		}
		case 1:
		{
			SetNativeString(4, Ability[boss][spell][slot], GetNativeCell(5));
			return strlen(Ability[boss][spell][slot]);
		}
		case 2:
		{
			SetNativeString(4, PluginName[boss][spell][slot], GetNativeCell(5));
			return strlen(PluginName[boss][spell][slot]);
		}
		case 3:
		{
			SetNativeString(4, Particle[boss][spell], GetNativeCell(5));
			return strlen(Particle[boss][spell]);
		}
		case 4:
		{
			SetNativeString(4, Attachment[boss][spell], GetNativeCell(5));
			return strlen(Attachment[boss][spell]);
		}
	}
	return 0;
}

#file "FF2 Subplugin: Menu Abilities"