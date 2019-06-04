#pragma semicolon 1

#include <sourcemod>
#include <tf2items>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_functions>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <drain_over_time>
#include <drain_over_time_subplugin>
#include <ff2_dynamic_defaults>

/**
 * A third wave of mods, some stuff for Doctor Whooves and maybe one or two others.
 *
 * This pack REQUIRES my drain over time subplugin, and it needs to be updated to the current version.
 *
 * RegenerationShockwave: Emulates the spectacular "death" of the Tenth Doctor, and Ninth to a lesser extent.
 *			  Accepts many settings including knockback ranges, damage ranges, ignite player option, colors...
 *	Known Issues: If a boss wins during this rage, and a player is supposed to have something like donor invincibility, said invincibility will probably be lost.
 *		      When flaming gibs are removed, the for each gib a line gets printed to server console. I don't think there's any way around this.
 *		      It's likely that the flaming gibs will stop trains, much like the gibs of the phatrages ion cannon.
 *	Credits: Like with dot_beam, I used phatrages IonCannon as a starting point for the animation.
 *
 * SentryHijack: A particularly evil DOT rage where the hale can hijack any sentry, and use it almost instantly.
 *	Known Issues: 
 *	Credits: I used the RTD mod as a starting point for creating the hale's sentry.
 *		 HUGE credit to FlaminSarge, who found a number of hidden sentry props, including critical values necessary to get Wrangler to fire.
 *
 * TARDISTimeWarp: There's no real way to make this NOT specific to Doctor Whooves, since ff2 bosses can't really effectively execute another rage.
 *		   Except those in the same pack, of course. This rage summons a TARDIS. Upon any BLU entering, it executes the CharacterScramble rage,
 *		   the MeterScramble rage, the SentryDelevel rage, and it can stun sentries.
 *	Known Issues: Although rare, and although many tests are made before spawning the TARDIS, it's possible for the TARDIS to spawn in some unreachable
 *		      area...though it's most likely that it'd spawn in a damage pit close to safe ground.
 *	Credits: The beacon I ripped straight from RTD mod, since players are familiar with it.
 *
 * =====The rages below are versions of mechanics used above, separated from the above as standalone rages.=====
 *
 * CharacterScramble: A simple rage (and a wonder no one else made it already) where all living red team members have their
 *		      positions, angles, and velocities swapped with each other. Can be set to a time delay.
 *
 * MeterScramble: Simply randomizes various charge meters in a way that's sensible for FF2.
 *		  Medigun charge is randomized from 40-100%, while all other meters are randomized from 0-100%.
 *
 * SentryDelevel: Delevels all sentries on the map, with optional particle effect.
 *
 * FlamingDebris: Shoots flaming debris from the boss.
 *
 * =====BONUS RAGE=====
 *
 * DOTTeleport: I ported over the War3/Otokiru teleport over for use as a DOT rage. Did not fix any of the exploits that exist in the MDW rage.
 *
 * Revamped on 2015-03-22
 */

new bool:PRINT_DEBUG_INFO = true;
new bool:PRINT_DEBUG_SPAM = false;

new Float:OFF_THE_MAP[3] = { 16383.0, 16383.0, -16383.0 };

// text string limits
#define MAX_SOUND_FILE_LENGTH 80
#define MAX_MODEL_FILE_LENGTH 128
#define MAX_MATERIAL_FILE_LENGTH 128
#define MAX_WEAPON_NAME_LENGTH 64
#define MAX_WEAPON_ARG_LENGTH 256
#define MAX_EFFECT_NAME_LENGTH 48
#define MAX_ENTITY_CLASSNAME_LENGTH 48
#define MAX_CENTER_TEXT_LENGTH 128
#define COLOR_BUFFER_SIZE 12

#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

#define NOPE_AVI "vo/engineer_no01.mp3"

#define SOUND_BLIP "buttons/blip1.wav"

enum // Collision_Group_t in const.h
{
	COLLISION_GROUP_NONE  = 0,
	COLLISION_GROUP_DEBRIS,			// Collides with nothing but world and static stuff
	COLLISION_GROUP_DEBRIS_TRIGGER, // Same as debris, but hits triggers
	COLLISION_GROUP_INTERACTIVE_DEBRIS,	// Collides with everything except other interactive debris or debris
	COLLISION_GROUP_INTERACTIVE,	// Collides with everything except interactive debris or debris
	COLLISION_GROUP_PLAYER,
	COLLISION_GROUP_BREAKABLE_GLASS,
	COLLISION_GROUP_VEHICLE,
	COLLISION_GROUP_PLAYER_MOVEMENT,  // For HL2, same as Collision_Group_Player, for
										// TF2, this filters out other players and CBaseObjects
	COLLISION_GROUP_NPC,			// Generic NPC group
	COLLISION_GROUP_IN_VEHICLE,		// for any entity inside a vehicle
	COLLISION_GROUP_WEAPON,			// for any weapons that need collision detection
	COLLISION_GROUP_VEHICLE_CLIP,	// vehicle clip brush to restrict vehicle movement
	COLLISION_GROUP_PROJECTILE,		// Projectiles!
	COLLISION_GROUP_DOOR_BLOCKER,	// Blocks entities not permitted to get near moving doors
	COLLISION_GROUP_PASSABLE_DOOR,	// ** sarysa TF2 note: Must be scripted, not passable on physics prop (Doors that the player shouldn't collide with)
	COLLISION_GROUP_DISSOLVING,		// Things that are dissolving are in this group
	COLLISION_GROUP_PUSHAWAY,		// ** sarysa TF2 note: I could swear the collision detection is better for this than NONE. (Nonsolid on client and server, pushaway in player code)

	COLLISION_GROUP_NPC_ACTOR,		// Used so NPCs in scripts ignore the player.
	COLLISION_GROUP_NPC_SCRIPTED,	// USed for NPCs in scripts that should not collide with each other

	LAST_SHARED_COLLISION_GROUP
};

//new MercTeam = _:TFTeam_Red;
new BossTeam = _:TFTeam_Blue;

#define FAR_FUTURE 100000000.0
#define IsEmptyString(%1) (%1[0] == 0)
#define INVALID_ENTREF INVALID_ENT_REFERENCE

new RoundInProgress = false;
new bool:PluginActiveThisRound = false;

public Plugin:myinfo = {
	name = "Freak Fortress 2: sarysa's mods, third pack",
	author = "sarysa",
	version = "1.1.1",
}

// regeneration shockwave
#define RS_STRING "rage_regeneration_shockwave"
new Beam_Laser;
new Beam_Glow;
new Beam_Halo;
new bool:RS_ActiveThisRound;
new bool:RS_CanUse[MAX_PLAYERS_ARRAY];
new Float:RS_RemoveGodModeAt[MAX_PLAYERS_ARRAY];
new Float:RS_RemoveIgniteAt[MAX_PLAYERS_ARRAY];
new Float:RS_BeginShockwaveAt[MAX_PLAYERS_ARRAY];
new Float:RS_AnimateShockwaveAt[MAX_PLAYERS_ARRAY];
new bool:RS_BlockingAllInput = false;
new Float:RS_BlockingAllInputUntil;
new Float:RS_PlayerCount = 1.0;
new RS_AnimTickCount[MAX_PLAYERS_ARRAY];
new RS_EffectColor[MAX_PLAYERS_ARRAY];
new RS_FrameTotal[MAX_PLAYERS_ARRAY];
new Float:RS_Medigun[MAX_PLAYERS_ARRAY];
new Float:RS_Rage[MAX_PLAYERS_ARRAY];
new Float:RS_Cloak[MAX_PLAYERS_ARRAY];
new Float:RS_Hype[MAX_PLAYERS_ARRAY];
new Float:RS_Charge[MAX_PLAYERS_ARRAY];

// sentry hijack
#define SH_STRING "dot_sentry_hijack"
new bool:SH_ActiveThisRound = false;
new bool:SH_CanUse[MAX_PLAYERS_ARRAY]; // internal
new bool:SH_IsHijacking[MAX_PLAYERS_ARRAY]; // internal
new bool:SH_WeaponSwapped[MAX_PLAYERS_ARRAY]; // internal
new SH_SentryOriginalOwner[MAX_PLAYERS_ARRAY]; // internal. is NOT a user Id since it doesn't work properly with bots.
new SH_OriginalSentryEntityRef[MAX_PLAYERS_ARRAY]; // internal
new SH_HaleSentryEntityRef[MAX_PLAYERS_ARRAY]; // internal
new bool:SH_BuildBlocked[MAX_PLAYERS_ARRAY]; // internal
new Float:SH_HaleSentryHPBoostFactor[MAX_PLAYERS_ARRAY]; // arg1
new Float:SH_RestoredSentryInvulnDuration[MAX_PLAYERS_ARRAY]; // arg2
new String:SH_FailSound[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg3
new String:SH_ExitTooEarlySound[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg4
new bool:SH_SapperResist[MAX_PLAYERS_ARRAY]; // arg5
// arg6 - arg18 are loaded at rage time

// character scramble
#define CS_STRING "rage_character_scramble"
new bool:CS_ActiveThisRound;
new bool:CS_CanUse[MAX_PLAYERS_ARRAY];
new Float:CS_ExecuteRageAt[MAX_PLAYERS_ARRAY];

// meter scramble
#define MS_STRING "rage_meter_scramble"
new bool:MS_ActiveThisRound;
new bool:MS_CanUse[MAX_PLAYERS_ARRAY];
new Float:MS_ExecuteRageAt[MAX_PLAYERS_ARRAY];

// sentry delevel
#define SD_STRING "rage_sentry_delevel"
new bool:SD_ActiveThisRound;
new bool:SD_CanUse[MAX_PLAYERS_ARRAY];
new Float:SD_ExecuteRageAt[MAX_PLAYERS_ARRAY];

// TARDIS
#define TARDIS_STRING "rage_tardis"
#define MAX_TARDIS_SPAWN_ATTEMPTS 20
#define TARDIS_FADE_IN_TIME 3.0
#define TARDIS_FADE_OUT_TIME 3.0
new bool:TARDIS_ActiveThisRound = false;
new bool:TARDIS_CanUse[MAX_PLAYERS_ARRAY];
new Float:TARDIS_FreezeAt[MAX_PLAYERS_ARRAY];
new bool:TARDIS_OnMap[MAX_PLAYERS_ARRAY];
new bool:TARDIS_Used[MAX_PLAYERS_ARRAY]; // a used TARDIS still needs to animate out
new TARDIS_EntityRef[MAX_PLAYERS_ARRAY];
new Float:TARDIS_MinMax[MAX_PLAYERS_ARRAY][2][3];
new Float:TARDIS_NextBeaconTime[MAX_PLAYERS_ARRAY];
new Float:TARDIS_FadeInTime[MAX_PLAYERS_ARRAY];
new Float:TARDIS_FadeOutTime[MAX_PLAYERS_ARRAY];
new BEACON_BEAM;
new BEACON_HALO;

// flaming debris
#define FD_STRING "rage_flaming_debris"
new bool:FD_ActiveThisRound;
new bool:FD_CanUse[MAX_PLAYERS_ARRAY];
new Float:FD_ExecuteRageAt[MAX_PLAYERS_ARRAY];

// war3 teleport ported as a DOT rage
#define DT_STRING "dot_teleport"
new bool:DT_CanUse[MAX_PLAYERS_ARRAY]; // internal
new Float:DT_MaxDistance[MAX_PLAYERS_ARRAY]; // arg1
new String:DT_FailSound[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg2
new String:DT_OldLocationParticleEffect[MAX_PLAYERS_ARRAY][MAX_EFFECT_NAME_LENGTH]; // arg3
new String:DT_NewLocationParticleEffect[MAX_PLAYERS_ARRAY][MAX_EFFECT_NAME_LENGTH]; // arg4
new String:DT_UseSound[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg5

/**
 * METHODS REQUIRED BY ff2 subplugin
 */
public OnPluginStart2()
{
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	// NOTE: For DOTs, only basic inits go here. The real init happens on a time delay shortly after.
	// It is recommended you don't load anything related to DOTs until then.
	RoundInProgress = true;
	PluginActiveThisRound = false;
	
	TARDIS_ActiveThisRound = false;
	RS_ActiveThisRound = false;
	SH_ActiveThisRound = false;
	CS_ActiveThisRound = false;
	MS_ActiveThisRound = false;
	SD_ActiveThisRound = false;
	FD_ActiveThisRound = false;
	RS_BlockingAllInput = false;
	
	new playerCount = 0;
	
	// initialize arrays
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (IsLivingPlayer(clientIdx) && !IsValidBoss(clientIdx))
			playerCount++;

		// sentry hijack
		SH_CanUse[clientIdx] = false;
		SH_IsHijacking[clientIdx] = false;
		SH_WeaponSwapped[clientIdx] = false;
		SH_OriginalSentryEntityRef[clientIdx] = -1;
		SH_HaleSentryEntityRef[clientIdx] = -1;
		SH_BuildBlocked[clientIdx] = false;
		
		// character scramble
		CS_CanUse[clientIdx] = false;
		
		// meter scramble
		MS_CanUse[clientIdx] = false;
		
		// sentry delevel
		SD_CanUse[clientIdx] = false;
		
		// flaming debris
		FD_CanUse[clientIdx] = false;
		
		// tardis
		TARDIS_OnMap[clientIdx] = false;
		TARDIS_CanUse[clientIdx] = false;
		TARDIS_EntityRef[clientIdx] = INVALID_ENTREF;
		
		// regeneration shockwave
		RS_CanUse[clientIdx] = false;
		
		if (!IsValidBoss(clientIdx))
			continue;
	
		new bossIdx = FF2_GetBossIndex(clientIdx);
		if (bossIdx < 0)
			continue;
			
		// precache sounds for regeneration shockwave if applicable
		if ((RS_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, RS_STRING)) == true)
		{
			RS_ActiveThisRound = true;
			PluginActiveThisRound = true;
			RS_RemoveGodModeAt[clientIdx] = FAR_FUTURE;
			RS_RemoveIgniteAt[clientIdx] = FAR_FUTURE;
			RS_BeginShockwaveAt[clientIdx] = FAR_FUTURE;
			RS_AnimateShockwaveAt[clientIdx] = FAR_FUTURE;
		
			new String:str[MAX_SOUND_FILE_LENGTH];
			ReadSound(bossIdx, RS_STRING, 2, str);
			ReadSound(bossIdx, RS_STRING, 3, str);
			ReadSound(bossIdx, RS_STRING, 15, str);
				
			// may as well also store this info
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RS_STRING, 5, str, MAX_SOUND_FILE_LENGTH);
			if (strlen(str) == 6)
				RS_EffectColor[clientIdx] = ParseColor(str);
			else
			{
				PrintToServer("[sarysamods3] Bad color provided for regeneration shockwave. Setting it to off-white.");
				RS_EffectColor[clientIdx] = 0xe0e0e0;
			}
			RS_FrameTotal[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, RS_STRING, 6);
			
			// list of all these are here: http://www.pamelabowman.org/tf2/effectsprites.txt
			Beam_Laser = PrecacheModel("materials/sprites/laser.vmt");
			Beam_Glow = PrecacheModel("sprites/glow02.vmt", true);
			Beam_Halo = PrecacheModel("materials/sprites/halo01.vmt");
		}

		if ((CS_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, CS_STRING)) == true)
		{
			CS_ActiveThisRound = true;
			PluginActiveThisRound = true;
			CS_ExecuteRageAt[clientIdx] = FAR_FUTURE;
		}
		
		if ((MS_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, MS_STRING)) == true)
		{
			MS_ActiveThisRound = true;
			PluginActiveThisRound = true;
			MS_ExecuteRageAt[clientIdx] = FAR_FUTURE;
		}
		
		if ((SD_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, SD_STRING)) == true)
		{
			SD_ActiveThisRound = true;
			PluginActiveThisRound = true;
			SD_ExecuteRageAt[clientIdx] = FAR_FUTURE;
		}
		
		// precache gib model for flaming debris
		if ((FD_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, FD_STRING)) == true)
		{
			FD_ActiveThisRound = true;
			PluginActiveThisRound = true;
			FD_ExecuteRageAt[clientIdx] = FAR_FUTURE;
			ReadModelToInt(bossIdx, FD_STRING, 2); // precache
		}
		
		// precache sounds and model for tardis
		if ((TARDIS_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, TARDIS_STRING)) == true)
		{
			TARDIS_ActiveThisRound = true;
			PluginActiveThisRound = true;
			TARDIS_FreezeAt[clientIdx] = FAR_FUTURE;
		
			ReadModelToInt(bossIdx, TARDIS_STRING, 1);
		
			new String:str[MAX_SOUND_FILE_LENGTH];
			ReadSound(bossIdx, TARDIS_STRING, 3, str);
			ReadSound(bossIdx, TARDIS_STRING, 4, str);
				
			TARDIS_NextBeaconTime[clientIdx] = 0.0;
				
			// precache beacon stuff
			PrecacheSound(SOUND_BLIP);
			BEACON_BEAM = PrecacheModel("materials/sprites/laser.vmt");
			BEACON_HALO = PrecacheModel("materials/sprites/halo01.vmt");
		}
	}
	
	RS_PlayerCount = float(playerCount);
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	// round has ended, this'll kill the looping timer
	RoundInProgress = false;
	
	// end of round cleanup
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		// sentry hijack
		SH_CanUse[clientIdx] = false;
		SH_IsHijacking[clientIdx] = false;
		SH_WeaponSwapped[clientIdx] = false;
		SH_OriginalSentryEntityRef[clientIdx] = -1;
		SH_HaleSentryEntityRef[clientIdx] = -1;
		SH_BuildBlocked[clientIdx] = false;
		
		// remove any TARDISes that may exist
		if (TARDIS_OnMap[clientIdx])
		{
			new tardis = EntRefToEntIndex(TARDIS_EntityRef[clientIdx]);
			if (tardis != -1)
				AcceptEntityInput(tardis, "kill");
			TARDIS_OnMap[clientIdx] = false;
			TARDIS_EntityRef[clientIdx] = INVALID_ENTREF;
		}
		
		// regeneration shockwave
		if (RS_ActiveThisRound && RS_CanUse[clientIdx] && IsLivingPlayer(clientIdx))
		{
			// cancel any pre-rage momentum or stored knockback from being frozen
			TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
			SetEntityMoveType(clientIdx, MOVETYPE_WALK);
			if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed))
				TF2_RemoveCondition(clientIdx, TFCond_Dazed);
			
			// allow damage
			SetEntProp(clientIdx, Prop_Data, "m_takedamage", 2);
			TF2_RemoveCondition(clientIdx, TFCond_Ubercharged);
			TF2_RemoveCondition(clientIdx, TFCond_MegaHeal);
		}
	}

	if (SH_ActiveThisRound)
	{
		RemoveCommandListener(BlockPDA, "build");
		RemoveCommandListener(BlockPDA, "destroy");
	}
	SH_ActiveThisRound = false;
	RS_BlockingAllInput = false;
}

