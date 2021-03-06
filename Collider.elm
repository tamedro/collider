import Color exposing (..)
import Graphics.Collage exposing (..)
import Graphics.Element exposing (..)
import Keyboard
import Text
import String
import Time exposing (..)
import Window
import Html exposing (..)
import Html.Events exposing (onClick)
import Html exposing (Html, Attribute, text, toElement, div, input)
import Html.Attributes exposing (..)
import StartApp.Simple exposing (start)

-- Model

(gameWidth,gameHeight) = (600,400)
(halfWidth,halfHeight) = (300,200)

-- types 

type alias Game =
  { state : Bool
  , balls : List Ball
  , collisions : List Collision
  , debug : String
  , gun : Gun
  }

type alias Ball =
  { id : Int
  , x : Float
  , y : Float
  , vx : Float
  , vy : Float
  , r : Float
  , c : Color
  , col : Bool
  , colx : Float
  , coly : Float
  , mes : String
  }

type alias Collision = 
  { b1 : Ball
  , b2 : Ball
  }

type alias Gun =
  { dir : Int
  , rotSpeed : Int
  }

type alias UpdateInputs =
  { clickButton : Bool
  , ballSignal : RadiusMessage
  , inputs : Inputs
  }

type alias Inputs =
  { delta : Time
  , enter : Bool
  }
  
type alias RadiusMessage =
  { id : Int 
  , radius : String
  }

type alias Velocity =
  { vx : Float
  , vy : Float
  }

-- defaults

defaultGame : Game
defaultGame =
  { state = False
  , balls = []
  , collisions = []
  , debug = ""
  , gun = defaultGun
  }

defaultBall : Gun -> Int -> Ball
defaultBall gun num =
  { id = num
  , x = 0
  , y = 0
  , vx = 200 * (cos <| (degrees <| toFloat gun.dir + 90))
  , vy = 200 * (sin <| (degrees <| toFloat gun.dir + 90))
  , r = 5
  , c = white
  , col = False
  , colx = 0
  , coly = 0
  , mes = "None"
  }

defaultGun : Gun
defaultGun =
  { dir = 0
  , rotSpeed = 5
  }

defaultCollision : Ball -> Ball -> Collision
defaultCollision ball1 ball2 =
  { b1 = ball1
  , b2 = ball2
  }

defaultMessage : RadiusMessage 
defaultMessage = 
  { id = 0
  , radius = "5"
  }
  
makeMessage : Int -> String -> RadiusMessage
makeMessage idIn radiusIn =
  { id = idIn
  , radius = radiusIn
  }
  
-- Update

update : UpdateInputs -> Game -> Game
update {clickButton, ballSignal, inputs} ({state,balls,debug,gun} as game) =
  let
    newState = clickButton
    newGun = spinGun gun
    updateCollisions = collisions <| List.map (physicsUpdate inputs.delta) balls
  in 
    { game |
      gun = newGun,
      balls = updateBalls game.gun (clickButton /= state) inputs.delta game.balls updateCollisions ballSignal,
      state = newState
    }

updateBalls : Gun -> Bool -> Time -> List Ball -> List Collision -> RadiusMessage -> List Ball
updateBalls gun add dt balls updateCollisions ballSignal =
  let newballs = 
    if add then
      defaultBall gun (List.length balls) :: balls
    else 
      balls
  in
    List.map (updateBall dt newballs updateCollisions ballSignal) newballs

updateBall : Time -> List Ball -> List Collision -> RadiusMessage -> Ball -> Ball
updateBall dt balls updateCollisions ballSignal ball =
  let
    didCollide = collided updateCollisions ball
    collisionM = thisCollision updateCollisions ball
    newVelocity = stepVelocity collisionM ball
    newRadius = if ballSignal.id == ball.id then 
                  case String.toFloat ballSignal.radius of
                     Ok float -> float
                     Err mes -> 20
                else ball.r
  in 
    physicsUpdate dt
      { ball |
          vx = newVelocity.vx
        , vy = newVelocity.vy
        , r = newRadius
      }

collided : List Collision -> Ball -> Bool
collided collidedBalls ball =
  let 
    colM = thisCollision collidedBalls ball
  in
    case colM of 
      Just col -> True
      Nothing -> False

thisCollision : List Collision -> Ball -> Maybe Collision
thisCollision collisions ball =
  List.head <| List.filter (\c -> c.b1.id == ball.id || c.b2.id == ball.id) collisions

collisions : List Ball -> List Collision
collisions balls = 
  List.filterMap (collision balls) balls

collision : List Ball -> Ball -> Maybe Collision
collision balls ball = 
  let 
    colliderM = List.head <| removeSelf (List.filter (collide ball) balls) ball
  in
    case colliderM of
    Just oBall -> Just <| defaultCollision ball oBall
    Nothing -> Nothing

removeSelf : List Ball -> Ball -> List Ball
removeSelf balls ball =
  List.filter (\x -> x.id /= ball.id) balls

collide : Ball -> Ball -> Bool
collide ball1 ball2 =
  (distance ball1 ball2) <= (ball1.r + ball2.r)

