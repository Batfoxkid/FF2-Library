#include <tf2_stocks>
#include <ff2_ams2>
#include <sdkhooks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

#define FAR_FUTURE 100000000.0
#define HORROR "Horror_Countdown"
float Countdown_tick;
Handle HorrorHUD;
char Horror_Counter[PLATFORM_MAX_PATH];
int startTime=0;
float VictimSpeed[MAXPLAYERS+1] = 0.0;
float PreparationSpeed[MAXPLAYERS+1] = 0.0;
int mysteriousmode;

int HorrorFog=-1;
Handle WinningTimer;
Handle StartingTimer;
Handle GameOverTimer;
Handle OutlineBossTimer;

// For King Bobomb (Sadly does not work correcty, was suppose to make the minions act like Sentry busters, meh, too lazy to fix it)
// You can see this as yet another way to summon people
bool Ishooked=false;
#define MinionExplode		"mvm/sentrybuster/mvm_sentrybuster_explode.wav"
bool Bombombs_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS (incase we want to use it with AMS)
int SummonerIndex[MAXPLAYERS+1];
char bombombmodel[PLATFORM_MAX_PATH], weaponclassname[64], weaponattributes[768], conditions[768];
int minionnumber, class, wearables, weaponindex, health, pickups;

// For Painis Cupcake
float RageDuration;
float AmountGained;
Handle PainisRageTimer;
bool rageison = false;

// For Billy the Doll (I want to play a game, Gentlemen)
int outlinetimer=0;

#define RAGESENTRYHACK "rage_sentry_hijack"
bool SentryHack_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS (incase we want to use it with AMS)

#define RPTA_STRING "rage_pickuptrap_ams"
#define INVALID_ENTREF INVALID_ENT_REFERENCE
#define MAX_ENTITY_CLASSNAME_LENGTH 48
bool RPTA_ActiveThisRound;
bool RPTA_DispensersAreHarmful; // internal
float RPTA_DispensersHarmUntil; // internal
float RPTA_DispenserCheckAt; // internal
float RPTA_Duration[MAXPLAYERS+1]; // arg2
int RPTA_TrapCount[MAXPLAYERS+1]; // arg3
float RPTA_TrapHealthNerfAmount[MAXPLAYERS+1]; // arg4
float RPTA_TrapAmmoNerfAmount[MAXPLAYERS+1]; // arg5
int RPTA_TrappedObjectRecolor[MAXPLAYERS+1]; // arg6
float RPTA_DispenserHarmDuration[MAXPLAYERS+1]; // arg7
float RPTA_DispenserHarmDamage; // arg8
float RPTA_DispenserHarmInterval; // arg9

#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

bool NULL_BLACKLIST[MAX_PLAYERS_ARRAY];

#define MAX_TRAPS 50
bool RPTAT_TrapsNeverExpire;
int RPTAT_EntRef[MAX_TRAPS];
int RPTAT_Trapper[MAX_TRAPS];
float RPTAT_TrappedUntil[MAX_TRAPS];
bool PickupTraps_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS (incase we want to use it with AMS)

// For Gerald The Hunter (Halloween Version of Appelflap64)
#define TIMESTOP "rage_timestop_moonshot"
bool TimeStop_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS (incase we want to use it with AMS)

#define CESTUS_RAMPAGE "rage_cestus_rampage"
#define MAX_WEAPON_NAME_LENGTH 64
#define MAX_WEAPON_ARG_LENGTH 256
#define MAX_SOUND_FILE_LENGTH 80
#define MAX_MODEL_FILE_LENGTH 128
bool Rampage_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS (incase we want to use it with AMS)
float Rampage_UsingUntil[MAX_PLAYERS_ARRAY];
TFClassType Rampage_OriginalClass[MAX_PLAYERS_ARRAY]; // internal
float Rampage_Duration[MAX_PLAYERS_ARRAY]; // arg1
// arg2-arg10 not stored
float Rampage_Speed[MAX_PLAYERS_ARRAY]; // arg11
// arg12 not stored
TFClassType Rampage_TempClass[MAX_PLAYERS_ARRAY]; // arg13

// Grand Cross
#define GRAND_CROSS "rage_grand_cross"
bool GrandCross_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS (incase we want to use it with AMS)
int Beam_Laser;
int Beam_Glow;
int Beam_Halo;
bool GrandCross_ActiveThisRound;
bool GrandCross_CanUse[MAX_PLAYERS_ARRAY];
float GrandCross_RemoveGodModeAt[MAX_PLAYERS_ARRAY];
float GrandCross_RemoveIgniteAt[MAX_PLAYERS_ARRAY];
float GrandCross_BeginShockwaveAt[MAX_PLAYERS_ARRAY];
float GrandCross_AnimateShockwaveAt[MAX_PLAYERS_ARRAY];
bool GrandCross_BlockingAllInput = false;
float GrandCross_BlockingAllInputUntil;
float GrandCross_PlayerCount = 1.0;
float GrandCross_ExecuteRageAt[MAX_PLAYERS_ARRAY];
int GrandCross_AnimTickCount[MAX_PLAYERS_ARRAY];
int GrandCross_EffectColor[MAX_PLAYERS_ARRAY];
int GrandCross_FrameTotal[MAX_PLAYERS_ARRAY];
float GrandCross_Medigun[MAX_PLAYERS_ARRAY];
float GrandCross_Rage[MAX_PLAYERS_ARRAY];
float GrandCross_Cloak[MAX_PLAYERS_ARRAY];
float GrandCross_Hype[MAX_PLAYERS_ARRAY];
float GrandCross_Charge[MAX_PLAYERS_ARRAY];

// Actual version would probably be around 1.5.0
public Plugin myinfo = {
	name	= "Freak Fortress 2: Misc Stuff",
	author	= "M7",
	version = "5.0",
};

public void OnPluginStart2()
{
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_death", event_player_death);
	
	HorrorHUD = CreateHudSynchronizer();
	
	// list of all these are here: http://www.pamelabowman.org/tf2/effectsprites.txt
	Beam_Laser = PrecacheModel("materials/sprites/laser.vmt");
	Beam_Glow = PrecacheModel("sprites/glow02.vmt", true);
	Beam_Halo = PrecacheModel("materials/sprites/halo01.vmt");
}

public Action event_player_death(Event event, const char[] name, bool dontBroadcast)
{
	if(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
	{
		return Plugin_Continue;
	}
	
	int client=GetClientOfUserId(event.GetInt("userid"));
	int attacker=GetClientOfUserId(event.GetInt( "attacker"));
	
	int boss=FF2_GetBossIndex(client);	// Boss is the victim
	if(boss!=-1 && FF2_HasAbility(boss, this_plugin_name, "death_curse") && !(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
	{
		for(int companion=0; companion<=MaxClients; companion++)
		{
			if(IsValidClient(companion) && GetClientTeam(companion)==FF2_GetBossTeam())
			{
				ForcePlayerSuicide(companion);
			}
		}
	}
	
	if(boss!=-1 && FF2_HasAbility(boss, this_plugin_name, "king_bombomb") && !(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
	{
		for(int clone=1; clone<=MaxClients; clone++)
		{
			if(SummonerIndex[clone]==boss && IsValidClient(clone) && IsValidMinion(clone) && IsPlayerAlive(clone))
			{
				SummonerIndex[clone]=-1;
				ChangeClientTeam(clone, (FF2_GetBossTeam()==view_as<int>(TFTeam_Blue)) ? (view_as<int>(TFTeam_Red)) : (view_as<int>(TFTeam_Blue)));
			}
		}
	}
	
	boss=FF2_GetBossIndex(attacker); // Boss is an attacker
	if(boss!=-1 && FF2_HasAbility(boss, this_plugin_name, "painis_rage") && rageison)
	{
		AmountGained = FF2_GetAbilityArgumentFloat(boss, this_plugin_name,"painis_rage", 2);
		
		int bosshealth = FF2_GetBossHealth(boss);
		int maxhealth = FF2_GetBossMaxHealth(boss);
		
		bosshealth = RoundToCeil(bosshealth + (maxhealth * AmountGained));
		if(bosshealth > maxhealth)
		{
			bosshealth = maxhealth;
		}
		
		FF2_SetBossHealth(boss, bosshealth);
	}
	return Plugin_Continue;
}

public void Event_RoundStart(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
	
	rageison = false;
	GrandCross_ActiveThisRound = false;
	GrandCross_BlockingAllInput = false;

	int playerCount = 0;
	for(int client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client) && GetClientTeam(client)!=FF2_GetBossTeam())
			playerCount++;
		
		if(!IsValidClient(client))
			continue;
		
		SummonerIndex[client]=-1;
		
		int boss=FF2_GetBossIndex(client);
		if(boss >= 0 && FF2_HasAbility(boss, this_plugin_name, HORROR))
		{
			ReadCenterText(boss, HORROR, 1, Horror_Counter);
			
			startTime = FF2_GetAbilityArgument(boss, this_plugin_name, HORROR, 2, 210);
		
			mysteriousmode=FF2_GetAbilityArgument(boss, this_plugin_name, HORROR, 3);
		
			if(mysteriousmode != 0)
			{
				int horrorcolor[3][3];
				// horror color
				horrorcolor[0][0]=FF2_GetAbilityArgument(boss, this_plugin_name, HORROR, 5, 255);
				horrorcolor[0][1]=FF2_GetAbilityArgument(boss, this_plugin_name, HORROR, 6, 255);
				horrorcolor[0][2]=FF2_GetAbilityArgument(boss, this_plugin_name, HORROR, 7, 255);
				// horror color 2
				horrorcolor[1][0]=FF2_GetAbilityArgument(boss, this_plugin_name, HORROR, 8, 255);
				horrorcolor[1][1]=FF2_GetAbilityArgument(boss, this_plugin_name, HORROR, 9, 255);
				horrorcolor[1][2]=FF2_GetAbilityArgument(boss, this_plugin_name, HORROR, 10, 255);
				// horror start
				float horrorstart=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, HORROR, 11, 64.0);
				// horror end
				float horrorend=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, HORROR, 12, 384.0);
				// horror density
				float horrordensity=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, HORROR, 13, 1.0);

				HorrorFog = StartHorrorFog(FF2_GetAbilityArgument(boss, this_plugin_name, HORROR, 4, 0), horrorcolor[0], horrorcolor[1], horrorstart, horrorend, horrordensity);
				
				for (int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i))
					{
						SetVariantString("MyFog");
						AcceptEntityInput(i, "SetFogController");
					}
				}
			}
			
			if(mysteriousmode == 1)
			{
				StartingTimer=CreateTimer(1.5, NoWhere_ToRun);
				WinningTimer=CreateTimer(float(startTime), Victorious_RedTeam);
				
				char overlay[PLATFORM_MAX_PATH];
				FF2_GetAbilityArgumentString(boss, this_plugin_name, HORROR, 14, overlay, PLATFORM_MAX_PATH);
				Format(overlay, PLATFORM_MAX_PATH, "r_screenoverlay \"%s\"", overlay);
				SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
				
				for (int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)!=FF2_GetBossTeam())
					{
						ClientCommand(i, overlay);
					}
				}
				
				SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
			}
			
			if(mysteriousmode == 2)
			{
				for(int bossclient=0; bossclient<=MaxClients; bossclient++)
				{
					if (IsValidClient(bossclient) && GetClientTeam(bossclient)==FF2_GetBossTeam())
					{
						float stunduration = FF2_GetAbilityArgumentFloat(boss,this_plugin_name,HORROR, 15);        // Duration (if valid)
						float uberchargeduration = FF2_GetAbilityArgumentFloat(boss,this_plugin_name,HORROR, 16);        // Duration (if valid)
						TF2_StunPlayer(bossclient, stunduration, 0.0, TF_STUNFLAG_BONKSTUCK, boss);
						TF2_AddCondition(bossclient, TFCond_UberchargedHidden, uberchargeduration);
						CreateTimer(0.5, preparation);
					}
				}
			}
			
			if(mysteriousmode == 3)
			{
				outlinetimer = FF2_GetAbilityArgument(boss, this_plugin_name, HORROR, 17);
				GameOverTimer=CreateTimer(float(startTime), GameOver_Mercenaries);
				CreateTimer(0.5, MakeEngiesWeak);
				OutlineBossTimer=CreateTimer(float(outlinetimer), OutlineTheBoss);
				
				for(int i = 1; i <= MaxClients; i++ )
				{
					if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)!= FF2_GetBossTeam())
					{
						SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1);
					}
				}
			}
			
			Countdown_tick=GetEngineTime()+1.0;
		}
	}
	
	if (RPTA_ActiveThisRound)
	{
		
	}
	
	GrandCross_PlayerCount = float(playerCount);
}

