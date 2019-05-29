public Action:Timer_RemoveEntity(Handle:timer, any:ref)
{
    new ent = EntRefToEntIndex(ref);
    if (ent != INVALID_ENT_REFERENCE)
    {
        AcceptEntityInput(ent, "Kill");
    }
}

public Action:Timer_RemoveRagdoll(Handle:timer, any:userid)
{
    new victim = GetClientOfUserId(userid);
    if(victim && IsClientInGame(victim))
    {
        new ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
        if (ragdoll > MaxClients)
        {
            AcceptEntityInput(ragdoll, "Kill");
        }
    }
}

public Action:Timer_DissolveRagdoll(Handle:timer, Handle:pack)
{
    ResetPack(pack);
    new victim = GetClientOfUserId(ReadPackCell(pack));
    if(victim && IsClientInGame(victim))
    {
        new ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
        if (ragdoll != -1)
        {
            Dissolve(ragdoll, ReadPackCell(pack));
        }
    }
}

stock Dissolve(ent, mode=3)
{
    new dissolver = CreateEntityByName("env_entity_dissolver");
    if (dissolver != -1)
    {
        decl String:dname[12];
        FormatEx(dname, 12, "dis_%d", ent);
        
        DispatchKeyValue(ent, "targetname", dname);
        switch(mode <0 ? GetRandomInt(0,3) : mode)    //"0 ragdoll rises as it dissolves, 1 and 2 dissolve on ground, 3 is fast dissolve"
        {
            case 0: DispatchKeyValue(dissolver, "dissolvetype", "0");
            case 1: DispatchKeyValue(dissolver, "dissolvetype", "1");
            case 2: DispatchKeyValue(dissolver, "dissolvetype", "2");
            default: DispatchKeyValue(dissolver, "dissolvetype", "3");
        }
        DispatchKeyValue(dissolver, "target", dname);
        AcceptEntityInput(dissolver, "Dissolve");
        AcceptEntityInput(dissolver, "kill");
    }
}

PerformBlind(client, duration)
{
    static UserMsg:g_FadeUserMsgId = INVALID_MESSAGE_ID;
    if(g_FadeUserMsgId == INVALID_MESSAGE_ID)
    {
        g_FadeUserMsgId = GetUserMessageId("Fade");
    }

    new targets[2];
    targets[0] = client;

    new Handle:message = StartMessageEx(g_FadeUserMsgId, targets, 1);
    if (GetUserMessageType() == UM_Protobuf)
    {
        PbSetInt(message, "duration", duration);
        PbSetInt(message, "hold_time", duration);
        PbSetInt(message, "flags", 0x0002);
        PbSetColor(message, "clr", {200, 200, 200, 200});
    }
    else
    {
        BfWriteShort(message, 900);
        BfWriteShort(message, 900);
        BfWriteShort(message, 0x0002);		
        BfWriteByte(message, 200);
        BfWriteByte(message, 200);
        BfWriteByte(message, 200);
        BfWriteByte(message, 200);
    }
    
    EndMessage();
}

