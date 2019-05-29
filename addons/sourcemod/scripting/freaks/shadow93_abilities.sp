/*SHADoW93 Abilities Pack 
 by SHADoW NiNE TR3S
 
 with some code snippets from:
 -MasterOfTheXP
 -Friagram
 -WliU
 -EP
 -Otokiru
 -jfrog
 -Wolvan

*/


#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2items>
#include <adt_array>
#include <tf2_stocks>
#include <ff2_ams>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
//#tryinclude <freak_fortress_2_extras>

#define MANN_SND "ambient/siren.wav"
#define BUILDABLE_SND "ui/message_update.wav"

enum FF2BossType
{
	FF2BossType_NotABoss=-1,
	FF2BossType_IsBoss,
	FF2BossType_IsCompanion,
	FF2BossType_IsMinion
}

enum Operators
{
	Operator_None=0,
	Operator_Add,
	Operator_Subtract,
	Operator_Multiply,
	Operator_Divide,
	Operator_Exponent,
};

enum VoiceMode
{
	VoiceMode_None=-1,
	VoiceMode_Normal,
	VoiceMode_Robot,
	VoiceMode_GiantRobot,
	VoiceMode_BossCatchPhrase,
	VoiceMode_CatchPhrase,
	VoiceMode_RandomBossCatchPhrase,
}

// Ability Names

// Standard E rages
#define TAUNTSLIDE "rage_taunt_slide"
#define REACTION "effect_classreaction"

// E rage or AMS rage
#define VACCINATOR "rage_vaccinator"
#define RSALMON "rage_summon"
#define THRILLER "rage_thriller_taunt"
#define BUILDABLE "rage_buildable"
 
// Charge Ability
#define CSALMON "charge_summon"

// TO-DO: dynamic_summon for dynamic-defaults compatible version.
#define DSALMON "dynamic_summon"
#define INACTIVE 100000000.0

// Tweaks
#define ROBOT "roboticize"
#define INTRO "intromusic"
#define OUTTRO "outtromusic"
#define REANIMATORS "revive_markers"
#define RANDOMMODEL "random_model"
#define RANDOMMODEL_KILL "modelchange_on_kill"

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

// Version Number

#define MAJOR_REVISION "1"
#define MINOR_REVISION "23"
//#define PATCH_REVISION ""

#if !defined PATCH_REVISION
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION
#else
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...PATCH_REVISION
#endif


// Charge Stuff
Handle jumpHUD;
bool bEnableSuperDuperJump[MAXPLAYERS+1];

// Salmon System / VO Tweaks
bool DontSlay[MAXPLAYERS+1];
bool minRestrict[MAXPLAYERS+1];
int minToSpawn[MAXPLAYERS+1];
bool minRestrict2[MAXPLAYERS+1];
int minToSpawn2[MAXPLAYERS+1];
Handle MinionKV[MAXPLAYERS+1]=null;
int SummonerIndex[MAXPLAYERS+1];
VoiceMode VOMode[MAXPLAYERS+1];
MoveType mMoveType[MAXPLAYERS+1];
int minionMaxHP[MAXPLAYERS+1];
bool HookHealth[MAXPLAYERS+1]=false;

// Reanimators
int decaytime;
int reviveMarker[MAXPLAYERS+1];
bool ChangeClass[MAXPLAYERS+1] = { false, ... };
int revivemarkers = -1;
int currentTeam[MAXPLAYERS+1] = {0, ... };
Handle decayTimers[MAXPLAYERS+1] = { null, ... };


// Outtro Track Bool
bool HasOuttro = false;
char VictoryTrack[PLATFORM_MAX_PATH];
char DefeatTrack[PLATFORM_MAX_PATH];
char StalemateTrack[PLATFORM_MAX_PATH];

// AMS-specific
bool Thriller_AMS[MAXPLAYERS+1];
bool Salmon_AMS[MAXPLAYERS+1];
bool Vaccinator_AMS[MAXPLAYERS+1];
bool Buildable_AMS[MAXPLAYERS+1];

// Hitboxes
bool isHitBoxAvailable=false;

public Plugin myinfo = {
	name = "Freak Fortress 2: Koishi's Abilities Pack",
	author = "Koishi (SHADoW NiNE TR3S)",
	description="Koishi's Abilities Pack",
	version=PLUGIN_VERSION,
};

public void OnPluginStart2()
{
	int version[3];
	FF2_GetFF2Version(version);
	if(version[0]==1 && (version[1]<10 || (version[1]==10 && version[2]<3)))
	{
		SetFailState("This subplugin (shadow93_abilities) requires at least FF2 v1.10.3!");
	}
	HookEvent("teamplay_round_start", Event_Countdown, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_PostNoCopy);
	AddNormalSoundHook(SoundHook);
	
	// Notification Sounds
	PrecacheSound(MANN_SND,true);
	PrecacheSound(BUILDABLE_SND,true);
	
	// Class Voice Reaction Lines
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
	
	// Translations file
	LoadTranslations("ff2_shadow93.phrases");
	
	// HUD
	jumpHUD = CreateHudSynchronizer();
	
	// Ugh, y u no precache?
	PrecacheSound("mvm/giant_common/giant_common_step_01.wav", true);
	PrecacheSound("mvm/giant_common/giant_common_step_02.wav", true);
	PrecacheSound("mvm/giant_common/giant_common_step_03.wav", true);
	PrecacheSound("mvm/giant_common/giant_common_step_04.wav", true);
	PrecacheSound("mvm/giant_common/giant_common_step_05.wav", true);
	PrecacheSound("mvm/giant_common/giant_common_step_06.wav", true);
	PrecacheSound("mvm/giant_common/giant_common_step_07.wav", true);
	PrecacheSound("mvm/giant_common/giant_common_step_08.wav", true);
	
	isHitBoxAvailable=((FindSendPropOffs("CBasePlayer", "m_vecSpecifiedSurroundingMins") != -1) && FindSendPropOffs("CBasePlayer", "m_vecSpecifiedSurroundingMaxs") != -1);
	
	if(FF2_GetRoundState()==1)
	{
		CreateTimer(0.3, CheckAbility, _,TIMER_FLAG_NO_MAPCHANGE);
	}
}

public OnClientDisconnect(client) 
{
	if(revivemarkers != -1)
	{
		if(IsValidMarker(reviveMarker[client])) 
			RemoveReanimator(client);
		currentTeam[client] = 0;
		ChangeClass[client] = false;
	}
}

/*
********************** EVENT FORWARDS ***********************
* All event forwards used can be found in this section here *
*************************************************************
*/

public Action:Event_PlayerInventory(Handle:event, const String:name[], bool:dontbroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(revivemarkers != -1)
	{
		if(IsValidMarker(reviveMarker[client])) 
			RemoveReanimator(client);
	}
	if(HookHealth[client])
	{
		SDKHook(client, SDKHook_GetMaxHealth, GetMaxHealth_Minion);
	}
	
	return Plugin_Continue;
}

public Action:Event_Countdown(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (FF2_IsFF2Enabled())
	{
		HasOuttro=false;
		revivemarkers=-1;
		for(new client=1;client<MaxClients;client++)
		{
			bEnableSuperDuperJump[client]=false;
			SummonerIndex[client]=-1;
		}
		CreateTimer(0.3, CheckAbility, _,TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			DontSlay[client]=Salmon_AMS[client]=false;
			minRestrict[client]=minRestrict2[client]=false;
			minToSpawn[client]=minToSpawn2[client]=minionMaxHP[client]=0;
			Vaccinator_AMS[client]=false;
			Buildable_AMS[client]=false;
			Thriller_AMS[client]=false;
		
			ResetSalmonSettings(client);
		}
	}
	if(HasOuttro)
	{
		if (GetEventInt(event, "winning_team") == FF2_GetBossTeam())
			EmitSoundToAll(VictoryTrack);
		else if (GetEventInt(event, "winning_team") == ((FF2_GetBossTeam()==_:TFTeam_Blue) ? (_:TFTeam_Red) : (_:TFTeam_Blue)))
			EmitSoundToAll(DefeatTrack);
		else if (GetEventInt(event, "winning_team") == 0)
			EmitSoundToAll(StalemateTrack);
	}
}

