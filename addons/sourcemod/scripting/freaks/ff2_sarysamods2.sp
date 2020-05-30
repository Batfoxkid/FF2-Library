// best viewed with tab width of 8

// GPL blah blah don't sue if something goes wrong blah blah no warranty blah blah

#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <ff2_dynamic_defaults>

#pragma semicolon 1
#pragma newdecls required

/**
 * A second wave of mods, some stuff for Button Mash and others that aren't. (like the first one)
 *
 * RageBossOverlay: Display a cosmetic overlay to the boss when they rage. Used by Button Mash.
 *	Known issues: Do NOT use on a boss with a drain over time rage. The DOT "reload" overlay will quickly kill this one. (or race condition if this one animates)
 *		      Like any overlay, fire makes it disappear. You can mostly work around it by adding animation, even BS animation like two of the same frame.
 *	Credits: Obviously, this is just a simple inversion of FF2's stock rage_overlay. (though I expanded this a bit)
 *
 * RageCustomProjectileGun: Boss is swapped to a int weapon on rage fires custom model projectiles from their gun.
 *			    Melee is unavailable during this rage.
 *	Known issues: Projectile reverts to old model after it strikes target or wall. Can't fix, believe me I tried. I don't think leftover is even an entity.
 *		      Some weapons and damage flags are incompatible. For example, you can't gib with the Rescue Ranger.
 *		      A few lines will show up in the console complaining about the projectiles belonging to a destroyed weapon
 *		          after the user reverts to melee. Has no effect on gameplay.
 *
 * RageBossGravity: Make changes (positive or negative) to the boss' gravity.
 *	Known issues: It affects the player's super jump. More gravity = lower super jump and vice versa.
 * 
 * RageAlteredSounds: Plays int sounds for certain events like jump. Does not remove any of the boss' existing sounds.
 *	Known issues: Ambient sounds are finicky. You need locally played sounds that peak around 1.0 gain for them to be audible over all the other noise.
 *		      Audacity does a good job of this, but you need to export and reload the sound to ensure you've hit
 *		      around 1.0 peak gain without going overboard and corrupting the sound. (yes, I've learned a thing or two since Cheese :P )
 *		      Altered attack sound will not work properly with The Huntsman, and is untested for instances where the player must reload.
 *		      User can fudge with the logic and possibly spam attack spells if they have access to weapon switching. (Button did not)
 *
 * RageReloadBump: While this is active, the user will bump forward if they hit reload. Good all-class alternative to charge,
 *		   more versatile for the user, and has a delay between uses.
 *
 * ReskinnedMelee: Reskins the user's melee weapon. (note: Button Mash does NOT use this, that joystick is in the model itself)
 *   Known issues: Only the local player can see it, and only in third person mode. Seems that Valve crippled this a bit. Damn. Sorry, but you'll want to add it to the model.
 *		   Will reskin any melee weapon it detects that isn't already reskinned on the boss. Bosses with multiple melee weapons (i.e. Cheese) shouldn't use this.
 *		   Brutal Legend guitar appears as your reskin. No clean way around it.
 *
 * RageModelOverride: Reskins the player when they rage. BTW, hi Friagram. I'm guessing you're reviewing this code for VSP and I know your opinion on the
 *		      subject, but in spite of the advice you gave me I could not noodle through reskinning with skin families. I hit the same impasse as
 *		      before -- documentation didn't help and part of what you said seemed to be native plugin territory which I'm assuming is off limits.
 *		      So I had to go with the failtastic option. :/ At least for Button, the only difference between models is one's missing his hat.
 *
 * Revamped on 2015-03-21
 */

// change this to minimize console output
int PRINT_DEBUG_INFO = true;

#define MAX_PLAYERS_ARRAY 36
#define MAX_PLAYERS (MAX_PLAYERS_ARRAY < (MaxClients + 1) ? MAX_PLAYERS_ARRAY : (MaxClients + 1))

// text string limits
#define MAX_SOUND_FILE_LENGTH 80
#define MAX_MODEL_FILE_LENGTH 128
#define MAX_MATERIAL_FILE_LENGTH 128
#define MAX_WEAPON_NAME_LENGTH 64
#define MAX_WEAPON_ARG_LENGTH 256
#define MAX_EFFECT_NAME_LENGTH 48
#define MAX_ENTITY_CLASSNAME_LENGTH 48

#define FAR_FUTURE 100000000.0
#define IsEmptyString(%1) (%1[0] == 0)

int BossTeam = view_as<int>(TFTeam_Blue);

// HUD hiding constants
#define HUD_HIDE_NONE 0
#define HUD_HIDE_ALL (1<<2)
#define HUD_HIDE_AVATAR (1<<3)
#define HUD_HIDE_RETICLE_AVATAR_AMMO (1<<4)
#define HUD_HIDE_POINT_RAGE (1<<6)
#define HUD_HIDE_CHAT (1<<7)
#define HUD_HIDE_RETICLE (1<<8)
#define NUM_HUD_HIDE_LEVELS 4
int HUD_HIDE_LEVELS[NUM_HUD_HIDE_LEVELS] = { HUD_HIDE_NONE,
		HUD_HIDE_RETICLE_AVATAR_AMMO | HUD_HIDE_POINT_RAGE,
		HUD_HIDE_RETICLE_AVATAR_AMMO | HUD_HIDE_POINT_RAGE | HUD_HIDE_CHAT,
		HUD_HIDE_RETICLE_AVATAR_AMMO | HUD_HIDE_POINT_RAGE | HUD_HIDE_CHAT | HUD_HIDE_ALL };

// quick way to see if the round is active
bool RoundInProgress = false;
bool PluginActiveThisRound = false;

/**
 * Boss Overlay
 */
#define BO_STRING "rage_boss_overlay"
bool BO_ActiveThisRound;
bool BO_CanUse[MAX_PLAYERS_ARRAY];
float BO_RestoreOverlayAt[MAX_PLAYERS_ARRAY]; // internal
float BO_IncrementOverlayAt[MAX_PLAYERS_ARRAY]; // internal
float BO_ActiveUntil[MAX_PLAYERS_ARRAY]; // internal
int BO_CurrentFrame[MAX_PLAYERS_ARRAY]; // internal
float BO_Duration[MAX_PLAYERS_ARRAY]; // arg1
// arg2 is space inefficient to use this way, grabbed when overlay is set
int BO_FrameCount[MAX_PLAYERS_ARRAY]; // arg3
float BO_IncrementInterval[MAX_PLAYERS_ARRAY]; // arg4
int BO_HUDHideLevel[MAX_PLAYERS_ARRAY]; // arg5

