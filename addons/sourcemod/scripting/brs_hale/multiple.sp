public void Handle_MultiRockets(int boss)
{
	SpawnSpecialWeapon(boss, Multiple);
}

public MRESReturn Pre_RocketLauncherPrimaryAttack(int weapon)
{
	if(!IsRoundActive())
		return MRES_Ignored;
	
	int owner = GethOwnerEntity(weapon);
	int boss = FF2_GetBossIndex(owner);
	if(GetCurrentWeapon(boss) != weapon)
		return MRES_Ignored;
		
	FF2Prep Boss = FF2Prep(boss, false);
	if(!Boss.HasAbility(this_plugin_name, "special_weapons_multiple"))
		return MRES_Ignored;
	
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 1.0);
	int curAmmo = GetEntProp(weapon, Prop_Data, "m_iClip1");
	if(curAmmo <= 0) {
		return MRES_Supercede;
	}
	int min = Boss.GetArgI(this_plugin_name, "special_weapons_multiple", "min", 14, 1);
	int max = Boss.GetArgI(this_plugin_name, "special_weapons_multiple", "max", 15, 5);
	Prep_LaunchRocket(Boss, GetRandomInt(min, max));
	SetEntProp(weapon, Prop_Data, "m_iClip1", curAmmo - 1);
	return MRES_Supercede;
}

static void Prep_LaunchRocket(FF2Prep Boss, int ammount)
{
	for (int x; x < ammount; x++) {
		LaunchRocket(Boss); LaunchRocket(Boss);
	}
}

static void LaunchRocket(FF2Prep Boss)
{
	static bool tick;
	int rocket = CreateEntityByName("tf_projectile_rocket");
	
	static char buffer[126];
	
	int client = Boss.Index;
	float speed = Boss.GetArgF(this_plugin_name, "special_weapons_multiple", "speed", 16, 1000.0);
	static float vecAng[3], vecPos[3], vecFwd[3];
	GetClientEyePosition(client, vecPos);
	GetClientEyeAngles(client, vecAng);
	
	vecPos[1] += !tick ? GetRandomFloat(-50.0, -20.0):GetRandomFloat(20.0, 50.0);
	
	GetAngleVectors(vecAng, vecFwd, NULL_VECTOR, NULL_VECTOR);
	for (int x; x < 3; x++)
		vecFwd[x] += GetRandomFloat(-0.27, 0.33);
	ScaleVector(vecFwd, speed);
	
	speed = Boss.GetArgF(this_plugin_name, "special_weapons_multiple", "damage", 17, 15.0);
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
	
	if(Boss.GetArgS(this_plugin_name, "special_weapons_multiple", "model", 18, buffer, sizeof(buffer))) {
		SetEntProp(rocket, Prop_Send, "m_nModelIndex", PrecacheModel(buffer));
	}
	tick = !tick;
}

public void Start_MultiRocket(int weapon)
{
	DHookEntity(Global[hPrimaryAttack], false, weapon, .callback = Pre_RocketLauncherPrimaryAttack);
}