-- Game Tasks Idler Module
-- Handles idle rewards system with crafting-style UI

local OPCODE = 111 -- Using a different opcode than tasks system

local idlerButton = nil
local idlerWindow = nil
local lastClaimTime = 0
local CLAIM_COOLDOWN = 60 -- Cooldown in seconds
local updateEvent = nil -- Timer event for updating countdown display
local playerBalance = 0 -- Store player's bank balance
local clickValue = 1 -- Default gold per click value
local UPGRADE_COST = 1000 -- Cost to upgrade click value

-- Main initialization function
function init()
  g_logger.info("Initializing Idle Rewards module...")
  g_logger.info("Module version: 1.2.0") -- Updated version number

  -- Connect to game events
  connect(
    g_game,
    {
      onGameStart = create,
      onGameEnd = destroy
    }
  )

  -- Register extended opcode handler
  ProtocolGame.registerExtendedOpcode(OPCODE, onExtendedOpcode)

  -- Create UI if player is already online
  if g_game.isOnline() then
    g_logger.info("Player is online, creating UI...")
    create()
  else
    g_logger.info("Player is not online, waiting for onGameStart event...")
  end
  
  g_logger.info("Idle Rewards module initialized!")
end

-- Terminate the module
function terminate()
  g_logger.info("Terminating Idle Rewards module...")

  -- Disconnect from game events
  disconnect(
    g_game,
    {
      onGameStart = create,
      onGameEnd = destroy
    }
  )

  -- Unregister opcode handler
  ProtocolGame.unregisterExtendedOpcode(OPCODE, onExtendedOpcode)

  -- Destroy UI
  destroy()
  
  g_logger.info("Idle Rewards module terminated!")
end

-- Safely get a UI element, logging an error if it doesn't exist
function safeGetElement(parent, elementId)
  if not parent then
    g_logger.error("Parent element is nil when trying to access " .. elementId)
    return nil
  end
  
  local element = parent:getChildById(elementId)
  if not element then
    g_logger.error("Failed to find element: " .. elementId)
    return nil
  end
  
  return element
end

-- Create the UI elements
function create()
  g_logger.info("Creating Idle Rewards UI...")
  
  if idlerWindow then
    g_logger.info("Window already exists, skipping creation.")
    return
  end

  -- Add button to the top menu (using particles image as requested)
  idlerButton = modules.client_topmenu.addRightGameToggleButton("idlerButton", tr('Idle Rewards'), "/images/topbuttons/particles", toggle, true)
  if idlerButton then
    g_logger.info("Successfully created IdlerButton!")
  else
    g_logger.error("Failed to create IdlerButton!")
  end
  
  -- Load the window UI from idler_window.otui
  g_logger.info("Displaying idler_window.otui...")
  idlerWindow = g_ui.displayUI("idler_window")
  if not idlerWindow then
    g_logger.error("Failed to load Idler window!")
    return
  end
  
  g_logger.info("Successfully loaded Idler window!")
  
  -- Set initial UI state
  idlerWindow:hide()
  
  -- Get main panel
  local craftPanel = idlerWindow:getChildById('craftPanel')
  if not craftPanel then
    g_logger.error("Failed to find craftPanel!")
    return
  end
  
  -- Set initial status message
  local statusLabel = craftPanel:getChildById('statusLabel')
  if statusLabel then
    statusLabel:setText("Welcome to Idle Rewards")
    statusLabel:setColor("#FFFFFF")
  else
    g_logger.error("Failed to find statusLabel!")
  end
  
  -- Set initial timer display
  local timerDisplay = craftPanel:getChildById('timerDisplay')
  if timerDisplay then
    timerDisplay:setText("Checking...")
    timerDisplay:setColor("#FFFFFF")
  else
    g_logger.error("Failed to find timerDisplay!")
  end
  
  -- Initialize player money display
  local balancePanel = craftPanel:getChildById('balancePanel')
  if balancePanel then
    local playerMoney = balancePanel:getChildById('playerMoney')
    if playerMoney then
      playerMoney:setText("0")
    else
      g_logger.error("Failed to find playerMoney!")
    end
  else
    g_logger.error("Failed to find balancePanel!")
  end
  
  -- Set the gold button text based on current click value
  local buttonPanel = idlerWindow:getChildById('buttonPanel')
  if buttonPanel then
    local goldButton = buttonPanel:getChildById('goldButton')
    if goldButton then
      goldButton:setText("Get " .. clickValue .. " Gold")
    else
      g_logger.error("Failed to find goldButton!")
    end
  else
    g_logger.error("Failed to find buttonPanel!")
  end
  
  -- Set the click value display
  local infoPanel = idlerWindow:getChildById('infoPanel')
  if infoPanel then
    local currentClickPanel = infoPanel:getChildById('currentClickPanel')
    if currentClickPanel then
      local clickValueLabel = currentClickPanel:getChildById('clickValueLabel')
      if clickValueLabel then
        clickValueLabel:setText("Value: " .. clickValue .. " per click")
      else
        g_logger.error("Failed to find clickValueLabel!")
      end
    else
      g_logger.error("Failed to find currentClickPanel!")
    end
  else
    g_logger.error("Failed to find infoPanel!")
  end
  
  -- Set the upgrade button initial state
  updateUpgradeButton()
  
  -- Request timer status from server
  requestTimerStatus()
  
  -- Start a timer that updates the countdown every second
  startUpdateTimer()
  
  g_logger.info("Idle Rewards UI created!")
