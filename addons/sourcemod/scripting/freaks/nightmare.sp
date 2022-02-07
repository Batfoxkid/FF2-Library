#define FF2_USING_AUTO_PLUGIN__OLD

#include <sdkhooks>
#include <tf2_stocks>
#include <ff2_ams2>
#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
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
float EndNightmareAt;
float EndFFAt;
bool SniperFF=false; // We use this in case FF is set from RAGE, and not from round events like end-of-round friendly fire
bool NoVoice[MAXPLAYERS+1]=false; // Block voices while RAGE is active
TFClassType LastClass[MAXPLAYERS+1];
char NightmareModel[PLATFORM_MAX_PATH], NightmareClassname[64], NightmareAttributes[124];
int NightmareIndex, NightmareClass;
bool NightmareVoice;
bool Nightmare_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS

public void OnPluginStart2()
{
	HookEvent("arena_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);
	AddNormalSoundHook(SoundHook);
}

public void FF2AMS_PreRoundStart(int client)
{
	int boss = FF2_GetBossIndex(client);
	if(FF2_HasAbility(boss, this_plugin_name, NIGHTMARE))
	{
		Nightmare_TriggerAMS[client] = FF2AMS_PushToAMS(client, this_plugin_name, NIGHTMARE, "NIGH");
	}
}

public Action FF2_OnAbility2(int index, const char[] plugin_name, const char[] ability_name, int status)
{
    //Make sure that RAGE is only allowed to be used when a FF2 round is active
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue;

	int client=GetClientOfUserId(FF2_GetBossUserId(index));
	if(!strcmp(ability_name,NIGHTMARE))	// Defenses
	{
		if(!LibraryExists("FF2AMS")) // Fail state?
		{
			Nightmare_TriggerAMS[client]=false;
		}

		if(!Nightmare_TriggerAMS[client])
			NIGH_Invoke(client, -1);
	}
	return Plugin_Continue;
}

public AMSResult NIGH_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void NIGH_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);

	char NightmareHealth[768];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, NIGHTMARE, 3, NightmareModel, sizeof(NightmareModel)); // Model that the players gets
	NightmareClass=FF2_GetAbilityArgument(boss, this_plugin_name, NIGHTMARE, 4); // class name
	FF2_GetAbilityArgumentString(boss, this_plugin_name, NIGHTMARE, 5, NightmareClassname, sizeof(NightmareClassname));
	NightmareIndex=FF2_GetAbilityArgument(boss, this_plugin_name, NIGHTMARE, 6);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, NIGHTMARE, 7, NightmareAttributes, sizeof(NightmareAttributes));
	NightmareVoice=FF2_GetAbilityArgument(boss, this_plugin_name, NIGHTMARE, 8) != 0;
	FF2_GetAbilityArgumentString(boss, this_plugin_name, NIGHTMARE, 9, NightmareHealth, sizeof(NightmareHealth));

	if(Nightmare_TriggerAMS[client])
	{
		char sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_nightmare_rage", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);
		}
	}

	FindConVar("mp_friendlyfire").AddChangeHook(HideCvarNotify);

	// And now proceed to rage
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidLivingPlayer(i) && GetClientTeam(i)!=FF2_GetBossTeam())
		{
			//First, Remove all weapons
			TF2_RemoveAllWeapons(i);

			//Then set the class to whatever class you want and give them a custom weapon (it should be the bosses weapon and class, otherwise it would kinda destroy the purpose of this RAGE)
			LastClass[i]=TF2_GetPlayerClass(i);
			if(TF2_GetPlayerClass(i)!=view_as<TFClassType>(NightmareClass))
			{
				TF2_SetPlayerClass(i, view_as<TFClassType>(NightmareClass));
			}

			SpawnWeapon(i, NightmareClassname, NightmareIndex, 5, 8, NightmareAttributes);

			//Then Remove all Wearables
			int entity, owner;
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

			int playing=0;
			for(int player=1;player<=MaxClients;player++)
			{
				if(!IsValidClient(player))
					continue;
				if(GetClientTeam(player)!= FF2_GetBossTeam())
				{
					playing++;
				}
			}

			int health=RoundToCeil(ParseFormula(NightmareHealth, playing));
			if(health)
			{
				SetEntityHealth(i, health);
			}

			//Now set a timer for the Rage, because the rage should not last forever
			EndNightmareAt=GetGameTime()+FF2_GetAbilityArgumentFloat(boss, this_plugin_name, NIGHTMARE, 1, 10.0);

			//Since it should confuse players, we need FriendlyFire aswell
			if(!FindConVar("mp_friendlyfire").BoolValue)
			{
				FindConVar("mp_friendlyfire").BoolValue = true;
			}
			SniperFF=true;

			if(NightmareVoice)
			{
				NoVoice[i]=true;
			}

			EndFFAt=GetGameTime()+FF2_GetAbilityArgumentFloat(boss, this_plugin_name, NIGHTMARE, 2, 10.0);

			SDKHook(i, SDKHook_PreThink, Nightmare_Prethink);
		}
	}
}

