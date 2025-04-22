-- Banking System Client Module
-- Handles banking operations with a UI

-- Configuration
local OPCODE = 156 -- Use a different opcode than other modules
local bankButton = nil
local bankWindow = nil

-- Initialize the module
function init()
  g_logger.info("Initializing Banking module...")
  g_logger.info("Module version: 1.0.2")

  -- Connect to game events
  connect(
    g_game,
    {
      onGameStart = create,
      onGameEnd = destroy,
      onTalk = onTalk
    }
  )

  -- Register extended opcode handler
  ProtocolGame.registerExtendedOpcode(OPCODE, onExtendedOpcode)

  -- Create UI if player is already online
  if g_game.isOnline() then
    g_logger.info("Player is online, creating bank UI...")
    create()
  else
    g_logger.info("Player is not online, waiting for onGameStart event...")
  end
  
  g_logger.info("Banking module initialized!")
end

-- Terminate the module
function terminate()
  g_logger.info("Terminating Banking module...")

  -- Disconnect from game events
  disconnect(
    g_game,
    {
      onGameStart = create,
      onGameEnd = destroy,
      onTalk = onTalk
    }
  )

  -- Unregister opcode handler
  ProtocolGame.unregisterExtendedOpcode(OPCODE, onExtendedOpcode)

  -- Destroy UI
  destroy()
  
  g_logger.info("Banking module terminated!")
end

-- Handle NPC talk to detect banking keywords
function onTalk(name, level, mode, text, channelId, pos)
  -- Check if this is an NPC that said "hi" or "hello" and we're close to them
  if mode == 27 or mode == 28 then -- NPC talk modes
    local lowercaseText = text:lower()
    if (lowercaseText:find("bank") or lowercaseText:find("balance") or 
        lowercaseText:find("deposit") or lowercaseText:find("withdraw")) then
      
      -- Calculate distance to NPC
      local player = g_game.getLocalPlayer()
      if player and pos and getDistanceBetween(player:getPosition(), pos) < 4 then
        -- We're talking to a banker NPC - show the bank window
        show()
        
        -- Request balance update
        requestBalance()
      end
    end
  end
end

-- Create UI elements
function create()
  g_logger.info("Creating Banking UI...")
  
  if bankWindow then
    g_logger.info("Window already exists, skipping creation.")
    return
  end

  -- Add button to the top menu
  bankButton = modules.client_topmenu.addRightGameToggleButton(
    "bankButton", 
    tr('Bank'), 
    "/images/topbuttons/bank", 
    toggle, 
    true
  )
  
  if bankButton then
    g_logger.info("Successfully created BankButton!")
  else
    g_logger.error("Failed to create BankButton!")
  end
  
  -- Load the window UI
  g_logger.info("Displaying bank_window.otui...")
  bankWindow = g_ui.displayUI("bank_window")
  if not bankWindow then
    g_logger.error("Failed to load Bank window!")
    return
  end
  
  g_logger.info("Successfully loaded Bank window!")
  
  -- Check UI elements to make sure they're created
  local balanceValue = bankWindow:getChildById('balanceValue')
  if balanceValue then
    g_logger.info("balanceValue element found!")
  else
    g_logger.error("balanceValue element NOT found!")
  end
  
  -- Set initial UI state
  bankWindow:hide()
  
  -- Set the amount edit to accept only numbers
  local amountEdit = bankWindow:getChildById('amountEdit')
  if amountEdit then
    amountEdit:setValidCharacters('0123456789')
  end
  
  -- Set initial status message
  local statusLabel = bankWindow:getChildById('statusLabel')
  if statusLabel then
    statusLabel:setText("Ready for transactions")
  end
  
  g_logger.info("Banking UI created!")
end

-- Request balance update from server
function requestBalance()
  g_logger.info("Requesting bank balance from server...")
  
  -- Update status to show we're loading
  local statusLabel = safeGetElement('statusLabel')
  if statusLabel then
    statusLabel:setText("Checking balance...")
  end
  
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(OPCODE, json.encode({action = "get_balance"}))
    g_logger.info("Balance request sent with opcode: " .. OPCODE)
  else
    g_logger.error("Failed to get protocol game!")
    
    -- Show error in status
    if statusLabel then
      statusLabel:setText("Error: Cannot connect to server")
      statusLabel:setColor("#ff0000")
    end
  end
end