public Action:Event_BroadcastAudio(Handle:event, const String:name[], bool:dontBroadcast)
{
	new String:strAudio[PLATFORM_MAX_PATH];
	GetEventString(event, "sound", strAudio, sizeof(strAudio));
	if(strncmp(strAudio, "Game.Your", 9) == 0 || strcmp(strAudio, "Game.Stalemate") == 0)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker=GetClientOfUserId(GetEventInt(event, "attacker"));
	new client=GetClientOfUserId(GetEventInt(event, "userid"));
	
	new boss=FF2_GetBossIndex(attacker); // Boss is an attacker
	if(boss!=-1)
	{
	
		if(FF2_HasAbility(boss, this_plugin_name, RANDOMMODEL_KILL))
		{
			SetRandomModel(boss, client, RANDOMMODEL_KILL);
		}
	}
	
	if((GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
		return Plugin_Continue; // Prevent a bug with revive markers & dead ringer spies
	
	if(!(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
	{
		DontSlay[client]=false;
		
		if(HookHealth[client])
		{
			SDKUnhook(client, SDKHook_GetMaxHealth, GetMaxHealth_Minion);
		}
		
		switch(revivemarkers)
		{
			case 0: // Only Non-Boss Team
			{
				if(GetFF2BossType(client)==FF2BossType_NotABoss)
					DropReanimator(client);
			}
			case 1: // Minions can revive each other	
			{
				if(GetFF2BossType(client)==FF2BossType_IsMinion || GetFF2BossType(client)==FF2BossType_NotABoss)
					DropReanimator(client);
			}
			case 2: // Only Minions can revive each other	
			{
				if(GetFF2BossType(client)==FF2BossType_IsMinion)
					DropReanimator(client);
			}
		}
		
		if(GetFF2BossType(client)==FF2BossType_IsMinion && !revivemarkers)
		{
			ResetSalmonSettings(client);
			ChangeClientTeam(client, (FF2_GetBossTeam()==_:TFTeam_Blue) ? (_:TFTeam_Red) : (_:TFTeam_Blue));
		}
	}
	
	boss=FF2_GetBossIndex(client);	// Boss is the victim	
	if(boss != -1 && (FF2_HasAbility(boss, this_plugin_name, RSALMON) || FF2_HasAbility(boss, this_plugin_name, CSALMON)) && !(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
	{
		for(new clone=1; clone<=MaxClients; clone++)
		{
			if(SummonerIndex[clone]==boss && IsValidClient(clone, true) && GetFF2BossType(clone)==FF2BossType_IsMinion && !DontSlay[clone])
			{
				ResetSalmonSettings(clone);
				ChangeClientTeam(clone, (FF2_GetBossTeam()==_:TFTeam_Blue) ? (_:TFTeam_Red) : (_:TFTeam_Blue));
			}
		}
	}
	return Plugin_Continue;
}

stock void ResetSalmonSettings(int client)
{
	MinionKV[client]=null;
	VOMode[client]=VoiceMode_Normal;
	SummonerIndex[client]=-1;
	DontSlay[client]=false;
	if(HookHealth[client])
	{
		SDKUnhook(client, SDKHook_GetMaxHealth, GetMaxHealth_Minion);
		HookHealth[client]=false;
	}	
	HookHealth[client]=false;
	if(GetEntityGravity(client)!=1.0)
	{
		SetEntityGravity(client, 1.0);
	}
			
	if(mMoveType[client]!=MOVETYPE_WALK)
	{
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
			
	if(GetEntPropFloat(client, Prop_Send, "m_flModelScale")!=1.0)
	{
		float curpos[3];
		GetEntPropVector(client, Prop_Data, "m_vecOrigin", curpos);
		if(IsSpotSafe(client, curpos, 1.0))
		{
			SetEntPropFloat(client, Prop_Send, "m_flModelScale", 1.0);
			if(isHitBoxAvailable)
			{
				UpdatePlayerHitbox(client, 1.0);
			}
		}
		else
			LogError("[SHADoW93 Minions] %N was not resized to avoid getting stuck!", client);
	}
}

public Action:Event_ChangeClass(Handle:event, const String:name[], bool:dontbroadcast) 
{
	if(revivemarkers!= -1)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		ChangeClass[client] = true;
	}
	return Plugin_Continue;
}

/*
************************* ABILITIES *************************
* All boss abilities used can be found in this section here *
*************************************************************
*/

public Action:TauntSliding(Handle:timer, any:userid)
{
	new client=GetClientOfUserId(FF2_GetBossUserId(userid));
	if (!GetEntProp(client, Prop_Send, "m_bIsReadyToHighFive") && !IsValidEntity(GetEntPropEnt(client, Prop_Send, "m_hHighFivePartner")))
	{
		TF2_RemoveCondition(client,TFCond_Taunting);
		new Float:up[3];
		up[2]=220.0;
		TeleportEntity(client,NULL_VECTOR, NULL_VECTOR,up);
	}
	else if(TF2_IsPlayerInCondition(client, TFCond_Taunting))
	{
		TF2_RemoveCondition(client,TFCond_Taunting);
	}
	return Plugin_Continue;
}	

public Action CheckAbility(Handle timer) // Check for abilities
{
	for(int client=1;client<=MaxClients;client++)
	{
		if(!IsValidClient(client))
			continue;
		if(HookHealth[client])
		{
			SDKUnhook(client, SDKHook_GetMaxHealth, GetMaxHealth_Minion);
			HookHealth[client]=false;
		}
		MinionKV[client]=null;
		VOMode[client]=VoiceMode_Normal;
		minionMaxHP[client]=0;
		Salmon_AMS[client]=false;
		minRestrict[client]=minRestrict2[client]=false;
		minToSpawn[client]=minToSpawn2[client]=0;
		HookHealth[client]=false;
		Vaccinator_AMS[client]=false;
		Buildable_AMS[client]=false;
		Thriller_AMS[client]=false;
		
		int boss=FF2_GetBossIndex(client);
		if(boss>=0)
		{	
			if (FF2_HasAbility(boss, this_plugin_name, ROBOT))
			{	
				new botmode=FF2_GetAbilityArgument(boss,this_plugin_name,ROBOT, 1);
				if(botmode)
					VOMode[client]=VoiceMode_GiantRobot;
				else
					VOMode[client]=VoiceMode_Robot;
			}
			if(FF2_HasAbility(boss, this_plugin_name, REANIMATORS))
			{
				decaytime=FF2_GetAbilityArgument(boss,this_plugin_name,REANIMATORS, 1); // Reanimator decay time
				revivemarkers = FF2_GetAbilityArgument(boss,this_plugin_name,REANIMATORS, 2); // Can Minions Revive Each Other?
				HookEvent("player_changeclass", Event_ChangeClass);
				HookEvent("post_inventory_application", Event_PlayerInventory, EventHookMode_Pre);
			}
			if(FF2_HasAbility(boss, this_plugin_name, INTRO))
			{
				new String:INTROM[PLATFORM_MAX_PATH];
				FF2_GetAbilityArgumentString(boss, this_plugin_name, INTRO, 1, INTROM, sizeof(INTROM));
				if(INTROM[0] != '\0')
				{
					PrecacheSound(INTROM, true);
					EmitSoundToAll(INTROM);
				}
				else
				{
					if(FF2_RandomSound("sound_intromusic", INTROM, sizeof(INTROM), boss))
					{
						EmitSoundToAll(INTROM);
					}		
				}
			}
			if(FF2_HasAbility(boss, this_plugin_name, OUTTRO))
			{
				int type = FF2_GetAbilityArgument(boss,this_plugin_name,OUTTRO, 1);
				if(type)
				{
					char trackList[PLATFORM_MAX_PATH];
					FF2_GetAbilityArgumentString(boss,this_plugin_name,OUTTRO,2,VictoryTrack,sizeof(VictoryTrack));
					FF2_GetAbilityArgumentString(boss,this_plugin_name,OUTTRO,3,DefeatTrack,sizeof(DefeatTrack));
					FF2_GetAbilityArgumentString(boss,this_plugin_name,OUTTRO,4,StalemateTrack,sizeof(StalemateTrack));
					if(VictoryTrack[0] != '\0')
					{
						PrecacheSound(VictoryTrack, true);
					}
					else
					{
						if(FF2_RandomSound("sound_outtromusic_win", trackList, sizeof(trackList), boss))
						{
							strcopy(VictoryTrack, sizeof(VictoryTrack), trackList);
						}	
					}
				
					if(DefeatTrack[0] != '\0')
					{
						PrecacheSound(DefeatTrack, true);
					}
					else
					{
						if(FF2_RandomSound("sound_outtromusic_lose", trackList, sizeof(trackList), boss))
						{
							strcopy(DefeatTrack, sizeof(DefeatTrack), trackList);
						}	
						else
						{
							strcopy(DefeatTrack, sizeof(DefeatTrack), VictoryTrack);
							PrecacheSound(DefeatTrack, true);
						}
					}
	
					if(StalemateTrack[0] != '\0')
					{
						PrecacheSound(StalemateTrack, true);
					}	
					else
					{
						if(FF2_RandomSound("sound_outtromusic_lose", trackList, sizeof(trackList), boss))
						{
							strcopy(StalemateTrack, sizeof(StalemateTrack), trackList);
						}
						else
						{
							strcopy(StalemateTrack, sizeof(StalemateTrack), VictoryTrack);
							PrecacheSound(StalemateTrack, true);
						}
					}
					HasOuttro=true;
				}
				HookEvent("teamplay_broadcast_audio", Event_BroadcastAudio, EventHookMode_Pre);
			}
			if(FF2_HasAbility(boss, this_plugin_name, RANDOMMODEL))
			{
				CreateTimer(0.5, Timer_RandomModel, client, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

public Action Timer_RandomModel(Handle timer, any client)
{
	if(!IsValidClient(client))
		return Plugin_Stop;

	new boss=FF2_GetBossIndex(client);
	SetRandomModel(boss, client, RANDOMMODEL);
	return Plugin_Continue;
}

public void SetRandomModel(int boss, int client, const char[] ability_name)
{
	char randomModel[PLATFORM_MAX_PATH];
	int maxmodels = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 1, 1);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, GetRandomInt(2, maxmodels+1), randomModel, sizeof(randomModel));
	SetPlayerModel(client, randomModel);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int client=1;client<=MaxClients;client++)
	{
		if(!IsValidClient(client))
			continue;
			
		int boss=FF2_GetBossIndex(client);
		if(boss>=0)
		{
			// Initialize if using AMS for these abilities
			if(FF2_HasAbility(boss, this_plugin_name, RSALMON))
			{
				minRestrict2[client]=view_as<bool>(FF2_GetAbilityArgument(boss,this_plugin_name,RSALMON, 24));
				minToSpawn2[client]=FF2_GetAbilityArgument(boss,this_plugin_name,RSALMON, 25);
				Salmon_AMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, RSALMON);
				if(Salmon_AMS[client])
				{
					AMS_InitSubability(boss, client, this_plugin_name, RSALMON, "SMN");
				}
			}
			if(FF2_HasAbility(boss, this_plugin_name, VACCINATOR))
			{
				Vaccinator_AMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, VACCINATOR);
				if(Vaccinator_AMS[client])
				{
					AMS_InitSubability(boss, client, this_plugin_name, VACCINATOR, "VAC");
				}
			}	
			if(FF2_HasAbility(boss, this_plugin_name, BUILDABLE))
			{
				Buildable_AMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, BUILDABLE);
				if(Buildable_AMS[client])
				{
					AMS_InitSubability(boss, client, this_plugin_name, BUILDABLE, "BLD");
				}
			}
			if(FF2_HasAbility(boss, this_plugin_name, THRILLER))
			{
				Thriller_AMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, THRILLER);
				if(Thriller_AMS[client])
				{
					AMS_InitSubability(boss, client, this_plugin_name, THRILLER, "MJT");
				}
			}
		
		}
		
	}
}

public Action:FF2_OnAbility2(boss,const String:plugin_name[],const String:ability_name[],action)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue;
		
	new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	new slot=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 0);
	
	// Non-AMS supported abilities
	if (!strcmp(ability_name,TAUNTSLIDE)) 	// Taunt Sliding!!!!!
	{
		FakeClientCommand(client,"taunt");
		CreateTimer(0.1, TauntSliding);
	}
	else if (!strcmp(ability_name,REACTION))
	{
		for(new target=1;target<=MaxClients;target++)
		{
			ClassResponses(target);
		}
	}
	else if (!strcmp(ability_name,CSALMON)) // TO-DO: Make compatible with Dynamic Defaults
	{
		Charge_Salmon(ability_name,boss,slot,action, client);			// Upgraded version of Otokiru's Charge_Salmon
	}
	
	// AMS supported abilities
	else if(!strcmp(ability_name, VACCINATOR))  // Vaccinator resistances
	{
		if(Vaccinator_AMS[client])
		{
			if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability"))
			{
				Vaccinator_AMS[client]=false;
			}
			else
			{
				return Plugin_Continue;
			}
		}
		VAC_Invoke(client);
	}
	else if (!strcmp(ability_name,RSALMON))
	{
		if(minRestrict[client] && GetMinionCount()>minToSpawn[client])
		{
			PrintHintText(client,"ALIVE MINIONS: %i > MAXIMUM ALIVE MINIONS: %i!", GetMinionCount(), minToSpawn[client]);
			return Plugin_Continue;
		}
		if(Salmon_AMS[client])
		{
			if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability"))
			{
				Salmon_AMS[client]=false;
			}
			else
			{
				return Plugin_Continue;
			}
		}
		SMN_Invoke(client);
	}	
	else if (!strcmp(ability_name,THRILLER))
	{
		if(Thriller_AMS[client])
		{
			if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability"))
			{
				Thriller_AMS[client]=false;
			}
			else
			{
				return Plugin_Continue;
			}
		}
		MJT_Invoke(client);
	}
	else if (!strcmp(ability_name,BUILDABLE))
	{
		if(Buildable_AMS[client])
		{
			if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability"))
			{
				Buildable_AMS[client]=false;
			}
			else
			{
				return Plugin_Continue;
			}
		}
		BLD_Invoke(client);
	}
	return Plugin_Continue;
}

public bool MJT_CanInvoke(int client)
{
	return true;
}

public void MJT_Invoke(int client)
{
	int boss=FF2_GetBossIndex(client);
	float pos[3], pos2[3], dist;
	int maxdances=FF2_GetAbilityArgument(boss,this_plugin_name,THRILLER, 1, 1);
	int mode=FF2_GetAbilityArgument(boss,this_plugin_name,THRILLER, 2);
	float maxdist=FF2_GetAbilityArgumentFloat(boss,this_plugin_name,THRILLER, 3, FF2_GetRageDist(boss, this_plugin_name, THRILLER));

	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	for(int target=1; target<=MaxClients; target++)
	{
		if(IsValidClient(target, true) && GetClientTeam(target)!= FF2_GetBossTeam())
		{
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
			dist=GetVectorDistance(pos,pos2);
			if (dist<maxdist && GetClientTeam(target)!=FF2_GetBossTeam())
			{
				if(!(GetEntityFlags(target) & FL_ONGROUND)) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_UberBulletResist) && !mode) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_BulletImmune) && !mode) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_UberBlastResist) && !mode) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_BlastImmune) && !mode) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_UberFireResist) && !mode) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_FireImmune) && !mode) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_Ubercharged)  && !mode) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_UberchargedHidden) && !mode) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_Stealthed)) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_StealthedUserBuffFade)) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_Cloaked)) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_DeadRingered)) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_UberchargedCanteen)) continue;			
				
				
				if(TF2_IsPlayerInCondition(target, TFCond_Taunting))
				{
					TF2_RemoveCondition(target,TFCond_Taunting);
				}
				if(TF2_IsPlayerInCondition(target, TFCond_HalloweenThriller))
				{
					TF2_RemoveCondition(target, TFCond_HalloweenThriller);
				}
				
				SetVariantInt(0);
				AcceptEntityInput(target, "SetForcedTauntCam");
				TF2_AddCondition(target, TFCond_HalloweenThriller, 3.0);
				FakeClientCommand(target, "taunt");
			}
		}
	}
	
	if(maxdances>0)
	{
		CreateTimer(3.0, ThrillerTaunt, boss, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action ThrillerTaunt(Handle timer, any boss)
{
	float pos[3], pos2[3], dist;
	static int dances=0;
	static int targets=0;
	int client=GetClientOfUserId(FF2_GetBossUserId(boss));
	int maxdances=FF2_GetAbilityArgument(boss,this_plugin_name,THRILLER, 1, 1);
	int mode=FF2_GetAbilityArgument(boss,this_plugin_name,THRILLER, 2);
	float maxdist=FF2_GetAbilityArgumentFloat(boss,this_plugin_name,THRILLER, 3, FF2_GetRageDist(boss, this_plugin_name, THRILLER));
	
	if(dances>=maxdances || !IsValidClient(client, true) || FF2_GetRoundState()!=1)
	{
		targets=0;
		dances=0;
		return Plugin_Stop;
	}
	
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	for(int target=1; target<=MaxClients; target++)
	{
		if(IsValidClient(target, true) && GetClientTeam(target)!= FF2_GetBossTeam())
		{
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
			dist=GetVectorDistance(pos,pos2);
			if (dist<maxdist && GetClientTeam(target)!=FF2_GetBossTeam())
			{
				if(!(GetEntityFlags(target) & FL_ONGROUND)) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_UberBulletResist) && !mode) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_BulletImmune) && !mode) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_UberBlastResist) && !mode) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_BlastImmune) && !mode) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_UberFireResist) && !mode) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_FireImmune) && !mode) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_Ubercharged)  && !mode) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_UberchargedHidden) && !mode) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_Stealthed)) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_StealthedUserBuffFade)) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_Cloaked)) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_DeadRingered)) continue;
				if(TF2_IsPlayerInCondition(target, TFCond_UberchargedCanteen)) continue;			
				
				
				if(TF2_IsPlayerInCondition(target, TFCond_Taunting))
				{
					TF2_RemoveCondition(target,TFCond_Taunting);
				}
				if(TF2_IsPlayerInCondition(target, TFCond_HalloweenThriller))
				{
					TF2_RemoveCondition(target, TFCond_HalloweenThriller);
				}
				
				SetVariantInt(0);
				AcceptEntityInput(target, "SetForcedTauntCam");
				TF2_AddCondition(target, TFCond_HalloweenThriller, 3.0);
				FakeClientCommand(target, "taunt");
				targets++;
			}
		}
	}
	
	if(targets)
	{
		dances++;
	}
	return Plugin_Continue;
}

