
const int MENU_BUTTON_OFFSET_X = 48;
const int MENU_BUTTON_OFFSET_Y_MIN = -35;
const int MENU_BUTTON_OFFSET_Y_MAX = 35;
const int MENU_BUTTON_OFFSET_Z_MIN = -32;
const int MENU_BUTTON_OFFSET_Z_MAX = 24;
const int MENU_BUTTON_OFFSET_YZ_STEP_SIZE = 14;

const int MENU_BUTTONS_PER_ROW = 6;
const int MENU_TOWER_BUTTONS_ROWS = 2;  // Max amount of rows for tower buttons
const int MAX_TOWER_COUNT = MENU_BUTTONS_PER_ROW * MENU_TOWER_BUTTONS_ROWS;

const Vector MENU_EXIT_BUTTON_OFFSET(MENU_BUTTON_OFFSET_X, MENU_BUTTON_OFFSET_Y_MIN, MENU_BUTTON_OFFSET_Z_MAX);
const Vector MENU_MONEY_DISPLAY_OFFSET(MENU_BUTTON_OFFSET_X, MENU_BUTTON_OFFSET_Y_MIN+MENU_BUTTON_OFFSET_YZ_STEP_SIZE, MENU_BUTTON_OFFSET_Z_MAX);
const Vector MENU_COMPUTER_TERMINAL_DISPLAY_OFFSET(MENU_BUTTON_OFFSET_X, MENU_BUTTON_OFFSET_Y_MAX, MENU_BUTTON_OFFSET_Z_MAX);

const int MENU_BUTTON_WIDTH = 8;
const int MENU_BUTTON_HEIGHT = 8;
const int MENU_BUTTON_SPRITE_Z_OFFSET = MENU_BUTTON_HEIGHT / 2;
const int MENU_BUTTON_MODEL_Z_OFFSET = 2;
const float MENU_BUTTON_TRIGGER_X_OFFSET = 0.1;

const float MENU_BUTTON_INFO_WIDTH = 1.4;
const float MENU_BUTTON_INFO_SCALE = 0.6;

const float MENU_MONEY_SCALE = 1.25;
const float MENU_MONEY_WIDTH = 3.5;

const float MENU_MONEY_FLASH_TIME = 1.0;
const float MENU_MONEY_FLASH_INTERVAL = 0.1;
const float MENU_TERMINALHEALTH_FLASH_TIME = 3.0;
const float MENU_TERMINALHEALTH_FLASH_INTERVAL = 0.25;

const Vector COLOR_PRICE_OK(0, 127, 0);
const Vector COLOR_PRICE_NOTENOUGHMONEY(255, 0, 0);
const Vector COLOR_MONEY(212, 175, 55);
const Vector COLOR_MONEY_SELL(102, 178, 255);
const Vector COLOR_FLASH_RED(255, 0, 0);
const Vector COLOR_FLASH_GREEN(0, 127, 0);
const Vector COLOR_COMPUTER_TERMINAL_HEALTH(102, 178, 255);

const array<array<int>> MENU_MONEY_DONATE_VALUES =
{
  {1, 3},
  {2, 5},     //   6 => -1
  {5, 10},    //  15,  12.5 => -2.5
  {10, 17},   //  30,  25  ,  20 => -3
  {20, 30},   //  60,  50  ,  40, 34 => -4
  {50, 70}    // 150, 125  , 100, 82, 75 => -5
};

class MenuButtonModel
{
  EHandle hModel;
  Vector offset;
  Vector rotatedOffset;
  bool useColor;
  MenuButtonModel() {}
  MenuButtonModel(EHandle hModel, Vector offset, bool useColor)
  {
    this.hModel = hModel;
    this.rotatedOffset = this.offset = offset;
    this.useColor = useColor;
  }
};

class MenuButton
{
  int _cost = 0;  // store cost here for upgrade buttons
  int _cost2 = 0;

  private Vector vanillaOffset;
  private MenuButtonModel triggerModel;
  private MenuButtonModel mainModel;
  private array<MenuButtonModel> sprites;
  private bool m_fTriggerIsInvisible = false;
  
  private float flLastPitch;
  
  private EHandle hCurrentPlayer;
  
  private int m_iModelMouseHoverAnimSequence;
  
  private bool isEnabled = true;
  
  MenuButton() {}
  
  void DestroyButton()
  {
    if (triggerModel.hModel.IsValid())
    {
      triggerModel.hModel.GetEntity().pev.flags |= FL_KILLME;
      triggerModel.hModel = null;
    }
    if (mainModel.hModel.IsValid())
    {
      mainModel.hModel.GetEntity().pev.flags |= FL_KILLME;
      mainModel.hModel = null;
    }
    ClearSprites();
  }
  
  MenuButton(string model, float modelScale, int mouseOverSequence, Vector offset)
  {
    this.vanillaOffset = offset;
    this.triggerModel.hModel = CreateTrigger();
    this.mainModel.hModel = CreateModel(model, modelScale);
    this.mainModel.offset = this.triggerModel.offset = offset;
    if (model.EndsWith(".spr"))
    {
      this.mainModel.offset.z += MENU_BUTTON_SPRITE_Z_OFFSET;
    }
    else
    {
      this.mainModel.offset.z += MENU_BUTTON_MODEL_Z_OFFSET;
    }
    this.triggerModel.offset.x += MENU_BUTTON_TRIGGER_X_OFFSET;
    this.triggerModel.rotatedOffset = this.triggerModel.offset;
    this.mainModel.rotatedOffset = this.mainModel.offset;
    this.flLastPitch = 0;
    this.m_iModelMouseHoverAnimSequence = mouseOverSequence;
  }
  
  void AddSprite(string model, float modelScale, int frame, float widthOffset, float heightOffset, bool useColor)
  {
    EHandle hSprite = EHandle(CreateModel(model, modelScale));
    hSprite.GetEntity().pev.frame = frame;
    hSprite.GetEntity().pev.framerate = 0;
    hSprite.GetEntity().pev.sequence = 0;
    hSprite.GetEntity().pev.rendermode = 2;
    
    MenuButtonModel@ menuButtonModel = MenuButtonModel(hSprite, vanillaOffset + Vector(0, -widthOffset, heightOffset), useColor);
    if (flLastPitch == 0)
    {
      menuButtonModel.rotatedOffset = menuButtonModel.offset;
    }
    else
    {
      menuButtonModel.rotatedOffset = Math.RotateVector(menuButtonModel.offset, Vector(flLastPitch, 0, 0), Vector());
    }
    sprites.insertLast(menuButtonModel);
  }
  
