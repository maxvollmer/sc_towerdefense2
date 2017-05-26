
/*
 * Constants for camera
 * TODO: Make some of these customizable (e.g. grid size)
 */

const int MOUSE_RELEASED = 0;
const int MOUSE_PRESSED = 1;
const int MOUSE_DOUBLE_PRESSED = 2;
const int MOUSE_DRAGGED = 3;
const int MOUSE_POS_CHANGED = 4;
const int MOUSE_WHEEL_SCROLLED = 5;

const int MOUSE_BUTTON_LEFT = 0;
const int MOUSE_BUTTON_RIGHT = 1;
const int MOUSE_BUTTON_MIDDLE = 2;


// TODO: Make these customizable ->
const int MAX_GRID_X = 1120;
const int MAX_GRID_Y= 1728;
const int GRID_SIZE = 64;
const int GRID_SIZE_ON_PATH = GRID_SIZE * 2;
const int INVALID_GRID = -1;

const int CAMERA_INITIAL_Z = 440;
const int CAMERA_MIN_Z = 200;
const int CAMERA_TILT_THRESHOLD_Z = 400;
const int CAMERA_MAX_Z = 1792;
const int CAMERA_MIN_TILT_DEGREES = 0;
const int CAMERA_MAX_TILT_DEGREES = 50;
// <- TODO: Make these customizable


const int WHEEL_ZOOM_FACTOR = -30;

const int MIN_DRAG_DELTA_TO_CANCEL_RIGHTCLICK = 8;


class CameraData
{
  bool isDragging = false;
  float dragStartX = 0;
  float dragStartY = 0;
  float totalDraggedDelta = 0;
  
  EHandle hMousePressedEntity;
  float flTotalDraggedDelta = 0;
  
  bool wasLeftMouseDown = false;
  bool wasRightMouseDown = false;
};


int GetGridPosition(float pos, int maxGrid)
{
  int gridPos = (int(pos)/GRID_SIZE)*GRID_SIZE;
  if (gridPos < -maxGrid || gridPos > maxGrid)
  {
    return INVALID_GRID;
  }
  if (pos < 0)
  {
    gridPos -= GRID_SIZE/2;
  }
  else
  {
    gridPos += GRID_SIZE/2;
  }
  return gridPos;
}

float GetTiltForZ(float z)
{
  if (z >= CAMERA_TILT_THRESHOLD_Z)
  {
    return 90 - CAMERA_MIN_TILT_DEGREES;
  }
  else if (z <= CAMERA_MIN_Z)
  {
    return 90 - CAMERA_MAX_TILT_DEGREES;
  }
  else
  {
    float upper = CAMERA_TILT_THRESHOLD_Z - CAMERA_MIN_Z;
    float actual = z - CAMERA_MIN_Z;
    float ratio = actual / upper;
    return 90 - ((CAMERA_MAX_TILT_DEGREES - CAMERA_MIN_TILT_DEGREES) * (1 - ratio)) + CAMERA_MIN_TILT_DEGREES;
  }
}


/*
 * Callbacks from game
 */

void EnterCameraCallback(CBaseEntity@ pPlayer, CBaseEntity@ pCamera, USE_TYPE useType, float value)
{
  Worker@ worker = GetWorkerForCamera(pCamera);
  if (worker is null)
    return;
  
  worker.menu.SetVisible(pCamera, pPlayer, true);
}

void LeaveCameraCallback(CBaseEntity@ pPlayer, CBaseEntity@ pCamera, USE_TYPE useType, float value)
{
  Worker@ worker = GetWorkerForCamera(pCamera);
  if (worker is null)
    return;
  
  worker.menu.SetVisible(pCamera, pPlayer, false);
}

