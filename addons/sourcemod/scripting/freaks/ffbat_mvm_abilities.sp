 /*

	Are you ready to MANN UP, LADIES?
	
*/

#include <sdkhooks>
#include <tf2attributes>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <ff2_ams2>
#undef REQUIRE_PLUGIN
#tryinclude <goomba>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

// Version Number
#define MAJOR_REVISION "1"
#define MINOR_REVISION "4"
#define PATCH_REVISION "3"

#if !defined PATCH_REVISION
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION
#else
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...PATCH_REVISION
#endif

public Plugin myinfo = {
	name = "Freak Fortress 2: Gray Mann",
	author = "SHADoW NiNE TR3S, edited by Batfoxkid",
	description="Get ready to MANN UP!",
	version=PLUGIN_VERSION,
};

enum GMBossType
{
	// Non-boss
	GBossType_None=-1,
	
	// Gray Mann
	GBossType_GrayMann=1,
	
	// Minions
	GBossType_Scout,
	GBossType_BatScout,
	GBossType_Soldier,
	GBossType_Pyro,
	GBossType_Demo,
	GBossType_DemoKnight,
	GBossType_Heavy,
	GBossType_Engineer,
	GBossType_Engineers,
	GBossType_Medic,
	GBossType_Sniper,
	GBossType_BowSniper,
	GBossType_Spy,
	
	// Scout
	GBossType_SuperScout,
	GBossType_FaNSuperScout,
	GBossType_JumpingSandmanScout,
	GBossType_MajorLeagueScout,
	GBossType_GiantBonkScout,
	GBossType_ArmoredGiantSandmanScout,
	
	// Soldier
	GBossType_GiantSoldier,
	GBossType_GiantBuffBannerSoldier,
	GBossType_GiantBattalionSoldier,
	GBossType_GiantConcherorSoldier,
	GBossType_GiantRapidFireSoldier,
	GBossType_GiantBurstFireSoldier,
	GBossType_GiantChargedSoldier,
	GBossType_GiantBlastSoldier,
	GBossType_ColonelBarrageSoldier,
	GBossType_GiantBlackBoxSoldier,
	GBossType_SergeantCrits,
	GBossType_MajorCrits,
	GBossType_ChiefBlastSoldier,
	
	// Pyro
	GBossType_GiantPyro,
	GBossType_GiantFlarePyro,

	// Demoman
	GBossType_GiantRapidFireDemo,
	GBossType_GiantBurstFireDemo,
	GBossType_GiantDemoKnight,
	GBossType_MajorBomber,
	GBossType_SirNukesalot,
	GBossType_SentryBuster,
	
	// Heavy
	GBossType_GiantHeavy,
	GBossType_GiantShotgunHeavy,
	GBossType_GiantDeflectorHeavy,
	GBossType_GiantHeaterHeavy,
	GBossType_CaptainPunch,
	GBossType_GiantHealOnKillHeavy,
	
	// Medic
	GBossType_GiantMedic
}

#define MAXTF2PLAYERS 36

// Global Vars
bool IsRoundActive;
bool UnofficialFF2;
int bossID;
int ClassCount;
int AlivePlayerCount;
bool hooked;

// Teleporter Vars
int TeleporterUpTime;
float TeleporterMessageTime;

// Player Vars
GMBossType Special[MAXTF2PLAYERS];
int SpecialIndex[MAXTF2PLAYERS];
bool IsMiniBoss[MAXTF2PLAYERS];
bool IsMechaBoss[MAXTF2PLAYERS];
int Buff[MAXTF2PLAYERS];
int NextSapperIn[MAXTF2PLAYERS];
int BotMaxHealth[MAXTF2PLAYERS];

// Bomb Vars
bool BombEnabled;
float BombTimer;
int BombLevel;
int BombCarrier;
int BombEntity;

// Boss Settings
float botHealthMulti;
float botStabMulti;
float botSapper;
float BombChance;
bool BombCapture;

// Killstreak Sound
float KspreeTimer;
int KspreeCount;

// PDA
bool UsingPDA[MAXTF2PLAYERS];
bool UsingAMS[MAXTF2PLAYERS];
int buildpage[MAXTF2PLAYERS];
int limit[MAXTF2PLAYERS];

// Bot Attribute Strings
char botAttributes1[7][256];
char botAttributes2[8][256];
char botAttributes3[2][256];
char botAttributes4[3][256];
char botAttributes5[5][256];
char botAttributes6[256];
char botAttributes7[256];
char botAttributesBuster[256];
char botAttributesBoss[6][256];

// Bot Health Values
int botHealth1[7];
int botHealth2[8];
int botHealth3[2];
int botHealth4[3];
int botHealth5[5];
int botHealth6;
int botHealth7;
int botHealthBuster;
int botHealthBoss[6];

#define SentryBusterTick "mvm/sentrybuster/mvm_sentrybuster_loop.wav"
#define SentryBusterSpawn "mvm/sentrybuster/mvm_sentrybuster_intro.wav"
#define SentryBusterModel "models/bots/demo/bot_sentry_buster.mdl"
#define SentryBusterExplode "mvm/sentrybuster/mvm_sentrybuster_explode.wav"

#define BRIEFCASE_MODEL "models/flag/briefcase.mdl"
#define BOMB_MODEL "models/props_td/atom_bomb.mdl"
#define BOMB_UPGRADE "#*mvm/mvm_warning.wav"

static const char SentryBusterAlert[][] = {
	"vo/mvm_sentry_buster_alerts01.mp3",
	"vo/mvm_sentry_buster_alerts02.mp3",
	"vo/mvm_sentry_buster_alerts03.mp3",
	"vo/mvm_sentry_buster_alerts04.mp3",
	"vo/mvm_sentry_buster_alerts05.mp3",
	"vo/mvm_sentry_buster_alerts06.mp3",
	"vo/mvm_sentry_buster_alerts07.mp3"
};

static const char SpyAlert[][] = {
	"vo/mvm_spy_spawn01.mp3",
	"vo/mvm_spy_spawn02.mp3",
	"vo/mvm_spy_spawn03.mp3",
	"vo/mvm_spy_spawn04.mp3"
};

static const char EngyAlert[][] = {
	"vo/announcer_mvm_engbot_arrive01.mp3",
	"vo/announcer_mvm_engbot_arrive02.mp3",
	"vo/announcer_mvm_engbot_arrive03.mp3",
};

static const char EngyAlert2[][] = {
	"vo/announcer_mvm_engbots_arrive01.mp3",
	"vo/announcer_mvm_engbots_arrive02.mp3"
};

static const char EngyAlert3[][] = {
	"vo/announcer_mvm_engbot_another01.mp3",
	"vo/announcer_mvm_engbot_another02.mp3"
};

static const char Kspree[][] = {
	"vo/mvm_all_dead01.mp3",
	"vo/mvm_all_dead02.mp3",
	"vo/mvm_all_dead03.mp3"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("FF2_FF2_GetArgNamedI");
	MarkNativeAsOptional("FF2_FF2_GetArgNamedF");
	MarkNativeAsOptional("FF2_FF2_GetArgNamedS");
	return APLRes_Success;
}

public void OnPluginStart2()
{
	HookEvent("arena_round_start", OnRoundStart);
	HookEvent("arena_win_panel", OnRoundEnd);
	LoadTranslations("freak_fortress_2.phrases");

	for(int i = 0; i < sizeof(SentryBusterAlert); i++)
	{
		PrecacheSound(SentryBusterAlert[i], true);
	}
	for(int i = 0; i < sizeof(SpyAlert); i++)
	{
		PrecacheSound(SpyAlert[i], true);
	}
	for(int i = 0; i < sizeof(EngyAlert); i++)
	{
		PrecacheSound(EngyAlert[i], true);
	}
	for(int i = 0; i < sizeof(EngyAlert2); i++)
	{
		PrecacheSound(EngyAlert2[i], true);
	}
	for(int i = 0; i < sizeof(EngyAlert3); i++)
	{
		PrecacheSound(EngyAlert3[i], true);
	}
	for(int i = 0; i < sizeof(Kspree); i++)
	{
		PrecacheSound(Kspree[i], true);
	}

	PrecacheSound(SentryBusterTick, true);
	PrecacheSound(SentryBusterSpawn, true);
	PrecacheSound(SentryBusterExplode, true);
	PrecacheSound("mvm/mvm_warning.wav", true);
	PrecacheSound("mvm/mvm_robo_stun.wav", true);
	PrecacheSound("mvm/mvm_sentrybuster_spin.wav", true);
	PrecacheSound("mvm/mvm_tele_deliver.wav", true);
	PrecacheSound(BOMB_UPGRADE, true);
	PrecacheModel(BOMB_MODEL, true);

	OnRoundStart(INVALID_HANDLE, "plugin_lateload", false);
}

public void OnPluginEnd()
{
	if(IsRoundActive)
		OnRoundEnd(INVALID_HANDLE, "plugin_unload", false);
}

public Action OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(!FF2_IsFF2Enabled())
		return;

	bossID = GetClientOfUserId(FF2_GetBossUserId(0));
	TeleporterUpTime = 0;
	
	for(int client=1;client<=MaxClients;client++)
	{
		if(!IsValidClient(client))
			continue;
			
		NextSapperIn[client] = 0;
		Buff[client] = 0;
		limit[client]=0;
		IsMiniBoss[client]=false;
		IsMechaBoss[client]=false;
		Special[client]=GBossType_None;
		SpecialIndex[client]=view_as<int>(GBossType_None);
			
		int boss = FF2_GetBossIndex(client);
		if(boss >= 0)
		{
			if(FF2_HasAbility(boss, this_plugin_name, "graymann_config"))
			{
				int ver[3];
				FF2_GetForkVersion(ver);
				UnofficialFF2 = (ver[0] && ver[1] && ver[2]) ? true : false;
				Special[bossID] = GBossType_GrayMann;
				SetEntData(bossID, FindDataMapInfo(bossID, "m_iAmmo") + (3 * 4), 9999, 4);
			
				MVM_AddHooks();
				IsRoundActive = true;

				botHealthMulti = FF2_GetArgF(boss, this_plugin_name, "graymann_config", "health", 1, 1.0);
				botStabMulti = FF2_GetArgF(boss, this_plugin_name, "graymann_config", "backstab", 2, 1.0);
				botSapper = FF2_GetArgF(boss, this_plugin_name, "graymann_config", "sapper", 3, 5.0);
				BombChance = FF2_GetArgF(boss, this_plugin_name, "graymann_config", "bomb", 4, 0.04);
				BombCapture = view_as<bool>(FF2_GetArgI(boss, this_plugin_name, "graymann_config", "capture", 5, 1));
				UsingPDA[client] = view_as<bool>(FF2_GetArgI(boss, this_plugin_name, "graymann_config", "usepda", 6, 1));
			}
		}
	}
}

public void FF2AMS_PreRoundStart(int client)
{
	int boss = FF2_GetBossIndex(client);
	if(FF2_HasAbility(boss, this_plugin_name, "graymann_config"))
	{
		UsingAMS[boss] = true;
		FF2AMS_PushToAMS(client, this_plugin_name, "graymann_pda0", "GM0"); // Group
		FF2AMS_PushToAMS(client, this_plugin_name, "graymann_pda1", "GM1"); // Scout
		FF2AMS_PushToAMS(client, this_plugin_name, "graymann_pda2", "GM2"); // Soldier
		FF2AMS_PushToAMS(client, this_plugin_name, "graymann_pda3", "GM3"); // Pyro
		FF2AMS_PushToAMS(client, this_plugin_name, "graymann_pda4", "GM4"); // Demoman
		FF2AMS_PushToAMS(client, this_plugin_name, "graymann_pda5", "GM5"); // Heavy
		FF2AMS_PushToAMS(client, this_plugin_name, "graymann_pda6", "GM6"); // Medic
		FF2AMS_PushToAMS(client, this_plugin_name, "graymann_pda7", "GM7"); // Sentry Buster
		FF2AMS_PushToAMS(client, this_plugin_name, "graymann_pda8", "GM8"); // MegaBoss
		FF2AMS_PushToAMS(client, this_plugin_name, "graymann_pda9", "GM9"); // Engineer
	}
	else
	{
		UsingAMS[boss] = false;
	}
}

