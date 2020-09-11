cd build

mkdir -p package/addons/sourcemod

cp -r ../addons/sourcemod/configs package/addons/sourcemod
cp -r ../addons/sourcemod/gamedata package/addons/sourcemod
cp ../addons/sourcemod/scripting/compiled package/addons/sourcemod/plugins
cp -r ../addons/sourcemod/translations package/addons/sourcemod
cp -r ../materials package
cp -r ../sound package
cp -r ../LICENSE.txt package