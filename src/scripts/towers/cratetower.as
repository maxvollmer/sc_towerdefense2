
const int FORKLIFT_SEQUENCE_IDLE = 0;
const int FORKLIFT_SEQUENCE_JOCKEY = 3;

const int CRATE_WEAK = 0;
const int CRATE_NORMAL = 1;
const int CRATE_STRONG = 2;
const int CRATE_METAL = 3;
const int CRATE_EXPLOSIVE = 4;

const int CRATE_OFFSET_Z = 32;

class CrateTower : CBaseTower
{
  private float m_flFramerate;
  
  private bool m_fHasCrate;
  private bool m_fIsSpawningCrate;
  private float m_flNextSpawnTime;
  private float m_flCrateDestroyTime;
  
  Vector crateOrigin;
  EHandle hCrate;
  int m_iCurrentCrateBody;
  
  private float m_flSpeed;
  private float m_flCrateLifetime;
  private float m_flExplosionDamage;
  
  private float m_flMaxSpeed = 5;
  private float m_flMaxCrateLifetime = 8;
  private float m_flMaxExplosionDamage = 100;
  
  private int m_iCrateBody;
  
  private int metalGibModelIndex;
  private int woodGibModelIndex;
  
  void Spawn()
  {
    Precache();
    InitTowerValues();
    
    m_flFramerate = 0.1;
    m_fHasCrate = false;
    m_fIsSpawningCrate = false;
    m_flNextSpawnTime = 0;
    m_flCrateDestroyTime = 0;
    
    m_flExplosionDamage = 0;
    
    m_flCrateLifetime = 0.5;
    m_flSpeed = 1;
    
    m_iCurrentCrateBody = m_iCrateBody = CRATE_WEAK;
    
    SetSequence(FORKLIFT_SEQUENCE_IDLE);
    self.pev.nextthink = g_Engine.time + Math.RandomFloat(0, m_flFramerate);
  }

  void Precache()
  {
    g_Game.PrecacheModel(GetModel());
    g_Game.PrecacheModel("models/sc_towerdefense2/crate.mdl");
    g_SoundSystem.PrecacheSound("debris/bustmetal1.wav");
    g_SoundSystem.PrecacheSound("debris/bustmetal2.wav");
    g_SoundSystem.PrecacheSound("debris/bustcrate1.wav");
    g_SoundSystem.PrecacheSound("debris/bustcrate2.wav");
    metalGibModelIndex = g_Game.PrecacheModel("models/metalgibs.mdl");
    woodGibModelIndex = g_Game.PrecacheModel("models/woodgibs.mdl");
  }

  void Think()
  {
    if (globalGameOver)
    {
      self.pev.flags |= FL_KILLME;
      return;
    }
    self.pev.nextthink = g_Engine.time + m_flFramerate;
    
    float flFrameTime = Animate(m_flFramerate, m_fIsSpawningCrate ? m_flSpeed : 1);
    
    if (self.m_fSequenceFinished && m_fIsSpawningCrate)
    {
      self.m_fSequenceFinished = false;
      m_fIsSpawningCrate = false;
      m_fHasCrate = true;
      SpawnCrate();
      SetSequence(FORKLIFT_SEQUENCE_IDLE);
    }
    
    if (m_fHasCrate)
    {
      // crate got removed from game or time is up
      if (!hCrate.IsValid() || g_Engine.time > m_flCrateDestroyTime)
      {
        DestroyCrate();
      }
    }
    
    if (!m_fIsSpawningCrate && !m_fHasCrate && g_Engine.time >= m_flNextSpawnTime)
    {
      self.m_fSequenceFinished = false;
      m_fIsSpawningCrate = true;
      SetSequence(FORKLIFT_SEQUENCE_JOCKEY);
    }
  }

  private void SpawnCrate()
  {
    if (hCrate.IsValid())
    {
      // we still have a crate!
      return;
    }
    crateOrigin = self.pev.origin + GetCrateOffset();
    CSprite@ pCrate = g_EntityFuncs.CreateSprite("models/sc_towerdefense2/crate.mdl", crateOrigin, false, 0);
    pCrate.pev.targetname = "critterblocker";
    pCrate.pev.body = m_iCrateBody;
    pCrate.pev.angles = Vector(0,180,0);
    @pCrate.pev.owner = GetWorker().self.edict();
    if (IsCrateExplosive(m_iCrateBody))
    {
      pCrate.pev.dmg = m_flExplosionDamage;
    }
    m_iCurrentCrateBody = pCrate.pev.body;
    hCrate = EHandle(pCrate);
    m_flCrateDestroyTime = g_Engine.time + m_flCrateLifetime;
    EHandle hOtherBlocker;
    critterBlockers.get(VectorString(crateOrigin), hOtherBlocker);
    if (hOtherBlocker.IsValid())
    {
      // Another blocker exists - destroy it
      hOtherBlocker.GetEntity().pev.flags |= FL_KILLME;
      hOtherBlocker.GetEntity().pev.effects |= EF_NODRAW;
    }
    critterBlockers.set(VectorString(crateOrigin), EHandle(pCrate));
  }