public void FF2AMS_PreRoundStart(int client)
{
	int boss = FF2_GetBossIndex(client);
	if(boss>=0 && FF2_HasAbility(boss, this_plugin_name, RPTA_STRING))
	{
		RPTA_ActiveThisRound = true;
		RPTA_DispensersAreHarmful = false;
		
		PickupTraps_TriggerAMS[client]=FF2AMS_PushToAMS(client, this_plugin_name, RPTA_STRING, "RPTA");
		
		for (int i = 0; i < MAX_TRAPS; i++)
			RPTAT_EntRef[i] = INVALID_ENTREF;
			
		HookEntityOutput("item_healthkit_small", "OnPlayerTouch", RPTA_ItemPickup);
		HookEntityOutput("item_healthkit_medium", "OnPlayerTouch", RPTA_ItemPickup);
		HookEntityOutput("item_healthkit_large", "OnPlayerTouch", RPTA_ItemPickup);
		HookEntityOutput("item_ammopack_small", "OnPlayerTouch", RPTA_ItemPickup);
	}
	if(boss>=0 && FF2_HasAbility(boss, this_plugin_name, CESTUS_RAMPAGE))
	{
		Rampage_UsingUntil[client] = FAR_FUTURE;
		
		Rampage_TriggerAMS[client]=FF2AMS_PushToAMS(client, this_plugin_name, CESTUS_RAMPAGE, "CERA");
	}
	if(boss>=0 && FF2_HasAbility(boss, this_plugin_name, TIMESTOP))
	{
		TimeStop_TriggerAMS[client]=FF2AMS_PushToAMS(client, this_plugin_name, TIMESTOP, "TIME");
	}
	
	if(boss>=0 && FF2_HasAbility(boss, this_plugin_name, "king_bombomb"))
	{
		PrecacheSound(MinionExplode);
		Bombs_AddHooks();
		
		Bombombs_TriggerAMS[client]=FF2AMS_PushToAMS(client, this_plugin_name, "king_bombomb", "BOMB");
	}
		
	if(boss>=0 && FF2_HasAbility(boss, this_plugin_name, RAGESENTRYHACK))
	{
		SentryHack_TriggerAMS[client]=FF2AMS_PushToAMS(client, this_plugin_name, RAGESENTRYHACK, "RSHK");
		
		int entity = SpawnWeapon(client, "tf_weapon_builder", 28, 101, 5, "391 ; 2 ; 287 ; 0.5"); // Builder
		SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
		SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
		SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
		SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
	}
		
	if(boss>=0 && FF2_HasAbility(boss, this_plugin_name, GRAND_CROSS))
	{	
		GrandCross_ActiveThisRound = true;
		GrandCross_CanUse[client] = true;
		GrandCross_ExecuteRageAt[client] = FAR_FUTURE;
		GrandCross_RemoveGodModeAt[client] = FAR_FUTURE;
		GrandCross_RemoveIgniteAt[client] = FAR_FUTURE;
		GrandCross_BeginShockwaveAt[client] = FAR_FUTURE;
		GrandCross_AnimateShockwaveAt[client] = FAR_FUTURE;
		
		GrandCross_TriggerAMS[client]=FF2AMS_PushToAMS(client, this_plugin_name, GRAND_CROSS, "GRCR");
			
		char str[MAX_SOUND_FILE_LENGTH];
		FF2_GetAbilityArgumentString(boss, this_plugin_name, GRAND_CROSS, 3, str, MAX_SOUND_FILE_LENGTH);
		if (strlen(str) == 6)
			GrandCross_EffectColor[client] = ParseColor(str);
		else
		{
			GrandCross_EffectColor[client] = 0xe0e0e0;
		}
		GrandCross_FrameTotal[client] = FF2_GetAbilityArgument(boss, this_plugin_name, GRAND_CROSS, 4);
			
		ReadModelToInt(boss, GRAND_CROSS, 15); // precache
	}
}

public void Event_RoundEnd(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	Countdown_tick = FAR_FUTURE;
	KillFog(HorrorFog);
	CreateTimer(2.0, Remove_Overlay, _, TIMER_FLAG_NO_MAPCHANGE);
	Bombs_RemoveHooks();
	rageison = false;
	GrandCross_BlockingAllInput = false;
	
	if (RPTA_ActiveThisRound)
	{
		RPTA_ActiveThisRound = false;
		UnhookEntityOutput("item_healthkit_small", "OnPlayerTouch", RPTA_ItemPickup);
		UnhookEntityOutput("item_healthkit_medium", "OnPlayerTouch", RPTA_ItemPickup);
		UnhookEntityOutput("item_healthkit_large", "OnPlayerTouch", RPTA_ItemPickup);
		UnhookEntityOutput("item_ammopack_small", "OnPlayerTouch", RPTA_ItemPickup);
	}
	
	for(int client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			SDKUnhook(client, SDKHook_PreThink, Victim_Prethink);
			SDKUnhook(client, SDKHook_PreThink, Rampage_PreThink);
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
			VictimSpeed[client]=0.0;
			PreparationSpeed[client]=0.0;
			Rampage_UsingUntil[client] = FAR_FUTURE;
			SentryHack_TriggerAMS[client] = false;
			PickupTraps_TriggerAMS[client] = false;
			Rampage_TriggerAMS[client] = false;
			TimeStop_TriggerAMS[client] = false;
			Bombombs_TriggerAMS[client] = false;
			GrandCross_TriggerAMS[client] = false;
			
			if (GrandCross_ActiveThisRound && GrandCross_CanUse[client])
			{
				// cancel any pre-rage momentum or stored knockback from being frozen
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
				SetEntityMoveType(client, MOVETYPE_WALK);
				if (TF2_IsPlayerInCondition(client, TFCond_Dazed))
					TF2_RemoveCondition(client, TFCond_Dazed);
			
				// allow damage
				SetEntProp(client, Prop_Data, "m_takedamage", 2);
				TF2_RemoveCondition(client, TFCond_Ubercharged);
				TF2_RemoveCondition(client, TFCond_MegaHeal);
			}
		}
		
		if(WinningTimer)
		{
			KillTimer(WinningTimer);
			WinningTimer=INVALID_HANDLE;
		}
		if(StartingTimer)
		{
			KillTimer(StartingTimer);
			StartingTimer=INVALID_HANDLE;
		}
		if(GameOverTimer)
		{
			KillTimer(GameOverTimer);
			GameOverTimer=INVALID_HANDLE;
		}
		if(OutlineBossTimer)
		{
			KillTimer(OutlineBossTimer);
			OutlineBossTimer=INVALID_HANDLE;
		}
		if(PainisRageTimer)
		{
			KillTimer(PainisRageTimer);
			PainisRageTimer=INVALID_HANDLE;
		}
	}
	HorrorFog=-1;
}


public void OnGameFrame() // Moving some stuff here and there
{
	if(!FF2_IsFF2Enabled())
		return;

	if (FF2_HasAbility(0, this_plugin_name, HORROR))
	{
		Horror_Tick(GetEngineTime());
	}
	
	if (RPTA_ActiveThisRound)
	{
		RPTA_Tick(GetEngineTime());
	}
	
	if (GrandCross_ActiveThisRound)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (!IsValidClient(clientIdx) || GetClientTeam(clientIdx) != FF2_GetBossTeam())
				continue;
				
			if (GrandCross_CanUse[clientIdx])
				GrandCross_Tick(clientIdx, GetEngineTime());
		}
	}
}

public void Horror_Tick(float gameTime)
{
	if(gameTime>=Countdown_tick)
	{
		if(FF2_GetRoundState()!=1)
		{
			Countdown_tick=FAR_FUTURE;
			return;
		}
	
		for(int clientIdx=1;clientIdx<=MaxClients;clientIdx++)
		{
			if(!IsValidClient(clientIdx))
				continue;
			
			char waveTime[6];
			if(startTime/60>9)
			{
				IntToString(startTime/60, waveTime, sizeof(waveTime));
			}	
			else
			{
				Format(waveTime, sizeof(waveTime), "0%i", startTime/60);
			}
	
			if(startTime%60>9)
			{
				Format(waveTime, sizeof(waveTime), "%s:%i", waveTime, startTime%60);
			}	
			else
			{
				Format(waveTime, sizeof(waveTime), "%s:0%i", waveTime, startTime%60);
			}
			
			char countdown[PLATFORM_MAX_PATH];
			SetHudTextParams(-1.0, 0.25, 1.1, startTime<=30 ? 255 : 0, startTime>10 ? 255 : 0, 0, 255);
			Format(countdown,sizeof(countdown), Horror_Counter, waveTime);
			ShowSyncHudText(clientIdx, HorrorHUD, countdown);
		}
	
		switch(startTime)
		{
			case 0:
			{
				Countdown_tick = FAR_FUTURE;
				return;
			}
		}
		startTime--;
		Countdown_tick=GetEngineTime()+1.0;
	}
}

public Action NoWhere_ToRun(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i) && GetClientTeam(i)!=FF2_GetBossTeam())
		{
			TF2_RemoveAllWeapons(i);
			
			SpawnWeapon(i, "tf_weapon_shovel", 954, 100, 5, "1 ; 0.0 ; 49 ; 1", false, true);
			
			SDKHook(i, SDKHook_PreThink, Victim_Prethink);
			VictimSpeed[i]=120.0; // Victim Move Speed
			StartingTimer=INVALID_HANDLE;
		}
	}
	return Plugin_Continue;
}

public void Victim_Prethink(int client)
{
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", VictimSpeed[client]);
}

public Action Victorious_RedTeam(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i) && GetClientTeam(i)!=FF2_GetBossTeam() && mysteriousmode == 1)
		{
			CreateTimer(0.5, Winners, GetClientSerial(i));
		}
		WinningTimer=INVALID_HANDLE;
		KillFog(HorrorFog);
		HorrorFog=-1;
		VictimSpeed[i]=0.0;
		SDKUnhook(i, SDKHook_PreThink, Victim_Prethink);
	}
}

