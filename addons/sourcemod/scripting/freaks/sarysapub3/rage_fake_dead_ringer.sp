
/*
rage_fake_dead_ringer

* arg-10 "ams"				"bool"
* arg1 "duration" 			"float"
* arg2 "unlock duration"	"float"
* arg3 "sound"				"string"

*/

static bool isActive;
bool FDR_AMS[MAXCLIENTS];
static bool FDR_Pending[MAXCLIENTS];
static float FDR_EndAt[MAXCLIENTS], FDR_GoombaBlockedUntil[MAXCLIENTS];

public AMSResult FDR_CanInvoke(int client, int idex)
{
	return FDR_EndAt[client] < GetGameTime() ? AMS_Accept:AMS_Deny;
}

public void FDR_Invoke(int client, int index)
{
	FDR_Pending[client] = true;
}

public void FDR_EndAbility(int client, int index)
{
	FF2Prep player = FF2Prep(client);
	float duration = player.GetArgF(FAST_REG(rage_fake_dead_ringer), "unlock duration", 2, 3.0);
	{
		int weapon = -1;
		for (int slot = 0; slot <= 2; slot++)
		{
			weapon = GetPlayerWeaponSlot(client, slot);
			if(IsValidEntity(weapon)) {
				SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + duration);
				SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + duration);
			}
		}
	}
	
	static char snd[128];
	if(player.GetArgS(FAST_REG(rage_fake_dead_ringer), "sound", 3, snd, sizeof(snd))) {
		float pos[3]; GetClientEyePosition(client, pos);
		EmitAmbientSound(snd, pos, client);
	}
	
	if(TF2_IsPlayerInCondition(client, TFCond_Cloaked)) TF2_RemoveCondition(client, TFCond_Cloaked);
	TF2_SetCloakFadeTime(client, 0.09);
	if(TF2_IsPlayerInCondition(client, TFCond_DeadRingered)) TF2_RemoveCondition(client, TFCond_DeadRingered);
	if(TF2_IsPlayerInCondition(client, TFCond_Stealthed)) TF2_RemoveCondition(client, TFCond_Stealthed);
	FDR_GoombaBlockedUntil[client] = GetGameTime() + duration;
}

public void FDR_PostThinkPost(int  client)
{
	if(FDR_EndAt[client] < GetGameTime()) {
		FDR_EndAbility(client, -1);
		SDKUnhook(client, SDKHook_PostThinkPost, FDR_PostThinkPost);
		return;
	}
	
	if(!TF2_IsPlayerInCondition(client, TFCond_DeadRingered)) TF2_AddCondition(client, TFCond_DeadRingered, FF2Prep(client).GetArgF(FAST_REG(rage_fake_dead_ringer), "duration", 1, 5.0));
	if(!TF2_IsPlayerInCondition(client, TFCond_Stealthed)) TF2_AddCondition(client, TFCond_Stealthed, FF2Prep(client).GetArgF(FAST_REG(rage_fake_dead_ringer), "duration", 1, 5.0));
	if(GetEntPropFloat(client, Prop_Send, "m_flCloakMeter") != 100.0) SetEntPropFloat(client, Prop_Send, "m_flCloakMeter", 100.0);
}

public Action FDR_OnTakeDamageAlive(int victim, int& attacker, int& inflictor, 
								float& damage, int& damagetype, int& weapon,
								float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(!isActive) {
		isActive = true;
	}
	if(!ValidatePlayer(victim, AnyAlive) || !FF2Prep(victim).HasAbility(FAST_REG(rage_fake_dead_ringer))) {
		return Plugin_Continue;
	}
	else if(FDR_EndAt[victim] < GetGameTime()) {
		return Plugin_Continue;
	}
	if(!FDR_Pending[victim]) {
		return Plugin_Continue;
	}
	
	damage *= 0.1;
	FDR_FeignDeath(victim);
	return Plugin_Continue;
}

#if defined _goomba_included_
Action FDR_OnStomp(int attacker, int victim, float& damageMultiplier, float& damageBonus, float& JumpPower)
{
	if(!isActive) {
		return Plugin_Continue;
	}
	bool hasability = FF2Prep(attacker).HasAbility(FAST_REG(rage_fake_dead_ringer));
	if(hasability && (FDR_GoombaBlockedUntil[attacker] > GetGameTime() || FDR_EndAt[attacker] > GetGameTime())) {
		return Plugin_Handled;
	}
	hasability = FF2Prep(victim).HasAbility(FAST_REG(rage_fake_dead_ringer));
	if(hasability) {
		if(FDR_Pending[victim]) {
			damageMultiplier *= 0.1;
			damageBonus *= 0.1;
			return Plugin_Changed;
		}
		else if(FDR_EndAt[victim] > GetGameTime()) {
			damageMultiplier *= 0.1;
			damageBonus *= 0.1;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}
#endif

static void FDR_FeignDeath(int victim)
{
	FDR_Pending[victim] = false;
	float maxdur = FF2Prep(victim).GetArgF(FAST_REG(rage_fake_dead_ringer), "duration", 1, 5.0);
	FDR_EndAt[victim] = GetGameTime() + maxdur;
	UTIL_CreateRagdoll(victim);
	{
		int weapon = -1;
		for (int slot = 0; slot <= 2; slot++)
		{
			weapon = GetPlayerWeaponSlot(victim, slot);
			if(IsValidEntity(weapon)) {
				SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + maxdur);
				SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + maxdur);
			}
		}
	}
	SetEntPropFloat(victim, Prop_Send, "m_flCloakMeter", 100.0);
	TF2_AddCondition(victim, TFCond_DeadRingered, maxdur);
	TF2_AddCondition(victim, TFCond_Stealthed, maxdur);
	RequestFrame(NextFrame_RemoveConds, GetClientSerial(victim));
	SDKHook(victim, SDKHook_PostThinkPost, FDR_PostThinkPost);
}

public void NextFrame_RemoveConds(int serial)
{
	int client = GetClientFromSerial(serial);
	if(!client) {
		return;
	}
	if(TF2_IsPlayerInCondition(client, TFCond_OnFire)) TF2_RemoveCondition(client, TFCond_OnFire);
	if(TF2_IsPlayerInCondition(client, TFCond_Bleeding)) TF2_RemoveCondition(client, TFCond_Bleeding);
	if(TF2_IsPlayerInCondition(client, TFCond_MarkedForDeath)) TF2_RemoveCondition(client, TFCond_MarkedForDeath);
}

public void FDR_RoundEnd()
{
	if(!isActive) {
		return;
	}
	LoopAnyValidPlayer( \
		FDR_Pending[_x] = FDR_AMS[_x] = false; \
		SDKUnhook(_x, SDKHook_OnTakeDamageAlive, FDR_OnTakeDamageAlive); \
	)
}

static void TF2_SetCloakFadeTime(int client, float duration)
{
	static int m_flLastStealthExposeTime = -1;
	if(m_flLastStealthExposeTime == -1) {
		m_flLastStealthExposeTime = FindSendPropInfo("CTFPlayer", "m_Shared") + 0x96;
	}
	SetEntDataFloat(client, m_flLastStealthExposeTime, GetGameTime() + duration);
}
