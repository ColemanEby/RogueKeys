-- tests/test_items.lua
-- The keycap item system: rarity rolls, the nine effect kinds, and
-- keyboardModel's item plumbing (install/score/serialize, legacy-save
-- compatibility, and layout-derived adjacency).

local H = require("tests/helpers")

local Rarity = require("modules/items/rarity")
local Effects = require("modules/items/effects")
local ItemDefs = require("modules/items/itemDefs")
local KeyboardModel = require("modules/keyboard/keyboardModel")

local T = {}

-- ---------------------------------------------------------------------------
-- Effects: one function per effect.kind, pure given (item, ctx, state).
-- ---------------------------------------------------------------------------

function T.effects_flat_is_constant()
    local item = { effect = { kind = "flat", value = 0.2 } }
    local points, procs = Effects.flat(item, {}, {})
    H.near(points, 0.2)
    H.equal(H.count(procs), 0)
end

function T.effects_streak_scales_and_zero_at_zero_streak()
    local item = { effect = { kind = "streak", value = 0.05 } }

    local points = Effects.streak(item, { streak = 0 }, {})
    H.near(points, 0, 1e-9, "streak 0 must score nothing")

    points = Effects.streak(item, { streak = 10 }, {})
    H.near(points, 0.5)
end

function T.effects_adjacent_doubles_only_when_flagged()
    local item = { effect = { kind = "adjacent", value = 0.1 } }

    local points, procs = Effects.adjacent(item, { adjacentToPrev = false }, {})
    H.near(points, 0.1)
    H.isFalse(procs.adjacent)

    points, procs = Effects.adjacent(item, { adjacentToPrev = true }, {})
    H.near(points, 0.2)
    H.isTrue(procs.adjacent)

    -- No previous character (start of text): ctx simply omits the flag.
    points, procs = Effects.adjacent(item, {}, {})
    H.near(points, 0.1)
    H.isFalse(procs.adjacent)
end

function T.effects_echo_distributes_to_vowels_only()
    local item = { effect = { kind = "echo", value = 0.3 } }
    local state = {}

    -- Consonant keystroke: banks the value, scores nothing itself.
    local points, procs = Effects.echo(item, { isVowel = false }, state)
    H.near(points, 0)
    H.isFalse(procs.echo)
    H.near(state.echoBank, 0.3)

    -- Another consonant keystroke: bank grows, still nothing paid out.
    points, procs = Effects.echo(item, { isVowel = false }, state)
    H.near(points, 0)
    H.isFalse(procs.echo)
    H.near(state.echoBank, 0.6)

    -- A vowel keystroke drains the whole bank in one shot.
    points, procs = Effects.echo(item, { isVowel = true }, state)
    H.near(points, 0.6)
    H.isTrue(procs.echo)
    H.near(state.echoBank, 0.3, 1e-9, "this press's own contribution should still be banked")

    -- Bank is empty right after a payout that only banked its own value: a
    -- second consecutive vowel keeps whatever this call itself contributed.
    state.echoBank = 0
    points, procs = Effects.echo(item, { isVowel = true }, state)
    H.near(points, 0, 1e-9, "nothing to pay out from an empty bank")
    H.isFalse(procs.echo)
end

function T.effects_coin_grants_coins_not_points()
    local item = { effect = { kind = "coin", value = 2 } }
    local points, procs = Effects.coin(item, { streak = 5, isVowel = true }, {})
    H.near(points, 0)
    H.near(procs.coins, 2)
end

function T.effects_grace_consumed_once_per_round_then_stops()
    local item = { id = "guard", effect = { kind = "grace", value = 1 } }
    local state = {}

    -- Not an error: never consumes or forgives, regardless of round.
    local _, procs = Effects.grace(item, { isError = false, round = 1 }, state)
    H.isFalse(procs.forgiven)

    -- First error this round: forgiven, and consumes the charge.
    _, procs = Effects.grace(item, { isError = true, round = 1 }, state)
    H.isTrue(procs.forgiven)

    -- Second error, same round: charge already spent.
    _, procs = Effects.grace(item, { isError = true, round = 1 }, state)
    H.isFalse(procs.forgiven, "grace must not forgive twice in the same round")

    -- New round: a fresh charge is available again.
    _, procs = Effects.grace(item, { isError = true, round = 2 }, state)
    H.isTrue(procs.forgiven, "a new round should refresh grace")