end

-- Destroy UI elements
function destroy()
  g_logger.info("Destroying Idle Rewards UI...")
  
  -- Stop the update timer
  stopUpdateTimer()
  
  if idlerButton then
    idlerButton:destroy()
    idlerButton = nil
    g_logger.info("IdlerButton destroyed!")
  end

  if idlerWindow then
    idlerWindow:destroy()
    idlerWindow = nil
    g_logger.info("IdlerWindow destroyed!")
  end
  
  lastClaimTime = 0
  playerBalance = 0
  
  g_logger.info("Idle Rewards UI destroyed!")
end

-- Request timer status from server
function requestTimerStatus()
  g_logger.info("Requesting timer status from server...")
  
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(OPCODE, json.encode({action = "get_timer_status"}))
  else
    g_logger.error("Failed to get protocol game!")
  end
end

-- Request gold balance status from server
function requestGoldStatus()
  g_logger.info("Requesting gold balance from server...")
  
  -- Update UI to show we're loading
  local statusLabel = idlerWindow and safeGetElement(idlerWindow:getChildById('craftPanel'), 'statusLabel')
  if statusLabel then
    statusLabel:setText("Checking gold balance...")
    statusLabel:setColor("#FFFFFF")
  end
  
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(OPCODE, json.encode({action = "get_gold_status"}))
  else
    g_logger.error("Failed to get protocol game!")
  end
end

-- Get 1 gold coin instantly
function claimGold()
  g_logger.info("Gold button clicked!")
  
  -- Send a request to server to get 1 gold coin (using click value)
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(OPCODE, json.encode({action = "get_gold_coin", amount = clickValue}))
    
    -- Update status temporarily
    local statusLabel = idlerWindow and safeGetElement(idlerWindow:getChildById('craftPanel'), 'statusLabel')
    if statusLabel then
      statusLabel:setText("Requesting " .. clickValue .. " gold coin" .. (clickValue > 1 and "s" or "") .. "...")
      statusLabel:setColor("#FFFFFF")
    end
  else
    g_logger.error("Failed to get protocol game!")
  end
end

