#define BOSS_FASTZOMBIE_KEY "special_fastzombie"

#define ZOMBIE_MIN_BLOODDMG 15

static String:gs_zombiechatter[][] = {
    "npc/zombie/zombie_voice_idle1.wav",
    "npc/zombie/zombie_voice_idle2.wav",
    "npc/zombie/zombie_voice_idle3.wav",
    "npc/zombie/zombie_voice_idle4.wav",
    "npc/zombie/zombie_voice_idle5.wav",
    "npc/zombie/zombie_voice_idle6.wav",
    "npc/zombie/zombie_voice_idle7.wav",
    "npc/zombie/zombie_voice_idle8.wav",
    "npc/zombie/zombie_voice_idle9.wav",
    "npc/zombie/zombie_voice_idle10.wav",
    "npc/zombie/zombie_voice_idle11.wav",
    "npc/zombie/zombie_voice_idle12.wav",
    "npc/zombie/zombie_voice_idle13.wav",
    "npc/zombie/zombie_voice_idle14.wav"
};

new TFClassType:Zombie_LastClass[MAXPLAYERS+1];

new TFClassType:g_fastzombie_class;
new g_fastzombie_weaponindex;
new Float:gf_fastzombie_ratio, Float:gf_fastzombie_protection, Float:gf_fastzombie_healtime;
new String:gs_fastzombie_model[PLATFORM_MAX_PATH];
new String:gs_fastzombie_weaponclassname[64];
new String:gs_fastzombie_weaponattributes[128];
new g_zombiechattermin, g_zombiechattermax;
new g_zombiespray, g_zombieblood;

Fastzombie_FF2_OnAbility2(index,const String:ability_name[])
{
    if (StrEqual(ability_name,BOSS_FASTZOMBIE_KEY))
    {
        Rage_UseFastZombie(index);
    }
}

Fastzombie_event_round_active()
{
    g_zombiespray = PrecacheModel("materials/sprites/bloodspray.vmt", true);
    g_zombieblood = PrecacheModel("materials/sprites/blood.vmt", true);

    for(new i; i<sizeof(gs_zombiechatter); i++)
    {
        PrecacheSound(gs_zombiechatter[i]);
    }

    g_fastzombie_class = TFClassType:FF2_GetAbilityArgument(0, this_plugin_name, BOSS_FASTZOMBIE_KEY, 1, 1);			  // class
    FF2_GetAbilityArgumentString(0, this_plugin_name, BOSS_FASTZOMBIE_KEY, 2, gs_fastzombie_model, PLATFORM_MAX_PATH);   // modelpath
    if(gs_fastzombie_model[0] != '\0')
    {
        PrecacheModel(gs_fastzombie_model);
    }
    gf_fastzombie_ratio = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_FASTZOMBIE_KEY, 3, 1.0);			      // Ratio
    if(gf_fastzombie_ratio < 0.0)
    {
        gf_fastzombie_ratio = 1.0;
    }
    FF2_GetAbilityArgumentString(0, this_plugin_name, BOSS_FASTZOMBIE_KEY, 4, gs_fastzombie_weaponclassname, 64);       // classname
    g_fastzombie_weaponindex = FF2_GetAbilityArgument(0, this_plugin_name, BOSS_FASTZOMBIE_KEY, 5, 264);				  // index
    FF2_GetAbilityArgumentString(0, this_plugin_name, BOSS_FASTZOMBIE_KEY, 6, gs_fastzombie_weaponattributes, 128);	  // attribs
    gf_fastzombie_protection = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_FASTZOMBIE_KEY, 7, 2.0);            // protection len
    gf_fastzombie_healtime = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_FASTZOMBIE_KEY, 8, 2.0);              // heal len 
    g_zombiechattermin = FF2_GetAbilityArgument(0, this_plugin_name, BOSS_FASTZOMBIE_KEY, 9, 10);
    g_zombiechattermax = FF2_GetAbilityArgument(0, this_plugin_name, BOSS_FASTZOMBIE_KEY, 10, 20);
    
    for(new i=1;i<=MaxClients;i++)
    {
        if(IsClientInGame(i) && IsPlayerAlive(i))
        {
            Zombie_LastClass[i] = TF2_GetPlayerClass(i);
        }
        else
        {
            Zombie_LastClass[i] = TFClass_Unknown;
        }
    }
}

Fastzombie_OnTakeDamage(victim, Float:damage, Float:damagePosition[3])
{
    static lastsound[MAXPLAYERS+1];

    if(GetClientTeam(victim) == g_bossteam)
    {
        new time = GetTime();
        if(lastsound[victim] < time)
        {
            lastsound[victim]  = GetRandomInt(g_zombiechattermin, g_zombiechattermax) + time;
            EmitSoundToAll(gs_zombiechatter[GetRandomInt(0, sizeof(gs_zombiechatter)-1)], victim, SNDCHAN_VOICE);
        }
        
        if(damage > ZOMBIE_MIN_BLOODDMG)
        {
            decl Float:vecRt[3];
            GetVectorVectors(damagePosition, vecRt, NULL_VECTOR);
            TE_SetupBloodSprite(damagePosition, vecRt, {255, 230, 80, 255}, GetRandomInt(10,25), g_zombiespray, g_zombieblood);							// set up blood spray
            TE_SendToAll();
        }
    }
    return ACTION_CONTINUE;
}

