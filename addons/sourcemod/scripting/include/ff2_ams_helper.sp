
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
	public AMSHash(const FF2Player player, Handle plugin, const char[] pl_name, const char[] ab_name, const char[] prefix)
	{
		StringMap map = new StringMap();
		
		map.SetValue("this", plugin);
		map.SetString("this_plugin", pl_name);
		map.SetString("prefix", prefix);
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
	
	public bool GetPrefix(char[] prefix, int size) {
		return this.GetString("prefix", prefix, size);
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
	
	public bool GetFunction(const char[] key, Function& fn)
	{
		Function_t _fn;
		if(this.GetArray(key, _fn, sizeof(Function_t))) {
			fn = _fn.fn;
			return true;
		}
		return false;
	}
	
	public void SetFunction(const char[] key, Function& fn)
	{
		Function_t _fn; _fn.fn = fn;
		this.SetArray(key, _fn, sizeof(Function_t));
	}
}

methodmap AMSSettings < ArrayList {
	public AMSSettings() {
		return view_as<AMSSettings>(new ArrayList());
	}
	
	public int Register(const FF2Player player, Handle plugin, const char[] pl_name, const char[] ab_name, const char[] prefix)
	{
		return this.Push(new AMSHash(player, plugin, pl_name, ab_name, prefix));
	}
}


enum struct AMSData_t {
	char szActive[124];
	char szInactive[124];
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
}


methodmap DeleteStack < ArrayStack {
	public DeleteStack() 
	{ 
		return view_as<DeleteStack>(new ArrayStack());
	}
	
	public void Flush()
	{
		if(!this)
			return;
		
		ConfigMap curCfg;
		while(!this.Empty)
		{
			curCfg = this.Pop();
			DeleteCfg(curCfg);
		}
	}
}
DeleteStack g_hDeleteStack;


methodmap AMSMap < ConfigMap 
{
	public AMSMap GetSection(const char[] section) {
		return view_as<AMSMap>(this.GetSection(section));
	}
	
	public AMSMap(const char[] path) {
		
		AMSMap cfg = view_as<AMSMap>(new ConfigMap(path));
		
		AMSMap ams_base = cfg.GetSection("character.ams_sys");
		if(!ams_base) {
			DeleteCfg(view_as<ConfigMap>(cfg));
			return null;
		}
		
		g_hDeleteStack.Push(cfg);
		
		return ams_base;
	}
	
	public int GetButton(const char[] key) {
		char val[8];
		if(!this.Get(key, val, sizeof(val)))
			return IN_RELOAD;
		
		if(!strcmp(val, "reload"))
			return IN_RELOAD;
		else if(!strcmp(val, "mouse3"))
			return IN_ATTACK3;
		else if(!strcmp(val, "mouse2"))
			return IN_ATTACK2;
		
		else return 0;
	}
}

AMSMap g_hAMSMap[MAXCLIENTS];

Handle hAMSHud;


bool CreateAMS(const AMSUser player)
{
	char path[PLATFORM_MAX_PATH];
	player.GetConfigName(path, sizeof(path));
	Format(path, sizeof(path), "configs/freak_fortress_2/%s.cfg", path);
	int client = player.index;
	
	if( !(g_hAMSMap[client] = new AMSMap(path)) )
		return false;
	
	AMSMap data = g_hAMSMap[client];
	AMSMap hud_data = data.GetSection("hud");
	
	int res;
	if(!hud_data.Get("cactive", path, sizeof(path)))
		res = 0x00FF00FF;
	else res = StringToInt(path, 16);
	player.rgba_on = res;
	
	if(!hud_data.Get("cinactive", path, sizeof(path)))
		res = 0x00FF00FF;
	else res = StringToInt(path, 16);
	player.rgba_off = res;
	
	AMSData[client].iActivateKey = data.GetButton("activation");
	AMSData[client].iForwardKey = data.GetButton("selection");
	AMSData[client].iReverseKey = data.GetButton("reverse");
	
	hud_data.Get("active", AMSData[client].szActive, sizeof(AMSData_t::szActive));
	hud_data.Get("inactive", AMSData[client].szInactive, sizeof(AMSData_t::szInactive));
	hud_data.GetFloat("y", AMSData[client].flHudPos);
	
	ReplaceString(AMSData[client].szActive, sizeof(AMSData_t::szActive), "\\n", "\n");
	ReplaceString(AMSData[client].szInactive, sizeof(AMSData_t::szInactive), "\\n", "\n");
	
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

void Handle_AMSOnAbility(int client, AMSHash data)
{
	Call_StartForward(AMSForward[hOnAbility]);
	Call_PushCell(client);
	Call_PushCell(data);
	Call_Finish();
	
	AMS_DoInvoke(client, data);
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
	if(AMS_GetCallback(data, "%s_EndAbility", hPlugin, hFunc)) {
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
	if(AMS_GetCallback(data, "%s_CanInvoke", hPlugin, hFunc)) {
		Call_StartFunction(hPlugin, hFunc);
		Call_PushCell(client);
		Call_PushCell(data);
		Call_Finish(AMSAction);
	}
	if(AMSAction == AMS_Overwrite) {
		if(AMS_GetCallback(data, "%s_Overwrite", hPlugin, hFunc)) {
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

static void AMS_DoInvoke(int client, AMSHash data)
{
	Handle hPlugin;
	Function hFunc;
	if(AMS_GetCallback(data, "%s_Invoke", hPlugin, hFunc)) {
		Call_StartFunction(hPlugin, hFunc);
		Call_PushCell(client);
		Call_PushCell(data);
		Call_Finish();
		
		static char buffer[64];
		g_hAMSMap[client].GetString("cast-particle", buffer, sizeof(buffer));
		if(buffer[0])
			CreateTimedParticle(client, buffer, 1.0);
	}
}



static bool AMS_GetCallback(AMSHash data, const char[] format, Handle &IPlugin, Function &Func)
{
	if(!data.GetValue("this", IPlugin) || IPlugin == null)
		return false;
	
	static char func[32], prefix[8];
	FormatEx(func, sizeof(func), format, prefix);
	
	if(!data.GetPrefix(prefix, sizeof(prefix)))
		return false;
	
	if(!data.GetFunction(func, Func))
	{
		Func = GetFunctionByName(IPlugin, func);
		data.SetFunction(func, Func);
	}
	
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
