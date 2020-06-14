#define BOSS_MUMMY_KEY "special_mummy"

float g_fDiedMummy[MAXPLAYERS+1];

float gf_mummyradius;
float gf_mummyminratio;
float gf_mummyscaleincrement;
float gf_mummyminscale;
float gf_mummymindamage;
float gf_mummymaxdamage;
float gf_mummydamagetime;
float gf_mummyragemulti;
float gf_mummyragetime;

void Mummy_event_round_active()
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


void Mummy_FF2_OnAbility2(const char[] ability_name)
{
    if (StrEqual(ability_name, BOSS_MUMMY_KEY))
    {
        gf_RageTime[BOSS_MUMMY] = GetEngineTime() + gf_mummyragetime;
    }
}

public void Mummy_HookTouch(int boss, int entity)
{
    static float origin[3], angles[3], targetpos[3];

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
            ForcePlayerSuicide(entity);
        }
    }
}

void Mummy_event_player_death(int client, int userid, Event hEvent)
{
    if(g_fDiedMummy[client] > GetEngineTime())
    {
        hEvent.SetString("weapon_logclassname", "mummy_stomp");
        hEvent.SetString("weapon", "mantreads");
    }
    if(client != g_boss)
    {
        CreateTimer(0.01, Timer_RemoveRagdoll, userid);
    }
}

public Action Timer_MummyCurse(Handle timer, any userid)
{
    static float bosspos[3], clientpos[3], dist, ratio, scale, damage, time;
    static float lastdamage[MAXPLAYERS+1];
    static bool rage;

    if(gb_tf2attributes)
    {
        int boss = GetClientOfUserId(userid);
        if(g_boss == boss && g_bosstype == BOSS_MUMMY && IsClientInGame(boss) && IsPlayerAlive(boss))
        {
            time = GetEngineTime();
            GetClientAbsOrigin(boss, bosspos);
            rage = gf_RageTime[BOSS_MUMMY] > time ? true : false;
            for(int target = 1; target<=MaxClients; target++)
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
            for(int target = 1; target<=MaxClients; target++)
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
