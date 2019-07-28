-- TomPoints.lua
-- Parses chat channels for X,Y coordinate locations to create TomTom waypoints.
-- Heavily patterned off the ClickLinks addon.

-- US/British-style (period decimal delimeter, optionally separated by a comma)
local PATTERNS_US_BRITISH = {
    "((%d+(%.?%d*))%s*,+%s*(%d+(%.?%d*)))", -- has a comma
    "((%d+(%.?%d*))%s+(%d+(%.?%d*)))",      -- no comma, just at least a space
}
-- European-style (comma decimal delimeter, optionally separated by a period?)
local PATTERNS_EURO = {
    "((%d+(%,?%d*))%s*%.+%s*(%d+(%,?%d*)))", -- has a period
    "((%d+(%,?%d*))%s+(%d+(%,?%d*)))",      -- no period, just at least a space
}

local STR_US_BRITISH = "TomPoints is currently parsing US/British-style number formats for waypoints. This means that decimals are denoted by a period like: (23.45, 45.56)";
local STR_EURO = "TomPoints is currently parsing European-style number formats for waypoints. This means that decimals are denoted by a comma like (23,45 45,56)";

-- Default to US/British-style
local PATTERNS = PATTERNS_US_BRITISH;

local LINK_PATTERN = "[^|]|c.-|h|r";
local iconNumber = 52294;
-- addTomTomWaypoint
-- Helper function to add the waypoint in TomTom
-- coordXFromLink - The X coordinate from the link, this is not in units that TomTom expects.
-- coordYFromLink - The Y coordinate from the link, this is not in units that TomTom expects.
-- TODO: a custom icon would be nice to distinguish from normal waypoints, since these may be temporal in nature, like rares in Nazjatar, Mechagon, etc.
local function addTomTomWaypoint(coordXFromLink, coordYFromLink, text)
  if (TomTom) then
    TomTom:AddWaypoint(C_Map.GetBestMapForUnit("player"), tonumber(coordXFromLink)/100, tonumber(coordYFromLink)/100, {
      title = "TomPoints - " .. date("%H:%M").. " - " .. text,
      persistent = nil,
      minimap = true,
      world = true,
      minimap_displayID = iconNumber,
      worldmap_displayID = iconNumber
    })
  else
    print "TomTom not loaded!"
  end
end

-- Arguments are in decimal format, for European-style, it needs to be converted to the opposite.
local function doChatInsert(x, y)
  if (TomPoints_EuropeanDecimalFormat) then
    local euroX = x:gsub("%.", ",");
    local euroY = y:gsub("%.", ",");
    return ChatEdit_InsertLink(" " .. euroX .. " " .. euroY .. " ");
  else
    return ChatEdit_InsertLink(" " .. x .. ", " .. y .. " ")
  end
end

local SetItemRef_orig = SetItemRef;
-- TomPoints_SetItemRef
-- Handles when the user clicks on the link
local function TomPoints_SetItemRef(link, text, button)
    -- print("link: " .. link .. " text: " .. text .. " button: " .. button);
    if (string.sub(link, 1, 4) == "tpx:") then
        local x, y = strmatch(link, "tpx:(%d+%.%d+)tpy:(%d+%.%d+)")
        if (x and y) then
          -- If the person is trying to link the waypoint like it's an achievement, attempt to add to chat
          -- Otherwise, add the waypoint like normal if the chat edit area isn't open (maybe the shift was down by accident)

          if IsModifiedClick("CHATLINK") and doChatInsert(x,y) then
            -- print("modified click");
          else
            addTomTomWaypoint(x, y, text);
          end
        -- print ("Attempted to add waypoint to " .. tonumber(x) .. "," .. tonumber(y) .. " for map: " .. C_Map.GetMapInfo(C_Map.GetBestMapForUnit("player")).name)
        else
          print("X or Y coordinate is invalid");
        end
    else
        SetItemRef_orig(link, text, button);
    end
end
SetItemRef = TomPoints_SetItemRef;
-- hooksecurefunc("ChatFrame_OnHyperlinkShow", TomPoints_SetItemRef); -- Doesn't work because WoW's code doesn't know how to handle the custom link type

