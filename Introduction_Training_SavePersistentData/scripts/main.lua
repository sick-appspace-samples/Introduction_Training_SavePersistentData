Log.setLevel( "ALL" )

local imageNumber = 0
-- Create an instance of a viewer:
local myViewer = View.create( "2DImageDisplay" )
-- Create an instance of a code reader:
local myCodeReader = Image.CodeReader.create()
-- Create an instance of a decoder:
local myDecoderQR = Image.CodeReader.QR.create()
local myDecoderDM = Image.CodeReader.DataMatrix.create()
myDecoderDM:setAggressivityLevel( "DPMPLUS" )
local myDecoderMC = Image.CodeReader.Maxicode.create()
local myDecoderPDF = Image.CodeReader.PDF417.create()
-- Add the decoder to the code reader:
myCodeReader:setDecoder( "APPEND", myDecoderQR )
myCodeReader:setDecoder( "APPEND", myDecoderDM )
myCodeReader:setDecoder( "APPEND", myDecoderMC )
myCodeReader:setDecoder( "APPEND", myDecoderPDF )

local myGrayImage = nil
local myProcessingDelay = 1000
-- Create a timer to delay the start of image processing:
local myDelayTimer = Timer.create()
myDelayTimer:setExpirationTime( myProcessingDelay )   -- in [ms]
myDelayTimer:setPeriodic( false )

-- Create a shape decoration:
local myShapeDecoQR = View.ShapeDecoration.create()
myShapeDecoQR:setLineWidth( 3 )
myShapeDecoQR:setLineColor( 0, 255, 0, 255 )   -- green border
myShapeDecoQR:setFillColor( 0, 255, 0, 127 )   -- filled transparent green
local myShapeDecoDM = View.ShapeDecoration.create()
myShapeDecoDM:setLineWidth( 3 )
myShapeDecoDM:setLineColor( 0, 255, 255, 255 )   -- cyan border
myShapeDecoDM:setFillColor( 0, 255, 255, 127 )   -- filled transparent cyan
local myShapeDecoMC = View.ShapeDecoration.create()
myShapeDecoMC:setLineWidth( 3 )
myShapeDecoMC:setLineColor( 255, 0, 255, 255 )   -- magenta border
myShapeDecoMC:setFillColor( 255, 0, 255, 127 )   -- filled transparent magenta
local myShapeDecoPDF = View.ShapeDecoration.create()
myShapeDecoPDF:setLineWidth( 3 )
myShapeDecoPDF:setLineColor( 255, 255, 0, 255 )   -- yellow border
myShapeDecoPDF:setFillColor( 255, 255, 0, 127 )   -- filled transparent yellow
local myShapeDecoUnknown = View.ShapeDecoration.create()
myShapeDecoUnknown:setLineWidth( 3 )
myShapeDecoUnknown:setLineColor( 255, 0, 0, 255 )   -- red border
myShapeDecoUnknown:setFillColor( 255, 0, 0, 127 )   -- filled transparent red
-- Create text decorations:
local myContentTextDeco = View.TextDecoration.create()
myContentTextDeco:setSize( 12 )
myContentTextDeco:setColor( 0, 0, 255, 255 )   -- blue text
local myNoFoundTextDeco = View.TextDecoration.create()
myNoFoundTextDeco:setSize( 20 )
myNoFoundTextDeco:setColor( 255, 0, 0, 255 )   -- red text

local latestImage = nil

Script.serveEvent( "Training.OnProcessingFinished", "OnProcessingFinished" )

local function handleOnNewImage( inImage )
  latestImage = inImage
  --print( inImage:toString() )
  Log.info( inImage:toString() )
  -- Clear viewer from previously shown data:
  myViewer:clear()
  local myIconicID = myViewer:addImage( inImage )
  myViewer:present( "ASSURED" )
  Script.notifyEvent( "OnProcessingFinished", "n/a" )
  myDelayTimer:start()
  -- Change the colored image to grayscale:
  myGrayImage = inImage:toGray()
end