public Action Winners(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	TF2_RemoveAllWeapons(client);
			
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Scout:
			SpawnWeapon(client, "tf_weapon_bat", 452, 666, 9, "2 ; 3.0 ; 6 ; 0.5 ; 250 ; 100 ; 38 ; 1 ; 279 ; 999 ; 275 ; 1 ; 149 ; 666 ; 252 ; 0.4 ; 206 ; 0.0 ; 75 ; 2.0", false, true);
		case TFClass_Soldier:
			SpawnWeapon(client, "tf_weapon_katana", 357, 666, 9, "2 ; 3.0 ; 6 ; 0.5 ; 235 ; 10 ; 115 ; 10 ; 252 ; 0.3 ; 206 ; 0.0 ; 75 ; 2.0", false, true);
		case TFClass_Pyro:
			SpawnWeapon(client, "tf_weapon_fireaxe", 38, 666, 9, "2 ; 3.0 ; 6 ; 0.5 ; 206 ; 0.0 ; 252 ; 0.3 ; 208 ; 1 ; 71 ; 10.0 ; 73 ; 10.0 ; 75 ; 2.0", false, true);
		case TFClass_DemoMan:
			SpawnWeapon(client, "tf_weapon_sword", 172, 666, 9, "2 ; 3.0 ; 6 ; 0.5 ; 206 ; 0.0 ; 252 ; 0.35 ; 75 ; 2.0 ; 781 ; 1", false, true);
		case TFClass_Heavy:
			SpawnWeapon(client, "tf_weapon_fists", 310, 666, 9, "2 ; 3.0 ; 6 ; 0.5 ; 206 ; 0.0 ; 252 ; 0.1 ; 75 ; 2.0", false, true);
		case TFClass_Engineer:
			SpawnWeapon(client, "tf_weapon_robot_arm", 142, 666, 9, "2 ; 3.0 ; 6 ; 0.5 ; 206 ; 0.0 ; 252 ; 0.6 ; 75 ; 2.0 ; 124 ; 1 ; 287 ; 5.0 ; 343 ; 4.0 ; 344 ; 5.0 ; 351 ; 10 ; 80 ; 999", false, true);
		case TFClass_Medic:
			SpawnWeapon(client, "tf_weapon_bonesaw", 37, 666, 9, "2 ; 3.0 ; 6 ; 0.5 ; 206 ; 0.0 ; 252 ; 0.5 ; 75 ; 2.0", false, true);
		case TFClass_Sniper:
			SpawnWeapon(client, "tf_weapon_club", 401, 666, 9, "2 ; 3.0 ; 6 ; 0.5 ; 206 ; 0.0 ; 252 ; 0.5 ; 75 ; 2.0", false, true);
		case TFClass_Spy:
			SpawnWeapon(client, "tf_weapon_knife", 356, 666, 9, "2 ; 3.0 ; 6 ; 0.1 ; 206 ; 0.0 ; 252 ; 0.7 ; 75 ; 2.0", false, true);
	}
	return Plugin_Continue;
}


public Action preparation(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i) && GetClientTeam(i)!=FF2_GetBossTeam())
		{
			SDKHook(i, SDKHook_PreThink, Preparation_Prethink);
			PreparationSpeed[i]=295.0; // Victim Move Speed
			CreateTimer(66.0, preparation_over);
		}
	}
	return Plugin_Continue;
}

public void Preparation_Prethink(int client)
{
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", PreparationSpeed[client]);
}

public Action preparation_over(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		KillFog(HorrorFog);
		HorrorFog=-1;
		PreparationSpeed[i]=0.0;
		SDKUnhook(i, SDKHook_PreThink, Preparation_Prethink);
	}
}

public Action MakeEngiesWeak(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i) && GetClientTeam(i)!=FF2_GetBossTeam() && TF2_GetPlayerClass(i)==TFClass_Engineer)
		{
			for(int slot=2;slot<7;slot++)
			{
				TF2_RemoveWeaponSlot(i, slot);
			}
			SpawnWeapon(i, "tf_weapon_wrench", 197, 5, 10, "93 ; 0.5");
			SpawnWeapon(i, "tf_weapon_pda_engineer_build", 737, 5, 10, "");
			SpawnWeapon(i, "tf_weapon_pda_engineer_destroy", 26, 5, 10, "");
			
			int entity = SpawnWeapon(i, "tf_weapon_builder", 28, 101, 5, "345 ; 0.25 ; 344 ; 0.25"); // Builder
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
		}
	}
	return Plugin_Continue;
}
public Action GameOver_Mercenaries(Handle timer)
{
	for(int target = 1; target <= MaxClients; target++)
	{
		if (IsValidClient(target) && GetClientTeam(target)!=FF2_GetBossTeam())
		{
			ForcePlayerSuicide(target);
		}
		GameOverTimer=INVALID_HANDLE;
		KillFog(HorrorFog);
		HorrorFog=-1;
	}
	return Plugin_Continue;
}
public Action OutlineTheBoss(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i) && GetClientTeam(i) == FF2_GetBossTeam() && FF2_GetBossIndex(i)!=-1)
		{
			SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1);
		}
	}
	OutlineBossTimer=INVALID_HANDLE;
	return Plugin_Continue;
}


int StartHorrorFog(int fogblend, int fogcolor[3], int fogcolor2[3], float fogstart=64.0, float fogend=384.0, float fogdensity=1.0)
{
	int iFog = CreateEntityByName("env_fog_controller");

	char fogcolors[3][16];
	IntToString(fogblend, fogcolors[0], sizeof(fogcolors[]));
	Format(fogcolors[1], sizeof(fogcolors[]), "%i %i %i", fogcolor[0], fogcolor[1], fogcolor[2]);
	Format(fogcolors[2], sizeof(fogcolors[]), "%i %i %i", fogcolor2[0], fogcolor2[1], fogcolor2[2]);
	if(IsValidEntity(iFog)) 
	{
        DispatchKeyValue(iFog, "targetname", "MyFog");
        DispatchKeyValue(iFog, "fogenable", "1");
        DispatchKeyValue(iFog, "spawnflags", "1");
        DispatchKeyValue(iFog, "fogblend", fogcolors[0]);
        DispatchKeyValue(iFog, "fogcolor", fogcolors[1]);
        DispatchKeyValue(iFog, "fogcolor2", fogcolors[2]);
        DispatchKeyValueFloat(iFog, "fogstart", fogstart);
        DispatchKeyValueFloat(iFog, "fogend", fogend);
        DispatchKeyValueFloat(iFog, "fogmaxdensity", fogdensity);
        DispatchSpawn(iFog);
        
        AcceptEntityInput(iFog, "TurnOn");
	}
	return iFog;
}

stock void KillFog(int entity)
{
	if (IsValidEntity(entity))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SetVariantString("");
				AcceptEntityInput(i, "SetFogController");
			}
		}
		AcceptEntityInput(entity, "Kill");
		entity=-1;
	}
}

public Action Remove_Overlay(Handle timer)
{
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
	for(int target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam())
		{
			ClientCommand(target, "r_screenoverlay \"\"");
		}
	}
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
	return Plugin_Continue;
}


public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int action)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue; // Because some FF2 forks still allow RAGE to be activated when the round is over....
	
	int client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!strcmp(ability_name,"king_bombomb"))
	{
		if(!LibraryExists("FF2AMS")) // Fail state?
		{
			Bombombs_TriggerAMS[client]=false;
		}
		
		if(!Bombombs_TriggerAMS[client])
			BOMB_Invoke(client, -1);
	}
	else if(!strcmp(ability_name,RAGESENTRYHACK))
	{
		if(!LibraryExists("FF2AMS")) // Fail state?
		{
			SentryHack_TriggerAMS[client]=false;
		}
		
		if(!SentryHack_TriggerAMS[client])
			RSHK_Invoke(client, -1);
	}
	else if(!strcmp(ability_name,RPTA_STRING))
	{
		if(!LibraryExists("FF2AMS")) // Fail state?
		{
			PickupTraps_TriggerAMS[client]=false;
		}
		
		if(!PickupTraps_TriggerAMS[client])
			RPTA_Invoke(client, -1);
	}
	else if(!strcmp(ability_name,CESTUS_RAMPAGE))
	{
		if(!LibraryExists("FF2AMS")) // Fail state?
		{
			Rampage_TriggerAMS[client]=false;
		}
		
		if(!Rampage_TriggerAMS[client])
			CERA_Invoke(client, -1);
	}
	else if(!strcmp(ability_name,TIMESTOP))
	{
		if(!LibraryExists("FF2AMS")) // Fail state?
		{
			TimeStop_TriggerAMS[client]=false;
		}
		
		if(!TimeStop_TriggerAMS[client])
			TIME_Invoke(client, -1);
	}
	else if(!strcmp(ability_name,GRAND_CROSS))
	{
		if(!LibraryExists("FF2AMS")) // Fail state?
		{
			GrandCross_TriggerAMS[client]=false;
		}
		
		if(!GrandCross_TriggerAMS[client])
			GRCR_Invoke(client, -1);
	}
	
	else if(!strcmp(ability_name,"painis_rage"))
	{
		RageDuration = FF2_GetAbilityArgumentFloat(boss, this_plugin_name,"painis_rage", 1);
		rageison = true;
		PainisRageTimer = CreateTimer(RageDuration, RageIsOver);
	}
	return Plugin_Continue;
}
public Action RageIsOver(Handle timer)
{
	rageison = false;
	PainisRageTimer = INVALID_HANDLE;
	return Plugin_Continue;
}


public AMSResult BOMB_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void BOMB_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	
	minionnumber=FF2_GetAbilityArgument(boss,this_plugin_name,"king_bombomb", 1);	// How many Minions?
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "king_bombomb", 2, bombombmodel, sizeof(bombombmodel)); // Human or custom model?
	class=FF2_GetAbilityArgument(boss, this_plugin_name, "king_bombomb", 3); // class name, if changing
	wearables=FF2_GetAbilityArgument(boss, this_plugin_name, "king_bombomb", 4); // wearable
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "king_bombomb", 5, weaponclassname, sizeof(weaponclassname));
	weaponindex=FF2_GetAbilityArgument(boss, this_plugin_name, "king_bombomb", 6);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "king_bombomb", 7, weaponattributes, sizeof(weaponattributes));
	health=FF2_GetAbilityArgument(boss, this_plugin_name, "king_bombomb", 8, 0); // HP
	pickups=FF2_GetAbilityArgument(boss, this_plugin_name, "king_bombomb", 9); // PickupMode?
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "king_bombomb", 10, conditions, sizeof(conditions)); // Conditions
	
	if(Bombombs_TriggerAMS[client])
	{
		char sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_bombomb_minions", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);	
		}
	}
	
	int ii;				
	for (int i=0; i<minionnumber; i++)
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
			}
			ChangeClientTeam(ii,FF2_GetBossTeam());
			TF2_RespawnPlayer(ii);
			SummonerIndex[ii]=boss;
					
			TF2_RemoveAllWeapons(ii);
					
			SpawnWeapon(ii, weaponclassname, weaponindex, 101, 5, weaponattributes);
			
			if(conditions[0]!='\0')
				SetCondition(ii, conditions);
			
			if(wearables)
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
			
			if(class)
			{
				TF2_SetPlayerClass(ii, view_as<TFClassType>(class), _, false);
			}
					
			SetPlayerModel(ii, bombombmodel);	
		}
			
		if(health)
		{
			SetEntProp(ii, Prop_Data, "m_iMaxHealth", health);
			SetEntProp(ii, Prop_Data, "m_iHealth", health);
			SetEntProp(ii, Prop_Send, "m_iHealth", health);
		}
	}
}


stock void SetPlayerModel(int client, char[] model)
{	
	if(!IsModelPrecached(model))
	{
		PrecacheModel(model);
	}
	
	SetVariantString(model);
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
}


