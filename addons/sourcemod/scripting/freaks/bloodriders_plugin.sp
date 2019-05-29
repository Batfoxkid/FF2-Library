#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <sdkhooks>
#include <tf2items>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <morecolors>
//#tryinclude <freak_fortress_2_extras>

// All the general informations here
#define FAR_FUTURE 100000000.0
#define MAX_WEAPON_ARG_LENGTH 256
#define MAX_CENTER_TEXT_LENGTH 256
#define MAX_ENTITY_CLASSNAME_LENGTH 48
#define INVALID_ENTREF INVALID_ENT_REFERENCE

#define RAGE_BLOOD "rage_bloodrider"
#define LIFELOSE_BLOOD "lifelose_bloodrider"
#define CONFIG_BLOOD "bloodrider_config"

// The Models (Yes, he has 9 models now)
#define BLOODRIDER_SCOUT	"models/freak_fortress_2/bloodriderv3/scout.mdl"
#define BLOODRIDER_SOLDIER	"models/freak_fortress_2/bloodriderv3/soldier.mdl"
#define BLOODRIDER_PYRO		"models/freak_fortress_2/bloodriderv3/pyro.mdl"
#define BLOODRIDER_DEMOMAN	"models/freak_fortress_2/bloodriderv3/demo.mdl"
#define BLOODRIDER_HEAVY	"models/freak_fortress_2/bloodriderv3/heavy.mdl"
#define BLOODRIDER_ENGINEER	"models/freak_fortress_2/bloodriderv3/engineer.mdl"
#define BLOODRIDER_MEDIC	"models/freak_fortress_2/bloodriderv3/medic.mdl"
#define BLOODRIDER_SNIPER	"models/freak_fortress_2/bloodriderv3/sniper.mdl"
#define BLOODRIDER_SPY		"models/freak_fortress_2/bloodriderv3/spy.mdl"

new BloodriderBossIdx;
new bool:RoundInProgress = false;
new bool:BossIsWinner = false;
new String:BOuttro[PLATFORM_MAX_PATH];
new bool:hooksEnabled = false;
new bool:IsBloodrider[MAXPLAYERS+1];
new bool:bloodisboss = false;

// So many bools here, goddamn
new weapondifficulty;
new bool:grapplinkhookboss;
new bool:grapplinkhookplayers;
new bool:givehookback;
new bool:IntroOutroOn;
new AdditionalVoiceOvers;
new String:hookbossargs[MAX_WEAPON_ARG_LENGTH], String:hookplayersargs[MAX_WEAPON_ARG_LENGTH];

// Regeneration stuff
new bool:RegenerateLivesOn;
new timeleft_stacks[MAXPLAYERS+1];
new timeleft[MAXPLAYERS+1];
new Handle:Timer_toReincarnate[MAXPLAYERS+1];
new Handle:cooldownHUD;

// Level up Stuff
new LevelingUp;
new bool:IsRandomDifficultyMode = false;
new Minimum;
new Maximum;

// Waves
new bool:Waveenabled;
new grenadeExtention=0;
new startTime=0;
new BloodMaxWaves=0;
new grenadeCount=0;

// Reanimators
new MaxClientRevives;
new ReviveMarkerDecayTime;
new clientRevives[MAXPLAYERS+1]=0;
new reviveMarker[MAXPLAYERS+1];
new bool:ChangeClass[MAXPLAYERS+1] = { false, ... };
new currentTeam[MAXPLAYERS+1] = {0, ... };
new Float:Blood_LastPlayerPos[MAXPLAYERS+1][3];

// Speedmanagement (Two lines because it looks better)
new String:ScoutSpeed[MAXPLAYERS+1], String:SoldierSpeed[MAXPLAYERS+1], String:PyroSpeed[MAXPLAYERS+1], String:DemoSpeed[MAXPLAYERS+1], String:HeavySpeed[MAXPLAYERS+1];
new String:EngineerSpeed[MAXPLAYERS+1], String:MedicSpeed[MAXPLAYERS+1], String:SniperSpeed[MAXPLAYERS+1], String:SpySpeed[MAXPLAYERS+1];
new Float:BloodriderSpeed[MAXPLAYERS+1];