/**
 * Custom Projectile Gun
 */
#define CPG_STRING "rage_custom_projectile_gun"
bool CPG_ActiveThisRound;
bool CPG_CanUse[MAX_PLAYERS_ARRAY];
float CPG_ActiveUntil[MAX_PLAYERS_ARRAY]; // internal
bool CPG_TestNextFrame[MAX_PLAYERS_ARRAY]; // internal
float CPG_RageDuration[MAX_PLAYERS_ARRAY]; // arg1
int CPG_ModelIndex[MAX_PLAYERS_ARRAY]; // arg2
// arg3-arg10 are related to weapon swap. not worth storing
char CPG_EntityClassname[MAX_PLAYERS_ARRAY][MAX_ENTITY_CLASSNAME_LENGTH]; // arg11
char CPG_EffectOnHit[MAX_PLAYERS_ARRAY][MAX_EFFECT_NAME_LENGTH]; // arg12
float CPG_EffectDuration[MAX_PLAYERS_ARRAY]; // arg13
int CPG_DamageFlagOverride[MAX_PLAYERS_ARRAY]; // arg14
bool CPG_BlockHeadshots[MAX_PLAYERS_ARRAY]; // arg15

/**
 * Boss Gravity
 */
#define BG_STRING "rage_boss_gravity"
bool BG_ActiveThisRound;
bool BG_CanUse[MAX_PLAYERS_ARRAY]; // internal
float BG_ActiveUntil[MAX_PLAYERS_ARRAY]; // internal

/**
 * Altered Sounds
 */