public Action OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	IsRoundActive=false;
	if(IsValidClient(bossID) && IsPlayerAlive(bossID) && Special[bossID]==GBossType_GrayMann && UsingPDA[bossID])
	{
		SetEntPropEnt(bossID, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(bossID, TFWeaponSlot_Melee));
		TF2_RemoveWeaponSlot(bossID, 3); // No point in keeping this on an inactive round
		TF2_RemoveWeaponSlot(bossID, 5); // No point in keeping this on an inactive round
	} 

	TeleporterUpTime = 0;
	BombEnabled = false;
	BombLevel = -1;
	BombTimer = 0.0;
	BombEntity = -1;
	for(int client=1;client<=MaxClients;client++)
	{
		NextSapperIn[client] = 0;
		Buff[client] = 0;
		limit[client]=0;
		IsMiniBoss[client]=false;
		IsMechaBoss[client]=false;
		Special[client]=GBossType_None;
		SpecialIndex[client]=view_as<int>(GBossType_None);
		buildpage[client]=-1;

		if(IsValidClient(client))
		{
			StopSound(client, SNDCHAN_AUTO, SentryBusterTick);
			StopSound(client, SNDCHAN_AUTO, "mvm/mvm_robo_stun.wav");
			FF2_SetFF2flags(client, FF2_GetFF2flags(client) & ~FF2FLAG_CLASSTIMERDISABLED);
			SDKUnhook(client, SDKHook_GetMaxHealth, OnGetMaxHealth);
			
			TF2Attrib_RemoveByDefIndex(client, 68);
			TF2Attrib_RemoveByDefIndex(client, 109);
			TF2Attrib_RemoveByDefIndex(client, 112);
			TF2Attrib_RemoveByDefIndex(client, 60);
			TF2Attrib_RemoveByDefIndex(client, 62);
			TF2Attrib_RemoveByDefIndex(client, 64);
			TF2Attrib_RemoveByDefIndex(client, 66);
			TF2Attrib_RemoveByDefIndex(client, 442);
			TF2Attrib_RemoveByDefIndex(client, 443);
			TF2Attrib_RemoveByDefIndex(client, 57);
			TF2Attrib_RemoveByDefIndex(client, 113);

			if(client == BombCarrier)
				CreateTimer(0.1, SentryBusting, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	BombCarrier = -1;
	
	MVM_RemoveHooks();
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) || !FF2_IsFF2Enabled() || FF2_GetRoundState()!=1 || !IsRoundActive || (event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER))
		return Plugin_Continue;

	int bossTeam = FF2_GetBossTeam();
	if(Special[client] == GBossType_GrayMann)
	{
		SpawnManyObjects(client, 15);
		for(int target=1; target<=MaxClients; target++)
		{
			if(IsValidClient(target) && target!=client && GetClientTeam(target)==bossTeam && IsPlayerAlive(target))
			{
				if(Special[target] != GBossType_SentryBuster)
				{
					EmitSoundToAll("mvm/mvm_robo_stun.wav", target);
					if(IsMechaBoss[target])
					{
						TF2_StunPlayer(target, 21.0, 0.5, TF_STUNFLAGS_LOSERSTATE);
					}
					else
					{
						TF2_StunPlayer(target, 21.0, 1.0, TF_STUNFLAGS_NORMALBONK);
					}
				}
				else if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1)
				{
					FakeClientCommand(target, "taunt");
				}
				else
				{
					CreateTimer(1.0, SentryBusting, GetClientSerial(target), TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
		return Plugin_Continue;
	}

	SDKUnhook(client, SDKHook_GetMaxHealth, OnGetMaxHealth);
	NextSapperIn[client] = 0;
	TF2Attrib_RemoveByDefIndex(client, 68);
	TF2Attrib_RemoveByDefIndex(client, 109);
	TF2Attrib_RemoveByDefIndex(client, 112);
	TF2Attrib_RemoveByDefIndex(client, 60);
	TF2Attrib_RemoveByDefIndex(client, 62);
	TF2Attrib_RemoveByDefIndex(client, 64);
	TF2Attrib_RemoveByDefIndex(client, 66);
	TF2Attrib_RemoveByDefIndex(client, 442);
	TF2Attrib_RemoveByDefIndex(client, 443);
	TF2Attrib_RemoveByDefIndex(client, 57);
	TF2Attrib_RemoveByDefIndex(client, 113);
	
	if(IsMiniBoss[client] || IsMechaBoss[client])
	{
		if(IsMechaBoss[client])
		{
			SpawnManyObjects(client, 10);
		}
		else
		{
			SpawnManyObjects(client, 4);
		}

		StopSound(client, SNDCHAN_AUTO, SentryBusterTick);
		StopSound(client, SNDCHAN_AUTO, "mvm/mvm_robo_stun.wav");
		SpecialIndex[client]=view_as<int>(GBossType_None);
		Special[client]=GBossType_None;
		IsMiniBoss[client]=false;
		IsMechaBoss[client]=false;
		FF2_SetFF2flags(client, FF2_GetFF2flags(client) & ~FF2FLAG_CLASSTIMERDISABLED);
		ChangeClientTeam(client, (FF2_GetBossTeam()==view_as<int>(TFTeam_Blue)) ? view_as<int>(TFTeam_Red) : view_as<int>(TFTeam_Blue));
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		//SetEntProp(client, Prop_Send, "m_iMaxHealth", 175);
		return Plugin_Continue;
	}

	if(GetClientTeam(client) ==  bossTeam)
	{
		FF2_SetFF2flags(client, FF2_GetFF2flags(client) & ~FF2FLAG_CLASSTIMERDISABLED);
		SpawnManyObjects(client, 1);
		return Plugin_Continue;
	}

	if(KspreeTimer < GetGameTime())
		KspreeCount = 0;

	KspreeCount++;
	KspreeTimer = GetGameTime()+2.0;
	if(KspreeCount > 7)
	{
		for(int target=1; target<=MaxClients; target++)
		{
			if(!IsValidClient(target))
				continue;

			if(GetClientTeam(target) != bossTeam)
				EmitSoundToClient(target, Kspree[GetRandomInt(0, sizeof(Kspree)-1)]);
		}
		KspreeCount = 0;
	}

	return Plugin_Continue;
}

public Action Event_PlayerInventory(Event event, const char[] name, bool dontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1 || !IsRoundActive)
		return Plugin_Continue;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(GetClientTeam(client)!=FF2_GetBossTeam() && FF2_GetBossIndex(client)<0)
		UpgradeClient(client, 0);
	
	return Plugin_Continue;
}

public void OnFlagEvent(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player");
	int bossTeam = FF2_GetBossTeam();
	if(IsValidClient(client) && GetClientTeam(client)==bossTeam)
	{
		if(event.GetInt("eventtype") == TF_FLAGEVENT_PICKEDUP)
		{
			BombLevel = 0;
			BombCarrier = client;
			BombTimer = GetGameTime()+5.0;
			if(BombCapture)
				PrintCenterText(client, "Drop the bomb off at the control point!");

			TF2Attrib_SetByDefIndex(client, 442, 0.5);
			TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
		}
		else
		{
			BombLevel = -1;
			BombCarrier = -1;
			BombTimer = GetGameTime()+60.0;
			if(BombCapture)
				ServerCommand("ff2_point_disable");

			TF2Attrib_RemoveByDefIndex(client, 442);
			TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
			for(int target=1; target<=MaxClients; target++)
			{
				if(IsValidClient(target) && GetClientTeam(target)==bossTeam && FF2_GetBossIndex(target)<0 && Special[target]!=GBossType_SentryBuster)
				{
					TF2Attrib_RemoveByDefIndex(target, 57);
					TF2Attrib_RemoveByDefIndex(target, 68);
				}
			}
		}
	}
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int action) // Not used by abilities
{
	if(!IsRoundActive || UsingAMS[boss])
		return Plugin_Continue;

	if(StrEqual(ability_name, "graymann_pda0", false))
	{
		GM0_Invoke(GetClientOfUserId(FF2_GetBossUserId(boss)), -1);
	}
	else if(StrEqual(ability_name, "graymann_pda1", false))
	{
		GM1_Invoke(GetClientOfUserId(FF2_GetBossUserId(boss)), -1);
	}
	else if(StrEqual(ability_name, "graymann_pda2", false))
	{
		GM2_Invoke(GetClientOfUserId(FF2_GetBossUserId(boss)), -1);
	}
	else if(StrEqual(ability_name, "graymann_pda3", false))
	{
		GM3_Invoke(GetClientOfUserId(FF2_GetBossUserId(boss)), -1);
	}
	else if(StrEqual(ability_name, "graymann_pda4", false))
	{
		GM4_Invoke(GetClientOfUserId(FF2_GetBossUserId(boss)), -1);
	}
	else if(StrEqual(ability_name, "graymann_pda5", false))
	{
		GM5_Invoke(GetClientOfUserId(FF2_GetBossUserId(boss)), -1);
	}
	else if(StrEqual(ability_name, "graymann_pda6", false))
	{
		GM6_Invoke(GetClientOfUserId(FF2_GetBossUserId(boss)), -1);
	}
	else if(StrEqual(ability_name, "graymann_pda7", false))
	{
		GM7_Invoke(GetClientOfUserId(FF2_GetBossUserId(boss)), -1);
	}
	else if(StrEqual(ability_name, "graymann_pda8", false))
	{
		GM8_Invoke(GetClientOfUserId(FF2_GetBossUserId(boss)), -1);
	}
	else if(StrEqual(ability_name, "graymann_pda9", false))
	{
		GM9_Invoke(GetClientOfUserId(FF2_GetBossUserId(boss)), -1);
	}

	return Plugin_Continue;
}

public AMSResult GM0_CanInvoke(int client, int aidx)
{
	//return GetClassCount(view_as<int>(TFClass_Engineer), FF2_GetBossTeam())==0 ? true : false;
	return AMS_Accept;
}

public void GM0_Invoke(int client, int aidx)
{
	int boss=FF2_GetBossIndex(client);
	char activator_string[768];
	FF2_GetArgS(boss, this_plugin_name, "graymann_pda0", "string", 1, activator_string, sizeof(activator_string));
	limit[boss] = FF2_GetArgI(boss, this_plugin_name, "graymann_pda0", "rate", 2);
	MvM_GivePDA(client, 0, activator_string);
}

public AMSResult GM1_CanInvoke(int client, int aidx)
{
	return AMS_Accept;
}

public void GM1_Invoke(int client, int aidx)
{		
	int boss=FF2_GetBossIndex(client);
	char activator_string[768];
	FF2_GetArgS(boss, this_plugin_name, "graymann_pda1", "string", 1, activator_string, sizeof(activator_string));
	limit[boss] = FF2_GetArgI(boss, this_plugin_name, "graymann_pda1", "rate", 2);
	char ability[64];
	for(int types; types<7; types++)
	{
		Format(ability, sizeof(ability), "attribute%i", types+1);
		FF2_GetArgS(boss, this_plugin_name, "graymann_pda1", ability, (types*2)+3, botAttributes1[types], 128);
		Format(ability, sizeof(ability), "health%i", types+1);
		botHealth1[types] = FF2_GetArgI(boss, this_plugin_name, "graymann_pda1", ability, (types*2)+4);
	}
	MvM_GivePDA(client, 1, activator_string);
}

public AMSResult GM2_CanInvoke(int client, int aidx)
{
	return AMS_Accept;
}

public void GM2_Invoke(int client, int aidx)
{
	int boss=FF2_GetBossIndex(client);
	char activator_string[768];
	FF2_GetArgS(boss, this_plugin_name, "graymann_pda2", "string", 1, activator_string, sizeof(activator_string));
	limit[boss] = FF2_GetArgI(boss, this_plugin_name, "graymann_pda2", "rate", 2);
	char ability[64];
	for(int types; types<8; types++)
	{
		Format(ability, sizeof(ability), "attribute%i", types+1);
		FF2_GetArgS(boss, this_plugin_name, "graymann_pda2", ability, (types*2)+3, botAttributes2[types], 128);
		Format(ability, sizeof(ability), "health%i", types+1);
		botHealth2[types] = FF2_GetArgI(boss, this_plugin_name, "graymann_pda2", ability, (types*2)+4);
	}
	MvM_GivePDA(client, 2, activator_string);
}

public AMSResult GM3_CanInvoke(int client, int aidx)
{
	return AMS_Accept;
}

public void GM3_Invoke(int client, int aidx)
{
	int boss=FF2_GetBossIndex(client);
	char activator_string[768];
	FF2_GetArgS(boss, this_plugin_name, "graymann_pda3", "string", 1, activator_string, sizeof(activator_string));
	limit[boss] = FF2_GetArgI(boss, this_plugin_name, "graymann_pda3", "rate", 2);
	char ability[64];
	for(int types; types<2; types++)
	{
		Format(ability, sizeof(ability), "attribute%i", types+1);
		FF2_GetArgS(boss, this_plugin_name, "graymann_pda3", ability, (types*2)+3, botAttributes3[types], 128);
		Format(ability, sizeof(ability), "health%i", types+1);
		botHealth3[types] = FF2_GetArgI(boss, this_plugin_name, "graymann_pda3", ability, (types*2)+4);
	}
	MvM_GivePDA(client, 3, activator_string);
}

public AMSResult GM4_CanInvoke(int client, int aidx)
{
	return AMS_Accept;
}

public void GM4_Invoke(int client, int aidx)
{
	int boss=FF2_GetBossIndex(client);
	char activator_string[768];
	FF2_GetArgS(boss, this_plugin_name, "graymann_pda4", "string", 1, activator_string, sizeof(activator_string));
	limit[boss] = FF2_GetArgI(boss, this_plugin_name, "graymann_pda4", "rate", 2);
	char ability[64];
	for(int types; types<3; types++)
	{
		Format(ability, sizeof(ability), "attribute%i", types+1);
		FF2_GetArgS(boss, this_plugin_name, "graymann_pda4", ability, (types*2)+3, botAttributes4[types], 128);
		Format(ability, sizeof(ability), "health%i", types+1);
		botHealth4[types] = FF2_GetArgI(boss, this_plugin_name, "graymann_pda4", ability, (types*2)+4);
	}
	MvM_GivePDA(client, 4, activator_string);
}

public AMSResult GM5_CanInvoke(int client, int aidx)
{
	return AMS_Accept;
}

public void GM5_Invoke(int client, int aidx)
{
	int boss=FF2_GetBossIndex(client);
	char activator_string[768];
	FF2_GetArgS(boss, this_plugin_name, "graymann_pda5", "string", 1, activator_string, sizeof(activator_string));
	limit[boss] = FF2_GetArgI(boss, this_plugin_name, "graymann_pda5", "rate", 2);
	char ability[64];
	for(int types; types<5; types++)
	{
		Format(ability, sizeof(ability), "attribute%i", types+1);
		FF2_GetArgS(boss, this_plugin_name, "graymann_pda5", ability, (types*2)+3, botAttributes5[types], 128);
		Format(ability, sizeof(ability), "health%i", types+1);
		botHealth5[types] = FF2_GetArgI(boss, this_plugin_name, "graymann_pda5", ability, (types*2)+4);
	}
	MvM_GivePDA(client, 5, activator_string);
}

public AMSResult GM6_CanInvoke(int client, int aidx)
{
	return AMS_Accept;
}

public void GM6_Invoke(int client, int aidx)
{
	int boss=FF2_GetBossIndex(client);
	char activator_string[768];
	FF2_GetArgS(boss, this_plugin_name, "graymann_pda6", "string", 1, activator_string, sizeof(activator_string));
	limit[boss] = FF2_GetArgI(boss, this_plugin_name, "graymann_pda6", "rate", 2);
	FF2_GetArgS(boss, this_plugin_name, "graymann_pda6", "attribute", 3, botAttributes7, 128);
	botHealth7 = FF2_GetArgI(boss, this_plugin_name, "graymann_pda6", "health", 4);
	MvM_GivePDA(client, 6, activator_string);
}

public AMSResult GM7_CanInvoke(int client, int aidx)
{
	//return view_as<bool>(GetClassCount(view_as<int>(TFClass_Engineer), (FF2_GetBossTeam()==view_as<int>(TFTeam_Blue)) ? view_as<int>(TFTeam_Red) : view_as<int>(TFTeam_Blue)));
	return AMS_Accept;
}

public void GM7_Invoke(int client, int aidx)
{
	int boss=FF2_GetBossIndex(client);
	char activator_string[768];
	FF2_GetArgS(boss, this_plugin_name, "graymann_pda7", "string", 1, activator_string, sizeof(activator_string));	
	limit[boss] = FF2_GetArgI(boss, this_plugin_name, "graymann_pda7", "rate", 2);
	FF2_GetArgS(boss, this_plugin_name, "graymann_pda7", "attribute", 3, botAttributesBuster, 128);
	botHealthBuster = FF2_GetArgI(boss, this_plugin_name, "graymann_pda7", "health", 4);
	MvM_GivePDA(client, 7, activator_string);
}

public AMSResult GM8_CanInvoke(int client, int aidx)
{
	return AMS_Accept;
}

public void GM8_Invoke(int client, int aidx)
{
	int boss=FF2_GetBossIndex(client);
	char activator_string[768];
	FF2_GetArgS(boss, this_plugin_name, "graymann_pda8", "string", 1, activator_string, sizeof(activator_string));	
	limit[boss] = FF2_GetArgI(boss, this_plugin_name, "graymann_pda8", "rate", 2);
	char ability[64];
	for(int types; types<5; types++)
	{
		Format(ability, sizeof(ability), "attribute%i", types+1);
		FF2_GetArgS(boss, this_plugin_name, "graymann_pda8", ability, (types*2)+3, botAttributesBoss[types], 128);
		Format(ability, sizeof(ability), "health%i", types+1);
		botHealthBoss[types] = FF2_GetArgI(boss, this_plugin_name, "graymann_pda8", ability, (types*2)+4);
	}
	MvM_GivePDA(client, 8, activator_string);
}

public AMSResult GM9_CanInvoke(int client, int aidx)
{
	//return GetClassCount(view_as<int>(TFClass_Engineer), FF2_GetBossTeam())==0 ? true : false;
	return AMS_Accept;
}

public void GM9_Invoke(int client, int aidx)
{
	int boss=FF2_GetBossIndex(client);
	char activator_string[768];
	FF2_GetArgS(boss, this_plugin_name, "graymann_pda9", "string", 1, activator_string, sizeof(activator_string));	
	limit[boss] = FF2_GetArgI(boss, this_plugin_name, "graymann_pda9", "rate", 2);
	FF2_GetArgS(boss, this_plugin_name, "graymann_pda9", "attribute", 3, botAttributes6, 128);
	botHealth6 = FF2_GetArgI(boss, this_plugin_name, "graymann_pda9", "health", 4);
	MvM_GivePDA(client, 9, activator_string);
}

public void MvM_GivePDA(int client, int type, char activator_string[768])
{
	int boss = FF2_GetBossIndex(client);
	if(!IsValidClient(client) || boss<0)
		return;

	if(!UsingPDA[client] || IsFakeClient(client))
	{
		buildpage[client] = type;
		FakeClientCommand(client, "build");
		return;
	}

	//SetHudTextParams(-1.0, 0.30, 7.0, 255, 255, 255, 255, 2);
	//Format(activator_string, sizeof(activator_string), "%s", activator_string);
	//ShowHudText(client, -1, activator_string);	
	PrintCenterText(client, activator_string);
		
	// Modified PDA for use as miniboss spawner
	int entity = FF2_SpawnWeapon(client, "tf_weapon_builder", 28, 101, 5, "391 ; 2"); // Builder
	SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
	SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
	SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
	SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
		
	// PDA Boss Spawner
	FF2_SpawnWeapon(client, "tf_weapon_pda_engineer_build", 26, 101, 14, "292 ; 3 ; 293 ; 59 ; 391 ; 2 ; 495 ; 60");
	buildpage[client] = type;
}

public Action GrayMann_PDA(int client, const char[] command, int argc)
{
	if(Special[client] != GBossType_GrayMann)
		return Plugin_Continue;

	if(UsingPDA[client] && GetRandomDeadPlayer()==-1)
	{
		//SetHudTextParams(-1.0, 0.45, 4.0, 255, 255, 255, 255, 2);
		//ShowHudText(client, -1, "There are no dead players to spawn a robot!");
		PrintCenterText(client, "There are no dead players to spawn a robot!");
		return Plugin_Handled;
	}

	int boss = FF2_GetBossIndex(client);
	switch(buildpage[client])
	{
		case 0: // Minions
		{
			switch(GetRandomInt(0, 10))
			{
				case 0: SetMiniBoss(boss, GBossType_Scout, 125, "tf_weapon_scattergun", 13, "15 ; 0", _, 0);
				case 1: SetMiniBoss(boss, GBossType_BatScout, 185, "tf_weapon_bat", 0, "15 ; 0", _, 0);
				case 2: SetMiniBoss(boss, GBossType_Soldier, 200, "tf_weapon_rocketlauncher", 18, "15 ; 0 ; 413 ; 1", _, 0);
				case 3: SetMiniBoss(boss, GBossType_Pyro, 175, "tf_weapon_flamethrower", 21, "15 ; 0 ; 839 ; 2.8 ; 841 ; 0 ; 843 ; 8.5 ; 844 ; 2300 ; 862 ; 0.6 ; 863 ; 0.1 ; 865 ; 50 ; 783 ; 20", _, 0);
				case 4: SetMiniBoss(boss, GBossType_Demo, 175, "tf_weapon_grenadelauncher", 19, "15 ; 0 ; 413 ; 1", _, 0);
				case 5: SetMiniBoss(boss, GBossType_DemoKnight, 200, "tf_weapon_sword", 132, "15 ; 0 ; 31 ; 3 ; 107 ; 1.15 ; 125 ; 25", _, 0);
				case 6: SetMiniBoss(boss, GBossType_Heavy, 300, "tf_weapon_minigun", 15, "1 ; 0.75 ; 15 ; 0", _, 0);
				case 7: SetMiniBoss(boss, GBossType_Medic, 150, "tf_weapon_medigun", 29, "10 ; 2 ; 105 ; 0", _, 0);
				case 8: SetMiniBoss(boss, GBossType_Sniper, 125, "tf_weapon_sniperrifle", 14, "1 ; 0.75 ; 42 ; 0 ; 297 ; 1 ; 305 ; 1", _, 0);
				case 9: SetMiniBoss(boss, GBossType_BowSniper, 125, "tf_weapon_compound_bow", 56, "1 ; 0.5 ; 6 ; 0.5 ; 42 ; 0", _, 0);
				case 10: SetMiniBoss(boss, GBossType_Spy, 125, "tf_weapon_knife", 4, "1 ; 0.75 ; 166 ; 75", _, 0), EmitSoundToAll(SpyAlert[GetRandomInt(0, sizeof(SpyAlert)-1)]), ShowTFMessage("Spy bots have spawned! Look out!"), FF2_PrintGlobalText("Spy bots have spawned! Look out!");
			}
		}
		case 1: // Scouts
		{
			switch(GetRandomInt(0,5)) // Scouts
			{
				case 0: SetMiniBoss(boss, GBossType_SuperScout, botHealth1[0], "tf_weapon_bat_fish", 221, botAttributes1[0]);
				case 1: SetMiniBoss(boss, GBossType_MajorLeagueScout, botHealth1[1], "tf_weapon_bat_wood", 44, botAttributes1[1]);
				case 2: SetMiniBoss(boss, GBossType_ArmoredGiantSandmanScout, botHealth1[2], "tf_weapon_bat_wood", 44, botAttributes1[2]);
				case 3: SetMiniBoss(boss, GBossType_GiantBonkScout, botHealth1[3], "tf_weapon_lunchbox_drink", 46, botAttributes1[3]);
				case 4: SetMiniBoss(boss, GBossType_FaNSuperScout, botHealth1[4], "tf_weapon_scattergun", 45, botAttributes1[4]);
				case 5: SetMiniBoss(boss, GBossType_JumpingSandmanScout, botHealth1[5], "tf_weapon_bat_wood", 44, botAttributes1[5]);							
			}
		}
		case 2: // Soldiers
		{
			switch(GetRandomInt(0,7)) // Soldiers
			{
				case 0: SetMiniBoss(boss, GBossType_GiantSoldier, botHealth2[0], "tf_weapon_rocketlauncher", 18, botAttributes2[0]);
				case 1: SetMiniBoss(boss, GBossType_GiantBurstFireSoldier, botHealth2[1], "tf_weapon_rocketlauncher", 414, botAttributes2[1]);
				case 2: SetMiniBoss(boss, GBossType_GiantBuffBannerSoldier, botHealth2[2], "tf_weapon_buff_item", 129, botAttributes2[2]);
				case 3: SetMiniBoss(boss, GBossType_GiantBattalionSoldier, botHealth2[3], "tf_weapon_buff_item", 226, botAttributes2[3]);
				case 4: SetMiniBoss(boss, GBossType_GiantConcherorSoldier, botHealth2[4], "tf_weapon_buff_item", 354, botAttributes2[4]);
				case 5: SetMiniBoss(boss, GBossType_GiantChargedSoldier, botHealth2[5], "tf_weapon_rocketlauncher", 513, botAttributes2[5]);
				case 6: SetMiniBoss(boss, GBossType_GiantBlackBoxSoldier, botHealth2[6], "tf_weapon_rocketlauncher", 228, botAttributes2[6]);
				case 7: SetMiniBoss(boss, GBossType_GiantBlastSoldier, botHealth2[7], "tf_weapon_rocketlauncher", 414, botAttributes2[7]);
			}		
		}
		case 3: // Pyros
		{
			switch(GetRandomInt(0,1)) // Pyros
			{
				case 0: SetMiniBoss(boss, GBossType_GiantPyro, botHealth3[0], "tf_weapon_flamethrower", 21, botAttributes3[0]);
				case 1: SetMiniBoss(boss, GBossType_GiantFlarePyro, botHealth3[1], "tf_weapon_flaregun", 351, botAttributes3[1]);
			}
		}
		case 4: // Demomen
		{
			switch(GetRandomInt(0,2))
			{
				case 0: SetMiniBoss(boss, GBossType_GiantRapidFireDemo, botHealth4[0], "tf_weapon_grenadelauncher", 19, botAttributes4[0]);
				case 1: SetMiniBoss(boss, GBossType_GiantBurstFireDemo, botHealth4[1], "tf_weapon_grenadelauncher", 19, botAttributes4[1]);
				case 2: SetMiniBoss(boss, GBossType_GiantDemoKnight, botHealth4[2], "tf_weapon_sword", 132, botAttributes4[2]);
			}		
		}
		case 5: // Heavy
		{
			switch(GetRandomInt(0,4)) // Heavy
			{
				case 0: SetMiniBoss(boss, GBossType_GiantHeavy, botHealth5[0], "tf_weapon_minigun", 15, botAttributes5[0]);
				case 1: SetMiniBoss(boss, GBossType_GiantDeflectorHeavy, botHealth5[1], "tf_weapon_minigun", 15, botAttributes5[1]);
				case 2: SetMiniBoss(boss, GBossType_GiantHealOnKillHeavy, botHealth5[2], "tf_weapon_minigun", 15, botAttributes5[2]);
				case 3: SetMiniBoss(boss, GBossType_GiantHeaterHeavy, botHealth5[3], "tf_weapon_minigun", 811, botAttributes5[3]);
				case 4: SetMiniBoss(boss, GBossType_GiantShotgunHeavy, botHealth5[4], "tf_weapon_shotgun_hwg", 11, botAttributes5[4]);									
			}
		}
		case 6: // Medic
		{
			SetMiniBoss(boss, GBossType_GiantMedic, botHealth7, "tf_weapon_medigun", 411, botAttributes7); // Medic
		}
		case 7: // Sentry Busters
		{
			if(UsingPDA[client])
			{
				switch(GetClassCount(view_as<int>(TFClass_Engineer), (FF2_GetBossTeam()==view_as<int>(TFTeam_Blue)) ? view_as<int>(TFTeam_Red) : view_as<int>(TFTeam_Blue))) // Sentry Buster
				{
					case 0: // No engies :(
					{
						//SetHudTextParams(-1.0, 0.45, 4.0, 255, 255, 255, 255, 2);
						//ShowHudText(client, -1, "There are no alive engineers to be able to spawn a sentry buster!");
						PrintCenterText(client, "There are no alive engineers to be able to spawn a sentry buster!");
						return Plugin_Handled;
					}
					default: // Sentry Buster
					{
						SetMiniBoss(boss, GBossType_SentryBuster, botHealthBuster, "tf_weapon_stickbomb", 307, botAttributesBuster, GetClassCount(view_as<int>(TFClass_Engineer), (FF2_GetBossTeam()==view_as<int>(TFTeam_Blue)) ? view_as<int>(TFTeam_Red) : view_as<int>(TFTeam_Blue)));
						EmitSoundToAll(SentryBusterSpawn);
						EmitSoundToAll(SentryBusterAlert[GetRandomInt(0, sizeof(SentryBusterAlert)-1)]);
						ShowTFMessage("Engineers! Watch out for sentry busters!");
						FF2_PrintGlobalText("Engineers! Watch out for sentry busters!");
					}
				}
			}
			else
			{
				int count = GetClassCount(view_as<int>(TFClass_Engineer), (FF2_GetBossTeam()==view_as<int>(TFTeam_Blue)) ? view_as<int>(TFTeam_Red) : view_as<int>(TFTeam_Blue));
				SetMiniBoss(boss, GBossType_SentryBuster, botHealthBuster, "tf_weapon_stickbomb", 307, botAttributesBuster, count ? count : 1);
				EmitSoundToAll(SentryBusterSpawn);
				EmitSoundToAll(SentryBusterAlert[GetRandomInt(0, sizeof(SentryBusterAlert)-1)]);
				ShowTFMessage("Engineers! Watch out for sentry busters!");
				FF2_PrintGlobalText("Engineers! Watch out for sentry busters!");
			}
		}
		case 8: // MEGA Boss
		{
			switch(GetRandomInt(1,5))
			{
				case 1: SetMiniBoss(boss, GBossType_SergeantCrits, botHealthBoss[0], "tf_weapon_rocketlauncher", 18, botAttributesBoss[0], _, 2);
				case 2: SetMiniBoss(boss, GBossType_MajorBomber, botHealthBoss[1], "tf_weapon_grenadelauncher", 19, botAttributesBoss[1], _, 2);
				case 3: SetMiniBoss(boss, GBossType_SirNukesalot, botHealthBoss[2], "tf_weapon_cannon", 996, botAttributesBoss[2], _, 2);
				case 4: SetMiniBoss(boss, GBossType_GiantHealOnKillHeavy, botHealthBoss[3], "tf_weapon_minigun", 15, botAttributesBoss[3], _, 2);
				case 5: SetMiniBoss(boss, GBossType_CaptainPunch, botHealthBoss[4], "tf_weapon_fists", 331, botAttributesBoss[4], _, 2);
				case 6: SetMiniBoss(boss, GBossType_ChiefBlastSoldier, botHealthBoss[5], "tf_weapon_rocketlauncher", 414, botAttributesBoss[5], _, 2);
			}
		}
		case 9: // Engi Minion
		{
			if(!GetRandomInt(0, 3))
			{
				SetMiniBoss(boss, GBossType_Engineers, botHealth6, "tf_weapon_wrench", 7, botAttributes6, limit[boss]*2);
				EmitSoundToAll(EngyAlert2[GetRandomInt(0, sizeof(EngyAlert2)-1)]);
				ShowTFMessage("Engineer bots has spawned! Destroy them and their teleporters!");
				FF2_PrintGlobalText("Engineer bots has spawned! Destroy them and their teleporters!");
			}
			else
			{
				SetMiniBoss(boss, GBossType_Engineer, botHealth6, "tf_weapon_wrench", 7, botAttributes6);
				EmitSoundToAll(EngyAlert[GetRandomInt(0, sizeof(EngyAlert)-1)]);
				ShowTFMessage("An engineer bot has spawned! Destroy it and its teleporters!");
				FF2_PrintGlobalText("An engineer bot has spawned! Destroy it and its teleporters!");
			}
		}
		default:
		{
			if(UsingPDA[client])
			{
				//SetHudTextParams(-1.0, 0.45, 4.0, 255, 255, 255, 255, 2);
				//ShowHudText(client, -1, "There is nothing to spawn!");
				PrintCenterText(client, "There is nothing to spawn!");
			}
			return Plugin_Handled;
		}
	}

	buildpage[client] = -1;
	if(UsingPDA[client])
	{
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, TFWeaponSlot_Melee));
		TF2_RemoveWeaponSlot(client, 3); // Remove once boss has picked a miniboss to spawn.
		TF2_RemoveWeaponSlot(client, 5); // Remove once boss has picked a miniboss to spawn.
	}
	return Plugin_Handled;
}

