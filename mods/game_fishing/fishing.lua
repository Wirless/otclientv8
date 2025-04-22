-- Fishing Module
-- Implements a fishing minigame with a sliding bar interface

-- Configuration
local FISHING_OPCODE = 103 -- Unique opcode for fishing communication
local BAR_WIDTH = 400 -- Width of the fishing bar in pixels
local GREEN_ZONE_WIDTH = 20 -- Width of the success zone in pixels
local SLIDER_SPEED = 2 -- Reduced speed for smoother animation
local SLIDER_WIDTH = 4 -- Width of the slider indicator
local UPDATE_INTERVAL = 16 -- Aiming for 60 FPS (16ms between frames)

-- Module variables
local fishingWindow = nil
local sliderPosition = 0
local sliderDirection = 1
local greenZonePosition = 0
local fishingActive = false
local updateEvent = nil
local debugMode = true -- Enable to show debug messages

-- Debug log function
function debugLog(message)
  if debugMode and message then
    g_logger.debug("[Fishing] " .. message)
    -- Also print to console for immediate visibility
    print("[Fishing] " .. message)
  end
end

-- Initialize the module
function init()
  connect(g_game, {
    onGameStart = create,
    onGameEnd = destroy,
    onKeyDown = handleKeyDown
  })

  -- Register the opcode handler for server communications
  ProtocolGame.registerExtendedOpcode(FISHING_OPCODE, onExtendedOpcode)
  
  -- Handle text messages to prevent errors
  connect(g_game, { onTextMessage = handleTextMessage })
  
  -- Initialize if already logged in
  if g_game.isOnline() then
    create()
  end
  
  debugLog("Fishing module initialized")
end

-- Handler for text messages (to prevent errors)
function handleTextMessage(mode, text)
  -- Only handle fishing related messages to prevent errors in log
  if string.find(text, "fish") or string.find(text, "worm") then
    debugLog("Captured fishing text message: " .. text)
    return true -- This prevents "unhandled" errors
  end
  return false -- Let other handlers process it
end

-- Clean up when module unloads
function terminate()
  disconnect(g_game, {
    onGameStart = create,
    onGameEnd = destroy,
    onKeyDown = handleKeyDown,
    onTextMessage = handleTextMessage
  })

  -- Unregister the opcode
  ProtocolGame.unregisterExtendedOpcode(FISHING_OPCODE)

  -- Clean up
  destroy()
  
  debugLog("Fishing module terminated")
end

-- Create interface elements
function create()
  -- Nothing to create until fishing window is opened
  debugLog("Game started, waiting for fishing window request")
end

-- Clean up interface
function destroy()
  -- Stop fishing if active
  stopFishing()
  
  -- Destroy window if it exists
  if fishingWindow then
    fishingWindow:destroy()
    fishingWindow = nil
    debugLog("Fishing window destroyed")
  end
end

-- Handle messages from server
function onExtendedOpcode(protocol, opcode, buffer)
  -- Verify this is our opcode
  if opcode ~= FISHING_OPCODE then
    return
  end
  
  -- Parse the message
  local json_status, json_data = pcall(function()
    return json.decode(buffer)
  end)
  
  if not json_status then
    g_logger.error("Fishing JSON error: " .. json_data)
    return
  end
  
  debugLog("Received message: " .. buffer)
  
  -- Process messages from server
  if json_data.action == "result" then
    showFishingResult(json_data.success, json_data.message)
  elseif json_data.action == "open" then
    -- Open the fishing window when server requests it
    openFishingWindow()
  end
end