  private Vector GetCrateOffset()
  {
    float angle = FixAngle(self.pev.angles.y);
    if (angle == 90)
      return Vector(0, GRID_SIZE + GRID_SIZE/2, CRATE_OFFSET_Z);
    else if (angle == 180)
      return Vector(-GRID_SIZE - GRID_SIZE/2, 0, CRATE_OFFSET_Z);
    else if (angle == 270)
      return Vector(0, -GRID_SIZE - GRID_SIZE/2, CRATE_OFFSET_Z);
    else
      return Vector(GRID_SIZE + GRID_SIZE/2, 0, CRATE_OFFSET_Z);
  }

  private string GetBreakSound(int body)
  {
    if (IsCrateMetal(body))
    {
      return Math.RandomLong(0,1)==0 ? "debris/bustmetal1.wav" : "debris/bustmetal2.wav";
    }
    else
    {
      return Math.RandomLong(0,1)==0 ? "debris/bustcrate1.wav" : "debris/bustcrate2.wav";
    }
  }

  private bool IsCrateMetal(int body)
  {
    return body == CRATE_METAL;
  }

  private bool IsCrateExplosive(int body)
  {
    return body == CRATE_EXPLOSIVE;
  }

  private bool IsCrateStrong(int body)
  {
    return body == CRATE_STRONG;
  }

  private void DestroyCrate()
  {
    g_SoundSystem.EmitAmbientSound(null, crateOrigin, GetBreakSound(m_iCurrentCrateBody), 0.85, ATTN_NORM, 0, 100);
    
    NetworkMessage message(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, crateOrigin);
      message.WriteByte( TE_BREAKMODEL );
      // position
      message.WriteCoord( crateOrigin.x );
      message.WriteCoord( crateOrigin.y );
      message.WriteCoord( crateOrigin.z );
      // size
      message.WriteCoord( GRID_SIZE );
      message.WriteCoord( GRID_SIZE );
      message.WriteCoord( GRID_SIZE );
      // velocity
      message.WriteCoord(0); 
      message.WriteCoord(0);
      message.WriteCoord(0);
      // randomization
      message.WriteByte(Math.RandomLong(5,10)); 
      // Model
      message.WriteShort(IsCrateMetal(m_iCurrentCrateBody) ? metalGibModelIndex : woodGibModelIndex);
      // # of shards
      message.WriteByte(0);
      // duration
      message.WriteByte(Math.RandomLong(2,10));
      // flags
      message.WriteByte(IsCrateMetal(m_iCurrentCrateBody) ? BREAK_METAL : BREAK_WOOD);
    message.End();
    
    if (IsCrateExplosive(m_iCurrentCrateBody))
    {
      g_EntityFuncs.CreateExplosion(crateOrigin, Vector(), null, 100, false);
      // TODO: Cause damage (m_flExplosionDamage)
    }
    
    EHandle hCurrentBlocker;
    critterBlockers.get(VectorString(crateOrigin), hCurrentBlocker);
    if (hCurrentBlocker.IsValid() && hCrate.IsValid() && hCurrentBlocker.GetEntity() == hCrate.GetEntity())
    {
      critterBlockers.delete(VectorString(crateOrigin));
    }
    
    if (hCrate.IsValid())
    {
      hCrate.GetEntity().pev.flags |= FL_KILLME;
    }
    hCrate = null;
    m_fHasCrate = false;
    m_flNextSpawnTime = g_Engine.time + (1 + m_flMaxSpeed - m_flSpeed);
  }
  
  // CBaseTower implementations
  string GetModel() { return "models/forklift.mdl"; }
  float GetModelScale() { return 0.75; }
  float GetMenuModelScale() { return 0.6; }
  int GetMenuSequence() { return FORKLIFT_SEQUENCE_JOCKEY; }
  bool IsBorderTower() { return true; }
  
