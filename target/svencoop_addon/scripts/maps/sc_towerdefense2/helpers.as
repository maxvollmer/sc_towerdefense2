
Vector NullVector;

EHandle g_hRenderNormal;
EHandle g_hRenderTransparent50;
EHandle g_hRenderTransparent100;
EHandle g_hRenderTransparent150;
EHandle g_hRenderTransparent200;
EHandle g_hRenderTransparent255;
EHandle g_hRenderGlowEffect;

EHandle g_hTriggerCameraEnter;
EHandle g_hTriggerCameraLeave;

CBaseEntity@ CreateRender(int rendermode, int renderamt)
{
  dictionary keyValues = {
    {"spawnflags", "73"},
    {"rendermode", string(rendermode)},
    {"renderamt", string(renderamt)}
  };
  return g_EntityFuncs.CreateEntity("env_render_individual", @keyValues);
}

CBaseEntity@ CreateRender(int rendermode, int renderamt, Vector rendercolor, int renderfx)
{
  dictionary keyValues = {
    {"spawnflags", "64"},
    {"rendermode", string(rendermode)},
    {"renderamt", string(renderamt)},
    {"rendercolor", VectorString(rendercolor)},
    {"renderfx", string(renderfx)}
  };
  return g_EntityFuncs.CreateEntity("env_render_individual", @keyValues);
}

void SetRender(EHandle hPlayer, EHandle hEntity, EHandle hRender, bool on)
{
  if (!hPlayer.IsValid() || !hEntity.IsValid() || !hRender.IsValid())
  {
    return;
  }
  string backupTargetname = hEntity.GetEntity().pev.targetname;
  hEntity.GetEntity().pev.targetname = "random_" + Math.RandomLong(10000, 999999) + "_" + Math.RandomLong(10000, 999999);
  hRender.GetEntity().pev.target = hEntity.GetEntity().pev.targetname;
  hRender.GetEntity().Use(hPlayer.GetEntity(), hPlayer.GetEntity(), on ? USE_ON : USE_OFF, 0);
  hEntity.GetEntity().pev.targetname = backupTargetname;
}

void InitGlobalHelperEntities()
{
  g_hRenderNormal = CreateRender(0, 0, Vector(), 0);
  g_hRenderTransparent50 = CreateRender(2, 50);
  g_hRenderTransparent100 = CreateRender(2, 100);
  g_hRenderTransparent150 = CreateRender(2, 150);
  g_hRenderTransparent200 = CreateRender(2, 200);
  g_hRenderTransparent255 = CreateRender(2, 255);
  g_hRenderGlowEffect = CreateRender(0, 0, Vector(255,255,255), kRenderFxGlowShell);
  
  dictionary triggerCameraEnterKeyValues = {
    {"m_iMode", "1"},
    {"m_iszScriptFunctionName", "EnterCameraCallback"},
    {"targetname", "EnterCameraCallback"}
  };
  g_hTriggerCameraEnter = EHandle(g_EntityFuncs.CreateEntity("trigger_script", @triggerCameraEnterKeyValues));
  
  dictionary triggerCameraLeaveKeyValues = {
    {"m_iMode", "1"},
    {"m_iszScriptFunctionName", "LeaveCameraCallback"},
    {"targetname", "LeaveCameraCallback"}
  };
  g_hTriggerCameraLeave = EHandle(g_EntityFuncs.CreateEntity("trigger_script", @triggerCameraLeaveKeyValues));
}

const Vector TEXT_COLOR_DEFAULT(117, 168, 243);
const Vector TEXT_COLOR_RED(255, 127, 127);
const Vector TEXT_COLOR_GREEN(0, 127, 0);

void DisplayText(string text, CBasePlayer@ pPlayer=null, bool center=false, Vector textColor = TEXT_COLOR_DEFAULT)
{
  HUDTextParams params;
  params.x = center ? -1.0 : 0.1;
  params.y = center ? -1.0 : 0.65;
  params.effect = 0;
  params.r1 = int(textColor.x);
  params.g1 = int(textColor.y);
  params.b1 = int(textColor.z);
  params.a1 = 255;
  params.r2 = int(textColor.x);
  params.g2 = int(textColor.y);
  params.b2 = int(textColor.z);
  params.a2 = 255;
  params.fadeinTime = 0;
  params.fadeoutTime = 0;
  params.holdTime = 3;
  params.fxTime = 0;
  params.channel = center ? 2 : 1;
  
  if (pPlayer !is null)
  {
    g_PlayerFuncs.HudMessage(pPlayer, params, text+"\n          .");
  }
  else
  {
    g_PlayerFuncs.HudMessageAll(params, text+"\n          .");
  }
}

