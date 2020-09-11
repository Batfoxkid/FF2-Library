
public void Handle_StunRage(int boss)
{
	SpawnSpecialWeapon(boss, StunGun);
}

public MRESReturn Pre_StunGunPrimaryAttack(int weapon)
{
	if(!IsRoundActive()){
		return MRES_Ignored;
	}
	
	int owner = GethOwnerEntity(weapon);
	int boss = FF2_GetBossIndex(owner);
	if(GetCurrentWeapon(boss) != weapon){
		return MRES_Ignored;
	}
	
	FF2Prep Boss = FF2Prep(boss, false);
	
	float delay = Boss.GetArgF(this_plugin_name, "special_weapons_stungun", "delay", 13, 5.0);
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + delay);
	
	int clip = GetEntProp(weapon, Prop_Data, "m_iClip1");
	if(clip <= 0)
		return MRES_Supercede;
	
	LaunchRocket(Boss);
	SetEntProp(weapon, Prop_Data, "m_iClip1", clip - 1);
	
	return MRES_Supercede;
}

public void Start_StunGun(int weapon)
{
	DHookEntity(Global[hPrimaryAttack], false, weapon, .callback = Pre_StunGunPrimaryAttack);
}

static void LaunchRocket(FF2Prep Boss)
{
	int rocket = CreateEntityByName("tf_projectile_rocket");
	if(!IsValidEntity(rocket))
		return;
	
	static char buffer[126];
	
	int client = Boss.Index;
	float speed = Boss.GetArgF(this_plugin_name, "special_weapons_stungun", "speed", 14, 1000.0);
	static float vecAng[3], vecPos[3], vecFwd[3];
	GetClientEyePosition(client, vecPos);
	GetClientEyeAngles(client, vecAng);
	
	vecPos[2] -= 25.0;
	GetAngleVectors(vecAng, vecFwd, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(vecFwd, speed);
	
	speed = Boss.GetArgF(this_plugin_name, "special_weapons_stungun", "damage", 15, 25.0);
	TeleportEntity(rocket, vecPos, vecAng, vecFwd);
	SetEntProp(rocket, Prop_Send, "m_bCritical", false);
	SetEntDataFloat(rocket, m_flRocketDamage, speed, true);
	SetEntProp(rocket, Prop_Send, "m_nSkin", 0);
	SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", client);
	SetVariantInt(GetClientTeam(client));
	AcceptEntityInput(rocket, "TeamNum");
	SetVariantInt(GetClientTeam(client));
	AcceptEntityInput(rocket, "SetTeam"); 
	SetEntPropEnt(rocket, Prop_Send, "m_hOriginalLauncher", GetPlayerWeaponSlot(client, TFWeaponSlot_Melee));
	SetEntPropEnt(rocket, Prop_Send, "m_hLauncher", GetPlayerWeaponSlot(client, TFWeaponSlot_Melee));
	DispatchSpawn(rocket);
	
	if(Boss.GetArgS(this_plugin_name, "special_weapons_stungun", "model", 16, buffer, sizeof(buffer))) {
		SetEntProp(rocket, Prop_Send, "m_nModelIndex", PrecacheModel(buffer));
	}
	
	SDKHook(rocket, SDKHook_StartTouch, On_RocketTouch);
}

public Action On_RocketTouch(int rocket, int other)
{
	int owner = GetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity");
	FF2Prep Boss = FF2Prep(owner);
	
	static float vicPos[3], endPos[3], vecPos[3];
	static char particle[64];
	float intensity = Boss.GetArgF(this_plugin_name, "special_weapons_stungun", "intensity", 17, 800.0);
	GetEntPropVector(rocket, Prop_Send, "m_vecOrigin", endPos);
	
	int obj = -1;
	while((obj = FindEntityInSphere(obj, endPos, 232.0)) != -1)
	{
		if(obj <= 0)
			continue;
		else if(obj <= MaxClients && (GetClientTeam(obj) != GetClientTeam(owner) || obj == owner))
		{
			GetEntPropVector(obj, Prop_Send, "m_vecOrigin", vicPos);
			MakeVectorFromPoints(endPos, vicPos, vecPos);
			NormalizeVector(vecPos, vecPos);
			ScaleVector(vecPos, intensity);
			TeleportEntity(obj, NULL_VECTOR, NULL_VECTOR, vecPos);
		}
		else if(HasEntProp(obj, Prop_Send, "m_hBuilder"))
		{
			GetEntityClassname(obj, particle, sizeof(particle));
			if(!strcmp(particle, "obj_sentrygun"))
				Hijack_Sentry(obj, Boss.GetArgF(this_plugin_name, "special_weapons_stungun", "hijack", 18, 4.0));
			else if(!strcmp(particle, "obj_dispenser"))
				SetDisabled(obj, Boss.GetArgF(this_plugin_name, "special_weapons_stungun", "disable", 19, 4.0));
		}
	}
	
	if(Boss.GetArgS(this_plugin_name, "special_weapons_stungun", "particles2", 20, particle, sizeof(particle))) {
		FixParticlesName(particle, sizeof(particle), TF2_GetClientTeam(owner));
		CreateTimedParticle(owner, particle, endPos, 0.7, false);
	}
	if(FF2_RandomSound("sound_explode_stun", particle, sizeof(particle), Boss.boss))
		FF2_EmitVoiceToAll2(particle, rocket);
	
	return Plugin_Handled;
}