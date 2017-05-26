
class TowerUpgradeInfo
{
  string id;
  string description;
  int cost;
  string buttonModel;
  bool isEnabled;
  string currentValue;
  string afterUpdateValue;
  string maximumValue;
  TowerUpgradeInfo(){}
  TowerUpgradeInfo(string id, string description, int cost, string buttonModel, bool isEnabled, string currentValue, string afterUpdateValue, string maximumValue)
  {
    this.id = id;
    this.description = description;
    this.cost = cost;
    this.buttonModel = buttonModel;
    this.isEnabled = isEnabled;
    this.currentValue = currentValue;
    this.afterUpdateValue = afterUpdateValue;
    this.maximumValue = maximumValue;
  }
  string GetInfoText()
  {
    if (isEnabled)
    {
      return
        "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"+
        description + "\n\n" +
        "Current: "+currentValue + "\n" +
        "After Update: "+afterUpdateValue + "\n" +
        "Maximum: "+maximumValue + "\n\n" +
        "Cost: "+cost;
    }
    else
    {
      return description + "\n\n(Already at maximum!)";
    }
  }
}

// Tower classes must implement this class and override the methods below
class CBaseTower : CBaseTD
{
  private float m_flSellValue;
  
  void InitTowerValues()
  {
    g_EntityFuncs.SetModel(self, GetModel());
    if (IsPathTower())
    {
      g_EntityFuncs.SetSize(self.pev, Vector(-GRID_SIZE*2,-GRID_SIZE*2,0), Vector(GRID_SIZE*2,GRID_SIZE*2,GRID_SIZE));
    }
    else
    {
      g_EntityFuncs.SetSize(self.pev, Vector(-GRID_SIZE,-GRID_SIZE,0), Vector(GRID_SIZE,GRID_SIZE,GRID_SIZE));
    }
    self.pev.scale = GetModelScale();
    self.pev.movetype = MOVETYPE_NONE;
    self.pev.solid = SOLID_NOT;
    self.pev.takedamage = DAMAGE_NO;
    self.m_bloodColor = DONT_BLEED;
    m_flSellValue = float(GetPrice()) * 0.5;
  }

  string GetDisplayName() { return "Invalid Tower"; }
  string GetDescription() { return "Error"; }
  
  TowerUpgradeInfo[] GetUpgradeInfo() { TowerUpgradeInfo[] returnValue; return returnValue; }
  string[] GetAdditionalInfo() { array<string> returnValue; return returnValue; }
  void Upgrade(TowerUpgradeInfo@ upgradeInfo) {}
  
  int GetPrice() { return 99999999; }
  int GetSellValue() {  return int(m_flSellValue); }
  
  void AddUpgradeCost(int money)
  {
    m_flSellValue += float(money) * 0.5;
  }
  
  string GetModel() { return ""; }
  float GetModelScale() { return 1; }
  float GetMenuModelScale() { return 1; }
  int GetMenuSequence() { return 0; }
  bool IsBorderTower() { return false; }
  bool IsPathTower() { return false; }
  
  private Worker@ worker;
  
  private string GetAdditionalInfoText()
  {
    string returnValue;
    string[] additionalInfo = GetAdditionalInfo();
    for (int i = 0, n = additionalInfo.size(); i < n; i++)
    {
      returnValue = returnValue + additionalInfo[i] + "\n";
    }
    return returnValue;
  }
  
  string GetInfoText(bool prebuild)
  {
    return
      "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"+
      GetDisplayName() + "\n\n"+
      GetDescription() + "\n\n"+
      GetAdditionalInfoText()+"\n"+
      (prebuild?"Price: "+GetPrice():"")+"\n";
  }
  
  void SetWorker(Worker@ worker)
  {
    @this.worker = worker;
  }
  
  Worker@ GetWorker()
  {
    return worker;
  }
};

// Base class for towers that slow down critters
class CSlowTower : CBaseTower
{
  float GetSlowDownFactor()
  {
    return 1.0;
  }
};


// TODO: Encapsulate code below in class TowerManager

Vector[] g_towerPositions;
dictionary g_towerReservations;
dictionary g_groundTowers;

CBaseTower@ GetTowerBaseClass(string towerEntityClassname)
{
  // Temporarily create a tower entity, so we get a pointer to the correct tower script class.
  // Immediately kill that entity again.
  CBaseEntity@ pTowerEntity = g_EntityFuncs.CreateEntity(towerEntityClassname, null);
  if (pTowerEntity !is null)
  {
    pTowerEntity.pev.effects |= EF_NODRAW;
    pTowerEntity.pev.flags |= FL_KILLME;
    return cast<CBaseTower>(g_EntityFuncs.CastToScriptClass(pTowerEntity));
  }
  return null;
}

