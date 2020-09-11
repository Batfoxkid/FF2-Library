#define BOSS_GRAY
/*
		"name"		"rage_gray_summon"

		"arg0"		"-1"
		"arg1"		"0"					// If amount is ratio of alive players
		"arg2"		"6"					// Amount/ratio to summon
		"arg3"		"models/bots/scout/bot_scout.mdl"	// Player model
		"arg4"		"1"					// Player class
		"arg5"		"1"					// Robot type
		// 1: Minion
		// 2: Engineer
		// 3: Spy
		// 4: Big Bot
		// 5: Boss Bot
		// 6: Sentry Buster

		"arg6"		"125" 		// Player health
		"arg7"		"25.0"		// Chance to wield a bomb
		"arg8"		"Bat Scout"	// Boss name (For Boss Bot)
		"arg9"		"1"		// Cash to drop on death
		"arg10"		"0"		// If crit boosted

		"arg11"		"tf_weapon_bat"		// Weapon Classname
		"arg12"		"0"			// Weapon Index
		"arg13"		"15 ; 0"		// Weapon Attributes
		"arg14"		""			// Weapon Ammo
		"arg15"		""			// Weapon Clip
		"arg16"		""			// Weapon Model

		"arg101"	"0"					// If amount is ratio of alive players
		"arg102"	"5"					// Amount/ratio to summon
		"arg103"	"models/bots/scout/bot_scout.mdl"	// Player model
		"arg104"	"1"					// Player class
		"arg105"	"1"					// Robot type
		// 1: Minion
		// 2: Engineer
		// 3: Spy
		// 4: Big Bot
		// 5: Boss Bot
		// 6: Sentry Buster

		"arg106"	"125" 	// Player health
		"arg107"	"20.0"	// Chance to wield a bomb
		"arg108"	"Scout"	// Boss name (For Boss Bot)
		"arg109"	"1"	// Cash to drop on death
		"arg110"	"0"	// If crit boosted

		"arg111"	"tf_weapon_scattergun"	// Weapon Classname
		"arg112"	"13"			// Weapon Index
		"arg113"	"15 ; 0"		// Weapon Attributes
		"arg114"	"99999"			// Weapon Ammo
		"arg115"	"6"			// Weapon Clip
		"arg116"	""			// Weapon Model

		"arg201"	"0"					// If amount is ratio of alive players
		"arg202"	"5"					// Amount/ratio to summon
		"arg203"	"models/bots/soldier/bot_soldier.mdl"	// Player model
		"arg204"	"3"					// Player class
		"arg205"	"1"					// Robot type
		// 1: Minion
		// 2: Engineer
		// 3: Spy
		// 4: Big Bot
		// 5: Boss Bot
		// 6: Sentry Buster

		"arg206"	"200" 		// Player health
		"arg207"	"20.0"		// Chance to wield a bomb
		"arg208"	"Soldier"	// Boss name (For Boss Bot)
		"arg209"	"1"		// Cash to drop on death
		"arg210"	"0"		// If crit boosted

		"arg211"	"tf_weapon_rocketlauncher"	// Weapon Classname
		"arg212"	"18"				// Weapon Index
		"arg213"	"15 ; 0 ; 413 ; 1"		// Weapon Attributes
		"arg214"	"99999"				// Weapon Ammo
		"arg215"	"0"				// Weapon Clip
		"arg216"	""				// Weapon Model

		"arg301"	"0"					// If amount is ratio of alive players
		"arg302"	"5"					// Amount/ratio to summon
		"arg303"	"models/bots/pyro/bot_pyro.mdl"	// Player model
		"arg304"	"7"					// Player class
		"arg305"	"1"					// Robot type
		// 1: Minion
		// 2: Engineer
		// 3: Spy
		// 4: Big Bot
		// 5: Boss Bot
		// 6: Sentry Buster

		"arg306"	"175" 	// Player health
		"arg307"	"20.0"	// Chance to wield a bomb
		"arg308"	"Pyro"	// Boss name (For Boss Bot)
		"arg309"	"1"	// Cash to drop on death
		"arg310"	"0"	// If crit boosted

		"arg311"	"tf_weapon_flamethrower"										// Weapon Classname
		"arg312"	"21"													// Weapon Index
		"arg313"	"15 ; 0 ; 839 ; 2.8 ; 841 ; 0 ; 843 ; 8.5 ; 844 ; 2300 ; 862 ; 0.6 ; 863 ; 0.1 ; 865 ; 50 ; 783 ; 20"	// Weapon Attributes
		"arg314"	"99999"													// Weapon Ammo
		"arg315"	""													// Weapon Clip
		"arg316"	""													// Weapon Model

		"arg401"	"0"				// If amount is ratio of alive players
		"arg402"	"5"				// Amount/ratio to summon
		"arg403"	"models/bots/demo/bot_demo.mdl"	// Player model
		"arg404"	"4"				// Player class
		"arg405"	"1"				// Robot type
		// 1: Minion
		// 2: Engineer
		// 3: Spy
		// 4: Big Bot
		// 5: Boss Bot
		// 6: Sentry Buster

		"arg406"	"175" 		// Player health
		"arg407"	"15.0"		// Chance to wield a bomb
		"arg408"	"Demoman"	// Boss name (For Boss Bot)
		"arg409"	"1"		// Cash to drop on death
		"arg410"	"0"		// If crit boosted

		"arg411"	"tf_weapon_grenadelauncher"	// Weapon Classname
		"arg412"	"19"				// Weapon Index
		"arg413"	"15 ; 0 ; 413 ; 1"		// Weapon Attributes
		"arg414"	"99999"				// Weapon Ammo
		"arg415"	"0"				// Weapon Clip
		"arg416"	""				// Weapon Model

		"arg501"	"0"				// If amount is ratio of alive players
		"arg502"	"5"				// Amount/ratio to summon
		"arg503"	"models/bots/demo/bot_demo.mdl"	// Player model
		"arg504"	"4"				// Player class
		"arg505"	"1"				// Robot type
		// 1: Minion
		// 2: Engineer
		// 3: Spy
		// 4: Big Bot
		// 5: Boss Bot
		// 6: Sentry Buster

		"arg506"	"200" 		// Player health
		"arg507"	"15.0"		// Chance to wield a bomb
		"arg508"	"Demoknight"	// Boss name (For Boss Bot)
		"arg509"	"1"		// Cash to drop on death
		"arg510"	"0"		// If crit boosted

		"arg511"	"tf_weapon_sword"		// Weapon Classname
		"arg512"	"132"				// Weapon Index
		"arg513"	"15 ; 0 ; 31 ; 3 ; 781 ; 1"	// Weapon Attributes
		"arg514"	""				// Weapon Ammo
		"arg515"	""				// Weapon Clip
		"arg516"	""				// Weapon Model

		"arg521"	"tf_wearable_demoshield"			// Weapon Classname
		"arg522"	"131"						// Weapon Index
		"arg523"	"60 ; 0.5 ; 64 ; 0.7 ; 107 ; 1.1"		// Weapon Attributes
		"arg524"	""						// Weapon Ammo
		"arg525"	""						// Weapon Clip
		"arg526"	"models/weapons/c_models/c_targe/c_targe.mdl"	// Weapon Model

		"arg601"	"0"					// If amount is ratio of alive players
		"arg602"	"4"					// Amount/ratio to summon
		"arg603"	"models/bots/heavy/bot_heavy.mdl"	// Player model
		"arg604"	"6"					// Player class
		"arg605"	"1"					// Robot type
		// 1: Minion
		// 2: Engineer
		// 3: Spy
		// 4: Big Bot
		// 5: Boss Bot
		// 6: Sentry Buster

		"arg606"	"300" 	// Player health
		"arg607"	"15.0"	// Chance to wield a bomb
		"arg608"	"Heavy"	// Boss name (For Boss Bot)
		"arg609"	"1"	// Cash to drop on death
		"arg610"	"0"	// If crit boosted

		"arg611"	"tf_weapon_minigun"	// Weapon Classname
		"arg612"	"15"			// Weapon Index
		"arg613"	"1 ; 0.8 ; 15 ; 0"	// Weapon Attributes
		"arg614"	"99999"			// Weapon Ammo
		"arg615"	""			// Weapon Clip
		"arg616"	""			// Weapon Model

		"arg701"	"0"					// If amount is ratio of alive players
		"arg702"	"3"					// Amount/ratio to summon
		"arg703"	"models/bots/medic/bot_medic.mdl"	// Player model
		"arg704"	"5"					// Player class
		"arg705"	"1"					// Robot type
		// 1: Minion
		// 2: Engineer
		// 3: Spy
		// 4: Big Bot
		// 5: Boss Bot
		// 6: Sentry Buster

		"arg706"	"150" 	// Player health
		"arg707"	"5.0"	// Chance to wield a bomb
		"arg708"	"Medic"	// Boss name (For Boss Bot)
		"arg709"	"1"	// Cash to drop on death
		"arg710"	"0"	// If crit boosted

		"arg711"	"tf_weapon_syringegun_medic"	// Weapon Classname
		"arg712"	"17"				// Weapon Index
		"arg713"	"15 ; 0"			// Weapon Attributes
		"arg714"	"99999"				// Weapon Ammo
		"arg715"	"40"				// Weapon Clip
		"arg716"	""				// Weapon Model

		"arg721"	"tf_weapon_medigun"	// Weapon Classname
		"arg722"	"29"			// Weapon Index
		"arg723"	"10 ; 2 ; 105 ; 0"	// Weapon Attributes
		"arg724"	""			// Weapon Ammo
		"arg725"	""			// Weapon Clip
		"arg726"	""			// Weapon Model

		"arg801"	"0"					// If amount is ratio of alive players
		"arg802"	"5"					// Amount/ratio to summon
		"arg803"	"models/bots/sniper/bot_sniper.mdl"	// Player model
		"arg804"	"2"					// Player class
		"arg805"	"1"					// Robot type
		// 1: Minion
		// 2: Engineer
		// 3: Spy
		// 4: Big Bot
		// 5: Boss Bot
		// 6: Sentry Buster

		"arg806"	"125" 		// Player health
		"arg807"	"10.0"		// Chance to wield a bomb
		"arg808"	"Sniper"	// Boss name (For Boss Bot)
		"arg809"	"1"		// Cash to drop on death
		"arg810"	"0"		// If crit boosted

		"arg811"	"tf_weapon_sniperrifle"		// Weapon Classname
		"arg812"	"14"				// Weapon Index
		"arg813"	"1 ; 0.75 ; 392 ; 0.667"	// Weapon Attributes
		"arg814"	"99999"				// Weapon Ammo
		"arg815"	""				// Weapon Clip
		"arg816"	""				// Weapon Model

		"arg821"	"tf_weapon_club"	// Weapon Classname
		"arg822"	"3"			// Weapon Index
		"arg823"	"15 ; 0"		// Weapon Attributes
		"arg824"	""			// Weapon Ammo
		"arg825"	""			// Weapon Clip
		"arg826"	""			// Weapon Model

		"arg901"	"0"					// If amount is ratio of alive players
		"arg902"	"5"					// Amount/ratio to summon
		"arg903"	"models/bots/sniper/bot_sniper.mdl"	// Player model
		"arg904"	"2"					// Player class
		"arg905"	"1"					// Robot type
		// 1: Minion
		// 2: Engineer
		// 3: Spy
		// 4: Big Bot
		// 5: Boss Bot
		// 6: Sentry Buster

		"arg906"	"125" 		// Player health
		"arg907"	"15.0"		// Chance to wield a bomb
		"arg908"	"Huntsman"	// Boss name (For Boss Bot)
		"arg909"	"1"		// Cash to drop on death
		"arg910"	"0"		// If crit boosted

		"arg911"	"tf_weapon_compound_bow"		// Weapon Classname
		"arg912"	"56"					// Weapon Index
		"arg913"	"1 ; 0.75 ; 392 ; 0.667 ; 401 ; 0.79"	// Weapon Attributes
		"arg914"	"99999"					// Weapon Ammo
		"arg915"	"1"					// Weapon Clip
		"arg916"	""					// Weapon Model

		"arg921"	"tf_weapon_club"	// Weapon Classname
		"arg922"	"3"			// Weapon Index
		"arg923"	"15 ; 0"		// Weapon Attributes
		"arg924"	""			// Weapon Ammo
		"arg925"	""			// Weapon Clip
		"arg926"	""			// Weapon Model

		"arg1001"	"0"				// If amount is ratio of alive players
		"arg1002"	"5"				// Amount/ratio to summon
		"arg1003"	"models/bots/spy/bot_spy.mdl"	// Player model
		"arg1004"	"8"				// Player class
		"arg1005"	"3"				// Robot type
		// 1: Minion
		// 2: Engineer
		// 3: Spy
		// 4: Big Bot
		// 5: Boss Bot
		// 6: Sentry Buster

		"arg1006"	"125" 	// Player health
		"arg1007"	"0.0"	// Chance to wield a bomb
		"arg1008"	"Spy"	// Boss name (For Boss Bot)
		"arg1009"	"1"	// Cash to drop on death
		"arg1010"	"0"	// If crit boosted

		"arg1011"	"tf_weapon_revolver"	// Weapon Classname
		"arg1012"	"24"			// Weapon Index
		"arg1013"	"1 ; 0.75 ; 15 ; 0"	// Weapon Attributes
		"arg1014"	"99999"			// Weapon Ammo
		"arg1015"	"6"			// Weapon Clip
		"arg1016"	""			// Weapon Model

		"arg1021"	"tf_weapon_builder"	// Weapon Classname
		"arg1022"	"735"			// Weapon Index
		"arg1023"	""			// Weapon Attributes
		"arg1024"	""			// Weapon Ammo
		"arg1025"	""			// Weapon Clip
		"arg1026"	""			// Weapon Model

		"arg1031"	"tf_weapon_knife"	// Weapon Classname
		"arg1032"	"4"			// Weapon Index
		"arg1033"	""			// Weapon Attributes
		"arg1034"	""			// Weapon Ammo
		"arg1035"	""			// Weapon Clip
		"arg1036"	""			// Weapon Model

		"arg1041"	"tf_weapon_pda_spy"	// Weapon Classname
		"arg1042"	"27"			// Weapon Index
		"arg1043"	"157 ; 1"		// Weapon Attributes
		"arg1044"	""			// Weapon Ammo
		"arg1045"	""			// Weapon Clip
		"arg1046"	""			// Weapon Model

		"arg1051"	"tf_weapon_invis"	// Weapon Classname
		"arg1052"	"30"			// Weapon Index
		"arg1053"	"159 ; 1"		// Weapon Attributes
		"arg1054"	""			// Weapon Ammo
		"arg1055"	""			// Weapon Clip
		"arg1056"	""			// Weapon Model

		"plugin_name"	"ffbat_nec_abilities"

		"sound_gray_bomb"
		{
			"1"	"vo/mvm_bomb_alerts01.mp3"
			"2"	"vo/mvm_bomb_alerts02.mp3"
		}
		"sound_gray_bomb_tutorial"
		{
			"1"	"freak_fortress_2/graymann/droppoint.mp3"
		}
		"sound_gray_bomb_again"
		{
			"1"	"vo/mvm_another_bomb01.mp3"
			"2"	"vo/mvm_another_bomb02.mp3"
			"3"	"vo/mvm_another_bomb03.mp3"
			"4"	"vo/mvm_another_bomb04.mp3"
			"5"	"vo/mvm_another_bomb05.mp3"
			"6"	"vo/mvm_another_bomb06.mp3"
			"7"	"vo/mvm_another_bomb07.mp3"
			"8"	"vo/mvm_another_bomb08.mp3"
		}
		"sound_gray_spy"
		{
			"1"	"vo/mvm_spy_spawn01.mp3"
			"2"	"vo/mvm_spy_spawn02.mp3"
			"3"	"vo/mvm_spy_spawn03.mp3"
			"4"	"vo/mvm_spy_spawn04.mp3"
		}
		"sound_gray_engi"
		{
			"1"	"vo/announcer_mvm_engbot_arrive01.mp3"
			"2"	"vo/announcer_mvm_engbot_arrive02.mp3"
			"3"	"vo/announcer_mvm_engbot_arrive03.mp3"
		}
		"sound_gray_engis"
		{
			"1"	"vo/announcer_mvm_engbots_arrive01.mp3"
			"2"	"vo/announcer_mvm_engbots_arrive02.mp3"
		}
		"sound_gray_engi_again"
		{
			"1"	"vo/announcer_mvm_engbot_another01.mp3"
			"2"	"vo/announcer_mvm_engbot_another02.mp3"
		}
		"sound_gray_buster"
		{
			"1"	"vo/mvm_sentry_buster_alerts01.mp3"
			"2"	"vo/mvm_sentry_buster_alerts04.mp3"
			"3"	"vo/mvm_sentry_buster_alerts05.mp3"
			"4"	"vo/mvm_sentry_buster_alerts06.mp3"
			"5"	"vo/mvm_sentry_buster_alerts07.mp3"
		}
		"sound_gray_buster_spawn"
		{
			"1"	"mvm/sentrybuster/mvm_sentrybuster_intro.wav"
		}
		"sound_gray_buster_again"
		{
			"1"	"vo/mvm_sentry_buster_alerts02.mp3"
			"2"	"vo/mvm_sentry_buster_alerts03.mp3"
		}
		"sound_gray_mega_spawn"
		{
			"1"	"freak_fortress_2/graymann/destroythem.mp3"
			"2"	"freak_fortress_2/graymann/killthem.mp3"
		}
		"sound_gray_mega"
		{
			"1"	"mvm/mvm_tank_start.wav"
		}
		"sound_gray_teleport"
		{
			"1"	"mvm/mvm_tele_deliver.wav"
		}


		"name"		"special_gray_extra"

		"arg1"		"tf_weapon_laser_pointer"	// Classname
		"arg2"		"25"				// Index
		"arg3"		"236 ; 1"			// Attributes
		"arg4"		"1"				// Visibility

		"plugin_name"	"ffbat_nec_abilities"

		"sound_gray_kspree"
		{
			"1"	"vo/mvm_all_dead01.mp3"
			"2"	"vo/mvm_all_dead02.mp3"
			"3"	"vo/mvm_all_dead03.mp3"
		}
		"sound_gray_engi_death"
		{
			"1"	"vo/announcer_mvm_engbot_dead_notele01.mp3"
			"2"	"vo/announcer_mvm_engbot_dead_notele02.mp3"
			"3"	"vo/announcer_mvm_engbot_dead_notele03.mp3"
		}
		"sound_gray_engis_death"
		{
			"1"	"vo/announcer_mvm_engbots_dead_notele01.mp3"
			"2"	"vo/announcer_mvm_engbots_dead_notele02.mp3"
		}
		"sound_gray_engi_death_tele"
		{
			"1"	"vo/announcer_mvm_engbot_dead_tele01.mp3"
			"2"	"vo/announcer_mvm_engbot_dead_tele02.mp3"
		}
		"sound_gray_buster_death"
		{
			"1"	"mvm/sentrybuster/mvm_sentrybuster_explode.wav"
		}
		"sound_gray_spies_death"
		{
			"1"	"vo/mvm_spybot_death04.mp3"
			"2"	"vo/mvm_spybot_death05.mp3"
			"3"	"vo/mvm_spybot_death06.mp3"
			"4"	"vo/mvm_spybot_death07.mp3"
		}
		"sound_gray_bomb_upgrade"
		{
			"1"	"mvm/mvm_warning.wav"
		}
		"sound_gray_bomb_death"
		{
			"1"	"vo/mvm_bomb_back01.mp3"
			"2"	"vo/mvm_bomb_back02.mp3"
			"3"	"vo/mvm_bomb_reset01.mp3"
			"4"	"vo/mvm_bomb_reset02.mp3"
			"5"	"vo/mvm_bomb_reset03.mp3"
		}
		"sound_gray_win"
		{
			"1"	"vo/mvm_final_wave_end01.mp3"
			"2"	"vo/mvm_final_wave_end02.mp3"
			"3"	"vo/mvm_final_wave_end03.mp3"
			"4"	"vo/mvm_final_wave_end05.mp3"
			"5"	"vo/mvm_final_wave_end06.mp3"
			"6"	"vo/mvm_manned_up01.mp3"
			"7"	"vo/mvm_manned_up02.mp3"
			"8"	"vo/mvm_manned_up03.mp3"
			"9"	"vo/mvm_mannup_wave_end01.mp3"
			"10"	"vo/mvm_mannup_wave_end02.mp3"
			"11"	"vo/mvm_wave_end08.mp3"
		}
		"sound_gray_lose"
		{
			"1"	"vo/mvm_game_over_loss01.mp3"
			"2"	"vo/mvm_game_over_loss02.mp3"
			"3"	"vo/mvm_game_over_loss03.mp3"
			"4"	"vo/mvm_game_over_loss04.mp3"
			"5"	"vo/mvm_game_over_loss05.mp3"
			"6"	"vo/mvm_game_over_loss06.mp3"
			"7"	"vo/mvm_game_over_loss07.mp3"
			"8"	"vo/mvm_game_over_loss08.mp3"
			"9"	"vo/mvm_game_over_loss09.mp3"
			"10"	"vo/mvm_game_over_loss10.mp3"
			"11"	"vo/mvm_game_over_loss11.mp3"
			"12"	"vo/mvm_wave_lose01.mp3"
			"13"	"vo/mvm_wave_lose02.mp3"
			"14"	"vo/mvm_wave_lose03.mp3"
			"15"	"vo/mvm_wave_lose09.mp3"
			"16"	"vo/mvm_wave_lose10.mp3"
			"17"	"vo/mvm_wave_lose12.mp3"
		}
		"sound_gray_player_death"
		{
			"1"	"mvm/mvm_player_died.wav"
		}


		"name"		"special_gray_markers"

		"arg1"		"30.0"	// Revive marker lifetime
		"arg2"		"3"	// Revive limit
		"arg3"		"1"	// Hide mode
		// 0: Everyone can see it
		// 1: Only same team can see it
		// 2: Only same team Medics can see it

		"plugin_name"	"ffbat_nec_abilities"

		"sound_gray_intro"
		{
			"1"	"music/mvm_class_select.wav"
		}
*/

