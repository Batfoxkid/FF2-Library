//////////////////////
//Table of contents://
////// Defines ///////
////// Events  ///////
///// Abilities //////
////// Timers  ///////
////// Stocks  ///////
//////////////////////

//////////// Plugin inits

#define FF2_USING_AUTO_PLUGIN__OLD

#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <ff2_ams2>
#undef REQUIRE_PLUGIN
#tryinclude <ff2_dynamic_defaults>
#define REQUIRE_PLUGIN
#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name	= "Freak Fortress 2: Deathreus Boss Pack",
	author	= "Deathreus",
	version = "1.7"
};



/////////////////////////////////////////
//Defines some terms used by the plugin//
/////////////////////////////////////////

 #undef MAXPLAYERS // Cause why not
#define MAXPLAYERS 34

#define IsEmptyString(%1) (%1[0]==0)

int BossTeam = view_as<int>(TFTeam_Blue);
int MercTeam = view_as<int>(TFTeam_Red);
int g_Boss;
int MJT_ButtonType;		// Shared between Magic Jump and Magic Teleport as 4th argument, or Jump Manager as 2nd

/* Rage_Wanker */
int WankerPissMode[MAXPLAYERS];						//1
int WankerAmmo[MAXPLAYERS];							//2

float WankerPissDuration[MAXPLAYERS]; 				//3

/* Rage_TheRock */
float Rockduration[MAXPLAYERS];						//1

/* Rage_Mine */
int FruitCanRemoveSentry[MAXPLAYERS];				//2
float FruitRageRange[MAXPLAYERS];					//1

/* Charge_RocketSpawn */
int RocketRequiredRage[MAXPLAYERS];					//8

float RocketCharge[MAXPLAYERS];						//1
float RocketCooldown[MAXPLAYERS];					//2
float RocketSpeed[MAXPLAYERS];						//3
float RocketDamage[MAXPLAYERS];						//6
float RocketStunTime[MAXPLAYERS];					//7

char RocketModel[MAXPLAYERS][PLATFORM_MAX_PATH];	//4
char RocketParticle[MAXPLAYERS][PLATFORM_MAX_PATH];	//5

Handle chargeHUD = INVALID_HANDLE;

/* Heffe_Reincarn_Rapture */
#define MODEL_TRIGGER			"models/items/ammopack_small.mdl"

#define RAPTURE_STUN_DELAY		1.0
#define RAPTURE_BEAM_LENGTH		1000.0
#define RAPTURE_BEAM_MINS		view_as<float>({-50.0, -50.0, 0.0})
#define RAPTURE_BEAM_MAXS		view_as<float>({50.0, 50.0, 1000.0})

int RaptureIteration;					// 1
int RaptureBlindTime;					// 9
int g_Update[MAXPLAYERS];				// Internal
int g_Smoke;							// Internal
int g_Glow;								// Internal
int g_Laser;							// Internal

float RaptureTimer;						// 2
float RaptureRadius;					// 3
float RaptureVel;						// 4
float RaptureDmg;						// 5
float RaptureStunTime;					// 7
float RaptureDuration;					// 8
float RaptureSlayRatio;					// 10
float DiedRapture[MAXPLAYERS];			// Internal

char RapturePush[6];					// 6

/* Rage_Heffe */
#define SOUND_THUNDER 			"ambient/explosions/explode_9.wav"

int g_iSmiteNumber;						// 3
int g_iButtonType;						// 4
int g_SmokeSprite;						// Internal
int g_LightningSprite;					// Internal

float HeffeStunDuration;				// 2
float HeffeRange;						// 1

bool Heffe_TriggerAMS[MAXPLAYERS+1];

Handle heffeHUD = INVALID_HANDLE;

/* DOT_Heffe_Jump */
int FlapForce;							// 2

float HeffeUpdateHUD[MAXPLAYERS];		// Internal
float FlapDrain;						// 1
//float FlapRate;							// 3  /** < 01Pollux: deprecated, its assigned to a value that is never used */

char FlapSound[PLATFORM_MAX_PATH];		// 4

bool g_bButtonPressed = false;			// Internal

Handle jumpHUD = INVALID_HANDLE;

/* Special_PocketMedic */
bool MedicJumpWeaponPreference[MAXPLAYERS];
bool MedicTeleWeaponPreference[MAXPLAYERS];

/* Rage_SkeleSummon */
int SkeleNumberOfSpawns[MAXPLAYERS];				// 1

/* Charge_MagicJump */			// Intended for gaining height
float MJ_ChargeTime[MAXPLAYERS];					// 1
float MJ_Cooldown[MAXPLAYERS];						// 2
float MJ_OnCooldownUntil[MAXPLAYERS];				// Internal, set by arg3
float MJ_CrouchOrAltFireDownSince[MAXPLAYERS];		// Internal

bool MJ_EmergencyReady[MAXPLAYERS+1];				// Internal

/* Charge_MegicTele */			// Intended for catching fast players
float MT_ChargeTime[MAXPLAYERS];					// 1
float MT_Cooldown[MAXPLAYERS];						// 2
float MT_OnCooldownUntil[MAXPLAYERS];				// Internal, set by arg3
float MT_CrouchOrAltFireDownSince[MAXPLAYERS];		// Internal

bool MT_EmergencyReady[MAXPLAYERS];					// Internal

/* Special_JumpManager */
int JM_ButtonType;									// 1

bool JM_AbilitySwitched[MAXPLAYERS];				// Internal

float WitchDoctorUpdateHUD[MAXPLAYERS];				// Internal

Handle witchdoctorHUD;

/* Special_SpellAttack */
float SS_CoolDown[MAXPLAYERS];						// 1

/* Rage_MLG */
float MLGRageTime[MAXPLAYERS];

bool MLG[MAXPLAYERS] = false;

//////////// FF2 inits
public void OnPluginStart2()
{
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);

	HookUserMessage(GetUserMessageId("PlayerJarated"), Event_Jarate);

	LoadTranslations("freak_fortress_2.phrases");
	LoadTranslations("ff2_1st_set.phrases");

	heffeHUD = CreateHudSynchronizer();
	jumpHUD = CreateHudSynchronizer();
	chargeHUD = CreateHudSynchronizer();
	witchdoctorHUD = CreateHudSynchronizer();

	PrecacheModel(MODEL_TRIGGER, true);
	g_Laser = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_Smoke = PrecacheModel("materials/effects/fire_cloud1.vmt");
	g_Glow = PrecacheModel("sprites/yellowglow1.vmt", true);

	PrecacheSound(SOUND_THUNDER, true);
	g_SmokeSprite = PrecacheModel("sprites/steam1.vmt");
	g_LightningSprite = PrecacheModel("sprites/lgtning.vmt");
}

public void FF2_OnAbility2(int iBoss, const char[] pluginName, const char[] abilityName, int iStatus)
{
	int iSlot = FF2_GetAbilityArgument(iBoss, pluginName, abilityName, 0);
	if (!strcmp(abilityName, "rage_wanker"))
		Rage_Wanker(iBoss);
	else if (!strcmp(abilityName, "rage_heffe"))
		Rage_Heffe(iBoss, abilityName);
	else if (!strcmp(abilityName, "rage_therock"))
		Rage_TheRock(iBoss);
	else if (!strcmp(abilityName, "rage_mine"))
		Rage_Mine(iBoss);
	else if (!strcmp(abilityName, "rage_skelesummon"))
		Rage_SkeleSummon(iBoss, abilityName);
	else if(!strcmp(abilityName, "charge_projectile"))
		Charge_RocketSpawn(iBoss, iSlot, iStatus);
	else if(!strcmp(abilityName, "rage_mlg"))
		Rage_MLG(iBoss, abilityName);
}

//////////////////
//	AMS stuff  //
/////////////////

public void FF2AMS_PreRoundStart(int client)
{
	int boss = FF2_GetBossIndex(client);
	if (FF2_HasAbility(boss, this_plugin_name, "rage_heffe"))
	{
		Heffe_TriggerAMS[client] = FF2AMS_PushToAMS(client, this_plugin_name, "rage_heffe", "HEFFE");
	}
}

public AMSResult HEFFE_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

/////////////////////////////////////
//	Events start below this point  //
/////////////////////////////////////

public void Event_RoundStart(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	BossTeam = FF2_GetBossTeam();
	MercTeam = (FF2_GetBossTeam()==view_as<int>(TFTeam_Blue)) ? view_as<int>(TFTeam_Red) : view_as<int>(TFTeam_Blue);

	for(int iIndex, iBoss=GetClientOfUserId(FF2_GetBossUserId(iIndex)); iIndex < MaxClients; iIndex++)
	{
		if(FF2_HasAbility(iIndex, this_plugin_name, "rage_wanker"))
		{
			WankerPissMode[iBoss] = FF2_GetAbilityArgumentBool(iIndex, this_plugin_name, "rage_wanker", 1);					// Jarate and bleed or just bleed, 0 = just bleed
			WankerAmmo[iBoss] = FF2_GetAbilityArgument(iIndex, this_plugin_name, "rage_wanker", 2, 3);
			WankerPissDuration[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "rage_wanker", 3, 10.0);		// Duration of bleed
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "heffe_reincarn_rapture"))
		{
			RaptureIteration = FF2_GetAbilityArgument(iIndex, this_plugin_name, "heffe_reincarn_rapture", 1, 15);			// Number of beams
			RaptureTimer = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "heffe_reincarn_rapture", 2, 0.2);			// Interval of beam spawns
			RaptureRadius = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "heffe_reincarn_rapture", 3, 800.0);		// Radius around boss to spawn the beams
			RaptureVel = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "heffe_reincarn_rapture", 4, 350.0);			// Push force to get them off the ground and start the move upwards
			RaptureDmg = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "heffe_reincarn_rapture", 5, 10.0);			// Damager per tick at it's peak, factored based on distance
			FF2_GetAbilityArgumentString(iIndex, this_plugin_name, "heffe_reincarn_rapture", 6, RapturePush, 6);			// Push force of the beams
			RaptureStunTime = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "heffe_reincarn_rapture", 7, 1.0);		// Stun time, will be reapplied every 1 second(s)
			RaptureDuration = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "heffe_reincarn_rapture", 8, 8.0);		// Duration of stun and beams
			RaptureBlindTime = FF2_GetAbilityArgument(iIndex, this_plugin_name, "heffe_reincarn_rapture", 9, 10);			// Duration of visual screen effect
			RaptureSlayRatio = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "heffe_reincarn_rapture", 10, 0.95);	// How far they must be upwards before they are slayed outright

			g_Boss = iBoss;
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "rage_heffe"))
		{
			HeffeRange = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "rage_heffe", 1);
			HeffeStunDuration = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "rage_heffe", 2, 10.0);	// Stun duration; Recommended to keep this value since it works perfectly with the sound file
			g_iButtonType = FF2_GetAbilityArgument(iIndex, this_plugin_name, "rage_heffe", 4, 2);				// Button type to use the ability; 1 = Secondary Fire, 2 = Reload, 3 = Special Attack

			SDKHook(iBoss, SDKHook_PreThink, Heffe_HUD);
			g_iSmiteNumber = 0;
			g_Boss = iBoss;
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "dot_heffe_jump"))
		{
			FlapDrain = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "dot_heffe_jump", 1, 5.0);						// Amount of rage drained per second
			FlapForce = FF2_GetAbilityArgument(iIndex, this_plugin_name, "dot_heffe_jump", 2, 75);								// Force multiplier of the jump
