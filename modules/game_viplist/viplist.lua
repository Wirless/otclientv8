vipWindow = nil
vipButton = nil
addVipWindow = nil
editVipWindow = nil
addGroupWindow = nil
vipInfo = {}
vipGroups = {}
currentCharacter = nil

function init()
  connect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd,
    onAddVip = onAddVip,
    onVipStateChange = onVipStateChange,
    onLogin = onLogin  
  })

  Keybind.new("Windows", "Toggle VIP list", "Ctrl+P", "")
  Keybind.bind("Windows", "Toggle VIP list", {
    {
      type = KEY_DOWN,
      callback = toggle,
    }
  })

  vipButton = modules.client_topmenu.addRightGameToggleButton('vipListButton', tr('VIP List') .. ' (Ctrl+P)', '/images/topbuttons/viplist', toggle, false, 3)
  vipButton:setOn(true)
  vipWindow = g_ui.loadUI('viplist', modules.game_interface.getRightPanel())

  if not g_game.getFeature(GameAdditionalVipInfo) then
    loadVipInfo()
  end
  
  refresh()
  vipWindow:setup()
end

function terminate()
  Keybind.delete("Windows", "Toggle VIP list")

  disconnect(g_game, {
    onGameStart = onGameStart,
    onGameEnd = onGameEnd,
    onAddVip = onAddVip,
    onVipStateChange = onVipStateChange,
    onLogin = onLogin
  })

  if not g_game.getFeature(GameAdditionalVipInfo) then
    saveVipInfo()
  end
  
  saveVipGroups()

  if addVipWindow then
    addVipWindow:destroy()
  end

  if editVipWindow then
    editVipWindow:destroy()
  end
  
  if addGroupWindow then
    addGroupWindow:destroy()
  end

  vipWindow:destroy()
  vipButton:destroy()
end

function onLogin(localPlayer, loginWidget)
  if localPlayer then
    currentCharacter = localPlayer:getName()
    loadVipGroups()
  end
end

function onGameStart()
  refresh()
end

function onGameEnd()
  saveVipGroups()
  clear()
end

function loadVipInfo()
  local settings = g_settings.getNode('VipList')
  if not settings then
    vipInfo = {}
    return
  end
  vipInfo = settings['VipInfo'] or {}
end

function saveVipInfo()
  settings = {}
  settings['VipInfo'] = vipInfo
  g_settings.mergeNode('VipList', settings)
end

function loadVipGroups()
  vipGroups = {}
  
  if not currentCharacter then
    local localPlayer = g_game.getLocalPlayer()
    if localPlayer then
      currentCharacter = localPlayer:getName()
    else
      return
    end
  end
  
  local file = io.open("viplist_" .. currentCharacter .. ".txt", "r")
  if not file then
    return
  end
  
  for line in file:lines() do
    local groupName, vipName = line:match("^GROUP:(.+),VIP:(.+)$")
    if groupName and vipName then
      if not vipGroups[groupName] then
        vipGroups[groupName] = {}
      end
      table.insert(vipGroups[groupName], vipName)
    end
  end
  
  file:close()
  refreshGroups()
end

function saveVipGroups()
  if not currentCharacter then
    local localPlayer = g_game.getLocalPlayer()
    if localPlayer then
      currentCharacter = localPlayer:getName()
    else
      return
    end
  end
  
  local file = io.open("viplist_" .. currentCharacter .. ".txt", "w")
  if not file then
    return
  end
  
  for groupName, vips in pairs(vipGroups) do
    for _, vipName in ipairs(vips) do
      file:write("GROUP:" .. groupName .. ",VIP:" .. vipName .. "\n")
    end
  end
  
  file:close()
end

function refresh()
  clear()
  refreshGroups()
  
  for id, vip in pairs(g_game.getVips()) do
    onAddVip(id, unpack(vip))
  end

  vipWindow:setContentMinimumHeight(38)
end

