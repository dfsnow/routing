library(tidyverse)
library(tidycensus)

year = 2010
states <- unique(fips_codes$state)[1:51]

car_vars <- c("1" = "B08201_008",
              "2" = "B08201_014", 
              "3" = "B08201_020",
              "4" = "B08201_026")

totalpop <- map_df(states, function(x) {
  get_acs("tract", variables = car_vars, year = year, summary_var = "B01001_001", state = x)
})

total_no_cars <- totalpop %>%
  mutate(no_car = as.numeric(variable) * estimate) %>%
  rename(geoid = GEOID) %>%
  rename(total_pop = summary_est) %>%
  select(geoid, total_pop, no_car) %>%
  group_by(geoid) %>%
  summarize(total_pop = mean(total_pop),
            no_car = sum(no_car))

total_no_cars %>% write_csv("us_car_pop.csv")