-- formatXYLink
-- Formats the TomTom coordinates x and y into the link text format WoW needs to turn it into a clickable link.
local function formatXYLink(x, y)
    if (TomPoints_EuropeanDecimalFormat) then
      local xStr = tostring(x);
      xStr = xStr:gsub("%.", ",");
      local yStr = tostring(y);
      yStr = yStr:gsub("%.", ",");
      return "|cff149bfd|Htpx:"..format("%.02f", x).."tpy:"..format("%.02f", y).." |h[" .. xStr .. " " .. yStr .. "]|h|r";
    else
      return "|cff149bfd|Htpx:"..format("%.02f", x).."tpy:"..format("%.02f", y).." |h[" .. x .. ", " .. y .. "]|h|r";
    end

end

-- findLinks
-- Find the location of links in the message text, or nil if none found. Returns an array of begin and end index pairs, so
-- the length will always be number of links * 2
-- This makes the potentially ignorant assumption that every link begins with |c and ends with |h|r
-- This is also required, since some achievements, quests, items, etc. can contain text that looks like a waypoint, and will trick the parser
-- into turning it into a waypoint link. The Achievement, "10,000 World Quests Completed" is one such link.
-- msgText - the full message text, including being modified from this script itself, so the new links are included in the
-- list of links, so they don't get double-replaced.
-- returns the list indices indicating where the links exist in the string or nil if no links are found.
local function findLinks(msgText)
  local result = {}
  local lastIdx = 1;
  -- Append the space at the beginning so people can't unknowingly trick the code into thinking there's a link
  -- this only matters at the beginning of the string, Lua's pattern parsing stuff isn't that robust.
  local beginI, endI = string.find(" " .. msgText, LINK_PATTERN, lastIdx);
  local tableIdx = 0;
  while (beginI) do
    -- Subtract 1 for the space we appended above.
    result[tableIdx] = beginI - 1;
    tableIdx = tableIdx + 1;
    -- Subtract 1 for the space we appended above.
    result[tableIdx] = endI - 1;
    tableIdx = tableIdx + 1;
    --print ("Found link starting at " .. (beginI - 1) .. " ending at: " .. (endI - 1));
    -- Subtract 1 for the space we appended above.
    lastIdx = endI - 1;
    -- Append the space at the beginning so people can't unknowingly trick the code into thinking there's a link
    -- this only matters at the beginning of the string, Lua's pattern parsing stuff isn't that robust.
    beginI, endI = string.find(" " ..msgText, LINK_PATTERN, lastIdx)
  end
  if ((table.getn(result) or 0) > 0) then
    return result;
  else
    return nil;
  end
end

-- isInsideLink
-- Determines if the given index is within a link found in the message.
-- linkTable - the array of links created from findLinks (this can be nil)
-- startIndex - the starting index of the text to determine if it exists in a link.
local function isInsideLink(linkTable, startIndex)
  if (linkTable) then
    for i = 0, #(linkTable), 2 do
      --print ("Link i " .. i .. " = begin: " .. linkTable[i] .. " end: " .. linkTable[i + 1]);
      if (startIndex >= linkTable[i] and startIndex <= linkTable[i+1]) then
        --print ("Found that match starting at " .. startIndex .. " was inside a link, ignoring, hopefully!")
        -- return the end index of the match
        return linkTable[i+1] + 1;
      end
    end
  else
    return nil;
  end
end

-- doReplaceLink
-- Replaces the matching waypoint text with the clickable waypoint link.
-- This is favorable over gsub, since gsub only replaces patterns, without an idea of where to start replacing from.
-- msgText - the full message text
-- replaceStartIdx - the index where to start replacing text
-- replaceEndIdx - the index where to stop replacing text
-- returns the message text now with the waypoint link instead of the text that matched.
local function doReplaceLink(msgText, replaceStartIdx, replaceEndIdx, replaceWithText)
  local preText, postText;
  preText = strsub(msgText, 0, replaceStartIdx);
  postText = strsub(msgText, replaceEndIdx);

  return preText .. replaceWithText .. postText;
