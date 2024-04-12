rm(list = ls())

library(tidyverse)
library(magrittr)
library(fplr)
library(regista)
library(stringr)
library(progress)
library(hash)
library(glue)

options(dplyr.summarise.inform = FALSE)

sapply(list.files("R", full.names = TRUE, recursive = TRUE), source)

# manually input these parameters
current_gameweek <- 33
exclude_ids <- c(526) # exclude certain players from selection, e.g. long-term injured
gw_30_ids <- c(308, 362, 412) # Salah, Palmer, Gordon
gw_31_ids <- c(293, 85, 19) # Darwin Nunez, Solanke, Saka
gw_32_ids <- c(516, 211, 590) # Son, Nicolas Jackson, Matheus Cunha
prev_selected_ids <- c(gw_30_ids, # these players will be unavailable except in wildcard week
                       gw_31_ids, 
                       gw_32_ids) 
min_gi <- 4
min_minutes <- 800
greedy_k_vals <- 3:6

sapply(exclude_ids, function(id) player_hash[[as.character(id)]])
sapply(prev_selected_ids, function(id) player_hash[[as.character(id)]]) %>% matrix(ncol = 3, byrow = TRUE, dimnames = list((current_gameweek - (length(prev_selected_ids) %/% 3)):(current_gameweek - 1), paste("Player", 1:3)))

# fit DC model and predict future scores
pred_scores <- predict_scorelines(current_gameweek)
# extract players meeting minimum requirements for selection
los_pool <- get_los_pool(min_gi, min_minutes, exclude_ids)
los_simplex <- fit_los_simplex(los_pool, current_gameweek)
# compute goal involvement probabilities for each player/gameweek
gw_probs <- get_los_gw_probs(pred_scores, los_simplex)
# find best selection
my_los <- optimise_los_selection(nreps = 2000, gw_probs, greedy_k = greedy_k_vals, prev_selected_ids, plot_surve_probs = TRUE)
# print squad in more readable format
matrix(my_los$squad$name, ncol = 3, byrow = TRUE, dimnames = list(current_gameweek:38, paste("Player", 1:3)))
# save squad and probabilities
saveRDS(my_los, glue("gameweeks/gw{current_gameweek}.RDS"))
