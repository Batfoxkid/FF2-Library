#define BOSS_OOGIEBOOGIE_KEY "rage_oogieboogie"

#define OOGIEBOOGIE_PHYSICS_SAWBLADE "models/props_forest/saw_blade.mdl"
#define OOGIEBOOGIE_LARGE_PHYSICS_SAWBLADE "models/props_forest/sawblade_moving.mdl"
#define SOUND_OOGIEBOOGIE_TOSS "physics/metal/sawblade_stick3.wav"
#define SOUND_OOGIEBOOGIE_SAW_SPINUP "ambient/machines/spinup.wav"

#define OOGIEBOOGIE_SAWBLADE_THROW_OFFSET 15.0

new g_oogieboogie_min_tossrage, g_oogieboogie_largesawhealth;
new Float:gf_oogieboogie_tosschargerate, Float:g_oogieboogie_largesawdamage, Float:gf_oogieboogie_largesawrehitdelay;
new Float:gf_oogieboogie_tossdamage, Float:gf_oogieboogie_tossforce, Float:gf_oogieboogie_tossforcemin, Float:gf_oogieboogie_tosssawrehitdelay;
new Float:gf_oogieboogie_largesawduration, Float:gf_oogieboogie_tossduration, Float:gf_oogieboogie_largesawactivate;
new Float:gf_oogieboogie_largesawbleed;

static const String:gs_oogieboogiesaws[][] = {"ambient/sawblade_impact1.wav", "ambient/sawblade_impact1.wav"}; 

new Handle:gh_oogieboogie_sawblades;
new Float:gf_diedOogieboogie[MAXPLAYERS+1];

new Handle:g_hSDKGetSmoothedVelocity = INVALID_HANDLE;
new bool:gb_SDKsv;

bool:TF2_SVStartup()
{
    new Handle:hConfig = LoadGameConfigFile("smoothedvelocity"); 
    if (hConfig == INVALID_HANDLE)
    {
        LogError("Couldn't load SDK functions (GetSmoothedVelocity). Make sure smoothedvelocity.txt is in your gamedata folder! Restart server if you want projectile physics.");
        return false;
    }
    
    StartPrepSDKCall(SDKCall_Entity); 
    PrepSDKCall_SetFromConf(hConfig, SDKConf_Virtual, "GetSmoothedVelocity"); 
    PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByValue); 
    CloseHandle(hConfig);

    if ((g_hSDKGetSmoothedVelocity = EndPrepSDKCall()) == INVALID_HANDLE)
    {
        LogError("Couldn't load SDK functions (GetSmoothedVelocity). SDK call failed.");
        return false;
    }

    return true;
}