#define AS_STRING "rage_altered_sounds"
bool AS_ActiveThisRound = false;
bool AS_CanUse[MAX_PLAYERS_ARRAY];
float AS_ActiveUntil[MAX_PLAYERS_ARRAY]; // internal
float AS_FireSoundSanityTimer[MAX_PLAYERS_ARRAY]; // internal
bool AS_JumpWasDown[MAX_PLAYERS_ARRAY]; // internal
bool AS_AttackWasDown[MAX_PLAYERS_ARRAY]; // internal
float AS_LastFireTimeRecorded[MAX_PLAYERS_ARRAY]; // internal
int AS_AirDashCount[MAX_PLAYERS_ARRAY]; // internal
float AS_Duration[MAX_PLAYERS_ARRAY]; // arg1
char AS_JumpSound[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg2
char AS_KillSound[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg3
char AS_FireSound[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg4
//bool AS_CanDoubleJump[MAX_PLAYERS_ARRAY]; // arg5, DEPRECATED
bool AS_RageNotRequired[MAX_PLAYERS_ARRAY]; // arg6

/**
 * Reload Bump
 */
#define RB_STRING "rage_reload_bump"
bool RB_ActiveThisRound = false;
bool RB_CanUse[MAX_PLAYERS_ARRAY];
float RB_ActiveUntil[MAX_PLAYERS_ARRAY]; // internal
float RB_CanBumpAgainAt[MAX_PLAYERS_ARRAY]; // internal
float RB_Duration[MAX_PLAYERS_ARRAY]; // arg1
float RB_Intensity[MAX_PLAYERS_ARRAY]; // arg2
float RB_UseDelay[MAX_PLAYERS_ARRAY]; // arg3
char RB_BumpSound[MAX_PLAYERS_ARRAY][MAX_SOUND_FILE_LENGTH]; // arg4
float RB_ZLift[MAX_PLAYERS_ARRAY]; // arg5

/**
 * Model Override (opting not to store any args for this one, for space efficiency)
 */
#define MO_STRING "rage_model_override"
bool MO_ActiveThisRound;
bool MO_CanUse[MAX_PLAYERS_ARRAY];
float MO_ActiveUntil[MAX_PLAYERS_ARRAY]; // internal
char MO_NormalModel[MAX_PLAYERS_ARRAY][MAX_MODEL_FILE_LENGTH]; // internal

/**
 * Reskinned Melee - Kept it around even after the revamp. Maybe Valve will allow it someday.
 */
#define RM_STRING "ff2_reskinned_melee"
bool RM_ActiveThisRound;
bool RM_CanUse[MAX_PLAYERS_ARRAY];
int RM_ModelIndex[MAX_PLAYERS_ARRAY];

public Plugin myinfo = {
	name = "Freak Fortress 2: sarysa's mods, second pack",
	author = "sarysa",
	version = "1.1.1",
};
	
public void OnPluginStart2()
{
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	// non-array inits
	PluginActiveThisRound = false;
	BO_ActiveThisRound = false;
	RB_ActiveThisRound = false;
	BG_ActiveThisRound = false;
	AS_ActiveThisRound = false;
	MO_ActiveThisRound = false;
	RM_ActiveThisRound = false;

	// round is active
	RoundInProgress = true;
	
	// various array inits
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		// REVAMP init list
		BO_CanUse[clientIdx] = false;
		CPG_CanUse[clientIdx] = false;
		CPG_ModelIndex[clientIdx] = -1;
		CPG_DamageFlagOverride[clientIdx] = -1;
		CPG_ActiveUntil[clientIdx] = FAR_FUTURE;
		CPG_EntityClassname[clientIdx][0] = 0;
		CPG_TestNextFrame[clientIdx] = false;
		BG_CanUse[clientIdx] = false;
		AS_CanUse[clientIdx] = false;
		RM_CanUse[clientIdx] = false;
		RB_CanUse[clientIdx] = false;
		MO_CanUse[clientIdx] = false;
	
		if (!IsLivingPlayer(clientIdx) || GetClientTeam(clientIdx) != BossTeam)
			continue;
		int bossIdx = FF2_GetBossIndex(clientIdx);
		if (bossIdx < 0)
			continue;

		// boss-only inits
		if ((BO_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, BO_STRING)) == true)
		{
			PluginActiveThisRound = true;
			BO_ActiveThisRound = true;
			BO_ActiveUntil[clientIdx] = FAR_FUTURE;
			BO_RestoreOverlayAt[clientIdx] = FAR_FUTURE;
			BO_IncrementOverlayAt[clientIdx] = FAR_FUTURE;

			BO_Duration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, BO_STRING, 1);
			BO_FrameCount[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, BO_STRING, 3);
			BO_IncrementInterval[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, BO_STRING, 4);
			BO_HUDHideLevel[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, BO_STRING, 5);
		}
		
		if ((BG_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, BG_STRING)) == true)
		{
			PluginActiveThisRound = true;
			BG_ActiveThisRound = true;
			BG_ActiveUntil[clientIdx] = FAR_FUTURE;
		}

		if ((AS_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, AS_STRING)) == true)
		{
			PluginActiveThisRound = true;
			AS_ActiveThisRound = true;
			AS_ActiveUntil[clientIdx] = FAR_FUTURE;

			AS_Duration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, AS_STRING, 1);
			ReadSound(bossIdx, AS_STRING, 2, AS_JumpSound[clientIdx]);
			ReadSound(bossIdx, AS_STRING, 3, AS_KillSound[clientIdx]);
			ReadSound(bossIdx, AS_STRING, 4, AS_FireSound[clientIdx]);
			//AS_CanDoubleJump[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, AS_STRING, 5) == 1;
			AS_RageNotRequired[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, AS_STRING, 6) == 1;
		}

		if ((RB_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, RB_STRING)) == true)
		{
			PluginActiveThisRound = true;
			RB_ActiveThisRound = true;
			RB_ActiveUntil[clientIdx] = FAR_FUTURE;
			RB_CanBumpAgainAt[clientIdx] = 0.0;

			RB_Duration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RB_STRING, 1);
			RB_Intensity[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RB_STRING, 2);
			RB_UseDelay[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RB_STRING, 3);
			ReadSound(bossIdx, RB_STRING, 4, RB_BumpSound[clientIdx]);
			RB_ZLift[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, RB_STRING, 5);
			
			if (RB_ZLift[clientIdx] <= 0.0)
				RB_ZLift[clientIdx] = 275.0;
		}

		if ((MO_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, MO_STRING)) == true)
		{
			PluginActiveThisRound = true;
			MO_ActiveThisRound = true;
			MO_ActiveUntil[clientIdx] = FAR_FUTURE;

			// must precache the swap model now
			int modelIdx = ReadModelToInt(bossIdx, MO_STRING, 2);
			if (modelIdx <= 0)
			{
				PrintToServer("[sarysamods2] WARNING:: Failed to precache model for %s. Disabling rage.", MO_STRING);
				MO_CanUse[clientIdx] = false;
			}
			else // store the normal model
				GetEntPropString(clientIdx, Prop_Data, "m_ModelName", MO_NormalModel[clientIdx], MAX_MODEL_FILE_LENGTH);
		}

		// also precache model for reskinned melee now
		if ((RM_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, RM_STRING)) == true)
		{
			PluginActiveThisRound = true;
			RM_ActiveThisRound = true;
			
			RM_ModelIndex[clientIdx] = ReadModelToInt(bossIdx, RM_STRING, 1);
			if (RM_ModelIndex[clientIdx] == -1)
			{
				PrintToServer("[sarysamods2] WARNING:: Failed to precache model for %s, disabling this round.", RM_STRING);
				RM_CanUse[clientIdx] = false;
			}
		}
	}
	
	// add altered sounds hooks if applicable
	if (AS_ActiveThisRound)
	{
		HookEvent("player_death", AS_PlayerDeath, EventHookMode_Post);
		//HookEvent("air_dash", AS_PlayerDoubleJump, EventHookMode_Post); // no way, this event never goes off
		//HookEvent("player_jump", AS_PlayerJump, EventHookMode_Post); // nope.avi, need to use more convoluted detection
		//HookEvent("player_shoot", AS_PlayerShoot, EventHookMode_Post); // ach no, no shoot detectin' for ye wee lassie
	}
	
	// post-round start inits
	CreateTimer(0.3, Timer_PostRoundStartInits, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_PostRoundStartInits(Handle timer)
{
	if (!RoundInProgress)
		return Plugin_Stop; // user must have suicided very quickly
		
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (!IsLivingPlayer(clientIdx) || GetClientTeam(clientIdx) != BossTeam)
			continue;
		int bossIdx = FF2_GetBossIndex(clientIdx);
		if (bossIdx < 0)
			continue;

		// inits for gun with custom projectile
		if ((CPG_CanUse[clientIdx] = FF2_HasAbility(bossIdx, this_plugin_name, CPG_STRING)) == true)
		{
			PluginActiveThisRound = true;
			CPG_ActiveThisRound = true;
		
			CPG_RageDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CPG_STRING, 1);
			CPG_ModelIndex[clientIdx] = ReadModelToInt(bossIdx, CPG_STRING, 2);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CPG_STRING, 11, CPG_EntityClassname[clientIdx], MAX_ENTITY_CLASSNAME_LENGTH);
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CPG_STRING, 12, CPG_EffectOnHit[clientIdx], MAX_EFFECT_NAME_LENGTH);
			CPG_EffectDuration[clientIdx] = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, CPG_STRING, 13);
			CPG_DamageFlagOverride[clientIdx] = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CPG_STRING, 14);
			CPG_BlockHeadshots[clientIdx] = (FF2_GetAbilityArgument(bossIdx, this_plugin_name, CPG_STRING, 15) == 1);
			
			if (CPG_ModelIndex[clientIdx] != -1 && strlen(CPG_EntityClassname[clientIdx]) > 3 && PRINT_DEBUG_INFO)
				PrintToServer("[sarysamods2] Will be reskinning projectiles for %d this round to modelidx=%d", clientIdx, CPG_ModelIndex[clientIdx]);
			else if (PRINT_DEBUG_INFO)
				PrintToServer("[sarysamods2] Will only be weapon swapping during rage for %d with no projectile model changes.", clientIdx);
				
			// switch melee weapon to avoid bonk boy glitch
			CPG_SwitchToMelee(clientIdx);
		}
	}
	
	if (CPG_ActiveThisRound)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
				SDKHook(clientIdx, SDKHook_OnTakeDamage, CPG_OnTakeDamage);
		}
	}
	
	return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	// round is no longer active
	RoundInProgress = false;
	
	// various cleanup
	if (BO_ActiveThisRound)
	{
		BO_ActiveThisRound = false;
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			// boss overlay
			if (BO_CanUse[clientIdx] && IsClientInGame(clientIdx))
			{
				BO_CanUse[clientIdx] = false;
				BO_RemoveBossOverlay(clientIdx);
				BO_SetHUDHideLevel(clientIdx, 0);
			}
		}
	}

	// unhook altered sounds events
	if (AS_ActiveThisRound)
	{
		AS_ActiveThisRound = false;
		UnhookEvent("player_death", AS_PlayerDeath, EventHookMode_Post);
	}
	
	// remove CPG damage hooks
	if (CPG_ActiveThisRound)
	{
		CPG_ActiveThisRound = false;
		
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
				SDKHook(clientIdx, SDKHook_OnTakeDamage, CPG_OnTakeDamage);
		}
	}

	// fix gravity, to be safe just fix it wildly.
	if (BG_ActiveThisRound)
	{
		BG_ActiveThisRound = false;
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (IsClientInGame(clientIdx))
				SetEntityGravity(clientIdx, 1.0);
		}
	}
}

