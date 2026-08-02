-- tests/test_shop.lua
-- Pure-logic coverage for the shop redesign: reroll cost escalation, the
-- offer normalizer (both item shapes), purchase-only-removes-one-offer, and
-- the returnTo default that fixes the "shop force-starts a round" trap.

local H = require("tests/helpers")
local ShopState = require("states/shopState")

local T = {}

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

return T