public AMSResult RSHK_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void RSHK_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	
	float bossPosition[3], buildingPosition[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", bossPosition);
	
	int building;
	while((building=FindEntityByClassname(building, "obj_sentrygun"))!=-1) // Let's look for sentries to hijack
	{
		GetEntPropVector(building, Prop_Send, "m_vecOrigin", buildingPosition);
		if(GetVectorDistance(bossPosition, buildingPosition)<=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, RAGESENTRYHACK, 1) && GetEntProp(building, Prop_Send, "m_iTeamNum")!=FF2_GetBossTeam())
		{
			int owner;
			if(FF2_GetRoundState()==1 && building>MaxClients && IsValidEntity(building))
			{
				if ((owner = GetEntDataEnt2(building, FindSendPropInfo("CObjectSentrygun", "m_hBuilder"))) != -1)
				{
					SetEntProp(building, Prop_Data, "m_takedamage", 2);
					SetEntProp(building, Prop_Send, "m_bDisabled", 0);
			
					owner=client;
					AcceptEntityInput(building, "SetBuilder", owner);
					SetEntPropEnt(building, Prop_Send, "m_hBuilder", owner);
					SetEntProp(building, Prop_Send, "m_iTeamNum", GetClientTeam(owner));
					SetEntProp(building, Prop_Send, "m_nSkin", GetClientTeam(owner) - 2);
				}
			}
		}
	}
	
	if(SentryHack_TriggerAMS[client])
	{
		char snd[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_sentry_hijack", snd, sizeof(snd), boss))
		{
			EmitSoundToAll(snd, client);
			EmitSoundToAll(snd, client);
		}		
	}
}


public AMSResult RPTA_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void RPTA_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	
	RPTA_Duration[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, RPTA_STRING, 1);
	RPTA_TrapCount[client] = FF2_GetAbilityArgument(boss, this_plugin_name, RPTA_STRING, 2);
	RPTA_TrapHealthNerfAmount[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, RPTA_STRING, 3);
	RPTA_TrapAmmoNerfAmount[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, RPTA_STRING, 4);
	RPTA_TrappedObjectRecolor[client] = FF2_GetAbilityArgument(boss, this_plugin_name, RPTA_STRING, 5);
	RPTA_DispenserHarmDuration[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, RPTA_STRING, 6);
	RPTA_DispenserHarmDamage = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, RPTA_STRING, 7);
	RPTA_DispenserHarmInterval = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, RPTA_STRING, 8);
	
	RPTAT_TrapsNeverExpire = (RPTA_Duration[client] <= 0.0);
	
	if(PickupTraps_TriggerAMS[client])
	{
		char snd[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_pickup_trap", snd, sizeof(snd), boss))
		{
			EmitSoundToAll(snd, client);
			EmitSoundToAll(snd, client);
		}		
	}
	
	int firstAvailable = 0;
	for (int derp = 0; derp < RPTA_TrapCount[client]; derp++)
	{
		// find first available
		for (; firstAvailable <= MAX_TRAPS; firstAvailable++)
		{
			if (firstAvailable == MAX_TRAPS)
				break;
			if (RPTAT_EntRef[firstAvailable] == INVALID_ENTREF)
				break;
		}
		
		// max reached
		if (firstAvailable == MAX_TRAPS)
			break;
			
		// iterate through potential entities for trapping...
		static potentials[200];
		int validCount = 0;
		static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
		for (int pass = 0; pass < 4; pass++)
		{
			int entity = -1;
			if (pass == 0)
				classname = "item_ammopack_small";
			else if (pass == 1)
				classname = "item_healthkit_small";
			else if (pass == 2)
				classname = "item_healthkit_medium";
			else if (pass == 3)
				classname = "item_healthkit_large";

			while ((entity = FindEntityByClassname(entity, classname)) != -1)
			{
				bool tryNextObject = false;
				for (int i = 0; i < MAX_TRAPS; i++)
				{
					if (RPTAT_EntRef[i] != INVALID_ENTREF && EntRefToEntIndex(RPTAT_EntRef[i]) == entity)
					{
						tryNextObject = true;
						break;
					}
					else if (RPTAT_EntRef[i] == INVALID_ENTREF)
						break; // we reached the end, it's the whole point of me maintaining the list...
				}
				
				if (tryNextObject)
					continue;
					
				potentials[validCount] = entity;
				validCount++;
			}
		}
		
		// are we out of packs to trap?
		if (validCount == 0)
		{
			break;
		}
		
		// trap our object
		int trappedObject = potentials[GetRandomInt(0, validCount - 1)];
		SetEntityRenderMode(trappedObject, RENDER_TRANSCOLOR);
		SetEntityRenderColor(trappedObject, GetR(RPTA_TrappedObjectRecolor[client]), GetG(RPTA_TrappedObjectRecolor[client]), GetB(RPTA_TrappedObjectRecolor[client]), 255);
		RPTAT_EntRef[firstAvailable] = EntIndexToEntRef(trappedObject);
		RPTAT_Trapper[firstAvailable] = client;
		RPTAT_TrappedUntil[firstAvailable] = GetEngineTime() + RPTA_Duration[client];
	}

	// dispenser harm
	if (RPTA_DispenserHarmDuration[client] > 0.0)
	{
		RPTA_DispensersAreHarmful = true;
		RPTA_DispensersHarmUntil = GetEngineTime() + RPTA_DispenserHarmDuration[client];
		RPTA_DispenserCheckAt = GetEngineTime() + RPTA_DispenserHarmInterval;
	}
}

public void RPTA_ItemPickup(const char[] output, int caller, int victim, float delay)
{
	if (!IsValidClient(victim) || GetClientTeam(victim) == FF2_GetBossTeam())
		return;
		
	// is this item trapped?
	for (int i = 0; i < MAX_TRAPS; i++)
	{
		if (RPTAT_EntRef[i] == INVALID_ENTREF)
			continue;
		else if (!IsValidClient(RPTAT_Trapper[i]))
			continue;
			
		if (EntRefToEntIndex(RPTAT_EntRef[i]) == caller)
		{
			// before any of this, change the color back...
			SetEntityRenderColor(caller, 255, 255, 255, 255);
		
			static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
			GetEntityClassname(caller, classname, sizeof(classname));
			if (!strcmp(classname, "item_ammopack_small"))
			{
				float ammoFactor = 1.0 - RPTA_TrapAmmoNerfAmount[RPTAT_Trapper[i]];
				for (int slot = 0; slot < 2; slot++)
				{
					int weapon = GetPlayerWeaponSlot(victim, slot);
					if (IsValidEntity(weapon))
					{
						int offset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1);
						if (offset < 0)
							continue;
							
						if (GetEntProp(victim, Prop_Send, "m_iAmmo", 4, offset) > 1)
							SetEntProp(victim, Prop_Send, "m_iAmmo", RoundFloat(GetEntProp(victim, Prop_Send, "m_iAmmo", 4, offset) * ammoFactor), 4, offset);
						if (GetEntProp(weapon, Prop_Send, "m_iClip1") > 1 && GetEntProp(weapon, Prop_Send, "m_iClip1") < 128)
							SetEntProp(weapon, Prop_Send, "m_iClip1", RoundFloat(GetEntProp(weapon, Prop_Send, "m_iClip1") * ammoFactor));
						//SetEntProp(weapon, Prop_Send, "m_iClip2", RoundFloat(GetEntProp(weapon, Prop_Send, "m_iClip2") * ammoFactor));
					}
				}
				
				// if it's an engineer, drain metal
				if (TF2_GetPlayerClass(victim) == TFClass_Engineer)
				{
					int metalOffset = FindDataMapInfo(victim, "m_iAmmo") + (3 * 4);
					SetEntData(victim, metalOffset, RoundFloat(GetEntData(victim, metalOffset, 4) * ammoFactor), 4);
				}
			}
			else
			{
				float hpDrain = 0.2;
				if (!strcmp(classname, "item_healthkit_medium"))
					hpDrain = 0.5;
				else if (!strcmp(classname, "item_healthkit_large"))
					hpDrain = 1.0;
				hpDrain *= RPTA_TrapHealthNerfAmount[RPTAT_Trapper[i]];
					
				float damage = ((float(GetEntProp(victim, Prop_Data, "m_iMaxHealth")) * hpDrain) / 3.0) + 1.0;
				damage = fixDamageForFF2(damage);
				FullyHookedDamage(victim, RPTAT_Trapper[i], RPTAT_Trapper[i], damage, DMG_GENERIC | DMG_CRIT | DMG_PREVENT_PHYSICS_FORCE, -1);
			}
			
			// permanently remove the resource
			AcceptEntityInput(caller, "kill");
			
			RPTA_RemoveObject(i);
			break;
		}
	}
}

public void RPTA_RemoveObject(int index)
{
	for (int i = index; i < MAX_TRAPS - 1; i++)
	{
		RPTAT_EntRef[i] = RPTAT_EntRef[i + 1];
		RPTAT_Trapper[i] = RPTAT_Trapper[i + 1];
		RPTAT_TrappedUntil[i] = RPTAT_TrappedUntil[i + 1];
	}
	
	RPTAT_EntRef[MAX_TRAPS - 1] = INVALID_ENTREF;
}

public void RPTA_Tick(float curTime)
{
	// check all players being healed and damage them if a dispenser's healing them
	if (RPTA_DispensersAreHarmful)
	{
		if (curTime >= RPTA_DispensersHarmUntil)
		{
			RPTA_DispensersAreHarmful = false;
		
			// remove recoloring on dispensers
			int dispenser = -1;
			while ((dispenser = FindEntityByClassname(dispenser, "obj_dispenser")) != -1)
			{
				SetEntityRenderMode(dispenser, RENDER_TRANSCOLOR);
				SetEntityRenderColor(dispenser, 255, 255, 255, 255);
			}
		}
		else if (curTime >= RPTA_DispenserCheckAt)
		{
			RPTA_DispenserCheckAt += RPTA_DispenserHarmInterval;
		
			// enforce recoloring of dispensers
			int dispenser = -1;
			while ((dispenser = FindEntityByClassname(dispenser, "obj_dispenser")) != -1)
			{
				SetEntityRenderMode(dispenser, RENDER_TRANSCOLOR);
				SetEntityRenderColor(dispenser, 0, 0, 0, 255);
			}

			static medicHealCount[33];
			for (int victim = 1; victim < MaxClients; victim++)
				medicHealCount[victim] = 0;
			for (int medic = 1; medic < MaxClients; medic++)
			{
				if (!IsValidClient(medic) || GetClientTeam(medic) == FF2_GetBossTeam())
					continue;
				else if (TF2_GetPlayerClass(medic) != TFClass_Medic)
					continue;

				int medigun = GetPlayerWeaponSlot(medic, TFWeaponSlot_Secondary);
				if (IsValidEntity(medigun) && IsInstanceOf(medigun, "tf_weapon_medigun"))
				{
					int partner = GetEntProp(medigun, Prop_Send, "m_hHealingTarget") & 0x3ff;
					if (IsValidClient(partner))
						medicHealCount[partner]++;
				}
			}

			int attacker = FindRandomPlayer(true);
			if (IsValidClient(attacker)) for (int victim = 1; victim < MaxClients; victim++)
			{
				if (!IsValidClient(victim) || GetClientTeam(victim) == FF2_GetBossTeam())
					continue;

				int stacks = GetEntProp(victim, Prop_Send, "m_nNumHealers") - medicHealCount[victim];
				if (stacks > 0)
				{
					QuietDamage(victim, attacker, attacker, RPTA_DispenserHarmDamage * stacks, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
				}
			}
		}
	}

	if (RPTAT_TrapsNeverExpire)
		return;
		
	for (int i = MAX_TRAPS - 1; i >= 0; i--)
	{
		if (RPTAT_EntRef[i] != INVALID_ENTREF && curTime >= RPTAT_TrappedUntil[i])
			RPTA_RemoveObject(i);
	}
}


public AMSResult CERA_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void CERA_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	
	Rampage_Duration[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, CESTUS_RAMPAGE, 1);
	Rampage_Speed[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, CESTUS_RAMPAGE, 11);
	Rampage_TempClass[client] = view_as<TFClassType>(FF2_GetAbilityArgument(boss, this_plugin_name, CESTUS_RAMPAGE, 12));
			
	if(Rampage_TriggerAMS[client])
	{
		char sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_cestus_rampage", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);	
		}
	}
	
	if (Rampage_UsingUntil[client] == FAR_FUTURE) // in case of ragespam
	{
		Rampage_OriginalClass[client] = TF2_GetPlayerClass(client);
		if (Rampage_TempClass[client] > TFClass_Unknown && Rampage_TempClass[client] != Rampage_OriginalClass[client])
			TF2_SetPlayerClass(client, Rampage_TempClass[client]);
		Rampage_SwapWeapon(client, true);
	}
	
	Rampage_UsingUntil[client] = GetEngineTime() + Rampage_Duration[client];
	SDKHook(client, SDKHook_PreThink, Rampage_PreThink);
}

