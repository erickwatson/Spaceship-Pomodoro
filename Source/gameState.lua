local pd  <const> = playdate
local gfx <const> = pd.graphics

gameState = {}

gameState.history           = {} -- snapshots over time
gameState.isEndless         = false
gameState.gameOverState     = nil  -- nil / "win" / "lose"
gameState.initialDays       = 30   -- starting days, for stats5

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
        sum = sum + qty * commodity.weight
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

-- Net worth = cash + value of cargo at current prices - debt
function gameState.getNetWorth()
    local p      = gameState.player
    local prices = gameState.getMarketPrices()
    local invVal = 0

    for _, c in ipairs(gameState.commodities) do
        local qty   = p.inventory[c.id] or 0
        local price = prices[c.id] or c.basePrice
        invVal = invVal + qty * price
    end

    return p.cash + invVal - p.debt
end

-- Record a snapshot for graphs / stats
function gameState.recordSnapshot(reason)
    local p      = gameState.player
    local prices = gameState.getMarketPrices()
    local invVal = 0

    for _, c in ipairs(gameState.commodities) do
        local qty   = p.inventory[c.id] or 0
        local price = prices[c.id] or c.basePrice
        invVal = invVal + qty * price
    end

    local snap = {
        daysLeft        = p.daysLeft,
        debt            = p.debt,
        cash            = p.cash,
        inventoryValue  = invVal,
        netWorth        = p.cash + invVal - p.debt,
        planet          = p.planet,
        reason          = reason or "",
    }

    table.insert(gameState.history, snap)
end


-- Loan / interest tuning
gameState.interestRatePerDay = 0.02  -- 2% per day – tweak to taste

-- Apply interest on the player's debt over N days
function gameState.applyInterest(days)
    local p = gameState.player
    days = days or 1

    if p.debt <= 0 then
        return 0
    end

    local interest = math.floor(p.debt * gameState.interestRatePerDay * days + 0.5)
    if interest <= 0 then
        return 0
    end

    p.debt = p.debt + interest
    return interest
end

-- Safely pay down debt, clamped by cash + remaining debt
function gameState.payDebt(amount)
    local p = gameState.player
    if amount <= 0 then return 0 end

    if amount > p.cash then amount = p.cash end
    if amount > p.debt then amount = p.debt end
    if amount <= 0 then return 0 end

    p.cash = p.cash - amount
    p.debt = p.debt - amount
    return amount
end

-- Take a new loan (adds both cash and debt)
function gameState.takeLoan(amount)
    local p = gameState.player
    if amount <= 0 then return 0 end

    p.cash = p.cash + amount
    p.debt = p.debt + amount
    return amount
end

-- Check if the game has ended (normal mode only)
function gameState.checkGameOver()
    if gameState.isEndless then
        return nil
    end

    if gameState.gameOverState ~= nil then
        return gameState.gameOverState
    end

    local p = gameState.player

    if p.debt <= 0 then
        gameState.gameOverState = "win"
        gameState.recordSnapshot("win")
        return "win"
    elseif p.daysLeft <= 0 and p.debt > 0 then
        gameState.gameOverState = "lose"
        gameState.recordSnapshot("lose")
        return "lose"
    end

    return nil
end

function gameState.travelTo(destination)
    local player = gameState.player

    if not gameState.planets[destination] then
        return false, "Unknown destination!"
    end

    if player.fuel < gameState.travelFuelCost then
        return false, "Not enough fuel!"
    end

    -- Consume fuel and advance time
    player.fuel     = player.fuel - gameState.travelFuelCost
    player.daysLeft = player.daysLeft - 1
    if player.daysLeft < 0 then player.daysLeft = 0 end

    -- One day of interest
    gameState.applyInterest(1)

    player.planet = destination

    -- Regenerate market stock
    for _, commodity in ipairs(gameState.commodities) do
        commodity.stock = math.random(10, 100)
    end

    gameState.recordSnapshot("travel:" .. destination)

    return true, "Arrived at " .. destination
end

-- Reset to a fresh game state
function gameState.reset()
    gameState.player = {
        planet        = "Narwhal Nebula",
        cash          = 5000,
        debt          = 10000,
        daysLeft      = gameState.initialDays,

        cargoCapacity = 100,
        fuel          = 50,
        fuelCapacity  = 50,

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

    gameState.commodities = {
        { id = "iron",        name = "Iron Ore",     basePrice = 12,   stock = 100, weight = 5   },
        { id = "titanium",    name = "Titanium",     basePrice = 80,   stock = 50,  weight = 3   },
        { id = "xenon",       name = "Xenon Gas",    basePrice = 350,  stock = 25,  weight = 1   },
        { id = "darkCrystal", name = "Dark Crystal", basePrice = 1400, stock = 10,  weight = 0.5 },
    }

    gameState.history       = {}
    gameState.isEndless     = false
    gameState.gameOverState = nil

    gameState.recordSnapshot("newGame")
end

-- Call once on startup
gameState.reset()

-- -- Optional save/load using Playdate datastore
function gameState.save()
    local data = {
        player      = gameState.player,
        commodities = gameState.commodities,
        history     = gameState.history,
        isEndless   = gameState.isEndless,
    }
    local ok, err = pcall(function()
        playdate.datastore.write(data, "playwait_save")
    end)

    if not ok then
        print("Save failed: " .. tostring(err))
    end
    
end

function gameState.load()
    local data = playdate.datastore.read("playwait_save")
    if not data then return false end

    if data.player      then gameState.player      = data.player      end
    if data.commodities then gameState.commodities = data.commodities end
    gameState.history   = data.history   or {}
    gameState.isEndless = data.isEndless or false
    gameState.gameOverState = nil

    return true
end

function gameState.hasSave()
    local data = playdate.datastore.read("playwait_save")
    return data ~= nil
end

function gameState.clearSave()
    playdate.datastore.write(nil, "playwait_save")
end