public Action FF2_OnAbility2(int bossIdx, const char[] plugin_name, const char[] ability_name, int status)
{
	// don't execute any of this after round is done.
	// you're just asking for bugs.
	if (!RoundInProgress)
		return Plugin_Continue;

	// strictly enforce the correct plugin is specified.
	// these were working earlier with no specification...eep.
	if (strcmp(plugin_name, this_plugin_name))
		return Plugin_Continue;

	if (PRINT_DEBUG_INFO)
		PrintToServer("[sarysamods2] FF2_OnAbility2(%d, %s, %s, %d)", bossIdx, plugin_name, ability_name, status);
		
	if (!strcmp(ability_name, BO_STRING))
		Rage_BossOverlay(bossIdx);
	else if (!strcmp(ability_name, CPG_STRING))
		Rage_CustomProjectileGun(bossIdx);
	else if (!strcmp(ability_name, BG_STRING))
		Rage_BossGravity(ability_name, bossIdx);
	else if (!strcmp(ability_name, AS_STRING))
		Rage_AlteredSounds(bossIdx);
	else if (!strcmp(ability_name, RB_STRING))
		Rage_ReloadBump(bossIdx);
	else if (!strcmp(ability_name, MO_STRING))
		Rage_ModelOverride(ability_name, bossIdx);
		
	return Plugin_Continue;
}

/**
 * Boss Overlay - Overlay that only boss sees.
 */
void BO_SetHUDHideLevel(int clientIdx, int hideLevel)
{
	if (!IsClientInGame(clientIdx))
		return;

	if (hideLevel >= 0 && hideLevel < NUM_HUD_HIDE_LEVELS)
		SetEntProp(clientIdx, Prop_Send, "m_iHideHUD", HUD_HIDE_LEVELS[hideLevel]);
		
	if (hideLevel > 1)
		FF2_SetFF2flags(clientIdx, FF2_GetFF2flags(clientIdx) | FF2FLAG_HUDDISABLED);
	else
		FF2_SetFF2flags(clientIdx, FF2_GetFF2flags(clientIdx) & (~FF2FLAG_HUDDISABLED));
}

void BO_RemoveBossOverlay(int clientIdx)
{
	int flags = GetCommandFlags("r_screenoverlay");
	SetCommandFlags("r_screenoverlay", flags & ~FCVAR_CHEAT);
	ClientCommand(clientIdx, "r_screenoverlay \"\"");
	SetCommandFlags("r_screenoverlay", flags);
}

void BO_SetBossOverlay(int clientIdx)
{
	int bossIdx = FF2_GetBossIndex(clientIdx);
	if (bossIdx < 0)
	{
		BO_CanUse[clientIdx] = false;
		BO_RemoveBossOverlay(clientIdx);
		return;
	}

	static char materialFile[MAX_MATERIAL_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, BO_STRING, 2, materialFile, MAX_MATERIAL_FILE_LENGTH);

	// display the int overlay to the boss
	int flags = GetCommandFlags("r_screenoverlay");
	SetCommandFlags("r_screenoverlay", flags & ~FCVAR_CHEAT);
	if (BO_FrameCount[clientIdx] <= 1)
		ClientCommand(clientIdx, "r_screenoverlay \"%s\"", materialFile);
	else
		ClientCommand(clientIdx, "r_screenoverlay \"%s%d\"", materialFile, BO_CurrentFrame[clientIdx] + 1);
	SetCommandFlags("r_screenoverlay", flags);
}

public void BO_EndRage(int clientIdx)
{
	BO_RemoveBossOverlay(clientIdx);
	BO_SetHUDHideLevel(clientIdx, 0);
	BO_ActiveUntil[clientIdx] = FAR_FUTURE;
	BO_RestoreOverlayAt[clientIdx] = FAR_FUTURE;
	BO_IncrementOverlayAt[clientIdx] = FAR_FUTURE;
}

public void BO_Tick(int clientIdx, float curTime)
{
	if (curTime >= BO_ActiveUntil[clientIdx])
		BO_EndRage(clientIdx);
	else if (curTime >= BO_RestoreOverlayAt[clientIdx])
	{
		BO_SetBossOverlay(clientIdx);
		BO_RestoreOverlayAt[clientIdx] += 0.5;
	}
	else if (curTime >= BO_IncrementOverlayAt[clientIdx])
	{
		BO_CurrentFrame[clientIdx]++;
		BO_CurrentFrame[clientIdx] = BO_CurrentFrame[clientIdx] % BO_FrameCount[clientIdx];
		BO_SetBossOverlay(clientIdx);
		BO_IncrementOverlayAt[clientIdx] += BO_IncrementInterval[clientIdx];
	}
}

