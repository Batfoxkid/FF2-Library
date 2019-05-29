#pragma semicolon 1

#include <tf2>
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2items>
#include <tf2_stocks>
#include <ff2_ams>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin> 

public Plugin:myinfo = {
	name = "Freak Fortress 2: Nightmare Sniper's Ability",
	author = "M7",
};

enum Operators
{
	Operator_None=0,
	Operator_Add,
	Operator_Subtract,
	Operator_Multiply,
	Operator_Divide,
	Operator_Exponent,
};

#define INACTIVE 100000000.0
#define NIGHTMARE "nightmare_rage"
new Float:EndNightmareAt;
new Float:EndFFAt;
new bool:SniperFF=false; // We use this in case FF is set from RAGE, and not from round events like end-of-round friendly fire 
new bool:NoVoice[MAXPLAYERS+1]=false; // Block voices while RAGE is active
new TFClassType:LastClass[MAXPLAYERS+1];
new String:NightmareModel[PLATFORM_MAX_PATH], String:NightmareClassname[64], String:NightmareAttributes[768];
new NightmareIndex, NightmareClass;
new bool:NightmareVoice;
new bool:Nightmare_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS

public OnPluginStart2()
{
	HookEvent("arena_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", OnRoundStart, EventHookMode_PostNoCopy);
	AddNormalSoundHook(SoundHook);
}

public Action:OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
		
	PrepareAbilities();
}

public PrepareAbilities()
{
	for(new client=1;client<=MaxClients;client++)
	{
		EndNightmareAt = INACTIVE;
		EndFFAt = INACTIVE;
		SniperFF=false;
		NoVoice[client]=false;
		
		if(IsValidClient(client))
		{
			Nightmare_TriggerAMS[client]=false;
			
			new boss=FF2_GetBossIndex(client);
			if(boss>=0 && FF2_HasAbility(boss, this_plugin_name, NIGHTMARE))
			{
				Nightmare_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, NIGHTMARE);
				if(Nightmare_TriggerAMS[client])
				{
					AMS_InitSubability(boss, client, this_plugin_name, NIGHTMARE, "NIGH"); // Important function to tell AMS that this subplugin supports it
				}
			}
		}
	}
}

public Action:FF2_OnAbility2(index,const String:plugin_name[],const String:ability_name[],action)
{
    //Make sure that RAGE is only allowed to be used when a FF2 round is active
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue;
		
	new client=GetClientOfUserId(FF2_GetBossUserId(index));
	if(!strcmp(ability_name,NIGHTMARE))	// Defenses
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			Nightmare_TriggerAMS[client]=false;
		}
		
		if(!Nightmare_TriggerAMS[client])
			NIGH_Invoke(client);
	}
	return Plugin_Continue;
}

public bool:NIGH_CanInvoke(client)
{
	return true;
}

