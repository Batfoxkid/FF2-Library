/*
  "lives_sys"
  {
    "position"
    {
      "x" "-1.0"
      "y" "0.174"
      "pad" "0.03"
    }
    "color" "FFFFFFFF"
  }
*/
#include <sourcemod>
#include <sdktools>
#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

enum struct _Vector2D
{
	float x;
	float y;
}

enum struct _Color
{
	char r;
	char g;
	char b;
	char a;
}

enum struct _LivesSys {
	bool bEnabled;
	
	_Color color;
	_Vector2D pos;
	float pad;
	
	int num_bosses;
	FF2Player boss;
	
	void ParseFromConfig(FF2Player player)
	{
		float pos;
		/// X Position
		{
			if (!player.GetFloat("lives_sys.position.x", pos))
				pos = -1.0;
			this.pos.x = pos;
		}
		/// Y Position
		{
			if (!player.GetFloat("lives_sys.position.y", pos))
				pos = 0.174;
			this.pos.y = pos;
		}
		
		/// Y pad
		{
			if (!player.GetFloat("lives_sys.position.pad", pos))
				pos = 0.03;
			this.pad = pos;
		}
		
		/// RGBA color
		{
			char clr[8];
			player.GetString("lives_sys.color", clr, sizeof(clr));
			GetRGBA(clr, this.color);
		}
		
		this.boss = player;
	}
}

int iBossCount;
bool call_once;

_LivesSys live_sys[32];

FF2GameMode ff2_gm;

public Plugin myinfo = 
{
	name		= "[FF2] Multi lives system",
	author		= "01Pollux",
	version 	= "1.0",
};

public void OnLibraryAdded(const char[] name)
{
	if (!strcmp(name, "VSH2"))
	{
		VSH2_Hook(OnRoundStart, _OnRoundStart);
		VSH2_Hook(OnRoundEndInfo, _OnRoundEndInfo);
		VSH2_Hook(OnBossThink, _OnBossThink);
		VSH2_Hook(OnRedPlayerThink, _OnRedPlayerThink);
		
		if (ff2_gm.RoundState == StateRunning)
		{
			VSH2Player[] pl2 = new VSH2Player[MaxClients];
			int pl = FF2GameMode.GetBosses(pl2);
			_OnRoundStart(pl2, pl, pl2, 0);
		}
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (!strcmp(name, "VSH2"))
	{
		VSH2_Unhook(OnRoundStart, _OnRoundStart);
		VSH2_Unhook(OnRoundEndInfo, _OnRoundEndInfo);
		VSH2_Unhook(OnBossThink, _OnBossThink);
		VSH2_Unhook(OnRedPlayerThink, _OnRedPlayerThink);
	}
}


public void _OnRoundStart(const VSH2Player[] bosses, const int boss_count, const VSH2Player[] red_players, const int red_count)
{
	FF2Player player;
	for (int i = 0; i < boss_count && iBossCount < sizeof(live_sys); i++)
	{
		player = ToFF2Player(bosses[i]);
		if(player.GetPropInt("iMaxLives") <= 1)
			continue;
		
		live_sys[iBossCount].ParseFromConfig(player);
		iBossCount++;
	}
}

public void _OnRoundEndInfo(const VSH2Player player, bool bossBool, char message[MAXMESSAGE])
{
	if (iBossCount && player.GetPropInt("iMaxLives") > 1)
	{
		char name[MAX_BOSS_NAME_SIZE];
		player.GetName(name);
		
		FormatEx(message, sizeof(message), "%s (%N) had %i (of %i) health left, %i (of %i) lives left.", 
											name, 
											player.index, 
											player.GetPropInt("iHealth"), 
											player.GetPropInt("iMaxHealth"),
											player.GetPropInt("iLives"),
											player.GetPropInt("iMaxLives"));
		
		if (call_once) 
		{
			CreateTimer(0.2, Timer_ResetLiveSys);
			call_once = false;
		}
	}
}

public void _OnBossThink(const VSH2Player player)
{
	if (!iBossCount || ff2_gm.RoundState != StateRunning)
		return;
	
	DisplayLivesNum(player.index);
}

public void _OnRedPlayerThink(const VSH2Player player)
{
	if (!iBossCount || ff2_gm.RoundState != StateRunning)
		return;
	
	DisplayLivesNum(player.index);
}


public Action Timer_ResetLiveSys(Handle timer)
{
	iBossCount = 0;
	call_once = true;
}

void DisplayLivesNum(int client)
{
	_Color c;
	FF2Player curBoss;
	int curLives;
	
	float pos = 2.0;
	static char name[MAX_BOSS_NAME_SIZE]; 
	
	for (int i = 0; i < iBossCount; i++)
	{
		curBoss = live_sys[i].boss;
		if (!curBoss.index)
			continue;
			
		curLives = curBoss.GetPropInt("iLives");
		
		if(curLives <= 1) {
			continue;
		}
		
		c = live_sys[i].color;
		curBoss.GetName(name);
		
		if(pos == 2.0)
			pos = live_sys[i].pos.y;
		
		SetHudTextParams(live_sys[i].pos.x, pos, 0.15, c.r, c.g, c.b, c.a);
		ShowHudText(client, -1, "%s: (%i / %i) lives left", name, curLives, curBoss.GetPropInt("iMaxLives"));
		
		pos += live_sys[i].pad;
	}
}


void GetRGBA(const char[] str, any color[4])
{
    int extra_offset = str[0] == '0' && str[1] == 'x' ? 2:0;
    char c[5];	c[0] = '0'; c[1] = 'x';
    for (int i; i < 4; i++)
    {
        c[2] = str[extra_offset + i * 2] & 0xFF;
        c[3] = str[extra_offset + i * 2 + 1] & 0xFF;
        color[i] = StringToInt(c, 16);
    }
}