Oogieboogie_event_round_active()
{
    gb_SDKsv = TF2_SVStartup();

    PrecacheModel(OOGIEBOOGIE_PHYSICS_SAWBLADE);
    PrecacheModel(OOGIEBOOGIE_LARGE_PHYSICS_SAWBLADE);

    for(new i; i<sizeof(gs_oogieboogiesaws); i++)
    {
        PrecacheSound(gs_oogieboogiesaws[i]);
    }
    PrecacheSound(SOUND_OOGIEBOOGIE_TOSS);
    PrecacheSound(SOUND_OOGIEBOOGIE_SAW_SPINUP);

    // these will always be solo boss/rages, so i'm not going to bother coding for multiples. There's no point looking this crap up every .1 seconds...
    g_oogieboogie_largesawhealth = FF2_GetAbilityArgument(0,this_plugin_name,BOSS_OOGIEBOOGIE_KEY,1, 5000);
    g_oogieboogie_largesawdamage = FF2_GetAbilityArgumentFloat(0,this_plugin_name,BOSS_OOGIEBOOGIE_KEY,2,100.0);
    gf_oogieboogie_largesawrehitdelay = FF2_GetAbilityArgumentFloat(0,this_plugin_name,BOSS_OOGIEBOOGIE_KEY,3,0.25);
    gf_oogieboogie_largesawduration = FF2_GetAbilityArgumentFloat(0,this_plugin_name,BOSS_OOGIEBOOGIE_KEY,4,30.0);
    gf_oogieboogie_largesawactivate = FF2_GetAbilityArgumentFloat(0,this_plugin_name,BOSS_OOGIEBOOGIE_KEY,5,2.0);
    gf_oogieboogie_largesawbleed = FF2_GetAbilityArgumentFloat(0,this_plugin_name,BOSS_OOGIEBOOGIE_KEY,5,3.0);

    g_oogieboogie_min_tossrage = FF2_GetAbilityArgument(0,this_plugin_name,"charge_oogieboogiesaw",1,10);
    gf_oogieboogie_tosschargerate = FF2_GetAbilityArgumentFloat(0,this_plugin_name,"charge_oogieboogiesaw",2,5.0);
    gf_oogieboogie_tossdamage = FF2_GetAbilityArgumentFloat(0,this_plugin_name,"charge_oogieboogiesaw",3,300.0);
    gf_oogieboogie_tossforce = FF2_GetAbilityArgumentFloat(0,this_plugin_name,"charge_oogieboogiesaw",4,900.0);
    gf_oogieboogie_tosssawrehitdelay = FF2_GetAbilityArgumentFloat(0,this_plugin_name,"charge_oogieboogiesaw",5,0.25);
    gf_oogieboogie_tossduration = FF2_GetAbilityArgumentFloat(0,this_plugin_name,"charge_oogieboogiesaw",6,5.0);
    gf_oogieboogie_tossforcemin = FF2_GetAbilityArgumentFloat(0,this_plugin_name,"charge_oogieboogiesaw",7,200.0);
}

Oogieboogie_FF2_OnAbility2(index, const String:ability_name[], action)
{
    if (StrEqual(ability_name,BOSS_OOGIEBOOGIE_KEY))
    {
        Rage_UseOogieboogiesaw(index);
    }
    else if(StrEqual(ability_name, "charge_oogieboogiesaw"))
    {
        Charge_Oogieboogiesaw(ability_name, index, action);
    }
}

Oogieboogie_OnPluginStart2()
{
    gh_oogieboogie_sawblades = CreateArray();
}

Oogieboogie_event_round_end()
{
    for(new i = GetArraySize(gh_oogieboogie_sawblades) -1; i>= 0; i--)
    {
        new ent = EntRefToEntIndex(GetArrayCell(gh_oogieboogie_sawblades, i));
        if(ent != INVALID_ENT_REFERENCE)
        {
            AcceptEntityInput(ent, "Break");
        }
    }
    ClearArray(gh_oogieboogie_sawblades);
}

Oogieboogie_event_death(client, Handle:hEvent)
{
    if(gf_diedOogieboogie[client] > GetEngineTime())
    {
        new iDamageBits = GetEventInt(hEvent, "damagebits");
        SetEventInt(hEvent, "damagebits",  iDamageBits |= DMG_NERVEGAS);
        SetEventString(hEvent, "weapon_logclassname", "oogieboogie_saw");
        SetEventString(hEvent, "weapon", "worldspawn");
        SetEventInt(hEvent, "customkill", TF_CUSTOM_TRIGGER_HURT);
        SetEventInt(hEvent, "playerpenetratecount", 0);
        SetEventInt(hEvent, "attacker", g_BossUserid[0]);
    }
}