-- Deposit specified amount to bank
function deposit()
  g_logger.info("Deposit button clicked!")
  
  -- Get amount from input field
  local amountEdit = safeGetElement('amountEdit')
  if not amountEdit then
    g_logger.error("Failed to find amountEdit!")
    return
  end
  
  local amount = tonumber(amountEdit:getText())
  if not amount or amount <= 0 then
    -- Show error in status
    local statusLabel = safeGetElement('statusLabel')
    if statusLabel then
      statusLabel:setText("Please enter a valid amount")
      statusLabel:setColor("#ff0000")
    end
    return
  end
  
  -- Send deposit request to server
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(OPCODE, json.encode({
      action = "deposit",
      amount = amount
    }))
    
    -- Update status
    local statusLabel = safeGetElement('statusLabel')
    if statusLabel then
      statusLabel:setText("Processing deposit...")
      statusLabel:setColor("#ffffff")
    end
  else
    g_logger.error("Failed to get protocol game!")
  end
end

-- Withdraw specified amount from bank
function withdraw()
  g_logger.info("Withdraw button clicked!")
  
  -- Get amount from input field
  local amountEdit = safeGetElement('amountEdit')
  if not amountEdit then
    g_logger.error("Failed to find amountEdit!")
    return
  end
  
  local amount = tonumber(amountEdit:getText())
  if not amount or amount <= 0 then
    -- Show error in status
    local statusLabel = safeGetElement('statusLabel')
    if statusLabel then
      statusLabel:setText("Please enter a valid amount")
      statusLabel:setColor("#ff0000")
    end
    return
  end
  
  -- Send withdraw request to server
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(OPCODE, json.encode({
      action = "withdraw",
      amount = amount
    }))
    
    -- Update status
    local statusLabel = safeGetElement('statusLabel')
    if statusLabel then
      statusLabel:setText("Processing withdrawal...")
      statusLabel:setColor("#ffffff")
    end
  else
    g_logger.error("Failed to get protocol game!")
  end
end

-- Deposit all money to bank
function depositAll()
  g_logger.info("Deposit All button clicked!")
  
  -- Send deposit all request to server
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(OPCODE, json.encode({
      action = "deposit_all"
    }))
    
    -- Update status
    local statusLabel = safeGetElement('statusLabel')
    if statusLabel then
      statusLabel:setText("Processing deposit all...")
      statusLabel:setColor("#ffffff")
    end
  else
    g_logger.error("Failed to get protocol game!")
  end
end

-- Withdraw all money from bank
function withdrawAll()
  g_logger.info("Withdraw All button clicked!")
  
  -- Send withdraw all request to server
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(OPCODE, json.encode({
      action = "withdraw_all"
    }))
    
    -- Update status
    local statusLabel = safeGetElement('statusLabel')
    if statusLabel then
      statusLabel:setText("Processing withdrawal all...")
      statusLabel:setColor("#ffffff")
    end
  else
    g_logger.error("Failed to get protocol game!")
  end
end

-- Handle server responses
function onExtendedOpcode(protocol, opcode, buffer)
  if opcode ~= OPCODE then
    return
  end
  
  local json_status, json_data = pcall(function()
    return json.decode(buffer)
  end)
  
  if not json_status then
    g_logger.error("BANK json error: " .. json_data)
    return false
  end
  
  local data = json_data
  
  -- Ensure we have a valid window
  if not bankWindow then
    g_logger.error("Bank window not available, recreating...")
    create()
    if not bankWindow then
      g_logger.error("Failed to recreate bank window!")
      return
    end
  end
  
  -- Handle balance update from server
  if data.action == "balance_update" then
    g_logger.info("Received bank balance: " .. data.balance)
    
    -- Update balance display using our helper function
    if updateBalanceDisplay(data.balance) then
      -- Update status
      local statusLabel = safeGetElement('statusLabel')
      if statusLabel then
        statusLabel:setText("Balance updated")
        statusLabel:setColor("#00ff00")
      end
    end
  
  -- Handle transaction result
  elseif data.action == "transaction_result" then
    local statusLabel = safeGetElement('statusLabel')
    
    if data.success then
      -- Update balance display
      updateBalanceDisplay(data.balance)
      
      -- Clear amount field
      local amountEdit = safeGetElement('amountEdit')
      if amountEdit then
        amountEdit:setText("")
      end
      
      -- Show success message
      if statusLabel then
        statusLabel:setText(data.message)
        statusLabel:setColor("#00ff00")
      end
    else
      -- Show error message
      if statusLabel then
        statusLabel:setText(data.message)
        statusLabel:setColor("#ff0000")
      end
    end
  end
end

-- Format number with commas for readability
function comma_value(amount)
  local formatted = amount
  while true do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1.%2")
    if (k == 0) then
      break
    end
  end
  return formatted
end