bool CameraMouseEventCallback(CBaseEntity@ pCamera, CBaseEntity@ pPlayer, CBaseEntity@ pEntity, int mouseEvent, int mouseEventParam, float screenX, float screenY, Vector clickPosition, Vector clickDirection, Vector clickPlaneNormal, float scale)
{
  Worker@ worker = GetWorkerForCamera(pCamera);
  if (worker is null)
    return false;
  
  int gridX;
  int gridY;
  if (IsGroundEntity(pEntity))
  {
    gridX = GetGridPosition(clickPosition.x, MAX_GRID_X);
    gridY = GetGridPosition(clickPosition.y, MAX_GRID_Y);
    if (critterRouteManager.IsPath(Vector(gridX, gridY, 0)))
    {
      Vector gridPositionOnPath = critterRouteManager.GetGridPositionOnPath(Vector(gridX, gridY, 0));
      gridX = int(gridPositionOnPath.x);
      gridY = int(gridPositionOnPath.y);
    }
  }
  else
  {
    gridX = INVALID_GRID;
    gridY = INVALID_GRID;
  }
  
  if (mouseEvent == MOUSE_WHEEL_SCROLLED)
  {
    //zoom camera
    pCamera.pev.origin.z += mouseEventParam * WHEEL_ZOOM_FACTOR;
    pCamera.pev.origin.z = Clamp(pCamera.pev.origin.z, CAMERA_MIN_Z, CAMERA_MAX_Z);
    g_EntityFuncs.SetOrigin(pCamera, pCamera.pev.origin);
  }
  else
  {
    if (mouseEvent == MOUSE_DRAGGED && mouseEventParam == MOUSE_BUTTON_RIGHT)
    {
      if (worker.cameraData.isDragging)
      {
        float deltaX = (screenX - worker.cameraData.dragStartX) * pCamera.pev.origin.z;
        float deltaY = (screenY - worker.cameraData.dragStartY) * pCamera.pev.origin.z;
        pCamera.pev.origin.x -= deltaY; // x and y is switched due to orientation of camera
        pCamera.pev.origin.y += deltaX;
        pCamera.pev.origin.x = Clamp(pCamera.pev.origin.x, -MAX_GRID_X, MAX_GRID_X);
        pCamera.pev.origin.y = Clamp(pCamera.pev.origin.y, -MAX_GRID_Y, MAX_GRID_Y);
        g_EntityFuncs.SetOrigin(pCamera, pCamera.pev.origin);
        worker.cameraData.dragStartX = screenX;
        worker.cameraData.dragStartY = screenY;
        worker.cameraData.totalDraggedDelta += abs(deltaX) + abs(deltaY);
      }
      else
      {
        worker.cameraData.dragStartX = screenX;
        worker.cameraData.dragStartY = screenY;
        worker.cameraData.isDragging = true;
        worker.cameraData.totalDraggedDelta = 0;
      }
    }
    else
    {
      worker.cameraData.isDragging = false;
    }
    
    if (mouseEvent == MOUSE_PRESSED)
    {
      worker.cameraData.hMousePressedEntity = EHandle(pEntity);
      worker.cameraData.totalDraggedDelta = 0;
      if (mouseEventParam == MOUSE_BUTTON_RIGHT && !worker.cameraData.wasRightMouseDown)
      {
        worker.menu.RightMouseDown(pCamera, pPlayer, pEntity, gridX, gridY);
        worker.cameraData.wasRightMouseDown = true;
      }
    }
    else if (mouseEvent == MOUSE_RELEASED)
    {
      if ((pEntity is null && !worker.cameraData.hMousePressedEntity.IsValid()) || (worker.cameraData.hMousePressedEntity.IsValid() && pEntity !is null && pEntity == worker.cameraData.hMousePressedEntity.GetEntity()))
      {
        if (mouseEventParam == MOUSE_BUTTON_LEFT)
        {
          worker.menu.LeftClick(pCamera, pPlayer, pEntity, gridX, gridY);
        }
        else if (mouseEventParam == MOUSE_BUTTON_RIGHT)
        {
          if (MIN_DRAG_DELTA_TO_CANCEL_RIGHTCLICK > worker.cameraData.totalDraggedDelta)
          {
            worker.menu.RightClick(pCamera, pPlayer, pEntity, gridX, gridY);
            worker.cameraData.totalDraggedDelta = 0;
          }
        }
      }
      if (mouseEventParam == MOUSE_BUTTON_RIGHT && worker.cameraData.wasRightMouseDown)
      {
        worker.menu.RightMouseUp(pCamera, pPlayer, pEntity, gridX, gridY);
        worker.cameraData.wasRightMouseDown = false;
      }
    }
  }
  
  pCamera.pev.angles.x = GetTiltForZ(pCamera.pev.origin.z);
  pCamera.pev.angles.y = 0;
  pCamera.pev.angles.z = 0;
  worker.menu.Update(pCamera, pPlayer, pEntity, gridX, gridY);
  
  return false;
}