//			FlapRate =  GetEngineTime() + FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "dot_heffe_jump", 3, 1.5);		// Time between flaps
			FF2_GetAbilityArgumentString(iIndex, this_plugin_name, "dot_heffe_jump", 4, FlapSound, PLATFORM_MAX_PATH);			// Sound played on flap

			if(!IsEmptyString(FlapSound))
				PrecacheSound(FlapSound);

			CreateTimer(0.1, Timer_HeffeTick, iBoss, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			SDKHook(iBoss, SDKHook_PreThink, Heffe_HUD);
			HeffeUpdateHUD[iBoss] = GetEngineTime() + 0.2;
			g_bButtonPressed = false;
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "rage_therock"))
		{
			Rockduration[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "rage_therock", 1, 20.0);
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "rage_mine"))
		{
			FruitRageRange[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "rage_mine", 1, 325.0);
			FruitCanRemoveSentry[iBoss] = FF2_GetAbilityArgumentBool(iIndex, this_plugin_name, "rage_mine", 2);
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "charge_projectile"))
		{
			RocketCharge[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_projectile", 1, 5.0);
			RocketCooldown[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_projectile", 2, 5.0);
			RocketSpeed[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_projectile", 3, 1000.0);
			FF2_GetAbilityArgumentString(iIndex, this_plugin_name, "charge_projectile", 4, RocketModel[iBoss], PLATFORM_MAX_PATH);
			FF2_GetAbilityArgumentString(iIndex, this_plugin_name, "charge_projectile", 5, RocketParticle[iBoss], PLATFORM_MAX_PATH);
			RocketDamage[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_projectile", 6, 40.0);
			RocketStunTime[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_projectile", 7, 3.0);
			RocketRequiredRage[iBoss] = FF2_GetAbilityArgument(iIndex, this_plugin_name, "charge_projectile", 8, 10);

			for (int i=1; i<=MaxClients; i++) if(IsValidClient(i))
				SDKHook(i, SDKHook_OnTakeDamage, OnTakeRocketDamage);
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "special_pocketmedic"))
		{
			MedicJumpWeaponPreference[iBoss] = FF2_GetAbilityArgumentBool(iIndex, this_plugin_name, "special_pocketmedic", 1);	// 0 = use melee, else use medigun
			MedicTeleWeaponPreference[iBoss] = FF2_GetAbilityArgumentBool(iIndex, this_plugin_name, "special_pocketmedic", 2);	// 0 = use medigun, else use melee

			SDKHook(iBoss, SDKHook_WeaponCanSwitchToPost, WeaponSwitch);
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "special_jumpmanager"))
		{
			JM_ButtonType = FF2_GetAbilityArgument(iIndex, this_plugin_name, "special_jumpmanager", 1);	// Button for switching, 1 = reload, 2 = special attack, 3 = secondary attack
			MJT_ButtonType = FF2_GetAbilityArgument(iIndex, this_plugin_name, "special_jumpmanager", 2); // Button for activation, 1 = secondary attack, 2 = reload, 3 = special attack

			MJ_ChargeTime[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "special_jumpmanager", 3);		// Time it takes to charge
			MJ_Cooldown[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "special_jumpmanager", 4);		// Time it takes to refresh
			MJ_OnCooldownUntil[iBoss] = GetEngineTime() + FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "special_jumpmanager", 5);	// Time before first use

			MT_ChargeTime[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "special_jumpmanager", 6);		// Time it takes to charge
			MT_Cooldown[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "special_jumpmanager", 7);		// Time it takes to refresh
			MT_OnCooldownUntil[iBoss] = GetEngineTime() + FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "special_jumpmanager", 8);	// Time before first use

			SpawnWeapon(iBoss, "tf_weapon_spellbook", 1069, 0, 0, "", true, false);
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "charge_magicjump"))
		{
			MJ_ChargeTime[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_magicjump", 1);		// Time it takes to charge
			MJ_Cooldown[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_magicjump", 2);		// Time it takes to refresh
			MJ_OnCooldownUntil[iBoss] = GetEngineTime() + FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_magicjump", 3);	// Time before first use
			MJT_ButtonType = FF2_GetAbilityArgument(iIndex, this_plugin_name, "charge_magicjump", 4);	// Button for activation, 1 = secondary attack, 2 = reload, 3 = special attack

			SpawnWeapon(iBoss, "tf_weapon_spellbook", 1069, 0, 0, "", true, false);
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "charge_magictele"))
		{
			MT_ChargeTime[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_magictele", 1);		// Time it takes to charge
			MT_Cooldown[iBoss] = FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_magictele", 2);		// Time it takes to refresh
			MT_OnCooldownUntil[iBoss] = GetEngineTime() + FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "charge_magictele", 3);	// Time before first use
			MJT_ButtonType = FF2_GetAbilityArgument(iIndex, this_plugin_name, "charge_magictele", 4);	// Button for activation, 1 = secondary attack, 2 = reload, 3 = special attack

			SpawnWeapon(iBoss, "tf_weapon_spellbook", 1069, 0, 0, "", true, false);
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "special_spellattack"))
		{
			SS_CoolDown[iBoss] = GetEngineTime() + FF2_GetAbilityArgumentFloat(iIndex, this_plugin_name, "special_spellattack", 1);

			for(int i=1; i<=MaxClients; i++)
				SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "special_mlgsounds") || FF2_HasAbility(iIndex, this_plugin_name, "rage_mlg"))
		{
			SDKHook(iBoss, SDKHook_TraceAttack, TraceAttack);
			HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
			MLG[iBoss] = true;
		}

		if(FF2_HasAbility(iIndex, this_plugin_name, "special_norage"))
			SDKHook(iBoss, SDKHook_PreThink, NoRage_Think);
		if(FF2_HasAbility(iIndex, this_plugin_name, "special_noknockback"))
			SDKHook(iBoss, SDKHook_OnTakeDamage, NKBOnTakeDamage);

		SDKHook(iBoss, SDKHook_OnTakeDamage, CheckEnvironmentalDamage);
	}
}

public void Event_RoundEnd(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	for(int iClient=MaxClients; iClient>0 ; iClient--)
	{
		MJ_CrouchOrAltFireDownSince[iClient] = -1.0;
		MJ_EmergencyReady[iClient] = false;

		MT_CrouchOrAltFireDownSince[iClient] = -1.0;
		MT_EmergencyReady[iClient] = false;

		JM_AbilitySwitched[iClient] = false;

		SDKUnhook(iClient, SDKHook_StartTouch, OnRockTouch);
		SDKUnhook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKUnhook(iClient, SDKHook_OnTakeDamage, CheckEnvironmentalDamage);
		SDKUnhook(iClient, SDKHook_OnTakeDamage, OnTakeRocketDamage);
		SDKUnhook(iClient, SDKHook_OnTakeDamage, NKBOnTakeDamage);
		SDKUnhook(iClient, SDKHook_PreThink, NoRage_Think);
		SDKUnhook(iClient, SDKHook_TraceAttack, TraceAttack);

		if(MLG[iClient])
		{
			UnhookEvent("player_hurt", Event_PlayerHurt);
			MLG[iClient] = false;
		}
	}

	g_Boss = -1;
	g_bButtonPressed = false;
}

public Action Event_PlayerDeath(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	if (hEvent.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
		return Plugin_Continue;
	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	int iVictim = GetClientOfUserId(hEvent.GetInt("userid"));
	int att_index = FF2_GetBossIndex(iAttacker);
	//int vic_index = FF2_GetBossIndex(iVictim);
	if (att_index != -1)
	{
		if(FF2_HasAbility(att_index, this_plugin_name, "rage_therock"))
			SDKUnhook(iVictim, SDKHook_StartTouch, OnRockTouch);
	}
	else
	{
		if (GetClientTeam(iVictim)==BossTeam)
			SDKUnhook(iVictim, SDKHook_StartTouch, OnRockTouch);
	}

	if(MLG[iAttacker])
	{
		int iCustom = hEvent.GetInt("customkill");
		if(MLGRageTime[iAttacker] >= GetEngineTime())
		{
			hEvent.SetInt("customkill", TF_CUSTOM_HEADSHOT);
			iCustom = TF_CUSTOM_HEADSHOT;
		}

		if(iCustom == TF_CUSTOM_HEADSHOT)
		{
			float position[3];
			GetEntPropVector(iAttacker, Prop_Data, "m_vecOrigin", position);

			char sound[PLATFORM_MAX_PATH];
			if (FF2_RandomSound("sound_headshot", sound, PLATFORM_MAX_PATH, att_index))
			{
				EmitSoundToAll(sound, iAttacker, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iAttacker, position, NULL_VECTOR, true, 0.0);

				for (int enemy=MaxClients; enemy>0 ; enemy--)
				{
					if (IsClientInGame(enemy) && enemy != iAttacker)
					{
						EmitSoundToClient(enemy, sound, iAttacker, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iAttacker, position, NULL_VECTOR, true, 0.0);
					}
				}
			}
		}
	}

	if(DiedRapture[iVictim] > GetEngineTime())
	{
		hEvent.SetString("weapon_logclassname", "alien_abduction");
		hEvent.SetString("weapon", "merasmus_zap");

		DataPack hData;
		CreateDataTimer(0.01, Timer_DissolveRagdoll, hData);
		hData.WriteCell(iVictim);
		hData.WriteCell(0);
	}
	return Plugin_Continue;
}

public Action Event_PlayerHurt(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState() != 1)
		return Plugin_Continue;

	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));

	if(!IsValidClient(iClient, true) || !IsValidClient(iAttacker, true, true) || iClient == iAttacker)
		return Plugin_Continue;

	if(MLG[iAttacker])
	{
		if(MLGRageTime[iAttacker] >= GetEngineTime())
		{
			hEvent.SetBool("crit", true);
			hEvent.SetBool("allseecrit", true);
			hEvent.SetInt("damageamount", 1337);
		}
	}
	return Plugin_Continue;
}

public Action Event_Jarate(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	int iClient = BfReadByte(msg);
	int iVictim = BfReadByte(msg);
	if(IsValidClient(iVictim))
	{
		if(FF2_HasAbility(0, this_plugin_name, "rage_wanker"))
		{
			if (WankerPissMode[iClient])
			{
				CreateTimer(0.1, Timer_NoPiss, GetClientUserId(iVictim));
				WankerPissDuration[iClient] *= 2.0;
			}
			TF2_MakeBleed(iVictim, iClient, WankerPissDuration[iClient]);
		}
	}
}