Charge_Oogieboogiesaw(const String:ability_name[],index,action)      // so lazy
{
    new slot = FF2_GetAbilityArgument(index, this_plugin_name, ability_name, 0);
    new Float:zero_charge = FF2_GetBossCharge(index,0);
    new boss = GetClientOfUserId(FF2_GetBossUserId(index));
    if(zero_charge < g_oogieboogie_min_tossrage)
    {
        SetHudTextParams(-1.0, 0.93, 1.0, 255, 255, 255, 255);
        ShowSyncHudText(boss, chargeHUD, "Requires at least %d Rage!", g_oogieboogie_min_tossrage);
        return;
    }
 
    new Float:charge=FF2_GetBossCharge(index,slot);

    switch(action)
    {
    case 1:
        {
            SetHudTextParams(-1.0, 0.93, 1.0, 255, 255, 255, 255);
            ShowSyncHudText(boss, chargeHUD, "Throw Cooldown: %d",-RoundFloat(charge*10/gf_oogieboogie_tosschargerate));
        }
    case 2:
        {
            SetHudTextParams(-1.0, 0.93, 1.0, 255, 255, 255, 255);
            if(charge+1 < gf_oogieboogie_tosschargerate)
            {
                FF2_SetBossCharge(index,slot,charge+1);
            }
            else
            {
                charge=gf_oogieboogie_tosschargerate;
            }
            ShowSyncHudText(boss, chargeHUD, "Throw Charge: %d",RoundFloat(charge*100/gf_oogieboogie_tosschargerate));
        }
    default:
        {		
            if (charge <= 0.2)
            {
                SetHudTextParams(-1.0, 0.93, 1.0, 255, 255, 255, 255);
                ShowSyncHudText(boss, chargeHUD, "Throw Ready!, RELOAD/Mouse3 to charge");
            }
            if (charge >= gf_oogieboogie_tosschargerate)
            {
                FF2_SetBossCharge(index,0,zero_charge - g_oogieboogie_min_tossrage);

                new Handle:data;
                CreateDataTimer(0.2, Timer_StartOogieThrowCD, data);
                WritePackCell(data, index);
                WritePackCell(data, slot);
                ResetPack(data);

                ThrowSawBlade(boss);
            }
        }
    }
}

public Action:Timer_StartOogieThrowCD(Handle:hTimer,Handle:data)
{
	new index = ReadPackCell(data);
	new slot = ReadPackCell(data);
	FF2_SetBossCharge(index,slot,-gf_oogieboogie_tosschargerate);
}

ThrowSawBlade(boss)     // arc math from https://forums.alliedmods.net/showthread.php?t=175600
{
    decl Float:fPlayerPos[3];
    decl Float:fPlayerAngles[3];
    decl Float:fThrowingVector[3];

    GetClientEyeAngles( boss, fPlayerAngles );
    GetClientEyePosition( boss, fPlayerPos );

    EmitAmbientSound(SOUND_OOGIEBOOGIE_TOSS, fPlayerPos);
    
    new Float:fLen = OOGIEBOOGIE_SAWBLADE_THROW_OFFSET * Sine( DegToRad( fPlayerAngles[0] + 90.0 ) );
    
    fPlayerPos[0] = fPlayerPos[0] + fLen * Cosine( DegToRad( fPlayerAngles[1] ) );
    fPlayerPos[1] = fPlayerPos[1] + fLen * Sine( DegToRad( fPlayerAngles[1] ) );
    fPlayerPos[2] = fPlayerPos[2] + OOGIEBOOGIE_SAWBLADE_THROW_OFFSET * Sine( DegToRad( -1 * fPlayerAngles[0] ) ) ;
    
    new entity = CreateEntityByName( "prop_physics_multiplayer" );
    if(entity != -1)        
    {
        DispatchKeyValueVector(entity, "origin", fPlayerPos);
        DispatchKeyValueVector(entity, "angles", fPlayerAngles);
        DispatchKeyValue( entity, "model", OOGIEBOOGIE_PHYSICS_SAWBLADE );
        DispatchKeyValue( entity, "massScale", "1.0" );
        DispatchKeyValue( entity, "solid", "6");
        DispatchKeyValue( entity, "spawnflags", "12288");

        DispatchSpawn( entity );
        ActivateEntity( entity );
        
        SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", boss);	
        //SetEntProp(entity, Prop_Send, "m_CollisionGroup", 2);		// This is a trigger (1) Valve constantly changes this crap, now projectiles get stuck in these props
        SetEntProp(entity, Prop_Send, "m_usSolidFlags", 8);			// Fire trigger even if not solid (8)

        SDKHook(entity, SDKHook_StartTouch, OogieboogieProjectileTouchHook);			// force projectile to deal damage on touch

        new ref = EntIndexToEntRef(entity);
        PushArrayCell(gh_oogieboogie_sawblades, ref);
        CreateTimer(gf_oogieboogie_tossduration, Timer_RemoveEntity, ref, TIMER_FLAG_NO_MAPCHANGE);

        new Float:fScal = gf_oogieboogie_tossforce * Sine( DegToRad( fPlayerAngles[0] + 90.0 ) );

        fThrowingVector[0] = fScal * Cosine( DegToRad( fPlayerAngles[1] ) );
        fThrowingVector[1] = fScal * Sine( DegToRad( fPlayerAngles[1] ) );
        fThrowingVector[2] = gf_oogieboogie_tossforce * Sine( DegToRad( -1 * fPlayerAngles[0] ) );

        TeleportEntity( entity, fPlayerPos, fPlayerAngles, fThrowingVector );
    }
}

