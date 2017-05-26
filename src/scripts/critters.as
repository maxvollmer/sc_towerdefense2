
const int FLYING_CRITTER_Z_OFFSET = 128;

const int CRITTER_HEALTHBAR_FRAMES = 30;
const int CRITTER_REACHED_GOAL_DIST = 8;

dictionary critterBlockers;   // Vector (position) -> EHandle

class Critter : CBaseTD
{
  private EHandle m_hCurrentGoal;
  
  private EHandle m_hHealthbarSprite;
  
  private Vector m_vDirection;
  private bool m_fWasBlocked;
  
  private float m_flFramerate;
  
  private float m_flMaxHealth;
  private float m_iSpeed;
  private float m_flUnclutterSpeedTime;
  
  private bool m_fInvisible = false;
  private bool m_fFlying = false;
  private bool m_fIsBoss = false;
  
  private EHandle m_hBlockerOwner;
  private float m_flBlockerDamage = 0;
  
  private int m_iKillMoney;
  
  private array<ComparableEHandle> critterSlowers;
  
  void Spawn()
  {
    g_EntityFuncs.SetModel(self, self.pev.model);
    g_EntityFuncs.SetSize(self.pev, Vector(-32,-32,0), Vector(32,32,64));
    self.pev.movetype = MOVETYPE_NOCLIP;
    self.pev.solid = SOLID_BBOX;
    self.pev.takedamage = DAMAGE_YES;
    self.m_bloodColor = DONT_BLEED;
    
    m_fWasBlocked = false;
    m_flUnclutterSpeedTime = 0;
    
    CSprite@ pHealthbarSprite = g_EntityFuncs.CreateSprite(HEALTHBAR_SPRITE, self.pev.origin, false, 0);
    pHealthbarSprite.SetTransparency(kRenderTransAlpha, 0, 0, 0, 255, 0);
    //pHealthbarSprite.SetAttachment(self.edict(), 0); // TODO: Use models with attachement in future
    pHealthbarSprite.SetScale(1);
    pHealthbarSprite.TurnOn();
    pHealthbarSprite.pev.frame = CRITTER_HEALTHBAR_FRAMES;
    m_hHealthbarSprite = EHandle(pHealthbarSprite);
    
    m_flFramerate = 0.1;
    self.pev.nextthink = g_Engine.time + Math.RandomFloat(0, m_flFramerate);
    
    SetActivity(ACT_RUN);
  }

  bool KeyValue(const string& in key, const string& in value)
  {
    if (key == "spawnPointName")
    {
      m_hCurrentGoal = EHandle(g_EntityFuncs.FindEntityByTargetname(null, value));
      return true;
    }
    else if (key == "critterHealth")
    {
      m_flMaxHealth = self.pev.health = atof(value);
      return true;
    }
    else if (key == "critterSpeed")
    {
      m_iSpeed = atoi(value);
      return true;
    }
    else if (key == "invisible")
    {
      m_fInvisible = atoi(value)!=0;
      return true;
    }
    else if (key == "flying")
    {
      m_fFlying = atoi(value)!=0;
      return true;
    }
    else if (key == "boss")
    {
      m_fIsBoss = atoi(value)!=0;
      return true;
    }
    else if (key == "killmoney")
    {
      m_iKillMoney = atoi(value);
      return true;
    }
    return false;
  }

  void Think()
  {
    if (globalGameOver)
    {
      self.pev.flags |= FL_KILLME;
      return;
    }
    if (!self.IsAlive())
    {
      return;
    }
    
    Animate(m_flFramerate, GetSlowDownFactor());
    Move();
    
    self.pev.nextthink = g_Engine.time + m_flFramerate;
  }

