-- Activate multitouch
system.activate("multitouch")

-- Initialize variables

local composer = require( "composer" )

local scene = composer.newScene()

local font = "star_destroyer.ttf"

local CBE = require("CBE.CBE")
CBE.listPresets()
-- -----------------------------------------------------------------------------------
-- Code outside of the scene event functions below will only be executed ONCE unless
-- the scene is removed entirely (not recycled) via "composer.removeScene()"
-- -----------------------------------------------------------------------------------

local physics = require( "physics" )
physics.start()
physics.setGravity( 0, 0 )

-- Configure image sheet
local sheetOptions =
{
    frames =
    {
        {   -- 1) asteroid 1
            x = 0,
            y = 0,
            width = 102,
            height = 85
        },
        {   -- 2) asteroid 2
            x = 0,
            y = 85,
            width = 90,
            height = 83
        },
        {   -- 3) asteroid 3
            x = 0,
            y = 168,
            width = 100,
            height = 97
        },
        {   -- 4) ship
            x = 0,
            y = 265,
            width = 98,
            height = 79
        },
        {   -- 5) laser
            x = 98,
            y = 265,
            width = 14,
            height = 40
        },
    },
}
local objectSheet = graphics.newImageSheet( "gameObjects.png", sheetOptions )

-- Initialize variables
local lives = 3
local score = 0
local died = false

local asteroidsTable = {}

local ship
local gameLoopTimer
local livesText
local scoreText

local backGroup
local mainGroup
local uiGroup

local explosionSound
local fireSound
local musicTrack


local function updateText()
	livesText.text = "Lives: " .. lives
	scoreText.text = "Score: " .. score
end

local vent = CBE.newVent({
	preset = "flame",
	title = "explosion",

	positionType = "inRadius",
	color = {{1, 1, 0}, {1, 0.5, 0}, {0.2, 0.2, 0.2}},
	particleProperties = {blendMode = "add"},
	emitX = display.contentCenterX,
	emitY = display.contentCenterY,

	emissionNum = 5,
	emitDelay = 5,
	perEmit = 1,

	inTime = 100,
	lifeTime = 0,
	outTime = 600,

	onCreation = function(particle)
		particle:changeColor({
			color = {0.1, 0.1, 0.1},
			time = 600
		})
	end,

	onUpdate = function(particle)
		particle:setCBEProperty("scaleRateX", particle:getCBEProperty("scaleRateX") * 0.998)
		particle:setCBEProperty("scaleRateY", particle:getCBEProperty("scaleRateY") * 0.998)
	end,

	physics = {
		velocity = 0,
		gravityY = -0.035,
		angles = {0, 360},
		scaleRateX = 1.05,
		scaleRateY = 1.05
	}
})

local function createAsteroid()

	local newAsteroid = display.newImageRect( mainGroup, objectSheet, 1, 102, 85 )
	table.insert( asteroidsTable, newAsteroid )
	physics.addBody( newAsteroid, "dynamic", { radius=40, bounce=0.8 } )
	newAsteroid.myName = "asteroid"

	local whereFrom = math.random( 3 )

	if ( whereFrom == 1 ) then
		-- From the left
		newAsteroid.x = -60
		newAsteroid.y = math.random( 500 )
		newAsteroid:setLinearVelocity( math.random( 40,120 ), math.random( 20,60 ) )
	elseif ( whereFrom == 2 ) then
		-- From the top
		newAsteroid.x = math.random( display.contentWidth )
		newAsteroid.y = -60
		newAsteroid:setLinearVelocity( math.random( -40,40 ), math.random( 40,120 ) )
	elseif ( whereFrom == 3 ) then
		-- From the right
		newAsteroid.x = display.contentWidth + 60
		newAsteroid.y = math.random( 500 )
		newAsteroid:setLinearVelocity( math.random( -120,-40 ), math.random( 20,60 ) )
	end

	newAsteroid:applyTorque( math.random( -6,6 ) )
end

local function gameLoop()
	createAsteroid()

	-- Remove asteroids which have drifted off screen
	for i = #asteroidsTable, 1, -1 do
		local thisAsteroid = asteroidsTable[i]

		if ( thisAsteroid.x < -100 or
			 thisAsteroid.x > display.contentWidth + 100 or
			 thisAsteroid.y < -100 or
			 thisAsteroid.y > display.contentHeight + 100 )
		then
			display.remove( thisAsteroid )
			table.remove( asteroidsTable, i )
		end
	end
end

local function endGame()
	composer.setVariable( "finalScore", score )
	composer.removeScene( "highscores" )
	composer.gotoScene( "highscores", { time=800, effect="crossFade" } )
end