  void SetSprite(uint index, string model, float modelScale, int frame, float widthOffset, float heightOffset, bool useColor)
  {
    if (index < sprites.size())
    {
      MenuButtonModel@ menuButtonModel = sprites[index];
      menuButtonModel.hModel.GetEntity().pev.model = model;
      g_EntityFuncs.SetModel(menuButtonModel.hModel.GetEntity(), model);
      menuButtonModel.hModel.GetEntity().pev.scale = modelScale * 0.1;
      menuButtonModel.hModel.GetEntity().pev.frame = frame;
      menuButtonModel.hModel.GetEntity().pev.effects &= ~EF_NODRAW;
      menuButtonModel.useColor = useColor;
      menuButtonModel.offset = vanillaOffset + Vector(0, -widthOffset, heightOffset);
      if (flLastPitch == 0)
      {
        menuButtonModel.rotatedOffset = menuButtonModel.offset;
      }
      else
      {
        menuButtonModel.rotatedOffset = Math.RotateVector(menuButtonModel.offset, Vector(flLastPitch, 0, 0), Vector());
      }
      sprites[index] = menuButtonModel;
    }
    else
    {
      AddSprite(model, modelScale, frame, widthOffset, heightOffset, useColor);
    }
  }
  
  void SetSpriteModel(uint index, string model, float modelScale, int frame, bool useColor)
  {
    if (index < sprites.size())
    {
      MenuButtonModel@ menuButtonModel = sprites[index];
      menuButtonModel.hModel.GetEntity().pev.model = model;
      g_EntityFuncs.SetModel(menuButtonModel.hModel.GetEntity(), model);
      menuButtonModel.hModel.GetEntity().pev.scale = modelScale * 0.1;
      menuButtonModel.hModel.GetEntity().pev.frame = frame;
      menuButtonModel.hModel.GetEntity().pev.effects &= ~EF_NODRAW;
      menuButtonModel.useColor = useColor;
    }
  }
  
  void ClearSprites()
  {
    for (uint i = 0, n = sprites.size(); i < n; i++)
    {
      if (sprites[i].hModel.IsValid())
      {
        sprites[i].hModel.GetEntity().pev.flags |= FL_KILLME;
        sprites[i].hModel = null;
      }
    }
    sprites.resize(0);
  }
  
  void HideSpritesFrom(uint index)
  {
    if (index < sprites.size())
    {
      for (uint i = index, n = sprites.size(); i < n; i++)
      {
        if (sprites[i].hModel.IsValid())
        {
          sprites[i].hModel.GetEntity().pev.effects |= EF_NODRAW;
        }
      }
    }
  }
  
  private CBaseEntity@ CreateTrigger()
  {
    dictionary itemKeyValues = {
      {"rendermode", "2"},
      {"model", GetEntityModel("template_menu_button")},
      {"targetname", "rand_" + Math.RandomLong(10000, 999999) + "_" + Math.RandomLong(10000, 999999)}
    };
    return g_EntityFuncs.CreateEntity("trigger_cameratarget", @itemKeyValues);
  }
  
  private CBaseEntity@ CreateModel(string model, float modelScale)
  {
    CSprite@ pSprite = g_EntityFuncs.CreateSprite(model, Vector(), false, 0);
    pSprite.pev.targetname = "rand_" + Math.RandomLong(1000000, 999999) + "_" + Math.RandomLong(1000000, 999999);
    pSprite.pev.rendermode = 2;
    pSprite.pev.scale = modelScale * 0.1;
    return pSprite;
  }
  
  private void CalculateRotatedOffsets(float pitch)
  {
    if (pitch != flLastPitch)
    {
      if (pitch == 0)
      {
        triggerModel.rotatedOffset = triggerModel.offset;
        mainModel.rotatedOffset = mainModel.offset;
        for (uint i = 0, n = sprites.size(); i < n; i++)
        {
          sprites[i].rotatedOffset = sprites[i].offset;
        }
      }
      else
      {
        triggerModel.rotatedOffset = Math.RotateVector(triggerModel.offset, Vector(pitch, 0, 0), Vector());
        mainModel.rotatedOffset = Math.RotateVector(mainModel.offset, Vector(pitch, 0, 0), Vector());
        for (uint i = 0, n = sprites.size(); i < n; i++)
        {
          sprites[i].rotatedOffset = Math.RotateVector(sprites[i].offset, Vector(pitch, 0, 0), Vector());
        }
      }
      flLastPitch = pitch;
    }
  }
  
  void UpdatePosition(Vector origin, float pitch)
  {
    if (!triggerModel.hModel.IsValid() || !mainModel.hModel.IsValid())
    {
      return;
    }
    
    CalculateRotatedOffsets(pitch);
    
    triggerModel.hModel.GetEntity().pev.origin = origin + triggerModel.rotatedOffset;
    g_EntityFuncs.SetOrigin(triggerModel.hModel.GetEntity(), triggerModel.hModel.GetEntity().pev.origin);
    triggerModel.hModel.GetEntity().pev.angles.x = pitch;
    
    mainModel.hModel.GetEntity().pev.origin = origin + mainModel.rotatedOffset;
    g_EntityFuncs.SetOrigin(mainModel.hModel.GetEntity(), mainModel.hModel.GetEntity().pev.origin);
    mainModel.hModel.GetEntity().pev.angles.x = pitch;
    mainModel.hModel.GetEntity().pev.angles.y = 180;
    
    for (uint i = 0, n = sprites.size(); i < n; i++)
    {
      if (sprites[i].hModel.IsValid())
      {
        sprites[i].hModel.GetEntity().pev.origin = origin + sprites[i].rotatedOffset;
        g_EntityFuncs.SetOrigin(sprites[i].hModel.GetEntity(), sprites[i].hModel.GetEntity().pev.origin);
        sprites[i].hModel.GetEntity().pev.angles.x = pitch;
        sprites[i].hModel.GetEntity().pev.angles.y = 180;
      }
    }
  }
  
  void MouseOver(bool mouseOver)
  {
    if (!triggerModel.hModel.IsValid() || !mainModel.hModel.IsValid())
    {
      return;
    }
    
    if (!isEnabled)
    {
      return;
    }
    
    // Animate model when mouse is hovering over this button
    if (mouseOver)
    {
      SetRender(hCurrentPlayer, triggerModel.hModel, g_hRenderTransparent200, !m_fTriggerIsInvisible);
      mainModel.hModel.GetEntity().pev.sequence = m_iModelMouseHoverAnimSequence;
      mainModel.hModel.GetEntity().pev.framerate = 0.5;
      mainModel.hModel.GetEntity().pev.frame = 0;
    }
    else
    {
      SetRender(hCurrentPlayer, triggerModel.hModel, g_hRenderTransparent100, !m_fTriggerIsInvisible);
      mainModel.hModel.GetEntity().pev.sequence = 0;
      mainModel.hModel.GetEntity().pev.framerate = 0;
      mainModel.hModel.GetEntity().pev.frame = 0;
    }
  }
  
