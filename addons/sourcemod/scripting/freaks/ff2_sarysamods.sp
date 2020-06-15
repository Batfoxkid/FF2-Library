#include <sdkhooks>
#include <ff2_helper>
#include <ff2_ams2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

/**
 * A bunch of original code and others' tweaked code for mechanics related to my Cheese Sandwich boss.
 * Everything with "Delayable" in the name has an optional time delay. If it's 0 it executes immediately.
 *
 * OVERALL Known Issues:
 * - Single bosses have been tested thoroughly. Multi-bosses support was added on 2014-04-20 but 
 *	has only had limited testing.
 * - If you have the RTD mod installed on your server and non-engies can make sentry guns, search and remove if 
 *	check with TFClass_Engineer
 * - Don't time any of the delayables longer than it'd take between last end of round and next round respawn
 *
 *--------------------------------------------------------------------------------------------------------------
 * DelayableDamage: Damage in a radius with no visual effect, which allows a delay before execution.
 *	Credits: Took minor samples from phatrages and other minor sources while making this.
 *--------------------------------------------------------------------------------------------------------------
 * arg1	"delay"			"float"
 * arg2	"damage"		"float"
 * arg3	"radius"		"float"
 * arg4	"knockback"		"float"
 * arg5	"scale by dist"	"bool"
 * arg6	"z-lift"		"bool"
 *--------------------------------------------------------------------------------------------------------------
 *--------------------------------------------------------------------------------------------------------------
 *
 *
 *--------------------------------------------------------------------------------------------------------------
 * DelayableDamage: Damage in a radius with no visual effect, which allows a delay before execution.
 *	Credits: Took minor samples from phatrages and other minor sources while making this.
 *--------------------------------------------------------------------------------------------------------------
 * arg1	"alive to start"		"int"
 * arg2	"player rage per sec"	"float"
 *--------------------------------------------------------------------------------------------------------------
 *--------------------------------------------------------------------------------------------------------------
 *
 *
 *--------------------------------------------------------------------------------------------------------------
 * DelayableEarthquake: Display an earthquake to living non-hale players for a period, optionally play a sound.
 *	Credits: Ripped some functions straight from phatrages.
 *		 Took minor samples from phatrages and other minor sources while making this.
 *--------------------------------------------------------------------------------------------------------------
 * arg1 "delay"		"float"
 * arg2 "duration"	"float"
 * arg3 "radius"	"float"
 * arg4 "amplitude"	"float"
 * arg5 "frequency"	"float"
 * arg6 "air shake" "bool"
 * arg7 "sound"		"string"
 *--------------------------------------------------------------------------------------------------------------
 *--------------------------------------------------------------------------------------------------------------
 *
 *
 *--------------------------------------------------------------------------------------------------------------
 * DelayableBuildingDestruction: Destroys all buildings of specified types except the ones the engie is holding.
 *--------------------------------------------------------------------------------------------------------------
 *--------------------------------------------------------------------------------------------------------------
 * arg1 "delay"			"float"
 * arg2 "sentries"		"bool"
 * arg3 "dispenser" 	"bool"
 * arg4 "teleporters" 	"bool"
 * arg5 "save by carry" "bool"
 * arg6 "radius"		"float"
 *--------------------------------------------------------------------------------------------------------------
 *--------------------------------------------------------------------------------------------------------------
 *
 *
 *--------------------------------------------------------------------------------------------------------------
 * DelayableParticleEffect: Display a particle effect on all players in a radius for N seconds.
 *	Credits: Took some of the code used when sentries are raged.
 *--------------------------------------------------------------------------------------------------------------
 *--------------------------------------------------------------------------------------------------------------
 * arg1 "delay"		"float"
 * arg2 "duration"	"float"
 * arg3 "radius"	"float"
 * arg4 "particle"	"string"
 *--------------------------------------------------------------------------------------------------------------
 *--------------------------------------------------------------------------------------------------------------
 *
 *
 *--------------------------------------------------------------------------------------------------------------
 * Airblast Immunity: Airblast immunity for N seconds.
 *--------------------------------------------------------------------------------------------------------------
 *
 * arg1 "duration"		"float"
 * arg2 "incldue uber"	"bool"
 *--------------------------------------------------------------------------------------------------------------
 *--------------------------------------------------------------------------------------------------------------
 *
 *
 *--------------------------------------------------------------------------------------------------------------
 * Mapwide Sound: And you thought the above was reinventing the wheel. Plays a map-wide 
 * sound on rage, instead of the standard local rage sound.
 *--------------------------------------------------------------------------------------------------------------
 * arg1 "sound"		"string"
 *--------------------------------------------------------------------------------------------------------------
 *--------------------------------------------------------------------------------------------------------------
 *
 *--------------------------------------------------------------------------------------------------------------
 * ======= Revised on 2015-03-20, with plenty of opportunity to laugh at my old work from 2014-03-2X ==========
 *--------------------------------------------------------------------------------------------------------------
 * ================ Rework on 2020-06-09 by 01Pollux, improvement and migration to AMS2 =======================
 *--------------------------------------------------------------------------------------------------------------
 */

