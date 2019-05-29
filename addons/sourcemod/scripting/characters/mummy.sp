#define BOSS_MUMMY_KEY "special_mummy"

new Float:g_fDiedMummy[MAXPLAYERS+1];

new Float:gf_mummyradius;
new Float:gf_mummyminratio;
new Float:gf_mummyscaleincrement;
new Float:gf_mummyminscale;
new Float:gf_mummymindamage;
new Float:gf_mummymaxdamage;
new Float:gf_mummydamagetime;
new Float:gf_mummyragemulti;
new Float:gf_mummyragetime;

Mummy_event_round_active()
{
    gf_mummyradius = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_MUMMY_KEY, 1, 1500.0);
    gf_mummyminratio = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_MUMMY_KEY, 2, 0.5);
    
    gf_mummyscaleincrement = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_MUMMY_KEY, 3, 0.01);
    gf_mummyminscale = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_MUMMY_KEY, 4, 0.5);
    
    gf_mummymindamage = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_MUMMY_KEY, 5, 1.0);
    gf_mummymaxdamage = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_MUMMY_KEY, 6, 10.0);
    
    gf_mummydamagetime = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_MUMMY_KEY, 8, 5.0);
    
    gf_mummyragemulti = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_MUMMY_KEY, 9, 10.0);
    gf_mummyragetime = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_MUMMY_KEY, 10, 6.0);

    if(gb_tf2attributes)
    {
        CreateTimer(FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_MUMMY_KEY, 7, 0.5), Timer_MummyCurse, g_BossUserid[0], TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
    
    SDKHook(g_boss, SDKHook_Touch, Mummy_HookTouch);
}


Mummy_FF2_OnAbility2(const String:ability_name[])
{
    if (StrEqual(ability_name, BOSS_MUMMY_KEY))
    {
        gf_RageTime[BOSS_MUMMY] = GetEngineTime() + gf_mummyragetime;
    }
}

public Mummy_HookTouch(boss, entity)
{
    static Float:origin[3], Float:angles[3], Float:targetpos[3];

    if(boss != g_boss)
    {
        SDKUnhook(boss, SDKHook_Touch, Mummy_HookTouch);
        return;
    }

    if(entity > 0 && entity <= MaxClients && IsClientInGame(entity) &&
        IsPlayerAlive(entity) && GetClientTeam(entity) == g_otherteam &&
        GetEntPropFloat(entity, Prop_Send, "m_flModelScale") == gf_mummyminscale)
    {
        GetClientEyeAngles(boss, angles);
        GetClientEyePosition(boss, origin);
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", targetpos);
        GetAngleVectors(angles, angles, NULL_VECTOR, NULL_VECTOR);
        NormalizeVector(angles, angles);
        SubtractVectors(targetpos, origin, origin);

        if(GetVectorDotProduct(origin, angles) > 0.0)
        {
            g_fDiedMummy[entity]= GetEngineTime() + 0.1;
            SDKHooks_TakeDamage(entity, boss, boss, 9999.9, DMG_CRUSH|DMG_PREVENT_PHYSICS_FORCE);    // going to use his meter, rather than his velocity for more reliable numbers
            FakeClientCommandEx(entity, "kill");
        }
    }
}

Mummy_event_player_death(client, userid, Handle:hEvent)
{
    if(g_fDiedMummy[client] > GetEngineTime())
    {
        SetEventString(hEvent, "weapon_logclassname", "mummy_stomp");
        SetEventString(hEvent, "weapon", "mantreads");
    }
    if(client != g_boss)
    {
        CreateTimer(0.01, Timer_RemoveRagdoll, userid);
    }
}

public Action:Timer_MummyCurse(Handle:timer, any:userid)
{
    static Float:bosspos[3], Float:clientpos[3], Float:dist, Float:ratio, Float:scale, Float:damage, Float:time;
    static Float:lastdamage[MAXPLAYERS+1];
    static bool:rage;

    if(gb_tf2attributes)
    {
        new boss = GetClientOfUserId(userid);
        if(g_boss == boss && g_bosstype == BOSS_MUMMY && IsClientInGame(boss) && IsPlayerAlive(boss))
        {
            time = GetEngineTime();
            GetClientAbsOrigin(boss, bosspos);
            rage = gf_RageTime[BOSS_MUMMY] > time ? true : false;
            for(new target = 1; target<=MaxClients; target++)
            {
                if(IsClientInGame(target) && GetClientTeam(target) == g_otherteam)
                {
                    GetClientAbsOrigin(target, clientpos);
                    dist = GetVectorDistance(bosspos, clientpos);
                    if(dist < gf_mummyradius)
                    {
                        ratio = dist/gf_mummyradius;
                        damage = (1-ratio) * gf_mummymaxdamage;
                        if(ratio < gf_mummyminratio)
                        {
                            ratio = gf_mummyminratio;
                        }

                        TF2Attrib_SetByName(target, "move speed penalty", ratio);

                        scale = GetEntPropFloat(target, Prop_Send, "m_flModelScale") - gf_mummyscaleincrement;
                        if(scale < gf_mummyminscale)
                        {
                            scale = gf_mummyminscale;
                        }
                        SetEntPropFloat(target, Prop_Send, "m_flModelScale", scale);

                        if(lastdamage[target] < time)
                        {
                            lastdamage[target] = gf_mummydamagetime + time;
                            if(rage)
                            {
                                damage *= gf_mummyragemulti;
                            }
                            if(damage < gf_mummymindamage)
                            {
                                damage = gf_mummymindamage;
                            }

                            if(damage > 1.0)
                            {
                                SDKHooks_TakeDamage(target, target, target, (1.0/scale) * damage, DMG_PREVENT_PHYSICS_FORCE);
                            }
                        }
                    }
                    else
                    {
                        TF2Attrib_RemoveByName(target, "move speed penalty");
                    }
                    TF2_AddCondition(target, TFCond_SpeedBuffAlly, 0.001);
                }
            }
            return Plugin_Continue;
        }
        else
        {
            for(new target = 1; target<=MaxClients; target++)
            {
                if(IsClientInGame(target))
                {
                    TF2Attrib_RemoveByName(target, "move speed penalty");
                    TF2_AddCondition(target, TFCond_SpeedBuffAlly, 0.001);
                    SetEntPropFloat(target, Prop_Send, "m_flModelScale", 1.0);
                }
            }
        }
    }

    return Plugin_Stop;
}