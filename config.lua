-- config.lua (shared)
Config = {}

-- Test requirements
Config.RequireWrittenTest = true
Config.RequireDrivingTest = true

-- Written test scoring
-- If you want to hardcode a required number, set WrittenPassScore to a number.
-- Otherwise the script will compute required = ceil(#questions * WrittenPassPercentage)
Config.WrittenPassScore = nil
Config.WrittenPassPercentage = 0.9  -- 90%

-- Driving test settings (all speeds are in MPH now)
Config.PointsToFail = 5                       -- fail when reaching this many points
Config.StopSpeedLimitMPH = 5.0                -- mph considered "stopped" for must-stop checkpoints (default 5 mph)
Config.DrivingSpeedLimitMPH = 50              -- speed limit (mph) for the route
Config.SpeedViolationPoints = 1               -- points added for each speed violation
Config.SpeedViolationCooldown = 5             -- seconds between speed violation points
Config.CheckpointRadius = 7.5                 -- radius (meters) to trigger a checkpoint
Config.StopCheckTimeSeconds = 4               -- how many seconds to sample speed for a must-stop (grace period)
Config.Debug = false

-- Allow starting via chat commands
Config.AllowCommandStart = true

-- Use lib.inputDialog (ox_lib / whatever provides lib.inputDialog). If false,
-- the script falls back to simple chat prompts (less ideal).
Config.UseLibInputDialog = true

-- DMV locations where players can open DMV menu (vector3)
-- Each entry can include heading, ped model override, blip settings
Config.DMVLocations = {
  {
    pos = vector3(240.706, -1379.409, 33.742),
    heading = 142.789,
    pedModel = "s_m_m_autoshop_02",
    blip = { sprite = 850, color = 5, name = "DMV" }
  }
}

-- Driving start: XYZH + vehicle model used for the driving test.
-- Change coords/model as desired. If vehicleModel is empty or nil, the script
-- will attempt to use the player's current vehicle instead of spawning one.
Config.DrivingStart = {
    pos = vector3(-512.690, -262.885, 35.437),  -- spawn point for the test vehicle / where player is placed
    heading = 114.216,
    vehicleModel = "blista",               -- example; set to nil to use player's current vehicle
    spawnVehicle = true                    -- if false and player not in vehicle, test will not start
}

-- Optional finish point (where waypoint is set after final checkpoint). If nil,
-- the last checkpoint is considered the finish.
Config.DrivingFinish = vector3(-499.150, -256.917, 36.074)

-- Driving route: sequence of points with mustStop true if you must stop there
Config.DrivingRoute = {
  { pos = vector3(-550.505, -283.883, 35.437), mustStop = true },
  { pos = vector3(-613.745, -195.329, 37.593), mustStop = true  },
  { pos = vector3(-525.663, -143.424, 38.565), mustStop = true },
  { pos = vector3(-464.044, -231.067, 36.074), mustStop = true  },
}

-- Written test questions (trimmed to your provided list; add/remove as needed)
Config.Questions = {
    {
        question = "What should you do if your car's engine overheats?",
        options = {
            { value = "turn_off", label = "Turn off the engine and wait for it to cool down" },
            { value = "cold_water", label = "Pour cold water on the engine" },
            { value = "keep_driving", label = "Keep driving until you reach a mechanic" }
        },
        correctOption = "turn_off"
    },
    {
        question = "When approaching a pedestrian crossing, what should you do?",
        options = {
            { value = "slow_down", label = "Slow down and be prepared to stop" },
            { value = "speed_up", label = "Speed up to pass quickly" },
            { value = "ignore_pedestrians", label = "Ignore pedestrians and continue driving" }
        },
        correctOption = "slow_down"
    },
    {
        question = "What does a yellow traffic light mean?",
        options = {
            { value = "slow_down", label = "Slow down and prepare to stop" },
            { value = "proceed_with_caution", label = "Proceed with caution" },
            { value = "stop", label = "Stop immediately" }
        },
        correctOption = "proceed_with_caution"
    },
    {
        question = "What does a red traffic light mean?",
        options = {
            { value = "stop", label = "Stop" },
            { value = "go", label = "Go" },
            { value = "yield", label = "Yield" }
        },
        correctOption = "stop"
    },
    -- {
    --     question = "What should you do when you see a yield sign?",
    --     options = {
    --         { value = "slow_down_and_yield", label = "Slow down and yield to traffic" },
    --         { value = "speed_up", label = "Speed up and try to merge quickly" },
    --         { value = "ignore_yield_sign", label = "Ignore the yield sign and proceed" }
    --     },
    --     correctOption = "slow_down_and_yield"
    -- },
    -- {
    --     question = "What should you do when approaching a sharp curve?",
    --     options = {
    --         { value = "slow_down", label = "Slow down before entering the curve" },
    --         { value = "accelerate", label = "Accelerate to maintain speed" },
    --         { value = "close_your_eyes", label = "Close your eyes and hope for the best" }
    --     },
    --     correctOption = "slow_down"
    -- },
    -- {
    --     question = "What does a flashing red traffic light mean?",
    --     options = {
    --         { value = "stop", label = "Stop" },
    --         { value = "yield", label = "Yield" },
    --         { value = "proceed_with_caution", label = "Proceed with caution" }
    --     },
    --     correctOption = "stop"
    -- },
    -- {
    --     question = "What should you do if your vehicle starts to skid?",
    --     options = {
    --         { value = "steer_in_direction_of_skid", label = "Steer in the direction of the skid" },
    --         { value = "steer_opposite_direction", label = "Steer in the opposite direction of the skid" },
    --         { value = "press_gas_pedal_harder", label = "Press the gas pedal harder" }
    --     },
    --     correctOption = "steer_in_direction_of_skid"
    -- },
    -- {
    --     question = "What is the purpose of a crosswalk?",
    --     options = {
    --         { value = "allow_pedestrians_to_cross_safely", label = "Allow pedestrians to cross safely" },
    --         { value = "park_vehicles", label = "Park vehicles" },
    --         { value = "race_with_friends", label = "Race with friends" }
    --     },
    --     correctOption = "allow_pedestrians_to_cross_safely"
    -- },
    -- {
    --     question = "What should you do if you miss your exit on the highway?",
    --     options = {
    --         { value = "continue_to_next_exit", label = "Continue to the next exit" },
    --         { value = "reverse_on_the_highway", label = "Reverse on the highway" },
    --         { value = "stop_and_wait_for_help", label = "Stop and wait for help" }
    --     },
    --     correctOption = "continue_to_next_exit"
    -- },
    -- {
    --     question = "What is the purpose of a stop sign?",
    --     options = {
    --         { value = "stop", label = "Stop completely before proceeding" },
    --         { value = "slow_down", label = "Slow down and proceed without stopping" },
    --         { value = "ignore_sign", label = "Ignore the sign and proceed" }
    --     },
    --     correctOption = "stop"
    -- },
    -- {
    --     question = "What should you do if your tire blows out while driving?",
    --     options = {
    --         { value = "keep_driving", label = "Keep driving until you reach a service station" },
    --         { value = "brake_hard", label = "Brake hard to stop the vehicle" },
    --         { value = "steer_steadily", label = "Grip the steering wheel firmly and steer steadily" }
    --     },
    --     correctOption = "steer_steadily"
    -- },
    -- {
    --     question = "What should you do if your headlights suddenly go out while driving at night?",
    --     options = {
    --         { value = "flash_high_beams", label = "Flash high beams to alert other drivers" },
    --         { value = "drive_slowly", label = "Drive slowly until you can stop safely" },
    --         { value = "turn_on_hazard_lights", label = "Turn on hazard lights and pull over" }
    --     },
    --     correctOption = "turn_on_hazard_lights"
    -- },
    -- {
    --     question = "What does a white painted curb mean?",
    --     options = {
    --         { value = "loading_zone", label = "Loading zone" },
    --         { value = "parking_allowed", label = "Parking allowed" },
    --         { value = "no_stopping_or_parking", label = "No stopping or parking" }
    --     },
    --     correctOption = "loading_zone"
    -- },
    -- {
    --     question = "What should you do if your vehicle starts hydroplaning on wet roads?",
    --     options = {
    --         { value = "brake_hard", label = "Brake hard to regain control" },
    --         { value = "steer_in_direction_of_skid", label = "Steer in the direction of the skid" },
    --         { value = "accelerate", label = "Accelerate to gain traction" }
    --     },
    --     correctOption = "steer_in_direction_of_skid"
    -- },
    -- {
    --     question = "What should you do when approaching a blind intersection?",
    --     options = {
    --         { value = "honk_horn", label = "Honk your horn before proceeding" },
    --         { value = "proceed_with_caution", label = "Proceed with caution" },
    --         { value = "speed_up", label = "Speed up to clear the intersection quickly" }
    --     },
    --     correctOption = "proceed_with_caution"
    -- },
    -- {
    --     question = "What should you do if your vehicle's accelerator becomes stuck?",
    --     options = {
    --         { value = "panic_and_brake", label = "Panic and slam on the brakes" },
    --         { value = "turn_off_ignition", label = "Turn off the ignition" },
    --         { value = "shift_to_neutral", label = "Shift to neutral and safely pull over" }
    --     },
    --     correctOption = "shift_to_neutral"
    -- },
    -- {
    --     question = "What does a solid yellow line on the road indicate?",
    --     options = {
    --         { value = "no_passing", label = "No passing" },
    --         { value = "passing_allowed", label = "Passing allowed" },
    --         { value = "yield_to_pedestrians", label = "Yield to pedestrians" }
    --     },
    --     correctOption = "no_passing"
    -- },
    -- {
    --     question = "What should you do if you witness a traffic accident?",
    --     options = {
    --         { value = "stop_and_help", label = "Stop and render aid if possible" },
    --         { value = "drive_away", label = "Drive away and ignore the accident" },
    --         { value = "take_pictures", label = "Take pictures and post them on social media" }
    --     },
    --     correctOption = "stop_and_help"
    -- },
    -- {
    --     question = "What should you do if you encounter a school bus with flashing red lights?",
    --     options = {
    --         { value = "stop_and_wait", label = "Stop and wait until the lights stop flashing" },
    --         { value = "drive_around", label = "Drive around the bus quickly" },
    --         { value = "ignore_lights", label = "Ignore the lights and keep driving" }
    --     },
    --     correctOption = "stop_and_wait"
    -- },
    -- {
    --     question = "What does a green traffic light indicate?",
    --     options = {
    --         { value = "go", label = "Go if the intersection is clear" },
    --         { value = "prepare_to_stop", label = "Prepare to stop" },
    --         { value = "speed_up", label = "Speed up to make the light" }
    --     },
    --     correctOption = "go"
    -- },
    -- {
    --     question = "What is the purpose of a roundabout?",
    --     options = {
    --         { value = "reduce_traffic_congestion", label = "Reduce traffic congestion" },
    --         { value = "increase_speed", label = "Increase vehicle speed" },
    --         { value = "perform_doughnuts", label = "Perform vehicular stunts" }
    --     },
    --     correctOption = "reduce_traffic_congestion"
    -- },
    -- {
    --     question = "What should you do if your vehicle's brakes fail?",
    --     options = {
    --         { value = "remain_calm", label = "Remain calm and pump the brakes" },
    --         { value = "brake_hard", label = "Brake hard to test the brakes" },
    --         { value = "panic_and_steer", label = "Panic and steer into a ditch" }
    --     },
    --     correctOption = "remain_calm"
    -- },
    -- {
    --     question = "What does a diamond-shaped sign indicate?",
    --     options = {
    --         { value = "warning", label = "Warning" },
    --         { value = "construction_zone", label = "Construction zone" },
    --         { value = "safe_zone", label = "Safe zone" }
    --     },
    --     correctOption = "warning"
    -- },
    -- {
    --     question = "What should you do if you hit a parked car?",
    --     options = {
    --         { value = "leave_a_note", label = "Leave a note with your contact information" },
    --         { value = "drive_away", label = "Drive away and pretend it never happened" },
    --         { value = "wait_for_owner", label = "Wait for the owner to return" }
    --     },
    --     correctOption = "leave_a_note"
    -- },
    -- {
    --     question = "What should you do if you encounter a deer on the road?",
    --     options = {
    --         { value = "flash_high_beams", label = "Flash high beams to scare the deer away" },
    --         { value = "brake_hard", label = "Brake hard to avoid hitting the deer" },
    --         { value = "honk_horn", label = "Honk your horn to warn the deer" }
    --     },
    --     correctOption = "brake_hard"
    -- },
    -- {
    --     question = "What should you do if you are being tailgated?",
    --     options = {
    --         { value = "maintain_steady_speed", label = "Maintain a steady speed and don't brake suddenly" },
    --         { value = "speed_up", label = "Speed up to get away from the tailgater" },
    --         { value = "slam_brakes", label = "Slam on your brakes to teach them a lesson" }
    --     },
    --     correctOption = "maintain_steady_speed"
    -- }
    -- add more if you like
}