public Action OnTakeRocketDamage(int iClient, int &iAttacker, int &iInflictor, float &flDamage, int &iDmgType, int &iWeapon, float vDmgForce[3], float vDmgPos[3], int iDmgCstm)
{
	if (!IsValidClient(iAttacker, true))
		return Plugin_Continue;

	int iBoss = FF2_GetBossIndex(iAttacker);
	if (FF2_HasAbility(iBoss, this_plugin_name, "charge_projectile") && GetClientTeam(iClient) == MercTeam)
	{
		char sClassname[64];
		GetEntityClassname(iInflictor, sClassname, sizeof(sClassname));
		if (!strcmp(sClassname, "tf_projectile_rocket"))
			if (RocketStunTime[iAttacker] > 0.25)
				TF2_StunPlayer(iClient, RocketStunTime[iAttacker], 0.0, TF_STUNFLAGS_NORMALBONK, iAttacker);
	}

	return Plugin_Continue;
}

public Action OnTakeDamage(int iClient, int &iAttacker, int &iInflictor, float &flDamage, int &iDmgType, int &iWep, float flDmgForce[3], float flDmgPos[3], int iDmgCstm)
{
	if (!IsValidClient(iAttacker) || GetClientTeam(iAttacker)!=BossTeam)
		return Plugin_Continue;

	int iBoss = FF2_GetBossIndex(iAttacker);
	if(FF2_HasAbility(iBoss, this_plugin_name, "special_spellattack"))
	{
		flDamage *= 0.2;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action TraceAttack(int iVictim, int &iAttacker, int &iInflictor, float &flDmg, int &iDmgType, int &iAmmotype, int iHitBox, int iHitGroup)
{
	if(!IsValidClient(iVictim, true) || !IsValidClient(iAttacker, true, true))
		return Plugin_Continue;

	if(iHitBox == 0)	// bip_head is usually 0
	{
		float position[3]; char sound[PLATFORM_MAX_PATH];
		int iBoss = FF2_GetBossIndex(iAttacker);

		GetEntPropVector(iAttacker, Prop_Data, "m_vecOrigin", position);
		if (FF2_RandomSound("sound_headshot", sound, PLATFORM_MAX_PATH, iBoss))
		{
			EmitSoundToAll(sound, iAttacker, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iAttacker, position, NULL_VECTOR, true, 0.0);

			for (int enemy=MaxClients; enemy>0 ; enemy--)
			{
				if (IsClientInGame(enemy) && enemy != iAttacker)
				{
					EmitSoundToClient(enemy, sound, iAttacker, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iAttacker, position, NULL_VECTOR, true, 0.0);
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action CheckEnvironmentalDamage(int iClient, int &iAttacker, int &iInflictor, float &flDmg, int &iDmgType, int &iWep, float flDmgForce[3], float flDmgPos[3], int iDmgCstm)
{
	if (!IsValidClient(iClient, true))
		return Plugin_Continue;

	if (iAttacker == 0 && iInflictor == 0 && (iDmgType & DMG_FALL) != 0)
		return Plugin_Continue;

	// ignore damage from players
	if (iAttacker >= 1 && iAttacker <= MaxClients)
		return Plugin_Continue;

	int iBoss = FF2_GetBossIndex(iClient);

	if (FF2_HasAbility(iBoss, this_plugin_name, "charge_magicjump") || FF2_HasAbility(iBoss, this_plugin_name, "special_jumpmanager"))
	{
		if (flDmg > 50.0)
		{
			MJ_EmergencyReady[iClient] = true;
			MJ_OnCooldownUntil[iClient] = -1.0;
		}
	}

	if (FF2_HasAbility(iBoss, this_plugin_name, "charge_magictele") || FF2_HasAbility(iBoss, this_plugin_name, "special_jumpmanager"))
	{
		if (flDmg > 50.0)
		{
			MT_EmergencyReady[iClient] = true;
			MT_OnCooldownUntil[iClient] = -1.0;
		}
	}

	return Plugin_Continue;
}

public Action NKBOnTakeDamage(int iClient, int &iAttacker, int &iInflictor, float &flDamage, int &iDmgType, int &iWeapon, float flDmgForce[3], float flDmgPos[3], int DmgCstm)
{
	if(!IsValidClient(iAttacker, true))
		return Plugin_Continue;

	if(IsValidClient(iClient, true, true))
	{
		iDmgType |= DMG_PREVENT_PHYSICS_FORCE;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action WeaponSwitch(int iClient, int iWeapon)
{
	if(MedicJumpWeaponPreference[iClient])
	{
		if(GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee) == iWeapon)
			DD_SetDisabled(iClient, false, true, true, false);
	}
	else
	{
		if(GetPlayerWeaponSlot(iClient, TFWeaponSlot_Secondary) == iWeapon)
			DD_SetDisabled(iClient, false, true, true, false);
	}

	if(MedicTeleWeaponPreference[iClient])
	{
		if(GetPlayerWeaponSlot(iClient, TFWeaponSlot_Secondary) == iWeapon)
			DD_SetDisabled(iClient, true, false, true, false);
	}
	else
	{
		if(GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee) == iWeapon)
			DD_SetDisabled(iClient, true, false, true, false);
	}

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float vVel[3], float vAng[3], int &iWeapon, int &iIndex, int &iSlot)
{
	if(!IsValidClient(iClient, true, true))
		return Plugin_Continue;

	if(!FF2_IsFF2Enabled() || FF2_GetRoundState() != 1)
		return Plugin_Continue;

	int iBoss = FF2_GetBossIndex(iClient);
	if(FF2_HasAbility(iBoss, this_plugin_name, "rage_heffe"))
	{
		if(!FF2_IsFF2Enabled() || FF2_GetRoundState() != 1)
			return Plugin_Continue;

		int Button;
		switch(g_iButtonType)
		{
			case 1: Button = IN_RELOAD;
			case 2: Button = IN_ATTACK3;
		}

		if((iButtons & Button) && g_iSmiteNumber > 0)
		{
			float vPos1[3], vPos2[3], flDist;

			GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", vPos1);
			for(int i=MaxClients; i>0; i--)
			{
				if(IsValidClient(i) && IsClientInGame(i))
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", vPos2);
					flDist = GetVectorDistance(vPos1, vPos2);
					if (flDist < HeffeRange && GetClientTeam(i)!=BossTeam)
					{
						if(IsPlayerAlive(i))
						{
							PerformSmite(iClient, i);
							break;
						}
					}
				}
			}
		}
	}

	if(FF2_HasAbility(iBoss, this_plugin_name, "dot_heffe_jump"))
	{
		if(iButtons & IN_ATTACK2)
		{
			if(!g_bButtonPressed)
			{
				g_bButtonPressed = true;
				CreateTimer(1.0, Timer_DrainTick, iClient, TIMER_REPEAT);
			}
			else g_bButtonPressed = false;
		}
	}

	if(FF2_HasAbility(iBoss, this_plugin_name, "special_jumpmanager"))
	{
		JM_Tick(iClient, iButtons, GetEngineTime());

		int Button;
		switch(JM_ButtonType)
		{
			case 1: Button = IN_RELOAD;
			case 2: Button = IN_ATTACK3;
			case 3: Button = IN_ATTACK2;
		}

		if(iButtons & Button)
		{
			if(!JM_AbilitySwitched[iClient])
				JM_AbilitySwitched[iClient] = true;
			else JM_AbilitySwitched[iClient] = false;
		}
	}

	if(FF2_HasAbility(iBoss, this_plugin_name, "charge_magicjump"))
	{
		MJ_Tick(iClient, iButtons, GetEngineTime());
	}

	if(FF2_HasAbility(iBoss, this_plugin_name, "charge_magictele"))
	{
		MT_Tick(iClient, iButtons, GetEngineTime());
	}

	if(FF2_HasAbility(iBoss, this_plugin_name, "special_spellattack"))
	{
		if(iButtons & IN_ATTACK)
		{
			if(GetEngineTime() >= SS_CoolDown[iClient])
			{
				ShootProjectile(iClient, "tf_projectile_spellfireball");
				SS_CoolDown[iClient] = GetEngineTime() + FF2_GetAbilityArgumentFloat(iBoss, this_plugin_name, "special_spellattack", 1);

				float position[3];
				GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", position);

				char sound[PLATFORM_MAX_PATH];
				if (FF2_RandomSound("sound_ability", sound, PLATFORM_MAX_PATH, iBoss, 4))
				{
					EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
					EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);

					for (int enemy = 1; enemy < MaxClients; enemy++)
					{
						if (IsClientInGame(enemy) && enemy != iClient)
						{
							EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
							EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
						}
					}
				}
			}
			else iButtons &= ~IN_ATTACK;
		}
	}

	return Plugin_Continue;
}

public Action FF2_OnLoseLife(int iIndex)
{
	int iClient = GetClientOfUserId(FF2_GetBossUserId(iIndex));
	if(iIndex == -1 || !IsValidClient(iClient, true, true))
		return Plugin_Continue;

	if(FF2_HasAbility(iIndex, this_plugin_name, "heffe_reincarn_rapture"))
	{
		Handle data;
		CreateDataTimer(RaptureTimer, Timer_Abduction, data, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(data, iClient);
		WritePackCell(data, RaptureIteration);		   // iterations

		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != BossTeam)
				PerformBlind(i, RaptureBlindTime);
		}

		TF2_AddCondition(iClient, TFCond_Ubercharged, RaptureDuration);
		TF2_StunPlayer(iClient, RaptureDuration, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT);
	}

	return Plugin_Continue;
}



////////////////////////////////////////
//	Abilities start below this point  //
////////////////////////////////////////

void Rage_Wanker(int iBoss)
{
	int iClient = GetClientOfUserId(FF2_GetBossUserId(iBoss));

	TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Secondary);
	if(!WankerPissMode[iClient])				//Whether it's jarate and bleed, or just bleed; 1 = just bleed
		SpawnWeapon(iClient, "tf_weapon_jar", 58, 100, 5, "149 ; 15.0 ; 134 ; 12.0 ; 175 ; 15.0", true, true);
		//149 - 15 second bleed
		//175 - 15 second jarate
		//134 - Applies particle of id 12
	else
		SpawnWeapon(iClient, "tf_weapon_jar", 58, 100, 5, "149 ; 30.0 ; 134 ; 12.0", true, true);
		//149 - 30 second bleed
		//134 - Applies particle of id 12
	SetAmmo(iClient, TFWeaponSlot_Secondary, WankerAmmo[iClient]);
}

void Rage_Heffe(int iBoss, const char[] ability_name)
{
	if (Heffe_TriggerAMS[iBoss]) // Prevent normal 100% RAGE activation if using AMS
	{
		if (!LibraryExists("FF2AMS")) // Fail state?
		{
			Heffe_TriggerAMS[iBoss]=false;
		}
		else
		{
			return;
		}
	}
	HEFFE_Invoke(iBoss, -1, ability_name); // Activate RAGE normally, if ability is configured to be used as a normal RAGE.
}

public void HEFFE_Invoke(int iBoss, int index, const char[] ability_name)
{
	int iClient = GetClientOfUserId(FF2_GetBossUserId(iBoss));
	g_iSmiteNumber = FF2_GetAbilityArgument(iBoss, this_plugin_name, ability_name, 3, 3);			// Number of available smite abilities per rage

	float flPos1[3], flPos2[3], flDist;

	GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", flPos1);
	TF2_StunPlayer(iClient, HeffeStunDuration, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT, iClient);
	for(int i=1; i<=MaxClients; i++)
	{
		if(IsValidClient(i) && IsClientInGame(i) && IsPlayerAlive(i))
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", flPos2);
			flDist = GetVectorDistance(flPos1, flPos2);
			if (flDist <= HeffeRange && GetClientTeam(i)!=BossTeam)
				TF2_StunPlayer(i, HeffeStunDuration, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT, iClient);
		}
	}
}

void Rage_TheRock(int iBoss)
{
	int iClient = GetClientOfUserId(FF2_GetBossUserId(iBoss));

	if(GetClientTeam(iClient)==BossTeam)
	{
		SDKHook(iClient, SDKHook_StartTouch, OnRockTouch);
		TF2_AddCondition(iClient, TFCond_MegaHeal, Rockduration[iClient]);
		TF2_AddCondition(iClient, TFCond_SpeedBuffAlly, Rockduration[iClient]);
		CreateTimer(Rockduration[iClient], UnHook, iClient);
		SetEntProp(iClient, Prop_Send, "m_CollisionGroup", 2);
	}
}

void Rage_Mine(int iBoss)
{
	int iClient = GetClientOfUserId(FF2_GetBossUserId(iBoss));
	float flPos[3], flPos2[3], flDistance;

	GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", flPos);
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)!=BossTeam)
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", flPos2);
			flDistance = GetVectorDistance(flPos, flPos2);
			if (flDistance <= FruitRageRange[iClient] && GetClientTeam(i)!=BossTeam)
			{
				switch (GetRandomInt(1, 3))	// Removes players weapons, Primary has higher chance then Secondary, as what good would a Medic be if he lost his medigun?
				{
					case 1:
						TF2_RemoveWeaponSlot(i, TFWeaponSlot_Secondary);
					case 2:
						TF2_RemoveWeaponSlot(i, TFWeaponSlot_Primary);
					case 3:
						TF2_RemoveWeaponSlot(i, TFWeaponSlot_Primary);
				}
				// Set's the players active weapon if the weapon they were using was removed
				if (GetPlayerWeaponSlot(i, 0) == -1 && GetPlayerWeaponSlot(i, 1) == -1)
					SwitchtoSlot(i, TFWeaponSlot_Melee);
				else if (GetPlayerWeaponSlot(i, 1) == -1)
					SwitchtoSlot(i, TFWeaponSlot_Primary);
				else if (GetPlayerWeaponSlot(i, 0) == -1)
					SwitchtoSlot(i, TFWeaponSlot_Secondary);
			}
		}
	}
	int iSentry = -1;
	while((iSentry = FindEntityByClassname(iSentry, "obj_sentrygun")) != -1)
	{
		if(IsValidEdict(iSentry) && FruitCanRemoveSentry[iClient])
		{
			GetEntPropVector(iSentry, Prop_Send, "m_vecOrigin", flPos2);
			flDistance = GetVectorDistance(flPos, flPos2);
			if(flDistance <= FruitRageRange[iClient])
			{
				if(!GetRandomInt(0, 1))
				{
					SetVariantInt(999);
					AcceptEntityInput(iSentry, "RemoveHealth");
				}
			}
		}
	}
}