  void SetVisible(CBaseEntity@ pPlayer, bool visible)
  {
    if (!triggerModel.hModel.IsValid() || !mainModel.hModel.IsValid())
    {
      return;
    }
    
    SetRender(EHandle(pPlayer), triggerModel.hModel, g_hRenderTransparent200, false);
    SetRender(EHandle(pPlayer), triggerModel.hModel, g_hRenderTransparent100, visible && !m_fTriggerIsInvisible);
    SetRender(EHandle(pPlayer), mainModel.hModel, g_hRenderNormal, visible);
    
    for (uint i = 0, n = sprites.size(); i < n; i++)
    {
      if (sprites[i].hModel.IsValid())
      {
        SetRender(EHandle(pPlayer), sprites[i].hModel, g_hRenderTransparent255, visible);
      }
    }
    
    if (visible)
    {
      hCurrentPlayer = EHandle(pPlayer);
      if (triggerModel.hModel.GetEntity().pev.model != "")
      {
        triggerModel.hModel.GetEntity().pev.solid = SOLID_BSP;
      }
    }
    else
    {
      hCurrentPlayer = null;
      triggerModel.hModel.GetEntity().pev.solid = SOLID_NOT;
    }
  }
  
  void SetEnabled(bool enabled)
  {
    if (!enabled)
    {
      MouseOver(false);
      SetRender(hCurrentPlayer, triggerModel.hModel, g_hRenderTransparent50, !m_fTriggerIsInvisible);
      SetRender(hCurrentPlayer, mainModel.hModel, g_hRenderTransparent50, true);
    }
    this.isEnabled = enabled;
  }
  
  bool IsMyEntity(CBaseEntity@ pEntity)
  {
    return pEntity !is null && triggerModel.hModel.IsValid() && pEntity == triggerModel.hModel.GetEntity();
  }
  
  void RemoveTrigger()
  {
    dictionary keyvalues;
    triggerModel.hModel = g_EntityFuncs.CreateEntity("info_target", @keyvalues);
  }
  
  void SetTriggerInvisible()
  {
    this.m_fTriggerIsInvisible = true;
  }
  
  void SetColor(Vector color)
  {
    for (uint i = 0, n = sprites.size(); i < n; i++)
    {
      if (sprites[i].hModel.IsValid() && sprites[i].useColor)
      {
        sprites[i].hModel.GetEntity().pev.rendercolor = color;
      }
    }
  }
}

class Menu
{
  private Worker@ worker;
  private dictionary towerButtons;
  private dictionary towerModels;
  private dictionary towerModelScales;
  private dictionary towerPrices;
  private dictionary towerInfoTexts;
  private array<string> borderTowers;
  private array<string> pathTowers;
  private MenuButton@ exitButton;
  private MenuButton@ sellButton;
  private MenuButton@ moneyDisplay;
  private MenuButton@ computerTerminalHealthDisplay;
  private EHandle hGhostTower;
  private string selectedTower;
  private string mouseHoverTower;
  private CScheduledFunction@ pScheduledKeepClientMessageUpInterval = null;
  private CScheduledFunction@ pScheduledFlashMoneyTimeout = null;
  private CScheduledFunction@ pScheduledFlashComputerTerminalHealthTimeout = null;
  private string vFlashComputerTerminalHealthSprite = WARNING_SPRITE;
  private Vector vFlashComputerTerminalHealthColor = COLOR_FLASH_RED;
  private float flFlashComputerTerminalStarttime = 0;
  private bool m_fIsComputerTerminalHealthDisplayRed = false;
  private EHandle hGroundTower;
  private array<MenuButton> upgradeButtons;
  private array<MenuButton> moneyDonateButtons;
  private EHandle hCurrentPlayer;
  private Worker@ pGroundWorker = null;
  
  Menu(Worker@ worker, string[] towerEntityClassnames)
  {
    @this.worker = worker;
    for (uint i = 0, n = towerEntityClassnames.size(); i < n; i++)
    {
      CBaseTower@ tower = GetTowerBaseClass(towerEntityClassnames[i]);
      if (tower !is null)
      {
        MenuButton@ towerButton = MenuButton(tower.GetModel(), tower.GetMenuModelScale()*0.8, tower.GetMenuSequence(), GetTowerButtonOffset(i, n));
        towerButton.AddSprite(SELL_SPRITE, 0.3, 0, MENU_BUTTON_WIDTH/2, 0, false);
        for (int count = 0, price = tower.GetPrice(); price > 0; count++, price /= 10)
        {
          towerButton.AddSprite(ALPHANUM_SPRITE, MENU_BUTTON_INFO_SCALE, price % 10, MENU_BUTTON_WIDTH*0.5 - MENU_BUTTON_INFO_WIDTH - (MENU_BUTTON_INFO_WIDTH*count), MENU_BUTTON_INFO_WIDTH, true);
        }
        towerButtons[towerEntityClassnames[i]] = @towerButton;
        towerModels[towerEntityClassnames[i]] = tower.GetModel();
        towerModelScales[towerEntityClassnames[i]] = tower.GetModelScale();
        towerPrices[towerEntityClassnames[i]] = tower.GetPrice();
        towerInfoTexts[towerEntityClassnames[i]] = tower.GetInfoText(true);
        if (tower.IsBorderTower())
        {
          borderTowers.insertLast(towerEntityClassnames[i]);
        }
        if (tower.IsPathTower())
        {
          pathTowers.insertLast(towerEntityClassnames[i]);
        }
      }
    }
    CreateExitButton();
    CreateMoneyDonateButtons();
    CreateMoneyDisplay();
    if (worker.HasComputerTerminal())
    {
      CreateComputerTerminalHealthDisplay();
    }
    @sellButton = null;
  }
  
  private Vector GetTowerButtonOffset(int index, int towerCount)
  {
    int lastRow = (towerCount-1) / MENU_BUTTONS_PER_ROW;
    
    int backIndex = towerCount - (index+1);
    int row = backIndex / MENU_BUTTONS_PER_ROW;
    int column = backIndex % MENU_BUTTONS_PER_ROW;
    
    int towersInLastRow = towerCount % MENU_BUTTONS_PER_ROW;
    if (index < towersInLastRow)
    {
      column = column + MENU_BUTTONS_PER_ROW - towersInLastRow;
    }
    
    int x = MENU_BUTTON_OFFSET_X;
    int y = MENU_BUTTON_OFFSET_Y_MIN + MENU_BUTTON_OFFSET_YZ_STEP_SIZE * column;
    int z = MENU_BUTTON_OFFSET_Z_MIN + MENU_BUTTON_OFFSET_YZ_STEP_SIZE * row;
    
    return Vector(x, y, z);
  }
  
  private void CreateExitButton()
  {
    @exitButton = MenuButton(EXIT_SPRITE, 2.5, 0, MENU_EXIT_BUTTON_OFFSET);
    exitButton.SetTriggerInvisible();
  }
  
