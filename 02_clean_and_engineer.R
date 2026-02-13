# ============================================================
# PHASE 2 & 3: CLEANING & FEATURE ENGINEERING (COMBINED)
# ============================================================

library(tidyverse)
library(data.table)

# Define Project Directory
project_dir <- "D:/Github/R/BPL_Scouting_Project"

# 1. Load the full master data using full path
full_data <- readRDS(file.path(project_dir, "raw_full_master.rds"))

message("Starting Cleaning Process...")

# ------------------------------------------------------------
# STEP A: TEAM NAME STANDARDIZATION
# ------------------------------------------------------------
team_mapping <- c(
  "Barisal Bulls" = "Barishal", "Barisal Burners" = "Barishal", "Fortune Barishal" = "Barishal",
  "Chittagong Kings" = "Chittagong", "Chittagong Vikings" = "Chittagong", "Chittagong Challengers" = "Chittagong", 
  "Chattogram Challengers" = "Chittagong", "Chattogram Royals" = "Chittagong",
  "Comilla Victorians" = "Comilla", "Cumilla Warriors" = "Comilla",
  "Dhaka Gladiators" = "Dhaka", "Dhaka Dynamites" = "Dhaka", "Dhaka Platoon" = "Dhaka", 
  "Dhaka Dominators" = "Dhaka", "Minister Group Dhaka" = "Dhaka", "Durdanto Dhaka" = "Dhaka", "Dhaka Capitals" = "Dhaka",
  "Khulna Royal Bengals" = "Khulna", "Khulna Titans" = "Khulna", "Khulna Tigers" = "Khulna",
  "Rangpur Riders" = "Rangpur", "Rangpur Rangers" = "Rangpur",
  "Duronto Rajshahi" = "Rajshahi", "Rajshahi Kings" = "Rajshahi", "Rajshahi Royals" = "Rajshahi", 
  "Durbar Rajshahi" = "Rajshahi", "Rajshahi Warriors" = "Rajshahi",
  "Sylhet Royals" = "Sylhet", "Sylhet Super Stars" = "Sylhet", "Sylhet Sixers" = "Sylhet", 
  "Sylhet Thunder" = "Sylhet", "Sylhet Strikers" = "Sylhet", "Sylhet Titans" = "Sylhet", "Sylhet Sunrisers" = "Sylhet",
  "Noakhali Express" = "Noakhali"
)

full_data <- full_data %>%
  mutate(
    batting_team_std = ifelse(batting_team %in% names(team_mapping), team_mapping[batting_team], batting_team),
    bowling_team_std = ifelse(bowling_team %in% names(team_mapping), team_mapping[bowling_team], bowling_team)
  )

# ------------------------------------------------------------
# STEP B: CALCULATE TRUE BATTING ORDER (CRITICAL)
# ------------------------------------------------------------
message("Calculating Batting Orders...")

# Parse Over/Ball for sorting
full_data_sorted <- full_data %>%
  separate(ball, into = c("over_num", "ball_num"), sep = "\\.", remove = FALSE, convert = TRUE) %>%
  mutate(over_num = as.integer(over_num)) %>%
  arrange(match_id, innings, over_num, ball_num)

# Find first appearance of each striker
batting_orders <- full_data_sorted %>%
  group_by(match_id, innings, striker) %>%
  slice(1) %>%
  ungroup() %>%
  group_by(match_id, innings) %>%
  mutate(batting_position = row_number()) %>%
  select(match_id, innings, striker, batting_position)

# ------------------------------------------------------------
# STEP C: CREATE DEATH OVERS DATASET
# ------------------------------------------------------------
message("Filtering Death Overs...")

death_overs_data <- full_data_sorted %>%
  filter(over_num >= 15) # Overs 16-20 (0-indexed: 15-19)

# ------------------------------------------------------------
# STEP D: CALCULATE VENUE DIFFICULTY
# ------------------------------------------------------------
venue_stats <- death_overs_data %>%
  mutate(total_runs = runs_off_bat + extras) %>%
  group_by(venue) %>%
  summarise(
    venue_avg_rpo = (sum(total_runs) / n()) * 6
  )

# ------------------------------------------------------------
# STEP E: FINAL MERGE & SAVE (PRODUCTION READY)
# ------------------------------------------------------------
message("Merging Features...")

# 1. Define valid bowler wicket types OUTSIDE the mutate
valid_wicket_types <- c("bowled", "caught", "lbw", "stumped", "hit wicket", "caught and bowled")

final_data <- death_overs_data %>%
  # Add Batting Order (For the Striker)
  left_join(batting_orders, by = c("match_id", "innings", "striker")) %>%
  rename(striker_position = batting_position) %>%
  
  # Add Venue Stats
  left_join(venue_stats, by = "venue") %>%
  
  # Calculate Wickets
  replace_na(list(striker_position = 0)) %>%
  mutate(
    # FIX 2: Check if wicket occurred AND if it's a valid bowler type
    is_wicket = ifelse(!is.na(player_dismissed) & 
                         player_dismissed != "" & 
                         wicket_type %in% valid_wicket_types, 1, 0),
    
    # FIX 3: Quality Wicket uses Striker Position (Since bowler only dismisses striker)
    is_quality_wicket = ifelse(is_wicket == 1 & striker_position <= 6, 1, 0)
  )

# Save
saveRDS(final_data, file.path(project_dir, "engineered_data_final.rds"))
message("Process Complete. Logic verified: Run Outs excluded.")

