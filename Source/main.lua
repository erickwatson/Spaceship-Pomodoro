import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

import "gameState"
import "buySell"
import "dock"
import "travel"

local pd  <const> = playdate
local gfx <const> = pd.graphics

--------------------------------------------------
-- SCREEN STATE
--------------------------------------------------

local screenState  = "menu"   -- "menu", "story", "market", "buySell", "dock", "travel"
local menuIndex    = 1
local marketIndex  = 1

--------------------------------------------------
-- STORY TEXT
--------------------------------------------------

local storyLines = {
    "Year 3025.",
    "You owe 10,000 credits",
    "to the Syndicate.",
    "",
    "They gave you a ship,",
    "5,000 credits,",
    "and 30 days to pay it back.",
    "",
    "Trade minerals between worlds.",
    "Pay off your debt.",
    "Try not to die."
}

--------------------------------------------------
-- MARKET MENU ITEMS
--------------------------------------------------

local marketItems = {
    "Buy Commodities",
    "Sell Commodities",
    "Travel",
    "Dock",
    "Visit Loan Shark"
}

--------------------------------------------------
-- DRAW HELPERS
--------------------------------------------------

local function drawMarketHeader()
    local p = gameState.player
    local text = string.format(
        "[%s][$%s][-$%s][DUE: %d days]",
        p.planet,
        gameState.formatNumber(p.cash),
        gameState.formatNumber(p.debt),
        p.daysLeft
    )
    gfx.drawTextAligned(text, 200, 10, kTextAlignment.center)
end

--------------------------------------------------
-- DRAW SCREENS
--------------------------------------------------

local function drawMenuScreen()
    gfx.drawTextAligned("SPACE TRADER", 200, 40, kTextAlignment.center)

    local yPlay = 100
    local yQuit = 120

    gfx.drawTextAligned((menuIndex == 1 and "> Play" or "  Play"), 200, yPlay, kTextAlignment.center)
    gfx.drawTextAligned((menuIndex == 2 and "> Quit" or "  Quit"), 200, yQuit, kTextAlignment.center)

    gfx.drawTextAligned("Use ↑/↓ and A", 200, 210, kTextAlignment.center)
end

local function drawStoryScreen()
    gfx.drawTextAligned("PROLOGUE", 200, 20, kTextAlignment.center)

    local y = 50
    for _, line in ipairs(storyLines) do
        gfx.drawTextAligned(line, 200, y, kTextAlignment.center)
        y = y + 14
    end

    gfx.drawTextAligned("Press A to continue", 200, 210, kTextAlignment.center)
end

local function drawMarketScreen()
    drawMarketHeader()

    gfx.drawLine(20, 30, 380, 30)
    gfx.drawTextAligned("TERRA ORBITAL MARKET", 200, 40, kTextAlignment.center)

    local y = 80
    for i, item in ipairs(marketItems) do
        local prefix = (i == marketIndex) and "> " or "  "
        gfx.drawText(prefix .. item, 30, y)
        y = y + 18
    end

    gfx.drawTextAligned("A: Select   B: Back (later)", 200, 210, kTextAlignment.center)
end

--------------------------------------------------
-- MAIN UPDATE LOOP
--------------------------------------------------

function playdate.update()
    gfx.sprite.update()
    pd.timer.updateTimers()

    -----------------------------------
    -- MENU
    -----------------------------------
    if screenState == "menu" then
        if pd.buttonJustPressed(pd.kButtonUp) then
            menuIndex = menuIndex - 1
            if menuIndex < 1 then menuIndex = 2 end
        end

        if pd.buttonJustPressed(pd.kButtonDown) then
            menuIndex = menuIndex + 1
            if menuIndex > 2 then menuIndex = 1 end
        end

        if pd.buttonJustPressed(pd.kButtonA) then
            if menuIndex == 1 then
                screenState = "story"
            end
        end

        gfx.clear()
        gfx.setColor(gfx.kColorBlack)
        drawMenuScreen()
        return
    end

    -----------------------------------
    -- STORY
    -----------------------------------
    if screenState == "story" then
        if pd.buttonJustPressed(pd.kButtonA) then
            screenState = "market"
        end

        gfx.clear()
        gfx.setColor(gfx.kColorBlack)
        drawStoryScreen()
        return
    end

    -----------------------------------
    -- MARKET
    -----------------------------------
    if screenState == "market" then
        if pd.buttonJustPressed(pd.kButtonUp) then
            marketIndex = marketIndex - 1
            if marketIndex < 1 then marketIndex = #marketItems end
        end

        if pd.buttonJustPressed(pd.kButtonDown) then
            marketIndex = marketIndex + 1
            if marketIndex > #marketItems then marketIndex = 1 end
        end

        if pd.buttonJustPressed(pd.kButtonA) then
            print("Market option selected:", marketIndex)
            if marketIndex == 1 then
                buySell.enter("buy")
                screenState = "buySell"
            elseif marketIndex == 2 then
                buySell.enter("sell")
                screenState = "buySell"
            elseif marketIndex == 3 then
                print("Entering travel screen")
                travel.enter()
                screenState = "travel"
            elseif marketIndex == 4 then
                dock.enter()
                screenState = "dock"
            elseif marketIndex == 5 then
                -- Loan Shark (future)
            end
        end

        gfx.clear()
        gfx.setColor(gfx.kColorBlack)
        drawMarketScreen()
        return
    end

    -----------------------------------
    -- BUY/SELL
    -----------------------------------
    if screenState == "buySell" then
        buySell.update()

        if buySell.exitRequested then
            screenState = "market"
        end

        buySell.draw()
        return
    end

    -----------------------------------
    -- DOCK
    -----------------------------------
    if screenState == "dock" then
        dock.update()

        if dock.exitRequested then
            screenState = "market"
        else
            dock.draw()
        end

        return
    end

    -----------------------------------
    -- TRAVEL
    -----------------------------------
    if screenState == "travel" then
        travel.update()

        if travel.exitRequested then
            screenState = "market"
        end

        travel.draw()
        return
    end
end