public bool BLD_CanInvoke(int client)
{
	return true;
}

public void BLD_Invoke(int client)
{
	int entity;
	int boss=FF2_GetBossIndex(client);
	int buildable=FF2_GetAbilityArgument(boss,this_plugin_name,BUILDABLE, 1); //buildable boss
	if(FF2_GetAbilityArgument(boss,this_plugin_name,BUILDABLE, 2))
	{
		EmitSoundToAll(BUILDABLE_SND);
	}
	switch(buildable)
	{
		case 25, 26, 28, 737:
		{
			int metal=FF2_GetAbilityArgument(boss,this_plugin_name,BUILDABLE, 4);	// Extra Metal?
			int wrangler=FF2_GetAbilityArgument(boss,this_plugin_name,BUILDABLE, 5);	// Wrangler?
			SpawnWeapon(client, "tf_weapon_pda_engineer_build", 25, 101, 5, "292 ; 3 ; 293 ; 59 ; 391 ; 2 ; 495 ; 60", false, true); // Build PDA
			SpawnWeapon(client, "tf_weapon_pda_engineer_destroy", 26, 101, 5, "391 ; 2", false, true); // Destroy PDA
			entity = SpawnWeapon(client, "tf_weapon_builder", 28, 101, 5, "391 ; 2", false, true); // Builder
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
			if(FF2_GetAbilityArgument(boss,this_plugin_name,BUILDABLE, 3))
				PrintHintText(client, "%t", "build_notification");
			if(metal)
				SetEntData(client, FindDataMapOffs(client, "m_iAmmo") + (3 * 4), metal, 4);
			if(wrangler)
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
				SpawnWeapon(client, "tf_weapon_laser_pointer", 1086, 101, 5, "292 ; 86", false, true); // Wrangler
			}
		}
		case 735, 736, 810, 831, 933, 1080, 1102:
		{
			switch(buildable)
			{
				case 735, 736: // Sapper
					entity = SpawnWeapon(client, "tf_weapon_builder", 735, 101, 5, "391 ; 2", false, true);
				case 810, 831: // Red Tape Recorder
						entity = SpawnWeapon(client, "tf_weapon_sapper", 810, 101, 5, "426 ; 0 ; 433 ; 0.5 ; 391 ; 2", false, true);
				case 933: // Ap-sap
					entity = SpawnWeapon(client, "tf_weapon_sapper", 933, 101, 5, "451 ; 1 ; 452 ; 3 ; 391 ; 2", false, true);
				case 1080: // Festive Sapper
					entity = SpawnWeapon(client, "tf_weapon_sapper", 1080, 101, 5, "391 ; 2", false, true);
				case 1102: // Snack Attack
					entity = SpawnWeapon(client, "tf_weapon_sapper", 1102, 101, 5, "391 ; 2", false, true);
			}
			SetEntProp(entity, Prop_Send, "m_iObjectType", 3);
			SetEntProp(entity, Prop_Data, "m_iSubType", 3);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
			if(FF2_GetAbilityArgument(boss,this_plugin_name,BUILDABLE, 3))
				PrintHintText(client, "%t", "sap_notification");
		}
	}
}

public bool VAC_CanInvoke(int client)
{
	if(TF2_IsPlayerInCondition(client, TFCond_UberBulletResist)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_BulletImmune)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_UberBlastResist)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_BlastImmune)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_UberFireResist)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_FireImmune)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_Ubercharged)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_Stealthed)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_StealthedUserBuffFade)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_Cloaked)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_DeadRingered)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_UberchargedCanteen)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_UberchargedOnTakeDamage)) return false;
	return true;
}

public void VAC_Invoke(int client)
{
	int boss=FF2_GetBossIndex(client);
	int vacmode=FF2_GetAbilityArgument(boss,this_plugin_name,VACCINATOR, 1); // Resistance type
	if(vacmode==-1) // Random resistance
		vacmode=GetRandomInt(0,6);
	if(!vacmode||vacmode==1||vacmode==4||vacmode==5) // Bullet Resistance
	{
		TF2_AddCondition(client, TFCond_UberBulletResist, FF2_GetAbilityArgumentFloat(boss,this_plugin_name,VACCINATOR,2,5.0)); // Bullet Resistance
		TF2_AddCondition(client, TFCond_BulletImmune, FF2_GetAbilityArgumentFloat(boss,this_plugin_name,VACCINATOR,2,5.0)); // Shield portion
	}
	if(!vacmode||vacmode==2||vacmode==4||vacmode==6) // Blast Resistance
	{
		TF2_AddCondition(client, TFCond_UberBlastResist, FF2_GetAbilityArgumentFloat(boss,this_plugin_name,VACCINATOR,2,5.0)); //Blast Resistance
		TF2_AddCondition(client, TFCond_BlastImmune, FF2_GetAbilityArgumentFloat(boss,this_plugin_name,VACCINATOR,2,5.0)); //Shield Portion
	}
	if(!vacmode||vacmode==3||vacmode==5||vacmode==6) // Fire Resistance
	{
		TF2_AddCondition(client, TFCond_UberFireResist, FF2_GetAbilityArgumentFloat(boss,this_plugin_name,VACCINATOR,2,5.0)); //Fire Resistance
		TF2_AddCondition(client, TFCond_FireImmune, FF2_GetAbilityArgumentFloat(boss,this_plugin_name,VACCINATOR,2,5.0)); //Shield Portion
	}	
}

public bool SMN_CanInvoke(int client)
{
	if(minRestrict[client] && GetMinionCount()>minToSpawn[client]) return false;
	return true;
}

public void SMN_Invoke(int client)
{
	int boss=FF2_GetBossIndex(client);
	if(minRestrict2[client] && GetMinionCount()>minToSpawn2[client])
	{
		PrintHintText(client, "Alive minion quota exceeded (%i / %i)!", GetMinionCount(), minToSpawn2[client]);
		return;
	}
	
	PrepareSalmon(boss, client, RSALMON, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36);
}

