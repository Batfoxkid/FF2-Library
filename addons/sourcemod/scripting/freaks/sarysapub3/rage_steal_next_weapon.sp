
/*
rage_random_weapon

* arg-10 "ams"		"bool"
* arg1 "keep duration" 		"float"
* arg2 "steal duration" "float"
* arg2 "sound"		"string"

X = [0, class]
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
bool SNW_AMS[MAXCLIENTS];
static float flStealThink[MAXCLIENTS], flRemoveThink[MAXCLIENTS][7];


public void Post_SNWThinkPost(int client)
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

public void SNW_Invoke(int client, int index)
{
	FF2Prep player = FF2Prep(client);
	static char sound[128];
	if(player.GetArgS(FAST_REG(rage_random_weapon), "sound", 2, sound, sizeof(sound))) {
		EmitSoundToAll(sound);
	}
	flStealThink[client] = GetGameTime() + player.GetArgF(FAST_REG(rage_random_weapon), "keep duration", 1, 15.0);
}

static void StealClassWeapon(int client, int victim)
{
	int offset = view_as<int>(TF2_GetPlayerClass(victim));
	
	FF2Prep player = FF2Prep(client);
	
	char arg[32];
	static char cls[64], attr[128];
	
	int count = offset * 10;
	FormatEx(arg, sizeof(arg), "classname %i", offset);
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
	
	UTIL_SwitchToNextBestWeapon(client, slot);		//is this really necessary?
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
	
	float duration = player.GetArgF(FAST_REG(rage_random_weapon), "steal duration", 2, 15.0);
	flRemoveThink[client][slot] = duration <= 0 ? 1000000.0:duration + GetGameTime();
	
	if(!slots[client]) {
		slots[client] = new ArrayList();
		SDKHook(client, SDKHook_PostThinkPost, Post_SNWThinkPost);
		SDKHook(victim, SDKHook_WeaponCanSwitchTo, SWN_WeaponCanSwitchTo);
	}
	slots[client].Push(slot);
}

public Action SWN_WeaponCanSwitchTo(int victim, int weapon)
{
	int slot = UTIL_GetWeaponSlot(weapon);
	if(slot <= -1 || slot >= sizeof(flRemoveThink[])) {
		return Plugin_Continue;
	}
	
	if(flRemoveThink[victim][slot] > GetGameTime()) {
		EmitGameSoundToClient(victim, "Player.DenyWeaponSelection");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action SNW_OnTakeDamageAlive(int victim, int& attacker, int& inflictor, 
							float& damage, int& damagetype, int& weapon, 
							float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(!isActive) {
		isActive = true;
	}
	if(!ValidatePlayer(victim, IsBoss))
		return Plugin_Continue;
	else if(PlayerIsInvun(victim))
		return Plugin_Continue;
		
	if(GetEngineTime() < flStealThink[attacker] && damagetype & DMG_CLUB) {
		StealClassWeapon(attacker, victim);
	}
		
	return Plugin_Continue;
}

public void SNW_RoundEnd()
{
	if(!isActive) {
		return;
	}
	LoopAnyValidPlayer( \
		SDKUnhook(_x, SDKHook_WeaponCanSwitchTo, SWN_WeaponCanSwitchTo); \
		if(slots[_x]) { \
			delete slots[_x]; \
			SNW_AMS[_x] = false; \
			SDKUnhook(_x, SDKHook_PostThinkPost, Post_SNWThinkPost); \
			SDKUnhook(_x, SDKHook_OnTakeDamageAlive, SNW_OnTakeDamageAlive); \
		} \
	)
	isActive = false;
}
