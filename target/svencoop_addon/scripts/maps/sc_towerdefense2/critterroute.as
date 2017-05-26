
const Vector CRITTER_ROUTE_SPAWN_EFFECT_OFFSET(0,0,32);

class CritterRoute : ScriptBaseEntity
{
  EHandle hSprite;

  void Spawn()
  {
    self.pev.origin.z = 0;
    g_EntityFuncs.SetOrigin(self, self.pev.origin);
    
    self.pev.effects |= EF_NODRAW;
    self.pev.solid = SOLID_NOT;
    self.pev.movetype = MOVETYPE_NONE;
    
    if (self.pev.model != "")
    {
      g_Game.PrecacheModel(self.pev.model);
      
      CSprite@ pSprite = g_EntityFuncs.CreateSprite(self.pev.model, self.pev.origin + CRITTER_ROUTE_SPAWN_EFFECT_OFFSET, true);
      pSprite.pev.rendermode = 5;
      pSprite.pev.renderamt = 255;
      pSprite.TurnOff();
      hSprite = EHandle(pSprite);
      
      self.pev.model = "";
    }
  }

  void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float value)
  {
    if (hSprite.IsValid())
    {
      hSprite.GetEntity().Use(pActivator, pCaller, useType, value);
    }
  }
};

class PathRectangle
{
  private float xMin, xMax, yMin, yMax;
  private float angle;
  private bool xReverse, yReverse;
  PathRectangle() {}
  PathRectangle(float xMin, float xMax, float yMin, float yMax, float angle, bool xReverse, bool yReverse)
  {
    this.xMin = xMin;
    this.xMax = xMax;
    this.yMin = yMin;
    this.yMax = yMax;
    this.angle = angle;
    this.xReverse = xReverse;
    this.yReverse = yReverse;
  }
  bool IsInside(Vector pos)
  {
    return (pos.x >= xMin && pos.x <= xMax && pos.y >= yMin && pos.y <= yMax);
  }
  Vector AlignOnPath(Vector pos)
  {
    float x, y;
    if (xReverse)
    {
      for (x = xMax-GRID_SIZE_ON_PATH; x >= xMin; x -= GRID_SIZE_ON_PATH)
      {
        if (pos.x > x)
        {
          x += GRID_SIZE;
          break;
        }
      }
    }
    else
    {
      for (x = xMin+GRID_SIZE_ON_PATH; x <= xMax; x += GRID_SIZE_ON_PATH)
      {
        if (pos.x < x)
        {
          x -= GRID_SIZE;
          break;
        }
      }
    }
    if (yReverse)
    {
      for (y = yMax-GRID_SIZE_ON_PATH; y >= yMin; y -= GRID_SIZE_ON_PATH)
      {
        if (pos.y > y)
        {
          y += GRID_SIZE;
          break;
        }
      }
    }
    else
    {
      for (y = yMin+GRID_SIZE_ON_PATH; y <= yMax; y += GRID_SIZE_ON_PATH)
      {
        if (pos.y < y)
        {
          y -= GRID_SIZE;
          break;
        }
      }
    }
    return Vector(x, y, 0);
  }
  float GetAngle() { return angle; }
};

class CritterRouteManager
{
  private array<PathRectangle> pathRectangles;
  private array<PathRectangle> borderRectangles;

  private array<string> critterRouteSpawnpointNames;
  private bool validRouteFound = false;

  CritterRouteManager()
  {
    InitCritterRoutes();
    if (!validRouteFound || critterRouteSpawnpointNames.size() == 0)
    {
      g_EngineFuncs.ServerPrint("Map error: No valid critter_route found. Game will abort.\n");
      GameLost();
      g_Scheduler.SetTimeout("DisplayNoValidRouteError", 5);
    }
  }