enum struct iPlayerInfo {
	int iAlives;
	int iBosses;
	void Update(int p, int b) {
		this.iAlives = p;
		this.iBosses = b;
	}
}
iPlayerInfo infos;

enum ShakeCommand_t
{
	SHAKE_START,			// Starts the screen shake for all players within the radius.
	SHAKE_STOP,				// Stops the screen shake for all players within the radius.
	SHAKE_AMPLITUDE,		// Modifies the amplitude of an active screen shake for all players within the radius.
	SHAKE_FREQUENCY,		// Modifies the frequency of an active screen shake for all players within the radius.
	SHAKE_START_RUMBLEONLY,	// Starts a shake effect that only rumbles the controller, no screen effect.
	SHAKE_START_NORUMBLE	// Starts a shake that does NOT rumble the controller.
};

bool AIActive;
float AI_EndsAt[MAXCLIENTS];

bool DDActive;
float DD_ExecuteRageAt[MAXCLIENTS];

bool DEActive;
float DE_ExecuteRageAt[MAXCLIENTS];

bool DBDActive;
float DBD_ExecuteRageAt[MAXCLIENTS];

bool DPEActive;
float DPE_ExecuteRageAt[MAXCLIENTS];

bool SERGActive;
int SERG_PlayersAliveToStart[MAXCLIENTS];
float SERG_OnePlayerRPS[MAXCLIENTS];
float SERG_flNextThink[MAXCLIENTS];

#define PLUGIN_EXISTS AIActive || DDActive || DEActive || DBDActive || DPEActive || SERGActive

public Plugin myinfo = {
	name = "Freak Fortress 2: sarysa's mods",
	author = "sarysa, 01Pollux",
	version = "1.1.0",
};
	