Fastzombie_event_player_death(client, userid, attacker, deathflags)
{
    if (deathflags & TF_DEATHFLAG_DEADRINGER)                   // if it's a spy, the boss could think the zombie spawned at spawn
    {
        return;
    }

    if (client == g_boss)          // victim is a boss
    {
        for(new target = 1; target <= MaxClients; target++)     // the boss died, kill his minions and restore the classes of everyone
        {
            if (IsClientInGame(target) && IsPlayerAlive(client) && GetClientTeam(target) == g_bossteam)
            {
                ForcePlayerSuicide(target);                    // force this event to fire for the client, and restore their class via the method below
            }
        }
    }
    else
    {
        if(attacker == g_boss && client != g_boss)             // boss killed a player
        {
            decl Float:origin[3], Float:angles[3], Float:velocity[3];
        
            GetClientAbsOrigin(client, origin);
            GetClientEyeAngles(client, angles);
            GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);

            new Handle:data;
            CreateDataTimer(0.1, Timer_CreateSingleZombie, data);
            WritePackCell(data, userid);
            WritePackFloat(data, origin[0]);
            WritePackFloat(data, origin[1]);
            WritePackFloat(data, origin[2]);
            WritePackFloat(data, angles[0]);
            WritePackFloat(data, angles[1]);
            WritePackFloat(data, angles[2]);
            WritePackFloat(data, velocity[0]);
            WritePackFloat(data, velocity[1]);
            WritePackFloat(data, velocity[2]);
        }
        else                                                     //player somehow died
        {
            CreateTimer(0.1, Timer_RestoreZombie_LastClass, userid);
        }
    }
}

public Action:Timer_CreateSingleZombie(Handle:timer, any:pack)
{
    ResetPack(pack);
    new client = GetClientOfUserId(ReadPackCell(pack));
    if(client && IsClientInGame(client) && !IsPlayerAlive(client) && g_bosstype == BOSS_FASTZOMBIE)
    {
        decl Float:origin[3], Float:angles[3], Float:velocity[3];

        origin[0] = ReadPackFloat(pack); 
        origin[1] = ReadPackFloat(pack);
        origin[2] = ReadPackFloat(pack);
        angles[0] = ReadPackFloat(pack);
        angles[1] = ReadPackFloat(pack);
        angles[2] = ReadPackFloat(pack);
        velocity[0] = ReadPackFloat(pack);
        velocity[1] = ReadPackFloat(pack);
        velocity[2] = ReadPackFloat(pack);
        CreateZombieMinion(client, g_boss, true, origin, angles, velocity);
    }
}

public Action:Timer_RestoreZombie_LastClass(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);
    if(client && IsClientInGame(client) && FF2_GetBossIndex(client) == -1)
    {
        if (Zombie_LastClass[client])
        {
            TF2_SetPlayerClass(client,Zombie_LastClass[client]);
        }

        ChangeClientTeam(client, g_otherteam);
        SetVariantString("");
        AcceptEntityInput(client, "SetCustomModel");
    }

    return Plugin_Continue;
}

Fastzombie_event_round_end()
{
    if(FF2_GetRoundState())
    {
        for(new client = 1; client <= MaxClients; client++)
        {
            if (IsClientInGame(client) && GetClientTeam(client) == g_bossteam && FF2_GetBossIndex(client) == -1)
            {
                CreateTimer(0.1, Timer_RestoreZombie_LastClass, GetClientUserId(client));
            }
        }
    }
}

//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////  Active Rages

Rage_UseFastZombie(index)
{
    new Boss=GetClientOfUserId(FF2_GetBossUserId(index));

    new alive;
    new dead;
    decl team;
    new Handle:hPlayers = CreateArray();
    for(new client=1;client<=MaxClients;client++)
    {
        if (IsClientInGame(client))
        {
            team = GetClientTeam(client);
            if(IsPlayerAlive(client))
            {
                if(team == g_otherteam)
                {
                    alive++;
                }
            }
            else if(team > 1)
            {
                PushArrayCell(hPlayers, client);
                dead++;
            }
        }
    }

    decl idx;
    new maxspawn = RoundToCeil(alive * gf_fastzombie_ratio);
    for(new i; i<dead && i<maxspawn; i++)
    {
        idx = GetRandomInt(0, GetArraySize(hPlayers) -1);
        CreateZombieMinion(GetArrayCell(hPlayers, idx), Boss, false);
        RemoveFromArray(hPlayers, idx);
    }

    CloseHandle(hPlayers);

    new ent = -1;
    decl owner;
    while ((ent = FindEntityByClassname(ent, "tf_wearable*")) != -1)
    {
        if ((owner=GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner) == g_bossteam && FF2_GetBossIndex(owner) == -1)
        TF2_RemoveWearable(owner, ent);
    }
    ent = -1;
    while ((ent = FindEntityByClassname(ent, "tf_powerup_bottle")) != -1)
    {
        if ((owner=GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner) == g_bossteam && FF2_GetBossIndex(owner) == -1)
        TF2_RemoveWearable(owner, ent);
    }
}

