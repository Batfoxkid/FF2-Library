stock void FF2_EmitVoiceToAll2(const char[] sound, int entity = SOUND_FROM_PLAYER)
{
#if defined _FFBAT_included
	if(UnOfficialFF2)
		FF2_EmitVoiceToAll(sound, entity);
	else EmitSoundToAll(sound, entity);
#else
	EmitSoundToAll(sound, entity);
#endif
}

static float EndThink[2048];
stock void Hijack_Sentry(int sentry, float dur)
{
	CreateTimer(0.1, Pseudo_OnSentryThink, EntIndexToEntRef(sentry), TIMER_REPEAT);
	SetDisabled(sentry, dur);
	EndThink[sentry] = GetGameTime() + dur;
}

stock void SetDisabled(int entity, float duration)
{
	if(duration < 0.1)	duration = 0.1;
	SetEntProp(entity, Prop_Send, "m_bDisabled", true);
	CreateTimer(duration, Timer_ResetBuilding, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Pseudo_OnSentryThink(Handle timer, any Ref)
{
	int sentry = EntRefToEntIndex(Ref);
	if(!IsValidEntity(sentry)) {
		return Plugin_Stop;
	}
	if(EndThink[sentry] <= GetGameTime())
	{	
		return Plugin_Stop;
	}
	static float vecTurretAngles[3];
	GetEntDataVector(sentry, m_vecTurretAngles, vecTurretAngles);
	vecTurretAngles[0] = GetRandomFloat(-120.0, 120.0);
	vecTurretAngles[1] = GetRandomFloat(-0.0, 360.0);
	SetEntDataVector(sentry, m_vecTurretAngles, vecTurretAngles);
	return Plugin_Continue;
}

stock void SetAsCurrentWeapon(int boss, int weapon)
{
	RemoveFromCurrentWeapon(boss);
	int idx = ADTWeapons.Push(boss);
	ADTWeapons.Set(idx, EntIndexToEntRef(weapon), 1);
}

stock int GetCurrentWeapon(int boss)
{
	if(boss < 0)
		return -1;
	int idx = ADTWeapons.FindValue(boss, 0);
	if(idx == -1)
		return -1;
	return EntRefToEntIndex(ADTWeapons.Get(idx, 1));
}

stock void RemoveFromCurrentWeapon(int boss)
{
	int idx = ADTWeapons.FindValue(boss, 0);
	if(idx == -1)
		return;
	ADTWeapons.Erase(idx);
}

stock int GetWeaponSlot(int weapon)
{
	return SDKCall(Global[SDKGetSlot], weapon);
}

stock int GethOwnerEntity(int entity)
{
	return GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
}

stock int FindEntityInSphere(int iEntity, const float vecPosition[3], float flRadius) 
{
	return SDKCall(Global[SDKFindEntityInSphere], iEntity, vecPosition, flRadius);
}

bool SameTeam(int x, int y)
{
	return (GetClientTeam(x) == GetClientTeam(y));
}

stock void CreateTimedParticle(int owner, const char[] Name, float SpawnPos[3], float duration, bool bFollow = true)
{
	CreateTimer(duration, Timer_KillEntity, EntIndexToEntRef(AttachParticle(owner, Name, SpawnPos, bFollow)), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_KillEntity(Handle timer, any EntRef)
{
	int entity = EntRefToEntIndex(EntRef);
	if(IsValidEntity(entity))
		RemoveEntity(entity);
}

public Action Timer_ResetBuilding(Handle Timer, any EntRef)
{
	int building = EntRefToEntIndex(EntRef);
	if(IsValidEntity(building))
		SetEntProp(building, Prop_Send, "m_bDisabled", false);
}

stock int AttachParticle(int owner, const char[] ParticleName, float SpawnPos[3], bool bFollow)
{
	int entity = CreateEntityByName("info_particle_system");

	TeleportEntity(entity, SpawnPos, NULL_VECTOR, NULL_VECTOR);

	static char buffer[64];
	FormatEx(buffer, sizeof(buffer), "target%i", owner);
	DispatchKeyValue(owner, "targetname", buffer);

	DispatchKeyValue(entity, "targetname", "tf2particle");
	DispatchKeyValue(entity, "parentname", buffer);
	DispatchKeyValue(entity, "effect_name", ParticleName);
	DispatchSpawn(entity);
	
	if(bFollow) {
		SetVariantString(buffer);
		AcceptEntityInput(entity, "SetParent", entity, entity);
	}
	
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", owner);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "start");
	
	return entity; 
}

stock int FindNearestTargetInSphere(const float radius, int rocket, float vecOrigin[3])
{
	float vecTarget[3];
	
	ArrayStack players = new ArrayStack();
	int client = -1, team = GetEntProp(rocket, Prop_Send, "m_iTeamNum");
	
	while((client = FindEntityInSphere(client, vecOrigin, radius)) != -1)
		if(ValidatePlayer(client, AnyAlive) && GetClientTeam(client) != team) {
			players.Push(client);
		}
	
	if(players.Empty) {
		delete players;
		return -1;
	}
	float Nearest = 9999.9 * 9999.9;
	client = -1;
	while(!players.Empty) {
		int index = players.Pop();
		GetClientAbsOrigin(index, vecTarget);
		float dist = GetVectorDistance(vecOrigin, vecTarget, true);
		if( dist < Nearest) {
			Nearest = dist;
			client = index;
		}
	}
	delete players;
	return client;
}

public void Global_Unhook(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamageAlive, Post_TakeDamageAlive);
	SDKUnhook(client, SDKHook_PreThink, CheckBackToSanity);
}

stock bool FixParticlesName(char[] buffer, int size, const TFTeam iTeam)
{
	if(StrContains(buffer, "...") == -1)
		return false;
	switch(iTeam)
	{
		case TFTeam_Red: {
			ReplaceString(buffer, size, "...", "red");
			return true;
		}
		case TFTeam_Blue: {
			ReplaceString(buffer, size, "...", "blue");
			return true;
		}
	}
	return false;
}