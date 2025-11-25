import "gameState"

local pd  <const> = playdate
local gfx <const> = pd.graphics

dock = {
    exitRequested = false
}

local selectedIndex = 1

-- tuning knobs
local fuelPricePerUnit          = 10
local cargoUpgradeBaseCost      = 1000
local fuelTankUpgradeBaseCost   = 800
local cargoCapacityPerUpgrade   = 10   -- tons
local fuelCapacityPerUpgrade    = 10   -- tons

local menuItems = {
    "Refuel",
    "Upgrade Cargo Bay",
    "Upgrade Fuel Tank",
}

--------------------------------------------------
-- INTERNAL HELPERS
--------------------------------------------------

-- Max fuel we *can* add, limited by:
-- - tank capacity (fuelCapacity)
-- - cargo capacity (fuel consumes cargo space)
local function getRefuelInfo()
    local p = gameState.player

    local fuelMissingToTank = p.fuelCapacity - p.fuel
    if fuelMissingToTank < 0 then fuelMissingToTank = 0 end

    local cargoUsed  = gameState.getCargoUsed()
    local cargoFree  = p.cargoCapacity - cargoUsed
    if cargoFree < 0 then cargoFree = 0 end

    -- 1 fuel = 1 ton of cargo space
    local maxByCargo = cargoFree
    local maxCanAdd  = math.min(fuelMissingToTank, maxByCargo)

    local cost = maxCanAdd * fuelPricePerUnit
    return maxCanAdd, cost
end

local function getCargoUpgradeCost()
    local level = gameState.player.cargoUpgradeLevel or 0
    return cargoUpgradeBaseCost * (level + 1)
end

local function getFuelUpgradeCost()
    local level = gameState.player.fuelUpgradeLevel or 0
    return fuelTankUpgradeBaseCost * (level + 1)
end

--------------------------------------------------
-- PUBLIC API
--------------------------------------------------

function dock.enter()
    dock.exitRequested = false
    selectedIndex = 1
end

function dock.update()
    local p = gameState.player

    if pd.buttonJustPressed(pd.kButtonUp) then
        selectedIndex = selectedIndex - 1
        if selectedIndex < 1 then
            selectedIndex = #menuItems
        end
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        selectedIndex = selectedIndex + 1
        if selectedIndex > #menuItems then
            selectedIndex = 1
        end
    end

    if pd.buttonJustPressed(pd.kButtonB) then
        dock.exitRequested = true
        return
    end

    if pd.buttonJustPressed(pd.kButtonA) then
        if selectedIndex == 1 then
            -- Refuel
            local canAdd, cost = getRefuelInfo()
            if canAdd > 0 and p.cash >= cost then
                p.cash = p.cash - cost
                p.fuel = p.fuel + canAdd
            end

        elseif selectedIndex == 2 then
            -- Upgrade Cargo Bay
            local cost = getCargoUpgradeCost()
            if p.cash >= cost then
                p.cash = p.cash - cost
                p.cargoUpgradeLevel = (p.cargoUpgradeLevel or 0) + 1
                p.cargoCapacity = p.cargoCapacity + cargoCapacityPerUpgrade
            end

        elseif selectedIndex == 3 then
            -- Upgrade Fuel Tank
            local cost = getFuelUpgradeCost()
            if p.cash >= cost then
                p.cash = p.cash - cost
                p.fuelUpgradeLevel = (p.fuelUpgradeLevel or 0) + 1
                p.fuelCapacity = p.fuelCapacity + fuelCapacityPerUpgrade
            end
        end
    end
end

function dock.draw()
    local p = gameState.player
    local cargoUsed = gameState.getCargoUsed()

    gfx.clear()
    gfx.setColor(gfx.kColorBlack)
    gfx.setFont(gfx.getSystemFont())

    gfx.drawTextAligned("DOCK - SHIP SERVICES", 200, 10, kTextAlignment.center)

    --------------------------------------------------
    -- SHIP STATUS PANEL
    --------------------------------------------------

    local statusY = 30
    gfx.drawText(
        string.format(
            "Hull: %d/%d   Fuel: %d/%d   Cargo: %.1f/%d",
            p.hull, p.maxHull,
            p.fuel, p.fuelCapacity,
            cargoUsed, p.cargoCapacity
        ),
        12, statusY
    )

    gfx.drawText(
        string.format("Cash: $%s", gameState.formatNumber(p.cash)),
        12, statusY + 14
    )

    --------------------------------------------------
    -- MENU BOX
    --------------------------------------------------

    local boxY = 64
    gfx.drawRect(8, boxY, 384, 90)

    local canAddFuel, refuelCost = getRefuelInfo()
    local cargoUpgradeCost       = getCargoUpgradeCost()
    local fuelUpgradeCost        = getFuelUpgradeCost()

    local y = boxY + 8

    for i, label in ipairs(menuItems) do
        local prefix = (i == selectedIndex) and "> " or "  "
        local line = label

        if i == 1 then
            if canAddFuel <= 0 then
                line = line .. " (FULL / NO SPACE)"
            else
                line = line .. string.format("  (+%d fuel, $%d)", canAddFuel, refuelCost)
            end
        elseif i == 2 then
            line = line .. string.format(
                "  (+%d cargo, $%d)  [Lvl %d]",
                cargoCapacityPerUpgrade,
                cargoUpgradeCost,
                (p.cargoUpgradeLevel or 0)
            )
        elseif i == 3 then
            line = line .. string.format(
                "  (+%d fuel cap, $%d)  [Lvl %d]",
                fuelCapacityPerUpgrade,
                fuelUpgradeCost,
                (p.fuelUpgradeLevel or 0)
            )
        end

        gfx.drawText(prefix .. line, 16, y)
        y = y + 18
    end

    gfx.drawTextAligned("↑/↓ select   A: confirm   B: back", 200, 210, kTextAlignment.center)
end
