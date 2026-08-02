-- states/shopState.lua
-- Keycap draft: 3-5 item cards, escalating reroll, a live keyboard preview and
-- a real exit -- replaces the old "flat numeric bonus lottery" shop.

local StateManager = require("engine/stateManager")
local ConfigManager = require("engine/configManager")
local Context = require("modules/game/context")
local Theme = require("modules/ui/theme")
local Screen = require("modules/ui/screen")
local KeyboardModel = require("modules/keyboard/keyboardModel")
local KeyboardView = require("modules/keyboard/keyboardView")

local ShopState = {
    name = "ShopState",
    logical = true,
}

-- Layout constants, all in 640x360 logical space.
local HEADER_H = 16
local TAB_H = 14
local CARD_Y = HEADER_H + TAB_H + 4
local CARD_W, CARD_H, CARD_GAP = 96, 110, 8
local KEYBOARD_Y = CARD_Y + CARD_H + 10
local KEYBOARD_SCALE = 0.65
local LAYOUT_ROW_H, LAYOUT_ROW_GAP = 22, 6

local PREFERRED_LAYOUT_ORDER = { "qwerty", "dvorak" }
local DEFAULT_BONUS_RANGE = { min = 0.05, max = 0.30 }

-- Module-local state, all cleared in ShopState.exit() so every visit is fresh.
local returnTo = "menuState"
local shopSection = "upgrades" -- "upgrades" or "layouts"
local offers = {}
local layoutIds = {}
local keyboardView = nil
local previewView, previewIndex = nil, nil
local selectedIndex = 1
local hoveredIndex = nil
local rerollIndex = 0
local pendingLayoutChange = nil
local initError = nil

--------------------------------------------------------------------------
-- Pure helpers (exposed at the bottom for tests/test_shop.lua)
--------------------------------------------------------------------------

-- returnTo travels with StateManager.switch params. Unit 4 is adding that
-- plumbing; this defaults safely whether or not params ever arrives.
local function resolveReturnTo(params)
    return (params and params.returnTo) or "menuState"
end

-- Reroll cost escalates within a visit: 5, 8, 12, 17, 23... and resets to 5
-- every time the shop is entered. n is 1 for the first reroll of a visit.
local function rerollCostForIndex(n)
    return 5 + (n - 1) * (n + 4) / 2
end

-- pcall wrapper for the common "try this, use nil on failure" shape used
-- throughout the preview/offer code below.
local function try(fn)
    local ok, result = pcall(fn)
    if ok then return result end
    return nil
end

