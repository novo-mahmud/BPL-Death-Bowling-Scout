# ============================================================
# PHASE 1: LOAD FULL MATCH DATA (FROM SCRATCH)
# ============================================================

library(tidyverse)
library(data.table)

# 1. Define Path to CSVs
csv_path <- "D:/Github/R/BPL_Scouting_Project/data_csv"

# 2. List all CSV files
all_files <- list.files(csv_path, pattern = "\\.csv$", full.names = TRUE)

# 3. Separate Ball-by-Ball files vs Info files
# Cricsheet format: '12345.csv' is ball-by-ball, '12345_info.csv' is info
ball_by_ball_files <- all_files[!grepl("_info", all_files)]

message("Found ", length(ball_by_ball_files), " ball-by-ball files.")

# 4. Load all files into one dataset
raw_data <- lapply(ball_by_ball_files, function(f) {
  # Read file
  df <- fread(f)
  
  # Extract Match ID from filename (remove path and .csv)
  match_id <- tools::file_path_sans_ext(basename(f))
  
  # Add match_id column
  df$match_id <- as.integer(match_id)
  
  return(df)
}) %>% bind_rows()

# 5. Standardize column names (lowercase)
names(raw_data) <- tolower(names(raw_data))

# ------------------------------------------------------------
# CRITICAL VERIFICATION
# ------------------------------------------------------------
# We need to ensure we have overs 0.1 to 19.6
# Let's parse the 'ball' column to check

verification <- raw_data %>%
  # Split ball (e.g. "0.1" or "0.1.1") into over and ball number
  separate(ball, into = c("over", "delivery"), sep = "\\.", remove = FALSE, convert = TRUE) %>%
  mutate(over = as.integer(over))

print("Data Structure Check:")
print(paste("Total Rows:", nrow(raw_data)))
print("Unique Overs found (Head):")
print(head(sort(unique(verification$over)), 10))
print("Unique Overs found (Tail):")
print(tail(sort(unique(verification$over)), 10))

# Save the FULL dataset
saveRDS(raw_data, "raw_combined_data.rds")

message("Phase 1 Complete. Full dataset saved to 'raw_combined_data.rds'")