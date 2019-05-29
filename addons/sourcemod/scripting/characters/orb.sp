#define BOSS_SPECIAL_ORB_KEY "special_orb"

#define ORB_OFFSET			40.0			// z offset
#define ORB_REFRESH_TIME	4.8				// time before making a new orb to extend time (stops around 5)
#define MIN_ORB_DISTANCE	200.0			// dead zone, to stop moving them when they are near orb, or it will bug out/be annoying

new Float:gf_Special_orb_damage;
new Float:gf_Special_orb_range;
new Float:gf_Special_orb_force;
new Float:gf_Special_orb_duration;
new Float:gf_Special_orb_speed;

Special_Orb_FF2_OnAbility2(const String:ability_name[])
{
	if (StrEqual(ability_name, BOSS_SPECIAL_ORB_KEY))
	{
		Rage_UseSpecial_Orb();
	}
}

Special_Orb_event_round_active()
{
	gf_Special_orb_damage = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_SPECIAL_ORB_KEY, 1, 5.0);
	gf_Special_orb_range = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_SPECIAL_ORB_KEY, 2, 600.0);
	gf_Special_orb_force = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_SPECIAL_ORB_KEY, 3, 400.0);
	gf_Special_orb_duration = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_SPECIAL_ORB_KEY, 4, 10.0);
	gf_Special_orb_speed = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_SPECIAL_ORB_KEY, 5, 0.0);
}

Special_Orb_OnTakeDamage(attacker, &Float:damage, inflictor)
{
	static String:classname[27];
	
	if (attacker == g_boss)
	{
		GetEntityClassname(inflictor, classname, 27);
		
		if (StrEqual(classname, "tf_projectile_lightningorb"))
		{
			damage = gf_Special_orb_damage;
			
			return ACTION_CHANGED;
		}
	}
	return ACTION_CONTINUE;
}

//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////  Active Rages

Rage_UseSpecial_Orb()
{
	decl Float:origin[3];
	GetClientAbsOrigin(g_boss, origin);

	new entity = Orb_Create(origin);
	if(entity != -1)
	{
		new Float:time = GetEngineTime();
	
		new Handle:pack = CreateDataPack();
		WritePackCell(pack, EntIndexToEntRef(entity));
		WritePackFloat(pack, time + gf_Special_orb_duration);
		WritePackFloat(pack, time + ORB_REFRESH_TIME);
		RequestFrame(Frame_OrbThink, pack);
	}
}

Orb_Create(Float:origin[3])
{
	new entity = CreateEntityByName("tf_projectile_lightningorb");
	if (entity != -1)
	{
		DispatchKeyValueVector(entity, "origin", origin);
		DispatchSpawn(entity);
		
		SetEntProp(entity, Prop_Send, "m_CollisionGroup", 4);
		SetEntProp(entity, Prop_Send, "m_iTeamNum", g_bossteam);
		SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", g_boss); // store attacker
		SetEntProp(entity, Prop_Data, "m_takedamage", 0);
		SetEntPropVector(entity, Prop_Send, "m_vecMins", Float: { 0.0, 0.0, 0.0 } );
		SetEntPropVector(entity, Prop_Send, "m_vecMaxs", Float: { 0.0, 0.0, 0.0 } );
		
		SetEntityMoveType(entity, MOVETYPE_NOCLIP);
	}
	
	return entity;
}

public Frame_OrbThink(Handle:pack)
{
	static Float:pos1[3], Float:pos2[3], Float:pos3[3];
	static Float:force, Float:time, Float:endtime, Float:distance;
	static entity;

	ResetPack(pack);

	entity = EntRefToEntIndex(ReadPackCell(pack));

	if(entity != INVALID_ENT_REFERENCE)
	{
		if(g_bosstype == BOSS_SPECIAL_ORB && g_boss && IsClientInGame(g_boss) && IsPlayerAlive(g_boss))
		{
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos2);

			time = GetEngineTime();
			endtime = ReadPackFloat(pack);
			if(time > endtime)						// time elapsed
			{
				#if defined DEBUG
				PrintToChatAll("Total Duration complete: %f %f", time, endtime);
				#endif

				AcceptEntityInput(entity, "Kill");
				CloseHandle(pack);
				return;
			}
			else if(time > ReadPackFloat(pack))		// need new orb
			{
				#if defined DEBUG
				PrintToChatAll("Orb complete: %f", time);
				#endif
			
				AcceptEntityInput(entity, "Kill");
				
				CloseHandle(pack);					// destroy the old pack

				entity = Orb_Create(pos2);
				if(entity == -1)					// fail
				{
					#if defined DEBUG
					PrintToChatAll("Failed to create new orb!");
					#endif
				
					return;
				}

				#if defined DEBUG
				PrintToChatAll("New orb created");
				#endif
				
				pack = CreateDataPack();
				WritePackCell(pack, EntIndexToEntRef(entity));
				WritePackFloat(pack, endtime);
				WritePackFloat(pack, time + ORB_REFRESH_TIME);
			}
			
			GetClientAbsOrigin(g_boss, pos1);
			pos1[2] += ORB_OFFSET;

			for(new target = 1; target<=MaxClients; target++)
			{
				if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target) == g_otherteam)
				{
					GetClientAbsOrigin(target, pos3);
					distance = GetVectorDistance(pos2, pos3);
					force = distance - gf_Special_orb_range;
					if(force < 0.0 && distance > MIN_ORB_DISTANCE && Orb_CanSeeHere(pos2, pos3))
					{
						force = (force/gf_Special_orb_range) * gf_Special_orb_force;
						
						SubtractVectors(pos3, pos2, pos3);
						NormalizeVector(pos3, pos3);
						ScaleVector(pos3, force);
						
						SetEntPropEnt(target, Prop_Send, "m_hGroundEntity", -1 );
						TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, pos3);
					}
				}
			}
	
			if(gf_Special_orb_speed)
			{
				SubtractVectors(pos1, pos2, pos1);
				NormalizeVector(pos1, pos1);
				ScaleVector(pos1, gf_Special_orb_speed);
				
				TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, pos1);
			}
			else
			{
				TeleportEntity(entity, pos1, NULL_VECTOR, NULL_VECTOR);
			}
	
			RequestFrame(Frame_OrbThink, pack);
			
			return;
		}
		else
		{
			AcceptEntityInput(entity, "Kill");
		}
	}

	CloseHandle(pack);
}

stock bool:Orb_CanSeeHere(Float:clientpos[3], Float:clienteyepos[3])
{
    TR_TraceRayFilter(clienteyepos, clientpos, MASK_SOLID, RayType_EndPoint, Orb_TraceEntityFilterWorld);
    return !TR_DidHit(INVALID_HANDLE);
}

public bool:Orb_TraceEntityFilterWorld(entityhit, mask)
{
	if (entityhit == 0) // I only want it to hit terrain, no models or debris
	{
		return true;
	}
	return false;
}