local function detectButton( event )
 
	for i = 1,buttonGroup.numChildren do
		local bounds = buttonGroup[i].contentBounds
		if (
			event.x > bounds.xMin and
			event.x < bounds.xMax and
			event.y > bounds.yMin and
			event.y < bounds.yMax
		) then
			return buttonGroup[i]
		end
	end
end

local function fireLaser()
	if(ship ~= nil) then
		audio.play( fireSound )

		local newLaser = display.newImageRect( mainGroup, objectSheet, 5, 14, 40 )
		physics.addBody( newLaser, "dynamic", { isSensor=true } )
		newLaser.isBullet = true
		newLaser.myName = "laser"

		newLaser.x = ship.x
		newLaser.y = ship.y
		newLaser:toBack()

		transition.to( newLaser, { y=-40, time=500,
			onComplete = function() display.remove( newLaser ) end
		} )
	end
end

local function dragShip( event )
	local phase = event.phase
	local touchOverButton = detectButton( event )

	if ( phase == "began" ) then
        if ( touchOverButton ~= nil ) then
            if not ( buttonGroup.touchID ) then
                buttonGroup.touchID = event.id
				buttonGroup.activeButton = touchOverButton

				if ( buttonGroup.activeButton.ID == "leftBtn" ) then
					if(ship ~= nil) then
						-- ship:setLinearVelocity( -150, 0 )
						ship.deltaPerFrame = { -2, 0 }
					end
				elseif ( buttonGroup.activeButton.ID == "rightBtn" ) then
					if(ship ~= nil) then
						-- ship:setLinearVelocity( 150, 0 )
						ship.deltaPerFrame = { 2, 0 }
					end
                end
            end
            return true
		end
	elseif ( "ended" == phase or "cancelled" == phase ) then
			buttonGroup.touchID = nil
			buttonGroup.activeButton = nil
			if(ship ~= nil) then
				ship.deltaPerFrame = { 0, 0 }
			end
	end
end


local function restoreShip()

	ship.isBodyActive = false
	ship.x = display.contentCenterX
	ship.y = display.contentHeight - 150

	-- Fade in the ship
	transition.to( ship, { alpha=1, time=1000,
		onComplete = function()
			ship.isBodyActive = true
			died = false
		end
	} )
end

local function removeAllAsteroids()
	for i = #asteroidsTable, 1, -1 do
		local asteroid = asteroidsTable[i]
		transition.to( asteroid, { alpha=0, time=1000,
			onComplete = function()
				display.remove(asteroid)
				table.remove( asteroidsTable, i )
			end
		} )
	end
end

local function onCollision( event )

	if ( event.phase == "began" ) then

		local obj1 = event.object1
		local obj2 = event.object2

		if ( ( obj1.myName == "laser" and obj2.myName == "asteroid" ) or
			 ( obj1.myName == "asteroid" and obj2.myName == "laser" ) )
		then
						
		    audio.play( explosionSound )
			vent.emitX = obj2.x or obj1.x
			vent.emitY = obj2.y or obj1.y
			vent:start()

			display.remove( obj1 )
			display.remove( obj2 )
			for i = #asteroidsTable, 1, -1 do
					if ( asteroidsTable[i] == obj1 or asteroidsTable[i] == obj2 ) then
						table.remove( asteroidsTable, i )
						break
					end
			end

			timer.performWithDelay(8000, function()
				vent:stop()
			end, 0)


			-- Increase score
			score = score + 100
			scoreText.text = "Score: " .. score

		elseif ( ( obj1.myName == "ship" and obj2.myName == "asteroid" ) or
				 ( obj1.myName == "asteroid" and obj2.myName == "ship" ) )
		then
			if ( died == false ) then
				died = true

				-- Play explosion sound!
				audio.play( explosionSound )
				vent.emitX = obj2.x or obj1.x
				vent.emitY = obj2.y or obj1.y
				vent:start()

				if (obj1.myName == "asteroid") then
					display.remove(obj1)
				else
					display.remove(obj2)
				end

				for i = #asteroidsTable, 1, -1 do
					if ( asteroidsTable[i] == obj1 or asteroidsTable[i] == obj2 ) then
						table.remove( asteroidsTable, i )
						break
					end
				end
				-- Update lives
				lives = lives - 1
				livesText.text = "Lives: " .. lives

				if ( lives == 0 ) then
					display.remove( ship )
					ship = nil
					timer.performWithDelay( 2000, endGame )
				else
					ship.alpha = 0
					timer.performWithDelay( 1000, restoreShip )
					removeAllAsteroids()
				end
			end
		end
	end
end

local function frameUpdate()
	if ship ~= nil then
		if ship.x < (ship.width * 1.5) then
			ship.x = ship.width * 1.5
		elseif ship.x > display.contentWidth - (ship.width * 1.5) then
			ship.x = display.contentWidth - (ship.width * 1.5)
		else
			ship.x = ship.x + ship.deltaPerFrame[1]
			ship.y = ship.y + ship.deltaPerFrame[2]
		end
	end
