
enum AMSType: {
	TYPE_CanInvoke,
	TYPE_Invoke,
	TYPE_Overwrite,
	TYPE_End,
	
	AMSTypes
};

enum AMSResult 
{
	AMS_INVALID = -1,
	AMS_Ignore,
	AMS_Deny,
	AMS_Accept,
	AMS_Overwrite
};


enum struct Function_t {
	Function fn;
}

methodmap AMSHash < StringMap
{
	public AMSHash(	const FF2Player player, 
					Handle plugin, const char[] pl_name, const char[] ab_name, 
					Function can_invoke = INVALID_FUNCTION,
					Function invoke = INVALID_FUNCTION,
					Function overwrite = INVALID_FUNCTION,
					Function on_end = INVALID_FUNCTION 
				  )
	{
		StringMap map = new StringMap();
		
		
		{
				
			Function_t fn;
			fn.fn = can_invoke;
			map.SetArray("callack"...TEXT(0), fn, sizeof(Function_t));
			fn.fn = invoke;
			map.SetArray("callack"...TEXT(1), fn, sizeof(Function_t));
			fn.fn = overwrite;
			map.SetArray("callack"...TEXT(2), fn, sizeof(Function_t));
			fn.fn = on_end;
			map.SetArray("callack"...TEXT(3), fn, sizeof(Function_t));
		}
		
		map.SetValue("this", plugin);
		map.SetString("this_plugin", pl_name);
		map.SetString("ability", ab_name);
		map.SetValue("cooldown", GetGameTime() + 	player.GetArgF(pl_name, ab_name, "initial cd", 0.0));
		map.SetValue("abilitycd", player.GetArgF(pl_name, ab_name, "ability cd", 10.0));
		
		char str[128]; player.GetArgS(pl_name, ab_name, "this_name", str, sizeof(str));
		map.SetString("this_name", str);
		
		player.GetArgS(pl_name, ab_name, "display_desc", str, sizeof(str));
		map.SetString("ability desc", str);
		
		map.SetValue("this_cost", player.GetArgF(pl_name, ab_name, "cost", 25.0));
		map.SetValue("this_end", player.GetArgI(pl_name, ab_name, "can end", 0));
		
		return view_as<AMSHash>(map);
	}
	
	public Function GetFunction(AMSType type)
	{
		char key[12];
		FormatEx(key, sizeof(key), "callback%i", type);
		
		Function_t fn;
		return this.GetArray(key, fn, sizeof(Function_t)) ? fn.fn:INVALID_FUNCTION;
	}
	
	property float flCooldown {
		public get() {
			float cd;
			return this.GetValue("cooldown", cd) ? cd:0.0;
		}
		public set(const float cd) {
			this.SetValue("cooldown", cd + GetGameTime());
		}
	}
	
	property float flInternalCd {
		public get() {
			float cd;
			return this.GetValue("abilitycd", cd) ? cd:0.0;
		}
	}
	
	property float flCost {
		public get() {
			float c;
			return this.GetValue("this_cost", c) ? c:0.0;
		}
		public set(const float c) {
			this.SetValue("this_cost", c);
		}
	}
	
	property bool bCanEnd {
		public get() {
			bool b;
			return this.GetValue("this_end", b) ? b:false;
		}
	}
}

methodmap AMSSettings < ArrayList {
	public AMSSettings() {
		return view_as<AMSSettings>(new ArrayList());
	}
	
	public int Register(const FF2Player player, 
						Handle plugin, const char[] pl_name, const char[] ab_name, 
						Function can_invoke = INVALID_FUNCTION,
						Function invoke = INVALID_FUNCTION,
						Function overwrite = INVALID_FUNCTION,
						Function on_end = INVALID_FUNCTION
						)
	{
		return this.Push(new AMSHash(player, plugin, pl_name, ab_name, can_invoke, invoke, overwrite, on_end));
	}
}


enum struct AMSData_t {
	char szActive[128];
	char szInactive[128];
	float flHudPos;
	
	int iForwardKey;
	int iReverseKey;
	int iActivateKey;
	
	int Pos;
	AMSSettings hAbilities;
	
	void MoveForward()
	{
		++this.Pos;
		this.Pos %= this.hAbilities.Length;
	}
	void MoveBackward()
	{
		this.Pos = !this.Pos ? this.hAbilities.Length - 1:--this.Pos;
	}
}
AMSData_t AMSData[MAXCLIENTS];


methodmap AMSUser < FF2Player 
{
	public AMSUser(const int index, bool userid = false) {
		return view_as<AMSUser>(FF2Player(index, userid));
	}
	
	property int rgba_on {
		public get() {
			return this.GetPropInt("rgba_ColorAMS_ON");
		}
		public set(const int c) {
			this.SetPropInt("rgba_ColorAMS_ON", c);
		}
	}
	
	property int rgba_off {
		public get() {
			return this.GetPropInt("rgba_ColorAMS_OFF");
		}
		public set(const int c) {
			this.SetPropInt("rgba_ColorAMS_OFF", c);
		}
	}
	
	public void GetUserData(AMSData_t data)
	{
		data = AMSData[this.index];
	}
	
	property bool bHasAMS {
		public get() {
			return this.GetPropAny("bHasAMS");
		}
		public set(const bool b) {
			this.SetPropAny("bHasAMS", b);
		}
	}
	
	property bool bWantsToRage {
		public get() {
			return this.GetPropAny("ams_bWantsToRage");
		}
		public set(const bool b) {
			this.SetPropAny("ams_bWantsToRage", b);
		}
	}
	
	property float flLastThink {
		public get() {
			return this.GetPropFloat("ams_flLastThink");
		}
		public set(const float f) {
			this.SetPropFloat("ams_flLastThink", f);
		}
	}
	
	
	public int GetButton(const char[] key) 
	{
		char val[8];
		if(!this.GetString(key, val, sizeof(val)))
			return 0;
		
		if(!strcmp(val, "reload"))
			return IN_RELOAD;
		else if(!strcmp(val, "mouse3"))
			return IN_ATTACK3;
		else if(!strcmp(val, "mouse2"))
			return IN_ATTACK2;
		
		else return 0;
	}
}


