
const int FL_CRITTER_NORMAL = 0;    // On ground, gets blocked, some towers can't attack
const int FL_CRITTER_FLYING = 1;    // 128 units above ground, doesn't get blocked, some towers can't attack
const int FL_CRITTER_INVISIBLE = 2; // Can only be seen and attacked when made visible by special towers
const int FL_CRITTER_BOSS = 4;      // Doesn't slow down, doesn't get blocked

const int WAVE_COUNTDOWN_TIME = 5;

const string WAVEINFO_CRITTER_SPECIALTY_NONE = "waveinfo_critter_special_none";
const string WAVEINFO_CRITTER_SPECIALTY_FLYING = "waveinfo_critter_special_flying";
const string WAVEINFO_CRITTER_SPECIALTY_BOSS = "waveinfo_critter_special_boss";
const string WAVEINFO_CRITTER_SPECIALTY_INVISIBLE = "waveinfo_critter_special_invisible";
const string WAVEINFO_CRITTER_SPECIALTY_FLYING_AND_BOSS = "waveinfo_critter_special_flyboss";
const string WAVEINFO_CRITTER_SPECIALTY_FLYING_AND_INVISIBLE = "waveinfo_critter_special_flyinvi";
const string WAVEINFO_CRITTER_SPECIALTY_INVISIBLE_AND_BOSS = "waveinfo_critter_special_inviboss";
const string WAVEINFO_CRITTER_SPECIALTY_ALL = "waveinfo_critter_special_all";

const string WAVEINFO_CURRENTWAVE = "waveinfo_current_wave";
const string WAVEINFO_CRITTER_HEALTH = "waveinfo_critter_health";
const string WAVEINFO_CRITTER_SPEED = "waveinfo_critter_speed";
const string WAVEINFO_KILLMONEY = "waveinfo_killmoney";
const string WAVEINFO_WAVEMONEY = "waveinfo_wavemoney";
const string WAVEINFO_CRITTERS_ALIVE = "waveinfo_critters_alive";
const string WAVEINFO_CRITTERS_KILLED = "waveinfo_critters_killed";
const string WAVEINFO_CRITTERS_ESCAPED = "waveinfo_critters_escaped";

class CritterWave
{
  int critterCount;
  string model;
  float health;
  int speed;
  bool invisible;
  bool flying;
  bool boss;
  string escapedMonsterClassname;
  int killMoney;
  int endOfWaveMoney;
  int noCrittersEscapedMoney;
  CritterWave() {}
  CritterWave(int critterCount, string model, float health, int speed, int flags, string escapedMonsterClassname, int killMoney, int endOfWaveMoney, int noCrittersEscapedMoney)
  {
    this.critterCount = critterCount;
    this.model = model;
    this.health = health;
    this.speed = speed;
    this.invisible = (flags & FL_CRITTER_INVISIBLE) != 0;
    this.flying = (flags & FL_CRITTER_FLYING) != 0;
    this.boss = (flags & FL_CRITTER_BOSS) != 0;
    this.escapedMonsterClassname = escapedMonsterClassname;
    this.killMoney = killMoney;
    this.endOfWaveMoney = endOfWaveMoney;
    this.noCrittersEscapedMoney = noCrittersEscapedMoney;
  }
};

class CritterWaveManager
{
  private int critterWaveIndex = 0;
  private int critterCount = 0;
  private int critterAliveCount = 0;
  private int critterEscapedCount = 0;
  private float critterEscapedHealth = 0;

  CritterWaveManager()
  {
    PrecacheCritters();
  }

  void StartGame()
  {
    InitCritterWave(0);
  }

  void EndGame()
  {
    UpdateWaveInfo();
  }

  private void PrecacheCritters()
  {
    for (int i = 0, n = CRITTER_WAVES.size(); i < n; i++)
    {
      g_Game.PrecacheModel(CRITTER_WAVES[i].model);
      dictionary keyvalues;
      CBaseEntity@ pTempPrecacheMonster = g_EntityFuncs.CreateEntity(CRITTER_WAVES[i].escapedMonsterClassname, @keyvalues);
      if (pTempPrecacheMonster !is null)
      {
        pTempPrecacheMonster.pev.flags |= FL_KILLME;
        pTempPrecacheMonster.pev.effects |= EF_NODRAW;
      }
    }
  }