public void Nightmare_Prethink(int client)
{
	NightmareTick(client, GetGameTime());
}

public void NightmareTick(int client, float gTime)
{
	if(gTime >= EndFFAt)
	{
		if(FindConVar("mp_friendlyfire").BoolValue)
		{
			FindConVar("mp_friendlyfire").BoolValue = false;
			FindConVar("mp_friendlyfire").RemoveChangeHook(HideCvarNotify);
		}
		SniperFF=false;
		EndFFAt=INACTIVE;
	}
	if(gTime >= EndNightmareAt)
	{
		for (int i=1;i<=MaxClients;i++)
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

public void HideCvarNotify(ConVar convar, const char[] oldValue, const char[] newValue)
{
    int flags = convar.Flags;
    flags &= ~FCVAR_NOTIFY;
    convar.Flags = flags;
}

public Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	//Make sure that Friendlyfire is disabled
	EndFFAt=INACTIVE;
	EndNightmareAt=INACTIVE;
	if(SniperFF && FindConVar("mp_friendlyfire").BoolValue)
	{
		FindConVar("mp_friendlyfire").BoolValue = false;
		FindConVar("mp_friendlyfire").RemoveChangeHook(HideCvarNotify);
	}

	if(SniperFF)
	{
		SniperFF=false;
	}

	for(int i=1;i<=MaxClients;i++)
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

stock bool IsValidLivingPlayer(int client)
{
	if (client <= 0 || client > MaxClients)
		return false;

	return IsClientInGame(client) && IsPlayerAlive(client);
}

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients)
		return false;

	return IsClientInGame(client);
}

stock int SpawnWeapon(int client, char[] name, int index, int level, int qual, char[] att, bool isVisible=false)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	char atts[32][32];
	int count = ExplodeString(att, " ; ", atts, 32, 32);
	if (count > 0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		int i2 = 0;
		for (int i = 0; i < count; i+=2)
		{
			TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
			i2++;
		}
	}
	else
		TF2Items_SetNumAttributes(hWeapon, 0);
	if (hWeapon==INVALID_HANDLE)
		return -1;
	int entity = TF2Items_GiveNamedItem(client, hWeapon);
	delete hWeapon;

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

public Action SoundHook(int clients[MAXPLAYERS], int& numClients, char vl[PLATFORM_MAX_PATH],
				  int& client, int& channel, float& volume, int& level, int& pitch, int& flags,
				  char soundEntry[PLATFORM_MAX_PATH], int& seed)
{
	if(client <=  MaxClients && client > 0)
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


/**
 * Remade FF2 formula parser by Nergal.
 */

enum {
	TokenInvalid,
	TokenNum,
	TokenLParen, TokenRParen,
	TokenLBrack, TokenRBrack,
	TokenPlus, TokenSub,
	TokenMul, TokenDiv,
	TokenPow,
	TokenVar
};

enum {
	LEXEME_SIZE=64,
	dot_flag = 1,
};

enum struct Token {
	char lexeme[LEXEME_SIZE];
	int size;
	int tag;
	float val;
}

enum struct LexState {
	Token tok;
	int i;
}

float ParseFormula(const char[] formula, const int players)
{
	LexState ls;
	GetToken(ls, formula);
	return ParseAddExpr(ls, formula, players + 0.0);
}

float ParseAddExpr(LexState ls, const char[] formula, const float n)
{
	float val = ParseMulExpr(ls, formula, n);
	if( ls.tok.tag==TokenPlus ) {
		GetToken(ls, formula);
		float a = ParseAddExpr(ls, formula, n);
		return val + a;
	} else if( ls.tok.tag==TokenSub ) {
		GetToken(ls, formula);
		float a = ParseAddExpr(ls, formula, n);
		return val - a;
	}
	return val;
}

float ParseMulExpr(LexState ls, const char[] formula, const float n)
{
	float val = ParsePowExpr(ls, formula, n);
	if( ls.tok.tag==TokenMul ) {
		GetToken(ls, formula);
		float m = ParseMulExpr(ls, formula, n);
		return val * m;
	} else if( ls.tok.tag==TokenDiv ) {
		GetToken(ls, formula);
		float m = ParseMulExpr(ls, formula, n);
		return val / m;
	}
	return val;
}

float ParsePowExpr(LexState ls, const char[] formula, const float n)
{
	float val = ParseFactor(ls, formula, n);
	if( ls.tok.tag==TokenPow ) {
		GetToken(ls, formula);
		float e = ParsePowExpr(ls, formula, n);
		float p = Pow(val, e);
		return p;
	}
	return val;
}

float ParseFactor(LexState ls, const char[] formula, const float n)
{
	switch( ls.tok.tag ) {
		case TokenNum: {
			float f = ls.tok.val;
			GetToken(ls, formula);
			return f;
		}
		case TokenVar: {
			GetToken(ls, formula);
			return n;
		}
		case TokenLParen: {
			GetToken(ls, formula);
			float f = ParseAddExpr(ls, formula, n);
			if( ls.tok.tag != TokenRParen ) {
				LogError("VSH2/FF2 :: expected ')' bracket but got '%s'", ls.tok.lexeme);
				return 0.0;
			}
			GetToken(ls, formula);
			return f;
		}
		case TokenLBrack: {
			GetToken(ls, formula);
			float f = ParseAddExpr(ls, formula, n);
			if( ls.tok.tag != TokenRBrack ) {
				LogError("VSH2/FF2 :: expected ']' bracket but got '%s'", ls.tok.lexeme);
				return 0.0;
			}
			GetToken(ls, formula);
			return f;
		}
	}
	return 0.0;
}

bool LexOctal(LexState ls, const char[] formula)
{
	int lit_flags = 0;
	while( formula[ls.i] != 0 && (IsCharNumeric(formula[ls.i])) ) {
		switch( formula[ls.i] ) {
			case '0', '1', '2', '3', '4', '5', '6', '7': {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
			}
			default: {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
				LogError("VSH2/FF2 :: invalid octal literal: '%s'", ls.tok.lexeme);
				return false;
			}
		}
	}
	return true;
#pragma unused lit_flags		//REMOVEME
}

bool LexHex(LexState ls, const char[] formula)
{
	while( formula[ls.i] != 0 && (IsCharNumeric(formula[ls.i]) || IsCharAlpha(formula[ls.i])) ) {
		switch( formula[ls.i] ) {
			case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
				'a', 'b', 'c', 'd', 'e', 'f',
				'A', 'B', 'C', 'D', 'E', 'F': {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
			}
			default: {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
				LogError("VSH2/FF2 :: invalid hex literal: '%s'", ls.tok.lexeme);
				return false;
			}
		}
	}
	return true;
}

bool LexDec(LexState ls, const char[] formula)
{
	int lit_flags = 0;
	while( formula[ls.i] != 0 && (IsCharNumeric(formula[ls.i]) || formula[ls.i]=='.') ) {
		switch( formula[ls.i] ) {
			case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9': {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
			}
			case '.': {
				if( lit_flags & dot_flag ) {
					LogError("VSH2/FF2 :: extra dot in decimal literal");
					return false;
				}
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
				lit_flags |= dot_flag;
			}
			default: {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
				LogError("VSH2/FF2 :: invalid decimal literal: '%s'", ls.tok.lexeme);
				return false;
			}
		}
	}
	return true;
}