  void Move()
  {
    if (globalGameOver)
    {
      self.pev.flags |= FL_KILLME;
      return;
    }
    if (!m_hCurrentGoal.IsValid())
    {
      ReachedGoal();
      return;
    }
    
    if (IsBlocked())
    {
      self.pev.velocity = Vector(0,0,0);
      if (m_hHealthbarSprite.IsValid())
      {
        m_hHealthbarSprite.GetEntity().pev.origin = self.pev.origin + Vector(0,0,32);
        m_hHealthbarSprite.GetEntity().pev.velocity = self.pev.velocity;
        g_EntityFuncs.SetOrigin(m_hHealthbarSprite.GetEntity(), m_hHealthbarSprite.GetEntity().pev.origin);
      }
      m_fWasBlocked = true;
    }
    else
    {
      if (m_fWasBlocked)
      {
        TakeDamageFromBlocker();
        m_flUnclutterSpeedTime = g_Engine.time + 5;  // Randomize speed for the next 5 seconds so critters don't form a blob after being blocked
        m_fWasBlocked = false;
      }
      
      // DotProduct is positive when we passed the goal and zero when we are exactly on it
      if (DotProduct2D((self.pev.origin - m_hCurrentGoal.GetEntity().pev.origin), m_vDirection) >= 0)
      {
        EHandle m_hNextGoal = EHandle(g_EntityFuncs.FindEntityByTargetname(null, m_hCurrentGoal.GetEntity().pev.target));
        if (m_hNextGoal.IsValid())
        {
          self.pev.origin = m_hCurrentGoal.GetEntity().pev.origin;
          if (m_fFlying)
          {
            self.pev.origin.z += FLYING_CRITTER_Z_OFFSET;
          }
          self.pev.angles = m_hCurrentGoal.GetEntity().pev.angles;
          g_EntityFuncs.SetOrigin(self, self.pev.origin);
          g_EngineFuncs.AngleVectors(self.pev.angles, m_vDirection, NullVector, NullVector);
          m_hCurrentGoal = m_hNextGoal;
        }
        else
        {
          ReachedGoal();
          return;
        }
      }
      
      // Set velocity
      if (m_flUnclutterSpeedTime >= g_Engine.time)
      {
        self.pev.velocity = m_vDirection * (float(m_iSpeed) * GetSlowDownFactor() * Math.RandomFloat(1,1.5));
      }
      else
      {
        self.pev.velocity = m_vDirection * (float(m_iSpeed) * GetSlowDownFactor());
      }
      
      // Copy velocity and origin to healthbar sprite
      if (m_hHealthbarSprite.IsValid())
      {
        m_hHealthbarSprite.GetEntity().pev.origin = self.pev.origin + Vector(0,0,32);
        m_hHealthbarSprite.GetEntity().pev.velocity = self.pev.velocity;
        g_EntityFuncs.SetOrigin(m_hHealthbarSprite.GetEntity(), m_hHealthbarSprite.GetEntity().pev.origin);
      }
    }
  }

  private bool IsBlocked()
  {
    if (!m_fFlying)
    {
      array<string> critterBlockerKeys = critterBlockers.getKeys();
      for (uint i = 0, n = critterBlockerKeys.size(); i < n; i++)
      {
        EHandle hBlocker;
        critterBlockers.get(critterBlockerKeys[i], hBlocker);
        if (hBlocker.IsValid() && DotProduct2D((self.pev.origin - hBlocker.GetEntity().pev.origin), m_vDirection) < 0 && (self.pev.origin-hBlocker.GetEntity().pev.origin).Length2D() <= 64)
        {
          this.m_hBlockerOwner = EHandle(g_EntityFuncs.Instance(hBlocker.GetEntity().pev.owner));
          this.m_flBlockerDamage = hBlocker.GetEntity().pev.dmg;
          if (m_fIsBoss)
          {
            // bosses don't get blocked, but they do destroy the blocker (and receive damage if it causes damage)
            TakeDamageFromBlocker();
            hBlocker.GetEntity().pev.flags |= FL_KILLME;
            hBlocker.GetEntity().pev.effects |= EF_NODRAW;
            return false;
          }
          else
          {
            return true;
          }
        }
      }
    }
    return false;
  }

  private float GetSlowDownFactor()
  {
    float slowDownFactor = 1.0;
    for (uint i = 0, n = critterSlowers.size(); i < n; )
    {
      if (critterSlowers[i].IsValid())
      {
        float factor = GetSlowTower(critterSlowers[i].GetEntity()).GetSlowDownFactor();
        if (factor > 0.0)
        {
          slowDownFactor = slowDownFactor * factor;
        }
        i++;
      }
      else
      {
        critterSlowers.removeAt(i);
      }
    }
    return slowDownFactor;
  }

  void AddCritterSlower(CSlowTower@ pSlowTower)
  {
    if (globalGameOver)
    {
      self.pev.flags |= FL_KILLME;
      return;
    }
    ComparableEHandle hEntity = ComparableEHandle(pSlowTower.self);
    int index = critterSlowers.find(hEntity);
    if (index == -1)
    {
      critterSlowers.insertLast(hEntity);
    }
  }

  void RemoveCritterSlower(CSlowTower@ pSlowTower)
  {
    ComparableEHandle hEntity = ComparableEHandle(pSlowTower.self);
    int index = critterSlowers.find(hEntity);
    if (index >= 0)
    {
      critterSlowers.removeAt(index);
    }
  }