void Rage_SkeleSummon(int iBoss, const char[] ability_name)
{
	int iClient = GetClientOfUserId(FF2_GetBossUserId(iBoss));
	SkeleNumberOfSpawns[iClient] = FF2_GetAbilityArgument(iBoss, this_plugin_name, ability_name, 1);

	SDKHook(ShootProjectile(iClient, "tf_projectile_spellspawnhorde"), SDKHook_StartTouch, Projectile_Touch);
}

void Rage_MLG(int iBoss, const char[] ability_name)
{
	int iClient = GetClientOfUserId(FF2_GetBossUserId(iBoss));
	MLGRageTime[iClient] = GetEngineTime() + FF2_GetAbilityArgumentFloat(iBoss, this_plugin_name, ability_name, 1);
	SDKHook(iClient, SDKHook_PreThink, AimThink);
}

void Charge_RocketSpawn(int iBoss, int iSlot, int iAction)	// Shamelessly stolen code from Friagram and EggMan
{
	float flZeroCharge = FF2_GetBossCharge(iBoss, 0);
	int iClient = GetClientOfUserId(FF2_GetBossUserId(iBoss));
	float flCharge = FF2_GetBossCharge(iBoss, iSlot);
	if(flZeroCharge < RocketRequiredRage[iClient])
	{
		SetHudTextParams(-1.0, 0.93, 1.0, 255, 255, 255, 255);
		ShowSyncHudText(iClient, chargeHUD, "Requires at least %d Rage!", RocketRequiredRage[iClient]);
		return;
	}
	switch(iAction)
	{
		case 1:
		{
			SetHudTextParams(-1.0, 0.93, 0.15, 255, 255, 255, 255);
			ShowSyncHudText(iClient, chargeHUD, "Charge is at %i percent. Let go of the charge button when at 100%", -RoundFloat(flCharge*10/RocketCharge[iClient]));
		}
		case 2:
		{
			SetHudTextParams(-1.0, 0.93, 0.15, 255, 255, 255, 255);
			if(flCharge+1 < RocketCharge[iClient])
				FF2_SetBossCharge(iClient, iSlot, flCharge+1);
			else
				flCharge = RocketCharge[iClient];
			ShowSyncHudText(iClient, chargeHUD, "Your charged ability will be available in %i second(s).", RoundFloat(flCharge*100/RocketCharge[iClient]));
		}
		default:
		{
			if (flCharge <= 0.2)
			{
				SetHudTextParams(-1.0, 0.93, 0.15, 255, 255, 255, 255);
				ShowSyncHudText(iClient, chargeHUD, "Your charged ability is ready!");
			}
			if (flCharge >= RocketCharge[iClient])
			{
				FF2_SetBossCharge(iBoss, 0, flZeroCharge - RocketRequiredRage[iClient]);
				float pos[3], rot[3], vel[3];
				GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", pos);
				GetClientEyeAngles(iClient, rot);
				pos[2]+=63;

				int iProj = CreateEntityByName("tf_projectile_rocket");
				SetVariantInt(BossTeam);
				AcceptEntityInput(iProj, "TeamNum", -1, -1, 0);
				SetVariantInt(BossTeam);
				AcceptEntityInput(iProj, "SetTeam", -1, -1, 0);
				SetEntPropEnt(iProj, Prop_Send, "m_hOwnerEntity", iClient);

				vel[0] = Cosine(DegToRad(rot[0]))*Cosine(DegToRad(rot[1]))*RocketSpeed[iClient];
				vel[1] = Cosine(DegToRad(rot[0]))*Sine(DegToRad(rot[1]))*RocketSpeed[iClient];
				vel[2] = Sine(DegToRad(rot[0]))*RocketSpeed[iClient];
				vel[2]*=-1;

				TeleportEntity(iProj, pos, rot, vel);
				SetEntProp(iProj, Prop_Send, "m_bCritical", 1);
				SetEntDataFloat(iProj, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, RocketDamage[iClient], true);
				DispatchSpawn(iProj);

				if(strlen(RocketModel[iClient]) > 5)
					SetEntityModel(iProj, RocketModel[iClient]);
				if(strlen(RocketParticle[iClient]) > 2)
					CreateTimer(15.0, RemoveEnt, EntIndexToEntRef(AttachParticle(iProj, RocketParticle[iClient], _, true)));

				char s[PLATFORM_MAX_PATH];
				if(FF2_RandomSound("sound_ability", s, PLATFORM_MAX_PATH, iBoss, iSlot))
				{
					EmitSoundToAll(s, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, pos, NULL_VECTOR, true, 0.0);
					EmitSoundToAll(s, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, pos, NULL_VECTOR, true, 0.0);

					for(int i=1; i<=MaxClients; i++)
						if(IsClientInGame(i) && i != iClient)
						{
							EmitSoundToClient(i, s, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, pos, NULL_VECTOR, true, 0.0);
							EmitSoundToClient(i, s, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, pos, NULL_VECTOR, true, 0.0);
						}
				}

				Handle hData;
				CreateDataTimer(0.2, Timer_StartCD, hData);
				WritePackCell(hData, iBoss);
				WritePackCell(hData, iSlot);
				WritePackFloat(hData, -RocketCooldown[iClient]);
				ResetPack(hData);
			}
		}
	}
}



/////////////////////////////////////
//	Timers start below this point  //
/////////////////////////////////////


/**
*Deprecated
*
*public Action:Timer_RemoveWeaponS(Handle:hTimer, any:iClient)
*{
*	if (IsValidClient(iClient)) TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Secondary);
*		 EquipPlayerWeapon(iClient, GetPlayerWeaponSlot(iClient, 2));
*}
*public Action:Timer_RemoveWeaponP(Handle:timer, any:iClient)
*{
*	if (IsValidClient(iClient)) TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Primary);
*		 EquipPlayerWeapon(iClient, GetPlayerWeaponSlot(iClient, 2));
*}
**/

public Action Timer_ResetMoveType(Handle hTimer, any iClient) {
	if (IsValidClient(iClient) && (GetEntityMoveType(iClient)==MOVETYPE_FLY || GetEntityMoveType(iClient)==MOVETYPE_NONE))
		SetEntityMoveType(iClient, MOVETYPE_WALK);
}

public Action Timer_NoPiss(Handle hTimer, any iClient) {
	if (IsValidClient(iClient))
		TF2_RemoveCondition(iClient, TFCond_Jarated);
}

public Action RemoveEnt(Handle hTimer, any entid)
{
	int iEntity = EntRefToEntIndex(entid);
	if (IsValidEdict(iEntity))
	{
		if (iEntity > MaxClients)
			AcceptEntityInput(iEntity, "Kill");
	}
}

/*public Action Timer_SwitchToSlot(Handle hTimer, any iClient)
{
	if(IsValidClient(iClient, true))
		SwitchtoSlot(iClient, 2);
}*/

public Action UnHook(Handle hTimer, any Boss)
{
	if(IsValidClient(Boss))
	{
		SDKUnhook(Boss, SDKHook_StartTouch, OnRockTouch);
		SetEntProp(Boss, Prop_Send, "m_CollisionGroup", 5);
	}
}

public Action Timer_StartCD(Handle hTimer, Handle hData)
{
	int iClient = ReadPackCell(hData);
	int iSlot = ReadPackCell(hData);
	float flSee = ReadPackFloat(hData);
	FF2_SetBossCharge(iClient, iSlot, flSee);
}

public Action Timer_HeffeTick(Handle hTimer, any iClient)
{
	if(g_bButtonPressed)
	{
//		int Boss = FF2_GetBossIndex(iClient);
		if((GetClientButtons(iClient) & IN_JUMP)/* && GetEngineTime() >= g_flFlapRate*/)	// Enforce a time limit between flaps
		{
			float flPos[3], flRot[3], flVel[3];
			GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", flPos);
			GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", flVel);
			GetClientEyeAngles(iClient, flRot);

			flVel[0] += Cosine(DegToRad(flRot[0]))*Cosine(DegToRad(flRot[1]))*FlapForce;
			flVel[1] += Cosine(DegToRad(flRot[0]))*Sine(DegToRad(flRot[1]))*FlapForce;
			flVel[2] = (750.0+175.0*FlapForce/70);

			TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, flVel);
//			FlapRate =  GetEngineTime() + FF2_GetAbilityArgumentFloat(Boss, this_plugin_name, "dot_heffe_jump", 2, 1.5);

			if(!IsEmptyString(FlapSound))
				EmitAmbientSound(FlapSound, flPos, iClient);
		}
	}

	if(FF2_GetRoundState() != 1)	// So I don't need an event_round_end
		return Plugin_Stop;

	return Plugin_Continue;
}

