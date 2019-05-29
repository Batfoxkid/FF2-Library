#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <morecolors>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#define BOSS_HIDE_DEAD_SOUND "misc/halloween/merasmus_disappear.wav"

#define PLUGIN_VERSION "0.1"

new Handle:chargeHUD;
new BossTeam=_:TFTeam_Blue;
new bool:gb_ghost;
new bool:hide_death;

public Plugin:myinfo=
{
	name="Freak Fortress 2: Luigi's Mansion Ghost Abilittypack",
	author="Benoist3012",
	description="FF2: Luigi's Mansion Ghost",
	version=PLUGIN_VERSION
};
public OnPluginStart2()
{
	HookEvent("teamplay_round_active", event_round_active, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", event_round_active, EventHookMode_PostNoCopy); 
	HookEvent("player_death", event_player_death, EventHookMode_Pre);
	LoadTranslations("ff2_luigi_ghost.phrases");
}
public OnMapStart()
{
	chargeHUD = CreateHudSynchronizer();
	PrecacheSound(BOSS_HIDE_DEAD_SOUND,true);
}
public event_round_active(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(0.3, Timer_GetBossTeam);
	gb_ghost = false;
	hide_death = false;
	if(FF2_HasAbility( 0, this_plugin_name, "invisible_ghost" ))
	{
		new client = GetClientOfUserId(FF2_GetBossUserId(0));
		if(client && IsClientInGame(client) && IsPlayerAlive(client))
		{
			gb_ghost = true;
		}
		for (new iclient = 1; iclient <= MaxClients; iclient++)
		{
			if (IsValidEdict(iclient))
				OnClientPutInServer(iclient);
		}
	}
	if(FF2_HasAbility( 0, this_plugin_name, "hide_on_death" ))
	{
		hide_death = true;
	}
}
public Action:Timer_GetBossTeam(Handle:hTimer)
{
	BossTeam=FF2_GetBossTeam();
	return Plugin_Continue;
}
public OnClientPutInServer(iclient)
{
    SDKHook(iclient, SDKHook_OnTakeDamage, OnTakeDamage);
}
public Action:OnTakeDamage(iClient, &iAttacker, &iInflictor, &Float:fDamage, &iDamageBits, &iWeapon, Float:flDamageForce[3], Float:flDamagePosition[3], iDamageCustom )
{
    if (iClient <= 0 || iClient > MaxClients) 
        return Plugin_Continue;

    if (IsClientInGame(iClient))
	{
		
		if(!gb_ghost)
		{
			return Plugin_Continue;
		}
		new Boss = GetClientOfUserId(FF2_GetBossUserId(0));
		if(GetClientTeam(iClient) != BossTeam && iAttacker == Boss && !TF2_IsPlayerInCondition(iClient,TFCond_Ubercharged) && !TF2_IsPlayerInCondition(iAttacker,TFCond_Stealthed) && TF2_IsPlayerInCondition(iClient,TFCond_HalloweenSpeedBoost))
		{
			fDamage = 300.0;
			return Plugin_Changed;
		}
		else if(GetClientTeam(iClient) != GetClientTeam(Boss) && iAttacker == Boss && !TF2_IsPlayerInCondition(iClient,TFCond_Ubercharged) && !TF2_IsPlayerInCondition(iAttacker,TFCond_Stealthed) && !TF2_IsPlayerInCondition(iClient,TFCond_HalloweenSpeedBoost))
		{
			TF2_StunPlayer(iClient, 3.0, 0.0, TF_STUNFLAGS_GHOSTSCARE|TF_STUNFLAG_SLOWDOWN, iAttacker);
			TF2_AddCondition(iClient, TFCond_HalloweenSpeedBoost, 3.0);
			fDamage = 0.0;
			return Plugin_Changed;
		}
		if(GetClientTeam(iClient) != BossTeam && iAttacker == Boss && TF2_IsPlayerInCondition(iAttacker,TFCond_Stealthed))
		{
			fDamage = 0.0;
			return Plugin_Changed;
		}
    }
    return Plugin_Continue;
}
public Action:FF2_OnAbility2(index, const String:plugin_name[], const String:ability_name[], status)
{
	if(!strcmp(ability_name, "invisible_ghost"))
	{
		Charge_Invisible(ability_name, index, status);	
	}
	else if(!strcmp(ability_name, "rage_spawn_ghost"))
	{
		Charge_spawn_ghost(ability_name, index);		
	}
	return Plugin_Continue;
}
Charge_spawn_ghost(const String:ability_name[],index)
{
	new boss=GetClientOfUserId(FF2_GetBossUserId(index));
	decl String:model[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(index, this_plugin_name, ability_name, 1, model, sizeof(model));
	new maxminion = FF2_GetAbilityArgument(index,this_plugin_name, ability_name, 2);
	new String:classname[64]="tf_weapon_bottle";
	FF2_GetAbilityArgumentString(index, this_plugin_name, ability_name, 3, classname, sizeof(classname));
	new windex=FF2_GetAbilityArgument(index, this_plugin_name, ability_name, 4, 191);
	new String:attributes[64]="68 ; -1";
	FF2_GetAbilityArgumentString(index, this_plugin_name, ability_name, 5, attributes, sizeof(attributes));
	new health=FF2_GetAbilityArgument(index, this_plugin_name, ability_name, 6, 0);
	
	new ii;
	for (new i=0; i<maxminion; i++)
	{
		ii = GetRandomDeadPlayer();
		if(ii != -1)
		{
			FF2_SetFF2flags(ii,FF2_GetFF2flags(ii)|FF2FLAG_ALLOWSPAWNINBOSSTEAM);
			ChangeClientTeam(ii,BossTeam);
			TF2_RespawnPlayer(ii);
			if (TF2_GetPlayerClass(ii) != TFClass_DemoMan) TF2_SetPlayerClass(ii, TFClass_DemoMan);
			SetEntPropFloat(ii, Prop_Send, "m_flModelScale", 0.5);
			SetVariantString(model);
			AcceptEntityInput(ii, "SetCustomModel");
			SetEntProp(ii, Prop_Send, "m_bUseClassAnimations", 1);
			SetEntityRenderColor(ii, 45, 79, 10, 255);
			new weapon;
			TF2_RemoveAllWeapons(ii);
			if(classname[0]=='\0')
			{
				classname="tf_weapon_bottle";
			}

			if(attributes[0]=='\0')
			{
				attributes="68 ; -1";
			}
			weapon=SpawnWeapon(ii, classname, windex, 101, 0, attributes);
			if(IsValidEdict(weapon))
			{
				SetEntPropEnt(ii, Prop_Send, "m_hActiveWeapon", weapon);
				SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", -1);
				SetEntProp(weapon, Prop_Send, "m_nModelIndexOverrides", -1, _, 0);
			}
			SetEntProp(ii, Prop_Data, "m_iMaxHealth", health);
			SetEntProp(ii, Prop_Data, "m_iHealth", health);
			SetEntProp(ii, Prop_Send, "m_iHealth", health);
			new Float:velocity[3];
			new Float:position[3];
			GetEntPropVector(boss, Prop_Data, "m_vecOrigin", position);
			velocity[0]=GetRandomFloat(300.0, 500.0)*(GetRandomInt(0, 1) ? 1:-1);
			velocity[1]=GetRandomFloat(300.0, 500.0)*(GetRandomInt(0, 1) ? 1:-1);
			velocity[2]=GetRandomFloat(300.0, 500.0);
			TeleportEntity(ii, position, NULL_VECTOR, velocity);
			new Handle:data;
			CreateDataTimer(0.1, Timer_EquipModel, data, TIMER_FLAG_NO_MAPCHANGE);
			WritePackCell(data, GetClientUserId(ii));
			WritePackString(data, model);
		}
	}
	new entity, owner;
	while((entity=FindEntityByClassname(entity, "tf_wearable"))!=-1)
	{
		if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==BossTeam)
		{
			TF2_RemoveWearable(owner, entity);
		}
	}

	while((entity=FindEntityByClassname(entity, "tf_wearable_demoshield"))!=-1)
	{
		if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==BossTeam)
		{
			TF2_RemoveWearable(owner, entity);
		}
	}

	while((entity=FindEntityByClassname(entity, "tf_powerup_bottle"))!=-1)
	{
		if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==BossTeam)
		{
			TF2_RemoveWearable(owner, entity);
		}
	}
}
public Action:Timer_EquipModel(Handle:timer, any:pack)
{
	ResetPack(pack);
	new client=GetClientOfUserId(ReadPackCell(pack));
	if(client && IsClientInGame(client) && IsPlayerAlive(client))
	{
		decl String:model[PLATFORM_MAX_PATH];
		ReadPackString(pack, model, PLATFORM_MAX_PATH);
		SetVariantString(model);
		AcceptEntityInput(client, "SetCustomModel");
		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
	}
}
Charge_Invisible(const String:ability_name[],index,action)
{
	new Float:duration = FF2_GetAbilityArgumentFloat(index,this_plugin_name,ability_name, 1);
	new Float:zero_charge = FF2_GetBossCharge(index,0);
	new boss=GetClientOfUserId(FF2_GetBossUserId(index));
	if(zero_charge<1)
	{
		MakePlayerInvisible(boss, 255);
		return;
	}
	
	switch(action)
	{
		case 1:
		{
			if(gb_ghost)
			{
				TF2_RemoveCondition(boss, TFCond_Stealthed);
				MakePlayerInvisible(boss, 255);
			}
		}
		case 2:
		{
			if(gb_ghost)
			{
				TF2_RemoveCondition(boss, TFCond_OnFire);
				MakePlayerInvisible(boss, 0);
				FF2_SetBossCharge(index,0,zero_charge-0.2);
				TF2_AddCondition(boss, TFCond_Stealthed, duration);
				SetHudTextParams(-1.0, 0.93, 0.15, 255, 255, 255, 255);
				ShowSyncHudText(boss, chargeHUD, "%t","charge_case2");
			}
		}
		default:
		{
			if(gb_ghost)
			{
				MakePlayerInvisible(boss, 255);
				SetHudTextParams(-1.0, 0.93, 0.15, 255, 255, 255, 255);
				ShowSyncHudText(boss, chargeHUD, "%t","charge_ready_invisible");
			}
		}
	}
}
public Action:event_player_death(Handle:hEvent, const String:strEventName[], bool:bDontBroadcast)
{
	new attackerId = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	new Boss = GetClientOfUserId(FF2_GetBossUserId(0));
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(gb_ghost)
	{	
		if(attackerId == Boss && GetClientTeam(client) != BossTeam)
		{
			SetEventString(hEvent, "weapon_logclassname", "cry");
			SetEventString(hEvent, "weapon", "merasmus_zap");
		}
		if(GetClientTeam(client) != BossTeam && attackerId != Boss && GetClientTeam(attackerId) == BossTeam)
		{
			SetEventString(hEvent, "weapon_logclassname", "bomb");
			SetEventString(hEvent, "weapon", "tf_pumpkin_bomb");
			SetEventInt(hEvent, "customkill", TF_CUSTOM_PUMPKIN_BOMB);
		}
	}
	if(hide_death)
	{
		if(client == Boss)
		{
			SetVariantString("");
			AcceptEntityInput(Boss, "SetCustomModel");
			AttachParticle(Boss, "merasmus_tp");
			EmitSoundToAll(BOSS_HIDE_DEAD_SOUND);
			CreateTimer(0.0, RemoveBody, client);
		}
		if(GetClientTeam(client) == BossTeam && client != Boss)
		{
			SetVariantString("");
			AcceptEntityInput(client, "SetCustomModel");
			AttachParticle(client, "merasmus_tp");
			EmitSoundToAll(BOSS_HIDE_DEAD_SOUND);
			CreateTimer(0.0, RemoveBody, client);
		}
	}
}
public Action:RemoveBody(Handle:Timer, any:Client)
{
	decl BodyRagdoll;
	BodyRagdoll = GetEntPropEnt(Client, Prop_Send, "m_hRagdoll");
	if(IsValidEdict(BodyRagdoll))
	{
		RemoveEdict(BodyRagdoll);
	}
}
stock MakePlayerInvisible(client, alpha)
{
	SetWeaponsAlpha(client, alpha);
	SetWearablesAlpha(client, alpha);
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntityRenderColor(client, 255, 255, 255, alpha);
}
stock SetWeaponsAlpha (client, alpha)
{
	decl String:classname[64];
	new m_hMyWeapons = FindSendPropOffs("CBasePlayer", "m_hMyWeapons");
	for(new i = 0, weapon; i < 189; i += 4)
	{
		weapon = GetEntDataEnt2(client, m_hMyWeapons + i);
		if(weapon > -1 && IsValidEdict(weapon))
		{
			GetEdictClassname(weapon, classname, sizeof(classname));
			if(StrContains(classname, "tf_weapon", false) != -1 || StrContains(classname, "tf_wearable", false) != -1)
			{
				SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
				SetEntityRenderColor(weapon, 255, 255, 255, alpha);
			}
		}
	}
}
stock SetWearablesAlpha (client, alpha)
{
	if(IsPlayerAlive(client))
	{
		new Float:pos[3], Float:wearablepos[3];
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
		new wearable= -1;
		while ((wearable= FindEntityByClassname(wearable, "tf_wearable")) != -1)
		{
			GetEntPropVector(wearable, Prop_Data, "m_vecAbsOrigin", wearablepos);
			if (GetVectorDistance(pos, wearablepos, true) < 2)
			{
				SetEntityRenderMode(wearable, RENDER_TRANSCOLOR);
				SetEntityRenderColor(wearable, 255, 255, 255, alpha);
			}
		}
		while ((wearable= FindEntityByClassname(wearable, "tf_wearable_item_demoshield")) != -1)
		{
			GetEntPropVector(wearable, Prop_Data, "m_vecAbsOrigin", wearablepos); 
			if (GetVectorDistance(pos, wearablepos, true) < 2)
			{
				SetEntityRenderMode(wearable, RENDER_TRANSCOLOR);
				SetEntityRenderColor(wearable, 255, 255, 255, alpha);
			}
		}
	}
}
stock IsValidClient(client, bool:replaycheck=true)
{
	if(client<=0 || client>MaxClients)
	{
		return false;
	}

	if(!IsClientInGame(client))
	{
		return false;
	}

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
	{
		return false;
	}

	if(replaycheck)
	{
		if(IsClientSourceTV(client) || IsClientReplay(client))
		{
			return false;
		}
	}
	return true;
}
stock GetRandomDeadPlayer()
{
	new clients[MaxClients+1], clientCount;
	for(new i=1;i<=MaxClients;i++)
	{
		if (IsValidEdict(i) && IsClientConnected(i) && IsClientInGame(i) && !IsPlayerAlive(i) && (GetClientTeam(i) > 1))
		{
			clients[clientCount++] = i;
		}
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}
stock AttachParticle(entity, String:particleType[], Float:offset[]={0.0,0.0,0.0}, bool:attach=true)
{
	new particle=CreateEntityByName("info_particle_system");

	decl String:targetName[128];
	decl Float:position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	position[0]+=offset[0];
	position[1]+=offset[1];
	position[2]+=offset[2];
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

	Format(targetName, sizeof(targetName), "target%i", entity);
	DispatchKeyValue(entity, "targetname", targetName);

	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", targetName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(targetName);
	if(attach)
	{
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	}
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	CreateTimer(10.0, DeleteParticle, particle);
	return particle;
}
public Action:DeleteParticle(Handle:timer, any:Ent)
{
	if (!IsValidEntity(Ent)) return;
	new String:cls[25];
	GetEdictClassname(Ent, cls, sizeof(cls));
	if (StrEqual(cls, "info_particle_system", false)) AcceptEntityInput(Ent, "Kill");
	return;
}
stock SpawnWeapon(client, String:name[], index, level, quality, String:attribute[])
{
	new Handle:weapon=TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(weapon, name);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, quality);
	new String:attributes[32][32];
	new count = ExplodeString(attribute, ";", attributes, 32, 32);
	if(count%2!=0)
	{
		count--;
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(weapon, count/2);
		new i2=0;
		for(new i=0; i<count; i+=2)
		{
			new attrib=StringToInt(attributes[i]);
			if(attrib==0)
			{
				LogError("Bad weapon attribute passed: %s ; %s", attributes[i], attributes[i+1]);
				return -1;
			}
			TF2Items_SetAttribute(weapon, i2, attrib, StringToFloat(attributes[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(weapon, 0);
	}

	if(weapon==INVALID_HANDLE)
	{
		return -1;
	}
	new entity=TF2Items_GiveNamedItem(client, weapon);
	CloseHandle(weapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}