void Rage_BossOverlay(int bossIdx)
{
	// get our duration and the overlay command
	int clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	if (BO_ActiveUntil[clientIdx] == FAR_FUTURE) // in case of ragespam, don't reinit these
	{
		// set HUD hide level
		BO_SetHUDHideLevel(clientIdx, BO_HUDHideLevel[clientIdx]);
	
		// get the ball rolling
		if (BO_FrameCount[clientIdx] > 1)
		{
			BO_RestoreOverlayAt[clientIdx] = GetEngineTime() + 0.5;
			BO_IncrementOverlayAt[clientIdx] = GetEngineTime();
			BO_CurrentFrame[clientIdx] = BO_FrameCount[clientIdx] - 1;
			BO_RestoreOverlayAt[clientIdx] = FAR_FUTURE;
		}
		else
		{
			BO_RestoreOverlayAt[clientIdx] = GetEngineTime();
			BO_IncrementOverlayAt[clientIdx] = FAR_FUTURE;
		}
	}
	BO_ActiveUntil[clientIdx] = GetEngineTime() + BO_Duration[clientIdx];
}

/**
 * Any projectile weapon but with a replacement model for the projectile.
 */
public Action CPG_OnTakeDamage(int victim, int& attacker, int& inflictor, 
							float& damage, int& damagetype, int& weapon,
							float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsLivingPlayer(attacker) || GetClientTeam(attacker) != BossTeam)
		return Plugin_Continue;

	Action result = Plugin_Continue;
	if (GetClientTeam(attacker) == BossTeam && IsValidEntity(inflictor))
	{
		// attach custom particle to victim
		if (!IsEmptyString(CPG_EffectOnHit[attacker]))
		{
			static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
			GetEntityClassname(inflictor, classname, MAX_ENTITY_CLASSNAME_LENGTH);
			if (!strcmp(CPG_EntityClassname[attacker], classname))
			{
				int particle = AttachParticle(victim, CPG_EffectOnHit[attacker], 75.0);
				if (IsValidEntity(particle))
					CreateTimer(CPG_EffectDuration[attacker], Timer_RemoveEntity, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		
		// override damage flags
		if (CPG_DamageFlagOverride[attacker] != -1 && inflictor != attacker)
		{
			damagetype = CPG_DamageFlagOverride[attacker];
			result = Plugin_Changed;
		}
		
		// block headshots
		if (CPG_CanUse[attacker] && damagecustom == TF_CUSTOM_HEADSHOT && CPG_BlockHeadshots[attacker])
		{
			//damagetype &= ~DMG_CRIT;
			damage /= 3.0; // FFS these headshots...I swear...
			result = Plugin_Changed;
		}
	}
	
	return result;
}
 
void CPG_SwitchToMelee(int clientIdx)
{
	if (!IsClientInGame(clientIdx) || !IsPlayerAlive(clientIdx))
		return;
		
	int bossIdx = FF2_GetBossIndex(clientIdx);
	
	// switch the user's melee weapon now, to avoid the Bonk Boy problem
	static char weaponName[MAX_WEAPON_NAME_LENGTH];
	static char weaponArgs[MAX_WEAPON_ARG_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CPG_STRING, 7, weaponName, MAX_WEAPON_NAME_LENGTH);
	int weaponIdx = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CPG_STRING, 8);
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CPG_STRING, 9, weaponArgs, MAX_WEAPON_ARG_LENGTH);
	bool weaponVisibility = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CPG_STRING, 10) != 0;
	SwitchWeapon(clientIdx, weaponName, weaponIdx, weaponArgs, weaponVisibility);
}

void CPG_SwitchToRanged(int clientIdx)
{
	if (!IsClientInGame(clientIdx) || !IsPlayerAlive(clientIdx))
		return;
		
	int bossIdx = FF2_GetBossIndex(clientIdx);
	
	// switch the user's melee weapon now, to avoid the Bonk Boy problem
	static char weaponName[MAX_WEAPON_NAME_LENGTH];
	static char weaponArgs[MAX_WEAPON_ARG_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CPG_STRING, 3, weaponName, MAX_WEAPON_NAME_LENGTH);
	int weaponIdx = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CPG_STRING, 4);
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, CPG_STRING, 5, weaponArgs, MAX_WEAPON_ARG_LENGTH);
	bool weaponVisibility = FF2_GetAbilityArgument(bossIdx, this_plugin_name, CPG_STRING, 6) != 0;
	int weapon = SwitchWeapon(clientIdx, weaponName, weaponIdx, weaponArgs, weaponVisibility);
	
	// set reserve ammo to 0, to stop the wigging out which is apparently a int problem with overfilled weapons
	if (IsValidEntity(weapon))
	{
		int offset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1);
		if (offset >= 0)
			SetEntProp(clientIdx, Prop_Send, "m_iAmmo", 0, 4, offset);
	}
}

public void CPG_OnEntityCreated(int entity, const char[] classname)
{
	for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
	{
		if (CPG_CanUse[clientIdx] && CPG_ActiveUntil[clientIdx] != FAR_FUTURE && strcmp(CPG_EntityClassname[clientIdx], classname) == 0)
			CPG_TestNextFrame[clientIdx] = true;
	}
}

public void CPG_Tick(int clientIdx, float curTime)
{
	// only test projectiles of interesting type when it's necessary
	if (CPG_TestNextFrame[clientIdx])
	{
		CPG_TestNextFrame[clientIdx] = false;
		
		int projectileEntity = MAX_PLAYERS;
		while ((projectileEntity = FindEntityByClassname(projectileEntity, CPG_EntityClassname[clientIdx])) != -1)
		{
			int owner = GetEntPropEnt(projectileEntity, Prop_Send, "m_hOwnerEntity");
			if (owner == clientIdx && CPG_ModelIndex[clientIdx] != -1)
			{
				if (GetEntProp(projectileEntity, Prop_Send, "m_nModelIndex") != CPG_ModelIndex[clientIdx])
					SetEntProp(projectileEntity, Prop_Send, "m_nModelIndex", CPG_ModelIndex[clientIdx]);
			}
		}
	}
	
	// is it time to end the rage?
	if (curTime >= CPG_ActiveUntil[clientIdx])
	{
		CPG_ActiveUntil[clientIdx] = FAR_FUTURE;
		CPG_SwitchToMelee(clientIdx);
		//ReskinWeapon(clientIdx);
	}
}