  private void CreateMoneyDisplay()
  {
    @moneyDisplay = MenuButton("", 1, 0, MENU_MONEY_DISPLAY_OFFSET);
    moneyDisplay.RemoveTrigger();
  }
  
  private void CreateComputerTerminalHealthDisplay()
  {
    @computerTerminalHealthDisplay = MenuButton("", 1, 0, MENU_COMPUTER_TERMINAL_DISPLAY_OFFSET);
    computerTerminalHealthDisplay.RemoveTrigger();
  }
  
  private void CreateMoneyDonateButtons()
  {
    for (uint i = 0, n = MENU_MONEY_DONATE_VALUES.size(); i < n; i++)
    {
      MenuButton@ moneyDonateButton = MenuButton(SELL_SPRITE, 1, 0, GetTowerButtonOffset(i, n));
      moneyDonateButton._cost = MENU_MONEY_DONATE_VALUES[i][0];
      moneyDonateButton._cost2 = MENU_MONEY_DONATE_VALUES[i][1];
      int index = 0;
      for (int moneydigit = moneyDonateButton._cost; moneydigit > 0; moneydigit /= 10, index++)
      {
        moneyDonateButton.AddSprite(ALPHANUM_SPRITE, MENU_BUTTON_INFO_SCALE, moneydigit % 10, MENU_BUTTON_WIDTH*0.5 - MENU_BUTTON_INFO_WIDTH - (MENU_BUTTON_INFO_WIDTH*index), MENU_BUTTON_INFO_WIDTH, true);
      }
      moneyDonateButton.AddSprite(ALPHANUM_SPRITE, MENU_BUTTON_INFO_SCALE, GetCharacterFrame("/"), MENU_BUTTON_WIDTH*0.5 - MENU_BUTTON_INFO_WIDTH - (MENU_BUTTON_INFO_WIDTH*index), MENU_BUTTON_INFO_WIDTH, true);
      index++;
      for (int moneydigit = moneyDonateButton._cost2; moneydigit > 0; moneydigit /= 10, index++)
      {
        moneyDonateButton.AddSprite(ALPHANUM_SPRITE, MENU_BUTTON_INFO_SCALE, moneydigit % 10, MENU_BUTTON_WIDTH*0.5 - MENU_BUTTON_INFO_WIDTH - (MENU_BUTTON_INFO_WIDTH*index), MENU_BUTTON_INFO_WIDTH, true);
      }
      moneyDonateButtons.insertLast(moneyDonateButton);
    }
  }
  
  private void SelectTower(string tower)
  {
    DeSelectTower();
    if (towerButtons.exists(tower))
    {
      selectedTower = tower;
    }
  }
  
  private void DeSelectTower()
  {
    selectedTower = "";
    HideGhostTower();
  }
  
  private bool HasTowerSelected()
  {
    return towerButtons.exists(selectedTower);
  }
  
  private void SelectGroundTower(CBaseEntity@ pCamera, CBaseEntity@ pPlayer, CBaseTower@ pTower)
  {
    DeSelectTower();
    DeSelectGroundTower(pPlayer);
    DeSelectGroundWorker(pPlayer);
    if (pTower !is null)
    {
      //ShowTowerInfo(pPlayer, pTower.GetInfoText(false));
      hGroundTower = EHandle(pTower.self);
      SetRender(EHandle(pPlayer), hGroundTower, g_hRenderGlowEffect, true);
      SetTowerButtonsVisible(pPlayer, false);
      TowerUpgradeInfo[] upgradeInfo = pTower.GetUpgradeInfo();
      for (uint i = 0, n = upgradeInfo.size(); i < n; i++)
      {
        MenuButton@ upgradeButton = MenuButton(upgradeInfo[i].buttonModel, 1, 0, GetTowerButtonOffset(i, n+1));
        if (upgradeInfo[i].isEnabled)
        {
          upgradeButton.AddSprite(SELL_SPRITE, 0.3, 0, MENU_BUTTON_WIDTH/2, 0, false);
          for (int count = 0, price = upgradeInfo[i].cost; price > 0; count++, price /= 10)
          {
            upgradeButton.AddSprite(ALPHANUM_SPRITE, MENU_BUTTON_INFO_SCALE, price % 10, MENU_BUTTON_WIDTH*0.5 - MENU_BUTTON_INFO_WIDTH - (MENU_BUTTON_INFO_WIDTH*count), MENU_BUTTON_INFO_WIDTH, true);
          }
        }
        upgradeButton.SetVisible(pPlayer, true);
        upgradeButton.SetEnabled(upgradeInfo[i].isEnabled);
        upgradeButton._cost = upgradeInfo[i].cost;
        upgradeButtons.insertLast(upgradeButton);
      }
      @this.sellButton = MenuButton(SELL_SPRITE, 1, 0, GetTowerButtonOffset(MENU_BUTTONS_PER_ROW-1, MENU_BUTTONS_PER_ROW));
      for (int count = 0, price = pTower.GetSellValue(); price > 0; count++, price /= 10)
      {
        this.sellButton.AddSprite(ALPHANUM_SPRITE, MENU_BUTTON_INFO_SCALE, price % 10, MENU_BUTTON_WIDTH*0.5 - MENU_BUTTON_INFO_WIDTH - (MENU_BUTTON_INFO_WIDTH*count), MENU_BUTTON_INFO_WIDTH, true);
      }
      this.sellButton._cost = pTower.GetSellValue();
      this.sellButton.SetColor(COLOR_MONEY_SELL);
      this.sellButton.SetVisible(pPlayer, true);
      this.sellButton.SetEnabled(true);
      UpdateMoneyDisplay();
      UpdateComputerTerminalHealthDisplay();
      UpdatePosition(pCamera);
    }
  }
  
  private void DeSelectGroundTower(CBaseEntity@ pPlayer)
  {
    if (hGroundTower.IsValid())
    {
      SetRender(EHandle(pPlayer), hGroundTower, g_hRenderGlowEffect, false);
      hGroundTower = null;
      //HideTowerInfo(pPlayer);
      SetTowerButtonsVisible(pPlayer, true);
      for (int i = 0, n = upgradeButtons.size(); i < n; i++)
      {
        upgradeButtons[i].DestroyButton();
      }
      upgradeButtons.resize(0);
      sellButton.DestroyButton();
      @sellButton = null;
    }
  }
  
  private bool HasGroundTowerSelected()
  {
    return hGroundTower.IsValid();
  }
  