  private void TakeDamageFromBlocker()
  {
    entvars_t@ pevAttacker = self.pev;
    if (this.m_hBlockerOwner.IsValid())
    {
      @pevAttacker = this.m_hBlockerOwner.GetEntity().pev;
    }
    this.TakeDamage(pevAttacker, pevAttacker, this.m_flBlockerDamage, DMG_GENERIC);
    this.m_hBlockerOwner = null;
    this.m_flBlockerDamage = 0;
  }

  int TakeDamage(entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType)
  {
    if (globalGameOver)
    {
      self.pev.flags |= FL_KILLME;
      return 1;
    }
    if (pev.health <= 0 || pev.deadflag == DEAD_DEAD)
    {
      // Don't die twice!
      return 1;
    }
    self.pev.health -= flDamage;
    if (m_hHealthbarSprite.IsValid())
    {
      m_hHealthbarSprite.GetEntity().pev.frame = Math.min(Math.max(0, (self.pev.health / m_flMaxHealth) * CRITTER_HEALTHBAR_FRAMES), CRITTER_HEALTHBAR_FRAMES);
    }
    if (pev.health <= 0)
    {
      pev.deadflag = DEAD_DEAD;
      pev.effects |= EF_NODRAW;
      pev.flags |= FL_KILLME;
      DeathBlurp();
      
      array<ComparableEHandle> areadyReceivedMoneyWorkers;
      
      // Give money to worker who built tower that killed me:
      CBaseEntity@ pAttacker = g_EntityFuncs.Instance(pevAttacker);
      Worker@ worker = GetWorker(pAttacker);
      if (worker !is null)
      {
        worker.AddMoney(m_iKillMoney);
        areadyReceivedMoneyWorkers.insertLast(ComparableEHandle(worker.self));
      }
      
      // Give money to worker who built a blocker that blocked me while I was killed (but only if it didn't already get money):
      if (this.m_hBlockerOwner.IsValid() && this.m_hBlockerOwner.GetEntity().pev !is pevAttacker)
      {
        CBaseEntity@ pBlockerOwner = g_EntityFuncs.Instance(this.m_hBlockerOwner.GetEntity().pev);
        Worker@ blockerWorker = GetWorker(pBlockerOwner);
        if (blockerWorker !is null && areadyReceivedMoneyWorkers.find(ComparableEHandle(blockerWorker.self))==-1)
        {
          blockerWorker.AddMoney(m_iKillMoney);
          areadyReceivedMoneyWorkers.insertLast(ComparableEHandle(blockerWorker.self));
        }
      }
      
      // Give money to workers who built slow towers that slowed me while I was killed (but only if they didn't already get money):
      for (uint i = 0, n = critterSlowers.size(); i < n; i++)
      {
        if (critterSlowers[i].IsValid())
        {
          Worker@ slowTowerWorker = GetSlowTower(critterSlowers[i].GetEntity()).GetWorker();
          if (slowTowerWorker !is null && areadyReceivedMoneyWorkers.find(ComparableEHandle(slowTowerWorker.self))==-1)
          {
            slowTowerWorker.AddMoney(m_iKillMoney);
            areadyReceivedMoneyWorkers.insertLast(ComparableEHandle(slowTowerWorker.self));
          }
        }
      }
    }
    return 1;
  }

  private void ReachedGoal()
  {
    critterWaveManager.CritterEscaped(self.pev.health);
    pev.health = 0;
    pev.deadflag = DEAD_DEAD;
    pev.effects |= EF_NODRAW;
    pev.flags |= FL_KILLME;
    if (m_hHealthbarSprite.IsValid())
    {
      m_hHealthbarSprite.GetEntity().pev.effects |= EF_NODRAW;
      m_hHealthbarSprite.GetEntity().pev.flags |= FL_KILLME;
    }
  }

  void OnDestroy()
  {
    if (m_hHealthbarSprite.IsValid())
    {
      m_hHealthbarSprite.GetEntity().pev.effects |= EF_NODRAW;
      m_hHealthbarSprite.GetEntity().pev.flags |= FL_KILLME;
    }
    critterWaveManager.CritterDown();
  }

  void DeathBlurp()
  {
    // TODO: Gibs / blood / effects...
  }
  
  bool IsFlying()
  {
    return m_fFlying;
  }
  
  bool IsInvisible()
  {
    return m_fInvisible;
  }
  
  bool IsBoss()
  {
    return m_fIsBoss;
  }
};

Critter@ GetCritter(CBaseEntity@ pEntity)
{
  return cast<Critter>(g_EntityFuncs.CastToScriptClass(pEntity));
}