void Rage_CustomProjectileGun(int bossIdx)
{
	int clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	// switch weapon, but only if necessary
	if (CPG_ActiveUntil[clientIdx] == FAR_FUTURE)
		CPG_SwitchToRanged(clientIdx);
	
	// get the ball rolling
	CPG_ActiveUntil[clientIdx] = GetEngineTime() + CPG_RageDuration[clientIdx];
}

/**
 * Change to boss gravity
 */
public void BG_Tick(int clientIdx, float curTime)
{
	if (curTime >= BG_ActiveUntil[clientIdx])
	{
		BG_ActiveUntil[clientIdx] = FAR_FUTURE;
		SetEntityGravity(clientIdx, 1.0);
		DW_SetDefaultGravity(clientIdx, 1.0);
	}
}

void Rage_BossGravity(const char[] ability_name, int bossIdx)
{
	// get our variables
	float duration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 1);
	float factor = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 2);
	int clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	// change gravity only if necessary
	if (BG_ActiveUntil[clientIdx] == FAR_FUTURE)
	{
		SetEntityGravity(clientIdx, factor);
		DW_SetDefaultGravity(clientIdx, factor);
	}
	BG_ActiveUntil[clientIdx] = GetEngineTime() + duration;
}

/**
 * Altered Sounds - Custom sound effects for events like jump, fire, etc.
 */
public void AS_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int killer = GetClientOfUserId(event.GetInt("attacker"));
	
	if (victim <= 0 || killer <= 0 || killer >= MAX_PLAYERS)
		return;
	
	// for whatever reason, the volume for this sound and PlaySoundLocal is terrible
	// so I need to do a manual pseudo-ambient sound that ignores obstacles
	if ((AS_ActiveUntil[killer] != FAR_FUTURE || AS_RageNotRequired[killer]) && strlen(AS_KillSound[killer]) > 3)
		PseudoAmbientSound(victim, AS_KillSound[killer]);
}

public void AS_OnPlayerRunCmd(int clientIdx, int buttons, float curTime)
{
	if (curTime >= AS_ActiveUntil[clientIdx])
		AS_ActiveUntil[clientIdx] = FAR_FUTURE;

	if (AS_ActiveUntil[clientIdx] != FAR_FUTURE || AS_RageNotRequired[clientIdx])
	{
		int airDashCount = GetEntProp(clientIdx, Prop_Send, "m_iAirDash");
		if ((buttons & IN_JUMP) && (GetEntityFlags(clientIdx) & FL_ONGROUND) && !(GetEntityFlags(clientIdx) & (FL_INWATER | FL_SWIM)) && !AS_JumpWasDown[clientIdx])
		{
			// ensure player is not in an invalid state when they hit jump
			// NOTE: I am not handling the case where heavy is using minigun!
			// If you want to expand this beyond typical hale use, you can figure that out yourself.
			if (!(buttons & IN_DUCK) && !TF2_IsPlayerInCondition(clientIdx, TFCond_Dazed))
				if (strlen(AS_JumpSound[clientIdx]) > 3)
					PlaySoundLocal(clientIdx, AS_JumpSound[clientIdx], true);
		}
		else if (airDashCount > AS_AirDashCount[clientIdx])
		{
			if (strlen(AS_JumpSound[clientIdx]) > 3)
				PlaySoundLocal(clientIdx, AS_JumpSound[clientIdx], true);
		}
		AS_JumpWasDown[clientIdx] = (buttons & IN_JUMP) != 0;
		AS_AirDashCount[clientIdx] = airDashCount;

		// determine if they attacked by seeing if their current weapon is capable of attacking
		// though me from the past determined it was necessary to play the sound one frame late. I'll go with it.
		if ((buttons & IN_ATTACK) && strlen(AS_FireSound[clientIdx]) > 3)
		{
			// find a weapon, non-melee only!
			int weapon = GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon");
			if (weapon != -1)
			{
				float nextTime = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
				if (AS_LastFireTimeRecorded[clientIdx] != nextTime && AS_AttackWasDown[clientIdx] && AS_FireSoundSanityTimer[clientIdx] < GetEngineTime())
				{
					PlaySoundLocal(clientIdx, AS_FireSound[clientIdx], true);
					AS_FireSoundSanityTimer[clientIdx] = GetEngineTime() + 0.33;
				}
				AS_LastFireTimeRecorded[clientIdx] = nextTime;
			}
		}
		AS_AttackWasDown[clientIdx] = (buttons & IN_ATTACK) != 0;
	}
}

void Rage_AlteredSounds(int bossIdx)
{
	// the sounds themselves are already grabbed, so we only need the duration
	int clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));

	if (AS_RageNotRequired[clientIdx])
		return;

	// inits, only necessary if not ragespam
	if (AS_ActiveUntil[clientIdx] == FAR_FUTURE)
	{
		AS_JumpWasDown[clientIdx] = (GetClientButtons(clientIdx) & IN_JUMP) != 0;
		AS_AttackWasDown[clientIdx] = (GetClientButtons(clientIdx) & IN_ATTACK) != 0;
		AS_LastFireTimeRecorded[clientIdx] = 0.0;
		AS_AirDashCount[clientIdx] = GetEntProp(clientIdx, Prop_Send, "m_iAirDash");
	}
	AS_ActiveUntil[clientIdx] = GetEngineTime() + AS_Duration[clientIdx];
}

/**
 * Reload bump
 */
