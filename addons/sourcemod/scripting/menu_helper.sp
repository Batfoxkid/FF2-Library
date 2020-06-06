
/*
	"menu_base"
	{
		"button"		"reload"
		"max abilities"	"6"
		"menu name"		"Current [ENERGY] : %i\nSelect Your Powerup."
		"hud format"	"[ENERGY] : %i"	
		"damage taken"		"1000"
		"damage pts"		"45"
		"life loss"			"70"
		"loss mult"			"3 - 5 - 10"
		"max pts"			"9001"
		"gain per rage"	"60"
		"gain per kill"	"50" 
		
		"hook"
		{
			"num"		"3"
			"1"
			{
				"name"		"ability_name"
				
				"rage title"	"Anti-Medigun"
				"rage info"		"ENERGY : 120 Stamina.\nCooldown : 20 sec"
				"rage cost"		"120"
				"rage cooldown"	"20.0"
			
				"plugin_name"	"plugin_name"
			}
			"2"
			{
				"name"		"ability_name"
				...
				..
				"plugin_name"	"plugin_name"
			}
			"3"
			{
				"name"		"ability_name"
				...
				..
				"plugin_name"	"plugin_name"
			}
		}
	}
*/

methodmap PointsMap < StringMap {
	public PointsMap(int maxpts) {
		StringMap map = new StringMap();
		
		map.SetValue("max", maxpts);
		map.SetValue("points", 0);
		map.SetValue("damage", 0);
		map.SetValue("stack", 0);
		
		return view_as<PointsMap>(map);
	}
	
	public void Purge() {
		if(!this)
			return;
		delete this;
	}
	
	property int max {
		public get() {
			int val;
			return this.GetValue("max", val) ? val:9001;
		}
	}
	
	property int points {
		public get() {
			int val;
			return this.GetValue("points", val) ? val:0;
		}
		public set(int val) {
			this.SetValue("points", val);
		}
	}
	
	property int damage {
		public get() {
			int val;
			return this.GetValue("damage", val) ? val:0;
		}
		public set(int val) {
			this.SetValue("damage", val);
		}
	}
	
	property int stack {
		public get() {
			int val;
			return this.GetValue("stack", val) ? val:0;
		}
		public set(int val) {
			this.SetValue("stack", val);
		}
	}
}

PointsMap Points[MAXCLIENTS];
FF2Parse BossMap[MAXCLIENTS];
Handle PointsHud;

bool FF2CreateMenu(FF2Prep player)
{
	char path[PLATFORM_MAX_PATH];
	if(!player.BuildBoss(path, sizeof(path), "menu_base")) {
		return false;
	}
	
	if((BossMap[player.Index] = new FF2Parse(path, "menu_base")) == null) {
		return false;
	}
	
	MenuRage_Available = true;
	return true;
}
