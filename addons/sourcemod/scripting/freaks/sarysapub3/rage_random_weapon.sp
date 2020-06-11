
/*
rage_random_weapon

* arg-10 "ams"		"bool"
* arg1 "duration" 	"float"
* arg2 "count"		"int"
* arg3 "sound"		"string"

X = [0, count - 1] + 1
* arg(X*10) 	"classname X" 	"string"
* arg(X*10 + 1) "index X" 		"int"
* arg(X*10 + 2) "attributes X" 	"string"
* arg(X*10 + 3) "visible X" 	"bool"
* arg(X*10 + 4) "alpha X" 		"int"
* arg(X*10 + 5) "ammo X" 		"int"
* arg(X*10 + 6) "clip X" 		"int"
* arg(X*10 + 7) "slot X"		"int"
*/

static bool isActive = false;
static ArrayList slots[MAXCLIENTS];
bool RRW_AMS[MAXCLIENTS];
static float flRemoveThink[MAXCLIENTS][7];


public void Post_RRWThinkPost(int client)
{
	if(!slots[client].Length) {
		return;
	}
	int slot;
	for(int i = 0; i < slots[client].Length; i++) {
		slot = slots[client].Get(i);
		if(flRemoveThink[client][slot] <= GetGameTime()) {
			UTIL_SwitchToNextBestWeapon(client, slot);
			TF2_RemoveWeaponSlot(client, slot);
			slots[client].Erase(i);
		}
	}
}

public void RRW_Invoke(int client, int index)
{
	if(!isActive) {
		isActive = true;
	}
	FF2Prep player = FF2Prep(client);
	
	int count = player.GetArgI(FAST_REG(rage_random_weapon), "count", 2, 0);
	if(count <= 0) {
		char name[48];
		player.BossName(name, sizeof(name));
		LogError("[FF2] Boss: %s has an invalid weapon count (arg2 for \"rage_random_weapon\"", name);
		return;
	}
	
	int offset = GetRandomInt(0, count - 1) + 1;
	char arg[32];
	static char cls[64], attr[128];
	
	count = offset * 10;
	FormatEx(arg, sizeof(arg), "classname %i", count);
	player.GetArgS(FAST_REG(rage_random_weapon), arg, count, cls, sizeof(cls));
	FormatEx(arg, sizeof(arg), "index %i", offset);
	int idx = player.GetArgI(FAST_REG(rage_random_weapon), arg, count + 1, -1);
	FormatEx(arg, sizeof(arg), "attributes %i", offset);
	player.GetArgS(FAST_REG(rage_random_weapon), arg, count + 2, attr, sizeof(attr));
	FormatEx(arg, sizeof(arg), "visible %i", offset);
	bool visible = player.GetArgI(FAST_REG(rage_random_weapon), arg, count + 3, 1) != 0;
	FormatEx(arg, sizeof(arg), "alpha %i", offset);
	int alpha = player.GetArgI(FAST_REG(rage_random_weapon), arg, count + 4, 1);
	FormatEx(arg, sizeof(arg), "ammo %i", offset);
	int ammo = player.GetArgI(FAST_REG(rage_random_weapon), arg, count + 5, 1);
	FormatEx(arg, sizeof(arg), "clip %i", offset);
	int clip = player.GetArgI(FAST_REG(rage_random_weapon), arg, count + 6, 1);
	FormatEx(arg, sizeof(arg), "slot %i", offset);
	int slot = player.GetArgI(FAST_REG(rage_random_weapon), arg, count + 7, 0);
	
	UTIL_SwitchToNextBestWeapon(client, slot);
	TF2_RemoveWeaponSlot(client, slot);
	
	int weapon = FF2_SpawnWeapon(client, cls, idx, 39, 5, attr, visible);
	if(!IsValidEntity(weapon)) {
		char name[48];
		player.BossName(name, sizeof(name));
		LogError("[FF2] Boss: %s has an invalid weapon", name);
		return;
	}
	FF2_SetAmmo(client, weapon, ammo, clip);
	
	if(alpha < 255) {
		SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
		SetEntityRenderColor(weapon, 255, 255, 255, alpha < 0 ? 0:alpha);
	}
	
	if(!DP_IsLatched(client)) {
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}
	
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.5);
	SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 0.5);
	
	if(player.GetArgS(FAST_REG(rage_random_weapon), "sound", 3, attr, sizeof(attr))) {
		EmitSoundToAll(attr);
	}
	
	float duration = player.GetArgF(FAST_REG(rage_random_weapon), "duration", 1, 15.0);
	flRemoveThink[client][slot] = duration <= 0 ? 1000000.0:duration + GetGameTime();
	
	if(!slots[client]) {
		slots[client] = new ArrayList();
		SDKHook(client, SDKHook_PostThinkPost, Post_RRWThinkPost);
	}
	slots[client].Push(slot);
}

public void RRW_RoundEnd()
{
	if(!isActive) {
		return;
	}
	for(int i = 1; i <= MaxClients; i++) {
		if(RRW_AMS[i]) {
			RRW_AMS[i] = false;
			delete slots[i];
			SDKUnhook(i, SDKHook_PostThinkPost, Post_RRWThinkPost);
		}
	}
}

public void RRW_ClientDisconnect(int client)
{
	if(slots[client]) {
		delete slots[client];
	}
}
