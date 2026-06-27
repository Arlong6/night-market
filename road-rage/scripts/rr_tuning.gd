## RRTuning — single source of truth for all tunable values (橫衝直撞).
## Data-driven per project standards: change feel here, not in scattered scripts.
class_name RRTuning
extends RefCounted

# Vehicle
const ACCEL: float = 900.0          ## px/s^2 forward thrust
const MAX_SPEED: float = 520.0      ## px/s
const REVERSE_SPEED: float = 180.0
const TURN_RATE: float = 3.2        ## rad/s at speed
const FRICTION: float = 600.0       ## px/s^2 passive slowdown
const VEHICLE_MASS: float = 3.0     ## multiplies impact force
const VEHICLE_HP: float = 100.0
const SPEED_BLEED_ON_BREAK: float = 0.78  ## velocity retained after smashing a prop

# Impact / destruction
const BREAK_THRESHOLD_PROP: float = 220.0   ## min impact force to break a light prop
const BREAK_THRESHOLD_CAR: float = 700.0    ## parked car
const BREAK_THRESHOLD_PED: float = 60.0     ## peds tumble easily

# Heat / wanted (star thresholds = cumulative heat; index = stars 0..5)
const STAR_THRESHOLDS: Array[int] = [0, 60, 180, 400, 800, 1500]
const HEAT_DECAY_PER_SEC: float = 8.0

# Heat awarded per destroyed object kind
const HEAT_PROP: int = 8
const HEAT_CAR: int = 30
const HEAT_PED: int = 20

# Combo
const COMBO_WINDOW: float = 1.6
const COMBO_MAX_MULT: int = 10

# Score (base, before combo multiplier)
const SCORE_PROP: int = 10
const SCORE_CAR: int = 40
const SCORE_PED: int = 25

# Police
const POLICE_SPEED: float = 480.0
const POLICE_RAM_DAMAGE: float = 14.0
const POLICE_SPAWN_INTERVAL: float = 3.0   ## seconds between spawn checks
const POLICE_PER_STAR: int = 2             ## desired live cops = stars * this

# City
const TILE: int = 64                ## world units per grid cell
const CITY_COLS: int = 24
const CITY_ROWS: int = 24
const BUILDING_CHANCE: float = 0.28
const PROP_CHANCE: float = 0.30     ## chance a non-building cell gets a prop
