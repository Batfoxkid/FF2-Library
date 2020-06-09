#if defined _01PX_Included
 #endinput
#endif
#define _01PX_Included

#include <tf2_stocks>
#include <freak_fortress_2>

#define IsEmptyString(%1)	(%1[0]=='\0')
#define BossToClient(%1)	(GetClientOfUserId(FF2_GetBossUserId(%1)))
#define ClientToBoss(%1)	(FF2_GetBossIndex(%1))
#define Dereference(%1)		(view_as<Address>(LoadFromAddress(%1, NumberType_Int32)))
#define MAXCLIENTS			(MAXPLAYERS+1)
#define FAST_REG(%1)		this_plugin_name, #%1

methodmap FF2Plugins < StringMap {
	public FF2Plugins() {
		char name[PLATFORM_MAX_PATH];
		StringMap map = new StringMap();
			
		Handle plugin = null;
		Handle iter = GetPluginIterator();
		Function func = INVALID_FUNCTION;
		
		while (MorePlugins(iter)) {
			if(!(plugin = ReadPlugin(iter))) {
				continue;
			}
			
			func = GetFunctionByName(plugin, "FF2_OnAbility2");
			if(func == INVALID_FUNCTION) {
				continue;
			}
			
			GetPluginFilename(plugin, name, sizeof(name));
			ReplaceString(name, sizeof(name), "freaks\\", "");
			name[strlen(name) - 4] = '\0';
			map.SetValue(name, plugin);
		}
		delete iter;
		
		if(!map.Size) {
			delete map;
		}
		return view_as<FF2Plugins>(map);
	}
	
	public Handle FindContextByName(const char[] name) {
		Handle val = null;
		if(!this.GetValue(name, val) || !val) {
			return null;
		}
		return val;
	}
}

