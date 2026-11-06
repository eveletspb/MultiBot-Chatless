-- Run from the addon root: luajit tests/audit_regressions.lua
local now, timers, sent, frames, chat = 10, {}, {}, {}, {}
GetTime = function() return now end
UnitName = function() return 'Owner' end
GetNumRaidMembers = function() return 0 end
GetNumPartyMembers = function() return 0 end
SendChatMessage = function(...) chat[#chat + 1] = {...} end
local nativeSend = SendChatMessage
CreateFrame = function()
    local frame = { scripts = {} }
    function frame:Show() end
    function frame:SetScript(key, callback) self.scripts[key] = callback end
    frames[#frames + 1] = frame
    return frame
end
MultiBot = {
    L = function(key) return key end,
    SendChatMessage = SendChatMessage,
    TimerAfter = function(delay, callback) timers[#timers + 1] = { at = now + delay, callback = callback } end,
}
local function advance(seconds)
    now = now + seconds
    local pending = timers
    timers = {}
    for _, timer in ipairs(pending) do
        if timer.at <= now then timer.callback() else timers[#timers + 1] = timer end
    end
end
local function receive(opcode, payload)
    return MultiBot.Comm.HandleAddonMessage('MBOT', opcode .. '~' .. (payload or ''), 'WHISPER', 'Owner')
end
dofile('Core/MultiBotComm.lua')
local comm, bridge = MultiBot.Comm, MultiBot.bridge
comm.Send = function(opcode, payload) sent[#sent + 1] = {opcode, payload}; return true end
bridge.connected = true
bridge.capabilitiesResolved = true
receive('CAPS_BEGIN')
receive('CAPS', 'INVENTORY_EXACT_V1,ITEM_IDENTITY_V1,ITEM_MOVE_V1,ITEM_TRADE_V1,ITEM_EQUIP_V1,ITEM_DESTROY_V1,ITEM_USE_V1,ITEM_SELL_SINGLE_V1,ITEM_DEPOSIT_EXACT_V1')
receive('CAPS_END')
assert(bridge.inventoryItemIdentityCapable)

local snapshot
MultiBot.OnBridgeInventoryExactSnapshot = function(_, value) snapshot = value end
local function inventory(withIdentity)
    snapshot = nil
    local token = assert(comm.RequestInventoryExact('Bot'))
    receive('INV_EXACT_BEGIN', 'Bot~' .. token)
    receive('INV_ITEM_LOC', 'Bot~' .. token .. '~255~23~123~1~0')
    if withIdentity then receive('INV_ITEM_IDENTITY', 'Bot~' .. token .. '~255~23~111') end
    receive('INV_EXACT_END', 'Bot~' .. token)
    return snapshot
end
assert(not inventory(false), 'Incomplete identities must not replace the displayed inventory')
assert(inventory(true).itemsByPosition['255:23'].guid == 111)
local operations = {
    { 'Move', { 'Bot', 255, 23, 123, 1, 255, 24, 0, 0, 111, 0 }, '~111~0$' },
    { 'Trade', { 'Bot', 255, 23, 123, 1, 111 }, '~111$' },
    { 'Equip', { 'Bot', 255, 23, 123, 1, 111 }, '~111$' },
    { 'Destroy', { 'Bot', 255, 23, 123, 1, 111 }, '~111$' },
    { 'Use', { 'Bot', 255, 23, 123, 1, 111 }, '~111$' },
    { 'Sell', { 'Bot', 255, 23, 123, 1, 111 }, '~111$' },
    { 'DepositExact', { 'Bot', 'BANK_DEPOSIT', 255, 23, 123, 1, 111 }, '~111$' },
}
for _, operation in ipairs(operations) do
    bridge.inventoryItemIdentityCapable = false
    assert(not comm['RunInventoryItem' .. operation[1]](unpack(operation[2])))
    bridge.inventoryItemIdentityCapable = true
    assert(comm['RunInventoryItem' .. operation[1]](unpack(operation[2])))
    assert(sent[#sent][2]:match(operation[3]), operation[1] .. ' lost its item GUID')
end
assert(not comm.RunInventoryItemDestroy('Bot', 255, 23, 123, 1))

advance(6)
local results = {}
MultiBot.OnBridgeInventoryItemActionResult = function(_, _, _, result, reason)
    results[#results + 1] = {result, reason}
end
local token = assert(comm.RunInventoryItemAction('Bot', 'BUY_ITEM', 123, 3))
assert(not comm.RunInventoryItemAction('Bot', 'BUY_ITEM', 123, 3), 'Do not duplicate an outstanding purchase')
receive('ERR', 'RUN~ITEM_ACTION~' .. token .. '~BAD_NUMBER')
assert(not bridge.inventoryItemActions[token] and results[#results][2] == 'BAD_NUMBER')
advance(6)
assert(#results == 1, 'A late timeout must not complete the same action twice')
token = assert(comm.RunInventoryItemAction('Bot', 'BUY_ITEM', 123, 3))
advance(6)
assert(not bridge.inventoryItemActions[token] and results[#results][2] == 'TIMEOUT')
token = assert(comm.RunInventoryItemAction('Bot', 'BUY_ITEM', 123, 3))
receive('INVENTORY_ITEM_ACTION', 'Other~' .. token .. '~BUY_ITEM~123~OK~OK~3')
assert(bridge.inventoryItemActions[token], 'A reply for another bot must be ignored')
receive('INVENTORY_ITEM_ACTION', 'Bot~' .. token .. '~BUY_ITEM~123~OK~OK~3')
assert(not bridge.inventoryItemActions[token] and results[#results][1] == 'OK')

-- Exercise the shipped bank UI, including its OnHide hook.
local methods = {}
methods.__index = function(_, key)
    return function(self, ...)
        if key == 'CreateTexture' or key == 'CreateFontString' then return setmetatable({}, methods) end
        if key == 'Show' then self.shown = true end
        if key == 'Hide' then
            self.shown = false
            if self.scripts.OnHide then self.scripts.OnHide(self) end
        end
        if key == 'IsShown' then return self.shown end
        if key == 'SetScript' then self.scripts[(...)] = select(2, ...) end
        if key == 'HookScript' then self.scripts[(...)] = select(2, ...) end
    end
end
CreateFrame = function() return setmetatable({ shown = true, scripts = {} }, methods) end
MultiBot.RegisterScaledFrame = function() end
MultiBot.SafeTexturePath = function(value) return value end
dofile('UI/MultiBotBankFrame.lua')
local bankToken = assert(MultiBot.OpenBotBank('Bot'))
MultiBot.bankFrame:Hide()
assert(not bridge.bankActive)
receive('BANK_BEGIN', 'Bot~' .. bankToken)
receive('BANK_END', 'Bot~' .. bankToken)
assert(not MultiBot.bankFrame:IsShown(), 'A late response must not reopen a closed bank')
bankToken = assert(MultiBot.OpenBotBank('Bot'))
local guildToken = assert(MultiBot.OpenBotGuildBank('Bot'))
assert(not bridge.bankActive)
receive('BANK_END', 'Bot~' .. bankToken)
assert(MultiBot.bankFrame.mode == 'gbank')
receive('GBANK_BEGIN', 'Bot~' .. guildToken)
receive('GBANK_END', 'Bot~' .. guildToken)
assert(MultiBot.bankFrame.mode == 'gbank' and MultiBot.bankFrame:IsShown())
assert(comm.RequestBank('Bot'))
advance(6)
assert(not bridge.bankActive)

-- Confirming an old button must retain the original GUID after the slot is reused.
StaticPopupDialogs = {}
local destroyDialog
StaticPopup_Show = function(_, _, _, data) destroyDialog = data end
GetItemIcon = function() return 'icon' end
GetItemInfo = function() return 'Sword', '|Hitem:123|h[Sword]|h', 4 end
MultiBot.isInside = function() return false end
dofile('UI/MultiBotInventoryItem.lua')
MultiBot.inventory = { name = 'Bot', action = 'destroy' }
local itemFrame = { index = 0, addButton = function() return {} end }
local button = assert(MultiBot.InventoryAddExactItem(itemFrame, {}, {
    itemId = 123, bag = 255, slot = 23, count = 1, guid = 111,
}, 0))
button.doLeft(button)
assert(destroyDialog and destroyDialog.request.srcGuid == 111)
button.item.guid = 222
StaticPopupDialogs.MULTIBOT_CONFIRM_DESTROY.OnAccept(nil, destroyDialog)
assert(sent[#sent][2]:match('^ITEM_DESTROY~') and sent[#sent][2]:match('~111$'))

frames = {}
CreateFrame = function()
    local frame = { scripts = {} }
    function frame:Show() end
    function frame:SetScript(key, callback) self.scripts[key] = callback end
    frames[#frames + 1] = frame
    return frame
end
dofile('Core/MultiBotThrottle.lua')
MultiBot.Throttle_Init()
assert(SendChatMessage == nativeSend)
SendChatMessage('human guild message', 'GUILD')
assert(#chat == 1)
MultiBot.SendChatMessage('bot command', 'WHISPER', nil, 'Bot')
assert(#chat == 1)
frames[1].scripts.OnUpdate(frames[1], 0)
assert(#chat == 2 and chat[2][1] == 'bot command')
print('MultiBot audit: identity negotiation/frames/actions, timeout/error lifecycle, closed bank and chat isolation passed')
