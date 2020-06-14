public Action Timer_RemoveEntity(Handle timer, any ref)
{
    int ent = EntRefToEntIndex(ref);
    if (ent != INVALID_ENT_REFERENCE)
    {
    	RemoveEntity(ent);
    }
}

public Action Timer_RemoveRagdoll(Handle timer, any userid)
{
    int victim = GetClientOfUserId(userid);
    if(victim && IsClientInGame(victim))
    {
        int ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
        if (ragdoll > MaxClients)
        {
    		RemoveEntity(ragdoll);
        }
    }
}

public Action Timer_DissolveRagdoll(Handle timer, DataPack pack)
{
    pack.Reset();
    int victim = GetClientOfUserId(pack.ReadCell());
    if(victim && IsClientInGame(victim))
    {
        int ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
        if (ragdoll != -1)
        {
            Dissolve(ragdoll, pack.ReadCell());
        }
    }
}

stock void Dissolve(int ent, int mode=3)
{
    int dissolver = CreateEntityByName("env_entity_dissolver");
    if (dissolver != -1)
    {
        static char dname[12];
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

void PerformBlind(int client, int duration)
{
    BfWrite message = UserMessageToBfWrite(StartMessageOne("Fade", client));
    message.WriteShort(900);
    message.WriteShort(900);
    message.WriteShort(0x0002);		
    message.WriteByte(200);
    message.WriteByte(200);
    message.WriteByte(200);
    message.WriteByte(200);
    EndMessage();
    #pragma unused duration
}

stock void TE_Particle(char[] Name, float origin[3]=NULL_VECTOR, float start[3]=NULL_VECTOR, float angles[3]=NULL_VECTOR,
int entindex=-1,										// entity to attach to
int attachtype=-1, 									// start_at_origin(1), start_at_attachment(2), follow_origin(3), follow_attachment(4)
int attachpoint=-1,									// attachment point index on entity
bool resetParticles=true,
int customcolors = 0,								// probably 0/1/2
float color1[3] = NULL_VECTOR,						// rgb colors?
float color2[3] = NULL_VECTOR,						// rgb colors?
int controlpoint = -1,								// second entity to attach to
int controlpointattachment = -1,					// attach type
float controlpointoffset[3] = NULL_VECTOR,			// offset to maintain
float delay=0.0)
{
    // find string table
    int tblidx = FindStringTable("ParticleEffectNames");
    if (tblidx==INVALID_STRING_TABLE) 
    {
        LogError("Could not find string table: ParticleEffectNames");
        return;
    }
    
    int stridx = FindStringIndex(tblidx, Name);
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

stock int SpawnWeapon(int client,char[] name, int index, int level,int qual,char[] att, bool hide=false, bool equip=false)
{
    Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
    TF2Items_SetClassname(hWeapon, name);
    TF2Items_SetItemIndex(hWeapon, index);
    TF2Items_SetLevel(hWeapon, level);
    TF2Items_SetQuality(hWeapon, qual);
    char atts[32][32];
    int count = ExplodeString(att, ";", atts, 32, 32);
    if (count > 1)
    {
        TF2Items_SetNumAttributes(hWeapon, count/2);
        int i2 = 0;
        for (int i = 0;  i < count;  i+= 2)
        {
            TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
            i2++;
        }
    }
    else
    TF2Items_SetNumAttributes(hWeapon, 0);
    if (hWeapon == INVALID_HANDLE)
    return -1;
    int entity = TF2Items_GiveNamedItem(client, hWeapon);
    delete hWeapon;
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

stock void SetAmmo(int client, int weapon, int ammo, int clip = 0)
{
    if(clip < 0)
    {
        SetEntProp(weapon, Prop_Data, "m_iClip1", 0);
    }
    else if(clip)
    {
        SetEntProp(weapon, Prop_Data, "m_iClip1", clip);
    }

    int ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
    if(ammotype != -1)
    {
        SetEntProp(client, Prop_Data, "m_iAmmo", ammo, _, ammotype);
    }
}