public void Rampage_SwapWeapon(int client, bool isRage)
{
	int boss = FF2_GetBossIndex(client);
	if (boss < 0)
		return;
		
	static char weaponName[MAX_WEAPON_NAME_LENGTH];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, CESTUS_RAMPAGE, (isRage ? 6 : 2), weaponName, MAX_WEAPON_NAME_LENGTH);
	int weaponIdx = FF2_GetAbilityArgument(boss, this_plugin_name, CESTUS_RAMPAGE, (isRage ? 7 : 3));
	static char weaponArgs[MAX_WEAPON_ARG_LENGTH];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, CESTUS_RAMPAGE, (isRage ? 8 : 4), weaponArgs, MAX_WEAPON_ARG_LENGTH);
	int weaponVisibility = FF2_GetAbilityArgument(boss, this_plugin_name, CESTUS_RAMPAGE, (isRage ? 9 : 5));
	int slot = FF2_GetAbilityArgument(boss, this_plugin_name, CESTUS_RAMPAGE, 10);
	
	TF2_RemoveWeaponSlot(client, slot);
	int weapon = SpawnWeapon(client, weaponName, weaponIdx, 101, 5, weaponArgs, weaponVisibility);
	if (IsValidEntity(weapon))
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
}

public void Rampage_PreThink(int client)
{
	RampageTick(client, GetEngineTime());
}
public void RampageTick(int client, float gameTime)
{
	if (Rampage_UsingUntil[client] != FAR_FUTURE)
	{
		if (gameTime >= Rampage_UsingUntil[client])
		{
			Rampage_UsingUntil[client] = FAR_FUTURE;
			if (TF2_GetPlayerClass(client) != Rampage_OriginalClass[client])
				TF2_SetPlayerClass(client, Rampage_OriginalClass[client]);
			Rampage_SwapWeapon(client, false);
			SDKUnhook(client, SDKHook_PreThink, Rampage_PreThink);
		}
		else
			SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", Rampage_Speed[client]);
	}
}


public AMSResult TIME_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void TIME_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	float bossPosition[3], targetPosition[3];
	
	float Timestop_Range=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, TIMESTOP, 1);
	float Timestop_Duration=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, TIMESTOP, 2);
	
	if(TimeStop_TriggerAMS[client])
	{
		char sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_time_stop", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);	
		}
	}
	
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", bossPosition);
	for(int target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam())
		{
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPosition);
			if(!TF2_IsPlayerInCondition(target, TFCond_Ubercharged) && (GetVectorDistance(bossPosition, targetPosition)<=Timestop_Range))
			{
				TF2_StunPlayer(target, Timestop_Duration, 0.0, TF_STUNFLAG_BONKSTUCK, client);
			}
		}
	}
}

public AMSResult GRCR_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void GRCR_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	
	if(GrandCross_TriggerAMS[client])
	{
		char sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_grand_cross_begin", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);	
		}
	}
	
	Rage_GrandCross(client);
	Rage_GrandCrossEffects(client);
}

/**
 * Regeneration Shockwave
 */
public bool TraceWallsOnly(int entity, int contentsMask)
{
	return false;
}

int IgniteNextNGibs = 0;
float IgniteGibsDuration = 0.0;