void GetToken(LexState ls, const char[] formula)
{
	int len = strlen(formula);
	Token empty;
	ls.tok = empty;
	while( ls.i<len ) {
		switch( formula[ls.i] ) {
			case ' ', '\t', '\n': {
				ls.i++;
			}
			case '0': { /// possible hex, octal, binary, or float.
				ls.tok.tag = TokenNum;
				ls.i++;
				switch( formula[ls.i] ) {
					case 'o', 'O': {
						/// Octal.
						ls.i++;
						if( LexOctal(ls, formula) ) {
							ls.tok.val = StringToInt(ls.tok.lexeme, 8) + 0.0;
						}
						return;
					}
					case 'x', 'X': {
						/// Hex.
						ls.i++;
						if( LexHex(ls, formula) ) {
							ls.tok.val = StringToInt(ls.tok.lexeme, 16) + 0.0;
						}
						return;
					}
					case '.', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9': {
						/// Decimal/Float.
						if( LexDec(ls, formula) ) {
							ls.tok.val = StringToFloat(ls.tok.lexeme);
						}
						return;
					}
				}
			}
			case '.', '1', '2', '3', '4', '5', '6', '7', '8', '9': {
				ls.tok.tag = TokenNum;
				/// Decimal/Float.
				if( LexDec(ls, formula) ) {
					ls.tok.val = StringToFloat(ls.tok.lexeme);
				}
				return;
			}
			case '(': {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
				ls.tok.tag = TokenLParen;
				return;
			}
			case ')': {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
				ls.tok.tag = TokenRParen;
				return;
			}
			case '[': {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
				ls.tok.tag = TokenLBrack;
				return;
			}
			case ']': {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
				ls.tok.tag = TokenRBrack;
				return;
			}
			case '+': {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
				ls.tok.tag = TokenPlus;
				return;
			}
			case '-': {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
				ls.tok.tag = TokenSub;
				return;
			}
			case '*': {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
				ls.tok.tag = TokenMul;
				return;
			}
			case '/': {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
				ls.tok.tag = TokenDiv;
				return;
			}
			case '^': {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
				ls.tok.tag = TokenPow;
				return;
			}
			case 'x', 'n', 'X', 'N': {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
				ls.tok.tag = TokenVar;
				return;
			}
			default: {
				ls.tok.lexeme[ls.tok.size++] = formula[ls.i++];
				LogError("VSH2/FF2 :: invalid formula token '%s'.", ls.tok.lexeme);
				return;
			}
		}
	}
}