public Action:OogieboogieProjectileTouchHook(entity, other)
{
    static Float:lasthit[MAXPLAYERS+1];
    static Float:time;

    if(other > 0 && other != g_boss)
    {
        decl bool:fail;
        decl Float:speed;
        if(gb_SDKsv)
        {
            decl Float:vel[3];
            SDKCall(g_hSDKGetSmoothedVelocity, entity, vel);
            speed = GetVectorLength(vel);
            if(speed < gf_oogieboogie_tossforcemin)
            {
                fail = true;
            }
            else
            {
                fail = false;
            }
        }
        else
        {
            fail = false;
            speed = gf_oogieboogie_tossforce;
        }

        if(!fail)
        {
            new Float:ratio = speed/gf_oogieboogie_tossforce;
            if(other > MaxClients)
            {
                decl String:classname[5];
                if(!(GetEntityClassname(other, classname, 5) && StrEqual(classname, "obj_")))
                {
                    SetVariantInt(RoundToCeil(ratio*gf_oogieboogie_tossdamage));
                    AcceptEntityInput(other, "RemoveHealth");
                    EmitSoundToAll(gs_oogieboogiesaws[GetRandomInt(0, sizeof(gs_oogieboogiesaws)-1)], entity);
                }
            }
            else
            {
                time = GetEngineTime();
                if(lasthit[other] < time)
                {
                    lasthit[other] = time + gf_oogieboogie_tosssawrehitdelay;
                    gf_diedOogieboogie[other] = time + 0.1;
                    SDKHooks_TakeDamage(other, g_boss, g_boss, ratio*gf_oogieboogie_tossdamage);
                    EmitSoundToAll(gs_oogieboogiesaws[GetRandomInt(0, sizeof(gs_oogieboogiesaws)-1)], entity);
                }
            }
        }
    }
}

public bool:TraceRayWorld(entityhit, mask)
{
    if(!entityhit)
    {
        return true;
    }
    if(entityhit >= MaxClients)
    {
        return false;
    }
    decl String:classname[64];
    GetEntPropString(entityhit, Prop_Data, "m_iClassname", classname, 64);
    if(StrEqual(classname, "worldspawn") || !StrContains(classname, "prop_"))
    {
        return true;
    }
    
    return false;
}