public void PrepareSalmon(int boss, int client, const char[] ability_name, int arg1, int arg2, int arg3, int arg4, int arg5, int arg6, int arg7, int arg8, int arg9, int arg10, int arg11, int arg12, int arg13, int arg14, int arg15, int arg16, int arg17, int arg18, int arg19, int arg20, int arg21, int arg22, int arg23, int arg24, int arg25, int arg26, int arg27, int arg28, int arg29, int arg30, int arg31, int arg32, int arg33)
{
	char condition[768], classname[64], attributes[64], model[PLATFORM_MAX_PATH], summoner[512], summoned[512], bHealth[768], moveType[10], prgba[32], wrgba[32], worldmodelpath[PLATFORM_MAX_PATH];
	bool alert=view_as<bool>(FF2_GetAbilityArgument(boss,this_plugin_name,ability_name, arg1)); 						// Sound?
	int rate=FF2_GetAbilityArgument(boss,this_plugin_name,ability_name, arg2); 											// Minions Spawned?
	float uber=FF2_GetAbilityArgumentFloat(boss,this_plugin_name,ability_name, arg3);									// Uber Protection?
	bool notification=view_as<bool>(FF2_GetAbilityArgument(boss,this_plugin_name,ability_name, arg4));					// Notification Text?
	int modelmode=FF2_GetAbilityArgument(boss,this_plugin_name,ability_name, arg5);										// Model Mode?
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, arg6, model, sizeof(model));						// Custom Model Path?
	TFClassType ctype=view_as<TFClassType>(FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, arg7));			// Class override?
	float ratio=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, arg8, 0.0);							// Ratio
	bool remwearables=view_as<bool>(FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, arg9));				// Remove Wearables?
	int wepmode=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, arg10);									// Weapon Mode
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, arg11, classname, sizeof(classname));			// Weapon classname
	int itemindex=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, arg12);									// Weapon Index
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, arg13, attributes, sizeof(attributes));			// Weapon attributes
	int accs=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, arg14);										// Accessories?
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, arg15, bHealth, sizeof(bHealth));				// Health
	bool telemode=view_as<bool>(FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, arg16));					// Teleport to summoner's location?
	int gammo=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, arg17);										// Ammo
	int gclip=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, arg18);										// Clip
	int vline=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, arg19);										// Voice Line Mode
	int mpickups=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, arg20);									// Pickups?
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, arg21, condition, sizeof(condition));			// Spawn conditions
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, arg22, summoner, sizeof(summoner));				// Text to show to summoner
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, arg23, summoned, sizeof(summoned));				// Text to show to summoned
	bool noslayminions=view_as<bool>(FF2_GetAbilityArgument(boss,this_plugin_name,ability_name, arg24));				// Slay minions if owner dies?
	float scale=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, arg25);								// Minion scale
	float gravity=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, arg26);								// Gravity	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, arg27, moveType, sizeof(moveType));				// Movetype
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, arg28, prgba, sizeof(prgba));					// Player RBG + Alpha
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, arg29, wrgba, sizeof(wrgba));					// Weapon RGB + Alpha
	bool wvisbility=view_as<bool>(FF2_GetAbilityArgument(boss,this_plugin_name,ability_name, arg30));					// Visible weapon (clientside)
	bool disableOverHeal=view_as<bool>(FF2_GetAbilityArgument(boss,this_plugin_name,ability_name, arg31));				// Disable hp being overheal?
	float wepScale=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, arg32);							// Weapon Scale
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, arg33, worldmodelpath, sizeof(worldmodelpath));	// Weapon worldmodel
	Salmon(boss, client, alert, rate, ratio, ctype, bHealth, mpickups, modelmode, model, wepmode, remwearables, classname, itemindex, attributes, gammo, gclip, accs, condition, uber, vline, notification, summoned, summoner, telemode, noslayminions, scale, gravity, moveType, prgba, wrgba, wvisbility, disableOverHeal, wepScale, worldmodelpath);
}

void Charge_Salmon(const char[] ability_name, int index, int slot, int action, int client)
{
	char status[256], status2[256], status3[256], status4[256];
	float charge=FF2_GetBossCharge(index,slot);
	float bCharge = FF2_GetBossCharge(index,0);
	float rCost = FF2_GetAbilityArgumentFloat(index, this_plugin_name, ability_name, 6);
	minRestrict[client]=view_as<bool>(FF2_GetAbilityArgument(index,this_plugin_name,ability_name, 27));
	minToSpawn[client]=FF2_GetAbilityArgument(index,this_plugin_name,ability_name, 28);
	
	FF2_GetAbilityArgumentString(index, this_plugin_name, ability_name, 37, status, sizeof(status));
	FF2_GetAbilityArgumentString(index, this_plugin_name, ability_name, 38, status2, sizeof(status2));	
	FF2_GetAbilityArgumentString(index, this_plugin_name, ability_name, 39, status3, sizeof(status3));
	FF2_GetAbilityArgumentString(index, this_plugin_name, ability_name, 40, status4, sizeof(status4));
	
	if(!status[0])
	{
		Format(status, sizeof(status), "%t", "summon_status");
	}
	if(!status2[0])
	{
		Format(status2, sizeof(status2), "%t", "summon_status_2");
	}
	if(!status3[0])
	{
		Format(status3, sizeof(status3), "%t", "super_duper_jump");
	}
	if(!status4[0])
	{
		Format(status3, sizeof(status4), "%t", "summon_ready");
	}
	
	if(minRestrict[client] && GetMinionCount()>minToSpawn[client])
	{
		return;
	}
	
	if(rCost && !bEnableSuperDuperJump[client])
	{
		if(bCharge<rCost)
		{
			return;
		}
	}
	switch (action)
	{
		case 1:
		{
			SetHudTextParams(-1.0, slot==1 ? 0.88 : 0.93, 0.15, 255, 255, 255, 255);
			ShowSyncHudText(client, jumpHUD, status2, -RoundFloat(charge));
		}	
		case 2:
		{
			SetHudTextParams(-1.0, slot==1 ? 0.88 : 0.93, 0.15, 255, bEnableSuperDuperJump[client] && slot == 1 ? 64 : 255, bEnableSuperDuperJump[client] && slot == 1 ? 64 : 255, 255);
			if (bEnableSuperDuperJump[client] && slot == 1)
			{
				ShowSyncHudText(client, jumpHUD, status3);
			}	
			else
			{	
				ShowSyncHudText(client, jumpHUD, status, RoundFloat(charge));
			}
		}
		case 3:
		{
			if (bEnableSuperDuperJump[client] && slot == 1)
			{
				float vel[3];
				float rot[3];
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
				GetClientEyeAngles(client, rot);
				vel[2]=750.0+500.0*charge/70+2000;
				vel[0]+=Cosine(DegToRad(rot[0]))*Cosine(DegToRad(rot[1]))*500;
				vel[1]+=Cosine(DegToRad(rot[0]))*Sine(DegToRad(rot[1]))*500;
				bEnableSuperDuperJump[client]=false;
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
			}
			else
			{
				if(charge<100)
				{
					CreateTimer(0.1, ResetCharge, index*10000+slot);
					return;					
				}
				if(rCost)
				{
					FF2_SetBossCharge(index,0,bCharge-rCost);
				}
				
				PrepareSalmon(index, client, ability_name, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38);
				float position[3];
				char sound[PLATFORM_MAX_PATH];
				if(FF2_RandomSound("sound_ability", sound, sizeof(sound), index, slot))
				{
					EmitSoundToAll(sound, client, _, _, _, _, _, index, position);
					EmitSoundToAll(sound, client, _, _, _, _, _, index, position);
	
					for(int target=1; target<=MaxClients; target++)
					{
						if(IsClientInGame(target) && target!=index)
						{
							EmitSoundToClient(target, sound, client, _, _, _, _, _, index, position);
							EmitSoundToClient(target, sound, client, _, _, _, _, _, index, position);
						}
					}
				}
			}			
		}
		default:
		{
			if(charge<=0.2 && !bEnableSuperDuperJump[client])
			{
				SetHudTextParams(-1.0, 0.93, 0.15, 255, 255, 255, 255);
				ShowSyncHudText(client, jumpHUD, status4);
			}
		}
	}
	
}

/*
************************* FORWARDS ***************************
* Here you will find all the forwards used by this subplugin *
* Except FF2_OnAbility2 which is on the ABILITIES section    *
**************************************************************
*/

public Action:FF2_OnTriggerHurt(boss,triggerhurt,&Float:damage)
{
	new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!bEnableSuperDuperJump[client])
	{
		bEnableSuperDuperJump[client]=true;
		if (FF2_GetBossCharge(boss,1)<0)
			FF2_SetBossCharge(boss,1,0.0);
	}
	return Plugin_Continue;
}

