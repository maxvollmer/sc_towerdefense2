
const int CONVEYOR_FRAMES = 10;

const array<float> CONVEYOR_SPEEDS = {
  0.2, 0.1, 0.075, 0.05
};

const array<float> CONVEYOR_SLOWDOWN_FACTORS = {
  0.6, 0.5, 0.4, 0.3
};

class ConveyorBeltTower : CSlowTower
{
  private uint m_iSpeed;
  private array<ComparableEHandle> slowedCritters;
  
  private float m_flTargetZoneMinX;
  private float m_flTargetZoneMaxX;
  private float m_flTargetZoneMinY;
  private float m_flTargetZoneMaxY;
  
  void Spawn()
  {
    Precache();
    InitTowerValues();
    
    m_iSpeed = 1;
    
    m_flTargetZoneMinX = self.pev.origin.x - GRID_SIZE;
    m_flTargetZoneMaxX = self.pev.origin.x + GRID_SIZE;
    m_flTargetZoneMinY = self.pev.origin.y - GRID_SIZE;
    m_flTargetZoneMaxY = self.pev.origin.y + GRID_SIZE;
    
    self.pev.nextthink = g_Engine.time + Math.RandomFloat(0, 1);
  }

  void Precache()
  {
    g_Game.PrecacheModel(GetModel());
  }

  void Think()
  {
    if (globalGameOver)
    {
      self.pev.flags |= FL_KILLME;
      return;
    }
    self.pev.nextthink = g_Engine.time + CONVEYOR_SPEEDS[m_iSpeed-1];
    self.pev.body = (self.pev.body+1) % CONVEYOR_FRAMES;
    SlowDownCrittersInTargetZone();
  }

  private bool IsInTargetZone(CBaseEntity@ pEntity)
  {
    return
      pEntity !is null &&
      GetCritter(pEntity) !is null &&
      !GetCritter(pEntity).IsFlying() &&
      pEntity.pev.origin.x >= m_flTargetZoneMinX &&
      pEntity.pev.origin.x < m_flTargetZoneMaxX &&
      pEntity.pev.origin.y >= m_flTargetZoneMinY &&
      pEntity.pev.origin.y < m_flTargetZoneMaxY;
  }

  private void SlowDownCrittersInTargetZone()
  {
    CBaseEntity@ pEntity = null;
    while ((@pEntity=g_EntityFuncs.FindEntityByTargetname(pEntity, "critter")) !is null)
    {
      if (IsInTargetZone(pEntity))
      {
        if (slowedCritters.find(ComparableEHandle(pEntity)) == -1)
        {
          GetCritter(pEntity).AddCritterSlower(@this);
          slowedCritters.insertLast(ComparableEHandle(pEntity));
        }
      }
    }
    for (uint i = 0; i < slowedCritters.size();)
    {
      if (!IsInTargetZone(slowedCritters[i].GetEntity()))
      {
        if (slowedCritters[i].IsValid())
        {
          GetCritter(slowedCritters[i].GetEntity()).RemoveCritterSlower(@this);
        }
        slowedCritters.removeAt(i);
      }
      else
      {
        i++;
      }
    }
  }

  float GetSlowDownFactor()
  {
    return CONVEYOR_SLOWDOWN_FACTORS[m_iSpeed-1];
  }

  // CBaseTower implementations
  string GetModel()
  {
    return "models/sc_towerdefense2/conveyorbelt.mdl";
  }
  
  bool IsPathTower() { return true; }
  
  string GetDisplayName() { return "Conveyor Belt"; }
  string GetDescription()
  {
    return
      "A simple conveyor belt\n\n"+
      "Slows down ground units.";
  }
  
  string GetSpeed() { return ""+m_iSpeed; }
  
  int GetPrice() { return 20; }
  
  float GetModelScale() { return 1; }
  float GetMenuModelScale() { return 0.8; }
  
  string[] GetAdditionalInfo()
  {
    string[] returnValue = {
      "Speed: "+GetSpeed()
    };
    return returnValue;
  }
  
  TowerUpgradeInfo[] GetUpgradeInfo()
  {
    TowerUpgradeInfo[] returnValue = {
      TowerUpgradeInfo("speed", "Upgrade Speed", 5, UPGRADE_SPEED_SPRITE, m_iSpeed < CONVEYOR_SPEEDS.size(), ""+m_iSpeed, ""+(m_iSpeed+1), ""+CONVEYOR_SPEEDS.size())
    };
    return returnValue;
  }
  
  void Upgrade(TowerUpgradeInfo@ upgradeInfo)
  {
    if (globalGameOver)
    {
      return;
    }
    AddUpgradeCost(upgradeInfo.cost);
    if (upgradeInfo.id == "speed")
    {
      if (m_iSpeed < CONVEYOR_SPEEDS.size())
      {
        m_iSpeed++;
      }
    }
  }
  
  void OnDestroy()
  {
    for (uint i = 0, n = slowedCritters.size(); i < n; i++)
    {
      if (slowedCritters[i].IsValid())
      {
        GetCritter(slowedCritters[i].GetEntity()).RemoveCritterSlower(@this);
      }
    }
    slowedCritters.resize(0);
  }
};


