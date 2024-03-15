rm(list = ls())

library(tidyverse)
library(fplr)
library(regista)
library(stringr)
library(progress)
library(hash)
library(progress)

options(dplyr.summarise.inform = FALSE)

sapply(list.files("R", full.names = TRUE, recursive = TRUE), source)

# manually input these parameters
current_gameweek <- 29
exclude_ids <- NULL # use this to exclude certain players from selection, e.g. long-term injured
prev_selected_ids <- c(82, 85, 86) # these players will be unavailable except in wildcard week
min_gi <- 4
min_minutes <- 800

sapply(prev_selected_ids, function(id) player_hash[[as.character(id)]])

# fit DC model and predict future scores
pred_scores <- predict_scorelines(current_gameweek)
# extract players meeting minimum requirements for selection
los_pool <- get_los_pool(min_gi, min_minutes, exclude_ids)
los_simplex <- fit_los_simplex(los_pool, current_gameweek)
# compute goal involvement probabilities for each player/gameweek
gw_probs <- get_los_gw_probs(pred_scores, los_simplex)
# find best selection
my_los <- optimise_los_selection(nreps = 2, gw_probs, greedy_k = 4:7, prev_selected_ids, plot_surve_probs = TRUE)
# print squad in readable format
matrix(my_los$squad$name, ncol = 3, byrow = TRUE, dimnames = list(current_gameweek:38, paste("Player", 1:3)))
