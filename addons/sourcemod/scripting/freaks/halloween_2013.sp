#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <tf2_stocks>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define EF_BONEMERGE			(1 << 0)
#define EF_NODRAW				(1 << 5)
#define EF_BONEMERGE_FASTCULL	(1 << 7)

#define TURRET_FIREANGLE	20.0			// halved viewangle for targetting players

int g_boss;
int g_BossTeam = view_as<int>(TFTeam_Blue);

float gf_CannonDamage = 25.0;
float gf_CannonDistance = 2250000.0;
float gf_CannonSpeed = 900.0;

float gf_rageTime;

int g_effectsOffset;					// Effects offset for viewmodel

ArrayList g_hArrayHoming;
#define HOMING_ENTREF		 0
#define HOMING_LOCK_TYPE	 1
#define HOMING_SPEED		 2

///////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////// PREDATOR
#define VISION_NORMAL		0
#define VISION_CLOAK		1
#define VISION_RAGE		2

#define MODEL_TROPHY_DUMMY	"models/weapons/w_models/w_cannonball.mdl"
#define MODEL_TROPHY		"models/props_mvm/mvm_human_skull.mdl"

#define TARGET_SPRITE		"materials/vgui/crosshairs/crosshair6.vmt"
#define TRAIL_SPRITE		"materials/Sprites/plasma1.vmt"
#define MG_SPRITE			"materials/Sprites/blueglow1.vmt"

#define SOUND_TURRET_FIRE	"freak_fortress_2/predator/fire.wav"
#define SOUND_RAGE_ON		"freak_fortress_2/predator/predator_zoom_in.wav"
#define SOUND_RAGE_OFF	"freak_fortress_2/predator/predator_zoom_out.wav"
#define SOUND_CLOAK_ON	"freak_fortress_2/predator/cloakon.wav"
#define SOUND_CLOAK_OFF	"freak_fortress_2/predator/cloakoff.wav"
#define SOUND_TROPHY		"freak_fortress_2/predator/pred_headpickup.wav"

#define SPRITE_RENDERAMT "200"

bool gb_predator;

float gf_TrophyTime = 10.0;
float gf_TrophyPct = 33.3;

int g_sprite[MAXPLAYERS+1];

int g_TargetSprite;
int g_CannonSprite;

float gf_diedPredCannon[MAXPLAYERS+1];

////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////	Doom

#define ITEM_SHOTGUN			(1<<0)		// 1
#define ITEM_ROCKETLAUNCHER	(1<<1)		// 2
#define ITEM_INVULNERABILITY	(1<<2)		// 4
#define ITEM_BERSERK			(1<<3)		// 8

#define EMOTION_NEUTRAL	0
#define EMOTION_LEFT		1
#define EMOTION_RIGHT		2
#define EMOTION_HAPPY		3
#define EMOTION_INVULN	4

#define ITEM_RESPAWN_DELAY		2.0		// multiplier for how long it takes before destroying an item and creating a int one if doom hasn't found it
#define LOOK_CHANCE			5		// larger number = less chance he'll look to the side :/
#define HAPPY_DURATION		1.0		// how long doom will smile for in the ui
#define LOOK_DURATION			1.0		// how long doom will look to the left or right in the UI

#define MODEL_ITEM_DUMMY		"models/items/medkit_large.mdl"
#define SOUND_ITEMPICKUP		"freak_fortress_2/doom/item_pickup.wav"
#define SOUND_WEAPPICKUP		"freak_fortress_2/doom/item_weaponpickup.wav"
#define SOUND_INVULN			"freak_fortress_2/doom/item_invuln.wav"

#define SPRITE_SHOTGUN		"materials/freak_fortress_2/doom/item_shotgun.vmt"
#define SPRITE_BERSERK		"materials/freak_fortress_2/doom/item_berserk.vmt"
#define SPRITE_INVULN			"materials/freak_fortress_2/doom/item_invuln.vmt"
#define SPRITE_ROCKETLAUNCHER	"materials/freak_fortress_2/doom/item_rocketlauncher.vmt"

bool gb_Doom;

float gf_ItemRespawn = 30.0;
float gf_PowerupDuration = 10.0;
char g_ShotgunAtt[128];
int g_ShotGunAmmo[2];
char g_RocketAtt[128];
int g_RocketAmmo[2];
int gb_CanRage;
int g_doomRandomChance;

int g_ItemArray[4];
int g_NumItems;

ArrayList gh_ItemLocations;
float gf_NextEmotion[MAXPLAYERS+1];

int g_iOffsetClip;
int g_iOffsetAmmo;

////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////	Skulls

static const char gs_booms[][] = {"weapons/mortar/mortar_explode1.wav", "weapons/mortar/mortar_explode2.wav", "weapons/mortar/mortar_explode3.wav"}; 
#define SPRITE_RED		"materials/Sprites/redglow2.vmt"
#define MODEL_ROCKET		"models/props_mvm/mvm_human_skull.mdl"

#define SOUND_CHAINSAW	"freak_fortress_2/ashwilliams/chainsaw.mp3"

bool gb_Skulls;
int g_flameEnt[3];
float gf_diedFireball[MAXPLAYERS+1];
float gf_IgniteTime = 5.0;

int g_bossuserid;

int gs_RedSprite;

////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////	Ash Williams

static const char gs_saws[][] = {"ambient/sawblade_impact1.wav", "ambient/sawblade_impact1.wav"}; 
#define MODEL_CHAINSAW		"models/props_swamp/chainsaw.mdl"

#define SAW_REHIT_INTERVAL		0.3

bool gb_Ash;
int g_chainsawmodel;

char gs_bossweaponclassname[32];
char gs_bossweaponattribs[256];
int g_bossweaponindex;
int g_chainsawref = INVALID_ENT_REFERENCE;

////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////	The Hidden

#define HIDDEN_DETATCHED		0
#define HIDDEN_DETATCHING		1
#define HIDDEN_ATTACHED		2
#define HIDDEN_ATTACHING		3

#define MIN_CLOAKATTACH		10.0
float gf_MinAttach = 10.0;
float gf_ReattachDelay = 1.0;
float gf_WallDist = 3600.0;
#define MAXDISTWALL_SQD		3600.0

bool gb_Hidden;
int g_OnWall;

////////////////////////////////////////////////////////////////////////////////////////////////////////////

stock void SDK_RemoveWearable(int client, int wearable)
{
	static Handle h_RemoveWearable = null;
	if(!h_RemoveWearable)
	{
		GameData hGameConfigtemp = new GameData("equipwearable");
		if(!hGameConfigtemp)
		{
			LogError("Equipwearable Gamedata could not be found");
			return;
		}
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConfigtemp, SDKConf_Virtual, "RemoveWearable");
		delete hGameConfigtemp;
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		if ((h_RemoveWearable = EndPrepSDKCall()) == INVALID_HANDLE)
		{
			LogError("Couldn't load SDK functions (CTFPlayer::RemoveWearable). SDK call failed.");
			return;
		}
	}

	SDKCall(h_RemoveWearable, client, wearable);
}

stock void SDK_EquipWearable(int client, int wearable)
{
	static Handle h_EquipWearable = null;
	if(!h_EquipWearable)
	{
		GameData hGameConfigtemp = new GameData("equipwearable");
		if(!hGameConfigtemp)
		{
			LogError("Equipwearable Gamedata could not be found");
			return;
		}
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConfigtemp, SDKConf_Virtual, "EquipWearable");
		delete hGameConfigtemp;
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		if ((h_EquipWearable = EndPrepSDKCall()) == INVALID_HANDLE)
		{
			LogError("Couldn't load SDK functions (CTFPlayer::EquipWearable). SDK call failed.");
			return;
		}
	}

	SDKCall(h_EquipWearable, client, wearable);
}

public Plugin myinfo = 
{
	name = "Freak Fortress 2: Halloween 2013 Boss Pack",
	author = "Friagram",
	description = "Ability pack for 2013 Halloween Bosses",
	version = "1.5",
	url = "http://steamcommunity.com/groups/poniponiponi"
};

public Action FF2_OnAbility2(int index, const char[] plugin_name, const char[] ability_name, int action)
{
	if (!strcmp(ability_name,"special_predator"))
	{
		Rage_UsePredator(ability_name, index);
	}
	else if(!strcmp(ability_name,"special_skulls"))
	{
		Rage_UseSkulls(ability_name, index);
	}
	else if(!strcmp(ability_name,"special_ash"))
	{
		Rage_UseAsh(ability_name, index);
	}

	return Plugin_Continue;
}