end

-- processMessage
-- Helper function that does all the message processing.
-- msgText - the full message text to process.
-- returns the msgText whether it has been processed or not, if it has been processed, and a location is found, the resulting text
-- will include the links that will be display in the chat window.
local function processMessage(msgText)
  -- If you want to see the full, un-decorated text, uncomment:
    -- print("Here's what it really looks like: \"" .. gsub(msgText, "\124", "\124\124") .. "\"");

    local stopCount = 0;
    for key,val in pairs(PATTERNS) do
      -- Attempt to limit the function so it doesn't potentially infinitely-loop
      stopCount = 0;
      local searchFromIdx = 1;

      local startIndex = string.find(msgText, val, searchFromIdx);
      -- print ("Testing string starting from " .. searchFromIdx .. " : " .. strsub(msgText, searchFromIdx))
      while startIndex and stopCount < 50 do
        stopCount = stopCount + 1;
        local linkLocs = findLinks(msgText);
        local nextSafeIdx = isInsideLink(linkLocs, startIndex);
        if (not(nextSafeIdx)) then
          -- msgText = string.gsub(msgText, val, formatURL("%1"))
          local match1, match2, match3, match4, match5 = strmatch(msgText, val, searchFromIdx)
          if match2 and match4 then
            local decimalMatch2 = match2:gsub("%,", ".");
            local decimalMatch4 = match4:gsub("%,", ".");
            local match2Value = tonumber(decimalMatch2);
            local match4Value = tonumber(decimalMatch4);
            -- Need to verify that coordinates are valid.
            -- Without this, values greater than 100 would be matched, or equal to 0 would match.
            if (match2Value > 0 and match2Value < 100  and match4Value > 0 and match4Value < 100) then
              local replaceBegin, replaceEnd = strfind(msgText, val, searchFromIdx);
              -- Ignore percentages
              -- The only place the percent sign could be is after the last match
              -- Enforcer KX-T57 announcements  can cause a match to fire
              -- Like: Enforcer KX-T57 98% ...
              if (msgText:sub(replaceEnd+1, replaceEnd+1) == "%") then
                searchFromIdx = searchFromIdx + match2:len();
              elseif (replaceBegin > 1 and tonumber(msgText:sub(replaceBegin-1, replaceBegin-1))) then
                -- This means the first match would be invalid, the pattern matched on a message like:
                -- 123 45, but found match2 = 23 and match 4 is 45
                searchFromIdx = searchFromIdx + match2:len();
              elseif (replaceBegin > 1 and msgText:sub(replaceBegin-1, replaceBegin-1):find("%a")) then
                -- This means the first match would be invalid, the pattern matched on a message like:
                -- Enforcer KX-T57 54 98.3, but found match2 = 57 and match 4 is 54 instead of 54 98.3
                searchFromIdx = searchFromIdx + match2:len();
              else
                -- print ("replacement starts at " .. (replaceBegin - 1)  .. " and ends at: " .. (replaceEnd + 1));
                msgText = doReplaceLink(msgText, replaceBegin - 1, replaceEnd + 1, formatXYLink(match2Value, match4Value));
              end
            else
              --print("match2 or match 4 is >= 100 match2: " .. match2 .. " match4: " .. match4);
              -- Move past the first token of the invalid match
              searchFromIdx = searchFromIdx + match2:len();
            end
          end
          startIndex = string.find(msgText, val, searchFromIdx);
        else
          -- print ("Not safe index, moving to: " .. nextSafeIdx .. " stopCount: " .. stopCount);
          searchFromIdx = nextSafeIdx;
          startIndex = string.find(msgText, val, searchFromIdx);
        end
      end
    end
    return msgText;
end

--local lastEvent = nil
-- TODO: throttle parsing. This gets called multiple times per message, I'm sure that can't be good for performance reasons.
local function tomPoints_OnEvent(self, event, msg,...)
  --if (lastEvent ~= event) then
  if (TomTom) then
    msg = processMessage(msg);
  else
    --print ("TomTom not loaded.");
  end
  return false, msg, ...