  private void SpawnCritter(string spawnPointName)
  {
    if (globalGameOver)
    {
      return;
    }
    CBaseEntity@ pSpawnPoint = g_EntityFuncs.FindEntityByTargetname(null, spawnPointName);
    dictionary itemKeyValues = {
      {"targetname", "critter"},
      {"origin", OriginString(pSpawnPoint.pev.origin.x, pSpawnPoint.pev.origin.y, pSpawnPoint.pev.origin.z)},
      {"angles", AnglesString(pSpawnPoint.pev.angles.x, pSpawnPoint.pev.angles.y, pSpawnPoint.pev.angles.z)},
      {"spawnPointName", spawnPointName},
      {"model", CRITTER_WAVES[critterWaveIndex].model},
      {"critterHealth", string(CRITTER_WAVES[critterWaveIndex].health)},
      {"critterSpeed", string(CRITTER_WAVES[critterWaveIndex].speed)}
    };
    if (CRITTER_WAVES[critterWaveIndex].invisible)
    {
      itemKeyValues.set("invisible", "1");
    }
    if (CRITTER_WAVES[critterWaveIndex].flying)
    {
      itemKeyValues.set("flying", "1");
    }
    if (CRITTER_WAVES[critterWaveIndex].boss)
    {
      itemKeyValues.set("boss", "1");
    }
    if (CRITTER_WAVES[critterWaveIndex].killMoney > 0)
    {
      itemKeyValues.set("killmoney", string(CRITTER_WAVES[critterWaveIndex].killMoney));
    }
    g_EntityFuncs.CreateEntity("critter", @itemKeyValues);
    critterAliveCount++;
    UpdateWaveCritterStatusInfo();
  }

  // must be public for scheduler
  void SpawnCritters(int i)
  {
    if (globalGameOver)
    {
      return;
    }
    if (i < CRITTER_WAVES[critterWaveIndex].critterCount)
    {
      array<string> spawnPointNames = critterRouteManager.GetSpawnPointNames();
      SpawnCritter(spawnPointNames[i % spawnPointNames.size()]);
      float delayTillNextCritter = float(GRID_SIZE) / float(CRITTER_WAVES[critterWaveIndex].speed);
      g_Scheduler.SetTimeout("CallSpawnCritters", delayTillNextCritter, i+1);
    }
    else
    {
      CritterSpawnDone();
    }
  }

  void CritterEscaped(float health)
  {
    if (globalGameOver)
    {
      return;
    }
    critterEscapedCount++;
    critterEscapedHealth += health;
    UpdateWaveCritterStatusInfo();
  }

  void CritterDown()
  {
    if (globalGameOver)
    {
      return;
    }
    critterCount--;
    critterAliveCount--;
    UpdateWaveCritterStatusInfo();
    if (critterCount == 0)
    {
      CritterWaveCompleted(critterEscapedCount, critterEscapedHealth);
    }
  }

  private void CritterSpawnDone()
  {
    critterRouteManager.SetSpawnSpritesVisible(false);
  }

  private void StartCritterWave()
  {
    if (globalGameOver)
    {
      return;
    }
    critterRouteManager.SetSpawnSpritesVisible(true);
    critterCount = CRITTER_WAVES[critterWaveIndex].critterCount;
    critterAliveCount = 0;
    critterEscapedCount = 0;
    critterEscapedHealth = 0;
    SpawnCritters(0);
  }