public void OnPluginStart2()
{
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void FF2AMS_PreRoundStart(int client)
{
	FF2Prep player = FF2Prep(client);
	if(player.HasAbility(FAST_REG(rage_delayable_particle_effect)) && player.GetArgI(FAST_REG(rage_delayable_particle_effect), "ams", .def = 1) == 1) {
		if(!AMS_REG(client)(rage_delayable_particle_effect.PE)) {
			return;
		}
	}
	if(player.HasAbility(FAST_REG(rage_delayable_building_destruction)) && player.GetArgI(FAST_REG(rage_delayable_building_destruction), "ams", .def = 1) == 1) {
		if(!AMS_REG(client)(rage_delayable_building_destruction.BD)) {
			return;
		}
	}
	if(player.HasAbility(FAST_REG(rage_delayable_earthquake)) && player.GetArgI(FAST_REG(rage_delayable_earthquake), "ams", .def = 1) == 1) {
		if(!AMS_REG(client)(rage_delayable_earthquake.DE)) {
			return;
		}
	}
	if(player.HasAbility(FAST_REG(rage_delayable_damage)) && player.GetArgI(FAST_REG(rage_delayable_damage), "ams", .def = 1) == 1) {
		if(!AMS_REG(client)(rage_delayable_damage.DD)) {
			return;
		}
	}
	if(player.HasAbility(FAST_REG(rage_airblast_immunity)) && player.GetArgI(FAST_REG(rage_airblast_immunity), "ams", .def = 1) == 1) {
		if(!AMS_REG(client)(rage_airblast_immunity.AI)) {
			return;
		}
	}
}

public Action Event_RoundStart(Event event,const char[] name, bool dontBroadcast)
{
	FF2Prep player;
	int client;
	for(int i; ; i++) {
		player = FF2Prep(i, false);
		client = player.Index;
		if(!client) {
			break;
		}
		
		if(player.HasAbility(FAST_REG(ff2_scaled_endgame_rage_gain))) {
			SERGActive = true;
			SERG_PlayersAliveToStart[client] = player.GetArgI(FAST_REG(ff2_scaled_endgame_rage_gain), "alive to start", 1, 5);
			SERG_OnePlayerRPS[client] = player.GetArgF(FAST_REG(ff2_scaled_endgame_rage_gain), "player rage per sec", 2, 5.0);
			SDKHook(client, SDKHook_PostThinkPost, SERG_ThinkPost);
		}
		
		if(player.HasAbility(FAST_REG(rage_delayable_damage))) {
			DDActive = true;
		}
		
		if(player.HasAbility(FAST_REG(rage_delayable_earthquake))) {
			DEActive = true;
		}
		
		if(player.HasAbility(FAST_REG(rage_delayable_building_destruction))) {
			DBDActive = true;
		}
		
		if(player.HasAbility(FAST_REG(rage_delayable_particle_effect))) {
			DPEActive = true;
		}
	}
}

public Action Event_RoundEnd(Event event,const char[] name, bool dontBroadcast)
{
	if(PLUGIN_EXISTS) {
		FF2Prep player;
		int client;
		for(int i; ; i++) {
			player = FF2Prep(i, false);
			client = player.Index;
			if(!client) {
				break;
			}
			
			if(SERGActive) {
				SDKUnhook(client, SDKHook_PostThinkPost, SERG_ThinkPost);
			}
			
			if(DDActive) {
				SDKUnhook(client, SDKHook_PostThinkPost, DD_ThinkPost);
			}
			
			if(DEActive) {
				SDKUnhook(client, SDKHook_PostThinkPost, DE_ThinkPost);
			}
			
			if(DBDActive) {
				SDKUnhook(client, SDKHook_PostThinkPost, DBD_ThinkPost);
			}
			
			if(DPEActive) {
				SDKUnhook(client, SDKHook_PostThinkPost, DPE_ThinkPost);
			}
			
			if(AIActive) {
				SDKUnhook(client, SDKHook_PostThinkPost, AI_ThinkPost);
			}
			
		}
		SERGActive = DDActive = AIActive = DEActive = DBDActive = DPEActive = false;
	}
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	// I'm allowing this to happen after hale wins. playing rage sounds after winning is a time-honored tradition. :D
	if (!strcmp(ability_name, "rage_mapwide_sound_sarysamods"))
	{
		FF2Prep player = FF2Prep(boss, false);
		static char soundFile[128];
		if (!player.GetArgS(FAST_REG(rage_mapwide_sound_sarysamods), "sound", 1, soundFile, sizeof(soundFile)))
			EmitSoundToAll(soundFile);
	}

	if (!IsRoundActive())
		return Plugin_Continue;

	if (!strcmp(ability_name, "rage_delayable_damage"))
		Rage_DelayableDamage(boss);
	else if (!strcmp(ability_name, "rage_delayable_earthquake"))
		Rage_DelayableEarthquake(boss);
	else if (!strcmp(ability_name, "rage_delayable_building_destruction"))
		Rage_DelayableBuildingDestruction(boss);
	else if (!strcmp(ability_name, "rage_delayable_particle_effect"))
		Rage_DelayableParticleEffect(boss);
	else if (!strcmp(ability_name, "rage_airblast_immunity"))
		Rage_AirblastImmunity(boss);
		
	return Plugin_Continue;
}

public void FF2_OnAlivePlayersChanged(int players, int bosses)
{
	infos.Update(players, bosses);
}

public void PE_Invoke(int client, int index)
{
	Rage_DelayableParticleEffect(ClientToBoss(client));
}

public void BD_Invoke(int client, int index)
{
	Rage_DelayableBuildingDestruction(ClientToBoss(client));
}

public void DE_Invoke(int client, int index)
{
	Rage_DelayableEarthquake(ClientToBoss(client));
}

public void DD_Invoke(int client, int index)
{
	Rage_DelayableDamage(ClientToBoss(client));
}

public void AI_Invoke(int client, int index)
{
	Rage_AirblastImmunity(ClientToBoss(client));
}

/**
 * Airblast Immunity (fun fact, in March 2014 I actually made this as a standalone ability. lol)
 */
public void AI_ThinkPost(int client)
{
	if(AI_EndsAt[client] >= GetGameTime()) {
		AI_EndRage(client);
		SDKUnhook(client, SDKHook_PostThinkPost, DPE_ThinkPost);
	}
}

public void Rage_AirblastImmunity(int bossIdx)
{
	FF2Prep player = FF2Prep(bossIdx, false);
	float duration = player.GetArgF(FAST_REG(rage_airblast_immunity), "duration", 1, 7.5);
	bool includeUber = player.GetArgI(FAST_REG(rage_airblast_immunity), "include uber", 2, 1) != 0;
	int client = BossToClient(bossIdx);
	
	if(AI_EndsAt[client] <= GetGameTime()) {
		TF2_AddCondition(client, TFCond_MegaHeal, -1.0);
		if(includeUber) {
			TF2_AddCondition(client, TFCond_Ubercharged, -1.0);
			SetEntProp(client, Prop_Data, "m_takedamage", 0);
		}
		SDKHook(client, SDKHook_PostThinkPost, AI_ThinkPost);
	}
	
	AI_EndsAt[client] = GetGameTime() + duration;
}

void AI_EndRage(int client)
{
	TF2_RemoveCondition(client, TFCond_MegaHeal);
	TF2_RemoveCondition(client, TFCond_Ubercharged);
	SetEntProp(client, Prop_Data, "m_takedamage", 2);
}

/**
 * Delayable Particle Effect
 */
public void DPE_ThinkPost(int client)
{
	if(DPE_ExecuteRageAt[client] >= GetGameTime()) {
		DelayableBuildingDestruction(client);
		SDKUnhook(client, SDKHook_PostThinkPost, DPE_ThinkPost);
	}
}

void DelayableParticleEffect(int client)
{
	FF2Prep player = FF2Prep(client);
	float duration = player.GetArgF(FAST_REG(rage_delayable_particle_effect), "duration", 2, 2.0);
	float radiusSquared = player.GetArgF(FAST_REG(rage_delayable_particle_effect), "radius", 3, 1000.0);
	radiusSquared = radiusSquared * radiusSquared;
	char[] effectName = new char[48];
	player.GetArgS(FAST_REG(rage_delayable_particle_effect), "particle", 4, effectName, 48);

	static float bossPos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", bossPos);
	static float victimPos[3];
	for (int victim = 1; victim < MaxClients; victim++) {
		if (ValidatePlayer(victim, AnyAlive) && GetClientTeam(victim) != FF2_GetBossTeam()) {
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
			if (GetVectorDistance(bossPos, victimPos, true) <= radiusSquared) {
				CreateTimedEntity(EntIndexToEntRef(AttachParticle(victim, effectName, 75.0)), duration);
			}
		}
	}
}

void Rage_DelayableParticleEffect(int bossIdx)
{
	FF2Prep player = FF2Prep(bossIdx, false);
	float delay = player.GetArgF(FAST_REG(rage_delayable_particle_effect), "delay", 1, 2.5);
	int client = BossToClient(bossIdx);
	
	if(delay) {
		DPE_ExecuteRageAt[client] = GetGameTime() + delay;
		SDKHook(client, SDKHook_PostThinkPost, DPE_ThinkPost);
		return;
	}
	DelayableParticleEffect(client);
}

/**
 * Delayable Building Destruction
 */
public void DBD_ThinkPost(int client)
{
	if(DBD_ExecuteRageAt[client] >= GetGameTime()) {
		DelayableBuildingDestruction(client);
		SDKUnhook(client, SDKHook_PostThinkPost, DBD_ThinkPost);
	}
}

void DestroyBuildingsOfType(const int bits, int clientIdx, bool saveByCarry, float radiusSquared)
{
	int building = MaxClients + 1;
	char clsname[64];
	while((building = FindEntityByClassname(building, "obj_*")) != -1) {
		if(!IsValidEntity(building)) {
			continue;
		}
		GetEntityClassname(building, clsname, sizeof(clsname));
		switch(clsname[5]) {
			case 's': if(bits ^ (1 << 0)) continue;
			case 'd': if(bits ^ (1 << 1)) continue;
			case 't': if(bits ^ (1 << 2)) continue;
		}
		
		static float bossPos[3];
		static float objPos[3];
		GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", bossPos);
		GetEntPropVector(building, Prop_Send, "m_vecOrigin", objPos);
		if (GetVectorDistance(bossPos, objPos, true) > radiusSquared) {
			continue;
		}
		
		if (saveByCarry) {
			SDKHooks_TakeDamage(building, clientIdx, clientIdx, 5000.0, DMG_GENERIC, -1);
		}
		else if (!(GetEntProp(building, Prop_Send, "m_bCarried") == 0 && GetEntProp(building, Prop_Send, "m_bPlacing") != 0)) {
			if (GetEntProp(building, Prop_Send, "m_bPlacing")) {
				CreateTimedEntity(building, 0.0);
			}
			else {
				SDKHooks_TakeDamage(building, clientIdx, clientIdx, 5000.0, DMG_GENERIC, -1);
			}
		}
	}
}

void DelayableBuildingDestruction(int client)
{
	FF2Prep player = FF2Prep(client);
	bool sentries = player.GetArgI(FAST_REG(rage_delayable_building_destruction), "sentries", 2, 1) != 0;
	bool dispensers = player.GetArgI(FAST_REG(rage_delayable_building_destruction), "dispenser", 3, 1) != 0;
	bool teleporters = player.GetArgI(FAST_REG(rage_delayable_building_destruction), "teleporters", 4, 1) != 0;
	bool saveByCarry = player.GetArgI(FAST_REG(rage_delayable_building_destruction), "save by carry", 5, 1) != 0;
	float radius = player.GetArgF(FAST_REG(rage_delayable_building_destruction), "radius", 6, 700.0);
	radius *= radius;
	
	int bits = 0x00;
	bits &= sentries ? (1<<0):0;
	bits &= dispensers ? (1<<1):0;
	bits &= teleporters ? (1<<2):0;
	DestroyBuildingsOfType(bits, client, saveByCarry, radius);
}

void Rage_DelayableBuildingDestruction(int bossIdx)
{
	FF2Prep player = FF2Prep(bossIdx, false);
	float delay = player.GetArgF(FAST_REG(rage_delayable_damage), "delay", 1, 2.5);
	int client = BossToClient(bossIdx);
	
	if(delay) {
		DBD_ExecuteRageAt[client] = GetGameTime() + delay;
		SDKHook(client, SDKHook_PostThinkPost, DBD_ThinkPost);
		return;
	}
	DelayableBuildingDestruction(client);
}

/**
 * Delayable Earthquake
 */
public void DE_ThinkPost(int client)
{
	if(DD_ExecuteRageAt[client] >= GetGameTime()) {
		DelayableEarthquake(client);
		SDKUnhook(client, SDKHook_PostThinkPost, DE_ThinkPost);
	}
}

void DelayableEarthquake(int client)
{
	FF2Prep player = FF2Prep(client);
		
	float duration = player.GetArgF(FAST_REG(rage_delayable_earthquake), "duration", 2, 5.0);
	float raidus = player.GetArgF(FAST_REG(rage_delayable_earthquake), "radius", 3, 1000.0);
	float amplitude = player.GetArgF(FAST_REG(rage_delayable_earthquake), "amplitude", 4, 6.0);
	float frequency = player.GetArgF(FAST_REG(rage_delayable_earthquake), "frequency", 5, 1.0);
	bool airshake = player.GetArgI(FAST_REG(rage_delayable_earthquake), "air shake", 6, 1) != 0;

	static float bossPos[3];
	GetClientAbsOrigin(client, bossPos);
	FF2UTIL_ScreenShakeAll(player, bossPos, amplitude, frequency, duration, raidus, SHAKE_START, airshake);
}

void Rage_DelayableEarthquake(int bossIdx)
{
	FF2Prep player = FF2Prep(bossIdx, false);
	float delay = player.GetArgF(FAST_REG(rage_delayable_earthquake), "delay", 1, 1.5);
	int client = BossToClient(bossIdx);
	
	if(delay) {
		DE_ExecuteRageAt[client] = GetGameTime() + delay;
		SDKHook(client, SDKHook_PostThinkPost, DE_ThinkPost);
		return;
	}
	DelayableEarthquake(client);
}

/**
 * Delayable Damage
 */
public void DD_ThinkPost(int client)
{
	if(DD_ExecuteRageAt[client] >= GetGameTime()) {
		DelayableDamage(client);
		SDKUnhook(client, SDKHook_PostThinkPost, DD_ThinkPost);
	}
}

void DelayableDamage(int client)
{
	FF2Prep player = FF2Prep(client);
	
	float damage = player.GetArgF(FAST_REG(rage_delayable_damage), "damage", 2, 150.0);
	float radius = player.GetArgF(FAST_REG(rage_delayable_damage), "radius", 3, 1200.0);
	float knockback = player.GetArgF(FAST_REG(rage_delayable_damage), "knockback", 4, 1200.0);
	bool scaleByDistance = player.GetArgI(FAST_REG(rage_delayable_damage), "scale by dist", 5, 1) == 1;
	bool liftLowZ = player.GetArgI(FAST_REG(rage_delayable_damage), "z-lift", 6, 1) == 1;

	static float bossPos[3];
	GetClientAbsOrigin(client, bossPos);
	static float victimPos[3];
	static float kbTarget[3];
	float dist;
	for (int victim = 1; victim < MaxClients; victim++) {
		if (ValidatePlayer(victim, AnyAlive) && GetClientTeam(victim) != FF2_GetBossTeam())
		{
			GetClientAbsOrigin(victim, victimPos);
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
			dist = GetVectorDistance(bossPos, victimPos);
			if (dist < radius && !TF2_IsPlayerInCondition(victim, TFCond_Ubercharged))
			{
				SDKHooks_TakeDamage(victim, client, client, damage, DMG_GENERIC | DMG_PREVENT_PHYSICS_FORCE, -1);
				
				if (knockback)
				{
					MakeVectorFromPoints(bossPos, victimPos, kbTarget);
					NormalizeVector(kbTarget, kbTarget);
					
					if (kbTarget[2] < 0.1 && !(kbTarget[2] < 0 && liftLowZ))
						kbTarget[2] = 0.1;
					
					ScaleVector(kbTarget, (scaleByDistance ? knockback : (knockback * (((radius - dist) * 2) / radius))));

					TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, kbTarget);
				}
			}
		}
	}
}