function refreshGroups()
  local vipList = vipWindow:getChildById('contentsPanel')
  
  -- Remove all group labels first
  local children = vipList:getChildren()
  for i = 1, #children do
    local child = children[i]
    if child:getId():find("^group_") then
      vipList:removeChild(child)
    end
  end
  
  -- Add all groups
  for groupName, _ in pairs(vipGroups) do
    addGroupLabel(groupName)
  end
end

function clear()
  local vipList = vipWindow:getChildById('contentsPanel')
  vipList:destroyChildren()
end

function toggle()
  if vipButton:isOn() then
    vipWindow:close()
    vipButton:setOn(false)
  else
    vipWindow:open()
    vipButton:setOn(true)
  end
end

function onMiniWindowClose()
  vipButton:setOn(false)
end

function createAddWindow()
  if not addVipWindow then
    addVipWindow = g_ui.displayUI('addvip')
  end
end

function createAddGroupWindow()
  if not addGroupWindow then
    addGroupWindow = g_ui.displayUI('addgroup')
  end
end

function createEditWindow(widget)
  if editVipWindow then
    return
  end

  editVipWindow = g_ui.displayUI('editvip')

  local name = widget:getText()
  local id = widget:getId():sub(4)

  local okButton = editVipWindow:getChildById('buttonOK')
  local cancelButton = editVipWindow:getChildById('buttonCancel')

  local nameLabel = editVipWindow:getChildById('nameLabel')
  nameLabel:setText(name)

  local descriptionText = editVipWindow:getChildById('descriptionText')
  descriptionText:appendText(widget:getTooltip())

  local notifyCheckBox = editVipWindow:getChildById('checkBoxNotify')
  notifyCheckBox:setChecked(widget.notifyLogin)

  local iconRadioGroup = UIRadioGroup.create()
  for i = VipIconFirst, VipIconLast do
    iconRadioGroup:addWidget(editVipWindow:recursiveGetChildById('icon' .. i))
  end
  iconRadioGroup:selectWidget(editVipWindow:recursiveGetChildById('icon' .. widget.iconId))

  local cancelFunction = function()
    editVipWindow:destroy()
    iconRadioGroup:destroy()
    editVipWindow = nil
  end

  local saveFunction = function()
    local vipList = vipWindow:getChildById('contentsPanel')
    if not widget or not vipList:hasChild(widget) then
      cancelFunction()
      return
    end

    local name = widget:getText()
    local state = widget.vipState
    local description = descriptionText:getText()
    local iconId = tonumber(iconRadioGroup:getSelectedWidget():getId():sub(5))
    local notify = notifyCheckBox:isChecked()

    if g_game.getFeature(GameAdditionalVipInfo) then
      g_game.editVip(id, description, iconId, notify)
    else
      if notify ~= false or #description > 0 or iconId > 0 then
        vipInfo[id] = {description = description, iconId = iconId, notifyLogin = notify}
      else
        vipInfo[id] = nil
      end
    end

    widget:destroy()
    onAddVip(id, name, state, description, iconId, notify)

    editVipWindow:destroy()
    iconRadioGroup:destroy()
    editVipWindow = nil
  end

  cancelButton.onClick = cancelFunction
  okButton.onClick = saveFunction

  editVipWindow.onEscape = cancelFunction
  editVipWindow.onEnter = saveFunction
end

function destroyAddWindow()
  addVipWindow:destroy()
  addVipWindow = nil
end

function destroyAddGroupWindow()
  addGroupWindow:destroy()
  addGroupWindow = nil
end

function addVip()
  g_game.addVip(addVipWindow:getChildById('name'):getText())
  destroyAddWindow()
end

function addGroup()
  local groupName = addGroupWindow:getChildById('groupName'):getText()
  if groupName and groupName:len() > 0 then
    if not vipGroups[groupName] then
      vipGroups[groupName] = {}
      addGroupLabel(groupName)
      saveVipGroups()
    end
  end
  destroyAddGroupWindow()
end

