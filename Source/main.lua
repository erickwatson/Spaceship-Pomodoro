import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

import "gameState"
import "buySell"
import "dock"
import "travel"
import "loanShark"

local pd  <const> = playdate
local gfx <const> = pd.graphics

-- Seed RNG once (nice for your random market stock)
math.randomseed(pd.getSecondsSinceEpoch())

--------------------------------------------------
-- GLOBAL-ish STATE
--------------------------------------------------

local screenState      = "menu"   -- "menu", "story", "market", "buySell", "dock", "travel", "loanShark", "gameOver", "summary"
local menuIndex        = 1
local marketIndex      = 1

-- For crank+physics menu
local menuVisualIndex  = 1.0      -- smoothed version of menuIndex
local menuCrankAccum   = 0        -- accumulated crank degrees

local gameOverOutcome   = nil   -- "win" / "lose"
local gameOverMenuIndex = 1
local summaryMenuIndex  = 1     -- currently just for future expansion

local hasSave           = gameState.hasSave()

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
-- MENU HELPERS
--------------------------------------------------

local function getMenuItems()
    if hasSave then
        return { "Continue", "New Game", "Settings" }
    else
        return { "New Game", "Settings" }
    end
end

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

local function drawMenuScreen()
    gfx.drawTextAligned("SPACE TRADER", 200, 40, kTextAlignment.center)

    local items = getMenuItems()
    local y = 100
    for i, label in ipairs(items) do
        local prefix = (i == menuIndex) and "> " or "  "
        gfx.drawTextAligned(prefix .. label, 200, y, kTextAlignment.center)
        y = y + 18
    end

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
    gfx.drawTextAligned("ORBITAL MARKET", 200, 40, kTextAlignment.center)

    local y = 80
    for i, item in ipairs(marketItems) do
        local prefix = (i == marketIndex) and "> " or "  "
        gfx.drawText(prefix .. item, 30, y)
        y = y + 18
    end

    gfx.drawTextAligned("A: Select   B: Back (later)", 200, 210, kTextAlignment.center)
end

--------------------------------------------------
-- GAME OVER SCREEN
--------------------------------------------------

local function drawGameOverScreen()
    local p       = gameState.player
    local outcome = gameOverOutcome
    local title
    local detail

    if outcome == "win" then
        local daysUsed = (gameState.initialDays or 30) - p.daysLeft
        if daysUsed < 0 then daysUsed = 0 end
        title  = "DEBT REPAID!"
        detail = string.format("You paid off the Syndicate in %d days.", daysUsed)
    else
        title  = "YOU FAILED..."
        detail = "The Syndicate has repossessed your ship."
    end

    gfx.clear()
    gfx.setColor(gfx.kColorBlack)

    gfx.drawTextAligned(title, 200, 40, kTextAlignment.center)
    gfx.drawTextAligned(detail, 200, 60, kTextAlignment.center)

    local options
    if outcome == "win" then
        options = { "View Summary", "Endless Mode", "Main Menu" }
    else
        options = { "View Summary", "Main Menu" }
    end

    local y = 120
    for i, label in ipairs(options) do
        local prefix = (i == gameOverMenuIndex) and "> " or "  "
        gfx.drawTextAligned(prefix .. label, 200, y, kTextAlignment.center)
        y = y + 18
    end

    gfx.drawTextAligned("↑/↓ select   A: confirm", 200, 210, kTextAlignment.center)
end

local function updateGameOver()
    local outcome = gameOverOutcome
    local options

    if outcome == "win" then
        options = { "View Summary", "Endless Mode", "Main Menu" }
    else
        options = { "View Summary", "Main Menu" }
    end

    if pd.buttonJustPressed(pd.kButtonUp) then
        gameOverMenuIndex = gameOverMenuIndex - 1
        if gameOverMenuIndex < 1 then gameOverMenuIndex = #options end
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        gameOverMenuIndex = gameOverMenuIndex + 1
        if gameOverMenuIndex > #options then gameOverMenuIndex = 1 end
    end

    if pd.buttonJustPressed(pd.kButtonA) then
        local choice = options[gameOverMenuIndex]

        if choice == "View Summary" then
            screenState = "summary"

        elseif choice == "Endless Mode" then
            gameState.isEndless     = true
            gameState.gameOverState = nil
            gameOverOutcome         = nil
            -- you could clear history here or keep it
            screenState = "market"

        elseif choice == "Main Menu" then
            gameState.save()
            screenState       = "menu"
            gameOverOutcome   = nil
            gameOverMenuIndex = 1
            hasSave           = gameState.hasSave()
        end
    end
end

--------------------------------------------------
-- SUMMARY SCREEN (GRAPH)
--------------------------------------------------