#if SOURCEMOD_V_MAJOR==1 && SOURCEMOD_V_MINOR<=7
public Action:SoundHook(clients[64], &numClients, String:vl[PLATFORM_MAX_PATH], &client, &channel, &Float:volume, &level, &pitch, &flags)
#else
public Action:SoundHook(clients[64], &numClients, String:vl[PLATFORM_MAX_PATH], &client, &channel, &Float:volume, &level, &pitch, &flags, String:soundEntry[PLATFORM_MAX_PATH], &seed)
#endif
{
	if(!IsValidClient(client, false) || channel<1)
	{
		return Plugin_Continue;
	}

	switch(VOMode[client])
	{
		case VoiceMode_None: // NO Voicelines!
		{
			if(channel==SNDCHAN_VOICE)
			{
				return Plugin_Stop;
			}
		}
		case VoiceMode_Robot:	// Robot VO
		{
			if(!TF2_IsPlayerInCondition(client, TFCond_Disguised)) // Robot voice lines & footsteps
			{
				if (StrContains(vl, "player/footsteps/", false) != -1 && TF2_GetPlayerClass(client) != TFClass_Medic)
				{
					new rand = GetRandomInt(1,18);
					Format(vl, sizeof(vl), "mvm/player/footsteps/robostep_%s%i.wav", (rand < 10) ? "0" : "", rand);
					pitch = GetRandomInt(95, 100);
					EmitSoundToAll(vl, client, _, _, _, 0.25, pitch);
				}
				
				if(channel==SNDCHAN_VOICE)
				{
					if (volume == 0.99997) return Plugin_Continue;
					ReplaceString(vl, sizeof(vl), "vo/", "vo/mvm/norm/", false);
					ReplaceString(vl, sizeof(vl), ".wav", ".mp3", false);
					new String:classname[10], String:classname_mvm[15];
					TF2_GetNameOfClass(TF2_GetPlayerClass(client), classname, sizeof(classname));
					Format(classname_mvm, sizeof(classname_mvm), "%s_mvm", classname);
					ReplaceString(vl, sizeof(vl), classname, classname_mvm, false);
					new String:nSnd[PLATFORM_MAX_PATH];
					Format(nSnd, sizeof(nSnd), "sound/%s", vl);
					PrecacheSound(vl);
				}
				return Plugin_Changed;
			}
		}
		case VoiceMode_GiantRobot: // Giant Robot VO
		{
			if(!TF2_IsPlayerInCondition(client, TFCond_Disguised)) // Giant robot voice lines & footsteps
			{
				if (StrContains(vl, "player/footsteps/", false) != -1 && TF2_GetPlayerClass(client) != TFClass_Medic)
				{
					Format(vl, sizeof(vl), "mvm/giant_common/giant_common_step_0%i.wav", GetRandomInt(1,8));
					pitch = GetRandomInt(95, 100);
					EmitSoundToAll(vl, client, _, _, _, 0.25, pitch);
				}
				
				if(channel==SNDCHAN_VOICE)
				{
					if (volume == 0.99997) return Plugin_Continue;
					ReplaceString(vl, sizeof(vl), "vo/", "vo/mvm/mght/", false);
					new String:classname[10], String:classname_mvm_m[20];
					TF2_GetNameOfClass(TF2_GetPlayerClass(client), classname, sizeof(classname));
					Format(classname_mvm_m, sizeof(classname_mvm_m), "%s_mvm_m", classname);
					ReplaceString(vl, sizeof(vl), classname, classname_mvm_m, false);
					new String:gSnd[PLATFORM_MAX_PATH];
					Format(gSnd, sizeof(gSnd), "sound/%s", vl);
					PrecacheSound(vl);
				}
				return Plugin_Changed;
			}
		}
		case VoiceMode_BossCatchPhrase: // Minions use boss's catchphrases
		{
			char taunt[PLATFORM_MAX_PATH];
			if(channel==SNDCHAN_VOICE && FF2_RandomSound("catch_phrase", taunt, sizeof(taunt), SummonerIndex[client]))
			{
				strcopy(vl, PLATFORM_MAX_PATH, taunt);
				return Plugin_Changed;
			}
		}
		case VoiceMode_CatchPhrase: // Minions have their own catchphrase lines
		{
			char taunt[PLATFORM_MAX_PATH];
			if(channel==SNDCHAN_VOICE && FF2_RandomSound("sound_minion_catchphrase", taunt, sizeof(taunt), SummonerIndex[client]))
			{
				strcopy(vl, PLATFORM_MAX_PATH, taunt);
				return Plugin_Changed;
			}
		}
		case VoiceMode_RandomBossCatchPhrase: // Random boss model, let's get the boss's catchphrase of that boss
		{
			char taunt[PLATFORM_MAX_PATH];
			if(channel==SNDCHAN_VOICE && HasSection("catch_phrase", taunt, sizeof(taunt), MinionKV[client]))
			{
				strcopy(vl, PLATFORM_MAX_PATH, taunt);
				PrecacheSound(vl);
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

public Action:SaveMinion(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if(attacker>MaxClients)
	{
		decl String:edict[64];
		if(GetEdictClassname(attacker, edict, sizeof(edict)) && !strcmp(edict, "trigger_hurt", false))
		{
			new target, Float:position[3];
			new bool:otherTeamIsAlive;
			for(new player=1; player<=MaxClients; player++)
			{
				if(IsValidEdict(player) && IsClientInGame(player) && IsPlayerAlive(player) && GetClientTeam(player)!=FF2_GetBossTeam())
				{
					otherTeamIsAlive=true;
					break;
				}
			}

			new tries;
			do
			{
				tries++;
				target=GetRandomInt(1, MaxClients);
				if(tries==100)
				{
					return Plugin_Continue;
				}
			}
			while(otherTeamIsAlive && (!IsValidEdict(target) || GetClientTeam(target)==FF2_GetBossTeam() || !IsPlayerAlive(target)));

			GetEntPropVector(target, Prop_Data, "m_vecOrigin", position);
			TeleportEntity(client, position, NULL_VECTOR, NULL_VECTOR);
			TF2_StunPlayer(client, 2.0, 0.0, TF_STUNFLAGS_LOSERSTATE, client);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

/*
************************** STOCKS **************************
* Here you will find all the stocks used by this subplugin *
************************************************************
*/

/*
	Prethink 
*/
public MinionMoveType_PreThink(client)
{
	if(!IsValidClient(client, true) || FF2_GetRoundState()!=1)
	{
		mMoveType[client]=MOVETYPE_WALK;
		SetEntityMoveType(client, mMoveType[client]);
		SDKUnhook(client, SDKHook_PreThink, MinionMoveType_PreThink);
	}
	
	// This is to prevent bosses from getting stuck on the ground.
	if(mMoveType[client]!=MOVETYPE_NONE && mMoveType[client]!=MOVETYPE_WALK)
	{
		if(!(GetEntityFlags(client) & FL_ONGROUND))
		{
			if(GetEntityMoveType(client)!= mMoveType[client])
			{
				SetEntityMoveType(client, mMoveType[client]);
			}
		}
		else
		{
			if(GetEntityMoveType(client)!=MOVETYPE_WALK)
			{
				SetEntityMoveType(client, MOVETYPE_WALK);
			}
		}
	}
}

public Action GetMaxHealth_Minion(client, &maxHealth)
{
	maxHealth=minionMaxHP[client];
	return Plugin_Changed;
}

/*
	sarysa's safe resizing code
*/

new bool:ResizeTraceFailed;
new ResizeMyTeam;
public bool:Resize_TracePlayersAndBuildings(entity, contentsMask)
{
	if (IsValidClient(entity,true))
	{
		if (GetClientTeam(entity) != ResizeMyTeam)
		{
			ResizeTraceFailed = true;
		}
	}
	else if (IsValidEntity(entity))
	{
		static String:classname[64];
		GetEntityClassname(entity, classname, sizeof(classname));
		if ((strcmp(classname, "obj_sentrygun") == 0) || (strcmp(classname, "obj_dispenser") == 0) || (strcmp(classname, "obj_teleporter") == 0)
			|| (strcmp(classname, "prop_dynamic") == 0) || (strcmp(classname, "func_physbox") == 0) || (strcmp(classname, "func_breakable") == 0))
		{
			ResizeTraceFailed = true;
		}
	}

	return false;
}

bool:Resize_OneTrace(const Float:startPos[3], const Float:endPos[3])
{
	static Float:result[3];
	TR_TraceRayFilter(startPos, endPos, MASK_PLAYERSOLID, RayType_EndPoint, Resize_TracePlayersAndBuildings);
	if (ResizeTraceFailed)
	{
		return false;
	}
	TR_GetEndPosition(result);
	if (endPos[0] != result[0] || endPos[1] != result[1] || endPos[2] != result[2])
	{
		return false;
	}
	
	return true;
}

// the purpose of this method is to first trace outward, upward, and then back in.
bool:Resize_TestResizeOffset(const Float:bossOrigin[3], Float:xOffset, Float:yOffset, Float:zOffset)
{
	static Float:tmpOrigin[3];
	tmpOrigin[0] = bossOrigin[0];
	tmpOrigin[1] = bossOrigin[1];
	tmpOrigin[2] = bossOrigin[2];
	static Float:targetOrigin[3];
	targetOrigin[0] = bossOrigin[0] + xOffset;
	targetOrigin[1] = bossOrigin[1] + yOffset;
	targetOrigin[2] = bossOrigin[2];
	
	if (!(xOffset == 0.0 && yOffset == 0.0))
		if (!Resize_OneTrace(tmpOrigin, targetOrigin))
			return false;
		
	tmpOrigin[0] = targetOrigin[0];
	tmpOrigin[1] = targetOrigin[1];
	tmpOrigin[2] = targetOrigin[2] + zOffset;

	if (!Resize_OneTrace(targetOrigin, tmpOrigin))
		return false;
		
	targetOrigin[0] = bossOrigin[0];
	targetOrigin[1] = bossOrigin[1];
	targetOrigin[2] = bossOrigin[2] + zOffset;
		
	if (!(xOffset == 0.0 && yOffset == 0.0))
		if (!Resize_OneTrace(tmpOrigin, targetOrigin))
			return false;
		
	return true;
}

bool:Resize_TestSquare(const Float:bossOrigin[3], Float:xmin, Float:xmax, Float:ymin, Float:ymax, Float:zOffset)
{
	static Float:pointA[3];
	static Float:pointB[3];
	for (new phase = 0; phase <= 7; phase++)
	{
		// going counterclockwise
		if (phase == 0)
		{
			pointA[0] = bossOrigin[0] + 0.0;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + ymax;
		}
		else if (phase == 1)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + 0.0;
		}
		else if (phase == 2)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + 0.0;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 3)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + 0.0;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 4)
		{
			pointA[0] = bossOrigin[0] + 0.0;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 5)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + 0.0;
		}
		else if (phase == 6)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + 0.0;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + ymax;
		}
		else if (phase == 7)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + 0.0;
			pointB[1] = bossOrigin[1] + ymax;
		}

		for (new shouldZ = 0; shouldZ <= 1; shouldZ++)
		{
			pointA[2] = pointB[2] = shouldZ == 0 ? bossOrigin[2] : (bossOrigin[2] + zOffset);
			if (!Resize_OneTrace(pointA, pointB))
				return false;
		}
	}
		
	return true;
}

public bool:IsSpotSafe(clientIdx, Float:playerPos[3], Float:sizeMultiplier)
{
	ResizeTraceFailed = false;
	ResizeMyTeam = GetClientTeam(clientIdx);
	static Float:mins[3];
	static Float:maxs[3];
	mins[0] = -24.0 * sizeMultiplier;
	mins[1] = -24.0 * sizeMultiplier;
	mins[2] = 0.0;
	maxs[0] = 24.0 * sizeMultiplier;
	maxs[1] = 24.0 * sizeMultiplier;
	maxs[2] = 82.0 * sizeMultiplier;

	// the eight 45 degree angles and center, which only checks the z offset
	if (!Resize_TestResizeOffset(playerPos, mins[0], mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], 0.0, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], maxs[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, 0.0, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, maxs[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], 0.0, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], maxs[1], maxs[2])) return false;

	// 22.5 angles as well, for paranoia sake
	if (!Resize_TestResizeOffset(playerPos, mins[0], mins[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], maxs[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], mins[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], maxs[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0] * 0.5, mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0] * 0.5, mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0] * 0.5, maxs[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0] * 0.5, maxs[1], maxs[2])) return false;

	// four square tests
	if (!Resize_TestSquare(playerPos, mins[0], maxs[0], mins[1], maxs[1], maxs[2])) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.75, maxs[0] * 0.75, mins[1] * 0.75, maxs[1] * 0.75, maxs[2])) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.5, maxs[0] * 0.5, mins[1] * 0.5, maxs[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.25, maxs[0] * 0.25, mins[1] * 0.25, maxs[1] * 0.25, maxs[2])) return false;
	
	return true;
}

/*
	Hitbox scaling
*/
stock UpdatePlayerHitbox(const client, Float:scale)
{
	new Float:vecScaledPlayerMin[3] = { -24.5, -24.5, 0.0 }, Float:vecScaledPlayerMax[3] = { 24.5,  24.5, 83.0 };
	ScaleVector(vecScaledPlayerMin, scale);
	ScaleVector(vecScaledPlayerMax, scale);
	SetEntPropVector(client, Prop_Send, "m_vecSpecifiedSurroundingMins", vecScaledPlayerMin);
	SetEntPropVector(client, Prop_Send, "m_vecSpecifiedSurroundingMaxs", vecScaledPlayerMax);
}

/*
	Health Parser
 */
stock Operate(Handle:sumArray, &bracket, Float:value, Handle:_operator)
{
	new Float:sum=GetArrayCell(sumArray, bracket);
	switch(GetArrayCell(_operator, bracket))
	{
		case Operator_Add:
		{
			SetArrayCell(sumArray, bracket, sum+value);
		}
		case Operator_Subtract:
		{
			SetArrayCell(sumArray, bracket, sum-value);
		}
		case Operator_Multiply:
		{
			SetArrayCell(sumArray, bracket, sum*value);
		}
		case Operator_Divide:
		{
			if(!value)
			{
				LogError("[SHADoW93 Minions] Detected a divide by 0!");
				bracket=0;
				return;
			}
			SetArrayCell(sumArray, bracket, sum/value);
		}
		case Operator_Exponent:
		{
			SetArrayCell(sumArray, bracket, Pow(sum, value));
		}
		default:
		{
			SetArrayCell(sumArray, bracket, value);  //This means we're dealing with a constant
		}
	}
	SetArrayCell(_operator, bracket, Operator_None);
}