-- Create and show the fishing window
function openFishingWindow()
  -- If window already exists, just show it
  if fishingWindow then
    fishingWindow:show()
    fishingWindow:raise()
    fishingWindow:focus()
    debugLog("Showing existing fishing window")
    return
  end
  
  debugLog("Creating fishing window")
  
  -- Create the fishing window using a simpler approach that should work in the client
  fishingWindow = g_ui.createWidget('MainWindow', modules.game_interface.getRootPanel())
  if not fishingWindow then
    g_logger.error("Failed to create fishing window")
    return
  end
  
  -- Configure the window
  fishingWindow:setId('fishingWindow')
  fishingWindow:setText('Fishing')
  fishingWindow:setSize({width = 450, height = 250})
  fishingWindow:setDraggable(true)
  
  -- Add title label
  local titleLabel = g_ui.createWidget('Label', fishingWindow)
  titleLabel:setId('titleLabel')
  titleLabel:setText('Fishing Minigame')
  titleLabel:setTextAlign(AlignCenter)
  titleLabel:addAnchor(AnchorTop, 'parent', AnchorTop)
  titleLabel:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
  titleLabel:setMarginTop(10)
  
  -- Add instruction label
  local instructionLabel = g_ui.createWidget('Label', fishingWindow)
  instructionLabel:setId('instructionLabel')
  instructionLabel:setText('Press SPACEBAR when the slider is in the green zone')
  instructionLabel:setTextAlign(AlignCenter)
  instructionLabel:addAnchor(AnchorTop, 'titleLabel', AnchorBottom)
  instructionLabel:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
  instructionLabel:setMarginTop(10)
  
  -- Create fishing bar with very simple implementation
  -- First create a base red bar
  local redBar = g_ui.createWidget('UIWidget', fishingWindow)
  redBar:setId('redBar')
  redBar:setBackgroundColor('#FF2222')
  redBar:setSize({width = BAR_WIDTH, height = 30})
  redBar:addAnchor(AnchorTop, 'instructionLabel', AnchorBottom)
  redBar:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
  redBar:setMarginTop(20)
  
  -- Add result label
  local resultLabel = g_ui.createWidget('Label', fishingWindow)
  resultLabel:setId('resultLabel')
  resultLabel:setText('Ready to fish!')
  resultLabel:setTextAlign(AlignCenter)
  resultLabel:addAnchor(AnchorTop, 'redBar', AnchorBottom)
  resultLabel:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
  resultLabel:setMarginTop(15)
  
  -- Debug position label
  if debugMode then
    local debugLabel = g_ui.createWidget('Label', fishingWindow)
    debugLabel:setId('debugLabel')
    debugLabel:setText('Position: 0')
    debugLabel:setTextAlign(AlignCenter)
    debugLabel:addAnchor(AnchorTop, 'resultLabel', AnchorBottom)
    debugLabel:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
    debugLabel:setMarginTop(5)
  end
  
  -- Add close button
  local closeButton = g_ui.createWidget('Button', fishingWindow)
  closeButton:setId('closeButton')
  closeButton:setText('Close')
  closeButton:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
  closeButton:addAnchor(AnchorBottom, 'parent', AnchorBottom)
  closeButton:setMarginBottom(10)
  closeButton:setWidth(90)
  closeButton.onClick = function() hide() end
  
  -- Position window using the parent panel
  local parent = fishingWindow:getParent()
  if parent then
    fishingWindow:setPosition({
      x = (parent:getWidth() - fishingWindow:getWidth()) / 2,
      y = (parent:getHeight() - fishingWindow:getHeight()) / 2
    })
  end
  
  -- Create the green zone and slider
  createGreenZone()
  createSlider()
  
  -- Show the window
  fishingWindow:show()
  fishingWindow:raise()
  fishingWindow:focus()
  
  -- Directly bind spacebar to this module
  g_keyboard.bindKeyDown('Space', onSpacePress)
  
  -- Start the minigame
  startFishing()
  
  debugLog("Fishing window created and minigame started")
end

-- Create the green zone
function createGreenZone()
  if not fishingWindow then return end
  
  -- Remove existing green zone if any
  local oldGreenZone = fishingWindow:getChildById('greenZone')
  if oldGreenZone then
    oldGreenZone:destroy()
  end
  
  -- Create new green zone at the specified position
  local greenZone = g_ui.createWidget('UIWidget', fishingWindow)
  greenZone:setId('greenZone')
  greenZone:setBackgroundColor('#22FF22')
  greenZone:setSize({width = GREEN_ZONE_WIDTH, height = 30})
  
  -- Position the green zone relative to the red bar
  local redBar = fishingWindow:getChildById('redBar')
  if redBar then
    local redBarPos = redBar:getPosition()
    greenZone:setPosition({
      x = redBarPos.x + greenZonePosition,
      y = redBarPos.y
    })
  end
  
  debugLog("Created green zone at position: " .. greenZonePosition)
end

-- Create or update the slider
function createSlider()
  if not fishingWindow then return end
  
  -- Remove existing slider if any
  local oldSlider = fishingWindow:getChildById('slider')
  if oldSlider then
    oldSlider:destroy()
  end
  
  -- Create new slider at the current position
  local slider = g_ui.createWidget('UIWidget', fishingWindow)
  slider:setId('slider')
  slider:setBackgroundColor('#FFFFFF')
  slider:setSize({width = SLIDER_WIDTH, height = 30})
  
  -- Position the slider relative to the red bar
  local redBar = fishingWindow:getChildById('redBar')
  if redBar then
    local redBarPos = redBar:getPosition()
    slider:setPosition({
      x = redBarPos.x + sliderPosition,
      y = redBarPos.y
    })
  end
  
  debugLog("Created slider at position: " .. sliderPosition)
end

-- Function for when spacebar is pressed
function onSpacePress()
  if not fishingActive or not fishingWindow or not fishingWindow:isVisible() then
    debugLog("Spacebar pressed but fishing not active")
    return false
  end
  
  -- Determine if slider is in green zone
  local success = isSliderInGreenZone()
  
  debugLog("Space pressed, success: " .. tostring(success) .. 
            ", slider at: " .. sliderPosition .. 
            ", green zone at: " .. greenZonePosition)
  
  -- Send result to server
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(FISHING_OPCODE, json.encode({
      action = "fish",
      success = success
    }))
    
    debugLog("Sent fishing action to server, success: " .. tostring(success))
  else
    debugLog("Could not send fish action, protocol game not available")
  end
  
  -- Stop the current fishing attempt
  stopFishing()
  
  -- Show a temporary message
  local resultLabel = fishingWindow:getChildById('resultLabel')
  if resultLabel then
    if success then
      resultLabel:setText("Nice catch! Waiting for server...")
      resultLabel:setColor('#00FF00')
    else
      resultLabel:setText("You missed! Waiting for server...")
      resultLabel:setColor('#FF0000')
    end
  end
  
  return true