stock TE_Particle(String:Name[], Float:origin[3]=NULL_VECTOR, Float:start[3]=NULL_VECTOR, Float:angles[3]=NULL_VECTOR,
entindex=-1,										// entity to attach to
attachtype=-1, 									// start_at_origin(1), start_at_attachment(2), follow_origin(3), follow_attachment(4)
attachpoint=-1,									// attachment point index on entity
bool:resetParticles=true,
customcolors = 0,								// probably 0/1/2
Float:color1[3] = NULL_VECTOR,					// rgb colors?
Float:color2[3] = NULL_VECTOR,					// rgb colors?
controlpoint = -1,								// second entity to attach to
controlpointattachment = -1,						// attach type
Float:controlpointoffset[3] = NULL_VECTOR,		// offset to maintain
Float:delay=0.0)
{
    // find string table
    new tblidx = FindStringTable("ParticleEffectNames");
    if (tblidx==INVALID_STRING_TABLE) 
    {
        LogError("Could not find string table: ParticleEffectNames");
        return;
    }
    
    // find particle index
    new String:tmp[256];
    new count = GetStringTableNumStrings(tblidx);
    new stridx = INVALID_STRING_INDEX;
    new i;
    for (i=0; i<count; i++)
    {
        ReadStringTable(tblidx, i, tmp, sizeof(tmp));
        if (StrEqual(tmp, Name, false))
        {
            stridx = i;
            break;
        }
    }
    if (stridx==INVALID_STRING_INDEX)
    {
        LogError("Could not find particle: %s", Name);
        return;
    }

    TE_Start("TFParticleEffect");
    TE_WriteFloat("m_vecOrigin[0]", origin[0]);
    TE_WriteFloat("m_vecOrigin[1]", origin[1]);
    TE_WriteFloat("m_vecOrigin[2]", origin[2]);
    TE_WriteFloat("m_vecStart[0]", start[0]);
    TE_WriteFloat("m_vecStart[1]", start[1]);
    TE_WriteFloat("m_vecStart[2]", start[2]);
    TE_WriteVector("m_vecAngles", angles);
    TE_WriteNum("m_iParticleSystemIndex", stridx);
    if (entindex!=-1)
    {
        TE_WriteNum("entindex", entindex);
    }
    if (attachtype!=-1)
    {
        TE_WriteNum("m_iAttachType", attachtype);
    }
    if (attachpoint!=-1)
    {
        TE_WriteNum("m_iAttachmentPointIndex", attachpoint);
    }
    TE_WriteNum("m_bResetParticles", resetParticles ? 1 : 0);    
    
    if(customcolors)
    {
        TE_WriteNum("m_bCustomColors", customcolors);
        TE_WriteVector("m_CustomColors.m_vecColor1", color1);
        if(customcolors == 2)
        {
            TE_WriteVector("m_CustomColors.m_vecColor2", color2);
        }
    }
    if(controlpoint != -1)
    {
        TE_WriteNum("m_bControlPoint1", controlpoint);
        if(controlpointattachment != -1)
        {
            TE_WriteNum("m_ControlPoint1.m_eParticleAttachment", controlpointattachment);
            TE_WriteFloat("m_ControlPoint1.m_vecOffset[0]", controlpointoffset[0]);
            TE_WriteFloat("m_ControlPoint1.m_vecOffset[1]", controlpointoffset[1]);
            TE_WriteFloat("m_ControlPoint1.m_vecOffset[2]", controlpointoffset[2]);
        }
    }
    
    TE_SendToAll(delay);
}

stock SpawnWeapon(client,String:name[],index,level,qual,String:att[], bool:hide=false, bool:equip=false)
{
    new Handle:hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
    TF2Items_SetClassname(hWeapon, name);
    TF2Items_SetItemIndex(hWeapon, index);
    TF2Items_SetLevel(hWeapon, level);
    TF2Items_SetQuality(hWeapon, qual);
    new String:atts[32][32];
    new count = ExplodeString(att, ";", atts, 32, 32);
    if (count > 1)
    {
        TF2Items_SetNumAttributes(hWeapon, count/2);
        new i2 = 0;
        for (new i = 0;  i < count;  i+= 2)
        {
            TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
            i2++;
        }
    }
    else
    TF2Items_SetNumAttributes(hWeapon, 0);
    if (hWeapon == INVALID_HANDLE)
    return -1;
    new entity = TF2Items_GiveNamedItem(client, hWeapon);
    CloseHandle(hWeapon);
    EquipPlayerWeapon(client, entity);
    
    if(hide)
    {
        SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
        SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
    }
    if(equip)
    {
        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", entity);
    }

    return entity;
}

stock SetAmmo(client, weapon, ammo, clip = 0)
{
    if(clip < 0)
    {
        SetEntProp(weapon, Prop_Data, "m_iClip1", 0);
    }
    else if(clip)
    {
        SetEntProp(weapon, Prop_Data, "m_iClip1", clip);
    }

    new ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
    if(ammotype != -1)
    {
        SetEntProp(client, Prop_Data, "m_iAmmo", ammo, _, ammotype);
    }
}