public Action Timer_DrainTick(Handle hTimer, any iClient)
{
	int Boss = FF2_GetBossIndex(iClient);

	float flRage = FF2_GetBossCharge(Boss, 0);
	flRage -= FlapDrain;

	if (flRage < 0.0)
	{
		g_bButtonPressed = false;
		flRage = 0.0;
		PrintCenterText(iClient, "Out of rage!");
	}

	FF2_SetBossCharge(Boss, 0, flRage);

	if(!g_bButtonPressed)
		return Plugin_Stop;

	if(FF2_GetRoundState() != 1)	// So I don't need an event_round_end
		return Plugin_Stop;

	return Plugin_Continue;
}

public Action Timer_Abduction(Handle hTimer, Handle pack)
{
	ResetPack(pack);

	int Boss = ReadPackCell(pack);
	int iIterations = ReadPackCell (pack);
	if (IsValidClient(Boss, true, true))
	{
		Abduct(Boss);

		if(--iIterations)
		{
			DataPack hData;
			CreateDataTimer(RaptureTimer, Timer_Abduction, hData, TIMER_FLAG_NO_MAPCHANGE);
			hData.WriteCell(Boss);
			hData.WriteCell(iIterations);
		}
	}
}

public Action Timer_RemovePod(Handle hTimer, any ref)
{
	int ent = EntRefToEntIndex(ref);
	if(ent != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(ent, "Disable");

		CreateTimer(0.1, RemoveEnt, ref, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_RemoveRagdoll(Handle hTimer, any userid)
{
	int iVictim = GetClientOfUserId(userid);
	if(iVictim && IsClientInGame(iVictim))
	{
		int iRagdoll = GetEntPropEnt(iVictim, Prop_Send, "m_hRagdoll");
		if (iRagdoll > MaxClients)
		{
			AcceptEntityInput(iRagdoll, "Kill");
		}
	}
}

public Action Timer_DissolveRagdoll(Handle hTimer, Handle pack)
{
	ResetPack(pack);
	int iVictim = GetClientOfUserId(ReadPackCell(pack));
	if(iVictim && IsClientInGame(iVictim))
	{
		int iRagdoll = GetEntPropEnt(iVictim, Prop_Send, "m_hRagdoll");
		if (iRagdoll != -1)
		{
			Dissolve(iRagdoll, ReadPackCell(pack));
		}
	}
}



/////////////////////////////////////
//	Stocks start below this point  //
/////////////////////////////////////

public void NoRage_Think(int iClient)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		SDKUnhook(iClient, SDKHook_PreThink, NoRage_Think);
	FF2_SetBossCharge(iClient, 0, 0.0);
}

public void Heffe_HUD(int iClient)
{
	if(GetClientButtons(iClient) & IN_SCORE)
		return;

	if (GetEngineTime() >= HeffeUpdateHUD[iClient])
	{
		if(g_iSmiteNumber > 0)
		{
			SetHudTextParams(-1.0, 0.62, 0.21, 255, 255, 255, 192);
			ShowSyncHudText(iClient, heffeHUD, "Smite number remaining: %d", g_iSmiteNumber);
		}

		int Boss = FF2_GetBossIndex(iClient);
		if(FF2_HasAbility(Boss, this_plugin_name, "dot_heffe_jump"))
		{
			SetHudTextParams(-1.0, 0.88, 0.21, 255, 255, 255, 192);
			ShowSyncHudText(iClient, jumpHUD, "Flying is %sabled, press Secondary Fire to toggle", g_bButtonPressed ? "En" : "Dis");
		}

		HeffeUpdateHUD[iClient] = GetEngineTime() + 0.2;
	}

	if(FF2_GetRoundState() != 1)	// So I don't need an event_round_end
		SDKUnhook(iClient, SDKHook_PreThink, Heffe_HUD);
}

public Action OnRockTouch(int Boss, int iEntity)
{
	if(GetClientTeam(Boss) != BossTeam)
	{
		SDKUnhook(Boss, SDKHook_Touch, OnRockTouch);
		return;
	}

	static float origin[3], angles[3], targetpos[3];
	if(IsValidClient(iEntity) && GetClientTeam(iEntity)!=BossTeam)
	{
		GetClientEyeAngles(Boss, angles);
		GetClientEyePosition(Boss, origin);
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", targetpos);
		GetAngleVectors(angles, angles, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(angles, angles);
		SubtractVectors(targetpos, origin, origin);

		if(GetVectorDotProduct(origin, angles) > 0.0 && !IsPlayerInvincible(iEntity))
		{
			SDKHooks_TakeDamage(iEntity, Boss, Boss, 15.0, DMG_CRUSH|DMG_PREVENT_PHYSICS_FORCE|DMG_ALWAYSGIB);	// Make boss get credit for the kill
			FakeClientCommandEx(iEntity, "explode");
		}
	}
}

public void MJ_Tick(int iClient, int iButtons, float flTime)
{
	int Boss = FF2_GetBossIndex(iClient);
	if(FF2_HasAbility(Boss, this_plugin_name, "special_jumpmanager"))	// Prevent possible double up conflicts
		return;

	if (flTime >= MJ_OnCooldownUntil[iClient] && MJ_OnCooldownUntil[iClient] != -1.0)
		MJ_OnCooldownUntil[iClient] = -1.0;

	float flCharge = 0.0;
	if (MJ_OnCooldownUntil[iClient] == -1.0)
	{
		// get charge percent here, used by both the HUD and the actual jump
		if (MJ_CrouchOrAltFireDownSince[iClient] != -1.0)
		{
			if (MJ_ChargeTime[iClient] <= 0.0)
				flCharge = 100.0;
			else
				flCharge = fmin((flTime - MJ_CrouchOrAltFireDownSince[iClient]) / MJ_ChargeTime[iClient], 1.0) * 100.0;
		}

		char Button;
		switch(MJT_ButtonType)
		{
			case 1: Button = IN_ATTACK2;
			case 2: Button = IN_RELOAD;
			case 3: Button = IN_ATTACK3;
		}

		// do we start the charging now?
		if (MJ_CrouchOrAltFireDownSince[iClient] == -1.0 && (iButtons & Button) != 0)
			MJ_CrouchOrAltFireDownSince[iClient] = flTime;

		// has key been released?
		if (MJ_CrouchOrAltFireDownSince[iClient] != -1.0 && (iButtons & Button) == 0)
		{
			if (!IsInInvalidCondition(iClient))
			{
				MJ_OnCooldownUntil[iClient] = flTime + MJ_Cooldown[iClient];

				// taken from default_abilities, modified only lightly
				float position[3];
				float velocity[3];
				GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", position);
				GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", velocity);

				int spellbook = FindSpellBook(iClient);
				SetEntProp(spellbook, Prop_Send, "m_iSelectedSpellIndex", 4);
				SetEntProp(spellbook, Prop_Send, "m_iSpellCharges", 1);
				FakeClientCommand(iClient, "use tf_weapon_spellbook");

				// for the sake of making this viable, I'm keeping an actual jump, but half the power of a standard jump
				if (MJ_EmergencyReady[iClient])
				{
					velocity[2] = (750 + (flCharge / 4) * 13.0) + 2000 * 0.75;
					MJ_EmergencyReady[iClient] = false;
				}
				else
				{
					velocity[2] = (750 + (flCharge / 4) * 13.0) * 0.5;
				}
				SetEntProp(iClient, Prop_Send, "m_bJumping", 1);
				velocity[0] *= (1 + Sine((flCharge / 4) * FLOAT_PI / 50)) * 0.5;
				velocity[1] *= (1 + Sine((flCharge / 4) * FLOAT_PI / 50)) * 0.5;

				TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, velocity);
				char sound[PLATFORM_MAX_PATH];
				if (FF2_RandomSound("sound_magjump", sound, PLATFORM_MAX_PATH, Boss))
				{
					EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
					EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);

					for (int enemy = 1; enemy < MaxClients; enemy++)
					{
						if (IsClientInGame(enemy) && enemy != iClient)
						{
							EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
							EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
						}
					}
				}
			}

			// regardless of outcome, cancel the charge.
			MJ_CrouchOrAltFireDownSince[iClient] = -1.0;
		}
	}

	// draw the HUD if it's time
	if (flTime >= WitchDoctorUpdateHUD[iClient])
	{
		if (!(GetClientButtons(iClient) & IN_SCORE))
		{
			if (MJ_EmergencyReady[iClient])
			{
				SetHudTextParams(-1.0, 0.88, 0.21, 225, 64, 64, 192);
				ShowSyncHudText(iClient, witchdoctorHUD, "Super DUPER Jump ready! Press and release %s!", GetMJTButton());
			}
			else if (MJ_OnCooldownUntil[iClient] == -1.0)
			{
				SetHudTextParams(-1.0, 0.88, 0.21, 255, 255, 255, 192);
				ShowSyncHudText(iClient, witchdoctorHUD, "Magic Jump is ready. %.0f percent charged.\nPress and release %s!", flCharge, GetMJTButton());
			}
			else
			{
				SetHudTextParams(-1.0, 0.88, 0.21, 225, 64, 64, 192);
				ShowSyncHudText(iClient, witchdoctorHUD, "Magic Jump is not ready. %.1f seconds remaining.", MJ_OnCooldownUntil[iClient] - flTime);
			}
		}

		WitchDoctorUpdateHUD[iClient] = flTime + 0.2;
	}
}

public void MT_Tick(int iClient, int iButtons, float flTime)
{
	int Boss = FF2_GetBossIndex(iClient);
	if(FF2_HasAbility(Boss, this_plugin_name, "special_jumpmanager"))	// Prevent possible double up conflicts
		return;

	if (flTime >= MT_OnCooldownUntil[iClient] && MT_OnCooldownUntil[iClient] != -1.0)
		MT_OnCooldownUntil[iClient] = -1.0;

	float flCharge = 0.0;
	if (MT_OnCooldownUntil[iClient] == -1.0)
	{
		// get charge percent here, used by both the HUD and the actual jump
		if (MT_CrouchOrAltFireDownSince[iClient] != -1.0)
		{
			if (MT_ChargeTime[iClient] <= 0.0)
				flCharge = 100.0;
			else
				flCharge = fmin((flTime - MT_CrouchOrAltFireDownSince[iClient]) / MT_ChargeTime[iClient], 1.0) * 100.0;
		}

		char Button;
		switch(MJT_ButtonType)
		{
			case 1: Button = IN_ATTACK2;
			case 2: Button = IN_RELOAD;
			case 3: Button = IN_ATTACK3;
		}

		// do we start the charging now?
		if (MT_CrouchOrAltFireDownSince[iClient] == -1.0 && (iButtons & Button) != 0)
			MT_CrouchOrAltFireDownSince[iClient] = flTime;

		// has key been released?
		if (MT_CrouchOrAltFireDownSince[iClient] != -1.0 && (iButtons & Button) == 0)
		{
			if (!IsInInvalidCondition(iClient))
			{
				MT_OnCooldownUntil[iClient] = flTime + MT_Cooldown[iClient];

				int spellbook = FindSpellBook(iClient);
				SetEntProp(spellbook, Prop_Send, "m_iSelectedSpellIndex", 6);
				SetEntProp(spellbook, Prop_Send, "m_iSpellCharges", 1);
				FakeClientCommand(iClient, "use tf_weapon_spellbook");

				// just because I can see this becoming an immediate problem, gonna add an emergency teleport
				if (MT_EmergencyReady[iClient])
				{
					if (DD_PerformTeleport(iClient, 2.0, _, true))
					{
						MT_EmergencyReady[iClient] = false;
					}
				}

				float position[3];
				GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", position);

				char sound[PLATFORM_MAX_PATH];
				if (FF2_RandomSound("sound_magtele", sound, PLATFORM_MAX_PATH, Boss))
				{
					EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
					EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);

					for (int enemy = 1; enemy < MaxClients; enemy++)
					{
						if (IsClientInGame(enemy) && enemy != iClient)
						{
							EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
							EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
						}
					}
				}
			}

			// regardless of outcome, cancel the charge.
			MT_CrouchOrAltFireDownSince[iClient] = -1.0;
		}
	}

	// draw the HUD if it's time
	if (flTime >= WitchDoctorUpdateHUD[iClient])
	{
		if (!(GetClientButtons(iClient) & IN_SCORE))
		{
			if (MT_EmergencyReady[iClient])
			{
				SetHudTextParams(-1.0, 0.88, 0.21, 225, 64, 64, 192);
				ShowSyncHudText(iClient, witchdoctorHUD, "EMERGENCY TELEPORT! Press and release %s!", GetMJTButton());
			}
			else if (MT_OnCooldownUntil[iClient] == -1.0)
			{
				SetHudTextParams(-1.0, 0.88, 0.21, 255, 255, 255, 192);
				ShowSyncHudText(iClient, witchdoctorHUD, "Magic Tele is ready. %.0f percent charged.\nPress and release %s!", flCharge, GetMJTButton());
			}
			else
			{
				SetHudTextParams(-1.0, 0.88, 0.21, 225, 64, 64, 192);
				ShowSyncHudText(iClient, witchdoctorHUD, "Magic Tele is not ready. %.1f seconds remaining.", MT_OnCooldownUntil[iClient] - flTime);
			}
		}

		WitchDoctorUpdateHUD[iClient] = flTime + 0.2;
	}
}