#define BEAM_TOP 0
#define BEAM_LEFT 1
#define BEAM_RIGHT 2
#define BEAM_COUNT 3
float ARS_BossOrigins[MAX_PLAYERS_ARRAY][3];
float ARS_BeamTargetPoints[MAX_PLAYERS_ARRAY][BEAM_COUNT][3];
float ARS_StoredEyeAngles[MAX_PLAYERS_ARRAY][3];
#define ARM_BEAM_LENGTH 700.0
#define TOP_BEAM_LENGTH 1250.0
#define BEAM_WIDTH_MODIFIER 1.28
#define BEAM_FREQUENCY 0.18
public void AnimateGrandCross(int clientIdx)
{
	// get animation percentage, luckily it's a pretty simple job, except for the halo
	float animationPercentage = ((GrandCross_AnimTickCount[clientIdx] + 0.5) * 100.0) / GrandCross_FrameTotal[clientIdx];
	
	// store the boss origin vector and beam points (for consistency) if this is frame 0
	if (GrandCross_AnimTickCount[clientIdx] == 0)
	{
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", ARS_BossOrigins[clientIdx]);
		ARS_BossOrigins[clientIdx][2] += 50; // set it a bit higher, but still lower than eye level
		ARS_StoredEyeAngles[clientIdx][0] = 0.0; // don't care how user is looking up/down
		
		// top is easy
		ARS_BeamTargetPoints[clientIdx][BEAM_TOP][0] = ARS_BossOrigins[clientIdx][0];
		ARS_BeamTargetPoints[clientIdx][BEAM_TOP][1] = ARS_BossOrigins[clientIdx][1];
		ARS_BeamTargetPoints[clientIdx][BEAM_TOP][2] = ARS_BossOrigins[clientIdx][2] + TOP_BEAM_LENGTH;
		
		// will need to trace for left and right. just a simple ray trace since the beam does no damage.
		ARS_StoredEyeAngles[clientIdx][1] = fixAngle(ARS_StoredEyeAngles[clientIdx][1] + 90);
		Handle trace = TR_TraceRayFilterEx(ARS_BossOrigins[clientIdx], ARS_StoredEyeAngles[clientIdx], (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
		TR_GetEndPosition(ARS_BeamTargetPoints[clientIdx][BEAM_LEFT], trace);
		CloseHandle(trace);
		constrainDistance(ARS_BossOrigins[clientIdx], ARS_BeamTargetPoints[clientIdx][BEAM_LEFT], GetVectorDistance(ARS_BossOrigins[clientIdx], ARS_BeamTargetPoints[clientIdx][BEAM_LEFT]), ARM_BEAM_LENGTH);

		ARS_StoredEyeAngles[clientIdx][1] = fixAngle(ARS_StoredEyeAngles[clientIdx][1] + 180);
		trace = TR_TraceRayFilterEx(ARS_BossOrigins[clientIdx], ARS_StoredEyeAngles[clientIdx], (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
		TR_GetEndPosition(ARS_BeamTargetPoints[clientIdx][BEAM_RIGHT], trace);
		CloseHandle(trace);
		constrainDistance(ARS_BossOrigins[clientIdx], ARS_BeamTargetPoints[clientIdx][BEAM_RIGHT], GetVectorDistance(ARS_BossOrigins[clientIdx], ARS_BeamTargetPoints[clientIdx][BEAM_RIGHT]), ARM_BEAM_LENGTH);
	}
		
	// get the colors for the beams, which I took straight from dot_beam :P
	int r = GetR(GrandCross_EffectColor[clientIdx]);
	int g = GetG(GrandCross_EffectColor[clientIdx]);
	int b = GetB(GrandCross_EffectColor[clientIdx]);
	int  colorLayer4[4]; SetColorRGBA(colorLayer4, r, g, b, 255);
	int  colorLayer3[4]; SetColorRGBA(colorLayer3,  (((colorLayer4[0] * 7) + (255 * 1)) / 8),
							(((colorLayer4[1] * 7) + (255 * 1)) / 8),
							(((colorLayer4[2] * 7) + (255 * 1)) / 8),
							255);
	int  colorLayer2[4]; SetColorRGBA(colorLayer2,  (((colorLayer4[0] * 6) + (255 * 2)) / 8),
							(((colorLayer4[1] * 6) + (255 * 2)) / 8),
							(((colorLayer4[2] * 6) + (255 * 2)) / 8),
							255);
	int  colorLayer1[4]; SetColorRGBA(colorLayer1,  (((colorLayer4[0] * 5) + (255 * 3)) / 8),
							(((colorLayer4[1] * 5) + (255 * 3)) / 8),
							(((colorLayer4[2] * 5) + (255 * 3)) / 8),
							255);
	int  glowColor[4]; SetColorRGBA(glowColor, r, g, b, 255);
							
	// get the frame-specific target points for the beams
	float beamStarts[BEAM_COUNT][3];
	float beamEnds[BEAM_COUNT][3];
	for (int i = 0; i < BEAM_COUNT; i++)
	{
		beamStarts[i] = ARS_BossOrigins[clientIdx];
		beamEnds[i] = ARS_BeamTargetPoints[clientIdx][i];
	}
	if (animationPercentage < 10.0)
	{
		for (int i = 0; i < BEAM_COUNT; i++)
			constrainDistance(beamStarts[i], beamEnds[i], 10.0, animationPercentage);
	}
	else if (animationPercentage > 90.0)
	{
		for (int i = 0; i < BEAM_COUNT; i++)
			constrainDistance(beamEnds[i], beamStarts[i], 10.0, 100.0 - animationPercentage);
	}
	
	// draw all the beams
	int diameter = 100;
	for (int i = 0; i < BEAM_COUNT; i++)
	{
		TE_SetupBeamPoints(beamStarts[i], beamEnds[i], Beam_Laser, 0, 0, 0, BEAM_FREQUENCY, ClampBeamWidth(0.3 * diameter * BEAM_WIDTH_MODIFIER), ClampBeamWidth(0.3 * diameter * BEAM_WIDTH_MODIFIER), 0, 1.0, colorLayer1, 3);
		TE_SendToAll();
		TE_SetupBeamPoints(beamStarts[i], beamEnds[i], Beam_Laser, 0, 0, 0, BEAM_FREQUENCY, ClampBeamWidth(0.5 * diameter * BEAM_WIDTH_MODIFIER), ClampBeamWidth(0.5 * diameter * BEAM_WIDTH_MODIFIER), 0, 1.0, colorLayer2, 3);
		TE_SendToAll();
		TE_SetupBeamPoints(beamStarts[i], beamEnds[i], Beam_Laser, 0, 0, 0, BEAM_FREQUENCY, ClampBeamWidth(0.8 * diameter * BEAM_WIDTH_MODIFIER), ClampBeamWidth(0.8 * diameter * BEAM_WIDTH_MODIFIER), 0, 1.0, colorLayer3, 3);
		TE_SendToAll();
		TE_SetupBeamPoints(beamStarts[i], beamEnds[i], Beam_Laser, 0, 0, 0, BEAM_FREQUENCY, ClampBeamWidth(diameter * BEAM_WIDTH_MODIFIER), ClampBeamWidth(diameter * BEAM_WIDTH_MODIFIER), 0, 1.0, colorLayer4, 3);
		TE_SendToAll();

		// the glow color is just one static color, since the glow has to be a pair of points
		// the way it was done in IonCannon only allowed a purely vertical glow
		TE_SetupBeamPoints(beamStarts[i], beamEnds[i], Beam_Glow, 0, 0, 0, BEAM_FREQUENCY, ClampBeamWidth(diameter * BEAM_WIDTH_MODIFIER), ClampBeamWidth(diameter * BEAM_WIDTH_MODIFIER), 0, 5.0, glowColor, 0);
		TE_SendToAll();
	}
	
	// draw the halo, only needs to be done first tick
	float duration = GrandCross_FrameTotal[clientIdx] / 10.0;
	if (GrandCross_AnimTickCount[clientIdx] == 0)
	{
		int haloColor1[4]; SetColorRGBA(haloColor1, r, g, b, 255);
		TE_SetupBeamRingPoint(ARS_BossOrigins[clientIdx], 0.0, 2000.0, Beam_Glow, Beam_Halo, 0, 0, duration / 5, 128.0, 10.0, haloColor1, 0, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(ARS_BossOrigins[clientIdx], 0.0, 2333.0, Beam_Glow, Beam_Halo, 0, 0, duration / 4, 92.0, 5.0, haloColor1, 0, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(ARS_BossOrigins[clientIdx], 0.0, 2666.0, Beam_Glow, Beam_Halo, 0, 0, duration / 3, 64.0, 2.0, haloColor1, 0, 0);
		TE_SendToAll();
		TE_SetupBeamRingPoint(ARS_BossOrigins[clientIdx], 0.0, 3000.0, Beam_Glow, Beam_Halo, 0, 0, duration, 48.0, 0.0, haloColor1, 0, 0);
		TE_SendToAll();
	}
	
	// increase tick count, and stuff to do if it's the last frame
	GrandCross_AnimTickCount[clientIdx]++;
	if (GrandCross_AnimTickCount[clientIdx] == GrandCross_FrameTotal[clientIdx])
	{
		int bossIdx = FF2_GetBossIndex(clientIdx);
		
		// cancel any pre-rage momentum or stored knockback from being frozen
		float ZeroVec[3];
		TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, ZeroVec);

		// allow movement and remove invincibility
		SetEntityMoveType(clientIdx, MOVETYPE_WALK);
		float godModeDuration = (bossIdx < 0) ? 0.0 : FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GRAND_CROSS, 13);
		if (godModeDuration <= 0.0)
		{
			SetEntProp(clientIdx, Prop_Data, "m_takedamage", 2);
			TF2_RemoveCondition(clientIdx, TFCond_Ubercharged);
			TF2_RemoveCondition(clientIdx, TFCond_MegaHeal);
		}
		else
			GrandCross_RemoveGodModeAt[clientIdx] = GetEngineTime() + godModeDuration;
			
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed))
			TF2_RemoveCondition(clientIdx, TFCond_Dazed);
		
		// restore all sentries
		int sentryEntity = -1;
		while ((sentryEntity = FindEntityByClassname(sentryEntity, "obj_sentrygun")) != -1)
			SetEntProp(sentryEntity, Prop_Send, "m_bDisabled", 0);
			
		// play the mapwide sound
		char sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_grand_cross_end", sound, sizeof(sound), bossIdx))
		{
			EmitSoundToAll(sound, clientIdx);	
		}

		GrandCross_AnimateShockwaveAt[clientIdx] = FAR_FUTURE;
	}
}
 
public void DoGrandCross(int clientIdx)
{
	int bossIdx = FF2_GetBossIndex(clientIdx);
	GrandCross_AnimTickCount[clientIdx] = 0;
	
	// get all the info we need for knockback and damage
	float earthquakeDuration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GRAND_CROSS, 2);
	float damageRadius = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GRAND_CROSS, 5);
	float knockbackRadius = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GRAND_CROSS, 6);
	char damagePointBlankStr[29];
	char damagePointBlankStrSplit[2][15];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, GRAND_CROSS, 7, damagePointBlankStr, 29);
	ExplodeString(damagePointBlankStr, ",", damagePointBlankStrSplit, 2, 15);
	float damageMin = StringToFloat(damagePointBlankStrSplit[0]);
	float damageMax = StringToFloat(damagePointBlankStrSplit[1]);
	float damagePointBlank = damageMin + ((damageMax - damageMin) * GrandCross_PlayerCount / 31.0);
	float igniteDuration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GRAND_CROSS, 8);
	float knockbackIntensityPointBlank = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GRAND_CROSS, 9);
	float knockbackIntensityMidpoint = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GRAND_CROSS, 10);
	float knockbackIntensityFarpoint = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GRAND_CROSS, 11);
	float minimumZLift = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GRAND_CROSS, 12);
	
	// knock back players first, and then damage them
	float bossOrigin[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
	float mercOrigin[3];
	float currentVelocity[3];
	float knockbackVelocity[3];
	float distance;
	float intensity;
	float diffIntensity;
	float distanceRatio;
	float damage;
	for (int victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (IsValidClient(victim) && GetClientTeam(victim) != FF2_GetBossTeam())
		{
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", mercOrigin);
			distance = GetVectorDistance(bossOrigin, mercOrigin);
			
			// don't waste time on unaffected users
			if (distance > knockbackRadius)
				continue;
				
			// get velocity for our axes
			MakeVectorFromPoints(bossOrigin, mercOrigin, knockbackVelocity);
			NormalizeVector(knockbackVelocity, knockbackVelocity);
			if (knockbackVelocity[2] < minimumZLift)
				knockbackVelocity[2] = minimumZLift;
				
			// get knockback intensity and damage
			if (distance > damageRadius)
			{
				diffIntensity = knockbackIntensityMidpoint - knockbackIntensityFarpoint;
				distanceRatio = 1.0 - ((distance - damageRadius) / (knockbackRadius - damageRadius));
				intensity = (diffIntensity * distanceRatio) + knockbackIntensityFarpoint;
				//PrintToServer("far intensity... %f (%f and %f)", intensity, diffIntensity, distanceRatio);
				damage = 0.0;
			}
			else
			{
				diffIntensity = knockbackIntensityPointBlank - knockbackIntensityMidpoint;
				distanceRatio = 1.0 - (distance / damageRadius);
				intensity = (diffIntensity * distanceRatio) + knockbackIntensityMidpoint;
				//PrintToServer("near intensity... %f (%f and %f)", intensity, diffIntensity, distanceRatio);
				damage = distanceRatio * damagePointBlank;
			}
			
			// determine our final velocity and add it to the player's existing velocity vector
			GetEntPropVector(victim, Prop_Data, "m_vecVelocity", currentVelocity);
			knockbackVelocity[0] = (knockbackVelocity[0] * intensity) + currentVelocity[0];
			knockbackVelocity[1] = (knockbackVelocity[1] * intensity) + currentVelocity[1];
			knockbackVelocity[2] = (knockbackVelocity[2] * intensity) + currentVelocity[2];
			
			// knock the player back!
			TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, knockbackVelocity);
			
			// and damage the player. may create quite the amusing flying ragdoll.
			if (damage > 0.0 && !TF2_IsPlayerInCondition(victim, TFCond_Ubercharged))
			{
				// sarysa 2014-06-17, decided to not ignite spies due to cloak instakill issues
				if (igniteDuration > 0.0 && TF2_GetPlayerClass(victim) != TFClass_Spy)
				{
					TF2_IgnitePlayer(victim, clientIdx);
					GrandCross_RemoveIgniteAt[clientIdx] = GetEngineTime() + igniteDuration; // not an error, remove them all at once so use boss idx
				}
				
				SDKHooks_TakeDamage(victim, clientIdx, clientIdx, damage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
			}
		}
	}
	
	// play the mapwide sound
	char sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_grand_cross_soundeffect", sound, sizeof(sound), clientIdx))
	{
		EmitSoundToAll(sound, bossIdx);	
	}
	
	// shake shake shake, da-da-dah-da-dah-dah, shake shake shake, da-da-dah-da-dah-dah, shake your booteh...
	env_shake(bossOrigin, 120.0, knockbackRadius, earthquakeDuration, 250.0);
	
	// start the looping timer for this shockwave
	GrandCross_AnimateShockwaveAt[clientIdx] = GetEngineTime();
}

public void GrandCross(int clientIdx)
{
	// allow everyone but the hale to move again
	GrandCross_BlockingAllInput = false;
	for (int victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (victim != clientIdx && IsValidClient(victim))
			SetEntityMoveType(victim, MOVETYPE_WALK);
	}

	DoGrandCross(clientIdx);
}

public void GrandCross_Tick(int clientIdx, float curTime)
{
	if (curTime >= GrandCross_RemoveGodModeAt[clientIdx])
	{
		GrandCross_RemoveGodModeAt[clientIdx] = FAR_FUTURE;
		
		SetEntProp(clientIdx, Prop_Data, "m_takedamage", 2);
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_MegaHeal))
			TF2_RemoveCondition(clientIdx, TFCond_MegaHeal);
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_Ubercharged))
			TF2_RemoveCondition(clientIdx, TFCond_Ubercharged);
	}
	
	if (curTime >= GrandCross_RemoveIgniteAt[clientIdx])
	{
		GrandCross_RemoveIgniteAt[clientIdx] = FAR_FUTURE;
		for (int victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (!IsValidClient(victim) || GetClientTeam(victim) == FF2_GetBossTeam())
				continue;
		
			if (TF2_IsPlayerInCondition(victim, TFCond_OnFire))
				TF2_RemoveCondition(victim, TFCond_OnFire);
		}
	}
	
	if (curTime >= GrandCross_BeginShockwaveAt[clientIdx])
	{
		GrandCross_BeginShockwaveAt[clientIdx] = FAR_FUTURE;
		GrandCross(clientIdx);
	}
	
	if (curTime >= GrandCross_AnimateShockwaveAt[clientIdx])
	{
		GrandCross_AnimateShockwaveAt[clientIdx] += 0.1;
		AnimateGrandCross(clientIdx);
	}
	
	if (curTime >= GrandCross_ExecuteRageAt[clientIdx])
	{
		GrandCross_ExecuteRageAt[clientIdx] = FAR_FUTURE;
		DoGrandCrossEffects(clientIdx);
	}
}
 