/**
 * METHODS REQUIRED BY dot subplugin
 */
DOTPostRoundStartInit()
{
	if (!RoundInProgress)
	{
		PrintToServer("DOTPostRoundStartInit() called when the round is over?! Shouldn't be possible!");
		return;
	}
	
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!IsValidBoss(clientIdx))
			continue;
	
		new bossIdx = FF2_GetBossIndex(clientIdx);
		if (bossIdx < 0)
			continue; // this may seem weird, but rages often break on duo bosses if the leader suicides. these DOTs can be an exception. :D
			
		// sentry hijack
		SH_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, SH_STRING);
		if (SH_CanUse[clientIdx])
		{
			PluginActiveThisRound = true;
			if (PRINT_DEBUG_INFO)
				PrintToServer("[sarysamods3] User %d has DOT ability for sentry hijack.", clientIdx);
			SH_HaleSentryHPBoostFactor[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SH_STRING, 1);
			SH_RestoredSentryInvulnDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SH_STRING, 2);
			ReadSound(bossIdx, SH_STRING, 3, SH_FailSound[clientIdx]);
			ReadSound(bossIdx, SH_STRING, 4, SH_ExitTooEarlySound[clientIdx]);
			SH_SapperResist[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, SH_STRING, 5) == 1;
			SH_ActiveThisRound = true;
			
			// for consistency
			SH_RestoreMeleeWeapon(clientIdx);
			
			if (PRINT_DEBUG_INFO)
				PrintToServer("[sarysamods3] Sentry hijack usable by %d this round. hpBoost=%f  invuln=%f", clientIdx, SH_HaleSentryHPBoostFactor[clientIdx], SH_RestoredSentryInvulnDuration[clientIdx]);
		}
		
		// teleport
		DT_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, DT_STRING);
		if (DT_CanUse[clientIdx])
		{
			PluginActiveThisRound = true;
			DT_MaxDistance[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DT_STRING, 1);
			ReadSound(bossIdx, DT_STRING, 2, DT_FailSound[clientIdx]);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DT_STRING, 3, DT_OldLocationParticleEffect[clientIdx], MAX_EFFECT_NAME_LENGTH);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, DT_STRING, 4, DT_NewLocationParticleEffect[clientIdx], MAX_EFFECT_NAME_LENGTH);
			ReadSound(bossIdx, DT_STRING, 5, DT_UseSound[clientIdx]);
		}
	}
	
	if (SH_ActiveThisRound)
	{
		AddCommandListener(BlockPDA, "build");
		AddCommandListener(BlockPDA, "destroy");
		PrecacheSound(NOPE_AVI);
	}
}

new SH_TraceSentryEntity = -1;
public bool:SH_TraceSentry(entity, contentsMask)
{
	if (SH_TraceSentryEntity == -1 && IsValidEntity(entity))
	{
		new String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
		GetEntityClassname(entity, classname, MAX_ENTITY_CLASSNAME_LENGTH);
		if (!strcmp(classname, "obj_sentrygun"))
		{
			SH_TraceSentryEntity = entity;
			return true;
		}
	}

	return !entity;
}
 
OnDOTAbilityActivated(clientIdx)
{
	if (!PluginActiveThisRound)
		return;

	if (SH_CanUse[clientIdx])
	{
		// is the user looking at a sentry? won't allow players to body block either.
		SH_TraceSentryEntity = -1;
		new Float:bossOrigin[3];
		new Float:bossEyeAngles[3];
		//GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
		GetClientEyePosition(clientIdx, bossOrigin);
		GetClientEyeAngles(clientIdx, bossEyeAngles);
		new Handle:trace = TR_TraceRayFilterEx(bossOrigin, bossEyeAngles, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, SH_TraceSentry);
		CloseHandle(trace); // results not important

		// I normally don't like to bury important method calls in statements like this. Oh well.
		if (SH_TraceSentryEntity == -1 || !HijackSentry(clientIdx, SH_TraceSentryEntity)) // fail!
		{
			if (strlen(SH_FailSound[clientIdx]) > 3)
				EmitSoundToClient(clientIdx, SH_FailSound[clientIdx]);

			PrintCenterText(clientIdx, "No functioning sentry there!");
			CancelDOTAbilityActivation(clientIdx);
			return;
		}

		// switch the user to a Wrangler
		new String:weaponName[32] = "tf_weapon_laser_pointer";
		new String:attributes[MAX_WEAPON_ARG_LENGTH];
		FF2_GetAbilityArgumentString(FF2_GetBossIndex(clientIdx), this_plugin_name, SH_STRING, 10, attributes, MAX_WEAPON_ARG_LENGTH);
		SwitchWeapon(clientIdx, weaponName, 140, attributes, 0);
		SH_WeaponSwapped[clientIdx] = true;
	}
	
	if (DT_CanUse[clientIdx])
	{
		if (!DOTTeleport(clientIdx))
		{
			if (strlen(DT_FailSound[clientIdx]) > 3)
				EmitSoundToClient(clientIdx, DT_FailSound[clientIdx]);
			CancelDOTAbilityActivation(clientIdx);
			return;
		}
	}
}

OnDOTAbilityDeactivated(clientIdx)
{
	if (!PluginActiveThisRound)
		return;

	if (SH_CanUse[clientIdx])
	{
		if (SH_IsHijacking[clientIdx])
			RestoreSentry(clientIdx);
		SH_IsHijacking[clientIdx] = false;
		
		// restore the user's weapon
		if (SH_WeaponSwapped[clientIdx])
		{
			SH_RestoreMeleeWeapon(clientIdx);
			SH_WeaponSwapped[clientIdx] = false;
		}
	}
}

OnDOTUserDeath(clientIdx, isInGame)
{
	if (!PluginActiveThisRound)
		return;

	if (SH_CanUse[clientIdx])
	{
		if (SH_IsHijacking[clientIdx])
			RestoreSentry(clientIdx);
		SH_IsHijacking[clientIdx] = false;
	}
	
	// suppress
	if (isInGame) { }
}

Action:OnDOTAbilityTick(clientIdx, tickCount)
{
	if (!PluginActiveThisRound)
		return;

	// sentry hijack: if the sentry is dead, force the DOT rage to deactivate.
	if (SH_CanUse[clientIdx])
	{
		new sentryEntity = EntRefToEntIndex(SH_HaleSentryEntityRef[clientIdx]);
		if (!IsValidEntity(sentryEntity))
			ForceDOTAbilityDeactivation(clientIdx);
	}
	
	if (DT_CanUse[clientIdx])
	{
		// since DOT teleport is just a one-time action, deactivate it.
		ForceDOTAbilityDeactivation(clientIdx);
	}
	
	// suppress
	if (tickCount) { }
}

/**
 * METHODS USED BY NORMAL RAGES
 */
public Action:FF2_OnAbility2(bossIdx, const String:plugin_name[], const String:ability_name[], status)
{
	if (strcmp(plugin_name, this_plugin_name) != 0)
		return Plugin_Continue;
	else if (!RoundInProgress) // don't execute these rages with 0 players alive
		return Plugin_Continue;

	if (!strcmp(ability_name, RS_STRING))
		Rage_RegenerationShockwave(ability_name, bossIdx);
	else if (!strcmp(ability_name, CS_STRING))
		Rage_CharacterScramble(ability_name, bossIdx);
	else if (!strcmp(ability_name, MS_STRING))
		Rage_MeterScramble(ability_name, bossIdx);
	else if (!strcmp(ability_name, SD_STRING))
		Rage_SentryDelevel(ability_name, bossIdx);
	else if (!strcmp(ability_name, FD_STRING))
		Rage_FlamingDebris(ability_name, bossIdx);
	else if (!strcmp(ability_name, TARDIS_STRING))
		Rage_Tardis(ability_name, bossIdx);

	return Plugin_Continue;
}

/**
 * Regeneration Shockwave
 */
public bool:TraceWallsOnly(entity, contentsMask)
{
	return false;
}

new IgniteNextNGibs = 0;
new Float:IgniteGibsDuration = 0.0;

