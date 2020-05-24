methodmap AMSSettings < StringMap {
	public AMSSettings(const FF2Prep player, Handle pContext, const char[] plugin, const char[] ability, const char[] prefix) {
		StringMap ams = new StringMap();
		
		ams.SetValue("this", pContext);
		ams.SetString("this_plugin", plugin);
		ams.SetString("prefix", prefix);
		ams.SetString("ability", ability);
		ams.SetValue("cooldown", GetGameTime() + player.GetArgF(plugin, ability, "initial cd", 1001, 0.0));
		ams.SetValue("abilitycd", player.GetArgF(plugin, ability, "ability cd", 1002, 10.0));
		
		char str[128]; player.GetArgS(plugin, ability, "this_name", 1003, str, sizeof(str));
		ams.SetString("this_name", str);
		
		player.GetArgS(plugin, ability, "display_desc", 1004, str, sizeof(str));
		ams.SetString("display_desc", str);
		
		ams.SetValue("this_cost", player.GetArgF(plugin, ability, "cost", 1005, 25.0));
		ams.SetValue("this_end", player.GetArgI(plugin, ability, "can end", 1006, 0));
		
		return view_as<AMSSettings>(ams);
	}
	
	public bool IsValid() {
		return this != null;
	}
	
	public bool GetPrefix(char[] prefix, int size) {
		return this.GetString("prefix", prefix, size);
	}
	
	public float GetCurrentCooldown() {
		float cd;
		return this.GetValue("cooldown", cd) ? cd:0.0;
	}
	public void SetCurrentCooldown(float cd) {
		this.SetValue("cooldown", cd + GetGameTime());
	}
	public void AddCooldown()
	{
		float cd; 
		this.GetValue("abilitycd", cd);
		this.SetCurrentCooldown(cd);
	}
	
	public bool CanEnd()
	{
		bool canend; this.GetValue("this_end", canend);
		return canend;
	}
	
	public float GetCost() {
		float cost;
		this.GetValue("this_cost", cost);
		return cost;
	}
	public float SetCost(float cost) {
		this.SetValue("this_cost", cost);
	}
	
}

FF2Parse GlobalAMS[MAXCLIENTS];
AMSSettings AMS_Settings[MAXCLIENTS][MAXABILITIES];

public AMSResult Handle_AMSPreAbility(int client, int index)
{
	Call_StartForward(AMSForward[hPreAbility]);
	Call_PushCell(client);
	int idx = index;
	Call_PushCellRef(idx);
	AMSResult action = AMS_Ignore;
	Call_PushCellRef(action);
	Action result = Plugin_Continue;
	Call_Finish(result);
	if(result == Plugin_Stop) {
		return AMS_Deny;
	}
	else if(result != Plugin_Continue) {
		index = idx;
	}
	if(result == Plugin_Handled && action != AMS_Ignore) {
		return action;
	}
	return AMS_CanInvoke(client, index);
}

static AMSResult AMS_CanInvoke(int client, int index)
{
	AMSResult AMSAction = AMS_Accept;
	Handle hPlugin;
	Function hFunc;
	if(AMS_GetThisFunction(client, index, "%s_CanInvoke", hPlugin, hFunc)) {
		Call_StartFunction(hPlugin, hFunc);
		Call_PushCell(client);
		Call_PushCell(index);
		Call_Finish(AMSAction);
	}
	if(AMSAction == AMS_Overwrite) {
		if(AMS_GetThisFunction(client, index, "%s_Overwrite", hPlugin, hFunc)) {
			Call_StartFunction(hPlugin, hFunc);
			Call_PushCell(client);
			Call_PushCell(index);
			Call_Finish();
		}
	} else if(AMSAction == AMS_Accept) {
		AMS_Settings[client][index].AddCooldown();
	}
	return AMSAction;
}

static void AMS_DoInvoke(int client, int index)
{
	Handle hPlugin;
	Function hFunc;
	if(AMS_GetThisFunction(client, index, "%s_Invoke", hPlugin, hFunc)) {
		Call_StartFunction(hPlugin, hFunc);
		Call_PushCell(client);
		Call_PushCell(index);
		Call_Finish();
		
		static char buffer[64];
		GlobalAMS[client].GetString("cast-particle", buffer, sizeof(buffer));
		if(!IsEmptyString(buffer)) {
			CreateTimedParticle(client, buffer, 1.0);
		}
	}
}

public void Handle_AMSOnAbility(int client, int index)
{
	Call_StartForward(AMSForward[hOnAbility]);
	Call_PushCell(client);
	Call_PushCell(index);
	static char plugin[64]; AMS_Settings[client][index].GetString("this_plugin", plugin, sizeof(plugin));
	Call_PushString(plugin);
	AMS_Settings[client][index].GetString("ability", plugin, sizeof(plugin));
	Call_PushString(plugin);
	Call_Finish();
	
	AMS_DoInvoke(client, index);
}

public void Handle_AMSOnEnd(int client, int index)
{
	Call_StartForward(AMSForward[hPreForceEnd]);
	Call_PushCell(client);
	int idx = index;
	Call_PushCellRef(idx);
	AMSResult action = AMS_Ignore;
	Call_PushCellRef(action);
	Action result = Plugin_Continue;
	Call_Finish(result);
	if(result == Plugin_Stop || action <= AMS_Deny) {
		return;
	}
	else if(result != Plugin_Continue) {
		index = idx;
	}
	
	Handle hPlugin;
	Function hFunc;
	if(AMS_GetThisFunction(client, index, "%s_EndAbility", hPlugin, hFunc)) {
		Call_StartFunction(hPlugin, hFunc);
		Call_PushCell(client);
		Call_PushCell(index);
		Call_Finish();
	}
}

static bool AMS_GetThisFunction(int client, int index, const char[] format, Handle &IPlugin, Function &Func)
{
	
	if(!AMS_Settings[client][index].GetValue("this", IPlugin) || IPlugin == null) {
		return false;
	}
	
	static char func[32], prefix[8];
	if(!AMS_Settings[client][index].GetPrefix(prefix, sizeof(prefix))) {
		return false;
	}
	
	FormatEx(func, sizeof(func), format, prefix);
	Func = GetFunctionByName(IPlugin, func);
	return Func != INVALID_FUNCTION;
}

static stock void CreateTimedParticle(int client, char[] particle, float duration)
{
	int entity = CreateEntityByName("info_particle_system");
	
	float vecPos[3]; GetEntPropVector(client, Prop_Send, "m_vecOrigin", vecPos);
	TeleportEntity(entity, vecPos, NULL_VECTOR, NULL_VECTOR);

	static char buffer[64];
	FormatEx(buffer, sizeof(buffer), "target%i", client);
	DispatchKeyValue(client, "targetname", buffer);

	DispatchKeyValue(entity, "targetname", "tf2particle");
	DispatchKeyValue(entity, "parentname", buffer);
	DispatchKeyValue(entity, "effect_name", particle);
	DispatchSpawn(entity);
	
	SetVariantString(buffer);
	AcceptEntityInput(entity, "SetParent", entity, entity);
	
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "start");
	
	CreateTimer(duration, Timer_KillEntity, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_KillEntity(Handle timer, any EntRef)
{
	int entity = EntRefToEntIndex(EntRef);
	if(IsValidEntity(entity))
		RemoveEntity(entity);
}
