local views = require("utilitybelt.views")
local IM = require("imgui")
local ImGui = IM.ImGui

local hud = nil
--- @type Enchantment|nil
local surgeEnchantment = nil

--- @param num number
--- @return string
local function makeDoubleDigitNumber(num)
  local s = tostring(math.floor(num))
  if #s < 2 then
    s = "0" .. s
  end

  return s
end

--- @param timeRemaining number
--- @return string
local function formatTimeRemaining(timeRemaining)
  local x = "00:00"
  if timeRemaining > 0 then
    x = makeDoubleDigitNumber(timeRemaining / 60) .. ":" .. makeDoubleDigitNumber(timeRemaining % 60)
  end

  return x
end

---@param timeRemaining number
---@return Vector4
local function chooseTextColor(timeRemaining)
  if timeRemaining > 5 then
    return Vector4.new(0, 255, 0, 1)   -- green
  elseif timeRemaining <= 5 and timeRemaining > 0 then
    return Vector4.new(255, 255, 0, 1) -- yellow
  end

  return Vector4.new(255, 0, 0, 1) -- red
end

local function onPreRender()
  local viewport = ImGui.GetMainViewport()
  local windowPosition = Vector2.new(viewport.GetCenter().X + 75, viewport.GetCenter().Y + 50)
  ImGui.SetNextWindowSizeConstraints(Vector2.new(116, 29), Vector2.new(116, 29));
  ImGui.SetNextWindowPos(windowPosition, IM.ImGuiCond.Always)
end

local function onRender()
  local timeRemaining = 0
  if surgeEnchantment ~= nil then
    timeRemaining = (surgeEnchantment.ExpiresAt - DateTime.UtcNow).TotalSeconds

    ImGui.TextColored(chooseTextColor(timeRemaining), "Surging: " .. formatTimeRemaining(timeRemaining))
  else
    ImGui.TextColored(chooseTextColor(timeRemaining), "Surging: No")
  end
end

--- @param event EnchantmentsChangedEventArgs
local function onEnchantmentsChanged(event)
  local spell = game.Character.SpellBook.Get(event.Enchantment.SpellId)
  local isDestructionSurge = spell.Name == "Surge of Destruction"
  local isAddEnchantment = event.Type == AddRemoveEventType.Added
  local isRemoveEnchantment = event.Type == AddRemoveEventType.Removed

  if isAddEnchantment and isDestructionSurge then
    surgeEnchantment = event.Enchantment
  elseif isRemoveEnchantment and isDestructionSurge then
    surgeEnchantment = nil
  end
end

local function init()
  hud = views.Huds.CreateHud("Surge Detector", 27651)
  hud.WindowSettings = IM.ImGuiWindowFlags.NoDecoration + IM.ImGuiWindowFlags.NoScrollbar + IM.ImGuiWindowFlags.NoMove +
      IM.ImGuiWindowFlags.AlwaysAutoResize

  game.Character.OnEnchantmentsChanged.Add(onEnchantmentsChanged)

  hud.OnPreRender.Add(onPreRender)
  hud.OnRender.Add(onRender)

  print("Initialized.")
end

local function dispose()
  hud.Visible = false

  hud.OnRender.Remove(onRender)
  hud.OnPreRender.Remove(onPreRender)

  hud.Dispose()
end

game.OnStateChanged.Add(function(event)
  if event.NewState == ClientState.In_Game then
    init()
  elseif event.NewState == ClientState.Logging_Out then
    dispose()
  end
end)

game.OnScriptEnd.Once(dispose)

if game.State == ClientState.In_Game then init() end
