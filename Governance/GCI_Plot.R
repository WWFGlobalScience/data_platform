library(tidyverse)
library(readxl)
library(ggrepel)
library(colorspace)
library(cowplot)

setwd("C:/Users/readd/Documents/WWF-US_Consultancy/2024-25_Consultancy")
corrupt <- read_xlsx(path = "Governance_Indicators_2.xlsx")

countries <- c("Colombia")
country_cols <- c("#E69F00", "#56B4E9", "#009E73")

gci <- corrupt[,c(1:3,21:43)]

colnames(gci) <- c("Country", "State", "ISO", 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020)

gci <- gci %>% pivot_longer(cols = 4:26, names_to = "Year", values_to = "Value") %>%
  mutate(Year = as.numeric(Year),
         Value = as.numeric(Value),
         label = NA) %>%
  arrange(State, Year) %>%  # Ensure data is sorted by State and Year
  group_by(State) %>%
  mutate(
    # Assign an index to each state to identify odd/even order
    state_index = as.integer(factor(State)),
    # Counter of non-NA values within each state, with special logic for ISO == "COL"
    non_na_instance = cumsum(!is.na(Value)),
    # Set label based on conditions
    label = case_when(
      # For ISO == "COL": label at the first non-NA for odd states, second for even states
      ISO == "COL" & ((state_index %% 2 == 1 & non_na_instance == 1) |
                        (state_index %% 2 == 0 & non_na_instance == 2)) ~ paste(State, ISO, sep = ", "),
      
      # For other ISO values: label at the first non-NA value
      ISO != "COL" & non_na_instance == 1 ~ paste(State, ISO, sep = ", "),
      
      # Otherwise, keep label as NA
      TRUE ~ NA_character_
    )
  ) %>%
  ungroup() %>%
  select(-state_index, -non_na_instance) %>%
  filter(Country %in% countries)

gci_plot <- ggplot(gci[!is.na(gci$Value),], aes(x = Year, y = Value, group = State, color = Country)) +
  geom_line() +
  geom_point(
    aes(fill = Country),
    size = 2.5, alpha = 0.5, 
    shape = 21 # This is a dot with both border (color) and fill.
  ) +
  geom_label_repel(
    aes(label = label),
    color = "black",
    fill = "white",
    segment.color = NA,
    nudge_x = .5,
    nudge_y = .5,
    size = 9/.pt, # font size 9 pt
    point.padding = 0.1, 
    box.padding = 0.2,
    min.segment.length = 0,
    max.overlaps = Inf) +
  scale_color_manual(
    values = darken(country_cols, 0.3) # dot borders are a darker than the fill
  ) +
  scale_fill_manual(
    values = country_cols
  ) +
  scale_y_continuous(
    name = "Grand Corruption Index\n(100 = least corrupt)"
  ) +
  labs(caption = "Source: Global Data Lab") +
  # Minimal grid theme that only draws horizontal lines
  theme_minimal_grid(12, rel_small = 1) +
  # Remove legend and x-axis label
  theme(
    legend.position = "none",
    axis.title.x = element_blank()
  ) 

gci_plot