bool CreateAMS(const AMSUser player)
{
	int client = player.index;
	
	if( !player.GetString(_AMS_TAG "hud.active", AMSData[client].szActive, sizeof(AMSData_t::szActive)) ||
		!player.GetString(_AMS_TAG "hud.inactive", AMSData[client].szInactive, sizeof(AMSData_t::szInactive)) )
		return false;
	
	ReplaceString(AMSData[client].szActive, sizeof(AMSData_t::szActive), "\\n", "\n");
	ReplaceString(AMSData[client].szInactive, sizeof(AMSData_t::szInactive), "\\n", "\n");
	
	char buffer[10];
	int res;
	if(!player.GetString(_AMS_TAG "hud.cactive", buffer, sizeof(buffer)))
		res = 0x0000FFFF;
	else res = StringToInt(buffer, 16);
	player.rgba_on = res;
	
	if(!player.GetString(_AMS_TAG "hud.cinactive", buffer, sizeof(buffer)))
		res = 0xFF0000FF;
	else res = StringToInt(buffer, 16);
	player.rgba_off = res;
	
	AMSData[client].iActivateKey = player.GetButton(_AMS_TAG "activation");
	AMSData[client].iForwardKey = player.GetButton(_AMS_TAG "selection");
	AMSData[client].iReverseKey = player.GetButton(_AMS_TAG "reverse");
	
	player.GetFloat(_AMS_TAG "hud.y", AMSData[client].flHudPos);
	
	AMSData[client].hAbilities = new AMSSettings();
	AMSData[client].Pos = 0;
	
	player.bHasAMS = true;
	player.SetPropAny("bSupressRAGE", true);
	
	return true;
}


AMSResult Handle_AMSPreAbility(int client, AMSHash data)
{
	Call_StartForward(AMSForward[hPreAbility]);
	Call_PushCell(client);
	Call_PushCellRef(data);
	AMSResult action = AMS_Ignore;
	Call_PushCellRef(action);
	Action result = Plugin_Continue;
	Call_Finish(result);
	if(result == Plugin_Stop) {
		return AMS_Deny;
	}
	
	if(result == Plugin_Handled && action != AMS_Ignore) {
		return action;
	}
	return AMS_CanInvoke(client, data);
}

void Handle_AMSOnAbility(FF2Player player, AMSHash data)
{
	int client = player.index;
	Call_StartForward(AMSForward[hOnAbility]);
	Call_PushCell(client);
	Call_PushCell(data);
	Call_Finish();
	
	AMS_DoInvoke(player, data);
}

void Handle_AMSOnEnd(int client, AMSHash data)
{
	Call_StartForward(AMSForward[hPreForceEnd]);
	Call_PushCell(client);
	Call_PushCellRef(data);
	AMSResult action = AMS_Ignore;
	Call_PushCellRef(action);
	Action result = Plugin_Continue;
	Call_Finish(result);
	if(result == Plugin_Stop || action <= AMS_Deny) {
		return;
	}
	
	Handle hPlugin;
	Function hFunc;
	if(AMS_GetCallback(data, TYPE_End, hPlugin, hFunc)) {
		Call_StartFunction(hPlugin, hFunc);
		Call_PushCell(client);
		Call_PushCell(data);
		Call_Finish();
	}
}


static AMSResult AMS_CanInvoke(int client, AMSHash data)
{
	AMSResult AMSAction = AMS_Accept;
	Handle hPlugin;
	Function hFunc;
	if(AMS_GetCallback(data, TYPE_CanInvoke, hPlugin, hFunc)) {
		Call_StartFunction(hPlugin, hFunc);
		Call_PushCell(client);
		Call_PushCell(data);
		Call_Finish(AMSAction);
	}
	if(AMSAction == AMS_Overwrite) {
		if(AMS_GetCallback(data, TYPE_Overwrite, hPlugin, hFunc)) {
			Call_StartFunction(hPlugin, hFunc);
			Call_PushCell(client);
			Call_PushCell(data);
			Call_Finish();
		}
	} else if(AMSAction == AMS_Accept) {
		data.flCooldown = data.flInternalCd;
	}
	return AMSAction;
}

static void AMS_DoInvoke(FF2Player player, AMSHash data)
{
	Handle hPlugin;
	Function hFunc;
	if(AMS_GetCallback(data, TYPE_Invoke, hPlugin, hFunc)) {
		int client = player.index;
		Call_StartFunction(hPlugin, hFunc);
		Call_PushCell(client);
		Call_PushCell(data);
		Call_Finish();
		
		static char buffer[64];
		player.GetString(_AMS_TAG "cast-particle", buffer, sizeof(buffer));
		if(buffer[0])
			CreateTimedParticle(client, buffer, 1.0);
	}
}



static bool AMS_GetCallback(AMSHash data, AMSType type, Handle &IPlugin, Function &Func)
{
	if (!data.GetValue("this", IPlugin) || !IPlugin)
		return false;
	
	return (Func = data.GetFunction(type)) != INVALID_FUNCTION;
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