public void MVM_AddHooks()
{	
	if(!hooked)
	{
		hooked=true;
	}
	AddNormalSoundHook(SoundHook);
	
	AddCommandListener(GrayMann_PDA, "build");
	/*AddCommandListener(SentryBuster_Detonate, "taunt");
	AddCommandListener(SentryBuster_Detonate, "+taunt");
	AddCommandListener(SentryBuster_Detonate, "voicemenu");*/

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("post_inventory_application", Event_PlayerInventory, EventHookMode_Pre);
	HookEvent("teamplay_flag_event", OnFlagEvent);
}

public void MVM_RemoveHooks()
{	
	if(hooked)
	{
		RemoveNormalSoundHook(SoundHook);
		RemoveCommandListener(GrayMann_PDA, "build");
		/*RemoveCommandListener(SentryBuster_Detonate, "taunt");
		RemoveCommandListener(SentryBuster_Detonate, "+taunt");
		RemoveCommandListener(SentryBuster_Detonate, "voicemenu");*/
		
		UnhookEvent("post_inventory_application", Event_PlayerInventory, EventHookMode_Pre);	
		UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
		UnhookEvent("teamplay_flag_event", OnFlagEvent);
		hooked=false;
	}
}

public Action SentryBuster_Detonate(int client, const char[] command, int argc)
{
	if(IsValidClient(client) && Special[client]==GBossType_SentryBuster && (GetEntityFlags(client) & FL_ONGROUND) && GetEntityMoveType(client)!=MOVETYPE_NONE)
	{
		SetEntityMoveType(client, MOVETYPE_NONE);
		EmitSoundToAll("mvm/mvm_sentrybuster_spin.wav", client);
		CreateTimer(2.1, SentryBusting, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public void OnGameFrame()
{
	if(!IsRoundActive)
		return;

	if(BombTimer && BombTimer<GetGameTime() && !IsValidClient(BombCarrier))
	{
		int entity = EntRefToEntIndex(BombEntity);
		if(IsValidEntity(entity))
			RemoveEntity(entity);

		BombTimer = 0.0;
		BombCarrier = -1;
		BombLevel = -1;
		BombEnabled = false;
		if(BombCapture)
			ServerCommand("ff2_point_disable");
	}

	if(TeleporterMessageTime>GetGameTime())
		return;

	TeleporterMessageTime = GetGameTime()+5.0;
	int bossTeam = FF2_GetBossTeam();
	int ent = -1;
	while((ent=FindEntityByClassname2(ent, "obj_teleporter")) != -1)
	{
		if(((GetEntProp(ent, Prop_Send, "m_nSkin") % 2)==(bossTeam % 2)) && IsValidClient(GetEntPropEnt(ent, Prop_Send, "m_hBuilder")) && !GetEntProp(ent, Prop_Send, "m_bCarried") && !GetEntProp(ent, Prop_Send, "m_bPlacing") && !GetEntProp(ent, Prop_Send, "m_bDisabled"))
		{
			float position[3];
			GetEntPropVector(ent, Prop_Data, "m_vecOrigin", position);

			int beacon = CreateEntityByName("trigger_push");
			CreateTimer(5.0, Timer_RemoveEntity, EntIndexToEntRef(beacon));
			TeleportEntity(beacon, position, NULL_VECTOR, NULL_VECTOR);
			TE_Particle("teleported_mvm_bot", position, _, _, beacon, 1, 0);

			TeleporterUpTime++;
			if(TeleporterUpTime>4 && GetRandomDeadPlayer()!=-1)
			{
				position[2] += 50.0;
				TeleporterUpTime = 0;
				switch(GetRandomInt(0, 10))
				{
					case 0: SetMiniBoss(-1, GBossType_Scout, 125, "tf_weapon_scattergun", 13, "15 ; 0", 3, 0, position);
					case 1: SetMiniBoss(-1, GBossType_BatScout, 150, "tf_weapon_bat", 0, "15 ; 0", 4, 0, position);
					case 2: SetMiniBoss(-1, GBossType_Soldier, 200, "tf_weapon_rocketlauncher", 18, "15 ; 0 ; 413 ; 1", 3, 0, position);
					case 3: SetMiniBoss(-1, GBossType_Pyro, 175, "tf_weapon_flamethrower", 21, "15 ; 0", 3, 0, position);
					case 4: SetMiniBoss(-1, GBossType_Demo, 175, "tf_weapon_grenadelauncher", 19, "15 ; 0 ; 413 ; 1", 3, 0, position);
					case 5: SetMiniBoss(-1, GBossType_DemoKnight, 200, "tf_weapon_sword", 132, "15 ; 0 ; 31 ; 3 ; 107 ; 1.15 ; 125 ; 25", 3, 0, position);
					case 6: SetMiniBoss(-1, GBossType_Heavy, 300, "tf_weapon_minigun", 15, "1 ; 0.75 ; 15 ; 0", 2, 0, position);
					//case 7: SetMiniBoss(-1, GBossType_Engineer, 375, "tf_weapon_wrench", 7, botAttributes6, 1, _, position), EmitSoundToAll(EngyAlert3[GetRandomInt(0, sizeof(EngyAlert3)-1)]), ShowTFMessage("Another engineer bot have spawned! Destroy the teleporters!"), FF2_PrintGlobalText("Another engineer bot have spawned! Destroy the teleporters!");
					case 7: SetMiniBoss(-1, GBossType_Medic, 150, "tf_weapon_medigun", 29, "10 ; 2 ; 105 ; 0", 3, 0, position);
					case 8: SetMiniBoss(-1, GBossType_Sniper, 125, "tf_weapon_sniperrifle", 14, "1 ; 0.75 ; 42 ; 0 ; 297 ; 1 ; 305 ; 1", 3, 0, position);
					case 9: SetMiniBoss(-1, GBossType_BowSniper, 125, "tf_weapon_compound_bow", 56, "1 ; 0.5 ; 6 ; 0.5 ; 42 ; 0", 3, 0, position);
					case 10: SetMiniBoss(-1, GBossType_Spy, 125, "tf_weapon_knife", 4, "1 ; 0.75 ; 166 ; 75", 2, 0, position), EmitSoundToAll(SpyAlert[GetRandomInt(0, sizeof(SpyAlert)-1)]), ShowTFMessage("Spy bots have spawned! Destroy the teleporters!"), FF2_PrintGlobalText("Spy bots have spawned! Destroy the teleporters!");
				}
			}
		}
	}
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
	All essential stocks
*/

stock void SetMiniBoss(int boss, GMBossType GBossType, int health, char[] name, int index, char[] attributes, int quantity=0, int megaboss=1, float position[3]=NULL_VECTOR)
{
	if(quantity <= 0)
		quantity = limit[boss];

	health = RoundToFloor(health*botHealthMulti);
	int client;
	for (int miniboss=0; miniboss<quantity; miniboss++)
	{
		client = GetRandomDeadPlayer();
		if(client != -1)
		{
			FF2_SetFF2flags(client,FF2_GetFF2flags(client)|FF2FLAG_ALLOWSPAWNINBOSSTEAM); // Spawn in Boss team
			FF2_SetFF2flags(client, FF2_GetFF2flags(client)|FF2FLAG_CLASSTIMERDISABLED); // Disable HUD/crits
			FF2_SetFF2flags(client,FF2_GetFF2flags(client)|FF2FLAG_ALLOW_AMMO_PICKUPS); // Ammo Pickup
			FF2_SetFF2flags(client,FF2_GetFF2flags(client)^FF2FLAG_ALLOW_HEALTH_PICKUPS); // NO HP Pickups!
			
			ChangeClientTeam(client,FF2_GetBossTeam());
			TF2_SetPlayerClass(client, TFClass_Scout, _, false);
			TF2_RespawnPlayer(client);
			Special[client]=GBossType;
			SpecialIndex[client]=boss;
			
			switch(GBossType)
			{
				case GBossType_Scout, GBossType_BatScout, GBossType_FaNSuperScout, GBossType_JumpingSandmanScout, GBossType_MajorLeagueScout, GBossType_GiantBonkScout, GBossType_ArmoredGiantSandmanScout:
					TF2_SetPlayerClass(client, TFClass_Scout, _, false);
				case GBossType_Soldier, GBossType_GiantSoldier, GBossType_GiantBuffBannerSoldier, GBossType_GiantBattalionSoldier, GBossType_GiantConcherorSoldier, GBossType_GiantRapidFireSoldier, GBossType_GiantBurstFireSoldier, GBossType_GiantChargedSoldier, GBossType_GiantBlastSoldier, GBossType_ColonelBarrageSoldier, GBossType_GiantBlackBoxSoldier, GBossType_SergeantCrits, GBossType_MajorCrits, GBossType_ChiefBlastSoldier:
					TF2_SetPlayerClass(client, TFClass_Soldier, _, false);
				case GBossType_Pyro, GBossType_GiantPyro, GBossType_GiantFlarePyro:
					TF2_SetPlayerClass(client, TFClass_Pyro, _, false);
				case GBossType_Demo, GBossType_DemoKnight, GBossType_GiantRapidFireDemo, GBossType_GiantBurstFireDemo, GBossType_GiantDemoKnight, GBossType_MajorBomber, GBossType_SirNukesalot, GBossType_SentryBuster:
					TF2_SetPlayerClass(client, TFClass_DemoMan, _, false);
				case GBossType_Heavy, GBossType_GiantHeavy, GBossType_GiantShotgunHeavy, GBossType_GiantDeflectorHeavy, GBossType_GiantHeaterHeavy, GBossType_CaptainPunch, GBossType_GiantHealOnKillHeavy:
					TF2_SetPlayerClass(client, TFClass_Heavy, _, false);
				case GBossType_Engineer, GBossType_Engineers:
					TF2_SetPlayerClass(client, TFClass_Engineer, _, false);
				case GBossType_Medic, GBossType_GiantMedic:
					TF2_SetPlayerClass(client, TFClass_Medic, _, false);
				case GBossType_Sniper, GBossType_BowSniper:
					TF2_SetPlayerClass(client, TFClass_Sniper, _, false);
				case GBossType_Spy:
					TF2_SetPlayerClass(client, TFClass_Spy, _, false);
			}
			
			TF2_RemoveAllWeapons(client);
			RemoveAllWearables();
			
			char model[PLATFORM_MAX_PATH];
			switch(TF2_GetPlayerClass(client))
			{
				case TFClass_Scout:
				{
					Format(model, sizeof(model), megaboss ? "models/bots/scout_boss/bot_scout_boss.mdl" : "models/bots/scout/bot_scout.mdl");
				}
				case TFClass_Sniper:
				{
					Format(model, sizeof(model), "models/bots/sniper/bot_sniper.mdl");
				}
				case TFClass_Soldier:
				{
					Format(model, sizeof(model), megaboss ? "models/bots/soldier_boss/bot_soldier_boss.mdl" : "models/bots/soldier/bot_soldier.mdl");
				}
				case TFClass_DemoMan:
				{
					Format(model, sizeof(model), megaboss ? Special[client]==GBossType_SentryBuster ? SentryBusterModel : "models/bots/demo_boss/bot_demo_boss.mdl" : "models/bots/demo/bot_demo.mdl");
				}
				case TFClass_Medic:
				{
					Format(model, sizeof(model), "models/bots/medic/bot_medic.mdl");
				}
				case TFClass_Heavy:
				{
					Format(model, sizeof(model), megaboss ? "models/bots/heavy_boss/bot_heavy_boss.mdl" : "models/bots/heavy/bot_heavy.mdl");
				}
				case TFClass_Pyro:
				{
					Format(model, sizeof(model), megaboss ? "models/bots/pyro_boss/bot_pyro_boss.mdl" : "models/bots/pyro/bot_pyro.mdl");
				}
				case TFClass_Spy:
				{
					Format(model, sizeof(model), "models/bots/spy/bot_spy.mdl");
				}
				case TFClass_Engineer:
				{
					Format(model, sizeof(model), "models/bots/engineer/bot_engineer.mdl");
				}
				default:
				{
					Format(model, sizeof(model), "error.mdl");
				}
			}
			PrecacheModel(model);
			SetVariantString(model);
			
			switch(megaboss)
			{
				case 1: IsMiniBoss[client]=true;
				case 2: IsMechaBoss[client]=true;
			}

			DataPack data;
			CreateDataTimer(0.2, Timer_EquipModel, data, TIMER_FLAG_NO_MAPCHANGE);
			data.WriteCell(GetClientSerial(client));
			data.WriteString(model);
			BotMaxHealth[client] = health;
			SDKHook(client, SDKHook_GetMaxHealth, OnGetMaxHealth);

			if(megaboss==2)
			{
				char bname[128], btype[512], lives[4];
				switch(Special[client])
				{
					case GBossType_MajorCrits: bname="Major Crits";
					case GBossType_ChiefBlastSoldier: bname="Chief Blast Soldier";
					case GBossType_SergeantCrits: bname="Sergeant Crits";
					case GBossType_MajorBomber: bname="Major Bomber";
					case GBossType_SirNukesalot: bname="Sir Nukes-a-Lot";
					case GBossType_GiantHealOnKillHeavy: bname="Chief Heal-on-Kill Deflector Heavy";
					case GBossType_CaptainPunch: bname="Captain Punch";
				}
				Format(btype, sizeof(btype), "%s\n%t", btype, "ff2_start", client, bname, health, lives);
				ReplaceString(btype, sizeof(btype), "\n", "");  //Get rid of newlines
				ShowTFMessage(btype);
				FF2_PrintGlobalText(btype);
				if(FF2_RandomSound("sound_bot_boss_spawn", bname, sizeof(bname), boss))
				{
					for(int minions=1; minions<=MaxClients; minions++)
					{
						if(!IsValidClient(minions))
							continue;

						if(GetClientTeam(minions)!=FF2_GetBossTeam())
							continue;

						EmitSoundToClient(minions, bname);
					}
				}
				TF2_AddCondition(client, TFCond_TeleportedGlow, TFCondDuration_Infinite);
				EmitSoundToAll("mvm/mvm_warning.wav");
				EmitSoundToAll("mvm/mvm_warning.wav");
			}

			AcceptEntityInput(client, "SetCustomModel");
			SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);

			int wepEnt = FF2_SpawnWeapon(client, name, index, 101, 14, attributes);
			if(Special[client]!=GBossType_JumpingSandmanScout && Special[client]!=GBossType_ArmoredGiantSandmanScout && Special[client]!=GBossType_MajorLeagueScout)
				FF2_SetAmmo(client, wepEnt, 99999);

			TF2Attrib_SetByDefIndex(client, 109, 0.0);
			TF2Attrib_SetByDefIndex(client, 112, 1.0);
			
			switch(Special[client])
			{
				case GBossType_MajorCrits, GBossType_SergeantCrits, GBossType_MajorBomber, GBossType_SirNukesalot, GBossType_CaptainPunch: TF2_AddCondition(client, TFCond_CritCanteen, TFCondDuration_Infinite); // 100% Crits
				case GBossType_GiantBattalionSoldier, GBossType_GiantBuffBannerSoldier, GBossType_GiantConcherorSoldier: FF2_SpawnWeapon(client, "tf_weapon_rocketlauncher", 18, 101, 14, "413 ; 1 ; 57 ; 20 ; 252 ; 0.4 ; 54 ; 0.5"), SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 100.0); // Rocket Launcher & Full RAGE
				case GBossType_SentryBuster: EmitSoundToAll(SentryBusterTick, client), SetEntProp(wepEnt, Prop_Send, "m_iDetonated", 1)/*, PrintCenterText(client, "Call for a Medic to explode!")*/; // No Surprise Kabooms pls
				case GBossType_GiantBonkScout: FF2_SpawnWeapon(client, "tf_weapon_bat", 0, 101, 14, "252 ; 0.7"); // Bat for melee
				case GBossType_Engineer, GBossType_Engineers: wepEnt=FF2_SpawnWeapon(client, "tf_weapon_builder", 28, 101, 14, ""), SetEntProp(wepEnt, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0), SetEntProp(wepEnt, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1), SetEntProp(wepEnt, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2), SetEntProp(wepEnt, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3), FF2_SpawnWeapon(client, "tf_weapon_pda_engineer_build", 25, 101, 14, ""), FF2_SpawnWeapon(client, "tf_weapon_pda_engineer_destroy", 26, 101, 14, ""), SetEntData(client, FindDataMapInfo(client, "m_iAmmo") + (3 * 4), 600, 4);
				case GBossType_Medic: FF2_SpawnWeapon(client, "tf_weapon_syringegun_medic", 17, 101, 14, ""); // Syringe gun
				case GBossType_GiantMedic: FF2_SpawnWeapon(client, "tf_weapon_syringegun_medic", 17, 101, 14, "57 ; 20 ; 54 ; 0.5"), SetEntPropFloat(wepEnt, Prop_Send, "m_flChargeLevel", GetEntPropFloat(wepEnt, Prop_Send, "m_flChargeLevel")+1.00); // Type 2 with syringe gun 
				case GBossType_Sniper: FF2_SpawnWeapon(client, "tf_weapon_club", 3, 101, 14, "15 ; 0");
				case GBossType_Spy: wepEnt=FF2_SpawnWeapon(client, "tf_weapon_builder", 735, 101, 14, ""), SetEntProp(wepEnt, Prop_Send, "m_iObjectType", 3), SetEntProp(wepEnt, Prop_Data, "m_iSubType", 3), SetEntProp(wepEnt, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0), SetEntProp(wepEnt, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1), SetEntProp(wepEnt, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2), SetEntProp(wepEnt, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3), FF2_SpawnWeapon(client, "tf_weapon_revolver", 24, 101, 14, "1 ; 0.75 ; 15 ; 0 ; 166 ; 10"), FF2_SpawnWeapon(client, "tf_weapon_pda_spy", 27, 101, 14, ""), FF2_SpawnWeapon(client, "tf_weapon_invis", 30, 101, 14, "35 ; 0.01");
			}

			if(!IsNullVector(position))
			{
				TF2_AddCondition(client, TFCond_UberchargedHidden, 2.0);
				TF2_AddCondition(client, TFCond_TeleportedGlow, 6.0);
				TeleportEntity(client, position, NULL_VECTOR, NULL_VECTOR);
				EmitSoundToAll("mvm/mvm_tele_deliver.wav", client);
			}
			else
			{
				if(!megaboss && !BombEnabled && GetRandomFloat(0.0, 1.0)<BombChance)
				{
					BombEnabled = true;
					float pos[3];
					GetEntPropVector(client, Prop_Data, "m_vecOrigin", pos);
					int bomb = CreateEntityByName("item_teamflag"); 
					TeleportEntity(bomb, pos, NULL_VECTOR, NULL_VECTOR); 
					DispatchKeyValue(bomb, "Angles", "0 0 0");
					DispatchKeyValue(bomb, "TeamNum", FF2_GetBossTeam()==3 ? "3" : "2"); 
					DispatchKeyValue(bomb, "StartDisabled", "0"); 
					DispatchSpawn(bomb); 
					AcceptEntityInput(bomb, "Enable"); 
					char sound[64];
					if(FF2_RandomSound("sound_bot_bomb_spawn", sound, sizeof(sound), boss))
						EmitSoundToClient(client, sound);
				}
				else
					TF2_AddCondition(client, TFCond_UberchargedHidden, 5.0);
			}

			//SetEntityHealth(client, health);
			SetEntProp(client, Prop_Data, "m_iHealth", health);
			SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public Action Timer_EquipModel(Handle timer, DataPack pack)
{
	pack.Reset();
	int client=GetClientFromSerial(pack.ReadCell());
	if(client && IsClientInGame(client) && IsPlayerAlive(client))
	{
		char[] model = new char[PLATFORM_MAX_PATH];
		pack.ReadString(model, PLATFORM_MAX_PATH);
		ReadPackString(pack, model, PLATFORM_MAX_PATH);
		SetVariantString(model);
		AcceptEntityInput(client, "SetCustomModel");
		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
		//SetEntityHealth(client, RoundFloat(ReadPackFloat(pack)));
		SetEntProp(client, Prop_Data, "m_iHealth", BotMaxHealth[client]);
	}
}

stock void ShowTFMessage(char[] strMessage) 
{
	int iEntity = CreateEntityByName("game_text_tf");
	DispatchKeyValue(iEntity,"message", strMessage);
	DispatchKeyValue(iEntity,"display_to_team", "0");
	DispatchKeyValue(iEntity,"icon", "ico_notify_on_fire");
	DispatchKeyValue(iEntity,"targetname", "game_text1");
	DispatchKeyValue(iEntity,"background", "0");
	DispatchSpawn(iEntity);
	AcceptEntityInput(iEntity, "Display", iEntity, iEntity);
	/*if(TFMessageRepeat == 0)
	{
		CreateTimer(0.5, Timer_ShowTFMessage, strMessage, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}*/
	CreateTimer(3.0, KillGameText, EntIndexToEntRef(iEntity), TIMER_FLAG_NO_MAPCHANGE);
}

/*public Action Timer_ShowTFMessage(Handle timer, char[] strMessage)
{
	TFMessageRepeat++;

	if(TFMessageRepeat > 4)
	{
		TFMessageRepeat=0;
		return Plugin_Stop;
	}

	ShowTFMessage(strMessage);
	return Plugin_Continue;
}*/

public Action KillGameText(Handle hTimer, any iEntityRef) 
{
	int iEntity = EntRefToEntIndex(iEntityRef);
	if ((iEntity > 0) && IsValidEntity(iEntity))
		RemoveEntity(iEntity);
	return Plugin_Stop;
}

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(!FF2_IsFF2Enabled() || !IsRoundActive || FF2_GetRoundState()!=1)
		return Plugin_Continue;
	
	if(!IsValidClient(client) || FF2_GetBossIndex(client)>=0)
		return Plugin_Continue;

	if(IsMiniBoss[client] || IsMechaBoss[client])
	{
		if(damagetype & DMG_FALL)
			return Plugin_Handled;

		if(IsValidClient(attacker) && FF2_GetBossIndex(client)<0)
		{
			bool bIsBackstab, bIsTelefrag;
			if(damagecustom==TF_CUSTOM_BACKSTAB)
			{
				bIsBackstab=true;
			}
			else if(damagecustom==TF_CUSTOM_TELEFRAG)
			{
				bIsTelefrag=true;
			}
			else if(weapon!=4095 && IsValidEntity(weapon) && weapon==GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee) && damage>1000.0)
			{
				char classname[32];
				if(GetEntityClassname(weapon, classname, sizeof(classname)) && !StrContains(classname, "tf_weapon_knife", false))
				{
					bIsBackstab=true;
				}
			}
			else if(!IsValidEntity(weapon) && (damagetype & DMG_CRUSH)==DMG_CRUSH && damage==1000.0)
			{
				bIsTelefrag=true;
			}

			int index;
			char classname[64];
			if(IsValidEntity(weapon) && weapon>MaxClients && attacker<=MaxClients)
			{
				GetEntityClassname(weapon, classname, sizeof(classname));
				if(!StrContains(classname, "eyeball_boss"))  //Dang spell Monoculuses
				{
					index=-1;
					classname[0] = '\0';
				}
				else
				{
					index=GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
				}
			}
			else
			{
				index=-1;
				classname[0] = '\0';
			}

			//Sniper rifles aren't handled by the switch/case because of the amount of reskins there are
			if(!StrContains(classname, "tf_weapon_sniperrifle"))
			{
				float charge=(IsValidEntity(weapon) && weapon>MaxClients ? GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage") : 0.0);
				if(index==752)  //Hitman's Heatmaker
				{
					float focus=10+(charge/10);
					if(TF2_IsPlayerInCondition(attacker, TFCond_FocusBuff))
					{
						focus/=3;
					}
					float rage=GetEntPropFloat(attacker, Prop_Send, "m_flRageMeter");
					SetEntPropFloat(attacker, Prop_Send, "m_flRageMeter", (rage+focus>100) ? 100.0 : rage+focus);
				}
				else if(index!=230 && index!=402 && index!=526 && index!=30665)  //Sydney Sleeper, Bazaar Bargain, Machina, Shooting Star
				{
					int current=FF2_GetClientGlow(client);
					float time=(current>10 ? 1.0 : 2.0);
					time+=(current>10 ? (current>20 ? 1.0 : 2.0) : 4.0)*(charge/100.0);
					if(time>25.0)
					{
						time=25.0;
					}
					FF2_SetClientGlow(client, time);
				}

				if(!(damagetype & DMG_CRIT))
				{
					ConVar cvar;
					if(TF2_IsPlayerInCondition(attacker, TFCond_CritCola) || TF2_IsPlayerInCondition(attacker, TFCond_Buffed))
					{
						cvar = FindConVar("ff2_sniper_dmg_mini");
						if(cvar == null)
						{
							damage *= 2.2;
						}
						else
						{
							damage *= cvar.FloatValue;
						}
					}
					else
					{
						cvar = FindConVar("ff2_sniper_dmg");
						if(index!=230)  //Sydney Sleeper
						{
							if(cvar == null)
							{
								damage *= 3.0;
							}
							else
							{
								damage *= cvar.FloatValue;
							}
						}
						else
						{
							if(cvar == null)
							{
								damage *= 2.4;
							}
							else
							{
								damage *= cvar.FloatValue*0.8;
							}
						}
					}
					return Plugin_Changed;
				}
			}
			else if(!StrContains(classname, "tf_weapon_compound_bow") && UnofficialFF2)
			{
				if((damagetype & DMG_CRIT))
				{
					ConVar cvar = FindConVar("ff2_sniper_bow");
					if(cvar != null)
					{
						damage *= cvar.FloatValue;
						return Plugin_Changed;
					}
				}
				else if(TF2_IsPlayerInCondition(attacker, TFCond_CritCola) || TF2_IsPlayerInCondition(attacker, TFCond_Buffed))
				{
					ConVar cvar = FindConVar("ff2_sniper_bow_mini");
					if(cvar != null)
					{
						if(cvar.FloatValue>0.0)
						{
							damage *= cvar.FloatValue;
							return Plugin_Changed;
						}
						cvar = FindConVar("ff2_sniper_bow_non");
						if(cvar != null)
						{
							if(cvar.FloatValue>0.0)
							{
								damage *= cvar.FloatValue;
								return Plugin_Changed;
							}
						}
					}
					cvar = FindConVar("ff2_sniper_bow_non");
					if(cvar != INVALID_HANDLE)
					{
						if(cvar.FloatValue>0.0)
						{
							damage *= cvar.FloatValue;
							return Plugin_Changed;
						}
					}
				}
				else
				{
					ConVar cvar = FindConVar("ff2_sniper_bow_non");
					if(cvar != INVALID_HANDLE)
					{
						if(cvar.FloatValue>0.0)
						{
							damage *= cvar.FloatValue;
							return Plugin_Changed;
						}
					}
				}
				return Plugin_Continue;
			}

			switch(index)
			{
				case 61, 1006:  //Ambassador, Festive Ambassador
				{
					ConVar cvar = FindConVar("ff2_hardcodewep");
					if(cvar != null)
					{
						if(cvar.IntValue>1)
							return Plugin_Continue;
					}

					if(damagecustom==TF_CUSTOM_HEADSHOT)
					{
						damage=85.0;  //Final damage 255
						return Plugin_Changed;
					}
				}
				case 132, 266, 482, 1082:  //Eyelander, HHHH, Nessie's Nine Iron, Festive Eyelander
				{
					IncrementHeadCount(attacker);
				}
				case 214:  //Powerjack
				{
					ConVar cvar = FindConVar("ff2_hardcodewep");
					if(cvar != null)
					{
						if(cvar.IntValue>1)
							return Plugin_Continue;
					}

					int health=GetClientHealth(attacker);
					int newhealth=health+25;
					if(newhealth<=GetEntProp(attacker, Prop_Data, "m_iMaxHealth"))  //No overheal allowed
						SetEntityHealth(attacker, newhealth);

					if(!UnofficialFF2 && TF2_IsPlayerInCondition(attacker, TFCond_OnFire))
					{
						TF2_RemoveCondition(attacker, TFCond_OnFire);
					}
				}
				case 307:  //Ullapool Caber
				{
					if(UnofficialFF2 && !GetEntProp(weapon, Prop_Send, "m_iDetonated"))	// If using ullapool caber, only trigger if bomb hasn't been detonated
                        		{
						damage = GetRandomFloat(350.0, 550.0)*botStabMulti;
						damagetype |= DMG_CRIT;

						float position[3];
						GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", position);

						EmitSoundToClient(attacker, "ambient/lightsoff.wav", _, _, _, _, 0.6, _, _, position, _, false);
						EmitSoundToClient(client, "ambient/lightson.wav", _, _, _, _, 0.6, _, _, position, _, false);

						return Plugin_Changed;
					}
				}
				case 310:  //Warrior's Spirit
				{
					ConVar cvar = FindConVar("ff2_hardcodewep");
					if(cvar != null)
					{
						if(cvar.IntValue>1)
							return Plugin_Continue;
					}

					int health=GetClientHealth(attacker);
					int newhealth=health+50;
					if(newhealth<=GetEntProp(attacker, Prop_Data, "m_iMaxHealth"))  //No overheal allowed
						SetEntityHealth(attacker, newhealth);

					if(!UnofficialFF2 && TF2_IsPlayerInCondition(attacker, TFCond_OnFire))
					{
						TF2_RemoveCondition(attacker, TFCond_OnFire);
					}
				}
				case 317:  //Candycane
				{
					SpawnSmallHealthPackAt(client, GetClientTeam(attacker), attacker);
				}
				case 327:  //Claidheamh Mòr
				{
					ConVar cvar = FindConVar("ff2_hardcodewep");
					if(cvar != null)
					{
						if(cvar.IntValue>1)
							return Plugin_Continue;
					}

					float charge=GetEntPropFloat(attacker, Prop_Send, "m_flChargeMeter");
					if(charge+25.0>=100.0)
					{
						SetEntPropFloat(attacker, Prop_Send, "m_flChargeMeter", 100.0);
					}
					else
					{
						SetEntPropFloat(attacker, Prop_Send, "m_flChargeMeter", charge+25.0);
					}
				}
				case 348:  //Sharpened Volcano Fragment
				{
					if(UnofficialFF2)
					{
						ConVar cvar = FindConVar("ff2_hardcodewep");
						if(cvar != null)
						{
							if(cvar.IntValue>1)
								return Plugin_Continue;
						}

						int health=GetClientHealth(attacker);
						int max=GetEntProp(attacker, Prop_Data, "m_iMaxHealth");
						int newhealth=health+5;
						if(health<max+60)
						{
							if(newhealth>max+60)
							{
								newhealth=max+60;
							}
							SetEntityHealth(attacker, newhealth);
						}
					}
				}
				case 357:  //Half-Zatoichi
				{
					int health=GetClientHealth(attacker);
					int max=GetEntProp(attacker, Prop_Data, "m_iMaxHealth");
					int max2=RoundToFloor(max*2.0);
					if(!UnofficialFF2)	// Official only version
					{
						int newhealth=health+50;
						if(health<max2)
						{
							if(newhealth>max2)
							{
								newhealth=max2;
							}
							SetEntityHealth(attacker, newhealth);
						}
						if(TF2_IsPlayerInCondition(attacker, TFCond_OnFire))
						{
							TF2_RemoveCondition(attacker, TFCond_OnFire);
						}
					}
					else if(GetEntProp(weapon, Prop_Send, "m_bIsBloody"))	// Less effective used more than once
					{
						int newhealth=health+25;
						if(health<max2)
						{
							if(newhealth>max2)
							{
								newhealth=max2;
							}
							SetEntityHealth(attacker, newhealth);
						}
					}
					else	// Most effective on first hit
					{
						int newhealth=health+RoundToFloor(max/2.0);
						if(health<max2)
						{
							if(newhealth>max2)
							{
								newhealth=max2;
							}
							SetEntityHealth(attacker, newhealth);
						}
						if(TF2_IsPlayerInCondition(attacker, TFCond_OnFire))
						{
							TF2_RemoveCondition(attacker, TFCond_OnFire);
						}
					}
					SetEntProp(weapon, Prop_Send, "m_bIsBloody", 1);
					if(GetEntProp(attacker, Prop_Send, "m_iKillCountSinceLastDeploy")<1)
					{
						SetEntProp(attacker, Prop_Send, "m_iKillCountSinceLastDeploy", 1);
					}
				}
				case 416:  //Market Gardener (courtesy of Chdata)
				{
					if(RemoveCond(attacker, TFCond_BlastJumping)) {
						damage = GetRandomFloat(250.0, 600.0)*botStabMulti;
						damagetype |= DMG_CRIT|DMG_PREVENT_PHYSICS_FORCE;
						if(IsMechaBoss[client])
							damage *= 3.0;

						float position[3];
						GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", position);

						EmitSoundToClient(attacker, "player/doubledonk.wav", _, _, _, _, 0.6, _, _, position, _, false);
						EmitSoundToClient(client, "player/doubledonk.wav", _, _, _, _, 0.6, _, _, position, _, false);

						return Plugin_Changed;
					}
				}
				case 525, 595:  //Diamondback, Manmelter
				{
					ConVar cvar = FindConVar("ff2_hardcodewep");
					if(cvar != null)
					{
						if(cvar.IntValue>1)
							return Plugin_Continue;
					}

					if(GetEntProp(attacker, Prop_Send, "m_iRevengeCrits"))  //If a revenge crit was used, give a damage bonus
					{
						damage=85.0;  //255 final damage
						return Plugin_Changed;
					}
				}
				case 528:  //Short Circuit
				{
					ConVar cvar = FindConVar("ff2_circuit_stun");
					if(cvar == null)
						return Plugin_Continue;

					if(cvar.IntValue<=0)
						return Plugin_Continue;

					TF2_StunPlayer(client, GetConVarFloat(FindConVar("ff2_circuit_stun")), 0.0, TF_STUNFLAGS_SMALLBONK|TF_STUNFLAG_NOSOUNDOREFFECT, attacker);
					EmitSoundToAll("weapons/barret_arm_zap.wav", client);
					EmitSoundToClient(client, "weapons/barret_arm_zap.wav");
				}
				case 593:  //Third Degree
				{
					int healers[MAXPLAYERS];
					int healerCount;
					for(int healer; healer<=MaxClients; healer++)
					{
						if(IsValidClient(healer) && IsPlayerAlive(healer) && (GetHealingTarget(healer, true)==attacker))
						{
							healers[healerCount]=healer;
							healerCount++;
						}
					}

					for(int healer; healer<healerCount; healer++)
					{
						if(IsValidClient(healers[healer]) && IsPlayerAlive(healers[healer]))
						{
							int medigun=GetPlayerWeaponSlot(healers[healer], TFWeaponSlot_Secondary);
							if(IsValidEntity(medigun))
							{
								char medigunClassname[64];
								GetEntityClassname(medigun, medigunClassname, sizeof(medigunClassname));
								if(StrEqual(medigunClassname, "tf_weapon_medigun", false))
								{
									float uber=GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel")+(0.1/healerCount);
									if(uber>1.0)
									{
										uber=1.0;
									}
									SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", uber);
								}
							}
						}
					}
				}
				case 594:  //Phlogistinator
				{
					ConVar cvar = FindConVar("ff2_hardcodewep");
					if(cvar != null)
					{
						if(cvar.IntValue>1)
							return Plugin_Continue;
					}

					if(!TF2_IsPlayerInCondition(attacker, TFCond_CritMmmph))
					{
						damage/=2.0;
						return Plugin_Changed;
					}
				}
			}

			if(bIsBackstab)
			{
				damage = GetRandomFloat(350.0, 750.0)*botStabMulti;
				damagetype |= DMG_CRIT|DMG_PREVENT_PHYSICS_FORCE;
				damagecustom = 0;
				if(IsMechaBoss[client])
					damage *= 3.0;

				EmitSoundToClient(client, "player/crit_received3.wav", _, _, _, _, 0.7, _, _, _, _, false);
				EmitSoundToClient(attacker, "player/crit_received3.wav", _, _, _, _, 0.7, _, _, _, _, false);

				SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime()+2.0);
				SetEntPropFloat(attacker, Prop_Send, "m_flNextAttack", GetGameTime()+2.0);
				SetEntPropFloat(attacker, Prop_Send, "m_flStealthNextChangeTime", GetGameTime()+2.0);

				int viewmodel=GetEntPropEnt(attacker, Prop_Send, "m_hViewModel");
				if(viewmodel>MaxClients && IsValidEntity(viewmodel) && TF2_GetPlayerClass(attacker)==TFClass_Spy)
				{
					int melee = GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Melee);
					int animation = 42;
					switch(melee)
					{
						case 225, 356, 423, 461, 574, 649, 1071, 30758:  //Your Eternal Reward, Conniver's Kunai, Saxxy, Wanga Prick, Big Earner, Spy-cicle, Golden Frying Pan, Prinny Machete
							animation=16;

						case 638:  //Sharp Dresser
							animation=32;
					}
					SetEntProp(viewmodel, Prop_Send, "m_nSequence", animation);
				}
				switch(index)
				{
					case 225, 574:	// Eternal Reward, Wanga Prick
					{
						RandomlyDisguise(client);
					}
					case 356:	// Conniver's Kunai
					{
						int health=GetClientHealth(attacker)+200;
						if(health>600)
						{
							health=600;
						}
						SetEntProp(attacker, Prop_Data, "m_iHealth", health);

						if(TF2_IsPlayerInCondition(attacker, TFCond_OnFire))
						{
							TF2_RemoveCondition(attacker, TFCond_OnFire);
						}
					}
					case 461:	// Big Earner
					{
						SetEntPropFloat(attacker, Prop_Send, "m_flCloakMeter", 100.0);	//Full cloak
						TF2_AddCondition(attacker, TFCond_SpeedBuffAlly, 3.0);  //Speed boost
					}
				}
			
				if(index!=225 && index!=574)  //Your Eternal Reward, Wanga Prick
				{
					float position[3];
					GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", position);

					EmitSoundToClient(client, "player/spy_shield_break.wav", _, _, _, _, 0.7, _, _, position, _, false);
					EmitSoundToClient(attacker, "player/spy_shield_break.wav", _, _, _, _, 0.7, _, _, position, _, false);
				}

				if(GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Primary)==525)  //Diamondback
					SetEntProp(attacker, Prop_Send, "m_iRevengeCrits", GetEntProp(attacker, Prop_Send, "m_iRevengeCrits")+3);

				return Plugin_Changed;
			}
			else if(bIsTelefrag)
			{
				damagecustom = 0;
				if(!IsPlayerAlive(attacker))
				{
					damage = 1.0;
				}
				else
				{
					damage = 9001.0;
				}
				return Plugin_Changed;
			}
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public Action OnStomp(int attacker, int victim, float &damageMultiplier, float &damageBonus, float &JumpPower)
{
	if(!FF2_IsFF2Enabled() || !IsRoundActive || FF2_GetRoundState()!=1)
		return Plugin_Continue;

	if(!IsValidClient(attacker) || !IsValidClient(victim) || attacker==victim)
		return Plugin_Continue;

	if(IsMiniBoss[victim] || IsMechaBoss[victim])
	{
		damageMultiplier = FindConVar("ff2_goomba_damage").FloatValue;
		JumpPower = FindConVar("ff2_goomba_jump").FloatValue;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

stock int GetIndexOfWeaponSlot(int client, int slot)
{
	int weapon = GetPlayerWeaponSlot(client, slot);
	return (weapon>MaxClients && IsValidEntity(weapon) ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
}

stock void RandomlyDisguise(int client)	// From FF2's built-in random disguise
{
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		int disguiseTarget = -1;
		int team = UnofficialFF2 ? TF2_GetClientTeam(client)==TFTeam_Red ? view_as<int>(TFTeam_Blue) : view_as<int>(TFTeam_Red) : GetClientTeam(client);
		// Since Unofficial has the ability to look like a robot while disguised, make it so you disguise as the rival team.

		ArrayList disguiseArray = new ArrayList();
		for(int clientcheck; clientcheck<=MaxClients; clientcheck++)
		{
			if(IsValidClient(clientcheck) && GetClientTeam(clientcheck)==team && clientcheck!=client)
				disguiseArray.Push(clientcheck);
		}

		if(!disguiseArray.Length)
		{
			disguiseTarget = client;
		}
		else
		{
			disguiseTarget = disguiseArray.Get(GetRandomInt(0, disguiseArray.Length - 1));
			if(!IsValidClient(disguiseTarget))
			{
				disguiseTarget = client;
			}
		}

		int class = GetRandomInt(0, 4);
		TFClassType classArray[] = {TFClass_Scout, TFClass_Pyro, TFClass_Medic, TFClass_Engineer, TFClass_Sniper};
		delete disguiseArray;

		if(TF2_GetPlayerClass(client) == TFClass_Spy)
		{
			TF2_DisguisePlayer(client, view_as<TFTeam>(team), classArray[class], disguiseTarget);
		}
		else
		{
			TF2_AddCondition(client, TFCond_Disguised, -1.0);
			SetEntProp(client, Prop_Send, "m_nDisguiseTeam", team);
			SetEntProp(client, Prop_Send, "m_nDisguiseClass", classArray[class]);
			SetEntProp(client, Prop_Send, "m_iDisguiseTargetIndex", disguiseTarget);
			SetEntProp(client, Prop_Send, "m_iDisguiseHealth", 200);
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(!FF2_IsFF2Enabled() || !IsRoundActive)
		return Plugin_Continue;

	int bossTeam = FF2_GetBossTeam();
	if(BombCarrier==client && IsPlayerAlive(client) && GetClientTeam(client)==bossTeam)
	{
		if(BombLevel > 0)
		{
			float position[3], position2[3], distance;
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", position);
			if(BombCapture)
			{
				ServerCommand("ff2_point_enable");
				TF2Attrib_RemoveByDefIndex(client, 68);
			}
			for(int target=1; target<=MaxClients; target++)
			{
				if(IsValidClient(target))
				{
					if(client!=target && BombCapture)
						TF2Attrib_SetByDefIndex(target, 68, -3.0);

					if(GetClientTeam(target)==bossTeam && FF2_GetBossIndex(target)<0 && Special[target]!=GBossType_SentryBuster)
					{
						GetEntPropVector(target, Prop_Send, "m_vecOrigin", position2);
						distance = GetVectorDistance(position, position2);
						if(distance < 380)
						{
							if(BombLevel > 2)
								TF2_AddCondition(target, TFCond_HalloweenCritCandy, 1.0);

							if(BombLevel > 1)
								TF2Attrib_SetByDefIndex(target, 57, 45.0);

							TF2_AddCondition(target, TFCond_DefenseBuffNoCritBlock, 1.0);
						}
						else
						{
							TF2Attrib_RemoveByDefIndex(target, 57);
						}
					}
				}
			}
		}
	
		if(BombTimer<GetGameTime() && BombLevel<3 && GetEntPropEnt(client, Prop_Send, "m_hGroundEntity")!=-1)
		{
			BombLevel++;
			BombTimer = GetGameTime()+15.0;

			FakeClientCommand(client, "taunt");
			EmitSoundToAll(BOMB_UPGRADE, SOUND_FROM_WORLD, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_NOFLAGS, 0.500, SNDPITCH_NORMAL);
		}
	}

	if(!botSapper || UnofficialFF2)
		return Plugin_Continue;

	int entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(IsValidEntity(entity) && GetClientTeam(client)!=bossTeam)
	{
		int index = GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
		if((buttons & IN_ATTACK) && !TF2_IsPlayerInCondition(client, TFCond_Cloaked) && !GetEntProp(client, Prop_Send, "m_bFeignDeathReady") && (index==735 || index==736 || index==810 || index==831 || index==933 || index==1080 || index==1102))
		{
			float position[3], position2[3], distance;
			int boss;
			bool usedSapper;
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", position);
			for(int target=1; target<=MaxClients; target++)
			{
				if(IsValidClient(target) && IsPlayerAlive(target) && GetClientTeam(target)==bossTeam)
				{
					boss = FF2_GetBossIndex(target);
					GetEntPropVector(target, Prop_Send, "m_vecOrigin", position2);
					distance = GetVectorDistance(position, position2);
					if(distance<180 && target!=client &&
					  !TF2_IsPlayerInCondition(target, TFCond_Dazed) &&
					  !TF2_IsPlayerInCondition(target, TFCond_Sapped) &&
					  !TF2_IsPlayerInCondition(target, TFCond_UberchargedHidden) &&
					  !TF2_IsPlayerInCondition(target, TFCond_Ubercharged) &&
					  !TF2_IsPlayerInCondition(target, TFCond_MegaHeal))
					{
						if(Special[client] == GBossType_SentryBuster)
						{
						}
						else if(boss>=0 || IsMechaBoss[target])
						{
							TF2_StunPlayer(target, botSapper, 0.0, TF_STUNFLAGS_SMALLBONK|TF_STUNFLAG_NOSOUNDOREFFECT, client);
							TF2_AddCondition(target, TFCond_Sapped, botSapper);
							usedSapper = true;
						}
						else
						{
							TF2_StunPlayer(target, botSapper, 0.0, TF_STUNFLAGS_NORMALBONK|TF_STUNFLAG_NOSOUNDOREFFECT, client);
							TF2_AddCondition(target, TFCond_Sapped, botSapper);
							usedSapper = true;
						}
					}
				}
			}

			if(usedSapper)
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, TFWeaponSlot_Melee));
				SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime()+1.0);
				SetEntPropFloat(client, Prop_Send, "m_flStealthNextChangeTime", GetGameTime()+1.0);
				NextSapperIn[client] = 5;
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public Action SoundHook(int clients[64], int &numClients, char vl[PLATFORM_MAX_PATH], int &Ent, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	if(!IsRoundActive)
		return Plugin_Continue;

	int client = Ent;
	if(client <=  MAXPLAYERS && client > 0)
	{
		if (StrContains(vl, "announcer")!=-1) return Plugin_Continue;
		if (StrContains(vl, "norm")!=-1) return Plugin_Continue;
		if (StrContains(vl, "mght")!=-1) return Plugin_Continue;
		if (StrContains(vl, "vo/", false)==-1) return Plugin_Continue;
	
		if(!IsValidBoss(client) && GetClientTeam(client)==FF2_GetBossTeam() && !TF2_IsPlayerInCondition(client, TFCond_Disguised)) // Robot voice lines & footsteps
		{
			if (StrContains(vl, "player/footsteps/", false) != -1)
			{	
				if(TF2_GetPlayerClass(client)==TFClass_Medic || TF2_GetPlayerClass(client)==TFClass_Engineer || (!IsMiniBoss[client] && !IsMechaBoss[client]))
					return Plugin_Stop;
				Format(vl, sizeof(vl), "mvm/giant_common/giant_common_step_0%i.wav", GetRandomInt(1,8));
				pitch = GetRandomInt(95, 100);
				EmitSoundToAll(vl, client, _, _, _, 0.25, pitch);
				return Plugin_Changed;
			}

			if(Special[client]==GBossType_SentryBuster) // Block voice lines.
			{
				if (StrContains(vl, "demo", false) != -1) 
					return Plugin_Stop;
			}
			else
			{
				if (volume == 0.99997) return Plugin_Continue;
				ReplaceString(vl, sizeof(vl), "vo/", (TF2_GetPlayerClass(client)==TFClass_Medic || TF2_GetPlayerClass(client)==TFClass_Engineer || (!IsMiniBoss[client] && !IsMechaBoss[client])) ? "vo/mvm/norm/" : "vo/mvm/mght/", false);
				char classname[10], classname_mvm[20];
				TF2_GetNameOfClass(TF2_GetPlayerClass(client), classname, sizeof(classname));
				Format(classname_mvm, sizeof(classname_mvm), (TF2_GetPlayerClass(client)==TFClass_Medic || TF2_GetPlayerClass(client)==TFClass_Engineer || (!IsMiniBoss[client] && !IsMechaBoss[client])) ? "%s_mvm" : "%s_mvm_m", classname);
				ReplaceString(vl, sizeof(vl), classname, classname_mvm, false);
				char gSnd[PLATFORM_MAX_PATH];
				Format(gSnd, sizeof(gSnd), "sound/%s", vl);
				PrecacheSound(vl);
				return Plugin_Changed;
			}
			return Plugin_Continue;
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public Action SentryBusting(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (!IsValidClient(client)) return Plugin_Handled;
	if (!IsPlayerAlive(client)) return Plugin_Handled;
	int explosion = CreateEntityByName("env_explosion");
	float clientPos[3];
	GetClientAbsOrigin(client, clientPos);
	if (explosion)
	{
		TeleportEntity(explosion, clientPos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(explosion);
		AcceptEntityInput(explosion, "Explode", -1, -1, 0);
		RemoveEntity(explosion);
	}
	
	float zPos[3];
	int ent = 1;
	
	for (; ent <= MaxClients; ent++)
	{
		if(!IsValidClient(ent) || !IsPlayerAlive(ent)) continue;
		GetClientAbsOrigin(ent, zPos);
		float Dist = GetVectorDistance(clientPos, zPos);
		if (Dist > 300.0) continue;
		DoDamage(client, ent, 2500);
	}
	
	++ent;
	while((ent = FindEntityByClassname(ent, "obj_*")) != -1) {
		if(HasEntProp(ent, Prop_Send, "m_hBuilder")) {
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", zPos);
			
			float Dist = GetVectorDistance(clientPos, zPos);
			if (Dist > 300.0) continue;
			
			SetVariantInt(2500);
			AcceptEntityInput(ent, "RemoveHealth");
		}
	}
	
	EmitSoundToAll(SentryBusterExplode, client);
	AttachParticle(client, "fluidSmokeExpl_ring_mvm");
	DoDamage(client, client, 2500);
	ForcePlayerSuicide(client);
	CreateTimer(0.1, Timer_RemoveRagdoll, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

public Action Timer_RemoveRagdoll(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (!IsValidClient(client)) return;
	int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if (!IsValidEntity(ragdoll) || ragdoll <= MaxClients) return;
	RemoveEntity(ragdoll);
}

stock void DoDamage(int client, int target, int amount) // from Goomba Stomp.
{
	int pointHurt = CreateEntityByName("point_hurt");
	if (pointHurt)
	{
		DispatchKeyValue(target, "targetname", "explodeme");
		DispatchKeyValue(pointHurt, "DamaFF2_GetArget", "explodeme");
		char dmg[15];
		Format(dmg, 15, "%i", amount);
		DispatchKeyValue(pointHurt, "Damage", dmg);
		DispatchKeyValue(pointHurt, "DamageType", "0");

		DispatchSpawn(pointHurt);
		AcceptEntityInput(pointHurt, "Hurt", client);
		DispatchKeyValue(pointHurt, "classname", "point_hurt");
		DispatchKeyValue(target, "targetname", "");
		RemoveEdict(pointHurt);
	}
}

stock void SpawnManyObjects(int client, int amount=14)
{
	if(!client || !IsClientInGame(client))
		return;

	float position[3];
	float angle[] = {0.0, 0.0, 0.0};
	GetClientAbsOrigin(client, position);
	position[2] += 10.0;
	for(int i; i<amount; i++)
	{
		position[0] += GetRandomFloat(-15.0, 15.0);
		position[1] += GetRandomFloat(-15.0, 15.0);

		int entity;
		switch(GetRandomInt(0, 5))
		{
			case 3, 4:
			{
				entity = CreateEntityByName("item_currencypack_medium");
				if(!IsValidEntity(entity))
					continue;

				PrecacheModel("models/items/currencypack_medium.mdl");
				SetEntityModel(entity, "models/items/currencypack_medium.mdl");
			}
			case 5:
			{
				entity = CreateEntityByName("item_currencypack_large");
				if(!IsValidEntity(entity))
					continue;

				PrecacheModel("models/items/currencypack_large.mdl");
				SetEntityModel(entity, "models/items/currencypack_large.mdl");
			}
			default:
			{
				entity = CreateEntityByName("item_currencypack_small");
				if(!IsValidEntity(entity))
					continue;

				PrecacheModel("models/items/currencypack_small.mdl");
				SetEntityModel(entity, "models/items/currencypack_small.mdl");
			}
		}

		DispatchKeyValue(entity, "OnPlayerTouch", "!self,Kill,,0,-1");
		SetEntProp(entity, Prop_Send, "m_nSkin", 0);
		SetEntProp(entity, Prop_Send, "m_nSolidType", 6);
		SetEntProp(entity, Prop_Send, "m_usSolidFlags", 152);
		SetEntProp(entity, Prop_Send, "m_triggerBloat", 24);
		SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1);
		SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
		SetEntProp(entity, Prop_Send, "m_iTeamNum", 2);
		TeleportEntity(entity, position, angle, NULL_VECTOR);
		DispatchSpawn(entity);
		SetEntProp(entity, Prop_Data, "m_iHealth", 900);
		//int offs = GetEntSendPropOffs(entity, "m_vecInitialVelocity", true);
		//SetEntData(entity, offs-4, 1, _, true);
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

stock void CreateParticle(const char[] particle, float pos[3])
{
	int tblidx = FindStringTable("ParticleEffectNames");
	int stridx = FindStringIndex(tblidx, particle);
	
	if(stridx == INVALID_STRING_INDEX) {
		LogError("Invalid String Table index for particle (%s)", particle);
		return;
	}
	
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", pos[0]);
	TE_WriteFloat("m_vecOrigin[1]", pos[1]);
	TE_WriteFloat("m_vecOrigin[2]", pos[2]);
	TE_WriteNum("m_iParticleSystemIndex", stridx);
	TE_WriteNum("entindex", -1);
	TE_SendToAll();
}

public Action DeleteParticle(Handle timer, int ref)
{
	int Ent = EntRefToEntIndex(ref);
	if (!IsValidEntity(Ent)) return Plugin_Continue;
	RemoveEntity(Ent);
	return Plugin_Continue;
}

public void RemoveAllWearables()
{
	int entity, owner;
	while((entity = FindEntityByClassname(entity, "tf_wearable*")) != -1 || (entity=FindEntityByClassname(entity, "tf_powerup_bottle")) !=-1) {
		if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==FF2_GetBossTeam()) {
			TF2_RemoveWearable(owner, entity);
		}
	}
}

stock int GetRandomDeadPlayer()
{
	int[] clients = new int[MaxClients+1];
	int clientCount;
	for(int i=1;i<=MaxClients;i++)
	{
		if(IsValidEdict(i) && IsValidClient(i) && !IsPlayerAlive(i) && !IsValidBoss(i) && (GetClientTeam(i) > 1))
		{
			clients[clientCount++] = i;
		}
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

stock void TF2_GetNameOfClass(TFClassType class, char[] name, int maxlen)
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

stock void SetAmmo(int client, int slot, int ammo)
{
	int weapon = GetPlayerWeaponSlot(client, slot);
	if (IsValidEntity(weapon))
	{
		int iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		static int iAmmoTable = 0;
		if(!iAmmoTable) {
			iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		}
		SetEntData(client, iAmmoTable+iOffset, ammo, 4, true);
	}
}

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client) || !IsClientConnected(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}

stock bool IsValidBoss(int client)
{
	if (FF2_GetBossIndex(client) == -1) return false;
	return true;
}

stock bool IsValidMinion(int client)
{
	if (GetClientTeam(client)!=FF2_GetBossTeam()) return false;
	if (FF2_GetBossIndex(client) >= 0) return false;
	if (SpecialIndex[client] == -1) return false;
	return true;
}

stock void FF2_PrintGlobalText(char[] text)
{
	CPrintToChatAll("{olive}[FF2]{default} %s", text);
}

stock void FF2_PrintClientText(int client, char[] text)
{
	CPrintToChat(client, "{olive}[FF2]{default} %s", text);
}

stock int GetClassCount(int classtype, int teamnum)
{
	ClassCount=0;
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && IsPlayerAlive(client) && TF2_GetPlayerClass(client) == view_as<TFClassType>(classtype) && GetClientTeam(client) == teamnum)
		{
			ClassCount++;
			FF2Dbg("Class Count for class %i, team %i: %i", classtype, teamnum, ClassCount);
		}
	}
	return ClassCount;
}

stock int GetAlivePlayerCount(int team)
{
	AlivePlayerCount=0;
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == team)
		{
			AlivePlayerCount++;
			FF2Dbg("Alive Player Count for Team %i: %i", team, AlivePlayerCount);
		}
	}
	return AlivePlayerCount;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(!FF2_IsFF2Enabled() || !IsRoundActive)
		return;

	if(StrEqual(classname, "item_currencypack_small"))
	{
		SDKHook(entity, SDKHook_Spawn, OnSmallSpawned);
	}
	else if(StrEqual(classname, "item_currencypack_medium"))
	{
		SDKHook(entity, SDKHook_Spawn, OnMediumSpawned);
	}
	else if(StrEqual(classname, "item_currencypack_large"))
	{
		SDKHook(entity, SDKHook_Spawn, OnLargeSpawned);
	}
	else if(StrEqual(classname, "item_teamflag"))
	{
		SDKHook(entity, SDKHook_Spawn, OnFlagSpawned);
	}
}

public void OnSmallSpawned(int entity)
{
	SDKUnhook(entity, SDKHook_Spawn, OnSmallSpawned);
	SDKHook(entity, SDKHook_StartTouch, OnSmallPickup);
	SDKHook(entity, SDKHook_Touch, OnSmallPickup);
	CreateTimer(30.0, Timer_RemoveEntity, EntIndexToEntRef(entity));
}

public void OnMediumSpawned(int entity)
{
	SDKUnhook(entity, SDKHook_Spawn, OnMediumSpawned);
	SDKHook(entity, SDKHook_StartTouch, OnMediumPickup);
	SDKHook(entity, SDKHook_Touch, OnMediumPickup);
	CreateTimer(30.0, Timer_RemoveEntity, EntIndexToEntRef(entity));
}

public void OnLargeSpawned(int entity)
{
	SDKUnhook(entity, SDKHook_Spawn, OnLargeSpawned);
	SDKHook(entity, SDKHook_StartTouch, OnLargePickup);
	SDKHook(entity, SDKHook_Touch, OnLargePickup);
	CreateTimer(30.0, Timer_RemoveEntity, EntIndexToEntRef(entity));
}

public void OnFlagSpawned(int entity)
{
	SDKUnhook(entity, SDKHook_Spawn, OnFlagSpawned);
	char model[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_iszModel", model, sizeof(model));
	if(!strlen(model) || StrEqual(model, BRIEFCASE_MODEL))
	{
		DispatchKeyValue(entity, "flag_model", BOMB_MODEL);
		DispatchKeyValue(entity, "trail_effect", "3");
	}

	BombEntity = EntIndexToEntRef(entity);
	BombCarrier = -1;
	BombLevel = -1;
	BombTimer = GetGameTime()+30.0;
	SDKHook(entity, SDKHook_StartTouch, OnFlagPickup);
	SDKHook(entity, SDKHook_Touch, OnFlagPickup);
}

public Action OnSmallPickup(int entity, int client)
{
	if(!IsValidClient(client) || Buff[client]==100 || GetClientTeam(client)==FF2_GetBossTeam())
		return Plugin_Handled;

	UpgradeClient(client, 1);
	return Plugin_Continue;
}

public Action OnMediumPickup(int entity, int client)
{
	if(!IsValidClient(client) || Buff[client]==100 || GetClientTeam(client)==FF2_GetBossTeam())
		return Plugin_Handled;

	UpgradeClient(client, 2);
	return Plugin_Continue;
}

public Action OnLargePickup(int entity, int client)
{
	if(!IsValidClient(client) || Buff[client]==100 || GetClientTeam(client)==FF2_GetBossTeam())
		return Plugin_Handled;

	UpgradeClient(client, 4);
	return Plugin_Continue;
}

stock void UpgradeClient(int client, int amount)
{
	if(!IsRoundActive)
		return;

	Buff[client] += amount;
	NextSapperIn[client] -= amount;

	float value = 1.0 - (Buff[client]*0.01);
	TF2Attrib_SetByDefIndex(client, 60, value<0.25 ? 0.25 : value);
	TF2Attrib_SetByDefIndex(client, 62, value<0.1 ? 0.1 : value);
	TF2Attrib_SetByDefIndex(client, 64, value<0.25 ? 0.25 : value);
	TF2Attrib_SetByDefIndex(client, 66, value<0.25 ? 0.25 : value);

	value = 1.0 + (Buff[client]*0.003);
	TF2Attrib_SetByDefIndex(client, 442, value>1.3 ? 1.3 : value);

	value = 1.0 + (Buff[client]*0.006);
	TF2Attrib_SetByDefIndex(client, 443, value>1.6 ? 1.6 : value);

	value = Buff[client]*0.1;
	TF2Attrib_SetByDefIndex(client, 57, value>10 ? 10.0 : value);

	value = Buff[client]*0.25;
	TF2Attrib_SetByDefIndex(client, 113, value>25 ? 25.0 : value);

	if(amount)
	{
		PrintHintText(client, "Upgraded %i%%", Buff[client]>100 ? 100 : Buff[client]);
		if(!NextSapperIn[client])
		{
			int wepEnt = FF2_SpawnWeapon(client, "tf_weapon_builder", 735, 1, 0, "");
			SetEntProp(wepEnt, Prop_Send, "m_iObjectType", 3);
			SetEntProp(wepEnt, Prop_Data, "m_iSubType", 3);
			SetEntProp(wepEnt, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
			SetEntProp(wepEnt, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
			SetEntProp(wepEnt, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
			SetEntProp(wepEnt, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
			PrintCenterText(client, "Sapper is now ready!");
		}
	}
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
}

public Action OnFlagPickup(int entity, int client)
{
	if(!IsValidClient(client) || GetClientTeam(client)!=FF2_GetBossTeam() || FF2_GetBossIndex(client)>=0 || Special[client]==GBossType_SentryBuster)
		return Plugin_Handled;

	return Plugin_Continue;
}

stock void TE_Particle(const char[] Name, float origin[3]=NULL_VECTOR, float start[3]=NULL_VECTOR, float angles[3]=NULL_VECTOR, int entindex=-1, int attachtype=-1, int attachpoint=-1, bool resetParticles=true, int customcolors=0, float color1[3]=NULL_VECTOR, float color2[3]=NULL_VECTOR, int controlpoint=-1, int controlpointattachment=-1, float controlpointoffset[3]=NULL_VECTOR, float delay=0.0)
{
	// find string table
	int tblidx = FindStringTable("ParticleEffectNames");
	int stridx = FindStringIndex(tblidx, Name);
	if(stridx == INVALID_STRING_INDEX)
	{
		LogError("Could not find particle: %s", Name);
		return;
	}

	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", origin[0]);
	TE_WriteFloat("m_vecOrigin[1]", origin[1]);
	TE_WriteFloat("m_vecOrigin[2]", origin[2]);
	TE_WriteFloat("m_vecStart[0]", start[0]);
	TE_WriteFloat("m_vecStart[1]", start[1]);
	TE_WriteFloat("m_vecStart[2]", start[2]);
	TE_WriteVector("m_vecAngles", angles);
	TE_WriteNum("m_iParticleSystemIndex", stridx);

	if(entindex != -1)
		TE_WriteNum("entindex", entindex);

	if(attachtype != -1)
		TE_WriteNum("m_iAttachType", attachtype);

	if(attachpoint != -1)
		TE_WriteNum("m_iAttachmentPointIndex", attachpoint);

	TE_WriteNum("m_bResetParticles", resetParticles ? 1 : 0);

	if(customcolors)
	{
		TE_WriteNum("m_bCustomColors", customcolors);
		TE_WriteVector("m_CustomColors.m_vecColor1", color1);
		if(customcolors == 2)
			TE_WriteVector("m_CustomColors.m_vecColor2", color2);
	}

	if(controlpoint != -1)
	{
		TE_WriteNum("m_bControlPoint1", controlpoint);
		if(controlpointattachment != -1)
		{
			TE_WriteNum("m_ControlPoint1.m_eParticleAttachment", controlpointattachment);
			TE_WriteFloat("m_ControlPoint1.m_vecOffset[0]", controlpointoffset[0]);
			TE_WriteFloat("m_ControlPoint1.m_vecOffset[1]", controlpointoffset[1]);
			TE_WriteFloat("m_ControlPoint1.m_vecOffset[2]", controlpointoffset[2]);
		}
	}

	TE_SendToAll(delay);
}

public Action Timer_RemoveEntity(Handle timer, any entid)
{
	int entity = EntRefToEntIndex(entid);
	if(IsValidEntity(entity))
		RemoveEntity(entity);

	return Plugin_Continue;
}

stock int SpawnSmallHealthPackAt(int client, int team=0, int attacker)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client))
		return -1;

	int healthpack = CreateEntityByName("item_healthkit_small");
	float position[3];
	GetClientAbsOrigin(client, position);
	position[2] += 20.0;
	if(IsValidEntity(healthpack))
	{
		DispatchKeyValue(healthpack, "OnPlayerTouch", "!self,Kill,,0,-1");
		DispatchSpawn(healthpack);
		SetEntProp(healthpack, Prop_Send, "m_iTeamNum", team, 4);
		SetEntityMoveType(healthpack, MOVETYPE_VPHYSICS);
		float velocity[3];
		velocity[0] = float(GetRandomInt(-10, 10)), velocity[1]=float(GetRandomInt(-10, 10)), velocity[2]=50.0;  //I did this because setting it on the creation of the vel variable was creating a compiler error for me.
		TeleportEntity(healthpack, position, NULL_VECTOR, velocity);
		SetEntPropEnt(healthpack, Prop_Send, "m_hOwnerEntity", attacker);
		return healthpack;
	}
	return -1;
}

public Action OnGetMaxHealth(int client, int &maxHealth)
{
	if(IsMiniBoss[client] || IsMechaBoss[client])
	{
		maxHealth = BotMaxHealth[client];
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

stock void IncrementHeadCount(int client)
{
	if(!TF2_IsPlayerInCondition(client, TFCond_DemoBuff))
		TF2_AddCondition(client, TFCond_DemoBuff, -1.0);

	int decapitations = GetEntProp(client, Prop_Send, "m_iDecapitations");
	int health = GetClientHealth(client);
	SetEntProp(client, Prop_Send, "m_iDecapitations", decapitations+1);
	SetEntityHealth(client, health+15);
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
}

stock int GetHealingTarget(int client, bool checkgun=false)
{
	int medigun=GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if(!checkgun)
	{
		if(GetEntProp(medigun, Prop_Send, "m_bHealing"))
			return GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");

		return -1;
	}

	if(IsValidEntity(medigun))
	{
		if(HasEntProp(medigun, Prop_Send, "m_hHealingTarget") && GetEntProp(medigun, Prop_Send, "m_bHealing")) {
			return GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");
		}
	}
	return -1;
}

// True if the condition was removed.
stock bool RemoveCond(int client, TFCond cond)
{
	if(TF2_IsPlayerInCondition(client, cond))
	{
		TF2_RemoveCondition(client, cond);
		return true;
	}
	return false;
}

#file "Another Gray Mann error?"
