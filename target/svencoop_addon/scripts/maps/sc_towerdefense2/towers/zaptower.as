
const int ISLAVE_AE_CLAW = 1;
const int ISLAVE_AE_CLAWRAKE = 2;
const int ISLAVE_AE_ZAP_POWERUP = 3;
const int ISLAVE_AE_ZAP_SHOOT = 4;
const int ISLAVE_AE_ZAP_DONE = 5;

const int ISLAVE_ATTACHEMENT_LEFT = 1;
const int ISLAVE_ATTACHEMENT_RIGHT = 2;

const int ISLAVE_RUN_SEQUENCE = 6;

class ZapTower : CBaseTower
{
  private float m_flFramerate;
  private EHandle m_hTargetCritter;

  private float m_flRange;
  private int m_iDamage;
  private int m_iAccuracy;
  private int m_iDamageType;
  private float m_flSpeed;
  
  private float m_flMaxSpeed = 5;
  private float m_flMaxRange = 1024;
  private int m_iMaxDamage = 50;
  
  private bool m_fHitTarget;
  private bool m_fIsInAttack;
  private bool m_fPowerUpSound;
  
  private float m_flZapTime;
  private EHandle m_hBeam;
  
  void Spawn()
  {
    Precache();
    InitTowerValues();
    
    m_flFramerate = 0.1;
    m_flZapTime = 0;
    m_fIsInAttack = false;
    m_fPowerUpSound = false;
    
    m_fHitTarget = false;
    m_flRange = 256;
    m_iDamage = 1;
    m_iDamageType = 0;
    m_iAccuracy = 50;
    m_flSpeed = 1;
    
    SetActivity(ACT_IDLE);
    self.pev.nextthink = g_Engine.time + Math.RandomFloat(0, m_flFramerate);
  }

  void Precache()
  {
    g_Game.PrecacheModel(GetModel());
    g_Game.PrecacheModel("sprites/lgtning.spr");
    g_SoundSystem.PrecacheSound("debris/zap4.wav");
    g_SoundSystem.PrecacheSound("hassault/hw_shoot1.wav");
    g_SoundSystem.PrecacheSound("weapons/electro4.wav");
  }

  void Think()
  {
    if (globalGameOver)
    {
      self.pev.flags |= FL_KILLME;
      return;
    }
    self.pev.nextthink = g_Engine.time + m_flFramerate;
    
    float flFrameTime = Animate(m_flFramerate, m_fIsInAttack ? m_flSpeed : 1);
    
    if (self.m_fSequenceFinished || !m_hTargetCritter.IsValid())
    {
      KillBeam();
      FindCritter();
      if (m_hTargetCritter.IsValid())
      {
        FaceCritter();
        SetActivity(ACT_RANGE_ATTACK1);
        m_fIsInAttack = true;
        m_fPowerUpSound = false;
      }
      else if (m_fIsInAttack || self.m_fSequenceFinished)
      {
        SetActivity(ACT_IDLE);
        m_fIsInAttack = false;
      }
    }
    else if (m_hTargetCritter.IsValid())
    {
      FaceCritter();
    }
  }

  private void FaceCritter()
  {
    if (m_hTargetCritter.IsValid())
    {
      Vector dir = m_hTargetCritter.GetEntity().pev.origin - self.pev.origin;
      self.pev.angles.y = FixAngle(atan2(dir.y, dir.x) * 180.0 / Math.PI);
    }
  }

  private void FindCritter()
  {
    float flLastDist = m_flRange;
    CBaseEntity@ pEntity = null;
    while ((@pEntity=g_EntityFuncs.FindEntityByTargetname(pEntity, "critter")) !is null)
    {
      // do smth
      float dist = (self.pev.origin-pEntity.pev.origin).Length2D();
      if (dist < flLastDist)
      {
        m_hTargetCritter = EHandle(pEntity);
        flLastDist = dist;
      }
    }
  }

  void HandleAnimEvent(MonsterEvent@ pEvent)
  {
    switch( pEvent.event )
    {
      case ISLAVE_AE_ZAP_POWERUP:
        PowerUpZap();
        break;
      case ISLAVE_AE_ZAP_SHOOT:
        Zap();
        break;
      case ISLAVE_AE_ZAP_DONE:
        ZapDone();
        break;
    }
  }

