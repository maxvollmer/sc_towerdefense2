
array<Worker@> workers;

const int SF_WORKER_FORCEVIEW = 1;

class Worker : CBaseTD
{
  private float m_flFramerate;
  private bool m_fFirstThink;
  
  private string[] towerEntityClassnames;
  private EHandle hCamera;
  
  private float m_flSpeed;
  
  private Vector m_vRunToLocation;
  private Vector m_vRunToAngles;
  private bool m_fIsRunning;
  
  private string m_szBuildTowerEntityClassname;
  private Vector m_vBuildTowerPos;
  private EHandle m_hBuildTowerGroundEntity;
  private bool m_fWantsToBuildTower;
  private bool m_fIsBuildingTower;
  private int m_iBuildCost;
  
  private string m_szCursorSpritename;
  private string m_iszComputerTerminalTargetname;
  
  private int m_iMoney;
  
  private EHandle m_hComputerTerminal;
  private int lastComputerTerminalHealth = 0;
  private int lastComputerTerminalMaxHealth = 0;
  
  private string m_szName;
  
  CameraData cameraData;
  Menu@ menu;
  
  void Spawn()
  {
    Precache();
    g_EntityFuncs.SetModel(self, self.pev.model);
    g_EntityFuncs.SetSize(self.pev, Vector(-32,-32,-32), Vector(32,32,32));
    self.pev.movetype = MOVETYPE_NOCLIP;
    self.pev.solid = SOLID_NOT;
    self.pev.takedamage = DAMAGE_NO;
    self.m_bloodColor = DONT_BLEED;
    self.pev.rendermode = kRenderTransTexture;
    self.pev.renderamt = 255;
    
    m_flSpeed = 400;
    
    m_fIsRunning = false;
    m_fWantsToBuildTower = false;
    m_fIsBuildingTower = false;
    m_iBuildCost = 0;
    
    SetActivity(ACT_IDLE);
    
    CheckName();
    
    m_fFirstThink = true;
    m_flFramerate = 0.01;
    self.pev.nextthink = g_Engine.time + m_flFramerate;
  }
  
  private void CheckName()
  {
    if (m_szName == "")
    {
      m_szName = self.pev.targetname;
    }
    if (m_szName == "")
    {
      m_szName = m_iszComputerTerminalTargetname;
    }
    if (m_szName == "")
    {
      m_szName = "I have no name :(";
    }
  }
  
  private void InitWorker()
  {
    CreateCamera();
    if (m_iszComputerTerminalTargetname != "")
    {
      this.m_hComputerTerminal = EHandle(g_EntityFuncs.FindEntityByTargetname(null, m_iszComputerTerminalTargetname));
    }
    @this.menu = Menu(this, towerEntityClassnames);
    workers.insertLast(this);
  }
  
  private void CreateCamera()
  {
    if (hCamera.IsValid())
    {
      return;
    }
    bool forceView = (self.pev.spawnflags & SF_WORKER_FORCEVIEW) != 0;
    
    dictionary itemKeyValues = {
      {"spawnflags", forceView?"980":"964"},  // 4|64|128|256|512 (|16 if forceview)
      {"origin", OriginString(self.pev.origin.x, self.pev.origin.y,  self.pev.origin.z + CAMERA_INITIAL_Z)},
      {"angles", "90 0 0"},
      {"targetname", string(self.pev.targetname)+"_camera"},
      {"m_iszASMouseEventCallbackName", "CameraMouseEventCallback"},
      {"m_iszTargetWhenPlayerStartsUsing", "EnterCameraCallback"},
      {"m_iszTargetWhenPlayerStopsUsing", "LeaveCameraCallback"},
      {"max_player_count", "1"},
      {"hud_health", "1"},
      {"hud_flashlight", "1"},
      {"hud_weapons", "1"}
    };
    
    if (m_szCursorSpritename != "")
    {
      itemKeyValues["cursor_sprite"] = m_szCursorSpritename;
    }
    
    this.hCamera = EHandle(g_EntityFuncs.CreateEntity("trigger_camera", @itemKeyValues));
  }
  
  void Precache()
  {
    g_Game.PrecacheModel(self.pev.model);
    if (m_szCursorSpritename != "")
    {
      g_Game.PrecacheModel(m_szCursorSpritename);
    }
    
    // Precache towers...
    for (uint i = 0, n = towerEntityClassnames.size(); i < n; i++)
    {
      dictionary keyvalues = {
        {"origin", "99999,99999,99999"}
      };
      CBaseEntity@ tempPrecacheTower = g_EntityFuncs.CreateEntity(towerEntityClassnames[i], @keyvalues);
      if (tempPrecacheTower !is null)
      {
        tempPrecacheTower.pev.flags |= FL_KILLME;
        tempPrecacheTower.pev.effects |= EF_NODRAW;
      }
    }
  }
  