  private void SelectGroundWorker(CBaseEntity@ pCamera, CBaseEntity@ pPlayer, Worker@ groundWorker)
  {
    DeSelectTower();
    DeSelectGroundTower(pPlayer);
    DeSelectGroundWorker(pPlayer);
    if (groundWorker !is null)
    {
      @this.pGroundWorker = groundWorker;
      SetRender(EHandle(pPlayer), EHandle(groundWorker.self), g_hRenderGlowEffect, true);
      SetTowerButtonsVisible(pPlayer, false);
      SetDonateMoneyButtonsVisible(pPlayer, true);
      UpdateMoneyDisplay();
      UpdateComputerTerminalHealthDisplay();
      UpdatePosition(pCamera);
    }
  }
  
  private void DeSelectGroundWorker(CBaseEntity@ pPlayer)
  {
    if (pGroundWorker !is null)
    {
      SetRender(EHandle(pPlayer), EHandle(pGroundWorker.self), g_hRenderGlowEffect, false);
      @pGroundWorker = null;
      SetTowerButtonsVisible(pPlayer, true);
      SetDonateMoneyButtonsVisible(pPlayer, false);
    }
  }
  
  private bool HasGroundWorkerSelected()
  {
    return pGroundWorker !is null;
  }
  
  private int GetGroundTowerButtonIndex(CBaseEntity@ pEntity)
  {
    for (int i = 0, n = upgradeButtons.size(); i < n; i++)
    {
      if (upgradeButtons[i].IsMyEntity(pEntity))
      {
        return i;
      }
    }
    return -1;
  }
  
  private bool IsGroundTowerButton(CBaseEntity@ pEntity)
  {
    return GetGroundTowerButtonIndex(pEntity) >= 0;
  }
  
  private MenuButton@ GetMoneyDonateButton(CBaseEntity@ pEntity)
  {
    for (int i = 0, n = moneyDonateButtons.size(); i < n; i++)
    {
      if (moneyDonateButtons[i].IsMyEntity(pEntity))
      {
        return moneyDonateButtons[i];
      }
    }
    return null;
  }
  
  private bool IsMoneyDonateButton(CBaseEntity@ pEntity)
  {
    return GetMoneyDonateButton(pEntity) !is null;
  }
  
  private bool IsSellTowerButton(CBaseEntity@ pEntity)
  {
    return sellButton !is null && sellButton.IsMyEntity(pEntity);
  }
  
  private bool IsBorderTower(string tower)
  {
    return borderTowers.find(tower) >= 0;
  }
  
  private bool IsPathTower(string tower)
  {
    return pathTowers.find(tower) >= 0;
  }
  
  private void HideGhostTower()
  {
    if (hGhostTower.IsValid())
    {
      hGhostTower.GetEntity().pev.effects |= EF_NODRAW;
    }
  }
  
  private string GetTowerModel(string tower)
  {
    string value = "";
    towerModels.get(tower, value);
    return value;
  }
  
  private float GetTowerModelScale(string tower)
  {
    double value = 1;
    towerModelScales.get(tower, value);
    return value;
  }
  
  private int GetTowerPrice(string tower)
  {
    int value = 0;
    towerPrices.get(tower, value);
    return value;
  }
  
  private MenuButton@ GetTowerButton(string tower)
  {
    return cast<MenuButton>(towerButtons[tower]);
  }
  
  private string GetTowerInfoText(string tower)
  {
    string value = "";
    towerInfoTexts.get(tower, value);
    return value;
  }
  
  private void ShowGhostTower(CBaseEntity@ pGroundEntity, Vector pos)
  {
    if (!hGhostTower.IsValid())
    {
      CSprite@ sprite = g_EntityFuncs.CreateSprite(GetTowerModel(selectedTower), pos, false);
      sprite.SetTransparency(kRenderTransTexture, 255, 0, 0, 255, kRenderFxGlowShell);
      sprite.TurnOff();
      sprite.pev.sequence = 0;
      sprite.pev.framerate = 0;
      sprite.pev.frame = 0;
      g_EntityFuncs.SetSize(sprite.pev, Vector(-32,-32,0), Vector(32,32,64));
      hGhostTower = EHandle(sprite);
    }
    g_EntityFuncs.SetModel(hGhostTower.GetEntity(), GetTowerModel(selectedTower));
    hGhostTower.GetEntity().pev.origin = pos;
    hGhostTower.GetEntity().pev.effects &= ~EF_NODRAW;
    hGhostTower.GetEntity().pev.scale = GetTowerModelScale(selectedTower);
    hGhostTower.GetEntity().pev.angles = critterRouteManager.GetPathAngles(pos, hGhostTower.GetEntity().pev.angles);
    if (CanSpawnTowerThere(pos, pGroundEntity, IsBorderTower(selectedTower), IsPathTower(selectedTower)))
    {
      // green
      hGhostTower.GetEntity().pev.rendercolor = Vector(0,128,0);
    }
    else
    {
      // red
      hGhostTower.GetEntity().pev.rendercolor = Vector(255,0,0);
    }
  }
  
  string GetTowerForButton(CBaseEntity@ pEntity)
  {
    array<string> @towerButtonKeys = towerButtons.getKeys();
    for (int i = 0, n = towerButtonKeys.size(); i < n; i++)
    {
      if (GetTowerButton(towerButtonKeys[i]).IsMyEntity(pEntity))
      {
        return towerButtonKeys[i];
      }
    }
    return "";
  }
  
  bool IsTowerButton(CBaseEntity@ pEntity)
  {
    return GetTowerForButton(pEntity) != "";
  }
  
  bool IsExitButton(CBaseEntity@ pEntity)
  {
    return exitButton.IsMyEntity(pEntity);
  }
  
  bool IsAnyButton(CBaseEntity@ pEntity)
  {
    return IsExitButton(pEntity) || IsTowerButton(pEntity);
  }
  
  private void SetTowerButtonsVisible(CBaseEntity@ pPlayer, bool visible)
  {
    array<string> @towerButtonKeys = towerButtons.getKeys();
    for (int i = 0, n = towerButtonKeys.size(); i < n; i++)
    {
      GetTowerButton(towerButtonKeys[i]).SetVisible(pPlayer, visible);
    }
  }
  
  private void SetDonateMoneyButtonsVisible(CBaseEntity@ pPlayer, bool visible)
  {
    for (int i = 0, n = moneyDonateButtons.size(); i < n; i++)
    {
      moneyDonateButtons[i].SetVisible(pPlayer, visible);
    }
  }
  
  void SetVisible(CBaseEntity@ pCamera, CBaseEntity@ pPlayer, bool visible)
  {
    if (visible)
    {
      hCurrentPlayer = EHandle(pPlayer);
    }
    else
    {
      DeSelectTower();
      DeSelectGroundTower(pPlayer);
      DeSelectGroundWorker(pPlayer);
      HideTowerInfo(pPlayer);
      HideGhostTower();
      hCurrentPlayer = null;
    }
    SetTowerButtonsVisible(pPlayer, visible);
    exitButton.SetVisible(pPlayer, visible);
    moneyDisplay.SetVisible(pPlayer, visible);
    if (computerTerminalHealthDisplay !is null)
    {
      computerTerminalHealthDisplay.SetVisible(pPlayer, visible);
    }
    if (visible)
    {
      UpdateMoneyDisplay();
      UpdateComputerTerminalHealthDisplay();
      UpdatePosition(pCamera);
    }
  }
  
