#pragma semicolon 1

#include <tf2items>
#include <tf2_stocks>
#include <freak_fortress_2>

#pragma newdecls required

#define this_plugin_name "ff2_client_musicmod"
#define ABILITY_INFO this_plugin_name, "special_changebgm_onclientmatch"

//	"steam ids"		"... ; ... ; ..."
//	"redirect"		"sound_bgm_..."

enum struct Music_Info_t 
{
	FF2Player player;
	char redirect[64];
}

methodmap MusicList < ArrayList {
	public MusicList()
	{
		return view_as<MusicList>(new ArrayList(ByteCountToCells(sizeof(Music_Info_t))));
	}
	
	public void InsertPlayer(const FF2Player player, const char[] redirect)
	{
		Music_Info_t infos;
		infos.player = player;
		strcopy(infos.redirect, sizeof(Music_Info_t::redirect), redirect);
		this.PushArray(infos, sizeof(Music_Info_t));
	}
	
	public void GetMusic(const int index, Music_Info_t infos)
	{
		this.GetArray(index, infos, sizeof(Music_Info_t));
	}
	
	public bool FindPlayer(const FF2Player player, Music_Info_t infos)
	{
		for(int i; i < this.Length; i++)
		{
			this.GetMusic(i, infos);
			if(player == infos.player)
				return true;
		}
		return false;
	}
}

MusicList music_list;

public Plugin myinfo = {
    name = "Freak Fortress 2: Boss Client Music Modifier",
    author = "Koishi (SHADoW NiNE TR3S), Remodified by 01Pollux",
    version = "1.0",
};

public void OnLibraryAdded(const char[] name)
{
	if(!strcmp(name, "VSH2")) {
		VSH2_Hook(OnRoundStart, _OnRoundStart);
		HookEvent("arena_win_panel", _OnRoundEnd);
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(!strcmp(name, "VSH2")) {
		VSH2_Unhook(OnRoundStart, _OnRoundStart);
		UnhookEvent("arena_win_panel", _OnRoundEnd);
	}
}

public void _OnRoundStart(const VSH2Player[] bosses, const int boss_count, const VSH2Player[] red_players, const int red_count)
{
	static char steamID[64], wantedIDs[1024];
	FF2Player player;
	for(int i; i < boss_count; i++)
	{
		player = ToFF2Player(bosses[i]);
		if(player.HasAbility(ABILITY_INFO))
		{
			if(!player.GetArgS(ABILITY_INFO, "steam ids", wantedIDs, sizeof(wantedIDs)))
				continue;
			
			if(!music_list) {
				music_list = new MusicList();
			}
			
			if(!GetClientAuthId(player.index, AuthId_Steam2, steamID, sizeof(steamID), true))
				continue;
			
			char[][] steamIDPool = new char[16][64];
			int count = ExplodeString(wantedIDs, " ; ", steamIDPool, 16, 64);
			for(int j; j < count; j++)
			{
				if(!strcmp(steamIDPool[j], steamID))
				{
					player.GetArgS(ABILITY_INFO, "redirect", wantedIDs, sizeof(wantedIDs));
					music_list.InsertPlayer(player, wantedIDs);
					break;
				}
			}
		}
	}
}

public void _OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	delete music_list;
}

public Action FF2_OnMusic(int boss_idx, char[] upcoming_song, float& time)
{
	if (!music_list)
		return Plugin_Continue;
	
	FF2Player player = FF2Player(boss_idx);
	static Music_Info_t infos;
	if (!music_list.FindPlayer(player, infos))
		return Plugin_Continue;
	
	StringMap map = player.SoundMap;
	ConfigMap sound_list;
	if (map && map.GetValue(infos.redirect, sound_list) && sound_list)
	{
		int size = sound_list.Size;
		if (size)
		{
			int pos = GetRandomInt(0, size - 1);
			ConfigMap rand_sec = sound_list.GetIntSection(pos);

			rand_sec.Get("path", upcoming_song, PLATFORM_MAX_PATH);
			rand_sec.GetFloat("time", time);

			char artist[32], song_name[64];
			if (!rand_sec.Get("name", song_name, sizeof(song_name)))
				song_name = "Unknown song";
			if (!rand_sec.Get("artist", song_name, sizeof(song_name)))
				song_name = "Unknown artist";

			FPrintToChatAll(
				"Now Playing: {blue}%s{default} - {orange}%s{default}", 
				song_name, 
				artist
			);

			FF2Player.ReleaseSoundMap(map);
			return Plugin_Handled;
		}
	}

	FF2Player.ReleaseSoundMap(map);
	return Plugin_Continue;
}
