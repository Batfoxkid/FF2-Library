#define BOSS_SPECIAL_ORB_KEY "special_orb"

#define ORB_OFFSET			40.0			// z offset
#define ORB_REFRESH_TIME	4.8				// time before making a new orb to extend time (stops around 5)
#define MIN_ORB_DISTANCE	200.0			// dead zone, to stop moving them when they are near orb, or it will bug out/be annoying

float gf_Special_orb_damage;
float gf_Special_orb_range;
float gf_Special_orb_force;
float gf_Special_orb_duration;
float gf_Special_orb_speed;

void Special_Orb_FF2_OnAbility2(const char[] ability_name)
{
	if (StrEqual(ability_name, BOSS_SPECIAL_ORB_KEY))
	{
		Rage_UseSpecial_Orb();
	}
}

void Special_Orb_event_round_active()
{
	gf_Special_orb_damage = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_SPECIAL_ORB_KEY, 1, 5.0);
	gf_Special_orb_range = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_SPECIAL_ORB_KEY, 2, 600.0);
	gf_Special_orb_force = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_SPECIAL_ORB_KEY, 3, 400.0);
	gf_Special_orb_duration = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_SPECIAL_ORB_KEY, 4, 10.0);
	gf_Special_orb_speed = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_SPECIAL_ORB_KEY, 5, 0.0);
}

int Special_Orb_OnTakeDamage(int attacker, float& damage, int inflictor)
{
	static char classname[27];
	
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

void Rage_UseSpecial_Orb()
{
	static float origin[3];
	GetClientAbsOrigin(g_boss, origin);

	int entity = Orb_Create(origin);
	if(entity != -1)
	{
		float time = GetEngineTime();
	
		DataPack pack = new DataPack();
		pack.WriteCell(EntIndexToEntRef(entity));
		pack.WriteFloat(time + gf_Special_orb_duration);
		pack.WriteFloat(time + ORB_REFRESH_TIME);
		RequestFrame(Frame_OrbThink, pack);
	}
}

int Orb_Create(float origin[3])
{
	int entity = CreateEntityByName("tf_projectile_lightningorb");
	if (entity != -1)
	{
		DispatchKeyValueVector(entity, "origin", origin);
		DispatchSpawn(entity);
		
		SetEntProp(entity, Prop_Send, "m_CollisionGroup", 4);
		SetEntProp(entity, Prop_Send, "m_iTeamNum", g_bossteam);
		SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", g_boss); // store attacker
		SetEntProp(entity, Prop_Data, "m_takedamage", 0);
		SetEntPropVector(entity, Prop_Send, "m_vecMins", view_as<float>({0.0, 0.0, 0.0}));
		SetEntPropVector(entity, Prop_Send, "m_vecMaxs", view_as<float>({0.0, 0.0, 0.0}));
		
		SetEntityMoveType(entity, MOVETYPE_NOCLIP);
	}
	
	return entity;
}

public void Frame_OrbThink(DataPack pack)
{
	static float pos1[3], pos2[3], pos3[3];
	static float force, time, endtime, distance;
	static int entity;

	pack.Reset();

	entity = EntRefToEntIndex(pack.ReadCell());

	if(entity != INVALID_ENT_REFERENCE)
	{
		if(g_bosstype == BOSS_SPECIAL_ORB && g_boss && IsClientInGame(g_boss) && IsPlayerAlive(g_boss))
		{
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos2);

			time = GetEngineTime();
			endtime = pack.ReadFloat();
			if(time > endtime)						// time elapsed
			{
				#if defined DEBUG
				PrintToChatAll("Total Duration complete: %f %f", time, endtime);
				#endif

				AcceptEntityInput(entity, "Kill");
				delete pack;
				return;
			}
			else if(time > pack.ReadFloat())		// need new orb
			{
				#if defined DEBUG
				PrintToChatAll("Orb complete: %f", time);
				#endif
			
				AcceptEntityInput(entity, "Kill");
				
				delete pack;					// destroy the old pack

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
				
				pack = new DataPack();
				pack.WriteCell(EntIndexToEntRef(entity));
				pack.WriteFloat(endtime);
				pack.WriteFloat(time + ORB_REFRESH_TIME);
			}
			
			GetClientAbsOrigin(g_boss, pos1);
			pos1[2] += ORB_OFFSET;

			for(int target = 1; target<=MaxClients; target++)
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

stock bool Orb_CanSeeHere(float clientpos[3], float clienteyepos[3])
{
    TR_TraceRayFilter(clienteyepos, clientpos, MASK_SOLID, RayType_EndPoint, Orb_TraceEntityFilterWorld);
    return !TR_DidHit(INVALID_HANDLE);
}

public bool Orb_TraceEntityFilterWorld(int entityhit, int mask)
{
	if (entityhit == 0) // I only want it to hit terrain, no models or debris
	{
		return true;
	}
	return false;
}
