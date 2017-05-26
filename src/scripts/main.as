#include "helpers"
#include "baseclass"
#include "worker"
#include "camera"
#include "menu"
#include "critters"
#include "critterroute"
#include "critterwave"
#include "towers"
#include "config"

bool globalGameOver = false;
CritterWaveManager@ critterWaveManager = null;
CritterRouteManager@ critterRouteManager = null;

const string ALPHANUM_SPRITE = "sprites/sc_towerdefense2/mecha.spr";

const string COMPUTER_TERMINAL_SPRITE = "sprites/sc_towerdefense2/terminal.spr";
const string COMPUTER_TERMINAL_REPAIR_SPRITE = "sprites/sc_towerdefense2/repair.spr";
const string WARNING_SPRITE = "sprites/sc_towerdefense2/warning.spr";
const string EXIT_SPRITE = "sprites/sc_towerdefense2/exit.spr";
const string SELL_SPRITE = "sprites/sc_towerdefense2/sell.spr";

const string HEALTHBAR_SPRITE = "sprites/sc_towerdefense2/healthbar.spr";
const string TOWER_SPAWN_SPRITE = "sprites/b-tele1.spr";

const string UPGRADE_SPEED_SPRITE = "sprites/sc_towerdefense2/upgrade_speed.spr";
const string UPGRADE_DAMAGE_SPRITE = "sprites/sc_towerdefense2/upgrade_damage.spr";
const string UPGRADE_RANGE_SPRITE = "sprites/sc_towerdefense2/upgrade_range.spr";
const string UPGRADE_ACCURACY_SPRITE = "sprites/sc_towerdefense2/upgrade_accuracy.spr";
const string UPGRADE_TO_METALCRATE_SPRITE = "sprites/sc_towerdefense2/upgrade_to_metalcrate.spr";
const string UPGRADE_TO_EXPLOSIVECRATE_SPRITE = "sprites/sc_towerdefense2/upgrade_to_explosivecrate.spr";
const string UPGRADE_STRENGTH_METAL_SPRITE = "sprites/sc_towerdefense2/upgrade_strength_metal.spr";
const string UPGRADE_STRENGTH_WOOD_SPRITE = "sprites/sc_towerdefense2/upgrade_strength_wood.spr";

// Called as soon as AS is loaded
void MapInit()
{
  g_Game.PrecacheModel(ALPHANUM_SPRITE);
  
  g_Game.PrecacheModel(COMPUTER_TERMINAL_SPRITE);
  g_Game.PrecacheModel(COMPUTER_TERMINAL_REPAIR_SPRITE);
  g_Game.PrecacheModel(WARNING_SPRITE);
  g_Game.PrecacheModel(EXIT_SPRITE);
  g_Game.PrecacheModel(SELL_SPRITE);
  
  g_Game.PrecacheModel(HEALTHBAR_SPRITE);
  g_Game.PrecacheModel(TOWER_SPAWN_SPRITE);
  
  g_Game.PrecacheModel(UPGRADE_SPEED_SPRITE);
  g_Game.PrecacheModel(UPGRADE_DAMAGE_SPRITE);
  g_Game.PrecacheModel(UPGRADE_RANGE_SPRITE);
  g_Game.PrecacheModel(UPGRADE_ACCURACY_SPRITE);
  g_Game.PrecacheModel(UPGRADE_TO_METALCRATE_SPRITE);
  g_Game.PrecacheModel(UPGRADE_TO_EXPLOSIVECRATE_SPRITE);
  g_Game.PrecacheModel(UPGRADE_STRENGTH_METAL_SPRITE);
  g_Game.PrecacheModel(UPGRADE_STRENGTH_WOOD_SPRITE);
  
  g_CustomEntityFuncs.RegisterCustomEntity("Worker", "worker");
  g_CustomEntityFuncs.RegisterCustomEntity("Critter", "critter");
  g_CustomEntityFuncs.RegisterCustomEntity("CritterRoute", "critter_route");
  
  RegisterTowerEntities();
  
  InitGlobalHelperEntities();
  
  @critterWaveManager = CritterWaveManager();
}

// Called as soon as all entities are loaded and initialized
void MapActivate()
{
  @critterRouteManager = CritterRouteManager();
}

void GameStartCallback(CBaseEntity@ pPlayer, CBaseEntity@ pCamera, USE_TYPE useType, float value)
{
  StartGame();
}

void GameLostCallback(CBaseEntity@ pPlayer, CBaseEntity@ pCamera, USE_TYPE useType, float value)
{
  GameLost();
}

void StartGame()
{
  if (globalGameOver)
  {
    return;
  }
  critterWaveManager.StartGame();
}

void GameLost()
{
  if (globalGameOver)
  {
    return;
  }
  globalGameOver = true;
  critterWaveManager.EndGame();
  DisplayText("GAME OVER: YOU LOST", null, false, TEXT_COLOR_RED);
  CBaseEntity@ pGameLostCallback = g_EntityFuncs.FindEntityByTargetname(null, "game_lost_callback");
  if (pGameLostCallback !is null)
  {
    pGameLostCallback.Use(pGameLostCallback, pGameLostCallback, USE_ON, 0);
  }
}

void GameWon()
{
  if (globalGameOver)
  {
    return;
  }
  globalGameOver = true;
  critterWaveManager.EndGame();
  DisplayText("CONGRATULATIONS: YOU WON!", null, false, TEXT_COLOR_GREEN);
  CBaseEntity@ pGameWonCallback = g_EntityFuncs.FindEntityByTargetname(null, "game_won_callback");
  if (pGameWonCallback !is null)
  {
    pGameWonCallback.Use(pGameWonCallback, pGameWonCallback, USE_ON, 0);
  }
}