void Rage_DelayableDamage(int bossIdx)
{
	FF2Prep player = FF2Prep(bossIdx, false);
	float delay = player.GetArgF(FAST_REG(rage_delayable_damage), "delay", 1, 2.5);
	int client = BossToClient(bossIdx);
	
	if(delay) {
		DD_ExecuteRageAt[client] = GetGameTime() + delay;
		SDKHook(client, SDKHook_PostThinkPost, DD_ThinkPost);
		return;
	}
	DelayableDamage(client);
}

/**
 * Scaled Endgame Rage Gain (SERG)
 */
public void SERG_ThinkPost(int client)
{
	if(SERG_flNextThink[client] > GetGameTime()) {
		return;
	}
	SERG_flNextThink[client] = GetGameTime() + 1.0;
	int count = GetClientTeam(client) == FF2_GetBossTeam() ? infos.iAlives:infos.iBosses;
	if(SERG_PlayersAliveToStart[client] >= count) {
		int boss = FF2_GetBossIndex(client);
		float rtg = (SERG_OnePlayerRPS[client] * ((SERG_PlayersAliveToStart[client] - count) + 1)) / SERG_PlayersAliveToStart[client];
		float rage = FF2_GetBossCharge(boss, 0) + rtg;
		if(rage > 100.0) {
			rage = 100.0;
		}
		FF2_SetBossCharge(boss, 0, rage);
	}
}