stock OperateString(Handle:sumArray, &bracket, String:value[], size, Handle:_operator)
{
	if(!StrEqual(value, ""))  //Make sure 'value' isn't blank
	{
		Operate(sumArray, bracket, StringToFloat(value), _operator);
		strcopy(value, size, "");
	}
}

public ParseFormula(boss, const String:key[], defaultValue, playing)
{
	decl String:formula[1024], String:bossName[64];
	FF2_GetBossSpecial(boss, bossName, sizeof(bossName));
	strcopy(formula, sizeof(formula), key);
	new size=1;
	new matchingBrackets;
	for(new i; i<=strlen(formula); i++)  //Resize the arrays once so we don't have to worry about it later on
	{
		if(formula[i]=='(')
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
		else if(formula[i]==')')
		{
			matchingBrackets++;
		}
	}

	new Handle:sumArray=CreateArray(_, size), Handle:_operator=CreateArray(_, size);
	new bracket;  //Each bracket denotes a separate sum (within parentheses).  At the end, they're all added together to achieve the actual sum
	SetArrayCell(sumArray, 0, 0.0);  //TODO:  See if these can be placed naturally in the loop
	SetArrayCell(_operator, bracket, Operator_None);

	new String:character[2], String:value[16];  //We don't decl value because we directly append characters to it and there's no point in decl'ing character
	for(new i; i<=strlen(formula); i++)
	{
		character[0]=formula[i];  //Find out what the next char in the formula is
		switch(character[0])
		{
			case ' ', '\t':  //Ignore whitespace
			{
				continue;
			}
			case '(':
			{
				bracket++;  //We've just entered a new parentheses so increment the bracket value
				SetArrayCell(sumArray, bracket, 0.0);
				SetArrayCell(_operator, bracket, Operator_None);
			}
			case ')':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
				if(GetArrayCell(_operator, bracket)!=Operator_None)  //Something like (5*)
				{
					LogError("[SHADoW93 Minions] %s's %s formula has an invalid operator at character %i", bossName, key, i+1);
					CloseHandle(sumArray);
					CloseHandle(_operator);
					return defaultValue;
				}

				if(--bracket<0)  //Something like (5))
				{
					LogError("[SHADoW93 Minions] %s's %s formula has an unbalanced parentheses at character %i", bossName, key, i+1);
					CloseHandle(sumArray);
					CloseHandle(_operator);
					return defaultValue;
				}

				Operate(sumArray, bracket, GetArrayCell(sumArray, bracket+1), _operator);
			}
			case '\0':  //End of formula
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
			}
			case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.':
			{
				StrCat(value, sizeof(value), character);  //Constant?  Just add it to the current value
			}
			case 'n', 'x':  //n and x denote player variables
			{
				Operate(sumArray, bracket, float(playing), _operator);
			}
			case '+', '-', '*', '/', '^':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
				switch(character[0])
				{
					case '+':
					{
						SetArrayCell(_operator, bracket, Operator_Add);
					}
					case '-':
					{
						SetArrayCell(_operator, bracket, Operator_Subtract);
					}
					case '*':
					{
						SetArrayCell(_operator, bracket, Operator_Multiply);
					}
					case '/':
					{
						SetArrayCell(_operator, bracket, Operator_Divide);
					}
					case '^':
					{
						SetArrayCell(_operator, bracket, Operator_Exponent);
					}
				}
			}
		}
	}

	new result=RoundFloat(GetArrayCell(sumArray, 0));
	CloseHandle(sumArray);
	CloseHandle(_operator);
	if(result<=0)
	{
		LogError("[SHADoW93 Minions] %s has an invalid %s formula for minions, using default health!", bossName, key);
		return defaultValue;
	}
	return result;
}


stock ClassResponses(client) // Simple Class responses
{
	if(IsValidClient(client, true) && GetClientTeam(client)!=FF2_GetBossTeam())
	{
		new String:Reaction[PLATFORM_MAX_PATH];
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Scout: // Scout
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, ScoutReact[GetRandomInt(0, sizeof(ScoutReact)-1)]);
			}
			case TFClass_Soldier: // Soldier
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, SoldierReact[GetRandomInt(0, sizeof(SoldierReact)-1)]);
			}
			case TFClass_Pyro: // Pyro
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, PyroReact[GetRandomInt(0, sizeof(PyroReact)-1)]);
			}
			case TFClass_DemoMan: // DemoMan
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, DemoReact[GetRandomInt(0, sizeof(DemoReact)-1)]);
			}
			case TFClass_Heavy: // Heavy
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, HeavyReact[GetRandomInt(0, sizeof(HeavyReact)-1)]);
			}
			case TFClass_Engineer: // Engineer
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, EngyReact[GetRandomInt(0, sizeof(EngyReact)-1)]);
			}	
			case TFClass_Medic: // Medic
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, MedicReact[GetRandomInt(0, sizeof(MedicReact)-1)]);
			}
			case TFClass_Sniper: // Sniper
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, SniperReact[GetRandomInt(0, sizeof(SniperReact)-1)]);
			}
			case TFClass_Spy: // Spy
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, SpyReact[GetRandomInt(0, sizeof(SpyReact)-1)]);
			}
		}
		EmitSoundToAll(Reaction, client);
	}
}


stock TeleToRandomPlayer(client) // Teleport to random player
{
	new Float:pos_2[3], target, teleportme, bool:AlivePlayers;
	for(new ii=1;ii<=MaxClients;ii++)
	if(IsValidEdict(ii) && IsValidClient(ii, true) && GetClientTeam(ii)!=FF2_GetBossTeam())
	{
		AlivePlayers=true;
		break;
	}
	do
	{
		teleportme++;
		target=GetRandomInt(1,MaxClients);
		if (teleportme==100)
			return;
	}
	while (AlivePlayers && (!IsValidEdict(target) || (target==client) || !IsPlayerAlive(target)));
	
	if (IsValidEdict(target))
	{
		GetEntPropVector(target, Prop_Data, "m_vecOrigin", pos_2);
		GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos_2);
		if(GetEntProp(target, Prop_Send, "m_bDucked"))
		{
			new Float:temp[3]={24.0, 24.0, 62.0};
			SetEntPropVector(client, Prop_Send, "m_vecMaxs", temp);
			SetEntProp(client, Prop_Send, "m_bDucked", 1);
			SetEntityFlags(client, GetEntityFlags(client)|FL_DUCKING);
		}
		TeleportEntity(client, pos_2, NULL_VECTOR, NULL_VECTOR);
	}
}

stock SetRangedConditionRage(boss, client, const String:ability_name[], TFCond:condition) // Applies a single TFCond to players within range
{
	new Float:pos[3], Float:pos2[3], Float:distance;
	new mode=FF2_GetAbilityArgument(boss,this_plugin_name,ability_name, 1); // mode
	new Float:length=FF2_GetAbilityArgumentFloat(boss,this_plugin_name,ability_name, 2); // Effect Duration
	new Float:dist=FF2_GetAbilityArgumentFloat(boss,this_plugin_name,ability_name, 3);	//range
	if(!dist)
	{
		dist=FF2_GetRageDist(boss, this_plugin_name, ability_name); // Use Ragedist if range is not set
	}
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	if(!mode|| mode==2)
	{
		if(IsValidClient(client, true))
		{
			TF2_AddCondition(client, TFCond:condition, length);
		}
	}
	if(mode)
	{
		for(new target=1;target<=MaxClients;target++)
		{
			if(IsValidClient(target,true))
			{
				GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
				distance=GetVectorDistance( pos, pos2 );
				if (distance<dist && GetClientTeam(target)!=FF2_GetBossTeam())
				{
					TF2_AddCondition(target, TFCond:condition, length);
				}
			}
		}
	}
}

stock bool:IsValidClient(client, bool:isPlayerAlive=false) // Checks if a client is valid
{
	if (client <= 0 || client > MaxClients) return false;
	if (isPlayerAlive) return IsClientInGame(client) && IsPlayerAlive(client);
	return IsClientInGame(client);
}

stock TF2_GetNameOfClass(TFClassType:class, String:name[], maxlen) // Retrieves player class name
{
	switch (class)
	{
		case TFClass_Scout: Format(name, maxlen, "scout");
		case TFClass_Soldier: Format(name, maxlen, "soldier");
		case TFClass_Pyro: Format(name, maxlen, "pyro");
		case TFClass_DemoMan: Format(name, maxlen, "demoman");
		case TFClass_Heavy: Format(name, maxlen, "heavy");
		case TFClass_Engineer: Format(name, maxlen, "engineer");
		case TFClass_Medic: Format(name, maxlen, "medic");
		case TFClass_Sniper: Format(name, maxlen, "sniper");
		case TFClass_Spy: Format(name, maxlen, "spy");
	}
}

stock DropReanimator(client) // Drops a revive marker
{
	new clientTeam = GetClientTeam(client);
	reviveMarker[client] = CreateEntityByName("entity_revive_marker");
	if (reviveMarker[client] != -1)
	{
		SetEntPropEnt(reviveMarker[client], Prop_Send, "m_hOwner", client); // client index 
		SetEntProp(reviveMarker[client], Prop_Send, "m_nSolidType", 2); 
		SetEntProp(reviveMarker[client], Prop_Send, "m_usSolidFlags", 8); 
		SetEntProp(reviveMarker[client], Prop_Send, "m_fEffects", 16); 	
		SetEntProp(reviveMarker[client], Prop_Send, "m_iTeamNum", clientTeam); // client team 
		SetEntProp(reviveMarker[client], Prop_Send, "m_CollisionGroup", 1); 
		SetEntProp(reviveMarker[client], Prop_Send, "m_bSimulatedEveryTick", 1); 
		SetEntProp(reviveMarker[client], Prop_Send, "m_nBody", _:TF2_GetPlayerClass(client) - 1); 
		SetEntProp(reviveMarker[client], Prop_Send, "m_nSequence", 1); 
		SetEntPropFloat(reviveMarker[client], Prop_Send, "m_flPlaybackRate", 1.0);  
		SetEntProp(reviveMarker[client], Prop_Data, "m_iInitialTeamNum", clientTeam);
		SetEntDataEnt2(client, FindSendPropInfo("CTFPlayer", "m_nForcedSkin")+4, reviveMarker[client]);
		if(GetClientTeam(client) == 3)
			SetEntityRenderColor(reviveMarker[client], 0, 0, 255); // make the BLU Revive Marker distinguishable from the red one
		DispatchSpawn(reviveMarker[client]);
		CreateTimer(0.1, MoveMarker, GetClientUserId(client));
		if(decayTimers[client] == null) 
		{
			decayTimers[client] = CreateTimer(float(decaytime), TimeBeforeRemoval, GetClientUserId(client));
		}
	} 
}

stock bool:IsValidMarker(marker) // Checks if revive marker is a valid entity.
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

