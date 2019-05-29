#define BOSS_GREYALIEN_KEY     "special_greyalien"

#define SOUND_GREYALIEN_POD_START "npc/scanner/combat_scan5.wav"
#define SOUND_GREYALIEN_POD_LOOP "npc/scanner/combat_scan_loop6.wav"
#define SOUND_GREYALIEN_POD_END "npc/scanner/scanner_nearmiss1.wav"

#define GREYALIEN_STUN_DELAY 1.0

#define GREYALIEN_BEAM_LENGTH 1000.0
#define GREYALIEN_BEAM_MINS Float:{-50.0, -50.0, 0.0}
#define GREYALIEN_BEAM_MAXS Float:{50.0, 50.0, 1000.0}

new g_update[MAXPLAYERS+1];
new Float:gf_DiedGreyAlien[MAXPLAYERS+1];
new g_greyalien_iterations, g_greyalien_blindtime;
new Float:gf_greyalien_timer, Float:gf_greyalien_radius, Float:gf_greyalien_velocity;
new Float:gf_greyalien_stuntime, Float:gf_greyalien_duration, Float:gf_greyalien_damage;
new Float:gf_greyalien_slayratio;
new String:gs_greyalien_push[6];

Greyalien_event_round_active()
{
    PrecacheSound(SOUND_GREYALIEN_POD_START);
    PrecacheSound(SOUND_GREYALIEN_POD_LOOP);
    PrecacheSound(SOUND_GREYALIEN_POD_END);

    g_greyalien_iterations = FF2_GetAbilityArgument(0,this_plugin_name,BOSS_GREYALIEN_KEY, 1, 15);
    gf_greyalien_timer = FF2_GetAbilityArgumentFloat(0,this_plugin_name,BOSS_GREYALIEN_KEY,2,0.2);
    gf_greyalien_radius = FF2_GetAbilityArgumentFloat(0,this_plugin_name,BOSS_GREYALIEN_KEY,3,800.0);
    gf_greyalien_velocity = FF2_GetAbilityArgumentFloat(0,this_plugin_name,BOSS_GREYALIEN_KEY,4,0.350);
    gf_greyalien_damage = FF2_GetAbilityArgumentFloat(0,this_plugin_name,BOSS_GREYALIEN_KEY,5, 10.0);
    FF2_GetAbilityArgumentString(0,this_plugin_name,BOSS_GREYALIEN_KEY,6, gs_greyalien_push, 6);
    gf_greyalien_stuntime = FF2_GetAbilityArgumentFloat(0,this_plugin_name,BOSS_GREYALIEN_KEY,7,1.0);
    gf_greyalien_duration = FF2_GetAbilityArgumentFloat(0,this_plugin_name,BOSS_GREYALIEN_KEY,8,8.0);
    g_greyalien_blindtime = FF2_GetAbilityArgument(0,this_plugin_name,BOSS_GREYALIEN_KEY,9,2);
    gf_greyalien_slayratio = FF2_GetAbilityArgumentFloat(0,this_plugin_name,BOSS_GREYALIEN_KEY,10,0.95);
}

Greyalien_FF2_OnAbility2(index,const String:ability_name[])
{
    if (StrEqual(ability_name,BOSS_GREYALIEN_KEY))
    {
        Rage_UseGreyAlien(index);
    }
}

Greyalien_event_player_death(client, userid, Handle:hEvent)
{
    if(gf_DiedGreyAlien[client] > GetEngineTime())
    {
        SetEventString(hEvent, "weapon_logclassname", "alien_abduction");
        SetEventString(hEvent, "weapon", "merasmus_zap");

        new Handle:data;
        CreateDataTimer(0.01, Timer_DissolveRagdoll, data);
        WritePackCell(data, userid);
        WritePackCell(data, 0);
    }
}

//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////  Luna Active Rage
Rage_UseGreyAlien(index)
{
    new Handle:data;
    CreateDataTimer(gf_greyalien_timer, Timer_Abduction, data, TIMER_FLAG_NO_MAPCHANGE);
    WritePackCell(data, FF2_GetBossUserId(index));
    WritePackCell(data, g_greyalien_iterations);          // iterations

    for(new client=1; client<=MaxClients; client++)
    {
        if(IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == g_otherteam)
        {
            PerformBlind(client, g_greyalien_blindtime);
        }
    }
}

public Action:Timer_Abduction(Handle:timer, Handle:pack)
{
    ResetPack(pack);

    new userid = ReadPackCell(pack);
    new iterations = ReadPackCell (pack);

    new client = GetClientOfUserId(userid);
    if (client == g_boss && client && IsClientInGame(client) && IsPlayerAlive(client))
    {
        Abduct(client);

        if(--iterations)
        {
            new Handle:data;
            CreateDataTimer(gf_greyalien_timer, Timer_Abduction, data, TIMER_FLAG_NO_MAPCHANGE);
            WritePackCell(data, userid);
            WritePackCell(data, iterations);          // iterations
        }
    }
}