public void JM_Tick(int iClient, int iButtons, float flTime)
{
	if(!JM_AbilitySwitched[iClient])
	{
		if (flTime >= MJ_OnCooldownUntil[iClient] && MJ_OnCooldownUntil[iClient] != -1.0)
			MJ_OnCooldownUntil[iClient] = -1.0;

		float flCharge = 0.0;
		if (MJ_OnCooldownUntil[iClient] == -1.0)
		{
			// get charge percent here, used by both the HUD and the actual jump
			if (MJ_CrouchOrAltFireDownSince[iClient] != -1.0)
			{
				if (MJ_ChargeTime[iClient] <= 0.0)
					flCharge = 100.0;
				else
					flCharge = fmin((flTime - MJ_CrouchOrAltFireDownSince[iClient]) / MJ_ChargeTime[iClient], 1.0) * 100.0;
			}

			char Button;
			switch(MJT_ButtonType)
			{
				case 1: Button = IN_ATTACK2;
				case 2: Button = IN_RELOAD;
				case 3: Button = IN_ATTACK3;
			}

			// do we start the charging now?
			if (MJ_CrouchOrAltFireDownSince[iClient] == -1.0 && (iButtons & Button) != 0)
				MJ_CrouchOrAltFireDownSince[iClient] = flTime;

			// has key been released?
			if (MJ_CrouchOrAltFireDownSince[iClient] != -1.0 && (iButtons & Button) == 0)
			{
				if (!IsInInvalidCondition(iClient))
				{
					MJ_OnCooldownUntil[iClient] = flTime + MJ_Cooldown[iClient];

					// taken from default_abilities, modified only lightly
					int Boss = FF2_GetBossIndex(iClient);
					float position[3];
					float velocity[3];
					GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", position);
					GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", velocity);

					int spellbook = FindSpellBook(iClient);
					SetEntProp(spellbook, Prop_Send, "m_iSelectedSpellIndex", 4);
					SetEntProp(spellbook, Prop_Send, "m_iSpellCharges", 1);
					FakeClientCommand(iClient, "use tf_weapon_spellbook");

					// for the sake of making this viable, I'm keeping an actual jump, but half the power of a standard jump
					if (MJ_EmergencyReady[iClient])
					{
						velocity[2] = (750 + (flCharge / 4) * 13.0) + 2000 * 0.75;
						MJ_EmergencyReady[iClient] = false;
					}
					else
					{
						velocity[2] = (750 + (flCharge / 4) * 13.0) * 0.5;
					}
					SetEntProp(iClient, Prop_Send, "m_bJumping", 1);
					velocity[0] *= (1 + Sine((flCharge / 4) * FLOAT_PI / 50)) * 0.5;
					velocity[1] *= (1 + Sine((flCharge / 4) * FLOAT_PI / 50)) * 0.5;

					TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, velocity);
					char sound[PLATFORM_MAX_PATH];
					if (FF2_RandomSound("sound_magjump", sound, PLATFORM_MAX_PATH, Boss))
					{
						EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
						EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);

						for (int enemy = 1; enemy < MaxClients; enemy++)
						{
							if (IsClientInGame(enemy) && enemy != iClient)
							{
								EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
								EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
							}
						}
					}
				}

				// regardless of outcome, cancel the charge.
				MJ_CrouchOrAltFireDownSince[iClient] = -1.0;
			}
		}

		// draw the HUD if it's time
		if (flTime >= WitchDoctorUpdateHUD[iClient])
		{
			if (!(GetClientButtons(iClient) & IN_SCORE))
			{
				if (MJ_EmergencyReady[iClient])
				{
					SetHudTextParams(-1.0, 0.88, 0.21, 225, 64, 64, 192);
					ShowSyncHudText(iClient, witchdoctorHUD, "Super DUPER Jump ready! Press and release %s!", GetMJTButton());
				}
				else if (MJ_OnCooldownUntil[iClient] == 1000000.0)
				{
					SetHudTextParams(-1.0, 0.88, 0.21, 255, 255, 255, 192);
					ShowSyncHudText(iClient, witchdoctorHUD, "Magic Jump is ready. %.0f percent charged.\nPress and release %s!\nPress %s to change.", flCharge, GetMJTButton(), GetJMButton());
				}
				else
				{
					SetHudTextParams(-1.0, 0.88, 0.21, 225, 64, 64, 192);
					ShowSyncHudText(iClient, witchdoctorHUD, "Magic Jump is not ready. %.1f seconds remaining.\nPress %s to change.", MJ_OnCooldownUntil[iClient] - flTime, GetJMButton());
				}
			}

			WitchDoctorUpdateHUD[iClient] = flTime + 0.2;
		}
	}
	else
	{
		if (flTime >= MT_OnCooldownUntil[iClient] && MT_OnCooldownUntil[iClient] != -1.0)
			MT_OnCooldownUntil[iClient] = -1.0;

		float flCharge = 0.0;
		if (MT_OnCooldownUntil[iClient] == -1.0)
		{
			// get charge percent here, used by both the HUD and the actual jump
			if (MT_CrouchOrAltFireDownSince[iClient] != -1.0)
			{
				if (MT_ChargeTime[iClient] <= 0.0)
					flCharge = 100.0;
				else
					flCharge = fmin((flTime - MT_CrouchOrAltFireDownSince[iClient]) / MT_ChargeTime[iClient], 1.0) * 100.0;
			}

			char Button;
			switch(MJT_ButtonType)
			{
				case 1: Button = IN_ATTACK2;
				case 2: Button = IN_RELOAD;
				case 3: Button = IN_ATTACK3;
			}

			// do we start the charging now?
			if (MT_CrouchOrAltFireDownSince[iClient] == -1.0 && (iButtons & Button) != 0)
				MT_CrouchOrAltFireDownSince[iClient] = flTime;

			// has key been released?
			if (MT_CrouchOrAltFireDownSince[iClient] != -1.0 && (iButtons & Button) == 0)
			{
				if (!IsInInvalidCondition(iClient))
				{
					MT_OnCooldownUntil[iClient] = flTime + MT_Cooldown[iClient];

					int spellbook = FindSpellBook(iClient);
					SetEntProp(spellbook, Prop_Send, "m_iSelectedSpellIndex", 6);
					SetEntProp(spellbook, Prop_Send, "m_iSpellCharges", 1);
					FakeClientCommand(iClient, "use tf_weapon_spellbook");

					// just because I can see this becoming an immediate problem, gonna add an emergency teleport
					if (MT_EmergencyReady[iClient])
					{
						if (DD_PerformTeleport(iClient, 2.0, _, true))
						{
							MT_EmergencyReady[iClient] = false;
						}
					}

					float position[3];
					GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", position);

					int Boss = FF2_GetBossIndex(iClient);
					char sound[PLATFORM_MAX_PATH];
					if (FF2_RandomSound("sound_magtele", sound, PLATFORM_MAX_PATH, Boss))
					{
						EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
						EmitSoundToAll(sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);

						for (int enemy = 1; enemy < MaxClients; enemy++)
						{
							if (IsClientInGame(enemy) && enemy != iClient)
							{
								EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
								EmitSoundToClient(enemy, sound, iClient, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, iClient, position, NULL_VECTOR, true, 0.0);
							}
						}
					}
				}

				// regardless of outcome, cancel the charge.
				MT_CrouchOrAltFireDownSince[iClient] = -1.0;
			}
		}

		// draw the HUD if it's time
		if (flTime >= WitchDoctorUpdateHUD[iClient])
		{
			if (!(GetClientButtons(iClient) & IN_SCORE))
			{
				if (MT_EmergencyReady[iClient])
				{
					SetHudTextParams(-1.0, 0.88, 0.21, 225, 64, 64, 192);
					ShowSyncHudText(iClient, witchdoctorHUD, "EMERGENCY TELEPORT! Press and release %s!", GetMJTButton());
				}
				else if (MT_OnCooldownUntil[iClient] == -1.0)
				{
					SetHudTextParams(-1.0, 0.88, 0.21, 255, 255, 255, 192);
					ShowSyncHudText(iClient, witchdoctorHUD, "Magic Tele is ready. %.0f percent charged.\nPress and release %s!\nPress %s to change.", flCharge, GetMJTButton(), GetJMButton());
				}
				else
				{
					SetHudTextParams(-1.0, 0.88, 0.21, 225, 64, 64, 192);
					ShowSyncHudText(iClient, witchdoctorHUD, "Magic Tele is not ready. %.1f seconds remaining.\nPress %s to change.", MT_OnCooldownUntil[iClient] - flTime, GetJMButton());
				}
			}

			WitchDoctorUpdateHUD[iClient] = flTime + 0.2;
		}
	}
}

