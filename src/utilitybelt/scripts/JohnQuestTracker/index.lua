local scriptFilesystem = require('filesystem').GetScript()
local dataFilesystem = require('filesystem').GetData()
local views = require("utilitybelt.views")
local IM = require("imgui")
local ImGui = IM.ImGui
local tableHelpers = require('table-helpers')

local hud = nil
local lastRefreshTimestamp = nil
local questRegex = "^(%S+) %- (%d+) solves %(%d{0,11}%)\"?.*\" .* %d{0,11}?.*$"
local questFlags = {}
local quests = nil
local filename = nil
local showCompleted = true

local function getJohnQuestData()
  local serverName = game.ServerName:lower():gsub(" ", "-")
  local serverSpecificJohnFile = "data/" .. serverName .. ".json"

  if scriptFilesystem.FileExists(serverSpecificJohnFile) then
    return scriptFilesystem.ReadText(serverSpecificJohnFile)
  end

  if not scriptFilesystem.FileExists("data/ace.json") then
    error("File not found. Expected 'data/ace.json' to exist.")
  end

  return scriptFilesystem.ReadText("data/ace.json")
end

local function loadQuests()
  if not dataFilesystem.FileExists(filename) then
    local questData = getJohnQuestData()
    dataFilesystem.WriteText(filename, questData)
  end

  local questData = dataFilesystem.ReadText(filename)
  quests = json.parse(questData)

  for _, quest in pairs(quests) do
    if not tableHelpers.contains(questFlags, quest["flag"]) then
      table.insert(questFlags, quest["flag"])
    end
  end
end

--- @param message string
local function parseFlagFromMessage(message)
  dataFilesystem.AppendText("log.txt", message .. "\n")

  local _, __, flag, solves = string.find(message, questRegex)
  return { name = flag, solves = tonumber(solves) }
end

local function beginsWithFlag(message)
  for _, questFlag in ipairs(questFlags) do
    if message:startsWith(questFlag) then
      return true
    end
  end

  return false
end

--- @param event ChatEventArgs
local function onChatText(event)
  local message = event.Message
  local isQuestFlagMessageFromServer = event.Room == ChatChannel.None and
      event.Type == ChatMessageType.Default and
      string.match(message, questRegex)

  if not isQuestFlagMessageFromServer then
    return
  end

  if (lastRefreshTimestamp ~= nil and os.difftime(os.time(), lastRefreshTimestamp) < 10) then
    event.Eat = true
  end

  if beginsWithFlag(message) then
    local flag = parseFlagFromMessage(message)
    dataFilesystem.AppendText("log.txt", json.serialize(flag) .. "\n")

    for _, questDetails in pairs(quests) do
      if questDetails["flag"] == flag["name"] then
        questDetails["completed"] = bit32.band(questDetails["bit"], flag["solves"]) == questDetails["bit"]
      end
    end

    dataFilesystem.WriteText(filename, json.serialize(quests))
  end
end

local function refresh()
  for _, questDetails in pairs(quests) do
    questDetails["completed"] = false
  end

  dataFilesystem.WriteText(filename, json.serialize(quests))

  lastRefreshTimestamp = os.time()
  game.Actions.InvokeChat("/myquests")
end

local function onPreRender()
  local viewport = ImGui.GetMainViewport()
  local windowPosition = Vector2.new(viewport.GetCenter().X, viewport.GetCenter().Y)
  ImGui.SetNextWindowPos(windowPosition, IM.ImGuiCond.FirstUseEver, Vector2.new(0.5, 0.5))
end

local function onRender()
  if ImGui.Button("Refresh") then
    refresh()
  end

  ImGui.SameLine()

  local showHideButtonText = "Include Completed"
  if showCompleted then
    showHideButtonText = "Hide Completed"
  end

  if ImGui.Button(showHideButtonText) then
    showCompleted = not showCompleted
  end

  ImGui.NewLine()

  local completed = 0
  for _, value in pairs(quests) do
    if value["completed"] then
      completed = completed + 1
    end
  end

  ImGui.Text("Completed: " .. completed)

  ImGui.NewLine()

  for key, value in pairs(quests) do
    if showCompleted and value["completed"] then
      ImGui.Checkbox(key, value["completed"])
    end

    if not value["completed"] then
      ImGui.Checkbox(key, value["completed"])
    end
  end
end

local function init()
  filename = game.ServerName .. "/" .. game.Character.Weenie.Name .. ".json"

  hud = views.Huds.CreateHud("John Quest Tracker", 28632)
  hud.WindowSettings = IM.ImGuiWindowFlags.AlwaysAutoResize

  game.World.OnChatText.Add(onChatText)

  hud.OnPreRender.Add(onPreRender)
  hud.OnRender.Add(onRender)

  loadQuests()

  print("Initialized.")
end

local function dispose()
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