/**
 * Stocks
 */
#define MAX_SHAKE_AMPLITUDE 16.0
void FF2UTIL_ScreenShakeAll(FF2Prep player, const float center[3], float amplitude, float frequency, float duration, float radius, ShakeCommand_t eCommand, bool AirShake = true)
{
	static bool usesound = false;
	char[] soundFile = new char[128];
	usesound = player.GetArgS(FAST_REG(rage_delayable_earthquake), "sound", 7, soundFile, 128);
	if(usesound) {
		PrecacheSound(soundFile);
	}
	
	int i;
	float LocalAmplitude;
	
	if( amplitude > MAX_SHAKE_AMPLITUDE)
		amplitude = MAX_SHAKE_AMPLITUDE;
	
	static float Origin[3];
	
	for (i = 1; i <= MaxClients; i++) {
		if(!ValidatePlayer(i, AnyAlive)) {
			continue;
		}
		
		if (!AirShake && eCommand == SHAKE_START && GetEntityFlags(i) & ~FL_ONGROUND) {
			continue;
		}
		
		GetClientAbsOrigin(i, Origin);
		LocalAmplitude = ComputeShakeAmplitude(center, Origin, amplitude, radius);
		if(LocalAmplitude <0) {
			continue;
		}
		
		if(usesound && GetClientTeam(i) != FF2_GetBossTeam() && GetVectorDistance(center, Origin, true) <= radius*radius) {
			EmitSoundToClient(i, soundFile);
		}
		
		TransmitShakeEvent(i, LocalAmplitude, frequency, duration, eCommand);
	}
}