  bool KeyValue(const string& in szKey, const string& in szValue)
  {
    if (szKey == "cursor_sprite")
    {
      m_szCursorSpritename = szValue;
      return true;
    }
    else if (szKey == "computer_terminal")
    {
      m_iszComputerTerminalTargetname = szValue;
      return true;
    }
    else if (szKey == "start_money")
    {
      m_iMoney = atoi(szValue);
      return true;
    }
    else if (szKey == "display_name")
    {
      m_szName = szValue;
      return true;
    }
    else if (szKey.StartsWith("tower"))
    {
      uint index = atoi(szKey.SubString(5));
      if (index < MAX_TOWER_COUNT)
      {
        if (towerEntityClassnames.size() <= index)
        {
          towerEntityClassnames.resize(index+1);
        }
        towerEntityClassnames[index] = szValue;
        return true;
      }
    }
    return false;
  }
  
  void Use(CBaseEntity@ pActivatior, CBaseEntity@ pCaller, USE_TYPE useType, float value)
  {
    if (hCamera.IsValid())
    {
      hCamera.GetEntity().Use(pActivatior, pCaller, useType, value);
    }
  }
  
  void Think()
  {
    if (m_fFirstThink)
    {
      InitWorker();
      m_fFirstThink = false;
    }
    
    float flFrameTime = Animate(m_flFramerate, 1);
    
    if (m_fIsRunning)
    {
      CheckMove(flFrameTime);
    }
    else if (m_fWantsToBuildTower)
    {
      BuildTower();
    }
    else if (m_fIsBuildingTower && self.m_fSequenceFinished)
    {
      SetActivity(ACT_IDLE);
      m_fIsBuildingTower = false;
      m_iBuildCost = 0;
    }
    
    if (HasComputerTerminal())
    {
      CBaseEntity@ pComputerTerminal = GetComputerTerminal();
      int computerTerminalHealth;
      int computerTerminalMaxHealth;
      if (pComputerTerminal !is null)
      {
        computerTerminalHealth = int(pComputerTerminal.pev.health);
        computerTerminalMaxHealth = int(pComputerTerminal.pev.max_health);
      }
      else
      {
        computerTerminalHealth = 0;
        computerTerminalMaxHealth = 0;
      }
      if (computerTerminalHealth != lastComputerTerminalHealth || computerTerminalMaxHealth != lastComputerTerminalMaxHealth)
      {
        menu.ComputerTerminalHealthChanged(computerTerminalHealth, computerTerminalMaxHealth);
      }
      if (computerTerminalHealth < lastComputerTerminalHealth)
      {
        menu.ComputerTerminalUnderAttackWarning();
      }
      else if (computerTerminalHealth > lastComputerTerminalHealth)
      {
        menu.ComputerTerminalRepairNotice();
      }
      lastComputerTerminalMaxHealth = computerTerminalMaxHealth;
      lastComputerTerminalHealth = computerTerminalHealth;
    }
    
    self.pev.nextthink = g_Engine.time + m_flFramerate;
  }
  
  private void CheckMove(float flFrameTime)
  {
    // DotProduct is negative when we passed the goal
    if (DotProduct2D((m_vRunToLocation - self.pev.origin), self.pev.velocity) <= 0)
    {
      self.pev.origin = m_vRunToLocation;
      self.pev.velocity = Vector();
      self.pev.angles = m_vRunToAngles;
      g_EntityFuncs.SetOrigin(self, self.pev.origin);
      m_fIsRunning = false;
      SetActivity(ACT_IDLE);
    }
  }
  
  private void BuildTower()
  {
    CSprite@ sprite = g_EntityFuncs.CreateSprite(TOWER_SPAWN_SPRITE, m_vBuildTowerPos + Vector(0,0,10), true);
    sprite.AnimateAndDie(20);
    sprite.SetTransparency(kRenderTransAdd, 0, 0, 0, 255, kRenderFxNone);
    sprite.SetScale(0.5);
    
    g_Scheduler.SetTimeout("SpawnTower", 0.5, m_szBuildTowerEntityClassname, m_vBuildTowerPos, m_hBuildTowerGroundEntity, @this);
    
    m_fWantsToBuildTower = false;
    m_fIsBuildingTower = true;
  }
  
  void CancelBuild()
  {
    if (m_fWantsToBuildTower)
    {
      AddMoney(m_iBuildCost);
      UnReserveTowerSpot(m_vBuildTowerPos);
      m_szBuildTowerEntityClassname = "";
      m_vBuildTowerPos = Vector();
      m_hBuildTowerGroundEntity = EHandle(null);
      m_fIsRunning = false;
      m_fWantsToBuildTower = false;
      SetActivity(ACT_IDLE);
      m_iBuildCost = 0;
    }
  }
  
