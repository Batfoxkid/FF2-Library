public Action Handle_RandomTeleport(int client)
{
	ArrayList players = new ArrayList();
	for(int x = 1; x <= MaxClients; x++) 
	{
		if(!ValidatePlayer(x, AnyAlive) || client == x)
			continue;
		
		players.Push(x);
	}
	int boss = FF2_GetBossIndex(client);
	static char buffer[64];
	
	if(!players.Length) {
		if(FF2_RandomSound("sound_teleport_failure", buffer, sizeof(buffer), boss))
			FF2_EmitVoiceToAll2(buffer, client);
		delete players;
		return Plugin_Stop;
	}
	
	if(FF2_RandomSound("sound_teleport_success", buffer, sizeof(buffer), boss))
		FF2_EmitVoiceToAll2(buffer);
	
	FF2Prep Boss = FF2Prep(boss, false);
	
	if(Boss.GetArgS(this_plugin_name, REALITY, "particles", 1, buffer, sizeof(buffer)))
		FixParticlesName(buffer, sizeof(buffer), TF2_GetClientTeam(client));
	
	while(players.Length) {
		if((players.Length - 2) < 0)
			break;
		
		int victim[2];
		static float vecPos[2][3];
		
		for (int i; i < 2; i++) {
			int idx = GetRandomInt(0, players.Length - 1);
			victim[i] = players.Get(idx);
			players.Erase(idx);
			if(i) {
				GetClientAbsOrigin(victim[i], vecPos[i]);
				GetClientAbsOrigin(victim[i-1], vecPos[i-1]);
				TeleportEntity(victim[i], vecPos[i - 1], NULL_VECTOR, NULL_VECTOR);
				TeleportEntity(victim[i - 1], vecPos[i], NULL_VECTOR, NULL_VECTOR);
				if(strlen(buffer) > 3) {
					CreateTimedParticle(victim[i], buffer, vecPos[i - 1], 1.0);
					CreateTimedParticle(victim[i - 1], buffer, vecPos[i], 1.0);
				}
			}
		}
	}
	delete players;
	return Plugin_Handled;
}