void PostClientMessage(EHandle hPlayer, string msg)
{
  if (hPlayer.IsValid() && hPlayer.GetEntity().IsPlayer())
  {
    g_EngineFuncs.ClientPrintf(cast<CBasePlayer>(hPlayer.GetEntity()), print_center, msg);
  }
}

float DotProduct2D(const Vector& in a, const Vector& in b)
{
  return( a.x*b.x + a.y*b.y ); 
}

string OriginString(float x=0, float y=0, float z=0) {
  string originString;
  snprintf(originString, "%1 %2 %3", x, y, z);
  return originString;
}

string AnglesString(float pitch=0, float yaw=0, float roll=0) {
  string angles;
  snprintf(angles, "%1 %2 %3", FixAngle(pitch), FixAngle(yaw), FixAngle(roll));
  return angles;
}

string VectorString(Vector v)
{
  return OriginString(v.x, v.y, v.z);
}

float FixAngle(float angle)
{
  while (angle < 0) angle += 360;
  while (angle > 360) angle -= 360;
  return angle;
}

string ToString(float value)
{
  string s;
  snprintf(s, "%1", value);
  return s;
}

float Clamp(float value, int minValue, int maxValue)
{
  if (value < minValue)
  {
    return minValue;
  }
  else if (value > maxValue)
  {
    return maxValue;
  }
  else
  {
    return value;
  }
}

string GetEntityModel(string entity_name)
{
  CBaseEntity@ entity = g_EntityFuncs.FindEntityByTargetname(null, entity_name);
  if (entity !is null)
  {
    return entity.pev.model;
  }
  else
  {
    return "";
  }
}

void RemoveEntityDelayed(EHandle hEntity)
{
  if (hEntity.IsValid())
  {
    g_EntityFuncs.Remove(hEntity);
  }
}

array<uint> GetDigits(uint i)
{
  array<uint> digitArray;
  for (uint digits = i, index = 0; digits > 0; digits /= 10, index++)
  {
    digitArray.resize(index+1);
    digitArray[index] = digits % 10;
  }
  if (digitArray.size() == 0)
  {
    digitArray.resize(1);
    digitArray[0] = 0;
  }
  digitArray.reverse();
  return digitArray;
}

array<uint> GetDigits(int i)
{
  return GetDigits(uint(abs(i)));
}

const string ALPHANUM_CHARACTER_FRAMES = "0123456789abcdefghijklmnopqrstuvwxyz/";
const uint ALPHANUM_INVALIDCHARACTER_FRAME = ALPHANUM_CHARACTER_FRAMES.Length();

int GetCharacterFrame(char character)
{
  int index = ALPHANUM_CHARACTER_FRAMES.FindFirstOf(""+character);
  if (index == -1)
  {
    index = ALPHANUM_CHARACTER_FRAMES.FindFirstOf(""+character, 0, String::CaseInsensitive);
  }
  if (index >= 0)
  {
    return index;
  }
  else
  {
    return ALPHANUM_INVALIDCHARACTER_FRAME;
  }
}

int GetCharacterFrame(string s)
{
  if (s.Length() > 0)
  {
    return GetCharacterFrame(s[0]);
  }
  else
  {
    return ALPHANUM_INVALIDCHARACTER_FRAME;
  }
}

array<int> GetCharacterFrames(string s)
{
  array<int> characterFrames;
  characterFrames.resize(s.Length());
  for (uint i = 0, n = s.Length(); i < n; i++)
  {
    characterFrames[i] = GetCharacterFrame(s[i]);
  }
  return characterFrames;
}



const float EPSILON = 0.0001;

Vector GetAnglesFromVectors(Vector forward, Vector right, Vector up)
{
  float sr, sp, sy, cr, cp, cy;

  sp = -forward.z;

  float cp_x_cy = forward.x;
  float cp_x_sy = forward.y;
  float cp_x_sr = -right.z;
  float cp_x_cr = up.z;

  float yaw = atan2(cp_x_sy, cp_x_cy);
  float roll = atan2(cp_x_sr, cp_x_cr);

  cy = cos(yaw);
  sy = sin(yaw);
  cr = cos(roll);
  sr = sin(roll);

  if (abs(cy) > EPSILON)
  {
    cp = cp_x_cy / cy;
  }
  else if (abs(sy) > EPSILON)
  {
    cp = cp_x_sy / sy;
  }
  else if (abs(sr) > EPSILON)
  {
    cp = cp_x_sr / sr;
  }
  else if (abs(cr) > EPSILON)
  {
    cp = cp_x_cr / cr;
  }
  else
  {
    cp = cos(asin(sp));
  }

  float pitch = atan2(sp, cp);

  return Vector(
    pitch / (Math.PI / 180.0),
    yaw / (Math.PI / 180.0),
    roll / (Math.PI / 180.0)
  );
}
