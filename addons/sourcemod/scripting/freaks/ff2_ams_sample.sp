#include <ff2_ams2>
#include <ff2_helper>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

bool Ability_IsAMS[MAXPLAYERS+1]; // global boolean to use with AMS

public Plugin myinfo = {
    name = "[FF2] AMS2 : plugin sample",
    author = "01Pollux",
    version = "1.0",
};

#define ABILITY_SAMPLE "rage_sample" // ability name
#define ABILITY_PREFIX "SMPL"  // abbreviation of ability name

/*
	//check include for more infos
	public AMSResult <ABILITY_PREFIX>_CanInvoke(int client, int index)
	public void <ABILITY_PREFIX>_Invoke(int client, int index)
	public void <ABILITY_PREFIX>_Overwrite(int client, int index)
	public void <ABILITY_PREFIX>_EndAbility(int client, int index)
	
	//since we have ABILITY_PREFIX as SMPL, it would then be written as:
	public AMSResult SMPL_CanInvoke(int client, int index)
	public void SMPL_Invoke(int client, int index)
	public void SMPL_Overwrite(int client, int index)
	public void SMPL_EndAbility(int client, int index)
	
	//ABILITY_PREFIX will be initialized during Post_"arena_round_start"
	//Im unsure about if its safe to late reload plugin, but i will be adding a way to remove an index from AMS-StringHashMap
	//NOTE: AMS won't guarantee to work properly if initialized outside FF2AMS_PreRoundStart(), (first round of ff2 problem)
*/

public void OnPluginStart2()
{
	HookEvent("arena_round_start", Post_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", Post_RoundEnd, EventHookMode_PostNoCopy);
}

public Action FF2_OnAbility2(int boss, const char[] plugin, const char[] ability, int status)
{
	if(!IsRoundActive())
		return Plugin_Continue;
		
	int client = BossToClient(boss);
	if(!strcmp(ability, ABILITY_SAMPLE)) {
		if(!Ability_IsAMS[client] ) {
			SMPL_Invoke(client, -1);	// Activate RAGE normally, if ability is configured to be used as a normal RAGE. index here doesn't matter
		}
	}
	return Plugin_Continue;
}

public void Post_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(!IsRoundActive())		//ff2_helper.inc
		return;
		
	Prep_StartAbilities();
}

public void FF2AMS_PreRoundStart(int client)
{
	FF2Prep player = FF2Prep(client);		//ff2_helper.inc
	if(player.HasAbility(this_plugin_name, ABILITY_SAMPLE)) {	//always true if player is boss + hasability
		if(LibraryExists("FF2AMS")) {		//check if ams plugin exists
			Ability_IsAMS[client] = FF2AMS_IsAMSActivatedFor(client) && FF2AMS_PushToAMS(client, this_plugin_name, ABILITY_SAMPLE, ABILITY_PREFIX);	//return true if pushing was successful
			//FF2AMS_PushToAMSEx is the same as non-Ex but instead return ability index
		}
	}
}

void Prep_StartAbilities()
{
	for(int client = 1; client <= MaxClients; client++) {
		if(!ValidatePlayer(client, Any))		//ff2_helper.inc
			continue;
		
		//here initialize any non-ams ability if needed
		
	}
}

public void Post_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for(int client=1; client<=MaxClients; client++) {
		if(ValidatePlayer(client, Any)) {
			Ability_IsAMS[client]=false; // cleanup
		}
	}
}

public AMSResult SMPL_CanInvoke(int client, int index)
{
	/*
		specify any conditions that would prevent this ability.
		returning AMS_Overwrite will call SMPL_Overwrite.
		returning any value other than AMS_Accept will block the ability.
		
		Use FF2AMS_GetAMSHashMap(client, index) if you need to look into ability context, DO NOT delete the StringMap
	*/
	return AMS_Accept;
}

public void SMPL_Invoke(int client, int index)
{
	FF2Prep player = FF2Prep(client);
	/*
		Insert your boss RAGE ability code here
		
		Use FF2AMS_GetAMSHashMap(client, index) if you need to look into/change ability context, DO NOT delete the StringMap
	*/
	
	char message[124];	
	
	if(player.GetArgS(this_plugin_name, ABILITY_SAMPLE, "message", 1, message, sizeof(message))) {
		PrintToChatAll(message);
		
		if(Ability_IsAMS[client]) {
			StringMap hMap = FF2AMS_GetAMSHashMap(client, index);
			
			hMap.GetString("display_desc", message, sizeof(message));
			PrintToChatAll("this rage description : \"%s\"", message);
			
			RequestFrame(NextFrame_ChangeCost, hMap);
			//cost will be changed a frame after we set it, to avoid negative boss rage, we will be requesting a new frame
			hMap.SetString("display_desc", "this new description with new 30.0% cost");
		}
	}
}

public void NextFrame_ChangeCost(StringMap hMap)
{
	hMap.SetValue("this_cost", 30.0);
}
