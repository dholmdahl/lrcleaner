local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrLogger = import 'LrLogger'
local LrPathUtils = import 'LrPathUtils'
local LrProgressScope = import 'LrProgressScope'
local LrSystemInfo = import 'LrSystemInfo'
local LrTasks = import 'LrTasks'

local json = require "JSON"

require 'Info'

local logger = LrLogger(plugin_name)
logger:enable(log_target)

json.strictTypes = true

logger:trace('FindDuplicates.lua invoked')
logger:infof('summaryString: %s', LrSystemInfo.summaryString())
logger:infof('Deduplicator version is %s', plugin_version)

local scoredImagesCollectionName = "Scored"

local nrScoredImagesCollectionName = "No Reference"
local frScoredImagesCollectionName = "Full Reference"
local aesScoredImagesCollectionName = "Aesthetic"

local jsonFilePath = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'metadata.json')
-- LrPathUtils.standardizePath(
  -- LrPathUtils.getStandardFilePath('temp') .. '/' .. 'imgsum.db')

-- TODO: remove this... should only need to re-generate database on user request
-- LrFileUtils.moveToTrash(jsonFilePath)

catalog = LrApplication.activeCatalog()

LrTasks.startAsyncTask(function()
  catalog:withWriteAccessDo("Create collection", function()
    collection = catalog:createCollection(scoredImagesCollectionName)

    if collection == nil then
    
      -- Check if there's already a collection with the same name
      for _, c in pairs(catalog:getChildCollections()) do
        if c:getName() == scoredImagesCollectionName then
          collection = c
        end
      end

      -- Create subcollections
      nrCollection = catalog:createCollection(nrScoredImagesCollectionName, collection)
      frCollection = catalog:createCollection(frScoredImagesCollectionName, collection)
      aesCollection = catalog:createCollection(aesScoredImagesCollectionName, collection)

      -- Check if subcollections were created successfully
      if nrCollection and frCollection and aesCollection then
        logger:info('Subcollections created successfully')
      else
        logger:error('Failed to create subcollections')
      end
    end
  end)
end)

binName = 'scoreimages-i386'
if LrSystemInfo.is64Bit() then
  binName = 'scoreimages-amd64'
end

function AddScoredPhotosToCollection(collectionData, lrCollection)
  for _, photo in pairs(collectionData) do

      logger:infof('Preparing query to Lightroom about %s', photo)
      file = lrCollection:findPhotoByPath(photo["path"])
      if file ~= nil then
        logger:infof('Preparing to add photo id=%s to collection id=%s', file.localIdentifier, lrCollection.localIdentifier)
        file:setRawMetadata("rating", photo["score"])
        lrCollection:addPhotos({p})
      else
        logger:warnf('nil result returned on attempt to resolve photo by path %s', file)
      end

  end
end

function ScoreImages()
  logger:trace('ScoreImages() invoked')
  local command
  local quotedCommand

  -- Run compiled python script to generate score database
  if WIN_ENV == true then
    command = string.format('"%s" -json-output -all %s',
      LrPathUtils.child( LrPathUtils.child( _PLUGIN.path, "win" ), binName .. '.exe' ),
      jsonFilePath)
    quotedCommand = '"' .. command .. '"'
  else
    -- TODO
    -- command = string.format('"%s" -json-output -find-duplicates %s',
    --   LrPathUtils.child( LrPathUtils.child( _PLUGIN.path, "mac" ), binName ),
    --   imgRatingDatabasePath)
    --  quotedCommand = command
  end

  logger:debugf('Preparing to run command %s', quotedCommand)
  local process = assert(io.popen(quotedCommand, 'r'))
  local proc_output = assert(process:read('*a'))
  process:close()
  logger:debugf('imgscore -json-output -all output: %s', proc_output)

  if proc_output ~= "" then
    local scores_output = json:decode(proc_output)

    if scores_output["scores"] ~= nil then
      catalog:withWriteAccessDo("Add photos to scores collection", function()
        AddScoredPhotosToCollection(scores_output["scores"][nrScoredImagesCollectionName], nrCollection)
        AddScoredPhotosToCollection(scores_output["scores"][frScoredImagesCollectionName], frCollection)
        AddScoredPhotosToCollection(scores_output["scores"][aesScoredImagesCollectionName], aesCollection)
      end)
    else
      logger:warn('JSON output from scoreimages contains null')
    end

  else
    logger:warn('Empty output')
  end
end

function StartIndexing()
  logger:trace('StartIndexing() invoked')
  local photos = catalog:getMultipleSelectedOrAllPhotos()
  local indexerProgress = LrProgressScope({
    title="Indexing photos...", functionContext = context})

  indexerProgress:setCancelable(true)

  LrDialogs.showBezel("Starting indexing...")

  -- Create a table to store photo metadata
  local metadataTable = {}

  for i, photo in ipairs(photos) do
    if indexerProgress:isCanceled() then
      logger:info('Indexing process cancelled')
      break;
    end

    local fileName = photo:getFormattedMetadata("fileName")
    logger:debugf('Processing file %s', fileName)

    indexerProgress:setPortionComplete(i, #photos)
    indexerProgress:setCaption(
      string.format("Processing %s (%s of %s)", fileName, i, #photos))

    local imagePath = photo:getRawMetadata("path")

    -- Get the photo metadata
    local metadata = {
      path = imagePath,
      -- Add more metadata fields as needed
    }

    -- Add the metadata to the table
    table.insert(metadataTable, metadata)
  end

  -- Convert the metadata table to JSON
  local jsonData = json.encode(metadataTable)

  -- Write the JSON data to a local file
  logger:debugf('Writing metadata.json to %s', jsonFilePath)
  LrFileUtils.writeFile(jsonFilePath, jsonData)

  logger:info('Setting indexing process to done state')
  indexerProgress:done()

  logger:info('Starting database search process')
  ScoreImages()
end

LrTasks.startAsyncTask(StartIndexing)
