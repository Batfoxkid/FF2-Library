mkdir -p build/addons/sourcemod
cd build

cp -r ../addons/sourcemod/scripting addons/sourcemod
cp -r ../sm/addons/sourcemod/scripting/include addons/sourcemod/scripting
cp -r ../sm/addons/sourcemod/scripting/compile.sh addons/sourcemod/scripting
cp -r ../sm/addons/sourcemod/scripting/spcomp addons/sourcemod/scripting
cd addons/sourcemod/scripting

wget "https://forums.alliedmods.net/attachment.php?attachmentid=79000&d=1292171445" -O include/colors.inc
wget "https://raw.githubusercontent.com/peace-maker/DHooks2/dynhooks/sourcemod/scripting/include/dhooks.inc" -O include/dhooks.inc
wget "https://raw.githubusercontent.com/Batfoxkid/FreakFortressBat/master/addons/sourcemod/scripting/include/freak_fortress_2.inc" -O include/freak_fortress_2.inc
wget "https://raw.githubusercontent.com/Batfoxkid/FreakFortressBat/master/addons/sourcemod/scripting/include/freak_fortress_2_stocks.inc" -O include/freak_fortress_2_stocks.inc
wget "https://raw.githubusercontent.com/Batfoxkid/FreakFortressBat/master/addons/sourcemod/scripting/include/freak_fortress_2_subplugin.inc" -O include/freak_fortress_2_subplugin.inc
wget "https://raw.githubusercontent.com/Batfoxkid/FreakFortressBat/master/addons/sourcemod/scripting/include/freak_fortress_2_vsh_feedback.inc" -O include/freak_fortress_2_vsh_feedback.inc
wget "https://raw.githubusercontent.com/Flyflo/SM-Goomba-Stomp/master/addons/sourcemod/scripting/include/goomba.inc" -O include/goomba.inc
wget "https://raw.githubusercontent.com/DoctorMcKay/sourcemod-plugins/master/scripting/include/morecolors.inc" -O include/morecolors.inc
wget "https://forums.alliedmods.net/attachment.php?attachmentid=115795&d=1360508618" -O include/rtd.inc
wget "https://raw.githubusercontent.com/Phil25/RTD/master/scripting/include/rtd2.inc" -O include/rtd2.inc
wget "https://raw.githubusercontent.com/Silenci0/SMAC/master/addons/sourcemod/scripting/include/smac.inc" -O include/smac.inc
wget "https://raw.githubusercontent.com/Silenci0/SMAC/master/addons/sourcemod/scripting/include/smac_stocks.inc" -O include/smac_stocks.inc
wget "https://raw.githubusercontent.com/asherkin/SteamTools/master/plugin/steamtools.inc" -O include/steamtools.inc
wget "https://forums.alliedmods.net/attachment.php?attachmentid=116849&d=1377667508" -O include/tf2attributes.inc
wget "https://raw.githubusercontent.com/asherkin/TF2Items/master/pawn/tf2items.inc" -O include/tf2items.inc
wget "https://raw.githubusercontent.com/nosoop/SM-TFCustAttr/master/scripting/include/tf_custom_attributes.inc" -O include/tf_custom_attributes.inc

sed -i'' 's/required = 1/#if defined REQUIRE_PLUGIN\nrequired = 1\n\#else\nrequired = 0/' include/rtd.inc