Abduct(client)
{
    decl Float:origin[3];
    GetClientAbsOrigin(client, origin);
    origin[0] += GetRandomFloat(-gf_greyalien_radius, gf_greyalien_radius);
    origin[1] += GetRandomFloat(-gf_greyalien_radius, gf_greyalien_radius);
    new Handle:TraceRay = TR_TraceRayEx(origin, Float:{90.0, 0.0, 0.0}, MASK_SHOT, RayType_Infinite);
    if (TR_DidHit(TraceRay))
    {
        TR_GetEndPosition(origin, TraceRay);
        origin[2] += 5.0;
    }
    else
    {
        origin[2] -= 280.0;
    }
    CloseHandle(TraceRay);

    new trigger = CreateEntityByName("trigger_push");
    if(trigger != -1)
    {
        EmitAmbientSound(SOUND_GREYALIEN_POD_START, origin, trigger);
        EmitSoundToAll(SOUND_GREYALIEN_POD_LOOP, trigger, SNDCHAN_VOICE);
        CreateTimer(gf_greyalien_duration, Timer_RemovePod, EntIndexToEntRef(trigger), TIMER_FLAG_NO_MAPCHANGE);
         
        DispatchKeyValueVector(trigger, "origin", origin);
        DispatchKeyValue(trigger, "speed", gs_greyalien_push);
        DispatchKeyValue(trigger, "StartDisabled", "0");
        DispatchKeyValue(trigger, "spawnflags", "1");
        DispatchKeyValueVector(trigger, "pushdir", Float:{-90.0, 0.0, 0.0});
        DispatchKeyValue(trigger, "alternateticksfix", "0");
        DispatchSpawn(trigger);
        
        ActivateEntity(trigger);

        AcceptEntityInput(trigger, "Enable");
        
        SetEntityModel(trigger, MODEL_TRIGGER);

        SetEntPropVector(trigger, Prop_Send, "m_vecMins", GREYALIEN_BEAM_MINS);
        SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", GREYALIEN_BEAM_MAXS);

        SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);

        SDKHook(trigger, SDKHook_StartTouch, OnStartTouchBeam);
        SDKHook(trigger, SDKHook_Touch, OnTouchBeam);
        SDKHook(trigger, SDKHook_EndTouch, OnEndTouchBeam);

        TE_Particle("teleported_mvm_bot", origin, _, _, trigger, 1,0);
    }
}

public Action:Timer_RemovePod(Handle:timer, any:ref)
{
    new ent = EntRefToEntIndex(ref);
    if(ent != INVALID_ENT_REFERENCE)
    {
        StopSound(ent, SNDCHAN_VOICE, SOUND_GREYALIEN_POD_LOOP);
        EmitSoundToAll(SOUND_GREYALIEN_POD_END, ent, SNDCHAN_VOICE);
        AcceptEntityInput(ent, "Disable");
        
        CreateTimer(0.1, Timer_RemoveEntity, ref, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action:OnStartTouchBeam( brush, entity )
{
    if(entity > 0 && entity <= MaxClients && IsClientInGame(entity) && GetClientTeam(entity) == g_otherteam) // should be in game, but sometimes arn't wtf
    {
        SetEntityGravity(entity, 0.001);
        
        return Plugin_Continue;
    }
    return Plugin_Handled;
}

public Action:OnEndTouchBeam( brush, entity )
{
    if(entity > 0 && entity <= MaxClients && IsClientInGame(entity)) // should be in game, but sometimes arn't wtf
    {
        g_update[entity] = 0;
        SetEntityGravity(entity, 1.0);
    }
}

public Action:OnTouchBeam( brush, entity )
{
    static Float:lasthurtstun[MAXPLAYERS+1];
    static Float:time, Float:ratio;
    static Float:clientpos[3], Float:beampos[3];

    if(entity > 0 && entity <= MaxClients && IsClientInGame(entity) && GetClientTeam(entity) == g_otherteam) // should be in game, but sometimes arn't wtf
    {
        time = GetEngineTime();
        if(lasthurtstun[entity] < time)
        {
            lasthurtstun[entity] = time + GREYALIEN_STUN_DELAY;
            TF2_StunPlayer(entity, gf_greyalien_stuntime, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT, 0);

            GetClientAbsOrigin(entity, clientpos);
            GetEntPropVector(brush, Prop_Send, "m_vecOrigin", beampos);
            ratio = GetVectorDistance(clientpos, beampos)/GREYALIEN_BEAM_LENGTH;

            gf_DiedGreyAlien[entity] = time + 0.1;
            if(ratio >= gf_greyalien_slayratio)
            {
                SDKHooks_TakeDamage(entity, g_boss, g_boss, 9001.0, DMG_SHOCK|DMG_PREVENT_PHYSICS_FORCE);
            }
            else
            {
                SDKHooks_TakeDamage(entity, g_boss, g_boss, gf_greyalien_damage * ratio, DMG_SHOCK|DMG_PREVENT_PHYSICS_FORCE);
            }
        }

        if(GetEntityFlags(entity) & FL_ONGROUND)
        {
            clientpos[0] = 0.0;
            clientpos[1] = 0.0;
            clientpos[2] = gf_greyalien_velocity;

            TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, clientpos);
            
            g_update[entity] = 0;
        }
        else if(g_update[entity] == 1)
        {
            TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, Float:{0.0,0.0,0.0}); 
        }
        g_update[entity]++;

        return Plugin_Continue;
    }
    return Plugin_Handled;
}

Greyalien_event_round_end()
{
    for(new client=1; client<=MaxClients; client++)
    {
        if(IsClientInGame(client))
        {
            SetEntityGravity(client, 1.0);  // just in case.
        }
    }
}