distance : Ball -> Ball -> Float
distance ball1 ball2 =
  Basics.sqrt ((ball2.x-ball1.x)^2 + (ball2.y-ball1.y)^2)

physicsUpdate dt obj =
  { obj |
    x = obj.x + obj.vx * dt,
    y = obj.y + obj.vy * dt
  }

stepVelocity : Maybe Collision -> Ball -> Velocity
stepVelocity collisionM ball =
  let 
    newVx = 
      if (ball.x < ball.r - halfWidth) then
        abs ball.vx
      else if (ball.x > halfWidth - ball.r) then 
        -(abs ball.vx)
      else
        case collisionM of
          Just collision -> collisionVelocity collision ball
          Nothing -> ball.vx
    newVy =
      if (ball.y < ball.r - halfHeight) then
        abs ball.vy
      else if (ball.y > halfHeight - ball.r) then
        -(abs ball.vy)
      else
        case collisionM of
          Just collision -> collisionVelocityY collision ball
          Nothing -> ball.vy
  in 
    { vx = newVx , vy = newVy }
 

collisionVelocity : Collision -> Ball -> Float
collisionVelocity collision ball =
  let
    oball = 
      if (collision.b1.id == ball.id) then 
        collision.b2
      else 
        collision.b1
  in
    ((ball.vx * (ball.r - oball.r)) + (2 * oball.r * oball.vx)) / (ball.r + oball.r)
    
collisionVelocityY : Collision -> Ball -> Float
collisionVelocityY collision ball =
  let
    oball = 
      if (collision.b1.id == ball.id) then 
        collision.b2
      else 
        collision.b1
  in
    ((ball.vy * (ball.r - oball.r)) + (2 * oball.r * oball.vy)) / (ball.r + oball.r)    
    
near k c n =
  n >= k-c && n <= k+c

spinGun : Gun -> Gun
spinGun gun = 
    { gun | 
      dir = ((gun.dir + gun.rotSpeed) % 360) 
    }
    
-- View

view (w,h) game =
  flow down ([
    (container w h middle <|
      collage gameWidth gameHeight
        ([ rect gameWidth gameHeight
          |> filled (rgb 60 60 60)
        ] ++ List.map formBall game.balls ++ List.map formCollisions game.balls)
    )
    , toElement 10 50 <| button [style (buttonStyle ++ centerStyle), onClick addSignal.address <| not game.state] 
                                [Html.text "+"]
    , toElement 10 10 <| div [] [Html.text game.debug]
  ] ++ List.map ballDiv game.balls)

-- View Utilities

formBall : Ball -> Form
formBall ball = 
  oval (2*ball.r) (2*ball.r) 
    |> filled ball.c
    |> move (ball.x, ball.y)

formCollisions : Ball -> Form
formCollisions ball =
  if ball.col then
    oval 5 5 
      |> filled blue
      |> move (ball.colx, ball.coly)
  else oval 0 0 |> filled white

ballDiv : Ball -> Element
ballDiv ball =
  toElement 50 50 <| div [style (centerStyle ++ ballStyle)] 
    [ div [style innerBallStyle] [ Html.text <| toString ball.id ]
    , input 
        [ type' "range"
        , Html.Attributes.step "1"
        , Html.Attributes.min "0"
        , Html.Attributes.max "20"
        , value <| toString ball.r 
        , Html.Events.on "change" Html.Events.targetValue (\str -> Signal.message radiusSignal.address (makeMessage ball.id str))
        ] []
    ]
  
-- Signals

main = Signal.map2 view Window.dimensions gameState 

gameState : Signal Game
gameState = Signal.foldp update defaultGame inputs

addSignal : Signal.Mailbox Bool
addSignal = Signal.mailbox False

radiusSignal = Signal.mailbox defaultMessage

delta = Signal.map inSeconds (fps 35)

inputs : Signal UpdateInputs
inputs =
  Signal.map3 UpdateInputs
    addSignal.signal
    radiusSignal.signal
    (Signal.sampleOn delta <|
      Signal.map2 Inputs
        delta
        Keyboard.enter)

-- Styling

centerStyle : List (String, String)
centerStyle =
    [ ("position", "absolute")
    , ("left", "50%")
    , ("transform", "translate(-50%,-50%)")
    ]

buttonStyle : List (String, String)
buttonStyle =
    [ ("background-color", "#4CAF50")
    , ("border", "none")
    , ("color", "white")
    , ("padding", "10px 32px")
    , ("text-align", "center")
    , ("text-decoration", "none")
    , ("display", "inline-block")
    , ("font-size", "16px")
    ]

ballStyle : List (String, String)
ballStyle = 
    [ ("border-style", "solid")
    , ("padding-top", "10px")
    , ("padding-bottom", "10px")
    , ("padding-left", "10px")
    , ("padding-right", "20px")
    , ("text-align", "center")
    , ("text-decoration", "none")
    , ("font-size", "16px")
    , ("left", "50%")
    , ("width", "200px")
    , ("margin", "5px")
    ]
 
innerBallStyle : List (String, String)
innerBallStyle = 
  [ ("display", "inline-block")
  , ("text-align", "center")
  , ("float", "left")
  , ("padding-left", "15px")
  ]