end

local CHANNELS = {
    "BATTLEGROUND_LEADER",
    "BATTLEGROUND",
    "BN_WHISPER",
    "BN_WHISPER_INFORM",
    "CHANNEL",
    "COMMUNITIES_CHANNEL",
    "DND",
    "EMOTE",
    "GUILD",
    "OFFICER",
    "PARTY_LEADER",
    "PARTY",
    "RAID_LEADER",
    "RAID_WARNING",
    "RAID",
    "SAY",
    "WHISPER",
    "WHISPER_INFORM",
    "YELL"
}
-- print("loaded")
for _, type in pairs(CHANNELS) do
    ChatFrame_AddMessageEventFilter("CHAT_MSG_" .. type, tomPoints_OnEvent)
end
--ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", tomPoints_OnEvent)
--ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", tomPoints_OnEvent)

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "TomPoints" then
        -- Our saved variables, if they exist, have been loaded at this point.
      if TomPoints_EuropeanDecimalFormat == nil then
        -- This is the first time this addon is loaded; set SVs to default values
        TomPoints_EuropeanDecimalFormat = false
      end
      if (TomPoints_EuropeanDecimalFormat) then
        PATTERNS = PATTERNS_EURO;
        print(STR_EURO);
      else
        PATTERNS = PATTERNS_US_BRITISH;
        print(STR_US_BRITISH);
      end
      frame:UnregisterEvent("ADDON_LOADED");
    end
end)

--- Configuration/testing functions
local function printUsage(msg)
  local currentSettingOfDecimal = TomPoints_EuropeanDecimalFormat or false;
  if (currentSettingOfDecimal) then
    print(STR_EURO);
  else
    print(STR_US_BRITISH);
  end
  print("/tompoints - Print this message");
  print("/tompoints_comma, /tpcomma, /tpeuro - Turn on parsing of European-style comma decimal number formats in waypoints (23,45 45,56)");
  print("/tompoints_period, /tpperiod, /tpus, /tpbrit  - Turn on parsing of US/British-style period decimal number formats in waypoints (23.45, 45.56)");
  print("/tompoints_test, /tptest - Test a string to see how TomPoints parses it, the result will be printed to the chat window.");
end

SLASH_TOMPOINTS1 = "/TOMPOINTS";
SLASH_TOMPOINTSCOMMA1 = "/TOMPOINTS_COMMA";
SLASH_TOMPOINTSCOMMA2 = "/TPCOMMA";
SLASH_TOMPOINTSCOMMA3 = "/TPEURO";
SLASH_TOMPOINTSPERIOD1 = "/TOMPOINTS_PERIOD";
SLASH_TOMPOINTSPERIOD2 = "/TPPERIOD";
SLASH_TOMPOINTSPERIOD3 = "/TPUS";
SLASH_TOMPOINTSPERIOD4 = "/TPBRIT";
SLASH_TOMPOINTSTEST1 = "/TOMPOINTS_TEST";
SLASH_TOMPOINTSTEST2 = "/TPTEST";
SLASH_TOMPOINTSICON1 = "/TPICON"
SLASH_TOMPOINTSREMOVE1 = "/TP"

SlashCmdList["TOMPOINTSICON"] = function(msg)
  iconNumber = tonumber(msg);
end

SlashCmdList["TOMPOINTS"] = printUsage
SlashCmdList["TOMPOINTSPERIOD"] = function(msg)
  TomPoints_EuropeanDecimalFormat = false;
  PATTERNS = PATTERNS_US_BRITISH;
  print(STR_US_BRITISH);
end
SlashCmdList["TOMPOINTSCOMMA"] = function(msg)
  TomPoints_EuropeanDecimalFormat = true;
  PATTERNS = PATTERNS_EURO;
  print(STR_EURO);
end
SlashCmdList["TOMPOINTSTEST"] = function(msg)
  print("TomPoints test result: " .. processMessage(msg or ""));
end