  private void UpdatePosition(CBaseEntity@ pCamera)
  {
    array<string> @towerButtonKeys = towerButtons.getKeys();
    for (int i = 0, n = towerButtonKeys.size(); i < n; i++)
    {
      GetTowerButton(towerButtonKeys[i]).UpdatePosition(pCamera.pev.origin, pCamera.pev.angles.x);
    }
    for (int i = 0, n = upgradeButtons.size(); i < n; i++)
    {
      upgradeButtons[i].UpdatePosition(pCamera.pev.origin, pCamera.pev.angles.x);
    }
    for (int i = 0, n = moneyDonateButtons.size(); i < n; i++)
    {
      moneyDonateButtons[i].UpdatePosition(pCamera.pev.origin, pCamera.pev.angles.x);
    }
    exitButton.UpdatePosition(pCamera.pev.origin, pCamera.pev.angles.x);
    moneyDisplay.UpdatePosition(pCamera.pev.origin, pCamera.pev.angles.x);
    if (computerTerminalHealthDisplay !is null)
    {
      computerTerminalHealthDisplay.UpdatePosition(pCamera.pev.origin, pCamera.pev.angles.x);
    }
    if (sellButton !is null)
    {
      sellButton.UpdatePosition(pCamera.pev.origin, pCamera.pev.angles.x);
    }
  }
  
  private void UpdateMoneyDisplay()
  {
    int money = worker.GetCurrentMoney();
    
    array<string> @towerButtonKeys = towerButtons.getKeys();
    for (int i = 0, n = towerButtonKeys.size(); i < n; i++)
    {
      int price = GetTowerPrice(towerButtonKeys[i]);
      GetTowerButton(towerButtonKeys[i]).SetColor(price <= money ? COLOR_PRICE_OK : COLOR_PRICE_NOTENOUGHMONEY);
    }
    
    for (int i = 0, n = upgradeButtons.size(); i < n; i++)
    {
      upgradeButtons[i].SetColor(upgradeButtons[i]._cost <= money ? COLOR_PRICE_OK : COLOR_PRICE_NOTENOUGHMONEY);
    }
    
    for (int i = 0, n = moneyDonateButtons.size(); i < n; i++)
    {
      moneyDonateButtons[i].SetColor(moneyDonateButtons[i]._cost2 <= money ? COLOR_PRICE_OK : COLOR_PRICE_NOTENOUGHMONEY);
    }
    
    uint count = 0;
    for (int moneydigits = money; count==0 || moneydigits > 0; moneydigits /= 10, count++)
    {
      moneyDisplay.SetSprite(count, ALPHANUM_SPRITE, MENU_MONEY_SCALE, moneydigits % 10, MENU_BUTTON_WIDTH*0.5 - MENU_MONEY_WIDTH - (MENU_MONEY_WIDTH*count), MENU_BUTTON_SPRITE_Z_OFFSET, true);
    }
    moneyDisplay.SetSprite(count, SELL_SPRITE, 0.9, 0, MENU_BUTTON_WIDTH*0.5 - MENU_MONEY_WIDTH - (MENU_MONEY_WIDTH*count), MENU_BUTTON_SPRITE_Z_OFFSET, true);
    moneyDisplay.HideSpritesFrom(count+1);
    if (hCurrentPlayer.IsValid())
    {
      moneyDisplay.SetVisible(hCurrentPlayer.GetEntity(), true);
    }
    if (pScheduledFlashMoneyTimeout !is null)
    {
      g_Scheduler.RemoveTimer(pScheduledFlashMoneyTimeout);
      @pScheduledFlashMoneyTimeout = null;
    }
    moneyDisplay.SetColor(COLOR_MONEY);
  }
  
  void FlashMoney(float starttime, bool red=true)
  {
    if (pScheduledFlashMoneyTimeout !is null)
    {
      g_Scheduler.RemoveTimer(pScheduledFlashMoneyTimeout);
      @pScheduledFlashMoneyTimeout = null;
    }
    if (g_Engine.time <= (starttime + MENU_MONEY_FLASH_TIME))
    {
      @pScheduledFlashMoneyTimeout = g_Scheduler.SetTimeout("CallFlashMoney", MENU_MONEY_FLASH_INTERVAL, @this, starttime, !red);
      moneyDisplay.SetColor(red?COLOR_FLASH_RED:COLOR_MONEY);
    }
    else
    {
      moneyDisplay.SetColor(COLOR_MONEY);
    }
  }
  
  private void UpdateComputerTerminalHealthDisplay()
  {
    if (computerTerminalHealthDisplay !is null)
    {
      CBaseEntity@ pComputerTerminal = worker.GetComputerTerminal();
      if (pComputerTerminal !is null)
      {
        int health = int(pComputerTerminal.pev.health);
        int maxHealth = int(pComputerTerminal.pev.max_health);
        
        uint[] healthDigits = GetDigits(health);
        uint[] maxHealthDigits = GetDigits(maxHealth);
        
        uint index = 0;
        
        computerTerminalHealthDisplay.SetSprite(index, m_fIsComputerTerminalHealthDisplayRed ? vFlashComputerTerminalHealthSprite : COMPUTER_TERMINAL_SPRITE, 1.5, 0, MENU_BUTTON_WIDTH*0.5 - MENU_MONEY_WIDTH, MENU_BUTTON_SPRITE_Z_OFFSET, false);
        index++;
        
        for (uint i = 0; i < healthDigits.size(); i++, index++)
        {
          computerTerminalHealthDisplay.SetSprite(index, ALPHANUM_SPRITE, MENU_MONEY_SCALE, healthDigits[i] % 10, MENU_BUTTON_WIDTH*0.5 - MENU_MONEY_WIDTH + (MENU_MONEY_WIDTH*index), MENU_BUTTON_SPRITE_Z_OFFSET, true);
        }
        
        computerTerminalHealthDisplay.SetSprite(index, ALPHANUM_SPRITE, MENU_MONEY_SCALE, GetCharacterFrame("/"), MENU_BUTTON_WIDTH*0.5 - MENU_MONEY_WIDTH + (MENU_MONEY_WIDTH*index), MENU_BUTTON_SPRITE_Z_OFFSET, true);
        index++;
        
        for (uint i = 0; i < maxHealthDigits.size(); i++, index++)
        {
          computerTerminalHealthDisplay.SetSprite(index, ALPHANUM_SPRITE, MENU_MONEY_SCALE, maxHealthDigits[i] % 10, MENU_BUTTON_WIDTH*0.5 - MENU_MONEY_WIDTH + (MENU_MONEY_WIDTH*index), MENU_BUTTON_SPRITE_Z_OFFSET, true);
        }
      }
      computerTerminalHealthDisplay.SetColor(m_fIsComputerTerminalHealthDisplayRed ? vFlashComputerTerminalHealthColor : COLOR_COMPUTER_TERMINAL_HEALTH);
    }
  }
  
