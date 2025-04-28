library(tidyverse)
library(readxl)
library(ggrepel)

setwd("C:/Users/readd/Documents/WWF_Consultancy/2024-25_Consultancy")
gov <- read_xlsx(path = "Governance_Indicators.xlsx")

countries <- c("Madagascar")

PLIPLC <- gov[,c(1,42:43)]

colnames(PLIPLC) <- c("Country", 2015, 2020)

PLIPLC <- PLIPLC %>% pivot_longer(cols = -Country, names_to = "Year", values_to = "Value")

PLIPLC$Value <- as.numeric(PLIPLC$Value)

PLIPLC$Year <- as.numeric(PLIPLC$Year)

PLIPLC_labels <- PLIPLC %>%
  group_by(Country) %>%
  filter(Year == min(Year))

PLIPLC <- PLIPLC %>% filter(Country %in% countries)
PLIPLC_labels <- PLIPLC_labels %>% filter(Country %in% countries)

PLIPLC_plot <- ggplot(PLIPLC, aes(x = Year, y = Value, color = Country, group = Country)) +
  geom_line() +
  geom_point() +
  geom_label_repel(data = PLIPLC_labels, aes(label = Country),
                   nudge_x = 0.5, # Slight horizontal nudging
                   nudge_y = 0.5,
                   alpha = 0.8,
                   size = 4,
                   fill = "white",
                   segment.color = NA,
                   box.padding = 0.3, # Space between text and box
                   point.padding = 0.9, # Space between point and text
                   max.overlaps = Inf) + 
  labs(title = "Land owned by or designated for Indigenous, Afro-descendant, or local communities",
       y = "Percent of Total Country Land Area",
       caption = "Source: International Land Coalition") +
  theme_bw() +
  theme(legend.position = "none", axis.title.x = element_blank())

PLIPLC_plot
