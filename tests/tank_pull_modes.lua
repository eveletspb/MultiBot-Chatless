-- Run from the addon root: luajit tests/tank_pull_modes.lua
local sent, saved, notices = {}, {}, {}
local raidMembers, partyMembers = 0, 4
GetNumRaidMembers = function() return raidMembers end
GetNumPartyMembers = function() return partyMembers end
GetTime = function() return 1 end
SendChatMessage = function() error("Unexpected chat fallback") end

MultiBot = { tips = { expand = {} } }
dofile("Core/MultiBotEngine.lua")
dofile("Core/MultiBotComm.lua")
MultiBot.L = function(key) return key end
MultiBot.SetSavedMainBarValue = function(key, value) saved[key] = value end
MultiBot.NotifyBridgeCommandResult = function(result) notices[#notices + 1] = result end
MultiBot.Comm.Send = function(opcode, payload)
    assert(opcode == "RUN")
    sent[#sent + 1] = payload
    return true
end
MultiBot.bridge.connected = true
MultiBot.bridge.groupOrderCapable = true

local function newFrame(parent)
    local frame = { parent = parent, buttons = {}, frames = {}, shown = true }
    function frame:Hide() self.shown = false end
    function frame:Show() self.shown = true end
    function frame:IsVisible() return self.shown end
    frame.addButton = function(name, x, y, icon, tip)
        local button = { parent = frame, texture = icon, tip = tip }
        button.setButton = function(texture, tooltip)
            button.texture, button.tip = texture, tooltip
        end
        button.setEnable = function() button.state = true; return button end
        button.setDisable = function() button.state = false; return button end
        button.doHide = function() return button end
        frame.buttons[name] = button
        return button
    end
    frame.addFrame = function(name)
        local child = newFrame(frame)
        frame.frames[name] = child
        return child
    end
    return frame
end

MultiBot.BindShiftRightSwapButtons = function(_, _, entries)
    for _, entry in ipairs(entries) do
        if entry.name == "Tanker" then assert(entry.frameName == "Tanker") end
    end
end
dofile("UI/MultiBotLeftCoreUI.lua")
local left = newFrame()
MultiBot.InitializeLeftCoreUI(left)
local shield, menu = left.buttons.Tanker, left.frames.Tanker
assert(not menu.shown and #sent == 0)
shield.doLeft()
assert(sent[1]:find("~@tank do attack my target$"))
MultiBot.bridge.groupOrderCommands = {}

for _, mode in ipairs({ { "Pull", "pull" }, { "PullBack", "pull back" }, { "Attack", "do attack my target" } }) do
    local before = #sent
    shield.doRight()
    assert(menu.shown)
    menu.buttons[mode[1]].doLeft()
    assert(not menu.shown and #sent == before, "Selecting a mode must not attack")
    assert(saved.TankerMode == mode[1])
    assert(shield.tip == "tips.tanker." .. mode[1])
    shield.doLeft()
    assert(#sent == before + 1)
    assert(sent[#sent]:find("^GROUP_ORDER~PARTY~"))
    assert(sent[#sent]:find("~@tank " .. mode[2] .. "$"))
    local token, command = sent[#sent]:match("^GROUP_ORDER~PARTY~~([^~]+)~(.+)$")
    assert(MultiBot.Comm.HandleGroupOrderAddonMessage("GROUP_ORDER_ACK",
        "PARTY~~" .. token .. "~" .. command .. "~1~1~0~OK"))
    assert(not MultiBot.bridge.groupOrderCommands[token])
    assert(notices[#notices].status == "ok")
end

raidMembers = 10
menu.buttons.PullBack.doLeft()
shield.doLeft()
assert(sent[#sent]:find("^GROUP_ORDER~RAID~"))
local before = #sent
shield.doLeft()
assert(#sent == before, "An outstanding identical order must not be duplicated")
MultiBot.bridge.groupOrderCommands = {}
assert(not MultiBot.Comm.RunGroupOrderCommand("PARTY", "", "@tank pull; follow"))
assert(not MultiBot.Comm.RunGroupOrderCommand("BOT", "", "@tank pull"))

MultiBot.bridge.connected = false
MultiBot.allowLegacyChatFallback = true
assert(not MultiBot.ActionToGroup("@tank pull"))
assert(not MultiBot.ActionToGroup("@tank pull back"))
assert(notices[#notices].reason == "BRIDGE_UNAVAILABLE")
MultiBot.bridge.connected = true
raidMembers, partyMembers = 0, 0
assert(not MultiBot.ActionToGroup("@tank pull back"))
assert(notices[#notices].reason == "NO_GROUP")
assert(#sent == before)
print("tank pull modes: UI selection, persistence, party/raid routing and rejection checks passed")