public NIGH_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	
	char NightmareHealth[768];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, NIGHTMARE, 3, NightmareModel, sizeof(NightmareModel)); // Model that the players gets
	NightmareClass=FF2_GetAbilityArgument(boss, this_plugin_name, NIGHTMARE, 4); // class name
	FF2_GetAbilityArgumentString(boss, this_plugin_name, NIGHTMARE, 5, NightmareClassname, sizeof(NightmareClassname));
	NightmareIndex=FF2_GetAbilityArgument(boss, this_plugin_name, NIGHTMARE, 6);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, NIGHTMARE, 7, NightmareAttributes, sizeof(NightmareAttributes));
	NightmareVoice=bool:FF2_GetAbilityArgument(boss, this_plugin_name, NIGHTMARE, 8);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, NIGHTMARE, 9, NightmareHealth, sizeof(NightmareHealth));
	
	if(Nightmare_TriggerAMS[client])
	{
		new String:sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_nightmare_rage", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);	
		}
	}
	
	HookConVarChange(FindConVar("mp_friendlyfire"), HideCvarNotify);
	
	// And now proceed to rage
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsValidLivingPlayer(i) && GetClientTeam(i)!=FF2_GetBossTeam())
		{
			//First, Remove all weapons
			TF2_RemoveAllWeapons(i);
				
			//Then set the class to whatever class you want and give them a custom weapon (it should be the bosses weapon and class, otherwise it would kinda destroy the purpose of this RAGE)
			LastClass[i]=TF2_GetPlayerClass(i);
			if(TF2_GetPlayerClass(i)!=TFClassType:NightmareClass)
			{
				TF2_SetPlayerClass(i, TFClassType:NightmareClass);
			}
			
			SpawnWeapon(i, NightmareClassname, NightmareIndex, 5, 8, NightmareAttributes);
				
			//Then Remove all Wearables
			new entity, owner;
			while((entity=FindEntityByClassname(entity, "tf_wearable"))!=-1)
				if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)!=FF2_GetBossTeam())
					TF2_RemoveWearable(owner, entity);
			while((entity=FindEntityByClassname(entity, "tf_wearable_demoshield"))!=-1)
				if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)!=FF2_GetBossTeam())
					TF2_RemoveWearable(owner, entity);
			while((entity=FindEntityByClassname(entity, "tf_powerup_bottle"))!=-1)
				if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)!=FF2_GetBossTeam())
					TF2_RemoveWearable(owner, entity);
				
			//Now setting the Model for the victims (should be the model of the boss, otherwise this RAGE is kinda useless)
			PrecacheModel(NightmareModel);
			SetVariantString(NightmareModel);
			AcceptEntityInput(i, "SetCustomModel");
			SetEntProp(i, Prop_Send, "m_bUseClassAnimations", 1);
			
			new playing=0;
			for(new player=1;player<=MaxClients;player++)
			{
				if(!IsValidClient(player))
					continue;
				if(GetClientTeam(player)!= FF2_GetBossTeam())
				{
					playing++;
				}
			}
			
			new health=ParseFormula(boss, NightmareHealth, GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, i), playing);
			if(health)
			{
				SetEntityHealth(i, health);
			}
				
			//Now set a timer for the Rage, because the rage should not last forever
			EndNightmareAt=GetEngineTime()+FF2_GetAbilityArgumentFloat(boss, this_plugin_name, NIGHTMARE, 1, 10.0);

			//Since it should confuse players, we need FriendlyFire aswell
			if(!GetConVarBool(FindConVar("mp_friendlyfire")))
			{
				SetConVarBool(FindConVar("mp_friendlyfire"), true);
			}
			SniperFF=true;
			
			if(NightmareVoice)
			{
				NoVoice[i]=true;
			}
			
			EndFFAt=GetEngineTime()+FF2_GetAbilityArgumentFloat(boss, this_plugin_name, NIGHTMARE, 2, 10.0);
				
			SDKHook(i, SDKHook_PreThink, Nightmare_Prethink);
		}
	}
}

public Nightmare_Prethink(client)
{
	NightmareTick(client, GetEngineTime());
}

public NightmareTick(client, Float:gTime)
{
	if(gTime >= EndFFAt)
	{
		if(GetConVarBool(FindConVar("mp_friendlyfire")))
		{
			SetConVarBool(FindConVar("mp_friendlyfire"), false);
			UnhookConVarChange(FindConVar("mp_friendlyfire"), HideCvarNotify);
		}
		SniperFF=false;
		EndFFAt=INACTIVE;
	}
	if(gTime >= EndNightmareAt)
	{
		for (new i=1;i<=MaxClients;i++)
		{
			if(IsValidLivingPlayer(i) && GetClientTeam(i)!=FF2_GetBossTeam())
			{
				SetVariantString("");
				AcceptEntityInput(i, "SetCustomModel");
				SetEntProp(i, Prop_Send, "m_bUseClassAnimations", 1);
				
				TF2_SetPlayerClass(i, LastClass[i]);
			
				TF2_RegeneratePlayer(i);
				
				NoVoice[i]=false;
			}
		}
		SDKUnhook(client, SDKHook_PreThink, Nightmare_Prethink);
		EndNightmareAt=INACTIVE;
	}
}