public void Rage_GrandCross(int clientIdx)
{
	int bossIdx = FF2_GetBossIndex(clientIdx);
	float delay = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GRAND_CROSS, 1);
	
	if (GrandCross_FrameTotal[clientIdx] <= 1)
	{
		return;
	}

	// stun all sentries
	int sentryEntity = -1;
	while ((sentryEntity = FindEntityByClassname(sentryEntity, "obj_sentrygun")) != -1)
		SetEntProp(sentryEntity, Prop_Send, "m_bDisabled", 1);

	// freeze and stun the hale no matter what, but make them immune to damage (due to trains/pits)
	SetEntityMoveType(clientIdx, MOVETYPE_NONE);
	TF2_StunPlayer(clientIdx, 50.0, 0.0, TF_STUNFLAG_BONKSTUCK | TF_STUNFLAG_NOSOUNDOREFFECT);
	SetEntProp(clientIdx, Prop_Data, "m_takedamage", 0);
	TF2_AddCondition(clientIdx, TFCond_Ubercharged, -1.0);
	TF2_AddCondition(clientIdx, TFCond_MegaHeal, -1.0);
	
	// fix a bug with the eye angles changing while stunned
	GetClientEyeAngles(clientIdx, ARS_StoredEyeAngles[clientIdx]);
	
	if (delay > 0.0)
	{
		// freeze all players and store their charges
		for (int victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (victim != clientIdx && IsValidClient(victim))
			{
				SetEntityMoveType(victim, MOVETYPE_NONE);
				
				// medic is the only one that needs to be explicitly checked
				if (TF2_GetPlayerClass(victim) == TFClass_Medic)
				{
					int weapon = GetPlayerWeaponSlot(victim, TFWeaponSlot_Secondary);
					if (IsValidEntity(weapon))
					{
						char classname[MAX_ENTITY_CLASSNAME_LENGTH];
						GetEntityClassname(weapon, classname, sizeof(classname));
						if (!strcmp(classname, "tf_weapon_medigun"))
							GrandCross_Medigun[victim] = GetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel");
					}
				}
				
				// the rest of these, all players have
				GrandCross_Rage[victim] = GetEntPropFloat(victim, Prop_Send, "m_flRageMeter");
				GrandCross_Cloak[victim] = GetEntPropFloat(victim, Prop_Send, "m_flCloakMeter");
				GrandCross_Hype[victim] = GetEntPropFloat(victim, Prop_Send, "m_flHypeMeter");
				GrandCross_Charge[victim] = GetEntPropFloat(victim, Prop_Send, "m_flChargeMeter");
			}
		}

		// block input
		GrandCross_BlockingAllInputUntil = GetEngineTime() + delay + delay; // this is only a sanity timer, intentionally set beyond freeze duration. it'll truly end well before that, when the timer executes.
		GrandCross_BlockingAllInput = true;
		GrandCross_BeginShockwaveAt[clientIdx] = GetEngineTime() + delay;
	}
	else
		DoGrandCross(clientIdx);
}

public Action OnPlayerRunCmd(int clientIdx, int& buttons, int& impulse, 
							float vel[3], float angles[3], int& weapon, 
							int &subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (!IsValidClient(clientIdx))
		return Plugin_Continue;
		
	if (GrandCross_BlockingAllInput)
	{
		if (GrandCross_BlockingAllInputUntil <= GetEngineTime())
			GrandCross_BlockingAllInput = false;
		else
		{
			buttons = 0;
			
			if (IsValidClient(clientIdx))
			{
				// freeze player's meters during the rage
				// medic is the only one that needs to be explicitly checked
				if (TF2_GetPlayerClass(clientIdx) == TFClass_Medic)
				{
					int medigun = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Secondary);
					if (IsValidEntity(medigun))
					{
						char classname[MAX_ENTITY_CLASSNAME_LENGTH];
						GetEntityClassname(medigun, classname, sizeof(classname));
						if (!strcmp(classname, "tf_weapon_medigun"))
							SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", GrandCross_Medigun[clientIdx]);
					}
				}

				// the rest of these, all players have
				SetEntPropFloat(clientIdx, Prop_Send, "m_flRageMeter", GrandCross_Rage[clientIdx]);
				SetEntPropFloat(clientIdx, Prop_Send, "m_flCloakMeter", GrandCross_Cloak[clientIdx]);
				SetEntPropFloat(clientIdx, Prop_Send, "m_flHypeMeter", GrandCross_Hype[clientIdx]);
				SetEntPropFloat(clientIdx, Prop_Send, "m_flChargeMeter", GrandCross_Charge[clientIdx]);
			}
			
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}


/**
 * Flaming Debris
 */
public void ShootFlamingGibs(int flameCount, const char[] modelName, float flameDuration, const float origin[3], float flameDelay, float flameVelocity)
{
	int flamingGibShooter = CreateEntityByName("env_shooter");
	float angles[3] = {0.0, 0.0, 0.0};
	char gibCountStr[3];
	Format(gibCountStr, 3, "%d", flameCount);
	DispatchKeyValue(flamingGibShooter, "m_iGibs", gibCountStr);
	IgniteNextNGibs += flameCount;
	IgniteGibsDuration = flameDuration;
	DispatchKeyValueVector(flamingGibShooter, "gibangles", angles);
	DispatchKeyValueFloat(flamingGibShooter, "delay", flameDelay);
	DispatchKeyValue(flamingGibShooter, "nogibshadows", "1");
	DispatchKeyValueFloat(flamingGibShooter, "m_flVelocity", flameVelocity);
	DispatchKeyValueFloat(flamingGibShooter, "m_flVariance", 179.9);
	DispatchKeyValueFloat(flamingGibShooter, "m_flGibLife", flameDuration + 5.0);
	DispatchKeyValueFloat(flamingGibShooter, "gibgravityscale", 1.0);
	DispatchKeyValue(flamingGibShooter, "shootmodel", modelName);
	DispatchKeyValue(flamingGibShooter, "shootsounds", "-1");
	DispatchKeyValueFloat(flamingGibShooter, "scale", 1.0);
	// may need: m_flGibScale

	TeleportEntity(flamingGibShooter, origin, NULL_VECTOR, NULL_VECTOR);

	AcceptEntityInput(flamingGibShooter, "Shoot", 0);

	CreateTimer(10.0, TimerRemoveEntity, EntIndexToEntRef(flamingGibShooter), TIMER_FLAG_NO_MAPCHANGE); // remove a one-off entity with no significance? timer's fine.
}
 
public void DoGrandCrossEffects(int clientIdx)
{
	int bossIdx = FF2_GetBossIndex(clientIdx);
	if (!IsValidClient(clientIdx))
	{
		return;
	}
	
	if (!FF2_HasAbility(bossIdx, this_plugin_name, GRAND_CROSS))
	{
		return;
	}

	char modelName[MAX_MODEL_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, GRAND_CROSS, 15, modelName, MAX_MODEL_FILE_LENGTH);
	int flameCount = FF2_GetAbilityArgument(bossIdx, this_plugin_name, GRAND_CROSS, 16);
	if (flameCount > 50) // mitigate the risk of running out of entities...not a big issue for between-lives, but could be a problem for standard rage
	{
		flameCount = 50;
	}
	float flameDuration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GRAND_CROSS, 17);
	
	if (strlen(modelName) < 3 || flameCount <= 0 || flameDuration <= 0.0)
	{
		return;
	}
	
	float flameDelay = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GRAND_CROSS, 18);
	float flameVelocity = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GRAND_CROSS, 19);
	
	float bossOrigin[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
	bossOrigin[2] += 50.0;
	
	// shoot the gibs
	ShootFlamingGibs(flameCount, modelName, flameDuration, bossOrigin, flameDelay, flameVelocity);
}

public void Rage_GrandCrossEffects(int bossIdx)
{
	int clientIdx = FF2_GetBossIndex(bossIdx);
	float delay = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, GRAND_CROSS, 14);
	
	if (delay == 0.0)
		DoGrandCrossEffects(bossIdx);
	else
		GrandCross_ExecuteRageAt[clientIdx] = GetEngineTime() + delay;
}


