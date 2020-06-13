
/*
rage_ams_dynamic_teleport

* arg-10 "ams"		"bool"
* arg1 ""
* arg2 "sound"
* arg3 "max to work"	"int"

*/

static bool isActive = false;
bool DT_AMS[MAXCLIENTS];


public AMSResult DT_CanInvoke(int client, int index)
{
	int max = FF2Prep(client).GetArgI(FAST_REG(rage_ams_dynamic_teleport), "max to work", 3, -1);
	if(max <= 0) {
		return AMS_Accept;
	}
	int team = GetClientTeam(client) == FF2_GetBossTeam() ? infos.bosses:infos.players;
	return team <= max ? AMS_Accept:AMS_Deny;
}

public void DT_Invoke(int client, int index)
{
	FF2Prep player = FF2Prep(client);
	float stun = player.GetArgF(FAST_REG(rage_ams_dynamic_teleport), "stun duration", 1, 2.0);
	if(!FF2_TryTeleport(client, stun, false)) {
		return;
	}

	char snd[128];
	if(player.GetArgS(FAST_REG(rage_ams_dynamic_teleport), "sound", 2, snd, sizeof(snd))) {
		EmitSoundToAll(snd);
	}
}


public void DT_RoundEnd()
{
	if(!isActive) {
		return;
	}
	LoopAnyValidPlayer( \
		if(DT_AMS[_x]) { \
			DT_AMS[_x] = false; \
		} \
	)
	isActive = false;
}