public HideCvarNotify(Handle:convar, const String:oldValue[], const String:newValue[])
{
    new flags = GetConVarFlags(convar);
    flags &= ~FCVAR_NOTIFY;
    SetConVarFlags(convar, flags);
}

public Action:OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	//Make sure that Friendlyfire is disabled
	EndFFAt=INACTIVE;
	EndNightmareAt=INACTIVE;
	if(SniperFF && GetConVarBool(FindConVar("mp_friendlyfire")))
	{
		SetConVarBool(FindConVar("mp_friendlyfire"), false);
		UnhookConVarChange(FindConVar("mp_friendlyfire"), HideCvarNotify);
	}
	
	if(SniperFF)
	{
		SniperFF=false;
	}
	
	for(new i=1;i<=MaxClients;i++)
	{
		if(IsValidClient(i))
		{
			LastClass[i]=TFClass_Unknown;
			SDKUnhook(i, SDKHook_PreThink, Nightmare_Prethink);
			Nightmare_TriggerAMS[i]=false;
		}
		if(NoVoice[i])
		{
			NoVoice[i]=false;
		}
	}
	
	return Plugin_Continue;
}

stock bool:IsValidLivingPlayer(client)
{
	if (client <= 0 || client > MaxClients)
		return false;
		
	return IsClientInGame(client) && IsPlayerAlive(client);
}

stock bool:IsValidClient(client)
{
	if (client <= 0 || client > MaxClients)
		return false;
		
	return IsClientInGame(client);
}

stock SpawnWeapon(client,String:name[],index,level,qual,String:att[], bool:isVisible=false)
{
	new Handle:hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	new String:atts[32][32];
	new count = ExplodeString(att, " ; ", atts, 32, 32);
	if (count > 0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		new i2 = 0;
		for (new i = 0; i < count; i+=2)
		{
			TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
			i2++;
		}
	}
	else
		TF2Items_SetNumAttributes(hWeapon, 0);
	if (hWeapon==INVALID_HANDLE)
		return -1;
	new entity = TF2Items_GiveNamedItem(client, hWeapon);
	CloseHandle(hWeapon);
	
	if(!isVisible)
	{
		SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
	}
	#if defined _FF2_Extras_included
	else
	{
		PrepareWeapon(entity);
	}
	#endif	
	
	EquipPlayerWeapon(client, entity);
	return entity;
}

