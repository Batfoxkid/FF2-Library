#if defined _FF2_Ability_Parser
 #endinput
#endif
#define _FF2_Ability_Parser

enum ParseState {
	Parse_Inactive,
	Parse_Active,
	Parse_Finished
};

enum struct FF2Template {
	StringMap map;
	SMCParser parser;
	ArrayStack last;
	char section[PLATFORM_MAX_PATH];
	char target[32];
	ParseState state;
	int level;
}

static FF2Template FF2Ability;
methodmap FF2Parse < StringMap {
	public FF2Parse(const char[] bosspath, const char[] target) {
		
		FormatEx(FF2Ability.target, sizeof(FF2Ability.target), target);
		
		FF2Ability.parser = new SMCParser();
		FF2Ability.parser.OnStart = SMC_OnStart;
		FF2Ability.parser.OnEnterSection = SMC_OnEnterSection;
		FF2Ability.parser.OnKeyValue = SMC_OnKeyValue;
		FF2Ability.parser.OnLeaveSection = SMC_OnLeaveSection;
		
		SMCError SMCErr = FF2Ability.parser.ParseFile(bosspath);
		if(SMCErr != SMCError_Okay) {
			char error[64];
			FF2Ability.parser.GetErrorString(SMCErr, error, sizeof(error));
			LogError("[FF2Parser] '%s' Error : %s", bosspath, error);
			delete FF2Ability.map;
		}
		
		delete FF2Ability.last;
		delete FF2Ability.parser;
		
		if(FF2Ability.state == Parse_Inactive) {
			delete FF2Ability.map;
			FF2Ability.map = null;
			LogError("[FF2Parser] Invalid path (%s) / target key (%s) used", bosspath, target);
		}
		
		return view_as<FF2Parse>(FF2Ability.map);
	}
	
	public int Get(const char[] key, char[] buffer, int maxlen) {
		if(this == null) {
			return 0;
		}
		char[] result = new char[maxlen];
		if(!this.GetString(key, buffer, maxlen)) {
			return 0;
		}
		
		return strcopy(buffer, maxlen, result);
	}
	
	public float GetFloat(const char[] key, float def = 0.0) {
		char[] key_buffer = new char[16];
		if(!this.GetString(key, key_buffer, 16)) {
			return def;
		}
		
		return StringToFloat(key_buffer);
	}
	
	public int GetInt(const char[] key, int def = 0) {
		char[] key_buffer = new char[16];
		if(!this.GetString(key, key_buffer, 16)) {
			return def;
		}
		
		return StringToInt(key_buffer);
	}
	
	public int GetButton(const char[] key, int def = IN_RELOAD) {
		char[] key_buffer = new char[16];
		if(!this.GetString(key, key_buffer, 16)) {
			return def;
		}
		
		if(!strcmp(key_buffer, "reload")) {
			return IN_RELOAD;
		}
		else if(!strcmp(key_buffer, "mouse3")) {
			return IN_ATTACK3;
		}
		else if(!strcmp(key_buffer, "mouse2")) {
			return IN_ATTACK2;
		}
		
		return def;
	}
	
	public int GetBool(const char[] key, bool def = false) {
		char[] key_buffer = new char[6];
		if(!this.GetString(key, key_buffer, 6)) {
			return def;
		}
		
		return !strcmp(key_buffer, "true");
	}
}

public void SMC_OnStart(SMCParser smc)
{
	FF2Ability.map = new StringMap();
	FF2Ability.last = new ArrayStack(PLATFORM_MAX_PATH);
	FF2Ability.state = Parse_Inactive;
	FF2Ability.level = 0;
}
public SMCResult SMC_OnEnterSection(SMCParser smc, const char[] name, bool opt_quotes)
{
	switch(FF2Ability.state) {
		case Parse_Finished: {
			return SMCParse_Halt;
		}
		
		case Parse_Inactive: {
			if(!strcmp(name, FF2Ability.target)) {
				FF2Ability.state = Parse_Active;
			}
			return SMCParse_Continue;
		}
		
		case Parse_Active: {
			if(!FF2Ability.level) {
				FormatEx(FF2Ability.section, sizeof(FF2Ability.section), name);
			} else {
				Format(FF2Ability.section, sizeof(FF2Ability.section), "%s->%s", FF2Ability.section, name);
			}
			FF2Ability.last.PushString(name);
			FF2Ability.level++;
			return SMCParse_Continue;
		}
	}
	return SMCParse_Continue;
}

public SMCResult SMC_OnKeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	switch(FF2Ability.state) {
		case Parse_Active: {
			static char section[PLATFORM_MAX_PATH];
			
			if(!FF2Ability.level) {
				FF2Ability.map.SetString(key, value);
			} else {
				FormatEx(section, sizeof(section), "%s->%s", FF2Ability.section, key);
				FF2Ability.map.SetString(section, value);
			}
		}
		default: {
		}
	}
	return SMCParse_Continue;
}

public SMCResult SMC_OnLeaveSection(SMCParser smc)
{
	switch(FF2Ability.state) {
		case Parse_Active: {
			if(--FF2Ability.level >= 0) {
				char[] last = new char[PLATFORM_MAX_PATH];
				int size;
				FF2Ability.last.PopString(last, PLATFORM_MAX_PATH, size);
				RemoveLastString(FF2Ability.section, sizeof(FF2Ability.section), size);
			} else {
				FF2Ability.state = Parse_Finished;
			}
		}
	}
	return SMCParse_Continue;
}

static void RemoveLastString(char[] src, int maxlen, int len)
{
	if(len <= 0) {
		return;
	}
	int pos;
	while(pos < maxlen) {
		if(src[++pos]=='\0')
			break;
	}
	int nul = pos - len - 2;
	if(nul < 0) {
		nul = 0;
	}
	src[nul] = '\0';
}