#define BEAM_TOP 0
#define BEAM_LEFT 1
#define BEAM_RIGHT 2
#define BEAM_COUNT 3
new Float:ARS_BossOrigins[MAX_PLAYERS_ARRAY][3];
new Float:ARS_BeamTargetPoints[MAX_PLAYERS_ARRAY][BEAM_COUNT][3];
new Float:ARS_StoredEyeAngles[MAX_PLAYERS_ARRAY][3];
#define ARM_BEAM_LENGTH 700.0
#define TOP_BEAM_LENGTH 1250.0
#define BEAM_WIDTH_MODIFIER 1.28
#define BEAM_FREQUENCY 0.18
public AnimateRegenerationShockwave(clientIdx)
{
	// get animation percentage, luckily it's a pretty simple job, except for the halo
	new Float:animationPercentage = ((RS_AnimTickCount[clientIdx] + 0.5) * 100.0) / RS_FrameTotal[clientIdx];
	
	// store the boss origin vector and beam points (for consistency) if this is frame 0
	if (RS_AnimTickCount[clientIdx] == 0)
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
		new Handle:trace = TR_TraceRayFilterEx(ARS_BossOrigins[clientIdx], ARS_StoredEyeAngles[clientIdx], (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
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
	new r = GetR(RS_EffectColor[clientIdx]);
	new g = GetG(RS_EffectColor[clientIdx]);
	new b = GetB(RS_EffectColor[clientIdx]);
	decl colorLayer4[4]; SetColorRGBA(colorLayer4, r, g, b, 255);
	decl colorLayer3[4]; SetColorRGBA(colorLayer3,  (((colorLayer4[0] * 7) + (255 * 1)) / 8),
							(((colorLayer4[1] * 7) + (255 * 1)) / 8),
							(((colorLayer4[2] * 7) + (255 * 1)) / 8),
							255);
	decl colorLayer2[4]; SetColorRGBA(colorLayer2,  (((colorLayer4[0] * 6) + (255 * 2)) / 8),
							(((colorLayer4[1] * 6) + (255 * 2)) / 8),
							(((colorLayer4[2] * 6) + (255 * 2)) / 8),
							255);
	decl colorLayer1[4]; SetColorRGBA(colorLayer1,  (((colorLayer4[0] * 5) + (255 * 3)) / 8),
							(((colorLayer4[1] * 5) + (255 * 3)) / 8),
							(((colorLayer4[2] * 5) + (255 * 3)) / 8),
							255);
	decl glowColor[4]; SetColorRGBA(glowColor, r, g, b, 255);
							
	// get the frame-specific target points for the beams
	new Float:beamStarts[BEAM_COUNT][3];
	new Float:beamEnds[BEAM_COUNT][3];
	for (new i = 0; i < BEAM_COUNT; i++)
	{
		CopyVector(beamStarts[i], ARS_BossOrigins[clientIdx]);
		CopyVector(beamEnds[i], ARS_BeamTargetPoints[clientIdx][i]);
	}
	if (animationPercentage < 10.0)
	{
		for (new i = 0; i < BEAM_COUNT; i++)
			constrainDistance(beamStarts[i], beamEnds[i], 10.0, animationPercentage);
	}
	else if (animationPercentage > 90.0)
	{
		for (new i = 0; i < BEAM_COUNT; i++)
			constrainDistance(beamEnds[i], beamStarts[i], 10.0, 100.0 - animationPercentage);
	}
	
	// draw all the beams
	new diameter = 100;
	for (new i = 0; i < BEAM_COUNT; i++)
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
	new Float:duration = RS_FrameTotal[clientIdx] / 10.0;
	if (RS_AnimTickCount[clientIdx] == 0)
	{
		decl haloColor1[4]; SetColorRGBA(haloColor1, r, g, b, 255);
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
	RS_AnimTickCount[clientIdx]++;
	if (RS_AnimTickCount[clientIdx] == RS_FrameTotal[clientIdx])
	{
		new bossIdx = FF2_GetBossIndex(clientIdx);
		
		// cancel any pre-rage momentum or stored knockback from being frozen
		new Float:ZeroVec[3];
		TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, ZeroVec);

		// allow movement and remove invincibility
		SetEntityMoveType(clientIdx, MOVETYPE_WALK);
		new Float:godModeDuration = (bossIdx < 0) ? 0.0 : FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RS_STRING, 16);
		if (godModeDuration <= 0.0)
		{
			SetEntProp(clientIdx, Prop_Data, "m_takedamage", 2);
			TF2_RemoveCondition(clientIdx, TFCond_Ubercharged);
			TF2_RemoveCondition(clientIdx, TFCond_MegaHeal);
		}
		else
			RS_RemoveGodModeAt[clientIdx] = GetEngineTime() + godModeDuration;
			
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed))
			TF2_RemoveCondition(clientIdx, TFCond_Dazed);
		
		// allow DOTs
		SetDOTUsability(clientIdx, true);
		
		// restore all sentries
		new sentryEntity = -1;
		while ((sentryEntity = FindEntityByClassname(sentryEntity, "obj_sentrygun")) != -1)
			SetEntProp(sentryEntity, Prop_Send, "m_bDisabled", 0);
			
		// play the mapwide sound
		new String:soundFile[MAX_SOUND_FILE_LENGTH];
		if (bossIdx >= 0)
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RS_STRING, 15, soundFile, MAX_SOUND_FILE_LENGTH);
		if (strlen(soundFile) > 3)
			EmitSoundToAll(soundFile);

		RS_AnimateShockwaveAt[clientIdx] = FAR_FUTURE;
	}
}
 
public DoRegenerationShockwave(bossIdx)
{
	new clientIdx = GetBossClientId(bossIdx);
	RS_AnimTickCount[clientIdx] = 0;
	
	// get all the info we need for knockback and damage
	new Float:earthquakeDuration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RS_STRING, 4);
	new Float:damageRadius = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RS_STRING, 7);
	new Float:knockbackRadius = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RS_STRING, 8);
	new String:damagePointBlankStr[29];
	new String:damagePointBlankStrSplit[2][15];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RS_STRING, 9, damagePointBlankStr, 29);
	ExplodeString(damagePointBlankStr, ",", damagePointBlankStrSplit, 2, 15);
	new Float:damageMin = StringToFloat(damagePointBlankStrSplit[0]);
	new Float:damageMax = StringToFloat(damagePointBlankStrSplit[1]);
	new Float:damagePointBlank = damageMin + ((damageMax - damageMin) * RS_PlayerCount / 31.0);
	new Float:igniteDuration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RS_STRING, 10);
	new Float:knockbackIntensityPointBlank = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RS_STRING, 11);
	new Float:knockbackIntensityMidpoint = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RS_STRING, 12);
	new Float:knockbackIntensityFarpoint = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RS_STRING, 13);
	new Float:minimumZLift = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RS_STRING, 14);
	
	// knock back players first, and then damage them
	new Float:bossOrigin[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
	new Float:mercOrigin[3];
	new Float:currentVelocity[3];
	new Float:knockbackVelocity[3];
	new Float:distance;
	new Float:intensity;
	new Float:diffIntensity;
	new Float:distanceRatio;
	new Float:damage;
	for (new victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (IsLivingPlayer(victim) && GetClientTeam(victim) != BossTeam)
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
					RS_RemoveIgniteAt[clientIdx] = GetEngineTime() + igniteDuration; // not an error, remove them all at once so use boss idx
				}
				
				SDKHooks_TakeDamage(victim, clientIdx, clientIdx, damage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
			}
		}
	}
	
	// play the mapwide sound
	new String:soundFile[MAX_SOUND_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RS_STRING, 3, soundFile, MAX_SOUND_FILE_LENGTH);
	if (strlen(soundFile) > 3)
		EmitSoundToAll(soundFile);
	
	// shake shake shake, da-da-dah-da-dah-dah, shake shake shake, da-da-dah-da-dah-dah, shake your booteh...
	env_shake(bossOrigin, 120.0, knockbackRadius, earthquakeDuration, 250.0);
	
	// start the looping timer for this shockwave
	RS_AnimateShockwaveAt[clientIdx] = GetEngineTime();
}

public RegenerationShockwave(clientIdx)
{
	// allow everyone but the hale to move again
	RS_BlockingAllInput = false;
	for (new victim = 1; victim < MAX_PLAYERS; victim++)
	{
		if (victim != clientIdx && IsLivingPlayer(victim))
			SetEntityMoveType(victim, MOVETYPE_WALK);
	}
		
	new bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;

	DoRegenerationShockwave(bossIdx);
}

public RS_Tick(clientIdx, Float:curTime)
{
	if (curTime >= RS_RemoveGodModeAt[clientIdx])
	{
		RS_RemoveGodModeAt[clientIdx] = FAR_FUTURE;
		
		SetEntProp(clientIdx, Prop_Data, "m_takedamage", 2);
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_MegaHeal))
			TF2_RemoveCondition(clientIdx, TFCond_MegaHeal);
		if (TF2_IsPlayerInCondition(clientIdx, TFCond_Ubercharged))
			TF2_RemoveCondition(clientIdx, TFCond_Ubercharged);
	}
	
	if (curTime >= RS_RemoveIgniteAt[clientIdx])
	{
		RS_RemoveIgniteAt[clientIdx] = FAR_FUTURE;
		for (new victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (!IsLivingPlayer(victim) || GetClientTeam(victim) == BossTeam)
				continue;
		
			if (TF2_IsPlayerInCondition(victim, TFCond_OnFire))
				TF2_RemoveCondition(victim, TFCond_OnFire);
		}
	}
	
	if (curTime >= RS_BeginShockwaveAt[clientIdx])
	{
		RS_BeginShockwaveAt[clientIdx] = FAR_FUTURE;
		RegenerationShockwave(clientIdx);
	}
	
	if (curTime >= RS_AnimateShockwaveAt[clientIdx])
	{
		RS_AnimateShockwaveAt[clientIdx] += 0.1;
		AnimateRegenerationShockwave(clientIdx);
	}
}
 
public Rage_RegenerationShockwave(const String:ability_name[], bossIdx)
{
	new Float:delay = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RS_STRING, 1);
	new clientIdx = GetBossClientId(bossIdx);
	
	if (RS_FrameTotal[clientIdx] <= 1)
	{
		PrintToServer("ERROR: Need a valid frame count to animate Regeneration Shockwave. Rage will not execute.");
		return;
	}

	// deactivate DOTs, since the player is incapacitated for a bit
	ForceDOTAbilityDeactivation(clientIdx);
	SetDOTUsability(clientIdx, false);
	
	// play the mapwide sound
	new String:soundFile[MAX_SOUND_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, RS_STRING, 2, soundFile, MAX_SOUND_FILE_LENGTH);
	if (strlen(soundFile) > 3)
		EmitSoundToAll(soundFile);
	
	// stun all sentries
	new sentryEntity = -1;
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
		for (new victim = 1; victim < MAX_PLAYERS; victim++)
		{
			if (victim != clientIdx && IsLivingPlayer(victim))
			{
				SetEntityMoveType(victim, MOVETYPE_NONE);
				
				// medic is the only one that needs to be explicitly checked
				if (TF2_GetPlayerClass(victim) == TFClass_Medic)
				{
					new weapon = GetPlayerWeaponSlot(victim, TFWeaponSlot_Secondary);
					if (IsValidEntity(weapon))
					{
						new String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
						GetEntityClassname(weapon, classname, sizeof(classname));
						if (!strcmp(classname, "tf_weapon_medigun"))
							RS_Medigun[victim] = GetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel");
					}
				}
				
				// the rest of these, all players have
				RS_Rage[victim] = GetEntPropFloat(victim, Prop_Send, "m_flRageMeter");
				RS_Cloak[victim] = GetEntPropFloat(victim, Prop_Send, "m_flCloakMeter");
				RS_Hype[victim] = GetEntPropFloat(victim, Prop_Send, "m_flHypeMeter");
				RS_Charge[victim] = GetEntPropFloat(victim, Prop_Send, "m_flChargeMeter");
			}
		}

		// block input
		RS_BlockingAllInputUntil = GetEngineTime() + delay + delay; // this is only a sanity timer, intentionally set beyond freeze duration. it'll truly end well before that, when the timer executes.
		RS_BlockingAllInput = true;
		RS_BeginShockwaveAt[clientIdx] = GetEngineTime() + delay;
	}
	else
		DoRegenerationShockwave(bossIdx);
}

/**
 * Character Scramble
 */