public void OnPluginStart2()
{
	HookEvent("teamplay_round_active", event_round_active, EventHookMode_PostNoCopy);			// I guess this is for noaml maps?
	HookEvent("arena_round_start", event_round_active, EventHookMode_PostNoCopy); 

	HookEvent("teamplay_round_win", event_round_end, EventHookMode_PostNoCopy);
	HookEvent("player_death", event_player_death, EventHookMode_Pre);

	if((g_iOffsetAmmo = FindSendPropInfo("CTFPlayer", "m_iAmmo")) == -1)
	{
		SetFailState("Could not find offset for CTFPlayer::m_iAmmo");
	}
	if((g_iOffsetClip = FindSendPropInfo("CTFWeaponBase", "m_iClip1")) == -1)
	{
		SetFailState("Could not find offset for CTFWeaponBase::m_iClip1");
	}
	if ((g_effectsOffset = FindSendPropInfo("CBaseViewModel","m_fEffects"))	 == -1)
	{	
		SetFailState("could not locate CBaseViewModel:m_fEffects");
	}

	g_sprite[0] = INVALID_ENT_REFERENCE;
	for(int i=1; i<=MaxClients; i++)
	{
		g_sprite[i] = INVALID_ENT_REFERENCE;		// just in case.
		if(IsClientInGame(i))
		{
			SDKHook(i, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
		}
	}

	gh_ItemLocations = new ArrayList();
	
	g_hArrayHoming = new ArrayList(3);
} 

public void OnMapStart()
{
	PrecacheModel(TRAIL_SPRITE, true);
	PrecacheModel(MODEL_TROPHY, true);
	PrecacheModel(MODEL_TROPHY_DUMMY, true);
	g_TargetSprite = PrecacheModel(TARGET_SPRITE, true);
	g_CannonSprite = PrecacheModel(MG_SPRITE, true);	
	PrecacheSound(SOUND_TURRET_FIRE, true);
	PrecacheSound(SOUND_RAGE_ON, true);
	PrecacheSound(SOUND_RAGE_OFF, true);
	PrecacheSound(SOUND_CLOAK_ON, true);
	PrecacheSound(SOUND_CLOAK_OFF, true);
	
	PrecacheModel(MODEL_ITEM_DUMMY, true);
	PrecacheSound(SOUND_ITEMPICKUP, true);
	PrecacheSound(SOUND_WEAPPICKUP, true);
	PrecacheSound(SOUND_INVULN, true);
	PrecacheModel(SPRITE_SHOTGUN, true);
	PrecacheModel(SPRITE_BERSERK, true);
	PrecacheModel(SPRITE_INVULN, true);
	PrecacheModel(SPRITE_ROCKETLAUNCHER, true);
	
	for(int i; i<sizeof(gs_booms); i++)
	{
		PrecacheSound(gs_booms[i], true);
	}
	gs_RedSprite = PrecacheModel(SPRITE_RED, true);

	for(int i; i<sizeof(gs_saws); i++)
	{
		PrecacheSound(gs_saws[i], true);
	}
	g_chainsawmodel = PrecacheModel(MODEL_CHAINSAW, true);
	PrecacheSound(SOUND_CHAINSAW, true);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public void event_round_active(Event event, const char[] name, bool dontBroadcast)
{
	g_boss = 0;
	gb_predator = gb_Doom = gb_Skulls = gb_Ash = gb_Hidden = false;

	int Boss;
	for(int Index = 0; (Boss=GetClientOfUserId(FF2_GetBossUserId(Index)))>0; Index++)
	{
		if(FF2_HasAbility( Index, this_plugin_name, "special_predator" ))
		{
			if(Boss && IsClientInGame(Boss) && IsPlayerAlive(Boss))
			{
				g_boss = Boss;
				gb_predator = true;

				gf_CannonDamage = FF2_GetAbilityArgumentFloat(Index, this_plugin_name, "special_predator", 2, 25.0);
				gf_TrophyTime = FF2_GetAbilityArgumentFloat(Index, this_plugin_name, "special_predator", 3, 10.0);
				gf_TrophyPct = FF2_GetAbilityArgumentFloat(Index, this_plugin_name, "special_predator", 4, 33.3);
				gf_CannonDistance = FF2_GetAbilityArgumentFloat(Index, this_plugin_name, "special_predator", 5, 1500.0);
				gf_CannonDistance *= gf_CannonDistance;
				gf_CannonSpeed = FF2_GetAbilityArgumentFloat(Index, this_plugin_name, "special_predator", 6, 900.0);
			
				CreateSprites(g_boss);
				TF2_RemoveCondition(Boss, TFCond_Cloaked);
			}
		}
		else if(FF2_HasAbility( Index, this_plugin_name, "special_skulls" ))
		{
			if(Boss && IsClientInGame(Boss) && IsPlayerAlive(Boss))
			{
				gb_Skulls = true;
				g_boss = Boss;

				gf_CannonDamage = FF2_GetAbilityArgumentFloat(Index, this_plugin_name, "special_skulls", 2, 25.0);
				gf_CannonDistance = FF2_GetAbilityArgumentFloat(Index, this_plugin_name, "special_skulls", 3, 1000.0);
				gf_CannonDistance *= gf_CannonDistance;
				gf_IgniteTime = FF2_GetAbilityArgumentFloat(Index, this_plugin_name, "special_skulls", 4, 5.0);
				gf_CannonSpeed = FF2_GetAbilityArgumentFloat(Index, this_plugin_name, "special_skulls", 5, 800.0);

				g_flameEnt[0] = g_flameEnt[1] = g_flameEnt[2] = INVALID_ENT_REFERENCE;
				CreateTimer(5.0, Timer_CreateFire, GetClientUserId(Boss), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		else if(FF2_HasAbility(Index, this_plugin_name, "special_ash" ))
		{
			g_bossuserid = FF2_GetBossUserId(Index);
			if(Boss && IsClientInGame(Boss) && IsPlayerAlive(Boss))
			{
				gb_Ash = true;
				g_boss = Boss;

				gf_CannonDamage = FF2_GetAbilityArgumentFloat(Index, this_plugin_name, "special_ash", 2, 150.0);		// saw damage?

				Handle kv = FF2_GetSpecialKV(Index);
				KvRewind(kv);
				if(KvJumpToKey(kv, "weapon1"))
				{
					KvGetString(kv, "name", gs_bossweaponclassname, 32, "tf_weapon_sword");
					KvGetString(kv, "attributes", gs_bossweaponattribs, 256, "2.0;3;68;2");
					g_bossweaponindex = KvGetNum(kv, "index", 132);
				}
				CloseHandle(kv);
			}
		}
		else if(FF2_HasAbility( Index, this_plugin_name, "special_hidden" ))
		{
			if(Boss && IsClientInGame(Boss) && IsPlayerAlive(Boss))
			{
				gb_Hidden = true;
				g_boss = Boss;

				gf_MinAttach = FF2_GetAbilityArgumentFloat(Index, this_plugin_name, "special_hidden", 1, 10.0);
				gf_ReattachDelay = FF2_GetAbilityArgumentFloat(Index, this_plugin_name, "special_hidden", 2, 1.0);
				gf_WallDist = FF2_GetAbilityArgumentFloat(Index, this_plugin_name, "special_hidden", 3, 60.0);
				gf_WallDist = gf_WallDist * gf_WallDist;

				CreateTimer(5.0, Timer_CreateHidden, GetClientUserId(Boss), TIMER_FLAG_NO_MAPCHANGE);

// add glows to clients, if you want
			}
		}
		else if(FF2_HasAbility(Index, this_plugin_name, "special_doom" ))				// can multiboss if you want
		{
			if(Boss && IsClientInGame(Boss) && IsPlayerAlive(Boss))
			{
				g_BossTeam = GetClientTeam(Boss);								// could do getff2bossteam but we have this already anyways.
				gb_Doom = true;

				int itemflags = FF2_GetAbilityArgument(Index, this_plugin_name, "special_doom", 1, ITEM_SHOTGUN|ITEM_ROCKETLAUNCHER|ITEM_INVULNERABILITY|ITEM_BERSERK);				// 1, 2, 4, 8, 16

				if(itemflags)
				{
					static char stuff[6];
					static char morestuff[2][3];

					g_NumItems = 0;
					if(itemflags & ITEM_SHOTGUN)
					{
						FF2_GetAbilityArgumentString(Index, this_plugin_name,"special_doom", 5, stuff, 6);
						ExplodeString(stuff, ";", morestuff, 2, 3);
						g_ShotGunAmmo[0] = StringToInt(morestuff[0]);
						g_ShotGunAmmo[1] = StringToInt(morestuff[1]);

						FF2_GetAbilityArgumentString(Index, this_plugin_name,"special_doom", 4, g_ShotgunAtt, 128);
					
						g_ItemArray[g_NumItems] = ITEM_SHOTGUN;
						g_NumItems++;
					}
					if(itemflags & ITEM_ROCKETLAUNCHER)
					{
						FF2_GetAbilityArgumentString(Index, this_plugin_name,"special_doom", 7, stuff, 6);
						ExplodeString(stuff, ";", morestuff, 2, 3);
						g_RocketAmmo[0] = StringToInt(morestuff[0]);
						g_RocketAmmo[1] = StringToInt(morestuff[1]);

						FF2_GetAbilityArgumentString(Index, this_plugin_name,"special_doom", 6, g_RocketAtt, 128);

						g_ItemArray[g_NumItems] = ITEM_ROCKETLAUNCHER;
						g_NumItems++;
					}
					if(itemflags & ITEM_INVULNERABILITY)
					{
						g_ItemArray[g_NumItems] = ITEM_INVULNERABILITY;
						g_NumItems++;
					}
					if(itemflags & ITEM_BERSERK)
					{
						g_ItemArray[g_NumItems] = ITEM_BERSERK;
						g_NumItems++;
					}

					gf_ItemRespawn = FF2_GetAbilityArgumentFloat(Index, this_plugin_name, "special_doom", 2, 30.0);		// time before int one pops once grabbed
					gf_PowerupDuration = FF2_GetAbilityArgumentFloat(Index, this_plugin_name, "special_doom", 3, 10.0);	// length of invuln or berserk

					CacheItemSpawnLocations();
				
					gb_CanRage = FF2_GetAbilityArgument(Index, this_plugin_name, "special_doom", 8, 0) != 0;				// block boss from raging?
					g_doomRandomChance = FF2_GetAbilityArgument(Index, this_plugin_name, "special_doom", 9, 5);			// random chance to get a drop
				}

				for(int i=1; i<=MaxClients; i++)
				{
					if(FF2_GetBossIndex(i) != -1)																	// find all the boss!
					{
						CreateTimer(0.3, Timer_DoomguyThink, GetClientUserId(i), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					}
				}
			}
		}
	}
}

public void event_round_end(Event event, const char[] name, bool dontBroadcast)
{
	if(gb_predator)						// should use a switch enum for this shit, oh well.
	{
		TerminatePredatorEffects();
	}
	else if(gb_Skulls)
	{
		TerminateSkullsEffects();
	}
	else if(gb_Ash)
	{
		TerminateAshe();
	}
	else if(gb_Hidden)
	{
		if(g_boss && IsClientInGame(g_boss) && IsPlayerAlive(g_boss))
		{
			SetEntityMoveType(g_boss, MOVETYPE_WALK);
			TeleportEntity(g_boss, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
		}

		TerminateHidden();
	}
	
	g_boss = 0;		// just in case somone suicides or someshit and the timer is still going :/
}

public Action event_player_death(Handle hEvent, const char[] strEventName, bool bDontBroadcast)
{
	if(gb_predator)
	{
		int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));					// predator died :*(
		
		if(client == g_boss)
		{
			TerminatePredatorEffects();
		}
		else																			// faster and more surefire to just check this every death since arena will happen once
		{
			if(!(GetEventInt(hEvent, "death_flags") & TF_DEATHFLAG_DEADRINGER))			// if spies actually die, remove their trails
			{
				int ent = EntRefToEntIndex(g_sprite[client]);
				if(ent != INVALID_ENT_REFERENCE)
				{
					RemoveEntity(ent);
				}
			}
			
			if(client > 0 && client <= client && IsClientInGame(client))
			{
				if(GetClientOfUserId(GetEventInt(hEvent,"attacker")) == g_boss)			// spawn trophy skulls for all nonboss
				{
					SpawnTrophy(client);
				}

				if(gf_diedPredCannon[client] != 0.0)									// convert shoulder cannon kills to sentry icons
				{
					if(GetEngineTime() - gf_diedPredCannon[client] <= 0.1)
					{			
						int iDamageBits = GetEventInt(hEvent, "damagebits");
						SetEventInt(hEvent, "damagebits",  iDamageBits |= DMG_CRIT);
						SetEventString(hEvent, "weapon_logclassname", "predator_cannon");
						SetEventString(hEvent, "weapon", "obj_sentrygun");
						SetEventInt(hEvent, "customkill", TF_CUSTOM_PLAYER_SENTRY);
						SetEventInt(hEvent, "playerpenetratecount", 0);
						gf_diedPredCannon[client] = 0.0;

						return Plugin_Continue;
					}
					gf_diedPredCannon[client] = 0.0;
				}
			}
		}
	}
	else if(gb_Doom)
	{
		int attacker = GetClientOfUserId(GetEventInt(hEvent,"attacker"));
		if(attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && GetClientTeam(attacker) == g_BossTeam)
		{
			int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
			if(client > 0 && client <= client && IsClientInGame(client) && GetClientTeam(client) != g_BossTeam)
			{
				SetDoomUI(attacker, EMOTION_HAPPY);									// death is good
				if(GetEntityFlags(client) && FL_ONGROUND && !GetRandomInt(0, g_doomRandomChance))
				{
					SpawnItem(client);
				}
			}
		}
	}
	else if(gb_Skulls)
	{
		int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

		if(client == g_boss)
		{
			TerminateSkullsEffects();
		}
		else
		{
			if(client > 0 && client <= client && IsClientInGame(client))
			{
				if(gf_diedFireball[client] != 0.0)									// set kill icon to hadouken
				{
					if(GetEngineTime() - gf_diedFireball[client] <= 0.1)
					{			
						int iDamageBits = GetEventInt(hEvent, "damagebits");
						SetEventInt(hEvent, "damagebits",  iDamageBits |= DMG_CRIT);
						SetEventString(hEvent, "weapon_logclassname", "rage_fireball");
						SetEventString(hEvent, "weapon", "taunt_pyro");
						SetEventInt(hEvent, "customkill", TF_CUSTOM_TAUNT_HADOUKEN);
						SetEventInt(hEvent, "playerpenetratecount", 0);
						gf_diedFireball[client] = 0.0;

						return Plugin_Continue;
					}
					gf_diedFireball[client] = 0.0;
				}
			}
		}
	}
	else if(gb_Ash)
	{
		int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

		if(client == g_boss)
		{
			TerminateAshe();
		}
		else
		{
			if(client && IsClientInGame(client) && EntRefToEntIndex(g_chainsawref) == GetEventInt(hEvent, "inflictor_entindex"))
			{		
				int iDamageBits = GetEventInt(hEvent, "damagebits");
				SetEventInt(hEvent, "damagebits",  iDamageBits |= DMG_NERVEGAS);
				SetEventString(hEvent, "weapon_logclassname", "ash_chainsaw");
				SetEventString(hEvent, "weapon", "worldspawn");				// something environmental ??!! 
				SetEventInt(hEvent, "customkill", TF_CUSTOM_TRIGGER_HURT);
				SetEventInt(hEvent, "playerpenetratecount", 0);
				SetEventInt(hEvent, "attacker", g_bossuserid);

				EmitSoundToAll(gs_saws[GetRandomInt(0, sizeof(gs_saws)-1)], client);

				return Plugin_Continue;
			}
		}
	}
	else if(gb_Hidden)
	{
		if(GetClientOfUserId(GetEventInt(hEvent, "userid")) == g_boss)
		{
			TerminateHidden();
		}
	}

	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	if(client == g_boss)
	{
		if(gb_predator)
		{
			TerminatePredatorEffects();
		}
		else if(gb_Skulls)
		{
			TerminateSkullsEffects();
		}
		else if(gb_Ash)
		{
			TerminateAshe();
		}
		else if(gb_Hidden)
		{
			TerminateHidden();
		}
	}

	gf_diedPredCannon[client] = 0.0;			// probably don't even need this since time moves forward >>
	gf_diedFireball[client] = 0.0;
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if(gb_predator && condition == TFCond_Cloaked && client == g_boss)
	{
		TF2_RemoveCondition(client, TFCond_OnFire);
		TF2_RemoveCondition(client, TFCond_Milked);
		TF2_RemoveCondition(client, TFCond_Bleeding);
		TF2_RemoveCondition(client, TFCond_MarkedForDeath);
		SetVisionMode(client, VISION_CLOAK);
		EmitSoundToAll(SOUND_CLOAK_ON, client);
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if(gb_predator)
	{
		if(condition == TFCond_Cloaked && client == g_boss)
		{
			SetVisionMode(client, VISION_NORMAL);
			SetEntPropFloat(client, Prop_Send, "m_flStealthNoAttackExpire", GetGameTime()+0.25);		// attack instantly
			EmitSoundToAll(SOUND_CLOAK_OFF, client);
		}
	}
	else if(gb_Hidden)
	{
		if(condition == TFCond_Cloaked && client == g_boss)
		{
			SetEntPropFloat(client, Prop_Send, "m_flStealthNoAttackExpire", GetGameTime()+0.75);		// attack fast
		}
	}
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, 
					float damage, int damagetype, int weapon,
				const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if(gb_Doom && victim != attacker && attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && GetClientTeam(attacker) == g_BossTeam && TF2_IsPlayerInCondition(attacker, TFCond_CritHype))
	{
		FakeClientCommand(victim, "Explode");									// ff2's ontakedamage also hits here if we used ontakedamage....
	}
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool& result)
{
	if(gb_Skulls && client == g_boss && gf_rageTime > GetEngineTime())
	{
		ThrowFireBall(client);
	}
	return Plugin_Continue;
}

//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////  Skulls Passive Stuff

public Action Timer_CreateFire(Handle timer, any userid)	// Creates and caches the particle systems used for fire
{
	if(gb_Skulls)
	{
		int client = GetClientOfUserId(userid);
		if(client && IsClientInGame(client) && client == g_boss)
		{
			static float origin[3];
			GetClientAbsOrigin(client, origin);

			int ent = CreateEntityByName("info_particle_system");
			if(ent != -1)
			{
				DispatchKeyValueVector(ent, "origin", origin);
				DispatchKeyValue(ent, "effect_name", "m_brazier_flame");
				DispatchSpawn(ent);
				
				SetVariantString("!activator");
				AcceptEntityInput(ent, "SetParent", client);

				SetVariantString("flame_head");
				AcceptEntityInput(ent, "SetParentAttachment");

				ActivateEntity(ent);

				g_flameEnt[0] = EntIndexToEntRef(ent);
			}
			ent = CreateEntityByName("info_particle_system");
			if(ent != -1)
			{
				DispatchKeyValueVector(ent, "origin", origin);
				DispatchKeyValue(ent, "effect_name", "eye_powerup_red_lvl_2");
				DispatchSpawn(ent);

				SetVariantString("!activator");
				AcceptEntityInput(ent, "SetParent", client);

				SetVariantString("flame_eye_left");
				AcceptEntityInput(ent, "SetParentAttachment");
				
				ActivateEntity(ent);

				g_flameEnt[1] = EntIndexToEntRef(ent);
			}
			ent = CreateEntityByName("info_particle_system");
			if(ent != -1)
			{
				DispatchKeyValueVector(ent, "origin", origin);
				DispatchKeyValue(ent, "effect_name", "eye_powerup_red_lvl_2");
				DispatchSpawn(ent);

				SetVariantString("!activator");
				AcceptEntityInput(ent, "SetParent", client);

				SetVariantString("flame_eye_right");
				AcceptEntityInput(ent, "SetParentAttachment");

				ActivateEntity(ent);

				g_flameEnt[2] = EntIndexToEntRef(ent);
			}
		}
	}
}

void TerminateSkullsEffects()								// Prevent rage from bleeding over into warmup, and stop skulls from homing, etc.
{
	gb_Skulls = false;
	g_boss = 0;
	gf_rageTime = 0.0;
}

//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////  Doom Passive Stuff

void CacheItemSpawnLocations()								// Finds pickups around the map, and stores their entities. (Better than vecs, we can use them in timers)
{
	gh_ItemLocations.Clear();

	int ent = MaxClients+1;
	while ((ent = FindEntityByClassname2(ent, "item_ammopack_small")) != -1)
	{
		gh_ItemLocations.Push(EntIndexToEntRef(ent));
	}
	ent = MaxClients+1;
	while ((ent = FindEntityByClassname2(ent, "item_healthkit*")) != -1)
	{
		gh_ItemLocations.Push(EntIndexToEntRef(ent));
	}
	int size = gh_ItemLocations.Length;
	if(size)											// spawn the first item, and continue for as the round lasts.
	{
		CreateTimer(gf_ItemRespawn, Timer_SpawnItem, gh_ItemLocations.Get(GetRandomInt(0, size-1)), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_SpawnItem(Handle timer, any ref)		// Spawns a sprite on a random pickup item (will not work on multistage maps well..)
{
	if(gb_Doom)										// should also fail if the round resets and the ent ref is invalid, but whatever.
	{
		int ent = EntRefToEntIndex(ref);
		if(ent != INVALID_ENT_REFERENCE)
		{
			static float origin[3];
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origin);
			origin[2] += 30.0;
			
			ent = CreateEntityByName("prop_physics_override");
			if(ent != -1)
			{
				DispatchKeyValueVector(ent, "origin", origin);
				
				DispatchKeyValue(ent, "solid", "6");
				DispatchKeyValue(ent, "model", MODEL_ITEM_DUMMY);		// this one's for business
				DispatchKeyValue(ent, "disableshadows", "1");
				DispatchKeyValue(ent, "spawnflags", "8192");			// need to hit clients, physics, debris
				
				DispatchSpawn(ent);
				
				ActivateEntity(ent);
				
				AcceptEntityInput(ent, "DisableMotion");				// should start motion enabled, whatever.
				
				SetEntProp(ent, Prop_Send, "m_CollisionGroup", 1);		// This is a trigger
				SetEntProp(ent, Prop_Send, "m_usSolidFlags", 8);			// Fire trigger even if not solid

				SetEntPropFloat(ent, Prop_Send, "m_flModelScale", 0.001);	// color and alpha and nodraw do not seem to always work.
				
				int ent2 = CreateEntityByName("env_sprite");			// if I could make models follow people, that would be ideal.
				if(ent2 != -1)
				{
					DispatchKeyValueVector(ent2, "origin", origin);

					DispatchKeyValue(ent2, "disablereceiveshadows", "1");
					DispatchKeyValue(ent2, "framerate", "3.0");
					DispatchKeyValueFloat(ent2, "GlowProxySize", 10.0);
					DispatchKeyValueFloat(ent2, "HDRColorScale", 1.0);
					DispatchKeyValue(ent2, "maxdxlevel", "0");
					DispatchKeyValue(ent2, "mindxlevel", "0");

					switch(g_ItemArray[GetRandomInt(0, g_NumItems-1)])
					{
					case ITEM_SHOTGUN:
						{
							DispatchKeyValue(ent2, "model", SPRITE_SHOTGUN);
							SDKHook(ent, SDKHook_StartTouch, OnShotgunTouch);
						}
					case ITEM_ROCKETLAUNCHER:
						{
							DispatchKeyValue(ent2, "model", SPRITE_ROCKETLAUNCHER);
							SDKHook(ent, SDKHook_StartTouch, OnRocketLauncherTouch);
						}
					case ITEM_BERSERK:
						{
							DispatchKeyValue(ent2, "model", SPRITE_BERSERK);
							SDKHook(ent, SDKHook_StartTouch, OnBerserkTouch);
						}
					default:
						{
							DispatchKeyValue(ent2, "model", SPRITE_INVULN);
							SDKHook(ent, SDKHook_StartTouch, OnInvulnerabilityTouch);
						}
					}

					DispatchKeyValue(ent2, "renderamt", "255");
					DispatchKeyValue(ent2, "rendercolor", "255 255 255 255");
					DispatchKeyValue(ent2, "renderfx", "0");
					DispatchKeyValue(ent2, "rendermode", "4");
					DispatchKeyValue(ent2, "scale", "1.0");
					
					DispatchSpawn(ent2);
					
					ActivateEntity(ent2);
					
					SetVariantString("!activator");
					AcceptEntityInput(ent2, "SetParent", ent);
					
					CreateTimer(gf_ItemRespawn * ITEM_RESPAWN_DELAY, Timer_ReSpawnItem, EntIndexToEntRef(ent), TIMER_FLAG_NO_MAPCHANGE);
				}
				else
				{
					KillWithoutMayhem(ent);
				}
			}
		}
	}
}

public Action Timer_ReSpawnItem(Handle timer, any ref)		// Spawns a int item chain, if doom hasn't picked up the previous item in a long time
{
	int ent = EntRefToEntIndex(ref);
	if(ent != INVALID_ENT_REFERENCE)
	{
		CreateTimer(0.1, Timer_SpawnItem, gh_ItemLocations.Get(GetRandomInt(0, gh_ItemLocations.Length - 1)), TIMER_FLAG_NO_MAPCHANGE);	// next frame.
		KillWithoutMayhem(ent);
	}
}

public Action OnShotgunTouch( int prop, int entity )
{
	if(entity > 0 && entity <= MaxClients && GetClientTeam(entity) == g_BossTeam  && !TF2_IsPlayerInCondition(entity, TFCond_CritHype))
	{
		TF2_RemoveWeaponSlot(entity, 1);
		int weapon = SpawnWeapon(entity, "tf_weapon_shotgun_soldier", 10, 100, 5, g_ShotgunAtt);
		if(IsValidEntity(weapon))
		{
			SetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon", weapon);
			SetAmmo(entity, weapon, g_ShotGunAmmo[0], g_ShotGunAmmo[1]);

			EmitSoundToAll(SOUND_WEAPPICKUP, entity);
			SetDoomUI(entity, EMOTION_HAPPY);
		}

		KillWithoutMayhem(prop);
		CreateTimer(gf_ItemRespawn, Timer_SpawnItem, gh_ItemLocations.Get(GetRandomInt(0, gh_ItemLocations.Length - 1)), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action OnRocketLauncherTouch( int prop, int entity )
{
	if(entity > 0 && entity <= MaxClients && GetClientTeam(entity) == g_BossTeam && !TF2_IsPlayerInCondition(entity, TFCond_CritHype))
	{
		TF2_RemoveWeaponSlot(entity, 0);
		int weapon = SpawnWeapon(entity, "tf_weapon_rocketlauncher", 18, 100, 5, g_RocketAtt);
		if(IsValidEntity(weapon))
		{
			SetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon", weapon);
			SetAmmo(entity, weapon, g_RocketAmmo[0], g_RocketAmmo[1]);

			EmitSoundToAll(SOUND_WEAPPICKUP, entity);
			SetDoomUI(entity, EMOTION_HAPPY);
		}

		KillWithoutMayhem(prop);
		CreateTimer(gf_ItemRespawn, Timer_SpawnItem, gh_ItemLocations.Get(GetRandomInt(0, gh_ItemLocations.Length - 1)), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action OnInvulnerabilityTouch( int prop, int entity )
{
	if(entity > 0 && entity <= MaxClients && GetClientTeam(entity) == g_BossTeam)
	{
		TF2_AddCondition(entity, TFCond_Ubercharged, gf_PowerupDuration);
		TF2_AddCondition(entity, TFCond_MegaHeal, gf_PowerupDuration);

		EmitSoundToAll(SOUND_INVULN);
		SetDoomUI(entity, EMOTION_INVULN);
		
		KillWithoutMayhem(prop);
		CreateTimer(gf_ItemRespawn, Timer_SpawnItem, gh_ItemLocations.Get(GetRandomInt(0, gh_ItemLocations.Length - 1)), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action OnBerserkTouch( int prop, int entity )
{
	if(entity > 0 && entity <= MaxClients && GetClientTeam(entity) == g_BossTeam)
	{
		int weapon = GetPlayerWeaponSlot(entity, TFWeaponSlot_Melee);					// this will probably never fail, but whatever.
		if (weapon != -1)
		{
			static char classname[32];
			if(GetEntityClassname(weapon, classname, 64))
			{
				TF2_RemoveWeaponSlot(entity, 0);
				TF2_RemoveWeaponSlot(entity, 1);

				FakeClientCommand(entity, "use %s", classname);
				SetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon", weapon);
				
				TF2_AddCondition(entity, TFCond_CritHype, gf_PowerupDuration);
				TF2_AddCondition(entity, TFCond_MegaHeal, gf_PowerupDuration);

				EmitSoundToAll(SOUND_ITEMPICKUP, entity);
				SetDoomUI(entity, EMOTION_HAPPY);
			}
		}

		KillWithoutMayhem(prop);
		CreateTimer(gf_ItemRespawn, Timer_SpawnItem, gh_ItemLocations.Get(GetRandomInt(0, gh_ItemLocations.Length - 1)), TIMER_FLAG_NO_MAPCHANGE);
	}
}

void SpawnItem(int client)		// Spawns a sprite on a client's death location (will not work on multistage maps well..)
{
	static float origin[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", origin);
	origin[2] += 30.0;
	
	int ent = CreateEntityByName("prop_physics_override");
	if(ent != -1)
	{
		DispatchKeyValueVector(ent, "origin", origin);

		DispatchKeyValue(ent, "solid", "6");
		DispatchKeyValue(ent, "model", MODEL_ITEM_DUMMY);		// this one's for business
		DispatchKeyValue(ent, "disableshadows", "1");
		DispatchKeyValue(ent, "spawnflags", "8192");			// need to hit clients, physics, debris

		DispatchSpawn(ent);

		ActivateEntity(ent);

		AcceptEntityInput(ent, "DisableMotion");				// should start motion enabled, whatever.

		SetEntProp(ent, Prop_Send, "m_CollisionGroup", 1);		// This is a trigger
		SetEntProp(ent, Prop_Send, "m_usSolidFlags", 8);			// Fire trigger even if not solid

		SetEntPropFloat(ent, Prop_Send, "m_flModelScale", 0.001);// color and alpha and nodraw do not seem to always work.

		int ent2 = CreateEntityByName("env_sprite");			// if I could make models follow people, that would be ideal.
		if(ent2 != -1)
		{
			DispatchKeyValueVector(ent2, "origin", origin);

			DispatchKeyValue(ent2, "disablereceiveshadows", "1");
			DispatchKeyValue(ent2, "framerate", "3.0");
			DispatchKeyValueFloat(ent2, "GlowProxySize", 10.0);
			DispatchKeyValueFloat(ent2, "HDRColorScale", 1.0);
			DispatchKeyValue(ent2, "maxdxlevel", "0");
			DispatchKeyValue(ent2, "mindxlevel", "0");

			switch(g_ItemArray[GetRandomInt(0, g_NumItems-1)])
			{
			case ITEM_SHOTGUN:
				{
					DispatchKeyValue(ent2, "model", SPRITE_SHOTGUN);
					SDKHook(ent, SDKHook_StartTouch, OnShotgunTouchOnce);
				}
			case ITEM_ROCKETLAUNCHER:
				{
					DispatchKeyValue(ent2, "model", SPRITE_ROCKETLAUNCHER);
					SDKHook(ent, SDKHook_StartTouch, OnRocketLauncherTouchOnce);
				}
			case ITEM_BERSERK:
				{
					DispatchKeyValue(ent2, "model", SPRITE_BERSERK);
					SDKHook(ent, SDKHook_StartTouch, OnBerserkTouchOnce);
				}
			default:
				{
					DispatchKeyValue(ent2, "model", SPRITE_INVULN);
					SDKHook(ent, SDKHook_StartTouch, OnInvulnerabilityTouchOnce);
				}
			}

			DispatchKeyValue(ent2, "renderamt", "255");
			DispatchKeyValue(ent2, "rendercolor", "255 255 255 255");
			DispatchKeyValue(ent2, "renderfx", "0");
			DispatchKeyValue(ent2, "rendermode", "4");
			DispatchKeyValue(ent2, "scale", "1.0");

			DispatchSpawn(ent2);

			ActivateEntity(ent2);

			SetVariantString("!activator");
			AcceptEntityInput(ent2, "SetParent", ent);

			CreateTimer(gf_ItemRespawn * ITEM_RESPAWN_DELAY, Timer_RemoveEntityWithoutMayhem, EntIndexToEntRef(ent), TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			KillWithoutMayhem(ent);
		}
	}
}

public Action OnShotgunTouchOnce( int prop, int entity )
{
	if(entity > 0 && entity <= MaxClients && GetClientTeam(entity) == g_BossTeam && !TF2_IsPlayerInCondition(entity, TFCond_CritHype))
	{
		TF2_RemoveWeaponSlot(entity, 1);
		int weapon = SpawnWeapon(entity, "tf_weapon_shotgun_soldier", 10, 100, 5, g_ShotgunAtt);
		if(IsValidEntity(weapon))
		{
			SetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon", weapon);
			SetAmmo(entity, weapon, g_ShotGunAmmo[0], g_ShotGunAmmo[1]);

			EmitSoundToAll(SOUND_WEAPPICKUP, entity);
			SetDoomUI(entity, EMOTION_HAPPY);
		}

		KillWithoutMayhem(prop);
	}
}

public Action OnRocketLauncherTouchOnce( int prop, int entity )
{
	if(entity > 0 && entity <= MaxClients && GetClientTeam(entity) == g_BossTeam && !TF2_IsPlayerInCondition(entity, TFCond_CritHype))
	{
		TF2_RemoveWeaponSlot(entity, 0);
		int weapon = SpawnWeapon(entity, "tf_weapon_rocketlauncher", 18, 100, 5, g_RocketAtt);
		if(IsValidEntity(weapon))
		{
			SetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon", weapon);
			SetAmmo(entity, weapon, g_RocketAmmo[0], g_RocketAmmo[1]);

			EmitSoundToAll(SOUND_WEAPPICKUP, entity);
			SetDoomUI(entity, EMOTION_HAPPY);
		}

		KillWithoutMayhem(prop);
	}
}

public Action OnInvulnerabilityTouchOnce( int prop, int entity )
{
	if(entity > 0 && entity <= MaxClients && GetClientTeam(entity) == g_BossTeam)
	{
		TF2_AddCondition(entity, TFCond_Ubercharged, gf_PowerupDuration);
		TF2_AddCondition(entity, TFCond_MegaHeal, gf_PowerupDuration);

		EmitSoundToAll(SOUND_INVULN);
		SetDoomUI(entity, EMOTION_INVULN);
		
		KillWithoutMayhem(prop);
	}
}

public Action OnBerserkTouchOnce( int prop, int entity )
{
	if(entity > 0 && entity <= MaxClients && GetClientTeam(entity) == g_BossTeam)
	{
		int weapon = GetPlayerWeaponSlot(entity, TFWeaponSlot_Melee);					// this will probably never fail, but whatever.
		if (weapon != -1)
		{
			static char classname[32];
			if(GetEntityClassname(weapon, classname, 64))
			{
				TF2_RemoveWeaponSlot(entity, 0);
				TF2_RemoveWeaponSlot(entity, 1);

				FakeClientCommand(entity, "use %s", classname);
				SetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon", weapon);
				
				TF2_AddCondition(entity, TFCond_CritHype, gf_PowerupDuration);
				TF2_AddCondition(entity, TFCond_MegaHeal, gf_PowerupDuration);

				EmitSoundToAll(SOUND_ITEMPICKUP, entity);
				SetDoomUI(entity, EMOTION_HAPPY);
			}
		}

		KillWithoutMayhem(prop);
	}
}


public Action Timer_DoomguyThink(Handle timer, any userid)	// powers the hud ai
{
	if(gb_Doom)
	{
		int client = GetClientOfUserId(userid);
		if(client && IsClientInGame(client))
		{
			if(IsPlayerAlive(client) && GetClientTeam(client) == g_BossTeam)
			{
				if(!gb_CanRage)
				{
					int bossidx = FF2_GetBossIndex(client);
					if(bossidx != -1)
					{
						FF2_SetBossCharge( bossidx, 0, 0.0 );
					}
				}

				if(GetEngineTime() > gf_NextEmotion[client])
				{
					switch(GetRandomInt(0, LOOK_CHANCE))
					{
					case 0:
						{
							SetDoomUI(client, EMOTION_LEFT);
						}
					case 1:
						{
							SetDoomUI(client, EMOTION_RIGHT);
						}
					default:
						{
							SetDoomUI(client, EMOTION_NEUTRAL);
						}
					}
				}
				return Plugin_Continue;
			}
			else
			{
				SetOverlay(client, "");
			}
		}
	}

	return Plugin_Stop;
}

void SetDoomUI(int client, int emotion)								// draws the hud
{
	switch(emotion)
	{
	case EMOTION_HAPPY:
		{
			gf_NextEmotion[client] = GetEngineTime() + HAPPY_DURATION;
			SetOverlay(client, "freak_fortress_2/doom/doomguy_happy");
		}
	case EMOTION_INVULN:
		{
			gf_NextEmotion[client] = GetEngineTime() + gf_PowerupDuration;
			SetOverlay(client, "freak_fortress_2/doom/doomguy_invuln");
		}
	case EMOTION_LEFT:
		{
			gf_NextEmotion[client] = GetEngineTime() + LOOK_DURATION;
			SetOverlay(client, "freak_fortress_2/doom/doomguy_normal_l");
		}
	case EMOTION_RIGHT:
		{
			gf_NextEmotion[client] = GetEngineTime() + LOOK_DURATION;
			SetOverlay(client, "freak_fortress_2/doom/doomguy_normal_r");
		}
	case EMOTION_NEUTRAL:
		{
			SetOverlay(client, "freak_fortress_2/doom/doomguy_normal_c");
		}
	}
}


//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////  Hidden Passive Stuff

public Action Timer_CreateHidden(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if(gb_Hidden && client && g_boss == client && IsClientInGame(client) && IsPlayerAlive(client))
	{
		g_OnWall = HIDDEN_DETATCHED;
		SDKUnhook(client, SDKHook_PreThink, OnPreThink);						// just to be safe, though generally won't ever happen
		SDKHook(client, SDKHook_PreThink, OnPreThink);
		
/**
		int team = GetClientTeam(client) == 3 ? 2 : 3;

		if(FF2_GetAbilityArgument(0, this_plugin_name, "special_hidden", 4, 1))
		{
			for(int player=1; player<=MaxClients; player++)
			{
				if(player != client && IsClientInGame(player) && IsPlayerAlive(player))
				{
// add glow to clients, if you want
				}
			}
		}
**/

	}
}

public void OnPreThink(int client)
{
	if(g_boss == client) // meh. not the best way, but a surefire way
	{
		int buttons = GetClientButtons(client);
		if(buttons & IN_ATTACK)
		{
			if(g_OnWall == HIDDEN_ATTACHED)
			{
				DetatchFromWall(client);
			}
		}
		else	if(buttons & IN_ATTACK2)
		{
			if(g_OnWall == HIDDEN_DETATCHED)
			{
				if(!(GetEntityFlags(client) & FL_ONGROUND) && GetEntPropFloat(client, Prop_Send, "m_flCloakMeter") > gf_MinAttach)
				{
					AttachToWall(client);
				}
			}
		}
		else
		{
			if(TF2_IsPlayerInCondition(client, TFCond_Cloaked))			// fire and bleeds can still sneak past the onconditionadded check =/ sloppy sloppy sloppy
			{
				TF2_RemoveCondition(client, TFCond_OnFire);
				TF2_RemoveCondition(client, TFCond_Milked);
				TF2_RemoveCondition(client, TFCond_Bleeding);
				TF2_RemoveCondition(client, TFCond_MarkedForDeath);
			}
			switch(g_OnWall)
			{
				case HIDDEN_ATTACHED:
				{
					if(GetEntPropFloat(client, Prop_Send, "m_flCloakMeter") < gf_MinAttach)
					{
						DetatchFromWall(client);
					}
					else
					{
						TF2_AddCondition(client, TFCond_DeadRingered, 1.0);
					}
				}
			}
		}
	}
	else
	{
		SDKUnhook(client, SDKHook_PreThink, OnPreThink);						// they are not the boss, or boss state has been revoked
	}
}

void AttachToWall(int client)														// based on Mecha's Khopesh Climber
{
	static float clientpos[3];
	static float angles[3];
	GetClientEyePosition(client, clientpos);										// Get the position of the player's eyes
	GetClientEyeAngles(client, angles);											// Get the angle the player is looking

	TR_TraceRayFilter(clientpos, angles, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelf, client);

	if (TR_DidHit(INVALID_HANDLE))
	{
		static char classname[11];
		if(GetEntityClassname(TR_GetEntityIndex(INVALID_HANDLE), classname, 11) && StrEqual(classname, "worldspawn"))
		{
			TR_GetPlaneNormal(INVALID_HANDLE, angles);
			GetVectorAngles(angles, angles);

			if (angles[0] >= 30.0 && angles[0] <= 330.0) return;
			if (angles[0] <= -30.0) return;

			static float endpos[3];
			TR_GetEndPosition(endpos);

			if (GetVectorDistance(clientpos, endpos, true) < gf_WallDist)
			{
				SetEntityMoveType(client, MOVETYPE_NONE);
				g_OnWall = HIDDEN_ATTACHED;
			}
		}
	}
}

void DetatchFromWall(int client)
{
	SetEntityMoveType(client, MOVETYPE_WALK);
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));

	TF2_RemoveCondition(client, TFCond_Cloaked);

	g_OnWall = HIDDEN_DETATCHING;
	CreateTimer(gf_ReattachDelay, Timer_Detatch);
}

public Action Timer_Detatch(Handle timer)
{
	g_OnWall = HIDDEN_DETATCHED;
}

void TerminateHidden()
{
	g_boss = 0;
	gb_Hidden = false;
}

//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////  Predator Passive Stuff

void SetVisionMode(int client, int mode)								// handles setting predator's vision modes (cloak, rage, normal)
{
	switch(mode)
	{
	case VISION_NORMAL:
		{
			if(gf_rageTime > GetEngineTime())			// check if still in rage and return to it
			{
				SetVisionMode(client,  VISION_RAGE);		// hur dur
				HideSprites(true);
			}
			else
			{
				SetOverlay(client, "");
				HideSprites(false);
			}
		}
	case VISION_CLOAK:
		{
			SetOverlay(client, "debug/yuv");
			HideSprites(true);
		}
	case VISION_RAGE:
		{
			SetOverlay(client, "Effects/combine_binocoverlay");
			HideSprites(true);
			EmitSoundToAll(SOUND_RAGE_ON, client);
		}
	}
}

void CreateSprites(int client)									// gonna show spies in stealth and stuff, sorry spies :3
{
	int particle;
	static float pos[3];

	for (int target = 1; target<=MaxClients; target++)
	{
		particle = EntRefToEntIndex(g_sprite[target]);
		if(particle != INVALID_ENT_REFERENCE)
		{
			RemoveEntity(particle);
		}
		
		if(target != client && IsClientInGame(target) && IsPlayerAlive(target))
		{
			particle = CreateEntityByName("env_spritetrail");
			if (particle != -1)
			{
				GetClientAbsOrigin(target, pos);
				pos[2] += 33.0;

				DispatchKeyValueVector(particle, "origin", pos);
				DispatchKeyValue(particle, "spritename",  TRAIL_SPRITE);
				DispatchKeyValue(particle, "rendercolor", "255 255 255");
				SetEntPropFloat(particle, Prop_Send, "m_flTextureRes", 0.10);	

				DispatchKeyValue(particle, "rendermode", "5");
				DispatchKeyValue(particle, "renderamt", SPRITE_RENDERAMT);

				DispatchKeyValue(particle, "lifetime", "0.5");
				DispatchKeyValue(particle, "startwidth", "70.0");
				DispatchKeyValue(particle, "endwidth", "40.0");

				DispatchSpawn(particle);

				SetVariantString("!activator");
				AcceptEntityInput(particle, "SetParent", target);

				g_sprite[target] = EntIndexToEntRef(particle);
				SDKHook(particle, SDKHook_SetTransmit, TransmitBossOnly);
			}
		}
	}
}

void HideSprites(bool hide)									// shows or hides sprite trails
{
	if(hide)
	{
		int ent;
		for(int client=1; client<=MaxClients; client++)
		{
			ent = EntRefToEntIndex(g_sprite[client]);
			if(ent != INVALID_ENT_REFERENCE)
			{
				DispatchKeyValue(ent, "renderamt", "0");
				ChangeEdictState(ent, FL_EDICT_CHANGED);
			}
		}
	}
	else
	{
		int ent;
		for(int client=1; client<=MaxClients; client++)
		{
			ent = EntRefToEntIndex(g_sprite[client]);
			if(ent != INVALID_ENT_REFERENCE)
			{
				DispatchKeyValue(ent, "renderamt", SPRITE_RENDERAMT);
				ChangeEdictState(ent, FL_EDICT_CHANGED);
			}
		}
	}
}

public Action TransmitBossOnly(int particle, int client)
{
	if(client != g_boss)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

void TerminatePredatorEffects()								// ends predator as the boss, removes overlays, cleans up sprites
{
	if(IsClientInGame(g_boss))
	{
		SetOverlay(g_boss, "");
	}

	int ent;
	for(int client=1; client<=MaxClients; client++)
	{
		ent = EntRefToEntIndex(g_sprite[client]);
		if(ent != INVALID_ENT_REFERENCE)
		{
			RemoveEntity(ent);
		}
	}
	
	gb_predator = false;
	gf_rageTime = 0.0;
	g_boss = 0;
}

void SpawnTrophy(int client)										// Spawns a grabbable physprop
{
	int ent = CreateEntityByName("prop_physics_override");
	if(ent != -1)
	{
		static float origin[3];
		GetClientEyePosition(client, origin);
		origin[2] += 2.0;

		DispatchKeyValueVector(ent, "origin", origin);

		DispatchKeyValue(ent, "solid", "6");
		DispatchKeyValue(ent, "model", MODEL_TROPHY_DUMMY);	// this one's for business
		DispatchKeyValue(ent, "disableshadows", "1");
		DispatchKeyValue(ent, "spawnflags", "8192");			// need to hit clients, physics, debris

		DispatchSpawn(ent);

		ActivateEntity(ent);

		AcceptEntityInput(ent, "EnableMotion");				// should start motion enabled, whatever.

		SetEntProp(ent, Prop_Send, "m_CollisionGroup", 1);		// This is a trigger
		SetEntProp(ent, Prop_Send, "m_usSolidFlags", 8);			// Fire trigger even if not solid
		
		SetEntPropFloat(ent, Prop_Send, "m_flModelScale", 0.001);	// color and alpha and nodraw do not seem to always work.
		
		int ent2 = CreateEntityByName("prop_dynamic");
		if(ent2 != -1)
		{
			DispatchKeyValueVector(ent2, "origin", origin);
			
			DispatchKeyValue(ent2, "solid", "0");
			DispatchKeyValue(ent2, "model", MODEL_TROPHY);	// this one's for show
			DispatchKeyValue(ent2, "disableshadows", "1");

			DispatchSpawn(ent2);

			ActivateEntity(ent2);

			SetVariantString("!activator");
			AcceptEntityInput(ent2, "SetParent", ent);

			SDKHook(ent, SDKHook_StartTouch, OnTrophyTouch);

			CreateTimer(gf_TrophyTime, Timer_RemoveEntityWithoutMayhem, EntIndexToEntRef(ent), TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			KillWithoutMayhem(ent);
		}
	}
}

public Action OnTrophyTouch( int prop, int entity )				// Refunds stealth to boss on pickup
{
	if(entity == g_boss)
	{
		float cloakmeter = GetEntPropFloat(entity, Prop_Send, "m_flCloakMeter");
		cloakmeter += gf_TrophyPct;
		if(cloakmeter > 100.0)
		{
			cloakmeter = 100.0;
		}
		SetEntPropFloat(entity, Prop_Send, "m_flCloakMeter", cloakmeter);
		
		KillWithoutMayhem(prop);
		
		EmitSoundToAll(SOUND_TROPHY, entity);
	}
}

//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////  Predator Active Rage

void Rage_UsePredator(const char[] ability_name, int index)
{
	int userid = FF2_GetBossUserId(index);
	int client = GetClientOfUserId(userid);
	float time = GetEngineTime();
	float duration = FF2_GetAbilityArgumentFloat(index,this_plugin_name,ability_name, 1, 15.0);
	if(gf_rageTime > time)			// old rage, add time
	{
		gf_rageTime += duration;
	}
	else								// int rage, make stuff
	{
		gf_rageTime = time + duration;
		SetVisionMode(client, VISION_RAGE);

		CreateTimer(0.5, Timer_Predator, userid, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_Predator(Handle timer, any userid)
{
	int boss = GetClientOfUserId(userid);
	if(boss == g_boss && IsClientInGame(boss))
	{
		if(gb_predator && IsPlayerAlive(boss))
		{
			if(gf_rageTime > GetEngineTime())					// rage is active
			{
				static float clientpos[3];

				for(int target=1;target<=MaxClients;target++)
				{
					if(boss != target && IsClientInGame(target) && IsPlayerAlive(target))
					{
						GetClientEyePosition(target, clientpos);
						clientpos[2] -= 20.0;

						TE_SetupGlowSprite(clientpos, g_TargetSprite, 0.5, 1.0, 120);
						TE_SendToClient(boss);
					}
				}
				
				TurretThink(boss);

				return Plugin_Continue;
			}
			
			EmitSoundToAll(SOUND_RAGE_OFF, boss);

			if(TF2_IsPlayerInCondition(boss, TFCond_Cloaked))
			{
				SetVisionMode(boss, VISION_CLOAK);				// if they are cloaked when their rage ends, give them cloak vision
			}
			else
			{
				SetVisionMode(boss, VISION_NORMAL);				// normal vision when rage ended
			}
		}
		else
		{
			SetOverlay(boss, "");								// always terminate their vision when boss abilities end	
		}
	}

	return Plugin_Stop;
}

void TurretThink(int client)										// Shoulder cannon AI
{
	static float turretpos[3], playerpos[3], anglevector[3], targetvector[3], angles[3], vecrt[3], ang;
	int bossteam = GetClientTeam(client);
	int playerarray[MAXPLAYERS+1];
	int playercount;

	GetClientEyePosition(client, turretpos);
	GetClientEyeAngles(client, angles);

	GetAngleVectors(angles, anglevector, vecrt, NULL_VECTOR);

	turretpos[0] += anglevector[0]*-10.0 + vecrt[0]*15.0;											// set the turret's position to the client's shoulder
	turretpos[1] += anglevector[1]*-10.0 + vecrt[1]*15.0;
	turretpos[2] += anglevector[2]*-10.0 + vecrt[2]*15.0;

	TR_TraceRayFilter(turretpos, angles, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelf, client);
	TR_GetEndPosition(targetvector);

	NormalizeVector(anglevector, anglevector);

	for(int player = 1; player <= MaxClients; player++)
	{
		if(player != client && IsClientInGame(player) && IsPlayerAlive(player))
		{
			GetClientEyePosition(player, playerpos);
			playerpos[2] -= 30.0;
			if(GetVectorDistance(turretpos, playerpos, true) < gf_CannonDistance  && CanSeeTarget(turretpos, playerpos, player, bossteam))
			{
				MakeVectorFromPoints(turretpos, playerpos, targetvector);
				NormalizeVector(targetvector, targetvector);

				ang = RadToDeg(ArcCosine(GetVectorDotProduct(targetvector, anglevector)));
				if(ang <= TURRET_FIREANGLE)	
				{
					playerarray[playercount] = player;
					playercount++;
				}
			}
		}
	}

	if(playercount)
	{
		int target = playerarray[GetRandomInt(0, playercount-1)];
		CreateProjectile(client, target, turretpos, angles, anglevector);
		
		EmitSoundToAll(SOUND_TURRET_FIRE, 0, SNDCHAN_WEAPON, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, turretpos);

		TE_SetupGlowSprite(turretpos, g_CannonSprite, 0.2, 1.5, 180);
		TE_SendToAll();
		
		TF2_RemoveCondition(client, TFCond_Cloaked);
	}
}

void CreateProjectile(int client, int target, float origin[3], float eyeangles[3], float anglevector[3])	// Fires a single projectile
{
	int entity = CreateEntityByName("tf_projectile_energy_ball");				// because bison particles == blue balls of light on blue team
	if(entity != -1)
	{
		DispatchSpawn(entity);
		
		SetEntProp(entity, Prop_Send, "m_CollisionGroup", 4);
		SetEntProp(entity, Prop_Send, "m_iTeamNum", GetClientTeam(client));
		SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);				// store attacker
		SetEntPropEnt(entity, Prop_Send, "m_nForceBone", target);				// store intended target
		SetEntProp(entity, Prop_Data, "m_takedamage", 0);						// don't want them to be shot down/destroyed
		SetEntPropVector(entity, Prop_Send, "m_vecMins", view_as<float>({0.0, 0.0, 0.0}));	// the pellet size should be tiny... they will still collide normally
		SetEntPropVector(entity, Prop_Send, "m_vecMaxs", view_as<float>({0.0, 0.0, 0.0}));
		
		NormalizeVector(anglevector, anglevector);
		ScaleVector(anglevector, gf_CannonSpeed);
		
		TeleportEntity(entity, origin, eyeangles, anglevector);
		
		SDKHook(entity, SDKHook_StartTouch, ProjectileTouchHook);				// force projectile to deal damage on touch
		
		MakeProjectileHoming(entity, target, false, gf_CannonSpeed);
	}
}

public Action ProjectileTouchHook(int entity, int other)			// Wat happens when this projectile touches something
{
	if(other > 0 && other <= MaxClients)
	{
		int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if(client > 0 && client <= MaxClients && IsClientInGame(client))			// will probably just be -1, but whatever.
		{
			gf_diedPredCannon[other] = GetEngineTime();
			SDKHooks_TakeDamage(other, client, client, gf_CannonDamage, DMG_SHOCK|DMG_ALWAYSGIB);
		}
	}
}

//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////  Skulls Active Rage

void Rage_UseSkulls(const char[] ability_name, int index)
{
	int userid = FF2_GetBossUserId(index);
	float time = GetEngineTime();
	float duration = FF2_GetAbilityArgumentFloat(index,this_plugin_name,ability_name, 1, 15.0);
	if(gf_rageTime > time)			// old rage, add time
	{
		gf_rageTime += duration;
	}
	else								// int rage, make stuff
	{
		gf_rageTime = time + duration;
		
		ActivateFlame(true);

		CreateTimer(0.5, Timer_Skulls, userid, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_Skulls(Handle timer, any userid)			// Updates boss rage stuffs
{
	int boss = GetClientOfUserId(userid);
	if(boss == g_boss && IsClientInGame(boss))
	{
		if(gb_Skulls && IsPlayerAlive(boss))
		{
			if(gf_rageTime > GetEngineTime())					// rage is active
			{
				// do stuff ?

				return Plugin_Continue;
			}
			
			ActivateFlame(false);								// rage is over
		}
	}

	ActivateFlame(false);										// mabye he died or something, try to turn them off

	return Plugin_Stop;
}

void ActivateFlame(bool enable)									// Sets head/eye glow on or off
{
	if(enable)
	{
		int ent = EntRefToEntIndex(g_flameEnt[0]);
		if(ent != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(ent, "start");
		}
		ent = EntRefToEntIndex(g_flameEnt[1]);
		if(ent != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(ent, "start");
		}
		ent = EntRefToEntIndex(g_flameEnt[2]);
		if(ent != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(ent, "start"); 
		}
	}
	else
	{
		int ent = EntRefToEntIndex(g_flameEnt[0]);
		if(ent != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(ent, "stop");
		}
		ent = EntRefToEntIndex(g_flameEnt[1]);
		if(ent != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(ent, "stop");
		}
		ent = EntRefToEntIndex(g_flameEnt[2]);
		if(ent != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(ent, "stop");
		}
	}
}

void ThrowFireBall(int client)										// Creates a single projectile
{
	static float turretpos[3], playerpos[3], anglevector[3], targetvector[3], angles[3], vecrt[3], ang;
	int bossteam = GetClientTeam(client);
	int playerarray[MAXPLAYERS+1];
	int playercount;

	GetClientEyePosition(client, turretpos);
	GetClientEyeAngles(client, angles);

	GetAngleVectors(angles, anglevector, vecrt, NULL_VECTOR);

	turretpos[0] += anglevector[0]*30.0 + vecrt[0]*25.0;											// set the turret's position to the client's right arm
	turretpos[1] += anglevector[1]*30.0 + vecrt[1]*25.0;
	turretpos[2] += anglevector[2]*30.0 + vecrt[2]*25.0;

	TR_TraceRayFilter(turretpos, angles, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelf, client);
	TR_GetEndPosition(targetvector);

	NormalizeVector(anglevector, anglevector);

	for(int player = 1; player <= MaxClients; player++)
	{
		if(player != client && IsClientInGame(player) && IsPlayerAlive(player))
		{
			GetClientEyePosition(player, playerpos);
			playerpos[2] -= 30.0;
			if(GetVectorDistance(turretpos, playerpos, true) < gf_CannonDistance  && CanSeeTarget(turretpos, playerpos, player, bossteam))
			{
				MakeVectorFromPoints(turretpos, playerpos, targetvector);
				NormalizeVector(targetvector, targetvector);

				ang = RadToDeg(ArcCosine(GetVectorDotProduct(targetvector, anglevector)));
				if(ang <= TURRET_FIREANGLE)	
				{
					playerarray[playercount] = player;
					playercount++;
				}
			}
		}
	}

	if(playercount)		// found a target to home in on
	{
		int target = playerarray[GetRandomInt(0, playercount-1)];
		CreateFireballProjectile(client, target, turretpos, angles, anglevector);
	}
	else					// just do it
	{
		CreateFireballProjectile(client, -1, turretpos, angles, anglevector);
	}
	
	EmitSoundToAll(gs_booms[GetRandomInt(0, sizeof(gs_booms)-1)], 0, SNDCHAN_WEAPON, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, turretpos);
	TE_SetupGlowSprite(turretpos, gs_RedSprite, 0.2, 1.0, 180);
	TE_SendToAll();
}

void CreateFireballProjectile(int client, int target, float origin[3], float eyeangles[3], float anglevector[3])
{
	int entity = CreateEntityByName("tf_projectile_rocket");					// because fire particles
	if(entity != -1)
	{
		DispatchSpawn(entity);
		
		SetEntityModel(entity, MODEL_ROCKET);
		SetEntProp(entity, Prop_Send, "m_CollisionGroup", 4);
		SetEntProp(entity, Prop_Send, "m_iTeamNum", GetClientTeam(client));		// make it red :|
		SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);			// store attacker
		SetEntPropEnt(entity, Prop_Send, "m_nForceBone", target);				// store intended target
		SetEntProp(entity, Prop_Data, "m_takedamage", 0);						// don't want them to be shot down/destroyed
		SetEntPropVector(entity, Prop_Send, "m_vecMins", view_as<float>({0.0, 0.0, 0.0}));	// the pellet size should be tiny... they will still collide normally
		SetEntPropVector(entity, Prop_Send, "m_vecMaxs", view_as<float>({0.0, 0.0, 0.0}));
		
		NormalizeVector(anglevector, anglevector);
		ScaleVector(anglevector, gf_CannonSpeed);

		IgniteEntity(entity, 1.0);											// only stays ignited for short time
		StopSound(entity, SNDCHAN_WEAPON, "ambient/fire/fire_small_loop2.wav");	// may not be needed, but whatever.
		CreateTimer(1.0, Timer_IgniteEntity, EntIndexToEntRef(entity), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);		// sigh.. but scounts or slow projectiles

		TeleportEntity(entity, origin, eyeangles, anglevector);

		SDKHook(entity, SDKHook_StartTouch, FireProjectileTouchHook);			// force projectile to deal damage on touch
		
		MakeProjectileHoming(entity, target, false, gf_CannonSpeed);
	}
}

public Action Timer_IgniteEntity(Handle timer, any ref)		// Re-ignites the projectile, since it doesn't want to stay aflame...
{
	int ent = EntRefToEntIndex(ref);
	if(ent != INVALID_ENT_REFERENCE)
	{
		ExtinguishEntity(ent);
		IgniteEntity(ent, 1.0, _, 30.0);
		StopSound(ent, SNDCHAN_WEAPON, "ambient/fire/fire_small_loop2.wav");

		return Plugin_Continue;
	}

	return Plugin_Stop;
}

public Action FireProjectileTouchHook(int entity, int other)
{
	if(other > 0 && other <= MaxClients)
	{
		int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if(client > 0 && client <= MaxClients && IsClientInGame(client))			// will probably just be -1, but whatever.
		{
			gf_diedFireball[other] = GetEngineTime();
			SDKHooks_TakeDamage(other, client, client, gf_CannonDamage, DMG_BURN|DMG_ALWAYSGIB);
			TF2_IgnitePlayer(other, other);										// if hale ignites them it will rape them.
			if(gf_IgniteTime < 10.0)
			{
				CreateTimer(gf_IgniteTime, Timer_ExtinguishPlayer, GetClientUserId(other), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////  Skulls Active Rage

void Rage_UseAsh(const char[] ability_name, int index)
{
	int userid = FF2_GetBossUserId(index);
	float time = GetEngineTime();
	float duration = FF2_GetAbilityArgumentFloat(index,this_plugin_name,ability_name, 1, 10.0);
	if(gf_rageTime > time)			// old rage, add time
	{
		gf_rageTime += duration;
	}
	else								// int rage, make stuff
	{
		gf_rageTime = time + duration;
		ActivateChainsaw(GetClientOfUserId(userid));
		CreateTimer(0.5, Timer_Ash, userid, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_Ash(Handle timer, any userid)					// Updates boss rage stuffs
{
	int boss = GetClientOfUserId(userid);
	if(boss && IsClientInGame(boss))
	{
		if(gb_Ash && boss == g_boss && IsPlayerAlive(boss))
		{
			if(gf_rageTime > GetEngineTime())					// rage is active
			{
				// do stuff ?

				return Plugin_Continue;
			}

			int trigger = EntRefToEntIndex(g_chainsawref);
			if(trigger != INVALID_ENT_REFERENCE)
			{
				RemoveEntity(trigger);
			}

			TF2_RemoveWeaponSlot(boss, TFWeaponSlot_Melee);		// just incase incase
			int weapon = SpawnWeapon(boss, gs_bossweaponclassname, g_bossweaponindex , 101, 5, gs_bossweaponattribs);
			if(IsValidEntity(weapon))
			{
				SetEntPropFloat(weapon, Prop_Send, "m_flModelScale", 0.001);
				FakeClientCommand(boss, "use %s", gs_bossweaponclassname);
			}

			weapon = GetPlayerWeaponSlot(boss, TFWeaponSlot_Secondary);
			if(weapon != -1)
			{
				StopSound(boss, SNDCHAN_AUTO, SOUND_CHAINSAW);
				
				int viewmodel = GetEntPropEnt(weapon, Prop_Send, "m_hExtraWearableViewModel");
				if(IsValidEntity(viewmodel))
				{
					SDK_RemoveWearable(boss, viewmodel);
				}
				
				TF2_RemoveWeaponSlot(boss, TFWeaponSlot_Secondary);	// rage is over
			}
		}

		StopSound(boss, SNDCHAN_AUTO, SOUND_CHAINSAW);				// just in case
	}

	return Plugin_Stop;
}

void CreateChainsaw(int client)
{
	int trigger = EntRefToEntIndex(g_chainsawref);
	if(trigger != INVALID_ENT_REFERENCE)
	{
		RemoveEntity(trigger);
	}
	
	trigger = CreateEntityByName("trigger_hurt");
	if(trigger != -1)
	{
		static float origin[3];
		static float ang[3];
		GetClientAbsOrigin(client, origin);
		GetClientAbsAngles(client, ang);

		DispatchKeyValueVector(trigger, "origin", origin);
		DispatchKeyValueVector(trigger, "angles", ang);
		DispatchKeyValue(trigger, "spawnflags", "65");
		DispatchKeyValueFloat(trigger, "damage", gf_CannonDamage);
		DispatchKeyValueFloat(trigger, "damagecap", gf_CannonDamage);
		DispatchKeyValue(trigger, "damagetype", "65536");
		DispatchKeyValue(trigger, "damagemodel", "0");
		DispatchKeyValue(trigger, "StartDisabled", "0");

		DispatchSpawn(trigger);
		ActivateEntity(trigger);
		
		AcceptEntityInput(trigger, "Enable");

		SetEntityModel(trigger, MODEL_ITEM_DUMMY);
		
		SetEntPropVector(trigger, Prop_Send, "m_vecMins", view_as<float>({-15.0, -15.0, -15.0}));
		SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", view_as<float>({15.0, 15.0, 15.0}));

		SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);

		SetVariantString("!activator");
		AcceptEntityInput(trigger, "SetParent", client);
		
		SetVariantString("chainsaw_blade");
		AcceptEntityInput(trigger, "SetParentAttachmentMaintainOffset", client);

		int ref = EntIndexToEntRef(trigger);
		g_chainsawref = ref;
	}
}

void ActivateChainsaw(int client)
{
	CreateChainsaw(client);

	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);		// just incase incase
	int weapon = SpawnWeapon(client,"tf_weapon_raygun", 442, 100, 5, "2; 0.0; 551 ; 1");
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
	if(IsValidEntity(weapon))
	{
		EmitSoundToAll(SOUND_CHAINSAW, client, SNDCHAN_AUTO);
		FakeClientCommand(client, "use tf_weapon_raygun");

		SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", 999999.0);
		SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", 999999.0);

		int vm = -1;
		while( ( vm = FindEntityByClassname2( vm, "tf_viewmodel" ) ) != -1 )	// hide the view model
		{ 
			if(client == GetEntPropEnt(vm, Prop_Send, "m_hOwner"))
			{
				SetEntProp(vm, Prop_Send, "m_fEffects", GetEntProp(vm, Prop_Send, "m_fEffects") & ~EF_NODRAW);
				ChangeEdictState(vm, g_effectsOffset);
			}
		}

		SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
		SetEntityRenderColor(weapon, 0, 0, 0, 0);

		vm = CreateVM(client, g_chainsawmodel);
		if(vm != -1)
		{
			SetEntPropEnt(vm, Prop_Send, "m_hWeaponAssociatedWith", weapon);
			SetEntPropEnt(weapon, Prop_Send, "m_hExtraWearableViewModel", vm);
		}
	}
}

void TerminateAshe()
{
	gb_Ash = false;
	gf_rageTime = 0.0;
	g_boss = 0;

	int trigger = EntRefToEntIndex(g_chainsawref);
	if(trigger != INVALID_ENT_REFERENCE)
	{
		RemoveEntity(trigger);
	}
}

/////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////	 Stocks

void SetOverlay(int client, const char[] overlay)						// changes a client's screen overlay (requires clientcommand, they could disable so, enforce with smac or something if you care.)
{
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
	ClientCommand(client, "r_screenoverlay \"%s\"", overlay); 
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") | FCVAR_CHEAT);
}

public Action Timer_RemoveEntityWithoutMayhem(Handle timer, any ref)			// removes an entity
{
	int ent = EntRefToEntIndex(ref);
	if(ent != INVALID_ENT_REFERENCE)
	{
		KillWithoutMayhem(ent);
	}
}

stock int FindEntityByClassname2(int startEnt, const char[] classname)	// because legacy
{
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
	return FindEntityByClassname(startEnt, classname);
}

stock int SpawnWeapon(int client, char[] name, int index, int level, int qual,char[] att)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	char atts[32][32];
	int count = ExplodeString(att, ";", atts, 32, 32);
	if (count > 1)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		int i2 = 0;
		for (int i = 0; i < count; i+=2)
		{
			TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
			i2++;
		}
	}
	else
	TF2Items_SetNumAttributes(hWeapon, 0);
	if (hWeapon==INVALID_HANDLE)
	return -1;
	int entity = TF2Items_GiveNamedItem(client, hWeapon);
	CloseHandle(hWeapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}

stock void SetAmmo(int client, int weapon, int ammo, int clip = 0)
{
	if(clip)
	{
		int iClip = GetEntData(weapon, g_iOffsetClip);
		if(iClip != -1)
		{
			SetEntData(weapon, g_iOffsetClip, clip, _, true);
		}
	}
	
	int iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
	SetEntData(client, g_iOffsetAmmo+iOffset, ammo, 4, true);
}

public Action Timer_ExtinguishPlayer(Handle timer, any userid)		// stops a player from burning early
{
	int client = GetClientOfUserId(userid);
	if(client && IsClientInGame(client) && IsPlayerAlive(client))
	{
		TF2_RemoveCondition(client, TFCond_OnFire);
	}
}

public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	return entity != data;
}

public bool TraceRayFilterClients(int entity, int mask, any data)
{
	if(entity > 0 && entity <=MaxClients)					// only hit the client we're aiming at
	{
		if(entity == data)
		{
			return true;
		}
		else
		{
			return false;
		}
	}

	return true;
}

bool CanSeeTarget(float startpos[3], float targetpos[3], int target, int bossteam)		// Tests to see if vec1 > vec2 can "see" target
{
	TR_TraceRayFilter(startpos, targetpos, MASK_SOLID, RayType_EndPoint, TraceRayFilterClients, target);

	if(TR_GetEntityIndex() == target)
	{
		if(TF2_GetPlayerClass(target) == TFClass_Spy)							// if they are a spy, do extra tests (coolrocket stuff?)
		{
			if(TF2_IsPlayerInCondition(target, TFCond_Cloaked))				// if they are cloaked
			{
				if(TF2_IsPlayerInCondition(target, TFCond_CloakFlicker)		// check if they are partially visible
						|| TF2_IsPlayerInCondition(target, TFCond_OnFire)
						|| TF2_IsPlayerInCondition(target, TFCond_Jarated)
						|| TF2_IsPlayerInCondition(target, TFCond_Milked)
						|| TF2_IsPlayerInCondition(target, TFCond_Bleeding))
				{
					return true;
				}
				
				return false;
			}
			if(TF2_IsPlayerInCondition(target, TFCond_Disguised) && GetEntProp(target, Prop_Send, "m_nDisguiseTeam") == bossteam)
			{
				return false;
			}

			return true;
		}

		return true;
	}

	return false;
}

stock int CreateVM(int client, int model)
{
	int ent = CreateEntityByName("tf_wearable_vm");
	if (!IsValidEntity(ent)) return -1;

	SetEntProp(ent, Prop_Send, "m_nModelIndex", model);
	SetEntProp(ent, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL);
	SetEntProp(ent, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(ent, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 11);

	DispatchSpawn(ent);
	SetVariantString("!activator");
	ActivateEntity(ent);

	SDK_EquipWearable(client, ent);

	return ent;
}

stock bool IsEntityWearable(int entity)
{
	if (entity > MaxClients && IsValidEdict(entity))
	{
		char strClassname[32]; GetEdictClassname(entity, strClassname, sizeof(strClassname));
		return (strncmp(strClassname, "tf_wearable", 11, false) == 0 || strncmp(strClassname, "tf_powerup", 10, false) == 0);
	}

	return false;
}

void KillWithoutMayhem(int entity)		// will ensure that props are not in different collision groups and at the same place :/
{
	static float randomvec[3];
	randomvec[0] = GetRandomFloat(-5000.0,5000.0);
	randomvec[1] = GetRandomFloat(-5000.0,5000.0);
	randomvec[2] = -5000.0;
	
	TeleportEntity(entity, randomvec, NULL_VECTOR, NULL_VECTOR); 
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
	
	RemoveEntity(entity);
}


public void MakeProjectileHoming(int iProjectile, int target, bool lockon, float newspeed)
{
	SetEntProp(iProjectile, Prop_Send, "m_nForceBone", target);		  // target to seek

	int array[3];
	array[HOMING_ENTREF] = EntIndexToEntRef(iProjectile);
	array[HOMING_LOCK_TYPE] = lockon;
	array[HOMING_SPEED] = view_as<int>(newspeed);
	g_hArrayHoming.PushArray(array);
}

public void OnGameFrame()
{
	for(int i=g_hArrayHoming.Length-1; i>=0; i--)
	{
		int iData[3];
		g_hArrayHoming.GetArray(i, iData);

		int iProjectile = EntRefToEntIndex(iData[HOMING_ENTREF]);
		if(iProjectile != INVALID_ENT_REFERENCE)
		{
			HomingProjectile_Think(iProjectile, iData[HOMING_LOCK_TYPE], i, float (iData[HOMING_SPEED]));
		}
		else
		{
			g_hArrayHoming.Erase(i);
		}
	}
}

public void HomingProjectile_Think(int iProjectile, int homing, int index, float speed)
{	
	int iCurrentTarget = GetEntProp(iProjectile, Prop_Send, "m_nForceBone");

	if(!HomingProjectile_IsValidTarget(iCurrentTarget, iProjectile, GetEntProp(iProjectile, Prop_Send, "m_iTeamNum")))
	{
		if(homing)
		{
			HomingProjectile_FindTarget(iProjectile, speed);
		}
		else
		{
			g_hArrayHoming.Erase(index);
		}
	}
	else
	{
		HomingProjectile_TurnToTarget(iCurrentTarget, iProjectile, speed);
	}
}

bool HomingProjectile_IsValidTarget(int client, int iProjectile, int iTeam)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) != iTeam)
	{
		if( TF2_IsPlayerInCondition(client, TFCond_Cloaked) ||
				(TF2_IsPlayerInCondition(client, TFCond_Disguised) && GetEntProp(client, Prop_Send, "m_nDisguiseTeam") == iTeam))
		{
			return false;
		}
		
		static float flStart[3];
		GetClientEyePosition(client, flStart);
		static float flEnd[3];
		GetEntPropVector(iProjectile, Prop_Send, "m_vecOrigin", flEnd);
		
		Handle hTrace = TR_TraceRayFilterEx(flStart, flEnd, MASK_SOLID, RayType_EndPoint, TraceFilterHoming, iProjectile);
		if(hTrace != INVALID_HANDLE)
		{
			if(TR_DidHit(hTrace))
			{
				CloseHandle(hTrace);
				return false;
			}
			
			CloseHandle(hTrace);
			return true;
		}
	}
	
	return false;
}

public bool TraceFilterHoming(int entity, int contentsMask, any iProjectile)
{
	if(entity == iProjectile || (entity >= 1 && entity <= MaxClients))
	{
		return false;
	}
	
	return true;
}

void HomingProjectile_FindTarget(int iProjectile, float speed)
{
	static float flPos1[3];
	GetEntPropVector(iProjectile, Prop_Send, "m_vecOrigin", flPos1);
	
	int iBestTarget;
	float flBestLength = 99999.9;
	for(int i=1; i<=MaxClients; i++)
	{
		if(HomingProjectile_IsValidTarget(i, iProjectile, GetEntProp(iProjectile, Prop_Send, "m_iTeamNum")))
		{
			static float flPos2[3];
			GetClientEyePosition(i, flPos2);
			
			float flDistance = GetVectorDistance(flPos1, flPos2);			
			if(flDistance < flBestLength)
			{
				iBestTarget = i;
				flBestLength = flDistance;
			}
		}
	}
	
	if(iBestTarget > 0 && iBestTarget <= MaxClients)
	{
		SetEntProp(iProjectile, Prop_Send, "m_nForceBone", iBestTarget);
		HomingProjectile_TurnToTarget(iBestTarget, iProjectile, speed);
	}
	else
	{
		SetEntProp(iProjectile, Prop_Send, "m_nForceBone", 0);
	}
}

void HomingProjectile_TurnToTarget(int client, int iProjectile, float speed)					// update projectile position
{
	float flTargetPos[3];
	GetClientAbsOrigin(client, flTargetPos);
	float flRocketPos[3];
	GetEntPropVector(iProjectile, Prop_Send, "m_vecOrigin", flRocketPos);

	//flTargetPos[2] += 30 + Pow(GetVectorDistance(flTargetPos, flRocketPos), 2.0) / 10000;
	flTargetPos[2] += 30;
	
	float flNewVec[3];
	SubtractVectors(flTargetPos, flRocketPos, flNewVec);
	NormalizeVector(flNewVec, flNewVec);
	
	float flAng[3];
	GetVectorAngles(flNewVec, flAng);

	if(speed)
	{
		ScaleVector(flNewVec, speed);
	}
	else
	{
		static float flRocketVel[3];
		GetEntPropVector(iProjectile, Prop_Data, "m_vecAbsVelocity", flRocketVel);
/**		// should not need smooth velocity implementation here
		if(flRocketVel[0] == 0.0 && gb_SV)
		{
			SDKCall(g_hSDKGetSmoothedVelocity, iProjectile, flRocketVel);
		}
**/
	
		ScaleVector(flNewVec, GetVectorLength(flRocketVel));
	}
	
	TeleportEntity(iProjectile, NULL_VECTOR, flAng, flNewVec);
}
