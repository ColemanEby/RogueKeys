-- tests/test_shop.lua
-- Pure-logic coverage for the shop redesign: reroll cost escalation, the
-- offer normalizer (both item shapes), purchase-only-removes-one-offer, and
-- the returnTo default that fixes the "shop force-starts a round" trap.

local H = require("tests/helpers")
local ShopState = require("states/shopState")
local PlayerModel = require("modules/player/playerModel")
local Context = require("modules/game/context")

local T = {}

local function enterShopWithMoney(amount)
    local player = PlayerModel.new()
    player.totalMoney = amount
    Context.setPlayer(player)
    ShopState.enter({})
    return player
end

function T.reroll_cost_escalates_5_8_12()
    H.equal(ShopState.rerollCostForIndex(1), 5)
    H.equal(ShopState.rerollCostForIndex(2), 8)
    H.equal(ShopState.rerollCostForIndex(3), 12)
    H.equal(ShopState.rerollCostForIndex(4), 17)
end

function T.reroll_cost_is_monotonically_increasing()
    local prev = 0
    for n = 1, 10 do
        local cost = ShopState.rerollCostForIndex(n)
        H.isTrue(cost > prev, "reroll cost must strictly increase at n=" .. n)
        prev = cost
    end
end

function T.normalize_passes_through_item_shape_unchanged()
    local item = {
        id = "oiled_e",
        name = "Oiled E",
        key = "e",
        rarity = "common",
        capVariant = "plain",
        switchType = "linear",
        effect = { kind = "flat", value = 0.15 },
        cost = 35,
    }

    local result = ShopState.normalizeOffer(item)
    H.isTrue(result == item, "item-shape offers must pass through unchanged")
end

function T.normalize_converts_legacy_shape()
    local legacy = { key = "e", displayKey = "E", cost = 40, bonus = 0.2 }
    local result = ShopState.normalizeOffer(legacy, { min = 0.05, max = 0.30 })

    H.equal(result.id, "legacy_e")
    H.equal(result.key, "e")
    H.equal(result.name, "E Key")
    H.equal(result.cost, 40)
    H.equal(result.effect.kind, "flat")
    H.near(result.effect.value, 0.2)
    H.equal(result.capVariant, "plain")
    H.equal(result.switchType, "linear")
end

function T.normalize_legacy_rarity_spans_the_full_range()
    local range = { min = 0.05, max = 0.30 }

    local common = ShopState.normalizeOffer({ key = "a", cost = 20, bonus = 0.05 }, range)
    H.equal(common.rarity, "common")

    local legendary = ShopState.normalizeOffer({ key = "z", cost = 20, bonus = 0.30 }, range)
    H.equal(legendary.rarity, "legendary")

    local mid = ShopState.normalizeOffer({ key = "m", cost = 20, bonus = 0.20 }, range)
    H.equal(mid.rarity, "rare")
end

function T.normalize_legacy_handles_space_key()
    local legacy = { key = " ", cost = 20, bonus = 0.1 }
    local result = ShopState.normalizeOffer(legacy, { min = 0.05, max = 0.30 })

    H.equal(result.key, " ")
    H.equal(result.name, "Space Key")
end

