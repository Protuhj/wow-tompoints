-- TomPoints.lua
-- Parses chat channels for X,Y coordinate locations to create TomTom waypoints.
-- Heavily patterned off the ClickLinks addon.

local PATTERNS = {
    "((%d+(%.?%d*))%s*,+%s*(%d+(%.?%d*)))", -- has a comma
    "((%d+(%.?%d*))%s+(%d+(%.?%d*)))",      -- no comma, just at least a space
}

local LINK_PATTERN = "[^|]|c.-|h|r";

local lastAddedWaypoint = nil;

-- formatXYLink
-- Formats the TomTom coordinates x and y into the link text format WoW needs to turn it into a clickable link.
-- pinActive - if true, an icon is added to the link
local function formatXYLink(x, y, pinActive)
    if pinActive then
        return "|cff149bfd|Hgarrmission:TomPoints:tpx:"..format("%.02f", x).."tpy:"..format("%.02f", y).." |h[|A:Waypoint-MapPin-ChatIcon:13:13:0:0|a" .. x .. ", " .. y .. "]|h|r";
    else
        return "|cff149bfd|Hgarrmission:TomPoints:tpx:"..format("%.02f", x).."tpy:"..format("%.02f", y).." |h[" .. x .. ", " .. y .. "]|h|r";
    end
end

-- formatPinLink
-- Formats the coordinates x and y into the link text format WoW needs to turn it into a clickable link for MapPins.
-- Don't use this link format because you can't easily share it for now. I have to assume they'll allow it in the future.
local function formatPinLink(x, y)
    map = C_Map.GetBestMapForUnit("player");
    --print("Map : " .. map);
    return "|cffffff00|Hworldmap:" .. map .. ":"..format("%d", tonumber(x)*100)..":"..format("%d", tonumber(y)*100).."|h[|A:Waypoint-MapPin-ChatIcon:13:13:0:0|a " .. x .. ", " .. y .. "]|h|r";
end

-- addTomTomWaypoint
-- Helper function to add the waypoint in TomTom
-- coordXFromLink - The X coordinate from the link, this is not in units that TomTom expects.
-- coordYFromLink - The Y coordinate from the link, this is not in units that TomTom expects.
-- TODO: a custom icon would be nice to distinguish from normal waypoints, since these may be temporal in nature, like rares in Nazjatar, Mechagon, etc.
local function addTomTomWaypoint(coordXFromLink, coordYFromLink, text)
  if (TomTom) then
    lastAddedWaypoint = TomTom:AddWaypoint(C_Map.GetBestMapForUnit("player"), tonumber(coordXFromLink)/100, tonumber(coordYFromLink)/100, {
      title = "TomPoints - " .. date("%H:%M").. " - " .. text,
      persistent = nil,
      minimap = true,
      world = true
    })
  else
    print "TomTom not loaded!"
  end
end

-- addUiPinWaypoint
-- Helper function to add the waypoint using the new Pin system
-- coordXFromLink - The X coordinate from the link, this is not in units that WoW expects.
-- coordYFromLink - The Y coordinate from the link, this is not in units that WoW expects.
-- quiet          - should this function not announce it's creating a pin?
local function addUiPinWaypoint(coordXFromLink, coordYFromLink, quiet)
    map = C_Map.GetBestMapForUnit("player");
    if C_Map.CanSetUserWaypointOnMap(map) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, tonumber(coordXFromLink)/100, tonumber(coordYFromLink)/100));
        if not(quiet) then
            print("TomPoints created Map Pin: " .. formatXYLink(tonumber(coordXFromLink), tonumber(coordYFromLink), true));
        end
    else
        print("TomPoints can't create Map Pin in this zone");
    end
end

