# FPL Last One Standing

Algorithm for automated player selection for an FPL `Last One Standing' competition. 

## Rules

 - Each FPL Gameweek, select 3 Premier League players.
 - If any of those players score or assist (according to FPL), then you progress to the next round.
 - You may only choose each player once, except in Gameweek 35, where you may select players you have already used.
 - The winner is the last person remaining. If several managers are remaining at the end of the season, there is a tie breaker (described in the official rules) to decide the winner.
 - Player selections must be made before the official FPL deadline for that gameweek. Other managers' selections are available to view after the submission deadline.
 
## Methodology

### Summary

The automated selection algorithm comprises three parts:

1. A **team-level model** giving probabilistic predictions of the scorelines of future fixtures.
2. A **player-level model** describing the probability that a player scored, assisted, or was not involved in a goal that their team scored while they were on the pitch. 
3. An **optimisation procedure** for finding the set of player selections that maximises the probability of surviving all remaining gameweeks. 

### Team-level model

The team model is based on Dixon-Coles, a Poisson-based statistical model for football scorelines. The model model assigns attacking and defensive strengths to each team, and accounts for home advantage. More details about the model, and how it can be used to generate scoreline predictions for future matches, can be found [here](https://www.statsandsnakeoil.com/2019/01/01/predicting-the-premier-league-with-dixon-coles/).

### Player-level model

For each player (or at least a subset of players, say those with at least 4 goal involvements this season), we model the conditional distribution that they were involved in a goal given the number of goals scored by their team and the number of minutes they played. This requires inferring a simplex $\boldsymbol{\theta}=(\theta_s,\theta_a,\theta_n)$ and modelling their playing minutes $T$. Details about inference for the player model and can be found [here](https://www.turing.ac.uk/news/airsenal) and in [the associated GitHub notebooks](https://github.com/alan-turing-institute/AIrsenal).

### Predicting goal involvement for each gameweek

Consider a player with goal-involvement simplex $\boldsymbol{\theta}$ and predicted minutes $T$. Consider a fixture where the probability their team scores $g$ goals is $p_g$, for $g \in \mathbb{N}$. The probability that the player is involved in a goal in that fixture is given by
\[
\mathbb{P}(\text{at least one goal involvement}) = 1 - \left[\sum_{g=0}^\infty p_g\left(\frac{T(\theta_{n} - 1) + 90}{90} \right)^g\right].
\]
In practice $p_g\approx 0$ for large $g$, so the sum can be truncated. If a player's team has multiple fixtures in a single gameweek, then compute one minus the probability they fail to record a goal involvement across all the fixtures. If a player has no fixtures in a gameweek, then obviously their goal involvement probability is zero.

Repeating this procedure yields a matrix of probabilities $P=(p_{ij})$, where $p_{ij}$ represents the probability that player $i$ fails to record a goal involvement in future gameweek $j$.

### Optimising squad selection

From the matrix $P$, we can deduce gameweek survival probabilities for any set of players. For example, if we want to maximise the probability of surviving the first gameweek, we choose the three players with the largest entries in the first column of $P$. However, this `greedy' approach is suboptimal, because it doesn't account for the fact that selecting the top players will incur a cost in terms of our survival probabilities in later weeks (since we cannot select players more than once). Instead, the procedure used is as follows:

1. Find the top $K\geq 3$ players for this gameweek. Randomly select 3 of them.
2. Repeat the process for all future gameweeks, respecting the rule that players cannot be picked more than once (except for Gameweek 35).
3. Evaluate the quality of the set of selections by the probability of surviving all gameweeks (i.e. the product of the gameweek survival probabilities).

We repeat the above procedure many times (e.g. 1000) and find the best strategy according to the criterion in step 3. 

We also repeat this procedure for various values of $K$, say $3 \leq K \leq 8$. This hyperparameter determines the greediness of the algorithm: if $K=3$ it will select the best players now with no consideration for the future; if $K$ is large we will select weaker players now in the hope that their availability for selection in later weeks pays dividends. The optimal $K$ is that which yields a strategy with the best overall survival probability. 

The algorithm will give a strategy for the rest of the competition, but the idea is that the model re-run to give a new strategy each week. This allows the model to use the information from the latest gameweek and become more greedy as the competition progresses. 

## Instructions for running the code

1. Open the `automated_los.R` script.
2. Input the current gameweek.
3. Input the IDs of players you want to exclude from selection, e.g. injured players. To find the ID of a given player, type `player_hash` in the Console.
4. Input the IDs of players you have entered in previous gameweeks. These players will be ineligible for selection, apart from in Gameweek 35.
5. Input the minimum number of goal involvement and minutes players should have in order to be considered for selection. (This is not strictly necessary, but setting restrictions reduces the player pool and speeds up the code significantly.)
6. Input the $K$ values to be used for the strategy optimisation.
7. Run the script. It will output: (i) a plot of the Dixon-Cole team parameters, (ii) the optimal strategy, (iii) the survival probability for the optimal strategy, and a plot of the gameweek/cumulative survival probabilities, (iii) the $K$ value used for the optimal strategy.
