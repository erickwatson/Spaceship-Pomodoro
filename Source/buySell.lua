import "gameState"

local pd  <const> = playdate
local gfx <const> = pd.graphics

buySell = {
    exitRequested = false
}

local mode          = "buy"   -- "buy" or "sell"
local selectedIndex = 1
local quantity      = 0
local prices        = {}

--------------------------------------------------
-- COLUMN LAYOUT
--------------------------------------------------

local colX = {
    resource  = 16,
    price     = 130,
    available = 190,
    qty       = 250,
    inv       = 320,
}

local headerY   = 32
local rowsStart = 52
local rowHeight = 16

--------------------------------------------------
-- INTERNAL HELPERS
--------------------------------------------------

local function getSelectedCommodity()
    return gameState.commodities[selectedIndex]
end

-- Max you are allowed to trade for a given commodity,
-- considering cash, cargo weight, and stock/owned.
local function getMaxQuantityForCommodity(commodity)
    local player = gameState.player
    local price  = prices[commodity.id] or commodity.basePrice

    if mode == "buy" then
        local stock           = commodity.stock or 0
        local maxByCash       = (price > 0) and math.floor(player.cash / price) or 0
        local availableWeight = player.cargoCapacity - gameState.getCargoUsed()
        local maxByWeight     = (commodity.weight > 0) and math.floor(availableWeight / commodity.weight) or 0

        local max = stock
        if maxByCash   < max then max = maxByCash end
        if maxByWeight < max then max = maxByWeight end
        if max < 0 then max = 0 end
        return max
    else
        -- sell mode: limited by what you own
        local owned = player.inventory[commodity.id] or 0
        return owned
    end
end

local function getMaxQuantityForSelected()
    local commodity = getSelectedCommodity()
    local price     = prices[commodity.id] or commodity.basePrice
    local max       = getMaxQuantityForCommodity(commodity)
    return max, price
end

--------------------------------------------------
-- PUBLIC API
--------------------------------------------------

function buySell.enter(startMode)
    mode          = startMode or "buy"
    selectedIndex = 1
    quantity      = 0
    prices        = gameState.getMarketPrices()
    buySell.exitRequested = false
end

function buySell.update()
    -- Change row selection
    if pd.buttonJustPressed(pd.kButtonUp) then
        selectedIndex = selectedIndex - 1
        if selectedIndex < 1 then
            selectedIndex = #gameState.commodities
        end
        quantity = 0
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        selectedIndex = selectedIndex + 1
        if selectedIndex > #gameState.commodities then
            selectedIndex = 1
        end
        quantity = 0
    end

    -- Adjust quantity for selected row
    local maxQty, price = getMaxQuantityForSelected()

    if pd.buttonJustPressed(pd.kButtonLeft) then
        quantity = quantity - 1
        if quantity < 0 then quantity = 0 end
    elseif pd.buttonJustPressed(pd.kButtonRight) then
        quantity = quantity + 1
        if quantity > maxQty then quantity = maxQty end
    end

    -- Confirm buy/sell
    if pd.buttonJustPressed(pd.kButtonA) and quantity > 0 then
        local player    = gameState.player
        local commodity = getSelectedCommodity()
        local total     = quantity * price

        if mode == "buy" then
            if total <= player.cash and quantity <= (commodity.stock or 0) then
                player.cash = player.cash - total
                player.inventory[commodity.id] =
                    (player.inventory[commodity.id] or 0) + quantity

                -- reduce market stock of this commodity only
                commodity.stock = (commodity.stock or 0) - quantity
                if commodity.stock < 0 then commodity.stock = 0 end
            end
        else
            local owned = player.inventory[commodity.id] or 0
            if quantity <= owned then
                player.cash = player.cash + total
                player.inventory[commodity.id] = owned - quantity

                -- optionally increase market stock when you sell
                commodity.stock = (commodity.stock or 0) + quantity
            end
        end

        quantity = 0
        prices   = gameState.getMarketPrices()
    end

    -- Exit back to market
    if pd.buttonJustPressed(pd.kButtonB) then
        buySell.exitRequested = true
    end
end

function buySell.draw()
    gfx.clear()
    gfx.setColor(gfx.kColorBlack)
    gfx.setFont(gfx.getSystemFont())

    local title = (mode == "buy") and "BUY COMMODITIES" or "SELL COMMODITIES"
    gfx.drawTextAligned(title, 200, 10, kTextAlignment.center)

    --------------------------------------------------
    -- HEADER ROW + GRID
    --------------------------------------------------

    gfx.drawRect(8, 24, 384, 140)

    gfx.drawLine(colX.price - 4,     24, colX.price - 4,     164)
    gfx.drawLine(colX.available - 4, 24, colX.available - 4, 164)
    gfx.drawLine(colX.qty - 4,       24, colX.qty - 4,       164)
    gfx.drawLine(colX.inv - 4,       24, colX.inv - 4,       164)

    gfx.drawText("Resource", colX.resource,  headerY)
    gfx.drawText("$Price",   colX.price,     headerY)
    gfx.drawText("Available",colX.available, headerY)
    gfx.drawText((mode == "buy") and "Buy" or "Sell", colX.qty, headerY)
    gfx.drawText("Inv.",     colX.inv,       headerY)

    gfx.drawLine(8, headerY + 12, 392, headerY + 12)

    --------------------------------------------------
    -- ROWS
    --------------------------------------------------

    local player    = gameState.player
    local cargoUsed = gameState.getCargoUsed()

    for i, commodity in ipairs(gameState.commodities) do
        local y = rowsStart + (i - 1) * rowHeight

        -- Highlight current row
        if i == selectedIndex then
            gfx.setDitherPattern(0.75)
            gfx.fillRect(9, y - 1, 382, rowHeight)
            gfx.setColor(gfx.kColorWhite)
        else
            gfx.setColor(gfx.kColorBlack)
        end

        local price      = prices[commodity.id] or commodity.basePrice
        local owned      = player.inventory[commodity.id] or 0
        local availStock -- what we show in the "Available" column
        if mode == "buy" then
            availStock = commodity.stock or 0
        else
            availStock = owned  -- how much you can sell
        end

        local rowQty = (i == selectedIndex) and quantity or 0

        gfx.drawText(commodity.name, colX.resource, y)
        gfx.drawText(string.format("$%d", price), colX.price, y)
        gfx.drawText(tostring(availStock), colX.available, y)
        gfx.drawText(tostring(rowQty), colX.qty, y)
        gfx.drawText(tostring(owned), colX.inv, y)

        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(0.0)
    end

    --------------------------------------------------
    -- FOOTER
    --------------------------------------------------

    local footerY = 172
    gfx.drawText(
        string.format(
            "Cash: $%s   Cargo: %.1ft/%dt   Fuel: %dt",
            gameState.formatNumber(player.cash),
            cargoUsed,
            player.cargoCapacity,
            player.fuel
        ),
        12, footerY
    )

    gfx.drawTextAligned("↑/↓ row  ←/→ qty  A: confirm  B: back", 200, 210, kTextAlignment.center)
end