-- TomPoints_SetItemRef
-- Handles when the user clicks on the link
local function TomPoints_SetItemRef(link, text, button)
    -- print("link: " .. link .. " text: " .. text .. " button: " .. button);
    local linkType, addon, param1 = strsplit(":", link)
    --print("Type: " .. linkType);
    --if (linkType == "worldmap" and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink(C_Map.GetUserWaypointHyperlink())) then
    --    print("Pasted in link");
    --else
    if (linkType == "garrmission" and addon == "TomPoints") then
        local x, y = strmatch(link, "tpx:(%d+%.%d+)tpy:(%d+%.%d+)")
        if (x and y) then
            -- If the person is trying to link the waypoint like it's an achievement, attempt to add to chat
            -- Otherwise, add the waypoint like normal if the chat edit area isn't open (maybe the shift was down by accident)
            linkAdded = false; 
            if IsModifiedClick("CHATLINK") then
                if (addonConfig["ShareAsPin"]) then -- share map pins instead of raw text
                    map = C_Map.GetBestMapForUnit("player");
                    if C_Map.CanSetUserWaypointOnMap(map) then
                        curPin = C_Map.GetUserWaypoint();
                        -- Have to create the pin to be able to share it
                        addUiPinWaypoint(x, y, true);
                        linkAdded = ChatEdit_InsertLink(C_Map.GetUserWaypointHyperlink());
                        if curPin then
                            C_Map.SetUserWaypoint(curPin);
                        end
                    else
                        print("TomPoints can't create Map Pin in this zone; can't share as map pin");
                    end
                end
                if not(linkAdded) then
                    linkAdded = ChatEdit_InsertLink(" " .. x .. ", " .. y .. " ");
                end
                
            end
            if not(linkAdded) then
                if (TomTom) then
                    addTomTomWaypoint(x, y, text);
                    if (addonConfig["AlwaysCreateMapPin"]) then
                        addUiPinWaypoint(x, y);
                    end
                else
                    addUiPinWaypoint(x, y);
                end
            end
            -- print ("Attempted to add waypoint to " .. tonumber(x) .. "," .. tonumber(y) .. " for map: " .. C_Map.GetMapInfo(C_Map.GetBestMapForUnit("player")).name)
        else
          print("X or Y coordinate is invalid");
        end
    end
end
-- hooksecurefunc("ChatFrame_OnHyperlinkShow", TomPoints_SetItemRef); -- Doesn't work because WoW's code doesn't know how to handle the custom link type
hooksecurefunc("SetItemRef", TomPoints_SetItemRef); -- Doesn't work because WoW's code doesn't know how to handle the custom link type

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

-- replaceBlizzPinLink
-- Replaces Blizzard's Map Pin link with a TomPoints link, so we can share it like other waypoint links
local function replaceBlizzPinLink(msgText)
    -- Needed for pin replacement to work in other languages
    -- Defined in GlobalStrings.lua
    -- https://www.townlong-yak.com/framexml/live/GlobalStrings.lua
    local localizedText = MAP_PIN_HYPERLINK; -- Works out to: "|A:Waypoint-MapPin-ChatIcon:13:13:0:0|a Map Pin Location"
    localizedText = gsub(localizedText, "%-", "%%-");
    local matchPattern = "|cffffff00|Hworldmap:%d+:(%d+):(%d+)|h%[" .. localizedText .. "%]|h|r";
    local stopCount = 0;
    local searchFromIdx = 1;

    local replaceBegin, replaceEnd = strfind(msgText, matchPattern, searchFromIdx);
    while replaceBegin and stopCount < 500 do
        --print("Begin: " .. tostring(replaceBegin) .. " end: " .. tostring(replaceEnd));
        stopCount = stopCount + 1;
        local linkText = msgText:sub(replaceBegin, replaceEnd);
        local xCoord, yCoord = strmatch(linkText, matchPattern, 1);
        if xCoord ~= nil and yCoord ~= nil then
            xCoordFloatStr = tostring(tonumber(xCoord) / 100.);
            yCoordFloatStr = tostring(tonumber(yCoord) / 100.);
            --print("Found link: with xCoord: " .. xCoordFloatStr .. " yCoord: " .. yCoordFloatStr);
            msgText = doReplaceLink(msgText, replaceBegin - 1, replaceEnd + 1, xCoordFloatStr .. " " .. yCoordFloatStr .. " ");
            searchFromIdx = searchFromIdx + xCoordFloatStr:len();
            --print("Replaced, msgText now: " .. msgText);
        else
            --print("Coords were nil");
            -- nudge it forward
            searchFromIdx = searchFromIdx + 1;
        end
        replaceBegin, replaceEnd = strfind(msgText, matchPattern, searchFromIdx);
    end
    return msgText