stock RemoveReanimator(client) // Removes a revive marker
{
	currentTeam[client] = GetClientTeam(client);
	ChangeClass[client] = false;
	if (IsValidMarker(reviveMarker[client])) 
	{
		AcceptEntityInput(reviveMarker[client], "Kill");
	} 
	if (decayTimers[client] != null) 
	{
		KillTimer(decayTimers[client]);
		decayTimers[client] = null;
	}
}

/*
************************* TIMERS ***************************
* Here you will find all the timers used by this subplugin *
************************************************************
*/

// Thriller Taunt


public Action:MoveMarker(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	new Float:position[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", position);
	TeleportEntity(reviveMarker[client], position, NULL_VECTOR, NULL_VECTOR);
}

public Action:TimeBeforeRemoval(Handle:timer, any:userid) 
{
	new client = GetClientOfUserId(userid);
	if(!IsValidMarker(reviveMarker[client]) || !IsValidClient(client)) 
		return Plugin_Handled;
	if(GetFF2BossType(client)==FF2BossType_IsMinion && !IsPlayerAlive(client) && revivemarkers!=0)
	{
		ResetSalmonSettings(client);
		ChangeClientTeam(client, (FF2_GetBossTeam()==_:TFTeam_Blue) ? (_:TFTeam_Red) : (_:TFTeam_Blue));
	}
	RemoveReanimator(client);
	if(decayTimers[client] != null)
	{
		KillTimer(decayTimers[client]);
		decayTimers[client] = null;
	}
	return Plugin_Continue;
}

public Action:ResetCharge(Handle:timer, any:index)
{
	new slot=index%10000;
	index/=1000;
	FF2_SetBossCharge(index, slot, 0.0);
}

public Action:Timer_Enable_Damage(Handle:timer, any:userid)
{
	new client=GetClientOfUserId(userid);
	if(client)
	{
		SetEntProp(client, Prop_Data, "m_takedamage", 2);
		FF2_SetFF2flags(client, FF2_GetFF2flags(client) & ~FF2FLAG_ALLOWSPAWNINBOSSTEAM);
		SDKUnhook(client, SDKHook_OnTakeDamage, SaveMinion);
	}
	return Plugin_Continue;
}

/********************************************************************************************************************
********************************************STOCKS USED INTERNALLY***************************************************
*********************************************************************************************************************/
stock int GetMinionCount()
{
	int minions=0;
	for(int client=1;client<=MaxClients;client++)
	{
		if(!IsValidClient(client, true)) continue;
		if(TF2_GetClientTeam(client)!=view_as<TFTeam>(FF2_GetBossTeam())) continue;
		if(FF2_GetBossIndex(client)!=-1) continue;
		minions++;
	}
	return minions;
}
stock int GetAlivePlayerCount(TFTeam team)
{
	int alivePlayers=0;
	for (int client=1;client<=MaxClients;client++)
	{
		if(!IsValidClient(client, true))
			continue;
		if(TF2_GetClientTeam(client)!=team)
			continue;
		alivePlayers++;
	}
	return alivePlayers;
}

stock int SetWeaponClip(int client, int slot, int clip)
{
	int weapon = GetPlayerWeaponSlot(client, slot);
	if (IsValidEntity(weapon))
	{
		SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
	}
}

stock int SetWeaponAmmo(int client, int slot, int ammo)
{
	int weapon = GetPlayerWeaponSlot(client, slot);
	if (IsValidEntity(weapon))
	{
		int iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		SetEntData(client, iAmmoTable+iOffset, ammo, 4, true);
	}
}
stock void SetCondition(int client, char[] cond)
{
	char conds[32][32];
	int count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		for (int i = 0; i < count; i+=2)
		{
			TF2_AddCondition(client, TFCond:StringToInt(conds[i]), StringToFloat(conds[i+1]));
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

/********************************************************************************************************************
****************************************DEVELOPER INTERFACE STUFFS***************************************************
*********************************************************************************************************************/

/*
	Spawns a minion
*/
public void Salmon(int boss, int client, bool spawnalert, int quantity, float ratio, TFClassType tfclasstype, char[] hpFormula, int pickups, int modelmode, char[] model, int weaponmode, bool removewearables, char[] classname, int index, char[] attributes, int ammo, int clip, int accessories, char[] conditions, float uberprotection, int voicelinesmode, bool notify, char[] summoned_text, char[] summoner_text, bool teletoboss, bool noslay, float scale,  float gravity, char[] moveType, char[] prgba, char[] wrgba, bool wvisibility, bool NoOverHeal, float weaponscale, char[] worldmodel) // Originally coded by Otokiru, upgraded by SHADoW93. Minion spawner
{
	int weapon;
	float position[3], velocity[3];
	if(spawnalert)
	{
		EmitSoundToAll(MANN_SND);
	}
	
	if(GetAlivePlayerCount((TFTeam:FF2_GetBossTeam()==TFTeam_Blue) ? (TFTeam_Red) : (TFTeam_Blue))<quantity || !quantity) 
	{
		quantity=GetAlivePlayerCount((TFTeam:FF2_GetBossTeam()==TFTeam_Blue) ? (TFTeam_Red) : (TFTeam_Blue));
	}
	
	if(quantity==-1)
	{
		quantity=(ratio ? RoundToCeil(GetAlivePlayerCount((TFTeam:FF2_GetBossTeam()==TFTeam_Blue) ? (TFTeam_Red) : (TFTeam_Blue))*ratio) : MaxClients);
	}
	
	Handle bossKV=GetRandomBossKV(boss);
	
	int ii;
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", position);
	for (int i=0; i<quantity; i++)
	{
		ii = GetRandomDeadPlayer();
		if(ii != -1)
		{
			FF2_SetFF2flags(ii,FF2_GetFF2flags(ii)|FF2FLAG_ALLOWSPAWNINBOSSTEAM);
			if(pickups)
			{
				if(pickups==1 || pickups==3)
					FF2_SetFF2flags(ii,FF2_GetFF2flags(ii)|FF2FLAG_ALLOW_HEALTH_PICKUPS); // HP Pickup
				if(pickups==2 || pickups==3)
					FF2_SetFF2flags(ii,FF2_GetFF2flags(ii)|FF2FLAG_ALLOW_AMMO_PICKUPS); // Ammo Pickup
				else
				{
					FF2_SetFF2flags(ii,FF2_GetFF2flags(ii)|~FF2FLAG_ALLOW_HEALTH_PICKUPS); // HP Pickup
					FF2_SetFF2flags(ii,FF2_GetFF2flags(ii)|~FF2FLAG_ALLOW_AMMO_PICKUPS); // Ammo Pickup
				}
			}
			
			TF2_ChangeClientTeam(ii,TFTeam:FF2_GetBossTeam());
			TF2_RespawnPlayer(ii);
			
			switch(modelmode)
			{
				case 1:	// robots
				{
					if(tfclasstype)
					{
						TF2_SetPlayerClass(ii, tfclasstype, _, false);
						TF2_RegeneratePlayer(ii);
					}
				
					char pclassname[10];
					TF2_GetNameOfClass(TF2_GetPlayerClass(ii), pclassname, sizeof(pclassname));
					Format(model, PLATFORM_MAX_PATH, "models/bots/%s/bot_%s.mdl", pclassname, pclassname);
					ReplaceString(model, PLATFORM_MAX_PATH, "demoman", "demo", false);
					VOMode[ii]=VoiceMode_Robot;
					if(uberprotection)
					{
						TF2_AddCondition(ii, TFCond_UberchargedHidden, uberprotection);
					}
				}
				case 2: // looks like a random boss
				{
					MinionKV[client]=bossKV;
					char taunt[PLATFORM_MAX_PATH];
					TF2_SetPlayerClass(ii, TFClassType:KvGetNum(bossKV, "class", 0), _, false);
					KvGetString(bossKV, "model", model, PLATFORM_MAX_PATH);	
					if(KvGetNum(bossKV, "sound_block_vo", 0))
					{
						VOMode[ii]=((!HasSection("catch_phrase", taunt, sizeof(taunt), bossKV)) ? VoiceMode_None : VoiceMode_RandomBossCatchPhrase);
					}
					else
					{
						VOMode[ii]=((!HasSection("catch_phrase", taunt, sizeof(taunt), bossKV)) ? VoiceMode_Normal : VoiceMode_RandomBossCatchPhrase);
					}
				}
				case 3: // clone of boss
				{
					char taunt[PLATFORM_MAX_PATH];
					Handle curBossKV=FF2_GetSpecialKV(boss, false);
					TF2_SetPlayerClass(ii, TFClassType:KvGetNum(curBossKV, "class", 0), _, false);
					KvGetString(curBossKV, "model", model, PLATFORM_MAX_PATH);	
					if(KvGetNum(curBossKV, "sound_block_vo", 0))
					{
						VOMode[ii]=((!FF2_RandomSound("catch_phrase", taunt, sizeof(taunt), boss)) ? VoiceMode_None : VoiceMode_BossCatchPhrase);
					}
					else
					{
						VOMode[ii]=((!FF2_RandomSound("catch_phrase", taunt, sizeof(taunt), boss)) ? VoiceMode_Normal : VoiceMode_BossCatchPhrase);
					}
				}
				default:
				{
					if(uberprotection)
						TF2_AddCondition(ii, TFCond_Ubercharged, uberprotection);
					if(voicelinesmode)
					{
						VOMode[ii]=VoiceMode:voicelinesmode;
					}
				}
			}
			
			SetPlayerModel(ii, model);
			
			DontSlay[ii]=noslay;
			SummonerIndex[ii]=boss;	
			
			int playing=0;
			for(int player=1;player<=MaxClients;player++)
			{
				if(!IsValidClient(player, true))
					continue;
				if(TF2_GetClientTeam(player)!=view_as<TFTeam>(FF2_GetBossTeam()))
				{
					playing++;
				}
			}
			
			int health=ParseFormula(boss, hpFormula, GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, ii), playing);
			if(health)
			{
				SetEntityHealth(ii, health);
				if(health!=GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, ii) && NoOverHeal)
				{
					HookHealth[ii]=true;
					SDKHook(ii, SDKHook_GetMaxHealth, GetMaxHealth_Minion);
					minionMaxHP[ii]=health;
				}
			}
			
			if(conditions[0]!='\0')
				SetCondition(ii, conditions);
				
			if(removewearables)
			{
				int owner, entity;
				while((entity=FindEntityByClassname(entity, "tf_wearable"))!=-1)
					if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==FF2_GetBossTeam())
						TF2_RemoveWearable(owner, entity);
				while((entity=FindEntityByClassname(entity, "tf_wearable_demoshield"))!=-1)
					if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==FF2_GetBossTeam())
						TF2_RemoveWearable(owner, entity);
				while((entity=FindEntityByClassname(entity, "tf_powerup_bottle"))!=-1)
					if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==FF2_GetBossTeam())
						TF2_RemoveWearable(owner, entity);
			}
			
			if(notify)
			{
				char spcl[768];
				FF2_GetBossSpecial(boss, spcl, sizeof(spcl));
				PrintHintText(client, "%s", summoner_text);
				PrintHintText(ii, "%s", summoned_text);
			}

			if(gravity)
			{
				SetEntityGravity(ii, gravity);
			}

			if(prgba[0]!='\0')
			{
				char colors[32][32];
				int count = ExplodeString(prgba, " ; ", colors, sizeof(colors), sizeof(colors));
				if (count > 0)
				{
					for (int c = 0; c < count; c+=4)
					{
						SetEntityRenderMode(ii, RENDER_TRANSCOLOR);
						SetEntityRenderColor(ii, StringToInt(colors[c]), StringToInt(colors[c+1]), StringToInt(colors[c+2]), StringToInt(colors[c+3]));
					}
				}
			}
			
			if(teletoboss)
			{
				velocity[0]=GetRandomFloat(300.0, 500.0)*(GetRandomInt(0, 1) ? 1:-1);
				velocity[1]=GetRandomFloat(300.0, 500.0)*(GetRandomInt(0, 1) ? 1:-1);
				velocity[2]=GetRandomFloat(300.0, 500.0);
				if(GetEntProp(client, Prop_Send, "m_bDucked"))
				{
					float temp[3]={24.0, 24.0, 62.0};
					SetEntPropVector(ii, Prop_Send, "m_vecMaxs", temp);
					SetEntProp(ii, Prop_Send, "m_bDucked", 1);
					SetEntityFlags(ii, GetEntityFlags(ii)|FL_DUCKING);
				}
				TeleportEntity(ii, position, NULL_VECTOR, velocity);
			}
			
			if(scale)
			{
				float spawnpos[3];
				GetEntPropVector(ii, Prop_Data, "m_vecOrigin", spawnpos);
				if(IsSpotSafe(ii, (teletoboss) ? (position) : (spawnpos), scale))
				{
					SetEntPropFloat(ii, Prop_Send, "m_flModelScale", scale);
					if(isHitBoxAvailable)
					{
						UpdatePlayerHitbox(ii, scale);
					}
				}
				else
				{
					LogError("[SHADoW93 Minions] %N was not resized to %f to avoid getting stuck!", ii, scale);
				}
			}
			SetEntProp(ii, Prop_Data, "m_takedamage", 0);
			SDKHook(ii, SDKHook_OnTakeDamage, SaveMinion);
			CreateTimer(4.0, Timer_Enable_Damage, GetClientUserId(ii));			
			
			if(moveType[0])
			{
				if(StrEqual(moveType, "walk", false))
					mMoveType[ii]=MOVETYPE_WALK;
				else if(StrEqual(moveType, "isometric", false))
					mMoveType[ii]=MOVETYPE_ISOMETRIC;
				else if(StrEqual(moveType, "step", false))
					mMoveType[ii]=MOVETYPE_STEP;
				else if(StrEqual(moveType, "fly", false))
					mMoveType[ii]=MOVETYPE_FLY;
				else if(StrEqual(moveType, "flygravity", false))
					mMoveType[ii]=MOVETYPE_FLYGRAVITY;
				else if(StrEqual(moveType, "vphysics", false))
					mMoveType[ii]=MOVETYPE_VPHYSICS;
				else if(StrEqual(moveType, "push", false))
					mMoveType[ii]=MOVETYPE_PUSH;
				else if(StrEqual(moveType, "noclip", false))
					mMoveType[ii]=MOVETYPE_NOCLIP;
				else if(StrEqual(moveType, "ladder", false))
					mMoveType[ii]=MOVETYPE_LADDER;
				else if(StrEqual(moveType, "observer", false))
					mMoveType[ii]=MOVETYPE_OBSERVER;
				else if(StrEqual(moveType, "custom", false))
					mMoveType[ii]=MOVETYPE_CUSTOM;	
				else if(StrEqual(moveType, "none", false))
					mMoveType[ii]=MOVETYPE_NONE;
					
				if(mMoveType[ii]!=MOVETYPE_WALK && mMoveType[ii]!=MOVETYPE_NONE)
				{
					SetEntityMoveType(ii, mMoveType[ii]);
					SDKHook(ii, SDKHook_PreThink, MinionMoveType_PreThink);
				}
			}
			
			switch(weaponmode)
			{
				case 2: // No weapons
					TF2_RemoveAllWeapons(ii);
				case 1: // User-Specified
				{
					TF2_RemoveAllWeapons(ii);
					weapon=SpawnWeapon(ii, classname, index, 101, 0, attributes, true, wvisibility);
					if(ammo)
						SetWeaponAmmo(ii, weapon, ammo);
					if(clip)
						SetWeaponClip(ii, weapon, clip);
					if(wrgba[0])
					{
						char colors[32][32];
						int count = ExplodeString(wrgba, " ; ", colors, sizeof(colors), sizeof(colors));
						if (count > 0)
						{
							for (int c = 0; c < count; c+=4)
							{
								SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
								SetEntityRenderColor(weapon, StringToInt(colors[c]), StringToInt(colors[c+1]), StringToInt(colors[c+2]), StringToInt(colors[c+3]));
							}
						}
					}	
					if(worldmodel[0])
					{
						new modelIndex=PrecacheModel(worldmodel);
						SetEntProp(weapon, Prop_Send, "m_nModelIndex", modelIndex);
						SetEntProp(weapon, Prop_Send, "m_nModelIndexOverrides", modelIndex, _, 1);
						SetEntProp(weapon, Prop_Send, "m_nModelIndexOverrides", modelIndex, _, 2);
						SetEntProp(weapon, Prop_Send, "m_nModelIndexOverrides", modelIndex, _, 3);
						SetEntProp(weapon, Prop_Send, "m_nModelIndexOverrides", (!StrContains(classname, "tf_wearable", true) ? GetEntProp(weapon, Prop_Send, "m_iWorldModelIndex") : GetEntProp(weapon, Prop_Send, "m_nModelIndex")), _, 0);    
					}
					if(weaponscale)
					{
						SetEntPropFloat(weapon, Prop_Send, "m_flModelScale", weaponscale); 
					}
					
					if(accessories!=0)
					{
						switch(TF2_GetPlayerClass(ii))
						{
							case TFClass_Engineer:
							{
								SpawnWeapon(ii, "tf_weapon_pda_engineer_build", 25, 101, 5, "292 ; 3 ; 293 ; 59 ; 391 ; 2 ; 495 ; 60", false, wvisibility);
								SpawnWeapon(ii, "tf_weapon_pda_engineer_destroy", 26, 101, 5, "391 ; 2", false, wvisibility);
								weapon = SpawnWeapon(ii, "tf_weapon_builder", 28, 101, 5, "391 ; 2", false, wvisibility);
								SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
								SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
								SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
								SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
							}
							case TFClass_Spy:
							{
								if(accessories==4 || accessories==6 || accessories==8 || accessories==11) // Dead Ringer
									SpawnWeapon(ii, "tf_weapon_invis", 59, 1, 0, "33 ; 1 ; 34 ; 1.6 ; 35 ; 1.8 ; 292 ; 9 ; 391 ; 2", false, wvisibility);
								if(accessories==3 || accessories==5 || accessories==7 || accessories==10) // Invis Watch
									SpawnWeapon(ii, "tf_weapon_invis", 30, 1, 0, "391 ; 2", false, wvisibility);
								if(accessories==2|| accessories==5 || accessories == 6 || accessories>=9) // Disguise kit
									SpawnWeapon(ii, "tf_weapon_pda_spy", 27, 1, 0, "391 ; 2", false, wvisibility);
								if(accessories==1 || accessories==7 || accessories>=7) // Sapper
								{
									weapon = SpawnWeapon(ii, "tf_weapon_builder", 735, 101, 5, "391 ; 2", false, wvisibility);
									SetEntProp(weapon, Prop_Send, "m_iObjectType", 3);
									SetEntProp(weapon, Prop_Data, "m_iSubType", 3);
									SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
									SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
									SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
									SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
								}
							}
						}
					}
				}
			}
		}
	}
}