static stock void TransmitShakeEvent(int client, float LocalAmplitude, float frequency, float duration, ShakeCommand_t eCommand)
{
	if(LocalAmplitude>0.0 || eCommand == SHAKE_STOP) {
		if(eCommand)	
			LocalAmplitude = 0.0;
		
		BfWrite DoShake = UserMessageToBfWrite(StartMessageOne("Shake", client, 1));
		
		DoShake.WriteByte(view_as<int>(eCommand));
		DoShake.WriteFloat(LocalAmplitude);
		DoShake.WriteFloat(frequency);
		DoShake.WriteFloat(duration);
		
		EndMessage();
	}
}
static stock float ComputeShakeAmplitude(const float Center[3], const float ShakePt[3], float amplitude, float radius)
{
	if(radius <= 0) {
		return amplitude;
	}

	float localAmplitude = -1.0;
	static float delta[3];
	SubtractVectors(Center, ShakePt, delta);
	
	float distance = GetVectorLength(delta);

	if(distance <= radius) {
		float flPerc = 1.0 - (distance / radius);
		localAmplitude = amplitude * flPerc;
	}
	return localAmplitude;
}

void CreateTimedEntity(int entity, float time = 0.0)
{
	if (time == 0.0)
	{
		if(IsValidEntity(entity))
		{
			RemoveEntity(entity);
		}
	}
	else
	{
		CreateTimer(time, RemoveEntityTimer, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action RemoveEntityTimer(Handle Timer, any entRef)
{
	int entity = EntRefToEntIndex(entRef);
	if(IsValidEntity(entity))
		RemoveEntity(entity);
}

stock int AttachParticle(int entity, const char[] particleType, float offset=0.0, bool attach=true)
{
	int particle = CreateEntityByName("info_particle_system");
	if (!IsValidEntity(particle))
		return -1;

	static char targetName[128];
	static float position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	position[2]+=offset;
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

	Format(targetName, sizeof(targetName), "target%i", entity);
	DispatchKeyValue(entity, "targetname", targetName);

	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", targetName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(targetName);
	if(attach) {
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	}
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	return particle;
}