end


-- -----------------------------------------------------------------------------------
-- Scene event functions
-- -----------------------------------------------------------------------------------

-- create()
function scene:create( event )

	local sceneGroup = self.view
	-- Code here runs when the scene is first created but has not yet appeared on screen

	physics.pause()  -- Temporarily pause the physics engine

	-- Set up display groups
	backGroup = display.newGroup()  -- Display group for the background image
	sceneGroup:insert( backGroup )  -- Insert into the scene's view group

	mainGroup = display.newGroup()  -- Display group for the ship, asteroids, lasers, etc.
	sceneGroup:insert( mainGroup )  -- Insert into the scene's view group

	uiGroup = display.newGroup()    -- Display group for UI objects like the score
	sceneGroup:insert( uiGroup )    -- Insert into the scene's view group

	buttonGroup = display.newGroup()
	sceneGroup:insert ( buttonGroup )

	local leftButton = display.newImageRect(buttonGroup, "leftButton.png", 100, 100)
	leftButton.x, leftButton.y = 160, display.contentHeight-70
	leftButton.canSlideOn = true
	leftButton.ID = "leftBtn"

	local rightButton = display.newImageRect(buttonGroup, "rightButton.png", 100, 100)
	rightButton.x, rightButton.y = 270, display.contentHeight-70
	rightButton.canSlideOn = true
	rightButton.ID = "rightBtn"

	local fireButton = display.newImageRect( buttonGroup, "fireButton.png", 100, 100 )
	fireButton.x, fireButton.y = display.contentWidth - 150, display.contentHeight - 70
	fireButton.canSlideOn = true
	fireButton.ID = "fireBtn"

	local groupBounds = buttonGroup.contentBounds
	local groupRegion = display.newRect( 0, 0, groupBounds.xMax-groupBounds.xMin+200, groupBounds.yMax-groupBounds.yMin+200 )
	groupRegion.x = groupBounds.xMin + ( buttonGroup.contentWidth/2 )
	groupRegion.y = groupBounds.yMin + ( buttonGroup.height/2 )
	groupRegion.isVisible = false
	groupRegion.isHitTestable = true
	
	-- Load the background
	local background = display.newImageRect( backGroup, "background.png", 800, 1400 )
	background.x = display.contentCenterX
	background.y = display.contentCenterY
	
	ship = display.newImageRect( mainGroup, "spaceShip.png", 100, 120 )
	ship.x = display.contentCenterX
	ship.y = display.contentHeight - 150
	physics.addBody( ship, "static" )
	ship.myName = "ship"
	ship.deltaPerFrame = {0, 0}

	-- Display lives and score
	livesText = display.newText( uiGroup, "Lives: " .. lives, 200, 80, font, 24 )
	scoreText = display.newText( uiGroup, "Score: " .. score, 400, 80, font, 24 )

	-- leftButton:addEventListener( "tap", fireLaser )
	groupRegion:addEventListener( "touch", dragShip )
	fireButton:addEventListener( "touch", fireLaser )

	explosionSound = audio.loadSound( "audio/explosion.wav" )
	fireSound = audio.loadSound( "audio/fire.wav" )
	musicTrack = audio.loadStream( "audio/80s-Space-Game_Looping.wav" )
end


-- show()
function scene:show( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is still off screen (but is about to come on screen)

	elseif ( phase == "did" ) then
		-- Code here runs when the scene is entirely on screen
		physics.start()
		Runtime:addEventListener( "collision", onCollision )
		Runtime:addEventListener( "enterFrame", frameUpdate )
		gameLoopTimer = timer.performWithDelay( 1000, gameLoop, 0 )
		-- Start the music!
		audio.play( musicTrack, { channel=1, loops=-1 } )
	end
end


-- hide()
function scene:hide( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is on screen (but is about to go off screen)
		timer.cancel( gameLoopTimer )

	elseif ( phase == "did" ) then
		-- Code here runs immediately after the scene goes entirely off screen
		Runtime:removeEventListener( "collision", onCollision )
		physics.pause()
		-- Stop the music!
		audio.stop( 1 )
	end
end


-- destroy()
function scene:destroy( event )

	local sceneGroup = self.view
	-- Code here runs prior to the removal of scene's view
	-- Dispose audio!
	audio.dispose( explosionSound )
	audio.dispose( fireSound )
	audio.dispose( musicTrack )

end


-- -----------------------------------------------------------------------------------
-- Scene event function listeners
-- -----------------------------------------------------------------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )
-- -----------------------------------------------------------------------------------

return scene