end

function T.effects_crit_respects_injected_roll()
    local item = { effect = { kind = "crit", value = 0.25 } }

    -- Roll just under the threshold: crits.
    local points, procs = Effects.crit(item, { forceRoll = 0.1 }, {})
    H.isTrue(procs.crit)
    H.near(points, Effects.BASE_SCORE)

    -- Roll at/over the threshold: no crit.
    points, procs = Effects.crit(item, { forceRoll = 0.25 }, {})
    H.isFalse(procs.crit)
    H.near(points, 0)

    points, procs = Effects.crit(item, { forceRoll = 0.9 }, {})
    H.isFalse(procs.crit)
    H.near(points, 0)
end

function T.effects_crit_distribution_matches_probability_roughly()
    love.math.setRandomSeed(12345)
    local item = { effect = { kind = "crit", value = 0.3 } }

    local crits, trials = 0, 4000
    for _ = 1, trials do
        local _, procs = Effects.crit(item, {}, {})
        if procs.crit then crits = crits + 1 end
    end

    local rate = crits / trials
    H.isTrue(rate > 0.24 and rate < 0.36,
        "crit rate " .. tostring(rate) .. " should be roughly 0.3")
end

function T.effects_protect_flags_only_on_error()
    local item = { effect = { kind = "protect", value = 1 } }

    local points, procs = Effects.protect(item, { isError = false }, {})
    H.near(points, 0)
    H.isFalse(procs.protected)

    points, procs = Effects.protect(item, { isError = true }, {})
    H.near(points, 0)
    H.isTrue(procs.protected)
end

function T.effects_set_active_only_when_whole_set_installed()
    local item = {
        id = "harmony",
        effect = { kind = "set", value = 1.5, setMembers = { "a", "b", "c" } },
    }

    local points, procs = Effects.set(item, {}, { installedIds = { a = true, b = true } })
    H.near(points, 0)
    H.isFalse(procs.set)

    points, procs = Effects.set(item, {}, { installedIds = { a = true, b = true, c = true } })
    H.near(points, 1.5)
    H.isTrue(procs.set)
end

function T.effects_compute_dispatches_by_kind_and_is_safe_for_unknown()
    local item = { effect = { kind = "flat", value = 0.4 } }
    local points, procs = Effects.compute("flat", item, {}, {})
    H.near(points, 0.4)
    H.deepEqual(procs, {})

    points, procs = Effects.compute("not_a_real_kind", item, {}, {})
    H.near(points, 0)
    H.deepEqual(procs, {})
end

-- ---------------------------------------------------------------------------
-- Rarity
-- ---------------------------------------------------------------------------

function T.rarity_roll_never_returns_unknown_tier()
    for round = 1, 30, 7 do
        for _ = 1, 200 do
            local tier = Rarity.roll(round)
            H.isTrue(Rarity.index(tier) ~= nil, "unknown tier rolled: " .. tostring(tier))
        end
    end
end