public void RB_OnPlayerRunCmd(int clientIdx, int buttons, float curTime)
{
	if (curTime >= RB_ActiveUntil[clientIdx])
	{
		RB_ActiveUntil[clientIdx] = FAR_FUTURE;
	}
	else if (RB_ActiveUntil[clientIdx] != FAR_FUTURE)
	{
		if ((buttons & IN_RELOAD) != 0 && RB_CanBumpAgainAt[clientIdx] <= GetEngineTime())
		{
			// yeah this is probably more complicated than it should be, alas I don't know how
			// to just use the client's eye angles to get my desired result
			static float bumpTarget[3];
			static float startPoint[3];
			static float eyeAngles[3];
			static float endPoint[3];
			GetClientEyePosition(clientIdx, startPoint);
			GetClientEyeAngles(clientIdx, eyeAngles);
			Handle trace = TR_TraceRayFilterEx(startPoint, eyeAngles, (CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_GRATE), RayType_Infinite, TraceWallsOnly);
			if (TR_DidHit(trace))
			{
				TR_GetEndPosition(endPoint, trace);

				MakeVectorFromPoints(startPoint, endPoint, bumpTarget);
				NormalizeVector(bumpTarget, bumpTarget);
				float intensity = 1200.0;

				// apply the user supplied modifier
				intensity *= RB_Intensity[clientIdx];
				
				// now scale our vector
				ScaleVector(bumpTarget, intensity); // can opt to factor distance

				// ensure user has the minimum lift they need to get off the ground
				if (GetEntityFlags(clientIdx) & FL_ONGROUND)
					if (bumpTarget[2] < RB_ZLift[clientIdx])
						bumpTarget[2] = RB_ZLift[clientIdx];

				// and push the hale
				TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, NULL_VECTOR); // cancel existing momentum, a common trope associated with air slide
				TeleportEntity(clientIdx, NULL_VECTOR, NULL_VECTOR, bumpTarget);
				
				// play sound
				if (strlen(RB_BumpSound[clientIdx]) > 3)
					PlaySoundLocal(clientIdx, RB_BumpSound[clientIdx], true);

				// set time for next bump
				RB_CanBumpAgainAt[clientIdx] = GetEngineTime() + RB_UseDelay[clientIdx];
			}
			else
				PrintToServer("[sarysamods2] Error: Indiscriminate trace found nothing? Shouldn't be possible.");
			
			CloseHandle(trace);
		}
	}
}

void Rage_ReloadBump(int bossIdx)
{
	// bump the user forward when they hit reload
	int clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	if (RB_ActiveUntil[clientIdx] == FAR_FUTURE)
		RB_CanBumpAgainAt[clientIdx] = GetEngineTime();
	RB_ActiveUntil[clientIdx] = GetEngineTime() + RB_Duration[clientIdx];
}

/**
 * Model override
 */
public void MO_Tick(int clientIdx, float curTime)
{
	if (curTime >= MO_ActiveUntil[clientIdx])
	{
		MO_ActiveUntil[clientIdx] = FAR_FUTURE;

		int bossIdx = FF2_GetBossIndex(clientIdx);
		if (bossIdx >= 0)
		{
			SwapModel(clientIdx, MO_NormalModel[clientIdx]);
		
			static char particleName[MAX_EFFECT_NAME_LENGTH];
			FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MO_STRING, 4, particleName, MAX_EFFECT_NAME_LENGTH);
			if (!IsEmptyString(particleName))
				ParticleEffect(clientIdx, particleName, 0.1);
		}
	}
}

void Rage_ModelOverride(const char[] ability_name, int bossIdx)
{
	float duration = FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, ability_name, 1);
	int clientIdx = GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	
	if (!MO_CanUse[clientIdx])
		return;
		
	// change model and particle effect only if necessary
	if (MO_ActiveUntil[clientIdx] == FAR_FUTURE)
	{
		// model
		static char modelFile[MAX_MODEL_FILE_LENGTH];
		ReadModel(bossIdx, MO_STRING, 2, modelFile);
		SwapModel(clientIdx, modelFile);
		
		// particle effect
		static char particleName[MAX_EFFECT_NAME_LENGTH];
		FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, MO_STRING, 3, particleName, MAX_EFFECT_NAME_LENGTH);
		if (!IsEmptyString(particleName))
			ParticleEffect(clientIdx, particleName, 0.1);
	}
	MO_ActiveUntil[clientIdx] = GetEngineTime() + duration;
}

/**
 * Reskinned melee -- just leaving it around for the unlikely chance Valve removes the restrictions.
 */
public void ReskinMelee(int clientIdx)
{
	int entity = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Melee);
	if (entity == -1)
		return;

	// only perform if necessary. source engine PROBABLY has code to avoid spamming unchanged network variables,
	// but this is the only way I can be certain.
	if (GetEntProp(entity, Prop_Send, "m_iWorldModelIndex") != RM_ModelIndex[clientIdx])
	{
		SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", RM_ModelIndex[clientIdx]);
		//SetEntProp(entity, Prop_Send, "m_nModelIndex", RM_ModelIndex[clientIdx]);
		for (int i = 0; i < 4; i++)
			SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", RM_ModelIndex[clientIdx] , _, i);
	}
}

/**
 * OnGameFrame/OnPlayerRunCmd, with special guest OnEntityCreated
 */
public void OnGameFrame()
{
	if (!PluginActiveThisRound || !RoundInProgress)
		return;
	
	float curTime = GetEngineTime();
	
	if (BO_ActiveThisRound || CPG_ActiveThisRound || BG_ActiveThisRound || MO_ActiveThisRound || RM_ActiveThisRound)
	{
		for (int clientIdx = 1; clientIdx < MAX_PLAYERS; clientIdx++)
		{
			if (!IsLivingPlayer(clientIdx) || GetClientTeam(clientIdx) != BossTeam)
				continue;
				
			if (BO_CanUse[clientIdx])
				BO_Tick(clientIdx, curTime);
				
			if (CPG_CanUse[clientIdx])
				CPG_Tick(clientIdx, curTime);
				
			if (BG_CanUse[clientIdx])
				BG_Tick(clientIdx, curTime);
				
			if (MO_CanUse[clientIdx])
				MO_Tick(clientIdx, curTime);
				
			if (RM_CanUse[clientIdx])
				ReskinMelee(clientIdx);
		}
	}
}

// how much Z push is necessary to get off the ground for the "slide"
public Action OnPlayerRunCmd(int clientIdx, int& buttons, int& impulse, 
							float vel[3], float angles[3], int& weapon, 
							int &subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (!PluginActiveThisRound || !RoundInProgress)
		return Plugin_Continue;
	else if (!IsLivingPlayer(clientIdx) || GetClientTeam(clientIdx) != BossTeam)
		return Plugin_Continue;

	if (AS_ActiveThisRound && AS_CanUse[clientIdx])
		AS_OnPlayerRunCmd(clientIdx, buttons, GetEngineTime());
		
	if (RB_ActiveThisRound && RB_CanUse[clientIdx])
		RB_OnPlayerRunCmd(clientIdx, buttons, GetEngineTime());
	
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!PluginActiveThisRound || !RoundInProgress)
		return;
		
	if (CPG_ActiveThisRound)
		CPG_OnEntityCreated(entity, classname);
}

