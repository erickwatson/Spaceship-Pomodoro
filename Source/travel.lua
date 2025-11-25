import "gameState"

local pd  <const> = playdate
local gfx <const> = pd.graphics

travel = {
    exitRequested = false
}

local selectedIndex = 1
local message = ""

--------------------------------------------------
-- PUBLIC API
--------------------------------------------------

function travel.enter()
    selectedIndex = 1
    message = ""
    travel.exitRequested = false
end

function travel.update()
    -- Navigate destinations
    if pd.buttonJustPressed(pd.kButtonUp) then
        selectedIndex -= 1
        if selectedIndex < 1 then
            selectedIndex = #gameState.destinations
        end
        message = ""
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        selectedIndex += 1
        if selectedIndex > #gameState.destinations then
            selectedIndex = 1
        end
        message = ""
    end

    -- Confirm travel
    if pd.buttonJustPressed(pd.kButtonA) then
        local destination = gameState.destinations[selectedIndex]
        
        -- Don't allow travel to current location
        if destination == gameState.player.planet then
            message = "Already at " .. destination
        else
            local success, msg = gameState.travelTo(destination)
            if success then
                travel.exitRequested = true
            else
                message = msg
            end
        end
    end

    -- Exit back to market
    if pd.buttonJustPressed(pd.kButtonB) then
        travel.exitRequested = true
    end
end

function travel.draw()
    gfx.clear()
    gfx.setColor(gfx.kColorBlack)
    gfx.setFont(gfx.getSystemFont())

    local player = gameState.player

    gfx.drawTextAligned("TRAVEL TO DESTINATION", 200, 10, kTextAlignment.center)
    
    -- Current location
    gfx.drawText("Current: " .. player.planet, 20, 30)
    gfx.drawText(string.format("Fuel: %dt/%dt  (Cost: %dt per trip)", 
        player.fuel, player.fuelCapacity, gameState.travelFuelCost), 20, 45)
    
    gfx.drawLine(20, 60, 380, 60)
    
    -- Destination list
    local y = 75
    for i, dest in ipairs(gameState.destinations) do
        local prefix = (i == selectedIndex) and "> " or "  "
        local suffix = (dest == player.planet) and " (Current)" or ""
        
        if i == selectedIndex then
            gfx.setDitherPattern(0.75)
            gfx.fillRect(18, y - 2, 364, 16)
            gfx.setColor(gfx.kColorWhite)
        else
            gfx.setColor(gfx.kColorBlack)
        end
        
        gfx.drawText(prefix .. dest .. suffix, 20, y)
        y += 18
        
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(0.0)
    end
    
    -- Message area
    if message ~= "" then
        gfx.drawTextAligned(message, 200, 195, kTextAlignment.center)
    end
    
    gfx.drawTextAligned("A: Travel  B: Back", 200, 210, kTextAlignment.center)
end