public void AimThink(int iClient)
{
	int iClosest = GetClosestClient(iClient);
	if(!IsValidClient(iClosest, true))
		return;

	float flClosestLocation[3], flClientEyePosition[3], flVector[3], flCamAngle[3];
	GetClientEyePosition(iClient, flClientEyePosition);

	GetClientEyePosition(iClosest, flClosestLocation);
	flClosestLocation[2] -= 2.0;

	MakeVectorFromPoints(flClosestLocation, flClientEyePosition, flVector);
	GetVectorAngles(flVector, flCamAngle);
	flCamAngle[0] *= -1.0;
	flCamAngle[1] += 180.0;

	ClampAngle(flCamAngle);
	TeleportEntity(iClient, NULL_VECTOR, flCamAngle, NULL_VECTOR);

	if(GetEngineTime() >= MLGRageTime[iClient] || FF2_GetRoundState() != 1)
		SDKUnhook(iClient, SDKHook_PreThink, AimThink);
}

void Abduct(int iClient)
{
	float flPos[3];
	GetClientAbsOrigin(iClient, flPos);
	flPos[0] += GetRandomFloat(-RaptureRadius, RaptureRadius);
	flPos[1] += GetRandomFloat(-RaptureRadius, RaptureRadius);
	Handle TraceRay = TR_TraceRayEx(flPos, view_as<float>({90.0, 0.0, 0.0}), MASK_SHOT, RayType_Infinite);
	if (TR_DidHit(TraceRay))
	{
		TR_GetEndPosition(flPos, TraceRay);
		flPos[2] += 5.0;
	}
	else
	{
		flPos[2] -= 280.0;
	}
	delete TraceRay;

	int trigger = CreateEntityByName("trigger_push");
	if(trigger != -1)
	{
		CreateTimer(RaptureDuration, Timer_RemovePod, EntIndexToEntRef(trigger), TIMER_FLAG_NO_MAPCHANGE);

		DispatchKeyValueVector(trigger, "origin", flPos);
		DispatchKeyValue(trigger, "speed", RapturePush);
		DispatchKeyValue(trigger, "StartDisabled", "0");
		DispatchKeyValue(trigger, "spawnflags", "1");
		DispatchKeyValueVector(trigger, "pushdir", view_as<float>({-90.0, 0.0, 0.0}));
		DispatchKeyValue(trigger, "alternateticksfix", "0");
		DispatchSpawn(trigger);

		ActivateEntity(trigger);

		AcceptEntityInput(trigger, "Enable");

		SetEntityModel(trigger, MODEL_TRIGGER);

		SetEntPropVector(trigger, Prop_Send, "m_vecMins", RAPTURE_BEAM_MINS);
		SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", RAPTURE_BEAM_MAXS);

		SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);

		SDKHook(trigger, SDKHook_StartTouch, OnStartTouchBeam);
		SDKHook(trigger, SDKHook_Touch, OnTouchBeam);
		SDKHook(trigger, SDKHook_EndTouch, OnEndTouchBeam);

		ProjectBeams(flPos, RaptureDuration, {255, 215, 0, 155});
	}
}

public Action OnStartTouchBeam(int brush, int entity)
{
	if(entity > 0 && entity <= MaxClients && IsClientInGame(entity) && GetClientTeam(entity) != BossTeam)
	{
		SetEntityGravity(entity, 0.001);

		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action OnEndTouchBeam(int brush, int entity)
{
	if(entity > 0 && entity <= MaxClients && IsClientInGame(entity))
	{
		g_Update[entity] = 0;
		SetEntityGravity(entity, 1.0);
	}
	return Plugin_Continue;
}

public Action OnTouchBeam(int brush, int entity)
{
	static float lasthurtstun[MAXPLAYERS+1];
	static float flTime, flRatio;
	static float flClPos[3], flBeampos[3];

	if(entity > 0 && entity <= MaxClients && IsClientInGame(entity) && GetClientTeam(entity) != BossTeam)
	{
		flTime = GetEngineTime();
		if(lasthurtstun[entity] < flTime)
		{
			lasthurtstun[entity] = flTime + RAPTURE_STUN_DELAY;
			TF2_StunPlayer(entity, RaptureStunTime, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT, 0);

			GetClientAbsOrigin(entity, flClPos);
			GetEntPropVector(brush, Prop_Send, "m_vecOrigin", flBeampos);
			flRatio = GetVectorDistance(flClPos, flBeampos)/RAPTURE_BEAM_LENGTH;

			DiedRapture[entity] = flTime + 0.1;
			if(flRatio >= RaptureSlayRatio)
			{
				SDKHooks_TakeDamage(entity, g_Boss, g_Boss, 9001.0, DMG_SHOCK|DMG_PREVENT_PHYSICS_FORCE);
			}
			else
			{
				SDKHooks_TakeDamage(entity, g_Boss, g_Boss, RaptureDmg * flRatio, DMG_SHOCK|DMG_PREVENT_PHYSICS_FORCE);
			}
		}

		if(GetEntityFlags(entity) & FL_ONGROUND)
		{
			flClPos[0] = 0.0;
			flClPos[1] = 0.0;
			flClPos[2] = RaptureVel;

			TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, flClPos);

			g_Update[entity] = 0;
		}
		else if(g_Update[entity] == 1)
		{
			TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0,0.0,0.0}));
		}
		g_Update[entity]++;

		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action Projectile_Touch(int iProj, int iOther)
{
	int iClient = GetEntPropEnt(iProj, Prop_Send, "m_hOwnerEntity");
	char strClassname[11];
	if((GetEntityClassname(iOther, strClassname, 11) && StrEqual(strClassname, "worldspawn")) || (iOther > 0 && iOther <= MaxClients))
	{
		float flPos[3], flAng[3];
		GetEntPropVector(iProj, Prop_Data, "m_vecAbsOrigin", flPos);
		for (int i = 0; i <= SkeleNumberOfSpawns[iClient]; i++)
		{
			flAng[0] = GetRandomFloat(-500.0, 500.0);
			flAng[1] = GetRandomFloat(-500.0, 500.0);
			flAng[2] = GetRandomFloat(0.0, 25.0);

			int iTeam = GetClientTeam(iClient);
			int iSpell = CreateEntityByName("tf_projectile_spellspawnhorde");

			if(!IsValidEntity(iSpell))
				return Plugin_Continue;

			SetEntPropEnt(iSpell, Prop_Send, "m_hOwnerEntity", iClient);
			SetEntProp(iSpell, Prop_Send, "m_iTeamNum", iTeam, 1);
			SetEntProp(iSpell, Prop_Send, "m_nSkin", (iTeam-2));

			SetVariantInt(iTeam);
			AcceptEntityInput(iSpell, "TeamNum", -1, -1, 0);
			SetVariantInt(iTeam);
			AcceptEntityInput(iSpell, "SetTeam", -1, -1, 0);

			DispatchSpawn(iSpell);
			TeleportEntity(iSpell, flPos, flAng, flAng);
		}
	}
	return Plugin_Continue;
}

stock int GetIndexOfWeaponSlot(int iClient, int iSlot)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	return (iWeapon > MaxClients && IsValidEntity(iWeapon) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
}

stock void RemoveWeapons(int iClient)
{
	if (IsValidClient(iClient, true, true))
	{
		if(GetPlayerWeaponSlot(iClient, 0) != -1)
			TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Primary);

		if(GetPlayerWeaponSlot(iClient, 1) != -1)
			TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Secondary);

		if(GetPlayerWeaponSlot(iClient, 2) != -1)
			TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Melee);

		SwitchtoSlot(iClient, TFWeaponSlot_Melee);
	}
}

stock void SwitchtoSlot(int iClient, int iSlot)
{
	if (iSlot >= 0 && iSlot <= 5 && IsClientInGame(iClient) && IsPlayerAlive(iClient))
	{
		char strClassname[64];
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
		if (iWeapon > MaxClients && IsValidEdict(iWeapon) && GetEdictClassname(iWeapon, strClassname, sizeof(strClassname)))
		{
			FakeClientCommandEx(iClient, "use %s", strClassname);
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
		}
	}
}

void PerformBlind(int iClient, int iDuration)
{
	static UserMsg g_FadeUserMsgId = INVALID_MESSAGE_ID;
	if(g_FadeUserMsgId == INVALID_MESSAGE_ID)
	{
		g_FadeUserMsgId = GetUserMessageId("Fade");
	}

	int targets[2];
	targets[0] = iClient;

	Handle message = StartMessageEx(g_FadeUserMsgId, targets, 1);
	if (GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(message, "duration", iDuration);
		PbSetInt(message, "hold_time", iDuration);
		PbSetInt(message, "flags", 0x0002);
		PbSetColor(message, "clr", {255, 200, 0, 175});
	}
	else
	{
		BfWriteShort(message, 900);
		BfWriteShort(message, 900);
		BfWriteShort(message, 0x0002);
		BfWriteByte(message, 255);
		BfWriteByte(message, 200);
		BfWriteByte(message, 0);
		BfWriteByte(message, 175);
	}

	EndMessage();
}

void PerformSmite(int iClient, int iTarget)
{
	float flStart[3], flEnd[3], flCeil[3];
	GetClientAbsOrigin(iTarget, flEnd);
	flCeil = GetMapCeiling(flCeil);
	flEnd[2] -= 26; // increase y-axis by 26 to strike at player's chest instead of the ground

	// define where the lightning strike starts
	flStart[0] = flEnd[0] + GetRandomFloat(-500.0, 500.0);
	flStart[1] = flEnd[1] + GetRandomFloat(-500.0, 500.0);
	flStart[2] = flCeil[2];

	int iColor[4] = { 255, 255, 255, 255 };

	// define the direction of the sparks
	float flDir[3] = { 0.0, 0.0, 0.0 };

	TE_SetupBeamPoints(flStart, flEnd, g_LightningSprite, 0, 0, 0, 0.2, 20.0, 10.0, 0, 1.0, iColor, 3);
	TE_SendToAll();

	TE_SetupSparks(flEnd, flDir, 5000, 1000);
	TE_SendToAll();

	TE_SetupEnergySplash(flEnd, flDir, false);
	TE_SendToAll();

	TE_SetupSmoke(flEnd, g_SmokeSprite, 5.0, 10);
	TE_SendToAll();

	EmitAmbientSound(SOUND_THUNDER, flStart, iClient, SNDLEVEL_RAIDSIREN);

	SDKHooks_TakeDamage(iTarget, iClient, iClient, 9001.0, DMG_PREVENT_PHYSICS_FORCE, -1);
	PrintCenterText(iTarget, "Thou hast been smitten!");
	g_iSmiteNumber -= 1;
}

public void ProjectBeams(float flStart[3], float flDuration, const Color[4])
{
	float flEnd[3], flCeil[3];
	flCeil = GetMapCeiling(flCeil);

	flEnd[0] = flStart[0];
	flEnd[1] = flStart[1];
	flEnd[2] = flCeil[2];

	TE_SetupBeamPoints(flStart, flEnd, g_Laser, 0, 0, 0, flDuration, 50.0, 42.5, 0, 0.80, Color, 1);
	TE_SendToAll();
	flEnd[2] -= 2490.0;
	TE_SetupSmoke(flStart, g_Smoke, 30.0, 6);
	TE_SendToAll();
	TE_SetupGlowSprite(flStart, g_Glow, flDuration, 3.0, 235);
	TE_SendToAll();
}