/**
 * Various reusable helper methods
 */
public bool TraceWallsOnly(int entity, int contentsMask)
{
	return !entity;
}
 
stock void ReadSound(int bossIdx, const char[] ability_name, int argInt, char[] soundFile)
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, soundFile, MAX_SOUND_FILE_LENGTH);
	if (strlen(soundFile) > 3)
		PrecacheSound(soundFile);
}

stock void ReadModel(int bossIdx, const char[] ability_name, int argInt, char[] modelFile)
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, modelFile, MAX_MODEL_FILE_LENGTH);
	if (strlen(modelFile) > 3)
		PrecacheModel(modelFile);
}
 
stock int ReadModelToInt(int bossIdx, const char[] ability_name, int argInt)
{
	static char modelFile[MAX_MODEL_FILE_LENGTH];
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, modelFile, MAX_MODEL_FILE_LENGTH);
	if (strlen(modelFile) > 3)
		return PrecacheModel(modelFile);
	return -1;
}
 
stock bool IsLivingPlayer(int clientIdx)
{
	if (clientIdx <= 0 || clientIdx >= MAX_PLAYERS)
		return false;
		
	return IsClientInGame(clientIdx) && IsPlayerAlive(clientIdx);
}

void PlaySoundLocal(int clientIdx, char[] soundPath, bool followPlayer = true)
{
	// play a speech sound that travels normally, local from the player.
	static float playerPos[3];
	GetClientEyePosition(clientIdx, playerPos);
	//PrintToServer("eye pos=%f,%f,%f     sound=%s", playerPos[0], playerPos[1], playerPos[2], soundPath);
	EmitAmbientSound(soundPath, playerPos, followPlayer ? clientIdx : SOUND_FROM_WORLD);
}

// this version ignores obstacles, use when conditions are making the above hard to hear
stock void PseudoAmbientSound(int clientIdx, char[] soundPath, int count=1, float radius=1000.0, bool skipSelf=false, bool skipDead=false, float volumeFactor=1.0)
{
	static float emitterPos[3];
	static float listenerPos[3];
	if (!IsLivingPlayer(clientIdx)) // updated 2015-01-16 to allow non-players...finally.
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", emitterPos);
	else
		GetClientEyePosition(clientIdx, emitterPos);
	for (int listener = 1; listener < MAX_PLAYERS; listener++)
	{
		if (!IsClientInGame(listener))
			continue;
		else if (skipSelf && listener == clientIdx)
			continue;
		else if (skipDead && !IsLivingPlayer(listener))
			continue;
			
		GetClientEyePosition(listener, listenerPos);
		float distance = GetVectorDistance(emitterPos, listenerPos);
		if (distance >= radius)
			continue;
		
		float volume = (radius - distance) / radius;
		if (volume <= 0.0)
			continue;
		else if (volume > 1.0)
		{
			PrintToServer("[sarysamods9] How the hell is volume greater than 1.0?");
			volume = 1.0;
		}
		
		for (int i = 0; i < count; i++)
			EmitSoundToClient(listener, soundPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume);
	}
}
 
int SwitchWeapon(int clientIdx, char[] weaponName, int weaponIdx, char[] weaponAttributes, bool visible)
{
	TF2_RemoveWeaponSlot(clientIdx, TFWeaponSlot_Primary);
	TF2_RemoveWeaponSlot(clientIdx, TFWeaponSlot_Secondary);
	TF2_RemoveWeaponSlot(clientIdx, TFWeaponSlot_Melee);
	int weapon = SpawnWeapon(clientIdx, weaponName, weaponIdx, 101, 5, weaponAttributes, visible);
	SetEntPropEnt(clientIdx, Prop_Data, "m_hActiveWeapon", weapon);
	return weapon;
}

void SwapModel(int clientIdx, const char[] model)
{
	// standard important check here...
	if (!IsClientInGame(clientIdx) || !IsPlayerAlive(clientIdx))
		return;
		
	SetVariantString(model);
	AcceptEntityInput(clientIdx, "SetCustomModel");
	SetEntProp(clientIdx, Prop_Send, "m_bUseClassAnimations", 1);
}

void ParticleEffect(int clientIdx, char[] effectName, float duration)
{
	if (strlen(effectName) < 3)
		return; // nothing to display
	if (duration == 0.0)
		duration = 0.1; // probably doesn't matter for this effect, I just don't feel comfortable passing 0 to a timer
		
	int particle = AttachParticle(clientIdx, effectName, 75.0);
	if (IsValidEntity(particle))
		CreateTimer(duration, Timer_RemoveEntity, EntIndexToEntRef(particle), TIMER_FLAG_NO_MAPCHANGE);
}

/**
 * Taken from default_abilities
 */
public Action Timer_RemoveEntity(Handle timer, any entid)
{
	int entity = EntRefToEntIndex(entid);
	if (IsValidEdict(entity) && entity > MaxClients)
		RemoveEntity(entity);
}

stock int AttachParticle(int entity, char[] particleType, float offset=0.0, bool attach=true)
{
	int particle = CreateEntityByName("info_particle_system");
	
	if (!IsValidEntity(particle))
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
	if (attach)
	{
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	}
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	return particle;
}

/**
 * CODE BELOW WAS TAKEN FROM ff2_1st_set_abilities, I TAKE NO CREDIT FOR IT
 * 'cept the small parts I added :P
 */
int SpawnWeapon(int clientIdx, char[] name, int index, int level, int quality, char[] attribute, bool visible = true)
{
	Handle weapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
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
		PrintToServer("[sarysamods2] Error: Invalid weapon spawned. client=%d name=%s idx=%d attr=%s", clientIdx, name, index, attribute);
		return -1;
	}

	int entity = TF2Items_GiveNamedItem(clientIdx, weapon);
	CloseHandle(weapon);
	EquipPlayerWeapon(clientIdx, entity);
	
	// sarysa addition
	if (!visible)
	{
		SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
		//for (int i = 0; i < 4; i++)
		//	SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", -1, _, i);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
	}
	
	return entity;
}
