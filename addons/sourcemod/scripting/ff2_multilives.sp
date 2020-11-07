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

enum struct Vector2D
{
	float x;
	float y;
}

enum struct _LivesSys {
	bool bEnabled;
	
	int color[4];
	Vector2D pos;
	float pad;
	
	int num_bosses;
	FF2Player boss;
	
	void ParseFromConfig(FF2Player player)
	{
		float pos;
		/// X Position
		{
			if( !player.GetFloat("lives_sys.position.x", pos) )
				pos = -1.0;
			this.pos.x = pos;
		}
		/// Y Position
		{
			if( !player.GetFloat("lives_sys.position.y", pos) )
				pos = 0.174;
			this.pos.y = pos;
		}
		
		/// Y pad
		{
			if( !player.GetFloat("lives_sys.position.pad", pos) )
				pos = 0.03;
			this.pad = pos;
		}
		
		/// RGBA color
		{
			char clr[8];
			GetRGBA(player.GetString("lives_sys.color", clr, sizeof(clr)) ? StringToInt(clr, 16) : 0xFFFFFFFF,
					this.color);
		}
		
		this.boss = player;
	}
}

int iBossCount;

_LivesSys live_sys[3];

FF2GameMode ff2_gm;


public Plugin myinfo = 
{
	name		= "[FF2] Multi lives system",
	author		= "01Pollux",
	version 	= "1.0",
};

public void OnLibraryAdded(const char[] name)
{
	if(!strcmp(name, "VSH2")) {
		VSH2_Hook(OnRoundStart, _OnRoundStart);
		VSH2_Hook(OnRoundEndInfo, _OnRoundEndInfo);
		VSH2_Hook(OnBossThink, _OnBossThink);
		VSH2_Hook(OnRedPlayerThink, _OnRedPlayerThink);
		
		if(ff2_gm.RoundState == StateRunning) {
			VSH2Player[] pl2 = new VSH2Player[MaxClients];
			int pl = FF2GameMode.GetBosses(pl2);
			_OnRoundStart(pl2, pl, pl2, 0);
		}
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(!strcmp(name, "VSH2")) {
		VSH2_Unhook(OnRoundStart, _OnRoundStart);
		VSH2_Unhook(OnRoundEndInfo, _OnRoundEndInfo);
		VSH2_Unhook(OnBossThink, _OnBossThink);
		VSH2_Unhook(OnRedPlayerThink, _OnRedPlayerThink);
	}
}


public void _OnRoundStart(const VSH2Player[] bosses, const int boss_count, const VSH2Player[] red_players, const int red_count)
{
	VSH2Player player;
	for(int i = 0; i < boss_count && iBossCount < 3; i++) {
		player = bosses[i];
		if(player.GetPropInt("iMaxLives") <= 1)
			continue;
		
		live_sys[iBossCount].ParseFromConfig(ToFF2Player(player));
		iBossCount++;
	}
}

public void _OnRoundEndInfo(const VSH2Player player, bool bossBool, char message[MAXMESSAGE])
{
	if(iBossCount && player.GetPropInt("iMaxLives") > 1)
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
		
		if(iBossCount) 
		{
			CreateTimer(0.2, Timer_ResetLiveSys);
		}
	}
}

public void _OnBossThink(const VSH2Player player)
{
	if(!iBossCount || ff2_gm.RoundState != StateRunning)
		return;
	
	DisplayLivesNum(player.index);
}

public void _OnRedPlayerThink(const VSH2Player player)
{
	if(!iBossCount || ff2_gm.RoundState != StateRunning)
		return;
	
	DisplayLivesNum(player.index);
}


public Action Timer_ResetLiveSys(Handle timer)
{
	iBossCount = 0;
}

void DisplayLivesNum(int client)
{
	static int c[4]; 
	FF2Player curBoss; int curLives;
	
	static char name[MAX_BOSS_NAME_SIZE]; 
	float pos = 2.0;
	
	for(int i = 0; i < iBossCount; i++)
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
		
		SetHudTextParams(live_sys[i].pos.x, pos, 0.15, c[0], c[1], c[2], c[3]);
		ShowHudText(client, -1, "%s: (%i / %i) lives left", name, curLives, curBoss.GetPropInt("iMaxLives"));
		
		pos += live_sys[i].pad;
	}
}


void GetRGBA(const int hex, int color[4])
{
	for(int i; i < 4; i++)
		color[i] = (hex >> 0x8 * i) & 0xFF;
}