// HUD
new String:BLOOD_BossHud[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // HUD type: Boss
new String:BLOOD_Client[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // HUD type: Player
new String:BLOOD_Easy[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // Easy
new String:BLOOD_Normal[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // Normal
new String:BLOOD_Intermediate[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // Intermediate
new String:BLOOD_Difficult[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // Difficult
new String:BLOOD_Lunatic[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // Lunatic
new String:BLOOD_Insane[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // Insane
new String:BLOOD_Godlike[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // Godlike
new String:BLOOD_GrenadeHell[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // Grenade Hell
new String:BLOOD_TrueBloodrider[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // True Bloodrider
new String:BLOOD_RNGDisplay[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // RNGLevel
new String:BLOOD_Counter[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // counter HUD
new String:BLOOD_Counter2[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // counter HUD
new String:BLOOD_CombatModeNoMelee[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // string name: combatmode_nomelee
new String:BLOOD_CombatModeWithMelee[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // string name: combatmode_withmelee
new String:BLOOD_NoMoreRevives[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH];

new String:regenerationHUD[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH];
new String:regeneratedHUD[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH];
new String:warningHUD[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH];
new String:Bloodrider_DifficultyLevelString[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH];

new Handle:ClientHUDS;
new Handle:BossHUDS;
new Handle:counterHUD;
new Handle:StatHUDS;

// Internal stuff
new bool:Raging[MAXPLAYERS+1] = false;
new bool:Nextlive[MAXPLAYERS+1] = false;
new bool:cantGetLives[MAXPLAYERS+1];

// many, many timer replacements
new Float:Bloodrider_FindBloodriderAt;
new Float:Blood_HUDSync;
new Float:NewGrenadeTimer;
new Float:Blood_WaveTick;
new Float:Blood_AdminTauntAt;
new Float:Blood_RemoveUberAt;
new Float:Blood_ReverifyGrapplinkhooksAt[MAXPLAYERS+1];
new Float:Blood_RemoveReviveMarkerAt[MAXPLAYERS+1];
new Float:Blood_MoveReviveMarkerAt[MAXPLAYERS+1];

/**
 * Stat Tracker - 28 December 2015 (Original date in Blitzkriegs plugin, as for Bloodrider, its the 18.09.2018)
 */
char Blood_statHUD[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // BOSS Stat HUD
char Blood_specHUD[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // Not spectating a player
char Blood_specHUD2[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // Spectating non-boss
char Blood_specHUD3[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH]; // Spectating boss
char Blood_MyStats[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH];
char Blood_Stats[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH];

int Blood_Wins[MAXPLAYERS+1];
int Blood_Losses[MAXPLAYERS+1];
int Blood_grenadeKills[MAXPLAYERS+1];
int Blood_meleeKills[MAXPLAYERS+1];
int Blood_grapplinkKills[MAXPLAYERS+1];
int Blood_Deaths[MAXPLAYERS+1];


public Plugin:myinfo = {
	name = "Freak Fortress 2: Bloodrider - the 9 Soul Grenade Spammer",
	author = "M7",
	description="Bloodriders abilities",
	version="3.0",
};


Handle winCookie = null;
Handle lossCookie = null;
Handle killCookie = null;
Handle killMeleeCookie = null;
Handle killHookCookie = null;
Handle deathCookie = null;

void PrepareStatTrakCookie()
{
	winCookie = RegClientCookie("blood_wins", "Bloodrider Win Tracker", CookieAccess_Public);
	lossCookie = RegClientCookie("blood_losses", "Bloodrider Loss Tracker", CookieAccess_Public);
	killCookie = RegClientCookie("blood_grenade_kills", "Bloodrider Kill Tracker", CookieAccess_Public);
	killMeleeCookie = RegClientCookie("blood_melee_kills", "Bloodrider Melee Kill Tracker", CookieAccess_Public);
	killHookCookie = RegClientCookie("blood_hook_kills", "Bloodrider Hook Kill Tracker", CookieAccess_Public);
	deathCookie = RegClientCookie("blood_deaths", "Bloodrider Death Tracker", CookieAccess_Public);

	for(int i = 0; i < MaxClients; i++)
	{
		Blood_Wins[i]=0;
		Blood_Losses[i]=0;
		Blood_grenadeKills[i]=0;
		Blood_meleeKills[i]=0;
		Blood_grapplinkKills[i]=0;
		Blood_Deaths[i]=0;
	}
	
	for(int clientIdx=1;clientIdx<=MaxClients;clientIdx++)
	{
		if(!IsValidClient(clientIdx))
			continue;
		if(!AreClientCookiesCached(clientIdx))
			continue;
		LoadStatCookie(clientIdx);
	}
}

stock void SaveStatCookie(int client)
{
	char statCookie[256];
	IntToString(Blood_Wins[client], statCookie, sizeof(statCookie));
	SetClientCookie(client, winCookie, statCookie);
	IntToString(Blood_Losses[client], statCookie, sizeof(statCookie));
	SetClientCookie(client, lossCookie, statCookie);
	IntToString(Blood_grenadeKills[client], statCookie, sizeof(statCookie));
	SetClientCookie(client, killCookie, statCookie);
	IntToString(Blood_meleeKills[client], statCookie, sizeof(statCookie));
	SetClientCookie(client, killMeleeCookie, statCookie);
	IntToString(Blood_grapplinkKills[client], statCookie, sizeof(statCookie));
	SetClientCookie(client, killHookCookie, statCookie);
	IntToString(Blood_Deaths[client], statCookie, sizeof(statCookie));
	SetClientCookie(client, deathCookie, statCookie);
}

stock void LoadStatCookie(int client)
{
	char statCookie[256];
	GetClientCookie(client, winCookie, statCookie, sizeof(statCookie));
	Blood_Wins[client] = StringToInt(statCookie);
	GetClientCookie(client, lossCookie, statCookie, sizeof(statCookie));
	Blood_Losses[client] = StringToInt(statCookie);
	GetClientCookie(client, killCookie, statCookie, sizeof(statCookie));
	Blood_grenadeKills[client] = StringToInt(statCookie);
	GetClientCookie(client, killMeleeCookie, statCookie, sizeof(statCookie));
	Blood_meleeKills[client] = StringToInt(statCookie);
	GetClientCookie(client, killHookCookie, statCookie, sizeof(statCookie));
	Blood_grapplinkKills[client] = StringToInt(statCookie);
	GetClientCookie(client, deathCookie, statCookie, sizeof(statCookie));
	Blood_Deaths[client] = StringToInt(statCookie);
}

public void OnClientCookiesCached(int client)
{
	LoadStatCookie(client);
}

// Level Up Enabled Indicator
static const String:BloodCanLevelUpgrade[][] = {
	"vo/mvm_mann_up_mode01.mp3",
	"vo/mvm_mann_up_mode02.mp3",
	"vo/mvm_mann_up_mode03.mp3",
	"vo/mvm_mann_up_mode04.mp3",
	"vo/mvm_mann_up_mode05.mp3",
	"vo/mvm_mann_up_mode06.mp3",
	"vo/mvm_mann_up_mode07.mp3",
	"vo/mvm_mann_up_mode08.mp3",
	"vo/mvm_mann_up_mode09.mp3",
	"vo/mvm_mann_up_mode10.mp3",
	"vo/mvm_mann_up_mode11.mp3",
	"vo/mvm_mann_up_mode12.mp3",
	"vo/mvm_mann_up_mode13.mp3",
	"vo/mvm_mann_up_mode14.mp3",
	"vo/mvm_mann_up_mode15.mp3"
};

// Round Result
static const String:BloodIsDefeated[][] = {
	"vo/mvm_manned_up01.mp3",
	"vo/mvm_manned_up02.mp3",
	"vo/mvm_manned_up03.mp3"
};

static const String:BloodIsVictorious[][] = {
	"vo/mvm_game_over_loss01.mp3",
	"vo/mvm_game_over_loss02.mp3",
	"vo/mvm_game_over_loss03.mp3",
	"vo/mvm_game_over_loss04.mp3",
	"vo/mvm_game_over_loss05.mp3",
	"vo/mvm_game_over_loss06.mp3",
	"vo/mvm_game_over_loss07.mp3",
	"vo/mvm_game_over_loss08.mp3",
	"vo/mvm_game_over_loss09.mp3",
	"vo/mvm_game_over_loss10.mp3",
	"vo/mvm_game_over_loss11.mp3"
};

// Class Reaction Lines
static const String:ScoutReact[][] = {
	"vo/scout_sf13_magic_reac03.mp3",
	"vo/scout_sf13_magic_reac07.mp3",
	"vo/scout_sf12_badmagic04.mp3"
};

static const String:SoldierReact[][] = {
	"vo/soldier_sf13_magic_reac03.mp3",
	"vo/soldier_sf12_badmagic07.mp3",
	"vo/soldier_sf12_badmagic13.mp3"
};

static const String:PyroReact[][] = {
	"vo/pyro_autodejectedtie01.mp3",
	"vo/pyro_painsevere02.mp3",
	"vo/pyro_painsevere04.mp3"
};

static const String:DemoReact[][] = {
	"vo/demoman_sf13_magic_reac05.mp3",
	"vo/demoman_sf13_bosses02.mp3",
	"vo/demoman_sf13_bosses03.mp3",
	"vo/demoman_sf13_bosses04.mp3",
	"vo/demoman_sf13_bosses05.mp3",
	"vo/demoman_sf13_bosses06.mp3"
};

static const String:HeavyReact[][] = {
	"vo/heavy_sf13_magic_reac01.mp3",
	"vo/heavy_sf13_magic_reac03.mp3",
	"vo/heavy_cartgoingbackoffense02.mp3",
	"vo/heavy_negativevocalization02.mp3",
	"vo/heavy_negativevocalization06.mp3"
};

static const String:EngyReact[][] = {
	"vo/engineer_sf13_magic_reac01.mp3",
	"vo/engineer_sf13_magic_reac02.mp3",
	"vo/engineer_specialcompleted04.mp3",
	"vo/engineer_painsevere05.mp3",
	"vo/engineer_negativevocalization12.mp3"
};

static const String:MedicReact[][] = {
	"vo/medic_sf13_magic_reac01.mp3",
	"vo/medic_sf13_magic_reac02.mp3",
	"vo/medic_sf13_magic_reac03.mp3",
	"vo/medic_sf13_magic_reac04.mp3",
	"vo/medic_sf13_magic_reac07.mp3"
};

static const String:SniperReact[][] = {
	"vo/sniper_sf13_magic_reac01.mp3",
	"vo/sniper_sf13_magic_reac02.mp3",
	"vo/sniper_sf13_magic_reac04.mp3"
};

static const String:SpyReact[][] = {
	"vo/Spy_sf13_magic_reac01.mp3",
	"vo/Spy_sf13_magic_reac02.mp3",
	"vo/Spy_sf13_magic_reac03.mp3",
	"vo/Spy_sf13_magic_reac04.mp3",
	"vo/Spy_sf13_magic_reac05.mp3",
	"vo/Spy_sf13_magic_reac06.mp3"
};

public Bloodrider_PrecacheModels()
{
	PrecacheModel(BLOODRIDER_SCOUT, true);
	PrecacheModel(BLOODRIDER_SOLDIER, true);
	PrecacheModel(BLOODRIDER_PYRO, true);
	PrecacheModel(BLOODRIDER_DEMOMAN, true);
	PrecacheModel(BLOODRIDER_HEAVY, true);
	PrecacheModel(BLOODRIDER_ENGINEER, true);
	PrecacheModel(BLOODRIDER_MEDIC, true);
	PrecacheModel(BLOODRIDER_SNIPER, true);
	PrecacheModel(BLOODRIDER_SPY, true);
}

public Bloodrider_PrecacheSounds()
{
	//Class Voice Reaction Lines
	for (new i = 0; i < sizeof(ScoutReact); i++)
	{
		PrecacheSound(ScoutReact[i], true);
	}
	for (new i = 0; i < sizeof(SoldierReact); i++)
	{
		PrecacheSound(SoldierReact[i], true);
	}
	for (new i = 0; i < sizeof(PyroReact); i++)
	{
		PrecacheSound(PyroReact[i], true);
	}
	for (new i = 0; i < sizeof(DemoReact); i++)
	{
		PrecacheSound(DemoReact[i], true);
	}
	for (new i = 0; i < sizeof(HeavyReact); i++)
	{
		PrecacheSound(HeavyReact[i], true);
	}
	for (new i = 0; i < sizeof(EngyReact); i++)
	{
		PrecacheSound(EngyReact[i], true);
	}
	for (new i = 0; i < sizeof(MedicReact); i++)
	{
		PrecacheSound(MedicReact[i], true);
	}
	for (new i = 0; i < sizeof(SniperReact); i++)
	{
		PrecacheSound(SniperReact[i], true);
	}
	for (new i = 0; i < sizeof(SpyReact); i++)
	{
		PrecacheSound(SpyReact[i], true);
	}
	// Manning Up & Round Result Lines
	for (new i = 0; i < sizeof(BloodCanLevelUpgrade); i++)
	{
		PrecacheSound(BloodCanLevelUpgrade[i], true);
	}
	for (new i = 0; i < sizeof(BloodIsDefeated); i++)
	{
		PrecacheSound(BloodIsDefeated[i], true);
	}
	for (new i = 0; i < sizeof(BloodIsVictorious); i++)
	{
		PrecacheSound(BloodIsVictorious[i], true);
	}
}

public OnPluginStart2()
{
	HookEvent("arena_round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);
	HookEvent("teamplay_round_start", Event_TeamplayRoundStart, EventHookMode_PostNoCopy);
	
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i)) 
		{
			currentTeam[i] = GetClientTeam(i);
			ChangeClass[i] = false;
		}
	}

	PrepareStatTrakCookie();
	StatHUDS=CreateHudSynchronizer();
	BossHUDS=CreateHudSynchronizer();
	ClientHUDS=CreateHudSynchronizer();
	counterHUD=CreateHudSynchronizer();
	cooldownHUD=CreateHudSynchronizer();
	
	Bloodrider_PrecacheModels();
	Bloodrider_PrecacheSounds();
	
	for (new clientIdx = 1; clientIdx <= MaxClients; clientIdx++)
		reviveMarker[clientIdx] = INVALID_ENTREF;
}

public void Event_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Bloodrider_FindBloodriderAt=GetEngineTime()+0.6;
}

public Action:OnAnnounce(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(bloodisboss)
	{
		new String:strAudio[40];
		GetEventString(event, "sound", strAudio, sizeof(strAudio));
		if(strncmp(strAudio, "Game.Your", 9) == 0 || strcmp(strAudio, "Game.Stalemate") == 0)
		{
			if (IntroOutroOn && BOuttro[0]!='\0')
				EmitSoundToAll(BOuttro);
			return Plugin_Handled;
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public MoveMarker(client)
{
	Blood_MoveReviveMarkerAt[client] = FAR_FUTURE;
	if (reviveMarker[client] == INVALID_ENTREF)
		return;
		
	new marker = EntRefToEntIndex(reviveMarker[client]);
	if (!IsValidEntity(marker))
	{
		reviveMarker[client] = INVALID_ENTREF;
		Blood_RemoveReviveMarkerAt[client] = FAR_FUTURE;
		return;
	}
	
	if (!IsClientInGame(client))
	{
		AcceptEntityInput(marker, "kill");
		reviveMarker[client] = INVALID_ENTREF;
		Blood_RemoveReviveMarkerAt[client] = FAR_FUTURE;
		return;
	}

	// must offset by 20, otherwise they can fall through the world
	static Float:spawnPos[3];
	spawnPos[0] = Blood_LastPlayerPos[client][0];
	spawnPos[1] = Blood_LastPlayerPos[client][1];
	spawnPos[2] = Blood_LastPlayerPos[client][2] + 20.0;
	TeleportEntity(marker, spawnPos, NULL_VECTOR, NULL_VECTOR);
}

public bool:IsValidMarker(marker) 
{
	if (IsValidEntity(marker)) 
	{
		decl String:buffer[128];
		GetEntityClassname(marker, buffer, sizeof(buffer));
		if (strcmp(buffer,"entity_revive_marker",false) == 0)
		{
			return true;
		}
	}
	return false;
}

public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontbroadcast) 
{
	new userid = GetEventInt(event, "userid");
	new clientIdx = GetClientOfUserId(userid);
	
	if(bloodisboss && MaxClientRevives != 0)
	{
		RemoveReanimator(clientIdx);
		clientRevives[clientIdx]++;
	}
	
	if(RoundInProgress && bloodisboss && MaxClientRevives != 0 && givehookback)
	{
		Blood_ReverifyGrapplinkhooksAt[clientIdx] = GetEngineTime() + 0.1;
	}
	
	return Plugin_Continue;
}

public Action:OnChangeClass(Handle:event, const String:name[], bool:dontbroadcast) 
{
	if(bloodisboss)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		ChangeClass[client] = true;
	}
	return Plugin_Continue;
}

public OnClientDisconnect(client) 
{
	if(bloodisboss)
	{
		if(MaxClientRevives!=0)
		{
			RemoveReanimator(client);
		}
		currentTeam[client] = 0;
		ChangeClass[client] = false;
	}
 }

public Blood_AddHooks()
{
	if (hooksEnabled)
		return;
	HookEvent("teamplay_broadcast_audio", OnAnnounce, EventHookMode_Pre);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("player_changeclass", OnChangeClass);
	HookEvent("object_deflected", OnDeflectObject);
	
	hooksEnabled = true;
}

public Blood_RemoveHooks()
{
	if (!hooksEnabled)
		return;
	UnhookEvent("teamplay_broadcast_audio", OnAnnounce, EventHookMode_Pre);
	UnhookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	UnhookEvent("player_changeclass", OnChangeClass);
	UnhookEvent("object_deflected", OnDeflectObject);

	hooksEnabled = false;
}

public Action:OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!FF2_IsFF2Enabled())
		return;
		
	Blood_WaveTick = FAR_FUTURE;
	NewGrenadeTimer = FAR_FUTURE;
	Blood_AdminTauntAt = FAR_FUTURE;
	Blood_RemoveUberAt = FAR_FUTURE;
	Blood_HUDSync = FAR_FUTURE;
	grenadeCount=0;
	bloodisboss = false;
		
	for(new clientIdx=1;clientIdx<=MaxClients;clientIdx++)
	{
		if(!IsValidClient(clientIdx))
			continue;
		
		Raging[clientIdx] = false;	
		Nextlive[clientIdx] = false;
		IsBloodrider[clientIdx]=false;
		cantGetLives[clientIdx] = false;	
		IsRandomDifficultyMode = false;
		
		timeleft_stacks[clientIdx]=0;
		BloodriderSpeed[clientIdx]=0.0;
		
		new bossIdx = FF2_GetBossIndex(clientIdx);
		if(bossIdx>=0)
		{
			if (FF2_HasAbility(bossIdx, this_plugin_name, CONFIG_BLOOD))
			{
				RoundInProgress = true;
				IsBloodrider[clientIdx]=true;
				bloodisboss = true;
				BloodriderBossIdx=bossIdx;
				
				weapondifficulty = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CONFIG_BLOOD, 1);
				
				grapplinkhookboss = bool:FF2_GetAbilityArgument(bossIdx, this_plugin_name, CONFIG_BLOOD, 2);
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CONFIG_BLOOD, 3, hookbossargs, MAX_WEAPON_ARG_LENGTH);
				
				grapplinkhookplayers = bool:FF2_GetAbilityArgument(bossIdx, this_plugin_name, CONFIG_BLOOD, 4);
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CONFIG_BLOOD, 5, hookplayersargs, MAX_WEAPON_ARG_LENGTH);
				givehookback = bool:FF2_GetAbilityArgument(bossIdx, this_plugin_name, CONFIG_BLOOD, 6);
				
				if(!weapondifficulty)
				{
					IsRandomDifficultyMode = true;
					Minimum=FF2_GetAbilityArgument(bossIdx, this_plugin_name, CONFIG_BLOOD, 10, 1); // Minimum level to roll on random mode
					Maximum=FF2_GetAbilityArgument(bossIdx, this_plugin_name, CONFIG_BLOOD, 11, 5); // Max level to roll on random mode
					weapondifficulty=GetRandomInt(Minimum,Maximum);
				}
				LevelingUp=FF2_GetAbilityArgument(bossIdx, this_plugin_name, CONFIG_BLOOD, 12); // Allow Bloodrider to change difficulty level on random mode?
				
				Waveenabled = bool:FF2_GetAbilityArgument(bossIdx, this_plugin_name, CONFIG_BLOOD, 13);
				grenadeExtention = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CONFIG_BLOOD, 14);
				startTime = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CONFIG_BLOOD, 15, 60);
				BloodMaxWaves = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CONFIG_BLOOD, 16);
				
				MaxClientRevives=FF2_GetAbilityArgument(bossIdx, this_plugin_name, CONFIG_BLOOD, 17); // Allow Reanimator
				ReviveMarkerDecayTime=FF2_GetAbilityArgument(bossIdx, this_plugin_name, CONFIG_BLOOD, 18); // Reanimator decay time
				
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CONFIG_BLOOD, 19, ScoutSpeed, sizeof(ScoutSpeed));
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CONFIG_BLOOD, 20, SoldierSpeed, sizeof(SoldierSpeed));
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CONFIG_BLOOD, 21, PyroSpeed, sizeof(PyroSpeed));
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CONFIG_BLOOD, 22, DemoSpeed, sizeof(DemoSpeed));
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CONFIG_BLOOD, 23, HeavySpeed, sizeof(HeavySpeed));
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CONFIG_BLOOD, 24, EngineerSpeed, sizeof(EngineerSpeed));
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CONFIG_BLOOD, 25, MedicSpeed, sizeof(MedicSpeed));
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CONFIG_BLOOD, 26, SniperSpeed, sizeof(SniperSpeed));
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CONFIG_BLOOD, 27, SpySpeed, sizeof(SpySpeed));

				// Loading Strings
				ReadCenterText(bossIdx, CONFIG_BLOOD, 28, BLOOD_BossHud[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, MaxClientRevives>0 ? 29 : 30, BLOOD_Client[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 31, BLOOD_Easy[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 32, BLOOD_Normal[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 33, BLOOD_Intermediate[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 34, BLOOD_Difficult[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 35, BLOOD_Lunatic[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 36, BLOOD_Insane[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 37, BLOOD_Godlike[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 38, BLOOD_GrenadeHell[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 39, BLOOD_TrueBloodrider[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 40, BLOOD_RNGDisplay[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 41, BLOOD_Counter[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 42, BLOOD_Counter2[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 43, BLOOD_CombatModeNoMelee[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 44, BLOOD_CombatModeWithMelee[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 45, Blood_Stats[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 46, Blood_MyStats[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 47, Blood_specHUD[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 48, Blood_specHUD2[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 49, Blood_specHUD3[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 50, Blood_statHUD[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 51, BLOOD_NoMoreRevives[clientIdx]);

				ReadCenterText(bossIdx, CONFIG_BLOOD, 52, regenerationHUD[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 53, regeneratedHUD[clientIdx]);
				ReadCenterText(bossIdx, CONFIG_BLOOD, 54, warningHUD[clientIdx]);
			
				// Everything is now inside this here
				SwitchSouls(clientIdx, grapplinkhookboss, Waveenabled, false);
				Blood_HUDSync=GetEngineTime()+0.2;
				RefreshDifficulty(weapondifficulty);
				PrintToServer("Bloodrider's Difficulty will be %d", weapondifficulty);
				
				SetHudTextParams(-1.0, 0.67, 5.0, 255, 255, 255, 255);
				switch(Waveenabled)
				{
					case 1:
					{
						ShowHudText(clientIdx, -1, BLOOD_CombatModeNoMelee[clientIdx]);
						Blood_WaveTick=GetEngineTime()+1.0;
					}
					case 0:
					{
						ShowHudText(clientIdx, -1, BLOOD_CombatModeWithMelee[clientIdx]);
					}
				}
				
				if(AdditionalVoiceOvers == 1 || AdditionalVoiceOvers == 3)
					Blood_AdminTauntAt = GetEngineTime() + 6.0;
				
				if(grapplinkhookplayers)
					GrapplinkhookForPlayers();
			}
		}
		
		// stuff for Bloodrider main
		if (bloodisboss)
		{
			for (new bloodIdx = 1; bloodIdx < MaxClients; bloodIdx++)
			{
				// gotta initialize this, in case someone ducks until they die (lol)
				if (IsValidClient(bloodIdx))
					GetEntPropVector(bloodIdx, Prop_Send, "m_vecOrigin", Blood_LastPlayerPos[bloodIdx]);
				Blood_RemoveReviveMarkerAt[bloodIdx] = FAR_FUTURE;
				Blood_MoveReviveMarkerAt[bloodIdx] = FAR_FUTURE;
				Blood_ReverifyGrapplinkhooksAt[bloodIdx] = FAR_FUTURE;
				reviveMarker[bloodIdx] = INVALID_ENTREF;
			}
		}
	}
}

public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	// ensure we should be doing any of this at all
	if (!bloodisboss)
		return;

	new attacker=GetClientOfUserId(GetEventInt(event, "attacker"));
	new victim=GetClientOfUserId(GetEventInt(event, "userid"));

	if ((GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER) != 0)
		return; // sarysa, fix an error where dead ringer drops a revive marker
		
	if (IsBloodrider[victim])
	{
		Blood_Deaths[victim]++;
		return; // sarysa, fix an error when the hale loses
	}

	// allow revive for victim regardless of cause of death
	if (MaxClientRevives!=0 && !IsBoss(victim))
	{
		DropReviveMarker(victim);
	}
	
	if(IsBloodrider[attacker])
	{
		new bool:AllowgainingRage = bool:FF2_GetAbilityArgument(BloodriderBossIdx, this_plugin_name, LIFELOSE_BLOOD, 7);
		new Float:rageonkill = FF2_GetAbilityArgumentFloat(BloodriderBossIdx, this_plugin_name, LIFELOSE_BLOOD, 8);
		new Float:bRage = FF2_GetBossCharge(BloodriderBossIdx, 0);
		new Float:BloodGiveRage;

		if(Nextlive[attacker] && AllowgainingRage)
		{
			if(bRage + rageonkill > 100.0) // We don't want RAGE to exceed more than 100%
				BloodGiveRage = 100.0;
			else if (bRage + rageonkill < 100.0)
				BloodGiveRage = bRage+rageonkill;
		
			FF2_SetBossCharge(BloodriderBossIdx, 0, BloodGiveRage);
		}
		
		new bool:AllowgainingHealth = bool:FF2_GetAbilityArgument(BloodriderBossIdx, this_plugin_name, RAGE_BLOOD, 6);
		new Float:healthgained = FF2_GetAbilityArgumentFloat(BloodriderBossIdx, this_plugin_name, RAGE_BLOOD, 7);
		new health = FF2_GetBossHealth(BloodriderBossIdx);
		new maxhealth = FF2_GetBossMaxHealth(BloodriderBossIdx);
		
		if(Raging[attacker] && AllowgainingHealth)
		{
			health = RoundToCeil(health + (maxhealth * healthgained));
			if(health > maxhealth)
			{
				health = maxhealth;
			}
			
			FF2_SetBossHealth(BloodriderBossIdx, health);
		}
		
		if(GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon") == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Primary))
		{	
			Blood_grenadeKills[attacker]++;
		}
		else if(GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon") == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee))
		{
			Blood_meleeKills[attacker]++;
		}
		else if(GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon") == GetPlayerWeaponSlot(attacker, TFWeaponSlot_Item1))
		{
			Blood_grapplinkKills[attacker]++;
		}
	}
}	


public Action:OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	grenadeCount=0;
	RoundInProgress = false;
	
	if(bloodisboss)
	{
		weapondifficulty = 0;
		MaxClientRevives = 0;
		bloodisboss = false;
		IsRandomDifficultyMode = false;
		
		Blood_RemoveHooks();

		if(AdditionalVoiceOvers == 1 || AdditionalVoiceOvers == 3)
		{
			if(GetEventInt(event, "winning_team") == FF2_GetBossTeam())
				BossIsWinner = true;
			else if (GetEventInt(event, "winning_team") == ((FF2_GetBossTeam()==_:TFTeam_Blue) ? (_:TFTeam_Red) : (_:TFTeam_Blue)))
				BossIsWinner = false;
		}
		
		for(new client=1;client<=MaxClients;client++)
		{
			if(!IsValidClient(client))
				continue;
			
			if(IsBloodrider[client])
			{
				if(AdditionalVoiceOvers == 1 || AdditionalVoiceOvers == 3)
				{
					if(BossIsWinner)
						Blood_Wins[client]++;
					else
						Blood_Losses[client]++;
				}
				
				CPrintToChat(client, Blood_MyStats[client], Blood_Wins[client], Blood_Losses[client], Blood_grenadeKills[client], Blood_Deaths[client]);
				for(new target=1;target<=MaxClients;target++)
				{
					if(!IsValidClient(target))
						continue;
					if(IsBloodrider[target])
						continue;
					CPrintToChat(target, Blood_Stats[client], client, Blood_Wins[client], Blood_Losses[client], Blood_grenadeKills[client], Blood_Deaths[client]);
				}
				SaveStatCookie(client);
				
				IsBloodrider[client]=false;
				SDKUnhook(client, SDKHook_PreThink, BloodSpeed_Prethink);
				BloodriderSpeed[client]=0.0;
				Raging[client] = false;	
				Nextlive[client] = false;
			}
			
			if(Blood_RemoveReviveMarkerAt[client] != FAR_FUTURE)
			{
				RemoveReanimator(client);
			}
		}

		if(AdditionalVoiceOvers == 1 || AdditionalVoiceOvers == 3)
		{
			CreateTimer(5.0, RoundResultSound, _, TIMER_FLAG_NO_MAPCHANGE); // sarysa: kept this one around, but fixed param #4 to be the no mapchange flag
		}
	}
}

public Action:FF2_OnAbility2(boss,const String:plugin_name[],const String:ability_name[],action)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue;

	new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if (!strcmp(ability_name, RAGE_BLOOD)) 	
	{
		TF2_AddCondition(client, TFCond_Buffed, GetTimerDuration(boss, ability_name, 1, false)); 					// Minicrits
		TF2_AddCondition(client, TFCond_DefenseBuffNoCritBlock, GetTimerDuration(boss, ability_name, 1, false));	// Defensive Buff
		TF2_AddCondition(client, TFCond_RegenBuffed, GetTimerDuration(boss, ability_name, 1, false));				// Regen Buff
		
		new grenade=FF2_GetAbilityArgument(boss,this_plugin_name,ability_name, 2);	// Ammo

		SwitchSouls(client, grapplinkhookboss, Waveenabled, true);
		SetAmmo(client, TFWeaponSlot_Primary, grenade);

		NewGrenadeTimer = GetTimerDuration(boss, ability_name, 3, true);
		Raging[client] = true;
		
		new Float:reflectionchance = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 4);
		if (reflectionchance>0.0)
		{
			if (GetRandomFloat(0.0, 1.0)<=reflectionchance)
			{
				TF2_AddCondition(client, TFCond_RuneWarlock, GetTimerDuration(boss, ability_name, 5, false));  //Warlock
			}
		}
		
		if (AdditionalVoiceOvers == 2 || AdditionalVoiceOvers == 3)
		{
			for(new i = 1; i <= MaxClients; i++ )
			{
				ClassResponses(i);
			}
		}
	}
	else if(!strcmp(ability_name, LIFELOSE_BLOOD)) 	
	{
		TF2_AddCondition(client, TFCond_HalloweenCritCandy, GetTimerDuration(boss, ability_name, 1, false));  // Crits
		TF2_AddCondition(client, TFCond_Ubercharged, GetTimerDuration(boss, ability_name, 1, false)); // Ubercharge
		Blood_RemoveUberAt = GetTimerDuration(boss, ability_name, 1);
		SetEntProp(client, Prop_Data, "m_takedamage", 0);

		new lifelosegrenade=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 2);	// Ammo

		SwitchSouls(client, grapplinkhookboss, Waveenabled, true);
		SetAmmo(client, TFWeaponSlot_Primary, lifelosegrenade);

		NewGrenadeTimer = GetTimerDuration(boss, ability_name, 3, true);
		Nextlive[client] = true;
			
		switch(GetRandomInt(0,3))
		{
			case 0:
			{
				TF2_AddCondition(client, TFCond_RuneStrength, GetTimerDuration(boss, ability_name, 4, false));  //Strength
			}
			case 1:
			{
				TF2_AddCondition(client, TFCond_RuneHaste, GetTimerDuration(boss, ability_name, 4, false));  //Haste
			}
			case 2:
			{
				TF2_AddCondition(client, TFCond_RunePrecision, GetTimerDuration(boss, ability_name, 4, false));  //Precision
			}
			case 3:
			{
				TF2_AddCondition(client, TFCond_RuneAgility, GetTimerDuration(boss, ability_name, 4, false));  //Agility
			}
		}
		
		if (AdditionalVoiceOvers == 2 || AdditionalVoiceOvers == 3)
		{
			for(new i = 1; i <= MaxClients; i++ )
			{
				ClassResponses(i);
			}
		}
		
		//Level up stuff
		if(LevelingUp)
		{
			if(IsRandomDifficultyMode && LevelingUp==1)
				weapondifficulty=GetRandomInt(Minimum,Maximum);
			else
			{
				switch(weapondifficulty)
				{
					case 9:
					{
						if(IsRandomDifficultyMode)
							weapondifficulty=Minimum;
						else
							weapondifficulty=FF2_GetAbilityArgument(boss, this_plugin_name, CONFIG_BLOOD, 1);
					}
					default: weapondifficulty=weapondifficulty+1;
				}
			}
			RefreshDifficulty(weapondifficulty);
		}
	}
	return Plugin_Continue;
}

public OnGameFrame()
{
	Blood_HUDSyncTick(GetEngineTime());
	
	if (!RoundInProgress)
		return;
		
	if (bloodisboss)
		Blood_MiscStuffTick(GetEngineTime());
}

public Blood_HUDSyncTick(Float:curTime)
{
	if(curTime>=Bloodrider_FindBloodriderAt)
	{
		if(FF2_GetRoundState()>0)
		{
			Bloodrider_FindBloodriderAt=FAR_FUTURE;
			return;
		}
		for(new clientIdx=1;clientIdx<=MaxClients;clientIdx++)
		{
			if(!IsValidClient(clientIdx))
				continue;
			
			new bossIdx=FF2_GetBossIndex(clientIdx);
			if(bossIdx>=0 && FF2_HasAbility(bossIdx, this_plugin_name, CONFIG_BLOOD))
			{
				RegenerateLivesOn = bool:FF2_GetAbilityArgument(bossIdx, this_plugin_name, CONFIG_BLOOD, 7);
				IntroOutroOn = bool:FF2_GetAbilityArgument(bossIdx, this_plugin_name, CONFIG_BLOOD, 8);
				AdditionalVoiceOvers = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CONFIG_BLOOD, 9);
				
				bloodisboss = true;
				Blood_AddHooks();
				IsRandomDifficultyMode = false;

				// Intro BGM
				if(IntroOutroOn)
				{
					char sound[PLATFORM_MAX_PATH];
				
					if(FF2_RandomSound("sound_bloodrider_intromusic", sound, sizeof(sound), bossIdx))
					{
						EmitSoundToAll(sound);
					}	
					if(FF2_RandomSound("sound_bloodrider_outtromusic", sound, sizeof(sound), bossIdx))
					{
						BOuttro=sound;
					}
				}
			}
		}
		Bloodrider_FindBloodriderAt=FAR_FUTURE;
	}
	
	if (curTime >= Blood_HUDSync)
	{
		if(FF2_GetRoundState()!=1)
		{
			Blood_HUDSync=FAR_FUTURE;
			return;
		}
		
		new String:BossHUDTxt[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH];
		new String:ClientHudTxt[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH];
		for(new clientIdx=1;clientIdx<=MaxClients;clientIdx++)
		{
			if (IsValidClient(clientIdx) && !(GetClientButtons(clientIdx) & IN_SCORE))
			{
				if(IsBoss(clientIdx) && IsBloodrider[clientIdx])
				{
					SetHudTextParams(-1.0, 0.73, 0.4, 255, 255, 255, 255);
					Format(BossHUDTxt[clientIdx], sizeof(BossHUDTxt[]), BLOOD_BossHud[clientIdx], Bloodrider_DifficultyLevelString[clientIdx]);
					ShowSyncHudText(clientIdx, BossHUDS, BossHUDTxt[clientIdx]);
					
					SetHudTextParams(-1.0, 0.99, 0.4, 255, 255, 255, 255);	
					ShowSyncHudText(clientIdx, StatHUDS, Blood_statHUD[clientIdx], Blood_Wins[clientIdx], Blood_Losses[clientIdx], Blood_grenadeKills[clientIdx], Blood_Deaths[clientIdx]);
				}
			
				if(IsPlayerAlive(clientIdx) && GetClientTeam(clientIdx)!=FF2_GetBossTeam())
				{
					SetHudTextParams(-1.0, 0.75, 0.4, 255, 255, 255, 255);
					if(MaxClientRevives>0)
					{
						Format(ClientHudTxt[clientIdx], sizeof(ClientHudTxt[]), BLOOD_Client[clientIdx], Bloodrider_DifficultyLevelString[clientIdx], clientRevives[clientIdx], MaxClientRevives);
					}
					else
					{
						Format(ClientHudTxt[clientIdx], sizeof(ClientHudTxt[]), BLOOD_Client[clientIdx], Bloodrider_DifficultyLevelString[clientIdx]);				
					}
					ShowSyncHudText(clientIdx, ClientHUDS, ClientHudTxt[clientIdx]);			
				}
			
				if(!IsPlayerAlive(clientIdx))
				{
					new observerIdx=GetEntPropEnt(clientIdx, Prop_Send, "m_hObserverTarget");
					SetHudTextParams(-1.0, 0.85, 0.4, 255, 255, 255, 255);	
					if(IsValidClient(observerIdx) && observerIdx!=clientIdx)
					{
						if(!IsBloodrider[observerIdx])
						{
							ShowSyncHudText(clientIdx, ClientHUDS, Blood_specHUD2[clientIdx], clientRevives[clientIdx], observerIdx, clientRevives[observerIdx]);
						}
						else
						{
							ShowSyncHudText(clientIdx, ClientHUDS, Blood_specHUD3[clientIdx], observerIdx, Blood_Wins[observerIdx], Blood_Losses[observerIdx], Blood_grenadeKills[observerIdx], Blood_Deaths[observerIdx]);
						}
					}	
					else
					{
						ShowSyncHudText(clientIdx, ClientHUDS, Blood_specHUD[clientIdx], clientRevives[clientIdx]);
					}
					continue;	
				}
			}
		}
		Blood_HUDSync+=0.1;
	}

	if(curTime>=Blood_WaveTick)
	{
		static wavesDone=0;
		static BloodCount=0;
		if(!BloodCount && !wavesDone)
		{
			wavesDone++;
			BloodCount+=startTime;
			Blood_WaveTick+=0.01;
			return;
		}
		
		static BloodTimePassed=0;
		if(FF2_GetRoundState()!=1)
		{	
			wavesDone=0;
			BloodCount=startTime;
			BloodTimePassed=0;
			Blood_WaveTick=FAR_FUTURE;
			return;
		}
	
		for(new clientIdx=1;clientIdx<=MaxClients;clientIdx++)
		{
			if(!IsValidClient(clientIdx))
				continue;
			
			new String:waveTime[6];
			if(BloodCount/60>9)
			{
				IntToString(BloodCount/60, waveTime, sizeof(waveTime));
			}	
			else
			{
				Format(waveTime, sizeof(waveTime), "0%i", BloodCount/60);
			}
	
			if(BloodCount%60>9)
			{
				Format(waveTime, sizeof(waveTime), "%s:%i", waveTime, BloodCount%60);
			}	
			else
			{
				Format(waveTime, sizeof(waveTime), "%s:0%i", waveTime, BloodCount%60);
			}
			
			new String:countdown[MAXPLAYERS+1][MAX_CENTER_TEXT_LENGTH];
			SetHudTextParams(-1.0, 0.25, 1.1, BloodCount<=30 ? 255 : 0, BloodCount>10 ? 255 : 0, 0, 255);
			
			if(BloodMaxWaves>0)
			{
				Format(countdown[clientIdx],sizeof(countdown[]), BLOOD_Counter2[clientIdx], wavesDone, BloodMaxWaves, waveTime);
			}
			else
			{
				Format(countdown[clientIdx],sizeof(countdown[]), BLOOD_Counter[clientIdx], wavesDone, waveTime);			
			}
			
			ShowSyncHudText(clientIdx, counterHUD, countdown[clientIdx]);	
		
			if(!BloodCount)
			{
				if(IsBloodrider[clientIdx])
				{
					Grenadelauncher(clientIdx);
				}
				if(IsPlayerAlive(clientIdx) && !IsBoss(clientIdx))
				{
					// Give them survival points based on number of gernades
					new Handle:hPoints=CreateEvent("player_escort_score", true);
					SetEventInt(hPoints, "player", clientIdx);
					SetEventInt(hPoints, "points", grenadeCount);
					FireEvent(hPoints);
						
					new qPoints=FF2_GetQueuePoints(clientIdx)+(BloodTimePassed/4);
					FF2_SetQueuePoints(clientIdx, qPoints);
					CPrintToChat(clientIdx, "{olive}[FF2]{default} You have earned %i queue points for surviving a wave of %i gernades for %i seconds", qPoints, grenadeCount, BloodTimePassed);
						
					TF2_RegeneratePlayer(clientIdx);
					if(givehookback)
						GrapplinkhookForPlayers();
					HealPlayer(clientIdx);
				}
			}
		}
	
		if(BloodCount<=10)
		{
			char sound[PLATFORM_MAX_PATH];
			switch(BloodCount)
			{
				case 0: // Give ammo & reset timer
				{
					if(FF2_RandomSound("sound_blood_countdown_reset", sound, sizeof(sound), BloodriderBossIdx))
					{
						EmitSoundToAll(sound);
					}
					grenadeCount=0;
					
					if(BloodMaxWaves>0 && wavesDone>=BloodMaxWaves)
					{
						ForceTeamWin(0);
						wavesDone=0;
						BloodCount=startTime;
						BloodTimePassed=0;
						Blood_WaveTick=FAR_FUTURE;
						return;
					}
					
					wavesDone++;
					BloodCount=BloodTimePassed+grenadeExtention;
					BloodTimePassed=0;
					Blood_WaveTick+=1.0;
					
					return;
				}
				case 10,9,8,7,6,5,4,3,2,1:
				{
					if(FF2_RandomSound("sound_blood_countdown_tick", sound, sizeof(sound), BloodriderBossIdx))
					{
						EmitSoundToAll(sound);
					}
				}
			}				
		}
		BloodCount--;
		BloodTimePassed++;
		Blood_WaveTick+=1.0;
	}
}

public Blood_MiscStuffTick(Float:curTime)
{
	if (curTime >= NewGrenadeTimer)
	{
		for(new clientIdx=1;clientIdx<=MaxClients;clientIdx++)
		{
			if(!IsValidClient(clientIdx))
				continue;
			if(!IsBloodrider[clientIdx])
				continue;
				
			Grenadelauncher(clientIdx);
		}
		NewGrenadeTimer = FAR_FUTURE;
	}
	
	if (curTime >= Blood_AdminTauntAt)
	{
		WhatWereYouThinking();
		Blood_AdminTauntAt = FAR_FUTURE;
	}
	
	if (curTime >= Blood_RemoveUberAt)
	{
		for(new clientIdx=1;clientIdx<=MaxClients;clientIdx++)
		{
			if(!IsValidClient(clientIdx))
				continue;
			if(!IsBloodrider[clientIdx])
				continue;
				
			RemoveUber(clientIdx);
		}
		Blood_RemoveUberAt = FAR_FUTURE;
	}
	
	for (new clientIdx = 1; clientIdx < MaxClients; clientIdx++)
	{
		if (curTime >= Blood_MoveReviveMarkerAt[clientIdx])
			MoveMarker(clientIdx); // will also reset the timer

		if (curTime >= Blood_RemoveReviveMarkerAt[clientIdx])
		{	
			RemoveReanimator(clientIdx); // will also reset the timer
		}
		else if (Blood_RemoveReviveMarkerAt[clientIdx] != FAR_FUTURE)
		{
			if (IsBloodrider[clientIdx] && !IsValidClient(clientIdx) || GetClientTeam(clientIdx) == FF2_GetBossTeam() || GetClientTeam(clientIdx) < 2)
			{
				RemoveReanimator(clientIdx);
			}
			else if (reviveMarker[clientIdx] == INVALID_ENTREF) // something weird happened
				DropReanimator(clientIdx);
		}
			
		// everything below requires the player to be alive
		if (!IsValidClient(clientIdx))
			continue;
		
		if ((GetEntityFlags(clientIdx) & FL_DUCKING) == 0)
			GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", Blood_LastPlayerPos[clientIdx]);
			
		if (curTime >= Blood_ReverifyGrapplinkhooksAt[clientIdx])
		{
			Blood_ReverifyGrapplinkhooksAt[clientIdx] = FAR_FUTURE;
			GrapplinkhookForPlayers();
		}
	}
}

public WhatWereYouThinking()
{
	new String:BloodAlert[PLATFORM_MAX_PATH];
	strcopy(BloodAlert, PLATFORM_MAX_PATH, BloodCanLevelUpgrade[GetRandomInt(0, sizeof(BloodCanLevelUpgrade)-1)]);
	if (AdditionalVoiceOvers == 1 || AdditionalVoiceOvers == 3)
		EmitSoundToAll(BloodAlert);
}

public Action:RoundResultSound(Handle:hTimer, any:userid)
{
	new String:BloodRoundResult[PLATFORM_MAX_PATH];
	if (BossIsWinner)
		strcopy(BloodRoundResult, PLATFORM_MAX_PATH, BloodIsVictorious[GetRandomInt(0, sizeof(BloodIsVictorious)-1)]);
	else
		strcopy(BloodRoundResult, PLATFORM_MAX_PATH, BloodIsDefeated[GetRandomInt(0, sizeof(BloodIsDefeated)-1)]);	
	for(new i = 1; i <= MaxClients; i++ )
	{
		if(IsClientInGame(i) && IsClientConnected(i) && GetClientTeam(i) != FF2_GetBossTeam())
		{
			EmitSoundToClient(i, BloodRoundResult);	
		}
	}
	BossIsWinner = false;
}

public RemoveUber(Boss)
{
	SetEntProp(Boss, Prop_Data, "m_takedamage", 2);
	TF2_AddCondition(Boss, TFCond_UberchargeFading, 3.0);
}

public Action:OnDeflectObject(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(Waveenabled)
	{
		if(IsValidClient(client) && GetClientTeam(client) != FF2_GetBossTeam())
		{
			static deflected[MAXPLAYERS+1]=0;
			static deflect;
			deflect+=deflected[client];
			if(deflect>=5)
			{
				// Give them +1 points & +1 queue point for survival
				new Handle:hPoints=CreateEvent("player_escort_score", true);
				SetEventInt(hPoints, "player", client);
				SetEventInt(hPoints, "points", GetEventInt(hPoints, "points")+1);
				FireEvent(hPoints);
					
				new pts=1;
				FF2_SetQueuePoints(client, FF2_GetQueuePoints(client)+pts);
				CPrintToChat(client, "{olive}[FF2]{default} You have earned %i queue points for deflecting %i times", pts, deflected[client]);
				deflect-=deflected[client];
			}
			deflected[client]++;
		}
	}
	
}

public Action:FF2_OnLoseLife(index)
{
	new userid = FF2_GetBossUserId(index);
	new client=GetClientOfUserId(userid);
	if(index==-1 || !IsValidEdict(client) || !FF2_HasAbility(index, this_plugin_name, LIFELOSE_BLOOD) || !RegenerateLivesOn)
		return Plugin_Continue;
		
	if (cantGetLives[index])
	{
		//ForcePlayerSuicide(client);
	}
	else
	{
		cantGetLives[index] = true;
		timeleft[index]=FF2_GetAbilityArgument(index, this_plugin_name, LIFELOSE_BLOOD, 5, 60)+timeleft_stacks[index];
		timeleft_stacks[index]+=FF2_GetAbilityArgument(index, this_plugin_name, LIFELOSE_BLOOD, 6, 60);
		if (Timer_toReincarnate[index]!=INVALID_HANDLE)
			KillTimer(Timer_toReincarnate[index]);
		Timer_toReincarnate[index]=CreateTimer(1.0, Timer_nowUcanReincarnate, index, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		FF2_SetBossLives(index,2);
		FF2_SetBossHealth(index,FF2_GetBossMaxHealth(index));
		SetHudTextParams(-1.0, 0.35, 10.0, 255, 255, 255, 255);
		
		for(new player=1; player<=MaxClients; player++)
			if(IsValidClient(player) && GetClientTeam(player)!=FF2_GetBossTeam())
				ShowSyncHudText(player, cooldownHUD, regenerationHUD[index], timeleft[index]);
	}
	return Plugin_Continue;
}

public Action:Timer_nowUcanReincarnate(Handle:hTimer,any:index)
{
	timeleft[index]--;
	new boss=GetClientOfUserId(FF2_GetBossUserId(index));
	if (FF2_GetRoundState()!=1)
	{
		KillTimer(Timer_toReincarnate[index]);
		Timer_toReincarnate[index]=INVALID_HANDLE;	
	}
	else if (timeleft[index]<=0)
	{
		SetHudTextParams(-1.0, 0.42, 4.0, 255, 255, 255, 255);
		ShowSyncHudText(boss, cooldownHUD, regeneratedHUD[index]);
		FF2_SetBossLives(index,FF2_GetBossLives(index)+1);
		FF2_SetBossHealth(index, FF2_GetBossHealth(index)+FF2_GetBossMaxHealth(index));
		cantGetLives[index] = false;
		KillTimer(Timer_toReincarnate[index]);
		Timer_toReincarnate[index]=INVALID_HANDLE;	
	}
	else
	{
		SetHudTextParams(-1.0, 0.42, 1.0, 255, 255, 255, 255);
		ShowSyncHudText(boss, cooldownHUD, warningHUD[index], timeleft[index]);
	}
}

public OnEntityCreated(entity, const String:classname[])
{
	if(Waveenabled)
	{
		if (!strcmp(classname, "tf_projectile_pipe"))
		{
			SDKHook(entity, SDKHook_Spawn, Hook_OnGrenadeSpawn);
		}
	}
}

public Hook_OnGrenadeSpawn(entity)
{
	new owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	if(owner > 0 && owner <= MaxClients && IsBoss(owner))
	{
		grenadeCount++;
	}
}

public HealPlayer(clientIdx)
{
	new maxHealth = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, clientIdx);
	maxHealth += 100;
	SetEntProp(clientIdx, Prop_Send, "m_iHealth", maxHealth);
	SetEntProp(clientIdx, Prop_Data, "m_iHealth", maxHealth);
}

SwitchSouls(client, bool:grapplinkhook=false, bool:waveon=false, bool:rageisactive=false)
{
	// First, lets switch up the class
	switch(GetRandomInt(0, 8))
	{
		case 0:
			TF2_SetPlayerClass(client, TFClass_Scout);
		case 1:
			TF2_SetPlayerClass(client, TFClass_Soldier);
		case 2:
			TF2_SetPlayerClass(client, TFClass_Pyro);
		case 3:
			TF2_SetPlayerClass(client, TFClass_DemoMan);
		case 4:
			TF2_SetPlayerClass(client, TFClass_Heavy);
		case 5:
			TF2_SetPlayerClass(client, TFClass_Engineer);
		case 6:
			TF2_SetPlayerClass(client, TFClass_Medic);
		case 7:
			TF2_SetPlayerClass(client, TFClass_Sniper);
		case 8:
			TF2_SetPlayerClass(client, TFClass_Spy);
	}
	
	// Second, remove and give the boss a Grenade Launcher and the respected melee (and Grapplinkhook, if enabled)
	TF2_RemoveAllWeapons(client);
	
	new String:justattributes[256];
	if(grapplinkhook)
	{
		Format(justattributes, sizeof(justattributes), "214 ; %d ; %s", Blood_grapplinkKills[client], hookbossargs);
		SpawnWeapon(client, "tf_weapon_grapplinghook", 1152, 101, 5, justattributes);
	}
	
	if(rageisactive)
		Grenadelauncherrage(client);
	else
		Grenadelauncher(client);
	
	// Third, give the boss the melee weapon, model and speed, depending on which class he is right now
	switch(TF2_GetPlayerClass(client))
	{
		case TFClass_Scout:
		{
			if(!waveon)
			{
				switch(weapondifficulty)
				{
					case 1, 2, 3, 4:	SpawnWeapon(client, "tf_weapon_bat", 190, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 1 ; 2 ; 1.5 ; 214 ; %d", Blood_meleeKills[client]);
					case 5,6:	SpawnWeapon(client, "tf_weapon_bat", 190, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 3 ; 2 ; 3 ; 6 ; 0.8 ; 214 ; %d", Blood_meleeKills[client]);
					case 7,8:	SpawnWeapon(client, "tf_weapon_bat", 190, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 5 ; 2 ; 6 ; 6 ; 0.65 ; 214 ; %d", Blood_meleeKills[client]);
					case 9:	SpawnWeapon(client, "tf_weapon_bat", 190, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 10 ; 2 ; 10 ; 6 ; 0.5 ; 214 ; %d", Blood_meleeKills[client]);
				}
			}
			BloodriderSpeed[client] = StringToFloat(ScoutSpeed);
		}
		case TFClass_Soldier:
		{
			if(!waveon)
			{
				switch(weapondifficulty)
				{
					case 1, 2, 3, 4:	SpawnWeapon(client, "tf_weapon_shovel", 196, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 2 ; 2 ; 3 ; 214 ; %d", Blood_meleeKills[client]);
					case 5, 6:	SpawnWeapon(client, "tf_weapon_shovel", 196, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 5 ; 2 ; 5 ; 6 ; 0.8 ; 214 ; %d", Blood_meleeKills[client]);
					case 7, 8:	SpawnWeapon(client, "tf_weapon_shovel", 196, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 8 ; 2 ; 7 ; 6 ; 0.65 ; 214 ; %d", Blood_meleeKills[client]);
					case 9:	SpawnWeapon(client, "tf_weapon_shovel", 196, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 10 ; 2 ; 10 ; 6 ; 0.5 ; 214 ; %d", Blood_meleeKills[client]);
				}
			}
			BloodriderSpeed[client] = StringToFloat(SoldierSpeed);
		}
		case TFClass_Pyro:
		{
			if(!waveon)
			{
				switch(weapondifficulty)
				{
					case 1, 2, 3, 4:	SpawnWeapon(client, "tf_weapon_fireaxe", 192, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 2 ; 2 ; 3 ; 214 ; %d", Blood_meleeKills[client]);
					case 5, 6:	SpawnWeapon(client, "tf_weapon_fireaxe", 192, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 5 ; 2 ; 5 ; 6 ; 0.8 ; 214 ; %d", Blood_meleeKills[client]);
					case 7, 8:	SpawnWeapon(client, "tf_weapon_fireaxe", 192, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 8 ; 2 ; 7 ; 6 ; 0.65 ; 214 ; %d", Blood_meleeKills[client]);
					case 9:	SpawnWeapon(client, "tf_weapon_fireaxe", 192, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 10 ; 2 ; 10 ; 6 ; 0.5 ; 214 ; %d", Blood_meleeKills[client]);
				}
			}
			BloodriderSpeed[client] = StringToFloat(PyroSpeed);
		}
		case TFClass_DemoMan:
		{
			if(!waveon)
			{
				switch(weapondifficulty)
				{
					case 1, 2, 3, 4:	SpawnWeapon(client, "tf_weapon_bottle", 191, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 2 ; 2 ; 3 ; 214 ; %d", Blood_meleeKills[client]);
					case 5, 6:	SpawnWeapon(client, "tf_weapon_bottle", 191, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 5 ; 2 ; 5 ; 6 ; 0.8 ; 214 ; %d", Blood_meleeKills[client]);
					case 7, 8:	SpawnWeapon(client, "tf_weapon_bottle", 191, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 8 ; 2 ; 7 ; 6 ; 0.65 ; 214 ; %d", Blood_meleeKills[client]);
					case 9:	SpawnWeapon(client, "tf_weapon_bottle", 191, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 10 ; 2 ; 10 ; 6 ; 0.5 ; 214 ; %d", Blood_meleeKills[client]);
				}
			}
			BloodriderSpeed[client] = StringToFloat(DemoSpeed);
		}
		case TFClass_Heavy:
		{
			if(!waveon)
			{
				switch(weapondifficulty)
				{
					case 1, 2, 3, 4:	SpawnWeapon(client, "tf_weapon_fists", 195, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 2 ; 2 ; 3 ; 214 ; %d", Blood_meleeKills[client]);
					case 5, 6:	SpawnWeapon(client, "tf_weapon_fists", 195, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 5 ; 2 ; 5 ; 6 ; 0.8 ; 214 ; %d", Blood_meleeKills[client]);
					case 7, 8:	SpawnWeapon(client, "tf_weapon_fists", 195, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 8 ; 2 ; 7 ; 6 ; 0.65 ; 214 ; %d", Blood_meleeKills[client]);
					case 9:	SpawnWeapon(client, "tf_weapon_fists", 195, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 10 ; 2 ; 10 ; 6 ; 0.5 ; 214 ; %d", Blood_meleeKills[client]);
				}
			}
			BloodriderSpeed[client] = StringToFloat(HeavySpeed);
		}
		case TFClass_Engineer:
		{
			if(!waveon)
			{
				switch(weapondifficulty)
				{
					case 1, 2, 3, 4:	SpawnWeapon(client, "tf_weapon_wrench", 197, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 2 ; 2 ; 3 ; 214 ; %d", Blood_meleeKills[client]);
					case 5, 6:	SpawnWeapon(client, "tf_weapon_wrench", 197, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 5 ; 2 ; 5 ; 6 ; 0.8 ; 214 ; %d", Blood_meleeKills[client]);
					case 7, 8:	SpawnWeapon(client, "tf_weapon_wrench", 197, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 8 ; 2 ; 7 ; 6 ; 0.65 ; 214 ; %d", Blood_meleeKills[client]);
					case 9:	SpawnWeapon(client, "tf_weapon_wrench", 197, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 10 ; 2 ; 10 ; 6 ; 0.5 ; 214 ; %d", Blood_meleeKills[client]);
				}
			}
			BloodriderSpeed[client] = StringToFloat(EngineerSpeed);
		}
		case TFClass_Medic:
		{
			if(!waveon)
			{
				switch(weapondifficulty)
				{
					case 1, 2, 3, 4:	SpawnWeapon(client, "tf_weapon_bonesaw", 198, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 2 ; 2 ; 3 ; 214 ; %d", Blood_meleeKills[client]);
					case 5, 6:	SpawnWeapon(client, "tf_weapon_bonesaw", 198, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 5 ; 2 ; 5 ; 6 ; 0.8 ; 214 ; %d", Blood_meleeKills[client]);
					case 7, 8:	SpawnWeapon(client, "tf_weapon_bonesaw", 198, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 8 ; 2 ; 7 ; 6 ; 0.65 ; 214 ; %d", Blood_meleeKills[client]);
					case 9:	SpawnWeapon(client, "tf_weapon_bonesaw", 198, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 10 ; 2 ; 10 ; 6 ; 0.5 ; 214 ; %d", Blood_meleeKills[client]);
				}
			}
			BloodriderSpeed[client] = StringToFloat(MedicSpeed);
		}
		case TFClass_Sniper:
		{
			if(!waveon)
			{
				switch(weapondifficulty)
				{
					case 1, 2, 3, 4:	SpawnWeapon(client, "tf_weapon_club", 193, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 2 ; 2 ; 3 ; 214 ; %d", Blood_meleeKills[client]);
					case 5, 6:	SpawnWeapon(client, "tf_weapon_club", 193, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 5 ; 2 ; 5 ; 6 ; 0.8 ; 214 ; %d", Blood_meleeKills[client]);
					case 7, 8:	SpawnWeapon(client, "tf_weapon_club", 193, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 8 ; 2 ; 7 ; 6 ; 0.65 ; 214 ; %d", Blood_meleeKills[client]);
					case 9:	SpawnWeapon(client, "tf_weapon_club", 193, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 10 ; 2 ; 10 ; 6 ; 0.5 ; 214 ; %d", Blood_meleeKills[client]);
				}
			}
			BloodriderSpeed[client] = StringToFloat(SniperSpeed);
		}
		case TFClass_Spy:
		{
			if(!waveon)
			{
				switch(weapondifficulty)
				{
					case 1, 2, 3, 4:	SpawnWeapon(client, "tf_weapon_knife", 194, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 2 ; 2 ; 1.5 ; 214 ; %d", Blood_meleeKills[client]);
					case 5, 6:	SpawnWeapon(client, "tf_weapon_knife", 194, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 5 ; 2 ; 3 ; 6 ; 0.8 ; 214 ; %d", Blood_meleeKills[client]);
					case 7, 8:	SpawnWeapon(client, "tf_weapon_knife", 194, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 8 ; 2 ; 6 ; 6 ; 0.65 ; 214 ; %d", Blood_meleeKills[client]);
					case 9:	SpawnWeapon(client, "tf_weapon_knife", 194, 100, 5, "2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 68 ; 10 ; 2 ; 10 ; 6 ; 0.5 ; 214 ; %d", Blood_meleeKills[client]);
				}
			}
			BloodriderSpeed[client] = StringToFloat(SpySpeed);
		}
	}
	
	SDKUnhook(client, SDKHook_PreThink, BloodSpeed_Prethink);
	SDKHook(client, SDKHook_PreThink, BloodSpeed_Prethink);
	
	// Removing all wearables
	RemoveAttachable(client, "tf_wearable");
	RemoveAttachable(client, "tf_wearable_demoshield");
	RemoveAttachable(client, "tf_powerup_bottle");	
	RemoveAttachable(client, "tf_wearable_razorback");
	
	switch(TF2_GetPlayerClass(client))
	{
		case TFClass_Scout: SetVariantString(BLOODRIDER_SCOUT);
		case TFClass_Soldier: SetVariantString(BLOODRIDER_SOLDIER);
		case TFClass_Pyro: SetVariantString(BLOODRIDER_PYRO);
		case TFClass_DemoMan: SetVariantString(BLOODRIDER_DEMOMAN);
		case TFClass_Heavy: SetVariantString(BLOODRIDER_HEAVY);
		case TFClass_Engineer: SetVariantString(BLOODRIDER_ENGINEER);
		case TFClass_Medic: SetVariantString(BLOODRIDER_MEDIC);
		case TFClass_Sniper: SetVariantString(BLOODRIDER_SNIPER);
		case TFClass_Spy: SetVariantString(BLOODRIDER_SPY);
	}
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
}

public BloodSpeed_Prethink(client)
{
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", BloodriderSpeed[client]);
}

Grenadelauncher(client)
{
	new index;
	if(TF2_GetPlayerClass(client)==TFClass_Scout||TF2_GetPlayerClass(client)==TFClass_Soldier||TF2_GetPlayerClass(client)==TFClass_Pyro||TF2_GetPlayerClass(client)==TFClass_Heavy)
		index = 18;
	else
		index = 19;
	
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
	switch(weapondifficulty)
	{
		case 1: // Easy
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 1 ; 0.01 ; 6 ; 0.60 ; 97 ; 0.50 ; 4 ; 5 ; 114 ; 1 ; 112 ; 1.1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_meleeKills[client])); 
		case 2:	// Normal
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 1 ; 0.05 ; 6 ; 0.55 ; 97 ; 0.45 ; 4 ; 7 ; 114 ; 1 ; 112 ; 1.3 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_meleeKills[client])); 
		case 3:	// Intermediate
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 1 ; 0.10 ; 6 ; 0.40 ; 97 ; 0.35 ; 4 ; 10 ; 114 ; 1 ; 112 ; 1.6 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_meleeKills[client])); 
		case 4: // Difficult
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 1 ; 0.20 ; 6 ; 0.35 ; 97 ; 0.30 ; 4 ; 20 ; 114 ; 1 ; 112 ; 1.9 ; 37 ; 1.5 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_meleeKills[client])); 
		case 5: // Very Hard
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 1 ; 0.30 ; 6 ; 0.30 ; 97 ; 0.25 ; 4 ; 50 ; 114 ; 1 ; 112 ; 2 ; 37 ; 1.5 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_meleeKills[client])); 
		case 6: // Insane
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 1 ; 0.40 ; 6 ; 0.25 ; 97 ; 0.20 ; 4 ; 75 ; 114 ; 1 ; 112 ; 2 ; 37 ; 2.0 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_meleeKills[client])); 
		case 7: // Godlike
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 1 ; 0.60 ; 6 ; 0.20 ; 97 ; 0.15 ; 4 ; 90 ; 114 ; 1 ; 112 ; 2 ; 37 ; 2.5 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_meleeKills[client])); 
		case 8: // Grenade Hell
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 1 ; 0.80 ; 6 ; 0.15 ; 97 ; 0.10 ; 4 ; 110 ; 114 ; 1 ; 112 ; 2 ; 37 ; 5.0 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_meleeKills[client])); 
		case 9: // True Bloodrider
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 6 ; 0.10 ; 97 ; 0.05 ; 4 ; 130 ; 114 ; 1 ; 112 ; 2 ; 37 ; 10.0 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_meleeKills[client])); 
	}
	SetAmmo(client, TFWeaponSlot_Primary, 99999999);

	if(Raging[client])
		Raging[client] = false;
	
	if(Nextlive[client])
		Nextlive[client] = false;
}

Grenadelauncherrage(client)
{
	new index;
	new String:snd[PLATFORM_MAX_PATH];
	switch (GetRandomInt(0,4))
	{
		case 0: // Grenade launcher
		{
			if(TF2_GetPlayerClass(client)==TFClass_Scout||TF2_GetPlayerClass(client)==TFClass_Soldier||TF2_GetPlayerClass(client)==TFClass_Pyro||TF2_GetPlayerClass(client)==TFClass_Heavy)
				index = 18;
			else
				index = 19;
			switch(weapondifficulty)
			{
				case 1: // Easy
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 4 ; 10 ; 1 ; 0.01 ; 6 ; 0.40 ; 411 ; 150.0 ; 97 ; 0.60 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 112 ; 2 ; 214 ; %d", Blood_grenadeKills[client]));
				case 2:	// Normal
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 4 ; 30 ; 1 ; 0.05 ; 6 ; 0.35 ; 411 ; 130.0 ; 97 ; 0.50 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 112 ; 2 ; 214 ; %d", Blood_grenadeKills[client]));
				case 3:	// Intermediate
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 4 ; 50 ; 1 ; 0.10 ; 6 ; 0.30 ; 411 ; 110.0 ; 97 ; 0.45 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 112 ; 2 ; 214 ; %d", Blood_grenadeKills[client]));
				case 4: // Difficult
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 4 ; 70 ; 1 ; 0.20 ; 6 ; 0.25 ; 411 ; 90.0 ; 97 ; 0.35 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 112 ; 2 ; 37 ; 1.5 ; 214 ; %d", Blood_grenadeKills[client]));
				case 5: // Very Hard
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 4 ; 90 ; 1 ; 0.30 ; 6 ; 0.20 ; 411 ; 70.0 ; 97 ; 0.30 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 112 ; 2 ; 37 ; 2.0 ; 214 ; %d", Blood_grenadeKills[client]));
				case 6: // Insane
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 4 ; 110 ; 1 ; 0.50 ; 6 ; 0.15 ; 411 ; 50.0 ; 97 ; 0.25 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 112 ; 2 ; 37 ; 2.0 ; 214 ; %d", Blood_grenadeKills[client]));
				case 7: // Godlike
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 4 ; 145 ; 1 ; 0.75 ; 6 ; 0.10 ; 411 ; 30.0 ; 97 ; 0.20 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 112 ; 2 ; 37 ; 3.0 ; 214 ; %d", Blood_grenadeKills[client]));
				case 8: // Grenade Hell
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 4 ; 165 ; 1 ; 0.90 ; 6 ; 0.05 ; 411 ; 15.0 ; 97 ; 0.10 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 112 ; 2 ; 37 ; 4.0 ; 214 ; %d", Blood_grenadeKills[client]));
				case 9: // True Bloodrider
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 4 ; 200 ; 6 ; 0.03 ; 411 ; 5.0 ; 97 ; 0.05 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 112 ; 2 ; 37 ; 10.0 ; 214 ; %d", Blood_grenadeKills[client]));
			}
			if(FF2_RandomSound("sound_bloodrider_rage_grenadelauncher", snd, sizeof(snd), BloodriderBossIdx))
			{
				EmitSoundToAll(snd, client);
				EmitSoundToAll(snd, client);
			}
		}
		case 1: // Loch n Load
		{
			if(TF2_GetPlayerClass(client)==TFClass_Scout||TF2_GetPlayerClass(client)==TFClass_Soldier||TF2_GetPlayerClass(client)==TFClass_Pyro||TF2_GetPlayerClass(client)==TFClass_Heavy)
				index = 228;
			else
				index = 308;
			switch(weapondifficulty)
			{
				case 1: // Easy
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 1 ; 0.01 ; 6 ; 0.40 ; 97 ; 0.50 ; 4 ; 10 ; 114 ; 1 ; 112 ; 2 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 2:	// Normal
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 1 ; 0.05 ; 6 ; 0.35 ; 97 ; 0.45 ; 4 ; 20 ; 114 ; 1 ; 112 ; 2 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 3:	// Intermediate
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 1 ; 0.10 ; 6 ; 0.30 ; 97 ; 0.40 ; 4 ; 45 ; 114 ; 1 ; 112 ; 2 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 4: // Difficult
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 1 ; 0.20 ; 6 ; 0.25 ; 97 ; 0.35 ; 4 ; 60 ; 114 ; 1 ; 112 ; 2 ; 37 ; 1.5 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 5: // Very Hard
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 1 ; 0.35 ; 6 ; 0.20 ; 97 ; 0.25 ; 4 ; 80 ; 114 ; 1 ; 112 ; 2 ; 37 ; 1.5 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 6: // Insane
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 1 ; 0.55 ; 6 ; 0.15 ; 97 ; 0.15 ; 4 ; 100 ; 114 ; 1 ; 112 ; 2 ; 37 ; 2.0 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 7: // Godlike
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 1 ; 0.75 ; 6 ; 0.10 ; 97 ; 0.10 ; 4 ; 200 ; 114 ; 1 ; 112 ; 2 ; 37 ; 3.0 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 8: // Grenade Hell
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 1 ; 0.90 ; 6 ; 0.05 ; 97 ; 0.05 ; 4 ; 500 ; 114 ; 1 ; 112 ; 2 ; 37 ; 5.0 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 9: // True Bloodrider
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 6 ; 0.01 ; 97 ; 0.01 ; 4 ; 1000 ; 114 ; 1 ; 112 ; 2 ; 37 ; 10.0 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
			}
			if(FF2_RandomSound("sound_bloodrider_rage_lochnload", snd, sizeof(snd), BloodriderBossIdx))
			{
				EmitSoundToAll(snd, client);
				EmitSoundToAll(snd, client);
			}
		}
		case 2: // Loose Cannon
		{
			if(TF2_GetPlayerClass(client)==TFClass_Scout||TF2_GetPlayerClass(client)==TFClass_Soldier||TF2_GetPlayerClass(client)==TFClass_Pyro||TF2_GetPlayerClass(client)==TFClass_Heavy)
				index = 414;
			else
				index = 996;
			switch(weapondifficulty)
			{
				case 1: // Easy
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_cannon", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 1 ; 0.7 ; 99 ; 1.3 ; 3 ; 0.25 ; 104 ; 0.10 ; 96 ; 100 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 2:	// Normal
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_cannon", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 1 ; 0.9 ; 99 ; 1.7 ; 3 ; 0.25 ; 104 ; 0.20 ; 96 ; 80 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 3:	// Intermediate
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_cannon", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2 ; 1.3 ; 99 ; 2.0 ; 3 ; 0.25 ; 104 ; 0.30 ; 96 ; 70 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 4: // Difficult
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_cannon", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2 ; 1.6 ; 99 ; 2.3 ; 3 ; 0.25 ; 104 ; 0.40 ; 37 ; 1.5 ; 96 ; 40 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 5: // Very Hard
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_cannon", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2 ; 1.85 ; 99 ; 2.67 ; 3 ; 0.5 ; 104 ; 0.50 ; 37 ; 2.0 ; 96 ; 20 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 6: // Insane
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_cannon", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2 ; 2.1 ; 99 ; 2.88 ; 3 ; 0.5 ; 104 ; 0.6 ; 37 ; 3.0 ; 96 ; 10 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 7: // Godlike
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_cannon", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2 ; 2.4 ; 99 ; 3.2 ; 3 ; 0.75 ; 104 ; 0.7 ; 37 ; 4.5 ; 96 ; 5 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 8: // Grenade Hell
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_cannon", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2 ; 2.8 ; 99 ; 3.7 ; 3 ; 0.75 ; 104 ; 0.80 ; 37 ; 7.0 ; 96 ; 2.5 ;  2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 9: // True Bloodrider
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_cannon", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2 ; 3.6 ; 99 ; 4.0 ; 104 ; 0.90 ; 37 ; 10.0 ; 96 ; 2.0 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
			}
			if(FF2_RandomSound("sound_bloodrider_rage_loosecannon", snd, sizeof(snd), BloodriderBossIdx))
			{
				EmitSoundToAll(snd, client);
				EmitSoundToAll(snd, client);
			}
		}
		case 3: // Festive Grenade Launcher
		{
			if(TF2_GetPlayerClass(client)==TFClass_Scout||TF2_GetPlayerClass(client)==TFClass_Soldier||TF2_GetPlayerClass(client)==TFClass_Pyro||TF2_GetPlayerClass(client)==TFClass_Heavy)
				index = 658;
			else
				index = 1007;
			switch(weapondifficulty)
			{
				case 1: // Easy
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 1 ; 0.10 ; 214 ; %d", Blood_grenadeKills[client]));
				case 2: // Normal
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 1 ; 0.30 ; 214 ; %d", Blood_grenadeKills[client]));
				case 3: // Intermediate
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 1 ; 0.60 ; 214 ; %d", Blood_grenadeKills[client]));
				case 4: // Difficult
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 1 ; 0.75 ; 214 ; %d", Blood_grenadeKills[client]));
				case 5: // Very Hard
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 214 ; %d", Blood_grenadeKills[client]));
				case 6: // Insane
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 2 ; 3 ; 214 ; %d", Blood_grenadeKills[client]));
				case 7: // Godlike
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 2 ; 7 ; 214 ; %d", Blood_grenadeKills[client]));
				case 8: // Grenade Hell
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 2 ; 11 ; 214 ; %d", Blood_grenadeKills[client]));
				case 9: // True Bloodrider
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 2 ; 15 ; 214 ; %d", Blood_grenadeKills[client]));
			}
			if(FF2_RandomSound("sound_bloodrider_rage_festivegrenadelauncher", snd, sizeof(snd), BloodriderBossIdx))
			{
				EmitSoundToAll(snd, client);
				EmitSoundToAll(snd, client);
			}
		}
		case 4: // Iron Bomber
		{
			if(TF2_GetPlayerClass(client)==TFClass_Scout||TF2_GetPlayerClass(client)==TFClass_Soldier||TF2_GetPlayerClass(client)==TFClass_Pyro||TF2_GetPlayerClass(client)==TFClass_Heavy)
				index = 1104;
			else
				index = 1151;
			switch(weapondifficulty)
			{
				case 1: // Easy
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 1 ; 0.1 ; 32 ; 1 ; 149 ; 1 ; 214 ; %d", Blood_grenadeKills[client]));
				case 2: // Normal
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 1 ; 0.25 ; 32 ; 2 ; 37 ; 1.5 ; 149 ; 1.5 ; 214 ; %d", Blood_grenadeKills[client]));
				case 3: // Intermediate
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 1 ; 0.40 ; 32 ; 3 ; 37 ; 1.5 ; 149 ; 2.0 ; 214 ; %d", Blood_grenadeKills[client]));
				case 4: // Difficult
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 1 ; 0.50 ; 32 ; 3 ; 37 ; 2.5 ; 149 ; 2.5 ; 214 ; %d", Blood_grenadeKills[client]));
				case 5: // Very Hard
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 1 ; 0.65 ; 32 ; 5 ; 37 ; 3.5 ; 149 ; 3.5 ; 214 ; %d", Blood_grenadeKills[client]));
				case 6: // Insane
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 1 ; 0.75 ; 32 ; 6 ; 37 ; 4.5 ; 149 ; 4.5 ; 214 ; %d", Blood_grenadeKills[client]));
				case 7: // Godlike
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 1 ; 0.80 ; 32 ; 8 ; 37 ; 6.5 ; 149 ; 6.5 ; 214 ; %d", Blood_grenadeKills[client]));
				case 8: // Grenade Hell
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 1 ; 0.90 ; 32 ; 10 ; 37 ; 8.5 ; 149 ; 7.5 ; 214 ; %d", Blood_grenadeKills[client]));
				case 9: // True Bloodrider
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_grenadelauncher", index, 101, 5, "275 ; 1 ; 128 ; 1 ; 2025 ; 3 ; 2013 ; 2007 ; 2014 ; 4 ; 32 ; 20 ; 37 ; 12.5 ; 149 ; 10 ; 437 ; 1 ; 438 ; 1 ; 31 ; 10 ; 214 ; %d", Blood_grenadeKills[client]));
			}
			if(FF2_RandomSound("sound_bloodrider_rage_ironbomber", snd, sizeof(snd), BloodriderBossIdx))
			{
				EmitSoundToAll(snd, client);
				EmitSoundToAll(snd, client);
			}
		}
	}
}

GrapplinkhookForPlayers()
{
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i) && GetClientTeam(i)!=FF2_GetBossTeam()) 
		{
			SpawnWeapon(i, "tf_weapon_grapplinghook", 1152, 5, 8, hookplayersargs);
		}
	}
}

#if !defined _FF2_Extras_included
stock int SpawnWeapon(int client, char[] name, int index, int level, int quality, char[] attribute, int visible = 1, bool preserve = false)
{
	if(StrEqual(name,"saxxy", false)) // if "saxxy" is specified as the name, replace with appropiate name
	{ 
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Scout: ReplaceString(name, 64, "saxxy", "tf_weapon_bat", false);
			case TFClass_Soldier: ReplaceString(name, 64, "saxxy", "tf_weapon_shovel", false);
			case TFClass_Pyro: ReplaceString(name, 64, "saxxy", "tf_weapon_fireaxe", false);
			case TFClass_DemoMan: ReplaceString(name, 64, "saxxy", "tf_weapon_bottle", false);
			case TFClass_Heavy: ReplaceString(name, 64, "saxxy", "tf_weapon_fists", false);
			case TFClass_Engineer: ReplaceString(name, 64, "saxxy", "tf_weapon_wrench", false);
			case TFClass_Medic: ReplaceString(name, 64, "saxxy", "tf_weapon_bonesaw", false);
			case TFClass_Sniper: ReplaceString(name, 64, "saxxy", "tf_weapon_club", false);
			case TFClass_Spy: ReplaceString(name, 64, "saxxy", "tf_weapon_knife", false);
		}
	}
	
	if(StrEqual(name, "tf_weapon_shotgun", false)) // If using tf_weapon_shotgun for Soldier/Pyro/Heavy/Engineer
	{
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Soldier:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_soldier", false);
			case TFClass_Pyro:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_pyro", false);
			case TFClass_Heavy:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_hwg", false);
			case TFClass_Engineer:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_primary", false);
		}
	}

	Handle weapon = TF2Items_CreateItem((preserve ? PRESERVE_ATTRIBUTES : OVERRIDE_ALL) | FORCE_GENERATION);
	TF2Items_SetClassname(weapon, name);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, quality);
	char attributes[32][32];
	int count = ExplodeString(attribute, ";", attributes, 32, 32);
	if(count%2!=0)
	{
		count--;
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(weapon, count/2);
		int i2 = 0;
		for(int i = 0; i < count; i += 2)
		{
			int attrib = StringToInt(attributes[i]);
			if (attrib == 0)
			{
				LogError("Bad weapon attribute passed: %s ; %s", attributes[i], attributes[i+1]);
				return -1;
			}
			TF2Items_SetAttribute(weapon, i2, attrib, StringToFloat(attributes[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(weapon, 0);
	}

	if (weapon == INVALID_HANDLE)
	{
		PrintToServer("[SpawnWeapon] Error: Invalid weapon spawned. client=%d name=%s idx=%d attr=%s", client, name, index, attribute);
		return -1;
	}

	int entity = TF2Items_GiveNamedItem(client, weapon);
	delete weapon;
	
	if(!visible)
	{
		SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
	}
	
	if (StrContains(name, "tf_wearable")==-1)
	{
		EquipPlayerWeapon(client, entity);
	}
	else
	{
		Wearable_EquipWearable(client, entity);
	}
	
	return entity;
}

Handle S93SF_equipWearable = INVALID_HANDLE;
stock void Wearable_EquipWearable(client, wearable)
{
	if(S93SF_equipWearable==INVALID_HANDLE)
	{
		Handle config=LoadGameConfigFile("equipwearable");
		if(config==INVALID_HANDLE)
		{
			LogError("[FF2] EquipWearable gamedata could not be found; make sure /gamedata/equipwearable.txt exists.");
			return;
		}

		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "EquipWearable");
		CloseHandle(config);
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		if((S93SF_equipWearable=EndPrepSDKCall())==INVALID_HANDLE)
		{
			LogError("[FF2] Couldn't load SDK function (CTFPlayer::EquipWearable). SDK call failed.");
			return;
		}
	}
	SDKCall(S93SF_equipWearable, client, wearable);
}
#endif

stock SetAmmo(client, slot, ammo)
{
	new weapon2 = GetPlayerWeaponSlot(client, slot);
	if (IsValidEntity(weapon2))
	{
		new iOffset = GetEntProp(weapon2, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		new iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		SetEntData(client, iAmmoTable+iOffset, ammo, 4, true);
	}
}

stock void RemoveAttachable(client, char[] itemName)
{
	int entity;
	while((entity=FindEntityByClassname(entity, itemName))!=-1)
	{
		if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")==client)
		{
			TF2_RemoveWearable(client, entity);
		}
	}
}

stock void RefreshDifficulty(int level)
{
	for(int client=1;client<=MaxClients;client++)
	{
		if(!IsValidClient(client))
			continue;
		switch(level)
		{	
			case 1: Bloodrider_DifficultyLevelString[client]=BLOOD_Easy[client];
			case 2: Bloodrider_DifficultyLevelString[client]=BLOOD_Normal[client];
			case 3: Bloodrider_DifficultyLevelString[client]=BLOOD_Intermediate[client];
			case 4: Bloodrider_DifficultyLevelString[client]=BLOOD_Difficult[client];
			case 5: Bloodrider_DifficultyLevelString[client]=BLOOD_Lunatic[client];
			case 6: Bloodrider_DifficultyLevelString[client]=BLOOD_Insane[client];
			case 7: Bloodrider_DifficultyLevelString[client]=BLOOD_Godlike[client];
			case 8: Bloodrider_DifficultyLevelString[client]=BLOOD_GrenadeHell[client];
			case 9: Bloodrider_DifficultyLevelString[client]=BLOOD_TrueBloodrider[client];
			default: Format(Bloodrider_DifficultyLevelString[client], sizeof(Bloodrider_DifficultyLevelString[]), BLOOD_RNGDisplay[client], level);
		}
	}
}

stock ReadCenterText(bossIdx, const String:ability_name[], argInt, String:centerText[PLATFORM_MAX_PATH])
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, centerText, PLATFORM_MAX_PATH);
	ReplaceString(centerText, PLATFORM_MAX_PATH, "\\n", "\n");
}

stock void ClassResponses(int client)
{
	if(IsValidClient(client) && GetClientTeam(client)!=FF2_GetBossTeam())
	{
		char Reaction[PLATFORM_MAX_PATH];
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Scout: // Scout
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, ScoutReact[GetRandomInt(0, sizeof(ScoutReact)-1)]);
				EmitSoundToAll(Reaction, client);
			}
			case TFClass_Soldier: // Soldier
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, SoldierReact[GetRandomInt(0, sizeof(SoldierReact)-1)]);
				EmitSoundToAll(Reaction, client);
			}
			case TFClass_Pyro: // Pyro
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, PyroReact[GetRandomInt(0, sizeof(PyroReact)-1)]);
				EmitSoundToAll(Reaction, client);
			}
			case TFClass_DemoMan: // DemoMan
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, DemoReact[GetRandomInt(0, sizeof(DemoReact)-1)]);
				EmitSoundToAll(Reaction, client);
			}
			case TFClass_Heavy: // Heavy
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, HeavyReact[GetRandomInt(0, sizeof(HeavyReact)-1)]);
				EmitSoundToAll(Reaction, client);
			}
			case TFClass_Engineer: // Engineer
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, EngyReact[GetRandomInt(0, sizeof(EngyReact)-1)]);
				EmitSoundToAll(Reaction, client);
			}	
			case TFClass_Medic: // Medic
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, MedicReact[GetRandomInt(0, sizeof(MedicReact)-1)]);
				EmitSoundToAll(Reaction, client);
			}
			case TFClass_Sniper: // Sniper
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, SniperReact[GetRandomInt(0, sizeof(SniperReact)-1)]);
				EmitSoundToAll(Reaction, client);
			}
			case TFClass_Spy: // Spy
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, SpyReact[GetRandomInt(0, sizeof(SpyReact)-1)]);
				EmitSoundToAll(Reaction, client);
			}
		}
	}
}

stock void DropReanimator(int client) 
{
	int clientTeam = GetClientTeam(client);
	int marker = CreateEntityByName("entity_revive_marker");
	if (marker != -1)
	{
		SetEntPropEnt(marker, Prop_Send, "m_hOwner", client); // client index 
		SetEntProp(marker, Prop_Send, "m_nSolidType", 2); 
		SetEntProp(marker, Prop_Send, "m_usSolidFlags", 8); 
		SetEntProp(marker, Prop_Send, "m_fEffects", 16); 	
		SetEntProp(marker, Prop_Send, "m_iTeamNum", clientTeam); // client team 
		SetEntProp(marker, Prop_Send, "m_CollisionGroup", 1); 
		SetEntProp(marker, Prop_Send, "m_bSimulatedEveryTick", 1); 
		SetEntProp(marker, Prop_Send, "m_nBody", (view_as<int>(TF2_GetPlayerClass(client))) - 1); 
		SetEntProp(marker, Prop_Send, "m_nSequence", 1); 
		SetEntPropFloat(marker, Prop_Send, "m_flPlaybackRate", 1.0);  
		SetEntProp(marker, Prop_Data, "m_iInitialTeamNum", clientTeam);
		SetEntDataEnt2(client, FindSendPropInfo("CTFPlayer", "m_nForcedSkin")+4, marker);
		if(GetClientTeam(client) == 3)
			SetEntityRenderColor(marker, 0, 0, 255); // make the BLU Revive Marker distinguishable from the red one
		DispatchSpawn(marker);
		reviveMarker[client] = EntIndexToEntRef(marker);
		Blood_MoveReviveMarkerAt[client] = GetEngineTime() + 0.01;
		Blood_RemoveReviveMarkerAt[client] = GetEngineTime() + ReviveMarkerDecayTime;
	} 
}

stock void RemoveReanimator(int client)
{
	if (reviveMarker[client] != INVALID_ENTREF && reviveMarker[client] != 0) // second call needed due to slim possibility of it being uninitialized, thus the world
	{
		currentTeam[client] = GetClientTeam(client);
		ChangeClass[client] = false;
		int marker = EntRefToEntIndex(reviveMarker[client]);
		if (IsValidEntity(marker) && marker >= MaxClients)
			AcceptEntityInput(marker, "Kill");
	}
	Blood_RemoveReviveMarkerAt[client] = FAR_FUTURE;
	Blood_MoveReviveMarkerAt[client] = FAR_FUTURE;
	reviveMarker[client] = INVALID_ENTREF;
}

stock void DropReviveMarker(int client)
{
	switch(MaxClientRevives)
	{	
		case -1: // Unlimited revives
		{
			DropReanimator(client);	
		}
						
		case 0: // Revive Markers Disabled
		{
			// Noop
		}
							
		default: // Has a limit of number of times player can be revived
		{
			static int revivecount[MAXPLAYERS+1] = 0;
			if(revivecount[client] >= MaxClientRevives)
			{
				SetHudTextParams(-1.0, 0.67, 5.0, 255, 0, 0, 255);
				ShowHudText(client, -1, BLOOD_NoMoreRevives[client]);
				revivecount[client] = 0;
			}
			else
			{
				DropReanimator(client);
				revivecount[client]++;
			}
		}
	}
}

stock bool IsInstanceOf(int entity, const char[] desiredClassname)
{
	static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, MAX_ENTITY_CLASSNAME_LENGTH);
	return strcmp(classname, desiredClassname) == 0;
}

ForceTeamWin(team)
{
	new entity=FindEntityByClassname(-1, "team_control_point_master");
	if(entity==-1)
	{
		entity=CreateEntityByName("team_control_point_master");
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Enable");
	}
	SetVariantInt(team);
	AcceptEntityInput(entity, "SetWinner");
}

stock float GetTimerDuration(int boss, const char[] ability_name, int arg, bool isEngineTime=true)
{
	if(!isEngineTime)	return FF2_GetAbilityArgumentFloat(boss,this_plugin_name,ability_name,arg,5.0);
	return GetEngineTime() + FF2_GetAbilityArgumentFloat(boss,this_plugin_name,ability_name,arg,5.0);
}

stock bool:IsBoss(client)
{
	if(FF2_GetBossIndex(client)==-1) return false;
	if(GetClientTeam(client)!=FF2_GetBossTeam()) return false;
	return true;
}

stock bool:IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client) || !IsClientConnected(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}