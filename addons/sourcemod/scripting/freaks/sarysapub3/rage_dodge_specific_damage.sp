
/*
rage_dodge_specific_damage

* arg-10 "ams"		"bool"
* arg1	"duration"	"float"
* arg2	"move speed" "float"
* arg3	"replay speed" "float"
* arg4	"sound" 	"string"
* arg5	"dodge" 	"hex"	//refer to sdkhooks.inc DMG_

*/

static bool isActive;
bool DSD_AMS[MAXCLIENTS];
static float flThinkTime[MAXCLIENTS];

public void DSD_Invoke(int client, int index)
{
	FF2Prep player = FF2Prep(client);
	flThinkTime[client] = GetGameTime() + player.GetArgF(FAST_REG(rage_dodge_specific_damage), "duration", 1, 10.0);
	float replayspd = player.GetArgF(FAST_REG(rage_dodge_specific_damage), "replay speed", 3, 0.0);
	if(replayspd) {
		UTIL_UpdateCheatValues("0");
		sv_cheats.FloatValue = replayspd;
	}
	
	float movespd = player.GetArgF(FAST_REG(rage_dodge_specific_damage), "replay speed", 2, 0.0);
	if(movespd) {
		DSM_SetOverrideSpeed(client, movespd);
	}
	
	static char bffer[128];
	if(player.GetArgS(FAST_REG(rage_dodge_specific_damage), "sound", 4, bffer, sizeof(bffer))) {
		EmitSoundToAll(bffer);
	}
	SDKHook(client, SDKHook_OnTakeDamageAlive, DSD_PostThinkPost);
}

public void DSD_PostThinkPost(int client)
{
	if(flThinkTime[client] < GetGameTime()) {
		UTIL_UpdateCheatValues("1");
		sv_cheats.RestoreDefault();
		SDKUnhook(client, SDKHook_OnTakeDamageAlive, DSD_PostThinkPost);
		DSM_SetOverrideSpeed(client);
	}
}

public Action DSD_OnTakeDamageAlive(int victim, int& attacker, int& inflictor, 
								float& damage, int& damagetype, int& weapon,
								float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(!ValidatePlayer(victim, AnyAlive)) {
		return Plugin_Continue;
	}
	if(!flThinkTime[victim] || flThinkTime[victim] < GetGameTime()) {
		return Plugin_Continue;
	}
	
	FF2Prep player = FF2Prep(victim);
	int bits = player.GetArgI(FAST_REG(rage_dodge_specific_damage), "dodge", 5, 0x200000CA);
	if(damagetype & bits) {
		damage = 0.0;
		damagetype |= DMG_PREVENT_PHYSICS_FORCE;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public void DSD_RoundEnd()
{
	if(!isActive) {
		return;
	}
	LoopAnyValidPlayer( \
		DSD_AMS[_x] = false; \
		SDKUnhook(_x, SDKHook_OnTakeDamageAlive, DSD_OnTakeDamageAlive); \
		SDKUnhook(_x, SDKHook_OnTakeDamageAlive, DSD_PostThinkPost); \
	)
	isActive = false;
}
