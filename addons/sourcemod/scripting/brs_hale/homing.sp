
public void Handle_HomingRocket(int boss)
{
	SpawnSpecialWeapon(boss, Homing);
}

static float flNextThink[2048];
public void Handle_HomingRocketThink(int rocket)
{
	if(flNextThink[rocket] > GetGameTime())
		return;
	
	int owner = GethOwnerEntity(GetEntPropEnt(rocket, Prop_Send, "m_hOriginalLauncher"));
	if(!ValidatePlayer(owner, Any))
		return;
	
	FF2Prep Boss = FF2Prep(owner);
	if(!Boss.HasAbility(this_plugin_name, "special_weapons_homing"))
		return;
	
	flNextThink[rocket] = GetGameTime() + Boss.GetArgF(this_plugin_name, "special_weapons_homing", "next think", 13, 0.1);
	
	float rocketOrigin[3];
	GetEntPropVector(rocket, Prop_Data, "m_vecAbsOrigin", rocketOrigin);
	int target = FindNearestTargetInSphere(Boss.GetArgF(this_plugin_name, "special_weapons_homing", "homing radius", 14, 400.0) , rocket, rocketOrigin);
	
	if(target <= 0) {
		return;
	}
	
	SetEntDataFloat(rocket, m_flRocketDamage, Boss.GetArgF(this_plugin_name, "special_weapons_homing", "damage", 15, 75.0), true);
	
	static float vecVelocity[3], vecPosition[3];
	GetEntPropVector(rocket, Prop_Data, "m_vecAbsVelocity", vecVelocity);
	
	float flSpeed = NormalizeVector(vecVelocity, vecVelocity);
	GetClientEyePosition(target, vecPosition);
	
	float vecTargetAim[3];
	MakeVectorFromPoints(rocketOrigin, vecPosition, vecTargetAim);
	NormalizeVector(vecTargetAim, vecTargetAim);
	
	for (int x; x < 3; x++) 
		vecVelocity[x] += ((vecTargetAim[x] - vecVelocity[x]) * Boss.GetArgF(this_plugin_name, "special_weapons_homing", "turn rate", 16, 75.0));
	
	NormalizeVector(vecVelocity, vecVelocity);
	flSpeed *= Boss.GetArgF(this_plugin_name, "special_weapons_homing", "speed", 17, 0.75);
	if(flSpeed < 500.0)
		flSpeed = 500.0;
	ScaleVector(vecVelocity, flSpeed);
	
	GetVectorAngles(vecVelocity, vecTargetAim);
	SetEntPropVector(rocket, Prop_Data, "m_vecAbsVelocity", vecVelocity);
	
	TeleportEntity(rocket, NULL_VECTOR, vecTargetAim, NULL_VECTOR);
}