  private string GetCritterSpecialtiesText()
  {
    string specialties = "";
    if (CRITTER_WAVES[critterWaveIndex].flying)
    {
      specialties = "Flying";
    }
    if (CRITTER_WAVES[critterWaveIndex].invisible)
    {
      if (specialties.Length() > 0)
      {
        specialties = specialties + " + Invisible";
      }
      else
      {
        specialties = "Invisible";
      }
    }
    if (CRITTER_WAVES[critterWaveIndex].boss)
    {
      if (specialties.Length() > 0)
      {
        specialties = specialties + " + Boss";
      }
      else
      {
        specialties = "Boss";
      }
    }
    if (specialties.Length() > 0)
    {
      return specialties;
    }
    else
    {
      return "None";
    }
  }

  private string GetWaveInfoText()
  {
    return
      "Critter Speed: " + CRITTER_WAVES[critterWaveIndex].speed + "\n"+
      "Critter Health: " + CRITTER_WAVES[critterWaveIndex].health + "\n"+
      "Critter Specialties: "+GetCritterSpecialtiesText();
  }

  // must be public for scheduler
  void CountDownCritterWave(int count)
  {
    if (globalGameOver)
    {
      return;
    }
    if (count > 0)
    {
      DisplayText("Wave "+(critterWaveIndex+1)+"/"+CRITTER_WAVES.size()+" starts in "+count+"...\n\n"+GetWaveInfoText());
      g_Scheduler.SetTimeout("CallCountDownCritterWave", 2, count-1);
    }
    else
    {
      DisplayText("Wave "+(critterWaveIndex+1)+"/"+CRITTER_WAVES.size()+" starting!\n\n"+GetWaveInfoText());
      StartCritterWave();
    }
  }

  private void InitCritterWave(int index)
  {
    if (globalGameOver)
    {
      return;
    }
    if (index < int(CRITTER_WAVES.size()))
    {
      critterWaveIndex = index;
      critterCount = 0;
      critterAliveCount = 0;
      critterEscapedCount = 0;
      critterEscapedHealth = 0;
      UpdateWaveInfo();
      CountDownCritterWave(WAVE_COUNTDOWN_TIME);
    }
    else
    {
      GameWon();
    }
  }

  // must be public for scheduler
  void NextCritterWave()
  {
    if (globalGameOver)
    {
      return;
    }
    InitCritterWave(critterWaveIndex+1);
  }

  private void CritterWaveCompleted(int critterEscapedCount, float critterEscapedHealth)
  {
    if (globalGameOver)
    {
      return;
    }
    for(uint i = 0, n = workers.length(); i < n; i++)
    {
      workers[i].AddMoney(CRITTER_WAVES[critterWaveIndex].endOfWaveMoney);
      if (critterEscapedCount == 0)
      {
        workers[i].AddMoney(CRITTER_WAVES[critterWaveIndex].noCrittersEscapedMoney);
      }
    }
    
    if (critterEscapedCount > 0)
    {
      CountDownTillMonster(5);
    }
    else
    {
      DisplayText("Wave successfully completed!\nNo critters escaped!\n\nYou receive "+CRITTER_WAVES[critterWaveIndex].endOfWaveMoney+" money + "+CRITTER_WAVES[critterWaveIndex].noCrittersEscapedMoney+" bonus.\n", null, false, TEXT_COLOR_GREEN);
      g_Scheduler.SetTimeout("CallNextCritterWave", 5);
    }
  }

  // must be public for scheduler
  void CountDownTillMonster(int count)
  {
    if (globalGameOver)
    {
      return;
    }
    string displaytext = "Wave "+(critterWaveIndex+1)+"/"+CRITTER_WAVES.size()+" completed!\n"+critterEscapedCount+" critters with total "+int(critterEscapedHealth)+" health escaped!\n\nYou only receive "+CRITTER_WAVES[critterWaveIndex].endOfWaveMoney+" money.\n\n";
    
    if (count > 0)
    {
      displaytext = displaytext + "A "+CRITTER_WAVES[critterWaveIndex].escapedMonsterClassname+" will spawn in the lobby in "+count+"...";
      g_Scheduler.SetTimeout("CallCountDownTillMonster", 2, count-1);
    }
    else
    {
      displaytext = displaytext + "A "+CRITTER_WAVES[critterWaveIndex].escapedMonsterClassname+" spawned in lobby!";
      dictionary keyvalues = {
        {"origin", "-4608 -5120 -960"},  // TODO: Get origin from entity
        {"angles", "0 "+Math.RandomFloat(0,360)+" 0"},
        {"health", string(critterEscapedHealth)}
      };
      g_EntityFuncs.CreateEntity(CRITTER_WAVES[critterWaveIndex].escapedMonsterClassname, @keyvalues);
      g_Scheduler.SetTimeout("CallNextCritterWave", 10);
    }
    
    DisplayText(displaytext, null, false, TEXT_COLOR_RED);
  }