public Action:SoundHook(clients[64], &numClients, String:vl[PLATFORM_MAX_PATH], &Ent, &channel, &Float:volume, &level, &pitch, &flags)
{
	new client = Ent;
	if(client <=  MAXPLAYERS && client > 0)
	{
		if(NoVoice[client]) // Block voice lines.
		{
			if (StrContains(vl, "vo/", false) == -1) 
				return Plugin_Stop;
			else if (!(StrContains(vl, "vo/", false) == -1)) // Just in case
				return Plugin_Stop;
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

/*
	Health Parser
 */
stock Operate(Handle:sumArray, &bracket, Float:value, Handle:_operator)
{
	new Float:sum=GetArrayCell(sumArray, bracket);
	switch(GetArrayCell(_operator, bracket))
	{
		case Operator_Add:
		{
			SetArrayCell(sumArray, bracket, sum+value);
		}
		case Operator_Subtract:
		{
			SetArrayCell(sumArray, bracket, sum-value);
		}
		case Operator_Multiply:
		{
			SetArrayCell(sumArray, bracket, sum*value);
		}
		case Operator_Divide:
		{
			if(!value)
			{
				LogError("[SHADoW93 Minions] Detected a divide by 0!");
				bracket=0;
				return;
			}
			SetArrayCell(sumArray, bracket, sum/value);
		}
		case Operator_Exponent:
		{
			SetArrayCell(sumArray, bracket, Pow(sum, value));
		}
		default:
		{
			SetArrayCell(sumArray, bracket, value);  //This means we're dealing with a constant
		}
	}
	SetArrayCell(_operator, bracket, Operator_None);
}

stock OperateString(Handle:sumArray, &bracket, String:value[], size, Handle:_operator)
{
	if(!StrEqual(value, ""))  //Make sure 'value' isn't blank
	{
		Operate(sumArray, bracket, StringToFloat(value), _operator);
		strcopy(value, size, "");
	}
}

public ParseFormula(boss, const String:key[], defaultValue, playing)
{
	decl String:formula[1024], String:bossName[64];
	FF2_GetBossSpecial(boss, bossName, sizeof(bossName));
	strcopy(formula, sizeof(formula), key);
	new size=1;
	new matchingBrackets;
	for(new i; i<=strlen(formula); i++)  //Resize the arrays once so we don't have to worry about it later on
	{
		if(formula[i]=='(')
		{
			if(!matchingBrackets)
			{
				size++;
			}
			else
			{
				matchingBrackets--;
			}
		}
		else if(formula[i]==')')
		{
			matchingBrackets++;
		}
	}

	new Handle:sumArray=CreateArray(_, size), Handle:_operator=CreateArray(_, size);
	new bracket;  //Each bracket denotes a separate sum (within parentheses).  At the end, they're all added together to achieve the actual sum
	SetArrayCell(sumArray, 0, 0.0);  //TODO:  See if these can be placed naturally in the loop
	SetArrayCell(_operator, bracket, Operator_None);

	new String:character[2], String:value[16];  //We don't decl value because we directly append characters to it and there's no point in decl'ing character
	for(new i; i<=strlen(formula); i++)
	{
		character[0]=formula[i];  //Find out what the next char in the formula is
		switch(character[0])
		{
			case ' ', '\t':  //Ignore whitespace
			{
				continue;
			}
			case '(':
			{
				bracket++;  //We've just entered a new parentheses so increment the bracket value
				SetArrayCell(sumArray, bracket, 0.0);
				SetArrayCell(_operator, bracket, Operator_None);
			}
			case ')':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
				if(GetArrayCell(_operator, bracket)!=Operator_None)  //Something like (5*)
				{
					LogError("[M7 Minions] %s's %s formula has an invalid operator at character %i", bossName, key, i+1);
					CloseHandle(sumArray);
					CloseHandle(_operator);
					return defaultValue;
				}

				if(--bracket<0)  //Something like (5))
				{
					LogError("[M7 Minions] %s's %s formula has an unbalanced parentheses at character %i", bossName, key, i+1);
					CloseHandle(sumArray);
					CloseHandle(_operator);
					return defaultValue;
				}

				Operate(sumArray, bracket, GetArrayCell(sumArray, bracket+1), _operator);
			}
			case '\0':  //End of formula
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
			}
			case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.':
			{
				StrCat(value, sizeof(value), character);  //Constant?  Just add it to the current value
			}
			case 'n', 'x':  //n and x denote player variables
			{
				Operate(sumArray, bracket, float(playing), _operator);
			}
			case '+', '-', '*', '/', '^':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
				switch(character[0])
				{
					case '+':
					{
						SetArrayCell(_operator, bracket, Operator_Add);
					}
					case '-':
					{
						SetArrayCell(_operator, bracket, Operator_Subtract);
					}
					case '*':
					{
						SetArrayCell(_operator, bracket, Operator_Multiply);
					}
					case '/':
					{
						SetArrayCell(_operator, bracket, Operator_Divide);
					}
					case '^':
					{
						SetArrayCell(_operator, bracket, Operator_Exponent);
					}
				}
			}
		}
	}

	new result=RoundFloat(GetArrayCell(sumArray, 0));
	CloseHandle(sumArray);
	CloseHandle(_operator);
	if(result<=0)
	{
		LogError("[Nightmare] %s has an invalid %s formula for minions, using default health!", bossName, key);
		return defaultValue;
	}
	return result;
}