CBaseTower@ GetTower(CBaseEntity@ pEntity)
{
  return cast<CBaseTower>(g_EntityFuncs.CastToScriptClass(pEntity));
}

CSlowTower@ GetSlowTower(CBaseEntity@ pEntity)
{
  return cast<CSlowTower>(g_EntityFuncs.CastToScriptClass(pEntity));
}

CBaseTower@ GetGroundTower(Vector pos)
{
  if (g_groundTowers.exists(VectorString(pos)))
  {
    EHandle hGroundTower;
    g_groundTowers.get(VectorString(pos), hGroundTower);
    if (hGroundTower.IsValid())
    {
      return GetTower(hGroundTower.GetEntity());
    }
  }
  return null;
}

bool IsGroundTower(Vector pos)
{
  return GetGroundTower(pos) !is null;
}

bool IsGroundEntity(CBaseEntity@ pEntity)
{
  return pEntity is null || (pEntity.pev.solid == SOLID_BSP && string(pEntity.pev.classname) != "trigger_cameratarget");
}

bool IsNoTowerEntity(CBaseEntity@ pEntity)
{
  return pEntity !is null && string(pEntity.pev.targetname) == "notower";
}

bool CanSpawnTowerThere(Vector pos, CBaseEntity@ pGroundEntity, bool isBorderTower, bool isPathTower)
{
  return
    g_towerPositions.find(pos) == -1 &&
    !g_towerReservations.exists(VectorString(pos)) &&
    IsGroundEntity(pGroundEntity) &&
    !IsNoTowerEntity(pGroundEntity) &&
    (isPathTower == critterRouteManager.IsPath(pos)) &&
    (!isBorderTower || critterRouteManager.IsBorder(pos));
}

void ReserveTowerSpot(string towerModel, float towerModelScale, Vector pos, Vector angles, EHandle hGroundEntity)
{
  CSprite@ sprite = g_EntityFuncs.CreateSprite(towerModel, pos, false);
  sprite.TurnOff();
  sprite.SetTransparency(kRenderTransAdd, 0, 0, 0, 128, kRenderFxNone);
  sprite.pev.effects &= ~EF_NODRAW;
  sprite.pev.sequence = 0;
  sprite.pev.framerate = 0;
  sprite.pev.frame = 0;
  sprite.pev.scale = towerModelScale;
  sprite.pev.angles = angles;
  g_EntityFuncs.SetSize(sprite.pev, Vector(-32,-32,0), Vector(32,32,64));
  g_towerReservations[VectorString(pos)] = EHandle(sprite);
}

Vector GetAnglesFromReservedTowerSpot(Vector pos)
{
  Vector angles;
  if (g_towerReservations.exists(VectorString(pos)))
  {
    EHandle hSprite;
    g_towerReservations.get(VectorString(pos), hSprite);
    if (hSprite.IsValid())
    {
      angles = hSprite.GetEntity().pev.angles;
    }
  }
  return angles;
}

void UnReserveTowerSpot(Vector pos)
{
  if (g_towerReservations.exists(VectorString(pos)))
  {
    EHandle hSprite;
    g_towerReservations.get(VectorString(pos), hSprite);
    if (hSprite.IsValid())
    {
      hSprite.GetEntity().pev.effects |= EF_NODRAW;
      hSprite.GetEntity().pev.flags |= FL_KILLME;
    }
    g_towerReservations.delete(VectorString(pos));
  }
}

void SpawnTower(string towerEntityClassname, Vector pos, EHandle hGroundEntity, Worker@ worker)
{
  Vector angles = GetAnglesFromReservedTowerSpot(pos);
  dictionary itemKeyValues = {
    {"origin", OriginString(pos.x, pos.y, pos.z)},
    {"angles", AnglesString(angles.x, angles.y, angles.z)}
  };
  CBaseEntity@ tower = g_EntityFuncs.CreateEntity(towerEntityClassname, @itemKeyValues);
  g_towerPositions.insertLast(pos);
  g_groundTowers[VectorString(pos)] = EHandle(tower);
  GetTower(tower).SetWorker(worker);
  UnReserveTowerSpot(pos);
}

void RemoveTower(CBaseTower@ pTower)
{
  Vector pos = pTower.self.pev.origin;
  
  uint index = g_towerPositions.find(pos);
  if (index >= 0)
  {
    g_towerPositions.removeAt(index);
  }
  
  if (g_groundTowers.exists(VectorString(pos)))
  {
    g_groundTowers.delete(VectorString(pos));
  }
  
  pTower.self.pev.flags |= FL_KILLME;
  pTower.self.pev.effects |= EF_NODRAW;
}

