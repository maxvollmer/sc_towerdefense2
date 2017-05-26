
/**
 * Use this file to configure the tower entities and critter waves for your sc_td map.
 * Towers are automagically precached by their worker entities.
 * Critters are automagically precached by the global CritterWaveManager.
 */


// Add and remove any towers you want in your map here:

#include "towers/cratetower"
#include "towers/zaptower"
#include "towers/conveyorbelt"
#include "towers/xentreetower"

void RegisterTowerEntities()
{
  g_CustomEntityFuncs.RegisterCustomEntity("ZapTower", "zaptower");
  g_CustomEntityFuncs.RegisterCustomEntity("CrateTower", "cratetower");
  g_CustomEntityFuncs.RegisterCustomEntity("ConveyorBeltTower", "conveyorbelt");
  g_CustomEntityFuncs.RegisterCustomEntity("XenTreeTower", "xentreetower");
}


// Configure the critter waves you want in your map here:
/*
CritterWave(
  critterCount - number of critters that spawn per route
  critterModel - self explanatory
  critterHealth - self explanatory
  critterSpeed - self explanatory
  flags - can be any of those (use | to have multiple): FL_CRITTER_NORMAL, FL_CRITTER_FLYING, FL_CRITTER_INVISIBLE, FL_CRITTER_BOSS
  monsterClassName - entity to spawn in player lobby, when critters have escaped
  killMoney - money a player receives when they kill a critter
  waveMoney - money all players receive at end of the wave
  successMoney - money all players receive additionally at end of the wave if no critters escaped
);
*/

const CritterWave[] CRITTER_WAVES = {
  CritterWave(40, "models/hlclassic/headcrab.mdl", 1, 50, FL_CRITTER_NORMAL, "monster_zombie", 0, 5, 0),
  CritterWave(40, "models/hlclassic/headcrab.mdl", 2, 60, FL_CRITTER_NORMAL, "monster_zombie", 0, 5, 0),
  CritterWave(40, "models/hlclassic/headcrab.mdl", 4, 70, FL_CRITTER_NORMAL, "monster_zombie", 0, 5, 0),
  CritterWave(40, "models/hlclassic/headcrab.mdl", 8, 80, FL_CRITTER_NORMAL, "monster_zombie", 0, 5, 0),
  CritterWave(40, "models/aflock.mdl", 20, 100, FL_CRITTER_FLYING, "monster_zombie", 1, 15, 0),
  
  CritterWave(60, "models/hlclassic/headcrab.mdl", 15, 100, FL_CRITTER_NORMAL, "monster_zombie", 1, 10, 2),
  CritterWave(60, "models/hlclassic/headcrab.mdl", 20, 110, FL_CRITTER_NORMAL, "monster_zombie", 1, 10, 2),
  CritterWave(60, "models/hlclassic/headcrab.mdl", 25, 120, FL_CRITTER_NORMAL, "monster_zombie", 1, 10, 2),
  CritterWave(60, "models/hlclassic/headcrab.mdl", 30, 130, FL_CRITTER_NORMAL, "monster_zombie", 1, 10, 2),
  CritterWave(1, "models/kingheadcrab.mdl", 1000, 200, FL_CRITTER_BOSS, "monster_zombie", 25, 20, 10),
  
  CritterWave(80, "models/hlclassic/headcrab.mdl", 40, 150, FL_CRITTER_NORMAL, "monster_zombie", 2, 15, 5),
  CritterWave(80, "models/hlclassic/headcrab.mdl", 50, 160, FL_CRITTER_NORMAL, "monster_zombie", 2, 15, 5),
  CritterWave(80, "models/hlclassic/headcrab.mdl", 60, 170, FL_CRITTER_NORMAL, "monster_zombie", 2, 15, 5),
  CritterWave(80, "models/hlclassic/headcrab.mdl", 70, 180, FL_CRITTER_NORMAL, "monster_zombie", 2, 15, 5),
  CritterWave(80, "models/hlclassic/headcrab.mdl", 150, 300, FL_CRITTER_INVISIBLE, "monster_zombie", 3, 25, 5),
  
  CritterWave(100, "models/hlclassic/headcrab.mdl", 80, 190, FL_CRITTER_NORMAL, "monster_zombie", 3, 20, 10),
  CritterWave(100, "models/hlclassic/headcrab.mdl", 100, 200, FL_CRITTER_NORMAL, "monster_zombie", 3, 20, 10),
  CritterWave(100, "models/hlclassic/headcrab.mdl", 120, 210, FL_CRITTER_NORMAL, "monster_zombie", 3, 20, 10),
  CritterWave(100, "models/hlclassic/headcrab.mdl", 140, 220, FL_CRITTER_NORMAL, "monster_zombie", 3, 20, 10),
  CritterWave(1, "models/kingheadcrab.mdl", 2000, 400, FL_CRITTER_BOSS|FL_CRITTER_INVISIBLE, "monster_zombie", 50, 30, 20)
};