  void FlashComputerTerminalHealth(bool red=true, bool firstCall=true)
  {
    if (computerTerminalHealthDisplay is null)
    {
      return;
    }
    if (firstCall)
    {
      float lastFlashComputerTerminalStarttime = flFlashComputerTerminalStarttime;
      flFlashComputerTerminalStarttime = g_Engine.time;
      if (g_Engine.time < (lastFlashComputerTerminalStarttime + MENU_TERMINALHEALTH_FLASH_TIME + MENU_TERMINALHEALTH_FLASH_INTERVAL + 0.1))
      {
        return;
      }
    }
    if (pScheduledFlashComputerTerminalHealthTimeout !is null)
    {
      g_Scheduler.RemoveTimer(pScheduledFlashComputerTerminalHealthTimeout);
      @pScheduledFlashComputerTerminalHealthTimeout = null;
    }
    if (g_Engine.time <= (flFlashComputerTerminalStarttime + MENU_TERMINALHEALTH_FLASH_TIME))
    {
      @pScheduledFlashComputerTerminalHealthTimeout = g_Scheduler.SetTimeout("CallFlashComputerTerminalHealth", MENU_TERMINALHEALTH_FLASH_INTERVAL, @this, !red);
      if (red)
      {
        computerTerminalHealthDisplay.SetSpriteModel(0, vFlashComputerTerminalHealthSprite, 1.5, 0, false);
        computerTerminalHealthDisplay.SetColor(vFlashComputerTerminalHealthColor);
        m_fIsComputerTerminalHealthDisplayRed = true;
      }
      else
      {
        computerTerminalHealthDisplay.SetSpriteModel(0, COMPUTER_TERMINAL_SPRITE, 1.5, 0, false);
        computerTerminalHealthDisplay.SetColor(COLOR_COMPUTER_TERMINAL_HEALTH);
        m_fIsComputerTerminalHealthDisplayRed = false;
      }
    }
    else
    {
      computerTerminalHealthDisplay.SetSpriteModel(0, COMPUTER_TERMINAL_SPRITE, 1.5, 0, false);
      computerTerminalHealthDisplay.SetColor(COLOR_COMPUTER_TERMINAL_HEALTH);
      m_fIsComputerTerminalHealthDisplayRed = false;
    }
  }
  
  private bool HideTowerInfo(CBaseEntity@ pPlayer)
  {
    /*
    if (HasGroundTowerSelected())
    {
      return false;
    }
    */
    PostClientMessage(EHandle(pPlayer), "");
    if (pScheduledKeepClientMessageUpInterval !is null)
    {
      g_Scheduler.RemoveTimer(pScheduledKeepClientMessageUpInterval);
      @pScheduledKeepClientMessageUpInterval = null;
      return true;
    }
    else
    {
      return false;
    }
  }
  
  private void ShowTowerInfo(CBaseEntity@ pPlayer, string infoText)
  {
    /*
    if (HasGroundTowerSelected())
    {
      return;
    }
    */
    HideTowerInfo(pPlayer);
    PostClientMessage(EHandle(pPlayer), infoText);
    @pScheduledKeepClientMessageUpInterval = g_Scheduler.SetInterval("PostClientMessage", 1, -1, EHandle(pPlayer), infoText);
  }
  
  void Update(CBaseEntity@ pCamera, CBaseEntity@ pPlayer, CBaseEntity@ pEntity, int gridX, int gridY)
  {
    UpdatePosition(pCamera);
    if (HasTowerSelected() && !HasGroundTowerSelected() && IsGroundEntity(pEntity) && gridX != INVALID_GRID && gridY != INVALID_GRID)
    {
      ShowGhostTower(pEntity, Vector(gridX, gridY, 0));
    }
    else
    {
      HideGhostTower();
    }
    if (!HasGroundTowerSelected())
    {
      if (mouseHoverTower != GetTowerForButton(pEntity))
      {
        if (IsTowerButton(pEntity))
        {
          GetTowerButton(GetTowerForButton(pEntity)).MouseOver(true);
        }
        if (towerButtons.exists(mouseHoverTower))
        {
          GetTowerButton(mouseHoverTower).MouseOver(false);
          HideTowerInfo(pPlayer);
        }
        mouseHoverTower = GetTowerForButton(pEntity);
      }
    }
  }
  
  void LeftClick(CBaseEntity@ pCamera, CBaseEntity@ pPlayer, CBaseEntity@ pEntity, int gridX, int gridY)
  {
    if (IsExitButton(pEntity))
    {
      SetVisible(pCamera, pPlayer, false);
      pCamera.Use(pPlayer, pPlayer, USE_OFF, 0);
    }
    else if (HasGroundWorkerSelected())
    {
      if (IsMoneyDonateButton(pEntity))
      {
        int cost = GetMoneyDonateButton(pEntity)._cost;
        int cost2 = GetMoneyDonateButton(pEntity)._cost2;
        if (worker.CheckAndTakeMoney(pPlayer, cost2))
        {
          pGroundWorker.AddMoney(cost);
        }
        else
        {
          FlashMoney(g_Engine.time);
        }
      }
      else
      {
        DeSelectGroundWorker(pPlayer);
      }
    }
    else if (!HasTowerSelected() && IsGroundTower(Vector(gridX, gridY, 0)) && (worker.self == GetGroundTower(Vector(gridX, gridY, 0)).GetWorker().self))
    {
      SelectGroundTower(pCamera, pPlayer, GetGroundTower(Vector(gridX, gridY, 0)));
    }
    else if (HasGroundTowerSelected())
    {
      if (IsGroundTowerButton(pEntity))
      {
        int index = GetGroundTowerButtonIndex(pEntity);
        CBaseTower@ pTower = GetTower(hGroundTower.GetEntity());
        TowerUpgradeInfo@ upgradeInfo = pTower.GetUpgradeInfo()[index];
        if (upgradeInfo.isEnabled)
        {
          if (worker.CheckAndTakeMoney(pPlayer, upgradeInfo.cost))
          {
            pTower.Upgrade(upgradeInfo);
            SelectGroundTower(pCamera, pPlayer, pTower);
          }
          else
          {
            FlashMoney(g_Engine.time);
          }
        }
      }
      else
      {
        if (IsSellTowerButton(pEntity))
        {
          CBaseTower@ pTower = GetTower(hGroundTower.GetEntity());
          worker.AddMoney(pTower.GetSellValue());
          RemoveTower(pTower);
        }
        DeSelectGroundTower(pPlayer);
      }
    }
    else if (IsTowerButton(pEntity))
    {
      if (worker.CheckMoney(pPlayer, GetTowerPrice(GetTowerForButton(pEntity))))
      {
        SelectTower(GetTowerForButton(pEntity));
      }
      else
      {
        FlashMoney(g_Engine.time);
      }
    }
    else if (HasTowerSelected() && gridX!=INVALID_GRID && gridY!=INVALID_GRID && CanSpawnTowerThere(Vector(gridX, gridY, 0), pEntity, IsBorderTower(selectedTower), IsPathTower(selectedTower)))
    {
      if (worker.CheckAndTakeMoney(pPlayer, GetTowerPrice(selectedTower)))
      {
        Vector angles;
        if (hGhostTower.IsValid())
        {
          angles = hGhostTower.GetEntity().pev.angles;
        }
        else
        {
          angles = critterRouteManager.GetPathAngles(Vector(gridX, gridY, 0), angles);
        }
        worker.Build(selectedTower, GetTowerModel(selectedTower), GetTowerModelScale(selectedTower), gridX, gridY, angles, pEntity, GetTowerPrice(selectedTower));
        DeSelectTower();
      }
      else
      {
        FlashMoney(g_Engine.time);
      }
    }
    else if (!HasTowerSelected() && !HasGroundTowerSelected() && IsWorkerField(Vector(gridX, gridY, 0)))
    {
      Worker@ groundWorker = GetWorker(Vector(gridX, gridY, 0));
      if (groundWorker !is null && groundWorker.self !is worker.self)
      {
        SelectGroundWorker(pCamera, pPlayer, groundWorker);
      }
    }
  }
  
