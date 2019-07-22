-- TomPoints.lua
-- Parses chat channels for X,Y coordinate locations to create TomTom waypoints.
-- Heavily patterned off the ClickLinks addon.

local PATTERNS = {
    "((%d+(%.?%d*))%s*,+%s*(%d+(%.?%d*)))", -- has a comma
    "((%d+(%.?%d*))%s+(%d+(%.?%d*)))",      -- no comma, just at least a space
}

local LINK_PATTERN = "[^|]|c.-|h|r";

-- addTomTomWaypoint
-- Helper function to add the waypoint in TomTom
-- coordXFromLink - The X coordinate from the link, this is not in units that TomTom expects.
-- coordYFromLink - The Y coordinate from the link, this is not in units that TomTom expects.
-- TODO: a custom icon would be nice to distinguish from normal waypoints, since these may be temporal in nature, like rares in Nazjatar, Mechagon, etc.
local function addTomTomWaypoint(coordXFromLink, coordYFromLink)
  if (TomTom) then
    TomTom:AddWaypoint(C_Map.GetBestMapForUnit("player"), tonumber(coordXFromLink)/100, tonumber(coordYFromLink)/100, {
      title = nil,
      persistent = nil,
      minimap = true,
      world = true
    })
  else
    print "TomTom not loaded!"
  end
end

local SetItemRef_orig = SetItemRef;
-- TomPoints_SetItemRef
-- Handles when the user clicks on the link
local function TomPoints_SetItemRef(link, text, button)
    --print("link: " .. link);
    if (string.sub(link, 1, 4) == "tpx:") then
        local x, y = strmatch(link, "tpx:(%d+%.%d+)tpy:(%d+%.%d+)")
        if (x and y) then
          -- If the person is trying to link the waypoint like it's an achievement, attempt to add to chat
          -- Otherwise, add the waypoint like normal if the chat edit area isn't open (maybe the shift was down by accident)
          if IsModifiedClick("CHATLINK") and ChatEdit_InsertLink(" " .. x .. ", " .. y .. " ") then
            -- print("modified click");
          else
            addTomTomWaypoint(x, y);
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
    return "|cff149bfd|Htpx:"..format("%.02f", x).."tpy:"..format("%.02f", y).." |h[" .. x .. ", " .. y .. "]|h|r";
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

--local lastEvent = nil
--function tomPoints_OnEvent(self, event, msg, player, language, channel,...)
-- TODO: throttle parsing. This gets called multiple times per message, I'm sure that can't be good for performance reasons.
function tomPoints_OnEvent(self, event, msg,...)
  --if (lastEvent ~= event) then
  if (TomTom) then
    -- If you want to see the full, un-decorated text, uncomment:
    -- print("Here's what it really looks like: \"" .. gsub(msg, "\124", "\124\124") .. "\"");

    local stopCount = 0;
    for key,val in pairs(PATTERNS) do
      -- Attempt to limit the function so it doesn't potentially infinitely-loop
      stopCount = 0;
      local searchFromIdx = 1;

      local startIndex = string.find(msg, val, searchFromIdx);
      -- print ("Testing string starting from " .. searchFromIdx .. " : " .. strsub(msg, searchFromIdx))
      while startIndex and stopCount < 50 do
        stopCount = stopCount + 1;
        local linkLocs = findLinks(msg);
        local nextSafeIdx = isInsideLink(linkLocs, startIndex);
        if (not(nextSafeIdx)) then
          -- msg = string.gsub(msg, val, formatURL("%1"))
          local match1, match2, match3, match4, match5 = strmatch(msg, val, searchFromIdx)
          if match2 and match4 then
            local match2Value = tonumber(match2);
            local match4Value = tonumber(match4);
            -- Need to verify that coordinates are valid.
            -- Without this, values greater than 100 would be matched, or equal to 0 would match.
            if (match2Value > 0 and match2Value < 100  and match4Value > 0 and match4Value < 100) then
              local replaceBegin, replaceEnd = strfind(msg, val, searchFromIdx);
              -- print ("replacement starts at " .. (replaceBegin - 1)  .. " and ends at: " .. (replaceEnd + 1));
              msg = doReplaceLink(msg, replaceBegin - 1, replaceEnd + 1, formatXYLink(match2Value, match4Value));
            else
              --print("match2 or match 4 is >= 100 match2: " .. match2 .. " match4: " .. match4);
              -- Move past the first token of the invalid match
              searchFromIdx = searchFromIdx + match2:len();
            end
          elseif match2 and match3 then
            --print("hello2 " .. channel .. " msg: " .. match2 .. " , " .. match3.. ": " .. formatXYLink(match1, match2))
            -- print(formatXYLink(match2, match3));
            -- msg = string.gsub(msg, val, formatXYLink(match2, match3), 1)
            local match2Value = tonumber(match2);
            local match4Value = tonumber(match3);
            if (match2Value > 0 and match2Value < 100  and match3Value > 0 and match3Value < 100) then
            local replaceBegin, replaceEnd = strfind(msg, val, searchFromIdx);
            -- print ("replacement starts at " .. (replaceBegin - 1) .. " and ends at: " .. (replaceEnd + 1));
            msg = doReplaceLink(msg, replaceBegin - 1, replaceEnd + 1, formatXYLink(match2Value, match3Value));
            else
              --print("match2 or match 3 is >= 100 match2: " .. match2 .. " match3: " .. match3);
              -- Move past the first token of the invalid match
              searchFromIdx = searchFromIdx + match2:len();
            end
          end
          startIndex = string.find(msg, val, searchFromIdx);
        else
          -- print ("Not safe index, moving to: " .. nextSafeIdx .. " stopCount: " .. stopCount);
          searchFromIdx = nextSafeIdx;
          startIndex = string.find(msg, val, searchFromIdx);
        end
      end
      end
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