enum BossType
{
	Boss_None = 0,
	Boss_Minion,
	Boss_Engi,
	Boss_Spy,
	Boss_Normal,
	Boss_Mega,
	Boss_Buster
}

#define GMS_NAME		"rage_gray_summon"
#define GMS_BOMB		"sound_gray_bomb"
#define GMS_BOMBS	"sound_gray_bomb_tutorial"
#define GMS_BOMB2	"sound_gray_bomb_again"
#define GMS_SPY		"sound_gray_spy"
#define GMS_ENGI		"sound_gray_engi"
#define GMS_ENGIS	"sound_gray_engis"
#define GMS_ENGI2	"sound_gray_engi_again"
#define GMS_BUSTER	"sound_gray_buster"
#define GMS_BUSTERS	"sound_gray_buster_spawn"
#define GMS_BUSTER2	"sound_gray_buster_again"
#define GMS_MEGA		"sound_gray_mega_spawn"
#define GMS_MEGA2	"sound_gray_mega"
#define GMS_TELEPORT	"sound_gray_teleport"
#define GMS_BRIEFCASE	"models/flag/briefcase.mdl"
#define GMS_BOMBMODEL	"models/props_td/atom_bomb.mdl"
#define GMS_ROBOTSTUN	"mvm/mvm_robo_stun.wav"
#define GMS_KABOOM	"mvm/mvm_bomb_explode.wav"
#define GMS_TICKING	"mvm/sentrybuster/mvm_sentrybuster_loop.wav"
#define GMS_DETONATE	"mvm/sentrybuster/mvm_sentrybuster_spin.wav"
#define GMS_WEAPONS	7
#define GMS_GRAYISRICH	30
#define GMS_BOMBRANGE	380
static float GMS_ExplodeAt[MAXTF2PLAYERS];
static int GMS_Health[MAXTF2PLAYERS];
static int GMS_Owner[MAXTF2PLAYERS];
static int GMS_Cash[MAXTF2PLAYERS];
static int GMS_Buff[MAXTF2PLAYERS];
static BossType GMS_BossType[MAXTF2PLAYERS];
static bool GMS_IsUpgraded[MAXTF2PLAYERS];
static float GMS_BombTimer;
static int GMS_BombCarrier;
static int GMS_BombLevel;
static bool GMS_HasEngiSummoned;
static bool GMS_HasEngisSummoned;
static bool GMS_HasBusterSummoned;
static bool GMS_WasBombEnabled;
static bool GMS_BombEnabled;

#define GME_NAME		"special_gray_extra"
#define GME_KSPREE	"sound_gray_kspree"
#define GME_ENGIDEAD	"sound_gray_engi_death"
#define GME_ENGISDEAD	"sound_gray_engis_death"
#define GME_ENGIDEAD2	"sound_gray_engi_death_tele"
#define GME_ENGISDEAD2	"sound_gray_engis_death_tele"
#define GME_BUSTERDEAD	"sound_gray_buster_death"
#define GME_SPIESDEAD	"sound_gray_spies_death"
#define GME_UPGRADE	"sound_gray_bomb_upgrade"
#define GME_BOMBDEAD	"sound_gray_bomb_death"
#define GME_WIN		"sound_gray_win"
#define GME_LOSE		"sound_gray_lose"
#define GME_DEATH	"sound_gray_player_death"
static int GME_Boss;
static TFTeam GME_Team;
static bool GME_Enabled;