public void OnEntityCreated(int entity, const char[] classname)
{
	// regeneration shockwave, gibs
	if (IgniteNextNGibs > 0 && !strcmp(classname, "gib"))
	{
		if (IsValidEntity(entity))
		{
			IgniteEntity(entity, IgniteGibsDuration);
			IgniteNextNGibs--;
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

stock void Wearable_EquipWearable(int client, int wearable)
{
	static Handle S93SF_equipWearable = INVALID_HANDLE;
	if(!S93SF_equipWearable)
	{
		GameData config= new GameData("equipwearable");
		if(!config)
		{
			LogError("[FF2] EquipWearable gamedata could not be found; make sure /gamedata/equipwearable.txt exists.");
			return;
		}

		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "EquipWearable");
		delete config;
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

stock void SetCondition(int client, const char[] cond) // Sets multi TFConds to a client
{
	char conds[32][32];
	int count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		for (int i = 0; i < count; i+=2)
		{
			TF2_AddCondition(client, view_as<TFCond>(StringToInt(conds[i])), StringToFloat(conds[i+1]));
		}
	}
}


// For King Bombomb
public void Bombs_AddHooks()
{	
	if(!Ishooked)
	{
		Ishooked=true;
	}
	
	AddCommandListener(Bombombs_Detonate, "taunt");
	AddCommandListener(Bombombs_Detonate, "+taunt");
}

public void Bombs_RemoveHooks()
{	
	if(Ishooked)
	{
		RemoveCommandListener(Bombombs_Detonate, "taunt");
		RemoveCommandListener(Bombombs_Detonate, "+taunt");
		Ishooked=false;
	}
}

public Action Bombombs_Detonate(int client, const char[] command, int argc)
{
	if(IsValidMinion(client))
	{
		CreateTimer(2.1, BombombBusting, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public Action BombombBusting(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (!IsValidClient(client)) return Plugin_Handled;
	if (!IsPlayerAlive(client)) return Plugin_Handled;
	int explosion = CreateEntityByName("env_explosion");
	float clientPos[3];
	GetClientAbsOrigin(client, clientPos);
	if (explosion)
	{
		DispatchSpawn(explosion);
		TeleportEntity(explosion, clientPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(explosion, "Explode", -1, -1, 0);
		RemoveEdict(explosion);
	}
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || !IsPlayerAlive(i)) continue;
		float zPos[3];
		GetClientAbsOrigin(i, zPos);
		float Dist = GetVectorDistance(clientPos, zPos);
		if (Dist > 300.0) continue;
		DoDamage(client, i, 2500);
	}
	for (int i = MaxClients + 1; i <= 2048; i++)
	{
		if (!IsValidEntity(i)) continue;
		char cls[64];
		GetEntityClassname(i, cls, sizeof(cls));
		if (!StrEqual(cls, "obj_sentrygun", false) &&
		!StrEqual(cls, "obj_dispenser", false) &&
		!StrEqual(cls, "obj_teleporter", false)) continue;
		float zPos[3];
		GetEntPropVector(i, Prop_Send, "m_vecOrigin", zPos);
		float Dist = GetVectorDistance(clientPos, zPos);
		if (Dist > 300.0) continue;
		SetVariantInt(2500);
		AcceptEntityInput(i, "RemoveHealth");
	}
	EmitSoundToAll(MinionExplode, client);
	AttachParticle(client, "fluidSmokeExpl_ring_mvm");
	DoDamage(client, client, 2500);
	CreateTimer(0.0, Timer_RemoveRagdoll, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

public Action Timer_RemoveRagdoll(Handle timer, any uid)
{
	int client = GetClientOfUserId(uid);
	if (!IsValidClient(client)) return;
	int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if (!IsValidEntity(ragdoll) || ragdoll <= MaxClients) return;
	AcceptEntityInput(ragdoll, "Kill");
}

stock void DoDamage(int client, int target, int amount) // from Goomba Stomp.
{
	int pointHurt = CreateEntityByName("point_hurt");
	if (pointHurt)
	{
		DispatchKeyValue(target, "targetname", "explodeme");
		DispatchKeyValue(pointHurt, "DamageTarget", "explodeme");
		char dmg[15];
		Format(dmg, 15, "%i", amount);
		DispatchKeyValue(pointHurt, "Damage", dmg);
		DispatchKeyValue(pointHurt, "DamageType", "0");

		DispatchSpawn(pointHurt);
		AcceptEntityInput(pointHurt, "Hurt", client);
		DispatchKeyValue(pointHurt, "classname", "point_hurt");
		DispatchKeyValue(target, "targetname", "");
		RemoveEntity(pointHurt);
	}
}

stock bool AttachParticle(int Ent, char[] particleType, bool cache=false) // from L4D Achievement Trophy
{
	int particle = CreateEntityByName("info_particle_system");
	if (!IsValidEntity(particle)) return false;
	char tName[128];
	float f_pos[3];
	if (cache) f_pos[2] -= 3000;
	else
	{
		GetEntPropVector(Ent, Prop_Send, "m_vecOrigin", f_pos);
		f_pos[2] += 60;
	}
	TeleportEntity(particle, f_pos, NULL_VECTOR, NULL_VECTOR);
	Format(tName, sizeof(tName), "target%i", Ent);
	DispatchKeyValue(Ent, "targetname", tName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(tName);
	AcceptEntityInput(particle, "SetParent", particle, particle, 0);
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	CreateTimer(10.0, DeleteParticle, EntIndexToEntRef(particle));
	return true;
}

public Action DeleteParticle(Handle timer, int ref)
{
	int Ent = EntRefToEntIndex(ref);
	if (!IsValidEntity(Ent)) return;
	RemoveEntity(Ent);
	return;
}

stock int GetR(int c) { return abs((c>>16)&0xff); }
stock int GetG(int c) { return abs((c>>8 )&0xff); }
stock int GetB(int c) { return abs((c    )&0xff); }

stock int abs(int x)
{
	return x < 0 ? -x : x;
}

stock int GetRandomDeadPlayer()
{
	int clientCount;
	int[] clients = new int[MaxClients + 1];
	for(int i=1;i<=MaxClients;i++)
	{
		if (IsValidEdict(i) && IsClientConnected(i) && IsClientInGame(i) && !IsPlayerAlive(i) && (GetClientTeam(i) > 1))
		{
			clients[clientCount++] = i;
		}
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

stock void ReadCenterText(int bossIdx, const char[] ability_name, int argInt, char[] centerText)
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, centerText, PLATFORM_MAX_PATH);
	ReplaceString(centerText, PLATFORM_MAX_PATH, "\\n", "\n");
}

stock float fixDamageForFF2(float damage)
{
	if (damage <= 160.0)
		return damage / 3.0;
	return damage;
}

stock void QuietDamage(int victim, int inflictor, int attacker, float damage, int damageType=DMG_GENERIC, int weapon=-1)
{
	int takedamage = GetEntProp(victim, Prop_Data, "m_takedamage");
	SetEntProp(victim, Prop_Data, "m_takedamage", 0);
	SDKHooks_TakeDamage(victim, inflictor, attacker, damage, damageType, weapon);
	SetEntProp(victim, Prop_Data, "m_takedamage", takedamage);
	SDKHooks_TakeDamage(victim, victim, victim, damage, damageType, weapon);
}

stock void FullyHookedDamage(int victim, int inflictor, int attacker, float damage, int damageType=DMG_GENERIC, int weapon=-1, float attackPos[3] = NULL_VECTOR)
{
	static char dmgStr[16];
	IntToString(RoundFloat(damage), dmgStr, sizeof(dmgStr));

	// took this from war3...I hope it doesn't double damage like I've heard old versions do
	int pointHurt = CreateEntityByName("point_hurt");
	if (IsValidEntity(pointHurt))
	{
		DispatchKeyValue(victim, "targetname", "halevictim");
		DispatchKeyValue(pointHurt, "DamageTarget", "halevictim");
		DispatchKeyValue(pointHurt, "Damage", dmgStr);
		DispatchKeyValueFormat(pointHurt, "DamageType", "%d", damageType);

		DispatchSpawn(pointHurt);
		if (!(attackPos[0] == NULL_VECTOR[0] && attackPos[1] == NULL_VECTOR[1] && attackPos[2] == NULL_VECTOR[2]))
		{
			TeleportEntity(pointHurt, attackPos, NULL_VECTOR, NULL_VECTOR);
		}
		else if (IsValidClient(attacker))
		{
			static float attackerOrigin[3];
			GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", attackerOrigin);
			TeleportEntity(pointHurt, attackerOrigin, NULL_VECTOR, NULL_VECTOR);
		}
		AcceptEntityInput(pointHurt, "Hurt", attacker);
		DispatchKeyValue(pointHurt, "classname", "point_hurt");
		DispatchKeyValue(victim, "targetname", "noonespecial");
		DeleteParticle(INVALID_HANDLE, EntIndexToEntRef(pointHurt));
	}
}

stock int FindRandomPlayer(bool isBossTeam, float position[3] = NULL_VECTOR, float maxDistance = 0.0, bool anyTeam = false, bool deadOnly = false)
{
	return FindRandomPlayerBlacklist(isBossTeam, NULL_BLACKLIST, position, maxDistance, anyTeam, deadOnly);
}

stock int FindRandomPlayerBlacklist(bool isBossTeam, const bool blacklist[MAX_PLAYERS_ARRAY], float position[3] = NULL_VECTOR, float maxDistance = 0.0, bool anyTeam = false, bool deadOnly = false)
{
	int player = -1;

	// first, get a player count for the team we care about
	int playerCount = 0;
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!deadOnly && !IsValidClient(clientIdx))
			continue;
		else if (deadOnly)
		{
			if (!IsClientInGame(clientIdx) || IsValidClient(clientIdx))
				continue;
		}
			
		if (!deadOnly && maxDistance > 0.0 && !IsPlayerInRange(clientIdx, position, maxDistance))
			continue;
			
		if (blacklist[clientIdx])
			continue;

		// fixed to not grab people in spectator, since we can now include the dead
		bool valid = anyTeam && (GetClientTeam(clientIdx) == FF2_GetBossTeam() || GetClientTeam(clientIdx) != FF2_GetBossTeam());
		if (!valid)
			valid = (isBossTeam && GetClientTeam(clientIdx) == FF2_GetBossTeam()) || (!isBossTeam && GetClientTeam(clientIdx) != FF2_GetBossTeam());
			
		if (valid)
			playerCount++;
	}

	// ensure there's at least one living valid player
	if (playerCount <= 0)
		return -1;

	// now randomly choose our victim
	int rand = GetRandomInt(0, playerCount - 1);
	playerCount = 0;
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!deadOnly && !IsValidClient(clientIdx))
			continue;
		else if (deadOnly)
		{
			if (!IsClientInGame(clientIdx) || IsValidClient(clientIdx))
				continue;
		}
			
		if (!deadOnly && maxDistance > 0.0 && !IsPlayerInRange(clientIdx, position, maxDistance))
			continue;

		if (blacklist[clientIdx])
			continue;

		// fixed to not grab people in spectator, since we can now include the dead
		bool valid = anyTeam && (GetClientTeam(clientIdx) == FF2_GetBossTeam() || GetClientTeam(clientIdx) != FF2_GetBossTeam());
		if (!valid)
			valid = (isBossTeam && GetClientTeam(clientIdx) == FF2_GetBossTeam()) || (!isBossTeam && GetClientTeam(clientIdx) != FF2_GetBossTeam());
			
		if (valid)
		{
			if (playerCount == rand) // needed if rand is 0
			{
				player = clientIdx;
				break;
			}
			playerCount++;
			if (playerCount == rand) // needed if rand is playerCount - 1, executes for all others except 0
			{
				player = clientIdx;
				break;
			}
		}
	}
	
	return player;
}

stock bool IsInstanceOf(int entity, const char[] desiredClassname)
{
	static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, MAX_ENTITY_CLASSNAME_LENGTH);
	return strcmp(classname, desiredClassname) == 0;
}

stock bool IsPlayerInRange(int player, float position[3], float maxDistance)
{
	maxDistance *= maxDistance;
	
	static float playerPos[3];
	GetEntPropVector(player, Prop_Data, "m_vecOrigin", playerPos);
	return GetVectorDistance(position, playerPos, true) <= maxDistance;
}

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client) || !IsClientConnected(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}

stock bool IsValidMinion(int client)
{
	if (GetClientTeam(client)!=FF2_GetBossTeam()) return false;
	if (FF2_GetBossIndex(client) != -1) return false;
	if (SummonerIndex[client] == -1) return false;
	return true;
}

// stole this stock from KissLick. it's a good stock!
stock void DispatchKeyValueFormat(int entity, const char[] keyName, const char[] format, any ...)
{
	static char value[256];
	VFormat(value, sizeof(value), format, 4);

	DispatchKeyValue(entity, keyName, value);
} 

// int Stocks!
stock int GetA(int c) { return abs(c>>24); }

stock int charToHex(int c)
{
	if (c >= '0' && c <= '9')
		return c - '0';
	else if (c >= 'a' && c <= 'f')
		return c - 'a' + 10;
	else if (c >= 'A' && c <= 'F')
		return c - 'A' + 10;
	
	// this is a user error, so print this out (it won't spam)
	PrintToServer("[sarysamods3] Invalid hex character, probably while parsing something's color. Please only use 0-9 and A-F in your color. c=%d", c);
	return 0;
}

stock void SetColorRGBA(int color[4], int r, int g, int b, int a)
{
	color[0] = abs(r)%256;
	color[1] = abs(g)%256;
	color[2] = abs(b)%256;
	color[3] = abs(a)%256;
}

stock int ParseColor(char[] colorStr)
{
	int ret = 0;
	ret |= charToHex(colorStr[0])<<20;
	ret |= charToHex(colorStr[1])<<16;
	ret |= charToHex(colorStr[2])<<12;
	ret |= charToHex(colorStr[3])<<8;
	ret |= charToHex(colorStr[4])<<4;
	ret |= charToHex(colorStr[5]);
	return ret;
}

stock float fixAngle(float angle)
{
	int sanity = 0;
	while (angle < -180.0 && (sanity++) <= 10)
		angle = angle + 360.0;
	while (angle > 180.0 && (sanity++) <= 10)
		angle = angle - 360.0;
		
	return angle;
}

stock void constrainDistance(const float[] startPoint, float[] endPoint, float distance, float maxDistance)
{
	if (distance <= maxDistance)
		return; // nothing to do
		
	float constrainFactor = maxDistance / distance;
	endPoint[0] = ((endPoint[0] - startPoint[0]) * constrainFactor) + startPoint[0];
	endPoint[1] = ((endPoint[1] - startPoint[1]) * constrainFactor) + startPoint[1];
	endPoint[2] = ((endPoint[2] - startPoint[2]) * constrainFactor) + startPoint[2];
}

stock float ClampBeamWidth(float w) { return w > 128.0 ? 128.0 : w; }

stock void env_shake(float Origin[3], float Amplitude, float Radius, float Duration, float Frequency)
{
	//Initialize:
	int Ent = CreateEntityByName("env_shake");
		
	//Spawn:
	if (IsValidEntity(Ent))
	{
		//Properties:
		DispatchKeyValueFloat(Ent, "amplitude", Amplitude);
		DispatchKeyValueFloat(Ent, "radius", Radius);
		DispatchKeyValueFloat(Ent, "duration", Duration);
		DispatchKeyValueFloat(Ent, "frequency", Frequency);

		SetVariantString("spawnflags 8");
		AcceptEntityInput(Ent,"AddOutput");

		//Input:
		AcceptEntityInput(Ent, "StartShake", 0);
		
		// create
		DispatchSpawn(Ent);
		
		//Send:
		TeleportEntity(Ent, Origin, NULL_VECTOR, NULL_VECTOR);

		//Delete:
		CreateTimer(Duration + 1.0, TimerRemoveEntity, EntIndexToEntRef(Ent), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action TimerRemoveEntity(Handle timer, any entid)
{
	int entity = EntRefToEntIndex(entid);
	if (IsValidEntity(entity))
	{
		RemoveEntity(entity);
	}
}

stock int ReadModelToInt(int bossIdx, const char[] ability_name, int argInt)
{
	char[] modelFile = new char[MAX_MODEL_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, modelFile, MAX_MODEL_FILE_LENGTH);
	if (strlen(modelFile) > 3)
		return PrecacheModel(modelFile);
	return -1;
}
