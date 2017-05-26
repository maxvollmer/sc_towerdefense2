
class ComparableEHandle
{
  private EHandle hEntity;
  ComparableEHandle() {}
  ComparableEHandle(EHandle hEntity)
  {
    this.hEntity = hEntity;
  }
  ComparableEHandle(CBaseEntity@ pEntity)
  {
    this.hEntity = EHandle(pEntity);
  }
  bool opEquals(const ComparableEHandle &in other) const
  {
    return IsValid() && other.IsValid() && GetEntity() == other.GetEntity();
  }
  CBaseEntity@ GetEntity() const
  {
    return hEntity.GetEntity();
  }
  bool IsValid() const
  {
    return hEntity.IsValid();
  }
};


abstract class CBaseTD : ScriptBaseMonsterEntity
{
  private float m_flLastTime = 0;
  private bool m_fFirstTime = true;
  
  private bool IsValidModel()
  {
    return string(self.pev.model).EndsWith(".mdl");
  }
  
  protected void SetActivity(Activity act) 
  {
    SetActivity(act, false);
  }
  
  protected void SetActivity(Activity act, bool noSequenceBox) 
  {
    if (IsValidModel())
    {
      SetSequence(self.LookupActivity(act), noSequenceBox);
    }
    else
    {
      SetSequence(0, noSequenceBox);
    }
  }
  
  protected void SetSequence(int sequence) 
  {
    SetSequence(sequence, false);
  }
  
  protected void SetSequence(int sequence, bool noSequenceBox) 
  {
    if (sequence < 0)
    {
      sequence = 0;
    }
    self.m_fSequenceFinished = false;
    self.pev.sequence = sequence;
    self.pev.framerate = 0;
    self.pev.frame = 0;
    if (IsValidModel())
    {
      self.ResetSequenceInfo();
      if (!noSequenceBox)
      {
        self.SetSequenceBox();
      }
    }
  }
  
  protected float Animate(float flFramerate, float flSpeed)
  {
    if (m_fFirstTime)
    {
      self.InitBoneControllers();
      m_fFirstTime = false;
    }
    if (m_flLastTime == 0)
    {
      // First frame, wait till next to animate
      m_flLastTime = g_Engine.time;
      return flFramerate;
    }
    float flFrameTime = g_Engine.time - m_flLastTime;
    m_flLastTime = g_Engine.time;
    
    self.pev.framerate = flSpeed * flFrameTime/0.1;  // Account for bug in DispatchAnimEvents (flInterval is fixed at 0.1)
    if (IsValidModel())
    {
      self.StudioFrameAdvance(0.1);   // Always sent 0.1, because DispatchAnimEvents has bug that overrides flInterval no matter what is send as parameter. Instead we encode flInterval in pev->framerate (see above).
      self.DispatchAnimEvents(0.1);
    }
    
    return flFrameTime;
  }
};