methodmap FF2Prep {
	/**
	 *	[ CONSTRUCTOR ]
	 *
	 * @param player	 : client's gameplayer index
	 * @param isclient : false to use boss index instead
	 *
	 * @return			FF2Player's player pointer
	 */
	public FF2Prep(int user, bool isclient=true) {
		return view_as<FF2Prep>((isclient) ? ClientToBoss(user):user);
	}
	
	/**
	 *	int FF2Prep::boss
	 *
	 *	@brief			: return player's boss index
	 *
	 * @return		
	 */
	property int boss {
		public get() {
			return view_as<int>(this);
		}
	}
	
	/**
	 *	int FF2Prep::Index
	 *
	 *	@brief			: return player's gameplayer index
	 *
	 * @return		
	 */
	property int Index {
		public get() {
			return BossToClient(this.boss);
		}
	}
	
	/**
	 *	KeyValues FF2Prep::KeyValues
	 *
	 *	@brief			: return boss' KeyValue Handle
	 *
	 * @return
	 */
	property KeyValues KeyValues {
		public get() {
			return view_as<KeyValues>(FF2_GetSpecialKV(this.boss));
		}
	}
	
	/**
	 *	bool FF2Prep::BuildBoss
	 *
	 *	@brief			: build path to boss config file
	 *
	 * @return		true on success, false others
	 */
	public bool BuildBoss(char[] path, int maxlen, char[] key) {
		KeyValues kv = this.KeyValues;
		if(!kv) {
			return false;
		}
		
		if(!kv.JumpToKey(key)) {
			return false;
		}
		
		char name[64];
		
		kv.GetString("name", name, sizeof(name));
		kv = null;
		BuildPath(Path_SM, path, maxlen, "configs/freak_fortress_2/%s.cfg", name);
		return FileExists(path);
	}
	
	/**
	 *	bool FF2Prep::HasAbility(const char[], const char[])
	 *
	 *	@brief			: checks if player has an the following ability/plugin
	 *
	 * @param plugin	: plugin_name
	 * @param ability	: ability_name
	 *
	 * @return			: true on success, false otherwise
	 */
	public bool HasAbility(const char[] plugin, const char[] ability) {
		if(this.boss < 0)
			return false;
		return FF2_HasAbility(this.boss, plugin, ability);
	}
	
	/**
	 *	Use FF2Prep::ForceAbility instead
	 *
	 *	bool FF2Prep::DoAbility(bool, const char[], const char[], int, int)
	 *
	 *	@brief			: similar to FF2_DoAbility()
	 *
	 * @param check	: extra checks, return false if player is not boss or doesn't have ability
	 * @param plugin	: plugin_name
	 * @param ability	: ability_name
	 * @param slot		: slot of charge meter
	 * > 0 - rage
	 *	> 1 - as usual, used for brave jump or teleport
	 *	> 2 - other charged abilities
	 * @param button	: key to activate ability
	 * > 0 - by call for medic
 	 *	> 1 - by right mouse button or duck
 	 *	> 2 - by reload button
	 *
	 * @return			: true on success/no check, false otherwise
	 */
	public bool DoAbility(bool check = true, const char[] plugin, const char[] ability, int slot = 4, int buttonmode = 0) {
		int boss = this.boss;
		if(check) {
			if(boss < 0)
				return false;
			
			else if(!this.HasAbility(plugin, ability))
				return false;
		}
		FF2_DoAbility(boss, plugin, ability, slot, buttonmode);
		return true;
	}
	
	/**
	 *	bool FF2Prep::ForceAbility(const char[], const char[], int)
	 *
	 *	@brief			: Use this instead of FF2_DoAbility 
	 *
	 * @param plugin_name: plugin_name
	 * @param ability	: ability_name
	 * @param status	: status
	 *
	 * @return			: true on success, false otherwise
	 */
	public bool ForceAbility(const char[] plugin_name, const char[] ability, int status = 4, bool refresh = false) {
		FF2Plugins plugins = FF2_LoadPrecachedPlugins(refresh);
		if(!plugins) {
			LogError("Failed to find any FF2 plugin");
			return false;
		}
		
		Handle plugin = plugins.FindContextByName(plugin_name);
		if(!plugin) {
			LogError("plugin \"%s\" does not exists", plugin_name);
			return false;
		}
		
		Call_StartFunction(plugin, GetFunctionByName(plugin, "FF2_OnAbility2"));
		Call_PushCell(this.boss);
		Call_PushString(plugin_name);
		Call_PushString(ability);
		Call_PushCell(status);
		return Call_Finish() == SP_ERROR_NONE;
	}
	
	/**
	 *	float FF2Prep::RageDist(const char[], const char[])
	 *
	 *	@brief			: retrieve boss' rage dist
	 *
	 * @param plugin	: plugin_name
	 * @param ability	: ability_name
	 *
	 * @return			: boss' rage dist if plugin/ability are empty string
	 */
	public float RageDist(const char[] plugin = "", const char[] ability = "") {
		FF2_GetRageDist(this.boss, plugin, ability);
	}
	
	/**
	 *	int FF2Prep::GetArgI(const char[], const char[], const char[], int, int)
	 *
	 *	@brief			: retrieve int value from boss' ability
	 *
	 * @param plugin	: plugin_name
	 * @param ability	: ability_name
	 * @param key		: arg name
	 * @param arg		: arg number
	 * @param def		: default value if key/arg doesn't exist
	 *
	 * @return			: the value/def
	 */
	public int GetArgI(const char[] plugin, const char[] ability, const char[] key, int arg = -10, int def) {
		return (GetFeatureStatus(FeatureType_Native, "FF2_GetArgNamedI") == FeatureStatus_Available ? 
		FF2_GetArgNamedI(this.boss, plugin, ability, key, def):FF2_GetAbilityArgument(this.boss, plugin, ability, arg = -10, def));
	}
	
	/**
	 *	float FF2Prep::GetArgF(const char[], const char[], const char[], int, int)
	 *
	 *	@brief			: retrieve float value from boss' ability
	 *
	 * @param plugin	: plugin_name
	 * @param ability	: ability_name
	 * @param key		: arg name
	 * @param arg		: arg number
	 * @param def		: default value if key/arg doesn't exist
	 *
	 * @return			: the value/def
	 */
	public float GetArgF(const char[] plugin, const char[] ability, const char[] key, int arg = -10, float def) {
		return (GetFeatureStatus(FeatureType_Native, "FF2_GetArgNamedF") == FeatureStatus_Available ? 
		FF2_GetArgNamedF(this.boss, plugin, ability, key, def):FF2_GetAbilityArgumentFloat(this.boss, plugin, ability, arg = -10, def));
	}
	
	/**
	 *	bool FF2Prep::GetArgS(const char[], const char[], const char[], int, char[], int)
	 *
	 *	@brief			: retrieve string from boss' ability 
	 *
	 * @param plugin	: plugin_name
	 * @param ability	: ability_name
	 * @param key		: arg name
	 * @param arg		: arg number
	 * @param buffer	: buffer to store string at
	 * @param size		: strlen(buffer)
	 *
	 * @return			: true on success, false otherwise
	 */
	public bool GetArgS(const char[] plugin, const char[] ability, const char[] key, int arg = -10, char[] buffer, int size) {
		switch(GetFeatureStatus(FeatureType_Native, "FF2_GetArgNamedS")) 
		{
			case FeatureStatus_Available: {
				FF2_GetArgNamedS(this.boss, plugin, ability, key, buffer, size);
				if(IsEmptyString(buffer))
					FF2_GetAbilityArgumentString(this.boss, plugin, ability, arg, buffer, size);
			}
			default: {
				FF2_GetAbilityArgumentString(this.boss, plugin, ability, arg, buffer, size);
			}
		}
		return (!IsEmptyString(buffer));
	}
	
	/**
	 *	int FF2Prep::GetButton(const char[], const char[], const char[], int, int)
	 *
	 *	@brief			: convert a string to button bits
	 *
	 * @param plugin	: plugin_name
	 * @param ability	: ability_name
	 * @param key		: arg name
	 * @param arg		: arg number
	 * @param def		: default value if key/arg wasn't found
	 *
	 * @return			: the key value/def
	 */
	public int GetButton(const char[] plugin, const char[] ability, const char[] key, int arg = -10, int def) {
		char buffer[32];
		if(!this.GetArgS(plugin, ability, key, arg, buffer, sizeof(buffer)))
			return def;
		if(!strcmp(buffer, "reload"))
			return IN_RELOAD;
		else if(!strcmp(buffer, "attack3"))
			return IN_ATTACK3;
		else if(!strcmp(buffer, "attack2"))
			return IN_ATTACK2;
		return def;
	}
	
	/**
	 *	bool FF2Prep::PrepareString(int, char[], int)
	 *
	 *	@brief			: adjust an imported string
	 *
	 * @param type		: 1- HUD, 2-Precache sound
	 * @param buffer	: text
	 * @param size		: strlen(text)
	 *
	 * @return			: true on success, false otherwise
	 */
	public bool PrepareString(int type, char[] buffer, int size)
	{
		switch(type) {
			case 0 : return !!ReplaceString(buffer, size, "\\n", "\n");
			case 1 :	return PrecacheSound(buffer);
			default: return false;
		}
	}
}