function addGroupLabel(groupName)
  local vipList = vipWindow:getChildById('contentsPanel')
  
  -- Create the group label
  local label = g_ui.createWidget('VipGroupLabel')
  label:setId('group_' .. groupName)
  label:setText(groupName)
  label.onMousePress = onVipGroupLabelMousePress
  label:setDraggable(false)
  
  -- Insert at appropriate position (groups should be at the top)
  local inserted = false
  for i = 1, vipList:getChildCount() do
    local child = vipList:getChildByIndex(i)
    if not child:getId():find("^group_") then
      vipList:insertChild(i, label)
      inserted = true
      break
    end
  end
  
  if not inserted then
    vipList:addChild(label)
  end
  
  return label
end

function removeGroup(groupName)
  if not vipGroups[groupName] then
    return
  end
  
  vipGroups[groupName] = nil
  
  local vipList = vipWindow:getChildById('contentsPanel')
  local groupLabel = vipList:getChildById('group_' .. groupName)
  if groupLabel then
    vipList:removeChild(groupLabel)
  end
  
  saveVipGroups()
  refresh()
end

function removeVip(widgetOrName)
  if not widgetOrName then
    return
  end

  local widget
  local vipList = vipWindow:getChildById('contentsPanel')
  if type(widgetOrName) == 'string' then
    local entries = vipList:getChildren()
    for i = 1, #entries do
      if entries[i]:getText():lower() == widgetOrName:lower() then
        widget = entries[i]
        break
      end
    end
    if not widget then
      return
    end
  else
    widget = widgetOrName
  end

  if widget then
    local id = widget:getId():sub(4)
    local name = widget:getText()
    
    -- Remove from any groups if present
    for groupName, vips in pairs(vipGroups) do
      for i, vipName in ipairs(vips) do
        if vipName == name then
          table.remove(vipGroups[groupName], i)
          break
        end
      end
    end
    
    g_game.removeVip(id)
    vipList:removeChild(widget)
    if vipInfo[id] and g_game.getFeature(GameAdditionalVipInfo) then
      vipInfo[id] = nil
    end
    
    saveVipGroups()
  end
end

function addVipToGroup(vipName, groupName)
  if not vipGroups[groupName] then
    vipGroups[groupName] = {}
  end
  
  -- Check if already in the group
  for _, name in ipairs(vipGroups[groupName]) do
    if name == vipName then
      return
    end
  end
  
  table.insert(vipGroups[groupName], vipName)
  saveVipGroups()
end

function removeVipFromGroup(vipName, groupName)
  if not vipGroups[groupName] then
    return
  end
  
  for i, name in ipairs(vipGroups[groupName]) do
    if name == vipName then
      table.remove(vipGroups[groupName], i)
      saveVipGroups()
      return
    end
  end
end

function hideOffline(state)
  settings = {}
  settings['hideOffline'] = state
  g_settings.mergeNode('VipList', settings)

  refresh()
end

function isHiddingOffline()
  local settings = g_settings.getNode('VipList')
  if not settings then
    return false
  end
  return settings['hideOffline']
end

function getSortedBy()
  local settings = g_settings.getNode('VipList')
  if not settings or not settings['sortedBy'] then
    return 'status'
  end
  return settings['sortedBy']
end

function sortBy(state)
  settings = {}
  settings['sortedBy'] = state
  g_settings.mergeNode('VipList', settings)

  refresh()
end