local function processImage()
  myViewer:addImage( myGrayImage )
  local currCodeElements, currDuration = myCodeReader:decode( myGrayImage )
  print( "Code reading duration: " .. currDuration .. "ms;" )
  local actualCodeContent = "No data code found in current image!"
  local actualCenterPoint = Point.create( 0, myGrayImage:getHeight() / 2 )
  myNoFoundTextDeco:setPosition( actualCenterPoint:getX(), actualCenterPoint:getY() )
  if ( #currCodeElements > 0 ) then
    print( "Number of codes read: " .. #currCodeElements .. ";" )
    local actualCodeRegion = nil
    for i = 1, #currCodeElements, 1 do
      actualCodeContent = currCodeElements[ i ]:getContent()
      Log.info( "Current code content (" .. i .. "): '" .. actualCodeContent .. "';" )
      actualCodeRegion = currCodeElements[ i ]:getRegion()
      if ( currCodeElements[ i ]:getType() == "QR" ) then
        myViewer:addShape( actualCodeRegion, myShapeDecoQR )
      elseif ( currCodeElements[ i ]:getType() == "DMX" ) then
        myViewer:addShape( actualCodeRegion, myShapeDecoDM )
      elseif ( currCodeElements[ i ]:getType() == "MAXICODE" ) then
        myViewer:addShape( actualCodeRegion, myShapeDecoMC )
      elseif ( currCodeElements[ i ]:getType() == "PDF417" ) then
        myViewer:addShape( actualCodeRegion, myShapeDecoPDF )
      else
        myViewer:addShape( actualCodeRegion, myShapeDecoUnknown )
      end
      actualCenterPoint = currCodeElements[ i ]:getGravityCenter()
      myContentTextDeco:setPosition( actualCenterPoint:getX(), actualCenterPoint:getY() )
      myViewer:addText( actualCodeContent, myContentTextDeco )
    end
  else
    Log.warning( actualCodeContent )
    myViewer:addText( actualCodeContent, myNoFoundTextDeco )
  end
  Script.notifyEvent( "OnProcessingFinished", tostring( #currCodeElements ) )
  myViewer:present( "ASSURED" )
end
myDelayTimer:register( "OnExpired", processImage )

local function loadNextImage()
  if ( imageNumber == 0 ) then
    Log.warning( "Will start at first image!" )
  end
  print( "Will load image '" .. imageNumber .. ".png' ..." )
  local myImage = Image.load( "resources/" .. imageNumber .. ".png" )
  imageNumber = ( imageNumber + 1 ) % 13
  handleOnNewImage( myImage )
end

local imageTimer = Timer.create()
imageTimer:setExpirationTime( 3 * myProcessingDelay )   -- in [ms]
imageTimer:setPeriodic( true )
imageTimer:register( "OnExpired", loadNextImage )
Log.severe( "Timer has been registered!" )

---@param inNewTime int New processing delay value
local function setProcessingDelay( inNewTime )
  local processingDelayRunning = myDelayTimer:isRunning()
  if ( processingDelayRunning == true ) then
    myDelayTimer:stop()
  end
  imageTimer:stop()
  myProcessingDelay = inNewTime
  myDelayTimer:setExpirationTime( myProcessingDelay )   -- in [ms]
  imageTimer:setExpirationTime( 3 * myProcessingDelay )   -- in [ms]
  imageTimer:start()
  Log.info( "New processing delay: " .. myProcessingDelay .. "ms;" )
  Log.info( "Yields new image loading interval: " .. 3 * myProcessingDelay .. "ms;" )
  if ( processingDelayRunning == true ) then
    myDelayTimer:start()
  else
    loadNextImage()
  end
end
Script.serveFunction( "Training.setProcessingDelay", setProcessingDelay )

---@return int currProcessingDelay current processing delay
local function getProcessingDelay()

  return myProcessingDelay
end
Script.serveFunction( "Training.getProcessingDelay", getProcessingDelay )

local function saveData()
  Log.info( "Saving data ..." )
  if ( latestImage ~= nil ) then
    latestImage:save( "public/latestImage.bmp" )
  end
  --local myContainer = Container.create()
  --myContainer:add( "currProcessingDelay", myProcessingDelay )
  --Object.save( myContainer, "public/ProcessingDelay.json", "JSON" )
  Parameters.set( "paramProcessingDelay", myProcessingDelay )
  Parameters.savePermanent()
end
Script.serveFunction( "Training.saveData", saveData )

local function loadData()
  --local myContainerLoaded = Object.load( "public/ProcessingDelay.json", "JSON" )
  --if ( myContainerLoaded ~= nil ) then
  --  myProcessingDelay = myContainerLoaded:get( "currProcessingDelay" )
  --else
  --  myProcessingDelay = 1000
  --end
  myProcessingDelay = Parameters.get( "paramProcessingDelay" )
  setProcessingDelay( myProcessingDelay )
end

local function main()
  print( "Hello world!" )
  local myText = "This is me!"
  print( "content of 'myText' is: '" .. myText .. "';" )
  loadData()
  --imageTimer:start()
  --loadNextImage()
end
Script.register( "Engine.OnStarted", main )
