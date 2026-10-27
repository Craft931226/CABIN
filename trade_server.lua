-- CABIN Trade Server v3.0
-- One item type per Ender Chest

local SIDES = {
  left=true, right=true,
  top=true, bottom=true,
  front=true, back=true
}

-- Optional short item names
local LABELS = {
  ["ae2:certus_quartz_crystal"] = "Certus Quartz",
  ["create:blaze_cake"] = "Blaze Cake",
  ["minecraft:ender_pearl"] = "Ender Pearl",
  ["minecraft:gold_ingot"] = "Gold Ingot",
  ["minecraft:quartz"] = "Quartz",
  ["thermal:invar_ingot"] = "Invar Ingot"
}
local CHEST_CONFIG = {
    ["enderstorage:ender_chest_0"] = {
        label = "Blaze cake",
        maxStack = 64,
        relay = "redstone_relay_0",
        side = "right",
        activeHigh = false
    },
    ["enderstorage:ender_chest_5"] = {
        label = "Quartz",
        maxStack = 64,
        relay = "redstone_relay_0",
        side = "front",
        activeHigh = false
    },
    ["enderstorage:ender_chest_2"] = {
        label = "Ender Pearl",
        maxStack = 16,
        relay = "redstone_relay_0",
        side = "left",
        activeHigh = false
    },
    ["enderstorage:ender_chest_16"] = {
        label = "Copper Ingot",
        maxStack = 64,
        relay = "redstone_relay_0",
        side = "back",
        activeHigh = false
    },
    ["enderstorage:ender_chest_17"] = {
        label = "Zinc Ingot",
        maxStack = 64,
        relay = "redstone_relay_0",
        side = "top",
        activeHigh = false
    },
    ["enderstorage:ender_chest_12"] = {
        label = "Emerald",
        maxStack = 64,
        relay = "redstone_relay_1",
        side = "front",
        activeHigh = false
    },
    ["enderstorage:ender_chest_13"] = {
        label = "Diamond",
        maxStack = 64,
        relay = "redstone_relay_1",
        side = "left",
        activeHigh = false
    },
    ["enderstorage:ender_chest_6"] = {
        label = "Niter",
        maxStack = 64,
        relay = "redstone_relay_1",
        side = "back",
        activeHigh = false
    },
    ["enderstorage:ender_chest_9"] = {
        label = "Lead",
        maxStack = 64,
        relay = "redstone_relay_1",
        side = "right",
        activeHigh = false
    },
    ["enderstorage:ender_chest_10"] = {
        label = "Nickel",
        maxStack = 64,
        relay = "redstone_relay_1",
        side = "top",
        activeHigh = false
    },
    ["enderstorage:ender_chest_7"] = {
        label = "Gold",
        maxStack = 64,
        relay = "redstone_relay_2",
        side = "right",
        activeHigh = false
    },
    ["enderstorage:ender_chest_15"] = {
        label = "Blaze Rod",
        maxStack = 64,
        relay = "redstone_relay_2",
        side = "left",
        activeHigh = false
    },
    ["enderstorage:ender_chest_8"] = {
        label = "Sulfur",
        maxStack = 64,
        relay = "redstone_relay_2",
        side = "back",
        activeHigh = false
    },
    ["enderstorage:ender_chest_14"] = {
        label = "Redstone",
        maxStack = 64,
        relay = "redstone_relay_2",
        side = "top",
        activeHigh = false
    },
    ["enderstorage:ender_chest_18"] = {
        label = "Leather",
        maxStack = 64,
        relay = "redstone_relay_2",
        side = "front",
        activeHigh = false
    },
    ["enderstorage:ender_chest_20"] = {
        label = "Andesite Alloy",
        maxStack = 64,
        relay = "redstone_relay_3",
        side = "right",
        activeHigh = false
    },
    ["enderstorage:ender_chest_19"] = {
        label = "Andesite",
        maxStack = 64,
        relay = "redstone_relay_3",
        side = "front",
        activeHigh = false
    },
    ["enderstorage:ender_chest_1"] = {
        label = "Certus Quartz",
        maxStack = 64,
        relay = "redstone_relay_3",
        side = "left",
        activeHigh = false
    },
    ["enderstorage:ender_chest_11"] = {
        label = "Silver Coin",
        maxStack = 64,
        relay = "redstone_relay_3",
        side = "back",
        activeHigh = false
    },
    ["enderstorage:ender_chest_21"] = {
        label = "Silver coin Original",
        maxStack = 64,
        relay = "redstone_relay_3",
        side = "top",
        activeHigh = false
    }
}