public DoCharacterScramble(const String:particleName[], bool:cancelVelocity)
{
	if (!RoundInProgress)
		return;
		
	if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods3] Scrambling the locations, angles, and velocities of all living mercenaries!");
		
	// a lot of information that needs to be stored
	new bool:used[MAX_PLAYERS_ARRAY];
	new shuffle[MAX_PLAYERS_ARRAY];
	new clientIndexes[MAX_PLAYERS_ARRAY];
	new Float:clientOrigins[MAX_PLAYERS_ARRAY][3];
	new Float:clientAngles[MAX_PLAYERS_ARRAY][3];
	new Float:clientVelocities[MAX_PLAYERS_ARRAY][3];
	
	// init used, find all living players and store their positions, angles, and movement!
	for (new pass = 0; pass <= 1; pass++) // need to do ducking players separately from standing players
	{
		new clientIndexCount = 0;
		for (new i = 1; i < MAX_PLAYERS; i++)
		{
			used[i] = false;
			if (IsLivingPlayer(i) && GetClientTeam(i) != BossTeam)
			{
				if (pass == 0 && (GetEntityFlags(i) & FL_DUCKING)) // first pass, filter out ducking players
					continue;
				else if (pass == 1 && (GetEntityFlags(i) & FL_DUCKING) == 0) // second pass, filter out non-ducking players
					continue;
			
				clientIndexes[clientIndexCount] = i;
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", clientOrigins[clientIndexCount]);
				GetEntPropVector(i, Prop_Send, "m_angRotation", clientAngles[clientIndexCount]);
				GetEntPropVector(i, Prop_Data, "m_vecVelocity", clientVelocities[clientIndexCount]);
				if (cancelVelocity)
				{
					clientVelocities[clientIndexCount][0] = 0.0;
					clientVelocities[clientIndexCount][1] = 0.0;
					clientVelocities[clientIndexCount][2] = 0.0;
				}
				clientIndexCount++;
			}
		}
		
		if (clientIndexCount <= 1) // nothing to do
			continue;

		// figure out the scramble order
		new randomIdx = -1;
		for (new i = 0; i < clientIndexCount; i++)
		{
			new sanity = 0;
		
			// this could get very expensive with bad luck and large arrays. luckily, it can never be more than 31...
			do {
				randomIdx = GetRandomInt(0, clientIndexCount - 1);
			} while (used[randomIdx] && ++sanity < 500);
			
			if (sanity >= 500 && PRINT_DEBUG_INFO)
				PrintToServer("[sarysamods3] WARNING: Reached sanity limit on character scramble.");

			shuffle[i] = randomIdx;
			used[randomIdx] = true;
		}

		// scramble! and display a particle effect if applicable.
		for (new i = 0; i < clientIndexCount; i++)
		{
			TeleportEntity(clientIndexes[i], clientOrigins[shuffle[i]], clientAngles[shuffle[i]], clientVelocities[shuffle[i]]);
			
			if (!IsEmptyString(particleName))
			{
				new particle = AttachParticle(clientIndexes[i], particleName, 75.0);
				if (IsValidEntity(particle))
					CreateTimer(1.0, Timer_RemoveEntity, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

public CS_Tick(clientIdx, Float:curTime)
{
	if (curTime >= CS_ExecuteRageAt[clientIdx])
	{
		CS_ExecuteRageAt[clientIdx] = FAR_FUTURE;
		
		new bossIdx = FF2_GetBossIndex(clientIdx);
		if (bossIdx >= 0)
			DoCharacterScramble(NULL_STRING, (FF2_GetAbilityArgument(bossIdx, this_plugin_name, CS_STRING, 2) == 1));
	}
}

public Rage_CharacterScramble(const String:ability_name[], bossIdx)
{
	new Float:delay = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 1);
	new bool:cancelVelocity = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 2) == 1;
	new clientIdx = GetBossClientId(bossIdx);
	
	if (delay == 0.0)
		DoCharacterScramble(NULL_STRING, cancelVelocity);
	else
		CS_ExecuteRageAt[clientIdx] = GetEngineTime() + delay;
}

/**
 * Meter Scramble
 */
#define METER_FLAG_MEDIGUN 0x01
#define METER_FLAG_CLOAK 0x02
#define METER_FLAG_MMMPH 0x04
#define METER_FLAG_RAGE 0x08
#define METER_FLAG_HYPE 0x10
#define METER_FLAG_CHARGE 0x20
public DoMeterScramble(flags)
{
	if (!RoundInProgress)
		return;
	else if (flags == 0)
		return;
		
	if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods3] Scrambling medigun charge and other charge meters.");
		
	for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!IsLivingPlayer(clientIdx))
			continue;
		else if (IsValidBoss(clientIdx))
			continue;
			
		if (TF2_GetPlayerClass(clientIdx) == TFClass_Spy && (flags & METER_FLAG_CLOAK))
			SetEntPropFloat(clientIdx, Prop_Send, "m_flCloakMeter", GetRandomFloat(0.0, 100.0));
		else if (TF2_GetPlayerClass(clientIdx) == TFClass_Medic && (flags & METER_FLAG_MEDIGUN))
		{
			new weapon = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Secondary);
			if (IsValidEntity(weapon))
			{
				new String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
				GetEntityClassname(weapon, classname, sizeof(classname));
				if (!strcmp(classname, "tf_weapon_medigun"))
					SetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel", GetRandomFloat(0.40, 1.00));
			}
		}
		else if (TF2_GetPlayerClass(clientIdx) == TFClass_DemoMan && (flags & METER_FLAG_CHARGE))
			SetEntPropFloat(clientIdx, Prop_Send, "m_flChargeMeter", GetRandomFloat(0.0, 100.0));
		else if (TF2_GetPlayerClass(clientIdx) == TFClass_Scout && (flags & METER_FLAG_HYPE))
			SetEntPropFloat(clientIdx, Prop_Send, "m_flHypeMeter", GetRandomFloat(0.0, 100.0));
		else if ((TF2_GetPlayerClass(clientIdx) == TFClass_Soldier && (flags & METER_FLAG_RAGE)) || (TF2_GetPlayerClass(clientIdx) == TFClass_Pyro && (flags & METER_FLAG_MMMPH)))
			SetEntPropFloat(clientIdx, Prop_Send, "m_flRageMeter", GetRandomFloat(0.0, 100.0));
	}
}

public MS_Tick(clientIdx, Float:curTime)
{
	if (curTime >= MS_ExecuteRageAt[clientIdx])
	{
		MS_ExecuteRageAt[clientIdx] = FAR_FUTURE;
		
		new bossIdx = FF2_GetBossIndex(clientIdx);
		if (bossIdx >= 0)
			DoMeterScramble(FF2_GetAbilityArgument(bossIdx, this_plugin_name, MS_STRING, 2));
	}
}

public Rage_MeterScramble(const String:ability_name[], bossIdx)
{
	new Float:delay = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 1);
	new flags = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 2);
	new clientIdx = GetBossClientId(bossIdx);
	
	if (delay == 0.0)
		DoMeterScramble(flags);
	else
		MS_ExecuteRageAt[clientIdx] = GetEngineTime() + delay;
}

/**
 * Sentry Delevel
 */
#define MAX_SENTRY_MONITOR 10
new SD_MonitoredSentryEntRefs[MAX_SENTRY_MONITOR];
new Float:SD_DamageModifiers[MAX_SENTRY_MONITOR];
public Action:SD_SM_OnTakeDamage(sentryEntity, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	// this method fixes a bug where the deleveled sentry can withstand level 2 or level 3 damage.
	// the bug fixes itself once it's been leveled up again.
	if (!IsValidEntity(sentryEntity))
		return Plugin_Continue;

	for (new i = 0; i < MAX_SENTRY_MONITOR; i++)
	{
		if (SD_MonitoredSentryEntRefs[i] != 0)
		{
			new tmpEntity = EntRefToEntIndex(SD_MonitoredSentryEntRefs[i]);
			if (sentryEntity == tmpEntity)
			{
				new curLevel = GetEntProp(sentryEntity, Prop_Send, "m_iHighestUpgradeLevel") & 0x03;
				if (curLevel == 1)
					damage *= SD_DamageModifiers[i];
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

public HookSentryMonitor(sentryEntity, Float:factor)
{
	new freeSpot = -1;
	new foundEntity = -1;
	for (new i = 0; i < MAX_SENTRY_MONITOR; i++)
	{
		if (SD_MonitoredSentryEntRefs[i] != 0)
		{
			new tmpEntity = EntRefToEntIndex(SD_MonitoredSentryEntRefs[i]);
			if (!IsValidEntity(tmpEntity))
				SD_MonitoredSentryEntRefs[i] = 0;
			else if (sentryEntity == tmpEntity)
			{
				foundEntity = i;
				break;
			}
		}
	
		if (SD_MonitoredSentryEntRefs[i] == 0 && freeSpot == -1)
			freeSpot = i;
	}
	
	if (foundEntity != -1)
	{
		// already exists, so just modify the damage factor
		//SD_DamageModifiers[foundEntity] *= factor;
		SD_DamageModifiers[foundEntity] = factor; // or not...
	}
	else if (freeSpot != -1)
	{
		// a new entry
		SD_MonitoredSentryEntRefs[freeSpot] = EntIndexToEntRef(sentryEntity);
		SD_DamageModifiers[freeSpot] = factor;
		SDKHook(sentryEntity, SDKHook_OnTakeDamage, SD_SM_OnTakeDamage);
	}
	else
		PrintToServer("[sarysamods3] Error: Somehow ran out of sentry monitor space. Sentry will have buggy boosted HP with no damage modifier.");
}

public DoSentryDelevel(String:particleName[])
{
	if (!RoundInProgress)
		return;
		
	if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods3] Deleveling all sentries to level 1.");
		
	new sentryEntity = -1;
	while ((sentryEntity = FindEntityByClassname(sentryEntity, "obj_sentrygun")) != -1)
	{
		new oldSentryLevel = GetEntProp(sentryEntity, Prop_Send, "m_iUpgradeLevel") & 0x03;
		new sentryTeam = GetEntProp(sentryEntity, Prop_Send, "m_iTeamNum") & 0x03;
		new Float:sentryCenter[3];
		GetEntPropVector(sentryEntity, Prop_Send, "m_vecOrigin", sentryCenter);
		sentryCenter[2] += 40;
		if (oldSentryLevel > 1 && sentryTeam != BossTeam)
		{
			// fix health. if this is not done, the sentry's health will get higher every delevel
			new oldHealth = GetEntProp(sentryEntity, Prop_Send, "m_iHealth");
			if (oldHealth > 150)
				SetEntProp(sentryEntity, Prop_Send, "m_iHealth", 150);
			SetEntProp(sentryEntity, Prop_Send, "m_iMaxHealth", 150);
		
			// tweak level and upgrade level
			SetEntProp(sentryEntity, Prop_Send, "m_iHighestUpgradeLevel", 1);
			SetEntProp(sentryEntity, Prop_Send, "m_iUpgradeLevel", 1);
			
			// level 1 sentry model
			SetEntityModel(sentryEntity, "models/buildables/sentry1.mdl");
			
			// remove rockets
			SetEntProp(sentryEntity, Prop_Send, "m_iAmmoRockets", 0);
			
			// find and change max rockets
			new offs = FindSendPropInfo("CObjectSentrygun", "m_iAmmoRockets");
			if (offs > 0)
				SetEntData(sentryEntity, offs - 4, 0, 4, true);

			// clamp shells count
			new oldShells = GetEntProp(sentryEntity, Prop_Send, "m_iAmmoShells");
			if (oldShells > 150)
				SetEntProp(sentryEntity, Prop_Send, "m_iAmmoShells", 150);

			// find and change max shells
			offs = FindSendPropInfo("CObjectSentrygun", "m_iAmmoShells");
			if (offs > 0)
				SetEntData(sentryEntity, offs - 4, 150, 4, true); // max shells
				
			// hoping this'll prevent the sentry firing position from being wrong
			SetEntProp(sentryEntity, Prop_Send, "m_iState", 3);
			
			// testing -- hopefully this will fix the sentry HP/damage reduction? glitch
			// it failed.
			//offs = FindSendPropInfo("CObjectSentrygun", "m_hAutoAimTarget");
			//if (offs > 0)
			//	SetEntData(sentryEntity, offs - 0x20, 0, 4, true);
			
			if (oldSentryLevel == 2)
				HookSentryMonitor(sentryEntity, 1.2);
			else if (oldSentryLevel == 3)
				HookSentryMonitor(sentryEntity, 1.44);
			else
				PrintToServer("[sarysamods3] ERROR: Old deleveled sentry had invalid level?!");
			
			// optional particle effect
			if (!IsEmptyString(particleName))
				ParticleEffectAt(sentryCenter, particleName);
		}
	}
}

public SD_Tick(clientIdx, Float:curTime)
{
	if (curTime >= SD_ExecuteRageAt[clientIdx])
	{
		SD_ExecuteRageAt[clientIdx] = FAR_FUTURE;
		
		new bossIdx = FF2_GetBossIndex(clientIdx);
		if (bossIdx >= 0)
		{
			static String:particleName[MAX_EFFECT_NAME_LENGTH];
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SD_STRING, 2, particleName, MAX_EFFECT_NAME_LENGTH);

			DoSentryDelevel(particleName);
		}
	}
}

public Rage_SentryDelevel(const String:ability_name[], bossIdx)
{
	new Float:delay = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 1);
	new clientIdx = GetBossClientId(bossIdx);
	
	if (delay == 0.0)
	{
		static String:particleName[MAX_EFFECT_NAME_LENGTH];
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SD_STRING, 2, particleName, MAX_EFFECT_NAME_LENGTH);
		DoSentryDelevel(particleName);
	}
	else
		SD_ExecuteRageAt[clientIdx] = GetEngineTime() + delay;
}

/**
 * Flaming Debris
 */
public ShootFlamingGibs(flameCount, const String:modelName[], Float:flameDuration, const Float:origin[3], Float:flameDelay, Float:flameVelocity)
{
	// DEFINE_KEYFIELD is the magic phrase to search for in the tf2 SDK
	// pass it on :P
	new flamingGibShooter = CreateEntityByName("env_shooter");
	new Float:angles[3] = {0.0, 0.0, 0.0};
	new String:gibCountStr[3];
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

	if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods3] Created shooter with %d flames.", flameCount);

	CreateTimer(10.0, Timer_RemoveEntity, EntIndexToEntRef(flamingGibShooter), TIMER_FLAG_NO_MAPCHANGE); // remove a one-off entity with no significance? timer's fine.
}
 
public DoFlamingDebris(bossIdx)
{
	if (!RoundInProgress)
	{
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods3] Flaming debris not executed. Round is over.");
		return;
	}
	else if (!FF2_HasAbility(bossIdx, this_plugin_name, FD_STRING))
	{
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods3] Flaming debris not executed. Current boss %d does not have rage.", bossIdx);
		return;
	}
		
	new clientIdx = GetBossClientId(bossIdx);
	if (!IsValidBoss(clientIdx))
	{
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods3] Flaming debris not executed. Boss client %d is invalid (may be dead)", clientIdx);
		return;
	}

	new String:modelName[MAX_MODEL_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, FD_STRING, 2, modelName, MAX_MODEL_FILE_LENGTH);
	new flameCount = FF2_GetAbilityArgument(bossIdx, this_plugin_name, FD_STRING, 3);
	if (flameCount > 50) // mitigate the risk of running out of entities...not a big issue for between-lives, but could be a problem for standard rage
	{
		PrintToServer("[sarysamods3] Warning (FlamingDebris): Flame count had to clamped to 50. This is due to concerns of running out of server-side entities.");
		flameCount = 50;
	}
	new Float:flameDuration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FD_STRING, 4);
	
	if (strlen(modelName) < 3 || flameCount <= 0 || flameDuration <= 0.0)
	{
		PrintToServer("[sarysamods3] ERROR (FlamingDebris): Either invalid model, or flame count/duration is <= 0.");
		return;
	}
	
	new Float:flameDelay = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FD_STRING, 5);
	new Float:flameVelocity = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, FD_STRING, 6);
	
	new Float:bossOrigin[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
	bossOrigin[2] += 50.0;
	
	// shoot the gibs
	if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods3] Shooting %d flaming gibs (%s) with life of %f seconds, from {%f,%f,%f}", flameCount, modelName, flameDuration, bossOrigin[0], bossOrigin[1], bossOrigin[2]);
	ShootFlamingGibs(flameCount, modelName, flameDuration, bossOrigin, flameDelay, flameVelocity);
}

public FD_Tick(clientIdx, Float:curTime)
{
	if (curTime >= FD_ExecuteRageAt[clientIdx])
	{
		FD_ExecuteRageAt[clientIdx] = FAR_FUTURE;
		
		new bossIdx = FF2_GetBossIndex(clientIdx);
		if (bossIdx >= 0)
			DoFlamingDebris(bossIdx);
	}
}

