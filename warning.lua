
-- CABIN WARNING SIGN
-- 3x2 Advanced Monitor
-- Chinese bitmap renderer

local m = peripheral.find("monitor")
assert(m, "Monitor not found!")
assert(m.isColor(), "Advanced Monitor required!")

m.setTextScale(0.5)
local W, H = m.getSize()
local PW, PH = W * 2, H * 3

assert(PW >= 110 and PH >= 70,
    "Monitor too small. Use 3x2!")

-- Industrial color palette
m.setPaletteColor(colors.black, 0x0B1119)
m.setPaletteColor(colors.yellow, 0xFFD044)
m.setPaletteColor(colors.red, 0xDC3B43)
m.setPaletteColor(colors.white, 0xFFF6E5)
m.setPaletteColor(colors.gray, 0x38424C)

local K = "f" -- Black
local Y = "4" -- Yellow
local R = "e" -- Red
local A = "0" -- White
local G = "7" -- Gray

-- Pixel buffer
local buf = {}

for y = 1, PH do
    buf[y] = {}
    for x = 1, PW do
        buf[y][x] = K
    end
end

local function pixel(x, y, color)
    if x >= 1 and x <= PW
        and y >= 1 and y <= PH then
        buf[y][x] = color
    end
end

local function rect(x1, y1, x2, y2, color)
    for y = y1, y2 do
        for x = x1, x2 do
            pixel(x, y, color)
        end
    end
end

-- Top and bottom hazard stripes
for y = 1, 5 do
    for x = 1, PW do
        if math.floor((x + y * 2) / 10) % 2 == 0 then
            pixel(x, y, Y)
        end
    end
end

for y = PH - 3, PH do
    for x = 1, PW do
        if math.floor((x + y * 2) / 10) % 2 == 0 then
            pixel(x, y, Y)
        end
    end
end

-- Outer border
rect(1, 6, PW, 6, Y)
rect(1, PH-4, PW, PH-4, Y)
rect(1, 6, 2, PH-4, Y)
rect(PW-1, 6, PW, PH-4, Y)

-- Divider: move up
rect(9, 38, PW-8, 39, Y)

-- Red panel: increase top padding
rect(10, 41, PW-9, 62, R)

-- Embedded Chinese bitmap font
-- Main title: 22x22
local BIG = {
"00000000000002000006191006113006312406256c1ffd781f7918061d340635a40f3ffe0f7fb20f81980e81981e7ffe1610c81618d8063cd80636700660e20661f2",
"000000000000000030003ff007ff0006000006000007fff806000806000806001807fff806060006060007fffe061c00061800041ff80c38380c30100c603019c030",
"00000000000000000001fff007ff00000c00000c001ffffe000c0007fff8060c18060c1807fff8060c18060c1807fff8000c00000c0007fffc000c00000c00000c00",
"0000000000000000800200c00208c00218c00218c00218dc1fd8fc1fdbec021fcc023ccc0278cc0218cc0218cc03d8c803d8c80f18c81c1882101802001806000ffe"
}
-- Pad the final glyph to 22 complete rows
BIG[4] = BIG[4] .. string.rep("0", math.max(0, 132 - #BIG[4]))

-- Secondary warning: 16x16
local SMALL = {
"0000081008107efe1c383e7c6ad6499200001ff800007ffe018009b0199c3184",
"000000800080008000801080108010fe10801080108010801080108010807ffe",
"000020202120113003fe7b2017203ffc63207b201bfc132013fe100038006e00",
"000000000f80018000800180018003c003c00240066004200c301818300c6006"
}

-- Draw encoded glyphs
local function drawGlyphs(glyphs, size, gap, y0, color)
    local digits = math.ceil(size / 4)
    local total = #glyphs * size
        + (#glyphs - 1) * gap
    local startX = math.floor((PW - total) / 2) + 1

    for i, data in ipairs(glyphs) do
        local gx0 = startX + (i - 1) * (size + gap)

        for gy = 1, size do
            local a = (gy - 1) * digits + 1
            local bits = tonumber(
                data:sub(a, a + digits - 1), 16
            )

            for gx = 1, size do
                local bit = math.floor(
                    bits / (2 ^ (size - gx))
                ) % 2

                if bit == 1 then
                    pixel(gx0 + gx - 1, y0 + gy - 1, color)
                end
            end
        end
    end
end

-- Main title: move up 4 pixels
drawGlyphs(BIG, 22, 4, 12, Y)

-- Warning text: centered vertically in red panel
drawGlyphs(SMALL, 16, 4, 44, A)

-- Convert pixels to CC 2x3 graphics
local function render()
    for cy = 1, H do
        local chars, fgs, bgs = {}, {}, {}

        for cx = 1, W do
            local x = (cx - 1) * 2 + 1
            local y = (cy - 1) * 3 + 1

            local p = {
                buf[y][x],
                buf[y][x+1],
                buf[y+1][x],
                buf[y+1][x+1],
                buf[y+2][x],
                buf[y+2][x+1]
            }

            local bg = p[6]
            local counts = {}

            for j = 1, 5 do
                if p[j] ~= bg then
                    counts[p[j]] = (counts[p[j]] or 0) + 1
                end
            end

            local fg = bg
            local best = 0

            for c, n in pairs(counts) do
                if n > best then
                    fg, best = c, n
                end
            end

            local mask = 0
            if fg ~= bg then
                for j = 1, 5 do
                    if p[j] == fg then
                        mask = mask + 2 ^ (j-1)
                    end
                end
            end

            chars[cx] = string.char(128 + mask)
            fgs[cx] = fg
            bgs[cx] = bg
        end

        m.setCursorPos(1, cy)
        m.blit(
            table.concat(chars),
            table.concat(fgs),
            table.concat(bgs)
        )
    end
end

render()

-- Native English labels
local function label(text, row, color)
    m.setBackgroundColor(colors.black)
    m.setTextColor(color)
    m.setCursorPos(
        math.floor((W - #text) / 2) + 1,
        row
    )
    m.write(text)
end

label("!! SECURITY WARNING !!", 3, colors.yellow)
label("AUTHORIZED PERSONNEL ONLY", H-2, colors.white)

m.setCursorBlink(false)
print("Warning sign ready!")