local function bonusToRarity(bonus, range)
    range = range or DEFAULT_BONUS_RANGE
    local span = math.max(1e-6, range.max - range.min)
    local t = (bonus - range.min) / span
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local idx = math.floor(t * (#Theme.rarityOrder - 1) + 0.5) + 1
    return Theme.rarityOrder[idx]
end

-- Normalizes either the unit-13 item shape or the legacy
-- {key, displayKey, cost, bonus} shape from KeyboardModel:generateUpgradeOffers
-- into one shape the drawing code always sees.
local function normalizeOffer(raw, bonusRange)
    if raw.effect then
        return raw -- already an item-shape offer
    end

    local key = raw.key or " "
    local displayKey = raw.displayKey or (key == " " and "Space" or string.upper(key))

    return {
        id = "legacy_" .. key,
        name = displayKey .. " Key",
        key = key,
        rarity = bonusToRarity(raw.bonus or 0, bonusRange),
        capVariant = "plain",
        switchType = "linear",
        effect = { kind = "flat", value = raw.bonus or 0 },
        cost = raw.cost or 0,
    }
end

-- Removes only the purchased offer, leaving the rest of the draft untouched --
-- the whole point of a draft instead of a slot machine.
local function removeOfferById(list, id)
    local result = {}
    for _, o in ipairs(list) do
        if o.id ~= id then
            result[#result + 1] = o
        end
    end
    return result
end

local function sortedLayoutIds(layouts)
    local ids, seen = {}, {}
    for _, id in ipairs(PREFERRED_LAYOUT_ORDER) do
        if layouts[id] then
            ids[#ids + 1] = id
            seen[id] = true
        end
    end
    local rest = {}
    for id in pairs(layouts or {}) do
        if not seen[id] then rest[#rest + 1] = id end
    end
    table.sort(rest)
    for _, id in ipairs(rest) do ids[#ids + 1] = id end
    return ids
end

--------------------------------------------------------------------------
-- Economy helpers
--------------------------------------------------------------------------

-- Prefer unit 13's KeyboardModel:installItem when it exists; fall back to the
-- legacy flat key upgrade so the shop stays functional either way.
local function applyItemEffect(keyboard, item)
    if type(keyboard.installItem) == "function" then
        local ok = pcall(function() keyboard:installItem(item) end)
        if ok then return true end
    end

    if item.effect and item.effect.kind == "flat" and item.key then
        keyboard:upgradeKey(item.key, item.effect.value or 0)
        return true
    end

    return false
end

local function generateOffers(keyboard)
    local count = 5

    -- Prefer unit 13's item system when it is present in this worktree.
    if type(keyboard.generateOffers) == "function" then
        local raw = try(function() return keyboard:generateOffers(count) end)
        if type(raw) == "table" and #raw > 0 then
            local normalized = {}
            for _, o in ipairs(raw) do
                normalized[#normalized + 1] = normalizeOffer(o)
            end
            return normalized
        end
    end

    local baseCost = ConfigManager:get("progression.upgradeBaseCost", 20)
    local minBonus = ConfigManager:get("progression.upgradeMinBonus", 0.05)
    local maxBonus = ConfigManager:get("progression.upgradeMaxBonus", 0.3)
    local bonusRange = { min = minBonus, max = maxBonus }

    local raw = keyboard:generateUpgradeOffers(count, baseCost, baseCost * 3.5, minBonus, maxBonus)
    local normalized = {}
    for _, o in ipairs(raw) do
        normalized[#normalized + 1] = normalizeOffer(o, bonusRange)
    end
    return normalized
end

-- KeyboardModel:serialize() hands back its live `upgrades` table by reference,
-- so a naive serialize/deserialize "clone" would let the preview mutate the
-- real player's keyboard. Copy the upgrades table ourselves before previewing.
local function cloneKeyboardForPreview(keyboard)
    local data = try(function() return keyboard:serialize() end)
    if not data then return nil end

    local clone = try(function() return KeyboardModel.deserialize(data) end)
    if not clone then return nil end

    local upgradesCopy = {}
    for k, v in pairs(keyboard.upgrades or {}) do
        upgradesCopy[k] = v
    end
    clone.upgrades = upgradesCopy

    return clone
end

local function buildPreviewView(keyboard, item)
    local clone = cloneKeyboardForPreview(keyboard)
    if not clone then return nil end

    applyItemEffect(clone, item)

    return try(function() return KeyboardView.new(clone) end)
end

local function getPreviewView(player)
    if shopSection ~= "upgrades" then
        previewView, previewIndex = nil, nil
        return nil
    end

    local idx = hoveredIndex or selectedIndex
    local item = offers[idx]
    if not item then
        previewView, previewIndex = nil, nil
        return nil
    end

    if previewIndex ~= idx then
        previewView = buildPreviewView(player.keyboard, item)
        previewIndex = idx
    end

    return previewView
end

local function purchaseOffer(index)
    local item = offers[index]
    if not item then return end

    local player = Context.player()
    if player.totalMoney < (item.cost or 0) then return end
    if not player:spendMoney(item.cost) then return end

    local applied = applyItemEffect(player.keyboard, item)
    if not applied and _G.DEBUG_MODE then
        print("ShopState: purchased '" .. tostring(item.id) .. "' but its effect could not be applied")
    end

    offers = removeOfferById(offers, item.id)
    player:save()

    selectedIndex = math.max(1, math.min(selectedIndex, #offers))
    hoveredIndex, previewIndex = nil, nil
end

local function performReroll()
    local player = Context.player()
    local cost = rerollCostForIndex(rerollIndex + 1)
    if player.totalMoney < cost then return end
    if not player:spendMoney(cost) then return end

    rerollIndex = rerollIndex + 1
    offers = generateOffers(player.keyboard)
    selectedIndex = 1
    hoveredIndex, previewIndex = nil, nil
end

local function requestLayoutChange(layoutId)
    pendingLayoutChange = layoutId
end

local function confirmLayoutChange()
    if not pendingLayoutChange then return end

    local player = Context.player()
    player:changeKeyboard(pendingLayoutChange)
    keyboardView = KeyboardView.new(player.keyboard)
    previewView, previewIndex = nil, nil
    pendingLayoutChange = nil
end

local function cancelLayoutChange()
    pendingLayoutChange = nil
end

local function goBack()
    StateManager.switch(returnTo)
end

-- Shared by both tabs' arrow-key navigation: nudge selectedIndex by delta,
-- clamped to [1, count] (or left at 1 when count is 0).
local function moveSelection(delta, count)
    selectedIndex = math.max(1, math.min(math.max(1, count), (selectedIndex or 1) + delta))
end

--------------------------------------------------------------------------
-- Layout / hit-testing
--------------------------------------------------------------------------

local function pointInRect(x, y, r)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function computeLayout()
    local W = Screen.getWidth()
    local layout = {}

    layout.backButton = { x = W - 70, y = 1, w = 66, h = HEADER_H - 2 }
    layout.tabUpgrades = { x = 8, y = HEADER_H + 2, w = 90, h = TAB_H }
    layout.tabLayouts = { x = 104, y = HEADER_H + 2, w = 90, h = TAB_H }
    layout.rerollButton = { x = W - 90, y = HEADER_H + 2, w = 82, h = TAB_H }

    layout.cards = {}
    if #offers > 0 then
        local totalW = #offers * CARD_W + (#offers - 1) * CARD_GAP
        local startX = (W - totalW) / 2
        for i = 1, #offers do
            layout.cards[i] = {
                x = startX + (i - 1) * (CARD_W + CARD_GAP),
                y = CARD_Y, w = CARD_W, h = CARD_H,
            }
        end
    end

    layout.layoutRows = {}
    local rowY = CARD_Y
    for i = 1, #layoutIds do
        layout.layoutRows[i] = { x = 40, y = rowY, w = W - 80, h = LAYOUT_ROW_H }
        rowY = rowY + LAYOUT_ROW_H + LAYOUT_ROW_GAP
    end

    layout.confirmBox = { x = 190, y = 135, w = 260, h = 90 }
    layout.confirmYes = { x = 210, y = 193, w = 100, h = 22 }
    layout.confirmNo = { x = 330, y = 193, w = 100, h = 22 }

    return layout
end

--------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------

local function formatEffect(item)
    local eff = item.effect or {}
    local kind = eff.kind or "flat"
    local v = eff.value or 0

    if kind == "flat" then
        return string.format("+%.0f%% on key", v * 100)
    elseif kind == "streak" then
        return string.format("+%.0f%% x streak", v * 100)
    elseif kind == "adjacent" then
        return "x2 after adjacent key"
    elseif kind == "echo" then
        return string.format("%.0f%% echoes to vowels", v * 100)
    elseif kind == "coin" then
        return string.format("+%.0f coin/press", v)
    elseif kind == "grace" then
        return "forgives 1st miss"
    elseif kind == "crit" then
        return string.format("%.0f%% crit chance", v * 100)
    elseif kind == "protect" then
        return "streak protected"
    elseif kind == "set" then
        return "set bonus"
    end
    return "special effect"
end

local function drawHeader(player)
    Theme.setColor("panel")
    love.graphics.rectangle("fill", 0, 0, Screen.getWidth(), HEADER_H)

    love.graphics.setFont(Theme.font("body"))
    Theme.setColor("accent")
    love.graphics.print("Money: " .. tostring(player.totalMoney), Theme.spacing.sm, 1)

    Theme.setColor("textMuted")
    love.graphics.setFont(Theme.font("small"))
    love.graphics.printf("[Esc] Back", 0, 3, Screen.getWidth() - Theme.spacing.sm, "right")
end

local function drawTabs(layout)
    love.graphics.setFont(Theme.font("small"))

    Theme.setColor(shopSection == "upgrades" and "text" or "textMuted")
    love.graphics.printf("Upgrades", layout.tabUpgrades.x, layout.tabUpgrades.y, layout.tabUpgrades.w, "left")

    Theme.setColor(shopSection == "layouts" and "text" or "textMuted")
    love.graphics.printf("Layouts", layout.tabLayouts.x, layout.tabLayouts.y, layout.tabLayouts.w, "left")

    if shopSection == "upgrades" then
        local cost = rerollCostForIndex(rerollIndex + 1)
        Theme.setColor("warning")
        love.graphics.printf("Reroll (" .. cost .. "g)", layout.rerollButton.x, layout.rerollButton.y,
            layout.rerollButton.w, "right")
    end
end

local function drawCard(rect, item, isHovered, isSelected, canAfford)
    local rarity = item.rarity or "common"

    Theme.setColor("panel")
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)

    Theme.setColor((isHovered or isSelected) and "borderLight" or "border")
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)

    -- Rarity strip: the cheapest signal a player reads at a glance.
    Theme.setColor("rarity." .. rarity)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, 4)

    -- Placeholder keycap art: a plain cap with the switch color peeking under
    -- it, ready to be swapped for real cap art when it drops in.
    local capSize = 36
    local capX = rect.x + (rect.w - capSize) / 2
    local capY = rect.y + 10

    Theme.setColor("switch." .. (item.switchType or "linear"))
    love.graphics.rectangle("fill", capX + 3, capY + 3, capSize, capSize)
    Theme.setColor("panelLight")
    love.graphics.rectangle("fill", capX, capY, capSize, capSize)
    Theme.setColor("rarity." .. rarity)
    love.graphics.rectangle("line", capX, capY, capSize, capSize)

    love.graphics.setFont(Theme.font("heading"))
    Theme.setColor("text")
    local keyLabel = (item.key == " ") and "SPC" or string.upper(item.key or "?")
    love.graphics.printf(keyLabel, capX, capY + capSize / 2 - 8, capSize, "center")

    love.graphics.setFont(Theme.font("small"))
    Theme.setColor("text")
    love.graphics.printf(item.name or "", rect.x + 2, capY + capSize + 4, rect.w - 4, "center")

    Theme.setColor("textMuted")
    love.graphics.printf(formatEffect(item), rect.x + 2, capY + capSize + 16, rect.w - 4, "center")

    Theme.setColor(canAfford and "accent" or "error")
    love.graphics.printf((item.cost or 0) .. "g", rect.x + 2, rect.y + rect.h - 13, rect.w - 4, "center")
end

local function drawCards(layout, player)
    if #offers == 0 then
        Theme.setColor("textMuted")
        love.graphics.setFont(Theme.font("body"))
        love.graphics.printf("No offers left -- reroll for more.", 0, CARD_Y + CARD_H / 2, Screen.getWidth(), "center")
        return
    end

    for i, item in ipairs(offers) do
        drawCard(layout.cards[i], item, hoveredIndex == i, selectedIndex == i, player.totalMoney >= (item.cost or 0))
    end
end

local function drawLayouts(layout, player)
    local layouts = ConfigManager:getKeyboardLayouts()

    for i, id in ipairs(layoutIds) do
        local rect = layout.layoutRows[i]
        local data = layouts[id] or {}
        local isCurrent = (player.selectedKeyboardLayout == id)

        Theme.setColor(isCurrent and "panelLight" or "panel")
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
        Theme.setColor("border")
        love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)

        love.graphics.setFont(Theme.font("body"))
        Theme.setColor("text")
        love.graphics.printf(data.name or id, rect.x + Theme.spacing.sm, rect.y + 4, rect.w - 80, "left")

        love.graphics.setFont(Theme.font("small"))
        if isCurrent then
            Theme.setColor("success")
            love.graphics.printf("CURRENT", rect.x, rect.y + 5, rect.w - Theme.spacing.sm, "right")
        else
            -- Scope guard: non-default layouts are an unlock, not a paid item.
            Theme.setColor("accent")
            love.graphics.printf("UNLOCK", rect.x, rect.y + 5, rect.w - Theme.spacing.sm, "right")
        end
    end
end

local function drawKeyboardPreview(player)
    local view = getPreviewView(player) or keyboardView
    if not view then return end

    local dims = try(function() return view:calculateDimensions(0, KEYBOARD_Y, KEYBOARD_SCALE) end)
    if not dims then return end

    local x = (Screen.getWidth() - dims.width) / 2
    try(function() view:draw(x, KEYBOARD_Y, KEYBOARD_SCALE) end)
end

local function drawConfirmOverlay(layout)
    local layouts = ConfigManager:getKeyboardLayouts()
    local data = layouts[pendingLayoutChange] or {}
    local name = data.name or pendingLayoutChange

    Theme.setColor("baseAlt", 0.85)
    love.graphics.rectangle("fill", 0, 0, Screen.getWidth(), Screen.getHeight())

    local box = layout.confirmBox
    Theme.setColor("panel")
    love.graphics.rectangle("fill", box.x, box.y, box.w, box.h)
    Theme.setColor("borderLight")
    love.graphics.rectangle("line", box.x, box.y, box.w, box.h)

    love.graphics.setFont(Theme.font("body"))
    Theme.setColor("text")
    love.graphics.printf("Switch to " .. tostring(name) .. "?", box.x + 8, box.y + 8, box.w - 16, "center")

    love.graphics.setFont(Theme.font("small"))
    Theme.setColor("textMuted")
    love.graphics.printf("This may reset your key upgrades.", box.x + 8, box.y + 28, box.w - 16, "center")

    local yes, no = layout.confirmYes, layout.confirmNo
    Theme.setColor("success")
    love.graphics.rectangle("line", yes.x, yes.y, yes.w, yes.h)
    love.graphics.printf("[Y] Yes", yes.x, yes.y + 5, yes.w, "center")

    Theme.setColor("error")
    love.graphics.rectangle("line", no.x, no.y, no.w, no.h)
    love.graphics.printf("[N] No", no.x, no.y + 5, no.w, "center")
end

--------------------------------------------------------------------------
-- State callbacks
--------------------------------------------------------------------------

-- Shared reset for enter/exit -- every field a shop visit can dirty, so a new
-- visit (or a game that never re-enters after a bad exit) always starts fresh.
local function resetState()
    shopSection = "upgrades"
    rerollIndex = 0
    pendingLayoutChange = nil
    selectedIndex = 1
    hoveredIndex = nil
    previewView, previewIndex = nil, nil
    initError = nil
end

function ShopState.enter(params)
    returnTo = resolveReturnTo(params)
    resetState()

    local ok, err = pcall(function()
        local player = Context.player()
        keyboardView = KeyboardView.new(player.keyboard)
        offers = generateOffers(player.keyboard)
        layoutIds = sortedLayoutIds(ConfigManager:getKeyboardLayouts())
    end)

    if not ok then
        print("ShopState: enter failed: " .. tostring(err))
        initError = err
        offers = offers or {}
        layoutIds = layoutIds or {}
    end
end

function ShopState.exit()
    resetState()
    offers = {}
    layoutIds = {}
    keyboardView = nil
end

function ShopState.update(dt)
    -- Guarded: if enter() threw, keyboardView may be nil and this must not
    -- crash every frame forever.
    if keyboardView then keyboardView:update(dt) end
    if previewView then previewView:update(dt) end
end

function ShopState.draw()
    if initError then
        love.graphics.setFont(Theme.font("body"))
        Theme.setColor("error")
        love.graphics.printf("Shop failed to load: " .. tostring(initError), 8, 8, Screen.getWidth() - 16, "left")
        Theme.setColor("textMuted")
        love.graphics.printf("[Esc] Back", 8, Screen.getHeight() - 16, Screen.getWidth() - 16, "left")
        return
    end

    local layout = computeLayout()
    local player = Context.player()

    drawHeader(player)
    drawTabs(layout)

    if shopSection == "upgrades" then
        drawCards(layout, player)
    else
        drawLayouts(layout, player)
    end

    drawKeyboardPreview(player)

    if pendingLayoutChange then
        drawConfirmOverlay(layout)
    end
end

function ShopState.keypressed(key)
    if pendingLayoutChange then
        if key == "y" or key == "return" or key == "kpenter" then
            confirmLayoutChange()
        elseif key == "n" or key == "escape" then
            cancelLayoutChange()
        end
        return
    end

    if key == "escape" then
        goBack()
        return
    end

    if key == "tab" then
        shopSection = (shopSection == "upgrades") and "layouts" or "upgrades"
        return
    end

    if shopSection == "upgrades" then
        if key == "left" then
            moveSelection(-1, #offers)
        elseif key == "right" then
            moveSelection(1, #offers)
        elseif key == "return" or key == "kpenter" or key == "space" then
            purchaseOffer(selectedIndex)
        elseif key == "r" then
            performReroll()
        end
    else
        if key == "up" then
            moveSelection(-1, #layoutIds)
        elseif key == "down" then
            moveSelection(1, #layoutIds)
        elseif key == "return" or key == "kpenter" or key == "space" then
            local id = layoutIds[selectedIndex]
            if id and id ~= Context.player().selectedKeyboardLayout then
                requestLayoutChange(id)
            end
        end
    end
end

function ShopState.mousepressed(x, y, button)
    if button ~= 1 or initError then return end

    local layout = computeLayout()

    if pendingLayoutChange then
        if pointInRect(x, y, layout.confirmYes) then confirmLayoutChange() return end
        if pointInRect(x, y, layout.confirmNo) then cancelLayoutChange() return end
        return
    end

    if pointInRect(x, y, layout.backButton) then goBack() return end
    if pointInRect(x, y, layout.tabUpgrades) then shopSection = "upgrades" return end
    if pointInRect(x, y, layout.tabLayouts) then shopSection = "layouts" return end

    if shopSection == "upgrades" then
        if pointInRect(x, y, layout.rerollButton) then
            performReroll()
            return
        end
        for i, rect in ipairs(layout.cards) do
            if pointInRect(x, y, rect) then
                selectedIndex = i
                purchaseOffer(i)
                return
            end
        end
    else
        for i, rect in ipairs(layout.layoutRows) do
            local id = layoutIds[i]
            if id and pointInRect(x, y, rect) then
                selectedIndex = i
                if id ~= Context.player().selectedKeyboardLayout then
                    requestLayoutChange(id)
                end
                return
            end
        end
    end
end

function ShopState.mousemoved(x, y)
    if initError or shopSection ~= "upgrades" or pendingLayoutChange then
        hoveredIndex = nil
        return
    end

    local layout = computeLayout()
    local found = nil
    for i, rect in ipairs(layout.cards) do
        if pointInRect(x, y, rect) then
            found = i
            break
        end
    end
    hoveredIndex = found
end

--------------------------------------------------------------------------
-- Exposed for tests/test_shop.lua -- pure logic only, no love.* calls.
--------------------------------------------------------------------------

ShopState.rerollCostForIndex = rerollCostForIndex
ShopState.normalizeOffer = normalizeOffer
ShopState.removeOfferById = removeOfferById
ShopState.resolveReturnTo = resolveReturnTo

return ShopState