stock void SetPlayerModel(client, char[] model)
{
	if(!model[0])
	{
		return;		
	}
	
	if(!FileExists(model, true))
	{
		LogError("Unable to find model %s, reverting to default model...", model);
		return;
	}
	
	if(!IsModelPrecached(model))
	{
		PrecacheModel(model);
	}
	
	SetVariantString(model);
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
}

/*
	Check if player is a boss, companion or minion or not a boss.
*/

public FF2BossType GetFF2BossType(int client)
{
	if(FF2_GetBossIndex(client)==-1)
	{
		if(TF2_GetClientTeam(client)!=view_as<TFTeam>(FF2_GetBossTeam())) 
			return FF2BossType_NotABoss;
		return FF2BossType_IsMinion;
	}
	if(FF2_GetBossIndex(client)>0) return FF2BossType_IsCompanion;
	return FF2BossType_IsBoss;
}

/*
	Roboticizes a player
*/
public void MakeRobot(int client, int type)
{
	if(!type && VOMode[client]!=VoiceMode_Robot)
	{
		VOMode[client]=VoiceMode_Robot;
	}
	if(type && VOMode[client]!=VoiceMode_GiantRobot)
	{
		VOMode[client]=VoiceMode_GiantRobot;
	}
}

/*
	Undoes roboticzation
*/
public void UnMakeRobot(int client)
{
	if(VOMode[client])
	{
		VOMode[client]=VoiceMode_Normal;
	}
}

/* 
	Checks if player was roboticized
*/
public bool IsPlayerRobot(int client)
{
	if(VOMode[client]==VoiceMode_Robot || VOMode[client]==VoiceMode_GiantRobot) return true;
	return false;
}


/*
	Gets a random dead player
*/
public int GetRandomDeadPlayer()
{
	int[] clients = new int[MaxClients+1];
	int clientCount;
	for(int i=1;i<=MaxClients;i++)
	{
		if(IsValidEdict(i) && IsValidClient(i) && !IsPlayerAlive(i) && GetFF2BossType(i)==FF2BossType_NotABoss && (TF2_GetClientTeam(i) > TFTeam_Spectator))
		{
			clients[clientCount++] = i;
		}
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

stock bool:HasSection(const String:sound[], String:file[], length, Handle bossKV)
{
	if(!bossKV)
	{
		return false;
	}

	KvRewind(bossKV);
	if(!KvJumpToKey(bossKV, sound))
	{
		KvRewind(bossKV);
		return false;  //Requested sound not implemented for this boss
	}

	char key[4];
	int sounds;
	while(++sounds)  //Just keep looping until there's no keys left
	{
		IntToString(sounds, key, sizeof(key));
		KvGetString(bossKV, key, file, length);
		if(!file[0])
		{
			sounds--;  //This sound wasn't valid, so don't include it
			break;  //Assume that there's no more sounds
		}
	}

	if(!sounds)
	{
		return false;  //Found sound, but no sounds inside of it
	}

	IntToString(GetRandomInt(1, sounds), key, sizeof(key));
	KvGetString(bossKV, key, file, length);  //Populate file
	return true;
}

public Handle GetRandomBossKV(int boss)
{
	int index=-1;
	for(int config=0; FF2_GetSpecialKV(config, true)!=null; config++)
	{
		index++;
	}
	
	int position=GetRandomInt(0, index);
	Handle BossKV=FF2_GetSpecialKV(position, true);
	if(BossKV!=null) return BossKV;
	return FF2_GetSpecialKV(boss, false);
}