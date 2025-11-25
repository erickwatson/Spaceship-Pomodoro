local pd  <const> = playdate
local gfx <const> = pd.graphics

gameState = {}

--------------------------------------------------
-- PLAYER
--------------------------------------------------

gameState.player = {
    planet        = "Narwhal Nebula",
    cash          = 5000,
    debt          = 10000,
    daysLeft      = 30,

    -- cargo & fuel
    cargoCapacity = 100,  -- tons
    fuel          = 50,   -- tons (fuel takes cargo space)
    fuelCapacity  = 50,   -- tons

    -- ship condition / upgrades
    hull              = 100,
    maxHull           = 100,
    cargoUpgradeLevel = 0,
    fuelUpgradeLevel  = 0,

    inventory     = {
        iron        = 0,
        titanium    = 0,
        xenon       = 0,
        darkCrystal = 0,
    }
}

--------------------------------------------------
-- COMMODITIES / PLANETS
--------------------------------------------------

gameState.commodities = {
    { id = "iron",        name = "Iron Ore",     basePrice = 12,   stock = 100, weight = 5   },  -- tons per unit
    { id = "titanium",    name = "Titanium",     basePrice = 80,   stock = 50,  weight = 3   },
    { id = "xenon",       name = "Xenon Gas",    basePrice = 350,  stock = 25,  weight = 1   },
    { id = "darkCrystal", name = "Dark Crystal", basePrice = 1400, stock = 10,  weight = 0.5 },
}

gameState.planets = {
    ["Narwhal Nebula"] = {
        priceMultipliers = {
            iron        = 0.8,
            titanium    = 1.2,
            xenon       = 1.5,
            darkCrystal = 1.3,
        }
    },
    ["Gerbil Galaxy"] = {
        priceMultipliers = {
            iron        = 1.3,
            titanium    = 0.9,
            xenon       = 1.1,
            darkCrystal = 1.6,
        }
    },
    ["Unicorn Nexus"] = {
        priceMultipliers = {
            iron        = 1.1,
            titanium    = 1.4,
            xenon       = 0.7,
            darkCrystal = 1.2,
        }
    },
    ["Former Terran Colonies"] = {
        priceMultipliers = {
            iron        = 0.9,
            titanium    = 1.0,
            xenon       = 1.4,
            darkCrystal = 0.8,
        }
    },
    ["Outskirts Space Station"] = {
        priceMultipliers = {
            iron        = 1.5,
            titanium    = 0.7,
            xenon       = 0.9,
            darkCrystal = 1.7,
        }
    },
    ["Mega Moon Alliance"] = {
        priceMultipliers = {
            iron        = 0.7,
            titanium    = 1.3,
            xenon       = 1.2,
            darkCrystal = 1.4,
        }
    }
}

-- All destinations with fuel cost to reach them
gameState.destinations = {
    "Narwhal Nebula",
    "Gerbil Galaxy",
    "Unicorn Nexus",
    "Former Terran Colonies",
    "Outskirts Space Station",
    "Mega Moon Alliance"
}

gameState.travelFuelCost = 4  -- tons of fuel per trip

--------------------------------------------------
-- HELPERS
--------------------------------------------------

function gameState.formatNumber(n)
    local s = tostring(n)
    local pos = #s - 2
    while pos > 1 do
        s = s:sub(1, pos) .. "," .. s:sub(pos + 1)
        pos = pos - 3
    end
    return s
end

function gameState.getCargoUsed()
    -- fuel takes up cargo space, plus goods * their weight
    local sum = gameState.player.fuel
    for _, commodity in ipairs(gameState.commodities) do
        local qty = gameState.player.inventory[commodity.id] or 0
        sum = sum + qty * commodity.weight   -- ✅ fixed "+="
    end
    return sum
end

function gameState.getMarketPrices()
    local player     = gameState.player
    local planetData = gameState.planets[player.planet]
    local result     = {}

    for _, c in ipairs(gameState.commodities) do
        local mult = 1.0
        if planetData and planetData.priceMultipliers and planetData.priceMultipliers[c.id] then
            mult = planetData.priceMultipliers[c.id]
        end
        result[c.id] = math.floor(c.basePrice * mult)
    end

    return result  -- table: id → price
end

-- Travel to a new destination
function gameState.travelTo(destination)
    local player = gameState.player

    if player.fuel < gameState.travelFuelCost then
        return false, "Not enough fuel!"
    end

    -- Consume fuel and advance time
    player.fuel     = player.fuel - gameState.travelFuelCost   -- ✅ fixed "-="
    player.daysLeft = player.daysLeft - 1

    player.planet = destination

    -- Regenerate market stock at new location
    for _, commodity in ipairs(gameState.commodities) do
        commodity.stock = math.random(10, 100)
    end

    return true, "Arrived at " .. destination
end
