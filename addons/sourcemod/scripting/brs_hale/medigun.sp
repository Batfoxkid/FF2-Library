public void Prep_Medigun(GameData &Config)
{
	Handle hAllowedToheal = DHookCreateFromConf(Config, "CWeaponMedigun::AllowedToHealTarget");
	
	if(hAllowedToheal == null)
	{
		delete Config;
		SetFailState("[GameData] Failed to Create a Hook for \"CWeaponMedigun::AllowedToHealTarget\"");
		return;
	}
	
	DHookEnableDetour(hAllowedToheal, false, Pre_CanHealTarget);
}

public void Handle_MedigunRage(int boss)
{
	SpawnSpecialWeapon(boss, Healing);
}

public MRESReturn Pre_CanHealTarget(int medigun, Handle Return, Handle Params)
{
	int owner = GethOwnerEntity(medigun);
	if(!ValidatePlayer(owner, IsBoss))
		return MRES_Ignored;
	
	if(GetCurrentWeapon(FF2_GetBossIndex(owner)) != medigun)
		return MRES_Ignored;
	
	int target = DHookGetParam(Params, 1);
	if(ValidatePlayer(target, AnyAlive)) {
		if(TF2_GetPlayerClass(target) == TFClass_Spy && TF2_IsPlayerInCondition(target, TFCond_Cloaked)) {
			return MRES_Ignored;
		}
		DHookSetReturn(Return, true);
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

static float flNextParticle[MAXCLIENTS];
public MRESReturn Pre_MedigunPostFrame(int medigun)
{
	int target = GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");
	if(!ValidatePlayer(target, AnyAlive)) {
		return MRES_Ignored;
	}
	
	int owner = GethOwnerEntity(medigun);
	if(SameTeam(owner, target))
		return MRES_Ignored;
	
	FF2Prep Boss = FF2Prep(owner);
	if(!Boss.HasAbility(this_plugin_name, "special_weapons_medigun")) {
		return MRES_Ignored;
	}
		
	float flhurtDmg = Boss.GetArgF(this_plugin_name, "special_weapons_medigun", "hurt dmg", 13, 50.0);
	if(flhurtDmg <= 40)	flhurtDmg = 40.0;
	flhurtDmg *= GetGameFrameTime();
	SDKHooks_TakeDamage(target, medigun, owner, flhurtDmg, DMG_PREVENT_PHYSICS_FORCE);
	
	static char particle[64];
	Boss.GetArgS(this_plugin_name, "special_weapons_medigun", "particles2", 20, particle, sizeof(particle));
	if(strlen(particle) > 3) {
		if(flNextParticle[target] < GetGameTime()) {
			flNextParticle[target] = GetGameTime() + 0.6;
			static float vecPos[3]; GetClientAbsOrigin(target, vecPos);
			FixParticlesName(particle, sizeof(particle), TF2_GetClientTeam(owner));
			CreateTimedParticle(target, particle, vecPos, 0.4);
		}
	}
	return MRES_Ignored;
}

public void Start_AntiMedigun(int medigun)
{
	DHookEntity(Global[hItemPostFrame], false, medigun, .callback = Pre_MedigunPostFrame);
}