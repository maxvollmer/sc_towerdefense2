
const int XEN_TREE_IDLE_SEQUENCE = 0;
const int XEN_TREE_ATTACK_SEQUENCE = 1;

const int XEN_TREE_AE_HACK = 1;

const array<string> XEN_TREE_ATTACK_HIT_SOUNDS = 
{
  "zombie/claw_strike1.wav",
  "zombie/claw_strike2.wav",
  "zombie/claw_strike3.wav"
};

const array<string> XEN_TREE_ATTACK_WOOSH_SOUNDS = 
{
  "zombie/claw_miss1.wav",
  "zombie/claw_miss2.wav"
};

class XenTreeTower : CBaseTower
{
  private float m_flFramerate;
  
  private int m_iDamage;
  private float m_flSpeed;
  
  private float m_flMaxSpeed = 3;
  private int m_iMaxDamage = 50;
  
  private bool m_fIsAttacking;
  private float m_flNextAttackTime;
  
  private float m_flTargetZoneMinX;
  private float m_flTargetZoneMaxX;
  private float m_flTargetZoneMinY;
  private float m_flTargetZoneMaxY;
  
  void Spawn()
  {
    Precache();
    InitTowerValues();
    
    m_flFramerate = 0.1;
    
    m_fIsAttacking = false;
    m_flNextAttackTime = 0;
    
    m_iDamage = 1;
    m_flSpeed = 1;
    
    Vector vecDir;
    Vector vecRight;
    g_EngineFuncs.AngleVectors(self.pev.angles, vecDir, vecRight, NullVector);
    vecDir = vecDir.Normalize();
    vecRight = vecRight.Normalize();
    
    float x1 = self.pev.origin.x + (vecDir.x * (GRID_SIZE/2)) - (vecRight.x * (GRID_SIZE/2));
    float x2 = self.pev.origin.x + (vecDir.x * (GRID_SIZE/2)) + (vecDir.x * GRID_SIZE*2) + (vecRight.x * (GRID_SIZE/2));
    
    float y1 = self.pev.origin.y + (vecDir.y * (GRID_SIZE/2)) - (vecRight.y * (GRID_SIZE/2));
    float y2 = self.pev.origin.y + (vecDir.y * (GRID_SIZE/2)) + (vecDir.y * GRID_SIZE*2) + (vecRight.y * (GRID_SIZE/2));
    
    m_flTargetZoneMinX = Math.min(x1, x2);
    m_flTargetZoneMaxX = Math.max(x1, x2);
    
    m_flTargetZoneMinY = Math.min(y1, y2);
    m_flTargetZoneMaxY = Math.max(y1, y2);
    
    SetSequence(XEN_TREE_IDLE_SEQUENCE);
    self.pev.nextthink = g_Engine.time + Math.RandomFloat(0, m_flFramerate);
  }

  void Precache()
  {
    g_Game.PrecacheModel(GetModel());
    for (uint i = 0, n = XEN_TREE_ATTACK_WOOSH_SOUNDS.size(); i < n; i++)
    {
      g_SoundSystem.PrecacheSound(XEN_TREE_ATTACK_WOOSH_SOUNDS[i]);
    }
    for (uint i = 0, n = XEN_TREE_ATTACK_HIT_SOUNDS.size(); i < n; i++)
    {
      g_SoundSystem.PrecacheSound(XEN_TREE_ATTACK_HIT_SOUNDS[i]);
    }
  }