CreateZombieMinion(client, Boss, bool:single=true, Float:origin[3] = NULL_VECTOR, Float:angle[3] = NULL_VECTOR, Float:velocity[3] = NULL_VECTOR)
{
    FF2_SetFF2flags(client,FF2_GetFF2flags(client)|FF2FLAG_ALLOWSPAWNINBOSSTEAM);

    TF2_RemoveCondition(client, TFCond_HalloweenGhostMode);

    if(g_fastzombie_class)
    {
        TF2_SetPlayerClass(client,g_fastzombie_class);
    }

    ChangeClientTeam(client, g_bossteam);
    TF2_RespawnPlayer(client);

    if(g_fastzombie_weaponindex)
    {
        TF2_RemoveAllWeapons(client);
        SpawnWeapon(client,gs_fastzombie_weaponclassname,g_fastzombie_weaponindex, 101, 9, gs_fastzombie_weaponattributes, true, true);   //stock SpawnWeapon(client,String:name[],index,level,qual,String:att[])
    }
    else
    {
        TF2_RemoveWeaponSlot(client, 0);
        TF2_RemoveWeaponSlot(client, 1);
        TF2_RemoveWeaponSlot(client, 3);
        TF2_RemoveWeaponSlot(client, 4);
        TF2_RemoveWeaponSlot(client, 5);
        new weapon = GetPlayerWeaponSlot(client, 2);
        if(weapon != -1)
        {
            SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon",weapon);
        }
    }

    SetVariantString(gs_fastzombie_model);
    AcceptEntityInput(client, "SetCustomModel");
    SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);

#if defined _friagramstocks_included
    Call_StartForward(gfwd_OnEquipModel);
    Call_PushCell(client);
    Call_PushCell(false);
    Call_PushCell(false);
    Call_PushArray(Float:{0.0,0.0,0.0}, 3);
    Call_Finish();	
#endif

    decl Float:vel[3];
    vel[0]=GetRandomFloat(300.0,500.0)*(GetRandomInt(1,0)?1:-1);
    vel[1]=GetRandomFloat(300.0,500.0)*(GetRandomInt(1,0)?1:-1);
    vel[2]=GetRandomFloat(300.0,500.0);

    if(single)
    {
        TeleportEntity(client, origin, angle, velocity);
    }
    else
    {
        if(GetRandomInt(0,1))
        {
            decl Float:pos[3];
            GetEntPropVector(Boss, Prop_Data, "m_vecOrigin", pos);
            TeleportEntity(client, pos, NULL_VECTOR, vel);
        }
        else
        {
            TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
        }
    }

    TF2_AddCondition(client, TFCond_UberchargedHidden, gf_fastzombie_protection);
    TF2_AddCondition(client, TFCond_HalloweenQuickHeal, gf_fastzombie_healtime);

    new userid = GetClientUserId(client);

    CreateTimer(0.5, Timer_SetFastZombieModel, userid, TIMER_FLAG_NO_MAPCHANGE);		// lazy
    CreateTimer(1.0, Timer_SetFastZombieModel, userid, TIMER_FLAG_NO_MAPCHANGE);		// set the model again, just incase?
    
    if(single)
    {
        new ent = -1;
        while ((ent = FindEntityByClassname(ent, "tf_wearable*")) != -1)
        {
            if (client == GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity"))
            {
                TF2_RemoveWearable(client, ent);
            }
        }
        ent = -1;
        while ((ent = FindEntityByClassname(ent, "tf_powerup_bottle")) != -1)
        {
            if (client == GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity"))
            {
                TF2_RemoveWearable(client, ent);
            }
        }
    }
}

public Action:Timer_SetFastZombieModel(Handle:timer, any:userid)
{
    if(g_bosstype == BOSS_FASTZOMBIE)
    {
        new client = GetClientOfUserId(userid);
        if(client && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == g_bossteam)
        {
            SetVariantString(gs_fastzombie_model);
            AcceptEntityInput(client, "SetCustomModel");
            SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);

#if defined _friagramstocks_included
            Call_StartForward(gfwd_OnEquipModel);
            Call_PushCell(client);
            Call_PushCell(false);
            Call_PushCell(false);
            Call_PushArray(Float:{0.0,0.0,0.0}, 3);
            Call_Finish();

            Call_StartForward(gfwd_OnCreateArrow);
            Call_PushCell(client);
            Call_PushFloat(100.0);
            Call_PushCell(g_bossteam);
            Call_Finish();
#endif

            if(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == -1)
            {
                new weapon = GetPlayerWeaponSlot(client, 2);
                if(weapon != -1)
                {
                    SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon",weapon);
                }
            }
        }
    }
}