local function drawSummaryScreen()
    local history = gameState.history

    gfx.clear()
    gfx.setColor(gfx.kColorBlack)

    gfx.drawTextAligned("GAME SUMMARY", 200, 10, kTextAlignment.center)

    if #history < 2 then
        gfx.drawTextAligned("Not enough data to draw graph.", 200, 120, kTextAlignment.center)
        gfx.drawTextAligned("Press B to return to menu.", 200, 140, kTextAlignment.center)
        return
    end

    -- find min/max net worth
    local minNW = history[1].netWorth
    local maxNW = history[1].netWorth
    for _, h in ipairs(history) do
        if h.netWorth < minNW then minNW = h.netWorth end
        if h.netWorth > maxNW then maxNW = h.netWorth end
    end
    if maxNW == minNW then
        maxNW = minNW + 1
    end

    local graphLeft   = 20
    local graphTop    = 40
    local graphWidth  = 360
    local graphHeight = 120

    gfx.drawRect(graphLeft, graphTop, graphWidth, graphHeight)

    local prevX, prevY

    for i, h in ipairs(history) do
        local t   = (i - 1) / (#history - 1)
        local x   = graphLeft + 1 + t * (graphWidth - 2)
        local norm = (h.netWorth - minNW) / (maxNW - minNW)
        local y   = graphTop + graphHeight - 2 - norm * (graphHeight - 4)

        if prevX ~= nil then
            gfx.drawLine(prevX, prevY, x, y)
        end
        prevX, prevY = x, y
    end

    local first = history[1]
    local last  = history[#history]

    gfx.drawText(
        string.format("Start Net Worth: $%d", first.netWorth),
        20, graphTop + graphHeight + 6
    )
    gfx.drawText(
        string.format("End Net Worth:   $%d", last.netWorth),
        20, graphTop + graphHeight + 20
    )

    gfx.drawTextAligned("B: Main Menu", 200, 210, kTextAlignment.center)
end

local function updateSummaryScreen()
    if pd.buttonJustPressed(pd.kButtonB) then
        screenState       = "menu"
        gameOverOutcome   = nil
        gameOverMenuIndex = 1
        hasSave           = gameState.hasSave()
    end
end

--------------------------------------------------
-- COMMON GAME-OVER CHECK
--------------------------------------------------

local function checkForGameOver()
    local outcome = gameState.checkGameOver and gameState.checkGameOver() or nil
    if outcome ~= nil then
        gameOverOutcome   = outcome
        gameOverMenuIndex = 1
        screenState       = "gameOver"
        -- optional: gameState.save()
        return true
    end
    return false
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
        local items = getMenuItems()

        if pd.buttonJustPressed(pd.kButtonUp) then
            menuIndex = menuIndex - 1
            if menuIndex < 1 then menuIndex = #items end
        end

        if pd.buttonJustPressed(pd.kButtonDown) then
            menuIndex = menuIndex + 1
            if menuIndex > #items then menuIndex = 1 end
        end
        
        if pd.buttonJustPressed(pd.kButtonA) then
            if not hasSave then
                -- items = { New Game, Settings }
                if menuIndex == 1 then
                    gameState.reset()
                    gameState.save()
                    hasSave     = true
                    screenState = "story"
                    menuIndex   = 1
                elseif menuIndex == 2 then
                    -- Settings placeholder
                end
            else
                -- items = { Continue, New Game, Settings }
                if menuIndex == 1 then
                    -- Continue
                    if gameState.load() then
                        screenState = "market"
                    else
                        hasSave = false
                    end
                elseif menuIndex == 2 then
                    -- New Game
                    gameState.reset()
                    gameState.save()
                    screenState = "story"
                    menuIndex   = 1
                elseif menuIndex == 3 then
                    -- Settings placeholder
                end
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
            if marketIndex == 1 then
                buySell.enter("buy")
                screenState = "buySell"
            elseif marketIndex == 2 then
                buySell.enter("sell")
                screenState = "buySell"
            elseif marketIndex == 3 then
                travel.enter()
                screenState = "travel"
            elseif marketIndex == 4 then
                dock.enter()
                screenState = "dock"
            elseif marketIndex == 5 then
                loanShark.enter()
                screenState = "loanShark"
            end
        end

        if checkForGameOver() then
            return
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

        if checkForGameOver() then
            return
        end

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

        if checkForGameOver() then
            return
        end

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

        if checkForGameOver() then
            return
        end

        if travel.exitRequested then
            screenState = "market"
        end

        travel.draw()
        return
    end

    -----------------------------------
    -- LOAN SHARK
    -----------------------------------
    if screenState == "loanShark" then
        loanShark.update()

        if checkForGameOver() then
            return
        end

        if loanShark.exitRequested then
            screenState = "market"
        else
            loanShark.draw()
        end

        return
    end

    -----------------------------------
    -- GAME OVER
    -----------------------------------
    if screenState == "gameOver" then
        updateGameOver()
        drawGameOverScreen()
        return
    end

    -----------------------------------
    -- SUMMARY
    -----------------------------------
    if screenState == "summary" then
        updateSummaryScreen()
        drawSummaryScreen()
        return
    end
end