-- Upgrade the gold click value
function upgradeGoldClick()
  g_logger.info("Upgrade button clicked!")
  
  -- Check if player has enough gold
  if playerBalance < UPGRADE_COST then
    -- Not enough gold
    if idlerWindow then
      local craftPanel = idlerWindow:getChildById('craftPanel')
      if craftPanel then
        local statusLabel = craftPanel:getChildById('statusLabel')
        if statusLabel then
          statusLabel:setText("Not enough gold for upgrade!")
          statusLabel:setColor("#FF0000")
        end
      end
    end
    return
  end
  
  -- Send request to server to upgrade click value
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(OPCODE, json.encode({action = "upgrade_click", cost = UPGRADE_COST}))
    
    -- Update status temporarily
    if idlerWindow then
      local craftPanel = idlerWindow:getChildById('craftPanel')
      if craftPanel then
        local statusLabel = craftPanel:getChildById('statusLabel')
        if statusLabel then
          statusLabel:setText("Processing upgrade...")
          statusLabel:setColor("#FFFFFF")
        end
      end
    end
  else
    g_logger.error("Failed to get protocol game!")
  end
end

-- Update the upgrade button state based on player balance
function updateUpgradeButton()
  g_logger.info("updateUpgradeButton: Starting button update")
  
  if not idlerWindow then
    g_logger.error("updateUpgradeButton: idlerWindow is nil")
    return
  end
  
  -- Debug the window hierarchy
  g_logger.info("updateUpgradeButton: Window children: " .. table.concat(tableToList(idlerWindow:getChildren()), ", "))
  
  -- Get craftPanel first
  local craftPanel = idlerWindow:getChildById('craftPanel')
  if not craftPanel then
    g_logger.error("updateUpgradeButton: craftPanel not found")
    return
  end
  
  -- Debug craftPanel children
  g_logger.info("updateUpgradeButton: craftPanel children: " .. table.concat(tableToList(craftPanel:getChildren()), ", "))
  
  -- Get infoPanel from craftPanel
  local infoPanel = craftPanel:getChildById('infoPanel')
  if not infoPanel then
    g_logger.error("updateUpgradeButton: infoPanel not found in craftPanel")
    return
  end
  
  -- Debug infoPanel children
  g_logger.info("updateUpgradeButton: infoPanel children: " .. table.concat(tableToList(infoPanel:getChildren()), ", "))
  
  -- Then get the upgrade button directly from infoPanel
  local upgradeButton = infoPanel:getChildById('upgradeButton')
  if not upgradeButton then
    g_logger.error("updateUpgradeButton: upgradeButton not found in infoPanel")
    return
  end
  
  -- Get click value panel
  local currentClickPanel = infoPanel:getChildById('currentClickPanel')
  if not currentClickPanel then
    g_logger.error("updateUpgradeButton: currentClickPanel not found")
    return
  end
  
  -- Update the click value display
  local clickValueLabel = currentClickPanel:getChildById('clickValueLabel')
  if clickValueLabel then
    clickValueLabel:setText("Value: " .. clickValue .. " per click")
  else
    g_logger.error("updateUpgradeButton: clickValueLabel not found")
  end
  
  -- Get cost panel
  local upgradeCostPanel = infoPanel:getChildById('upgradeCostPanel')
  if not upgradeCostPanel then
    g_logger.error("updateUpgradeButton: upgradeCostPanel not found")
    return
  end
  
  -- Update cost text if needed
  local costLabel = upgradeCostPanel:getChildById('costLabel')
  if costLabel then
    costLabel:setText("Cost: " .. UPGRADE_COST .. " gold")
  else
    g_logger.error("updateUpgradeButton: costLabel not found")
  end
  
  -- Log current state for debugging
  g_logger.info("updateUpgradeButton: balance=" .. playerBalance .. ", cost=" .. UPGRADE_COST)
  
  if playerBalance >= UPGRADE_COST then
    -- Enable the upgrade button
    g_logger.info("updateUpgradeButton: enabling button")
    upgradeButton:setEnabled(true)
    upgradeButton:setOpacity(1.0)
    upgradeButton:setImageColor("#3c6e71")
  else
    -- Disable the upgrade button
    g_logger.info("updateUpgradeButton: disabling button")
    upgradeButton:setEnabled(false)
    upgradeButton:setOpacity(0.5)
    upgradeButton:setImageColor("#ababab")
  end
end

