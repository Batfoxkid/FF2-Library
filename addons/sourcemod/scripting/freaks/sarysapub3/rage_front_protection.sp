
/*
rage_front_protection

* arg-10 "ams"			"bool"
* arg1 "steal duration" "float"
* arg2 "damage count" 	"int"
* arg3 "shot sound"		"string"
* arg4 "min yaw"		"float"
* arg5 "max yaw"		"float"

* arg6 "sound"			"string"
* arg7 "wearable idx"	"int"
* arg8 "shield model"	"string"

*/

static bool isActive = false;
bool FP_AMS[MAXCLIENTS];
static float flProtectThink[MAXCLIENTS];
static int iDamageCount[MAXCLIENTS], iWearableRef[MAXCLIENTS] =  { INVALID_ENT_REFERENCE, ... };

public void FP_EndRage(int client)
{
	iDamageCount[client] = 0;
	
	char[] bffer = new char[128];
	FF2Prep player = FF2Prep(client);
	if(player.GetArgS(FAST_REG(rage_front_protection), "sound", 6, bffer, 128)) {
		EmitSoundToAll(bffer);
	}
	
	if(iWearableRef[client] != INVALID_ENT_REFERENCE) {
		int wearable = EntRefToEntIndex(iWearableRef[client]);
		if(IsValidEntity(wearable)) {
			TF2_RemoveWearable(client, wearable);
		}
		iWearableRef[client] = INVALID_ENT_REFERENCE;
	}
	
	if(GetEntPropString(client, Prop_Data, "m_ModelName", bffer, 128)) {
		SetVariantString(bffer);
		AcceptEntityInput(client, "SetCustomModel");
		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
	}
}

public void FP_Invoke(int client, int index)
{
	FF2Prep player = FF2Prep(client);

	char[] bffer = new char[128];
	if(player.GetArgS(FAST_REG(rage_front_protection), "sound", 6, bffer, 128)) {
		EmitSoundToAll(bffer);
	}
	
	flProtectThink[client] = player.GetArgF(FAST_REG(rage_front_protection), "protect duration", 1, 10.0) + GetGameTime();
	iDamageCount[client] = player.GetArgI(FAST_REG(rage_front_protection), "damage count", 2, 250);
	int wearable = player.GetArgI(FAST_REG(rage_front_protection), "wearable idx", 7, -1);
	if(wearable != -1 && iWearableRef[client] == INVALID_ENT_REFERENCE) {
		int ent = TF2_EquipWearable(client, wearable, "tf_wearable");
		if(IsValidEntity(ent)) {
			iWearableRef[client] = EntIndexToEntRef(ent);
		}
	}
	
	if(player.GetArgS(FAST_REG(rage_front_protection), "shield model", 8, bffer, 128)) {
		SetVariantString(bffer);
		AcceptEntityInput(client, "SetCustomModel");
		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
	}
	
	SDKHook(client, SDKHook_PostThinkPost, FP_PostThinkPost);
}

public Action FP_OnTakeDamageAlive(int victim, int& attacker, int& inflictor, 
								float& damage, int& damagetype, int& weapon,
								float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(!isActive) {
		isActive = true;
	}
	if(!ValidatePlayer(victim, AnyAlive) || !ValidatePlayer(attacker, AnyAlive)) {
		return Plugin_Continue;
	}
	else if(TF2_IsPlayerInCondition(victim, TFCond_Ubercharged) || !iDamageCount[victim] || damagecustom == TF_CUSTOM_BACKSTAB) {
		return Plugin_Continue;
	}
	
	FF2Prep player = FF2Prep(victim);
	
	static float vecPosv[3], vecPosa[3];
	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", vecPosv); GetEntPropVector(inflictor, Prop_Send, "m_vecOrigin", vecPosa);
	
	static float vecAngv[3]; GetClientEyeAngles(victim, vecAngv);
	static float vecAngr[3];
	
	float vecRes[3];
	MakeVectorFromPoints(vecPosv, vecPosa, vecRes);
	GetVectorAngles(vecRes, vecAngr);
	
	float yawOffset = vecAngr[1] - vecAngv[1];
	while(yawOffset <= -180.0) {
		yawOffset += 360.0;
	}
	while(yawOffset > 180.0) {
		yawOffset -= 360.0;
	}
	
	float min = player.GetArgF(FAST_REG(rage_front_protection), "min yaw", 4, 0.0);
	float max = player.GetArgF(FAST_REG(rage_front_protection), "max yaw", 5, 0.0);
	static char snd[128]; 
	
	if (yawOffset >= min && yawOffset <= max)
	{
		iDamageCount[victim] -= damage;
		if(iDamageCount[victim] <= 0.0) {
			FP_EndRage(victim);
		}
		else if(player.GetArgS(FAST_REG(rage_front_protection), "shot sound", 3, snd, sizeof(snd))) {
			EmitSoundToClient(victim, snd);
			EmitSoundToClient(attacker, snd);
		}
		damage = 0.0;
		damagetype |= DMG_PREVENT_PHYSICS_FORCE;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void FP_PostThinkPost(int client)
{
	if(flProtectThink[client] < GetGameTime()) {
		FP_EndRage(client);
		SDKUnhook(client, SDKHook_PostThinkPost, FP_PostThinkPost);
	}
}

public void FP_RoundEnd()
{
	if(!isActive) {
		return;
	}
	LoopAnyValidPlayer( \
		FP_AMS[_x] = false; \
		SDKUnhook(_x, SDKHook_OnTakeDamageAlive, FP_OnTakeDamageAlive); \
		SDKUnhook(_x, SDKHook_PostThinkPost, FP_PostThinkPost); \
		iWearableRef[_x] = INVALID_ENT_REFERENCE; \
	) 
	isActive = false;
}