end

-- processMessage
-- Helper function that does all the message processing.
-- msgText - the full message text to process.
-- returns the msgText whether it has been processed or not, if it has been processed, and a location is found, the resulting text
-- will include the links that will be display in the chat window.
local function processMessage(msgText)
  -- If you want to see the full, un-decorated text, uncomment:
    -- print("Here's what it really looks like: \"" .. gsub(msgText, "\124", "\124\124") .. "\"");
    if addonConfig["ReplaceBlizzardLinks"] then
        msgText = replaceBlizzPinLink(msgText);
    end
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
            local match2Value = tonumber(match2);
            local match4Value = tonumber(match4);
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
                if (TomTom) then
                   msgText = doReplaceLink(msgText, replaceBegin - 1, replaceEnd + 1, formatXYLink(match2Value, match4Value, addonConfig["AlwaysCreateMapPin"]));
                else
                   msgText = doReplaceLink(msgText, replaceBegin - 1, replaceEnd + 1, formatXYLink(match2Value, match4Value, true));
                end
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
    msg = processMessage(msg);
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
frame:RegisterEvent("VARIABLES_LOADED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "VARIABLES_LOADED" then
        -- Our saved variables, if they exist, have been loaded at this point.
      if addonConfig == nil then
        -- This is the first time this addon is loaded; set SVs to default values
        addonConfig = {};
        print("Created addonConfig");
      end
      if addonConfig["AlwaysCreateMapPin"] == nil then
        addonConfig["AlwaysCreateMapPin"] = false;
      end
      if addonConfig["ShareAsPin"] == nil then
        addonConfig["ShareAsPin"] = true;
      end
      if addonConfig["ReplaceBlizzardLinks"] == nil then
        addonConfig["ReplaceBlizzardLinks"] = false;
      end
      frame:UnregisterEvent("VARIABLES_LOADED");
    end
end)

--- Configuration/testing functions
local function printUsage(msg)
  print("/tompoints - Print this message");
  print("/tompoints_test, /tptest - Test a string to see how TomPoints parses it, the result will be printed to the chat window.");
  print("/tompoints_removelast, /tpremove_last, /tprl - Removes from TomTom the last waypoint that was clicked on, this isn't remembered between UI reloads, or between logins.");
end

SLASH_TOMPOINTS1 = "/TOMPOINTS";
SLASH_TOMPOINTSTEST1 = "/TOMPOINTS_TEST";
SLASH_TOMPOINTSTEST2 = "/TPTEST";
SLASH_TOMPOINTSREMOVELAST1 = "/TOMPOINTS_REMOVELAST";
SLASH_TOMPOINTSREMOVELAST2 = "/TPREMOVE_LAST";
SLASH_TOMPOINTSREMOVELAST3 = "/TPRL";

SlashCmdList["TOMPOINTS"] = printUsage
SlashCmdList["TOMPOINTSTEST"] = function(msg)
  print("TomPoints test result: " .. processMessage(msg or ""));
end
SlashCmdList["TOMPOINTSREMOVELAST"] = function(msg)
  if (lastAddedWaypoint) then
    TomTom:RemoveWaypoint(lastAddedWaypoint);
    lastAddedWaypoint = nil;
  end
end