-- Helper function to convert a table of UI elements to a list of IDs
function tableToList(items)
  local result = {}
  for i, item in ipairs(items) do
    if item.getId then
      table.insert(result, item:getId() or "unknown")
    else
      table.insert(result, "no-id")
    end
  end
  return result
end

-- Handle messages from server
function onExtendedOpcode(protocol, opcode, buffer)
  if opcode ~= OPCODE then
    return
  end
  
  local json_status, json_data = pcall(function()
    return json.decode(buffer)
  end)
  
  if not json_status then
    g_logger.error("IDLER json error: " .. json_data)
    return false
  end
  
  local data = json_data
  
  -- Handle reward result from server
  if data.action == "reward_result" then
    local statusLabel = idlerWindow and safeGetElement(idlerWindow:getChildById('craftPanel'), 'statusLabel')
    local timerDisplay = idlerWindow and safeGetElement(idlerWindow:getChildById('craftPanel'), 'timerDisplay')
    
    if statusLabel then
      if data.success then
        -- Animate the crafting lines to show successful claim
        for i = 1, 6 do
          local craftLine = idlerWindow and safeGetElement(idlerWindow:getChildById('craftPanel'), 'craftLine' .. i)
          if craftLine then
            -- Check if the element has image source before trying to use it
            local ok, originalSource = pcall(function() return craftLine:getImageSource() end)
            if ok and originalSource then
              craftLine:setImageSource(originalSource .. "on")
              
              scheduleEvent(function()
                craftLine:setImageSource(originalSource)
              end, 850)
            end
          end
        end
        
        -- Update status with the reward amount
        statusLabel:setText("Reward claimed: " .. data.amount .. " gold!")
        statusLabel:setColor("#00FF00")
        
        -- Update last claim time
        lastClaimTime = os.time()
        
        -- Update the timer display with new countdown
        if timerDisplay then
          timerDisplay:setText(string.format("%d:%02d", 1, 0)) -- Start with 1:00
          timerDisplay:setColor("#FF9900")
        end
        
        -- Request updated gold balance
        requestGoldStatus()
      else
        statusLabel:setText("Failed: " .. data.message)
        statusLabel:setColor("#FF0000")
      end
    end
  -- Handle timer status from server
  elseif data.action == "timer_status" then
    g_logger.info("Received timer status from server: " .. data.remainingTime .. " seconds")
    
    local timerDisplay = idlerWindow and safeGetElement(idlerWindow:getChildById('craftPanel'), 'timerDisplay')
    local statusLabel = idlerWindow and safeGetElement(idlerWindow:getChildById('craftPanel'), 'statusLabel') 
    
    if data.remainingTime > 0 then
      -- Still on cooldown, calculate the last claim time
      lastClaimTime = os.time() - (CLAIM_COOLDOWN - data.remainingTime)
      
      -- Update timer display directly
      if timerDisplay then
        local minutes = math.floor(data.remainingTime / 60)
        local seconds = data.remainingTime % 60
        timerDisplay:setText(string.format("%d:%02d", minutes, seconds))
        timerDisplay:setColor("#FF9900")
      end
      
      -- Update reward button state
      local rewardButton = idlerWindow and safeGetElement(idlerWindow:getChildById('buttonPanel'), 'rewardButton')
      if rewardButton then
        rewardButton:setEnabled(false)
      end
      
      -- Update status if needed
      if statusLabel and (statusLabel:getText() == "Checking reward status..." or statusLabel:getText() == "Welcome to Idle Rewards") then
        statusLabel:setText("Waiting for next reward...")
        statusLabel:setColor("#FF9900")
      end
    else
      -- Ready to claim
      lastClaimTime = 0
      
      -- Update timer display directly
      if timerDisplay then
        timerDisplay:setText("Ready!")
        timerDisplay:setColor("#00FF00")
      end
      
      -- Update reward button state
      local rewardButton = idlerWindow and safeGetElement(idlerWindow:getChildById('buttonPanel'), 'rewardButton')
      if rewardButton then
        rewardButton:setEnabled(true)
      end
      
      -- Update status if needed
      if statusLabel and (statusLabel:getText() == "Checking reward status..." or statusLabel:getText() == "Welcome to Idle Rewards") then
        statusLabel:setText("Reward is ready to claim!")
        statusLabel:setColor("#00FF00")
      end
    end
  -- Handle gold balance status from server  
  elseif data.action == "gold_status" then
    g_logger.info("Received gold balance: " .. data.balance)
    
    -- Store the player's bank balance
    playerBalance = data.bankBalance
    
    -- Update click value if provided
    if data.clickValue and data.clickValue > 0 then
      local oldClickValue = clickValue
      clickValue = data.clickValue
      
      -- Update gold button text if value changed
      if oldClickValue ~= clickValue and idlerWindow then
        local buttonPanel = idlerWindow:getChildById('buttonPanel')
        if buttonPanel then
          local goldButton = buttonPanel:getChildById('goldButton')
          if goldButton then
            goldButton:setText("Get " .. clickValue .. " Gold")
          end
        end
      end
    end
    
    -- Format the balance with commas for better readability
    local formattedBankBalance = comma_value(data.bankBalance)
    
    -- Update UI elements - use proper hierarchy
    if idlerWindow then
      local craftPanel = idlerWindow:getChildById('craftPanel')
      if craftPanel then
        local balancePanel = craftPanel:getChildById('balancePanel')
        if balancePanel then
          local playerMoney = balancePanel:getChildById('playerMoney')
          if playerMoney then
            playerMoney:setText(formattedBankBalance)
          end
        end
        
        -- Show a success message (but don't overwrite important messages)
        local statusLabel = craftPanel:getChildById('statusLabel')
        if statusLabel then
          local currentText = statusLabel:getText()
          if not string.find(currentText, "Reward claimed:") then
            statusLabel:setText("Balance updated!")
            statusLabel:setColor("#00FF00")
          end
        end
      end
    end

    -- Update the upgrade button state - this now uses the correct hierarchy
    updateUpgradeButton()
  -- Handle result of getting 1 gold coin
  elseif data.action == "gold_coin_result" then
    local statusLabel = idlerWindow and safeGetElement(idlerWindow:getChildById('craftPanel'), 'statusLabel')
    if statusLabel then
      if data.success then
        local amount = data.amount or 1
        statusLabel:setText("Received " .. amount .. " gold coin" .. (amount > 1 and "s" or "") .. "!")
        statusLabel:setColor("#00FF00")
        
        -- Request updated gold balance
        requestGoldStatus()
      else
        statusLabel:setText("Failed: " .. data.message)
        statusLabel:setColor("#FF0000")
      end
    end
  -- Handle result of click upgrade
  elseif data.action == "upgrade_click_result" then
    local statusLabel = idlerWindow and safeGetElement(idlerWindow:getChildById('craftPanel'), 'statusLabel')
    
    if data.success then
      -- Update click value
      clickValue = data.new_value or clickValue + 1
      
      -- Update gold button text
      if idlerWindow then
        local buttonPanel = idlerWindow:getChildById('buttonPanel')
        if buttonPanel then
          local goldButton = buttonPanel:getChildById('goldButton')
          if goldButton then
            goldButton:setText("Get " .. clickValue .. " Gold")
          end
        end
      end
      
      -- Update click value display using correct hierarchy
      if idlerWindow then
        local craftPanel = idlerWindow:getChildById('craftPanel')
        if craftPanel then
          local infoPanel = craftPanel:getChildById('infoPanel')
          if infoPanel then
            local currentClickPanel = infoPanel:getChildById('currentClickPanel')
            if currentClickPanel then
              local clickValueLabel = currentClickPanel:getChildById('clickValueLabel')
              if clickValueLabel then
                clickValueLabel:setText("Value: " .. clickValue .. " per click")
              end
            end
          end
        end
      end
      
      -- Show success message
      if statusLabel then
        statusLabel:setText("Click upgraded to " .. clickValue .. " gold!")
        statusLabel:setColor("#00FF00")
      end
      
      -- Request updated gold balance
      requestGoldStatus()
    else
      -- Show error message
      if statusLabel then
        statusLabel:setText("Upgrade failed: " .. (data.message or "Unknown error"))
        statusLabel:setColor("#FF0000")
      end
    end
  end
end

-- Format number with commas
function comma_value(n)
  local left, num, right = string.match(n, "^([^%d]*%d)(%d*)(.-)$")
  return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

-- Toggle the window visibility
function toggle()
  g_logger.info("Toggle function called!")
  
  if not idlerWindow then
    g_logger.error("Cannot toggle: idlerWindow is nil!")
    return
  end
  
  if idlerWindow:isVisible() then
    g_logger.info("Window is visible, hiding...")
    return hide()
  end
  
  g_logger.info("Window is hidden, showing...")
  show()
end

-- Show the window
function show()
  g_logger.info("Show function called!")
  
  if not idlerWindow then
    g_logger.error("Cannot show: idlerWindow is nil!")
    return
  end
  
  if not idlerButton then
    g_logger.error("Cannot show: idlerButton is nil!")
    return
  end
  
  -- Position the window in the center of the screen
  local gameUi = modules.game_interface.getMapPanel():getParent()
  local gameWidth, gameHeight = gameUi:getWidth(), gameUi:getHeight()
  local windowWidth, windowHeight = idlerWindow:getWidth(), idlerWindow:getHeight()
  
  local x = (gameWidth - windowWidth) / 2
  local y = (gameHeight - windowHeight) / 2
  
  idlerWindow:setPosition({x = x, y = y})
  g_logger.info("Window positioned at x=" .. x .. ", y=" .. y)

  idlerWindow:show()
  idlerWindow:raise()
  idlerWindow:focus()
  
  -- Always reset timer display to checking state first
  local timerDisplay = idlerWindow and safeGetElement(idlerWindow:getChildById('craftPanel'), 'timerDisplay')
  if timerDisplay then
    timerDisplay:setText("Checking...")
    timerDisplay:setColor("#FFFFFF")
  end
  
  -- Request latest timer status when window is shown
  requestTimerStatus()
  
  -- Request latest gold balance when window is shown
  requestGoldStatus()
  
  g_logger.info("Window shown!")
end

-- Hide the window
function hide()
  g_logger.info("Hide function called!")
  
  if not idlerWindow then
    g_logger.error("Cannot hide: idlerWindow is nil!")
    return
  end
  
  idlerWindow:hide()
  g_logger.info("Window hidden!")
end

-- Claim the reward
function claimReward()
  g_logger.info("Claim reward button clicked!")
  
  -- Check cooldown
  local currentTime = os.time()
  local timeElapsed = currentTime - lastClaimTime
  
  if timeElapsed < CLAIM_COOLDOWN then
    -- Still on cooldown
    local remainingTime = CLAIM_COOLDOWN - timeElapsed
    g_logger.info("Still on cooldown: " .. remainingTime .. " seconds remaining")
    
    -- Update UI to show remaining time
    local statusLabel = idlerWindow and safeGetElement(idlerWindow:getChildById('craftPanel'), 'statusLabel')
    local timerDisplay = idlerWindow and safeGetElement(idlerWindow:getChildById('craftPanel'), 'timerDisplay')
    
    if statusLabel then
      statusLabel:setText("Please wait before claiming again")
      statusLabel:setColor("#FF9900")
    end
    
    if timerDisplay then
      local minutes = math.floor(remainingTime / 60)
      local seconds = remainingTime % 60
      timerDisplay:setText(string.format("%d:%02d", minutes, seconds))
      timerDisplay:setColor("#FF9900")
    end
    return
  end
  
  -- Send claim request to server
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    -- Send the request first to prevent delay
    protocolGame:sendExtendedOpcode(OPCODE, json.encode({action = "claim_reward"}))
    
    -- Update UI to show we're processing
    local statusLabel = idlerWindow and safeGetElement(idlerWindow:getChildById('craftPanel'), 'statusLabel')
    if statusLabel then
      statusLabel:setText("Processing reward claim...")
      statusLabel:setColor("#FFFFFF")
    end
    
    -- Reset the timer display to processing
    local timerDisplay = idlerWindow and safeGetElement(idlerWindow:getChildById('craftPanel'), 'timerDisplay')
    if timerDisplay then
      timerDisplay:setText("Wait...")
      timerDisplay:setColor("#FFFFFF")
    end
    
    -- Request a timer update immediately after the request
    scheduleEvent(function()
      requestTimerStatus()
    end, 500)
  else
    g_logger.error("Failed to get protocol game!")
  end
end

-- Start one-second update timer for the countdown
function startUpdateTimer()
  -- Clear any existing timer first
  stopUpdateTimer()
  
  -- Create a new update timer that fires every second
  updateEvent = scheduleEvent(function()
    updateCountdown()
    -- Reschedule the event to run again in 1 second
    startUpdateTimer()
  end, 1000)
end

-- Stop the update timer
function stopUpdateTimer()
  if updateEvent then
    removeEvent(updateEvent)
    updateEvent = nil
  end
end

-- Update the countdown display
function updateCountdown()
  if not idlerWindow or not idlerWindow:isVisible() then
    return
  end
  
  -- Get UI elements
  local rewardButton = safeGetElement(idlerWindow:getChildById('buttonPanel'), 'rewardButton')
  local timerDisplay = safeGetElement(idlerWindow:getChildById('craftPanel'), 'timerDisplay')
  local statusLabel = safeGetElement(idlerWindow:getChildById('craftPanel'), 'statusLabel')
  
  if not timerDisplay then
    g_logger.error("Timer display not found!")
    return
  end
  
  if not rewardButton then
    g_logger.error("Reward button not found!")
    return
  end
  
  -- Calculate time elapsed since last claim
  local currentTime = os.time()
  local elapsedTime = currentTime - lastClaimTime
  local remainingTime = math.max(0, CLAIM_COOLDOWN - elapsedTime)
  
  -- Update UI based on cooldown state
  if remainingTime > 0 and lastClaimTime > 0 then  -- Only update if we have a valid last claim time
    -- Still in cooldown
    rewardButton:setEnabled(false)
    local minutes = math.floor(remainingTime / 60)
    local seconds = remainingTime % 60
    
    -- Only update the timer display if it's not in "Checking..." or "Wait..." state
    local currentText = timerDisplay:getText()
    if currentText ~= "Checking..." and currentText ~= "Wait..." then
      timerDisplay:setText(string.format("%d:%02d", minutes, seconds))
      timerDisplay:setColor("#FF9900")
    end
    
    -- Don't overwrite important status messages
    if statusLabel and (statusLabel:getText() == "Checking reward status..." or 
                        statusLabel:getText() == "Welcome to Idle Rewards" or
                        statusLabel:getText() == "Reward is ready to claim!") then
      statusLabel:setText("Waiting for next reward...")
      statusLabel:setColor("#FF9900")
    end
  elseif lastClaimTime == 0 then
    -- If lastClaimTime is 0, we're either freshly logged in or timer was reset
    -- Don't update anything, wait for server to tell us the status
    return
  else
    -- Cooldown expired, ready to claim
    rewardButton:setEnabled(true)
    
    -- Only update if not in special states
    local currentText = timerDisplay:getText()
    if currentText ~= "Checking..." and currentText ~= "Wait..." then
      timerDisplay:setText("Ready!")
      timerDisplay:setColor("#00FF00")
    end
    
    -- Don't overwrite important status messages
    if statusLabel and (statusLabel:getText() == "Checking reward status..." or 
                        statusLabel:getText() == "Welcome to Idle Rewards" or
                        statusLabel:getText() == "Waiting for next reward...") then
      statusLabel:setText("Reward is ready to claim!")
      statusLabel:setColor("#00FF00")
    end
  end
end