end

-- Start the fishing minigame
function startFishing()
  -- Reset variables
  sliderPosition = 0
  sliderDirection = 1
  
  -- Generate random position for green zone
  greenZonePosition = math.random(50, BAR_WIDTH - GREEN_ZONE_WIDTH - 50)
  
  debugLog("Starting fishing minigame, green zone at: " .. greenZonePosition)
  
  -- Create green zone at the new position
  createGreenZone()
  
  -- Update the slider position
  createSlider()
  
  -- Start the slider movement
  fishingActive = true
  
  -- Start the update loop - using standard scheduleEvent
  scheduleEvent(function() updateSlider() end, UPDATE_INTERVAL)
  
  debugLog("Started fishing minigame")
end

-- Stop the fishing minigame
function stopFishing()
  fishingActive = false
  debugLog("Stopped fishing minigame")
end

-- Update the slider position
function updateSlider()
  -- Don't continue if fishing is not active
  if not fishingActive or not fishingWindow then
    debugLog("Update slider canceled - fishing not active")
    return
  end
  
  -- Move the slider
  sliderPosition = sliderPosition + (SLIDER_SPEED * sliderDirection)
  
  -- Bounce at edges - ensure we stay within bounds
  if sliderPosition >= BAR_WIDTH - SLIDER_WIDTH then
    sliderPosition = BAR_WIDTH - SLIDER_WIDTH
    sliderDirection = -1
    debugLog("Slider hit right edge, changing direction")
  elseif sliderPosition <= 0 then
    sliderPosition = 0
    sliderDirection = 1
    debugLog("Slider hit left edge, changing direction")
  end
  
  -- Update the slider position
  local redBar = fishingWindow:getChildById('redBar')
  local slider = fishingWindow:getChildById('slider')
  
  if redBar and slider then
    local redBarPos = redBar:getPosition()
    slider:setPosition({
      x = redBarPos.x + sliderPosition,
      y = redBarPos.y
    })
  else
    debugLog("Could not update slider - elements not found")
  end
  
  -- Update debug label if in debug mode
  if debugMode then
    local debugLabel = fishingWindow:getChildById('debugLabel')
    if debugLabel then
      debugLabel:setText('Slider: ' .. sliderPosition .. ', Green: ' .. greenZonePosition)
    end
  end
  
  -- If still active, schedule next update using the correct format for scheduleEvent
  if fishingActive then
    scheduleEvent(function() updateSlider() end, UPDATE_INTERVAL)
  end
end

-- Check if slider is in the green zone
function isSliderInGreenZone()
  local inZone = sliderPosition >= greenZonePosition and 
                 sliderPosition <= greenZonePosition + GREEN_ZONE_WIDTH
  debugLog("Checking green zone: " .. tostring(inZone) .. 
           " (slider=" .. sliderPosition .. 
           ", green=" .. greenZonePosition .. 
           "-" .. (greenZonePosition + GREEN_ZONE_WIDTH) .. ")")
  return inZone
end

-- Show the result of fishing
function showFishingResult(success, message)
  if not fishingWindow then
    debugLog("Cannot show result, fishing window does not exist")
    return
  end
  
  debugLog("Showing fishing result: " .. tostring(success) .. ", " .. message)
  
  -- Display result message
  local resultLabel = fishingWindow:getChildById('resultLabel')
  if resultLabel then
    resultLabel:setText(message)
    
    -- Color based on success/failure
    if success then
      resultLabel:setColor('#00FF00') -- Green for success
    else
      resultLabel:setColor('#FF0000') -- Red for failure
    end
  else
    debugLog("Could not find result label")
  end
  
  -- Restart the minigame after a brief delay
  scheduleEvent(startFishing, 2000)
  debugLog("Scheduled restart of fishing minigame in 2 seconds")
end

-- Function to hide the window
function hide()
  if fishingWindow then
    -- Unbind keyboard when closing
    g_keyboard.unbindKeyDown('Space')
    
    fishingWindow:hide()
    stopFishing()
    debugLog("Fishing window hidden")
  end
end

-- Handle keypresses
function handleKeyDown(self, keyCode, keyChar, keyboardModifiers)
  -- Only process if fishing is active
  if not fishingActive or not fishingWindow or not fishingWindow:isVisible() then
    return false
  end
  
  -- Check for spacebar (keyCode 32)
  if keyCode == 32 then
    debugLog("Spacebar keypress detected in handleKeyDown")
    return onSpacePress()
  end
  
  -- Let other handlers process the key
  return false
end 