public Rage_FlamingDebris(const String:ability_name[], bossIdx)
{
	new Float:delay = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 1);
	new clientIdx = GetBossClientId(bossIdx);
	
	if (delay == 0.0)
		DoFlamingDebris(bossIdx);
	else
		FD_ExecuteRageAt[clientIdx] = GetEngineTime() + delay;
}

/**
 * TARDIS
 */
public OnTardisEntered(clientIdx)
{
	if (!RoundInProgress || !IsValidBoss(clientIdx))
		return;
	
	// boss index
	new bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;
	
	// tardis and origin
	new tardis = EntRefToEntIndex(TARDIS_EntityRef[clientIdx]);
	if (!IsValidEntity(tardis))
		return;
	new Float:tardisOrigin[3];
	GetEntPropVector(tardis, Prop_Send, "m_vecOrigin", tardisOrigin);
	
	// bring in the various args
	new String:exitSound[MAX_SOUND_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, TARDIS_STRING, 4, exitSound, MAX_SOUND_FILE_LENGTH);
	new String:particleEffectCharacterScramble[MAX_EFFECT_NAME_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, TARDIS_STRING, 8, particleEffectCharacterScramble, MAX_EFFECT_NAME_LENGTH);
	new String:particleEffectDelevel[MAX_EFFECT_NAME_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, TARDIS_STRING, 9, particleEffectDelevel, MAX_EFFECT_NAME_LENGTH);
	new bool:sentryDelevel = FF2_GetAbilityArgument(bossIdx, this_plugin_name, TARDIS_STRING, 10) == 1;
	new bool:characterScramble = FF2_GetAbilityArgument(bossIdx, this_plugin_name, TARDIS_STRING, 11) == 1;
	new Float:sentryStunDuration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, TARDIS_STRING, 12);
	new bool:cancelVelocity = FF2_GetAbilityArgument(bossIdx, this_plugin_name, TARDIS_STRING, 13) == 1;
	new meterFlags = FF2_GetAbilityArgument(bossIdx, this_plugin_name, TARDIS_STRING, 16);
	
	// play the exit sound
	if (strlen(exitSound) > 3)
	{
		new Float:soundOrigin[3];
		soundOrigin[0] = tardisOrigin[0];
		soundOrigin[1] = tardisOrigin[1];
		soundOrigin[2] = tardisOrigin[2] + 50.0;
	
		// double it so it's louder
		EmitAmbientSound(exitSound, soundOrigin, tardis);
		EmitAmbientSound(exitSound, soundOrigin, tardis);
	}
	
	// execute various rages
	if (sentryDelevel)
		DoSentryDelevel(particleEffectDelevel);
	if (characterScramble)
		DoCharacterScramble(particleEffectCharacterScramble, cancelVelocity);
	if (meterFlags > 0)
		DoMeterScramble(meterFlags);
	if (sentryStunDuration > 0.0)
		DSSG_PerformStun(clientIdx, 99999.0, sentryStunDuration);
	
	// tell everyone what happened
	new String:tardisEnteredMessage[MAX_CENTER_TEXT_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, TARDIS_STRING, 15, tardisEnteredMessage, MAX_CENTER_TEXT_LENGTH);
	if (!IsEmptyString(tardisEnteredMessage))
		for (new victim = 1; victim < MAX_PLAYERS; victim++)
			if (IsLivingPlayer(victim))
				PrintCenterText(victim, tardisEnteredMessage);
}

public TARDIS_Tick(clientIdx, Float:curTime)
{
	if (curTime >= TARDIS_FreezeAt[clientIdx])
	{
		TARDIS_FreezeAt[clientIdx] = FAR_FUTURE;

		new tardis = EntRefToEntIndex(TARDIS_EntityRef[clientIdx]);
		if (IsValidEntity(tardis))
		{
			SetEntityMoveType(tardis, MOVETYPE_NONE);
			SetEntProp(tardis, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_NONE);
			SetEntProp(tardis, Prop_Send, "m_usSolidFlags", 4); // not solid
			SetEntProp(tardis, Prop_Send, "m_nSolidType", 0); // not solid
		}
	}

	// **** THIS MUST ALWAYS BE LAST, AS IT MAKES RETURN CALLS ****
	// legacy code. sigh.
	if (TARDIS_OnMap[clientIdx])
	{
		new tardis = EntRefToEntIndex(TARDIS_EntityRef[clientIdx]);
		if (IsValidEntity(tardis))
		{
			if (!IsValidBoss(clientIdx))
			{
				AcceptEntityInput(tardis, "kill");
				TARDIS_OnMap[clientIdx] = false;
				TARDIS_EntityRef[clientIdx] = INVALID_ENTREF;
				return;
			}
			else if (TARDIS_Used[clientIdx] && TARDIS_FadeOutTime[clientIdx] + TARDIS_FADE_OUT_TIME <= GetEngineTime())
			{
				AcceptEntityInput(tardis, "kill");
				TARDIS_OnMap[clientIdx] = false;
				TARDIS_EntityRef[clientIdx] = INVALID_ENTREF;
				return;
			}

			// animate the TARDIS fade-in and fade-out
			new bool:isFadingOut = TARDIS_Used[clientIdx];
			new bool:isFadingIn = !isFadingOut && (GetEngineTime() < TARDIS_FadeInTime[clientIdx] + TARDIS_FADE_IN_TIME);
			if (isFadingOut || isFadingIn)
			{
				// since fade out animation is a reverse of fade in animation, do the little 1.0 - dealio ;P
				new Float:animationCompletion = isFadingOut ? (1.0 - ((GetEngineTime() - TARDIS_FadeOutTime[clientIdx]) / TARDIS_FADE_OUT_TIME)) :
									      ((GetEngineTime() - TARDIS_FadeInTime[clientIdx]) / TARDIS_FADE_IN_TIME);

				// just gonna do it linear, too lazy to make it like a sine wave
				new alpha = 255;

				if (animationCompletion <= 0.4) // fade in fast, but it won't last
					alpha = RoundFloat(alpha * animationCompletion * 1.75);
				else if (animationCompletion <= 0.7) // fade out a little. real TARDIS does many of these but I'm just doing one.
					alpha = RoundFloat(alpha * (0.7 - (((animationCompletion - 0.4) / 0.3) * 0.25)));
				else
					alpha = RoundFloat(alpha * (0.45 + (((animationCompletion - 0.7) / 0.3) * 0.55)));

				SetEntityRenderMode(tardis, RENDER_TRANSCOLOR);
				SetEntityRenderColor(tardis, 255, 255, 255, alpha);
			}
			else
			{
				//SetEntityRenderMode(tardis, RENDER_NORMAL);
				SetEntityRenderMode(tardis, RENDER_TRANSCOLOR);
				SetEntityRenderColor(tardis, 255, 255, 255, 255);
			}

			// nothing more to do if tardis was used
			if (TARDIS_Used[clientIdx])
				return;

			// need origin
			new Float:tardisOrigin[3];
			GetEntPropVector(tardis, Prop_Send, "m_vecOrigin", tardisOrigin);

			// get bounds for tardis
			new Float:boundsMin[3];
			new Float:boundsMax[3];
			boundsMin[0] = tardisOrigin[0] + TARDIS_MinMax[clientIdx][0][0];
			boundsMin[1] = tardisOrigin[1] + TARDIS_MinMax[clientIdx][0][1];
			boundsMin[2] = tardisOrigin[2] + TARDIS_MinMax[clientIdx][0][2];
			boundsMax[0] = tardisOrigin[0] + TARDIS_MinMax[clientIdx][1][0];
			boundsMax[1] = tardisOrigin[1] + TARDIS_MinMax[clientIdx][1][1];
			boundsMax[2] = tardisOrigin[2] + TARDIS_MinMax[clientIdx][1][2];

			// get origin of player but tweak it a little
			new Float:bossOrigin[3];
			GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
			bossOrigin[2] += 50.0; // closer to center

			if (TARDIS_NextBeaconTime[clientIdx] <= GetEngineTime() && !isFadingIn && !isFadingOut)
			{
				// ripped straight from RTD beacon, since it's the kind everyone's familiar with already
				new Float:beaconPos[3];
				beaconPos[0] = tardisOrigin[0];
				beaconPos[1] = tardisOrigin[1];
				beaconPos[2] = tardisOrigin[2] + 10.0;

				TE_SetupBeamRingPoint(beaconPos, 10.0, 350.0, BEACON_BEAM, BEACON_HALO, 0, 15, 0.5, 5.0, 0.0, {128,128,128,255}, 10, 0);
				TE_SendToAll();
				TE_SetupBeamRingPoint(beaconPos, 10.0, 350.0, BEACON_BEAM, BEACON_HALO, 0, 10, 0.6, 10.0, 0.5, {75,75,255,255}, 10, 0);
				TE_SendToAll();

				EmitSoundToAll(SOUND_BLIP, tardis);
				EmitSoundToAll(SOUND_BLIP, tardis);
				EmitSoundToAll(SOUND_BLIP, tardis);

				TARDIS_NextBeaconTime[clientIdx] = GetEngineTime() + 1.0;
			}

			// do bounds check, trigger rage effects when hale enters
			if (WithinBounds(bossOrigin, boundsMin, boundsMax))
			{
				if (PRINT_DEBUG_INFO)
					PrintToServer("[sarysamods3] Boss %d entered the TARDIS! Rages will execute.", clientIdx);

				TARDIS_Used[clientIdx] = true;
				TARDIS_FadeOutTime[clientIdx] = GetEngineTime();

				OnTardisEntered(clientIdx);
			}
		}
		else
		{
			TARDIS_OnMap[clientIdx] = false;
			TARDIS_EntityRef[clientIdx] = INVALID_ENTREF;
		}
	}
}