function T.rarity_index_matches_declared_order()
    H.equal(Rarity.index("common"), 1)
    H.equal(Rarity.index("legendary"), #Rarity.order)
    H.equal(Rarity.index("not_a_tier"), nil)
end

function T.rarity_weights_favor_higher_tiers_as_round_increases()
    local early = Rarity.weights(1)
    local late = Rarity.weights(25)

    H.isTrue(late.legendary > early.legendary, "legendary weight should rise with round")
    H.isTrue(late.epic > early.epic, "epic weight should rise with round")
    H.isTrue(late.common <= early.common, "common weight should not rise with round")
end

function T.rarity_multipliers_are_monotonic_across_tiers()
    local prevCost, prevPower = 0, 0
    for _, tier in ipairs(Rarity.order) do
        H.isTrue(Rarity.costMultiplier[tier] > prevCost, "cost multiplier must increase with tier")
        H.isTrue(Rarity.powerMultiplier[tier] > prevPower, "power multiplier must increase with tier")
        prevCost = Rarity.costMultiplier[tier]
        prevPower = Rarity.powerMultiplier[tier]
    end
end

-- ---------------------------------------------------------------------------
-- ItemDefs
-- ---------------------------------------------------------------------------

local VALID_CAP_VARIANTS = { plain = true, dyesub = true, doubleshot = true, artisan = true, resin = true }
local VALID_SWITCH_TYPES = { linear = true, tactile = true, clicky = true }
local VALID_KINDS = {}
for _, k in ipairs(Effects.KINDS) do VALID_KINDS[k] = true end

local function assertContractShape(item, msg)
    H.isTrue(type(item.id) == "string" and #item.id > 0, (msg or "") .. ": id")
    H.isTrue(type(item.name) == "string" and #item.name > 0, (msg or "") .. ": name")
    H.isTrue(type(item.key) == "string" and #item.key == 1, (msg or "") .. ": key")
    H.isTrue(Rarity.index(item.rarity) ~= nil, (msg or "") .. ": rarity")
    H.isTrue(VALID_CAP_VARIANTS[item.capVariant], (msg or "") .. ": capVariant " .. tostring(item.capVariant))
    H.isTrue(VALID_SWITCH_TYPES[item.switchType], (msg or "") .. ": switchType " .. tostring(item.switchType))
    H.isTrue(VALID_KINDS[item.effect.kind], (msg or "") .. ": effect.kind " .. tostring(item.effect.kind))
    H.isTrue(type(item.effect.value) == "number", (msg or "") .. ": effect.value")
    H.isTrue(type(item.cost) == "number" and item.cost > 0, (msg or "") .. ": cost")
end

function T.itemDefs_generateOffer_matches_contract_shape_for_every_rarity()
    for _, rarity in ipairs(Rarity.order) do
        for _ = 1, 10 do
            local item = ItemDefs.generateOffer(3, rarity, nil)
            assertContractShape(item, "generateOffer(" .. rarity .. ")")
            H.equal(item.rarity, rarity)
        end
    end
end

function T.itemDefs_at_least_twenty_templates_across_all_kinds_and_rarities()
    local templates = ItemDefs.templates()
    H.isTrue(#templates >= 20, "expected at least 20 templates, got " .. #templates)

    local seenKinds, seenRarities = {}, {}
    for _, tmpl in ipairs(templates) do
        seenKinds[tmpl.kind] = true
        seenRarities[tmpl.fixedRarity or "scalable"] = true
    end

    for _, kind in ipairs(Effects.KINDS) do
        H.isTrue(seenKinds[kind], "no template covers effect kind: " .. kind)
    end
end

function T.itemDefs_legendaries_are_fixed_set_pieces_not_scaled_commons()
    local templates = ItemDefs.templates()
    local sawFixedLegendary = false
    for _, tmpl in ipairs(templates) do
        if tmpl.fixedRarity == "legendary" then
            sawFixedLegendary = true
            -- A scalable template capped below legendary must never be
            -- reachable at legendary via generateOffer's filtering.
        elseif tmpl.maxRarity then
            H.isTrue(Rarity.index(tmpl.maxRarity) < Rarity.index("legendary"),
                "scalable template should not itself reach legendary: " .. tmpl.id)
        end
    end
    H.isTrue(sawFixedLegendary, "expected at least one fixed-legendary template")
end

function T.itemDefs_cost_and_value_correlate_with_rarity()
    -- Find a scalable (non fixed-rarity) template to instantiate at two
    -- different rarities against the same key.
    local scalable
    for _, tmpl in ipairs(ItemDefs.templates()) do
        if not tmpl.fixedRarity then scalable = tmpl break end
    end
    H.isTrue(scalable ~= nil, "expected at least one scalable template")

    local common = ItemDefs.instantiate(scalable, "common", 1, "e")
    local epic = ItemDefs.instantiate(scalable, "epic", 1, "e")

    H.isTrue(epic.cost > common.cost,
        "higher rarity instantiation of the same template must cost more")
    H.isTrue(epic.effect.value > common.effect.value,
        "higher rarity instantiation of the same template must be stronger")
end

function T.itemDefs_all_and_byId_are_consistent()
    local all = ItemDefs.all()
    H.isTrue(#all >= 20)

    for _, item in ipairs(all) do
        assertContractShape(item, "all()")
    end

    local first = all[1]
    local found = ItemDefs.byId(first.id)
    H.isTrue(found ~= nil)
    H.equal(found.id, first.id)

    H.equal(ItemDefs.byId("definitely_not_an_id"), nil)
end

-- ---------------------------------------------------------------------------
-- KeyboardModel: adjacency, install/score, legacy compatibility, round trip
-- ---------------------------------------------------------------------------

function T.keyboardModel_adjacency_is_derived_from_layout_not_hardcoded_qwerty()
    local qwerty = KeyboardModel.new("qwerty")
    local dvorak = KeyboardModel.new("dvorak")

    -- q and w are next to each other on QWERTY's top row...
    H.isTrue(qwerty:isAdjacent("q", "w"), "q/w should be adjacent on QWERTY")
    -- ...but Dvorak puts q and w on opposite ends of the bottom row.
    H.isFalse(dvorak:isAdjacent("q", "w"), "q/w should not be adjacent on Dvorak")

    -- A nil previous character is never adjacent to anything.
    H.isFalse(qwerty:isAdjacent("q", nil))
end

function T.keyboardModel_installItem_replaces_same_kind_but_stacks_different_kinds()
    local kb = KeyboardModel.new("qwerty")

    kb:installItem({ id = "flat_a", key = "e", rarity = "common",
        capVariant = "plain", switchType = "linear", effect = { kind = "flat", value = 0.1 }, cost = 10 })
    kb:installItem({ id = "flat_b", key = "e", rarity = "common",
        capVariant = "plain", switchType = "linear", effect = { kind = "flat", value = 0.5 }, cost = 10 })
    kb:installItem({ id = "crit_a", key = "e", rarity = "rare",
        capVariant = "doubleshot", switchType = "clicky", effect = { kind = "crit", value = 0.2 }, cost = 40 })

    local onE = kb:getItemsOnKey("e")
    H.equal(#onE, 2, "same-kind install should replace, different-kind should stack")

    local ids = {}
    for _, item in ipairs(onE) do ids[item.id] = true end
    H.isTrue(ids.flat_b, "the later same-kind item should win")
    H.isFalse(ids.flat_a == true, "the replaced item should be gone")
    H.isTrue(ids.crit_a, "a different-kind item should still be present")
end

function T.keyboardModel_getTotalMultiplier_reflects_installed_rarity()
    local kb = KeyboardModel.new("qwerty")
    H.near(kb:getTotalMultiplier(), 1.0)

    kb:installItem({ id = "legendary_thing", key = "j", rarity = "legendary",
        capVariant = "resin", switchType = "tactile", effect = { kind = "flat", value = 1 }, cost = 100 })

    H.isTrue(kb:getTotalMultiplier() > 1.0, "installing a legendary should raise the global multiplier")
end

function T.keyboardModel_computeKeyScore_honours_legacy_upgrades_map()
    -- A save from before this unit existed: only the flat `upgrades` map,
    -- no installedItems at all.
    local kb = KeyboardModel.deserialize({
        layoutType = "qwerty",
        multiplier = 1.0,
        upgrades = { e = 0.25 },
    })

    local points = kb:computeKeyScore("e", { streak = 3, prevChar = "w", round = 1, isVowel = true })
    H.near(points, 1.25, 1e-9, "base score + legacy flat bonus")
end

function T.keyboardModel_computeKeyScore_sums_installed_item_effects()
    local kb = KeyboardModel.new("qwerty")
    kb:installItem({ id = "flat_e", key = "e", rarity = "common",
        capVariant = "plain", switchType = "linear", effect = { kind = "flat", value = 0.3 }, cost = 15 })
    kb:installItem({ id = "streak_e", key = "e", rarity = "common",
        capVariant = "plain", switchType = "linear", effect = { kind = "streak", value = 0.1 }, cost = 15 })

    -- base 1.0 + flat 0.3 + streak(0.1 * 4) = 1.7
    local points, procs = kb:computeKeyScore("e", { streak = 4, prevChar = "w", round = 1, isVowel = true })
    H.near(points, 1.7, 1e-9)
    H.isFalse(procs.crit)
    H.equal(procs.coins, 0)
end

function T.keyboardModel_computeKeyError_wires_grace_and_protect()
    local kb = KeyboardModel.new("qwerty")
    kb:installItem({ id = "guard", key = "f", rarity = "uncommon",
        capVariant = "dyesub", switchType = "tactile", effect = { kind = "grace", value = 1 }, cost = 30 })
    kb:installItem({ id = "brace", key = "f", rarity = "uncommon",
        capVariant = "dyesub", switchType = "linear", effect = { kind = "protect", value = 1 }, cost = 28 })

    local result = kb:computeKeyError("f", { round = 1 })
    H.isTrue(result.forgiven, "first error this round should be forgiven")
    H.isTrue(result.protected, "protect should always flag the error as protected")

    result = kb:computeKeyError("f", { round = 1 })
    H.isFalse(result.forgiven, "grace should not forgive a second error in the same round")
    H.isTrue(result.protected, "protect has no per-round limit")
end

function T.keyboardModel_serialize_deserialize_round_trips_items_and_legacy_map()
    local kb = KeyboardModel.new("qwerty")
    kb:upgradeKey("t", 0.2)
    kb:installItem({ id = "flat_e", key = "e", rarity = "epic",
        capVariant = "artisan", switchType = "linear", effect = { kind = "flat", value = 0.4 }, cost = 60 })

    local data = kb:serialize()
    local restored = KeyboardModel.deserialize(data)

    H.near(restored:getKeyBonus("t"), 0.2)
    H.equal(#restored:getInstalled(), 1)
    H.equal(restored:getInstalled()[1].id, "flat_e")
    H.near(restored:getTotalMultiplier(), kb:getTotalMultiplier(), 1e-9)

    -- Scoring behaves the same after a round trip.
    local before = kb:computeKeyScore("e", { streak = 0, round = 1 })
    local after = restored:computeKeyScore("e", { streak = 0, round = 1 })
    H.near(before, after, 1e-9)
end

function T.keyboardModel_generateOffers_returns_contract_shaped_items()
    local kb = KeyboardModel.new("qwerty")
    local offers = kb:generateOffers(5, 4)

    H.equal(#offers, 5)
    for _, item in ipairs(offers) do
        assertContractShape(item, "generateOffers")
    end
end

function T.keyboardModel_generateUpgradeOffers_still_works()
    -- unit 8 falls back to this if it doesn't have the new item system yet.
    local kb = KeyboardModel.new("qwerty")
    local offers = kb:generateUpgradeOffers(3, 20, 70, 0.05, 0.3)

    H.equal(#offers, 3)
    for _, offer in ipairs(offers) do
        H.isTrue(type(offer.key) == "string")
        H.isTrue(offer.cost >= 20 and offer.cost <= 70)
        H.isTrue(offer.bonus >= 0.05 and offer.bonus <= 0.3)
    end
end

return T