local lastKnown = {}

-- Only open wireless or ender modems
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

rednet.host("trade_req", "trade_center")

local slotsCache = {}
local itemCache = {}

local function scan()
  local result = {}
  local errors = 0

  for _, name in ipairs(peripheral.getNames()) do
    if CHEST_CONFIG[name]
      and peripheral.hasType(name, "inventory") then

      local ok1, items =
        pcall(peripheral.call, name, "list")
	  local slots = slotsCache[name]
	  local ok2 = slots ~= nil

	  if not ok2 then
    	  ok2, slots = pcall(peripheral.call, name, "size")
    	  if ok2 then
        	  slotsCache[name] = slots
    	  end
	  end

      if ok1 and type(items) == "table"
        and ok2 and type(slots) == "number" then
        local count = 0
        local itemId = nil
        local firstSlot = nil
        local mixed = false

        for slot, item in pairs(items) do
          count = count + item.count

          if not itemId then
            itemId = item.name
            firstSlot = slot
          elseif itemId ~= item.name then
            mixed = true
          end
        end

        local stackMax = nil
        local displayName = nil

        if firstSlot then
			local detail = itemCache[name]

			if not detail or detail.id ~= itemId then
    			local ok, data = pcall(
        			peripheral.call,
        			name,
        			"getItemDetail",
        			firstSlot
    			)

    			if ok and data then
        			detail = {
            			id = itemId,
            			maxCount = data.maxCount,
            			displayName = data.displayName
        			}
        			itemCache[name] = detail
    			else
        			detail = nil
    			end
			end

			if detail then
    			stackMax = detail.maxCount
    			displayName = detail.displayName
		    end

          lastKnown[name] = {
            id = itemId,
            max = stackMax,
            label = displayName
          }
        elseif lastKnown[name] then
          local old = lastKnown[name]
          itemId = old.id
          stackMax = old.max
          displayName = old.label
        end
		local configured = CHEST_CONFIG[name]

		if configured and not stackMax then
   			stackMax = configured.maxStack
		end

		-- Each Ender Chest stores only one item type
		local capacity = slots * (stackMax or 0)

		local label =
    		(configured and configured.label) or
    		LABELS[itemId] or
  			displayName or
    		(itemId and itemId:match(":(.+)$")) or
    		"Unknown Empty"

		label = label:gsub("^item%.[^:]+:%s*", "")

        local restocking = nil
        local cfg = CHEST_CONFIG[name]

        if cfg and cfg.relay and cfg.side then
            local ok, signal = pcall(
                peripheral.call,
                cfg.relay,
                "getInput",
                cfg.side
            )

            if ok then
                restocking = (
                    signal == (cfg.activeHigh ~= false)
                )
            end
        end

        table.insert(result, {
          peripheral = name,
          id = itemId or "",
          label = label,
          count = count,
          capacity = capacity,
          slots = slots,
          stackMax = stackMax or 0,
          restocking = restocking,
          mixed = mixed
        })
      else
          errors = errors + 1
          print("SCAN ERROR: " .. name)
          print("list: " .. tostring(ok1))
          print("items type: " .. type(items))
          print("size: " .. tostring(slots))
      end
    end
  end

  return {
    version = 3,
    chests = result,
    errors = errors
  }
end

term.clear()
term.setCursorPos(1, 1)
print("TRADE SERVER v3 ONLINE")
print("Computer ID:", os.getComputerID())

local requests = 0

while true do
  local sender, msg = rednet.receive("trade_req")

  if msg == "get" then
    local startTime = os.epoch("utc")
    local data = scan()
    local scanMs = os.epoch("utc") - startTime

    rednet.send(sender, data, "trade_reply")

    requests = requests + 1
    term.setCursorPos(1, 4)
    term.clearLine()
    print("Inventories: " .. #data.chests)

    term.setCursorPos(1, 5)
    term.clearLine()
    print("Requests: " .. requests)
	term.setCursorPos(1, 6)
	term.clearLine()
	print("Scan: " .. scanMs .. " ms")
  end
end