#define GMR_NAME		"special_gray_markers"
#define GMR_INTRO	"sound_gray_intro"
static int GMR_Revives[MAXTF2PLAYERS][2];
static float GMR_GoneAt[MAXTF2PLAYERS];
static float GMR_MoveAt[MAXTF2PLAYERS];
static int GMR_EntRef[MAXTF2PLAYERS];
static float GMR_Lifetime[2];
static int GMR_Limit[2];
static int GMR_Hide[2];
static TFTeam GMR_Team;

#define GMA_NAME		"special_gray_combined"

/*
	Summon
*/

void GMS_Precache()
{
	PrecacheModel(GMS_BOMBMODEL, true);
	PrecacheSound(GMS_TICKING);
	PrecacheSound(GMS_ROBOTSTUN);
	PrecacheSound(GMS_DETONATE);
	AddNormalSoundHook(GMS_HookSound);
	for(int i; i<MAXTF2PLAYERS; i++)
	{
		GMS_Owner[i] = -1;
	}
}

void GMS_Ability(int boss, const char[] ability_name)
{
	GMS_Summon(boss, ability_name, NULL_VECTOR);
}

static int GMS_Summon(int boss, const char[] ability_name, float position[3])
{
	char temp[MAX_ABILITY_LENGTH];
	int loadout;
	for(; loadout<99; loadout++)
	{
		FormatEx(temp, MAX_ABILITY_LENGTH, "amount%i", loadout+1);
		if(GetArgI(boss, ability_name, temp, (loadout*100)+2, -999.9) == -999.9)
			break;
	}

	if(--loadout > 0)
		loadout = GetRandomInt(0, loadout);

	FormatEx(temp, MAX_ABILITY_LENGTH, "model%i", loadout+1);
	static char model[MAX_MODEL_LENGTH];
	GetArgS(boss, ability_name, temp, (loadout*100)+3, model, MAX_MODEL_LENGTH);

	FormatEx(temp, MAX_ABILITY_LENGTH, "class%i", loadout+1);
	TFClassType class = view_as<TFClassType>(RoundFloat(GetArgI(boss, ability_name, temp, (loadout*100)+4, float(view_as<int>(TFClass_Unknown)))));

	FormatEx(temp, MAX_ABILITY_LENGTH, "boss%i", loadout+1);
	BossType type = view_as<BossType>(RoundFloat(GetArgI(boss, ability_name, temp, (loadout*100)+5, 1.0)));

	FormatEx(temp, MAX_ABILITY_LENGTH, "health%i", loadout+1);
	int health = RoundFloat(GetArgF(boss, ability_name, temp, (loadout*100)+6, 1.0, 0));

	bool bomb;
	if(!GMS_BombEnabled)
	{
		FormatEx(temp, MAX_ABILITY_LENGTH, "bomb%i", loadout+1);
		bomb = GetArgF(boss, ability_name, temp, (loadout*100)+7, 0.0, 0)>GetRandomFloat(0.0, 100.0);
	}

	FormatEx(temp, MAX_ABILITY_LENGTH, "cash%i", loadout+1);
	int cash = RoundFloat(GetArgF(boss, ability_name, temp, (loadout*100)+9, 5.0, 0));

	FormatEx(temp, MAX_ABILITY_LENGTH, "crits%i", loadout+1);
	bool crits = view_as<bool>(RoundFloat(GetArgI(boss, ability_name, temp, (loadout*100)+10, 0.0)));

	static bool wearable[GMS_WEAPONS];
	static char classname[GMS_WEAPONS][MAX_CLASSNAME_LENGTH];
	static int index[GMS_WEAPONS];
	static char attributes[GMS_WEAPONS][MAX_ATTRIBUTE_LENGTH];
	static int ammo[GMS_WEAPONS];
	static int clip[GMS_WEAPONS];
	static char worldmodel[GMS_WEAPONS][MAX_MODEL_LENGTH];
	int weapons;
	bool actionSlotUsed;
	for(int i; i<GMS_WEAPONS; i++)
	{
		FormatEx(temp, MAX_ABILITY_LENGTH, "classname%i-%i", loadout+1, i+1);
		if(!GetArgS(boss, ability_name, temp, (loadout*100)+(i*10)+11, classname[i], MAX_CLASSNAME_LENGTH))
			break;

		wearable[i] = StrContains(classname[i], "tf_weap")==-1;

		if(!actionSlotUsed && (StrEqual(classname[i], "tf_weapon_grapplinghook") || StrEqual(classname[i], "tf_weapon_spellbook") || StrEqual(classname[i], "tf_powerup_bottle")))
			actionSlotUsed = true;

		weapons++;
		FormatEx(temp, MAX_ABILITY_LENGTH, "index%i-%i", loadout+1, i+1);
		index[i] = RoundFloat(GetArgI(boss, ability_name, temp, (loadout*100)+(i*10)+12));
		FormatEx(temp, MAX_ABILITY_LENGTH, "attributes%i-%i", loadout+1, i+1);
		GetArgS(boss, ability_name, temp, (loadout*100)+(i*10)+13, attributes[i], MAX_ATTRIBUTE_LENGTH);
		FormatEx(temp, MAX_ABILITY_LENGTH, "ammo%i-%i", loadout+1, i+1);
		ammo[i] = RoundFloat(GetArgF(boss, ability_name, temp, (loadout*100)+(i*10)+14, -1.0, 0));
		FormatEx(temp, MAX_ABILITY_LENGTH, "clip%i-%i", loadout+1, i+1);
		clip[i] = RoundFloat(GetArgF(boss, ability_name, temp, (loadout*100)+(i*10)+15, -1.0, 0));
		FormatEx(temp, MAX_ABILITY_LENGTH, "model%i-%i", loadout+1, i+1);
		GetArgS(boss, ability_name, temp, (loadout*100)+(i*10)+16, worldmodel[i], MAX_MODEL_LENGTH);
	}

	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	int bossTeam = GetClientTeam(client);
	if(GMS_Cash[client] < 36)
		GMS_Cash[client]++;

	// Get Dead Targets
	int dead, amount, var1;
	ArrayList players = new ArrayList();
	for(int target=1; target<=MaxClients; target++)
	{
		if(!IsValidClient(target))
			continue;

		var1 = GetClientTeam(target);
		if(var1 <= view_as<int>(TFTeam_Spectator))
			continue;

		if(IsPlayerAlive(target))
		{
			if(var1!=bossTeam && (type!=Boss_Buster || TF2_GetPlayerClass(target)==TFClass_Engineer))
				amount++;
		}
		else if(FF2_GetBossIndex(target) < 0)
		{
			players.Push(target);
			dead++;
		}
	}

	FormatEx(temp, MAX_ABILITY_LENGTH, "ratio%i", loadout+1);
	if(GetArgI(boss, ability_name, temp, (loadout*100)+1))
	{
		FormatEx(temp, MAX_ABILITY_LENGTH, "amount%i", loadout+1);
		float ratio = GetArgF(boss, ability_name, temp, (loadout*100)+2, 1.0, 0);
		amount = RoundToCeil(amount*ratio);
		if(amount < 1)
			amount = (type==Boss_Engi && !GetRandomInt(0, 3)) ? 2 : 1;
	}
	else
	{
		FormatEx(temp, MAX_ABILITY_LENGTH, "amount%i", loadout+1);
		amount = RoundToCeil(GetArgF(boss, ability_name, temp, (loadout*100)+2, 1.0, 2));
	}

	// Loop, Spawn, Equip, Etc.
	bool activeWep;
	int clone, var2;
	for(int i; i<dead && i<amount; i++)
	{
		// Delete From Array
		var1 = GetRandomInt(0, players.Length-1);
		clone = players.Get(var1);
		players.Erase(var1);

		// Assign Global Vars
		GMS_BossType[clone] = type;
		GMS_Owner[clone] = boss;
		GMS_Cash[clone] = cash;
		G_BlockPickups[clone] = true;

		// Team, Flags, Spawn, Class
		FF2_SetFF2flags(clone, FF2_GetFF2flags(clone)|FF2FLAG_ALLOWSPAWNINBOSSTEAM|FF2FLAG_CLASSTIMERDISABLED);
		ChangeClientTeam(clone, bossTeam);
		TF2_RespawnPlayer(clone);
		if(class != TFClass_Unknown)
			TF2_SetPlayerClass(clone, class, _, false);

		static char sound[MAX_SOUND_LENGTH];
		switch(type)
		{
			case Boss_Buster:
			{
				G_BlockSuicide[clone] = true;
				EmitSoundToAll(GMS_TICKING, clone);
				if(!i && !bomb)
				{
					ShowGameText(0, "ico_demolish", _, (amount>1 && dead>1) ? GMS_HasBusterSummoned ? "More Sentry Busters has spawned!" : "Sentry Busters has spawned!" : GMS_HasBusterSummoned ? "Another Sentry Buster has spawned!" : "A Sentry Buster has spawned!");
					if(FF2_RandomSound(GMS_HasBusterSummoned ? GMS_BUSTER2 : GMS_BUSTER, sound, MAX_SOUND_LENGTH, boss))
					{
						for(var1=1; var1<=MaxClients; var1++)
						{
							if(IsValidClient(var1) && GetClientTeam(var1)!=bossTeam)
								ClientCommand(var1, "playgamesound \"%s\"", sound);
						}
					}

					GMS_HasBusterSummoned = true;
					if(FF2_RandomSound(GMS_BUSTERS, sound, MAX_SOUND_LENGTH, boss))
						EmitVoiceToAll(sound);
				}
			}
			case Boss_Engi:
			{
				if(!i && !bomb)
				{
					ShowGameText(0, "ico_metal", _, (amount>1 && dead>1) ? GMS_HasEngiSummoned ? "More Engineers has spawned!" : "Engineers has spawned!" : GMS_HasEngiSummoned ? "Another Engineer has spawned!" : "An Engineer has spawned!");
					if(FF2_RandomSound((amount>1 && dead>1) ? GMS_ENGIS : GMS_HasEngiSummoned ? GMS_ENGI2 : GMS_ENGI, sound, MAX_SOUND_LENGTH, boss))
					{
						for(var1=1; var1<=MaxClients; var1++)
						{
							if(IsValidClient(var1) && GetClientTeam(var1)!=bossTeam)
								ClientCommand(var1, "playgamesound \"%s\"", sound);
						}
					}
				}

				GMS_HasEngiSummoned = true;
				GMS_HasEngisSummoned = (GMS_HasEngisSummoned || i);
			}
			case Boss_Spy:
			{
				if(!i && !bomb)
				{
					ShowGameText(0, "hud_spy_disguise_menu_icon", _, "Spies has spawned!");
					if(FF2_RandomSound(GMS_SPY, sound, MAX_SOUND_LENGTH, boss))
					{
						for(var1=1; var1<=MaxClients; var1++)
						{
							if(IsValidClient(var1) && GetClientTeam(var1)!=bossTeam)
								ClientCommand(var1, "playgamesound \"%s\"", sound);
						}
					}
				}
			}
			case Boss_Normal:
			{
				G_BlockSuicide[clone] = true;
			}
			case Boss_Mega:
			{
				G_BlockSuicide[clone] = true;
				FormatEx(temp, MAX_ABILITY_LENGTH, "name%i", loadout+1);
				GetArgS(boss, ability_name, temp, (loadout*100)+8, temp, MAX_ABILITY_LENGTH);
				CPrintToChatAll("{olive}[FF2]{default} %N became %s with %i HP!", clone, temp, health);
				if(!i && !bomb)
				{
					ShowGameText(0, "ico_notify_on_fire", bossTeam, "%N became %s with %i HP!", clone, temp, health);
					if(FF2_RandomSound(GMS_MEGA, sound, MAX_SOUND_LENGTH, boss))
						EmitVoiceToAll(sound);

					if(FF2_RandomSound(GMS_MEGA2, sound, MAX_SOUND_LENGTH, boss))
					{
						for(var1=1; var1<=MaxClients; var1++)
						{
							if(IsValidClient(var1) && GetClientTeam(var1)==bossTeam)
								ClientCommand(var1, "playgamesound \"%s\"", sound);
						}
					}
				}
			}
		}

		// Model
		if(model[0])
		{
			PrecacheModel(model);

			DataPack data;
			CreateDataTimer(0.2, GMS_EquipModel, data, TIMER_FLAG_NO_MAPCHANGE);
			data.WriteCell(GetClientUserId(clone));
			data.WriteString(model);
		}

		var1 = -1;
		while((var1=FindEntityByClassname2(var1, "tf_wear*")) != -1)
		{
			if(clone == GetEntPropEnt(var1, Prop_Send, "m_hOwnerEntity"))
			{
				switch(GetEntProp(var1, Prop_Send, "m_iItemDefinitionIndex"))
				{
					case 493, 233, 234, 241, 280, 281, 282, 283, 284, 286, 288, 362, 364, 365, 536, 542, 577, 599, 673, 729, 791, 928:  //Action slot items
					{
						if(actionSlotUsed)
							TF2_RemoveWearable(clone, var1);
					}
					default:
					{
						TF2_RemoveWearable(clone, var1);
					}
				}
			}
		}

		var1 = -1;
		while((var1=FindEntityByClassname2(var1, "tf_powerup_bottle")) != -1)
		{
			if(clone == GetEntPropEnt(var1, Prop_Send, "m_hOwnerEntity"))
				TF2_RemoveWearable(clone, var1);
		}

		// Weapons
		if(weapons)
		{
			TF2_RemoveAllWeapons(clone);

			activeWep = false;
			for(var2=0; var2<weapons; var2++)
			{
				if(wearable[var2])
				{
					var1 = TF2_CreateAndEquipWearable(clone, classname[var2], index[var2], 101, 14, attributes[var2]);
				}
				else
				{
					var1 = SpawnWeapon(clone, classname[var2], index[var2], 101, 14, attributes[var2], !worldmodel[var2][0]);
					if(var1 == -1)
						continue;

					if(index[var2]!=735 && index[var2]!=736 && StrEqual(classname[var2], "tf_weapon_builder"))  //PDA, normal sapper
					{
						SetEntProp(var1, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
						SetEntProp(var1, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
						SetEntProp(var1, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
						SetEntProp(var1, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
					}
					else if(index[var2]==735 || index[var2]==736 || StrEqual(classname[var2], "tf_weapon_sapper"))  //Sappers, normal sapper
					{
						SetEntProp(var1, Prop_Send, "m_iObjectType", 3);
						SetEntProp(var1, Prop_Data, "m_iSubType", 3);
						SetEntProp(var1, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
						SetEntProp(var1, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
						SetEntProp(var1, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
						SetEntProp(var1, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
					}

					FF2_SetAmmo(clone, var1, ammo[var2], clip[var2]);
					TF2Attrib_SetByDefIndex(var1, 109, 0.0);

					if(!activeWep) // Equip only if it's the first weapon
					{
						SetEntPropEnt(clone, Prop_Send, "m_hActiveWeapon", var1);
						activeWep = true;
					}
				}

				if(worldmodel[var2][0])
					ConfigureWorldModelOverride(var1, worldmodel[var2], wearable[var2]);
			}
		}

		if(health > 0)
		{
			GMS_Health[clone] = health;
			CreateTimer(0.2, GMS_SetHealth, GetClientUserId(clone), TIMER_FLAG_NO_MAPCHANGE);
			SDKHook(clone, SDKHook_GetMaxHealth, GMS_GetMaxHealth);
			SetEntProp(clone, Prop_Data, "m_iHealth", health);
			SetEntProp(clone, Prop_Send, "m_iHealth", health);
		}

		if(crits)
			TF2_AddCondition(clone, TFCond_HalloweenCritCandy, TFCondDuration_Infinite);

		if(!bomb)
		{
			if(IsNullVector(position))
			{
				TF2_AddCondition(clone, TFCond_UberchargedHidden, 3.0);
				continue;
			}

			TeleportEntity(clone, position, NULL_VECTOR, NULL_VECTOR);
			SetEntProp(clone, Prop_Send, "m_bDucked", 1);
			SetEntityFlags(clone, GetEntityFlags(clone)|FL_DUCKING);
			continue;
		}

		static float pos[3];
		GetEntPropVector(clone, Prop_Data, "m_vecOrigin", pos);

		GMS_BombEnabled = true;

		bomb = false;
		var1 = CreateEntityByName("item_teamflag");
		TeleportEntity(var1, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(var1, "Angles", "0 0 0");
		DispatchKeyValue(var1, "TeamNum", bossTeam==3 ? "3" : "2");
		DispatchKeyValue(var1, "StartDisabled", "0");
		DispatchSpawn(var1); 
		AcceptEntityInput(var1, "Enable");

		GMS_BombCarrier = 0;
		GMS_BombLevel = 0;
		GMS_BombTimer = GetGameTime()+58.0;

		CreateTimer(0.1, GMS_BombThink, EntIndexToEntRef(var1), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		SDKHook(var1, SDKHook_StartTouch, GMS_BombTouch);
		SDKHook(var1, SDKHook_Touch, GMS_BombTouch);

		ShowGameText(0, "ico_notify_flag_moving_alt", _, GMS_WasBombEnabled ? "Another bomb has spawned!" : "A bomb has spawned!");
		if(FF2_RandomSound(GMS_WasBombEnabled ? GMS_BOMB2 : GMS_BOMB, sound, MAX_SOUND_LENGTH, boss))
		{
			for(int target=1; target<=MaxClients; target++)
			{
				if(clone!=target && IsValidClient(target) && GetClientTeam(target)!=bossTeam)
					ClientCommand(target, "playgamesound \"%s\"", sound);
			}
		}

		if(FF2_RandomSound(GMS_BOMBS, sound, MAX_SOUND_LENGTH, boss))
			ClientCommand(clone, "playgamesound \"%s\"", sound);

		if(!GMS_WasBombEnabled)
		{
			var1 = MaxClients+1;
			while((var1=FindEntityByClassname2(var1, "trigger_capture_area")) != -1)
			{
				SDKHook(var1, SDKHook_StartTouch, GMS_PointTouch);
				SDKHook(var1, SDKHook_Touch, GMS_PointTouch);
			}
		}
		GMS_WasBombEnabled = true;
	}
	delete players;
	return clone;
}

public Action GMS_GetMaxHealth(int client, int &health)
{
	if(!IsPlayerAlive(client) || GMS_BossType[client]==Boss_None)
		SDKUnhook(client, SDKHook_GetMaxHealth, GMS_GetMaxHealth);

	health = GMS_Health[client];
	return Plugin_Changed;
}

public Action GMS_SetHealth(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(IsValidClient(client))
		SetEntityHealth(client, GMS_Health[client]);

	return Plugin_Continue;
}

public Action GMS_EquipModel(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	if(!IsValidClient(client))
		return Plugin_Continue;

	static char model[MAX_MODEL_LENGTH];
	pack.ReadString(model, MAX_MODEL_LENGTH);
	SetVariantString(model);
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
	return Plugin_Continue;
}

public Action GMS_PointTouch(int entity, int client)
{
	if(!IsValidClient(client))
		return Plugin_Continue;

	if(GMS_BombEnabled)
		return GMS_BombCarrier==client ? Plugin_Continue : Plugin_Handled;

	return (GMS_BossType[client]==Boss_None || GMS_BossType[client]==Boss_Mega) ? Plugin_Continue : Plugin_Handled;
}

public Action GMS_BombTouch(int entity, int client)
{
	if(!IsValidClient(client))
		return Plugin_Continue;

	return (GMS_BossType[client]==Boss_None || GMS_BossType[client]==Boss_Mega || GMS_BossType[client]==Boss_Buster) ? Plugin_Handled : Plugin_Continue;
}

public Action GMS_BombThink(Handle timer, int ref)
{
	int entity = EntRefToEntIndex(ref);

	static char sound[MAX_SOUND_LENGTH];
	bool validEntity = (entity>MaxClients && IsValidEntity(entity));
	bool validClient = (IsValidClient(GMS_BombCarrier) && IsPlayerAlive(GMS_BombCarrier));
	if(!validEntity || !GMS_BombEnabled || (!validClient && GMS_BombTimer<GetGameTime()))
	{
		if(validEntity)
		{
			SDKUnhook(entity, SDKHook_StartTouch, GMS_BombTouch);
			SDKUnhook(entity, SDKHook_Touch, GMS_BombTouch);
			AcceptEntityInput(entity, "Kill");
		}

		GMS_BombTimer = FAR_FUTURE;
		GMS_BombCarrier = 0;
		GMS_BombLevel = 0;
		GMS_BombEnabled = false;
		if(G_RoundState!=1 || !GME_Enabled || !FF2_RandomSound(GME_BOMBDEAD, sound, MAX_SOUND_LENGTH, GME_Boss))
			return Plugin_Stop;

		for(int target=1; target<=MaxClients; target++)
		{
			if(IsValidClient(target) && TF2_GetClientTeam(target)!=GME_Team)
				ClientCommand(target, "playgamesound \"%s\"", sound);
		}
		return Plugin_Stop;
	}

	if(!validClient)
		return Plugin_Continue;

	if(GMS_BossType[GMS_BombCarrier] == Boss_Normal)
		return Plugin_Continue;

	float engineTime = GetEngineTime();
	if(GMS_BombTimer < engineTime)
	{
		ClientCommand(GMS_BombCarrier, "taunt");
		FakeClientCommand(GMS_BombCarrier, "taunt");
		TF2_AddCondition(GMS_BombCarrier, TFCond_HalloweenKartNoTurn, 3.0);
		if(++GMS_BombLevel > 2)
		{
			GMS_BombTimer = FAR_FUTURE;
		}
		else
		{
			GMS_BombTimer = GetEngineTime()+20.0;
		}

		if(GME_Enabled && FF2_RandomSound(GME_UPGRADE, sound, MAX_SOUND_LENGTH, GME_Boss))
			EmitVoiceToAll(sound);
	}

	{
		static float nextAt;
		if(nextAt > engineTime)
			return Plugin_Continue;

		nextAt = engineTime+1.8;
	}

	static float position[3];
	GetEntPropVector(GMS_BombCarrier, Prop_Send, "m_vecOrigin", position);
	int team = GetClientTeam(GMS_BombCarrier);
	if(GMS_BombLevel)
	{
		for(int target=1; target<=MaxClients; target++)
		{
			if(!(GMS_BossType[target]==Boss_Minion || GMS_BossType[target]==Boss_Engi || GMS_BossType[target]==Boss_Spy) || !IsValidClient(target) || !IsPlayerAlive(target) || GetClientTeam(target)!=team)
				continue;

			static float position2[3];
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", position2);
			if(GetVectorDistance(position, position2) > GMS_BOMBRANGE)
				continue;

			if(GMS_BombLevel > 2)
				TF2_AddCondition(target, TFCond_HalloweenCritCandy, 2.0);

			if(GMS_BombLevel > 1)
				TF2_AddCondition(target, TFCond_HalloweenQuickHeal, 2.0);

			TF2_AddCondition(target, TFCond_DefenseBuffNoCritBlock, 2.0);
		}
	}
	return Plugin_Continue;
}

void GMS_FlagSpawn(int entity)
{
	if(!GMS_BombEnabled)
		return;

	static char model[MAX_MODEL_LENGTH];
	GetEntPropString(entity, Prop_Data, "m_iszModel", model, sizeof(model));
	if(!model[0] || StrEqual(model, GMS_BRIEFCASE))
	{
		DispatchKeyValue(entity, "flag_model", GMS_BOMBMODEL);
		DispatchKeyValue(entity, "trail_effect", "3");
	}
}

public Action GMS_Flag(int client, int type)
{
	if(!GMS_BombEnabled || !IsValidClient(client))
		return Plugin_Continue;

	if(type == TF_FLAGEVENT_PICKEDUP)
	{
		GMS_BombLevel = 0;
		GMS_BombCarrier = client;
		GMS_BombTimer = GetEngineTime()+10.0;
		PrintCenterText(client, "Drop the bomb off at the control point!");

		GMS_IsUpgraded[client] = true;
		TF2Attrib_SetByDefIndex(client, 442, GMS_BossType[client]==Boss_Normal ? 0.75 : 0.5);
		TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
		ServerCommand("ff2_point_enable");
		return Plugin_Handled;
	}

	GMS_BombLevel = 0;
	GMS_BombCarrier = 0;
	GMS_BombTimer = GetGameTime()+58.0;
	if(G_MercPlayers > GetConVarInt(FindConVar("ff2_point_delay")))
		ServerCommand("ff2_point_disable");

	TF2Attrib_SetByDefIndex(client, 442, 1.0);
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
	return Plugin_Handled;
}

void GMS_PointCapture()
{
	if(!GMS_BombEnabled || !IsValidClient(GMS_BombCarrier) || !IsPlayerAlive(GMS_BombCarrier))
		return;

	GMS_BombEnabled = false;
	GMS_ExplodeAt[GMS_BombCarrier] = 0.0;
	SDKHook(GMS_BombCarrier, SDKHook_PreThink, GMS_ExplodeThink);
	for(int target=1; target<=MaxClients; target++)
	{
		if(IsValidClient(target))
			ClientCommand(target, "playgamesound \"%s\"", GMS_KABOOM);
	}
}

void GMS_Death(int client, int flags, bool clean)
{
	if((flags & TF_DEATHFLAG_DEADRINGER) || !IsValidClient(client))
		return;

	switch(GMS_BossType[client])
	{
		case Boss_Buster:
		{
			StopSound(client, SNDCHAN_AUTO, GMS_TICKING);
			G_BlockSuicide[client] = false;
			G_BlockPickups[client] = false;
		}
		case Boss_Normal, Boss_Mega:
		{
			G_BlockSuicide[client] = false;
			G_BlockPickups[client] = false;
		}
		case Boss_Engi:
		{
			G_BlockPickups[client] = false;

			if(!clean)
			{
				int owner = GetClientOfUserId(FF2_GetBossUserId(GMS_Owner[client]));
				if(IsValidClient(owner))
				{
					int entity = MaxClients+1;
					while((entity=FindEntityByClassname2(entity, "obj_teleporter")) != -1)
					{
						if(GetEntPropEnt(entity, Prop_Send, "m_hBuilder") != client)
							continue;

						SetEntPropEnt(entity, Prop_Send, "m_hBuilder", owner);
						SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", owner);
					}
				}
			}
		}
		case Boss_None:
		{
			if(!clean)
			{
				int boss = FF2_GetBossIndex(client);
				if(boss >= 0)
				{
					int target = 1;
					for(; target<=MaxClients; target++)
					{
						if(!IsValidClient(target) || GMS_Owner[target]!=boss)
							continue;

						TF2_RemoveCondition(target, TFCond_UberchargedHidden);
						EmitVoiceToAll(GMS_ROBOTSTUN, target);
						TF2_StunPlayer(target, 20.5, 0.25, GMS_BossType[target]==Boss_Mega ? TF_STUNFLAGS_LOSERSTATE : TF_STUNFLAGS_NORMALBONK);
					}

					int entity = MaxClients+1;
					while((entity=FindEntityByClassname2(entity, "obj_sentrygun")) != -1)
					{
						target = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
						if(!IsValidClient(target) || (client!=target && GMS_Owner[target]!=boss))
							continue;

						SetEntProp(entity, Prop_Send, "m_bDisabled", 1);
						CreateTimer(20.5, GMS_EnableBuilding, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
					}

					entity = MaxClients+1;
					while((entity=FindEntityByClassname2(entity, "obj_teleporter")) != -1)
					{
						target = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
						if(!IsValidClient(target) || (client!=target && GMS_Owner[target]!=boss))
							continue;

						SetEntProp(entity, Prop_Send, "m_bDisabled", 1);
						CreateTimer(20.5, GMS_EnableBuilding, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
					}
				}
			}
		}
		default:
		{
			G_BlockPickups[client] = false;
		}
	}

	StopSound(client, SNDCHAN_AUTO, GMS_ROBOTSTUN);

	if(GMS_Owner[client] >= 0)
	{
		GMS_Owner[client] = -1;
		int flag = FF2_GetFF2flags(client);
		flag &= ~(FF2FLAG_ALLOWSPAWNINBOSSTEAM|FF2FLAG_CLASSTIMERDISABLED);
		FF2_SetFF2flags(client, flag);
		if(!clean)
			ClientCommand(client, "autoteam");
	}

	if(GMS_IsUpgraded[client])
	{
		TF2Attrib_SetByDefIndex(client, 60, 1.0);
		TF2Attrib_SetByDefIndex(client, 62, 1.0);
		TF2Attrib_SetByDefIndex(client, 64, 1.0);
		TF2Attrib_SetByDefIndex(client, 66, 1.0);
		TF2Attrib_SetByDefIndex(client, 442, 1.0);
		TF2Attrib_SetByDefIndex(client, 443, 1.0);
		TF2Attrib_SetByDefIndex(client, 57, 0.0);
		TF2Attrib_SetByDefIndex(client, 113, 0.0);
		TF2Attrib_SetByDefIndex(client, 286, 1.0);
		GMS_IsUpgraded[client] = false;
	}

	if(clean)
	{
		GMS_BossType[client] = Boss_None;
		GMS_Cash[client] = 0;
		return;
	}

	CreateTimer(0.1, GMS_UnsetFlag, client, TIMER_FLAG_NO_MAPCHANGE);
	if(GMS_Cash[client] > 0)
		GMS_DropCash(client, GMS_Cash[client]);

	GMS_Cash[client] = 0;
}

public Action GMS_EnableBuilding(Handle timer, int ref)
{
	int entity = EntRefToEntIndex(ref);
	if(entity > MaxClients)
		SetEntProp(entity, Prop_Send, "m_bDisabled", 0);

	return Plugin_Continue;
}

public Action GMS_UnsetFlag(Handle timer, int client)
{
	GMS_BossType[client] = Boss_None;
	return Plugin_Continue;
}

static void GMS_DropCash(int client, int amount)
{
	static float position[3];
	GetClientAbsOrigin(client, position);
	position[2] += 10.0;
	int entity, type;
	for(int i; i<amount; i++)
	{
		position[0] += GetRandomFloat(-15.0, 15.0);
		position[1] += GetRandomFloat(-15.0, 15.0);

		switch(GetRandomInt(0, 5))
		{
			case 3, 4:
			{
				entity = CreateEntityByName("item_currencypack_medium");
				if(!IsValidEntity(entity))
					continue;

				type = 1;
				PrecacheModel("models/items/currencypack_medium.mdl");
				SetEntityModel(entity, "models/items/currencypack_medium.mdl");
			}
			case 5:
			{
				entity = CreateEntityByName("item_currencypack_large");
				if(!IsValidEntity(entity))
					continue;

				type = 2;
				PrecacheModel("models/items/currencypack_large.mdl");
				SetEntityModel(entity, "models/items/currencypack_large.mdl");
			}
			default:
			{
				entity = CreateEntityByName("item_currencypack_small");
				if(!IsValidEntity(entity))
					continue;

				type = 0;
				PrecacheModel("models/items/currencypack_small.mdl");
				SetEntityModel(entity, "models/items/currencypack_small.mdl");
			}
		}

		DispatchKeyValue(entity, "OnPlayerTouch", "!self,Kill,,0,-1");
		SetEntProp(entity, Prop_Send, "m_nSkin", 0);
		SetEntProp(entity, Prop_Send, "m_nSolidType", 6);
		SetEntProp(entity, Prop_Send, "m_usSolidFlags", 152);
		SetEntProp(entity, Prop_Send, "m_triggerBloat", 24);
		SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1);
		SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
		SetEntProp(entity, Prop_Send, "m_iTeamNum", 2);
		DispatchSpawn(entity);
		SetEntityMoveType(entity, MOVETYPE_VPHYSICS);
		TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
		SetEntProp(entity, Prop_Data, "m_iHealth", 900);
		switch(type)
		{
			case 1:
			{
				SDKHook(entity, SDKHook_StartTouch, GMS_CashMed);
				SDKHook(entity, SDKHook_Touch, GMS_CashMed);
			}
			case 2:
			{
				SDKHook(entity, SDKHook_StartTouch, GMS_CashLarge);
				SDKHook(entity, SDKHook_Touch, GMS_CashLarge);
			}
			default:
			{
				SDKHook(entity, SDKHook_StartTouch, GMS_CashSmall);
				SDKHook(entity, SDKHook_Touch, GMS_CashSmall);
			}
		}
		CreateTimer(35.0, Timer_RemoveEntity, EntIndexToEntRef(entity));
	}
}

public Action GMS_CashSmall(int entity, int client)
{
	if(!IsValidClient(client))
		return Plugin_Continue;

	if(GMS_Buff[client]>99 || GMS_BossType[client]!=Boss_None || FF2_GetBossIndex(client)>=0)
		return Plugin_Handled;

	SDKUnhook(entity, SDKHook_StartTouch, GMS_CashSmall);
	SDKUnhook(entity, SDKHook_Touch, GMS_CashSmall);
	GMS_Upgrade(client, 6);
	return Plugin_Continue;
}

public Action GMS_CashMed(int entity, int client)
{
	if(!IsValidClient(client))
		return Plugin_Continue;

	if(GMS_Buff[client]>99 || GMS_BossType[client]!=Boss_None || FF2_GetBossIndex(client)>=0)
		return Plugin_Handled;

	SDKUnhook(entity, SDKHook_StartTouch, GMS_CashMed);
	SDKUnhook(entity, SDKHook_Touch, GMS_CashMed);
	GMS_Upgrade(client, 12);
	return Plugin_Continue;
}

public Action GMS_CashLarge(int entity, int client)
{
	if(!IsValidClient(client))
		return Plugin_Continue;

	if(GMS_Buff[client]>99 || GMS_BossType[client]!=Boss_None || FF2_GetBossIndex(client)>=0)
		return Plugin_Handled;

	SDKUnhook(entity, SDKHook_StartTouch, GMS_CashLarge);
	SDKUnhook(entity, SDKHook_Touch, GMS_CashLarge);
	GMS_Upgrade(client, 24);
	return Plugin_Continue;
}

static void GMS_Upgrade(int client, int amount=0)
{
	if(G_RoundState != 1)
		return;

	if(!GMS_Buff[client] && !amount)
		return;

	GMS_Buff[client] += amount;
	if(GMS_Buff[client] > 99)
		GMS_Buff[client] = 100;

	GMS_IsUpgraded[client] = true;
	float value = 1.0 - (GMS_Buff[client]*0.0075);
	TF2Attrib_SetByDefIndex(client, 60, value);
	TF2Attrib_SetByDefIndex(client, 64, value);
	TF2Attrib_SetByDefIndex(client, 66, value);

	TF2Attrib_SetByDefIndex(client, 62, (1.0-(GMS_Buff[client]*0.009)));

	TF2Attrib_SetByDefIndex(client, 442, (1.0+(GMS_Buff[client]*0.003)));

	TF2Attrib_SetByDefIndex(client, 443, (1.0+(GMS_Buff[client]*0.006)));

	TF2Attrib_SetByDefIndex(client, 57, (GMS_Buff[client]*0.1));

	TF2Attrib_SetByDefIndex(client, 113, (GMS_Buff[client]*0.3));

	TF2Attrib_SetByDefIndex(client, 286, (1.0+(GMS_Buff[client]*0.02)));
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
}

public void GMS_TeleFrame()
{
	if(!GMS_HasEngiSummoned)
		return;

	static float nextAt;
	if(nextAt > GetGameTime())
		return;

	nextAt = GetGameTime()+5.5;
	int client, boss;
	int entity = MaxClients+1;
	while((entity=FindEntityByClassname2(entity, "obj_teleporter")) != -1)
	{
		if(GetEntProp(entity, Prop_Send, "m_bCarried") || GetEntProp(entity, Prop_Send, "m_bPlacing") || GetEntProp(entity, Prop_Send, "m_bDisabled") || GetEntPropFloat(entity, Prop_Send, "m_flPercentageConstructed")<1)
			continue;

		client = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
		if(!IsValidClient(client))
			continue;

		boss = FF2_GetBossIndex(client);
		if(boss < 0)
		{
			if(GMS_BossType[client] != Boss_Engi)
				continue;

			boss = GMS_Owner[client];
		}
		else if(!FF2_HasAbility(boss, this_plugin_name, GMS_NAME))
		{
			continue;
		}

		static float position[3];
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", position);

		client = CreateEntityByName("trigger_push");
		CreateTimer(5.5, Timer_RemoveEntity, EntIndexToEntRef(client));
		TeleportEntity(client, position, NULL_VECTOR, NULL_VECTOR);
		TE_Particle("teleported_mvm_bot", position, _, _, client, 1, 0);

		static int teleAt;
		if(++teleAt < 4)
			continue;

		teleAt = 0;
		position[2] += 50.0;
		static char sound[MAX_SOUND_LENGTH];
		if(!FF2_RandomSound(GMS_TELEPORT, sound, MAX_SOUND_LENGTH, boss))
		{
			GMS_Summon(boss, GMS_NAME, position);
			continue;
		}

		client = GMS_Summon(boss, GMS_NAME, position);
		if(!client)
			continue;

		EmitVoiceToAll(sound, client);
		EmitVoiceToAll(sound, client);
	}
}

public Action GMS_OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(G_RoundState!=1 || !IsValidClient(client) || GMS_BossType[client]==Boss_None)
		return Plugin_Continue;

	if(client!=attacker && !IsValidClient(attacker))
	{
		if(!TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden))
			return (damagetype & DMG_FALL) ? Plugin_Handled : Plugin_Continue;

		int target = GetClientOfUserId(FF2_GetBossUserId(GMS_Owner[client]));
		if(!IsValidClient(target))
			return Plugin_Continue;

		static float position[3];
		GetClientAbsOrigin(target, position);
		TeleportEntity(client, position, NULL_VECTOR, NULL_VECTOR);

		TF2_RemoveCondition(client, TFCond_UberchargedHidden);
		static char sound[MAX_SOUND_LENGTH];
		if(FF2_RandomSound(GMS_TELEPORT, sound, MAX_SOUND_LENGTH, GMS_Owner[client]))
			EmitVoiceToAll(sound, client);

		return Plugin_Handled;
	}

	if(GMS_BossType[client]!=Boss_Buster && GMS_BossType[client]!=Boss_Mega && GMS_BossType[client]!=Boss_Normal)
		return Plugin_Continue;

	if(client == attacker)
		return Plugin_Handled;

	bool isBossAttacker = FF2_GetBossIndex(attacker)>=0;
	bool bIsTelefrag, bIsBackstab;
	static char classname[64];
	if(damagecustom == TF_CUSTOM_BACKSTAB)
	{
		bIsBackstab = true;
	}
	else if(damagecustom == TF_CUSTOM_TELEFRAG)
	{
		bIsTelefrag = true;
	}
	else if(weapon!=4095 && IsValidEntity(weapon) && weapon==GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee) && damage>1000.0)
	{
		if(GetEntityClassname(weapon, classname, sizeof(classname)) && !StrContains(classname, "tf_weapon_knife", false))
			bIsBackstab = true;
	}
	else if(!IsValidEntity(weapon) && (damagetype & DMG_CRUSH) && damage==1000.0)
	{
		bIsTelefrag = true;
	}

	int index;
	if(!isBossAttacker && IsValidEntity(weapon) && weapon>MaxClients && attacker<=MaxClients)
	{
		GetEntityClassname(weapon, classname, sizeof(classname));
		if(!HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))  //Dang spell Monoculuses
		{
			index = -1;
			classname[0] = 0;
		}
		else
		{
			index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		}
	}
	else
	{
		index = -1;
		classname[0] = 0;
	}

	//Sniper rifles aren't handled by the switch/case because of the amount of reskins there are
	if(!StrContains(classname, "tf_weapon_sniperrifle"))
	{
		if(index == 752)  //Hitman's Heatmaker
		{
			float focus = 10+(GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage")/10);
			if(TF2_IsPlayerInCondition(attacker, TFCond_FocusBuff))
				focus /= 3;

			float rage = GetEntPropFloat(attacker, Prop_Send, "m_flRageMeter");
			SetEntPropFloat(attacker, Prop_Send, "m_flRageMeter", (rage+focus>100) ? 100.0 : rage+focus);
		}
		else if(index!=230 && index!=402 && index!=526 && index!=30665)  //Sydney Sleeper, Bazaar Bargain, Machina, Shooting Star
		{
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
		}

		if(!(damagetype & DMG_CRIT))
		{
			if(TF2_IsPlayerInCondition(attacker, TFCond_CritCola) || TF2_IsPlayerInCondition(attacker, TFCond_Buffed))
			{
				damage *= UnofficialFF2 ? 2.222 : 1.7;
			}
			else if(index == 230)  //Sydney Sleeper
			{
				damage *= 2.4;
			}
			else
			{
				damage *= UnofficialFF2 ? 3.0 : 2.9;
			}
			return Plugin_Changed;
		}
	}
	else if(!StrContains(classname, "tf_weapon_compound_bow"))
	{
		if(UnofficialFF2)
		{
			damage *= 1.25;
			return Plugin_Changed;
		}
	}
	else if(!StrContains(classname, "tf_weapon_rocketlauncher"))
	{
		if(!UnofficialFF2)
		{
			int flags = GetEntityFlags(client);
			if(!(flags & FL_ONGROUND) && !(flags & FL_INWATER))
			{
				if(!(damagetype & DMG_CRIT))
				{	
					damagetype |= DMG_CRIT;
					damage *= 0.54;	// simulate mini
					return Plugin_Changed;
				}
			}
		}
	}

	switch(index)
	{
		case 61, 1006:  //Ambassador, Festive Ambassador
		{
			if(UnofficialFF2 && damagecustom==TF_CUSTOM_HEADSHOT)
			{
				damage = 85.0;  //Final damage 255
				return Plugin_Changed;
			}
		}
		case 132, 266, 482, 1082:  //Eyelander, HHHH, Nessie's Nine Iron, Festive Eyelander
		{
			if(!TF2_IsPlayerInCondition(attacker, TFCond_DemoBuff))
				TF2_AddCondition(attacker, TFCond_DemoBuff, -1.0);

			int decapitations = GetEntProp(attacker, Prop_Send, "m_iDecapitations");
			int health = GetClientHealth(attacker);
			SetEntProp(attacker, Prop_Send, "m_iDecapitations", decapitations+1);
			SetEntityHealth(attacker, health+15);
			TF2_AddCondition(attacker, TFCond_SpeedBuffAlly, 0.01);
		}
		case 214:  //Powerjack
		{
			int health = GetClientHealth(attacker);
			int newhealth = UnofficialFF2 ? health+25 : health+50;
			if(newhealth <= GetEntProp(attacker, Prop_Data, "m_iMaxHealth"))  //No overheal allowed
				SetEntityHealth(attacker, newhealth);
		}
		case 310:  //Warrior's Spirit
		{
			if(UnofficialFF2)
			{
				int health = GetClientHealth(attacker);
				int newhealth = health+50;
				if(newhealth <= GetEntProp(attacker, Prop_Data, "m_iMaxHealth"))  //No overheal allowed
					SetEntityHealth(attacker, newhealth);
			}
		}
		case 317:  //Candycane
		{
			int healthpack = CreateEntityByName("item_healthkit_small");
			float position[3];
			GetClientAbsOrigin(client, position);
			position[2] += 20.0;
			if(IsValidEntity(healthpack))
			{
				DispatchKeyValue(healthpack, "OnPlayerTouch", "!self,Kill,,0,-1");
				DispatchSpawn(healthpack);
				SetEntProp(healthpack, Prop_Send, "m_iTeamNum", GetClientTeam(attacker), 4);
				SetEntityMoveType(healthpack, MOVETYPE_VPHYSICS);
				float velocity[3];//={float(GetRandomInt(-10, 10)), float(GetRandomInt(-10, 10)), 50.0};  //Q_Q
				velocity[0] = float(GetRandomInt(-10, 10));
				velocity[1] = float(GetRandomInt(-10, 10));
				velocity[2] = 50.0;  //I did this because setting it on the creation of the vel variable was creating a compiler error for me.
				TeleportEntity(healthpack, position, NULL_VECTOR, velocity);
				SetEntPropEnt(healthpack, Prop_Send, "m_hOwnerEntity", attacker);
			}
		}
		case 327:  //Claidheamh Mor
		{
			if(UnofficialFF2)
			{
				float charge = GetEntPropFloat(attacker, Prop_Send, "m_flChargeMeter");
				if(charge+25.0 >= 100.0)
				{
					SetEntPropFloat(attacker, Prop_Send, "m_flChargeMeter", 100.0);
				}
				else
				{
					SetEntPropFloat(attacker, Prop_Send, "m_flChargeMeter", charge+25.0);
				}
			}
		}
		case 357:  //Half-Zatoichi
		{
			int health = GetClientHealth(attacker);
			int maximum = GetEntProp(attacker, Prop_Data, "m_iMaxHealth");
			int max2 = RoundToFloor(maximum*2.0);
			int newhealth;
			if(!UnofficialFF2)
			{
				newhealth = health+35;
				if(health < maximum)
				{
					if(newhealth+25 > maximum)
						newhealth = maximum+25;

					SetEntityHealth(attacker, newhealth);
				}
				if(TF2_IsPlayerInCondition(attacker, TFCond_OnFire))
					TF2_RemoveCondition(attacker, TFCond_OnFire);
			}
			else if(GetEntProp(weapon, Prop_Send, "m_bIsBloody"))	// Less effective used more than once
			{
				newhealth = health+25;
				if(health < max2)
				{
					if(newhealth > max2)
						newhealth = max2;

					SetEntityHealth(attacker, newhealth);
				}
			}
			else	// Most effective on first hit
			{
				newhealth = health + RoundToFloor(maximum/2.0);
				if(health < max2)
				{
					if(newhealth > max2)
						newhealth = max2;

					SetEntityHealth(attacker, newhealth);
				}
				if(TF2_IsPlayerInCondition(attacker, TFCond_OnFire))
					TF2_RemoveCondition(attacker, TFCond_OnFire);
			}
			SetEntProp(weapon, Prop_Send, "m_bIsBloody", 1);
			if(GetEntProp(attacker, Prop_Send, "m_iKillCountSinceLastDeploy") < 1)
				SetEntProp(attacker, Prop_Send, "m_iKillCountSinceLastDeploy", 1);
		}
		case 528:  //Short Circuit
		{
			if(!UnofficialFF2)
			{
				TF2_StunPlayer(client, 2.0, 0.0, TF_STUNFLAGS_SMALLBONK|TF_STUNFLAG_NOSOUNDOREFFECT, attacker);
				EmitSoundToAll("weapons/barret_arm_zap.wav", client);
				EmitSoundToClient(client, "weapons/barret_arm_zap.wav");
			}
		}
		case 593:  //Third Degree
		{
			int healers[MAXTF2PLAYERS];
			int healerCount;
			for(int healer; healer<=MaxClients; healer++)
			{
				if(IsValidClient(healer) && IsPlayerAlive(healer) && (GetHealingTarget(healer, true)==attacker))
				{
					healers[healerCount] = healer;
					healerCount++;
				}
			}

			for(int healer; healer<healerCount; healer++)
			{
				if(IsValidClient(healers[healer]) && IsPlayerAlive(healers[healer]))
				{
					int medigun = GetPlayerWeaponSlot(healers[healer], TFWeaponSlot_Secondary);
					if(IsValidEntity(medigun))
					{
						static char medigunClassname[64];
						GetEntityClassname(medigun, medigunClassname, sizeof(medigunClassname));
						if(StrEqual(medigunClassname, "tf_weapon_medigun", false))
						{
							float uber = GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel")+(0.1/healerCount);
							if(uber > 1.0)
								uber = 1.0;

							SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", uber);
						}
					}
				}
			}
		}
		case 594:  //Phlogistinator
		{
			if(UnofficialFF2 && !TF2_IsPlayerInCondition(attacker, TFCond_CritMmmph))
			{
				damage /= 2.0;
				return Plugin_Changed;
			}
		}
	}

	if(bIsBackstab)
	{
		damage = GMS_BossType[client]==Boss_Mega ? GMS_Health[client]*0.06 : GMS_Health[client]*0.24;
		damagetype |= DMG_CRIT|DMG_PREVENT_PHYSICS_FORCE;
		damagecustom = 0;

		EmitSoundToClient(client, "player/crit_received3.wav", _, _, _, _, 0.7, _, _, _, _, false);
		EmitSoundToClient(attacker, "player/crit_received3.wav", _, _, _, _, 0.7, _, _, _, _, false);
		SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime()+1.5);
		SetEntPropFloat(attacker, Prop_Send, "m_flNextAttack", GetGameTime()+1.5);

		if(UnofficialFF2)
		{
			int viewmodel = GetEntPropEnt(attacker, Prop_Send, "m_hViewModel");
			if(viewmodel>MaxClients && IsValidEntity(viewmodel) && TF2_GetPlayerClass(attacker)==TFClass_Spy)
			{
				int animation = 42;
				switch(index)
				{
					case 225, 356, 423, 461, 574, 649, 1071, 30758:  //Your Eternal Reward, Conniver's Kunai, Saxxy, Wanga Prick, Big Earner, Spy-cicle, Golden Frying Pan, Prinny Machete
						animation = 16;

					case 638:  //Sharp Dresser
						animation = 32;
				}
				SetEntProp(viewmodel, Prop_Send, "m_nSequence", animation);
			}
		}

		if(!UnofficialFF2 || (index!=225 && index!=574))  //Your Eternal Reward, Wanga Prick
		{
			EmitSoundToClient(client, "player/spy_shield_break.wav", _, _, _, _, 0.7, _, _, _, _, false);
			EmitSoundToClient(attacker, "player/spy_shield_break.wav", _, _, _, _, 0.7, _, _, _, _, false);
		}

		switch(index)
		{
			case 225, 574:	//Your Eternal Reward, Wanga Prick
			{
				CreateTimer(0.3, GMS_Disguise, GetClientUserId(attacker), TIMER_FLAG_NO_MAPCHANGE);
			}
			case 356:	//Conniver's Kunai
			{
				int health = GetClientHealth(attacker)+100;
				if(health > 270)
					health = 270;

				SetEntityHealth(attacker, health);
			}
			case 461:	//Big Earner
			{
				if(UnofficialFF2)
				{
					SetEntPropFloat(attacker, Prop_Send, "m_flCloakMeter", 100.0);  //Full cloak
					TF2_AddCondition(attacker, TFCond_SpeedBuffAlly, 3.0);  //Speed boost
				}
			}
		}
		return Plugin_Changed;
	}

	if(bIsTelefrag)
	{
		damagecustom = 0;
		if(!IsPlayerAlive(attacker))
		{
			damage = 1.0;
			return Plugin_Changed;
		}
		damage = (isBossAttacker ? float(GMS_Health[client]) : UnofficialFF2 ? 5000.0 : 9001.0);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action GMS_OnTakeDamageAlive(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(G_RoundState!=1 || !IsValidClient(client) || GMS_BossType[client]!=Boss_Buster)
		return Plugin_Continue;

	if(TF2_IsPlayerInCondition(client, TFCond_UberchargedCanteen) || damage<GetClientHealth(client))
		return Plugin_Continue;

	TF2_AddCondition(client, TFCond_UberchargedCanteen, 9.9);
	TF2_AddCondition(client, TFCond_HalloweenKartNoTurn, 9.9);
	SDKHook(client, SDKHook_PreThink, GMS_ExplodeStartThink);
	SetEntityHealth(client, 1);
	return Plugin_Handled;
}

public Action GMS_Disguise(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(IsValidClient(client, false))
		RandomlyDisguise(client);

	return Plugin_Continue;
}

public Action GMS_HookSound(int clients[64], int &numClients, char sound[PLATFORM_MAX_PATH], int &client, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if(!IsValidClient(client) || GMS_BossType[client]==Boss_None)
		return Plugin_Continue;

	if(StrContains(sound, "announcer")!=-1) return Plugin_Continue;
	if(StrContains(sound, "norm")!=-1) return Plugin_Continue;
	if(StrContains(sound, "mght")!=-1) return Plugin_Continue;
	if(StrContains(sound, "vo/", false)==-1) return Plugin_Continue;
	if(TF2_IsPlayerInCondition(client, TFCond_Disguised)) return Plugin_Continue;

	if(StrContains(sound, "player/footsteps/", false) != -1)
	{	
		if(GMS_BossType[client]!=Boss_Buster && GMS_BossType[client]!=Boss_Normal && GMS_BossType[client]!=Boss_Mega)
			return Plugin_Stop;

		Format(sound, sizeof(sound), "mvm/giant_common/giant_common_step_0%i.wav", GetRandomInt(1, 8));
		pitch = GetRandomInt(95, 100);
		EmitSoundToAll(sound, client, _, _, _, 0.25, pitch);
		return Plugin_Changed;
	}

	if(GMS_BossType[client] == Boss_Buster) // Block voice lines.
	{
		if(StrContains(sound, "demo", false) != -1) 
			return Plugin_Stop;

		return Plugin_Continue;
	}
		
	if(volume == 0.99997) return Plugin_Continue;

	ReplaceString(sound, sizeof(sound), "vo/", (TF2_GetPlayerClass(client)==TFClass_Medic || TF2_GetPlayerClass(client)==TFClass_Engineer || (GMS_BossType[client]!=Boss_Normal && GMS_BossType[client]!=Boss_Mega)) ? "vo/mvm/norm/" : "vo/mvm/mght/", false);
	char classname[10], classname_mvm[20];
	GMS_ClassName(TF2_GetPlayerClass(client), classname, sizeof(classname));
	Format(classname_mvm, sizeof(classname_mvm), (TF2_GetPlayerClass(client)==TFClass_Medic || TF2_GetPlayerClass(client)==TFClass_Engineer || (GMS_BossType[client]!=Boss_Normal && GMS_BossType[client]!=Boss_Mega)) ? "%s_mvm" : "%s_mvm_m", classname);
	ReplaceString(sound, sizeof(sound), classname, classname_mvm, false);
	char temp[MAX_MODEL_LENGTH];
	Format(temp, sizeof(temp), "sound/%s", sound);
	PrecacheSound(sound);
	return Plugin_Changed;
}

static void GMS_ClassName(TFClassType class, char[] name, int maxlen)
{
	switch(class)
	{
		case TFClass_Scout: strcopy(name, maxlen, "scout");
		case TFClass_Soldier: strcopy(name, maxlen, "soldier");
		case TFClass_Pyro: strcopy(name, maxlen, "pyro");
		case TFClass_DemoMan: strcopy(name, maxlen, "demoman");
		case TFClass_Heavy: strcopy(name, maxlen, "heavy");
		case TFClass_Engineer: strcopy(name, maxlen, "engineer");
		case TFClass_Medic: strcopy(name, maxlen, "medic");
		case TFClass_Sniper: strcopy(name, maxlen, "sniper");
		case TFClass_Spy: strcopy(name, maxlen, "spy");
	}
}

public void GMS_ExplodeStartThink(int client)
{
	if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1)
		return;

	SDKUnhook(client, SDKHook_PreThink, GMS_ExplodeStartThink);
	GMS_ExplodeStart(client);
}

Action GMS_Rage(int client)
{
	if(!IsValidClient(client) || GMS_BossType[client]!=Boss_Buster || GMS_ExplodeAt[client]>0 || !IsPlayerAlive(client))
		return Plugin_Continue;

	if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity")!=-1 && !TF2_IsPlayerInCondition(client, TFCond_UberchargedCanteen) && !TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden))
		GMS_ExplodeStart(client);

	return Plugin_Handled;
}

static void GMS_ExplodeStart(int client)
{
	GMS_ExplodeAt[client] = GetGameTime()+2.1;
	TF2_RemoveAllWeapons(client);
	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", SpawnWeapon(client, "tf_weapon_stickbomb", 307, 101, 14, "252 ; 0 ; 329 ; 0", false));
	SetEntityMoveType(client, MOVETYPE_NONE);
	EmitSoundToAll(GMS_DETONATE, client);
	FakeClientCommand(client, "taunt");
	TF2_AddCondition(client, TFCond_UberchargedCanteen, 9.9);
	SDKHook(client, SDKHook_PreThink, GMS_ExplodeThink);
}

public void GMS_ExplodeThink(int client)
{
	if(GMS_ExplodeAt[client] > GetGameTime())
		return;

	GMS_ExplodeAt[client] = 0.0;
	SDKUnhook(client, SDKHook_PreThink, GMS_ExplodeThink);

	static float pos[3], pos2[3];
	GetClientAbsOrigin(client, pos);
	int target = 1;
	for(; target<=MaxClients; target++)
	{
		if(!IsValidClient(target) || !IsPlayerAlive(target))
			continue;

		GetClientAbsOrigin(target, pos2);
		if(GetVectorDistance(pos, pos2) < 300)
			SDKHooks_TakeDamage(target, client, client, 750.0, DMG_CRUSH|DMG_BLAST);
	}

	for(target=MAXENTITIES; target>MaxClients; target--)
	{
		if(!IsValidEntity(target))
			continue;

		static char classname[20];
		GetEntityClassname(target, classname, sizeof(classname));
		if(!StrEqual(classname, "obj_sentrygun", false) && !StrEqual(classname, "obj_dispenser", false) && !StrEqual(classname, "obj_teleporter", false))
			continue;

		GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
		if(GetVectorDistance(pos, pos2) > 300)
			continue;

		SetVariantInt(2500);
		AcceptEntityInput(target, "RemoveHealth");
	}

	TE_Particle("fluidSmokeExpl_ring_mvm", pos);
	ForcePlayerSuicide(client);
	RequestFrame(GMS_RemoveRagdoll, GetClientUserId(client));
}

public void GMS_RemoveRagdoll(int userid)
{
	int client = GetClientOfUserId(userid);
	if(!IsValidClient(client))
		return;

	int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if(ragdoll>MaxClients && IsValidEntity(ragdoll))
		AcceptEntityInput(ragdoll, "Kill");
}

Action GMS_Goomba(int victim, float &damageMultiplier, float &jumpPower)
{
	if(GMS_BossType[victim] == Boss_None)
		return Plugin_Continue;

	damageMultiplier = 0.05;
	jumpPower = 300.0;
	return Plugin_Changed;
}

void GMS_Clean()
{
	GMS_HasEngiSummoned = false;
	GMS_HasEngisSummoned = false;
	GMS_HasBusterSummoned = false;
	GMS_WasBombEnabled = false;
	GMS_BombEnabled = false;

	for(int client; client<MAXTF2PLAYERS; client++)
	{
		GMS_Buff[client] = 0;

		if(IsValidClient(client))
		{
			GMS_Death(client, 0, true);
			continue;
		}

		GMS_Owner[client] = -1;
		GMS_BossType[client] = Boss_None;
		GMS_IsUpgraded[client] = false;
	}
}

/*
	Sound Effects
*/

void GME_Setup(int client, int boss)
{
	static char classname[MAX_CLASSNAME_LENGTH];
	GetArgS(boss, GME_NAME, "classname", 1, classname, MAX_CLASSNAME_LENGTH);
	if(classname[0])
	{
		static char attributes[MAX_ATTRIBUTE_LENGTH];
		GetArgS(boss, GME_NAME, "attributes", 3, attributes, MAX_ATTRIBUTE_LENGTH);
		SpawnWeapon(client, classname, RoundFloat(GetArgI(boss, GME_NAME, "index", 2)), 101, UnofficialFF2 ? 14 : 5, attributes, view_as<bool>(RoundFloat(GetArgI(boss, GME_NAME, "visible", 4))));
	}

	if(GME_Enabled)
		return;

	GME_Boss = boss;
	GME_Team = TF2_GetClientTeam(client);
	GME_Enabled = true;
}

void GME_Death(int client, int flags)
{
	if(!GME_Enabled || (flags & TF_DEATHFLAG_DEADRINGER) || !IsValidClient(client))
		return;

	static char sound[MAX_SOUND_LENGTH];
	switch(GMS_BossType[client])
	{
		case Boss_Engi:
		{
			int target = 1;
			for(; target<=MaxClients; target++)
			{
				if(IsValidClient(target) && target!=client && GMS_BossType[target]==Boss_Engi)
					return;
			}

			bool found;
			int entity = MaxClients+1;
			while((entity=FindEntityByClassname2(entity, "obj_teleporter")) != -1)
			{
				target = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
				if(IsValidClient(target) && TF2_GetClientTeam(target)==GME_Team)
				{
					if(!FF2_RandomSound(GMS_HasEngisSummoned ? GME_ENGISDEAD2 : GME_ENGIDEAD2, sound, MAX_SOUND_LENGTH, GME_Boss))
						break;

					for(target=1; target<=MaxClients; target++)
					{
						if(IsValidClient(target) && TF2_GetClientTeam(target)!=GME_Team)
							ClientCommand(target, "playgamesound \"%s\"", sound);
					}
					found = true;
					break;
				}
			}

			if(!found)
			{
				if(FF2_RandomSound(GMS_HasEngisSummoned ? GME_ENGISDEAD : GME_ENGIDEAD, sound, MAX_SOUND_LENGTH, GME_Boss))
				{
					for(target=1; target<=MaxClients; target++)
					{
						if(IsValidClient(target) && TF2_GetClientTeam(target)!=GME_Team)
							ClientCommand(target, "playgamesound \"%s\"", sound);
					}
				}
			}

			GMS_HasEngisSummoned = false;
		}
		case Boss_Spy:
		{
			for(int target=1; target<=MaxClients; target++)
			{
				if(IsValidClient(target) && target!=client && GMS_BossType[target]==Boss_Spy)
					return;
			}

			if(!FF2_RandomSound(GME_SPIESDEAD, sound, MAX_SOUND_LENGTH, GME_Boss))
				return;
	
			for(int target=1; target<=MaxClients; target++)
			{
				if(IsValidClient(target) && TF2_GetClientTeam(target)!=GME_Team)
					ClientCommand(target, "playgamesound \"%s\"", sound);
			}
		}
		case Boss_Buster:
		{
			if(FF2_RandomSound(GME_BUSTERDEAD, sound, MAX_SOUND_LENGTH, GME_Boss))
				EmitSoundToAll(sound);
		}
		case Boss_None:
		{
			if(GetClientTeam(client) == view_as<int>(GME_Team))
				return;

			static float timer;
			static int streak;
			float engineTime = GetEngineTime();
			if(timer < engineTime)
			{
				timer = engineTime+5.0;
				streak = 0;
				return;
			}

			if(streak < 3)
			{
				streak++;
				timer += 1.0;
				return;
			}

			streak = 0;
			timer = 0.0;
			if(!FF2_RandomSound(GME_KSPREE, sound, MAX_SOUND_LENGTH, GME_Boss))
				return;

			for(int target=1; target<=MaxClients; target++)
			{
				if(IsValidClient(target) && TF2_GetClientTeam(target)!=GME_Team)
					ClientCommand(target, "playgamesound \"%s\"", sound);
			}
		}
	}
}

/*Action GME_RunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	#if defined DDCOMPILE
	if(!GME_Enabled || !IsValidClient(client))
		return Plugin_Continue;

	int boss = FF2_GetBossIndex(client);
	if(boss<0 || !FF2_HasAbility(boss, this_plugin_name, GME_NAME))
		return Plugin_Continue;

	static bool holding[MAXTF2PLAYERS], mode[MAXTF2PLAYERS];
	if(holding[client])
	{
		if(!(buttons & IN_RELOAD))
			holding[client] = false;

		return Plugin_Continue;
	}

	if(!(buttons & IN_RELOAD))
		return Plugin_Continue;

	holding[client] = true;
	mode[client] = !mode[client];
	DD_SetDisabled(client, mode[client], !mode[client], true);
	#endif
	return Plugin_Continue;
}*/

Action GME_Broadcast(Event event)
{
	if(!GME_Enabled)
		return Plugin_Continue;

	static char sound[PLATFORM_MAX_PATH];
	event.GetString("sound", sound, sizeof(sound));
	if(!StrContains(sound, "Game.Your", false) || !StrContains(sound, "CaptureFlag.", false) || StrEqual(sound, "Game.Stalemate", false) || !StrContains(sound, "Announcer.AM_RoundStartRandom", false))
		return Plugin_Handled;

	return Plugin_Continue;
}

void GME_Clean(TFTeam winner)
{
	if(GME_Enabled)
		CreateTimer(winner==GME_Team ? 5.0 : 1.5, GME_Gameover, winner, TIMER_FLAG_NO_MAPCHANGE);
}

public Action GME_Gameover(Handle timer, TFTeam winner)
{
	GME_Enabled = false;
	if(winner==TFTeam_Spectator || winner==TFTeam_Unassigned)
		return Plugin_Continue;

	static char sound[MAX_SOUND_LENGTH];
	if(FF2_RandomSound(winner==GME_Team ? GME_WIN : GME_LOSE, sound, MAX_SOUND_LENGTH, GME_Boss))
	{
		for(int target=1; target<=MaxClients; target++)
		{
			if(IsValidClient(target) && TF2_GetClientTeam(target)!=GME_Team)
				ClientCommand(target, "playgamesound \"%s\"", sound);
		}
	}
	return Plugin_Continue;
}

/*
	Revive Markers
*/

void GMR_Setup(int client, int boss)
{
	if(GMR_Team == TFTeam_Spectator)
		return;

	bool first;
	int team = GetClientTeam(client)==view_as<int>(TFTeam_Blue) ? view_as<int>(TFTeam_Red) : view_as<int>(TFTeam_Blue);
	if(GMR_Team == TFTeam_Unassigned)
	{
		GMR_Team = view_as<TFTeam>(team);
		first = true;
	}
	else if(GMR_Team != view_as<TFTeam>(team)) // Both teams have a revive marker boss
	{
		GMR_Team = TFTeam_Spectator; // Randomize
	}
	else
	{
		return;
	}

	team -= 2;
	GMR_Lifetime[team] = GetArgF(boss, GMR_NAME, "lifetime", 1, 60.0, 0);
	GMR_Limit[team] = RoundFloat(GetArgF(boss, GMR_NAME, "limit", 2, 3.0, 2));
	GMR_Hide[team] = RoundFloat(GetArgI(boss, GMR_NAME, "hide", 3, 1.0));

	if(!first)
		return;

	char sound[MAX_SOUND_LENGTH];
	bool hasSound = FF2_RandomSound(GMR_INTRO, sound, MAX_SOUND_LENGTH, boss);
	for(int target=1; target<=MaxClients; target++)
	{
		if(!IsValidClient(target) || IsFakeClient(target))
			continue;

		if(GMR_Team!=TFTeam_Spectator && GMR_Team!=TF2_GetClientTeam(target))
			continue;

		SetHudTextParams(-1.0, 0.67, 4.0, 255, 0, 0, 255);
		ShowHudText(target, -1, "Medics can revive players this round!");
		if(hasSound)
			ClientCommand(target, "playgamesound \"%s\"", sound);
	}
}

void GMR_Death(int client, int flags, int attacker)
{
	if(GMR_Team==TFTeam_Unassigned || (flags & TF_DEATHFLAG_DEADRINGER) || !IsValidClient(client))
		return;

	switch(GMR_Team)
	{
		case TFTeam_Spectator:
		{
			int team;
			if(IsValidClient(attacker))
			{
				team = GetClientTeam(attacker)-2;
				if(team && team!=1)
					team = GetRandomInt(0, 1);
			}
			else
			{
				team = GetRandomInt(0, 1);
			}
			GMR_MarkerCheck(client, team);
		}
		case TFTeam_Red:
		{
			GMR_MarkerCheck(client, 0);
		}
		case TFTeam_Blue:
		{
			GMR_MarkerCheck(client, 1);
		}
	}
}

static void GMR_MarkerCheck(int client, int team)
{
	if(GMR_Limit[team]>0 && GMR_Revives[client][team]>=GMR_Limit[team])
		return;

	if(GME_Enabled)
	{
		static char sound[MAX_SOUND_LENGTH];
		if(FF2_RandomSound(GME_DEATH, sound, MAX_SOUND_LENGTH, GME_Boss))
			EmitSoundToClient(client, sound);
	}

	ChangeClientTeam(client, team+2);
	GMR_Marker(client, team, GMR_Limit[team]-GMR_Revives[client][team]);
}

static void GMR_Marker(int client, int team, int revives)
{
	int entity = CreateEntityByName("entity_revive_marker");
	if(entity == -1)
		return;

	SetEntPropEnt(entity, Prop_Send, "m_hOwner", client); // client index 
	SetEntProp(entity, Prop_Send, "m_nSolidType", 2); 
	SetEntProp(entity, Prop_Send, "m_usSolidFlags", 8); 
	SetEntProp(entity, Prop_Send, "m_fEffects", 16); 
	SetEntProp(entity, Prop_Send, "m_iTeamNum", team+2); // client team 
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1); 
	SetEntProp(entity, Prop_Send, "m_bSimulatedEveryTick", 1);
	SetEntProp(entity, Prop_Send, "m_nRevives", 11-revives);
	SetEntDataEnt2(client, FindSendPropInfo("CTFPlayer", "m_nForcedSkin")+4, entity);
	int class = GetEntProp(client, Prop_Send, "m_iDesiredPlayerClass");
	if(!class)
		class = view_as<int>(TFClass_Scout);

	SetEntProp(entity, Prop_Send, "m_nBody", class-1); // character hologram that is shown
	SetEntProp(entity, Prop_Send, "m_nSequence", 1); 
	SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 1.0);
	SetEntProp(entity, Prop_Data, "m_iInitialTeamNum", team+2);
	SDKHook(entity, SDKHook_SetTransmit, GMR_None);

	if(team)
		SetEntityRenderColor(entity, 0, 0, 255); // make the BLU Revive Marker distinguishable from the red one

	DispatchSpawn(entity);
	GMR_EntRef[client] = EntIndexToEntRef(entity);
	GMR_MoveAt[client] = GetEngineTime()+0.05;
	if(GMR_Lifetime[team] > 0)
	{
		GMR_GoneAt[client] = GetEngineTime()+GMR_Lifetime[team];
	}
	else
	{
		GMR_GoneAt[client] = FAR_FUTURE;
	}

	SDKHook(client, SDKHook_PreThink, GMR_MarkerThink);
}

public void GMR_MarkerThink(int client)
{
	if(GMR_MoveAt[client] < GetEngineTime())
	{
		GMR_MoveAt[client] = FAR_FUTURE;
		int entity = EntRefToEntIndex(GMR_EntRef[client]);
		if(!GMR_IsMarker(entity)) // Oh fiddlesticks, what now..
		{
			SDKUnhook(client, SDKHook_PreThink, GMR_MarkerThink);
			return;
		}

		// get position to teleport the Marker to
		static float position[3];
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", position);
		TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
		SDKHook(entity, SDKHook_SetTransmit, GMR_Transmit);
		SDKUnhook(entity, SDKHook_SetTransmit, GMR_None);
	}
	else if(GMR_GoneAt[client] < GetEngineTime())
	{
		SDKUnhook(client, SDKHook_PreThink, GMR_MarkerThink);
		int entity = EntRefToEntIndex(GMR_EntRef[client]);
		if(GMR_IsMarker(entity))
			AcceptEntityInput(entity, "Kill");
	}
}

public Action GMR_Transmit(int entity, int client)
{
	int team = GetEntProp(entity, Prop_Send, "m_iTeamNum");
	if(team<2 || team>3 || !GMR_Hide[team-2] || !IsPlayerAlive(client) || GetClientTeam(client)<=view_as<int>(TFTeam_Spectator))
		return Plugin_Continue;

	if(team != GetClientTeam(client))
		return Plugin_Handled;

	if(GMR_Hide[team-2]==2 && TF2_GetPlayerClass(client)!=TFClass_Medic)
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action GMR_None(int entity, int client)
{
	return Plugin_Handled;
}

static bool GMR_IsMarker(int marker)
{
	if(!IsValidEntity(marker))
		return false;

	static char buffer[128];
	GetEntityClassname(marker, buffer, sizeof(buffer));
	return StrEqual(buffer, "entity_revive_marker", false);
}

void GMR_Revive(int client)
{
	if(GMR_Team==TFTeam_Unassigned || !IsValidClient(client))
		return;

	Event points = CreateEvent("player_escort_score", true);
	points.SetInt("player", client);
	points.SetInt("points", -2);
	points.Fire();

	int entity = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if(entity <= MaxClients)
		return;

	static char classname[MAX_CLASSNAME_LENGTH];
	GetEdictClassname(entity, classname, MAX_CLASSNAME_LENGTH);
	if(!StrEqual(classname, "tf_weapon_medigun"))
		return;

	entity = GetEntPropEnt(entity, Prop_Send, "m_hHealingTarget");
	if(entity <= MaxClients)
		return;

	entity = GetEntPropEnt(entity, Prop_Send, "m_hOwner");
	if(!IsValidClient(entity))
		return;

	int team = GetClientTeam(entity)-2;
	if(team && team!=1)
		return;

	GMR_Revives[entity][team]++;
	GMS_Upgrade(entity, 0);

	if(GMR_Limit[team] < 1)
		return;

	switch(GMR_Limit[team]-GMR_Revives[entity][team])
	{
		case 0:
		{
			SetHudTextParams(-1.0, 0.67, 4.0, 255, 0, 0, 255);
			ShowHudText(entity, -1, "You can no longer be revived!");
		}
		case 1:
		{
			SetHudTextParams(-1.0, 0.67, 4.0, 255, 64, 64, 255);
			ShowHudText(entity, -1, "You can be revived 1 more time!");
		}
		default:
		{
			SetHudTextParams(-1.0, 0.67, 4.0, 255, 128, 128, 255);
			ShowHudText(entity, -1, "You can be revived %i more times!", GMR_Limit[team]-GMR_Revives[entity][team]);
		}
	}
}

void GMR_Clean()
{
	GMR_Team = TFTeam_Unassigned;
	for(int client; client<MAXTF2PLAYERS; client++)
	{
		GMR_GoneAt[client] = 0.0;
		GMR_Revives[client][0] = 0;
		GMR_Revives[client][1] = 0;
	}
}

/*
	Combined Abilities: Because damn that 14 limit
*/

void GMA_Setup(int client, int boss)
{
	static char classname[MAX_CLASSNAME_LENGTH];
	GetArgS(boss, GMA_NAME, "classname", 1, classname, MAX_CLASSNAME_LENGTH);
	if(classname[0])
	{
		static char attributes[MAX_ATTRIBUTE_LENGTH];
		GetArgS(boss, GMA_NAME, "attributes", 3, attributes, MAX_ATTRIBUTE_LENGTH);
		SpawnWeapon(client, classname, RoundFloat(GetArgI(boss, GMA_NAME, "index", 2)), 101, UnofficialFF2 ? 14 : 5, attributes, view_as<bool>(RoundFloat(GetArgI(boss, GMA_NAME, "visible", 4))));
	}

	if(!GME_Enabled)
	{
		GME_Boss = boss;
		GME_Team = TF2_GetClientTeam(client);
		GME_Enabled = true;
	}

	if(GMR_Team != TFTeam_Spectator)
	{
		bool first;
		int team = GetClientTeam(client)==view_as<int>(TFTeam_Blue) ? view_as<int>(TFTeam_Red) : view_as<int>(TFTeam_Blue);
		if(GMR_Team == TFTeam_Unassigned)
		{
			GMR_Team = view_as<TFTeam>(team);
			first = true;
		}
		else if(GMR_Team != view_as<TFTeam>(team)) // Both teams have a revive marker boss
		{
			GMR_Team = TFTeam_Spectator; // Randomize
		}
		else
		{
			return;
		}

		team -= 2;
		GMR_Lifetime[team] = GetArgF(boss, GMA_NAME, "lifetime", 11, 60.0, 0);
		GMR_Limit[team] = RoundFloat(GetArgF(boss, GMA_NAME, "limit", 12, 3.0, 2));
		GMR_Hide[team] = RoundFloat(GetArgI(boss, GMA_NAME, "hide", 13, 1.0));

		if(!first)
			return;

		char sound[MAX_SOUND_LENGTH];
		bool hasSound = FF2_RandomSound(GMR_INTRO, sound, MAX_SOUND_LENGTH, boss);
		for(int target=1; target<=MaxClients; target++)
		{
			if(!IsValidClient(target) || IsFakeClient(target))
				continue;

			if(GMR_Team!=TFTeam_Spectator && GMR_Team!=TF2_GetClientTeam(target))
				continue;

			SetHudTextParams(-1.0, 0.67, 4.0, 255, 0, 0, 255);
			ShowHudText(target, -1, "Medics can revive players this round!");
			if(hasSound)
				ClientCommand(target, "playgamesound \"%s\"", sound);
		}
	}
}