  string GetDisplayName() { return "Forklift Tower"; }
  string GetDescription()
  {
    return
      "Puts crates onto the path,\n"+
      "temporarily blocking ground units.\n\n"+
      "Special Tower: Does not attack.";
  }
  
  string GetSpeed() { return ""+m_flSpeed; }
  string GetCrateLifetime() { return ""+m_flCrateLifetime; }
  string GetDamage()
  {
    if (IsCrateExplosive(m_iCrateBody))
    {
      return ""+m_flExplosionDamage;
    }
    else
    {
      return "-";
    }
  }
  string GetDamageType() { return IsCrateExplosive(m_iCrateBody) ? "Fire" : "No damage."; }
  string GetSplash() { return IsCrateExplosive(m_iCrateBody) ? ("Explosion hits all blocked.") : "No splash"; }
  string GetAttackInfo() { return "Blocks ground units."; }
  
  int GetPrice() { return 30; }
  
  string[] GetAdditionalInfo()
  {
    string[] returnValue = {
      "Speed: "+GetSpeed(),
      "Crate Lifetime: "+GetCrateLifetime()
    };
    if (IsCrateExplosive(m_iCrateBody))
    {
      returnValue.insertLast("Explosion Damage: "+GetDamage());
    }
    return returnValue;
  }
  
  TowerUpgradeInfo[] GetUpgradeInfo()
  {
    TowerUpgradeInfo[] returnValue = {
      TowerUpgradeInfo("speed", "Upgrade Speed", 5, UPGRADE_SPEED_SPRITE, m_flSpeed < m_flMaxSpeed, ""+m_flSpeed, ""+(m_flSpeed+0.5), ""+m_flMaxSpeed)
    };
    if (IsCrateStrong(m_iCrateBody))
    {
      returnValue.insertLast(TowerUpgradeInfo("metal", "Upgrade To Metal Crate", 5, UPGRADE_TO_METALCRATE_SPRITE, true, "", "", ""));
      returnValue.insertLast(TowerUpgradeInfo("explosion", "Upgrade To Explosive Crate", 5, UPGRADE_TO_EXPLOSIVECRATE_SPRITE, true, "", "", ""));
    }
    else if (IsCrateExplosive(m_iCrateBody))
    {
      returnValue.insertLast(TowerUpgradeInfo("damage", "Upgrade Explosion Damage", 5, UPGRADE_DAMAGE_SPRITE, m_flExplosionDamage < m_flMaxExplosionDamage, ""+m_flExplosionDamage, ""+(m_flExplosionDamage+10), ""+m_flMaxExplosionDamage));
    }
    else if (IsCrateMetal(m_iCrateBody))
    {
      returnValue.insertLast(TowerUpgradeInfo("metalstrength", "Upgrade Crate Lifetime", 5, UPGRADE_STRENGTH_METAL_SPRITE, m_flCrateLifetime < m_flMaxCrateLifetime, ""+m_flCrateLifetime, ""+(m_flCrateLifetime+1), ""+m_flMaxCrateLifetime));
    }
    else
    {
      returnValue.insertLast(TowerUpgradeInfo("woodstrength", "Upgrade Crate Lifetime", 5, UPGRADE_STRENGTH_WOOD_SPRITE, true, ""+m_flCrateLifetime, ""+(m_flCrateLifetime+0.5), ""+CRATE_STRONG));
    }
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
    if (upgradeInfo.id == "speed")
    {
      if (m_flSpeed < m_flMaxSpeed)
        m_flSpeed += 0.5;
    }
    else if (upgradeInfo.id == "woodstrength")
    {
      m_flCrateLifetime += 0.5;
      m_iCrateBody = int(m_flCrateLifetime);
    }
    else if (upgradeInfo.id == "metalstrength")
    {
      if (m_flCrateLifetime < m_flMaxCrateLifetime)
        m_flCrateLifetime += 1;
    }
    else if (upgradeInfo.id == "damage")
    {
      if (m_flExplosionDamage < m_flMaxExplosionDamage)
        m_flExplosionDamage += 10;
    }
    else if (upgradeInfo.id == "metal")
    {
      m_flCrateLifetime = 3;
      m_iCrateBody = CRATE_METAL;
    }
    else if (upgradeInfo.id == "explosion")
    {
      m_flCrateLifetime = 2;
      m_iCrateBody = CRATE_EXPLOSIVE;
      m_flExplosionDamage = 50;
    }
  }
  
  void OnDestroy()
  {
    if (hCrate.IsValid())
    {
      DestroyCrate();
    }
  }
};