float GetMapCeiling(float flPos[3])
{
	Handle hTrace = TR_TraceRayEx(flPos, view_as<float>({-90.0, 0.0, 0.0}), MASK_SHOT, RayType_Infinite);

	if (TR_DidHit(hTrace))
		TR_GetEndPosition(flPos, hTrace);
	else
		flPos[2] = 1500.0;
	delete hTrace;

	return flPos;
}

stock int AttachParticle(int iEntity, char[] sParticleType, float flOffset = 0.0, bool bAttach = true)
{
	int iParticle = CreateEntityByName("info_particle_system");

	char sName[128];
	float flPos[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", flPos);
	flPos[2] += flOffset;
	TeleportEntity(iParticle, flPos, NULL_VECTOR, NULL_VECTOR);

	Format(sName, sizeof(sName), "target%i", iEntity);
	DispatchKeyValue(iEntity, "targetname", sName);

	DispatchKeyValue(iParticle, "targetname", "tf2particle");
	DispatchKeyValue(iParticle, "parentname", sName);
	DispatchKeyValue(iParticle, "effect_name", sParticleType);
	DispatchSpawn(iParticle);
	if (bAttach)
	{
		SetVariantString(sName);
		AcceptEntityInput(iParticle, "SetParent", iParticle, iParticle, 0);
		SetEntPropEnt(iParticle, Prop_Send, "m_hOwnerEntity", iEntity);
	}
	ActivateEntity(iParticle);
	AcceptEntityInput(iParticle, "Start");
	return iParticle;
}

stock bool IsValidClient(int iClient, bool bAlive = false, bool bTeam = false)
{
	if(iClient < 1 || iClient > MaxClients || !IsClientInGame(iClient))
		return false;

	if(IsClientSourceTV(iClient) || IsClientReplay(iClient))
		return false;

	if(bAlive && !IsPlayerAlive(iClient))
		return false;

	if(bTeam && GetClientTeam(iClient) != BossTeam)
		return false;

	return true;
}

public bool FF2_GetAbilityArgumentBool(int iBoss, const char[] pluginName, const char[] abilityName, int iArg) {
	return FF2_GetAbilityArgument(iBoss, pluginName, abilityName, iArg, 1) == 1;
}

stock int FindEntityByClassname2(int startEnt, const char[] sClassname)
{
	/* If startEnt isn't valid shifting it back to the nearest valid one */
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
	return FindEntityByClassname(startEnt, sClassname);
}

stock int SpawnWeapon(int iClient, char[] sClassname, int iIndex, int iLevel, int iQuality, const char[] sAttribute = "", bool bShow = true, bool bEquip = true)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if (hWeapon == null)
		return -1;

	TF2Items_SetClassname(hWeapon, sClassname);
	TF2Items_SetItemIndex(hWeapon, iIndex);
	TF2Items_SetLevel(hWeapon, iLevel);
	TF2Items_SetQuality(hWeapon, iQuality);

	char sAttributes[32][32];
	int count=ExplodeString(sAttribute, ";", sAttributes, 32, 32);
	if (count % 2)
		--count;

	if (count > 0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		int i2;
		for(int i; i < count; i += 2)
		{
			int attrib = StringToInt(sAttributes[i]);
			if (!attrib)
			{
				LogError("Bad weapon attribute passed: %s ; %s", sAttributes[i], sAttributes[i+1]);
				CloseHandle(hWeapon);
				return -1;
			}
			TF2Items_SetAttribute(hWeapon, i2, attrib, StringToFloat(sAttributes[i+1]));
			i2++;
		}
	}
	else
		TF2Items_SetNumAttributes(hWeapon, 0);

	int iEntity = TF2Items_GiveNamedItem(iClient, hWeapon);
	EquipPlayerWeapon(iClient, iEntity);
	delete hWeapon;

	if(bEquip)
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iEntity);

	if (!bShow)
	{
		SetEntProp(iEntity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", 0.001);
	}

	return iEntity;
}

stock void SetAmmo(int iClient, int iWep, int iAmmo, int iClip = 0)
{
    if(iClip < 0)
    {
        SetEntProp(iWep, Prop_Data, "m_iClip1", 0);
    }
    else
    {
        SetEntProp(iWep, Prop_Data, "m_iClip1", iClip);
    }

    int iAmmoType = GetEntProp(iWep, Prop_Send, "m_iPrimaryAmmoType");
    if(iAmmoType != -1)
    {
        SetEntProp(iClient, Prop_Data, "m_iAmmo", iAmmo, _, iAmmoType);
    }
}

void Dissolve(int iEnt, int iMode=3)
{
	int iDissolver = CreateEntityByName("env_entity_dissolver");
	if (iDissolver != -1)
	{
		char dname[12];
		FormatEx(dname, 12, "dis_%d", iEnt);

		DispatchKeyValue(iEnt, "targetname", dname);
		switch(iMode <0 ? GetRandomInt(0, 3) : iMode)	  //"0 ragdoll rises as it dissolves, 1 and 2 dissolve on ground, 3 is fast dissolve"
		{
			case 0: DispatchKeyValue(iDissolver, "dissolvetype", "0");
			case 1: DispatchKeyValue(iDissolver, "dissolvetype", "1");
			case 2: DispatchKeyValue(iDissolver, "dissolvetype", "2");
			default: DispatchKeyValue(iDissolver, "dissolvetype", "3");
		}
		DispatchKeyValue(iDissolver, "target", dname);
		AcceptEntityInput(iDissolver, "Dissolve");
		AcceptEntityInput(iDissolver, "kill");
	}
}

int ShootProjectile(int iClient, char strEntname[48] = "")
{
	float flAng[3]; // original
	float flPos[3]; // original
	GetClientEyeAngles(iClient, flAng);
	GetClientEyePosition(iClient, flPos);

	int iTeam = GetClientTeam(iClient);
	int iSpell = CreateEntityByName(strEntname);

	if(!IsValidEntity(iSpell))
		return -1;

	float flVel1[3];
	float flVel2[3];

	GetAngleVectors(flAng, flVel2, NULL_VECTOR, NULL_VECTOR);

	flVel1[0] = flVel2[0]*1100.0; //Speed of a tf2 rocket.
	flVel1[1] = flVel2[1]*1100.0;
	flVel1[2] = flVel2[2]*1100.0;

	SetEntPropEnt(iSpell, Prop_Send, "m_hOwnerEntity", iClient);
	SetEntProp(iSpell, Prop_Send, "m_bCritical", (GetRandomInt(0, 100) <= 5)? 1 : 0, 1);
	SetEntProp(iSpell, Prop_Send, "m_iTeamNum", iTeam, 1);
	SetEntProp(iSpell, Prop_Send, "m_nSkin", (iTeam-2));

	TeleportEntity(iSpell, flPos, flAng, NULL_VECTOR);

	SetVariantInt(iTeam);
	AcceptEntityInput(iSpell, "TeamNum", -1, -1, 0);
	SetVariantInt(iTeam);
	AcceptEntityInput(iSpell, "SetTeam", -1, -1, 0);

	DispatchSpawn(iSpell);
	TeleportEntity(iSpell, NULL_VECTOR, NULL_VECTOR, flVel1);

	return iSpell;
}

public bool IsInInvalidCondition(int iClient)
{
	return TF2_IsPlayerInCondition(iClient, TFCond_Dazed) || TF2_IsPlayerInCondition(iClient, TFCond_Taunting) || GetEntityMoveType(iClient)==MOVETYPE_NONE;
}

stock float fmin(float n1, float n2)
{
	return n1 < n2 ? n1 : n2;
}

stock char GetJMButton()
{
	char strBuffer[18];
	switch(JM_ButtonType)
	{
		case 1: strBuffer = "Reload";
		case 2: strBuffer = "Special Attack";
		case 3: strBuffer = "Secondary Attack";
	}
	return strBuffer;
}

stock char GetMJTButton()
{
	char strBuffer[18];
	switch(MJT_ButtonType)
	{
		case 1: strBuffer = "Secondary Attack";
		case 2: strBuffer = "Reload";
		case 3: strBuffer = "Special Attack";
	}
	return strBuffer;
}

stock int FindSpellBook(int iClient)
{
	int spellbook = -1;
	while ((spellbook = FindEntityByClassname(spellbook, "tf_weapon_spellbook")) != -1)
	{
		if (IsValidEntity(spellbook) && GetEntPropEnt(spellbook, Prop_Send, "m_hOwnerEntity") == iClient)
			if(!GetEntProp(spellbook, Prop_Send, "m_bDisguiseWeapon"))
				return spellbook;
	}

	return -1;
}

public bool TraceEntityFilterPlayer(int iEntity, int contentsMask)
{
	return (iEntity > MaxClients || !iEntity);
}

stock bool CylinderCollision(float cylinderOrigin[3], float colliderOrigin[3], float maxDistance, float zMin, float zMax)
{
	if (colliderOrigin[2] < zMin || colliderOrigin[2] > zMax)
		return false;

	static float tmpVec1[3];
	tmpVec1[0] = cylinderOrigin[0];
	tmpVec1[1] = cylinderOrigin[1];
	tmpVec1[2] = 0.0;
	static float tmpVec2[3];
	tmpVec2[0] = colliderOrigin[0];
	tmpVec2[1] = colliderOrigin[1];
	tmpVec2[2] = 0.0;

	return GetVectorDistance(tmpVec1, tmpVec2, true) <= maxDistance * maxDistance;
}

stock bool IsPlayerInvincible(int iClient)
{
	return TF2_IsPlayerInCondition(iClient, TFCond_Ubercharged) || TF2_IsPlayerInCondition(iClient, TFCond_UberchargedCanteen) || TF2_IsPlayerInCondition(iClient, TFCond_Bonked);
}

stock int GetClosestClient(int iClient)
{
	float fClientLocation[3], fEntityOrigin[3];
	GetClientAbsOrigin(iClient, fClientLocation);

	int iClosestEntity = -1;
	float fClosestDistance = -1.0;
	for(int i = 1; i < MaxClients; i++) if(IsValidClient(i))
	{
		if(GetClientTeam(i) != GetClientTeam(iClient) && IsPlayerAlive(i) && i != iClient)
		{
			GetClientAbsOrigin(i, fEntityOrigin);
			float fEntityDistance = GetVectorDistance(fClientLocation, fEntityOrigin);
			if((fEntityDistance < fClosestDistance) || fClosestDistance == -1.0)
			{
				fClosestDistance = fEntityDistance;
				iClosestEntity = i;
			}
		}
	}
	return iClosestEntity;
}

stock void ClampAngle(float flAngles[3])
{
	while(flAngles[0] > 89.0)  flAngles[0]-=360.0;
	while(flAngles[0] < -89.0) flAngles[0]+=360.0;
	while(flAngles[1] > 180.0) flAngles[1]-=360.0;
	while(flAngles[1] <-180.0) flAngles[1]+=360.0;
}