Rage_UseOogieboogiesaw(index)
{
    decl Handle:TraceRay;
    decl Float:StartOrigin[3], Float:Angles[3];
    new client = GetClientOfUserId(FF2_GetBossUserId(index));
    GetClientEyeAngles(client, Angles);
    GetClientEyePosition(client, StartOrigin);

    TraceRay = TR_TraceRayFilterEx(StartOrigin, Angles, CONTENTS_SOLID|CONTENTS_WATER|CONTENTS_WINDOW|CONTENTS_GRATE, RayType_Infinite, TraceRayWorld);

    if(TR_DidHit(TraceRay))
    {
        decl Float:EndOrigin[3];
        TR_GetEndPosition(EndOrigin, TraceRay);

        new ent = CreateEntityByName("prop_dynamic");
        if (ent != -1)
        {
            decl Float:normal[3], Float:tempangles[3];
            TR_GetPlaneNormal(TraceRay, normal);		// this is a forward vector

            EndOrigin[0] += normal[0]*90.0;
            EndOrigin[1] += normal[1]*90.0;
            EndOrigin[2] += normal[2]*90.0;
            
            GetVectorAngles(normal, tempangles);

            Angles[0] = tempangles[0] -270;	// horizontal

            if (tempangles[0] != 270)
            {
                Angles[1]  = tempangles[1];			// override
            }

            DispatchKeyValue(ent, "model", OOGIEBOOGIE_LARGE_PHYSICS_SAWBLADE);
            DispatchKeyValue(ent, "disableshadows", "1");
            DispatchKeyValueVector(ent, "origin", EndOrigin);
            DispatchKeyValueVector(ent, "angles", Angles);
            DispatchKeyValue(ent, "solid", "6");

            DispatchSpawn(ent);

            ActivateEntity(ent);

            SetEntProp(ent, Prop_Data, "m_iHealth", g_oogieboogie_largesawhealth);
            SetEntProp(ent, Prop_Data, "m_takedamage", 2, 1);
            
            SetEntProp(ent, Prop_Send, "m_CollisionGroup", 13);
            SetEntProp(ent, Prop_Send, "m_usSolidFlags", 8);

            new ref = EntIndexToEntRef(ent);

            PushArrayCell(gh_oogieboogie_sawblades, ref);
            CreateTimer(gf_oogieboogie_largesawactivate, Timer_ActivateSaw, ref, TIMER_FLAG_NO_MAPCHANGE);
            CreateTimer(gf_oogieboogie_largesawduration, Timer_RemoveEntity, ref, TIMER_FLAG_NO_MAPCHANGE);
        }
    }

    CloseHandle(TraceRay);
}

public Action:Timer_ActivateSaw(Handle:timer, any:ref)
{
    new ent = EntRefToEntIndex(ref);
    if(ent != INVALID_ENT_REFERENCE)
    {
        SetVariantString("idle");
        AcceptEntityInput(ent, "SetDefaultAnimation");
        SetVariantString("idle");
        AcceptEntityInput(ent, "SetAnimation");

        SDKHook(ent, SDKHook_StartTouch, OnStartTouchOogieSawZone);
        SDKHook(ent, SDKHook_Touch, OnTouchOogieSawZone);
        
        EmitSoundToAll(SOUND_OOGIEBOOGIE_SAW_SPINUP, ent, SNDCHAN_VOICE);
    }
}
public Action:OnStartTouchOogieSawZone(prop, entity)
{
    if(entity >0 && entity <=MaxClients && IsClientInGame(entity) && GetClientTeam(entity) == g_bossteam)
    {
        return Plugin_Handled;
    }
    return Plugin_Continue;
}
public Action:OnTouchOogieSawZone(prop, entity)
{
    static Float:lasthit[MAXPLAYERS+1];
    static Float:time;

    if(entity >0 && entity <=MaxClients && IsClientInGame(entity) && GetClientTeam(entity) == g_otherteam)
    {
        time = GetEngineTime();
        if(lasthit[entity] < time)
        {
            lasthit[entity] = time + gf_oogieboogie_largesawrehitdelay;

            gf_diedOogieboogie[entity] = time + 0.1;
            SDKHooks_TakeDamage(entity, g_boss, g_boss, g_oogieboogie_largesawdamage);
            EmitSoundToAll(gs_oogieboogiesaws[GetRandomInt(0, sizeof(gs_oogieboogiesaws)-1)], entity);

            decl Float:clientpos[3];
            GetClientAbsOrigin(entity, clientpos);
            clientpos[0] += GetRandomFloat(-10.0, 10.0);
            clientpos[1] += GetRandomFloat(-10.0, 10.0);
            clientpos[2] += GetRandomFloat(30.0, 50.0);
            TE_Particle("blood_impact_backscatter", clientpos);

            TF2_MakeBleed(entity, entity, gf_oogieboogie_largesawbleed);

            SetVariantInt(1);
            AcceptEntityInput(prop, "Skin");
        }
    }
}