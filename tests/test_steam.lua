-- tests/test_steam.lua
-- The dev/CI environment has no Steamworks SDK and no steam_appid.txt, so
-- luasteam never loads here. This suite locks down the property that matters
-- most: every call is a safe no-op in that state, so game code never has to
-- guard calls behind Steam.isAvailable().

local H = require("tests/helpers")
local Steam = require("modules/steam/steam")
local TypingTrainer = require("modules/typing/trainer")
local PlayerModel = require("modules/player/playerModel")
local Run = require("modules/game/run")
local Context = require("modules/game/context")
local StateManager = require("engine/stateManager")
local TextGenerator = require("modules/typing/textGenerator")
local RoundState = require("states/roundState")
local ShopState = require("states/shopState")

local T = {}

local function completeOneCharacterRound(player)
    local originalGetRandomText = TextGenerator.getRandomText
    local originalSwitch = StateManager.switch

    TextGenerator.getRandomText = function() return "a" end
    StateManager.switch = function() end
    Context.setPlayer(player)

    local ok, err = pcall(function()
        RoundState.enter()
        RoundState.textinput("a")
    end)

    RoundState.exit()
    TextGenerator.getRandomText = originalGetRandomText
    StateManager.switch = originalSwitch

    if not ok then error(err, 2) end
end