public Rage_Tardis(const String:ability_name[], bossIdx)
{
	new clientIdx = GetBossClientId(bossIdx);

	// a couple strings...
	new String:modelName[MAX_MODEL_FILE_LENGTH];
	new String:tardisDimensionsStr[134];
	new String:tardisDimensionsStrSplit[2][66];
	new String:tardisStrIndividual[3][21];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, 1, modelName, MAX_MODEL_FILE_LENGTH);
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, 2, tardisDimensionsStr, 134);
	new Float:maxZDifference = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 14);
	
	// split up and validate the dimensions first of all, necessary for proper spawning and verifying boss is within TARDIS borders
	ExplodeString(tardisDimensionsStr, " ", tardisDimensionsStrSplit, 2, 66);
	for (new i = 0; i < 2; i++)
	{
		ExplodeString(tardisDimensionsStrSplit[i], ",", tardisStrIndividual, 3, 21);
		TARDIS_MinMax[clientIdx][i][0] = StringToFloat(tardisStrIndividual[0]);
		TARDIS_MinMax[clientIdx][i][1] = StringToFloat(tardisStrIndividual[1]);
		TARDIS_MinMax[clientIdx][i][2] = StringToFloat(tardisStrIndividual[2]);
	}
	
	if (TARDIS_MinMax[clientIdx][1][0] <= TARDIS_MinMax[clientIdx][0][0] ||
		TARDIS_MinMax[clientIdx][1][1] <= TARDIS_MinMax[clientIdx][0][1] ||
		TARDIS_MinMax[clientIdx][1][2] <= TARDIS_MinMax[clientIdx][0][2])
	{
		PrintToServer("[sarysamods3] ERROR with %s, dimensions are invalid. Rage will not execute. Must be formatted: minX,minY,minZ maxX,maxY,maxZ", TARDIS_STRING);
		return;
	}
	
	// grab the entry sound, but can't play it yet
	new String:entrySound[MAX_SOUND_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, 3, entrySound, MAX_SOUND_FILE_LENGTH);
	// skip arg4 for now, not used here
	
	// random distance for TARDIS to spawn from rager
	new Float:minDistance = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 5);
	new Float:maxDistance = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 6);
	if (maxDistance < minDistance)
	{
		PrintToServer("[sarysamods3] WARNING distance to spawn tardis from player, min is less than max. Correcting.");
		
		// because I don't know if the 1337 bitwise trick works on floats in SourcePawn :P
		new Float:tmp = minDistance;
		minDistance = maxDistance;
		maxDistance = tmp;
	}
	
	// health for our TARDIS
	new health = FF2_GetAbilityArgument(bossIdx, this_plugin_name, ability_name, 7);
	if (health <= 0)
		health = 999999; // "invincible"
	
	// find a suitable place for the TARDIS. fall back to BLU spawn if suitable location cannot be found.
	new Float:bossOrigin[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossOrigin);
	new Float:tardisOrigin[3];
	new Float:testPoint[3];
	new bool:wallTestFailure = false;
	new bool:playerTestFailure = false;
	new Float:testDistanceMinimum = 0.0;
	new Float:testedDistance = 0.0;
	new Float:tmpVec[3];
	new Float:rayAngles[3];
	new Float:playerOrigin[3];
	new Float:tardisAngles[3];
	tardisAngles[0] = 0.0;
	tardisAngles[1] = 0.0;
	tardisAngles[2] = 0.0;
	
	// need our widths to test. 1.51 is a cheap way to cover even the center point of the tardis. (i.e. the 2/2/3 triangle)
	new Float:widthTest = fmax(TARDIS_MinMax[clientIdx][1][0] - TARDIS_MinMax[clientIdx][0][0], TARDIS_MinMax[clientIdx][1][1] - TARDIS_MinMax[clientIdx][0][1]) * 1.51;
	for (new attempt = 0; attempt < MAX_TARDIS_SPAWN_ATTEMPTS; attempt++)
	{
		// placement is simple. Z will always be +80 to account for minor bumps and hills
		// X and Y will be plus or minus some random offset
		tardisOrigin[0] = bossOrigin[0] + RandomNegative(GetRandomFloat(minDistance, maxDistance));
		tardisOrigin[1] = bossOrigin[1] + RandomNegative(GetRandomFloat(minDistance, maxDistance));
		tardisOrigin[2] = bossOrigin[2] + 80.0;
		
		// first, the quick test...do ray traces to the four bottom points to ensure there's nothing blocking the tardis from spawning
		// we don't care about the top points. it'll fall through a ceiling and I can live with that.
		testPoint[2] = tardisOrigin[2];
		wallTestFailure = false;
		for (new testNum = 0; testNum < 4; testNum++)
		{
			// simple way to disperse our four tests
			if (testNum == 0 || testNum == 1)
				testPoint[0] = tardisOrigin[0] + TARDIS_MinMax[clientIdx][0][0];
			else
				testPoint[0] = tardisOrigin[0] + TARDIS_MinMax[clientIdx][1][0];
			if (testNum == 1 || testNum == 2)
				testPoint[1] = tardisOrigin[1] + TARDIS_MinMax[clientIdx][0][1];
			else
				testPoint[1] = tardisOrigin[1] + TARDIS_MinMax[clientIdx][1][1];
				
			// get the distance minimum and our angles
			testDistanceMinimum = GetVectorDistance(bossOrigin, testPoint);
			tmpVec[0] = testPoint[0] - bossOrigin[0];
			tmpVec[1] = testPoint[1] - bossOrigin[1];
			tmpVec[2] = testPoint[2] - bossOrigin[2];
			GetVectorAngles(tmpVec, rayAngles);
			
			// get the distance a ray can travel
			new Handle:trace = TR_TraceRayFilterEx(bossOrigin, rayAngles, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
			TR_GetEndPosition(tmpVec, trace);
			CloseHandle(trace);
			testedDistance = GetVectorDistance(tmpVec, bossOrigin);
			
			if (testedDistance < testDistanceMinimum) // we hit a wall. this spawn point is no good.
			{
				if (PRINT_DEBUG_SPAM)
					PrintToServer("[sarysamods3] Wall test failed on attempt %d. (%f < %f) angles=%f,%f    tmpVec=%f,%f,%f", attempt, testedDistance, testDistanceMinimum, rayAngles[0], rayAngles[1], tmpVec[0], tmpVec[1], tmpVec[2]);
				
				wallTestFailure = true;
				break;
			}
		}
		
		if (wallTestFailure)
			continue;
			
		// now the player test
		// doing it cheaply as possible by completely ignoring the Z axis.
		// yes it can be problematic with vertical maps. oh well. but OTOH we don't want it falling on players.
		playerTestFailure = false;
		new failPlayer = 0;
		
		for (new victim = 1; victim < MAX_PLAYERS; victim++)
		{
			// for paranoia's sake I'm including the boss in this test
			if (!IsLivingPlayer(victim))
				continue;
				
			// need the player's position...
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", playerOrigin);
			
			// do a simple point-distance test on x and y.
			for (new testNum = 0; testNum < 4; testNum++)
			{
				// simple way to disperse our four tests
				if (testNum == 0 || testNum == 1)
					testPoint[0] = tardisOrigin[0] + TARDIS_MinMax[clientIdx][0][0];
				else
					testPoint[0] = tardisOrigin[0] + TARDIS_MinMax[clientIdx][1][0];
				if (testNum == 1 || testNum == 2)
					testPoint[1] = tardisOrigin[1] + TARDIS_MinMax[clientIdx][0][1];
				else
					testPoint[1] = tardisOrigin[1] + TARDIS_MinMax[clientIdx][1][1];
					
				if (fabs(testPoint[0] - playerOrigin[0]) < widthTest && fabs(testPoint[1] - playerOrigin[1]) < widthTest)
				{
					playerTestFailure = true;
					failPlayer = victim;
					break;
				}
			}
			
			if (playerTestFailure)
				break;
		}
		
		if (playerTestFailure)
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods3] Player test failed on attempt %d with player %d", attempt, failPlayer);
			continue;
		}
		
		// oh hey, both tests passed. now lets set a good angle rotation for the tardis and get out of here
		// by making it face the player it becomes very unlikely the entrance will be blocked by a wall
		tmpVec[0] = tardisOrigin[0] - bossOrigin[0];
		tmpVec[1] = tardisOrigin[1] - bossOrigin[1];
		tmpVec[2] = tardisOrigin[2] - bossOrigin[2];
		GetVectorAngles(tmpVec, rayAngles);
		
		new Float:eyeAngles[3];
		GetClientEyeAngles(clientIdx, eyeAngles);
		new Float:testAngle = fixAngle(rayAngles[1] - eyeAngles[1]);
		if (testAngle >= 45.0 && testAngle < 135.0)
			tardisAngles[1] = 90.0;
		else if (testAngle >= -45.0 || testAngle < 45.0)
			tardisAngles[1] = 180.0;
		else if (testAngle >= -135.0 && testAngle < -45.0)
			tardisAngles[1] = -90.0;
		
		// and lets set a better origin point so it's close to the ground from the get go
		new Float:highestSafeZ = -99999.0;
		new Float:lowestSafeZ = 99999.0;
		new Float:smallestZDiff = 99999.0;
		testPoint[2] = tardisOrigin[2];
		rayAngles[1] = 0.0;
		for (new testNum = 0; testNum < 4; testNum++)
		{
			// simple way to disperse our four tests
			if (testNum == 0 || testNum == 1)
				testPoint[0] = tardisOrigin[0] + TARDIS_MinMax[clientIdx][0][0];
			else
				testPoint[0] = tardisOrigin[0] + TARDIS_MinMax[clientIdx][1][0];
			if (testNum == 1 || testNum == 2)
				testPoint[1] = tardisOrigin[1] + TARDIS_MinMax[clientIdx][0][1];
			else
				testPoint[1] = tardisOrigin[1] + TARDIS_MinMax[clientIdx][1][1];
				
			// perform a ray trace straight down
			rayAngles[0] = 89.9;
			new Handle:trace = TR_TraceRayFilterEx(testPoint, rayAngles, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
			TR_GetEndPosition(tmpVec, trace);
			CloseHandle(trace);
			if (tmpVec[2] > highestSafeZ)
				highestSafeZ = tmpVec[2];
			if (tmpVec[2] < lowestSafeZ)
				lowestSafeZ = tmpVec[2];
				
			// also perform a ray trace straight up
			rayAngles[0] = -89.9;
			new Float:oldZ = tmpVec[2];
			trace = TR_TraceRayFilterEx(testPoint, rayAngles, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
			TR_GetEndPosition(tmpVec, trace);
			CloseHandle(trace);
			if (fabs(oldZ - tmpVec[2]) < smallestZDiff)
				smallestZDiff = fabs(oldZ - tmpVec[2]);
		}
		
		// determine our max topple
		new Float:maxTopple = (TARDIS_MinMax[clientIdx][1][0] - TARDIS_MinMax[clientIdx][0][0]) / 3.0;
		
		// looks like we have one more fail condition. too much variation means the tardis will likely topple, and we don't want that
		// so ensure there is no such variation
		if (fabs(highestSafeZ - lowestSafeZ) >= maxTopple)
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods3] Topple test failed on attempt %d. Lowest is %f and highest is %f", attempt, lowestSafeZ, highestSafeZ);
			playerTestFailure = true; // lie :P
			continue;
		}
		
		// yet another fail condition, don't let it spawn in too small of a space
		if (smallestZDiff < 63.0 + maxTopple)
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods3] Space test failed on attempt %d. Player needs %f to fit, ended up being %f.", attempt, smallestZDiff, (63.0 + maxTopple));
			playerTestFailure = true; // lie :P
			continue;
		}
		
		tardisOrigin[2] = highestSafeZ + 20.0;
		
		// and even one more, don't want the TARDIS spawning in a damage pit
		if (fabs(tardisOrigin[2] - bossOrigin[2]) > maxZDifference)
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods3] Pit test failed on attempt %d. maxZDifference=%f    zDifference=%f", attempt, maxZDifference, fabs(tardisOrigin[2] - bossOrigin[2]));
			playerTestFailure = true; // lie :P
			continue;
		}
		
		break;
	}
	
	// could not spawn it anywhere, so put it in BLU spawn
	// this could be a problem on rare maps like Mann Co. Headquarters
	if (wallTestFailure || playerTestFailure)
	{
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods3] Could not find suitable spawn location for TARDIS. Falling back to BLU spawn.");
	
		new spawn = -1;
		new teamNum = 0;
		while ((spawn = FindEntityByClassname(spawn, "info_player_teamspawn")) != -1)
		{
			teamNum = GetEntProp(spawn, Prop_Send, "m_iTeamNum");
			if (teamNum == BossTeam)	
				break;
		}
		
		if (spawn == -1)
		{
			PrintToServer("[sarysamods3] Could not find BLU spawn, just going with any spawn there is.");
			spawn = FindEntityByClassname(spawn, "info_player_teamspawn");
			if (spawn == -1)
			{
				PrintToServer("[sarysamods3] WARNING: Could find no way to spawn the TARDIS. Executing TARDIS effects now.");
				OnTardisEntered(clientIdx);
				return;
			}
		}
		
		// no player test. it'd be rare and it's breakable anyway.
		GetEntPropVector(spawn, Prop_Send, "m_vecOrigin", tardisOrigin);
		tardisOrigin[2] += 20; // get it a little bit off the ground, to be safe
	}
	
	// now we have our origin, so create our physics prop
	new tardis = CreateEntityByName("prop_physics");
	SetEntProp(tardis, Prop_Data, "m_takedamage", 2);
	
	// reducing the already heavy amount of math here, giving it an angle rotation of 0
	SetEntPropVector(tardis, Prop_Data, "m_angRotation", tardisAngles);
	
	// set the model
	SetEntityModel(tardis, modelName);
	
	// spawn and move it
	GetEntProp(tardis, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS);
	DispatchSpawn(tardis);
	// also, make it drop fast
	TeleportEntity(tardis, tardisOrigin, tardisAngles, NULL_VECTOR);
	SetEntProp(tardis, Prop_Data, "m_takedamage", 2);
	
	// gotta set its health after it's spawned. just how it is
	SetEntProp(tardis, Prop_Data, "m_iMaxHealth", health);
	SetEntProp(tardis, Prop_Data, "m_iHealth", health);
	
	// delete any old TARDIS and replace its ref with this one
	if (TARDIS_OnMap[clientIdx])
	{
		new oldTardis = EntRefToEntIndex(TARDIS_EntityRef[clientIdx]);
		if (IsValidEntity(oldTardis))
			AcceptEntityInput(oldTardis, "kill");
		TARDIS_EntityRef[clientIdx] = INVALID_ENTREF;
	}
	TARDIS_OnMap[clientIdx] = true;
	TARDIS_EntityRef[clientIdx] = EntIndexToEntRef(tardis);
	TARDIS_Used[clientIdx] = false;
	TARDIS_FadeInTime[clientIdx] = GetEngineTime();
	
	// play the entry sound
	if (strlen(entrySound) > 3)
	{
		new Float:soundOrigin[3];
		soundOrigin[0] = tardisOrigin[0];
		soundOrigin[1] = tardisOrigin[1];
		soundOrigin[2] = tardisOrigin[2] + 50.0;
	
		// double it so it's louder
		EmitAmbientSound(entrySound, soundOrigin, tardis);
		EmitAmbientSound(entrySound, soundOrigin, tardis);
	}
	
	if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods3] Boss %d summoned a TARDIS! Placed at %f,%f,%f", clientIdx, tardisOrigin[0], tardisOrigin[1], tardisOrigin[2]);

	// timer to freeze the tardis.
	TARDIS_FreezeAt[clientIdx] = GetEngineTime() + 1.0;
}

/**
 * DOT Teleport
 *
 * It's just a port of Otokiru's War3 teleport as a DOT.
 */
public bool:TracePlayersAndBuildings(entity, contentsMask)
{
	if (!IsValidEntity(entity))
		return false;

	// check for mercs
	if (entity > 0 && entity < MAX_PLAYERS)
	{
		if (IsPlayerAlive(entity) && !TF2_IsPlayerInCondition(entity, TFCond_Cloaked))
			if (GetClientTeam(entity) != BossTeam)
				return true;
	}
	else
	{
		new String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
		GetEntityClassname(entity, classname, MAX_ENTITY_CLASSNAME_LENGTH);
		if (!strcmp("obj_sentrygun", classname) || !strcmp("obj_dispenser", classname) || !strcmp("obj_teleporter", classname))
			return true;
	}
	
	return false;
}

new absincarray[]={0,4,-4,8,-8,12,-12,18,-18,22,-22,25,-25};//,27,-27,30,-30,33,-33,40,-40}; //for human it needs to be smaller

public bool:CanHitThis(entityhit, mask, any:data)
{
	if(entityhit == data )
	{// Check if the TraceRay hit the itself.
		return false; // Don't allow self to be hit, skip this result
	}
	if (IsValidBoss(entityhit)){
		return false; //skip result, prend this space is not taken cuz they on same team
	}
	return true; // It didn't hit itself
}

public bool:GetEmptyLocationHull(client, Float:originalpos[3], Float:emptypos[3])
{
	new Float:mins[3];
	new Float:maxs[3];
	GetClientMins(client,mins);
	GetClientMaxs(client,maxs);
	new absincarraysize=sizeof(absincarray);
	new limit=5000;
	for(new x=0;x<absincarraysize;x++){
		if(limit>0){
			for(new y=0;y<=x;y++){
				if(limit>0){
					for(new z=0;z<=y;z++){
						new Float:pos[3]={0.0,0.0,0.0};
						AddVectors(pos,originalpos,pos);
						pos[0]+=float(absincarray[x]);
						pos[1]+=float(absincarray[y]);
						pos[2]+=float(absincarray[z]);
						TR_TraceHullFilter(pos,pos,mins,maxs,MASK_SOLID,CanHitThis,client);
						//new ent;
						if(!TR_DidHit(_))
						{
							AddVectors(emptypos,pos,emptypos); ///set this gloval variable
							limit=-1;
							break;
						}
						if(limit--<0){
							break;
						}
					}
					if(limit--<0){
						break;
					}
				}
			}
			if(limit--<0){
				break;
			}
		}
	}
} 