  private void SetCritterSpecialityInfoVisible(string name, bool visible)
  {
    CBaseEntity@ pEntity = null;
    while ((@pEntity = g_EntityFuncs.FindEntityByTargetname(pEntity, name)) !is null)
    {
      pEntity.Use(pEntity, pEntity, visible ? USE_ON : USE_OFF, 0);
    }
  }

  private void SetWaveInfoText(string name, string text)
  {
    CBaseEntity@ pEntity = null;
    while ((@pEntity = g_EntityFuncs.FindEntityByTargetname(pEntity, name)) !is null)
    {
      array<int> frames = GetCharacterFrames(text);
      if (frames.size() > 0)
      {
        pEntity.pev.framerate = 0;
        pEntity.pev.frame = frames[0];  // TODO: All frames!
      }
    }
  }

  private void UpdateWaveInfo()
  {
    if (globalGameOver)
    {
      SetWaveInfoText(WAVEINFO_CURRENTWAVE, " ");
      SetWaveInfoText(WAVEINFO_CRITTER_HEALTH, " ");
      SetWaveInfoText(WAVEINFO_CRITTER_SPEED, " ");
      SetWaveInfoText(WAVEINFO_KILLMONEY, " ");
      SetWaveInfoText(WAVEINFO_WAVEMONEY, " ");
      SetWaveInfoText(WAVEINFO_CRITTERS_ALIVE, " ");
      SetWaveInfoText(WAVEINFO_CRITTERS_KILLED, " ");
      SetWaveInfoText(WAVEINFO_CRITTERS_ESCAPED, " ");
      
      SetCritterSpecialityInfoVisible(WAVEINFO_CRITTER_SPECIALTY_NONE, false);
      SetCritterSpecialityInfoVisible(WAVEINFO_CRITTER_SPECIALTY_BOSS, false);
      SetCritterSpecialityInfoVisible(WAVEINFO_CRITTER_SPECIALTY_FLYING, false);
      SetCritterSpecialityInfoVisible(WAVEINFO_CRITTER_SPECIALTY_INVISIBLE, false);
      SetCritterSpecialityInfoVisible(WAVEINFO_CRITTER_SPECIALTY_FLYING_AND_BOSS, false);
      SetCritterSpecialityInfoVisible(WAVEINFO_CRITTER_SPECIALTY_FLYING_AND_INVISIBLE, false);
      SetCritterSpecialityInfoVisible(WAVEINFO_CRITTER_SPECIALTY_INVISIBLE_AND_BOSS, false);
      SetCritterSpecialityInfoVisible(WAVEINFO_CRITTER_SPECIALTY_ALL, false);
    }
    else
    {
      SetWaveInfoText(WAVEINFO_CURRENTWAVE, ""+(critterWaveIndex+1)+"/"+CRITTER_WAVES.size());
      SetWaveInfoText(WAVEINFO_CRITTER_HEALTH, ""+CRITTER_WAVES[critterWaveIndex].health);
      SetWaveInfoText(WAVEINFO_CRITTER_SPEED, ""+CRITTER_WAVES[critterWaveIndex].speed);
      SetWaveInfoText(WAVEINFO_KILLMONEY, ""+CRITTER_WAVES[critterWaveIndex].killMoney);
      SetWaveInfoText(WAVEINFO_WAVEMONEY, ""+CRITTER_WAVES[critterWaveIndex].endOfWaveMoney+"/"+CRITTER_WAVES[critterWaveIndex].noCrittersEscapedMoney);
      SetWaveInfoText(WAVEINFO_CRITTERS_ALIVE, "0");
      SetWaveInfoText(WAVEINFO_CRITTERS_KILLED, "0");
      SetWaveInfoText(WAVEINFO_CRITTERS_ESCAPED, "0");
      
      SetCritterSpecialityInfoVisible(WAVEINFO_CRITTER_SPECIALTY_NONE, !CRITTER_WAVES[critterWaveIndex].invisible && !CRITTER_WAVES[critterWaveIndex].flying && !CRITTER_WAVES[critterWaveIndex].boss);
      SetCritterSpecialityInfoVisible(WAVEINFO_CRITTER_SPECIALTY_BOSS, !CRITTER_WAVES[critterWaveIndex].invisible && !CRITTER_WAVES[critterWaveIndex].flying && CRITTER_WAVES[critterWaveIndex].boss);
      SetCritterSpecialityInfoVisible(WAVEINFO_CRITTER_SPECIALTY_FLYING, !CRITTER_WAVES[critterWaveIndex].invisible && CRITTER_WAVES[critterWaveIndex].flying && !CRITTER_WAVES[critterWaveIndex].boss);
      SetCritterSpecialityInfoVisible(WAVEINFO_CRITTER_SPECIALTY_INVISIBLE, CRITTER_WAVES[critterWaveIndex].invisible && !CRITTER_WAVES[critterWaveIndex].flying && !CRITTER_WAVES[critterWaveIndex].boss);
      SetCritterSpecialityInfoVisible(WAVEINFO_CRITTER_SPECIALTY_FLYING_AND_BOSS, !CRITTER_WAVES[critterWaveIndex].invisible && CRITTER_WAVES[critterWaveIndex].flying && CRITTER_WAVES[critterWaveIndex].boss);
      SetCritterSpecialityInfoVisible(WAVEINFO_CRITTER_SPECIALTY_FLYING_AND_INVISIBLE, CRITTER_WAVES[critterWaveIndex].invisible && CRITTER_WAVES[critterWaveIndex].flying && !CRITTER_WAVES[critterWaveIndex].boss);
      SetCritterSpecialityInfoVisible(WAVEINFO_CRITTER_SPECIALTY_INVISIBLE_AND_BOSS, CRITTER_WAVES[critterWaveIndex].invisible && !CRITTER_WAVES[critterWaveIndex].flying && CRITTER_WAVES[critterWaveIndex].boss);
      SetCritterSpecialityInfoVisible(WAVEINFO_CRITTER_SPECIALTY_ALL, CRITTER_WAVES[critterWaveIndex].invisible && CRITTER_WAVES[critterWaveIndex].flying && CRITTER_WAVES[critterWaveIndex].boss);
    }
  }

  private void UpdateWaveCritterStatusInfo()
  {
    if (globalGameOver)
    {
      SetWaveInfoText(WAVEINFO_CRITTERS_ALIVE, " ");
      SetWaveInfoText(WAVEINFO_CRITTERS_KILLED, " ");
      SetWaveInfoText(WAVEINFO_CRITTERS_ESCAPED, " ");
    }
    else
    {
      SetWaveInfoText(WAVEINFO_CRITTERS_ALIVE, ""+critterAliveCount);
      SetWaveInfoText(WAVEINFO_CRITTERS_KILLED, ""+(CRITTER_WAVES[critterWaveIndex].critterCount - (critterCount + critterEscapedCount)));
      SetWaveInfoText(WAVEINFO_CRITTERS_ESCAPED, ""+critterEscapedCount);
    }
  }
};

// callbacks for scheduler
void CallCountDownCritterWave(int count)
{
  critterWaveManager.CountDownCritterWave(count);
}

void CallNextCritterWave()
{
  critterWaveManager.NextCritterWave();
}

void CallCountDownTillMonster(int count)
{
  critterWaveManager.CountDownTillMonster(count);
}

void CallSpawnCritters(int i)
{
  critterWaveManager.SpawnCritters(i);
}