  void Build(string towerEntityClassname, string towerModel, float towerModelScale, int gridX, int gridY, Vector angles, CBaseEntity@ pGroundEntity, int buildCost)
  {
    CancelBuild();
    m_szBuildTowerEntityClassname = towerEntityClassname;
    m_vBuildTowerPos = Vector(gridX, gridY, 0);
    m_hBuildTowerGroundEntity = EHandle(pGroundEntity);
    m_fWantsToBuildTower = true;
    m_iBuildCost = buildCost;
    
    // Find best location close to build pos and run there!
    int runToGridX;
    int runToGridY;
    float deltaX = abs(self.pev.origin.x - gridX);
    float deltaY = abs(self.pev.origin.y - gridY);
    Vector faceTowerAngles;
    if (deltaX > deltaY) // approaching from east or west
    {
      runToGridY = gridY;
      if (self.pev.origin.x < gridX)
      {
        runToGridX = gridX - GRID_SIZE;
        faceTowerAngles = Vector(0, 0, 0); // standing west of tower, facing east
      }
      else
      {
        runToGridX = gridX + GRID_SIZE;
        faceTowerAngles = Vector(0, 180, 0); // standing east of tower, facing west
      }
    }
    else // approaching from south or north
    {
      runToGridX = gridX;
      if (self.pev.origin.y < gridY)
      {
        runToGridY = gridY - GRID_SIZE;
        faceTowerAngles = Vector(0, 90, 0); // standing south of tower, facing north
      }
      else
      {
        runToGridY = gridY + GRID_SIZE;
        faceTowerAngles = Vector(0, 270, 0); // standing north of tower, facing south
      }
    }
    self.pev.angles = faceTowerAngles;
    RunTo(runToGridX, runToGridY);
    m_vRunToAngles = faceTowerAngles;
    
    ReserveTowerSpot(towerModel, towerModelScale, m_vBuildTowerPos, angles, m_hBuildTowerGroundEntity);
  }
  
  bool IsCamera(CBaseEntity@ pCamera)
  {
    return pCamera !is null && hCamera.IsValid() && pCamera == hCamera.GetEntity();
  }
  
  bool IsPlayer(CBaseEntity@ pPlayer)
  {
    return pPlayer !is null && pPlayer.IsPlayer() && menu.IsCurrentPlayer(pPlayer);
  }
  
  void RunTo(int gridX, int gridY)
  {
    m_vRunToLocation = Vector(gridX, gridY, self.pev.origin.z);
    if (self.pev.origin != m_vRunToLocation)
    {
      Vector runDir = (m_vRunToLocation-self.pev.origin).Normalize();
      runDir.z = 0;
      self.pev.velocity = runDir * m_flSpeed;
      self.pev.angles.y = atan2(runDir.y, runDir.x) * 180 / Math.PI;
      m_vRunToAngles = self.pev.angles;
      m_fIsRunning = true;
      SetActivity(ACT_RUN);
    }
  }
  
  bool CheckMoney(CBaseEntity@ pPlayer, int money)
  {
    return money <= m_iMoney;
  }
  
  bool CheckAndTakeMoney(CBaseEntity@ pPlayer, int money)
  {
    if (money <= m_iMoney)
    {
      m_iMoney -= money;
      menu.MoneyChanged(m_iMoney);
      return true;
    }
    else
    {
      return false;
    }
  }
  
  void AddMoney(int money)
  {
    m_iMoney += money;
    menu.MoneyChanged(m_iMoney);
  }
  
  int GetCurrentMoney()
  {
    return m_iMoney;
  }
  
  bool HasComputerTerminal()
  {
    return m_hComputerTerminal.IsValid();
  }
  
  CBaseEntity@ GetComputerTerminal()
  {
    return m_hComputerTerminal.GetEntity();
  }
  
  string GetName()
  {
    return m_szName;
  }
};

Worker@ GetWorker(CBaseEntity@ pEntity)
{
  return cast<Worker>(g_EntityFuncs.CastToScriptClass(pEntity));
}

Worker@ GetWorkerForCamera(CBaseEntity@ pCamera)
{
  for(uint i = 0, n = workers.length(); i < n; i++)
  {
    if (workers[i].IsCamera(pCamera))
    {
      return workers[i];
    }
  }
  return null;
}

Worker@ GetWorkerForPlayer(CBaseEntity@ pPlayer)
{
  for(uint i = 0, n = workers.length(); i < n; i++)
  {
    if (workers[i].IsPlayer(pPlayer))
    {
      return workers[i];
    }
  }
  return null;
}

bool IsWorkerField(Vector pos)
{
  return GetWorker(pos) !is null;
}

Worker@ GetWorker(Vector pos)
{
  for(uint i = 0, n = workers.length(); i < n; i++)
  {
    if ((workers[i].self.pev.origin - pos).Length2D() < GRID_SIZE)
    {
      return workers[i];
    }
  }
  return null;
}

