import "gameState"

local pd  <const> = playdate
local gfx <const> = pd.graphics

loanShark = {
    exitRequested = false
}

local selectedIndex = 1
local paymentAmount = 0
local loanAmount    = 0

local stepAmount    = 100   -- increment for payment/loan adjustments

local menuItems = {
    "Make Payment",
    "Take New Loan",
    "Hear the Threats",
}

--------------------------------------------------
-- INTERNAL HELPERS
--------------------------------------------------

local function getThreatText()
    local p   = gameState.player
    local d   = p.debt
    local days = p.daysLeft

    if d <= 0 then
        return "Syndicate: We're... impressed. For now."
    end

    if days > 20 then
        return "Syndicate: Plenty of time. Don't get comfy."
    elseif days > 10 then
        return "Syndicate: Clock's ticking. We expect progress."
    elseif days > 5 then
        return "Syndicate: We're watching your account closely."
    elseif days > 1 then
        return "Syndicate: You like that ship? Pay up. Soon."
    else
        return "Syndicate: Last. Chance."
    end
end

local function clampPayment()
    local p = gameState.player
    if paymentAmount < 0 then paymentAmount = 0 end
    if paymentAmount > p.cash then paymentAmount = p.cash end
    if paymentAmount > p.debt then paymentAmount = p.debt end
end

local function clampLoan()
    if loanAmount < 0 then loanAmount = 0 end
    -- you *could* add a max loan limit here later
end

--------------------------------------------------
-- PUBLIC API
--------------------------------------------------

function loanShark.enter()
    loanShark.exitRequested = false
    selectedIndex = 1

    -- reasonable defaults
    local p = gameState.player
    paymentAmount = math.min(500, p.cash, p.debt)
    if paymentAmount < 0 then paymentAmount = 0 end

    loanAmount = 1000
end

function loanShark.update()
    local p = gameState.player

    -- navigation
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

    -- adjust payment or loan with left/right
    if pd.buttonJustPressed(pd.kButtonLeft) then
        if selectedIndex == 1 then
            paymentAmount = paymentAmount - stepAmount
            clampPayment()
        elseif selectedIndex == 2 then
            loanAmount = loanAmount - stepAmount
            clampLoan()
        end
    elseif pd.buttonJustPressed(pd.kButtonRight) then
        if selectedIndex == 1 then
            paymentAmount = paymentAmount + stepAmount
            clampPayment()
        elseif selectedIndex == 2 then
            loanAmount = loanAmount + stepAmount
            clampLoan()
        end
    end

    -- back to market
    if pd.buttonJustPressed(pd.kButtonB) then
        loanShark.exitRequested = true
        return
    end

    -- confirm actions
    if pd.buttonJustPressed(pd.kButtonA) then
        if selectedIndex == 1 then
            -- Make Payment
            local paid = gameState.payDebt(paymentAmount)
            if paid > 0 then
                -- After paying, re-clamp in case debt/cash changed
                clampPayment()
            end

        elseif selectedIndex == 2 then
            -- Take New Loan
            local got = gameState.takeLoan(loanAmount)
            if got > 0 then
                -- optionally adjust future min payment, etc.
            end

        elseif selectedIndex == 3 then
            -- Hear the Threats – no mechanical effect for now
            -- (Threat text is always shown in draw() anyway)
        end
    end
end

function loanShark.draw()
    local p = gameState.player

    gfx.clear()
    gfx.setColor(gfx.kColorBlack)
    gfx.setFont(gfx.getSystemFont())

    gfx.drawTextAligned("THE SYNDICATE - LOAN OFFICE", 200, 10, kTextAlignment.center)

    --------------------------------------------------
    -- STATUS PANEL
    --------------------------------------------------

    local statusY = 30
    gfx.drawText(
        string.format(
            "Debt: $%s   Days Left: %d   Cash: $%s",
            gameState.formatNumber(p.debt),
            p.daysLeft,
            gameState.formatNumber(p.cash)
        ),
        12, statusY
    )

    gfx.drawText(getThreatText(), 12, statusY + 14)

    --------------------------------------------------
    -- MENU BOX
    --------------------------------------------------

    local boxY = 70
    gfx.drawRect(8, boxY, 384, 100)

    local y = boxY + 8

    for i, label in ipairs(menuItems) do
        local prefix = (i == selectedIndex) and "> " or "  "
        local line = label

        if i == 1 then
            line = line .. string.format("  [$%d]", paymentAmount)
        elseif i == 2 then
            line = line .. string.format("  [$%d]", loanAmount)
        else
            -- "Hear the Threats" – no dynamic number
        end

        gfx.drawText(prefix .. line, 16, y)
        y = y + 18
    end

    gfx.drawTextAligned("↑/↓ select  ←/→ adjust  A: confirm  B: back", 200, 210, kTextAlignment.center)
end
