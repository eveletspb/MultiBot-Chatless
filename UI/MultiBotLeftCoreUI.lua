if not MultiBot then return end

local MODE_FRAME_NAME = "Mode"
local MODE_BUTTON_NAME = "Mode"
local MODE_BUTTON_ICON = "Interface\\AddOns\\MultiBot\\Icons\\mode_passive.blp"
local MODE_FRAME_X = -172
local MODE_FRAME_Y = 34

local TANK_MODES = {
    { name = "Attack", command = "@tank do attack my target", icon = "ability_warrior_shieldbash" },
    { name = "Pull", command = "@tank pull", icon = "ability_hunter_markedfordeath" },
    { name = "PullBack", command = "@tank pull back", icon = "ability_hunter_disengage" },
}

local function createTankerUI(tLeft)
    local button = tLeft.addButton("Tanker", -238, 0, TANK_MODES[1].icon, "")
    local menu = tLeft.addFrame("Tanker", -240, 34)
    menu:Hide()

    local function selectMode(mode)
        button.setButton(mode.icon, MultiBot.L("tips.tanker." .. mode.name))
        button.doLeft = function()
            MultiBot.ActionToGroup(mode.command)
        end
        menu:Hide()
        if MultiBot.RequestClickBlockerUpdate then
            MultiBot.RequestClickBlockerUpdate(menu)
        end
    end

    button.doRight = function()
        MultiBot.ShowHideSwitch(menu)
    end

    selectMode(TANK_MODES[1])
    for index, mode in ipairs(TANK_MODES) do
        local option = menu.addButton(mode.name, 0, (index - 1) * 30, mode.icon, MultiBot.L("tips.tanker." .. mode.name))
        option.doLeft = function()
            selectMode(mode)
            MultiBot.SetSavedMainBarValue("TankerMode", mode.name)
        end
    end
end

-- MB_P1A_MODE_BLOCKED_STATE_V1_START
local function dispatchModeToggleAction(button, enableCommand, disableCommand)
    local wasEnabled = button.state == true
    local command = wasEnabled and disableCommand or enableCommand

    if not MultiBot.ActionToGroup(command) then
        return false
    end

    if wasEnabled then
        button.setDisable()
    else
        button.setEnable()
    end
    return true
end

local function bindModeToggleAction(modeButton, enableCommand, disableCommand)
    modeButton.setEnable().doLeft = function(button)
        dispatchModeToggleAction(button, enableCommand, disableCommand)
    end
end
-- MB_P1A_MODE_BLOCKED_STATE_V1_END
local function createModeUI(tLeft)
    local modeButton = tLeft.addButton(MODE_BUTTON_NAME, -170, 0, MODE_BUTTON_ICON, MultiBot.L("tips.mode.master")).setDisable()

    modeButton.doRight = function(button)
        MultiBot.ShowHideSwitch(button.parent.frames[MODE_FRAME_NAME])
    end

    modeButton.doLeft = function(button)
        dispatchModeToggleAction(button, "co +passive,?", "co -passive,?")
    end
    local modeFrame = tLeft.addFrame(MODE_FRAME_NAME, MODE_FRAME_X, MODE_FRAME_Y)
    modeFrame:Hide()

    modeFrame.addButton("Passive", 0, 0, MODE_BUTTON_ICON, MultiBot.L("tips.mode.passive")).doLeft = function(button)
        if MultiBot.SelectToGroup(button.parent.parent, MODE_FRAME_NAME, button.texture, "co +passive,?") then
            bindModeToggleAction(button.parent.parent.buttons[MODE_BUTTON_NAME], "co +passive,?", "co -passive,?")
        end
    end

    modeFrame.addButton("Grind", 0, 30, "Interface\\AddOns\\MultiBot\\Icons\\mode_grind.blp", MultiBot.L("tips.mode.grind")).doLeft = function(button)
        if MultiBot.SelectToGroup(button.parent.parent, MODE_FRAME_NAME, button.texture, "grind") then
            bindModeToggleAction(button.parent.parent.buttons[MODE_BUTTON_NAME], "grind", "follow")
        end
    end
end

local function createStayFollowUI(tLeft)
    tLeft.addButton("Stay", -136, 0, "Interface\\AddOns\\MultiBot\\Icons\\command_stay.blp", MultiBot.L("tips.stallow.stay")).doLeft = function(button)
        MultiBot.ActionToGroup("stay", function(result)
            if result and (result.status == "ok" or result.status == "legacy") then
                button.parent.buttons["Follow"].doShow()
                button.parent.buttons["ExpandFollow"].setDisable()
                button.parent.buttons["ExpandStay"].setEnable()
                button.doHide()
            end
        end)
    end

    tLeft.addButton("Follow", -136, 0, "Interface\\AddOns\\MultiBot\\Icons\\command_follow.blp", MultiBot.L("tips.stallow.follow")).doHide().doLeft = function(button)
        MultiBot.ActionToGroup("follow", function(result)
            if result and (result.status == "ok" or result.status == "legacy") then
                button.parent.buttons["Stay"].doShow()
                button.parent.buttons["ExpandFollow"].setEnable()
                button.parent.buttons["ExpandStay"].setDisable()
                button.doHide()
            end
        end)
    end

    tLeft.addButton("ExpandStay", -136, 0, "Interface\\AddOns\\MultiBot\\Icons\\command_stay.blp", MultiBot.tips.expand.stay).doHide().setDisable().doLeft = function(button)
        MultiBot.ActionToGroup("stay", function(result)
            if result and (result.status == "ok" or result.status == "legacy") then
                button.parent.buttons["ExpandFollow"].setDisable()
                button.setEnable()
            end
        end)
    end

    tLeft.addButton("ExpandFollow", -170, 0, "Interface\\AddOns\\MultiBot\\Icons\\command_follow.blp", MultiBot.tips.expand.follow).doHide().doLeft = function(button)
        MultiBot.ActionToGroup("follow", function(result)
            if result and (result.status == "ok" or result.status == "legacy") then
                button.parent.buttons["ExpandStay"].setDisable()
                button.setEnable()
            end
        end)
    end
end

function MultiBot.InitializeLeftCoreUI(tLeft)
    if not tLeft or not tLeft.addButton or not tLeft.addFrame then
        return nil
    end

    if MultiBot.BuildBotRTIActionUI then
        MultiBot.BuildBotRTIActionUI(tLeft, -306, 0)
    end

    if MultiBot.BuildDisperseUI then
        MultiBot.BuildDisperseUI(tLeft)
    end

    if MultiBot.BuildLootUI then
        MultiBot.BuildLootUI(tLeft)
    end

    createTankerUI(tLeft)

    createModeUI(tLeft)
    createStayFollowUI(tLeft)

    if MultiBot.BindShiftRightSwapButtons then
        MultiBot.BindShiftRightSwapButtons(tLeft, "LeftRoot", {
            { name = "BotRTI", id = "BotRTIActionButton", frameName = "BotRTIAction" },
            { name = "Disperse", frameName = "DisperseMenu" },
            { name = "Loot", frameName = "LootMenu" },
            { name = "Tanker", frameName = "Tanker" },
            { name = "Mode", frameName = "Mode" },
            { name = "Stay" },
            { name = "Follow" },
        })
    end

    return tLeft
end
