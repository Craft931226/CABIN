
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
rect(10, 42, PW-9, PH-10, R)

-- Embedded Chinese bitmap font
-- Main title: 20x20
local BIG = {
  "000001818018d90189b019bac7fcf818c9818ab419ffc1db903c09839ffc78cc858c4818e7819b70190721b19e1a30c00000", -- 機
  "00000000f80ffe018000180001fffc1800c1800c1fff818300183801fffe1040010ff810ff831818230186e0304c0f000000", -- 房
  "00000001f81ffe0006007fffe7fffe006001fff818618186181fff8186181fff800600006001fffc00600006007fffe00000", -- 重
  "00000080400804008440084401845c7e4fc087cc09e4c09c4c08448084480e4483c440604020040600606007fc0000000000" -- 地
}


-- Warning text: 14x14
local SMALL = {
  "000002100f7e073c0f3c1a52021007f800000ffe02d004cc08c40000", -- 禁
  "00000040004000400440047c047c044004400440044004401ffe0000", -- 止
  "000008800c9004fc1f9007fc08901cfc04b004b4044c0f0011fe0000", -- 進
  "000007c0004000c000c000c001a00120031006180c0c180600000000" -- 入
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

-- Main title
drawGlyphs(BIG, 20, 4, 15, Y)

-- Restricted area warning
drawGlyphs(SMALL, 14, 4, 45, A)

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

label("!! SECURITY WARNING !!", 4, colors.yellow)
label("AUTHORIZED PERSONNEL ONLY", H-2, colors.white)

m.setCursorBlink(false)
print("Warning sign ready!")
