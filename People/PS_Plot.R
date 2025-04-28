library(tidyverse)
library(readxl)
library(ggrepel)

setwd("C:/Users/readd/Documents/WWF_Consultancy/2024-25_Consultancy")
gov <- read_xlsx(path = "Governance_Indicators.xlsx")

countries <- c("Madagascar")

ps <- gov[,c(1,20:30)]

colnames(ps) <- c("Country", 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022)

ps <- ps %>% pivot_longer(cols = -Country, names_to = "Year", values_to = "Value")

ps$Year <- as.numeric(ps$Year)

ps_labels <- ps %>%
  group_by(Country) %>%
  filter(Year == min(Year)+1)

ps <- ps %>% filter(Country %in% countries)
ps_labels <- ps_labels %>% filter(Country %in% countries)

ps_plot <- ggplot(ps, aes(x = Year, y = Value, color = Country, group = Country)) +
  geom_line() +
  geom_point() +
  geom_label_repel(data = ps_labels, aes(label = Country),
                   nudge_x = 0.5, # Slight horizontal nudging
                   nudge_y = 0.5,
                   alpha = 0.8,
                   size = 4,
                   fill = "white",
                   segment.color = NA,
                   box.padding = 0.3, # Space between text and box
                   point.padding = 0.9, # Space between point and text
                   max.overlaps = Inf) + 
  labs(title = "Land and Environmental Defenders Killed",
       y = "Number of People Killed",
       caption = "Source: Global Witness")+
  theme_bw() +
  scale_x_continuous(limits = c(2012, 2022), n.breaks = 6)+
  theme(legend.position = "none", axis.title.x = element_blank())

ps_plot

