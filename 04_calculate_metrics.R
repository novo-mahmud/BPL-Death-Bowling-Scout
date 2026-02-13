# ============================================================
# PHASE 4: CALCULATE SCOUT METRICS
# ============================================================

library(tidyverse)

# 1. Load the Engineered Data
project_dir <- "D:/Github/R/BPL_Scouting_Project"
data <- readRDS(file.path(project_dir, "engineered_data_final.rds"))

message("Calculating Bowler Metrics...")

# ------------------------------------------------------------
# STEP A: CORE AGGREGATION
# ------------------------------------------------------------
# Group by Bowler and summarize performance

bowler_stats <- data %>%
  group_by(bowler) %>%
  summarise(
    # 1. Basic Workload
    balls_bowled = n(),
    innings_bowled = n_distinct(match_id, innings),
    
    # 2. Basic Runs & Wickets
    total_runs_conceded = sum(runs_off_bat, na.rm = TRUE) + sum(extras, na.rm = TRUE),
    total_wickets = sum(is_wicket, na.rm = TRUE),
    quality_wickets = sum(is_quality_wicket, na.rm = TRUE),
    
    # 3. Context (Average Venue Difficulty)
    avg_venue_rpo = mean(venue_avg_rpo, na.rm = TRUE)
  ) %>%
  ungroup()

# ------------------------------------------------------------
# STEP B: CALCULATE ADVANCED METRICS
# ------------------------------------------------------------
bowler_metrics <- bowler_stats %>%
  mutate(
    # Calculate Economy Rate (Runs / Overs)
    overs = balls_bowled / 6,
    economy_rate = total_runs_conceded / overs,
    
    # Quality Wicket Percentage
    # What % of their wickets are "Top Order"?
    quality_wicket_pct = ifelse(total_wickets > 0, (quality_wickets / total_wickets) * 100, 0),
    
    # Relative Performance vs Venue
    # Negative value = Better than average (Good)
    # Positive value = Worse than average (Bad)
    relative_economy = economy_rate - avg_venue_rpo
  )

# ------------------------------------------------------------
# STEP C: RELIABILITY SCORE (Sample Size)
# ------------------------------------------------------------
# We want to prioritize bowlers with more data.
# Let's create a simple score: 
# 0-5 innings = Low Reliability
# 5-10 innings = Medium
# 10+ innings = High

bowler_metrics <- bowler_metrics %>%
  mutate(
    reliability = case_when(
      innings_bowled < 5 ~ "Low (1-4 inns)",
      innings_bowled < 10 ~ "Medium (5-9 inns)",
      TRUE ~ "High (10+ inns)"
    )
  )

# ------------------------------------------------------------
# STEP D: FILTER & FINAL SORT
# ------------------------------------------------------------
# We only want serious candidates (e.g., at least 30 balls bowled in death)
final_scout_report <- bowler_metrics %>%
  filter(balls_bowled >= 30) %>% # Minimum 5 overs total in death
  arrange(economy_rate) # Sort by best economy

# Save the report
saveRDS(final_scout_report, file.path(project_dir, "scout_report.rds"))

message("Scout Report Generated!")

# ------------------------------------------------------------
# PREVIEW THE TOP TALENT
# ------------------------------------------------------------
print("Top 10 Death Bowlers by Economy Rate:")
print(head(final_scout_report %>% 
             select(bowler, economy_rate, quality_wicket_pct, relative_economy, reliability), 10))