function onAddVip(id, name, state, description, iconId, notify)  
  if not name or name:len() == 0 then
    return
  end
  
  local vipList = vipWindow:getChildById('contentsPanel')
  local childrenCount = vipList:getChildCount()
  for i=1,childrenCount do
    local child = vipList:getChildByIndex(i)
    if child:getText() == name and not child:getId():find("^group_") then
      return -- don't add duplicated vips
    end
  end
  
  local label = g_ui.createWidget('VipListLabel')
  label.onMousePress = onVipListLabelMousePress
  label:setId('vip' .. id)
  label:setText(name)

  if not g_game.getFeature(GameAdditionalVipInfo) then
    local tmpVipInfo = vipInfo[tostring(id)]
    label.iconId = 0
    label.notifyLogin = false
    if tmpVipInfo then
      if tmpVipInfo.iconId then
        label:setImageClip(torect((tmpVipInfo.iconId * 12) .. ' 0 12 12'))
        label.iconId = tmpVipInfo.iconId
      end
      if tmpVipInfo.description then
        label:setTooltip(tmpVipInfo.description)
      end
      label.notifyLogin = tmpVipInfo.notifyLogin or false
    end
  else
    label:setTooltip(description)
    label:setImageClip(torect((iconId * 12) .. ' 0 12 12'))
    label.iconId = iconId
    label.notifyLogin = notify
  end

  if state == VipState.Online then
    label:setColor('#00ff00')
  elseif state == VipState.Pending then
    label:setColor('#ffca38')
  else
    label:setColor('#ff0000')
  end

  label.vipState = state

  label:setPhantom(false)
  connect(label, { onDoubleClick = function () g_game.openPrivateChannel(label:getText()) return true end } )

  if state == VipState.Offline and isHiddingOffline() then
    label:setVisible(false)
  end

  -- Check if this VIP belongs to a group
  local belongsToGroup = false
  for groupName, vips in pairs(vipGroups) do
    for _, vipName in ipairs(vips) do
      if vipName == name then
        belongsToGroup = true
        -- Insert below the appropriate group
        local groupWidget = vipList:getChildById('group_' .. groupName)
        if groupWidget then
          local index = vipList:getChildIndex(groupWidget)
          vipList:insertChild(index + 1, label)
          return
        end
      end
    end
  end
  
  -- If not in a group, add it normally based on sorting
  if not belongsToGroup then
    local nameLower = name:lower()
    local childrenCount = vipList:getChildCount()

    for i=1,childrenCount do
      local child = vipList:getChildByIndex(i)
      -- Skip group labels in sorting
      if not child:getId():find("^group_") then
        if (state == VipState.Online and child.vipState ~= VipState.Online and getSortedBy() == 'status')
            or (label.iconId > child.iconId and getSortedBy() == 'type') then
          vipList:insertChild(i, label)
          return
        end

        if (((state ~= VipState.Online and child.vipState ~= VipState.Online) or (state == VipState.Online and child.vipState == VipState.Online)) and getSortedBy() == 'status')
            or (label.iconId == child.iconId and getSortedBy() == 'type') or getSortedBy() == 'name' then

          local childText = child:getText():lower()
          local length = math.min(childText:len(), nameLower:len())

          for j=1,length do
            if nameLower:byte(j) < childText:byte(j) then
              vipList:insertChild(i, label)
              return
            elseif nameLower:byte(j) > childText:byte(j) then
              break
            elseif j == nameLower:len() then -- We are at the end of nameLower, and its shorter than childText, thus insert before
              vipList:insertChild(i, label)
              return
            end
          end
        end
      end
    end
  end

  vipList:insertChild(childrenCount+1, label)
end

function onVipStateChange(id, state)
  local vipList = vipWindow:getChildById('contentsPanel')
  local label = vipList:getChildById('vip' .. id)
  if not label then
    return
  end
  local name = label:getText()
  local description = label:getTooltip()
  local iconId = label.iconId
  local notify = label.notifyLogin
  label:destroy()

  onAddVip(id, name, state, description, iconId, notify)

  if notify and state ~= VipState.Pending then
    modules.game_textmessage.displayFailureMessage(tr('%s has logged %s.', name, (state == VipState.Online and 'in' or 'out')))
  end
end

function onVipListMousePress(widget, mousePos, mouseButton)
  if mouseButton ~= MouseRightButton then return end

  local vipList = vipWindow:getChildById('contentsPanel')

  local menu = g_ui.createWidget('PopupMenu')
  menu:setGameMenu(true)
  menu:addOption(tr('Add new VIP'), function() createAddWindow() end)
  menu:addOption(tr('Add new Group'), function() createAddGroupWindow() end)

  menu:addSeparator()
  if not isHiddingOffline() then
    menu:addOption(tr('Hide Offline'), function() hideOffline(true) end)
  else
    menu:addOption(tr('Show Offline'), function() hideOffline(false) end)
  end

  if not(getSortedBy() == 'name') then
    menu:addOption(tr('Sort by name'), function() sortBy('name') end)
  end

  if not(getSortedBy() == 'status') then
    menu:addOption(tr('Sort by status'), function() sortBy('status') end)
  end

  if not(getSortedBy() == 'type') then
    menu:addOption(tr('Sort by type'), function() sortBy('type') end)
  end

  menu:display(mousePos)

  return true
