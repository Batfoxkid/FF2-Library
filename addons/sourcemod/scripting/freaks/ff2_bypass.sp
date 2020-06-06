#include <ff2_helper>

#pragma semicolon 1
#pragma newdecls required

bool IsActive;

#define this_ability_name "ff2_unload"
#define this_plugin_name "ff2_bypass"
#define CFG_DIRECTORY "plugins/freaks/"...this_ability_name

ArrayStack List;

public Plugin myinfo = 
{
	author		= "[01]Pollux."
};

public void OnPluginStart2()
{
	HookEvent("arena_win_panel", Post_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Post_RoundStart, EventHookMode_PostNoCopy);
	if(IsRoundActive())	
		Post_RoundStart(null, "plugin_lateload", false);
}

public void OnMapEnd()
{
	Post_RoundEnd(null, "plugin_unload", false);
}

public void Post_RoundEnd(Event hevent, const char[] name, bool dontBroadcast)
{
	if(IsActive)
	{
		char plugin[PLATFORM_MAX_PATH];
		while(!List.Empty) {
			List.PopString(plugin, sizeof(plugin));
			ServerCommand("sm plugins load %s", plugin);
		}
		delete List;
		IsActive = false;
	}
}

public void Post_RoundStart(Event hevent, const char[] name, bool dontBroadcast)
{
	IsActive = false;
	for (int client = 1; client <= MaxClients; client++)
	{
		if(!ValidatePlayer(client, AnyAlive))
			continue;
		
		FF2Prep boss = FF2Prep(client);
		if(!boss.HasAbility(this_plugin_name, this_ability_name))
			continue;
		
		char Path[PLATFORM_MAX_PATH];
		if(!boss.GetArgS(this_plugin_name, this_ability_name, "directory", 1, Path, sizeof(Path)))
			continue;
		if(!IsActive) IsActive = true;
		if(List==null) List = new ArrayStack(ByteCountToCells(PLATFORM_MAX_PATH));
		Prep_PluginsUnload(Path);
	}
}

void Prep_PluginsUnload(const char[] dir)
{
	SMCParser plugins = new SMCParser();

	plugins.OnKeyValue = SMC_OnNextKeyValue;
	
	char[] cfg = new char[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, cfg, PLATFORM_MAX_PATH, "%s/%s", CFG_DIRECTORY, dir);
	SMCError Error = plugins.ParseFile(cfg);
	if(Error != SMCError_Okay) {
		char err[64];
		plugins.GetErrorString(Error, err, sizeof(err));
		LogError("[FF2] SMCError : %s", err);
	}
	delete plugins;
}

public SMCResult SMC_OnNextKeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	ServerCommand("sm plugins unload %s", value);
	List.PushString(value);
	return SMCParse_Continue;
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status){
}
