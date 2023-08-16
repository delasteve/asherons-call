--- @param event Social_FriendsUpdate_S2C_EventArgs
local function friendUpdate(event)
  for _, k in ipairs(event.Data.Friend.Friends) do
    if k.Online == 1 then
      print(k.Name .. " has logged in.")
    else
      print(k.Name .. " has logged out.")
    end
  end
end

local function init()
  game.Messages.Incoming.Social_FriendsUpdate.Add(friendUpdate)

  print("Initialized.")
end

local function dispose()
  game.Messages.Incoming.Social_FriendsUpdate.Remove(friendUpdate)
end

game.OnStateChanged.Add(function(evt)
  if evt.NewState == ClientState.In_Game then
    init()
  elseif evt.NewState == ClientState.Logging_Out then
    dispose()
  end
end)

game.OnScriptEnd.Once(dispose)

if game.State == ClientState.In_Game then init() end