stock FF2Plugins FF2_LoadPrecachedPlugins(bool refresh)
{
	static FF2Plugins plugins = null;
	if(refresh && plugins) {
		delete plugins;
	}
	if(!plugins) {
		plugins = new FF2Plugins();
	}
	return plugins;
}



enum Validity {
	Invalid,
	Any,
	AnyAlive,
	IsRed,
	IsBlu,
	IsBoss
};

/**
 *	bool ValidatePlayer(int, Validity)
 *
 *	@brief			: checks if FF2 round is active
 *
 * @param client	 : client's gameplayer index
 * @param Validity : Type:
 * > Invalid  : useless, return false
 * > Any		  : return return true if client is in game
 * > AnyAlive : Any + IsPlayerAlive()
 * > IsRed	  : Any + TFTeam==Red
 * > IsBlu	  : Any + TFTeam==Blue
 * > IsBoss	  : Any + Player is a boss
 *
 * @return			: results
 */
stock bool ValidatePlayer(int client, Validity Type)
{
	if(client <= 0 || client > MaxClients)
		return false;
	
	if(!IsClientInGame(client))
		return false;
	
	if(IsClientSourceTV(client) || IsClientReplay(client))
		return false;
	
	if(!!GetEntProp(client, Prop_Send, "m_bIsCoaching"))
		return false;
	
	switch(Type)
	{
		case Any:		return true;
		case AnyAlive: return IsPlayerAlive(client);
		case IsRed:		return TF2_GetClientTeam(client)==TFTeam_Red;
		case IsBlu:		return TF2_GetClientTeam(client)==TFTeam_Blue;
		case IsBoss:	return FF2_GetBossIndex(client)>=0;
	}
	return false;
}

/**
 *	bool IsRoundActive()
 *
 *	@brief			: checks if FF2 round is active
 *
 * @return			: true on success, false otherwise
 */
stock bool IsRoundActive()
{
	return (FF2_IsFF2Enabled() && FF2_GetRoundState() == 1);
}

stock bool StringToHex(const char[] key, int &result)
{
	int size = strlen(key);
	if(size < 3)
		return false;
	if(strncmp(key, "0x", 2, false))
		return false;
	
	result = 0;
	int pos = 2, x;
	char[] buffer = new char[size-2];
	while(pos < size) {
		switch(key[pos]) {
			case 	'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
					'a', 'b', 'c', 'd', 'e', 'f',
					'A', 'B', 'C', 'D', 'E', 'F': {
				buffer[x++] = key[pos++];
			}
			default :{
				LogError("Invalid Key '%s' parsed", key[pos++]);
			}
		}
	}
	result = StringToInt(buffer, 16);
	return (pos > 2);
}