-- Toggle the window visibility
function toggle()
  g_logger.info("Toggle function called!")
  
  if not bankWindow then
    g_logger.error("Cannot toggle: bankWindow is nil!")
    return
  end
  
  if bankWindow:isVisible() then
    g_logger.info("Window is visible, hiding...")
    return hide()
  end
  
  g_logger.info("Window is hidden, showing...")
  show()
end

-- Show the window and update balance
function show()
  g_logger.info("Show function called!")
  
  if not bankWindow then
    g_logger.error("Cannot show: bankWindow is nil!")
    create()
    if not bankWindow then
      g_logger.error("Failed to recreate bank window!")
      return
    end
  end
  
  -- Position the window in the center of the screen
  local gameUi = modules.game_interface.getMapPanel():getParent()
  local gameWidth, gameHeight = gameUi:getWidth(), gameUi:getHeight()
  local windowWidth, windowHeight = bankWindow:getWidth(), bankWindow:getHeight()
  
  local x = (gameWidth - windowWidth) / 2
  local y = (gameHeight - windowHeight) / 2
  
  bankWindow:setPosition({x = x, y = y})
  
  -- Check if UI elements are accessible
  local balanceValue = bankWindow:getChildById('balanceValue')
  if balanceValue then
    g_logger.info("balanceValue element accessible at show time")
  else
    g_logger.error("balanceValue element NOT accessible at show time")
    
    -- Try to recreate the window
    bankWindow:destroy()
    bankWindow = nil
    bankWindow = g_ui.displayUI("bank_window")
    
    -- Check again after recreation
    if bankWindow then
      balanceValue = bankWindow:getChildById('balanceValue')
      if balanceValue then
        g_logger.info("balanceValue element found after recreation")
      else
        g_logger.error("balanceValue element STILL not found after recreation")
      end
    end
  end
  
  -- Show the window
  bankWindow:show()
  bankWindow:raise()
  bankWindow:focus()
  
  -- Request balance update when showing the window, but with a small delay
  -- This ensures the window is fully rendered before we try to access elements
  scheduleEvent(function()
    -- Double check that window still exists before requesting
    if bankWindow then
      -- Verify that elements exist
      local balanceValueCheck = bankWindow:getChildById('balanceValue')
      if balanceValueCheck then
        g_logger.info("balanceValue element found before balance request")
      else
        g_logger.error("balanceValue element NOT found before balance request")
      end
      
      requestBalance()
    end
  end, 100) -- 100ms delay
  
  g_logger.info("Window shown!")
end

-- Hide the window
function hide()
  g_logger.info("Hide function called!")
  
  if not bankWindow then
    g_logger.error("Cannot hide: bankWindow is nil!")
    return
  end
  
  bankWindow:hide()
  g_logger.info("Window hidden!")
end

-- Destroy UI elements
function destroy()
  g_logger.info("Destroying Banking UI...")
  
  if bankButton then
    bankButton:destroy()
    bankButton = nil
    g_logger.info("BankButton destroyed!")
  end

  if bankWindow then
    bankWindow:destroy()
    bankWindow = nil
    g_logger.info("BankWindow destroyed!")
  end
  
  g_logger.info("Banking UI destroyed!")
end

-- Helper function to safely get UI elements with fallbacks
function safeGetElement(elementId)
  -- First check if the window exists
  if not bankWindow then
    g_logger.error("Cannot get element " .. elementId .. ": bankWindow is nil!")
    return nil
  end
  
  -- Try direct child lookup first
  local element = bankWindow:getChildById(elementId)
  if element then
    return element
  end
  
  -- Try recursive lookup if direct failed
  element = bankWindow:recursiveGetChildById(elementId)
  if element then
    g_logger.info("Found " .. elementId .. " using recursive search")
    return element
  end
  
  -- If we still don't have the element, try using a path pattern
  local panels = {"topPanel", "buttonPanel", "allButtonPanel"}
  for _, panel in ipairs(panels) do
    local panelWidget = bankWindow:getChildById(panel)
    if panelWidget then
      element = panelWidget:getChildById(elementId)
      if element then
        g_logger.info("Found " .. elementId .. " in " .. panel)
        return element
      end
    end
  end
  
  -- If all else fails, log the error and return nil
  g_logger.error("Failed to find element: " .. elementId)
  return nil
end

-- Update balance display with formatted value
function updateBalanceDisplay(balance)
  local balanceValue = safeGetElement('balanceValue')
  if balanceValue then
    local formattedBalance = comma_value(balance)
    g_logger.info("Setting formatted balance: " .. formattedBalance)
    balanceValue:setText(formattedBalance .. " gold")
    return true
  end
  
  return false
end 