  void RightMouseDown(CBaseEntity@ pCamera, CBaseEntity@ pPlayer, CBaseEntity@ pEntity, int gridX, int gridY)
  {
    //if (!HasGroundTowerSelected())
    {
      if (IsTowerButton(pEntity))
      {
        ShowTowerInfo(pPlayer, GetTowerInfoText(GetTowerForButton(pEntity)));
      }
      else if (IsGroundTowerButton(pEntity))
      {
        int index = GetGroundTowerButtonIndex(pEntity);
        CBaseTower@ pTower = GetTower(hGroundTower.GetEntity());
        TowerUpgradeInfo@ upgradeInfo = pTower.GetUpgradeInfo()[index];
        ShowTowerInfo(pPlayer, upgradeInfo.GetInfoText());
      }
      else if (HasGroundWorkerSelected() && IsMoneyDonateButton(pEntity))
      {
        ShowTowerInfo(pPlayer,
            "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"+
            "Donate some money\nfor a higher cost to another player.\n\n"+
            "Receiver: "+pGroundWorker.GetName()+"\n\n"+
            "They get: "+GetMoneyDonateButton(pEntity)._cost+"\n"+
            "You pay:"+GetMoneyDonateButton(pEntity)._cost2
          );
      }
      else if (IsSellTowerButton(pEntity))
      {
        ShowTowerInfo(pPlayer, "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\nSell this tower\nfor 50% of its original value.\n\nSell Value: "+sellButton._cost);
      }
      else if (IsGroundTower(Vector(gridX, gridY, 0)))
      {
        ShowTowerInfo(pPlayer, GetGroundTower(Vector(gridX, gridY, 0)).GetInfoText(false));
      }
      else if (IsWorkerField(Vector(gridX, gridY, 0)))
      {
        Worker@ groundWorker = GetWorker(Vector(gridX, gridY, 0));
        if (groundWorker !is null)
        {
          string info_text = "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\nWorker \""+worker.GetName()+"\"";
          if (groundWorker.self !is worker.self)
          {
            info_text = info_text +"\n\nMoney: "+groundWorker.GetCurrentMoney();
          }
          else
          {
            info_text = info_text + "\n\n(This is your worker!)";
          }
          ShowTowerInfo(pPlayer, info_text);
        }
      }
    }
  }
  
  void RightMouseUp(CBaseEntity@ pCamera, CBaseEntity@ pPlayer, CBaseEntity@ pEntity, int gridX, int gridY)
  {
    //if (!HasGroundTowerSelected())
    {
      HideTowerInfo(pPlayer);
    }
  }
  
  void RightClick(CBaseEntity@ pCamera, CBaseEntity@ pPlayer, CBaseEntity@ pEntity, int gridX, int gridY)
  {
    bool wasShowingInfo = HideTowerInfo(pPlayer);
    if (!wasShowingInfo)
    {
      if (HasGroundTowerSelected())
      {
        if (!IsGroundTowerButton(pEntity) && !IsSellTowerButton(pEntity))
        {
          DeSelectGroundTower(pPlayer);
        }
      }
      else if (HasGroundWorkerSelected())
      {
        if (!IsMoneyDonateButton(pEntity))
        {
          DeSelectGroundWorker(pPlayer);
        }
      }
      else if (HasTowerSelected())
      {
        DeSelectTower();
      }
      else if (gridX!=INVALID_GRID && gridY!=INVALID_GRID)
      {
        CSprite@ sprite = g_EntityFuncs.CreateSprite("sprites/explode1.spr", Vector(gridX,gridY,10), true);
        sprite.AnimateAndDie(20);
        sprite.SetTransparency(kRenderTransAdd, 0, 0, 0, 255, kRenderFxNone);
        sprite.SetScale(0.5);
        
        worker.CancelBuild();
        worker.RunTo(gridX, gridY);
      }
    }
  }
  
  void MoneyChanged(int newMoney)
  {
    UpdateMoneyDisplay();
  }
  
  void ComputerTerminalHealthChanged(int health, int max_health)
  {
    UpdateComputerTerminalHealthDisplay();
  }
  
  void ComputerTerminalUnderAttackWarning()
  {
    vFlashComputerTerminalHealthSprite = WARNING_SPRITE;
    vFlashComputerTerminalHealthColor = COLOR_FLASH_RED;
    FlashComputerTerminalHealth();
  }
  
  void ComputerTerminalRepairNotice()
  {
    vFlashComputerTerminalHealthSprite = COMPUTER_TERMINAL_REPAIR_SPRITE;
    vFlashComputerTerminalHealthColor = COLOR_FLASH_GREEN;
    FlashComputerTerminalHealth();
  }
  
  bool IsCurrentPlayer(CBaseEntity@ pPlayer)
  {
    return pPlayer !is null && pPlayer.IsPlayer() && hCurrentPlayer.IsValid() && pPlayer == hCurrentPlayer.GetEntity();
  }
};

// These have to be public for scheduler
void CallFlashMoney(Menu@ menu, float starttime, bool red)
{
  menu.FlashMoney(starttime, red);
}
void CallFlashComputerTerminalHealth(Menu@ menu, bool red)
{
  menu.FlashComputerTerminalHealth(red, false);
}