public bool:DOTTeleport(clientIdx)
{
	// taken directly from War3 otokiru with some tweaks
	new Float:eyeAngles[3];
	new Float:bossOrigin[3];
	GetClientEyeAngles(clientIdx, eyeAngles);
	new Float:endPos[3];
	new Float:startPos[3];
	GetClientEyePosition(clientIdx, startPos);
	new Float:dir[3];
	GetAngleVectors(eyeAngles, dir, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(dir, DT_MaxDistance[clientIdx]);
	AddVectors(startPos, dir, endPos);
	GetClientAbsOrigin(clientIdx, bossOrigin);
	TR_TraceRayFilter(startPos, endPos, MASK_ALL, RayType_EndPoint, TracePlayersAndBuildings);
	TR_GetEndPosition(endPos);
	new Float:distanceteleport = GetVectorDistance(startPos, endPos);
	GetAngleVectors(eyeAngles, dir, NULL_VECTOR, NULL_VECTOR);///get dir again
	ScaleVector(dir, distanceteleport - 33.0);

	AddVectors(startPos, dir, endPos);
	new Float:emptyPos[3];
	emptyPos[0] = 0.0;
	emptyPos[1] = 0.0;
	emptyPos[2] = 0.0;

	endPos[2] -= 30.0;
	GetEmptyLocationHull(clientIdx, endPos, emptyPos);

	if (GetVectorLength(emptyPos) < 1.0)
	{
		if (PRINT_DEBUG_INFO)
			PrintToServer("[sarysamods3] Teleport failure case: Bad location");
		PrintCenterText(clientIdx, "Cannot teleport there!");
		return false;
	}

	TeleportEntity(clientIdx, emptyPos, NULL_VECTOR, NULL_VECTOR);
	if (strlen(DT_UseSound[clientIdx]) > 3)
	{
		EmitSoundToAll(DT_UseSound[clientIdx]);
		EmitSoundToAll(DT_UseSound[clientIdx]);
	}
	
	ParticleEffectAt(startPos, DT_OldLocationParticleEffect[clientIdx]);
	ParticleEffectAt(emptyPos, DT_NewLocationParticleEffect[clientIdx]);
	
	return true;
}

/**
 * Sentry Hijack
 */
public RemoveSentryInvuln(sentryEntityRef)
{
	new sentryEntity = EntRefToEntIndex(sentryEntityRef);
	if (IsValidEntity(sentryEntity))
		SetEntProp(sentryEntity, Prop_Data, "m_takedamage", 2);
}

// 2015-03-22, I'm allowing this timer. I must be going soft.
// Alas, the game frame solution would be clunky as hell, since there could be multiple sentries.
// Having a sentry go perma-invuln would be VERY BAD as well.
public Action:Timer_RemoveSentryInvuln(Handle:timer, any:sentryEntityRef)
{
	RemoveSentryInvuln(sentryEntityRef);
}

public SH_RestoreMeleeWeapon(clientIdx)
{
	if (!IsValidBoss(clientIdx))
		return;

	new bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
		return;
		
	new String:weaponName[MAX_WEAPON_NAME_LENGTH];
	new String:weaponArgs[MAX_WEAPON_ARG_LENGTH];
	FF2_GetAbilityArgumentString(FF2_GetBossIndex(clientIdx), this_plugin_name, SH_STRING, 6, weaponName, MAX_WEAPON_NAME_LENGTH);
	new weaponIdx = FF2_GetAbilityArgument(FF2_GetBossIndex(clientIdx), this_plugin_name, SH_STRING, 7);
	FF2_GetAbilityArgumentString(FF2_GetBossIndex(clientIdx), this_plugin_name, SH_STRING, 8, weaponArgs, MAX_WEAPON_ARG_LENGTH);
	new visible = FF2_GetAbilityArgument(FF2_GetBossIndex(clientIdx), this_plugin_name, SH_STRING, 9);
	SwitchWeapon(clientIdx, weaponName, weaponIdx, weaponArgs, visible);
}
 
public RestoreSentry(clientIdx)
{
	// don't do this if the round's over
	if (!RoundInProgress)
		return;
		
	// different things to do depending on if the hale's sentry survived
	new haleSentry = EntRefToEntIndex(SH_HaleSentryEntityRef[clientIdx]);
	new engieSentry = EntRefToEntIndex(SH_OriginalSentryEntityRef[clientIdx]);
	
	if (IsValidEntity(haleSentry))
	{
		// it survived, which means the engie's gun can also live.
		new Float:sentryOrigin[3];
		new Float:sentryAngles[3];
		GetEntPropVector(haleSentry, Prop_Send, "m_vecOrigin", sentryOrigin);
		GetEntPropVector(haleSentry, Prop_Send, "m_angRotation", sentryAngles);
		
		// silently kill the hale's sentry and put the engie's sentry in its place
		AcceptEntityInput(haleSentry, "kill");
		
		// but only if the engie's sentry is still alive (if it's dead, it means the engie is also dead)
		if (IsValidEntity(engieSentry))
		{
			TeleportEntity(engieSentry, sentryOrigin, sentryAngles, NULL_VECTOR);

			// if applicable, make the sentry invulnerable
			if (SH_RestoredSentryInvulnDuration[clientIdx] > 0.0)
			{
				// 2015-03-22 REVAMP NOTE: I am allowing this timer.
				// Move along now.
				SetEntProp(engieSentry, Prop_Data, "m_takedamage", 0);
				CreateTimer(SH_RestoredSentryInvulnDuration[clientIdx], Timer_RemoveSentryInvuln, SH_OriginalSentryEntityRef[clientIdx], TIMER_FLAG_NO_MAPCHANGE);
				SH_OriginalSentryEntityRef[clientIdx] = -1;
			}
		}
	}
	else
	{
		// it was destroyed, so silently destroy the engie's hidden gun as well
		if (IsValidEntity(engieSentry))
			AcceptEntityInput(engieSentry, "kill");
	}
	
	// regardless of the above condition, must restore use of the engie's PDA
	SH_BuildBlocked[SH_SentryOriginalOwner[clientIdx]] = false;
}

public OnEntityCreated(entity, const String:classname[])
{
	//PrintToServer("Entity %d, class %s, created", entity, classname);

	// sentry hijack, sappers
	// no sense keeping it around while sappers are broken. saving it for later
	//if (SH_ActiveThisRound && !strcmp(classname, "obj_attachment_sapper"))
	//{
	//	for (new i = 1; i < MAX_PLAYERS; i++)
	//	{
	//		if (SH_IsHijacking[i])
	//		{
	//			if (SH_SapperResist[i])
	//				AcceptEntityInput(entity, "kill");
	//			// hrm, not sure what to do here...probably nothing is best. player can just end the rage. gives more value to spies this way.
	//			//else
	//			//	CreateTimer(0.5, Timer_SapperForceDeactivation, 
	//			
	//			break;
	//		}
	//	}
	//}
	
	// regeneration shockwave, gibs
	if (IgniteNextNGibs > 0 && !strcmp(classname, "gib"))
	{
		if (IsValidEntity(entity))
		{
			// tried this, failed. the gibs can collide with each other and larger scale
			// increases the chance of gibs getting stuck. also, no change to size of flame.
			//SetEntPropFloat(entity, Prop_Send, "m_flModelScale", GetRandomFloat(0.5, 5.0));
			IgniteEntity(entity, IgniteGibsDuration);
			IgniteNextNGibs--;
		}
	}
}

public Action:OnHijackedSentryTakeDamage(sentryEntity, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (!IsValidEntity(sentryEntity))
		return Plugin_Continue;

	damagetype = DMG_GENERIC;
	new clientIdx = GetEntProp(sentryEntity, Prop_Send, "m_hBuilder") & 0x3ff;
	if (IsValidBoss(clientIdx))
	{
		if (SH_HaleSentryHPBoostFactor[clientIdx] == 0.0)
			damage = 0.0;
		else
			damage /= SH_HaleSentryHPBoostFactor[clientIdx];
	}
	else
		PrintToServer("[sarysamods3] ERROR: Sentry damage being tracked, belongs to invalid boss.");
		
	return Plugin_Changed;
}

public HijackSentry(clientIdx, sentryEntity)
{
	// for the hidden props
	new offs;

	// store stuff we'll need to use to restore the sentry later
	SH_SentryOriginalOwner[clientIdx] = GetEntProp(sentryEntity, Prop_Send, "m_hBuilder") & 0x3ff;
	new sentryMaxHealth = GetEntProp(sentryEntity, Prop_Send, "m_iMaxHealth");
	// for whatever reason this style of HP boost is not working
	new haleSentryMaxHP = sentryMaxHealth; // RoundFloat(sentryMaxHealth * SH_HaleSentryHPBoostFactor[clientIdx]);
	
	// get the original sentry's position and angles
	new Float:sentryOrigin[3];
	new Float:sentryAngles[3];
	GetEntPropVector(sentryEntity, Prop_Send, "m_vecOrigin", sentryOrigin);
	GetEntPropVector(sentryEntity, Prop_Send, "m_angRotation", sentryAngles);
	
	// various fail conditions
	if (GetEntProp(sentryEntity, Prop_Data, "m_takedamage") == 0)
	{
		// don't let user re-hijack so soon after releasing control. this is to discourage quick toggles to heal the hijacked sentry.
		return false;
	}
	else if (GetEntProp(sentryEntity, Prop_Send, "m_bBuilding")) // don't hijack a sentry being built
		return false;
	else if (GetEntProp(sentryEntity, Prop_Send, "m_bPlacing")) // don't hijack a sentry being placed
		return false;
		
	// create a new sentry on top of the old one
	new newSentry = CreateEntityByName("obj_sentrygun");
	if (!IsValidEntity(newSentry))
	{
		PrintToServer("[sarysamods3] ERROR: Could not create sentry!");
		return false;
	}
	
	// and now we can set the entity ref for the old sentry
	SH_OriginalSentryEntityRef[clientIdx] = EntIndexToEntRef(sentryEntity);
	
	// spawn it before making settings
	DispatchSpawn(newSentry);
	TeleportEntity(newSentry, sentryOrigin, sentryAngles, NULL_VECTOR);
	
	// gotta set the model...
	new oldSentryLevel = GetEntProp(sentryEntity, Prop_Send, "m_iUpgradeLevel") & 0x03;
	new String:modelName[MAX_MODEL_FILE_LENGTH];
	Format(modelName, MAX_MODEL_FILE_LENGTH, "models/buildables/sentry%d.mdl", oldSentryLevel);
	SetEntityModel(newSentry, modelName);
	
	// basic ammo, health...
	offs = FindSendPropInfo("CObjectSentrygun", "m_iAmmoShells");
	if (offs > 0)
		SetEntData(newSentry, offs - 4, 5000, 4, true); // my first find, max shells :D
	SetEntProp(newSentry, Prop_Send, "m_iAmmoShells", 5000); // more than enough
	SetEntProp(newSentry, Prop_Send, "m_iMaxHealth", haleSentryMaxHP);
	SetEntProp(newSentry, Prop_Send, "m_iHealth", haleSentryMaxHP);
	SetEntProp(newSentry, Prop_Send, "m_iObjectType", _:TFObject_Sentry);

	// specific to mini sentry
	new mini = GetEntProp(sentryEntity, Prop_Send, "m_bMiniBuilding") & 0x01;
	if (mini)
	{
		SetEntProp(newSentry, Prop_Send, "m_bMiniBuilding", mini);
		SetEntPropFloat(newSentry, Prop_Send, "m_flModelScale", 0.75); // credit to FlaminSarge
	}

	// sentry team and skin
	SetEntProp(newSentry, Prop_Send, "m_iTeamNum", BossTeam);
	SetEntProp(newSentry, Prop_Send, "m_nSkin", BossTeam - (mini ? 0 : 2));
	
	// sentry level, and level 3 specific stuff
	SetEntProp(newSentry, Prop_Send, "m_iUpgradeLevel", oldSentryLevel);
	SetEntProp(newSentry, Prop_Send, "m_iHighestUpgradeLevel", GetEntProp(sentryEntity, Prop_Send, "m_iHighestUpgradeLevel") & 0x03);
	if (oldSentryLevel == 3)
	{
		offs = FindSendPropInfo("CObjectSentrygun", "m_iAmmoRockets");
		if (offs > 0)
			SetEntData(newSentry, offs - 4, 50, 4, true); // my second find, max rockets :D
		SetEntProp(newSentry, Prop_Send, "m_iAmmoRockets", 50);
	}
		
	// Credit to FlaminSarge on this one, seems state 3 will fix the firing position
	// state 1 is just generic idle, and state 2 is used both by firing and wrangled
	SetEntProp(newSentry, Prop_Send, "m_iState", 3);
	
	// belongs to the boss
	SetEntPropEnt(newSentry, Prop_Send, "m_hBuilder", clientIdx);
	SetEntPropEnt(newSentry, Prop_Send, "m_hOwnerEntity", clientIdx);

	// construction percentage and whatever BuildMaxs is :P
	SetEntPropFloat(newSentry, Prop_Send, "m_flPercentageConstructed", 1.0);
	
	// credit for values: BuildingSpawner.sp by X3Mano with edits by FlaminSarge
	SetEntPropVector(newSentry, Prop_Send, "m_vecBuildMaxs", Float:{ 24.0, 24.0, 66.0 });
	SetEntPropVector(newSentry, Prop_Send, "m_vecBuildMins", Float:{ -24.0, -24.0, 0.0 });
	
	// a long time ago this fixed the sapper problem. now it does not.
	// the offset is now -10 but it doesn't work on its own.
	//new offs = FindSendPropInfo("CObjectSentrygun", "m_iDesiredBuildRotations");	//2608
	//if (offs > 0)
	//	SetEntData(newSentry, offs - 12, 1, 1, true);
	//else
	//	PrintToServer("nope.");
	
	// track damage to sentry, this is where damage reduction must be done
	SDKHook(newSentry, SDKHook_OnTakeDamage, OnHijackedSentryTakeDamage);
	
	// save this entity
	SH_HaleSentryEntityRef[clientIdx] = EntIndexToEntRef(newSentry);
	
	// debug info
	if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods3] Level %d (or %d) sentry has been hijacked by boss %d, belongs to engie %d (or %d), original sentry is %d(%d) (hp=%d), temporary sentry is %d(%d) (hp=%d)", oldSentryLevel, oldSentryLevel & 0x03, clientIdx, SH_SentryOriginalOwner[clientIdx], SH_SentryOriginalOwner[clientIdx] & 0x3ff, SH_OriginalSentryEntityRef[clientIdx], sentryEntity, sentryMaxHealth, SH_HaleSentryEntityRef[clientIdx], newSentry, haleSentryMaxHP);

	// send the original sentry off the map and disable the original engie's PDAs
	TeleportEntity(sentryEntity, OFF_THE_MAP, NULL_VECTOR, NULL_VECTOR);
	SH_BuildBlocked[SH_SentryOriginalOwner[clientIdx]] = true;
	
	// switch original engie's weapon for the case they could be in a build state
	// removed on 2015-03-22, causes bugs
	//SetEntPropEnt(SH_SentryOriginalOwner[clientIdx], Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(SH_SentryOriginalOwner[clientIdx], 2));
	
	// and of course...
	SH_IsHijacking[clientIdx] = true;
	
	return true;
}