function T.purchase_removes_only_the_bought_offer()
    local offers = {
        { id = "a", cost = 10 },
        { id = "b", cost = 20 },
        { id = "c", cost = 30 },
    }

    local remaining = ShopState.removeOfferById(offers, "b")

    H.equal(#remaining, 2)
    H.equal(remaining[1].id, "a")
    H.equal(remaining[2].id, "c")

    -- The original list must be untouched -- no reroll-everything side effect.
    H.equal(#offers, 3)
end

function T.purchase_of_missing_id_is_a_noop()
    local offers = { { id = "a" }, { id = "b" } }
    local remaining = ShopState.removeOfferById(offers, "does_not_exist")
    H.equal(#remaining, 2)
end

function T.return_to_defaults_to_menu_state()
    H.equal(ShopState.resolveReturnTo(nil), "menuState")
    H.equal(ShopState.resolveReturnTo({}), "menuState")
end

function T.return_to_honors_explicit_param()
    H.equal(ShopState.resolveReturnTo({ returnTo = "statsState" }), "statsState")
end

function T.locked_offer_survives_reroll_at_same_index()
    local current = {
        { id = "a" },
        { id = "b", locked = true },
        { id = "c" },
    }
    local fresh = {
        { id = "x" },
        { id = "y" },
        { id = "z" },
    }

    local merged = ShopState.mergeRerollOffers(current, fresh)

    H.equal(#merged, 3)
    H.equal(merged[1].id, "x")
    H.equal(merged[2].id, "b")
    H.equal(merged[3].id, "z")
    H.isTrue(merged[2].locked)
end

function T.unlocked_offers_are_replaced_by_fresh_ones()
    local current = {
        { id = "a", locked = true },
        { id = "b" },
        { id = "c" },
    }
    local fresh = {
        { id = "x" },
        { id = "y" },
        { id = "z" },
    }

    local merged = ShopState.mergeRerollOffers(current, fresh)

    H.equal(merged[1].id, "a")
    H.equal(merged[2].id, "y")
    H.equal(merged[3].id, "z")
end

function T.locking_all_offers_still_uses_normal_escalating_reroll_cost()
    local current = {
        { id = "a", locked = true },
        { id = "b", locked = true },
    }
    local fresh = {
        { id = "x" },
        { id = "y" },
    }

    local merged = ShopState.mergeRerollOffers(current, fresh)

    -- Lock count does not affect cost escalation: the cost is still indexed
    -- purely by reroll count within the visit.
    H.equal(ShopState.rerollCostForIndex(1), 5)
    H.equal(ShopState.rerollCostForIndex(2), 8)
    H.equal(ShopState.rerollCostForIndex(3), 12)
    H.equal(#merged, 2)
    H.equal(merged[1].id, "a")
    H.equal(merged[2].id, "b")
end

function T.clearOfferLocks_removes_all_locks()
    local offers = {
        { id = "a", locked = true },
        { id = "b" },
        { id = "c", locked = true },
    }

    ShopState.clearOfferLocks(offers)

    H.isFalse(offers[1].locked)
    H.isFalse(offers[2].locked)
    H.isFalse(offers[3].locked)
end

function T.toggleOfferLock_toggles_lock_state()
    local offers = { { id = "a" }, { id = "b" } }

    ShopState.toggleOfferLock(offers, 1)
    H.isTrue(offers[1].locked)

    ShopState.toggleOfferLock(offers, 1)
    H.isFalse(offers[1].locked)

    -- Out-of-range toggle is a no-op.
    ShopState.toggleOfferLock(offers, 99)
    H.equal(#offers, 2)
end

function T.locked_offer_survives_real_reroll_at_same_index()
    love.math.setRandomSeed(12345)
    local player = enterShopWithMoney(1000)

    local before = ShopState.getOffers()
    H.isTrue(#before >= 3, "expected at least 3 offers")
    local beforeIds = {}
    for i, o in ipairs(before) do beforeIds[i] = o.id end

    -- Select and lock the third offer.
    ShopState.keypressed("right")
    ShopState.keypressed("right")
    ShopState.keypressed("l")
    H.isTrue(ShopState.getOffers()[3].locked, "offer 3 should be locked before reroll")

    -- Reroll through the live call site.
    ShopState.keypressed("r")

    local after = ShopState.getOffers()
    H.equal(#after, #before, "offer count must stay the same")
    H.equal(after[3].id, beforeIds[3], "locked offer must survive at its exact index")
    H.isTrue(after[3].locked, "locked offer must remain locked after reroll")

    local changed = 0
    for i = 1, #after do
        if i ~= 3 and after[i].id ~= beforeIds[i] then
            changed = changed + 1
        end
    end
    H.isTrue(changed >= 1, "at least one unlocked slot must be replaced by the reroll")
end

function T.fully_locked_board_uses_normal_escalating_reroll_cost()
    love.math.setRandomSeed(54321)
    local player = enterShopWithMoney(1000)
    local offers = ShopState.getOffers()
    local n = #offers
    H.isTrue(n >= 2, "expected at least 2 offers")

    -- Lock every offer through the real UI path.
    for _ = 1, n do
        ShopState.keypressed("l")
        ShopState.keypressed("right")
    end
    for i = 1, n do
        H.isTrue(ShopState.getOffers()[i].locked, "offer " .. i .. " should be locked")
    end

    local beforeMoney = player.totalMoney
    H.equal(ShopState.getRerollIndex(), 0)

    -- First reroll: must charge exactly the first escalated step.
    ShopState.keypressed("r")
    H.equal(player.totalMoney, beforeMoney - ShopState.rerollCostForIndex(1))
    H.equal(ShopState.getRerollIndex(), 1)

    -- Second reroll: must charge the next escalated step (no lock surcharge).
    ShopState.keypressed("r")
    H.equal(
        player.totalMoney,
        beforeMoney - ShopState.rerollCostForIndex(1) - ShopState.rerollCostForIndex(2)
    )
    H.equal(ShopState.getRerollIndex(), 2)

    -- The board should be unchanged because every slot was locked.
    local after = ShopState.getOffers()
    for i = 1, n do
        H.isTrue(after[i].locked, "all offers must still be locked after rerolling a full board")
    end
end

function T.locks_are_cleared_by_real_shop_exit()
    love.math.setRandomSeed(99999)
    enterShopWithMoney(1000)

    local offers = ShopState.getOffers()
    H.isTrue(#offers >= 1, "expected at least 1 offer")

    -- Lock the first offer through the live call site.
    ShopState.keypressed("l")
    H.isTrue(offers[1].locked, "offer should be locked before exit")

    -- Capture the exact table that the state machine will discard.
    local captured = offers
    ShopState.exit()

    -- resetState must clear locks on the live table before it is discarded.
    H.isFalse(captured[1].locked, "resetState must clear locks on the outgoing offers table")

    -- A fresh visit must start with no locks.
    ShopState.enter({})
    local fresh = ShopState.getOffers()
    for i = 1, #fresh do
        H.isFalse(fresh[i].locked, "fresh visit must produce unlocked offers")
    end
end

function T.teardown()
    ShopState.exit()
end

return T