  private void InitCritterRoutes()
  {
    array<string> allCritterRouteNames;
    array<string> allCritterRouteTargets;

    CBaseEntity@ pCritterRoute = null;
    while ((@pCritterRoute = g_EntityFuncs.FindEntityByClassname(pCritterRoute, "critter_route")) !is null)
    {
      if (pCritterRoute.pev.targetname != "")
      {
        allCritterRouteNames.insertLast(pCritterRoute.pev.targetname);
        if (pCritterRoute.pev.target != "")
        {
          allCritterRouteTargets.insertLast(pCritterRoute.pev.target);
          CBaseEntity@ pNextCritterRoute = g_EntityFuncs.FindEntityByTargetname(null, pCritterRoute.pev.target);
          if (pNextCritterRoute !is null)
          {
            validRouteFound = true;
            Vector vecDir = (pNextCritterRoute.pev.origin - pCritterRoute.pev.origin).Normalize() * GRID_SIZE;
            Vector vecNorm = CrossProduct(vecDir, Vector(0,0,1)).Normalize() * GRID_SIZE;
            
            float absNormX = abs(vecNorm.x) + abs(vecDir.x);
            float absNormY = abs(vecNorm.y) + abs(vecDir.y);
            
            float xMin, xMax, yMin, yMax;
            bool xReverse = false;
            bool yReverse = false;
            
            if (pCritterRoute.pev.origin.x < pNextCritterRoute.pev.origin.x)
            {
              xMin = pCritterRoute.pev.origin.x - absNormX;
              xMax = pNextCritterRoute.pev.origin.x + absNormX;
            }
            else
            {
              xMin = pNextCritterRoute.pev.origin.x - absNormX;
              xMax = pCritterRoute.pev.origin.x + absNormX;
              xReverse = true;
            }
            
            if (pCritterRoute.pev.origin.y < pNextCritterRoute.pev.origin.y)
            {
              yMin = pCritterRoute.pev.origin.y - absNormY;
              yMax = pNextCritterRoute.pev.origin.y + absNormY;
            }
            else
            {
              yMin = pNextCritterRoute.pev.origin.y - absNormY;
              yMax = pCritterRoute.pev.origin.y + absNormY;
              yReverse = true;
            }
            
            pathRectangles.insertLast(PathRectangle(xMin, xMax, yMin, yMax, FixAngle(atan2(-vecDir.y, -vecDir.x) * 180.0 / Math.PI), xReverse, yReverse));
            
            borderRectangles.insertLast(PathRectangle(xMin - GRID_SIZE, xMin, yMin, yMax,   0, false, false));
            borderRectangles.insertLast(PathRectangle(xMax, xMax + GRID_SIZE, yMin, yMax, 180, false, false));
            borderRectangles.insertLast(PathRectangle(xMin, xMax, yMin - GRID_SIZE, yMin,  90, false, false));
            borderRectangles.insertLast(PathRectangle(xMin, xMax, yMax, yMax + GRID_SIZE, 270, false, false));
          }
        }
      }
    }
    
    // Add all names that are not targets to critterRouteSpawnpointNames
    for (uint i = 0, n = allCritterRouteNames.size(); i < n; i++)
    {
      if (allCritterRouteTargets.find(allCritterRouteNames[i]) < 0)
      {
        critterRouteSpawnpointNames.insertLast(allCritterRouteNames[i]);
      }
    }
  }


  // public methods for spawning critters, placing towers and such:

  array<string> GetSpawnPointNames()
  {
    return critterRouteSpawnpointNames;
  }

  void SetSpawnSpritesVisible(bool visible)
  {
    for (uint i = 0, n = critterRouteSpawnpointNames.size(); i < n; i++)
    {
      CBaseEntity@ pSpawnPoint = g_EntityFuncs.FindEntityByTargetname(null, critterRouteSpawnpointNames[i]);
      if (pSpawnPoint !is null)
      {
        pSpawnPoint.Use(pSpawnPoint, pSpawnPoint, visible ? USE_ON : USE_OFF, 0);
      }
    }
  }

  bool IsPath(Vector pos)
  {
    for (uint i = 0, n = pathRectangles.size(); i < n; i++)
    {
      if (pathRectangles[i].IsInside(pos))
      {
        return true;
      }
    }
    return false;
  }

  bool IsBorder(Vector pos)
  {
    if (!IsPath(pos))
    {
      for (uint i = 0, n = borderRectangles.size(); i < n; i++)
      {
        if (borderRectangles[i].IsInside(pos))
        {
          return true;
        }
      }
    }
    return false;
  }

  Vector GetPathAngles(Vector pos, Vector fallback)
  {
    for (uint i = 0, n = pathRectangles.size(); i < n; i++)
    {
      if (pathRectangles[i].IsInside(pos))
      {
        return Vector(0, pathRectangles[i].GetAngle(), 0);
      }
    }
    
    for (uint i = 0, n = borderRectangles.size(); i < n; i++)
    {
      if (borderRectangles[i].IsInside(pos))
      {
        return Vector(0, borderRectangles[i].GetAngle(), 0);
      }
    }
    
    return fallback;
  }

  Vector GetGridPositionOnPath(Vector pos)
  {
    for (uint i = 0, n = pathRectangles.size(); i < n; i++)
    {
      if (pathRectangles[i].IsInside(pos))
      {
        return pathRectangles[i].AlignOnPath(pos);
      }
    }
    
    for (uint i = 0, n = borderRectangles.size(); i < n; i++)
    {
      if (borderRectangles[i].IsInside(pos))
      {
        return borderRectangles[i].AlignOnPath(pos);
      }
    }
    
    return pos;
  }
};

void DisplayNoValidRouteError()
{
  DisplayText("ERROR: NO VALID ROUTE FOR CRITTERS FOUND! GAME ABORTED", null, false, TEXT_COLOR_RED);
}