public Action:BlockPDA(client, const String:command[], argc)
{
	if (client > 0 && client < MAX_PLAYERS)
	{
		if (SH_BuildBlocked[client])
		{
			EmitSoundToClient(client, NOPE_AVI);
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

// HUGE CREDIT goes to FlaminSarge of AlliedMods for this
// Clearly I have a crappy reverse-engineered version of the TF2 SDK...
// because I had no sentry class to refer to to find offsets like the ones below...gah.
public Action:OnPlayerRunCmd(clientIdx, &buttons, &impulse, Float:vel[3], Float:angles[3], &weaponIdx)
{
	if (!PluginActiveThisRound)
		return Plugin_Continue;
		
	if (!IsLivingPlayer(clientIdx))
		return Plugin_Continue;
		
	if (RS_BlockingAllInput)
	{
		if (RS_BlockingAllInputUntil <= GetEngineTime())
			RS_BlockingAllInput = false;
		else
		{
			buttons = 0;
			
			if (IsLivingPlayer(clientIdx))
			{
				// freeze player's meters during the rage
				// medic is the only one that needs to be explicitly checked
				if (TF2_GetPlayerClass(clientIdx) == TFClass_Medic)
				{
					new medigun = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Secondary);
					if (IsValidEntity(medigun))
					{
						new String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
						GetEntityClassname(medigun, classname, sizeof(classname));
						if (!strcmp(classname, "tf_weapon_medigun"))
							SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", RS_Medigun[clientIdx]);
					}
				}

				// the rest of these, all players have
				SetEntPropFloat(clientIdx, Prop_Send, "m_flRageMeter", RS_Rage[clientIdx]);
				SetEntPropFloat(clientIdx, Prop_Send, "m_flCloakMeter", RS_Cloak[clientIdx]);
				SetEntPropFloat(clientIdx, Prop_Send, "m_flHypeMeter", RS_Hype[clientIdx]);
				SetEntPropFloat(clientIdx, Prop_Send, "m_flChargeMeter", RS_Charge[clientIdx]);
			}
			
			return Plugin_Changed;
		}
	}
	
	if (GetClientTeam(clientIdx) == BossTeam && SH_CanUse[clientIdx] && SH_IsHijacking[clientIdx])
	{
		if (!TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed))
		{
			new sentryEntity = EntRefToEntIndex(SH_HaleSentryEntityRef[clientIdx]);
			new wrangler = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
			if (IsValidEntity(sentryEntity) && IsValidEntity(wrangler))
			{
				new initialOffset = FindSendPropInfo("CObjectSentrygun", "m_hEnemy");
				new hitscanOffset = initialOffset + 4;
				new rocketOffset = initialOffset + 5;
				new bool:canFireHitscan = GetEntPropFloat(wrangler, Prop_Send, "m_flNextPrimaryAttack") <= GetEngineTime();
				new bool:canFireRockets = GetEntPropFloat(wrangler, Prop_Send, "m_flNextSecondaryAttack") <= GetEngineTime();
				
				if ((buttons & IN_ATTACK) && canFireHitscan)
					SetEntData(sentryEntity, hitscanOffset, 1, 1, true);
				if ((buttons & IN_ATTACK2) && canFireRockets)
					SetEntData(sentryEntity, rocketOffset, 1, 1, true);
			}
			else
			{
				// force the rage to end. sentry was destroyed.
				ForceDOTAbilityDeactivation(clientIdx);
			
				if (PRINT_DEBUG_SPAM)
					PrintToServer("[sarysamods3] Something is not valid: %d %d", sentryEntity, wrangler);
			}
		}
		else
		{
			if (PRINT_DEBUG_SPAM)
				PrintToServer("[sarysamods3] Boss is dazed. Cannot control sentry.");
		}
	}
	
	return Plugin_Continue;
}

public OnGameFrame()
{
	if (!PluginActiveThisRound)
		return;
		
	new Float:curTime = GetEngineTime();
		
	if (RS_ActiveThisRound || CS_ActiveThisRound || MS_ActiveThisRound || SD_ActiveThisRound || FD_ActiveThisRound || TARDIS_ActiveThisRound)
	{
		for (new clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (!IsLivingPlayer(clientIdx) || GetClientTeam(clientIdx) != BossTeam)
				continue;
				
			if (RS_CanUse[clientIdx])
				RS_Tick(clientIdx, curTime);
				
			if (CS_CanUse[clientIdx])
				CS_Tick(clientIdx, curTime);
				
			if (MS_CanUse[clientIdx])
				MS_Tick(clientIdx, curTime);
				
			if (SD_CanUse[clientIdx])
				SD_Tick(clientIdx, curTime);
				
			if (FD_CanUse[clientIdx])
				FD_Tick(clientIdx, curTime);
				
			if (TARDIS_CanUse[clientIdx])
				TARDIS_Tick(clientIdx, curTime);
		}
	}
}

/**
 * General helper stocks, some original, some taken/modified from other sources
 */
stock bool:IsLivingPlayer(clientIdx)
{
	if (clientIdx <= 0 || clientIdx >= MAX_PLAYERS)
		return false;
		
	return IsClientInGame(clientIdx) && IsPlayerAlive(clientIdx);
}

stock ReadSound(bossIdx, const String:ability_name[], argInt, String:soundFile[MAX_SOUND_FILE_LENGTH])
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, soundFile, MAX_SOUND_FILE_LENGTH);
	if (strlen(soundFile) > 3)
		PrecacheSound(soundFile);
}

stock ReadModel(bossIdx, const String:ability_name[], argInt, String:modelFile[MAX_MODEL_FILE_LENGTH])
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, modelFile, MAX_MODEL_FILE_LENGTH);
	if (strlen(modelFile) > 3)
		PrecacheModel(modelFile);
}
 
stock ReadModelToInt(bossIdx, const String:ability_name[], argInt)
{
	static String:modelFile[MAX_MODEL_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, modelFile, MAX_MODEL_FILE_LENGTH);
	if (strlen(modelFile) > 3)
		return PrecacheModel(modelFile);
	return -1;
}

stock bool:IsValidBoss(clientIdx)
{
	if (!IsLivingPlayer(clientIdx))
		return false;
		
	return GetClientTeam(clientIdx) == BossTeam;
}

stock FindRandomLivingMerc()
{
	for (new i = 1; i < MAX_PLAYERS; i++)
		if (IsLivingPlayer(i) && GetClientTeam(i) != BossTeam)
			return i;
			
	return -1;
}

stock SwitchWeapon(bossClient, String:weaponName[], weaponIdx, String:weaponAttributes[], visible)
{
	TF2_RemoveWeaponSlot(bossClient, TFWeaponSlot_Primary);
	TF2_RemoveWeaponSlot(bossClient, TFWeaponSlot_Secondary);
	TF2_RemoveWeaponSlot(bossClient, TFWeaponSlot_Melee);
	new weapon;
	weapon = SpawnWeapon(bossClient, weaponName, weaponIdx, 101, 5, weaponAttributes, visible);
	SetEntPropEnt(bossClient, Prop_Data, "m_hActiveWeapon", weapon);
}

SpawnWeapon(client, String:name[], index, level, quality, String:attribute[], visible = 1)
{
	new Handle:weapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(weapon, name);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, quality);
	new String:attributes[32][32];
	new count = ExplodeString(attribute, ";", attributes, 32, 32);
	if(count%2!=0)
	{
		count--;
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(weapon, count/2);
		new i2 = 0;
		for(new i = 0; i < count; i += 2)
		{
			new attrib = StringToInt(attributes[i]);
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
		PrintToServer("[sarysamods3] Error: Invalid weapon spawned. client=%d name=%s idx=%d attr=%s", client, name, index, attribute);
		return -1;
	}

	new entity = TF2Items_GiveNamedItem(client, weapon);
	CloseHandle(weapon);
	EquipPlayerWeapon(client, entity);
	
	// sarysa addition
	if (!visible)
	{
		SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
	}
	
	return entity;
}

stock GetA(c) { return abs(c>>24); }
stock GetR(c) { return abs((c>>16)&0xff); }
stock GetG(c) { return abs((c>>8 )&0xff); }
stock GetB(c) { return abs((c    )&0xff); }

stock charToHex(c)
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

stock SetColorRGBA(color[4], r, g, b, a)
{
	color[0] = abs(r)%256;
	color[1] = abs(g)%256;
	color[2] = abs(b)%256;
	color[3] = abs(a)%256;
}

stock ParseColor(String:colorStr[])
{
	new ret = 0;
	ret |= charToHex(colorStr[0])<<20;
	ret |= charToHex(colorStr[1])<<16;
	ret |= charToHex(colorStr[2])<<12;
	ret |= charToHex(colorStr[3])<<8;
	ret |= charToHex(colorStr[4])<<4;
	ret |= charToHex(colorStr[5]);
	return ret;
}

stock ColorToDecimalString(String:buffer[COLOR_BUFFER_SIZE], rgb)
{
	Format(buffer, COLOR_BUFFER_SIZE, "%d %d %d", GetR(rgb), GetG(rgb), GetB(rgb));
}

stock GetBossClientId(bossIdx)
{
	new userId = FF2_GetBossUserId(bossIdx);
	if (userId <= 0)
		return -1;
		
	return GetClientOfUserId(userId);
}

stock Float:fixAngle(Float:angle)
{
	new sanity = 0;
	while (angle < -180.0 && (sanity++) <= 10)
		angle = angle + 360.0;
	while (angle > 180.0 && (sanity++) <= 10)
		angle = angle - 360.0;
		
	return angle;
}

stock constrainDistance(const Float:startPoint[], Float:endPoint[], Float:distance, Float:maxDistance)
{
	if (distance <= maxDistance)
		return; // nothing to do
		
	new Float:constrainFactor = maxDistance / distance;
	endPoint[0] = ((endPoint[0] - startPoint[0]) * constrainFactor) + startPoint[0];
	endPoint[1] = ((endPoint[1] - startPoint[1]) * constrainFactor) + startPoint[1];
	endPoint[2] = ((endPoint[2] - startPoint[2]) * constrainFactor) + startPoint[2];
}

stock CopyVector(Float:dst[3], Float:src[3])
{
	dst[0] = src[0];
	dst[1] = src[1];
	dst[2] = src[2];
}

stock Float:ClampBeamWidth(Float:w) { return w > 128.0 ? 128.0 : w; }

stock abs(x)
{
	return x < 0 ? -x : x;
}

stock Float:fabs(Float:x)
{
	return x < 0 ? -x : x;
}

stock Float:fmax(Float:x1, Float:x2)
{
	return x1 > x2 ? x1 : x2;
}

stock ParticleEffectAt(Float:position[3], String:effectName[], Float:duration = 0.1)
{
	if (IsEmptyString(effectName))
		return -1; // nothing to display
		
	new particle = CreateEntityByName("info_particle_system");
	if (particle != -1)
	{
		TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "effect_name", effectName);
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		if (duration > 0.0)
			CreateTimer(duration, Timer_RemoveEntity, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
	}
	return particle;
}

stock Float:RandomNegative(Float:val)
{
	return val * (GetRandomInt(0, 1) == 1 ? 1.0 : -1.0);
}

stock bool:WithinBounds(Float:point[3], Float:min[3], Float:max[3])
{
	return point[0] >= min[0] && point[0] <= max[0] &&
		point[1] >= min[1] && point[1] <= max[1] &&
		point[2] >= min[2] && point[2] <= max[2];
}

public Action:RemoveGodMode(Handle:timer, any:userId)
{
	new clientIdx = GetClientOfUserId(userId);
	
	if (!IsValidEntity(clientIdx))
		return Plugin_Stop;
		
	SetEntProp(clientIdx, Prop_Data, "m_takedamage", 2);
	TF2_RemoveCondition(clientIdx, TFCond_Ubercharged);
	TF2_RemoveCondition(clientIdx, TFCond_MegaHeal);
		
	return Plugin_Stop;
}

/**
 * CODE BELOW WAS TAKEN STRAIGHT FROM PHATRAGES, I TAKE NO CREDIT FOR IT
 */
stock env_shake(Float:Origin[3], Float:Amplitude, Float:Radius, Float:Duration, Float:Frequency)
{
	decl Ent;

	//Initialize:
	Ent = CreateEntityByName("env_shake");
		
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
		CreateTimer(Duration + 1.0, Timer_RemoveEntity, EntIndexToEntRef(Ent), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:Timer_RemoveEntity(Handle:timer, any:entid)
{
	new entity = EntRefToEntIndex(entid);
	if (IsValidEdict(entity) && entity > MaxClients)
	{
		AcceptEntityInput(entity, "Kill");
	}
}

stock AttachParticle(entity, const String:particleType[], Float:offset=0.0, bool:attach=true)
{
	new particle = CreateEntityByName("info_particle_system");
	
	if (!IsValidEntity(particle))
		return -1;

	decl String:targetName[128];
	decl Float:position[3];
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
	if (attach)
	{
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	}
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	return particle;
}