  void Think()
  {
    if (globalGameOver)
    {
      self.pev.flags |= FL_KILLME;
      return;
    }
    self.pev.nextthink = g_Engine.time + m_flFramerate;
    
    float flFrameTime = Animate(m_flFramerate, m_fIsAttacking ? m_flSpeed : 1);
    
    if (m_fIsAttacking && self.m_fSequenceFinished)
    {
      m_fIsAttacking = false;
      m_flNextAttackTime = g_Engine.time + (0.25 + m_flMaxSpeed - m_flSpeed);
      SetSequence(XEN_TREE_IDLE_SEQUENCE);
    }
    
    if (!m_fIsAttacking && g_Engine.time >= m_flNextAttackTime && HasCrittersInTargetZone())
    {
      self.m_fSequenceFinished = false;
      m_fIsAttacking = true;
      SetSequence(XEN_TREE_ATTACK_SEQUENCE);
      g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_WEAPON, XEN_TREE_ATTACK_WOOSH_SOUNDS[Math.RandomLong(0,XEN_TREE_ATTACK_WOOSH_SOUNDS.size()-1)], 1, ATTN_NORM, 0, Math.RandomLong(95,105));
    }
  }

  void HandleAnimEvent(MonsterEvent@ pEvent)
  {
    if ( pEvent.event == XEN_TREE_AE_HACK )
    {
      bool hitACritter = HurtCrittersInTargetZone();
      if (hitACritter)
      {
        g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_WEAPON, XEN_TREE_ATTACK_HIT_SOUNDS[Math.RandomLong(0,XEN_TREE_ATTACK_HIT_SOUNDS.size()-1)], 1, ATTN_NORM, 0, Math.RandomLong(95,105));
      }
    }
  }

  private bool IsInTargetZone(CBaseEntity@ pEntity)
  {
    return
      pEntity !is null &&
      GetCritter(pEntity) !is null &&
      !GetCritter(pEntity).IsFlying() &&
      pEntity.pev.origin.x >= m_flTargetZoneMinX &&
      pEntity.pev.origin.x <= m_flTargetZoneMaxX &&
      pEntity.pev.origin.y >= m_flTargetZoneMinY &&
      pEntity.pev.origin.y <= m_flTargetZoneMaxY;
  }

  private bool HasCrittersInTargetZone()
  {
    CBaseEntity@ pEntity = null;
    while ((@pEntity=g_EntityFuncs.FindEntityByTargetname(pEntity, "critter")) !is null)
    {
      if (IsInTargetZone(pEntity))
      {
        return true;
      }
    }
    return false;
  }

  private bool HurtCrittersInTargetZone()
  {
    bool hitACritter = false;
    CBaseEntity@ pEntity = null;
    while ((@pEntity=g_EntityFuncs.FindEntityByTargetname(pEntity, "critter")) !is null)
    {
      if (IsInTargetZone(pEntity))
      {
        pEntity.TakeDamage(self.pev, GetWorker().self.pev, m_iDamage, DMG_GENERIC);
        hitACritter = true;
      }
    }
    return hitACritter;
  }

  // CBaseTower implementations
  string GetModel() { return "models/tree.mdl"; }
  float GetModelScale() { return 1; }
  float GetMenuModelScale() { return 0.5; }
  int GetMenuSequence() { return XEN_TREE_ATTACK_SEQUENCE; }
  bool IsBorderTower() { return false; }
  
  string GetDisplayName() { return "Xen Tree Tower"; }
  string GetDescription()
  {
    return
      "Melee tower.\n\n"+
      "Attacks ground units only.";
  }
  
  private string GetSpeed() { return ""+m_flSpeed; }
  private string GetDamage() { return ""+m_iDamage; }
  
  int GetPrice() { return 10; }
  
  string[] GetAdditionalInfo()
  {
    string[] returnValue = {
      "Speed: "+GetSpeed(),
      "Damage: "+GetDamage()
    };
    return returnValue;
  }
  
  TowerUpgradeInfo[] GetUpgradeInfo()
  {
    TowerUpgradeInfo[] returnValue = {
      TowerUpgradeInfo("speed", "Upgrade Speed", 5, UPGRADE_SPEED_SPRITE, m_flSpeed < m_flMaxSpeed, ""+m_flSpeed, ""+(m_flSpeed+0.5), ""+m_flMaxSpeed),
      TowerUpgradeInfo("damage", "Upgrade Damage", 5, UPGRADE_DAMAGE_SPRITE, m_iDamage < m_iMaxDamage, ""+m_iDamage, ""+(m_iDamage+1), ""+m_iMaxDamage)
    };
    return returnValue;
  }
  
  void Upgrade(TowerUpgradeInfo@ upgradeInfo)
  {
    if (globalGameOver)
    {
      self.pev.flags |= FL_KILLME;
      return;
    }
    AddUpgradeCost(upgradeInfo.cost);
    if (upgradeInfo.id == "damage")
    {
      if (m_iDamage < m_iMaxDamage)
        m_iDamage += 1;
    }
    else if (upgradeInfo.id == "speed")
    {
      if (m_flSpeed < m_flMaxSpeed)
        m_flSpeed += 0.5;
    }
  }
};