  private void PowerUpZap()
  {
    if (!m_fPowerUpSound)
    {
      g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_WEAPON, "debris/zap4.wav", 1, ATTN_NORM, 0, Math.RandomLong(100, 200));
      m_fPowerUpSound = true;
    }
  }

  private void Zap()
  {
    KillBeam();
    m_fPowerUpSound = false;
    CBeam@ pBeam = g_EntityFuncs.CreateBeam("sprites/lgtning.spr", 50);
    Vector vecEndPos;
    if (m_hTargetCritter.IsValid())
    {
      if (Math.RandomLong(0, 100) < m_iAccuracy && (self.pev.origin-m_hTargetCritter.GetEntity().pev.origin).Length2D() < m_flRange)
      {
        m_fHitTarget = true;
        vecEndPos = m_hTargetCritter.GetEntity().pev.origin;
        pBeam.EntsInit(m_hTargetCritter.GetEntity().entindex(), self.entindex());
      }
      else
      {
        m_fHitTarget = false;
        Vector vDirection;
        g_EngineFuncs.AngleVectors(self.pev.angles, vDirection, NullVector, NullVector);
        vecEndPos = self.pev.origin + vDirection * m_flRange;
        pBeam.PointEntInit(vecEndPos, self.entindex());
      }
      pBeam.SetEndAttachment(Math.RandomLong(0, 2)==0 ? ISLAVE_ATTACHEMENT_LEFT : ISLAVE_ATTACHEMENT_RIGHT);
      //pBeam.SetColor( 255, 40, 16 );
      pBeam.SetColor( 96, 128, 16 );
      pBeam.SetBrightness( 255 );
      pBeam.SetNoise( 20 );
      m_hBeam = EHandle(pBeam);
      g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_WEAPON, "hassault/hw_shoot1.wav", 1, ATTN_NORM, 0, Math.RandomLong(130, 160));
      g_SoundSystem.EmitAmbientSound(self.edict(), vecEndPos, "weapons/electro4.wav", 0.5, ATTN_NORM, 0, Math.RandomLong(140, 160));
      m_flZapTime = g_Engine.time;
    }
    else
    {
      m_hTargetCritter = null;
      m_fHitTarget = false;
      KillBeam(true);
      SetActivity(ACT_IDLE);
      m_fIsInAttack = false;
    }
  }

  private void ZapDone()
  {
    if (m_hTargetCritter.IsValid() && m_fHitTarget)
    {
      m_hTargetCritter.GetEntity().TakeDamage(self.pev, GetWorker().self.pev, m_iDamage, m_iDamageType);
    }
    m_hTargetCritter = null;
    m_fHitTarget = false;
    KillBeam();
  }

  private void KillBeam(bool fForced = false)
  {
    if (m_hBeam.IsValid())
    {
      if (g_Engine.time > m_flZapTime || fForced)
      {
        m_hBeam.GetEntity().pev.effects |= EF_NODRAW;
        m_hBeam.GetEntity().pev.flags |= FL_KILLME;
        m_hBeam = null;
      }
      else
      {
        // Make sure beam is visible even with really fast towers that are done shooting in the same frame
        g_Scheduler.SetTimeout("RemoveEntityDelayed", 0.1, EHandle(m_hBeam));
      }
    }
  }
  
  // CBaseTower implementations
  string GetModel() { return "models/hlclassic/islave.mdl"; }
  float GetModelScale() { return 1; }
  float GetMenuModelScale() { return 1.25; }
  int GetMenuSequence() { return ISLAVE_RUN_SEQUENCE; }
  bool IsBorderTower() { return false; }
  
  string GetDisplayName() { return "Alien Zap Tower"; }
  string GetDescription()
  {
    return
      "Cheap starting tower.\n"+
      "Powerful on maximum upgrade.\n\n"+
      "Shoots beams of lightning.\n"+
      "Attacks ground and flying. No splash.";
  }
  
  private string GetSpeed() { return ""+m_flSpeed; }
  private string GetDamage() { return ""+m_iDamage; }
  private string GetAccuracy() { return ""+m_iAccuracy+"%"; }
  private string GetRange() { return ""+m_flRange; }
  
  int GetPrice() { return 15; }
  
  string[] GetAdditionalInfo()
  {
    string[] returnValue = {
      "Speed: "+GetSpeed(),
      "Damage: "+GetDamage(),
      "Range: "+GetRange(),
      "Accuracy: "+GetAccuracy()
    };
    return returnValue;
  }
  
  TowerUpgradeInfo[] GetUpgradeInfo()
  {
    TowerUpgradeInfo[] returnValue = {
      TowerUpgradeInfo("speed", "Upgrade Speed", 5, UPGRADE_SPEED_SPRITE, m_flSpeed < m_flMaxSpeed, ""+m_flSpeed, ""+(m_flSpeed+0.5), ""+m_flMaxSpeed),
      TowerUpgradeInfo("damage", "Upgrade Damage", 5, UPGRADE_DAMAGE_SPRITE, m_iDamage < m_iMaxDamage, ""+m_iDamage, ""+(m_iDamage+1), ""+m_iMaxDamage),
      TowerUpgradeInfo("range", "Upgrade Range", 5, UPGRADE_RANGE_SPRITE, m_flRange < m_flMaxRange, ""+m_flRange, ""+(m_flRange+16), ""+m_flMaxRange),
      TowerUpgradeInfo("accuracy", "Upgrade Accuracy", 5, UPGRADE_ACCURACY_SPRITE, m_iAccuracy < 100, ""+m_iAccuracy, ""+(m_iAccuracy+5), ""+100)
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
    if (upgradeInfo.id == "speed")
    {
      if (m_flSpeed < m_flMaxSpeed)
        m_flSpeed += 0.5;
    }
    else if (upgradeInfo.id == "damage")
    {
      if (m_iDamage < m_iMaxDamage)
        m_iDamage += 1;
    }
    else if (upgradeInfo.id == "range")
    {
      if (m_flRange < m_flMaxRange)
        m_flRange += 16;
    }
    else if (upgradeInfo.id == "accuracy")
    {
      if (m_iAccuracy < 100)
        m_iAccuracy += 5;
    }
  }
  
  void OnDestroy()
  {
    KillBeam();
  }
};