end

function onVipGroupLabelMousePress(widget, mousePos, mouseButton)
  if mouseButton ~= MouseRightButton then return end
  
  local groupName = widget:getText()

  local menu = g_ui.createWidget('PopupMenu')
  menu:setGameMenu(true)
  menu:addOption(tr('Add new VIP'), function() createAddWindow() end)
  menu:addOption(tr('Add new Group'), function() createAddGroupWindow() end)
  menu:addSeparator()
  menu:addOption(tr('Remove Group'), function() removeGroup(groupName) end)
  menu:addSeparator()
  if not isHiddingOffline() then
    menu:addOption(tr('Hide Offline'), function() hideOffline(true) end)
  else
    menu:addOption(tr('Show Offline'), function() hideOffline(false) end)
  end

  menu:display(mousePos)

  return true
end

function onVipListLabelMousePress(widget, mousePos, mouseButton)
  if mouseButton ~= MouseRightButton then return end

  local vipList = vipWindow:getChildById('contentsPanel')
  local name = widget:getText()

  local menu = g_ui.createWidget('PopupMenu')
  menu:setGameMenu(true)
  menu:addOption(tr('Send Message'), function() g_game.openPrivateChannel(name) end)
  menu:addOption(tr('Add new VIP'), function() createAddWindow() end)
  menu:addOption(tr('Add new Group'), function() createAddGroupWindow() end)
  menu:addOption(tr('Edit %s', name), function() if widget then createEditWindow(widget) end end)
  menu:addOption(tr('Remove %s', name), function() if widget then removeVip(widget) end end)
  menu:addSeparator()
  
  -- Group management submenu
  local groupSubmenu = menu:addSubmenu(tr('Group Management'))
  
  -- Add to group
  for groupName, _ in pairs(vipGroups) do
    -- Check if the VIP is already in this group
    local isInGroup = false
    if vipGroups[groupName] then
      for _, vipName in ipairs(vipGroups[groupName]) do
        if vipName == name then
          isInGroup = true
          break
        end
      end
    end
    
    -- Only show groups the VIP is not already in
    if not isInGroup then
      groupSubmenu:addOption(tr('Add to "%s"', groupName), function() 
        addVipToGroup(name, groupName)
        refresh()
      end)
    end
  end
  
  -- Remove from groups
  local belongsToGroups = {}
  for groupName, vips in pairs(vipGroups) do
    for _, vipName in ipairs(vips) do
      if vipName == name then
        table.insert(belongsToGroups, groupName)
      end
    end
  end
  
  if #belongsToGroups > 0 then
    for _, groupName in ipairs(belongsToGroups) do
      groupSubmenu:addOption(tr('Remove from "%s"', groupName), function() 
        removeVipFromGroup(name, groupName)
        refresh()
      end)
    end
  end
  
  menu:addSeparator()
  menu:addOption(tr('Copy Name'), function() g_window.setClipboardText(name) end)

  if modules.game_console.getOwnPrivateTab() then
    menu:addSeparator()
    menu:addOption(tr('Invite to private chat'), function() g_game.inviteToOwnChannel(name) end)
    menu:addOption(tr('Exclude from private chat'), function() g_game.excludeFromOwnChannel(name) end)
  end

  if not isHiddingOffline() then
    menu:addOption(tr('Hide Offline'), function() hideOffline(true) end)
  else
    menu:addOption(tr('Show Offline'), function() hideOffline(false) end)
  end

  if not(getSortedBy() == 'name') then
    menu:addOption(tr('Sort by name'), function() sortBy('name') end)
  end

  if not(getSortedBy() == 'status') then
    menu:addOption(tr('Sort by status'), function() sortBy('status') end)
  end

  menu:display(mousePos)

  return true
end
