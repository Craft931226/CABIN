-- CABIN Trade Monitor v3.0
-- Pocket Computer UI

local LOW = 0.25
local HIGH = 0.90
local REFRESH = 3

local w, h = term.getSize()
local items = {}
local selected = 1
local sortMode = "name"
local detailMode = false
local lastSeen = nil
local errorText = nil

local function pct(item)
  if not item or item.capacity <= 0 then
    return -1
  end
  return math.min(1, item.count / item.capacity)
end

local function status(item)
  if item.mixed then
    return "MIX", colors.red
  end
  if item.restocking == true then
    return "REFILL", colors.cyan
  end
  local p = pct(item)
  if p < 0 then
    return "N/A", colors.gray
  elseif item.count == 0 then
    return "EMPTY", colors.red
  elseif p >= 1 then
    return "FULL", colors.cyan
  elseif p >= HIGH then
    return "HIGH", colors.yellow
  elseif p <= LOW then
    return "LOW", colors.red
  else
    return "OK", colors.lime
  end
end

local function ordered()
  local t = {}
  for _, item in ipairs(items) do
    t[#t + 1] = item
  end

  table.sort(t, function(a, b)
    if sortMode == "low" then
      local pa, pb = pct(a), pct(b)
      if pa ~= pb then return pa < pb end
    end
    if a.label == b.label then
      return a.peripheral < b.peripheral
    end
    return a.label:lower() < b.label:lower()
  end)

  return t
end

local function put(x, y, str, color)
  if y < 1 or y > h or x > w then return end
  term.setCursorPos(x, y)
  term.setTextColor(color or colors.white)
  term.write(tostring(str):sub(1, w - x + 1))
end

local function drawBar(y, item)
  local p = pct(item)
  local bw = math.max(4, w - 17)
  local fill = p < 0 and 0 or math.floor(p * bw + 0.5)
  local st, color = status(item)

  put(1, y, "  [", colors.gray)
  put(4, y, string.rep("=", fill), color)
  put(4 + fill, y,
      string.rep("-", bw - fill), colors.gray)
  put(4 + bw, y, "]", colors.gray)

  local percentage = p < 0 and "--" or
    tostring(math.floor(p * 100 + 0.5))

  put(6 + bw, y,
      string.format("%3s%% %s", percentage, st),
      color)
end

-- Open the wireless/ender modem
local wireless = false
for _, name in ipairs(peripheral.getNames()) do
  if peripheral.hasType(name, "modem") then
    local m = peripheral.wrap(name)
    if m.isWireless() then
      rednet.open(name)
      wireless = true
    end
  end
end

assert(wireless, "No wireless modem")

local server = rednet.lookup("trade_req", "trade_center")
assert(server, "Trade server not found")

local function render()
  local list = ordered()
  local count = #list
  local perPage = math.max(1, math.floor((h - 7) / 2))

  if count > 0 then
    selected = math.max(1, math.min(selected, count))
  else
    selected = 1
  end

  local age = lastSeen and
    (os.clock() - lastSeen) or nil

  local state, stateColor

  if not age then
    state = "CONNECTING"
    stateColor = colors.yellow
  elseif age < 15 then
    state = "ONLINE"
    stateColor = colors.lime
  elseif age < 45 then
    state = "STALE"
    stateColor = colors.orange
  else
    state = "NO REPLY"
    stateColor = colors.red
  end
  local lowCount = 0

  for _, item in ipairs(list) do
    local p = pct(item)
    if p >= 0 and p <= LOW then
      lowCount = lowCount + 1
    end
  end

  term.setBackgroundColor(colors.black)
  term.clear()

  if detailMode and count > 0 then
    local item = list[selected]
    local p = pct(item)
    local st, color = status(item)

    put(1, 1, " BUFFER DETAIL", colors.cyan)
    put(1, 3, item.label, colors.white)

    put(1, 5, "STATUS: " .. st, color)
    local refillText = "UNMONITORED"
    local refillColor = colors.gray

    if item.restocking == true then
        refillText = "ACTIVE"
        refillColor = colors.cyan
    elseif item.restocking == false then
        refillText = "IDLE"
    end

    put(1, 6, "REFILL: " .. refillText, refillColor)
    put(1, 7, "STOCK: " .. item.count)
    put(1, 8, "CAPACITY: " .. item.capacity)
    put(1, 9, "FREE: " ..
      math.max(0, item.capacity - item.count))

    put(1, 11, "SLOTS: " .. item.slots)
    put(1, 12, "STACK SIZE: " .. item.stackMax)

    if p >= 0 then
      put(1, 14, string.format(
        "USAGE: %.1f%%", p * 100))
    end

    put(1, 16, "PERIPHERAL:", colors.gray)
    put(1, 17, item.peripheral:sub(1, w))
    put(1, 18, item.peripheral:sub(w + 1, w * 2))

    put(1, h, "BACKSPACE: RETURN", colors.gray)
    return
  end

  put(1, 1, " TRADE MONITOR v3", colors.cyan)

  put(1, 2, string.format(
    "SERVER:%d BOXES:%d", server, count), colors.white)

  put(1, 3,
    state .. " LOW:" .. lowCount,
    stateColor)

  if errorText then
    put(1, 3, errorText, colors.red)
  end

  put(1, 4, string.rep("-", w), colors.gray)

  local page = math.floor((selected - 1) / perPage) + 1
  local pages = math.max(1, math.ceil(count / perPage))
  local first = (page - 1) * perPage + 1

  for i = 1, perPage do
    local index = first + i - 1
    local item = list[index]

    if item then
      local y = 5 + (i - 1) * 2
      local qty = tostring(item.count)
      local marker = index == selected and ">" or " "
      local maxName = math.max(1, w - #qty - 4)
      local label = item.label:sub(1, maxName)

      put(1, y, marker .. " " .. label,
          index == selected and colors.cyan or colors.white)
      put(w - #qty + 1, y, qty, colors.white)

      drawBar(y + 1, item)
    end
  end

  put(1, h - 2,
      string.format("PAGE %d/%d SORT:%s",
        page, pages, sortMode:upper()),
      colors.lightGray)

  put(1, h - 1, "UP/DN MOVE ENTER:DETAIL", colors.gray)
  put(1, h, "S SORT R REFRESH Q QUIT", colors.gray)
end

local pending = false
local requestAt = 0

local function request()
  local now = os.clock()

  -- Avoid overlapping requests
  if pending and now - requestAt < 8 then
    return
  end

  pending = true
  requestAt = now

  rednet.send(server, "get", "trade_req")
end

request()
render()

local timer = os.startTimer(REFRESH)

while true do
  local event, a, b, c = os.pullEvent()

  if event == "rednet_message" then
    if a == server and c == "trade_reply" then
	  pending = false
      if type(b) == "table" and b.version == 3 then
        items = b.chests or {}
        lastSeen = os.clock()
        errorText = nil
      else
        errorText = "UPDATE SERVER TO v3"
      end
      render()
    end

  elseif event == "timer" and a == timer then
    request()
    render()
    timer = os.startTimer(REFRESH)

  elseif event == "key" then
    if a == keys.q then
      break

    elseif a == keys.up then
      selected = math.max(1, selected - 1)

    elseif a == keys.down then
      selected = math.min(math.max(1, #items), selected + 1)

    elseif a == keys.s then
      sortMode = sortMode == "name" and "low" or "name"
      selected = 1

    elseif a == keys.r then
      request()

    elseif a == keys.enter then
      if #items > 0 then detailMode = true end

    elseif a == keys.backspace then
      detailMode = false
    end

    render()
  end
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
print("Trade Monitor closed")
