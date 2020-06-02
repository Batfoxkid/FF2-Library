
static float flNextTime[MAXCLIENTS];
public void Handle_UpgradeThink(int client)
{
	int boss = FF2_GetBossIndex(client);
	
	if(!Tracker[boss].DmgSince)
		return;
	FF2Prep Boss = FF2Prep(boss, false);
	
	float min = Boss.GetArgF(this_plugin_name, UPGRADE, "start time", 1, 10.0);
	if(GetGameTime() - Tracker[boss].DmgSince < min){
		return;
	}
	
	static char particle[64];
	if(flNextTime[client] < GetGameTime())
	{
		min = Boss.GetArgF(this_plugin_name, UPGRADE, "think time", 2, 1.5);
		flNextTime[client] = GetGameTime() + min;
	
		Boss.GetArgS(this_plugin_name, UPGRADE, "particles2", 3, particle, sizeof(particle));
		if(strlen(particle) > 3) {
			FixParticlesName(particle, sizeof(particle), TF2_GetClientTeam(client));
			static float vecPos[3]; GetClientAbsOrigin(client, vecPos);
			CreateTimedParticle(client, particle, vecPos, 1.5);
		}
		
		if(!!Boss.GetArgI(this_plugin_name, UPGRADE, "hp regen", 4, 1)) {
			int iLives = FF2_GetBossLives(boss);
			int iMaxHealth = FF2_GetBossMaxHealth(boss);
			int iHealth = FF2_GetBossHealth(boss);
			if(iHealth / iLives < iMaxHealth) {
				FF2_SetBossHealth(boss, iHealth + Boss.GetArgI(this_plugin_name, UPGRADE, "health", 5, 25));
			}
		}
		
		if(!!Boss.GetArgI(this_plugin_name, UPGRADE, "pts regen", 6, 1)) {
			int max = Boss.GetArgI("menurage_platform", "menu_platform", "max pts", 9, 9999);
			int pts = FF2MenuRage_PeekValue(client, "points") + Boss.GetArgI(this_plugin_name, UPGRADE, "points", 7, 5);
			if(max <= pts)
				pts = max;
			FF2MenuRage_SetValue(client, "points", pts);
		}
	}
}