local function enterShop(player)
    player.save = function() return true end
    Context.setPlayer(player)
    ShopState.enter({})
    H.isTrue(#ShopState.getOffers() > 0, "expected the live shop to generate offers")
end

local function purchaseShopItem(player, item)
    player.totalMoney = item.cost
    enterShop(player)
    ShopState.getOffers()[1] = item
    ShopState.keypressed("return")
end

local function itemWithRarity(id, key, rarity, effectKind)
    return {
        id = id,
        name = id,
        key = key,
        rarity = rarity,
        effect = { kind = effectKind or "flat", value = 1 },
        cost = 1,
    }
end

function T.init_reports_unavailable_when_luasteam_is_absent()
    -- Headless tests run with no window and no Steamworks SDK -- init must
    -- report false, not raise.
    local ok = Steam.init()
    H.isFalse(ok, "Steam.init() must return false with no luasteam module present")
    H.isFalse(Steam.isAvailable())
end

function T.all_calls_are_safe_noops_when_unavailable()
    H.succeeds(function() Steam.unlockAchievement("FIRST_RUN") end)
    H.succeeds(function() Steam.setStat("rounds_played", 1) end)
    H.succeeds(function() Steam.store() end)
    H.succeeds(function() Steam.update() end)
    H.succeeds(function() Steam.shutdown() end)
end

function T.unlock_achievement_ignores_nil_id()
    H.succeeds(function() Steam.unlockAchievement(nil) end)
end

function T.set_stat_ignores_nil_name()
    H.succeeds(function() Steam.setStat(nil, 5) end)
end

function T.repeated_unlocks_of_the_same_achievement_are_cheap_and_safe()
    for _ = 1, 5 do
        H.succeeds(function() Steam.unlockAchievement("PERFECT_ROUND") end)
    end
end

-- Stat-threshold achievement triggers --------------------------------------

function T.first_correct_keystroke_unlocks_first_keystroke()
    Steam.shutdown()
    local trainer = TypingTrainer.new({ text = "ab" })
    trainer:handleInput("a")
    H.isTrue(Steam.isAchievementSent("FIRST_KEYSTROKE"))
end

function T.streak_of_50_unlocks_in_the_zone()
    Steam.shutdown()
    local trainer = TypingTrainer.new({ text = string.rep("a", 50) })
    for i = 1, 50 do
        trainer:handleInput("a")
    end
    H.isTrue(Steam.isAchievementSent("STREAK_50"))
    H.isFalse(Steam.isAchievementSent("STREAK_200"))
end

function T.streak_of_200_unlocks_unbroken()
    Steam.shutdown()
    local trainer = TypingTrainer.new({ text = string.rep("a", 200) })
    for i = 1, 200 do
        trainer:handleInput("a")
    end
    H.isTrue(Steam.isAchievementSent("STREAK_200"))
end

function T.perfect_round_unlocks_flawless()
    Steam.shutdown()
    local player = PlayerModel.new()
    player:startSession()
    player:endSession({ keystrokes = 10, mistakes = 0, correct = 10, accuracy = 100, wpm = 0 })
    H.isTrue(Steam.isAchievementSent("PERFECT_ROUND"))
    H.isFalse(Steam.isAchievementSent("FIVE_PERFECT_ROUNDS"))
end

function T.five_perfect_rounds_unlocks_precision_machine()
    Steam.shutdown()
    local player = PlayerModel.new()
    for i = 1, 5 do
        player:startSession()
        player:endSession({ keystrokes = 10, mistakes = 0, correct = 10, accuracy = 100, wpm = 0 })
    end
    H.isTrue(Steam.isAchievementSent("PERFECT_ROUND"))
    H.isTrue(Steam.isAchievementSent("FIVE_PERFECT_ROUNDS"))
end

function T.wpm_60_unlocks_speed_typer()
    Steam.shutdown()
    local player = PlayerModel.new()
    player:startSession()
    player:endSession({ keystrokes = 60, mistakes = 0, correct = 60, accuracy = 100, wpm = 60 })
    H.isTrue(Steam.isAchievementSent("WPM_60"))
    H.isFalse(Steam.isAchievementSent("WPM_100"))
end

function T.wpm_100_unlocks_triple_digit()
    Steam.shutdown()
    local player = PlayerModel.new()
    player:startSession()
    player:endSession({ keystrokes = 100, mistakes = 0, correct = 100, accuracy = 100, wpm = 100 })
    H.isTrue(Steam.isAchievementSent("WPM_60"))
    H.isTrue(Steam.isAchievementSent("WPM_100"))
    H.isFalse(Steam.isAchievementSent("WPM_150"))
end

function T.wpm_150_unlocks_inhuman()
    Steam.shutdown()
    local player = PlayerModel.new()
    player:startSession()
    player:endSession({ keystrokes = 150, mistakes = 0, correct = 150, accuracy = 100, wpm = 150 })
    H.isTrue(Steam.isAchievementSent("WPM_60"))
    H.isTrue(Steam.isAchievementSent("WPM_100"))
    H.isTrue(Steam.isAchievementSent("WPM_150"))
end

function T.perfect_accuracy_over_100_keystrokes_unlocks_accuracy_surgeon()
    Steam.shutdown()
    local player = PlayerModel.new()
    player:startSession()
    player:endSession({ keystrokes = 100, mistakes = 0, correct = 100, accuracy = 100, wpm = 0 })
    H.isTrue(Steam.isAchievementSent("ACCURACY_SURGEON"))
end

-- Run/economy lifecycle achievement triggers -----------------------------

function T.first_round_complete_unlocks_only_on_the_first_round_completion()
    Steam.shutdown()
    local player = PlayerModel.new()

    completeOneCharacterRound(player)
    H.isTrue(Steam.isAchievementSent("FIRST_ROUND_COMPLETE"))

    Steam.shutdown()
    completeOneCharacterRound(player)
    H.isFalse(Steam.isAchievementSent("FIRST_ROUND_COMPLETE"),
        "a later round completion must not re-trigger the first-round achievement")
end

function T.first_run_complete_unlocks_only_when_the_run_reaches_a_terminal_state()
    Steam.shutdown()
    local run = Run.new({ rounds = 2, seed = 1 })

    run:submitScore(run:getRequiredScore(1))
    H.isFalse(Steam.isAchievementSent("FIRST_RUN_COMPLETE"),
        "advancing to another round must not count as completing the run")

    run:submitScore(run:getRequiredScore(2) - 1)
    H.isTrue(Steam.isAchievementSent("FIRST_RUN_COMPLETE"),
        "a gate failure that ends the run must count as run completion")
end

function T.victory_run_unlocks_on_victory_but_not_on_failure()
    Steam.shutdown()
    local failedRun = Run.new({ rounds = 1, seed = 1 })
    failedRun:submitScore(failedRun:getRequiredScore(1) - 1)

    H.isTrue(Steam.isAchievementSent("FIRST_RUN_COMPLETE"))
    H.isFalse(Steam.isAchievementSent("VICTORY_RUN"),
        "a failed run must never unlock the victory achievement")

    Steam.shutdown()
    local victoriousRun = Run.new({ rounds = 1, seed = 1 })
    victoriousRun:submitScore(victoriousRun:getRequiredScore(1))

    H.isTrue(Steam.isAchievementSent("FIRST_RUN_COMPLETE"))
    H.isTrue(Steam.isAchievementSent("VICTORY_RUN"))
end

function T.first_purchase_unlocks_only_for_the_first_successful_purchase()
    Steam.shutdown()
    local player = PlayerModel.new()
    player.totalMoney = 0
    enterShop(player)

    local offerCount = #ShopState.getOffers()
    local cost = ShopState.getOffers()[1].cost
    H.isTrue(cost > 0, "expected the first live shop offer to have a positive cost")

    ShopState.keypressed("return")
    H.isFalse(Steam.isAchievementSent("FIRST_PURCHASE"),
        "an insufficient-funds attempt must not unlock the purchase achievement")
    H.equal(#ShopState.getOffers(), offerCount,
        "an insufficient-funds attempt must leave the offer in the shop")

    player.totalMoney = cost
    ShopState.keypressed("return")
    H.isTrue(Steam.isAchievementSent("FIRST_PURCHASE"))
    H.equal(player.stats.moneySpent, cost)

    ShopState.exit()
    Steam.shutdown()
    player.totalMoney = 1000
    enterShop(player)
    ShopState.keypressed("return")
    H.isFalse(Steam.isAchievementSent("FIRST_PURCHASE"),
        "a later successful purchase must not re-trigger the first-purchase achievement")
end

-- Item/rarity achievement triggers ---------------------------------------

function T.installing_a_common_item_unlocks_no_rarity_achievements()
    Steam.shutdown()
    local player = PlayerModel.new()

    purchaseShopItem(player, itemWithRarity("common_test", "a", "common"))

    H.isFalse(Steam.isAchievementSent("FIRST_RARE_ITEM"))
    H.isFalse(Steam.isAchievementSent("FIRST_LEGENDARY"))
    H.isFalse(Steam.isAchievementSent("FULL_LEGENDARY_BOARD"))
end

function T.installing_a_rare_item_unlocks_first_rare_item_only()
    Steam.shutdown()
    local player = PlayerModel.new()

    purchaseShopItem(player, itemWithRarity("rare_test", "a", "rare"))

    H.isTrue(Steam.isAchievementSent("FIRST_RARE_ITEM"))
    H.isFalse(Steam.isAchievementSent("FIRST_LEGENDARY"))
end

function T.installing_an_epic_item_unlocks_first_rare_item_only()
    Steam.shutdown()
    local player = PlayerModel.new()

    purchaseShopItem(player, itemWithRarity("epic_test", "a", "epic"))

    H.isTrue(Steam.isAchievementSent("FIRST_RARE_ITEM"))
    H.isFalse(Steam.isAchievementSent("FIRST_LEGENDARY"))
end

function T.installing_a_legendary_item_unlocks_both_rarity_milestones()
    Steam.shutdown()
    local player = PlayerModel.new()

    purchaseShopItem(player, itemWithRarity("legendary_test", "a", "legendary"))

    H.isTrue(Steam.isAchievementSent("FIRST_RARE_ITEM"))
    H.isTrue(Steam.isAchievementSent("FIRST_LEGENDARY"))
end

function T.full_legendary_board_requires_every_installed_item_to_be_legendary()
    Steam.shutdown()
    local mixedPlayer = PlayerModel.new()
    H.isFalse(mixedPlayer.keyboard:isFullyLegendary(),
        "an empty board must not qualify as a full legendary board")

    purchaseShopItem(mixedPlayer, itemWithRarity("common_test", "a", "common"))
    ShopState.exit()

    purchaseShopItem(mixedPlayer, itemWithRarity("legendary_test", "b", "legendary"))

    H.isFalse(Steam.isAchievementSent("FULL_LEGENDARY_BOARD"),
        "one non-legendary installed item must keep a mixed board from qualifying")

    ShopState.exit()
    Steam.shutdown()
    local legendaryPlayer = PlayerModel.new()

    purchaseShopItem(legendaryPlayer, itemWithRarity("legendary_only", "a", "legendary"))

    H.isTrue(Steam.isAchievementSent("FULL_LEGENDARY_BOARD"),
        "a non-empty board of only legendary items must qualify")
end

function T.successful_item_purchase_flushes_the_achievement_batch_once()
    Steam.shutdown()
    local player = PlayerModel.new()
    local originalStore = Steam.store
    local storeCalls = 0
    Steam.store = function() storeCalls = storeCalls + 1 end

    local ok, err = pcall(function()
        purchaseShopItem(player, itemWithRarity("legendary_test", "a", "legendary"))
    end)
    Steam.store = originalStore

    if not ok then error(err, 2) end
    H.equal(storeCalls, 1, "a successful purchase must flush its achievement batch exactly once")
end

function T.money_1000_unlocks_only_when_lifetime_earnings_cross_the_threshold()
    Steam.shutdown()
    local player = PlayerModel.new()

    player:startSession()
    player:endSession({ moneyEarned = 999 })
    H.isFalse(Steam.isAchievementSent("MONEY_1000"),
        "999 lifetime coins must remain below the achievement threshold")

    player:startSession()
    player:endSession({ moneyEarned = 1 })
    H.isTrue(Steam.isAchievementSent("MONEY_1000"))

    Steam.shutdown()
    player:startSession()
    player:endSession({ moneyEarned = 1 })
    H.isFalse(Steam.isAchievementSent("MONEY_1000"),
        "earnings after the threshold was already reached must not re-trigger the achievement")
end

function T.teardown()
    RoundState.exit()
    ShopState.exit()
    Context.reset()
end

return T
